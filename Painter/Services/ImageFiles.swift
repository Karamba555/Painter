import UIKit
import CoreImage.CIFilterBuiltins

enum ImageFiles {
    static var directory: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Projects", isDirectory: true) }
    static func load(_ filename: String) -> UIImage? { UIImage(contentsOfFile: directory.appendingPathComponent(filename).path) }
    static func save(_ image: UIImage) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        guard let data = image.jpegData(compressionQuality: 0.9) else { throw ImageError.invalidImage }
        try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        return name
    }
    static func normalized(_ image: UIImage, maxDimension: CGFloat = 1600) -> UIImage {
        let scale = min(1, maxDimension / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
    }
    static func outline(_ image: UIImage, detailed: Bool) -> UIImage {
        let resized = normalized(image, maxDimension: 1200)
        guard let input = CIImage(image: resized) else { return resized }
        let edges = CIFilter.lineOverlay()
        edges.inputImage = input
        edges.nrNoiseLevel = detailed ? 0.02 : 0.08
        edges.nrSharpness = 0.7
        edges.edgeIntensity = detailed ? 1.2 : 0.8
        edges.threshold = detailed ? 0.08 : 0.16
        edges.contrast = 50
        guard let result = edges.outputImage, let cgImage = CIContext().createCGImage(result, from: input.extent) else { return resized }
        return UIImage(cgImage: cgImage)
    }
    static func source(for drawing: Drawing) -> UIImage? {
        if let path = drawing.localImage { return load(path) }
        return UIImage(named: drawing.asset)
    }
    /// Converts white paper to transparency so the camera and the hand remain visible.
    static func transparentOutline(_ image: UIImage) -> UIImage {
        guard let input = CIImage(image: image) else { return image }
        let invert = CIFilter.colorInvert(); invert.inputImage = input
        let blend = CIFilter.blendWithMask()
        blend.inputImage = CIImage(color: CIColor(red: 0.77, green: 0.31, blue: 0.22)).cropped(to: input.extent)
        blend.backgroundImage = CIImage(color: .clear).cropped(to: input.extent)
        blend.maskImage = invert.outputImage
        guard let output = blend.outputImage, let cgImage = CIContext().createCGImage(output, from: input.extent) else { return image }
        return UIImage(cgImage: cgImage)
    }
    static func exportImage(_ filename: String) -> URL? {
        let url = directory.appendingPathComponent(filename)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
    static func pdf(for drawing: Drawing) throws -> URL {
        guard let source = source(for: drawing) else { throw ImageError.invalidImage }
        let image = drawing.isOutline ? source : outline(source, detailed: true)
        let bounds = CGRect(x: 0, y: 0, width: 595, height: 842)
        let data = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            let scale = min(515 / image.size.width, 762 / image.size.height)
            let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            image.draw(in: CGRect(x: (595 - size.width) / 2, y: (842 - size.height) / 2, width: size.width, height: size.height))
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Trace-Studio-\(drawing.id).pdf")
        try data.write(to: url, options: .atomic)
        return url
    }
    enum ImageError: LocalizedError { case invalidImage; var errorDescription: String? { "This image could not be opened. Please choose another photo." } }
}
