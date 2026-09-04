# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

cmake_minimum_required(VERSION 3.24)

project(KTabletop VERSION 0.0.1)

set(QT6_MIN_VERSION 6.10.0)
set(KF6_MIN_VERSION 6.22.0)
set(KIRIGAMI_ADDONS_MIN_VERSION 1.8.0)

set(LUA_EXACT_VERSION 5.5)
set(GIT2_MIN_VERSION 1.9.0)

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)

set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH} ${ECM_MODULE_PATH})

include(FeatureSummary)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

include(ECMSetupVersion)
include(ECMFindQmlModule)
include(ECMQmlModule)
include(ECMAddAndroidApk)

if (NOT ANDROID)
    include(KDEGitCommitHooks)
    include(KDEClangFormat)
endif()

set(QT_EXTRA_COMPONENTS)
if (NOT ANDROID)
    list(APPEND QT_EXTRA_COMPONENTS Widgets)
endif()

find_package(Lua ${LUA_EXACT_VERSION} REQUIRED EXACT)
find_package(OpenSSL REQUIRED)
find_package(LibGit2 ${GIT2_MIN_VERSION} REQUIRED)
find_package(spdlog REQUIRED)

find_package(Qt6 ${QT6_MIN_VERSION} REQUIRED COMPONENTS Qml ${QT_EXTRA_COMPONENTS})
find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS Kirigami CoreAddons Config I18n)

find_package(KF6KirigamiAddons ${KIRIGAMI_ADDONS_MIN_VERSION} REQUIRED)
set_package_properties(KF6KirigamiAddons PROPERTIES
    TYPE REQUIRED
    PURPOSE "Required application components and runtime dependency"
)

ecm_find_qmlmodule(org.kde.kirigamiaddons.formcard)

add_subdirectory(src)

# install(FILES org.kde.kapp4.desktop DESTINATION ${KDE_INSTALL_APPDIR})
# install(FILES org.kde.kapp4.metainfo.xml DESTINATION ${KDE_INSTALL_METAINFODIR})
# ki18n_install(po)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

if (NOT ANDROID)
    file(GLOB_RECURSE ALL_CLANG_FORMAT_SOURCE_FILES src/*.cpp src/*.h)
    kde_clang_format(${ALL_CLANG_FORMAT_SOURCE_FILES})
    kde_configure_git_pre_commit_hook(CHECKS CLANG_FORMAT)
endif()
