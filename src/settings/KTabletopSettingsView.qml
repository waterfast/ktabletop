pragma Singleton

import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kirigamiaddons.settings as KirigamiSettings

KirigamiSettings.ConfigurationView {
    id: root

    modules: [
        KirigamiSettings.ConfigurationModule {
            moduleId: "appearance"
            text: i18n("Appearance")
            icon.name: "preferences-desktop-theme-global-symbolic"
            page: () => Qt.createComponent("org.kde.ktabletop.settings", "AppearanceSettingsPage")
        },
        KirigamiSettings.ConfigurationModule {
            moduleId: "aboutKTabletop"
            text: i18n("About KTabletop")
            icon.name: "help-about-symbolic"
            page: () => Qt.createComponent("org.kde.kirigamiaddons.formcard", "AboutPage")
        },
        KirigamiSettings.ConfigurationModule {
            moduleId: "aboutKDE"
            text: i18n("About KDE")
            icon.name: "kde-symbolic"
            page: () => Qt.createComponent("org.kde.kirigamiaddons.formcard", "AboutKDEPage")
        }
    ]
}
