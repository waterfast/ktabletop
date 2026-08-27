// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QObject>
#include <QVariant>
#include <qqmlregistration.h>

class LuaEventListener;

class LuaEventListenerManager : public QObject
{
    Q_OBJECT

public:
    static LuaEventListenerManager *instance();

    void registerListener(const QString &eventName, LuaEventListener *listener);
    void unregisterListener(const QString &eventName, LuaEventListener *listener);

public Q_SLOTS:
    // Entry point the host connects its luaEvent signal to.
    void dispatch(const QString &type, const QVariant &payload);

private:
    explicit LuaEventListenerManager(QObject *parent = nullptr);
    QMultiHash<QString, LuaEventListener *> m_listeners;
};

class LuaEventListener : public QObject
{
    Q_OBJECT
    QML_ELEMENT

    Q_PROPERTY(QString eventName READ eventName WRITE setEventName NOTIFY eventNameChanged REQUIRED FINAL)

public:
    explicit LuaEventListener(QObject *parent = nullptr);
    ~LuaEventListener() override;

    QString eventName() const;
    void setEventName(const QString &name);

Q_SIGNALS:
    void eventNameChanged();
    void triggered(const QVariant &data);

private:
    QString m_eventName;
};
