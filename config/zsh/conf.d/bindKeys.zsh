bindkey "^[[3~" delete-char # delete
bindkey "^[[1;5D" backward-word # Ctl-left
bindkey "^[[1;5C" forward-word # Ctl-right
bindkey "^[[3;5~" forward-kill-word # Ctl-delete

### glab ###
bindkey "^G" widget::glab::session # C-g
bindkey "^[g" widget::glab::dir # Alt-g