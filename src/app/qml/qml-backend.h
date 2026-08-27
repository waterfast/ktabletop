// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QQmlPropertyMap>

class QmlBackend : public QObject
{
    Q_OBJECT
    QML_SINGLETON
    QML_NAMED_ELEMENT(Backend)

public:
    explicit QmlBackend(QObject *parent = nullptr);
    ~QmlBackend() override;

    Q_INVOKABLE void startServer(ushort port);
    Q_INVOKABLE void joinServer(const QString &address, ushort port = 17943);

    void emitLuaEvent(const QString &type, const QVariant &payload);

    Q_INVOKABLE QQmlPropertyMap *getObservable(const QString &objectName) const;

Q_SIGNALS:
    // emitted from QML
    void startServerRequested(ushort port);
    void joinServerRequested(const QString &address, ushort port);

    // emitted from C++, by calling emitLuaEvent
    void luaEvent(const QString &type, const QVariant &payload);
};
