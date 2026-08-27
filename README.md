# KTabletop

A boardgame platform based on Qt/QML and KDE libs, using Lua for scripting.

Still at very very beginning. Join our matrix room: #ktabletop:tchncs.de

## Build and Run

Install deps, then

```sh
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

## Code Convention

Just follow KDE policy, exceptions:

- Lua code use 2 spaces for indentation, because it will be often deeply nested

Additions:

- Avoid using `table.insert`. Use `t[#t + 1] = foo` for slightly better performance.

## Tech debts

I want to make everything working ASAP, so actual code different from my design.

- Too many raw pointers
- Variable naming violates KDE policy
- and more...
