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
    private var previousWristY: CGFloat?
    
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
    
    func processFrame(_ sampleBuffer: CMSampleBuffer) async -> (state: PoseState, deltaY: CGFloat, drawingPoint: CGPoint?) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return (.unknown, 0, nil)
        }
        
        let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        let request = VNDetectHumanHandPoseRequest()
        request.maximumHandCount = 1
        
        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first else {
                return (.unknown, 0, nil)
            }
            
            // 모델에 주입하기 위한 MultiArray 변환
            let keypointsMultiArray = try observation.keypointsMultiArray()
            
            guard let prediction = try model?.prediction(poses: keypointsMultiArray) else {
                return (.unknown, 0, nil)
            }
            
            let state = PoseState(rawValue: prediction.label) ?? .unknown
            var deltaY: CGFloat = 0
            var drawingPoint: CGPoint? = nil
            
            if state == .fist {
                let wristPoint = try observation.recognizedPoint(.wrist)
                if wristPoint.confidence > 0.5 {
                    let currentY = wristPoint.location.y
                    if let prevY = previousWristY {
                        deltaY = abs(currentY - prevY)
                    }
                    previousWristY = currentY
                }
            } else if state == .holdingCan {
                let indexTipPoint = try observation.recognizedPoint(.indexTip)
                if indexTipPoint.confidence > 0.5 {
                    drawingPoint = indexTipPoint.location
                }
                previousWristY = nil
            } else {
                previousWristY = nil
            }
            
            return (state, deltaY, drawingPoint)
            
        } catch {
            print("Vision/ML processing error: \(error)")
            return (.unknown, 0, nil)
        }
    }
}
