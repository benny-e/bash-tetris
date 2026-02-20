#!/bin/bash
#a simple terminal tetris game

BOARD_WIDTH=10
BOARD_HEIGHT=20
BLOCK_CHAR="██"
EMPTY_CHAR="  "
NEXT_PIECE_TYPE=0

C_RESET=$(tput sgr0)
C_CYAN=$(tput setaf 6)
C_YELLOW=$(tput setaf 3)
C_PURPLE=$(tput setaf 5)
C_GREEN=$(tput setaf 2)
C_RED=$(tput setaf 1)
C_BLUE=$(tput setaf 4)
C_ORANGE=$(tput setaf 208 2>/dev/null || tput setaf 3)

declare -A COLORS=(
    [0]="$C_RESET"
    [1]="$C_CYAN"
    [2]="$C_YELLOW"
    [3]="$C_PURPLE"
    [4]="$C_GREEN"
    [5]="$C_RED"
    [6]="$C_BLUE"
    [7]="$C_ORANGE"
)

I_PIECE=(
    "0,1 1,1 2,1 3,1"
    "1,0 1,1 1,2 1,3"
    "0,2 1,2 2,2 3,2"
    "2,0 2,1 2,2 2,3"
)

O_PIECE=(
    "0,1 0,2 1,1 1,2"
    "0,1 0,2 1,1 1,2"
    "0,1 0,2 1,1 1,2"
    "0,1 0,2 1,1 1,2"
)

T_PIECE=(
    "0,1 1,0 1,1 1,2"
    "0,1 1,1 1,2 2,1"
    "1,0 1,1 1,2 2,1"
    "0,1 1,0 1,1 2,1"
)

S_PIECE=(
    "0,1 0,2 1,0 1,1"
    "0,1 1,1 1,2 2,2"
    "1,1 1,2 2,0 2,1"
    "0,0 1,0 1,1 2,1"
)

Z_PIECE=(
    "0,0 0,1 1,1 1,2"
    "0,2 1,1 1,2 2,1"
    "1,0 1,1 2,1 2,2"
    "0,1 1,0 1,1 2,0"
)

J_PIECE=(
    "0,0 1,0 1,1 1,2"
    "0,1 0,2 1,1 2,1"
    "1,0 1,1 1,2 2,2"
    "0,1 1,1 2,0 2,1"
)

L_PIECE=(
    "0,2 1,0 1,1 1,2"
    "0,1 1,1 2,1 2,2"
    "1,0 1,1 1,2 2,0"
    "0,0 0,1 1,1 2,1"
)

declare -a BOARD
SCORE=0
LINES=0
LEVEL=1
GAME_OVER=0

CUR_PIECE_TYPE=0
CUR_ROTATION=0
CUR_X=0
CUR_Y=0

init_board() {
    for ((i=0; i<BOARD_HEIGHT*BOARD_WIDTH; i++)); do
        BOARD[$i]=0
    done
}

get_board() {
    local x=$1 y=$2
    echo ${BOARD[$((y * BOARD_WIDTH + x))]}
}

set_board() {
    local x=$1 y=$2 val=$3
    BOARD[$((y * BOARD_WIDTH + x))]=$val
}

get_piece_blocks() {
    local piece_type=$1
    local rotation=$2
    local blocks=""
    
    case $piece_type in
        1) blocks=${I_PIECE[$rotation]} ;;
        2) blocks=${O_PIECE[$rotation]} ;;
        3) blocks=${T_PIECE[$rotation]} ;;
        4) blocks=${S_PIECE[$rotation]} ;;
        5) blocks=${Z_PIECE[$rotation]} ;;
        6) blocks=${J_PIECE[$rotation]} ;;
        7) blocks=${L_PIECE[$rotation]} ;;
    esac
    
    echo "$blocks"
}

#checks if terminal is big enough so it doesn't glitch
check_terminal_size() {
    local min_cols=$((BOARD_WIDTH * 2 + 16))
    local min_rows=$((BOARD_HEIGHT + 10))

    local cols
    local rows
    cols=$(tput cols)
    rows=$(tput lines)

    if (( cols < min_cols || rows < min_rows )); then
        clear

        local center_row=$((rows / 2 - 3))
        tput cup $center_row 0

        echo
        echo "   Terminal Too Small!      "
        echo
        echo "  Required: ${min_cols} cols x ${min_rows} rows"
        echo "  Current:  ${cols} cols x ${rows} rows"
        echo
        echo "  Please resize your terminal."
        echo
        echo "  Press any key to exit..."

        read -rsn1
        exit 1
    fi
}


check_terminal_size() {
    local min_cols=$((BOARD_WIDTH * 2 + 16))
    local min_rows=$((BOARD_HEIGHT + 10))

    local cols
    local rows
    cols=$(tput cols)
    rows=$(tput lines)

    if (( cols < min_cols || rows < min_rows )); then
        clear
        echo
        echo "  Terminal too small!"
        echo
        echo "  Required: at least ${min_cols}x${min_rows}"
        echo "  Current:  ${cols}x${rows}"
        echo
        echo "  Resize your terminal and try again."
        echo
        exit 1
    fi
}

can_place() {
    local x=$1 y=$2 piece_type=$3 rotation=$4
    local blocks=$(get_piece_blocks $piece_type $rotation)
    
    for block in $blocks; do
        local by=${block%,*}
        local bx=${block#*,}
        local nx=$((x + bx))
        local ny=$((y + by))
        
        if [ $nx -lt 0 ] || [ $nx -ge $BOARD_WIDTH ] || [ $ny -ge $BOARD_HEIGHT ]; then
            return 1
        fi
        
        if [ $ny -ge 0 ] && [ $(get_board $nx $ny) -ne 0 ]; then
            return 1
        fi
    done
    
    return 0
}

place_piece() {
    local blocks=$(get_piece_blocks $CUR_PIECE_TYPE $CUR_ROTATION)
    
    for block in $blocks; do
        local by=${block%,*}
        local bx=${block#*,}
        local nx=$((CUR_X + bx))
        local ny=$((CUR_Y + by))
        
        if [ $ny -ge 0 ]; then
            set_board $nx $ny $CUR_PIECE_TYPE
        fi
    done
}

#spawn piece + next piece
spawn_piece() {
    CUR_PIECE_TYPE=$NEXT_PIECE_TYPE
    NEXT_PIECE_TYPE=$((RANDOM % 7 + 1))

    CUR_ROTATION=0
    CUR_X=$((BOARD_WIDTH / 2 - 2))
    CUR_Y=0
    
    if ! can_place $CUR_X $CUR_Y $CUR_PIECE_TYPE $CUR_ROTATION; then
        GAME_OVER=1
    fi
}

#clearing full line
clear_lines() {
    local lines_cleared=0
    
    for ((y=BOARD_HEIGHT-1; y>=0; y--)); do
        local full=1
        for ((x=0; x<BOARD_WIDTH; x++)); do
            if [ $(get_board $x $y) -eq 0 ]; then
                full=0
                break
            fi
        done
        
        if [ $full -eq 1 ]; then
            ((lines_cleared++))
            for ((cy=y; cy>0; cy--)); do
                for ((x=0; x<BOARD_WIDTH; x++)); do
                    set_board $x $cy $(get_board $x $((cy-1)))
                done
            done
            for ((x=0; x<BOARD_WIDTH; x++)); do
                set_board $x 0 0
            done
            ((y++)) 
        fi
    done
    
    if [ $lines_cleared -gt 0 ]; then
        ((LINES += lines_cleared))
        case $lines_cleared in
            1) ((SCORE += 100 * LEVEL)) ;;
            2) ((SCORE += 300 * LEVEL)) ;;
            3) ((SCORE += 500 * LEVEL)) ;;
            4) ((SCORE += 800 * LEVEL)) ;;
        esac
        LEVEL=$(((LINES / 10) + 1))
    fi
}

draw_game_over_screen() {
    tput cup 0 0
    tput ed

    echo -e "\n  ${C_RED}╔══════════════════════╗${C_RESET}"
    echo -e "  ${C_RED}║${C_RESET}      GAME OVER       ${C_RED}║${C_RESET}"
    echo -e "  ${C_RED}╚══════════════════════╝${C_RESET}\n"

    echo -e "  Final Score: ${C_YELLOW}${SCORE}${C_RESET}"
    echo -e "  Lines:       ${C_YELLOW}${LINES}${C_RESET}"
    echo -e "  Level:       ${C_YELLOW}${LEVEL}${C_RESET}\n"

    echo -e "  Press ${C_CYAN}Q${C_RESET} to quit."
}

draw_next_preview() {
    local blocks
    local grid
    local x y

    grid=()
    for ((y=0; y<4; y++)); do
        for ((x=0; x<4; x++)); do
            grid[$((y*4 + x))]=0
        done
    done

    blocks="$(get_piece_blocks "$NEXT_PIECE_TYPE" 0)"
    for block in $blocks; do
        local by=${block%,*}
        local bx=${block#*,}
        if (( bx>=0 && bx<4 && by>=0 && by<4 )); then
            grid[$((by*4 + bx))]="$NEXT_PIECE_TYPE"
        fi
    done

    echo -e "  Next:"
    echo -e "  ┌────────┐"
    for ((y=0; y<4; y++)); do
        echo -n "  │"
        for ((x=0; x<4; x++)); do
            local v=${grid[$((y*4 + x))]}
            if (( v == 0 )); then
                echo -n "  "
            else
                echo -n "${COLORS[$v]}██${COLORS[0]}"
            fi
        done
        echo "│"
    done
    echo -e "  └────────┘"
}


#Draws board+preview
draw() {
    tput cup 0 0

    echo -e "\n  ${C_PURPLE}╔══════════════════════╗${C_RESET}"
    echo -e "  ${C_PURPLE}║${C_RESET}     BASH TETRIS      ${C_PURPLE}║${C_RESET}"
    echo -e "  ${C_PURPLE}╚══════════════════════╝${C_RESET}\n"

    local -a display_board=("${BOARD[@]}")

    if [ $GAME_OVER -eq 0 ]; then
        local blocks
        blocks="$(get_piece_blocks "$CUR_PIECE_TYPE" "$CUR_ROTATION")"
        for block in $blocks; do
            local by=${block%,*}
            local bx=${block#*,}
            local nx=$((CUR_X + bx))
            local ny=$((CUR_Y + by))
            if [ $ny -ge 0 ] && [ $nx -ge 0 ] && [ $nx -lt $BOARD_WIDTH ] && [ $ny -lt $BOARD_HEIGHT ]; then
                display_board[$((ny * BOARD_WIDTH + nx))]="$CUR_PIECE_TYPE"
            fi
        done
    fi

    #draws next grid
    local -a next_grid
    for ((i=0; i<16; i++)); do next_grid[$i]=0; done

    local next_blocks
    next_blocks="$(get_piece_blocks "$NEXT_PIECE_TYPE" 0)"
    for block in $next_blocks; do
        local by=${block%,*}
        local bx=${block#*,}
        if (( bx>=0 && bx<4 && by>=0 && by<4 )); then
            next_grid[$((by*4 + bx))]="$NEXT_PIECE_TYPE"
        fi
    done

    echo -n "  ┌"
    for ((x=0; x<BOARD_WIDTH; x++)); do echo -n "──"; done
    echo "┐    Next"
    echo -n "  │"
    for ((x=0; x<BOARD_WIDTH; x++)); do echo -n "  "; done
    echo "│  ┌────────┐"

    for ((y=0; y<BOARD_HEIGHT; y++)); do
        echo -n "  │"
        for ((x=0; x<BOARD_WIDTH; x++)); do
            local val=${display_board[$((y * BOARD_WIDTH + x))]}
            if (( val == 0 )); then
                echo -n "${EMPTY_CHAR}"
            else
                echo -n "${COLORS[$val]}${BLOCK_CHAR}${COLORS[0]}"
            fi
        done
        echo -n "│"

        if (( y >= 0 && y < 4 )); then
            echo -n "  │"
            for ((x=0; x<4; x++)); do
                local v=${next_grid[$((y*4 + x))]}
                if (( v == 0 )); then
                    echo -n "  "
                else
                    echo -n "${COLORS[$v]}██${COLORS[0]}"
                fi
            done
            echo "│"
        elif (( y == 4 )); then
            echo "  └────────┘"
        else
            echo
        fi
    done

    echo -n "  └"
    for ((x=0; x<BOARD_WIDTH; x++)); do echo -n "──"; done
    echo "┘"

    echo -e "\n  Score: $SCORE  Lines: $LINES  Level: $LEVEL"
    echo -e "\n  Press Q to quit."

    if [ $GAME_OVER -eq 1 ]; then
        echo -e "\n  ${C_RED}GAME OVER!${C_RESET}"
    fi

    tput ed
}

move_piece() {
    local dx=$1 dy=$2
    local new_x=$((CUR_X + dx))
    local new_y=$((CUR_Y + dy))
    
    if can_place $new_x $new_y $CUR_PIECE_TYPE $CUR_ROTATION; then
        CUR_X=$new_x
        CUR_Y=$new_y
        return 0
    fi
    return 1
}

rotate_piece() {
    local new_rotation=$(((CUR_ROTATION + 1) % 4))
    
    if can_place $CUR_X $CUR_Y $CUR_PIECE_TYPE $new_rotation; then
        CUR_ROTATION=$new_rotation
    fi
}

hard_drop() {
    while move_piece 0 1; do
        ((SCORE += 2))
    done
    place_piece
    clear_lines
    spawn_piece
}

game_loop() {
    local tick=0
    local drop_speed=50

    NEXT_PIECE_TYPE=$((RANDOM % 7 + 1))
    spawn_piece
    clear

    while [ $GAME_OVER -eq 0 ]; do
        draw

	#auto drop
        if [ $((tick % drop_speed)) -eq 0 ]; then
            if ! move_piece 0 1; then
                place_piece
                clear_lines
                spawn_piece
            fi
        fi

	#read input, arrows keys + wsad
        local input=""
        if read -rsn1 -t 0.05 input; then
            if [[ "$input" == "" || "$input" == " " ]]; then
                hard_drop
            elif [[ "$input" == $'\e' ]]; then
                local seq=""
                read -rsn2 -t 0.001 seq || seq=""
                case "$seq" in
                    "[A") rotate_piece ;;                  
                    "[B") move_piece 0 1 && ((SCORE++)) ;;
                    "[C") move_piece 1 0 ;;              
                    "[D") move_piece -1 0 ;;            
                esac
            else
                case "$input" in
                    a|A) move_piece -1 0 ;;
                    d|D) move_piece 1 0 ;;
                    w|W) rotate_piece ;;
                    s|S) move_piece 0 1 && ((SCORE++)) ;;
                    q|Q) GAME_OVER=1 ;;
                esac
            fi
        fi

        ((tick++))
        drop_speed=$((50 - (LEVEL - 1) * 3))
        [ $drop_speed -lt 10 ] && drop_speed=10
    done

    draw_game_over_screen

    #wait for Q
    while true; do
        if read -rsn1 -t 0.1 input; then
            [[ "$input" == "q" || "$input" == "Q" ]] && break
        fi
    done

}

setup_term() {
    stty -echo
    stty -icanon
    tput civis
    clear
}

restore_term() {
    stty echo
    stty icanon
    tput cnorm
    clear
}

check_terminal_size
trap restore_term EXIT
setup_term
init_board
game_loop

echo -e "\nThanks for playing!\n"
