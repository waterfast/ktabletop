// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "i18n-qml-context.h"
#include "abstract-catalog.h"
#include "qml-backend.h"

#include <QQmlEngine>

using namespace Qt::Literals::StringLiterals;

I18nQmlContext::I18nQmlContext(QObject *parent)
    : QObject(parent)
{
}

QUrl I18nQmlContext::url() const
{
    return m_url;
}

void I18nQmlContext::setUrl(const QUrl &url)
{
    if (m_url == url) {
        return;
    }
    m_url = url;

    if (m_catalog) {
        m_catalog->deleteLater();
        m_catalog = nullptr;
    }

    if (auto *engine = qmlEngine(this)) {
        if (auto *backend = engine->singletonInstance<QmlBackend *>(u"org.kde.ktabletop"_s, u"Backend"_s)) {
            m_catalog = backend->createCatalog(url, this);
        }
    }
    if (!m_catalog) {
        m_catalog = new AbstractCatalog(this);
    }
    m_context.setCatalog(m_catalog);

    Q_EMIT urlChanged();
}

QString I18nQmlContext::i18n(const QString &msg,
                             const QVariant &p1,
                             const QVariant &p2,
                             const QVariant &p3,
                             const QVariant &p4,
                             const QVariant &p5,
                             const QVariant &p6,
                             const QVariant &p7,
                             const QVariant &p8,
                             const QVariant &p9) const
{
    return m_context.i18n(msg, p1, p2, p3, p4, p5, p6, p7, p8, p9);
}

QString I18nQmlContext::i18nc(const QString &ctx,
                              const QString &msg,
                              const QVariant &p1,
                              const QVariant &p2,
                              const QVariant &p3,
                              const QVariant &p4,
                              const QVariant &p5,
                              const QVariant &p6,
                              const QVariant &p7,
                              const QVariant &p8,
                              const QVariant &p9) const
{
    return m_context.i18nc(ctx, msg, p1, p2, p3, p4, p5, p6, p7, p8, p9);
}

QString I18nQmlContext::i18np(const QString &singular,
                              const QString &plural,
                              const QVariant &p1,
                              const QVariant &p2,
                              const QVariant &p3,
                              const QVariant &p4,
                              const QVariant &p5,
                              const QVariant &p6,
                              const QVariant &p7,
                              const QVariant &p8,
                              const QVariant &p9) const
{
    return m_context.i18np(singular, plural, p1.toInt(), p1, p2, p3, p4, p5, p6, p7, p8, p9);
}

QString I18nQmlContext::i18ncp(const QString &ctx,
                               const QString &singular,
                               const QString &plural,
                               const QVariant &p1,
                               const QVariant &p2,
                               const QVariant &p3,
                               const QVariant &p4,
                               const QVariant &p5,
                               const QVariant &p6,
                               const QVariant &p7,
                               const QVariant &p8,
                               const QVariant &p9) const
{
    return m_context.i18ncp(ctx, singular, plural, p1.toInt(), p1, p2, p3, p4, p5, p6, p7, p8, p9);
}
