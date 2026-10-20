# --- Base PATH Setup (CRITICAL: Must be at the very top) ---
# This explicitly defines the initial PATH, ensuring fundamental system binaries are available
# and includes Homebrew's default binary paths for early detection.
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- Oh My Zsh configuration ---
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="bureau" # Or your preferred theme

# Oh My Zsh settings
zstyle ':omz:update' mode auto
zstyle ':omz:update' frequency 7
HIST_STAMPS="yyyy-mm-dd"

# Oh My Zsh plugins (add or remove as needed)
plugins=(
  git
  zsh-autosuggestions
  zsh-syntax-highlighting
)

# Source Oh My Zsh - This comes after initial PATH setup.
source "$ZSH/oh-my-zsh.sh"


# --- Custom User PATH Additions and Configurations ---

# Homebrew environment setup (from 'brew shellenv' - recommended by Homebrew)
eval "$(/opt/homebrew/bin/brew shellenv)"

# Homebrew Python path (ensure it's only added once - redundant if brew shellenv handles it, but kept for certainty)
# export PATH="/opt/homebrew/opt/python@3.12/libexec/bin:$PATH"

# Node Version Manager (NVM) setup
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# --- Managed by Rancher Desktop (DO NOT EDIT) ---
# Moved here to ensure goenv shims are at the front of PATH.
export PATH="/Users/riaz/.rd/bin:$PATH"
# --- MANAGED BY RANCHER DESKTOP END ---

# Kubeconfig and Go Private Repo settings
export KUBECONFIG="/Users/riaz/.kube/config"
# export GOPRIVATE="github.kyndryl.net/Observe-Automation/*"
# export GOPRIVATE="github.com/kyndryl-cto/*"
export GOPRIVATE="github.com/kyndryl*"

# Preferred editor for local and remote sessions (example, uncomment if needed)
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='nvim'
# fi

# Compilation flags (example, uncomment if needed)
# export ARCHFLAGS="-arch $(uname -m)"


# --- Aliases ---
alias zshconfig="code ~/.zshrc"
alias ohmyzsh="code ~/.oh-my-zsh"
alias c="clear"
alias clean="echo > ~/.zsh_history && kill -9 $$" # Use with caution, nukes history for current session
alias g="go run main.go"
alias cg="cd cmd && go run main.go"
alias gpm="git pull origin master --rebase"
alias gpmn="git pull origin main --rebase"
swagger() {
    local module_dir

    if [[ -f ./cmd/main.go ]]; then
        module_dir="."
    elif [[ -f ./sms-server/cmd/main.go ]]; then
        module_dir="./sms-server"
    else
        print -u2 "swagger: no cmd/main.go found in this directory or ./sms-server"
        return 1
    fi

    (
        cd "$module_dir" || return
        swag fmt && swag init --parseInternal -g ./cmd/main.go -o ./docs
    )
}
alias pretty="npx prettier --write ."
alias eslint="npx eslint --fix ."
alias i="bash ./install.sh"
alias u="bash ./uninstall.sh"
alias up="docker-compose up -d --build"
alias down="docker-compose down"
alias nd="npm run dev"

alias log="kubectl logs -n observe -f"
alias lg="bash /Users/riaz/Documents/personal/automations/logs/podlogs.sh"
alias pods="kubectl get pods -n observe"
alias deployments="kubectl get deployments -n observe"
alias jobs="kubectl get jobs -n observe"
# alias mods="bash /Users/riaz/Documents/personal/automations/go/update-mods/update-mods.sh"
# alias merge2main="bash /Users/riaz/Documents/personal/automations/git/merge2main.sh"
# alias sbx="cd '/Users/riaz/OneDrive - kyndryl/sandbox' && code ."
alias sbx="code '/Users/riaz/Documents/personal/sandbox/'"


# # --- Go Test Aliases ---
# # NOTE: Adjusted the grep pattern for coverage to be more robust.
# # test package by package
# alias tp='go test -coverpkg=./... -covermode=atomic -coverprofile=coverage.out.tmp `go list ./... | grep -vE ".*_mocks\.go$"` && cat coverage.out.tmp | grep -vE ".*_mocks\.go$" > coverage.out && go tool cover -func=coverage.out | grep total | grep -Eo "[0-9]+\.[0-9]+%"'
# # test all packages recursively
# alias t='go test -coverpkg=./... -covermode=atomic -coverprofile=coverage.out.tmp `find . -name "*.go" ! -name "*_mocks.go" ! -name "*_test.go" -not -path "*/vendor/*" -exec dirname {} \; | sort | uniq` && \
# cat coverage.out.tmp | grep -vE ".*_mocks\.go$|.*_test\.go$" > coverage.out && \
# go tool cover -func=coverage.out | grep total | grep -Eo "[0-9]+\.[0-9]+%"'
# # test all packages and open HTML coverage report
# alias test='go test -coverpkg=./... -covermode=atomic -coverprofile=coverage.out.tmp `find . -name "*.go" ! -name "*_mocks.go" ! -name "*_test.go" -not -path "*/vendor/*" -exec dirname {} \; | sort | uniq` && \
# cat coverage.out.tmp | grep -vE ".*_mocks\.go$|.*_test\.go$" > coverage.out && \
# go tool cover -html=coverage.out'
# alias seecoverage="go tool cover -html=coverage.out" # For direct HTML viewing

### MANAGED BY RANCHER DESKTOP START (DO NOT EDIT)
export PATH="/Users/riaz/.rd/bin:$PATH"
### MANAGED BY RANCHER DESKTOP END (DO NOT EDIT)

. "$HOME/.local/bin/env"

# # >>> conda initialize >>>
# # !! Contents within this block are managed by 'conda init' !!
# __conda_setup="$('/Users/riaz/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
# if [ $? -eq 0 ]; then
#     eval "$__conda_setup"
# else
#     if [ -f "/Users/riaz/miniconda3/etc/profile.d/conda.sh" ]; then
#         . "/Users/riaz/miniconda3/etc/profile.d/conda.sh"
#     else
#         export PATH="/Users/riaz/miniconda3/bin:$PATH"
#     fi
# fi
# unset __conda_setup
# conda deactivate
# # <<< conda initialize <<<

# shell integration for VSCode terminal (MUST be last to avoid conda/theme overriding output markers)
[[ "$TERM_PROGRAM" == "vscode" ]] && . "$(code --locate-shell-integration-path zsh)"
export PATH="$PATH:/usr/local/go/bin"
