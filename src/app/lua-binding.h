// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class LuaVM;

class LuaBinding : public QObject
{
    Q_OBJECT

public:
    enum Role {
        Server,
        Client,
    };
    Q_ENUM(Role);

    explicit LuaBinding(Role role);
    ~LuaBinding() override;

    void emit(const QString &type, const QVariant &payload);

    LuaVM &vm();

public
    Q_SIGNAL :
        // called by Lua, usually
        void luaEvent(const QString &type, const QVariant &payload);

private:
    LuaVM *L;
};
