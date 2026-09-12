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
    @State private var isNewStroke: Bool = true // 새로운 획인지 구분하는 상태 변수
    
    struct DrawingPath: Identifiable {
        let id = UUID()
        var points: [CGPoint]
        var alpha: Double
        var color: Color
        var thickness: CGFloat
    }
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                for line in lines {
                    var path = Path()
                    guard let first = line.points.first else { continue }
                    path.move(to: first)
                    
                    if line.points.count == 2 {
                        path.addLine(to: line.points[1])
                    } else if line.points.count > 2 {
                        var previousPoint = first
                        for i in 1..<line.points.count {
                            let currentPoint = line.points[i]
                            let midPoint = CGPoint(
                                x: (previousPoint.x + currentPoint.x) / 2,
                                y: (previousPoint.y + currentPoint.y) / 2
                            )
                            if i == 1 {
                                path.addLine(to: midPoint)
                            } else {
                                path.addQuadCurve(to: midPoint, control: previousPoint)
                            }
                            previousPoint = currentPoint
                        }
                        path.addLine(to: previousPoint)
                    }
                    
                    // 스프레이 질감을 위한 3중 레이어 렌더링 (Airbrush / Spray Effect)
                    
                    // 1. 가장 넓고 흐릿하게 퍼지는 외곽 가루 (Overspray)
                    var ctx1 = context
                    ctx1.addFilter(.blur(radius: line.thickness * 0.8))
                    ctx1.stroke(
                        path,
                        with: .color(line.color.opacity(line.alpha * 0.3)),
                        style: StrokeStyle(lineWidth: line.thickness * 2.5, lineCap: .round, lineJoin: .round)
                    )
                    
                    // 2. 중간 밀도의 안개
                    var ctx2 = context
                    ctx2.addFilter(.blur(radius: line.thickness * 0.4))
                    ctx2.stroke(
                        path,
                        with: .color(line.color.opacity(line.alpha * 0.6)),
                        style: StrokeStyle(lineWidth: line.thickness * 1.2, lineCap: .round, lineJoin: .round)
                    )
                    
                    // 3. 중심부 (가장 진하지만 살짝 부드럽게)
                    var ctx3 = context
                    ctx3.addFilter(.blur(radius: line.thickness * 0.1))
                    ctx3.stroke(
                        path,
                        with: .color(line.color.opacity(line.alpha * 0.9)),
                        style: StrokeStyle(lineWidth: line.thickness * 0.6, lineCap: .round, lineJoin: .round)
                    )
                }
            }
            .onChange(of: viewModel.currentState) { newState in
                // 캔을 쥔 상태(그리기 상태)가 아니게 되면, 다음번 그리기는 '새로운 획'으로 취급
                if newState != .holdingCan {
                    isNewStroke = true
                }
            }
            .onChange(of: viewModel.currentDrawingPoint) { newPoint in
                guard let normalizedPoint = newPoint else { 
                    // 스프레이를 누르지 않거나(조준 모드), 주먹을 쥔 상태라 좌표가 nil로 들어오면
                    // 다음번 그릴 때 무조건 선이 끊어지도록(새로운 획) 처리합니다.
                    isNewStroke = true
                    return 
                }
                
                let mappedPoint = CGPoint(
                    x: (1.0 - normalizedPoint.x) * geometry.size.width, // 좌우 반전 처리(거울 모드)
                    y: (1.0 - normalizedPoint.y) * geometry.size.height
                )
                
                // 거리 비례 굵기 조절을 없애고 고정 굵기로 변경
                let dynamicThickness: CGFloat = 80.0
                
                if viewModel.currentState == .holdingCan && viewModel.paintGauge > 0 {
                    // 새로운 획이거나 선이 아예 없을 때는 무조건 새 선을 시작
                    if isNewStroke || lines.isEmpty {
                        lines.append(DrawingPath(points: [mappedPoint], alpha: Double(viewModel.paintGauge), color: viewModel.selectedColor, thickness: dynamicThickness))
                        isNewStroke = false
                    } else if let lastIndex = lines.indices.last, let lastPoint = lines[lastIndex].points.last {
                        // 중간에 프레임이 튀어서 거리가 멀어지더라도, 같은 획(스프레이를 누르고 있는 상태)이면 절대 끊지 않고 강제로 잇습니다.
                        if lines[lastIndex].color == viewModel.selectedColor {
                            lines[lastIndex].points.append(mappedPoint)
                        } else {
                            lines.append(DrawingPath(points: [mappedPoint], alpha: Double(viewModel.paintGauge), color: viewModel.selectedColor, thickness: dynamicThickness))
                        }
                    }
                }
            }
            .onChange(of: viewModel.clearTrigger) { _ in
                lines.removeAll()
            }
        }
        .background(Color.clear)
    }
}
