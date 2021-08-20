//
//  ViewController.swift
//  Agora-Audio-Example-iOS
//
//  Created by Max Cobb on 08/01/2021.
//

import UIKit

import AgoraRtcKit

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.placeFields()

        // Tapping on background hides keyboard
        let tap = UITapGestureRecognizer(target: self, action: #selector(UIInputViewController.dismissKeyboard))
        self.view.addGestureRecognizer(tap)
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }

    static var appID: String = <#App ID#>

    @objc func joinChannel() {
        let channel = self.channelField.text ?? ""
        let username = self.usernameField.text ?? ""
        let role: AgoraClientRole = self.toggleRole.selectedSegmentIndex == 0 ?
            .audience : .broadcaster
        if channel.isEmpty || username.isEmpty {
            return
        }
        let agoraAVC = AgoraAudioViewController(
            appId: ViewController.appID, token: nil,
            channel: channel, username: username, role: role
        )
        agoraAVC.presentationController?.delegate = self
        self.present(agoraAVC, animated: true)
    }

    // MARK: - UI Elements

    lazy var channelField: UITextField = {
        let textf = UITextField()
        textf.placeholder = "channel-name"
        textf.borderStyle = .roundedRect
        return textf
    }()
    lazy var usernameField: UITextField = {
        let textf = UITextField()
        textf.placeholder = "username"
        textf.borderStyle = .roundedRect
        textf.textContentType = .username
        return textf
    }()
    let segmentItems = ["audience", "broadcaster"]
    lazy var toggleRole: UISegmentedControl = {
        let seg = UISegmentedControl(items: self.segmentItems)
        seg.selectedSegmentIndex = 0
        return seg
    }()
    lazy var submitButton: UIButton = {
        let btn = UIButton(type: .roundedRect)
        btn.setTitle("Join", for: .normal)
        btn.addTarget(self, action: #selector(joinChannel), for: .touchUpInside)
        return btn
    }()
    func placeFields() {
        [self.channelField, self.usernameField, self.toggleRole, self.submitButton]
            .enumerated().forEach { (idx, field) in
            self.view.addSubview(field)
            field.frame = CGRect(
                origin: CGPoint(
                    x: 25,
                    y: Int(self.view.safeAreaInsets.top) + 50 + idx * 55),
                size: CGSize(width: self.view.bounds.width - 50, height: 50)
            )
            field.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        }
    }
}

extension ViewController: UIAdaptivePresentationControllerDelegate {
    func presentationControllerWillDismiss(_ presentationController: UIPresentationController) {
        guard let videoViewer = (
                presentationController.presentedViewController as? AgoraAudioViewController
        ) else {
            return
        }
        videoViewer.disconnect()
    }
}
