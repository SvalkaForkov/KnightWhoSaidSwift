//
//  KWSGameViewController.swift
//  KnightWhoSaidSwift
//
//  Created by Marcin Pędzimąż on 17.09.2014.
//  Copyright (c) 2014 Marcin Pedzimaz. All rights reserved.
//

import UIKit
import SpriteKit

class KWSGameViewController: UIViewController, KWSBlueToothLEDelegate,KWSPlayerDelegate {
    
    private var communicationInterface : KWSBluetoothLEInterface?
    private var gameButtons = [UIButton]()
    
    private weak var gameScene : KWSGameScene!
    private var isServer : Bool = false
    private var continueLoop : Bool = false
    
    @IBOutlet weak var becomeServerButton: UIButton!
    @IBOutlet weak var becomeClientButton: UIButton!
    
    @IBOutlet weak var moveLeftButton: UIButton!
    @IBOutlet weak var moveRightButton: UIButton!
    @IBOutlet weak var jumpButton: UIButton!
    @IBOutlet weak var guardButton: UIButton!
    @IBOutlet weak var attackButton: UIButton!
    @IBOutlet weak var restartButton: UIButton!

    override func viewWillAppear(animated: Bool) {
        
        super.viewWillAppear(animated)
    
        for button in self.gameButtons {
        
            button.alpha = 0.0
        }
    }

    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.sharedApplication().idleTimerDisabled = true
    }
    
    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        
        UIApplication.sharedApplication().idleTimerDisabled = false
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.moveLeftButton.transform = CGAffineTransformMakeRotation(CGFloat(M_PI))
        
        let classString = NSStringFromClass(KWSGameScene)
        let realClassName = classString.componentsSeparatedByString(".")[1]
        
        if let scene = KWSGameScene.unarchiveFromFile(realClassName) as? KWSGameScene {
            
            let skView = self.view as! SKView
        
            skView.ignoresSiblingOrder = true
            skView.shouldCullNonVisibleNodes = true
            
            skView.showsFPS = true
            skView.showsNodeCount = true
            
            scene.scaleMode = .AspectFill
            
            skView.presentScene(scene)
            
            self.gameScene = scene
        }
        
        self.gameButtons.append(self.moveLeftButton)
        self.gameButtons.append(self.moveRightButton)
        self.gameButtons.append(self.jumpButton)
        self.gameButtons.append(self.guardButton)
        self.gameButtons.append(self.attackButton)
    }
    
    func closeAndChangeMusic() {
    
        self.navigationController?.popViewControllerAnimated(true)
        
        let gameAudio = KWSGameAudioManager.sharedInstance
            gameAudio.playMusic(musicName: "Menu")
            gameAudio.setMusicVolume(volume: 0.3)
    
    }
    
    @IBAction func popGameController(sender: UIButton) {
        
        closeAndChangeMusic()
        
        guard let _ = self.communicationInterface else {
        
            return
        }
        
        self.communicationInterface!.sendCommand(command: .Disconnect, data: nil)
    }
    
    @IBAction func becomeServerPress(sender: UIButton) {
        
        self.setupGameLogic(true)
    }
    
    @IBAction func becomeClientPress(sender: UIButton) {
        
        self.setupGameLogic(false)
    }
    
    func setupGameLogic(becomeServer:Bool) {
    
        self.isServer = becomeServer
        
        if self.isServer {
            
            self.communicationInterface = KWSBluetoothLEServer(ownerController: self, delegate: self)
        }
        else {
            
            self.communicationInterface = KWSBluetoothLEClient(ownerController: self, delegate: self)
        }
        
        self.showGameButtons()
        
        let playerA = self.gameScene.players[1]
        let playerB = self.gameScene.players[0]
        
        self.gameScene.selectedPlayer = self.isServer ? playerA : playerB
        self.gameScene.otherPlayer = self.isServer ? playerB : playerA
        self.gameScene.otherPlayer!.externalControl = true;
        
        self.gameScene.selectedPlayer!.delegate = self
        self.gameScene.otherPlayer!.delegate = self
    }
    
    func showGameButtons() {
    
        UIView.animateWithDuration(kKWSAnimationDuration, animations: { () -> Void in
        
            self.becomeClientButton.alpha = 0.0
            self.becomeServerButton.alpha = 0.0
            
            for button in self.gameButtons {
                
                button.alpha = 1.0
                //comment this line to play without connecting
                //button.userInteractionEnabled = false
            }
        })
    }
    
    deinit {
    
        continueLoop = false
    }
    

    //MARK: LE interface delegate
    
    func interfaceDidUpdate(interface interface: KWSBluetoothLEInterface, command: KWSPacketType, data: NSData?)
    {
        
        switch( command ) {
        
        case .Connect:
            
            for button in self.gameButtons {
                
                button.userInteractionEnabled = true
            }
            
            continueLoop = true
            heartBeat()
            
        case .HearBeat:
            
            if let data = data {
                
                let subData : NSData = data.subdataWithRange(NSMakeRange(0, sizeof(syncPacket)))
                let packetMemory = UnsafePointer<syncPacket>(subData.bytes)
                let packet = packetMemory.memory
                
                self.gameScene.otherPlayer!.healt = packet.healt
                self.gameScene.otherPlayer!.applyDamage(0)
                
                let decoded = Float16CompressorDecompress(packet.posx)
                let realPos = self.gameScene.otherPlayer!.position
                let position = CGPointMake(CGFloat(decoded), CGFloat(realPos.y))
                
                self.gameScene.otherPlayer!.position = position
            }
            
        case .Attack:
            self.gameScene.otherPlayer!.playerAttack()
            self.gameScene.otherPlayer!.collidedWith(self.gameScene.selectedPlayer!)
        
        case .DefenseDown:
            self.gameScene.otherPlayer!.defenseButtonActive = true
            self.gameScene.otherPlayer!.playerDefense()
        
        case .DefenseUp:
            self.gameScene.otherPlayer!.defenseButtonActive = false
        
        case .Jump:
            self.gameScene.otherPlayer!.playerJump()

        case .MoveDown:
            
            if let data = data {
            
                self.gameScene.otherPlayer!.moveButtonActive = true
                
                let body : NSData = data.subdataWithRange(NSMakeRange(0, sizeof(Bool)))
                let value : UnsafePointer<Bool> = UnsafePointer<Bool>(body.bytes)
                let direction : Bool = value.memory
                
                if direction {
                
                    self.gameScene.otherPlayer!.playerMoveLeft()
                
                } else {
                
                    self.gameScene.otherPlayer!.playerMoveRight()
                }
            }
            
        case .MoveUp:
            self.gameScene.otherPlayer!.moveButtonActive = false
            
        case .Disconnect:
            
            continueLoop = false
            
            let KWSAlertController = UIAlertController( title: NSLocalizedString("Error", comment: ""),
                                                      message: NSLocalizedString("Other player has been disconnect", comment: ""),
                                               preferredStyle: .Alert)
            
            let okAction = UIAlertAction(title: NSLocalizedString("OK", comment: ""),
                                         style: .Cancel,
                                       handler: { (action: UIAlertAction) -> Void in
                    
                                            self.closeAndChangeMusic()
                                        })
            
            KWSAlertController.addAction(okAction)
            
            self.presentViewController(KWSAlertController, animated: true, completion: nil)
            
        case .Restart:
            
            self.unlockControls()
            
        case .GameEnd:
            
            self.lockControls()
        
        }
    }
    
    func lockControls() {
    
        UIView.animateWithDuration(kKWSAnimationDuration, animations: { () -> Void in
            
            self.restartButton.alpha = 1.0
            
            for button in self.gameButtons {
                
                button.alpha = 0.0
            }
        })
    }
    
    func unlockControls() {
    
        self.gameScene.selectedPlayer!.resetPlayer()
        self.gameScene.otherPlayer!.resetPlayer()
        
        UIView.animateWithDuration(kKWSAnimationDuration, animations: { () -> Void in
            
            self.restartButton.alpha = 0.0
            
            for button in self.gameButtons {
                
                button.alpha = 1.0
            }
        })
    }
    
    //MARK: player delegate

    func playerDidDied() {
        
        print("player died.")
    
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        self.communicationInterface!.sendCommand(command: .GameEnd, data: nil)
     
        //reset menu etc.
        self.lockControls()
    }
    
    func heartBeat() {

        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        var packet = syncPacket()
            packet.healt = currentPlayer!.healt
            packet.posx = Float16CompressorCompress(Float32(currentPlayer!.position.x))
        
        let packetData = NSData(bytes: &packet, length: sizeof(syncPacket))
        
        self.communicationInterface!.sendCommand(command: .HearBeat, data: packetData)
        
        if continueLoop {
        
            let runAfter : dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(kKWSPacketRoonLoopTime * Double(NSEC_PER_SEC)))
            
            dispatch_after(runAfter, dispatch_get_main_queue()) { () -> Void in
                
                self.heartBeat()
            }
        }
    }
    
    @IBAction func restartButtonPress(sender: UIButton) {
        
        
        let runAfter : dispatch_time_t = dispatch_time(DISPATCH_TIME_NOW, Int64(1.0 * Double(NSEC_PER_SEC)))
        
        dispatch_after(runAfter, dispatch_get_main_queue()) { () -> Void in
            
            guard let _ = self.communicationInterface else {
                
                return
            }
            
            self.communicationInterface!.sendCommand(command: .Restart, data: nil)
        }
        
        self.unlockControls()
    }
    
    //MARK: player sterring
    
    @IBAction func pressLeftButton(sender: UIButton) {
        
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer

        currentPlayer!.moveButtonActive = true
        currentPlayer!.playerMoveLeft()

        let directionData = NSData(bytes: &currentPlayer!.movingLeft, length: sizeof(Bool))
        self.communicationInterface!.sendCommand(command: .MoveDown, data: directionData)
    }
    
    @IBAction func pressRightButton(sender: UIButton) {

        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.moveButtonActive = true
        currentPlayer!.playerMoveRight()
        
        let directionData = NSData(bytes: &currentPlayer!.movingLeft, length: sizeof(Bool))
        self.communicationInterface!.sendCommand(command: .MoveDown, data: directionData)
    }
    
    @IBAction func unpressLeftButton(sender: UIButton) {
        
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.moveButtonActive = false

        self.communicationInterface!.sendCommand(command: .MoveUp, data: nil)
    }
    
    @IBAction func unpressRightButton(sender: UIButton) {
        
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.moveButtonActive = false
        
        self.communicationInterface!.sendCommand(command: .MoveUp, data: nil)
    }
    
    @IBAction func pressAttackButton(sender: UIButton) {
        
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.playerAttack()
        currentPlayer!.collidedWith(self.gameScene.otherPlayer!)
        
        self.communicationInterface!.sendCommand(command: .Attack, data: nil)
    }
    
    @IBAction func pressDefenseButton(sender: UIButton) {

        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.defenseButtonActive = true
        currentPlayer!.playerDefense()

        self.communicationInterface!.sendCommand(command: .DefenseDown, data: nil)
    }
    
    @IBAction func unpressDefenseButton(sender: UIButton){
    
        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.defenseButtonActive = false

        self.communicationInterface!.sendCommand(command: .DefenseUp, data: nil)
    }
    
    @IBAction func pressJumpButton(sender: UIButton) {

        guard let _ = self.communicationInterface else {
            
            return
        }
        
        let currentPlayer = self.gameScene.selectedPlayer
        
        currentPlayer!.playerJump()

        self.communicationInterface!.sendCommand(command: .Jump, data: nil)
    }
    
}
