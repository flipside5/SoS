//
//  Socket.swift
//
//  Created by Michael Sanford on 9/27/16.
//  Copyright © 2016 flipside5. All rights reserved.
//

import Foundation
#if os(Linux)
    import Glibc
#else
    import Darwin
#endif

public enum SocketError: Error {
    case socketClosed
    case operationFailure(SocketErrorCode)
    case internalError
    case receivedDataFromUnexpectedSender
    case attemptNonBlockingOperationOnBlockingSocket
    
    fileprivate static var currentFailure: SocketError {
        return .operationFailure(SocketErrorCode.current)
    }
}

public enum SocketOption {
    case SendBufferSize(Int)
    case ReceiveBufferSize(Int)
    case ReuseAddress(Bool)
    case KeepAlive(Bool)
    case ReceiveTimeout(Int)
    case SignalPipe(Bool)
    
    #if os(Linux)
        private static let NO_SIGNAL = Int32(MSG_NOSIGNAL)
    #else
        private static let NO_SIGNAL = SO_NOSIGPIPE
    #endif
    
    fileprivate var constant: Int32 {
        switch self {
        case .SendBufferSize: return SO_SNDBUF
        case .ReceiveBufferSize: return SO_RCVBUF
        case .ReuseAddress: return SO_REUSEADDR
        case .KeepAlive: return SO_KEEPALIVE
        case .ReceiveTimeout: return SO_RCVTIMEO
        case .SignalPipe: return SocketOption.NO_SIGNAL
        }
    }
    
    fileprivate var value: UInt32 {
        switch self {
        case .SendBufferSize(let value): return UInt32(value)
        case .ReceiveBufferSize(let value): return UInt32(value)
        case .ReuseAddress(let flag): return flag ? 1 : 0
        case .KeepAlive(let flag): return flag ? 1 : 0
        case .ReceiveTimeout(let time): return UInt32(time)
        case .SignalPipe(let flag): return flag ? 1 : 0
        }
    }
    
    fileprivate static func create(_ option: SocketOption, value: UInt32) -> SocketOption {
        switch option {
        case .SendBufferSize: return .SendBufferSize(Int(value))
        case .ReceiveBufferSize: return .ReceiveBufferSize(Int(value))
        case .ReuseAddress: return .ReuseAddress(value != 0)
        case .KeepAlive: return .KeepAlive(value != 0)
        case .ReceiveTimeout: return .ReceiveTimeout(Int(value))
        case .SignalPipe: return .SignalPipe(value != 0)
        }
    }
}

/*---------------------------------------------------------------*/

public typealias SocketRawHandle = Int32

fileprivate struct NativeSocket {
    let handle: SocketRawHandle
    let connectionType: ConnectionType
    let addressType: IPAddressType
    
    init?(addressType: IPAddressType = .version6, connectionType: ConnectionType) {
        let handle = socket(Int32(addressType.family), connectionType.socketType, 0)
        guard handle >= 0 else { return nil }
        self.init(handle: handle, addressType: addressType, connectionType: connectionType)
    }
    
    init(handle: SocketRawHandle, addressType: IPAddressType, connectionType: ConnectionType) {
        self.handle = handle
        self.connectionType = connectionType
        self.addressType = addressType
    }
}

/*---------------------------------------------------------------*/

public enum SelectOperationType {
    case read
    case close
    case error(SocketErrorCode)
}

public class Socket {
    fileprivate var socket: NativeSocket?
    
    public var handle: SocketRawHandle? {
        return socket?.handle
    }
    
    fileprivate init?(addressType: IPAddressType, connectionType: ConnectionType) {
        guard let socket = NativeSocket(addressType: addressType, connectionType: connectionType) else { return nil }
        self.socket = socket
    }
    
    fileprivate init(handle: SocketRawHandle, addressType: IPAddressType, connectionType: ConnectionType) {
        self.socket = NativeSocket(handle: handle, addressType: addressType, connectionType: connectionType)
    }
    
    public var isNonBlockingEnabled: Bool {
        get {
            guard let socket = socket else { return true }
            let flags = fcntl(socket.handle, F_GETFL, 0)
            return (flags & O_NONBLOCK) != 0
        }
        set {
            guard let socket = socket else { return }
            
            if newValue {
                let flags = fcntl(socket.handle, F_GETFL, 0)
                _ = fcntl(socket.handle, F_SETFL, flags | O_NONBLOCK);
            } else {
                var flags = fcntl(socket.handle, F_GETFL, 0)
                flags = flags & (~O_NONBLOCK)
                _ = fcntl(socket.handle, F_SETFL, flags);
            }
        }
    }
    
    public func addressType() throws -> IPAddressType {
        guard let socket = socket else { throw SocketError.socketClosed }
        return socket.addressType
    }
    
    public func connectionType() throws -> ConnectionType {
        guard let socket = socket else { throw SocketError.socketClosed }
        return socket.connectionType
    }
    
    public func getOption(_ option: SocketOption) throws -> SocketOption {
        guard let socket = socket else { throw SocketError.socketClosed }

        var value: UInt32 = 0
        var length: UInt32 = UInt32(MemoryLayout<UInt32>.size)
        guard getsockopt(socket.handle, SOL_SOCKET, option.constant, &value, &length) >= 0 else { throw SocketError.currentFailure }
        return SocketOption.create(option, value: value)
    }
    
    public func setOption(_ option: SocketOption) throws {
        guard let socket = socket else { throw SocketError.socketClosed }

        var value: UInt32 = option.value
        guard setsockopt(socket.handle, SOL_SOCKET, option.constant, &value, UInt32(MemoryLayout<UInt32>.size)) >= 0 else { throw SocketError.currentFailure }
    }
    
    public func close() throws {
        guard let socket = socket else { throw SocketError.socketClosed }

        let result = Socket.close(socket.handle)
        guard result >= 0 else { throw SocketError.currentFailure }
        self.socket = nil
    }
    
    /// MARK: Cross platform socket calls
    #if os(Linux)
    public static let STREAM: Int32 = Int32(SOCK_STREAM.rawValue)
    public static let DGRAM: Int32 = Int32(SOCK_DGRAM.rawValue)
    
    fileprivate static func close(_ handle: SocketRawHandle) -> Int32 {
        return Glibc.close(handle)
    }
    
    fileprivate static func bind(_ handle: SocketRawHandle, _ ptr: UnsafePointer<sockaddr>!, _ size: socklen_t) -> Int32 {
        return Glibc.close(handle)
    }
    
    fileprivate static func connect(_ handle: SocketRawHandle, _ ptr: UnsafePointer<sockaddr>!, _ size: socklen_t) -> Int32 {
        return Glibc.connect(handle, ptr, size)
    }
    
    fileprivate static func recvfrom(_ handle: SocketRawHandle, _ buf: UnsafeMutableRawPointer!, _ len: Int, _ flags: Int32,
    _ ptr: UnsafeMutablePointer<sockaddr>!, _ size: UnsafeMutablePointer<socklen_t>) -> Int {
        return Glibc.recvfrom(handle, buf, len, flags, ptr, size)
    }
    
    fileprivate static func sendto(_ handle: SocketRawHandle, _ dataPtr: UnsafeRawPointer, _ dataLen: Int, _ flags: Int32, _ addrPtr: UnsafePointer<sockaddr>, _ addrLen: socklen_t) -> Int {
        return Glibc.sendto(handle, dataPtr, dataLen, flags, addrPtr, addrLen)
    }
    
    fileprivate static func read(_ handle: SocketRawHandle, _ dataPtr: UnsafeMutablePointer<UInt8>, _ dataLen: Int) -> Int {
        return Glibc.read(handle, dataPtr, dataLen)
    }
    
    fileprivate static func write(_ handle: SocketRawHandle, _ dataPtr: UnsafePointer<UInt8>, _ dataLen: Int) -> Int {
        return Glibc.write(handle, dataPtr, dataLen)
    }
    
    fileprivate static func listen(_ handle: SocketRawHandle, _ backlog: Int32) -> Int32 {
        return Glibc.listen(handle, backlog)
    }
    
    fileprivate static func accept(_ handle: SocketRawHandle, _ addrPtr: UnsafeMutablePointer<sockaddr>, _ addrLen: UnsafeMutablePointer<socklen_t>) -> Int32 {
        return Glibc.accept(handle, addrPtr, addrLen)
    }

    #else
    public static let STREAM: Int32 = SOCK_STREAM
    public static let DGRAM: Int32 = SOCK_DGRAM

    fileprivate static func close(_ handle: SocketRawHandle) -> Int32 {
        return Darwin.close(handle)
    }
    
    fileprivate static func bind(_ handle: SocketRawHandle, _ ptr: UnsafePointer<sockaddr>!, _ size: socklen_t) -> Int32 {
        return Darwin.close(handle)
    }
    
    fileprivate static func connect(_ handle: SocketRawHandle, _ ptr: UnsafePointer<sockaddr>!, _ size: socklen_t) -> Int32 {
        return Darwin.connect(handle, ptr, size)
    }
    
    fileprivate static func recvfrom(_ handle: SocketRawHandle, _ buf: UnsafeMutableRawPointer!, _ len: Int, _ flags: Int32,
                                     _ ptr: UnsafeMutablePointer<sockaddr>!, _ size: UnsafeMutablePointer<socklen_t>) -> Int {
        return Darwin.recvfrom(handle, buf, len, flags, ptr, size)
    }
    
    fileprivate static func sendto(_ handle: SocketRawHandle, _ dataPtr: UnsafeRawPointer, _ dataLen: Int, _ flags: Int32, _ addrPtr: UnsafePointer<sockaddr>, _ addrLen: socklen_t) -> Int {
        return Darwin.sendto(handle, dataPtr, dataLen, flags, addrPtr, addrLen)
    }
    
    fileprivate static func read(_ handle: SocketRawHandle, _ dataPtr: UnsafeMutablePointer<UInt8>, _ dataLen: Int) -> Int {
        return Darwin.read(handle, dataPtr, dataLen)
    }
    
    fileprivate static func write(_ handle: SocketRawHandle, _ dataPtr: UnsafePointer<UInt8>, _ dataLen: Int) -> Int {
        return Darwin.write(handle, dataPtr, dataLen)
    }
    
    fileprivate static func listen(_ handle: SocketRawHandle, _ backlog: Int32) -> Int32 {
        return Darwin.listen(handle, backlog)
    }
    
    fileprivate static func accept(_ handle: SocketRawHandle, _ addrPtr: UnsafeMutablePointer<sockaddr>, _ addrLen: UnsafeMutablePointer<socklen_t>) -> Int32 {
        return Darwin.accept(handle, addrPtr, addrLen)
    }
    
    #endif
}

/*---------------------------------------------------------------*/

public class UDPServerSocket: Socket {
    public let port: Port
    
    public required init?(port: Port, bufferSize: Int = 128, addressType: IPAddressType = .version4) {
        self.port = port
        super.init(addressType: addressType, connectionType: .udp)
        do {
            try setOption(.SendBufferSize(bufferSize))
            try setOption(.ReuseAddress(true))
        } catch {
            return nil
        }
    }

    public func bind() throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        
        let localAddress = IPAddress.localhost(withPort: port, type: socket.addressType)
        let result = localAddress.withUnsafeNativePointer { (ptr, size) in Socket.bind(socket.handle, ptr, size) }
        guard result >= 0 else { throw SocketError.currentFailure }
    }
    
    public func receive(numberOfBytes: Int) throws -> (Data, IPAddress)? {
        guard let socket = socket else { throw SocketError.socketClosed }
        return try socket.receive(numberOfBytes: numberOfBytes)
    }
    
    public func send(_ data: Data, to clientAddress: IPAddress) throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        try socket.send(data, to: clientAddress)
    }
}

public class UDPClientSocket: Socket {
    public let remoteAddress: IPAddress
    
    public required init?(remoteAddress: IPAddress) {
        self.remoteAddress = remoteAddress
        super.init(addressType: remoteAddress.type, connectionType: .udp)
    }
    
    public func connect() throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        let result = remoteAddress.withUnsafeNativePointer { (ptr, size) in Socket.connect(socket.handle, ptr, size) }
        guard result >= 0 else { throw SocketError.currentFailure }
    }
    
    /// Reads bytes of the socket. If the socket is blocking, this will never return nil. If the socket
    /// is non-blocking, then this may return nil only when there is not any more data remaining to read.
    ///
    /// - Parameter numberOfBytes: Number of bytes to read from the socket
    /// - Returns: The bytes read from the socket and wrapped in a Data object
    /// - Throws: May throw when a socket is closed, the incoming data is not from the expected server ip address,
    ///           or an error reading from the socket
    public func receive(numberOfBytes: Int) throws -> Data? {
        guard let socket = socket else { throw SocketError.socketClosed }
        guard let (data, from) = try socket.receive(numberOfBytes: numberOfBytes) else { return nil }
        guard from == remoteAddress else { throw SocketError.receivedDataFromUnexpectedSender }
        return data
    }
    
    public func send(_ data: Data) throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        try socket.send(data, to: remoteAddress)
    }
}

// UDP extension
fileprivate extension NativeSocket {
    
    func receive(numberOfBytes: Int) throws -> (Data, IPAddress)? {
        var rawClientAddress: sockaddr_in6 = sockaddr_in6()
        return try withUnsafePointer(to: &rawClientAddress) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                var addressLength: socklen_t = IPAddressType.version6.size
                var buffer = Array<UInt8>(repeating: 0, count: numberOfBytes)
                let pointer = UnsafeMutablePointer<sockaddr>(mutating: $0)
                let bytesReadCount = Socket.recvfrom(handle, &buffer, numberOfBytes, 0, pointer, &addressLength)
                let endOfStream = bytesReadCount == -1 && SocketErrorCode.current == .WOULDBLOCK
                guard !endOfStream else { return nil }
                guard bytesReadCount != -1 else { throw SocketError.currentFailure }
                guard let clientAddress = IPAddress(addressPtr: $0, size: addressLength) else { throw SocketError.internalError }
                let data = Data(bytes: &buffer, count: bytesReadCount)
                return (data, clientAddress)
            }
        }
    }
    
    func send(_ data: Data, to remoteAddress: IPAddress) throws {
        let numberOfBytesSent = data.withUnsafeBytes { bytes in
            remoteAddress.withUnsafeNativePointer { (ptr, size) in Socket.sendto(handle, bytes, data.count, 0, ptr, size) }
        }
        guard numberOfBytesSent == data.count else { throw SocketError.currentFailure }
    }
}

/*---------------------------------------------------------------*/

public class TCPClientSocket: Socket {
    public let remoteAddress: IPAddress
    
    public init?(remoteAddress: IPAddress) {
        self.remoteAddress = remoteAddress
        super.init(addressType: remoteAddress.type, connectionType: .tcp)
    }
    
    fileprivate init(remoteAddress: IPAddress, handle: SocketRawHandle) {
        self.remoteAddress = remoteAddress
        super.init(handle: handle, addressType: remoteAddress.type, connectionType: .tcp)
    }
    
    public func connect() throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        let result = remoteAddress.withUnsafeNativePointer { (ptr, size) in Socket.connect(socket.handle, ptr, size) }
        guard result >= 0 else { throw SocketError.currentFailure }
    }
    
    public func read(numberOfBytes: Int) throws -> Data? {
        guard let socket = socket else { throw SocketError.socketClosed }
        var buffer = Array<UInt8>(repeating: 0, count: numberOfBytes)
        let result = Socket.read(socket.handle, &buffer, numberOfBytes)
        guard result != 0 else { return nil }
        guard result > 0 else { throw SocketError.currentFailure }
        return Data(bytes: &buffer, count: numberOfBytes)
    }
    
    public func write(_ data: Data) throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        
        let result = data.withUnsafeBytes { (ptr: UnsafePointer<UInt8>) -> Int in
            return Socket.write(socket.handle, ptr, data.count)
        }
        guard result == data.count else { throw SocketError.currentFailure }
    }
}

public class TCPServerSocket: Socket {
    private enum StreamMode {
        case unbound(Port)
        case acceptingConnections(Port)
        case closed
    }
    
    private var mode: StreamMode = .unbound(0)
    
    public init?(port: Port, type: IPAddressType = IPAddress.localhost().type) {
        self.mode = .unbound(port)
        super.init(addressType: type, connectionType: .tcp)
        
        do {
            try setOption(.ReuseAddress(true))
        } catch {
            return nil
        }
    }
    
    public func listen(withBacklog backlog: Int = 128) throws {
        guard let socket = socket else { throw SocketError.socketClosed }

        let result = Socket.listen(socket.handle, Int32(backlog))
        guard result >= 0 else { throw SocketError.currentFailure }
    }
    
    public func bind() throws {
        guard let socket = socket else { throw SocketError.socketClosed }
        guard case .unbound(let localPort) = mode else { throw SocketError.internalError }

        let localAddress = IPAddress.localhost(withPort: localPort)
        let result = localAddress.withUnsafeNativePointer { (ptr, size) in Socket.bind(socket.handle, ptr, size) }
        guard result >= 0 else { throw SocketError.currentFailure }
        mode = .acceptingConnections(localPort)
    }
    
    public func accept() throws -> TCPClientSocket? {
        guard let socket = socket else { throw SocketError.socketClosed }
        guard case .acceptingConnections = mode else { throw SocketError.internalError }

        var rawClientAddress: sockaddr_in6 = sockaddr_in6()
        return try withUnsafePointer(to: &rawClientAddress) {
            try $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                var addressLength: socklen_t = IPAddressType.version6.size
                let pointer = UnsafeMutablePointer<sockaddr>(mutating: $0)
                let handle = Socket.accept(socket.handle, pointer , &addressLength)
                guard handle >= 0 else { return nil }
                guard let clientAddress = IPAddress(addressPtr: $0, size: addressLength) else { throw SocketError.internalError }
                return TCPClientSocket(remoteAddress: clientAddress, handle: handle)
            }
        }
    }
    
    public override func close() throws {
        self.mode = .closed
        try super.close()
    }
}

/*---------------------------------------------------------------*/

fileprivate extension ConnectionType {
    var socketType: Int32 {
        switch self {
        case .tcp: return Socket.STREAM
        case .udp: return Socket.DGRAM
        }
    }
}

fileprivate extension IPAddressType {
    var family: sa_family_t {
        switch self {
        case .version6: return sa_family_t(PF_INET6)
        case .version4: return sa_family_t(PF_INET)
        }
    }
}
