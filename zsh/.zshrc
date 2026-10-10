export PATH="$HOME/.local/bin:$PATH"

# Up/Down arrow: search history matching the current prefix
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

# aliases
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias rwm='yabai --restart-service && skhd --restart-service'
alias claude='claude --dangerously-skip-permissions'
alias oc='opencode .'
alias bj='blackjack-tui'

export JAVA_HOME="/opt/homebrew/opt/openjdk"

function y() {
	local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
	command yazi "$@" --cwd-file="$tmp"
	IFS= read -r -d '' cwd < "$tmp"
	[ "$cwd" != "$PWD" ] && [ -d "$cwd" ] && builtin cd -- "$cwd"
	command rm -f -- "$tmp"
}

# bun completions
[ -s "/Users/mrodhansen/.bun/_bun" ] && source "/Users/mrodhansen/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
export EDITOR=nvim
export VISUAL=nvim

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
