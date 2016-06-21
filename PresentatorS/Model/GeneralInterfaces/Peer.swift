//
// Created by Igor Litvinenko on 6/21/16.
// Copyright (c) 2016 DataArt. All rights reserved.
//

import Foundation

protocol Peer {
    init(displayName myDisplayName: String)
    var displayName: String { get }
}
