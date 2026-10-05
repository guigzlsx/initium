import SwiftUI
import Foundation

enum AppTab: Hashable {
    case today
    case now
    case routines
    case insights
}

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: AppTab

    #if DEBUG
    var launchEditorDemo: Bool
    var launchReplanDemo: Bool
    #endif

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--initium-routines-demo") {
            selectedTab = .routines
        } else if arguments.contains("--initium-insights-demo") {
            selectedTab = .insights
        } else if arguments.contains("--initium-transition-demo") {
            selectedTab = .now
        } else {
            selectedTab = .today
        }
        launchEditorDemo = arguments.contains("--initium-editor-demo")
        launchReplanDemo = arguments.contains("--initium-replan-demo")
        #else
        selectedTab = .today
        #endif
    }
}
