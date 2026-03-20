//
//  QRScannerView.swift
//  DIGIFENCEV1
//
//  Admin QR code scanner for verifying event passes using AVFoundation.
//

import SwiftUI
import AVFoundation

struct QRScannerView: View {
    @StateObject private var viewModel = QRScannerViewModel()
    @State private var showManualEntry = false
    @State private var manualCode = ""
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreviewView(session: viewModel.captureSession)
                .ignoresSafeArea()
            
            // Overlay
            scannerOverlay
            
            // Result Sheet
            if viewModel.scanResult != nil {
                resultOverlay
            }
        }
        .navigationTitle("Scan Pass")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Manual") {
                    HapticManager.shared.light()
                    showManualEntry = true
                }
            }
        }
        .onAppear { viewModel.startScanning() }
        .onDisappear { viewModel.stopScanning() }
        .alert("Manual Entry", isPresented: $showManualEntry) {
            TextField("Enter pass code", text: $manualCode)
            Button("Verify") {
                Task { await viewModel.verifyCode(manualCode) }
            }
            Button("Cancel", role: .cancel) { manualCode = "" }
        }
    }

    // MARK: - Scanner Overlay
    
    private var scannerOverlay: some View {
        VStack {
            Spacer()
            
            // Scan Frame
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.8), lineWidth: 3)
                    .frame(width: 280, height: 280)
                
                // Corner accents
                ForEach(0..<4, id: \.self) { corner in
                    CornerAccent()
                        .rotationEffect(.degrees(Double(corner) * 90))
                        .offset(
                            x: corner == 1 || corner == 2 ? 120 : -120,
                            y: corner >= 2 ? 120 : -120
                        )
                }
                
                // Scanning line animation
                if viewModel.isScanning {
                    ScanningLine()
                }
            }
            
            Spacer()
            
            // Instructions
            VStack(spacing: DFSpacing.md) {
                Text("Position QR code within frame")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                
                Text("The scanner will automatically detect the pass")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 60)
        }
    }
    
    // MARK: - Result Overlay
    
    private var resultOverlay: some View {
        VStack {
            Spacer()
            
            VStack(spacing: DFSpacing.xl) {
                // Status Icon
                ZStack {
                    Circle()
                        .fill(viewModel.scanResult?.isValid == true ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: viewModel.scanResult?.isValid == true ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(viewModel.scanResult?.isValid == true ? .green : .red)
                }

                // Result Text
                VStack(spacing: DFSpacing.sm) {
                    Text(viewModel.scanResult?.isValid == true ? "Pass Verified" : "Invalid Pass")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(viewModel.scanResult?.message ?? "")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Event Info (if valid)
                if let result = viewModel.scanResult, result.isValid, let eventTitle = result.eventTitle {
                    VStack(spacing: DFSpacing.sm) {
                        Text(eventTitle)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let entryCode = result.entryCode {
                            Text("Entry Code: \(entryCode)")
                                .font(.system(size: 14, weight: .medium, design: .monospaced))
                                .foregroundColor(.dfAccent)
                        }
                    }
                    .padding(DFSpacing.lg)
                    .background(Color(.tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.md, style: .continuous))
                }
                
                // Action Button
                DFPrimaryButton(
                    title: "Scan Another",
                    icon: "qrcode.viewfinder",
                    colors: [.cyan, .blue]
                ) {
                    viewModel.resetScan()
                }
                .padding(.horizontal, DFSpacing.xl)
            }
            .padding(DFSpacing.xl)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: DFCornerRadius.xxl, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: -10)
            .padding(.horizontal, DFSpacing.lg)
            .padding(.bottom, DFSpacing.xl)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.scanResult != nil)
    }
}


// MARK: - Corner Accent

private struct CornerAccent: View {
    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 20))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 20, y: 0))
        }
        .stroke(Color.dfAccent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
    }
}

// MARK: - Scanning Line

private struct ScanningLine: View {
    @State private var offset: CGFloat = -120
    
    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .dfAccent.opacity(0.8), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: 260, height: 3)
            .offset(y: offset)
            .onAppear {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    offset = 120
                }
            }
    }
}

// MARK: - Camera Preview

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        context.coordinator.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var previewLayer: AVCaptureVideoPreviewLayer?
    }
}
