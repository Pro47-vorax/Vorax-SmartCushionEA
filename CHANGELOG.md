# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned
- Optional maximum number of simultaneous open positions.
- Optional maximum floating drawdown safety cutoff.
- Configurable trading session / time filter.
- Chart-based dashboard showing live cushion status.

## [1.0.0] - 2026-06-28

### Added
- Initial public release of `SmartCushionEA.mq5`.
- Continuous maintenance of a Buy Stop / Sell Stop pending order pair near the current price, refreshed on a configurable interval (`RefreshSeconds`).
- Fixed lot size trading (`Lot`), with no martingale-style scaling.
- Per-position Take Profit calculated from a money-based target (`TakeProfitMoney`) using the symbol's tick value and tick size.
- Per-position Breakeven logic (`BreakevenStart`, `BreakevenOffset`), always active.
- Per-position Trailing Stop logic (`TrailingStart`, `TrailingDistance`, `TrailingStep`), always active.
- Persistent profit cushion system: accumulates realized profit from closed deals (filtered by `MagicNumber` and symbol) and saves it to a text file (`CushionFileName`), surviving EA and terminal restarts.
- Cushion-covered loss closing: automatically closes individual positions in floating loss once the accumulated cushion exceeds that specific loss.
- Magic-number and symbol-based isolation across all order, position, and history operations.
