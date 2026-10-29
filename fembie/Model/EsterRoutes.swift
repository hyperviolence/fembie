import Foundation

struct EsterRoutes {
    static func getRoutes(ester: EstradiolType) -> [EstradiolRoute] {
        switch ester {
        case .estradiolEnanthate, .estradiolUndecyclate:
            return [.subcutaneous, .intramuscular]
        case .estradiolValerate:
            return [.intramuscular]
        case .estradiolOral:
            return [.oral, .sublingual]
        case .estradiolGel:
            return [.transdermal]
        case .estradiolPatch:
            return [.patch]
        }
    }
}

