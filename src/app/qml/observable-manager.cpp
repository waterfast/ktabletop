// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "observable-manager.h"
#include "lua-event-listener.h"

#include <QMap>
#include <QScopedPointer>
#include <QVariant>

using namespace Qt::Literals::StringLiterals;

ObservableManager *ObservableManager::instance()
{
    static QScopedPointer<ObservableManager> s_instance(new ObservableManager(LuaEventListenerManager::instance()));
    return s_instance.data();
}

ObservableManager::ObservableManager(QObject *parent)
    : QObject(parent)
{
    m_newObjectListener = new LuaEventListener(this);
    m_newObjectListener->setEventName(u"Observable::NewObject"_s);
    connect(m_newObjectListener, &LuaEventListener::triggered, this, &ObservableManager::onNewObject);

    m_valueChangedListener = new LuaEventListener(this);
    m_valueChangedListener->setEventName(u"Observable::ValueChanged"_s);
    connect(m_valueChangedListener, &LuaEventListener::triggered, this, &ObservableManager::onValueChanged);
}

QQmlPropertyMap *ObservableManager::get(const QString &objectName) const
{
    return m_maps.value(objectName);
}

void ObservableManager::onNewObject(const QVariant &data)
{
    const QVariantMap map = data.toMap();
    const QString objectName = map.value(u"_stringId"_s).toString();
    if (objectName.isEmpty()) {
        return;
    }

    if (auto *old = m_maps.take(objectName)) {
        old->deleteLater();
    }

    auto *pm = QQmlPropertyMap::create(this);
    pm->setObjectName(objectName);
    for (auto it = map.cbegin(), end = map.cend(); it != end; ++it) {
        if (it.key() != u"_stringId"_s) {
            pm->insert(it.key(), it.value());
        }
    }

    connect(pm, &QQmlPropertyMap::valueChanged, this, [this, objectName](const QString &key, const QVariant &value) {
        // only fired by QML-side writes; insert()/clear() from C++ never emit it
        Q_EMIT valueChanged(objectName, key, value);
    });

    m_maps.insert(objectName, pm);
}

void ObservableManager::onValueChanged(const QVariant &data)
{
    const QVariantMap map = data.toMap();
    const QString objectName = map.value(u"_stringId"_s).toString();
    auto *pm = m_maps.value(objectName);
    if (!pm) {
        return;
    }
    pm->insert(map.value(u"key"_s).toString(), map.value(u"value"_s));
}
