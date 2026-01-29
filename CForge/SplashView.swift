import SwiftUI

struct SplashView: View {
    @State private var scale = 0.7
    @State private var opacity = 0.5
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.darkBackground.ignoresSafeArea()

            
            VStack {
                Image(systemName: "bolt.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .neonBlue, radius: 20)
                    .symbolEffect(.variableColor.iterative.reversing)
                
                Text("CForge")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.neonBlue, .neonPurple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: .neonPurple, radius: 10)
                    .padding(.top, 16)
            }
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeIn(duration: 1.0)) {
                        scale = 1.2
                        opacity = 1
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation(.easeOut(duration: 0.5)) {
                            onComplete()
                        }
                    }
                }
    }
}


#Preview {
    SplashView(onComplete: {})
        
}
