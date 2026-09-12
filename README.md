# ShakeShake 쉑쉑 🎨

**ShakeShake**는 웹캠(카메라)을 통해 사용자의 손 동작을 추적하여 가상의 페인트를 충전하고, 화면에 스프레이 드로잉을 수행할 수 있는 macOS 기반 애플리케이션입니다.

## 🌟 핵심 컨셉 (Core Concept)
- **모션 인식 충전:** 손을 쥐고(주먹) 상하로 흔드는 동작을 취하면 화면 내 스프레이 페인트 게이지가 충전됩니다.
- **가상 드로잉:** 손 모양을 '캔을 쥔 손' 형태로 변경하면, 실시간으로 손의 위치를 추적하여 화면에 가상의 스프레이 드로잉 효과를 렌더링합니다.

## ⚙️ 데이터 처리 파이프라인 (Data Pipeline)
1. **Vision Framework:** 카메라 영상 프레임에서 실시간으로 손의 21개 랜드마크 좌표를 추출합니다.
2. **Core ML 추론:** 추출된 랜드마크 배열 데이터를 Create ML로 사전 학습된 분류 모델(`HandPoseClassifier.mlmodel`)에 주입하여 현재 손 모양('주먹' vs '캔을 쥔 손')을 식별합니다.
3. **물리 연산 (흔들기 강도):** 손 모양이 '주먹'인 경우, 연속된 프레임 간 손목 랜드마크의 Y축 위치 변화량(Delta Y)을 연산하여 페인트 게이지를 충전합니다.
4. **렌더링 맵핑 (스프레이 드로잉):** 손 모양이 '캔을 쥔 손'인 경우, 검지 끝점의 정규화된 좌표를 macOS 뷰 픽셀 좌표계로 변환하여 캔버스 위에 스프레이 노이즈 효과를 렌더링합니다.

## 🛠 기술 스택 (Technology Stack)
- **UI Framework:** SwiftUI, AppKit
- **Camera Input:** AVFoundation (`AVCaptureSession`)
- **Computer Vision:** Vision (`VNDetectHumanHandPoseRequest`)
- **Machine Learning:** Core ML
- **Rendering Engine:** Core Graphics (SwiftUI Canvas)
- **Concurrency:** Swift Concurrency (async/await, Actor 기반 비동기 격리)

## 📁 주요 디렉토리 구조 (Architecture)
```text
SprayPaintMacSimulator/
├── App/                # 앱 엔트리포인트 (SwiftUI App)
├── MLModels/           # Core ML 모델 파일
├── Views/              # 캔버스, 카메라 프리뷰, 오버레이 UI
├── ViewModels/         # 비즈니스 로직 및 상태(게이지, 포즈, 좌표) 관리
├── Managers/           # 카메라 제어 및 Vision/Core ML 데이터 처리 파이프라인
└── Models/             # 상태 정의 (PoseState)
```
