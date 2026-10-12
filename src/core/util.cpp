#include "util.h"

#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

using namespace Qt::Literals::StringLiterals;

namespace KTabletopUtils
{

QString readWholeFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) {
        return QString();
    }
    return QString::fromUtf8(file.readAll());
}

QString runtimeDataDir(bool headless)
{
    static QString cached;
    if (!cached.isEmpty()) {
        return cached;
    }

    const QString cwd = QDir::currentPath();

    if (headless) {
        cached = cwd;
        qInfo().noquote() << "Using runtime path:" << cached;
        return cached;
    }

    const QDir cwdDir(cwd);
    const bool cwdUsable = QFileInfo(cwd).isWritable() && QFile::exists(cwdDir.filePath(u".ktabletop-dir"_s)) && cwdDir.exists(u"client"_s)
        && cwdDir.exists(u"server"_s) && cwdDir.exists(u"plugins"_s);
    if (cwdUsable) {
        cached = cwd;
        qInfo().noquote() << "Using runtime path:" << cached;
        return cached;
    }

    const QString appData = QStandardPaths::writableLocation(QStandardPaths::AppDataLocation);
    if (appData.isEmpty()) {
        qFatal("Cannot find a writable location to store runtime data, quitting!");
    }

    QDir dataDir(appData);
    if (!dataDir.mkpath(u"."_s)) {
        qFatal("Cannot create runtime data directory %s, quitting!", qPrintable(appData));
    }

    QFile marker(dataDir.filePath(u".ktabletop-dir"_s));
    if (!marker.open(QIODevice::WriteOnly)) {
        qFatal("Cannot create marker file in %s, quitting!", qPrintable(appData));
    }
    marker.close();

    for (const auto &sub : {u"client"_s, u"server"_s, u"plugins"_s}) {
        if (!dataDir.mkpath(sub)) {
            qFatal("Cannot create runtime data subdirectory %s in %s, quitting!", qPrintable(sub), qPrintable(appData));
        }
    }

    cached = appData;
    qInfo().noquote() << "Using runtime path:" << cached;
    return cached;
}

} // namespace KTabletopUtils
