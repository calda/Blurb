//
//  AppDelegate.swift
//  Custom Blur
//
//  Created by Cal on 6/10/15.
//  Copyright © 2015 Cal. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics

let IBStatusBarTappedNotification = "com.cal.instablur.statusBarTapped"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        Fabric.with([Crashlytics.self, Answers.self])
        Event.appLaunched.record()
        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: Notification.Name(rawValue: IBAppOpenedNotification), object: nil, userInfo: nil)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard let window = self.window else { return }
        guard let touch = touches.first else { return }
        let location = touch.location(in: window)
        let statusBarFrame = UIApplication.shared.statusBarFrame
        if statusBarFrame.contains(location) {
            NotificationCenter.default.post(name: Notification.Name(rawValue: IBStatusBarTappedNotification), object: nil)
        }
    }
    
}
