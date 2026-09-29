# Workbench Lab Setup Guide (Windows)

Complete this setup before the lab. It validates the required command-line tools, configures Workbench from the `feat/301-latest` branch, and prepares the payments validation fixture for the Round 0 lab. Existing system tools are not upgraded automatically.

SPEED is the next version of Workbench, focused on agentic tasks. The tool is installed as `workbench`, and its commands also run as `speed`.

| | |
|---|---|
| **Platform** | Windows 10 or 11 with Git Bash (validated on Windows 11) |
| **Setup script** | `setup-windows.sh` |
| **Workbench branch** | `feat/301-latest` |
| **Lab repository** | `payments-validation-fixture` on `round-0` |
| **Network** | Access to GitHub, npm, and PyPI, or approved internal mirrors |
| **Result** | The script's readiness check passes, `/workbench-health` reports `Status: healthy`, the Round 0 diff is available, and `speed help` runs without errors |

> **Setup timing:** Complete the setup well before the lab. Use the setup script; the manual steps in the appendix are only needed if the script cannot finish.

## Software and Package Dependencies

The following software is required for this lab on Windows. Items listed as **Prerequisite** must be installed before running the setup script. The setup script validates all prerequisites and installs the remaining components.

| # | Dependency | Requirement / Rev Level | Source |
|---|---|---|---|
| 1 | Git for Windows (Git Bash) | Available | Prerequisite |
| 2 | Bash | 4.3+ | Bundled with Git for Windows |
| 3 | curl | Available | Bundled with Git for Windows |
| 4 | Git | Available | Bundled with Git for Windows |
| 5 | GNU `timeout` | Available | Bundled with Git for Windows |
| 6 | jq | 1.7+ | Installed by setup script (jq 1.7.1) |
| 7 | Python | 3.12+ | Prerequisite (python.org, with "Add python.exe to PATH" selected) |
| 8 | Python packages | Workbench `requirements.txt` | Installed by setup script |
| 9 | ast-grep | From `requirements.txt` | Installed by setup script |
| 10 | Node.js | 22.18+ | Prerequisite |
| 11 | npm | Available | Bundled with Node.js |
| 12 | Dashboard packages (npm) | Workbench `package-lock.json` | Installed by setup script |
| 13 | Claude Code | Available (tested with 2.1.108) | Prerequisite (`npm install -g @anthropic-ai/claude-code`) |

## Before You Begin

**Disable the previous Workbench plugin.** If `workbench@mastercard-workbench` was installed through a previous setup, disable the user-scoped plugin before installing this version of Workbench:

```bash
claude plugin disable workbench@mastercard-workbench --scope user
claude plugin list
```

Confirm that the plugin list reports:

```text
workbench@mastercard-workbench    user    disabled
```

## Quick Start

Use **Git Bash** for every command. Workbench is a set of Bash scripts and does not run in PowerShell or Command Prompt.

**1. Install the base tools** if they are not already installed, then close and reopen Git Bash:

- Git for Windows (includes Git Bash)
- Python 3.12 or newer from python.org, with **"Add python.exe to PATH"** selected
- Node.js 22.18 or newer
- Claude Code: `npm install -g @anthropic-ai/claude-code`, then run `claude` once to sign in

**2. Run the setup script.** Save `setup-windows.sh` to any local folder, open Git Bash in that folder, and run:

```bash
bash setup-windows.sh
```

The first run takes about 10–15 minutes and needs about 1.3 GB of disk space. Some steps print nothing for several minutes; do not close the window. You are ready when it prints:

```text
Setup complete: all required tools and repositories are ready.
```

If the script stops, follow the displayed `Fix:` instruction, then run `bash setup-windows.sh` again. It resumes where it stopped. When it finishes, complete the checks in **After the Setup Script** below.

Everything is installed in `~/lab` (`C:\Users\<username>\lab`): `workbench/`, `payments-validation-fixture/`, and `bin/`. The only change outside that folder is one block in `~/.bashrc` so new Git Bash windows can find Workbench. To install to a different location, set `INSTALL_DIR`, for example `INSTALL_DIR=/c/workbench-lab bash setup-windows.sh`.

> **Windows note:** always run `workbench` and `speed` commands from outside the `workbench/` folder, for example from the `payments-validation-fixture/` folder.

## After the Setup Script

Open a **new** Git Bash window.

**1. Confirm Workbench inside Claude Code:**

```bash
cd ~/lab/payments-validation-fixture
claude
```

Inside Claude Code, run `/workbench-health` and approve the `python3` command if prompted. Expected result:

```text
Status: healthy
Workbench skills were imported successfully and are ready to use.
```

**2. Review the Round 0 change.** Exit Claude Code, then from the same folder run:

```bash
git --no-pager diff --stat main...round-0
```

This displays the changed file names, a per-file summary, and the total number of files changed.

**3. Confirm SPEED runs:**

```bash
speed help
```

Confirm that the SPEED help and available commands are displayed without errors.

> **You are all set for the lab.** On lab day, rerun the setup script to pull the latest code and confirm your setup is still current.

## Troubleshooting (Common Issues)

For any other issue, see the full troubleshooting table in the appendix or contact the lab facilitators.

| Symptom | Resolution |
|---|---|
| The script stops and reports a missing or outdated tool | Follow the displayed `Fix:` instruction, then rerun the script. It resumes where it stopped |
| `python not found`, or `Python ... is not supported` | Install Python 3.12 or newer from python.org with **"Add python.exe to PATH"** selected, reopen Git Bash, and rerun |
| `Clone failed` | Confirm GitHub, VPN, or proxy access, then rerun the script |
| `workbench: command not found` | Open a new Git Bash window so your shell settings reload, then retry |
| `/workbench-health` is unavailable in Claude Code | From the payments fixture folder, run `workbench skills sync`, restart Claude Code, and retry |
| `18 language(s) have broken ast-grep rules` | You are inside the `workbench/` folder. Change to the `payments-validation-fixture/` folder and retry |
| `Ports 3000/4440 free` fails | Another application is using port 3000 or 4440. Run `netstat -ano` to find its process ID, close it in Task Manager, then rerun |

# Appendix: Manual Installation (Windows)

Follow these steps only if `setup-windows.sh` cannot complete. Use **Git Bash** for every command. They install into `~/lab`, the same location the setup script uses.

## 1. Confirm Git Bash and the Base Tools

```bash
git --version
python --version
node --version
```

If any command is not found, install the missing tool through your approved software source, then open a new Git Bash window:

- **Git for Windows**, which includes Git Bash
- **Python 3.12 or newer**, with **"Add python.exe to PATH"** selected during installation
- **Node.js 22.18 or newer**, which includes npm

No C compiler or Xcode equivalent is required on Windows.

## 2. Install the Required Command-Line Dependencies

```bash
npm install -g @anthropic-ai/claude-code
mkdir -p ~/lab/bin
curl -L -o ~/lab/bin/jq.exe https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-windows-amd64.exe
```

`jq` is downloaded directly because `winget` is not available inside Git Bash. `ast-grep` is installed with the Python dependencies in section 4.

### Required Compatibility

| Dependency | Compatible version |
|---|---:|
| Bash | 4.3+ (included with Git Bash) |
| Git | Available (included with Git for Windows) |
| jq | 1.7+ |
| Python | 3.12 or newer |
| Node.js | 22.18+ |
| npm | Included with Node.js |
| Claude Code | Available (tested with 2.1.108) |
| ast-grep | Installed from `requirements.txt` |
| curl and GNU timeout | Included with Git Bash |

## 3. Clone Workbench and Select the Lab Branch

```bash
git clone -b feat/301-latest https://github.com/ArulaAI/workbench.git ~/lab/workbench
cd ~/lab/workbench
git branch --show-current
```

Expected: `feat/301-latest`

## 4. Create the Isolated Python Environment

Run these commands from `~/lab/workbench`:

```bash
python -m venv .venv
.venv/Scripts/pip install -r requirements.txt
```

On Windows, the environment's programs are in `.venv/Scripts/`, not `.venv/bin/`.

> **Note:** `requirements.txt` installs more than 100 Python packages, including indirect dependencies. This is expected. The exact count changes as `requirements.txt` is updated.

## 5. Create the `python3` Command and Verify the Python Environment

Workbench calls `python3`, but the python.org installer for Windows provides only `python`. Create a `python3` launcher that points to the Workbench environment:

```bash
printf '#!/bin/sh\nexec "%s" "$@"\n' "$HOME/lab/workbench/.venv/Scripts/python.exe" > ~/lab/bin/python3
chmod +x ~/lab/bin/python3
~/lab/bin/python3 --version
~/lab/bin/python3 -c "import yaml, tree_sitter, sklearn, networkx; print('Python dependencies: PASS')"
```

Expected Python version: 3.12 or newer.

## 6. Custom Language Grammars (Not Required on Windows)

The macOS setup builds four custom grammar libraries. That build requires a C compiler, and Workbench runs on Windows without it, provided you run Workbench commands from **outside** the `~/lab/workbench` folder. Inside that folder, Workbench's own configuration requests the grammar libraries, and every command fails with `18 language(s) have broken ast-grep rules`.

## 7. Add Workbench to Git Bash

Run this once:

```bash
cat >> ~/.bashrc <<'EOF'

# Workbench
export SPEED_DIR="$HOME/lab/workbench"
export SPEED_PYTHON="$SPEED_DIR/.venv/Scripts/python.exe"
export PATH="$HOME/lab/bin:$SPEED_DIR:$SPEED_DIR/.venv/Scripts:$PATH"
EOF
source ~/.bashrc
```

## 8. Verify the Installation

```bash
cd ~
echo "$SPEED_DIR"
command -v workbench
echo "$SPEED_PYTHON"
"$SPEED_PYTHON" --version
jq --version
workbench help
```

Expected path pattern:

```text
/c/Users/<username>/lab/workbench
/c/Users/<username>/lab/workbench/workbench
/c/Users/<username>/lab/workbench/.venv/Scripts/python.exe
Python 3.12.x or newer
jq-1.7.1
```

Open a new Git Bash window and run:

```bash
echo "$SPEED_DIR"
command -v workbench
echo "$SPEED_PYTHON"
"$SPEED_PYTHON" --version
workbench help >/dev/null && echo "Workbench fresh-terminal check: PASS"
```

Expected final line:

```text
Workbench fresh-terminal check: PASS
```

> **Note:** If you had no `~/.bash_profile`, the first new window shows a one-time red warning that begins `WARNING: Found ~/.bashrc but no ~/.bash_profile`. This is expected. Git for Windows creates the file automatically, and the warning does not appear again.

## 9. Prepare and Validate the Payments Lab Fixture

```bash
git clone https://github.com/ArulaAI/payments-validation-fixture.git ~/lab/payments-validation-fixture
cd ~/lab/payments-validation-fixture
git switch round-0
git branch --show-current
workbench init --harness claude
workbench skills status
workbench skills sync
workbench skills doctor
```

Expected branch: `round-0`

Expected results include:

```text
SPEED initialized
claude     workbench-health     current
skills doctor: healthy - 0 issue(s)
All imported Workbench skills are current and ready to use.
```

Confirm the lab's tests run:

```bash
npm test
```

Expected: `# tests 19`, `# pass 18`, `# fail 1`. The one failing test is intentional and part of the lab.

Start Claude Code from the payments validation fixture:

```bash
claude
```

Inside Claude Code, run:

```text
/workbench-health
```

Approve the `python3 .claude/skills/workbench-health/scripts/health.py` command when prompted; it only reads files.

Expected result:

```text
Status: healthy
Workbench skills were imported successfully and are ready to use.
```

After confirming the healthy result, exit Claude Code and list the files changed in the course's Round 0 change:

```bash
cd ~/lab/payments-validation-fixture
git --no-pager diff --stat main...round-0
```

This compares the change introduced on `round-0` with its common starting point on `main` and displays the changed file names, a per-file summary, and the total number of files changed without showing the code patch.

## 10. Pre-Install the Dashboard Packages

The lab uses a web dashboard. Install its packages in advance to save time during the lab:

```bash
cd "$SPEED_DIR/dashboard/frontend"
npm install
cd ~
```

npm prints deprecation notices, including one for the dashboard's Next.js version. The installation still completes.

## Windows Readiness Check

The setup script ends with this readiness check. To run it manually, open a new Git Bash window and paste this block:

```bash
cd ~/lab
FIXTURE="$(dirname "$SPEED_DIR")/payments-validation-fixture"
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fi; }
check "Python 3.12+"           'python3 -c "import sys; sys.exit(sys.version_info < (3,12))"'
check "Node 22.18+"            'node -e "const [a,b]=process.versions.node.split(\".\").map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)"'
check "jq 1.7+"                'jq --version | grep -Eq "jq-1\.([7-9]|[1-9][0-9])"'
check "ast-grep"               'ast-grep --version'
check "Claude Code"            'claude --version'
check "Workbench on PATH"      'workbench help'
check "Workbench branch"       '[ "$(git -C "$SPEED_DIR" branch --show-current)" = "feat/301-latest" ]'
check "Lab repo on round-0"    '[ "$(git -C "$FIXTURE" branch --show-current)" = "round-0" ]'
check "Lab repo local main"    'git -C "$FIXTURE" rev-parse --verify main'
check "Fixture Workbench"      '[ -f "$FIXTURE/speed.toml" ]'
check "Workbench health skill" '[ -f "$FIXTURE/.claude/skills/workbench-health/SKILL.md" ]'
check "Dashboard packages"     '[ -d "$SPEED_DIR/dashboard/frontend/node_modules" ]'
check "Ports 3000/4440 free"   '! netstat -ano | grep -Eq ":(3000|4440) .*LISTENING"'
```

The installation and lab fixture are ready when every line prints `PASS`, `/workbench-health` reports `Status: healthy` inside Claude Code, and `git --no-pager diff --stat main...round-0` displays the changed-file summary and total.

## Windows Troubleshooting

| Symptom | Resolution |
|---|---|
| `python: command not found`, or "Python was not found; run without arguments to install from the Microsoft Store" | Install Python 3.12 or newer with **"Add python.exe to PATH"** selected, then open a new Git Bash window |
| `Unknown file extension ".ts"` from `npm test` | Upgrade Node.js to 22.18 or newer |
| `winget: command not found` | winget is not available in Git Bash; use the direct `jq` download in section 2 |
| `python3 not found` | Create the `python3` launcher in section 5 |
| `jq is not installed`, or `speed plan` fails with `unexpected def` | Install jq 1.7.1 from section 2 (jq 1.6 is too old), then open a new Git Bash window |
| `workbench: command not found` | Confirm the Workbench block is present in `~/.bashrc`, then open a new Git Bash window |
| `18 language(s) have broken ast-grep rules` | You are inside `~/lab/workbench`. Change to `~/lab/payments-validation-fixture`, then retry |
| `ast-grep CLI not found` | Confirm `.venv/Scripts` is on `PATH` (section 7), then open a new Git Bash window |
| Python dependency import fails | From `~/lab/workbench`, rerun the commands in section 4 |
| `Author identity unknown` | Configure Git `user.name` and `user.email`, then rerun the initialization commands |
| Payments fixture directory already exists but is not a Git repository | Move the existing directory aside or clone the fixture to another location before retrying |
| Payments fixture is not on `round-0` | Preserve any local changes, then run `git switch round-0` from `~/lab/payments-validation-fixture` |
| `Could not diff 'main...round-0'` | Run `git -C ~/lab/payments-validation-fixture branch --track main origin/main` |
| `workbench skills doctor` reports `unsupported` or does not report `healthy` | From `~/lab/payments-validation-fixture`, run `workbench init --harness claude`, then `workbench skills sync`, and rerun the installer |
| `/workbench-health` is unavailable | Run `workbench skills sync` from `~/lab/payments-validation-fixture`, restart Claude Code, and retry |
| `Ports 3000/4440 free` fails, or the dashboard shows `EADDRINUSE` | Run `netstat -ano \| grep -E ":(3000\|4440) .*LISTENING"`. The last number is the process ID; close that application in Task Manager. Port 3000 must be free. If only 4440 is busy, use `speed dashboard start --port 4441` |
| `Dashboard API already running (PID ...)` but no dashboard is open | Run `speed dashboard stop`, then start the dashboard again |
