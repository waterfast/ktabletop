// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-binding.h"
#include "c-wrapper.h"

#include <QDir>
#include <QString>

#include <QStringLiteral>
using namespace Qt::Literals::StringLiterals;

LuaBinding::LuaBinding(QObject *parent, Role role)
    : QObject(parent)
{
    L = new LuaVM;

    QDir::setCurrent(u"scripts"_s);
    if (role == Server) {
        L->dofile(u"ktabletop/server-entry.lua"_s);
    } else {
        L->dofile(u"ktabletop/client-entry.lua"_s);
    }
    QDir::setCurrent(u".."_s);
}

LuaBinding::~LuaBinding()
{
    delete L;
}

void LuaBinding::emit(const QString &type, const QVariant &payload)
{
    // TODO: something like MainContext:emit(type, payload)
    // I maybe pass payload to Lua using JSON, but not very smart
    // Or declare a global function in Lua (like Emit) so I can use L->call
    L->call(u"Emit"_s, {type, payload});
}

LuaVM &LuaBinding::vm()
{
    return *L;
}
