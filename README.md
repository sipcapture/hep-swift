# HEP Swift Library

A modern Swift implementation of the Homer Encapsulation Protocol (HEP) capture agent for duplicating SIP messages and other network protocols to Homer/SIPCAPTURE monitoring systems.

## Features

- ✅ **HEP v2 and v3 Protocol Support**
- ✅ **IPv4 and IPv6 Support**
- ✅ **SSL/TLS Encryption**
- ✅ **Payload Compression (zlib)**
- ✅ **Authentication Support**
- ✅ **Thread-Safe Operations**
- ✅ **Modern Swift Network Framework**
- ✅ **Memory Safe (No Manual Memory Management)**
- ✅ **Type Safe with Swift's Strong Typing**

## Requirements

- iOS 12.0+ / macOS 10.14+ / tvOS 12.0+ / watchOS 5.0+
- Swift 5.0+
- Xcode 10.0+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/hep-swift.git", from: "1.0.0")
]
```

### Manual Installation

1. Download the `HEPCaptureAgent.swift` file
2. Add it to your Xcode project
3. Import the necessary frameworks in your project:
   - `Network`
   - `Compression`
   - `CryptoKit`

## Quick Start

```swift
import Foundation

// Create HEP capture agent
let agent = HEPCaptureAgent(
    host: "10.0.0.1",        // Homer server IP
    port: "9060",            // Homer server port
    captureId: 101,          // Capture node ID
    version: 3,              // HEP version (2 or 3)
    useSSL: false,           // Enable SSL/TLS
    compress: false,         // Enable payload compression
    password: nil            // Authentication password
)

// Create connection info
let rcInfo = RemoteConnectionInfo(
    ipFamily: 2,             // AF_INET (IPv4)
    ipProto: 17,             // IPPROTO_UDP
    srcIP: "192.168.1.100",
    dstIP: "192.168.1.200",
    srcPort: 5060,
    dstPort: 5060,
    timeSec: UInt32(Date().timeIntervalSince1970),
    timeUsec: 0,
    protoType: 1             // Protocol type (1 = SIP)
)

// Send SIP message
let sipMessage = """
INVITE sip:alice@example.com SIP/2.0
Via: SIP/2.0/UDP 192.168.1.100:5060;branch=z9hG4bK-123456
From: Bob <sip:bob@example.com>;tag=abc123
To: Alice <sip:alice@example.com>
Call-ID: 123456789@192.168.1.100
CSeq: 1 INVITE
Contact: <sip:bob@192.168.1.100:5060>
Content-Length: 0

""".data(using: .utf8)!

let success = agent.sendHEPBasic(rcInfo: rcInfo, data: sipMessage)
print("Message sent successfully: \(success)")
```

## Detailed Examples

### 1. Basic SIP Message Capture

```swift
func captureSIPMessage() {
    let agent = HEPCaptureAgent(host: "homer.example.com", port: "9060")
    
    let connectionInfo = RemoteConnectionInfo(
        ipFamily: 2,  // IPv4
        ipProto: 17,  // UDP
        srcIP: "10.0.1.100",
        dstIP: "10.0.1.200",
        srcPort: 5060,
        dstPort: 5060,
        timeSec: UInt32(Date().timeIntervalSince1970),
        timeUsec: UInt32(Date().timeIntervalSince1970.truncatingRemainder(dividingBy: 1) * 1_000_000),
        protoType: 1  // SIP
    )
    
    let sipInvite = """
    INVITE sip:user@domain.com SIP/2.0
    Via: SIP/2.0/UDP 10.0.1.100:5060
    From: "Caller" <sip:caller@domain.com>;tag=12345
    To: "Callee" <sip:user@domain.com>
    Call-ID: call-id-12345@10.0.1.100
    CSeq: 1 INVITE
    Content-Type: application/sdp
    Content-Length: 142
    
    v=0
    o=- 12345 67890 IN IP4 10.0.1.100
    c=IN IP4 10.0.1.100
    m=audio 8000 RTP/AVP 0
    a=rtpmap:0 PCMU/8000
    """.data(using: .utf8)!
    
    if agent.sendHEPBasic(rcInfo: connectionInfo, data: sipInvite) {
        print("✅ SIP INVITE captured successfully")
    } else {
        print("❌ Failed to capture SIP INVITE")
    }
}
```

### 2. IPv6 with SSL and Compression

```swift
func captureWithAdvancedFeatures() {
    let agent = HEPCaptureAgent(
        host: "2001:db8::1",     // IPv6 Homer server
        port: "9061",            // SSL port
        captureId: 201,
        version: 3,
        useSSL: true,            // Enable SSL
        compress: true,          // Enable compression
        password: "secret123"    // Authentication
    )
    
    let connectionInfo = RemoteConnectionInfo(
        ipFamily: 30,            // AF_INET6
        ipProto: 6,              // TCP
        srcIP: "2001:db8::100",
        dstIP: "2001:db8::200",
        srcPort: 5060,
        dstPort: 5060,
        timeSec: UInt32(Date().timeIntervalSince1970),
        timeUsec: 0,
        protoType: 1
    )
    
    let largePayload = String(repeating: "SIP message data ", count: 100).data(using: .utf8)!
    
    let result = agent.sendHEPBasic(rcInfo: connectionInfo, data: largePayload)
    print("Compressed IPv6 SSL capture: \(result ? "Success" : "Failed")")
    
    // Print statistics
    print(agent.getStatistics())
}
```

### 3. Real-time SIP Packet Capture Integration

```swift
import Network

class SIPMonitor {
    private let hepAgent: HEPCaptureAgent
    private var udpListener: NWListener?
    
    init(homerHost: String, homerPort: String) {
        self.hepAgent = HEPCaptureAgent(
            host: homerHost,
            port: homerPort,
            captureId: 100,
            version: 3
        )
        
        setupUDPListener()
    }
    
    private func setupUDPListener() {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        
        do {
            udpListener = try NWListener(using: parameters, on: 5060)
            
            udpListener?.newConnectionHandler = { [weak self] connection in
                self?.handleNewConnection(connection)
            }
            
            udpListener?.start(queue: DispatchQueue.global())
            print("🎧 SIP UDP listener started on port 5060")
            
        } catch {
            print("❌ Failed to start UDP listener: \(error)")
        }
    }
    
    private func handleNewConnection(_ connection: NWConnection) {
        connection.start(queue: DispatchQueue.global())
        
        func receiveData() {
            connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, context, isComplete, error in
                
                if let data = data, !data.isEmpty {
                    self?.processSIPPacket(data: data, connection: connection)
                }
                
                if !isComplete {
                    receiveData() // Continue receiving
                }
            }
        }
        
        receiveData()
    }
    
    private func processSIPPacket(data: Data, connection: NWConnection) {
        guard let remoteEndpoint = connection.endpoint,
              case .hostPort(let host, let port) = remoteEndpoint else {
            return
        }
        
        let connectionInfo = RemoteConnectionInfo(
            ipFamily: host.debugDescription.contains(":") ? 30 : 2, // IPv6 vs IPv4
            ipProto: 17, // UDP
            srcIP: "0.0.0.0", // Would need to extract from actual packet
            dstIP: host.debugDescription,
            srcPort: 5060,
            dstPort: UInt16(port.rawValue),
            timeSec: UInt32(Date().timeIntervalSince1970),
            timeUsec: 0,
            protoType: 1
        )
        
        let success = hepAgent.sendHEPBasic(rcInfo: connectionInfo, data: data)
        
        if success {
            print("📡 Captured SIP packet (\(data.count) bytes)")
        }
    }
    
    func stop() {
        udpListener?.cancel()
        hepAgent.disconnect()
        print("🛑 SIP monitor stopped")
    }
}

// Usage
let monitor = SIPMonitor(homerHost: "homer.company.com", port: "9060")
// Monitor will automatically capture and forward SIP packets

// Stop monitoring when done
// monitor.stop()
```

### 4. Batch Processing with Error Handling

```swift
func batchCapture() {
    let agent = HEPCaptureAgent(host: "10.0.0.100", port: "9060")
    
    let messages = [
        ("INVITE", "INVITE sip:alice@example.com SIP/2.0\r\n..."),
        ("200 OK", "SIP/2.0 200 OK\r\n..."),
        ("ACK", "ACK sip:alice@example.com SIP/2.0\r\n..."),
        ("BYE", "BYE sip:alice@example.com SIP/2.0\r\n...")
    ]
    
    var successCount = 0
    var failureCount = 0
    
    for (messageType, content) in messages {
        let connectionInfo = RemoteConnectionInfo(
            ipFamily: 2,
            ipProto: 17,
            srcIP: "192.168.1.10",
            dstIP: "192.168.1.20",
            srcPort: 5060,
            dstPort: 5060,
            timeSec: UInt32(Date().timeIntervalSince1970),
            timeUsec: 0,
            protoType: 1
        )
        
        guard let data = content.data(using: .utf8) else {
            print("❌ Failed to encode \(messageType)")
            failureCount += 1
            continue
        }
        
        if agent.sendHEPBasic(rcInfo: connectionInfo, data: data) {
            print("✅ \(messageType) captured successfully")
            successCount += 1
        } else {
            print("❌ Failed to capture \(messageType)")
            failureCount += 1
        }
        
        // Small delay between messages
        Thread.sleep(forTimeInterval: 0.1)
    }
    
    print("\n📊 Batch Results:")
    print("   Successful: \(successCount)")
    print("   Failed: \(failureCount)")
    print("   \(agent.getStatistics())")
}
```

## Configuration Options

### HEPCaptureAgent Initialization Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `host` | String | "10.0.0.1" | Homer server hostname or IP address |
| `port` | String | "9060" | Homer server port |
| `captureId` | UInt32 | 101 | Unique capture node identifier |
| `version` | Int | 3 | HEP protocol version (2 or 3) |
| `useSSL` | Bool | false | Enable SSL/TLS encryption |
| `compress` | Bool | false | Enable payload compression |
| `password` | String? | nil | Authentication password |

### RemoteConnectionInfo Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `ipFamily` | UInt8 | 2 for IPv4, 30 for IPv6 |
| `ipProto` | UInt8 | 6 for TCP, 17 for UDP |
| `srcIP` | String | Source IP address |
| `dstIP` | String | Destination IP address |
| `srcPort` | UInt16 | Source port number |
| `dstPort` | UInt16 | Destination port number |
| `timeSec` | UInt32 | Timestamp seconds since epoch |
| `timeUsec` | UInt32 | Timestamp microseconds |
| `protoType` | UInt8 | Protocol type (1=SIP, 5=RTCP, etc.) |

### Protocol Types

| Value | Protocol |
|-------|----------|
| 1 | SIP |
| 5 | RTCP |
| 8 | H323 |
| 9 | SDP |
| 10 | RTP |
| 34 | Megaco/H248 |
| 35 | M2UA |
| 36 | M3UA |
| 37 | IAX |
| 38 | H322 |
| 39 | Skinny |

## Error Handling

The library provides several ways to handle errors:

```swift
let agent = HEPCaptureAgent(host: "invalid-host", port: "9060")

// Check connection before sending
if agent.sendHEPBasic(rcInfo: connectionInfo, data: data) {
    print("Success!")
} else {
    print("Failed to send - check network connectivity")
    print(agent.getStatistics()) // Check for connection issues
}

// Monitor statistics for failures
let stats = agent.getStatistics()
print(stats) // Shows packet counts and any failures
```

## Performance Tips

1. **Reuse Agent Instances**: Create one agent per Homer server and reuse it
2. **Batch Operations**: Send multiple packets without recreating connections
3. **Use Compression**: Enable compression for large payloads to reduce bandwidth
4. **Monitor Statistics**: Check packet counts to ensure delivery
5. **Connection Pooling**: For high-volume scenarios, consider multiple agent instances

## Thread Safety

The HEP Swift library is thread-safe and can be used from multiple threads simultaneously:

```swift
let agent = HEPCaptureAgent(host: "homer.example.com", port: "9060")

// Safe to call from multiple threads
DispatchQueue.global().async {
    agent.sendHEPBasic(rcInfo: connectionInfo1, data: data1)
}

DispatchQueue.global().async {
    agent.sendHEPBasic(rcInfo: connectionInfo2, data: data2)
}
```

## License

This project is licensed under the MIT License

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Support

For issues and questions:
- Open an issue on GitHub
- Check the [Homer Project documentation](http://sipcapture.org)
- Review the original captagent C implementation

## Changelog

### v1.0.0
- Initial Swift implementation
- HEP v2 and v3 support
- IPv4/IPv6 support
- SSL/TLS encryption
- Payload compression
- Thread-safe operations
