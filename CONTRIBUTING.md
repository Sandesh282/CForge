# Contributing to CForge

Thank you for your interest in contributing to **CForge**! Whether it's your first open-source contribution or your hundredth, we're happy to have you here.

---

## Getting Started

### Prerequisites

- **macOS** with [Xcode](https://developer.apple.com/xcode/) installed (version 15.0 or later recommended)
- An Apple ID (free account works for simulator testing)
- Basic familiarity with **Swift** and **SwiftUI**

### Setup

1. **Fork** this repository by clicking the "Fork" button on the top right of the GitHub page.

2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/<your-username>/CForge.git
   cd CForge
   ```

3. **Open** the project in Xcode:
   ```bash
   open CForge.xcodeproj
   ```

4. **Update Signing & Capabilities:**
   - Select the **CForge** project in the Xcode navigator (blue icon at the top).
   - Select the **CForge** target under **TARGETS**.
   - Go to the **Signing & Capabilities** tab.
   - Check **Automatically manage signing**.
   - Change the **Team** dropdown to your own Apple Developer account (a free Apple ID works).
   - If needed, update the **Bundle Identifier** to something unique (e.g., `com.yourname.CForge`).

5. **Build and Run** on the iOS Simulator (`Cmd+R`).

> ** Important:** Do **not** commit changes to the signing/team configuration. These are local to your machine.

---

## How to Contribute

### 1. Find an Issue

- Browse the [Issues](https://github.com/Sandesh282/CForge/issues) tab.
- Look for issues tagged with `good first issue` if you're new.
- Comment on the issue to let the maintainers know you'd like to work on it.
- **Wait for assignment** before starting work to avoid duplicate effort.

### 2. Create a Branch

Create a descriptive branch from `main`:

```bash
git checkout -b fix/verdict-typo
# or
git checkout -b feature/rating-filter
```

**Branch naming conventions:**
| Prefix | Use Case |
|--------|----------|
| `fix/` | Bug fixes |
| `feature/` | New features |
| `chore/` | Cleanup, refactoring, docs |

### 3. Make Your Changes

- Follow the existing code style and patterns in the project.
- Keep changes focused — one issue per PR.
- Test your changes by building (`Cmd+B`) and running the app on the simulator.

### 4. Commit Your Changes

Write clear, descriptive commit messages:

```bash
git add .
git commit -m "Fix: Rename Verdict.faled to Verdict.failed"
```

### 5. Push and Open a Pull Request

```bash
git push origin your-branch-name
```

Then open a **Pull Request** on GitHub:
- Reference the issue number in the PR description (e.g., `Closes #3`).
- Provide a brief summary of what you changed and why.
- Add screenshots if your change affects the UI.

---

## Project Structure

```
CForge/
├── CForgeApp.swift          # App entry point, login flow
├── SplashView.swift         # Splash screen animation
├── AnimatedGradient.swift   # Background gradient animation
├── Theme.swift              # Theme/color definitions
│
├── Views/
│   ├── ContentView.swift    # Main tab bar
│   ├── Common/              # Shared UI components
│   ├── Contest/             # Contest list, detail, API, models
│   ├── Problem/             # Problem list, detail, submissions, models
│   └── Profile/             # Profile view, API, models
│
├── ViewModels/              # MVVM ViewModels
├── Services/                # Network service layer
├── Repositories/            # Data caching & orchestration
├── Domain/                  # Business logic (filters, etc.)
├── Models/                  # Data models
├── Commons/                 # Shared utilities (logging)
└── Utilities/               # Constants, extensions
```

---

## Code Style Guidelines

- Use **SwiftUI** for all views.
- Follow the existing **MVVM** pattern (Service → Repository → ViewModel → View) for new features.
- Use the app's neon color palette (`Color.neonBlue`, `.neonPurple`, `.darkBackground`, etc.) — do not introduce new colors without discussion.
- Use `AppLog.debug()` / `AppLog.error()` instead of `print()` for logging.
- Keep views small and focused — extract subviews and helper functions.

---

## Reporting Bugs

If you find a bug that isn't already tracked:

1. Check [existing issues](https://github.com/Sandesh282/CForge/issues) to avoid duplicates.
2. Open a new issue with the `[BUG]` prefix in the title.
3. Include: steps to reproduce, expected behavior, actual behavior, and screenshots if applicable.

---

## Need Help?

- Comment on the issue you're working on — the maintainers will help!
- Be patient and respectful. We're all here to learn.

---

Thank you for contributing!
