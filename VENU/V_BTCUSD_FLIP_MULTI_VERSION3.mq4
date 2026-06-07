//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA.mq4                  |
//|  First SAR signal -> continuous orders -> $1 basket profit        |
//|  SAR flip closes opposite orders. Early reverse trend pauses SAR  |
//|  cycle, draws arrows, closes opposite orders, resumes when aligned |
//+------------------------------------------------------------------+
#property strict

// MT4 compatibility: balance/deposit/withdrawal history operation type
#ifndef OP_BALANCE
#define OP_BALANCE 6
#endif
#property version   "1.09"

//======================== INPUTS ====================================
string InpEAName                  = "DXB SAR 5Min Gap30 BasketSL EarlyExit EA";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 3;     // maximum normal SAR orders per SAR signal cycle
#define DXB_HARD_MAX_OPEN_ORDERS 3  // absolute safety cap for normal SAR orders per cycle

double InpBasketProfitUSD         = 2.00;
double InpBasketProfitUSD_12_17 = 1.00; // profit target during 12,13,14,15,16,17 hours

double InpBasketStopLossUSD       = 5.00;    // BASKET stop loss in USD, 0 = disabled. This closes all orders in active SAR direction.
bool   InpOpenRecoveryAfterClose  = false;   // open recovery order after SL/SAR flip/early reverse close
double InpRecoveryProfitUSD       = 2.00;   // close recovery order when this USD profit is reached
bool   InpRecoveryAfterSLReverse  = false;   // true: after basket SL, open opposite direction

// Recovery gap orders: when existing BUY/SELL basket is in loss and price moves against it
// by this raw price gap, open one more same-direction recovery order.
bool   InpUseRecoveryGapOrders    = true;
double InpRecoveryGapRawPrice     = 200.0;   // raw price difference, not points
double InpRecoveryGapLot          = 0.01;
int    InpMaxRecoveryGapOrdersPerSide = 3;  // recovery ladder: 50, 100, 150 from first order price
int    InpStopLossPoints          = 0;       // 0 = no hard SL
int    InpSlippage                = 30;
int    InpMaxSpreadPoints         = 3000;

// Daily equity protection / profit lock
// Example: Balance=$100 -> Protected=$50, TradingCapital=$50, ProfitTarget=$25.
// When target is reached, EA closes its orders and pauses until next day.
// MT4 cannot literally move profit aside; this EA protects it by stopping new trades.
bool   InpUseEquityProtection       = false;
bool   InpAutoUseCurrentBalanceBase = true;   // true = take current account balance on EA load/new day
double InpManualBaseCapitalUSD      = 20.0;   // used only when Auto=false

double InpProfitTargetPercent      = 20.0;   // stop trading when equity reaches Base + 100%
double InpLossStopPercent          = 50.0;   // stop trading when equity reaches Base - 50%
double InpProtectionBufferUSD      = 0.00;   // optional buffer below loss-stop level
bool   InpCloseOrdersOnEquityHit    = true;

bool   InpUseDailyProfitLock        = false;
bool   InpCloseOrdersOnProfitLock   = true;
bool   InpPauseAfterProfitTarget    = true;

// Equity statistics reset cycle
bool   InpResetEquityStatsEvery6Hours = true;
int    InpEquityResetHours            = 24;      // fallback rolling reset if fixed hours are disabled
bool   InpUseFixedEquityResetHours    = false;   // true = reset only at configured server hours
string InpEquityResetHourList         = "1"; // server-time hours to reset equity base
bool   InpResetTradingCycleWithEquity = true;   // reset SAR/early/flat cycle when equity stats reset

// Deposit detection reset
bool   InpResetEquityStatsOnDeposit = true;      // detect OP_BALANCE deposit and reuse equity reset method
bool   InpCloseOrdersOnDepositReset = false;     // optional: close EA orders before deposit reset

// Notifications
bool   InpSendPushNotifications       = true;    // MT4 mobile push notification
bool   InpSendTerminalAlerts          = true;    // desktop popup alert
bool   InpNotifyOnProfitLock          = true;    // notify when trading stops after profit target
bool   InpNotifyOnEquityStop          = true;    // notify when trading stops after equity/loss protection
bool   InpNotifyOnEquityRestart       = true;    // notify when trading restarts after reset hour
bool   InpNotifyOnEAStart             = true;    // notify when EA is loaded


// Continuous order controls
bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;       // 0 = disabled
double InpMinPriceGap             = 0.00;    // raw price gap, 0 = disabled

// No-trading hours: block NEW normal SAR orders only. Close/profit/protection/recovery management still runs.
bool   InpUseNoNewOrderHours      = false;
string InpNoNewOrderHourList      = "23";//"13,14,15,16,17,18"; // server-time hours to block new orders


//profit booking hours are 4,5,6,7,8

// Big candle pause protection
bool   InpUseBigCandlePause       = false;     // pause new orders after very large candle
double InpBigCandleRawDifference  = 300;    // raw BTCUSD price difference: High[1]-Low[1]
int    InpBigCandlePauseMinutes   = 1;       // pause duration after big candle
bool   InpNotifyOnBigCandlePause  = true;     // push notification when big candle pause starts/ends

// SAR settings
double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;

bool isCloseOrderOnSARChangeEnabled=true;

// SAR flip confirmation filters
// 1) EMA9/EMA21 trend filter
// 2) Wait for one fully closed candle after SAR flip
// 3) Confirm raw price difference from SAR flip price
bool   InpUseSARFlipConfirmations = true;
bool   InpUseSAREMAConfirm        = false;
bool   InpUseSARClosedCandleConfirm = false;
bool   InpUseSARPriceDiffConfirm  = true;
// double InpSARConfirmPriceDiff     = 100.0;   // raw price diff for BTCUSD, not points
// int    InpSARConfirmMinutes       = 15;     // wait this many minutes after SAR signal change before new order

double InpSARConfirmPriceDiff     = 30.0;   // raw price diff for BTCUSD, not points
int    InpSARConfirmMinutes       = 1;     // wait this many minutes after SAR signal change before new order
// TEST MODE: Only SAR flip confirmation is active: wait 5 minutes, then require raw price gap 30 in SAR direction.
// BUY requires Close[1] - flipPrice >= 30. SELL requires flipPrice - Close[1] >= 30.

// SAR signal changed price side protection.
// Applies ONLY to normal SAR orders.
// BUY normal order allowed only when current Ask is above the SAR signal changed price.
// SELL normal order allowed only when current Bid is below the SAR signal changed price.
// Recovery orders are NOT blocked by this filter.
bool   InpUseSARSignalPriceSideFilter = true;
double InpSARSignalPriceSideMinGap    = 0.0;   // 0 = only correct side, >0 = require extra raw price gap

// Early trend settings
bool   InpUseEarlyTrend           = false;
int    InpFastEMA                 = 9;
int    InpSlowEMA                 = 21;
int    InpEarlyLookbackCandles    = 10;
double InpMinEarlyBodyMove        = 0.00;    // raw price diff, 0 = disabled
bool   InpCloseOnEarlyReverse     = false;
// If true, early reverse closes all market orders on this symbol in the active SAR direction,
// even if magic number is different. This prevents old EA/manual magic mismatch from blocking close.
bool   InpEarlyCloseAnyMagicOrders = true;
bool   InpDrawEarlyArrows         = true;

// Flat mode detection before early trend
bool   InpUseFlatMode             = true;
int    InpFlatLookbackCandles     = 5;       // closed candles to scan
double InpFlatMaxEMADistance      = 0.00;    // raw price diff, 0 = auto using ATR
double InpFlatMaxBodyTotal        = 0.00;    // raw price diff, 0 = auto using ATR
int    InpFlatMaxSameColor        = 3;       // max green/red count allowed in flat
bool   InpDrawFlatDots            = true;
color  InpFlatDotColor            = clrSilver;

// Visuals
bool   InpDrawSARArrows           = false;  // disabled: show only EARLY trend arrows
bool   InpDrawSAREveryBarArrows   = false;  // disabled: show only EARLY trend arrows
int    InpSAREveryBarLookback     = 200;    // historical SAR direction arrows to draw
color  InpBuyColor                = clrLime;
color  InpSellColor               = clrRed;
color  InpEarlyBuyColor           = clrAqua;
color  InpEarlySellColor          = clrOrangeRed;

// SAR dot visuals
bool   InpDrawSARDots            = true;
int    InpSARDotLookback         = 200;      // historical SAR dots to draw
color  InpSARDotBuyColor         = clrLime;
color  InpSARDotSellColor        = clrOrangeRed;

// SAR opposite-duration dynamic max-order protection
// Default every SAR signal = 10 orders.
// Restriction applies only when the previous opposite SAR color lasted long.
// Example: long RED trend restricts next GREEN orders; long GREEN trend restricts next RED orders.
bool   InpUseSARDurationDynamicLimit = false;
int    InpSARDurationScanBars        = 1500;   // historical bars to scan for SAR changes

int    InpSARVeryLongDurationMinutes = 60;    // opposite duration >=120 min => max 0
int    InpSARVeryLongDurationMaxOrders = 3;

int    InpSARDurationLongMinutes     = 30;     // opposite duration 60-119 min => max 2
int    InpSARLongDurationMaxOrders   = 3;

int    InpSARDurationMediumMinutes   = 10;     // opposite duration 30-59 min => max 5
int    InpSARMediumDurationMaxOrders = 3;

int    InpSARNormalDurationMaxOrders = 10;     // opposite duration <30 min or no data => max 10
//1-?100
//2 -67
int InpSARGoodMomentumExtraOrders = 1;
bool InpResetMaxOrdersWhenSARWeak = true;

bool InpIncreaseSARMaxAfterActiveMinutes = true;
int  InpSARActiveMinutesForExtraOrders = 30;
int  InpSARActiveExtraOrders = 10;

// SAR good-momentum upgrade
// If current SAR trend is strong, increase current SAR signal-cycle max back to normal max.
bool   InpUseSARGoodMomentumMaxUpgrade = false;
double InpSARGoodMomentumMinDotDistance = 300.0; // raw price distance from SAR dot
int    InpSARGoodMomentumADXPeriod = 14;
double InpSARGoodMomentumMinADX = 20.0;
int    InpSARGoodMomentumATRPeriod = 14;
double InpSARGoodMomentumMinATR = 100.0;       // raw BTCUSD ATR
int    InpSARGoodMomentumCandleLookback = 3;
int    InpSARGoodMomentumMinSameCandles = 1;

//================ DYNAMIC BTC SAR QUALITY ENGINE ===================
// SAR still gives GREEN/RED direction, but this layer decides whether
// the current BTC movement is strong enough to follow. It auto-adjusts
// using ATR, ADX, EMA distance and long-bar behaviour, so you do not
// need to keep changing fixed BTC price values every week.
bool   InpUseDynamicSAREngine              = false;
bool   InpBlockNewOrdersWhenSARWeak        = false;
bool   InpBlockFastSARFlip                 = false;
int    InpDynamicATRPeriod                 = 14;
int    InpDynamicMinSignalMinutes          = 20;   // normal minimum SAR age before new normal order
int    InpDynamicVeryStrongMinMinutes      = 10;   // allow earlier only if score is very strong
double InpDynamicConfirmATRMultiplier      = 0.80; // replaces fixed SAR diff when dynamic engine is ON
double InpDynamicStrongDotATRMultiplier    = 1.20; // SAR dot distance must be >= ATR * this
double InpDynamicWeakDotATRMultiplier      = 0.45; // below this means SAR is too close/weak
double InpDynamicEMADistanceATRMultiplier  = 0.10; // EMA9/21 separation required
double InpDynamicLongBarATRMultiplier      = 1.50; // long bar in SAR direction = breakout strength
double InpDynamicOppositeBarATRMultiplier  = 1.20; // long bar opposite SAR = danger
double InpDynamicADXStrong                 = 25.0;
double InpDynamicADXWeak                   = 18.0;
int    InpDynamicStrongScore               = 5;
int    InpDynamicVeryStrongScore           = 6;
int    InpDynamicWeakScore                 = 2;

//================ EARLY SAR WEAK EXIT ENGINE =======================
// This closes or freezes the active SAR basket BEFORE the full SAR flip.
// SAR is still the main direction, but when the current GREEN/RED signal
// starts dying, the EA stops adding orders and can close the basket early.
bool   InpUseEarlySARWeakExit          = true;
bool   InpStopNewOrdersOnSARWeakExit   = true;   // when SAR weak is detected, block adding new orders
bool   InpCloseBasketOnSARWeakExit     = false;   // close active BUY/SELL basket early before SAR flip when profit/loss/trail condition is met
double InpEarlySARWeakExitMinProfitUSD = 1;//0.20;  // close weak basket if already in small profit
double InpEarlySARWeakExitMaxLossUSD   = 5;//1.50;  // close weak basket before SAR flip if loss reaches this
double InpEarlySARWeakExitTrailUSD     = 0.75;  // if profit falls from peak by this value, close
int    InpEarlySARWeakExitNeedSignals  = 3;     // minimum weakness points required
int    InpEarlySARWeakExitMinAgeMin    = 5;     // avoid closing immediately after fresh flip
int    InpEarlySARWeakExitCooldownSec  = 60;    // avoid repeat close loop

//================ PROFIT PROTECTION / RECOVERY SAFETY ==============
// Protect total equity after a strong run. Example: equity peak 85,
// trail 10 => close all orders and pause if equity falls to 75.
bool   InpUseGlobalEquityTrailLock      = true;
double InpGlobalEquityTrailStartProfit  = 10.0;   // start trailing only after equity is Base + this profit
double InpGlobalEquityTrailLockUSD      = 10.0;   // close all if equity falls this much from peak
int    InpGlobalEquityTrailPauseMinutes = 60;     // pause new trading after trail lock closes orders

// Early close using pure candle pressure before SAR flip.
// BUY SAR + 4 red candles out of last 5 = weak BUY.
// SELL SAR + 4 green candles out of last 5 = weak SELL.
bool   InpUseOppositeCandleWeakExit     = true;
int    InpWeakExitCandleLookback        = 5;
int    InpWeakExitOppositeMinCandles    = 4;

// Stop adding recovery orders after a strong opposite move.
// Example BUY basket losing more than 200 raw price => do not add more BUY recovery.
bool   InpStopRecoveryOnStrongOppMove   = true;
double InpStrongOppMoveBlockRecoveryGap = 200.0;

// Absolute cap for all EA market orders combined: normal + recovery.
int    InpMaxTotalOpenOrders            = 3;


//======================== GLOBALS ===================================
int      g_activeSARDirection   = 0;       // 1 BUY, -1 SELL
int      g_lastSARDotDirection  = 0;       // current SAR side memory
int      g_earlyDirection       = 0;       // 1 BUY, -1 SELL, 0 none
bool     g_sarPausedByEarly     = false;   // true when early reverse fights SAR
bool     g_firstSARLocked       = false;
datetime g_lastBarTime          = 0;
datetime g_lastOrderTime        = 0;
datetime g_lastEarlyArrowTime   = 0;
datetime g_lastSARArrowTime     = 0;
datetime g_lastSAREveryBarTime   = 0;
datetime g_lastFlatDotTime      = 0;
string   OBJ_PREFIX             = "DXB_SAR_CYCLE_";
int      dotColor               = 0;       // 1 SAR below price, -1 SAR above price
bool     g_flatMode             = false;   // true when price is compressed/sideways

// SAR flip pending confirmation state
int      g_pendingSARConfirmDirection = 0;  // 1 BUY, -1 SELL, 0 none
double   g_pendingSARConfirmPrice     = 0.0;
datetime g_pendingSARConfirmTime      = 0;
datetime g_pendingSARConfirmBarTime   = 0;

// Active SAR signal changed reference price. This remains available after pending confirmation is reset.
double   g_activeSARSignalChangePrice = 0.0;
datetime g_activeSARSignalChangeTime  = 0;

int      g_equityDay            = -1;
double   g_dayStartBalance      = 0.0;
double   g_dayStartEquity       = 0.0;
double   g_baseBalance          = 0.0;   // balance captured on EA load/new day
double   g_lossStopEquityLevel = 0.0;  // base balance - 50% loss
double   g_profitTargetEquity  = 0.0;  // base balance + 50% profit
double   g_dailyProfitTarget   = 0.0;  // dollar profit target from base
double   g_lockedProfitToday    = 0.0;
bool     g_dailyProfitLock      = false;
bool     g_equityProtectionHit  = false;
datetime g_lastEquityStatsResetTime = 0;
int      g_equityCycleNumber    = 1;
int      g_lastEquityResetSlot  = -1;  // prevents repeated reset during the same reset hour
bool     g_notifyProfitLockSent = false;
bool     g_notifyEquityStopSent = false;
datetime g_lastDepositBalanceOpTime = 0; // last processed OP_BALANCE deposit/withdrawal time
bool     g_bigCandlePause          = false;
datetime g_bigCandlePauseUntil     = 0;
int      g_bigCandlePauseSARDirection = 0;
datetime g_lastBigCandlePauseBarTime = 0;
double   g_lastBigCandleMove       = 0.0;
bool     g_notifyBigCandlePauseSent = false;

// Last 5 SAR change duration arrays
datetime g_sarChangeTimes[5];
int      g_sarChangeDirections[5];
int      g_sarChangeDurationsSeconds[5];

// Current SAR signal-cycle order counter.
// This counts ALL normal SAR orders created in the current SAR signal,
// including orders that are already closed. It resets only when SAR signal changes.
int      g_sarCycleDirection       = 0;
int      g_sarCycleMaxOrders       = 10;
int      g_sarCycleOrdersCreated   = 0;
datetime g_sarCycleStartTime       = 0;
bool     g_sarGoodMomentum         = false;
double   g_sarGoodMomentumDotDistance = 0.0;
double   g_sarGoodMomentumADX      = 0.0;
double   g_sarGoodMomentumATR      = 0.0;
int      g_dynamicSARScore          = 0;
string   g_dynamicSARDecision       = "WAIT";
double   g_dynamicSARRequiredDiff   = 0.0;
double   g_dynamicSARDotDistance    = 0.0;
double   g_dynamicSARATR            = 0.0;
double   g_dynamicSARADX            = 0.0;
double   g_dynamicSARLongBarMove    = 0.0;

bool     g_earlySARWeakExitActive = false;
string   g_earlySARWeakExitReason = "";
double   g_activeBasketPeakProfit = 0.0;
datetime g_lastEarlySARWeakExitTime = 0;
int      g_lastEarlySARWeakExitDirection = 0;

double   g_globalEquityPeak              = 0.0;
datetime g_globalEquityTrailPauseUntil   = 0;
bool     g_globalEquityTrailLocked       = false;
string   g_globalEquityTrailStatus       = "OFF";

bool   InpUseH1TrendFilter = false;
int    InpH1FastEMA = 50;
int    InpH1SlowEMA = 200;

bool InpOpenExtraOrderOnEarlySameSAR = false;
int  InpEarlySameSARExtraMaxOrders = 1;
datetime g_lastEarlySameSAROrderBarTime = 0;

bool   InpAddOneOrderWhenSARDistanceH1Same = false;
double InpSARDistanceExtraOrderMin         = 300.0;
int    InpSARDistanceExtraOrders           = 1;
bool TryOpenEarlySameSARExtraOrder()
{
   // IMPORTANT: extra orders must not bypass SAR flip confirmation.
   // This prevents SELL/BUY orders from opening immediately after SAR change.
   if(g_pendingSARConfirmDirection != 0)
     {
      if(!IsSARFlipConfirmationReady())
        {
         Print("EARLY SAME SAR EXTRA BLOCKED | Waiting SAR confirmation | Direction=",
               DirectionText(g_pendingSARConfirmDirection),
               " | Duration=", SARConfirmDurationStatusText(),
               " | PriceDiff=", DoubleToString(GetSARConfirmCurrentPriceDiff(), Digits),
               " | RequiredDiff=", DoubleToString(InpSARConfirmPriceDiff, Digits));
         return(false);
        }

      Print("EARLY SAME SAR EXTRA | SAR confirmation completed | Direction=",
            DirectionText(g_pendingSARConfirmDirection));
      ResetSARFlipConfirmation();
     }

   if(!InpOpenExtraOrderOnEarlySameSAR)
      return false;

   int early = DetectEarlyTrend();

   if(early == 0)
      return false;

   if(early != g_activeSARDirection)
      return false;

   if(Time[1] == g_lastEarlySameSAROrderBarTime)
      return false;

   if(!IsOrderAllowedByH1Trend(g_activeSARDirection))
      return false;

   EnsureSARSignalOrderCycle(g_activeSARDirection);

   g_sarCycleMaxOrders += InpEarlySameSARExtraMaxOrders;

   if(OpenMarketOrder(g_activeSARDirection, "SAR_ARROW_EXTRA"))
   {
      g_lastEarlySameSAROrderBarTime = Time[1];

      Print("ARROW EXTRA ORDER OPENED | Direction=",
            DirectionText(g_activeSARDirection),
            " | NewMax=", g_sarCycleMaxOrders);

      return true;
   }

   return false;
}
bool TryOpenEarlySameSARExtraOrder111111()
{
   if(g_pendingSARConfirmDirection != 0 && !IsSARFlipConfirmationReady())
      return false;

   if(!InpOpenExtraOrderOnEarlySameSAR)
      return false;

   int early = DetectEarlyTrend();

   if(early == 0)
      return false;

   if(early != g_activeSARDirection)
      return false;

   if(Time[1] == g_lastEarlySameSAROrderBarTime)
      return false;

   EnsureSARSignalOrderCycle(g_activeSARDirection);

   g_sarCycleMaxOrders += InpEarlySameSARExtraMaxOrders;

   if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_V2"))
   {
      g_lastEarlySameSAROrderBarTime = Time[1];

      Print("EARLY SAME SAR EXTRA ORDER OPENED | Direction=",
            DirectionText(g_activeSARDirection),
            " | NewMax=", g_sarCycleMaxOrders);

      return true;
   }

   return false;
}
int GetH1TrendDirection()
  {


   double currentPrice = Close[0];

// M1 chart: 30 candles = 30 minutes ago
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 30);

   double diff = currentPrice - price30MinAgo;

   if(diff >= 100)
      return 1;   // BUY trend

   if(diff <= -100)
      return -1;  // SELL trend

   return 0;      // RANGE










   int h1  = GetH1TrendDirection1();
   int m30 = GetM30TrendDirection();

   if(h1 != 0 && h1 == m30)
      return h1;

   return 0; // no clear trend
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetH1TrendDirection1()
  {
   double fast = iMA(Symbol(), PERIOD_H1, InpH1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow = iMA(Symbol(), PERIOD_H1, InpH1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(fast > slow)
      return 1;
   if(fast < slow)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetM30TrendDirection()
  {
   double fast = iMA(Symbol(), PERIOD_M30, InpH1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow = iMA(Symbol(), PERIOD_M30, InpH1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(fast > slow)
      return 1;
   if(fast < slow)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOrderAllowedByH1Trend(int orderDirection)
  {
   if(!InpUseH1TrendFilter)
      return true;

   int trend = GetH1TrendDirection();

   if(trend == 0)
      return false;

   if(orderDirection != trend)
     {
      Print("ORDER BLOCKED BY H1 TREND | SAR=",
            DirectionText(orderDirection),
            " | H1Trend=",
            DirectionText(trend));
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
void SendEAAlert(string eventTitle, string details)
  {
   string msg = InpEAName + " | " + Symbol() + " | " + eventTitle + " | " + details;

   Print("NOTIFICATION | ", msg);

// if(InpSendTerminalAlerts)
//    Alert(msg);

   if(InpSendPushNotifications)
      SendNotification(msg);
  }
double GetBasketProfitTargetUSD()
{
   int h = TimeHour(TimeCurrent());

   if(h >= 12 && h <= 17)
      return InpBasketProfitUSD_12_17;

   return InpBasketProfitUSD;
}
//+------------------------------------------------------------------+
int OnInit()
  {
   InitializeEquityDay();
   InitializeLastDepositBalanceOpTime();
   DeleteNonEarlySignalArrows();
   LoadLast5SARChangeDurations();

   InpMagicNumber=AccountNumber()+202; // override magic number with account number to prevent interference between charts/accounts. Orders are still filtered by symbol and magic in this EA.

   Print(InpEAName, " initialized. Magic=", InpMagicNumber,
         " | BaseBalance=$", DoubleToString(g_baseBalance,2),
         " | LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
         " | ProfitTargetEquity=$", DoubleToString(g_profitTargetEquity,2),
         " | TargetProfit=$", DoubleToString(g_dailyProfitTarget,2));

   if(InpNotifyOnEAStart)
     {
      SendEAAlert("EA STARTED",
                  "Base=$" + DoubleToString(g_baseBalance,2) +
                  " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
                  " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
     }

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   Comment("");
  }
//+------------------------------------------------------------------+
void InitializeEquityDay()
  {
   g_equityDay       = TimeDay(TimeCurrent());
   g_dayStartBalance = AccountBalance();
   g_dayStartEquity  = AccountEquity();

// Fully automated: every cycle base is always taken from live AccountBalance().
// Example: if AccountBalance() is $20 at reset, target=$30 and loss-stop=$10.
   if(InpAutoUseCurrentBalanceBase)
      g_baseBalance = g_dayStartBalance;
   else
      g_baseBalance = InpManualBaseCapitalUSD;

   if(g_baseBalance <= 0.0)
      g_baseBalance = AccountBalance();

   g_dailyProfitTarget =
      g_baseBalance * InpProfitTargetPercent / 100.0;

   g_profitTargetEquity =
      g_baseBalance + g_dailyProfitTarget;

   g_lossStopEquityLevel =
      g_baseBalance - (g_baseBalance * InpLossStopPercent / 100.0) - InpProtectionBufferUSD;

   if(g_lossStopEquityLevel < 0.0)
      g_lossStopEquityLevel = 0.0;

   g_lockedProfitToday    = 0.0;
   g_dailyProfitLock      = false;
   g_equityProtectionHit  = false;
   g_notifyProfitLockSent = false;
   g_notifyEquityStopSent = false;
   g_lastEquityStatsResetTime = TimeCurrent();
   g_lastEquityResetSlot = GetEquityResetSlot(TimeCurrent());

   if(InpResetTradingCycleWithEquity)
      ResetTradingCycleState();

   Print("EQUITY STATS INIT/RESET | Cycle=", g_equityCycleNumber,
         " | ResetTime=", TimeToString(g_lastEquityStatsResetTime, TIME_DATE|TIME_SECONDS),
         " | StartBalance=$", DoubleToString(g_dayStartBalance,2),
         " | StartEquity=$", DoubleToString(g_dayStartEquity,2),
         " | Base=$", DoubleToString(g_baseBalance,2),
         " | LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
         " | ProfitTargetEquity=$", DoubleToString(g_profitTargetEquity,2),
         " | TargetProfit=$", DoubleToString(g_dailyProfitTarget,2));
  }

//+------------------------------------------------------------------+
void ResetTradingCycleState()
  {
   g_activeSARDirection  = 0;
   g_lastSARDotDirection = 0;
   g_earlyDirection      = 0;
   g_sarPausedByEarly    = false;
   g_firstSARLocked      = false;
   g_flatMode            = false;
   g_lastOrderTime       = 0;
   g_sarCycleDirection   = 0;
   g_sarCycleMaxOrders   = MathMax(0, InpSARNormalDurationMaxOrders);
   g_sarCycleOrdersCreated = 0;
   g_sarCycleStartTime   = 0;
   g_activeSARSignalChangePrice = 0.0;
   g_activeSARSignalChangeTime  = 0;
   ResetSARFlipConfirmation();
   ResetBigCandlePauseState();

   Print("TRADING CYCLE RESET | Waiting for fresh SAR direction after equity stats reset.");
  }

//+------------------------------------------------------------------+
int GetEquityResetSlot(datetime t)
  {
   return(TimeYear(t) * 100000 + TimeDayOfYear(t) * 100 + TimeHour(t));
  }

//+------------------------------------------------------------------+
bool IsConfiguredEquityResetHour(int hourValue)
  {
   string parts[];
   int total = StringSplit(InpEquityResetHourList, ',', parts);

   for(int i = 0; i < total; i++)
     {
      int h = (int)StrToInteger(parts[i]);
      if(h < 0)
         h = 0;
      if(h > 23)
         h = 23;

      if(h == hourValue)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool IsConfiguredNoNewOrderHour(int hourValue)
  {
   string parts[];
   int total = StringSplit(InpNoNewOrderHourList, ',', parts);

   for(int i = 0; i < total; i++)
     {
      int h = (int)StrToInteger(parts[i]);
      if(h < 0)
         h = 0;
      if(h > 23)
         h = 23;

      if(h == hourValue)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool IsNoNewOrderHour()
  {
   if(!InpUseNoNewOrderHours)
      return(false);

   return(IsConfiguredNoNewOrderHour(TimeHour(TimeCurrent())));
  }

//+------------------------------------------------------------------+
string NoNewOrderHoursStatusText()
  {
   if(!InpUseNoNewOrderHours)
      return("OFF");

   string status = IsNoNewOrderHour() ? "BLOCK NOW" : "ALLOW";
   return(status + " | " + InpNoNewOrderHourList);
  }

//+------------------------------------------------------------------+
void ResetEquityDayIfNewDay()
  {
   datetime now = TimeCurrent();
   int today = TimeDay(now);

   bool resetNow = false;
   string resetReason = "";

   if(InpResetEquityStatsEvery6Hours)
     {
      if(InpUseFixedEquityResetHours)
        {
         int currentSlot = GetEquityResetSlot(now);

         // Reset only once during configured server hours: 1, 7, 13, 19 by default.
         if(IsConfiguredEquityResetHour(TimeHour(now)) && currentSlot != g_lastEquityResetSlot)
           {
            resetNow = true;
            resetReason = "FIXED EQUITY RESET HOUR";
           }
        }
      else
        {
         int resetSeconds = MathMax(1, InpEquityResetHours) * 3600;
         if(g_lastEquityStatsResetTime <= 0 || now - g_lastEquityStatsResetTime >= resetSeconds)
           {
            resetNow = true;
            resetReason = "ROLLING EQUITY RESET";
           }
        }
     }

// If fixed reset hours are enabled, 01:00 handles the new-day reset.
// If fixed hours are disabled, keep the old daily reset behavior.
   if(!InpUseFixedEquityResetHours && today != g_equityDay)
     {
      resetNow = true;
      resetReason = "NEW DAY";
     }

   if(resetNow)
     {
      g_equityCycleNumber++;
      InitializeEquityDay();

      Print(resetReason, " | Equity statistics reset from AccountBalance(). Trading enabled. Hours=", InpEquityResetHourList);

      if(InpNotifyOnEquityRestart)
        {
         SendEAAlert("TRADING RESTARTED",
                     resetReason +
                     " | NewBase=$" + DoubleToString(g_baseBalance,2) +
                     " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
                     " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
        }
     }
  }

//+------------------------------------------------------------------+
int GetSecondsUntilNextEquityReset()
  {
   if(!InpResetEquityStatsEvery6Hours || g_lastEquityStatsResetTime <= 0)
      return(0);

   datetime now = TimeCurrent();

   if(InpUseFixedEquityResetHours)
     {
      datetime hourStart = now - (TimeMinute(now) * 60) - TimeSeconds(now);

      for(int i = 0; i <= 48; i++)
        {
         datetime candidate = hourStart + (i * 3600);

         if(candidate <= now)
            continue;

         if(IsConfiguredEquityResetHour(TimeHour(candidate)))
            return((int)(candidate - now));
        }

      return(0);
     }

   int resetSeconds = MathMax(1, InpEquityResetHours) * 3600;
   int elapsed = (int)(now - g_lastEquityStatsResetTime);
   int left = resetSeconds - elapsed;

   if(left < 0)
      left = 0;

   return(left);
  }

//+------------------------------------------------------------------+
string FormatSecondsToHHMM(int totalSeconds)
  {
   int hours = totalSeconds / 3600;
   int mins  = (totalSeconds % 3600) / 60;

   return(IntegerToString(hours) + "h " + IntegerToString(mins) + "m");
  }

//+------------------------------------------------------------------+
void InitializeLastDepositBalanceOpTime()
  {
   g_lastDepositBalanceOpTime = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderType() != OP_BALANCE)
         continue;

      if(OrderCloseTime() > g_lastDepositBalanceOpTime)
         g_lastDepositBalanceOpTime = OrderCloseTime();
     }

   Print("DEPOSIT WATCH INIT | Last OP_BALANCE time=",
         TimeToString(g_lastDepositBalanceOpTime, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
bool CheckDepositAndResetEquityStats()
  {
   if(!InpResetEquityStatsOnDeposit)
      return(false);

   bool resetDone = false;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderType() != OP_BALANCE)
         continue;

      datetime opTime = OrderCloseTime();
      if(opTime <= g_lastDepositBalanceOpTime)
         continue;

      double amount = OrderProfit();
      string comment = OrderComment();

      // Always advance processed time so old balance operations are not repeated.
      if(opTime > g_lastDepositBalanceOpTime)
         g_lastDepositBalanceOpTime = opTime;

      // Positive OP_BALANCE = deposit/balance-in for most brokers.
      // Closed trade profit is NOT OP_BALANCE, so it will not trigger this reset.
      if(amount <= 0.0)
        {
         Print("BALANCE OPERATION IGNORED | Amount=$", DoubleToString(amount,2),
               " | Comment=", comment);
         continue;
        }

      Print("DEPOSIT DETECTED | Amount=$", DoubleToString(amount,2),
            " | Comment=", comment,
            " | Reusing equity reset method");

      if(InpCloseOrdersOnDepositReset && CountAllOrders() > 0)
         CloseAllEAOrders("Deposit detected - equity stats reset");

      g_equityCycleNumber++;
      InitializeEquityDay();   // same method used by fixed reset hours 1,7,13,19

      if(InpNotifyOnEquityRestart)
        {
         SendEAAlert("TRADING RESTARTED - DEPOSIT RESET",
                     "Deposit=$" + DoubleToString(amount,2) +
                     " | NewBase=$" + DoubleToString(g_baseBalance,2) +
                     " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
                     " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
        }

      resetDone = true;
      break; // one reset is enough for this tick
     }

   return(resetDone);
  }

//+------------------------------------------------------------------+
double GetTodayProfitFromBase()
  {
   return(AccountEquity() - g_baseBalance);
  }

//+------------------------------------------------------------------+
//| Total open order hard cap: normal + recovery                     |
//+------------------------------------------------------------------+
bool IsTotalOpenOrderCapReached(string source)
  {
   int total = CountAllOrders();
   if(InpMaxTotalOpenOrders > 0 && total >= InpMaxTotalOpenOrders)
     {
      Print("TOTAL OPEN ORDER CAP BLOCKED | Source=", source,
            " | Total=", total, "/", InpMaxTotalOpenOrders);
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Global equity trailing lock                                      |
//+------------------------------------------------------------------+
bool IsGlobalEquityTrailPauseActive()
  {
   if(!InpUseGlobalEquityTrailLock)
      return(false);

   if(g_globalEquityTrailPauseUntil <= 0)
      return(false);

   if(TimeCurrent() >= g_globalEquityTrailPauseUntil)
     {
      g_globalEquityTrailPauseUntil = 0;
      g_globalEquityTrailLocked = false;
      g_globalEquityPeak = AccountEquity();
      g_globalEquityTrailStatus = "RESUMED";

      Print("GLOBAL EQUITY TRAIL PAUSE FINISHED | NewPeak=$",
            DoubleToString(g_globalEquityPeak, 2));

      return(false);
     }

   int leftSec = (int)(g_globalEquityTrailPauseUntil - TimeCurrent());
   if(leftSec < 0)
      leftSec = 0;

   g_globalEquityTrailStatus = "PAUSED " + FormatSecondsToHHMM(leftSec);
   return(true);
  }

//+------------------------------------------------------------------+
bool CheckGlobalEquityTrailLock()
  {
   if(!InpUseGlobalEquityTrailLock)
      return(false);

   if(IsGlobalEquityTrailPauseActive())
      return(true);

   double eq = AccountEquity();

   if(g_globalEquityPeak <= 0.0)
      g_globalEquityPeak = eq;

   if(eq > g_globalEquityPeak)
      g_globalEquityPeak = eq;

   double profitFromBase = eq - g_baseBalance;

   if(profitFromBase < InpGlobalEquityTrailStartProfit)
     {
      g_globalEquityTrailStatus = "WAIT +$" + DoubleToString(InpGlobalEquityTrailStartProfit, 2);
      return(false);
     }

   double dropFromPeak = g_globalEquityPeak - eq;

   g_globalEquityTrailStatus =
      "ON Peak=$" + DoubleToString(g_globalEquityPeak, 2) +
      " Drop=$" + DoubleToString(dropFromPeak, 2) +
      "/" + DoubleToString(InpGlobalEquityTrailLockUSD, 2);

   if(InpGlobalEquityTrailLockUSD > 0.0 && dropFromPeak >= InpGlobalEquityTrailLockUSD)
     {
      Print("GLOBAL EQUITY TRAIL LOCK HIT | Equity=$", DoubleToString(eq, 2),
            " | Peak=$", DoubleToString(g_globalEquityPeak, 2),
            " | Drop=$", DoubleToString(dropFromPeak, 2),
            " | Trail=$", DoubleToString(InpGlobalEquityTrailLockUSD, 2));

      if(CountAllOrders() > 0)
         CloseAllEAOrders("Global equity trailing lock");

      g_globalEquityTrailLocked = true;
      g_globalEquityTrailPauseUntil =
         TimeCurrent() + MathMax(1, InpGlobalEquityTrailPauseMinutes) * 60;

      g_globalEquityPeak = AccountEquity();
      g_globalEquityTrailStatus =
         "LOCKED PAUSE " + IntegerToString(InpGlobalEquityTrailPauseMinutes) + "m";

      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
int CountOppositeCandlesForWeakExit(int direction)
  {
   if(direction == 0)
      return(0);

   int lookback = MathMax(1, InpWeakExitCandleLookback);
   return(CountDirectionalCandles(-direction, lookback));
  }

//+------------------------------------------------------------------+
bool IsStrongOppositeMoveAgainstRecovery(int direction, double adverseGap)
  {
   if(!InpStopRecoveryOnStrongOppMove)
      return(false);

   if(InpStrongOppMoveBlockRecoveryGap <= 0.0)
      return(false);

   if(adverseGap >= InpStrongOppMoveBlockRecoveryGap)
     {
      Print("RECOVERY BLOCKED BY STRONG OPPOSITE MOVE | Direction=",
            DirectionText(direction),
            " | AdverseGap=", DoubleToString(adverseGap, Digits),
            " | BlockGap=", DoubleToString(InpStrongOppMoveBlockRecoveryGap, Digits));
      return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+
bool CheckEquityConditions()
  {
   ResetEquityDayIfNewDay();

   if(CheckGlobalEquityTrailLock())
      return(true);

// 1) Loss stop: if equity drops to base - loss percent, close EA orders and stop.
   if(InpUseEquityProtection && AccountEquity() < g_lossStopEquityLevel)
     {
      g_equityProtectionHit = true;

      if(InpCloseOrdersOnEquityHit && CountAllOrders() > 0)
         CloseAllEAOrders("50 percent equity protection hit");

      Print("EQUITY PROTECTION HIT | Equity=$", DoubleToString(AccountEquity(),2),
            " Protected=$", DoubleToString(g_lossStopEquityLevel,2),
            " Base=$", DoubleToString(g_baseBalance,2),
            " LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2));

      if(InpNotifyOnEquityStop && !g_notifyEquityStopSent)
        {
         g_notifyEquityStopSent = true;
         SendEAAlert("TRADING STOPPED - EQUITY LOSS",
                     "Equity=$" + DoubleToString(AccountEquity(),2) +
                     " | Base=$" + DoubleToString(g_baseBalance,2) +
                     " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
        }

      return(true);
     }

// 2) Daily profit lock: when equity reaches base + profit percent, close EA orders and pause.
   if(InpUseDailyProfitLock)
     {
      double profitFromBase = GetTodayProfitFromBase();

      if(!g_dailyProfitLock && profitFromBase >= g_dailyProfitTarget)
        {
         g_dailyProfitLock   = true;
         g_lockedProfitToday = profitFromBase;

         if(InpCloseOrdersOnProfitLock && CountAllOrders() > 0)
            CloseAllEAOrders("Daily profit lock: equity reached base plus profit percent");

         Print("DAILY PROFIT LOCK HIT | Base=$", DoubleToString(g_baseBalance,2),
               " Equity=$", DoubleToString(AccountEquity(),2),
               " Profit=$", DoubleToString(profitFromBase,2),
               " Target=$", DoubleToString(g_dailyProfitTarget,2),
               " LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
               " TargetEquity=$", DoubleToString(g_profitTargetEquity,2),
               " | Trading paused until next day.");

         if(InpNotifyOnProfitLock && !g_notifyProfitLockSent)
           {
            g_notifyProfitLockSent = true;
            SendEAAlert("TRADING STOPPED - PROFIT TARGET",
                        "Equity=$" + DoubleToString(AccountEquity(),2) +
                        " | Base=$" + DoubleToString(g_baseBalance,2) +
                        " | Profit=$" + DoubleToString(profitFromBase,2) +
                        " | Target=$" + DoubleToString(g_dailyProfitTarget,2));
           }
        }

      if(g_dailyProfitLock && InpPauseAfterProfitTarget)
         return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+
void CloseAllEAOrders(string reason)
  {
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      int type = OrderType();
      double closePrice = (type == OP_BUY) ? Bid : Ask;

      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);
      if(!ok)
        {
         int err = GetLastError();
         Print("CloseAllEAOrders failed | Ticket=", OrderTicket(), " Reason=", reason, " Error=", err);
         ResetLastError();
        }
      else
        {
         Print("CloseAllEAOrders closed | Ticket=", OrderTicket(), " Reason=", reason);
        }
     }
  }
//+------------------------------------------------------------------+

void ResetBigCandlePauseState()
  {
   g_bigCandlePause = false;
   g_bigCandlePauseUntil = 0;
   g_bigCandlePauseSARDirection = 0;
   g_lastBigCandleMove = 0.0;
   g_notifyBigCandlePauseSent = false;
  }

//+------------------------------------------------------------------+
int GetClosedCandleDirection(int shift)
  {
   if(shift < 0 || shift >= Bars)
      return(0);

   if(Close[shift] > Open[shift])
      return(1);

   if(Close[shift] < Open[shift])
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
void UpgradeSARCycleMaxToNormalBecauseBigCandle(int direction, double candleMove, string reason)
  {
   if(direction == 0)
      return;

   EnsureSARSignalOrderCycle(direction);

   int normalMax = MathMax(0, InpSARNormalDurationMaxOrders);
   if(normalMax <= 0)
      return;

   if(g_sarCycleMaxOrders >= normalMax)
     {
      Print("BIG CANDLE SAME SAR | Normal max already active | Direction=", DirectionText(direction),
            " | MaxOrders=", g_sarCycleMaxOrders,
            " | Created=", g_sarCycleOrdersCreated,
            " | Move=", DoubleToString(candleMove, Digits));
      return;
     }

   int oldMax = g_sarCycleMaxOrders;
   g_sarCycleMaxOrders = normalMax;

   Print("BIG CANDLE SAME SAR - MAX UPGRADED | Direction=", DirectionText(direction),
         " | OldMax=", oldMax,
         " | NewMax=", g_sarCycleMaxOrders,
         " | Created=", g_sarCycleOrdersCreated,
         " | Move=", DoubleToString(candleMove, Digits),
         " | Reason=", reason);
  }

//+------------------------------------------------------------------+
void CheckBigCandlePauseOnNewBar(bool isNewBar)
  {
   if(!InpUseBigCandlePause)
      return;

   if(!isNewBar)
      return;

   if(Bars < 10)
      return;

// Use the last fully closed candle. For BTCUSD this is raw price difference, not points.
   datetime barTime = Time[1];
   if(barTime == g_lastBigCandlePauseBarTime)
      return;

   double candleMove = MathAbs(High[1] - Low[1]);
   if(candleMove < InpBigCandleRawDifference)
      return;

   int sarDirection = g_activeSARDirection;
   if(sarDirection == 0)
      sarDirection = GetSARDotDirection(1);

   int candleDirection = GetClosedCandleDirection(1);

   g_lastBigCandlePauseBarTime = barTime;
   g_lastBigCandleMove = candleMove;

// New rule:
// 1) Big candle SAME direction as current SAR = trend momentum. Do NOT pause.
//    Upgrade current SAR cycle maximum to InpSARNormalDurationMaxOrders.
// 2) Big candle OPPOSITE direction to current SAR = dangerous reversal spike. Pause trading.
   if(sarDirection != 0 && candleDirection != 0 && candleDirection == sarDirection)
     {
      UpgradeSARCycleMaxToNormalBecauseBigCandle(sarDirection, candleMove, "Big candle same as SAR direction");

      Print("BIG CANDLE SAME DIRECTION - NO PAUSE | SAR=", DirectionText(sarDirection),
            " | Candle=", DirectionText(candleDirection),
            " | Move=", DoubleToString(candleMove, Digits),
            " | MaxOrders=", g_sarCycleMaxOrders,
            " | Created=", g_sarCycleOrdersCreated);

      return;
     }

// If candle has no clear body direction, do not start a pause.
   if(candleDirection == 0 || sarDirection == 0)
     {
      Print("BIG CANDLE IGNORED | No clear SAR/candle direction | SAR=", DirectionText(sarDirection),
            " | Candle=", DirectionText(candleDirection),
            " | Move=", DoubleToString(candleMove, Digits));
      return;
     }

// Pause only when big candle direction is opposite to current SAR direction.
   g_bigCandlePause = true;
   g_bigCandlePauseUntil = TimeCurrent() + MathMax(1, InpBigCandlePauseMinutes) * 60;
   g_bigCandlePauseSARDirection = sarDirection;
   g_notifyBigCandlePauseSent = true;

   Print("BIG CANDLE OPPOSITE SAR - PAUSE STARTED | Move=", DoubleToString(candleMove, Digits),
         " Required=", DoubleToString(InpBigCandleRawDifference, Digits),
         " Candle=", DirectionText(candleDirection),
         " SAR=", DirectionText(g_bigCandlePauseSARDirection),
         " PauseUntil=", TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS));

   if(InpNotifyOnBigCandlePause)
     {
      SendEAAlert("TRADING PAUSED - BIG CANDLE OPPOSITE SAR",
                  "Move=" + DoubleToString(candleMove,2) +
                  " | Candle=" + DirectionText(candleDirection) +
                  " | SAR=" + DirectionText(g_bigCandlePauseSARDirection) +
                  " | Pause=" + IntegerToString(InpBigCandlePauseMinutes) + "m" +
                  " | Wait SAR change from " + DirectionText(g_bigCandlePauseSARDirection));
     }
  }

//+------------------------------------------------------------------+
// bool IsBigCandlePauseActive()
// {
//    if(!InpUseBigCandlePause)
//       return(false);

//    if(!g_bigCandlePause)
//       return(false);

//    bool timeCompleted = (TimeCurrent() >= g_bigCandlePauseUntil);

//    if(timeCompleted)
//    {
//       Print("BIG CANDLE PAUSE COMPLETED | PauseUntil=",
//             TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS));

//       ResetBigCandlePauseState();
//       return(false);
//    }

//    return(true);
// }
bool IsBigCandlePauseActive()
{
   if(!InpUseBigCandlePause)
      return(false);

   if(!g_bigCandlePause)
      return(false);

   int currentSAR = g_activeSARDirection;
   if(currentSAR == 0)
      currentSAR = GetSARDotDirection(1);

   // // ADD THIS
   // if(IsCurrentSARGoodMomentum(currentSAR))
   // {
   //    Print("BIG CANDLE PAUSE RELEASED BY SAR GOOD MOMENTUM | SAR=",
   //          DirectionText(currentSAR));

   //    ResetBigCandlePauseState();
   //    return(false);
   // }

   bool timeCompleted = (TimeCurrent() >= g_bigCandlePauseUntil);
   bool sarChanged = (currentSAR != 0 && g_bigCandlePauseSARDirection != 0 && currentSAR != g_bigCandlePauseSARDirection);

   if(timeCompleted && sarChanged)
   {
      ResetBigCandlePauseState();
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
string BigCandlePauseStatusText()
  {
   if(!g_bigCandlePause)
      return("OFF");

   int secondsLeft = (int)(g_bigCandlePauseUntil - TimeCurrent());
   if(secondsLeft < 0)
      secondsLeft = 0;

   return("ON " + FormatSecondsToHHMM(secondsLeft) +
          " | Wait SAR " + DirectionText(g_bigCandlePauseSARDirection) + " change");
  }

//+------------------------------------------------------------------+
void UpdateBarAndSARVisualState(bool isNewBar)
  {
   int sarDotDirection = GetSARDotDirection(1);

   if(InpDrawSAREveryBarArrows && isNewBar && sarDotDirection != 0 && Time[1] != g_lastSAREveryBarTime)
     {
      DrawSignalArrow("SAR_BAR",
                      sarDotDirection,
                      Time[1],
                      sarDotDirection == 1 ? Low[1] : High[1],
                      false);
      g_lastSAREveryBarTime = Time[1];
     }

   if(!g_firstSARLocked && sarDotDirection != 0)
     {
      g_firstSARLocked      = true;
      g_activeSARDirection  = sarDotDirection;
      g_lastSARDotDirection = sarDotDirection;
      g_activeSARSignalChangePrice = Close[1];
      g_activeSARSignalChangeTime  = TimeCurrent();
      ResetSARSignalOrderCycle(sarDotDirection, "first SAR locked");
      Print("FIRST SAR LOCKED | Direction=", DirectionText(g_activeSARDirection),
            " | SignalPrice=", DoubleToString(g_activeSARSignalChangePrice, Digits));
     }
  }

//+------------------------------------------------------------------+
bool IsRecoveryOrder()
  {
   string c = OrderComment();
   return(StringFind(c, "RECOVERY_TP_0.50") >= 0 ||
          StringFind(c, "RECOVERY") >= 0);
  }

//+------------------------------------------------------------------+
int CountRecoveryOrders()
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(IsRecoveryOrder())
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
void CloseRecoveryOrdersAtProfit()
  {
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!IsRecoveryOrder())
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < InpRecoveryProfitUSD)
         continue;

      int type = OrderType();
      double closePrice = (type == OP_BUY) ? Bid : Ask;

      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrGold);

      if(ok)
        {
         Print("RECOVERY PROFIT CLOSED | Ticket=", OrderTicket(),
               " | Profit=$", DoubleToString(profit, 2),
               " | Target=$", DoubleToString(InpRecoveryProfitUSD, 2));
        }
      else
        {
         int err = GetLastError();
         Print("RECOVERY PROFIT CLOSE FAILED | Ticket=", OrderTicket(),
               " | Profit=$", DoubleToString(profit, 2),
               " | Error=", err);
         ResetLastError();
        }
     }
  }
//+------------------------------------------------------------------+
//| Check MT4 trading permission                                     |
//+------------------------------------------------------------------+
bool IsTradingAllowedNow()
  {
   if(!IsTradeAllowed())
     {
      Print("Trading blocked: AutoTrading OFF or broker trading disabled");
      return(false);
     }

   if(IsTradeContextBusy())
     {
      Print("Trading blocked: Trade context busy");
      return(false);
     }

   if(AccountStopoutLevel() > 0 && AccountFreeMargin() <= 0)
     {
      Print("Trading blocked: No free margin");
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
bool OpenRecoveryOrder(int direction, string sourceReason)
  {

   if(!IsTradingAllowedNow())
     {
      Print("Recovery order blocked: AutoTrading OFF");
      return(false);
     }
   if(!InpOpenRecoveryAfterClose)
      return(false);

   if(direction == 0)
      return(false);

   RefreshRates();

   if(IsTotalOpenOrderCapReached("OpenRecoveryOrder"))
      return(false);

   if(CheckEquityConditions())
     {
      Print("RECOVERY ORDER BLOCKED | Equity/profit lock active. Source=", sourceReason);
      return(false);
     }

     //      // ADD HERE
// if(CountAllOrders() >= 1)
// {
//    Print("RECOVERY ORDER BLOCKED | Current order count already >= 1 | Source=", sourceReason);
//    return(false);
// }

// Recovery is independent, but only ONE recovery order is allowed at a time.
// It is NOT blocked by normal order count, normal price gap, or normal order creation gates.
   if(CountRecoveryOrders() >= 1)
     {
      Print("RECOVERY ORDER BLOCKED | One recovery order already active. Source=", sourceReason);
      return(false);
     }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   // SAR signal price side filter is NOT applied to recovery orders.
   // Recovery must be allowed to work even when price is against the original SAR signal.

   double sl = 0;

   if(InpStopLossPoints > 0)
     {
      if(direction == 1)
         sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else
         sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
     }

   double lot = NormalizeLot(InpFixedLot);

   string comment = "SAR_FLIP_V2_RECOVERY_TP_0.50_" + DirectionText(direction);
   if(!IsTradingAllowedNow())
     {
      return(false);
     }
   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          sl,
                          0,
                          comment,
                          InpMagicNumber,
                          0,
                          direction == 1 ? InpBuyColor : InpSellColor);

   if(ticket < 0)
     {
      int err = GetLastError();
      Print("RECOVERY ORDER SEND FAILED | Direction=", DirectionText(direction),
            " | Source=", sourceReason,
            " | Error=", err);
      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();

   Print("RECOVERY ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | TargetProfit=$", DoubleToString(InpRecoveryProfitUSD, 2),
         " | Comment=", comment,
         " | Source=", sourceReason);

   return(true);
  }

//+------------------------------------------------------------------+
int CountRecoveryGapOrdersByDirection(int direction)
  {
   int total = 0;
   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      if(StringFind(OrderComment(), "RECOVERY_GAP") >= 0)
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
bool GetRecoveryGapReferencePrice(int direction, double &referencePrice, int &totalSideOrders)
  {
   totalSideOrders = 0;
   referencePrice = 0.0;

   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      double op = OrderOpenPrice();

      if(totalSideOrders == 0)
         referencePrice = op;
      else
        {
         // BUY recovery: use lowest BUY open price. Next BUY opens only after price drops 30 below it.
         if(direction == 1 && op < referencePrice)
            referencePrice = op;

         // SELL recovery: use highest SELL open price. Next SELL opens only after price rises 30 above it.
         if(direction == -1 && op > referencePrice)
            referencePrice = op;
        }

      totalSideOrders++;
     }

   return(totalSideOrders > 0);
  }

//+------------------------------------------------------------------+
bool OpenRecoveryGapMarketOrder(int direction, double gapMove)
  {
   if(direction == 0)
      return(false);

   if(!IsTradingAllowedNow())
      return(false);

   RefreshRates();

   if(IsTotalOpenOrderCapReached("OpenRecoveryGapMarketOrder"))
      return(false);

   if(CheckEquityConditions())
     {
      Print("RECOVERY GAP BLOCKED | Equity/profit lock active.");
      return(false);
     }

   if(CountRecoveryGapOrdersByDirection(direction) >= InpMaxRecoveryGapOrdersPerSide)
     {
      Print("RECOVERY GAP BLOCKED | Max recovery orders reached | Direction=",
            DirectionText(direction), " | Count=", CountRecoveryGapOrdersByDirection(direction),
            "/", InpMaxRecoveryGapOrdersPerSide);
      return(false);
     }

   if(MarketInfo(Symbol(), MODE_SPREAD) > InpMaxSpreadPoints)
     {
      Print("RECOVERY GAP BLOCKED | Spread=", MarketInfo(Symbol(), MODE_SPREAD),
            " > MaxSpread=", InpMaxSpreadPoints);
      return(false);
     }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   // SAR signal price side filter is NOT applied to RECOVERY_GAP orders.
   // Recovery ladder must follow adverse price gaps independently.

   double lot = NormalizeLot(InpRecoveryGapLot);
   int nextRecoveryNumber = CountRecoveryGapOrdersByDirection(direction) + 1;
   double requiredGapForComment = InpRecoveryGapRawPrice * nextRecoveryNumber;
   string comment = "RECOVERY_GAP_" + IntegerToString(nextRecoveryNumber) +
                    "_GAP_" + DoubleToString(requiredGapForComment, 0) +
                    "_" + DirectionText(direction);

   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          0,
                          0,
                          comment,
                          InpMagicNumber,
                          0,
                          direction == 1 ? InpBuyColor : InpSellColor);

   if(ticket < 0)
     {
      int err = GetLastError();
      Print("RECOVERY GAP ORDER FAILED | Direction=", DirectionText(direction),
            " | Lot=", DoubleToString(lot, 2),
            " | GapMove=", DoubleToString(gapMove, Digits),
            " | Error=", err);
      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();

   Print("RECOVERY GAP ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | Lot=", DoubleToString(lot, 2),
         " | RecoveryNo=", nextRecoveryNumber,
         " | RequiredGap=", DoubleToString(requiredGapForComment, Digits),
         " | ActualGap=", DoubleToString(gapMove, Digits),
         " | Comment=", comment);

   return(true);
  }

//+------------------------------------------------------------------+
// Return the first/base order price for the recovery ladder.
// BUY: use the highest open BUY price as the base, because recovery starts
//      when price falls from the original BUY.
// SELL: use the lowest open SELL price as the base, because recovery starts
//       when price rises from the original SELL.
bool GetRecoveryLadderBasePrice(int direction, double &basePrice, int &sideOrders)
  {
   basePrice = 0.0;
   sideOrders = 0;

   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      double op = OrderOpenPrice();

      if(sideOrders == 0)
         basePrice = op;
      else
        {
         if(direction == 1 && op > basePrice)
            basePrice = op;

         if(direction == -1 && op < basePrice)
            basePrice = op;
        }

      sideOrders++;
     }

   return(sideOrders > 0);
  }

//+------------------------------------------------------------------+
double GetRecoveryLadderCurrentGap(int direction, double basePrice)
  {
   if(direction == 1)
      return(basePrice - Bid);   // BUY is in loss when Bid is below base

   if(direction == -1)
      return(Ask - basePrice);   // SELL is in loss when Ask is above base

   return(0.0);
  }

//+------------------------------------------------------------------+
double GetNextRecoveryLadderRequiredGap(int direction)
  {
   int recoveryCount = CountRecoveryGapOrdersByDirection(direction);
   return(InpRecoveryGapRawPrice * (recoveryCount + 1));
  }

//+------------------------------------------------------------------+
void ProcessRecoveryGapOrders()
  {
   if(!InpUseRecoveryGapOrders)
      return;

   if(InpRecoveryGapRawPrice <= 0.0 || InpRecoveryGapLot <= 0.0)
      return;

   if(CheckEquityConditions())
      return;

   RefreshRates();

   double buyBase = 0.0;
   double sellBase = 0.0;
   int buyOrders = 0;
   int sellOrders = 0;

   bool hasBuy = GetRecoveryLadderBasePrice(1, buyBase, buyOrders);
   bool hasSell = GetRecoveryLadderBasePrice(-1, sellBase, sellOrders);

   int buyRecoveryCount = CountRecoveryGapOrdersByDirection(1);
   int sellRecoveryCount = CountRecoveryGapOrdersByDirection(-1);

   double buyGap = hasBuy ? GetRecoveryLadderCurrentGap(1, buyBase) : 0.0;
   double sellGap = hasSell ? GetRecoveryLadderCurrentGap(-1, sellBase) : 0.0;

   double buyRequiredGap = GetNextRecoveryLadderRequiredGap(1);     // 50, 100, 150
   double sellRequiredGap = GetNextRecoveryLadderRequiredGap(-1);   // 50, 100, 150

   bool buyReady = (hasBuy && buyGap >= buyRequiredGap &&
                    buyRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                    !IsStrongOppositeMoveAgainstRecovery(1, buyGap));

   bool sellReady = (hasSell && sellGap >= sellRequiredGap &&
                     sellRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                     !IsStrongOppositeMoveAgainstRecovery(-1, sellGap));

   // Open only one recovery gap order per tick. Choose the side with the larger adverse move.
   if(buyReady && (!sellReady || buyGap >= sellGap))
     {
      Print("RECOVERY LADDER READY | BUY | Base=", DoubleToString(buyBase, Digits),
            " | CurrentGap=", DoubleToString(buyGap, Digits),
            " | RequiredGap=", DoubleToString(buyRequiredGap, Digits),
            " | RecoveryCount=", buyRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      OpenRecoveryGapMarketOrder(1, buyGap);
      return;
     }

   if(sellReady)
     {
      Print("RECOVERY LADDER READY | SELL | Base=", DoubleToString(sellBase, Digits),
            " | CurrentGap=", DoubleToString(sellGap, Digits),
            " | RequiredGap=", DoubleToString(sellRequiredGap, Digits),
            " | RecoveryCount=", sellRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      OpenRecoveryGapMarketOrder(-1, sellGap);
      return;
     }
  }

//+------------------------------------------------------------------+
void ProcessSARFlipStateAndClose()
  {

    if(!isCloseOrderOnSARChangeEnabled)
    return ;
   int sarFlip = GetSARFlipSignal();

   if(sarFlip == 0 || sarFlip == g_activeSARDirection)
      return;

   int oldDirection = g_activeSARDirection;

// 1) Close old SAR direction orders first.
// Example: old BUY -> SAR changed SELL -> close BUY immediately.
   if(oldDirection != 0)
      CloseOrdersByDirection(oldDirection, "SAR signal changed");

// 2) Update SAR direction.
   g_activeSARDirection  = sarFlip;
   g_lastSARDotDirection = sarFlip;
   g_sarPausedByEarly    = false;
   g_earlyDirection      = 0;

// Reset per-signal total order counter. This is where max order count restarts.
   ResetSARSignalOrderCycle(sarFlip, "SAR signal changed");

// 3) Start confirmation only for next new order.
   StartSARFlipConfirmation(sarFlip);

   Print("SAR CHANGED | Old=", DirectionText(oldDirection),
         " New=", DirectionText(sarFlip),
         " | Old direction orders closed");
  }

//+------------------------------------------------------------------+
void UpdateEarlyTrendVisualState(int early)
  {
   if(early == 0)
      return;

   if(early != g_earlyDirection)
     {
      g_earlyDirection = early;

      if(InpDrawEarlyArrows && Time[1] != g_lastEarlyArrowTime)
        {
         DrawSignalArrow("EARLY", early, Time[1], early == 1 ? Low[1] : High[1], true);
         g_lastEarlyArrowTime = Time[1];
        }
     }
  }

//+------------------------------------------------------------------+
void CloseOrdersByDirectionAnyMagic(int direction, string reason, bool anyMagic)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(!anyMagic && OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;
      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);

      if(!ok)
        {
         int err = GetLastError();
         Print("EARLY CLOSE FAILED | Ticket=", OrderTicket(),
               " | Magic=", OrderMagicNumber(),
               " | Reason=", reason,
               " | Error=", err);
         ResetLastError();
        }
      else
        {
         Print("EARLY CLOSE OK | Ticket=", OrderTicket(),
               " | Magic=", OrderMagicNumber(),
               " | Reason=", reason);
        }
     }
  }


//+------------------------------------------------------------------+
//| Early SAR weak exit: detect dying SAR before full SAR flip        |
//+------------------------------------------------------------------+
int GetEarlySARWeaknessScore(int direction, string &reason)
  {
   reason = "";

   if(direction == 0 || Bars < 50)
      return(0);

   double atr = GetDynamicSARATR();
   if(atr <= 0.0)
      return(0);

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1    = iSAR(Symbol(), Period(), step, maxstep, 1);

   double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema21   = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double adx1    = iADX(Symbol(), Period(), InpSARGoodMomentumADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double adx2    = iADX(Symbol(), Period(), InpSARGoodMomentumADXPeriod, PRICE_CLOSE, MODE_MAIN, 2);

   double dotDistance = MathAbs(Close[1] - sar1);
   int weakness = 0;

   // 1) Price crosses EMA21 against active SAR.
   if(direction == 1 && Close[1] < ema21)
     {
      weakness++;
      reason += "Close<EMA21 ";
     }
   if(direction == -1 && Close[1] > ema21)
     {
      weakness++;
      reason += "Close>EMA21 ";
     }

   // 2) EMA9/EMA21 turns against active SAR.
   if(direction == 1 && emaFast < emaSlow)
     {
      weakness++;
      reason += "EMA Bearish ";
     }
   if(direction == -1 && emaFast > emaSlow)
     {
      weakness++;
      reason += "EMA Bullish ";
     }

   // 3) Last 3 closed candles press against SAR.
   int oppositeCandles = CountDirectionalCandles(-direction, 3);
   if(oppositeCandles >= 2)
     {
      weakness++;
      reason += "OppCandles=" + IntegerToString(oppositeCandles) + " ";
     }

   // 4) SAR dot becomes too close to price: current SAR is losing space.
   if(dotDistance <= atr * InpDynamicWeakDotATRMultiplier)
     {
      weakness++;
      reason += "DotNear ";
     }

   // 5) ADX is weak or falling: trend strength is dying.
   if(adx1 < InpDynamicADXWeak || adx1 < adx2)
     {
      weakness++;
      reason += "ADXWeak/Fall ";
     }

   // 6) Big/long candle against SAR: senior-trader exit clue.
   if(HasOppositeLongBarDanger(direction, atr))
     {
      weakness += 2;
      reason += "OppLongBar ";
     }

   // 7) Dynamic SAR score itself is weak.
   int dynScore = GetDynamicSARStrengthScore(direction);
   if(dynScore <= InpDynamicWeakScore)
     {
      weakness++;
      reason += "DynWeak=" + IntegerToString(dynScore) + " ";
     }

   return(weakness);
  }

//+------------------------------------------------------------------+
bool IsEarlySARWeakExitSignal(int direction, double basketProfit, string &reason)
  {
   reason = "";
   g_earlySARWeakExitActive = false;
   g_earlySARWeakExitReason = "";

   if(!InpUseEarlySARWeakExit || direction == 0)
      return(false);

   if(CountOrdersByDirection(direction) <= 0)
      return(false);

   int ageMin = GetSARSignalAgeMinutes();
   if(ageMin < InpEarlySARWeakExitMinAgeMin)
      return(false);

   if(g_lastEarlySARWeakExitTime > 0 &&
      TimeCurrent() - g_lastEarlySARWeakExitTime < InpEarlySARWeakExitCooldownSec &&
      g_lastEarlySARWeakExitDirection == direction)
      return(false);

   // Track basket peak profit to detect profit giving back before SAR flip.
   if(g_sarCycleDirection != direction || CountOrdersByDirection(direction) <= 0)
      g_activeBasketPeakProfit = basketProfit;
   else
      g_activeBasketPeakProfit = MathMax(g_activeBasketPeakProfit, basketProfit);

   string weakReason = "";
   int weakness = GetEarlySARWeaknessScore(direction, weakReason);

   int oppositePressureCandles = CountOppositeCandlesForWeakExit(direction);
   bool candleWeakExit =
      (InpUseOppositeCandleWeakExit &&
       oppositePressureCandles >= MathMax(1, InpWeakExitOppositeMinCandles));

   if(candleWeakExit)
     {
      weakness += 2;
      weakReason += "OppPressure=" + IntegerToString(oppositePressureCandles) +
                    "/" + IntegerToString(InpWeakExitCandleLookback) + " ";
     }

   bool enoughWeakness = (weakness >= InpEarlySARWeakExitNeedSignals);
   bool profitClose    = (basketProfit >= InpEarlySARWeakExitMinProfitUSD);
   bool lossClose      = (basketProfit <= -MathAbs(InpEarlySARWeakExitMaxLossUSD));
   bool trailClose     = (g_activeBasketPeakProfit >= InpEarlySARWeakExitMinProfitUSD &&
                          basketProfit <= g_activeBasketPeakProfit - MathAbs(InpEarlySARWeakExitTrailUSD));
   bool candlePressureClose =
      (candleWeakExit && basketProfit >= -MathAbs(InpEarlySARWeakExitMaxLossUSD));

   if(!enoughWeakness)
      return(false);

   reason = "Weakness=" + IntegerToString(weakness) +
            " | Profit=$" + DoubleToString(basketProfit, 2) +
            " | Peak=$" + DoubleToString(g_activeBasketPeakProfit, 2) +
            " | " + weakReason;

   g_earlySARWeakExitActive = true;
   g_earlySARWeakExitReason = reason;

   // If basket is between small profit and controlled loss, only stop adding orders.
   // Close only when profit is available, controlled max-loss is hit, or profit is giving back.
   if(profitClose || lossClose || trailClose || candlePressureClose)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
bool ProcessCloseOrdersFirst(string &status)
  {
   if(g_activeSARDirection == 0)
     {
      status = "Waiting for first SAR";
      return(false);
     }

// PRIORITY 1: Early trend reverse close.
// This runs before SAR confirmation, flat mode, basket TP/SL, order count, cooldown, or new-order checks.
   if(InpUseEarlyTrend)
     {
      int early = DetectEarlyTrend();
      UpdateEarlyTrendVisualState(early);

      if(early != 0 && early != g_activeSARDirection)
        {
         if(!g_sarPausedByEarly)
           {
            Print("EARLY REVERSE PRIORITY CLOSE | Early=", DirectionText(early),
                  " | ActiveSAR=", DirectionText(g_activeSARDirection),
                  " | AnyMagic=", (InpEarlyCloseAnyMagicOrders ? "YES" : "NO"));
           }

         g_sarPausedByEarly = true;
         ResetSARFlipConfirmation(); // pending SAR confirmation must not block early close

         if(InpCloseOnEarlyReverse)
           {
            CloseOrdersByDirectionAnyMagic(g_activeSARDirection,
                                           "Early reverse priority close",
                                           InpEarlyCloseAnyMagicOrders);

            // After early reverse close, open recovery order in early trend direction.
            OpenRecoveryOrder(early, "Early reverse trend close");
           }

         status = "EARLY REVERSE CLOSED " + DirectionText(g_activeSARDirection);
         return(true);
        }

      if(early != 0 && early == g_activeSARDirection && g_sarPausedByEarly)
        {
         g_sarPausedByEarly = false;
         Print("EARLY TREND BACK TO SAR | Resume SAR orders. Direction=", DirectionText(g_activeSARDirection));
        }
     }

// PRIORITY 2: Early SAR weak exit before full SAR flip.
// This is the main protection for: "many orders close only on SAR signal change and lose".
   double activeProfit = GetBasketProfit(g_activeSARDirection);

   string weakExitReason = "";
   bool shouldCloseWeakBasket = IsEarlySARWeakExitSignal(g_activeSARDirection, activeProfit, weakExitReason);

   if(g_earlySARWeakExitActive)
     {
      Print("EARLY SAR WEAK EXIT DETECTED | Direction=", DirectionText(g_activeSARDirection),
            " | ", weakExitReason);

      if(shouldCloseWeakBasket && InpCloseBasketOnSARWeakExit)
        {
         int oldDirection = g_activeSARDirection;
         CloseOrdersByDirection(oldDirection, "Early SAR weak exit: " + weakExitReason);
         g_lastEarlySARWeakExitTime = TimeCurrent();
         g_lastEarlySARWeakExitDirection = oldDirection;
         g_activeBasketPeakProfit = 0.0;

         status = "EARLY SAR WEAK EXIT CLOSED";
         return(true);
        }
     }

// PRIORITY 3: Basket stop loss / basket profit close.
   if(InpBasketStopLossUSD > 0.0 && activeProfit <= -InpBasketStopLossUSD)
     {
      int oldDirection = g_activeSARDirection;
      CloseOrdersByDirection(oldDirection,
                             "Basket stop loss $" + DoubleToString(activeProfit, 2));

      // Stop loss means the current SAR cycle gets a fresh normal limit.
      // This ignores the previous SAR duration restriction until the next SAR signal change.
      ResetSARSignalOrderCycleToNormalAfterStopLoss(oldDirection, "Basket stop loss hit");

      int recoveryDirection = oldDirection;
      if(InpRecoveryAfterSLReverse)
         recoveryDirection = -oldDirection;

      OpenRecoveryOrder(recoveryDirection, "Basket stop loss close");

      Print("BASKET STOP LOSS HIT | Direction=", DirectionText(oldDirection),
            " | Loss=$", DoubleToString(activeProfit, 2),
            " | Limit=$", DoubleToString(InpBasketStopLossUSD, 2));

      status = "Basket SL hit";
      return(true);
     }

   double basketTarget = GetBasketProfitTargetUSD();

   // Basket TP must be checked against the full active-direction basket profit.
   // Do NOT divide target by open order count.
   // Example: InpBasketProfitUSD = 2.00 means close BUY basket only when BUY basket profit >= $2.00.
   if(CountOrdersByDirection(g_activeSARDirection) > 0 && activeProfit >= basketTarget)
     {
      CloseOrdersByDirection(g_activeSARDirection,
                             "Basket profit $" + DoubleToString(activeProfit, 2));

      Print("BASKET PROFIT HIT | Direction=", DirectionText(g_activeSARDirection),
            " | Profit=$", DoubleToString(activeProfit, 2),
            " | Target=$", DoubleToString(basketTarget, 2));

      status = "Basket profit booked";
      return(true);
     }

   return(false);
  }
void IncreaseSARMaxIfTrendContinuesAfterOneHour()
{
   if(!InpIncreaseSARMaxAfterActiveMinutes)
      return;

   if(g_sarCycleDirection == 0 || g_sarCycleStartTime <= 0)
      return;

   int h1Trend = GetH1TrendDirection1();

   if(h1Trend != g_sarCycleDirection)
      return;

   int activeMinutes = (int)((TimeCurrent() - g_sarCycleStartTime) / 60);

   if(activeMinutes < InpSARActiveMinutesForExtraOrders)
      return;

   int normalMax = MathMax(0, InpSARNormalDurationMaxOrders);

   // Example:
   // 60 min  = normal + base extra
   // 90 min  = normal + base extra + 1
   // 120 min = normal + base extra + 2
   // 150 min = normal + base extra + 3
   // 180 min = normal + base extra + 4

   int extraOrders = MathMax(0, InpSARActiveExtraOrders);

   if(activeMinutes > InpSARActiveMinutesForExtraOrders)
   {
      int extraBlocks =
         (activeMinutes - InpSARActiveMinutesForExtraOrders) / 30;

      extraOrders += extraBlocks;
   }

   int newMax = normalMax + extraOrders;

   if(g_sarCycleMaxOrders < newMax)
   {
      int oldMax = g_sarCycleMaxOrders;
      g_sarCycleMaxOrders = newMax;

      Print("SAR TREND CONTINUED - PROGRESSIVE EXTRA ORDERS | Direction=",
            DirectionText(g_sarCycleDirection),
            " | H1=", DirectionText(h1Trend),
            " | ActiveMinutes=", activeMinutes,
            " | ExtraOrders=", extraOrders,
            " | OldMax=", oldMax,
            " | NewMax=", g_sarCycleMaxOrders);
   }
}

//+------------------------------------------------------------------+
bool ProcessNewOrderCreationLast(bool isNewBar, string &status)
  {
   if(g_activeSARDirection == 0)
     {
      status = "Waiting for first SAR";
      return(false);
     }

// No-trading hours block ONLY new normal SAR orders.
// Close management, equity protection, basket TP/SL, SAR flip close and recovery management still run.
   if(IsNoNewOrderHour())
     {
      status = "NO NEW ORDERS HOUR - " + InpNoNewOrderHourList;
      return(false);
     }

// Big candle pause blocks ONLY new orders. Close/profit/protection logic still runs first.
   if(IsBigCandlePauseActive())
     {
      status = "BIG CANDLE PAUSE - " + BigCandlePauseStatusText();
      return(false);
     }

// Early SAR weak exit blocks ONLY new normal orders. Close management already ran first.
   if(InpUseEarlySARWeakExit && InpStopNewOrdersOnSARWeakExit && g_earlySARWeakExitActive)
     {
      status = "SAR WEAK - STOP NEW ORDERS";
      Print("NEW ORDER BLOCKED BY EARLY SAR WEAK EXIT | Direction=",
            DirectionText(g_activeSARDirection), " | ", g_earlySARWeakExitReason);
      return(false);
     }

// Pending SAR confirmation blocks ONLY new orders. It cannot block close management.
   if(g_pendingSARConfirmDirection != 0)
     {
      if(!IsSARFlipConfirmationReady())
        {
         status = "WAIT SAR CONFIRM " + DirectionText(g_pendingSARConfirmDirection) +
                  " " + SARConfirmDurationStatusText();
         return(false);
        }

      Print("SAR CONFIRMED | Direction=", DirectionText(g_pendingSARConfirmDirection),
            " | FlipPrice=", DoubleToString(g_pendingSARConfirmPrice, Digits),
            " | Close[1]=", DoubleToString(Close[1], Digits));

      ResetSARFlipConfirmation();
     }

// Dynamic BTC SAR quality gate. SAR still gives direction, but weak/fast/fake flips do not open new normal orders.
   string dynamicBlockReason = "";
   if(!IsDynamicSARAllowedForNewOrder(g_activeSARDirection, dynamicBlockReason))
     {
      status = "DYNAMIC SAR BLOCK - " + dynamicBlockReason;
      Print("DYNAMIC SAR NEW ORDER BLOCKED | Direction=", DirectionText(g_activeSARDirection),
            " | Reason=", dynamicBlockReason,
            " | Age=", GetSARSignalAgeMinutes(), "m",
            " | Score=", g_dynamicSARScore,
            " | ATR=", DoubleToString(g_dynamicSARATR, 2),
            " | DotDistance=", DoubleToString(g_dynamicSARDotDistance, 2),
            " | ADX=", DoubleToString(g_dynamicSARADX, 2));
      return(false);
     }

// Flat mode blocks ONLY new orders. It cannot block close management.
   if(InpUseFlatMode)
     {
      g_flatMode = DetectFlatMode();
      if(g_flatMode)
        {
         if(InpDrawFlatDots && Time[1] != g_lastFlatDotTime)
           {
            DrawFlatDot(Time[1], (High[1] + Low[1]) / 2.0);
            g_lastFlatDotTime = Time[1];
           }

         status = "FLAT MODE - WAIT BREAKOUT";
         return(false);
        }
     }
   else
     {
      g_flatMode = false;
     }

   if(g_sarPausedByEarly)
     {
      status = "Paused by early reverse";
      return(false);
     }

   EnsureSARSignalOrderCycle(g_activeSARDirection);
   // ResetSARMaxToNormalIfActiveLongEnough();
   IncreaseSARMaxIfTrendContinuesAfterOneHour();
IncreaseSARMaxWhenDotDistanceAndH1Same();

// UpgradeSARCycleMaxIfGoodMomentum(g_activeSARDirection, "before new SAR order");
   UpdateSARCycleMaxByMomentum(g_activeSARDirection, "before new SAR order");

   if(TryOpenEarlySameSARExtraOrder())
{
   status = "EARLY SAME SAR EXTRA ORDER";
   return true;
}

   if(!IsOrderAllowedByH1Trend(g_activeSARDirection)  && !IsCurrentSARGoodMomentum(g_activeSARDirection))
     {
      status = "BLOCKED:SAR REV H1 "+DirectionText(GetH1TrendDirection());
      Print("ORDER BLOCKED | SAR reverse against H1 trend | Direction=", DirectionText(g_activeSARDirection));
      return(false);
     }

   int dynamicMaxOrders = g_sarCycleMaxOrders;
   int cycleOrders      = g_sarCycleOrdersCreated;

   if(dynamicMaxOrders <= 0)
     {
      status = "SAR CYCLE Immidiate change MAX BLOCK - MAX 0";
      Print("ORDER BLOCKED | SAR cycle max is 0 | Direction=", DirectionText(g_activeSARDirection),
            " | Last5=", GetSARDurationSummaryText());
      return(false);
     }

   if(cycleOrders >= dynamicMaxOrders)
     {
      status = "SAR CYCLE MAX " + IntegerToString(cycleOrders) + "/" + IntegerToString(dynamicMaxOrders);
      return(false);
     }

// if(InpOneOrderPerBar && !isNewBar)
// {
//    status = "Waiting new bar";
//    return(false);
// }

   if(!IsSARSignalPriceSideAllowed(g_activeSARDirection, "Normal SAR order"))
     {
      status = "SAR PRICE SIDE BLOCK";
      return(false);
     }

   if(!CanOpenNewOrder(g_activeSARDirection))
     {
      status = "Order gate blocked";
      return(false);
     }

   if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_V2LAST"))
      status = "Active " + DirectionText(g_activeSARDirection);
   else
      status = "OrderSend failed";

      Print("NEW ORDER CHECKS PASSED | Direction=", DirectionText(g_activeSARDirection),
            " | CycleOrders=", cycleOrders,
            " | MaxOrders=", dynamicMaxOrders,
            " | Last5=", GetSARDurationSummaryText());

   return(true);
  }
  void DrawEMATrendLines()
{
   DrawEMALine("DXB_EMA_FAST", InpFastEMA, clrLime, 2);
   DrawEMALine("DXB_EMA_SLOW", InpSlowEMA, clrRed, 2);
   DrawEMALine("DXB_EMA_H1_FAST", InpH1FastEMA, clrAqua, 1);
   DrawEMALine("DXB_EMA_H1_SLOW", InpH1SlowEMA, clrOrange, 1);
}

void DrawEMALine(string name, int period, color clr, int width)
{
   int lookback = 100;

   for(int i = lookback; i >= 1; i--)
   {
      string objName = name + "_" + IntegerToString(i);

      double ema1 = iMA(Symbol(), Period(), period, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema2 = iMA(Symbol(), Period(), period, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      datetime t1 = Time[i];
      datetime t2 = Time[i - 1];

      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_TREND, 0, t1, ema1, t2, ema2);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, width);
         ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      }
      else
      {
         ObjectMove(0, objName, 0, t1, ema1);
         ObjectMove(0, objName, 1, t2, ema2);
      }
   }
}

//+------------------------------------------------------------------+
void OnTick()
  {




   // if(!IsTesting())
   //   {


   //    if(AccountNumber() != 289052334 &&
   //       AccountNumber() != 291058458)
   //      {
   //       // Print("Unauthorized Account: ", AccountNumber());
   //       return;
   //      }
   //   }





   RefreshRates();

// Deposit reset uses the same equity reset method as fixed hours (1,7,13,19).
// Closed trade profit will not trigger this because only OP_BALANCE is checked.
   CheckDepositAndResetEquityStats();

// Equity protection may close all EA orders and intentionally stop processing.
   if(CheckEquityConditions())
     {
      if(g_dailyProfitLock)
         DrawDashboard("DAILY PROFIT LOCK - PAUSED");
      else
         DrawDashboard("EQUITY PROTECTION - PAUSED");
      return;
     }

// Recovery order profit close must run before all signal/new-order logic.
   CloseRecoveryOrdersAtProfit();

// Recovery gap orders are independent from normal SAR order gates.
// Ladder from first/base order price:
// BUY adverse move: 50 => recovery #1, 100 => #2, 150 => #3.
// SELL adverse move: 50 => recovery #1, 100 => #2, 150 => #3.
   ProcessRecoveryGapOrders();

   DrawSARDots();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
     {
      g_lastBarTime = Time[0];
      LoadLast5SARChangeDurations();
     }

   CheckBigCandlePauseOnNewBar(isNewBar);

   string status = "RUNNING";

// SECTION 1: Signal state update. No new orders here.
   UpdateBarAndSARVisualState(isNewBar);
   ProcessSARFlipStateAndClose();

// SECTION 2: Close management FIRST. No new-order gate is allowed before this.
   bool closedThisTick = ProcessCloseOrdersFirst(status);

// SECTION 3: New order creation LAST. Runs only if nothing closed this tick.
   if(!closedThisTick)
      ProcessNewOrderCreationLast(isNewBar, status);
      
      DrawEMATrendLines();
 

   DrawDashboard(status);
  }

//+------------------------------------------------------------------+
void ResetSARFlipConfirmation()
  {
   g_pendingSARConfirmDirection = 0;
   g_pendingSARConfirmPrice     = 0.0;
   g_pendingSARConfirmTime      = 0;
   g_pendingSARConfirmBarTime   = 0;
  }


//+------------------------------------------------------------------+
int GetSARConfirmElapsedSeconds()
  {
   if(g_pendingSARConfirmTime <= 0)
      return(0);

   int elapsed = (int)(TimeCurrent() - g_pendingSARConfirmTime);
   if(elapsed < 0)
      elapsed = 0;

   return(elapsed);
  }

//+------------------------------------------------------------------+
int GetSARConfirmRemainingSeconds()
  {
   int requiredSeconds = MathMax(0, InpSARConfirmMinutes) * 60;
   int remaining = requiredSeconds - GetSARConfirmElapsedSeconds();

   if(remaining < 0)
      remaining = 0;

   return(remaining);
  }

//+------------------------------------------------------------------+
double GetSARConfirmCurrentPriceDiff()
  {
   if(g_pendingSARConfirmDirection == 0 || g_pendingSARConfirmPrice <= 0.0)
      return(0.0);

   if(g_pendingSARConfirmDirection == 1)
      return(Close[1] - g_pendingSARConfirmPrice);

   if(g_pendingSARConfirmDirection == -1)
      return(g_pendingSARConfirmPrice - Close[1]);

   return(0.0);
  }

//+------------------------------------------------------------------+
string SARConfirmDurationStatusText()
  {
   if(g_pendingSARConfirmDirection == 0 || g_pendingSARConfirmTime <= 0)
      return("NONE");

   int elapsedSec = GetSARConfirmElapsedSeconds();
   int remainSec  = GetSARConfirmRemainingSeconds();

   return(IntegerToString(elapsedSec / 60) + "m / " +
          IntegerToString(MathMax(0, InpSARConfirmMinutes)) + "m" +
          " | Left " + IntegerToString(remainSec / 60) + "m " +
          IntegerToString(remainSec % 60) + "s");
  }

//+------------------------------------------------------------------+
void StartSARFlipConfirmation(int direction)
  {
   if(!InpUseSARFlipConfirmations)
     {
      ResetSARFlipConfirmation();
      return;
     }

   g_pendingSARConfirmDirection = direction;
   g_pendingSARConfirmPrice     = Close[1];     // raw flip reference price
   g_pendingSARConfirmTime      = TimeCurrent();
   g_pendingSARConfirmBarTime   = Time[1];      // SAR flip happened on this closed candle

   // Store the active SAR signal changed price separately. Do not reset this after confirmation.
   g_activeSARSignalChangePrice = g_pendingSARConfirmPrice;
   g_activeSARSignalChangeTime  = g_pendingSARConfirmTime;

   Print("SAR CONFIRMATION STARTED | Direction=", DirectionText(direction),
         " | FlipPrice=", DoubleToString(g_pendingSARConfirmPrice, Digits),
         " | FlipBar=", TimeToString(g_pendingSARConfirmBarTime, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
bool IsSARFlipConfirmationReady()
  {
   if(!InpUseSARFlipConfirmations)
      return(true);

   int direction = g_pendingSARConfirmDirection;
   if(direction == 0)
      return(true);

   if(Bars < 5)//immidiate change protection
      return(false);

// 0) SAR signal change time confirmation.
//    New orders must wait InpSARConfirmMinutes after SAR flip.
   if(InpSARConfirmMinutes > 0)
     {
      int elapsedSeconds  = GetSARConfirmElapsedSeconds();
      int requiredSeconds = InpSARConfirmMinutes * 60;

      if(elapsedSeconds < requiredSeconds)
        {
         Print("SAR CONFIRM WAIT | Time elapsed ",
               IntegerToString(elapsedSeconds / 60), "m ",
               IntegerToString(elapsedSeconds % 60), "s < required ",
               IntegerToString(InpSARConfirmMinutes), "m | Remaining=",
               IntegerToString((requiredSeconds - elapsedSeconds) / 60), "m ",
               IntegerToString((requiredSeconds - elapsedSeconds) % 60), "s");
         return(false);
        }
     }

// 1) EMA9/EMA21 trend filter on the last fully closed candle.
   if(InpUseSAREMAConfirm)
     {
      double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
      double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

      if(direction == 1 && emaFast <= emaSlow)
        {
         Print("SAR CONFIRM WAIT | EMA not BUY | EMA", InpFastEMA, "=",
               DoubleToString(emaFast, Digits), " EMA", InpSlowEMA, "=",
               DoubleToString(emaSlow, Digits));
         return(false);
        }

      if(direction == -1 && emaFast >= emaSlow)
        {
         Print("SAR CONFIRM WAIT | EMA not SELL | EMA", InpFastEMA, "=",
               DoubleToString(emaFast, Digits), " EMA", InpSlowEMA, "=",
               DoubleToString(emaSlow, Digits));
         return(false);
        }
     }

// 2) Wait for one new fully closed candle AFTER the SAR flip candle.
//    This avoids opening on the same candle that created the SAR flip.
   if(InpUseSARClosedCandleConfirm)
     {
      if(Time[1] <= g_pendingSARConfirmBarTime)
        {
         Print("SAR CONFIRM WAIT | Waiting next closed candle after flip bar");
         return(false);
        }

      if(direction == 1 && Close[1] <= Open[1])
        {
         Print("SAR CONFIRM WAIT | Last closed candle not bullish | O=",
               DoubleToString(Open[1], Digits), " C=", DoubleToString(Close[1], Digits));
         return(false);
        }

      if(direction == -1 && Close[1] >= Open[1])
        {
         Print("SAR CONFIRM WAIT | Last closed candle not bearish | O=",
               DoubleToString(Open[1], Digits), " C=", DoubleToString(Close[1], Digits));
         return(false);
        }
     }

// 3) Price difference confirmation from SAR flip reference price.
//    Dynamic mode uses ATR instead of a fixed BTCUSD raw price value.
   if(InpUseSARPriceDiffConfirm)
     {
      double diff = GetSARConfirmCurrentPriceDiff();
      double requiredDiff = InpSARConfirmPriceDiff;

      if(InpUseDynamicSAREngine)
         requiredDiff = GetDynamicSARRequiredConfirmDiff();

      g_dynamicSARRequiredDiff = requiredDiff;

      if(requiredDiff > 0.0 && diff < requiredDiff)
        {
         Print("SAR CONFIRM WAIT | Price diff ",
               DoubleToString(diff, Digits), " < required ",
               DoubleToString(requiredDiff, Digits),
               " | Dynamic=", (InpUseDynamicSAREngine ? "YES" : "NO"));
         return(false);
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
int GetSARFlipSignal()
  {
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2])
      return 1;
   if(sar1 > Close[1] && sar2 <= Close[2])
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
int GetSARDotDirection(int shift)
  {
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar     = iSAR(Symbol(), Period(), step, maxstep, shift);

   if(sar < Close[shift])
      return 1;
   if(sar > Close[shift])
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
double GetDynamicSARATR()
  {
   double atr = iATR(Symbol(), Period(), InpDynamicATRPeriod, 1);
   if(atr <= 0.0)
      atr = iATR(Symbol(), PERIOD_M5, InpDynamicATRPeriod, 1);
   return(atr);
  }

//+------------------------------------------------------------------+
double GetDynamicSARRequiredConfirmDiff()
  {
   if(!InpUseDynamicSAREngine)
      return(InpSARConfirmPriceDiff);

   double atr = GetDynamicSARATR();
   if(atr <= 0.0)
      return(InpSARConfirmPriceDiff);

   double dynamicDiff = atr * InpDynamicConfirmATRMultiplier;

   // Safety: do not allow the dynamic requirement to become almost zero in dead market.
   if(InpSARConfirmPriceDiff > 0.0)
      dynamicDiff = MathMax(dynamicDiff, InpSARConfirmPriceDiff * 0.35);

   return(dynamicDiff);
  }

//+------------------------------------------------------------------+
int CountDirectionalCandles(int direction, int lookback)
  {
   int total = 0;
   int lb = MathMax(1, lookback);

   for(int i = 1; i <= lb; i++)
     {
      if(direction == 1 && Close[i] > Open[i])
         total++;
      if(direction == -1 && Close[i] < Open[i])
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
bool HasOppositeLongBarDanger(int direction, double atr)
  {
   if(direction == 0 || atr <= 0.0)
      return(false);

   double body = MathAbs(Close[1] - Open[1]);
   double range = MathAbs(High[1] - Low[1]);
   int candleDirection = GetClosedCandleDirection(1);

   g_dynamicSARLongBarMove = range;

   if(candleDirection == -direction && range >= atr * InpDynamicOppositeBarATRMultiplier)
      return(true);

   if(candleDirection == -direction && body >= atr * InpDynamicWeakDotATRMultiplier)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
int GetDynamicSARStrengthScore(int direction)
  {
   g_dynamicSARScore        = 0;
   g_dynamicSARDecision     = "WAIT";
   g_dynamicSARDotDistance  = 0.0;
   g_dynamicSARATR          = 0.0;
   g_dynamicSARADX          = 0.0;
   g_dynamicSARLongBarMove  = 0.0;

   if(direction == 0 || Bars < 50)
      return(0);

   double atr = GetDynamicSARATR();
   if(atr <= 0.0)
      return(0);

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1    = iSAR(Symbol(), Period(), step, maxstep, 1);

   double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDistance = MathAbs(emaFast - emaSlow);

   double adx = iADX(Symbol(), Period(), InpSARGoodMomentumADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);

   double dotDistance = MathAbs(Close[1] - sar1);
   double barRange = MathAbs(High[1] - Low[1]);
   int sameColor = CountDirectionalCandles(direction, 3);

   g_dynamicSARDotDistance = dotDistance;
   g_dynamicSARATR = atr;
   g_dynamicSARADX = adx;
   g_dynamicSARLongBarMove = barRange;

   int score = 0;

   // 1) SAR dot must be on correct side.
   if(direction == 1 && sar1 < Close[1]) score++;
   if(direction == -1 && sar1 > Close[1]) score++;

   // 2) SAR dot distance must be meaningful compared with current BTC ATR.
   if(dotDistance >= atr * InpDynamicStrongDotATRMultiplier) score++;

   // 3) EMA9/EMA21 must agree and be separated enough.
   if(direction == 1 && emaFast > emaSlow && emaDistance >= atr * InpDynamicEMADistanceATRMultiplier) score++;
   if(direction == -1 && emaFast < emaSlow && emaDistance >= atr * InpDynamicEMADistanceATRMultiplier) score++;

   // 4) ADX confirms trend strength.
   if(adx >= InpDynamicADXStrong) score++;

   // 5) Candle pressure confirms direction.
   if(sameColor >= 2) score++;

   // 6) Last closed candle should continue in SAR direction.
   if(direction == 1 && Close[1] > Close[2]) score++;
   if(direction == -1 && Close[1] < Close[2]) score++;

   // 7) Long breakout candle in SAR direction is a senior-trader momentum clue.
   int candleDirection = GetClosedCandleDirection(1);
   if(candleDirection == direction && barRange >= atr * InpDynamicLongBarATRMultiplier) score++;

   // Penalties: avoid blind SAR during chop or reversal bars.
   if(dotDistance < atr * InpDynamicWeakDotATRMultiplier) score--;
   if(adx < InpDynamicADXWeak) score--;
   if(HasOppositeLongBarDanger(direction, atr)) score -= 2;

   if(score < 0)
      score = 0;

   g_dynamicSARScore = score;
   return(score);
  }

//+------------------------------------------------------------------+
int GetSARSignalAgeMinutes()
  {
   if(g_sarCycleStartTime <= 0)
      return(0);

   int mins = (int)((TimeCurrent() - g_sarCycleStartTime) / 60);
   if(mins < 0)
      mins = 0;
   return(mins);
  }

//+------------------------------------------------------------------+
bool IsDynamicSARAllowedForNewOrder(int direction, string &whyBlocked)
  {
   whyBlocked = "";

   if(!InpUseDynamicSAREngine)
      return(true);

   int score = GetDynamicSARStrengthScore(direction);
   int ageMinutes = GetSARSignalAgeMinutes();

   bool oppositeLongBarDanger = HasOppositeLongBarDanger(direction, g_dynamicSARATR);

   if(oppositeLongBarDanger)
     {
      g_dynamicSARDecision = "BLOCK OPPOSITE LONG BAR";
      whyBlocked = g_dynamicSARDecision + " | Score=" + IntegerToString(score);
      return(false);
     }

   // Do not follow 5-10 minute SAR flips blindly. Allow early only when BTC momentum is very strong.
   if(InpBlockFastSARFlip)
     {
      if(ageMinutes < InpDynamicVeryStrongMinMinutes)
        {
         g_dynamicSARDecision = "BLOCK FAST SAR";
         whyBlocked = g_dynamicSARDecision + " | Age=" + IntegerToString(ageMinutes) + "m | Score=" + IntegerToString(score);
         return(false);
        }

      if(ageMinutes < InpDynamicMinSignalMinutes && score < InpDynamicVeryStrongScore)
        {
         g_dynamicSARDecision = "WAIT MATURITY";
         whyBlocked = g_dynamicSARDecision + " | Age=" + IntegerToString(ageMinutes) + "m | Score=" + IntegerToString(score);
         return(false);
        }
     }

   if(InpBlockNewOrdersWhenSARWeak && score <= InpDynamicWeakScore)
     {
      g_dynamicSARDecision = "BLOCK WEAK SAR";
      whyBlocked = g_dynamicSARDecision + " | Score=" + IntegerToString(score);
      return(false);
     }

   if(score < InpDynamicStrongScore)
     {
      g_dynamicSARDecision = "WAIT STRONG SAR";
      whyBlocked = g_dynamicSARDecision + " | Score=" + IntegerToString(score) + "/" + IntegerToString(InpDynamicStrongScore);
      return(false);
     }

   g_dynamicSARDecision = "ALLOW STRONG SAR";
   return(true);
  }

//+------------------------------------------------------------------+
bool IsCurrentSARGoodMomentum(int direction)
  {
   g_sarGoodMomentum = false;
   g_sarGoodMomentumDotDistance = 0.0;
   g_sarGoodMomentumADX = 0.0;
   g_sarGoodMomentumATR = 0.0;

   if(!InpUseSARGoodMomentumMaxUpgrade)
      return(false);

   if(direction == 0)
      return(false);

   if(Bars < 20)
      return(false);

   if(InpUseDynamicSAREngine)
     {
      int score = GetDynamicSARStrengthScore(direction);

      g_sarGoodMomentumDotDistance = g_dynamicSARDotDistance;
      g_sarGoodMomentumADX         = g_dynamicSARADX;
      g_sarGoodMomentumATR         = g_dynamicSARATR;
      g_sarGoodMomentum            = (score >= InpDynamicStrongScore);

      return(g_sarGoodMomentum);
     }

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1    = iSAR(Symbol(), Period(), step, maxstep, 1);

   g_sarGoodMomentumDotDistance = MathAbs(Close[1] - sar1);

   double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   g_sarGoodMomentumADX = iADX(Symbol(), Period(), InpSARGoodMomentumADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   g_sarGoodMomentumATR = iATR(Symbol(), Period(), InpSARGoodMomentumATRPeriod, 1);

   bool sarSideOK = false;
   bool emaOK     = false;
   bool priceOK   = false;

   if(direction == 1)
     {
      sarSideOK = (sar1 < Close[1]);
      emaOK     = (emaFast > emaSlow);
      priceOK   = (Close[1] > Close[2]);
     }
   else
      if(direction == -1)
        {
         sarSideOK = (sar1 > Close[1]);
         emaOK     = (emaFast < emaSlow);
         priceOK   = (Close[1] < Close[2]);
        }

   int sameColor = 0;
   int lookback = MathMax(1, InpSARGoodMomentumCandleLookback);

   for(int i = 1; i <= lookback; i++)
     {
      if(direction == 1 && Close[i] > Open[i])
         sameColor++;

      if(direction == -1 && Close[i] < Open[i])
         sameColor++;
     }

   bool dotDistanceOK = (g_sarGoodMomentumDotDistance >= InpSARGoodMomentumMinDotDistance);
   bool adxOK         = (g_sarGoodMomentumADX >= InpSARGoodMomentumMinADX);
   bool atrOK         = (g_sarGoodMomentumATR >= InpSARGoodMomentumMinATR);
   bool candleOK      = (sameColor >= InpSARGoodMomentumMinSameCandles);

   g_sarGoodMomentum = (sarSideOK && dotDistanceOK && emaOK && priceOK && adxOK && atrOK && candleOK);

   return(g_sarGoodMomentum);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSARCycleMaxByMomentum(int direction, string reason)
  {
   if(!InpUseSARGoodMomentumMaxUpgrade)
      return;

   if(direction == 0)
      return;

   EnsureSARSignalOrderCycle(direction);

   int defaultMax = GetDynamicSARMaxOrdersForDirection(direction);
   int boostedMax = defaultMax + MathMax(0, InpSARGoodMomentumExtraOrders);

   bool goodMomentum = IsCurrentSARGoodMomentum(direction);

   if(goodMomentum)
     {
      if(g_sarCycleMaxOrders < boostedMax)
        {
         int oldMax = g_sarCycleMaxOrders;
         g_sarCycleMaxOrders = boostedMax;

         Print("SAR GOOD MOMENTUM EXTRA ORDERS | Direction=", DirectionText(direction),
               " | OldMax=", oldMax,
               " | NewMax=", g_sarCycleMaxOrders,
               " | Extra=", InpSARGoodMomentumExtraOrders,
               " | Created=", g_sarCycleOrdersCreated,
               " | DotDistance=", DoubleToString(g_sarGoodMomentumDotDistance, 2),
               " | ADX=", DoubleToString(g_sarGoodMomentumADX, 2),
               " | ATR=", DoubleToString(g_sarGoodMomentumATR, 2),
               " | Reason=", reason);
        }

      return;
     }

   if(InpResetMaxOrdersWhenSARWeak)
     {
      if(g_sarCycleMaxOrders != defaultMax)
        {
         int oldMax2 = g_sarCycleMaxOrders;
         g_sarCycleMaxOrders = defaultMax;

         Print("SAR WEAK MOMENTUM RESET MAX | Direction=", DirectionText(direction),
               " | OldMax=", oldMax2,
               " | DefaultMax=", g_sarCycleMaxOrders,
               " | Created=", g_sarCycleOrdersCreated,
               " | Reason=", reason);
        }
     }
  }

//+------------------------------------------------------------------+
void UpgradeSARCycleMaxIfGoodMomentum(int direction, string reason)
  {

   UpdateSARCycleMaxByMomentum(direction, reason);


   if(!InpUseSARGoodMomentumMaxUpgrade)
      return;

   if(direction == 0)
      return;

   EnsureSARSignalOrderCycle(direction);

   int normalMax = MathMax(0, InpSARNormalDurationMaxOrders);

   if(normalMax <= 0)
      return;

   if(g_sarCycleMaxOrders >= normalMax)
      return;

   if(!IsCurrentSARGoodMomentum(direction))
      return;

   int oldMax = g_sarCycleMaxOrders;
   g_sarCycleMaxOrders = normalMax;

   Print("SAR GOOD MOMENTUM MAX UPGRADE | Direction=", DirectionText(direction),
         " | OldMax=", oldMax,
         " | NewMax=", g_sarCycleMaxOrders,
         " | Created=", g_sarCycleOrdersCreated,
         " | DotDistance=", DoubleToString(g_sarGoodMomentumDotDistance, 2),
         " | ADX=", DoubleToString(g_sarGoodMomentumADX, 2),
         " | ATR=", DoubleToString(g_sarGoodMomentumATR, 2),
         " | Reason=", reason);
  }
//+------------------------------------------------------------------+
void LoadLast5SARChangeDurations()
  {
   ArrayInitialize(g_sarChangeTimes, 0);
   ArrayInitialize(g_sarChangeDirections, 0);
   ArrayInitialize(g_sarChangeDurationsSeconds, 0);

   int found = 0;
   int previousDirection = 0;

   int maxBars = MathMin(Bars - 2, MathMax(20, InpSARDurationScanBars));

   for(int i = 1; i <= maxBars && found < 5; i++)
     {
      int currentDirection = GetSARDotDirection(i);

      if(currentDirection == 0)
         continue;

      if(previousDirection == 0)
        {
         previousDirection = currentDirection;
         continue;
        }

      if(currentDirection != previousDirection)
        {
         g_sarChangeTimes[found] = Time[i];
         g_sarChangeDirections[found] = currentDirection;

         if(found > 0)
            g_sarChangeDurationsSeconds[found - 1] =
               (int)MathAbs(g_sarChangeTimes[found - 1] - g_sarChangeTimes[found]);

         found++;
         previousDirection = currentDirection;
        }
     }
  }
//+------------------------------------------------------------------+
int GetLastOppositeSARDurationMinutes(int currentDirection)
  {
   if(currentDirection == 0)
      currentDirection = g_activeSARDirection;

   if(currentDirection == 0)
      currentDirection = GetSARDotDirection(1);

   if(currentDirection == 0)
      return(0);

   int oppositeDirection = -currentDirection;

// g_sarChangeDirections[i] is the SAR color/trend direction for duration[i].
// Use only the latest opposite color duration.
   for(int i = 0; i < 5; i++)
     {
      if(g_sarChangeDurationsSeconds[i] <= 0)
         continue;

      if(g_sarChangeDirections[i] == oppositeDirection)
         return(g_sarChangeDurationsSeconds[i] / 60);
     }

   return(0);
  }
//+------------------------------------------------------------------+
int GetDynamicSARMaxOrdersForDirection(int currentDirection)
  {
   if(!InpUseSARDurationDynamicLimit)
      return(MathMax(0, InpSARNormalDurationMaxOrders));

   if(currentDirection == 0)
      currentDirection = g_activeSARDirection;

   if(currentDirection == 0)
      currentDirection = GetSARDotDirection(1);

   int oppositeMinutes = GetLastOppositeSARDurationMinutes(currentDirection);

// No opposite history loaded yet: use default max for new SAR signal.
   if(oppositeMinutes <= 0)
      return(MathMax(0, InpSARNormalDurationMaxOrders));

// Long opposite color restricts only this new reverse color.
// Example: long RED restricts next GREEN; long GREEN restricts next RED.
   if(oppositeMinutes >= InpSARVeryLongDurationMinutes)
      return(MathMax(0, InpSARVeryLongDurationMaxOrders));

   if(oppositeMinutes >= InpSARDurationLongMinutes)
      return(MathMax(0, InpSARLongDurationMaxOrders));

   if(oppositeMinutes >= InpSARDurationMediumMinutes)
      return(MathMax(0, InpSARMediumDurationMaxOrders));

   return(MathMax(0, InpSARNormalDurationMaxOrders));
  }
//+------------------------------------------------------------------+
void ResetSARSignalOrderCycle(int direction, string reason)
  {
   if(direction == 0)
      return;

   g_sarCycleDirection     = direction;
   g_sarCycleMaxOrders     = GetDynamicSARMaxOrdersForDirection(direction);
   g_sarCycleOrdersCreated = 0;
   g_sarCycleStartTime     = TimeCurrent();

   Print("SAR ORDER CYCLE RESET | Direction=", DirectionText(direction),
         " | MaxOrders=", g_sarCycleMaxOrders,
         " | Opposite=", GetOppositeSARDurationSummaryText(),
         " | Reason=", reason);
  }
//+------------------------------------------------------------------+
void ResetSARSignalOrderCycleToNormalAfterStopLoss(int direction, string reason)
  {
   if(direction == 0)
      return;

   g_sarCycleDirection     = direction;
   g_sarCycleMaxOrders     = MathMax(0, InpSARNormalDurationMaxOrders);
   g_sarCycleOrdersCreated = 0;
   g_sarCycleStartTime     = TimeCurrent();

   Print("SAR ORDER CYCLE RESET AFTER STOPLOSS | Direction=", DirectionText(direction),
         " | MaxOrders=", g_sarCycleMaxOrders,
         " | Created=", g_sarCycleOrdersCreated,
         " | Reason=", reason);
  }
//+------------------------------------------------------------------+
void EnsureSARSignalOrderCycle(int direction)
  {
   if(direction == 0)
      return;

   if(g_sarCycleDirection != direction || g_sarCycleStartTime <= 0)
      ResetSARSignalOrderCycle(direction, "cycle sync");
  }
//+------------------------------------------------------------------+
bool RegisterSARCycleOrderCreated(int direction)
  {
   EnsureSARSignalOrderCycle(direction);

   if(g_sarCycleMaxOrders <= 0)
      return(false);

   if(g_sarCycleOrdersCreated >= g_sarCycleMaxOrders)
      return(false);

   g_sarCycleOrdersCreated++;

   Print("SAR CYCLE ORDER COUNT | Direction=", DirectionText(direction),
         " | Created=", g_sarCycleOrdersCreated,
         "/", g_sarCycleMaxOrders);

   return(true);
  }

//+------------------------------------------------------------------+
int GetDynamicSARMaxOrders()
  {
   int currentDirection = g_activeSARDirection;
   if(currentDirection == 0)
      currentDirection = GetSARDotDirection(1);

// If a SAR signal-cycle is active, return the fixed max calculated at signal change.
   if(g_sarCycleDirection == currentDirection && g_sarCycleStartTime > 0)
      return(g_sarCycleMaxOrders);

   return(GetDynamicSARMaxOrdersForDirection(currentDirection));
  }
//+------------------------------------------------------------------+
string GetSARDurationSummaryText()
  {
   string txt = "";

   for(int i = 0; i < 5; i++)
     {
      if(g_sarChangeDurationsSeconds[i] <= 0)
         continue;

      if(txt != "")
         txt += ",";

      txt += DirectionText(g_sarChangeDirections[i]) + ":" +
             IntegerToString(g_sarChangeDurationsSeconds[i] / 60) + "m";
     }

   if(txt == "")
      txt = "loading";

   return(txt);
  }
//+------------------------------------------------------------------+
string GetOppositeSARDurationSummaryText()
  {
   int currentDirection = g_activeSARDirection;
   if(currentDirection == 0)
      currentDirection = GetSARDotDirection(1);

   int oppositeMinutes = GetLastOppositeSARDurationMinutes(currentDirection);

   if(currentDirection == 0)
      return("loading");

   return(DirectionText(-currentDirection) + " " +
          IntegerToString(oppositeMinutes) + "m");
  }
//+------------------------------------------------------------------+
bool DetectFlatMode()
  {
   int lookback = MathMax(2, InpFlatLookbackCandles);
   if(Bars <= lookback + 5)
      return(false);

   double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDistance = MathAbs(emaFast - emaSlow);

   double atr = iATR(Symbol(), Period(), 14, 1);
   if(atr <= 0)
      atr = Point * 100;

   double maxEMADistance = InpFlatMaxEMADistance;
   if(maxEMADistance <= 0.0)
      maxEMADistance = atr * 0.25;

   double maxBodyTotal = InpFlatMaxBodyTotal;
   if(maxBodyTotal <= 0.0)
      maxBodyTotal = atr * 0.80;

   int green = 0;
   int red   = 0;
   double bodyTotal = 0.0;
   double rangeHigh = High[1];
   double rangeLow  = Low[1];

   for(int i = 1; i <= lookback; i++)
     {
      double body = MathAbs(Close[i] - Open[i]);
      bodyTotal += body;

      if(Close[i] > Open[i])
         green++;
      if(Close[i] < Open[i])
         red++;

      if(High[i] > rangeHigh)
         rangeHigh = High[i];
      if(Low[i]  < rangeLow)
         rangeLow  = Low[i];
     }

   double rangeSize = rangeHigh - rangeLow;

   bool emaCompressed = (emaDistance <= maxEMADistance);
   bool smallBodies   = (bodyTotal <= maxBodyTotal);
   bool mixedCandles  = (green <= InpFlatMaxSameColor && red <= InpFlatMaxSameColor);
   bool tightRange    = (rangeSize <= atr * 1.20);

   return(emaCompressed && smallBodies && mixedCandles && tightRange);
  }

//+------------------------------------------------------------------+
void DrawFlatDot(datetime t, double price)
  {
   string name = OBJ_PREFIX + "FLAT_DOT_" + IntegerToString((int)t);
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 108); // circle
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpFlatDotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
int DetectEarlyTrend()
  {
   double emaFast1 = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow1 = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaFast2 = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double emaSlow2 = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool emaBuy  = (emaFast1 > emaSlow1 && emaFast1 >= emaFast2);
   bool emaSell = (emaFast1 < emaSlow1 && emaFast1 <= emaFast2);

   int green = 0, red = 0;
   double totalBody = 0;
   int lookback = MathMax(1, InpEarlyLookbackCandles);

   for(int i = 1; i <= lookback; i++)
     {
      double body = MathAbs(Close[i] - Open[i]);
      totalBody += body;
      if(Close[i] > Open[i])
         green++;
      if(Close[i] < Open[i])
         red++;
     }

   bool bodyOK = (InpMinEarlyBodyMove <= 0.0 || totalBody >= InpMinEarlyBodyMove);

   if(bodyOK && emaBuy  && green >= MathMax(1, lookback - 1))
      return 1;
   if(bodyOK && emaSell && red   >= MathMax(1, lookback - 1))
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//| SAR signal changed price side protection                         |
//+------------------------------------------------------------------+
double GetSARSignalSideLivePrice(int direction)
  {
   RefreshRates();

   if(direction == 1)
      return(Ask);

   if(direction == -1)
      return(Bid);

   return(Close[0]);
  }

//+------------------------------------------------------------------+
double GetSARSignalSidePriceDiff(int direction)
  {
   if(direction == 0 || g_activeSARSignalChangePrice <= 0.0)
      return(0.0);

   double livePrice = GetSARSignalSideLivePrice(direction);

   if(direction == 1)
      return(livePrice - g_activeSARSignalChangePrice);

   if(direction == -1)
      return(g_activeSARSignalChangePrice - livePrice);

   return(0.0);
  }

//+------------------------------------------------------------------+
string SARSignalSideStatusText()
  {
   if(!InpUseSARSignalPriceSideFilter)
      return("OFF");

   if(g_activeSARDirection == 0 || g_activeSARSignalChangePrice <= 0.0)
      return("WAIT SIGNAL PRICE");

   double diff = GetSARSignalSidePriceDiff(g_activeSARDirection);
   double livePrice = GetSARSignalSideLivePrice(g_activeSARDirection);

   return(DirectionText(g_activeSARDirection) +
          " Live=" + DoubleToString(livePrice, Digits) +
          " Signal=" + DoubleToString(g_activeSARSignalChangePrice, Digits) +
          " Diff=" + DoubleToString(diff, 2) +
          " / " + DoubleToString(InpSARSignalPriceSideMinGap, 2));
  }

//+------------------------------------------------------------------+
bool IsSARSignalPriceSideAllowed(int direction, string source)
  {
   if(!InpUseSARSignalPriceSideFilter)
      return(true);

   if(direction == 0)
      return(false);

   if(g_activeSARSignalChangePrice <= 0.0)
     {
      Print("SAR SIGNAL PRICE SIDE BLOCKED | No active SAR signal price | Source=", source,
            " | Direction=", DirectionText(direction));
      return(false);
     }

   double livePrice = GetSARSignalSideLivePrice(direction);
   double diff = GetSARSignalSidePriceDiff(direction);
   double required = MathMax(0.0, InpSARSignalPriceSideMinGap);

   bool ok = (diff >= required);

   if(!ok)
     {
      Print("SAR SIGNAL PRICE SIDE BLOCKED | Source=", source,
            " | Direction=", DirectionText(direction),
            " | SignalPrice=", DoubleToString(g_activeSARSignalChangePrice, Digits),
            " | LivePrice=", DoubleToString(livePrice, Digits),
            " | Diff=", DoubleToString(diff, Digits),
            " | Required=", DoubleToString(required, Digits),
            " | Rule=", direction == 1 ? "BUY live price must be above signal changed price"
                                      : "SELL live price must be below signal changed price");
      return(false);
     }

   return(true);
  }


//+------------------------------------------------------------------+
bool CanOpenNewOrder(int direction)
  {
   if(direction == 0)
      return(false);

   EnsureSARSignalOrderCycle(direction);
// UpgradeSARCycleMaxIfGoodMomentum(direction, "CanOpenNewOrder");
   UpdateSARCycleMaxByMomentum(direction, "CanOpenNewOrder");


// IMPORTANT: this is NOT open order count.
// It is total SAR orders CREATED in the current SAR signal-cycle,
// including orders already closed by basket profit/SL. It resets only on SAR change.
   int cycleCreatedOrders = g_sarCycleOrdersCreated;
   int dynamicMaxOrders   = g_sarCycleMaxOrders;

   if(dynamicMaxOrders <= 0)
     {
      Print("ORDER BLOCKED | SAR cycle max is 0. Symbol=", Symbol(),
            " Direction=", DirectionText(direction),
            " CycleCreated=", cycleCreatedOrders,
            " Last5=", GetSARDurationSummaryText());
      DrawDashboard("SAR CYCLE BLOCK - MAX 0");
      return(false);
     }

   if(cycleCreatedOrders >= dynamicMaxOrders)
     {
      Print("ORDER BLOCKED | SAR signal-cycle max reached. Symbol=", Symbol(),
            " Direction=", DirectionText(direction),
            " CycleCreated=", cycleCreatedOrders,
            " DynamicMax=", dynamicMaxOrders,
            " Last5=", GetSARDurationSummaryText());
      DrawDashboard("SAR " + DirectionText(direction) + " CYCLE MAX " +
                    IntegerToString(cycleCreatedOrders) + "/" +
                    IntegerToString(dynamicMaxOrders));
      return(false);
     }

   if(InpOrderCooldownSeconds > 0 && TimeCurrent() - g_lastOrderTime < InpOrderCooldownSeconds)
      return(false);

   if(InpMinPriceGap > 0.0 && !IsPriceGapValid(direction, InpMinPriceGap))
      return(false);

   return(true);
  }
//+------------------------------------------------------------------+
bool IsPriceGapValid(int direction, double minGap)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;

      if(MathAbs(price - OrderOpenPrice()) < minGap)
         return false;
     }
   return true;
  }
//+------------------------------------------------------------------+
bool OpenMarketOrder(int direction, string reason)
  {

Print("Attempting to open ",reason, "-------------------------------------");

   RefreshRates();

   if(IsTotalOpenOrderCapReached("OpenMarketOrder"))
      return(false);

   if(!IsTradingAllowedNow())
     {
      // DrawDashboard("AUTOTRADING OFF");
         Print("ORDERSEND BLOCKED | Autotrading not allowed now.");
      return(false);
     }

   if(CheckEquityConditions())
     {
      Print("ORDERSEND BLOCKED | Equity/profit lock active. Reason=", reason);
      return(false);
     }

   if(CountOrdersByDirection(direction) >= InpMaxOrders)
     {
      Print("ORDERSEND BLOCKED | Max open orders per direction reached | Direction=",
            DirectionText(direction), " | Open=", CountOrdersByDirection(direction),
            "/", InpMaxOrders, " | Reason=", reason);
      return(false);
     }

   EnsureSARSignalOrderCycle(direction);
// UpgradeSARCycleMaxIfGoodMomentum(direction, "OpenMarketOrder pre-check");
   UpdateSARCycleMaxByMomentum(direction, "OpenMarketOrder pre-check");


   int dynamicMaxOrders = g_sarCycleMaxOrders;
   int cycleOrders      = g_sarCycleOrdersCreated;

// Final safety before OrderSend: count created orders in current SAR signal-cycle,
// not currently open orders. Closed profitable orders are still counted.
   if(dynamicMaxOrders <= 0)
     {
      Print("ORDERSEND BLOCKED | SAR cycle max is 0. Symbol=", Symbol(),
            " Direction=", DirectionText(direction),
            " Reason=", reason,
            " Last5=", GetSARDurationSummaryText());
      DrawDashboard("ORDERSEND BLOCKED - SAR CYCLE MAX 0");
      return(false);
     }

   if(cycleOrders >= dynamicMaxOrders)
     {
      Print("ORDERSEND BLOCKED | SAR signal-cycle max reached. Symbol=", Symbol(),
            " Direction=", DirectionText(direction),
            " CycleCreated=", cycleOrders,
            " DynamicMax=", dynamicMaxOrders,
            " Reason=", reason,
            " Last5=", GetSARDurationSummaryText());
      DrawDashboard("ORDERSEND BLOCKED CYCLE " + IntegerToString(cycleOrders) + "/" + IntegerToString(dynamicMaxOrders));
      return(false);
     }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   if(!IsSARSignalPriceSideAllowed(direction, reason))
      return(false);

   double sl = 0;

   if(InpStopLossPoints > 0)
     {
      if(direction == 1)
         sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else
         sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
     }

     sl=0; // disable SL for now to test pure SAR cycle max logic

   double lot = NormalizeLot(InpFixedLot);

   RefreshRates();
   EnsureSARSignalOrderCycle(direction);
// UpgradeSARCycleMaxIfGoodMomentum(direction, "OrderSend last check");
   UpdateSARCycleMaxByMomentum(direction, "OrderSend last check");


   if(g_sarCycleMaxOrders <= 0 || g_sarCycleOrdersCreated >= g_sarCycleMaxOrders)
     {
      Print("ORDERSEND CANCELLED LAST CHECK | CycleCreated=", g_sarCycleOrdersCreated,
            " DynamicMax=", g_sarCycleMaxOrders,
            " Last5=", GetSARDurationSummaryText());
      return(false);
     }

   if(!IsTradingAllowedNow())
     {
      Print("ORDERSEND CANCELLED LAST CHECK | Autotrading not allowed now.");
      return(false);
     }

   int ticket = OrderSend(Symbol(), type, lot, price, InpSlippage, sl, 0, reason, InpMagicNumber, 0, direction == 1 ? InpBuyColor : InpSellColor);

   if(ticket < 0)
     {
      int err = GetLastError();

     Print("OrderSend FAILED | Symbol=", Symbol(),
         " | Type=", type == OP_BUY ? "BUY" : "SELL",
         " | Lot=", DoubleToString(lot, 2),
         " | Price=", DoubleToString(price, Digits),
         " | Bid=", DoubleToString(Bid, Digits),
         " | Ask=", DoubleToString(Ask, Digits),
         " | Spread=", MarketInfo(Symbol(), MODE_SPREAD),
         " | SL=", DoubleToString(sl, Digits),
         " | Magic=", InpMagicNumber,
         " | Reason=", reason,
         " | Slippage=", InpSlippage,
         " | Error=", err);
      Print("OrderSend failed. Direction=", DirectionText(direction), " Error=", err);
      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();

// Register only normal SAR cycle orders. Recovery orders use OpenRecoveryOrder() and are independent.
   RegisterSARCycleOrderCreated(direction);

   Print("Opened ", DirectionText(direction), " ticket=", ticket,
         " lot=", DoubleToString(lot, 2),
         " reason=", reason,
         " | SARCycleCreated=", g_sarCycleOrdersCreated,
         "/", g_sarCycleMaxOrders,
         " | Last5SAR=", GetSARDurationSummaryText());
   return(true);
  }

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
  {
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   if(lotStep > 0)
      lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
  }
//+------------------------------------------------------------------+
int CountAllOrders()
  {
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
        {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            total++;
        }
     }
   return total;
  }
//+------------------------------------------------------------------+
int CountAllSymbolMarketOrders()
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
        {
         total++;
        }
     }

   return(total);
  }
//+------------------------------------------------------------------+
int CountOrdersByDirection(int direction)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type)
         total++;
     }
   return total;
  }
//+------------------------------------------------------------------+
double GetBasketProfit(int direction)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   double profit = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type)
         profit += OrderProfit() + OrderSwap() + OrderCommission();
     }
   return profit;
  }
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newDirection, string reason)
  {
   int closeType = newDirection == 1 ? OP_SELL : OP_BUY;
   CloseOrdersByType(closeType, reason);
  }
//+------------------------------------------------------------------+
void CloseOrdersByDirection(int direction, string reason)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   CloseOrdersByType(type, reason);
  }
//+------------------------------------------------------------------+
void CloseOrdersByType(int type, string reason)
  {
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;
      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);

      if(!ok)
        {
         int err = GetLastError();
         Print("Close failed. Ticket=", OrderTicket(), " reason=", reason, " error=", err);
         ResetLastError();
        }
      else
        {
         Print("Closed ticket=", OrderTicket(), " reason=", reason);
        }
     }
  }

//+------------------------------------------------------------------+
void DeleteNonEarlySignalArrows()
  {
// Remove old SAR/FIRST/SAR_BAR arrows from previous versions.
// Keeps EARLY arrows, SAR dots, flat dots, and dashboard objects.
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);

      if(StringFind(name, OBJ_PREFIX + "FIRST_SAR_") == 0 ||
         StringFind(name, OBJ_PREFIX + "SAR_FLIP_")  == 0 ||
         StringFind(name, OBJ_PREFIX + "SAR_BAR_")   == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }

//+------------------------------------------------------------------+
void DrawSARDots()
  {
   if(!InpDrawSARDots)
      return;

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   int lookback = MathMin(InpSARDotLookback, Bars - 1);
   if(lookback <= 0)
      return;

   for(int i = 0; i < lookback; i++)
     {
      double sar = iSAR(Symbol(), Period(), step, maxstep, i);
      if(sar <= 0)
         continue;

      string name = OBJ_PREFIX + "SAR_DOT_" + IntegerToString(i);

      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // small dot
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
      else
        {
         ObjectSetInteger(0, name, OBJPROP_TIME, Time[i]);
         ObjectSetDouble(0, name, OBJPROP_PRICE, sar);
        }

      // Color based on SAR position relative to candle close.
      if(sar < Close[i])
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotBuyColor);
         if(i == 0)
            dotColor = 1;
        }
      else
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotSellColor);
         if(i == 0)
            dotColor = -1;
        }
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void DrawSAREveryBarArrowsHistory()
  {
   if(!InpDrawSAREveryBarArrows)
      return;

   int lookback = MathMin(InpSAREveryBarLookback, Bars - 2);
   if(lookback <= 1)
      return;

   for(int i = 1; i <= lookback; i++)
     {
      int direction = GetSARDotDirection(i);
      if(direction == 0)
         continue;

      double price = direction == 1 ? Low[i] : High[i];
      string name = OBJ_PREFIX + "SAR_BAR_" + IntegerToString((int)Time[i]) + "_" + IntegerToString(direction);

      if(ObjectFind(0, name) >= 0)
         continue;

      ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, direction == 1 ? 233 : 234);
      ObjectSetInteger(0, name, OBJPROP_COLOR, direction == 1 ? InpBuyColor : InpSellColor);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }

//+------------------------------------------------------------------+
void DrawSignalArrow(string tag, int direction, datetime t, double price, bool early)
  {
   string name = OBJ_PREFIX + tag + "_" + IntegerToString((int)t) + "_" + IntegerToString(direction);
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, direction == 1 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, early ? (direction == 1 ? InpEarlyBuyColor : InpEarlySellColor) : (direction == 1 ? InpBuyColor : InpSellColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, early ? 2 : 3);
  }
//+------------------------------------------------------------------+
string DirectionText(int direction)
  {
   if(direction == 1)
      return "BUY";
   if(direction == -1)
      return "SELL";
   return "NONE";
  }
//+------------------------------------------------------------------+
void DrawPanel(string name,int x,int y,int w,int h,color bg)
  {
   if(ObjectFind(0,name) < 0)
     {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

      ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,h);

      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
      ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrGray);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLabel(string name,
               string text,
               int x,
               int y,
               color clr,
               int size=9)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   ObjectSetString(0,name,OBJPROP_TEXT,text);

   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
  }

int g_dashRow=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DashRow(string title,string value,color clrText=clrWhite)
  {
   DrawLabel(
      "DXB_ROW_"+IntegerToString(g_dashRow),
      title+" : "+value,
      280,
      20+(g_dashRow*18),
      clrText,
      9
   );

   g_dashRow++;
  }
void IncreaseSARMaxWhenDotDistanceAndH1Same()
{
   if(!InpAddOneOrderWhenSARDistanceH1Same)
      return;

   if(g_sarCycleDirection == 0)
      return;

   int h1Trend = GetH1TrendDirection1();

   if(h1Trend != g_sarCycleDirection)
      return;

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1    = iSAR(Symbol(), Period(), step, maxstep, 1);

   double dotDistance = MathAbs(Close[1] - sar1);

   if(dotDistance < InpSARDistanceExtraOrderMin)
      return;

   int defaultMax = GetDynamicSARMaxOrdersForDirection(g_sarCycleDirection);
   int newMax = defaultMax + MathMax(0, InpSARDistanceExtraOrders);

   if(g_sarCycleMaxOrders < newMax)
   {
      int oldMax = g_sarCycleMaxOrders;
      g_sarCycleMaxOrders = newMax;

      Print("SAR DOT DISTANCE + H1 SAME EXTRA ORDER | Direction=",
            DirectionText(g_sarCycleDirection),
            " | H1=", DirectionText(h1Trend),
            " | DotDistance=", DoubleToString(dotDistance, 2),
            " | OldMax=", oldMax,
            " | NewMax=", g_sarCycleMaxOrders);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawDashboard(string status)
  {
   DrawPanel(
      "DXB_PANEL",
      350,
      20,
      350,
      680,
      clrBlack
   );

   g_dashRow=0;

   DashRow("V2 SAR EA",status,clrYellow);

   Print("DASHBOARD UPDATE | Status=", status,
         " | SAR=", DirectionText(g_activeSARDirection),
         " | Early=", DirectionText(g_earlyDirection),
         " | SAR Paused=", (g_sarPausedByEarly ? "YES" : "NO"),
         " | Flat Mode=", (g_flatMode ? "YES" : "NO"),
         " | EquityCycle=#", IntegerToString(g_equityCycleNumber),
         " | NextReset=", FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()));

// DashRow("--------------------------------","",clrGray);

   DashRow("SAR Direction",
           DirectionText(g_activeSARDirection),
           g_activeSARDirection==1 ? clrLime : clrRed);

   DashRow("EMA Trend",
           DirectionText(g_pendingSARConfirmDirection),
           g_pendingSARConfirmDirection==1 ? clrLime : clrRed);

   DashRow("H1 Trend",
           DirectionText(GetH1TrendDirection()),
           GetH1TrendDirection()==1 ? clrLime : clrRed);

           DashRow("SAR Dot Dist",
           DoubleToString(g_sarGoodMomentumDotDistance, 2),
           g_sarGoodMomentumDotDistance >= InpSARGoodMomentumMinDotDistance ? clrLime : clrOrange);

   DashRow("SAR Momentum",
           IsCurrentSARGoodMomentum(g_activeSARDirection) ? "GOOD" : "WEAK",
           g_sarGoodMomentum ? clrLime : clrOrangeRed);

   DashRow("Big Candle Pause",
           BigCandlePauseStatusText(),
           g_bigCandlePause ? clrOrangeRed : clrLime);

   DashRow("SAR Cycle Count",
           IntegerToString(g_sarCycleOrdersCreated) + "/" + IntegerToString(g_sarCycleMaxOrders),
           g_sarCycleOrdersCreated >= g_sarCycleMaxOrders ? clrOrangeRed : clrLime);

   DashRow("Max Open/Recovery",
           "Open " + IntegerToString(InpMaxOrders) + " | Rec " + IntegerToString(InpMaxRecoveryGapOrdersPerSide),
           clrYellow);

   DashRow("Recovery Gap Step",
           DoubleToString(InpRecoveryGapRawPrice,0) + "," +
           DoubleToString(InpRecoveryGapRawPrice*2,0) + "," +
           DoubleToString(InpRecoveryGapRawPrice*3,0),
           clrAqua);


   DashRow("Pending SAR",
           DirectionText(g_pendingSARConfirmDirection),
           g_pendingSARConfirmDirection == 0 ? clrLime : clrOrange);

   DashRow("SAR Change Min",
           SARConfirmDurationStatusText(),
           g_pendingSARConfirmDirection == 0 ? clrLime : clrOrange);

   DashRow("SAR Price Diff",
           DoubleToString(GetSARConfirmCurrentPriceDiff(), 2) + " / " + DoubleToString(GetDynamicSARRequiredConfirmDiff(), 2),
           GetSARConfirmCurrentPriceDiff() >= GetDynamicSARRequiredConfirmDiff() ? clrLime : clrOrange);

   DashRow("SAR Signal Side",
           SARSignalSideStatusText(),
           (!InpUseSARSignalPriceSideFilter || GetSARSignalSidePriceDiff(g_activeSARDirection) >= MathMax(0.0, InpSARSignalPriceSideMinGap)) ? clrLime : clrOrangeRed);

   DashRow("SAR Score",
           IntegerToString(g_dynamicSARScore) + " / " + IntegerToString(InpDynamicStrongScore) + " | " + g_dynamicSARDecision,
           g_dynamicSARScore >= InpDynamicStrongScore ? clrLime : clrOrange);

   DashRow("SAR Age",
           IntegerToString(GetSARSignalAgeMinutes()) + "m / " + IntegerToString(InpDynamicMinSignalMinutes) + "m",
           GetSARSignalAgeMinutes() >= InpDynamicMinSignalMinutes ? clrLime : clrOrange);

   DashRow("Early SAR Exit",
           g_earlySARWeakExitActive ? "WEAK - PROTECT" : "OFF",
           g_earlySARWeakExitActive ? clrOrangeRed : clrLime);

   DashRow("Basket Peak",
           "$" + DoubleToString(g_activeBasketPeakProfit, 2),
           g_activeBasketPeakProfit > 0 ? clrLime : clrWhite);

   DashRow("Dynamic ATR",
           DoubleToString(g_dynamicSARATR, 2),
           clrWhite);

   DashRow("Early Trend",
           DirectionText(g_earlyDirection),
           clrAqua);

   DashRow("SAR Paused",
           g_sarPausedByEarly ? "YES":"NO",
           g_sarPausedByEarly ? clrOrangeRed : clrLime);

   DashRow("Flat Mode",
           g_flatMode ? "YES":"NO",
           g_flatMode ? clrOrange : clrLime);



   DashRow("Last Candle Move",
           DoubleToString(g_lastBigCandleMove, 2) + " / " + DoubleToString(InpBigCandleRawDifference, 0),
           g_bigCandlePause ? clrOrangeRed : clrWhite);

// DashRow("--------------------------------","",clrGray);

// DashRow("BUY Orders",
//         IntegerToString(CountOrdersByDirection(1)));

   DashRow("BUY Profit",
           "$"+DoubleToString(GetBasketProfit(1),2),
           GetBasketProfit(1)>=0 ? clrLime : clrRed);

// DashRow("SELL Orders",
//         IntegerToString(CountOrdersByDirection(-1)));

   DashRow("SELL Profit",
           "$"+DoubleToString(GetBasketProfit(-1),2),
           GetBasketProfit(-1)>=0 ? clrLime : clrRed);

// DashRow("--------------------------------","",clrGray);

   DashRow("Balance",
           "$"+DoubleToString(AccountBalance(),2),
           clrWhite);

   DashRow("Equity",
           "$"+DoubleToString(AccountEquity(),2),
           clrAqua);

   DashRow("Equity Trail",
           g_globalEquityTrailStatus,
           g_globalEquityTrailLocked ? clrOrangeRed : clrAqua);

   DashRow("Equity Peak",
           "$"+DoubleToString(g_globalEquityPeak,2),
           clrAqua);

   DashRow("Base Balance",
           "$"+DoubleToString(g_baseBalance,2),
           clrWhite);

   DashRow("Loss Stop",
           "$"+DoubleToString(g_lossStopEquityLevel,2),
           clrRed);

   DashRow("Profit Target",
           "$"+DoubleToString(g_profitTargetEquity,2),
           clrLime);

   DashRow("Basket TP",
           "$"+DoubleToString(InpBasketProfitUSD,2),
           clrLime);

   DashRow("Basket SL",
           "$"+DoubleToString(InpBasketStopLossUSD,2),
           clrRed);

   DashRow("Max Open Orders",
           IntegerToString(CountAllOrders()) + "/" + IntegerToString(InpMaxTotalOpenOrders),
           CountAllOrders() >= InpMaxTotalOpenOrders ? clrOrangeRed : clrLime);

   DashRow("Recovery Block",
           "OppGap " + DoubleToString(InpStrongOppMoveBlockRecoveryGap,0),
           clrYellow);

// DashRow("Recovery TP",
//         "$"+DoubleToString(InpRecoveryProfitUSD,2),
//         clrGold);

// DashRow("Recovery Orders",
//         IntegerToString(CountRecoveryOrders()),
//         CountRecoveryOrders() > 0 ? clrOrange : clrLime);

// DashRow("--------------------------------","",clrGray);

// DashRow("Daily Profit",
//         "$"+DoubleToString(GetTodayProfitFromBase(),2),
//         GetTodayProfitFromBase()>=0 ? clrLime : clrRed);

// DashRow("Profit Lock",
//         g_dailyProfitLock ? "ON":"OFF",
//         g_dailyProfitLock ? clrOrange : clrLime);

// DashRow("Symbol Orders",
//         IntegerToString(CountAllSymbolMarketOrders())+
//         "/"+
//         IntegerToString(GetDynamicSARMaxOrders()),
//         clrWhite);

   DashRow("SAR Max Rule",
           "Max " + IntegerToString(GetDynamicSARMaxOrders()),
           GetDynamicSARMaxOrders() <= 0 ? clrRed : clrYellow);



   

   DashRow("ADX / ATR",
           DoubleToString(g_sarGoodMomentumADX, 1) + " / " + DoubleToString(g_sarGoodMomentumATR, 1),
           g_sarGoodMomentum ? clrLime : clrWhite);


   DashRow("SAR Cycle Dir",
           DirectionText(g_sarCycleDirection),
           g_sarCycleDirection == 1 ? clrLime : clrRed);

   DashRow("Opposite SAR",
           GetOppositeSARDurationSummaryText(),
           clrYellow);

   DashRow("SAR Durations",
           GetSARDurationSummaryText(),
           clrAqua);

   DashRow("Equity Cycle",
           "#"+IntegerToString(g_equityCycleNumber),
           clrAqua);

   DashRow("Next Reset",
           FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()),
           clrAqua);

   DashRow("No New Hours",
           NoNewOrderHoursStatusText(),
           IsNoNewOrderHour() ? clrOrangeRed : clrLime);

   DashRow("Early Arrows",
           InpDrawEarlyArrows ? "ON" : "OFF",
           InpDrawEarlyArrows ? clrLime : clrRed);

   DashRow("Notifications",
           InpSendPushNotifications ? "PUSH ON" : "PUSH OFF",
           InpSendPushNotifications ? clrLime : clrRed);

   DashRow("Lot Size",
           DoubleToString(InpFixedLot,2),
           clrWhite);
  }
//+------------------------------------------------------------------+
