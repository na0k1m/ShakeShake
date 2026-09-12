//
//  MainCanvasView.swift
//  ShakeShake
//
//  Created by 김나영 on 12/9/26.
//

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
                        style: StrokeStyle(lineWidth: 30, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .onChange(of: viewModel.currentDrawingPoint) { newPoint in
                guard let normalizedPoint = newPoint else { return }
                
                let mappedPoint = CGPoint(
                    x: (1.0 - normalizedPoint.x) * geometry.size.width, // 좌우 반전 처리(거울 모드)
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
