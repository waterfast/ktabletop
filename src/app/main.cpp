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

using namespace Qt::Literals::StringLiterals;

#ifdef Q_OS_ANDROID
Q_DECL_EXPORT
#endif
int main(int argc, char *argv[])
{
    return 1;
#ifdef Q_OS_ANDROID
    QGuiApplication app(argc, argv);
#else
    QApplication app(argc, argv);
#endif
    KirigamiAppDefaults::apply(&app);

    KLocalizedString::setApplicationDomain("KTableTop");

    KAboutData aboutData(u"kapp4"_s, i18nc("@title", "KApp4"), QStringLiteral("0.0.1"), i18n("Application Description"), KAboutLicense::GPL, i18n("(c) 2026"));
    aboutData.addAuthor(i18nc("@info:credit", ""), i18nc("@info:credit", "Maintainer"), u""_s, u"https://yourwebsite.com"_s);
    aboutData.setTranslator(i18nc("NAME OF TRANSLATORS", "Your names"), i18nc("EMAIL OF TRANSLATORS", "Your emails"));
    KAboutData::setApplicationData(aboutData);
    QGuiApplication::setWindowIcon(QIcon::fromTheme(u"org.kde.kapp4"_s));

    QQmlApplicationEngine engine;

    KLocalization::setupLocalizedContext(&engine);

    // auto config = KApp4Config::self();

    // qmlRegisterSingletonInstance("org.kde.kapp4.private", 1, 0, "Config", config);

    {
        QCommandLineParser parser;
        aboutData.setupCommandLine(&parser);
        parser.process(app);
        aboutData.processCommandLine(&parser);
    }

    engine.loadFromModule("org.kde.kapp4", u"Main"_s);
    if (engine.rootObjects().isEmpty()) {
        return EXIT_FAILURE;
    }

    return app.exec();
}
