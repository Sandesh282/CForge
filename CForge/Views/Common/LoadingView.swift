import SwiftUI
struct LoadingView: View {
    var body: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .neonBlue))
                .scaleEffect(1.5)
            Text("Loading...")
                .padding(.top, 8)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.darkBackground)
    }
}
#Preview {
    LoadingView()
}
