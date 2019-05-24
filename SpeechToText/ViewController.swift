//
//  ViewController.swift
//  SpeechToText
//
//  Created by Indra Permana on 22/05/19.
//  Copyright © 2019 Yusuf Indra. All rights reserved.
//

import UIKit
import Speech

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    
    @IBOutlet weak var transcriptTextView: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    lazy var audioEngine: AVAudioEngine = {
        let audioEngine = AVAudioEngine()
        return audioEngine
    }()
    
    lazy var speechRecognizer: SFSpeechRecognizer? = {
        if let recognizer = SFSpeechRecognizer(locale: Locale.init(identifier: "id-ID")) {
            recognizer.delegate = self
            return recognizer
        }
        else { return nil }
    }()
    
    var request: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
    }


    @IBAction func startRecord(_ sender: Any) {
        if audioEngine.isRunning {
            audioEngine.stop()
            request?.endAudio()
            recordButton.isEnabled = true
        } else {
            recordButton.isEnabled = false
            try! recordAndRecognizeSpeech()
        }
    }
    
    func recordAndRecognizeSpeech() throws {
        
        // Cancel the previous task if it's running
        if let recognitionTask = self.recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
        
        // Create a new audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(AVAudioSession.Category.record)
            try audioSession.setMode(AVAudioSession.Mode.measurement)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            print (error)
        }
        
        // Create a new live recognition request
        request = SFSpeechAudioBufferRecognitionRequest()
        
        let node = audioEngine.inputNode
        guard let request = self.request else {
            fatalError()
        }
        request.shouldReportPartialResults = true
        request.contextualStrings = ["um", "uhm", "uh", "eh", "ah", "o0h", "Stark" ]
        recognitionTask = speechRecognizer?.recognitionTask(with: request, resultHandler: { result, error in
            
            var isFinal = false
            
            // When the recognizer returns a result, we pass it to
            // the linguistic tagger to analyze its content.
            if let result = result {
                let bestString = result.bestTranscription
                self.transcriptTextView.text = bestString.formattedString
                
                print(bestString)
                
                
                isFinal = result.isFinal
            }
            if error != nil || isFinal {
                self.audioEngine.stop()
                node.removeTap(onBus: 0)
                
                self.request = nil
                self.recognitionTask = nil
            }
        })
        
        
        let recordingFormat = node.outputFormat(forBus: 0)
        node.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat ) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in self.request?.append(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            return print(error)
        }
        guard let myRecognizer = SFSpeechRecognizer() else {
            return
        }
        if !myRecognizer.isAvailable {
            return
        }
    }
}

