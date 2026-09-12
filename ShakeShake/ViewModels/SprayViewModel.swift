//
//  SprayViewModel.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

@MainActor
class SprayViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentState: PoseState = .unknown
    @Published var paintGauge: CGFloat = 0.0
    @Published var currentDrawingPoint: CGPoint? = nil
    
    let cameraManager = CameraManager()
    private let visionManager = VisionMLManager()
    
    override init() {
        super.init()
        cameraManager.sampleBufferDelegate = self
        Task {
            await visionManager.loadModel()
        }
    }
    
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        Task {
            let result = await visionManager.processFrame(sampleBuffer)
            await updateState(state: result.state, deltaY: result.deltaY, drawingPoint: result.drawingPoint)
        }
    }
    
    private func updateState(state: PoseState, deltaY: CGFloat, drawingPoint: CGPoint?) {
        self.currentState = state
        
        if state == .fist {
            let increment = deltaY * 2.0 // 흔들기 감도
            paintGauge = min(1.0, paintGauge + increment)
            self.currentDrawingPoint = nil
        } else if state == .holdingCan {
            if paintGauge > 0 {
                self.currentDrawingPoint = drawingPoint
                paintGauge = max(0.0, paintGauge - 0.01) // 페인트 소모 속도
            } else {
                self.currentDrawingPoint = nil
            }
        } else {
            self.currentDrawingPoint = nil
        }
    }
}
