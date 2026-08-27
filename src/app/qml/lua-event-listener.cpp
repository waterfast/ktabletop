// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "lua-event-listener.h"

#include <QPointer>
#include <QScopedPointer>

static QScopedPointer<LuaEventListenerManager> s_manager;

LuaEventListenerManager *LuaEventListenerManager::instance()
{
    if (s_manager.isNull()) {
        s_manager.reset(new LuaEventListenerManager);
    }
    return s_manager.data();
}

void LuaEventListenerManager::registerListener(const QString &eventName, LuaEventListener *listener)
{
    if (eventName.isEmpty()) {
        return;
    }
    if (!m_listeners.contains(eventName, listener)) {
        m_listeners.insert(eventName, listener);
    }
}

void LuaEventListenerManager::unregisterListener(const QString &eventName, LuaEventListener *listener)
{
    if (eventName.isEmpty()) {
        return;
    }
    m_listeners.remove(eventName, listener);
}

void LuaEventListenerManager::dispatch(const QString &type, const QVariant &payload)
{
    // Snapshot with QPointer guards: a triggered handler may destroy a listener
    // (or a sibling) synchronously, which would otherwise dangle the raw pointers.
    QList<QPointer<LuaEventListener>> targets;
    const auto values = m_listeners.values(type);
    targets.reserve(values.size());
    for (auto *l : std::as_const(values)) {
        targets.append(l);
    }

    for (const auto &l : targets) {
        if (l) {
            Q_EMIT l->triggered(payload);
        }
    }
}

LuaEventListenerManager::LuaEventListenerManager(QObject *parent)
    : QObject(parent)
{
}

LuaEventListener::LuaEventListener(QObject *parent)
    : QObject(parent)
{
}

LuaEventListener::~LuaEventListener()
{
    if (!m_eventName.isEmpty()) {
        LuaEventListenerManager::instance()->unregisterListener(m_eventName, this);
    }
}

QString LuaEventListener::eventName() const
{
    return m_eventName;
}

void LuaEventListener::setEventName(const QString &name)
{
    if (m_eventName == name) {
        return;
    }

    if (!m_eventName.isEmpty()) {
        LuaEventListenerManager::instance()->unregisterListener(m_eventName, this);
    }

    m_eventName = name;
    Q_EMIT eventNameChanged();

    if (!m_eventName.isEmpty()) {
        LuaEventListenerManager::instance()->registerListener(m_eventName, this);
    }
}
