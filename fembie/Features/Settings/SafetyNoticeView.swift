import SwiftUI

struct SafetyNoticeView: View {
    var body: some View {
        ScrollView {
            Text("""
                fembie is intended solely for personal recordkeeping and exploration of mathematical estimates. It is not intended to diagnose, prevent, monitor, or treat any medical condition, recommend treatment, or guide medication decisions.

                Estimated estradiol levels, projections, and rates of change are model outputs—not measurements of your blood or reliable predictions of your individual response. They may differ substantially from your actual levels. Scientific evidence is limited, and individuals may respond differently to the same regimen. Calibration using a lab result does not make subsequent estimates measured or medically reliable.

                Wellbeing charts show recorded ratings alongside estimates. They do not establish causation, treatment effectiveness, or safety. User-entered lab results are records supplied by you; fembie does not independently verify them.

                Do not use this app to start, stop, or change medication, doses, injection timing, or medical care. Consult a qualified healthcare professional about treatment and laboratory testing. Do not disregard medical advice or delay seeking care because of information displayed here.

                The app is provided “as is,” without warranties of accuracy, completeness, reliability, or fitness for a particular purpose, to the fullest extent permitted by law. To that same extent, the developer and contributors disclaim liability for loss, injury, or damage arising from use of, or reliance on, the app. Nothing in this notice excludes liability or rights that applicable law does not permit to be excluded.
                """)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding()
        }
        .navigationTitle("Safety notice")
        .navigationBarTitleDisplayMode(.inline)
    }
}
