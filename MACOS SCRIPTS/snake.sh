#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────
# snake.sh — Classic Snake game in pure Bash
#
# Author:  Jack Morton
# Version: 1.0.0
# Date:    2026-02-09
#
# Controls: Arrow keys or WASD to move, Q to quit
# Requires: Bash 3.2+, terminal with ANSI escape support
#
# Exit codes:
#   0 — Normal exit
#   2 — Terminal too small
#   3 — Missing dependency
#
# Note: set -e intentionally omitted. Interactive game loops
# depend on non-zero returns from read timeouts and arithmetic.
# ─────────────────────────────────────────────────────────
set -uo pipefail

# ── Dependency Check ─────────────────────────────────────
for cmd in tput stty; do
    command -v "$cmd" >/dev/null 2>&1 || {
        printf "Required: %s\n" "$cmd" >&2
        exit 3
    }
done

# ── Constants ────────────────────────────────────────────
readonly MIN_COLS=30
readonly MIN_ROWS=15
readonly INITIAL_LENGTH=3

# Box-drawing
readonly BD_H="═" BD_V="║"
readonly BD_TL="╔" BD_TR="╗" BD_BL="╚" BD_BR="╝"

# Game characters
readonly CH_HEAD="█" CH_BODY="▓" CH_FOOD="●" CH_EMPTY=" "

# ANSI colors
readonly C_RST="\033[0m"
readonly C_BRD="\033[1;37m"    # bold white  — border
readonly C_HD="\033[1;32m"     # bold green  — snake head
readonly C_BD="\033[0;32m"     # green       — snake body
readonly C_FD="\033[1;31m"     # bold red    — food
readonly C_SC="\033[1;33m"     # bold yellow — score
readonly C_TT="\033[1;36m"     # bold cyan   — title
readonly C_GO="\033[1;31m"     # bold red    — game over
readonly C_DM="\033[2m"        # dim         — hints

# Speed tiers: faster as score increases
readonly -a SPEED_THRESHOLDS=(0   50    100   200   350)
readonly -a SPEED_VALUES=(   0.12  0.10  0.08  0.06  0.045)

# ── Game State ───────────────────────────────────────────
declare -a SX=() SY=()      # Snake segments (index 0 = head)
DX=1 DY=0                   # Direction vector
FX=0 FY=0                   # Food position
SCORE=0
ALIVE=true
TICK="0.12"

# Play area edges (set during setup)
PL=0 PT=0 PR=0 PB=0

# ── Terminal Primitives ──────────────────────────────────
put()     { printf '\033[%d;%dH' "$2" "$1"; }
hide()    { printf '\033[?25l'; }
show()    { printf '\033[?25h'; }
cls()     { printf '\033[2J'; }
alt_on()  { printf '\033[?1049h'; }
alt_off() { printf '\033[?1049l'; }

draw() { # x y color char
    printf '\033[%d;%dH%b%s%b' "$2" "$1" "$3" "$4" "$C_RST"
}

center_text() { # text row [color]
    local text="$1" row="$2" color="${3:-$C_RST}"
    local cols col
    cols=$(tput cols)
    col=$(( (cols - ${#text}) / 2 ))
    (( col < 1 )) && col=1
    put "$col" "$row"
    printf '%b%s%b' "$color" "$text" "$C_RST"
}

# ── Cleanup ──────────────────────────────────────────────
cleanup() {
    show
    stty sane 2>/dev/null
    alt_off
}
trap cleanup EXIT INT TERM

# ── Terminal Setup ───────────────────────────────────────
setup_terminal() {
    local cols rows
    cols=$(tput cols)
    rows=$(tput lines)

    if (( cols < MIN_COLS || rows < MIN_ROWS )); then
        printf "Terminal too small (%dx%d). Minimum: %dx%d.\n" \
            "$cols" "$rows" "$MIN_COLS" "$MIN_ROWS" >&2
        exit 2
    fi

    alt_on
    hide
    cls
    stty -echo -icanon min 0 time 0 2>/dev/null

    PL=2
    PT=2
    PR=$(( cols - 1 ))
    PB=$(( rows - 2 ))
}

# ── Drawing ──────────────────────────────────────────────
draw_border() {
    local x y
    local l=$(( PL - 1 )) t=$(( PT - 1 )) r=$(( PR + 1 )) b=$(( PB + 1 ))

    draw "$l" "$t" "$C_BRD" "$BD_TL"
    draw "$r" "$t" "$C_BRD" "$BD_TR"
    draw "$l" "$b" "$C_BRD" "$BD_BL"
    draw "$r" "$b" "$C_BRD" "$BD_BR"

    for (( x = PL; x <= PR; x++ )); do
        draw "$x" "$t" "$C_BRD" "$BD_H"
        draw "$x" "$b" "$C_BRD" "$BD_H"
    done
    for (( y = PT; y <= PB; y++ )); do
        draw "$l" "$y" "$C_BRD" "$BD_V"
        draw "$r" "$y" "$C_BRD" "$BD_V"
    done
}

draw_hud() {
    local cols hint
    cols=$(tput cols)
    hint="Q=Quit  Arrows/WASD=Move"
    put 1 $(( PB + 2 ))
    printf '%b  SCORE: %-8d%b' "$C_SC" "$SCORE" "$C_RST"
    put $(( cols - ${#hint} - 1 )) $(( PB + 2 ))
    printf '%b%s%b' "$C_DM" "$hint" "$C_RST"
}

# ── Input ────────────────────────────────────────────────
read_input() {
    local key=""
    IFS= read -rsn1 -t "$TICK" key 2>/dev/null || true

    if [[ "$key" == $'\x1b' ]]; then
        IFS= read -rsn2 -t 0.01 key 2>/dev/null || true
        case "$key" in
            '[A') key=UP    ;;
            '[B') key=DOWN  ;;
            '[C') key=RIGHT ;;
            '[D') key=LEFT  ;;
            *)    return    ;;
        esac
    else
        case "$key" in
            w|W) key=UP    ;;
            s|S) key=DOWN  ;;
            a|A) key=LEFT  ;;
            d|D) key=RIGHT ;;
            q|Q) exit 0    ;;
            *)   return    ;;
        esac
    fi

    # Prevent 180-degree reversal
    case "$key" in
        UP)    if (( DY != 1  )); then DX=0;  DY=-1; fi ;;
        DOWN)  if (( DY != -1 )); then DX=0;  DY=1;  fi ;;
        LEFT)  if (( DX != 1  )); then DX=-1; DY=0;  fi ;;
        RIGHT) if (( DX != -1 )); then DX=1;  DY=0;  fi ;;
    esac
}

# ── Game Logic ───────────────────────────────────────────
tick_for_score() {
    local i
    for (( i = ${#SPEED_THRESHOLDS[@]} - 1; i >= 0; i-- )); do
        if (( SCORE >= SPEED_THRESHOLDS[i] )); then
            TICK="${SPEED_VALUES[$i]}"
            return
        fi
    done
    TICK="${SPEED_VALUES[0]}"
}

spawn_food() {
    local fx fy i hit
    while true; do
        fx=$(( RANDOM % (PR - PL + 1) + PL ))
        fy=$(( RANDOM % (PB - PT + 1) + PT ))
        hit=false
        for (( i = 0; i < ${#SX[@]}; i++ )); do
            if (( SX[i] == fx && SY[i] == fy )); then
                hit=true
                break
            fi
        done
        if ! $hit; then
            FX=$fx FY=$fy
            return
        fi
    done
}

init_game() {
    local i cx cy
    cx=$(( (PL + PR) / 2 ))
    cy=$(( (PT + PB) / 2 ))

    SX=() SY=()
    for (( i = 0; i < INITIAL_LENGTH; i++ )); do
        SX+=( $(( cx - i )) )
        SY+=( "$cy" )
    done

    DX=1 DY=0 SCORE=0 ALIVE=true
    TICK="${SPEED_VALUES[0]}"

    cls
    draw_border
    spawn_food
    draw "$FX" "$FY" "$C_FD" "$CH_FOOD"

    # Draw initial snake
    for (( i = 1; i < ${#SX[@]}; i++ )); do
        draw "${SX[$i]}" "${SY[$i]}" "$C_BD" "$CH_BODY"
    done
    draw "${SX[0]}" "${SY[0]}" "$C_HD" "$CH_HEAD"
    draw_hud
}

update() {
    local nx ny i len tail_x tail_y ate=false

    nx=$(( SX[0] + DX ))
    ny=$(( SY[0] + DY ))

    # Wall collision
    if (( nx < PL || nx > PR || ny < PT || ny > PB )); then
        ALIVE=false
        return
    fi

    # Self collision (skip tail — it moves out of the way)
    len=${#SX[@]}
    for (( i = 0; i < len - 1; i++ )); do
        if (( SX[i] == nx && SY[i] == ny )); then
            ALIVE=false
            return
        fi
    done

    # Food check
    if (( nx == FX && ny == FY )); then
        ate=true
        SCORE=$(( SCORE + 10 ))
        tick_for_score
    fi

    # Demote current head to body segment
    if (( len > 0 )); then
        draw "${SX[0]}" "${SY[0]}" "$C_BD" "$CH_BODY"
    fi

    # Prepend new head
    SX=( "$nx" "${SX[@]}" )
    SY=( "$ny" "${SY[@]}" )

    if $ate; then
        spawn_food
        draw "$FX" "$FY" "$C_FD" "$CH_FOOD"
        draw_hud
    else
        # Erase and remove tail
        len=${#SX[@]}
        tail_x=${SX[$(( len - 1 ))]}
        tail_y=${SY[$(( len - 1 ))]}
        draw "$tail_x" "$tail_y" "$C_RST" "$CH_EMPTY"
        unset "SX[$(( len - 1 ))]"
        unset "SY[$(( len - 1 ))]"
        # Re-index to avoid sparse array
        SX=( "${SX[@]}" )
        SY=( "${SY[@]}" )
    fi

    # Draw new head
    draw "${SX[0]}" "${SY[0]}" "$C_HD" "$CH_HEAD"
}

# ── Death Animation ──────────────────────────────────────
death_flash() {
    local i pass
    for pass in "$C_GO" "$C_DM" "$C_GO"; do
        for (( i = 0; i < ${#SX[@]}; i++ )); do
            draw "${SX[$i]}" "${SY[$i]}" "$pass" "$CH_HEAD"
        done
        sleep 0.2
    done
    sleep 0.3
}

# ── Screens ──────────────────────────────────────────────
title_screen() {
    cls
    local cy key=""
    cy=$(( $(tput lines) / 2 - 5 ))

    center_text "╔═══════════════════════╗" $(( cy ))     "$C_TT"
    center_text "║                       ║" $(( cy + 1 )) "$C_TT"
    center_text "║    S  N  A  K  E      ║" $(( cy + 2 )) "$C_TT"
    center_text "║                       ║" $(( cy + 3 )) "$C_TT"
    center_text "╚═══════════════════════╝" $(( cy + 4 )) "$C_TT"

    center_text "○ ○ ○ ○ ○ ▓ ▓ █ ~>"       $(( cy + 6 )) "$C_BD"

    center_text "Arrow keys or WASD to move" $(( cy + 9 ))  "$C_DM"
    center_text "Q to quit at any time"      $(( cy + 10 )) "$C_DM"

    center_text ">>> Press any key to start <<<" $(( cy + 13 )) "$C_SC"

    IFS= read -rsn1 key 2>/dev/null
}

game_over_screen() {
    local cy key="" score_line
    cy=$(( $(tput lines) / 2 - 3 ))
    printf -v score_line "║    Score: %-11d ║" "$SCORE"

    center_text "╔═══════════════════════╗" $(( cy ))     "$C_GO"
    center_text "║                       ║" $(( cy + 1 )) "$C_GO"
    center_text "║    G A M E  O V E R   ║" $(( cy + 2 )) "$C_GO"
    center_text "$score_line"               $(( cy + 3 )) "$C_GO"
    center_text "║                       ║" $(( cy + 4 )) "$C_GO"
    center_text "╚═══════════════════════╝" $(( cy + 5 )) "$C_GO"

    center_text "R = Play Again    Q = Quit" $(( cy + 8 )) "$C_DM"

    while true; do
        key=""
        IFS= read -rsn1 key 2>/dev/null || continue
        case "$key" in
            r|R) return 0 ;;
            q|Q) return 1 ;;
        esac
    done
}

# ── Main ─────────────────────────────────────────────────
main() {
    setup_terminal
    title_screen

    while true; do
        init_game

        # Core game loop
        while $ALIVE; do
            read_input
            update
        done

        death_flash
        game_over_screen || break
    done
}

main "$@"
