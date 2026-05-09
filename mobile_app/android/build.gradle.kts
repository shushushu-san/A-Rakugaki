import java.util.Properties

// local.properties から SDK / NDK パスを読み込み、Unity 由来の build.gradle が
// 期待する `unity.androidSdkPath` / `unity.androidNdkPath` を全サブプロジェクトに注入する。
// （Unity 再エクスポート時に build.gradle が上書きされても、トップレベルから供給されるので毎回有効）
val localProps = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
val unitySdkPath: String = localProps.getProperty(
    "unity.androidSdkPath",
    localProps.getProperty("sdk.dir", ""),
)
val unityNdkPath: String = localProps.getProperty(
    "unity.androidNdkPath",
    localProps.getProperty("unity.ndk.dir", localProps.getProperty("ndk.dir", "")),
)

allprojects {
    repositories {
        flatDir {
            dirs(file("${project(":unityLibrary").projectDir}/libs"))
        }

        google()
        mavenCentral()
    }

    // Unity の il2cpp ビルドが参照するプロパティ。空文字でも getProperty が失敗しないように常に設定する。
    project.extensions.extraProperties["unity.androidSdkPath"] = unitySdkPath
    project.extensions.extraProperties["unity.androidNdkPath"] = unityNdkPath
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
