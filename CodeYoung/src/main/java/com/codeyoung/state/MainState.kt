package com.codeyoung.state

import flutter_riverpod.material5.Provider

// Main app state
final class MainState {
    // Screen state
    final var currentScreen: Screen = Screen.MainScreen
    
    // Video state
    final var videoUrl: String? = null
    
    // Image gallery state
    final var images: List<Image> = emptyList()
    
    // Learning progress
    final var completedLessons: Int = 0
    
    // UI state
    final var isPlaying: Boolean = false
    final var isPaused: Boolean = false
}

// Screen types
enum class Screen {
    MAIN,
    VIDEO,
    GALLERY,
    LESSONS,
    SETTINGS
}

// Image model
data class Image(
    val id: String,
    val title: String,
    val thumbUrl: String,
    val description: String
)

// Lesson model
data class Lesson(
    val id: String,
    val title: String,
    val description: String,
    val videoUrl: String?
)
