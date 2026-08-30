allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Plugins (thermion_flutter in particular) declare their own compileSdk
// internally — bumping it in app/build.gradle.kts only affects the app
// module, not the plugin's. Its AAR metadata check then fails because its
// own androidx dependencies need compileSdk 34+ while it's still built
// against 33. Force every Android subproject to the same compileSdk so the
// check passes regardless of what an individual plugin declares.
subprojects {
    afterEvaluate {
        extensions.findByType(com.android.build.gradle.BaseExtension::class.java)?.compileSdkVersion(36)
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
