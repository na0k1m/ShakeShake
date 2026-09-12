//
//  VisionMLManager.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

import Foundation
import Vision
import CoreML
import AVFoundation

actor VisionMLManager {
    // 모델 이름을 HandPoseClassifier로 가정합니다. 
    // 파일명이 다를 경우 해당 클래스명으로 변경해야 합니다.
    private var model: HandPoseClassifier?
    private var previousWrist: CGPoint?
    private var wasSpraying: Bool = false
    private var missingFramesCount: Int = 0
    
    init() {
        // 모델 로드는 비동기로 처리합니다.
    }
    
    func loadModel() async {
        do {
            let config = MLModelConfiguration()
            self.model = try await HandPoseClassifier.load(configuration: config)
        } catch {
            print("Failed to load CoreML model: \(error)")
        }
    }
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) async -> (state: PoseState, deltaX: CGFloat, deltaY: CGFloat, drawingPoint: CGPoint?, isSpraying: Bool) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return (.unknown, 0, 0, nil, false)
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        
        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first else {
                wasSpraying = false
                return (.unknown, 0, 0, nil, false)
            }
            
            // 모델에 주입하기 위한 MultiArray 변환
            let keypointsMultiArray = try observation.keypointsMultiArray()
            
            guard let prediction = try await model?.prediction(poses: keypointsMultiArray) else {
                return (.unknown, 0, 0, nil, false)
            }
            
            let state = PoseState(rawValue: prediction.label) ?? .unknown
            var deltaX: CGFloat = 0
            var deltaY: CGFloat = 0
            var drawingPoint: CGPoint? = nil
            var isSpraying: Bool = false
            
            if state == .fist {
                let wristPoint = try observation.recognizedPoint(.wrist)
                let fistCenter = try? observation.recognizedPoint(.middleMCP) // 주먹의 중심부(중지 관절)
                
                if wristPoint.confidence > 0.5 {
                    let currentPoint = wristPoint.location
                    if let prevPoint = previousWrist {
                        deltaX = abs(currentPoint.x - prevPoint.x)
                        deltaY = abs(currentPoint.y - prevPoint.y)
                    }
                    previousWrist = currentPoint
                    
                    // 주먹을 쥐었을 때 에셋이 손목이 아닌 주먹(너클) 쪽에 위치하도록 수정
                    if let center = fistCenter, center.confidence > 0.3 {
                        drawingPoint = center.location
                    } else {
                        drawingPoint = currentPoint
                    }
                }
                wasSpraying = false
            } else if state == .holdingCan {
                let indexTipPoint = try? observation.recognizedPoint(.indexTip)
                let wristPoint = try? observation.recognizedPoint(.wrist)
                let indexMCP = try? observation.recognizedPoint(.indexMCP) // 검지 손가락 밑단(관절)
                
                // 손가락이 빠르게 움직일 때 모션 블러로 인해 인식률(confidence)이 순간적으로 떨어져 
                // 선이 끊기는 것을 방지하기 위해 신뢰도 임계값을 0.5에서 0.3으로 완화
                if let tip = indexTipPoint, tip.confidence > 0.3 {
                    drawingPoint = tip.location
                }
                
                var currentFrameSpraying = false
                
                // 검지 손가락이 구부러졌는지(스프레이를 누르는지) 판별
                if let tip = indexTipPoint, let mcp = indexMCP, let wrist = wristPoint, 
                   tip.confidence > 0.3, mcp.confidence > 0.3, wrist.confidence > 0.3 {
                    let fingerDist = hypot(tip.location.x - mcp.location.x, tip.location.y - mcp.location.y)
                    let palmDist = hypot(mcp.location.x - wrist.location.x, mcp.location.y - wrist.location.y)
                    
                    let ratio = fingerDist / palmDist
                    
                    // ⭐️ 히스테리시스(Hysteresis) 적용: 깜빡임(Flickering) 방지
                    // 한 번 쏘기 시작하면 손가락을 꽤 많이 펼 때까지(0.90) 계속 쏘는 것으로 인정하고,
                    // 안 쏠 때는 확실히 구부려야(0.75) 쏘는 것으로 인정합니다.
                    let threshold: CGFloat = wasSpraying ? 0.90 : 0.75
                    if ratio < threshold {
                        currentFrameSpraying = true
                    }
                    missingFramesCount = 0
                } else {
                    // 순간적으로 손가락이 카메라에서 흐릿하게 보일 때 에러 카운트 증가
                    missingFramesCount += 1
                }
                
                // 프레임 튀어오름 방지(Debouncing): 1~3프레임 정도 손가락을 놓치더라도 직전 스프레이 상태를 유지
                if missingFramesCount > 0 && missingFramesCount < 4 {
                    isSpraying = wasSpraying
                } else {
                    isSpraying = currentFrameSpraying
                }
                
                wasSpraying = isSpraying
                previousWrist = nil
            } else {
                wasSpraying = false
                previousWrist = nil
            }
            
            return (state, deltaX, deltaY, drawingPoint, isSpraying)
            
        } catch {
            print("Vision/ML processing error: \(error)")
            return (.unknown, 0, 0, nil, false)
        }
    }
}
