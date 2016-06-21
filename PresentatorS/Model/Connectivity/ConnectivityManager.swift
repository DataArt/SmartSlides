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
            NSException(name: "MethodNotImplementedException", reason: "\(#file), \(#line): \(#function) should be overriden", userInfo: nil).raise()
            return ConnectivityManager()
        }
    }
    
    func invalidateSessions() {
        NSException(name: "MethodNotImplementedException", reason: "\(#file), \(#line): \(#function) should be overriden", userInfo: nil).raise()
    }
    
    deinit {
        invalidateSessions()
    }
}

