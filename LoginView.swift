//
//  LoginView.swift
//  MiScale to Garmin
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject var auth: AuthManager

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Konto")) {
                    TextField("Email / login", text: $username)
                        .textContentType(.username)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    SecureField("Hasło", text: $password)
                        .textContentType(.password)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                }
                Button {
                    login()
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Zaloguj")
                    }
                }
                .disabled(username.isEmpty || password.isEmpty || isLoading)
            }
            .navigationTitle("Logowanie")
        }
    }

    private func login() {
        errorMessage = nil
        isLoading = true
        auth.login(username: username, password: password) { success in
            isLoading = false
            if !success {
                errorMessage = "Błędny login lub hasło."
            }
        }
    }
}
