import SwiftUI

struct ContentView: View {
    @State private var isARPresented = false
    
    var body: some View {
        ZStack {
            MapView()
                .edgesIgnoringSafeArea(.all)
            
            VStack {
                Spacer()
                Button(action: {
                    isARPresented = true
                }) {
                    HStack {
                        Image(systemName: "camera.viewfinder")
                        Text("ARカメラ起動")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(30)
                    .shadow(radius: 5)
                }
                .padding(.bottom, 40)
            }
        }
        .fullScreenCover(isPresented: $isARPresented) {
            ARViewControllerRepresentable()
                .edgesIgnoringSafeArea(.all)
        }
    }
}

#Preview {
    ContentView()
}
