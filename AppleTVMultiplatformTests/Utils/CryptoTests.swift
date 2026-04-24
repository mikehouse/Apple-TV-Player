import CommonCrypto
import FactoryTesting
import Foundation
import Testing
@testable import Bro_Player

@Suite(.container)
struct CryptoTests {

    @Test func generates256BitSalt() {
        let salt = Crypto.generateSalt()

        #expect(salt.count == kCCKeySizeAES256)
    }

    @Test func encryptsAndDecryptsStringInput() async throws {
        let crypto = Crypto()
        let salt = Crypto.generateSalt()
        let encrypted = try crypto.encrypt(Self.fixtureText, pin: Self.pin, salt: salt)
        let restored: String = try crypto.decrypt(encrypted, pin: Self.pin, salt: salt)

        #expect(!encrypted.isEmpty)
        #expect(restored == Self.fixtureText)
    }

    @Test func encryptsAndDecryptsDataInput() async throws {
        let crypto = Crypto()
        let salt = Crypto.generateSalt()
        let encrypted = try crypto.encrypt(Self.fixtureData, pin: Self.pin, salt: salt)
        let restored: Data = try crypto.decrypt(encrypted, pin: Self.pin, salt: salt)

        #expect(!encrypted.isEmpty)
        #expect(restored == Self.fixtureData)
    }

    @Test func producesCiphertextDifferentFromPlaintext() async throws {
        let crypto = Crypto()
        let salt = Crypto.generateSalt()
        let encrypted = try crypto.encrypt(Self.fixtureText, pin: Self.pin, salt: salt)

        #expect(encrypted != Self.fixtureData)
    }
}

private extension CryptoTests {
    static let pin = "1234"

    static let fixtureText = """
    "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.
    Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. 
    Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. 
    Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
    """

    static let fixtureData = Data(fixtureText.utf8)
}
