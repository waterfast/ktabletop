// SPDX-License-Identifier: GPL-3.0-or-later

#include "core/packman.h"
#include "core/util.h"
#include "db-thread.h"
#include <QDebug>
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QThread>
#include <QUrl>
#include <git2.h>

using namespace Qt::StringLiterals;
using namespace KTabletopUtils;

static PackMan *packManInstance = nullptr;

PackMan *PackMan::instance()
{
    if (!packManInstance) {
        packManInstance = new PackMan;
    }
    return packManInstance;
}

bool PackMan::initialized()
{
    return packManInstance != nullptr;
}

void PackMan::destroy()
{
    delete packManInstance;
    packManInstance = nullptr;
}

static QString extractPackName(const QString &u)
{
    auto url = u;
    while (url.endsWith(u"/"_s)) {
        url.chop(1);
    }
    QString fileName = QUrl(url).fileName();
    if (fileName.endsWith(u".git"_s))
        fileName.chop(4);
    return fileName;
}

#define GIT_CHK_CLEAN                                                                                                                                          \
    if (err < 0) {                                                                                                                                             \
        reportError(err);                                                                                                                                      \
        goto clean;                                                                                                                                            \
    }

// Simple wrapper around libgit2
struct GitRepo {
    git_repository *repo = nullptr;
    QString pluginsPath;

    QString op;
    QString target;
    QString repoName = "(null)"_L1;

    void reportError(int err, const QString &detail = QString()) const
    {
        QString text = u"GitRepo::%1(%2) of plugin %3 failed!\n    "_s.arg(op.isEmpty() ? u"unknownOp"_s : op, target, repoName);

        if (detail.isEmpty()) {
            const git_error *e = git_error_last();
            text += u"Error %1/%2: %3"_s.arg(err).arg(e->klass).arg(QString::fromUtf8(e->message));
        } else {
            text += detail;
        }

        Q_EMIT PackMan::instance()->errorOccurred(text);
    }

    GitRepo() noexcept = default;
    explicit GitRepo(const QString &pluginsPath)
        : pluginsPath(pluginsPath)
    {
    }
    GitRepo(GitRepo &) = delete;
    GitRepo(GitRepo &&) = delete;
    ~GitRepo()
    {
        if (repo)
            git_repository_free(repo);
    }

    bool isValid() const
    {
        return repo != nullptr;
    }

    int open(const QString &name);
    int clone(const QString &url);
    int pull();
    int hasCommit(const QString &hash);
    int checkout(const QString &hash);
    int checkoutBranch(const QString &branch);
    int status();
    QString head();
    QString remoteUrl(const QString &name = u"origin"_s);
};

int GitRepo::open(const QString &name)
{
    op = u"open"_s;

    git_repository *raw = nullptr;
    auto path = u"%1/%2"_s.arg(pluginsPath, name);
    target = path;
    int err = git_repository_open(&raw, path.toUtf8().constData());
    if (err < 0) {
        reportError(err);
        return err;
    }
    repo = raw;
    repoName = name;
    return 0;
}

static int transfer_progress_cb(const git_indexer_progress *stats, void *payload)
{
    Q_UNUSED(payload);
    if (stats->received_objects == stats->total_objects) {
        printf("Resolving deltas %u/%u\r", stats->indexed_deltas, stats->total_deltas);
    } else if (stats->total_objects > 0) {
        printf("Received %u/%u objects (%u) in %zu bytes\r", stats->received_objects, stats->total_objects, stats->indexed_objects, stats->received_bytes);
    }

    // QmlBackend related, commented out for now
    // Backend->notifyUI(u"PackageTransferProgress"_s, QJsonObject {
    //   { u"received_objects"_s, qint64(stats->received_objects) },
    //   { u"total_objects"_s, qint64(stats->total_objects) },
    //   { u"indexed_objects"_s, qint64(stats->indexed_objects) },
    //   { u"received_bytes"_s, qint64(stats->received_bytes) },
    //   { u"indexed_deltas"_s, qint64(stats->indexed_deltas) },
    //   { u"total_deltas"_s, qint64(stats->total_deltas) },
    // });
    //
    // if (stats->received_objects == stats->total_objects) {
    //   auto msg = QString("Resolving deltas %1/%2")
    //                  .arg(stats->indexed_deltas)
    //                  .arg(stats->total_deltas);
    //   Backend->notifyUI("UpdateBusyText", msg);
    // } else if (stats->total_objects > 0) {
    //   auto msg = QString("Received %1/%2 objects (%3) in %4 KiB")
    //                  .arg(stats->received_objects)
    //                  .arg(stats->total_objects)
    //                  .arg(stats->indexed_objects)
    //                  .arg(stats->received_bytes / 1024);
    //   Backend->notifyUI("UpdateBusyText", msg);
    // }

    return 0;
}

int GitRepo::clone(const QString &u)
{
    op = u"clone"_s;
    target = u;

    QString fileName = extractPackName(u);
    QString clonePath = u"%1/%2"_s.arg(pluginsPath, fileName);

    git_repository *raw = nullptr;
    git_clone_options opt = GIT_CLONE_OPTIONS_INIT;
    opt.fetch_opts.proxy_opts.version = 1;
    opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
    int err = git_clone(&raw, u.toUtf8().constData(), clonePath.toUtf8().constData(), &opt);
    if (err < 0) {
        QDir(clonePath).removeRecursively();
        reportError(err);
    } else {
        repo = raw;
        repoName = fileName;
        // if (Backend == nullptr)
        printf("\n");
    }
    return err;
}

// git fetch && git checkout FETCH_HEAD -f
int GitRepo::pull()
{
    op = u"pull"_s;
    target = u""_s;

    int err;
    git_remote *remote = NULL;
    git_fetch_options opt = GIT_FETCH_OPTIONS_INIT;
    opt.proxy_opts.version = 1;
    opt.callbacks.transfer_progress = transfer_progress_cb;

    git_checkout_options opt2 = GIT_CHECKOUT_OPTIONS_INIT;
    opt2.checkout_strategy = GIT_CHECKOUT_FORCE;

    // first git fetch origin
    err = git_remote_lookup(&remote, repo, "origin");
    GIT_CHK_CLEAN;

    err = git_remote_fetch(remote, NULL, &opt, NULL);
    GIT_CHK_CLEAN;

    // then git checkout FETCH_HEAD
    err = git_repository_set_head(repo, "FETCH_HEAD");
    GIT_CHK_CLEAN;

    err = git_checkout_head(repo, &opt2);
    GIT_CHK_CLEAN;

    // if (Backend == nullptr)
    printf("\n");

clean:
    git_remote_free(remote);
    return err;
}

int GitRepo::hasCommit(const QString &hash)
{
    op = u"hasCommit"_s;
    target = hash;

    int err;
    git_oid oid = {0};
    git_commit *commit = NULL;

    auto sha = hash.toLatin1();
    err = git_oid_fromstr(&oid, sha.constData());
    GIT_CHK_CLEAN;
    err = git_commit_lookup(&commit, repo, &oid);
    // No need to pop up a dialog here
    // GIT_CHK_CLEAN;

clean:
    git_commit_free(commit);
    return err;
}

int GitRepo::checkout(const QString &hash)
{
    op = u"checkout"_s;
    target = hash;

    int err;
    git_oid oid = {0};
    git_checkout_options opt = GIT_CHECKOUT_OPTIONS_INIT;
    opt.checkout_strategy = GIT_CHECKOUT_FORCE;
    auto sha = hash.toLatin1();
    err = git_oid_fromstr(&oid, sha.constData());
    GIT_CHK_CLEAN;
    err = git_repository_set_head_detached(repo, &oid);
    GIT_CHK_CLEAN;
    err = git_checkout_head(repo, &opt);
    GIT_CHK_CLEAN;

clean:
    return err;
}

// git checkout -B branch origin/branch --force
int GitRepo::checkoutBranch(const QString &branch)
{
    op = u"checkoutBranch"_s;
    target = branch;

    git_oid oid = {0};
    int err;
    git_object *obj = NULL;
    git_reference *branch_ref = NULL;
    git_reference *remote_ref = NULL;
    git_reference *new_branch_ref = NULL;
    git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;
    checkout_opts.checkout_strategy = GIT_CHECKOUT_FORCE;

    QString local_branch;
    QString remote_branch;

    // Look up the remote branch reference (refs/remotes/origin/branch)
    remote_branch = u"refs/remotes/origin/%1"_s.arg(branch);
    err = git_reference_lookup(&remote_ref, repo, remote_branch.toUtf8().constData());
    GIT_CHK_CLEAN;

    // Get the object the remote branch points to
    err = git_reference_peel(&obj, remote_ref, GIT_OBJECT_COMMIT);
    GIT_CHK_CLEAN;

    // Get the commit OID
    git_oid_cpy(&oid, git_object_id(obj));

    // Look up the local branch reference
    local_branch = u"refs/heads/%1"_s.arg(branch);
    err = git_reference_lookup(&branch_ref, repo, local_branch.toUtf8().constData());
    if (err == 0) {
        // Branch exists, force reset
        err = git_reference_set_target(&new_branch_ref, branch_ref, &oid, "reset: moving to remote branch");
        GIT_CHK_CLEAN;
    } else {
        // Branch does not exist, create a new one
        err = git_branch_create(&new_branch_ref, repo, branch.toUtf8().constData(), (git_commit *)obj, 0);
        GIT_CHK_CLEAN;
    }

    // Point HEAD to the branch
    err = git_repository_set_head(repo, git_reference_name(new_branch_ref));
    GIT_CHK_CLEAN;

    // Force checkout to HEAD
    err = git_checkout_head(repo, &checkout_opts);
    GIT_CHK_CLEAN;

clean:
    git_reference_free(new_branch_ref);
    git_reference_free(branch_ref);
    git_reference_free(remote_ref);
    git_object_free(obj);

    return err;
}

int GitRepo::status()
{
    op = u"status"_s;
    target = u""_s;

    int err;
    git_status_list *status_list = NULL;
    size_t i, maxi;
    const git_status_entry *s;
    err = git_status_list_new(&status_list, repo, NULL);
    GIT_CHK_CLEAN;
    maxi = git_status_list_entrycount(status_list);
    for (i = 0; i < maxi; ++i) {
        s = git_status_byindex(status_list, i);
        if (s->status != GIT_STATUS_CURRENT && s->status != GIT_STATUS_IGNORED) {
            git_status_list_free(status_list);
            status_list = NULL;

            // If caused by setting HEAD without checkout (no diff between index and workdir), auto-recover
            git_diff *diff = NULL;
            git_diff_options diff_opts = GIT_DIFF_OPTIONS_INIT;
            if (git_diff_index_to_workdir(&diff, repo, NULL, &diff_opts) == 0) {
                size_t num_deltas = git_diff_num_deltas(diff);
                git_diff_free(diff);
                if (num_deltas == 0) {
                    git_checkout_options checkout_opts = GIT_CHECKOUT_OPTIONS_INIT;
                    checkout_opts.checkout_strategy = GIT_CHECKOUT_FORCE;
                    err = git_checkout_head(repo, &checkout_opts);
                    if (err == 0) {
                        qInfo("GitRepo %s: Auto-recovering from interrupted set_head.", qPrintable(repoName));
                        return 0;
                    }
                    reportError(err);
                    return err;
                }
            }

            reportError(100, u"workspace is dirty, refusing to overwrite local changes"_s);
            return 100;
        }
    }

clean:
    git_status_list_free(status_list);
    return err;
}

QString GitRepo::head()
{
    op = u"head"_s;
    target = u""_s;

    int err;
    git_object *obj = NULL;
    const git_oid *oid;
    char buf[42] = {0};
    err = git_revparse_single(&obj, repo, "HEAD");
    GIT_CHK_CLEAN;

    oid = git_object_id(obj);
    git_oid_tostr(buf, 41, oid);
    git_object_free(obj);
    return QString::fromLatin1(buf);

clean:
    git_object_free(obj);
    return u"0000000000000000000000000000000000000000"_s;
}

QString GitRepo::remoteUrl(const QString &name)
{
    git_remote *remote = NULL;
    QString url;
    if (git_remote_lookup(&remote, repo, name.toUtf8().constData()) == 0) {
        url = QString::fromUtf8(git_remote_url(remote));
        git_remote_free(remote);
    }
    return url;
}

#undef GIT_CHK_CLEAN

// ----------------------------------------------------

static const auto pluginsDbSchema =
    uR"(
CREATE TABLE IF NOT EXISTS packages (
  name VARCHAR(32),
  url VARCHAR(128),
  hash CHAR(40),
  enabled BOOLEAN
);
)"_s;

PackMan::PackMan(QObject *parent)
    : QObject(parent)
{
    git_libgit2_init();

    m_pluginsPath = u"%1/plugins"_s.arg(runtimeDataDir());

    connect(this, &PackMan::errorOccurred, this, [](const QString &message) {
        qCritical().noquote() << message;
    });

    initDatabase();

#ifdef Q_OS_ANDROID
    git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif
}

void PackMan::initDatabase()
{
    delete m_pluginsDb;
    m_pluginsDb = new DbThread(this, u"pluginsDb"_s, u"%1/plugins.db"_s.arg(m_pluginsPath));

    const auto schemaResult = m_pluginsDb->execQuerySync(pluginsDbSchema);
    if (schemaResult.first.isValid()) {
        qFatal("Cannot initialize packages database: %s", qPrintable(schemaResult.first.text()));
    }

    disabled_packs.clear();
    const auto result = m_pluginsDb->execQuerySync(u"SELECT name FROM packages WHERE enabled = 0;"_s);
    for (const auto &row : result.second) {
        disabled_packs << row.value(0).toString();
    }
}

PackMan::~PackMan()
{
    git_libgit2_shutdown();
}

QStringList PackMan::getDisabledPacks()
{
    return disabled_packs;
}

void PackMan::setPluginsPath(const QString &path)
{
    if (m_pluginsPath == path) {
        return;
    }

    m_pluginsPath = path;
    initDatabase();
}

QString PackMan::getPackSummary()
{
    QJsonArray arr;
    const auto result = m_pluginsDb->execQuerySync(u"SELECT name, url, hash FROM packages WHERE enabled = 1;"_s);
    for (const auto &row : result.second) {
        QJsonObject obj;
        obj[u"name"_s] = row.value(0).toString();
        obj[u"url"_s] = row.value(1).toString();
        obj[u"hash"_s] = row.value(2).toString();
        arr.append(obj);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void PackMan::loadSummary(const QString &jsonData, bool useThread)
{
    auto f = [=, this] {
        // First, disable all packages
        const auto enabledResult = m_pluginsDb->execQuerySync(u"SELECT name, url, hash FROM packages WHERE enabled = 1;"_s);
        for (const auto &row : enabledResult.second) {
            disablePack(row.value(0).toString());
        }

        // Then read conf from string
        auto doc = QJsonDocument::fromJson(jsonData.toUtf8());
        auto arr = doc.array();
        for (auto e : arr) {
            auto obj = e.toObject();
            auto name = obj[u"name"_s].toString();
            auto url = obj[u"url"_s].toString();
            int err = 0;

            // There should be an extension pack page showing which pack is downloading
            // Backend->notifyUI(u"SetDownloadingPackage"_s, name);

            // First sync DB with disk state, then decide clone or pull
            sanitizePackageDb(name);

            auto existsResult = m_pluginsDb->execQuerySync(u"SELECT name FROM packages WHERE name = ?;"_s, name);
            if (existsResult.second.isEmpty()) {
                err = downloadNewPack(url);
                if (err != 0) {
                    QString msg;
                    if (err != 100) {
                        auto error = git_error_last();
                        msg = u"Error: %1"_s.arg(error->message);
                    } else {
                        msg = u"Workspace is dirty."_s;
                    }
                    // Backend->notifyUI(u"PackageDownloadError"_s, msg);
                    continue;
                }
            }

            enablePack(name);

            GitRepo head_repo(m_pluginsPath);
            if (head_repo.open(name) == 0 && head_repo.head() != obj[u"hash"_s].toString()) {
                err = updatePack(name, obj[u"hash"_s].toString());
                if (err != 0) {
                    QString msg;
                    if (err != 100) {
                        auto error = git_error_last();
                        msg = u"Error: %1"_s.arg(error->message);
                    } else {
                        msg = u"Workspace is dirty."_s;
                    }
                    // Backend->notifyUI(u"PackageDownloadError"_s, msg);
                    continue;
                }
            }

            m_pluginsDb->execQuerySync(u"UPDATE packages SET hash = ? WHERE name = ?;"_s, obj[u"hash"_s].toString(), name);
        }
    };
    if (useThread) {
        auto thread = QThread::create(f);
        thread->start();
        connect(thread, &QThread::finished, thread, &QObject::deleteLater);
    } else {
        f();
    }
}

int PackMan::downloadNewPack(const QString &url, bool useThread)
{
    auto threadFunc = [=, this] {
        GitRepo raii_repo(m_pluginsPath);
        int err = raii_repo.clone(url);
        if (err < 0) {
            sanitizePackageDb(extractPackName(url));
            return err;
        }

        auto fileName = extractPackName(url);

        auto existsResult = m_pluginsDb->execQuerySync(u"SELECT name FROM packages WHERE name = ?;"_s, fileName);
        if (existsResult.second.isEmpty()) {
            m_pluginsDb->execQuerySync(
                u"INSERT INTO packages (name, url, hash, enabled) "
                "VALUES (?, ?, ?, 1);"_s,
                fileName,
                url,
                raii_repo.head());
        }

        return err;
    };
    if (useThread) {
        auto thread = QThread::create(threadFunc);
        thread->start();
        connect(thread, &QThread::finished, thread, &QObject::deleteLater);
        return 0;
    } else {
        return threadFunc();
    }
}

void PackMan::enablePack(const QString &pack)
{
    m_pluginsDb->execQuerySync(u"UPDATE packages SET enabled = 1 WHERE name = ?;"_s, pack);

    disabled_packs.removeOne(pack);
}

void PackMan::disablePack(const QString &pack)
{
    m_pluginsDb->execQuerySync(u"UPDATE packages SET enabled = 0 WHERE name = ?;"_s, pack);

    if (!disabled_packs.contains(pack))
        disabled_packs << pack;
}

int PackMan::updatePack(const QString &pack, const QString &hash)
{
    GitRepo repo(m_pluginsPath);
    int err = repo.open(pack);
    if (err < 0) {
        sanitizePackageDb(pack);
        return err;
    }

    // Check dirty status first, since the following operations all use --force
    err = repo.status();
    if (err != 0)
        return err;

    // Check if the commit hash already exists, pull if not
    err = repo.hasCommit(hash);
    if (err != 0) {
        err = repo.pull();
        if (err < 0)
            return err;
    }
    err = repo.checkout(hash);
    if (err < 0)
        return err;
    return 0;
}

int PackMan::upgradePack(const QString &pack)
{
    GitRepo repo(m_pluginsPath);
    int err = repo.open(pack);
    if (err < 0) {
        sanitizePackageDb(pack);
        return err;
    }

    // Check dirty status first, since the following operations all use --force
    err = repo.status();
    if (err != 0)
        return err;

    auto old_hash = repo.head();

    err = repo.pull();
    if (err < 0)
        return err;
    // At this point upgrade has moved the pack to the FETCH_HEAD commit.
    // We then point HEAD to the latest master so that new branches can be
    // developed remotely without affecting the pack update mechanism.
    err = repo.checkoutBranch(u"master"_s);
    if (err < 0)
        return err;

    m_pluginsDb->execQuerySync(u"UPDATE packages SET hash = ? WHERE name = ?;"_s, repo.head(), pack);
    return 0;
}

void PackMan::removePack(const QString &pack)
{
    const auto result = m_pluginsDb->execQuerySync(u"SELECT enabled FROM packages WHERE name = ?;"_s, pack);
    if (result.second.isEmpty())
        return;

    m_pluginsDb->execQuerySync(u"DELETE FROM packages WHERE name = ?;"_s, pack);

    QDir d(u"%1/%2"_s.arg(m_pluginsPath, pack));
    d.removeRecursively();
}

QString PackMan::listPackages()
{
    QJsonArray arr;
    const auto result = m_pluginsDb->execQuerySync(u"SELECT name, url, hash, enabled FROM packages;"_s);
    for (const auto &row : result.second) {
        QJsonObject obj;
        obj[u"name"_s] = row.value(0).toString();
        obj[u"url"_s] = row.value(1).toString();
        obj[u"hash"_s] = row.value(2).toString();
        obj[u"enabled"_s] = row.value(3).toString();
        arr.append(obj);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

PluginManifest PluginManifest::fromJson(const QJsonObject &obj)
{
    PluginManifest manifest;
    if (obj.value(u"schemaVersion"_s).toInt() != 1) {
        return manifest;
    }

    // TODO: add more REQUIRED fields
    manifest.name = obj.value(u"name"_s).toString().trimmed();
    manifest.valid = !manifest.name.isEmpty();
    return manifest;
}

QStringList PackMan::listPluginPaths()
{
    QStringList paths;

    QDir pluginsDir(m_pluginsPath);
    if (!pluginsDir.exists()) {
        return paths;
    }

    const auto entries = pluginsDir.entryList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Name);
    for (const auto &entry : entries) {
        const auto manifestPath = pluginsDir.absoluteFilePath(entry + u"/ktabletop.plugin.json"_s);
        const auto text = readWholeFile(manifestPath);
        if (text.isEmpty()) {
            continue;
        }

        QJsonParseError err;
        const auto doc = QJsonDocument::fromJson(text.toUtf8(), &err);
        if (err.error != QJsonParseError::NoError || !doc.isObject()) {
            qWarning().noquote() << u"Cannot parse plugin manifest %1, skipping: %2"_s.arg(manifestPath, err.errorString());
            continue;
        }

        const auto manifest = PluginManifest::fromJson(doc.object());
        if (!manifest.valid) {
            qWarning().noquote() << u"Invalid plugin manifest %1, skipping"_s.arg(manifestPath);
            continue;
        }

        const auto enabledResult = m_pluginsDb->execQuerySync(u"SELECT enabled FROM packages WHERE name = ?;"_s, entry);
        if (!enabledResult.second.isEmpty()) {
            if (!enabledResult.second.first().value(0).toBool()) {
                continue;
            }
        } else {
            qWarning().noquote() << u"Plugin %1 is not registered in packages database"_s.arg(entry);
        }

        paths << QDir::cleanPath(pluginsDir.absoluteFilePath(entry));
    }

    return paths;
}

void PackMan::forceCheckoutMaster(const QString &pack)
{
    GitRepo repo(m_pluginsPath);
    int err = repo.open(pack);
    if (err < 0) {
        sanitizePackageDb(pack);
        return;
    }
    repo.checkoutBranch(u"master"_s);
}

void PackMan::syncCommitHashToDatabase()
{
    QStringList packs;
    const auto selectResult = m_pluginsDb->execQuerySync(u"SELECT name FROM packages;"_s);
    for (const auto &row : selectResult.second)
        packs << row.value(0).toString();

    for (const auto &pack : packs) {
        GitRepo repo(m_pluginsPath);
        int err = repo.open(pack);
        if (err < 0) {
            sanitizePackageDb(pack);
            continue;
        }

        m_pluginsDb->execQuerySync(u"UPDATE packages SET hash = ? WHERE name = ?;"_s, repo.head(), pack);
    }
}

void PackMan::sanitizePackageDb(const QString &packname)
{
    QString dirPath = u"%1/%2"_s.arg(m_pluginsPath, packname);
    QDir dir(dirPath);
    bool dirExists = dir.exists();

    const auto existsResult = m_pluginsDb->execQuerySync(u"SELECT name FROM packages WHERE name = ?;"_s, packname);
    bool dbHasRecord = !existsResult.second.isEmpty();

    if (!dirExists && dbHasRecord) {
        m_pluginsDb->execQuerySync(u"DELETE FROM packages WHERE name = ?;"_s, packname);
        return;
    }

    if (dirExists && !dbHasRecord) {
        GitRepo repo(m_pluginsPath);
        if (repo.open(packname) != 0)
            return;

        QString url = repo.remoteUrl();
        QString hash = repo.head();

        m_pluginsDb->execQuerySync(u"INSERT INTO packages (name, url, hash, enabled) VALUES (?, ?, ?, 1);"_s, packname, url, hash);
    }
}
