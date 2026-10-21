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
        let intentChannel = FlutterMethodChannel(name: "com.predidit.kazumi/intent",
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
