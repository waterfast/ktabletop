// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.AbstractCard {
    id: root

    property var player
    property bool isSelf: false
    property bool turnActive: false
    property int turnDuration: 0
    property real timeLeft: 1
    property double deadline: 0

    function restartTimer() {
        if (root.turnActive && root.turnDuration > 0) {
            root.deadline = Date.now() + root.turnDuration * 1000;
            root.timeLeft = 1;
            ticker.restart();
        } else {
            ticker.stop();
            root.timeLeft = 1;
        }
    }

    onTurnActiveChanged: root.restartTimer()
    onTurnDurationChanged: root.restartTimer()

    Timer {
        id: ticker
        interval: 100
        repeat: true
        onTriggered: {
            const total = root.turnDuration * 1000;
            if (total <= 0) {
                root.timeLeft = 0;
                return;
            }
            root.timeLeft = Math.max(0, Math.min(1, (root.deadline - Date.now()) / total));
        }
    }

    contentItem: RowLayout {
        spacing: Kirigami.Units.mediumSpacing

        Kirigami.Icon {
            Layout.preferredWidth: Kirigami.Units.iconSizes.medium
            Layout.preferredHeight: Kirigami.Units.iconSizes.medium
            source: "im-user"
        }

        QQC2.Label {
            Layout.fillWidth: true
            text: root.player ? root.player.username : i18n("Unknown")
            elide: Text.ElideRight
            font.bold: root.isSelf
        }

        Kirigami.Badge {
            visible: root.isSelf
            text: i18n("You")
        }

        Kirigami.Badge {
            visible: root.player && root.player.role !== ""
            text: root.player && root.player.role === "white" ? i18n("White") : i18n("Black")
            customColor: root.player && root.player.role === "white" ? Kirigami.Theme.backgroundColor : Kirigami.Theme.textColor
            customTextColor: root.player && root.player.role === "white" ? Kirigami.Theme.textColor : Kirigami.Theme.backgroundColor
        }
    }

    // TODO: looks bad?
    QQC2.ProgressBar {
        anchors.left: root.left
        anchors.right: root.right
        anchors.bottom: root.bottom
        anchors.bottomMargin: -root.bottomPadding
        visible: root.turnActive && root.turnDuration > 0
        from: 0
        to: 1
        value: root.timeLeft
    }
}
