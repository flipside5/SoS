//
//  ConnectionType.swift
//
//  Created by Michael Sanford on 9/27/16.
//  Copyright © 2016 flipside5. All rights reserved.
//

public enum ConnectionType {
    case tcp, udp
}

extension ConnectionType: CustomDebugStringConvertible, CustomStringConvertible {
    public var debugDescription: String {
        return description
    }
    
    public var description: String {
        switch self {
        case .tcp:
            return "TCP"
        case .udp:
            return "UDP"
        }
    }
}
