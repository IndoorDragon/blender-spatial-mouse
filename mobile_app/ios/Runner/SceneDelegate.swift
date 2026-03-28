import UIKit
import Flutter
import ARKit
import CoreMotion
import simd

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?

  private let methodChannelName = "phone_spatial_mouse/ar_method"
  private let eventChannelName = "phone_spatial_mouse/ar_pose_stream"

  private var arPoseStreamHandler: ARPoseStreamHandler?

  func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let windowScene = scene as? UIWindowScene else { return }

    let flutterEngine = (UIApplication.shared.delegate as? AppDelegate)?.flutterEngine
    let flutterViewController = FlutterViewController(
      engine: flutterEngine!,
      nibName: nil,
      bundle: nil
    )

    let window = UIWindow(windowScene: windowScene)
    window.rootViewController = flutterViewController
    self.window = window
    window.makeKeyAndVisible()

    GeneratedPluginRegistrant.register(with: flutterEngine!)

    let methodChannel = FlutterMethodChannel(
      name: methodChannelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )

    let eventChannel = FlutterEventChannel(
      name: eventChannelName,
      binaryMessenger: flutterViewController.binaryMessenger
    )

    let handler = ARPoseStreamHandler()
    self.arPoseStreamHandler = handler
    eventChannel.setStreamHandler(handler)

    methodChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self, let handler = self.arPoseStreamHandler else {
        result(FlutterError(
          code: "UNAVAILABLE",
          message: "AR handler unavailable",
          details: nil
        ))
        return
      }

      switch call.method {
      case "startTracking":
        print("startTracking called")
        handler.startTracking(result: result)
      case "stopTracking":
        print("stopTracking called")
        handler.stopTracking(result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}

final class ARPoseStreamHandler: NSObject, FlutterStreamHandler, ARSessionDelegate {
  private let session = ARSession()
  private let motionManager = CMMotionManager()

  private var eventSink: FlutterEventSink?
  private var isRunning = false

  override init() {
    super.init()
    session.delegate = self
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    print("Event stream attached")
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    print("Event stream cancelled")
    self.eventSink = nil
    return nil
  }

  func startTracking(result: @escaping FlutterResult) {
    print("AR/CoreMotion startTracking invoked")

    guard ARWorldTrackingConfiguration.isSupported else {
      result(FlutterError(
        code: "AR_NOT_SUPPORTED",
        message: "ARWorldTrackingConfiguration is not supported on this device",
        details: nil
      ))
      return
    }

    guard motionManager.isDeviceMotionAvailable else {
      result(FlutterError(
        code: "MOTION_NOT_AVAILABLE",
        message: "Core Motion deviceMotion is not available on this device",
        details: nil
      ))
      return
    }

    motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
    motionManager.startDeviceMotionUpdates(using: .xArbitraryZVertical)

    let config = ARWorldTrackingConfiguration()
    config.worldAlignment = .gravity
    session.run(config, options: [.resetTracking, .removeExistingAnchors])

    isRunning = true
    result(nil)
  }

  func stopTracking(result: @escaping FlutterResult) {
    print("AR/CoreMotion stopTracking invoked")
    session.pause()
    motionManager.stopDeviceMotionUpdates()
    isRunning = false
    result(nil)
  }

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard isRunning, let sink = eventSink else { return }

    let transform = frame.camera.transform

    let px = Double(transform.columns.3.x)
    let py = Double(transform.columns.3.y)
    let pz = Double(transform.columns.3.z)

    let arQuat = simd_quatf(transform)
    let arQx = Double(arQuat.imag.x)
    let arQy = Double(arQuat.imag.y)
    let arQz = Double(arQuat.imag.z)
    let arQw = Double(arQuat.real)

    let motion = motionManager.deviceMotion
    let attitudeQ = motion?.attitude.quaternion

    let qx = attitudeQ?.x ?? 0.0
    let qy = attitudeQ?.y ?? 0.0
    let qz = attitudeQ?.z ?? 0.0
    let qw = attitudeQ?.w ?? 1.0

    let tracking: String
    switch frame.camera.trackingState {
    case .normal:
      tracking = "normal"
    case .notAvailable:
      tracking = "not_available"
    case .limited(let reason):
      switch reason {
      case .initializing:
        tracking = "limited_initializing"
      case .excessiveMotion:
        tracking = "limited_excessive_motion"
      case .insufficientFeatures:
        tracking = "limited_insufficient_features"
      case .relocalizing:
        tracking = "limited_relocalizing"
      @unknown default:
        tracking = "limited_unknown"
      }
    }

    let payload: [String: Any] = [
      "tracking": tracking,
      "px": px,
      "py": py,
      "pz": pz,
      "qx": qx,
      "qy": qy,
      "qz": qz,
      "qw": qw,
      "ar_qx": arQx,
      "ar_qy": arQy,
      "ar_qz": arQz,
      "ar_qw": arQw,
      "timestamp": frame.timestamp
    ]

    sink(payload)
  }
}
