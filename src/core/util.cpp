#include "util.h"

#include <QFile>

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

} // namespace KTabletopUtils
