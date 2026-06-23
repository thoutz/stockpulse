import SwiftUI

struct VerdictBadge: View {
    let verdict: RippleVerdict
    var compact: Bool = false

    var color: Color { DS.Color.verdict(verdict) }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: verdict.icon)
                .font(.system(size: compact ? 8 : 10, weight: .bold))
            Text(verdict.label)
                .font(DS.Font.mono(compact ? 8 : 10, weight: .bold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, compact ? 6 : 8)
        .padding(.vertical, compact ? 2 : 3)
        .background(color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
}
