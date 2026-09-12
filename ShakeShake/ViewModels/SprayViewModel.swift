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
    
    // 새로 추가된 기능 상태들
    @Published var selectedColor: Color = .red
    @Published var clearTrigger: Int = 0
    
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
            await updateState(state: result.state, deltaX: result.deltaX, deltaY: result.deltaY, drawingPoint: result.drawingPoint, isSpraying: result.isSpraying)
        }
    }
    
    private func updateState(state: PoseState, deltaX: CGFloat, deltaY: CGFloat, drawingPoint: CGPoint?, isSpraying: Bool) {
        self.currentState = state
        
        if state == .fist {
            // Y축으로는 빠르고 크게 흔들고(> 0.03), X축(좌우)으로는 거의 움직이지 않아야(< 0.015) 깐깐하게 인정!
            if deltaY > 0.03 && deltaX < 0.015 {
                let increment = deltaY * 0.8 
                paintGauge = min(1.0, paintGauge + increment)
            }
            self.currentDrawingPoint = nil
        } else if state == .holdingCan {
            // 손 모양이 캔이고, 검지가 굽어있고(isSpraying == true), 페인트가 남아있을 때만 그림
            if paintGauge > 0 && isSpraying {
                self.currentDrawingPoint = drawingPoint
                // 페인트 소모 속도를 더 늦춤 (기존 0.003 -> 0.0015)
                paintGauge = max(0.0, paintGauge - 0.0015) 
            } else {
                // 페인트가 없거나, 검지를 쫙 펴고(조준) 있으면 선이 이어지지 않음
                self.currentDrawingPoint = nil
            }
        } else {
            self.currentDrawingPoint = nil
        }
    }
}
