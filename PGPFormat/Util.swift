//
//  Util.swift
//  PGPFormat
//
//  Created by Alex Grinman on 5/15/17.
//  Copyright © 2017 KryptCo, Inc. All rights reserved.
//


import Foundation
import Crypto

public enum DataError : Error {
    case encoding
    case cryptoRandom
    case fingerprint
    case tooShort(Int)
    case range(Int,Int)
}

public struct MPInt {
    
    public var data:Data
    
    /**
        Initialize an MPInt with integer bytes
        remove any leading zero bytes
     */
    public init(integerData:Data) {
        let bytes = integerData.bytes
        
        var startingIndex = 0
        for byte in bytes {
            guard Int(byte) == 0 else {
                break
            }
            
            startingIndex += 1
        }
        
        self.data = Data(bytes[startingIndex ..< bytes.count])
    }
    
    /**
        Initialize an MPInt with MPInt bytes
     */
    public init(mpintData:Data) throws {
        guard mpintData.count >= 2 else {
            throw DataError.tooShort(mpintData.count)
        }
        
        let bytes = mpintData.bytes
        
        var ptr = 0
        
        let length = Int(UInt32(bigEndianBytes: [UInt8](bytes[ptr ... ptr + 1])) + 7)/8
        ptr += 2
        
        guard bytes.count >= ptr + length else {
            throw DataError.tooShort(bytes.count)
        }
        
        data = Data(bytes[ptr ..< (ptr + length)])
    }
    
    public var byteLength:Int {
        return 2 + Int(UInt32(bigEndianBytes: lengthBytes) + 7)/8
    }
    
    public var lengthBytes:[UInt8] {
        return data.numBits.twoByteBigEndianBytes()
    }
    
}
extension Int {
    var numBits:Int {
        guard self > 0 else {
            return 0
        }
        
        return Int(floor(log2(Double(self)))) + 1
    }
}

extension Data {
    var SHA512: Data {
        let hash = Crypto.SHA512.hash(data: Data.init(self.bytes))
        
        return Data(hash)
    }

    var SHA384: Data {
        let hash = Crypto.SHA384.hash(data: Data.init(self.bytes))
        
        return Data(hash)
    }

    var SHA256: Data {
        let hash = Crypto.SHA256.hash(data: Data.init(self.bytes))
        
        return Data(hash)
    }
    
    var SHA1: Data {
        let hash = Crypto.Insecure.SHA1.hash(data: Data.init(self.bytes));

        return Data(hash)
    }
}


extension Data {
    
    var numBits:Int {
        guard count > 0 else {
            return 0
        }
        
        let dataBytes = self.bytes
        
        var byteIndex = 0
        for byte in dataBytes {
            guard Int(byte) == 0 else {
                break
            }
            
            byteIndex += 1
        }
        
        guard byteIndex < count else {
            return 0
        }
        
        let firstByteBits = Int(dataBytes[byteIndex]).numBits
        let remainingBytesBits = (count - byteIndex - 1)*8
        
        return firstByteBits + remainingBytesBits
    }

    internal var bytes:[UInt8] {
        return self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            [UInt8](UnsafeRawBufferPointer(start: bytes.baseAddress, count: self.count))
        }
    }
    
    var crc24Checksum:Data {
        let checksum = CRC24.generate(fromBytes: self.bytes)
        
        return Data(checksum.threeByteBigEndianBytes())
    }
    
    /**
        Create a new byte array with prepended zeros
        so that the final length is equal to `length`.
 
        If the length is greater than `length`, return itself.
     */
    func padPrependedZeros(upto length:Int) -> Data {
        guard self.count < length else {
            return Data(self)
        }
        
        let zeros = Data(repeating: 0, count: length - self.count)
        
        var padded = Data()
        padded.append(zeros)
        padded.append(self)
        
        return padded
    }

    
    func toBase64(_ urlEncoded:Bool = false) -> String {
        var result = self.base64EncodedString(options: NSData.Base64EncodingOptions(rawValue: 0))
        
        if urlEncoded {
            result = result.replacingOccurrences(of: "/", with: "_")
            result = result.replacingOccurrences(of: "+", with: "-")
        }
        
        return result
    }
    
    func byteArray() -> [String] {
        var array:[String] = []
        
        for i in 0 ..< self.count  {
            var byte: UInt8 = 0
            (self as NSData).getBytes(&byte, range: NSMakeRange(i, 1))
            array.append(NSString(format: "%d", byte) as String)
        }
        
        return array
    }
    
    
    func safeSubdata(in range:Range<Int>) throws -> Data {
        guard   self.count >= range.lowerBound + 1,
                self.count >= range.upperBound
        else {
            throw DataError.range(range.lowerBound, range.upperBound)
        }

        return self.subdata(in: range)
    }
    
    var hex:String {
        let bytes = self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            [UInt8](UnsafeRawBufferPointer(start: bytes.baseAddress, count: self.count))
        }
        
        var hexString = ""
        for i in 0..<self.count {
            hexString += String(format: "%02x", bytes[i])
        }
        return hexString
    }
    
    var hexPretty:String {
        let bytes = self.bytes
        
        var hex = ""
        for i in 0..<self.count {
            hex += String(format: "%02x ", bytes[i])
        }
        
        return hex.uppercased()
    }
}

extension NSMutableData {
    func byteArray() -> [String] {
        var array:[String] = []
        
        for i in 0 ..< self.length  {
            var byte: UInt8 = 0
            self.getBytes(&byte, range: NSMakeRange(i, 1))
            array.append(NSString(format: "%d", byte) as String)
        }
        
        return array
    }
}

extension String {
    func fromBase64() throws -> Data {
        var urlDecoded = self
        urlDecoded = urlDecoded.replacingOccurrences(of: "_", with: "/")
        urlDecoded = urlDecoded.replacingOccurrences(of: "-", with: "+")
        
        guard let data = Data(base64Encoded: urlDecoded, options: Data.Base64DecodingOptions.ignoreUnknownCharacters) else {
            throw DataError.encoding
        }
        
        return data
    }
}

extension Data {
    func bigEndianByteSize() -> [UInt8] {
        return stride(from: 24, through: 0, by: -8).map {
            UInt8(truncatingIfNeeded: UInt32(self.count).littleEndian >> UInt32($0))
        }
    }
}

extension UInt32 {
    init(bigEndianBytes: [UInt8]) {
        let count = UInt32(bigEndianBytes.count)
        
        var val : UInt32 = 0
        for i in UInt32(0) ..< count {
            val += UInt32(bigEndianBytes[Int(i)]) << ((count - 1 - i) * 8)
        }
        self.init(val)
    }
    
    func fourByteBigEndianBytes() -> [UInt8] {
        return [UInt8((self >> 24) % 256), UInt8((self >> 16) % 256), UInt8((self >> 8) % 256), UInt8((self) % 256)]
    }
    
    func threeByteBigEndianBytes() -> [UInt8] {
        return [UInt8((self >> 16) % 256), UInt8((self >> 8) % 256), UInt8((self) % 256)]
    }
    
    func twoByteBigEndianBytes() -> [UInt8] {
        return [UInt8((self >> 8) % 256), UInt8((self) % 256)]
    }
}

extension Int {
    func twoByteBigEndianBytes() -> [UInt8] {
        return [UInt8((self >> 8) % 256), UInt8((self) % 256)]
    }
}
