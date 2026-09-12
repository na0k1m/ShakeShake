# ShakeShake - macOS Spray Paint Simulator

본 문서는 ShakeShake 프로젝트의 핵심 아키텍처 및 구현 코드를 담은 기획서이자 기술 명세서입니다. SwiftUI와 Vision, Core ML을 활용하여 손 동작을 인식하고 스프레이 페인트 효과를 렌더링하는 파이프라인을 구축합니다.

## 디렉토리 구조
```text
SprayPaintMacSimulator/
├── App/
│   └── SprayPaintMacSimulatorApp.swift
├── MLModels/
│   └── HandPoseClassifier.mlmodel
├── Views/
│   ├── MainCanvasView.swift
│   ├── CameraPreviewView.swift
│   └── OverlayUI.swift
├── ViewModels/
│   └── SprayViewModel.swift
├── Managers/
│   ├── CameraManager.swift
│   └── VisionMLManager.swift
└── Models/
    └── PoseState.swift
```

---

## Step 1: CameraManager & Models 구성

### `Models/PoseState.swift`
손 포즈의 상태를 나타내는 Enum입니다.

```swift
import Foundation

enum PoseState: String {
    case fist = "Fist"
    case holdingCan = "HoldingCan"
    case unknown = "Unknown"
}
```

### `Managers/CameraManager.swift`
macOS 카메라 권한을 획득하고 프레임 버퍼를 출력하는 매니저입니다.

```swift
import Foundation
import AVFoundation
import AppKit

class CameraManager: NSObject, ObservableObject {
    @Published var session = AVCaptureSession()
    private let videoOutput = AVCaptureVideoDataOutput()
    private let cameraQueue = DispatchQueue(label: "com.shakeshake.cameraQueue", qos: .userInteractive)
    
    var sampleBufferDelegate: AVCaptureVideoDataOutputSampleBufferDelegate? {
        didSet {
            videoOutput.setSampleBufferDelegate(sampleBufferDelegate, queue: cameraQueue)
        }
    }
    
    override init() {
        super.init()
        checkPermissions()
    }
    
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupCamera()
                }
            }
        default:
            print("Camera permission denied")
        }
    }
    
    private func setupCamera() {
        session.beginConfiguration()
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            print("Failed to setup camera input")
            session.commitConfiguration()
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }
        
        session.commitConfiguration()
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }
}
```

---

## Step 2: VisionMLManager (핵심 파이프라인) 구현

비동기 Actor 격리를 사용하여 메인 스레드 차단을 방지하는 비전 및 ML 추론 파이프라인입니다.

### `Managers/VisionMLManager.swift`
```swift
import Foundation
import Vision
import CoreML
import AVFoundation

actor VisionMLManager {
    // HandPoseClassifier는 Create ML을 통해 사전 학습된 모델 객체로 가정합니다.
    private var model: HandPoseClassifier?
    private var previousWristY: CGFloat?
    
    init() {
        do {
            let config = MLModelConfiguration()
            self.model = try HandPoseClassifier(configuration: config)
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
            
            // Core ML 분류를 위한 MultiArray 추출 (Create ML 모델 입력 포맷에 맞춤)
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
                    // Vision 좌표계 (좌측 하단이 0,0)의 정규화된 좌표입니다.
                    // 뷰 좌표계로의 변환은 뷰 영역에서 수행하기 위해 정규화된 좌표를 반환합니다.
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
```

---

## Step 3: ViewModel 구성

데이터 흐름을 제어하고 뷰에 상태를 제공하는 ViewModel입니다.

### `ViewModels/SprayViewModel.swift`
```swift
import Foundation
import AVFoundation
import SwiftUI

@MainActor
class SprayViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var currentState: PoseState = .unknown
    @Published var paintGauge: CGFloat = 0.0 // 0.0 ~ 1.0
    @Published var currentDrawingPoint: CGPoint? = nil
    
    let cameraManager = CameraManager()
    private let visionManager = VisionMLManager()
    
    override init() {
        super.init()
        cameraManager.sampleBufferDelegate = self
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
            // 흔들기 이동량에 비례하여 게이지 증가
            let increment = deltaY * 2.0 // 감도 조절 계수
            paintGauge = min(1.0, paintGauge + increment)
            self.currentDrawingPoint = nil
        } else if state == .holdingCan {
            if paintGauge > 0 {
                self.currentDrawingPoint = drawingPoint
                paintGauge = max(0.0, paintGauge - 0.01) // 스프레이 사용 시 게이지 감소
            } else {
                self.currentDrawingPoint = nil
            }
        } else {
            self.currentDrawingPoint = nil
        }
    }
}
```

---

## Step 4: Rendering Engine (CanvasView) 구성

전달된 뷰 좌표에 스프레이 노이즈 질감을 렌더링합니다.

### `Views/MainCanvasView.swift`
```swift
import SwiftUI

struct MainCanvasView: View {
    @ObservedObject var viewModel: SprayViewModel
    @State private var lines: [DrawingPath] = []
    
    struct DrawingPath: Identifiable {
        let id = UUID()
        var points: [CGPoint]
        var alpha: Double
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for line in lines {
                    var path = Path()
                    guard let first = line.points.first else { continue }
                    path.move(to: first)
                    for point in line.points.dropFirst() {
                        path.addLine(to: point)
                    }
                    context.stroke(
                        path,
                        with: .color(Color.red.opacity(line.alpha)),
                        style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .onChange(of: viewModel.currentDrawingPoint) { newPoint in
                guard let normalizedPoint = newPoint else { return }
                
                // Vision 정규화 좌표(좌하단 0,0)를 macOS View 좌표(좌상단 0,0)로 변환
                // SwiftUI Canvas는 좌상단 기준이므로 Y를 반전시킵니다.
                let mappedPoint = CGPoint(
                    x: normalizedPoint.x * geometry.size.width,
                    y: (1.0 - normalizedPoint.y) * geometry.size.height
                )
                
                if viewModel.currentState == .holdingCan && viewModel.paintGauge > 0 {
                    if let lastIndex = lines.indices.last, let lastPoint = lines[lastIndex].points.last {
                        let distance = hypot(mappedPoint.x - lastPoint.x, mappedPoint.y - lastPoint.y)
                        if distance < 50 {
                            lines[lastIndex].points.append(mappedPoint)
                        } else {
                            lines.append(DrawingPath(points: [mappedPoint], alpha: Double(viewModel.paintGauge)))
                        }
                    } else {
                        lines.append(DrawingPath(points: [mappedPoint], alpha: Double(viewModel.paintGauge)))
                    }
                }
            }
        }
        .background(Color.clear)
    }
}
```

---

## Step 5: SwiftUI View 조립

카메라 프리뷰, 캔버스 뷰, 오버레이 UI를 계층적으로 조립합니다.

### `Views/CameraPreviewView.swift`
```swift
import SwiftUI
import AVFoundation

struct CameraPreviewView: NSViewRepresentable {
    let session: AVCaptureSession
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer = CALayer()
        view.layer?.addSublayer(previewLayer)
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        guard let layer = nsView.layer?.sublayers?.first as? AVCaptureVideoPreviewLayer else { return }
        layer.frame = nsView.bounds
    }
}
```

### `Views/OverlayUI.swift`
```swift
import SwiftUI

struct OverlayUI: View {
    @ObservedObject var viewModel: SprayViewModel
    
    var body: some View {
        VStack {
            HStack {
                Text("State: \(viewModel.currentState.rawValue)")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                Spacer()
            }
            Spacer()
            HStack {
                Text("Paint Gauge")
                    .foregroundColor(.white)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * viewModel.paintGauge)
                    }
                }
                .frame(height: 20)
                .cornerRadius(10)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
        .padding()
    }
}
```

### `App/SprayPaintMacSimulatorApp.swift`
```swift
import SwiftUI

@main
struct SprayPaintMacSimulatorApp: App {
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
```
