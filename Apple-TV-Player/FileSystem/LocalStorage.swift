//
//  LocalStorage.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 22.11.2020.
//

import Foundation

final class LocalStorage {
    private let storage = UserDefaults.standard
    
    func remove(_ domain: Domain) {
        storage.set(nil, forKey: domain.rawValue)
    }
    
    func domainKeys(_ domain: Domain) -> [String] {
        let dict: [String:Any] = container(for: domain)
        return Array(dict.keys)
    }
    
    func domainKeysURLs(_ domain: Domain) -> [URL] {
        domainKeys(domain).compactMap(URL.init(string:))
    }
    
    private func domainKeysRaw<Key: Hashable>(_ domain: Domain) -> [Key] {
        let dict: [Key:Any] = container(for: domain)
        return Array(dict.keys)
    }
    
    func add(data: Data, for key: URL, domain: Domain) {
        add(data: data, for: key.absoluteString, domain: domain)
    }
    
    func add(data: Data, for key: String, domain: Domain) {
        add(value: data, for: key, to: domain)
    }
    
    func remove(for key: URL, domain: Domain) {
        remove(for: key.absoluteString, domain: domain)
    }
    
    func remove(for key: String, domain: Domain) {
        add(value: Optional<Never>.none, for: key, to: domain)
    }
    
    func getData(_ key: URL, domain: Domain) -> Data? {
        getData(key.absoluteString, domain: domain)
    }
    
    func getData(_ key: String, domain: Domain) -> Data? {
        container(for: .playlist)[key]
    }
    
    private func container<K: Hashable, V>(for domain: Domain) -> [K:V] {
        (storage.value(forKey: domain.rawValue) as? [K:V]) ?? [:]
    }
    
    private func add<K: Hashable, V>(value: V?, for key: K, to domain: Domain) {
        var dict: [K:V] = container(for: domain)
        if value == nil {
            dict.removeValue(forKey: key)
        } else {
            dict[key] = value
        }
        storage.set(dict, forKey: domain.rawValue)
    }
}

extension LocalStorage {
    enum Domain: String {
        case playlist
    }
}
