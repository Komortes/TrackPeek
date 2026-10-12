import CryptoKit
import Foundation

@main
enum VerifyUpdateTests {
    static func main() throws {
        let key = Curve25519.Signing.PrivateKey()
        let archive = Data("test update archive".utf8)
        let signature = try key.signature(for: archive)
        let encodedSignature = signature.base64EncodedString()
        let publicKey = key.publicKey.rawRepresentation.base64EncodedString()
        try require(verifyUpdateSignature(archive, signature: encodedSignature, publicKey: publicKey), "valid signature")
        try require(!verifyUpdateSignature(Data("changed archive".utf8), signature: encodedSignature, publicKey: publicKey), "modified archive")
        let otherKey = Curve25519.Signing.PrivateKey().publicKey.rawRepresentation.base64EncodedString()
        try require(!verifyUpdateSignature(archive, signature: encodedSignature, publicKey: otherKey), "wrong public key")
        var changedSignature = signature
        changedSignature[0] ^= 1
        try require(!verifyUpdateSignature(archive, signature: changedSignature.base64EncodedString(), publicKey: publicKey), "modified signature")
        try requireInvalid { try verifyUpdateSignature(archive, signature: "invalid!", publicKey: publicKey) }
        try requireInvalid { try verifyUpdateSignature(archive, signature: Data([1]).base64EncodedString(), publicKey: publicKey) }
        try requireInvalid { try verifyUpdateSignature(archive, signature: encodedSignature, publicKey: "invalid!") }
        try requireInvalid { try verifyUpdateSignature(archive, signature: encodedSignature, publicKey: Data([1]).base64EncodedString()) }
        print("8 public-key update signature checks passed.")
    }

    static func require(_ condition: @autoclosure () throws -> Bool, _ scenario: String) throws {
        guard try condition() else { throw Failure.scenario(scenario) }
    }

    static func requireInvalid(_ operation: () throws -> Bool) throws {
        do { _ = try operation() } catch { return }
        throw Failure.scenario("invalid input was accepted")
    }

    enum Failure: Error { case scenario(String) }
}
