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

#property copyright "ABC S1"
#property version   "1.0"
#property strict

//+------------------------------------------------------------------+
//| SECTION 1: LICENSE                                                 |
//| Displayed in top-left panel on chart (license line at bottom)      |
//+------------------------------------------------------------------+
string dxb____LICENSE___           = "=";//====== LICENSE ACTIVATION =======";
string dxb_Enter_Your_License_Key  = "";//M1";
string dxb____LICENSE_INFO____     = "";//Contact: + for license";
string dxb_INTRO                   = "";//   CHAT GPT_V3 ";

//+------------------------------------------------------------------+
//| SECTION 2: AI SAR ENGINE                                           |
//| Controls the Parabolic SAR used for BUY/SELL flip detection.       |
//| Step = Period * STEP_SIZE / 10000                                  |
//| MaxStep = Step * SCALPER_ACCELERATION                              |
//| Smaller step = slower SAR, fewer signals (more reliable)           |
//| Higher acceleration = SAR catches up to price faster               |
//| Screenshot shows "SAR BULLISH" → sarCur < price (buy mode)        |
//+------------------------------------------------------------------+
double dxb_AI_SAR_Period               = 1.2;//0.56;
int    dxb_AI_SAR_STEP_SIZE            = 25;
int    dxb_AI_SAR_SCALPER_ACCELERATION = 9;

//+------------------------------------------------------------------+
//| SECTION 3: READING / DISPLAY LABELS                                |
//| These are informational strings shown in the Inputs panel.         |
//| They act as section headers — no trading logic attached.           |
//+------------------------------------------------------------------+
string dxb_MainChartRead  = "Parabolic AI FIRST";
string dxb_UseReading     = "Testing Indicators SECOND";
string dxb_RiskSettings   = "AI PORTED RISK INPUTS";

//+------------------------------------------------------------------+
//| SECTION 4: CORE RISK SETTINGS                                      |
//| TrailingLoss: points to trail behind open profit                   |
//| StopLoss: hard SL in points placed on OrderSend (530 pts = ~$5.30)|
//| LotSize: base lot — overridden by Lot Size System below            |
//| MaximumSpread: if live spread > this, skip the tick entirely       |
//|   Screenshot: spread was within 20pts so trades opened fine        |
//+------------------------------------------------------------------+
int    dxb_TrailingLoss   = 25;
int    dxb_StopLoss       = 200;//530;
double dxb_LotSize        = 0.05;
int    dxb_MaximumSpread  = 2000;

//+------------------------------------------------------------------+
//| SECTION 5: MAGIC NUMBER                                            |
//| Unique ID stamped on every order this EA places.                   |
//| All order loops filter by Symbol() AND MagicNumber together.       |
//| All order loops filter by Symbol() AND MagicNumber together.       |
//| CRITICAL: use different number per chart to avoid cross-EA mixing. |
//| Screenshot shows magic 222222 active on BTCUSDm M1.               |
//+------------------------------------------------------------------+
string dxb_MagicNumberNotice = "Make magic number different from each chart imported to";
int    dxb_MagicNumber_Live  = 989898;
int    dxb_MagicNumber_Test  = 111111;

string dxb_session_name="-----";

int dxb_MagicNumber; // Set automatically in OnInit()

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
string dxb____CUSTOM_LOTS____      = "======= LOT SIZE SYSTEM =======";
bool   dxb_Auto_Increment_Lots     = true;
double dxb_Base_Lot_Size           = 0.01;
double dxb_Increment_Per_Trade     = 0.01;
double dxb_Maximum_Lot_Size        = 0.10;

//+------------------------------------------------------------------+
//| MAX OPEN ORDERS LIMIT                                             |
//+------------------------------------------------------------------+
int dxb_Max_Open_Orders = 8;

// Custom lot sequence — used only when Auto_Increment_Lots = false
// Cycles: 1→2→3→4→5→6→7→8→9→10→1→2→... (modulo 10)
string dxb____CUSTOM_LOTS_HDR____  = "--- Custom Lots (only used when Auto is OFF) ---";
double dxb_Trade1_Lot_Size         = 0.01;
double dxb_Trade2_Lot_Size         = 0.02;
double dxb_Trade3_Lot_Size         = 0.03;
double dxb_Trade4_Lot_Size         = 0.04;
double dxb_Trade5_Lot_Size         = 0.01;
double dxb_Trade6_Lot_Size         = 0.01;
double dxb_Trade7_Lot_Size         = 0.01;
double dxb_Trade8_Lot_Size         = 0.01;
double dxb_Trade9_Lot_Size         = 0.01;
double dxb_Trade10_Lot_Size        = 0.01;//0.1;
string dxb____LOTS_NOTE____        = "After Trade 10 ? resets to Trade 1 lot";

//+------------------------------------------------------------------+
//| SECTION 7: TAKE PROFIT SETTINGS                                    |
//| Take_Profit_Amount: target in $ per trade (3.0 = $3 per position)  |
//| Take_Profit_Multiplier: used for backtesting amplification only.   |
//| Note: in live mode profit is managed by Profit Protection modes.   |
//| No hard TP is set on the order — EA closes manually on target hit. |
//+------------------------------------------------------------------+
string dxb____PROFIT_SETTINGS____  = "======== TAKE PROFIT SETTINGS ========";
double dxb_Take_Profit_Multiplier  = 100.0;

//+------------------------------------------------------------------+
//| SECTION 8: TRADE DISTANCE (Grid Spacing)                           |
//| Min_Distance_Between_Trades: how many points price must move       |
//|   AGAINST the open trade before EA adds another trade (grid).      |
//|   Screenshot: "Open: 2" means price moved 50+ pts against trade 1  |
//|   and triggered a second entry. Both visible as colored arrows.     |
//| Order_Placement_Distance: buffer zone for pending order placement. |
//+------------------------------------------------------------------+
string dxb____TRADE_DISTANCE____       = "======== TRADE DISTANCE ========";
int    dxb_Min_Distance_Between_Trades = 100;
int    dxb_Order_Placement_Distance    = 30;

//+------------------------------------------------------------------+
//| SECTION 9: DAILY PROFIT/LOSS LIMITS                                |
//| EA tracks cumulative closed P&L per day in dxb_g_dailyProfit/Loss  |
//| When Daily_Profit_Limit ($100) hit → stop trading, bank the gains  |
//| When Daily_Loss_Limit ($50) hit   → stop trading, protect capital  |
//| Resets automatically at midnight (new day detection in OnTick).    |
//| Screenshot shows "Profit: $6.16 | Loss: $0.00" — well within limits|
//+------------------------------------------------------------------+
string dxb____DAILY_LIMITS____     = "======== DAILY PROFIT/LOSS LIMITS ========";
bool   dxb_Use_Daily_Limits        = false;
double dxb_Daily_Profit_Limit      = 100.0;
double dxb_Daily_Loss_Limit        = 100.0;

//+------------------------------------------------------------------+
//| SECTION 10: FLOATING LOSS LIMIT                                    |
//| Monitors UNREALIZED (open) losses in real time every tick.         |
//| dxb_GetFloatingLoss() sums all negative open trade P&L.            |
//| If sum >= Floating_Loss_Limit_Per_Symbol ($50):                    |
//|   → Immediately closes ALL open trades for this symbol/magic.      |
//|   → Prevents a losing grid from wiping the account.               |
//| Screenshot shows "Float Limit: $50" displayed on panel.            |
//+------------------------------------------------------------------+
string dxb____FLOATING_LOSS____           = "======== FLOATING LOSS LIMIT ========";
bool   dxb_Use_Floating_Loss_Limit        = true;
double dxb_Floating_Loss_Limit_Per_Symbol = 10.0;//stoploss open trade  stop loss
double dxb_Take_Profit_Amount      = 1;//3.0;


//+------------------------------------------------------------------+
//| SECTION 11: PROFIT PROTECTION MASTER SWITCH                        |
//| MASTER switch must be TRUE to activate any of the 4 modes below.  |
//| Activate_After_Profit: minimum $ profit before protection triggers |
//|   e.g. $5 → EA won't interfere until position is $5 in profit.    |
//| Screenshot shows "Protect: OFF" → master switch is false.          |
//+------------------------------------------------------------------+
string dxb____PROFIT_PROTECT____           = "=== PROFIT PROTECTION ===";
bool   dxb_MASTER_Enable_Profit_Protection = false;
double dxb_Activate_After_Profit           = 5.0;

//--- MODE 1: Break-Even + Lock ---
// When total profit >= Mode1_Lock_Profit:
//   Moves StopLoss of all trades to their OpenPrice (break-even).
//   This guarantees at least $0 loss if market reverses.
//   Lock_Profit value is the minimum $ to lock above break-even.
string dxb____M1____          = "-- MODE 1: Break-Even + Lock --";
bool   dxb_Enable_Mode1       = false;
double dxb_Mode1_Lock_Profit  = 1.0;

//--- MODE 2: Trailing Stop ---
// Moves SL behind price by Trail_Distance ($) as profit grows.
// For BUY:  new SL = Bid - trail (follows price up)
// For SELL: new SL = Ask + trail (follows price down)
// Only moves SL in favorable direction — never widens it.
string dxb____M2____            = "-- MODE 2: Trailing Stop --";
bool   dxb_Enable_Mode2         = false;
double dxb_Mode2_Trail_Distance = 3.0;

//--- MODE 3: Partial Close ---
// When trade is in profit, closes Mode3_Close_Percent% of the position.
// e.g. 50% → closes half the lot, leaves rest running.
// Locks in partial profit while keeping exposure in the market.
string dxb____M3____           = "-- MODE 3: Partial Close --";
bool   dxb_Enable_Mode3        = false;
double dxb_Mode3_Close_Percent = 50.0;

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
string dxb____M4____    = "-- MODE 4: Step Lock (Recommended) --";
bool   dxb_Enable_Mode4 = true;
double dxb_Step1_Profit = 5.0;
double dxb_Step1_Lock   = 1.0;
double dxb_Step2_Profit = 10.0;
double dxb_Step2_Lock   = 5.0;
double dxb_Step3_Profit = 15.0;
double dxb_Step3_Lock   = 10.0;
double dxb_Step4_Profit = 20.0;
double dxb_Step4_Lock   = 15.0;

//+------------------------------------------------------------------+
//| SECTION 12: PER-SYMBOL TRADE LIMITS                                |
//| Stops the EA after a certain number of winning or losing trades.   |
//| Max_Winning_Trades=5: after 5 wins in a session, stop trading.     |
//| Max_Losing_Trades=3: after 3 losses, stop (protect from bad days). |
//| Screenshot shows "Win: 5 | Loss: 0" → winning limit almost reached.|
//| Counters reset only via Manual Reset or new day.                   |
//+------------------------------------------------------------------+
string dxb____TRADE_LIMITS____  = "=== PER SYMBOL TRADE LIMITS ===";
bool   dxb_Enable_Trade_Limits  = false;
int    dxb_Max_Winning_Trades   = 50;
int    dxb_Max_Losing_Trades    = 2;

//+------------------------------------------------------------------+
//| SECTION 13: MANUAL RESET                                           |
//| Set this to TRUE in Inputs to reset all counters instantly.        |
//| Useful when EA has stopped due to limits and user wants to restart.|
//| EA reads this every tick in OnTick() → resets → continues.         |
//| Remember to set it back to FALSE after reset to avoid loop.        |
//+------------------------------------------------------------------+
string dxb____MANUAL_RESET____          = "=== MANUAL RESET ===";
bool   dxb_Set_TRUE_to_Reset_All_Limits = false;

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
string dxb____VISUAL_SETTINGS____   = "------ CHART VISUALS ------";
bool   dxb_Show_Strategy_Visuals    = true;
bool   dxb_Show_HH_LL_Lines         = true;
bool   dxb_Show_Supply_Demand_Zones = true;
bool   dxb_Show_SAR_Dots            = true;
color  dxb_Resistance_HH_Color      = clrCrimson;   // Pink/red HH line
color  dxb_Support_LL_Color         = clrLime;      // Green LL line
color  dxb_Supply_Zone_Color        = C'120,30,30'; // Dark red supply box
color  dxb_Demand_Zone_Color        = C'0,80,40';   // Dark green demand box

//+------------------------------------------------------------------+
//| SECTION 15: MULTI-TIMEFRAME SUPPLY/DEMAND ZONES                    |
//| Shows supply/demand zones from HIGHER timeframes on current chart. |
//| Helps see the bigger picture while trading M1.                     |
//| Screenshot shows colored dots/markers = zone levels from M5→H4.   |
//| Each TF zone has its own color for easy identification:            |
//|   M5=Magenta, M15=Teal, M30=Olive, H1=RoyalBlue, H4=Sienna        |
//| "SUPPLY" and "DEMAND" labels visible on right side of screenshot.  |
//+------------------------------------------------------------------+
string dxb____MTF_ZONES____     = "------ MTF SUPPLY/DEMAND ZONES ------";
bool   dxb_Show_Higher_TF_Zones = true;
bool   dxb_Show_M5_Zones        = true;
bool   dxb_Show_M15_Zones       = true;
bool   dxb_Show_M30_Zones       = true;
bool   dxb_Show_H1_Zones        = true;
bool   dxb_Show_H4_Zones        = true;
color  dxb_M5_Zone_Color        = clrMagenta;    // Visible as pink markers
color  dxb_M15_Zone_Color       = C'0,139,139';  // Teal markers
color  dxb_M30_Zone_Color       = clrOlive;      // Olive/yellow markers
color  dxb_H1_Zone_Color        = clrRoyalBlue;  // Blue markers
color  dxb_H4_Zone_Color        = clrSienna;     // Brown/orange markers

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
string dxb____TIME_ANALYTICS____       = "------ TRADE TIME ANALYTICS ------";
bool   dxb_Show_Time_Analytics_Panel   = true;
int    dxb_Analyze_Last_X_Days         = 30;
int    dxb_LOOKBACK_SCAN_CANDLE_AMOUNT = 50;
bool   dxb_Stable_Instructions         = true;

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
string dxb______News_Filters______  = "====News Filter Settings====";
bool   dxb_NEWS_FILTER              = false;
bool   dxb_NEWS_IMPOTANCE_LOW       = false;
bool   dxb_NEWS_IMPOTANCE_MEDIUM    = true;
bool   dxb_NEWS_IMPOTANCE_HIGH      = true;
int    dxb_STOP_BEFORE_NEWS         = 30;
int    dxb_START_AFTER_NEWS         = 30;
string dxb_Currencies_Check         = "USD,EUR,CAD,AUD,NZD,GBP";
bool   dxb_Check_Specific_News      = false;
string dxb_Specific_News_Text       = "employment";
bool   dxb_DRAW_NEWS_CHART          = true;
int    dxb_Chart_X_Axis_Position    = 10;   // pixels from left edge
int    dxb_Chart_Y_Axis_Position    = 280;  // pixels from top
string dxb_News_Font                = "Arial";
color  dxb_Font_Color               = C'249,16,95'; // Pink/magenta text
color  dxb_News_Background_Color    = clrBlack;
bool   dxb_DRAW_NEWS_LINES          = true;
color  dxb_Line_Color               = C'249,16,95'; // Pink dotted line
int    dxb_Line_Style               = STYLE_DOT;
int    dxb_Line_Width               = 1;

string dxb____EQUITY_LOSS____       = "=== EQUITY LOSS LIMIT ===";
bool   dxb_Enable_Equity_Loss       = false;
double dxb_Max_Equity_Loss_Percent  = 10.0; // stop if equity drops 10%
double dxb_Max_Equity_Loss_Dollar   = 5.0; // OR stop if equity drops $50
bool   dxb_Use_Percent_Mode         = false;  // true=%, false=$

extern int lot_multiplier=1;




double dxb_g_startEquity = 0.0; // equity recorded at EA start
bool   dxb_g_equityHit   = false; // TRUE = equity limit breached

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
bool     dxb_g_isTesting     = false;
int      dxb_g_lastDrawBar   = -1;
string   dxb_g_statusText  = "ACTIVE";
double   dxb_g_cachedHH    = 0.0;
double   dxb_g_cachedLL    = 0.0;

//+------------------------------------------------------------------+
//| OnInit — runs ONCE when EA is attached to chart                    |
//| Resets all state variables to clean starting values.               |
//| Prints confirmation with MagicNumber to Experts log.              |
//+------------------------------------------------------------------+
int GetMagicNumberFromTime()
  {
   datetime now = TimeCurrent();

   int day    = TimeDay(now);
   int hour   = TimeHour(now);
   int minute = TimeMinute(now);
   int second = TimeSeconds(now);

// Random 2-digit number (10-99)
   int rnd = MathRand() % 90 + 10;

// Format: DDHHMMSSRR
   int magic =
      day    * 100000000 +
      hour   * 1000000 +
      minute * 10000 +
      second * 100 +
      rnd;

   return magic;
  }
//+------------------------------------------------------------------+
//| STRICT DISTANCE CHECK FOR SAME SIDE ORDERS                       |
//+------------------------------------------------------------------+//+------------------------------------------------------------------+
//| STRICT PRICE DIFFERENCE CHECK                                    |
//| Uses REAL PRICE difference, NOT points                           |
//+------------------------------------------------------------------+
bool dxb_IsDistanceValid(int orderType, double minPriceDistance)
  {
   double currentPrice =
      (orderType == OP_BUY) ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == dxb_MagicNumber &&
            OrderType() == orderType)
           {
            double priceDiff =
               MathAbs(currentPrice - OrderOpenPrice());

            if(priceDiff < minPriceDistance)
              {
               Print(
                  "[dxb] BLOCKED. PriceDiff=",
                  DoubleToString(priceDiff,2),
                  " Required=",
                  DoubleToString(minPriceDistance,2)
               );

               return false;
              }
           }
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Print(
      "TRADING STATUS | ",
      "TradeAllowed=", IsTradeAllowed(),
      " Spread=", MarketInfo(Symbol(), MODE_SPREAD),
      " BuyOrders=", CountOrders(OP_BUY),
      " SellOrders=", CountOrders(OP_SELL),
      " Time=", TimeToString(TimeCurrent(), TIME_SECONDS)
   );

   dxb_g_startEquity = AccountEquity();
   dxb_g_equityHit   = false;


   Print("V101-15 MIN STATUS |"+AccountNumber()+" BUY=",
         CountOrders(OP_BUY),
         " SELL=",
         CountOrders(OP_SELL),
         " TOTAL PL=$",
         DoubleToString(GetAllEAProfit(),2));


   dxb_g_isTesting = IsTesting();

// dxb_MagicNumber_Live=GetMagicNumberFromTime();

   dxb_MagicNumber_Live=AccountNumber()+1;



   dxb_MagicNumber = dxb_g_isTesting ? dxb_MagicNumber_Test : dxb_MagicNumber_Live;

   Print(" [dxb] initialized | Magic: ", dxb_MagicNumber);
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
   dxb_g_lastDrawBar   = -1;
   update_lot_multiplier();

   Print("V1 Started: $"+ dxb_g_startEquity+" equity | Final Multiplier: " + lot_multiplier);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| OnDeinit — runs when EA is removed from chart or terminal closes   |
//| Cleans up all chart objects this EA created.                       |
//| Prefix "DXB_MMFLIP_" ensures only THIS EA's objects are deleted.  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
// ObjectsDeleteAll(0, "DXB_MMFLIP_");
   Print("  [dxb] deinitialized.");
  }

//+------------------------------------------------------------------+
//| OnTick — runs on EVERY price tick (multiple times per second)      |
//| This is the main engine. All trading decisions happen here.        |
//| See FLOW OVERVIEW at top of file for step-by-step explanation.    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_RefreshVisuals()
  {
   if(!dxb_Show_Strategy_Visuals)
      return;

// Only redraw once per bar (not every tick — saves CPU)
   int dxb_currentBar = Bars;
   if(dxb_currentBar == dxb_g_lastDrawBar)
      return;
   dxb_g_lastDrawBar = dxb_currentBar;

   dxb_DrawZones();
   dxb_DrawSARDots();
   dxb_DrawInfoPanel();
   dxb_DrawStrategyPanel();
   dxb_DrawTimeAnalytics();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string dxb_GetSessionStatus()
  {
   string active = "";
   if(sessionNY)
      active += (active == "" ? "" : ", ") + "New York";
   if(sessionUS)
      active += (active == "" ? "" : ", ") + "US";
   if(sessionEU)
      active += (active == "" ? "" : ", ") + "Europe";
   if(sessionASIA)
      active += (active == "" ? "" : ", ") + "Asia";
   if(sessionDEAD)
      active += (active == "" ? "" : ", ") + "Dead Zone";
   return active == "" ? "No active session" : active;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string dxb_GetSessionDots()
  {
   string dots = "";
   dots += (sessionNY   ? "[NY:ON]"   : "[NY:--]") + "";
   dots += (sessionUS   ? "[US:ON]"   : "[US:--]") + "";
   dots += (sessionEU   ? "[EU:ON]"   : "[EU:--]") + "";
   dots += (sessionASIA ? "[AS:ON]"   : "[AS:--]") + "";
   dots += (sessionDEAD ? "[DEAD:ON]" : "[DEAD:--]");
   return dots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_UpdateDisplay(string dxb_status)
  {
   dxb_g_statusText = dxb_status;
   string dxb_msg = StringFormat(
                       "   Slipper:   Parabolic SAR flip  V10 [dxb]\n"
                       "Magic: %d | %s\n"
                       "Status: %s\n"
                       "Session: %s\n"
                       "%s\n",
                       dxb_MagicNumber,
                       dxb_g_isTesting ? "TESTER" : "LIVE",
                       dxb_status,
                       dxb_GetSessionStatus(),
                       dxb_GetSessionDots()
                    );
   static string dxb_last_msg = "";
   if(dxb_msg != dxb_last_msg)
     {
      // Print(dxb_msg);
      dxb_last_msg = dxb_msg;
     }
   Comment(dxb_msg);
  }

//+------------------------------------------------------------------+
//| NEWS STORAGE                                                       |
//+------------------------------------------------------------------+
#define DXB_MAX_NEWS 50
datetime dxb_NewsTime[DXB_MAX_NEWS];
string   dxb_NewsTitle[DXB_MAX_NEWS];
string   dxb_NewsCurrency[DXB_MAX_NEWS];
string   dxb_NewsImpact[DXB_MAX_NEWS];
int      dxb_NewsCount    = 0;
datetime dxb_LastNewsFetch = 0;
#define  DXB_FETCH_INTERVAL 3600
#define  DXB_NEWS_URL "https://nfs.faireconomy.media/ff_calendar_thisweek.csv"

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool dxb_IsBigCandleLast5Min()
  {
   for(int i = 1; i <= 5; i++)
     {
      double dxb_height = (High[i] - Low[i]) / Point;

      // Print(dxb_height);

      if(dxb_height > 10000)
        {
         Print("[dxb] BIG CANDLE bar ", i,
               " | Height: ", DoubleToStr(dxb_height, 0), " pts",
               " | High: ",   High[i],
               " | Low: ",    Low[i],
               " | Time: ",   TimeToString(Time[i], TIME_MINUTES));
         return(true);
        }
     }
   return(false);
  }
string sessionName="";
int    g_digits;
double g_point;

double g_LotSize = 0.01; // global lot variable



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void update_lot_multiplier()
  {
   double balance = AccountBalance();

// how many $20 units
   double multiplier = balance / 200.0;

   if(multiplier < 1)
      multiplier = 1;

// lot = multiplier * 0.01
   double lot = multiplier * 0.01;

// normalize
   lot = NormalizeDouble(lot, 2);

   g_LotSize      = lot;
   lot_multiplier = multiplier;

// Print("Balance=", balance,
//       " | Lot=", lot,
//       " | Multiplier=", lot_multiplier);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetAllEAProfit()
  {
   double totalProfit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == dxb_MagicNumber)
        {
         totalProfit +=
            OrderProfit() +
            OrderSwap() +
            OrderCommission();
        }
     }

   return totalProfit;
  }
datetime last15MinPrintTime = 0;
int CountOrders(int orderType)
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == dxb_MagicNumber &&
            OrderType() == orderType)
           {
            total++;
           }
        }
     }

   return total;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

if(!IsTesting())
if(AccountNumber() != 289058672)//single account
{
   return ;
}

   // if(AccountNumber() == 289052334)// || AccountNumber() == 291058458)// Replace with your actual account number
   //   {
   //    sessionNY=false;
   //    sessionUS=false;
   //    sessionEU=false;
   //    sessionASIA=false;
   //    sessionDEAD=false;
      
   //   }
   // else
     {
      sessionNY=false;
      sessionUS=false;
      sessionEU=false;
      sessionASIA=true;
      sessionDEAD=false;
     }


     




   if(TimeCurrent() - last15MinPrintTime >= 900) // 900 sec = 15 min
     {
      Print("V1-15 MIN STATUS "+AccountNumber()+"| BUY=",
            CountOrders(OP_BUY),
            " SELL=",
            CountOrders(OP_SELL),
            " TOTAL PL=$",
            DoubleToString(GetAllEAProfit(),2));

      last15MinPrintTime = TimeCurrent();
     }

   update_lot_multiplier();

   g_point  = MarketInfo(Symbol(), MODE_POINT);
   if(g_digits == 0)
      g_digits = 2;

// Add this block in OnTick() between STEP 6 and STEP 7
   dxb_ApplySessionSettings(); // ← ADD THIS ONE LINE ONLY


   dxb_Floating_Loss_Limit_Per_Symbol=20;
     if(TimeDayOfWeek(TimeCurrent()) == 0 || TimeDayOfWeek(TimeCurrent()) == 6)
     {
       
      dxb_Take_Profit_Amount=0.50;
      
     }


   double atr = iATR(Symbol(), Period(), 14, 1);
// dxb_Floating_Loss_Limit_Per_Symbol = NormalizeDouble(atr * 1.5, 2);   g_digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   dxb_Floating_Loss_Limit_Per_Symbol=dxb_Floating_Loss_Limit_Per_Symbol*lot_multiplier;//*10;


// EQUITY LOSS GATE
   if(dxb_Enable_Equity_Loss && !dxb_g_equityHit)
     {

      dxb_Floating_Loss_Limit_Per_Symbol=dxb_Floating_Loss_Limit_Per_Symbol*lot_multiplier;//*10;

      double dxb_currentEquity = AccountEquity();
      double dxb_equityDrop    = dxb_g_startEquity - dxb_currentEquity;
      // dxb_g_startEquity=dxb_g_startEquity==0?1:dxb_g_startEquity;
      if(dxb_g_startEquity==0)
         dxb_g_startEquity=1;


      double dxb_dropPercent   = (dxb_equityDrop / dxb_g_startEquity) * 100.0;

      bool dxb_limitBreached = false;

      if(dxb_Use_Percent_Mode && dxb_dropPercent >= dxb_Max_Equity_Loss_Percent)
         dxb_limitBreached = true;



      // dxb_Max_Equity_Loss_Dollar
      if(!dxb_Use_Percent_Mode && dxb_equityDrop >= dxb_Floating_Loss_Limit_Per_Symbol)
         dxb_limitBreached = true;

      if(dxb_limitBreached)
        {
         dxb_g_equityHit = true;
         Print("[dxb] EQUITY LOSS LIMIT HIT — Start: $", dxb_g_startEquity,
               " | Now: $", dxb_currentEquity,
               " | Drop: $", dxb_equityDrop,
               " (", dxb_dropPercent, "%)");
         dxb_CloseAllTrades("Equity Loss Limit Hit");
         dxb_UpdateDisplay(StringFormat(
                              "EQUITY LIMIT HIT — Drop: $%.2f (%.1f%%)",
                              dxb_equityDrop, dxb_dropPercent));
         return;
        }
     }

// Show live equity drop on panel every tick
   if(dxb_Enable_Equity_Loss)
     {
      double dxb_currentEquity = AccountEquity();
      double dxb_dropPercent   = ((dxb_g_startEquity - dxb_currentEquity)
                                  / dxb_g_startEquity) * 100.0;
      // displayed in panel below
     }





   dxb_DrawLiveStatus(); // top-center live ticker (every tick)
   string testingOutput="";
// Print("Step1");
   testingOutput="Step1";

// STEP 1: Daily reset
   dxb_ResetDailyLimitsIfNewDay();

// Check if we have a valid signal on a new bar to log blocked conditions
   bool dxb_is_new_bar = (Time[0] != dxb_g_lastBarTime);
   int dxb_current_signal = 0;
   if(dxb_is_new_bar)
      dxb_current_signal = dxb_GetSARSignal();

// STEP 2: Daily limit gate
   if(dxb_Use_Daily_Limits && dxb_g_dailyLimitHit)
     {
      if(dxb_is_new_bar && dxb_current_signal != 0)
         Print("[dxb] New order blocked condition: DAILY LIMIT HIT");
      dxb_UpdateDisplay("DAILY LIMIT HIT — Waiting for new day");
      return;
     }
//Print("Step2");
   testingOutput+=" - Step1";


// STEP 3: Floating loss gate
   if(dxb_Use_Floating_Loss_Limit)
     {
      /*if(dxb_GetFloatingLoss() >= dxb_Floating_Loss_Limit_Per_Symbol)
      {
         if(dxb_is_new_bar && dxb_current_signal != 0) Print("[dxb] New order blocked condition: FLOAT LIMIT HIT");
         dxb_UpdateDisplay("FLOAT LIMIT HIT — Closing all trades");
         dxb_CloseAllTrades();
         return;
      }*/
      if(dxb_GetTotalOpenProfit() <= -dxb_Floating_Loss_Limit_Per_Symbol)
        {
         if(dxb_is_new_bar && dxb_current_signal != 0)
            Print("[dxb] dxb_GetTotalOpenProfit New order blocked condition: FLOAT LIMIT HIT $"+dxb_Floating_Loss_Limit_Per_Symbol);
         dxb_UpdateDisplay("FLOAT LIMIT HIT — Closing all trades $"+dxb_Floating_Loss_Limit_Per_Symbol);
         dxb_CloseAllTrades();
         return;
        }




     }
//Print("Step3");
   testingOutput+=" - Step3";

// STEP 3b: Basket Take Profit Gate
   if(dxb_CountOpenTrades() > 0)
     {


      dxb_Take_Profit_Amount=dxb_Take_Profit_Amount*lot_multiplier;

      if(dxb_GetTotalOpenProfit() >= dxb_Take_Profit_Amount)
        {
         if(dxb_is_new_bar && dxb_current_signal != 0)
            Print("[dxb] New order blocked condition: TAKE PROFIT HIT");
         dxb_UpdateDisplay("Open Trades - TAKE PROFIT HIT — Closing all active trades");
         dxb_CloseAllTrades("Target Profit Reached");
         return;
        }
      else
         if( dxb_GetTotalOpenProfit() >= dxb_Take_Profit_Amount/dxb_CountOpenTrades() )


           {

            dxb_UpdateDisplay("Open Trades - TAKE PROFIT HIT — Closing all active trades");
            dxb_CloseAllTrades("Target Profit Reached");
            return;

           }
     }
//Print("Step3b");
   testingOutput+=" - Step3b";

// STEP 4: Trade count gate
   if(dxb_Enable_Trade_Limits)
      if(dxb_g_winCount  >= dxb_Max_Winning_Trades ||
         dxb_g_lossCount >= dxb_Max_Losing_Trades)
        {
         if(dxb_is_new_bar && dxb_current_signal != 0)
            Print("[dxb] New order blocked condition: TRADE LIMIT HIT");
         dxb_UpdateDisplay("TRADE LIMIT HIT — Session complete");
         return;
        }
// Print("Step4");
   testingOutput+=" - Step4";
// STEP 5: Manual reset
   if(dxb_Set_TRUE_to_Reset_All_Limits)
     {
      dxb_g_winCount=0;
      dxb_g_lossCount=0;
      dxb_g_dailyProfit=0;
      dxb_g_dailyLoss=0;
      dxb_g_dailyLimitHit=false;
      Print("[dxb] Manual reset triggered.");
     }
//Print("Step5");
   testingOutput+=" - Step5";

// STEP 6: Spread filter (skipped in Strategy Tester)
   if(!dxb_g_isTesting)
     {
      int dxb_spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
      if(dxb_spread > dxb_MaximumSpread)
        {
         if(dxb_is_new_bar && dxb_current_signal != 0)
            Print("[dxb] New order blocked condition: HIGH SPREAD (", dxb_spread, " > ", dxb_MaximumSpread, ")");
         dxb_UpdateDisplay("HIGH SPREAD: " + IntegerToString(dxb_spread) + " pts — Waiting"+" "+dxb_MaximumSpread);
         return;
        }
     }
//Print("Step6");
   testingOutput+=" - Step6";
// STEP 7: New bar filter




   if(Time[0] == dxb_g_lastBarTime)
      return;
   else
     {
      //Print(Time[0]+" -"+dxb_g_lastBarTime);

     }
   dxb_g_lastBarTime = Time[0];

// STEP 7b: News fetch (live only, once per hour)
   if(dxb_NEWS_FILTER && !dxb_g_isTesting)
     {
      if(TimeCurrent() - dxb_LastNewsFetch >= DXB_FETCH_INTERVAL)
         dxb_FetchNews();
      if(dxb_DRAW_NEWS_LINES)
         dxb_DrawNewsLines();
     }
//Print("Step7b");
   testingOutput+=" - Step7b";


// STEP 7c: News gate (live only)
   if(dxb_NEWS_FILTER && !dxb_g_isTesting && dxb_IsNewsTime())
     {
      if(dxb_current_signal != 0)
         Print("[dxb] New order blocked condition: NEWS FILTER ACTIVE");
      dxb_UpdateDisplay("NEWS FILTER ACTIVE — Trading paused");
      dxb_DrawNewsBlockedLabel();
      return;
     }
   else
     {
      // dxb_UpdateDisplay("-----");

     }
//Print("Step7c");
   testingOutput+=" - Step7c";

// STEP 8: Manage open trades
   dxb_ManageOpenTrades();
//Print("Step8");
   testingOutput+=" - Step8";


// 1. Add a time filter in OnTick() before STEP 10:
   /*int dxb_currentHour = TimeHour(TimeCurrent());
   if(dxb_currentHour >= 16 && dxb_currentHour <= 22) // 16:00–22:00 = US session
   {
       dxb_UpdateDisplay("US SESSION — Trading paused : "+dxb_session_name);
       return;
   }*/
// STEP X: Maximum open orders gate
   if(dxb_CountOpenTrades() >= dxb_Max_Open_Orders)
     {
      dxb_UpdateDisplay(
         "MAX OPEN ORDERS LIMIT HIT (" +
         IntegerToString(dxb_Max_Open_Orders) + ")"
      );

      Print("[dxb] New order blocked condition: MAX OPEN ORDERS LIMIT HIT");

      dxb_RefreshVisuals();
      return;
     }

//NEW TRADE GATE ----------------XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

// STEP 9: Grid entry check
   if(dxb_CountOpenTrades() > 0)
     {



      if(dxb_current_signal != 0)
         Print("[dxb] New SAR order blocked condition: OPEN TRADES EXIST (Grid mode active)");
      dxb_CheckAdditionalEntry();
      // ── DRAW VISUALS every bar ──
      dxb_RefreshVisuals();
      return;
     }
//Print("Step9");
   testingOutput+=" - Step9";










// STEP 10: SAR signal
   int dxb_signal = dxb_GetSARSignal();
   if(dxb_signal == 0)
     {
      dxb_RefreshVisuals(); // Still draw even when no signal
      return;
     }
//Print("Step10");
   testingOutput+=" - Step10";

// STEP 11: Lot size
   double dxb_lot = dxb_GetCurrentLotSize();
//Print("Step11");
   testingOutput+=" - Step11";



//FINAL GATE TO TRADE XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX


   if(sessionName=="NY" && !sessionNY)
     {
      dxb_UpdateDisplay("NY SESSION — Trading paused : "+sessionName);
      return;
     }
   if(sessionName=="US" && !sessionUS)
     {
      dxb_UpdateDisplay("US SESSION — Trading paused : "+sessionName);
      return;
     }
   if(sessionName=="EU" && !sessionEU)
     {
      dxb_UpdateDisplay("EU SESSION — Trading paused : "+sessionName);
      return;
     }
   if(sessionName=="DEAD" && !sessionDEAD)
     {
      dxb_UpdateDisplay("DEAD SESSION — Trading paused : "+sessionName);
      return;
     }
   if(sessionName=="ASIA" && !sessionASIA)
     {
      dxb_UpdateDisplay("ASIA SESSION — Trading paused : "+sessionName);
      return;
     }


   // if(dxb_IsBigCandleLast5Min() && (sessionName=="ASIA" || sessionName=="EU" || sessionName=="DEAD"))
   //   {

   //    Print("[dxb] BIG candle found in last 3 min ");

   //    dxb_UpdateDisplay("BIG candle found in last 3 min");
   //    return ;
   //   }
   // else
   //   {
   //    // dxb_UpdateDisplay("----");

   //   }
//XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

// STEP 12: Open trade
   string dxb_reason = (dxb_signal == 1) ? "V1 FLIP Single Order" : "V1 FLIP Single Order";
   dxb_OpenTrade(dxb_signal, dxb_lot, dxb_reason);
//Print("Step12");
   testingOutput+=" - Step12";

// ── DRAW VISUALS after trade ──
   dxb_RefreshVisuals();

//Print("Step End----------------------------------------------");


  }

//+------------------------------------------------------------------+
//| dxb_ApplySessionSettings                                          |
//| Overrides global input variables based on current session time.  |
//| Call this at the TOP of OnTick() before any logic runs.          |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| dxb_ApplyAllSettings                                              |
//| LAYER 0: Weekend BTC scalping mode                                |
//| LAYER 1: Weekday time-session settings (UTC+3 server)             |
//| LAYER 2: BTC tick-spike override with hold timer                  |
//|                                                                   |
//| Call this as the VERY FIRST LINE of OnTick()                      |
//| Order matters: Layer 0/1 set baseline → Layer 2 overrides         |
//+------------------------------------------------------------------+
/*
void dxb_ApplySessionSettings_old()
{
   datetime dxb_now    = TimeCurrent();
   int      dxb_day    = TimeDayOfWeek(dxb_now); // 0=Sun 6=Sat
   int      dxb_hour   = TimeHour(dxb_now);
   int      dxb_minute = TimeMinute(dxb_now);
   bool     dxb_isWeekend = (dxb_day == 0 || dxb_day == 6);

   // ═══════════════════════════════════════════════════════════════
   // LAYER 0 — WEEKEND MODE
   // Saturday + Sunday: lower volatility, no major news
   // Moderate settings — not too tight, not too loose
   // ═══════════════════════════════════════════════════════════════
   if(dxb_isWeekend)
   {
      dxb_NEWS_FILTER                    = false;
      // dxb_Floating_Loss_Limit_Per_Symbol = 30.0;
      dxb_Min_Distance_Between_Trades    = 100;
      dxb_MaximumSpread                  = 800;
      dxb_AI_SAR_Period                  = 1.5;
      dxb_AI_SAR_STEP_SIZE               = 15;
      dxb_AI_SAR_SCALPER_ACCELERATION    = 6;
      // dxb_Take_Profit_Amount             = 2.0;
      dxb_session_name                   = "Weekend Scalping";
   }
   else
   {
      // ═══════════════════════════════════════════════════════════
      // LAYER 1 — WEEKDAY SESSION (UTC+3 Server Time)
      // Asia:     03:00–10:00  slow, trending, tight spread
      // EU:       10:00–16:00  medium volatility, news active
      // NY Spike: 16:30–18:00  most dangerous, override EU/US
      // US:       16:00–23:00  high volatility, news active
      // Dead:     23:00–03:00  very low volume, wide spreads
      // ═══════════════════════════════════════════════════════════

      // NOTE: dxb_isNYSpike checked FIRST — takes priority over dxb_isUS
      bool dxb_isNYSpike = (dxb_hour == 16 && dxb_minute >= 30)
                        || (dxb_hour == 17);
      bool dxb_isUS      = (dxb_hour >= 16 && dxb_hour < 23);
      bool dxb_isEU      = (dxb_hour >= 10 && dxb_hour < 16);
      bool dxb_isAsia    = (dxb_hour >= 3  && dxb_hour < 10);

      if(dxb_isNYSpike)
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 10.0;
         dxb_Min_Distance_Between_Trades    = 200;
         dxb_MaximumSpread                  = 300;
         dxb_AI_SAR_Period                  = 2.5;
         dxb_AI_SAR_STEP_SIZE               = 8;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 4;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = "NY Spike 16:30-18:00";
      }
      else if(dxb_isUS)
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 15.0;
         dxb_Min_Distance_Between_Trades    = 150;
         dxb_MaximumSpread                  = 500;
         dxb_AI_SAR_Period                  = 2.0;
         dxb_AI_SAR_STEP_SIZE               = 10;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 5;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = "US Session 16:00-23:00";
      }
      else if(dxb_isEU)
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 30.0;
         dxb_Min_Distance_Between_Trades    = 80;
         dxb_MaximumSpread                  = 1000;
         dxb_AI_SAR_Period                  = 1.0;
         dxb_AI_SAR_STEP_SIZE               = 18;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 7;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = "EU Session 10:00-16:00";
      }
      else if(dxb_isAsia)
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 50.0;
         dxb_Min_Distance_Between_Trades    = 50;
         dxb_MaximumSpread                  = 2000;
         dxb_AI_SAR_Period                  = 0.56;
         dxb_AI_SAR_STEP_SIZE               = 25;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 9;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = "Asia Session 03:00-10:00";
      }
      else
      {
         // Dead zone 23:00–03:00
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 50.0;
         dxb_Min_Distance_Between_Trades    = 50;
         dxb_MaximumSpread                  = 2000;
         dxb_AI_SAR_Period                  = 0.56;
         dxb_AI_SAR_STEP_SIZE               = 25;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 9;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = "Dead Zone 23:00-03:00";
      }
   }

   // Save base session name BEFORE Layer 2 can overwrite it
   string dxb_baseSession = dxb_session_name;

   // ═══════════════════════════════════════════════════════════════
   // LAYER 2 — BTC TICK SPIKE OVERRIDE
   // Runs every tick, weekday AND weekend
   // Detects sudden large price moves and holds tighter settings
   // for a defined number of seconds after the spike
   //
   // Hold times:
   //   EXTREME spike → hold 300 seconds (5 minutes)
   //   STRONG spike  → hold 180 seconds (3 minutes)
   //   WARNING spike → hold  60 seconds (1 minute)
   //
   // After hold expires → Layer 0/1 settings automatically restore
   // ═══════════════════════════════════════════════════════════════
   static double   dxb_lastBid        = 0;
   static datetime dxb_lastTickTime   = 0;
   static datetime dxb_spikeHoldUntil = 0;
   static string   dxb_lastSpikeMode  = "";

   double dxb_bid    = Bid;
   double dxb_spread = (Ask - Bid) / Point;

   // First tick ever — just record and skip spike check
   if(dxb_lastBid == 0)
   {
      dxb_lastBid      = dxb_bid;
      dxb_lastTickTime = dxb_now;
      return;
   }

   // Measure price move since last tick
   int    dxb_seconds    = (int)(dxb_now - dxb_lastTickTime);
   if(dxb_seconds <= 0) dxb_seconds = 1;
   double dxb_movePoints = MathAbs(dxb_bid - dxb_lastBid) / Point;

   // Update trackers for next tick
   dxb_lastBid      = dxb_bid;
   dxb_lastTickTime = dxb_now;

   // ── Classify spike and set hold timer ───────────────────────────
   if(dxb_movePoints >= 1500 && dxb_seconds <= 2)
   {
      dxb_spikeHoldUntil = dxb_now + 300; // hold 5 min
      dxb_lastSpikeMode  = "EXTREME";
      Print("[dxb] EXTREME SPIKE | Move=", DoubleToStr(dxb_movePoints,0),
            " pts | Secs=", dxb_seconds,
            " | Spread=", DoubleToStr(dxb_spread,0),
            " | Hold 5min | Base=", dxb_baseSession);
   }
   else if(dxb_movePoints >= 800 && dxb_seconds <= 2)
   {
      dxb_spikeHoldUntil = dxb_now + 180; // hold 3 min
      dxb_lastSpikeMode  = "STRONG";
      Print("[dxb] STRONG SPIKE | Move=", DoubleToStr(dxb_movePoints,0),
            " pts | Secs=", dxb_seconds,
            " | Spread=", DoubleToStr(dxb_spread,0),
            " | Hold 3min | Base=", dxb_baseSession);
   }
   else if(dxb_movePoints >= 400 && dxb_seconds <= 3)
   {
      dxb_spikeHoldUntil = dxb_now + 60;  // hold 1 min
      dxb_lastSpikeMode  = "WARNING";
   }

   // ── Apply spike settings if still within hold window ────────────
   if(dxb_now <= dxb_spikeHoldUntil && dxb_lastSpikeMode != "")
   {
      int dxb_secsLeft = (int)(dxb_spikeHoldUntil - dxb_now);

      if(dxb_lastSpikeMode == "EXTREME")
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 5.0;
         dxb_Min_Distance_Between_Trades    = 500;
         dxb_MaximumSpread                  = 200;
         dxb_AI_SAR_Period                  = 3.0;
         dxb_AI_SAR_STEP_SIZE               = 6;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 3;
         // dxb_Take_Profit_Amount             = 10.0;
         dxb_session_name                   = StringFormat(
            "EXTREME SPIKE HOLD %ds | Base:%s",
            dxb_secsLeft, dxb_baseSession);
      }
      else if(dxb_lastSpikeMode == "STRONG")
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 10.0;
         dxb_Min_Distance_Between_Trades    = 300;
         dxb_MaximumSpread                  = 300;
         dxb_AI_SAR_Period                  = 2.5;
         dxb_AI_SAR_STEP_SIZE               = 8;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 4;
         // dxb_Take_Profit_Amount             = 5.0;
         dxb_session_name                   = StringFormat(
            "STRONG SPIKE HOLD %ds | Base:%s",
            dxb_secsLeft, dxb_baseSession);
      }
      else if(dxb_lastSpikeMode == "WARNING")
      {
         dxb_NEWS_FILTER                    = true;
         // dxb_Floating_Loss_Limit_Per_Symbol = 20.0;
         dxb_Min_Distance_Between_Trades    = 150;
         dxb_MaximumSpread                  = 500;
         dxb_AI_SAR_Period                  = 2.0;
         dxb_AI_SAR_STEP_SIZE               = 10;
         dxb_AI_SAR_SCALPER_ACCELERATION    = 5;
         // dxb_Take_Profit_Amount             = 2.0;
         dxb_session_name                   = StringFormat(
            "WARNING SPIKE HOLD %ds | Base:%s",
            dxb_secsLeft, dxb_baseSession);
      }
   }
   else if(dxb_now > dxb_spikeHoldUntil && dxb_lastSpikeMode != "")
   {
      // ── Hold expired — clear spike mode, Layer 0/1 restores ─────
      Print("[dxb] Spike hold EXPIRED | Was:", dxb_lastSpikeMode,
            " | Restored to: ", dxb_baseSession);
      dxb_lastSpikeMode = ""; // clear — Layer 0/1 now active again
   }
}
   */
bool sessionNY=false;
bool sessionUS=false;
bool sessionEU=true;
bool sessionASIA=true;
bool sessionDEAD=false;



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_ApplySessionSettings()
  {
   /*
   int  dxb_hour    = TimeHour(TimeCurrent());
   int  dxb_minute  = TimeMinute(TimeCurrent());

   // ── SESSION DETECTION ─────────────────────────────────────────
   bool dxb_isNYSpike = (dxb_hour == 13 && dxb_minute >= 30) || (dxb_hour == 14);
   bool dxb_isUS      = (dxb_hour >= 13 && dxb_hour <= 20);
   bool dxb_isEU      = (dxb_hour >= 7  && dxb_hour < 13);
   bool dxb_isAsia    = (dxb_hour >= 0  && dxb_hour < 7);
   */
   int dxb_hour   = TimeHour(TimeCurrent());
   int dxb_minute = TimeMinute(TimeCurrent());

// ── SESSION DETECTION (UTC+3 Server Time) ─────────────────────
// Your server = GMT+3
// Asia:     03:00–10:00 server
// EU:       10:00–16:00 server
// NY Spike: 16:30–18:00 server (most dangerous)
// US:       16:00–23:00 server
// Dead:     23:00–03:00 server

   bool dxb_isNYSpike = (dxb_hour == 16 && dxb_minute >= 30)
                        || (dxb_hour == 17);

   bool dxb_isUS      = (dxb_hour >= 20 && dxb_hour <= 22);

   bool dxb_isEU      = (dxb_hour >= 12 && dxb_hour < 20);

   bool dxb_isAsia    = (dxb_hour >= 2  && dxb_hour < 12);

// Dead zone: 23:00–03:00 server (handled by else below)
   if(dxb_isNYSpike)
     {
      // ── NY OPEN SPIKE ZONE 11:30–15:00 GMT (most dangerous) ───
      dxb_NEWS_FILTER                      = false;
      dxb_Floating_Loss_Limit_Per_Symbol   = 10.0;
      dxb_Min_Distance_Between_Trades      = 150;
      dxb_MaximumSpread                    = 2000;
      dxb_AI_SAR_Period                    = 2.5;
      dxb_AI_SAR_STEP_SIZE                 = 8;
      dxb_AI_SAR_SCALPER_ACCELERATION      = 4;
      dxb_Take_Profit_Amount               = 1;

      dxb_session_name="NY Session 16:30  to 18";
      sessionName="NY";
     }
   else
      if(dxb_isUS)
        {
         // ── NORMAL US SESSION 15:00–20:00 GMT ─────────────────────
         dxb_NEWS_FILTER                      = false;
         dxb_Floating_Loss_Limit_Per_Symbol   = 10.0;
         dxb_Min_Distance_Between_Trades      = 150;
         dxb_MaximumSpread                    = 2000;
         dxb_AI_SAR_Period                    = 2.0;
         dxb_AI_SAR_STEP_SIZE                 = 10;
         dxb_AI_SAR_SCALPER_ACCELERATION      = 5;
         dxb_Take_Profit_Amount               = 1.0;

         dxb_session_name="US Session 16 to 23";
         sessionName="US";

        }
      else
         if(dxb_isEU)
           {
            // ── EU SESSION 07:00–11:00 GMT ────────────────────────────
            dxb_NEWS_FILTER                      = false;
            dxb_Floating_Loss_Limit_Per_Symbol   = 10.0;
            dxb_Min_Distance_Between_Trades      = 150;
            dxb_MaximumSpread                    = 2000;
            dxb_AI_SAR_Period                    = 1.0;
            dxb_AI_SAR_STEP_SIZE                 = 18;
            dxb_AI_SAR_SCALPER_ACCELERATION      = 7;
            dxb_Take_Profit_Amount               = 1;

            dxb_session_name="EU Session 10 to 16";
            sessionName="EU";

           }
         else
            if(dxb_isAsia)
              {
               // ── ASIA SESSION 00:00–07:00 GMT ──────────────────────────
               dxb_NEWS_FILTER                      = false;
               dxb_Floating_Loss_Limit_Per_Symbol   = 10.0;
               dxb_Min_Distance_Between_Trades      = 150;
               dxb_MaximumSpread                    = 2000;
               dxb_AI_SAR_Period                    = 0.56;
               dxb_AI_SAR_STEP_SIZE                 = 25;
               dxb_AI_SAR_SCALPER_ACCELERATION      = 9;
               dxb_Take_Profit_Amount               = 1.0;

               dxb_session_name="Asia Session 3 to 10";
               sessionName="ASIA";

              }
            else
              {
               // ── FALLBACK (20:00–00:00 GMT dead zone) ──────────────────
               dxb_NEWS_FILTER                      = false;
               dxb_Floating_Loss_Limit_Per_Symbol   = 10.0;
               dxb_Min_Distance_Between_Trades      = 150;
               dxb_MaximumSpread                    = 2000;
               dxb_AI_SAR_Period                    = 0.56;
               dxb_AI_SAR_STEP_SIZE                 = 25;
               dxb_AI_SAR_SCALPER_ACCELERATION      = 9;
               dxb_Take_Profit_Amount               = 1.0;

               dxb_session_name="Dead Session 23 to 3";
               sessionName="DEAD";

              }

//Print(dxb_session_name);

// return sessionName;
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

// Read SAR values for the two most recently CLOSED bars
   double dxb_sar1 = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, 1); // bar 1 = just closed
   double dxb_sar2 = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, 2); // bar 2 = previous closed

// BUY: SAR just flipped from above to below price on the completed bar
   if(dxb_sar1 < Close[1] && dxb_sar2 >= Close[2])
      return(1);

// SELL: SAR just flipped from below to above price on the completed bar
   if(dxb_sar1 > Close[1] && dxb_sar2 <= Close[2])
      return(-1);

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
      if(dxb_lot > dxb_Maximum_Lot_Size)
         dxb_lot = dxb_Maximum_Lot_Size;
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
void dxb_OpenTrade(int dxb_direction, double dxb_lot, string dxb_reason="Unknown")
  {
//  if(AccountNumber() == 289052334 ) return;

   dxb_lot=dxb_lot*lot_multiplier;

   double dxb_point  = MarketInfo(Symbol(), MODE_POINT);
   int    dxb_ticket = -1;

   if(dxb_direction == 1) // BUY order
     {
      double dxb_price = NormalizeDouble(Ask, Digits);
      int    dxb_slip = (dxb_g_isTesting) ? 1000 : 30;
      dxb_ticket = OrderSend(Symbol(), OP_BUY, dxb_lot, dxb_price,
                             dxb_slip,   // slippage
                             0,          // stop loss (removed)
                             0,          // take profit (managed by EA)
                             "V1 Flip Single Order",
                             dxb_MagicNumber, 0, clrBlue);
     }
   else
      if(dxb_direction == -1) // SELL order
        {
         double dxb_price = NormalizeDouble(Bid, Digits);
         int    dxb_slip = (dxb_g_isTesting) ? 1000 : 30;
         dxb_ticket = OrderSend(Symbol(), OP_SELL, dxb_lot, dxb_price,
                                dxb_slip,   // slippage
                                0,          // stop loss (removed)
                                0,          // take profit (managed by EA)
                                "V1 Flip Single Order",
                                dxb_MagicNumber, 0, clrRed);
        }

   if(dxb_ticket > 0)
     {
      dxb_g_tradeCount++;              // Increment session trade counter
      dxb_g_openTicket = dxb_ticket;   // Remember last ticket
      Print("[dxb] Trade opened [", dxb_reason, "]: Ticket=", dxb_ticket,
            " Dir=", dxb_direction, " Lot=", dxb_lot,
            " TradeNo=", dxb_g_tradeCount);
     }
   else
     {
      // Error 4 = off quotes, 130 = invalid stops, 135 = price changed
      Print("[dxb] OrderSend failed [", dxb_reason, "]: Error=", GetLastError(),
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
   double dxb_lastOpenPrice = 0;
   int    dxb_lastType = -1;
   datetime dxb_lastTime = 0;

// 1. Find the most recently opened trade
   for(int dxb_i = 0; dxb_i < OrdersTotal(); dxb_i++)
     {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber)
         continue;

      if(OrderOpenTime() >= dxb_lastTime)
        {
         dxb_lastTime = OrderOpenTime();
         dxb_lastOpenPrice = OrderOpenPrice();
         dxb_lastType = OrderType();
        }
     }

   if(dxb_lastType == -1)
      return; // No open trades


   if(!dxb_IsDistanceValid(dxb_lastType, 30*dxb_g_tradeCount))
      return;

   double dxb_distPoints = 0;

// 2. Calculate distance from the LAST trade only
   if(dxb_lastType == OP_BUY)
      dxb_distPoints = (Ask - dxb_lastOpenPrice) / dxb_point;
   else
      if(dxb_lastType == OP_SELL)
         dxb_distPoints = (dxb_lastOpenPrice - Bid) / dxb_point;

// 3. If price moved AGAINST the last trade by the minimum distance
   if(dxb_distPoints <= -(double)dxb_Min_Distance_Between_Trades)
     {
      int    dxb_sig = (dxb_lastType == OP_BUY) ? 1 : -1; // Same direction
      double dxb_lot = dxb_GetCurrentLotSize();           // Next lot in sequence
      dxb_OpenTrade(dxb_sig, dxb_lot, "V1 Flip  Extra ");
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
   if(!dxb_MASTER_Enable_Profit_Protection)
      return;

// Activation threshold: don't protect until profit is meaningful
   if(dxb_totalProfit < dxb_Activate_After_Profit)
      return;

// ── MODE 4: Step Lock (Recommended) ──
// Ratchets up a "floor" as profit grows through steps
// If profit drops back to floor → close everything
   if(dxb_Enable_Mode4)
     {
      double dxb_lockLevel = 0;
      // Find which step we've reached based on highest profit
      if(dxb_g_highestProfit >= dxb_Step4_Profit)
         dxb_lockLevel = dxb_Step4_Lock;
      else
         if(dxb_g_highestProfit >= dxb_Step3_Profit)
            dxb_lockLevel = dxb_Step3_Lock;
         else
            if(dxb_g_highestProfit >= dxb_Step2_Profit)
               dxb_lockLevel = dxb_Step2_Lock;
            else
               if(dxb_g_highestProfit >= dxb_Step1_Profit)
                  dxb_lockLevel = dxb_Step1_Lock;

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
// if(dxb_Enable_Mode2)
//    dxb_TrailAllTrades(dxb_Mode2_Trail_Distance);

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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber)
         continue;

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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
        {
         double dxb_newSL = Bid - dxb_trail;
         // Only modify if new SL is better (higher) than current SL
         if(dxb_newSL > OrderStopLoss())
            OrderModify(OrderTicket(), OrderOpenPrice(), dxb_newSL,
                        OrderTakeProfit(), 0, clrNONE);
        }
      else
         if(OrderType() == OP_SELL)
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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber)
         continue;
      if(OrderProfit() <= 0)
         continue; // Only partially close profitable trades

      double dxb_closeLot = dxb_NormalizeLot(OrderLots() * dxb_closePct);
      if(OrderType() == OP_BUY)
         OrderClose(OrderTicket(), dxb_closeLot, Bid, 3, clrYellow);
      else
         if(OrderType() == OP_SELL)
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
void dxb_CloseAllTrades(string dxb_reason="Unknown")
  {

   Print("[dxb] Executing CloseAllTrades. Reason: ", dxb_reason);

   for(int dxb_i = OrdersTotal() - 1; dxb_i >= 0; dxb_i--)
     {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != dxb_MagicNumber)
         continue;

      int dxb_ticket = OrderTicket();
      double dxb_closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
      bool   dxb_closed     = OrderClose(dxb_ticket, OrderLots(),
                                         dxb_closePrice, 3, clrWhite);

      if(dxb_closed)
        {
         Print("[dxb] Trade closed [", dxb_reason, "]: Ticket=", dxb_ticket);

         // Track outcome for session statistics
         if(OrderProfit() > 0)
            dxb_g_winCount++;
         else
            dxb_g_lossCount++;

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
   dxb_g_tradeCount=0;

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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
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
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == dxb_MagicNumber)
        {
         double dxb_p = OrderProfit() + OrderSwap() + OrderCommission();
         if(dxb_p < 0)
            dxb_loss += MathAbs(dxb_p); // Sum only losing positions
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
   if(!dxb_Show_Supply_Demand_Zones)
      return;

// Find the price extremes over the lookback window
   double dxb_highestHigh = High[iHighest(Symbol(), 0, MODE_HIGH,
                                                             dxb_LOOKBACK_SCAN_CANDLE_AMOUNT, 1)];
   double dxb_lowestLow   = Low[iLowest(Symbol(), 0, MODE_LOW,
                                                          dxb_LOOKBACK_SCAN_CANDLE_AMOUNT, 1)];
   dxb_g_cachedHH = dxb_highestHigh;
   dxb_g_cachedLL = dxb_lowestLow;
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
//| dxb_DrawSARDots                                                    |
//| Draws visual representation of the Parabolic SAR on the chart.     |
//+------------------------------------------------------------------+
void dxb_DrawSARDots()
  {
   if(!dxb_Show_SAR_Dots)
      return;

   double dxb_step    = dxb_AI_SAR_Period * dxb_AI_SAR_STEP_SIZE / 10000.0;
   double dxb_maxstep = dxb_step * dxb_AI_SAR_SCALPER_ACCELERATION;

   for(int dxb_i = 0; dxb_i < dxb_LOOKBACK_SCAN_CANDLE_AMOUNT; dxb_i++)
     {
      double dxb_sar = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, dxb_i);
      string dxb_name = "DXB_MMFLIP_SAR_" + IntegerToString(dxb_i);

      if(ObjectFind(0, dxb_name) < 0)
        {
         ObjectCreate(0, dxb_name, OBJ_ARROW, 0, Time[dxb_i], dxb_sar);
         ObjectSetInteger(0, dxb_name, OBJPROP_ARROWCODE, 159); // Small dot
         ObjectSetInteger(0, dxb_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, dxb_name, OBJPROP_BACK, true);     // Keep behind price text
        }
      else
        {
         ObjectSetInteger(0, dxb_name, OBJPROP_TIME, Time[dxb_i]);
         ObjectSetDouble(0, dxb_name, OBJPROP_PRICE, dxb_sar);
        }

      // Color based on position relative to price (Bullish = Lime, Bearish = Red)
      if(dxb_sar < Close[dxb_i])
         ObjectSetInteger(0, dxb_name, OBJPROP_COLOR, clrLime);
      else
         ObjectSetInteger(0, dxb_name, OBJPROP_COLOR, clrOrangeRed);
     }
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

// Helper: draw a solid background box behind UI panels
void dxb_DrawBG(string dxb_name, int dxb_x, int dxb_y, int dxb_w, int dxb_h, ENUM_BASE_CORNER dxb_cor)
  {
   if(ObjectFind(0, dxb_name) < 0)
      ObjectCreate(0, dxb_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dxb_name, OBJPROP_CORNER, dxb_cor);
   ObjectSetInteger(0, dxb_name, OBJPROP_XDISTANCE, (dxb_x - 5 < 0) ? 0 : dxb_x - 5);
   ObjectSetInteger(0, dxb_name, OBJPROP_YDISTANCE, (dxb_y - 5 < 0) ? 0 : dxb_y - 5);
   ObjectSetInteger(0, dxb_name, OBJPROP_XSIZE, dxb_w);
   ObjectSetInteger(0, dxb_name, OBJPROP_YSIZE, dxb_h);
   ObjectSetInteger(0, dxb_name, OBJPROP_BGCOLOR, clrBlack);
   ObjectSetInteger(0, dxb_name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, dxb_name, OBJPROP_BACK, false);
   ObjectSetInteger(0, dxb_name, OBJPROP_ZORDER, 0); // Background behind labels
  }

// Helper: draw one label line at (x, y + line*lineH)
void dxb_Lbl(string dxb_pre, int dxb_n, string dxb_txt,
             int dxb_x, int dxb_y, int dxb_lh,
             ENUM_BASE_CORNER dxb_cor, color dxb_clr, int dxb_fs, string dxb_fnt)
  {
   string dxb_o = dxb_pre + IntegerToString(dxb_n);
   if(ObjectFind(0, dxb_o) < 0)
      ObjectCreate(0, dxb_o, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, dxb_o, OBJPROP_CORNER,    dxb_cor);

   if(dxb_cor == CORNER_RIGHT_UPPER)
      ObjectSetInteger(0, dxb_o, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   else
      if(dxb_cor == CORNER_RIGHT_LOWER)
         ObjectSetInteger(0, dxb_o, OBJPROP_ANCHOR, ANCHOR_RIGHT_LOWER);
      else
         if(dxb_cor == CORNER_LEFT_LOWER)
            ObjectSetInteger(0, dxb_o, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
         else
            ObjectSetInteger(0, dxb_o, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);

   ObjectSetInteger(0, dxb_o, OBJPROP_XDISTANCE, dxb_x);
   ObjectSetInteger(0, dxb_o, OBJPROP_YDISTANCE, dxb_y + dxb_n * dxb_lh);
   ObjectSetString(0,  dxb_o, OBJPROP_TEXT,      dxb_txt);
   ObjectSetString(0,  dxb_o, OBJPROP_FONT,      dxb_fnt);
   ObjectSetInteger(0, dxb_o, OBJPROP_FONTSIZE,  dxb_fs);
   ObjectSetInteger(0, dxb_o, OBJPROP_COLOR,     dxb_clr);
   ObjectSetInteger(0, dxb_o, OBJPROP_ZORDER,    1); // Text in front of backgrounds
  }

// ── LEFT PANEL ──────────────────────────────────────────────────────────────
void dxb_DrawInfoPanel()
  {




   if(!dxb_Show_Strategy_Visuals)
      return;
   double dxb_lot = dxb_GetCurrentLotSize();
   double dxb_flt = dxb_GetTotalOpenProfit();
   double dxb_net = dxb_g_dailyProfit - dxb_g_dailyLoss + dxb_flt;
   string dxb_tf  = StringSubstr(dxb_Enter_Your_License_Key, 0,
                                 StringFind(dxb_Enter_Your_License_Key, "-"));
   if(dxb_tf == "")
      dxb_tf = "M1";
   string dxb_p = "DXB_MMFLIP_Panel_L";
   int    dxb_x = dxb_Chart_X_Axis_Position;
   int    dxb_y = dxb_Chart_Y_Axis_Position;
   int    dxb_h = 14;

   dxb_DrawBG("DXB_MMFLIP_Panel_BG", dxb_x, dxb_y, 250, 13 * dxb_h + 10+50, CORNER_LEFT_UPPER);

   string dxb_f = dxb_News_Font;
   color  dxb_c = dxb_Font_Color;
   dxb_Lbl(dxb_p, 0,  Symbol(),                                                    dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrWhite,  9, dxb_f);
   dxb_Lbl(dxb_p, 1,  "Status: "+dxb_g_statusText,                                 dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrLime,   9, dxb_f);
   dxb_Lbl(dxb_p, 2,  StringFormat("Lot: %.2f | TP: $%.2f",dxb_lot,dxb_Take_Profit_Amount), dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c, 9, dxb_f);
   dxb_Lbl(dxb_p, 3,  StringFormat("Profit: $%.2f",dxb_g_dailyProfit),             dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrLime,   9, dxb_f);



   dxb_Lbl(dxb_p, 4,  StringFormat("Loss: $%.2f",dxb_g_dailyLoss),                 dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrRed,    9, dxb_f);
   dxb_Lbl(dxb_p, 5,  StringFormat("Floating: $%.2f",dxb_flt),                     dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c,     9, dxb_f);
   dxb_Lbl(dxb_p, 6,  StringFormat("Net P/L: $%.2f",dxb_net),                      dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, (dxb_net>=0)?clrLime:clrRed, 9, dxb_f);
   dxb_Lbl(dxb_p, 7,  StringFormat("Trades: %d | Open: %d",dxb_g_tradeCount,dxb_CountOpenTrades()), dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c, 9, dxb_f);
   dxb_Lbl(dxb_p, 8,  StringFormat("Win: %d | Loss: %d",dxb_g_winCount,dxb_g_lossCount),  dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c, 9, dxb_f);
   dxb_Lbl(dxb_p, 9,  StringFormat("Next Trade: #%d @ %.2f lot",dxb_g_tradeCount+1,dxb_lot), dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrYellow, 9, dxb_f);
   dxb_Lbl(dxb_p, 10, "Protect "+(dxb_MASTER_Enable_Profit_Protection?"ON":"OFF"), dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c,     9, dxb_f);
   dxb_Lbl(dxb_p, 11, StringFormat("STOP LOSS: $%.0f",dxb_Floating_Loss_Limit_Per_Symbol), dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, dxb_c, 9, dxb_f);
   dxb_Lbl(dxb_p, 12, " "+dxb_tf,                                   dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrAqua,   9, dxb_f);

   dxb_Lbl(dxb_p, 14, ("LOT Multiplier: "+lot_multiplier+" X "+g_LotSize),             dxb_x,dxb_y,dxb_h, CORNER_LEFT_UPPER, clrLime,   9, dxb_f);




   double dxb_currEq   = AccountEquity();
   double dxb_eqDrop   = dxb_g_startEquity - dxb_currEq;
   double dxb_eqDropPc = (dxb_eqDrop / dxb_g_startEquity) * 100.0;

   dxb_Lbl(dxb_p, 13,
           StringFormat("Equity: $%.2f | Drop: $%.2f (%.1f%%)",
                        dxb_currEq, dxb_eqDrop, dxb_eqDropPc),
           dxb_x, dxb_y, dxb_h, CORNER_LEFT_UPPER,
           (dxb_eqDropPc >= dxb_Max_Equity_Loss_Percent) ? clrRed : clrLime,
           9, dxb_f);


  }

// ── BOTTOM-LEFT STRATEGY BOX ─────────────────────────────────────────────────
void dxb_DrawStrategyPanel()
  {
   if(!dxb_Show_Strategy_Visuals)
      return;
   double dxb_step    = dxb_AI_SAR_Period * dxb_AI_SAR_STEP_SIZE / 10000.0;
   double dxb_maxstep = dxb_step * dxb_AI_SAR_SCALPER_ACCELERATION;
   double dxb_sarCur  = iSAR(Symbol(), 0, dxb_step, dxb_maxstep, 0);
   string dxb_sarTxt  = (dxb_sarCur < Close[0]) ? "SAR BULLISH" : "SAR BEARISH";
   color  dxb_sarClr  = (dxb_sarCur < Close[0]) ? clrLime : clrOrangeRed;
   double dxb_mom     = (dxb_g_cachedHH > 0) ? (Close[0] - dxb_g_cachedLL) / Point : 0;
   string dxb_tfStr;
   switch(Period())
     {
      case PERIOD_M1:
         dxb_tfStr="M1";
         break;
      case PERIOD_M5:
         dxb_tfStr="M5";
         break;
      case PERIOD_M15:
         dxb_tfStr="M15";
         break;
      case PERIOD_M30:
         dxb_tfStr="M30";
         break;
      case PERIOD_H1:
         dxb_tfStr="H1";
         break;
      case PERIOD_H4:
         dxb_tfStr="H4";
         break;
      default:
         dxb_tfStr="D1";
         break;
     }
   string dxb_p = "DXB_MMFLIP_Strat_L";
   int    dxb_x = 10;
   int    dxb_y = 400;
   int    dxb_h = 14;

//dxb_DrawBG("DXB_MMFLIP_Strat_BG", dxb_x, dxb_y, 180, 7 * dxb_h + 10, CORNER_LEFT_LOWER);

   string dxb_f = dxb_News_Font;
   dxb_Lbl(dxb_p, 0, "V1 FX STRATEGY",                          dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrOrangeRed, 9, dxb_f);
   dxb_Lbl(dxb_p, 1, Symbol()+" - "+dxb_tfStr,                      dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrWhite,     9, dxb_f);
   dxb_Lbl(dxb_p, 2, StringFormat("HH %.2f",dxb_g_cachedHH),        dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrMagenta,   9, dxb_f);
   dxb_Lbl(dxb_p, 3, StringFormat("LL %.2f",dxb_g_cachedLL),        dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrLime,      9, dxb_f);
   dxb_Lbl(dxb_p, 4, StringFormat("MOM %+.0f pts",dxb_mom),         dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrWhite,     9, dxb_f);
   dxb_Lbl(dxb_p, 5, dxb_sarTxt,                                     dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, dxb_sarClr,   9, dxb_f);
   dxb_Lbl(dxb_p, 6, "SCANNING...",                                   dxb_x,dxb_y,dxb_h, CORNER_LEFT_LOWER, clrCyan,      9, dxb_f);
  }

// ── TOP-RIGHT TIME ANALYTICS ──────────────────────────────────────────────────
void dxb_DrawTimeAnalytics()
  {
   if(!dxb_Show_Time_Analytics_Panel)
      return;
   int    dxb_cnt[24];
   ArrayInitialize(dxb_cnt, 0);
   int    dxb_win[24];
   ArrayInitialize(dxb_win, 0);
   double dxb_pnl[24];
   ArrayInitialize(dxb_pnl, 0.0);
   datetime dxb_cutoff = TimeCurrent() - (datetime)(dxb_Analyze_Last_X_Days * 86400);
   for(int dxb_i = OrdersHistoryTotal()-1; dxb_i >= 0; dxb_i--)
     {
      if(!OrderSelect(dxb_i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol()      != Symbol())
         continue;
      if(OrderMagicNumber() != dxb_MagicNumber)
         continue;
      if(OrderCloseTime()    < dxb_cutoff)
         continue;
      if(OrderType()         > OP_SELL)
         continue;
      int dxb_h2 = TimeHour(OrderOpenTime());
      dxb_cnt[dxb_h2]++;
      if(OrderProfit()>0)
         dxb_win[dxb_h2]++;
      dxb_pnl[dxb_h2]+=OrderProfit();
     }
   int dxb_hrs[24];
   int dxb_nh=0;
   for(int dxb_h2=0; dxb_h2<24; dxb_h2++)
      if(dxb_cnt[dxb_h2]>0)
        {
         dxb_hrs[dxb_nh]=dxb_h2;
         dxb_nh++;
        }

   int dxb_show=(dxb_nh<5)?dxb_nh:5;
   int dxb_best=(dxb_nh<3)?dxb_nh:3;
   int dxb_av=(dxb_nh<2)?dxb_nh:2;
   int total_rows = 3 + dxb_show + 1 + dxb_best + 1 + dxb_av + 1;

   for(int dxb_a=0; dxb_a<dxb_nh-1; dxb_a++)
      for(int dxb_b=dxb_a+1; dxb_b<dxb_nh; dxb_b++)
         if(dxb_cnt[dxb_hrs[dxb_b]]>dxb_cnt[dxb_hrs[dxb_a]])
           {
            int t=dxb_hrs[dxb_a];
            dxb_hrs[dxb_a]=dxb_hrs[dxb_b];
            dxb_hrs[dxb_b]=t;
           }

   string dxb_p = "DXB_MMFLIP_Ana_L";
   int dxb_x=10,dxb_y=5,dxb_h=13;
   int dxb_row=0;

   dxb_DrawBG("DXB_MMFLIP_Ana_BG", dxb_x, dxb_y, 250, total_rows * dxb_h + 10, CORNER_RIGHT_UPPER);

   dxb_Lbl(dxb_p,dxb_row++,"TRADE TIME ANALYTICS",         dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrWhite,  9,dxb_News_Font);
   dxb_Lbl(dxb_p,dxb_row++,StringFormat("Last %d Days",dxb_Analyze_Last_X_Days), dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrSilver,9,dxb_News_Font);
   dxb_Lbl(dxb_p,dxb_row++,"Hour  Trades  Win%  Profit",   dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrYellow, 9,dxb_News_Font);
   int dxb_totT=0,dxb_totW=0;
   double dxb_totP=0;
   for(int dxb_i=0; dxb_i<dxb_show; dxb_i++)
     {
      int dxb_hh=dxb_hrs[dxb_i];
      int dxb_wp=(dxb_cnt[dxb_hh]>0)?(int)MathRound(dxb_win[dxb_hh]*100.0/dxb_cnt[dxb_hh]):0;
      color dxb_rc=(dxb_wp>=60)?clrLime:clrOrangeRed;
      dxb_Lbl(dxb_p,dxb_row++,StringFormat("%02d:00   %d   %d%%   %+.0f",dxb_hh,dxb_cnt[dxb_hh],dxb_wp,dxb_pnl[dxb_hh]),
              dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,dxb_rc,9,dxb_News_Font);
      dxb_totT+=dxb_cnt[dxb_hh];
      dxb_totW+=dxb_win[dxb_hh];
      dxb_totP+=dxb_pnl[dxb_hh];
     }
   int dxb_byW[24];
   for(int ii=0; ii<dxb_nh; ii++)
      dxb_byW[ii]=dxb_hrs[ii];
   for(int dxb_a=0; dxb_a<dxb_nh-1; dxb_a++)
      for(int dxb_b=dxb_a+1; dxb_b<dxb_nh; dxb_b++)
        {
         int ha=dxb_byW[dxb_a],hb=dxb_byW[dxb_b];
         int wa=(dxb_cnt[ha]>0)?(int)MathRound(dxb_win[ha]*100.0/dxb_cnt[ha]):0;
         int wb=(dxb_cnt[hb]>0)?(int)MathRound(dxb_win[hb]*100.0/dxb_cnt[hb]):0;
         if(wb>wa)
           {
            int t=dxb_byW[dxb_a];
            dxb_byW[dxb_a]=dxb_byW[dxb_b];
            dxb_byW[dxb_b]=t;
           }
        }
   dxb_Lbl(dxb_p,dxb_row++,"BEST HOURS --", dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrLime,  9,dxb_News_Font);
   dxb_best=(dxb_nh<3)?dxb_nh:3;
   for(int dxb_i=0; dxb_i<dxb_best; dxb_i++)
     {
      int dxb_hh=dxb_byW[dxb_i];
      int dxb_wp=(dxb_cnt[dxb_hh]>0)?(int)MathRound(dxb_win[dxb_hh]*100.0/dxb_cnt[dxb_hh]):0;
      dxb_Lbl(dxb_p,dxb_row++,StringFormat("#%d %02d:00 = %d%%",dxb_i+1,dxb_hh,dxb_wp),
              dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrLime,9,dxb_News_Font);
     }
   dxb_Lbl(dxb_p,dxb_row++,"AVOID HOURS",  dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrOrangeRed,9,dxb_News_Font);
   dxb_av=(dxb_nh<2)?dxb_nh:2;
   for(int dxb_i=dxb_nh-dxb_av; dxb_i<dxb_nh; dxb_i++)
     {
      int dxb_hh=dxb_byW[dxb_i];
      int dxb_wp=(dxb_cnt[dxb_hh]>0)?(int)MathRound(dxb_win[dxb_hh]*100.0/dxb_cnt[dxb_hh]):0;
      dxb_Lbl(dxb_p,dxb_row++,StringFormat("X %02d:00 = %d%%",dxb_hh,dxb_wp),
              dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrOrangeRed,9,dxb_News_Font);
     }
   int dxb_twp=(dxb_totT>0)?(int)MathRound(dxb_totW*100.0/dxb_totT):0;
   dxb_Lbl(dxb_p,dxb_row++,StringFormat("TOTAL: %d | %d%% | %+.0f",dxb_totT,dxb_twp,dxb_totP),
           dxb_x,dxb_y,dxb_h,CORNER_RIGHT_UPPER,clrWhite,9,dxb_News_Font);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long& lparam,
                  const double& dparam, const string& sparam)
  {
   if(dxb_Show_Strategy_Visuals)
     {
      dxb_DrawZones();      // Refresh supply/demand zone rectangles
      dxb_DrawSARDots();    // Refresh SAR dots
      dxb_DrawInfoPanel();  // Refresh statistics panel text
     }
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| NEWS FILTER FUNCTIONS (live mode only)                             |
//+------------------------------------------------------------------+
void dxb_DrawLiveStatus()
  {
   double dxb_bid  = Bid;
   int    dxb_spr  = (int)MarketInfo(Symbol(), MODE_SPREAD);
   double dxb_flt  = dxb_GetTotalOpenProfit();
   int    dxb_open = dxb_CountOpenTrades();
   double dxb_net  = dxb_g_dailyProfit - dxb_g_dailyLoss + dxb_flt;
   double dxb_step = dxb_AI_SAR_Period * dxb_AI_SAR_STEP_SIZE / 10000.0;
   double dxb_mxs  = dxb_step * dxb_AI_SAR_SCALPER_ACCELERATION;
   double dxb_sarV = iSAR(Symbol(), 0, dxb_step, dxb_mxs, 0);
   string dxb_sarD = (dxb_sarV < dxb_bid) ? "BULLISH" : "BEARISH";
   int    dxb_secL = Period()*60 - (int)(TimeCurrent() % (Period()*60));

   string dxb_think;
   if(dxb_g_dailyLimitHit)
      dxb_think = "DAILY LIMIT HIT -- Waiting for midnight reset";
   else
      if(dxb_Use_Floating_Loss_Limit && dxb_GetFloatingLoss() >= dxb_Floating_Loss_Limit_Per_Symbol)
         dxb_think = "FLOAT LIMIT HIT -- Closing all positions now";
      else
         if(!dxb_g_isTesting && dxb_spr > dxb_MaximumSpread)
            dxb_think = StringFormat("HIGH SPREAD %d pts > %d -- Waiting", dxb_spr, dxb_MaximumSpread);
         else
            if(Time[0] == dxb_g_lastBarTime)
               dxb_think = StringFormat("SAME BAR -- Waiting for next M%d candle (%ds)", Period(), dxb_secL);
            else
               if(dxb_open > 0)
                  dxb_think = StringFormat("MANAGING %d OPEN TRADE(S) -- Floating %+.2f | Watching TP & grid", dxb_open, dxb_flt);
               else
                  if(dxb_sarD == "BULLISH")
                     dxb_think = "SAR BULLISH -- Watching for bearish flip to trigger SELL";
                  else
                     dxb_think = "SAR BEARISH -- Watching for bullish flip to trigger BUY";

   string dxb_mode = dxb_g_isTesting ? "TESTER" : "LIVE - FLIP SINGLE ORDER";
   string dxb_l1   = StringFormat("[ %s | %s ]  Bid:%.2f  Spread:%dpts  Bar closes in:%ds", dxb_mode, Symbol(), dxb_bid, dxb_spr, dxb_secL);
   string dxb_l2   = StringFormat("SAR:%s  Open:%d  Floating:%+.2f  Net P/L:%+.2f  Trades:%d (W:%d L:%d)", dxb_sarD, dxb_open, dxb_flt, dxb_net, dxb_g_tradeCount, dxb_g_winCount, dxb_g_lossCount);
   string dxb_l3   = ">> " + dxb_think;
   string dxb_l4   = "Session:"+dxb_session_name+" SL:$"+dxb_Floating_Loss_Limit_Per_Symbol+"|"+dxb_GetSessionDots();


   int    dxb_chartW = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int    dxb_xPos   = dxb_chartW/2 - 350;
   if(dxb_xPos < 180)
      dxb_xPos = 180;
   string dxb_p = "DXB_MMFLIP_Tick_L";
   int    dxb_h = 15;

   dxb_DrawBG("DXB_MMFLIP_Tick_BG", dxb_xPos, 3, 750, 3 * dxb_h + 22, CORNER_LEFT_UPPER);

   dxb_Lbl(dxb_p, 0, dxb_l1, dxb_xPos, 3, dxb_h, CORNER_LEFT_UPPER, clrCyan,   8, "Courier New");
   dxb_Lbl(dxb_p, 1, dxb_l2, dxb_xPos, 3, dxb_h, CORNER_LEFT_UPPER, clrWhite,  8, "Courier New");
   dxb_Lbl(dxb_p, 2, dxb_l3, dxb_xPos, 3, dxb_h, CORNER_LEFT_UPPER, clrYellow, 8, "Courier New");
   dxb_Lbl(dxb_p, 3, dxb_l4, dxb_xPos, 3, dxb_h, CORNER_LEFT_UPPER, clrGreen, 10, "Courier New");

   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_FetchNews()
  {
// Safety: never run in tester
   if(dxb_g_isTesting)
      return;

   dxb_NewsCount=0;
   dxb_LastNewsFetch=TimeCurrent();

   string dxb_headers="";
   char   dxb_post[];
   char   dxb_result[];
   string dxb_resultHeaders;

   int dxb_resp=WebRequest("GET",DXB_NEWS_URL,dxb_headers,5000,
                           dxb_post,dxb_result,dxb_resultHeaders);
   if(dxb_resp!=200)
     {
      Print("[dxb NEWS] WebRequest failed. Code=",dxb_resp," Err=",GetLastError());
      Print("[dxb NEWS] Go to: Tools→Options→Expert Advisors→Allow WebRequest");
      Print("[dxb NEWS] Add URL: ",DXB_NEWS_URL);
      return;
     }

   string dxb_csv=CharArrayToString(dxb_result,0,WHOLE_ARRAY,CP_UTF8);
   string dxb_lines[];
   int    dxb_lc=StringSplit(dxb_csv,'\n',dxb_lines);

   for(int dxb_i=1; dxb_i<dxb_lc; dxb_i++)
     {
      if(dxb_NewsCount>=DXB_MAX_NEWS)
         break;
      string dxb_ln=dxb_lines[dxb_i];
      if(StringLen(StringTrimRight(StringTrimLeft(dxb_ln)))<5)
         continue;
      string dxb_f[];
      if(StringSplit(dxb_ln,',',dxb_f)<5)
         continue;

      string dxb_title   =dxb_CleanField(dxb_f[0]);
      string dxb_country =dxb_CleanField(dxb_f[1]);
      string dxb_date    =dxb_CleanField(dxb_f[2]);
      string dxb_time    =dxb_CleanField(dxb_f[3]);
      string dxb_impact  =dxb_CleanField(dxb_f[4]);

      if(!dxb_CurrencyMatches(dxb_country))
         continue;
      if(!dxb_ImpactMatches(dxb_impact))
         continue;
      if(dxb_Check_Specific_News)
        {
         string dxb_tL=dxb_title;
         StringToLower(dxb_tL);
         string dxb_sL=dxb_Specific_News_Text;
         StringToLower(dxb_sL);
         if(StringFind(dxb_tL,dxb_sL)<0)
            continue;
        }

      string dxb_dp[];
      if(StringSplit(dxb_date,'-',dxb_dp)<3)
         continue;
      string dxb_dtStr=dxb_dp[2]+"."+dxb_dp[0]+"."+dxb_dp[1]+" "+dxb_time;
      datetime dxb_dt=StringToTime(dxb_dtStr);
      if(dxb_dt<=0)
         continue;

      dxb_NewsTime[dxb_NewsCount]    =dxb_dt;
      dxb_NewsTitle[dxb_NewsCount]   =dxb_title;
      dxb_NewsCurrency[dxb_NewsCount]=dxb_country;
      dxb_NewsImpact[dxb_NewsCount]  =dxb_impact;
      dxb_NewsCount++;
     }
   Print("[dxb NEWS] Loaded ",dxb_NewsCount," events.");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool dxb_IsNewsTime()
  {
   if(dxb_NewsCount==0)
      return(false);
   datetime dxb_now=TimeCurrent();
   for(int dxb_i=0; dxb_i<dxb_NewsCount; dxb_i++)
     {
      datetime dxb_bs=dxb_NewsTime[dxb_i]-dxb_STOP_BEFORE_NEWS*60;
      datetime dxb_be=dxb_NewsTime[dxb_i]+dxb_START_AFTER_NEWS*60;
      if(dxb_now>=dxb_bs && dxb_now<=dxb_be)
        {
         static datetime dxb_ll=0;
         if(dxb_now-dxb_ll>=60)
           {
            dxb_ll=dxb_now;
            Print("[dxb NEWS] BLOCKED: ",dxb_NewsTitle[dxb_i],
                  " | Resumes: ",TimeToString(dxb_be));
           }
         return(true);
        }
     }
   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool dxb_CurrencyMatches(string dxb_country)
  {
   string dxb_cl[];
   int dxb_cn=StringSplit(dxb_Currencies_Check,',',dxb_cl);
   for(int dxb_i=0; dxb_i<dxb_cn; dxb_i++)
     {
      string dxb_clU=StringTrimLeft(StringTrimRight(dxb_cl[dxb_i]));
      string dxb_cntU=dxb_country;
      StringToUpper(dxb_clU);
      StringToUpper(dxb_cntU);
      if(dxb_clU==dxb_cntU)
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool dxb_ImpactMatches(string dxb_impact)
  {
   string dxb_imp=StringTrimLeft(StringTrimRight(dxb_impact));
   StringToUpper(dxb_imp);
   if(dxb_imp=="HIGH"   && dxb_NEWS_IMPOTANCE_HIGH)
      return(true);
   if(dxb_imp=="MEDIUM" && dxb_NEWS_IMPOTANCE_MEDIUM)
      return(true);
   if(dxb_imp=="LOW"    && dxb_NEWS_IMPOTANCE_LOW)
      return(true);
   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string dxb_CleanField(string dxb_s)
  {
   dxb_s=StringTrimLeft(StringTrimRight(dxb_s));
   if(StringLen(dxb_s)>0 && StringGetChar(dxb_s,0)=='"')
      dxb_s=StringSubstr(dxb_s,1);
   int dxb_l=StringLen(dxb_s);
   if(dxb_l>0 && StringGetChar(dxb_s,dxb_l-1)=='"')
      dxb_s=StringSubstr(dxb_s,0,dxb_l-1);
   return(dxb_s);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_DrawNewsLines()
  {
   if(!dxb_DRAW_NEWS_CHART)
      return;
   for(int dxb_i=0; dxb_i<dxb_NewsCount; dxb_i++)
     {
      if(dxb_NewsTime[dxb_i]<TimeCurrent()-3600)
         continue;
      string dxb_ln="DXB_MMFLIP_NL_"+IntegerToString(dxb_i);
      if(ObjectFind(0,dxb_ln)<0)
         ObjectCreate(0,dxb_ln,OBJ_VLINE,0,dxb_NewsTime[dxb_i],0);
      ObjectSetInteger(0,dxb_ln,OBJPROP_TIME,0,dxb_NewsTime[dxb_i]);
      ObjectSetInteger(0,dxb_ln,OBJPROP_COLOR,dxb_Line_Color);
      ObjectSetInteger(0,dxb_ln,OBJPROP_STYLE,dxb_Line_Style);
      ObjectSetInteger(0,dxb_ln,OBJPROP_WIDTH,dxb_Line_Width);
      ObjectSetInteger(0,dxb_ln,OBJPROP_BACK,true);

      string dxb_tn="DXB_MMFLIP_NT_"+IntegerToString(dxb_i);
      string dxb_tx="["+dxb_NewsImpact[dxb_i]+"] "+dxb_NewsCurrency[dxb_i]+": "+dxb_NewsTitle[dxb_i];
      if(StringLen(dxb_tx)>30)
         dxb_tx=StringSubstr(dxb_tx,0,30)+"...";
      if(ObjectFind(0,dxb_tn)<0)
         ObjectCreate(0,dxb_tn,OBJ_TEXT,0,dxb_NewsTime[dxb_i],High[0]);
      ObjectSetInteger(0,dxb_tn,OBJPROP_TIME,0,dxb_NewsTime[dxb_i]);
      ObjectSetDouble(0, dxb_tn,OBJPROP_PRICE,0,High[0]);
      ObjectSetString(0, dxb_tn,OBJPROP_TEXT,dxb_tx);
      ObjectSetString(0, dxb_tn,OBJPROP_FONT,dxb_News_Font);
      ObjectSetInteger(0,dxb_tn,OBJPROP_FONTSIZE,7);
      ObjectSetInteger(0,dxb_tn,OBJPROP_COLOR,dxb_Font_Color);
      ObjectSetDouble(0,dxb_tn,OBJPROP_ANGLE,90.0);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void dxb_DrawNewsBlockedLabel()
  {
   string dxb_on="DXB_MMFLIP_NewsBlock";
   dxb_DrawBG("DXB_MMFLIP_NewsBlock_BG", dxb_Chart_X_Axis_Position, dxb_Chart_Y_Axis_Position-20, 260, 20, CORNER_LEFT_UPPER);

   if(ObjectFind(0,dxb_on)<0)
      ObjectCreate(0,dxb_on,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,dxb_on,OBJPROP_CORNER,   CORNER_LEFT_UPPER);
   ObjectSetInteger(0,dxb_on,OBJPROP_XDISTANCE,dxb_Chart_X_Axis_Position);
   ObjectSetInteger(0,dxb_on,OBJPROP_YDISTANCE,dxb_Chart_Y_Axis_Position-20);
   ObjectSetString(0, dxb_on,OBJPROP_TEXT,     "NEWS FILTER ACTIVE - Trading paused");
   ObjectSetString(0, dxb_on,OBJPROP_FONT,     dxb_News_Font);
   ObjectSetInteger(0,dxb_on,OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0,dxb_on,OBJPROP_COLOR,    dxb_Line_Color);
   ObjectSetInteger(0,dxb_on,OBJPROP_ZORDER,   1);
  }

//+------------------------------------------------------------------+
//| dxb_DrawZones                                                      |
//+------------------------------------------------------------------+
