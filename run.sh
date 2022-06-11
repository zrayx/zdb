#!/bin/bash

while :; do
    clear
    zig build test > out 2>&1
    head -$((LINES-4)) out | cut -b-$COLUMNS
    rm out
    #zig run test.zig
    echo --------------------------------------------------------------------------------
    inotifywait --format %w -q -e close_write src/*.zig build.zig
done
