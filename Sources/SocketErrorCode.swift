//
//  SocketErrorCode.swift
//
//  Created by Michael Sanford on 10/2/16.
//  Copyright © 2016 flipside5. All rights reserved.
//

import Foundation

public enum SocketErrorCode: Int32 {
    case PERM = 1
    case NOENT = 2
    case SRCH = 3
    case INTR = 4
    case IO = 5
    case NXIO = 6
    case TOOBIG = 7
    case NOEXEC = 8
    case BADF = 9
    case CHILD = 10
    case DEADLK = 11
    case NOMEM = 12
    case ACCES = 13
    case FAULT = 14
    case NOTBLK = 15
    case BUSY = 16
    case EXIST = 17
    case XDEV = 18
    case NODEV = 19
    case NOTDIR = 20
    case ISDIR = 21
    case INVAL = 22
    case NFILE = 23
    case MFILE = 24
    case NOTTY = 25
    case TXTBSY = 26
    case FBIG = 27
    case NOSPC = 28
    case SPIPE = 29
    case ROFS = 30
    case MLINK = 31
    case PIPE = 32
    case DOM = 33
    case RANGE = 34
    case WOULDBLOCK = 35 // AGAIN
    case INPROGRESS = 36
    case ALREADY = 37
    case NOTSOCK = 38
    case DESTADDRREQ = 39
    case MSGSIZE = 40
    case PROTOTYPE = 41
    case NOPROTOOPT = 42
    case PROTONOSUPPORT = 43
    case SOCKTNOSUPPORT = 44
    case NOTSUP = 45
    case PFNOSUPPORT = 46
    case AFNOSUPPORT = 47
    case ADDRINUSE = 48
    case ADDRNOTAVAIL = 49
    case NETDOWN = 50
    case NETUNREACH = 51
    case NETRESET = 52
    case CONNABORTED = 53
    case CONNRESET = 54
    case NOBUFS = 55
    case ISCONN = 56
    case NOTCONN = 57
    case SHUTDOWN = 58
    case TOOMANYREFS = 59
    case TIMEDOUT = 60
    case CONNREFUSED = 61
    case LOOP = 62
    case NAMETOOLONG = 63
    case HOSTDOWN = 64
    case HOSTUNREACH = 65
    case NOTEMPTY = 66
    case PROCLIM = 67
    case USERS = 68
    case DQUOT = 69
    case STALE = 70
    case REMOTE = 71
    case BADRPC = 72
    case RPCMISMATCH = 73
    case PROGUNAVAIL = 74
    case PROGMISMATCH = 75
    case PROCUNAVAIL = 76
    case NOLCK = 77
    case NOSYS = 78
    case FTYPE = 79
    case AUTH = 80
    case NEEDAUTH = 81
    case PWROFF = 82
    case DEVERR = 83
    case OVERFLOW = 84
    case BADEXEC = 85
    case BADARCH = 86
    case SHLIBVERS = 87
    case BADMACHO = 88
    case CANCELED = 89
    case IDRM = 90
    case NOMSG = 91
    case ILSEQ = 92
    case NOATTR = 93
    case BADMSG = 94
    case MULTIHOP = 95
    case NODATA = 96
    case NOLINK = 97
    case NOSR = 98
    case NOSTR = 99
    case PROTO = 100
    case TIME = 101
    case OPNOTSUPP = 102
    case NOPOLICY = 103
    case unknown = 999
    
    public static var current: SocketErrorCode {
        return SocketErrorCode(rawValue: errno) ?? SocketErrorCode.unknown
    }
}
