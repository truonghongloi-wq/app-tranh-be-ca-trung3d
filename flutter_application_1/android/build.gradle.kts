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
    configurations.configureEach {
        resolutionStrategy.eachDependency {
            if (requested.group == "com.android.support" && requested.name == "support-compat") {
                useTarget("androidx.core:core:1.18.0")
                because("Avoid duplicate android.support.v4 classes when mixing legacy support libs with AndroidX")
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround for old plugins that do not declare android.namespace (required by AGP 8+).
subprojects {
    if (name == "ar_flutter_plugin") {
        plugins.withId("com.android.library") {
            val androidExt = extensions.findByName("android") ?: return@withId
            val getNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "getNamespace" && it.parameterCount == 0
            }
            val setNamespace = androidExt.javaClass.methods.firstOrNull {
                it.name == "setNamespace" && it.parameterCount == 1
            }
            val current = getNamespace?.invoke(androidExt) as? String
            if (current.isNullOrBlank()) {
                setNamespace?.invoke(androidExt, "io.carius.lars.ar_flutter_plugin")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
