import UIKit
import Flutter
import AVKit

@main
@objc class AppDelegate: FlutterAppDelegate {
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        
        // Intent channel for opening videos with referer
        let intentChannel = FlutterMethodChannel(name: "com.hugetiny.haipee/intent",
                                           binaryMessenger: controller.binaryMessenger)
        intentChannel.setMethodCallHandler({
            (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            if call.method == "openWithReferer" {
                guard let args = call.arguments else { return }
                if let myArgs = args as? [String: Any],
                   let url = myArgs["url"] as? String,
                   let referer = myArgs["referer"] as? String {
                    self.openVideoWithReferer(url: url, referer: referer)
                }
                result(nil)
            } else if call.method == "isFirebaseTestLab" {
                let isTestLab = ProcessInfo.processInfo.environment["FIREBASE_TEST_LAB"] == "true" ||
                                ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil ||
                                UserDefaults.standard.bool(forKey: "firebase.test.lab")
                result(isTestLab)
            } else if call.method == "logNative" {
                guard let args = call.arguments as? [String: Any],
                      let message = args["message"] as? String else {
                    result(nil)
                    return
                }
                let level = (args["level"] as? String) ?? "I"
                NSLog("[haipee:%@] %@", level, message)
                result(nil)
            } else {
                result(FlutterMethodNotImplemented)
            }
        })
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // MARK: - Video Player Methods
    
    private func openVideoWithReferer(url: String, referer: String) {
        if let videoUrl = URL(string: url) {
            let headers: [String: String] = [
                "Referer": referer,
            ]
            let asset = AVURLAsset(url: videoUrl, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            let playerViewController = AVPlayerViewController()
            playerViewController.player = player
            playerViewController.videoGravity = AVLayerVideoGravity.resizeAspect
            
            UIApplication.shared.keyWindow?.rootViewController?.present(playerViewController, animated: true, completion: {
                playerViewController.player!.play()
            })
        }
    }
}
