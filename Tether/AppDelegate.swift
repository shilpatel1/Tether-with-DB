//
//  AppDelegate.swift
//  Tether
//
//  Created by My-Linh Tran on 1/29/19.
//  Copyright © 2019 ChrisLee. All rights reserved.
//

import UIKit
import Firebase
import GeoFire
import SwiftMessages

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    override init() {
        FirebaseApp.configure()
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let info = MessageView.viewFromNib(layout: .messageView)
        info.button?.isHidden = true
        info.configureTheme(.info)
        info.configureContent(title: "Hello! Thank You for Using Tether!", body: "Press and hold the screen for at least one second then release to save your car location!")
        SwiftMessages.show(view: info)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        let info = MessageView.viewFromNib(layout: .messageView)
        info.button?.isHidden = true
        info.configureTheme(.info)
        info.configureContent(title: "Welcome Back!", body: "Double tap the screen to find your car!")
        SwiftMessages.show(view: info)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    


}

