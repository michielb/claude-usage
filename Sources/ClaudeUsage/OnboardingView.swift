import SwiftUI

struct OnboardingView: View {
    let service: UsageService

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            Text("Claude Usage")
                .font(.title2.bold())

            Text("Tracks your Claude rate limit usage.\nRequires Claude Code with an active login.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 12) {
                stepView(number: 1, text: "Install **Claude Code** (CLI tool)")
                stepView(number: 2, text: "Open Terminal and run: **claude**")
                stepView(number: 3, text: "Sign in with your Anthropic account")
                stepView(number: 4, text: "Come back here and click **Retry**")
            }
            .padding(.vertical, 8)

            HStack(spacing: 12) {
                Link("Get Claude Code", destination: URL(string: "https://docs.anthropic.com/en/docs/claude-code/overview")!)
                    .buttonStyle(.bordered)

                Button("Retry") {
                    service.refresh()
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Works with Claude Max, Pro, and Team plans.")
                .font(.caption)
                .foregroundStyle(.tertiary)

            if service.state == .authExpired {
                Text("Credentials found but could not be read. Try signing out and back in to Claude Code.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(30)
        .frame(width: 340)
    }

    private func stepView(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .frame(width: 20, height: 20)
                .background(Circle().fill(.quaternary))
            Text(.init(text))  // .init for markdown
                .font(.body)
        }
    }
}
