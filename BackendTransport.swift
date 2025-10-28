//
//  BackendTransport.swift
//  MiScale to Garmin
//

import Foundation

enum BackendError: Error, CustomStringConvertible {
    case notConfigured
    case unauthorized
    case server(String)
    case network(Error)

    var description: String {
        switch self {
        case .notConfigured: return "Backend nie skonfigurowany"
        case .unauthorized: return "Brak autoryzacji"
        case .server(let s): return "Błąd serwera: \(s)"
        case .network(let e): return "Błąd sieci: \(e.localizedDescription)"
        }
    }
}

final class BackendTransport {

    static let shared = BackendTransport()

    // PODMIEN na URL z ngrok, np. "https://abcd-1234-ef56.ngrok-free.app"
    var baseURL: URL?

    private var authPath: String { "/api/login" }
    private var weightsPath: String { "/api/weights" }

    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 20
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    func authenticate(username: String, password: String, completion: @escaping (Result<String, BackendError>) -> Void) {
        guard let baseURL else { completion(.failure(.notConfigured)); return }
        let url = baseURL.appendingPathComponent(authPath)

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["username": username, "password": password]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        session.dataTask(with: req) { data, response, error in
            if let error { completion(.failure(.network(error))); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.server("Brak odpowiedzi"))); return
            }
            guard (200..<300).contains(http.statusCode), let data else {
                completion(.failure(http.statusCode == 401 ? .unauthorized : .server("HTTP \(http.statusCode)"))); return
            }
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let token = json["token"] as? String {
                completion(.success(token))
            } else {
                completion(.failure(.server("Niepoprawny format tokenu")))
            }
        }.resume()
    }

    func uploadWeight(token: String, weightKg: Double, date: Date, completion: @escaping (Result<Void, BackendError>) -> Void) {
        guard let baseURL else { completion(.failure(.notConfigured)); return }
        let url = baseURL.appendingPathComponent(weightsPath)

        struct Payload: Encodable {
            let weightKg: Double
            let date: String
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let payload = Payload(weightKg: weightKg, date: iso.string(from: date))
        req.httpBody = try? JSONEncoder().encode(payload)

        session.dataTask(with: req) { _, response, error in
            if let error { completion(.failure(.network(error))); return }
            guard let http = response as? HTTPURLResponse else {
                completion(.failure(.server("Brak odpowiedzi"))); return
            }
            guard (200..<300).contains(http.statusCode) else {
                completion(.failure(http.statusCode == 401 ? .unauthorized : .server("HTTP \(http.statusCode)"))); return
            }
            completion(.success(()))
        }.resume()
    }
}
