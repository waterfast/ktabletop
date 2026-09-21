// SPDX-License-Identifier: GPL-3.0-or-later

#include "core/packman.h"
#include "core/util.h"
#include <QDir>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSqlError>
#include <QSqlRecord>
#include <QThread>
#include <QUrl>
#include <git2.h>

using namespace Qt::StringLiterals;
using namespace KTabletopUtils;

PackMan *Pacman = nullptr;

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

#define GIT_FAIL                                                                                                                                               \
    const git_error *e = git_error_last();                                                                                                                     \
    qCritical("Error %d/%d: %s\n", err, e->klass, e->message)

#define GIT_CHK_CLEAN                                                                                                                                          \
    if (err < 0) {                                                                                                                                             \
        GIT_FAIL;                                                                                                                                              \
        goto clean;                                                                                                                                            \
    }

// Simple wrapper around libgit2
struct GitRepo {
    git_repository *repo = nullptr;

    GitRepo() noexcept = default;
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
    git_repository *raw = nullptr;
    auto path = u"plugins/%1"_s.arg(name).toUtf8();
    int err = git_repository_open(&raw, path.constData());
    if (err < 0) {
        GIT_FAIL;
        return err;
    }
    repo = raw;
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
    QString fileName = extractPackName(u);
    QString clonePath = u"plugins/%1"_s.arg(fileName);

    git_repository *raw = nullptr;
    git_clone_options opt = GIT_CLONE_OPTIONS_INIT;
    opt.fetch_opts.proxy_opts.version = 1;
    opt.fetch_opts.callbacks.transfer_progress = transfer_progress_cb;
    int err = git_clone(&raw, u.toUtf8().constData(), clonePath.toUtf8().constData(), &opt);
    if (err < 0) {
        QDir(clonePath).removeRecursively();
        GIT_FAIL;
    } else {
        repo = raw;
        // if (Backend == nullptr)
        printf("\n");
    }
    return err;
}

// git fetch && git checkout FETCH_HEAD -f
int GitRepo::pull()
{
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
    int err;
    git_status_list *status_list = NULL;
    size_t i, maxi;
    const git_status_entry *s;
    err = git_status_list_new(&status_list, repo, NULL);
    GIT_CHK_CLEAN;
    maxi = git_status_list_entrycount(status_list);
    for (i = 0; i < maxi; ++i) {
        char *istatus = NULL;
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
                        qInfo("Auto-recovered from interrupted set_head.");
                        return 0;
                    }
                    GIT_FAIL;
                    return err;
                }
            }

            qCritical("Workspace is dirty.");
            return 100;
        }
    }

clean:
    git_status_list_free(status_list);
    return err;
}

QString GitRepo::head()
{
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

#undef GIT_FAIL
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

    db = QSqlDatabase::addDatabase(u"QSQLITE"_s, u"pluginsDb"_s);
    db.setDatabaseName(u"./plugins/plugins.db"_s);
    if (!db.open()) {
        qFatal("Cannot open packages database: %s", qPrintable(db.lastError().text()));
    }

    auto schemaQuery = execQuery(db, pluginsDbSchema);
    if (schemaQuery.lastError().isValid()) {
        qFatal("Cannot initialize packages database: %s", qPrintable(schemaQuery.lastError().text()));
    }

    auto query = execQuery(db, u"SELECT name FROM packages WHERE enabled = 0;"_s);
    while (query.next()) {
        disabled_packs << query.value(0).toString();
    }

#ifdef Q_OS_ANDROID
    git_libgit2_opts(GIT_OPT_SET_SSL_CERT_LOCATIONS, NULL, "./certs");
#endif
}

PackMan::~PackMan()
{
    git_libgit2_shutdown();
}

QStringList PackMan::getDisabledPacks()
{
    return disabled_packs;
}

QString PackMan::getPackSummary()
{
    QJsonArray arr;
    auto query = execQuery(db, u"SELECT name, url, hash FROM packages WHERE enabled = 1;"_s);
    while (query.next()) {
        QJsonObject obj;
        obj[u"name"_s] = query.value(0).toString();
        obj[u"url"_s] = query.value(1).toString();
        obj[u"hash"_s] = query.value(2).toString();
        arr.append(obj);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void PackMan::loadSummary(const QString &jsonData, bool useThread)
{
    auto f = [=, this] {
        // First, disable all packages
        auto query = execQuery(db, u"SELECT name, url, hash FROM packages WHERE enabled = 1;"_s);
        while (query.next()) {
            disablePack(query.value(0).toString());
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

            auto existsQuery = execQuery(db, u"SELECT name FROM packages WHERE name = ?;"_s, name);
            if (!existsQuery.next()) {
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

            GitRepo head_repo;
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

            execQuery(db, u"UPDATE packages SET hash = ? WHERE name = ?;"_s, obj[u"hash"_s].toString(), name);
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
        GitRepo raii_repo;
        int err = raii_repo.clone(url);
        if (err < 0) {
            sanitizePackageDb(extractPackName(url));
            return err;
        }

        auto fileName = extractPackName(url);

        auto existsQuery = execQuery(db, u"SELECT name FROM packages WHERE name = ?;"_s, fileName);
        if (!existsQuery.next()) {
            execQuery(db,
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
    execQuery(db, u"UPDATE packages SET enabled = 1 WHERE name = ?;"_s, pack);

    disabled_packs.removeOne(pack);
}

void PackMan::disablePack(const QString &pack)
{
    execQuery(db, u"UPDATE packages SET enabled = 0 WHERE name = ?;"_s, pack);

    if (!disabled_packs.contains(pack))
        disabled_packs << pack;
}

int PackMan::updatePack(const QString &pack, const QString &hash)
{
    GitRepo repo;
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
    GitRepo repo;
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

    execQuery(db, u"UPDATE packages SET hash = ? WHERE name = ?;"_s, repo.head(), pack);
    return 0;
}

void PackMan::removePack(const QString &pack)
{
    auto query = execQuery(db, u"SELECT enabled FROM packages WHERE name = ?;"_s, pack);
    if (!query.next())
        return;

    execQuery(db, u"DELETE FROM packages WHERE name = ?;"_s, pack);

    QDir d(u"plugins/%1"_s.arg(pack));
    d.removeRecursively();
}

QString PackMan::listPackages()
{
    QJsonArray arr;
    auto query = execQuery(db, u"SELECT * FROM packages;"_s);
    while (query.next()) {
        QJsonObject obj;
        const auto record = query.record();
        for (int i = 0; i < record.count(); ++i) {
            obj[record.fieldName(i)] = query.value(i).toString();
        }
        arr.append(obj);
    }
    return QString::fromUtf8(QJsonDocument(arr).toJson(QJsonDocument::Compact));
}

void PackMan::forceCheckoutMaster(const QString &pack)
{
    GitRepo repo;
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
    auto selectQuery = execQuery(db, u"SELECT name FROM packages;"_s);
    while (selectQuery.next())
        packs << selectQuery.value(0).toString();

    for (const auto &pack : packs) {
        GitRepo repo;
        int err = repo.open(pack);
        if (err < 0) {
            sanitizePackageDb(pack);
            continue;
        }

        execQuery(db, u"UPDATE packages SET hash = ? WHERE name = ?;"_s, repo.head(), pack);
    }
}

void PackMan::sanitizePackageDb(const QString &packname)
{
    QString dirPath = u"plugins/%1"_s.arg(packname);
    QDir dir(dirPath);
    bool dirExists = dir.exists();

    auto existsQuery = execQuery(db, u"SELECT name FROM packages WHERE name = ?;"_s, packname);
    bool dbHasRecord = existsQuery.next();

    if (!dirExists && dbHasRecord) {
        execQuery(db, u"DELETE FROM packages WHERE name = ?;"_s, packname);
        return;
    }

    if (dirExists && !dbHasRecord) {
        GitRepo repo;
        if (repo.open(packname) != 0)
            return;

        QString url = repo.remoteUrl();
        QString hash = repo.head();

        execQuery(db, u"INSERT INTO packages (name, url, hash, enabled) VALUES (?, ?, ?, 1);"_s, packname, url, hash);
    }
}
