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
    enum SprayUIState {
        case hidden
        case shaking
        case idle
        case spraying
    }
    
    enum SprayColor: String, CaseIterable {
        case red = "SprayRed"
        case orange = "SprayOrange"
        case yellow = "SprayYellow"
        case green = "SprayGreen"
        case blue = "SprayBlue"
        case purple = "SprayPurple"
        case white = "SprayWhite"
        case black = "SprayBlack"
        
        var color: Color { Color(self.rawValue) }
    }
    
    @Published var currentState: PoseState = .unknown
    @Published var paintGauge: CGFloat = 0.0
    @Published var currentDrawingPoint: CGPoint? = nil
    @Published var currentHandPoint: CGPoint? = nil
    @Published var sprayUIState: SprayUIState = .hidden
    
    // 선택된 페인트 색상 (에셋 이름과 연동)
    @Published var selectedSprayColor: SprayColor = .red
    var selectedColor: Color { selectedSprayColor.color }
    
    var sprayImageName: String {
        let suffix = "_\(selectedSprayColor.rawValue)" // 예: "_SprayRed"
        switch sprayUIState {
        case .spraying: return "spray_active\(suffix)"
        case .idle:     return "spray_idle\(suffix)"
        case .shaking:  return "spray_shake\(suffix)"
        case .hidden:   return ""
        }
    }
    
    @Published var clearTrigger: Int = 0
    
    let cameraManager = CameraManager()
    private let visionManager = VisionMLManager()
    
    override init() {
        super.init()
        cameraManager.sampleBufferDelegate = self
        
        // 사운드 파일 미리 로드
        SoundManager.shared.setupSounds()
        
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
            self.currentHandPoint = drawingPoint
            self.sprayUIState = .shaking
            
            // Y축으로는 빠르고 크게 흔들고(> 0.03), X축(좌우)으로는 거의 움직이지 않아야(< 0.015) 깐깐하게 인정!
            if deltaY > 0.03 && deltaX < 0.015 {
                let increment = deltaY * 0.8 
                paintGauge = min(1.0, paintGauge + increment)
            }
            self.currentDrawingPoint = nil
        } else if state == .holdingCan {
            self.currentHandPoint = drawingPoint
            self.sprayUIState = isSpraying ? .spraying : .idle
            
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
            self.currentHandPoint = nil
            self.sprayUIState = .hidden
        }
        
        // --- 사운드 재생/정지 로직 ---
        if self.sprayUIState == .shaking {
            SoundManager.shared.playShake()
        } else {
            SoundManager.shared.stopShake()
        }
        
        if self.sprayUIState == .spraying && self.paintGauge > 0 {
            SoundManager.shared.playSpray()
        } else {
            SoundManager.shared.stopSpray()
        }
    }
}
