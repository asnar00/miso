import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            Color(red: 64/255, green: 224/255, blue: 208/255)
                .ignoresSafeArea()

            Text("ᕦ(ツ)ᕤ")
                .font(.system(size: 60))
                .foregroundColor(.black)
        }
    }
}

#Preview {
    ContentView()
}