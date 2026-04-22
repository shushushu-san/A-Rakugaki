import SwiftUI
import GoogleMaps

struct MapView: UIViewRepresentable {
    func makeUIView(context: Context) -> GMSMapView {
        // 渋谷駅の緯度経度
        let camera = GMSCameraPosition.camera(withLatitude: 35.6580, longitude: 139.7016, zoom: 15.0)
        let mapView = GMSMapView(frame: .zero, camera: camera)
        
        // ダミーのピン
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2D(latitude: 35.6580, longitude: 139.7016)
        marker.title = "渋谷駅"
        marker.snippet = "ダミーピン"
        marker.map = mapView
        
        return mapView
    }
    
    func updateUIView(_ uiView: GMSMapView, context: Context) {
        // 更新処理は今回不要
    }
}
