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
    project.plugins.withId("org.jetbrains.kotlin.android") {
        project.tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            val javaTarget = project.extensions
                .findByType(com.android.build.gradle.BaseExtension::class.java)
                ?.compileOptions?.sourceCompatibility
            val jvm = when (javaTarget) {
                JavaVersion.VERSION_11 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11
                JavaVersion.VERSION_17 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
                JavaVersion.VERSION_21 -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_21
                else -> org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
            }
            compilerOptions {
                jvmTarget.set(jvm)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
