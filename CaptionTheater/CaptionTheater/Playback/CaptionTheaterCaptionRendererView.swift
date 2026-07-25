//
//  CaptionTheaterCaptionRendererView.swift
//  CaptionTheater
//
//  Dedicated Caption Theater caption band renderer (CT-0404): current cue prominent, retained cues
//  de-emphasized, no future cues, no transcript wall. Consumes a precomputed ``CaptionTheaterCaptionRenderPlan``
//  rather than recomputing cue policy or reading-region geometry — callers size this view from
//  ``CaptionTheaterLayoutGeometry/captionReadingRect``.
//

import SwiftUI

/// Renders the current/retained caption rows for one ``CaptionTheaterCaptionRenderPlan``.
///
/// Stays passive on tvOS by design: `.focusable(false)` throughout so Siri Remote focus never lands on caption
/// text, matching the debug/production separation used elsewhere in the shell.
struct CaptionTheaterCaptionRendererView: View {

    let plan: CaptionTheaterCaptionRenderPlan
    let textSizePreset: CaptionTheaterCaptionTextSizePreset
    let isScrollingHistoryEnabled: Bool

    var body: some View {
        Group {
            if isScrollingHistoryEnabled {
                scrollingHistory
            } else {
                singleLine
            }
        }
        .focusable(false)
    }

    /// Newest-first scrolling column; older retained rows remain visible below the current row.
    private var scrollingHistory: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .center, spacing: 12) {
                    if plan.isEmpty {
                        emptyStateText
                    } else {
                        ForEach(plan.rows) { row in
                            rowText(row)
                                .id(row.id)
                        }
                    }
                }
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
            }
            .focusable(false)
            .onChange(of: plan.rows.first?.id) { _, newId in
                guard let newId else {
                    return
                }
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo(newId, anchor: .top)
                }
            }
        }
    }

    /// Latest cue only; same plan, without scroll history chrome.
    private var singleLine: some View {
        VStack(alignment: .center, spacing: 8) {
            if let row = plan.rows.first {
                rowText(row)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                emptyStateText
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var emptyStateText: some View {
        Text(emptyStateMessage)
            .font(textSizePreset.captionOverlayFont)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.65)
            .lineLimit(8)
            .padding(.horizontal, 4)
    }

    private var emptyStateMessage: String {
        switch plan.emptyReason {
        case .playbackPaused:
            return "Paused"
        case .waitingForCues, nil:
            return "Waiting for captions…"
        }
    }

    private func rowText(_ row: CaptionTheaterCaptionRenderRow) -> some View {
        Text(row.text)
            .font(textSizePreset.captionOverlayFont)
            .fontWeight(row.emphasis == .current ? .semibold : .regular)
            .foregroundStyle(row.emphasis == .current ? Color.primary : Color.secondary)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.65)
            .lineLimit(row.maximumLines)
            .frame(maxWidth: .infinity)
            .opacity(row.opacity)
            .animation(.easeInOut(duration: 0.35), value: row.emphasis)
            .accessibilityHidden(true)
    }
}
