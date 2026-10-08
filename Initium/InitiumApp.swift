import SwiftUI
import SwiftData
import Foundation
import EventKit

@main
struct InitiumApp: App {
    private let modelContainer: ModelContainer

    @StateObject private var appState = AppState()
    @StateObject private var authentication: AuthenticationService
    @StateObject private var entryFlow: EntryFlowViewModel
    @StateObject private var templateCatalog = RoutineTemplateCatalogViewModel()
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

        let authentication = AuthenticationService()
        _authentication = StateObject(wrappedValue: authentication)
        _entryFlow = StateObject(wrappedValue: EntryFlowViewModel())
    }

    var body: some Scene {
        WindowGroup {
            InitiumRootView()
                .environmentObject(appState)
                .environmentObject(authentication)
                .environmentObject(entryFlow)
                .environmentObject(templateCatalog)
                .modelContainer(modelContainer)
                .tint(AppTheme.accent)
                .preferredColorScheme(InitiumAppearance(rawValue: appearance)?.colorScheme)
        }
    }
}

private struct InitiumRootView: View {
    @EnvironmentObject private var authentication: AuthenticationService
    @EnvironmentObject private var entryFlow: EntryFlowViewModel
    @EnvironmentObject private var templateCatalog: RoutineTemplateCatalogViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var calendarSyncCoordinator = CalendarSyncCoordinator()

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            Group {
                if entryFlow.state == .mainApp {
                    RootTabView()
                } else {
                    switch authentication.state {
                    case .restoring:
                        ProgressView()
                            .tint(AppTheme.accent)
                    case .loggedOut:
                        EntryFlowView(viewModel: entryFlow)
                    case .loggedIn:
                        if authentication.isPasswordRecoveryActive {
                            PasswordRecoveryView()
                        } else {
                            RootTabView()
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: entryFlow.state)
        .task {
            await authentication.restoreSession()
            Task {
                await templateCatalog.loadAndRefresh()
            }
            if authentication.state == .loggedIn {
                await calendarSyncCoordinator.syncIfNeeded(in: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active, authentication.state == .loggedIn else { return }
            Task {
                await calendarSyncCoordinator.syncIfNeeded(in: modelContext)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged)) { _ in
            Task {
                await calendarSyncCoordinator.syncIfNeeded(in: modelContext)
            }
        }
        .onOpenURL { url in
            Task {
                await authentication.handleAuthCallback(url)
            }
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
        .toolbarBackground(AppTheme.background, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarColorScheme(.dark, for: .tabBar)
        .tint(AppTheme.primaryText)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .modifier(StableTabBarModifier())
    }
}

private struct StableTabBarModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.tabBarMinimizeBehavior(.never)
        } else {
            content
        }
    }
}
