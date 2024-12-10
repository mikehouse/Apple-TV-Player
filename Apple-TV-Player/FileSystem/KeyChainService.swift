//
//  KeyChainService.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 07.12.2024.
//

import Foundation
import Security

final class KeyChainService {
    
    static let shared = KeyChainService()
    
    @discardableResult func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary) // Delete any existing item
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    @discardableResult func save(key: String, value: String) -> Bool {
        if let data = value.data(using: .utf8) {
            return save(key: key, data: data)
        }
        return false
    }
    
    @discardableResult func read(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess {
            return dataTypeRef as? Data
        }
        return nil
    }
    
    @discardableResult func read(key: String) -> String? {
        if let retrievedData:Data = read(key: key),
               let result = String(data: retrievedData, encoding: .utf8) {
                return result
            }
        return nil
    }
    
    @discardableResult func update(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let attributes: [String: Any] = [
            kSecValueData as String: data
        ]
        
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        return status == errSecSuccess
    }
    
    @discardableResult func update(key: String, value: String) -> Bool {
        if let data = value.data(using: .utf8) {
            return update(key: key, data: data)
        }
        return false
    }
    
    @discardableResult func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess
    }
}
