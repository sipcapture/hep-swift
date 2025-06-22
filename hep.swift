import Foundation
import Network
import Compression
import CryptoKit

// MARK: - HEP Protocol Structures

struct HEPChunk {
    let vendorId: UInt16
    let typeId: UInt16
    let length: UInt16
    
    func toData() -> Data {
        var data = Data()
        data.append(vendorId.bigEndian.data)
        data.append(typeId.bigEndian.data)
        data.append(length.bigEndian.data)
        return data
    }
}

struct HEPChunkUInt8 {
    let chunk: HEPChunk
    let data: UInt8
    
    func toData() -> Data {
        var result = chunk.toData()
        result.append(data)
        return result
    }
}

struct HEPChunkUInt16 {
    let chunk: HEPChunk
    let data: UInt16
    
    func toData() -> Data {
        var result = chunk.toData()
        result.append(data.bigEndian.data)
        return result
    }
}

struct HEPChunkUInt32 {
    let chunk: HEPChunk
    let data: UInt32
    
    func toData() -> Data {
        var result = chunk.toData()
        result.append(data.bigEndian.data)
        return result
    }
}

struct HEPChunkIP4 {
    let chunk: HEPChunk
    let data: Data // 4 bytes for IPv4 address
    
    func toData() -> Data {
        var result = chunk.toData()
        result.append(data)
        return result
    }
}

struct HEPChunkIP6 {
    let chunk: HEPChunk
    let data: Data // 16 bytes for IPv6 address
    
    func toData() -> Data {
        var result = chunk.toData()
        result.append(data)
        return result
    }
}

struct HEPControl {
    let id: Data // 4 bytes: "HEP3"
    let length: UInt16
    
    func toData() -> Data {
        var result = id
        result.append(length.bigEndian.data)
        return result
    }
}

struct HEPGeneric {
    let header: HEPControl
    let ipFamily: HEPChunkUInt8
    let ipProto: HEPChunkUInt8
    let srcPort: HEPChunkUInt16
    let dstPort: HEPChunkUInt16
    let timeSec: HEPChunkUInt32
    let timeUsec: HEPChunkUInt32
    let protoType: HEPChunkUInt8
    let captId: HEPChunkUInt32
    
    func toData() -> Data {
        var result = Data()
        result.append(header.toData())
        result.append(ipFamily.toData())
        result.append(ipProto.toData())
        result.append(srcPort.toData())
        result.append(dstPort.toData())
        result.append(timeSec.toData())
        result.append(timeUsec.toData())
        result.append(protoType.toData())
        result.append(captId.toData())
        return result
    }
}

// HEP v2 structures
struct HEPHeader {
    let version: UInt8
    let length: UInt8
    let family: UInt8
    let protocol: UInt8
    let srcPort: UInt16
    let dstPort: UInt16
    
    func toData() -> Data {
        var data = Data()
        data.append(version)
        data.append(length)
        data.append(family)
        data.append(`protocol`)
        data.append(srcPort.bigEndian.data)
        data.append(dstPort.bigEndian.data)
        return data
    }
}

struct HEPTimeHeader {
    let tvSec: UInt32
    let tvUsec: UInt32
    let captId: UInt16
    
    func toData() -> Data {
        var data = Data()
        data.append(tvSec.bigEndian.data)
        data.append(tvUsec.bigEndian.data)
        data.append(captId.bigEndian.data)
        return data
    }
}

// MARK: - Remote Connection Info

struct RemoteConnectionInfo {
    let ipFamily: UInt8  // AF_INET or AF_INET6
    let ipProto: UInt8   // IPPROTO_UDP, IPPROTO_TCP
    let srcIP: String
    let dstIP: String
    let srcPort: UInt16
    let dstPort: UInt16
    let timeSec: UInt32
    let timeUsec: UInt32
    let protoType: UInt8
}

// MARK: - HEP Capture Agent

class HEPCaptureAgent {
    
    // Configuration
    private var captHost: String = "10.0.0.1"
    private var captPort: String = "9060"
    private var captPassword: String?
    private var captId: UInt32 = 101
    private var hepVersion: Int = 3
    private var useSSL: Bool = false
    private var plCompress: Bool = false
    
    // Network
    private var connection: NWConnection?
    private var queue = DispatchQueue(label: "hep.capture.agent")
    
    // Statistics
    private var sendPacketsCount: Int = 0
    private var initFails: Int = 0
    
    // Constants
    private let AF_INET: UInt8 = 2
    private let AF_INET6: UInt8 = 30
    private let IPPROTO_UDP: UInt8 = 17
    private let IPPROTO_TCP: UInt8 = 6
    
    init(host: String = "10.0.0.1", 
         port: String = "9060", 
         captureId: UInt32 = 101,
         version: Int = 3,
         useSSL: Bool = false,
         compress: Bool = false,
         password: String? = nil) {
        self.captHost = host
        self.captPort = port
        self.captId = captureId
        self.hepVersion = version
        self.useSSL = useSSL
        self.plCompress = compress
        self.captPassword = password
    }
    
    // MARK: - Public API
    
    func sendHEPBasic(rcInfo: RemoteConnectionInfo, data: Data) -> Bool {
        var processedData = data
        var isCompressed = false
        
        // Handle compression for HEP v3
        if plCompress && hepVersion == 3 {
            if let compressedData = compressData(data) {
                processedData = compressedData
                isCompressed = true
            }
        }
        
        switch hepVersion {
        case 3:
            return sendHEPv3(rcInfo: rcInfo, data: processedData, isCompressed: isCompressed)
        case 1, 2:
            return sendHEPv2(rcInfo: rcInfo, data: processedData)
        default:
            print("Unsupported HEP version [\(hepVersion)]")
            return false
        }
    }
    
    // MARK: - HEP v3 Implementation
    
    private func sendHEPv3(rcInfo: RemoteConnectionInfo, data: Data, isCompressed: Bool) -> Bool {
        // Create HEP header
        let hepId = "HEP3".data(using: .ascii)!
        
        // Calculate total length (will be updated later)
        var totalLength: UInt16 = 0
        
        // Create chunks
        let ipFamilyChunk = HEPChunkUInt8(
            chunk: HEPChunk(vendorId: 0, typeId: 0x0001, length: 7),
            data: rcInfo.ipFamily
        )
        
        let ipProtoChunk = HEPChunkUInt8(
            chunk: HEPChunk(vendorId: 0, typeId: 0x0002, length: 7),
            data: rcInfo.ipProto
        )
        
        var buffer = Data()
        var ipLength: Int = 0
        
        // Handle IP addresses
        if rcInfo.ipFamily == AF_INET {
            // IPv4 addresses
            guard let srcIPData = ipv4StringToData(rcInfo.srcIP),
                  let dstIPData = ipv4StringToData(rcInfo.dstIP) else {
                print("Invalid IPv4 addresses")
                return false
            }
            
            let srcIP4Chunk = HEPChunkIP4(
                chunk: HEPChunk(vendorId: 0, typeId: 0x0003, length: 10),
                data: srcIPData
            )
            
            let dstIP4Chunk = HEPChunkIP4(
                chunk: HEPChunk(vendorId: 0, typeId: 0x0004, length: 10),
                data: dstIPData
            )
            
            buffer.append(srcIP4Chunk.toData())
            buffer.append(dstIP4Chunk.toData())
            ipLength = 20 // 2 * 10 bytes
            
        } else if rcInfo.ipFamily == AF_INET6 {
            // IPv6 addresses
            guard let srcIPData = ipv6StringToData(rcInfo.srcIP),
                  let dstIPData = ipv6StringToData(rcInfo.dstIP) else {
                print("Invalid IPv6 addresses")
                return false
            }
            
            let srcIP6Chunk = HEPChunkIP6(
                chunk: HEPChunk(vendorId: 0, typeId: 0x0005, length: 22),
                data: srcIPData
            )
            
            let dstIP6Chunk = HEPChunkIP6(
                chunk: HEPChunk(vendorId: 0, typeId: 0x0006, length: 22),
                data: dstIPData
            )
            
            buffer.append(srcIP6Chunk.toData())
            buffer.append(dstIP6Chunk.toData())
            ipLength = 44 // 2 * 22 bytes
        }
        
        let srcPortChunk = HEPChunkUInt16(
            chunk: HEPChunk(vendorId: 0, typeId: 0x0007, length: 8),
            data: rcInfo.srcPort
        )
        
        let dstPortChunk = HEPChunkUInt16(
            chunk: HEPChunk(vendorId: 0, typeId: 0x0008, length: 8),
            data: rcInfo.dstPort
        )
        
        let timeSecChunk = HEPChunkUInt32(
            chunk: HEPChunk(vendorId: 0, typeId: 0x0009, length: 10),
            data: rcInfo.timeSec
        )
        
        let timeUsecChunk = HEPChunkUInt32(
            chunk: HEPChunk(vendorId: 0, typeId: 0x000a, length: 10),
            data: rcInfo.timeUsec
        )
        
        let protoTypeChunk = HEPChunkUInt8(
            chunk: HEPChunk(vendorId: 0, typeId: 0x000b, length: 7),
            data: rcInfo.protoType
        )
        
        let captIdChunk = HEPChunkUInt32(
            chunk: HEPChunk(vendorId: 0, typeId: 0x000c, length: 10),
            data: captId
        )
        
        // Payload chunk
        let payloadTypeId: UInt16 = isCompressed ? 0x0010 : 0x000f
        let payloadChunk = HEPChunk(
            vendorId: 0,
            typeId: payloadTypeId,
            length: UInt16(6 + data.count)
        )
        
        // Calculate total length
        totalLength = UInt16(6 + // header
                           7 + 7 + // ip_family + ip_proto
                           ipLength + // IP addresses
                           8 + 8 + // ports
                           10 + 10 + // timestamps
                           7 + 10 + // proto_type + capt_id
                           6 + data.count) // payload chunk + data
        
        // Add auth key if present
        var authKeyData = Data()
        if let password = captPassword {
            let authKeyChunk = HEPChunk(
                vendorId: 0,
                typeId: 0x000e,
                length: UInt16(6 + password.count)
            )
            authKeyData.append(authKeyChunk.toData())
            authKeyData.append(password.data(using: .utf8)!)
            totalLength += UInt16(6 + password.count)
        }
        
        // Create final header
        let header = HEPControl(id: hepId, length: totalLength)
        
        // Assemble final packet
        var finalBuffer = Data()
        finalBuffer.append(header.toData())
        finalBuffer.append(ipFamilyChunk.toData())
        finalBuffer.append(ipProtoChunk.toData())
        finalBuffer.append(buffer) // IP addresses
        finalBuffer.append(srcPortChunk.toData())
        finalBuffer.append(dstPortChunk.toData())
        finalBuffer.append(timeSecChunk.toData())
        finalBuffer.append(timeUsecChunk.toData())
        finalBuffer.append(protoTypeChunk.toData())
        finalBuffer.append(captIdChunk.toData())
        
        if !authKeyData.isEmpty {
            finalBuffer.append(authKeyData)
        }
        
        finalBuffer.append(payloadChunk.toData())
        finalBuffer.append(data)
        
        return sendData(finalBuffer)
    }
    
    // MARK: - HEP v2 Implementation
    
    private func sendHEPv2(rcInfo: RemoteConnectionInfo, data: Data) -> Bool {
        let header = HEPHeader(
            version: UInt8(hepVersion),
            length: 0, // Will be calculated
            family: rcInfo.ipFamily,
            protocol: rcInfo.ipProto,
            srcPort: rcInfo.srcPort,
            dstPort: rcInfo.dstPort
        )
        
        var buffer = Data()
        var ipHeaderLength = 0
        
        // Add IP addresses
        if rcInfo.ipFamily == AF_INET {
            guard let srcIPData = ipv4StringToData(rcInfo.srcIP),
                  let dstIPData = ipv4StringToData(rcInfo.dstIP) else {
                print("Invalid IPv4 addresses")
                return false
            }
            buffer.append(srcIPData)
            buffer.append(dstIPData)
            ipHeaderLength = 8
        } else if rcInfo.ipFamily == AF_INET6 {
            guard let srcIPData = ipv6StringToData(rcInfo.srcIP),
                  let dstIPData = ipv6StringToData(rcInfo.dstIP) else {
                print("Invalid IPv6 addresses")
                return false
            }
            buffer.append(srcIPData)
            buffer.append(dstIPData)
            ipHeaderLength = 32
        }
        
        // Update header length
        let totalHeaderLength = 8 + ipHeaderLength // base header + IP addresses
        var updatedHeader = header
        updatedHeader = HEPHeader(
            version: header.version,
            length: UInt8(totalHeaderLength),
            family: header.family,
            protocol: header.protocol,
            srcPort: header.srcPort,
            dstPort: header.dstPort
        )
        
        var finalBuffer = Data()
        finalBuffer.append(updatedHeader.toData())
        finalBuffer.append(buffer)
        
        // Add timestamp for version 2
        if hepVersion == 2 {
            let timeHeader = HEPTimeHeader(
                tvSec: rcInfo.timeSec,
                tvUsec: rcInfo.timeUsec,
                captId: UInt16(captId)
            )
            finalBuffer.append(timeHeader.toData())
        }
        
        finalBuffer.append(data)
        
        return sendData(finalBuffer)
    }
    
    // MARK: - Network Operations
    
    private func sendData(_ data: Data) -> Bool {
        guard let connection = self.connection else {
            if !initConnection() {
                return false
            }
            guard let newConnection = self.connection else {
                return false
            }
            return sendDataOnConnection(newConnection, data: data)
        }
        
        return sendDataOnConnection(connection, data: data)
    }
    
    private func sendDataOnConnection(_ connection: NWConnection, data: Data) -> Bool {
        var success = false
        let semaphore = DispatchSemaphore(value: 0)
        
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Send error: \(error)")
                success = false
            } else {
                self.sendPacketsCount += 1
                success = true
            }
            semaphore.signal()
        })
        
        semaphore.wait()
        return success
    }
    
    private func initConnection() -> Bool {
        guard let port = NWEndpoint.Port(captPort) else {
            print("Invalid port: \(captPort)")
            return false
        }
        
        let host = NWEndpoint.Host(captHost)
        let endpoint = NWEndpoint.hostPort(host: host, port: port)
        
        let parameters = NWParameters.udp
        if useSSL {
            parameters.defaultProtocolStack.applicationProtocols.insert(NWProtocolTLS.Options(), at: 0)
        }
        
        connection = NWConnection(to: endpoint, using: parameters)
        
        var isReady = false
        let semaphore = DispatchSemaphore(value: 0)
        
        connection?.stateUpdateHandler = { state in
            switch state {
            case .ready:
                isReady = true
                semaphore.signal()
            case .failed(let error):
                print("Connection failed: \(error)")
                isReady = false
                semaphore.signal()
            case .cancelled:
                print("Connection cancelled")
                isReady = false
                semaphore.signal()
            default:
                break
            }
        }
        
        connection?.start(queue: queue)
        
        let result = semaphore.wait(timeout: .now() + 5.0)
        if result == .timedOut {
            print("Connection timeout")
            connection?.cancel()
            connection = nil
            return false
        }
        
        return isReady
    }
    
    // MARK: - Utility Functions
    
    private func compressData(_ data: Data) -> Data? {
        return data.withUnsafeBytes { bytes in
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: data.count)
            defer { buffer.deallocate() }
            
            let compressedSize = compression_encode_buffer(
                buffer, data.count,
                bytes.bindMemory(to: UInt8.self).baseAddress!, data.count,
                nil, COMPRESSION_ZLIB
            )
            
            guard compressedSize > 0 else { return nil }
            
            return Data(bytes: buffer, count: compressedSize)
        }
    }
    
    private func ipv4StringToData(_ ipString: String) -> Data? {
        var addr = in_addr()
        guard inet_pton(AF_INET, ipString, &addr) == 1 else {
            return nil
        }
        return Data(bytes: &addr, count: MemoryLayout<in_addr>.size)
    }
    
    private func ipv6StringToData(_ ipString: String) -> Data? {
        var addr = in6_addr()
        guard inet_pton(AF_INET6, ipString, &addr) == 1 else {
            return nil
        }
        return Data(bytes: &addr, count: MemoryLayout<in6_addr>.size)
    }
    
    // MARK: - Statistics and Management
    
    func getStatistics() -> String {
        return "HEP Capture Agent Statistics:\nSent packets: \(sendPacketsCount)\nInit failures: \(initFails)"
    }
    
    func disconnect() {
        connection?.cancel()
        connection = nil
    }
    
    deinit {
        disconnect()
    }
}

// MARK: - Extensions

extension UInt16 {
    var data: Data {
        return withUnsafeBytes(of: self) { Data($0) }
    }
}

extension UInt32 {
    var data: Data {
        return withUnsafeBytes(of: self) { Data($0) }
    }
}

// MARK: - Usage Example

/*
// Example usage:
let agent = HEPCaptureAgent(
    host: "10.0.0.1",
    port: "9060",
    captureId: 101,
    version: 3,
    useSSL: false,
    compress: false,
    password: nil
)

let rcInfo = RemoteConnectionInfo(
    ipFamily: 2, // AF_INET
    ipProto: 17, // UDP
    srcIP: "192.168.1.1",
    dstIP: "192.168.1.2",
    srcPort: 5060,
    dstPort: 5060,
    timeSec: UInt32(Date().timeIntervalSince1970),
    timeUsec: 0,
    protoType: 1 // SIP
)

let sipMessage = "INVITE sip:user@example.com SIP/2.0\r\n".data(using: .utf8)!
let success = agent.sendHEPBasic(rcInfo: rcInfo, data: sipMessage)
print("Message sent: \(success)")
print(agent.getStatistics())
*/
