allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Forcer compileSdk 36 pour tous les plugins (flutter_webrtc etc.) encore en 31
subprojects {
    afterEvaluate {
        try {
            val androidExt = project.extensions.findByName("android")
            if (androidExt != null) {
                val compileSdkMethod = try {
                    androidExt.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                } catch (_: Exception) { null }
                if (compileSdkMethod != null) {
                    compileSdkMethod.invoke(androidExt, 36)
                } else {
                    val compileSdkVersionMethod = try {
                        androidExt.javaClass.getMethod("setCompileSdkVersion", Int::class.javaPrimitiveType)
                    } catch (_: Exception) { null }
                    compileSdkVersionMethod?.invoke(androidExt, 36)
                }
            }
        } catch (_: Exception) {}
    }
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
