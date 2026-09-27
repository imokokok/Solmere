import Foundation
import AVFoundation
import ImageIO
import CoreGraphics
import CoreVideo

guard (4...6).contains(CommandLine.arguments.count) else {
    fputs("Usage: swift tools/encode_godot_movie.swift <frames-directory> <output.mp4> <fps> [bitrate] [trim-start-frames]\n", stderr)
    exit(2)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let output = URL(fileURLWithPath: CommandLine.arguments[2])
let fps = Int(CommandLine.arguments[3]) ?? 24
let bitrate = CommandLine.arguments.count >= 5 ? (Int(CommandLine.arguments[4]) ?? 0) : 5_000_000
guard fps > 0, bitrate > 0 else { fatalError("FPS and bitrate must be positive") }
let trimFrames = CommandLine.arguments.count == 6 ? (Int(CommandLine.arguments[5]) ?? -1) : 0
guard trimFrames >= 0 else { fatalError("Invalid frame trim") }
let allFiles = try FileManager.default.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
    .filter { $0.lastPathComponent.hasPrefix("frame_") && $0.pathExtension == "jpg" }
    .sorted { $0.lastPathComponent < $1.lastPathComponent }
let files = Array(allFiles.dropFirst(trimFrames))
guard !files.isEmpty, let firstSource = CGImageSourceCreateWithURL(files[0] as CFURL, nil),
      let first = CGImageSourceCreateImageAtIndex(firstSource, 0, nil) else {
    fputs("No readable JPEG frames\n", stderr)
    exit(3)
}

let width = first.width
let height = first.height
let outputHeight = height + height % 2
try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: outputHeight,
    AVVideoCompressionPropertiesKey: [
        AVVideoAverageBitRateKey: bitrate,
        AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
    ]
]
let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
input.expectsMediaDataInRealTime = false
guard writer.canAdd(input) else { fatalError("Cannot add video input") }
writer.add(input)
let attributes: [String: Any] = [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
    kCVPixelBufferWidthKey as String: width,
    kCVPixelBufferHeightKey as String: outputHeight,
    kCVPixelBufferCGImageCompatibilityKey as String: true,
    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
]
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
guard writer.startWriting() else { fatalError("Cannot start MP4: \(writer.error?.localizedDescription ?? "unknown")") }
writer.startSession(atSourceTime: .zero)

for (index, file) in files.enumerated() {
    while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.005) }
    try autoreleasepool {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              image.width == width, image.height == height else {
            throw NSError(domain: "KitchenVideo", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unreadable frame: \(file.path)"])
        }
        var buffer: CVPixelBuffer?
        guard let pool = adaptor.pixelBufferPool,
              CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buffer) == kCVReturnSuccess,
              let pixelBuffer = buffer else {
            throw NSError(domain: "KitchenVideo", code: 5, userInfo: [NSLocalizedDescriptionKey: "Could not allocate pixel buffer"])
        }
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer),
              let context = CGContext(data: base, width: width, height: outputHeight,
                                      bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue) else {
            throw NSError(domain: "KitchenVideo", code: 6, userInfo: [NSLocalizedDescriptionKey: "Could not draw frame"])
        }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let time = CMTime(value: Int64(index), timescale: Int32(fps))
        guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
            throw NSError(domain: "KitchenVideo", code: 7, userInfo: [NSLocalizedDescriptionKey: "Could not append frame \(index): \(writer.error?.localizedDescription ?? "unknown")"])
        }
    }
    if index % 240 == 0 { print("Encoded \(index)/\(files.count) frames") }
}
input.markAsFinished()
let finished = DispatchSemaphore(value: 0)
writer.finishWriting { finished.signal() }
finished.wait()
guard writer.status == .completed else { fatalError("MP4 export failed: \(writer.error?.localizedDescription ?? "unknown")") }
print("Trimmed \(trimFrames) native startup frames")
print("Wrote \(output.path): \(files.count) frames, \(width)x\(outputHeight), \(fps) fps")
