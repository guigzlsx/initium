import Foundation

enum AppFlowState: String, Equatable {
    case restoring
    case welcome
    case onboarding
    case valueSummary
    case paywall
    case accountCreation
    case mainApp // DEBUG preview mode only; normal auth routing uses AuthenticationState.
}
