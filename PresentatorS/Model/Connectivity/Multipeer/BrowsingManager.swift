//
//  BrowsingManager.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 6/2/16.
//  Copyright © 2016 DataArt. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class BrowsingManagerMP: ConnectivityManager {
    
    private static let sharedInstance = BrowsingManagerMP()
    
    //MARK: Overriden singleton
    
    override class var sharedManager : BrowsingManagerMP {
        get {
            return BrowsingManagerMP.sharedInstance
        }
    }
    
    var browsingSession : MCSession?
    var advertiserPeer : MCPeerID?
    var pastAdvertisersIDList = [String]()
    
    var heartbeatTimer : NSTimer!
    var pingTimer : NSTimer!
    var expirationTimer : NSTimer!
    
    weak var connectivityDelegate : BrowsingConnectivityDelegate? {
        didSet {
            (handler as! BrowsingHandler).connectivityDelegate = connectivityDelegate
        }
    }
    
    override init() {
        super.init()
        isActive = true
        self.mode = .ListenerMode
        print("Listener mode established")
    }
    
    //MARK: Browsing session creation
    
    func instantiateObserverSessionWithName(name : String, browsingDelegate delegate : BrowsingHandlerDelegate?) {
        browsingSession = MCSession(peer : MCPeerID(displayName: name), securityIdentity : nil, encryptionPreference: .None)
        handler = BrowsingHandler(browsingDelegate: delegate)
        (handler as! BrowsingHandler).connectivityDelegate = connectivityDelegate
        browsingSession!.delegate = handler
    }
    
    //MARK: Allowed advertisers management
    
    func registerAdvertiserPeer(peer : MCPeerID) {
        advertiserPeer = peer
    }
    
    func registerAdvertiserSession(session : PresentationSession) {
        pastAdvertisersIDList.append(session.uniqueID)
    }
    
    func removeLastConnectedAdvertiserSessionHash() {
        if pastAdvertisersIDList.count > 0 {
            pastAdvertisersIDList.removeLast()
        }
    }
    
    func checkIfAdvertiserSessionAvailable(session : PresentationSession) -> Bool {
        for sessionID in pastAdvertisersIDList {
            if sessionID == session.uniqueID {
                return false
            }
        }
        
        return true
    }
    
    //MARK: Pinger
    
    func startHeartbeat() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(15.0, target: self, selector: #selector(BrowsingManagerMP.startSendingPingingMessages(_:)), userInfo: nil, repeats: false)
            print("Start heartbeat")
        }
    }
    
    func stopHeartbeat() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.heartbeatTimer?.invalidate()
            print("Stop heartbeat")
        }
    }
    
    func startSendingPingingMessages(timer: NSTimer) {
        self.pingTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: #selector(BrowsingManagerMP.checkConnectivity(_:)), userInfo: nil, repeats: true)
        print("Start sending pinging messages...")
    }
    
    func stopPinging() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            self.pingTimer?.invalidate()
            self.expirationTimer?.invalidate()
            self.heartbeatTimer?.invalidate()
            
            self.pingTimer = nil
            self.expirationTimer = nil
            self.heartbeatTimer = nil
        }
    }
    
    func checkConnectivity(timer : NSTimer) {
        if let advertiser = advertiserPeer {
            print("Ping sent...")
            if expirationTimer == nil {
                expirationTimer = NSTimer.scheduledTimerWithTimeInterval(9.0, target: self, selector: #selector(BrowsingManagerMP.lostConnectionWithAdvertiser(_:)), userInfo: nil, repeats: false)
            }
            do {
                try browsingSession?.sendData(SessionHandler.dataRequestForCommandType(.PingServer, parameters: nil), toPeers: [advertiser], withMode: .Reliable)
            } catch let error as NSError {
                print("Error sending ping: \(error)")
            }
        }
    }
    
    func backPingMessageReceived() {
        dispatch_async(dispatch_get_main_queue()) { () -> Void in
            print("Back ping received...")
            self.stopPinging()
            
            self.startHeartbeat()
        }
    }
    
    func lostConnectionWithAdvertiser(timer : NSTimer) {
        if timer.valid {
            stopPinging()
            print("No back ping received. Advertiser lost connection")
            if let advertiser = advertiserPeer {
                connectivityDelegate?.browsingHandlerDidDisconnectedFromPeer(advertiser)
            }
        }
    }
    
    //MARK: Overriden
    
    override func invalidateSessions() {
        advertiserPeer = nil
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
            self.browsingSession?.disconnect()
        })
        print("Browsing session \(browsingSession?.myPeerID.displayName) disconnected")
        browsingSession = nil
        
        stopPinging()
    }
}