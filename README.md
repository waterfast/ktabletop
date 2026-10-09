# KTabletop

A boardgame platform based on Qt/QML and KDE libs, using Lua for scripting.

## Goal

Make this an extensible and easy-to-use boardgame platform:

- Easy to develop new boardgame using provided Lua API and QML components
- Easy to host game server by yourself
- Easy for users to play together online without bothering plugin config by themselves
- And more...

Join our matrix room: #ktabletop:tchncs.de

## Build and Run

Currently only supports distros with up-to-date packages, like Arch, NixOS, Debian Testing, Fedora KDE, openSUSE...

Install deps: (On Arch, for Debian Testing please install corresponding `-dev` packages)

```sh
$ sudo pacman -S git gcc cmake ninja
$ sudo pacman -S spdlog lua55 libgit2 openssl extra-cmake-modules qt6-base
```

And install these if you want to build desktop app:

```sh
$ sudo pacman -S qt6-declarative kirigami kirigami-addons kcoreaddons kconfig ki18n kcolorscheme
```

Some notable minimum required versions here, since this project uses some of bleeding edge features:

- A compiler with C++26 support. (Used feature: `#embed` macro, needs gcc 15 or clang 19)
- Lua 5.5.x (Exactly 5.5, older or newer versions are not supported)
- CMake >= 4.3 (For `find_package(Lua EXACT 5.5)`)
- Qt >= 6.10
- LibGit2 >= 1.9

then clone repo and build:

```sh
$ git clone https://invent.kde.org/notifyctrl/ktabletop
$ cd ktabletop
$ cmake -S . -B build/ -G Ninja
$ cmake --build build/ -j
```

Currently `$PWD` for the app should be project source dir, I will recommend creating soft link,
and you need to create directories to make the app runs normally.

```sh
$ ln -s build/bin/ktabletop
$ mkdir plugins server client
$ ./ktabletop
```

OK, here we go.

- Run qmlls with `qmlls6 -b build` running in project root dir.
- Use `qml6 -I $(pwd)/build/bin <qml_file>` for previewing.

You may build it with only headless server, this will require less dependencies,
only use if you are going to host a testing server on your VPS

```sh
$ cmake -S . -B build/ -G Ninja -DBUILD_KTABLETOP_APP=false
$ cmake --build build/ -j
```

## Code Convention

Follow KDE policy, exceptions and additions:

- Lua code use 2 spaces for indentation, because it will be often deeply nested
- Avoid using `table.insert(t, foo)`. Use `t[#t + 1] = foo` for slightly better performance.
