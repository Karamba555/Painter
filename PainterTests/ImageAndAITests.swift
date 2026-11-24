import XCTest
import UIKit
@testable import Painter

final class ImageAndAITests: XCTestCase {
    func testPhotoNormalizationAndTransparentPaper() throws {
        let input = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 150)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 300, height: 150))
            UIColor.black.setFill(); context.fill(CGRect(x: 10, y: 10, width: 20, height: 20))
        }
        let normalized = ImageFiles.normalized(input, maxDimension: 100)
        XCTAssertEqual(normalized.size.width, 100)
        XCTAssertEqual(normalized.size.height, 50)
        let transparent = try XCTUnwrap(ImageFiles.transparentOutline(input).cgImage)
        func alpha(x: CGFloat, y: CGFloat) throws -> UInt8 {
            var pixel = [UInt8](repeating: 0, count: 4)
            let cropped = try XCTUnwrap(transparent.cropping(to: CGRect(x: x * input.scale, y: y * input.scale, width: 1, height: 1)))
            try pixel.withUnsafeMutableBytes { bytes in
                let context = try XCTUnwrap(CGContext(data: bytes.baseAddress, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
                context.draw(cropped, in: CGRect(x: 0, y: 0, width: 1, height: 1))
            }
            return pixel[3]
        }
        XCTAssertLessThan(try alpha(x: 100, y: 70), 5, "White paper must be transparent over the camera")
        XCTAssertGreaterThan(try alpha(x: 15, y: 15), 240, "The pencil contour must stay visible")
    }
    func testSavedImageCanBeExportedAsPDF() throws {
        let input = UIGraphicsImageRenderer(size: CGSize(width: 20, height: 20)).image { context in UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 20, height: 20)) }
        let filename = try ImageFiles.save(input)
        defer { try? ImageFiles.remove(filename) }
        let drawing = Drawing(id: UUID().uuidString, title: "Test", asset: "", topic: .flowers, difficulty: .easy, minutes: 5, isFree: true, localImage: filename)
        let pdf = try ImageFiles.pdf(for: drawing)
        defer { try? FileManager.default.removeItem(at: pdf) }
        XCTAssertEqual(String(data: try Data(contentsOf: pdf).prefix(4), encoding: .utf8), "%PDF")
    }
    func testAIClientUsesConfiguredServerAndPassesQuota() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); AIURLProtocol.handler = nil }
        AIURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.absoluteString, "https://test.example.com/v1/generations")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer signed-transaction")
            return (200, Data(#"{"imageBase64":"aW1hZ2U=","remaining":9,"limit":10}"#.utf8))
        }
        let response = try await AIClient(baseURL: URL(string: "https://test.example.com")!, session: session).generate(prompt: "A kitten", detailed: false, requestID: UUID(), signedTransaction: "signed-transaction")
        XCTAssertEqual(response.remaining, 9); XCTAssertEqual(response.limit, 10)
    }
    func testAIClientShowsServerQuotaError() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [AIURLProtocol.self]
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel(); AIURLProtocol.handler = nil }
        AIURLProtocol.handler = { _ in (429, Data(#"{"error":{"code":"quota_exceeded","message":"Your allowance is used."}}"#.utf8)) }
        do {
            _ = try await AIClient(baseURL: URL(string: "https://test.example.com")!, session: session).generate(prompt: "A kitten", detailed: false, requestID: UUID(), signedTransaction: "signed-transaction")
            XCTFail("Expected quota error")
        } catch { XCTAssertEqual(error.localizedDescription, "Your allowance is used.") }
    }
}

private final class AIURLProtocol: URLProtocol {
    static var handler: ((URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "test.example.com" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (status, data) = try handler(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
