// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include "abstract-catalog.h"

#include <QString>
#include <QVariant>

class I18nContext
{
public:
    I18nContext() = default;

    void setCatalog(AbstractCatalog *catalog)
    {
        m_catalog = catalog;
    }

    AbstractCatalog *catalog() const
    {
        return m_catalog;
    }

    template<typename... Args>
    QString i18n(const QString &msg, const Args &...args) const
    {
        return substitute(m_catalog ? m_catalog->i18n(msg) : msg, args...);
    }

    template<typename... Args>
    QString i18nc(const QString &ctx, const QString &msg, const Args &...args) const
    {
        return substitute(m_catalog ? m_catalog->i18nc(ctx, msg) : msg, args...);
    }

    template<typename... Args>
    QString i18np(const QString &singular, const QString &plural, int n, const Args &...args) const
    {
        const QString base = m_catalog ? m_catalog->i18np(singular, plural, n) : (n == 1 ? singular : plural);
        return substitute(base, args...);
    }

    template<typename... Args>
    QString i18ncp(const QString &ctx, const QString &singular, const QString &plural, int n, const Args &...args) const
    {
        const QString base = m_catalog ? m_catalog->i18ncp(ctx, singular, plural, n) : (n == 1 ? singular : plural);
        return substitute(base, args...);
    }

private:
    static QString substitute(const QString &text)
    {
        return text;
    }

    template<typename First, typename... Rest>
    static QString substitute(const QString &text, const First &first, const Rest &...rest)
    {
        return substitute(substituteOne(text, first), rest...);
    }

    static QString substituteOne(const QString &text, const QVariant &value)
    {
        if (!value.isValid()) {
            return text;
        }
        switch (value.typeId()) {
        case QMetaType::Int:
            return text.arg(value.toInt());
        case QMetaType::LongLong:
            return text.arg(value.toLongLong());
        case QMetaType::UInt:
            return text.arg(value.toUInt());
        case QMetaType::ULongLong:
            return text.arg(value.toULongLong());
        case QMetaType::Double:
            return text.arg(value.toDouble());
        default:
            return text.arg(value.toString());
        }
    }

    template<typename T>
    static QString substituteOne(const QString &text, const T &value)
    {
        return substituteOne(text, QVariant(value));
    }

    AbstractCatalog *m_catalog = nullptr;
};
