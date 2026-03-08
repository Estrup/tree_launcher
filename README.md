<div align="center">

# 🌳 TreeLauncher

**The elegant, visual Git Worktree manager and developer dashboard.**

[![Flutter](https://img.shields.io/badge/Flutter-%2302569B.svg?style=for-the-badge&logo=Flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%230175C2.svg?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![macOS](https://img.shields.io/badge/macOS-%23000000.svg?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)

<p align="center">
  <em>Effortlessly manage multiple Git worktrees, run custom commands, and orchestrate your local development environment from a single, beautiful interface.</em>
</p>

</div>

---

## ✨ Features

- **Visual Worktree Management:** Create, track, and switch between Git worktrees without touching the command line.
- **Multi-Repository Support:** Keep all your projects organized in one sidebar.
- **Embedded Terminal:** Integrated pseudo-terminal (`flutter_pty` + `xterm`) for running local commands, inspecting logs, or quick shell access.
- **Custom Launchers:** Define and run custom terminal commands with a single click.
- **Editor Integration:** Open worktrees directly in your favorite editors (VSCode, Ghostty, etc.).
- **Jira Integration:** Easily link your worktrees and branches to Jira ticket numbers.
- **Beautiful UI:** A dark-themed, modern interface built with Flutter, optimized for desktop use.

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (version 3.10.3 or higher)
- [Git](https://git-scm.com/) installed and available in your system path
- macOS (Currently optimized for macOS, though Linux/Windows support may work with minimal tweaks)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Estrup/tree_launcher.git
   cd tree_launcher
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the app:**
   ```bash
   flutter run -d macos
   ```

### Building for Release

To build a standalone macOS application:

```bash
flutter build macos
```

The resulting `.app` bundle will be located in `build/macos/Build/Products/Release/`.

To build and install the app into `/Applications`, use the repo helper script:

```bash
./install-macos-app
```

The script replaces the existing `/Applications/tree_launcher.app` bundle with the freshly built app. If your machine requires elevated permissions for `/Applications`, it will prompt for administrator access during the install step.

## 🛠️ Tech Stack

- **Framework:** [Flutter](https://flutter.dev/)
- **State Management:** [Provider](https://pub.dev/packages/provider)
- **Terminal Integration:** [xterm.dart](https://pub.dev/packages/xterm) & [flutter_pty](https://pub.dev/packages/flutter_pty)
- **Local Storage:** `path_provider` + standard JSON configs
- **System Shell:** Dart `Process.run` and standard `Platform.environment` bindings

## Copilot Skills

TreeLauncher-specific Copilot skills live in `tools/skills/`. This repo is the source of truth for those skills; do not hand-edit the installed copies in your global skills directory.

The helper scripts prefer `COPILOT_HOME/skills` when available, fall back to `CODEX_HOME/skills`, and otherwise default to `~/.copilot/skills`.

Validate checked-in skills with:

```bash
python3 tools/validate_codex_skills.py
```

Install all repo-managed skills into the active global skills directory with:

```bash
python3 tools/install_codex_skills.py
```

Install a single skill with:

```bash
python3 tools/install_codex_skills.py --skill kanban-issue-ops
```

## 🎨 Architecture & Code Structure

- `lib/models/`: Data models for Repositories, Worktrees, Settings, and Terminal Sessions.
- `lib/providers/`: State management for Repositories, App Settings, and Terminal.
- `lib/screens/`: Main application screens (e.g., `HomeScreen`).
- `lib/services/`: Core business logic wrapping Git CLI (`git_service.dart`) and configuration storage (`config_service.dart`).
- `lib/theme/`: Centralized design system (`app_theme.dart`).
- `lib/widgets/`: Reusable UI components (Sidebar, Terminal Panel, Dialogs).
- `tools/skills/`: Repo-managed Codex skills and their bundled scripts.


## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
