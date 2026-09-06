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
    if (type == u"LObject::ValueChanged"_s) {
        onValueChanged(payload);
    } else if (type == u"LObject::Signal"_s) {
        onSignal(payload);
    }
}

LObjectProxy *LObjectManager::get(const QString &objectName) const
{
    return m_maps.value(objectName);
}

void LObjectManager::setCreateObjectFn(CreateObjectFn fn)
{
    m_createObjectFn = std::move(fn);
}

void LObjectManager::setReleaseObjectFn(ReleaseObjectFn fn)
{
    m_releaseObjectFn = std::move(fn);
}

QVariantMap LObjectManager::createObject(const QVariantMap &opts)
{
    if (!m_createObjectFn) {
        qWarning() << "LObjectManager: no createObject handler installed";
        return {};
    }
    return m_createObjectFn(opts);
}

void LObjectManager::releaseObject(int ref)
{
    if (m_releaseObjectFn) {
        m_releaseObjectFn(ref);
    }
}

void LObjectManager::registerProxy(const QString &objectName, LObjectProxy *proxy)
{
    if (auto *old = m_maps.value(objectName)) {
        if (old != proxy) {
            old->deleteLater();
        }
    }
    m_maps.insert(objectName, proxy);

    connect(proxy, &LObjectProxy::invoked, this, [this](int ref, const QString &method, const QVariant &args) {
        Q_EMIT invoked(ref, method, args);
    });
}

void LObjectManager::unregisterProxy(const QString &objectName, LObjectProxy *proxy)
{
    if (m_maps.value(objectName) == proxy) {
        m_maps.remove(objectName);
    }
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
