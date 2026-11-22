#!/bin/bash
# apply_lab13.sh - adds the Lab 13 semaphores to an xv6-riscv tree.
#
#   ./apply_lab13.sh 1 [~/xv6-riscv]   Part 1: numbers + user side only  (Check 1: "unknown sys call 24")
#   ./apply_lab13.sh 2 [~/xv6-riscv]   Part 2: kernel side as well       (Check 2: "semtest: OK")
#
# The script can be run several times: it never adds a line that is already there.
set -e

STAGE="$1"
XV6="${2:-$HOME/xv6-riscv}"
HERE="$(cd "$(dirname "$0")" && pwd)"

if [ "$STAGE" != "1" ] && [ "$STAGE" != "2" ]; then
  echo "usage: $0 1|2 [path-to-xv6-riscv]"; exit 1
fi
[ -f "$XV6/kernel/syscall.h" ] || { echo "no xv6 tree at $XV6"; exit 1; }
cd "$XV6"

# add_after FILE ANCHOR_REGEX MARKER NEW_TEXT
#   inserts NEW_TEXT (may contain \n) after the first line matching ANCHOR_REGEX,
#   unless MARKER is already in the file.
add_after() {
  local file="$1" anchor="$2" marker="$3" text="$4"
  if grep -qF -- "$marker" "$file"; then
    echo "  = $file already has $marker"; return
  fi
  if ! grep -qE -- "$anchor" "$file"; then
    echo "  ! $file: anchor '$anchor' not found, add by hand:"; printf '%b\n' "$text"; return
  fi
  python3 - "$file" "$anchor" "$text" <<'PY'
import re, sys
f, anchor, text = sys.argv[1], sys.argv[2], sys.argv[3].encode().decode('unicode_escape')
lines = open(f).read().split('\n')
for i, l in enumerate(lines):
    if re.search(anchor, l):
        lines[i+1:i+1] = text.split('\n')
        break
open(f, 'w').write('\n'.join(lines))
PY
  echo "  + $file"
}

echo "== Part 1: numbers and the user side"
add_after kernel/syscall.h '^#define SYS_sync' 'SYS_sem_init' \
'#define SYS_sem_init 24   // new\n#define SYS_sem_down 25   // new\n#define SYS_sem_up   26   // new'

add_after user/user.h '^int sync\(void\);' 'sem_init(' \
'int sem_init(int, int);   // new: id, start value\nint sem_down(int);        // new: take one, or sleep\nint sem_up(int);          // new: give one back'

add_after user/usys.pl '^entry\("sync"\);' 'entry("sem_init")' \
'entry("sem_init");       # new\nentry("sem_down");       # new\nentry("sem_up");         # new'

cp "$HERE/user/semtest.c" user/semtest.c && echo "  + user/semtest.c"
cp "$HERE/user/mix.c"     user/mix.c     && echo "  + user/mix.c"

add_after Makefile '^\s*\$U/_zombie\\' '_semtest' '\t$U/_semtest\\\n\t$U/_mix\\'

if [ "$STAGE" = "2" ]; then
  echo "== Part 2: the kernel side"
  cp "$HERE/kernel/sem.c" kernel/sem.c && echo "  + kernel/sem.c"

  add_after Makefile '^\s*\$K/sysproc\.o' '$K/sem.o' '  $K/sem.o \\'

  add_after kernel/syscall.c '^extern uint64 sys_sync\(void\);' 'sys_sem_init(void)' \
'extern uint64 sys_sem_init(void);   // new\nextern uint64 sys_sem_down(void);   // new\nextern uint64 sys_sem_up(void);     // new'

  add_after kernel/syscall.c '^\s*\[SYS_sync\]' '[SYS_sem_init]' \
'  [SYS_sem_init] = sys_sem_init,   // new\n  [SYS_sem_down] = sys_sem_down,   // new\n  [SYS_sem_up]   = sys_sem_up,     // new'
fi

echo
echo "Done. Now:  cd $XV6 && make clean && make qemu   then run: semtest   (Ctrl-A X to quit)"
