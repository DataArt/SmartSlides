//
//  SessionsManager.swift
//  PresentatorS
//
//  Created by Roman Ivchenko on 11/18/15.
//  Copyright © 2015 DataArt. All rights reserved.
//

import Foundation
import MultipeerConnectivity

enum ConnectivityManagerMode {
    case AdvertiserMode, ListenerMode, UnknownMode
}

protocol ConnectivityManagerDelegate : NSObjectProtocol {
    func connectivityManagerDidChangeState(manager : ConnectivityManager)
}

class ConnectivityManager : NSObject {
    let kServiceTypeName = "present-service"
    let kAllowedPeersAmountInSession = 7
    
    var handler : SessionHandler?
    var mode = ConnectivityManagerMode.UnknownMode
    var isActive = false
    weak var delegate : ConnectivityManagerDelegate?
    
    class var sharedManager: ConnectivityManager {
        get {
            NSException(name: "MethodNotImplementedException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
            return ConnectivityManager()
        }
    }
    
    func invalidateSessions() {
        NSException(name: "MethodNotImplementedException", reason: "\(__FILE__), \(__LINE__): \(__FUNCTION__) should be overriden", userInfo: nil).raise()
    }

    override init() {
        super.init()
    }
    
    deinit {
        invalidateSessions()
    }
}

class BrowsingManager : ConnectivityManager {
    
    private static let sharedInstance = BrowsingManager()
    
    //MARK: Overriden singleton
    
    override class var sharedManager : BrowsingManager {
        get {
            return BrowsingManager.sharedInstance
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
            self.heartbeatTimer = NSTimer.scheduledTimerWithTimeInterval(15.0, target: self, selector: Selector("startSendingPingingMessages:"), userInfo: nil, repeats: false)
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
        self.pingTimer = NSTimer.scheduledTimerWithTimeInterval(3.0, target: self, selector: Selector("checkConnectivity:"), userInfo: nil, repeats: true)
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
                expirationTimer = NSTimer.scheduledTimerWithTimeInterval(9.0, target: self, selector: Selector("lostConnectionWithAdvertiser:"), userInfo: nil, repeats: false)
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

class AdvertisingManager : ConnectivityManager {
    private static let sharedInstance = AdvertisingManager()
    
    //MARK: Overriden singleton
    
    override class var sharedManager : AdvertisingManager {
        get {
            return AdvertisingManager.sharedInstance
        }
    }
    
    var sessions = [PresentationSession]()
    var supplementarySessionNedded : Bool {
        get {
            let peersCount = (sessions as NSArray).valueForKeyPath("@sum.peersCount") as! Int
            
            if peersCount % kAllowedPeersAmountInSession == 0 {
                return true
            } else {
                return false
            }
        }
    }
    
    override init() {
        super.init()
        
        self.mode = .AdvertiserMode
        self.handler = AdvertiserHandler(manager: self)
        isActive = false
    }
    
    //MARK: Advertiser session creation
    
    func createPresentationSessionWithName(name : String) {
        let presentationSession = PresentationSession(peer: MCPeerID(displayName: name), serviceType: kServiceTypeName, delegate: handler, index: 0, creationDate: NSDate(), broadcastingDevice: UIDevice().model)
        
        sessions.append(presentationSession)
        
        isActive = true
        delegate?.connectivityManagerDidChangeState(self)
    }
    
    //MARK: Creating supplementary sessions for overhead connections
    
    func addSupplementaryPresentationSession() {
        if sessions.count > 0 {
            let index = sessions.count
            
            let presentationSession = PresentationSession(peer: MCPeerID(displayName: sessions[0].displayName), serviceType: kServiceTypeName, delegate: handler, index: index, creationDate: NSDate(), broadcastingDevice: UIDevice().model)
            
            sessions.append(presentationSession)
        }
    }
    
    override func invalidateSessions() {
        for session in sessions {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                session.advertiserAssistant?.stop()
                session.disconnect()
            });
            print("Session \(session.displayName) disconnected")
        }
        
        sessions.removeAll()
        
        isActive = false
        delegate?.connectivityManagerDidChangeState(self)
        
        print("All sessions removed")
    }
}
