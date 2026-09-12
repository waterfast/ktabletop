// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami

Kirigami.Dialog {
    id: root

    title: i18n("Promotion")
    property string pieceColor: "white"
    property string promotionResult: "Q"

    RowLayout {
        spacing: Kirigami.Units.smallSpacing

        Repeater {
            model: [
                { key: "Q", name: "queen" },
                { key: "R", name: "rook" },
                { key: "B", name: "bishop" },
                { key: "N", name: "knight" }
            ]

            delegate: QQC2.Button {
                required property var modelData

                icon.source: Qt.resolvedUrl("../assets/image/" + root.pieceColor + "_" + modelData.name + ".svg")
                icon.width: 48
                icon.height: 48

                onClicked: {
                    root.promotionResult = modelData.key;
                    root.accept();
                }
            }
        }
    }
}
