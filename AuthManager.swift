//
//  AuthManager.swift
//  MiScale to Garmin
//

import Foundation
import Combine
import Security

protocol TokenProvider {
    var accessToken: String? { get }
}

final class AuthManager: ObservableObject, TokenProvider {

    static let shared = AuthManager()

    @Published private(set) var isAuthenticated: Bool = false
    @Published private(set) var username: String = ""

    private let keychainService = "com.yourapp.miscale"
    private let tokenAccount = "backend_token"
    private let userAccount = "backend_user"

    var accessToken: String? {
        loadKeychain(account: tokenAccount)
    }

    init() {
        if let token = loadKeychain(account: tokenAccount), !token.isEmpty {
            self.isAuthenticated = true
        } else {
            self.isAuthenticated = false
        }
        if let user = loadKeychain(account: userAccount) {
            self.username = user
        }
    }

    func login(username: String, password: String, completion: @escaping (Bool) -> Void) {
        BackendTransport.shared.authenticate(username: username, password: password) { result in
            switch result {
            case .success(let token):
                self.saveKeychain(value: token, account: self.tokenAccount)
                self.saveKeychain(value: username, account: self.userAccount)
                DispatchQueue.main.async {
                    self.username = username
                    self.isAuthenticated = true
                    completion(true)
                }
            case .failure:
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    func logout() {
        deleteKeychain(account: tokenAccount)
        deleteKeychain(account: userAccount)
        DispatchQueue.main.async {
            self.username = ""
            self.isAuthenticated = false
        }
    }

    // MARK: - Keychain

    private func saveKeychain(value: String, account: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var attrs = query
        attrs[kSecValueData as String] = data
        SecItemAdd(attrs as CFDictionary, nil)
    }

    private func loadKeychain(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func deleteKeychain(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
