// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class LuaVM;
struct lua_State;

class LuaBinding : public QObject
{
    Q_OBJECT

public:
    enum Role {
        Server,
        Client,
    };
    Q_ENUM(Role);

    explicit LuaBinding(QObject *parent = nullptr, Role role = Server);
    ~LuaBinding() override;

    // called by Lua
    void triggerLuaEvent(const QString &type, const QVariant &payload);

    void emit(const QString &type, const QVariantMap &payload);
    void loadPlugin(const QVariantMap &plugin);

    LuaVM &vm();

    static LuaBinding *forState(lua_State *state);

Q_SIGNALS:
    void luaEvent(const QString &type, const QVariant &payload);

private:
    LuaVM *L;
};
