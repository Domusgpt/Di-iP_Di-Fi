# Contributing to IdeaCapital

Thank you for your interest in contributing to IdeaCapital. This document provides guidelines and procedures to help you contribute effectively.

---

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Branch Naming Conventions](#branch-naming-conventions)
4. [Commit Message Format](#commit-message-format)
5. [Pull Request Process](#pull-request-process)
6. [Code Style](#code-style)
7. [Testing Requirements](#testing-requirements)
8. [Schema Changes](#schema-changes)
9. [Security](#security)

---

## Code of Conduct

All contributors are expected to maintain a professional, respectful, and inclusive environment. In particular:

- Be respectful and constructive in code reviews and discussions.
- Assume good intent. Seek clarification before making assumptions about another contributor's work.
- Harassment, discrimination, and abusive behavior will not be tolerated.
- Focus feedback on the code, not the person.
- Welcome newcomers. Offer guidance rather than criticism for first-time contributors.

Violations of these expectations should be reported to the project maintainers.

---

## Getting Started

### Prerequisites

Ensure you have the following installed:

- Docker and Docker Compose
- Flutter SDK (3.x)
- Node.js (20+) and npm
- Python 3.11+ and pip
- Rust (stable toolchain) and Cargo
- Firebase CLI

### Local Development Setup

For detailed setup instructions, including environment variables, emulator configuration, and service startup, refer to **[docs/getting-started.md](docs/getting-started.md)**.

The quickest way to start all services:

```bash
docker compose up
```

To start an individual service:

```bash
docker compose up brain    # Python AI agent on port 8081
docker compose up vault    # Rust financial backend on port 8080
```

### Repository Structure

IdeaCapital is a polyglot monorepo with five services:

| Directory | Language | Service |
|-----------|----------|---------|
| `frontend/ideacapital/` | Dart (Flutter) | Mobile/web UI |
| `backend/functions/` | TypeScript | Firebase Cloud Functions API |
| `brain/` | Python | AI agent (FastAPI + Vertex AI) |
| `vault/` | Rust | Financial backend (Axum + PostgreSQL) |
| `contracts/` | Solidity | Smart contracts (Hardhat + OpenZeppelin) |

---

## Branch Naming Conventions

Use the following prefixes for all branches:

| Prefix | Use Case | Example |
|--------|----------|---------|
| `feature/` | New functionality or capabilities | `feature/dividend-claim-api` |
| `fix/` | Bug fixes | `fix/merkle-proof-encoding` |
| `docs/` | Documentation-only changes | `docs/brain-agent-spec` |

Additional guidelines:

- Use lowercase with hyphens as separators.
- Keep branch names concise but descriptive.
- Include a ticket or issue number when applicable (e.g., `feature/42-wallet-connect`).

---

## Commit Message Format

Write commit messages in **imperative mood** with a concise 1-2 sentence summary on the first line.

### Format

```
<summary in imperative mood>

<optional body with additional context>
```

### Examples

Good:
```
Add Merkle tree calculation to dividend distribution endpoint

Wire the Rust merkle module into the /dividends/distribute route
and store the computed root in PostgreSQL.
```

```
Fix USDC decimal truncation in token calculator
```

Bad:
```
Fixed stuff
```
```
Updated the code to make it work better
```

### Rules

- Start with a capital letter.
- Do not end the summary line with a period.
- Use imperative mood: "Add", "Fix", "Update", "Remove" -- not "Added", "Fixes", or "Updating".
- Keep the summary line under 72 characters.
- Use the body to explain **why**, not just **what**, when the change is non-obvious.

---

## Pull Request Process

### Before Submitting

1. Ensure all tests pass locally for the services you modified.
2. Run the appropriate linter and formatter for each language you touched (see [Code Style](#code-style)).
3. Rebase your branch on the latest main branch to avoid merge conflicts.

### PR Description

Every pull request must include:

1. **Summary:** A clear description of what the PR changes and why.
2. **Test Plan:** A bulleted checklist describing how the changes were tested and how reviewers can verify correctness.
3. **Related Issues:** Link any related GitHub issues using `Closes #123` or `Relates to #456`.

### Review Process

- All PRs require at least one approval before merging.
- Address all review comments before requesting re-review.
- Use "Resolve conversation" only after the reviewer's concern has been addressed.
- Prefer squash-and-merge for feature branches to keep the main branch history clean.

### CI Checks

The GitHub Actions CI pipeline runs on every PR. All of the following must pass before merge:

- Solidity: `npx hardhat compile && npx hardhat test`
- TypeScript: `npm run build && npm run lint`
- Python: `pytest tests/ -v`
- Rust: `cargo build && cargo test`

---

## Code Style

Each language in the monorepo has its own formatting and linting standards. Run the appropriate tools before committing.

### Dart (Flutter)

- **Linter:** `flutter_lints` (configured in `analysis_options.yaml`)
- **Formatting:** `dart format .`
- **State Management:** Riverpod (providers, not BLoC)
- **Routing:** GoRouter (declarative routes in `app.dart`)
- **Models:** Use `json_serializable` with `@JsonKey` annotations; run `dart run build_runner build` after model changes
- **File naming:** `snake_case.dart`

### TypeScript (Backend)

- **Compiler:** TypeScript strict mode (`"strict": true` in `tsconfig.json`)
- **Linting:** ESLint (run via `npm run lint`)
- **Build:** `npm run build`
- **Pattern:** Firebase Functions Gen 2 with Express routers
- **Validation:** Zod schemas where applicable
- **File naming:** `kebab-case.ts`

### Python (Brain)

- **Formatter:** [black](https://github.com/psf/black) (default configuration)
- **Linter:** [ruff](https://github.com/astral-sh/ruff)
- **Framework:** FastAPI with async everywhere (`async def`, `await`)
- **Models:** Pydantic v2
- **Testing:** pytest with httpx `AsyncClient`
- **File naming:** `snake_case.py`

```bash
cd brain
black src/ tests/
ruff check src/ tests/
```

### Rust (Vault)

- **Formatter:** `cargo fmt`
- **Linter:** `cargo clippy` (all warnings must be resolved)
- **Framework:** Axum 0.7 with `Router` and `State<PgPool>`
- **Database:** SQLx with compile-time checked queries where possible
- **Error handling:** `anyhow::Result`
- **File naming:** `snake_case.rs`

```bash
cd vault
cargo fmt --check
cargo clippy -- -D warnings
```

### Solidity (Contracts)

- **Linter:** [solhint](https://protofire.github.io/solhint/)
- **Version:** Solidity 0.8.24 with optimizer enabled
- **Base contracts:** OpenZeppelin v5
- **Testing:** Hardhat with ethers.js
- **File naming:** `PascalCase.sol`

```bash
cd contracts
npx solhint 'contracts/**/*.sol'
```

---

## Testing Requirements

All tests must pass before a PR can be merged. There are no exceptions.

### Per-Service Requirements

| Service | Command | Notes |
|---------|---------|-------|
| Contracts | `cd contracts && npx hardhat test` | Test all financial edge cases (overflow, zero amounts, unauthorized access) |
| Brain | `cd brain && pytest tests/ -v` | Tests run in mock mode; no GCP credentials required |
| Vault | `cd vault && cargo test` | Unit tests for `token_calculator` and `merkle` modules |
| Backend | `cd backend/functions && npm run build` | TypeScript strict mode compilation catches type errors |
| Frontend | `cd frontend/ideacapital && flutter test` | Model serialization tests (requires generated `.g.dart` files) |

### Writing New Tests

- When adding a new endpoint, add corresponding tests that cover success cases, validation errors, and edge cases.
- For the Brain service, ensure tests work in mock mode (no Vertex AI credentials).
- For the Vault, write unit tests for any new calculation or cryptographic logic.
- For contracts, test all modifier conditions, revert cases, and event emissions.

---

## Schema Changes

The canonical data contract lives at `schemas/InventionSchema.json`. This schema is mirrored in four languages, and **all mirrors must be updated together**.

### Files to Update

When modifying `InventionSchema.json`, you must update all of the following:

| Language | File | Model Type |
|----------|------|------------|
| JSON | `schemas/InventionSchema.json` | Canonical source of truth |
| Dart | `frontend/ideacapital/lib/models/invention.dart` | `json_serializable` class |
| TypeScript | `backend/functions/src/models/types.ts` | TypeScript interfaces |
| Python | `brain/src/models/invention.py` | Pydantic `BaseModel` classes |

Note: Rust (`vault/`) uses `serde_json::Value` for flexibility and does not maintain a direct struct mirror of the schema, but verify that any new fields are handled appropriately in Vault routes and services.

### Process

1. Make the change in `InventionSchema.json` first.
2. Update all four language mirrors.
3. Run `dart run build_runner build` in the Flutter project to regenerate serialization code.
4. Run tests in all affected services.
5. Document the schema change in your PR description.

---

## Security

### Secrets and Credentials

- **Never commit** `.env` files, private keys, API keys, or service account credentials.
- Use environment variables for all secrets. Refer to `.env.example` for the expected variable names.
- If you accidentally commit a secret, rotate it immediately and notify the maintainers.

### Vulnerability Reporting

If you discover a security vulnerability, **do not open a public issue**. Instead, report it privately to the project maintainers. Include:

1. A description of the vulnerability.
2. Steps to reproduce.
3. The potential impact.
4. A suggested fix, if you have one.

We will acknowledge receipt within 48 hours and work with you to understand and resolve the issue before any public disclosure.

### Security Practices

- Firestore security rules enforce authentication. Cloud Functions use the Firebase Admin SDK for privileged writes.
- Investment verification requires on-chain transaction receipt confirmation.
- Wallet addresses must be lowercased before any comparison.
- USDC amounts use 6 decimal precision; token amounts use 18 decimal precision. Ensure consistent handling across services to prevent financial calculation errors.
