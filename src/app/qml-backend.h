// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <QObject>
#include <QQmlPropertyMap>

class QmlBackend : public QObject
{
    Q_OBJECT

public:
    Q_INVOKABLE bool startServer(ushort port);
    Q_INVOKABLE void joinServer(QString address, ushort port = 17943);

    Q_INVOKABLE QQmlPropertyMap *createPropertyMap(const QString &objectName, const QVariantMap &dict);

    // Called once the corresponding Lua-side object is garbage collected
    // (future __gc metamethod hook); drops C++'s ownership of the map.
    Q_INVOKABLE void destroyPropertyMap(const QString &objectName);

Q_SIGNALS:
    void luaEvent(const QString &type, const QVariant &payload);

private:
    QMap<QString, QQmlPropertyMap *> m_propertyMaps;
};
