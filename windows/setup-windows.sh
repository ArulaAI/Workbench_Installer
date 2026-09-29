#!/usr/bin/env bash
#
# setup-windows.sh
#
# Sets up SPEED (the next version of Workbench, focused on agentic tasks) and
# the lab repository on Windows (Git Bash), then runs a readiness check.
#
# Usage (in Git Bash):
#   bash setup-windows.sh
#
# Everything is installed inside ~/lab by default:
#   ~/lab/workbench                     SPEED/Workbench (feat/301-latest) + Python environment
#   ~/lab/payments-validation-fixture   lab repository, on the round-0 branch
#   ~/lab/bin                           jq and the python3 launcher
# The only change outside this folder is a small block in ~/.bashrc that puts
# Workbench on PATH in new Git Bash windows.
#
# Safe to re-run: completed steps are detected and skipped.
#
# Optional override:
#   INSTALL_DIR   (default: ~/lab)
#
# Rerun it any time (for example on lab day) to pull the latest code for both
# repositories and re-verify the setup.

set -uo pipefail

INSTALL_DIR="${INSTALL_DIR:-$HOME/lab}"

WORKBENCH_REPO="https://github.com/ArulaAI/workbench.git"
WORKBENCH_BRANCH="feat/301-latest"
FIXTURE_REPO="https://github.com/ArulaAI/payments-validation-fixture.git"
LAB_BRANCH="round-0"
JQ_URL="https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe"
BASHRC_MARKER="# Workbench (setup-windows.sh)"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  { printf '\n    \033[31m✗ %s\033[0m\n' "$1" >&2; [[ $# -gt 1 ]] && printf '      Fix: %s\n' "$2" >&2; exit 1; }

# ── 0. Environment ─────────────────────────────────────────────────
step "Checking the shell"
case "$(uname -s)" in
    MINGW*|MSYS*) ok "Git Bash detected" ;;
    *) die "This script is for Git Bash on Windows (detected: $(uname -s))." \
           "Open Git Bash from the Start menu and run: bash setup-windows.sh" ;;
esac

mkdir -p "$INSTALL_DIR" \
    || die "Could not create or access the installation directory: $INSTALL_DIR" \
           "Choose a user-writable location, set INSTALL_DIR to that path, and rerun."
INSTALL_DIR="$(cd "$INSTALL_DIR" && pwd)" \
    || die "Could not resolve the installation directory: $INSTALL_DIR" \
           "Confirm the directory exists and is accessible, then rerun."
WORKBENCH_DIR="$INSTALL_DIR/workbench"
FIXTURE_DIR="$INSTALL_DIR/payments-validation-fixture"
BIN_DIR="$INSTALL_DIR/bin"
ok "Installation workspace: $INSTALL_DIR"

# ── 1. Base tools ──────────────────────────────────────────────────
step "Checking base tools"
command -v git >/dev/null || die "git not found." "Install Git for Windows from your approved software catalog."
ok "git $(git --version | awk '{print $3}')"

command -v curl >/dev/null || die "curl not found." "curl ships with Git for Windows; reinstall Git for Windows."

command -v python >/dev/null || die "python not found." \
    "Install Python 3.12 or newer with \"Add python.exe to PATH\" selected, then reopen Git Bash."
python -c "import sys; sys.exit(sys.version_info < (3,12))" 2>/dev/null \
    || die "Python $(python --version 2>&1 | awk '{print $2}') is not supported." "Install Python 3.12 or newer, then reopen Git Bash."
ok "Python $(python --version 2>&1 | awk '{print $2}')"

command -v node >/dev/null || die "node not found." "Install Node.js 22.18 or newer, then reopen Git Bash."
node -e "const [a,b]=process.versions.node.split('.').map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)" \
    || die "Node.js $(node --version) is too old." "Install Node.js 22.18 or newer, then reopen Git Bash."
ok "Node.js $(node --version)"
command -v npm >/dev/null || die "npm not found." "npm ships with Node.js; reinstall Node.js."

command -v claude >/dev/null || die "Claude Code not found." \
    "Run: npm install -g @anthropic-ai/claude-code   then reopen Git Bash and rerun this script."
ok "Claude Code $(claude --version 2>/dev/null | awk '{print $1}')"

# ── 2. Workbench ───────────────────────────────────────────────────
step "Cloning Workbench ($WORKBENCH_BRANCH)"
if [[ -d "$WORKBENCH_DIR/.git" ]]; then
    current=$(git -C "$WORKBENCH_DIR" branch --show-current)
    if [[ "$current" != "$WORKBENCH_BRANCH" ]]; then
        [[ -z "$(git -C "$WORKBENCH_DIR" status --porcelain --untracked-files=no)" ]] \
            || die "$WORKBENCH_DIR is on '$current' and has local changes." "Commit or discard them, then rerun."
        git -C "$WORKBENCH_DIR" fetch -q origin "$WORKBENCH_BRANCH" \
            && git -C "$WORKBENCH_DIR" checkout -q "$WORKBENCH_BRANCH" \
            || die "Could not switch $WORKBENCH_DIR to $WORKBENCH_BRANCH."
    fi
    if git -C "$WORKBENCH_DIR" pull -q --ff-only origin "$WORKBENCH_BRANCH" 2>/dev/null; then
        ok "Using existing clone at $WORKBENCH_DIR (updated to latest $WORKBENCH_BRANCH)"
    else
        info "Could not pull the latest $WORKBENCH_BRANCH (local changes or no network); using the current copy"
        ok "Using existing clone at $WORKBENCH_DIR"
    fi
elif [[ -e "$WORKBENCH_DIR" ]]; then
    die "$WORKBENCH_DIR exists but is not a git clone." "Move it aside, or set WORKBENCH_DIR to another path."
else
    git clone -q -b "$WORKBENCH_BRANCH" "$WORKBENCH_REPO" "$WORKBENCH_DIR" \
        || die "Clone failed." "Check access to github.com (or your approved proxy/mirror)."
    ok "Cloned to $WORKBENCH_DIR"
fi
ok "Branch: $(git -C "$WORKBENCH_DIR" branch --show-current)"

step "Creating the Python environment (first run takes about 5-6 minutes)"
VENV_PY="$WORKBENCH_DIR/.venv/Scripts/python.exe"
if [[ ! -x "$VENV_PY" ]]; then
    python -m venv "$WORKBENCH_DIR/.venv" || die "Could not create the virtual environment."
    ok "Created $WORKBENCH_DIR/.venv"
else
    ok "Virtual environment already exists"
fi
"$WORKBENCH_DIR/.venv/Scripts/pip" install -q --disable-pip-version-check -r "$WORKBENCH_DIR/requirements.txt" \
    || die "pip install failed." "Check access to PyPI (or your approved mirror), then rerun."
"$VENV_PY" -c "import yaml, tree_sitter, sklearn, networkx" \
    || die "Python dependencies failed to import." "Rerun the script; if it persists, delete $WORKBENCH_DIR/.venv and rerun."
ok "Python dependencies installed"

step "Installing jq 1.7.1"
mkdir -p "$BIN_DIR"
if [[ -x "$BIN_DIR/jq.exe" ]] && "$BIN_DIR/jq.exe" --version 2>/dev/null | grep -Eq 'jq-1\.([7-9]|[1-9][0-9])'; then
    ok "jq already installed ($("$BIN_DIR/jq.exe" --version))"
else
    curl -fsSL -o "$BIN_DIR/jq.exe" "$JQ_URL" || die "jq download failed." "Check access to github.com."
    chmod +x "$BIN_DIR/jq.exe"
    ok "Installed $("$BIN_DIR/jq.exe" --version)"
fi

step "Creating the python3 launcher"
printf '#!/bin/sh\nexec "%s" "$@"\n' "$VENV_PY" > "$BIN_DIR/python3"
chmod +x "$BIN_DIR/python3"
ok "$BIN_DIR/python3 -> Workbench Python"

step "Adding Workbench to ~/.bashrc"
BASHRC_BLOCK="$(
    printf '%s\n' "$BASHRC_MARKER"
    printf 'export SPEED_DIR="%s"\n' "$WORKBENCH_DIR"
    printf 'export SPEED_PYTHON="$SPEED_DIR/.venv/Scripts/python.exe"\n'
    printf 'export PATH="%s:$SPEED_DIR:$SPEED_DIR/.venv/Scripts:$PATH"\n' "$BIN_DIR"
)"
# Remove a block written by the earlier version of this script (install-workbench-windows.sh).
OLD_MARKER="# Workbench (install-workbench-windows.sh)"
if grep -qF "$OLD_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    awk -v m="$OLD_MARKER" '$0==m {skip=3; next} skip>0 {skip--; next} {print}' "$HOME/.bashrc" > "$HOME/.bashrc.wbtmp" \
        && mv "$HOME/.bashrc.wbtmp" "$HOME/.bashrc"
fi
if grep -qF "$BASHRC_MARKER" "$HOME/.bashrc" 2>/dev/null; then
    if grep -qF "export SPEED_DIR=\"$WORKBENCH_DIR\"" "$HOME/.bashrc"; then
        ok "Already configured"
    else
        # Replace a block left by an earlier install in a different folder.
        awk -v m="$BASHRC_MARKER" '$0==m {skip=3; next} skip>0 {skip--; next} {print}' "$HOME/.bashrc" > "$HOME/.bashrc.wbtmp" \
            && mv "$HOME/.bashrc.wbtmp" "$HOME/.bashrc"
        printf '\n%s\n' "$BASHRC_BLOCK" >> "$HOME/.bashrc"
        ok "Updated ~/.bashrc to point to $INSTALL_DIR"
    fi
else
    printf '\n%s\n' "$BASHRC_BLOCK" >> "$HOME/.bashrc"
    ok "Added to ~/.bashrc"
fi
export SPEED_DIR="$WORKBENCH_DIR"
export SPEED_PYTHON="$VENV_PY"
export PATH="$BIN_DIR:$SPEED_DIR:$SPEED_DIR/.venv/Scripts:$PATH"

step "Verifying Workbench"
cd "$INSTALL_DIR"   # never run workbench from inside the Workbench folder
workbench help >/dev/null 2>&1 || { workbench help 2>&1 | grep -E '✗|Fix:' >&2; die "workbench help failed."; }
ok "workbench help works"

# ── 3. Lab repository ─────────────────────────────────────────────
step "Preparing the lab repository ($LAB_BRANCH)"
if [[ -d "$FIXTURE_DIR/.git" ]]; then
    git -C "$FIXTURE_DIR" fetch -q origin 2>/dev/null
    ok "Using existing clone at $FIXTURE_DIR"
elif [[ -e "$FIXTURE_DIR" ]]; then
    die "$FIXTURE_DIR exists but is not a git clone." "Move it aside, or delete it and rerun."
else
    git clone -q "$FIXTURE_REPO" "$FIXTURE_DIR" \
        || die "Clone failed." "Check access to github.com."
    ok "Cloned to $FIXTURE_DIR"
fi
if [[ "$(git -C "$FIXTURE_DIR" branch --show-current)" != "$LAB_BRANCH" ]]; then
    git -C "$FIXTURE_DIR" checkout -q "$LAB_BRANCH" \
        || die "Could not check out $LAB_BRANCH in $FIXTURE_DIR." "Commit or discard local changes there, then rerun."
fi
if git -C "$FIXTURE_DIR" pull -q --ff-only origin "$LAB_BRANCH" 2>/dev/null; then
    ok "On branch $LAB_BRANCH (updated to latest)"
else
    info "Could not pull the latest $LAB_BRANCH (local changes or no network); using the current copy"
    ok "On branch $LAB_BRANCH"
fi
# Diagnose compares main...round-0, so origin/main and a local main are required.
if ! git -C "$FIXTURE_DIR" show-ref --verify --quiet refs/remotes/origin/main; then
    git -C "$FIXTURE_DIR" fetch origin main:refs/remotes/origin/main \
        || die "Could not fetch origin/main for the lab repository." \
               "Check GitHub, VPN, or proxy access, then rerun the script."
fi
if ! git -C "$FIXTURE_DIR" rev-parse --verify -q main >/dev/null; then
    git -C "$FIXTURE_DIR" branch -q --track main origin/main \
        || die "Could not create the local main branch." \
               "Run 'git -C \"$FIXTURE_DIR\" branch --track main origin/main' to inspect the error, then rerun."
fi
ok "Local main branch present"

tests=$(cd "$FIXTURE_DIR" && npm test 2>&1 | grep -E '^# (tests|pass|fail) ' | tr '\n' ' ')
info "npm test: ${tests:-no result}(1 failing test is intentional)"

step "Verifying Workbench skills in the payments validation fixture"
(cd "$FIXTURE_DIR" && workbench init --harness claude >/dev/null 2>&1) \
    || die "workbench init failed in $FIXTURE_DIR." \
           "Run 'cd \"$FIXTURE_DIR\" && workbench init --harness claude' to inspect the error. If it reports 'Author identity unknown', configure git user.name and user.email, then rerun."
(cd "$FIXTURE_DIR" && workbench skills status 2>/dev/null) | grep -Eq 'claude +workbench-health +current' \
    || die "workbench-health is not current in the payments validation fixture." \
           "Run 'cd \"$FIXTURE_DIR\" && workbench skills status' to inspect the result, then rerun."
[[ -f "$FIXTURE_DIR/.claude/skills/workbench-health/SKILL.md" ]] \
    || die "The workbench-health skill was not projected into the payments validation fixture." \
           "Run 'cd \"$FIXTURE_DIR\" && workbench init --harness claude', then rerun."
ok "claude  workbench-health  current"

# ── 4. Dashboard ──────────────────────────────────────────────────
step "Pre-installing dashboard packages (first run takes about 3-4 minutes)"
FRONTEND_DIR="$SPEED_DIR/dashboard/frontend"
if [[ -d "$FRONTEND_DIR/node_modules" ]]; then
    ok "Already installed"
else
    (cd "$FRONTEND_DIR" && npm install --no-fund --no-audit --loglevel=error) \
        || die "Dashboard npm install failed." "Check access to the npm registry (or your approved mirror)."
    ok "Installed"
fi
cd "$INSTALL_DIR"

# ── 5. Readiness check ────────────────────────────────────────────
step "Readiness check"
failed=0
failed_names=""
check() {
    if eval "$2" >/dev/null 2>&1; then
        printf '    \033[32mPASS\033[0m  %s\n' "$1"
    else
        printf '    \033[31mFAIL\033[0m  %s\n' "$1"; failed=$((failed + 1)); failed_names+="[$1]"
    fi
}
check "Python 3.12+"          'python3 -c "import sys; sys.exit(sys.version_info < (3,12))"'
check "Node 22.18+"           'node -e "const [a,b]=process.versions.node.split(\".\").map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)"'
check "jq 1.7+"               'jq --version | grep -Eq "jq-1\.([7-9]|[1-9][0-9])"'
check "ast-grep"              'ast-grep --version'
check "Claude Code"           'claude --version'
check "Workbench on PATH"     'workbench help'
check "Workbench branch"      '[ "$(git -C "$SPEED_DIR" branch --show-current)" = "feat/301-latest" ]'
check "Lab repo on round-0"   '[ "$(git -C "$FIXTURE_DIR" branch --show-current)" = "round-0" ]'
check "Lab repo local main"   'git -C "$FIXTURE_DIR" rev-parse --verify main'
check "Fixture Workbench"     '[ -f "$FIXTURE_DIR/speed.toml" ]'
check "Workbench health skill" '[ -f "$FIXTURE_DIR/.claude/skills/workbench-health/SKILL.md" ]'
check "Dashboard packages"    '[ -d "$SPEED_DIR/dashboard/frontend/node_modules" ]'
check "Ports 3000/4440 free"  '! netstat -ano | grep -Eq ":(3000|4440) .*LISTENING"'

echo
if [[ $failed -eq 0 ]]; then
    printf '\033[1;32mSetup complete: all required tools and repositories are ready.\033[0m\n'
else
    printf '\033[1;31m%d check(s) failed.\033[0m\n' "$failed"
    [[ "$failed_names" == *"[Ports 3000/4440 free]"* ]] && \
        info "Ports: the lab dashboard needs port 3000 (fixed) and 4440. Find what is using them with:"
        info "         netstat -ano | grep -E ':(3000|4440) .*LISTENING'   (last number = process ID; close it in Task Manager)"
        info "       If only 4440 is busy, start the dashboard with: speed dashboard start --port 4441"
    [[ "$failed_names" =~ \[(Python|Node|jq|ast-grep|Claude|Workbench|Lab|Dashboard) ]] && \
        info "Other failures: open a new Git Bash window and rerun this script; it resumes where it left off."
fi

cat <<EOF

Installed in: $INSTALL_DIR
  workbench/                     SPEED / Workbench
  payments-validation-fixture/   lab repository (round-0)
  bin/                           jq and python3

Remaining manual step:
  1. Open a NEW Git Bash window (so ~/.bashrc is loaded).
  2. cd "$FIXTURE_DIR" && claude
  3. Inside Claude Code, run /workbench-health, approve the python3 command, and confirm it reports healthy.

Always run workbench/speed commands from outside the workbench/ folder.
EOF
exit $(( failed > 0 ))
