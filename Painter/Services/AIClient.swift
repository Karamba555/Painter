import Foundation

enum AIConfiguration {
    static var baseURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TraceAPIBaseURL") as? String,
              let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host != nil else { return nil }
        return url
    }
}

struct AIClient {
    struct Request: Encodable { let requestId: String; let prompt: String; let detail: String }
    struct Response: Decodable { let imageBase64: String; let remaining: Int; let limit: Int }
    struct ErrorResponse: Decodable { struct Detail: Decodable { let code: String; let message: String }; let error: Detail }
    struct ServiceError: LocalizedError { let message: String; var errorDescription: String? { message } }
    let baseURL: URL
    var session: URLSession = .shared

    func generate(prompt: String, detailed: Bool, requestID: UUID, signedTransaction: String) async throws -> Response {
        var request = URLRequest(url: baseURL.appendingPathComponent("v1/generations"))
        request.httpMethod = "POST"; request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer " + signedTransaction, forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Request(requestId: requestID.uuidString, prompt: prompt, detail: detailed ? "detailed" : "simple"))
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw ServiceError(message: "The image service could not be reached.") }
        guard http.statusCode == 200 else {
            let error = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            throw ServiceError(message: error?.error.message ?? "The drawing could not be created. Please try again.")
        }
        guard data.count <= 13_000_000 else { throw ServiceError(message: "The generated image is too large. Please try again.") }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}
