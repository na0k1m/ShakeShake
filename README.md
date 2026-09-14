# ShakeShake 쉑쉑 🎨

**쉑쉑**은 웹캠(카메라)을 통해 사용자의 손 동작을 추적하여 가상의 페인트를 충전하고, 화면에 스프레이 드로잉을 수행할 수 있는 macOS 기반 애플리케이션입니다.

## ✨ 핵심 기능 (Features)

<table width="100%">
  <tr align="center">
    <td width="33%"><b>1. 스프레이 발사 (Draw & Spray)</b></td>
    <td width="33%"><b>2. 조준 및 이동 (Aim & Hover)</b></td>
    <td width="33%"><b>3. 페인트 충전 (Shake to Recharge)</b></td>
  </tr>
  <tr align="center">
    <td><img src="https://github.com/user-attachments/assets/ead55447-f983-41d5-8425-21047e41588e" width="100%" alt="스프레이 발사" /></td>
    <td><img src="https://github.com/user-attachments/assets/29b5d708-61ad-4258-a756-89a1730929bc" width="100%" alt="조준 및 이동" /></td>
    <td><img src="https://github.com/user-attachments/assets/af91d5e2-4af5-4e5d-869b-3bf6ee41fc5f" width="100%" alt="페인트 충전" /></td>
  </tr>
  <tr>
    <td>검지 손가락을 구부리면 치이익- 소리와 함께 그래피티가 그려집니다. 현재 선택한 페인트 색상에 맞춰 캔 에셋과 UI 게이지의 색상이 동기화됩니다.</td>
    <td>스프레이를 쏘다 검지를 쫙 펴면 페인트 분사가 즉시 멈춥니다. 캔을 쥔 채로 화면 이곳저곳을 자유롭게 이동하며 다음 위치를 조준할 수 있습니다.</td>
    <td>페인트를 다 썼다면 주먹을 꽉 쥐고 위아래로 힘차게 흔들어주세요! 찰캉찰캉 경쾌한 사운드와 함께 페인트 게이지가 빠르게 충전됩니다.</td>
  </tr>
</table>

---
## ⚙️ 데이터 처리 파이프라인 (Data Pipeline)
1. **Vision Framework:** 카메라 영상 프레임에서 실시간으로 손의 21개 랜드마크 좌표를 추출합니다.
2. **Core ML 추론:** 추출된 랜드마크 배열 데이터를 Create ML로 사전 학습된 분류 모델(`HandPoseClassifier.mlmodel`)에 주입하여 현재 손 모양('주먹' vs '캔을 쥔 손')을 식별합니다.
3. **물리 연산 (흔들기 강도):** 손 모양이 '주먹'인 경우, 연속된 프레임 간 손목 랜드마크의 Y축 위치 변화량(Delta Y)을 연산하여 페인트 게이지를 충전합니다.
4. **렌더링 맵핑 (스프레이 드로잉):** 손 모양이 '캔을 쥔 손'인 경우, 검지 끝점의 정규화된 좌표를 macOS 뷰 픽셀 좌표계로 변환하여 캔버스 위에 스프레이 노이즈 효과를 렌더링합니다.

## 🛠 기술 스택 (Technology Stack)
- **UI & Graphics:** `SwiftUI`, `Canvas`
- **Machine Learning:** `Create ML` (Custom Hand Pose Classification 모델 직접 학습 및 구축)
- **Computer Vision:** `Vision` (21개 손 관절 실시간 3D Tracking 및 Geometric Override 로직 구현)
- **Model Inference:** `Core ML`
- **Media:** `AVFoundation` (카메라 제어 및 공간 SFX 오디오 재생)

---
## 💡 주요 기술적 도전 및 해결 과정 (Troubleshooting)
### 1. ML 모델 오인식 방어 (Geometric Override & Debouncing)
사용자의 손이 화면 가장자리로 벗어나 새끼손가락이 잘릴 경우, AI 모델이 이를 '주먹(Fist)'으로 오인식하여 원치 않게 충전 모드로 넘어가는 문제가 있었습니다. 
이를 해결하기 위해 `Vision` 프레임워크가 추적한 검지 손가락과 손바닥의 길이 비율을 실시간으로 수학적 연산하여, ML 모델의 결과를 동적으로 강제 교정(Override) 하는 방어 로직을 구현했습니다.
### 2. 부드러운 획(Stroke)과 스프레이 질감 렌더링
손을 빠르게 움직일 때 선이 각지는 현상을 막기 위해 `addQuadCurve`를 이용해 좌표 사이의 중간점(Mid-point)을 베지어 곡선으로 연결했습니다. 또한 3중 `blur` 필터 레이어를 겹쳐 그려 실제 스프레이 특유의 입자감과 퍼짐(Overspray) 효과를 완벽하게 재현했습니다.
### 3. 효율적인 생명주기(Lifecycle) 및 권한 관리
백그라운드에서 카메라가 불필요하게 켜져있는 것을 방지하기 위해 `AppDelegate`와 `ScenePhase`를 활용했습니다. 앱이 비활성화되거나 다른 창에 가려지면 카메라 세션과 ML 연산을 즉시 중단하여 Mac의 배터리와 리소스를 최적화했습니다.

---
## 🚀 실행 방법 (How to Run)
1. Xcode 15 이상 버전에서 프로젝트를 엽니다.
2. `Assets.xcassets`에 커스텀 스프레이 에셋과 컬러셋이 정상적으로 들어있는지 확인합니다.
3. 타겟을 **My Mac**으로 설정하고 `Cmd + R`을 눌러 실행합니다.
4. 카메라 접근 권한을 허용하면 바로 플레이 가능합니다!
