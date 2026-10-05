import SwiftUI
import SwiftData
import Foundation

@main
struct InitiumApp: App {
    private let modelContainer: ModelContainer

    @StateObject private var appState = AppState()
    @AppStorage("initium.appearance") private var appearance = InitiumAppearance.system.rawValue

    init() {
        do {
            #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            let demoMode = arguments.contains("--initium-ui-demo") || arguments.contains("--initium-transition-demo")
            #else
            let demoMode = false
            #endif

            modelContainer = try PersistenceController.makeContainer(inMemory: demoMode)

            #if DEBUG
            if demoMode {
                PreviewData.insertRichDemo(
                    into: modelContainer.mainContext,
                    activeTransition: arguments.contains("--initium-transition-demo")
                )
            }
            #endif
        } catch {
            fatalError("Unable to create the Initium model container: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
                .tint(AppTheme.accent)
                .preferredColorScheme(InitiumAppearance(rawValue: appearance)?.colorScheme)
        }
    }
}

private struct RootTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "calendar")
                }
                .tag(AppTab.today)

            NowView()
                .tabItem {
                    Label("Now", systemImage: "play.circle")
                }
                .tag(AppTab.now)

            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "checklist")
                }
                .tag(AppTab.routines)

            InsightsView()
                .tabItem {
                    Label("Insights", systemImage: "chart.bar")
                }
                .tag(AppTab.insights)
        }
        .toolbarBackground(AppTheme.cardBackground, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .tint(AppTheme.accent)
    }
}
