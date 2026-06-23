import SwiftUI

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = resolvedMaxWidth(proposal: proposal, boundsWidth: nil)
        let laidOutRows = rows(maxWidth: maxW, subviews: subviews)
        let rowHeights = laidOutRows.map { rowHeight($0) }
        let totalHeight = rowHeights.reduce(0) { $0 + $1 + spacing }
        let contentWidth = laidOutRows.map { rowWidth($0) }.max() ?? 0
        let width = proposal.width ?? min(contentWidth, maxW.isFinite ? maxW : contentWidth)
        return CGSize(width: width, height: max(0, totalHeight - spacing))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = resolvedMaxWidth(proposal: proposal, boundsWidth: bounds.width)
        var y = bounds.minY
        for row in rows(maxWidth: maxW, subviews: subviews) {
            var x = bounds.minX
            let rowH = rowHeight(row)
            for sv in row {
                let s = sv.sizeThatFits(.unspecified)
                sv.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(s))
                x += s.width + spacing
            }
            y += rowH + spacing
        }
    }

    private func resolvedMaxWidth(proposal: ProposedViewSize, boundsWidth: CGFloat?) -> CGFloat {
        if let w = proposal.width, w.isFinite, w > 0 { return w }
        if let w = boundsWidth, w > 0 { return w }
        return .infinity
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidthUsed: CGFloat = 0
        let wraps = maxWidth.isFinite && maxWidth > 0

        for sv in subviews {
            let size = sv.sizeThatFits(.unspecified)
            if wraps, rowWidthUsed + size.width > maxWidth, !rows.last!.isEmpty {
                rows.append([])
                rowWidthUsed = 0
            }
            rows[rows.count - 1].append(sv)
            rowWidthUsed += size.width + spacing
        }
        return rows
    }

    private func rowHeight(_ row: [LayoutSubview]) -> CGFloat {
        row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
    }

    private func rowWidth(_ row: [LayoutSubview]) -> CGFloat {
        let widths = row.map { $0.sizeThatFits(.unspecified).width }
        guard !widths.isEmpty else { return 0 }
        return widths.reduce(0, +) + spacing * CGFloat(widths.count - 1)
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
