//
//  ShakeShakeApp.swift
//  ShakeShake
//
//  Created by 김나영 on 9/12/26.
//

import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    // 다른 앱으로 넘어가서 비활성화될 때
    func applicationWillResignActive(_ notification: Notification) {
        NotificationCenter.default.post(name: .appWillResignActive, object: nil)
    }
    
    // 다시 우리 앱으로 돌아와서 활성화될 때
    func applicationDidBecomeActive(_ notification: Notification) {
        NotificationCenter.default.post(name: .appDidBecomeActive, object: nil)
    }
    
    // X 버튼을 눌러 창을 닫았을 때 백그라운드에 남지 않고 앱을 완전히 종료(Kill)시킴
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

extension Notification.Name {
    static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    static let appWillResignActive = Notification.Name("appWillResignActive")
}

@main
struct ShakeShakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
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
            .onReceive(NotificationCenter.default.publisher(for: .appDidBecomeActive)) { _ in
                viewModel.cameraManager.startSession()
            }
            .onReceive(NotificationCenter.default.publisher(for: .appWillResignActive)) { _ in
                viewModel.cameraManager.stopSession()
            }
        }
    }
}
