//
//  ViewController.swift
//  ConverterTest
//
//  Created by Sergey Yuryev on 25/01/2017.
//  Copyright © 2017 syuryev. All rights reserved.
//

import UIKit
import AVFoundation

enum RecordExtension: String {
    case CAF = ".caf"
    case M4A = ".m4a"
}

enum RecordState: Int {
    case Default
    case Recording
    case Stoped
    case Converting
    case Converted
    case Playing
}

class ViewController: UIViewController {

    /// MARK: - Outlets
    
    @IBOutlet weak var actionButton: UIButton!
    
    
    /// Vars
    
    /// Current state
    private var recordState: RecordState = .Default
    
    /// Engine to record audio
    private let audioEngine = AVAudioEngine()
    
    /// Player to play audio
    private var audioPlayer: AVPlayer?
    
    /// File to write recording audio
    private var audioFile: AVAudioFile?
    
    /// Path to converted recording audio
    private var convertedPath: URL?
    
    
    /// MARK: - View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerDidFinishPlaying(notification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        NotificationCenter.default.removeObserver(self)
        super.viewWillDisappear(animated)
    }
    
    
    /// MARK: - Setup
    
    func setup() {
        self.updateUI(state: self.recordState)
    }
    
    
    /// MARK: - Recording
    
    func startRecord() {
        self.audioFile = self.createAudioRecordFile()
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSessionCategoryPlayAndRecord, with: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        guard let inputNode = self.audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: self.format()) { (buffer, time) in
            buffer.frameLength = 1024
            
            if let f = self.audioFile {
                do {
                    try f.write(from: buffer)
                }
                catch let error as NSError {
                    print(error.localizedDescription)
                }
            }
        }
        self.audioEngine.prepare()
        do {
            try self.audioEngine.start()
        }
        catch let error as NSError {
            print(error.localizedDescription)
        }
        self.recordState = .Recording
        self.updateUI(state: self.recordState)
    }
    
    func stopRecord() {
        guard let inputNode = self.audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        inputNode.removeTap(onBus: 0)
        self.audioEngine.stop()
        self.recordState = .Stoped
        self.updateUI(state: self.recordState)
    }

    
    /// MARK: - Convert
    
    func startConvert() {
        self.recordState = .Converting
        self.updateUI(state: self.recordState)
        self.convertedPath = self.createAudioConvertPath()
        guard let file = self.audioFile else {
            print("error no audio file")
            return
        }
        guard let output = self.convertedPath else {
            print("error no output path")
            return
        }
        let input = file.url
        self.convert(sourceURL: input, destinationURL: output, success: {
            DispatchQueue.main.async {
                self.recordState = .Converted
                self.updateUI(state: self.recordState)
            }
        }, failure: {
            DispatchQueue.main.async {
                self.recordState = .Default
                self.updateUI(state: self.recordState)
            }
        })
    }

    func convert(sourceURL: URL, destinationURL: URL, success: ((Void) -> Void)?, failure: ((Void) -> Void)?) {
        let started = now()
        print("started \(started)")
        let asset = AVURLAsset(url: sourceURL)
        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A)
        exporter?.outputFileType = AVFileTypeAppleM4A
        exporter?.outputURL = destinationURL
        exporter?.exportAsynchronously(completionHandler: {
            print("finished \(diff(start: started)) sec.")
            if let e = exporter {
                switch e.status {
                case .failed:
                    print("failed \(e.error)")
                    if let c = failure {
                        c()
                    }
                case .cancelled:
                    print("cancelled \(e.error)")
                    if let c = failure {
                        c()
                    }
                default:
                    print("complete")
                    if let c = success {
                        c()
                    }
                }
            }
        })
    }
    
    
    /// MARK: - Playback
    
    func startPlay() {
        guard let output = self.convertedPath else {
            print("error no output path")
            return
        }
        let asset = AVURLAsset(url: output)
        let file = AVPlayerItem(asset: asset)
        self.audioPlayer = AVPlayer(playerItem: file)
        self.audioPlayer?.play()
        self.recordState = .Playing
        self.updateUI(state: self.recordState)
    }
    
    func stopPlay() {
        self.audioPlayer?.pause()
        self.recordState = .Default
        self.updateUI(state: self.recordState)
    }
    
    func playerDidFinishPlaying(notification: NSNotification) {
        self.recordState = .Default
        self.updateUI(state: self.recordState)
    }
    
    
    /// MARK: - Actions
    
    @IBAction func actionButtonTap(_ sender: Any) {
        switch self.recordState {
        case .Default:
            self.startRecord()
            break
        case .Recording:
            self.stopRecord()
            break
        case .Stoped:
            self.startConvert()
            break
        case .Converting:
            break
        case .Converted:
            self.startPlay()
        case .Playing:
            self.stopPlay()
            break
        }
    }
    
    func updateUI(state: RecordState) {
        switch self.recordState {
        case .Default:
            self.actionButton.setTitle("Record", for: .normal)
            break
        case .Recording:
            self.actionButton.setTitle("Stop recording", for: .normal)
            break
        case .Stoped:
            self.actionButton.setTitle("Convert", for: .normal)
            break
        case .Converting:
            self.actionButton.setTitle("Converting", for: .normal)
            break
        case .Converted:
            self.actionButton.setTitle("Play", for: .normal)
            break
        case .Playing:
            self.actionButton.setTitle("Stop playing", for: .normal)
            break
        }
    }

    func format() -> AVAudioFormat {
        guard let inputNode = self.audioEngine.inputNode else {
            fatalError("Audio engine has no input node")
        }
        return inputNode.inputFormat(forBus: 0)
    }
    
    func createAudioRecordFile() -> AVAudioFile? {
        guard let path = self.createAudioRecordPath() else {
            return nil
        }
        do {
            let file = try AVAudioFile(forWriting: path, settings: self.format().settings)
            return file
        }
        catch let error as NSError {
            print(error.localizedDescription)
            return nil
        }
    }
    
    func createPath(ex: RecordExtension) -> URL? {
        let format = DateFormatter()
        format.dateFormat="yyyy-MM-dd-HH-mm-ss"
        let currentFileName = "recording-\(format.string(from: Date()))" + ex.rawValue
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = documentsDirectory.appendingPathComponent(currentFileName)
        return url
    }
    
    func createAudioRecordPath() -> URL? {
        return self.createPath(ex: .CAF)
    }
    
    func createAudioConvertPath() -> URL? {
        return self.createPath(ex: .M4A)
    }

}


