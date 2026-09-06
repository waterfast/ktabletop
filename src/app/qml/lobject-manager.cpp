// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lobject-manager.h"
#include "lobject-proxy.h"

#include <QScopedPointer>
#include <QVariant>

using namespace Qt::Literals::StringLiterals;

LObjectManager *LObjectManager::instance()
{
    static QScopedPointer<LObjectManager> s_instance(new LObjectManager());
    return s_instance.data();
}

LObjectManager::LObjectManager(QObject *parent)
    : QObject(parent)
{
}

void LObjectManager::dispatch(const QString &type, const QVariant &payload)
{
    if (type == u"LObject::New"_s) {
        onNewObject(payload);
    } else if (type == u"LObject::ValueChanged"_s) {
        onValueChanged(payload);
    } else if (type == u"LObject::Signal"_s) {
        onSignal(payload);
    }
}

LObjectProxy *LObjectManager::get(const QString &objectName) const
{
    return m_maps.value(objectName);
}

void LObjectManager::onNewObject(const QVariant &data)
{
    const QVariantMap map = data.toMap();
    const QString objectName = map.value(u"id"_s).toString();
    if (objectName.isEmpty()) {
        return;
    }

    if (auto *old = m_maps.take(objectName)) {
        old->deleteLater();
    }

    auto *proxy = new LObjectProxy(this);
    proxy->setObjectName(objectName);

    const QVariantMap values = map.value(u"values"_s).toMap();
    for (auto it = values.cbegin(), end = values.cend(); it != end; ++it) {
        proxy->insert(it.key(), it.value());
    }

    connect(proxy, &QQmlPropertyMap::valueChanged, this, [this, objectName](const QString &key, const QVariant &value) {
        // only fired by QML-side writes; insert()/clear() from C++ never emit it
        Q_EMIT valueChanged(objectName, key, value);
    });

    connect(proxy, &LObjectProxy::invoked, this, [this, objectName](const QString &method, const QVariant &args) {
        Q_EMIT invoked(objectName, method, args);
    });

    m_maps.insert(objectName, proxy);
    Q_EMIT objectCreated(objectName);
}

void LObjectManager::onValueChanged(const QVariant &data)
{
    const QVariantMap map = data.toMap();
    const QString objectName = map.value(u"id"_s).toString();
    auto *proxy = m_maps.value(objectName);
    if (!proxy) {
        return;
    }
    proxy->insert(map.value(u"key"_s).toString(), map.value(u"value"_s));
}

void LObjectManager::onSignal(const QVariant &data)
{
    const QVariantMap map = data.toMap();
    const QString objectName = map.value(u"id"_s).toString();
    auto *proxy = m_maps.value(objectName);
    if (!proxy) {
        return;
    }
    Q_EMIT proxy->signalEmitted(map.value(u"signal"_s).toString(), map.value(u"data"_s));
}
