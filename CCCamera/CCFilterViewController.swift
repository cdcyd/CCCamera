//
//  CCFilterViewController.swift
//  CCCamera
//
//  Created by cyd on 2018/9/7.
//  Copyright © 2018 cyd. All rights reserved.
//

import UIKit
import AVFoundation

class CCFilterViewController: UIViewController {

    lazy private var preview: CCPreviewView = {
        let rect = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        let view = CCPreviewView(frame: rect)
        return view
    }()

    lazy private var filterLabel: UILabel = {
        let rect = CGRect(x: 0, y: self.view.bounds.height/2-80, width: self.view.bounds.width, height: 30)
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14)
        label.textColor = UIColor.red
        label.textAlignment = .center
        label.frame = rect
        label.text = "左右轻扫切换滤镜"
        return label
    }()

    lazy private var videoFilter: CCFilterRenderer = {
        let filter = self.filterRenderers[0]
        return filter
    }()

    lazy private var filterRenderers: [CCFilterRenderer] = {
        let lists = [CCPhotoRenderer("CIPhotoEffectChrome"),
                     CCPhotoRenderer("CIPhotoEffectFade"),
                     CCPhotoRenderer("CIPhotoEffectInstant"),
                     CCPhotoRenderer("CIPhotoEffectMono"),
                     CCPhotoRenderer("CIPhotoEffectNoir"),
                     CCPhotoRenderer("CIPhotoEffectProcess"),
                     CCPhotoRenderer("CIPhotoEffectTonal"),
                     CCPhotoRenderer("CIPhotoEffectTransfer"),
                     CCPhotoRenderer("CILinearToSRGBToneCurve"),
                     CCPhotoRenderer("CISRGBToneCurveToLinear"),
                     CCPhotoRenderer("CIColorInvert")]
        return lists
    }()

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], autoreleaseFrequency: .workItem)

    private let dataOutputQueue = DispatchQueue(label: "video data queue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)

    private let videoDataOutput = AVCaptureVideoDataOutput()

    private var filterIndex: Int = 0

    private var setupResult: SessionSetupResult = .success

    private var isSessionRunning = false

    private var renderingEnabled = true

    private var videoDeviceInput: AVCaptureDeviceInput!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.edgesForExtendedLayout = UIRectEdge.init(rawValue: 0)
        self.view.backgroundColor = UIColor.black
        self.view.addSubview(preview)
        self.view.addSubview(filterLabel)

        let leftSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(changeFilterSwipe))
        leftSwipeGesture.direction = .left
        preview.addGestureRecognizer(leftSwipeGesture)

        let rightSwipeGesture = UISwipeGestureRecognizer(target: self, action: #selector(changeFilterSwipe))
        rightSwipeGesture.direction = .right
        preview.addGestureRecognizer(rightSwipeGesture)

        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: break
            case .notDetermined:
                sessionQueue.suspend()
                AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                    if !granted {
                        self.setupResult = .notAuthorized
                    }
                    self.sessionQueue.resume()
                })
            default:
                setupResult = .notAuthorized
        }

        sessionQueue.async {
            self.configureSession()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let statusOrientation = UIApplication.shared.statusBarOrientation
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                let devicePosition = self.videoDeviceInput.device.position
                let videoOrientation = self.videoDataOutput.connection(with: .video)!.videoOrientation
                self.preview.mirroring = (devicePosition == .front)
                let rotation = CCPreviewView.Rotation(with: statusOrientation, videoOrientation: videoOrientation, cameraPosition: devicePosition)
                if let rotation = rotation {
                    self.preview.rotation = rotation
                }
                self.dataOutputQueue.async {
                    self.renderingEnabled = true
                }
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning
            case .notAuthorized:
                print("没有权限")
                break
            case .configurationFailed:
                print("配置会话失败")
                break
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        dataOutputQueue.async {
            self.renderingEnabled = false
        }
        sessionQueue.async {
            if self.setupResult == .success {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }
        }
        super.viewWillDisappear(animated)
    }

    deinit {
        print("deinit: \(self)")
    }

    private func configureSession() {
        if setupResult != .success {
            return
        }

        let defaultVideoDevice: AVCaptureDevice? = AVCaptureDevice.default(for: .video)
        guard let videoDevice = defaultVideoDevice else {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }

        do {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        } catch {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }

        if session.canAddOutput(videoDataOutput) {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            videoDataOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        } else {
            print("Could not add video data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.hd1920x1080
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)
        session.commitConfiguration()
    }

    @objc private func changeFilterSwipe(_ gesture: UISwipeGestureRecognizer) {
        if gesture.direction == .left {
            filterIndex = (filterIndex + 1) % filterRenderers.count
        } else if gesture.direction == .right {
            filterIndex = (filterIndex + filterRenderers.count - 1) % filterRenderers.count
        }

        let newIndex = filterIndex
        let filterDescription = filterRenderers[newIndex].description
        self.showFilterLabel(description: filterDescription)

        dataOutputQueue.async {
            self.videoFilter.reset()
            self.videoFilter = self.filterRenderers[newIndex]
        }
    }

    private func showFilterLabel(description: String) {
        filterLabel.text = description
        filterLabel.alpha = 0.0

        UIView.animate(withDuration: 0.25) {
            self.filterLabel.alpha = 1.0
        }

        UIView.animate(withDuration: 2.0) {
            self.filterLabel.alpha = 0.0
        }
    }
}

extension CCFilterViewController: AVCaptureVideoDataOutputSampleBufferDelegate {

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        self.processVideo(sampleBuffer: sampleBuffer)
    }

    private func processVideo(sampleBuffer: CMSampleBuffer) {
        if !renderingEnabled {
            return
        }
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer) else {
                return
        }
        let filter = self.videoFilter
        if !filter.isPrepared {
            filter.prepare(with: formatDescription, outputRetainedBufferCountHint: 3)
        }
        guard let filteredBuffer = filter.render(pixelBuffer: videoPixelBuffer) else {
            print("Unable to filter video buffer")
            return
        }
        preview.pixelBuffer = filteredBuffer
    }
}
