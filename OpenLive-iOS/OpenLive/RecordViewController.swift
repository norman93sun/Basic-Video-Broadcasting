//
//  RecordViewController.swift
//  OpenLive
//
//  Created by Norman on 2021/7/20.
//  Copyright © 2021 Agora. All rights reserved.
//

import UIKit
import AVFoundation

class RecordViewController: UIViewController, AVAudioRecorderDelegate {


    let recordingSession = AVAudioSession.sharedInstance()
    
        
    var tool: RatingTool?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            if #available(iOS 10.0, *) {
                try recordingSession.setCategory(.playAndRecord, mode: .default)
            } else {
                // Fallback on earlier versions
            }
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { _ in
              
            }
        } catch {
            // failed to record!
        }
        
        tool = RatingTool()
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        tool?.shutdownAKManager()
    }
    

    @IBAction func doStartRecord(_ sender: Any) {
        
//        let playItem = AVPlayerItem(url: URL(string: "https://oss.vipsing.com/audio/ZGNKpG_1624513707150.mp3")!)

              
        tool?.start()
    
        
    }
    
    @IBAction func doStopRecord(_ sender: Any) {

        tool?.stopRecord(isReset: false, completion: { _ in

        })
    }
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("------ successfully \(flag)")
    }
    
}
