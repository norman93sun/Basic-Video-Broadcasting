//
//  RecorderManager.swift
//  OpenLive
//
//  Created by Norman on 2021/7/20.
//  Copyright © 2021 Agora. All rights reserved.
//

import Foundation
import AudioKit
import AVKit

class RatingTool: NSObject {
    
    var currentNoteNumberBlock: ((Int32)->Void)?
    
    //麦克风
    var mic: AKMicrophone?
    
    // ------------------- 频率检测 ------------------- /
    //频率跟踪器
    var tracker: AKFrequencyTracker!
    //消音器
    var silence: AKBooster!
    // ------------------- 音频录制 ------------------- /
    var micMixer: AKMixer!
    var recorder: AKNodeRecorder!
    var player: AKPlayer!
    var tape: AKAudioFile!
    var micBooster: AKBooster!
    var moogLadder: AKMoogLadder!
    var mainMixer: AKMixer!
    
    var bgLadder: AKMoogLadder!
    var bgPlayer: AKPlayer!
    
    
    let noteFrequencies = [16.35, 17.32, 18.35, 19.45, 20.6, 21.83, 23.12, 24.5, 25.96, 27.5, 29.14, 30.87]
    let noteNamesWithSharps = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    let noteNamesWithFlats = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    
    //    let noteNames = [NoteScale_C, NoteScale_Csharp, NoteScale_D, NoteScale_Dsharp, NoteScale_E, NoteScale_F, NoteScale_Fsharp, NoteScale_G, NoteScale_Gsharp, NoteScale_A, NoteScale_Asharp, NoteScale_B]
    
    
    // 定时器获取声音频率
    var timerRefresh: Timer?
    
    override init() {
        super.init()
        self.initAudioKit()
    }
    
    
    func initAudioKit() {
        
        // Clean tempFiles !
        AKAudioFile.cleanTempDirectory()
        
        
        // AKSettings
        AKSettings.bufferLength = .medium
        // 我们是否应该收听音频输入（麦克风）
        AKSettings.audioInputEnabled = true
        AKSettings.defaultToSpeaker = true
        AKSettings.useBluetooth = true
        
        
        
        
        
        
        /**
         audiokit IsFormatSampleRateAndChannelCountValid: (hwFormat)
         https://github.com/AudioKit/AudioKit/issues/1767
         */
        AKSettings.disableAVAudioSessionCategoryManagement = false
        
        //        let audioSession = AVAudioSession.sharedInstance()
        //        do {
        //            if #available(iOS 12.0, *) {
        //                try AKSettings.setSession(category: .playAndRecord)
        //            } else { // .iPad4
        //                try audioSession.setCategory(.playAndRecord)
        //            }
        //
        //        } catch {
        //            print("setting category or active state failed")
        //        }
        
        
        
        
        
        AKSettings.sampleRate = AKManager.engine.inputNode.inputFormat(forBus: 0).sampleRate
        mic = AKMicrophone(with: AKManager.engine.inputNode.inputFormat(forBus: 0)) //来自标准输入的音频
        
        
        
        
        
        // AKFrequencyTracker
        tracker = AKFrequencyTracker(mic) //这是基于Miller Puckette最初创建的算法。频率跟踪器
        silence = AKBooster(tracker) //立体声助推器
        silence.gain = 0
        
        // Patching
        let monoToStereo = AKStereoFieldLimiter(mic, amount: 1)
        micMixer = AKMixer(monoToStereo)
        micBooster = AKBooster(micMixer)
        
        // Will set the level of microphone monitoring
        micBooster.gain = 0
        recorder = try? AKNodeRecorder(node: micMixer)
        if let file = recorder.audioFile {
            player = AKPlayer(audioFile: file)
        }
        player.isLooping = true

        moogLadder = AKMoogLadder(player)
        
        
        if let audioFile = try? AKAudioFile(readFileName: "Organ.wav", baseDir: .resources) {
            
            bgPlayer = AKPlayer(audioFile: audioFile)
            bgLadder = AKMoogLadder(bgPlayer)
            
        }
        
        
        // AKMixer
        mainMixer = AKMixer(silence, micBooster, bgLadder, moogLadder)
        
        
        // output
        AKManager.output = mainMixer
        
        
        // start
        do {
            try AKManager.start()
        } catch {
            AKLog("AudioKit did not start!")
        }
        
    }
    
    // 开始显示麦克风的收声频率
    func start() {
        
        startRecord()
        
    }
    
    
    fileprivate var recordFilePath: URL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("SingRecord+\(Date().description).wav")
    
    func startRecord() {
        bgPlayer.play()
        // microphone will be monitored while recording
        // only if headphones are plugged
        if AKSettings.headPhonesPlugged {
            micBooster.gain = 1
        }
        do {
            try recorder.record()
        } catch { AKLog("Errored recording.") }
        
    }
    
    func stopRecord(isReset: Bool, completion: @escaping ((Result<URL, Error>) -> Void)) {
        
        bgPlayer.stop()
        
        let fileName = "SingRecord+\(Date().description).m4a"
                
        
        guard let audioFile = recorder.audioFile else { return }
        // Microphone monitoring is muted
        micBooster.gain = 0
        tape = audioFile
        
        do {
            try player.load(audioFile: tape)
        } catch let err as NSError {
            AKLog(err)
            // Assuming formats match, this should load
            return
        }
        if let _ = player.audioFile?.duration {
            recorder.stop()
            tape.exportAsynchronously(name: fileName,
                                      baseDir: .temp,
                                      exportFormat: .m4a) { [weak self] _, exportError in
                guard let `self` = self else { return }
                
            }
        }
        
        
    }
    
    
    func shutdownAKManager() -> Void {
        do {
            try AKManager.shutdown()
        } catch let error {
            print("-------- AudioKit error", error)
        }
        self.releaseTimerAndObj()
    }
    
    deinit {
        debugPrint("RatingTool 释放")
    }
    
    /// 销毁定时器和部分对象
    func releaseTimerAndObj() {
        if timerRefresh != nil {
            timerRefresh?.invalidate()
            timerRefresh = nil
        }
        tracker = nil
        silence = nil
        micMixer = nil
        recorder = nil
        player = nil
        tape = nil
        micBooster = nil
        moogLadder = nil
        mainMixer = nil
        mic = nil
    }
    
    
    
    
    
    static func getIsHeadphone() -> Bool {
        // 是否耳机模式
        var isMixNeed: Bool {
            return !AVAudioSession.sharedInstance().currentRoute.outputs.compactMap {
                ($0.portType == .bluetoothA2DP ||
                    $0.portType == .bluetoothHFP ||
                    $0.portType == .bluetoothLE ||
                    $0.portType == .headphones ||
                    $0.portType == .headsetMic) ? true : nil
            }.isEmpty
        }
        return isMixNeed
    }
    
}
