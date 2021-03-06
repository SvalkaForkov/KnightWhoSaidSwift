//
//  GameViewController.swift
//  KnightWhoSaidSwift
//
//  Created by Marcin Pędzimąż on 27.08.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import SpriteKit

let kDebugOption : Bool = false

class KWSMainMenuViewController: UIViewController, UIPopoverPresentationControllerDelegate{

    let kKWSSettingsSegueIdentifier : String! = "kKWSSettingsSegueIdentifier"
    let kKWSPlayGameSegueIdentifier : String! = "kKWSPlayGameSegueIdentifier"
    
    weak var gameAudio : KWSGameAudioManager?

    override func viewDidLoad() {
        super.viewDidLoad()

        let classString = NSStringFromClass(KWSMainMenuScene)
        let realClassName = classString.componentsSeparatedByString(".")[1]
        
        if let scene = KWSMainMenuScene.unarchiveFromFile(realClassName) as? KWSMainMenuScene {
          
            let skView = self.view as! SKView
            
            if kDebugOption {
        
                skView.showsFPS = true
                skView.showsNodeCount = true
            }
        
            skView.ignoresSiblingOrder = true
            skView.shouldCullNonVisibleNodes = true
            
            scene.scaleMode = .AspectFill
            
            skView.presentScene(scene)
        }
        
        self.gameAudio = KWSGameAudioManager.sharedInstance
        
        if let gameAudio = self.gameAudio {
            
            gameAudio.playMusic(musicName: "Menu")
            gameAudio.setMusicVolume(volume: 0.3)
        }
    }

    @IBAction func didPressMenuButton(sender: AnyObject) {
        
        if let gameAudio = self.gameAudio {
            
            gameAudio.playClickButtonSound()
        }
    }

    override func shouldAutorotate() -> Bool {
        
        return true
    }

    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        
       return UIInterfaceOrientationMask.Landscape
    }

    override func didReceiveMemoryWarning() {
        
        super.didReceiveMemoryWarning()
    }

    override func prefersStatusBarHidden() -> Bool {
        
        return true
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        
        if kKWSPlayGameSegueIdentifier == segue.identifier {
        
            let runAfter : dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(0.5 * Double(NSEC_PER_SEC)))
            
            dispatch_after(runAfter, dispatch_get_main_queue()) { () -> Void in
                
                
                if let gameAudio = self.gameAudio {
                
                    gameAudio.playMusic(musicName: "Level")
                    gameAudio.setMusicVolume(volume: 0.3)
                }
            }
        }
    }

}
