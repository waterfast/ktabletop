// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QMap>
#include <QObject>
#include <QVariant>
#include <QtQml>

class LObjectProxy;

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

    Q_INVOKABLE LObjectProxy *getObservable(const QString &objectName) const;

    Q_INVOKABLE void emit(const QString &type, const QVariantMap &payload);

Q_SIGNALS:
    // emitted from QML
    void startServerRequested(ushort port);
    void joinServerRequested(const QString &address, ushort port);

    // emitted from QML (via emit()), forwarded by the host to luaBinding->emit
    void emitRequested(const QString &type, const QVariantMap &payload);
};
