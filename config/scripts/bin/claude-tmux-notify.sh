#!/bin/bash
# Claude Code → tmux ベル通知。
# claude ペイン自身の制御端末(/dev/tty)に BEL を送ることで、フォーカス外の
# window でも tmux が該当 window に ⏳ を付けられるようにする。
[ -n "$TMUX" ] || exit 0
printf '\a' > /dev/tty 2>/dev/null || true
