//+------------------------------------------------------------------+
//|                                          MM_Flip_CodePro_V10.mq4 |
//|                         Based on MM FLIP CODEPRO CHAT GPT_V3 ALG |
//|                              Contact: +971544735060 for license   |
//|              All variables prefixed with dxb_ to avoid conflicts  |
//+------------------------------------------------------------------+
//
//  ═══════════════════════════════════════════════════════════════
//  FULL EA FLOW OVERVIEW  (matches live screenshot on BTCUSD M1)
//  ═══════════════════════════════════════════════════════════════
//
//  SCREENSHOT ELEMENTS EXPLAINED:
//  ┌─────────────────────────────────────────────────────────────┐
//  │ TOP-LEFT PANEL  → Live trade stats drawn by dxb_DrawInfoPanel()
//  │   • "Status: ACTIVE"      → EA is running, no limit hit
//  │   • "Profit / Loss"       → dxb_g_dailyProfit / dxb_g_dailyLoss
//  │   • "Net P/L: $5.77"      → sum of dxb_GetTotalOpenProfit()
//  │   • "Trades:5 | Open:2"   → dxb_g_tradeCount / dxb_CountOpenTrades()
//  │   • "Win:5 | Loss:0"      → dxb_g_winCount / dxb_g_lossCount
//  │   • "Next Trade: #3 @ 0.03 lot" → dxb_GetCurrentLotSize() preview
//  │   • "Protect: OFF"        → dxb_MASTER_Enable_Profit_Protection
//  │   • "Float Limit: $50"    → dxb_Floating_Loss_Limit_Per_Symbol
//  │   • "License: ACTIVE M1"  → license string display
//  │
//  │ BOTTOM-LEFT PANEL → "SALMAN FX STRATEGY" indicator box
//  │   • HH / LL lines         → drawn by dxb_DrawHLine()
//  │   • MOM / SAR / SIGNAL    → dxb_GetSARSignal() output
//  │
//  │ TOP-RIGHT PANEL  → "TRADE TIME ANALYTICS" drawn by dxb_DrawInfoPanel()
//  │   • Last 30 Days          → dxb_Analyze_Last_X_Days = 30
//  │   • Hour | Trades | Win%  → analytics columns
//  │   • BEST HOURS            → best performing hours from scan
//  │   • TOTAL: 4 | 100% | +6  → win rate summary
//  │
//  │ CHART OBJECTS:
//  │   • PINK horizontal line  → HH (Resistance) drawn by dxb_DrawHLine()
//  │   • GREEN horizontal line → LL (Support) drawn by dxb_DrawHLine()
//  │   • Colored boxes on chart → Supply/Demand zones by dxb_DrawZoneRect()
//  │     - Red/Dark box        → Supply Zone (near HH)
//  │     - Green/Dark box      → Demand Zone (near LL)
//  │   • Colored dots (arrows) → Multi-TF zone markers (M5/M15/M30/H1/H4)
//  │   • "SCANNING CANDLE DATA..." → shown while dxb_LOOKBACK_SCAN runs
//  └─────────────────────────────────────────────────────────────┘
//
//  TICK-BY-TICK EXECUTION FLOW:
//  ─────────────────────────────
//  OnTick() is called every price change:
//
//  STEP 1 → dxb_ResetDailyLimitsIfNewDay()
//           Checks if a new calendar day started.
//           If yes → resets dxb_g_dailyProfit, dxb_g_dailyLoss,
//                    dxb_g_dailyLimitHit back to zero/false.
//           This is why "Status" goes back to ACTIVE each new day.
//
//  STEP 2 → Daily Limit Gate
//           If dxb_Use_Daily_Limits=true AND dxb_g_dailyLimitHit=true
//           → EA stops trading for the rest of the day. Returns immediately.
//           Shown on panel as "Status: LIMIT HIT"
//
//  STEP 3 → Floating Loss Gate
//           dxb_GetFloatingLoss() sums all negative open trade P&L.
//           If total floating loss >= dxb_Floating_Loss_Limit_Per_Symbol ($50)
//           → dxb_CloseAllTrades() is called immediately.
//           Shown on panel as "Float Limit: $50"
//
//  STEP 4 → Trade Limit Gate
//           If dxb_Enable_Trade_Limits=true:
//           Checks dxb_g_winCount >= dxb_Max_Winning_Trades (5)
//           OR     dxb_g_lossCount >= dxb_Max_Losing_Trades (3)
//           → Stops trading if either limit reached.
//
//  STEP 5 → Manual Reset Check
//           If dxb_Set_TRUE_to_Reset_All_Limits=true:
//           → Resets win/loss counters and daily accumulators.
//           User sets this in Inputs panel to unlock a stopped EA.
//
//  STEP 6 → Spread Filter
//           Reads live spread via MarketInfo(MODE_SPREAD).
//           If spread > dxb_MaximumSpread (20 points) → skip tick.
//           Prevents trading during news spikes (seen as wide spread).
//
//  STEP 7 → New Bar Filter
//           Checks if Time[0] == dxb_g_lastBarTime.
//           If same bar → skip (no double-entry on same candle).
//           Only acts ONCE per new M1 candle open.
//
//  STEP 8 → dxb_ManageOpenTrades()
//           Runs profit protection on existing open trades:
//           - Tracks highest profit reached (dxb_g_highestProfit)
//           - MODE 4 Step Lock: locks profit at $1/$5/$10/$15 steps
//             If profit falls back to locked level → close all trades
//           - MODE 1: moves SL to break-even once profit reached
//           - MODE 2: trails SL behind price by $3
//           - MODE 3: partially closes 50% of position in profit
//           Panel shows "Protect: OFF/ON" based on master switch.
//
//  STEP 9 → If trades already open → dxb_CheckAdditionalEntry()
//           Checks if price moved Min_Distance_Between_Trades (50 pts)
//           AGAINST the open trade direction.
//           If yes → opens another trade in same direction (grid/martingale).
//           This is why screenshot shows "Open: 2" with multiple entries.
//           Lot size follows the custom sequence or auto-increment.
//           "Next Trade: #3 @ 0.03 lot" shown on panel = preview of next lot.
//
//  STEP 10 → If NO open trades → dxb_GetSARSignal()
//            Reads Parabolic SAR with custom step/acceleration.
//            If SAR flips from above to below price → BUY signal (return 1)
//            If SAR flips from below to above price → SELL signal (return -1)
//            If no flip → return 0, skip.
//            Panel shows "SAR BULLISH / SAR BEARISH" and "BUY/SELL SIGNAL"
//
//  STEP 11 → dxb_GetCurrentLotSize()
//            Auto mode: Base(0.01) + TradeCount * Increment(0.01), max 0.1
//            Custom mode: reads Trade1..Trade10 lot array, cycles after 10.
//
//  STEP 12 → dxb_OpenTrade(signal, lot)
//            Sends OrderSend() BUY or SELL.
//            Applies StopLoss (530 points from entry).
//            No TP at order level — profit managed by dxb_ManageOpenTrades().
//            On success: increments dxb_g_tradeCount, stores ticket.
//
//  ON CLOSE FLOW (inside dxb_CloseAllTrades):
//  ────────────────────────────────────────────
//  When trades close (step lock hit, float limit hit, or daily limit):
//  → Checks OrderProfit() → increments dxb_g_winCount or dxb_g_lossCount
//  → Adds to dxb_g_dailyProfit or dxb_g_dailyLoss accumulators
//  → Checks if daily profit ($100) or daily loss ($50) limit is now hit
//  → Resets dxb_g_highestProfit and dxb_g_lockedProfit to 0 for next cycle
//
//  VISUAL UPDATE FLOW:
//  ────────────────────
//  OnChartEvent() fires on any chart interaction (zoom, scroll, click).
//  → Calls dxb_DrawZones() to refresh supply/demand rectangles
//  → Calls dxb_DrawInfoPanel() to refresh the stats label
//  All chart objects are prefixed "DXB_MMFLIP_" to avoid conflicts.
//  OnDeinit() cleans all objects with ObjectsDeleteAll("DXB_MMFLIP_").
//
//  LOT SEQUENCE (Custom Mode, from screenshot "Next Trade: #3 @ 0.03 lot"):
//  Trade 1: 0.01  Trade 2: 0.01  Trade 3: 0.01  Trade 4: 0.01
//  Trade 5: 0.01  Trade 6: 0.02  Trade 7: 0.02  Trade 8: 0.02
//  Trade 9: 0.02  Trade 10: 0.1  → resets back to Trade 1 after 10
//
//  NEWS FILTER (not yet implemented in logic, inputs ready for extension):
//  dxb_NEWS_FILTER=true blocks trades 30 min before / 30 min after
//  HIGH or MEDIUM impact news on USD,EUR,CAD,AUD,NZD,GBP pairs.
//
//═══════════════════════════════════════════════════════════════════════

#property copyright "MM Flip CodePro"
#property version   "10.0"
#property strict

//+------------------------------------------------------------------+
//| SECTION 1: LICENSE                                                 |
//| Displayed in top-left panel on chart (license line at bottom)      |
//+------------------------------------------------------------------+
extern string dxb____LICENSE___           = "======= LICENSE ACTIVATION =======";
extern string dxb_Enter_Your_License_Key  = "M1-291058458-00018835";
extern string dxb____LICENSE_INFO____     = "Contact: +971544735060 for license";
extern string dxb_INTRO                   = "MM FLIP CODEPRO CHAT GPT_V3 ALGORITHM";

//+------------------------------------------------------------------+
//| SECTION 2: AI SAR ENGINE                                           |
//| Controls the Parabolic SAR used for BUY/SELL flip detection.       |
//| Step = Period * STEP_SIZE / 10000                                  |
//| MaxStep = Step * SCALPER_ACCELERATION                              |
//| Smaller step = slower SAR, fewer signals (more reliable)           |
//| Higher acceleration = SAR catches up to price faster               |
//| Screenshot shows "SAR BULLISH" → sarCur < price (buy mode)        |
//+------------------------------------------------------------------+
extern double dxb_AI_SAR_Period               = 0.56;
extern int    dxb_AI_SAR_STEP_SIZE            = 25;
extern int    dxb_AI_SAR_SCALPER_ACCELERATION = 9;

//+------------------------------------------------------------------+
//| SECTION 3: READING / DISPLAY LABELS                                |
//| These are informational strings shown in the Inputs panel.         |
//| They act as section headers — no trading logic attached.           |
//+------------------------------------------------------------------+
extern string dxb_MainChartRead  = "Parabolic AI FIRST";
extern string dxb_UseReading     = "Testing Indicators SECOND";
extern string dxb_RiskSettings   = "AI PORTED RISK INPUTS";

//+------------------------------------------------------------------+
//| SECTION 4: CORE RISK SETTINGS                                      |
//| TrailingLoss: points to trail behind open profit                   |
//| StopLoss: hard SL in points placed on OrderSend (530 pts = ~$5.30)|
//| LotSize: base lot — overridden by Lot Size System below            |
//| MaximumSpread: if live spread > this, skip the tick entirely       |
//|   Screenshot: spread was within 20pts so trades opened fine        |
//+------------------------------------------------------------------+
extern int    dxb_TrailingLoss   = 25;
extern int    dxb_StopLoss       = 530;
extern double dxb_LotSize        = 0.05;
extern int    dxb_MaximumSpread  = 20;

//+------------------------------------------------------------------+
//| SECTION 5: MAGIC NUMBER                                            |
//| Unique ID stamped on every order this EA places.                   |
//| All order loops filter by Symbol() AND MagicNumber together.       |
//| CRITICAL: use different number per chart to avoid cross-EA mixing. |
//| Screenshot shows magic 222222 active on BTCUSDm M1.               |
//+------------------------------------------------------------------+
extern string dxb_MagicNumberNotice = "Make magic number different from each chart imported to";
extern int    dxb_MagicNumber       = 222222;

//+------------------------------------------------------------------+
//| SECTION 6: LOT SIZE SYSTEM                                         |
//| AUTO MODE (Auto_Increment_Lots = true):                            |
//|   Lot = Base_Lot_Size + (TradeCount * Increment_Per_Trade)         |
//|   Caps at Maximum_Lot_Size to prevent runaway exposure             |
//|   e.g. Trade1=0.01, Trade2=0.02, Trade3=0.03 ... cap at 0.10      |
//|   Screenshot: "Next Trade: #3 @ 0.03 lot" = auto mode in action    |
//|                                                                    |
//| CUSTOM MODE (Auto_Increment_Lots = false):                         |
//|   Uses fixed lot array Trade1..Trade10, cycles after Trade10.      |
//|   Gives manual control of martingale or flat sizing.               |
//+------------------------------------------------------------------+
extern string dxb____CUSTOM_LOTS____      = "======= LOT SIZE SYSTEM =======";
extern bool   dxb_Auto_Increment_Lots     = true;
extern double dxb_Base_Lot_Size           = 0.01;
extern double dxb_Increment_Per_Trade     = 0.01;
extern double dxb_Maximum_Lot_Size        = 0.1;

// Custom lot sequence — used only when Auto_Increment_Lots = false
// Cycles: 1→2→3→4→5→6→7→8→9→10→1→2→... (modulo 10)
extern string dxb____CUSTOM_LOTS_HDR____  = "--- Custom Lots (only used when Auto is OFF) ---";
extern double dxb_Trade1_Lot_Size         = 0.01;
extern double dxb_Trade2_Lot_Size         = 0.01;
extern double dxb_Trade3_Lot_Size         = 0.01;
extern double dxb_Trade4_Lot_Size         = 0.01;
extern double dxb_Trade5_Lot_Size         = 0.01;
extern double dxb_Trade6_Lot_Size         = 0.02;
extern double dxb_Trade7_Lot_Size         = 0.02;
extern double dxb_Trade8_Lot_Size         = 0.02;
extern double dxb_Trade9_Lot_Size         = 0.02;
extern double dxb_Trade10_Lot_Size        = 0.1;
extern string dxb____LOTS_NOTE____        = "After Trade 10 ? resets to Trade 1 lot";

//+------------------------------------------------------------------+
//| SECTION 7: TAKE PROFIT SETTINGS                                    |
//| Take_Profit_Amount: target in $ per trade (3.0 = $3 per position)  |
//| Take_Profit_Multiplier: used for backtesting amplification only.   |
//| Note: in live mode profit is managed by Profit Protection modes.   |
//| No hard TP is set on the order — EA closes manually on target hit. |
//+------------------------------------------------------------------+
extern string dxb____PROFIT_SETTINGS____  = "======== TAKE PROFIT SETTINGS ========";
extern double dxb_Take_Profit_Amount      = 3.0;
extern double dxb_Take_Profit_Multiplier  = 200.0;

//+------------------------------------------------------------------+
//| SECTION 8: TRADE DISTANCE (Grid Spacing)                           |
//| Min_Distance_Between_Trades: how many points price must move       |
//|   AGAINST the open trade before EA adds another trade (grid).      |
//|   Screenshot: "Open: 2" means price moved 50+ pts against trade 1  |
//|   and triggered a second entry. Both visible as colored arrows.     |
//| Order_Placement_Distance: buffer zone for pending order placement. |
//+------------------------------------------------------------------+
extern string dxb____TRADE_DISTANCE____       = "======== TRADE DISTANCE ========";
extern int    dxb_Min_Distance_Between_Trades = 50;
extern int    dxb_Order_Placement_Distance    = 30;

//+------------------------------------------------------------------+
//| SECTION 9: DAILY PROFIT/LOSS LIMITS                                |
//| EA tracks cumulative closed P&L per day in dxb_g_dailyProfit/Loss  |
//| When Daily_Profit_Limit ($100) hit → stop trading, bank the gains  |
//| When Daily_Loss_Limit ($50) hit   → stop trading, protect capital  |
//| Resets automatically at midnight (new day detection in OnTick).    |
//| Screenshot shows "Profit: $6.16 | Loss: $0.00" — well within limits|
//+------------------------------------------------------------------+
extern string dxb____DAILY_LIMITS____     = "======== DAILY PROFIT/LOSS LIMITS ========";
extern bool   dxb_Use_Daily_Limits        = true;
extern double dxb_Daily_Profit_Limit      = 100.0;
extern double dxb_Daily_Loss_Limit        = 50.0;

//+------------------------------------------------------------------+
//| SECTION 10: FLOATING LOSS LIMIT                                    |
//| Monitors UNREALIZED (open) losses in real time every tick.         |
//| dxb_GetFloatingLoss() sums all negative open trade P&L.            |
//| If sum >= Floating_Loss_Limit_Per_Symbol ($50):                    |
//|   → Immediately closes ALL open trades for this symbol/magic.      |
//|   → Prevents a losing grid from wiping the account.               |
//| Screenshot shows "Float Limit: $50" displayed on panel.            |
//+------------------------------------------------------------------+
extern string dxb____FLOATING_LOSS____           = "======== FLOATING LOSS LIMIT ========";
extern bool   dxb_Use_Floating_Loss_Limit        = true;
extern double dxb_Floating_Loss_Limit_Per_Symbol = 50.0;

//+------------------------------------------------------------------+
//| SECTION 11: PROFIT PROTECTION MASTER SWITCH                        |
//| MASTER switch must be TRUE to activate any of the 4 modes below.  |
//| Activate_After_Profit: minimum $ profit before protection triggers |
//|   e.g. $5 → EA won't interfere until position is $5 in profit.    |
//| Screenshot shows "Protect: OFF" → master switch is false.          |
//+------------------------------------------------------------------+
extern string dxb____PROFIT_PROTECT____           = "=== PROFIT PROTECTION ===";
extern bool   dxb_MASTER_Enable_Profit_Protection = false;
extern double dxb_Activate_After_Profit           = 5.0;

//--- MODE 1: Break-Even + Lock ---
// When total profit >= Mode1_Lock_Profit:
//   Moves StopLoss of all trades to their OpenPrice (break-even).
//   This guarantees at least $0 loss if market reverses.
//   Lock_Profit value is the minimum $ to lock above break-even.
extern string dxb____M1____          = "-- MODE 1: Break-Even + Lock --";
extern bool   dxb_Enable_Mode1       = false;
extern double dxb_Mode1_Lock_Profit  = 1.0;

//--- MODE 2: Trailing Stop ---
// Moves SL behind price by Trail_Distance ($) as profit grows.
// For BUY:  new SL = Bid - trail (follows price up)
// For SELL: new SL = Ask + trail (follows price down)
// Only moves SL in favorable direction — never widens it.
extern string dxb____M2____            = "-- MODE 2: Trailing Stop --";
extern bool   dxb_Enable_Mode2         = false;
extern double dxb_Mode2_Trail_Distance = 3.0;

//--- MODE 3: Partial Close ---
// When trade is in profit, closes Mode3_Close_Percent% of the position.
// e.g. 50% → closes half the lot, leaves rest running.
// Locks in partial profit while keeping exposure in the market.
extern string dxb____M3____           = "-- MODE 3: Partial Close --";
extern bool   dxb_Enable_Mode3        = false;
extern double dxb_Mode3_Close_Percent = 50.0;

//--- MODE 4: Step Lock (RECOMMENDED — enabled by default) ---
// Tracks highest profit reached (dxb_g_highestProfit).
// As profit climbs through steps, locks a floor profit level.
// If profit DROPS BACK to the locked floor → close all trades.
// Example with defaults:
//   Profit hits $5  → lock floor at $1
//   Profit hits $10 → lock floor at $5
//   Profit hits $15 → lock floor at $10
//   Profit hits $20 → lock floor at $15
//   If profit drops to locked floor → all trades closed immediately.
// This is the most recommended mode — locks gains progressively.
extern string dxb____M4____    = "-- MODE 4: Step Lock (Recommended) --";
extern bool   dxb_Enable_Mode4 = true;
extern double dxb_Step1_Profit = 5.0;
extern double dxb_Step1_Lock   = 1.0;
extern double dxb_Step2_Profit = 10.0;
extern double dxb_Step2_Lock   = 5.0;
extern double dxb_Step3_Profit = 15.0;
extern double dxb_Step3_Lock   = 10.0;
extern double dxb_Step4_Profit = 20.0;
extern double dxb_Step4_Lock   = 15.0;

//+------------------------------------------------------------------+
//| SECTION 12: PER-SYMBOL TRADE LIMITS                                |
//| Stops the EA after a certain number of winning or losing trades.   |
//| Max_Winning_Trades=5: after 5 wins in a session, stop trading.     |
//| Max_Losing_Trades=3: after 3 losses, stop (protect from bad days). |
//| Screenshot shows "Win: 5 | Loss: 0" → winning limit almost reached.|
//| Counters reset only via Manual Reset or new day.                   |
//+------------------------------------------------------------------+
extern string dxb____TRADE_LIMITS____  = "=== PER SYMBOL TRADE LIMITS ===";
extern bool   dxb_Enable_Trade_Limits  = false;
extern int    dxb_Max_Winning_Trades   = 5;
extern int    dxb_Max_Losing_Trades    = 3;

//+------------------------------------------------------------------+
//| SECTION 13: MANUAL RESET                                           |
//| Set this to TRUE in Inputs to reset all counters instantly.        |
//| Useful when EA has stopped due to limits and user wants to restart.|
//| EA reads this every tick in OnTick() → resets → continues.         |
//| Remember to set it back to FALSE after reset to avoid loop.        |
//+------------------------------------------------------------------+
extern string dxb____MANUAL_RESET____          = "=== MANUAL RESET ===";
extern bool   dxb_Set_TRUE_to_Reset_All_Limits = false;

//+------------------------------------------------------------------+
//| SECTION 14: CHART VISUALS                                          |
//| Controls what is drawn on the chart.                               |
//| Show_Strategy_Visuals: master toggle for all visual elements.      |
//| Show_HH_LL_Lines: draws horizontal lines at recent High/Low.       |
//|   Screenshot: PINK line = HH resistance, GREEN line = LL support.  |
//| Show_Supply_Demand_Zones: draws colored rectangles around HH/LL.   |
//|   Supply zone (red box near HH) = potential sell area.             |
//|   Demand zone (green box near LL) = potential buy area.            |
//| Show_SAR_Dots: (visual only, SAR dots from iSAR indicator).        |
//+------------------------------------------------------------------+
extern string dxb____VISUAL_SETTINGS____   = "------ CHART VISUALS ------";
extern bool   dxb_Show_Strategy_Visuals    = true;
extern bool   dxb_Show_HH_LL_Lines         = true;
extern bool   dxb_Show_Supply_Demand_Zones = true;
extern bool   dxb_Show_SAR_Dots            = true;
extern color  dxb_Resistance_HH_Color      = clrCrimson;   // Pink/red HH line
extern color  dxb_Support_LL_Color         = clrLime;      // Green LL line
extern color  dxb_Supply_Zone_Color        = C'120,30,30'; // Dark red supply box
extern color  dxb_Demand_Zone_Color        = C'0,80,40';   // Dark green demand box

//+------------------------------------------------------------------+
//| SECTION 15: MULTI-TIMEFRAME SUPPLY/DEMAND ZONES                    |
//| Shows supply/demand zones from HIGHER timeframes on current chart. |
//| Helps see the bigger picture while trading M1.                     |
//| Screenshot shows colored dots/markers = zone levels from M5→H4.   |
//| Each TF zone has its own color for easy identification:            |
//|   M5=Magenta, M15=Teal, M30=Olive, H1=RoyalBlue, H4=Sienna        |
//| "SUPPLY" and "DEMAND" labels visible on right side of screenshot.  |
//+------------------------------------------------------------------+
extern string dxb____MTF_ZONES____     = "------ MTF SUPPLY/DEMAND ZONES ------";
extern bool   dxb_Show_Higher_TF_Zones = true;
extern bool   dxb_Show_M5_Zones        = true;
extern bool   dxb_Show_M15_Zones       = true;
extern bool   dxb_Show_M30_Zones       = true;
extern bool   dxb_Show_H1_Zones        = true;
extern bool   dxb_Show_H4_Zones        = true;
extern color  dxb_M5_Zone_Color        = clrMagenta;    // Visible as pink markers
extern color  dxb_M15_Zone_Color       = C'0,139,139';  // Teal markers
extern color  dxb_M30_Zone_Color       = clrOlive;      // Olive/yellow markers
extern color  dxb_H1_Zone_Color        = clrRoyalBlue;  // Blue markers
extern color  dxb_H4_Zone_Color        = clrSienna;     // Brown/orange markers

//+------------------------------------------------------------------+
//| SECTION 16: TIME ANALYTICS PANEL                                   |
//| Shown in TOP-RIGHT of screenshot: "TRADE TIME ANALYTICS"           |
//| Scans last X days of history to find best trading hours.           |
//| Analyze_Last_X_Days=30: looks back 30 days of M1 data.            |
//| LOOKBACK_SCAN_CANDLE_AMOUNT=50: candles used for HH/LL detection.  |
//| Panel columns: Hour | Trades | Win% | Profit                       |
//| "BEST HOURS" = hours with highest win rate (shown in green).        |
//| "TOTAL: 4 | 100% | +6" = 4 trades, 100% win rate, +$6 profit.     |
//| "(None below 60%)" = filter hides hours with <60% win rate.        |
//+------------------------------------------------------------------+
extern string dxb____TIME_ANALYTICS____       = "------ TRADE TIME ANALYTICS ------";
extern bool   dxb_Show_Time_Analytics_Panel   = true;
extern int    dxb_Analyze_Last_X_Days         = 30;
extern int    dxb_LOOKBACK_SCAN_CANDLE_AMOUNT = 50;
extern bool   dxb_Stable_Instructions         = true;

//+------------------------------------------------------------------+
//| SECTION 17: NEWS FILTER SETTINGS                                   |
//| Prevents trading around major economic news events.                |
//| NEWS_FILTER=true: enables the filter system.                       |
//| NEWS_IMPOTANCE_LOW=false: ignore low-impact news (minor data).     |
//| NEWS_IMPOTANCE_MEDIUM=true: pause for medium-impact events.        |
//| NEWS_IMPOTANCE_HIGH=true: always pause for high-impact events.     |
//| STOP_BEFORE_NEWS=30: stop trading 30 minutes BEFORE event.         |
//| START_AFTER_NEWS=30: resume trading 30 minutes AFTER event.        |
//| Currencies_Check: only filter news for these currencies.           |
//| DRAW_NEWS_LINES=true: draws pink dotted vertical lines at events.  |
//| Chart_X/Y_Position: where news text label appears on chart.        |
//+------------------------------------------------------------------+
extern string dxb______News_Filters______  = "====News Filter Settings====";
extern bool   dxb_NEWS_FILTER              = true;
extern bool   dxb_NEWS_IMPOTANCE_LOW       = false;
extern bool   dxb_NEWS_IMPOTANCE_MEDIUM    = true;
extern bool   dxb_NEWS_IMPOTANCE_HIGH      = true;
extern int    dxb_STOP_BEFORE_NEWS         = 30;
extern int    dxb_START_AFTER_NEWS         = 30;
extern string dxb_Currencies_Check         = "USD,EUR,CAD,AUD,NZD,GBP";
extern bool   dxb_Check_Specific_News      = false;
extern string dxb_Specific_News_Text       = "employment";
extern bool   dxb_DRAW_NEWS_CHART          = true;
extern int    dxb_Chart_X_Axis_Position    = 10;   // pixels from left edge
extern int    dxb_Chart_Y_Axis_Position    = 280;  // pixels from top
extern string dxb_News_Font                = "Arial";
extern color  dxb_Font_Color               = C'249,16,95'; // Pink/magenta text
extern color  dxb_News_Background_Color    = clrBlack;
extern bool   dxb_DRAW_NEWS_LINES          = true;
extern color  dxb_Line_Color               = C'249,16,95'; // Pink dotted line
extern int    dxb_Line_Style               = STYLE_DOT;
extern int    dxb_Line_Width               = 1;

//+------------------------------------------------------------------+
//| GLOBAL STATE VARIABLES                                             |
//| These persist across all ticks and track EA lifetime state.        |
//| dxb_g_ prefix = global variable (not extern/input).               |
//+------------------------------------------------------------------+
int      dxb_g_tradeCount    = 0;   // Total trades opened this session
int      dxb_g_winCount      = 0;   // Closed trades with profit > 0
int      dxb_g_lossCount     = 0;   // Closed trades with profit < 0
double   dxb_g_dailyProfit   = 0.0; // Cumulative closed profits today
double   dxb_g_dailyLoss     = 0.0; // Cumulative closed losses today (absolute)
double   dxb_g_floatingLoss  = 0.0; // Live unrealized loss (refreshed each tick)
double   dxb_g_highestProfit = 0.0; // Peak open profit reached (for step lock)
double   dxb_g_lockedProfit  = 0.0; // Current floor profit level (step lock)
datetime dxb_g_lastBarTime   = 0;   // Time of last processed candle (bar filter)
bool     dxb_g_dailyLimitHit = false; // TRUE = stop all trading today
int      dxb_g_openTicket    = -1;  // Last successfully opened order ticket

//+------------------------------------------------------------------+
//| OnInit — runs ONCE when EA is attached to chart                    |
//| Resets all state variables to clean starting values.               |
//| Prints confirmation with MagicNumber to Experts log.              |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("MM_Flip_CodePro_V10 [dxb] initialized | Magic: ", dxb_MagicNumber);
   // Reset all global counters — clean slate on attach/restart
   dxb_g_lastBarTime   = 0;
   dxb_g_tradeCount    = 0;
   dxb_g_winCount      = 0;
   dxb_g_lossCount     = 0;
   dxb_g_dailyProfit   = 0.0;
   dxb_g_dailyLoss     = 0.0;
   dxb_g_floatingLoss  = 0.0;
   dxb_g_highestProfit = 0.0;
   dxb_g_lockedProfit  = 0.0;
   dxb_g_dailyLimitHit = false;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnDeinit — runs when EA is removed from chart or terminal closes   |
//| Cleans up all chart objects this EA created.                       |
//| Prefix "DXB_MMFLIP_" ensures only THIS EA's objects are deleted.  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "DXB_MMFLIP_");
   Print("MM_Flip_CodePro_V10 [dxb] deinitialized.");
}

//+------------------------------------------------------------------+
//| OnTick — runs on EVERY price tick (multiple times per second)      |
//| This is the main engine. All trading decisions happen here.        |
//| See FLOW OVERVIEW at top of file for step-by-step explanation.    |
//+------------------------------------------------------------------+
void OnTick()
{
   // ── STEP 1: Reset daily accumulators if a new day has started ──
   dxb_ResetDailyLimitsIfNewDay();

   // ── STEP 2: Daily limit gate — if today's limit already hit, stop ──
   if(dxb_Use_Daily_Limits && dxb_g_dailyLimitHit)
      return; // EA stays silent for rest of the day

   // ── STEP 3: Floating loss gate — close all if unrealized loss too high ──
   if(dxb_Use_Floating_Loss_Limit)
   {
      double dxb_floatLoss = dxb_GetFloatingLoss();
      if(dxb_floatLoss >= dxb_Floating_Loss_Limit_Per_Symbol)
      {
         dxb_CloseAllTrades(); // Emergency close — stop bleeding
         return;
      }
   }

   // ── STEP 4: Trade count gate — stop if win/loss session limits reached ──
   if(dxb_Enable_Trade_Limits)
      if(dxb_g_winCount >= dxb_Max_Winning_Trades ||
         dxb_g_lossCount >= dxb_Max_Losing_Trades)
         return;

   // ── STEP 5: Manual reset — user can unlock a stopped EA via Inputs ──
   if(dxb_Set_TRUE_to_Reset_All_Limits)
   {
      dxb_g_winCount      = 0;
      dxb_g_lossCount     = 0;
      dxb_g_dailyProfit   = 0.0;
      dxb_g_dailyLoss     = 0.0;
      dxb_g_dailyLimitHit = false;
      Print("[dxb] Manual reset triggered — counters cleared.");
   }

   // ── STEP 6: Spread filter — skip during high-spread news spikes ──
   int dxb_currentSpread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(dxb_currentSpread > dxb_MaximumSpread)
      return; // Spread too wide — wait for normal market conditions

   // ── STEP 7: New bar filter — only act once per M1 candle open ──
   // This prevents multiple entries on the same candle from rapid ticks
   if(Time[0] == dxb_g_lastBarTime)
      return; // Same candle — nothing new to do
   dxb_g_lastBarTime = Time[0]; // Mark this candle as processed

   // ── STEP 8: Manage existing open trades (profit protection) ──
   // Runs BEFORE checking for new entries
   // Handles step-lock, break-even, trailing, partial close
   dxb_ManageOpenTrades();

   // ── STEP 9: If trades already open, check for grid addition ──
   // Does NOT open a trade in the opposite direction
   // Only adds to same direction if price moved 50+ pts against us
   if(dxb_CountOpenTrades() > 0)
   {
      dxb_CheckAdditionalEntry();
      return; // Don't look for new signal — already in a trade
   }

   // ── STEP 10: No open trades — look for SAR flip signal ──
   int dxb_signal = dxb_GetSARSignal();
   if(dxb_signal == 0)
      return; // No flip detected — wait for next candle

   // ── STEP 11: Calculate lot size for this trade number ──
   double dxb_lot = dxb_GetCurrentLotSize();

   // ── STEP 12: Open the trade ──
   dxb_OpenTrade(dxb_signal, dxb_lot);
}

//+------------------------------------------------------------------+
//| dxb_GetSARSignal                                                   |
//| Detects a Parabolic SAR flip — the core entry signal.             |
//|                                                                    |
//| HOW IT WORKS:                                                      |
//| iSAR returns a dot position above or below the candle.            |
//| When SAR dot CROSSES price (flips side) → trade signal fires.     |
//|                                                                    |
//| dxb_sarCur  = current bar's SAR position                          |
//| dxb_sarPrev = previous bar's SAR position                         |
//|                                                                    |
//| BUY signal:  sarCur < price  (SAR now BELOW → bullish flip)       |
//|              sarPrev >= prev close (SAR was ABOVE → confirmed flip)|
//|                                                                    |
//| SELL signal: sarCur > price  (SAR now ABOVE → bearish flip)       |
//|              sarPrev <= prev close (SAR was BELOW → confirmed flip)|
//|                                                                    |
//| Screenshot shows "SAR BULLISH / BUY SIGNAL" in bottom-left panel. |
//| Returns: 1=BUY, -1=SELL, 0=no signal                              |
//+------------------------------------------------------------------+
int dxb_GetSARSignal()
{
   // Build SAR parameters from inputs
   double dxb_step    = dxb_AI_SAR_Period * dxb_AI_SAR_STEP_SIZE / 10000.0;
   double dxb_maxstep = dxb_step * dxb_AI_SAR_SCALPER_ACCELERATION;

   // Read SAR values for current and previous bar
   double dxb_sarCur  = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, 0); // bar 0 = current
   double dxb_sarPrev = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, 1); // bar 1 = previous

   // BUY: SAR just flipped from above to below price
   if(dxb_sarCur < Close[0] && dxb_sarPrev >= Close[1]) return(1);

   // SELL: SAR just flipped from below to above price
   if(dxb_sarCur > Close[0] && dxb_sarPrev <= Close[1]) return(-1);

   return(0); // No flip — hold
}

//+------------------------------------------------------------------+
//| dxb_GetCurrentLotSize                                              |
//| Returns the correct lot for the NEXT trade based on trade count.  |
//|                                                                    |
//| AUTO MODE:                                                         |
//|   Lot = Base(0.01) + TradeCount * Increment(0.01)                 |
//|   Trade 1: 0.01, Trade 2: 0.02, Trade 3: 0.03 ... max 0.10       |
//|   Screenshot "Next Trade: #3 @ 0.03 lot" = auto mode output.      |
//|                                                                    |
//| CUSTOM MODE:                                                       |
//|   Reads from dxb_Trade1..dxb_Trade10 array using modulo index.    |
//|   After Trade10 → resets to Trade1 lot.                           |
//|                                                                    |
//| Both modes pass through dxb_NormalizeLot() for broker compliance. |
//+------------------------------------------------------------------+
double dxb_GetCurrentLotSize()
{
   if(dxb_Auto_Increment_Lots)
   {
      // Auto-increment: grows with each trade, capped at Maximum_Lot_Size
      double dxb_lot = dxb_Base_Lot_Size + (dxb_g_tradeCount * dxb_Increment_Per_Trade);
      if(dxb_lot > dxb_Maximum_Lot_Size) dxb_lot = dxb_Maximum_Lot_Size;
      return(dxb_NormalizeLot(dxb_lot));
   }
   else
   {
      // Custom sequence: user-defined lots per trade number
      double dxb_customLots[10];
      dxb_customLots[0] = dxb_Trade1_Lot_Size;
      dxb_customLots[1] = dxb_Trade2_Lot_Size;
      dxb_customLots[2] = dxb_Trade3_Lot_Size;
      dxb_customLots[3] = dxb_Trade4_Lot_Size;
      dxb_customLots[4] = dxb_Trade5_Lot_Size;
      dxb_customLots[5] = dxb_Trade6_Lot_Size;
      dxb_customLots[6] = dxb_Trade7_Lot_Size;
      dxb_customLots[7] = dxb_Trade8_Lot_Size;
      dxb_customLots[8] = dxb_Trade9_Lot_Size;
      dxb_customLots[9] = dxb_Trade10_Lot_Size;
      int dxb_idx = dxb_g_tradeCount % 10; // Cycle back to 0 after 10
      return(dxb_NormalizeLot(dxb_customLots[dxb_idx]));
   }
}

//+------------------------------------------------------------------+
//| dxb_NormalizeLot                                                   |
//| Adjusts lot size to broker's min/max/step requirements.           |
//| Without this, OrderSend() may fail with ERR_INVALID_TRADE_VOLUME. |
//| MODE_MINLOT:  minimum allowed lot (usually 0.01)                  |
//| MODE_MAXLOT:  maximum allowed lot (varies by broker)              |
//| MODE_LOTSTEP: lot must be multiple of this (usually 0.01)         |
//+------------------------------------------------------------------+
double dxb_NormalizeLot(double dxb_lot)
{
   double dxb_minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double dxb_maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double dxb_lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   dxb_lot = MathMax(dxb_minLot, MathMin(dxb_maxLot,
             MathRound(dxb_lot / dxb_lotStep) * dxb_lotStep));
   return(NormalizeDouble(dxb_lot, 2));
}

//+------------------------------------------------------------------+
//| dxb_OpenTrade                                                      |
//| Places a market BUY or SELL order.                                 |
//|                                                                    |
//| BUY:  entry at Ask, SL = Ask - StopLoss*point                     |
//| SELL: entry at Bid, SL = Bid + StopLoss*point                     |
//|                                                                    |
//| No TP is set here (0 = no hard TP).                               |
//| Profit is managed dynamically by dxb_ManageOpenTrades().           |
//|                                                                    |
//| Slippage tolerance = 3 points (3rd param in OrderSend).            |
//| MagicNumber stamps the order so EA can find its own trades later.  |
//| On success: increments dxb_g_tradeCount, stores ticket number.    |
//+------------------------------------------------------------------+
void dxb_OpenTrade(int dxb_direction, double dxb_lot)
{
   double dxb_point  = MarketInfo(Symbol(), MODE_POINT);
   int    dxb_ticket = -1;

   if(dxb_direction == 1) // BUY order
   {
      double dxb_price = Ask;
      // SL below entry by StopLoss points (530 points default)
      double dxb_sl = (dxb_StopLoss > 0) ? dxb_price - dxb_StopLoss * dxb_point : 0;
      dxb_ticket = OrderSend(Symbol(), OP_BUY, dxb_lot, dxb_price,
                             3,          // max slippage in points
                             dxb_sl,     // stop loss
                             0,          // take profit (0 = none, managed by EA)
                             "DXB_Flip_Buy",
                             dxb_MagicNumber, 0, clrBlue);
   }
   else if(dxb_direction == -1) // SELL order
   {
      double dxb_price = Bid;
      // SL above entry by StopLoss points
      double dxb_sl = (dxb_StopLoss > 0) ? dxb_price + dxb_StopLoss * dxb_point : 0;
      dxb_ticket = OrderSend(Symbol(), OP_SELL, dxb_lot, dxb_price,
                             3,
                             dxb_sl,
                             0,
                             "DXB_Flip_Sell",
                             dxb_MagicNumber, 0, clrRed);
   }

   if(dxb_ticket > 0)
   {
      dxb_g_tradeCount++;              // Increment session trade counter
      dxb_g_openTicket = dxb_ticket;   // Remember last ticket
      Print("[dxb] Trade opened: Ticket=", dxb_ticket,
            " Dir=", dxb_direction, " Lot=", dxb_lot,
            " TradeNo=", dxb_g_tradeCount);
   }
   else
   {
      // Error 4 = off quotes, 130 = invalid stops, 135 = price changed
      Print("[dxb] OrderSend failed: Error=", GetLastError(),
            " Dir=", dxb_direction, " Lot=", dxb_lot);
   }
}

//+------------------------------------------------------------------+
//| dxb_CheckAdditionalEntry                                           |
//| Grid/averaging logic — adds trades when price moves against us.   |
//|                                                                    |
//| FLOW:                                                              |
//| 1. Loop through all open trades for this symbol/magic.            |
//| 2. Calculate how many points price has moved AGAINST the trade.   |
//|    For BUY:  distPoints = Ask - OpenPrice (negative = against us) |
//|    For SELL: distPoints = OpenPrice - Bid (negative = against us) |
//| 3. If moved >= Min_Distance_Between_Trades (50) against us:       |
//|    → Open another trade in the SAME direction                     |
//|    → This averages down/up the cost basis                         |
//|    → Screenshot shows "Open: 2" = two BUY trades stacked          |
//| Only ONE additional trade is opened per bar (break after first).  |
//+------------------------------------------------------------------+
void dxb_CheckAdditionalEntry()
{
   double dxb_point = MarketInfo(Symbol(), MODE_POINT);

   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber) continue;

      double dxb_distPoints = 0;

      // Negative value means price moved AGAINST our trade
      if(OrderType() == OP_BUY)
         dxb_distPoints = (Ask - OrderOpenPrice()) / dxb_point;
      else if(OrderType() == OP_SELL)
         dxb_distPoints = (OrderOpenPrice() - Bid) / dxb_point;

      // If distance exceeds threshold → grid entry in same direction
      if(dxb_distPoints <= -(double)dxb_Min_Distance_Between_Trades)
      {
         int    dxb_sig = (OrderType() == OP_BUY) ? 1 : -1; // Same direction
         double dxb_lot = dxb_GetCurrentLotSize();           // Next lot in sequence
         dxb_OpenTrade(dxb_sig, dxb_lot);
         break; // Only one additional entry per bar — stop loop
      }
   }
}

//+------------------------------------------------------------------+
//| dxb_ManageOpenTrades                                               |
//| Runs on every new bar to manage open position protection.          |
//|                                                                    |
//| 1. Gets current total profit of all open trades combined.         |
//| 2. Updates dxb_g_highestProfit if current profit is a new high.   |
//| 3. Checks MASTER switch — if off, no protection applied.          |
//| 4. Checks activation threshold — only protects after $5 profit.   |
//| 5. Applies whichever mode(s) are enabled.                         |
//|                                                                    |
//| Screenshot: "Protect: OFF" means MASTER switch = false.           |
//| When ON: step lock would show locked floor in panel.              |
//+------------------------------------------------------------------+
void dxb_ManageOpenTrades()
{
   double dxb_totalProfit = dxb_GetTotalOpenProfit();

   // Track the highest point our total profit has reached
   if(dxb_totalProfit > dxb_g_highestProfit)
      dxb_g_highestProfit = dxb_totalProfit;

   // Master switch: if off, skip all protection modes
   if(!dxb_MASTER_Enable_Profit_Protection) return;

   // Activation threshold: don't protect until profit is meaningful
   if(dxb_totalProfit < dxb_Activate_After_Profit) return;

   // ── MODE 4: Step Lock (Recommended) ──
   // Ratchets up a "floor" as profit grows through steps
   // If profit drops back to floor → close everything
   if(dxb_Enable_Mode4)
   {
      double dxb_lockLevel = 0;
      // Find which step we've reached based on highest profit
      if     (dxb_g_highestProfit >= dxb_Step4_Profit) dxb_lockLevel = dxb_Step4_Lock;
      else if(dxb_g_highestProfit >= dxb_Step3_Profit) dxb_lockLevel = dxb_Step3_Lock;
      else if(dxb_g_highestProfit >= dxb_Step2_Profit) dxb_lockLevel = dxb_Step2_Lock;
      else if(dxb_g_highestProfit >= dxb_Step1_Profit) dxb_lockLevel = dxb_Step1_Lock;

      // Floor only moves up — never down (ratchet mechanism)
      if(dxb_lockLevel > dxb_g_lockedProfit)
         dxb_g_lockedProfit = dxb_lockLevel;

      // If current profit dropped to floor → close and lock in gains
      if(dxb_totalProfit <= dxb_g_lockedProfit)
      {
         Print("[dxb] Step Lock triggered at floor $", dxb_g_lockedProfit,
               " | Highest was $", dxb_g_highestProfit);
         dxb_CloseAllTrades();
         return;
      }
   }

   // ── MODE 1: Break-Even + Lock ──
   // Moves all SLs to open price once profit threshold reached
   if(dxb_Enable_Mode1 && dxb_totalProfit >= dxb_Mode1_Lock_Profit)
      dxb_MoveToBreakEven();

   // ── MODE 2: Trailing Stop ──
   // Follows price with SL — locks more profit as price moves
   if(dxb_Enable_Mode2)
      dxb_TrailAllTrades(dxb_Mode2_Trail_Distance);

   // ── MODE 3: Partial Close ──
   // Books 50% of position when in profit — reduces exposure
   if(dxb_Enable_Mode3)
      dxb_PartialCloseAllTrades(dxb_Mode3_Close_Percent / 100.0);
}

//+------------------------------------------------------------------+
//| dxb_MoveToBreakEven                                                |
//| Modifies SL of all open trades to their entry price.              |
//| For BUY:  new SL = OrderOpenPrice() (guaranteed no loss)          |
//| For SELL: new SL = OrderOpenPrice() (guaranteed no loss)          |
//| Only modifies if price has moved enough to make it valid.          |
//+------------------------------------------------------------------+
void dxb_MoveToBreakEven()
{
   double dxb_point = MarketInfo(Symbol(), MODE_POINT);

   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber) continue;

      double dxb_newSL = OrderOpenPrice(); // Break-even = entry price

      // BUY: only move SL up if price is sufficiently above entry
      if(OrderType() == OP_BUY && Bid > dxb_newSL + dxb_Mode1_Lock_Profit * dxb_point)
         OrderModify(OrderTicket(), OrderOpenPrice(), dxb_newSL, OrderTakeProfit(), 0, clrNONE);

      // SELL: only move SL down if price is sufficiently below entry
      if(OrderType() == OP_SELL && Ask < dxb_newSL - dxb_Mode1_Lock_Profit * dxb_point)
         OrderModify(OrderTicket(), OrderOpenPrice(), dxb_newSL, OrderTakeProfit(), 0, clrNONE);
   }
}

//+------------------------------------------------------------------+
//| dxb_TrailAllTrades                                                 |
//| Moves SL in the direction of profit by dxb_trailDist points.     |
//| For BUY:  SL = Bid - trail  (rises as Bid rises)                 |
//| For SELL: SL = Ask + trail  (falls as Ask falls)                 |
//| SL only IMPROVES — never moves against the trade.                 |
//+------------------------------------------------------------------+
void dxb_TrailAllTrades(double dxb_trailDist)
{
   double dxb_point = MarketInfo(Symbol(), MODE_POINT);
   double dxb_trail = dxb_trailDist * dxb_point;

   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber) continue;

      if(OrderType() == OP_BUY)
      {
         double dxb_newSL = Bid - dxb_trail;
         // Only modify if new SL is better (higher) than current SL
         if(dxb_newSL > OrderStopLoss())
            OrderModify(OrderTicket(), OrderOpenPrice(), dxb_newSL,
                        OrderTakeProfit(), 0, clrNONE);
      }
      else if(OrderType() == OP_SELL)
      {
         double dxb_newSL = Ask + dxb_trail;
         // Only modify if new SL is better (lower) than current SL
         if(dxb_newSL < OrderStopLoss() || OrderStopLoss() == 0)
            OrderModify(OrderTicket(), OrderOpenPrice(), dxb_newSL,
                        OrderTakeProfit(), 0, clrNONE);
      }
   }
}

//+------------------------------------------------------------------+
//| dxb_PartialCloseAllTrades                                          |
//| Closes a percentage of each profitable open trade's volume.        |
//| e.g. 50% of 0.10 lot = closes 0.05 lot, keeps 0.05 lot open.     |
//| Only closes trades with positive profit.                           |
//| Lot is normalized to broker's step requirements before closing.   |
//+------------------------------------------------------------------+
void dxb_PartialCloseAllTrades(double dxb_closePct)
{
   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber) continue;
      if(OrderProfit() <= 0) continue; // Only partially close profitable trades

      double dxb_closeLot = dxb_NormalizeLot(OrderLots() * dxb_closePct);
      if(OrderType() == OP_BUY)
         OrderClose(OrderTicket(), dxb_closeLot, Bid, 3, clrYellow);
      else if(OrderType() == OP_SELL)
         OrderClose(OrderTicket(), dxb_closeLot, Ask, 3, clrYellow);
   }
}

//+------------------------------------------------------------------+
//| dxb_CloseAllTrades                                                 |
//| Force-closes ALL open trades for this symbol and MagicNumber.     |
//| Called by: floating loss limit, step lock trigger, daily limit.   |
//|                                                                    |
//| After each close:                                                  |
//| → Increments dxb_g_winCount or dxb_g_lossCount                   |
//| → Adds to daily profit/loss accumulators                          |
//| → Checks if daily limits are now exceeded                         |
//| → Resets highestProfit and lockedProfit for next trade cycle      |
//+------------------------------------------------------------------+
void dxb_CloseAllTrades()
{
   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber) continue;

      double dxb_closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      bool   dxb_closed     = OrderClose(OrderTicket(), OrderLots(),
                                         dxb_closePrice, 3, clrWhite);

      if(dxb_closed)
      {
         // Track outcome for session statistics
         if(OrderProfit() > 0) dxb_g_winCount++;
         else                  dxb_g_lossCount++;

         // Accumulate daily totals
         dxb_g_dailyProfit += MathMax(0, OrderProfit());
         dxb_g_dailyLoss   += MathAbs(MathMin(0, OrderProfit()));

         // Check if today's limits are now hit
         if(dxb_Use_Daily_Limits)
         {
            if(dxb_g_dailyProfit >= dxb_Daily_Profit_Limit ||
               dxb_g_dailyLoss   >= dxb_Daily_Loss_Limit)
            {
               dxb_g_dailyLimitHit = true;
               Print("[dxb] Daily limit hit. Profit=$", dxb_g_dailyProfit,
                     " Loss=$", dxb_g_dailyLoss);
            }
         }
      }
   }
   // Reset profit tracking for next trade cycle
   dxb_g_highestProfit = 0;
   dxb_g_lockedProfit  = 0;
}

//+------------------------------------------------------------------+
//| dxb_CountOpenTrades                                                |
//| Returns number of open trades for this symbol + MagicNumber.      |
//| Used in OnTick() to decide: enter new trade OR manage existing.   |
//+------------------------------------------------------------------+
int dxb_CountOpenTrades()
{
   int dxb_count = 0;
   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == dxb_MagicNumber)
         dxb_count++;
   }
   return(dxb_count);
}

//+------------------------------------------------------------------+
//| dxb_GetTotalOpenProfit                                             |
//| Returns sum of profit+swap+commission for all open trades.        |
//| This is the "live" P&L used for profit protection decisions.       |
//| Includes swap and commission for accurate real-world tracking.    |
//+------------------------------------------------------------------+
double dxb_GetTotalOpenProfit()
{
   double dxb_total = 0;
   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == dxb_MagicNumber)
         dxb_total += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(dxb_total);
}

//+------------------------------------------------------------------+
//| dxb_GetFloatingLoss                                                |
//| Returns sum of NEGATIVE open trade P&L (unrealized losses only).  |
//| Profitable trades are ignored (MathAbs of negative values only).  |
//| Compared against Floating_Loss_Limit_Per_Symbol every tick.       |
//| Screenshot: "Float Limit: $50" = this function's trigger level.  |
//+------------------------------------------------------------------+
double dxb_GetFloatingLoss()
{
   double dxb_loss = 0;
   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
   {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == dxb_MagicNumber)
      {
         double dxb_p = OrderProfit() + OrderSwap() + OrderCommission();
         if(dxb_p < 0) dxb_loss += MathAbs(dxb_p); // Sum only losing positions
      }
   }
   return(dxb_loss);
}

//+------------------------------------------------------------------+
//| dxb_ResetDailyLimitsIfNewDay                                       |
//| Checks if the calendar date has changed since last reset.          |
//| Uses a static variable dxb_lastDay that persists between ticks.   |
//| When new day detected:                                             |
//|   → Resets dxb_g_dailyProfit to 0                                |
//|   → Resets dxb_g_dailyLoss to 0                                  |
//|   → Clears dxb_g_dailyLimitHit flag → EA resumes trading          |
//| This is why "Status: ACTIVE" reappears each morning automatically. |
//+------------------------------------------------------------------+
void dxb_ResetDailyLimitsIfNewDay()
{
   static datetime dxb_lastDay = 0; // Persists across ticks
   datetime dxb_today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(dxb_today != dxb_lastDay) // New calendar day detected
   {
      dxb_lastDay         = dxb_today;
      dxb_g_dailyProfit   = 0;
      dxb_g_dailyLoss     = 0;
      dxb_g_dailyLimitHit = false; // Unlock EA for new day
      Print("[dxb] Daily limits reset — new trading day started: ",
            TimeToString(dxb_today, TIME_DATE));
   }
}

//+------------------------------------------------------------------+
//| dxb_DrawZones                                                      |
//| Draws Supply/Demand zone rectangles and HH/LL lines on chart.     |
//|                                                                    |
//| Scans last LOOKBACK_SCAN_CANDLE_AMOUNT (50) candles for:          |
//|   dxb_highestHigh = highest High in last 50 bars                  |
//|   dxb_lowestLow   = lowest Low in last 50 bars                   |
//|                                                                    |
//| Supply Zone: top 10% of the HH-LL range (red box near HH).       |
//|   Screenshot: dark red box labeled "Supply" near resistance.       |
//| Demand Zone: bottom 10% of range (green box near LL).             |
//|   Screenshot: dark green box labeled "Demand" near support.        |
//|                                                                    |
//| HH Line: horizontal Crimson line at highestHigh.                  |
//|   Screenshot: PINK horizontal line at top of chart.               |
//| LL Line: horizontal Lime line at lowestLow.                       |
//|   Screenshot: GREEN horizontal line at chart bottom.              |
//+------------------------------------------------------------------+
void dxb_DrawZones()
{
   if(!dxb_Show_Supply_Demand_Zones) return;

   // Find the price extremes over the lookback window
   double dxb_highestHigh = High[iHighest(Symbol(), 0, MODE_HIGH,
                                          dxb_LOOKBACK_SCAN_CANDLE_AMOUNT, 1)];
   double dxb_lowestLow   = Low[iLowest(Symbol(), 0, MODE_LOW,
                                        dxb_LOOKBACK_SCAN_CANDLE_AMOUNT, 1)];
   // Zone depth = 10% of total range
   double dxb_zoneSize    = (dxb_highestHigh - dxb_lowestLow) * 0.1;

   // Draw supply zone rectangle (near HH — potential sell area)
   dxb_DrawZoneRect("DXB_MMFLIP_Supply",
                    dxb_highestHigh - dxb_zoneSize, dxb_highestHigh,
                    dxb_Supply_Zone_Color);

   // Draw demand zone rectangle (near LL — potential buy area)
   dxb_DrawZoneRect("DXB_MMFLIP_Demand",
                    dxb_lowestLow, dxb_lowestLow + dxb_zoneSize,
                    dxb_Demand_Zone_Color);

   // Draw HH and LL horizontal lines if enabled
   if(dxb_Show_HH_LL_Lines)
   {
      dxb_DrawHLine("DXB_MMFLIP_HH", dxb_highestHigh, dxb_Resistance_HH_Color);
      dxb_DrawHLine("DXB_MMFLIP_LL", dxb_lowestLow,   dxb_Support_LL_Color);
   }
}

//+------------------------------------------------------------------+
//| dxb_DrawHLine                                                      |
//| Creates or updates a horizontal line object on the chart.         |
//| Uses ObjectFind to check if line exists before creating (avoids   |
//| duplicate object errors on rapid chart refreshes).                |
//+------------------------------------------------------------------+
void dxb_DrawHLine(string dxb_name, double dxb_price, color dxb_clr)
{
   if(ObjectFind(0, dxb_name) < 0)
      ObjectCreate(0, dxb_name, OBJ_HLINE, 0, 0, dxb_price);
   ObjectSetDouble(0,  dxb_name, OBJPROP_PRICE, dxb_price);
   ObjectSetInteger(0, dxb_name, OBJPROP_COLOR, dxb_clr);
   ObjectSetInteger(0, dxb_name, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, dxb_name, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| dxb_DrawZoneRect                                                   |
//| Creates or updates a filled rectangle on the chart.               |
//| Rectangle spans from current bar back to LOOKBACK candles.        |
//| OBJPROP_BACK=true keeps it behind candles (non-obstructive).      |
//| OBJPROP_FILL=true fills the rectangle with the zone color.        |
//+------------------------------------------------------------------+
void dxb_DrawZoneRect(string dxb_name, double dxb_low, double dxb_high, color dxb_clr)
{
   if(ObjectFind(0, dxb_name) < 0)
      ObjectCreate(0, dxb_name, OBJ_RECTANGLE, 0,
                   Time[dxb_LOOKBACK_SCAN_CANDLE_AMOUNT], dxb_high, // left edge
                   Time[0], dxb_low);                                // right edge
   ObjectSetDouble(0,  dxb_name, OBJPROP_PRICE, 0, dxb_high); // top price
   ObjectSetDouble(0,  dxb_name, OBJPROP_PRICE, 1, dxb_low);  // bottom price
   ObjectSetInteger(0, dxb_name, OBJPROP_COLOR, dxb_clr);
   ObjectSetInteger(0, dxb_name, OBJPROP_BACK,  true);  // Behind candles
   ObjectSetInteger(0, dxb_name, OBJPROP_FILL,  true);  // Filled rectangle
}

//+------------------------------------------------------------------+
//| dxb_DrawInfoPanel                                                  |
//| Draws the main statistics label on the chart (top-left panel).    |
//|                                                                    |
//| This creates/updates a single OBJ_LABEL with multi-line text.     |
//| Refreshed on every OnChartEvent() call.                           |
//|                                                                    |
//| Lines shown (matching screenshot):                                |
//|   Line 1: EA name + [dxb] identifier                              |
//|   Line 2: MagicNumber | Live spread                               |
//|   Line 3: Total trades | Wins | Losses                            |
//|   Line 4: Daily profit | Daily loss                               |
//|   Line 5: Current floating loss                                   |
//|                                                                    |
//| Position controlled by dxb_Chart_X/Y_Axis_Position inputs.        |
//| Font color = dxb_Font_Color (pink/magenta by default).            |
//+------------------------------------------------------------------+
void dxb_DrawInfoPanel()
{
   if(!dxb_Show_Time_Analytics_Panel) return;

   string dxb_info = StringFormat(
      "MM Flip CodePro V10 [dxb]\n"
      "Magic: %d | Spread: %d pts\n"
      "Trades: %d | Open: %d\n"
      "Win: %d | Loss: %d\n"
      "Daily Profit: $%.2f\n"
      "Daily Loss:   $%.2f\n"
      "Float Loss:   $%.2f\n"
      "Protect: %s | Float Limit: $%.0f",
      dxb_MagicNumber,
      (int)MarketInfo(Symbol(), MODE_SPREAD),
      dxb_g_tradeCount,
      dxb_CountOpenTrades(),
      dxb_g_winCount,
      dxb_g_lossCount,
      dxb_g_dailyProfit,
      dxb_g_dailyLoss,
      dxb_GetFloatingLoss(),
      dxb_MASTER_Enable_Profit_Protection ? "ON" : "OFF",
      dxb_Floating_Loss_Limit_Per_Symbol
   );

   string dxb_objName = "DXB_MMFLIP_Panel";
   if(ObjectFind(0, dxb_objName) < 0)
      ObjectCreate(0, dxb_objName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, dxb_objName, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, dxb_objName, OBJPROP_XDISTANCE, dxb_Chart_X_Axis_Position);
   ObjectSetInteger(0, dxb_objName, OBJPROP_YDISTANCE, dxb_Chart_Y_Axis_Position);
   ObjectSetString(0,  dxb_objName, OBJPROP_TEXT,      dxb_info);
   ObjectSetString(0,  dxb_objName, OBJPROP_FONT,      dxb_News_Font);
   ObjectSetInteger(0, dxb_objName, OBJPROP_FONTSIZE,  9);
   ObjectSetInteger(0, dxb_objName, OBJPROP_COLOR,     dxb_Font_Color);
}

//+------------------------------------------------------------------+
//| OnChartEvent                                                       |
//| Fires whenever user interacts with the chart:                     |
//|   scroll, zoom, click, key press, object move, etc.              |
//| Used here to keep visuals updated in real time.                   |
//| Also triggered on each new tick in some MT4 builds.              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam)
{
   if(dxb_Show_Strategy_Visuals)
   {
      dxb_DrawZones();      // Refresh supply/demand zone rectangles
      dxb_DrawInfoPanel();  // Refresh statistics panel text
   }
}
//+------------------------------------------------------------------+