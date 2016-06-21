//
//  BrowserCommandsHelper.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/24/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import MultipeerConnectivity

extension MCSessionState {
    func readableRawValue() -> String {
        switch (self) {
        case .Connected: return "Connected"
        case .Connecting: return "Connecting"
        case .NotConnected: return "Not connected"
        }
    }
}

protocol BrowsingHandlerDelegate : NSObjectProtocol {
    func browsingHandlerDidDetermineAdvertiser(peerID: MCPeerID, withState state: MCSessionState)
}

protocol BrowsingConnectivityDelegate : NSObjectProtocol {
    func browsingHandlerDidDisconnectedFromPeer(peerID: MCPeerID)
    func browsingHandlerDidStartDownloadingPresentation(progress: NSProgress, presentationName : String)
    func browsingHandlerDidReceiveActiveSlideCommand(command : BrowserCommandsHelper.CommandReceiveActiveSlide)
    func browsingHandlerDidUpdateActiveSlideCommand(command : BrowserCommandsHelper.CommandUpdatePresentationSlide)
    func browsingHandlerDidReceiveStopPresentationCommand(command : BrowserCommandsHelper.CommandStopCurrentPresentation)
}

class BrowsingHandler: SessionHandler {
    weak var browsingDelegate : BrowsingHandlerDelegate?
    weak var connectivityDelegate : BrowsingConnectivityDelegate?
    
    override func setup() {
        self.commandFactory = BrowserCommandsHelper()
    }
    
    init(browsingDelegate : BrowsingHandlerDelegate?){
        self.browsingDelegate = browsingDelegate
        super.init()
    }
    
    override func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        if peerID.displayName.containsString(".pptx") || peerID.displayName.containsString(".key") {
            Logger.printLine("\(peerID.displayName) state: \(state.rawValue) (2-connected)")
            browsingDelegate?.browsingHandlerDidDetermineAdvertiser(peerID, withState: state)
            if state == .Connected {
                var error: NSError?
                do {
                    try session.sendData(SessionHandler.dataRequestForCommandType(.GetSharedMaterialsList, parameters: nil), toPeers: [peerID], withMode: MCSessionSendDataMode.Reliable)
                } catch let error1 as NSError {
                    error = error1
                }
                if let err = error {
                    Logger.printLine("\(#function), \(err.localizedDescription)")
                }
            } else if state == .NotConnected {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    Logger.printLine("ATT: \(peerID.displayName) is disconnected")
                    self.connectivityDelegate?.browsingHandlerDidDisconnectedFromPeer(peerID)
                    AppDelegate.shared.browsingManager.stopPinging()
                })
            }
        } else {
            Logger.printLine("\(peerID.displayName) state: \(state.rawValue) (2-connected) found, but is not advertiser")
        }
    }
    
    override func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID) {
        self.commandFactory?.commandWithType(SessionHandler.parseResponseToDictionary(data)).execute(session, peers: [peerID])
    }
    
    override func session(session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, withProgress progress: NSProgress) {
        connectivityDelegate?.browsingHandlerDidStartDownloadingPresentation(progress, presentationName: resourceName)
    }
    
    override func session(session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, atURL localURL: NSURL, withError error: NSError!) {
        var summaryError: NSError?
        do {
            if error == nil {
                try NSFileManager.defaultManager().moveItemAtURL(localURL, toURL: NSURL.CM_fileURLToSharedPresentationDirectory().URLByAppendingPathComponent(resourceName))
            }
        } catch let excError as NSError {
            summaryError = excError
        }
        
        if let err = summaryError {
            Logger.printLine("Get Error on saving presentation \(err.localizedDescription)")
        } else {
            Logger.printLine("Saved presentation with name \(NSURL.CM_pathForPresentationWithName(resourceName))")
            
            do {
                try session.sendData(SessionHandler.dataRequestForCommandType(.GetPresentationActiveSlide, parameters: nil), toPeers: [peerID], withMode: MCSessionSendDataMode.Reliable)
            } catch let excError as NSError {
                summaryError = excError
            }
        }
    }
}
