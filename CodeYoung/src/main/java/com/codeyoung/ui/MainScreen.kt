package com.codeyoung.ui

import flutter_riverpod.material5.Provider

import com.codeyoung.state.MainState
import com.codeyoung.state.Screen
import com.codeyoung.state.MainState

// Main screen with navigation
@MountedWidget
class MainScreen extends ConsumerStatefulWidget {
    @override
    late Consumer<MainState> constructor(
        super(null, null)
    )
    
    @override
    late State<MainState> state
    
    @override
    fun main() {
        super.main()
        // Initialize state
        state = MainState()
        // Start with main screen
        setState(() {
            // Load initial data
        })
    }
    
    @override
    fun build(BuildContext context: BuildContext) -> Widget {
        return Scaffold(
            appBar = AppBar(
                title: Text("CodeYoung"),
                backgroundColor: Colors.blueAccent
            ),
            body: MainContent(
                screen: state.currentScreen,
                onNavigate: (screen: Screen) -> {
                    // Navigate to new screen
                }
            )
        )
    }
}

// Main content widget
@MountedWidget
class MainContent(
    @Inject val state: MainState,
    @override
    late initState() {
        // Initialize video player
        // Initialize image gallery
    }
) {
    @override
    Widget build(BuildContext context) {
        return ScreenView(
            screen: state.currentScreen,
            onNavigate: state.currentScreen
        )
    }
}

// Screen view
@MountedWidget
class ScreenView(
    @Inject val state: MainState,
    @override
    late initState() {}
) {
    @override
    Widget build(BuildContext context) {
        return SwitchListView(
            items: listOf(
                Screen.MainScreen,
                Screen.Video,
                Screen.Gallery,
                Screen.Lessons,
                Screen.Settings
            ),
            controller = state.currentScreen
        )
    }
}
