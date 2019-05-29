//
//  ViewController.swift
//  SpeechToText
//
//  Created by Indra Permana on 22/05/19.
//  Copyright © 2019 Yusuf Indra. All rights reserved.
//

import UIKit

var words: Array<String> = []
var currentWord: String!

class ViewController: UIViewController, OEEventsObserverDelegate, AVAudioRecorderDelegate, AVAudioPlayerDelegate {
    
    @IBOutlet weak var transcriptTextView: UILabel!
    @IBOutlet weak var recordButton: UIButton!
    
    var slt = Slt()
    var openEarsEventsObserver = OEEventsObserver()
    var fliteController = OEFliteController()
    
    var usingStartingLanguageModel = Bool()
    var startupFailedDueToLackOfPermissions = Bool()
    var restartAttemptsDueToPermissionRequests = Int()
    var pathToFirstDynamicallyGeneratedLanguageModel: String!
    var pathToFirstDynamicallyGeneratedDictionary: String!
    var pathToSecondDynamicallyGeneratedLanguageModel: String!
    var pathToSecondDynamicallyGeneratedDictionary: String!
    var timer: Timer!
    
    var recordingSession: AVAudioSession!
    var audioRecorder: AVAudioRecorder!
    var audioPlayer:AVAudioPlayer!
    var formattedTime = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        
        
    }
    
    func startOpenEars() {
        self.openEarsEventsObserver.delegate = self
        self.restartAttemptsDueToPermissionRequests = 0
        self.startupFailedDueToLackOfPermissions = false
        let languageModelGenerator = OELanguageModelGenerator()
        
        // This is the language model (vocabulary) we're going to start up with. You can replace these words with the words you want to use.
        
        let fillerWords = ["um","uh", "umm","basically", "like", "okay", "well", "hmm","Actually", "Seriously", "So"]
        let firstVocabularyName = "FirstVocabulary"
        
        // languageModelGenerator.verboseLanguageModelGenerator = true // Uncomment me for verbose language model generator debug output to either diagnose your issue or provide information relating to language model generation when asking for help at the forums.
        // OELogging.startOpenEarsLogging() // If you encounter any issues, set this to true to get verbose logging output from OpenEars to either diagnose your issue or provide information when asking for help at the forums.
        // If you encounter any Pocketsphinx-related issues, see below (after OEPocketsphinxController.sharedInstance().setActive() is called) to see how to turn on verbose Pocketsphinx logging to either diagnose your issue or provide information when asking for help at the forums.
        
        
        let firstLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: fillerWords, withFilesNamed: firstVocabularyName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1")) // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to create a language model for Spanish recognition instead of English.
        
        if(firstLanguageModelGenerationError != nil) {
            print("Error while creating initial language model: \(String(describing: firstLanguageModelGenerationError))")
        } else {
            self.pathToFirstDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: firstVocabularyName) // these are convenience methods you can use to reference the file location of a language model that is known to have been created successfully.
            self.pathToFirstDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: firstVocabularyName) // these are convenience methods you can use to reference the file location of a dictionary that is known to have been created successfully.
            self.usingStartingLanguageModel = true // Just keeping track of which model we're using.
            
            // This is a model we will switch to when the user speaks "change model". The last entry, quidnunc, is an example of a word which will not be found in the lookup dictionary and will be passed to the fallback method. The fallback method is slower, so, for instance, creating a new language model from dictionary words will be pretty fast, but a model that has a lot of unusual names in it or invented/rare/recent-slang words will be slower to generate. You can use this information to give your users some UI feedback about what the expectations for wait times should be. However, on modern devices this is not expected to be a multi-second process if the vocabulary is within the supported size of 2000 words or fewer. Using "change model" as all one string in this array gives it a somewhat higher likelihood of being recognized as a phrase.
            
            let secondVocabularyName = "SecondVocabulary"
            
            let secondLanguageArray = ["Sunday",
                                       "Monday",
                                       "Tuesday",
                                       "Wednesday",
                                       "Thursday",
                                       "Friday",
                                       "Saturday",
                                       "quidnunc",
                                       "change model"]
            
            let secondLanguageModelGenerationError: Error! = languageModelGenerator.generateLanguageModel(from: secondLanguageArray, withFilesNamed: secondVocabularyName, forAcousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1")) // Change "AcousticModelEnglish" to "AcousticModelSpanish" in order to create a language model for Spanish recognition instead of English.
            
            if(secondLanguageModelGenerationError != nil) {
                print("Error while creating second language model: \(String(describing: secondLanguageModelGenerationError))")
            } else {
                self.pathToSecondDynamicallyGeneratedLanguageModel = languageModelGenerator.pathToSuccessfullyGeneratedLanguageModel(withRequestedName: secondVocabularyName)  // these are convenience methods you can use to reference the file location of a language model that is known to have been created successfully.
                self.pathToSecondDynamicallyGeneratedDictionary = languageModelGenerator.pathToSuccessfullyGeneratedDictionary(withRequestedName: secondVocabularyName) // these are convenience methods you can use to reference the file location of a dictionary that is known to have been created successfully.
                
                do {
                    try OEPocketsphinxController.sharedInstance().setActive(true) // Setting the shared OEPocketsphinxController active is necessary before any of its properties are accessed.
                }
                catch {
                    print("Error: it wasn't possible to set the shared instance to active: \"\(error)\"")
                }
                
                // OEPocketsphinxController.sharedInstance().verbosePocketSphinx = true // If you encounter any issues, set this to true to get verbose logging output from OEPocketsphinxController to either diagnose your issue or provide information when asking for help at the forums.
                
                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false)
                }
                startDisplayingLevels()
                
                // Here is some UI stuff that has nothing specifically to do with OpenEars implementation
                //                self.startButton.isHidden = true
                //                self.stopButton.isHidden = true
                //                self.suspendListeningButton.isHidden = true
                //                self.resumeListeningButton.isHidden = true
            }
        }
    }

    func pocketsphinxDidReceiveHypothesis(_ hypothesis: String!, recognitionScore: String!, utteranceID: String!) {
        print("Local callback: The received hypothesis is \(hypothesis!) with a score of \(recognitionScore!) and an ID of \(utteranceID!)") // Log it.
        transcriptTextView.text = hypothesis!
        if(hypothesis! == "change model") { // If the user says "change model", we will switch to the alternate model (which happens to be the dynamically generated model).
            
            // Here is an example of language model switching in OpenEars. Deciding on what logical basis to switch models is your responsibility.
            // For instance, when you call a customer service line and get a response tree that takes you through different options depending on what you say to it,
            // the models are being switched as you progress through it so that only relevant choices can be understood. The construction of that logical branching and
            // how to react to it is your job OpenEars just lets you send the signal to switch the language model when you've decided it's the right time to do so.
            
            if(self.usingStartingLanguageModel) { // If we're on the starting model, switch to the dynamically generated one.
                OEPocketsphinxController.sharedInstance().changeLanguageModel(toFile: self.pathToSecondDynamicallyGeneratedLanguageModel, withDictionary:self.pathToSecondDynamicallyGeneratedDictionary)
                self.usingStartingLanguageModel = false
                
            } else { // If we're on the dynamically generated model, switch to the start model (this is an example of a trigger and method for switching models).
                OEPocketsphinxController.sharedInstance().changeLanguageModel(toFile: self.pathToFirstDynamicallyGeneratedLanguageModel, withDictionary:self.pathToFirstDynamicallyGeneratedDictionary)
                self.usingStartingLanguageModel = true
            }
        }
        
//        self.heardTextView.text = "Heard: \"\(hypothesis!)\""
        
        // This is how to use an available instance of OEFliteController. We're going to repeat back the command that we heard with the voice we've chosen.
//        self.fliteController.say(_:"You said \(hypothesis!)", with:self.slt)
    }
    
    // An optional delegate method of OEEventsObserver which informs that the interruption to the audio session ended.
    func audioSessionInterruptionDidEnd() {
        print("Local callback:  AudioSession interruption ended.") // Log it.
//        self.statusTextView.text = "Status: AudioSession interruption ended." // Show it in the status box.
        // We're restarting the previously-stopped listening loop.
        if(!OEPocketsphinxController.sharedInstance().isListening){
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false)
            
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the audio input became unavailable.
    func audioInputDidBecomeUnavailable() {
        print("Local callback:  The audio input has become unavailable") // Log it.
//        self.statusTextView.text = "Status: The audio input has become unavailable" // Show it in the status box.
        
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeUnavailable: \(String(describing: stopListeningError))")
            }
        }
        
        // An optional delegate method of OEEventsObserver which informs that the unavailable audio input became available again.
        func audioInputDidBecomeAvailable() {
            print("Local callback: The audio input is available") // Log it.
//            self.statusTextView.text = "Status: The audio input is available" // Show it in the status box.
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        }
        // An optional delegate method of OEEventsObserver which informs that there was a change to the audio route (e.g. headphones were plugged in or unplugged).
        func audioRouteDidChange(toRoute newRoute: String!) {
            print("Local callback: Audio route change. The new audio route is \(String(describing: newRoute))") // Log it.
//            self.statusTextView.text = "Status: Audio route change. The new audio route is \(newRoute)"// Show it in the status box.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening() // React to it by telling Pocketsphinx to stop listening since there is no available input (but only if we are listening).
            if(stopListeningError != nil) {
                print("Error while stopping listening in audioInputDidBecomeAvailable: \(String(describing: stopListeningError))")
            }
        }
        
        
        
        
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
        }
    }
    
    // An optional delegate method of OEEventsObserver which informs that the Pocketsphinx recognition loop has entered its actual loop.
    // This might be useful in debugging a conflict between another sound class and Pocketsphinx.
    func pocketsphinxRecognitionLoopDidStart() {
        
        print("Local callback: Pocketsphinx started.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx started." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is now listening for speech.
    func pocketsphinxDidStartListening() {
        
        print("Local callback: Pocketsphinx is now listening.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx is now listening." // Show it in the status box.
//
//        self.startButton.isHidden = true // React to it with some UI changes.
//        self.stopButton.isHidden = false
//        self.suspendListeningButton.isHidden = false
//        self.resumeListeningButton.isHidden = true
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected speech and is starting to process it.
    func pocketsphinxDidDetectSpeech() {
        print("Local callback: Pocketsphinx has detected speech.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx has detected speech." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx detected a second of silence, indicating the end of an utterance.
    // This was added because developers requested being able to time the recognition speed without the speech time. The processing time is the time between
    // this method being called and the hypothesis being returned.
    func pocketsphinxDidDetectFinishedSpeech() {
        print("Local callback: Pocketsphinx has detected a second of silence, concluding an utterance.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx has detected finished speech." // Show it in the status box.
    }
    
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx has exited its recognition loop, most
    // likely in response to the OEPocketsphinxController being told to stop listening via the stopListening method.
    func pocketsphinxDidStopListening() {
        print("Local callback: Pocketsphinx has stopped listening.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx has stopped listening." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop but it is not
    // Going to react to speech until listening is resumed.  This can happen as a result of Flite speech being
    // in progress on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to suspend recognition via the suspendRecognition method.
    func pocketsphinxDidSuspendRecognition() {
        print("Local callback: Pocketsphinx has suspended recognition.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx has suspended recognition." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Pocketsphinx is still in its listening loop and after recognition
    // having been suspended it is now resuming.  This can happen as a result of Flite speech completing
    // on an audio route that doesn't support simultaneous Flite speech and Pocketsphinx recognition,
    // or as a result of the OEPocketsphinxController being told to resume recognition via the resumeRecognition method.
    func pocketsphinxDidResumeRecognition() {
        print("Local callback: Pocketsphinx has resumed recognition.") // Log it.
//        self.statusTextView.text = "Status: Pocketsphinx has resumed recognition." // Show it in the status box.
    }
    
    // An optional delegate method which informs that Pocketsphinx switched over to a new language model at the given URL in the course of
    // recognition. This does not imply that it is a valid file or that recognition will be successful using the file.
    func pocketsphinxDidChangeLanguageModel(toFile newLanguageModelPathAsString: String!, andDictionary newDictionaryPathAsString: String!) {
        
        print("Local callback: Pocketsphinx is now using the following language model: \n\(newLanguageModelPathAsString!) and the following dictionary: \(newDictionaryPathAsString!)")
    }
    
    // An optional delegate method of OEEventsObserver which informs that Flite is speaking, most likely to be useful if debugging a
    // complex interaction between sound classes. You don't have to do anything yourself in order to prevent Pocketsphinx from listening to Flite talk and trying to recognize the speech.
    func fliteDidStartSpeaking() {
        print("Local callback: Flite has started speaking") // Log it.
//        self.statusTextView.text = "Status: Flite has started speaking." // Show it in the status box.
    }
    
    // An optional delegate method of OEEventsObserver which informs that Flite is finished speaking, most likely to be useful if debugging a
    // complex interaction between sound classes.
    func fliteDidFinishSpeaking() {
        print("Local callback: Flite has finished speaking") // Log it.
//        self.statusTextView.text = "Status: Flite has finished speaking." // Show it in the status box.
    }
    
    func pocketSphinxContinuousSetupDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Setting up the continuous recognition loop has failed for the reason \(String(describing: reasonForFailure)), please turn on OELogging.startOpenEarsLogging() to learn more.") // Log it.
//        self.statusTextView.text = "Status: Not possible to start recognition loop." // Show it in the status box.
    }
    
    func pocketSphinxContinuousTeardownDidFail(withReason reasonForFailure: String!) { // This can let you know that something went wrong with the recognition loop startup. Turn on [OELogging startOpenEarsLogging] to learn why.
        print("Local callback: Tearing down the continuous recognition loop has failed for the reason %, please turn on [OELogging startOpenEarsLogging] to learn more.", reasonForFailure) // Log it.
//        self.statusTextView.text = "Status: Not possible to cleanly end recognition loop." // Show it in the status box.
    }
    
    func testRecognitionCompleted() { // A test file which was submitted for direct recognition via the audio driver is done.
        print("Local callback: A test file which was submitted for direct recognition via the audio driver is done.") // Log it.
        if(OEPocketsphinxController.sharedInstance().isListening) { // If we're listening, stop listening.
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in testRecognitionCompleted: \(String(describing: stopListeningError))")
            }
        }
        
    }
    /** Pocketsphinx couldn't start because it has no mic permissions (will only be returned on iOS7 or later).*/
    func pocketsphinxFailedNoMicPermissions() {
        print("Local callback: The user has never set mic permissions or denied permission to this app's mic, so listening will not start.")
        self.startupFailedDueToLackOfPermissions = true
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(String(describing: stopListeningError)). Will try again in 10 seconds.")
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(10), execute: {
            if(!OEPocketsphinxController.sharedInstance().isListening) {
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
            }
        })
    }
    
    /** The user prompt to get mic permissions, or a check of the mic permissions, has completed with a true or a false result  (will only be returned on iOS7 or later).*/
    
    func micPermissionCheckCompleted(withResult: Bool) {
        if(withResult) {
            
            self.restartAttemptsDueToPermissionRequests += 1
            if(self.restartAttemptsDueToPermissionRequests == 1 && self.startupFailedDueToLackOfPermissions) { // If we get here because there was an attempt to start which failed due to lack of permissions, and now permissions have been requested and they returned true, we restart exactly once with the new permissions.
                
                if(!OEPocketsphinxController.sharedInstance().isListening) {
                    OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
                }
                
                self.startupFailedDueToLackOfPermissions = false
            }
        }
        
    }
    
    
    
    // This is not OpenEars-specific stuff, just some UI behavior
    
    @IBAction func suspendListeningButtonAction() { // This is the action for the button which suspends listening without ending the recognition loop
        
        
        OEPocketsphinxController.sharedInstance().suspendRecognition()
        
//        self.startButton.isHidden = true
//        self.stopButton.isHidden = false
//        self.suspendListeningButton.isHidden = true
//        self.resumeListeningButton.isHidden = false
    }
    
    @IBAction func resumeListeningButtonAction() { // This is the action for the button which resumes listening if it has been suspended
        OEPocketsphinxController.sharedInstance().resumeRecognition()
        
//        self.startButton.isHidden = true
//        self.stopButton.isHidden = false
//        self.suspendListeningButton.isHidden = false
//        self.resumeListeningButton.isHidden = true
    }
    
    @IBAction func stopButtonAction() { // This is the action for the button which shuts down the recognition loop.
        if(OEPocketsphinxController.sharedInstance().isListening){
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(String(describing: stopListeningError))")
            }
        }
//        self.startButton.isHidden = false
//        self.stopButton.isHidden = true
//        self.suspendListeningButton.isHidden = true
//        self.resumeListeningButton.isHidden = true
    }
    
    @IBAction func startButtonAction() { // This is the action for the button which starts up the recognition loop again if it has been shut down.
        
//        self.startButton.isHidden = true
//        self.stopButton.isHidden = false
//        self.suspendListeningButton.isHidden = false
//        self.resumeListeningButton.isHidden = true
    }
    
    
    // What follows are not OpenEars methods, just an approach for level reading
    // that I've included with this sample app. My example implementation does make use of two OpenEars
    // methods:    the pocketsphinxInputLevel method of OEPocketsphinxController and the fliteOutputLevel
    // method of OEFliteController.
    //
    // The example is meant to show one way that you can read those levels continuously without locking the UI,
    // by using an NSTimer, but the OpenEars level-reading methods
    // themselves do not include multithreading code since I believe that you will want to design your own
    // code approaches for level display that are tightly-integrated with your interaction design and the
    // graphics API you choose.
    //
    // Please note that if you use my sample approach, you should pay attention to the way that the timer is always stopped in
    // dealloc. This should prevent you from having any difficulties with deallocating a class due to a running NSTimer process.
    
    func startDisplayingLevels() { // Start displaying the levels using a timer
        if(self.timer != nil) {
            self.timer.invalidate()
        }
        // start the timer
        self.timer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(updateLevelsUI), userInfo: nil, repeats: true)
        
    }
    
    
    
    @objc func updateLevelsUI() { // And here is how we obtain the levels.  This method includes the actual OpenEars methods and uses their results to update the UI of this view controller.
        
//        self.pocketsphinxDbLabel.text = "Pocketsphinx Input level: \(OEPocketsphinxController.sharedInstance().pocketsphinxInputLevel)"//pocketsphinxInputLevel is an OpenEars method of the class OEPocketsphinxController.
        
        if(self.fliteController.speechInProgress) {
//            self.fliteDbLabel.text = "Flite Output level: \(self.fliteController.fliteOutputLevel)" // fliteOutputLevel is an OpenEars method of the class OEFliteController.
        }
    }
    
    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func getFileURLForRecord() -> URL {
        let currentDateTime = Date()
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "ddMMyyyy-HHmmss"
        formattedTime = dateFormatter.string(from: currentDateTime)
        print("record name = recording-\(formattedTime).m4a")
        let path = getDocumentsDirectory().appendingPathComponent("recording-\(formattedTime).m4a")
        return path as URL
    }
    
    func startRecording() {
        let audioFilename = getFileURLForRecord()
        let settings = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 12000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder.delegate = self
            audioRecorder.record()
//            recordButton.setTitle("Tap to Stop", for: .normal)
//            playButton.isEnabled = false
        } catch {
            finishRecording(success: false)
        }
    }
    
    func finishRecording(success: Bool) {
        audioRecorder.stop()
        audioRecorder = nil
        if success {
//            recordButton.setTitle("Tap to Re-record", for: .normal)
        } else {
//            recordButton.setTitle("Tap to Record", for: .normal)
            // recording failed :(
        }
//        playButton.isEnabled = true
        recordButton.isEnabled = true
    }
    
//    func preparePlayer() {
//        var error: Error?
//        do {
//            audioPlayer = try AVAudioPlayer(contentsOf: getFileURL() as URL)
//        } catch let error1 as Error {
//            error = error1
//            audioPlayer = nil
//        }
//        if let err = error {
//            print("AVAudioPlayer error: \(err.localizedDescription)")
//        } else {
//            audioPlayer.delegate = self
//            audioPlayer.prepareToPlay()
//            audioPlayer.volume = 10.0
//        }
//    }
    
    func setupView() {
        recordingSession = AVAudioSession.sharedInstance()
        do {
            try recordingSession.setCategory(.playAndRecord, mode: .default)
            try recordingSession.setActive(true)
            recordingSession.requestRecordPermission() { [] allowed in
                DispatchQueue.main.async {
                    if allowed {
                        
                    } else {
                        // failed to record
                    }}}
        } catch { // failed to record }
        }
    }
    
    @IBAction func startRecord(_ sender: Any) {
        if(!OEPocketsphinxController.sharedInstance().isListening) {
            if audioRecorder == nil {
                startRecording()
                OEPocketsphinxController.sharedInstance().startListeningWithLanguageModel(atPath: self.pathToFirstDynamicallyGeneratedLanguageModel, dictionaryAtPath: self.pathToFirstDynamicallyGeneratedDictionary, acousticModelAtPath: OEAcousticModel.path(toModel: "AcousticModelAlternateEnglish1"), languageModelIsJSGF: false) // Start speech recognition, but only if we aren't already listening.
                
                startOpenEars()
            }
        }
        else if(OEPocketsphinxController.sharedInstance().isListening) || audioRecorder != nil{
            finishRecording(success: true)
            let stopListeningError: Error! = OEPocketsphinxController.sharedInstance().stopListening()
            if(stopListeningError != nil) {
                print("Error while stopping listening in pocketsphinxFailedNoMicPermissions: \(String(describing: stopListeningError))")
            }
        }
    }
    
    
    //MARK: Delegates
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag {
            finishRecording(success: false)
        }
    }
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        print("Error while recording audio \(error!.localizedDescription)")
    }
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        recordButton.isEnabled = true
//        playButton.setTitle("Play", for: .normal)
    }
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        print("Error while playing audio \(error!.localizedDescription)")
    }
    
}

