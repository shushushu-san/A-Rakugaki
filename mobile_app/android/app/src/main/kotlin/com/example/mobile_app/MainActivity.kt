package com.example.mobile_app

import android.graphics.Bitmap
import android.os.Handler
import android.os.Looper
import android.view.PixelCopy
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import com.xraph.plugin.flutter_unity_widget.FlutterUnityActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class MainActivity : FlutterUnityActivity() {

    companion object {
        private const val CHANNEL = "com.example.mobile_app/ar_screenshot"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "captureWindow" -> captureUnityView(result)
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Hybrid Composition では Flutter と Unity の両方がフルスクリーン SurfaceView を持つ。
     * Flutter の SurfaceView は _hideOverlay=true で透明→黒になる。
     * Unity の SurfaceView はカメラ/AR コンテンツで有色になる。
     * 全 SurfaceView を試して、非黒（有効なコンテンツあり）のものを採用する。
     */
    private fun captureUnityView(result: MethodChannel.Result) {
        val handler = Handler(Looper.getMainLooper())
        val candidates = findAllSurfaceViews(window.decorView)
            .filter { it.width > 0 && it.height > 0 }
            .sortedByDescending { it.width.toLong() * it.height.toLong() }

        tryCaptureSurfaceViews(candidates, handler, result)
    }

    /** candidates を先頭から順に PixelCopy し、最初の非黒フレームを返す */
    private fun tryCaptureSurfaceViews(
        candidates: List<SurfaceView>,
        handler: Handler,
        result: MethodChannel.Result
    ) {
        if (candidates.isEmpty()) {
            captureWindowFallback(result, handler)
            return
        }
        val sv = candidates.first()
        val rest = candidates.drop(1)
        val bmp = Bitmap.createBitmap(sv.width, sv.height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(sv, bmp, { copyResult ->
            when {
                copyResult != PixelCopy.SUCCESS -> {
                    // この SurfaceView はキャプチャ失敗 → 次へ
                    tryCaptureSurfaceViews(rest, handler, result)
                }
                isBlackBitmap(bmp) -> {
                    // 真っ黒（Flutter の透明レイヤーなど） → 次へ
                    tryCaptureSurfaceViews(rest, handler, result)
                }
                else -> {
                    // AR コンテンツが取れた
                    val stream = ByteArrayOutputStream()
                    bmp.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                    result.success(stream.toByteArray())
                }
            }
        }, handler)
    }

    /**
     * ビットマップが実質的に真っ黒かどうか判定する。
     * 全ピクセルをチェックするのは重いため、グリッド状にサンプリングする。
     */
    private fun isBlackBitmap(bmp: Bitmap): Boolean {
        val stepX = (bmp.width / 8).coerceAtLeast(1)
        val stepY = (bmp.height / 8).coerceAtLeast(1)
        for (y in 0 until bmp.height step stepY) {
            for (x in 0 until bmp.width step stepX) {
                val pixel = bmp.getPixel(x, y)
                // R, G, B どれかが 10 以上あれば有効なコンテンツとみなす
                val r = (pixel shr 16) and 0xFF
                val g = (pixel shr 8) and 0xFF
                val b = pixel and 0xFF
                if (r > 10 || g > 10 || b > 10) return false
            }
        }
        return true
    }

    private fun captureWindowFallback(result: MethodChannel.Result, handler: Handler) {
        val rootView = window.decorView
        if (rootView.width <= 0 || rootView.height <= 0) {
            result.error("CAPTURE_FAILED", "No valid surface found", null)
            return
        }
        val bmp = Bitmap.createBitmap(rootView.width, rootView.height, Bitmap.Config.ARGB_8888)
        PixelCopy.request(window, bmp, { copyResult ->
            if (copyResult == PixelCopy.SUCCESS) {
                val stream = ByteArrayOutputStream()
                bmp.compress(Bitmap.CompressFormat.JPEG, 90, stream)
                result.success(stream.toByteArray())
            } else {
                result.error("CAPTURE_FAILED", "PixelCopy failed: $copyResult", null)
            }
        }, handler)
    }

    private fun findAllSurfaceViews(view: View): List<SurfaceView> {
        val list = mutableListOf<SurfaceView>()
        if (view is SurfaceView) {
            list.add(view)
        } else if (view is ViewGroup) {
            for (i in 0 until view.childCount) {
                list.addAll(findAllSurfaceViews(view.getChildAt(i)))
            }
        }
        return list
    }
}

