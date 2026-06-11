import SwiftUI

struct MenuBarView: View {
    let service: UsageService
    var settings: AppSettings? = nil

    var body: some View {
        if settings?.isCompactMode == true {
            Image(nsImage: ProgressBarRenderer.renderCompact())
        } else {
            switch service.state {
            case .ready:
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
            case .noSession:
                Image(nsImage: ProgressBarRenderer.renderCompact())
            case .noCredentials, .invalidCredentials:
                Image(systemName: "questionmark.circle")
            case .httpError, .networkError:
                Text("C:err")
            case .loading:
                Text("C:...")
            }
        }
    }
}
