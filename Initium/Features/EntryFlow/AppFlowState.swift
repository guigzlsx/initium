import Foundation

enum AppFlowState: String, Equatable {
    case restoring
    case welcome
    case onboarding
    case valueSummary
    case paywall
    case accountCreation
    case mainApp
}
