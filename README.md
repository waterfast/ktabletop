# KTableTop

A boardgame platform based on Qt/QML and KDE libs, using Lua for scripting.

Still at very very beginning. Join our matrix room: #ktabletop:tchncs.de

## Code Convention

Just follow KDE policy, exceptions:

- Lua code use 2 spaces for indentation, because it will be often deeply nested

Additions:

- Avoid using `table.insert`. Use `t[#t + 1] = foo` for slightly better performance.

## Tech debts

I want to make everything working ASAP, so actual code different from my design.

- Too many raw pointers
- No directory structure
- Variable naming violates KDE policy
- and more...
