#!/bin/bash

while :; do
    clear
    zig test src/main.zig
    #zig run test.zig
    echo --------------------------------------------------------------------------------
    inotifywait -q -e close_write src/*.zig build.zig
done
