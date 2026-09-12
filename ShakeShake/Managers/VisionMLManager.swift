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
    
    // ML 예측 튐(Flickering) 방지를 위한 상태 추적 변수
    private var lastStableState: PoseState = .unknown
    private var candidateState: PoseState = .unknown
    private var candidateStateCount: Int = 0
    
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
        
        var rawState: PoseState = .unknown
        var state: PoseState = .unknown
        var deltaX: CGFloat = 0.0
        var deltaY: CGFloat = 0.0
        var drawingPoint: CGPoint? = nil
        var isSpraying = false
        
        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first else {
                wasSpraying = false
                return (.unknown, 0, 0, nil, false)
            }
            
            if let multiArray = try? observation.keypointsMultiArray() {
                if let prediction = try? await model?.prediction(poses: multiArray) {
                    rawState = PoseState(rawValue: prediction.label) ?? .unknown
                }
            }
            
            // ⭐️ ML 모델 오판 강제 교정 (Geometric Override)
            // 화면 밖으로 새끼손가락이 잘렸을 때 ML이 '주먹(fist)'으로 오해하는 경우를 원천 차단합니다.
            if rawState == .fist {
                let tip = try? observation.recognizedPoint(.indexTip)
                let mcp = try? observation.recognizedPoint(.indexMCP)
                let wrist = try? observation.recognizedPoint(.wrist)
                
                if let t = tip, let m = mcp, let w = wrist,
                   t.confidence > 0.3, m.confidence > 0.3, w.confidence > 0.3 {
                    
                    let fingerLength = hypot(t.location.x - m.location.x, t.location.y - m.location.y)
                    let palmLength = hypot(m.location.x - w.location.x, m.location.y - w.location.y)
                    
                    // 주먹을 쥐면 검지손가락(fingerLength)이 손바닥(palmLength) 대비 매우 짧아집니다.
                    // 만약 비율이 0.5 이상이라면 검지가 어느 정도 펴져 있다는 뜻이므로 주먹이 아닙니다!
                    if (fingerLength / palmLength) > 0.5 {
                        rawState = .holdingCan // 강제로 스프레이 쥐는 자세로 교정
                    }
                }
            }
            
            // 상태 안정화 (Debouncing) 로직
            if rawState == candidateState {
                candidateStateCount += 1
            } else {
                candidateState = rawState
                candidateStateCount = 1
            }
            
            // Vision 좌표계에서 y가 0에 가까울수록 화면 하단(또는 상단, 방향에 따라 다름)
            // 보통 macOS 카메라에서는 y < 0.2 이면 손이 화면 밑으로 빠져나가 잘리는 구간
            let wristY = (try? observation.recognizedPoint(.wrist))?.location.y ?? 0.5
            
            // 화면 밖으로 손가락이 잘려나가면 ML이 손가락을 못 찾아서 '주먹(fist)'으로 오인식함.
            // 이를 방지하기 위해 화면 가장자리(wristY < 0.2 또는 > 0.8)에서는 주먹으로의 상태 전환을 아주 엄격하게 방어
            let requiredFrames: Int
            if candidateState == .fist && (wristY < 0.2 || wristY > 0.8) {
                requiredFrames = 10 // 가장자리에서는 10프레임(약 0.3초) 연속 주먹이어야 찐 주먹으로 인정
            } else {
                requiredFrames = 2  // 정상 범위에서는 2프레임만 연속되어도 바로 빠릿빠릿하게 상태 전환
            }
            
            if candidateStateCount >= requiredFrames {
                lastStableState = candidateState
            }
            
            state = lastStableState
            
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
