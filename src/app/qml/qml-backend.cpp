// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend.h"
#include "lobject-manager.h"
#include "lobject-proxy.h"

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

LObjectProxy *QmlBackend::getObservable(const QString &objectName) const
{
    return LObjectManager::instance()->get(objectName);
}

void QmlBackend::emit(const QString &type, const QVariantMap &payload)
{
    Q_EMIT emitRequested(type, payload);
}
