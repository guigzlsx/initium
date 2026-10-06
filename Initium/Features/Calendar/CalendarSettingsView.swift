import SwiftUI
import SwiftData

struct CalendarSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: CalendarIntegrationViewModel

    @State private var showingPermissionExplanation = false
    @State private var showingDisconnectConfirmation = false

    init(provider: (any CalendarEventProvider)? = nil) {
        _viewModel = StateObject(
            wrappedValue: CalendarIntegrationViewModel(
                provider: provider ?? EventKitCalendarProvider()
            )
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
                header

                if viewModel.isConnected {
                    connectedContent
                } else {
                    connectionContent
                }
            }
            .padding(.horizontal, AppTheme.screenHorizontalPadding)
            .padding(.top, InitiumSpacing.md)
            .padding(.bottom, InitiumSpacing.xl)
        }
        .scrollIndicators(.hidden)
        .initiumScreen()
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(LocalizedStringKey("calendar.close")) { dismiss() }
            }
        }
        .task {
            await viewModel.load()
        }
        .sheet(isPresented: $showingPermissionExplanation) {
            CalendarPermissionExplanationView {
                showingPermissionExplanation = false
                Task { await viewModel.requestAccess() }
            } onLater: {
                showingPermissionExplanation = false
            }
            .presentationDetents([.medium])
        }
        .confirmationDialog(
            LocalizedStringKey("calendar.disconnect.confirm_title"),
            isPresented: $showingDisconnectConfirmation,
            titleVisibility: .visible
        ) {
            Button(LocalizedStringKey("calendar.disconnect.confirm"), role: .destructive) {
                viewModel.disconnect(in: modelContext)
            }
            Button(LocalizedStringKey("calendar.cancel"), role: .cancel) { }
        } message: {
            Text(LocalizedStringKey("calendar.disconnect.confirm_message"))
        }
        .alert(
            LocalizedStringKey("calendar.error.refresh_title"),
            isPresented: errorBinding
        ) {
            Button(LocalizedStringKey("calendar.ok"), role: .cancel) { }
        } message: {
            Text(viewModel.errorMessage ?? InitiumLocalization.string("calendar.error.unavailable"))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey("calendar.settings.eyebrow"))
                .font(AppTheme.Typography.caption)
                .tracking(1.8)
                .foregroundStyle(AppTheme.accent)

            Text(LocalizedStringKey("calendar.settings.title"))
                .font(AppTheme.Typography.largeTitle)
                .foregroundStyle(AppTheme.primaryText)

            Text(LocalizedStringKey("calendar.settings.subtitle"))
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)
        }
    }

    private var connectionContent: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text(LocalizedStringKey("calendar.connect.title"))
                .font(AppTheme.Typography.cardTitle)

            Text(LocalizedStringKey("calendar.connect.body"))
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)

            if viewModel.authorizationStatus == .denied || viewModel.authorizationStatus == .restricted || viewModel.authorizationStatus == .writeOnly {
                Text(LocalizedStringKey("calendar.access.disabled"))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.warmAccent)

                Button(LocalizedStringKey("calendar.open_settings")) {
                    viewModel.openSystemSettings()
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
            } else {
                Button(LocalizedStringKey("calendar.connect.button")) {
                    showingPermissionExplanation = true
                }
                .buttonStyle(InitiumPrimaryButtonStyle())
            }
        }
        .initiumCard()
    }

    private var connectedContent: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.md) {
            HStack {
                Label(LocalizedStringKey("calendar.connected"), systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Text(InitiumLocalization.string("calendar.selected_count", viewModel.selectedCount))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 8) {
                Button(LocalizedStringKey("calendar.select_all")) {
                    Task { await viewModel.selectAll(in: modelContext) }
                }
                .buttonStyle(InitiumSecondaryButtonStyle())

                Button(LocalizedStringKey("calendar.deselect_all")) {
                    Task { await viewModel.deselectAll(in: modelContext) }
                }
                .buttonStyle(InitiumSecondaryButtonStyle())
            }

            ForEach(viewModel.calendars) { calendar in
                Button {
                    Task { await viewModel.toggleCalendar(calendar, in: modelContext) }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.selectedCalendarIdentifiers.contains(calendar.id) ? "checkmark.square.fill" : "square")
                            .font(.title3)
                            .foregroundStyle(viewModel.selectedCalendarIdentifiers.contains(calendar.id) ? AppTheme.accent : AppTheme.mutedText)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(calendar.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(AppTheme.primaryText)

                            if let sourceTitle = calendar.sourceTitle {
                                Text(sourceTitle)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.mutedText)
                            }
                        }

                        Spacer()
                    }
                    .frame(minHeight: 52)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(InitiumLocalization.string(
                    "calendar.selection.accessibility",
                    calendar.title,
                    viewModel.selectedCalendarIdentifiers.contains(calendar.id)
                        ? InitiumLocalization.string("calendar.selected")
                        : InitiumLocalization.string("calendar.not_selected")
                ))
            }

            if viewModel.calendars.isEmpty {
                Text(LocalizedStringKey("calendar.none_available"))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 8) {
                Button(LocalizedStringKey("calendar.refresh")) {
                    Task { await viewModel.refreshAndSync(in: modelContext) }
                }
                .buttonStyle(InitiumSecondaryButtonStyle())

                if viewModel.syncState == .syncing {
                    ProgressView()
                        .tint(AppTheme.accent)
                        .accessibilityLabel(LocalizedStringKey("calendar.syncing"))
                }
            }

            Button(LocalizedStringKey("calendar.disconnect")) {
                showingDisconnectConfirmation = true
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppTheme.secondaryText)
            .frame(minHeight: 44, alignment: .leading)
        }
        .initiumCard()
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }
}

private struct CalendarPermissionExplanationView: View {
    let onContinue: () -> Void
    let onLater: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: InitiumSpacing.lg) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(AppTheme.accent)

            Text(LocalizedStringKey("calendar.permission.title"))
                .font(AppTheme.Typography.largeTitle)

            Text(LocalizedStringKey("calendar.permission.body"))
                .font(AppTheme.Typography.secondary)
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 0)

            Button(LocalizedStringKey("calendar.continue"), action: onContinue)
                .buttonStyle(InitiumPrimaryButtonStyle())

            Button(LocalizedStringKey("calendar.later"), action: onLater)
                .buttonStyle(InitiumSecondaryButtonStyle())
        }
        .padding(24)
        .initiumScreen()
    }
}

#if DEBUG
#Preview("Calendar settings") {
    CalendarSettingsView(
        provider: MockCalendarEventProvider(
            calendars: [
                CalendarDescriptor(id: "personal", title: "Personnel", colorHex: nil, sourceTitle: "iCloud"),
                CalendarDescriptor(id: "work", title: "Travail", colorHex: nil, sourceTitle: "Google")
            ]
        )
    )
    .modelContainer(PersistenceController.preview)
}
#endif
