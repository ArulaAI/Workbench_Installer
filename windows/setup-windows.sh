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
#   ~/lab/bin                           python3 launcher
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
BASHRC_MARKER="# Workbench (setup-windows.sh)"

step() { printf '\n\033[1;36m==> %s\033[0m\n' "$1"; }
ok()   { printf '    \033[32m✓\033[0m %s\n' "$1"; }
info() { printf '    %s\n' "$1"; }
die()  { printf '\n    \033[31m✗ %s\033[0m\n' "$1" >&2; [[ $# -gt 1 ]] && printf '      Fix: %s\n' "$2" >&2; exit 1; }

jq_works() {
    local version
    version="$(jq --version 2>/dev/null)" || return 1
    [[ "$version" =~ ^jq-([0-9]+)\.([0-9]+) ]] || return 1
    (( BASH_REMATCH[1] > 1 || (BASH_REMATCH[1] == 1 && BASH_REMATCH[2] >= 7) )) || return 1
    printf '{"ready":true}\n' | jq -e '.ready == true' >/dev/null 2>&1
}

# ── 0. Environment ─────────────────────────────────────────────────
step "Checking the shell"
case "$(uname -s)" in
    MINGW*|MSYS*) ok "Git Bash detected" ;;
    *) die "This script is for Git Bash on Windows (detected: $(uname -s))." \
           "Open Git Bash from the Start menu and run: bash setup-windows.sh" ;;
esac
(( BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2) )) \
    || die "Bash 3.2 or newer is required (detected: ${BASH_VERSION})." \
           "Pause here, install or repair Git Bash through an approved source, then rerun this script."
ok "Bash $BASH_VERSION"

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

command -v curl >/dev/null || die "curl not found." "Install or repair Git for Windows through an approved source, then reopen Git Bash."

command -v jq >/dev/null || die "jq 1.7 or newer was not found." \
    "Pause here, install jq through an approved source, ensure it is available in Git Bash, then rerun this script."
jq_works \
    || die "jq 1.7 or newer is required and must be able to process JSON (detected: $(jq --version 2>&1))." \
           "Pause here, repair jq through an approved source, then rerun this script."
ok "$(jq --version)"

command -v python >/dev/null || die "python not found." \
    "Pause here, install Python 3.12 or newer through an approved source, ensure python is on PATH, then reopen Git Bash."
python -c "import sys; sys.exit(sys.version_info < (3,12))" 2>/dev/null \
    || die "Python $(python --version 2>&1 | awk '{print $2}') is not supported." "Pause here, install Python 3.12 or newer through an approved source, then reopen Git Bash."
ok "Python $(python --version 2>&1 | awk '{print $2}')"

command -v node >/dev/null || die "node not found." "Pause here, install Node.js 22.18 or newer through an approved source, then reopen Git Bash."
node -e "const [a,b]=process.versions.node.split('.').map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)" \
    || die "Node.js $(node --version) is too old." "Pause here, install Node.js 22.18 or newer through an approved source, then reopen Git Bash."
ok "Node.js $(node --version)"
command -v npm >/dev/null || die "npm not found." "Pause here, install or repair Node.js through an approved source, then reopen Git Bash."

command -v claude >/dev/null || die "Claude Code not found." \
    "Pause here, install Claude Code through an approved source, ensure it is on PATH, then reopen Git Bash and rerun this script."
ok "Claude Code $(claude --version 2>/dev/null | awk '{print $1}')"

# ── 2. Workbench ───────────────────────────────────────────────────
step "Cloning Workbench ($WORKBENCH_BRANCH)"
if [[ -d "$WORKBENCH_DIR/.git" ]]; then
    workbench_origin="$(git -C "$WORKBENCH_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$workbench_origin" == *"ArulaAI/workbench"* ]] \
        || die "$WORKBENCH_DIR does not use the expected Workbench origin." \
               "Review 'git -C \"$WORKBENCH_DIR\" remote -v'. Preserve the directory and use a verified Workbench clone before rerunning."
    git -C "$WORKBENCH_DIR" diff --quiet && git -C "$WORKBENCH_DIR" diff --cached --quiet \
        || die "$WORKBENCH_DIR has local tracked changes." \
               "Preserve or commit those changes before rerunning. The script will not update a modified checkout."
    git -C "$WORKBENCH_DIR" fetch -q origin "$WORKBENCH_BRANCH" \
        || die "Could not check Workbench against origin/$WORKBENCH_BRANCH." \
               "Confirm repository, VPN, or proxy access, then rerun this script."
    current=$(git -C "$WORKBENCH_DIR" branch --show-current)
    if [[ "$current" != "$WORKBENCH_BRANCH" ]]; then
        [[ -z "$(git -C "$WORKBENCH_DIR" status --porcelain --untracked-files=no)" ]] \
            || die "$WORKBENCH_DIR is on '$current' and has local changes." "Commit or discard them, then rerun."
        git -C "$WORKBENCH_DIR" fetch -q origin "$WORKBENCH_BRANCH" \
            && git -C "$WORKBENCH_DIR" checkout -q "$WORKBENCH_BRANCH" \
            || die "Could not switch $WORKBENCH_DIR to $WORKBENCH_BRANCH."
    fi
    git -C "$WORKBENCH_DIR" pull -q --ff-only origin "$WORKBENCH_BRANCH" \
        || die "Could not update Workbench to origin/$WORKBENCH_BRANCH." \
               "Preserve local changes or resolve repository access, then rerun. The script will not continue with an unverified copy."
    workbench_relation="$(git -C "$WORKBENCH_DIR" rev-list --left-right --count HEAD...origin/"$WORKBENCH_BRANCH" 2>/dev/null)" \
        || die "Could not compare Workbench with origin/$WORKBENCH_BRANCH."
    [[ "$workbench_relation" == $'0\t0' ]] \
        || die "Workbench is not current with origin/$WORKBENCH_BRANCH (local/remote counts: $workbench_relation)." \
               "Review the repository state and rerun after HEAD exactly matches the approved branch."
    ok "Using existing clone at $WORKBENCH_DIR (verified current with origin/$WORKBENCH_BRANCH)"
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

step "Creating the python3 launcher"
mkdir -p "$BIN_DIR"
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
    fixture_origin="$(git -C "$FIXTURE_DIR" remote get-url origin 2>/dev/null || true)"
    [[ "$fixture_origin" == *"ArulaAI/payments-validation-fixture"* ]] \
        || die "$FIXTURE_DIR does not use the expected payments fixture origin." \
               "Review 'git -C \"$FIXTURE_DIR\" remote -v'. Preserve the directory and use a verified fixture clone before rerunning."
    git -C "$FIXTURE_DIR" diff --quiet && git -C "$FIXTURE_DIR" diff --cached --quiet \
        || die "$FIXTURE_DIR has local tracked changes." \
               "Preserve or commit those changes before rerunning. The script will not update a modified checkout."
    git -C "$FIXTURE_DIR" fetch -q origin main "$LAB_BRANCH" \
        || die "Could not check the lab repository against origin." \
               "Confirm repository, VPN, or proxy access, then rerun this script."
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
git -C "$FIXTURE_DIR" pull -q --ff-only origin "$LAB_BRANCH" \
    || die "Could not update the lab repository to origin/$LAB_BRANCH." \
           "Preserve local changes or resolve repository access, then rerun. The script will not continue with an unverified copy."
fixture_relation="$(git -C "$FIXTURE_DIR" rev-list --left-right --count HEAD...origin/"$LAB_BRANCH" 2>/dev/null)" \
    || die "Could not compare the lab repository with origin/$LAB_BRANCH."
[[ "$fixture_relation" == $'0\t0' ]] \
    || die "The lab repository is not current with origin/$LAB_BRANCH (local/remote counts: $fixture_relation)." \
           "Review the repository state and rerun after HEAD exactly matches the approved branch."
ok "On branch $LAB_BRANCH (verified current with origin)"
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
main_relation="$(git -C "$FIXTURE_DIR" rev-list --left-right --count main...origin/main 2>/dev/null)" \
    || die "Could not compare the local main baseline with origin/main."
case "$main_relation" in
    $'0\t0') ;;
    $'0\t'*)
        git -C "$FIXTURE_DIR" branch -q -f main origin/main \
            || die "Could not update the local main baseline to origin/main."
        ;;
    *)
        die "The local main baseline has commits not present on origin/main (local/remote counts: $main_relation)." \
            "Preserve or remove the local main changes, then rerun."
        ;;
esac
ok "Local main branch present"

step "Verifying the expected Round 0 test baseline"
test_output="$(cd "$FIXTURE_DIR" && npm test 2>&1)"
test_rc=$?
test_output_clean="$(printf '%s\n' "$test_output" | tr -d '\r')"
test_summary="$(printf '%s\n' "$test_output_clean" | grep -E ' (tests|pass|fail) [0-9]+$' | tr '\n' ' ')"
info "npm test: ${test_summary:-no test summary}"
[[ $test_rc -ne 0 ]] \
    || die "The Round 0 test suite did not contain exactly one expected failure." \
           "Run 'cd \"$FIXTURE_DIR\" && npm test' and resolve any unexpected result before continuing."
grep -Eq ' fail 1$' <<< "$test_output_clean" \
    || die "The Round 0 test suite did not report exactly one failure." \
           "Run 'cd \"$FIXTURE_DIR\" && npm test' and resolve any unexpected result before continuing."
grep -q '\[RISK-02\] the scheme fee rounds half up at the capture boundary' <<< "$test_output_clean" \
    || die "The expected RISK-02 failure was not present." \
           "Run 'cd \"$FIXTURE_DIR\" && npm test' and confirm the approved Round 0 baseline."
grep -q '2 !== 3' <<< "$test_output_clean" \
    || die "RISK-02 did not fail with the expected actual 2 versus expected 3 result." \
           "Confirm the fixture is unchanged on the approved Round 0 baseline, then rerun."
ok "Round 0 baseline: exactly one deliberate RISK-02 failure"

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
[[ -f "$FRONTEND_DIR/package-lock.json" ]] \
    || die "Dashboard package-lock.json was not found." "Restore a complete Workbench checkout, then rerun."
dashboard_lock="$(git hash-object "$FRONTEND_DIR/package-lock.json")" \
    || die "Could not fingerprint dashboard package-lock.json."
dashboard_marker="$FRONTEND_DIR/node_modules/.workbench-package-lock"
if [[ -d "$FRONTEND_DIR/node_modules" && -f "$dashboard_marker" ]] \
    && [[ "$(tr -d '\r\n' < "$dashboard_marker")" == "$dashboard_lock" ]]; then
    ok "Already installed for the current package lock"
else
    (cd "$FRONTEND_DIR" && npm ci --no-fund --no-audit --loglevel=error) \
        || die "Dashboard npm ci failed." "Check access to the npm registry (or your approved mirror)."
    printf '%s\n' "$dashboard_lock" > "$dashboard_marker" \
        || die "Dashboard packages installed, but the package-lock marker could not be written."
    ok "Installed from package-lock.json"
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
check "Bash 3.2+"             '(( BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2) ))'
check "Python 3.12+"          'python3 -c "import sys; sys.exit(sys.version_info < (3,12))"'
check "Node 22.18+"           'node -e "const [a,b]=process.versions.node.split(\".\").map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)"'
check "jq 1.7+"               'jq_works'
check "ast-grep"              'ast-grep --version'
check "Claude Code"           'claude --version'
check "Workbench on PATH"     'workbench help'
check "Workbench branch"      '[ "$(git -C "$SPEED_DIR" branch --show-current)" = "feat/301-latest" ]'
check "Workbench current"     '[ "$(git -C "$SPEED_DIR" rev-list --left-right --count HEAD...origin/feat/301-latest)" = "$(printf "0\t0")" ]'
check "Lab repo on round-0"   '[ "$(git -C "$FIXTURE_DIR" branch --show-current)" = "round-0" ]'
check "Lab repo current"      '[ "$(git -C "$FIXTURE_DIR" rev-list --left-right --count HEAD...origin/round-0)" = "$(printf "0\t0")" ]'
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
  bin/                           python3 launcher

Remaining manual step:
  1. Open a NEW Git Bash window (so ~/.bashrc is loaded).
  2. cd "$FIXTURE_DIR" && claude
  3. Inside Claude Code, run /workbench-health, approve the python3 command, and confirm it reports healthy.

Always run workbench/speed commands from outside the workbench/ folder.
EOF
exit $(( failed > 0 ))
