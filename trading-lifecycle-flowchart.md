# Complete Trading Lifecycle & Execution Flowchart

This document provides a visual guide and technical breakdown of the complete trading lifecycle for the **BTCUSD Scalping Expert Advisor** ([`SSLCHANEL-1.mq4`](file:///c:/Users/venuadmin/AppData/Roaming/MetaQuotes/Terminal/2191F4A3D14D7B4B1EBB84F924777883/MQL4/Experts/SSLCHANEL-1.mq4)).

---

## 1. High-Level Master Architecture

```mermaid
flowchart TD
    Tick(["Incoming BTCUSD Tick"]) --> GlobalCheck{"Global & Safety Gates"}
    
    GlobalCheck -->|"Daily Equity Stop Reached OR Dubai Pause"| Idle["Block New Orders & Maintain Active Trades"]
    GlobalCheck -->|"Trading Allowed"| ParallelOps["Execution Pipeline"]
    
    ParallelOps --> ModuleA["1. StopLoss Modification Engine (Every 500ms)"]
    ParallelOps --> ModuleB["2. Order Closing & Exit Engine (Every Tick)"]
    ParallelOps --> ModuleC["3. Order Creation & Entry Engine (On Signal)"]
    
    classDef main fill:#1e293b,stroke:#38bdf8,stroke-width:2px,color:#fff;
    classDef check fill:#334155,stroke:#f59e0b,stroke-width:2px,color:#fff;
    classDef act fill:#0f766e,stroke:#2dd4bf,stroke-width:2px,color:#fff;
    
    class Tick,ParallelOps main;
    class GlobalCheck check;
    class ModuleA,ModuleB,ModuleC,Idle act;
```

---

## 2. Order Creation Engine (When & How Orders Open)

Orders are only opened when an indicator signal occurs **AND** passes 8 layers of strict risk, timing, and gap filters.

```mermaid
flowchart TD
    StartSignal(["Signal Trigger Event"]) --> SigType{"Which Signal Fired?"}
    
    SigType -->|"SSL Channel Flip / Direction"| SSLGate["SSL Trend Direction (Buy=1, Sell=-1)"]
    SigType -->|"5-Min Bounceback / V-Shape"| VShapeGate["Bounceback Detection (>30pt Confirmation)"]
    
    SSLGate --> F1{"Gate 1: Daily Target Stop"}
    VShapeGate --> F1
    
    F1 -->|"g_dailyEquityTradingBlocked == true"| Abort1["ABORT: Daily Profit Target Already Hit"]
    F1 -->|"Trading Not Blocked"| F2{"Gate 2: Schedule & Pause"}
    
    F2 -->|"Dubai Pause Hour OR Halted Until Flip"| Abort2["ABORT: Session Paused"]
    F2 -->|"Session Active"| F3{"Gate 3: EMA 200 Filter"}
    
    F3 -->|"Price against EMA 200 trend"| Abort3["ABORT: Trend Conflict"]
    F3 -->|"Aligned with Trend"| F4{"Gate 4: Candle Limit"}
    
    F4 -->|"Order already made this candle"| Abort4["ABORT: 1 Candle 1 Order Rule"]
    F4 -->|"New Candle"| F5{"Gate 5: Max Orders"}
    
    F5 -->|"Total EA Orders >= MaxOpenOrders"| Abort5["ABORT: Max Orders Reached"]
    F5 -->|"Room Available"| F6{"Gate 6: Minimum Order Gap"}
    
    F6 -->|"Price too close to existing order"| Abort6["ABORT: Gap Under Dynamic Minimum"]
    F6 -->|"Sufficient Gap"| LotCalc["Calculate Lots & Multiplier"]
    
    LotCalc --> SLCalc["Calculate Initial Stop Loss (StopLossUSD distance)"]
    SLCalc --> ExecOrder["SafeOrderSend() $\rightarrow$ Order Created On Broker"]
```

### Detailed Order Creation Conditions:
| Stage | Condition | Purpose |
| :--- | :--- | :--- |
| **Signal Trigger** | SSL Indicator Direction = 1 (Bullish) or -1 (Bearish) | Primary entry signal |
| **Gate 1** | `!g_dailyEquityTradingBlocked` | Stop trading once daily equity goal is met |
| **Gate 2** | `!IsDubaiTradingPauseHour()` & `!TradingHaltedUntilNextFlip` | Avoid dead hours / high-spread sessions |
| **Gate 3** | `PassesEMAFilter(orderType)` | Never buy below or sell above EMA 200 |
| **Gate 4** | `IsOneCandleOrderAllowed()` | Limits EA to max 1 order per candle |
| **Gate 5** | `GetTotalEAOrders() < MaxOpenOrders` | Portfolio exposure cap |
| **Gate 6** | `HasMinimumSameOrderGap(...)` | Prevents clustering orders too close together |
| **Lot Sizing** | Scaled via `balancelomultipler` | Scales position size proportionally with account equity |

---

## 3. StopLoss Modification Engine (When & How SL Moves)

Stop Loss modifications run in real-time (throttled every 500 ms) and follow the **Ratchet Principle** (SL moves strictly forward into profit, never backward).

```mermaid
flowchart TD
    TickTrigger["OnTick() - Every 500ms"] --> ModeCheck{"Check Order Count by Direction"}
    
    ModeCheck -->|"All Open Orders"| IndivCheck["Individual Order Step Ladder (100 / 50)"]
    ModeCheck -->|"Count > 1 in Direction"| BasketCheck["Basket Cumulative Ladder ($2->$1, $4->$2, $8->$4)"]
    
    subgraph Individual_Order_Ladder ["Module 1: Individual Order Raw Price Ladder"]
        IndivCheck --> IndivMath{"Is Order Profit >= $100 Raw Gap?"}
        IndivMath -->|"Profit < $100"| IndivSkip["Keep Current SL"]
        IndivMath -->|"Profit >= $100"| CalcRung["Rung = Floor(Profit / 100)<br>TargetSL = OpenPrice +/- (Rung * 50)"]
        CalcRung --> SafeFilterA{"Anti-Churn & Safety Guard"}
    end
    
    subgraph Basket_Order_Ladder ["Module 2: Basket Cumulative Profit Ladder (Count > 1)"]
        BasketCheck --> BasketMath{"Cumulative Net Basket Profit"}
        BasketMath -->|"Profit >= $8"| Lock4["Lock $4.00 Cumulative Profit Floor"]
        BasketMath -->|"Profit >= $4"| Lock2["Lock $2.00 Cumulative Profit Floor"]
        BasketMath -->|"Profit >= $2"| Lock1["Lock $1.00 Cumulative Profit Floor"]
        BasketMath -->|"Profit < $2"| BasketSkip["Below $2 Milestone"]
        
        Lock4 --> DistributeSL["Calculate Unified Basket SL based on Allowable Giveback"]
        Lock2 --> DistributeSL
        Lock1 --> DistributeSL
        DistributeSL --> SafeFilterB{"Anti-Churn & Safety Guard"}
    end
    
    subgraph Safety_Guards ["Module 3: Anti-Churn & Error 130 Filter"]
        SafeFilterA --> G1{"Distance to Live Price < $15?"}
        SafeFilterB --> G1
        G1 -->|"YES (Too close)"| Reject1["SKIP: Prevent Error 130 (Invalid Stops)"]
        G1 -->|"NO (Safe gap)"| G2{"Is TargetSL Worse than CurrentSL?"}
        G2 -->|"YES"| Reject2["SKIP: Ratchet Rule (Never loosen SL)"]
        G2 -->|"NO"| G3{"Is SL Improvement < $10?"}
        G3 -->|"YES (Small change)"| Reject3["SKIP: Anti-Churn (Avoid server spam)"]
        G3 -->|"NO (Improvement >= $10)"| ApplyModify["EXECUTE: SafeOrderModify()"]
    end
```

### StopLoss Modification Situations:
1. **Single Order Running in Profit**:
   * When floating profit reaches **+$100** raw BTCUSD price distance $\rightarrow$ SL moved to **+$50**.
   * When floating profit reaches **+$200** $\rightarrow$ SL moved to **+$100**.
   * When floating profit reaches **+$300** $\rightarrow$ SL moved to **+$150** (every $100 step locks an additional $50).
2. **Cumulative Basket Running in Profit (Order Count > 1)**:
   * When combined net profit of all Buy (or Sell) orders hits **$2.00** $\rightarrow$ Stop Loss of all orders moved to protect **$1.00**.
   * When combined profit hits **$4.00** $\rightarrow$ Stop Loss moved to protect **$2.00**.
   * When combined profit hits **$8.00** $\rightarrow$ Stop Loss moved to protect **$4.00**.
3. **Basket Partial Protect (Individual Winners in Basket >= 2 Orders)**:
   * When a basket has **>= 2 orders** in the same direction, and **at least 2 orders are in profit**.
   * Any order with net profit **>= $1.00** has its Stop Loss adjusted to lock **$0.50** profit.
   * Scales step-wise: >= $2.00 -> $1.00 locked, etc.
   * **Crucial Rule:** Losing orders in the basket are **NEVER touched or loosened**.
   * Protects profitable positions even when a large or newer order in the basket is underwater and keeps overall cumulative basket profit negative.
4. **Profit & Ratchet Floor Guard (V7002)**:
   * **No Less Profit:** An order will **NEVER** be modified if the proposed new SL locks **less profit** than the current SL (e.g. if order already locks $1.00, any method attempting to set SL locking $0.70 is rejected).
   * **BUY:** `newSL` must NOT be less than or equal to `currentSL`.
   * **SELL:** `newSL` must NOT be greater than or equal to `currentSL`.
   * Checked globally inside `SafeOrderModify()` and in each trailing method individually.
5. **Anti-Churn Filter**:
   * If an order's proposed new SL is only $3, $5, or $8 better than its existing SL, the modification is **skipped** until the market moves far enough to provide at least a **$10** improvement.
6. **Broker Margin Filter**:
   * If the proposed SL is closer than $15 (or broker stop level) to current Bid/Ask, modification is delayed to prevent server **Error 130**.

---

## 4. Order Closing Engine (When & How Orders Exit)

Orders exit through one of six distinct paths:

```mermaid
flowchart TD
    ActiveOrder(["Active Market Order"]) --> ExitMonitor{"Exit Trigger Condition"}
    
    ExitMonitor -->|"1. Market touches Trailed SL"| ExitSL["Hard Stop Loss Hit (Locks In Profit Floor)"]
    ExitMonitor -->|"2. Market touches TP (if set)"| ExitTP["Take Profit Hit (Target Achieved)"]
    ExitMonitor -->|"3. Account Equity reaches Daily Target"| ExitDaily["IsDailyEquityStopReached() triggered:<br>Blocks new trades + Secures profit"]
    ExitMonitor -->|"4. Price pulls far from EMA 200"| ExitEMA["CloseOppositeOrdersOnEmaDistance():<br>Opposite trades closed on extreme stretch"]
    ExitMonitor -->|"5. 5% Equity Surplus Milestone"| ExitSurplus["Manage5PercentLadderReset():<br>Triggers baseline reset & profit lock"]
    ExitMonitor -->|"6. Deep Drawdown Partial De-risking"| ExitPartial["ManagePartialClosesLoss():<br>Closes 0.01 lots step-wise to reduce risk"]
    
    ExitSL --> Closed(["Trade Finished & Archived to History"])
    ExitTP --> Closed
    ExitDaily --> Closed
    ExitEMA --> Closed
    ExitSurplus --> Closed
    ExitPartial --> Closed
```

### Order Exit Situations:
| Exit Type | Situation | Action |
| :--- | :--- | :--- |
| **Trailed SL Exit** | Market pulls back and hits the trailed Stop Loss | Closes trade at locked profit (e.g. +$50, +$100, or basket floor) |
| **Daily Target Exit** | Total Account Equity hits the daily target (`g_dayOpeningBalance + Target`) | Trading stops for the day; orders are secured |
| **EMA Distance Exit** | Price deviates excessively from EMA 200 | Stale opposite orders that were lagging are closed out |
| **5% Surplus Reset** | Floating equity spikes significantly above balance | Locks gains and resets the equity baseline |
| **Partial Loss Close** | Large drawdown on individual order | Progressively closes 0.01 lot chunks every $100 raw drop to prevent account blowup |
| **V-Shape Bounceback** | Major 5-minute reversal pattern confirmed | Closes conflicting orders in the opposite direction |

---

## 5. Recovery Orders Strategy (Big Gap Protection & Independent/Orphan Profit Exit)

When an existing market trade suffers an unexpected adverse drawdown, the automated Recovery Engine steps in to protect the position with a discounted re-entry.

```mermaid
flowchart TD
    subgraph Trigger["1. Parent Drawdown & Big Gap Qualification"]
        P1["Parent Trade in Loss (<= -$1.00 USD)"] --> P2{"Adverse Price Gap Check<br>|Entry - LivePrice| >= 2000 raw BTC?"}
        P2 -->|"No"| PWait["Wait for Minimum Gap Distance"]
        P2 -->|"Yes"| P3{"Trend Resumption Aligns?<br>(SSL or EMA confirms direction)"}
        P3 -->|"No"| PWait2["Wait for Momentum Confirmation"]
        P3 -->|"Yes"| P4["Open RECOVERY_ Trade<br>(2x Parent Lots, Weak Pullback Filter Removed)"]
    end

    subgraph Monitor["2. Real-Time Pair & Orphan Monitoring (OnTick)"]
        P4 --> M1{"ManageRecoveryBasket()"}
        M1 --> M2{"Is Parent Trade Still Active?"}

        M2 -->|"YES: Parent is Active"| M3{"Profit Target Evaluation"}
        M3 -->|"Combined Basket Profit >= $1.00"| E1["1. COMBINED BASKET EXIT<br>Closes BOTH Parent & Recovery Together<br>(Wipes Parent Loss + Banks Net Profit)"]
        M3 -->|"Recovery Order Alone >= $1.00<br>(Combined basket still negative)"| E2["2. INDEPENDENT PROFIT BANK<br>Closes Recovery Order at Market<br>(Banks > $1 Cash, Parent Stays Active)"]
        M3 -->|"Neither Target Met"| MWait["Hold Pair & Monitor Live Ticks"]

        M2 -->|"NO: Parent Already Closed (Orphan)"| M4{"Orphan Profit Evaluation"}
        M4 -->|"Orphan Recovery Profit >= $1.00"| E3["3. CLEAN ORPHAN PROFIT EXIT<br>Closes Orphan Recovery Order at Market<br>(Banks > $1 Cash, No Invalid Parent Errors)"]
        M4 -->|"Profit < $1.00"| OWait["Hold Orphan Recovery Until Profit >= $1.00"]
    end

    E1 --> Done(["Cycle Finished & Capital Protected"])
    E2 --> ParentActive(["Parent Remains Open to Recover or Trigger Fresh Recovery Order"])
    E3 --> Done
```

### Key Recovery Mechanics:
1. **Trigger Requirements:**
   * **Minimum Adverse Gap:** Price must pull back by at least `RecoveryMinDistanceRaw = 2000` raw BTC points from parent entry.
   * **Parent Loss Threshold:** Parent floating loss must reach $\le -\$1.00$ (`dynamicRecoveryLossLimit`).
   * **Momentum Alignment:** SSL Channel or EMA 200 must confirm resumption in the trade direction.
   * **Zero Weak Pullback Block:** Restrictive weak pullback filter removed to ensure timely activation.
   * **Lot Sizing:** Opens at **2x parent volume** (`RecoveryLotMultiplier = 2.0`).
2. **Three Profit Exit Paths:**
   * **Path 1 (Combined Basket Win $\ge \$1.00$):** Closes parent and recovery order simultaneously, fully wiping the parent loss.
   * **Path 2 (Independent Profit Bank $>\$1.00$ with Parent Open):** Closes the recovery trade immediately at market to bank $> \$1.00$ cash while parent stays active to recover.
   * **Path 3 (Clean Orphan Exit $>\$1.00$ with Parent Closed):** If parent closed previously, the orphan recovery order closes cleanly at market without throwing errors.

---

## 6. Summary Cheat Sheet

| Event | Direction | Trigger Condition | Outcome |
| :--- | :--- | :--- | :--- |
| **Open Buy** | BUY | SSL Bullish + Above EMA 200 + Order Gap >= Min | Opens Buy with initial SL |
| **Open Sell** | SELL | SSL Bearish + Below EMA 200 + Order Gap >= Min | Opens Sell with initial SL |
| **Trail Single Buy** | BUY | `Bid - OpenPrice >= 100` | Moves SL to `OpenPrice + 50 * Rung` |
| **Trail Single Sell** | SELL | `OpenPrice - Ask >= 100` | Moves SL to `OpenPrice - 50 * Rung` |
| **Basket Buy Lock** | BUY | Cumulative Buy Profit >= $2 / $4 / $8 | Moves all Buy SLs to lock $1 / $2 / $4 |
| **Basket Sell Lock** | SELL | Cumulative Sell Profit >= $2 / $4 / $8 | Moves all Sell SLs to lock $1 / $2 / $4 |
| **Partial Basket Group Protect** | BUY / SELL | >= 2 orders in profit & Combined Winners Sum >= $1X ($1.00, $2.00, etc.) | Calculates unified SL locking $1X / 2 ($0.50, $1.00, etc.) across all winning orders; losing orders strictly untouched |
| **Profit Ratchet Floor** | BOTH | Proposed SL locks less profit than current SL OR worse price | Rejects modification; preserves higher locked profit |
| **Modify Guard** | BOTH | Gap to live price < $15 OR SL Change < $10 | Skips modification (avoids error/churn) |
| **Daily Stop Exit** | BOTH | Account Equity reaches daily target | Stops new orders & secures open trades |
| **Partial De-Risk** | BOTH | Drawdown hits loss tier + $100 price drop | Partially closes 0.01 lot to minimize risk |
| **Recovery Order Open** | BOTH | Adverse Gap >= 2000 raw BTC & Parent Loss <= -$1 & Trend Aligns | Opens 2x lots recovery order (weak pullback filter removed) |
| **Recovery Profit Exit** | BOTH | Combined >= $1 OR Recovery Order >= $1 (Parent Open / Orphan) | Banks > $1 profit immediately at market; parent stays active to recover |
