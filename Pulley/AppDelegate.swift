//
//  AppDelegate.swift
//  Pulley
//
//  Created by Brendan Lee on 7/6/16.
//  Copyright © 2016 52inc. All rights reserved.
//

import UIKit
import Pulley

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    

    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Override point for customization after application launch.
        
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // To create from a Storyboard
        window?.rootViewController = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController()!
        
        // To create in code (uncomment this block)
        /*
         let mainContentVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "PrimaryContentViewController")
         let drawerContentVC = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "DrawerContentViewController")
         let pulleyDrawerVC = PulleyViewController(contentViewController: mainContentVC, drawerViewController: drawerContentVC)
         
         // Uncomment this next line to give the drawer a starting position, in this case: closed.
         // pulleyDrawerVC.initialDrawerPosition = .closed
         
         window?.rootViewController = pulleyDrawerVC
         */
        
        window?.makeKeyAndVisible()
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
}

