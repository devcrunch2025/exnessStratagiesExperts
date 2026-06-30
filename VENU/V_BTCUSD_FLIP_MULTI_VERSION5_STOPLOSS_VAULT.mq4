//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA.mq4                  |
//|  SAR cycle + server-side SL + dynamic X-profit ladder          |
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
#property version   "1.47"

//======================== INPUTS ====================================
string InpEAName                  = "DXB Version 5 - SAR Confirm 50 in 5 Min";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 1;     // maximum OPEN orders PER TYPE: BUY limit and SELL limit are independent
double InpMinGapWhenMaxOrdersMoreThanOne = 100.0; // when InpMaxOrders > 1, enforce at least this raw price gap between same-direction open orders

#define DXB_HARD_MAX_OPEN_ORDERS 6  // absolute safety cap for normal SAR orders per cycle

double InpBasketProfitUSD         = 0.50;  // X1 base: custom ladder starts $0.50, $0.75, $0.875, $1.00...
double InpProfitTargetPercent      = 20;//50.0;//50   // stop trading when equity reaches Base + 100%


// Dynamic basket profit ladder:
// The BUY basket and SELL basket are managed independently.
// The first two X levels can have a larger opening gap. After the second
// level, InpDynamicBasketMultiplierStep is added repeatedly.
// Defaults with InpBasketProfitUSD=$0.50:
//   X1.00=$0.50, X1.50=$0.75, X1.75=$0.875, X2.00=$1.00,
//   X2.25=$1.125, X2.50=$1.25, X2.75=$1.375...
// Profit keeps moving upward through every completed level.
// Close only when profit comes back to the highest protected level.
bool   InpUseDynamicBasketProfitBooking    = true;
double InpDynamicBasketFirstLevelX          = 1.00; // first completed/protected ladder level
double InpDynamicBasketSecondLevelX         = 1.25; // second completed/protected ladder level
double InpDynamicBasketMultiplierStep       = 0.25; // added after X1.50: X1.75, X2.00, X2.25...
double InpDynamicBasketProfitMaxX           = 0.0;  // 0 = unlimited; otherwise highest protected X multiplier

// Broker/server-side dynamic profit protection:
// PRE-LADDER SMALL PROFIT LOCK with the defaults below:
//   Basket peak reaches $0.20 -> arm EA floor $0.05.
//   Server-side SL aims near $0.06 ($0.05 floor + $0.01 buffer).
//   If price reaches X1.0=$0.50, the same SL advances to that ladder level.
//   It then continues at X1.5=$0.75, X1.75=$0.875, X2.0=$1.00...
// A common side-basket SL is applied to every regular/recovery market order.
// Existing SL values never move backward toward greater risk.
// Buffer helps cover commission, swap changes, tick rounding and normal slippage.
bool   InpUseServerSideProfitLock            = true;
double InpServerProfitLockBufferUSD          = 0.01;
int    InpServerProfitLockRetrySeconds       = 5;

// Optional extra fall below the completed level before closing.
// 0.00 = close as soon as profit returns to the protected X level.
double InpDynamicBasketReturnBufferUSD     = 0.00;

// Pre-ladder minimum profit protection with a separate activation threshold:
// The basket must first reach InpDynamicBasketMinimumArmUSD before the
// small InpDynamicBasketMinimumCloseUSD floor becomes protected.
// It does NOT close while profit is still rising.
// With the default custom ladder:
//   peak below $0.20        => no small-profit lock yet
//   peak reaches $0.20      => EA floor $0.05; server SL aims near $0.06
//   peak reaches X1.0 $0.50 => advance protection to X1.0
//   peak reaches X1.5 $0.75 => advance protection to X1.5
//   peak reaches X1.75      => advance protection to X1.75, continuing by X0.25
// Close only when current profit comes back to the highest protected value.
double InpDynamicBasketMinimumArmUSD       =0.20;// 0.10;//0.15;//0.20;//before Dynamic profit
double InpDynamicBasketMinimumCloseUSD     = 0.05;//0.02;//0.05;//0.10;//0.10;//before Dynamic profit

// Drawdown comeback trailing floor:
// Once a BUY/SELL basket touches a negative loss step, remember the worst loss
// separately for that side. The reduced positive comeback target becomes the
// MINIMUM protected profit floor; it does NOT close immediately on the way up.
// Profit keeps advancing through the X ladder and closes only after coming back
// from the highest peak to the best protected level reached.
// Example with InpBasketProfitUSD=$0.40 and loss step=$1.00:
//   touched -$1.xx => arm minimum lock at $0.40/2 = $0.20
//   then custom levels X1=$0.40, X1.5=$0.60, X1.75=$0.70... keep moving upward
//   if peak reaches $1.05, the highest completed custom level is protected
// The rule continues automatically for deeper whole-dollar drawdown levels.
bool   InpUseDynamicBasketDrawdownComebackTP = true;
double InpDynamicBasketDrawdownStepUSD        = 1.00;
double InpDynamicBasketMinComebackProfitUSD   = 0.01;

// MIXED market-mode basket target:
// MIXED target is always exactly InpBasketProfitUSD / 2.
// Example: InpBasketProfitUSD=$1.00 => live MIXED target=$0.50.
// It is NOT divided again by open-order count, trading hour or time decay.
//
// These two legacy inputs are retained for old SET-file compatibility.
// MIXED half TP is now an automatic market-mode rule.
bool   InpUseMixedModeHalfBasketTP       = true;  // legacy compatibility
double InpMixedModeBasketTPMultiplier    = 0.40;  // fixed/ignored: MIXED always uses 0.50

// Weak SAR-score basket target:
// When the current active SAR quality score is <= this value,
// use the same exact fixed target: InpBasketProfitUSD / 2.
// Example: score 3, 2, 1 or 0 => half TP.
bool   InpUseLowSARScoreHalfBasketTP      = true;
int    InpSARScoreHalfBasketTPMax         = 3;

// SAR-flipped old basket profit target:
// Example: a BUY basket was opened during SAR BUY, then SAR flips to SELL
// while the BUY basket remains open. The old BUY basket is closed when its
// floating profit reaches InpBasketProfitUSD * multiplier.
// This never closes the old basket in loss.
bool   InpUseSARFlipOppositeBasketHalfTP = true;
double InpSARFlipOppositeBasketTPMultiplier = 0.50;

// Time-based half TP:
// When a BUY or SELL basket remains open for this many minutes,
// reduce only that side's profit target to InpBasketProfitUSD * multiplier.
// It closes only after positive profit reaches the reduced target.
bool   InpUseBasketHalfTPAfterMinutes = true;
int    InpBasketHalfTPAfterMinutes = 30;
double InpBasketHalfTPAfterMinutesMultiplier = 0.50;

//Live
double InpBasketStopLossUSD       = 0.50;//0.25;//5;// 3;;//2;//5;//2;//5.00;    // BASKET stop loss in USD, 0 = disabled. This closes all orders in active SAR direction.

double InpContinuousTrendBasketSLUSD   = 0.50;//0.25;//3;//2;//5;//1;// 2;//5.00;
double InpMediumTrendBasketSLUSD       = 0.50;//0.25;//3;//6;// 3;////2;//10;//10;//1;//2;//10.00;
double InpMixedTrendBasketSLUSD        = 0.50;//0.25;//6;//3;// 2;//10;//5;//10;//1;//2;//10.00;
double InpDangerModeBasketSLUSD        = 0.50;//0.25;// 3;//2;//5;//1;//2;//5.00;

// Simple basket close mode:
// true = close BUY basket and SELL basket only by fixed InpBasketProfitUSD / InpBasketStopLossUSD.
// It disables auto profit/loss adjustments such as combined all-basket profit close,
// basket/individual profit protect, time-decay TP, SAR-weak basket close,
// global equity trailing close, and auto market-flow SL adjustment.
bool   InpUseSimpleSideBasketCloseOnly = false;


//================ AUTO MARKET FLOW MODE ============================
// Mode 1: CONTINUOUS TREND  => follow SAR only, SL $5, no recovery/weak/pullback.
// Mode 2: MEDIUM TREND      => SAR + recovery, SL $10, no weak/pullback.
// Mode 3: MIXED TREND       => pause ALL new trading; manage existing basket TP/SL only.
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



bool   InpAutoModePauseOrdersInDanger  = true;
bool   InpAutoModePauseOrdersInMixed   = true;  // true = block every NEW order while mode is MIXED
bool   InpAutoModeAllowRecoveryMedium  = true;
// The following MIXED permissions are used only when InpAutoModePauseOrdersInMixed=false.
bool   InpAutoModeAllowRecoveryMixed   = true;
bool   InpAutoModeAllowSARWeakMixed    = false;
bool   InpAutoModeAllowPullbackMixed   = true;

//================ DIRECT MARKET-MODE FILTER CASES ==================
// There is NO old-filter master and NO two-level enable system.
//
// Every filter is controlled directly by one TRUE/FALSE case list:
//   GlobalFilterCase()          -> used when Auto Market Mode is OFF
//   ContinuousTrendFilterCase()
//   MediumTrendFilterCase()
//   MixedTrendFilterCase()
//   DangerModeFilterCase()
//
// TRUE  = run that filter in the selected mode.
// FALSE = completely bypass that filter in the selected mode.
//
// Threshold/value inputs such as spread limit, gap, minutes and score
// remain global configuration values. They do not enable the filter.
// DIRECTION and TRADING_ALLOWED remain hard safety checks.
bool   InpUseMarketModeFilterProfiles = true;

// Opposite-direction profit-streak pause:
// When the latest normal SAR order history produces N consecutive profitable closes
// in one direction, block NEW orders in the opposite direction for the configured time.
// Example: 3 consecutive profitable BUY closes => pause new SELL orders for 120 minutes.
// Existing orders continue to be managed/closed normally. SAR special guard orders are exempt.
bool   InpUseOppositeDirectionProfitPause = false;
int    InpOppositeDirectionProfitStreakOrders = 2;
int    InpOppositeDirectionPauseMinutes = 30;

double InpLossStopPercent          = 50.0;   // stop trading when equity reaches Base - 50%

double InpBasketProfitUSD_12_17 = 0.50;//1.00; // profit target during 12,13,14,15,16,17 hours

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
bool   InpKeepPendingRecoveryGapAfterBlock = false;
bool   InpOpenPendingRecoveryWhenSARMatches = false;

double InpRecoveryGapRawPrice     = 100;//50;//200.0;   // raw price difference, not points
double InpRecoveryGapLot          = 0.02;
int    InpMaxRecoveryGapOrdersPerSide = 1;  // recovery ladder: 50, 100, 150 from first order price

// Alternate recovery trigger based on basket-loss improvement:
// The raw-price recovery gap remains active. This is an additional OR condition.
// Example with defaults:
//   basket first touches -$3.00 or lower -> arm the loss-comeback trigger
//   basket then improves by $1.00, for example -$3.00 -> -$2.00
//   create one same-direction recovery order, subject to all existing safety filters.
// Deeper losses work dynamically too: -$4 -> -$3, -$5 -> -$4, etc.
bool   InpUseRecoveryLossComebackTrigger = true;
double InpRecoveryLossArmUSD              = 2.00;
double InpRecoveryLossComebackUSD         = 1.00;

// Legacy special-guard compatibility:
// This EA no longer creates SAR special guard orders.
// The prefix is retained only to recognize and safely clean up an old open guard.
string InpSARSpecialGuardPrefix = "SAR_SPECIAL_GUARD_ORDER_FOR_";
bool   InpSpecialGuardCloseOnlyInProfit = true;
double InpSpecialGuardMinProfitToClose  = 0.01;

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
bool   InpSendTerminalAlerts          = false;    // desktop popup alert
bool   InpNotifyOnProfitLock          = true;    // notify when trading stops after profit target
bool   InpNotifyOnEquityStop          = true;    // notify when trading stops after equity/loss protection
bool   InpNotifyOnEquityRestart       = true;    // notify when trading restarts after reset hour
bool   InpNotifyOnEAStart             = true;    // notify when EA is loaded


// Continuous order controls
bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;       // 0 = disabled
double InpMinPriceGap             = 0.00;    // raw price gap, 0 = disabled

//================ PENDING ORDER ENTRY MODE ==========================
// Every approved BUY entry is placed as a BUYSTOP and every approved SELL
// entry is placed as a SELLSTOP. The pending price is at least this RAW-price
// distance from the live market. Example BTCUSD: Ask 60000 + 20 = BUYSTOP 60020.
// For a same-SAR replacement after a normal order closes, the last close price
// is used as the preferred reference; broker/live-price safety may move it farther.
bool   InpUsePendingOrderEntries             = true;
double InpPendingOrderRawGap                 = 20.0;
bool   InpPendingUseLastClosedOrderPrice     = true;
bool   InpDeletePendingOrdersOnSARChange     = true;

// Dubai no-new-order hours:
// Block ALL new EA entries during every Dubai hour listed below:
// first SAR, later SAR, extra, recovery, recovery-gap and pending entries.
// Existing market-order close/profit/protection management continues.
// TimeGMT()+4 is used, so broker-server, VPS and VPN time zones do not affect this rule.
bool   InpUseNoNewOrderHours      = true;
string InpNoNewOrderHourList      = "11,12,13,14,15,16,17,18,19,20,21,22"; // Dubai-time hours




//profit booking hours are 4,5,6,7,8

// Big candle pause protection
// Blocks normal SAR orders, SAR_FLIP_V2LAST, recovery orders, recovery-gap orders, recovery hedge orders, and current forming spike candles.
bool   InpUseBigCandlePause       = true;     // detect very large candles
// true: bullish big candle blocks only SELL; bearish big candle blocks only BUY.
// Same-direction normal and recovery orders remain allowed.
bool   InpBigCandleBlockOppositeDirectionOnly = true;
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
// A candle is a spike ONLY when:
// 1) its larger upper/lower wick reaches InpSpikeWickMinRawPrice, and
// 2) its body is no more than InpSpikeWickBodyMaxPercent of that larger wick.
// Example: Wick=100 and setting=50 => Body must be <=50.
// Long-body / momentum candles are NOT classified as spike candles here.
bool   InpUseSpikeWickPauseFilter = false;
double InpSpikeWickMinRawPrice    = 30.0;   // minimum larger wick raw price
double InpSpikeWickBodyMaxPercent = 50.0;    // body must be <= this % of the larger wick

// Legacy settings retained for old SET-file compatibility.
// They are intentionally ignored by the wick-only spike rule.
double InpSpikeMomentumRangeRawPrice = 500.0;
double InpSpikeMomentumBodyRawPrice  = 100.0;
bool   InpDrawSpikeWickYellowMarker  = true;
int    InpSpikeWickMarkerArrowCode   = 159;
int    InpSpikeWickPauseMinutes   = 15;       // wait after spike/wick detected
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
bool   InpUseSARClosedCandleConfirm = false;//false;
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
bool   InpUseRepeatedPriceGapConfirm = true;
double InpContinuousOrderPriceGap    = 10;//10.0; //30  // raw price gap required from last confirmed normal order
int    InpContinuousOrderLookbackMinutes = 1;  // legacy input, not used by current continuity gap logic
int    InpContinuousOrderGapMinutes  = 1;      // wait this many minutes after last order, then verify price gap

double InpSARConfirmPriceDiff     = 50;//80.0;   // SAR signal-change raw price diff confirmation only
int    InpSARConfirmMinutes       = 5;      // used by the full profile only
// First normal order after every SAR flip:
// true = bypass all strategy filters and require only the FIXED live raw-price
// difference in InpSARConfirmPriceDiff. Direction, broker trade permission and
// the independent BUY/SELL InpMaxOrders cap remain mandatory safety checks.
bool   InpFirstSAROrderPriceDiffOnly = true;
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
bool   InpUseSARDurationDynamicLimit = true;
int    InpSARDurationScanBars        = 1500;   // historical bars to scan for SAR changes

int    InpSARVeryLongDurationMinutes = 60;    // opposite duration >=120 min => max 0
int    InpSARVeryLongDurationMaxOrders =2;//1;// 4;

int    InpSARDurationLongMinutes     = 30;     // opposite duration 60-119 min => max 2
int    InpSARLongDurationMaxOrders   =2;//1;// 3;

int    InpSARDurationMediumMinutes   = 10;     // opposite duration 30-59 min => max 5
int    InpSARMediumDurationMaxOrders =1;//2;// 1;

int    InpSARNormalDurationMaxOrders = 10;     // opposite duration <30 min or no data => max 10


bool   InpAddOneOrderWhenSARDistanceH1Same = true;
double InpSARDistanceExtraOrderMin         = 300.0;
int    InpSARDistanceExtraOrders           = 10;
//1-?100
//2 -67
int InpSARGoodMomentumExtraOrders = 1;
bool InpResetMaxOrdersWhenSARWeak = false;

bool InpIncreaseSARMaxAfterActiveMinutes = true;
int  InpSARActiveMinutesForExtraOrders = 60;
int  InpSARActiveExtraOrders = 1;

// SAR good-momentum upgrade
// If current SAR trend is strong, increase current SAR signal-cycle max back to normal max.
bool   InpUseSARGoodMomentumMaxUpgrade = true;
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
bool   InpUseDynamicSAREngine              = true;
bool   InpBlockNewOrdersWhenSARWeak        = true;
bool   InpBlockFastSARFlip                 = true;

// STRICT SAR SCORE ENTRY:
// Every NEW market order must reach this score before OrderSend.
// Current SAR quality score range is normally 0..7.
// Legacy guard orders are recognized only for safe cleanup.
bool   InpUseStrictSARScoreEntry            = true;
int    InpStrictSARMinimumScore             = 6;     // strict recommended value: 6 of 7

//================ DOUBTFUL CANDLE NEXT CONFIRMATION ================
// Normal SAR orders only. Recovery orders are not affected.
// SELL: a long lower wick is doubtful. BUY: a long upper wick is doubtful.
// The next fully closed candle must confirm before OrderSend.
bool   InpUseDoubtfulCandleNextConfirm       = true;
double InpDoubtfulOppositeWickMinRaw         = 20.0;
double InpDoubtfulOppositeWickBodyRatio      = 0.70;
double InpDoubtfulMinBodyPercentOfRange      = 35.0;
double InpDoubtfulStrongClosePercent         = 60.0;
bool   InpDoubtfulConfirmMustBreakExtreme    = true;
double InpDoubtfulConfirmBreakBufferRaw      = 0.0;

int    InpDynamicATRPeriod                 = 14;
int    InpDynamicMinSignalMinutes          = 20;//5;//20;   // normal minimum SAR age before new normal order
int    InpDynamicVeryStrongMinMinutes      = 10;//3;//10;   // allow earlier only if score is very strong
double InpDynamicConfirmATRMultiplier      = 0.80; // replaces fixed SAR diff when dynamic engine is ON
double InpDynamicStrongDotATRMultiplier    = 1.20; // SAR dot distance must be >= ATR * this
double InpDynamicWeakDotATRMultiplier      = 0.45; // below this means SAR is too close/weak
double InpDynamicEMADistanceATRMultiplier  = 0.10; // EMA9/2InpOldFilterInputsAreMaster1 separation required
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
int    InpLateSARMaxWeakScore             = 4;    // block when dynamic SAR score is <= this value after min age
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
int    InpEarlySARWeakExitNeedSignals  = 4;     // minimum weakness points required
int    InpEarlySARWeakExitMinAgeMin    = 5;     // avoid closing immediately after fresh flip
int    InpEarlySARWeakExitCooldownSec  = 60;    // avoid repeat close loop

// Confirmed SAR weak basket close:
// Close only when weakness is confirmed/recent, not on every weak marker.
// Profitable active SAR basket closes immediately.
// Old active SAR basket can close at a controlled small loss to avoid full basket SL.
bool   InpUseConfirmedSARWeakBasketClose = false;
int    InpSARWeakCloseRecentBars         = 3;     // latest weak signal must be within this many bars
bool   InpSARWeakCloseProfitBasket       = true;
double InpSARWeakMinProfitToClose        = 0.10;
bool   InpSARWeakCloseOldSmallLoss       = false;
int    InpSARWeakBasketAgeMinutes        = 30;
double InpSARWeakMaxSmallLossToCloseUSD  = 2.00;  // close old weak basket only if loss is between 0 and -this
bool   InpSARWeakCloseResetCycle         = false;  // after close, allow fresh SAR-direction entries on next tick

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
// Latest normal pending ticket that has become an active BUY/SELL market order.
// Used to start delayed-SAR-close tracking only after actual execution.
int      g_lastActivatedPendingMarketTicket = -1;
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
int      g_lastAppliedEntryFilterMode = -999;

// Opposite-direction pause state, reconstructed from closed normal-order history.
int      g_oppositeProfitStreakDirection = 0;
int      g_oppositeProfitStreakCount = 0;
int      g_oppositePausedDirection = 0;
datetime g_oppositeDirectionPauseUntil = 0;
datetime g_oppositeDirectionPauseTriggerTime = 0;
int      g_oppositeDirectionPauseTriggerTicket = 0;
int      g_oppositeDirectionPauseWinner = 0;
int      g_oppositePauseLastHistoryTotal = -1;
datetime g_oppositePauseLastScanTime = 0;
datetime g_oppositePauseLastBlockPrintTime = 0;
int      g_oppositePauseLastPrintedDirection = 0;
string   g_oppositeDirectionPauseStatus = "WAIT 3 PROFITS";

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


// Number of profitable NORMAL SAR orders closed in the current SAR signal cycle.
// Resets whenever SAR signal changes. Used by GetIndividualProfitProtectLevel().
int      g_sarClosedProfitOrdersCount = 0;

// Last normal order open result. Used by dashboard/status when OpenMarketOrder() returns false.
string   g_lastOrderOpenReason    = "WAIT ORDER";
datetime g_lastOrderBlockTime     = 0;

// Doubtful-candle next-confirmation state for NORMAL SAR orders.
int      g_doubtConfirmDirection       = 0;
datetime g_doubtConfirmReferenceTime   = 0;
double   g_doubtConfirmReferenceHigh   = 0.0;
double   g_doubtConfirmReferenceLow    = 0.0;
double   g_doubtConfirmReferenceClose  = 0.0;
string   g_doubtConfirmStatus          = "READY";
string   g_doubtConfirmReason          = "NONE";

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

// Last recovery-gap decision/open audit.
string   g_lastRecoveryAudit          = "NONE";
datetime g_lastRecoveryAuditTime      = 0;
int      g_lastRecoveryAuditDirection = 0;
double   g_lastRecoveryAuditGap       = 0.0;

// Dynamic loss-comeback recovery memory. BUY and SELL are independent.
// A side is armed after its basket touches -InpRecoveryLossArmUSD.
// It becomes ready when loss improves by InpRecoveryLossComebackUSD.
double   g_buyRecoveryWorstBasketProfit  = 0.0;
double   g_sellRecoveryWorstBasketProfit = 0.0;
bool     g_buyRecoveryLossComebackArmed  = false;
bool     g_sellRecoveryLossComebackArmed = false;


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
// Direction of the latest detected big candle: 1 bullish, -1 bearish.
int      g_bigCandlePauseCandleDirection = 0;
// Bullish big candle blocks SELL until this time.
// Bearish big candle blocks BUY until this time.
datetime g_bigCandleBlockBuyUntil  = 0;
datetime g_bigCandleBlockSellUntil = 0;
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
// Most negative floating basket profit touched during the current side basket.
// BUY and SELL drawdown memories are independent and reset only when that side closes.
double   g_buyBasketWorstProfit   = 0.0;
double   g_sellBasketWorstProfit  = 0.0;
string   g_dynamicBasketProfitStatus = "WAIT BASKET";

// Broker-side dynamic basket-lock state. BUY and SELL retry independently.
// These runtime values are rebuilt from live orders/stops after EA restart.
datetime g_lastBuyServerLockAttemptTime  = 0;
datetime g_lastSellServerLockAttemptTime = 0;
double   g_buyServerProtectedProfit      = 0.0;
double   g_sellServerProtectedProfit     = 0.0;
double   g_buyServerStopPrice            = 0.0;
double   g_sellServerStopPrice           = 0.0;
double   g_buyServerEstimatedNetProfit   = 0.0;
double   g_sellServerEstimatedNetProfit  = 0.0;
bool     g_buyServerLockOK                = false;
bool     g_sellServerLockOK               = false;
string   g_buyServerLockStatus            = "WAIT ORDER";
string   g_sellServerLockStatus           = "WAIT ORDER";

datetime g_lastEarlySARWeakExitTime = 0;
int      g_lastEarlySARWeakExitDirection = 0;


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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool TryOpenEarlySameSARExtraOrder()
  {
// IMPORTANT: extra orders must not bypass SAR flip confirmation.
// This prevents SELL/BUY orders from opening immediately after SAR change.
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM) &&
      g_pendingSARConfirmDirection != 0)
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_H1_TREND) &&
      !IsOrderAllowedByH1Trend(g_activeSARDirection))
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_H1_TREND))
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
//| Auto Market Flow Mode helpers                                    |
//+------------------------------------------------------------------+
#define DXB_MARKET_MODE_OFF        0
#define DXB_MARKET_MODE_CONTINUOUS 1
#define DXB_MARKET_MODE_MEDIUM     2
#define DXB_MARKET_MODE_MIXED      3
#define DXB_MARKET_MODE_DANGER     4

enum DXB_ENTRY_FILTER_ID
  {
   DXB_FILTER_DIRECTION = 0,
   DXB_FILTER_SAR_CONFIRM,
   DXB_FILTER_SAR_PRICE_SIDE,
   DXB_FILTER_REPEATED_GAP,
   DXB_FILTER_SAR_CYCLE,
   DXB_FILTER_H1_TREND,
   DXB_FILTER_LATE_SAR,
   DXB_FILTER_STRICT_SAR_SCORE,
   DXB_FILTER_DOUBTFUL_CANDLE,
   DXB_FILTER_TRADING_ALLOWED,
   DXB_FILTER_SPREAD,
   DXB_FILTER_EQUITY_LOCK,
   DXB_FILTER_NO_NEW_HOUR,
   DXB_FILTER_PROFIT_PAUSE,
   DXB_FILTER_OPPOSITE_PAUSE,
   DXB_FILTER_BIG_CANDLE,
   DXB_FILTER_SPIKE_WICK,
   DXB_FILTER_MIN_GAP,
   DXB_FILTER_MAX_OPEN_DIR,
   DXB_FILTER_TOTAL_OPEN,
   DXB_FILTER_AUTO_MARKET_MODE,
   DXB_FILTER_DYNAMIC_SAR,
   DXB_FILTER_FLAT_MODE,
   DXB_FILTER_EARLY_WEAK_EXIT,
   DXB_FILTER_EARLY_REVERSE,
   DXB_FILTER_ORDER_COOLDOWN,
   DXB_FILTER_COUNT
  };

//================ NORMAL ORDER DIAGNOSTIC / AUDIT ==================
// Live snapshot of all 26 normal-order filters.
bool     g_entryDiagEnabled[DXB_FILTER_COUNT];
bool     g_entryDiagPassed[DXB_FILTER_COUNT];
string   g_entryDiagDetail[DXB_FILTER_COUNT];

int      g_entryDiagEnabledCount   = 0;
int      g_entryDiagPassedCount    = 0;
int      g_entryDiagBlockedCount   = 0;
int      g_entryDiagDisabledCount  = 0;
int      g_entryDiagDirection      = 0;
datetime g_entryDiagTime           = 0;
string   g_entryDiagDecision       = "WAIT";
string   g_entryDiagPrimaryBlock   = "NONE";
string   g_entryDiagBlockerList    = "NONE";
string   g_entryDiagEnabledList    = "NONE";
string   g_entryDiagDisabledList   = "NONE";
string   g_entryDiagSource         = "LIVE CHECK";
bool     g_entryDiagFirstOrderProfile = false;
string   g_entryDiagProfileText      = "FULL FILTER PROFILE";

// Last real normal-order attempt.
datetime g_lastEntryAttemptTime       = 0;
int      g_lastEntryAttemptDirection  = 0;
string   g_lastEntryAttemptSource     = "NONE";
string   g_lastEntryAttemptDecision   = "NONE";
string   g_lastEntryAttemptPrimary    = "NONE";
string   g_lastEntryAttemptBlockers   = "NONE";
int      g_lastEntryAttemptEnabled    = 0;
int      g_lastEntryAttemptPassed     = 0;
int      g_lastEntryAttemptBlocked    = 0;

// Last successfully opened normal order and the exact filter snapshot.
int      g_lastAuditOpenedTicket      = -1;
datetime g_lastAuditOpenedTime        = 0;
int      g_lastAuditOpenedDirection   = 0;
double   g_lastAuditOpenedPrice       = 0.0;
double   g_lastAuditOpenedLot         = 0.0;
string   g_lastAuditOpenedSource      = "NONE";
string   g_lastAuditOpenedMode        = "NONE";
string   g_lastAuditOpenedProfile     = "NONE";
string   g_lastAuditOpenedFilters     = "NONE";
string   g_lastAuditDisabledFilters   = "NONE";
int      g_lastAuditOpenedEnabled     = 0;
int      g_lastAuditOpenedPassed      = 0;
string   g_lastAuditSendResult        = "NO ORDER ATTEMPT";

//+------------------------------------------------------------------+
string EntryFilterToken(int filterId)
  {
   if(filterId == DXB_FILTER_DIRECTION)
      return("DIRECTION");
   if(filterId == DXB_FILTER_SAR_CONFIRM)
      return("SAR_CONFIRM");
   if(filterId == DXB_FILTER_SAR_PRICE_SIDE)
      return("SAR_PRICE_SIDE");
   if(filterId == DXB_FILTER_REPEATED_GAP)
      return("REPEATED_GAP");
   if(filterId == DXB_FILTER_SAR_CYCLE)
      return("SAR_CYCLE");
   if(filterId == DXB_FILTER_H1_TREND)
      return("H1_TREND");
   if(filterId == DXB_FILTER_LATE_SAR)
      return("LATE_SAR");
   if(filterId == DXB_FILTER_STRICT_SAR_SCORE)
      return("STRICT_SAR_SCORE");
   if(filterId == DXB_FILTER_DOUBTFUL_CANDLE)
      return("DOUBTFUL_CANDLE");
   if(filterId == DXB_FILTER_TRADING_ALLOWED)
      return("TRADING_ALLOWED");
   if(filterId == DXB_FILTER_SPREAD)
      return("SPREAD");
   if(filterId == DXB_FILTER_EQUITY_LOCK)
      return("EQUITY_LOCK");
   if(filterId == DXB_FILTER_NO_NEW_HOUR)
      return("NO_NEW_HOUR");
   if(filterId == DXB_FILTER_PROFIT_PAUSE)
      return("PROFIT_PAUSE");
   if(filterId == DXB_FILTER_OPPOSITE_PAUSE)
      return("OPPOSITE_PAUSE");
   if(filterId == DXB_FILTER_BIG_CANDLE)
      return("BIG_CANDLE");
   if(filterId == DXB_FILTER_SPIKE_WICK)
      return("SPIKE_WICK");
   if(filterId == DXB_FILTER_MIN_GAP)
      return("MIN_GAP");
   if(filterId == DXB_FILTER_MAX_OPEN_DIR)
      return("MAX_OPEN_DIR");
   if(filterId == DXB_FILTER_TOTAL_OPEN)
      return("TOTAL_OPEN");
   if(filterId == DXB_FILTER_AUTO_MARKET_MODE)
      return("AUTO_MARKET_MODE");
   if(filterId == DXB_FILTER_DYNAMIC_SAR)
      return("DYNAMIC_SAR");
   if(filterId == DXB_FILTER_FLAT_MODE)
      return("FLAT_MODE");
   if(filterId == DXB_FILTER_EARLY_WEAK_EXIT)
      return("EARLY_WEAK_EXIT");
   if(filterId == DXB_FILTER_EARLY_REVERSE)
      return("EARLY_REVERSE");
   if(filterId == DXB_FILTER_ORDER_COOLDOWN)
      return("ORDER_COOLDOWN");
   return("UNKNOWN");
  }

//+------------------------------------------------------------------+
bool IsHardLockedEntryFilter(int filterId)
  {
// These safety rules can never be disabled by market-mode profiles.
// NO_NEW_HOUR is hard-locked so first SAR, normal, extra and recovery
// entry paths cannot bypass InpNoNewOrderHourList.
   return(filterId == DXB_FILTER_DIRECTION ||
          filterId == DXB_FILTER_TRADING_ALLOWED ||
          filterId == DXB_FILTER_MAX_OPEN_DIR ||
          filterId == DXB_FILTER_NO_NEW_HOUR);
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CONTINUOUS TREND FILTER CASE                                     |
//| Change only true/false values in this list.                       |
//+------------------------------------------------------------------+
bool ContinuousTrendFilterCase(int filterId)
  {
// CONTINUOUS TREND FILTERS
// This TRUE/FALSE value is the final filter switch for this mode.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);
      case DXB_FILTER_SAR_PRICE_SIDE:
         return(true);
      case DXB_FILTER_REPEATED_GAP:
         return(true);
      case DXB_FILTER_SAR_CYCLE:
         return(true);
      case DXB_FILTER_H1_TREND:
         return(false);
      case DXB_FILTER_LATE_SAR:
         return(true);
      case DXB_FILTER_STRICT_SAR_SCORE:
         return(true);
      case DXB_FILTER_DOUBTFUL_CANDLE:
         return(true);
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);
      case DXB_FILTER_SPREAD:
         return(true);
      case DXB_FILTER_EQUITY_LOCK:
         return(false);
      case DXB_FILTER_NO_NEW_HOUR:
         return(true);
      case DXB_FILTER_PROFIT_PAUSE:
         return(true);
      case DXB_FILTER_OPPOSITE_PAUSE:
         return(false);
      case DXB_FILTER_BIG_CANDLE:
         return(true);
      case DXB_FILTER_SPIKE_WICK:
         return(false);
      case DXB_FILTER_MIN_GAP:
         return(false);
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);
      case DXB_FILTER_TOTAL_OPEN:
         return(false);
      case DXB_FILTER_AUTO_MARKET_MODE:
         return(true);
      case DXB_FILTER_DYNAMIC_SAR:
         return(true);
      case DXB_FILTER_FLAT_MODE:
         return(true);
      case DXB_FILTER_EARLY_WEAK_EXIT:
         return(true);
      case DXB_FILTER_EARLY_REVERSE:
         return(false);
      case DXB_FILTER_ORDER_COOLDOWN:
         return(false);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| MEDIUM TREND FILTER CASE                                         |
//| H1_TREND and FLAT_MODE are enabled as requested.                  |
//+------------------------------------------------------------------+
bool MediumTrendFilterCase(int filterId)
  {
// MEDIUM TREND FILTERS
// This TRUE/FALSE value is the final filter switch for this mode.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);
      case DXB_FILTER_SAR_PRICE_SIDE:
         return(true);
      case DXB_FILTER_REPEATED_GAP:
         return(true);
      case DXB_FILTER_SAR_CYCLE:
         return(true);
      case DXB_FILTER_H1_TREND:
         return(true);
      case DXB_FILTER_LATE_SAR:
         return(true);
      case DXB_FILTER_STRICT_SAR_SCORE:
         return(true);
      case DXB_FILTER_DOUBTFUL_CANDLE:
         return(true);
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);
      case DXB_FILTER_SPREAD:
         return(true);
      case DXB_FILTER_EQUITY_LOCK:
         return(false);
      case DXB_FILTER_NO_NEW_HOUR:
         return(true);
      case DXB_FILTER_PROFIT_PAUSE:
         return(true);
      case DXB_FILTER_OPPOSITE_PAUSE:
         return(false);
      case DXB_FILTER_BIG_CANDLE:
         return(true);
      case DXB_FILTER_SPIKE_WICK:
         return(false);
      case DXB_FILTER_MIN_GAP:
         return(false);
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);
      case DXB_FILTER_TOTAL_OPEN:
         return(false);
      case DXB_FILTER_AUTO_MARKET_MODE:
         return(true);
      case DXB_FILTER_DYNAMIC_SAR:
         return(true);
      case DXB_FILTER_FLAT_MODE:
         return(true);
      case DXB_FILTER_EARLY_WEAK_EXIT:
         return(true);
      case DXB_FILTER_EARLY_REVERSE:
         return(false);
      case DXB_FILTER_ORDER_COOLDOWN:
         return(false);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| MIXED TREND FILTER CASE                                          |
//| Change each filter directly to true or false.                     |
//+------------------------------------------------------------------+
bool MixedTrendFilterCase(int filterId)
  {
// MIXED TREND FILTERS
// This TRUE/FALSE value is the final filter switch for this mode.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);
      case DXB_FILTER_SAR_PRICE_SIDE:
         return(true);
      case DXB_FILTER_REPEATED_GAP:
         return(true);
      case DXB_FILTER_SAR_CYCLE:
         return(true);
      case DXB_FILTER_H1_TREND:
         return(true);
      case DXB_FILTER_LATE_SAR:
         return(true);
      case DXB_FILTER_STRICT_SAR_SCORE:
         return(true);
      case DXB_FILTER_DOUBTFUL_CANDLE:
         return(true);
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);
      case DXB_FILTER_SPREAD:
         return(true);
      case DXB_FILTER_EQUITY_LOCK:
         return(false);
      case DXB_FILTER_NO_NEW_HOUR:
         return(true);
      case DXB_FILTER_PROFIT_PAUSE:
         return(true);
      case DXB_FILTER_OPPOSITE_PAUSE:
         return(true);
      case DXB_FILTER_BIG_CANDLE:
         return(true);
      case DXB_FILTER_SPIKE_WICK:
         return(true);
      case DXB_FILTER_MIN_GAP:
         return(true);
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);
      case DXB_FILTER_TOTAL_OPEN:
         return(false);
      case DXB_FILTER_AUTO_MARKET_MODE:
         return(true);
      case DXB_FILTER_DYNAMIC_SAR:
         return(true);
      case DXB_FILTER_FLAT_MODE:
         return(true);
      case DXB_FILTER_EARLY_WEAK_EXIT:
         return(true);
      case DXB_FILTER_EARLY_REVERSE:
         return(true);
      case DXB_FILTER_ORDER_COOLDOWN:
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| DANGER MODE FILTER CASE                                          |
//| AUTO_MARKET_MODE normally blocks new normal orders in danger.     |
//+------------------------------------------------------------------+
bool DangerModeFilterCase(int filterId)
  {
// DANGER MODE FILTERS
// This TRUE/FALSE value is the final filter switch for this mode.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);
      case DXB_FILTER_SAR_PRICE_SIDE:
         return(true);
      case DXB_FILTER_REPEATED_GAP:
         return(true);
      case DXB_FILTER_SAR_CYCLE:
         return(true);
      case DXB_FILTER_H1_TREND:
         return(false);
      case DXB_FILTER_LATE_SAR:
         return(true);
      case DXB_FILTER_STRICT_SAR_SCORE:
         return(true);
      case DXB_FILTER_DOUBTFUL_CANDLE:
         return(true);
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);
      case DXB_FILTER_SPREAD:
         return(true);
      case DXB_FILTER_EQUITY_LOCK:
         return(false);
      case DXB_FILTER_NO_NEW_HOUR:
         return(true);
      case DXB_FILTER_PROFIT_PAUSE:
         return(true);
      case DXB_FILTER_OPPOSITE_PAUSE:
         return(false);
      case DXB_FILTER_BIG_CANDLE:
         return(true);
      case DXB_FILTER_SPIKE_WICK:
         return(false);
      case DXB_FILTER_MIN_GAP:
         return(false);
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);
      case DXB_FILTER_TOTAL_OPEN:
         return(false);
      case DXB_FILTER_AUTO_MARKET_MODE:
         return(true);
      case DXB_FILTER_DYNAMIC_SAR:
         return(true);
      case DXB_FILTER_FLAT_MODE:
         return(true);
      case DXB_FILTER_EARLY_WEAK_EXIT:
         return(true);
      case DXB_FILTER_EARLY_REVERSE:
         return(false);
      case DXB_FILTER_ORDER_COOLDOWN:
         return(false);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Select the TRUE/FALSE case list for the current market mode.      |
//+------------------------------------------------------------------+
bool MarketModeFilterCaseValue(int mode, int filterId)
  {
   switch(mode)
     {
      case DXB_MARKET_MODE_CONTINUOUS:
         return(ContinuousTrendFilterCase(filterId));

      case DXB_MARKET_MODE_MEDIUM:
         return(MediumTrendFilterCase(filterId));

      case DXB_MARKET_MODE_MIXED:
         return(MixedTrendFilterCase(filterId));

      case DXB_MARKET_MODE_DANGER:
         return(DangerModeFilterCase(filterId));
     }

   return(GlobalFilterCase(filterId));
  }

//+------------------------------------------------------------------+
bool GlobalFilterCase(int filterId)
  {
// GLOBAL FILTERS: used when Auto Market Mode is OFF
// This TRUE/FALSE value is the final filter switch for this mode.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);
      case DXB_FILTER_SAR_PRICE_SIDE:
         return(true);
      case DXB_FILTER_REPEATED_GAP:
         return(true);
      case DXB_FILTER_SAR_CYCLE:
         return(true);
      case DXB_FILTER_H1_TREND:
         return(false);
      case DXB_FILTER_LATE_SAR:
         return(true);
      case DXB_FILTER_STRICT_SAR_SCORE:
         return(true);
      case DXB_FILTER_DOUBTFUL_CANDLE:
         return(true);
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);
      case DXB_FILTER_SPREAD:
         return(true);
      case DXB_FILTER_EQUITY_LOCK:
         return(false);
      case DXB_FILTER_NO_NEW_HOUR:
         return(true);
      case DXB_FILTER_PROFIT_PAUSE:
         return(true);
      case DXB_FILTER_OPPOSITE_PAUSE:
         return(false);
      case DXB_FILTER_BIG_CANDLE:
         return(true);
      case DXB_FILTER_SPIKE_WICK:
         return(false);
      case DXB_FILTER_MIN_GAP:
         return(false);
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);
      case DXB_FILTER_TOTAL_OPEN:
         return(false);
      case DXB_FILTER_AUTO_MARKET_MODE:
         return(true);
      case DXB_FILTER_DYNAMIC_SAR:
         return(true);
      case DXB_FILTER_FLAT_MODE:
         return(true);
      case DXB_FILTER_EARLY_WEAK_EXIT:
         return(true);
      case DXB_FILTER_EARLY_REVERSE:
         return(false);
      case DXB_FILTER_ORDER_COOLDOWN:
         return(false);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| FIRST ORDER AFTER SAR FLIP FILTER CASE                           |
//| Only one strategy condition is used: fixed InpSARConfirmPriceDiff.|
//| Direction/trading permission/per-side cap are mandatory safety.  |
//+------------------------------------------------------------------+
bool FirstSAROrderFilterCase(int filterId)
  {
// The actual first-order gate uses price difference plus mandatory
// execution safety, including the hard Dubai no-new-order hours.
// Every other strategy filter is deliberately bypassed.
   switch(filterId)
     {
      case DXB_FILTER_DIRECTION:
         return(true);
      case DXB_FILTER_SAR_CONFIRM:
         return(true);  // fixed live price difference
      case DXB_FILTER_TRADING_ALLOWED:
         return(true);  // MT4/broker safety
      case DXB_FILTER_MAX_OPEN_DIR:
         return(true);  // independent BUY/SELL cap

      case DXB_FILTER_NO_NEW_HOUR:
         return(true);  // mandatory Dubai-time lock
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool IsFirstSAROrderAfterFlip(int direction)
  {
   if(!InpFirstSAROrderPriceDiffOnly)
      return(false);

   return(direction != 0 &&
          direction == g_activeSARDirection &&
          direction == g_sarCycleDirection &&
          g_sarCycleOrdersCreated == 0);
  }

//+------------------------------------------------------------------+
bool IsNormalEntryFilterEnabledForOrder(int direction, int filterId)
  {
   if(IsFirstSAROrderAfterFlip(direction))
      return(FirstSAROrderFilterCase(filterId));

   return(IsMarketModeEntryFilterEnabled(filterId));
  }

//+------------------------------------------------------------------+
string NormalEntryProfileText(int direction)
  {
   if(IsFirstSAROrderAfterFlip(direction))
      return("FIRST ORDER: PRICE DIFF + DUBAI TIME");

   return("ORDER 2+: FULL MODE FILTERS");
  }

//+------------------------------------------------------------------+
bool IsMarketModeEntryFilterEnabled(int filterId)
  {
   if(IsHardLockedEntryFilter(filterId))
      return(true);

   if(!InpUseMarketModeFilterProfiles ||
      !InpUseAutoMarketFlowMode ||
      g_autoMarketMode == DXB_MARKET_MODE_OFF)
      return(GlobalFilterCase(filterId));

   return(MarketModeFilterCaseValue(g_autoMarketMode,
                                    filterId));
  }

//+------------------------------------------------------------------+
string EntryFilterModeStateText(int filterId)
  {
   if(IsHardLockedEntryFilter(filterId))
      return("LOCKED ON");

   if(!InpUseMarketModeFilterProfiles ||
      !InpUseAutoMarketFlowMode ||
      g_autoMarketMode == DXB_MARKET_MODE_OFF)
      return(GlobalFilterCase(filterId)
             ? "ON GLOBAL"
             : "OFF GLOBAL");

   return(IsMarketModeEntryFilterEnabled(filterId)
          ? "ON MODE"
          : "OFF MODE");
  }

//+------------------------------------------------------------------+
string ActiveFilterCaseSummary()
  {
   string summary = "";

   for(int filterId = 0; filterId < DXB_FILTER_COUNT; filterId++)
     {
      if(summary != "")
         summary += " | ";

      summary += EntryFilterToken(filterId) + "=" +
                 (IsMarketModeEntryFilterEnabled(filterId)
                  ? "ON"
                  : "OFF");
     }

   return(summary);
  }

//+------------------------------------------------------------------+
int CountEnabledMarketModeEntryFilters()
  {
   int enabled = 0;

   for(int i = 0; i < DXB_FILTER_COUNT; i++)
      if(IsMarketModeEntryFilterEnabled(i))
         enabled++;

   return(enabled);
  }

//+------------------------------------------------------------------+
bool IsNormalProfileSource(string source)
  {
   return(StringFind(source, "OpenMarketOrder") >= 0 ||
          StringFind(source, "CHECKLIST_NORMAL") >= 0 ||
          StringFind(source, "NORMAL_PROFILE") >= 0);
  }

//+------------------------------------------------------------------+
void ApplyMarketModeEntryFilterProfileState()
  {
   if(g_lastAppliedEntryFilterMode == g_autoMarketMode)
      return;

   int previousMode = g_lastAppliedEntryFilterMode;
   g_lastAppliedEntryFilterMode = g_autoMarketMode;

// Clear transient waiting states when their filter is disabled
// in the newly selected market profile.
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM))
      ResetSARFlipConfirmation();

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE))
      ResetDoubtfulCandleConfirmation("DISABLED BY MARKET MODE");

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_FLAT_MODE))
      g_flatMode = false;

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_REVERSE))
      g_sarPausedByEarly = false;

   Print("DIRECT FILTER CASE CHANGED | Previous=",
         MarketFlowModeText(previousMode),
         " | Current=", MarketFlowModeText(g_autoMarketMode),
         " | Enabled=", CountEnabledMarketModeEntryFilters(),
         "/", DXB_FILTER_COUNT,
         " | Source=",
         (!InpUseMarketModeFilterProfiles ||
          !InpUseAutoMarketFlowMode ||
          g_autoMarketMode == DXB_MARKET_MODE_OFF)
         ? "GLOBAL CASE"
         : "MARKET MODE CASE",
         " | ", ActiveFilterCaseSummary());
  }

//+------------------------------------------------------------------+
string MarketFlowModeText(int mode)
  {
   if(mode == DXB_MARKET_MODE_CONTINUOUS)
      return("CONTINUOUS TREND");
   if(mode == DXB_MARKET_MODE_MEDIUM)
      return("MEDIUM TREND");
   if(mode == DXB_MARKET_MODE_MIXED)
      return("MIXED TREND");
   if(mode == DXB_MARKET_MODE_DANGER)
      return("DANGER SPIKE");
   return("OFF");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color MarketFlowModeColor()
  {
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return(clrLime);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return(clrAqua);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
      return(clrYellow);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return(clrRed);
   return(clrSilver);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetMarketFlowDirection(int bars)
  {
   int lookback = MathMax(5, bars);
   if(Bars <= lookback + 2)
      lookback = MathMax(2, Bars - 2);

   double oldClose = iClose(Symbol(), PERIOD_M1, lookback);
   double diff = Close[0] - oldClose;
   if(diff > 0.0)
      return(1);
   if(diff < 0.0)
      return(-1);
   return(0);
  }

//+------------------------------------------------------------------+
//| Notification helper                                               |
//+------------------------------------------------------------------+
void SendEAAlert(string eventTitle, string details)
  {
// Status, pause, modification and protection events stay in the
// Experts log/terminal only. Push notifications are reserved strictly
// for actual market-order CREATED and CLOSED events.
   string msg = InpEAName + " | " + Symbol() + " | " +
                eventTitle + " | " + details;

   Print("EA EVENT | ", msg);

   if(InpSendTerminalAlerts)
      Alert(msg);
  }

//+------------------------------------------------------------------+
//| Legacy comment classifiers                                        |
//| Creation of these micro order types has been removed.             |
//| These helpers remain only to classify old open/history orders.    |
//+------------------------------------------------------------------+
bool IsSARPullbackHalfTPComment(string commentText)
  {
   return(StringFind(commentText, "PULLBACK_HALF") >= 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSARWeakReverseOrderComment(string commentText)
  {
   return(StringFind(commentText, "SAR_WEAK_REVERSE") >= 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNormalProfitOrderForMarketFlow(string commentText)
  {
   if(IsSARGuardOrderComment(commentText))
      return(false);
   if(IsRecoveryGapOrderComment(commentText))
      return(false);
   if(IsRecoveryHedgeOrderComment(commentText))
      return(false);
   if(IsSARWeakReverseOrderComment(commentText))
      return(false);
   if(IsSARPullbackHalfTPComment(commentText))
      return(false);
   if(StringFind(commentText, "RECOVERY") >= 0)
      return(false);
   return(true);
  }

#define DXB_OPPOSITE_PAUSE_HISTORY_KEEP 100

//+------------------------------------------------------------------+
//| Rebuild the latest normal-order profit streak from trade history. |
//| A loss/breakeven or a different direction breaks the streak.      |
//| Once triggered, the opposite-side pause remains for the full time |
//| even if another order later closes in loss.                        |
//+------------------------------------------------------------------+
void UpdateOppositeDirectionProfitPause(bool forceScan=false)
  {
   datetime now = TimeCurrent();

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_OPPOSITE_PAUSE))
     {
      g_oppositeProfitStreakDirection = 0;
      g_oppositeProfitStreakCount = 0;
      g_oppositePausedDirection = 0;
      g_oppositeDirectionPauseUntil = 0;
      g_oppositeDirectionPauseTriggerTime = 0;
      g_oppositeDirectionPauseTriggerTicket = 0;
      g_oppositeDirectionPauseWinner = 0;
      g_oppositeDirectionPauseStatus = "OFF";
      return;
     }

   int historyTotal = OrdersHistoryTotal();

// Avoid rescanning the complete history on every market tick.
   if(!forceScan &&
      historyTotal == g_oppositePauseLastHistoryTotal &&
      (now - g_oppositePauseLastScanTime) < 5)
     {
      if(g_oppositePausedDirection != 0 && now >= g_oppositeDirectionPauseUntil)
        {
         g_oppositePausedDirection = 0;
         g_oppositeDirectionPauseUntil = 0;
         g_oppositeDirectionPauseStatus = "FINISHED | Waiting new streak";
        }
      return;
     }

   g_oppositePauseLastHistoryTotal = historyTotal;
   g_oppositePauseLastScanTime = now;

   datetime closeTimes[DXB_OPPOSITE_PAUSE_HISTORY_KEEP];
   int      directions[DXB_OPPOSITE_PAUSE_HISTORY_KEEP];
   double   netProfits[DXB_OPPOSITE_PAUSE_HISTORY_KEEP];
   int      tickets[DXB_OPPOSITE_PAUSE_HISTORY_KEEP];

// Explicit initialization removes MetaEditor warnings and guarantees
// deterministic values before the insertion-sort history scan.
   ArrayInitialize(closeTimes, 0);
   ArrayInitialize(directions, 0);
   ArrayInitialize(netProfits, 0.0);
   ArrayInitialize(tickets, 0);

   int kept = 0;

// Keep the latest 100 eligible normal closes, sorted newest -> oldest.
   for(int i = 0; i < historyTotal; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() <= 0)
         continue;
      if(!IsNormalProfitOrderForMarketFlow(OrderComment()))
         continue;

      datetime closeTime = OrderCloseTime();
      int ticket = OrderTicket();
      int direction = (OrderType() == OP_BUY) ? 1 : -1;
      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();

      int insertPos = kept;

      if(kept < DXB_OPPOSITE_PAUSE_HISTORY_KEEP)
        {
         kept++;
        }
      else
        {
         int last = kept - 1;
         bool newerThanOldest = (closeTime > closeTimes[last] ||
                                 (closeTime == closeTimes[last] && ticket > tickets[last]));
         if(!newerThanOldest)
            continue;
         insertPos = last;
        }

      while(insertPos > 0)
        {
         int previous = insertPos - 1;
         bool shouldMove = (closeTime > closeTimes[previous] ||
                            (closeTime == closeTimes[previous] && ticket > tickets[previous]));
         if(!shouldMove)
            break;

         closeTimes[insertPos] = closeTimes[previous];
         directions[insertPos] = directions[previous];
         netProfits[insertPos] = netProfits[previous];
         tickets[insertPos] = tickets[previous];
         insertPos--;
        }

      closeTimes[insertPos] = closeTime;
      directions[insertPos] = direction;
      netProfits[insertPos] = netProfit;
      tickets[insertPos] = ticket;
     }

   int required = MathMax(1, InpOppositeDirectionProfitStreakOrders);
   int streakDirection = 0;
   int streakCount = 0;
   int latestTriggerDirection = 0;
   datetime latestTriggerTime = 0;
   int latestTriggerTicket = 0;

// Process oldest -> newest to reproduce the true consecutive sequence.
   for(int n = kept - 1; n >= 0; n--)
     {
      if(netProfits[n] > 0.0)
        {
         if(directions[n] == streakDirection)
            streakCount++;
         else
           {
            streakDirection = directions[n];
            streakCount = 1;
           }

         if(streakCount >= required)
           {
            latestTriggerDirection = streakDirection;
            latestTriggerTime = closeTimes[n];
            latestTriggerTicket = tickets[n];
           }
        }
      else
        {
         streakDirection = 0;
         streakCount = 0;
        }
     }

   g_oppositeProfitStreakDirection = streakDirection;
   g_oppositeProfitStreakCount = streakCount;

   int pauseSeconds = MathMax(1, InpOppositeDirectionPauseMinutes) * 60;
   datetime newPauseUntil = (latestTriggerTime > 0) ? latestTriggerTime + pauseSeconds : 0;

   if(latestTriggerDirection != 0 && newPauseUntil > now)
     {
      bool newTrigger = (latestTriggerTicket != g_oppositeDirectionPauseTriggerTicket ||
                         latestTriggerDirection != g_oppositeDirectionPauseWinner);

      g_oppositeDirectionPauseWinner = latestTriggerDirection;
      g_oppositePausedDirection = -latestTriggerDirection;
      g_oppositeDirectionPauseTriggerTime = latestTriggerTime;
      g_oppositeDirectionPauseTriggerTicket = latestTriggerTicket;
      g_oppositeDirectionPauseUntil = newPauseUntil;

      int remaining = (int)MathMax(0, g_oppositeDirectionPauseUntil - now);
      g_oppositeDirectionPauseStatus = "BLOCK " + DirectionText(g_oppositePausedDirection) +
                                       " | Winner " + DirectionText(g_oppositeDirectionPauseWinner) +
                                       " | " + FormatSecondsToHHMM(remaining);

      if(newTrigger)
        {
         Print("OPPOSITE DIRECTION PAUSE STARTED | Winner=", DirectionText(g_oppositeDirectionPauseWinner),
               " | ConsecutiveProfitOrders>=", required,
               " | BlockedDirection=", DirectionText(g_oppositePausedDirection),
               " | TriggerTicket=", g_oppositeDirectionPauseTriggerTicket,
               " | TriggerTime=", TimeToString(g_oppositeDirectionPauseTriggerTime, TIME_DATE|TIME_SECONDS),
               " | PauseUntil=", TimeToString(g_oppositeDirectionPauseUntil, TIME_DATE|TIME_SECONDS));
        }
     }
   else
     {
      if(g_oppositePausedDirection != 0 && now >= g_oppositeDirectionPauseUntil)
         Print("OPPOSITE DIRECTION PAUSE FINISHED | PreviousBlockedDirection=",
               DirectionText(g_oppositePausedDirection));

      g_oppositePausedDirection = 0;
      g_oppositeDirectionPauseUntil = 0;
      g_oppositeDirectionPauseWinner = 0;
      g_oppositeDirectionPauseTriggerTime = 0;
      g_oppositeDirectionPauseTriggerTicket = 0;

      if(streakDirection == 0)
         g_oppositeDirectionPauseStatus = "WAIT | Streak 0/" + IntegerToString(required);
      else
         g_oppositeDirectionPauseStatus = "WAIT | " + DirectionText(streakDirection) +
                                          " " + IntegerToString(streakCount) + "/" +
                                          IntegerToString(required);
     }
  }

//+------------------------------------------------------------------+
bool IsOppositeDirectionProfitPauseActive()
  {
   UpdateOppositeDirectionProfitPause(false);
   return(IsMarketModeEntryFilterEnabled(DXB_FILTER_OPPOSITE_PAUSE) &&
          g_oppositePausedDirection != 0 &&
          TimeCurrent() < g_oppositeDirectionPauseUntil);
  }

//+------------------------------------------------------------------+
string OppositeDirectionProfitPauseStatusText()
  {
   UpdateOppositeDirectionProfitPause(false);

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_OPPOSITE_PAUSE))
      return("OFF MODE");

   if(IsOppositeDirectionProfitPauseActive())
     {
      int remaining = (int)MathMax(0, g_oppositeDirectionPauseUntil - TimeCurrent());
      return("BLOCK " + DirectionText(g_oppositePausedDirection) +
             " | " + DirectionText(g_oppositeDirectionPauseWinner) +
             " wins | " + FormatSecondsToHHMM(remaining));
     }

   return(g_oppositeDirectionPauseStatus);
  }

//+------------------------------------------------------------------+
bool IsOrderBlockedByOppositeDirectionProfitPause(int direction, string source)
  {
   if(direction == 0 || !IsOppositeDirectionProfitPauseActive())
      return(false);

   if(direction != g_oppositePausedDirection)
      return(false);

   int remaining = (int)MathMax(0, g_oppositeDirectionPauseUntil - TimeCurrent());
   string message = "Opposite direction profit-streak pause | Winner=" +
                    DirectionText(g_oppositeDirectionPauseWinner) +
                    " | Blocked=" + DirectionText(direction) +
                    " | Remaining=" + FormatSecondsToHHMM(remaining) +
                    " | Source=" + source;

   SetLastOrderBlockDashboard(message);

   if(g_oppositePauseLastPrintedDirection != direction ||
      TimeCurrent() - g_oppositePauseLastBlockPrintTime >= 30)
     {
      Print("ORDER BLOCKED | ", message);
      g_oppositePauseLastPrintedDirection = direction;
      g_oppositePauseLastBlockPrintTime = TimeCurrent();
     }

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
   else
      if(g_autoMarketMoveRaw >= InpMediumTrendMinMoveRaw &&
         g_autoMarketMoveRaw <= InpMediumTrendMaxMoveRaw)
         g_autoMarketMode = DXB_MARKET_MODE_MEDIUM;
      else
         if(g_autoMarketMoveRaw >= InpMixedTrendMinMoveRaw &&
            g_autoMarketMoveRaw <= InpMixedTrendMaxMoveRaw)
            g_autoMarketMode = DXB_MARKET_MODE_MIXED;
         else
            g_autoMarketMode = DXB_MARKET_MODE_MIXED;

   g_autoMarketModeText = MarketFlowModeText(g_autoMarketMode);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetEffectiveBasketStopLossUSD()
  {
   if(InpUseSimpleSideBasketCloseOnly)
      return(InpBasketStopLossUSD);

   if(!InpUseAutoMarketFlowMode)
      return(InpBasketStopLossUSD);

   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return(InpContinuousTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return(InpMediumTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
      return(InpMixedTrendBasketSLUSD);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return(InpDangerModeBasketSLUSD);

   return(InpBasketStopLossUSD);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsAutoMarketTradingPaused()
  {
   if(!InpUseAutoMarketFlowMode)
      return(false);

   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER &&
      InpAutoModePauseOrdersInDanger)
      return(true);

   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED &&
      InpAutoModePauseOrdersInMixed)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AutoMarketTradingPauseText()
  {
   if(!IsAutoMarketTradingPaused())
      return("RUNNING");

   return(g_autoMarketModeText + " | NEW TRADING PAUSED");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsAutoMarketRecoveryAllowed()
  {
   if(!InpUseAutoMarketFlowMode)
      return(true);
   if(IsAutoMarketTradingPaused())
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return(InpAutoModeAllowRecoveryMedium);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
      return(InpAutoModeAllowRecoveryMixed);
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsAutoMarketSARWeakAllowed()
  {
   if(!InpUseAutoMarketFlowMode)
      return(true);
   if(IsAutoMarketTradingPaused())
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
      return(InpAutoModeAllowSARWeakMixed);
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsAutoMarketPullbackAllowed()
  {
   if(!InpUseAutoMarketFlowMode)
      return(true);
   if(IsAutoMarketTradingPaused())
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return(false);
   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
      return(InpAutoModeAllowPullbackMixed);
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsAutoMarketNewOrderAllowed(string reason)
  {
   if(!InpUseAutoMarketFlowMode)
      return(true);

// Complete pause: blocks normal SAR, continuity, pullback, recovery,
// recovery-gap, recovery-hedge, extra and SAR-weak reverse entries.
// Existing orders continue normal TP/SL/close management.
   if(IsAutoMarketTradingPaused())
      return(false);

   if(StringFind(reason, "RECOVERY") >= 0 && !IsAutoMarketRecoveryAllowed())
      return(false);
   if(StringFind(reason, "SAR_WEAK_REVERSE") >= 0 && !IsAutoMarketSARWeakAllowed())
      return(false);
   if((StringFind(reason, "PULLBACK") >= 0 || StringFind(reason, "HALF_TP") >= 0) && !IsAutoMarketPullbackAllowed())
      return(false);
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string AutoMarketModeStatusText()
  {
   if(!InpUseAutoMarketFlowMode)
      return("OFF | Auto market flow disabled");

   double last1Move = GetLastNCandlesRawMove(1);
   string action = IsAutoMarketTradingPaused()
                   ? "BLOCK ALL NEW ORDERS"
                   : "ALLOW NEW ORDERS";

   if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
      return("DANGER SPIKE | " + action +
             " | Last1 " + DoubleToString(last1Move,0) +
             "/" + DoubleToString(InpBigCandleRawDifference,0) +
             " | Last3 " + DoubleToString(g_autoMarketLast3MoveRaw,0) +
             "/" + DoubleToString(InpDangerLast3MoveRaw,0));

   if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
      return("CONTINUOUS TREND | " + action +
             " | Move " + DoubleToString(g_autoMarketMoveRaw,0) +
             "/" + DoubleToString(InpContinuousTrendMoveRaw,0) +
             " | Profit B/S " +
             IntegerToString(g_autoMarketBuyProfitCount) + "/" +
             IntegerToString(g_autoMarketSellProfitCount) +
             " | Need " + IntegerToString(InpContinuousTrendProfitOrders) +
             "/Opp<=" + IntegerToString(InpContinuousTrendOppProfitMax));

   if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
      return("MEDIUM TREND | " + action +
             " | Move " + DoubleToString(g_autoMarketMoveRaw,0) +
             " | Range " + DoubleToString(InpMediumTrendMinMoveRaw,0) +
             "-" + DoubleToString(InpMediumTrendMaxMoveRaw,0) +
             " | Last3 " + DoubleToString(g_autoMarketLast3MoveRaw,0) +
             "/" + DoubleToString(InpDangerLast3MoveRaw,0));

   if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
     {
      bool inConfiguredRange =
         (g_autoMarketMoveRaw >= InpMixedTrendMinMoveRaw &&
          g_autoMarketMoveRaw <= InpMixedTrendMaxMoveRaw);

      return("MIXED TREND | " + action +
             " | Move " + DoubleToString(g_autoMarketMoveRaw,0) +
             " | Range " + DoubleToString(InpMixedTrendMinMoveRaw,0) +
             "-" + DoubleToString(InpMixedTrendMaxMoveRaw,0) +
             " | " + (inConfiguredRange ? "RANGE MATCH" : "FALLBACK MIXED"));
     }

   return(g_autoMarketModeText + " | " + action +
          " | Move " + DoubleToString(g_autoMarketMoveRaw,0));
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
bool IsMixedModeHalfBasketTPActive()
  {
// Automatic rule: MIXED market mode always uses exact half basket TP.
   return(InpUseAutoMarketFlowMode &&
          g_autoMarketMode == DXB_MARKET_MODE_MIXED);
  }

//+------------------------------------------------------------------+
int GetCurrentSARScoreForBasketTP()
  {
   if(g_activeSARDirection == 0)
      return(99);

// Calculate the current active SAR score at the moment basket TP is checked.
// This avoids using an old score left from a previous SAR direction.
   return(GetDynamicSARStrengthScore(g_activeSARDirection));
  }

//+------------------------------------------------------------------+
bool IsLowSARScoreHalfBasketTPActive()
  {
   if(!InpUseLowSARScoreHalfBasketTP)
      return(false);

   if(g_activeSARDirection == 0)
      return(false);

   int maxScore = MathMax(0, InpSARScoreHalfBasketTPMax);
   int score = GetCurrentSARScoreForBasketTP();

   return(score <= maxScore);
  }

//+------------------------------------------------------------------+
bool IsFixedHalfBasketTPActive()
  {
   return(IsMixedModeHalfBasketTPActive() ||
          IsLowSARScoreHalfBasketTPActive());
  }

//+------------------------------------------------------------------+
double GetMixedModeBasketTPMultiplier()
  {
   if(!IsMixedModeHalfBasketTPActive())
      return(1.0);

// Fixed rule requested for MIXED mode.
   return(0.50);
  }

//+------------------------------------------------------------------+
double GetMixedModeBasketProfitTargetUSD()
  {
// Exact fixed target. Do not divide by order count or apply time decay.
   return(MathMax(0.01,
                  MathAbs(InpBasketProfitUSD) / 2.0));
  }

//+------------------------------------------------------------------+
double GetBasketProfitTargetUSD()
  {
// Exact fixed half target when either:
// 1) Auto Market Flow mode is MIXED, OR
// 2) current active SAR score <= InpSARScoreHalfBasketTPMax.
//
// This return intentionally happens before:
// - simple-mode order-count division,
// - 12:00-17:00 target override,
// - time-decay multiplier.
   if(IsFixedHalfBasketTPActive())
      return(GetMixedModeBasketProfitTargetUSD());

   if(InpUseSimpleSideBasketCloseOnly)
     {
      int simpleCount = CountOpenOrders();

      if(simpleCount <= 0)
         simpleCount = 1;

      return(MathMax(0.01,
                     InpBasketProfitUSD / simpleCount));
     }

   int hourNow = TimeHour(TimeCurrent());

   int count = CountOpenOrders();

   if(count <= 0)
      count = 1;

   double baseTarget = InpBasketProfitUSD;

   if(hourNow >= 12 && hourNow <= 17)
      baseTarget = InpBasketProfitUSD_12_17;

   double target = baseTarget / count;

   target =
      target * GetBasketProfitTimeDecayMultiplier();

   return(MathMax(0.01, target));
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

//================ CREATED/CLOSED PUSH NOTIFICATIONS ONLY ===========
// Exactly one push is sent when an EA pending order becomes a real BUY/SELL
// market order, and exactly one push is sent when that market order closes.
// OrderModify, SL updates, pending placement/deletion, pauses, startup and
// filter/status events never generate EA push notifications.
#define DXB_PUSH_TICKET_CAPACITY 2000
#define DXB_PUSH_HISTORY_SCAN    500

int  g_pushKnownMarketTickets[DXB_PUSH_TICKET_CAPACITY];
int  g_pushKnownMarketTicketCount = 0;
int  g_pushClosedTickets[DXB_PUSH_TICKET_CAPACITY];
int  g_pushClosedTicketCount = 0;
bool g_tradePushTrackerInitialized = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTicketInPushList(int ticket, int listType)
  {
   if(ticket <= 0)
      return(false);

   if(listType == 0)
     {
      for(int i = 0; i < g_pushKnownMarketTicketCount; i++)
         if(g_pushKnownMarketTickets[i] == ticket)
            return(true);
     }
   else
     {
      for(int j = 0; j < g_pushClosedTicketCount; j++)
         if(g_pushClosedTickets[j] == ticket)
            return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void AddTicketToPushList(int ticket, int listType)
  {
   if(ticket <= 0 || IsTicketInPushList(ticket, listType))
      return;

   if(listType == 0)
     {
      if(g_pushKnownMarketTicketCount < DXB_PUSH_TICKET_CAPACITY)
         g_pushKnownMarketTickets[g_pushKnownMarketTicketCount++] = ticket;
     }
   else
     {
      if(g_pushClosedTicketCount < DXB_PUSH_TICKET_CAPACITY)
         g_pushClosedTickets[g_pushClosedTicketCount++] = ticket;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PushOrderTypeText(int type)
  {
   if(type == OP_BUY)
      return("BUY");
   if(type == OP_SELL)
      return("SELL");
   return("UNKNOWN");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SendCreatedOrderPushFromSelected()
  {
   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return;

   int ticket = OrderTicket();
   if(IsTicketInPushList(ticket, 0))
      return;

   AddTicketToPushList(ticket, 0);

   string msg = InpEAName +
                " | ORDER CREATED | " + Symbol() +
                " | " + PushOrderTypeText(type) +
                " #" + IntegerToString(ticket) +
                " | Lot " + DoubleToString(OrderLots(), 2) +
                " | Open " + DoubleToString(OrderOpenPrice(), Digits) +
                " | Dubai " + TimeToString(GetDubaiTime(), TIME_DATE|TIME_SECONDS);

   Print("PUSH ORDER CREATED | ", msg);

   if(InpSendPushNotifications)
     {
      ResetLastError();
      if(!SendNotificationManul(msg))
        {
         Print("PUSH ORDER CREATED FAILED | Ticket=", ticket,
               " | Error=", GetLastError());
         ResetLastError();
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SendNotificationManul(string msg)
  {
   return true ;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NotifyCreatedOrderTicket(int ticket)
  {
   if(ticket <= 0)
      return;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return;

   if(OrderSymbol() != Symbol() ||
      OrderMagicNumber() != InpMagicNumber)
      return;

   SendCreatedOrderPushFromSelected();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void NotifyClosedOrderEvent(int ticket,
                            int type,
                            double profit,
                            double closePrice,
                            string reason)
  {
   if(ticket <= 0 ||
      (type != OP_BUY && type != OP_SELL) ||
      IsTicketInPushList(ticket, 1))
      return;

   AddTicketToPushList(ticket, 1);

   string shortReason = reason;
   if(StringLen(shortReason) > 42)
      shortReason = StringSubstr(shortReason, 0, 42);

   string msg = InpEAName +
                " | ORDER CLOSED | " + Symbol() +
                " | " + PushOrderTypeText(type) +
                " #" + IntegerToString(ticket) +
                " | P/L $" + DoubleToString(profit, 2) +
                " | Close " + DoubleToString(closePrice, Digits) +
                " | " + shortReason;

   Print("PUSH ORDER CLOSED | ", msg);

   if(InpSendPushNotifications)
     {
      ResetLastError();
      if(!SendNotificationManul(msg))
        {
         Print("PUSH ORDER CLOSED FAILED | Ticket=", ticket,
               " | Error=", GetLastError());
         ResetLastError();
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeCreatedClosedPushTracker()
  {
   g_pushKnownMarketTicketCount = 0;
   g_pushClosedTicketCount = 0;

// Existing market orders are remembered silently, preventing an EA reload
// from sending false ORDER CREATED messages.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         AddTicketToPushList(OrderTicket(), 0);
     }

// Remember recent historical tickets silently, preventing old close alerts
// after initialization. New broker-side SL closures appear at the end of
// history and are detected by ProcessCreatedClosedPushNotifications().
   int historyTotal = OrdersHistoryTotal();
   int firstHistoryIndex = MathMax(0, historyTotal - DXB_PUSH_HISTORY_SCAN);

   for(int h = historyTotal - 1; h >= firstHistoryIndex; h--)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         AddTicketToPushList(OrderTicket(), 1);
     }

   g_tradePushTrackerInitialized = true;

   Print("CREATED/CLOSED PUSH TRACKER READY | ExistingMarket=",
         g_pushKnownMarketTicketCount,
         " | SeededClosed=", g_pushClosedTicketCount,
         " | PushOnly=ORDER CREATED + ORDER CLOSED");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessCreatedClosedPushNotifications()
  {
   if(!g_tradePushTrackerInitialized)
      return;

// Detect every newly activated market order, including normal, recovery,
// recovery-gap and pending orders that have just triggered at the broker.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      SendCreatedOrderPushFromSelected();
     }

// Detect closures performed outside EA OrderClose(), especially a broker-side
// server SL. EA-initiated closures are already marked by the dashboard helper,
// so the same ticket cannot generate a duplicate close push.
   int historyTotal = OrdersHistoryTotal();
   int firstHistoryIndex = MathMax(0, historyTotal - DXB_PUSH_HISTORY_SCAN);

   for(int h = historyTotal - 1; h >= firstHistoryIndex; h--)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      int ticket = OrderTicket();
      if(IsTicketInPushList(ticket, 1))
         continue;

      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();
      string closeReason = "BROKER/HISTORY CLOSE";

      if(OrderStopLoss() > 0.0 &&
         MathAbs(OrderClosePrice() - OrderStopLoss()) <= MathMax(Point * 5, MarketInfo(Symbol(), MODE_SPREAD) * Point))
         closeReason = "SERVER STOP LOSS";

      NotifyClosedOrderEvent(ticket,
                             type,
                             netProfit,
                             OrderClosePrice(),
                             closeReason);
     }
  }

int g_onInitTickCount = 0;
int  g_tickConfirmationCount = 0;
int OnInit()
  {

   g_onInitTickCount        = GetTickCount();
   g_tickConfirmationCount = 0;

   Print("PRE-LADDER SERVER LOCK CONFIG | Arm=$",
         DoubleToString(GetDynamicBasketMinimumArmUSD(),2),
         " | EA Floor=$",
         DoubleToString(GetDynamicBasketMinimumCloseUSD(),2),
         " | Server Aim=$",
         DoubleToString(
            GetServerSideDesiredNetProfitUSD(
               GetDynamicBasketMinimumCloseUSD()),2),
         " | First Ladder=X",
         GetDynamicBasketLevelXText(1),
         " $",
         DoubleToString(GetDynamicBasketTargetUSDByLevel(1),2),
         " | Second Ladder=X",
         GetDynamicBasketLevelXText(2),
         " $",
         DoubleToString(GetDynamicBasketTargetUSDByLevel(2),2),
         " | Later Step=$",
         DoubleToString(GetDynamicBasketProfitStepUSD(),3));





   if(IsTesting())
     {
      InpProfitTargetPercent = 2000.0;
     }

   if(AccountNumber()==291085426)
     {
      InpProfitTargetPercent = 2000.0;
      InpNoNewOrderHourList="";

     }
   else
     {
      //   InpNoNewOrderHourList      = "11,12,13,14,15,16,17,18,19,20,21,22"; // Dubai-time hours

     }



   InitializeEquityDay();
   InitializeLastDepositBalanceOpTime();
   DeleteNonEarlySignalArrows();
   DeleteOldDashboardObjects();
   LoadLast5SARChangeDurations();

   InpMagicNumber=AccountNumber()+202; // override magic number with account number to prevent interference between charts/accounts. Orders are still filtered by symbol and magic in this EA.

   InitializeCreatedClosedPushTracker();

// Restore an active opposite-side pause after EA restart from account history.
   UpdateOppositeDirectionProfitPause(true);

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
   for(int i = ObjectsTotal(0,-1,-1)-1; i >= 0; i--)
     {
      string objectName = ObjectName(0,i);

      if(StringFind(objectName,"DXB_ENTRY_AUDIT_") == 0 ||
         StringFind(objectName,"DXB_RECOVERY_") == 0 ||
         StringFind(objectName,"DXB_PRO_REC_") == 0)
         ObjectDelete(0,objectName);
     }

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
   g_lastAppliedEntryFilterMode = -999;
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
   g_sarClosedProfitOrdersCount = 0;
   g_lastOrderOpenReason     = "WAIT ORDER";
   g_lastOrderBlockTime      = 0;
   g_doubtConfirmDirection      = 0;
   g_doubtConfirmReferenceTime  = 0;
   g_doubtConfirmReferenceHigh  = 0.0;
   g_doubtConfirmReferenceLow   = 0.0;
   g_doubtConfirmReferenceClose = 0.0;
   g_doubtConfirmStatus         = "READY";
   g_doubtConfirmReason         = "TRADING CYCLE RESET";
   g_lastOrderCloseMessage   = "NO CLOSE YET";
   g_lastOrderCloseTime      = 0;
   g_pendingRecoveryGapDirection = 0;
   g_pendingRecoveryGapMove      = 0.0;
   g_pendingRecoveryRequiredGap  = 0.0;
   g_pendingRecoveryGapTime      = 0;
   g_pendingRecoveryGapReason    = "NONE";
   g_sarChangesAfterLastNormalOrder = 0;
   g_sarCloseTrackedDirection       = 0;
   g_sarCloseTrackedOrderTime       = 0;
   g_sarDelayedCloseStatus          = "WAIT ORDER";
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
//| Current Dubai time (UTC+4). Dubai does not use daylight saving.  |
//| Independent of broker-server, VPS and VPN time zones.            |
//+------------------------------------------------------------------+
datetime GetDubaiTime()
  {
   return(TimeGMT() + (4 * 60 * 60));
  }

//+------------------------------------------------------------------+
bool IsDubaiNoNewOrderHourNow()
  {
   if(!InpUseNoNewOrderHours)
      return(false);

   int dubaiHour = TimeHour(GetDubaiTime());
   return(IsConfiguredNoNewOrderHour(dubaiHour));
  }

//+------------------------------------------------------------------+
// Backward-compatible name used throughout the EA. This is now a hard
// Dubai-time lock and no longer depends on the active market-mode profile.
bool IsNoNewOrderHour()
  {
   return(IsDubaiNoNewOrderHourNow());
  }

//+------------------------------------------------------------------+
string NoNewOrderHoursStatusText()
  {
   if(!InpUseNoNewOrderHours)
      return("OFF");

   datetime dubaiNow = GetDubaiTime();
   string status = IsDubaiNoNewOrderHourNow() ? "BLOCK NOW" : "ALLOW";

   return(status +
          " | DXB=" + TimeToString(dubaiNow, TIME_MINUTES) +
          " | HOURS=" + InpNoNewOrderHourList);
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
//| Pending-order entry helpers                                      |
//+------------------------------------------------------------------+
bool IsPendingOrderType(int type)
  {
   return(type == OP_BUYLIMIT ||
          type == OP_SELLLIMIT ||
          type == OP_BUYSTOP ||
          type == OP_SELLSTOP);
  }

//+------------------------------------------------------------------+
bool IsOrderTypeForDirection(int type, int direction, bool includePending)
  {
   if(direction == 1)
      return(type == OP_BUY ||
             (includePending && (type == OP_BUYSTOP || type == OP_BUYLIMIT)));

   if(direction == -1)
      return(type == OP_SELL ||
             (includePending && (type == OP_SELLSTOP || type == OP_SELLLIMIT)));

   return(false);
  }

//+------------------------------------------------------------------+
// Counts active market orders plus untriggered pending entries.
// Used only for entry caps so pending orders reserve their BUY/SELL slot.
int CountDirectionEntriesForCap(int direction)
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      if(IsOrderTypeForDirection(OrderType(), direction, true))
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
int CountAllEntriesForCap()
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL || IsPendingOrderType(type))
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
double GetEffectivePendingOrderGapRaw()
  {
   double requested = MathMax(0.0, InpPendingOrderRawGap);
   double stopRaw   = MarketInfo(Symbol(), MODE_STOPLEVEL)   * Point;
   double freezeRaw = MarketInfo(Symbol(), MODE_FREEZELEVEL) * Point;

   return(MathMax(requested, MathMax(stopRaw, freezeRaw)));
  }

//+------------------------------------------------------------------+
double BuildPendingOrderPrice(int direction, bool allowLastClosedReference)
  {
   RefreshRates();

   double gap = GetEffectivePendingOrderGapRaw();
   double referencePrice = (direction == 1) ? Ask : Bid;

   if(allowLastClosedReference &&
      InpPendingUseLastClosedOrderPrice &&
      g_lastClosedNormalOrderPrice > 0.0 &&
      g_lastClosedNormalOrderDirection == direction &&
      g_lastClosedNormalOrderTime > 0 &&
      (g_activeSARSignalChangeTime <= 0 ||
       g_lastClosedNormalOrderTime >= g_activeSARSignalChangeTime))
      referencePrice = g_lastClosedNormalOrderPrice;

   double pendingPrice = 0.0;

   if(direction == 1)
     {
      pendingPrice = referencePrice + gap;
      pendingPrice = MathMax(pendingPrice, Ask + gap);
     }
   else
      if(direction == -1)
        {
         pendingPrice = referencePrice - gap;
         pendingPrice = MathMin(pendingPrice, Bid - gap);
        }

   return(NormalizeDouble(pendingPrice, Digits));
  }

//+------------------------------------------------------------------+
bool IsPendingEntryAllowedForCurrentSAR(int direction, string source)
  {
   if(!InpUsePendingOrderEntries)
      return(true);

   if(IsDubaiNoNewOrderHourNow())
     {
      Print("PENDING ENTRY BLOCKED | DUBAI NO-NEW HOUR | DXB=",
            TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES),
            " | Hours=", InpNoNewOrderHourList,
            " | Source=", source);
      return(false);
     }

   if(direction == 0 || direction != g_activeSARDirection)
     {
      Print("PENDING ENTRY BLOCKED | Direction/SAR mismatch | Entry=",
            DirectionText(direction),
            " | ActiveSAR=", DirectionText(g_activeSARDirection),
            " | Source=", source);
      return(false);
     }

// Never place a pending order immediately after a SAR signal changes.
// Wait until the new SAR confirmation becomes ready.
   if(g_pendingSARConfirmDirection != 0)
     {
      if(g_pendingSARConfirmDirection != direction ||
         !IsSARFlipConfirmationReady())
        {
         Print("PENDING ENTRY BLOCKED | Waiting SAR confirmation | Entry=",
               DirectionText(direction),
               " | PendingSAR=", DirectionText(g_pendingSARConfirmDirection),
               " | ", SARConfirmDurationStatusText(),
               " | Source=", source);
         return(false);
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
// direction: 1=BUY pending only, -1=SELL pending only, 0=all pending.
int DeletePendingOrdersByDirection(int direction,
                                   string reason,
                                   bool anyMagic=false)
  {
   int deleted = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(!anyMagic && OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(!IsPendingOrderType(type))
         continue;

      if(direction != 0 && !IsOrderTypeForDirection(type, direction, true))
         continue;

      int ticket = OrderTicket();
      string comment = OrderComment();

      ResetLastError();
      if(!OrderDelete(ticket))
        {
         int err = GetLastError();
         Print("PENDING DELETE FAILED | Ticket=", ticket,
               " | Type=", type,
               " | Reason=", reason,
               " | Error=", err);
         ResetLastError();
         continue;
        }

      deleted++;
      Print("PENDING DELETED | Ticket=", ticket,
            " | Comment=", comment,
            " | Reason=", reason);
     }

   return(deleted);
  }

//+------------------------------------------------------------------+
//| Total open order hard cap: normal + recovery + pending entries    |
//+------------------------------------------------------------------+
bool IsTotalOpenOrderCapReached(string source)
  {
   int total = CountAllEntriesForCap();
   if(InpMaxTotalOpenOrders > 0 && total >= InpMaxTotalOpenOrders)
     {
      Print("TOTAL OPEN ORDER CAP BLOCKED | Source=", source,
            " | Total=", total, "/", InpMaxTotalOpenOrders);
      return(true);
     }
   return(false);
  }

//+------------------------------------------------------------------+
//| Independent maximum open orders per direction/type               |
//| InpMaxOrders=1 allows at most: 1 BUY and 1 SELL simultaneously.  |
//| An open SELL blocks only another SELL; it never blocks a BUY.     |
//| Counts normal and recovery orders of the same EA magic number.    |
//+------------------------------------------------------------------+
bool IsDirectionOrderCapReached(int direction, string source)
  {
   if(direction != 1 && direction != -1)
      return(true);

   int maxPerType = InpMaxOrders;
   if(maxPerType < 1)
      maxPerType = 1;

   int openForType = CountDirectionEntriesForCap(direction);

   if(openForType >= maxPerType)
     {
      string msg = "MAX OPEN " + DirectionText(direction) +
                   " ORDERS REACHED | " +
                   IntegerToString(openForType) + "/" +
                   IntegerToString(maxPerType) +
                   " | Opposite direction remains allowed" +
                   " | Source=" + source;

      SetLastOrderBlockDashboard(msg);
      Print(msg);
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
   else
      if(orderType == OP_SELL)
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
   else
      if(orderType == OP_SELL)
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

// Immediate, de-duplicated close push for every successful EA OrderClose().
   NotifyClosedOrderEvent(ticket, type, profit, closePrice, reason);
  }

//+------------------------------------------------------------------+
void CloseAllEAOrders(string reason)
  {
   RefreshRates();

// Pending entries must be deleted; OrderClose works only for market orders.
   DeletePendingOrdersByDirection(0, reason + " | ALL EA CLOSE", false);

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
//| Dynamic basket profit ladder helpers                             |
//+------------------------------------------------------------------+
double GetDynamicBasketProfitBaseUSD()
  {
   return(MathMax(0.01, MathAbs(InpBasketProfitUSD)));
  }

//+------------------------------------------------------------------+
//| Sanitized custom ladder multipliers.                              |
//+------------------------------------------------------------------+
double GetDynamicBasketFirstLevelX()
  {
   return(MathMax(0.01, MathAbs(InpDynamicBasketFirstLevelX)));
  }

double GetDynamicBasketSecondLevelX()
  {
   double firstX = GetDynamicBasketFirstLevelX();
   double secondX = MathAbs(InpDynamicBasketSecondLevelX);

   if(secondX <= firstX)
      secondX = firstX + MathMax(0.01, MathAbs(InpDynamicBasketMultiplierStep));

   return(secondX);
  }

double GetDynamicBasketMultiplierStep()
  {
   return(MathMax(0.01, MathAbs(InpDynamicBasketMultiplierStep)));
  }

//+------------------------------------------------------------------+
//| Normal USD gap used after the specially configured second level. |
//+------------------------------------------------------------------+
double GetDynamicBasketProfitStepUSD()
  {
   return(GetDynamicBasketProfitBaseUSD() *
          GetDynamicBasketMultiplierStep());
  }

//+------------------------------------------------------------------+
//| Convert internal integer level index to its visible X multiplier. |
//| Level 1=FirstX, level 2=SecondX, then add Step for every level.    |
//+------------------------------------------------------------------+
double GetDynamicBasketLevelMultiplier(int level)
  {
   if(level <= 0)
      return(0.0);

   if(level == 1)
      return(GetDynamicBasketFirstLevelX());

   double secondX = GetDynamicBasketSecondLevelX();
   if(level == 2)
      return(secondX);

   return(secondX + (level - 2) * GetDynamicBasketMultiplierStep());
  }

//+------------------------------------------------------------------+
//| Format X values cleanly: 0.50=>0.5, 1.00=>1, 1.50=>1.5.          |
//+------------------------------------------------------------------+
string DynamicBasketMultiplierText(double multiplier)
  {
   string text = DoubleToString(multiplier, 2);

   while(StringLen(text) > 0 &&
         StringSubstr(text, StringLen(text) - 1, 1) == "0")
      text = StringSubstr(text, 0, StringLen(text) - 1);

   if(StringLen(text) > 0 &&
      StringSubstr(text, StringLen(text) - 1, 1) == ".")
      text = StringSubstr(text, 0, StringLen(text) - 1);

   return(text);
  }

//+------------------------------------------------------------------+
string GetDynamicBasketLevelXText(int level)
  {
   return(DynamicBasketMultiplierText(
             GetDynamicBasketLevelMultiplier(level)));
  }

//+------------------------------------------------------------------+
double GetDynamicBasketTargetUSDByLevel(int level)
  {
   if(level <= 0)
      return(0.0);

   return(GetDynamicBasketProfitBaseUSD() *
          GetDynamicBasketLevelMultiplier(level));
  }

//+------------------------------------------------------------------+
int GetDynamicBasketMaximumLevel()
  {
   if(InpDynamicBasketProfitMaxX <= 0.0)
      return(0); // unlimited

   double maxX = MathAbs(InpDynamicBasketProfitMaxX);
   double firstX = GetDynamicBasketFirstLevelX();
   double secondX = GetDynamicBasketSecondLevelX();
   double stepX = GetDynamicBasketMultiplierStep();

   if(maxX < secondX - 0.0000001)
      return(1);

   int maxLevel = 2 + (int)MathFloor(
                         (maxX - secondX + 0.0000001) / stepX);

   if(maxLevel < 1)
      maxLevel = 1;

   // A configured max below FirstX still permits the first valid level.
   if(maxX < firstX)
      maxLevel = 1;

   return(maxLevel);
  }

//+------------------------------------------------------------------+
int GetDynamicBasketCompletedLevel(double peakProfit)
  {
   double baseUSD = GetDynamicBasketProfitBaseUSD();
   if(baseUSD <= 0.0 || peakProfit <= 0.0)
      return(0);

   double reachedX = peakProfit / baseUSD;
   double firstX = GetDynamicBasketFirstLevelX();
   double secondX = GetDynamicBasketSecondLevelX();
   double stepX = GetDynamicBasketMultiplierStep();

   if(reachedX + 0.0000001 < firstX)
      return(0);

   int level = 1;

   if(reachedX + 0.0000001 >= secondX)
      level = 2 + (int)MathFloor(
                    (reachedX - secondX + 0.0000001) / stepX);

   int maxLevel = GetDynamicBasketMaximumLevel();
   if(maxLevel > 0 && level > maxLevel)
      level = maxLevel;

   if(level < 0)
      level = 0;

   return(level);
  }

//+------------------------------------------------------------------+
double GetDynamicBasketProtectedProfitUSD(double peakProfit)
  {
   int level = GetDynamicBasketCompletedLevel(peakProfit);
   if(level <= 0)
      return(0.0);

   double protectedProfit = GetDynamicBasketTargetUSDByLevel(level);
   double buffer = MathMax(0.0, InpDynamicBasketReturnBufferUSD);

   protectedProfit -= buffer;
   return(MathMax(0.01, protectedProfit));
  }

//+------------------------------------------------------------------+
double GetDynamicBasketNextTargetUSD(double peakProfit)
  {
   int level = GetDynamicBasketCompletedLevel(peakProfit);
   int maxLevel = GetDynamicBasketMaximumLevel();

   if(maxLevel > 0 && level >= maxLevel)
      return(GetDynamicBasketTargetUSDByLevel(maxLevel));

   return(GetDynamicBasketTargetUSDByLevel(level + 1));
  }

//+------------------------------------------------------------------+
//| First small positive lock before the first X level completes.   |
//| It is clamped to that first X level as a minimum floor.          |
//+------------------------------------------------------------------+
double GetDynamicBasketMinimumCloseUSD()
  {
   double minimumClose = MathMax(0.01,
                                 MathAbs(InpDynamicBasketMinimumCloseUSD));
   double x1Target = GetDynamicBasketTargetUSDByLevel(1);

   if(x1Target > 0.0 && minimumClose > x1Target)
      minimumClose = x1Target;

   return(minimumClose);
  }

//+------------------------------------------------------------------+
//| Profit required before the small minimum close becomes armed.    |
//| The activation is never below the close floor and is clamped to  |
//| X1 because this protection is intended only for the pre-X1 zone. |
//+------------------------------------------------------------------+
double GetDynamicBasketMinimumArmUSD()
  {
   double minimumClose = GetDynamicBasketMinimumCloseUSD();
   double armProfit = MathMax(minimumClose,
                              MathAbs(InpDynamicBasketMinimumArmUSD));
   double x1Target = GetDynamicBasketTargetUSDByLevel(1);

   if(x1Target > 0.0 && armProfit > x1Target)
      armProfit = x1Target;

   return(armProfit);
  }

//+------------------------------------------------------------------+
//| Requested broker-side net lock after applying the safety buffer. |
//| Example: EA floor $0.10 + buffer $0.01 => server aims near $0.11.|
//+------------------------------------------------------------------+
double GetServerSideDesiredNetProfitUSD(double protectedProfitUSD)
  {
   if(protectedProfitUSD <= 0.0)
      return(0.0);

   return(protectedProfitUSD +
          MathMax(0.0, InpServerProfitLockBufferUSD));
  }

//+------------------------------------------------------------------+
//| Number of completed negative drawdown steps touched.             |
//| -$1.xx => level 1, -$2.xx => level 2, -$3.xx => level 3.         |
//+------------------------------------------------------------------+
int GetDynamicBasketDrawdownLevel(double worstProfit)
  {
   if(!InpUseDynamicBasketDrawdownComebackTP || worstProfit >= 0.0)
      return(0);

   double stepUSD = MathMax(0.01, MathAbs(InpDynamicBasketDrawdownStepUSD));
   double lossUSD = MathAbs(worstProfit);

   if(lossUSD + 0.0000001 < stepUSD)
      return(0);

   int level = (int)MathFloor((lossUSD + 0.0000001) / stepUSD);
   if(level < 0)
      level = 0;

   return(level);
  }

//+------------------------------------------------------------------+
double GetDynamicBasketComebackTargetUSD(double worstProfit)
  {
   int drawdownLevel = GetDynamicBasketDrawdownLevel(worstProfit);
   if(drawdownLevel <= 0)
      return(0.0);

   int divisor = drawdownLevel + 1;
   double target = GetDynamicBasketProfitBaseUSD() / divisor;
   double minimumTarget = MathMax(0.01,
                                  MathAbs(InpDynamicBasketMinComebackProfitUSD));

   return(MathMax(minimumTarget, target));
  }

//+------------------------------------------------------------------+
string DynamicBasketProfitDirectionStatusText(int direction)
  {
   string side = DirectionText(direction);
   if(CountOrdersByDirection(direction) <= 0)
      return(side + " WAIT ORDER");

   double currentProfit = GetBasketProfit(direction);
   double peakProfit = (direction == 1)
                       ? g_buyBasketPeakProfit
                       : g_sellBasketPeakProfit;
   double worstProfit = (direction == 1)
                        ? g_buyBasketWorstProfit
                        : g_sellBasketWorstProfit;

   int drawdownLevel = GetDynamicBasketDrawdownLevel(worstProfit);
   double comebackTarget = (drawdownLevel > 0)
                           ? GetDynamicBasketComebackTargetUSD(worstProfit)
                           : 0.0;
   int completedLevel = GetDynamicBasketCompletedLevel(peakProfit);
   int maxLevel = GetDynamicBasketMaximumLevel();

   double protectedProfit = 0.0;
   string lockText = "NOT ARMED";

// Arm the small positive floor only after the separate activation
// threshold is reached. Defaults: arm $0.20, then protect $0.10.
   double minimumArm = GetDynamicBasketMinimumArmUSD();
   double minimumClose = GetDynamicBasketMinimumCloseUSD();
   if(peakProfit + 0.0000001 >= minimumArm)
     {
      protectedProfit = minimumClose;
      lockText = "MIN";
     }

// A drawdown comeback target is another possible minimum trailing floor.
// Use it only when it protects more than the normal minimum close.
   if(drawdownLevel > 0 &&
      peakProfit + 0.0000001 >= comebackTarget &&
      comebackTarget > protectedProfit)
     {
      protectedProfit = comebackTarget;
      lockText = "TP/" + IntegerToString(drawdownLevel + 1);
     }

// The highest completed X level always replaces a lower comeback floor.
   if(completedLevel > 0)
     {
      double ladderProtected = GetDynamicBasketProtectedProfitUSD(peakProfit);
      if(ladderProtected >= protectedProfit)
        {
         protectedProfit = ladderProtected;
         lockText = "X" + GetDynamicBasketLevelXText(completedLevel);
        }
     }

   if(protectedProfit <= 0.0)
     {
      return(side + " P/L $" + DoubleToString(currentProfit, 2) +
             " | PEAK $" + DoubleToString(peakProfit, 2) +
             " | PRE ARM $" +
             DoubleToString(GetDynamicBasketMinimumArmUSD(), 2) +
             " => EA $" +
             DoubleToString(GetDynamicBasketMinimumCloseUSD(), 2) +
             " / SERVER ~$" +
             DoubleToString(
                GetServerSideDesiredNetProfitUSD(
                   GetDynamicBasketMinimumCloseUSD()), 2) +
             " | NEXT X" +
             GetDynamicBasketLevelXText(1) + " $" +
             DoubleToString(GetDynamicBasketTargetUSDByLevel(1), 2));
     }

   string nextText;
   if(maxLevel > 0 && completedLevel >= maxLevel)
      nextText = "MAX X" + GetDynamicBasketLevelXText(maxLevel);
   else
     {
      int nextLevel = completedLevel + 1;
      if(nextLevel < 1)
         nextLevel = 1;

      nextText = "NEXT X" + GetDynamicBasketLevelXText(nextLevel) + " $" +
                 DoubleToString(GetDynamicBasketTargetUSDByLevel(nextLevel), 2);
     }

   string worstText = "";
   if(drawdownLevel > 0)
      worstText = " | WORST $" + DoubleToString(worstProfit, 2);

   return(side + " P/L $" + DoubleToString(currentProfit, 2) +
          " | PEAK $" + DoubleToString(peakProfit, 2) +
          worstText +
          " | LOCK " + lockText + " $" +
          DoubleToString(protectedProfit, 2) +
          " | " + nextText);
  }

//+------------------------------------------------------------------+
//| Reset runtime broker-lock state for one side or both sides.       |
//+------------------------------------------------------------------+
void ResetServerSideProfitLockState(int direction)
  {
   if(direction == 0 || direction == 1)
     {
      g_lastBuyServerLockAttemptTime = 0;
      g_buyServerProtectedProfit     = 0.0;
      g_buyServerStopPrice           = 0.0;
      g_buyServerEstimatedNetProfit  = 0.0;
      g_buyServerLockOK               = false;
      g_buyServerLockStatus           = "WAIT ORDER";
     }

   if(direction == 0 || direction == -1)
     {
      g_lastSellServerLockAttemptTime = 0;
      g_sellServerProtectedProfit     = 0.0;
      g_sellServerStopPrice           = 0.0;
      g_sellServerEstimatedNetProfit  = 0.0;
      g_sellServerLockOK               = false;
      g_sellServerLockStatus           = "WAIT ORDER";
     }
  }

//+------------------------------------------------------------------+
//| Build a linear side-basket money model.                           |
//| BUY  net P/L = (exit - weighted open) * coefficient + costs.      |
//| SELL net P/L = (weighted open - exit) * coefficient + costs.      |
//+------------------------------------------------------------------+
bool GetSideServerLockPriceModel(int orderType,
                                 double &totalCoefficient,
                                 double &weightedOpenPrice,
                                 double &fixedCosts,
                                 int &orderCount)
  {
   totalCoefficient = 0.0;
   weightedOpenPrice = 0.0;
   fixedCosts = 0.0;
   orderCount = 0;

   if(orderType != OP_BUY && orderType != OP_SELL)
      return(false);

   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   if(tickSize <= 0.0)
      tickSize = Point;

   if(tickSize <= 0.0 || tickValue <= 0.0)
      return(false);

   double weightedOpenTotal = 0.0;
   double valuePerPriceUnitPerLot = tickValue / tickSize;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != orderType)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      double coefficient =
         valuePerPriceUnitPerLot * OrderLots();

      if(coefficient <= 0.0)
         continue;

      totalCoefficient += coefficient;
      weightedOpenTotal += OrderOpenPrice() * coefficient;
      fixedCosts += OrderSwap() + OrderCommission();
      orderCount++;
     }

   if(orderCount <= 0 || totalCoefficient <= 0.0)
      return(false);

   weightedOpenPrice =
      weightedOpenTotal / totalCoefficient;

   return(true);
  }

//+------------------------------------------------------------------+
double EstimateSideNetProfitAtPrice(int orderType,
                                    double exitPrice)
  {
   double totalCoefficient = 0.0;
   double weightedOpenPrice = 0.0;
   double fixedCosts = 0.0;
   int orderCount = 0;

   if(!GetSideServerLockPriceModel(orderType,
                                   totalCoefficient,
                                   weightedOpenPrice,
                                   fixedCosts,
                                   orderCount))
      return(0.0);

   double grossProfit = 0.0;

   if(orderType == OP_BUY)
      grossProfit =
         (exitPrice - weightedOpenPrice) *
         totalCoefficient;
   else
      grossProfit =
         (weightedOpenPrice - exitPrice) *
         totalCoefficient;

   return(grossProfit + fixedCosts);
  }

//+------------------------------------------------------------------+
//| Convert protected basket USD into one legal common server SL.     |
//| A legal broker price is accepted only when it still estimates at  |
//| least the requested protected profit. Otherwise the EA waits and  |
//| retries after price moves farther beyond the protected level.     |
//+------------------------------------------------------------------+
bool CalculateSideServerLockPrice(int orderType,
                                  double protectedProfitUSD,
                                  double &stopPrice,
                                  double &estimatedNetProfit,
                                  string &waitReason)
  {
   stopPrice = 0.0;
   estimatedNetProfit = 0.0;
   waitReason = "NONE";

   if(orderType != OP_BUY && orderType != OP_SELL)
     {
      waitReason = "invalid side";
      return(false);
     }

   if(protectedProfitUSD <= 0.0)
     {
      waitReason = "no protected profit";
      return(false);
     }

   double totalCoefficient = 0.0;
   double weightedOpenPrice = 0.0;
   double fixedCosts = 0.0;
   int orderCount = 0;

   if(!GetSideServerLockPriceModel(orderType,
                                   totalCoefficient,
                                   weightedOpenPrice,
                                   fixedCosts,
                                   orderCount))
     {
      waitReason = "tick-value model unavailable";
      return(false);
     }

   double desiredNetProfit =
      GetServerSideDesiredNetProfitUSD(protectedProfitUSD);

// Commission/swap are normally negative, so gross price profit must
// replace those costs in addition to the requested net-profit lock.
   double requiredGrossProfit =
      desiredNetProfit - fixedCosts;

   double desiredStopPrice = 0.0;

   if(orderType == OP_BUY)
      desiredStopPrice =
         weightedOpenPrice +
         requiredGrossProfit / totalCoefficient;
   else
      desiredStopPrice =
         weightedOpenPrice -
         requiredGrossProfit / totalCoefficient;

   RefreshRates();

   double stopLevelPoints =
      MarketInfo(Symbol(), MODE_STOPLEVEL);
   double freezeLevelPoints =
      MarketInfo(Symbol(), MODE_FREEZELEVEL);

   double minimumDistance =
      (MathMax(stopLevelPoints, freezeLevelPoints) + 1.0) *
      Point;

   double legalStopPrice = desiredStopPrice;

   if(orderType == OP_BUY)
     {
      double highestLegalBuySL = Bid - minimumDistance;

      // Lower BUY SL protects less, but may be required by broker distance.
      legalStopPrice =
         MathMin(desiredStopPrice,
                 highestLegalBuySL);

      legalStopPrice =
         NormalizeDouble(legalStopPrice, Digits);

      if(legalStopPrice <= 0.0 ||
         legalStopPrice >= Bid - Point * 0.5)
        {
         waitReason = "BUY SL inside stop/freeze level";
         return(false);
        }
     }
   else
     {
      double lowestLegalSellSL = Ask + minimumDistance;

      // Higher SELL SL protects less, but may be required by broker distance.
      legalStopPrice =
         MathMax(desiredStopPrice,
                 lowestLegalSellSL);

      legalStopPrice =
         NormalizeDouble(legalStopPrice, Digits);

      if(legalStopPrice <= Ask + Point * 0.5)
        {
         waitReason = "SELL SL inside stop/freeze level";
         return(false);
        }
     }

   estimatedNetProfit =
      EstimateSideNetProfitAtPrice(orderType,
                                   legalStopPrice);

   if(estimatedNetProfit + 0.0000001 <
      protectedProfitUSD)
     {
      waitReason =
         "price not far enough beyond protected level";

      return(false);
     }

   stopPrice = legalStopPrice;
   return(true);
  }

//+------------------------------------------------------------------+
bool IsOrderStopAtLeastAsProtective(int orderType,
                                    double existingStop,
                                    double requiredStop)
  {
   if(existingStop <= 0.0)
      return(false);

   if(orderType == OP_BUY)
      return(existingStop >=
             requiredStop - Point * 0.5);

   if(orderType == OP_SELL)
      return(existingStop <=
             requiredStop + Point * 0.5);

   return(false);
  }

//+------------------------------------------------------------------+
//| Apply one common server SL to every regular/recovery order side.  |
//| Existing stops never move backward. The EA basket close remains   |
//| active as a connected-terminal fallback while server SL protects  |
//| the completed minimum/X level if terminal/VPS disconnects.        |
//+------------------------------------------------------------------+
bool ApplyServerSideProfitLock(int orderType,
                               double protectedProfitUSD,
                               bool forceAttempt)
  {
   if(!InpUseServerSideProfitLock)
      return(false);

   if(protectedProfitUSD <= 0.0)
      return(false);

   datetime now = TimeCurrent();
   datetime lastAttempt =
      (orderType == OP_BUY) ?
      g_lastBuyServerLockAttemptTime :
      g_lastSellServerLockAttemptTime;

   int retrySeconds =
      (int)MathMax(1, InpServerProfitLockRetrySeconds);

   if(!forceAttempt &&
      lastAttempt > 0 &&
      now - lastAttempt < retrySeconds)
     {
      return((orderType == OP_BUY)
             ? g_buyServerLockOK
             : g_sellServerLockOK);
     }

   if(orderType == OP_BUY)
      g_lastBuyServerLockAttemptTime = now;
   else
      g_lastSellServerLockAttemptTime = now;

   double stopPrice = 0.0;
   double estimatedNetProfit = 0.0;
   string waitReason = "NONE";

   if(!CalculateSideServerLockPrice(orderType,
                                    protectedProfitUSD,
                                    stopPrice,
                                    estimatedNetProfit,
                                    waitReason))
     {
      if(orderType == OP_BUY)
        {
         g_buyServerLockOK = false;
         g_buyServerLockStatus =
            "WAIT | $" +
            DoubleToString(protectedProfitUSD, 2) +
            " | " + waitReason;
        }
      else
        {
         g_sellServerLockOK = false;
         g_sellServerLockStatus =
            "WAIT | $" +
            DoubleToString(protectedProfitUSD, 2) +
            " | " + waitReason;
        }

      return(false);
     }

   int expectedOrders = 0;
   int modifyFailures = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != orderType)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      expectedOrders++;

      double existingStop = OrderStopLoss();

      if(IsOrderStopAtLeastAsProtective(orderType,
                                        existingStop,
                                        stopPrice))
         continue;

      bool improvesStop =
         (existingStop <= 0.0) ||
         (orderType == OP_BUY &&
          stopPrice > existingStop + Point * 0.5) ||
         (orderType == OP_SELL &&
          stopPrice < existingStop - Point * 0.5);

      if(!improvesStop)
         continue;

      int ticket = OrderTicket();

      ResetLastError();

      bool modified =
         OrderModify(ticket,
                     OrderOpenPrice(),
                     stopPrice,
                     OrderTakeProfit(),
                     0,
                     clrNONE);

      if(!modified)
        {
         int err = GetLastError();

         // Error 1 = unchanged values; final verification decides success.
         if(err != 1)
           {
            modifyFailures++;

            Print("SERVER PROFIT SL MODIFY FAILED | Ticket=", ticket,
                  " | Side=",
                  (orderType == OP_BUY ? "BUY" : "SELL"),
                  " | RequestedSL=", DoubleToString(stopPrice, Digits),
                  " | Protected=$",
                  DoubleToString(protectedProfitUSD, 2),
                  " | Error=", err);
           }
        }
     }

   int protectedOrders = 0;

   for(int v = OrdersTotal() - 1; v >= 0; v--)
     {
      if(!OrderSelect(v, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != orderType)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      if(IsOrderStopAtLeastAsProtective(orderType,
                                        OrderStopLoss(),
                                        stopPrice))
         protectedOrders++;
     }

   bool allProtected =
      (expectedOrders > 0 &&
       protectedOrders == expectedOrders);

   string side = (orderType == OP_BUY) ? "BUY" : "SELL";

   if(orderType == OP_BUY)
     {
      g_buyServerLockOK = allProtected;

      if(allProtected)
        {
         g_buyServerProtectedProfit =
            MathMax(g_buyServerProtectedProfit,
                    protectedProfitUSD);
         g_buyServerStopPrice = stopPrice;
         g_buyServerEstimatedNetProfit = estimatedNetProfit;
         g_buyServerLockStatus =
            "OK | FLOOR $" +
            DoubleToString(g_buyServerProtectedProfit, 2) +
            " | EST $" +
            DoubleToString(g_buyServerEstimatedNetProfit, 2) +
            " | SL " +
            DoubleToString(g_buyServerStopPrice, Digits);
        }
      else
        {
         g_buyServerLockStatus =
            "WAIT | verify " +
            IntegerToString(protectedOrders) + "/" +
            IntegerToString(expectedOrders);
        }
     }
   else
     {
      g_sellServerLockOK = allProtected;

      if(allProtected)
        {
         g_sellServerProtectedProfit =
            MathMax(g_sellServerProtectedProfit,
                    protectedProfitUSD);
         g_sellServerStopPrice = stopPrice;
         g_sellServerEstimatedNetProfit = estimatedNetProfit;
         g_sellServerLockStatus =
            "OK | FLOOR $" +
            DoubleToString(g_sellServerProtectedProfit, 2) +
            " | EST $" +
            DoubleToString(g_sellServerEstimatedNetProfit, 2) +
            " | SL " +
            DoubleToString(g_sellServerStopPrice, Digits);
        }
      else
        {
         g_sellServerLockStatus =
            "WAIT | verify " +
            IntegerToString(protectedOrders) + "/" +
            IntegerToString(expectedOrders);
        }
     }

   if(!allProtected)
      return(false);

   double previousServerLock =
      (orderType == OP_BUY)
      ? g_buyServerProtectedProfit
      : g_sellServerProtectedProfit;

// The runtime protected value has already been advanced above. Print only
// when this call represents a new completed ladder protection level.
   if(forceAttempt ||
      protectedProfitUSD + 0.0000001 >= previousServerLock)
     {
      Print("SERVER PROFIT LOCK ACTIVE | Side=", side,
            " | Floor=$",
            DoubleToString(protectedProfitUSD, 2),
            " | BufferedAim=$",
            DoubleToString(
               GetServerSideDesiredNetProfitUSD(protectedProfitUSD), 2),
            " | SL=", DoubleToString(stopPrice, Digits),
            " | EstimatedNet=$",
            DoubleToString(estimatedNetProfit, 2),
            " | Orders=", expectedOrders,
            " | ModifyFailures=", modifyFailures);
     }

   return(true);
  }

//+------------------------------------------------------------------+
string ServerSideProfitLockStatusText(int direction)
  {
   if(!InpUseServerSideProfitLock)
      return("OFF");

   int orderType = (direction == 1) ? OP_BUY : OP_SELL;

   if(CountOrdersByDirection(direction) <= 0)
      return("WAIT ORDER");

   if(direction == 1)
      return(g_buyServerLockStatus);

   return(g_sellServerLockStatus);
  }

//+------------------------------------------------------------------+
bool ProcessDynamicBasketProfitByDirection(int direction,
      string &status)
  {
   if(!InpUseDynamicBasketProfitBooking || direction == 0)
      return(false);

   if(CountOrdersByDirection(direction) <= 0)
      return(false);

   double currentProfit = GetBasketProfit(direction);
   double peakProfit = (direction == 1)
                       ? g_buyBasketPeakProfit
                       : g_sellBasketPeakProfit;
   double worstProfit = (direction == 1)
                        ? g_buyBasketWorstProfit
                        : g_sellBasketWorstProfit;

   int drawdownLevel = GetDynamicBasketDrawdownLevel(worstProfit);
   double comebackTarget = (drawdownLevel > 0)
                           ? GetDynamicBasketComebackTargetUSD(worstProfit)
                           : 0.0;
   int completedLevel = GetDynamicBasketCompletedLevel(peakProfit);

   double protectedProfit = 0.0;
   string protectedName = "NONE";

// Arm the pre-ladder minimum close before X1.0 is completed.
// Defaults: peak reaches $0.20 => EA floor $0.05 and the broker-side
// SL aims near $0.06. At X1.0=$0.50, X1.5=$0.75, X1.75=$0.875...
// the same server SL keeps advancing without resetting the ladder.
   double minimumArm = GetDynamicBasketMinimumArmUSD();
   double minimumClose = GetDynamicBasketMinimumCloseUSD();
   if(peakProfit + 0.0000001 >= minimumArm)
     {
      protectedProfit = minimumClose;
      protectedName = "MIN";
     }

// Drawdown comeback remains a trailing floor, never an immediate TP.
// It replaces the normal minimum only when it is the higher protection.
   if(drawdownLevel > 0 &&
      peakProfit + 0.0000001 >= comebackTarget &&
      comebackTarget > protectedProfit)
     {
      protectedProfit = comebackTarget;
      protectedName = "TP/" + IntegerToString(drawdownLevel + 1);
     }

   if(completedLevel > 0)
     {
      double ladderProtected = GetDynamicBasketProtectedProfitUSD(peakProfit);
      if(ladderProtected >= protectedProfit)
        {
         protectedProfit = ladderProtected;
         protectedName = "X" + GetDynamicBasketLevelXText(completedLevel);
        }
     }

// No minimum floor, comeback floor or X level has been armed yet.
   if(protectedProfit <= 0.0)
     {
      g_dynamicBasketProfitStatus =
         DynamicBasketProfitDirectionStatusText(direction);
      status = g_dynamicBasketProfitStatus;
      return(false);
     }

// Install or advance the real broker-side SL. This is a fallback
// protection only; the connected EA continues its normal dynamic close.
   int serverOrderType = (direction == 1) ? OP_BUY : OP_SELL;
   double previousServerProtected =
      (direction == 1)
      ? g_buyServerProtectedProfit
      : g_sellServerProtectedProfit;

   bool serverLockRaised =
      (protectedProfit >
       previousServerProtected + 0.0000001);

   ApplyServerSideProfitLock(serverOrderType,
                             protectedProfit,
                             serverLockRaised);

// Never close while profit is making or matching its highest peak.
// Close only after a genuine pullback to the best protected level.
   bool isComingBack = (currentProfit + 0.0000001 < peakProfit);

   if(isComingBack &&
      currentProfit > 0.0 &&
      currentProfit <= protectedProfit)
     {
      string side = DirectionText(direction);
      string closeReason =
         "DYNAMIC MAX-PROFIT TRAIL | " + side +
         " | Peak $" + DoubleToString(peakProfit, 2) +
         " | Protected " + protectedName +
         " $" + DoubleToString(protectedProfit, 2) +
         " | Current $" + DoubleToString(currentProfit, 2);

      if(drawdownLevel > 0)
         closeReason += " | Worst $" + DoubleToString(worstProfit, 2);

      CloseOrdersByDirection(direction, closeReason);
      ResetDelayedSARCloseAfterBasketClose(direction,
                                           side + " dynamic max-profit reset");
      ResetBasketProfitPeaksAfterClose(direction);
      // Rebuild the combined peak from any opposite-side basket still open.
      g_allBasketPeakProfit = MathMax(0.0, GetAllOpenEAOrdersProfit());

      g_dynamicBasketProfitStatus = side +
                                    " CLOSED " + protectedName +
                                    " | $" + DoubleToString(currentProfit, 2);

      Print("DYNAMIC MAX-PROFIT TRAIL CLOSED | Direction=", side,
            " | Peak=$", DoubleToString(peakProfit, 2),
            " | ProtectedName=", protectedName,
            " | Protected=$", DoubleToString(protectedProfit, 2),
            " | Current=$", DoubleToString(currentProfit, 2),
            " | Worst=$", DoubleToString(worstProfit, 2));

      status = g_dynamicBasketProfitStatus;
      return(true);
     }

   g_dynamicBasketProfitStatus =
      DynamicBasketProfitDirectionStatusText(direction);
   status = g_dynamicBasketProfitStatus;
   return(false);
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
      g_allBasketPeakProfit   = 0.0;
      g_buyBasketPeakProfit   = 0.0;
      g_sellBasketPeakProfit  = 0.0;
      g_buyBasketWorstProfit  = 0.0;
      g_sellBasketWorstProfit = 0.0;
      ResetServerSideProfitLockState(0);
      return;
     }

   if(direction == 1)
     {
      g_buyBasketPeakProfit  = 0.0;
      g_buyBasketWorstProfit = 0.0;
      ResetServerSideProfitLockState(1);
     }

   if(direction == -1)
     {
      g_sellBasketPeakProfit  = 0.0;
      g_sellBasketWorstProfit = 0.0;
      ResetServerSideProfitLockState(-1);
     }
  }

//+------------------------------------------------------------------+
bool ProcessFirstPriorityBasketProfitClose(string &status)
  {
   if(InpUseSimpleSideBasketCloseOnly &&
      !InpUseDynamicBasketProfitBooking)
     {
      status = "SIMPLE SIDE BASKET ONLY";
      return(false);
     }

   double target = GetBasketProfitTargetUSD();
   double buyTarget = GetBasketProfitTargetForDirection(1);
   double sellTarget = GetBasketProfitTargetForDirection(-1);

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

      if(buyProfit < g_buyBasketWorstProfit)
         g_buyBasketWorstProfit = buyProfit;
     }
   else
     {
      g_buyBasketPeakProfit = 0.0;
      g_buyBasketWorstProfit = 0.0;
      ResetServerSideProfitLockState(1);
     }

   if(sellCount > 0)
     {
      if(sellProfit > g_sellBasketPeakProfit)
         g_sellBasketPeakProfit = sellProfit;

      if(sellProfit < g_sellBasketWorstProfit)
         g_sellBasketWorstProfit = sellProfit;
     }
   else
     {
      g_sellBasketPeakProfit = 0.0;
      g_sellBasketWorstProfit = 0.0;
      ResetServerSideProfitLockState(-1);
     }

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

// DYNAMIC SIDE PROFIT LADDER:
// BUY and SELL use separate peak/lock memory. The opposite side never reduces
// the protected profit of the profitable side. Fixed all-basket and fixed
// side-basket TP checks below are bypassed while this mode is enabled.
   if(InpUseDynamicBasketProfitBooking)
     {
      string dynamicStatus = "DYNAMIC BASKET RUNNING";

      if(ProcessDynamicBasketProfitByDirection(1, dynamicStatus))
        {
         status = dynamicStatus;
         return(true);
        }

      if(ProcessDynamicBasketProfitByDirection(-1, dynamicStatus))
        {
         status = dynamicStatus;
         return(true);
        }

      status = dynamicStatus;
      return(false);
     }

// PRIORITY 1A:
// Fixed target: close all BUY+SELL when combined floating profit reaches target.
   if(allProfit >= target)
     {
      string allTPReason =
         GetReducedBasketTPReasonText(g_activeSARDirection);

      CloseAllEAOrders(
         "FIRST PRIORITY " + allTPReason +
         " | ALL BUY+SELL profit $" +
         DoubleToString(allProfit, 2));

      ResetDelayedSARCloseAfterBasketClose(0,
                                           "All basket TP reset");
      ResetBasketProfitPeaksAfterClose(0);

      Print(IsFixedHalfBasketTPActive()
            ? "FIRST PRIORITY FIXED HALF TP HIT | Orders="
            : "FIRST PRIORITY ALL BASKET PROFIT HIT | Orders=",
            totalOrders,
            " | BuyCount=", buyCount,
            " | SellCount=", sellCount,
            " | Rule=", allTPReason,
            " | SARScore=", GetCurrentSARScoreForBasketTP(),
            " | Profit=$", DoubleToString(allProfit, 2),
            " | Target=$", DoubleToString(target, 2));

      status = allTPReason +
               " | ALL TP $" +
               DoubleToString(allProfit, 2);
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

   if(buyCount > 0 && buyProfit >= buyTarget)
     {
      string buyTPRule = GetReducedBasketTPReasonText(1);
      CloseOrdersByDirection(1,
                             "FIRST PRIORITY BUY | " + buyTPRule +
                             " | Profit $" + DoubleToString(buyProfit, 2));
      ResetDelayedSARCloseAfterBasketClose(1, "BUY basket TP reset");
      ResetBasketProfitPeaksAfterClose(1);

      Print("FIRST PRIORITY BUY BASKET PROFIT HIT | BuyCount=", buyCount,
            " | Rule=", buyTPRule,
            " | AgeMin=", GetBasketOpenAgeMinutes(1),
            " | Profit=$", DoubleToString(buyProfit, 2),
            " | Target=$", DoubleToString(buyTarget, 2));

      closedAnySide = true;
      closedText = "BUY " + buyTPRule + " $" +
                   DoubleToString(buyProfit, 2);
     }

   if(sellCount > 0 && sellProfit >= sellTarget)
     {
      string sellTPRule = GetReducedBasketTPReasonText(-1);
      CloseOrdersByDirection(-1,
                             "FIRST PRIORITY SELL | " + sellTPRule +
                             " | Profit $" + DoubleToString(sellProfit, 2));
      ResetDelayedSARCloseAfterBasketClose(-1, "SELL basket TP reset");
      ResetBasketProfitPeaksAfterClose(-1);

      Print("FIRST PRIORITY SELL BASKET PROFIT HIT | SellCount=", sellCount,
            " | Rule=", sellTPRule,
            " | AgeMin=", GetBasketOpenAgeMinutes(-1),
            " | Profit=$", DoubleToString(sellProfit, 2),
            " | Target=$", DoubleToString(sellTarget, 2));

      if(closedText != "")
         closedText += " | ";
      closedText += "SELL " + sellTPRule + " $" +
                    DoubleToString(sellProfit, 2);
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
                                  buyTarget,
                                  buyTarget / 2.0,
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
                                  sellTarget,
                                  sellTarget / 2.0,
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetBigCandlePauseState()
  {
   g_bigCandlePause = false;
   g_bigCandlePauseUntil = 0;
   g_bigCandlePauseSARDirection = 0;
   g_bigCandlePauseCandleDirection = 0;
   g_bigCandleBlockBuyUntil = 0;
   g_bigCandleBlockSellUntil = 0;
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
//| Direction of the combined last three CLOSED candles.              |
//+------------------------------------------------------------------+
int GetLast3CandlesMoveDirection()
  {
   if(Bars < 5)
      return(0);

   double startPrice = Open[3];
   double endPrice   = Close[1];

   if(endPrice > startPrice)
      return(1);

   if(endPrice < startPrice)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Register a directional big-candle pause.                          |
//| Bullish big candle blocks SELL only. Bearish blocks BUY only.     |
//+------------------------------------------------------------------+
void RegisterBigCandleDirectionalPause(int candleDirection,
                                       double move,
                                       datetime eventTime,
                                       bool forming,
                                       int pauseMinutes,
                                       string reason)
  {
   pauseMinutes = MathMax(1, pauseMinutes);
   datetime newUntil = TimeCurrent() + pauseMinutes * 60;

   g_bigCandlePause = true;

   if(newUntil > g_bigCandlePauseUntil)
      g_bigCandlePauseUntil = newUntil;

   g_lastBigCandleMove = move;
   g_bigCandlePauseCandleDirection = candleDirection;

   if(forming)
      g_lastBigCandleFormationBarTime = eventTime;
   else
      g_lastBigCandlePauseBarTime = eventTime;

   if(!InpBigCandleBlockOppositeDirectionOnly)
     {
      if(newUntil > g_bigCandleBlockBuyUntil)
         g_bigCandleBlockBuyUntil = newUntil;

      if(newUntil > g_bigCandleBlockSellUntil)
         g_bigCandleBlockSellUntil = newUntil;
     }
   else
     {
      // Bullish candle supports BUY, therefore only SELL is blocked.
      if(candleDirection == 1 &&
         newUntil > g_bigCandleBlockSellUntil)
         g_bigCandleBlockSellUntil = newUntil;

      // Bearish candle supports SELL, therefore only BUY is blocked.
      if(candleDirection == -1 &&
         newUntil > g_bigCandleBlockBuyUntil)
         g_bigCandleBlockBuyUntil = newUntil;
     }

   Print("BIG CANDLE DIRECTION REGISTERED | Candle=",
         DirectionText(candleDirection),
         " | Move=", DoubleToString(move,Digits),
         " | Rule=",
         InpBigCandleBlockOppositeDirectionOnly
         ? "OPPOSITE ONLY"
         : "ALL DIRECTIONS",
         " | Reason=", reason,
         " | Until=",
         TimeToString(newUntil,TIME_DATE|TIME_SECONDS));
  }

//+------------------------------------------------------------------+
//| Return true only when the candidate is opposite to a big candle.  |
//+------------------------------------------------------------------+
bool IsBigCandleOrderBlockedForDirection(int orderDirection,
      string &reason)
  {
   reason = "CLEAR";

   if(!IsBigCandlePauseActive())
      return(false);

   if(!InpBigCandleBlockOppositeDirectionOnly)
     {
      reason = "ALL DIRECTIONS BLOCKED | " +
               BigCandlePauseStatusText();
      return(true);
     }

   if(orderDirection == 1)
     {
      if(TimeCurrent() < g_bigCandleBlockBuyUntil)
        {
         reason = "OPPOSITE BIG CANDLE BLOCK | Candidate=BUY" +
                  " | BigCandle=SELL" +
                  " | " + BigCandlePauseStatusText();
         return(true);
        }

      reason = "SAME-DIRECTION/NO OPPOSITE BLOCK | Candidate=BUY" +
               " | " + BigCandlePauseStatusText();
      return(false);
     }

   if(orderDirection == -1)
     {
      if(TimeCurrent() < g_bigCandleBlockSellUntil)
        {
         reason = "OPPOSITE BIG CANDLE BLOCK | Candidate=SELL" +
                  " | BigCandle=BUY" +
                  " | " + BigCandlePauseStatusText();
         return(true);
        }

      reason = "SAME-DIRECTION/NO OPPOSITE BLOCK | Candidate=SELL" +
               " | " + BigCandlePauseStatusText();
      return(false);
     }

   reason = "NO CANDIDATE DIRECTION | NOT BLOCKED";
   return(false);
  }

//+------------------------------------------------------------------+
string BigCandleDirectionalStatusText(int orderDirection)
  {
   string reason = "";

   bool blocked =
      IsBigCandleOrderBlockedForDirection(orderDirection,
                                          reason);

   return((blocked ? "BLOCK | " : "ALLOW | ") + reason);
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

   int sarDirection = g_activeSARDirection;

   if(sarDirection == 0)
      sarDirection = GetSARDotDirection(0);

   if(sarDirection == 0)
      sarDirection = GetSARDotDirection(1);

   int candleDirection = 0;

   if(Close[0] > Open[0])
      candleDirection = 1;
   else
      if(Close[0] < Open[0])
         candleDirection = -1;

   bool firstDetectionThisBar =
      (g_lastBigCandleFormationBarTime != formingBarTime);

   RegisterBigCandleDirectionalPause(
      candleDirection,
      formingMove,
      formingBarTime,
      true,
      InpBigCandlePauseMinutes,
      "FORMING CANDLE");

   g_bigCandlePauseSARDirection = sarDirection;
   g_notifyBigCandlePauseSent = true;

   if(!firstDetectionThisBar)
      return;

   DrawBigCandleRedMarker(0,
                          formingMove,
                          "FORMING CANDLE");

   Print("BIG CANDLE FORMATION DETECTED | CurrentMove=",
         DoubleToString(formingMove,Digits),
         " | Required=",
         DoubleToString(InpBigCandleRawDifference,Digits),
         " | Candle=", DirectionText(candleDirection),
         " | SAR=", DirectionText(sarDirection),
         " | Rule=BLOCK OPPOSITE DIRECTION ONLY",
         " | PauseUntil=",
         TimeToString(g_bigCandlePauseUntil,
                      TIME_DATE|TIME_SECONDS));

   if(InpNotifyOnBigCandlePause)
     {
      SendEAAlert(
         "BIG CANDLE - OPPOSITE SIDE PAUSED",
         "CurrentMove=" +
         DoubleToString(formingMove,2) +
         " | Candle=" +
         DirectionText(candleDirection) +
         " | Same direction allowed" +
         " | Opposite direction paused " +
         IntegerToString(InpBigCandlePauseMinutes) +
         "m");
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

   if(candleDirection == 0)
     {
      Print("BIG CANDLE DIRECTION UNKNOWN | No directional order block",
            " | Move=", DoubleToString(candleMove,Digits));
      return;
     }

   RegisterBigCandleDirectionalPause(
      candleDirection,
      candleMove,
      barTime,
      false,
      InpBigCandlePauseMinutes,
      "CLOSED CANDLE");

   g_bigCandlePauseSARDirection = sarDirection;
   g_notifyBigCandlePauseSent = true;

   DrawBigCandleRedMarker(1,
                          candleMove,
                          "CLOSED CANDLE");

   Print("BIG CANDLE CLOSED | Move=",
         DoubleToString(candleMove,Digits),
         " | Required=",
         DoubleToString(InpBigCandleRawDifference,Digits),
         " | Candle=", DirectionText(candleDirection),
         " | SAR=", DirectionText(sarDirection),
         " | SAME DIRECTION ALLOWED",
         " | OPPOSITE DIRECTION PAUSED",
         " | PauseUntil=",
         TimeToString(g_bigCandlePauseUntil,
                      TIME_DATE|TIME_SECONDS));

   if(InpNotifyOnBigCandlePause)
     {
      SendEAAlert(
         "BIG CANDLE - OPPOSITE SIDE PAUSED",
         "Move=" + DoubleToString(candleMove,2) +
         " | Candle=" + DirectionText(candleDirection) +
         " | Same direction allowed" +
         " | Opposite paused " +
         IntegerToString(InpBigCandlePauseMinutes) +
         "m");
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

   CheckBigCandleFormationPauseOnTick();

   if(!g_bigCandlePause)
      return(false);

   if(TimeCurrent() >= g_bigCandlePauseUntil)
     {
      Print("BIG CANDLE DIRECTIONAL PAUSE FINISHED | Until=",
            TimeToString(g_bigCandlePauseUntil,
                         TIME_DATE|TIME_SECONDS));

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
bool EnforceBigCandleOrderBlock(int orderDirection,
                                string source)
  {
   bool normalProfileSource =
      IsNormalProfileSource(source);

   bool useSpikeFilter =
      normalProfileSource
      ? IsMarketModeEntryFilterEnabled(
         DXB_FILTER_SPIKE_WICK)
      : InpUseSpikeWickPauseFilter;

   bool useBigCandleFilter =
      normalProfileSource
      ? IsMarketModeEntryFilterEnabled(
         DXB_FILTER_BIG_CANDLE)
      : InpUseBigCandlePause;

   if(useSpikeFilter &&
      EnforceSpikeWickOrderBlock(
         source,
         InpSpikeWickBlockRecovery,
         InpSpikeWickBlockGuard))
      return(true);

   if(!useBigCandleFilter)
      return(false);

   if(Bars < 10)
     {
      string shortReason = "";

      return(IsBigCandleOrderBlockedForDirection(
                orderDirection,
                shortReason));
     }

// Register the strongest current/recent single candle.
   double maxMove = 0.0;
   int maxShift = -1;

   for(int shift = 0; shift <= 2; shift++)
     {
      double move = MathAbs(High[shift] -
                            Low[shift]);

      if(move > maxMove)
        {
         maxMove = move;
         maxShift = shift;
        }
     }

   if(maxShift >= 0 &&
      maxMove >= InpBigCandleRawDifference)
     {
      int candleDirection =
         GetClosedCandleDirection(maxShift);

      if(maxShift == 0)
        {
         if(Close[0] > Open[0])
            candleDirection = 1;
         else
            if(Close[0] < Open[0])
               candleDirection = -1;
        }

      RegisterBigCandleDirectionalPause(
         candleDirection,
         maxMove,
         Time[maxShift],
         maxShift == 0,
         InpBigCandlePauseMinutes,
         "ORDER CHECK " + source);

      DrawBigCandleRedMarker(maxShift,
                             maxMove,
                             "DIRECTIONAL ORDER CHECK");
     }

// Register the combined last-three-candle move direction.
   if(InpUseLast3CandlesMovePause &&
      InpLast3CandlesRawDifference > 0.0 &&
      Bars > 10)
     {
      double highest3 = High[1];
      double lowest3  = Low[1];

      for(int candle = 2;
          candle <= 3;
          candle++)
        {
         if(High[candle] > highest3)
            highest3 = High[candle];

         if(Low[candle] < lowest3)
            lowest3 = Low[candle];
        }

      double last3Move =
         MathAbs(highest3 - lowest3);

      if(last3Move >=
         InpLast3CandlesRawDifference)
        {
         int last3Direction =
            GetLast3CandlesMoveDirection();

         int pauseMinutes3 =
            MathMax(1,
                    InpLast3CandlesPauseMinutes);

         if(InpBlockRecoveryGapOnBigCandle)
            pauseMinutes3 =
               MathMax(
                  pauseMinutes3,
                  MathMax(
                     1,
                     InpBigCandleRecoveryPauseMinutes));

         RegisterBigCandleDirectionalPause(
            last3Direction,
            last3Move,
            Time[1],
            false,
            pauseMinutes3,
            "LAST 3 CANDLES MOVE");

         DrawBigCandleRedMarker(
            1,
            last3Move,
            "LAST 3 CANDLES DIRECTIONAL");
        }
     }

   string directionReason = "";

   bool blocked =
      IsBigCandleOrderBlockedForDirection(
         orderDirection,
         directionReason);

   if(blocked)
     {
      Print("BIG CANDLE OPPOSITE-DIRECTION BLOCK | Source=",
            source,
            " | Candidate=",
            DirectionText(orderDirection),
            " | ", directionReason);
     }
   else
      if(IsBigCandlePauseActive())
        {
         Print("BIG CANDLE SAME-DIRECTION ALLOWED | Source=",
               source,
               " | Candidate=",
               DirectionText(orderDirection),
               " | ", directionReason);
        }

   return(blocked);
  }

//+------------------------------------------------------------------+
string BigCandlePauseStatusText()
  {
   if(!g_bigCandlePause)
      return("OFF");

   int secondsLeft =
      (int)(g_bigCandlePauseUntil -
            TimeCurrent());

   if(secondsLeft < 0)
      secondsLeft = 0;

   string buyState =
      (TimeCurrent() < g_bigCandleBlockBuyUntil)
      ? "BUY BLOCK"
      : "BUY ALLOW";

   string sellState =
      (TimeCurrent() < g_bigCandleBlockSellUntil)
      ? "SELL BLOCK"
      : "SELL ALLOW";

   return("ON " +
          FormatSecondsToHHMM(secondsLeft) +
          " | Big=" +
          DirectionText(
             g_bigCandlePauseCandleDirection) +
          " | " + buyState +
          " | " + sellState +
          " | Move=" +
          DoubleToString(g_lastBigCandleMove,1));
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
   bodyPercent = 999999.0;
   rangeSize = 0.0;
   bodySize = 0.0;

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

   double upperWick = MathMax(0.0, h - MathMax(o, c));
   double lowerWick = MathMax(0.0, MathMin(o, c) - l);
   maxWick = MathMax(upperWick, lowerWick);

// bodyPercent now means body size as a percentage of the larger wick.
// Example: Body=40, Wick=100 => Body/Wick%=40.
   if(maxWick > 0.0)
      bodyPercent = (bodySize / maxWick) * 100.0;

   double allowedBodyPercent = MathMax(0.0, InpSpikeWickBodyMaxPercent);

   bool wickLarge = (InpSpikeWickMinRawPrice > 0.0 &&
                     maxWick >= InpSpikeWickMinRawPrice);

   bool bodyIsWithinWickRatio = (maxWick > 0.0 &&
                                 bodyPercent <= allowedBodyPercent);

// Wick-only spike rule. Long-body and long-range candles are ignored here.
   if(wickLarge && bodyIsWithinWickRatio)
     {
      string side = "WICK";

      if(upperWick >= lowerWick)
         side = "UPPER WICK";
      else
         side = "LOWER WICK";

      reason = "SPIKE/" + side +
               " | Range=" + DoubleToString(rangeSize, 1) +
               " | Body=" + DoubleToString(bodySize, 1) +
               " | Wick=" + DoubleToString(maxWick, 1) +
               " | Body/Wick%=" + DoubleToString(bodyPercent, 1) +
               " | Max=" + DoubleToString(allowedBodyPercent, 1) + "%";
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
   if(!InpUseSpikeWickPauseFilter &&
      !IsMarketModeEntryFilterEnabled(DXB_FILTER_SPIKE_WICK))
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
   bool filterEnabled = InpUseSpikeWickPauseFilter;

   if(IsNormalProfileSource(source))
      filterEnabled = IsMarketModeEntryFilterEnabled(DXB_FILTER_SPIKE_WICK);

   if(!filterEnabled)
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
      else
         if(!g_spikeWickPause)
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
   if(!InpUseSpikeWickPauseFilter &&
      !IsMarketModeEntryFilterEnabled(DXB_FILTER_SPIKE_WICK))
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
          " | Body/Wick%=" + DoubleToString(g_lastSpikeWickBodyPercent, 1));
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

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL && !IsPendingOrderType(type))
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
   if(IsDubaiNoNewOrderHourNow())
     {
      string msg = "RECOVERY ORDER BLOCKED | DUBAI NO-NEW HOUR | DXB=" +
                   TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                   " | Hours=" + InpNoNewOrderHourList +
                   " | Source=" + sourceReason;
      SetLastOrderBlockDashboard(msg);
      Print(msg);
      return(false);
     }

// Big candle protection: do not create recovery orders during/after a big candle pause.
   CheckBigCandlePauseOnNewBar(true);
   if(EnforceBigCandleOrderBlock(direction, "OpenRecoveryOrder " + sourceReason))
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

   if(!IsRecoveryDirectionStillValid(
         direction,
         "OpenRecoveryOrder"))
      return(false);

   if(!IsStrictSARScoreAllowedForNewOrder(direction,
                                          "OpenRecoveryOrder " + sourceReason))
      return(false);

   UpdateAutoMarketFlowMode();
   if(!IsAutoMarketNewOrderAllowed("RECOVERY " + sourceReason))
     {
      string modeMsg = "RECOVERY ORDER BLOCKED | " + AutoMarketModeStatusText() +
                       " | Source=" + sourceReason;
      SetLastOrderBlockDashboard(modeMsg);
      Print(modeMsg);
      return(false);
     }

   if(IsOrderBlockedByOppositeDirectionProfitPause(direction, "OpenRecoveryOrder " + sourceReason))
      return(false);

   RefreshRates();

// InpMaxOrders is a PER-TYPE cap.
// A SELL already open blocks another SELL recovery, but BUY is unaffected.
   if(IsDirectionOrderCapReached(direction, "OpenRecoveryOrder"))
      return(false);

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

   if(!IsPendingEntryAllowedForCurrentSAR(direction, "OpenRecoveryOrder"))
      return(false);

   int type = InpUsePendingOrderEntries
              ? (direction == 1 ? OP_BUYSTOP : OP_SELLSTOP)
              : (direction == 1 ? OP_BUY : OP_SELL);

   double price = InpUsePendingOrderEntries
                  ? BuildPendingOrderPrice(direction, false)
                  : (direction == 1 ? Ask : Bid);

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

// Final atomic same-type check immediately before OrderSend.
   if(IsDirectionOrderCapReached(direction, "OpenRecoveryOrder FINAL"))
      return(false);

   if(IsDubaiNoNewOrderHourNow())
     {
      Print("RECOVERY ORDERSEND CANCELLED | DUBAI NO-NEW HOUR | DXB=",
            TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES),
            " | Hours=", InpNoNewOrderHourList);
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
   NotifyCreatedOrderTicket(ticket); // pending placement is ignored until activation

   Print(InpUsePendingOrderEntries ? "RECOVERY PENDING PLACED | Ticket=" : "RECOVERY ORDER OPENED | Ticket=", ticket,
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

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(!IsOrderTypeForDirection(OrderType(), direction, true))
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
bool OpenRecoveryGapMarketOrder(int direction, double gapMove, string triggerReason)
  {
   if(IsDubaiNoNewOrderHourNow())
     {
      string msg = "RECOVERY GAP BLOCKED | DUBAI NO-NEW HOUR | DXB=" +
                   TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                   " | Hours=" + InpNoNewOrderHourList +
                   " | Trigger=" + triggerReason;
      SetLastOrderBlockDashboard(msg);
      Print(msg);
      return(false);
     }

   if(direction == 0)
      return(false);

   if(!IsRecoveryDirectionStillValid(
         direction,
         "OpenRecoveryGapMarketOrder START"))
     {
      Print("RECOVERY GAP FINAL DIRECTION BLOCK | ",
            g_lastRecoveryAudit);
      return(false);
     }

   if(!IsStrictSARScoreAllowedForNewOrder(direction,
                                          "OpenRecoveryGapMarketOrder"))
      return(false);

   if(IsOrderBlockedByOppositeDirectionProfitPause(direction, "OpenRecoveryGapMarketOrder"))
      return(false);

   UpdateAutoMarketFlowMode();
   if(!IsAutoMarketNewOrderAllowed("RECOVERY_GAP"))
     {
      string modeMsg = "RECOVERY GAP BLOCKED BY MARKET MODE | " + AutoMarketModeStatusText();
      SetLastOrderBlockDashboard(modeMsg);
      Print(modeMsg);
      return(false);
     }

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
   if(EnforceBigCandleOrderBlock(direction, "OpenRecoveryGapMarketOrder"))
     {
      Print("RECOVERY GAP BLOCKED BY BIG CANDLE PAUSE | Direction=", DirectionText(direction),
            " | GapMove=", DoubleToString(gapMove, Digits),
            " | ", BigCandlePauseStatusText());
      return(false);
     }

   if(!IsTradingAllowedNow())
      return(false);

   RefreshRates();

// InpMaxOrders is a PER-TYPE cap across normal and recovery orders.
   if(IsDirectionOrderCapReached(direction, "OpenRecoveryGapMarketOrder"))
      return(false);

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

   if(!IsPendingEntryAllowedForCurrentSAR(direction,
                                          "OpenRecoveryGapMarketOrder"))
      return(false);

   int type = InpUsePendingOrderEntries
              ? (direction == 1 ? OP_BUYSTOP : OP_SELLSTOP)
              : (direction == 1 ? OP_BUY : OP_SELL);

   double price = InpUsePendingOrderEntries
                  ? BuildPendingOrderPrice(direction, false)
                  : (direction == 1 ? Ask : Bid);

// SAR signal price side filter is NOT applied to RECOVERY_GAP orders.
// Recovery ladder must follow adverse price gaps independently.

   double lot = NormalizeLot(InpRecoveryGapLot);
   int nextRecoveryNumber = CountRecoveryGapOrdersByDirection(direction) + 1;

// lot=lot*nextRecoveryNumber;

   double requiredGapForComment = InpRecoveryGapRawPrice * nextRecoveryNumber;
   int linkedParentTicket = GetParentTicketForRecoveryGap(direction);
   bool lossComebackTrigger = (StringFind(triggerReason, "LOSS COMEBACK") >= 0);

   string comment = InpSARRecoveryGapOrderPrefix + IntegerToString(linkedParentTicket) +
                    "_N" + IntegerToString(nextRecoveryNumber);

   if(lossComebackTrigger)
      comment += "_LC_" + DirectionText(direction);
   else
      comment += "_G" + DoubleToString(requiredGapForComment, 0) +
                 "_" + DirectionText(direction);

// Keep tag and parent ticket safe from broker comment truncation.
   if(StringLen(comment) > 30)
      comment = StringSubstr(comment, 0, 30);

// Recheck after RefreshRates and immediately before OrderSend.
   if(!IsRecoveryDirectionStillValid(
         direction,
         "OpenRecoveryGapMarketOrder FINAL"))
     {
      Print("RECOVERY GAP FINAL DIRECTION BLOCK | ",
            g_lastRecoveryAudit);
      return(false);
     }

// Final atomic same-type check immediately before OrderSend.
   if(IsDirectionOrderCapReached(direction, "OpenRecoveryGapMarketOrder FINAL"))
      return(false);

   if(IsDubaiNoNewOrderHourNow())
     {
      Print("RECOVERY GAP ORDERSEND CANCELLED | DUBAI NO-NEW HOUR | DXB=",
            TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES),
            " | Hours=", InpNoNewOrderHourList);
      return(false);
     }

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
   NotifyCreatedOrderTicket(ticket); // pending placement is ignored until activation

   g_lastRecoveryAudit =
      "OPENED #" + IntegerToString(ticket) +
      " | " + DirectionText(direction) +
      " | ActiveSAR=" +
      DirectionText(g_activeSARDirection) +
      " | ClosedSAR=" +
      DirectionText(GetSARDotDirection(1)) +
      " | LiveSAR=" +
      DirectionText(GetSARDotDirection(0)) +
      " | Trigger=" + triggerReason +
      " | Gap=" + DoubleToString(gapMove,1);
   g_lastRecoveryAuditTime = TimeCurrent();
   g_lastRecoveryAuditDirection = direction;
   g_lastRecoveryAuditGap = gapMove;

   Print(InpUsePendingOrderEntries ? "RECOVERY GAP PENDING PLACED | Ticket=" : "RECOVERY GAP ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | Lot=", DoubleToString(lot, 2),
         " | RecoveryNo=", nextRecoveryNumber,
         " | Trigger=", triggerReason,
         " | RequiredGap=", DoubleToString(requiredGapForComment, Digits),
         " | ActualGap=", DoubleToString(gapMove, Digits),
         " | Comment=", comment);

// After a recovery order is opened, open one reverse swing/hedge order.
// Example: BUY recovery -> SELL hedge, SELL recovery -> BUY hedge.
// The hedge is tagged as RECOVERY_HEDGE so ProcessIndividualProfitProtect()
// will close it only after 0.50 peak -> 0.40 pullback.

   return(true);
  }

//+------------------------------------------------------------------+
// Return the first/base order price for the recovery ladder.
// BUY: use the highest open BUY price as the base, because recovery starts
//      when price falls from the original BUY.
// SELL: use the lowest open SELL price as the base, because recovery starts
//       when price rises from the original SELL.

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   if(OpenRecoveryGapMarketOrder(direction, gapForOrder, "RAW GAP RETRY"))
     {
      ClearPendingRecoveryGap("Opened pending recovery");
      return(true);
     }

// Keep pending when opening is still blocked by temporary conditions.
   return(false);
  }

//+------------------------------------------------------------------+
//| Hard final normal-order direction consistency check.              |
//+------------------------------------------------------------------+
bool IsFinalNormalDirectionStillValid(int direction,
                                      string source)
  {
   int closedSARDirection = GetSARDotDirection(1);
   int liveSARDirection   = GetSARDotDirection(0);

   if(direction == 0)
      return(BlockOrder("FINAL DIRECTION BLOCK | Candidate NONE | Source=" +
                        source));

   if(direction != g_activeSARDirection)
      return(BlockOrder("FINAL DIRECTION BLOCK | Candidate=" +
                        DirectionText(direction) +
                        " ActiveSAR=" +
                        DirectionText(g_activeSARDirection) +
                        " | Source=" + source));

   if(closedSARDirection != 0 &&
      closedSARDirection != direction)
      return(BlockOrder("FINAL CLOSED SAR BLOCK | Candidate=" +
                        DirectionText(direction) +
                        " ClosedSAR=" +
                        DirectionText(closedSARDirection) +
                        " | Source=" + source));

   if(liveSARDirection != 0 &&
      liveSARDirection != direction)
      return(BlockOrder("FINAL LIVE SAR BLOCK | Candidate=" +
                        DirectionText(direction) +
                        " LiveSAR=" +
                        DirectionText(liveSARDirection) +
                        " | Source=" + source));

   return(true);
  }

//+------------------------------------------------------------------+
//| Recovery must use the already-refreshed current SAR direction.    |
//+------------------------------------------------------------------+
bool IsRecoveryDirectionStillValid(int direction,
                                   string source)
  {
   int closedSARDirection = GetSARDotDirection(1);
   int liveSARDirection   = GetSARDotDirection(0);

   if(direction == 0)
     {
      g_lastRecoveryAudit = "BLOCK | DIRECTION NONE | " + source;
      g_lastRecoveryAuditTime = TimeCurrent();
      return(false);
     }

   if(InpRecoveryGapMustMatchSARDirection &&
      direction != g_activeSARDirection)
     {
      g_lastRecoveryAudit =
         "BLOCK | RECOVERY=" + DirectionText(direction) +
         " ACTIVE_SAR=" + DirectionText(g_activeSARDirection) +
         " | " + source;
      g_lastRecoveryAuditTime = TimeCurrent();
      g_lastRecoveryAuditDirection = direction;
      return(false);
     }

   if(InpRecoveryGapMustMatchSARDirection &&
      closedSARDirection != 0 &&
      direction != closedSARDirection)
     {
      g_lastRecoveryAudit =
         "BLOCK | CLOSED_SAR=" +
         DirectionText(closedSARDirection) +
         " RECOVERY=" + DirectionText(direction) +
         " | " + source;
      g_lastRecoveryAuditTime = TimeCurrent();
      g_lastRecoveryAuditDirection = direction;
      return(false);
     }

   if(InpRecoveryGapMustMatchSARDirection &&
      liveSARDirection != 0 &&
      direction != liveSARDirection)
     {
      g_lastRecoveryAudit =
         "BLOCK | LIVE_SAR=" +
         DirectionText(liveSARDirection) +
         " RECOVERY=" + DirectionText(direction) +
         " | " + source;
      g_lastRecoveryAuditTime = TimeCurrent();
      g_lastRecoveryAuditDirection = direction;
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Reset loss-comeback recovery memory for one basket side.         |
//+------------------------------------------------------------------+
void ResetRecoveryLossComebackState(int direction)
  {
   if(direction == 1)
     {
      g_buyRecoveryWorstBasketProfit = 0.0;
      g_buyRecoveryLossComebackArmed = false;
     }
   else
      if(direction == -1)
        {
         g_sellRecoveryWorstBasketProfit = 0.0;
         g_sellRecoveryLossComebackArmed = false;
        }
  }

//+------------------------------------------------------------------+
//| Track the worst side-basket loss and arm the comeback trigger.   |
//+------------------------------------------------------------------+
void UpdateRecoveryLossComebackState(int direction,
                                     bool hasBasket,
                                     double currentProfit)
  {
   if(direction == 0)
      return;

   if(!hasBasket)
     {
      ResetRecoveryLossComebackState(direction);
      return;
     }

   double armLoss = MathMax(0.01, MathAbs(InpRecoveryLossArmUSD));

   if(direction == 1)
     {
      if(currentProfit < g_buyRecoveryWorstBasketProfit)
         g_buyRecoveryWorstBasketProfit = currentProfit;

      if(g_buyRecoveryWorstBasketProfit <= -armLoss)
         g_buyRecoveryLossComebackArmed = true;
     }
   else
     {
      if(currentProfit < g_sellRecoveryWorstBasketProfit)
         g_sellRecoveryWorstBasketProfit = currentProfit;

      if(g_sellRecoveryWorstBasketProfit <= -armLoss)
         g_sellRecoveryLossComebackArmed = true;
     }
  }

//+------------------------------------------------------------------+
//| Keep BUY/SELL worst-loss memory updated on every tick, even when |
//| market mode, SAR, spread or candle filters temporarily block a   |
//| recovery order.                                                   |
//+------------------------------------------------------------------+
void TrackRecoveryLossComebackAllSides()
  {
   bool hasBuyBasket = CountOpenOrdersByType(OP_BUY) > 0;
   bool hasSellBasket = CountOpenOrdersByType(OP_SELL) > 0;

   double buyProfit = hasBuyBasket ? GetBasketProfit(1) : 0.0;
   double sellProfit = hasSellBasket ? GetBasketProfit(-1) : 0.0;

   UpdateRecoveryLossComebackState(1, hasBuyBasket, buyProfit);
   UpdateRecoveryLossComebackState(-1, hasSellBasket, sellProfit);
  }

//+------------------------------------------------------------------+
//| Alternate recovery entry: deep loss has started improving.       |
//| Default: worst <= -$3 and improvement >= $1, e.g. -$3 -> -$2.   |
//+------------------------------------------------------------------+
bool IsRecoveryLossComebackReady(int direction,
                                 bool hasBasket,
                                 double currentProfit,
                                 string &reason)
  {
   reason = "LOSS COMEBACK NOT READY";

   if(!InpUseRecoveryLossComebackTrigger || direction == 0)
      return(false);

   UpdateRecoveryLossComebackState(direction, hasBasket, currentProfit);

   if(!hasBasket)
     {
      reason = "NO SIDE BASKET";
      return(false);
     }

// This alternate trigger creates the first recovery order for the side.
// The normal raw-price ladder remains responsible for later levels.
   if(CountRecoveryGapOrdersByDirection(direction) > 0)
     {
      reason = "LOSS COMEBACK ALREADY USED";
      return(false);
     }

   double worstProfit = direction == 1
                        ? g_buyRecoveryWorstBasketProfit
                        : g_sellRecoveryWorstBasketProfit;

   bool armed = direction == 1
                ? g_buyRecoveryLossComebackArmed
                : g_sellRecoveryLossComebackArmed;

   if(!armed)
     {
      reason = "WAIT TOUCH -$" +
               DoubleToString(MathMax(0.01,
                                      MathAbs(InpRecoveryLossArmUSD)), 2);
      return(false);
     }

   double comebackUSD = MathMax(0.01,
                                MathAbs(InpRecoveryLossComebackUSD));
   double comebackTarget = worstProfit + comebackUSD;
   double improvedBy = currentProfit - worstProfit;

// Recovery is unnecessary after the basket has already returned to profit.
   if(currentProfit >= 0.0)
     {
      reason = "BASKET ALREADY POSITIVE";
      return(false);
     }

   if(currentProfit + 0.0000001 < comebackTarget)
     {
      reason = "LOSS COMEBACK WAIT | Worst=$" +
               DoubleToString(worstProfit, 2) +
               " Current=$" + DoubleToString(currentProfit, 2) +
               " Target=$" + DoubleToString(comebackTarget, 2);
      return(false);
     }

   reason = "LOSS COMEBACK | Worst=$" +
            DoubleToString(worstProfit, 2) +
            " Current=$" + DoubleToString(currentProfit, 2) +
            " Improved=$" + DoubleToString(improvedBy, 2);
   return(true);
  }

//+------------------------------------------------------------------+
string RecoveryLossComebackStatusText(int direction)
  {
   bool hasBasket = CountOpenOrdersByType(direction == 1 ? OP_BUY : OP_SELL) > 0;
   double currentProfit = hasBasket ? GetBasketProfit(direction) : 0.0;
   string reason = "";

   bool ready = IsRecoveryLossComebackReady(direction,
                hasBasket,
                currentProfit,
                reason);

   return((direction == 1 ? "BUY " : "SELL ") +
          (ready ? "READY | " : "") + reason);
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
   if(EnforceBigCandleOrderBlock(g_activeSARDirection, "ProcessRecoveryGapOrders"))
     {
      Print("RECOVERY PROCESS BLOCKED BY BIG CANDLE PAUSE | ", BigCandlePauseStatusText());
      return;
     }

   if(InpRecoveryGapLot <= 0.0)
      return;

// At least one recovery trigger must be enabled:
// raw-price gap OR dynamic loss comeback.
   if(InpRecoveryGapRawPrice <= 0.0 &&
      !InpUseRecoveryLossComebackTrigger)
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

   double buyBasketProfit = hasBuy ? GetBasketProfit(1) : 0.0;
   double sellBasketProfit = hasSell ? GetBasketProfit(-1) : 0.0;

   string buyLossComebackReason = "";
   string sellLossComebackReason = "";

   bool buyLossComebackReady =
      IsRecoveryLossComebackReady(1,
                                  hasBuy,
                                  buyBasketProfit,
                                  buyLossComebackReason);

   bool sellLossComebackReady =
      IsRecoveryLossComebackReady(-1,
                                  hasSell,
                                  sellBasketProfit,
                                  sellLossComebackReason);

   bool buyRawGapReady =
      (InpRecoveryGapRawPrice > 0.0 &&
       hasBuy &&
       buyGap >= buyRequiredGap);

   bool sellRawGapReady =
      (InpRecoveryGapRawPrice > 0.0 &&
       hasSell &&
       sellGap >= sellRequiredGap);

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

   if(buyRawGapReady &&
      buyRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
      !allowBuyRecoveryBySAR)
     {
      RememberPendingRecoveryGap(1, buyGap, buyRequiredGap,
                                 "BUY recovery gap matched but SAR not BUY");
     }

   if(sellRawGapReady &&
      sellRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
      !allowSellRecoveryBySAR)
     {
      RememberPendingRecoveryGap(-1, sellGap, sellRequiredGap,
                                 "SELL recovery gap matched but SAR not SELL");
     }

// Alternate trigger logic:
// RAW GAP ready OR LOSS COMEBACK ready.
// A confirmed loss comeback bypasses only the strong-opposite-move gap block,
// because improving P/L is itself the reversal confirmation. All other
// recovery filters remain enforced inside OpenRecoveryGapMarketOrder().
   bool buyReady = (allowBuyRecoveryBySAR &&
                    hasBuy &&
                    buyRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                    ((buyRawGapReady &&
                      !IsStrongOppositeMoveAgainstRecovery(1, buyGap)) ||
                     buyLossComebackReady));

   bool sellReady = (allowSellRecoveryBySAR &&
                     hasSell &&
                     sellRecoveryCount < InpMaxRecoveryGapOrdersPerSide &&
                     ((sellRawGapReady &&
                       !IsStrongOppositeMoveAgainstRecovery(-1, sellGap)) ||
                      sellLossComebackReady));

// Open only one recovery gap order per tick. Choose the side with the larger adverse move.
   if(buyReady && (!sellReady || buyGap >= sellGap))
     {
      string buyTriggerReason = buyLossComebackReady
                                ? buyLossComebackReason
                                : "RAW GAP";

      Print("RECOVERY READY | BUY | Trigger=", buyTriggerReason,
            " | BasketP/L=$", DoubleToString(buyBasketProfit, 2),
            " | Base=", DoubleToString(buyBase, Digits),
            " | CurrentGap=", DoubleToString(buyGap, Digits),
            " | RequiredGap=", DoubleToString(buyRequiredGap, Digits),
            " | RecoveryCount=", buyRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      if(!OpenRecoveryGapMarketOrder(1, buyGap, buyTriggerReason))
        {
         // Raw-gap matches can use the existing retry memory.
         // Loss-comeback readiness is already remembered by worst-loss state
         // and will be checked again automatically on the next tick.
         if(buyRawGapReady && !buyLossComebackReady)
            RememberPendingRecoveryGap(1, buyGap, buyRequiredGap,
                                       "BUY recovery gap ready but OrderSend/condition failed");
        }
      return;
     }

   if(sellReady)
     {
      string sellTriggerReason = sellLossComebackReady
                                 ? sellLossComebackReason
                                 : "RAW GAP";

      Print("RECOVERY READY | SELL | Trigger=", sellTriggerReason,
            " | BasketP/L=$", DoubleToString(sellBasketProfit, 2),
            " | Base=", DoubleToString(sellBase, Digits),
            " | CurrentGap=", DoubleToString(sellGap, Digits),
            " | RequiredGap=", DoubleToString(sellRequiredGap, Digits),
            " | RecoveryCount=", sellRecoveryCount, "/", InpMaxRecoveryGapOrdersPerSide);

      if(!OpenRecoveryGapMarketOrder(-1, sellGap, sellTriggerReason))
        {
         if(sellRawGapReady && !sellLossComebackReady)
            RememberPendingRecoveryGap(-1, sellGap, sellRequiredGap,
                                       "SELL recovery gap ready but OrderSend/condition failed");
        }
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
//| Affordable SAR special guard lot                                 |
//| Uses requested lot as MAX. If free margin is not enough, reduces |
//| lot step-by-step until AccountFreeMarginCheck() passes.          |
//+------------------------------------------------------------------+
//| Parent + recovery gap basket profit for guard trigger            |
//| Normal/recovery in same side are included; guard/hedge excluded. |
//+------------------------------------------------------------------+
//| Create SAR special guard only from parent+recovery loss           |
//| BYPASSES all normal filters: SAR, big candle, spread, hours, etc. |
//| BUY parent gets SELL guard. SELL parent gets BUY guard.           |
//| One guard per parent ticket.                                      |
//+------------------------------------------------------------------+
void ProcessSARSpecialGuardCleanup()
  {
// Creation code was removed. Scan only to safely manage a legacy open guard.
   if(CountSARSpecialGuardOrders() <= 0)
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

// Every untriggered EA pending order belongs to the old SAR cycle.
// Delete it before updating direction. The new cycle must complete its
// SAR confirmation before another pending order may be placed.
   if(InpDeletePendingOrdersOnSARChange)
     {
      int deletedPending = DeletePendingOrdersByDirection(
                              0,
                              "SAR signal changed " +
                              DirectionText(oldDirection) + " -> " +
                              DirectionText(sarFlip),
                              false);

      Print("SAR CHANGE PENDING CLEANUP | Deleted=", deletedPending,
            " | Old=", DirectionText(oldDirection),
            " | New=", DirectionText(sarFlip));
     }

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

// Guard orders are ignored by normal basket/profit/SL close logic and close only when parent closes.

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

   DeletePendingOrdersByDirection(direction,
                                  reason + " | EARLY SIDE CLOSE",
                                  anyMagic);
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
   double target = GetBasketProfitTargetForDirection(direction);
   bool oppositeAfterFlip = IsOppositeBasketAfterSARFlip(direction);
   bool agedHalfTP = IsBasketHalfTPAfterTime(direction);
   bool fixedHalfTP = IsFixedHalfBasketTPActive();
   string reducedTPReason = GetReducedBasketTPReasonText(direction);
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

// Dynamic basket profit is already handled first in
// ProcessFirstPriorityBasketProfitClose(). Do not allow this older fixed-TP
// path to close the side immediately at InpBasketProfitUSD.
   if(InpUseDynamicBasketProfitBooking)
      return(false);

   if(profit >= target)
     {
      string tpReason = (oppositeAfterFlip || agedHalfTP || fixedHalfTP)
                        ? reducedTPReason + " | " +
                        DirectionText(direction) +
                        " basket profit $" + DoubleToString(profit, 2)
                        : "Basket profit $" + DoubleToString(profit, 2);

      CloseOrdersByDirection(direction, tpReason);

      if(direction == g_sarCloseTrackedDirection)
        {
         g_sarChangesAfterLastNormalOrder = 0;
         g_sarCloseTrackedDirection       = 0;
         g_sarCloseTrackedOrderTime       = 0;
         g_sarDelayedCloseStatus          = "Basket TP reset";
        }

      Print((oppositeAfterFlip || agedHalfTP || fixedHalfTP)
            ? "REDUCED BASKET TP HIT | Direction="
            : "BASKET PROFIT HIT | Direction=",
            DirectionText(direction),
            " | Rule=", reducedTPReason,
            " | AgeMin=", GetBasketOpenAgeMinutes(direction),
            " | CurrentSAR=", DirectionText(g_activeSARDirection),
            " | Profit=$", DoubleToString(profit, 2),
            " | Target=$", DoubleToString(target, 2));

      status = (oppositeAfterFlip || agedHalfTP || fixedHalfTP)
               ? reducedTPReason + " " + DirectionText(direction)
               : "Basket TP " + DirectionText(direction);
      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
//| Check BUY and SELL baskets independently                          |
//+------------------------------------------------------------------+
bool ProcessAllSideBasketClose(string &status)
  {
   if(ProcessBasketCloseByDirection(1, status))
      return(true);

   if(ProcessBasketCloseByDirection(-1, status))
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

// PRIORITY 0: BUY/SELL basket TP/SL must work independently.
// This is required because delayed SAR close may leave the previous direction basket open.
   if(ProcessAllSideBasketClose(status))
      return(true);

// PRIORITY 1: Early trend reverse close.
// This runs before SAR confirmation, flat mode, basket TP/SL, order count, cooldown, or new-order checks.
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_REVERSE))
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
   else
     {
      g_sarPausedByEarly = false;
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
   if(!InpUseDynamicBasketProfitBooking &&
      CountOrdersByDirection(g_activeSARDirection) > 0 &&
      activeProfit >= basketTarget)
     {
      string activeTPReason =
         GetReducedBasketTPReasonText(g_activeSARDirection);

      CloseOrdersByDirection(
         g_activeSARDirection,
         activeTPReason +
         " | Basket profit $" +
         DoubleToString(activeProfit, 2));

      Print(IsFixedHalfBasketTPActive()
            ? "FIXED HALF BASKET PROFIT HIT | Direction="
            : "BASKET PROFIT HIT | Direction=",
            DirectionText(g_activeSARDirection),
            " | Rule=", activeTPReason,
            " | SARScore=", GetCurrentSARScoreForBasketTP(),
            " | Profit=$", DoubleToString(activeProfit, 2),
            " | Target=$", DoubleToString(basketTarget, 2));

      status = activeTPReason + " booked";
      return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//| Oldest open time for one BUY/SELL basket side                    |
//+------------------------------------------------------------------+
datetime GetOldestBasketOrderOpenTime(int direction)
  {
   if(direction == 0)
      return(0);

   int type = (direction == 1) ? OP_BUY : OP_SELL;
   datetime oldest = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber ||
         OrderType() != type ||
         IsSARGuardOrderComment(OrderComment()))
         continue;

      if(oldest <= 0 || OrderOpenTime() < oldest)
         oldest = OrderOpenTime();
     }

   return(oldest);
  }

//+------------------------------------------------------------------+
int GetBasketOpenAgeMinutes(int direction)
  {
   datetime oldest = GetOldestBasketOrderOpenTime(direction);

   if(oldest <= 0)
      return(0);

   return((int)MathMax(0, (TimeCurrent() - oldest) / 60));
  }

//+------------------------------------------------------------------+
bool IsBasketHalfTPAfterTime(int direction)
  {
   if(!InpUseBasketHalfTPAfterMinutes || direction == 0)
      return(false);

   if(CountOrdersByDirection(direction) <= 0)
      return(false);

   int requiredMinutes = MathMax(1, InpBasketHalfTPAfterMinutes);
   return(GetBasketOpenAgeMinutes(direction) >= requiredMinutes);
  }

//+------------------------------------------------------------------+
bool IsOppositeBasketAfterSARFlip(int direction)
  {
   return(InpUseSARFlipOppositeBasketHalfTP &&
          direction != 0 &&
          g_activeSARDirection != 0 &&
          direction != g_activeSARDirection);
  }

//+------------------------------------------------------------------+
string GetReducedBasketTPReasonText(int direction)
  {
   bool mixed   = IsMixedModeHalfBasketTPActive();
   bool lowScore = IsLowSARScoreHalfBasketTPActive();
   bool flipped = IsOppositeBasketAfterSARFlip(direction);
   bool aged    = IsBasketHalfTPAfterTime(direction);

   string reason = "";

   if(mixed)
      reason = "MIXED HALF TP";

   if(lowScore)
     {
      if(reason != "")
         reason += " + ";

      reason += "SAR SCORE<=" +
                IntegerToString(
                   MathMax(0,
                           InpSARScoreHalfBasketTPMax)) +
                " HALF TP";
     }

   if(flipped)
     {
      if(reason != "")
         reason += " + ";

      reason += "SAR FLIP HALF TP";
     }

   if(aged)
     {
      if(reason != "")
         reason += " + ";

      reason += IntegerToString(
                   MathMax(1, InpBasketHalfTPAfterMinutes)) +
                " MIN HALF TP";
     }

   if(reason == "")
      reason = "NORMAL TP";

   return(reason);
  }

//+------------------------------------------------------------------+
//| Direction-specific basket target                                 |
//| Reduced target applies when either:                              |
//| 1) the basket is opposite to current SAR, OR                     |
//| 2) the basket has remained open for configured minutes.          |
//+------------------------------------------------------------------+
double GetBasketProfitTargetForDirection(int direction)
  {
   double normalTarget = GetBasketProfitTargetUSD();

   if(direction == 0)
      return(normalTarget);

   double selectedTarget = normalTarget;

   if(IsOppositeBasketAfterSARFlip(direction))
     {
      double flipMultiplier = InpSARFlipOppositeBasketTPMultiplier;

      if(flipMultiplier <= 0.0)
         flipMultiplier = 0.50;
      if(flipMultiplier > 1.0)
         flipMultiplier = 1.0;

      double flipTarget =
         MathMax(0.01, MathAbs(InpBasketProfitUSD) * flipMultiplier);

      if(selectedTarget > 0.0)
         selectedTarget = MathMin(selectedTarget, flipTarget);
      else
         selectedTarget = flipTarget;
     }

   if(IsBasketHalfTPAfterTime(direction))
     {
      double timeMultiplier = InpBasketHalfTPAfterMinutesMultiplier;

      if(timeMultiplier <= 0.0)
         timeMultiplier = 0.50;
      if(timeMultiplier > 1.0)
         timeMultiplier = 1.0;

      double timeTarget =
         MathMax(0.01, MathAbs(InpBasketProfitUSD) * timeMultiplier);

      if(selectedTarget > 0.0)
         selectedTarget = MathMin(selectedTarget, timeTarget);
      else
         selectedTarget = timeTarget;
     }

   return(selectedTarget);
  }


//+------------------------------------------------------------------+
bool ProcessNewOrderCreationLast(bool isNewBar, string &status)
  {
   if(g_activeSARDirection == 0)
     {
      return(SetOrderBlockStatus(status, "Waiting for first SAR"));
     }

   EnsureSARSignalOrderCycle(g_activeSARDirection);

// HARD DUBAI-TIME ENTRY LOCK: applies to order #1 and every later
// normal SAR order, regardless of the active filter profile.
   if(IsDubaiNoNewOrderHourNow())
     {
      return(SetOrderBlockStatus(
                status,
                "NO NEW ORDERS DUBAI HOUR | DXB=" +
                TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                " | HOURS=" + InpNoNewOrderHourList));
     }

// ORDER #1 AFTER SAR FLIP:
// Go directly to the dedicated price-difference-only profile. This branch
// bypasses optional strategy filters, but never bypasses the hard Dubai
// no-new-order hours, trading permission, direction or per-side cap.
   if(IsFirstSAROrderAfterFlip(g_activeSARDirection))
     {
      if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_FIRST_ORDER"))
        {
         status = "FIRST SAR ORDER OPENED | PRICE DIFF + DUBAI TIME OK | " +
                  DirectionText(g_activeSARDirection);
         return(true);
        }

      status = g_lastOrderOpenReason;
      return(false);
     }

// ORDER #2 AND LATER: full market-mode filter profile follows below.

// Hard no-new-order hours are already checked above for every normal entry.
// Existing market-order close/profit/protection management still runs.
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_NO_NEW_HOUR) &&
      IsNoNewOrderHour())
     {
      return(SetOrderBlockStatus(status, "NO NEW ORDERS DUBAI HOUR - " + InpNoNewOrderHourList));
     }

// Big candle blocks only a candidate OPPOSITE to the big candle.
// Same-direction normal orders remain allowed.
   string bigDirectionReason = "";

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_BIG_CANDLE) &&
      IsBigCandleOrderBlockedForDirection(
         g_activeSARDirection,
         bigDirectionReason))
     {
      return(SetOrderBlockStatus(
                status,
                "BIG CANDLE OPPOSITE BLOCK - " +
                bigDirectionReason));
     }

// Early SAR weak exit blocks ONLY new normal orders while the weak active SAR basket still exists.
// If confirmed weak close already removed that basket, allow fresh SAR-direction order logic on the next tick.
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_WEAK_EXIT) &&
      g_earlySARWeakExitActive &&
      CountOrdersByDirection(g_activeSARDirection) > 0)
     {
      status = "SAR WEAK - STOP NEW ORDERS";
      SetLastOrderBlockDashboard(status + " | " + g_earlySARWeakExitReason);
      Print("NEW ORDER BLOCKED BY EARLY SAR WEAK EXIT | Direction=",
            DirectionText(g_activeSARDirection), " | ", g_earlySARWeakExitReason);
      return(false);
     }

// Pending SAR confirmation blocks ONLY new orders. It cannot block close management.
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM) &&
      g_pendingSARConfirmDirection != 0)
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
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_DYNAMIC_SAR) &&
      !IsDynamicSARAllowedForNewOrder(g_activeSARDirection, dynamicBlockReason))
     {
      status = "SAR BLOCK - " + dynamicBlockReason;
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
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_LATE_SAR) &&
      IsLateSARCycleEntryDanger(g_activeSARDirection, lateSARBlockReason))
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
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_FLAT_MODE))
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_REVERSE) &&
      g_sarPausedByEarly)
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_H1_TREND) &&
      !IsOrderAllowedByH1Trend(g_activeSARDirection))
     {
      status = "BLOCKED:SAR REV H1 "+DirectionText(GetH1TrendDirection());
      SetLastOrderBlockDashboard(status);
      Print("ORDER BLOCKED | SAR reverse against H1 trend | Direction=", DirectionText(g_activeSARDirection));
      return(false);
     }

   int dynamicMaxOrders = g_sarCycleMaxOrders;
   int cycleOrders      = g_sarCycleOrdersCreated;

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE) &&
      dynamicMaxOrders <= 0)
     {
      status = "SAR CYCLE Immidiate change MAX BLOCK - MAX 0";
      SetLastOrderBlockDashboard(status);
      Print("ORDER BLOCKED | SAR cycle max is 0 | Direction=", DirectionText(g_activeSARDirection),
            " | Last5=", GetSARDurationSummaryText());
      return(false);
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE) &&
      cycleOrders >= dynamicMaxOrders)
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_PRICE_SIDE) &&
      !IsSARSignalPriceSideAllowed(g_activeSARDirection, "Normal SAR order"))
     {
      return(SetOrderBlockStatus(status, "SAR PRICE SIDE BLOCK"));
     }

   if(!CanOpenNewOrder(g_activeSARDirection))
     {
      status = "Order gate blocked | " + g_lastOrderOpenReason;
      SetLastOrderBlockDashboard(status);
      return(false);
     }

// Normal continuity order needs price to move in the SAR direction.
// Pullback/micro re-entry creation has been removed.
   bool normalContinuousGapReady =
      !IsMarketModeEntryFilterEnabled(DXB_FILTER_REPEATED_GAP) ||
      IsRepeatedPriceGapConfirmedForNormalOrder(g_activeSARDirection,
            "SAR_FLIP_V2LAST_PRECHECK");

   if(!normalContinuousGapReady)
     {
      status = "CONTINUOUS GAP WAIT | MICRO/PULLBACK ORDERS REMOVED";
      SetLastOrderBlockDashboard(status);
      return(false);
     }

   if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_V2LAST"))
     {
      status = "Active " + DirectionText(g_activeSARDirection);

      Print("NEW ORDER CREATED | Direction=",
            DirectionText(g_activeSARDirection),
            " | CycleOrders=", g_sarCycleOrdersCreated,
            " | MaxOrders=", g_sarCycleMaxOrders,
            " | Last5=", GetSARDurationSummaryText());

      return(true);
     }

   status = g_lastOrderOpenReason;

   Print("NEW ORDER NOT CREATED | Direction=",
         DirectionText(g_activeSARDirection),
         " | Reason=", g_lastOrderOpenReason);

   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawEMATrendLines()
  {
   DrawEMALine("DXB_EMA_FAST", InpFastEMA, clrLime, 2);
   DrawEMALine("DXB_EMA_SLOW", InpSlowEMA, clrRed, 2);
   DrawEMALine("DXB_EMA_H1_FAST", InpH1FastEMA, clrAqua, 1);
   DrawEMALine("DXB_EMA_H1_SLOW", InpH1SlowEMA, clrOrange, 1);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AllowRecoveryOrders()
  {
   if(g_marketMode == MODE_STRONG_TREND)
      return(false);

   if(g_marketMode == MODE_DANGER)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool AllowPullbackOrders()
  {
   if(g_marketMode == MODE_STRONG_TREND)
      return(false);

   if(g_marketMode == MODE_DANGER)
      return(false);

   return(true);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//| Detect when a normal pending entry has become a market order.     |
//+------------------------------------------------------------------+
void TrackActivatedPendingNormalOrder()
  {
   if(!InpUsePendingOrderEntries ||
      !InpUseDelayedSARChangeClose ||
      !InpResetSARCloseCounterOnNewOrder)
      return;

   int latestTicket = -1;
   int latestDirection = 0;
   datetime latestOpenTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      if(!IsSARParentOrderComment(OrderComment()))
         continue;

      if(OrderOpenTime() >= latestOpenTime)
        {
         latestOpenTime = OrderOpenTime();
         latestTicket = OrderTicket();
         latestDirection = (type == OP_BUY) ? 1 : -1;
        }
     }

   if(latestTicket < 0 ||
      latestTicket == g_lastActivatedPendingMarketTicket)
      return;

   g_lastActivatedPendingMarketTicket = latestTicket;
   g_sarChangesAfterLastNormalOrder = 0;
   g_sarCloseTrackedDirection       = latestDirection;
   g_sarCloseTrackedOrderTime       = latestOpenTime;
   g_sarDelayedCloseStatus          = "TRACK " +
                                      DirectionText(latestDirection) +
                                      " 0/" +
                                      IntegerToString(
                                         MathMax(
                                               1,
                                               InpCloseOrdersOnNthSARChangeAfterOrder));

   Print("PENDING ACTIVATED AS MARKET ORDER | Ticket=", latestTicket,
         " | Direction=", DirectionText(latestDirection),
         " | OpenTime=", TimeToString(latestOpenTime,
                                      TIME_DATE|TIME_SECONDS),
         " | DelayedSARClose=", g_sarDelayedCloseStatus);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   int dubaiHour = TimeHour(GetDubaiTime());


   if(dubaiHour>13)
     {
      //         InpBasketStopLossUSD       = 1;//0.25;//5;// 3;;//2;//5;//2;//5.00;    // BASKET stop loss in USD, 0 = disabled. This closes all orders in active SAR direction.

      //   InpContinuousTrendBasketSLUSD   =  1;//0.25;//3;//2;//5;//1;// 2;//5.00;
      //   InpMediumTrendBasketSLUSD       =  1;//0.25;//3;//6;// 3;////2;//10;//10;//1;//2;//10.00;
      //    InpMixedTrendBasketSLUSD        =  1;//0.25;//6;//3;// 2;//10;//5;//10;//1;//2;//10.00;
      //  InpDangerModeBasketSLUSD        =  1;//0.25;// 3;//2;//5;//1;//2;//5.00;

      InpPendingOrderRawGap=50;
      InpSARConfirmPriceDiff=100;//

     }


// Print confirmation only for the first two received ticks.
   // if(g_tickConfirmationCount < 2)
     {
      g_tickConfirmationCount++;
      string msg =
         "EA IS WORKING | TICK RECEIVED | Confirmation " +
         IntegerToString(g_tickConfirmationCount) +
         "/2" +
         " | Symbol " + Symbol() +
         " | Bid " + DoubleToString(Bid, Digits) +
         " | Ask " + DoubleToString(Ask, Digits) +
         " | Dubai " +
         TimeToString(GetDubaiTime(), TIME_DATE | TIME_SECONDS);

      // Confirmation remains in the Experts log only.
      Print(msg);
       if(g_tickConfirmationCount < 2)

      SendNotification(msg);
     }

// Send only ORDER CREATED / ORDER CLOSED push events.
   ProcessCreatedClosedPushNotifications();

// A pending BUYSTOP/SELLSTOP can otherwise activate at the broker during
// a blocked Dubai hour. Remove all untriggered EA pending entries first.
   if(IsDubaiNoNewOrderHourNow())
     {
      DeletePendingOrdersByDirection(
         0,
         "DUBAI NO-NEW HOUR HARD LOCK | DXB=" +
         TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
         " | Hours=" + InpNoNewOrderHourList,
         false);
     }

   if(AccountEquity() <= 0)
     {
      string g_lastStatus =
         "LOW EQUITY | NEW TRADING PAUSED | EQUITY $" +
         DoubleToString(AccountEquity(), 2);

      Print(g_lastStatus);

      return;
     }
   /*
     if(AccountBalance() >= 40.0)
      {
         // Example:
         // Balance $40  => Basket SL $20
         // Balance $100 => Basket SL $50
         InpBasketStopLossUSD =
            MathMax(10.0, AccountBalance() / 2.0);

            InpBasketStopLossUSD=25;

           InpContinuousTrendBasketSLUSD=InpBasketStopLossUSD;//
     InpMediumTrendBasketSLUSD  =InpBasketStopLossUSD;//
     InpMixedTrendBasketSLUSD     =InpBasketStopLossUSD;//
       InpDangerModeBasketSLUSD     =InpBasketStopLossUSD;//
      }

     // One maximum order for every $20 balance
         // Balance $40  => 2 orders
         // Balance $59  => 2 orders
         // Balance $60  => 3 orders
         InpSARNormalDurationMaxOrders =
            MathMax(1, (int)MathFloor(AccountBalance() / 20.0));

   */



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

// Remember the deepest BUY/SELL basket loss continuously.
// This allows -$3 -> -$2 recovery detection even if entry filters
// were temporarily blocking recovery at the exact -$3 tick.
   TrackRecoveryLossComebackAllSides();

// Pending orders become normal BUY/SELL trades at broker execution.
// Start delayed SAR-close tracking only after that activation.
   TrackActivatedPendingNormalOrder();

// Detect a new 3-profit streak immediately after history changes and maintain the 2-hour lock.
   UpdateOppositeDirectionProfitPause(false);

   UpdateAutoMarketFlowMode();
   ApplyMarketModeEntryFilterProfileState();

// Update spike/wick pause status on every tick so dashboard shows it immediately.
   EnforceSpikeWickOrderBlock("OnTick dashboard scan", InpSpikeWickBlockRecovery, InpSpikeWickBlockGuard);

   ProcessSARSpecialGuardCleanup();

// DIRECTION-WISE BASKET STOP LOSS FIRST:
// BUY loss closes only BUY orders; SELL loss closes only SELL orders.
// Opposite side and any legacy guard order remain open.
   string directionSLStatus = "RUNNING";
   if(ProcessDirectionWiseBasketStopLossOnly(directionSLStatus))
     {
      DrawLeftOrderCreationChecklist(directionSLStatus);
      DrawDashboard(directionSLStatus);
      return;
     }

// FIRST PRIORITY PROFIT BOOKING:
// Dynamic mode: BUY and SELL independently advance through X1, X2, X3... and
// close only on pullback to the highest protected completed level.
// Fixed mode: use the older combined/side live-target close logic.
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
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EQUITY_LOCK) &&
      CheckEquityConditions())
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

// Recovery processing is intentionally delayed until AFTER current
// SAR state/flip processing. Running it here used the previous SAR direction
// and could create a recovery order on the wrong side of a fresh flip.

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

// RECOVERY CREATION AFTER SAR UPDATE:
// g_activeSARDirection and the closed-candle SAR signal are now current.
// Do not create a recovery order on the same tick that closed an order.
   if(!closedThisTick && CountOpenOrders() > 0)
      ProcessRecoveryGapOrders();

// SECTION 3: New normal order creation LAST. Runs only if nothing closed this tick.
   if(!closedThisTick)
      ProcessNewOrderCreationLast(isNewBar, status);


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
//| First SAR-cycle order uses LIVE Bid/Ask and the fixed input only. |
//| No EMA, candle, time-expiry, ATR/dynamic, mode or gap filters.     |
//+------------------------------------------------------------------+
double GetFirstSAROrderLivePriceDiff(int direction)
  {
   RefreshRates();

   double referencePrice = 0.0;

   if(g_pendingSARConfirmDirection == direction &&
      g_pendingSARConfirmPrice > 0.0)
      referencePrice = g_pendingSARConfirmPrice;
   else
      referencePrice = g_activeSARSignalChangePrice;

   if(referencePrice <= 0.0)
      return(-1.0);

   if(direction == 1)
      return(Ask - referencePrice);

   if(direction == -1)
      return(referencePrice - Bid);

   return(-1.0);
  }

//+------------------------------------------------------------------+
bool IsFirstSAROrderPriceDiffReady(int direction)
  {
   if(direction == 0)
      return(false);

   double requiredDiff = MathMax(0.0, InpSARConfirmPriceDiff);
   double currentDiff  = GetFirstSAROrderLivePriceDiff(direction);

   if(currentDiff < 0.0)
      return(false);

   return(currentDiff >= requiredDiff);
  }

//+------------------------------------------------------------------+
string FirstSAROrderPriceDiffStatusText(int direction)
  {
   double currentDiff  = GetFirstSAROrderLivePriceDiff(direction);
   double requiredDiff = MathMax(0.0, InpSARConfirmPriceDiff);

   if(currentDiff < 0.0)
      return("NO SAR Min Distance "+InpSARConfirmPriceDiff +"/"+ DoubleToString(currentDiff, Digits) );

   return("LIVE DIFF " + DoubleToString(currentDiff, Digits) +
          "/" + DoubleToString(requiredDiff, Digits) +
          (currentDiff >= requiredDiff ? " READY" : " WAIT"));
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
// The first-order price-difference profile always needs the SAR flip
// reference price, even when the current market-mode profile disables
// its normal SAR_CONFIRM filter.
   if(!InpFirstSAROrderPriceDiffOnly &&
      !IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM))
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
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM))
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
   if(direction == 1 && sar1 < Close[1])
      score++;
   if(direction == -1 && sar1 > Close[1])
      score++;

// 2) SAR dot distance must be meaningful compared with current BTC ATR.
   if(dotDistance >= atr * InpDynamicStrongDotATRMultiplier)
      score++;

// 3) EMA9/EMA21 must agree and be separated enough.
   if(direction == 1 && emaFast > emaSlow && emaDistance >= atr * InpDynamicEMADistanceATRMultiplier)
      score++;
   if(direction == -1 && emaFast < emaSlow && emaDistance >= atr * InpDynamicEMADistanceATRMultiplier)
      score++;

// 4) ADX confirms trend strength.
   if(adx >= InpDynamicADXStrong)
      score++;

// 5) Candle pressure confirms direction.
   if(sameColor >= 2)
      score++;

// 6) Last closed candle should continue in SAR direction.
   if(direction == 1 && Close[1] > Close[2])
      score++;
   if(direction == -1 && Close[1] < Close[2])
      score++;

// 7) Long breakout candle in SAR direction is a senior-trader momentum clue.
   int candleDirection = GetClosedCandleDirection(1);
   if(candleDirection == direction && barRange >= atr * InpDynamicLongBarATRMultiplier)
      score++;

// Penalties: avoid blind SAR during chop or reversal bars.
   if(dotDistance < atr * InpDynamicWeakDotATRMultiplier)
      score--;
   if(adx < InpDynamicADXWeak)
      score--;
   if(HasOppositeLongBarDanger(direction, atr))
      score -= 2;

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

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DYNAMIC_SAR))
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
         g_dynamicSARDecision = "WAITing Time and Score";
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
int GetStrictSARMinimumScore()
  {
   int required = InpStrictSARMinimumScore;

   if(required < 0)
      required = 0;
   if(required > 7)
      required = 7;

   return(required);
  }

//+------------------------------------------------------------------+
//| Final hard gate used before every non-guard market entry.        |
//| Direct OrderSend paths cannot bypass this score requirement.      |
//+------------------------------------------------------------------+
bool IsStrictSARScoreAllowedForNewOrder(int direction, string source)
  {
   if(!InpUseStrictSARScoreEntry)
      return(true);

   if(direction == 0)
     {
      string zeroMsg = "STRICT SAR SCORE BLOCK | Direction=NONE | Source=" + source;
      g_lastOrderOpenReason = zeroMsg;
      g_lastOrderBlockTime = TimeCurrent();
      SetLastOrderBlockDashboard(zeroMsg);
      Print(zeroMsg);
      return(false);
     }

   int required = GetStrictSARMinimumScore();
   int score = GetDynamicSARStrengthScore(direction);

   if(score < required)
     {
      g_dynamicSARDecision = "STRICT SCORE BLOCK";

      string msg = "STRICT SAR SCORE BLOCK | Direction=" +
                   DirectionText(direction) +
                   " | Score=" + IntegerToString(score) +
                   "/" + IntegerToString(required) +
                   " | ATR=" + DoubleToString(g_dynamicSARATR, 1) +
                   " | ADX=" + DoubleToString(g_dynamicSARADX, 1) +
                   " | Dot=" + DoubleToString(g_dynamicSARDotDistance, 1) +
                   " | Source=" + source;

      g_lastOrderOpenReason = msg;
      g_lastOrderBlockTime = TimeCurrent();
      SetLastOrderBlockDashboard(msg);
      Print(msg);
      return(false);
     }

   g_dynamicSARDecision = "STRICT SCORE ALLOW";

   Print("STRICT SAR SCORE ALLOW | Direction=", DirectionText(direction),
         " | Score=", score, "/", required,
         " | Source=", source);

   return(true);
  }


//+------------------------------------------------------------------+
//| Reset doubtful-candle pending confirmation.                       |
//+------------------------------------------------------------------+
void ResetDoubtfulCandleConfirmation(string reason)
  {
   g_doubtConfirmDirection      = 0;
   g_doubtConfirmReferenceTime  = 0;
   g_doubtConfirmReferenceHigh  = 0.0;
   g_doubtConfirmReferenceLow   = 0.0;
   g_doubtConfirmReferenceClose = 0.0;
   g_doubtConfirmStatus         = "READY";
   g_doubtConfirmReason         = reason;
  }

//+------------------------------------------------------------------+
bool IsDoubtfulSignalCandle(int direction,
                            int shift,
                            string &whyDoubtful)
  {
   whyDoubtful = "";

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE))
      return(false);

   if(direction == 0 || shift < 1 || Bars <= shift + 2)
     {
      whyDoubtful = "INVALID DATA";
      return(true);
     }

   double o = iOpen(Symbol(), PERIOD_M1, shift);
   double c = iClose(Symbol(), PERIOD_M1, shift);
   double h = iHigh(Symbol(), PERIOD_M1, shift);
   double l = iLow(Symbol(), PERIOD_M1, shift);
   double range = h - l;

   if(range <= 0.0)
     {
      whyDoubtful = "ZERO RANGE";
      return(true);
     }

   double body = MathAbs(c - o);
   double upperWick = MathMax(0.0, h - MathMax(o, c));
   double lowerWick = MathMax(0.0, MathMin(o, c) - l);
   double oppositeWick = (direction == 1) ? upperWick : lowerWick;
   double bodyPercent = (body / range) * 100.0;
   double closeLocation = ((c - l) / range) * 100.0;

   bool correctColor = (direction == 1) ? (c > o) : (c < o);

   bool wrongSideWick =
      (oppositeWick >= MathMax(0.0, InpDoubtfulOppositeWickMinRaw) &&
       (body <= 0.0 ||
        oppositeWick >= body *
        MathMax(0.0, InpDoubtfulOppositeWickBodyRatio)));

   bool weakBody =
      (bodyPercent <
       MathMax(0.0, InpDoubtfulMinBodyPercentOfRange));

   double strongClose =
      MathMax(50.0, MathMin(100.0,
                            InpDoubtfulStrongClosePercent));

   bool weakClose =
      (direction == 1)
      ? (closeLocation < strongClose)
      : (closeLocation > 100.0 - strongClose);

   if(!correctColor || wrongSideWick || weakBody || weakClose)
     {
      whyDoubtful =
         (!correctColor ? "WRONG COLOR; " : "") +
         (wrongSideWick ? "OPPOSITE WICK; " : "") +
         (weakBody ? "SMALL BODY; " : "") +
         (weakClose ? "WEAK CLOSE; " : "") +
         "Body=" + DoubleToString(body, 1) +
         " Wick=" + DoubleToString(oppositeWick, 1) +
         " Body%=" + DoubleToString(bodyPercent, 1) +
         " CloseLoc=" + DoubleToString(closeLocation, 1) + "%";

      return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool IsNextCandleConfirmationPassed(int direction,
                                    string &confirmDetails)
  {
   confirmDetails = "";

   if(direction == 0 ||
      g_doubtConfirmReferenceTime <= 0 ||
      Time[1] <= g_doubtConfirmReferenceTime)
     {
      confirmDetails = "WAIT NEXT CLOSED CANDLE";
      return(false);
     }

   double o = Open[1];
   double c = Close[1];
   double buffer = MathMax(0.0,
                           InpDoubtfulConfirmBreakBufferRaw);
   bool correctColor =
      (direction == 1) ? (c > o) : (c < o);

   double requiredClose = 0.0;

   if(direction == 1)
      requiredClose =
         InpDoubtfulConfirmMustBreakExtreme
         ? g_doubtConfirmReferenceHigh + buffer
         : g_doubtConfirmReferenceClose + buffer;
   else
      requiredClose =
         InpDoubtfulConfirmMustBreakExtreme
         ? g_doubtConfirmReferenceLow - buffer
         : g_doubtConfirmReferenceClose - buffer;

   bool priceConfirm =
      (direction == 1)
      ? (c > requiredClose)
      : (c < requiredClose);

   confirmDetails =
      "Color=" + (correctColor ? "YES" : "NO") +
      " | Close=" + DoubleToString(c, Digits) +
      " | Need=" + DoubleToString(requiredClose, Digits);

   return(correctColor && priceConfirm);
  }

//+------------------------------------------------------------------+
void StoreDoubtfulCandleReference(int direction,
                                  int shift,
                                  string reason)
  {
   g_doubtConfirmDirection      = direction;
   g_doubtConfirmReferenceTime  = Time[shift];
   g_doubtConfirmReferenceHigh  = High[shift];
   g_doubtConfirmReferenceLow   = Low[shift];
   g_doubtConfirmReferenceClose = Close[shift];
   g_doubtConfirmStatus         = "WAIT NEXT CANDLE";
   g_doubtConfirmReason         = reason;
  }

//+------------------------------------------------------------------+
bool IsDoubtfulCandleConfirmationAllowed(int direction,
      string source)
  {
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE))
      return(true);

   if(direction == 0 || Bars < 5)
      return(false);

   if(g_doubtConfirmDirection != 0 &&
      g_doubtConfirmDirection != direction)
      ResetDoubtfulCandleConfirmation("DIRECTION CHANGED");

   if(g_doubtConfirmDirection == direction &&
      g_doubtConfirmReferenceTime > 0)
     {
      string details = "";

      if(IsNextCandleConfirmationPassed(direction, details))
        {
         Print("DOUBTFUL CANDLE CONFIRMED | Direction=",
               DirectionText(direction),
               " | Reference=",
               TimeToString(g_doubtConfirmReferenceTime,
                            TIME_DATE|TIME_MINUTES),
               " | ", details,
               " | Source=", source);

         ResetDoubtfulCandleConfirmation(
            "CONFIRMED | " + details);
         return(true);
        }

      // A later candle failed confirmation. Roll the reference forward,
      // then require another next closed candle.
      if(Time[1] > g_doubtConfirmReferenceTime)
        {
         string latestReason = "";
         IsDoubtfulSignalCandle(direction, 1, latestReason);

         StoreDoubtfulCandleReference(
            direction,
            1,
            "NEXT CANDLE FAILED | " + details +
            (latestReason != "" ? " | " + latestReason : ""));
        }

      string waitMsg =
         "DOUBTFUL CANDLE WAIT | Direction=" +
         DirectionText(direction) +
         " | Ref=" +
         TimeToString(g_doubtConfirmReferenceTime,
                      TIME_DATE|TIME_MINUTES) +
         " | " + g_doubtConfirmReason +
         " | Source=" + source;

      g_lastOrderOpenReason = waitMsg;
      g_lastOrderBlockTime = TimeCurrent();
      SetLastOrderBlockDashboard(waitMsg);
      Print(waitMsg);
      return(false);
     }

   string doubtReason = "";

   if(IsDoubtfulSignalCandle(direction, 1, doubtReason))
     {
      StoreDoubtfulCandleReference(direction, 1,
                                   doubtReason);

      string blockMsg =
         "DOUBTFUL CANDLE DETECTED | WAIT NEXT CANDLE | Direction=" +
         DirectionText(direction) +
         " | " + doubtReason +
         " | Source=" + source;

      g_lastOrderOpenReason = blockMsg;
      g_lastOrderBlockTime = TimeCurrent();
      SetLastOrderBlockDashboard(blockMsg);
      Print(blockMsg);
      return(false);
     }

   g_doubtConfirmStatus = "READY";
   g_doubtConfirmReason = "LAST CANDLE STRONG";
   return(true);
  }

//+------------------------------------------------------------------+
bool IsDoubtfulCandleReadyForDashboard(int direction)
  {
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE))
      return(true);

   if(direction == 0)
      return(false);

   if(g_doubtConfirmDirection == direction &&
      g_doubtConfirmReferenceTime > 0)
     {
      string details = "";
      return(IsNextCandleConfirmationPassed(direction,
                                            details));
     }

   string reason = "";
   return(!IsDoubtfulSignalCandle(direction, 1, reason));
  }

//+------------------------------------------------------------------+
string DoubtfulCandleStatusText(int direction)
  {
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE))
      return("OFF MODE");

   if(g_doubtConfirmDirection != 0 &&
      g_doubtConfirmReferenceTime > 0)
     {
      string details = "";

      if(IsNextCandleConfirmationPassed(
            g_doubtConfirmDirection, details))
         return("CONFIRMED | " + details);

      return("WAIT " +
             DirectionText(g_doubtConfirmDirection) +
             " | " +
             StringSubstr(g_doubtConfirmReason, 0, 42));
     }

   string reason = "";

   if(IsDoubtfulSignalCandle(direction, 1, reason))
      return("DOUBTFUL | " +
             StringSubstr(reason, 0, 42));

   return("READY | LAST CANDLE STRONG");
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

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_LATE_SAR))
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

   ResetDoubtfulCandleConfirmation("SAR CYCLE RESET");
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

   ResetDoubtfulCandleConfirmation("STOPLOSS CYCLE RESET");
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
bool RegisterSARCycleOrderCreated(int direction, bool forceFirstOrderCount=false)
  {
   EnsureSARSignalOrderCycle(direction);

// The first order deliberately bypasses SAR_CYCLE. It must still be
// recorded as order #1 so every later order switches to the full profile.
   if(!forceFirstOrderCount)
     {
      if(g_sarCycleMaxOrders <= 0)
         return(false);

      if(g_sarCycleOrdersCreated >= g_sarCycleMaxOrders)
         return(false);
     }

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
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_PRICE_SIDE))
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_PROFIT_PAUSE) &&
      IsProfitProtectPauseActive())
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE) &&
      dynamicMaxOrders <= 0)
     {
      Print("ORDER BLOCKED | SAR cycle max is 0. Symbol=", Symbol(),
            " Direction=", DirectionText(direction),
            " CycleCreated=", cycleCreatedOrders,
            " Last5=", GetSARDurationSummaryText());
      DrawDashboard("SAR CYCLE BLOCK - MAX 0");
      return(false);
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE) &&
      cycleCreatedOrders >= dynamicMaxOrders)
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

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_ORDER_COOLDOWN) &&
      InpOrderCooldownSeconds > 0 &&
      TimeCurrent() - g_lastOrderTime < InpOrderCooldownSeconds)
      return(false);

   double effectiveMinGap = GetEffectiveMinPriceGap();
   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_MIN_GAP) &&
      effectiveMinGap > 0.0 &&
      !IsPriceGapValid(direction, effectiveMinGap))
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
//| Legacy pullback reason classifier                                 |
//| Pullback/micro creation is removed; this prevents old call sites  |
//| or old order reasons from breaking compilation/history handling.  |
//+------------------------------------------------------------------+
bool IsSARPullbackHalfTPReason(string reason)
  {
   return(StringFind(reason, "SAR_PULLBACK_HALF_TP") >= 0);
  }

//+------------------------------------------------------------------+
//| Repeated raw-price gap confirmation for SAR trend orders          |
//+------------------------------------------------------------------+
bool IsRepeatedPriceGapConfirmedForNormalOrder(int direction, string reason)
  {
// Legacy compatibility only. New pullback/micro order creation is removed.
   if(IsSARPullbackHalfTPReason(reason))
      return(true);

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_REPEATED_GAP))
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

   g_lastEntryAttemptDecision = "BLOCKED";
   g_lastEntryAttemptPrimary  = reason;
   g_lastEntryAttemptTime     = TimeCurrent();

   Print("ORDER BLOCKED | ", reason);
   return(false);
  }

//+------------------------------------------------------------------+
string MT4TradeErrorDescription(int err)
  {
   switch(err)
     {
      case 0:
         return("No error");
      case 1:
         return("No error returned");
      case 2:
         return("Common error");
      case 3:
         return("Invalid trade parameters");
      case 4:
         return("Trade server busy");
      case 5:
         return("Old terminal version");
      case 6:
         return("No connection");
      case 8:
         return("Too frequent requests");
      case 64:
         return("Account disabled");
      case 65:
         return("Invalid account");
      case 128:
         return("Trade timeout");
      case 129:
         return("Invalid price");
      case 130:
         return("Invalid stops");
      case 131:
         return("Invalid volume / lot size");
      case 132:
         return("Market closed");
      case 133:
         return("Trading disabled");
      case 134:
         return("Not enough money / free margin");
      case 135:
         return("Price changed");
      case 136:
         return("Off quotes");
      case 137:
         return("Broker busy");
      case 138:
         return("Requote");
      case 139:
         return("Order locked");
      case 140:
         return("Long positions only allowed");
      case 141:
         return("Too many trade requests");
      case 145:
         return("Modification denied because order too close to market");
      case 146:
         return("Trade context busy");
      case 147:
         return("Expiration denied by broker");
      case 148:
         return("Too many orders");
      case 149:
         return("Hedge prohibited");
      case 150:
         return("FIFO rule prohibited");
      case 4107:
         return("Invalid price parameter");
      case 4108:
         return("Invalid ticket");
      case 4109:
         return("Trade not allowed by EA/settings");
      case 4110:
         return("Long trades not allowed");
      case 4111:
         return("Short trades not allowed");
      case 4112:
         return("Trade is disabled by symbol/account settings");
      default:
         return("Unknown trade error");
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool BlockNormalOrderByModeProfile(string message)
  {
   g_lastOrderOpenReason = "MODE FILTER BLOCK | " + message;
   g_lastOrderBlockTime = TimeCurrent();
   SetLastOrderBlockDashboard(g_lastOrderOpenReason);
   Print(g_lastOrderOpenReason);
   return(false);
  }

//+------------------------------------------------------------------+
//| First order after SAR flip: fixed live price difference only.     |
//| Other strategy filters are deliberately bypassed.                 |
//+------------------------------------------------------------------+
bool IsFirstSAROrderAllowedByPriceDiffOnly(int direction,
      string reason)
  {
   if(!IsFirstSAROrderAfterFlip(direction))
      return(true);

   if(IsDubaiNoNewOrderHourNow())
      return(BlockNormalOrderByModeProfile(
                "FIRST ORDER | DUBAI NO-NEW HOUR | DXB=" +
                TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                " | Hours=" + InpNoNewOrderHourList +
                " | Source=" + reason));

   if(!IsFirstSAROrderPriceDiffReady(direction))
      return(BlockNormalOrderByModeProfile(
                "FIRST ORDER PRICE DIFF | " +
                FirstSAROrderPriceDiffStatusText(direction) +
                " | Source=" + reason));

// Mandatory execution safety; these are not strategy filters.
   if(!IsTradingAllowedNow())
      return(BlockNormalOrderByModeProfile(
                "FIRST ORDER | TRADING NOT ALLOWED | Source=" + reason));

   int maxPerType = InpMaxOrders;
   if(maxPerType < 1)
      maxPerType = 1;

   if(CountDirectionEntriesForCap(direction) >= maxPerType)
      return(BlockNormalOrderByModeProfile(
                "FIRST ORDER | MAX OPEN " + DirectionText(direction) +
                " " + IntegerToString(CountDirectionEntriesForCap(direction)) +
                "/" + IntegerToString(maxPerType) +
                " | Source=" + reason));

   Print("FIRST SAR ORDER PROFILE READY | Direction=",
         DirectionText(direction),
         " | ", FirstSAROrderPriceDiffStatusText(direction),
         " | Bypassed=ALL OTHER STRATEGY FILTERS",
         " | Source=", reason);

   return(true);
  }

//+------------------------------------------------------------------+
//| Final normal-order gate controlled by current market-mode profile.|
//| Recovery order functions do not call this function.               |
//+------------------------------------------------------------------+
bool IsNormalOrderAllowedByMarketModeProfile(int direction,
      string reason)
  {
   if(!IsNormalSAROrderReason(reason))
      return(true);

   UpdateAutoMarketFlowMode();
   ApplyMarketModeEntryFilterProfileState();

   if(direction == 0)
      return(BlockNormalOrderByModeProfile(
                "DIRECTION | NONE | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_AUTO_MARKET_MODE) &&
      !IsAutoMarketNewOrderAllowed(reason))
      return(BlockNormalOrderByModeProfile(
                "AUTO MARKET MODE | " + AutoMarketModeStatusText() +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM) &&
      g_pendingSARConfirmDirection != 0 &&
      !IsSARFlipConfirmationReady())
      return(BlockNormalOrderByModeProfile(
                "SAR CONFIRM | " + SARConfirmExactStatusText(direction) +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_PRICE_SIDE) &&
      !IsSARSignalPriceSideAllowed(direction, reason))
      return(BlockNormalOrderByModeProfile(
                "SAR PRICE SIDE | Direction=" +
                DirectionText(direction) + " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_REPEATED_GAP) &&
      !IsRepeatedPriceGapConfirmedForNormalOrder(direction, reason))
      return(BlockNormalOrderByModeProfile(
                "REPEATED GAP | " + CheckListRepeatedGapText(direction) +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE))
     {
      EnsureSARSignalOrderCycle(direction);
      UpdateSARCycleMaxByMomentum(direction,
                                  "Mode profile final gate");

      if(g_sarCycleMaxOrders <= 0 ||
         g_sarCycleOrdersCreated >= g_sarCycleMaxOrders)
         return(BlockNormalOrderByModeProfile(
                   "SAR CYCLE | " +
                   IntegerToString(g_sarCycleOrdersCreated) + "/" +
                   IntegerToString(g_sarCycleMaxOrders) +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_H1_TREND))
     {
      int h1Trend = GetH1TrendDirection();

      if(h1Trend == 0 ||
         direction != h1Trend)
         return(BlockNormalOrderByModeProfile(
                   "H1 TREND | Order=" + DirectionText(direction) +
                   " H1=" + DirectionText(h1Trend) +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_LATE_SAR))
     {
      string lateReason = "";

      if(IsLateSARCycleEntryDanger(direction, lateReason))
         return(BlockNormalOrderByModeProfile(
                   lateReason + " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_STRICT_SAR_SCORE))
     {
      int score = GetDynamicSARStrengthScore(direction);
      int required = GetStrictSARMinimumScore();

      if(score < required)
         return(BlockNormalOrderByModeProfile(
                   "STRICT SAR SCORE " +
                   IntegerToString(score) + "/" +
                   IntegerToString(required) +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_DOUBTFUL_CANDLE) &&
      !IsDoubtfulCandleConfirmationAllowed(
         direction, "NORMAL_PROFILE " + reason))
      return(false);

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_TRADING_ALLOWED) &&
      !IsTradingAllowedNow())
      return(BlockNormalOrderByModeProfile(
                "TRADING NOT ALLOWED | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_SPREAD))
     {
      int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);

      if(spread > InpMaxSpreadPoints)
         return(BlockNormalOrderByModeProfile(
                   "SPREAD " + IntegerToString(spread) + "/" +
                   IntegerToString(InpMaxSpreadPoints) +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EQUITY_LOCK) &&
      CheckEquityConditions())
      return(BlockNormalOrderByModeProfile(
                "EQUITY / DAILY LOCK | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_NO_NEW_HOUR) &&
      IsNoNewOrderHour())
      return(BlockNormalOrderByModeProfile(
                "NO NEW ORDER DUBAI HOUR | " + InpNoNewOrderHourList +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_PROFIT_PAUSE) &&
      IsProfitProtectPauseActive())
      return(BlockNormalOrderByModeProfile(
                "PROFIT PAUSE | " + ProfitProtectPauseStatusText() +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_OPPOSITE_PAUSE) &&
      IsOrderBlockedByOppositeDirectionProfitPause(direction, reason))
      return(false);

   if((IsMarketModeEntryFilterEnabled(DXB_FILTER_BIG_CANDLE) ||
       IsMarketModeEntryFilterEnabled(DXB_FILTER_SPIKE_WICK)) &&
      EnforceBigCandleOrderBlock(direction, "NORMAL_PROFILE " + reason))
      return(BlockNormalOrderByModeProfile(
                "BIG CANDLE / SPIKE | " +
                BigCandleExactStatusText(direction) +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_MIN_GAP))
     {
      double minGap = GetEffectiveMinPriceGap();

      if(minGap > 0.0 && !IsPriceGapValid(direction, minGap))
         return(BlockNormalOrderByModeProfile(
                   "MIN SAME-DIRECTION GAP | " +
                   MinGapExactStatusText(direction) +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_MAX_OPEN_DIR) &&
      CountDirectionEntriesForCap(direction) >= InpMaxOrders)
      return(BlockNormalOrderByModeProfile(
                "MAX OPEN DIRECTION " +
                IntegerToString(CountDirectionEntriesForCap(direction)) + "/" +
                IntegerToString(InpMaxOrders) +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_TOTAL_OPEN) &&
      InpMaxTotalOpenOrders > 0 &&
      CountAllEntriesForCap() >= InpMaxTotalOpenOrders)
      return(BlockNormalOrderByModeProfile(
                "TOTAL OPEN " +
                IntegerToString(CountAllEntriesForCap()) + "/" +
                IntegerToString(InpMaxTotalOpenOrders) +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_DYNAMIC_SAR))
     {
      string dynamicReason = "";

      if(!IsDynamicSARAllowedForNewOrder(direction,
                                         dynamicReason))
         return(BlockNormalOrderByModeProfile(
                   "DYNAMIC SAR | " + dynamicReason +
                   " | Source=" + reason));
     }

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_FLAT_MODE) &&
      DetectFlatMode())
      return(BlockNormalOrderByModeProfile(
                "FLAT MODE | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_WEAK_EXIT) &&
      g_earlySARWeakExitActive &&
      CountOrdersByDirection(direction) > 0)
      return(BlockNormalOrderByModeProfile(
                "EARLY SAR WEAK EXIT | " +
                g_earlySARWeakExitReason +
                " | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_EARLY_REVERSE) &&
      g_sarPausedByEarly)
      return(BlockNormalOrderByModeProfile(
                "EARLY REVERSE PAUSE | Source=" + reason));

   if(IsMarketModeEntryFilterEnabled(DXB_FILTER_ORDER_COOLDOWN) &&
      InpOrderCooldownSeconds > 0 &&
      g_lastOrderTime > 0 &&
      TimeCurrent() - g_lastOrderTime < InpOrderCooldownSeconds)
      return(BlockNormalOrderByModeProfile(
                "ORDER COOLDOWN | Left=" +
                IntegerToString(
                   InpOrderCooldownSeconds -
                   (int)(TimeCurrent() - g_lastOrderTime)) +
                "s | Source=" + reason));

   return(true);
  }

//+------------------------------------------------------------------+
bool OpenMarketOrder(int direction, string reason)
  {
   g_lastOrderOpenReason = "CHECKING | " + reason;

   RefreshRates();

   if(direction != 0)
      EnsureSARSignalOrderCycle(direction);

   if(IsDubaiNoNewOrderHourNow())
      return BlockOrder(
                "DUBAI NO-NEW HOUR HARD LOCK | DXB=" +
                TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                " | Hours=" + InpNoNewOrderHourList +
                " | Source=" + reason);

   bool isFirstSAROrder = IsFirstSAROrderAfterFlip(direction);

   RefreshNormalEntryDiagnosticSnapshot(direction, reason);
   CaptureLastEntryAttempt("CHECKING");

   if(direction == 0)
     {
      g_lastEntryAttemptDecision = "BLOCKED";
      g_lastEntryAttemptPrimary  = "DIRECTION | NONE";
      return BlockOrder("Direction is 0 | Source=" + reason);
     }

   if(!IsFinalNormalDirectionStillValid(
         direction,
         "OpenMarketOrder START | " + reason))
      return(false);

// Hard per-type cap: BUY and SELL are counted independently.
// Example InpMaxOrders=1: one SELL may coexist with one BUY.
   if(IsDirectionOrderCapReached(direction, "OpenMarketOrder START | " + reason))
      return(false);

   bool entryProfileAllowed = isFirstSAROrder
                              ? IsFirstSAROrderAllowedByPriceDiffOnly(direction, reason)
                              : IsNormalOrderAllowedByMarketModeProfile(direction, reason);

   if(!entryProfileAllowed)
     {
      RefreshNormalEntryDiagnosticSnapshot(direction, reason);
      CaptureLastEntryAttempt("BLOCKED");
      return(false);
     }

// Rebuild immediately after all final gates passed.
   RefreshNormalEntryDiagnosticSnapshot(direction, reason);
   CaptureLastEntryAttempt("APPROVED FOR ORDERSEND");

   if(!IsPendingEntryAllowedForCurrentSAR(direction,
                                          "OpenMarketOrder " + reason))
      return BlockOrder("Pending entry waiting current SAR confirmation | Direction=" +
                        DirectionText(direction) +
                        " | Source=" + reason);

   int type = InpUsePendingOrderEntries
              ? (direction == 1 ? OP_BUYSTOP : OP_SELLSTOP)
              : (direction == 1 ? OP_BUY : OP_SELL);

   double price = InpUsePendingOrderEntries
                  ? BuildPendingOrderPrice(direction, true)
                  : (direction == 1 ? Ask : Bid);

   if(!isFirstSAROrder &&
      IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_PRICE_SIDE) &&
      !IsSARSignalPriceSideAllowed(direction, reason))
      return BlockOrder("SAR signal price side filter blocked | Direction=" +
                        DirectionText(direction) +
                        " | SignalPrice=" + DoubleToString(g_activeSARSignalChangePrice, Digits) +
                        " | Bid=" + DoubleToString(Bid, Digits) +
                        " | Ask=" + DoubleToString(Ask, Digits) +
                        " | Source=" + reason);

   if(!isFirstSAROrder &&
      IsMarketModeEntryFilterEnabled(DXB_FILTER_REPEATED_GAP) &&
      !IsRepeatedPriceGapConfirmedForNormalOrder(direction, reason))
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
   price = InpUsePendingOrderEntries
           ? BuildPendingOrderPrice(direction, true)
           : ((direction == 1) ? Ask : Bid);

   EnsureSARSignalOrderCycle(direction);
   UpdateSARCycleMaxByMomentum(direction, "OrderSend last check");

   if(!isFirstSAROrder &&
      IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CYCLE) &&
      (g_sarCycleMaxOrders <= 0 ||
       g_sarCycleOrdersCreated >= g_sarCycleMaxOrders))
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

// Final time recheck immediately before the atomic filter audit/OrderSend.
   if(IsDubaiNoNewOrderHourNow())
      return BlockOrder(
                "OrderSend cancelled last check | DUBAI NO-NEW HOUR | DXB=" +
                TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                " | Hours=" + InpNoNewOrderHourList +
                " | Source=" + reason);

// FINAL ATOMIC FILTER SNAPSHOT:
// The dashboard result and actual OrderSend decision must match.
   RefreshRates();
   UpdateAutoMarketFlowMode();
   ApplyMarketModeEntryFilterProfileState();

   if(!IsFinalNormalDirectionStillValid(
         direction,
         "OpenMarketOrder FINAL | " + reason))
      return(false);

// Recheck the requested BUY/SELL side immediately before OrderSend.
// The opposite open side is deliberately ignored.
   if(IsDirectionOrderCapReached(direction, "OpenMarketOrder FINAL | " + reason))
      return(false);

   RefreshNormalEntryDiagnosticSnapshot(
      direction,
      "FINAL ORDERSEND | " + reason);

   if(g_entryDiagBlockedCount > 0)
     {
      CaptureLastEntryAttempt("FINAL FILTER BLOCK");

      return BlockOrder(
                "FINAL FILTER AUDIT BLOCK | Primary=" +
                g_entryDiagPrimaryBlock +
                " | All=" + g_entryDiagBlockerList +
                " | Source=" + reason);
     }

// Last possible check immediately before the broker request.
   if(IsDubaiNoNewOrderHourNow())
      return BlockOrder(
                "OrderSend aborted at broker boundary | DUBAI NO-NEW HOUR | DXB=" +
                TimeToString(GetDubaiTime(), TIME_DATE|TIME_MINUTES) +
                " | Hours=" + InpNoNewOrderHourList +
                " | Source=" + reason);

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

      g_lastOrderOpenReason =
         BuildOrderSendFailMessage(err,
                                   type,
                                   lot,
                                   price,
                                   sl,
                                   reason);

      g_lastAuditSendResult =
         "FAILED " + IntegerToString(err) +
         " | " + MT4TradeErrorDescription(err);

      g_lastEntryAttemptDecision = "ORDERSEND FAILED";
      g_lastEntryAttemptPrimary  = g_lastAuditSendResult;
      g_lastEntryAttemptTime     = TimeCurrent();

      Print(g_lastOrderOpenReason);

      ResetLastError();
      return(false);
     }

   g_lastOrderTime = TimeCurrent();
   MarkOpenedOrderOnChart(ticket, direction, orderComment, TimeCurrent(), price);
   NotifyCreatedOrderTicket(ticket); // pending placement is ignored until activation
   if(reason == "SAR_FLIP_V2LAST")
     {
      g_lastSARFlipV2LastOrderBarTime = Time[0];
      g_lastSARFlipV2LastOrderTime    = TimeCurrent();
     }
   g_lastConfirmedOrderPrice = price;
   g_lastConfirmedOrderTime  = TimeCurrent();
   ResetDoubtfulCandleConfirmation("ORDER OPENED");

// Register only normal SAR cycle orders. Recovery orders use OpenRecoveryOrder() and are independent.
   RegisterSARCycleOrderCreated(direction, isFirstSAROrder);

   if(isFirstSAROrder)
      ResetSARFlipConfirmation();

// A pending placement is not yet an active BUY/SELL market order.
// Do not start delayed SAR-close tracking merely because it was placed.
   if(!InpUsePendingOrderEntries &&
      InpUseDelayedSARChangeClose &&
      InpResetSARCloseCounterOnNewOrder)
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

   g_lastOrderOpenReason = (InpUsePendingOrderEntries
                            ? "PENDING SUCCESS | Ticket="
                            : "SUCCESS | Ticket=") + IntegerToString(ticket) +
                           " | Direction=" + DirectionText(direction) +
                           " | Lot=" + DoubleToString(lot, 2) +
                           " | Price=" + DoubleToString(price, Digits) +
                           " | Source=" + reason +
                           " | Profile=" + (isFirstSAROrder
                                 ? "FIRST PRICE DIFF ONLY"
                                 : "FULL FILTERS") +
                           " | Comment=" + orderComment;

   g_lastEntryAttemptDecision = InpUsePendingOrderEntries
                                ? "PENDING PLACED"
                                : "OPENED";
   g_lastEntryAttemptPrimary  = "NONE";
   g_lastEntryAttemptBlockers = "NONE";
   g_lastEntryAttemptBlocked  = 0;
   g_lastEntryAttemptTime     = TimeCurrent();

   CaptureOpenedOrderAudit(ticket,
                           direction,
                           reason,
                           price,
                           lot);

   Print(InpUsePendingOrderEntries ? "Pending placed " : "Opened ",
         DirectionText(direction), " ticket=", ticket,
         " lot=", DoubleToString(lot, 2),
         " reason=", reason,
         " comment=", orderComment,
         " | EntryProfile=", (isFirstSAROrder ? "FIRST PRICE DIFF ONLY" : "FULL FILTERS"),
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

//+------------------------------------------------------------------+
//|                                                                  |
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

   int pendingDirection = (type == OP_BUY) ? 1 : -1;
   DeletePendingOrdersByDirection(pendingDirection,
                                  reason + " | SIDE CLOSE",
                                  false);
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

//+------------------------------------------------------------------+
//|                                                                  |
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

//+------------------------------------------------------------------+
//| LEFT SIDE ORDER CREATION CHECKLIST DASHBOARD                     |
//| Shows the real normal-order gates as YES/NO before OrderSend.     |
//+------------------------------------------------------------------+
int g_leftDashRow = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetChecklistDirection()
  {
   if(g_activeSARDirection != 0)
      return(g_activeSARDirection);

   if(g_pendingSARConfirmDirection != 0)
      return(g_pendingSARConfirmDirection);

   return(GetSARDotDirection(1));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string YesNo(bool ok)
  {
   return(ok ? "YES" : "NO");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color YesNoColor(bool ok)
  {
   return(ok ? clrLime : clrOrangeRed);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LeftChecklistRow(string title,string value,bool ok,string extra="")
  {
   string rowName = "DXB_LEFT_CHK_ROW_" + IntegerToString(g_leftDashRow);
   string text = StringSubstr(title + "                         ", 0, 24) + " : " + value;
   if(extra != "")
      text = text + " " + extra;

   DrawLeftLabel(rowName,text,10,34 + (g_leftDashRow * 17),YesNoColor(ok),9);
   g_leftDashRow++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//| Left-side dashboard: important settings used before new orders    |
//+------------------------------------------------------------------+
void DrawLeftImportantOrderSettings(int direction)
  {
   LeftChecklistInfo("----- IMPORTANT ORDER SETTINGS -----", "", clrYellow);

   LeftChecklistInfo("Filter Profile",
                     g_autoMarketModeText + " | " +
                     IntegerToString(CountEnabledMarketModeEntryFilters()) +
                     "/" + IntegerToString(DXB_FILTER_COUNT) +
                     " enabled",
                     MarketFlowModeColor());

   LeftChecklistInfo("Lot / Slippage",
                     "Lot " + DoubleToString(InpFixedLot, 2) +
                     " | Slip " + IntegerToString(InpSlippage),
                     clrWhite);

   LeftChecklistInfo("Spread Limit",
                     IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) +
                     "/" + IntegerToString(InpMaxSpreadPoints) + " points",
                     ((int)MarketInfo(Symbol(), MODE_SPREAD) <= InpMaxSpreadPoints) ? clrLime : clrOrangeRed);

   LeftChecklistInfo("Max Orders / Type",
                     "BUY " + IntegerToString(CountOrdersByDirection(1)) +
                     "/" + IntegerToString(InpMaxOrders) +
                     " | SELL " + IntegerToString(CountOrdersByDirection(-1)) +
                     "/" + IntegerToString(InpMaxOrders) +
                     " | Cycle " + IntegerToString(g_sarCycleOrdersCreated) +
                     "/" + IntegerToString(g_sarCycleMaxOrders),
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

   LeftChecklistInfo("Recovery Loss Return",
                     InpUseRecoveryLossComebackTrigger
                     ? "Touch -$" +
                     DoubleToString(MathAbs(InpRecoveryLossArmUSD), 2) +
                     " | Improve +$" +
                     DoubleToString(MathAbs(InpRecoveryLossComebackUSD), 2)
                     : "OFF",
                     InpUseRecoveryLossComebackTrigger ? clrAqua : clrSilver);

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
                     " | OPPOSITE ONLY" +
                     " | " + DoubleToString(InpBigCandleRawDifference, 0) +
                     " | " + IntegerToString(InpBigCandlePauseMinutes) + "m",
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListSARConfirmationReady()
  {
   if(IsFirstSAROrderAfterFlip(g_activeSARDirection))
      return(IsFirstSAROrderPriceDiffReady(g_activeSARDirection));

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_CONFIRM))
      return(true);
   if(g_pendingSARConfirmDirection == 0)
      return(true);
   return(IsSARFlipConfirmationReady());
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListH1Allowed(int direction)
  {
   if(direction == 0)
      return(false);

   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_H1_TREND))
      return(true);

   int trend = GetH1TrendDirection();

   if(trend == 0)
      return(false);

// Strict H1 rule: momentum cannot override an opposite H1 trend.
   return(direction == trend);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListCycleAllowed(int direction)
  {
   if(direction == 0)
      return(false);
   EnsureSARSignalOrderCycle(direction);
   return(g_sarCycleMaxOrders > 0 && g_sarCycleOrdersCreated < g_sarCycleMaxOrders);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListMaxOpenAllowed(int direction)
  {
   if(direction == 0)
      return(false);
   return(CountDirectionEntriesForCap(direction) < InpMaxOrders);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListTotalOpenAllowed()
  {
   if(InpMaxTotalOpenOrders <= 0)
      return(true);
   return(CountAllEntriesForCap() < InpMaxTotalOpenOrders);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListMinGapAllowed(int direction)
  {
   if(direction == 0)
      return(false);

   double effectiveMinGap = GetEffectiveMinPriceGap();
   if(effectiveMinGap <= 0.0)
      return(true);

   return(IsPriceGapValid(direction, effectiveMinGap));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListSARSideAllowed(int direction)
  {
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_SAR_PRICE_SIDE))
      return(true);
   if(direction == 0 || g_activeSARSignalChangePrice <= 0.0)
      return(false);

   double diff = GetSARSignalSidePriceDiff(direction);
   return(diff >= MathMax(0.0, InpSARSignalPriceSideMinGap));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckListRepeatedGapAllowed(int direction)
  {
   if(!IsMarketModeEntryFilterEnabled(DXB_FILTER_REPEATED_GAP))
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//| NORMAL ORDER FILTER DIAGNOSTIC ENGINE                            |
//+------------------------------------------------------------------+
void AppendEntryAuditToken(string &target, string token)
  {
   if(token == "")
      return;

   if(target == "" || target == "NONE")
      target = token;
   else
      target += ", " + token;
  }

//+------------------------------------------------------------------+
void ResetEntryDiagnosticSnapshot(int direction, string source)
  {
   g_entryDiagEnabledCount  = 0;
   g_entryDiagPassedCount   = 0;
   g_entryDiagBlockedCount  = 0;
   g_entryDiagDisabledCount = 0;
   g_entryDiagDirection     = direction;
   g_entryDiagTime          = TimeCurrent();
   g_entryDiagDecision      = "WAIT";
   g_entryDiagPrimaryBlock  = "NONE";
   g_entryDiagBlockerList   = "NONE";
   g_entryDiagEnabledList   = "NONE";
   g_entryDiagDisabledList  = "NONE";
   g_entryDiagSource        = source;
   g_entryDiagFirstOrderProfile = false;
   g_entryDiagProfileText      = "FULL FILTER PROFILE";

   for(int i = 0; i < DXB_FILTER_COUNT; i++)
     {
      g_entryDiagEnabled[i] = false;
      g_entryDiagPassed[i]  = false;
      g_entryDiagDetail[i]  = "";
     }
  }

//+------------------------------------------------------------------+
void SetEntryDiagnosticFilter(int filterId,
                              bool rawConditionPassed,
                              string detail)
  {
   if(filterId < 0 || filterId >= DXB_FILTER_COUNT)
      return;

   bool enabled = g_entryDiagFirstOrderProfile
                  ? FirstSAROrderFilterCase(filterId)
                  : IsMarketModeEntryFilterEnabled(filterId);
   bool passed  = (!enabled || rawConditionPassed);
   string token = EntryFilterToken(filterId);

   g_entryDiagEnabled[filterId] = enabled;
   g_entryDiagPassed[filterId]  = passed;
   g_entryDiagDetail[filterId]  = detail;

   if(!enabled)
     {
      g_entryDiagDisabledCount++;
      AppendEntryAuditToken(g_entryDiagDisabledList, token);
      return;
     }

   g_entryDiagEnabledCount++;
   AppendEntryAuditToken(g_entryDiagEnabledList, token);

   if(rawConditionPassed)
     {
      g_entryDiagPassedCount++;
      return;
     }

   g_entryDiagBlockedCount++;
   AppendEntryAuditToken(g_entryDiagBlockerList, token);

   if(g_entryDiagPrimaryBlock == "NONE")
     {
      g_entryDiagPrimaryBlock = token;

      if(detail != "")
         g_entryDiagPrimaryBlock += " | " + detail;
     }
  }

//+------------------------------------------------------------------+
void FinalizeEntryDiagnosticSnapshot()
  {
   if(g_entryDiagBlockedCount > 0)
      g_entryDiagDecision = "BLOCKED";
   else
      g_entryDiagDecision = "READY TO OPEN";

   if(g_entryDiagBlockerList == "")
      g_entryDiagBlockerList = "NONE";

   if(g_entryDiagEnabledList == "")
      g_entryDiagEnabledList = "NONE";

   if(g_entryDiagDisabledList == "")
      g_entryDiagDisabledList = "NONE";
  }

//+------------------------------------------------------------------+
string EntryDiagnosticAgeText(datetime eventTime)
  {
   if(eventTime <= 0)
      return("NEVER");

   int secondsAgo = (int)MathMax(0, TimeCurrent() - eventTime);

   if(secondsAgo < 60)
      return(IntegerToString(secondsAgo) + "s ago");

   return(IntegerToString(secondsAgo / 60) + "m ago");
  }

//+------------------------------------------------------------------+
string EntryDiagnosticLine(string value, int start, int length)
  {
   if(value == "")
      return("");

   if(start >= StringLen(value))
      return("");

   return(StringSubstr(value, start, length));
  }

//+------------------------------------------------------------------+
//| Return one display segment without silently losing later text.   |
//| segmentIndex starts at 0.                                        |
//+------------------------------------------------------------------+
string EntryAuditSegment(string value,
                         int segmentIndex,
                         int charsPerLine)
  {
   if(value == "")
      return("");

   charsPerLine = MathMax(25, charsPerLine);

   int start = segmentIndex * charsPerLine;

   if(start >= StringLen(value))
      return("");

   return(StringSubstr(value, start, charsPerLine));
  }

//+------------------------------------------------------------------+
//| Dedicated status snapshot for SAR-cycle order #1.                 |
//+------------------------------------------------------------------+
void RefreshFirstSAROrderDiagnosticSnapshot(int direction,
      string source)
  {
   ResetEntryDiagnosticSnapshot(direction, source);
   g_entryDiagFirstOrderProfile = true;
   g_entryDiagProfileText = "FIRST ORDER: PRICE DIFF + DUBAI TIME";

   bool directionOk = (direction != 0 &&
                       direction == g_activeSARDirection);
   bool priceDiffOk = IsFirstSAROrderPriceDiffReady(direction);
   bool tradingOk   = CheckListTradingAllowed();
   bool maxOpenOk   = CheckListMaxOpenAllowed(direction);
   bool noNewHourOk = !IsDubaiNoNewOrderHourNow();
   int maxPerType = InpMaxOrders;
   if(maxPerType < 1)
      maxPerType = 1;

   for(int filterId = 0; filterId < DXB_FILTER_COUNT; filterId++)
     {
      bool rawPassed = true;
      string detail = "BYPASSED FOR FIRST ORDER";

      if(filterId == DXB_FILTER_DIRECTION)
        {
         rawPassed = directionOk;
         detail = DirectionText(direction);
        }
      else
         if(filterId == DXB_FILTER_SAR_CONFIRM)
           {
            rawPassed = priceDiffOk;
            detail = FirstSAROrderPriceDiffStatusText(direction);
           }
         else
            if(filterId == DXB_FILTER_TRADING_ALLOWED)
              {
               rawPassed = tradingOk;
               detail = DashboardTradePermissionText();
              }
            else
               if(filterId == DXB_FILTER_MAX_OPEN_DIR)
                 {
                  rawPassed = maxOpenOk;
                  detail = IntegerToString(CountDirectionEntriesForCap(direction)) +
                           "/" + IntegerToString(maxPerType);
                 }
               else
                  if(filterId == DXB_FILTER_NO_NEW_HOUR)
                    {
                     rawPassed = noNewHourOk;
                     detail = "DXB=" + TimeToString(GetDubaiTime(), TIME_MINUTES) +
                              " | Hours=" + InpNoNewOrderHourList;
                    }

      SetEntryDiagnosticFilter(filterId, rawPassed, detail);
     }

   FinalizeEntryDiagnosticSnapshot();
  }

//+------------------------------------------------------------------+
//| Build a current snapshot independently of OrderSend.             |
//| This is used before a real order attempt and for the top panel.   |
//+------------------------------------------------------------------+
void RefreshNormalEntryDiagnosticSnapshot(int direction,
      string source)
  {
   RefreshRates();
   UpdateAutoMarketFlowMode();
   ApplyMarketModeEntryFilterProfileState();

   if(IsFirstSAROrderAfterFlip(direction))
     {
      RefreshFirstSAROrderDiagnosticSnapshot(direction, source);
      return;
     }

   ResetEntryDiagnosticSnapshot(direction, source);
   g_entryDiagFirstOrderProfile = false;
   g_entryDiagProfileText = "ORDER 2+: FULL MODE FILTERS";

   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   string lateReason = "";
   string dynamicReason = "";

   bool rawDirection = (direction != 0 &&
                        direction == g_activeSARDirection);
   bool rawSARConfirm = CheckListSARConfirmationReady();
   bool rawSARSide = CheckListSARSideAllowed(direction);
   bool rawRepeatedGap = CheckListRepeatedGapAllowed(direction);
   bool rawCycle = CheckListCycleAllowed(direction);
   bool rawH1 = CheckListH1Allowed(direction);
   bool rawLate = !IsLateSARCycleEntryDanger(direction, lateReason);

   int strictRequired = GetStrictSARMinimumScore();
   int score = (direction != 0)
               ? GetDynamicSARStrengthScore(direction)
               : 0;
   bool rawStrict = (score >= strictRequired);
   bool rawDoubtful = IsDoubtfulCandleReadyForDashboard(direction);

   bool rawTrading = CheckListTradingAllowed();
   bool rawSpread = (spread <= InpMaxSpreadPoints);
   bool rawEquity =
      (!g_equityProtectionHit &&
       !(g_dailyProfitLock && InpPauseAfterProfitTarget));
   bool rawNoHour =
      (!InpUseNoNewOrderHours ||
       !IsConfiguredNoNewOrderHour(TimeHour(GetDubaiTime())));
   bool rawProfit = !IsProfitProtectPauseActive();
   bool rawOpposite =
      (!IsOppositeDirectionProfitPauseActive() ||
       direction != g_oppositePausedDirection);

   string bigDirectionReason = "";
   bool rawBig =
      !IsBigCandleOrderBlockedForDirection(
         direction,
         bigDirectionReason);
   bool rawSpike = !IsSpikeWickPauseActive();
   bool rawMinGap = CheckListMinGapAllowed(direction);
   bool rawMaxOpen = CheckListMaxOpenAllowed(direction);
   bool rawTotal = CheckListTotalOpenAllowed();
   bool rawAutoMarket =
      IsAutoMarketNewOrderAllowed("ENTRY_DIAGNOSTIC");

   bool rawDynamic = false;
   if(direction != 0)
      rawDynamic =
         IsDynamicSARAllowedForNewOrder(direction,
                                        dynamicReason);

   bool rawFlat = !DetectFlatMode();

   bool rawEarlyWeak =
      !(g_earlySARWeakExitActive &&
        direction != 0 &&
        CountOrdersByDirection(direction) > 0);

   bool rawEarlyReverse = !g_sarPausedByEarly;

   bool rawCooldown =
      (InpOrderCooldownSeconds <= 0 ||
       g_lastOrderTime <= 0 ||
       TimeCurrent() - g_lastOrderTime >=
       InpOrderCooldownSeconds);

   SetEntryDiagnosticFilter(
      DXB_FILTER_DIRECTION,
      rawDirection,
      DirectionExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_SAR_CONFIRM,
      rawSARConfirm,
      SARConfirmExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_SAR_PRICE_SIDE,
      rawSARSide,
      SARSignalSideStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_REPEATED_GAP,
      rawRepeatedGap,
      CheckListRepeatedGapText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_SAR_CYCLE,
      rawCycle,
      SARCycleExactStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_H1_TREND,
      rawH1,
      H1TrendExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_LATE_SAR,
      rawLate,
      rawLate ? "SAFE" : lateReason);

   SetEntryDiagnosticFilter(
      DXB_FILTER_STRICT_SAR_SCORE,
      rawStrict,
      IntegerToString(score) + "/" +
      IntegerToString(strictRequired));

   SetEntryDiagnosticFilter(
      DXB_FILTER_DOUBTFUL_CANDLE,
      rawDoubtful,
      DoubtfulCandleStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_TRADING_ALLOWED,
      rawTrading,
      DashboardTradePermissionText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_SPREAD,
      rawSpread,
      IntegerToString(spread) + "/" +
      IntegerToString(InpMaxSpreadPoints));

   SetEntryDiagnosticFilter(
      DXB_FILTER_EQUITY_LOCK,
      rawEquity,
      EquityLockExactStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_NO_NEW_HOUR,
      rawNoHour,
      NoNewOrderHoursStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_PROFIT_PAUSE,
      rawProfit,
      ProfitProtectPauseStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_OPPOSITE_PAUSE,
      rawOpposite,
      OppositeDirectionProfitPauseStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_BIG_CANDLE,
      rawBig,
      BigCandleExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_SPIKE_WICK,
      rawSpike,
      SpikeWickPauseStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_MIN_GAP,
      rawMinGap,
      MinGapExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_MAX_OPEN_DIR,
      rawMaxOpen,
      MaxOpenDirectionExactStatusText(direction));

   SetEntryDiagnosticFilter(
      DXB_FILTER_TOTAL_OPEN,
      rawTotal,
      TotalOpenExactStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_AUTO_MARKET_MODE,
      rawAutoMarket,
      AutoMarketModeStatusText());

   SetEntryDiagnosticFilter(
      DXB_FILTER_DYNAMIC_SAR,
      rawDynamic,
      DynamicSARExactStatusText(dynamicReason));

   SetEntryDiagnosticFilter(
      DXB_FILTER_FLAT_MODE,
      rawFlat,
      FlatModeExactStatusText(rawFlat));

   SetEntryDiagnosticFilter(
      DXB_FILTER_EARLY_WEAK_EXIT,
      rawEarlyWeak,
      g_earlySARWeakExitReason);

   SetEntryDiagnosticFilter(
      DXB_FILTER_EARLY_REVERSE,
      rawEarlyReverse,
      g_sarPausedByEarly ? "PAUSED" : "CLEAR");

   SetEntryDiagnosticFilter(
      DXB_FILTER_ORDER_COOLDOWN,
      rawCooldown,
      CooldownExactStatusText());

   FinalizeEntryDiagnosticSnapshot();
  }

//+------------------------------------------------------------------+
void CaptureLastEntryAttempt(string decision)
  {
   g_lastEntryAttemptTime      = TimeCurrent();
   g_lastEntryAttemptDirection = g_entryDiagDirection;
   g_lastEntryAttemptSource    = g_entryDiagSource;
   g_lastEntryAttemptDecision  = decision;
   g_lastEntryAttemptPrimary   = g_entryDiagPrimaryBlock;
   g_lastEntryAttemptBlockers  = g_entryDiagBlockerList;
   g_lastEntryAttemptEnabled   = g_entryDiagEnabledCount;
   g_lastEntryAttemptPassed    = g_entryDiagPassedCount;
   g_lastEntryAttemptBlocked   = g_entryDiagBlockedCount;
  }

//+------------------------------------------------------------------+
void CaptureOpenedOrderAudit(int ticket,
                             int direction,
                             string source,
                             double price,
                             double lot)
  {
   g_lastAuditOpenedTicket    = ticket;
   g_lastAuditOpenedTime      = TimeCurrent();
   g_lastAuditOpenedDirection = direction;
   g_lastAuditOpenedPrice     = price;
   g_lastAuditOpenedLot       = lot;
   g_lastAuditOpenedSource    = source;
   g_lastAuditOpenedMode      = g_autoMarketModeText;
   g_lastAuditOpenedProfile   = g_entryDiagProfileText;
   g_lastAuditOpenedFilters   = g_entryDiagEnabledList;
   g_lastAuditDisabledFilters = g_entryDiagDisabledList;
   g_lastAuditOpenedEnabled   = g_entryDiagEnabledCount;
   g_lastAuditOpenedPassed    = g_entryDiagPassedCount;
   g_lastAuditSendResult      =
      "SUCCESS #" + IntegerToString(ticket) +
      " | " + DirectionText(direction) +
      " | " + DoubleToString(price, Digits);

   Print("ORDER FILTER AUDIT | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | Source=", source,
         " | Mode=", g_autoMarketModeText,
         " | Profile=", g_entryDiagProfileText,
         " | Passed=", g_entryDiagPassedCount,
         "/", g_entryDiagEnabledCount,
         " | EnabledFilters=", g_entryDiagEnabledList,
         " | DisabledFilters=", g_entryDiagDisabledList);
  }

//+------------------------------------------------------------------+
//| PROFESSIONAL DASHBOARD HELPERS                                   |
//+------------------------------------------------------------------+
int g_rightDashRow = 0;
int g_recoveryDashRow = 0;
int g_guardDashRow = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string PadTitle(string title,int len=22)
  {
   return(StringSubstr(title + "                              ",0,len));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LeftProRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,20) + " : " + value;
   DrawCornerLabel("DXB_PRO_LEFT_"+IntegerToString(g_leftDashRow),
                   text,
                   CORNER_LEFT_UPPER,
                   10,
                   45+(g_leftDashRow*16),
                   clrText,
                   8);
   g_leftDashRow++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LeftProCheck(string title,bool ok,string extra="")
  {
   string value = YesNo(ok);
   if(extra != "")
      value = value + " " + extra;
   LeftProRow(title,value,YesNoColor(ok));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RecoveryRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,22) + " : " + value;

   DrawCornerLabel("DXB_PRO_REC_"+
                   IntegerToString(g_recoveryDashRow),
                   text,
                   CORNER_LEFT_LOWER,
                   570,
                   186-(g_recoveryDashRow*18),
                   clrText,
                   8);

   g_recoveryDashRow++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RightProRow(string title,string value,color clrText=clrWhite)
  {
   string text = PadTitle(title,20) + " : " + value;
   DrawCornerLabel("DXB_PRO_RIGHT_"+IntegerToString(g_rightDashRow),text,CORNER_RIGHT_UPPER,315,310+(g_rightDashRow*16),clrText,8);
   g_rightDashRow++;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
color DirectionColor(int direction)
  {
   if(direction == 1)
      return(clrLime);
   if(direction == -1)
      return(clrRed);
   return(clrSilver);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string OnOff(bool v)
  {
   return(v ? "ON" : "OFF");
  }

//+------------------------------------------------------------------+
//| CLEAR DASHBOARD: exact live-value helpers                         |
//+------------------------------------------------------------------+
string EntryFilterDisplayName(int filterId)
  {
   if(filterId == DXB_FILTER_DIRECTION)
      return("Direction");
   if(filterId == DXB_FILTER_SAR_CONFIRM)
      return("SAR Confirm");
   if(filterId == DXB_FILTER_SAR_PRICE_SIDE)
      return("SAR Price Side");
   if(filterId == DXB_FILTER_REPEATED_GAP)
      return("Repeated Gap");
   if(filterId == DXB_FILTER_SAR_CYCLE)
      return("SAR Cycle");
   if(filterId == DXB_FILTER_H1_TREND)
      return("H1 Trend");
   if(filterId == DXB_FILTER_LATE_SAR)
      return("Late SAR");
   if(filterId == DXB_FILTER_STRICT_SAR_SCORE)
      return("Strict SAR Score");
   if(filterId == DXB_FILTER_DOUBTFUL_CANDLE)
      return("Doubtful Candle");
   if(filterId == DXB_FILTER_TRADING_ALLOWED)
      return("Trading Allowed");
   if(filterId == DXB_FILTER_SPREAD)
      return("Spread");
   if(filterId == DXB_FILTER_EQUITY_LOCK)
      return("Equity / Daily Lock");
   if(filterId == DXB_FILTER_NO_NEW_HOUR)
      return("Dubai No-New Hour");
   if(filterId == DXB_FILTER_PROFIT_PAUSE)
      return("Profit Pause");
   if(filterId == DXB_FILTER_OPPOSITE_PAUSE)
      return("Opposite Pause");
   if(filterId == DXB_FILTER_BIG_CANDLE)
      return("Big / Last3 Move");
   if(filterId == DXB_FILTER_SPIKE_WICK)
      return("Spike / Wick");
   if(filterId == DXB_FILTER_MIN_GAP)
      return("Min Same-Dir Gap");
   if(filterId == DXB_FILTER_MAX_OPEN_DIR)
      return("Max Open Direction");
   if(filterId == DXB_FILTER_TOTAL_OPEN)
      return("Total Open Cap");
   if(filterId == DXB_FILTER_AUTO_MARKET_MODE)
      return("Auto Market Mode");
   if(filterId == DXB_FILTER_DYNAMIC_SAR)
      return("Dynamic SAR");
   if(filterId == DXB_FILTER_FLAT_MODE)
      return("Flat Mode");
   if(filterId == DXB_FILTER_EARLY_WEAK_EXIT)
      return("Early Weak Exit");
   if(filterId == DXB_FILTER_EARLY_REVERSE)
      return("Early Reverse");
   if(filterId == DXB_FILTER_ORDER_COOLDOWN)
      return("Order Cooldown");
   return(EntryFilterToken(filterId));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string SARConfirmExactStatusText(int direction)
  {
   if(IsFirstSAROrderAfterFlip(direction))
      return(FirstSAROrderPriceDiffStatusText(direction));

   if(g_pendingSARConfirmDirection == 0 ||
      g_pendingSARConfirmTime <= 0)
      return("No pending flip confirmation");

   double currentDiff = GetSARConfirmCurrentPriceDiff();
   double requiredDiff = MathMax(0.0, InpSARConfirmPriceDiff);

   if(InpUseDynamicSAREngine)
      requiredDiff = GetDynamicSARRequiredConfirmDiff();

   int elapsed = GetSARConfirmElapsedSeconds();
   int window = MathMax(0, InpSARConfirmMinutes) * 60;

   return("Diff " + DoubleToString(currentDiff,1) +
          "/" + DoubleToString(requiredDiff,1) +
          " | Window " + IntegerToString(elapsed) +
          "/" + IntegerToString(window) + "s");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DirectionExactStatusText(int direction)
  {
   return("Candidate " + DirectionText(direction) +
          " / SAR " + DirectionText(g_activeSARDirection));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string H1TrendExactStatusText(int direction)
  {
   int trend = GetH1TrendDirection();
   return("Candidate " + DirectionText(direction) +
          " / H1 " + DirectionText(trend));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string SARCycleExactStatusText()
  {
   int remaining = MathMax(0,
                           g_sarCycleMaxOrders -
                           g_sarCycleOrdersCreated);

   return("Created " + IntegerToString(g_sarCycleOrdersCreated) +
          "/" + IntegerToString(g_sarCycleMaxOrders) +
          " | Remaining " + IntegerToString(remaining));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetNearestSameDirectionOrderGapRaw(int direction,
      int &nearestTicket)
  {
   nearestTicket = -1;

   if(direction == 0)
      return(-1.0);

   int type = (direction == 1) ? OP_BUY : OP_SELL;
   double livePrice = (direction == 1) ? Ask : Bid;
   double nearestGap = 1.0e100;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != type)
         continue;

      double gap = MathAbs(livePrice - OrderOpenPrice());

      if(gap < nearestGap)
        {
         nearestGap = gap;
         nearestTicket = OrderTicket();
        }
     }

   if(nearestTicket < 0)
      return(-1.0);

   return(nearestGap);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MinGapExactStatusText(int direction)
  {
   double required = GetEffectiveMinPriceGap();

   if(required <= 0.0)
      return("OFF | Required 0");

   int nearestTicket = -1;
   double liveGap =
      GetNearestSameDirectionOrderGapRaw(direction,
                                         nearestTicket);

   if(liveGap < 0.0)
      return("No existing " + DirectionText(direction) +
             " order | Required " +
             DoubleToString(required,1));

   return("Gap " + DoubleToString(liveGap,1) +
          "/" + DoubleToString(required,1) +
          " | Nearest #" + IntegerToString(nearestTicket));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string BigCandleExactStatusText(int direction)
  {
   double maxSingleMove = 0.0;

   for(int shift = 0; shift <= 2 && shift < Bars; shift++)
     {
      double move = MathAbs(High[shift] - Low[shift]);
      if(move > maxSingleMove)
         maxSingleMove = move;
     }

   double last3Move = GetLastNCandlesRawMove(3);
   string reason = "";
   bool blocked =
      IsBigCandleOrderBlockedForDirection(direction,
                                          reason);

   return((blocked ? "BLOCK" : "ALLOW") +
          " | Single " + DoubleToString(maxSingleMove,1) +
          "/" + DoubleToString(InpBigCandleRawDifference,1) +
          " | Last3 " + DoubleToString(last3Move,1) +
          "/" + DoubleToString(InpLast3CandlesRawDifference,1) +
          (IsBigCandlePauseActive()
           ? " | " + BigCandlePauseStatusText()
           : ""));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string EquityLockExactStatusText()
  {
   return("Equity $" + DoubleToString(AccountEquity(),2) +
          " | Stop $" + DoubleToString(g_lossStopEquityLevel,2) +
          " | Daily " +
          (g_dailyProfitLock ? "LOCKED" : "CLEAR"));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MaxOpenDirectionExactStatusText(int direction)
  {
   return(DirectionText(direction) + " " +
          IntegerToString(CountDirectionEntriesForCap(direction)) +
          "/" + IntegerToString(InpMaxOrders));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TotalOpenExactStatusText()
  {
   if(InpMaxTotalOpenOrders <= 0)
      return("OFF | Open " + IntegerToString(CountAllEntriesForCap()));

   return(IntegerToString(CountAllEntriesForCap()) +
          "/" + IntegerToString(InpMaxTotalOpenOrders));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string DynamicSARExactStatusText(string reason)
  {
   string text = "Score " + IntegerToString(g_dynamicSARScore) +
                 " | ATR " + DoubleToString(g_dynamicSARATR,1) +
                 " | ADX " + DoubleToString(g_dynamicSARADX,1) +
                 " | Dot " + DoubleToString(g_dynamicSARDotDistance,1);

   if(reason != "")
      text += " | " + StringSubstr(reason,0,34);

   return(text);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string FlatModeExactStatusText(bool clear)
  {
   return((clear ? "CLEAR" : "FLAT BLOCK") +
          " | Lookback " +
          IntegerToString(InpFlatLookbackCandles));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string CooldownExactStatusText()
  {
   if(InpOrderCooldownSeconds <= 0)
      return("OFF | Required 0s");

   int elapsed = (g_lastOrderTime <= 0)
                 ? InpOrderCooldownSeconds
                 : (int)MathMax(0,
                                TimeCurrent() - g_lastOrderTime);

   return("Elapsed " + IntegerToString(elapsed) +
          "/" + IntegerToString(InpOrderCooldownSeconds) + "s");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string EntryDecisionHeadline()
  {
   if(g_entryDiagBlockedCount > 0)
      return("BLOCKED | " + g_entryDiagPrimaryBlock);

   return("READY TO OPEN");
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawRecoveryChecklistPanel(int direction)
  {
   bool enabled = InpUseRecoveryGapOrders;
   bool matchOk =
      (!InpRecoveryGapMustMatchSARDirection ||
       direction == g_activeSARDirection);
   bool countOk =
      (CountRecoveryGapOrdersByDirection(1) <
       InpMaxRecoveryGapOrdersPerSide ||
       CountRecoveryGapOrdersByDirection(-1) <
       InpMaxRecoveryGapOrdersPerSide);
   bool pending = (g_pendingRecoveryGapDirection != 0);
   string recoveryBigReason = "";
   bool bigOk =
      !IsBigCandleOrderBlockedForDirection(
         direction,
         recoveryBigReason);
   bool spikeOk = !IsSpikeWickPauseActive();
   bool allowed =
      enabled && matchOk && countOk && bigOk && spikeOk;

   DrawCornerPanel("DXB_RECOVERY_PANEL",
                   CORNER_LEFT_LOWER,
                   560,10,400,260,
                   clrBlack,clrDimGray);

   DrawCornerLabel("DXB_RECOVERY_TITLE",
                   "RECOVERY ORDER STATUS",
                   CORNER_LEFT_LOWER,
                   570,248,
                   clrYellow,9);

   g_recoveryDashRow = 0;

   RecoveryRow("Recovery Enabled",
               enabled ? "ON" : "OFF",
               enabled ? clrLime : clrSilver);

   RecoveryRow("Recovery Decision",
               allowed ? "READY / WAIT GAP" : "BLOCKED",
               allowed ? clrLime : clrOrangeRed);

   RecoveryRow("Direction / SAR",
               DirectionText(direction) + " / " +
               DirectionText(g_activeSARDirection),
               matchOk ? clrLime : clrOrangeRed);

   RecoveryRow("Required Gap",
               DoubleToString(InpRecoveryGapRawPrice,0),
               clrAqua);

   RecoveryRow("Recovery Count B/S",
               IntegerToString(
                  CountRecoveryGapOrdersByDirection(1)) +
               "/" +
               IntegerToString(
                  CountRecoveryGapOrdersByDirection(-1)) +
               " | Max " +
               IntegerToString(
                  InpMaxRecoveryGapOrdersPerSide),
               countOk ? clrLime : clrOrangeRed);

   RecoveryRow("Pending",
               pending
               ? DirectionText(g_pendingRecoveryGapDirection) +
               " | Gap " +
               DoubleToString(g_pendingRecoveryGapMove,0)
               : "NONE",
               pending ? clrYellow : clrSilver);

   RecoveryRow("Pending Reason",
               StringSubstr(g_pendingRecoveryGapReason,0,52),
               pending ? clrYellow : clrSilver);

   RecoveryRow("Big / Spike",
               (bigOk
                ? "BIG ALLOW"
                : "BIG OPP BLOCK") +
               " / " +
               (spikeOk
                ? "SPIKE CLEAR"
                : "SPIKE BLOCK"),
               (bigOk && spikeOk)
               ? clrLime
               : clrOrangeRed);

   RecoveryRow("Big Direction Rule",
               StringSubstr(
                  recoveryBigReason,
                  0,
                  58),
               bigOk ? clrAqua : clrOrangeRed);

   RecoveryRow("Strong Opp Move",
               OnOff(InpStopRecoveryOnStrongOppMove) +
               " | Gap " +
               DoubleToString(
                  InpStrongOppMoveBlockRecoveryGap,0),
               clrYellow);

   RecoveryRow("Last Recovery Audit",
               StringSubstr(g_lastRecoveryAudit,0,58),
               StringFind(g_lastRecoveryAudit,"OPENED") == 0
               ? clrAqua
               : (g_lastRecoveryAudit == "NONE"
                  ? clrSilver
                  : clrOrangeRed));
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LeftProModeCheck(string title,
                      int filterId,
                      bool conditionOk,
                      string extra="")
  {
   bool enabled = IsMarketModeEntryFilterEnabled(filterId);
   string state = EntryFilterModeStateText(filterId);

   if(!enabled)
     {
      string offValue = "OFF | " + state;

      if(extra != "")
         offValue += " | " + extra;

      LeftProRow(title, offValue, clrSilver);
      return;
     }

   string detail = conditionOk
                   ? "PASS | " + state
                   : "BLOCK | " + state;

   if(extra != "")
      detail += " | " + extra;

   LeftProRow(title,
              detail,
              conditionOk ? clrLime : clrOrangeRed);
  }

//+------------------------------------------------------------------+
void DrawTopCenterOrderAuditPanel()
  {
   int chartWidth =
      (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);

   int panelX = 560;
   int panelW = chartWidth - 1230;

   if(panelW < 430)
      panelW = 430;
   if(panelW > 850)
      panelW = 850;

   int charsPerLine = MathMax(48,
                              MathMin(115,
                                      (panelW - 25) / 7));

   color decisionColor =
      (g_entryDiagBlockedCount > 0)
      ? clrOrangeRed
      : clrLime;

   DrawCornerPanel("DXB_ENTRY_AUDIT_PANEL",
                   CORNER_LEFT_UPPER,
                   panelX,48,panelW,170,
                   clrBlack,decisionColor);

   DrawCornerLabel("DXB_ENTRY_AUDIT_TITLE",
                   "NEW ORDER GATE - EXACT LIVE REASON",
                   CORNER_LEFT_UPPER,
                   panelX+10,53,
                   clrYellow,10);

   string decision =
      (g_entryDiagBlockedCount > 0
       ? "BLOCKED"
       : "READY TO OPEN") +
      " | " + DirectionText(g_entryDiagDirection) +
      " | " + g_entryDiagProfileText +
      " | Pass " + IntegerToString(g_entryDiagPassedCount) +
      "/" + IntegerToString(g_entryDiagEnabledCount) +
      " | Fail " + IntegerToString(g_entryDiagBlockedCount);

   DrawCornerLabel("DXB_ENTRY_AUDIT_NOW1",
                   EntryAuditSegment(decision,0,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,73,
                   decisionColor,10);
   DrawCornerLabel("DXB_ENTRY_AUDIT_NOW2",
                   EntryAuditSegment(decision,1,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,85,
                   decisionColor,9);

   string primary = "WHY: " + g_entryDiagPrimaryBlock;

   DrawCornerLabel("DXB_ENTRY_AUDIT_PRIMARY1",
                   EntryAuditSegment(primary,0,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,101,
                   decisionColor,9);
   DrawCornerLabel("DXB_ENTRY_AUDIT_PRIMARY2",
                   EntryAuditSegment(primary,1,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,113,
                   decisionColor,9);

   string modeLine = "MODE: " + AutoMarketModeStatusText();

   DrawCornerLabel("DXB_ENTRY_AUDIT_BLOCK1",
                   EntryAuditSegment(modeLine,0,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,131,
                   MarketFlowModeColor(),8);
   DrawCornerLabel("DXB_ENTRY_AUDIT_BLOCK2",
                   EntryAuditSegment(modeLine,1,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,143,
                   MarketFlowModeColor(),8);
   DrawCornerLabel("DXB_ENTRY_AUDIT_BLOCK3",
                   EntryAuditSegment(modeLine,2,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,155,
                   MarketFlowModeColor(),8);

   string allBlockers =
      "ALL BLOCKERS: " + g_entryDiagBlockerList;

   DrawCornerLabel("DXB_ENTRY_AUDIT_ATTEMPT1",
                   EntryAuditSegment(allBlockers,0,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,171,
                   g_entryDiagBlockedCount > 0
                   ? clrOrangeRed
                   : clrSilver,8);
   DrawCornerLabel("DXB_ENTRY_AUDIT_ATTEMPT2",
                   EntryAuditSegment(allBlockers,1,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,183,
                   g_entryDiagBlockedCount > 0
                   ? clrOrangeRed
                   : clrSilver,8);

   string lastAttempt =
      "LAST ATTEMPT: " + g_lastEntryAttemptDecision +
      " | " + EntryDiagnosticAgeText(g_lastEntryAttemptTime) +
      " | " + g_lastEntryAttemptPrimary;

   DrawCornerLabel("DXB_ENTRY_AUDIT_OPENED1",
                   EntryAuditSegment(lastAttempt,0,charsPerLine),
                   CORNER_LEFT_UPPER,
                   panelX+10,197,
                   clrAqua,8);

// Clear labels used by the older, larger audit panel.
   DrawCornerLabel("DXB_ENTRY_AUDIT_OPENED2","",
                   CORNER_LEFT_UPPER,panelX+10,197,clrSilver,8);
   DrawCornerLabel("DXB_ENTRY_AUDIT_COUNTS1","",
                   CORNER_LEFT_UPPER,panelX+10,197,clrSilver,8);
   DrawCornerLabel("DXB_ENTRY_AUDIT_COUNTS2","",
                   CORNER_LEFT_UPPER,panelX+10,197,clrSilver,8);
  }

//+------------------------------------------------------------------+
void ClearLeftProfessionalChecklistRows()
  {
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i);
      if(StringFind(name, "DXB_PRO_LEFT_") == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| Compact, truthful dashboard for the first order after SAR flip.   |
//+------------------------------------------------------------------+
void DrawFirstSAROrderCreationChecklist(string mainStatus,
                                        int direction)
  {
   RefreshFirstSAROrderDiagnosticSnapshot(direction,
                                          "LIVE FIRST ORDER");

   bool allOk = (g_entryDiagBlockedCount == 0);

   DrawTopCenterOrderAuditPanel();

   DrawCornerPanel("DXB_LEFT_CHK_PANEL",
                   CORNER_LEFT_UPPER,
                   5,15,400,710,
                   clrBlack,clrDimGray);

   DrawCornerLabel("DXB_LEFT_CHK_TITLE",
                   "FIRST SAR ORDER - EXACT ENTRY CHECK",
                   CORNER_LEFT_UPPER,
                   10,22,clrYellow,10);

   ClearLeftProfessionalChecklistRows();
   g_leftDashRow = 0;

   LeftProRow("NEW ORDER",
              allOk ? "READY TO OPEN" : "BLOCKED",
              allOk ? clrLime : clrOrangeRed);

   LeftProRow("PRIMARY REASON",
              StringSubstr(g_entryDiagPrimaryBlock,0,62),
              allOk ? clrLime : clrOrangeRed);

   LeftProRow("Candidate / SAR",
              DirectionExactStatusText(direction),
              DirectionColor(direction));

   LeftProRow("Market Mode",
              StringSubstr(AutoMarketModeStatusText(),0,62),
              MarketFlowModeColor());

   LeftProRow("Mode Effect",
              "BYPASSED BY FIRST-ORDER PROFILE",
              clrYellow);

   LeftProRow("Profile",
              "PRICE DIFF + 3 SAFETY CHECKS",
              clrAqua);

   LeftProRow("Active / Bypassed",
              IntegerToString(g_entryDiagEnabledCount) +
              " ACTIVE / " +
              IntegerToString(g_entryDiagDisabledCount) +
              " BYPASSED",
              clrAqua);

   LeftProRow("Runtime Status",
              StringSubstr(mainStatus,0,62),
              clrWhite);

   LeftProRow("--- ACTIVE FIRST-ORDER CHECKS ---","",clrDimGray);

   for(int filterId = 0; filterId < DXB_FILTER_COUNT; filterId++)
     {
      if(!g_entryDiagEnabled[filterId])
         continue;

      bool passed = g_entryDiagPassed[filterId];
      string value = (passed ? "PASS | " : "BLOCK | ") +
                     g_entryDiagDetail[filterId];

      LeftProRow(EntryFilterDisplayName(filterId),
                 StringSubstr(value,0,62),
                 passed ? clrLime : clrOrangeRed);
     }

   LeftProRow("--- BYPASSED STRATEGY FILTERS ---","",clrDimGray);
   LeftProRow("Bypassed 1",
              EntryAuditSegment(g_entryDiagDisabledList,0,62),
              clrSilver);
   LeftProRow("Bypassed 2",
              EntryAuditSegment(g_entryDiagDisabledList,1,62),
              clrSilver);
   LeftProRow("Bypassed 3",
              EntryAuditSegment(g_entryDiagDisabledList,2,62),
              clrSilver);

   LeftProRow("IMPORTANT",
              "MIXED/DANGER/HOURS/SCORE ARE BYPASSED HERE",
              clrYellow);

   LeftProRow("Next Order",
              allOk
              ? "ALLOWED NOW"
              : "WAIT: " +
              StringSubstr(g_entryDiagPrimaryBlock,0,48),
              allOk ? clrLime : clrOrangeRed);

   DrawRecoveryChecklistPanel(direction);
  }

//+------------------------------------------------------------------+
void DrawLeftOrderCreationChecklist(string mainStatus)
  {
   RefreshRates();
   UpdateAutoMarketFlowMode();
   ApplyMarketModeEntryFilterProfileState();

   int direction = GetChecklistDirection();
   EnsureSARSignalOrderCycle(direction);

   if(IsFirstSAROrderAfterFlip(direction))
     {
      DrawFirstSAROrderCreationChecklist(mainStatus,
                                         direction);
      return;
     }

   RefreshNormalEntryDiagnosticSnapshot(direction,
                                        "LIVE DASHBOARD");

   bool allOk = (g_entryDiagBlockedCount == 0);

   DrawTopCenterOrderAuditPanel();

   DrawCornerPanel("DXB_LEFT_CHK_PANEL",
                   CORNER_LEFT_UPPER,
                   5,15,400,900,
                   clrBlack,clrDimGray);

   DrawCornerLabel("DXB_LEFT_CHK_TITLE",
                   "NEW ORDER DECISION - LIVE / REQUIRED VALUES",
                   CORNER_LEFT_UPPER,
                   10,22,clrYellow,10);

   ClearLeftProfessionalChecklistRows();
   g_leftDashRow = 0;

   LeftProRow("NEW ORDER",
              allOk
              ? "READY TO OPEN"
              : "BLOCKED BY " +
              IntegerToString(g_entryDiagBlockedCount) +
              " FILTER(S)",
              allOk ? clrLime : clrOrangeRed);

   LeftProRow("PRIMARY REASON",
              StringSubstr(g_entryDiagPrimaryBlock,0,62),
              allOk ? clrLime : clrOrangeRed);

   LeftProRow("ALL BLOCKERS",
              StringSubstr(g_entryDiagBlockerList,0,62),
              allOk ? clrSilver : clrOrangeRed);

   LeftProRow("Candidate / SAR",
              DirectionExactStatusText(direction),
              DirectionColor(direction));

   LeftProRow("MARKET MODE",
              g_autoMarketModeText +
              (IsAutoMarketTradingPaused()
               ? " | BLOCK ALL NEW ORDERS"
               : " | ALLOW NEW ORDERS"),
              MarketFlowModeColor());

   LeftProRow("Mode Exact",
              StringSubstr(AutoMarketModeStatusText(),0,62),
              MarketFlowModeColor());

   LeftProRow("Profile",
              g_entryDiagProfileText +
              " | " +
              IntegerToString(g_entryDiagEnabledCount) +
              " ON / " +
              IntegerToString(g_entryDiagDisabledCount) +
              " OFF",
              clrAqua);

   LeftProRow("Passed / Failed",
              IntegerToString(g_entryDiagPassedCount) +
              " / " + IntegerToString(g_entryDiagBlockedCount),
              allOk ? clrLime : clrOrangeRed);

   LeftProRow("Runtime Status",
              StringSubstr(mainStatus,0,62),
              clrWhite);

   LeftProRow("Last Runtime Block",
              StringSubstr(g_lastOrderOpenReason,0,62),
              g_lastOrderOpenReason == "WAIT ORDER"
              ? clrSilver : clrOrange);

   LeftProRow("--- ACTIVE FILTERS: LIVE / REQUIRED ---","",clrDimGray);

   for(int filterId = 0; filterId < DXB_FILTER_COUNT; filterId++)
     {
      if(!g_entryDiagEnabled[filterId])
         continue;

      bool passed = g_entryDiagPassed[filterId];
      string value = (passed ? "PASS | " : "BLOCK | ") +
                     g_entryDiagDetail[filterId];

      LeftProRow(EntryFilterDisplayName(filterId),
                 StringSubstr(value,0,62),
                 passed ? clrLime : clrOrangeRed);
     }

   LeftProRow("--- DISABLED / BYPASSED FILTERS ---","",clrDimGray);
   LeftProRow("Disabled 1",
              EntryAuditSegment(g_entryDiagDisabledList,0,62),
              clrSilver);
   LeftProRow("Disabled 2",
              EntryAuditSegment(g_entryDiagDisabledList,1,62),
              clrSilver);
   LeftProRow("Disabled 3",
              EntryAuditSegment(g_entryDiagDisabledList,2,62),
              clrSilver);

   LeftProRow("Last Close",
              StringSubstr(g_lastOrderCloseMessage,0,62),
              g_lastOrderCloseMessage == "NO CLOSE YET"
              ? clrSilver : clrAqua);

   LeftProRow("NEXT ORDER",
              allOk
              ? "ALLOWED NOW"
              : "WAIT: " +
              StringSubstr(g_entryDiagPrimaryBlock,0,48),
              allOk ? clrLime : clrOrangeRed);

   DrawRecoveryChecklistPanel(direction);
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//STRONG SAR SCORE ADDED

//+------------------------------------------------------------------+
//| True when the MT4 AutoTrading / Expert Advisor switch is ON.      |
//+------------------------------------------------------------------+
bool IsDashboardLiveModeEnabled()
  {
   if(IsTesting())
      return(false);

   return(IsExpertEnabled());
  }

//+------------------------------------------------------------------+
string DashboardLiveModeText()
  {
   if(IsTesting())
      return("STRATEGY TESTER");

   if(IsDashboardLiveModeEnabled())
      return("DASHBOARD LIVE");

   return("LIVE MODE DISABLED");
  }

//+------------------------------------------------------------------+
color DashboardLiveModeColor()
  {
   if(IsTesting())
      return(clrAqua);

   if(IsDashboardLiveModeEnabled())
      return(clrLime);

   return(clrRed);
  }

//+------------------------------------------------------------------+
string DashboardTradePermissionText()
  {
   if(IsTesting())
      return("TESTER MODE");

   if(!IsExpertEnabled())
      return("AUTOTRADING OFF");

   if(IsTradeContextBusy())
      return("LIVE | TRADE CONTEXT BUSY");

   if(!IsTradeAllowed())
      return("LIVE | TRADING NOT ALLOWED");

   return("LIVE | READY");
  }

//+------------------------------------------------------------------+
color DashboardTradePermissionColor()
  {
   if(IsTesting())
      return(clrAqua);

   if(!IsExpertEnabled())
      return(clrRed);

   if(IsTradeContextBusy() || !IsTradeAllowed())
      return(clrOrangeRed);

   return(clrLime);
  }

//+------------------------------------------------------------------+
void DrawDashboard(string status)
  {
   DrawCornerPanel("DXB_RIGHT_SETTINGS_PANEL",
                   CORNER_RIGHT_UPPER,
                   325,280,320,680,
                   clrBlack,clrDimGray);

   string liveModeText = DashboardLiveModeText();
   color liveModeColor = DashboardLiveModeColor();

// Large top-center warning/confirmation banner.
   DrawCornerPanel("DXB_LIVE_MODE_BANNER_PANEL",
                   CORNER_LEFT_UPPER,
                   360,5,310,36,
                   clrBlack,liveModeColor);

   DrawCornerLabel("DXB_LIVE_MODE_BANNER",
                   liveModeText,
                   CORNER_LEFT_UPPER,
                   410,13,
                   liveModeColor,
                   13);

   DrawCornerLabel("DXB_RIGHT_SETTINGS_TITLE",
                   liveModeText + " | VERSION 1.45",
                   CORNER_RIGHT_UPPER,
                   300,287,
                   liveModeColor,
                   11);

   g_rightDashRow = 0;

   RightProRow("LIVE MODE",
               liveModeText,
               liveModeColor);

   RightProRow("Trade Permission",
               DashboardTradePermissionText(),
               DashboardTradePermissionColor());

   RightProRow("EA Status",
               StringSubstr(status,0,38),
               clrYellow);
   RightProRow("NEW ORDER GATE",
               g_entryDiagBlockedCount > 0
               ? "BLOCKED | " + StringSubstr(g_entryDiagPrimaryBlock,0,25)
               : "READY TO OPEN",
               g_entryDiagBlockedCount > 0 ? clrOrangeRed : clrLime);
   RightProRow("MAJOR MODE",
               g_autoMarketModeText +
               (IsAutoMarketTradingPaused() ? " | BLOCK" : " | ALLOW"),
               MarketFlowModeColor());
   RightProRow("--- TRADING ---","",clrDimGray);
   RightProRow("Lot Size",DoubleToString(InpFixedLot,2),clrWhite);
   RightProRow("Slippage",IntegerToString(InpSlippage),clrWhite);
   RightProRow("Spread Limit",IntegerToString((int)MarketInfo(Symbol(),MODE_SPREAD))+" / "+IntegerToString(InpMaxSpreadPoints),((int)MarketInfo(Symbol(),MODE_SPREAD)<=InpMaxSpreadPoints) ? clrLime : clrRed);
   RightProRow("Basket TP Base","$"+DoubleToString(InpBasketProfitUSD,2),clrLime);
   RightProRow("Dynamic Basket TP",
               InpUseDynamicBasketProfitBooking
               ? "ON | X LADDER + DD EXIT"
               : "OFF | FIXED TP",
               InpUseDynamicBasketProfitBooking ? clrAqua : clrSilver);
   RightProRow("Drawdown Comeback",
               (InpUseDynamicBasketProfitBooking &&
                InpUseDynamicBasketDrawdownComebackTP)
               ? "ON | -$" +
               DoubleToString(InpDynamicBasketDrawdownStepUSD,2) +
               " STEPS"
               : "OFF",
               (InpUseDynamicBasketProfitBooking &&
                InpUseDynamicBasketDrawdownComebackTP) ? clrYellow : clrSilver);
   RightProRow("Dynamic BUY",
               InpUseDynamicBasketProfitBooking
               ? DynamicBasketProfitDirectionStatusText(1)
               : "OFF",
               InpUseDynamicBasketProfitBooking ? clrLime : clrSilver);
   RightProRow("Dynamic SELL",
               InpUseDynamicBasketProfitBooking
               ? DynamicBasketProfitDirectionStatusText(-1)
               : "OFF",
               InpUseDynamicBasketProfitBooking ? clrOrangeRed : clrSilver);
   RightProRow("Server Profit SL",
               InpUseServerSideProfitLock
               ? "ON | ARM $" +
               DoubleToString(GetDynamicBasketMinimumArmUSD(),2) +
               " => FLOOR $" +
               DoubleToString(GetDynamicBasketMinimumCloseUSD(),2) +
               " / AIM ~$" +
               DoubleToString(
                  GetServerSideDesiredNetProfitUSD(
                     GetDynamicBasketMinimumCloseUSD()),2)
               : "OFF",
               InpUseServerSideProfitLock ? clrAqua : clrSilver);
   RightProRow("Broker Lock BUY",
               ServerSideProfitLockStatusText(1),
               g_buyServerLockOK ? clrLime :
               (InpUseServerSideProfitLock ? clrYellow : clrSilver));
   RightProRow("Broker Lock SELL",
               ServerSideProfitLockStatusText(-1),
               g_sellServerLockOK ? clrLime :
               (InpUseServerSideProfitLock ? clrYellow : clrSilver));
   RightProRow("Mixed Mode TP",
               IsMixedModeHalfBasketTPActive()
               ? "ACTIVE | BASE/2 = $" +
               DoubleToString(
                  GetMixedModeBasketProfitTargetUSD(),2)
               : "AUTO | BASE/2",
               IsMixedModeHalfBasketTPActive()
               ? clrAqua
               : clrYellow);

   int basketTPSARScore =
      GetCurrentSARScoreForBasketTP();

   RightProRow("Low Score TP",
               InpUseLowSARScoreHalfBasketTP
               ? (IsLowSARScoreHalfBasketTPActive()
                  ? "ACTIVE | Score " +
                  IntegerToString(basketTPSARScore) +
                  "<=" +
                  IntegerToString(
                     InpSARScoreHalfBasketTPMax) +
                  " | BASE/2"
                  : "ARMED | Score " +
                  IntegerToString(basketTPSARScore) +
                  " / Max " +
                  IntegerToString(
                     InpSARScoreHalfBasketTPMax))
               : "OFF",
               IsLowSARScoreHalfBasketTPActive()
               ? clrAqua
               : (InpUseLowSARScoreHalfBasketTP
                  ? clrYellow
                  : clrSilver));

   RightProRow("Basket TP Rule",
               InpUseDynamicBasketProfitBooking
               ? "DYNAMIC X LADDER"
               : (IsFixedHalfBasketTPActive()
                  ? GetReducedBasketTPReasonText(
                     g_activeSARDirection)
                  : "NORMAL TP"),
               InpUseDynamicBasketProfitBooking
               ? clrAqua
               : (IsFixedHalfBasketTPActive()
                  ? clrAqua
                  : clrLime));

   RightProRow("Basket TP Live",
               InpUseDynamicBasketProfitBooking
               ? "PRE $" + DoubleToString(GetDynamicBasketMinimumArmUSD(),2) +
               "->$" + DoubleToString(GetDynamicBasketMinimumCloseUSD(),2) +
               " | X" + GetDynamicBasketLevelXText(1) + " $" +
               DoubleToString(GetDynamicBasketTargetUSDByLevel(1),2) +
               " | X" + GetDynamicBasketLevelXText(2) + " $" +
               DoubleToString(GetDynamicBasketTargetUSDByLevel(2),2) +
               " | X" + GetDynamicBasketLevelXText(3) + " $" +
               DoubleToString(GetDynamicBasketTargetUSDByLevel(3),2)
               : ("$" +
                  DoubleToString(
                     GetBasketProfitTargetUSD(),2) +
                  (InpUseSimpleSideBasketCloseOnly
                   ? " SIMPLE"
                   : "")),
               clrYellow);
   RightProRow("Old Opposite TP",
               InpUseSARFlipOppositeBasketHalfTP
               ? "$"+DoubleToString(MathMax(0.01,
                                    InpBasketProfitUSD * MathMax(0.0,
                                          MathMin(1.0, InpSARFlipOppositeBasketTPMultiplier))),2)
               : "OFF",
               InpUseSARFlipOppositeBasketHalfTP ? clrAqua : clrSilver);
   RightProRow("Aged Basket TP",
               InpUseBasketHalfTPAfterMinutes
               ? IntegerToString(MathMax(1, InpBasketHalfTPAfterMinutes)) +
               "m -> $" +
               DoubleToString(MathMax(0.01,
                                      InpBasketProfitUSD * MathMax(0.0,
                                            MathMin(1.0, InpBasketHalfTPAfterMinutesMultiplier))),2)
               : "OFF",
               InpUseBasketHalfTPAfterMinutes ? clrAqua : clrSilver);
   RightProRow("TP Time Decay",BasketProfitTimeDecayStatusText(),InpUseBasketProfitTimeDecay ? clrAqua : clrSilver);
   RightProRow("Basket SL Live","$"+DoubleToString(GetEffectiveBasketStopLossUSD(),2) + (InpUseSimpleSideBasketCloseOnly ? " SIMPLE" : ""),clrRed);
   RightProRow("Market Mode",AutoMarketModeStatusText(),MarketFlowModeColor());
   RightProRow("Opposite Pause",OppositeDirectionProfitPauseStatusText(),IsOppositeDirectionProfitPauseActive() ? clrOrangeRed : clrSilver);
   RightProRow("Ind Profit Protect",OnOff(InpUseIndividualProfitProtect),InpUseIndividualProfitProtect ? clrLime : clrSilver);
   RightProRow("Basket Protect",OnOff(InpUseBasketProfitProtect),InpUseBasketProfitProtect ? clrLime : clrSilver);

   RightProRow("--- RECOVERY ---","",clrDimGray);
   RightProRow("Recovery Gap",DoubleToString(InpRecoveryGapRawPrice,0),clrAqua);
   RightProRow("Loss Comeback",
               InpUseRecoveryLossComebackTrigger
               ? "-$" + DoubleToString(MathAbs(InpRecoveryLossArmUSD),2) +
               " +$" + DoubleToString(MathAbs(InpRecoveryLossComebackUSD),2)
               : "OFF",
               InpUseRecoveryLossComebackTrigger ? clrAqua : clrSilver);
   RightProRow("BUY Loss State",
               RecoveryLossComebackStatusText(1),
               g_buyRecoveryLossComebackArmed ? clrYellow : clrSilver);
   RightProRow("SELL Loss State",
               RecoveryLossComebackStatusText(-1),
               g_sellRecoveryLossComebackArmed ? clrYellow : clrSilver);
   RightProRow("Recovery Lot",DoubleToString(InpRecoveryGapLot,2),clrAqua);
   RightProRow("Max Recovery",IntegerToString(InpMaxRecoveryGapOrdersPerSide),clrAqua);
   RightProRow("Opp Move Block",OnOff(InpStopRecoveryOnStrongOppMove)+" | "+DoubleToString(InpStrongOppMoveBlockRecoveryGap,0),clrYellow);
   RightProRow("Mode Recovery",IsAutoMarketRecoveryAllowed() ? "ALLOW" : "BLOCK",IsAutoMarketRecoveryAllowed() ? clrLime : clrRed);
   RightProRow("Mode Auxiliary","MICRO CREATION REMOVED",clrSilver);

   RightProRow("--- SAR SETTINGS ---","",clrDimGray);
   RightProRow("SAR Direction",DirectionText(g_activeSARDirection),DirectionColor(g_activeSARDirection));
   RightProRow("Confirm Gap",DoubleToString(InpSARConfirmPriceDiff,0),clrAqua);
   RightProRow("Confirm Minutes",IntegerToString(InpSARConfirmMinutes),clrAqua);
   RightProRow("Continuous Gap",DoubleToString(InpContinuousOrderPriceGap,0),clrAqua);
   RightProRow("Gap Wait",IntegerToString(InpContinuousOrderGapMinutes)+"m",clrAqua);
   RightProRow("Signal Side Gap",DoubleToString(InpSARSignalPriceSideMinGap,0),clrAqua);
   RightProRow("SAR Cycle",IntegerToString(g_sarCycleOrdersCreated)+"/"+IntegerToString(g_sarCycleMaxOrders),g_sarCycleOrdersCreated>=g_sarCycleMaxOrders ? clrOrangeRed : clrLime);

   RightProRow("--- PROTECTION ---","",clrDimGray);
   RightProRow("Big Candle",
               DoubleToString(InpBigCandleRawDifference,0) +
               " | OPPOSITE ONLY | Pause " +
               IntegerToString(InpBigCandlePauseMinutes) +
               "m",
               clrYellow);
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
   DrawCornerLabel("DXB_ACC_9",PadTitle("Open Orders",20)+" : "+IntegerToString(CountAllEntriesForCap())+" / "+IntegerToString(InpMaxTotalOpenOrders),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),CountAllEntriesForCap()>=InpMaxTotalOpenOrders && InpMaxTotalOpenOrders>0 ? clrOrangeRed : clrLime,8);
   DrawCornerLabel("DXB_ACC_10",PadTitle("SAR Max Rule",20)+" : Max "+IntegerToString(GetDynamicSARMaxOrders()),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetDynamicSARMaxOrders()<=0 ? clrRed : clrYellow,8);
   DrawCornerLabel("DXB_ACC_11",PadTitle("Next Reset",20)+" : "+FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);

   g_rightDashRow = startRow;

   string dashboardLogPrefix = DashboardLiveModeText();

   Print(dashboardLogPrefix,
         " | TradePermission=", DashboardTradePermissionText(),
         " | Status=", status,
         " | SAR=", DirectionText(g_activeSARDirection),
         " | Early=", DirectionText(g_earlyDirection),
         " | SAR Paused=", (g_sarPausedByEarly ? "YES" : "NO"),
         " | Flat Mode=", (g_flatMode ? "YES" : "NO"),
         " | Spike/Wick=", SpikeWickPauseStatusText(),
         " | EquityCycle=#", IntegerToString(g_equityCycleNumber),
         " | NextReset=", FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()));
  }

//tested

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
