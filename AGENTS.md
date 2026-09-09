# AGENTS.md — Arterious

This file documents the architecture, conventions, and coding standards for **Arterious** (Apple Developer Academy Challenge 5).

All contributors — human or AI — must read and follow these rules before making any changes.

---

## Project Purpose

Arterious is a health awareness app that helps adult children stay informed about changes in their parents' general wellness, using Apple HealthKit as its sole data source.

**It does not diagnose medical conditions or measure blood pressure.**

---

## Architecture

This project uses **simple MVVM** as recommended by Apple for SwiftUI projects.

```
View → ViewModel → HealthKitManager → HealthKit
```

### Layers

| Layer | Responsibility |
|---|---|
| **View** | SwiftUI layout only. Reads ViewModel state. Forwards user actions. |
| **ViewModel** | Holds UI state. Calls HealthKitManager. Runs trend analysis. |
| **HealthKitManager** | Single gateway to HKHealthStore. Returns plain Swift models. No business logic. |
| **Model** | Pure Swift structs/enums. No SwiftUI. No HealthKit imports. |
| **Components** | Reusable, stateless UI building blocks. No business logic. |
| **DesignSystem** | Centralized design tokens (colors, spacing, typography, radius). |

### What to Avoid

- ❌ Clean Architecture / VIPER
- ❌ Coordinator or Router pattern
- ❌ Repository pattern (we have one data source)
- ❌ UseCase / Interactor layer
- ❌ Complex DI containers (Swinject, etc.)
- ❌ ThemeManager as a class/singleton
- ❌ Feature Flags or Analytics abstraction
- ❌ Generic abstractions for hypothetical future needs

---

## Folder Structure

```
Arterious/
├── App/                        # App entry point
├── DesignSystem/               # Design tokens only
│   ├── AppColor.swift
│   ├── AppSpacing.swift
│   ├── AppTypography.swift
│   └── AppRadius.swift
├── Models/                     # Plain Swift models
│   └── HealthModels.swift
├── ViewModels/                 # @Observable ViewModels
│   └── DashboardViewModel.swift
├── Views/                      # One folder per screen
│   ├── Dashboard/
│   │   └── DashboardView.swift
│   ├── Trends/
│   ├── Profile/
│   └── Settings/
├── Components/                 # Reusable SwiftUI components
│   ├── AppButton.swift
│   ├── AppCard.swift
│   ├── SectionHeader.swift
│   ├── EmptyStateView.swift
│   ├── LoadingView.swift
│   ├── MetricCardView.swift
│   └── CautionCardView.swift
├── Services/                   # HealthKit data access
│   └── HealthKitManager.swift
└── Resources/                  # Assets, colors, localisation
```

Only create folders that contain actual files.

---

## Naming Conventions

| Item | Convention | Example |
|---|---|---|
| Files | PascalCase | `DashboardView.swift` |
| Types (struct, class, enum) | PascalCase | `DailyHealthSummary` |
| Properties & methods | camelCase | `loadDashboardData()` |
| Design token namespaces | `App` prefix | `AppColor`, `AppSpacing` |
| Components | Descriptive noun | `MetricCardView`, `AppButton` |
| ViewModels | Screen name + `ViewModel` | `DashboardViewModel` |

---

## Design System Rules

- All colors must come from `AppColor`.
- All spacing values must come from `AppSpacing`.
- All corner radii must come from `AppRadius`.
- Typography helpers live in `AppTypography` as `Font` extensions.
- Magic numbers (e.g., `.padding(18)`) in components are not acceptable after the Design System exists.

---

## Component Rules

- Components must be **stateless** whenever possible (input via `let` properties or closures).
- Components must **never** import HealthKit or contain business logic.
- Components must have a `#Preview` block.
- Components receive data as simple Swift types (String, Double, Bool), not full model objects when practical.

---

## ViewModel Rules

- Mark with `@Observable` (not `ObservableObject`). iOS 17+ target.
- Mark with `@MainActor`.
- Use `async let` for parallel HealthKit queries.
- Hold `isLoading`, `errorMessage`, and domain state as `var`.
- Inject `HealthKitManager` via `init(healthKitManager:)` with a `.shared` default.

---

## HealthKitManager Rules

- Single shared instance via `HealthKitManager.shared`.
- All queries use async/await via `withCheckedContinuation`.
- Must not import SwiftUI.
- Must return plain Swift model types.
- Provide mock/placeholder data when HealthKit is unavailable (Simulator).

---

## Privacy & Medical Disclaimer

- Never use diagnostic language (e.g., "hypertension", "arrhythmia", "insomnia detected").
- Use gentle, conversational, relationship-focused copy.
- Always include the medical disclaimer on any screen displaying health metrics:
  > "Arterious reflects general wellness trends from Apple HealthKit and is not intended for medical diagnosis."

---

## Swift Style

- Use descriptive names over comments.
- Avoid `// MARK:` sections unless a file exceeds ~100 lines.
- Prefer `guard` for early exits.
- Prefer `if let` / `guard let` over force unwrap.
- Use trailing closures syntax.
- Avoid `AnyView`.
- Minimum iOS 17 — use `@Observable`, not `@StateObject`/`ObservableObject`.
