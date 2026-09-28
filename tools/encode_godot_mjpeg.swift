// Convert Godot's Movie Maker MJPEG AVI into a shareable H.264 MP4.
// Usage: swift tools/encode_godot_mjpeg.swift input.avi output.mp4 [fps]
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO

guard CommandLine.arguments.count == 3 || CommandLine.arguments.count == 4 else {
    fputs("usage: encode_godot_mjpeg.swift input.avi output.mp4 [fps]\n", stderr)
    exit(2)
}
let fps = Int32(CommandLine.arguments.count == 4 ? (Int(CommandLine.arguments[3]) ?? 12) : 12)
let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let bytes = [UInt8](try Data(contentsOf: inputURL))
var frames: [Data] = []
var cursor = 0
while cursor + 1 < bytes.count {
    if bytes[cursor] == 0xff && bytes[cursor + 1] == 0xd8 {
        let start = cursor
        cursor += 2
        while cursor + 1 < bytes.count && !(bytes[cursor] == 0xff && bytes[cursor + 1] == 0xd9) {
            cursor += 1
        }
        if cursor + 1 >= bytes.count { break }
        cursor += 2
        let frame = Data(bytes[start..<cursor])
        if CGImageSourceCreateWithData(frame as CFData, nil) != nil { frames.append(frame) }
    } else {
        cursor += 1
    }
}
guard let first = frames.first,
      let source = CGImageSourceCreateWithData(first as CFData, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fatalError("No decodable JPEG frames in AVI")
}
let width = image.width
let height = image.height
try? FileManager.default.removeItem(at: outputURL)
let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
let settings: [String: Any] = [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: width,
    AVVideoHeightKey: height,
    AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: 3_000_000]
]
let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
writerInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
    sourcePixelBufferAttributes: [
        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
        kCVPixelBufferWidthKey as String: width,
        kCVPixelBufferHeightKey as String: height,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
    ])
writer.add(writerInput)
guard writer.startWriting() else { fatalError("AVAssetWriter failed: \(String(describing: writer.error))") }
writer.startSession(atSourceTime: .zero)

for (index, jpeg) in frames.enumerated() {
    guard let src = CGImageSourceCreateWithData(jpeg as CFData, nil),
          let picture = CGImageSourceCreateImageAtIndex(src, 0, nil) else { continue }
    while !writerInput.isReadyForMoreMediaData { usleep(2_000) }
    var buffer: CVPixelBuffer?
    let attrs = [kCVPixelBufferCGImageCompatibilityKey: true,
                 kCVPixelBufferCGBitmapContextCompatibilityKey: true] as CFDictionary
    guard CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, attrs, &buffer) == kCVReturnSuccess,
          let pixel = buffer else { fatalError("Cannot allocate pixel buffer") }
    CVPixelBufferLockBaseAddress(pixel, [])
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmap = CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
    guard let context = CGContext(data: CVPixelBufferGetBaseAddress(pixel), width: width, height: height,
                                  bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixel),
                                  space: colorSpace, bitmapInfo: bitmap) else {
        fatalError("Cannot create image context")
    }
    context.draw(picture, in: CGRect(x: 0, y: 0, width: width, height: height))
    let time = CMTime(value: CMTimeValue(index), timescale: fps)
    guard adaptor.append(pixel, withPresentationTime: time) else {
        fatalError("Cannot append frame \(index): \(String(describing: writer.error))")
    }
    CVPixelBufferUnlockBaseAddress(pixel, [])
}
writerInput.markAsFinished()
let done = DispatchSemaphore(value: 0)
writer.finishWriting { done.signal() }
done.wait()
guard writer.status == .completed else { fatalError("Encoding failed: \(String(describing: writer.error))") }
print("MP4: \(frames.count) frames, \(width)x\(height), \(fps) fps")
