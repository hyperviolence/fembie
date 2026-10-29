import SwiftUI

struct AboutFembieView: View {
    var body: some View {
        ScrollView {
            VStack {
                Text("""
                    fembie
                    Copyright (c) 2026 fembie contributors,
                    
                    App icon artwork by Sogga (mmryrbt@gmail.com), all rights reserved.

                    fembie is an open source estradiol level-tracking app for transfemme individuals that uses an approximation model based on available scientific research to estimate the user's current estradiol levels and see how the speed-of-change and the levels themselves correlate with the user's wellbeing.

                    fembie is in no way a medical app and nothing shown in it can be considered a medical recommendation. The estimation graphs are not real blood levels, both because the scientific research is very limited and the levels vary from one person to another, even with the same regimen.

                    Therefore, the main developer and the contributors are not liable for any decisions users make based on the information provided by the app.

                    Any contributions to fembie are welcome.
                    """)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.gray.opacity(0.7))
                    .textSelection(.enabled)

                if let githubURL = URL(string: "https://github.com/hyperviolence/fembie") {
                    Link(destination: githubURL) {
                        Label("View fembie on GitHub", systemImage: "link")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("About fembie")
        .navigationBarTitleDisplayMode(.inline)
    }
}
