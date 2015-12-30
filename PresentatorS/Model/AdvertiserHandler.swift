//
//  AdvertiserHandler.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/24/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import MultipeerConnectivity

class AdvertiserHandler: SessionHandler {
    var manager : AdvertisingManager?
    
    init(manager advertManager : AdvertisingManager){
        manager = advertManager
        super.init()
    }

    override func setup() {
        self.commandFactory = AdviserCommandHelper()
        
        ContentManager.sharedInstance.presentationUpdateClosure = { presentation in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                for session in self.manager!.sessions where session.peersCount > 0 {
                    var error: NSError?
                    do {
                        try session.sendData(SessionHandler.dataRequestForCommandType(.UpdatePresentationActiveSlide, parameters: ["name": presentation.presentationName, "page": String(presentation.currentSlide)]), toPeers: session.connectedPeers, withMode: .Reliable)
                    } catch let error1 as NSError {
                        error = error1
                    } catch {
                        fatalError()
                    }
                    if let err = error{
                        Logger.printLine("Updating presentation slide error \(err.localizedDescription) for session \(session.displayName) with index \(session.index)")
                    }
                }
            })
        }
        
        ContentManager.sharedInstance.onStopSharingClosure = {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                for session in self.manager!.sessions where session.peersCount > 0 {
                    var error: NSError?
                    do {
                        try session.sendData(SessionHandler.dataRequestForCommandType(.StopPresentation, parameters: ["wait": ""]), toPeers: session.connectedPeers, withMode: .Reliable)
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
        
        ContentManager.sharedInstance.onStartSharingClosure = { presentation in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                for session in self.manager!.sessions where session.peersCount > 0 {
                    var error: NSError?
                    do {
                        try session.sendData(SessionHandler.dataRequestForCommandType(.UpdateActivePresentation, parameters: ["items": presentation.presentationName, "slides_amount" : "\(presentation.slidesAmount)"]), toPeers: session.connectedPeers, withMode: .Reliable)
                    } catch let error1 as NSError {
                        error = error1
                    } catch {
                        fatalError()
                    }
                    if let err = error {
                        Logger.printLine("Updating active presentation error \(err.localizedDescription) for session \(session.displayName) with index \(session.index)")
                    }
                }
            })
        }
    }
    
    override func session(session: MCSession, peer peerID: MCPeerID, didChangeState state: MCSessionState) {
        Logger.printLine("\(peerID.displayName) state: \(state.rawValue) (2-connected)")
        
        if state == .Connected && manager!.supplementarySessionNedded == true {
            manager!.addSupplementaryPresentationSession()
        }
    }
    
    // Received data from remote override override peer
    override func session(session: MCSession, didReceiveData data: NSData, fromPeer peerID: MCPeerID){
        self.commandFactory?.commandWithType(SessionHandler.parseResponseToDictionary(data)).execute(session, peers: [peerID])
    }
}

class AdviserCommandHelper: SessionCommandFactory {
    
    class CommandGetShared: SessionCommand {
        
        let parameters: [String : String]?
        
        required init(parameters: [String : String]) {
            self.parameters = parameters
        }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            var error: NSError?
            
            let resultString = ContentManager.sharedInstance.getSharedMaterials().joinWithSeparator(",")
            let data = SessionHandler.dataRequestForCommandType(CommantType.GetSharedMaterialsList, parameters: ["items" : resultString])
            let result: Bool
            do {
                try session.sendData(data, toPeers: peers, withMode: MCSessionSendDataMode.Reliable)
                result = true
            } catch let error1 as NSError {
                error = error1
                result = false
            }
            
            if let err = error {
                Logger.printLine("\(__FUNCTION__), error: \(err.localizedDescription)")
            }
            
            return result
        }
    }
    
    class CommandSendPresentation: SessionCommand {
        var presentationName: String?
        
        required init(parameters: [String : String]) {
            self.presentationName = parameters["name"]
        }
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            var result = true
            
            if let path : String? = NSURL.CM_pathForPresentationWithName(presentationName!)?.path where presentationName != nil {
                if NSFileManager.defaultManager().fileExistsAtPath(path!){
                    session.sendResourceAtURL(NSURL(fileURLWithPath: path!), withName: presentationName!, toPeer: peers.first!, withCompletionHandler: { (error) -> Void in
                        if error != nil {
                            Logger.printLine("Sending presentation error \(error!.localizedDescription) for session \(session.myPeerID.displayName)")
                        }
                    })
                } else{
                    result = false
                }
            } else {
                
                result = false
            }
            
            return result
        }
    }
    
    class CommandGetActiveState: SessionCommand{
        required init(parameters: [String : String]) { }
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            var parameters: [String: String]
            
            if let presentation = ContentManager.sharedInstance.getActivePresentationState() {
                parameters = ["name": presentation.presentationName, "page": String(presentation.currentSlide), "slides_amount": String(presentation.slidesAmount)]
            } else {
                parameters = ["name":""]
            }
            do {
                try session.sendData(SessionHandler.dataRequestForCommandType(.GetPresentationActiveSlide, parameters: parameters), toPeers: peers, withMode: .Reliable)
                return true
            } catch _ {
                return false
            }
        }
    }
    
    class CommandGetPing: SessionCommand{
        required init(parameters: [String : String]) { }
        
        func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
            do {
                print("Ping received, ping sent back")
                try session.sendData(SessionHandler.dataRequestForCommandType(.PingServer, parameters: nil), toPeers: peers, withMode: .Reliable)
                return true
            } catch let error as NSError {
                print("Error sending ping: \(error)")
                return false
            }
        }
    }

    func commandWithType(response: [String : String]) -> SessionCommand {
        var result : SessionCommand = CommandUnknown(parameters: response)
        let type = CommantType(rawValue: response["type"]!)
        
        if let type = type {
            switch type{
            case .GetSharedMaterialsList:
                result = CommandGetShared(parameters: response)
            case .GetPresentationWithNameAndCrc:
                result = CommandSendPresentation(parameters: response)
            case .GetPresentationActiveSlide:
                result = CommandGetActiveState(parameters: response)
            case .PingServer:
                result = CommandGetPing(parameters: response)
            default:
                result = CommandUnknown(parameters: response)
            }
        }
        
        return result
    }
    
}