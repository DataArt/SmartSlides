//
//  AdvertisingManager.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 6/2/16.
//  Copyright © 2016 DataArt. All rights reserved.
//

import Foundation
import MultipeerConnectivity

class AdvertisingManagerMP: ConnectivityManager {
    private static let sharedInstance = AdvertisingManagerMP()
    
    //MARK: Overriden singleton
    
    override class var sharedManager : AdvertisingManagerMP {
        get {
            return AdvertisingManagerMP.sharedInstance
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