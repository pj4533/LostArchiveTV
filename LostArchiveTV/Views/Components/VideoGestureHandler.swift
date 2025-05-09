//
//  VideoGestureHandler.swift
//  LostArchiveTV
//
//  Created by Claude on 4/25/25.
//

import SwiftUI
import OSLog
import CoreHaptics

struct VideoGestureHandler: ViewModifier {
    let transitionManager: VideoTransitionManager
    let provider: VideoProvider
    let geometry: GeometryProxy
    
    // Binding values for animation state
    @Binding var dragOffset: CGFloat
    @Binding var isDragging: Bool
    
    // Constants for animation
    let swipeThreshold: CGFloat
    let animationDuration: Double
    
    // State for double-speed playback
    @State private var isLongPressing: Bool = false
    @State private var showIndicator: Bool = false
    
    // Initialize with all dependencies
    init(
        transitionManager: VideoTransitionManager,
        provider: VideoProvider,
        geometry: GeometryProxy,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        swipeThreshold: CGFloat = 100,
        animationDuration: Double = 0.15
    ) {
        self.transitionManager = transitionManager
        self.provider = provider
        self.geometry = geometry
        self._dragOffset = dragOffset
        self._isDragging = isDragging
        self.swipeThreshold = swipeThreshold
        self.animationDuration = animationDuration
        
        // Listen for notifications that might require resetting playback rate
        setupNotificationObservers()
    }
    
    // Set up notification observers for trim mode and other state changes
    private func setupNotificationObservers() {
        // Listen for trim mode activation notification
        NotificationCenter.default.addObserver(
            forName: .startVideoTrimming,
            object: nil,
            queue: .main
        ) { [self] _ in
            // Reset double-speed state when entering trim mode
            if isLongPressing {
                isLongPressing = false
                showIndicator = false
                
                if let controlProvider = provider as? VideoControlProvider {
                    Logger.videoPlayback.debug("⏩ Resetting speed due to trim mode activation")
                    controlProvider.resetPlaybackRate()
                }
            }
        }
    }
    
    func body(content: Content) -> some View {
        // Create a gesture group that can handle both drag and long press gestures
        let dragGesture = DragGesture()
            .onChanged { value in
                guard !transitionManager.isTransitioning else { return }
                
                let translation = value.translation.height
                isDragging = true
                
                // Allow both upward and downward swipes
                if translation < 0 {
                    // Upward swipe (for next video) - only if next video is ready
                    let isNextReady = transitionManager.nextVideoReady
                    Logger.caching.info("🔍 GESTURE CHECK: nextVideoReady=\(isNextReady), isPrevReady=\(transitionManager.prevVideoReady), transitionManager=\(String(describing: ObjectIdentifier(transitionManager)))")

                    if isNextReady {
                        dragOffset = max(translation, -geometry.size.height)
                        Logger.caching.debug("Dragging UP (next): nextVideoReady=true, dragOffset=\(dragOffset)")
                    } else {
                        // Log detailed information about the current state to help debug the issue
                        Logger.caching.info("⚠️ BLOCKED Dragging UP: nextVideoReady=false, dragOffset=\(dragOffset), isDragging=\(isDragging), isTransitioning=\(transitionManager.isTransitioning)")
                        Logger.caching.info("⚠️ TRANSITION STATE: nextPlayer=\(transitionManager.nextPlayer != nil ? "exists" : "nil"), prevPlayer=\(transitionManager.prevPlayer != nil ? "exists" : "nil")")
                    }
                } else {
                    // Downward swipe (for previous video) - only if previous video is ready
                    if transitionManager.prevVideoReady {
                        dragOffset = min(translation, geometry.size.height)
                        Logger.caching.debug("Dragging DOWN (prev): prevVideoReady=true, dragOffset=\(dragOffset)")
                    } else {
                        Logger.caching.debug("⚠️ BLOCKED Dragging DOWN: prevVideoReady=false")
                    }
                }
            }
            .onEnded { (value: DragGesture.Value) in
                guard !transitionManager.isTransitioning else { return }
                
                let translation = value.translation.height
                let velocity = value.predictedEndTranslation.height - value.translation.height
                
                // If we're not actually dragging significantly, just reset
                if abs(dragOffset) < 10 {
                    withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                        dragOffset = 0
                        isDragging = false
                    }
                    return
                }
                
                if dragOffset < 0 {
                    // Upward swipe (next video)
                    let shouldComplete = -dragOffset > swipeThreshold || -velocity > 500
                    
                    if shouldComplete && transitionManager.nextVideoReady {
                        // If we're in 2x speed mode, reset it before transitioning
                        if isLongPressing {
                            if let controlProvider = provider as? VideoControlProvider {
                                Logger.videoPlayback.debug("⏩ Transitioning while in 2x mode - resetting speed")
                                controlProvider.resetPlaybackRate()
                                isLongPressing = false
                                showIndicator = false
                            }
                        }
                        
                        // Complete the swipe animation upward (to next video)
                        transitionManager.completeTransition(
                            geometry: geometry,
                            provider: provider,
                            dragOffset: $dragOffset,
                            isDragging: $isDragging,
                            animationDuration: animationDuration,
                            direction: .up
                        )
                    } else {
                        // Bounce back to original position
                        withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                            dragOffset = 0
                            isDragging = false
                        }
                    }
                } else if dragOffset > 0 {
                    // Downward swipe (previous video)
                    let shouldComplete = dragOffset > swipeThreshold || velocity > 500
                    
                    if shouldComplete && transitionManager.prevVideoReady {
                        // If we're in 2x speed mode, reset it before transitioning
                        if isLongPressing {
                            if let controlProvider = provider as? VideoControlProvider {
                                Logger.videoPlayback.debug("⏩ Transitioning while in 2x mode - resetting speed")
                                controlProvider.resetPlaybackRate()
                                isLongPressing = false
                                showIndicator = false
                            }
                        }
                        
                        // Complete the swipe animation downward (to previous video)
                        transitionManager.completeTransition(
                            geometry: geometry,
                            provider: provider,
                            dragOffset: $dragOffset,
                            isDragging: $isDragging,
                            animationDuration: animationDuration,
                            direction: .down
                        )
                    } else {
                        // Bounce back to original position
                        withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                            dragOffset = 0
                            isDragging = false
                        }
                    }
                } else {
                    // Reset animation if no significant drag
                    withAnimation(.spring(response: animationDuration, dampingFraction: 0.7)) {
                        dragOffset = 0
                        isDragging = false
                    }
                }
            }
        
        // Create a long press gesture that activates after 1 second
        // and handles both start and end of the gesture properly
        let longPressGesture = LongPressGesture(minimumDuration: 1.0)
            .onEnded { _ in
                // Set the playback rate to 2x when the long press activates (after 1 second)
                Logger.videoPlayback.debug("⏩ LONG PRESS ACTIVATED AFTER 1s - SETTING 2X SPEED ⏩")
                isLongPressing = true
                showIndicator = true
                
                // Provide haptic feedback
                let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
                impactGenerator.impactOccurred()
                
                // Cast to VideoControlProvider to access the rate control methods
                if let controlProvider = provider as? VideoControlProvider {
                    controlProvider.setTemporaryPlaybackRate(rate: 2.0)
                    Logger.videoPlayback.debug("🎬 Set playback rate to 2.0 on \(type(of: controlProvider))")
                    
                    // Announce speed change to VoiceOver users
                    #if os(iOS)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if UIAccessibility.isVoiceOverRunning {
                            UIAccessibility.post(notification: .announcement, argument: "Double speed playback activated")
                        }
                    }
                    #endif
                } else {
                    Logger.videoPlayback.error("❌ Provider \(type(of: provider)) does not conform to VideoControlProvider")
                }
            }
        
        // Combine the long press with a drag gesture to handle the end state
        let combinedGesture = longPressGesture.sequenced(before: DragGesture(minimumDistance: 0))
            .onEnded { _ in
                // Reset the playback rate when the finger is lifted
                if isLongPressing {
                    Logger.videoPlayback.debug("⏩ FINGER LIFTED - RESETTING PLAYBACK SPEED ⏩")
                    isLongPressing = false
                    showIndicator = false
                    
                    // Cast to VideoControlProvider to access the rate control methods
                    if let controlProvider = provider as? VideoControlProvider {
                        controlProvider.resetPlaybackRate()
                        Logger.videoPlayback.debug("🎬 Reset playback rate on \(type(of: controlProvider))")
                        
                        // Announce speed change to VoiceOver users
                        #if os(iOS)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            if UIAccessibility.isVoiceOverRunning {
                                UIAccessibility.post(notification: .announcement, argument: "Normal playback speed resumed")
                            }
                        }
                        #endif
                    } else {
                        Logger.videoPlayback.error("❌ Provider \(type(of: provider)) does not conform to VideoControlProvider")
                    }
                }
            }
        
        // Apply gestures to the content using simultaneousGesture which is safer
        // than chaining multiple .gesture() calls
        return ZStack {
            content
                .simultaneousGesture(combinedGesture)
                .simultaneousGesture(provider.player == nil ? nil : dragGesture)
            
            // Fast-forward indicator overlay at the top
            if showIndicator {
                VStack {
                    HStack {
                        Spacer()
                        FastForwardIndicator()
                        Spacer()
                    }
                    .padding(.top, 50) // Position below status bar and any top controls
                    
                    Spacer() // Push the indicator to the top
                }
                // Use rendered effect instead of View animation for better performance
                .transition(.opacity)
            }
        }
    }
}

extension View {
    func addVideoGestures(
        transitionManager: VideoTransitionManager,
        provider: VideoProvider,
        geometry: GeometryProxy,
        dragOffset: Binding<CGFloat>,
        isDragging: Binding<Bool>,
        swipeThreshold: CGFloat = 100,
        animationDuration: Double = 0.15
    ) -> some View {
        self.modifier(
            VideoGestureHandler(
                transitionManager: transitionManager,
                provider: provider,
                geometry: geometry,
                dragOffset: dragOffset,
                isDragging: isDragging,
                swipeThreshold: swipeThreshold,
                animationDuration: animationDuration
            )
        )
    }
}