// SPDX-FileCopyrightText: 2026 Notify Ctrl <notify-ctrl@qq.com>
// SPDX-License-Identifier: LGPL-2.1-or-later

#pragma once

#include <memory>
#include <nlohmann/json.hpp>

namespace KTableTop
{

class Server
{
public:
    static Server &instance();
    Server(Server &) = delete;
    Server(Server &&) = delete;
    ~Server();

    const nlohmann::json &config() const;

    // TODO: listen and stop

private:
    class Private;
    std::unique_ptr<Private> d_ptr;
};

};
