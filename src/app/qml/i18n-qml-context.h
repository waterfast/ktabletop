// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "i18n-context.h"

#include <QObject>
#include <QUrl>
#include <QVariant>
#include <QtQml>

class AbstractCatalog;

class I18nQmlContext : public QObject
{
    Q_OBJECT
    QML_NAMED_ELEMENT(I18nContext)

    Q_PROPERTY(QUrl url READ url WRITE setUrl NOTIFY urlChanged REQUIRED)

public:
    explicit I18nQmlContext(QObject *parent = nullptr);

    QUrl url() const;
    void setUrl(const QUrl &url);

    Q_INVOKABLE QString i18n(const QString &msg,
                             const QVariant &p1 = QVariant(),
                             const QVariant &p2 = QVariant(),
                             const QVariant &p3 = QVariant(),
                             const QVariant &p4 = QVariant(),
                             const QVariant &p5 = QVariant(),
                             const QVariant &p6 = QVariant(),
                             const QVariant &p7 = QVariant(),
                             const QVariant &p8 = QVariant(),
                             const QVariant &p9 = QVariant()) const;

    Q_INVOKABLE QString i18nc(const QString &ctx,
                              const QString &msg,
                              const QVariant &p1 = QVariant(),
                              const QVariant &p2 = QVariant(),
                              const QVariant &p3 = QVariant(),
                              const QVariant &p4 = QVariant(),
                              const QVariant &p5 = QVariant(),
                              const QVariant &p6 = QVariant(),
                              const QVariant &p7 = QVariant(),
                              const QVariant &p8 = QVariant(),
                              const QVariant &p9 = QVariant()) const;

    Q_INVOKABLE QString i18np(const QString &singular,
                              const QString &plural,
                              const QVariant &p1 = QVariant(),
                              const QVariant &p2 = QVariant(),
                              const QVariant &p3 = QVariant(),
                              const QVariant &p4 = QVariant(),
                              const QVariant &p5 = QVariant(),
                              const QVariant &p6 = QVariant(),
                              const QVariant &p7 = QVariant(),
                              const QVariant &p8 = QVariant(),
                              const QVariant &p9 = QVariant()) const;

    Q_INVOKABLE QString i18ncp(const QString &ctx,
                               const QString &singular,
                               const QString &plural,
                               const QVariant &p1 = QVariant(),
                               const QVariant &p2 = QVariant(),
                               const QVariant &p3 = QVariant(),
                               const QVariant &p4 = QVariant(),
                               const QVariant &p5 = QVariant(),
                               const QVariant &p6 = QVariant(),
                               const QVariant &p7 = QVariant(),
                               const QVariant &p8 = QVariant(),
                               const QVariant &p9 = QVariant()) const;

Q_SIGNALS:
    void urlChanged();

private:
    QUrl m_url;
    I18nContext m_context;
    AbstractCatalog *m_catalog = nullptr;
};
