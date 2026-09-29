# Workbench Lab Setup

Use this repository to prepare a Mac or Windows laptop for the Round 0 Workbench lab. Choose your platform below, read its guide, and run its setup script. The script clones the Workbench and payments validation repositories for you; no IDE connection to those repositories is needed.

| Dependency | Requirement | macOS | Windows |
|---|---|---|---|
| Shell and Git | Bash 4.3+ and Git | Apple Command Line Tools and a newer Bash | Git for Windows / Git Bash |
| Python | 3.12+ | Set up by the script through uv | Install from python.org before running |
| Node.js and npm | Node.js 22.18+ | Install before running | Install before running |
| jq | 1.7+ | Install before running | Script installs jq 1.7.1 |
| Claude Code | Installed and signed in | Required | Required |
| Other platform tools | See the guide | GNU coreutils, uv, tree-sitter CLI | Git Bash supplies GNU timeout |

## Choose your platform

| Platform | Read first | Run this script |
|---|---|---|
| macOS | [Mac setup guide](mac/Workbench-Lab-Setup-macOS.md) | [Workbench-Lab-Setup-Mac.sh](mac/Workbench-Lab-Setup-Mac.sh) |
| Windows | [Windows setup guide](windows/Workbench-Lab-Setup-Windows.md) | [setup-windows.sh](windows/setup-windows.sh) |

**Windows script filename:** `setup-windows.sh` in the `windows/` folder. Run it as `bash windows/setup-windows.sh` from the repository root.

## Quick start

Clone this repository:

```bash
git clone https://github.com/ArulaAI/Workbench_Installer.git
cd Workbench_Installer
```

On **macOS**, use Terminal:

```bash
bash mac/Workbench-Lab-Setup-Mac.sh
```

On **Windows**, use Git Bash:

```bash
bash windows/setup-windows.sh
```

Run setup well before the lab. The scripts check prerequisites, install project dependencies, clone Workbench from `feat/301-latest`, and prepare `payments-validation-fixture` on `round-0`. They use `~/Lab` on macOS and `~/lab` on Windows by default; see the platform guide to change the location.

After setup, open a new terminal, start Claude Code from the payments validation fixture, and run `/workbench-health`. The platform guides show the expected result and the remaining Round 0 checks. If setup stops, follow its displayed instruction and rerun the same script.
