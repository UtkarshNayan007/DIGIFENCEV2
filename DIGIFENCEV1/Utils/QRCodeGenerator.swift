//
//  QRCodeGenerator.swift
//  DIGIFENCEV1
//
//  Generates QR codes for event passes using CoreImage.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeGenerator {
    static let shared = QRCodeGenerator()
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
    /// Generates a QR code image from a string token
    func generateQRCode(from string: String, size: CGFloat = 200) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else { return nil }
        
        // Scale the image to desired size
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
    }
    
    /// Generates a unique token for event pass
    static func generatePassToken(eventId: String, userId: String) -> String {
        let timestamp = Int64(Date().timeIntervalSince1970 * 1000)
        let randomSuffix = String(format: "%06d", Int.random(in: 0...999999))
        return "\(eventId)_\(userId)_\(timestamp)_\(randomSuffix)"
    }
}

// MARK: - SwiftUI QR Code View

struct QRCodeView: View {
    let token: String
    var size: CGFloat = 180
    var foregroundColor: Color = .black
    var backgroundColor: Color = .white
    
    var body: some View {
        if let uiImage = QRCodeGenerator.shared.generateQRCode(from: token, size: size * 2) {
            Image(uiImage: uiImage)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            // Fallback placeholder
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.systemGray5))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "qrcode")
                        .font(.system(size: size * 0.4))
                        .foregroundColor(.secondary)
                )
        }
    }
}
