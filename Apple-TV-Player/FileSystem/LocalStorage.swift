//
//  LocalStorage.swift
//  Apple-TV-Player
//
//  Created by Mikhail Demidov on 22.11.2020.
//

import Foundation

private let lock = NSLock()

final class LocalStorage {
    private let storage: UserDefaults

    init(storage: UserDefaults = .app) {
        self.storage = storage
    }

    func remove(_ domain: Domain) {
        lock.lock()
        defer {lock.unlock()}
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
    
    func add(value: AnyHashable, for key: String, domain: Domain) {
        add(value: value, for: key, to: domain)
    }
    
    func add(value: AnyHashable, for key: CommonKeys, domain: Domain) {
        add(value: value, for: key.rawValue, to: domain)
    }
    
    func add(data value: Data, for key: CommonKeys, domain: Domain) {
        add(value: value, for: key.rawValue, to: domain)
    }

    func remove(for key: URL, domain: Domain) {
        remove(for: key.absoluteString, domain: domain)
    }
    
    func remove(for key: String, domain: Domain) {
        add(value: Optional<Any>.none, for: key, to: domain)
    }
    
    func remove(for key: CommonKeys, domain: Domain) {
        add(value: Optional<Any>.none, for: key.rawValue, to: domain)
    }
    
    func getData(_ key: URL, domain: Domain) -> Data? {
        getData(key.absoluteString, domain: domain)
    }
    
    func getData(_ key: String, domain: Domain) -> Data? {
        container(for: domain)[key]
    }
    
    func getValue(_ key: CommonKeys, domain: Domain) -> AnyHashable? {
        container(for: domain)[key.rawValue]
    }
    
    func getBool(_ key: CommonKeys, domain: Domain) -> Bool {
        (getValue(key, domain: domain) as? Bool) ?? false
    }

    func getData(_ key: CommonKeys, domain: Domain) -> Data? {
        container(for: domain)[key.rawValue]
    }

    func getValue(_ key: String, domain: Domain) -> AnyHashable? {
        container(for: domain)[key]
    }

    private func container<K: Hashable, V>(for domain: Domain) -> [K:V] {
        guard let rawValue = storage.value(forKey: domain.rawValue) else {
            return [:]
        }
        return (rawValue as? [K:V]) ?? [:]
    }
    
    private func add<K: Hashable, V>(value: V?, for key: K, to domain: Domain) {
        if case .list = domain {
            assertionFailure("for `list` domain use #addArray(_:) method.")
            return
        }
        lock.lock()
        defer {lock.unlock()}
        var dict: [K:V] = container(for: domain)
        if value == nil {
            dict.removeValue(forKey: key)
        } else {
            dict[key] = value
        }
        storage.set(dict, forKey: domain.rawValue)
    }
    
    @discardableResult
    private func addArray<V: Equatable>(value: V?, to domain: Domain) -> Bool {
        guard case .list = domain else {
            assertionFailure("only `list` domain available else use #add(_:) method.")
            return false
        }
        lock.lock()
        defer {lock.unlock()}
        switch domain {
        case .list(let key):
            switch key {
            case .provider(let key):
                if let value = value {
                    var dict: [AnyHashable:[V]] = container(for: domain)
                    if var old = dict[key] {
                        let before = old.count
                        old.removeAll(where: { $0 == value })
                        dict[key] = old + [value]
                        storage.set(dict, forKey: domain.rawValue)
                        return before == old.count
                    } else {
                        dict[key] = [value]
                        storage.set(dict, forKey: domain.rawValue)
                        return true
                    }
                }
                return false
            }
        default:
            fatalError("only `list` domain available else use #add(_:) method.")
        }
    }
    
    @discardableResult
    private func removeArray<V: Equatable>(value: V, to domain: Domain) -> Bool {
        lock.lock()
        defer {lock.unlock()}
        switch domain {
        case .list(let key):
            switch key {
            case .provider(let key):
                var dict: [AnyHashable:[V]] = container(for: domain)
                if var old = dict[key] {
                    let before = old.count
                    old.removeAll(where: { $0 == value })
                    if old.count != before {
                        dict[key] = old
                        storage.set(dict, forKey: domain.rawValue)
                        return true
                    }
                }
                return false
            }
        default:
            fatalError("only `list` domain available else use #add(_:) method.")
        }
    }
    
    private func array<V: Equatable>(value: V.Type, to domain: Domain) -> [V] {
        switch domain {
        case .list(let key):
            switch key {
            case .provider(let key):
                let dict: [AnyHashable:[V]] = container(for: domain)
                return dict[key] ?? []
            }
        default:
            fatalError("only `list` domain available else use #add(_:) method.")
        }
    }
}

extension LocalStorage {
    @discardableResult
    func addArray(value: AnyHashable, domain list: Domain) -> Bool {
        addArray(value: value, to: list)
    }
    @discardableResult
    func removeArray(value: AnyHashable, domain list: Domain) -> Bool {
        removeArray(value: value, to: list)
    }
    func array(domain list: Domain) -> [AnyHashable] {
        array(value: AnyHashable.self, to: list)
    }
}

extension LocalStorage {
    enum Domain: Equatable {
        case playlist
        case pin
        case playlistURL
        case common
        case list(ListKeys)
    
        var rawValue: String {
            switch self {
            case .list(let k):
                return "list_\(k.rawValue)"
            default:
                return "\(self)"
            }
        }
    
        static func ==(lhs: Domain, rhs: Domain) -> Bool {
            lhs.rawValue == rhs.rawValue
        }
    }
    
    enum CommonKeys: String {
        case current
        case symmetricKey
        case player
        case debugMenu
    }
    
    enum ListKeys {
        case provider(AnyHashable)
    
        var rawValue: String {
            switch self {
            case .provider(let p):
                return "\(p.base)"
            }
        }
    }

    enum Player: String, Identifiable, CaseIterable {
        var id: String { rawValue }

        case `default`
        case native
        case vlc

        var title: String {
            switch self {
            case .default:
                return "Default"
            case .native:
                return "Native (Apple TVOS)"
            case .vlc:
                return "VLC"
            }
        }
    }
}

extension LocalStorage {

    func set(player: Player) {
        add(value: player.rawValue, for: .player, domain: .common)
    }

    func getPlayer() -> Player? {
        getValue(.player, domain: .common)
            .flatMap({ $0 as? String })
            .flatMap(Player.init(rawValue:))
    }
}
