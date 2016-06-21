//
//  AppDelegate.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/19/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import UIKit
import Fabric
import Crashlytics
import WatchConnectivity

let kReadyToStartImportedPresentationNotification = "kReadyToStartImportedPresentationNotification"
let kRestoreNotification = "kRestoreNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, ConnectivityManagerDelegate {
    let kDropboxAppKey = ""
    let kDropboxAppSecret = ""

    
    var window: UIWindow?
    
    var browsingManager : BrowsingManagerMP {
        get {
            return BrowsingManagerMP.sharedManager
        }
    }
    
    var advertisingManager : AdvertisingManagerMP {
        get {
            let manager = AdvertisingManagerMP.sharedManager
            manager.delegate = self
            return manager
        }
    }
    
    // Workaround to make this ivar available only in iOS 9.0
    private var _watchSession: AnyObject?
    @available(iOS 9.0, *)
    var watchSession: WCSession? {
        get {
            return _watchSession as? WCSession
        }
        set {
            _watchSession = newValue
        }
    }
    
    var currentActiveMode = ConnectivityManagerMode.ListenerMode
    static let shared = UIApplication.sharedApplication().delegate as! AppDelegate
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .None)
        UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .None)
        Fabric.with([Crashlytics()])
        
        let dropboxSession = DBSession(appKey: kDropboxAppKey, appSecret: kDropboxAppSecret, root: kDBRootDropbox)
        DBSession.setSharedSession(dropboxSession)
        return true
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        if sourceApplication == "com.getdropbox.Dropbox" {
            if DBSession.sharedSession().handleOpenURL(url) {
                if DBSession.sharedSession().isLinked() {
                    NSNotificationCenter.defaultCenter().postNotificationName("didLinkToDropboxAccountNotification", object: nil)
                    return true
                }
            }
            return false
        } else {
            NSNotificationCenter.defaultCenter().postNotificationName(kReadyToStartImportedPresentationNotification, object: nil, userInfo: ["presentationPath" : url.path!])
            return true
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        if #available(iOS 9.0, *) {
            AppDelegate.shared.watchSession?.sendMessage(["type" : "stop"], replyHandler: nil, errorHandler: { (error) -> Void in
                print(error)
            })
        }
        
        if currentActiveMode == ConnectivityManagerMode.AdvertiserMode {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                for session in self.advertisingManager.sessions where session.peersCount > 0 {
                    var error: NSError?
                    do {
                        try session.sendData(SessionHandler.dataRequestForCommandType(.StopPresentation, parameters: ["wait": "show_again"]), toPeers: session.connectedPeers, withMode: .Reliable)
                    } catch let error1 as NSError {
                        error = error1
                    } catch {
                        fatalError()
                    }
                    if let err = error{
                        Logger.printLine("Stopping presentation error \(err.localizedDescription) for session \(session.displayName) with index \(session.index)")
                    }
                }
            })
        }
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        NSNotificationCenter.defaultCenter().postNotificationName(kRestoreNotification, object: nil, userInfo: nil)
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        invalidateAllSessions()
        if #available(iOS 9.0, *) {
            AppDelegate.shared.watchSession?.sendMessage(["type" : "stop"], replyHandler: nil, errorHandler: { (error) -> Void in
                print(error)
            })
        }
    }
    
    //MARK: Managers clean up
    
    func invalidateAllSessions() {
        browsingManager.invalidateSessions()
        advertisingManager.invalidateSessions()
    }
    
    //MARK: ConnectivityManagerDelegate
    
    func connectivityManagerDidChangeState(manager: ConnectivityManager) {
        let advertiserManager = manager as! AdvertisingManagerMP
        if advertiserManager.isActive {
            print("Advertising mode established \nListener mode deactivated")
            browsingManager.isActive = false
            currentActiveMode = ConnectivityManagerMode.AdvertiserMode
        } else {
            print("Advertising mode deactivated \nListener mode established")
            browsingManager.isActive = true
            currentActiveMode = ConnectivityManagerMode.ListenerMode
        }
    }
}

