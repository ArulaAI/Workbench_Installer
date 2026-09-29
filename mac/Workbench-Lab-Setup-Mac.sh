#!/usr/bin/env bash
#
# Workbench-Lab-Setup-Mac.sh
#
# Installs and validates Workbench on macOS. Mirrors
# "Mac OS Workbench Installer" in Workbench-Lab-Setup-Mac.md.
#
# Usage:
#   bash Workbench-Lab-Setup-Mac.sh
#
# Safe to re-run: existing installation stages are detected and reused.
#
# Optional overrides:
#   INSTALL_DIR     (default: ~/Lab)
#   WORKBENCH_DIR   (default: ~/Lab/workbench)
#   FIXTURE_DIR     (default: ~/Lab/payments-validation-fixture)

set -uo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/Lab}"
WORKBENCH_DIR="${WORKBENCH_DIR:-$INSTALL_DIR/workbench}"
FIXTURE_DIR="${FIXTURE_DIR:-$INSTALL_DIR/payments-validation-fixture}"
WORKBENCH_REPO="https://github.com/ArulaAI/workbench.git"
WORKBENCH_BRANCH="feat/301-latest"
FIXTURE_REPO="https://github.com/ArulaAI/payments-validation-fixture.git"
FIXTURE_BRANCH="round-0"
ZSHRC_MARKER="# Workbench (Workbench-Lab-Setup-Mac.sh)"
BREW_BIN=""
BREW_PREFIX=""
BASH_BIN=""
WORKBENCH_ACTIVE_VERIFIED=0
WORKBENCH_FRESH_VERIFIED=0

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  {
    printf '\n    \033[31m✗ %s\033[0m\n' "$1" >&2
    [[ $# -gt 1 ]] && printf '      Try: %s\n' "$2" >&2
    exit 1
}

prepend_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
    export PATH
}

append_path() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$PATH:$1" ;;
    esac
    export PATH
}

discover_homebrew() {
    local candidate=""
    local login_candidate=""

    if [[ -n "${HOMEBREW_PREFIX:-}" && -x "${HOMEBREW_PREFIX}/bin/brew" ]]; then
        candidate="${HOMEBREW_PREFIX}/bin/brew"
    elif command -v brew >/dev/null 2>&1; then
        candidate="$(command -v brew)"
    elif [[ -x /opt/homebrew/bin/brew ]]; then
        candidate="/opt/homebrew/bin/brew"
    elif [[ -x /usr/local/bin/brew ]]; then
        candidate="/usr/local/bin/brew"
    elif [[ -x /bin/zsh ]]; then
        login_candidate="$(/bin/zsh -lic 'command -v brew' 2>/dev/null | /usr/bin/tail -n 1 || true)"
        [[ -n "$login_candidate" && -x "$login_candidate" ]] && candidate="$login_candidate"
    fi

    if [[ -n "$candidate" ]]; then
        BREW_BIN="$candidate"
        BREW_PREFIX="$("$BREW_BIN" --prefix 2>/dev/null)" \
            || die "Homebrew could not report its installation prefix." "Run '$BREW_BIN --prefix', resolve the reported Homebrew error, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
        append_path "$BREW_PREFIX/bin"
        append_path "$BREW_PREFIX/sbin"
        hash -r
    fi
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || die "$1 was not found." "$2"
}

discover_compatible_bash() {
    local candidate
    for candidate in \
        "${BREW_PREFIX:+$BREW_PREFIX/bin/bash}" \
        /opt/homebrew/bin/bash \
        /usr/local/bin/bash \
        "$(command -v bash 2>/dev/null || true)"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        if "$candidate" -c '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) ))' 2>/dev/null; then
            BASH_BIN="$candidate"
            return 0
        fi
    done
    return 1
}

clone_with_retries() {
    local repo="$1"
    local destination="$2"
    local branch="${3:-}"
    local attempt

    for attempt in 1 2 3; do
        info "Clone attempt $attempt of 3: $repo"
        if [[ -n "$branch" ]]; then
            git clone --branch "$branch" "$repo" "$destination" && return 0
        else
            git clone "$repo" "$destination" && return 0
        fi
        [[ ! -e "$destination" ]] || return 2
        [[ $attempt -eq 3 ]] || info "The clone was interrupted; retrying."
    done
    return 1
}

jq_works() {
    printf '{}\n' | jq -e . >/dev/null 2>&1
}

skills_doctor_output_is_healthy() {
    [[ "$1" == *"skills doctor: healthy"* && "$1" == *"0 issue(s)"* ]]
}

skills_doctor_healthy() {
    local output
    output="$(cd "$FIXTURE_DIR" && workbench skills doctor 2>&1)" || return 1
    skills_doctor_output_is_healthy "$output"
}

configure_workbench_env() {
    export SPEED_DIR="$WORKBENCH_DIR"
    export SPEED_PYTHON="$WORKBENCH_DIR/.venv/bin/python3"
    prepend_path "$WORKBENCH_DIR"
}

step "Checking macOS and required prerequisites"
[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS (detected: $(uname -s))." "Run this installer on a supported macOS computer."
if ! /usr/bin/xcode-select -p >/dev/null 2>&1 || ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
    die \
        "Apple Command Line Tools and the compiler are required but were not found." \
        "Run 'xcode-select --install', complete the macOS installer, open a new Terminal window, and rerun 'bash Workbench-Lab-Setup-Mac.sh'. On a managed Mac, use your approved software catalog or contact IT support if installation is restricted."
fi
ok "Apple Command Line Tools: $(/usr/bin/xcode-select -p)"
discover_homebrew
if [[ -n "$BREW_BIN" ]]; then
    ok "Homebrew available for prerequisite recovery: $BREW_BIN ($("$BREW_BIN" --version | /usr/bin/head -n 1))"
else
    info "Homebrew is not on PATH. It is needed only if a prerequisite must be installed or upgraded."
fi
info "Architecture: $(uname -m)"

step "Validating the required command-line dependencies"
if ! discover_compatible_bash; then
    detected_bash="$(bash --version 2>/dev/null | /usr/bin/head -n 1 || printf 'not found')"
    die "Bash 4.3 or newer is required. Detected: $detected_bash" "Install or upgrade Bash through your approved software source (Homebrew: 'brew install bash'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
fi
require_command curl "Install curl through your approved software source, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command git "Install Git through your approved software source (Homebrew: 'brew install git'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command jq "Install jq through your approved software source (Homebrew: 'brew install jq'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
jq_works || die "jq is installed but could not process JSON." "Repair or reinstall jq through your approved software source (Homebrew: 'brew reinstall jq'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command gtimeout "Install GNU coreutils through your approved software source (Homebrew: 'brew install coreutils'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command uv "Install uv through your approved software source (Homebrew: 'brew install uv'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command node "Install Node.js through your approved software source (Homebrew: 'brew install node'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command npm "Install npm with Node.js through your approved software source, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command claude "Install Claude Code through your approved software source (npm: 'npm install -g @anthropic-ai/claude-code'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
require_command tree-sitter "Install the Tree-sitter CLI through your approved software source (npm: 'npm install -g tree-sitter-cli'), then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "Required command-line dependencies are available"
info "Bash: $("$BASH_BIN" --version | /usr/bin/head -n 1)"
info "curl: $(curl --version | /usr/bin/head -n 1)"
info "Git: $(git --version)"
info "jq: $(jq --version)"
info "coreutils: $(gtimeout --version | /usr/bin/head -n 1)"
info "uv: $(uv --version)"
info "Node.js: $(node --version)"
info "npm: $(npm --version)"
info "Claude Code: $(claude --version)"
info "tree-sitter: $(tree-sitter --version)"

step "Preparing the Lab workspace"
mkdir -p "$INSTALL_DIR" \
    || die "Could not create the Lab workspace at $INSTALL_DIR." "Resolve the directory ownership or permission issue, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
[[ -d "$INSTALL_DIR" && -w "$INSTALL_DIR" ]] \
    || die "The Lab workspace is not writable: $INSTALL_DIR." "Resolve the directory ownership or permission issue, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
if [[ "$WORKBENCH_DIR" == "$HOME/Lab/workbench" && ! -e "$WORKBENCH_DIR" && -d "$HOME/workbench/.git" ]]; then
    die "A previous Workbench clone exists at $HOME/workbench." "Preserve or remove the previous clone intentionally, then rerun the installer to create the standardized clone at $WORKBENCH_DIR. The installer will not move or delete the existing repository."
fi
if [[ "$FIXTURE_DIR" == "$HOME/Lab/payments-validation-fixture" && ! -e "$FIXTURE_DIR" && -d "$HOME/payments-validation-fixture/.git" ]]; then
    die "A previous payments fixture clone exists at $HOME/payments-validation-fixture." "Preserve or remove the previous clone intentionally, then rerun the installer to create the standardized clone at $FIXTURE_DIR. The installer will not move or delete the existing repository."
fi
ok "Lab workspace: $INSTALL_DIR"

step "Cloning Workbench and selecting $WORKBENCH_BRANCH"
if [[ -d "$WORKBENCH_DIR/.git" ]]; then
    workbench_origin="$(git -C "$WORKBENCH_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$workbench_origin" == *"ArulaAI/workbench"* ]] \
        || die "$WORKBENCH_DIR does not use the expected Workbench origin." "Review 'git -C \"$WORKBENCH_DIR\" remote -v'. Preserve the directory and use a verified Workbench clone before rerunning."
    git -C "$WORKBENCH_DIR" fetch origin "$WORKBENCH_BRANCH" \
        || die "Git could not check the current Workbench branch against origin." "Confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    current_branch="$(git -C "$WORKBENCH_DIR" branch --show-current)"
    if [[ "$current_branch" != "$WORKBENCH_BRANCH" ]]; then
        [[ -z "$(git -C "$WORKBENCH_DIR" status --porcelain --untracked-files=no)" ]] \
            || die "$WORKBENCH_DIR is on '$current_branch' and has local tracked changes." "Commit or preserve those changes before switching branches and rerunning the installer."
        git -C "$WORKBENCH_DIR" switch "$WORKBENCH_BRANCH" \
            || die "Git could not switch to $WORKBENCH_BRANCH." "From '$WORKBENCH_DIR', preserve local changes and run 'git switch $WORKBENCH_BRANCH', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    fi
    workbench_relation="$(git -C "$WORKBENCH_DIR" rev-list --left-right --count HEAD...origin/"$WORKBENCH_BRANCH" 2>/dev/null)" \
        || die "Git could not compare the Workbench checkout with origin/$WORKBENCH_BRANCH." "Review the repository state, then rerun the installer."
    [[ "$workbench_relation" == $'0\t0' ]] \
        || die "The existing Workbench checkout is not current with origin/$WORKBENCH_BRANCH (local/remote counts: $workbench_relation)." "From '$WORKBENCH_DIR', review the branch and run 'git pull --ff-only' when appropriate, then rerun the installer."
    ok "Using the existing clone at $WORKBENCH_DIR"
elif [[ -e "$WORKBENCH_DIR" ]]; then
    die "$WORKBENCH_DIR exists but is not a complete Git repository." "Move the incomplete directory aside, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
else
    clone_with_retries "$WORKBENCH_REPO" "$WORKBENCH_DIR" "$WORKBENCH_BRANCH"
    clone_status=$?
    if [[ $clone_status -eq 2 ]]; then
        die "The Workbench clone was interrupted and left an incomplete directory at $WORKBENCH_DIR." "Move the incomplete directory aside, confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    elif [[ $clone_status -ne 0 ]]; then
        die "Git could not clone Workbench after 3 attempts." "Confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    fi
    ok "Cloned Workbench to $WORKBENCH_DIR"
fi
[[ "$(git -C "$WORKBENCH_DIR" branch --show-current)" == "$WORKBENCH_BRANCH" ]] \
    || die "Workbench is not on $WORKBENCH_BRANCH." "From '$WORKBENCH_DIR', preserve local changes and run 'git switch $WORKBENCH_BRANCH', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "Workbench branch: $WORKBENCH_BRANCH"

step "Creating the isolated Python environment"
[[ -f "$WORKBENCH_DIR/requirements.txt" ]] || die "$WORKBENCH_DIR/requirements.txt was not found." "Move the incomplete Workbench checkout aside, then rerun 'bash Workbench-Lab-Setup-Mac.sh' to create a fresh clone."
(
    cd "$WORKBENCH_DIR" || exit 1
    uv python install 3.12 &&
    uv venv --python 3.12 .venv &&
    uv pip install -r requirements.txt --python .venv/bin/python3
) || die "The Workbench Python environment could not be prepared." "Review the uv output, resolve the reported package or network issue, and rerun."
VENV_PY="$WORKBENCH_DIR/.venv/bin/python3"
[[ -x "$VENV_PY" ]] \
    || die "Workbench Python was not created at $VENV_PY." "Run 'uv python install 3.12', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
"$VENV_PY" -c 'import sys; sys.exit(sys.version_info < (3, 12))' \
    || die "Python 3.12 or newer is required (detected: $("$VENV_PY" --version 2>&1 || printf 'unknown'))." "Run 'uv python install 3.12', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
"$VENV_PY" -c "import yaml, tree_sitter, sklearn, networkx; print('Python dependencies: PASS')" \
    || die "A required Workbench Python package could not be imported." "From '$WORKBENCH_DIR', run 'uv pip install -r requirements.txt --python .venv/bin/python3', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "$($VENV_PY --version)"

step "Building the custom language grammars"
[[ -x "$WORKBENCH_DIR/scripts/build-grammars.sh" ]] \
    || die "$WORKBENCH_DIR/scripts/build-grammars.sh was not found or is not executable." "Move the incomplete Workbench checkout aside, then rerun 'bash Workbench-Lab-Setup-Mac.sh' to create a fresh clone."
(cd "$WORKBENCH_DIR" && ./scripts/build-grammars.sh --clean) \
    || die "The custom language grammar build failed." "Review the build output and rerun the installer after correcting the reported issue."
ok "Custom language grammars built"

step "Adding Workbench to zsh"
touch "$HOME/.zshrc" \
    || die "Could not create or access $HOME/.zshrc." "Run 'ls -l \"$HOME/.zshrc\"', resolve the file ownership or permission issue, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
if grep -qF "$ZSHRC_MARKER" "$HOME/.zshrc" 2>/dev/null; then
    zshrc_tmp="$HOME/.zshrc.workbench-tmp"
    awk -v marker="$ZSHRC_MARKER" '
        $0 == marker { skip = 3; next }
        skip > 0 { skip--; next }
        { print }
    ' "$HOME/.zshrc" > "$zshrc_tmp" \
        && mv "$zshrc_tmp" "$HOME/.zshrc" \
        || die "Could not update the installer-managed Workbench block in $HOME/.zshrc." "Run 'ls -l \"$HOME/.zshrc\"', resolve the file ownership or permission issue, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
fi
{
    printf '\n%s\n' "$ZSHRC_MARKER"
    printf 'export SPEED_DIR="%s"\n' "$WORKBENCH_DIR"
    printf 'export PATH="$SPEED_DIR:$PATH"\n'
    printf 'export SPEED_PYTHON="$SPEED_DIR/.venv/bin/python3"\n'
} >> "$HOME/.zshrc" \
    || die "Could not write the Workbench configuration to $HOME/.zshrc." "Run 'ls -l \"$HOME/.zshrc\"', resolve the file ownership or permission issue, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "Configured Workbench at $WORKBENCH_DIR in ~/.zshrc"
configure_workbench_env

step "Verifying Workbench in the active and fresh zsh environments"
workbench help >/dev/null 2>&1 \
    || die "workbench help failed in the active environment." "Run '$WORKBENCH_DIR/workbench help' to inspect the error, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
WORKBENCH_ACTIVE_VERIFIED=1
/bin/zsh -lic 'workbench help >/dev/null && [[ -x "$SPEED_PYTHON" ]]' \
    || die "Workbench failed verification in a fresh zsh environment." "Open a new Terminal window, inspect ~/.zshrc, and rerun the installer."
WORKBENCH_FRESH_VERIFIED=1
ok "Workbench fresh-terminal check: PASS"

step "Preparing the payments validation fixture on $FIXTURE_BRANCH"
if [[ -d "$FIXTURE_DIR/.git" ]]; then
    fixture_origin="$(git -C "$FIXTURE_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$fixture_origin" == *"ArulaAI/payments-validation-fixture"* ]] \
        || die "$FIXTURE_DIR does not use the expected payments fixture origin." "Review 'git -C \"$FIXTURE_DIR\" remote -v'. Preserve the directory and use a verified fixture clone before rerunning."
    git -C "$FIXTURE_DIR" fetch origin main "$FIXTURE_BRANCH" \
        || die "Git could not check the payments fixture against origin." "Confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    fixture_current_branch="$(git -C "$FIXTURE_DIR" branch --show-current)"
    if [[ "$fixture_current_branch" != "$FIXTURE_BRANCH" ]]; then
        [[ -z "$(git -C "$FIXTURE_DIR" status --porcelain --untracked-files=no)" ]] \
            || die "$FIXTURE_DIR is on '$fixture_current_branch' and has local tracked changes." "Commit or preserve those changes before switching branches and rerunning the installer."
        git -C "$FIXTURE_DIR" switch "$FIXTURE_BRANCH" \
            || die "Git could not switch the payments fixture to $FIXTURE_BRANCH." "From '$FIXTURE_DIR', run 'git switch $FIXTURE_BRANCH', then rerun."
    fi
    fixture_relation="$(git -C "$FIXTURE_DIR" rev-list --left-right --count HEAD...origin/"$FIXTURE_BRANCH" 2>/dev/null)" \
        || die "Git could not compare the payments fixture with origin/$FIXTURE_BRANCH." "Review the repository state, then rerun the installer."
    [[ "$fixture_relation" == $'0\t0' ]] \
        || die "The existing payments fixture is not current with origin/$FIXTURE_BRANCH (local/remote counts: $fixture_relation)." "From '$FIXTURE_DIR', review the branch and run 'git pull --ff-only' when appropriate, then rerun the installer."
    ok "Using the existing payments fixture at $FIXTURE_DIR"
elif [[ -e "$FIXTURE_DIR" ]]; then
    die "$FIXTURE_DIR exists but is not a complete Git repository." "Move the incomplete directory aside, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
else
    clone_with_retries "$FIXTURE_REPO" "$FIXTURE_DIR"
    clone_status=$?
    if [[ $clone_status -eq 2 ]]; then
        die "The payments fixture clone was interrupted and left an incomplete directory at $FIXTURE_DIR." "Move the incomplete directory aside, confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    elif [[ $clone_status -ne 0 ]]; then
        die "Git could not clone the payments validation fixture after 3 attempts." "Confirm GitHub, VPN, or proxy access, then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
    fi
    git -C "$FIXTURE_DIR" switch "$FIXTURE_BRANCH" \
        || die "Git could not switch the payments fixture to $FIXTURE_BRANCH." "From '$FIXTURE_DIR', run 'git switch $FIXTURE_BRANCH', then rerun."
    ok "Cloned the payments fixture to $FIXTURE_DIR"
fi
if ! git -C "$FIXTURE_DIR" show-ref --verify --quiet refs/heads/main; then
    if ! git -C "$FIXTURE_DIR" show-ref --verify --quiet refs/remotes/origin/main; then
        git -C "$FIXTURE_DIR" fetch origin main:refs/remotes/origin/main \
            || die "Git could not fetch the main baseline for the payments fixture." "Confirm access to GitHub or your approved mirror, then rerun."
    fi
    git -C "$FIXTURE_DIR" branch main origin/main \
        || die "Git could not create the local main baseline for the payments fixture." "From '$FIXTURE_DIR', run 'git branch main origin/main', then rerun."
fi
[[ "$(git -C "$FIXTURE_DIR" branch --show-current)" == "$FIXTURE_BRANCH" ]] \
    || die "The payments fixture is not on $FIXTURE_BRANCH." "From '$FIXTURE_DIR', run 'git switch $FIXTURE_BRANCH', then rerun."
ok "Payments fixture branch: $FIXTURE_BRANCH"

step "Initializing Workbench in the payments validation fixture"
(cd "$FIXTURE_DIR" && workbench init --harness claude) \
    || die "Workbench could not initialize the Claude harness in $FIXTURE_DIR." "Review the command output, correct the reported issue, and rerun."
[[ -f "$FIXTURE_DIR/.claude/skills/workbench-health/SKILL.md" ]] \
    || die "The Claude Workbench harness was not projected into $FIXTURE_DIR." "From '$FIXTURE_DIR', run 'workbench init --harness claude', then rerun."
ok "Claude Workbench harness initialized"

step "Verifying SPEED from the payments validation fixture"
(cd "$FIXTURE_DIR" && speed help >/dev/null 2>&1) \
    || die "speed help failed from the payments validation fixture." "From '$FIXTURE_DIR', run 'speed help' to inspect the error, resolve it, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "speed help: PASS"

step "Verifying and synchronizing Workbench skills"
(cd "$FIXTURE_DIR" && workbench skills status) \
    || die "Workbench could not read the fixture skill status." "From '$FIXTURE_DIR', run 'workbench skills status', resolve the reported error, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
(cd "$FIXTURE_DIR" && workbench skills sync) \
    || die "Workbench could not synchronize the fixture skills." "From '$FIXTURE_DIR', run 'workbench skills sync', resolve the reported error, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
if ! skills_doctor_output="$(cd "$FIXTURE_DIR" && workbench skills doctor 2>&1)"; then
    printf '%s\n' "$skills_doctor_output"
    die "Workbench skills doctor could not complete." "From '$FIXTURE_DIR', run 'workbench init --harness claude' and 'workbench skills sync', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
fi
printf '%s\n' "$skills_doctor_output"
skills_doctor_output_is_healthy "$skills_doctor_output" \
    || die "Workbench skills doctor did not report healthy with 0 issues." "From '$FIXTURE_DIR', run 'workbench init --harness claude' and 'workbench skills sync', then rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "Workbench skills doctor: healthy with 0 issues"

step "Readiness check"
failed=0
check() {
    if eval "$2" >/dev/null 2>&1; then
        printf '    \033[32mPASS\033[0m  %s\n' "$1"
    else
        printf '    \033[31mFAIL\033[0m  %s\n' "$1"
        [[ $# -gt 2 ]] && printf '          Try: %s\n' "$3"
        failed=$((failed + 1))
    fi
}
check "Bash 4.3+"              '"$BASH_BIN" -c '\''(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 3) ))'\''' "Install or upgrade Bash through your approved software source, then rerun the installer."
check "curl"                   'curl --version' "Install curl through your approved software source, then rerun the installer."
check "Git"                    'git --version' "Install Git through your approved software source, then rerun the installer."
check "jq"                     'jq_works' "Install or repair jq through your approved software source, then rerun the installer."
check "GNU coreutils"          'gtimeout --version' "Run 'brew install coreutils', then rerun the installer."
check "uv"                     'uv --version' "Run 'brew install uv', then rerun the installer."
check "Node.js"                'node --version' "Install Node.js through your approved software source, then rerun the installer."
check "npm"                    'npm --version' "Install or repair npm with Node.js through your approved software source, then rerun the installer."
check "Claude Code"            'claude --version' "Install Claude Code through your approved software source, then rerun the installer."
check "tree-sitter CLI"        'tree-sitter --version' "Install the Tree-sitter CLI through your approved software source, then rerun the installer."
check "Python 3.12+"           '"$SPEED_PYTHON" -c '\''import sys; sys.exit(sys.version_info < (3,12))'\''' "Run 'uv python install 3.12', then rerun the installer."
check "Python dependencies"    '"$SPEED_PYTHON" -c '\''import yaml, tree_sitter, sklearn, networkx'\''' "Reinstall requirements.txt in the Workbench virtual environment, then rerun the installer."
check "Workbench verified"     '[[ "$WORKBENCH_ACTIVE_VERIFIED" -eq 1 && "$WORKBENCH_FRESH_VERIFIED" -eq 1 ]]' "Rerun the installer so the active and fresh-terminal Workbench checks can complete."
check "SPEED from fixture"     '(cd "$FIXTURE_DIR" && speed help)' "From the payments fixture, run 'speed help', resolve the reported error, and rerun the installer."
check "Workbench branch"       '[[ "$(git -C "$SPEED_DIR" branch --show-current)" == "feat/301-latest" ]]' "Review the Workbench repository branch, then rerun the installer."
check "Payments fixture"       '[[ -d "$FIXTURE_DIR/.git" ]]' "Confirm the payments validation fixture was cloned, then rerun the installer."
check "Fixture main branch"    'git -C "$FIXTURE_DIR" show-ref --verify --quiet refs/heads/main' "Fetch origin/main and create the local main branch, then rerun the installer."
check "Fixture round-0"        '[[ "$(git -C "$FIXTURE_DIR" branch --show-current)" == "round-0" ]]' "Preserve local changes, switch to round-0, and rerun the installer."
check "Fixture Workbench"      '[[ -f "$FIXTURE_DIR/speed.toml" ]]' "Rerun the installer to initialize Workbench in the fixture."
check "Claude harness"         '[[ -f "$FIXTURE_DIR/.claude/skills/workbench-health/SKILL.md" ]]' "From the fixture, run 'workbench init --harness claude', then rerun the installer."
check "Skills doctor healthy"  'skills_doctor_healthy' "From the fixture, run 'workbench init --harness claude' and 'workbench skills sync', then rerun the installer."
check "Round 0 diff"           '[[ -n "$(git -C "$FIXTURE_DIR" diff --name-only main...round-0)" ]]' "Confirm the main and round-0 branches are available, then rerun the installer."

echo
if [[ $failed -eq 0 ]]; then
    printf '\033[1;32mWorkbench is ready.\033[0m\n'
else
    printf '\033[1;31m%d readiness check(s) failed.\033[0m\n' "$failed"
fi

cat <<EOF

Remaining manual check:
  1. Open a new Terminal window.
  2. Run: cd "$FIXTURE_DIR" && claude
  3. Inside Claude Code, run: /workbench-health
  4. Confirm the result reports: Status: healthy
  5. Exit Claude Code.
  6. Run: cd "$FIXTURE_DIR" && git --no-pager diff --stat main...round-0
  7. Confirm that the changed-file summary and total are displayed.
  8. Run: cd "$FIXTURE_DIR" && speed help. Confirm that the SPEED help and available commands are displayed without errors.
  9. When the health check, Round 0 summary, and SPEED help are confirmed: You are all set for the lab.
EOF

exit $((failed > 0))
