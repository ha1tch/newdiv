#!/usr/bin/env bash
# =============================================================================
# makediv2.sh
# Copies games 152-302 (Mad Mix Game through Zzoom) into newdiv2/newdiv2.mmc
#
# Before running, set the two variables below:
#   GAMES_SRC  — path to your local copy of the ZXSpectrumTop100-noDoc folder
#   MMC        — path to the newdiv2.mmc image (relative paths are fine if
#                you run the script from the same directory as newdiv2/)
#
# Requires hdfmonkey on your PATH.
# =============================================================================

set -euo pipefail

GAMES_SRC="/path/to/ZXSpectrumTop100-noDoc"   # <-- set this
MMC="newdiv2/newdiv2.mmc"                       # <-- set this if needed
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

RED='\033[0;31m'; GRN='\033[0;32m'; BLU='\033[0;34m'; YLW='\033[1;33m'; NC='\033[0m'
info() { echo -e "${BLU}[info]${NC}  $*"; }
ok()   { echo -e "${GRN}[ ok ]${NC}  $*"; }
warn() { echo -e "${YLW}[warn]${NC}  $*"; }
die()  { echo -e "${RED}[fail]${NC}  $*" >&2; exit 1; }

command -v hdfmonkey &>/dev/null || die "hdfmonkey not found."
[[ -f "$MMC" ]] || die "MMC not found: $MMC"
[[ -d "$GAMES_SRC" ]] || die "Games source not found: $GAMES_SRC"

# Games 152-302: Mad Mix Game through Zzoom
GAMES=(
    "Mad Mix Game"
    "Manic Miner"
    "Marauder"
    "Marsport"
    "Match Day"
    "Match Day II"
    "Match Point"
    "Maziacs"
    "Mercenary"
    "Micronaut One"
    "Midnight Resistance"
    "Mikie"
    "Minder"
    "Mined-Out"
    "Monty Pythons Flying Circus"
    "Moon Strike"
    "Motos"
    "Movie"
    "Mr.Freeze"
    "Myth-History In The Making"
    "NARC"
    "Navy Seals"
    "Nebulus"
    "Nemesis The Warlock"
    "Nether Earth"
    "New Zealand Story, The"
    "Nigel Mansells World Championship"
    "Night Gunner"
    "Night Shift"
    "Nightshade"
    "Nodes Of Yesod"
    "North & South"
    "Operation Wolf"
    "Pac-Mania"
    "Pang"
    "Peking"
    "Penetrator"
    "Phantis"
    "Pheenix"
    "Pinball"
    "Ping Pong"
    "Pipe Mania"
    "Pippo"
    "Popeye"
    "Pssst"
    "Puzznic"
    "Pyjamarama"
    "Quazatron"
    "R-Type"
    "Rainbow Islands"
    "Ranarama"
    "Rastan"
    "Rebelstar"
    "Rebelstar 2"
    "Rebelstar Raiders"
    "Renegade"
    "Rescue"
    "Rex"
    "Rick Dangerous"
    "Ring Of Darkness, The"
    "River Rescue"
    "Robin Of The Wood"
    "Robocop"
    "Robotron-2084"
    "Rod-Land"
    "Rogue Trooper"
    "Roller Coaster"
    "Saboteur"
    "Saboteur II"
    "Sabre Wulf"
    "Sacred Armour Of Antiriad, The"
    "Saint Dragon"
    "Scuba Dive"
    "Secret Diary Of Adrian Mole, The"
    "Sentinel ,The"
    "Shadow of the Beast"
    "Shadowfire"
    "SimCity"
    "Sir Fred"
    "Sir Lancelot"
    "Skool Daze"
    "Slightly Magic"
    "Smash TV"
    "Soldier Of Fortune"
    "Space Crusade"
    "Spellbound Dizzy"
    "Spindizzy"
    "Splat"
    "Splitting Images"
    "Spy Hunter"
    "Spy Vs Spy"
    "Star Raiders II"
    "Star Wars"
    "Starquake"
    "Starstrike II"
    "Stonkers"
    "Stop The Express"
    "Stormlord"
    "Stunt Car Racer"
    "Super Hang-On"
    "Switchblade"
    "TLL"
    "Tai-Pan"
    "Tapper"
    "Target Renegade"
    "TauCeti - The Special Edition"
    "Technician Ted"
    "Teenage Mutant Hero Turtles"
    "Tempest"
    "Terra Cresta"
    "Tetris"
    "Thanatos"
    "They Stole A Million"
    "Think!"
    "Three Weeks In Paradise"
    "Thrust"
    "Thundercats"
    "Total Recall"
    "Track Suit Manager"
    "Train Game The"
    "TrapDoor - Through The Trap Door"
    "Trashman"
    "Turbo Esprit"
    "Turbo The Tortoise"
    "Turrican"
    "Turrican 2"
    "Underwurlde"
    "UniversalHero"
    "Uridium"
    "Viaje Al Centro De La Tierra"
    "Viking Raiders"
    "Vulcan"
    "WEC Le Mans"
    "Wanted Monty Mole"
    "Way Of The Exploding Fist, The"
    "West Bank"
    "Wheelie"
    "Where Time Stood Still"
    "Who Dares Wins II"
    "Wild Bunch, The"
    "Winter Games"
    "Wizball"
    "Wonder Boy"
    "World Series Baseball"
    "World Series Basketball"
    "Worse Things Happen At Sea"
    "Wriggler"
    "Xecutor"
    "Xeno"
    "Zynaps"
    "Zzoom"
)

# Helper: put a single file into the MMC image, uppercasing the filename
put_file() {
    local src="$1"
    local dest_dir="$2"
    local name
    name=$(basename "$src" | tr '[:lower:]' '[:upper:]')
    local tmp="${TMP}/${name}"
    cp "$src" "$tmp"
    hdfmonkey put "$MMC" "$tmp" "$dest_dir" 2>/dev/null && echo "    + ${dest_dir}/${name}" || warn "    failed: ${dest_dir}/${name}"
    rm -f "$tmp"
}

# Helper: recursively copy a host directory into the MMC image
put_dir() {
    local src_dir="$1"
    local dest_dir="$2"

    hdfmonkey mkdir "$MMC" "$dest_dir" 2>/dev/null || true

    for item in "$src_dir"/*; do
        [[ -e "$item" ]] || continue
        local name
        name=$(basename "$item" | tr '[:lower:]' '[:upper:]')
        if [[ -d "$item" ]]; then
            put_dir "$item" "${dest_dir}/${name}"
        elif [[ -f "$item" ]]; then
            put_file "$item" "$dest_dir"
        fi
    done
}

echo ""
echo "======================================================"
echo "  Populating newdiv2 — games 152-302"
echo "  (Mad Mix Game through Zzoom)"
echo "======================================================"
echo ""

hdfmonkey mkdir "$MMC" /GAMES 2>/dev/null || true

total=${#GAMES[@]}
count=0
failed=0

for game in "${GAMES[@]}"; do
    count=$((count + 1))
    src="${GAMES_SRC}/${game}"

    if [[ ! -d "$src" ]]; then
        warn "[$count/$total] NOT FOUND: $game"
        failed=$((failed + 1))
        continue
    fi

    safe=$(basename "$game" | tr '[:lower:]' '[:upper:]' | tr "' &,!+." '_' )

    info "[$count/$total] $game -> /GAMES/${safe}"
    put_dir "$src" "/GAMES/${safe}"
done

echo ""
echo "======================================================"
if [[ $failed -eq 0 ]]; then
    ok "Done. $count games installed into /GAMES on $MMC"
else
    warn "Done. $((count - failed)) games installed, $failed not found."
fi
echo "======================================================"
echo ""