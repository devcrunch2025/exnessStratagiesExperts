//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA.mq4                  |
//|  First SAR signal -> continuous orders -> $1 basket profit        |
//|  SAR flip closes opposite orders. Early reverse trend pauses SAR  |
//|  cycle, draws arrows, closes opposite orders, resumes when aligned |
//+------------------------------------------------------------------+

enum MARKET_MODE
{
   MODE_RANGE = 0,
   MODE_HEALTHY_TREND = 1,
   MODE_STRONG_TREND = 2,
   MODE_DANGER = 3
};

MARKET_MODE g_marketMode = MODE_RANGE;
#property strict

// MT4 compatibility: balance/deposit/withdrawal history operation type
#ifndef OP_BALANCE
#define OP_BALANCE 6
#endif
#property version   "1.09"

//======================== INPUTS ====================================
string InpEAName                  = "DXB Version 5 - Specila Order";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 1;     // maximum normal SAR orders per SAR signal cycle
double InpMinGapWhenMaxOrdersMoreThanOne = 100.0; // when InpMaxOrders > 1, enforce at least this raw price gap between same-direction open orders

#define DXB_HARD_MAX_OPEN_ORDERS 6  // absolute safety cap for normal SAR orders per cycle

double InpBasketProfitUSD         = 1.00;
double InpBasketStopLossUSD       = 5.00;    // BASKET stop loss in USD, 0 = disabled. This closes all orders in active SAR direction.

// Simple basket close mode:
// true = close BUY basket and SELL basket only by fixed InpBasketProfitUSD / InpBasketStopLossUSD.
// It disables auto profit/loss adjustments such as combined all-basket profit close,
// basket/individual profit protect, time-decay TP, SAR-weak basket close,
// global equity trailing close, and auto market-flow SL adjustment.
bool   InpUseSimpleSideBasketCloseOnly = true;


//================ AUTO MARKET FLOW MODE ============================
// Mode 1: CONTINUOUS TREND  => follow SAR only, SL $5, no recovery/weak/pullback.
// Mode 2: MEDIUM TREND      => SAR + recovery, SL $10, no weak/pullback.
// Mode 3: MIXED TREND       => SAR + recovery + SAR weak + pullback, SL $10.
// Mode 4: DANGER SPIKE      => pause new orders/recovery/weak/pullback; manage closes only.
bool   InpUseAutoMarketFlowMode        = true;
int    InpMarketFlowLookbackBars       = 60;     // M1 bars used for price-move classification
int    InpMarketFlowProfitHours        = 6;      // history window for profitable order count
int    InpContinuousTrendProfitOrders  = 5;      // one-side profit count required
int    InpContinuousTrendOppProfitMax  = 0;      // opposite-side profit count must be <= this

double InpContinuousTrendMoveRaw       = 500.0;
double InpMediumTrendMinMoveRaw        = 300.0;
double InpMediumTrendMaxMoveRaw        = 600.0;
double InpMixedTrendMinMoveRaw         = 50.0;
double InpMixedTrendMaxMoveRaw         = 300.0;
double InpDangerLast3MoveRaw           = 500.0;

double InpContinuousTrendBasketSLUSD   = 5.00;
double InpMediumTrendBasketSLUSD       = 10.00;
double InpMixedTrendBasketSLUSD        = 10.00;
double InpDangerModeBasketSLUSD        = 5.00;

bool   InpAutoModePauseOrdersInDanger  = true;
bool   InpAutoModeAllowRecoveryMedium  = true;
bool   InpAutoModeAllowRecoveryMixed   = true;
bool   InpAutoModeAllowSARWeakMixed    = false;
bool   InpAutoModeAllowPullbackMixed   = true;

double InpProfitTargetPercent      = 50000.0;//50   // stop trading when equity reaches Base + 100%
double InpLossStopPercent          = 50.0;   // stop trading when equity reaches Base - 50%

double InpBasketProfitUSD_12_17 = 1.00; // profit target during 12,13,14,15,16,17 hours

// Time-decay basket target:
// If no new EA order is created for 30 minutes, close basket faster.
// Example: 0-29 min => InpBasketProfitUSD, 30-59 min => InpBasketProfitUSD/2,
// 60-89 min => InpBasketProfitUSD/3, 90-119 min => InpBasketProfitUSD/4.
bool   InpUseBasketProfitTimeDecay       = false;
int    InpBasketProfitDecayStepMinutes   = 60;
double InpBasketProfitDecayMinMultiplier = 0.10;  // safety floor, 0.10 = minimum 10% of normal target
bool   InpBasketProfitDecayIncludeGuards = false; // false = ignore SAR special guard order time

// Basket profit protection:
// Works like individual profit protect, but for ALL basket, BUY basket, and SELL basket.
// If basket profit first reaches a level and later comes back down, close that basket near protected profit.
bool   InpUseBasketProfitProtect          = false;
bool   InpUseMultiBasketProfitProtect     = false;
double InpBasketProtectActivateUSD_1      = 0.50;
double InpBasketProtectCloseAtUSD_1       = 0.25;
double InpBasketProtectActivateUSD_2      = 1.00;
double InpBasketProtectCloseAtUSD_2       = 0.50;
double InpBasketProtectActivateUSD_3      = 2.00;
double InpBasketProtectCloseAtUSD_3       = 1.00;
double InpBasketProtectActivateUSD_4      = 3.00;
double InpBasketProtectCloseAtUSD_4       = 1.50;
double InpBasketProtectActivateUSD_5      = 5.00;
double InpBasketProtectCloseAtUSD_5       = 2.50;

// Dynamic basket fallback: if no fixed basket level matches,
// close basket when profit falls back to this percent of peak.
// Example: 50 = peak $2.00, close if basket profit falls to $1.00.
double InpBasketDynamicClosePercent       = 50.0;
double InpBasketDynamicMinPeakUSD         = 0.20;

// Individual profit protection:
// If an order first moves into profit and later comes back down, close it near this small profit.
bool   InpUseIndividualProfitProtect      = false;
double InpIndividualProtectActivateUSD    = 0.50;  // order must first reach this profit
double InpIndividualProtectCloseAtUSD     = 0.40;  // then close if profit falls back near this value

// SAR-cycle closed-profit count protection:
// After SAR signal changes this counter resets to 0.
// When 2 profitable normal orders are closed in the same SAR signal,
// the next normal order uses dynamic pullback close = peakProfit / closedProfitCount.
// Example: 2 closed profit orders => close at peak/2. 3 closed => close at peak/3.
bool   InpUseSARClosedProfitCountProtect = true;
int    InpSARClosedProfitCountStart      = 2;

// Multiple individual profit-protect levels.
// Highest reached level is used first.
// Example: peak >= 2.00 closes on pullback to 1.50; peak >= 1.00 closes on pullback to 0.80; peak >= 0.50 closes on pullback to 0.40.
bool   InpUseMultiIndividualProfitProtect = false;
double InpProtectActivateUSD_1 = 0.30;
double InpProtectCloseAtUSD_1  = 0.10;
double InpProtectActivateUSD_2 =0.60;
double InpProtectCloseAtUSD_2  = 0.40;
double InpProtectActivateUSD_3 = 0.80;
double InpProtectCloseAtUSD_3  = 0.50;
double InpProtectActivateUSD_4 = 1.50;
double InpProtectCloseAtUSD_4  = 1.00;
double InpProtectActivateUSD_5 = 1.90;
double InpProtectCloseAtUSD_5  = 1.50;

int    InpIndividualProtectPauseMinutes     = 5;     // wait this many minutes before opening next normal order after profit protect close
bool   InpCloseIfNextCandleNotProfit     = false;  // close order after next closed candle if profit is not above 0

bool   InpOpenRecoveryAfterClose  = false;   // open recovery order after SL/SAR flip/early reverse close
double InpRecoveryProfitUSD       = 2.00;   // close recovery order when this USD profit is reached
bool   InpRecoveryAfterSLReverse  = false;   // true: after basket SL, open opposite direction

// Recovery gap orders: when existing BUY/SELL basket is in loss and price moves against it
// by this raw price gap, open one more same-direction recovery order.
bool   InpUseRecoveryGapOrders    = true;
// Recovery gap orders must follow the current active SAR signal direction.
// Example: active SAR BUY => only BUY recovery gap orders are allowed.
// Active SAR SELL => only SELL recovery gap orders are allowed.
bool   InpRecoveryGapMustMatchSARDirection = true;
// Recovery gap H1 trend filter:
// Recovery gap order is allowed only when H1 trend matches the recovery order direction.
// BUY recovery requires H1 BUY. SELL recovery requires H1 SELL. Range/NONE blocks recovery.
bool   InpRecoveryGapMustMatchH1Trend = false;

// Pending recovery retry:
// If recovery gap was matched but order was blocked by SAR/temporary conditions,
// remember it and keep checking again on later ticks / next SAR signal.
// Useful when price moved strongly against basket, then comes back and SAR aligns again.
bool   InpKeepPendingRecoveryGapAfterBlock = true;
bool   InpOpenPendingRecoveryWhenSARMatches = true;

double InpRecoveryGapRawPrice     = 200.0;   // raw price difference, not points
double InpRecoveryGapLot          = 0.01;
int    InpMaxRecoveryGapOrdersPerSide = 3;  // recovery ladder: 50, 100, 150 from first order price

// Reverse swing order: whenever a RECOVERY_GAP order opens, also open one opposite order.
// Example: BUY recovery opens -> open SELL swing order.
// These reverse swing orders are protected by the same 0.50 -> 0.40 pullback logic.
bool   InpOpenReverseOrderWithRecovery = true;
double InpRecoveryReverseLot           = 0.01;   // 0 or less = use InpRecoveryGapLot

// SAR special guard hedge order:
// When SAR changes and an existing parent order is already losing,
// open one opposite hedge order linked to that parent ticket.
// Guard orders are ignored by normal basket/profit/SL closures and close only when the parent order closes.
bool   InpUseSARSpecialGuardOrder       = false;
double InpSARSpecialGuardLossUSD        = 6.00;//InpBasketStopLossUSD   // parent floating loss must be <= -this value
double InpSARSpecialGuardLotMultiplier  = 2.00;   // 1.0 = same lot as parent order
bool   InpSARSpecialGuardRespectSpread  = false;  // SPECIAL GUARD BYPASSES SPREAD/BIG-CANDLE/SAR/NO-HOUR FILTERS. Kept only for old settings display.
string InpSARSpecialGuardPrefix         = "SAR_SPECIAL_GUARD_ORDER_FOR_";
int    InpMaxSARSpecialGuardOrders      = 10;      // maximum active SAR special guard orders at the same time
double InpSARSpecialGuardExtraLossAfterSAROrder = 1.00; // after SAR_FLIP_V2LAST opens, special guard waits until basket loss <= -(InpSARSpecialGuardLossUSD + this value)
bool   InpSARSpecialGuardRequireSARChange = false;  // false = create guard anytime parent loss reaches trigger, no SAR condition
bool   InpSpecialGuardCloseOnlyInProfit = true;   // true = if parent closes, guard is NOT closed in loss; it waits until profit
double InpSpecialGuardMinProfitToClose = 0.01;    // minimum guard profit required to close after parent is gone

// Explicit order comment tags for stable parent/recovery grouping.
// Normal SAR orders start with SAR_PARENT_.
// Recovery gap orders start with RG_P<parentTicket>_ so guard loss can match the exact parent basket.
string InpSARParentOrderPrefix        = "SAR_PARENT_";
string InpSARRecoveryGapOrderPrefix   = "RG_P";


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


double InpProtectionBufferUSD      = 0.00;   // optional buffer below loss-stop level
bool   InpCloseOrdersOnEquityHit    = true;

bool   InpUseDailyProfitLock        = false;
bool   InpCloseOrdersOnProfitLock   = false;
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
string InpNoNewOrderHourList      = "12,13,18,19,22,23";//"0,23";//"13,14,15,16,17,18"; // server-time hours to block new orders




//profit booking hours are 4,5,6,7,8

// Big candle pause protection
// Blocks normal SAR orders, SAR_FLIP_V2LAST, recovery orders, recovery-gap orders, recovery hedge orders, and current forming spike candles.
bool   InpUseBigCandlePause       = true;     // pause new orders after very large candle
double InpBigCandleRawDifference  = 300;    // raw BTCUSD price difference: High[1]-Low[1]
int    InpBigCandlePauseMinutes   = 15;       // pause duration after big candle
bool   InpUseBigCandleFormationBlock = true; // block orders while current candle is forming as a spike/big candle: High[0]-Low[0]
bool   InpNotifyOnBigCandlePause  = true;     // push notification when big candle pause starts/ends
bool   InpDrawBigCandleRedMarker  = true;     // draw red marker/box when big candle is detected
int    InpBigCandleMarkerArrowCode = 159;     // marker symbol for big candle
color  InpBigCandleMarkerColor    = clrRed;   // red marker color for big candle

// Big candle profit protection:
// When a > InpBigCandleRawDifference candle/spike appears, all new/recovery orders are blocked.
// If an existing basket is already in profit, protect 80% of the highest basket profit reached.
// Example: peak profit $10, close if profit drops to $8 during big-candle pause.
bool   InpUseBigCandleProfitProtect = false;
double InpBigCandleProfitLockPercent = 80.0;
// Extra safety: block recovery gap orders for N minutes when current/last candles are big/spike.
bool   InpBlockRecoveryGapOnBigCandle = true;
int    InpBigCandleRecoveryPauseMinutes = 5;

// Last 3 candles movement pause:
// If the combined raw price range of the last 3 CLOSED candles is too large,
// pause ALL new orders/recovery orders like big candle protection.
// Formula: max(High[1..3]) - min(Low[1..3]) >= InpLast3CandlesRawDifference
bool   InpUseLast3CandlesMovePause = true;
double InpLast3CandlesRawDifference = 300.0;
int    InpLast3CandlesPauseMinutes = 5;

// Spike / wick pause protection
// Blocks new orders after long wick / spike candles. Useful to avoid BUY at top wick or SELL at bottom wick.
bool   InpUseSpikeWickPauseFilter = true;
double InpSpikeWickMinRawPrice    = 120.0;   // minimum upper/lower wick raw price to treat as spike
double InpSpikeWickBodyMaxPercent = 35.0;    // candle body must be small compared to full range
// Momentum spike detection catches full-body fast candles that do not have a small wick.
// Example: Range >= 150 or Body >= 100 => pause new orders and mark candle yellow.
double InpSpikeMomentumRangeRawPrice = 150.0;
double InpSpikeMomentumBodyRawPrice  = 100.0;
bool   InpDrawSpikeWickYellowMarker  = true;
int    InpSpikeWickMarkerArrowCode   = 159;
int    InpSpikeWickPauseMinutes   = 60;       // wait after spike/wick detected
bool   InpSpikeWickBlockRecovery  = true;    // block recovery/recovery-gap/hedge also
bool   InpSpikeWickBlockGuard     = true;    // block SAR special guard also

// SAR settings
double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;

// SAR flip confirmation filters
// 1) EMA9/EMA21 trend filter
// 2) Wait for one fully closed candle after SAR flip
// 3) Confirm raw price difference from SAR flip price
bool   InpUseSARFlipConfirmations = true;
bool   InpUseSAREMAConfirm        = false;
bool   InpUseSARClosedCandleConfirm = true;//false;
bool   InpUseSARPriceDiffConfirm  = true;
// double InpSARConfirmPriceDiff     = 100.0;   // raw price diff for BTCUSD, not points
// int    InpSARConfirmMinutes       = 15;     // wait this many minutes after SAR signal change before new order

// Continuous order price-gap confirmation:
// InpSARConfirmPriceDiff is used ONLY for SAR signal-change confirmation.
// InpContinuousOrderPriceGap is used ONLY for NEXT/continuity normal orders.
// Continuity order rule:
// 1) After the last confirmed normal order, wait InpContinuousOrderGapMinutes.
// 2) Then verify live price has moved InpContinuousOrderPriceGap from that last order price.
// No expiry timeout is used. If gap is not ready, EA keeps waiting.
bool   InpUseRepeatedPriceGapConfirm = false;
double InpContinuousOrderPriceGap    = 30;//10.0; //30  // raw price gap required from last confirmed normal order
int    InpContinuousOrderLookbackMinutes = 1;  // legacy input, not used by current continuity gap logic
int    InpContinuousOrderGapMinutes  = 1;      // wait this many minutes after last order, then verify price gap

// SAR pullback half-TP re-entry:
// Used only after at least one profitable NORMAL SAR order is closed in the same SAR signal.
// If continuity gap is not ready, but price pulls back 20-50 raw points from the last profit close,
// open one same-direction quick order and use TP = original basket target * multiplier.
bool   InpUseSARPullbackHalfTP            = true;
double InpSARPullbackMinGap               = 20.0;
double InpSARPullbackMaxGap               = 100.0;
double InpSARPullbackTPMultiplier         = 0.50;
bool   InpSARPullbackRequireRecoveryCandle = true;


double InpSARConfirmPriceDiff     = 50.0;   // SAR signal-change raw price diff confirmation only
int    InpSARConfirmMinutes       = 0;      // max minutes for SAR confirmation only; 0 = no expiry
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


// Order icon / chart marker colors
// Normal SAR, recovery, special guard, pullback and extra orders use different colors.
color  InpNormalBuyOrderIconColor       = clrLime;
color  InpNormalSellOrderIconColor      = clrRed;
color  InpRecoveryBuyOrderIconColor     = clrAqua;
color  InpRecoverySellOrderIconColor    = clrMagenta;
color  InpGuardBuyOrderIconColor        = clrYellow;
color  InpGuardSellOrderIconColor       = clrOrange;
color  InpPullbackBuyOrderIconColor     = clrBlue;
color  InpPullbackSellOrderIconColor    = clrDeepPink;
color  InpExtraBuyOrderIconColor        = clrGreenYellow;
color  InpExtraSellOrderIconColor       = clrTomato;
color  InpLastOrderIconColor            = clrWhite;

int    InpNormalBuyOrderArrowCode       = 233;
int    InpNormalSellOrderArrowCode      = 234;
int    InpRecoveryBuyOrderArrowCode     = 241;
int    InpRecoverySellOrderArrowCode    = 242;
int    InpGuardBuyOrderArrowCode        = 225;
int    InpGuardSellOrderArrowCode       = 226;
int    InpPullbackBuyOrderArrowCode     = 217;
int    InpPullbackSellOrderArrowCode    = 218;
int    InpExtraOrderArrowCode           = 159;
int    InpLastOrderArrowCode            = 108;

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
int    InpSARVeryLongDurationMaxOrders = 10;

int    InpSARDurationLongMinutes     = 30;     // opposite duration 60-119 min => max 2
int    InpSARLongDurationMaxOrders   = 10;

int    InpSARDurationMediumMinutes   = 10;     // opposite duration 30-59 min => max 5
int    InpSARMediumDurationMaxOrders = 10;

int    InpSARNormalDurationMaxOrders = 10;     // opposite duration <30 min or no data => max 10
//1-?100
//2 -67
int InpSARGoodMomentumExtraOrders = 1;
bool InpResetMaxOrdersWhenSARWeak = true;

bool InpIncreaseSARMaxAfterActiveMinutes = true;
int  InpSARActiveMinutesForExtraOrders = 30;
int  InpSARActiveExtraOrders = 1;

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

//================ LATE SAR CYCLE ENTRY PROTECTION ==================
// Prevent the last bad order before SAR reversal.
// Normal SAR orders are blocked when the SAR cycle is old and momentum/score becomes weak,
// or when the last closed candles are already moving against the current SAR direction.
bool   InpUseLateSARCycleEntryBlock       = true;
int    InpLateSARMinAgeMinutes            = 15;   // start blocking late-cycle entries after this SAR age
int    InpLateSARMaxWeakScore             = 3;    // block when dynamic SAR score is <= this value after min age
bool   InpLateSARBlockOnOpposite3Candles  = true; // BUY SAR + 3 falling closes, SELL SAR + 3 rising closes
bool   InpLateSARBlockOnWeakExit          = true; // block if early SAR weak exit is already active

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

// Confirmed SAR weak basket close:
// Close only when weakness is confirmed/recent, not on every weak marker.
// Profitable active SAR basket closes immediately.
// Old active SAR basket can close at a controlled small loss to avoid full basket SL.
bool   InpUseConfirmedSARWeakBasketClose = false;
int    InpSARWeakCloseRecentBars         = 3;     // latest weak signal must be within this many bars
bool   InpSARWeakCloseProfitBasket       = true;
double InpSARWeakMinProfitToClose        = 0.01;
bool   InpSARWeakCloseOldSmallLoss       = false;
int    InpSARWeakBasketAgeMinutes        = 30;
double InpSARWeakMaxSmallLossToCloseUSD  = 2.00;  // close old weak basket only if loss is between 0 and -this
bool   InpSARWeakCloseResetCycle         = false;  // after close, allow fresh SAR-direction entries on next tick

// SAR weak reverse order:
// When active SAR becomes weak before full SAR flip, optionally open one opposite order.
// Example: active SAR BUY becomes weak => open SELL order with comment SAR_WEAK_REVERSE.
bool   InpOpenReverseOrderOnSARWeakSignal = false;
double InpSARWeakReverseLot               = 0.01;  // 0 = use InpFixedLot
int    InpMaxSARWeakReverseOrders         = 2;     // total max weak-reverse orders. 2 = max 1 BUY + max 1 SELL
int    InpSARWeakReverseCooldownMinutes   = 1;     // avoid repeated reverse orders
bool   InpSARWeakReverseRequireH1Trend    = false; // true = reverse order must match H1/H2 trend
bool   InpSARWeakReverseRequireExistingSameSideOrder = false; // true = open weak-reverse only if an existing same-side order is already open

// SAR weak signal chart marker:
// When active SAR becomes weak, mark that candle with a different color so it is visible on chart.
bool   InpDrawSARWeakSignalMarker         = true;
color  InpSARWeakSignalMarkerColor        = clrViolet;
int    InpSARWeakSignalMarkerArrowCode    = 159;

//================ PROFIT PROTECTION / RECOVERY SAFETY ==============
// Protect total equity after a strong run. Example: equity peak 85,
// trail 10 => close all orders and pause if equity falls to 75.
bool   InpUseGlobalEquityTrailLock      = false;
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
double InpStrongOppMoveBlockRecoveryGap = 300.0;

// Absolute cap for all EA market orders combined: normal + recovery.
int    InpMaxTotalOpenOrders            = 0;

//================ DELAYED SAR CHANGE CLOSE =========================
// Reset counter whenever a NEW normal SAR order is created.
// Then count SAR signal changes from that order.
// Example: value 2 = do not close on first SAR flip after order; close on second flip.
bool   InpUseDelayedSARChangeClose          = true;
int    InpCloseOrdersOnNthSARChangeAfterOrder = 10;
bool   InpResetSARCloseCounterOnNewOrder    = true;


//======================== GLOBALS ===================================
int      g_activeSARDirection   = 0;       // 1 BUY, -1 SELL
int      g_lastSARDotDirection  = 0;       // current SAR side memory
int      g_earlyDirection       = 0;       // 1 BUY, -1 SELL, 0 none
bool     g_sarPausedByEarly     = false;   // true when early reverse fights SAR
bool     g_firstSARLocked       = false;
datetime g_lastBarTime          = 0;
datetime g_lastOrderTime        = 0;
// Last SAR_FLIP_V2LAST normal order time/bar. Used to give normal SAR order first priority over special guard.
datetime g_lastSARFlipV2LastOrderBarTime = 0;
datetime g_lastSARFlipV2LastOrderTime    = 0;
datetime g_lastEarlyArrowTime   = 0;
datetime g_lastSARArrowTime     = 0;
datetime g_lastSAREveryBarTime   = 0;
datetime g_lastFlatDotTime      = 0;
string   OBJ_PREFIX             = "DXB_SAR_CYCLE_";
int      g_autoMarketMode        = 0;       // 0 OFF, 1 CONTINUOUS, 2 MEDIUM, 3 MIXED, 4 DANGER
string   g_autoMarketModeText    = "OFF";
double   g_autoMarketMoveRaw     = 0.0;
double   g_autoMarketLast3MoveRaw= 0.0;
int      g_autoMarketBuyProfitCount  = 0;
int      g_autoMarketSellProfitCount = 0;
int      g_autoMarketDirection   = 0;
int      dotColor               = 0;       // 1 SAR below price, -1 SAR above price
bool     g_flatMode             = false;   // true when price is compressed/sideways

// Delayed SAR close state: this counter is reset only when a NEW normal SAR order is created.
int      g_sarChangesAfterLastNormalOrder = 0;
int      g_sarCloseTrackedDirection       = 0;
datetime g_sarCloseTrackedOrderTime       = 0;
string   g_sarDelayedCloseStatus          = "WAIT ORDER";

// SAR flip pending confirmation state
int      g_pendingSARConfirmDirection = 0;  // 1 BUY, -1 SELL, 0 none
double   g_pendingSARConfirmPrice     = 0.0;
datetime g_pendingSARConfirmTime      = 0;
datetime g_pendingSARConfirmBarTime   = 0;

// Active SAR signal changed reference price. This remains available after pending confirmation is reset.
double   g_activeSARSignalChangePrice = 0.0;
datetime g_activeSARSignalChangeTime  = 0;

// Repeated price-gap confirmation state for normal SAR orders
double   g_lastConfirmedOrderPrice = 0.0;
datetime g_lastConfirmedOrderTime  = 0;

// Last successful EA market-order close time.
// Used to prevent opening a new normal order in the same minute immediately after TP/protect/SL close.
datetime g_lastAnyOrderCloseTime   = 0;

// Last CLOSED normal SAR order reference for continuity orders.
// InpContinuousOrderPriceGap is checked from this close price while SAR signal is unchanged.
double   g_lastClosedNormalOrderPrice = 0.0;
datetime g_lastClosedNormalOrderTime  = 0;
int      g_lastClosedNormalOrderDirection = 0;
datetime g_lastSARPullbackOrderBarTime = 0;


// Number of profitable NORMAL SAR orders closed in the current SAR signal cycle.
// Resets whenever SAR signal changes. Used by GetIndividualProfitProtectLevel().
int      g_sarClosedProfitOrdersCount = 0;

// Last normal order open result. Used by dashboard/status when OpenMarketOrder() returns false.
string   g_lastOrderOpenReason    = "WAIT ORDER";
datetime g_lastOrderBlockTime     = 0;

// Last successful close result. Used by left dashboard so close reason is not missed.
string   g_lastOrderCloseMessage  = "NO CLOSE YET";
datetime g_lastOrderCloseTime     = 0;

// Pending recovery-gap request memory.
// Stored when gap was matched but recovery order was blocked by temporary conditions.
// It is retried on later ticks and also after SAR changes.
int      g_pendingRecoveryGapDirection = 0;
double   g_pendingRecoveryGapMove      = 0.0;
double   g_pendingRecoveryRequiredGap  = 0.0;
datetime g_pendingRecoveryGapTime      = 0;
string   g_pendingRecoveryGapReason    = "NONE";

// SAR special guard troubleshooting dashboard memory.
// Updated whenever guard trigger matches, is skipped, blocked, fails, or opens.
string   g_sarSpecialGuardLastStatus = "WAIT";
datetime g_sarSpecialGuardLastStatusTime = 0;
int      g_sarSpecialGuardLastParentTicket = 0;
double   g_sarSpecialGuardLastParentProfit = 0.0;
double   g_sarSpecialGuardLastParentRecoveryProfit = 0.0;
double   g_sarSpecialGuardLastRequestedLot = 0.0;
int      g_sarSpecialGuardLastError = 0;

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
datetime g_lastBigCandleFormationBarTime = 0;
double   g_lastBigCandleMove       = 0.0;
bool     g_notifyBigCandlePauseSent = false;

// Spike / wick pause state
bool     g_spikeWickPause = false;
datetime g_spikeWickPauseUntil = 0;
datetime g_lastSpikeWickBarTime = 0;
double   g_lastSpikeWickWickSize = 0.0;
double   g_lastSpikeWickBodyPercent = 0.0;
double   g_lastSpikeWickRangeSize = 0.0;
double   g_lastSpikeWickBodySize = 0.0;
int      g_lastSpikeWickShift = -1;
string   g_spikeWickLastReason = "OFF";

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
double   g_allBasketPeakProfit    = 0.0;
double   g_buyBasketPeakProfit    = 0.0;
double   g_sellBasketPeakProfit   = 0.0;
datetime g_lastEarlySARWeakExitTime = 0;
int      g_lastEarlySARWeakExitDirection = 0;

// SAR weak reverse order state
string   g_sarWeakReverseLastStatus = "WAIT";
datetime g_sarWeakReverseLastTime = 0;
int      g_sarWeakReverseLastDirection = 0;
int      g_sarWeakReverseLastTicket = 0;
string   g_sarWeakReverseLastReason = "NONE";

// SAR weak signal candle marker state
datetime g_lastSARWeakSignalMarkerBarTime = 0;
string   g_lastSARWeakSignalMarkerReason  = "OFF";

// Confirmed SAR weak basket-close dashboard state
string   g_sarWeakBasketCloseLastStatus = "WAIT";
datetime g_sarWeakBasketCloseLastTime = 0;
int      g_sarWeakBasketCloseLastDirection = 0;
double   g_sarWeakBasketCloseLastProfit = 0.0;
int      g_sarWeakBasketCloseLastAgeMin = 0;
string   g_sarWeakBasketCloseLastReason = "NONE";

double   g_globalEquityPeak              = 0.0;
datetime g_globalEquityTrailPauseUntil   = 0;
datetime g_profitProtectPauseUntil       = 0;   // pause new normal orders after individual profit protect close
bool     g_globalEquityTrailLocked       = false;
string   g_globalEquityTrailStatus       = "OFF";


// Individual profit protection tracker by ticket
int      g_profitProtectTickets[500];
double   g_profitProtectPeakProfit[500];
int      g_profitProtectCount = 0;

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

int GetH2TrendDirection()
  {


   double currentPrice = Close[0];

// M1 chart: 30 candles = 30 minutes ago
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 60);

   double diff = currentPrice - price30MinAgo;

   if(diff >= 1000)
      return 1;   // BUY trend

   if(diff <= -1000)
      return -1;  // SELL trend

   return 0;      // RANGE


  }
int GetH1TrendDirection()
  {


   double currentPrice = Close[0];

// M1 chart: 30 candles = 30 minutes ago
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 30);

   double diff = currentPrice - price30MinAgo;

   if(diff >= 200)
      return 1;   // BUY trend

   if(diff <= -200)
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
//| Recovery gap H1 trend filter                                     |
//| Blocks recovery gap orders unless H1 trend matches order side.    |
//+------------------------------------------------------------------+
bool IsRecoveryGapAllowedByH1Trend(int direction)
  {
   if(!InpRecoveryGapMustMatchH1Trend)
      return(true);

   int h1Trend = GetH2TrendDirection();

   if(h1Trend == 0)
     {
      string msg = "RECOVERY GAP BLOCKED | H1 trend is RANGE/NONE";
      SetLastOrderBlockDashboard(msg);
      Print(msg,
            " | RecoveryDir=", DirectionText(direction));
      return(false);
     }

   if(direction != h1Trend)
     {
      string msg2 = "RECOVERY GAP BLOCKED | H1 trend mismatch";
      SetLastOrderBlockDashboard(msg2 + " | H1=" + DirectionText(h1Trend));
      Print(msg2,
            " | RecoveryDir=", DirectionText(direction),
            " | H1Trend=", DirectionText(h1Trend));
      return(false);
     }

   return(true);
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
bool IsSARPullbackHalfTPComment(string commentText)
{
   return(StringFind(commentText, "PULLBACK_HALF") >= 0);
}


bool IsSARWeakReverseOrderComment(string commentText)
{
   return(StringFind(commentText, "SAR_WEAK_REVERSE") >= 0);
}

bool HasOpenSARPullbackHalfTPOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      if(IsSARPullbackHalfTPComment(OrderComment()))
         return(true);
   }
   return(false);
}


//+------------------------------------------------------------------+
//| Auto Market Flow Mode helpers                                    |
//+------------------------------------------------------------------+
#define DXB_MARKET_MODE_OFF        0
#define DXB_MARKET_MODE_CONTINUOUS 1
#define DXB_MARKET_MODE_MEDIUM     2
#define DXB_MARKET_MODE_MIXED      3
#define DXB_MARKET_MODE_DANGER     4

string MarketFlowModeText(int mode)
{
   if(mode == DXB_MARKET_MODE_CONTINUOUS) return("CONTINUOUS TREND");
   if(mode == DXB_MARKET_MODE_MEDIUM)     return("MEDIUM TREND");
   if(mode == DXB_MARKET_MODE_MIXED)      return("MIXED TREND");
   if(mode == DXB_MARKET_MODE_DANGER)     return("DANGER SPIKE");
   return("OFF");
}

color MarketFlowModeColor()
{
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS) return(clrLime);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)     return(clrAqua);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)      return(clrYellow);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)     return(clrRed);
   return(clrSilver);
}

double GetRecentMarketRawMove(int bars)
{
   int lookback = MathMax(5, bars);
   if(Bars <= lookback + 2)
      lookback = MathMax(2, Bars - 2);

   if(lookback <= 1)
      return(0.0);

   int hi = iHighest(Symbol(), PERIOD_M1, MODE_HIGH, lookback, 1);
   int lo = iLowest(Symbol(), PERIOD_M1, MODE_LOW, lookback, 1);
   if(hi < 0 || lo < 0)
      return(0.0);

   return(MathAbs(iHigh(Symbol(), PERIOD_M1, hi) - iLow(Symbol(), PERIOD_M1, lo)));
}

double GetLastNCandlesRawMove(int countBars)
{
   int lookback = MathMax(1, countBars);
   if(Bars <= lookback + 2)
      lookback = MathMax(1, Bars - 2);

   int hi = iHighest(Symbol(), PERIOD_M1, MODE_HIGH, lookback, 1);
   int lo = iLowest(Symbol(), PERIOD_M1, MODE_LOW, lookback, 1);
   if(hi < 0 || lo < 0)
      return(0.0);

   return(MathAbs(iHigh(Symbol(), PERIOD_M1, hi) - iLow(Symbol(), PERIOD_M1, lo)));
}

int GetMarketFlowDirection(int bars)
{
   int lookback = MathMax(5, bars);
   if(Bars <= lookback + 2)
      lookback = MathMax(2, Bars - 2);

   double oldClose = iClose(Symbol(), PERIOD_M1, lookback);
   double diff = Close[0] - oldClose;
   if(diff > 0.0) return(1);
   if(diff < 0.0) return(-1);
   return(0);
}

bool IsNormalProfitOrderForMarketFlow(string commentText)
{
   if(IsSARGuardOrderComment(commentText)) return(false);
   if(IsRecoveryGapOrderComment(commentText)) return(false);
   if(IsRecoveryHedgeOrderComment(commentText)) return(false);
   if(IsSARWeakReverseOrderComment(commentText)) return(false);
   if(IsSARPullbackHalfTPComment(commentText)) return(false);
   if(StringFind(commentText, "RECOVERY") >= 0) return(false);
   return(true);
}

int CountRecentProfitableOrdersForMarketFlow(int direction)
{
   int count = 0;
   datetime fromTime = TimeCurrent() - MathMax(1, InpMarketFlowProfitHours) * 3600;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() < fromTime)
         continue;
      if(OrderProfit() <= 0.0)
         continue;
      if(!IsNormalProfitOrderForMarketFlow(OrderComment()))
         continue;

      int dir = (OrderType() == OP_BUY) ? 1 : -1;
      if(dir == direction)
         count++;
   }

   return(count);
}

void UpdateAutoMarketFlowMode()
{
   if(!InpUseAutoMarketFlowMode)
   {
      g_autoMarketMode = DXB_MARKET_MODE_OFF;
      g_autoMarketModeText = "OFF";
      g_autoMarketMoveRaw = 0.0;
      g_autoMarketLast3MoveRaw = 0.0;
      g_autoMarketBuyProfitCount = 0;
      g_autoMarketSellProfitCount = 0;
      g_autoMarketDirection = 0;
      return;
   }

   g_autoMarketMoveRaw = GetRecentMarketRawMove(InpMarketFlowLookbackBars);
   g_autoMarketLast3MoveRaw = GetLastNCandlesRawMove(3);
   g_autoMarketBuyProfitCount = CountRecentProfitableOrdersForMarketFlow(1);
   g_autoMarketSellProfitCount = CountRecentProfitableOrdersForMarketFlow(-1);
   g_autoMarketDirection = GetMarketFlowDirection(InpMarketFlowLookbackBars);

   // Danger has first priority. No new orders; only close/protect management.
   if(g_autoMarketLast3MoveRaw >= InpDangerLast3MoveRaw ||
      GetLastNCandlesRawMove(1) >= InpBigCandleRawDifference)
   {
      g_autoMarketMode = DXB_MARKET_MODE_DANGER;
      g_autoMarketModeText = MarketFlowModeText(g_autoMarketMode);
      return;
   }

   bool buyContinuous = (g_autoMarketMoveRaw >= InpContinuousTrendMoveRaw &&
                         g_autoMarketBuyProfitCount >= InpContinuousTrendProfitOrders &&
                         g_autoMarketSellProfitCount <= InpContinuousTrendOppProfitMax);

   bool sellContinuous = (g_autoMarketMoveRaw >= InpContinuousTrendMoveRaw &&
                          g_autoMarketSellProfitCount >= InpContinuousTrendProfitOrders &&
                          g_autoMarketBuyProfitCount <= InpContinuousTrendOppProfitMax);

   if(buyContinuous || sellContinuous)
      g_autoMarketMode = DXB_MARKET_MODE_CONTINUOUS;
   else if(g_autoMarketMoveRaw >= InpMediumTrendMinMoveRaw &&
           g_autoMarketMoveRaw <= InpMediumTrendMaxMoveRaw)
      g_autoMarketMode = DXB_MARKET_MODE_MEDIUM;
   else if(g_autoMarketMoveRaw >= InpMixedTrendMinMoveRaw &&
           g_autoMarketMoveRaw <= InpMixedTrendMaxMoveRaw)
      g_autoMarketMode = DXB_MARKET_MODE_MIXED;
   else
      g_autoMarketMode = DXB_MARKET_MODE_MIXED;

   g_autoMarketModeText = MarketFlowModeText(g_autoMarketMode);
}

double GetEffectiveBasketStopLossUSD()
{
   if(InpUseSimpleSideBasketCloseOnly)
      return(InpBasketStopLossUSD);

   if(!InpUseAutoMarketFlowMode)
      return(InpBasketStopLossUSD);

   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS) return(InpContinuousTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)     return(InpMediumTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)      return(InpMixedTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)     return(InpDangerModeBasketSLUSD);

   return(InpBasketStopLossUSD);
}

bool IsAutoMarketRecoveryAllowed()
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS) return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)     return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)     return(InpAutoModeAllowRecoveryMedium);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)      return(InpAutoModeAllowRecoveryMixed);
   return(true);
}

bool IsAutoMarketSARWeakAllowed()
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS) return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)     return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)     return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)      return(InpAutoModeAllowSARWeakMixed);
   return(true);
}

bool IsAutoMarketPullbackAllowed()
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS) return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)     return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)     return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)      return(InpAutoModeAllowPullbackMixed);
   return(true);
}

bool IsAutoMarketNewOrderAllowed(string reason)
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER && InpAutoModePauseOrdersInDanger)
      return(false);
   if(StringFind(reason, "RECOVERY") >= 0 && !IsAutoMarketRecoveryAllowed())
      return(false);
   if(StringFind(reason, "SAR_WEAK_REVERSE") >= 0 && !IsAutoMarketSARWeakAllowed())
      return(false);
   if((StringFind(reason, "PULLBACK") >= 0 || StringFind(reason, "HALF_TP") >= 0) && !IsAutoMarketPullbackAllowed())
      return(false);
   return(true);
}

string AutoMarketModeStatusText()
{
   if(!InpUseAutoMarketFlowMode)
      return("OFF");

   return(g_autoMarketModeText + " | Move " + DoubleToString(g_autoMarketMoveRaw,0) +
          " | B/S " + IntegerToString(g_autoMarketBuyProfitCount) + "/" +
          IntegerToString(g_autoMarketSellProfitCount));
}

//+------------------------------------------------------------------+ 
//| Basket profit time-decay helpers                                 |
//+------------------------------------------------------------------+
datetime GetLatestEAOpenOrderTimeForBasketDecay()
{
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!InpBasketProfitDecayIncludeGuards && IsSARGuardOrderComment(OrderComment()))
         continue;

      if(OrderOpenTime() > latestTime)
         latestTime = OrderOpenTime();
   }

   // Fallback for the current tick / after restart edge cases.
   if(latestTime <= 0 && g_lastOrderTime > 0)
      latestTime = g_lastOrderTime;

   return(latestTime);
}

//+------------------------------------------------------------------+
double GetBasketProfitTimeDecayMultiplier()
{
   if(!InpUseBasketProfitTimeDecay)
      return(1.0);

   int stepMinutes = MathMax(1, InpBasketProfitDecayStepMinutes);
   datetime latestOrderTime = GetLatestEAOpenOrderTimeForBasketDecay();

   if(latestOrderTime <= 0)
      return(1.0);

   int elapsedMinutes = (int)((TimeCurrent() - latestOrderTime) / 60);

   if(elapsedMinutes < stepMinutes)
      return(1.0);

   int divisor = (elapsedMinutes / stepMinutes) + 1;
   if(divisor < 1)
      divisor = 1;

   double multiplier = 1.0 / divisor;
   double minMultiplier = MathMax(0.01, MathMin(1.0, InpBasketProfitDecayMinMultiplier));

   if(multiplier < minMultiplier)
      multiplier = minMultiplier;

   return(multiplier);
}

//+------------------------------------------------------------------+
string BasketProfitTimeDecayStatusText()
{
   if(!InpUseBasketProfitTimeDecay)
      return("OFF");

   datetime latestOrderTime = GetLatestEAOpenOrderTimeForBasketDecay();
   if(latestOrderTime <= 0)
      return("WAIT ORDER");

   int elapsedMinutes = (int)((TimeCurrent() - latestOrderTime) / 60);
   double multiplier = GetBasketProfitTimeDecayMultiplier();

   return(IntegerToString(elapsedMinutes) + "m | x" + DoubleToString(multiplier, 2));
}

//+------------------------------------------------------------------+
double GetBasketProfitTargetUSD()
{
   if(InpUseSimpleSideBasketCloseOnly)
     {
      int simpleCount = CountOpenOrders();
      if(simpleCount <= 0)
         simpleCount = 1;
      return(InpBasketProfitUSD / simpleCount);
     }

   int h = TimeHour(TimeCurrent());

   int count=CountOpenOrders();
   if(count==0)count=1;

   double baseTarget = InpBasketProfitUSD;

   if(h >= 12 && h <= 17)
      baseTarget = InpBasketProfitUSD_12_17;

   double target = baseTarget / count;

   // Time decay: after every 30 minutes without a new EA order,
   // reduce target so old baskets close faster before trend changes.
   target = target * GetBasketProfitTimeDecayMultiplier();

   // Pullback half-TP order is a quick re-entry. When it is open,
   // close the basket/side faster using original target * multiplier.
   if(InpUseSARPullbackHalfTP && HasOpenSARPullbackHalfTPOrder())
      target = target * MathMax(0.05, MathMin(1.0, InpSARPullbackTPMultiplier));

   return(target);
}


//+------------------------------------------------------------------+
//| Order icon color / marker helpers                                |
//+------------------------------------------------------------------+
color GetOrderIconColorByComment(int direction, string commentText)
  {
   if(IsSARGuardOrderComment(commentText))
      return(direction == 1 ? InpGuardBuyOrderIconColor : InpGuardSellOrderIconColor);

   if(IsRecoveryGapOrderComment(commentText) || IsRecoveryHedgeOrderComment(commentText) || StringFind(commentText, "RECOVERY") >= 0)
      return(direction == 1 ? InpRecoveryBuyOrderIconColor : InpRecoverySellOrderIconColor);

   if(IsSARPullbackHalfTPComment(commentText))
      return(direction == 1 ? InpPullbackBuyOrderIconColor : InpPullbackSellOrderIconColor);

   if(IsSARWeakReverseOrderComment(commentText))
      return(direction == 1 ? clrDodgerBlue : clrOrangeRed);

   if(StringFind(commentText, "SAR_ARROW_EXTRA") >= 0 || StringFind(commentText, "EXTRA") >= 0)
      return(direction == 1 ? InpExtraBuyOrderIconColor : InpExtraSellOrderIconColor);

   return(direction == 1 ? InpNormalBuyOrderIconColor : InpNormalSellOrderIconColor);
  }

//+------------------------------------------------------------------+
int GetOrderIconArrowCodeByComment(int direction, string commentText)
  {
   if(IsSARGuardOrderComment(commentText))
      return(direction == 1 ? InpGuardBuyOrderArrowCode : InpGuardSellOrderArrowCode);

   if(IsRecoveryGapOrderComment(commentText) || IsRecoveryHedgeOrderComment(commentText) || StringFind(commentText, "RECOVERY") >= 0)
      return(direction == 1 ? InpRecoveryBuyOrderArrowCode : InpRecoverySellOrderArrowCode);

   if(IsSARPullbackHalfTPComment(commentText))
      return(direction == 1 ? InpPullbackBuyOrderArrowCode : InpPullbackSellOrderArrowCode);

   if(IsSARWeakReverseOrderComment(commentText))
      return(direction == 1 ? 241 : 242);

   if(StringFind(commentText, "SAR_ARROW_EXTRA") >= 0 || StringFind(commentText, "EXTRA") >= 0)
      return(InpExtraOrderArrowCode);

   return(direction == 1 ? InpNormalBuyOrderArrowCode : InpNormalSellOrderArrowCode);
  }

//+------------------------------------------------------------------+
string GetOrderIconTypeText(string commentText)
  {
   if(IsSARGuardOrderComment(commentText))
      return("SPECIAL GUARD");

   if(IsRecoveryGapOrderComment(commentText))
      return("RECOVERY GAP");

   if(IsRecoveryHedgeOrderComment(commentText))
      return("RECOVERY HEDGE");

   if(StringFind(commentText, "RECOVERY") >= 0)
      return("RECOVERY");

   if(IsSARPullbackHalfTPComment(commentText))
      return("PULLBACK HALF TP");

   if(IsSARWeakReverseOrderComment(commentText))
      return("SAR WEAK REVERSE");

   if(StringFind(commentText, "SAR_ARROW_EXTRA") >= 0 || StringFind(commentText, "EXTRA") >= 0)
      return("EXTRA SAR");

   return("NORMAL SAR");
  }

//+------------------------------------------------------------------+
void DrawEAOrderIcon(int ticket, int direction, string commentText, datetime orderTime, double price)
  {
   if(ticket <= 0 || direction == 0)
      return;

   string name = OBJ_PREFIX + "ORDER_ICON_" + IntegerToString(ticket);
   ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, orderTime, price))
     {
      Print("ORDER ICON DRAW FAILED | Ticket=", ticket, " | Error=", GetLastError());
      ResetLastError();
      return;
     }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, GetOrderIconArrowCodeByComment(direction, commentText));
   ObjectSetInteger(0, name, OBJPROP_COLOR, GetOrderIconColorByComment(direction, commentText));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TEXT,
                   GetOrderIconTypeText(commentText) + " #" + IntegerToString(ticket) + " " + DirectionText(direction));
  }

//+------------------------------------------------------------------+
void DrawLastOrderHighlightIcon(int ticket, int direction, datetime orderTime, double price)
  {
   if(ticket <= 0 || direction == 0)
      return;

   string name = OBJ_PREFIX + "LAST_ORDER_ICON";
   ObjectDelete(0, name);

   double offset = MathMax(10 * Point, MarketInfo(Symbol(), MODE_SPREAD) * Point);
   double markerPrice = price;
   if(direction == 1)
      markerPrice = price - offset;
   else
      markerPrice = price + offset;

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, orderTime, markerPrice))
     {
      Print("LAST ORDER ICON DRAW FAILED | Ticket=", ticket, " | Error=", GetLastError());
      ResetLastError();
      return;
     }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, InpLastOrderArrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpLastOrderIconColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetString(0, name, OBJPROP_TEXT, "LAST ORDER #" + IntegerToString(ticket) + " " + DirectionText(direction));
  }

//+------------------------------------------------------------------+
void MarkOpenedOrderOnChart(int ticket, int direction, string commentText, datetime orderTime, double price)
  {
   DrawEAOrderIcon(ticket, direction, commentText, orderTime, price);
   DrawLastOrderHighlightIcon(ticket, direction, orderTime, price);
  }

//+------------------------------------------------------------------+
int OnInit()
  {


   
  
  if(IsTesting())
{
   InpProfitTargetPercent = 2000.0;
}

if(AccountNumber()==291085426)
{
    InpProfitTargetPercent = 2000.0;

}



   InitializeEquityDay();
   InitializeLastDepositBalanceOpTime();
   DeleteNonEarlySignalArrows();
   DeleteOldDashboardObjects();
   LoadLast5SARChangeDurations();

   InpMagicNumber=AccountNumber()+202; // override magic number with account number to prevent interference between charts/accounts. Orders are still filtered by symbol and magic in this EA.

   Print(InpEAName, " initialized. Magic=", InpMagicNumber,
         " | BaseBalance=$", DoubleToString(g_baseBalance,2),
         " | LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
         " | ProfitTargetEquity=$", DoubleToString(g_profitTargetEquity,2),
         " | TargetProfit=$", DoubleToString(g_dailyProfitTarget,2));

   if(InpNotifyOnEAStart)
     {
      // SendEAAlert("EA STARTED",
      //             "Base=$" + DoubleToString(g_baseBalance,2) +
      //             " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
      //             " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
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
   g_lastSARFlipV2LastOrderBarTime = 0;
   g_sarCycleDirection   = 0;
   g_sarCycleMaxOrders   = MathMax(0, InpSARNormalDurationMaxOrders);
   g_sarCycleOrdersCreated = 0;
   g_sarCycleStartTime   = 0;
   g_activeSARSignalChangePrice = 0.0;
   g_activeSARSignalChangeTime  = 0;
   g_lastConfirmedOrderPrice = 0.0;
   g_lastConfirmedOrderTime  = 0;
   g_lastAnyOrderCloseTime   = 0;
   g_lastClosedNormalOrderPrice = 0.0;
   g_lastClosedNormalOrderTime  = 0;
   g_lastClosedNormalOrderDirection = 0;
   g_lastSARPullbackOrderBarTime = 0;
   g_sarClosedProfitOrdersCount = 0;
   g_lastOrderOpenReason     = "WAIT ORDER";
   g_lastOrderBlockTime      = 0;
   g_lastOrderCloseMessage   = "NO CLOSE YET";
   g_lastOrderCloseTime      = 0;
   g_pendingRecoveryGapDirection = 0;
   g_pendingRecoveryGapMove      = 0.0;
   g_pendingRecoveryRequiredGap  = 0.0;
   g_pendingRecoveryGapTime      = 0;
   g_pendingRecoveryGapReason    = "NONE";
   g_sarSpecialGuardLastStatus = "WAIT";
   g_sarSpecialGuardLastStatusTime = 0;
   g_sarSpecialGuardLastParentTicket = 0;
   g_sarSpecialGuardLastParentProfit = 0.0;
   g_sarSpecialGuardLastParentRecoveryProfit = 0.0;
   g_sarSpecialGuardLastRequestedLot = 0.0;
   g_sarSpecialGuardLastError = 0;
   g_sarChangesAfterLastNormalOrder = 0;
   g_sarCloseTrackedDirection       = 0;
   g_sarCloseTrackedOrderTime       = 0;
   g_sarDelayedCloseStatus          = "WAIT ORDER";
   g_sarWeakReverseLastStatus      = "WAIT";
   g_sarWeakReverseLastTime        = 0;
   g_sarWeakReverseLastDirection   = 0;
   g_sarWeakReverseLastTicket      = 0;
   g_sarWeakReverseLastReason      = "NONE";
   ResetSARFlipConfirmation();
   ResetBigCandlePauseState();
   ResetSpikeWickPauseState();
   g_lastSARWeakSignalMarkerBarTime = 0;
   g_lastSARWeakSignalMarkerReason  = "OFF";
   g_sarWeakBasketCloseLastStatus   = "WAIT";
   g_sarWeakBasketCloseLastTime     = 0;
   g_sarWeakBasketCloseLastDirection = 0;
   g_sarWeakBasketCloseLastProfit   = 0.0;
   g_sarWeakBasketCloseLastAgeMin   = 0;
   g_sarWeakBasketCloseLastReason   = "NONE";

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
         // SendEAAlert("TRADING RESTARTED",
         //             resetReason +
         //             " | NewBase=$" + DoubleToString(g_baseBalance,2) +
         //             " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
         //             " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
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
         // SendEAAlert("TRADING RESTARTED - DEPOSIT RESET",
         //             "Deposit=$" + DoubleToString(amount,2) +
         //             " | NewBase=$" + DoubleToString(g_baseBalance,2) +
         //             " | Target=$" + DoubleToString(g_profitTargetEquity,2) +
         //             " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
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
   if(InpUseSimpleSideBasketCloseOnly)
      return(false);

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
         // SendEAAlert("TRADING STOPPED - EQUITY LOSS",
         //             "Equity=$" + DoubleToString(AccountEquity(),2) +
         //             " | Base=$" + DoubleToString(g_baseBalance,2) +
         //             " | LossStop=$" + DoubleToString(g_lossStopEquityLevel,2));
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
            // SendEAAlert("TRADING STOPPED - PROFIT TARGET",
            //             "Equity=$" + DoubleToString(AccountEquity(),2) +
            //             " | Base=$" + DoubleToString(g_baseBalance,2) +
            //             " | Profit=$" + DoubleToString(profitFromBase,2) +
            //             " | Target=$" + DoubleToString(g_dailyProfitTarget,2));
           }
        }

      if(g_dailyProfitLock && InpPauseAfterProfitTarget)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Store last CLOSED normal SAR order reference for continuity gap   |
//+------------------------------------------------------------------+
void RecordLastClosedNormalOrderReference(int orderType, double closePrice, string commentText, string closeReason)
  {
   int closeDirection = 0;
   if(orderType == OP_BUY)
      closeDirection = 1;
   else if(orderType == OP_SELL)
      closeDirection = -1;
   else
      return;

   // Recovery/hedge orders must not become the reference for normal SAR continuity orders.
   if(StringFind(commentText, "RECOVERY") >= 0 || StringFind(commentText, "HEDGE") >= 0 || IsSARGuardOrderComment(commentText))
      return;

   // Reference must belong to the current SAR signal cycle only.
   // When SAR changes, ResetSARSignalOrderCycle() clears this reference.
   if(closeDirection != g_sarCycleDirection || closeDirection != g_activeSARDirection)
     {
      Print("CLOSED NORMAL REFERENCE SKIPPED | CloseDir=", DirectionText(closeDirection),
            " | ActiveSAR=", DirectionText(g_activeSARDirection),
            " | CycleSAR=", DirectionText(g_sarCycleDirection),
            " | ClosePrice=", DoubleToString(closePrice, Digits),
            " | Reason=", closeReason);
      return;
     }

   g_lastClosedNormalOrderPrice = closePrice;
   g_lastClosedNormalOrderTime  = TimeCurrent();
   g_lastClosedNormalOrderDirection = closeDirection;

   Print("CLOSED NORMAL REFERENCE UPDATED | Direction=", DirectionText(closeDirection),
         " | ClosePrice=", DoubleToString(g_lastClosedNormalOrderPrice, Digits),
         " | Time=", TimeToString(g_lastClosedNormalOrderTime, TIME_DATE|TIME_SECONDS),
         " | Reason=", closeReason);
  }

//+------------------------------------------------------------------+
//| Count profitable NORMAL SAR order closes in current SAR signal    |
//+------------------------------------------------------------------+
void RegisterSARClosedProfitOrder(int orderType, string commentText, double closedProfit, string closeReason)
  {
   if(!InpUseSARClosedProfitCountProtect)
      return;

   if(closedProfit <= 0.0)
      return;

   int closeDirection = 0;
   if(orderType == OP_BUY)
      closeDirection = 1;
   else if(orderType == OP_SELL)
      closeDirection = -1;
   else
      return;

   // Count only normal SAR orders. Recovery/hedge closes must not increase this counter.
   if(StringFind(commentText, "RECOVERY") >= 0 || StringFind(commentText, "HEDGE") >= 0 || IsSARGuardOrderComment(commentText))
      return;

   // Count only orders closed inside the current SAR signal direction.
   if(closeDirection != g_sarCycleDirection || closeDirection != g_activeSARDirection)
      return;

   g_sarClosedProfitOrdersCount++;

   Print("SAR CLOSED PROFIT COUNT UPDATED | Direction=", DirectionText(closeDirection),
         " | Count=", g_sarClosedProfitOrdersCount,
         " | ClosedProfit=$", DoubleToString(closedProfit, 2),
         " | Reason=", closeReason);
  }

//+------------------------------------------------------------------+
//| Dashboard memory for last order block and last order close        |
//+------------------------------------------------------------------+
void SetLastOrderBlockDashboard(string reason)
  {
   g_lastOrderOpenReason = reason;
   g_lastOrderBlockTime  = TimeCurrent();
  }

//+------------------------------------------------------------------+
bool SetOrderBlockStatus(string &status, string reason)
  {
   status = reason;
   SetLastOrderBlockDashboard(reason);
   Print("ORDER BLOCKED | ", reason);
   return(false);
  }

//+------------------------------------------------------------------+
string DashboardTimeText(datetime t)
  {
   if(t <= 0)
      return("NONE");

   return(TimeToString(t, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
void SetLastOrderCloseDashboard(int ticket, int type, double profit, double closePrice, string reason)
  {
   string typeText = "UNKNOWN";
   if(type == OP_BUY)
      typeText = "BUY";
   else
      if(type == OP_SELL)
         typeText = "SELL";

   g_lastOrderCloseTime = TimeCurrent();
   g_lastOrderCloseMessage =
      "#" + IntegerToString(ticket) + " " + typeText +
      " $" + DoubleToString(profit, 2) +
      " @ " + DoubleToString(closePrice, Digits) +
      " | " + reason;

   Print("LAST CLOSE DASHBOARD UPDATED | ", g_lastOrderCloseMessage);
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

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      int type = OrderType();
      double closePrice = (type == OP_BUY) ? Bid : Ask;
      double closeProfit = OrderProfit() + OrderSwap() + OrderCommission();

      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);
      if(!ok)
        {
         int err = GetLastError();
         Print("CloseAllEAOrders failed | Ticket=", OrderTicket(), " Reason=", reason, " Error=", err);
         ResetLastError();
        }
      else
        {
         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(OrderTicket(), type, closeProfit, closePrice, reason);
         RecordLastClosedNormalOrderReference(type, closePrice, OrderComment(), reason);
         RegisterSARClosedProfitOrder(type, OrderComment(), closeProfit, reason);
         Print("CloseAllEAOrders closed | Ticket=", OrderTicket(), " Reason=", reason);
        }
     }
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| FIRST PRIORITY PROFIT BOOKING                                    |
//| 1) Close ALL BUY+SELL open EA orders when combined profit >= TP.  |
//| 2) If combined target is not reached, close BUY or SELL basket    |
//|    separately when that side profit >= TP.                        |
//+------------------------------------------------------------------+
double GetAllOpenEAOrdersProfit()
  {
   double profit = 0.0;

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

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      profit += OrderProfit() + OrderSwap() + OrderCommission();
     }

   return(profit);
  }

//+------------------------------------------------------------------+
void ResetDelayedSARCloseAfterBasketClose(int direction, string resetReason)
  {
   if(direction != 0 && direction != g_sarCloseTrackedDirection)
      return;

   g_sarChangesAfterLastNormalOrder = 0;
   g_sarCloseTrackedDirection       = 0;
   g_sarCloseTrackedOrderTime       = 0;
   g_sarDelayedCloseStatus          = resetReason;
  }


//+------------------------------------------------------------------+
//| Basket profit protection level selector                          |
//| Same idea as GetIndividualProfitProtectLevel(), but for baskets.  |
//| Highest reached fixed level is used first. If no fixed level      |
//| matches, dynamic fallback protects a percentage of peak profit.   |
//+------------------------------------------------------------------+
bool GetBasketProfitProtectLevel(double peakProfit,
                                 double defaultActivate,
                                 double defaultCloseAt,
                                 double &selectedActivate,
                                 double &selectedCloseAt,
                                 int &selectedLevel)
  {
   selectedActivate = MathMax(0.0, defaultActivate);
   selectedCloseAt  = MathMax(0.0, defaultCloseAt);
   selectedLevel    = 0;

   if(!InpUseBasketProfitProtect)
      return(false);

   if(!InpUseMultiBasketProfitProtect)
      return(selectedActivate > 0.0 && peakProfit >= selectedActivate && selectedCloseAt >= 0.0);

      /*
   if(InpBasketProtectActivateUSD_5 > 0.0 && peakProfit >= InpBasketProtectActivateUSD_5)
     {
      selectedActivate = InpBasketProtectActivateUSD_5;
      selectedCloseAt  = InpBasketProtectCloseAtUSD_5;
      selectedLevel    = 5;
      return(true);
     }

   if(InpBasketProtectActivateUSD_4 > 0.0 && peakProfit >= InpBasketProtectActivateUSD_4)
     {
      selectedActivate = InpBasketProtectActivateUSD_4;
      selectedCloseAt  = InpBasketProtectCloseAtUSD_4;
      selectedLevel    = 4;
      return(true);
     }

   if(InpBasketProtectActivateUSD_3 > 0.0 && peakProfit >= InpBasketProtectActivateUSD_3)
     {
      selectedActivate = InpBasketProtectActivateUSD_3;
      selectedCloseAt  = InpBasketProtectCloseAtUSD_3;
      selectedLevel    = 3;
      return(true);
     }

   if(InpBasketProtectActivateUSD_2 > 0.0 && peakProfit >= InpBasketProtectActivateUSD_2)
     {
      selectedActivate = InpBasketProtectActivateUSD_2;
      selectedCloseAt  = InpBasketProtectCloseAtUSD_2;
      selectedLevel    = 2;
      return(true);
     }

   if(InpBasketProtectActivateUSD_1 > 0.0 && peakProfit >= InpBasketProtectActivateUSD_1)
     {
      selectedActivate = InpBasketProtectActivateUSD_1;
      selectedCloseAt  = InpBasketProtectCloseAtUSD_1;
      selectedLevel    = 1;
      return(true);
     }

   // Dynamic fallback:
   // If no fixed basket level matched, but basket moved into profit,
   // close when basket profit falls back to configured percent of peak profit.
   if(peakProfit >= InpBasketDynamicMinPeakUSD && InpBasketDynamicClosePercent > 0.0)
     {
      selectedActivate = peakProfit;
      selectedCloseAt  = peakProfit * MathMin(100.0, InpBasketDynamicClosePercent) / 100.0;
      selectedLevel    = 0; // dynamic level
      return(true);
     }

     */

   return(false);
  }

//+------------------------------------------------------------------+
void ResetBasketProfitPeaksAfterClose(int direction)
  {
   if(direction == 0)
     {
      g_allBasketPeakProfit  = 0.0;
      g_buyBasketPeakProfit  = 0.0;
      g_sellBasketPeakProfit = 0.0;
      return;
     }

   if(direction == 1)
      g_buyBasketPeakProfit = 0.0;

   if(direction == -1)
      g_sellBasketPeakProfit = 0.0;
  }

//+------------------------------------------------------------------+
bool ProcessFirstPriorityBasketProfitClose(string &status)
  {
   if(InpUseSimpleSideBasketCloseOnly)
     {
      status = "SIMPLE SIDE BASKET ONLY";
      return(false);
     }

   double target = GetBasketProfitTargetUSD();
   if(target <= 0.0)
      return(false);

   RefreshRates();

   int totalOrders = CountAllOrders();
   if(totalOrders <= 0)
     {
      ResetBasketProfitPeaksAfterClose(0);
      return(false);
     }

   double allProfit = GetAllOpenEAOrdersProfit();
   int buyCount  = CountOrdersByDirection(1);
   int sellCount = CountOrdersByDirection(-1);

   double buyProfit  = (buyCount  > 0) ? GetBasketProfit(1)  : 0.0;
   double sellProfit = (sellCount > 0) ? GetBasketProfit(-1) : 0.0;

   // Keep basket peak profit memory.
   if(allProfit > g_allBasketPeakProfit)
      g_allBasketPeakProfit = allProfit;

   if(buyCount > 0)
     {
      if(buyProfit > g_buyBasketPeakProfit)
         g_buyBasketPeakProfit = buyProfit;
     }
   else
      g_buyBasketPeakProfit = 0.0;

   if(sellCount > 0)
     {
      if(sellProfit > g_sellBasketPeakProfit)
         g_sellBasketPeakProfit = sellProfit;
     }
   else
      g_sellBasketPeakProfit = 0.0;

   // BIG CANDLE PROFIT PROTECT:
   // Big candles/spikes are used for profit booking, not for opening new/recovery orders.
   // During a big-candle pause, protect configured percent of the highest combined basket profit.
   CheckBigCandlePauseOnNewBar(true);
   bool bigCandleActiveForProfit = IsBigCandlePauseActive();

   if(InpUseBigCandleProfitProtect &&
      bigCandleActiveForProfit &&
      g_allBasketPeakProfit > 0.0 &&
      allProfit > 0.0)
     {
      double lockPercent = InpBigCandleProfitLockPercent;
      if(lockPercent < 1.0)
         lockPercent = 1.0;
      if(lockPercent > 100.0)
         lockPercent = 100.0;

      double closeAt = g_allBasketPeakProfit * lockPercent / 100.0;

      if(allProfit <= closeAt)
        {
         CloseAllEAOrders(
            "BIG CANDLE PROFIT PROTECT | Peak $" +
            DoubleToString(g_allBasketPeakProfit, 2) +
            " -> Close $" + DoubleToString(allProfit, 2) +
            " | Lock " + DoubleToString(lockPercent, 1) + "%");

         ResetDelayedSARCloseAfterBasketClose(0, "Big candle profit protect reset");
         ResetBasketProfitPeaksAfterClose(0);

         Print("BIG CANDLE PROFIT PROTECT CLOSED | Peak=$",
               DoubleToString(g_allBasketPeakProfit, 2),
               " | Current=$", DoubleToString(allProfit, 2),
               " | CloseAt=$", DoubleToString(closeAt, 2),
               " | LockPercent=", DoubleToString(lockPercent, 1),
               " | LastMove=", DoubleToString(g_lastBigCandleMove, Digits));

         status = "BIG CANDLE PROFIT PROTECT $" + DoubleToString(allProfit, 2);
         return(true);
        }
     }

   // PRIORITY 1A:
   // Fixed target: close all BUY+SELL when combined floating profit reaches target.
   if(allProfit >= target)
     {
      CloseAllEAOrders("FIRST PRIORITY ALL BUY+SELL basket profit $" + DoubleToString(allProfit, 2));

      ResetDelayedSARCloseAfterBasketClose(0, "All basket TP reset");
      ResetBasketProfitPeaksAfterClose(0);

      Print("FIRST PRIORITY ALL BASKET PROFIT HIT | Orders=", totalOrders,
            " | BuyCount=", buyCount,
            " | SellCount=", sellCount,
            " | Profit=$", DoubleToString(allProfit, 2),
            " | Target=$", DoubleToString(target, 2));

      status = "ALL BUY+SELL TP $" + DoubleToString(allProfit, 2);
      return(true);
     }

   // PRIORITY 1B:
   // Basket profit protect: if combined basket first reached profit peak
   // and then profit reduced to protected level, close all.
   double protectActivate = 0.0;
   double protectCloseAt  = 0.0;
   int    protectLevel    = 0;

   if(GetBasketProfitProtectLevel(g_allBasketPeakProfit,
                                  target,
                                  target / 2.0,
                                  protectActivate,
                                  protectCloseAt,
                                  protectLevel))
     {
      if(g_allBasketPeakProfit >= protectActivate &&
         allProfit > 0.0 &&
         allProfit <= protectCloseAt)
        {
         CloseAllEAOrders("ALL BUY+SELL basket profit protect | Peak $" +
                          DoubleToString(g_allBasketPeakProfit, 2) +
                          " -> Close $" + DoubleToString(allProfit, 2));

         ResetDelayedSARCloseAfterBasketClose(0, "All basket protect reset");
         ResetBasketProfitPeaksAfterClose(0);

         Print("ALL BASKET PROFIT PROTECT CLOSED | Level=", protectLevel,
               " | Peak=$", DoubleToString(g_allBasketPeakProfit, 2),
               " | Current=$", DoubleToString(allProfit, 2),
               " | ProtectClose=$", DoubleToString(protectCloseAt, 2));

         status = "ALL BASKET PROTECT $" + DoubleToString(allProfit, 2);
         return(true);
        }
     }

   // PRIORITY 2A:
   // If combined profit is not enough, close the profitable side only
   // when BUY/SELL side reaches fixed target.
   bool closedAnySide = false;
   string closedText = "";

   if(buyCount > 0 && buyProfit >= target)
     {
      CloseOrdersByDirection(1, "FIRST PRIORITY BUY basket profit $" + DoubleToString(buyProfit, 2));
      ResetDelayedSARCloseAfterBasketClose(1, "BUY basket TP reset");
      ResetBasketProfitPeaksAfterClose(1);

      Print("FIRST PRIORITY BUY BASKET PROFIT HIT | BuyCount=", buyCount,
            " | Profit=$", DoubleToString(buyProfit, 2),
            " | Target=$", DoubleToString(target, 2));

      closedAnySide = true;
      closedText = "BUY TP $" + DoubleToString(buyProfit, 2);
     }

   if(sellCount > 0 && sellProfit >= target)
     {
      CloseOrdersByDirection(-1, "FIRST PRIORITY SELL basket profit $" + DoubleToString(sellProfit, 2));
      ResetDelayedSARCloseAfterBasketClose(-1, "SELL basket TP reset");
      ResetBasketProfitPeaksAfterClose(-1);

      Print("FIRST PRIORITY SELL BASKET PROFIT HIT | SellCount=", sellCount,
            " | Profit=$", DoubleToString(sellProfit, 2),
            " | Target=$", DoubleToString(target, 2));

      if(closedText != "")
         closedText += " | ";
      closedText += "SELL TP $" + DoubleToString(sellProfit, 2);
      closedAnySide = true;
     }

   if(closedAnySide)
     {
      status = closedText;
      return(true);
     }

   // PRIORITY 2B:
   // BUY/SELL side basket profit protect.
   if(buyCount > 0 &&
      GetBasketProfitProtectLevel(g_buyBasketPeakProfit,
                                  target,
                                  target / 2.0,
                                  protectActivate,
                                  protectCloseAt,
                                  protectLevel))
     {
      if(g_buyBasketPeakProfit >= protectActivate &&
         buyProfit > 0.0 &&
         buyProfit <= protectCloseAt)
        {
         CloseOrdersByDirection(1, "BUY basket profit protect | Peak $" +
                                DoubleToString(g_buyBasketPeakProfit, 2) +
                                " -> Close $" + DoubleToString(buyProfit, 2));
         ResetDelayedSARCloseAfterBasketClose(1, "BUY basket protect reset");
         ResetBasketProfitPeaksAfterClose(1);

         Print("BUY BASKET PROFIT PROTECT CLOSED | Level=", protectLevel,
               " | Peak=$", DoubleToString(g_buyBasketPeakProfit, 2),
               " | Current=$", DoubleToString(buyProfit, 2),
               " | ProtectClose=$", DoubleToString(protectCloseAt, 2));

         status = "BUY BASKET PROTECT $" + DoubleToString(buyProfit, 2);
         return(true);
        }
     }

   if(sellCount > 0 &&
      GetBasketProfitProtectLevel(g_sellBasketPeakProfit,
                                  target,
                                  target / 2.0,
                                  protectActivate,
                                  protectCloseAt,
                                  protectLevel))
     {
      if(g_sellBasketPeakProfit >= protectActivate &&
         sellProfit > 0.0 &&
         sellProfit <= protectCloseAt)
        {
         CloseOrdersByDirection(-1, "SELL basket profit protect | Peak $" +
                                DoubleToString(g_sellBasketPeakProfit, 2) +
                                " -> Close $" + DoubleToString(sellProfit, 2));
         ResetDelayedSARCloseAfterBasketClose(-1, "SELL basket protect reset");
         ResetBasketProfitPeaksAfterClose(-1);

         Print("SELL BASKET PROFIT PROTECT CLOSED | Level=", protectLevel,
               " | Peak=$", DoubleToString(g_sellBasketPeakProfit, 2),
               " | Current=$", DoubleToString(sellProfit, 2),
               " | ProtectClose=$", DoubleToString(protectCloseAt, 2));

         status = "SELL BASKET PROTECT $" + DoubleToString(sellProfit, 2);
         return(true);
        }
     }

   return(false);
  }


void ResetBigCandlePauseState()
  {
   g_bigCandlePause = false;
   g_bigCandlePauseUntil = 0;
   g_bigCandlePauseSARDirection = 0;
   g_lastBigCandleMove = 0.0;
   g_lastBigCandleFormationBarTime = 0;
   g_notifyBigCandlePauseSent = false;
  }

//+------------------------------------------------------------------+
//| Draw red marker/box on big candle                                |
//+------------------------------------------------------------------+
void DrawBigCandleRedMarker(int shift, double move, string reason)
  {
   if(!InpDrawBigCandleRedMarker)
      return;

   if(shift < 0 || Bars <= shift + 1)
      return;

   datetime t1 = Time[shift];
   datetime t2 = t1 + Period() * 60;
   if(shift > 0)
      t2 = Time[shift - 1];

   string baseName  = OBJ_PREFIX + "BIG_CANDLE_RED_" + IntegerToString((int)t1);
   string rectName  = baseName + "_RECT";
   string arrowName = baseName + "_ARROW";

   // Avoid repeated object creation on every tick for same candle.
   if(ObjectFind(0, rectName) >= 0 || ObjectFind(0, arrowName) >= 0)
      return;

   double h = iHigh(Symbol(), PERIOD_M1, shift);
   double l = iLow(Symbol(), PERIOD_M1, shift);

   string label = "BIG CANDLE RED | Move=" + DoubleToString(move, 1) + " | " + reason;

   if(ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, t1, h, t2, l))
     {
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, InpBigCandleMarkerColor);
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
      ObjectSetString(0, rectName, OBJPROP_TEXT, label);
     }

   double markerPrice = h + MathMax(30 * Point, MarketInfo(Symbol(), MODE_SPREAD) * Point);
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t1, markerPrice))
     {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, InpBigCandleMarkerArrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, InpBigCandleMarkerColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetString(0, arrowName, OBJPROP_TEXT, label);
     }
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
//| Big candle/spike formation protection                            |
//| This checks the CURRENT forming candle High[0]-Low[0].            |
//| If the current candle is already a spike, block all new orders    |
//| immediately instead of waiting for candle close.                  |
//+------------------------------------------------------------------+
void CheckBigCandleFormationPauseOnTick()
  {
   if(!InpUseBigCandlePause)
      return;

   if(!InpUseBigCandleFormationBlock)
      return;

   if(Bars < 10)
      return;

   double formingMove = MathAbs(High[0] - Low[0]);
   if(formingMove < InpBigCandleRawDifference)
      return;

   datetime formingBarTime = Time[0];

   // Avoid repeating the same start log every tick for the same forming candle.
   if(g_bigCandlePause && g_lastBigCandleFormationBarTime == formingBarTime)
      return;

   int sarDirection = g_activeSARDirection;
   if(sarDirection == 0)
      sarDirection = GetSARDotDirection(0);
   if(sarDirection == 0)
      sarDirection = GetSARDotDirection(1);

   int candleDirection = 0;
   if(Close[0] > Open[0])
      candleDirection = 1;
   else if(Close[0] < Open[0])
      candleDirection = -1;

   g_lastBigCandleFormationBarTime = formingBarTime;
   g_lastBigCandleMove = formingMove;
   g_bigCandlePause = true;
   g_bigCandlePauseUntil = TimeCurrent() + MathMax(1, InpBigCandlePauseMinutes) * 60;
   g_bigCandlePauseSARDirection = sarDirection;
   g_notifyBigCandlePauseSent = true;

   DrawBigCandleRedMarker(0, formingMove, "FORMING CANDLE");

   Print("BIG CANDLE FORMATION / SPIKE PAUSE STARTED | CurrentMove=", DoubleToString(formingMove, Digits),
         " Required=", DoubleToString(InpBigCandleRawDifference, Digits),
         " Candle=", DirectionText(candleDirection),
         " SAR=", DirectionText(g_bigCandlePauseSARDirection),
         " PauseUntil=", TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS),
         " | Normal and recovery orders blocked");

   if(InpNotifyOnBigCandlePause)
     {
      SendEAAlert("TRADING PAUSED - BIG CANDLE FORMING",
                  "CurrentMove=" + DoubleToString(formingMove,2) +
                  " | Candle=" + DirectionText(candleDirection) +
                  " | SAR=" + DirectionText(g_bigCandlePauseSARDirection) +
                  " | Pause=" + IntegerToString(InpBigCandlePauseMinutes) + "m" +
                  " | Normal/recovery blocked");
     }
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

// Big candle protection:
// Any big candle now pauses NEW normal SAR orders, including SAR_FLIP_V2LAST.
// Same-direction big candle no longer bypasses the pause. Recovery/close management still runs.
   if(candleDirection == 0 || sarDirection == 0)
     {
      Print("BIG CANDLE IGNORED | No clear SAR/candle direction | SAR=", DirectionText(sarDirection),
            " | Candle=", DirectionText(candleDirection),
            " | Move=", DoubleToString(candleMove, Digits));
      return;
     }

   g_bigCandlePause = true;
   g_bigCandlePauseUntil = TimeCurrent() + MathMax(1, InpBigCandlePauseMinutes) * 60;
   g_bigCandlePauseSARDirection = sarDirection;
   g_notifyBigCandlePauseSent = true;

   DrawBigCandleRedMarker(1, candleMove, "CLOSED CANDLE");

   Print("BIG CANDLE PAUSE STARTED - BLOCK SAR_FLIP_V2LAST | Move=", DoubleToString(candleMove, Digits),
         " Required=", DoubleToString(InpBigCandleRawDifference, Digits),
         " Candle=", DirectionText(candleDirection),
         " SAR=", DirectionText(g_bigCandlePauseSARDirection),
         " PauseUntil=", TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS));

   if(InpNotifyOnBigCandlePause)
     {
      SendEAAlert("TRADING PAUSED - BIG CANDLE",
                  "Move=" + DoubleToString(candleMove,2) +
                  " | Candle=" + DirectionText(candleDirection) +
                  " | SAR=" + DirectionText(g_bigCandlePauseSARDirection) +
                  " | Pause=" + IntegerToString(InpBigCandlePauseMinutes) + "m" +
                  " | SAR_FLIP_V2LAST blocked");
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

   // Also detect current forming candle spikes before any order creation.
   CheckBigCandleFormationPauseOnTick();

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

   if(timeCompleted)
   {
      Print("BIG CANDLE PAUSE FINISHED | SAR_FLIP_V2LAST allowed again | PauseUntil=",
            TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS));
      ResetBigCandlePauseState();
      return(false);
   }

   return(true);
}


//+------------------------------------------------------------------+
//| Strong big-candle gate for ALL order creation                    |
//| This is stricter than the visual pause check. It checks current   |
//| forming candle and recent closed candles, then starts/extends      |
//| pause immediately. Used before SAR, recovery gap and hedge orders.|
//+------------------------------------------------------------------+
bool EnforceBigCandleOrderBlock(string source)
  {
   if(EnforceSpikeWickOrderBlock(source, InpSpikeWickBlockRecovery, InpSpikeWickBlockGuard))
      return(true);

   if(!InpUseBigCandlePause)
      return(false);

   if(Bars < 10)
      return(IsBigCandlePauseActive());

   double maxMove = 0.0;
   int maxShift = -1;

   int maxScanShift = 2; // shift 0 = forming candle, 1/2 = just closed candles
   for(int s = 0; s <= maxScanShift; s++)
     {
      double move = MathAbs(High[s] - Low[s]);
      if(move > maxMove)
        {
         maxMove = move;
         maxShift = s;
        }
     }

   // NEW SAFETY:
   // Last 3 CLOSED candles combined range pause.
   // Example: High of candles 1..3 minus Low of candles 1..3 >= 200
   // means market is too volatile; block normal orders, recovery, recovery-gap and hedge.
   double last3Move = 0.0;
   if(InpUseLast3CandlesMovePause && Bars > 10)
     {
      double highest3 = High[1];
      double lowest3  = Low[1];

      for(int c = 2; c <= 3; c++)
        {
         if(High[c] > highest3)
            highest3 = High[c];

         if(Low[c] < lowest3)
            lowest3 = Low[c];
        }

      last3Move = MathAbs(highest3 - lowest3);
     }

   if(InpUseLast3CandlesMovePause &&
      InpLast3CandlesRawDifference > 0.0 &&
      last3Move >= InpLast3CandlesRawDifference)
     {
      int pauseMinutes3 = MathMax(1, InpLast3CandlesPauseMinutes);
      if(InpBlockRecoveryGapOnBigCandle)
         pauseMinutes3 = MathMax(pauseMinutes3, MathMax(1, InpBigCandleRecoveryPauseMinutes));

      datetime newUntil3 = TimeCurrent() + pauseMinutes3 * 60;
      if(!g_bigCandlePause || newUntil3 > g_bigCandlePauseUntil)
         g_bigCandlePauseUntil = newUntil3;

      g_bigCandlePause = true;
      g_lastBigCandleMove = last3Move;
      g_lastBigCandlePauseBarTime = Time[1];

      g_bigCandlePauseSARDirection = g_activeSARDirection;
      if(g_bigCandlePauseSARDirection == 0)
         g_bigCandlePauseSARDirection = GetSARDotDirection(1);

      DrawBigCandleRedMarker(1, last3Move, "LAST 3 CANDLES MOVE");

      Print("LAST 3 CANDLES MOVE ORDER BLOCK ACTIVE | Source=", source,
            " | Move=", DoubleToString(last3Move, Digits),
            " | Required=", DoubleToString(InpLast3CandlesRawDifference, Digits),
            " | PauseUntil=", TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS),
            " | Normal/Recovery/RecoveryGap/Hedge blocked");

      return(true);
     }

   if(maxMove >= InpBigCandleRawDifference)
     {
      int pauseMinutes = MathMax(1, InpBigCandlePauseMinutes);
      if(InpBlockRecoveryGapOnBigCandle)
         pauseMinutes = MathMax(pauseMinutes, MathMax(1, InpBigCandleRecoveryPauseMinutes));

      datetime newUntil = TimeCurrent() + pauseMinutes * 60;
      if(!g_bigCandlePause || newUntil > g_bigCandlePauseUntil)
         g_bigCandlePauseUntil = newUntil;

      g_bigCandlePause = true;
      g_lastBigCandleMove = maxMove;
      if(maxShift == 0)
         g_lastBigCandleFormationBarTime = Time[0];
      else
         g_lastBigCandlePauseBarTime = Time[maxShift];

      int candleDirection = 0;
      if(Close[maxShift] > Open[maxShift]) candleDirection = 1;
      else if(Close[maxShift] < Open[maxShift]) candleDirection = -1;

      g_bigCandlePauseSARDirection = g_activeSARDirection;
      if(g_bigCandlePauseSARDirection == 0)
         g_bigCandlePauseSARDirection = GetSARDotDirection(1);

      DrawBigCandleRedMarker(maxShift, maxMove, "ORDER BLOCK");

      Print("BIG CANDLE ORDER BLOCK ACTIVE | Source=", source,
            " | Shift=", maxShift,
            " | Move=", DoubleToString(maxMove, Digits),
            " | Required=", DoubleToString(InpBigCandleRawDifference, Digits),
            " | Candle=", DirectionText(candleDirection),
            " | PauseUntil=", TimeToString(g_bigCandlePauseUntil, TIME_DATE|TIME_SECONDS),
            " | Normal/Recovery/RecoveryGap/Hedge blocked");

      return(true);
     }

   return(IsBigCandlePauseActive());
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
          " | ALL ORDERS BLOCKED | LastMove=" + DoubleToString(g_lastBigCandleMove, 1));
  }

//+------------------------------------------------------------------+
//| Spike / wick pause filter                                        |
//+------------------------------------------------------------------+
void ResetSpikeWickPauseState()
  {
   g_spikeWickPause = false;
   g_spikeWickPauseUntil = 0;
   g_lastSpikeWickBarTime = 0;
   g_lastSpikeWickWickSize = 0.0;
   g_lastSpikeWickBodyPercent = 0.0;
   g_lastSpikeWickRangeSize = 0.0;
   g_lastSpikeWickBodySize = 0.0;
   g_lastSpikeWickShift = -1;
   g_spikeWickLastReason = "OFF";
  }

//+------------------------------------------------------------------+
bool IsSpikeWickCandle(int shift, string &reason, double &maxWick, double &bodyPercent, double &rangeSize, double &bodySize)
  {
   reason = "";
   maxWick = 0.0;
   bodyPercent = 100.0;
   rangeSize = 0.0;
   bodySize = 0.0;

   if(!InpUseSpikeWickPauseFilter)
      return(false);

   if(Bars <= shift + 5 || shift < 0)
      return(false);

   double o = iOpen(Symbol(), PERIOD_M1, shift);
   double c = iClose(Symbol(), PERIOD_M1, shift);
   double h = iHigh(Symbol(), PERIOD_M1, shift);
   double l = iLow(Symbol(), PERIOD_M1, shift);

   bodySize = MathAbs(c - o);
   rangeSize = h - l;

   if(rangeSize <= 0.0)
      return(false);

   double upperWick = h - MathMax(o, c);
   double lowerWick = MathMin(o, c) - l;
   maxWick = MathMax(upperWick, lowerWick);
   bodyPercent = (bodySize / rangeSize) * 100.0;

   bool wickLarge     = (InpSpikeWickMinRawPrice > 0.0 && maxWick >= InpSpikeWickMinRawPrice);
   bool bodySmall     = (bodyPercent <= InpSpikeWickBodyMaxPercent);
   bool rangeSpike    = (InpSpikeMomentumRangeRawPrice > 0.0 && rangeSize >= InpSpikeMomentumRangeRawPrice);
   bool momentumSpike = (InpSpikeMomentumBodyRawPrice > 0.0 && bodySize >= InpSpikeMomentumBodyRawPrice);

   // 1) Classic wick spike: long upper/lower wick and small body.
   if(wickLarge && bodySmall)
     {
      string side = "WICK";
      if(upperWick >= lowerWick && upperWick >= InpSpikeWickMinRawPrice)
         side = "UPPER WICK";
      else if(lowerWick > upperWick && lowerWick >= InpSpikeWickMinRawPrice)
         side = "LOWER WICK";

      reason = "SPIKE/" + side +
               " | Range=" + DoubleToString(rangeSize, 1) +
               " | Body=" + DoubleToString(bodySize, 1) +
               " | Wick=" + DoubleToString(maxWick, 1) +
               " | Body%=" + DoubleToString(bodyPercent, 1);
      return(true);
     }

   // 2) Momentum spike: full-body fast candle without a long wick.
   // This catches candles like Range=185 and Body=118 that were not detected by wick-only logic.
   if(rangeSpike || momentumSpike)
     {
      string type = "MOMENTUM SPIKE";
      if(rangeSpike && !momentumSpike)
         type = "LONG RANGE SPIKE";
      else if(momentumSpike && !rangeSpike)
         type = "LONG BODY SPIKE";

      reason = type +
               " | Range=" + DoubleToString(rangeSize, 1) +
               " | Body=" + DoubleToString(bodySize, 1) +
               " | Wick=" + DoubleToString(maxWick, 1) +
               " | Body%=" + DoubleToString(bodyPercent, 1);
      return(true);
     }

   return(false);
  }


//+------------------------------------------------------------------+
//| Draw different color marker when SAR weak signal is detected      |
//+------------------------------------------------------------------+
void DrawSARWeakSignalMarker(int shift, string reason)
  {
   if(!InpDrawSARWeakSignalMarker)
      return;

   if(shift < 0 || Bars <= shift + 1)
      return;

   datetime t1 = Time[shift];
   datetime t2 = t1 + Period() * 60;
   if(shift > 0)
      t2 = Time[shift - 1];

   string baseName  = OBJ_PREFIX + "SAR_WEAK_SIGNAL_" + IntegerToString((int)t1);
   string rectName  = baseName + "_RECT";
   string arrowName = baseName + "_ARROW";

   // Current candle changes while forming, so refresh the marker.
   ObjectDelete(0, rectName);
   ObjectDelete(0, arrowName);

   double h = iHigh(Symbol(), PERIOD_M1, shift);
   double l = iLow(Symbol(), PERIOD_M1, shift);

   string label = "SAR WEAK SIGNAL | " + reason;

   if(ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, t1, h, t2, l))
     {
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, InpSARWeakSignalMarkerColor);
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
      ObjectSetString(0, rectName, OBJPROP_TEXT, label);
     }

   double markerPrice = h + MathMax(40 * Point, MarketInfo(Symbol(), MODE_SPREAD) * Point);
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t1, markerPrice))
     {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, InpSARWeakSignalMarkerArrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, InpSARWeakSignalMarkerColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 4);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetString(0, arrowName, OBJPROP_TEXT, label);
     }

   g_lastSARWeakSignalMarkerBarTime = t1;
   g_lastSARWeakSignalMarkerReason  = reason;
  }

//+------------------------------------------------------------------+
void DrawSpikeWickYellowMarker(int shift, string reason)
  {
   if(!InpDrawSpikeWickYellowMarker)
      return;

   if(shift < 0 || Bars <= shift + 1)
      return;

   datetime t1 = Time[shift];
   datetime t2 = t1 + Period() * 60;
   if(shift > 0)
      t2 = Time[shift - 1];

   string baseName = OBJ_PREFIX + "SPIKE_WICK_YELLOW_" + IntegerToString((int)t1);
   string rectName = baseName + "_RECT";
   string arrowName = baseName + "_ARROW";

   ObjectDelete(0, rectName);
   ObjectDelete(0, arrowName);

   double h = iHigh(Symbol(), PERIOD_M1, shift);
   double l = iLow(Symbol(), PERIOD_M1, shift);

   if(ObjectCreate(0, rectName, OBJ_RECTANGLE, 0, t1, h, t2, l))
     {
      ObjectSetInteger(0, rectName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, rectName, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, rectName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, rectName, OBJPROP_BACK, false);
      ObjectSetString(0, rectName, OBJPROP_TEXT, reason);
     }

   double markerPrice = h + MathMax(20 * Point, MarketInfo(Symbol(), MODE_SPREAD) * Point);
   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, t1, markerPrice))
     {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, InpSpikeWickMarkerArrowCode);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, arrowName, OBJPROP_BACK, false);
      ObjectSetString(0, arrowName, OBJPROP_TEXT, reason);
     }
  }

//+------------------------------------------------------------------+
void StartSpikeWickPause(int shift, string reason, double maxWick, double bodyPercent, double rangeSize, double bodySize, string source)
  {
   int pauseMinutes = MathMax(1, InpSpikeWickPauseMinutes);
   datetime newUntil = TimeCurrent() + pauseMinutes * 60;

   if(!g_spikeWickPause || newUntil > g_spikeWickPauseUntil)
      g_spikeWickPauseUntil = newUntil;

   g_spikeWickPause = true;
   g_lastSpikeWickShift = shift;
   g_lastSpikeWickBarTime = Time[shift];
   g_lastSpikeWickWickSize = maxWick;
   g_lastSpikeWickBodyPercent = bodyPercent;
   g_lastSpikeWickRangeSize = rangeSize;
   g_lastSpikeWickBodySize = bodySize;
   g_spikeWickLastReason = reason + " | Pause " + IntegerToString(pauseMinutes) + "m";

   DrawSpikeWickYellowMarker(shift, reason);

   SetLastOrderBlockDashboard(g_spikeWickLastReason + " | Source=" + source);

   Print("SPIKE/WICK PAUSE STARTED | Source=", source,
         " | Shift=", shift,
         " | ", reason,
         " | PauseUntil=", TimeToString(g_spikeWickPauseUntil, TIME_DATE|TIME_SECONDS),
         " | New normal/recovery/guard orders blocked");
  }

//+------------------------------------------------------------------+
bool IsSpikeWickPauseActive()
  {
   if(!InpUseSpikeWickPauseFilter)
      return(false);

   if(!g_spikeWickPause)
      return(false);

   if(TimeCurrent() >= g_spikeWickPauseUntil)
     {
      Print("SPIKE/WICK PAUSE FINISHED | LastReason=", g_spikeWickLastReason);
      ResetSpikeWickPauseState();
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
bool EnforceSpikeWickOrderBlock(string source, bool blockRecovery, bool blockGuard)
  {
   if(!InpUseSpikeWickPauseFilter)
      return(false);

   if(StringFind(source, "Recovery") >= 0 || StringFind(source, "RECOVERY") >= 0)
     {
      if(!blockRecovery)
         return(false);
     }

   if(StringFind(source, "Guard") >= 0 || StringFind(source, "GUARD") >= 0)
     {
      if(!blockGuard)
         return(false);
     }

   string reason0 = "", reason1 = "";
   double wick0 = 0.0, wick1 = 0.0, bodyPct0 = 0.0, bodyPct1 = 0.0;
   double range0 = 0.0, range1 = 0.0, body0 = 0.0, body1 = 0.0;

   if(IsSpikeWickCandle(0, reason0, wick0, bodyPct0, range0, body0))
     {
      StartSpikeWickPause(0, reason0, wick0, bodyPct0, range0, body0, source);
      return(true);
     }

   if(IsSpikeWickCandle(1, reason1, wick1, bodyPct1, range1, body1))
     {
      // avoid restarting every tick for the same closed candle, but keep active pause blocking
      if(Time[1] != g_lastSpikeWickBarTime)
         StartSpikeWickPause(1, reason1, wick1, bodyPct1, range1, body1, source);
      else if(!g_spikeWickPause)
         StartSpikeWickPause(1, reason1, wick1, bodyPct1, range1, body1, source);

      return(true);
     }

   if(IsSpikeWickPauseActive())
     {
      SetLastOrderBlockDashboard("SPIKE/WICK PAUSE ACTIVE | " + SpikeWickPauseStatusText() + " | Source=" + source);
      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
string SpikeWickPauseStatusText()
  {
   if(!InpUseSpikeWickPauseFilter)
      return("OFF");

   if(!g_spikeWickPause)
      return("OFF");

   int secondsLeft = (int)(g_spikeWickPauseUntil - TimeCurrent());
   if(secondsLeft < 0)
      secondsLeft = 0;

   return("ON " + FormatSecondsToHHMM(secondsLeft) +
          " | Range=" + DoubleToString(g_lastSpikeWickRangeSize, 1) +
          " | Body=" + DoubleToString(g_lastSpikeWickBodySize, 1) +
          " | Wick=" + DoubleToString(g_lastSpikeWickWickSize, 1) +
          " | Body%=" + DoubleToString(g_lastSpikeWickBodyPercent, 1));
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
   // DISABLED BY DESIGN:
   // Recovery orders should NOT close immediately at a fixed profit target.
   // They must close only after:
   // 1) Order profit first reaches InpIndividualProtectActivateUSD, and
   // 2) Profit falls back to InpIndividualProtectCloseAtUSD.
   // This logic is handled by ProcessIndividualProfitProtect().
   return;
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

   // Big candle protection: do not create recovery orders during/after a big candle pause.
   CheckBigCandlePauseOnNewBar(true);
   if(EnforceBigCandleOrderBlock("OpenRecoveryOrder " + sourceReason))
     {
      Print("RECOVERY ORDER BLOCKED BY BIG CANDLE PAUSE | Source=", sourceReason,
            " | ", BigCandlePauseStatusText());
      return(false);
     }

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
                          GetOrderIconColorByComment(direction, comment));

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
   MarkOpenedOrderOnChart(ticket, direction, comment, TimeCurrent(), price);

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

      if(IsRecoveryGapOrderComment(OrderComment()))
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

      // SAR special guard orders are hedge/protection orders.
      // They must NOT become parent/base orders for recovery gap logic.
      if(IsSARGuardOrderComment(OrderComment()))
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
bool IsRecoveryHedgeOrderComment(string commentText)
  {
   return(StringFind(commentText, "RECOVERY_HEDGE") >= 0);
  }

//+------------------------------------------------------------------+
bool OpenReverseOrderForRecovery(int recoveryDirection, int recoveryNumber, double recoveryGapMove)
  {
   if(!InpOpenReverseOrderWithRecovery)
      return(false);

   if(recoveryDirection == 0)
      return(false);

   // Big candle protection: do not create recovery hedge/reverse orders during/after a big candle pause.
   CheckBigCandlePauseOnNewBar(true);
   if(EnforceBigCandleOrderBlock("OpenReverseOrderForRecovery"))
     {
      Print("RECOVERY HEDGE BLOCKED BY BIG CANDLE PAUSE | RecoveryDirection=",
            DirectionText(recoveryDirection), " | ", BigCandlePauseStatusText());
      return(false);
     }

   int reverseDirection = -recoveryDirection;

   if(!IsTradingAllowedNow())
     {
      Print("RECOVERY HEDGE BLOCKED | Trading not allowed | RecoveryDirection=",
            DirectionText(recoveryDirection));
      return(false);
     }

   RefreshRates();

   if(IsTotalOpenOrderCapReached("OpenReverseOrderForRecovery"))
      return(false);

   if(CheckEquityConditions())
     {
      Print("RECOVERY HEDGE BLOCKED | Equity/profit lock active.");
      return(false);
     }

   if(MarketInfo(Symbol(), MODE_SPREAD) > InpMaxSpreadPoints)
     {
      Print("RECOVERY HEDGE BLOCKED | Spread=", MarketInfo(Symbol(), MODE_SPREAD),
            " > MaxSpread=", InpMaxSpreadPoints);
      return(false);
     }

   int type = reverseDirection == 1 ? OP_BUY : OP_SELL;
   double price = reverseDirection == 1 ? Ask : Bid;
   double lotInput = InpRecoveryReverseLot > 0.0 ? InpRecoveryReverseLot : InpRecoveryGapLot;
   double lot = NormalizeLot(lotInput);

   string comment = "RECOVERY_HEDGE_FROM_" + IntegerToString(recoveryNumber) +
                    "_" + DirectionText(reverseDirection);

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
                          GetOrderIconColorByComment(reverseDirection, comment));

   if(ticket < 0)
     {
      int err = GetLastError();
      Print("RECOVERY HEDGE ORDER FAILED | RecoveryDirection=", DirectionText(recoveryDirection),
            " | HedgeDirection=", DirectionText(reverseDirection),
            " | RecoveryNo=", recoveryNumber,
            " | GapMove=", DoubleToString(recoveryGapMove, Digits),
            " | Error=", err);
      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();
   MarkOpenedOrderOnChart(ticket, reverseDirection, comment, TimeCurrent(), price);

   Print("RECOVERY HEDGE ORDER OPENED | Ticket=", ticket,
         " | RecoveryDirection=", DirectionText(recoveryDirection),
         " | HedgeDirection=", DirectionText(reverseDirection),
         " | Lot=", DoubleToString(lot, 2),
         " | RecoveryNo=", recoveryNumber,
         " | GapMove=", DoubleToString(recoveryGapMove, Digits),
         " | Protect=", DoubleToString(InpIndividualProtectActivateUSD, 2),
         " -> ", DoubleToString(InpIndividualProtectCloseAtUSD, 2),
         " | Comment=", comment);

   return(true);
  }

//+------------------------------------------------------------------+
bool OpenRecoveryGapMarketOrder(int direction, double gapMove)
  {
   if(direction == 0)
      return(false);

   UpdateAutoMarketFlowMode();
   if(!IsAutoMarketRecoveryAllowed())
     {
      Print("RECOVERY GAP BLOCKED BY MARKET MODE | ", AutoMarketModeStatusText());
      SetLastOrderBlockDashboard("RECOVERY BLOCKED BY MARKET MODE | " + AutoMarketModeStatusText());
      return(false);
     }

   if(InpRecoveryGapMustMatchSARDirection && direction != g_activeSARDirection)
     {
      Print("RECOVERY GAP BLOCKED | SAR direction mismatch | RecoveryDir=",
            DirectionText(direction),
            " | ActiveSAR=", DirectionText(g_activeSARDirection));
      return(false);
     }

   // H1 trend filter for recovery gap orders.
   // Recovery gap order is created only when H1 trend is in the same direction.
   if(!IsRecoveryGapAllowedByH1Trend(direction))
      return(false);

   // Big candle protection: do not create recovery gap orders during/after a big candle pause.
   CheckBigCandlePauseOnNewBar(true);
   if(EnforceBigCandleOrderBlock("OpenRecoveryGapMarketOrder"))
     {
      Print("RECOVERY GAP BLOCKED BY BIG CANDLE PAUSE | Direction=", DirectionText(direction),
            " | GapMove=", DoubleToString(gapMove, Digits),
            " | ", BigCandlePauseStatusText());
      return(false);
     }

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

// lot=lot*nextRecoveryNumber;

   double requiredGapForComment = InpRecoveryGapRawPrice * nextRecoveryNumber;
   int linkedParentTicket = GetParentTicketForRecoveryGap(direction);

   string comment = InpSARRecoveryGapOrderPrefix + IntegerToString(linkedParentTicket) +
                    "_N" + IntegerToString(nextRecoveryNumber) +
                    "_G" + DoubleToString(requiredGapForComment, 0) +
                    "_" + DirectionText(direction);

   // Keep tag and parent ticket safe from broker comment truncation.
   if(StringLen(comment) > 30)
      comment = StringSubstr(comment, 0, 30);

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
                          GetOrderIconColorByComment(direction, comment));

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
   MarkOpenedOrderOnChart(ticket, direction, comment, TimeCurrent(), price);

   Print("RECOVERY GAP ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | Lot=", DoubleToString(lot, 2),
         " | RecoveryNo=", nextRecoveryNumber,
         " | RequiredGap=", DoubleToString(requiredGapForComment, Digits),
         " | ActualGap=", DoubleToString(gapMove, Digits),
         " | Comment=", comment);

   // After a recovery order is opened, open one reverse swing/hedge order.
   // Example: BUY recovery -> SELL hedge, SELL recovery -> BUY hedge.
   // The hedge is tagged as RECOVERY_HEDGE so ProcessIndividualProfitProtect()
   // will close it only after 0.50 peak -> 0.40 pullback.
   OpenReverseOrderForRecovery(direction, nextRecoveryNumber, gapMove);

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
   datetime oldestTime = 0;

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

      // Reverse swing/hedge orders must not become the base for a new recovery ladder.
      if(IsRecoveryHedgeOrderComment(OrderComment()))
         continue;

      // SAR special guard orders protect a parent ticket only.
      // Do not use them to calculate recovery gap base or side order count.
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      sideOrders++;

      if(oldestTime == 0 || OrderOpenTime() < oldestTime)
      {
         oldestTime = OrderOpenTime();
         basePrice = OrderOpenPrice();
      }
   }

   return(sideOrders > 0);
}
bool GetRecoveryLadderBasePriceOld(int direction, double &basePrice, int &sideOrders)
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

      // SAR special guard orders are hedge/protection orders.
      // They must NOT become parent/base orders for recovery gap logic.
      if(IsSARGuardOrderComment(OrderComment()))
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

   // Gap must always be verified from the OLDEST open order price.
   // Recovery #1 = base +/- 150
   // Recovery #2 = base +/- 300
   // Recovery #3 = base +/- 450
   return(InpRecoveryGapRawPrice * (recoveryCount + 1));
  }


//+------------------------------------------------------------------+
void ClearPendingRecoveryGap(string reason)
  {
   if(g_pendingRecoveryGapDirection == 0)
      return;

   Print("PENDING RECOVERY GAP CLEARED | Direction=",
         DirectionText(g_pendingRecoveryGapDirection),
         " | StoredGap=", DoubleToString(g_pendingRecoveryGapMove, Digits),
         " | RequiredGap=", DoubleToString(g_pendingRecoveryRequiredGap, Digits),
         " | Reason=", reason);

   g_pendingRecoveryGapDirection = 0;
   g_pendingRecoveryGapMove      = 0.0;
   g_pendingRecoveryRequiredGap  = 0.0;
   g_pendingRecoveryGapTime      = 0;
   g_pendingRecoveryGapReason    = "NONE";
  }

//+------------------------------------------------------------------+
void RememberPendingRecoveryGap(int direction,
                                double gapMove,
                                double requiredGap,
                                string reason)
  {
   if(!InpKeepPendingRecoveryGapAfterBlock)
      return;

   if(direction == 0)
      return;

   if(gapMove < requiredGap)
      return;

   // Keep the strongest pending gap seen.
   if(g_pendingRecoveryGapDirection == direction &&
      g_pendingRecoveryGapMove >= gapMove)
      return;

   g_pendingRecoveryGapDirection = direction;
   g_pendingRecoveryGapMove      = gapMove;
   g_pendingRecoveryRequiredGap  = requiredGap;
   g_pendingRecoveryGapTime      = TimeCurrent();
   g_pendingRecoveryGapReason    = reason;

   Print("PENDING RECOVERY GAP SAVED | Direction=", DirectionText(direction),
         " | Gap=", DoubleToString(gapMove, Digits),
         " | Required=", DoubleToString(requiredGap, Digits),
         " | ActiveSAR=", DirectionText(g_activeSARDirection),
         " | Reason=", reason);
  }

//+------------------------------------------------------------------+
bool TryOpenPendingRecoveryGap()
  {
   if(!InpKeepPendingRecoveryGapAfterBlock ||
      !InpOpenPendingRecoveryWhenSARMatches)
      return(false);

   if(g_pendingRecoveryGapDirection == 0)
      return(false);

   if(!IsAutoMarketRecoveryAllowed())
      return(false);

   int direction = g_pendingRecoveryGapDirection;

   // Wait until SAR is aligned with the stored recovery direction.
   if(InpRecoveryGapMustMatchSARDirection &&
      direction != g_activeSARDirection)
      return(false);

   // Wait until H1 trend also matches the stored recovery direction.
   if(!IsRecoveryGapAllowedByH1Trend(direction))
      return(false);

   double basePrice = 0.0;
   int sideOrders = 0;

   if(!GetRecoveryLadderBasePrice(direction, basePrice, sideOrders))
     {
      ClearPendingRecoveryGap("No base order left");
      return(false);
     }

   if(CountRecoveryGapOrdersByDirection(direction) >= InpMaxRecoveryGapOrdersPerSide)
     {
      ClearPendingRecoveryGap("Max recovery reached");
      return(false);
     }

   double currentGap = GetRecoveryLadderCurrentGap(direction, basePrice);

   // If market fully recovered, pending recovery is no longer needed.
   if(currentGap <= 0.0)
     {
      ClearPendingRecoveryGap("Basket no longer adverse");
      return(false);
     }

   double gapForOrder = MathMax(currentGap, g_pendingRecoveryGapMove);

   Print("TRY PENDING RECOVERY GAP | Direction=", DirectionText(direction),
         " | ActiveSAR=", DirectionText(g_activeSARDirection),
         " | CurrentGap=", DoubleToString(currentGap, Digits),
         " | StoredGap=", DoubleToString(g_pendingRecoveryGapMove, Digits),
         " | Required=", DoubleToString(g_pendingRecoveryRequiredGap, Digits),
         " | SavedAt=", TimeToString(g_pendingRecoveryGapTime, TIME_DATE|TIME_SECONDS),
         " | OriginalReason=", g_pendingRecoveryGapReason);

   if(OpenRecoveryGapMarketOrder(direction, gapForOrder))
     {
      ClearPendingRecoveryGap("Opened pending recovery");
      return(true);
     }

   // Keep pending when opening is still blocked by temporary conditions.
   return(false);
  }

//+------------------------------------------------------------------+
void ProcessRecoveryGapOrders()
  {
   if(!InpUseRecoveryGapOrders)
      return;

   if(!IsAutoMarketRecoveryAllowed())
     {
      SetLastOrderBlockDashboard("RECOVERY BLOCKED BY MARKET MODE | " + AutoMarketModeStatusText());
      Print("RECOVERY GAP BLOCKED BY MARKET MODE | ", AutoMarketModeStatusText());
      return;
     }

   // Big candle protection: recovery orders are reverse-trend risk, so block them too.
   // This check is run here because recovery processing may happen before the normal new-order gate.
   CheckBigCandlePauseOnNewBar(true);
   if(EnforceBigCandleOrderBlock("ProcessRecoveryGapOrders"))
     {
      Print("RECOVERY PROCESS BLOCKED BY BIG CANDLE PAUSE | ", BigCandlePauseStatusText());
      return;
     }

   if(InpRecoveryGapRawPrice <= 0.0 || InpRecoveryGapLot <= 0.0)
      return;

   if(CheckEquityConditions())
      return;

   RefreshRates();

   if(TryOpenPendingRecoveryGap())
      return;

   bool allowBuyRecoveryBySAR  = true;
   bool allowSellRecoveryBySAR = true;

   if(InpRecoveryGapMustMatchSARDirection)
     {
      allowBuyRecoveryBySAR  = (g_activeSARDirection == 1);
      allowSellRecoveryBySAR = (g_activeSARDirection == -1);

      if(g_activeSARDirection == 0)
        {
         Print("RECOVERY GAP BLOCKED | No active SAR direction");
         return;
        }
     }

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

   if(InpRecoveryGapMustMatchSARDirection)
     {
      if(hasBuy && !allowBuyRecoveryBySAR)
         Print("RECOVERY GAP BUY SKIPPED | ActiveSAR=", DirectionText(g_activeSARDirection),
               " | RequiredSAR=BUY | Gap=", DoubleToString(buyGap, Digits),
               " | RequiredGap=", DoubleToString(buyRequiredGap, Digits));

      if(hasSell && !allowSellRecoveryBySAR)
         Print("RECOVERY GAP SELL SKIPPED | ActiveSAR=", DirectionText(g_activeSARDirection),
               " | RequiredSAR=SELL | Gap=", DoubleToString(sellGap, Digits),
               " | RequiredGap=", DoubleToString(sellRequiredGap, Digits));
     }

   if(hasBuy &&
      buyGap >= buyRequiredGap &&
      buyRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
      !allowBuyRecoveryBySAR)
     {
      RememberPendingRecoveryGap(1, buyGap, buyRequiredGap,
                                 "BUY recovery gap matched but SAR not BUY");
     }

   if(hasSell &&
      sellGap >= sellRequiredGap &&
      sellRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
      !allowSellRecoveryBySAR)
     {
      RememberPendingRecoveryGap(-1, sellGap, sellRequiredGap,
                                 "SELL recovery gap matched but SAR not SELL");
     }

   bool buyReady = (allowBuyRecoveryBySAR &&
                    hasBuy && buyGap >= buyRequiredGap &&
                    buyRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                    !IsStrongOppositeMoveAgainstRecovery(1, buyGap));

   bool sellReady = (allowSellRecoveryBySAR &&
                     hasSell && sellGap >= sellRequiredGap &&
                     sellRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                     !IsStrongOppositeMoveAgainstRecovery(-1, sellGap));

   // Open only one recovery gap order per tick. Choose the side with the larger adverse move.
   if(buyReady && (!sellReady || buyGap >= sellGap))
     {
      Print("RECOVERY LADDER READY | BUY | Base=", DoubleToString(buyBase, Digits),
            " | CurrentGap=", DoubleToString(buyGap, Digits),
            " | RequiredGap=", DoubleToString(buyRequiredGap, Digits),
            " | RecoveryCount=", buyRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      if(!OpenRecoveryGapMarketOrder(1, buyGap))
         RememberPendingRecoveryGap(1, buyGap, buyRequiredGap,
                                    "BUY recovery gap ready but OrderSend/condition failed");
      return;
     }

   if(sellReady)
     {
      Print("RECOVERY LADDER READY | SELL | Base=", DoubleToString(sellBase, Digits),
            " | CurrentGap=", DoubleToString(sellGap, Digits),
            " | RequiredGap=", DoubleToString(sellRequiredGap, Digits),
            " | RecoveryCount=", sellRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      if(!OpenRecoveryGapMarketOrder(-1, sellGap))
         RememberPendingRecoveryGap(-1, sellGap, sellRequiredGap,
                                    "SELL recovery gap ready but OrderSend/condition failed");
      return;
     }
  }


//+------------------------------------------------------------------+
//| SAR SPECIAL GUARD ORDER HELPERS                                  |
//+------------------------------------------------------------------+
bool IsSARGuardOrderComment(string commentText)
  {
   return(StringFind(commentText, InpSARSpecialGuardPrefix) >= 0);
  }

//+------------------------------------------------------------------+
bool IsSARParentOrderComment(string commentText)
  {
   return(StringFind(commentText, InpSARParentOrderPrefix) >= 0);
  }

//+------------------------------------------------------------------+
bool IsRecoveryGapOrderComment(string commentText)
  {
   return(StringFind(commentText, "RECOVERY_GAP") >= 0 ||
          StringFind(commentText, InpSARRecoveryGapOrderPrefix) >= 0);
  }

//+------------------------------------------------------------------+
string MakeSARParentOrderComment(string reason)
  {
   string c = InpSARParentOrderPrefix + reason;

   // MT4 broker comments may be truncated. Keep the important tag first.
   if(StringLen(c) > 30)
      c = StringSubstr(c, 0, 30);

   return(c);
  }

//+------------------------------------------------------------------+
int GetParentTicketForRecoveryGap(int direction)
  {
   int type = direction == 1 ? OP_BUY : OP_SELL;
   int parentTicket = 0;
   datetime oldestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      string c = OrderComment();

      if(IsSARGuardOrderComment(c) || IsRecoveryGapOrderComment(c) || IsRecoveryHedgeOrderComment(c))
         continue;

      // Prefer explicitly tagged normal parent orders.
      if(IsSARParentOrderComment(c))
        {
         if(parentTicket == 0 || OrderOpenTime() < oldestTime)
           {
            parentTicket = OrderTicket();
            oldestTime = OrderOpenTime();
           }
        }
     }

   // Backward compatibility: existing old orders may not have SAR_PARENT_ comment.
   if(parentTicket <= 0)
     {
      for(int j = OrdersTotal() - 1; j >= 0; j--)
        {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
            continue;

         if(OrderType() != type)
            continue;

         string c2 = OrderComment();
         if(IsSARGuardOrderComment(c2) || IsRecoveryGapOrderComment(c2) || IsRecoveryHedgeOrderComment(c2))
            continue;

         if(parentTicket == 0 || OrderOpenTime() < oldestTime)
           {
            parentTicket = OrderTicket();
            oldestTime = OrderOpenTime();
           }
        }
     }

   return(parentTicket);
  }

//+------------------------------------------------------------------+
bool IsRecoveryGapLinkedToParent(string commentText, int parentTicket)
  {
   if(parentTicket <= 0)
      return(false);

   string key = InpSARRecoveryGapOrderPrefix + IntegerToString(parentTicket) + "_";
   return(StringFind(commentText, key) >= 0);
  }

//+------------------------------------------------------------------+
string SARGuardGlobalVariableName(int guardTicket)
  {
   return("SAR_GUARD_PARENT_" + Symbol() + "_" + IntegerToString(InpMagicNumber) + "_" + IntegerToString(guardTicket));
  }

//+------------------------------------------------------------------+
int ExtractSARGuardParentTicketFromComment(string commentText)
  {
   int pos = StringFind(commentText, InpSARSpecialGuardPrefix);
   if(pos < 0)
      return(0);

   string ticketText = StringSubstr(commentText, pos + StringLen(InpSARSpecialGuardPrefix));
   int parentTicket = (int)StrToInteger(ticketText);

   return(parentTicket);
  }

//+------------------------------------------------------------------+
bool IsParentOrderStillOpen(int parentTicket)
  {
   if(parentTicket <= 0)
      return(false);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderTicket() == parentTicket &&
         OrderSymbol() == Symbol() &&
         OrderMagicNumber() == InpMagicNumber &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool HasSARSpecialGuardOrderForParent(int parentTicket)
  {
   if(parentTicket <= 0)
      return(true);

   string exactComment = InpSARSpecialGuardPrefix + IntegerToString(parentTicket);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!IsSARGuardOrderComment(OrderComment()))
         continue;

      // Comment may be truncated by broker, so also check the saved GlobalVariable mapping.
      if(StringFind(OrderComment(), exactComment) >= 0)
         return(true);

      string gvName = SARGuardGlobalVariableName(OrderTicket());
      if(GlobalVariableCheck(gvName))
        {
         int storedParent = (int)GlobalVariableGet(gvName);
         if(storedParent == parentTicket)
            return(true);
        }
     }

   return(false);
  }


//+------------------------------------------------------------------+
int CountSARSpecialGuardOrders()
  {
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         count++;
     }

   return(count);
  }


//+------------------------------------------------------------------+
//| Basket-side special guard helpers                                |
//+------------------------------------------------------------------+
double GetBasketLotsForSpecialGuard(int direction)
  {
   int type = (direction == 1) ? OP_BUY : OP_SELL;
   double lots = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      if(IsSARGuardOrderComment(OrderComment()) || IsRecoveryHedgeOrderComment(OrderComment()))
         continue;

      lots += OrderLots();
     }

   return(NormalizeDouble(lots, 2));
  }

//+------------------------------------------------------------------+
int GetFirstBasketParentTicketForSpecialGuard(int direction)
  {
   int type = (direction == 1) ? OP_BUY : OP_SELL;
   int selectedTicket = 0;
   datetime selectedTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      if(IsSARGuardOrderComment(OrderComment()) ||
         IsRecoveryGapOrderComment(OrderComment()) ||
         IsRecoveryHedgeOrderComment(OrderComment()))
         continue;

      if(selectedTicket <= 0 || OrderOpenTime() < selectedTime)
        {
         selectedTicket = OrderTicket();
         selectedTime   = OrderOpenTime();
        }
     }

   // Backward compatibility: if no clean SAR_PARENT order comment exists,
   // use the oldest non-guard/non-hedge same-side order as the representative parent.
   if(selectedTicket <= 0)
     {
      for(int j = OrdersTotal() - 1; j >= 0; j--)
        {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
            continue;

         if(OrderType() != type)
            continue;

         if(IsSARGuardOrderComment(OrderComment()) || IsRecoveryHedgeOrderComment(OrderComment()))
            continue;

         if(selectedTicket <= 0 || OrderOpenTime() < selectedTime)
           {
            selectedTicket = OrderTicket();
            selectedTime   = OrderOpenTime();
           }
        }
     }

   return(selectedTicket);
  }

//+------------------------------------------------------------------+
bool HasSARSpecialGuardOrderForBasketDirection(int basketDirection)
  {
   int guardType = (basketDirection == 1) ? OP_SELL : OP_BUY;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != guardType)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool TryCreateSARSpecialGuardForBasketDirection(int basketDirection)
  {
   if(basketDirection != 1 && basketDirection != -1)
      return(false);

   int basketCount = CountOrdersByDirection(basketDirection);
   if(basketCount <= 0)
      return(false);

   int guardDirection = -basketDirection;
   string basketText = (basketDirection == 1) ? "BUY_BASKET" : "SELL_BASKET";

   double basketProfit = GetBasketProfit(basketDirection);
   double triggerLoss  = MathAbs(InpSARSpecialGuardLossUSD);

   // Priority rule: after SAR_FLIP_V2LAST normal order opens,
   // do NOT use a time wait. Wait until basket loss becomes worse by extra amount.
   // Example: InpSARSpecialGuardLossUSD=8 and Extra=1 => guard waits until basket P/L <= -9.
   if(g_lastSARFlipV2LastOrderTime > 0 && InpSARSpecialGuardExtraLossAfterSAROrder > 0.0)
     {
      double priorityTriggerLoss = triggerLoss + MathAbs(InpSARSpecialGuardExtraLossAfterSAROrder);

      if(basketProfit > -priorityTriggerLoss)
        {
         SetSARSpecialGuardDebugStatus("SKIPPED | SAR order priority wait until " +
                                       basketText + " <= -$" + DoubleToString(priorityTriggerLoss, 2),
                                       0, basketProfit, basketProfit, 0.0, 0);
         Print("SAR SPECIAL GUARD SKIPPED | SAR_FLIP_V2LAST priority loss wait",
               " | Basket=", basketText,
               " | BasketProfit=$", DoubleToString(basketProfit, 2),
               " | Required<=-$", DoubleToString(priorityTriggerLoss, 2),
               " | BaseTrigger=-$", DoubleToString(triggerLoss, 2),
               " | Extra=$", DoubleToString(MathAbs(InpSARSpecialGuardExtraLossAfterSAROrder), 2),
               " | SAROrderTime=", TimeToString(g_lastSARFlipV2LastOrderTime, TIME_DATE|TIME_SECONDS));
         return(false);
        }
     }

   // Optional old behavior. Default false, because guard should protect basket loss even without SAR condition.
   if(InpSARSpecialGuardRequireSARChange && g_activeSARDirection != 0)
     {
      if(basketDirection == g_activeSARDirection)
        {
         if(basketProfit <= -triggerLoss)
            SetSARSpecialGuardDebugStatus("SKIPPED | Basket loss matched but SAR change required",
                                          0, basketProfit, basketProfit, 0.0, 0);
         return(false);
        }
     }

   // Basket trigger: BUY basket <= -$X opens SELL guard, SELL basket <= -$X opens BUY guard.
   if(basketProfit > -triggerLoss)
      return(false);

   int parentTicket = GetFirstBasketParentTicketForSpecialGuard(basketDirection);
   double basketLots = InpFixedLot;//GetBasketLotsForSpecialGuard(basketDirection);
   
   double guardLots = basketLots * InpSARSpecialGuardLotMultiplier;

   if(parentTicket <= 0)
     {
      Print("SAR SPECIAL GUARD BLOCKED | Basket trigger matched but no representative parent found",
            " | Basket=", basketText,
            " | BasketProfit=$", DoubleToString(basketProfit, 2),
            " | Trigger=-$", DoubleToString(triggerLoss, 2));
      SetSARSpecialGuardDebugStatus("BLOCKED | Basket matched, no parent ticket",
                                    0, basketProfit, basketProfit, guardLots, 0);
      return(false);
     }

   if(HasSARSpecialGuardOrderForBasketDirection(basketDirection))
     {
      Print("SAR SPECIAL GUARD SKIPPED | Basket guard already exists",
            " | Basket=", basketText,
            " | Parent=#", parentTicket,
            " | BasketProfit=$", DoubleToString(basketProfit, 2),
            " | Trigger=-$", DoubleToString(triggerLoss, 2));
      SetSARSpecialGuardDebugStatus("SKIPPED | Basket guard already exists",
                                    parentTicket, basketProfit, basketProfit, guardLots, 0);
      return(false);
     }

   int activeGuardCount = CountSARSpecialGuardOrders();
   if(InpMaxSARSpecialGuardOrders > 0 && activeGuardCount >= InpMaxSARSpecialGuardOrders)
     {
      Print("SAR SPECIAL GUARD BLOCKED | Max active guards reached ",
            activeGuardCount, "/", InpMaxSARSpecialGuardOrders,
            " | Basket=", basketText,
            " | Parent=#", parentTicket,
            " | BasketProfit=$", DoubleToString(basketProfit, 2));
      SetSARSpecialGuardDebugStatus("BLOCKED | Max guard reached " +
                                    IntegerToString(activeGuardCount) + "/" + IntegerToString(InpMaxSARSpecialGuardOrders),
                                    parentTicket, basketProfit, basketProfit, guardLots, 0);
      return(false);
     }

   Print("SAR SPECIAL GUARD BASKET TRIGGER | Basket=", basketText,
         " | BasketDir=", DirectionText(basketDirection),
         " | GuardDir=", DirectionText(guardDirection),
         " | Parent=#", parentTicket,
         " | BasketOrders=", basketCount,
         " | BasketProfit=$", DoubleToString(basketProfit, 2),
         " | Trigger=-$", DoubleToString(triggerLoss, 2),
         " | BasketLots=", DoubleToString(basketLots, 2),
         " | RequestedMaxLot=", DoubleToString(guardLots, 2));

   SetSARSpecialGuardDebugStatus("TRIGGER MATCHED | " + basketText + " -> guard " + DirectionText(guardDirection),
                                 parentTicket, basketProfit, basketProfit, guardLots, 0);

   return(OpenSARSpecialGuardOrder(guardDirection, guardLots, parentTicket));
  }

//+------------------------------------------------------------------+
//| Affordable SAR special guard lot                                 |
//| Uses requested lot as MAX. If free margin is not enough, reduces |
//| lot step-by-step until AccountFreeMarginCheck() passes.          |
//+------------------------------------------------------------------+
double GetAffordableGuardLot(int orderType, double requestedMaxLot)
  {
   RefreshRates();

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0)
      lotStep = 0.01;

   if(requestedMaxLot <= 0.0)
      return(0.0);

   double lot = MathMin(requestedMaxLot, maxLot);
   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);

   while(lot >= minLot)
     {
      ResetLastError();
      double freeAfter = AccountFreeMarginCheck(Symbol(), orderType, lot);
      int err = GetLastError();

      // freeAfter > 0 means broker accepts the margin calculation.
      if(freeAfter > 0.0 && err == 0)
         return(NormalizeDouble(lot, 2));

      lot -= lotStep;
      lot = MathFloor(lot / lotStep) * lotStep;
      lot = NormalizeDouble(lot, 2);
      ResetLastError();
     }

   return(0.0);
  }

//+------------------------------------------------------------------+
//| Parent + recovery gap basket profit for guard trigger            |
//| Normal/recovery in same side are included; guard/hedge excluded. |
//+------------------------------------------------------------------+
double GetParentAndRecoveryGapProfitForGuard(int parentTicket, int direction)
  {
   double totalProfit = 0.0;
   bool hasLinkedRecovery = false;

   // First pass: exact parent + recovery gap orders explicitly linked to this parent.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(IsSARGuardOrderComment(OrderComment()) || IsRecoveryHedgeOrderComment(OrderComment()))
         continue;

      int orderDirection = (OrderType() == OP_BUY) ? 1 : -1;
      if(orderDirection != direction)
         continue;

      string c = OrderComment();
      bool isParentOrder = (OrderTicket() == parentTicket);
      bool isLinkedRecovery = IsRecoveryGapLinkedToParent(c, parentTicket);

      if(isLinkedRecovery)
         hasLinkedRecovery = true;

      if(!isParentOrder && !isLinkedRecovery)
         continue;

      totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
     }

   // Backward compatibility for old recovery-gap orders created before RG_P<parent> comments existed.
   // Only used when no explicitly linked recovery exists.
   if(!hasLinkedRecovery)
     {
      for(int j = OrdersTotal() - 1; j >= 0; j--)
        {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
            continue;

         if(OrderType() != OP_BUY && OrderType() != OP_SELL)
            continue;

         if(IsSARGuardOrderComment(OrderComment()) || IsRecoveryHedgeOrderComment(OrderComment()))
            continue;

         int dir = (OrderType() == OP_BUY) ? 1 : -1;
         if(dir != direction)
            continue;

         string oldComment = OrderComment();

         if(IsRecoveryGapOrderComment(oldComment) && !IsRecoveryGapLinkedToParent(oldComment, parentTicket))
            totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

   return(totalProfit);
  }


//+------------------------------------------------------------------+
void SetSARSpecialGuardDebugStatus(string status,
                                   int parentTicket,
                                   double parentProfit,
                                   double parentAndRecoveryProfit,
                                   double requestedLot,
                                   int errorCode)
  {
   g_sarSpecialGuardLastStatus = status;
   g_sarSpecialGuardLastStatusTime = TimeCurrent();
   g_sarSpecialGuardLastParentTicket = parentTicket;
   g_sarSpecialGuardLastParentProfit = parentProfit;
   g_sarSpecialGuardLastParentRecoveryProfit = parentAndRecoveryProfit;
   g_sarSpecialGuardLastRequestedLot = requestedLot;
   g_sarSpecialGuardLastError = errorCode;

   Print("SAR SPECIAL GUARD DEBUG | ", status,
         " | Parent=#", parentTicket,
         " | ParentProfit=$", DoubleToString(parentProfit, 2),
         " | Parent+Recovery=$", DoubleToString(parentAndRecoveryProfit, 2),
         " | RequestedLot=", DoubleToString(requestedLot, 2),
         " | Error=", errorCode,
         " | Time=", TimeToString(g_sarSpecialGuardLastStatusTime, TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
color SARSpecialGuardDebugColor()
  {
   if(StringFind(g_sarSpecialGuardLastStatus, "OPENED") >= 0)
      return(clrLime);

   if(StringFind(g_sarSpecialGuardLastStatus, "TRIGGER") >= 0)
      return(clrYellow);

   if(StringFind(g_sarSpecialGuardLastStatus, "BLOCKED") >= 0 ||
      StringFind(g_sarSpecialGuardLastStatus, "FAILED") >= 0)
      return(clrRed);

   if(StringFind(g_sarSpecialGuardLastStatus, "SKIPPED") >= 0)
      return(clrOrangeRed);

   return(clrSilver);
  }

//+------------------------------------------------------------------+
bool OpenSARSpecialGuardOrder(int direction, double lot, int parentTicket)
  {
   if(direction == 0 || parentTicket <= 0)
     {
      SetSARSpecialGuardDebugStatus("BLOCKED | Invalid direction or parent ticket",
                                    parentTicket, 0.0, 0.0, lot, 0);
      return(false);
     }

   // IMPORTANT RULE:
   // SAR_SPECIAL_GUARD_ORDER_FOR_ must NOT be blocked by normal EA filters.
   // It bypasses: SAR direction/confirmation, big candle pause, no-new-hour,
   // H1 trend, repeated gap, late SAR block, spread filter, daily/order gates.
   // Only broker/server restrictions can still reject OrderSend.
   RefreshRates();

   int type = (direction == 1) ? OP_BUY : OP_SELL;
   double price = (direction == 1) ? Ask : Bid;

   // lot passed here is the requested MAX lot. Use the highest affordable lot,
   // but never exceed the requested InpSARSpecialGuardLotMultiplier limit.
   double guardLot = GetAffordableGuardLot(type, lot);
   if(guardLot <= 0.0)
     {
      Print("SAR SPECIAL GUARD BLOCKED | Insufficient free margin",
            " | Parent=#", parentTicket,
            " | Direction=", DirectionText(direction),
            " | RequestedMaxLot=", DoubleToString(lot, 2),
            " | FreeMargin=$", DoubleToString(AccountFreeMargin(), 2),
            " | Equity=$", DoubleToString(AccountEquity(), 2),
            " | Balance=$", DoubleToString(AccountBalance(), 2));

      double keepParentProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentProfit : 0.0;
      double keepParentRecoveryProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentRecoveryProfit : 0.0;
      SetSARSpecialGuardDebugStatus("BLOCKED | Insufficient free margin",
                                    parentTicket, keepParentProfit, keepParentRecoveryProfit, lot, 0);
      return(false);
     }

   string commentText = InpSARSpecialGuardPrefix + IntegerToString(parentTicket);

   if(EnforceSpikeWickOrderBlock("OpenSARSpecialGuardOrder", InpSpikeWickBlockRecovery, InpSpikeWickBlockGuard))
     {
      double keepParentProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentProfit : 0.0;
      double keepParentRecoveryProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentRecoveryProfit : 0.0;
      SetSARSpecialGuardDebugStatus("BLOCKED | Spike/Wick pause",
                                    parentTicket, keepParentProfit, keepParentRecoveryProfit, guardLot, 0);
      return(false);
     }

   ResetLastError();

   int ticket = OrderSend(Symbol(),
                          type,
                          guardLot,
                          price,
                          InpSlippage,
                          0,
                          0,
                          commentText,
                          InpMagicNumber,
                          0,
                          GetOrderIconColorByComment(direction, commentText));

   if(ticket < 0)
     {
      int err = GetLastError();
      Print("SAR SPECIAL GUARD ORDER FAILED | Parent=#", parentTicket,
            " | Direction=", DirectionText(direction),
            " | Lot=", DoubleToString(guardLot, 2),
            " | Price=", DoubleToString(price, Digits),
            " | Error=", err);

      double keepParentProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentProfit : 0.0;
      double keepParentRecoveryProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentRecoveryProfit : 0.0;
      SetSARSpecialGuardDebugStatus("FAILED | OrderSend error " + IntegerToString(err),
                                    parentTicket, keepParentProfit, keepParentRecoveryProfit, guardLot, err);
      ResetLastError();
      return(false);
     }

   // MT4/broker may truncate long comments. Store the parent ticket safely using a terminal global variable.
   GlobalVariableSet(SARGuardGlobalVariableName(ticket), parentTicket);
   MarkOpenedOrderOnChart(ticket, direction, commentText, TimeCurrent(), price);

   Print("SAR SPECIAL GUARD ORDER OPENED | Guard=#", ticket,
         " | Parent=#", parentTicket,
         " | Direction=", DirectionText(direction),
         " | Lot=", DoubleToString(guardLot, 2),
         " | Comment=", commentText);

   double keepParentProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentProfit : 0.0;
   double keepParentRecoveryProfit = (g_sarSpecialGuardLastParentTicket == parentTicket) ? g_sarSpecialGuardLastParentRecoveryProfit : 0.0;
   SetSARSpecialGuardDebugStatus("OPENED | Guard #" + IntegerToString(ticket),
                                 parentTicket, keepParentProfit, keepParentRecoveryProfit, guardLot, 0);

   return(true);
  }

//+------------------------------------------------------------------+
void CheckSARSpecialGuardOrdersOnSARChange(int newSARDirection)
  {
   // Latest rule: SAR signal condition is disabled by default.
   // Guard is created from parent floating loss only.
   CheckSARSpecialGuardOrdersByParentLoss();
  }


//+------------------------------------------------------------------+
//| Create SAR special guard only from parent+recovery loss           |
//| BYPASSES all normal filters: SAR, big candle, spread, hours, etc. |
//| BUY parent gets SELL guard. SELL parent gets BUY guard.           |
//| One guard per parent ticket.                                      |
//+------------------------------------------------------------------+
void CheckSARSpecialGuardOrdersByParentLoss()
  {
   if(!InpUseSARSpecialGuardOrder)
      return;

   RefreshRates();

   // New rule:
   // Use BUY/SELL basket P/L, not single parent order P/L.
   // BUY basket profit <= -InpSARSpecialGuardLossUSD  => create one SELL guard.
   // SELL basket profit <= -InpSARSpecialGuardLossUSD => create one BUY guard.
   TryCreateSARSpecialGuardForBasketDirection(1);
   TryCreateSARSpecialGuardForBasketDirection(-1);
  }

//+------------------------------------------------------------------+
void ProcessSARSpecialGuardCleanup()
  {
   if(!InpUseSARSpecialGuardOrder)
      return;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!IsSARGuardOrderComment(OrderComment()))
         continue;

      int guardTicket = OrderTicket();
      int parentTicket = 0;

      string gvName = SARGuardGlobalVariableName(guardTicket);
      if(GlobalVariableCheck(gvName))
         parentTicket = (int)GlobalVariableGet(gvName);
      else
         parentTicket = ExtractSARGuardParentTicketFromComment(OrderComment());

      // If we cannot identify the parent, do NOT close the guard blindly.
      if(parentTicket <= 0)
        {
         Print("SAR SPECIAL GUARD CLEANUP WAIT | Parent not identified | Guard=#", guardTicket,
               " | Comment=", OrderComment());
         continue;
        }

      if(IsParentOrderStillOpen(parentTicket))
         continue;

      int type = OrderType();
      double closeProfit = OrderProfit() + OrderSwap() + OrderCommission();

      // New safety rule:
      // If parent order is closed/profit recovered, do NOT close special guard in loss.
      // Keep it open until it reaches small profit, then close it.
      // MT4 does not allow changing an existing order comment, so we keep the guard comment
      // but make it behave like a regular protected order here.
      // if(InpSpecialGuardCloseOnlyInProfit && closeProfit < InpSpecialGuardMinProfitToClose)
      //   {
      //    Print("SAR SPECIAL GUARD CLEANUP SKIPPED | Waiting guard profit | Guard=#", guardTicket,
      //          " | Parent=#", parentTicket,
      //          " | GuardProfit=$", DoubleToString(closeProfit, 2),
      //          " | Need>=$", DoubleToString(InpSpecialGuardMinProfitToClose, 2),
      //          " | Parent already closed/recovered");

      //    SetSARSpecialGuardDebugStatus("WAIT PROFIT | Parent closed, guard kept",
      //                                  parentTicket, 0.0, closeProfit, OrderLots(), 0);
      //    continue;
      //   }

      double closePrice = (type == OP_BUY) ? Bid : Ask;

      bool ok = OrderClose(guardTicket, OrderLots(), closePrice, InpSlippage, clrYellow);
      if(!ok)
        {
         int err = GetLastError();
         Print("SAR SPECIAL GUARD CLOSE FAILED | Guard=#", guardTicket,
               " | Parent=#", parentTicket,
               " | Error=", err);
         ResetLastError();
        }
      else
        {
         if(GlobalVariableCheck(gvName))
            GlobalVariableDel(gvName);

         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(guardTicket, type, closeProfit, closePrice,
                                    "SAR special guard profit close after parent #" + IntegerToString(parentTicket) + " closed");

         Print("SAR SPECIAL GUARD PROFIT CLOSED | Guard=#", guardTicket,
               " | Parent=#", parentTicket,
               " | Profit=$", DoubleToString(closeProfit, 2));
        }
     }
  }

//+------------------------------------------------------------------+
void ProcessSARFlipStateAndClose()
  {
   int sarFlip = GetSARFlipSignal();

   if(sarFlip == 0 || sarFlip == g_activeSARDirection)
      return;

   int oldDirection = g_activeSARDirection;

// Always update SAR direction immediately so new orders follow current SAR.
// But do NOT close orders on the first signal change after a new order.
// Close only on the configured Nth SAR change counted from the latest normal order.
   if(InpUseDelayedSARChangeClose && g_sarCloseTrackedDirection != 0)
     {
      g_sarChangesAfterLastNormalOrder++;

      int requiredChanges = MathMax(1, InpCloseOrdersOnNthSARChangeAfterOrder);

      Print("SAR CHANGE COUNT FROM LAST ORDER | Old=", DirectionText(oldDirection),
            " | New=", DirectionText(sarFlip),
            " | TrackedOrderDirection=", DirectionText(g_sarCloseTrackedDirection),
            " | Count=", g_sarChangesAfterLastNormalOrder,
            "/", requiredChanges);

      if(g_sarChangesAfterLastNormalOrder >= requiredChanges)
        {
         if(CountOrdersByDirection(g_sarCloseTrackedDirection) > 0)
           {
            CloseOrdersByDirection(g_sarCloseTrackedDirection,
                                   "Delayed SAR close on change #" + IntegerToString(g_sarChangesAfterLastNormalOrder));

            Print("DELAYED SAR CLOSE DONE | ClosedDirection=", DirectionText(g_sarCloseTrackedDirection),
                  " | ChangeCount=", g_sarChangesAfterLastNormalOrder,
                  " | Required=", requiredChanges);
           }
         else
           {
            Print("DELAYED SAR CLOSE SKIPPED | No tracked direction orders open | Direction=",
                  DirectionText(g_sarCloseTrackedDirection));
           }

         g_sarChangesAfterLastNormalOrder = 0;
         g_sarCloseTrackedDirection       = 0;
         g_sarCloseTrackedOrderTime       = 0;
         g_sarDelayedCloseStatus          = "CLOSED/RESET";
        }
      else
        {
         g_sarDelayedCloseStatus = "SKIP " + IntegerToString(g_sarChangesAfterLastNormalOrder) +
                                   "/" + IntegerToString(requiredChanges) +
                                   " Track " + DirectionText(g_sarCloseTrackedDirection);

         Print("SAR CLOSE SKIPPED | Waiting for change #", requiredChanges,
               " from latest order | CurrentCount=", g_sarChangesAfterLastNormalOrder,
               " | TrackedDirection=", DirectionText(g_sarCloseTrackedDirection));
        }
     }
   else
     {
      // Old immediate-close behaviour only when delayed close is disabled.
      if(!InpUseDelayedSARChangeClose && oldDirection != 0)
         CloseOrdersByDirection(oldDirection, "SAR signal changed");

      g_sarDelayedCloseStatus = InpUseDelayedSARChangeClose ? "WAIT ORDER" : "IMMEDIATE CLOSE";
     }

// Open one special guard hedge for losing parent orders when SAR changes against them.
   // Guard orders are ignored by normal basket/profit/SL close logic and close only when parent closes.
   CheckSARSpecialGuardOrdersOnSARChange(sarFlip);

   // Update SAR direction after processing close/skip logic.
   g_activeSARDirection  = sarFlip;
   g_lastSARDotDirection = sarFlip;
   g_sarPausedByEarly    = false;
   g_earlyDirection      = 0;

// Reset per-signal total order counter. This is where max order count restarts.
   ResetSARSignalOrderCycle(sarFlip, "SAR signal changed");

// Start confirmation only for next new order.
   StartSARFlipConfirmation(sarFlip);

   Print("SAR CHANGED | Old=", DirectionText(oldDirection),
         " New=", DirectionText(sarFlip),
         " | DelayedCloseStatus=", g_sarDelayedCloseStatus);
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

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;
      double closeProfit = OrderProfit() + OrderSwap() + OrderCommission();
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
         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(OrderTicket(), type, closeProfit, closePrice, reason);
         RecordLastClosedNormalOrderReference(type, closePrice, OrderComment(), reason);
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
//| Confirmed/recent SAR weak basket close helpers                   |
//+------------------------------------------------------------------+
datetime GetOldestOpenOrderTimeByDirection(int direction)
  {
   datetime oldestTime = 0;
   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      if(oldestTime <= 0 || OrderOpenTime() < oldestTime)
         oldestTime = OrderOpenTime();
     }

   return(oldestTime);
  }

//+------------------------------------------------------------------+
int GetBasketAgeMinutesByDirection(int direction)
  {
   datetime oldestTime = GetOldestOpenOrderTimeByDirection(direction);
   if(oldestTime <= 0)
      return(0);

   int ageMin = (int)((TimeCurrent() - oldestTime) / 60);
   if(ageMin < 0)
      ageMin = 0;

   return(ageMin);
  }

//+------------------------------------------------------------------+
bool IsSARWeakSignalRecentForClose()
  {
   int bars = MathMax(1, InpSARWeakCloseRecentBars);

   // Current confirmed signal is treated as recent even before marker objects update.
   if(g_earlySARWeakExitActive)
      return(true);

   if(g_lastSARWeakSignalMarkerBarTime <= 0)
      return(false);

   datetime minTime = iTime(Symbol(), Period(), bars);
   if(minTime <= 0)
      minTime = TimeCurrent() - bars * PeriodSeconds();

   return(g_lastSARWeakSignalMarkerBarTime >= minTime);
  }

//+------------------------------------------------------------------+
bool ShouldCloseConfirmedSARWeakBasket(int direction,
                                        double basketProfit,
                                        string weakReason,
                                        string &closeReason)
  {
   closeReason = "";

   if(!InpUseConfirmedSARWeakBasketClose)
     {
      g_sarWeakBasketCloseLastStatus = "OFF";
      return(false);
     }

   if(direction == 0 || !g_earlySARWeakExitActive)
     {
      g_sarWeakBasketCloseLastStatus = "WAIT WEAK";
      return(false);
     }

   if(CountOrdersByDirection(direction) <= 0)
     {
      g_sarWeakBasketCloseLastStatus = "NO BASKET";
      return(false);
     }

   if(!IsSARWeakSignalRecentForClose())
     {
      g_sarWeakBasketCloseLastStatus = "WAIT RECENT";
      return(false);
     }

   int basketAgeMin = GetBasketAgeMinutesByDirection(direction);
   bool profitClose = (InpSARWeakCloseProfitBasket &&
                       basketProfit >= MathMax(0.0, InpSARWeakMinProfitToClose));

   double maxSmallLoss = MathAbs(InpSARWeakMaxSmallLossToCloseUSD);
   bool oldSmallLossClose =
      (InpSARWeakCloseOldSmallLoss &&
       basketAgeMin >= MathMax(1, InpSARWeakBasketAgeMinutes) &&
       basketProfit < MathMax(0.0, InpSARWeakMinProfitToClose) &&
       basketProfit >= -maxSmallLoss);

   g_sarWeakBasketCloseLastDirection = direction;
   g_sarWeakBasketCloseLastProfit = basketProfit;
   g_sarWeakBasketCloseLastAgeMin = basketAgeMin;
   g_sarWeakBasketCloseLastReason = weakReason;

   if(profitClose)
     {
      closeReason = "CONFIRMED SAR WEAK PROFIT EXIT | Profit=$" +
                    DoubleToString(basketProfit, 2) +
                    " | Age=" + IntegerToString(basketAgeMin) + "m | " +
                    weakReason;
      g_sarWeakBasketCloseLastStatus = "CLOSE PROFIT";
      return(true);
     }

   if(oldSmallLossClose)
     {
      closeReason = "CONFIRMED SAR WEAK OLD SMALL-LOSS EXIT | Profit=$" +
                    DoubleToString(basketProfit, 2) +
                    " | Age=" + IntegerToString(basketAgeMin) + "m | MaxLoss=$" +
                    DoubleToString(maxSmallLoss, 2) + " | " + weakReason;
      g_sarWeakBasketCloseLastStatus = "CLOSE OLD LOSS";
      return(true);
     }

   g_sarWeakBasketCloseLastStatus = "HOLD | Profit=$" +
                                    DoubleToString(basketProfit, 2) +
                                    " | Age=" + IntegerToString(basketAgeMin) + "m";
   return(false);
  }


//+------------------------------------------------------------------+
bool IsProfitProtectPauseActive()
  {
   if(g_profitProtectPauseUntil <= 0)
      return(false);

   if(TimeCurrent() >= g_profitProtectPauseUntil)
     {
      g_profitProtectPauseUntil = 0;
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
string ProfitProtectPauseStatusText()
  {
   if(!IsProfitProtectPauseActive())
      return("OFF");

   int leftSec = (int)(g_profitProtectPauseUntil - TimeCurrent());
   if(leftSec < 0)
      leftSec = 0;

   return(IntegerToString(leftSec / 60) + "m " + IntegerToString(leftSec % 60) + "s");
  }

//+------------------------------------------------------------------+
int FindProfitProtectIndex(int ticket)
  {
   for(int i = 0; i < g_profitProtectCount; i++)
     {
      if(g_profitProtectTickets[i] == ticket)
         return(i);
     }
   return(-1);
  }

//+------------------------------------------------------------------+
int EnsureProfitProtectIndex(int ticket)
  {
   int idx = FindProfitProtectIndex(ticket);
   if(idx >= 0)
      return(idx);

   if(g_profitProtectCount >= 500)
      return(-1);

   idx = g_profitProtectCount;
   g_profitProtectTickets[idx] = ticket;
   g_profitProtectPeakProfit[idx] = -999999.0;
   g_profitProtectCount++;
   return(idx);
  }

//+------------------------------------------------------------------+
void RemoveProfitProtectIndex(int idx)
  {
   if(idx < 0 || idx >= g_profitProtectCount)
      return;

   for(int i = idx; i < g_profitProtectCount - 1; i++)
     {
      g_profitProtectTickets[i] = g_profitProtectTickets[i + 1];
      g_profitProtectPeakProfit[i] = g_profitProtectPeakProfit[i + 1];
     }

   g_profitProtectCount--;
  }

//+------------------------------------------------------------------+
bool IsEAOrderTicketOpen(int ticket)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderTicket() == ticket &&
         OrderSymbol() == Symbol() &&
         OrderMagicNumber() == InpMagicNumber &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
         return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
void CleanupProfitProtectClosedTickets()
  {
   for(int i = g_profitProtectCount - 1; i >= 0; i--)
     {
      if(!IsEAOrderTicketOpen(g_profitProtectTickets[i]))
         RemoveProfitProtectIndex(i);
     }
  }


//+------------------------------------------------------------------+
// Select highest matching individual profit-protect level.
// Returns TRUE when a valid protection level exists.
bool GetIndividualProfitProtectLevel(double peakProfit,
                                     double defaultActivate,
                                     double defaultCloseAt,
                                     double &selectedActivate,
                                     double &selectedCloseAt,
                                     int &selectedLevel,datetime orderopentime)
  {
   selectedActivate = MathMax(0.0, defaultActivate);
   selectedCloseAt  = MathMax(0.0, defaultCloseAt);
   selectedLevel    = 0;

   if(!InpUseMultiIndividualProfitProtect)
      return(selectedActivate > 0.0 && selectedCloseAt >= 0.0);

   // SAR closed-profit count dynamic protection.
   // Example: after 2 profitable normal closes in this SAR signal,
   // close current order if it pulls back to peak/2. After 3 closes, peak/3, etc.
   int sarClosedCount = MathMax(0, g_sarClosedProfitOrdersCount);
   int startCount = MathMax(1, InpSARClosedProfitCountStart);

   if(InpUseSARClosedProfitCountProtect &&
      sarClosedCount >= startCount &&  
      peakProfit > 0.0 && peakProfit>InpBasketProfitUSD / sarClosedCount && peakProfit>InpBasketProfitUSD/2)
     {
      selectedActivate = peakProfit;
      // selectedCloseAt  = peakProfit / sarClosedCount;

      // Keep at least a tiny positive close value so the order never closes at 0.
      // selectedCloseAt = MathMax(0.01, selectedCloseAt);
      selectedCloseAt = peakProfit * 0.80;

      selectedLevel = 100 + sarClosedCount;
      return(true);
     }

      /*
   // Level 3 has highest priority after the order has reached that peak.
   if(InpProtectActivateUSD_5 > 0.0 && peakProfit >= InpProtectActivateUSD_5)
     {
      selectedActivate = InpProtectActivateUSD_5;
      selectedCloseAt  = InpProtectCloseAtUSD_5;
      selectedLevel    = 5;
      return(true);
     }

       if(InpProtectActivateUSD_4 > 0.0 && peakProfit >= InpProtectActivateUSD_4)
     {
      selectedActivate = InpProtectActivateUSD_4;
      selectedCloseAt  = InpProtectCloseAtUSD_4;
      selectedLevel    = 4;
      return(true);
     }
       if(InpProtectActivateUSD_3 > 0.0 && peakProfit >= InpProtectActivateUSD_3)
     {
      selectedActivate = InpProtectActivateUSD_3;
      selectedCloseAt  = InpProtectCloseAtUSD_3;
      selectedLevel    = 3;
      return(true);
     }

   if(InpProtectActivateUSD_2 > 0.0 && peakProfit >= InpProtectActivateUSD_2)
     {
      selectedActivate = InpProtectActivateUSD_2;
      selectedCloseAt  = InpProtectCloseAtUSD_2;
      selectedLevel    = 2;
      return(true);
     }

   if(InpProtectActivateUSD_1 > 0.0)
     {
      selectedActivate = InpProtectActivateUSD_1;
      selectedCloseAt  = InpProtectCloseAtUSD_1;
      selectedLevel    = 1;
      return(true);
     }

     */

     /*
  bool isNewBar = (Time[0] != g_lastBarTime);


if(g_sarCycleOrdersCreated>5 || TimeCurrent()-orderopentime>30)
{
    if(peakProfit > 0.0 && peakProfit>1)
        {
         selectedActivate = peakProfit;
         selectedCloseAt  = peakProfit *0.8;
         selectedLevel    = 0; // dynamic level
         return(true);
        }
       else  if(peakProfit > 0.0 && peakProfit>0.10)
        {
         selectedActivate = peakProfit;
         selectedCloseAt  = peakProfit *0.8;
         selectedLevel    = 0; // dynamic level
         return(true);
        }
}


   if(isNewBar)
     {
      if(peakProfit > 0.0 && peakProfit>3)
        {
         selectedActivate = peakProfit;
         selectedCloseAt  = peakProfit *0.8;
         selectedLevel    = 0; // dynamic level
         return(true);
        }
     }
   else
      if(peakProfit > 0.0 && peakProfit>3)
        {
         selectedActivate = peakProfit;
         selectedCloseAt  = peakProfit *0.8;
         selectedLevel    = 0; // dynamic level
         return(true);
        }
     // Dynamic fallback:
// If no fixed level matched, but order moved into profit,
// close when profit falls back to 50% of peak profit.
if(peakProfit > 0.0 && peakProfit>0.20)
{
   selectedActivate = peakProfit;
   selectedCloseAt  = peakProfit / 2.0;
   selectedLevel    = 0; // dynamic level
   return(true);
}*/

   // Fallback to old single-level/dynamic values if all multi levels are disabled.
   return(selectedActivate > 0.0 && selectedCloseAt >= 0.0);
  }

//+------------------------------------------------------------------+
void ProcessIndividualProfitProtect()
  {
   if(InpUseSimpleSideBasketCloseOnly)
      return;

   if(!InpUseIndividualProfitProtect)
      return;

   RefreshRates();

   double basketTarget = MathMax(0.0, GetBasketProfitTargetUSD());

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      int ticket = OrderTicket();
      int type   = OrderType();
      int sideOpenOrders = CountOpenOrdersByType(type);
      if(sideOpenOrders <= 0)
         sideOpenOrders = 1;

      bool recoveryOrder = IsRecoveryOrder();

      // Dynamic individual protection target for NORMAL orders:
      // Example: Basket TP=$2 and 4 BUY orders => each BUY protect activation=$0.50.
      double dynamicActivateProfit = basketTarget / sideOpenOrders;

      // Keep your manual input as a fallback when basket target is disabled/zero.
      if(dynamicActivateProfit <= 0.0)
         dynamicActivateProfit = MathMax(0.0, InpIndividualProtectActivateUSD);

      // Recovery orders must also be protected using the fixed manual values.
      // This protects RECOVERY_GAP_1 / RECOVERY_GAP_2 / RECOVERY_GAP_3 during sliding up/down market.
      if(recoveryOrder)
         dynamicActivateProfit = MathMax(0.0, InpIndividualProtectActivateUSD);

      // Close after profit pulls back. Default for normal orders: 50% of dynamic target.
      double dynamicCloseAtProfit = dynamicActivateProfit * 0.50;

      // Keep at least your manual close value.
      dynamicCloseAtProfit = MathMax(dynamicCloseAtProfit, MathMax(0.0, InpIndividualProtectCloseAtUSD));

      // Recovery orders use exact manual close value, example: reached $0.50, close when back to $0.40.
      if(recoveryOrder)
         dynamicCloseAtProfit = MathMax(0.0, InpIndividualProtectCloseAtUSD);

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      int idx = EnsureProfitProtectIndex(ticket);
      if(idx < 0)
         continue;

      if(profit > g_profitProtectPeakProfit[idx])
         g_profitProtectPeakProfit[idx] = profit;

      double selectedActivateProfit = dynamicActivateProfit;
      double selectedCloseAtProfit  = dynamicCloseAtProfit;
      int selectedProtectLevel      = 0;

      if(!GetIndividualProfitProtectLevel(g_profitProtectPeakProfit[idx],
                                          dynamicActivateProfit,
                                          dynamicCloseAtProfit,
                                          selectedActivateProfit,
                                          selectedCloseAtProfit,
                                          selectedProtectLevel,OrderOpenTime()))
         continue;

      // Rule: order first reaches the selected protection level,
      // then if profit comes back down near that level's close value, close it.
      if(g_profitProtectPeakProfit[idx] >= selectedActivateProfit &&
         profit <= selectedCloseAtProfit &&
         profit > 0.0)
        {
         double closePrice = (type == OP_BUY) ? Bid : Ask;
         double lots = OrderLots();

         bool ok = OrderClose(ticket, lots, closePrice, InpSlippage, clrYellow);

         if(ok)
           {
            g_lastAnyOrderCloseTime = TimeCurrent();
            SetLastOrderCloseDashboard(ticket, type, profit, closePrice, "Individual profit protect");
            RecordLastClosedNormalOrderReference(type, closePrice, OrderComment(), "Individual profit protect");
            RegisterSARClosedProfitOrder(type, OrderComment(), profit, "Individual profit protect");
            Print("INDIVIDUAL PROFIT PROTECT CLOSED | Ticket=", ticket,
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | Comment=", OrderComment(),
                  " | Recovery=", recoveryOrder ? "YES" : "NO",
                  " | SideOpenOrders=", sideOpenOrders,
                  " | BasketTarget=$", DoubleToString(basketTarget, 2),
                  " | ProtectLevel=", selectedProtectLevel,
                  " | SelectedActivate=$", DoubleToString(selectedActivateProfit, 2),
                  " | SelectedCloseAt=$", DoubleToString(selectedCloseAtProfit, 2),
                  " | DynamicActivate=$", DoubleToString(dynamicActivateProfit, 2),
                  " | DynamicCloseAt=$", DoubleToString(dynamicCloseAtProfit, 2),
                  " | PeakProfit=$", DoubleToString(g_profitProtectPeakProfit[idx], 2),
                  " | ClosedProfit=$", DoubleToString(profit, 2));

            // After individual profit protect closes an order, pause next normal SAR order for configured minutes.
            g_profitProtectPauseUntil = TimeCurrent() + MathMax(1, InpIndividualProtectPauseMinutes) * 60;
            Print("PROFIT PROTECT PAUSE STARTED | Next normal order blocked for ",
                  MathMax(1, InpIndividualProtectPauseMinutes), " minutes | Until=",
                  TimeToString(g_profitProtectPauseUntil, TIME_DATE|TIME_SECONDS));

            RemoveProfitProtectIndex(idx);
           }
         else
           {
            int err = GetLastError();
            Print("INDIVIDUAL PROFIT PROTECT CLOSE FAILED | Ticket=", ticket,
                  " | Profit=$", DoubleToString(profit, 2),
                  " | Error=", err);
            ResetLastError();
           }
        }
     }

   CleanupProfitProtectClosedTickets();
  }


//+------------------------------------------------------------------+
void ProcessNextCandleLossProtect()
  {
   if(!InpCloseIfNextCandleNotProfit)
      return;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      // Wait until the candle after the order-created candle has fully closed.
      // Example on M1: order opens during candle A, candle B closes, then check profit.
      int openShift = iBarShift(Symbol(), Period(), OrderOpenTime(), false);
      if(openShift < 15)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      // If order is not in profit after next candle close, close it before deeper loss.
      if(profit <= 0.0)
        {
         int type = OrderType();
         double closePrice = (type == OP_BUY) ? Bid : Ask;
         int ticket = OrderTicket();
         double lots = OrderLots();

         bool ok = OrderClose(ticket, lots, closePrice, InpSlippage, clrOrange);

         if(ok)
           {
            g_lastAnyOrderCloseTime = TimeCurrent();
            SetLastOrderCloseDashboard(ticket, type, profit, closePrice, "Next candle loss protect");
            RecordLastClosedNormalOrderReference(type, closePrice, OrderComment(), "Next candle loss protect");
            RegisterSARClosedProfitOrder(type, OrderComment(), profit, "Next candle loss protect");
            Print("NEXT CANDLE LOSS PROTECT CLOSED | Ticket=", ticket,
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | Profit=$", DoubleToString(profit, 2),
                  " | OpenTime=", TimeToString(OrderOpenTime(), TIME_DATE|TIME_SECONDS),
                  " | OpenShift=", openShift,
                  " | Next normal order pause=", MathMax(1, InpIndividualProtectPauseMinutes), " minutes");

            // Use same pause as individual profit protect, so EA does not immediately re-enter.
            g_profitProtectPauseUntil = TimeCurrent() + MathMax(1, InpIndividualProtectPauseMinutes) * 60;

            int idx = FindProfitProtectIndex(ticket);
            if(idx >= 0)
               RemoveProfitProtectIndex(idx);
           }
         else
           {
            int err = GetLastError();
            Print("NEXT CANDLE LOSS PROTECT CLOSE FAILED | Ticket=", ticket,
                  " | Profit=$", DoubleToString(profit, 2),
                  " | Error=", err);
            ResetLastError();
           }
        }
     }
  }


//+------------------------------------------------------------------+
//| Direction-wise basket stop loss                                  |
//| BUY basket loss closes only BUY orders.                          |
//| SELL basket loss closes only SELL orders.                        |
//| Special guard orders are excluded by CloseOrdersByDirection().    |
//+------------------------------------------------------------------+
bool ProcessDirectionWiseBasketStopLossOnly(string &status)
  {
   double effectiveBasketSL = GetEffectiveBasketStopLossUSD();
   if(effectiveBasketSL <= 0.0)
      return(false);

   // Check BUY and SELL independently.
   // This prevents one losing side from closing the opposite side.
   for(int d = 1; d >= -1; d -= 2)
     {
      if(CountOrdersByDirection(d) <= 0)
         continue;

      double sideProfit = GetBasketProfit(d);
      double limit = -MathAbs(effectiveBasketSL);

      if(sideProfit <= limit)
        {
         string sideText = DirectionText(d);

         CloseOrdersByDirection(d,
                                sideText + " direction basket stop loss $" +
                                DoubleToString(sideProfit, 2));

         if(d == g_sarCloseTrackedDirection)
           {
            g_sarChangesAfterLastNormalOrder = 0;
            g_sarCloseTrackedDirection       = 0;
            g_sarCloseTrackedOrderTime       = 0;
            g_sarDelayedCloseStatus          = sideText + " direction Basket SL reset";
           }

         Print("DIRECTION-WISE BASKET STOP LOSS HIT | Direction=", sideText,
               " | SideProfit=$", DoubleToString(sideProfit, 2),
               " | Limit=$", DoubleToString(MathAbs(effectiveBasketSL), 2),
               " | Opposite side left untouched");

         status = sideText + " Basket SL only";
         return(true);
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool ProcessBasketCloseByDirection(int direction, string &status)
  {
   if(direction == 0)
      return(false);

   if(CountOrdersByDirection(direction) <= 0)
      return(false);

   double profit = GetBasketProfit(direction);
   double target = GetBasketProfitTargetUSD();
   double effectiveBasketSL2 = GetEffectiveBasketStopLossUSD();

   if(effectiveBasketSL2 > 0.0 && profit <= -MathAbs(effectiveBasketSL2))
     {
      CloseOrdersByDirection(direction,
                             "Basket stop loss $" + DoubleToString(profit, 2));

      if(direction == g_sarCloseTrackedDirection)
        {
         g_sarChangesAfterLastNormalOrder = 0;
         g_sarCloseTrackedDirection       = 0;
         g_sarCloseTrackedOrderTime       = 0;
         g_sarDelayedCloseStatus          = "Basket SL reset";
        }

      Print("BASKET STOP LOSS HIT | Direction=", DirectionText(direction),
            " | Loss=$", DoubleToString(profit, 2),
            " | Limit=$", DoubleToString(effectiveBasketSL2, 2));

      status = "Basket SL " + DirectionText(direction);
      return(true);
     }

   if(profit >= target)
     {
      CloseOrdersByDirection(direction,
                             "Basket profit $" + DoubleToString(profit, 2));

      if(direction == g_sarCloseTrackedDirection)
        {
         g_sarChangesAfterLastNormalOrder = 0;
         g_sarCloseTrackedDirection       = 0;
         g_sarCloseTrackedOrderTime       = 0;
         g_sarDelayedCloseStatus          = "Basket TP reset";
        }

      Print("BASKET PROFIT HIT | Direction=", DirectionText(direction),
            " | Profit=$", DoubleToString(profit, 2),
            " | Target=$", DoubleToString(target, 2));

      status = "Basket TP " + DirectionText(direction);
      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool ProcessAllSideBasketClose(string &status)
  {
   // Important for delayed SAR close: old direction orders may remain open
   // after the first SAR flip, so BUY and SELL baskets must be checked independently.
   if(ProcessBasketCloseByDirection(1, status))
      return(true);

   if(ProcessBasketCloseByDirection(-1, status))
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| SAR weak reverse order helpers                                   |
//+------------------------------------------------------------------+
int CountSARWeakReverseOrders()
  {
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(IsSARWeakReverseOrderComment(OrderComment()))
         total++;
     }
   return(total);
  }

int CountSARWeakReverseOrdersByDirection(int direction)
  {
   int total = 0;
   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;
      if(IsSARWeakReverseOrderComment(OrderComment()))
         total++;
     }

   return(total);
  }

int GetMaxSARWeakReverseOrdersPerSide()
  {
   // InpMaxSARWeakReverseOrders is total across both sides.
   // Example: 2 means max 1 BUY weak-reverse + max 1 SELL weak-reverse.
   int totalMax = MathMax(1, InpMaxSARWeakReverseOrders);
   int perSide = (totalMax + 1) / 2;
   if(perSide < 1)
      perSide = 1;
   return(perSide);
  }

int CountSARWeakReverseBaseOrdersByDirection(int direction)
  {
   int total = 0;
   int type = direction == 1 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;
      if(IsSARWeakReverseOrderComment(OrderComment()))
         continue;

      total++;
     }

   return(total);
  }

bool HasSARWeakReverseOrderForDirection(int direction)
  {
   return(CountSARWeakReverseOrdersByDirection(direction) > 0);
  }

bool HasExistingOrderForSARWeakReverseProtection(int direction)
  {
   return(CountSARWeakReverseBaseOrdersByDirection(direction) > 0);
  }

bool OpenSARWeakReverseMarketOrder(int reverseDirection, string weakReason)
  {
   if(reverseDirection == 0)
      return(false);

   // Protection rule:
   // Example: active SAR BUY becomes weak => reverseDirection SELL.
   // Open SAR_WEAK_REVERSE SELL only when an existing SELL order is already open.
   // This makes weak-reverse orders protect previous same-side baskets instead of creating a fresh naked hedge.
   if(InpSARWeakReverseRequireExistingSameSideOrder &&
      !HasExistingOrderForSARWeakReverseProtection(reverseDirection))
     {
      g_sarWeakReverseLastStatus = "WAIT BASE ORDER";
      g_sarWeakReverseLastDirection = reverseDirection;
      g_sarWeakReverseLastReason = "No existing " + DirectionText(reverseDirection) +
                                   " order to protect";
      Print("SAR WEAK REVERSE WAIT | No existing ",
            DirectionText(reverseDirection),
            " order found. Weak reverse not opened. ActiveSAR=",
            DirectionText(g_activeSARDirection));
      return(false);
     }

   RefreshRates();

   if(EnforceBigCandleOrderBlock("SAR weak reverse"))
     {
      g_sarWeakReverseLastStatus = "BLOCKED BIG CANDLE";
      g_sarWeakReverseLastReason = BigCandlePauseStatusText();
      return(false);
     }

   if(InpUseSpikeWickPauseFilter && IsSpikeWickPauseActive())
     {
      g_sarWeakReverseLastStatus = "BLOCKED SPIKE/WICK";
      g_sarWeakReverseLastReason = SpikeWickPauseStatusText();
      return(false);
     }

   if(!IsTradingAllowedNow())
     {
      g_sarWeakReverseLastStatus = "BLOCKED TRADING OFF";
      g_sarWeakReverseLastReason = "AutoTrading/trade context/free margin";
      return(false);
     }

   if(CheckEquityConditions())
     {
      g_sarWeakReverseLastStatus = "BLOCKED EQUITY";
      g_sarWeakReverseLastReason = "Equity/profit protection active";
      return(false);
     }

   if(IsTotalOpenOrderCapReached("SARWeakReverse"))
     {
      g_sarWeakReverseLastStatus = "BLOCKED TOTAL CAP";
      g_sarWeakReverseLastReason = "Total order cap reached";
      return(false);
     }

   int totalMaxWeakReverseOrders = MathMax(1, InpMaxSARWeakReverseOrders);
   int activeWeakReverseOrders = CountSARWeakReverseOrders();

   if(activeWeakReverseOrders >= totalMaxWeakReverseOrders)
     {
      g_sarWeakReverseLastStatus = "BLOCKED MAX TOTAL";
      g_sarWeakReverseLastReason = "Active weak reverse orders " +
                                   IntegerToString(activeWeakReverseOrders) + "/" +
                                   IntegerToString(totalMaxWeakReverseOrders) +
                                   " | BUY=" + IntegerToString(CountSARWeakReverseOrdersByDirection(1)) +
                                   " SELL=" + IntegerToString(CountSARWeakReverseOrdersByDirection(-1));
      return(false);
     }

   // Per-side limit:
   // InpMaxSARWeakReverseOrders=2 means max 1 BUY weak-reverse and max 1 SELL weak-reverse.
   int maxWeakReverseOrdersPerSide = GetMaxSARWeakReverseOrdersPerSide();
   int sameSideWeakReverseOrders = CountSARWeakReverseOrdersByDirection(reverseDirection);

   if(sameSideWeakReverseOrders >= maxWeakReverseOrdersPerSide)
     {
      g_sarWeakReverseLastStatus = "BLOCKED SIDE MAX";
      g_sarWeakReverseLastReason = DirectionText(reverseDirection) + " weak reverse " +
                                   IntegerToString(sameSideWeakReverseOrders) + "/" +
                                   IntegerToString(maxWeakReverseOrdersPerSide) +
                                   " | Total " + IntegerToString(activeWeakReverseOrders) + "/" +
                                   IntegerToString(totalMaxWeakReverseOrders);
      return(false);
     }

   if(g_sarWeakReverseLastTime > 0 &&
      TimeCurrent() - g_sarWeakReverseLastTime < MathMax(1, InpSARWeakReverseCooldownMinutes) * 60)
     {
      g_sarWeakReverseLastStatus = "BLOCKED COOLDOWN";
      g_sarWeakReverseLastReason = "Wait " + IntegerToString(InpSARWeakReverseCooldownMinutes) + "m";
      return(false);
     }

   if(InpSARWeakReverseRequireH1Trend)
     {
      int hTrend = GetH2TrendDirection();
      if(hTrend == 0 || hTrend != reverseDirection)
        {
         g_sarWeakReverseLastStatus = "BLOCKED H1/H2 TREND";
         g_sarWeakReverseLastReason = "Reverse=" + DirectionText(reverseDirection) + " H=" + DirectionText(hTrend);
         return(false);
        }
     }

   int type = reverseDirection == 1 ? OP_BUY : OP_SELL;
   double price = reverseDirection == 1 ? Ask : Bid;
   double lot = InpSARWeakReverseLot > 0.0 ? InpSARWeakReverseLot : InpFixedLot;
   lot = NormalizeLot(lot);

   double sl = 0.0;
   if(InpStopLossPoints > 0)
     {
      if(reverseDirection == 1)
         sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else
         sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
     }

   string comment = "SAR_WEAK_REVERSE_" + DirectionText(reverseDirection);

   ResetLastError();
   int ticket = OrderSend(Symbol(), type, lot, price, InpSlippage, sl, 0,
                          comment, InpMagicNumber, 0,
                          GetOrderIconColorByComment(reverseDirection, comment));

   if(ticket < 0)
     {
      int err = GetLastError();
      g_sarWeakReverseLastStatus = "FAILED";
      g_sarWeakReverseLastReason = BuildOrderSendFailMessage(err, type, lot, price, sl, comment);
      g_lastOrderOpenReason = g_sarWeakReverseLastReason;
      Print("SAR WEAK REVERSE ORDER FAILED | ", g_sarWeakReverseLastReason);
      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();
   g_sarWeakReverseLastStatus = "OPENED";
   g_sarWeakReverseLastTime = TimeCurrent();
   g_sarWeakReverseLastDirection = reverseDirection;
   g_sarWeakReverseLastTicket = ticket;
   g_sarWeakReverseLastReason = weakReason;
   g_lastOrderOpenReason = "SAR WEAK REVERSE OPENED | Ticket=" + IntegerToString(ticket) +
                           " | Direction=" + DirectionText(reverseDirection) +
                           " | Lot=" + DoubleToString(lot, 2);

   MarkOpenedOrderOnChart(ticket, reverseDirection, comment, TimeCurrent(), price);

   Print("SAR WEAK REVERSE ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(reverseDirection),
         " | ActiveSAR=", DirectionText(g_activeSARDirection),
         " | Lot=", DoubleToString(lot, 2),
         " | WeakReason=", weakReason);

   return(true);
  }

bool TryOpenSARWeakReverseOrder(string weakReason)
  {
   if(!InpOpenReverseOrderOnSARWeakSignal)
      return(false);

   if(!g_earlySARWeakExitActive)
     {
      g_sarWeakReverseLastStatus = "WAIT WEAK SAR";
      g_sarWeakReverseLastReason = "Early SAR weak signal not active";
      return(false);
     }

   if(g_activeSARDirection == 0)
      return(false);

   int reverseDirection = -g_activeSARDirection;
   return(OpenSARWeakReverseMarketOrder(reverseDirection, weakReason));
  }

bool ProcessCloseOrdersFirst(string &status)
  {
   if(g_activeSARDirection == 0)
     {
      status = "Waiting for first SAR";
      return(false);
     }

// PRIORITY 0: BUY/SELL basket TP/SL must work independently.
// This is required because delayed SAR close may leave the previous direction basket open.
   if(ProcessAllSideBasketClose(status))
      return(true);

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

      // Mark weak SAR signal candle with different color on chart.
      DrawSARWeakSignalMarker(0, weakExitReason);

      // Optional hedge/reverse entry before full SAR flip.
      // Example: active SAR BUY is weak => open SELL SAR_WEAK_REVERSE order.
      TryOpenSARWeakReverseOrder(weakExitReason);

      string confirmedWeakCloseReason = "";
      bool shouldCloseConfirmedWeakBasket =
         ShouldCloseConfirmedSARWeakBasket(g_activeSARDirection,
                                           activeProfit,
                                           weakExitReason,
                                           confirmedWeakCloseReason);

      // New confirmed weak close rule:
      // 1) Close profitable active SAR basket immediately when confirmed/recent SAR weakness appears.
      // 2) If basket age is > configured minutes, close at controlled small loss only.
      // 3) Do not close on every weak marker; the signal must be confirmed and recent.
      if(shouldCloseConfirmedWeakBasket)
        {
         int oldDirection = g_activeSARDirection;
         CloseOrdersByDirection(oldDirection, confirmedWeakCloseReason);

         g_lastEarlySARWeakExitTime = TimeCurrent();
         g_lastEarlySARWeakExitDirection = oldDirection;
         g_activeBasketPeakProfit = 0.0;

         g_sarWeakBasketCloseLastTime = TimeCurrent();
         g_sarWeakBasketCloseLastDirection = oldDirection;
         g_sarWeakBasketCloseLastProfit = activeProfit;
         g_sarWeakBasketCloseLastAgeMin = GetBasketAgeMinutesByDirection(oldDirection);
         g_sarWeakBasketCloseLastReason = confirmedWeakCloseReason;

         if(InpSARWeakCloseResetCycle)
            ResetSARSignalOrderCycleToNormalAfterStopLoss(oldDirection, "Confirmed SAR weak basket close");

         // Allow new SAR-direction order logic on the next tick instead of keeping the EA stuck
         // only because the previous basket was closed by a confirmed weak signal.
         g_earlySARWeakExitActive = false;
         g_earlySARWeakExitReason = "";

         status = "CONFIRMED SAR WEAK BASKET CLOSED";
         return(true);
        }

      // Backward-compatible old switch: keep available, but new confirmed rule above is safer.
      if(shouldCloseWeakBasket && InpCloseBasketOnSARWeakExit)
        {
         int oldDirection2 = g_activeSARDirection;
         CloseOrdersByDirection(oldDirection2, "Early SAR weak exit: " + weakExitReason);
         g_lastEarlySARWeakExitTime = TimeCurrent();
         g_lastEarlySARWeakExitDirection = oldDirection2;
         g_activeBasketPeakProfit = 0.0;

         status = "EARLY SAR WEAK EXIT CLOSED";
         return(true);
        }
     }

// PRIORITY 3: Basket stop loss / basket profit close.
   double effectiveBasketSL3 = GetEffectiveBasketStopLossUSD();
   if(effectiveBasketSL3 > 0.0 && activeProfit <= -effectiveBasketSL3)
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
            " | Limit=$", DoubleToString(effectiveBasketSL3, 2));

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
      return(SetOrderBlockStatus(status, "Waiting for first SAR"));
     }

// No-trading hours block ONLY new normal SAR orders.
// Close management, equity protection, basket TP/SL, SAR flip close and recovery management still run.
   if(IsNoNewOrderHour())
     {
      return(SetOrderBlockStatus(status, "NO NEW ORDERS HOUR - " + InpNoNewOrderHourList));
     }

// Big candle pause blocks ONLY new orders. Close/profit/protection logic still runs first.
   if(IsBigCandlePauseActive())
     {
      return(SetOrderBlockStatus(status, "BIG CANDLE PAUSE - " + BigCandlePauseStatusText()));
     }

// Early SAR weak exit blocks ONLY new normal orders while the weak active SAR basket still exists.
// If confirmed weak close already removed that basket, allow fresh SAR-direction order logic on the next tick.
   if(InpUseEarlySARWeakExit && InpStopNewOrdersOnSARWeakExit && g_earlySARWeakExitActive &&
      CountOrdersByDirection(g_activeSARDirection) > 0)
     {
      status = "SAR WEAK - STOP NEW ORDERS";
      SetLastOrderBlockDashboard(status + " | " + g_earlySARWeakExitReason);
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
         SetLastOrderBlockDashboard(status);
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
      SetLastOrderBlockDashboard(status);
      Print("DYNAMIC SAR NEW ORDER BLOCKED | Direction=", DirectionText(g_activeSARDirection),
            " | Reason=", dynamicBlockReason,
            " | Age=", GetSARSignalAgeMinutes(), "m",
            " | Score=", g_dynamicSARScore,
            " | ATR=", DoubleToString(g_dynamicSARATR, 2),
            " | DotDistance=", DoubleToString(g_dynamicSARDotDistance, 2),
            " | ADX=", DoubleToString(g_dynamicSARADX, 2));
      return(false);
     }

// Late SAR cycle entry protection: prevents the last weak order before SAR reversal.
   string lateSARBlockReason = "";
   if(IsLateSARCycleEntryDanger(g_activeSARDirection, lateSARBlockReason))
     {
      status = lateSARBlockReason;
      SetLastOrderBlockDashboard(status);
      Print("LATE SAR CYCLE ENTRY BLOCKED | Direction=", DirectionText(g_activeSARDirection),
            " | Reason=", lateSARBlockReason,
            " | Age=", GetSARSignalAgeMinutes(), "m",
            " | Score=", g_dynamicSARScore);
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

         return(SetOrderBlockStatus(status, "FLAT MODE - WAIT BREAKOUT"));
        }
     }
   else
     {
      g_flatMode = false;
     }

   if(g_sarPausedByEarly)
     {
      return(SetOrderBlockStatus(status, "Paused by early reverse"));
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
      SetLastOrderBlockDashboard(status);
      Print("ORDER BLOCKED | SAR reverse against H1 trend | Direction=", DirectionText(g_activeSARDirection));
      return(false);
     }

   int dynamicMaxOrders = g_sarCycleMaxOrders;
   int cycleOrders      = g_sarCycleOrdersCreated;

   if(dynamicMaxOrders <= 0)
     {
      status = "SAR CYCLE Immidiate change MAX BLOCK - MAX 0";
      SetLastOrderBlockDashboard(status);
      Print("ORDER BLOCKED | SAR cycle max is 0 | Direction=", DirectionText(g_activeSARDirection),
            " | Last5=", GetSARDurationSummaryText());
      return(false);
     }

   if(cycleOrders >= dynamicMaxOrders)
     {
      status = "SAR CYCLE MAX " + IntegerToString(cycleOrders) + "/" + IntegerToString(dynamicMaxOrders);
      SetLastOrderBlockDashboard(status);
      return(false);
     }

// if(InpOneOrderPerBar && !isNewBar)
// {
//    status = "Waiting new bar";
//    return(false);
// }

   if(!IsSARSignalPriceSideAllowed(g_activeSARDirection, "Normal SAR order"))
     {
      return(SetOrderBlockStatus(status, "SAR PRICE SIDE BLOCK"));
     }

   if(!CanOpenNewOrder(g_activeSARDirection))
     {
      status = "Order gate blocked | " + g_lastOrderOpenReason;
      SetLastOrderBlockDashboard(status);
      return(false);
     }

   // Normal continuity order needs price to move in SAR direction from last profitable close.
   // If that forward gap is not ready, try safer pullback half-TP re-entry instead.
   bool normalContinuousGapReady = IsRepeatedPriceGapConfirmedForNormalOrder(g_activeSARDirection, "SAR_FLIP_V2LAST_PRECHECK");

   if(!normalContinuousGapReady)
     {
      string pullbackReason = "";
      if(IsSARPullbackHalfTPAllowed(g_activeSARDirection, pullbackReason))
        {
         if(OpenMarketOrder(g_activeSARDirection, "SAR_PULLBACK_HALF_TP"))
           {
            g_lastSARPullbackOrderBarTime = Time[0];
            status = pullbackReason;
            Print("SAR PULLBACK HALF TP ORDER OPENED | ", pullbackReason);
            return(true);
           }

         status = g_lastOrderOpenReason;
         SetLastOrderBlockDashboard(status);
         return(false);
        }

      status = "CONTINUOUS GAP WAIT | " + pullbackReason;
      SetLastOrderBlockDashboard(status);
      return(false);
     }

   if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_V2LAST"))
      status = "Active " + DirectionText(g_activeSARDirection);
   else
      status = g_lastOrderOpenReason;

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

void UpdateMarketMode()
{
   double move30 =
      MathAbs(Close[0] - iClose(Symbol(), PERIOD_M1, 30));

   int h1Trend = GetH1TrendDirection();

   int profitOrders = g_sarClosedProfitOrdersCount;

   double ema50 =
      iMA(Symbol(), PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE, 0);

   double ema50Old =
      iMA(Symbol(), PERIOD_M1, 50, 0, MODE_EMA, PRICE_CLOSE, 10);

   bool strongSlope =
      MathAbs(ema50 - ema50Old) > 100;

   double lastRange =
      MathAbs(High[1] - Low[1]);

   if(lastRange > 300)
   {
      g_marketMode = MODE_DANGER;
      return;
   }

   if(move30 > 500 &&
      profitOrders >= 4 &&
      h1Trend != 0 &&
      strongSlope)
   {
      g_marketMode = MODE_STRONG_TREND;
      return;
   }

   if(move30 >= 300)
   {
      g_marketMode = MODE_HEALTHY_TREND;
      return;
   }

   g_marketMode = MODE_RANGE;
}
bool AllowRecoveryOrders()
{
   if(g_marketMode == MODE_STRONG_TREND)
      return(false);

   if(g_marketMode == MODE_DANGER)
      return(false);

   return(true);
}

bool AllowSARWeakOrders()
{
   if(g_marketMode == MODE_STRONG_TREND)
      return(false);

   if(g_marketMode == MODE_HEALTHY_TREND)
      return(false);

   if(g_marketMode == MODE_DANGER)
      return(false);

   return(true);
}

bool AllowPullbackOrders()
{
   if(g_marketMode == MODE_STRONG_TREND)
      return(false);

   if(g_marketMode == MODE_DANGER)
      return(false);

   return(true);
}
double GetActiveBasketStopLoss()
{
   switch(g_marketMode)
   {
      case MODE_STRONG_TREND:
         return(5.0);

      case MODE_HEALTHY_TREND:
         return(10.0);

      case MODE_RANGE:
         return(10.0);

      default:
         return(10.0);
   }
}
string MarketModeText()
{
   switch(g_marketMode)
   {
      case MODE_STRONG_TREND:
         return("STRONG TREND");

      case MODE_HEALTHY_TREND:
         return("HEALTHY TREND");

      case MODE_RANGE:
         return("RANGE");

      case MODE_DANGER:
         return("DANGER");
   }

   return("UNKNOWN");
}
double GetEffectiveRecoveryGapRawPrice()
{
   if(!InpUseAutoMarketFlowMode)
      return(InpRecoveryGapRawPrice);

   switch(g_autoMarketMode)
   {
      case DXB_MARKET_MODE_CONTINUOUS:
         return(999999); // disable

      case DXB_MARKET_MODE_MEDIUM:
         return(InpRecoveryGapRawPrice);

      case DXB_MARKET_MODE_MIXED:
         return(InpRecoveryGapRawPrice/2);

      case DXB_MARKET_MODE_DANGER:
         return(999999); // disable
   }

   return(InpRecoveryGapRawPrice);
}
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

   UpdateAutoMarketFlowMode();

   // Update spike/wick pause status on every tick so dashboard shows it immediately.
   EnforceSpikeWickOrderBlock("OnTick dashboard scan", InpSpikeWickBlockRecovery, InpSpikeWickBlockGuard);

   ProcessSARSpecialGuardCleanup();
   // SAR_FLIP_V2LAST has first priority.
   // Special guard is checked after normal SAR order creation later in OnTick,
   // so both orders are not created in the same candle.

// DIRECTION-WISE BASKET STOP LOSS FIRST:
// BUY loss closes only BUY orders; SELL loss closes only SELL orders.
// Opposite side and special guard orders remain open.
   string directionSLStatus = "RUNNING";
   if(ProcessDirectionWiseBasketStopLossOnly(directionSLStatus))
     {
      DrawLeftOrderCreationChecklist(directionSLStatus);
      DrawDashboard(directionSLStatus);
      return;
     }

// FIRST PRIORITY PROFIT BOOKING:
// 1) Close ALL BUY+SELL open EA orders if combined profit >= InpBasketProfitUSD.
// 2) Otherwise close BUY basket or SELL basket individually if that side profit >= InpBasketProfitUSD.
   string firstPriorityStatus = "RUNNING";
   bool closedByFirstPriority = false;
   if(ProcessFirstPriorityBasketProfitClose(firstPriorityStatus))
     {
      closedByFirstPriority = true;
     }

// Deposit reset uses the same equity reset method as fixed hours (1,7,13,19).
// Closed trade profit will not trigger this because only OP_BALANCE is checked.
   CheckDepositAndResetEquityStats();

// Equity protection may close all EA orders and intentionally stop processing.
   if(CheckEquityConditions())
     {
      if(g_dailyProfitLock)
        {
         DrawLeftOrderCreationChecklist("DAILY PROFIT LOCK - PAUSED");
         DrawDashboard("DAILY PROFIT LOCK - PAUSED");
        }
      else
        {
         DrawLeftOrderCreationChecklist("EQUITY PROTECTION - PAUSED");
         DrawDashboard("EQUITY PROTECTION - PAUSED");
        }
      return;
     }

// Recovery orders must NOT close at fixed InpRecoveryProfitUSD.
   // They close only via ProcessIndividualProfitProtect():
   // peak >= InpIndividualProtectActivateUSD, then pullback <= InpIndividualProtectCloseAtUSD.
   // This keeps the oldest/base order open for basket recovery and lets recovery orders catch swings.
   // CloseRecoveryOrdersAtProfit();

// Individual profit protection:
   // Recovery orders close ONLY after profit pullback:
   // InpIndividualProtectActivateUSD -> InpIndividualProtectCloseAtUSD.
   ProcessIndividualProfitProtect();

// Next candle loss protection: if order is not in profit after next candle closes, close it.
   ProcessNextCandleLossProtect();

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
   bool closedThisTick = closedByFirstPriority;

   if(ProcessCloseOrdersFirst(status))
      closedThisTick = true;

   ProcessSARSpecialGuardCleanup();

   if(closedByFirstPriority)
      status = firstPriorityStatus + " | WAIT NEXT CANDLE";

// SECTION 3: New order creation LAST. Runs only if nothing closed this tick.
   if(!closedThisTick)
      ProcessNewOrderCreationLast(isNewBar, status);

   // Special guard runs AFTER normal SAR order creation.
   // If SAR_FLIP_V2LAST opened this candle, guard will be skipped until next candle.
   CheckSARSpecialGuardOrdersByParentLoss();

   if(status == "RUNNING" || status == "")
      status = g_lastOrderOpenReason;

   // DrawEMATrendLines();

   DrawLeftOrderCreationChecklist(status);
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

// 0) SAR signal max-time confirmation.
//    IMPORTANT: This is NOT a waiting time.
//    If InpSARConfirmPriceDiff is completed earlier, for example in 3 minutes,
//    the order is allowed immediately. InpSARConfirmMinutes is only the maximum
//    time allowed for the price gap to happen after SAR flip.
   int elapsedSecondsForSARConfirm = GetSARConfirmElapsedSeconds();
   int allowedSecondsForSARConfirm = MathMax(0, InpSARConfirmMinutes) * 60;

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
//    Rule: price gap must happen WITHIN InpSARConfirmMinutes.
//    Example: RequiredDiff=50 and ConfirmMinutes=15.
//    If price moves 50 in 3 minutes, confirmation is ready immediately.
//    If price does not move 50 within 15 minutes, block until next SAR cycle.
   if(InpUseSARPriceDiffConfirm)
     {
      double diff = GetSARConfirmCurrentPriceDiff();
      double requiredDiff = InpSARConfirmPriceDiff;

      if(InpUseDynamicSAREngine)
         requiredDiff = GetDynamicSARRequiredConfirmDiff();

      g_dynamicSARRequiredDiff = requiredDiff;

      if(requiredDiff > 0.0 && diff < requiredDiff)
        {
         if(allowedSecondsForSARConfirm > 0 && elapsedSecondsForSARConfirm > allowedSecondsForSARConfirm)
           {
            Print("SAR CONFIRM EXPIRED | Price diff not completed within time | Diff=",
                  DoubleToString(diff, Digits),
                  " < Required=", DoubleToString(requiredDiff, Digits),
                  " | ElapsedMin=", DoubleToString(elapsedSecondsForSARConfirm / 60.0, 1),
                  " | LimitMin=", InpSARConfirmMinutes,
                  " | Dynamic=", (InpUseDynamicSAREngine ? "YES" : "NO"));
            return(false);
           }

         Print("SAR CONFIRM WAIT | Price diff ",
               DoubleToString(diff, Digits), " < required ",
               DoubleToString(requiredDiff, Digits),
               " | ElapsedMin=", DoubleToString(elapsedSecondsForSARConfirm / 60.0, 1),
               "/", InpSARConfirmMinutes,
               " | Dynamic=", (InpUseDynamicSAREngine ? "YES" : "NO"));
         return(false);
        }

      Print("SAR CONFIRM READY | Price gap completed within time | Diff=",
            DoubleToString(diff, Digits),
            " >= Required=", DoubleToString(requiredDiff, Digits),
            " | ElapsedMin=", DoubleToString(elapsedSecondsForSARConfirm / 60.0, 1),
            "/", InpSARConfirmMinutes,
            " | Dynamic=", (InpUseDynamicSAREngine ? "YES" : "NO"));
     }
   else
     {
      // If price-diff confirmation is disabled, keep the old time-confirm behavior.
      if(allowedSecondsForSARConfirm > 0 && elapsedSecondsForSARConfirm < allowedSecondsForSARConfirm)
        {
         Print("SAR CONFIRM WAIT | Price diff disabled; time elapsed ",
               IntegerToString(elapsedSecondsForSARConfirm / 60), "m ",
               IntegerToString(elapsedSecondsForSARConfirm % 60), "s < required ",
               IntegerToString(InpSARConfirmMinutes), "m");
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
bool IsNormalSAROrderReason(string reason)
  {
   if(StringFind(reason, "SAR_FLIP") >= 0)
      return(true);
   if(StringFind(reason, "SAR_ARROW") >= 0)
      return(true);
   return(false);
  }

//+------------------------------------------------------------------+
bool IsLast3ClosedCandlesAgainstDirection(int direction)
  {
   if(direction == 0 || Bars < 5)
      return(false);

   // BUY SAR danger: last 3 closed candles are falling by closes.
   if(direction == 1 && Close[1] < Close[2] && Close[2] < Close[3])
      return(true);

   // SELL SAR danger: last 3 closed candles are rising by closes.
   if(direction == -1 && Close[1] > Close[2] && Close[2] > Close[3])
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
bool IsLateSARCycleEntryDanger(int direction, string &whyBlocked)
  {
   whyBlocked = "";

   if(!InpUseLateSARCycleEntryBlock)
      return(false);

   if(direction == 0)
      return(false);

   int ageMin = GetSARSignalAgeMinutes();
   int minAge = MathMax(0, InpLateSARMinAgeMinutes);

   if(InpLateSARBlockOnWeakExit && g_earlySARWeakExitActive)
     {
      whyBlocked = "Late SAR danger: SAR weak exit active | " + g_earlySARWeakExitReason;
      return(true);
     }

   if(ageMin < minAge)
      return(false);

   int score = GetDynamicSARStrengthScore(direction);
   int weakScore = MathMax(0, InpLateSARMaxWeakScore);

   if(score <= weakScore)
     {
      whyBlocked = "Late SAR danger: age " + IntegerToString(ageMin) + "m" +
                   " score " + IntegerToString(score) + "/" + IntegerToString(weakScore);
      return(true);
     }

   if(InpLateSARBlockOnOpposite3Candles && IsLast3ClosedCandlesAgainstDirection(direction))
     {
      whyBlocked = "Late SAR danger: last 3 candles against " + DirectionText(direction) +
                   " | age " + IntegerToString(ageMin) + "m";
      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
string LateSARCycleEntryStatusText(int direction)
  {
   if(!InpUseLateSARCycleEntryBlock)
      return("OFF");

   string why = "";
   bool danger = IsLateSARCycleEntryDanger(direction, why);

   if(danger)
      return("DANGER | " + why);

   return("SAFE age " + IntegerToString(GetSARSignalAgeMinutes()) + "m score " +
          IntegerToString(g_dynamicSARScore) + "/" + IntegerToString(InpLateSARMaxWeakScore));
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
   g_lastConfirmedOrderPrice = 0.0;
   g_lastConfirmedOrderTime  = 0;
   g_lastClosedNormalOrderPrice = 0.0;
   g_lastClosedNormalOrderTime  = 0;
   g_lastClosedNormalOrderDirection = 0;
   g_sarClosedProfitOrdersCount = 0;

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
   g_lastConfirmedOrderPrice = 0.0;
   g_lastConfirmedOrderTime  = 0;
   g_lastClosedNormalOrderPrice = 0.0;
   g_lastClosedNormalOrderTime  = 0;
   g_lastClosedNormalOrderDirection = 0;
   g_sarClosedProfitOrdersCount = 0;

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

   if(IsProfitProtectPauseActive())
     {
      Print("ORDER BLOCKED | Individual profit protect pause active | Remaining=",
            ProfitProtectPauseStatusText(), " | Direction=", DirectionText(direction));
      DrawDashboard("PROFIT PROTECT PAUSE " + ProfitProtectPauseStatusText());
      return(false);
     }

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

   double effectiveMinGap = GetEffectiveMinPriceGap();
   if(effectiveMinGap > 0.0 && !IsPriceGapValid(direction, effectiveMinGap))
     {
      Print("ORDER BLOCKED | Minimum same-direction order gap not matched | Direction=",
            DirectionText(direction),
            " | RequiredGap=", DoubleToString(effectiveMinGap, Digits),
            " | InpMaxOrders=", InpMaxOrders);
      return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
double GetEffectiveMinPriceGap()
  {
   double gap = MathMax(0.0, InpMinPriceGap);

   if(InpMaxOrders > 1)
      gap = MathMax(gap, MathMax(0.0, InpMinGapWhenMaxOrdersMoreThanOne));

   return(gap);
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

//+------------------------------------------------------------------+
//| SAR pullback half-TP re-entry helpers                             |
//+------------------------------------------------------------------+
bool IsSARPullbackHalfTPReason(string reason)
{
   return(StringFind(reason, "SAR_PULLBACK_HALF_TP") >= 0);
}

bool IsSARPullbackHalfTPAllowed(int direction, string &reason)
{
   reason = "";

   if(!InpUseSARPullbackHalfTP)
   {
      reason = "Pullback half-TP disabled";
      return(false);
   }

   if(direction == 0)
   {
      reason = "Pullback blocked: direction is 0";
      return(false);
   }

   if(direction != g_activeSARDirection || direction != g_sarCycleDirection)
   {
      reason = "Pullback blocked: SAR direction mismatch";
      return(false);
   }

   // Safer: enable only after at least one profitable normal SAR order closed in this SAR cycle.
   if(g_sarClosedProfitOrdersCount < 1)
   {
      reason = "Pullback blocked: no previous profitable SAR close";
      return(false);
   }

   if(g_lastClosedNormalOrderPrice <= 0.0 || g_lastClosedNormalOrderTime <= 0)
   {
      reason = "Pullback blocked: no last normal profit close price";
      return(false);
   }

   if(g_lastClosedNormalOrderDirection != direction)
   {
      reason = "Pullback blocked: last close direction mismatch";
      return(false);
   }

   if(Time[0] == g_lastSARPullbackOrderBarTime)
   {
      reason = "Pullback blocked: already opened this candle";
      return(false);
   }

   RefreshRates();

   double pullback = 0.0;
   double livePrice = (direction == 1) ? Ask : Bid;

   if(direction == 1)
      pullback = g_lastClosedNormalOrderPrice - Ask;   // BUY SAR: price dropped from profit close
   else
      pullback = Bid - g_lastClosedNormalOrderPrice;   // SELL SAR: price bounced up from profit close

   if(pullback < InpSARPullbackMinGap || pullback > InpSARPullbackMaxGap)
   {
      reason = "Pullback gap not matched | Gap=" + DoubleToString(pullback, 2) +
               " | Need=" + DoubleToString(InpSARPullbackMinGap, 2) +
               "-" + DoubleToString(InpSARPullbackMaxGap, 2) +
               " | LastClose=" + DoubleToString(g_lastClosedNormalOrderPrice, Digits) +
               " | Live=" + DoubleToString(livePrice, Digits);
      return(false);
   }

   if(InpSARPullbackRequireRecoveryCandle)
   {
      // BUY: after pullback, wait for a bullish closed candle.
      // SELL: after pullback, wait for a bearish closed candle.
      if(direction == 1 && Close[1] <= Open[1])
      {
         reason = "Pullback BUY blocked: no bullish recovery candle";
         return(false);
      }

      if(direction == -1 && Close[1] >= Open[1])
      {
         reason = "Pullback SELL blocked: no bearish recovery candle";
         return(false);
      }
   }

   reason = "PULLBACK HALF TP OK | Direction=" + DirectionText(direction) +
            " | Gap=" + DoubleToString(pullback, 2) +
            " | TPx=" + DoubleToString(InpSARPullbackTPMultiplier, 2) +
            " | ProfitCloseCount=" + IntegerToString(g_sarClosedProfitOrdersCount);
   return(true);
}

//+------------------------------------------------------------------+
//| Repeated raw-price gap confirmation for SAR trend orders          |
//+------------------------------------------------------------------+
bool IsRepeatedPriceGapConfirmedForNormalOrder(int direction, string reason)
  {
   // Pullback half-TP order is allowed exactly when normal continuity gap is not ready.
   // It has its own -20 to -50 pullback gap validation, so do not block it here.
   if(IsSARPullbackHalfTPReason(reason))
      return(true);

   if(!InpUseRepeatedPriceGapConfirm)
      return(true);

   if(direction == 0)
      return(false);

   RefreshRates();

   // First normal order after SAR change uses SAR confirmation only.
   // Continuity gap starts only after a normal order is CLOSED in the same SAR signal.
   if(g_sarCycleOrdersCreated <= 0)
     {
      Print("CONTINUOUS GAP SKIPPED | First order after SAR confirmation | Direction=",
            DirectionText(direction), " | Reason=", reason);
      return(true);
     }

   // If no normal order has closed in this SAR cycle yet, do not block continuity by old open price.
   if(g_lastClosedNormalOrderPrice <= 0.0 || g_lastClosedNormalOrderTime <= 0 ||
      g_lastClosedNormalOrderDirection != direction)
     {
      Print("CONTINUOUS GAP SKIPPED | No closed normal order reference in current SAR cycle | Direction=",
            DirectionText(direction),
            " | Created=", g_sarCycleOrdersCreated,
            " | LastClosedDir=", DirectionText(g_lastClosedNormalOrderDirection),
            " | Reason=", reason);
      return(true);
     }

   int waitMinutes = MathMax(0, InpContinuousOrderGapMinutes);
   int elapsedSeconds = (int)(TimeCurrent() - g_lastClosedNormalOrderTime);
   if(elapsedSeconds < 0)
      elapsedSeconds = 0;

   int requiredSeconds = waitMinutes * 60;
   if(requiredSeconds > 0 && elapsedSeconds < requiredSeconds)
     {
      int leftSeconds = requiredSeconds - elapsedSeconds;
      Print("CONTINUOUS GAP WAIT AFTER CLOSE | Direction=", DirectionText(direction),
            " | WaitMin=", waitMinutes,
            " | ElapsedSec=", elapsedSeconds,
            " | LeftSec=", leftSeconds,
            " | LastClosedPrice=", DoubleToString(g_lastClosedNormalOrderPrice, Digits),
            " | LastClosedTime=", TimeToString(g_lastClosedNormalOrderTime, TIME_DATE|TIME_SECONDS),
            " | Reason=", reason);
      return(false);
     }

   double livePrice = (direction == 1) ? Ask : Bid;
   double currentGap = 0.0;

   if(direction == 1)
      currentGap = livePrice - g_lastClosedNormalOrderPrice;
   else
      currentGap = g_lastClosedNormalOrderPrice - livePrice;

   if(currentGap < InpContinuousOrderPriceGap)
     {
      Print("CONTINUOUS GAP WAIT PRICE FROM LAST CLOSED ORDER | Direction=", DirectionText(direction),
            " | LivePrice=", DoubleToString(livePrice, Digits),
            " | LastClosedPrice=", DoubleToString(g_lastClosedNormalOrderPrice, Digits),
            " | CurrentGap=", DoubleToString(currentGap, Digits),
            " | RequiredGap=", DoubleToString(InpContinuousOrderPriceGap, Digits),
            " | ElapsedMin=", DoubleToString(elapsedSeconds / 60.0, 1),
            " | Reason=", reason);
      return(false);
     }

   Print("CONTINUOUS GAP CONFIRMED FROM LAST CLOSED ORDER | Direction=", DirectionText(direction),
         " | LivePrice=", DoubleToString(livePrice, Digits),
         " | LastClosedPrice=", DoubleToString(g_lastClosedNormalOrderPrice, Digits),
         " | CurrentGap=", DoubleToString(currentGap, Digits),
         " | RequiredGap=", DoubleToString(InpContinuousOrderPriceGap, Digits),
         " | ElapsedMin=", DoubleToString(elapsedSeconds / 60.0, 1),
         " | Reason=", reason);

   return(true);
  }

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Detailed order block / OrderSend failure reason helpers           |
//+------------------------------------------------------------------+
bool BlockOrder(string reason)
  {
   SetLastOrderBlockDashboard(reason);
   Print("ORDER BLOCKED | ", reason);
   return(false);
  }

//+------------------------------------------------------------------+
string MT4TradeErrorDescription(int err)
  {
   switch(err)
     {
      case 0:    return("No error");
      case 1:    return("No error returned");
      case 2:    return("Common error");
      case 3:    return("Invalid trade parameters");
      case 4:    return("Trade server busy");
      case 5:    return("Old terminal version");
      case 6:    return("No connection");
      case 8:    return("Too frequent requests");
      case 64:   return("Account disabled");
      case 65:   return("Invalid account");
      case 128:  return("Trade timeout");
      case 129:  return("Invalid price");
      case 130:  return("Invalid stops");
      case 131:  return("Invalid volume / lot size");
      case 132:  return("Market closed");
      case 133:  return("Trading disabled");
      case 134:  return("Not enough money / free margin");
      case 135:  return("Price changed");
      case 136:  return("Off quotes");
      case 137:  return("Broker busy");
      case 138:  return("Requote");
      case 139:  return("Order locked");
      case 140:  return("Long positions only allowed");
      case 141:  return("Too many trade requests");
      case 145:  return("Modification denied because order too close to market");
      case 146:  return("Trade context busy");
      case 147:  return("Expiration denied by broker");
      case 148:  return("Too many orders");
      case 149:  return("Hedge prohibited");
      case 150:  return("FIFO rule prohibited");
      case 4107: return("Invalid price parameter");
      case 4108: return("Invalid ticket");
      case 4109: return("Trade not allowed by EA/settings");
      case 4110: return("Long trades not allowed");
      case 4111: return("Short trades not allowed");
      case 4112: return("Trade is disabled by symbol/account settings");
      default:   return("Unknown trade error");
     }
  }

//+------------------------------------------------------------------+
string BuildOrderSendFailMessage(int err,
                                 int type,
                                 double lot,
                                 double price,
                                 double sl,
                                 string reason)
  {
   return("OrderSend FAILED | Error=" + IntegerToString(err) +
          " " + MT4TradeErrorDescription(err) +
          " | Type=" + (type == OP_BUY ? "BUY" : "SELL") +
          " | Lot=" + DoubleToString(lot, 2) +
          " | Price=" + DoubleToString(price, Digits) +
          " | Bid=" + DoubleToString(Bid, Digits) +
          " | Ask=" + DoubleToString(Ask, Digits) +
          " | Spread=" + DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0) +
          " | StopLevel=" + DoubleToString(MarketInfo(Symbol(), MODE_STOPLEVEL), 0) +
          " | FreeMargin=$" + DoubleToString(AccountFreeMargin(), 2) +
          " | Magic=" + IntegerToString(InpMagicNumber) +
          " | Source=" + reason);
  }

bool OpenMarketOrder(int direction, string reason)
  {
   g_lastOrderOpenReason = "CHECKING | " + reason;

   // Print("Attempting to open ", reason, "-------------------------------------");

   RefreshRates();

   UpdateAutoMarketFlowMode();
   if(!IsAutoMarketNewOrderAllowed(reason))
      return BlockOrder("Auto market mode blocked order | Mode=" + AutoMarketModeStatusText() + " | Source=" + reason);

   if(EnforceBigCandleOrderBlock("OpenMarketOrder " + reason))
     {
      string msgBig = "Big candle/spike pause active | " + BigCandlePauseStatusText() + " | Source=" + reason;
      Print("ORDERSEND BLOCKED | ", msgBig);
      return BlockOrder(msgBig);
     }

   if(direction == 0)
      return BlockOrder("Direction is 0 | Source=" + reason);

   // Final safety: block late-cycle weak NORMAL SAR entries only.
   // Recovery and hedge order reasons are not affected by this filter.
   if(IsNormalSAROrderReason(reason))
     {
      string lateSARReason = "";
      if(IsLateSARCycleEntryDanger(direction, lateSARReason))
         return BlockOrder(lateSARReason + " | Source=" + reason);
     }

   if(IsProfitProtectPauseActive())
     {
      string msg = "Individual profit protect pause active | Remaining=" +
                   ProfitProtectPauseStatusText() +
                   " | Direction=" + DirectionText(direction) +
                   " | Source=" + reason;

      Print("ORDERSEND BLOCKED | ", msg);
      DrawDashboard("PROFIT PROTECT PAUSE " + ProfitProtectPauseStatusText());
      return BlockOrder(msg);
     }

   if(IsTotalOpenOrderCapReached("OpenMarketOrder"))
      return BlockOrder("Total open order cap reached | Total=" +
                        IntegerToString(CountAllOrders()) +
                        "/" + IntegerToString(InpMaxTotalOpenOrders) +
                        " | Source=" + reason);

   if(!IsTradingAllowedNow())
      return BlockOrder("Trading not allowed now / AutoTrading OFF / trade context busy / no free margin | Source=" + reason);

   if(CheckEquityConditions())
      return BlockOrder("Equity protection or daily profit lock active | Source=" + reason);

   int currentDirectionCount = CountOrdersByDirection(direction);
   if(currentDirectionCount >= InpMaxOrders)
     {
      string msgMaxOpen = "Max open orders per direction reached | Direction=" +
                          DirectionText(direction) +
                          " | Open=" + IntegerToString(currentDirectionCount) +
                          "/" + IntegerToString(InpMaxOrders) +
                          " | Source=" + reason;

      Print("ORDERSEND BLOCKED | ", msgMaxOpen);
      return BlockOrder(msgMaxOpen);
     }

   double effectiveMinGap = GetEffectiveMinPriceGap();
   if(effectiveMinGap > 0.0 && !IsPriceGapValid(direction, effectiveMinGap))
     {
      string msgGap = "Minimum same-direction order gap not matched | Direction=" +
                      DirectionText(direction) +
                      " | RequiredGap=" + DoubleToString(effectiveMinGap, Digits) +
                      " | Open=" + IntegerToString(currentDirectionCount) +
                      "/" + IntegerToString(InpMaxOrders) +
                      " | Source=" + reason;

      Print("ORDERSEND BLOCKED | ", msgGap);
      return BlockOrder(msgGap);
     }

   EnsureSARSignalOrderCycle(direction);
   UpdateSARCycleMaxByMomentum(direction, "OpenMarketOrder pre-check");

   int dynamicMaxOrders = g_sarCycleMaxOrders;
   int cycleOrders      = g_sarCycleOrdersCreated;

   // Final safety before OrderSend: count created orders in current SAR signal-cycle,
   // not currently open orders. Closed profitable orders are still counted.
   if(dynamicMaxOrders <= 0)
     {
      string msgZeroMax = "SAR cycle max is 0 | Symbol=" + Symbol() +
                          " | Direction=" + DirectionText(direction) +
                          " | Last5=" + GetSARDurationSummaryText() +
                          " | Source=" + reason;

      Print("ORDERSEND BLOCKED | ", msgZeroMax);
      DrawDashboard("ORDERSEND BLOCKED - SAR CYCLE MAX 0");
      return BlockOrder(msgZeroMax);
     }

   if(cycleOrders >= dynamicMaxOrders)
     {
      string msgCycleMax = "SAR signal-cycle max reached | Direction=" +
                           DirectionText(direction) +
                           " | CycleCreated=" + IntegerToString(cycleOrders) +
                           "/" + IntegerToString(dynamicMaxOrders) +
                           " | Last5=" + GetSARDurationSummaryText() +
                           " | Source=" + reason;

      Print("ORDERSEND BLOCKED | ", msgCycleMax);
      DrawDashboard("ORDERSEND BLOCKED CYCLE " +
                    IntegerToString(cycleOrders) + "/" +
                    IntegerToString(dynamicMaxOrders));
      return BlockOrder(msgCycleMax);
     }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   if(!IsSARSignalPriceSideAllowed(direction, reason))
      return BlockOrder("SAR signal price side filter blocked | Direction=" +
                        DirectionText(direction) +
                        " | SignalPrice=" + DoubleToString(g_activeSARSignalChangePrice, Digits) +
                        " | Bid=" + DoubleToString(Bid, Digits) +
                        " | Ask=" + DoubleToString(Ask, Digits) +
                        " | Source=" + reason);

   if(!IsRepeatedPriceGapConfirmedForNormalOrder(direction, reason))
      return BlockOrder("Repeated price gap not confirmed | Direction=" +
                        DirectionText(direction) +
                        " | RequiredGap=" + DoubleToString(InpContinuousOrderPriceGap, Digits) +
                        " | WaitMin=" + IntegerToString(InpContinuousOrderGapMinutes) +
                        " | LastConfirmedPrice=" + DoubleToString(g_lastConfirmedOrderPrice, Digits) +
                        " | SARSignalPrice=" + DoubleToString(g_activeSARSignalChangePrice, Digits) +
                        " | Bid=" + DoubleToString(Bid, Digits) +
                        " | Ask=" + DoubleToString(Ask, Digits) +
                        " | Source=" + reason);

   double sl = 0;

   if(InpStopLossPoints > 0)
     {
      if(direction == 1)
         sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else
         sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
     }

   sl = 0; // disable SL for now to test pure SAR cycle max logic

   double lot = NormalizeLot(InpFixedLot);

   RefreshRates();
   EnsureSARSignalOrderCycle(direction);
   UpdateSARCycleMaxByMomentum(direction, "OrderSend last check");

   if(g_sarCycleMaxOrders <= 0 || g_sarCycleOrdersCreated >= g_sarCycleMaxOrders)
     {
      string msgLastCycle = "OrderSend cancelled last check | CycleCreated=" +
                            IntegerToString(g_sarCycleOrdersCreated) +
                            "/" + IntegerToString(g_sarCycleMaxOrders) +
                            " | Last5=" + GetSARDurationSummaryText() +
                            " | Source=" + reason;

      Print("ORDERSEND CANCELLED LAST CHECK | ", msgLastCycle);
      return BlockOrder(msgLastCycle);
     }

   if(!IsTradingAllowedNow())
      return BlockOrder("OrderSend cancelled last check | Trading not allowed now | Source=" + reason);

   ResetLastError();

   string orderComment = MakeSARParentOrderComment(reason);

   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          sl,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          GetOrderIconColorByComment(direction, orderComment));

   if(ticket < 0)
     {
      int err = GetLastError();

      g_lastOrderOpenReason = BuildOrderSendFailMessage(err, type, lot, price, sl, reason);

      Print(g_lastOrderOpenReason);

      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();
   MarkOpenedOrderOnChart(ticket, direction, orderComment, TimeCurrent(), price);
   if(reason == "SAR_FLIP_V2LAST")
     {
      g_lastSARFlipV2LastOrderBarTime = Time[0];
      g_lastSARFlipV2LastOrderTime    = TimeCurrent();
     }
   g_lastConfirmedOrderPrice = price;
   g_lastConfirmedOrderTime  = TimeCurrent();

   // Register only normal SAR cycle orders. Recovery orders use OpenRecoveryOrder() and are independent.
   RegisterSARCycleOrderCreated(direction);

   // Reset delayed SAR close counter from this newly created normal order.
   // This fixes: close on 2nd/4th SAR change FROM THE CREATED ORDER, not global SAR changes.
   if(InpUseDelayedSARChangeClose && InpResetSARCloseCounterOnNewOrder)
     {
      g_sarChangesAfterLastNormalOrder = 0;
      g_sarCloseTrackedDirection       = direction;
      g_sarCloseTrackedOrderTime       = TimeCurrent();
      g_sarDelayedCloseStatus          = "TRACK " + DirectionText(direction) + " 0/" +
                                         IntegerToString(MathMax(1, InpCloseOrdersOnNthSARChangeAfterOrder));

      Print("DELAYED SAR CLOSE COUNTER RESET BY NEW ORDER | Direction=", DirectionText(direction),
            " | Ticket=", ticket,
            " | CloseOnChange=", MathMax(1, InpCloseOrdersOnNthSARChangeAfterOrder));
     }

   g_lastOrderOpenReason = "SUCCESS | Ticket=" + IntegerToString(ticket) +
                           " | Direction=" + DirectionText(direction) +
                           " | Lot=" + DoubleToString(lot, 2) +
                           " | Price=" + DoubleToString(price, Digits) +
                           " | Source=" + reason +
                           " | Comment=" + orderComment;

   Print("Opened ", DirectionText(direction), " ticket=", ticket,
         " lot=", DoubleToString(lot, 2),
         " reason=", reason,
         " comment=", orderComment,
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
         if((OrderType() == OP_BUY || OrderType() == OP_SELL) && !IsSARGuardOrderComment(OrderComment()))
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

int CountOpenOrders()
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

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      total++;
     }

   return(total);
  }
int CountOpenOrdersByType(int type)
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

      if(OrderType() == type && !IsSARGuardOrderComment(OrderComment()))
         total++;
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
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type && !IsSARGuardOrderComment(OrderComment()))
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
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type && !IsSARGuardOrderComment(OrderComment()))
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

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;
      double closeProfit = OrderProfit() + OrderSwap() + OrderCommission();
      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);

      if(!ok)
        {
         int err = GetLastError();
         Print("Close failed. Ticket=", OrderTicket(), " reason=", reason, " error=", err);
         ResetLastError();
        }
      else
        {
         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(OrderTicket(), type, closeProfit, closePrice, reason);
         RecordLastClosedNormalOrderReference(type, closePrice, OrderComment(), reason);
         RegisterSARClosedProfitOrder(type, OrderComment(), closeProfit, reason);
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

//+------------------------------------------------------------------+
void DeleteOldDashboardObjects()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name,"DXB_ROW_") == 0 ||
         StringFind(name,"DXB_LEFT_CHK_ROW_") == 0 ||
         StringFind(name,"DXB_PANEL") == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }

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

//+------------------------------------------------------------------+
//| LEFT SIDE ORDER CREATION CHECKLIST DASHBOARD                     |
//| Shows the real normal-order gates as YES/NO before OrderSend.     |
//+------------------------------------------------------------------+
int g_leftDashRow = 0;

int GetChecklistDirection()
  {
   if(g_activeSARDirection != 0)
      return(g_activeSARDirection);

   if(g_pendingSARConfirmDirection != 0)
      return(g_pendingSARConfirmDirection);

   return(GetSARDotDirection(1));
  }

string YesNo(bool ok)
  {
   return(ok ? "YES" : "NO");
  }

color YesNoColor(bool ok)
  {
   return(ok ? clrLime : clrOrangeRed);
  }

void DrawLeftPanel(string name,int x,int y,int w,int h,color bg)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void DrawLeftLabel(string name,string text,int x,int y,color clrText,int size=9)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrText);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
ObjectSetText(name,text,7,"Consolas",clrText);

  }

void LeftChecklistRow(string title,string value,bool ok,string extra="")
  {
   string rowName = "DXB_LEFT_CHK_ROW_" + IntegerToString(g_leftDashRow);
   string text = StringSubstr(title + "                         ", 0, 24) + " : " + value;
   if(extra != "")
      text = text + " " + extra;

   DrawLeftLabel(rowName,text,10,34 + (g_leftDashRow * 17),YesNoColor(ok),9);
   g_leftDashRow++;
  }

void LeftChecklistInfo(string title,string value,color clrText=clrWhite)
  {
   string rowName = "DXB_LEFT_CHK_ROW_" + IntegerToString(g_leftDashRow);
   string text = StringSubstr(title + "                         ", 0, 24) + " : " + value;
   DrawLeftLabel(rowName,text,10,34 + (g_leftDashRow * 17),clrText,9);
   g_leftDashRow++;
  }

//+------------------------------------------------------------------+
//| Left-side dashboard: SAR special guard order information          |
//+------------------------------------------------------------------+
double GetSARSpecialGuardTotalProfit()
  {
   double totalProfit = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!IsSARGuardOrderComment(OrderComment()))
         continue;

      totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
     }

   return(totalProfit);
  }

//+------------------------------------------------------------------+
int GetSARSpecialGuardParentTicket(int guardTicket, string guardComment)
  {
   string gvName = SARGuardGlobalVariableName(guardTicket);

   if(GlobalVariableCheck(gvName))
      return((int)GlobalVariableGet(gvName));

   return(ExtractSARGuardParentTicketFromComment(guardComment));
  }

//+------------------------------------------------------------------+
void DrawLeftSARSpecialGuardInfo()
  {
   int activeGuards = CountSARSpecialGuardOrders();
   double guardProfit = GetSARSpecialGuardTotalProfit();

   LeftChecklistInfo("----- SAR SPECIAL GUARD -----", "", clrYellow);

   LeftChecklistInfo("Guard Enabled",
                     InpUseSARSpecialGuardOrder ? "YES" : "NO",
                     InpUseSARSpecialGuardOrder ? clrLime : clrOrangeRed);

   LeftChecklistInfo("Guard Active/Max",
                     IntegerToString(activeGuards) + "/" + IntegerToString(InpMaxSARSpecialGuardOrders),
                     activeGuards > 0 ? clrYellow : clrSilver);

   LeftChecklistInfo("Guard Total Profit",
                     "$" + DoubleToString(guardProfit, 2),
                     guardProfit >= 0.0 ? clrLime : clrRed);

   LeftChecklistInfo("Guard Last Status",
                     StringSubstr(g_sarSpecialGuardLastStatus, 0, 70),
                     SARSpecialGuardDebugColor());

   LeftChecklistInfo("Guard Last Time",
                     DashboardTimeText(g_sarSpecialGuardLastStatusTime),
                     g_sarSpecialGuardLastStatusTime > 0 ? clrYellow : clrSilver);

   LeftChecklistInfo("Guard Last Parent",
                     g_sarSpecialGuardLastParentTicket > 0 ?
                     ("#" + IntegerToString(g_sarSpecialGuardLastParentTicket) +
                      " P=$" + DoubleToString(g_sarSpecialGuardLastParentProfit, 2) +
                      " P+R=$" + DoubleToString(g_sarSpecialGuardLastParentRecoveryProfit, 2)) : "NONE",
                     g_sarSpecialGuardLastParentTicket > 0 ? SARSpecialGuardDebugColor() : clrSilver);

   LeftChecklistInfo("Guard ReqLot/Error",
                     "Lot " + DoubleToString(g_sarSpecialGuardLastRequestedLot, 2) +
                     " | Err " + IntegerToString(g_sarSpecialGuardLastError),
                     g_sarSpecialGuardLastError == 0 ? clrSilver : clrRed);

   if(activeGuards <= 0)
     {
      LeftChecklistInfo("Guard Orders", "NONE", clrSilver);
      return;
     }

   int shown = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(!IsSARGuardOrderComment(OrderComment()))
         continue;

      int guardTicket = OrderTicket();
      int parentTicket = GetSARSpecialGuardParentTicket(guardTicket, OrderComment());
      int guardDir = (OrderType() == OP_BUY) ? 1 : -1;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      string rowText =
         "#" + IntegerToString(guardTicket) +
         " P#" + IntegerToString(parentTicket) +
         " " + DirectionText(guardDir) +
         " L" + DoubleToString(OrderLots(), 2) +
         " $" + DoubleToString(profit, 2);

      LeftChecklistInfo("Guard " + IntegerToString(shown + 1),
                        StringSubstr(rowText, 0, 70),
                        profit >= 0.0 ? clrLime : clrRed);

      shown++;

      if(shown >= 4)
         break;
     }
  }

//+------------------------------------------------------------------+
//| Left-side dashboard: important settings used before new orders    |
//+------------------------------------------------------------------+
void DrawLeftImportantOrderSettings(int direction)
  {
   LeftChecklistInfo("----- IMPORTANT ORDER SETTINGS -----", "", clrYellow);

   LeftChecklistInfo("Lot / Slippage",
                     "Lot " + DoubleToString(InpFixedLot, 2) +
                     " | Slip " + IntegerToString(InpSlippage),
                     clrWhite);

   LeftChecklistInfo("Spread Limit",
                     IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) +
                     "/" + IntegerToString(InpMaxSpreadPoints) + " points",
                     ((int)MarketInfo(Symbol(), MODE_SPREAD) <= InpMaxSpreadPoints) ? clrLime : clrOrangeRed);

   LeftChecklistInfo("Normal Max Orders",
                     "Dir " + IntegerToString(InpMaxOrders) +
                     " | Cycle " + IntegerToString(g_sarCycleOrdersCreated) +
                     "/" + IntegerToString(g_sarCycleMaxOrders) +
                     " | Hard " + IntegerToString(DXB_HARD_MAX_OPEN_ORDERS),
                     clrAqua);

   LeftChecklistInfo("Total Order Cap",
                     InpMaxTotalOpenOrders > 0 ?
                     IntegerToString(CountAllOrders()) + "/" + IntegerToString(InpMaxTotalOpenOrders) :
                     "OFF",
                     InpMaxTotalOpenOrders > 0 ? clrAqua : clrSilver);

   LeftChecklistInfo("SAR Confirm",
                     "Diff " + DoubleToString(InpSARConfirmPriceDiff, 0) +
                     " | Min " + IntegerToString(InpSARConfirmMinutes) +
                     " | " + (InpUseSARFlipConfirmations ? "ON" : "OFF"),
                     InpUseSARFlipConfirmations ? clrLime : clrSilver);

   LeftChecklistInfo("SAR Side Filter",
                     (InpUseSARSignalPriceSideFilter ? "ON" : "OFF") +
                     " | Gap " + DoubleToString(InpSARSignalPriceSideMinGap, 0),
                     InpUseSARSignalPriceSideFilter ? clrLime : clrSilver);

   LeftChecklistInfo("Continuous Gap",
                     (InpUseRepeatedPriceGapConfirm ? "ON" : "OFF") +
                     " | Gap " + DoubleToString(InpContinuousOrderPriceGap, 0) +
                     " | Wait " + IntegerToString(InpContinuousOrderGapMinutes) + "m",
                     InpUseRepeatedPriceGapConfirm ? clrLime : clrSilver);

   LeftChecklistInfo("Min Same-Dir Gap",
                     "Min " + DoubleToString(GetEffectiveMinPriceGap(), 0) +
                     " | MultiMaxGap " + DoubleToString(InpMinGapWhenMaxOrdersMoreThanOne, 0),
                     GetEffectiveMinPriceGap() > 0.0 ? clrLime : clrSilver);

   LeftChecklistInfo("Recovery Gap",
                     (InpUseRecoveryGapOrders ? "ON" : "OFF") +
                     " | Gap " + DoubleToString(InpRecoveryGapRawPrice, 0) +
                     " | Lot " + DoubleToString(InpRecoveryGapLot, 2),
                     InpUseRecoveryGapOrders ? clrLime : clrSilver);

   LeftChecklistInfo("Recovery Count B/S",
                     IntegerToString(CountRecoveryGapOrdersByDirection(1)) + "/" +
                     IntegerToString(CountRecoveryGapOrdersByDirection(-1)) +
                     " Max " + IntegerToString(InpMaxRecoveryGapOrdersPerSide) + "/side",
                     clrAqua);

   LeftChecklistInfo("Recovery SAR Match",
                     InpRecoveryGapMustMatchSARDirection ? "YES" : "NO",
                     InpRecoveryGapMustMatchSARDirection ? clrLime : clrOrange);

   LeftChecklistInfo("Recovery Pending",
                     g_pendingRecoveryGapDirection == 0 ? "NONE" :
                     DirectionText(g_pendingRecoveryGapDirection) +
                     " Gap " + DoubleToString(g_pendingRecoveryGapMove, 0) +
                     " Req " + DoubleToString(g_pendingRecoveryRequiredGap, 0),
                     g_pendingRecoveryGapDirection == 0 ? clrSilver : clrYellow);

   LeftChecklistInfo("Special Guard",
                     (InpUseSARSpecialGuardOrder ? "ON" : "OFF") +
                     " | Active " + IntegerToString(CountSARSpecialGuardOrders()) +
                     "/" + IntegerToString(InpMaxSARSpecialGuardOrders),
                     InpUseSARSpecialGuardOrder ? clrLime : clrSilver);

   LeftChecklistInfo("Guard Trigger/Lot",
                     "Loss -$" + DoubleToString(InpSARSpecialGuardLossUSD, 2) +
                     " | Mult x" + DoubleToString(InpSARSpecialGuardLotMultiplier, 2),
                     clrAqua);

   LeftChecklistInfo("Guard SAR Condition",
                     InpSARSpecialGuardRequireSARChange ? "SAR OPPOSITE REQUIRED" : "DISABLED - LOSS ONLY",
                     InpSARSpecialGuardRequireSARChange ? clrYellow : clrLime);

   LeftChecklistInfo("Guard Rules",
                     "Close with parent | No recovery base",
                     clrYellow);

   LeftChecklistInfo("Basket TP / SL",
                     "$" + DoubleToString(GetBasketProfitTargetUSD(), 2) +
                     " / $" + DoubleToString(GetEffectiveBasketStopLossUSD(), 2),
                     clrWhite);

   LeftChecklistInfo("Profit Protect",
                     (InpUseIndividualProfitProtect ? "Ind ON" : "Ind OFF") +
                     " | " + (InpUseBasketProfitProtect ? "Basket ON" : "Basket OFF"),
                     (InpUseIndividualProfitProtect || InpUseBasketProfitProtect) ? clrLime : clrSilver);

   LeftChecklistInfo("Big Candle Block",
                     (InpUseBigCandlePause ? "ON" : "OFF") +
                     " | " + DoubleToString(InpBigCandleRawDifference, 0) +
                     " | Pause " + IntegerToString(InpBigCandlePauseMinutes) + "m",
                     InpUseBigCandlePause ? clrLime : clrSilver);

   LeftChecklistInfo("Last3 Move Block",
                     (InpUseLast3CandlesMovePause ? "ON" : "OFF") +
                     " | " + DoubleToString(InpLast3CandlesRawDifference, 0) +
                     " | Pause " + IntegerToString(InpLast3CandlesPauseMinutes) + "m",
                     InpUseLast3CandlesMovePause ? clrLime : clrSilver);

   LeftChecklistInfo("Late SAR Block",
                     (InpUseLateSARCycleEntryBlock ? "ON" : "OFF") +
                     " | Age " + IntegerToString(InpLateSARMinAgeMinutes) + "m" +
                     " | Weak<=" + IntegerToString(InpLateSARMaxWeakScore),
                     InpUseLateSARCycleEntryBlock ? clrLime : clrSilver);

   LeftChecklistInfo("SAR Weak Reverse",
                     (InpOpenReverseOrderOnSARWeakSignal ? "ON" : "OFF") +
                     " | Total " + IntegerToString(CountSARWeakReverseOrders()) +
                     "/" + IntegerToString(MathMax(1, InpMaxSARWeakReverseOrders)) +
                     " | B " + IntegerToString(CountSARWeakReverseOrdersByDirection(1)) +
                     "/" + IntegerToString(GetMaxSARWeakReverseOrdersPerSide()) +
                     " S " + IntegerToString(CountSARWeakReverseOrdersByDirection(-1)) +
                     "/" + IntegerToString(GetMaxSARWeakReverseOrdersPerSide()) +
                     " | Base " + IntegerToString(CountSARWeakReverseBaseOrdersByDirection(-g_activeSARDirection)) +
                     " | Last " + g_sarWeakReverseLastStatus,
                     InpOpenReverseOrderOnSARWeakSignal ?
                     (g_sarWeakReverseLastStatus == "OPENED" ? clrLime : clrYellow) : clrSilver);

   LeftChecklistInfo("Weak Reverse Last",
                     g_sarWeakReverseLastTicket > 0 ?
                     ("#" + IntegerToString(g_sarWeakReverseLastTicket) +
                      " " + DirectionText(g_sarWeakReverseLastDirection) +
                      " " + DashboardTimeText(g_sarWeakReverseLastTime)) : g_sarWeakReverseLastReason,
                     g_sarWeakReverseLastTicket > 0 ? clrAqua : clrSilver);

   LeftChecklistInfo("Weak Basket Close",
                     OnOff(InpUseConfirmedSARWeakBasketClose) +
                     " | " + g_sarWeakBasketCloseLastStatus +
                     " | Age " + IntegerToString(g_sarWeakBasketCloseLastAgeMin) + "m" +
                     " | P " + DoubleToString(g_sarWeakBasketCloseLastProfit, 2),
                     (g_sarWeakBasketCloseLastStatus == "CLOSE PROFIT" ||
                      g_sarWeakBasketCloseLastStatus == "CLOSE OLD LOSS") ? clrLime :
                     (InpUseConfirmedSARWeakBasketClose ? clrYellow : clrSilver));

   LeftChecklistInfo("No-New Hours",
                     InpUseNoNewOrderHours ? InpNoNewOrderHourList : "OFF",
                     InpUseNoNewOrderHours ? clrAqua : clrSilver);
  }


bool CheckListTradingAllowed()
  {
   if(!IsTradeAllowed())
      return(false);
   if(IsTradeContextBusy())
      return(false);
   if(AccountStopoutLevel() > 0 && AccountFreeMargin() <= 0)
      return(false);
   return(true);
  }

bool CheckListSARConfirmationReady()
  {
   if(!InpUseSARFlipConfirmations)
      return(true);
   if(g_pendingSARConfirmDirection == 0)
      return(true);
   return(IsSARFlipConfirmationReady());
  }

bool CheckListH1Allowed(int direction)
  {
   if(direction == 0)
      return(false);
   if(!InpUseH1TrendFilter)
      return(true);

   int trend = GetH1TrendDirection();
   if(trend == 0)
      return(false);

   return(direction == trend || IsCurrentSARGoodMomentum(direction));
  }

bool CheckListCycleAllowed(int direction)
  {
   if(direction == 0)
      return(false);
   EnsureSARSignalOrderCycle(direction);
   return(g_sarCycleMaxOrders > 0 && g_sarCycleOrdersCreated < g_sarCycleMaxOrders);
  }

bool CheckListMaxOpenAllowed(int direction)
  {
   if(direction == 0)
      return(false);
   return(CountOrdersByDirection(direction) < InpMaxOrders);
  }

bool CheckListTotalOpenAllowed()
  {
   if(InpMaxTotalOpenOrders <= 0)
      return(true);
   return(CountAllOrders() < InpMaxTotalOpenOrders);
  }

bool CheckListMinGapAllowed(int direction)
  {
   if(direction == 0)
      return(false);

   double effectiveMinGap = GetEffectiveMinPriceGap();
   if(effectiveMinGap <= 0.0)
      return(true);

   return(IsPriceGapValid(direction, effectiveMinGap));
  }

bool CheckListSARSideAllowed(int direction)
  {
   if(!InpUseSARSignalPriceSideFilter)
      return(true);
   if(direction == 0 || g_activeSARSignalChangePrice <= 0.0)
      return(false);

   double diff = GetSARSignalSidePriceDiff(direction);
   return(diff >= MathMax(0.0, InpSARSignalPriceSideMinGap));
  }

bool CheckListRepeatedGapAllowed(int direction)
  {
   if(!InpUseRepeatedPriceGapConfirm)
      return(true);
   if(direction == 0)
      return(false);

   if(g_sarCycleOrdersCreated <= 0)
      return(true);

   if(g_lastClosedNormalOrderPrice <= 0.0 || g_lastClosedNormalOrderTime <= 0 ||
      g_lastClosedNormalOrderDirection != direction)
      return(true);

   int waitMinutes = MathMax(0, InpContinuousOrderGapMinutes);
   int elapsedSeconds = (int)(TimeCurrent() - g_lastClosedNormalOrderTime);
   if(elapsedSeconds < 0)
      elapsedSeconds = 0;

   int requiredSeconds = waitMinutes * 60;
   if(requiredSeconds > 0 && elapsedSeconds < requiredSeconds)
      return(false);

   double livePrice = (direction == 1) ? Ask : Bid;
   double gap = 0.0;

   if(direction == 1)
      gap = livePrice - g_lastClosedNormalOrderPrice;
   else
      gap = g_lastClosedNormalOrderPrice - livePrice;

   return(gap >= InpContinuousOrderPriceGap);
  }

string CheckListRepeatedGapText(int direction)
  {
   if(!InpUseRepeatedPriceGapConfirm)
      return("OFF");
   if(direction == 0)
      return("NO DIRECTION");

   if(g_sarCycleOrdersCreated <= 0)
      return("FIRST ORDER - SAR CONFIRM ONLY");

   if(g_lastClosedNormalOrderPrice <= 0.0 || g_lastClosedNormalOrderTime <= 0 ||
      g_lastClosedNormalOrderDirection != direction)
      return("NO CLOSED ORDER REF - SAME SAR");

   int waitMinutes = MathMax(0, InpContinuousOrderGapMinutes);
   int elapsedSeconds = (int)(TimeCurrent() - g_lastClosedNormalOrderTime);
   if(elapsedSeconds < 0)
      elapsedSeconds = 0;

   int requiredSeconds = waitMinutes * 60;
   double elapsedMinutes = elapsedSeconds / 60.0;

   double livePrice = (direction == 1) ? Ask : Bid;
   double gap = 0.0;

   if(direction == 1)
      gap = livePrice - g_lastClosedNormalOrderPrice;
   else
      gap = g_lastClosedNormalOrderPrice - livePrice;

   if(requiredSeconds > 0 && elapsedSeconds < requiredSeconds)
     {
      int leftSeconds = requiredSeconds - elapsedSeconds;
      return("WAIT " + IntegerToString(leftSeconds) +
             "s from close, gap " + DoubleToString(gap,1) +
             "/" + DoubleToString(InpContinuousOrderPriceGap,0));
     }

   return(DoubleToString(gap,1) + "/" + DoubleToString(InpContinuousOrderPriceGap,0) +
          " from closed " + DirectionText(g_lastClosedNormalOrderDirection) +
          " after " + DoubleToString(elapsedMinutes,1) + "m");
  }


//+------------------------------------------------------------------+
//| PROFESSIONAL DASHBOARD HELPERS                                   |
//+------------------------------------------------------------------+
int g_rightDashRow = 0;
int g_recoveryDashRow = 0;
int g_guardDashRow = 0;

void DrawCornerPanel(string name,int corner,int x,int y,int w,int h,color bg,color border=clrDimGray)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void DrawCornerLabel(string name,string text,int corner,int x,int y,color clrText,int size=9)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,corner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrText);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetText(name,text,size,"Consolas",clrText);
  }

string PadTitle(string title,int len=22)
  {
   return(StringSubstr(title + "                              ",0,len));
  }

void LeftProRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,22) + " : " + value;
   DrawCornerLabel("DXB_PRO_LEFT_"+IntegerToString(g_leftDashRow),text,CORNER_LEFT_UPPER,10,45+(g_leftDashRow*16),clrText,8);
   g_leftDashRow++;
  }

void LeftProCheck(string title,bool ok,string extra="")
  {
   string value = YesNo(ok);
   if(extra != "") value = value + " " + extra;
   LeftProRow(title,value,YesNoColor(ok));
  }

void RecoveryRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,22) + " : " + value;
   DrawCornerLabel("DXB_PRO_REC_"+IntegerToString(g_recoveryDashRow),text,CORNER_LEFT_UPPER,10,625+(g_recoveryDashRow*16),clrText,8);
   g_recoveryDashRow++;
  }

void RightProRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,20) + " : " + value;
   DrawCornerLabel("DXB_PRO_RIGHT_"+IntegerToString(g_rightDashRow),text,CORNER_RIGHT_UPPER,315,310+(g_rightDashRow*16),clrText,8);
   g_rightDashRow++;
  }

void GuardTopRow(string title,string value,color clrText=clrWhite)
  {
   // Compact top-center guard panel: 3 columns instead of one tall list.
   int col = g_guardDashRow / 4;
   int row = g_guardDashRow % 4;
   int x = 440 + (col * 260);
   int y = 45 + (row * 16);

   string text = PadTitle(title,17) + " : " + value;
   DrawCornerLabel("DXB_PRO_GUARD_"+IntegerToString(g_guardDashRow),text,CORNER_LEFT_UPPER,x,y,clrText,8);
   g_guardDashRow++;
  }

color DirectionColor(int direction)
  {
   if(direction == 1) return(clrLime);
   if(direction == -1) return(clrRed);
   return(clrSilver);
  }

string OnOff(bool v)
  {
   return(v ? "ON" : "OFF");
  }

void DrawTopSARSpecialGuardPanel()
  {
   int activeGuards = CountSARSpecialGuardOrders();
   double guardProfit = GetSARSpecialGuardTotalProfit();

   DrawCornerPanel("DXB_TOP_GUARD_PANEL",CORNER_LEFT_UPPER,430,15,840,125,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_TOP_GUARD_TITLE","SAR SPECIAL GUARD DASHBOARD",CORNER_LEFT_UPPER,695,22,clrYellow,10);

   g_guardDashRow = 0;

   GuardTopRow("Status",InpUseSARSpecialGuardOrder ? "ACTIVE" : "OFF",InpUseSARSpecialGuardOrder ? clrLime : clrRed);
   GuardTopRow("Guard Active",IntegerToString(activeGuards)+" / "+IntegerToString(InpMaxSARSpecialGuardOrders),activeGuards>0 ? clrYellow : clrSilver);
   GuardTopRow("Guard Profit","$"+DoubleToString(guardProfit,2),guardProfit>=0.0 ? clrLime : clrRed);
   GuardTopRow("Trigger Loss","-$"+DoubleToString(InpSARSpecialGuardLossUSD,2),clrAqua);
   GuardTopRow("Lot Multiplier",DoubleToString(InpSARSpecialGuardLotMultiplier,2)+"x",clrAqua);
   GuardTopRow("SAR Required",InpSARSpecialGuardRequireSARChange ? "YES" : "NO",InpSARSpecialGuardRequireSARChange ? clrYellow : clrLime);
   GuardTopRow("Close Rule",InpSpecialGuardCloseOnlyInProfit ? "PARENT CLOSE + PROFIT" : "PARENT CLOSE",clrYellow);
   GuardTopRow("Min Close Profit","$"+DoubleToString(InpSpecialGuardMinProfitToClose,2),clrWhite);
   GuardTopRow("Last Action",StringSubstr(g_sarSpecialGuardLastStatus,0,48),SARSpecialGuardDebugColor());
   GuardTopRow("Last Error",IntegerToString(g_sarSpecialGuardLastError),g_sarSpecialGuardLastError==0 ? clrSilver : clrRed);
   GuardTopRow("Last Parent",g_sarSpecialGuardLastParentTicket>0 ? "#"+IntegerToString(g_sarSpecialGuardLastParentTicket) : "NONE",g_sarSpecialGuardLastParentTicket>0 ? clrYellow : clrSilver);
   GuardTopRow("Last Update",DashboardTimeText(g_sarSpecialGuardLastStatusTime),g_sarSpecialGuardLastStatusTime>0 ? clrAqua : clrSilver);
  }

void DrawRecoveryChecklistPanel(int direction)
  {
   bool enabled = InpUseRecoveryGapOrders;
   bool matchOk = (!InpRecoveryGapMustMatchSARDirection || direction == g_activeSARDirection);
   bool countOk = (CountRecoveryGapOrdersByDirection(1) < InpMaxRecoveryGapOrdersPerSide || CountRecoveryGapOrdersByDirection(-1) < InpMaxRecoveryGapOrdersPerSide);
   bool pending = (g_pendingRecoveryGapDirection != 0);
   bool bigOk = !IsBigCandlePauseActive();
   bool spikeOk = !IsSpikeWickPauseActive();
   bool strongOk = true;
   bool allowed = enabled && matchOk && countOk && bigOk && spikeOk && strongOk;

   DrawCornerPanel("DXB_RECOVERY_PANEL",CORNER_LEFT_UPPER,5,595,405,260,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_RECOVERY_TITLE","RECOVERY ORDER CHECKLIST",CORNER_LEFT_UPPER,10,602,clrYellow,9);

   g_recoveryDashRow = 0;
   RecoveryRow("Recovery Enabled",YesNo(enabled),enabled ? clrLime : clrRed);
   RecoveryRow("Recovery Allowed",YesNo(allowed),allowed ? clrLime : clrOrangeRed);
   RecoveryRow("SAR Direction",DirectionText(g_activeSARDirection),DirectionColor(g_activeSARDirection));
   RecoveryRow("Direction Match",YesNo(matchOk),matchOk ? clrLime : clrOrangeRed);
   RecoveryRow("Required Gap",DoubleToString(InpRecoveryGapRawPrice,0),clrAqua);
   RecoveryRow("Gap Levels",DoubleToString(InpRecoveryGapRawPrice,0)+","+DoubleToString(InpRecoveryGapRawPrice*2,0)+","+DoubleToString(InpRecoveryGapRawPrice*3,0),clrAqua);
   RecoveryRow("Recovery Count",IntegerToString(CountRecoveryGapOrdersByDirection(1))+"/"+IntegerToString(CountRecoveryGapOrdersByDirection(-1))+" | Max "+IntegerToString(InpMaxRecoveryGapOrdersPerSide),countOk ? clrLime : clrOrangeRed);
   RecoveryRow("Pending Recovery",pending ? DirectionText(g_pendingRecoveryGapDirection)+" Gap "+DoubleToString(g_pendingRecoveryGapMove,0) : "NONE",pending ? clrYellow : clrSilver);
   RecoveryRow("Pending Reason",StringSubstr(g_pendingRecoveryGapReason,0,42),pending ? clrYellow : clrSilver);
   RecoveryRow("Big Candle Block",YesNo(!bigOk),bigOk ? clrLime : clrOrangeRed);
   RecoveryRow("Spike/Wick Block",YesNo(!spikeOk),spikeOk ? clrLime : clrOrangeRed);
   RecoveryRow("Strong Opp Block",OnOff(InpStopRecoveryOnStrongOppMove)+" | Gap "+DoubleToString(InpStrongOppMoveBlockRecoveryGap,0),clrYellow);
   RecoveryRow("Reverse With Rec",OnOff(InpOpenReverseOrderWithRecovery),InpOpenReverseOrderWithRecovery ? clrYellow : clrSilver);
  }


void DrawLeftOrderCreationChecklist(string mainStatus)
  {
   RefreshRates();

   int direction = GetChecklistDirection();
   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   string lateSARBlockReasonForDashboard = "";

   bool okDirection     = (direction != 0);
   bool okTrading       = CheckListTradingAllowed();
   bool okSpread        = (spread <= InpMaxSpreadPoints);
   bool okEquity        = (!g_equityProtectionHit && !(g_dailyProfitLock && InpPauseAfterProfitTarget));
   bool okNoHour        = (!IsNoNewOrderHour());
   bool okProfitPause   = (!IsProfitProtectPauseActive());
   bool okBigCandle     = (!IsBigCandlePauseActive());
   bool okSpikeWick     = (!IsSpikeWickPauseActive());
   bool okSARConfirm    = CheckListSARConfirmationReady();
   bool okH1            = CheckListH1Allowed(direction);
   bool okCycle         = CheckListCycleAllowed(direction);
   bool okMaxOpen       = CheckListMaxOpenAllowed(direction);
   bool okTotalOpen     = CheckListTotalOpenAllowed();
   bool okMinGap        = CheckListMinGapAllowed(direction);
   bool okSARSide       = CheckListSARSideAllowed(direction);
   bool okLateSAR       = !IsLateSARCycleEntryDanger(direction, lateSARBlockReasonForDashboard);
   bool okRepeatedGap   = CheckListRepeatedGapAllowed(direction);

   bool allOk = okDirection && okTrading && okSpread && okEquity && okNoHour &&
                okProfitPause && okBigCandle && okSpikeWick && okSARConfirm && okH1 && okCycle &&
                okMaxOpen && okTotalOpen && okMinGap && okSARSide && okLateSAR && okRepeatedGap;

   DrawCornerPanel("DXB_LEFT_CHK_PANEL",CORNER_LEFT_UPPER,5,15,405,565,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_LEFT_CHK_TITLE","ORDER CREATION CHECKLIST",CORNER_LEFT_UPPER,10,22,clrYellow,10);

   g_leftDashRow = 0;

   LeftProRow("FINAL RESULT",allOk ? "READY TO OPEN" : "BLOCKED",allOk ? clrLime : clrOrangeRed);
   LeftProRow("Status",StringSubstr(mainStatus,0,55),clrAqua);
   LeftProRow("Last Block",StringSubstr(g_lastOrderOpenReason,0,55),g_lastOrderOpenReason=="WAIT ORDER" ? clrWhite : clrOrange);
   LeftProRow("Block Time",DashboardTimeText(g_lastOrderBlockTime),clrSilver);
   LeftProRow("Last Close",StringSubstr(g_lastOrderCloseMessage,0,55),g_lastOrderCloseMessage=="NO CLOSE YET" ? clrSilver : clrAqua);

   LeftProRow("--- ORDER SIGNAL ---","",clrDimGray);
   LeftProCheck("Direction",okDirection,DirectionText(direction));
   LeftProCheck("SAR Confirm",okSARConfirm,SARConfirmDurationStatusText());
   LeftProRow("SAR Age",IntegerToString(GetSARSignalAgeMinutes())+"m / "+IntegerToString(InpDynamicMinSignalMinutes)+"m",GetSARSignalAgeMinutes()>=InpDynamicMinSignalMinutes ? clrLime : clrOrange);
   LeftProCheck("SAR Price Side",okSARSide,SARSignalSideStatusText());
   LeftProCheck("Repeated Gap",okRepeatedGap,CheckListRepeatedGapText(direction));
   LeftProCheck("SAR Cycle",okCycle,IntegerToString(g_sarCycleOrdersCreated)+"/"+IntegerToString(g_sarCycleMaxOrders));

   LeftProRow("--- TREND FILTERS ---","",clrDimGray);
   LeftProCheck("H1 Trend",okH1,DirectionText(GetH1TrendDirection()));
   LeftProRow("EMA Trend",DirectionText(g_pendingSARConfirmDirection),DirectionColor(g_pendingSARConfirmDirection));
   LeftProRow("Early Trend",DirectionText(g_earlyDirection),DirectionColor(g_earlyDirection));
   LeftProRow("SAR Momentum",IsCurrentSARGoodMomentum(g_activeSARDirection) ? "GOOD" : "WEAK",IsCurrentSARGoodMomentum(g_activeSARDirection) ? clrLime : clrOrangeRed);
   LeftProRow("SAR Weak Mark",StringSubstr(g_lastSARWeakSignalMarkerReason,0,45),g_lastSARWeakSignalMarkerReason=="OFF" ? clrSilver : InpSARWeakSignalMarkerColor);
   LeftProCheck("Late Entry",okLateSAR,LateSARCycleEntryStatusText(direction));
   LeftProRow("SAR Score",IntegerToString(g_dynamicSARScore)+" / "+IntegerToString(InpDynamicStrongScore)+" | "+g_dynamicSARDecision,g_dynamicSARScore>=InpDynamicStrongScore ? clrLime : clrOrange);

   LeftProRow("--- TRADING FILTERS ---","",clrDimGray);
   LeftProCheck("Trading Allowed",okTrading);
   LeftProCheck("Spread OK",okSpread,IntegerToString(spread)+"/"+IntegerToString(InpMaxSpreadPoints));
   LeftProCheck("Equity/Daily Lock",okEquity);
   LeftProCheck("No-New-Hour",okNoHour,NoNewOrderHoursStatusText());
   LeftProCheck("Profit Pause",okProfitPause,ProfitProtectPauseStatusText());
   LeftProCheck("Big Candle Pause",okBigCandle,BigCandlePauseStatusText());
   LeftProCheck("Spike/Wick Pause",okSpikeWick,SpikeWickPauseStatusText());
   LeftProCheck("Min Gap",okMinGap,DoubleToString(GetEffectiveMinPriceGap(),0));

   LeftProRow("--- ORDER LIMITS ---","",clrDimGray);
   LeftProCheck("Max Open Dir",okMaxOpen,IntegerToString(CountOrdersByDirection(direction))+"/"+IntegerToString(InpMaxOrders));
   LeftProCheck("Total Open",okTotalOpen,IntegerToString(CountAllOrders())+"/"+IntegerToString(InpMaxTotalOpenOrders));
   LeftProRow("Next Order",allOk ? "ALLOWED NOW" : "WAIT / BLOCKED",allOk ? clrLime : clrOrangeRed);

   DrawRecoveryChecklistPanel(direction);
   DrawTopSARSpecialGuardPanel();
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
ObjectSetText(name,text,7,"Consolas",clr);
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
      315,
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
   DrawCornerPanel("DXB_RIGHT_SETTINGS_PANEL",CORNER_RIGHT_UPPER,325,280,320,575,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_RIGHT_SETTINGS_TITLE","Version 5 / LIVE STATUS",CORNER_RIGHT_UPPER,300,287,clrYellow,10);

   g_rightDashRow = 0;

   RightProRow("Status",StringSubstr(status,0,38),clrYellow);
   RightProRow("--- TRADING ---","",clrDimGray);
   RightProRow("Lot Size",DoubleToString(InpFixedLot,2),clrWhite);
   RightProRow("Slippage",IntegerToString(InpSlippage),clrWhite);
   RightProRow("Spread Limit",IntegerToString((int)MarketInfo(Symbol(),MODE_SPREAD))+" / "+IntegerToString(InpMaxSpreadPoints),((int)MarketInfo(Symbol(),MODE_SPREAD)<=InpMaxSpreadPoints) ? clrLime : clrRed);
   RightProRow("Basket TP Base","$"+DoubleToString(InpBasketProfitUSD,2),clrLime);
   RightProRow("Basket TP Live","$"+DoubleToString(GetBasketProfitTargetUSD(),2) + (InpUseSimpleSideBasketCloseOnly ? " SIMPLE" : ""),clrYellow);
   RightProRow("TP Time Decay",BasketProfitTimeDecayStatusText(),InpUseBasketProfitTimeDecay ? clrAqua : clrSilver);
   RightProRow("Basket SL Live","$"+DoubleToString(GetEffectiveBasketStopLossUSD(),2) + (InpUseSimpleSideBasketCloseOnly ? " SIMPLE" : ""),clrRed);
   RightProRow("Market Mode",AutoMarketModeStatusText(),MarketFlowModeColor());
   RightProRow("Ind Profit Protect",OnOff(InpUseIndividualProfitProtect),InpUseIndividualProfitProtect ? clrLime : clrSilver);
   RightProRow("Basket Protect",OnOff(InpUseBasketProfitProtect),InpUseBasketProfitProtect ? clrLime : clrSilver);

   RightProRow("--- RECOVERY ---","",clrDimGray);
   RightProRow("Recovery Gap",DoubleToString(InpRecoveryGapRawPrice,0),clrAqua);
   RightProRow("Recovery Lot",DoubleToString(InpRecoveryGapLot,2),clrAqua);
   RightProRow("Max Recovery",IntegerToString(InpMaxRecoveryGapOrdersPerSide),clrAqua);
   RightProRow("Reverse Recovery",OnOff(InpOpenReverseOrderWithRecovery),InpOpenReverseOrderWithRecovery ? clrYellow : clrSilver);
   RightProRow("Opp Move Block",OnOff(InpStopRecoveryOnStrongOppMove)+" | "+DoubleToString(InpStrongOppMoveBlockRecoveryGap,0),clrYellow);
   RightProRow("Mode Recovery",IsAutoMarketRecoveryAllowed() ? "ALLOW" : "BLOCK",IsAutoMarketRecoveryAllowed() ? clrLime : clrRed);
   RightProRow("Mode Weak/Pull",(IsAutoMarketSARWeakAllowed() ? "W" : "-") + "/" + (IsAutoMarketPullbackAllowed() ? "P" : "-"),(IsAutoMarketSARWeakAllowed() || IsAutoMarketPullbackAllowed()) ? clrLime : clrRed);

   RightProRow("--- SAR SETTINGS ---","",clrDimGray);
   RightProRow("SAR Direction",DirectionText(g_activeSARDirection),DirectionColor(g_activeSARDirection));
   RightProRow("Confirm Gap",DoubleToString(InpSARConfirmPriceDiff,0),clrAqua);
   RightProRow("Confirm Minutes",IntegerToString(InpSARConfirmMinutes),clrAqua);
   RightProRow("Continuous Gap",DoubleToString(InpContinuousOrderPriceGap,0),clrAqua);
   RightProRow("Gap Wait",IntegerToString(InpContinuousOrderGapMinutes)+"m",clrAqua);
   RightProRow("Signal Side Gap",DoubleToString(InpSARSignalPriceSideMinGap,0),clrAqua);
   RightProRow("SAR Cycle",IntegerToString(g_sarCycleOrdersCreated)+"/"+IntegerToString(g_sarCycleMaxOrders),g_sarCycleOrdersCreated>=g_sarCycleMaxOrders ? clrOrangeRed : clrLime);

   RightProRow("--- PROTECTION ---","",clrDimGray);
   RightProRow("Big Candle",DoubleToString(InpBigCandleRawDifference,0)+" | Pause "+IntegerToString(InpBigCandlePauseMinutes)+"m",clrYellow);
   RightProRow("Big Marker",OnOff(InpDrawBigCandleRedMarker)+" | RED",InpDrawBigCandleRedMarker ? clrRed : clrSilver);
   RightProRow("Last3 Move",DoubleToString(InpLast3CandlesRawDifference,0)+" | Pause "+IntegerToString(InpLast3CandlesPauseMinutes)+"m",clrYellow);
   RightProRow("Spike/Wick",DoubleToString(InpSpikeWickMinRawPrice,0)+" | R"+DoubleToString(InpSpikeMomentumRangeRawPrice,0)+" B"+DoubleToString(InpSpikeMomentumBodyRawPrice,0),clrYellow);
   RightProRow("Spike Pause",IntegerToString(InpSpikeWickPauseMinutes)+"m | Yellow marker "+OnOff(InpDrawSpikeWickYellowMarker),clrYellow);
   RightProRow("SAR Weak Marker",OnOff(InpDrawSARWeakSignalMarker)+" | Violet",InpDrawSARWeakSignalMarker ? InpSARWeakSignalMarkerColor : clrSilver);
   RightProRow("Weak Basket Close",
               OnOff(InpUseConfirmedSARWeakBasketClose) +
               " | Profit>=$" + DoubleToString(InpSARWeakMinProfitToClose,2) +
               " | Age " + IntegerToString(InpSARWeakBasketAgeMinutes) +
               "m Loss<=$" + DoubleToString(InpSARWeakMaxSmallLossToCloseUSD,2),
               InpUseConfirmedSARWeakBasketClose ? clrLime : clrSilver);
   RightProRow("Spike Status",SpikeWickPauseStatusText(),IsSpikeWickPauseActive() ? clrOrangeRed : clrSilver);
   RightProRow("Global Trail",g_globalEquityTrailStatus,g_globalEquityTrailLocked ? clrOrangeRed : clrAqua);
   RightProRow("No-New Hours",NoNewOrderHoursStatusText(),IsNoNewOrderHour() ? clrOrangeRed : clrLime);

   DrawCornerPanel("DXB_RIGHT_ACCOUNT_PANEL",CORNER_RIGHT_UPPER,325,15,320,250,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_RIGHT_ACCOUNT_TITLE","ACCOUNT / BASKET STATUS",CORNER_RIGHT_UPPER,300,23,clrYellow,10);

   int startRow = g_rightDashRow;
   g_rightDashRow = 0;
   int baseY = 47;

   DrawCornerLabel("DXB_ACC_0",PadTitle("Balance",20)+" : $"+DoubleToString(AccountBalance(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrWhite,8);
   DrawCornerLabel("DXB_ACC_1",PadTitle("Equity",20)+" : $"+DoubleToString(AccountEquity(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);
   DrawCornerLabel("DXB_ACC_2",PadTitle("Equity Peak",20)+" : $"+DoubleToString(g_globalEquityPeak,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);
   DrawCornerLabel("DXB_ACC_3",PadTitle("Base Balance",20)+" : $"+DoubleToString(g_baseBalance,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrWhite,8);
   DrawCornerLabel("DXB_ACC_4",PadTitle("BUY Basket",20)+" : $"+DoubleToString(GetBasketProfit(1),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetBasketProfit(1)>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_5",PadTitle("SELL Basket",20)+" : $"+DoubleToString(GetBasketProfit(-1),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetBasketProfit(-1)>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_6",PadTitle("Floating Total",20)+" : $"+DoubleToString(GetAllOpenEAOrdersProfit(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetAllOpenEAOrdersProfit()>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_7",PadTitle("Daily Target",20)+" : $"+DoubleToString(g_profitTargetEquity,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrLime,8);
   DrawCornerLabel("DXB_ACC_8",PadTitle("Loss Stop",20)+" : $"+DoubleToString(g_lossStopEquityLevel,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrRed,8);
   DrawCornerLabel("DXB_ACC_9",PadTitle("Open Orders",20)+" : "+IntegerToString(CountAllOrders())+" / "+IntegerToString(InpMaxTotalOpenOrders),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),CountAllOrders()>=InpMaxTotalOpenOrders && InpMaxTotalOpenOrders>0 ? clrOrangeRed : clrLime,8);
   DrawCornerLabel("DXB_ACC_10",PadTitle("SAR Max Rule",20)+" : Max "+IntegerToString(GetDynamicSARMaxOrders()),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetDynamicSARMaxOrders()<=0 ? clrRed : clrYellow,8);
   DrawCornerLabel("DXB_ACC_11",PadTitle("Next Reset",20)+" : "+FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);

   g_rightDashRow = startRow;

   Print("DASHBOARD UPDATE | Status=", status,
         " | SAR=", DirectionText(g_activeSARDirection),
         " | Early=", DirectionText(g_earlyDirection),
         " | SAR Paused=", (g_sarPausedByEarly ? "YES" : "NO"),
         " | Flat Mode=", (g_flatMode ? "YES" : "NO"),
         " | Spike/Wick=", SpikeWickPauseStatusText(),
         " | EquityCycle=#", IntegerToString(g_equityCycleNumber),
         " | NextReset=", FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()));
  }

//+------------------------------------------------------------------+