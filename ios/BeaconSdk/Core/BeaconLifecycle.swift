import UIKit
import Foundation

protocol LifecycleListener: AnyObject {
  func onForeground()
  func onBackground()
}

class BeaconLifecycle {

  private var isForegroundState: Bool = true
  private weak var listener: LifecycleListener?

  init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil
    )
    
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didBecomeActive),
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  var isForeground: Bool {
    return isForegroundState
  }

  func setListener(_ listener: LifecycleListener){
    self.listener = listener
  }

  @objc private func didBecomeActive() {
    isForegroundState = true
    Logger.i("App moved to FOREGROUND")
    listener?.onForeground()
  }
    
  @objc private func didEnterBackground() {
    isForegroundState = false
    Logger.i("App moved to BACKGROUND")
    listener?.onBackground()
  }
}