# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

qt_add_library(ktabletop_qml STATIC)
ecm_add_qml_module(ktabletop_qml
    URI org.kde.ktabletop
    GENERATE_PLUGIN_SOURCE
    QML_FILES
        Main.qml
        LobbyPage.qml
        CreateRoomDialog.qml
        BusyDialog.qml
    SOURCES
        qml-backend.cpp
        lua-event-listener.cpp
        observable-manager.cpp
    DEPENDENCIES
        # org.kde.kirigamiaddons.formcard
        org.kde.kirigami
)

target_link_libraries(ktabletop_qml PUBLIC
    Qt6::Quick
    KF6::I18n
    KF6::CoreAddons
    KF6::ConfigGui
)

target_include_directories(ktabletop_qml PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_BINARY_DIR}
)
