# Contributing to SmartCushionEA

Thank you for your interest in contributing to SmartCushionEA! This document outlines the process for contributing to the project.

## Code of Conduct

By participating in this project, you agree to abide by the [Code of Conduct](CODE_OF_CONDUCT.md).

## How to Contribute

### Reporting Bugs

Before submitting a bug report:

- Check the existing [Issues](../../issues) to avoid duplicates.
- Make sure you can reproduce the issue with a clean compile of the latest `SmartCushionEA.mq5`.

When submitting a bug report, please include:

- MetaTrader 5 build number.
- Broker/symbol used (e.g., XAUUSDc on a cent account).
- The exact input parameters used.
- Relevant log output from the **Experts** tab.
- Steps to reproduce the issue.
- Expected behavior vs. actual behavior.

### Suggesting Enhancements

Enhancement suggestions are welcome via [Issues](../../issues). Please describe:

- The problem the enhancement would solve.
- A proposed approach, if you have one.
- Whether the enhancement would change default behavior (which may require a major version bump per [CHANGELOG.md](CHANGELOG.md) conventions).

### Submitting Changes

1. Fork the repository.
2. Create a feature branch from `main`:
   ```
   git checkout -b feature/your-feature-name
   ```
3. Make your changes to `SmartCushionEA.mq5`.
4. Compile the EA in MetaEditor and confirm there are no errors or warnings.
5. Test your changes in the MT5 Strategy Tester and/or a demo account.
6. Commit your changes with a clear, descriptive message.
7. Push to your fork and open a Pull Request against `main`.

### Pull Request Guidelines

- Keep pull requests focused on a single change or feature.
- Describe what changed and why in the PR description.
- Reference any related issues (e.g., `Closes #12`).
- Include before/after behavior notes if the change affects trading logic.
- Update `README.md` and `CHANGELOG.md` if your change affects input parameters, behavior, or documentation.
- Do not include personal account credentials, broker server details, or live trading logs/screenshots that expose account numbers or balances.

## Code Style

- Follow the existing MQL5 formatting conventions used in `SmartCushionEA.mq5` (brace style, indentation, and section header comments).
- Keep input parameter comments bilingual (Spanish | English) as used throughout the existing code, to maintain consistency.
- Prefer descriptive function and variable names consistent with the existing codebase (e.g., `ManagePositions`, `UpdateCushionFromHistory`).
- Avoid introducing external dependencies beyond the standard MQL5 `Trade` library already used.

## Testing Expectations

Since this is trading software, all logic changes should be validated using:

- The MT5 Strategy Tester, with **"Every tick based on real ticks"** mode where feasible.
- A demo account run over a reasonable period before being proposed for merge, when the change affects order placement, position management, or the cushion logic.

## Questions

If you have questions about contributing, feel free to open a [Discussion](../../discussions) or an [Issue](../../issues) labeled `question`.
