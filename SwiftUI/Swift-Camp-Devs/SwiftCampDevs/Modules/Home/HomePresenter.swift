import Foundation
import Combine

final class HomePresenter: ObservableObject {

    // MARK: - Private properties -
    private let wireframe: HomeWireframeInterface

    // MARK: - Lifecycle -
    init(wireframe: HomeWireframeInterface) {
        self.wireframe = wireframe
    }

    func goBack() {
        wireframe.goBack()
    }

    func navigateToLogin() {
        wireframe.navigateToLoginPage()
    }
}
