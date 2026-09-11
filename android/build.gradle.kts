allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

open class FlutterPluginVersionExtension {
    val compileSdkVersion: Int = 36
    val minSdkVersion: Int = 24
    val targetSdkVersion: Int = 36
    val ndkVersion: String = "27.0.12077973"
}

subprojects {
    if (project.name != "app") {
        project.extensions.findByType(FlutterPluginVersionExtension::class.java)
            ?: project.extensions.create("flutter", FlutterPluginVersionExtension::class.java)
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
