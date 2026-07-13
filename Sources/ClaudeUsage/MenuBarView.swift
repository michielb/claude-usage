import SwiftUI

struct MenuBarView: View {
    let service: UsageService
    var settings: AppSettings? = nil

    var body: some View {
        if settings?.isCompactMode == true {
            Image(nsImage: ProgressBarRenderer.renderCompact())
        } else {
            switch service.state {
            case .needsSignIn, .authExpired:
                Image(systemName: "questionmark.circle")
            case .noSession:
                Image(nsImage: ProgressBarRenderer.renderCompact())
            case .ready, .loading, .reconnecting:
                // Keep showing the last-known bar during a quiet refresh/retry;
                // only fall back to "…" when we genuinely have nothing yet.
                if service.usage != nil {
                    let segments = [
                        BarSegment(
                            utilization: service.fiveHourUtilization,
                            target: service.fiveHourTarget,
                            label: "5h"
                        ),
                        BarSegment(
                            utilization: service.sevenDayUtilization,
                            target: service.sevenDayTarget,
                            label: "7d"
                        )
                    ]
                    Image(nsImage: ProgressBarRenderer.render(segments: segments))
                } else {
                    Text("C:…")
                }
            }
        }
    }
}
