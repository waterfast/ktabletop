// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigami.controls as KControls
import org.kde.kirigami.layouts as KL

import org.kde.ktabletop

Kirigami.ApplicationWindow {
    id: root

    pageStack {
        columnView.columnResizeMode: KL.ColumnView.SingleColumn
        globalToolBar {
            style: Kirigami.ApplicationHeaderStyle.ToolBar
            showNavigationButtons: pageStack.currentIndex > 0 || pageStack.layers.depth > 1 ? Kirigami.ApplicationHeaderStyle.ShowBackButton : 0
        }
    }

    pageStack.initialPage: Kirigami.Page {
        title: "KTabletop"
        ColumnLayout {
            anchors.centerIn: parent
            QQC2.Button {
                Layout.fillWidth: true
                text: "Single Player"
                onClicked: {
                    console.log("Single Player clicked")
                    Backend.startServer(17943);
                    Backend.joinServer("127.0.0.1");
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                text: "Multiple Players"
                onClicked: {
                }
            }

            QQC2.Button {
                Layout.fillWidth: true
                text: "Quit"
                onClicked: Qt.exit(0)
            }
        }
    }

    Component {
        id: lobbyPageComponent
        LobbyPage {}
    }

    Component.onCompleted: {
    }
}
