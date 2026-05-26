#!/usr/bin/env bash
# =============================================================================
# makediv1.sh
# Copies games 1-151 (180 through Lunar Jetman) into newdiv1/newdiv1.mmc
#
# Before running, set the two variables below:
#   GAMES_SRC  — path to your local copy of the ZXSpectrumTop100-noDoc folder
#   MMC        — path to the newdiv1.mmc image (relative paths are fine if
#                you run the script from the same directory as newdiv1/)
#
# Requires hdfmonkey on your PATH.
# =============================================================================

set -euo pipefail

GAMES_SRC="/path/to/ZXSpectrumTop100-noDoc"   # <-- set this
MMC="newdiv1/newdiv1.mmc"                       # <-- set this if needed
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

# Games 1-151: 180 through Lunar Jetman
GAMES=(
    "180"
    "3D Starstrike"
    "APB"
    "Academy"
    "Agent X"
    "Alchemist"
    "Alien"
    "Alien 8"
    "All Or Nothing"
    "Ant Attack"
    "Antics"
    "Arkanoid"
    "Astro Marine Corps"
    "Astroball"
    "Atic Atac"
    "Auf Wiedersehen Monty"
    "Avalon"
    "Avenger"
    "Back To School"
    "Bard'sTale, The"
    "Batman"
    "Batman - The Movie"
    "Batty"
    "Beach-Head"
    "Block-Dizzy"
    "Bobby Bearing"
    "Bomb Jack"
    "Booty"
    "Boulder Dash"
    "Bounder"
    "Bounty Bob Strikes Back"
    "Bruce Lee"
    "Bubble Bobble"
    "Bugaboo The Flea"
    "Buggy Boy"
    "Bumpy"
    "CJ's Elephant Antics"
    "Carrier Command"
    "Chaos"
    "Chase H.Q"
    "Chronos"
    "Chuckie Egg"
    "Cobra"
    "Codename MAT"
    "Combat School"
    "Commando"
    "Computer Scrabble"
    "Confuzion"
    "Contact Sam Cruise"
    "Continental Circus"
    "Cruising On Broadway"
    "Crystal Kingdom Dizzy"
    "Cybernoid"
    "Cybernoid II - The Revenge"
    "Cyclone"
    "Daley Thompson's Decathlon"
    "Daley Thompson's Supertest"
    "Dan Dare"
    "Dandy"
    "Dark Star"
    "Deactivators"
    "Deathchase"
    "Deflektor"
    "Deus Ex Machina"
    "Doomdark's Revenge"
    "Dragontorc"
    "Driller"
    "Dun Darach"
    "Dynamite Dan"
    "Dynamite Dan II"
    "Earthlight"
    "Elite"
    "Emlyn Hughes International Soccer"
    "Enduro Racer"
    "Enigma Force"
    "Equinox"
    "Eric & The Floaters"
    "Exolon"
    "F-16 Combat Pilot"
    "Fairlight"
    "Fantasy World Dizzy"
    "Fat Worm Blows A Sparky"
    "Fernando Martin Basket Master"
    "Feud"
    "Fiendish Freddys Big Top O Fun"
    "Finders Keepers"
    "Firefly"
    "Firelord"
    "Flying Shark"
    "Football Manager"
    "Football Manager 2"
    "Formula One"
    "Frankie Goes To Hollywood"
    "Fred"
    "Full Throttle"
    "Future Games"
    "Gauntlet"
    "Ghost 'N Goblins"
    "Ghostbusters"
    "Glass"
    "Golden Axe"
    "Great Escape, The"
    "Green Beret"
    "Grumpy Gumphrey Supersleuth"
    "Guardian II - Revenge Of The Mutants"
    "Gunfright"
    "Gunrunner"
    "Gyroscope"
    "Harrier Attack"
    "Head Over Heels"
    "Heavy On The Magick"
    "Hero Quest"
    "Highway Encounter"
    "Hijack"
    "Hobbit, The"
    "Horace Goes Skiing"
    "Hudson Hawk"
    "Hyper Sports"
    "Hyperaction"
    "I Ball II"
    "IK+"
    "Ikari Warriors"
    "Impossible Mission"
    "International Cricket - Test Cricket"
    "International Match Day"
    "Into The Eagle's Nest"
    "Ivan Ironman Stewarts Super Off Road"
    "Jack The Nipper"
    "Jack The Nipper II - In Coconut Capers"
    "Jet Set Willy"
    "Jetpac"
    "Jumping Jack"
    "Kayleth"
    "Killed Until Dead"
    "Knight Lore"
    "Knight Tyme"
    "Knot In 3D"
    "Kokotoni Wilf"
    "Kwik Snax"
    "La Abadia del Crimen"
    "Laser Squad"
    "Last Ninja Remix"
    "Leader Board"
    "Lemmings"
    "Licence To Kill"
    "Light Force"
    "Lode Runner"
    "Lords Of Chaos"
    "Lords Of Midnight The"
    "Lotus Esprit Turbo Challenge"
    "Lunar Jetman"
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

    # Create destination directory on image
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
echo "  Populating newdiv1 — games 1-151"
echo "  (180 through Lunar Jetman)"
echo "======================================================"
echo ""

# Create GAMES directory on the image
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

    # Sanitise directory name for FAT: replace special chars with _
    # Keep it to 8 chars max for FAT16 compatibility
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