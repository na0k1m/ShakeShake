//
//  CameraPreviewView.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

import SwiftUI
import AVFoundation

class PreviewView: NSView {
    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        
        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
        
        self.layer = previewLayer
        self.wantsLayer = true
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    
    func makeNSView(context: Context) -> PreviewView {
        return PreviewView(session: session)
    }
    
    func updateNSView(_ nsView: PreviewView, context: Context) {
        // NSView 자체의 root layer로 설정되었으므로 자동 리사이징됩니다.
    }
}
