//
// Created by Igor Litvinenko on 6/2/16.
// Copyright (c) 2016 DataArt. All rights reserved.
//

import Foundation

protocol SessionCommandFactory{
    func commandWithType(response: [String : String]) -> SessionCommand
}
