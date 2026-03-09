import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("This is a big test")
                .font(.title)
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
