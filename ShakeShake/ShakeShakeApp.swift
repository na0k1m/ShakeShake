//
//  ShakeShakeApp.swift
//  ShakeShake
//
//  Created by 김나영 on 9/12/26.
//

import SwiftUI

@main
struct ShakeShakeApp: App {
    @StateObject private var viewModel = SprayViewModel()
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                CameraPreviewView(session: viewModel.cameraManager.session)
                    .edgesIgnoringSafeArea(.all)
                
                MainCanvasView(viewModel: viewModel)
                    .edgesIgnoringSafeArea(.all)
                
                OverlayUI(viewModel: viewModel)
            }
            .frame(minWidth: 800, minHeight: 600)
        }
    }
}
