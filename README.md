# KTabletop

A boardgame platform based on Qt/QML and KDE libs, using Lua for scripting.

## Goal

Make this an extensible and easy-to-use boardgame platform:

- Easy to develop new boardgame using provided Lua API and QML components
- Easy to host game server by yourself
- Easy for users to play together online without bothering plugin config by themselves
- And more...

I'd like to make it an official KDE app, but it needs more works and time,
it's still at very beginning now. What we have:

- Model-View-ViewModel pattern, with Lua code as ViewModel & Model and QML for View
- Lua async library created from scratch
- Simple API for calling Lua from C++
- Designed basic structure of boardgame that will run on KTabletop, with a sample Chess implementation.

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
$ sudo pacman -S qt6-declarative kirigami kcoreaddons kconfig ki18n kirigami-addons
```

then clone repo and build:

```sh
$ git clone https://invent.kde.org/notifyctrl/ktabletop
$ cd ktabletop
$ cmake -S . -B build/ -G Ninja
$ cmake --build build/ -j
```

Currently `$PWD` for the app must be project source dir, because of Lua scripts.
I will recommend creating soft link

```sh
$ ln -s build/bin/ktabletop-app
$ ./ktabletop-app
```

OK, here we go

- Run qmlls with `qmlls6 -b build` running in project root dir.
- Use `qml6 -I $(pwd)/bin/build <qml_file>` for previewing.

You may build it with only headless server, this will require less dependencies,
only use if you are going to host a testing server on your VPS

```sh
$ cmake -S . -B build/ -G Ninja -DBUILD_KTABLETOP_APP=false
$ cmake --build build/ -j
```

## Code Convention

Follow KDE policy, exceptions and additions:

- Lua code use 2 spaces for indentation, because it will be often deeply nested
- Avoid using `table.insert`. Use `t[#t + 1] = foo` for slightly better performance.
