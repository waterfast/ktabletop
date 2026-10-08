import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.formcard as FormCard
import org.kde.kirigamiaddons.labs.components as KirigamiComponents

import org.kde.ktabletop

FormCard.FormCardPage {
    id: root

    title: i18nc("@title:window", "Appearance")

    FormCard.FormHeader {
        title: i18nc("@title:group", "General")
    }
    FormCard.FormCard {
        Loader {
            id: colorSchemeDelegate
            visible: item !== null
            sourceComponent: Qt.createComponent('org.kde.ktabletop.settings', 'ColorScheme')
            Layout.fillWidth: true
        }
    }

}
