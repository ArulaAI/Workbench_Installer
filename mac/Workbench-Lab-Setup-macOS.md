# Workbench Lab Setup Guide (macOS)

Complete this setup before the lab. It validates the required command-line tools, configures Workbench from the `feat/301-latest` branch, and prepares the payments validation fixture for the Round 0 lab. The setup script never installs or upgrades system tools and never downloads a Python runtime.

SPEED is the next version of Workbench, focused on agentic tasks. The tool is installed as `workbench`, and its commands also run as `speed`.

| | |
|---|---|
| **Platform** | macOS with zsh (Apple Silicon or Intel) |
| **Setup script** | `Workbench-Lab-Setup-Mac.sh` |
| **Workbench branch** | `feat/301-latest` |
| **Lab repository** | `payments-validation-fixture` on `round-0` |
| **Network** | Access to GitHub and PyPI (or your approved package index or mirror) |
| **Result** | The script's readiness check passes, `/workbench-health` reports `Status: healthy`, the Round 0 diff is available, and `speed help` runs without errors |

> **Setup timing:** Complete the setup well before the lab. Use the setup script; the manual steps in the appendix are only needed if the script cannot finish.

## Software and Package Dependencies

The following software is required for this lab on macOS. Items listed as **Prerequisite** must already be installed, through an approved software source, before you run the setup script. The script validates them without installing or upgrading anything, and sets up the remaining components.

| # | Dependency | Requirement / Rev Level | Source |
|---|---|---|---|
| 1 | Apple Command Line Tools | Available | Prerequisite (approved source) |
| 2 | Bash | 3.2+ | Included with macOS (`/bin/bash`) |
| 3 | curl | Available | Bundled with macOS |
| 4 | Git | Available | Bundled with Apple Command Line Tools |
| 5 | jq | 1.7+ | Prerequisite (approved source) |
| 6 | Python | 3.12+ | Prerequisite (approved source); the script does not download Python |
| 7 | Node.js | 22.18+ | Prerequisite (approved source) |
| 8 | npm | Available | Bundled with Node.js |
| 9 | Claude Code | Available (tested with 2.1.108) | Prerequisite (approved source) |
| 10 | Python packages | Workbench `requirements.txt` | Installed by setup script into a `.venv` |
| 11 | ast-grep | From `requirements.txt` | Installed by setup script |
| 12 | Agent timeout | Bundled with Workbench (`lib/timeout`) | Included in the Workbench repository |
| 13 | Dashboard packages (npm) | Workbench `package-lock.json` | Installed on first `speed dashboard start` |

No Homebrew, GNU coreutils (`gtimeout`), `uv`, Tree-sitter CLI, or grammar build is required. The optional Prisma, GraphQL, Protobuf, and Zig grammars are not used by this lab.

## Before You Begin

**Disable any previous Workbench plugin.** If a Workbench plugin was installed through an earlier setup, disable the user-scoped plugin before installing this version of Workbench. List your plugins, then disable the earlier Workbench plugin using the exact name shown in the list:

```bash
claude plugin list
claude plugin disable <earlier-workbench-plugin> --scope user
claude plugin list
```

Confirm that the earlier plugin now shows as `disabled`. If the list shows no earlier Workbench plugin, continue.

## Quick Start

Place `Workbench-Lab-Setup-Mac.sh` in a local folder, open Terminal in that folder, and run:

```bash
bash Workbench-Lab-Setup-Mac.sh
```

Running the file through Bash does not require executable file permission. To run it directly instead, first use `chmod +x Workbench-Lab-Setup-Mac.sh`, then run `./Workbench-Lab-Setup-Mac.sh`.

You are ready when it prints:

```text
Workbench is ready.
```

The script can be safely rerun. If it stops, follow the displayed `Try:` instruction, then rerun `bash Workbench-Lab-Setup-Mac.sh`. The script safely resumes by reusing completed setup steps. When it finishes, complete the checks in **After the Setup Script** below.

Everything is installed in `~/Lab` (`/Users/<username>/Lab`): `workbench/` and `payments-validation-fixture/`. The only change outside that folder is one block in `~/.zshrc` so new Terminal windows can find Workbench. To install to a different location, set `INSTALL_DIR`, for example `INSTALL_DIR=~/workbench-lab bash Workbench-Lab-Setup-Mac.sh`.

## After the Setup Script

Open a **new** Terminal window.

**1. Confirm Workbench inside Claude Code:**

```bash
cd ~/Lab/payments-validation-fixture
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

> **You are all set for the lab.** On lab day, rerun the setup script to confirm your setup is still current. If it reports that a repository is not current with origin, run the `git pull --ff-only` command it shows, then rerun.

## Troubleshooting (Common Issues)

For any other issue, see the full troubleshooting table in the appendix or contact the lab facilitators.

| Symptom | Resolution |
|---|---|
| The script stops and reports a missing or outdated tool | Install or repair that tool through an approved source, as the displayed `Try:` instruction says, then rerun the script. It resumes where it stopped |
| `permission denied` when starting the script | Run it with `bash Workbench-Lab-Setup-Mac.sh`, or run `chmod +x Workbench-Lab-Setup-Mac.sh` first |
| A Git clone fails or is interrupted | The script retries automatically. If it still fails, confirm GitHub, VPN, or proxy access, then rerun |
| `workbench: command not found` | Open a new Terminal window so your shell settings reload, then retry |
| `A previous Workbench clone exists` (or `A previous payments fixture clone exists`) | An earlier setup installed into your home folder. Move or delete `~/workbench` and `~/payments-validation-fixture`, then rerun. The script does not move or delete them itself |
| `... is not current with origin/...` | The repository has new commits. Run `git -C ~/Lab/workbench pull --ff-only` (or the same for `~/Lab/payments-validation-fixture`), then rerun |
| `/workbench-health` is unavailable in Claude Code | From the payments fixture folder, run `workbench skills sync`, restart Claude Code, and retry |

# Appendix: Manual Installation (macOS)

Follow these steps only if `Workbench-Lab-Setup-Mac.sh` cannot complete. They install into `~/Lab`, the same location the setup script uses.

## 1. Confirm the macOS Build Tools

Confirm the Apple Command Line Tools and compiler are available:

```bash
xcode-select -p
xcrun --find clang
```

If either command fails, pause here: install the Apple Command Line Tools through an approved source (on a managed Mac, use the approved software catalog or contact IT support), open a new Terminal window, and rerun the Workbench setup.

## 2. Validate the Required Command-Line Dependencies

```bash
bash --version
curl --version
git --version
jq --version
printf '{}\n' | jq -e .
python3 --version
node --version
npm --version
claude --version
```

The macOS system Bash (`/bin/bash`, version 3.2) is sufficient. The setup script checks these prerequisites without installing or upgrading them. If a prerequisite is missing or incompatible, the script stops and reports the detected condition. Install or repair it through an approved software source, then rerun the script.

### Repository Requirements

| Dependency | Requirement |
|---|---|
| macOS | Supported platform; no minimum macOS version is specified |
| Apple Command Line Tools | Required; no version is specified |
| Bash | 3.2 or newer (the macOS system Bash is sufficient) |
| curl | Required; no minimum version is specified |
| Git | Required; no minimum version is specified |
| jq | 1.7 or newer (jq 1.6 cannot run `speed plan`) |
| Python | 3.12 or newer, installed before you run the script; the script does not download Python. If it is not the `python3` on your `PATH`, set `SPEED_PYTHON` to its interpreter |
| Node.js and npm | Node.js 22.18 or newer (required to run the lab's TypeScript tests); npm is bundled with Node.js |
| Claude Code | Required lab agent CLI (tested with 2.1.108) |
| Agent timeout | Bundled with Workbench (`lib/timeout`); no GNU tools are needed |
| Python Tree-sitter package | Installed from `requirements.txt` with the repository constraint `>=0.23,<1.0` |
| Python packages | Installed according to the constraints in `requirements.txt` |

If a dependency is missing or too old, install or repair it through an approved software source, then rerun the setup script.

## 3. Clone Workbench and Select the Lab Branch

```bash
mkdir -p ~/Lab
git clone -b feat/301-latest https://github.com/ArulaAI/workbench.git ~/Lab/workbench
cd ~/Lab/workbench
git branch --show-current
```

Expected: `feat/301-latest`

The automated script retries a new HTTPS clone up to three times when a transient connection failure occurs. For an existing clone, it verifies the expected origin, branch, and remote state without overwriting local work. If the existing checkout is behind or has diverged, the script stops with review and recovery guidance.

## 4. Create the Isolated Python Environment

Run these commands from `~/Lab/workbench`, using your approved Python 3.12 or newer in place of `python3` if it is not the one on your `PATH`:

```bash
python3 -m venv .venv
.venv/bin/python3 -m pip install -r requirements.txt
```

> **Note:** `requirements.txt` installs more than 100 Python packages, including indirect dependencies. This is expected. The exact count changes as `requirements.txt` is updated. If a `.venv` already exists, reuse it; the second command is safe to rerun.

## 5. Activate and Verify the Python Environment

```bash
source .venv/bin/activate
python3 --version
python3 -c "import yaml, tree_sitter, sklearn, networkx; print('Python dependencies: PASS')"
```

Expected Python version: 3.12 or newer.

## 6. Add Workbench to zsh

Run this once:

```bash
cat >> ~/.zshrc <<'EOF'

# Workbench
export SPEED_DIR="$HOME/Lab/workbench"
export PATH="$SPEED_DIR:$PATH"
export SPEED_PYTHON="$SPEED_DIR/.venv/bin/python3"
EOF
source ~/.zshrc
```

## 7. Verify the Installation

```bash
echo "$SPEED_DIR"
command -v workbench
echo "$SPEED_PYTHON"
"$SPEED_PYTHON" --version
"$SPEED_DIR/lib/timeout" --kill-after=1 2 "$SPEED_PYTHON" -c 'print("Bundled Python timeout: PASS")'
workbench help
```

Expected path pattern:

```text
/Users/<username>/Lab/workbench
/Users/<username>/Lab/workbench/workbench
/Users/<username>/Lab/workbench/.venv/bin/python3
Python 3.12.x (or newer)
Bundled Python timeout: PASS
```

Open a new Terminal window and run:

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

## 8. Prepare and Validate the Payments Lab Fixture

```bash
git clone https://github.com/ArulaAI/payments-validation-fixture.git ~/Lab/payments-validation-fixture
cd ~/Lab/payments-validation-fixture
git switch round-0
git branch --show-current
workbench init --harness claude
speed help
workbench skills status
workbench skills sync
workbench skills doctor
```

Expected branch: `round-0`

Expected results include:

```text
SPEED initialized
SPEED command help is displayed without errors
claude     workbench-health     current
skills doctor: healthy - 0 issue(s)
All imported Workbench skills are current and ready to use.
```

Start Claude Code from the payments validation fixture:

```bash
claude
```

Inside Claude Code, run:

```text
/workbench-health
```

Expected result:

```text
Status: healthy
Workbench skills were imported successfully and are ready to use.
```

After confirming the healthy result, exit Claude Code and list the files changed in the course’s Round 0 change:

```bash
cd ~/Lab/payments-validation-fixture
git --no-pager diff --stat main...round-0
```

This compares the change introduced on `round-0` with its common starting point on `main` and displays the changed file names, a per-file summary, and the total number of files changed without showing the code patch.

As the final functional check, run SPEED from the payments validation fixture:

```bash
cd ~/Lab/payments-validation-fixture
speed help
```

Confirm that the SPEED help and available commands are displayed without errors.

## macOS Readiness Check

The setup script ends with this readiness check. To run it manually, open a new Terminal window and paste this block:

```bash
FIXTURE="$HOME/Lab/payments-validation-fixture"
check() { if eval "$2" >/dev/null 2>&1; then echo "PASS  $1"; else echo "FAIL  $1"; fi; }
bash_ok() { /bin/bash -c '(( BASH_VERSINFO[0] > 3 || (BASH_VERSINFO[0] == 3 && BASH_VERSINFO[1] >= 2) ))'; }
jq_ok() { jq --version | grep -Eq '^jq-(1\.([7-9]|[1-9][0-9])|[2-9]|[1-9][0-9])' && printf '{}\n' | jq -e .; }
node_ok() { node -e 'const [a,b]=process.versions.node.split(".").map(Number); process.exit(a>22||(a==22&&b>=18)?0:1)'; }
doctor_ok() {
  doctor_output="$(cd "$FIXTURE" && workbench skills doctor 2>&1)"
  [[ "$doctor_output" == *"skills doctor: healthy"* && "$doctor_output" == *"0 issue(s)"* ]]
}
check "Bash 3.2+"              'bash_ok'
check "curl"                   'curl --version'
check "Git"                    'git --version'
check "jq 1.7+"                'jq_ok'
check "Bundled Python timeout" '"$SPEED_DIR/lib/timeout" --kill-after=1 2 "$SPEED_PYTHON" -c "print(1)"'
check "Node.js 22.18+"         'node_ok'
check "npm"                    'npm --version'
check "Claude Code"            'claude --version'
check "Python 3.12+"           '"$SPEED_PYTHON" -c "import sys; sys.exit(sys.version_info < (3,12))"'
check "Python dependencies"    '"$SPEED_PYTHON" -c "import yaml, tree_sitter, sklearn, networkx"'
check "Workbench verified"     'workbench help'
check "SPEED from fixture"     'cd "$FIXTURE" && speed help'
check "Workbench branch"       '[ "$(git -C "$SPEED_DIR" branch --show-current)" = "feat/301-latest" ]'
check "Payments fixture"       '[ -d "$FIXTURE/.git" ]'
check "Fixture main branch"    'git -C "$FIXTURE" show-ref --verify --quiet refs/heads/main'
check "Fixture round-0"        '[ "$(git -C "$FIXTURE" branch --show-current)" = "round-0" ]'
check "Fixture Workbench"      '[ -f "$FIXTURE/speed.toml" ]'
check "Claude harness"         '[ -f "$FIXTURE/.claude/skills/workbench-health/SKILL.md" ]'
check "Skills doctor healthy"  'doctor_ok'
check "Round 0 diff"           '[ -n "$(git -C "$FIXTURE" diff --name-only main...round-0)" ]'
```

The installation and lab fixture are ready when every line prints `PASS`, `/workbench-health` reports `Status: healthy` inside Claude Code, `git --no-pager diff --stat main...round-0` displays the changed-file summary and total, and `speed help` displays the SPEED help and available commands without errors from the fixture directory.

## macOS Troubleshooting

| Symptom | Resolution |
|---|---|
| The script file reports `permission denied` | Run it with `bash Workbench-Lab-Setup-Mac.sh`, or run `chmod +x Workbench-Lab-Setup-Mac.sh` before direct execution |
| A required command is missing or too old | Install or repair it through an approved source, as the displayed `Try:` instruction says, then rerun the script |
| A Git clone is interrupted | Allow the script's bounded retries to complete. If an incomplete target directory remains, move it aside, confirm GitHub, VPN, or proxy access, and rerun |
| `xcode-select` or compiler check fails | Install the Apple Command Line Tools through an approved source (on a managed Mac, the approved software catalog or IT support), open a new Terminal window, and rerun the setup |
| `Python 3.12+ was not found` | Install Python 3.12 or newer through an approved source. If it is not the `python3` on your `PATH`, set `SPEED_PYTHON` to its interpreter, then rerun the script. The script never downloads Python |
| `Node.js ... is too old` | Install Node.js 22.18 or newer through an approved source, open a new Terminal window, and rerun the script |
| `workbench: command not found` | Confirm the Workbench block is present in `~/.zshrc`, then open a new Terminal window |
| Python dependency import fails | From `~/Lab/workbench`, rerun the `pip install` command in section 4 |
| `Author identity unknown` | Configure Git `user.name` and `user.email`, then rerun the initialization commands |
| Payments fixture directory already exists but is not a Git repository | Move the existing directory aside or clone the fixture to another location before retrying |
| Payments fixture is not on `round-0` | Preserve any local changes, then run `git switch round-0` from `~/Lab/payments-validation-fixture` |
| `workbench skills doctor` reports `unsupported` or does not report `healthy` | From `~/Lab/payments-validation-fixture`, run `workbench init --harness claude`, then `workbench skills sync`, and rerun the installer |
| `/workbench-health` is unavailable | Run `workbench skills sync` from `~/Lab/payments-validation-fixture`, restart Claude Code, and retry |
| `A previous Workbench clone exists` | Move or delete the earlier `~/workbench` and `~/payments-validation-fixture` clones, then rerun the script |
| `... is not current with origin/...` | From the named repository, run `git pull --ff-only`, then rerun the script |
