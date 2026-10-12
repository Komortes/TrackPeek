import CryptoKit
import Foundation

func verifyUpdateSignature(_ archive: Data, signature: String, publicKey: String) throws -> Bool {
    guard let signatureData = Data(base64Encoded: signature), signatureData.count == 64,
          let publicKeyData = Data(base64Encoded: publicKey), publicKeyData.count == 32 else {
        throw CocoaError(.fileReadCorruptFile)
    }
    let key = try Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
    return key.isValidSignature(signatureData, for: archive)
}

#if !SIGNATURE_TESTS
@main
enum VerifyUpdateCommand {
    static func main() {
        do {
            guard CommandLine.arguments.count == 4 else {
                throw CocoaError(.fileReadInvalidFileName)
            }
            let plistData = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1]))
            let plist = try PropertyListSerialization.propertyList(from: plistData, format: nil)
            guard let publicKey = (plist as? [String: Any])?["SUPublicEDKey"] as? String else {
                throw CocoaError(.fileReadCorruptFile)
            }
            let archive = try Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2]), options: .mappedIfSafe)
            guard try verifyUpdateSignature(archive, signature: CommandLine.arguments[3], publicKey: publicKey) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            print("Update signature verified against the app's public key.")
        } catch {
            FileHandle.standardError.write(Data("Update signature verification failed: \(error.localizedDescription)\n".utf8))
            exit(1)
        }
    }
}
#endif
