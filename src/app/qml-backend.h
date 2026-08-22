// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>

class QmlBackend : public QObject
{
    Q_OBJECT

Q_SIGNALS:
    void luaEvent(const QString &type, const QVariant &payload);

public:
    Q_INVOKABLE bool startServer(ushort port);
    Q_INVOKABLE void joinServer(QString address, ushort port = 17943);
};
