plugins {
    // Apply Detekt for static analysis
    id("io.gitlab.arturbosch.detekt") version "1.23.6"
    // Apply Ktlint for code style
    id("org.jlleitschuh.gradle.ktlint") version "12.1.0"
}

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
    // Apply the plugins only to repository modules (app), not third-party plugin dependencies
    if (project.name == "app") {
        plugins.apply("io.gitlab.arturbosch.detekt")
        plugins.apply("org.jlleitschuh.gradle.ktlint")
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
