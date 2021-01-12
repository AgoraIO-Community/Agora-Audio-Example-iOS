//
//  AgoraAudioViewController+TableView.swift
//  Agora-Audio-Example-iOS
//
//  Created by Max Cobb on 11/01/2021.
//

import UIKit

extension AgoraAudioViewController: UITableViewDelegate, UITableViewDataSource {

    func createSpeakerTable() {
        let newTable = UITableView()
        self.view.addSubview(newTable)
        newTable.frame = self.view.bounds
        newTable.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        newTable.delegate = self
        newTable.dataSource = self
        newTable.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        self.speakerTable = newTable
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? self.activeSpeakers.count : self.activeAudience.count
    }

    func numberOfSections(in tableView: UITableView) -> Int { 2 }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        ["Speakers", "Audience"][section]
    }

    func tableView(
        _ tableView: UITableView, cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

        let cellUserID = Array(
            indexPath.section == 0 ? self.activeSpeakers : self.activeAudience
        )[indexPath.row]

        cell.textLabel?.text = self.usernameLookups[cellUserID]
        return cell
    }
}
