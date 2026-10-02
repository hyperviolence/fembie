import Foundation

enum Ester: String, Identifiable, CaseIterable {
    case estradiolEnanthate = "een"
    case estradiolValerate = "ev"
    case estradiolUndecyclate = "eun"
    case estradiolGel = "eg"
    case estradiolOral = "eo"
    case estradiolPatch = "ep"
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .estradiolEnanthate: "Estradiol Enanthate (EEn)"
        case .estradiolValerate: "Estradiol Valerate (EV)"
        case .estradiolUndecyclate: "Estradiol Undecyclate (EUn)"
        case .estradiolGel: "Estradiol Gel"
        case .estradiolOral: "Estradiol Oral (Pills)"
        case .estradiolPatch: "Estradiol Patch"
        }
    }
}

enum Route: String, Identifiable, CaseIterable {
    case subcutaneous = "subq"
    case intramuscular = "im"
    case transdermal = "tdermal"
    case oral = "oral"
    case sublingual = "sublingual"
    case patch = "patch"
    
    var id: Self { self }
    
    var displayName: String {
        switch self {
        case .subcutaneous: "Subcutaneous (subq)"
        case .intramuscular: "Intramuscular (im)"
        case .transdermal: "Transdermal"
        case .patch: "Patch"
        case .oral: "Oral"
        case .sublingual: "Sublingual"
        }
    }
}
