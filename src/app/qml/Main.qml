// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.ApplicationWindow {
    width: 240
    height: 400
    ColumnLayout {
        anchors.centerIn: parent
        QQC2.Button {
            Layout.fillWidth: true
            text: "Single Player"
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Multiple Players"
        }

        QQC2.Button {
            Layout.fillWidth: true
            text: "Quit"
            onClicked: Qt.exit(0)
        }
    }

    Component.onCompleted: {
        console.log(Backend);
    }
}
