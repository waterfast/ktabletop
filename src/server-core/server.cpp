// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#include "server.h"

using namespace KTableTop;

class Server::Private
{
public:
    nlohmann::json config;
    // TODO: listening socket

    // TODO: database handle
    // TODO: managers

    // TODO: user manager
    // TODO: room manager

    // TODO: (async) executor manager
};

const nlohmann::json &Server::config() const
{
    return d_ptr->config;
}
