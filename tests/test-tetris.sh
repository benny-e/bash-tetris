#!/usr/bin/env bash
# tests/test-tetris.sh — Unit tests for tetris.sh using ptyunit
#
# Run:  bash tests/ptyunit/run.sh tests/test-tetris.sh

set -u

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"

source "$TESTS_DIR/ptyunit/assert.sh"

# Source tetris.sh functions without executing the game.
# Strips the bottom execution block (check_terminal_size … game_loop … echo).
eval "$(sed '/^check_terminal_size$/,$d' "$REPO_DIR/tetris.sh")"

# ── Board basics ─────────────────────────────────────────────────────────────

describe "Board basics"

  test_that "init_board sets all cells to 0"
  init_board
  all_zero=1
  for ((i=0; i<BOARD_HEIGHT*BOARD_WIDTH; i++)); do
    if [[ "${BOARD[$i]}" -ne 0 ]]; then all_zero=0; break; fi
  done
  assert_eq "1" "$all_zero"

  test_that "get_board returns 0 for empty cell"
  init_board
  assert_eq "0" "$(get_board 0 0)"

  test_that "set_board / get_board round-trip"
  init_board
  set_board 3 5 4
  assert_eq "4" "$(get_board 3 5)"

  test_that "set_board does not affect other cells"
  init_board
  set_board 3 5 4
  assert_eq "0" "$(get_board 0 0)"
  assert_eq "0" "$(get_board 4 5)"

  test_that "board dimensions are correct"
  assert_eq "10" "$BOARD_WIDTH"
  assert_eq "20" "$BOARD_HEIGHT"

end_describe

# ── Piece definitions ────────────────────────────────────────────────────────

describe "Piece definitions"

  test_that "get_piece_blocks returns non-empty for all 7 piece types"
  for type in 1 2 3 4 5 6 7; do
    blocks=""
    blocks=$(get_piece_blocks $type 0)
    assert_not_null "$blocks" "piece type $type rotation 0"
  done

  test_that "each piece has exactly 4 blocks"
  for type in 1 2 3 4 5 6 7; do
    blocks=""; count=""
    blocks=$(get_piece_blocks $type 0)
    count=$(echo "$blocks" | wc -w | tr -d ' ')
    assert_eq "4" "$count" "piece type $type should have 4 blocks"
  done

  test_that "all 4 rotations exist for each piece"
  for type in 1 2 3 4 5 6 7; do
    for rot in 0 1 2 3; do
      blocks=""
      blocks=$(get_piece_blocks $type $rot)
      assert_not_null "$blocks" "piece type $type rotation $rot"
    done
  done

  test_that "O-piece is the same in all rotations"
  r0=""; r1=""; r2=""; r3=""
  r0=$(get_piece_blocks 2 0)
  r1=$(get_piece_blocks 2 1)
  r2=$(get_piece_blocks 2 2)
  r3=$(get_piece_blocks 2 3)
  assert_eq "$r0" "$r1"
  assert_eq "$r1" "$r2"
  assert_eq "$r2" "$r3"

  test_that "I-piece rotation 0 is horizontal"
  blocks=""
  blocks=$(get_piece_blocks 1 0)
  # rotation 0: "0,1 1,1 2,1 3,1" — all y=1
  assert_eq "0,1 1,1 2,1 3,1" "$blocks"

  test_that "invalid piece type returns empty"
  blocks=""
  blocks=$(get_piece_blocks 0 0)
  assert_null "$blocks"

end_describe

# ── Collision detection (can_place) ──────────────────────────────────────────

describe "Collision detection"

  test_that "piece can be placed on empty board"
  init_board
  can_place 3 0 1 0
  assert_eq "0" "$?" "I-piece should fit at top-center"

  test_that "piece cannot extend past left wall"
  init_board
  can_place -2 0 1 0
  assert_eq "1" "$?"

  test_that "piece cannot extend past right wall"
  init_board
  can_place $((BOARD_WIDTH - 1)) 0 1 0
  assert_eq "1" "$?"

  test_that "piece cannot extend past bottom"
  init_board
  can_place 3 $((BOARD_HEIGHT)) 1 0
  assert_eq "1" "$?"

  test_that "piece cannot overlap occupied cell"
  init_board
  set_board 4 1 5
  can_place 3 0 1 0
  assert_eq "1" "$?" "I-piece at x=3 y=0 overlaps occupied cell at 4,1"

  test_that "piece can be placed adjacent to occupied cell"
  init_board
  set_board 0 0 5
  can_place 3 0 1 0
  assert_eq "0" "$?" "I-piece at x=3 should not conflict with cell at 0,0"

end_describe

# ── Place piece ──────────────────────────────────────────────────────────────

describe "Placing pieces"

  test_that "place_piece writes piece type onto the board"
  init_board
  CUR_PIECE_TYPE=1
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=0
  place_piece
  # I-piece rot 0: "0,1 1,1 2,1 3,1" → by,bx pairs
  # nx=CUR_X+bx=3+1=4, ny=CUR_Y+by=0+0,0+1,0+2,0+3
  # → column 4, rows 0,1,2,3
  assert_eq "1" "$(get_board 4 0)"
  assert_eq "1" "$(get_board 4 1)"
  assert_eq "1" "$(get_board 4 2)"
  assert_eq "1" "$(get_board 4 3)"

  test_that "place_piece does not affect unrelated cells"
  init_board
  CUR_PIECE_TYPE=2  # O-piece
  CUR_ROTATION=0
  CUR_X=0
  CUR_Y=0
  place_piece
  assert_eq "0" "$(get_board 5 5)"

end_describe

# ── Move piece ───────────────────────────────────────────────────────────────

describe "Moving pieces"

  test_that "move_piece moves right"
  init_board
  CUR_PIECE_TYPE=2
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=3
  move_piece 1 0
  assert_eq "4" "$CUR_X"
  assert_eq "3" "$CUR_Y"

  test_that "move_piece moves left"
  init_board
  CUR_PIECE_TYPE=2
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=3
  move_piece -1 0
  assert_eq "2" "$CUR_X"

  test_that "move_piece moves down"
  init_board
  CUR_PIECE_TYPE=2
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=3
  move_piece 0 1
  assert_eq "4" "$CUR_Y"

  test_that "move_piece fails at left wall"
  init_board
  CUR_PIECE_TYPE=2  # O-piece: blocks at col offsets 1,2
  CUR_ROTATION=0
  CUR_X=-1
  CUR_Y=3
  move_piece -1 0
  assert_eq "1" "$?" "should fail"

  test_that "move_piece fails at bottom"
  init_board
  CUR_PIECE_TYPE=2  # O-piece: row offsets 1,2
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=$((BOARD_HEIGHT - 2))
  move_piece 0 1
  assert_eq "1" "$?" "should fail at bottom"

end_describe

# ── Rotation ─────────────────────────────────────────────────────────────────

describe "Rotation"

  test_that "rotate_piece advances rotation"
  init_board
  CUR_PIECE_TYPE=3  # T-piece
  CUR_ROTATION=0
  CUR_X=4
  CUR_Y=4
  rotate_piece
  assert_eq "1" "$CUR_ROTATION"

  test_that "rotation wraps from 3 to 0"
  init_board
  CUR_PIECE_TYPE=3
  CUR_ROTATION=3
  CUR_X=4
  CUR_Y=4
  rotate_piece
  assert_eq "0" "$CUR_ROTATION"

  test_that "rotation is blocked when it would collide"
  init_board
  # Place I-piece at the right edge — rotating would go out of bounds
  CUR_PIECE_TYPE=1  # I-piece
  CUR_ROTATION=0    # horizontal: needs cols x+0..x+3
  CUR_X=$((BOARD_WIDTH - 4))
  CUR_Y=5
  # rotation 1 is vertical: needs rows y+0..y+3, col x+1
  # But first fill cells that would block rotation 1
  set_board $((CUR_X + 1)) 6 9
  rotate_piece
  assert_eq "0" "$CUR_ROTATION" "rotation should be blocked"

end_describe

# ── Line clearing ────────────────────────────────────────────────────────────

describe "Line clearing"

  test_that "full row is cleared"
  init_board
  # Fill the bottom row completely
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  # After clearing, the bottom row should be empty
  assert_eq "0" "$(get_board 0 $((BOARD_HEIGHT - 1)))"

  test_that "partial row is NOT cleared"
  init_board
  for ((x=0; x<BOARD_WIDTH-1; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  # Row should still be there
  assert_eq "3" "$(get_board 0 $((BOARD_HEIGHT - 1)))"

  test_that "clearing 1 line scores 100 at level 1"
  init_board
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  assert_eq "100" "$SCORE"

  test_that "clearing 2 lines scores 300 at level 1"
  init_board
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
    set_board $x $((BOARD_HEIGHT - 2)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  assert_eq "300" "$SCORE"

  test_that "clearing 3 lines scores 500 at level 1"
  init_board
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
    set_board $x $((BOARD_HEIGHT - 2)) 3
    set_board $x $((BOARD_HEIGHT - 3)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  assert_eq "500" "$SCORE"

  test_that "clearing 4 lines (tetris) scores 800 at level 1"
  init_board
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
    set_board $x $((BOARD_HEIGHT - 2)) 3
    set_board $x $((BOARD_HEIGHT - 3)) 3
    set_board $x $((BOARD_HEIGHT - 4)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  assert_eq "800" "$SCORE"

  test_that "LINES counter increments"
  init_board
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  assert_eq "1" "$LINES"

  test_that "clearing rows shifts cells above downward"
  init_board
  # Put a marker cell on second-to-last row
  set_board 5 $((BOARD_HEIGHT - 2)) 7
  # Fill bottom row
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  SCORE=0; LINES=0; LEVEL=1
  clear_lines
  # The marker should have fallen down one row
  assert_eq "7" "$(get_board 5 $((BOARD_HEIGHT - 1)))"
  assert_eq "0" "$(get_board 5 $((BOARD_HEIGHT - 2)))"

  test_that "level increases every 10 lines"
  init_board
  SCORE=0; LINES=9; LEVEL=1
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  clear_lines
  assert_eq "10" "$LINES"
  assert_eq "2" "$LEVEL"

  test_that "score scales with level"
  init_board
  SCORE=0; LINES=0; LEVEL=3
  for ((x=0; x<BOARD_WIDTH; x++)); do
    set_board $x $((BOARD_HEIGHT - 1)) 3
  done
  clear_lines
  assert_eq "300" "$SCORE" "100 * level 3 = 300"

end_describe

# ── Spawn piece ──────────────────────────────────────────────────────────────

describe "Spawn piece"

  test_that "spawn_piece sets CUR_PIECE_TYPE from NEXT_PIECE_TYPE"
  init_board
  NEXT_PIECE_TYPE=5
  GAME_OVER=0
  spawn_piece
  assert_eq "5" "$CUR_PIECE_TYPE"

  test_that "spawn_piece resets rotation to 0"
  init_board
  NEXT_PIECE_TYPE=3
  GAME_OVER=0
  CUR_ROTATION=2
  spawn_piece
  assert_eq "0" "$CUR_ROTATION"

  test_that "spawn_piece places piece near center"
  init_board
  NEXT_PIECE_TYPE=3
  GAME_OVER=0
  spawn_piece
  assert_eq "3" "$CUR_X" "should be BOARD_WIDTH/2 - 2 = 3"

  test_that "spawn_piece starts at top"
  init_board
  NEXT_PIECE_TYPE=3
  GAME_OVER=0
  spawn_piece
  assert_eq "0" "$CUR_Y"

  test_that "spawn_piece generates a new NEXT_PIECE_TYPE between 1 and 7"
  init_board
  NEXT_PIECE_TYPE=1
  GAME_OVER=0
  spawn_piece
  assert_ge "$NEXT_PIECE_TYPE" 1
  assert_le "$NEXT_PIECE_TYPE" 7

  test_that "spawn_piece triggers GAME_OVER when no room"
  init_board
  # Fill top rows so nothing can spawn
  for ((x=0; x<BOARD_WIDTH; x++)); do
    for ((y=0; y<4; y++)); do
      set_board $x $y 9
    done
  done
  NEXT_PIECE_TYPE=2
  GAME_OVER=0
  spawn_piece
  assert_eq "1" "$GAME_OVER"

end_describe

# ── Hard drop ────────────────────────────────────────────────────────────────

describe "Hard drop"

  test_that "hard_drop moves piece to bottom"
  init_board
  CUR_PIECE_TYPE=2  # O-piece: "0,1 0,2 1,1 1,2" → cols CUR_X+1,CUR_X+2; rows CUR_Y+0,CUR_Y+1
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=0
  SCORE=0; LINES=0; LEVEL=1; GAME_OVER=0
  NEXT_PIECE_TYPE=1
  hard_drop
  # O-piece lands at rows 18,19 (BOARD_HEIGHT-2, BOARD_HEIGHT-1), cols 4,5
  assert_eq "2" "$(get_board 4 $((BOARD_HEIGHT - 1)))"
  assert_eq "2" "$(get_board 5 $((BOARD_HEIGHT - 1)))"
  assert_eq "2" "$(get_board 4 $((BOARD_HEIGHT - 2)))"
  assert_eq "2" "$(get_board 5 $((BOARD_HEIGHT - 2)))"

  test_that "hard_drop awards 2 points per row dropped"
  init_board
  CUR_PIECE_TYPE=2
  CUR_ROTATION=0
  CUR_X=3
  CUR_Y=0
  SCORE=0; LINES=0; LEVEL=1; GAME_OVER=0
  NEXT_PIECE_TYPE=1
  hard_drop
  # O-piece by offsets 0,1. From y=0 it drops to y=18.
  # That's 18 successful move_piece calls → 18 * 2 = 36
  assert_eq "36" "$SCORE"

end_describe

# ── Summary ──────────────────────────────────────────────────────────────────

ptyunit_test_summary
