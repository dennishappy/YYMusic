//
//  PlayerManager.swift
//  YYMusic
//
//  Created by 王浩 on 2020/5/14.
//  Copyright © 2020 haoge. All rights reserved.
//

import UIKit
import AVFoundation
import MediaPlayer
import HWPanModal

//@objc protocol PlayMusicDelegate {
//    /**切换歌曲*/
//    @objc func playMusicChange(_ mode: Int, object: Any?)
//}

enum PlayMode: Int {
    //默认
    case none = 0
    //下一首
    case next = 1
    //前一首
    case previous = 2
    //播放
    case play = 3
    //暂停
    case pause = 4
    //自动下一首/循环/随机
    case auto = 5
    //继续播放
    case goOn = 6
}

//播放状态
enum PlayerCycle: Int {
    /**单曲循环*/
    case single = 0
    /**顺序播放*/
    case order = 1
    /**随机播放*/
    case random = 2
}

class PlayerManager: NSObject {
    static let shared = PlayerManager()
    //播放模式
    var playMode: PlayMode = .none
    /*存放歌曲数组*/
    var musicArray: [MusicModel] = []
    /*播放下标, 默认从第一首开始*/
    var index: Int = 0
    /*标记是不是没点列表直接点了播放按钮如果是就默认播放按钮*/
    var isFristPlayerPauseBtn: Bool = true
    /*是不是正在播放*/
    var isPlaying: Bool = false
    /*播放器*/
    var player: AVPlayer!
    var currentPlayerItem: AVPlayerItem! {
        didSet{
            if currentPlayerItem != nil {
                currentPlayerItem.addObserver(self, forKeyPath: "status", options: .new, context: nil)
            }
        }
    }
    /*播放模式*/
    var cycle: PlayerCycle = .order {
        didSet{
            UserDefaultsManager.shared.userDefaultsSet(object: cycle.rawValue, key: CYCLE)
        }
    }
    /**获取当前播放的歌曲*/
    var currentModel: MusicModel?
    {
        get {
            if musicArray.count > 0 {
                return musicArray[index]
            }
            return nil
        }
    }
    
    /**播放时间监听*/
    fileprivate var timeObserve: Any?
    fileprivate var isFirstTime: Bool = true
    
    override init() {
        super.init()
        
        //获取播放模式
        if let c = UserDefaultsManager.shared.userDefaultsGet(key: CYCLE) as? Int {
            self.cycle = PlayerCycle(rawValue: c) ?? .order
        }
        
        if player == nil {
            player = AVPlayer()
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback)
            try? session.setActive(true, options: [])
        }
        
        //播放完毕的通知
        NotificationCenter.addObserver(observer: self, selector: #selector(playerItemDidPlayToEndTime(_:)), name: Notification.Name.AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        //耳机插入和拔掉通知
        NotificationCenter.addObserver(observer: self, selector: #selector(audioRouteChangeListener(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        
    }

    //MARK:-播放完毕通知
    @objc fileprivate func playerItemDidPlayToEndTime(_ notification: Notification) {
        print("播放完毕========>\(currentModel?.title ?? "")歌曲")
        autoPlay()
    }
    
    //MARK:-耳机操作通知
    @objc fileprivate func audioRouteChangeListener(_ notification: Notification) {
        let info = notification.userInfo
        if let routeChangeReason = info?[AVAudioSessionRouteChangeReasonKey] as? AVAudioSession.RouteChangeReason {
            switch routeChangeReason {
            case .newDeviceAvailable:
                print("插入耳机========>\(currentModel?.title ?? "")歌曲")
                self.playerPlay()
            case .oldDeviceUnavailable:
                print("拔掉耳机========>\(currentModel?.title ?? "")歌曲")
                self.playerPause()
            default:
                break
            }
        }
    }
    
    //MARK:- 存储歌曲时缺少Index,重新设置index
    func resetIndex(model: MusicModel?) {
        for (index,m) in self.musicArray.enumerated() {
            if m.trackId == model?.trackId {
                PlayerManager.shared.index = index
            }
        }
    }
    
    //MARK:- 当前时间
    func getCurrentTime() -> String? {
        //获取当前时间
        let value = self.player.currentTime().value
        let timescale = self.player.currentTime().timescale
        if self.player.currentTime().timescale > 0  {
            let currentTime = value/Int64(timescale)
            return "\(currentTime)"
        }
        return nil
    }
    
    //MARK:- 总时长
    func getTotalTime() -> String? {
        //获取音乐总时长
        let d = self.player.currentItem?.duration.value
        let t = self.player.currentItem?.duration.timescale
        if self.player.currentItem?.duration.timescale != 0 {
            let totalTime = d!/Int64(t!)
            return "\(totalTime)"
        }
        
        return nil
    }
    
    //MARK:- 播放状态
    func playerStatus() -> Int {
        if currentPlayerItem.status == .readyToPlay {
            return 1
        } else {
            return 0
        }
    }

    //MARK:- 播放
    func playerPlay() {
        player.play()
        isPlaying = true
        NotificationCenter.post(name: .kReloadPlayStatus, object: isPlaying)
    }
    
    //MARK:- 暂停
    func playerPause() {
        player.pause()
        isPlaying = false
        NotificationCenter.post(name: .kReloadPlayStatus, object: isPlaying)
    }
    
    //MARK:- 播放歌曲
    func playMusic(model: MusicModel?) {
        self.playReplaceItem(with: model)
    }
    
    //MARK:- 自动下一首/循环/随机
    func autoPlay() {
        if PlayerManager.shared.cycle == .single {
            //单曲循环播放
            self.playReplaceItem(with: PlayerManager.shared.currentModel)
        } else {
            //下一首
            self.playNext()
        }
    }
    
    //MARK:- 前一首
    func playPrevious() {
        if self.index == 0 {
            self.index = self.musicArray.count - 1
        } else {
            self.index -= 1
        }
        self.playReplaceItem(with: self.currentModel)
    }
    
    //MARK:- 下一首
    func playNext() {
        if self.index == self.musicArray.count - 1 {
            self.index = 0
        } else {
            self.index += 1
        }
        self.playReplaceItem(with: self.currentModel)
    }
  
    //MARK:-喜欢
    func hasBeenFavoriteMusic() -> Bool {
        return true
    }
    
    //MARK:-音量控制
    func playerVolume(with volumeFloat: CGFloat) {
        self.player.volume = Float(volumeFloat)
    }

    //MARK:- 播放进度
    func playerProgress(with progress: Double, completionHandler: ((CMTime) -> Void)? = nil) {
        var progress = progress
        if self.isPlaying {
            // 将进度转换成播放时间（不能直接将进度条快进到播放结束）
            if (progress == CMTimeGetSeconds(self.player.currentItem!.duration)) {
                progress -= 0.5
            }
        }
        let time = CMTimeMakeWithSeconds(progress, preferredTimescale: Int32(NSEC_PER_SEC))
        self.player.seek(to: time, toleranceBefore: CMTime.zero, toleranceAfter: CMTime.zero) { (finished) in
            if finished {
                completionHandler?(time)
            }
        }
    }
    
    //MARK:- 自动/切换播放
    fileprivate func playReplaceItem(with model: MusicModel?) {
        //每次播放重置index
        resetIndex(model: model)
        //播放的url
        let url = URL(string: model?.playUrl32 ?? "")
        currentPlayerItem = AVPlayerItem(url: url!)
        self.player.replaceCurrentItem(with: currentPlayerItem)
        //调用播放
        self.playerPlay()

        //监听音乐的时间变化
        addMusicTimeMake()
        
        //通知页面模型改变
        NotificationCenter.post(name: .kMusicChange, object: model)
        //存储当前播放的歌曲
        UserDefaultsManager.shared.archiver(object: (model)!, key: CURRENTMUSIC)
    }
    
    //MARK:- 展示音乐播放界面
    func presentPlayController(vc: UIViewController?, model: MusicModel?) {
        let playVC = MainPlayViewController(nibName: "MainPlayViewController", bundle: nil)
        playVC.model = model
//        vc?.presentPanModal(playVC)
        playVC.modalPresentationStyle = .fullScreen
        vc?.present(playVC, animated: true, completion: nil)
    }

    //MARK:- 监听音乐时间变化
    func addMusicTimeMake() {
        var tempTime: Float64?
        let cmt = CMTime(value: CMTimeValue(1.0), timescale: CMTimeScale(1.0))
        timeObserve = player.addPeriodicTimeObserver(forInterval: cmt, queue: DispatchQueue.main) { [weak self](time) in
            //过滤重复的时间
            let ct = CMTimeGetSeconds(time)
            if ct == tempTime {
                return
            }
            tempTime = ct
            if let duration = self?.player.currentItem?.duration {
                let tt = CMTimeGetSeconds(duration)
                if ct == tt {
                    self?.autoPlay()
                }
                NotificationCenter.post(name: .kMusicTimeInterval, object: [ct,tt])
            }
            //控制中心,锁屏时候展示(在这里会导致主线程卡顿)
//            self?.updateLockedScreenMusic()
        }
    }

    //MARK:- 清空播放器监听属性
    func releasePlayer() {
        self.removeObserver(self, forKeyPath: "status")
        NotificationCenter.default.removeObserver(self)
        self.currentPlayerItem = nil
        self.player = nil
    }
    //MARK:- KVO监听播放状态
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let item = object as? AVPlayerItem {
            if keyPath == "status" {
                print("当前播放状态=====>\(item.status.rawValue)")
                if item.status == .readyToPlay {
                    //存储歌曲总时间
                    if let t = self.getTotalTime(), (Int(t) ?? 0) > 0{
                        UserDefaultsManager.shared.userDefaultsSet(object: "\(t)", key: TOTALTIME)
                    }
                }
            }
        }
    }
    
    //MARK:-锁屏时候的设置，效果需要在真机上才可以看到
    func updateLockedScreenMusic() {
        //开辟子线程监控锁屏
        if PlayerManager.shared.musicArray.count > 0 {
            let model = PlayerManager.shared.musicArray[PlayerManager.shared.index]
            var info = [String: Any]()
            // 设置持续时间（歌曲的总时间）
            info[MPMediaItemPropertyPlaybackDuration] = self.player.currentItem?.duration.value
            // 设置当前播放进度
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = self.player.currentItem?.currentTime().value
            //设置歌曲名
            info[MPMediaItemPropertyTitle] = model.title ?? ""
            //设置演唱者
            info[MPMediaItemPropertyArtist] = model.nickname ?? ""
            //歌手头像
            if let url = (model.coverLarge ?? "").addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
                if let data = try? Data(contentsOf: URL(string: url)!) {
                    let artwork = MPMediaItemArtwork.init(boundsSize: CGSize(width: 400, height: 400)) { (size) -> UIImage in
                        return UIImage(data: data)!
                    }
                    info[MPMediaItemPropertyArtwork] = artwork
                }
            }
            //进度光标的速度（这个随 自己的播放速率调整，我默认是原速播放）
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }
}
