// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend.h"
#include "observable-manager.h"

#include <QCoreApplication>
#include <QJSEngine>
#include <QQmlEngine>

QmlBackend::QmlBackend(QObject *parent)
    : QObject(parent)
{
}

QmlBackend::~QmlBackend() = default;

void QmlBackend::startServer(ushort port)
{
    Q_EMIT startServerRequested(port);
}

void QmlBackend::joinServer(const QString &address, ushort port)
{
    Q_EMIT joinServerRequested(address, port);
}

QQmlPropertyMap *QmlBackend::getObservable(const QString &objectName) const
{
    return ObservableManager::instance()->get(objectName);
}

void QmlBackend::emitLuaEvent(const QString &type, const QVariant &payload)
{
    Q_EMIT luaEvent(type, payload);
}
