//
//  AnimatedGradient.swift
//  CForge
//
//  Created by Sandesh Raj on 02/04/25.
//

import SwiftUI

struct AnimatedGradientBackground: View {
    @State private var startPoint = UnitPoint(x: 0, y: 0)
    @State private var endPoint = UnitPoint(x: 1, y: 1)
    
    let colors: [Color]
    let speed: Double
    
    init(colors: [Color] = [.darkBackground, .darkerBackground], speed: Double = 5.0) {
        self.colors = colors
        self.speed = speed
    }
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: colors),
            startPoint: startPoint,
            endPoint: endPoint
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: speed)
                    .repeatForever(autoreverses: true)
            ) {
                startPoint = UnitPoint(x: 1, y: 1)
                endPoint = UnitPoint(x: 0, y: 0)
            }
        }
        .edgesIgnoringSafeArea(.all)
    }
}
