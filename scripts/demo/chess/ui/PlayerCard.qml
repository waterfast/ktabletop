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
}
