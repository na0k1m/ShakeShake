//
//  OverlayUI.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

import SwiftUI

struct OverlayUI: View {
    @ObservedObject var viewModel: SprayViewModel
    
    var body: some View {
        VStack {
            // --- Top HUD ---
            ZStack {
                // 1. 상태 알림바 (왼쪽 고정)
                HStack {
                    HStack(spacing: 8) {
                        statusIcon()
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                        
                        Text(statusText())
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    
                    Spacer()
                }
                
                // 2. 컬러 팔레트 (가운데 절대 고정)
                HStack(spacing: 12) {
                    ForEach(SprayViewModel.SprayColor.allCases, id: \.self) { sprayColor in
                        let color = sprayColor.color
                        let isSelected = viewModel.selectedSprayColor == sprayColor
                        
                        Circle()
                            .fill(color)
                            .frame(width: 26, height: 26)
                            .overlay(
                                Circle()
                                    .stroke(Color.primary.opacity(0.8), lineWidth: isSelected ? 3 : 0)
                            )
                            .shadow(color: color.opacity(0.4), radius: isSelected ? 6 : 0)
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: viewModel.selectedSprayColor)
                            .onTapGesture {
                                viewModel.selectedSprayColor = sprayColor
                            }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                
                // 3. 지우기 버튼 (오른쪽 고정)
                HStack {
                    Spacer()
                    Button(action: {
                        withAnimation {
                            viewModel.clearTrigger += 1
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "eraser.fill")
                            Text("전체 지우기")
                        }
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(PlainButtonStyle())
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                }
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)
            
            Spacer()
            
            // --- Bottom Paint Gauge ---
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "drop.fill")
                        .foregroundColor(gaugeColor())
                    
                    Text("페인트 잔량")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Text("\(Int(viewModel.paintGauge * 100))%")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(gaugeColor())
                }
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.gray.opacity(0.2))
                        
                        Capsule()
                            .fill(gaugeColor())
                            .frame(width: max(0, geometry.size.width * viewModel.paintGauge))
                    }
                    // 자연스러운 차징/소모 애니메이션
                    .animation(.interactiveSpring(response: 0.4, dampingFraction: 0.8), value: viewModel.paintGauge)
                }
                .frame(height: 12)
            }
            .padding(24)
            .frame(width: 320)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.15), radius: 15, x: 0, y: 8)
            .padding(.bottom, 40)
        }
    }
    
    // SF Symbols 활용
    private func statusIcon() -> Image {
        switch viewModel.currentState {
        case .fist: return Image(systemName: "battery.100.bolt")
        case .holdingCan: return Image(systemName: "paintbrush.pointed.fill")
        case .unknown: return Image(systemName: "viewfinder")
        }
    }
    
    private func statusText() -> String {
        switch viewModel.currentState {
        case .fist: return "위아래로 흔들어 충전"
        case .holdingCan: return "스프레이 조준 중"
        case .unknown: return "카메라에 손을 인식해주세요"
        }
    }
    
    private func gaugeColor() -> Color {
        if viewModel.paintGauge < 0.2 { return .red }
        if viewModel.paintGauge < 0.5 { return .orange }
        
        // 🍯 게이지 색상을 현재 선택한 페인트 색상과 동일하게 맞춰서 시각적 즐거움 부여
        return viewModel.selectedColor == .white ? .gray : viewModel.selectedColor
    }
}
