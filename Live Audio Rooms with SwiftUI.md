# Creating Live Audio Chat Rooms with SwiftUI

Live audio rooms are becoming popular this year, especially with applications for live music performances and other live broadcasts.

In this tutorial, we'll go through how to build an app using the Agora Audio SDK, where users can drop into an audio channel with SwiftUI. Using Agora RTM, we will also create a list showing who else is in the channel with us.

## Prerequisites

- An Agora developer account (see[ How to Get Started with Agora](https://www.agora.io/en/blog/how-to-get-started-with-agora?utm_source=medium&utm_medium=blog&utm_campaign=audio-channels-swiftui))
- Xcode 11.0 or later
- An iOS device with minimum iOS 13.0
- A basic understanding of iOS development

## Setup

Create a SwiftUI iOS project in Xcode, and then install the Audio and RTM SDK Swift Packages by adding these two packages to your project:

- [github.com/AgoraIO/AgoraRtm_iOS](https://github.com/AgoraIO/AgoraRtm_iOS)
- [github.com/AgoraIO/AgoraAudio_iOS](https://github.com/AgoraIO/AgoraAudio_iOS)

You must add microphone permissions to the app's Info.plist. To do so, add `NSMicrophoneUsageDescription` to Info.plist with a brief description of your reason for needing the microphone. I have added: “So the other members can hear you.”



![Screenshot 2021-04-09 at 11.26.31](/Users/maxcobb/Library/Application Support/typora-user-images/Screenshot 2021-04-09 at 11.26.31.png)

## Laying Out the UI

For the initial UI we want three basic UI elements:

- Text input for channel name
- Text input for username
- Join Channel button

This form can be split into two sections: one for the inputs and the other for the Join Channel button:

```swift
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
        }
    }
}
```

![swiftui-audio-channel](/Users/maxcobb/Downloads/swiftui-audio-channel.png)

In the above snippet, the `AgoraObservable` is an `ObservableObject` that we will use to handle the RTM delegate callbacks and everything else to do with connecting to Agora.

Once we tap the Join Channel button, the label will be switched to "Leave Channel" and the tint changed from blue to red.

Let's create the `AgoraObservable` class now to see what needs to be done there:

```swift
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
            withAppId: <#my-app-id#>, delegate: nil
        )
        engine.setChannelProfile(.liveBroadcasting)
        engine.setClientRole(.broadcaster)
        return engine
    }()

    lazy var rtmkit: AgoraRtmKit? = {
        let rtm = AgoraRtmKit(
            appId: <#my-app-id#>, delegate: self
        )
        rtm.login(
            byToken: nil, user: self.rtmId
        ) { rtmLoggedIn in
            self.rtmIsLoggedIn = true
        }
        return rtm
    }()
}

extension AgoraObservable: AgoraRtmDelegate {
  ...
}
```

As we can see, channelName and username are the strings used inside the two text fields in the main view. The members and membersLookup properties will be used to store the usernames of all the members in our channel, which we will display later. The initial rtcId is set to 0, which tells the RTC engine to give us a random ID once we join a channel, and the rtmId is assigned a random UUID string.

The RTC engine is initialised with a live broadcasting channel profile, and the client role is set to broadcaster.

The RTM engine is initialised with the delegate being the AgoraObservable object itself. The RTM delegate will be used to read messages directly sent to us in the RTM network. The `AgoraRtmDelegate` extension will be covered later. A call to log in the RTM client is also called.

## Joining the Channel

The `joinChannel` method needs to join two different channels: the real-time audio channel and the real-time messaging channel.

When joining the real-time messaging channel, we need to tell all the other members what our RTC ID is, so we will first connect to the audio channel, which gives us that ID.

To join the RTC channel, we can call:

```swift
self.rtckit.joinChannel(
  byToken: nil, channelId: self.channelName, info: nil, uid: self.rtcId
) { (channel, uid, errCode) in
   self.rtcId = uid
}
```

> In this example, for the sake of simplicity we are not using tokens. If you are building an Agora application that is for production purposes, then you must generate a token using a token server.

Once we have recorded the RTC user ID we can progress to joining the RTM channel.

We must first be logged in to Agora RTM before creating a channel. We must first check that we are logged in with the rtmIsLoggedIn property of AgoraObservable. If we are not yet logged in, we can either wait for the logic to complete, or attempt to login again with `rtmkit.login(byToken:,user:)`.

Once logged in, we can create and join the RTM channel of our chosen channel name:

```swift
self.channel = self.rtmkit?.createChannel(
  withId: self.channelName, delegate: self
)
self.channel?.join(completion: { joinStatus in
  if joinStatus == .channelErrorOk {
    // we have joined the channel
  }
})
```

> The delegate here is set to `self`, which is the AgoraObservable. For this to work, you will need to apply the AgoraRtmChannelDelegate protocol to this class.

Now that you are connected to an Agora RTC channel, you can hear others in the channel, and they can hear you. The RTM channel is also connected but not yet used.

## Sharing Usernames

After logging in to both the RTM and the RTC channels, we now need to share our username with others and receive usernames from other members of the same channel.

Three values need to be shared:

- The RTC user ID, which is a UInt
- The RTM user ID, which is a randomly generated UUID string
- The username, input by the user on the main screen

To send these values over RTM, it must be encoded as a String from one device and then decoded on the receiving device. The Swift language has something built in to do this: the Codable protocol.

Let's define a basic struct that inherits the Codable protocol:

```swift
struct UserData: Codable {
    var rtmId: String
    var rtcId: UInt
    var username: String
}
```

This data struct can now be encoded, as can all the member types (String and UInt are also Codable). RTM accepts a string message, so let's encode to a JSON string using JSONEncoder:

```swift
extension UserData {
  func toJSONString() throws -> String? {
    let jsonData = try JSONEncoder().encode(self)
    return String(data: jsonData, encoding: .utf8)
  }
}
```
Thus, after joining the RTM channel, we can create the UserData object, use toJsonString to get the encoded string and then send it to the channel:

```swift
let user = UserData(
  rtmId: self.rtmId, rtcId: self.rtcId, username: self.username
)
guard let jsonString = try? user.toJSONString() else {
  return
}
self.channel?.send(AgoraRtmMessage(text: jsonString))
```

We also need to record our own username in membersLookup:

```swift
self.membersLookup[user.rtmId] = (user.rtcId, user.username)
```

At this point, we are now joining the RTM channel and the RTC channel, and also sending our user data across to everyone else in the channel. The entire joinChannel method should look like this:

https://gist.github.com/maxxfrazer/2c47c34c3645e60c8bf1bbcdf204fd1d

<script src="https://gist.github.com/maxxfrazer/2c47c34c3645e60c8bf1bbcdf204fd1d.js"></script>

We'll cover receiving usernames soon, but first we need to share our usernames with newcomers to the channel. To do so, we will need to use the `AgoraRtmChannelDelegate` method `channel(_:memberJoined:)` to know when and where to send our data:

```swift
extension AgoraObservable: AgoraRtmChannelDelegate {
  func channel(_ channel: AgoraRtmChannel, memberJoined member: AgoraRtmMember) {
    self.sendUsername(to: member)
  }
}
```

The sendUsername method needs to once again encode our user data, but this time to send it to a specific user rather than to the entire channel. Now that the toJSONString method is already defined, this is a fairly simple task:

```swift
extension AgoraObservable {
  func sendUsername(to member: AgoraRtmMember) {
    let user = UserData(
      rtmId: self.rtmId, rtcId: self.rtcId, username: self.username
    )
    guard let jsonString = try? user.toJSONString() else {
      return
    }
    self.rtmkit?.send(AgoraRtmMessage(text: jsonString), toPeer: member.userId)
  }
}
```

All set. Now we need to catch the incoming user data to then be able to get everyone's usernames in one place.

Because some usernames are sent to the entire channel and others are sent directly to users, we need to use two different delegate methods: one from `AgoraRtmChannelDelegate` and the other from `AgoraRtmDelegate`. Those methods are `channel(_:messageReceived:from:)` and `rtmKit(_:message:fromPeer:)`, respectively:

```swift
extension AgoraObservable {
  func channel(
    _ channel: AgoraRtmChannel, messageReceived message: AgoraRtmMessage,
    from member: AgoraRtmMember
  ) {
    self.parseMemberData(from: message.text)
  }

  func rtmKit(
    _ kit: AgoraRtmKit, messageReceived message: AgoraRtmMessage,
    fromPeer peerId: String
  ) {
    self.parseMemberData(from: message.text)
  }
}
```

To parse the member data, we can once again use the fact that the incoming data is a string of encoded JSON, coming from the UserData struct type, and then save the data in the `membersLookup` property as before:

```swift
extension AgoraObservable {
  func parseMemberData(from text: String) {
    guard let textData = text.data(using: .utf8),
    let userData = try? JSONDecoder().decode(
      UserData.self, from: textData
    ) else {
      return
    }
    membersLookup[userData.rtmId] = (userData.rtcId, userData.username)
  }
}
```

The final part of this section is removing a user from the data once they leave the channel. This is the simplest part because all we have to do is catch the memberLeft delegate method and remove the RTM ID from membersLookup when this happens:

```swift
extension AgoraObservable {
  func channel(_ channel: AgoraRtmChannel, memberLeft member: AgoraRtmMember) {
    membersLookup.removeValue(forKey: member.userId)
  }
}
```

Now we have a way to reference any user that is in the channel with us. And as can be seen earlier, every time the membersLookup property is updated we extract all the usernames and put them into a String array. We can use this array to display the usernames in the next section.

## Displaying Usernames

Displaying a list of values with SwiftUI is very straightforward once you have correctly set up your properties. In our case, the list of usernames we want to display is saved in a Published value (members), which is contained in an ObservedObject (agoraObservable).

Let's add a section to the ContentView, with a header of "Members", which creates a list from this array and displays them as a Text label:

```swift
Section(header: Text("Members")) {
  List(agoraObservable.members, id: \.self) { Text($0) }
}
```

That's all there is to it with SwiftUI! One additional thing would be to wrap the members section inside an if statement, this way the section displays only when we are in a channel. The entire ContentView struct should now look like this:

https://gist.github.com/maxxfrazer/6f9a76d75e042f7b4ce23783489dd1ba

<script src="https://gist.github.com/maxxfrazer/6f9a76d75e042f7b4ce23783489dd1ba.js"></script>

Now when you join a channel with a few people in it, you'll see a view that looks similar to this:

![swiftui-audio-channel-joined](/Users/maxcobb/Downloads/swiftui-audio-channel-joined.png)

---

That's it! You now have a fully working audio streaming application built with SwiftUI and with Agora as the back end.

## Testing

To see the full example project, go to this repository and explore the project in the directory `SwiftUI-Example`:

https://github.com/AgoraIO-Community/Agora-Audio-Example-iOS

## Conclusion

Now you can see how to make a basic Audio chat room application with SwiftUI and Agora.

I hope you found this tutorial useful. You can check out the blog for more posts on creating this kind of application with UIKit, Android, web, and more.

## Other Resources

For more information about building applications using Agora.io SDKs, take a look at the [Agora Video Call Quickstart Guide](https://docs.agora.io/en/Video/start_call_ios?platform=iOS&utm_source=medium&utm_medium=blog&utm_campaign=audio-channels-swiftui) and [Agora API Reference](https://docs.agora.io/en/Video/API Reference/oc/docs/headers/Agora-Objective-C-API-Overview.html?utm_source=medium&utm_medium=blog&utm_campaign=audio-channels-swiftui).

I also invite you to [join the Agora.io Developer Slack community](http://bit.ly/2IWexJQ).

