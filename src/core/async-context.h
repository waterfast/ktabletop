// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QVariant>

#include <system_error>

class LuaBinding;

class AsyncContext : public QObject
{
    Q_OBJECT
public:
    AsyncContext(LuaBinding *parent, int callback);

    void complete(std::error_code err = {}, QVariant val = {});
    void cancel();

public Q_SLOTS:
    void completeVoid();

Q_SIGNALS:
    void cancelled();

private:
    LuaBinding *m_binding;
    int m_callback;
};
