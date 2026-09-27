// Full native decode plus chapter samples; no claim of human audio audition.
import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
guard CommandLine.arguments.count == 3 else {
    fputs("Usage: verify_player_tutorial.swift <video.mp4> <evidence-directory>\n", stderr)
    exit(2)
}
let url=URL(fileURLWithPath:CommandLine.arguments[1])
let output=URL(fileURLWithPath:CommandLine.arguments[2],isDirectory:true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let asset=AVURLAsset(url:url)
guard let video=asset.tracks(withMediaType:.video).first, let audio=asset.tracks(withMediaType:.audio).first else { fatalError("Missing video/audio") }
let duration=asset.duration.seconds
print("Duration: \(duration)s; size: \(video.naturalSize); fps: \(video.nominalFrameRate); audio duration: \(audio.timeRange.duration.seconds)")
guard duration>=300 && duration<=365 else { fatalError("Outside requested 5–6 minutes") }
guard abs(audio.timeRange.duration.seconds-duration)<0.15 else { fatalError("Audio/video duration mismatch") }
let generator=AVAssetImageGenerator(asset:asset)
generator.appliesPreferredTrackTransform=true
generator.requestedTimeToleranceBefore = .zero
generator.requestedTimeToleranceAfter = .zero
for time in [3.0,22,47,76,107,139,162,188,216,247,276,301,duration-7] {
 if time>=duration { continue }
 let cg=try generator.copyCGImage(at:CMTime(seconds:time,preferredTimescale:600),actualTime:nil)
 let file=output.appendingPathComponent("encoded-\(Int(time))s.png")
 let destination=CGImageDestinationCreateWithURL(file as CFURL,UTType.png.identifier as CFString,1,nil)!
 CGImageDestinationAddImage(destination,cg,nil)
 guard CGImageDestinationFinalize(destination) else { fatalError("Screenshot export failed") }
}
let reader=try AVAssetReader(asset:asset)
let decoded=AVAssetReaderTrackOutput(track:video,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
reader.add(decoded); guard reader.startReading() else { fatalError("Cannot decode video") }
var count=0
while let sample=decoded.copyNextSampleBuffer() {
 guard CMSampleBufferGetImageBuffer(sample) != nil else { fatalError("Missing decoded image") }
 count+=1
}
guard reader.status == .completed else { fatalError("Decode failed") }
let expected=Int((duration*Double(video.nominalFrameRate)).rounded())
guard abs(count-expected)<=1 else { fatalError("Frame count mismatch \(count)/\(expected)") }
print("PASS: full H.264 decode, \(count) frames; audio track present and synchronized")

let audioReader = try AVAssetReader(asset: asset)
let pcm = AVAssetReaderTrackOutput(track: audio, outputSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false, AVLinearPCMIsNonInterleaved: false])
audioReader.add(pcm)
guard audioReader.startReading() else { fatalError("Cannot decode audio") }
var audioSamples = 0
var peak = 0
var squared = 0.0
var clipped = 0
while let sample = pcm.copyNextSampleBuffer() {
    guard let block = CMSampleBufferGetDataBuffer(sample) else { fatalError("Missing audio data") }
    let length = CMBlockBufferGetDataLength(block)
    var bytes = Data(count: length)
    let status = bytes.withUnsafeMutableBytes { CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: $0.baseAddress!) }
    guard status == kCMBlockBufferNoErr else { fatalError("Cannot read PCM") }
    bytes.withUnsafeBytes { raw in
        for value in raw.bindMemory(to: Int16.self) {
            let magnitude = abs(Int(value)); peak = max(peak, magnitude)
            squared += Double(value) * Double(value)
            if magnitude >= 32767 { clipped += 1 }
            audioSamples += 1
        }
    }
}
guard audioReader.status == .completed, audioSamples > 0, peak > 0, clipped == 0 else { fatalError("Incomplete, silent or clipped AAC audio") }
let peakDb = 20 * log10(Double(peak)/32767)
let rmsDb = 20 * log10(sqrt(squared/Double(audioSamples))/32767)
print("PASS: full AAC decode, \(audioSamples) samples; peak \(peakDb) dBFS, RMS \(rmsDb) dBFS; 0 clipped samples")
let metrics: [String: Any] = ["duration_seconds": duration, "width": Int(video.naturalSize.width), "height": Int(video.naturalSize.height), "fps": video.nominalFrameRate, "decoded_video_frames": count, "decoded_audio_samples": audioSamples, "audio_duration_seconds": audio.timeRange.duration.seconds, "aac_peak_dbfs": peakDb, "aac_rms_dbfs": rmsDb, "aac_clipped_samples": clipped, "complete_video_decode": true, "complete_audio_decode": true]
let json = try JSONSerialization.data(withJSONObject: metrics, options: [.prettyPrinted, .sortedKeys])
try json.write(to: output.appendingPathComponent("media-validation.json"))
