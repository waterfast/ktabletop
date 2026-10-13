# SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
# SPDX-License-Identifier: BSD-2-Clause

add_subdirectory(core)

if (BUILD_KTABLETOP_APP)
    add_subdirectory(controls)
    add_subdirectory(settings)
    add_subdirectory(app)
endif()

add_subdirectory(server)
