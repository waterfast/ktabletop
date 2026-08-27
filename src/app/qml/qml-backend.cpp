// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "qml-backend.h"

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

QQmlPropertyMap *QmlBackend::createPropertyMap(const QString &objectName, const QVariantMap &dict)
{
    if (auto existing = m_propertyMaps.take(objectName)) {
        existing->deleteLater();
    }

    auto ret = QQmlPropertyMap::create(this);
    ret->setObjectName(objectName);

    for (auto i = dict.cbegin(), end = dict.cend(); i != end; ++i) {
        ret->insert(i.key(), i.value());
    }

    connect(ret, &QQmlPropertyMap::valueChanged, this, [this, objectName](const QString &key, const QVariant &value) {
        Q_EMIT propertyMapValueChanged(objectName, key, value);
    });

    m_propertyMaps.insert(objectName, ret);
    return ret;
}

void QmlBackend::destroyPropertyMap(const QString &objectName)
{
    if (auto existing = m_propertyMaps.take(objectName)) {
        existing->deleteLater();
    }
}

void QmlBackend::emitLuaEvent(const QString &type, const QVariant &payload)
{
    Q_EMIT luaEvent(type, payload);
}
