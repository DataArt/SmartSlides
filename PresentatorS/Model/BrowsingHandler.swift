//
//  BrowsingHandler.swift
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
                    Logger.printLine("\(__FUNCTION__), \(err.localizedDescription)")
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

class BrowserCommandsHelper: SessionCommandFactory {
    
    class CommandGetSharedMaterials: SessionCommand {
        var items: [String]?
        
        required init(parameters: [String : String]) {
            self.items = parameters["items"]?.componentsSeparatedByString(",")
        }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            var result = true
            if let items = self.items{
                for presentation in items {
                    var error: NSError?
                    var array : [String] = presentation.componentsSeparatedByString("/md5Hex=")
                    let presentationFilename = array[0] as String
                    if !ContentManager.sharedInstance.isResourceAvailable(presentation, directoryType: .Imported){
                        do {
                            try session.sendData(SessionHandler.dataRequestForCommandType(.GetPresentationWithNameAndCrc, parameters: ["name": presentationFilename]), toPeers: peers, withMode: .Reliable)
                        } catch {
                            result = result && false
                        }
                        
                        if let err = error{
                            Logger.printLine("Sending request erre \(err.localizedDescription)")
                        }
                    } else {
                        do {
                            try session.sendData(SessionHandler.dataRequestForCommandType(.GetPresentationActiveSlide, parameters: nil), toPeers: peers, withMode: MCSessionSendDataMode.Reliable)
                        } catch let error1 as NSError {
                            error = error1
                        }
                    }
                }
            }
            return result
        }
    }
    
    class CommandReceiveActiveSlide: SessionCommand {
        let presentationName: String
        let pageNumber: Int?
        let slidesAmount : Int?
        
        required init(parameters: [String : String]) {
            let name = parameters["name"]!
            presentationName = NSURL.CM_pathForPresentationWithName((name as NSString).lastPathComponent)!.path!
            
            if let page : String? = parameters["page"] {
                pageNumber = Int(page!)
            } else {
                pageNumber = 0
            }
            
            if let slidesAmount : String? = parameters["slides_amount"] {
                self.slidesAmount = Int(slidesAmount!)
            } else {
                self.slidesAmount = 0
            }
        }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            Logger.printLine("Active presentation\(presentationName) and slide \(pageNumber!)")
            if !presentationName.isEmpty {
                AppDelegate.shared.browsingManager.stopHeartbeat()
                
                AppDelegate.shared.browsingManager.connectivityDelegate?.browsingHandlerDidReceiveActiveSlideCommand(self)
                
                AppDelegate.shared.browsingManager.startHeartbeat()
            }
            
            return true
        }
    }
    
    class CommandUpdatePresentationSlide: SessionCommand {
        
        let pageNumber: Int?
        
        required init(parameters: [String : String]) {
            if let page : String? = parameters["page"] {
                pageNumber = Int(page!)
            } else {
                pageNumber = 0
            }
        }
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            AppDelegate.shared.browsingManager.stopHeartbeat()
            
            AppDelegate.shared.browsingManager.connectivityDelegate?.browsingHandlerDidUpdateActiveSlideCommand(self)
            
            AppDelegate.shared.browsingManager.startHeartbeat()
            return true
        }
    }
    
    class CommandPing: SessionCommand {

        required init(parameters: [String : String]) {}
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            AppDelegate.shared.browsingManager.backPingMessageReceived()
            return true
        }
    }
    
    class CommandStopCurrentPresentation: SessionCommand {
        let parameters: [String: String]?
        required init(parameters: [String : String]) { self.parameters = parameters }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            AppDelegate.shared.browsingManager.connectivityDelegate?.browsingHandlerDidReceiveStopPresentationCommand(self)
            AppDelegate.shared.browsingManager.stopPinging()
            return true
        }
    }
    
    func commandWithType(response: [String : String]) -> SessionCommand {
        var result : SessionCommand = CommandUnknown(parameters: response)
        let type = CommantType(rawValue: response["type"]!)
        
        if let type_local = type {
            switch type_local {
            case .GetSharedMaterialsList, .UpdateActivePresentation:
                result = CommandGetSharedMaterials(parameters: response)
            case .GetPresentationActiveSlide:
                result = CommandReceiveActiveSlide(parameters: response)
            case .UpdatePresentationActiveSlide:
                result = CommandUpdatePresentationSlide(parameters: response)
            case .StopPresentation:
                result = CommandStopCurrentPresentation(parameters: response)
            case .PingServer:
                result = CommandPing(parameters: response)
            default:
                result = CommandUnknown(parameters: response)
            }
        }
        return result
    }
}
