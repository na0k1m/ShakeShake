//
//  OverlayUI.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

import SwiftUI

struct OverlayUI: View {
    @ObservedObject var viewModel: SprayViewModel
    
    let colors: [Color] = [.red, .blue, .green, .yellow, .black, .white, .purple, .orange]
    
    var body: some View {
        VStack {
            HStack {
                Text(stateText())
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                
                Spacer()
                
                // 컬러 팔레트
                HStack(spacing: 12) {
                    ForEach(colors, id: \.self) { color in
                        Circle()
                            .fill(color)
                            .frame(width: 30, height: 30)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: viewModel.selectedColor == color ? 3 : 0)
                            )
                            .onTapGesture {
                                viewModel.selectedColor = color
                            }
                    }
                }
                .padding()
                .background(Color.black.opacity(0.6))
                .cornerRadius(8)
                
                Spacer()
                
                // 전체 지우기 버튼
                Button(action: {
                    viewModel.clearTrigger += 1
                }) {
                    Text("지우기 🗑")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
            Spacer()
            HStack {
                Text("Paint Gauge")
                    .font(.headline)
                    .foregroundColor(.white)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.5))
                        Rectangle()
                            .fill(gaugeColor())
                            .frame(width: geometry.size.width * viewModel.paintGauge)
                            .animation(.easeInOut, value: viewModel.paintGauge)
                    }
                    .cornerRadius(10)
                }
                .frame(height: 24)
            }
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(12)
        }
        .padding(30)
    }
    
    private func stateText() -> String {
        switch viewModel.currentState {
        case .fist: return "✊ 흔들어서 충전하세요!"
        case .holdingCan: return "🎨 스프레이 뿌리는 중..."
        case .unknown: return "손을 보여주세요 👋"
        }
    }
    
    private func gaugeColor() -> Color {
        if viewModel.paintGauge < 0.2 { return .red }
        if viewModel.paintGauge < 0.5 { return .orange }
        return .blue
    }
}
