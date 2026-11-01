import Foundation
import StikJIT
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let configuration = StikJIT.Configuration()
        let paths = DDIPaths.default(in: URL(fileURLWithPath: NSTemporaryDirectory()))
        let script: StikJIT.Script = .universal
        let service = DeveloperDiskImageService.shared
        let state = StikJIT.DeviceSecurityState(isTXMPresent: nil)
        let readiness: StikJIT.JITReadiness = .ready(state)
        let stage: StikJIT.PreparationStage = .ready
        let error: StikJITError = .scriptUnavailable
        let label = UILabel()
        label.text = "\(configuration.deviceAddress) \(paths.imagePath) \(script) \(service) \(readiness.isReady) \(stage) \(error)"
        let controller = UIViewController()
        controller.view = label
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = controller
        window?.makeKeyAndVisible()
        return true
    }
}
