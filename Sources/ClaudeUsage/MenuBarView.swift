import SwiftUI

struct MenuBarView: View {
    let service: UsageService

    var body: some View {
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
        } else if service.lastError != nil {
            Text("C:err")
        } else {
            Text("C:...")
        }
    }
}
