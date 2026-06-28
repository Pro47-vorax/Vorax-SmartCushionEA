# SmartCushionEA

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](CHANGELOG.md)
[![Status](https://img.shields.io/badge/status-experimental-orange.svg)](#disclaimer)
[![Platform](https://img.shields.io/badge/platform-MetaTrader%205-0a7cff.svg)](https://www.metatrader5.com/)
[![Language](https://img.shields.io/badge/language-MQL5-555555.svg)](https://www.mql5.com/)

**SmartCushionEA** is an open-source Expert Advisor (EA) for MetaTrader 5, written in MQL5, that implements a continuous pending-order trading approach combined with a persistent "profit cushion" system. Instead of relying on a fixed stop-loss for every trade, the EA tracks its own accumulated *closed* profit over time and uses that cushion to selectively close losing positions once it can do so without turning the overall realized result negative.

---

## ⚠️ Disclaimer

**This software is provided "as is", with no warranty of any kind, and is distributed as an open-source project under the MIT License.**

- Automated trading involves substantial risk of financial loss and is not suitable for everyone.
- This EA **does not guarantee profit, positive returns, or any specific outcome**.
- The author(s) and contributors accept **no liability** for any financial loss resulting from the use of this software.
- **Always test thoroughly on a demo account** (and/or in the MetaTrader 5 Strategy Tester) before considering any use with real funds.
- You are solely responsible for your own trading decisions, configuration choices, and compliance with your broker's and jurisdiction's regulations.

See [DISCLAIMER.md](DISCLAIMER.md) for the complete terms.

---

## Table of Contents

- [Features](#features)
- [How It Works](#how-it-works)
- [Requirements](#requirements)
- [Installation](#installation)
- [Configuration](#configuration)
- [Input Parameters](#input-parameters)
- [Usage Examples](#usage-examples)
- [Best Practices](#best-practices)
- [Risks of Automated Trading](#risks-of-automated-trading)
- [Known Limitations](#known-limitations)
- [Roadmap](#roadmap)
- [FAQ](#faq)
- [Support](#support)
- [Credits](#credits)
- [License](#license)

---

## Features

- **Continuous pending orders** — automatically maintains one Buy Stop and one Sell Stop near the current price, refreshing them at a configurable interval.
- **Fixed lot size** — no martingale-style lot scaling; every order uses the same configured lot.
- **Per-position Take Profit** — each position gets its own Take Profit, calculated in account currency using the symbol's tick value, so the target is expressed in money rather than raw price distance.
- **Per-position Breakeven** — once a position reaches a configurable profit (in points), its stop loss is moved to the entry price plus a small offset.
- **Per-position Trailing Stop** — once a position reaches a configurable profit threshold, its stop loss trails the market price at a fixed distance.
- **Persistent profit cushion** — realized profit/loss from closed deals (magic-number and symbol filtered) is accumulated and saved to a text file, surviving EA and terminal restarts.
- **Cushion-covered loss closing** — positions in floating loss are closed only when the accumulated cushion is large enough to absorb that specific loss, aiming to keep the net realized result positive over time.
- **Magic-number isolation** — all order, position, and history logic is filtered by `MagicNumber` and `_Symbol`, so the EA does not interact with manually placed trades or trades from other EAs.

## How It Works

On every tick, SmartCushionEA runs the following sequence:

1. **Cushion update** — scans the account's deal history for new closed deals matching its magic number and symbol, sums their realized profit/swap/commission, and adds the result to an internal accumulated cushion value. The cushion (and the last processed deal ticket) is persisted to a file.
2. **Position management** — for every open position belonging to the EA, breakeven and trailing stop conditions are evaluated independently, and the stop loss is adjusted accordingly.
3. **Cushion-covered loss closing** — for every open position currently in floating loss, the EA checks whether the accumulated cushion exceeds the magnitude of that loss. If it does, the position is closed immediately.
4. **Pending order maintenance** — on a configurable interval, the EA verifies that a Buy Stop and a Sell Stop are present near the current price (placing them if missing, or repositioning them if the price has moved too far away), each with a money-based Take Profit already attached.

The strategy does not use any external signal, indicator, or predictive model to decide trade direction — both a Buy Stop and a Sell Stop are always maintained, and the market itself determines which one is triggered.

## Requirements

- MetaTrader 5 (desktop terminal)
- An MT5 trading account (the EA was designed with a cent account in mind, but works with any account type)
- A broker/symbol that supports pending stop orders (`ORDER_TYPE_BUY_STOP`, `ORDER_TYPE_SELL_STOP`) and reports valid `SYMBOL_TRADE_TICK_VALUE` / `SYMBOL_TRADE_TICK_SIZE` data
- "Allow Algo Trading" enabled in the terminal and for the specific EA instance

## Installation

1. Download `SmartCushionEA.mq5` from this repository.
2. Open MetaTrader 5.
3. Go to **File → Open Data Folder**, then navigate to `MQL5/Experts`.
4. Copy `SmartCushionEA.mq5` into that folder.
5. In MetaTrader 5, open **MetaEditor** (F4), locate the file, and compile it (F7).
6. Restart MetaTrader 5 or refresh the Navigator panel so the EA appears under **Expert Advisors**.

## Configuration

1. Open a chart for the symbol you want to trade.
2. Drag **SmartCushionEA** from the Navigator panel onto the chart.
3. In the EA properties window, open the **Inputs** tab and set the parameters described below.
4. On the **Common** tab, make sure **"Allow Algo Trading"** is checked.
5. Click **OK** to attach the EA to the chart.
6. Check the **Experts** tab in the Toolbox for log messages confirming cushion loading and order placement.

The cushion file (`CushionFileName`, default `SmartCushionEA_cushion.txt`) is written either to the terminal's Common Files folder or to the local Files folder, depending on permissions. Back up this file if you want to preserve the accumulated cushion across machines.

## Input Parameters

### General

| Parameter | Default | Description |
|---|---|---|
| `Lot` | `0.01` | Fixed lot size used for every order. Not scaled. |
| `LevelDistance` | `1.0` | Distance (in price units) from the current price at which the Buy Stop / Sell Stop pair is placed. |
| `RefreshSeconds` | `30` | Interval, in seconds, at which the EA checks/repositions the pending order pair. |
| `MagicNumber` | `778911` | Magic number used to identify and isolate this EA's orders, positions, and deal history. |
| `SlippagePoints` | `20` | Maximum allowed slippage, in points, for trade operations. |
| `TradeComment` | `SmartCushionEA` | Comment attached to orders placed by the EA. |

### Take Profit

| Parameter | Default | Description |
|---|---|---|
| `TakeProfitMoney` | `10.0` | Target profit per position, expressed in account currency, used to calculate each position's Take Profit price via the symbol's tick value. |

### Breakeven (always active)

| Parameter | Default | Description |
|---|---|---|
| `BreakevenStart` | `30` | Profit, in points, required before the stop loss is moved to breakeven. |
| `BreakevenOffset` | `5` | Extra points added beyond the entry price when breakeven is applied. |

### Trailing Stop (always active)

| Parameter | Default | Description |
|---|---|---|
| `TrailingStart` | `60` | Profit, in points, required before trailing begins. |
| `TrailingDistance` | `40` | Distance, in points, maintained between the current price and the trailing stop loss. |
| `TrailingStep` | `5` | Minimum movement, in points, required before the stop loss is updated again. |

### Profit Cushion

| Parameter | Default | Description |
|---|---|---|
| `CushionFileName` | `SmartCushionEA_cushion.txt` | File name used to persist the accumulated closed profit and the last processed deal ticket. |

## Usage Examples

**Conservative cent-account setup** (small lot, tight distances):
```
Lot = 0.01
LevelDistance = 1.0
TakeProfitMoney = 5.0
BreakevenStart = 20
TrailingStart = 40
TrailingDistance = 25
```

**Wider Take Profit, slower cycle:**
```
Lot = 0.01
LevelDistance = 2.0
TakeProfitMoney = 20.0
RefreshSeconds = 60
```

Always validate any configuration in the Strategy Tester or on a demo account before using it on a live account.

## Best Practices

- **Always test on a demo account first**, ideally using the MT5 Strategy Tester with "Every tick based on real ticks" mode, since the EA's logic is tick-driven.
- **Match the account balance to the lot size and to the number of simultaneous positions** that the symbol's margin requirements would realistically allow.
- **Monitor the Experts log** regularly, especially the cushion update and covered-loss closing messages, to confirm the EA is behaving as expected.
- **Back up the cushion file** before terminal reinstalls, migrations, or major configuration changes.
- **Re-evaluate `TakeProfitMoney`, `LevelDistance`, and the trailing/breakeven settings** whenever volatility conditions change significantly for the traded symbol.

## Risks of Automated Trading

Automated trading systems, including this one, carry inherent financial risk:

- Positions opened via pending stop orders have **no initial stop loss** until breakeven or trailing conditions are met, meaning a losing position can accumulate significant floating loss before any protective mechanism activates.
- The cushion-covered loss closing logic depends entirely on previously accumulated *realized* profit. If the cushion is small or zero (for example, right after installation, or following a losing streak), losing positions may remain open indefinitely with no automatic exit.
- Market gaps, slippage, low liquidity, or broker-side execution issues can cause results that differ from theoretical expectations.
- Past behavior in backtests or on a demo account does not guarantee future results on a live account.
- Continuous order placement means the EA can hold multiple simultaneous positions, which increases margin usage and exposure compared to single-trade strategies.

**Use this software entirely at your own risk.** See [DISCLAIMER.md](DISCLAIMER.md) for full terms.

## Known Limitations

- The EA does not use any directional signal, indicator, or trend filter — it relies solely on price reaching a pending stop level.
- There is no built-in maximum number of simultaneous open positions; exposure is implicitly limited only by available margin and broker-imposed limits.
- The cushion-covered loss logic evaluates and closes qualifying positions individually, based on each position's own floating loss — it does not optimize which combination of positions to close.
- The cushion file uses a simple two-line text format; manual edits to this file are not validated and may produce undefined behavior.
- No news filter, time filter, or volatility filter is implemented.
- The logic assumes a broker that fully supports stop orders and standard `SYMBOL_TRADE_TICK_VALUE` / `SYMBOL_TRADE_TICK_SIZE` reporting; behavior on non-standard instruments is not guaranteed.

## Roadmap

Planned and potential future improvements:

- [ ] Optional maximum number of simultaneous open positions.
- [ ] Optional maximum floating drawdown safety cutoff.
- [ ] Configurable trading session / time filter.
- [ ] Optional volatility-based dynamic `LevelDistance`.
- [ ] On-chart dashboard/panel showing live cushion status.
- [ ] Multi-symbol cushion isolation improvements.
- [ ] Automated test suite using the MT5 Strategy Tester.

This roadmap reflects ideas under consideration and is not a commitment to a specific delivery timeline.

## FAQ

**Does this EA guarantee profit?**
No. No trading system can guarantee profit, and SmartCushionEA is no exception. The cushion mechanism manages *when* losing positions are closed relative to previously realized gains, but it cannot prevent losses, especially when the cushion itself is small.

**What happens if I restart MetaTrader 5?**
The accumulated cushion and the last processed deal ticket are reloaded from the cushion file in `OnInit()`, so the EA resumes with the same cushion value it had before the restart.

**Can I run this on multiple symbols at once?**
Yes, but each chart instance should use a distinct `MagicNumber` and a distinct `CushionFileName` to prevent cushion values from being mixed between symbols.

**Why doesn't a losing position close immediately?**
By design — a losing position is only closed once the accumulated cushion (realized profit from previously closed deals) exceeds that position's current floating loss. If the cushion is insufficient, the position remains open under its own breakeven/trailing management.

**Does the EA use martingale or lot scaling?**
No. The lot size is fixed via the `Lot` input and is never increased automatically.

## Support

If you encounter a bug, have a question, or want to propose an improvement, please use **[GitHub Issues](../../issues)**. When reporting a bug, include your MetaTrader 5 build, the symbol/broker used, your input parameters, and relevant log output from the **Experts** tab — see [CONTRIBUTING.md](CONTRIBUTING.md) for full guidelines.

This project does not offer private support channels (email, chat, or direct messages) for trading advice or account-specific issues.

## Credits

Developed iteratively through a series of design and refinement discussions, and implemented in MQL5 for the MetaTrader 5 platform.

## License

This project is licensed under the MIT License — see [LICENSE](LICENSE) for details.
