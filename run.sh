#!/bin/bash

while :; do
    clear
    #zig build test > out 2>&1
    #head -$((LINES-4)) out | cut -b-$COLUMNS
    #rm out

    #zig build test
    zig build run

    echo --------------------------------------------------------------------------------
    inotifywait --format %w -q -e close_write src/*.zig examples/*.zig build.zig
done
