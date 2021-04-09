//
//  ContentView.swift
//  SwiftUI-Audio
//
//  Created by Max Cobb on 25/03/2021.
//

import SwiftUI
import AgoraRtmKit
import AgoraRtcKit

struct ContentView: View {
    @State var joinedChannel: Bool = false
    @ObservedObject var agoraObservable = AgoraObservable()
    var body: some View {
        Form {
            Section(header: Text("Channel Information")) {
                TextField(
                    "Channel Name", text: $agoraObservable.channelName
                ).disabled(joinedChannel)
                TextField(
                    "Username", text: $agoraObservable.username
                ).disabled(joinedChannel)
            }
            Button(action: {
                joinedChannel.toggle()
                if !joinedChannel {
                    self.agoraObservable.members.removeAll()
                    self.agoraObservable.rtckit.leaveChannel()
                    self.agoraObservable.rtmkit?.logout()
                    self.agoraObservable.rtmIsLoggedIn = false
                } else {
                    self.agoraObservable.joinChannel()
                }
            }, label: {
                Text("\(joinedChannel ? "Leave" : "Join") Channel")
                    .accentColor(joinedChannel ? .red : .blue)
            })
            if joinedChannel {
                Section(header: Text("Members")) {
                    List(agoraObservable.members, id: \.self) { Text($0) }
                }
            }
        }
    }
}

struct UserData: Codable {
    var rtmId: String
    var rtcId: UInt
    var username: String
    func toJSONString() throws -> String? {
        let jsonData = try JSONEncoder().encode(self)
        return String(data: jsonData, encoding: .utf8)
    }
}

class AgoraObservable: NSObject, ObservableObject {
    @Published var channelName: String = ""
    @Published var username: String = ""
    @Published var members: [String] = []
    @Published var membersLookup: [String: (rtcId: UInt, username: String)] = [:] {
        didSet {
            members = self.membersLookup.values.compactMap {
                $0.username + (
                    $0.rtcId == self.rtcId ? " (Me)" : ""
                )
            }
        }
    }

    var rtcId: UInt = 0
    var rtmId = UUID().uuidString
    var channel: AgoraRtmChannel?
    var rtmIsLoggedIn = false

    lazy var rtckit: AgoraRtcEngineKit = {
        let engine = AgoraRtcEngineKit.sharedEngine(
            withAppId: <#Agora App ID#>, delegate: nil
        )
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.broadcaster)
        return engine
    }()

    lazy var rtmkit: AgoraRtmKit? = {
        let rtm = AgoraRtmKit(
            appId: <#Agora App ID#>, delegate: self
        )
        return rtm
    }()
}
extension AgoraObservable {
    func joinChannel() {
        if !self.rtmIsLoggedIn {
            rtmkit?.login(byToken: nil, user: self.rtmId) { rtmLoggedIn in
                self.rtmIsLoggedIn = true
                self.joinChannel()
            }
            return
        }
        self.rtckit.joinChannel(byToken: nil, channelId: self.channelName, info: nil, uid: self.rtcId) { (channel, uid, errCode) in
            self.rtcId = uid
            self.channel = self.rtmkit?.createChannel(withId: self.channelName, delegate: self)
            self.channel?.join(completion: { joinStatus in
                if joinStatus == .channelErrorOk {
                    let user = UserData(rtmId: self.rtmId, rtcId: self.rtcId, username: self.username)
                    guard let jsonString = try? user.toJSONString() else {
                        return
                    }
                    self.membersLookup[user.rtmId] = (user.rtcId, user.username)
                    self.channel?.send(AgoraRtmMessage(text: jsonString))
                } else {
                    self.channel = nil
                }
            })
        }
    }
    func sendUsername(to member: AgoraRtmMember) {
        let user = UserData(rtmId: self.rtmId, rtcId: self.rtcId, username: self.username)
        guard let jsonString = try? user.toJSONString() else {
            return
        }
        self.rtmkit?.send(AgoraRtmMessage(text: jsonString), toPeer: member.userId)
   }
}

extension AgoraObservable: AgoraRtmChannelDelegate, AgoraRtmDelegate {
    func channel(_ channel: AgoraRtmChannel, memberJoined member: AgoraRtmMember) {
        self.sendUsername(to: member)
    }

    func channel(_ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage, from member: AgoraRtmMember) {
        parseMemberData(from: message.text)
    }
    func rtmKit(_ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage, fromPeer peerId: String) {
        parseMemberData(from: message.text)
    }

    func parseMemberData(from text: String) {
        guard let textData = text.data(using: .utf8),
              let decodedUserData = try? JSONDecoder().decode(UserData.self, from: textData)
        else {
            return
        }
        membersLookup[decodedUserData.rtmId] = (decodedUserData.rtcId, decodedUserData.username)
    }
    func channel(_ channel: AgoraRtmChannel, memberLeft member: AgoraRtmMember) {
        membersLookup.removeValue(forKey: member.userId)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().preferredColorScheme(.dark)
    }
}
