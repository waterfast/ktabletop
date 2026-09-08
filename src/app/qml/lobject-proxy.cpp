// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lobject-proxy.h"
#include "lobject-manager.h"

using namespace Qt::Literals::StringLiterals;

LObjectProxy::LObjectProxy(QObject *parent)
    : QQmlPropertyMap(this, parent)
{
}

LObjectProxy::~LObjectProxy()
{
    qDebug().noquote() << "LObjectProxy" << QJsonDocument::fromVariant(m_opts).toJson(QJsonDocument::Compact) << "destroyed!";
    auto *manager = LObjectManager::instance();
    manager->unregisterProxy(objectName(), this);
    if (m_refIndex >= 0) {
        manager->releaseObject(m_refIndex);
    }
}

QVariantMap LObjectProxy::opts()
{
    return m_opts;
}

void LObjectProxy::setOpts(QVariantMap mp)
{
    if (initialized) {
        return;
    }
    m_opts = mp;

    auto *manager = LObjectManager::instance();
    const QVariantMap data = manager->createObject(m_opts);
    if (data.isEmpty()) {
        qWarning() << "LObjectProxy: failed to create object for" << m_opts;
        return;
    }

    m_refIndex = data.value(u"refIndex"_s).toInt();
    m_invokables = data.value(u"invokables"_s).toStringList();

    const QString objectName = data.value(u"id"_s).toString();
    setObjectName(objectName);

    const QVariantMap props = data.value(u"props"_s).toMap();
    for (auto it = props.cbegin(), end = props.cend(); it != end; ++it) {
        insert(it.key(), it.value());
    }

    connect(this, &QQmlPropertyMap::valueChanged, this, [objectName](const QString &key, const QVariant &) {
        qWarning() << "Do not modify value in QML side: obj=" << objectName << "key=" << key;
    });

    manager->registerProxy(objectName, this);

    initialized = true;
}

void LObjectProxy::invoke(const QString &method, const QVariantList &args)
{
    if (m_refIndex < 0) {
        return;
    }
    if (!m_invokables.contains(method)) {
        qWarning() << "LObject method is not invokable:" << method;
        return;
    }
    Q_EMIT invoked(m_refIndex, method, args);
}
