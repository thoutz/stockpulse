import SwiftUI

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(DS.Font.mono(10, weight: .bold))
            .foregroundStyle(DS.Color.textDim)
            .tracking(1.0)
            .textCase(.uppercase)
    }
}
