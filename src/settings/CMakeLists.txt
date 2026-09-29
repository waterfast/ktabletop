qt_add_library(ktabletop_settings STATIC)

set_source_files_properties(
    KTabletopSettingsView.qml
    PROPERTIES
        QT_QML_SINGLETON_TYPE TRUE
)

qt_add_qml_module(ktabletop_settings
    URI org.kde.ktabletop.settings
    # GENERATE_PLUGIN_SOURCE
    QML_FILES
        KTabletopSettingsView.qml
)
