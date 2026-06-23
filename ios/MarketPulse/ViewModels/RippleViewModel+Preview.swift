import Foundation

extension RippleViewModel {
    static var preview: RippleViewModel {
        let vm = RippleViewModel()
        if let histories = try? MockDataLoader.loadHistories() {
            vm.histories = histories
            vm.computeAllVerdictsForPreview()
        }
        return vm
    }

    func computeAllVerdictsForPreview() {
        for catalyst in catalysts {
            rippleResults[catalyst.ticker] = RippleEngine.analyze(
                catalyst: catalyst,
                histories: histories
            )
        }
    }
}
