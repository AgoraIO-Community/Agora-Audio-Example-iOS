//
//  AgoraAudioViewController+AgoraDelegates.swift
//  Agora-Audio-Example-iOS
//
//  Created by Max Cobb on 12/01/2021.
//

import AgoraRtcKit
import AgoraRtmKit

extension AgoraAudioViewController: AgoraRtcEngineDelegate {
    func rtcEngine(
        _ engine: AgoraRtcEngineKit,
        remoteAudioStateChangedOfUid uid: UInt, state: AgoraAudioRemoteState,
        reason: AgoraAudioRemoteStateReason, elapsed: Int
    ) {
        switch state {
        case .decoding, .starting:
            self.activeAudience.remove(uid)
            self.activeSpeakers.insert(uid)
        case .stopped, .failed:
            self.activeSpeakers.remove(uid)
        default:
            return
        }
        self.speakerTable?.reloadData()
    }

    func rtcEngine(
        _ engine: AgoraRtcEngineKit,
        reportAudioVolumeIndicationOfSpeakers speakers: [AgoraRtcAudioVolumeInfo],
        totalVolume: Int
    ) {
        for speaker in speakers {
            print("\(speaker.uid): \(Float(speaker.volume) / Float(totalVolume))")
        }
    }
}

extension AgoraAudioViewController: AgoraRtmDelegate, AgoraRtmChannelDelegate {
    func channel(_ channel: AgoraRtmChannel, memberJoined member: AgoraRtmMember) {
        if self.userID != 0 {
            self.shareUserID(to: member.userId)
        }
    }
    func channel(_ channel: AgoraRtmChannel, memberLeft member: AgoraRtmMember) {
        guard let uid = self.usernameLookups.first(where: { (keyval) -> Bool in
            keyval.value == member.userId
        })?.key else {
            print("Could not find member \(member.userId)")
            return
        }
        self.activeAudience.remove(uid)
        self.activeSpeakers.remove(uid)
        self.usernameLookups.removeValue(forKey: uid)
        self.speakerTable?.reloadData()
    }
    func channel(
        _ channel: AgoraRtmChannel,
        messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember
    ) {
        self.newMessage(message.text, from: member.userId)
    }
    func rtmKit(
        _ kit: AgoraRtmKit,
        messageReceived message: AgoraRtmMessage, fromPeer peerId: String
    ) {
        self.newMessage(message.text, from: peerId)
    }
    /// New message from peer
    /// - Parameters:
    ///   - message: Message text, containing the user's RTC id.
    ///   - username: Username of the user who send the message
    func newMessage(_ message: String, from username: String) {
        if let uidMessage = UInt(message) {
            usernameLookups[uidMessage] = username
            // If we haven't seen this userID yet, add them to the audience
            if !self.activeAudience.union(self.activeSpeakers).contains(uidMessage) {
                self.activeAudience.insert(uidMessage)
            }
            self.speakerTable?.reloadData()
        }
    }
}
