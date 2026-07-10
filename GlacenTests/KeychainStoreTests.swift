// GlacenTests/KeychainStoreTests.swift
import Testing
@testable import Glacen
import Foundation

struct KeychainStoreTests {
    @Test func setAndRetrieveData() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        let payload = Data("hello".utf8)
        try store.set(payload, forKey: "token")
        let fetched = try store.data(forKey: "token")
        #expect(fetched == payload)
        try store.removeValue(forKey: "token")
    }

    @Test func missingKeyReturnsNil() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        let fetched = try store.data(forKey: "missing")
        #expect(fetched == nil)
    }

    @Test func removeValueDeletesData() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        try store.set(Data("x".utf8), forKey: "token")
        try store.removeValue(forKey: "token")
        let fetched = try store.data(forKey: "token")
        #expect(fetched == nil)
    }

    @Test func setOverwritesExistingValue() throws {
        let store = KeychainStore(service: "com.kounex.glacen.tests.\(UUID().uuidString)")
        try store.set(Data("first".utf8), forKey: "token")
        try store.set(Data("second".utf8), forKey: "token")
        let fetched = try store.data(forKey: "token")
        #expect(fetched == Data("second".utf8))
        try store.removeValue(forKey: "token")
    }
}
