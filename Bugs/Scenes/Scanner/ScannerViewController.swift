//
//  ScannerViewController.swift
//  Bugs
//

import AVFoundation
import UIKit

private final class ScannerZoomSlider: UISlider {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        bounds.insetBy(dx: -10, dy: -14).contains(point)
    }
}

/// Экран сканера: превью камеры, затемнение с вырезом, нижние кнопки. Вью не связываются друг с другом — только с корневым view / safe area.
final class ScannerViewController: UIViewController {

    /// Зона под нижний ряд: отступ 20 + высота 62 + зазор до выреза.
    private let bottomReservedForLayout: CGFloat = 20 + 62 + 24

    private let previewBox: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .black
        v.isUserInteractionEnabled = false
        return v
    }()

    private let previewLayer = AVCaptureVideoPreviewLayer()

    private let dimOverlay = ScannerMaskedDimOverlayView()
    private let dashBorder = ScannerCutoutDashBorderView()
    private let noAccessBackgroundBlur = ScannerStyleFullBlurOverlayView()

    private let infoButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let closeButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let galleryButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let shutterButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let flashButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    private let zoomContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let zoomMinusButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("-", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        b.tintColor = .white
        return b
    }()

    private let zoomPlusButton: UIButton = {
        let b = UIButton(type: .system)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("+", for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        b.tintColor = .white
        return b
    }()

    private let zoomTrackView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white.withAlphaComponent(0.35)
        v.layer.cornerRadius = 3
        return v
    }()

    private let zoomTrackFillView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = UIColor.white
        v.layer.cornerRadius = 3
        return v
    }()

    private let zoomThumbView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .white
        v.layer.cornerRadius = 13
        v.layer.borderWidth = 2
        v.layer.borderColor = UIColor.appReadMore.cgColor
        return v
    }()

    private let zoomSlider: ScannerZoomSlider = {
        let s = ScannerZoomSlider()
        s.translatesAutoresizingMaskIntoConstraints = false
        s.minimumValue = 0
        s.maximumValue = 1
        s.value = 0
        s.minimumTrackTintColor = .clear
        s.maximumTrackTintColor = .clear
        s.setThumbImage(UIImage(), for: .normal)
        return s
    }()

    private nonisolated(unsafe) let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "bugs.scanner.capture")
    private var photoOutput: AVCapturePhotoOutput?
    /// Вспышка только в момент съёмки (не фонарик).
    private var isFlashOnForCapture = false
    private weak var galleryLoaderHost: UIView?
    private var isSessionConfigured = false
    private var shouldRunSessionWhenReady = false
    private var noAccessIllustrationHeightConstraint: NSLayoutConstraint!
    private var zoomTrackFillWidthConstraint: NSLayoutConstraint?
    private var zoomThumbLeadingConstraint: NSLayoutConstraint?
    private var cameraDevice: AVCaptureDevice?

    private let noAccessContainer: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()

    private let noAccessIllustrationView: UIImageView = {
        let iv = UIImageView()
        iv.translatesAutoresizingMaskIntoConstraints = false
        iv.contentMode = .scaleAspectFit
        let img = UIImage(named: "camera_access")
        iv.image = img
        iv.isHidden = (img == nil)
        return iv
    }()

    private let noAccessTitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = .white
        l.font = .systemFont(ofSize: 24, weight: .bold)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let noAccessSubtitleLabel: UILabel = {
        let l = UILabel()
        l.translatesAutoresizingMaskIntoConstraints = false
        l.textColor = UIColor.white.withAlphaComponent(0.85)
        l.font = .systemFont(ofSize: 16, weight: .regular)
        l.textAlignment = .center
        l.numberOfLines = 0
        return l
    }()

    private let openSettingsButton: GradientRoundedCTAControl = {
        let b = GradientRoundedCTAControl()
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        overrideUserInterfaceStyle = .dark

        dimOverlay.bottomReservedHeight = bottomReservedForLayout
        dashBorder.bottomReservedHeight = bottomReservedForLayout
        dimOverlay.onTapDimmedArea = nil

        view.addSubview(previewBox)
        view.addSubview(dimOverlay)
        view.addSubview(dashBorder)
        view.addSubview(noAccessBackgroundBlur)
        view.addSubview(infoButton)
        view.addSubview(closeButton)
        view.addSubview(galleryButton)
        view.addSubview(shutterButton)
        view.addSubview(flashButton)
        view.addSubview(zoomContainer)
        zoomContainer.addSubview(zoomMinusButton)
        zoomContainer.addSubview(zoomTrackView)
        zoomContainer.addSubview(zoomTrackFillView)
        zoomContainer.addSubview(zoomThumbView)
        zoomContainer.addSubview(zoomSlider)
        zoomContainer.addSubview(zoomPlusButton)
        view.addSubview(noAccessContainer)
        noAccessContainer.addSubview(noAccessIllustrationView)
        noAccessContainer.addSubview(noAccessTitleLabel)
        noAccessContainer.addSubview(noAccessSubtitleLabel)
        noAccessContainer.addSubview(openSettingsButton)

        NSLayoutConstraint.activate([
            previewBox.topAnchor.constraint(equalTo: view.topAnchor),
            previewBox.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            previewBox.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            previewBox.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dimOverlay.topAnchor.constraint(equalTo: view.topAnchor),
            dimOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            dashBorder.topAnchor.constraint(equalTo: view.topAnchor),
            dashBorder.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            dashBorder.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            dashBorder.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            noAccessBackgroundBlur.topAnchor.constraint(equalTo: view.topAnchor),
            noAccessBackgroundBlur.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noAccessBackgroundBlur.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            noAccessBackgroundBlur.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            closeButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 32),
            closeButton.heightAnchor.constraint(equalToConstant: 32),

            infoButton.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            infoButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
            infoButton.widthAnchor.constraint(equalToConstant: 24),
            infoButton.heightAnchor.constraint(equalToConstant: 24),

            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            shutterButton.widthAnchor.constraint(equalToConstant: 62),
            shutterButton.heightAnchor.constraint(equalToConstant: 62),

            galleryButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            galleryButton.trailingAnchor.constraint(equalTo: shutterButton.leadingAnchor, constant: -40),
            galleryButton.widthAnchor.constraint(equalToConstant: 56),
            galleryButton.heightAnchor.constraint(equalToConstant: 56),

            flashButton.centerYAnchor.constraint(equalTo: shutterButton.centerYAnchor),
            flashButton.leadingAnchor.constraint(equalTo: shutterButton.trailingAnchor, constant: 40),
            flashButton.widthAnchor.constraint(equalToConstant: 56),
            flashButton.heightAnchor.constraint(equalToConstant: 56),

            zoomContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            zoomContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            zoomContainer.bottomAnchor.constraint(equalTo: shutterButton.topAnchor, constant: -20),
            zoomContainer.heightAnchor.constraint(equalToConstant: 44),

            zoomMinusButton.leadingAnchor.constraint(equalTo: zoomContainer.leadingAnchor),
            zoomMinusButton.centerYAnchor.constraint(equalTo: zoomContainer.centerYAnchor),
            zoomMinusButton.widthAnchor.constraint(equalToConstant: 24),
            zoomMinusButton.heightAnchor.constraint(equalToConstant: 24),

            zoomPlusButton.trailingAnchor.constraint(equalTo: zoomContainer.trailingAnchor),
            zoomPlusButton.centerYAnchor.constraint(equalTo: zoomContainer.centerYAnchor),
            zoomPlusButton.widthAnchor.constraint(equalToConstant: 24),
            zoomPlusButton.heightAnchor.constraint(equalToConstant: 24),

            zoomTrackView.leadingAnchor.constraint(equalTo: zoomMinusButton.trailingAnchor, constant: 8),
            zoomTrackView.trailingAnchor.constraint(equalTo: zoomPlusButton.leadingAnchor, constant: -8),
            zoomTrackView.centerYAnchor.constraint(equalTo: zoomContainer.centerYAnchor),
            zoomTrackView.heightAnchor.constraint(equalToConstant: 6),

            zoomTrackFillView.leadingAnchor.constraint(equalTo: zoomTrackView.leadingAnchor),
            zoomTrackFillView.topAnchor.constraint(equalTo: zoomTrackView.topAnchor),
            zoomTrackFillView.bottomAnchor.constraint(equalTo: zoomTrackView.bottomAnchor),

            zoomThumbView.centerYAnchor.constraint(equalTo: zoomTrackView.centerYAnchor),
            zoomThumbView.widthAnchor.constraint(equalToConstant: 26),
            zoomThumbView.heightAnchor.constraint(equalToConstant: 26),

            zoomSlider.leadingAnchor.constraint(equalTo: zoomTrackView.leadingAnchor),
            zoomSlider.trailingAnchor.constraint(equalTo: zoomTrackView.trailingAnchor),
            zoomSlider.centerYAnchor.constraint(equalTo: zoomTrackView.centerYAnchor),
            zoomSlider.heightAnchor.constraint(equalToConstant: 44),

            noAccessContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            noAccessContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            noAccessContainer.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),

            noAccessIllustrationView.topAnchor.constraint(equalTo: noAccessContainer.topAnchor),
            noAccessIllustrationView.centerXAnchor.constraint(equalTo: noAccessContainer.centerXAnchor),
            noAccessIllustrationView.widthAnchor.constraint(lessThanOrEqualTo: noAccessContainer.widthAnchor),

            noAccessTitleLabel.topAnchor.constraint(equalTo: noAccessIllustrationView.bottomAnchor, constant: 16),
            noAccessTitleLabel.leadingAnchor.constraint(equalTo: noAccessContainer.leadingAnchor),
            noAccessTitleLabel.trailingAnchor.constraint(equalTo: noAccessContainer.trailingAnchor),

            noAccessSubtitleLabel.topAnchor.constraint(equalTo: noAccessTitleLabel.bottomAnchor, constant: 12),
            noAccessSubtitleLabel.leadingAnchor.constraint(equalTo: noAccessContainer.leadingAnchor),
            noAccessSubtitleLabel.trailingAnchor.constraint(equalTo: noAccessContainer.trailingAnchor),

            openSettingsButton.topAnchor.constraint(equalTo: noAccessSubtitleLabel.bottomAnchor, constant: 20),
            openSettingsButton.leadingAnchor.constraint(equalTo: noAccessContainer.leadingAnchor, constant: 22),
            openSettingsButton.trailingAnchor.constraint(equalTo: noAccessContainer.trailingAnchor, constant: -22),
            openSettingsButton.heightAnchor.constraint(equalToConstant: 52),
            openSettingsButton.bottomAnchor.constraint(equalTo: noAccessContainer.bottomAnchor),
        ])
        noAccessIllustrationHeightConstraint = noAccessIllustrationView.heightAnchor.constraint(
            equalToConstant: noAccessIllustrationView.isHidden ? 0 : 140
        )
        noAccessIllustrationHeightConstraint.isActive = true

        previewLayer.videoGravity = .resizeAspectFill
        previewBox.layer.addSublayer(previewLayer)

        configureButtonImages()
        closeButton.accessibilityLabel = L10n.string("scanner.close.accessibility")
        infoButton.addTarget(self, action: #selector(infoTapped), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        galleryButton.addTarget(self, action: #selector(galleryTapped), for: .touchUpInside)
        shutterButton.addTarget(self, action: #selector(shutterTapped), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(flashTapped), for: .touchUpInside)
        zoomMinusButton.addTarget(self, action: #selector(zoomMinusTapped), for: .touchUpInside)
        zoomPlusButton.addTarget(self, action: #selector(zoomPlusTapped), for: .touchUpInside)
        zoomSlider.addTarget(self, action: #selector(zoomSliderChanged), for: .valueChanged)
        openSettingsButton.addTarget(self, action: #selector(openSettingsTapped), for: .touchUpInside)
        noAccessBackgroundBlur.isHidden = true
        applyNoAccessLocalizedStrings()
        zoomThumbLeadingConstraint = zoomThumbView.leadingAnchor.constraint(equalTo: zoomTrackView.leadingAnchor)
        zoomThumbLeadingConstraint?.isActive = true
        zoomTrackFillWidthConstraint = zoomTrackFillView.widthAnchor.constraint(equalToConstant: 0)
        zoomTrackFillWidthConstraint?.isActive = true

        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = previewBox.bounds
        updateZoomThumbPosition()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applySubscriptionStatusForAppearance()
        navigationController?.setNavigationBarHidden(true, animated: animated)
        shouldRunSessionWhenReady = true
        applyNoAccessLocalizedStrings()
        updateCameraAccessUI()
        startSessionIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        disableInteractivePopGestureIfNeeded()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        restoreInteractivePopGestureIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        hideGalleryLoader()
        shouldRunSessionWhenReady = false
        resetZoomUI()
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureSession() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                self?.sessionQueue.async {
                    self?.configureSession()
                }
            }
            return
        default:
            DispatchQueue.main.async { [weak self] in
                self?.updateCameraAccessUI()
            }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        for input in Array(session.inputs) {
            session.removeInput(input)
        }
        for output in Array(session.outputs) {
            session.removeOutput(output)
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            session.commitConfiguration()
            return
        }
        cameraDevice = device
        session.addInput(input)

        let output = AVCapturePhotoOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        photoOutput = output
        session.commitConfiguration()
        isSessionConfigured = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.previewLayer.session = self.session
            self.updateCameraAccessUI()
            self.startSessionIfNeeded()
        }
    }

    private func startSessionIfNeeded() {
        guard shouldRunSessionWhenReady else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.isSessionConfigured else { return }
            if !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    private func updateCameraAccessUI() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let isDenied = status == .denied || status == .restricted
        // До явного отказа (`notDetermined`) сохраняем обычный UI камеры.
        noAccessContainer.isHidden = !isDenied
        noAccessBackgroundBlur.isHidden = !isDenied
        dimOverlay.isHidden = isDenied
        dashBorder.isHidden = isDenied
        zoomContainer.isHidden = isDenied
    }

    private func applyNoAccessLocalizedStrings() {
        noAccessTitleLabel.text = L10n.string("scanner.camera.no_access.title")
        noAccessSubtitleLabel.text = L10n.string("scanner.camera.no_access.message")
        openSettingsButton.setTitle(L10n.string("scanner.camera.open_settings"), for: .normal)
    }

    private func configureButtonImages() {
        closeButton.setImage(Self.scaledAssetImage(named: "scanner_close", side: 32, template: false), for: .normal)
        infoButton.setImage(Self.scaledAssetImage(named: "scanner_info", side: 24, template: false), for: .normal)
        galleryButton.setImage(Self.scaledAssetImage(named: "scanner_gallery", side: 56, template: false), for: .normal)
        shutterButton.setImage(Self.scaledAssetImage(named: "scanner_shutter", side: 62, template: false), for: .normal)
        updateFlashButtonImage()
    }

    private static func scaledAssetImage(named: String, side: CGFloat, template: Bool) -> UIImage? {
        guard let img = UIImage(named: named) else { return nil }
        return renderImage(img, size: CGSize(width: side, height: side), template: template)
    }

    private static func renderImage(_ image: UIImage, size: CGSize, template: Bool) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = UITraitCollection.current.displayScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }.withRenderingMode(template ? .alwaysTemplate : .alwaysOriginal)
    }

    private func updateFlashButtonImage() {
        let name = isFlashOnForCapture ? "scanner_flash_on" : "scanner_flash_off"
        flashButton.setImage(Self.scaledAssetImage(named: name, side: 56, template: false), for: .normal)
    }

    @objc
    private func infoTapped() {
        let tips = ScannerTipsViewController()
        tips.modalPresentationStyle = .pageSheet
        if let sheet = tips.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 24
        }
        present(tips, animated: true)
    }

    @objc
    private func closeTapped() {
        dismiss(animated: true)
    }

    @objc
    private func galleryTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.photoLibrary) else { return }
        showGalleryLoader()
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let picker = UIImagePickerController()
            picker.delegate = self
            picker.sourceType = .photoLibrary
            picker.modalPresentationStyle = .fullScreen
            self.present(picker, animated: true) { [weak self] in
                self?.hideGalleryLoader()
            }
        }
    }

    private func showGalleryLoader() {
        guard galleryLoaderHost == nil else { return }
        let host = UIView()
        host.translatesAutoresizingMaskIntoConstraints = false
        host.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        host.isUserInteractionEnabled = true

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.color = .white
        spinner.startAnimating()
        host.addSubview(spinner)

        view.addSubview(host)
        NSLayoutConstraint.activate([
            host.topAnchor.constraint(equalTo: view.topAnchor),
            host.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            spinner.centerXAnchor.constraint(equalTo: host.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: host.centerYAnchor),
        ])
        view.bringSubviewToFront(host)
        view.bringSubviewToFront(closeButton)
        view.bringSubviewToFront(infoButton)
        galleryLoaderHost = host
    }

    private func hideGalleryLoader() {
        galleryLoaderHost?.removeFromSuperview()
        galleryLoaderHost = nil
    }

    @objc
    private func shutterTapped() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .denied || status == .restricted {
            openSettingsTapped()
            return
        }
        guard let out = photoOutput else { return }
        let wantFlash = isFlashOnForCapture
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let settings = AVCapturePhotoSettings()
            if wantFlash, out.supportedFlashModes.contains(.on) {
                settings.flashMode = .on
            } else {
                settings.flashMode = .off
            }
            out.capturePhoto(with: settings, delegate: self)
        }
    }

    @objc
    private func flashTapped() {
        isFlashOnForCapture.toggle()
        updateFlashButtonImage()
    }

    @objc
    private func zoomSliderChanged() {
        applyZoomValue(CGFloat(zoomSlider.value))
    }

    @objc
    private func zoomMinusTapped() {
        zoomSlider.value = max(0, zoomSlider.value - 0.1)
        zoomSliderChanged()
    }

    @objc
    private func zoomPlusTapped() {
        zoomSlider.value = min(1, zoomSlider.value + 0.1)
        zoomSliderChanged()
    }

    private func applyZoomValue(_ normalizedValue: CGFloat) {
        updateZoomThumbPosition()
        sessionQueue.async { [weak self] in
            guard let self, let device = self.cameraDevice else { return }
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 6)
            let targetZoom = 1 + (maxZoom - 1) * max(0, min(1, normalizedValue))
            do {
                try device.lockForConfiguration()
                device.videoZoomFactor = max(1, min(targetZoom, maxZoom))
                device.unlockForConfiguration()
            } catch {
                return
            }
        }
    }

    private func updateZoomThumbPosition() {
        let trackWidth = zoomTrackView.bounds.width
        guard trackWidth > 0 else { return }
        let value = CGFloat(zoomSlider.value)
        zoomTrackFillWidthConstraint?.constant = trackWidth * value
        let thumbWidth: CGFloat = 26
        let thumbX = max(0, min(trackWidth * value - thumbWidth / 2, trackWidth - thumbWidth))
        zoomThumbLeadingConstraint?.constant = thumbX
    }

    private func resetZoomUI() {
        zoomSlider.value = 0
        updateZoomThumbPosition()
        applyZoomValue(0)
    }

    @objc
    private func openSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

extension ScannerViewController: AVCapturePhotoCaptureDelegate {

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data)
        else {
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            let progress = RecognitionProgressViewController(backgroundImage: image)
            self.navigationController?.pushViewController(progress, animated: true)
        }
    }
}

extension ScannerViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    func imagePickerController(
        _ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
    ) {
        let picked = info[.originalImage] as? UIImage
        picker.dismiss(animated: true) { [weak self] in
            guard let self, let picked else { return }
            let progress = RecognitionProgressViewController(backgroundImage: picked)
            self.navigationController?.pushViewController(progress, animated: true)
        }
    }
}
