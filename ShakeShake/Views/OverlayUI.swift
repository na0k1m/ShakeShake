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
            HStack {
                Text(stateText())
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                Spacer()
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
