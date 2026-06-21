# Minimal powerlevel10k — run `p10k configure` to customize.
(( ${#options} )) || return

if [[ -r "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# IDEA terminal font is usually not Nerd Font — use ascii there
if [[ "${TERMINAL_EMULATOR:-}" == *JetBrains* ]] || [[ -n "${INTELLIJ_TERMINAL:-}" ]]; then
  typeset -g POWERLEVEL9K_MODE=ascii
  typeset -g POWERLEVEL9K_INSTANT_PROMPT=off
else
  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
fi
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_GAP=0
typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_GAP=0

typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
  dir
  vcs
  newline
  prompt_char
)

typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
  status
  command_execution_time
  background_jobs
)

typeset -g POWERLEVEL9K_SHORTEN_STRATEGY=truncate_to_unique
typeset -g POWERLEVEL9K_DIR_MAX_LENGTH=3
typeset -g POWERLEVEL9K_VCS_DISABLED_WORKDIR_PATTERN='~'
typeset -g POWERLEVEL9K_VCS_BRANCH_ICON=''
typeset -g POWERLEVEL9K_STATUS_OK=false
typeset -g POWERLEVEL9K_STATUS_ERROR=false
typeset -g POWERLEVEL9K_COMMAND_EXECUTION_TIME_THRESHOLD=3
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VIINS='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VIINS='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_VICMD='❮'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_VICMD='❮'

(( ! ${+functions[p10k]} )) || p10k reload
