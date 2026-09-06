// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QObject>
#include <QVariant>

class LObjectProxy;
class LuaEventListener;

class LObjectManager : public QObject
{
    Q_OBJECT

public:
    static LObjectManager *instance();

    LObjectProxy *get(const QString &objectName) const;

    void dispatch(const QString &type, const QVariant &payload);

Q_SIGNALS:
    // emitted when QML modifies a property map value; the host forwards it to luaBinding->emit
    void valueChanged(const QString &objectName, const QString &key, const QVariant &value);
    // emitted when QML invokes a method on the object; the host forwards it to Lua
    void invoked(const QString &objectName, const QString &method, const QVariant &args);
    // emitted when a new LObject proxy becomes available (LObject::New from Lua)
    void objectCreated(const QString &objectName);

private:
    explicit LObjectManager(QObject *parent = nullptr);
    void onNewObject(const QVariant &data);
    void onValueChanged(const QVariant &data);
    void onSignal(const QVariant &data);

    QHash<QString, LObjectProxy *> m_maps;
    LuaEventListener *m_newObjectListener = nullptr;
    LuaEventListener *m_valueChangedListener = nullptr;
    LuaEventListener *m_signalListener = nullptr;
};
