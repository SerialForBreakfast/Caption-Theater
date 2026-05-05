//
//  CaptionTheaterDebugDecisionInspectorView.swift
//  CaptionTheater
//
//  tvOS-only debug surface for eligibility decisions (not production UI).
//

import SwiftUI

/// Lists deterministic scenarios and shows evidence-heavy explanations on tvOS.
///
/// Uses a stacked ``NavigationStack`` instead of ``NavigationSplitView`` so each level gets full
/// horizontal width — split columns are unreliable on tvOS and caused overlapping, clipped panels.
///
/// UI updates follow SwiftUI’s main-actor isolation; inputs stay ``Sendable`` value types.
///
/// - Parameter navigationPath: Owned by ``ContentView`` so switching away from the Debug tab can clear the stack
///   and return you to the baseline scenario list when you come back.
struct CaptionTheaterDebugDecisionInspectorView: View {

    @AppStorage("CaptionTheater.playbackDemoSource")
    private var playbackDemoSourceRawValue = CaptionTheaterPlaybackDemoSource.muxTearsOfSteelHLS.rawValue

    @AppStorage("CaptionTheater.playbackDebugHUD")
    private var playbackDebugHUD = false

    /// Plain-language context for stakeholders who do not read the test bundle.
    private static let debugIntroExplanation = """
    Each row is a fake “moment” in playback: we set only what the decision engine cares about right now \
    (ads, subtitles, viewport guess, DRM posture). Nothing here plays video.

    The engine answers one question: should Caption Theater be allowed for this moment, or stay native? \
    Tap a row to see the reasons. These cases match the automated tests—useful when you want to agree \
    the rules feel right before wiring real AVPlayer data.
    """

    /// Scenario IDs pushed by ``NavigationStack``; clearing returns to the catalog.
    @Binding var navigationPath: [String]

    private let engine = CaptionTheaterDecisionEngine()

    private func inspection(for scenario: CaptionTheaterDebugScenario) -> CaptionTheaterDebugDecisionInspection {
        let decision = engine.decision(for: scenario.snapshot)
        return CaptionTheaterDebugDecisionInspection(
            scenarioTitle: scenario.title,
            scenarioSummary: scenario.summary,
            snapshot: scenario.snapshot,
            decision: decision
        )
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                Section {
                    Text(Self.debugIntroExplanation)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                }

                Section("Playback (engineering)") {
                    Picker("Demo media", selection: $playbackDemoSourceRawValue) {
                        ForEach(CaptionTheaterPlaybackDemoSource.allCases) { source in
                            Text(source.menuTitle).tag(source.rawValue)
                        }
                    }
                    Toggle("Playback debug HUD", isOn: $playbackDebugHUD)
                    Text(
                        "Changing demo media recreates the Playback tab player when you return to that tab (bundle ID scoped)."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Canned playback snapshots") {
                    ForEach(CaptionTheaterDebugScenarioCatalog.scenarios) { scenario in
                        NavigationLink(value: scenario.id) {
                            CaptionTheaterDebugScenarioRowView(scenario: scenario)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Eligibility (debug)")
            .navigationDestination(for: String.self) { scenarioID in
                if let scenario = CaptionTheaterDebugScenarioCatalog.scenarios.first(where: { $0.id == scenarioID }) {
                    CaptionTheaterDebugInspectionDetailView(
                        inspection: inspection(for: scenario),
                        navigationPath: $navigationPath
                    )
                }
            }
        }
    }
}

/// One row of the scenario catalog: wraps text instead of narrowing with ellipsis in a sidebar.
private struct CaptionTheaterDebugScenarioRowView: View {
    let scenario: CaptionTheaterDebugScenario

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(scenario.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(scenario.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

/// tvOS-friendly grouped panel (SwiftUI `GroupBox` is unavailable on tvOS).
private struct CaptionTheaterDebugSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 24)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Detail pane showing grouped evidence with emphasis on fail-closed outcomes.
private struct CaptionTheaterDebugInspectionDetailView: View {
    let inspection: CaptionTheaterDebugDecisionInspection
    @Binding var navigationPath: [String]

    private let horizontalGutter: CGFloat = 56
    private let verticalGutter: CGFloat = 36

    private var outcomeTint: Color {
        if inspection.outcomeHeadline == "Caption Theater eligible" {
            return .green
        }
        if inspection.outcomeHeadline.contains("Uncertain") {
            return .orange
        }
        return .red
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(inspection.outcomeHeadline)
                        .font(.largeTitle.bold())
                        .foregroundStyle(outcomeTint)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(inspection.outcomeDetail)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CaptionTheaterDebugSection(title: "Lifecycle") {
                    Text(inspection.lifecycleTransitionNote)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                CaptionTheaterDebugSection(title: "Inputs") {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(inspection.inputRows.enumerated()), id: \.offset) { _, row in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(row.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(row.value)
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                ForEach(Array(inspection.evidenceSections.enumerated()), id: \.offset) { _, section in
                    CaptionTheaterDebugSection(title: section.title) {
                        if section.rows.isEmpty {
                            Text("None")
                                .foregroundStyle(.tertiary)
                        } else {
                            VStack(alignment: .leading, spacing: 16) {
                                ForEach(Array(section.rows.enumerated()), id: \.offset) { _, row in
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(row.source)
                                            .font(.subheadline.weight(.semibold))
                                        Text(row.message)
                                            .font(.body)
                                            .foregroundStyle(.secondary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalGutter)
            .padding(.vertical, verticalGutter)
        }
        .scrollIndicators(.visible)
        .background(Color.black.opacity(0.001))
        .navigationTitle(inspection.inputRows.first { $0.label == "Scenario" }?.value ?? "Detail")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("All scenarios") {
                    navigationPath.removeAll()
                }
                .accessibilityLabel("Return to scenario list")
            }
        }
    }
}

private struct CaptionTheaterDebugInspectorPreviewHost: View {
    @State private var path: [String] = []

    var body: some View {
        CaptionTheaterDebugDecisionInspectorView(navigationPath: $path)
    }
}

#Preview {
    CaptionTheaterDebugInspectorPreviewHost()
}
