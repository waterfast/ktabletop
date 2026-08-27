// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QHash>
#include <QObject>
#include <QQmlPropertyMap>

class LuaEventListener;

class ObservableManager : public QObject
{
    Q_OBJECT

public:
    static ObservableManager *instance();

    QQmlPropertyMap *get(const QString &objectName) const;

Q_SIGNALS:
    // emitted when QML modifies a property map value; the host forwards it to luaBinding->emit
    void valueChanged(const QString &objectName, const QString &key, const QVariant &value);

private:
    explicit ObservableManager(QObject *parent = nullptr);
    void onNewObject(const QVariant &data);
    void onValueChanged(const QVariant &data);

    QHash<QString, QQmlPropertyMap *> m_maps;
    LuaEventListener *m_newObjectListener = nullptr;
    LuaEventListener *m_valueChangedListener = nullptr;
};
