allprojects {
    repositories {
        google()
        mavenCentral()
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

subprojects {
    fun configureAndroid() {
        val android = project.extensions.findByName("android")
        if (android != null) {
            try {
                // Try setCompileSdk(Integer)
                val setCompileSdk = android.javaClass.getMethod("setCompileSdk", Integer::class.java)
                setCompileSdk.invoke(android, 36)
            } catch (e: Exception) {
                try {
                    // Try setCompileSdk(int)
                    val setCompileSdkInt = android.javaClass.getMethod("setCompileSdk", Int::class.javaPrimitiveType)
                    setCompileSdkInt.invoke(android, 36)
                } catch (e1: Exception) {
                    try {
                        // Fallback to compileSdkVersion(int)
                        val compileSdkVersion = android.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                        compileSdkVersion.invoke(android, 36)
                    } catch (e2: Exception) {
                        println("Failed to override compileSdk for ${project.name}: $e2")
                    }
                }
            }
        }
    }

    if (project.state.executed) {
        configureAndroid()
    } else {
        project.afterEvaluate {
            configureAndroid()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
