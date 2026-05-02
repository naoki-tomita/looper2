import SwiftUI

struct ContentView: View {
    @StateObject private var session = LoopSession()

    var body: some View {
        ZStack {
            DesignTokens.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Header ──────────────────────────────────────────
                HStack {
                    Text("LOOPER")
                        .font(.system(.title2, design: .monospaced).weight(.black))
                        .foregroundColor(.white)
                        .tracking(8)

                    Spacer()

                    // Input source indicator
                    InputIndicatorView()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 10)

                Divider()
                    .background(DesignTokens.borderSubtle)

                // ── Track list ───────────────────────────────────────
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(session.tracks) { track in
                            TrackRowView(track: track)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }

                Divider()
                    .background(DesignTokens.borderSubtle)

                // ── Master controls ──────────────────────────────────
                MasterControlBar(session: session)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
            }
        }
        .preferredColorScheme(.dark)
    }
}

// Shows whether audio is coming from built-in mic or external interface
private struct InputIndicatorView: View {
    @State private var label = "BUILT-IN"

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(DesignTokens.ledGreen)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(DesignTokens.ledDim)
                .tracking(1)
        }
        .onReceive(
            NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
        ) { _ in
            updateLabel()
        }
        .onAppear { updateLabel() }
    }

    private func updateLabel() {
        let session = AVAudioSession.sharedInstance()
        let inputs = session.currentRoute.inputs
        if inputs.contains(where: { $0.portType != .builtInMic }) {
            label = "EXT IN"
        } else {
            label = "BUILT-IN"
        }
    }
}

// Make AVAudioSession import available
import AVFoundation
