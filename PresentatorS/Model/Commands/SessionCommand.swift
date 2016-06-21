//
// Created by Igor Litvinenko on 6/2/16.
// Copyright (c) 2016 DataArt. All rights reserved.
//

import Foundation
import MultipeerConnectivity

enum CommantType: String {
    case Unknown = "unknown"
    case GetSharedMaterialsList = "get_shared_materials"
    case GetPresentationWithNameAndCrc = "get_presentation"
    case GetPresentationActiveSlide = "get_active_slide"
    case UpdatePresentationActiveSlide = "update_active_slide"
    case PingServer = "ping"
    case StopPresentation = "stop_sharing"
    case UpdateActivePresentation = "update_presentation"
    case SetDeviceAsController = "set_controller_device"
}

protocol SessionCommand {
    init(parameters: [String: String])
    func execute(session: MCSession, peers: [MCPeerID]) -> (Bool)
}

class CommandUnknown: SessionCommand {
    required init(parameters: [String : String]) {}

    func execute(session: MCSession, peers: [MCPeerID]) -> (Bool) {
        NSException(name: "CommandNotFoundException", reason: "\(#file), \(#line): \(#function ) should be overriden", userInfo: nil).raise()
        return false
    }
}