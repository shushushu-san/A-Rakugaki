package com.unity3d.player;

import android.app.Activity;
import android.content.Intent;
import android.content.res.Configuration;
import android.os.Bundle;

/**
 * Compatibility stub for flutter_unity_widget_2 which still references UnityPlayerActivity.
 * Unity 6 removed UnityPlayerActivity; this stub bridges the gap.
 * Uses plain Activity (not AppCompatActivity) so it is accessible from all modules.
 */
public class UnityPlayerActivity extends Activity implements IUnityPlayerLifecycleEvents {

    /** The Unity player instance; set after createUnityPlayer() is called. */
    protected UnityPlayerForActivityOrService mUnityPlayer;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
    }

    /** Override in subclasses to react when Unity has been unloaded. */
    public void onUnityPlayerUnloaded() {}

    /** Override in subclasses to react when Unity is ready/quitting. */
    @Override
    public void onUnityPlayerQuitted() {}

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
    }

    @Override
    protected void onPause() {
        super.onPause();
        // OverrideUnityActivity calls mUnityPlayer.pause() explicitly after super
    }

    @Override
    protected void onResume() {
        super.onResume();
        // OverrideUnityActivity calls mUnityPlayer.resume() explicitly after super
    }

    @Override
    protected void onDestroy() {
        super.onDestroy();
    }

    @Override
    public void onLowMemory() {
        super.onLowMemory();
        // Subclasses handle Unity-specific trimming
    }

    @Override
    public void onWindowFocusChanged(boolean hasFocus) {
        super.onWindowFocusChanged(hasFocus);
        // OverrideUnityActivity only calls super; forward focus to Unity here
        if (mUnityPlayer != null) {
            mUnityPlayer.windowFocusChanged(hasFocus);
        }
    }

    @Override
    public void onBackPressed() {
        // Let subclasses decide
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
    }
}
