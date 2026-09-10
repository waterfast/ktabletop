// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.ktabletop

Kirigami.Dialog {
    id: root

    required property LuaObject d

    title: "Create Room"
    standardButtons: Kirigami.Dialog.Ok | Kirigami.Dialog.Cancel
    padding: Kirigami.Units.largeSpacing

    Kirigami.FormLayout {
        QQC2.TextField {
            id: nameField
            Kirigami.FormData.label: "Room name"
            text: `${d.username}'s room`
            onTextChanged: d.invoke("updateName", [text])
        }

        QQC2.SpinBox {
            id: capacitySpin
            from: 2
            to: 8
            value: 2
            Layout.fillWidth: true
            Kirigami.FormData.label: "Players:"
            onValueChanged: d.invoke("updateCapacity", [value])
        }
    }
}
