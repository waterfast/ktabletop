# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

qt_add_library(ktabletop_qml STATIC)
ecm_add_qml_module(ktabletop_qml
    URI org.kde.ktabletop
    GENERATE_PLUGIN_SOURCE
    QML_FILES
        qml/Main.qml
    DEPENDENCIES
        org.kde.kirigamiaddons.formcard
        org.kde.kirigamiaddons.statefulapp
        org.kde.kirigami
        org.kde.kapp4mymulti.settings
)
target_link_libraries(ktabletop_qml PUBLIC
    Qt6::Quick
    KF6::I18n
    KF6::CoreAddons
    KF6::ConfigGui
    KirigamiAddonsStatefulApp
)

target_include_directories(ktabletop_qml PUBLIC ${CMAKE_BINARY_DIR})

add_executable(ktabletop-app
    c-wrapper.cpp
    lua-binding.cpp

    main.cpp
)
target_link_libraries(ktabletop-app PUBLIC
    Qt6::Quick
    KF6::I18n
    KF6::CoreAddons
    KF6::ConfigGui
    Qt::Widgets
    KF6::I18nQml
    KirigamiApp

    ktabletop_qml
    ktabletop_qmlplugin

    ${LUA_LIBRARIES}
)
