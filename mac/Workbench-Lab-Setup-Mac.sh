#!/usr/bin/env bash
#
# Workbench-Lab-Setup-Mac.sh
#
# Configures Workbench using preinstalled system tools and Python. Mirrors
# "Mac OS Workbench Installer" in Workbench-Lab-Setup-macOS.md.
#
# Usage:
#   bash Workbench-Lab-Setup-Mac.sh
#
# Safe to re-run: existing repositories and setup are detected and reused.
# Creates a venv and installs requirements.txt. Custom Prisma, GraphQL,
# Protobuf, and Zig grammars are optional and are not needed by this lab.
# Never installs system tools or downloads a Python runtime.
#
# Optional overrides:
#   INSTALL_DIR     (default: ~/Lab)
#   WORKBENCH_DIR   (default: ~/Lab/workbench)
#   FIXTURE_DIR     (default: ~/Lab/payments-validation-fixture)
#   SPEED_PYTHON    (existing interpreter; otherwise .venv/bin/python3 or python3 on PATH)

set -uo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/Lab}"
WORKBENCH_DIR="${WORKBENCH_DIR:-$INSTALL_DIR/workbench}"
FIXTURE_DIR="${FIXTURE_DIR:-$INSTALL_DIR/payments-validation-fixture}"
WORKBENCH_REPO="https://github.com/ArulaAI/workbench.git"
WORKBENCH_BRANCH="feat/301-latest"
FIXTURE_REPO="https://github.com/ArulaAI/payments-validation-fixture.git"
FIXTURE_BRANCH="round-0"
ZSHRC_MARKER="# Workbench (Workbench-Lab-Setup-Mac.sh)"
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

require_command() {
    local label="$1"
    [[ $# -lt 3 ]] || label="$1 ($3)"
    command -v "$1" >/dev/null 2>&1 || die "$label was not found." "$2"
}

discover_compatible_bash() {
    local candidate
    for candidate in \
        /bin/bash \
        "$(command -v bash 2>/dev/null || true)"; do
        [[ -n "$candidate" && -x "$candidate" ]] || continue
        if "$candidate" -c '(( BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2) ))' 2>/dev/null; then
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
    local version
    version="$(jq --version 2>/dev/null)" || return 1
    [[ "$version" =~ ^jq-([0-9]+)\.([0-9]+) ]] || return 1
    (( BASH_REMATCH[1] > 1 || (BASH_REMATCH[1] == 1 && BASH_REMATCH[2] >= 7) )) || return 1
    printf '{}\n' | jq -e . >/dev/null 2>&1
}

node_works() {
    node -e 'const [major, minor] = process.versions.node.split(".").map(Number); process.exit(major > 22 || (major === 22 && minor >= 18) ? 0 : 1)' >/dev/null 2>&1
}

timeout_runner_works() {
    [[ -x "$SPEED_DIR/lib/timeout" && -f "$SPEED_DIR/lib/timeout_runner.py" ]] || return 1
    "$SPEED_DIR/lib/timeout" --kill-after=1 2 "$SPEED_PYTHON" -c 'print("Bundled Python timeout: PASS")'
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
    export SPEED_PYTHON="$VENV_PY"
    prepend_path "$WORKBENCH_DIR"
}

step "Checking macOS and required prerequisites"
[[ "$(uname -s)" == "Darwin" ]] || die "This installer is for macOS (detected: $(uname -s))." "Run this installer on a supported macOS computer."
if ! /usr/bin/xcode-select -p >/dev/null 2>&1 || ! /usr/bin/xcrun --find clang >/dev/null 2>&1; then
    die \
        "Apple Command Line Tools and the compiler are required but were not found." \
        "Pause here, install Apple Command Line Tools through an approved source, open a new Terminal window, and rerun the installer."
fi
ok "Apple Command Line Tools: $(/usr/bin/xcode-select -p)"
info "Architecture: $(uname -m)"

step "Validating the required command-line dependencies"
if ! discover_compatible_bash; then
    detected_bash="$(bash --version 2>/dev/null | /usr/bin/head -n 1 || printf 'not found')"
    die "Bash 3.2 or newer is required. Detected: $detected_bash" "Pause here, use the macOS system Bash at /bin/bash or install Bash through an approved source, then rerun the installer."
fi
require_command curl "Pause here, install curl through an approved source, then rerun the installer."
require_command git "Pause here, install Git through an approved source, then rerun the installer."
require_command jq "Pause here, install jq 1.7 or newer through an approved source, then rerun the installer." "1.7 or newer"
jq_works || die "jq 1.7 or newer is required and must be able to process JSON." "Pause here, install or repair jq 1.7 or newer through an approved source, then rerun the installer."
require_command node "Pause here, install Node.js 22.18 or newer through an approved source, then rerun the installer." "22.18 or newer"
node_works || die "Node.js 22.18 or newer is required (detected: $(node --version 2>/dev/null || printf 'unknown'))." "Pause here, install Node.js 22.18 or newer through an approved source, then rerun the installer."
require_command npm "Pause here, install or repair npm (it is installed with Node.js) through an approved source, then rerun the installer."
require_command claude "Pause here, install Claude Code through an approved source, then rerun the installer."
ok "Required command-line dependencies are available"
info "Bash: $("$BASH_BIN" --version | /usr/bin/head -n 1)"
info "curl: $(curl --version | /usr/bin/head -n 1)"
info "Git: $(git --version)"
info "jq: $(jq --version)"
info "Agent timeout: bundled Workbench Python runner (verified after Python setup)"
info "Node.js: $(node --version)"
info "npm: $(npm --version)"
info "Claude Code: $(claude --version)"

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

step "Preparing Python using an existing installed interpreter"
[[ -f "$WORKBENCH_DIR/requirements.txt" ]] || die "$WORKBENCH_DIR/requirements.txt was not found." "Restore a complete Workbench checkout, then rerun the script."
BASE_PY="${SPEED_PYTHON:-}"
if [[ -z "$BASE_PY" ]]; then
    if [[ -x "$WORKBENCH_DIR/.venv/bin/python3" ]]; then
        BASE_PY="$WORKBENCH_DIR/.venv/bin/python3"
    else
        BASE_PY="$(command -v python3 2>/dev/null || true)"
    fi
fi
[[ -x "$BASE_PY" ]] \
    || die "Python 3.12+ was not found." "Pause here, install Python 3.12 or newer through an approved source (set SPEED_PYTHON to its interpreter if it is not the python3 on your PATH), then rerun the installer. The script does not download Python."
"$BASE_PY" -c 'import sys; sys.exit(sys.version_info < (3, 12))' \
    || die "Python 3.12 or newer is required (detected: $("$BASE_PY" --version 2>&1 || printf 'unknown'))." "Pause here, install Python 3.12 or newer through an approved source (set SPEED_PYTHON to its interpreter if needed), then rerun the installer."
VENV_PY="$WORKBENCH_DIR/.venv/bin/python3"
if [[ ! -x "$VENV_PY" ]]; then
    "$BASE_PY" -m venv "$WORKBENCH_DIR/.venv" \
        || die "The Workbench Python environment could not be created." "Review the venv error, resolve the permission or Python installation issue, then rerun."
fi
[[ -x "$VENV_PY" ]] \
    || die "Workbench Python was not created at $VENV_PY." "Repair or recreate the Workbench environment using your approved Python 3.12+, then rerun."
"$VENV_PY" -c 'import sys; sys.exit(sys.version_info < (3, 12))' \
    || die "The existing Workbench environment uses Python older than 3.12." "Preserve the old .venv directory, prepare a Python 3.12+ environment, then rerun."
if ! "$VENV_PY" -m pip --version >/dev/null 2>&1; then
    "$VENV_PY" -m ensurepip \
        || die "pip is missing and could not be bootstrapped in the Workbench environment." "Have your approved Python environment provisioned with pip, then rerun."
fi
"$VENV_PY" -m pip install -r "$WORKBENCH_DIR/requirements.txt" \
    || die "Workbench Python packages could not be installed." "Review the pip output, confirm access to your approved package index or Artifactory, resolve the reported issue, then rerun."
"$VENV_PY" -c "import yaml, tree_sitter, sklearn, networkx; print('Python dependencies: PASS')" \
    || die "A required Workbench Python package could not be imported." "Pause here, repair the Python packages listed in $WORKBENCH_DIR/requirements.txt through an approved package source, then rerun the installer."
ok "$("$VENV_PY" --version)"

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
    printf 'export SPEED_PYTHON="%s"\n' "$VENV_PY"
} >> "$HOME/.zshrc" \
    || die "Could not write the Workbench configuration to $HOME/.zshrc." "Run 'ls -l \"$HOME/.zshrc\"', resolve the file ownership or permission issue, and rerun 'bash Workbench-Lab-Setup-Mac.sh'."
ok "Configured Workbench at $WORKBENCH_DIR in ~/.zshrc"
configure_workbench_env

step "Verifying Workbench in the active and fresh zsh environments"
timeout_runner_works \
    || die "The bundled Python timeout runner is missing or could not execute." "Update Workbench on feat/301-latest, verify SPEED_PYTHON and lib/timeout, then rerun the installer."
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
check() {
    if eval "$2" >/dev/null 2>&1; then
        printf '    \033[32mPASS\033[0m  %s\n' "$1"
    else
        die "$1 readiness check failed." "${3:-Pause here, install or repair the missing prerequisite through an approved source, then rerun the installer.}"
    fi
}
check "Bash 3.2+"              '"$BASH_BIN" -c '\''(( BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2) ))'\''' "Pause here, install or upgrade Bash through an approved source, then rerun the installer."
check "curl"                   'curl --version' "Pause here, install curl through an approved source, then rerun the installer."
check "Git"                    'git --version' "Pause here, install Git through an approved source, then rerun the installer."
check "jq 1.7+"                'jq_works' "Pause here, install or repair jq 1.7 or newer through an approved source, then rerun the installer."
check "Bundled Python timeout"  'timeout_runner_works' "Update Workbench on feat/301-latest and verify SPEED_PYTHON, then rerun the installer."
check "Node.js 22.18+"          'node_works' "Pause here, install Node.js 22.18 or newer through an approved source, then rerun the installer."
check "npm"                    'npm --version' "Pause here, install or repair npm (it is installed with Node.js) through an approved source, then rerun the installer."
check "Claude Code"            'claude --version' "Pause here, install Claude Code through an approved source, then rerun the installer."
check "Python 3.12+"           '"$SPEED_PYTHON" -c '\''import sys; sys.exit(sys.version_info < (3,12))'\''' "Pause here, install Python 3.12 or newer through an approved source (set SPEED_PYTHON to its interpreter if needed), then rerun the installer."
check "Python dependencies"    '"$SPEED_PYTHON" -c '\''import yaml, tree_sitter, sklearn, networkx'\''' "Pause here, repair the Python packages listed in requirements.txt through an approved package source, then rerun the installer."
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
printf '\033[1;32mWorkbench is ready.\033[0m\n'

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

exit 0
