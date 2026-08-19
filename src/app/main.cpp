// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include <KirigamiApp>
#include <QtGlobal>

#ifdef Q_OS_ANDROID
#include <QGuiApplication>
#else
#include <QApplication>
#endif
#include <QCommandLineParser>
#include <QIcon>
#include <QQmlApplicationEngine>

#include <KAboutData>
#include <KLocalizedQmlContext>
#include <KLocalizedString>
#include <KirigamiAppDefaults>

#include <QDir>
#include <QQmlContext>

#include "lua-binding.h"
#include "qml-backend.h"
#include "server.h"

using namespace Qt::Literals::StringLiterals;

#ifdef Q_OS_ANDROID
Q_DECL_EXPORT
#endif
int main(int argc, char *argv[])
{
#ifdef Q_OS_ANDROID
    QGuiApplication app(argc, argv);
#else
    QApplication app(argc, argv);
#endif
    KirigamiAppDefaults::apply(&app);

    KLocalizedString::setApplicationDomain("KTableTop");

    KAboutData aboutData(u"ktabletop"_s,
                         i18nc("@title", "KTableTop"),
                         QStringLiteral("0.0.1"),
                         i18n("Application Description"),
                         KAboutLicense::GPL,
                         i18n("(c) 2026"));
    aboutData.addAuthor(i18nc("@info:credit", ""), i18nc("@info:credit", "Maintainer"), u""_s, u"https://yourwebsite.com"_s);
    aboutData.setTranslator(i18nc("NAME OF TRANSLATORS", "Your names"), i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    KAboutData::setApplicationData(aboutData);
    QGuiApplication::setWindowIcon(QIcon::fromTheme(u"org.kde.ktabletop"_s));

    QQmlApplicationEngine engine;

    KLocalization::setupLocalizedContext(&engine);

    {
        QCommandLineParser parser;
        aboutData.setupCommandLine(&parser);
        parser.process(app);
        aboutData.processCommandLine(&parser);
    }

    QmlBackend backend;
    Server::instance();

    // FIXME: should use a singleton here
    // but I don't have time mess with QT I need make it run first
    engine.rootContext()->setContextProperty(u"Backend"_s, &backend);

    engine.loadFromModule("org.kde.ktabletop", u"Main"_s);
    if (engine.rootObjects().isEmpty()) {
        return EXIT_FAILURE;
    }

    return app.exec();
}
