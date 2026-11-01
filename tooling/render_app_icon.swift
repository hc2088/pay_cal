import AppKit
import Foundation

struct IconOutput {
  let path: String
  let pixels: Int
}

guard CommandLine.arguments.count == 3 else {
  fputs("Usage: swift tooling/render_app_icon.swift <source.svg> <project-root>\n", stderr)
  exit(2)
}

let sourceURL = URL(fileURLWithPath: CommandLine.arguments[1])
let rootURL = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
guard let sourceImage = NSImage(contentsOf: sourceURL) else {
  fputs("Unable to open SVG: \(sourceURL.path)\n", stderr)
  exit(1)
}
var sourceBounds = NSRect(origin: .zero, size: sourceImage.size)
guard let sourceCGImage = sourceImage.cgImage(
  forProposedRect: &sourceBounds,
  context: nil,
  hints: nil
) else {
  fputs("Unable to rasterize SVG source: \(sourceURL.path)\n", stderr)
  exit(1)
}

let outputs = [
  IconOutput(path: "android/app/src/main/res/mipmap-mdpi/ic_launcher.png", pixels: 48),
  IconOutput(path: "android/app/src/main/res/mipmap-hdpi/ic_launcher.png", pixels: 72),
  IconOutput(path: "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png", pixels: 96),
  IconOutput(path: "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png", pixels: 144),
  IconOutput(path: "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png", pixels: 192),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png", pixels: 20),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png", pixels: 40),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png", pixels: 60),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png", pixels: 29),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png", pixels: 58),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png", pixels: 87),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png", pixels: 40),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png", pixels: 80),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png", pixels: 120),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png", pixels: 120),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png", pixels: 180),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png", pixels: 76),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png", pixels: 152),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png", pixels: 167),
  IconOutput(path: "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png", pixels: 1024),
]

for output in outputs {
  let colorSpace = CGColorSpaceCreateDeviceRGB()
  let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue |
      CGImageAlphaInfo.noneSkipLast.rawValue
  guard let context = CGContext(
    data: nil,
    width: output.pixels,
    height: output.pixels,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: bitmapInfo
  ) else {
    fputs("Unable to allocate bitmap for \(output.path)\n", stderr)
    exit(1)
  }
  context.interpolationQuality = .high
  context.draw(
    sourceCGImage,
    in: CGRect(x: 0, y: 0, width: output.pixels, height: output.pixels)
  )

  guard let renderedCGImage = context.makeImage() else {
    fputs("Unable to render PNG for \(output.path)\n", stderr)
    exit(1)
  }
  let bitmap = NSBitmapImageRep(cgImage: renderedCGImage)
  guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Unable to encode PNG for \(output.path)\n", stderr)
    exit(1)
  }
  let destination = rootURL.appending(path: output.path)
  try FileManager.default.createDirectory(
    at: destination.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try png.write(to: destination)
}

print("Rendered \(outputs.count) icon PNG files from \(sourceURL.lastPathComponent)")
