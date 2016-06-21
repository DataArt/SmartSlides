//
// Created by Igor Litvinenko on 6/2/16.
// Copyright (c) 2016 DataArt. All rights reserved.
//

import Foundation
import MultipeerConnectivity

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
            } catch let err as NSError {
                error = err
                result = false
            }

            if let err = error {
                Logger.printLine("\(#function), error: \(err.localizedDescription)")
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