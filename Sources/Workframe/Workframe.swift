import AppKit
import Combine
import Foundation
import SwiftUI
import WorkframeCore

@MainActor
final class WorkframeStore: ObservableObject {
    @Published private(set) var workspaces: [Workspace] = []
    @Published private(set) var archived: [ArchivedWorkspace] = []
    @Published private(set) var repositories: [String] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published var archiveCandidate: Workspace?
    @Published var showingNewWorkspace = false
    @Published private(set) var availableUpdate: HomebrewCaskUpdate?
    @Published private(set) var isCheckingForUpdate = false
    @Published private(set) var isUpdating = false
    @Published private(set) var updateInstalled = false

    var commandPath: String? { WorkframeCommand.resolve()?.executable }

    init() {
        refresh()
        checkForUpdate()
    }

    var nextAction: String {
        switch workspaces.count {
        case 0: "Create your first workspace"
        case 1: "Continue \(workspaces[0].title)"
        default: "Choose where to continue"
        }
    }

    func refresh() {
        guard let command = WorkframeCommand.resolve() else {
            errorMessage = "Workframe CLI was not found. Install Workframe, then reopen the app."
            return
        }
        isLoading = true
        errorMessage = nil
        Task.detached {
            do {
                let active = try command.run(["worktrees"])
                let archived = try command.run(["archived"])
                let repositories = try command.run(["repos"])
                await MainActor.run {
                    self.isLoading = false
                    guard active.status == 0, archived.status == 0, repositories.status == 0 else {
                        self.errorMessage = Self.failureMessage(from: [active, archived, repositories])
                        return
                    }
                    self.workspaces = WorkframeOutput.workspaces(active.output)
                    self.archived = WorkframeOutput.archived(archived.output)
                    self.repositories = WorkframeOutput.lines(repositories.output)
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func checkForUpdate() {
        guard let brew = HomebrewCommand.resolve(), !isCheckingForUpdate, !isUpdating else { return }
        isCheckingForUpdate = true
        Task.detached {
            do {
                let result = try brew.run(["outdated", "--cask", "--json=v2", "workframe"])
                let update = result.status == 0
                    ? HomebrewOutput.caskUpdate(result.output, token: "workframe")
                    : nil
                await MainActor.run {
                    self.isCheckingForUpdate = false
                    self.availableUpdate = update
                }
            } catch {
                await MainActor.run {
                    self.isCheckingForUpdate = false
                }
            }
        }
    }

    func installUpdate() {
        guard let brew = HomebrewCommand.resolve(), let update = availableUpdate else { return }
        isUpdating = true
        errorMessage = nil
        Task.detached {
            do {
                // The cask owns both Workframe.app and its bundled CLI, so one
                // upgrade is an atomic product update rather than two packages
                // that can drift apart.
                let result = try brew.run(["upgrade", "--cask", update.token])
                await MainActor.run {
                    self.isUpdating = false
                    if result.status == 0 {
                        self.availableUpdate = nil
                        self.updateInstalled = true
                    } else {
                        self.errorMessage = "Workframe update failed.\n\n\(Self.message(for: result))"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isUpdating = false
                    self.errorMessage = "Workframe update failed.\n\n\(error.localizedDescription)"
                }
            }
        }
    }

    func relaunchAfterUpdate() {
        let launch = Process()
        launch.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        launch.arguments = ["-n", Bundle.main.bundleURL.path]
        do {
            try launch.run()
            NSApplication.shared.terminate(nil)
        } catch {
            errorMessage = "Workframe was updated, but could not relaunch automatically. Quit and reopen it to finish the update."
        }
    }

    func createWorkspace(repository: String, task: String) {
        perform("Creating workspace") { command in
            try command.run(["new", repository, task])
        }
    }

    func openInEditor(_ workspace: Workspace) {
        perform("Opening \(workspace.title)", refreshAfter: false) { command in
            try command.run(["open", workspace.path])
        }
    }

    func reveal(_ workspace: Workspace) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: workspace.path)])
    }

    func archive(_ workspace: Workspace, discardChanges: Bool = false) {
        perform("Archiving \(workspace.title)") { command in
            var arguments = ["archive", workspace.path, "--yes"]
            if discardChanges { arguments.append("--force") }
            return try command.run(arguments)
        }
    }

    func restore(_ workspace: ArchivedWorkspace) {
        perform("Restoring \(workspace.repository) / \(workspace.feature)") { command in
            try command.run(["restore", workspace.repository, workspace.branch])
        }
    }

    private func perform(_ action: String, refreshAfter: Bool = true, operation: @escaping @Sendable (WorkframeCommand) throws -> CommandResult) {
        guard let command = WorkframeCommand.resolve() else {
            errorMessage = "Workframe CLI was not found."
            return
        }
        isLoading = true
        errorMessage = nil
        Task.detached {
            do {
                let result = try operation(command)
                await MainActor.run {
                    self.isLoading = false
                    if result.status == 0 {
                        if refreshAfter { self.refresh() }
                    } else {
                        self.errorMessage = "\(action) failed.\n\n\(Self.message(for: result))"
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = "\(action) failed.\n\n\(error.localizedDescription)"
                }
            }
        }
    }

    private static func failureMessage(from results: [CommandResult]) -> String {
        results.first(where: { $0.status != 0 }).map(message(for:)) ?? "Workframe could not load its state."
    }

    private static func message(for result: CommandResult) -> String {
        let message = result.error.trimmingCharacters(in: .whitespacesAndNewlines)
        return message.isEmpty ? result.output.trimmingCharacters(in: .whitespacesAndNewlines) : message
    }
}

@main
struct WorkframeApp: App {
    @StateObject private var store = WorkframeStore()

    var body: some Scene {
        MenuBarExtra {
            WorkframeMenu(store: store)
        }
        label: {
            WorkframeStatusMark()
                .fill(.primary)
                // A compact 4:3 template glyph fits the standard menu-bar
                // rhythm while preserving the supplied mark's proportions.
                .frame(width: 24, height: 18)
                .accessibilityLabel("Workframe")
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(store: store)
        }
    }
}

struct WorkframeMenu: View {
    @ObservedObject var store: WorkframeStore

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                GlassEffectContainer(spacing: 12) {
                    menuBody
                }
            } else {
                menuBody
            }
        }
        .padding(12)
        .frame(width: 390)
        .alert("Workframe", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .alert("Archive \(store.archiveCandidate?.title ?? "workspace")?", isPresented: Binding(
            get: { store.archiveCandidate != nil },
            set: { if !$0 { store.archiveCandidate = nil } }
        )) {
            Button("Cancel", role: .cancel) { store.archiveCandidate = nil }
            Button("Archive", role: .destructive) {
                if let workspace = store.archiveCandidate { store.archive(workspace) }
                store.archiveCandidate = nil
            }
        } message: {
            Text("This removes the local worktree but keeps its branch, so it can be restored later. Uncommitted changes are never discarded automatically.")
        }
        .sheet(isPresented: $store.showingNewWorkspace) {
            NewWorkspaceSheet(store: store)
        }
    }

    private var menuBody: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            content
            footer
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Image(systemName: "square.3.layers.3d.top.filled")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 34, height: 34)
                .workframeGlass(in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text("Workframe").font(.headline.weight(.semibold))
                Text(store.nextAction).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            if store.isLoading || store.isCheckingForUpdate { ProgressView().controlSize(.small) }
            if let update = store.availableUpdate {
                Button("Update \(update.availableVersion)") { store.installUpdate() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .disabled(store.isUpdating)
                    .accessibilityLabel("Update Workframe to \(update.availableVersion)")
            } else if store.updateInstalled {
                Button("Restart") { store.relaunchAfterUpdate() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityLabel("Restart Workframe to finish updating")
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 14)
    }

    @ViewBuilder private var content: some View {
        if store.commandPath == nil {
            ContentUnavailableView("Workframe CLI not found", systemImage: "terminal", description: Text("Install the CLI first; this app is its human-friendly companion."))
                .frame(maxWidth: .infinity)
                .padding(24)
                .workframeGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else if store.isLoading && store.workspaces.isEmpty {
            ProgressView("Reading your workspaces…")
                .frame(maxWidth: .infinity)
                .padding(24)
                .workframeGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else if store.workspaces.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("No active workspaces").font(.headline)
                Text("Start work without remembering a command.").foregroundStyle(.secondary)
                Button("Create workspace…") { store.showingNewWorkspace = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .workframeGlass(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Active work")
                ForEach(store.workspaces) { workspace in
                    WorkspaceRow(workspace: workspace, store: store)
                }
                Button { store.showingNewWorkspace = true } label: {
                    Label("New workspace…", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .padding(.top, 2)
            }
        }

        if !store.archived.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Paused work")
                ForEach(store.archived.prefix(3)) { workspace in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(workspace.repository) / \(workspace.feature)")
                            Text("\(workspace.agent) · \(workspace.lastUpdated)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Restore") { store.restore(workspace) }.controlSize(.small)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .workframeGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous), interactive: true)
                }
            }
            .padding(.top, 16)
        }
    }

    private var footer: some View {
        HStack {
            Button {
                store.refresh()
                store.checkForUpdate()
            } label: { Label("Refresh", systemImage: "arrow.clockwise") }
            Spacer()
            SettingsLink { Label("Settings", systemImage: "gear") }
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        .controlSize(.small)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .workframeGlass(in: Capsule(), interactive: true)
        .padding(.top, 16)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .padding(.leading, 4)
    }
}

struct WorkspaceRow: View {
    let workspace: Workspace
    @ObservedObject var store: WorkframeStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 24, height: 24)
                .workframeGlass(in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workspace.feature).font(.body.weight(.medium)).lineLimit(1)
                Text("\(workspace.repository) · \(workspace.location)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Menu {
                Button("Open in editor") { store.openInEditor(workspace) }
                Button("Reveal in Finder") { store.reveal(workspace) }
                Divider()
                Button("Archive…", role: .destructive) { store.archiveCandidate = workspace }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { store.openInEditor(workspace) }
        .workframeGlass(in: RoundedRectangle(cornerRadius: 18, style: .continuous), interactive: true)
    }
}

struct NewWorkspaceSheet: View {
    @ObservedObject var store: WorkframeStore
    @Environment(\.dismiss) private var dismiss
    @State private var repository = ""
    @State private var task = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Start a workspace").font(.title2.weight(.semibold))
            Text("Workframe creates an isolated branch and folder for this task.").foregroundStyle(.secondary)
            Picker("Repository", selection: $repository) {
                Text("Choose a repository").tag("")
                ForEach(store.repositories, id: \.self) { Text($0).tag($0) }
            }
            TextField("What are you working on?", text: $task, prompt: Text("e.g. payment-retry"))
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Create workspace") {
                    store.createWorkspace(repository: repository, task: task)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(repository.isEmpty || task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 410)
        .onAppear {
            if repository.isEmpty { repository = store.repositories.first ?? "" }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var store: WorkframeStore

    var body: some View {
        Form {
            LabeledContent("CLI") {
                Text(store.commandPath ?? "Not found").textSelection(.enabled)
            }
            Text("The menubar app reads and acts through the installed Workframe CLI. Agents should continue using that CLI directly.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Refresh status") { store.refresh() }
        }
        .padding(20)
        .frame(width: 480)
    }
}
