//
// Created by Igor Litvinenko on 6/2/16.
// Copyright (c) 2016 DataArt. All rights reserved.
//

import Foundation
import MultipeerConnectivity

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