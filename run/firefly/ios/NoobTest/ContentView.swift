import SwiftUI

struct ContentView: View {
    @State private var backgroundColor = Color.gray
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            Text("ᕦ(ツ)ᕤ")
                .font(.system(size: 60))
                .foregroundColor(.black)
        }
        .onAppear {
            startPeriodicCheck()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    func startPeriodicCheck() {
        // Check immediately
        testConnection()

        // Then check every second
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            testConnection()
        }
    }

    func testConnection() {
        guard let url = URL(string: "http://185.96.221.52:8080/api/ping") else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if error == nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    // Connection successful - turn turquoise
                    backgroundColor = Color(red: 64/255, green: 224/255, blue: 208/255)
                } else {
                    // Connection failed - turn grey
                    backgroundColor = Color.gray
                }
            }
        }.resume()
    }
}

#Preview {
    ContentView()
}
