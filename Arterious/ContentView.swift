import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square.fill")
                }
            
            LLMInsightView()
                .tabItem {
                    Label("AI Insight", systemImage: "sparkles")
                }
            
            NavigationStack {
                ContentUnavailableView(
                    "Trends Coming Soon",
                    systemImage: "chart.xyaxis.line",
                    description: Text("View 7-30 day health trend lines and comparisons.")
                )
                .navigationTitle("Trends")
            }
            .tabItem {
                Label("Trends", systemImage: "chart.line.uptrend.xyaxis")
            }
        }
        .tint(.red)
    }
}

#Preview {
    ContentView()
}
