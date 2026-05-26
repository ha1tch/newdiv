#!/bin/bash

# Locate zesarux: check macOS app bundle, then PATH, then current directory
if [[ -x "/Applications/zesarux.app/Contents/MacOS/zesarux" ]]; then
    ZESARUX="/Applications/zesarux.app/Contents/MacOS/zesarux"
elif command -v zesarux &>/dev/null; then
    ZESARUX="zesarux"
else
    ZESARUX="./zesarux"
fi

$ZESARUX --noconfigfile   --machine 48k   --enable-mmc   --enable-divmmc-ports   --enable-divmmc-paging   --enable-divmmc   --divmmc-rom newdiv/ESXMMC.BIN   --mmc-file newdiv2/newdiv2.mmc
