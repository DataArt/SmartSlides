//
//  AdvertiserHandler.swift
//  PresentatorS
//
//  Created by Igor Litvinenko on 12/24/14.
//  Copyright (c) 2014 Igor Litvinenko. All rights reserved.
//

import MultipeerConnectivity

class AdvertiserHandler: SessionHandler {
    var manager : AdvertisingManagerMP?
    
    init(manager advertManager : AdvertisingManagerMP){
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