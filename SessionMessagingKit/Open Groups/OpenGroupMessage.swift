import PromiseKit
import Curve25519Kit
import SessionUtilitiesKit

@objc(SNOpenGroupMessage)
public final class OpenGroupMessage : NSObject {
    public let serverID: UInt64?
    public let senderPublicKey: String
    public let displayName: String
    public let profilePicture: ProfilePicture?
    public let body: String
    /// - Note: Expressed as milliseconds since 00:00:00 UTC on 1 January 1970.
    public let timestamp: UInt64
    public let type: String
    public let quote: Quote?
    public var attachments: [Attachment] = []
    public let signature: Signature?
    /// - Note: Used for sorting.
    public let serverTimestamp: UInt64
    
    @objc(serverID)
    public var objc_serverID: UInt64 { return serverID ?? 0 }
    
    // MARK: Settings
    private let signatureVersion: UInt64 = 1
    private let attachmentType = "net.app.core.oembed"
    
    // MARK: Types
    public struct ProfilePicture {
        public let profileKey: Data
        public let url: String
    }
    
    public struct Quote {
        public let quotedMessageTimestamp: UInt64
        public let quoteePublicKey: String
        public let quotedMessageBody: String
        public let quotedMessageServerID: UInt64?
    }
    
    public struct Attachment {
        public let kind: Kind
        public let server: String
        public let serverID: UInt64
        public let contentType: String
        public let size: UInt
        public let fileName: String
        public let flags: UInt
        public let width: UInt
        public let height: UInt
        public let caption: String?
        public let url: String
        /// Guaranteed to be non-`nil` if `kind` is `linkPreview`
        public let linkPreviewURL: String?
        /// Guaranteed to be non-`nil` if `kind` is `linkPreview`
        public let linkPreviewTitle: String?
        
        public enum Kind : String { case attachment, linkPreview = "preview" }
        
        public var dotNETType: String {
            if contentType.hasPrefix("image") {
                return "photo"
            } else if contentType.hasPrefix("video") {
                return "video"
            } else if contentType.hasPrefix("audio") {
                return "audio"
            } else {
                return "other"
            }
        }
    }
    
    public struct Signature {
        public let data: Data
        public let version: UInt64
    }
    
    // MARK: Initialization
    public init(serverID: UInt64?, senderPublicKey: String, displayName: String, profilePicture: ProfilePicture?, body: String,
            type: String, timestamp: UInt64, quote: Quote?, attachments: [Attachment], signature: Signature?, serverTimestamp: UInt64) {
        self.serverID = serverID
        self.senderPublicKey = senderPublicKey
        self.displayName = displayName
        self.profilePicture = profilePicture
        self.body = body
        self.type = type
        self.timestamp = timestamp
        self.quote = quote
        self.attachments = attachments
        self.signature = signature
        self.serverTimestamp = serverTimestamp
        super.init()
    }
    
    @objc public convenience init(senderPublicKey: String, displayName: String, body: String, type: String, timestamp: UInt64,
            quotedMessageTimestamp: UInt64, quoteePublicKey: String?, quotedMessageBody: String, quotedMessageServerID: UInt64,
            signatureData: Data?, signatureVersion: UInt64, serverTimestamp: UInt64) {
        let quote: Quote?
        if quotedMessageTimestamp != 0, let quoteeHexEncodedPublicKey = quoteePublicKey {
            let quotedMessageServerID = (quotedMessageServerID != 0) ? quotedMessageServerID : nil
            quote = Quote(quotedMessageTimestamp: quotedMessageTimestamp, quoteePublicKey: quoteeHexEncodedPublicKey, quotedMessageBody: quotedMessageBody, quotedMessageServerID: quotedMessageServerID)
        } else {
            quote = nil
        }
        let signature: Signature?
        if let signatureData = signatureData, signatureVersion != 0 {
            signature = Signature(data: signatureData, version: signatureVersion)
        } else {
            signature = nil
        }
        self.init(serverID: nil, senderPublicKey: senderPublicKey, displayName: displayName, profilePicture: nil, body: body, type: type, timestamp: timestamp, quote: quote, attachments: [], signature: signature, serverTimestamp: serverTimestamp)
    }
    
    // MARK: Crypto
    internal func sign(with privateKey: Data) -> OpenGroupMessage? {
        guard let data = getValidationData(for: signatureVersion) else {
            SNLog("Failed to sign open group message.")
            return nil
        }
        let userKeyPair = SNMessagingKitConfiguration.shared.storage.getUserKeyPair()!
        guard let signatureData = try? Ed25519.sign(data, with: userKeyPair) else {
            SNLog("Failed to sign open group message.")
            return nil
        }
        let signature = Signature(data: signatureData, version: signatureVersion)
        return OpenGroupMessage(serverID: serverID, senderPublicKey: senderPublicKey, displayName: displayName, profilePicture: profilePicture, body: body, type: type, timestamp: timestamp, quote: quote, attachments: attachments, signature: signature, serverTimestamp: serverTimestamp)
    }
    
    internal func hasValidSignature() -> Bool {
        guard let signature = signature else { return false }
        guard let data = getValidationData(for: signature.version) else { return false }
        let publicKey = Data(hex: self.senderPublicKey.removing05PrefixIfNeeded())
        return (try? Ed25519.verifySignature(signature.data, publicKey: publicKey, data: data)) ?? false
    }
    
    // MARK: JSON
    internal func toJSON() -> JSON {
        var value: JSON = [ "timestamp" : timestamp ]
        if let quote = quote {
            let quoteAsJSON: JSON = [ "id" : quote.quotedMessageTimestamp, "author" : quote.quoteePublicKey, "text" : quote.quotedMessageBody ]
            value["quote"] = quoteAsJSON
        }
        if let signature = signature {
            value["sig"] = signature.data.toHexString()
            value["sigver"] = signature.version
        }
        if let profilePicture = profilePicture {
            value["avatar"] = profilePicture;
        }
        let annotation: JSON = [ "type" : type, "value" : value ]
        let attachmentAnnotations: [JSON] = attachments.map { attachment in
            var attachmentValue: JSON = [
                // Fields required by the .NET API
                "version" : 1, "type" : attachment.dotNETType,
                // Custom fields
                "lokiType" : attachment.kind.rawValue, "server" : attachment.server, "id" : attachment.serverID, "contentType" : attachment.contentType, "size" : attachment.size, "fileName" : attachment.fileName, "width" : attachment.width, "height" : attachment.height, "url" : attachment.url
            ]
            if let caption = attachment.caption {
                attachmentValue["caption"] = caption
            }
            if let linkPreviewURL = attachment.linkPreviewURL {
                attachmentValue["linkPreviewUrl"] = linkPreviewURL
            }
            if let linkPreviewTitle = attachment.linkPreviewTitle {
                attachmentValue["linkPreviewTitle"] = linkPreviewTitle
            }
            return [ "type" : attachmentType, "value" : attachmentValue ]
        }
        var result: JSON = [ "text" : body, "annotations": [ annotation ] + attachmentAnnotations ]
        if let quotedMessageServerID = quote?.quotedMessageServerID {
            result["reply_to"] = quotedMessageServerID
        }
        return result
    }
    
    // MARK: Convenience
    @objc public func addAttachment(kind: String, server: String, serverID: UInt64, contentType: String, size: UInt,
            fileName: String, flags: UInt, width: UInt, height: UInt, caption: String?, url: String, linkPreviewURL: String?, linkPreviewTitle: String?) {
        guard let kind = Attachment.Kind(rawValue: kind) else { preconditionFailure() }
        let attachment = Attachment(kind: kind, server: server, serverID: serverID, contentType: contentType, size: size, fileName: fileName, flags: flags, width: width, height: height, caption: caption, url: url, linkPreviewURL: linkPreviewURL, linkPreviewTitle: linkPreviewTitle)
        attachments.append(attachment)
    }
    
    private func getValidationData(for signatureVersion: UInt64) -> Data? {
        var string = "\(body.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))\(timestamp)"
        if let quote = quote {
            string += "\(quote.quotedMessageTimestamp)\(quote.quoteePublicKey)\(quote.quotedMessageBody.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines))"
            if let quotedMessageServerID = quote.quotedMessageServerID {
                string += "\(quotedMessageServerID)"
            }
        }
        string += attachments.sorted { $0.serverID < $1.serverID }.map { "\($0.serverID)" }.joined(separator: "")
        string += "\(signatureVersion)"
        return string.data(using: String.Encoding.utf8)
    }
}
