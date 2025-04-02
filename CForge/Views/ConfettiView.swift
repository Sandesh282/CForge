//
//  ConfettiView.swift
//  CForge
//
//  Created by Sandesh Raj on 29/03/25.
//

import SwiftUI


struct ConfettiView: UIViewRepresentable {
    func makeUIView(context: Context) -> some UIView {
        let view = UIView()
        view.backgroundColor = .clear
        return view
    }
    
    func updateUIView(_ uiView: UIViewType, context: Context) {
        let emitter = CAEmitterLayer()
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: uiView.bounds.width/2, y: 0)
        emitter.emitterSize = CGSize(width: uiView.bounds.width, height: 1)
        
        let cell = CAEmitterCell()
        cell.contents = UIImage(systemName: "star.fill")?.cgImage
        cell.birthRate = 20
        cell.lifetime = 5
        cell.velocity = 100
        cell.scale = 0.1
        cell.spin = 2
        cell.emissionRange = .pi
        
        emitter.emitterCells = [cell]
        uiView.layer.addSublayer(emitter)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            emitter.removeFromSuperlayer()
        }
    }
}
#Preview {
    ConfettiView()
}
