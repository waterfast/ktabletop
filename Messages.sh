#! /usr/bin/env bash
# SPDX-FileCopyrightText: None
# SPDX-License-Identifier: CC0-1.0
$XGETTEXT `find ./src ./scripts \( -name \*.cpp -o -name \*.h -o -name \*.qml -o -name \*.lua \)` -o $podir/ktabletop.pot
