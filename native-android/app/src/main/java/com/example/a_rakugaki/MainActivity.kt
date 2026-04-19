package com.example.a_rakugaki

import android.os.Bundle
import android.util.Log
import androidx.activity.enableEdgeToEdge
import androidx.appcompat.app.AppCompatActivity
import androidx.core.view.ViewCompat
import androidx.core.view.WindowInsetsCompat
import com.google.android.gms.maps.CameraUpdateFactory
import com.google.android.gms.maps.GoogleMap
import com.google.android.gms.maps.OnMapReadyCallback
import com.google.android.gms.maps.SupportMapFragment
import com.google.android.gms.maps.model.LatLng
import com.google.android.gms.maps.model.MarkerOptions
import com.google.android.material.floatingactionbutton.FloatingActionButton
import com.google.firebase.Firebase
import com.google.firebase.app

class MainActivity : AppCompatActivity(), OnMapReadyCallback {

    companion object {
        private const val TAG = "MainActivity"
        // 初期表示位置: 渋谷（後でユーザー位置に変更可）
        private val DEFAULT_LOCATION = LatLng(35.6580, 139.7016)
        private const val DEFAULT_ZOOM = 15f
    }

    private lateinit var googleMap: GoogleMap

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        setContentView(R.layout.activity_main)
        ViewCompat.setOnApplyWindowInsetsListener(findViewById(R.id.main)) { v, insets ->
            val systemBars = insets.getInsets(WindowInsetsCompat.Type.systemBars())
            v.setPadding(systemBars.left, systemBars.top, systemBars.right, systemBars.bottom)
            insets
        }

        initFirebase()
        initMap()
        initFab()
    }

    private fun initFirebase() {
        Log.d(TAG, "Firebase initialized: ${Firebase.app.name}")
    }

    private fun initMap() {
        val mapFragment = supportFragmentManager
            .findFragmentById(R.id.map_fragment) as SupportMapFragment
        mapFragment.getMapAsync(this)
    }

    private fun initFab() {
        findViewById<FloatingActionButton>(R.id.fab_ar).setOnClickListener {
            // Step 3 で ArActivity への遷移を実装
            Log.d(TAG, "AR button tapped (placeholder)")
        }
    }

    // MapReadyCallback: 地図が利用可能になったら呼ばれる
    override fun onMapReady(map: GoogleMap) {
        googleMap = map

        // 初期カメラ位置を設定
        googleMap.moveCamera(CameraUpdateFactory.newLatLngZoom(DEFAULT_LOCATION, DEFAULT_ZOOM))

        // ダミーピンを配置（後でFirestoreから投稿データを取得して表示する）
        googleMap.addMarker(
            MarkerOptions()
                .position(DEFAULT_LOCATION)
                .title("サンプル落書き")
                .snippet("ここに落書きがあります")
        )

        Log.d(TAG, "Google Map is ready")
    }
}