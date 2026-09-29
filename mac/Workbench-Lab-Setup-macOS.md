# Workbench Lab Setup Guide (macOS)

Complete this setup before the lab. It validates the required command-line tools, configures Workbench from the `feat/301-latest` branch, and prepares the payments validation fixture for the Round 0 lab. Existing system tools are not upgraded automatically.

SPEED is the next version of Workbench, focused on agentic tasks. The tool is installed as `workbench`, and its commands also run as `speed`.

| | |
|---|---|
| **Platform** | macOS with zsh (Apple Silicon or Intel) |
| **Setup script** | `Workbench-Lab-Setup-Mac.sh` |
| **Workbench branch** | `feat/301-latest` |
| **Lab repository** | `payments-validation-fixture` on `round-0` |
| **Network** | Access to GitHub and PyPI; access to Homebrew and npm when a missing prerequisite must be installed |
| **Result** | The script's readiness check passes, `/workbench-health` reports `Status: healthy`, the Round 0 diff is available, and `speed help` runs without errors |

> **Setup timing:** Complete the setup well before the lab. Use the setup script; the manual steps in the appendix are only needed if the script cannot finish.

## Software and Package Dependencies

The following software is required for this lab on macOS. Items listed as **Prerequisite** must be installed before running the setup script. The setup script validates all prerequisites and installs the remaining components.

| # | Dependency | Requirement / Rev Level | Source |
|---|---|---|---|
| 1 | Apple Command Line Tools | Available | Prerequisite (`xcode-select --install`) |
| 2 | Homebrew | Optional | Optional prerequisite (used to install missing dependencies) |
| 3 | Bash | 4.3+ | Prerequisite (`brew install bash`); macOS includes 3.2 |
| 4 | curl | Available | Bundled with macOS |
| 5 | Git | Available | Bundled with Apple Command Line Tools |
| 6 | jq | 1.7+ | Prerequisite (`brew install jq`) |
| 7 | GNU coreutils (`gtimeout`) | Available | Prerequisite (`brew install coreutils`) |
| 8 | uv | Available | Prerequisite (`brew install uv`) |
| 9 | Python | 3.12+ | Installed by setup script (Python 3.12 via uv) |
| 10 | Python packages | Workbench `requirements.txt` | Installed by setup script |
| 11 | ast-grep | From `requirements.txt` | Installed by setup script |
| 12 | Tree-sitter CLI | Available | Prerequisite (`npm install -g tree-sitter-cli`) |
| 13 | Node.js | 22.18+ | Prerequisite (`brew install node`) |
| 14 | npm | Available | Bundled with Node.js |
| 15 | Dashboard packages (npm) | Workbench `package-lock.json` | Installed on first `speed dashboard start` |
| 16 | Claude Code | Available (tested with 2.1.108) | Prerequisite (`npm install -g @anthropic-ai/claude-code`) |

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
| The script stops and reports a missing or outdated tool | Follow the displayed `Try:` instruction, then rerun the script. It resumes where it stopped |
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

If either command fails, run `xcode-select --install`. Complete the macOS installer, open a new Terminal window, and rerun the Workbench setup. On a managed Mac, use the approved software catalog or contact IT support if installation is restricted.

Homebrew is an installation option for missing macOS prerequisites; it is not itself a Workbench runtime requirement. To confirm that it is available:

```bash
command -v brew
brew --version
```

If a prerequisite is missing and Homebrew is not available, install the prerequisite through another approved software source or install Homebrew through the approved software catalog.

## 2. Validate the Required Command-Line Dependencies

```bash
command -v bash
bash --version
curl --version
git --version
jq --version
printf '{}\n' | jq -e .
gtimeout --version
uv --version
node --version
npm --version
claude --version
tree-sitter --version
```

The setup script checks these prerequisites without installing or upgrading them. If a prerequisite is missing or incompatible, the script stops, reports the detected condition, and provides a suggested installation or upgrade command. Complete that action through the approved software source, then rerun the script.

### Repository Requirements

| Dependency | Requirement |
|---|---|
| macOS | Supported platform; no minimum macOS version is specified |
| Apple Command Line Tools | Required to compile the custom grammars; no version is specified |
| Homebrew | Optional installation mechanism for missing macOS prerequisites |
| Bash | 4.3 or newer |
| curl | Required; no minimum version is specified |
| Git | Required; no minimum version is specified |
| jq | 1.7 or newer (jq 1.6 cannot run `speed plan`) |
| GNU `gtimeout` | Required; supplied by `coreutils` on macOS; no minimum version is specified |
| uv | Required to prepare the Python environment; no minimum version is specified |
| Node.js and npm | Node.js 22.18 or newer (required to run the lab's TypeScript tests); npm is bundled with Node.js |
| Claude Code | Required lab agent CLI (tested with 2.1.108) |
| Tree-sitter CLI | Required to build the custom grammars; no minimum version is specified |
| Python | The Workbench environment uses Python 3.12 or newer |
| Python Tree-sitter package | Installed from `requirements.txt` with the repository constraint `>=0.23,<1.0` |
| Python packages | Installed according to the constraints in `requirements.txt` |

If a dependency is missing, use its individual recovery command through an approved software source:

| Missing prerequisite | Suggested command |
|---|---|
| Bash 4.3+ | `brew install bash` |
| Git | `brew install git` |
| jq | `brew install jq` |
| GNU `gtimeout` | `brew install coreutils` |
| uv | `brew install uv` |
| Node.js and npm | `brew install node` |
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Tree-sitter CLI | `npm install -g tree-sitter-cli` |

Install only the missing prerequisite, then rerun the setup script.

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

Run these commands from `~/Lab/workbench`:

```bash
uv python install 3.12
uv venv --python 3.12 .venv
uv pip install -r requirements.txt --python .venv/bin/python3
```

> **Note:** `requirements.txt` installs more than 100 Python packages, including indirect dependencies. This is expected. The exact count changes as `requirements.txt` is updated.

## 5. Activate and Verify the Python Environment

```bash
source .venv/bin/activate
python3 --version
python3 -c "import yaml, tree_sitter, sklearn, networkx; print('Python dependencies: PASS')"
```

Expected Python version: 3.12 or newer.

## 6. Build the Custom Language Grammars

```bash
./scripts/build-grammars.sh --clean
```

## 7. Add Workbench to zsh

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

## 8. Verify the Installation

```bash
echo "$SPEED_DIR"
command -v workbench
echo "$SPEED_PYTHON"
"$SPEED_PYTHON" --version
workbench help
```

Expected path pattern:

```text
/Users/<username>/Lab/workbench
/Users/<username>/Lab/workbench/workbench
/Users/<username>/Lab/workbench/.venv/bin/python3
Python 3.12.x
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

## 9. Prepare and Validate the Payments Lab Fixture

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
bash_compatible() {
  bash_path="$(command -v bash)"
  need='(( BASH_VERSINFO[0] * 100 + BASH_VERSINFO[1] >= 403 ))'
  for candidate in /opt/homebrew/bin/bash /usr/local/bin/bash "$bash_path"; do
    [ -x "$candidate" ] && "$candidate" -c "$need" && return 0
  done
  return 1
}
doctor_ok() {
  doctor_output="$(cd "$FIXTURE" && workbench skills doctor 2>&1)"
  [[ "$doctor_output" == *"skills doctor: healthy"* && "$doctor_output" == *"0 issue(s)"* ]]
}
check "Bash 4.3+"             'bash_compatible'
check "curl"                  'curl --version'
check "Git"                   'git --version'
check "jq"                    'printf "{}\n" | jq -e .'
check "GNU coreutils"         'gtimeout --version'
check "uv"                    'uv --version'
check "Node.js"               'node --version'
check "npm"                   'npm --version'
check "Claude Code"           'claude --version'
check "tree-sitter CLI"       'tree-sitter --version'
check "Python 3.12+"          '"$SPEED_PYTHON" -c "import sys; sys.exit(sys.version_info < (3,12))"'
check "Python dependencies"   '"$SPEED_PYTHON" -c "import yaml, tree_sitter, sklearn, networkx"'
check "Workbench verified"    'workbench help'
check "SPEED from fixture"    'cd "$FIXTURE" && speed help'
check "Workbench branch"      '[ "$(git -C "$SPEED_DIR" branch --show-current)" = "feat/301-latest" ]'
check "Payments fixture"      '[ -d "$FIXTURE/.git" ]'
check "Fixture main branch"   'git -C "$FIXTURE" show-ref --verify --quiet refs/heads/main'
check "Fixture round-0"       '[ "$(git -C "$FIXTURE" branch --show-current)" = "round-0" ]'
check "Fixture Workbench"     '[ -f "$FIXTURE/speed.toml" ]'
check "Claude harness"        '[ -f "$FIXTURE/.claude/skills/workbench-health/SKILL.md" ]'
check "Skills doctor healthy" 'doctor_ok'
check "Round 0 diff"          '[ -n "$(git -C "$FIXTURE" diff --name-only main...round-0)" ]'
```

The installation and lab fixture are ready when every line prints `PASS`, `/workbench-health` reports `Status: healthy` inside Claude Code, `git --no-pager diff --stat main...round-0` displays the changed-file summary and total, and `speed help` displays the SPEED help and available commands without errors from the fixture directory.

## macOS Troubleshooting

| Symptom | Resolution |
|---|---|
| `brew: command not found` | Install Homebrew through the approved software source, then open a new Terminal window |
| The script file reports `permission denied` | Run it with `bash Workbench-Lab-Setup-Mac.sh`, or run `chmod +x Workbench-Lab-Setup-Mac.sh` before direct execution |
| A required command is missing or Bash is older than 4.3 | Follow the script's suggested approved installation or upgrade command, then rerun the script |
| A Git clone is interrupted | Allow the script's bounded retries to complete. If an incomplete target directory remains, move it aside, confirm GitHub, VPN, or proxy access, and rerun |
| `xcode-select` or compiler check fails | Run `xcode-select --install`, complete the macOS installer, open a new Terminal window, and rerun the setup. On a managed Mac, use the approved software catalog or contact IT support |
| `workbench: command not found` | Confirm the Workbench block is present in `~/.zshrc`, then open a new Terminal window |
| Python dependency import fails | From `~/Lab/workbench`, rerun the three commands in section 4 |
| Grammar build fails | Confirm `tree-sitter --version` works, then rerun section 6 |
| `Author identity unknown` | Configure Git `user.name` and `user.email`, then rerun the initialization commands |
| Payments fixture directory already exists but is not a Git repository | Move the existing directory aside or clone the fixture to another location before retrying |
| Payments fixture is not on `round-0` | Preserve any local changes, then run `git switch round-0` from `~/Lab/payments-validation-fixture` |
| `workbench skills doctor` reports `unsupported` or does not report `healthy` | From `~/Lab/payments-validation-fixture`, run `workbench init --harness claude`, then `workbench skills sync`, and rerun the installer |
| `/workbench-health` is unavailable | Run `workbench skills sync` from `~/Lab/payments-validation-fixture`, restart Claude Code, and retry |
| `A previous Workbench clone exists` | Move or delete the earlier `~/workbench` and `~/payments-validation-fixture` clones, then rerun the script |
| `... is not current with origin/...` | From the named repository, run `git pull --ff-only`, then rerun the script |
