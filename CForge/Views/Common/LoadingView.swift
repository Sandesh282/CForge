//
//  LoadingView.swift
//  CForge
//
//  Created by Sandesh Raj on 30/03/25.
//

import SwiftUI
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
            Text("Loading...")
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
#Preview {
    LoadingView()
}
