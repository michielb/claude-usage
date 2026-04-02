import SwiftUI

struct MenuBarView: View {
    let service: UsageService

    var body: some View {
        if service.usage != nil {
            Image(nsImage: ProgressBarRenderer.render(
                utilization: service.fiveHourUtilization,
                target: service.targetUtilization,
                timeLeft: service.fiveHourResetString
            ))
        } else if service.lastError != nil {
            Text("C:err")
        } else {
            Text("C:...")
        }
    }
}
