import SwiftUI

struct TutorialView: View {
    let onFinish: () -> Void

    @State private var page: TutorialPage = .welcome
    @State private var hasAcceptedDisclaimer = false

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: Binding(
                get: { page },
                set: { requestedPage in
                    guard hasAcceptedDisclaimer || requestedPage.rawValue <= TutorialPage.disclaimer.rawValue else {
                        return
                    }
                    page = requestedPage
                }
            )) {
                ForEach(TutorialPage.allCases) { page in
                    TutorialPageView(page: page)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            if page == .disclaimer {
                Button("I accept, I won’t use fembie as a medical advice app") {
                    hasAcceptedDisclaimer = true
                    advance()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.large)
                .padding(.horizontal)
                .padding(.bottom)
            } else {
                HStack {
                    Button("Back") {
                        moveBack()
                    }
                    .disabled(page == .welcome)

                    Spacer()

                    Button(page == .extras ? "Get started" : "Next") {
                        if page == .extras {
                            onFinish()
                        } else {
                            advance()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(.background)
        .interactiveDismissDisabled()
        .accessibilityIdentifier("firstRunTutorial")
    }

    private func advance() {
        guard page != .disclaimer || hasAcceptedDisclaimer else { return }
        guard let nextPage = TutorialPage(rawValue: page.rawValue + 1) else { return }
        withAnimation {
            page = nextPage
        }
    }

    private func moveBack() {
        guard let previousPage = TutorialPage(rawValue: page.rawValue - 1) else { return }
        withAnimation {
            page = previousPage
        }
    }
}

private struct TutorialPageIcon: View {
    let page: TutorialPage

    var body: some View {
        Group {
            if page == .welcome {
                Image("FembieIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .clipShape(.rect(cornerRadius: 20))
            } else {
                Image(systemName: page.systemImage)
                    .font(.system(size: 48))
                    .foregroundStyle(page == .disclaimer ? Color.red : Color.accentColor)
            }
        }
        .accessibilityHidden(true)
    }
}

private struct TutorialPageView: View {
    let page: TutorialPage

    var body: some View {
        ScrollView {
            VStack(spacing: 76) {
                TutorialPageIcon(page: page)

                VStack(spacing: 24) {
                    Text(page.title)
                        .font(.largeTitle)
                        .bold()
                        .multilineTextAlignment(.center)

                    pageDescription
                        .font(.body)
                        .foregroundStyle(page == .disclaimer ? .red : .secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: page == .disclaimer ? 480 : 560)
                        .padding(.horizontal, page == .disclaimer ? 24 : 0)
                }

                pageIllustration
            }
            .padding(.top, 64)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, minHeight: 500)
        }
    }

    @ViewBuilder
    private var pageDescription: some View {
        switch page {
        case .welcome:
            Text("fembie helps you record your regimen, explore estimated levels over time, and notice patterns in your wellbeing.")
        case .disclaimer:
            Text("fembie is an educational tracking and visualization tool. It is not a medical app, medical device, diagnostic tool, or source of medical advice. Its estimates are not measurements and must not be used to make treatment decisions.")
        case .overview:
            Text("Use fembie in three simple stages.")
        case .extras:
            Text("You can also add lab results to adjust your graph, or create custom metrics to make fembie fit the way you track.")
        }
    }

    @ViewBuilder
    private var pageIllustration: some View {
        switch page {
        case .welcome:
            WelcomeIllustration()
        case .disclaimer:
            DisclaimerIllustration()
        case .overview:
            OverviewIllustration()
        case .extras:
            ExtrasIllustration()
        }
    }
}

private struct WelcomeIllustration: View {
    var body: some View {
        VStack(spacing: 28) {
            Label("Record", systemImage: "square.and.pencil")
            Label("Estimate", systemImage: "chart.xyaxis.line")
            Label("Reflect", systemImage: "heart")
        }
        .font(.title3)
        .foregroundStyle(.tint)
        .padding()
        .frame(maxWidth: .infinity)
        .background(.tint.opacity(0.1), in: .rect(cornerRadius: 20))
    }
}

private struct DisclaimerIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Not medical advice", systemImage: "xmark.circle")
            Label("Not a replacement for a clinician", systemImage: "person.crop.circle.badge.exclamationmark")
            Label("Not a measurement of your hormone levels", systemImage: "waveform.path.ecg")
        }
        .font(.headline)
        .foregroundStyle(.red)
        .padding(24)
        .frame(maxWidth: 480, alignment: .leading)
        .background(.red.opacity(0.12), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(.red.opacity(0.35), lineWidth: 1)
        }
        .padding(.horizontal, 32)
    }
}

private struct OverviewIllustration: View {
    var body: some View {
        VStack(spacing: 24) {
            Label("Enter regimen", systemImage: "calendar")
            Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
            Label("Watch the graph", systemImage: "chart.xyaxis.line")
            Image(systemName: "arrow.down")
                .foregroundStyle(.secondary)
            Label("Track wellbeing", systemImage: "heart")
        }
        .font(.headline)
        .padding(24)
        .frame(maxWidth: 480, alignment: .center)
        .background(.blue.opacity(0.1), in: .rect(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}

private struct ExtrasIllustration: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Label("Add lab results", systemImage: "testtube.2")
            Label("Create custom metrics", systemImage: "slider.horizontal.3")
            Text("Choose the information that helps you notice patterns.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: 480, alignment: .leading)
        .background(.purple.opacity(0.1), in: .rect(cornerRadius: 20))
        .padding(.horizontal, 32)
    }
}
