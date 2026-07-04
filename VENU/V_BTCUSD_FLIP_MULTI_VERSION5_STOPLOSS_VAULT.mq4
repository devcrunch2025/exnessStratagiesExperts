//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA_Strict_2345_FreshBoot_V192_PauseReasonNotifications.mq4                  |
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
#property version   "1.92"

//======================== INPUTS ====================================
string InpEAName                  = "DXB Version 5 - SAR Confirm 50 in 5 Min";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01; // fallback lot when dynamic balance lot is OFF

//================ OPENING-BALANCE DYNAMIC LOT ======================
// Lot is frozen from the current equity-cycle opening balance:
//   $10 opening balance -> 0.01 lot
//   $20 opening balance -> 0.02 lot
//   $50 opening balance -> 0.05 lot
// The broker lot step/min/max are respected. All configured trade-money
// targets and stop values can scale by the same lot multiplier so their RAW
// price distance remains comparable when the lot increases.
bool   InpUseDynamicBalanceLot              = true;
double InpDynamicLotBalanceStepUSD           = 10.0;
double InpDynamicLotPerBalanceStep           = 0.01;
double InpDynamicLotMinimum                  = 0.01;
double InpDynamicLotMaximum                  = 0.00; // 0 = broker maximum
bool   InpScaleTradeMoneyWithDynamicLot   = true;
int    InpMaxOrders               = 3;     // per-side entry cap: 1 base SAR order + up to 2 continuation add-ons
double InpMinGapWhenMaxOrdersMoreThanOne = 100.0; // when InpMaxOrders > 1, enforce at least this raw price gap between same-direction open orders

#define DXB_HARD_MAX_OPEN_ORDERS 6  // absolute safety cap for normal SAR orders per cycle

double InpBasketProfitUSD         = 0.50;  // X1 base: custom ladder starts $0.50, $0.75, $0.875, $1.00...
double InpProfitTargetPercent      = 10.0; // legacy fixed target used only when percentage ladder is OFF

//================ DAILY EQUITY PROFIT PERCENT LADDER ===============
// BOOK-AND-RESTART ladder using the current equity-cycle anchor and
// g_baseBalance as the percentage reference.
//
// IMPORTANT: the first visit to a target does NOT lock the day.
//   Reach +10% exactly -> close/delete all EA orders, book the profit,
//                        allow a fresh order cycle, then protect +5%.
//   Reach +15% exactly -> book all orders, restart, then protect +10%.
//   Reach +20% exactly -> book all orders, restart, then protect +15%.
//   Reach +30% exactly -> book all orders, restart, then protect +20%.
//   Reach +40% exactly -> book all orders, restart, then protect +30%.
//   Reach +50% exactly -> close everything and pause for the day.
//
// The lower protected floor becomes active only after a NEW market order
// opens following the target booking. Therefore reaching 10% itself cannot
// immediately trigger the 5% day lock. If the fresh cycle later pulls total
// daily equity below 5%, every order is closed and trading stops for the day.
bool   InpUseDailyProfitPercentLadder       = true;

double InpProfitLadderPercent1              = 10.0;
double InpProfitLadderPercent2              = 15.0;
double InpProfitLadderPercent3              = 20.0;
double InpProfitLadderPercent4              = 30.0;
double InpProfitLadderPercent5              = 40.0;
double InpProfitLadderPercent6              = 50.0;

double InpProfitLadderProtectPercent1       = 8.0;
double InpProfitLadderProtectPercent2       = 10.0;
double InpProfitLadderProtectPercent3       = 15.0;
double InpProfitLadderProtectPercent4       = 20.0;
double InpProfitLadderProtectPercent5       = 30.0;
double InpProfitLadderProtectPercent6       = 50.0;

// Default 0.00 means every target must be reached exactly.
double InpProfitLadderArmTolerancePercent   = 0.0;
bool   InpProfitLadderFinalLevelExact       = true;

// Close all EA market/pending orders whenever an intermediate target is hit,
// but do NOT pause. Normal strategy entries may start a fresh cycle afterward.
bool   InpProfitLadderBookAtEachTarget      = true;
bool   InpProfitLadderProtectAfterNewOrder  = true;

// Close slightly BEFORE the protected floor to compensate for spread,
// commission, fast-price movement and multi-order closing delay.
// Example: protected floor 20% + buffer 0.50% => start closing at 20.50%,
// aiming to finish near the intended 20% booked-profit floor.
// The optional return buffer is subtracted from this early-close trigger.
double InpProfitLadderFloorCloseBufferPercent = 0.50;
double InpProfitLadderReturnBufferPercent     = 0.0;

// Highest-total-daily-profit SHARE lock:
// The first target remains the exact Level-1 target (default +10%).
// At that first target the EA books all current orders, stays enabled and waits
// for a genuinely new market order. From that point onward there is NO final
// profit target and NO fixed 5-percentage-point trail gap.
//
// The EA remembers the highest TOTAL daily AccountEquity profit and locks a
// percentage share of that peak profit:
//   locked profit % = highest daily profit % * lock share / 100.
//
// Defaults with opening base $60 and 50% share:
//   highest equity $66 -> peak profit $6  -> lock $3  -> locked equity $63
//   highest equity $70 -> peak profit $10 -> lock $5  -> locked equity $65
//   highest equity $80 -> peak profit $20 -> lock $10 -> locked equity $70
//
// The locked level only moves upward. Trading continues without an upper limit.
// When AccountEquity falls to the buffered lock trigger, all EA orders are
// closed/deleted and trading pauses until the next equity/fresh-day reset.
bool   InpUseHighestProfitShareLock           = true;
double InpHighestProfitLockSharePercent       = 50.00; // retain this share of the highest total daily profit

// Unlimited mode: the old 50% final target is not used by the share-lock path.
bool   InpCloseAtFinalProfitLadderLevel       = false;
bool   InpPauseAfterProfitLadderClose         = true;


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
double InpDynamicBasketMultiplierStep       = 0.50; // added after X1.50: X1.75, X2.00, X2.25...
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
double InpDynamicBasketMinimumArmUSD       =0.40;// 0.10;//0.15;//0.20;//before Dynamic profit
double InpDynamicBasketMinimumCloseUSD     = 0.00;//0.02;//0.05;//0.10;//0.10;//before Dynamic profit

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
bool   InpUseMixedModeHalfBasketTP       = false;  // legacy compatibility
double InpMixedModeBasketTPMultiplier    = 0.40;  // fixed/ignored: MIXED always uses 0.50

// Weak SAR-score basket target:
// When the current active SAR quality score is <= this value,
// use the same exact fixed target: InpBasketProfitUSD / 2.
// Example: score 3, 2, 1 or 0 => half TP.
bool   InpUseLowSARScoreHalfBasketTP      = false;
int    InpSARScoreHalfBasketTPMax         = 3;

// SAR-flipped old basket profit target:
// Example: a BUY basket was opened during SAR BUY, then SAR flips to SELL
// while the BUY basket remains open. The old BUY basket is closed when its
// floating profit reaches InpBasketProfitUSD * multiplier.
// This never closes the old basket in loss.
bool   InpUseSARFlipOppositeBasketHalfTP = false;
double InpSARFlipOppositeBasketTPMultiplier = 0.50;

// Time-based half TP:
// When a BUY or SELL basket remains open for this many minutes,
// reduce only that side's profit target to InpBasketProfitUSD * multiplier.
// It closes only after positive profit reaches the reduced target.
bool   InpUseBasketHalfTPAfterMinutes = false;
int    InpBasketHalfTPAfterMinutes = 30;
double InpBasketHalfTPAfterMinutesMultiplier = 0.50;

//================ BASKET STOP LOSS BY MARKET MODE ==================
// InpBasketStopLossUSD is the fallback used when Auto Market Flow is OFF,
// or when InpUseSimpleSideBasketCloseOnly=true.
//
// When Auto Market Flow is ON and simple-side mode is OFF, the detected
// market mode selects ONE independent base SL below. The live tick-speed
// multiplier is then applied once and frozen for that BUY/SELL basket.
// Example defaults:
//   CONTINUOUS $0.50 + FAST x2.00 = locked SL $1.00
//   MEDIUM     $0.75 + NORMAL x1.50 = locked SL $1.125
//   MIXED      $0.50 + FAST x2.00 = locked SL $1.00
//   DANGER     $1.00 + DANGER x3.00 = locked SL $3.00
// Change these values independently according to your tested risk limits.
double InpBasketStopLossUSD              = 0.50; // fallback/simple-side SL, 0 = disabled
double InpContinuousTrendBasketSLUSD     = 0.50;
double InpMediumTrendBasketSLUSD         = 0.75;
double InpMixedTrendBasketSLUSD          = 0.50;
double InpDangerModeBasketSLUSD          = 1.00;

//================ AVERAGE M1 CANDLE BASKET SL ======================
// Calculates the average full candle height (High-Low) of the latest
// CLOSED M1 candles. Shift 0/current forming candle is excluded.
// The average RAW-price distance is converted into an estimated USD
// basket-stop value using the current dynamic lot and broker tick value/size.
//
// Combine mode:
//   0 = replace the normal market-mode basket SL with average-candle SL
//   1 = use the smaller/tighter value
//   2 = use the larger/wider value
bool   InpUseAverageM1CandleBasketSL       = true;
int    InpAverageM1CandleSLBars            = 10;
double InpAverageM1CandleSLMultiplier      = 1.25;//1.00;
int    InpAverageM1CandleSLCombineMode     = 0;
double InpAverageM1CandleSLMinimumUSD      = 0.10;
double InpAverageM1CandleSLMaximumUSD      = 2.00; // 0 = unlimited

// Simple basket close mode:
// true = close BUY basket and SELL basket only by fixed InpBasketProfitUSD / InpBasketStopLossUSD.
// It disables auto profit/loss adjustments such as combined all-basket profit close,
// basket/individual profit protect, time-decay TP, SAR-weak basket close,
// global equity trailing close, and auto market-flow SL adjustment.
bool   InpUseSimpleSideBasketCloseOnly = true;

//FIXED stoploss 


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

double InpLossStopPercent          = 15;//20;//10;//20.0; // full day loss lock percent

// Half-loss cooling pause:
// When equity uses this percentage of the configured InpLossStopPercent
// allowance, block every NEW order for the configured time. Existing market
// orders remain open and continue normal TP/SL/profit management. All pending
// EA entries are deleted when the pause starts and while it remains active.
// Example: InpLossStopPercent=20 and trigger=50 => pause at a 10% drawdown.
// The pause triggers only once per equity cycle, then trading resumes after
// InpHalfLossPauseMinutes even if equity is still below the warning level.
bool   InpUseHalfLossPause                = true;
double InpHalfLossPauseTriggerPercent     = 50.0; // percentage of InpLossStopPercent, not account percent
int    InpHalfLossPauseMinutes            =60*2;// 10;//60*4;
bool   InpDeletePendingOnHalfLossPause    = true;

double InpInitialServerSLExtraRawAfterHalfLoss =100;// 50.0; // extra RAW price gap for NEW orders after half-loss trigger

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

bool   InpOpenRecoveryAfterClose  = true;   // open recovery order after SL/SAR flip/early reverse close
double InpRecoveryProfitUSD       = 1;//2.00;   // optional fixed close target; chain continuation does NOT wait for this target
bool   InpRecoveryAfterSLReverse  = true;   // true: after basket SL, open opposite direction
bool   InpContinueSLReverseRecoveryAfterProfit = false; // any SL-reverse chain recovery closed with net profit > $0 opens the next same-direction recovery continuously
// SL-reverse recovery priority bypass:
// Applies only to SLREV_RECOVERY_1 and SLREV_RECOVERY_CHAIN orders.
// These orders ignore MIXED/DANGER market-mode pauses, big-candle pauses,
// per-direction limits, total-order limits and the one-recovery-order limit.
// GMT0 no-new hours, AutoTrading/broker permission and equity locks remain active.
bool   InpSLReverseRecoveryBypassEntryLimits = true;

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
double InpRecoveryGapLot          = 0.01;
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

//================ INITIAL SERVER-SIDE ORDER SL =====================
// Optional broker-side SL added immediately after every EA order is created.
// The USD amount is PER ORDER, not per BUY/SELL basket.
// The selected value depends on the live SAR direction at order creation:
//   SAR BUY  + BUY  order = InpInitialServerSLWithSARUSD
//   SAR BUY  + SELL order = InpInitialServerSLAgainstSARUSD
//   SAR SELL + SELL order = InpInitialServerSLWithSARUSD
//   SAR SELL + BUY  order = InpInitialServerSLAgainstSARUSD
// If SAR direction is unavailable, the conservative fallback value is used.
bool   InpUseInitialServerSideOrderSL       = true;
double InpInitialServerSLWithSARUSD          =1;//0.50;// 2;//0.90;
double InpInitialServerSLAgainstSARUSD       =0.50;//1;// 0.50;
double InpInitialServerSLNoSARDirectionUSD   =2;//3;// 0.50;
bool   InpInitialServerSLForPending          = true;
int    InpInitialServerSLRetrySeconds        = 3;

// Opening-balance equity guard:
// Example: opening balance $100 -> loss lock at $80 and profit lock at $110.
// When either threshold is reached, the EA closes its own orders and pauses
// until the next equity-cycle reset.
// Live trading pauses for the current equity cycle when:
//   Equity <= opening balance - 20%, or
//   Equity >= opening balance + 10%.
// On either threshold, all EA market orders are closed and all EA pending
// orders are deleted. The guard is bypassed in Strategy Tester and on the
// configured exempt account.
bool   InpUseEquityProtection       = true;
bool   InpAutoUseCurrentBalanceBase = true;   // capture AccountBalance() as the opening balance for each cycle
double InpManualBaseCapitalUSD      = 20.0;   // used only when Auto=false
bool   InpBypassEquityLockInTesting = false;
int    InpEquityLockExemptAccount   = 0;//291085426; // 0 = no exempt live account

double InpProtectionBufferUSD      = 0.00;   // optional extra amount below the 20% loss level
bool   InpCloseOrdersOnEquityHit    = true;

bool   InpUseDailyProfitLock        = true;
bool   InpCloseOrdersOnProfitLock   = true;
bool   InpPauseAfterProfitTarget    = true;

// Equity statistics reset cycle
bool   InpResetEquityStatsEvery6Hours = true;
int    InpEquityResetHours            = 24;      // fallback rolling reset if fixed hours are disabled
bool   InpUseFixedEquityResetHours    = false;   // true = reset only at configured server hours
string InpEquityResetHourList         = "1"; // server-time hours to reset equity base
bool   InpResetTradingCycleWithEquity = true;   // reset SAR/early/flat cycle when equity stats reset

//================ COMPLETE FRESH DAY START =========================
// Strategy Tester: a new tester/server date starts a completely fresh run.
// Live trading: a new GMT0 date starts a completely fresh run.
// To reproduce a separate one-day test, pending and market orders are closed,
// runtime strategy memory is cleared, persistent SL-streak state is reset,
// the new opening balance is captured, and the dynamic lot is recalculated.
bool   InpUseFreshDayStart                   = true;
bool   InpFreshDayCloseMarketOrders          = true;
bool   InpFreshDayDeletePendingOrders        = true;
bool   InpFreshDayResetPersistentLocks       = true;
bool   InpFreshDayIgnorePreviousTradeHistory = true;
bool   InpFreshDayDisableRollingEquityReset  = true;
// Strict mode reproduces a separately started one-day test as closely as
// possible. The history cutoff is moved beyond all forced day-boundary closes,
// all daily strategy memory is cleared, and the normal startup trackers are
// initialized again from the fresh cutoff.
bool   InpFreshDayStrictNewAttachBoot        = true;
bool   InpFreshDayDeleteEAStateGlobals       = true;
// Start the new day on the first available 00:00 tick after the strict
// 23:45-23:59 shutdown. Do not skip the first M1 setup of the new day.
bool   InpFreshDayResumeOnlyOnNewM1Bar       = false;
int    InpFreshDayInternalResumeDelaySeconds = 0;

// Unified new-day balance mode:
// Strategy Tester and live VPS both use the actual AccountBalance() captured
// at the new-day boundary for dynamic lot and scaled USD targets. The only
// intended difference is the clock source: tester/report time in backtests and
// GMT0 time in live trading.
// Legacy compatibility only. Tester and live now both use the actual new-day
// AccountBalance() as the opening reference. Only their clock source differs.
bool   InpTesterStandaloneFreshDayMode       = false;


//================ STRICT 23:45 DAY-END FRESH BOOT ==================
// Live trading uses GMT0/UTC time. Strategy Tester converts test/server time to GMT0.
// At the first tick from 23:45:00 onward, the EA:
//   1) blocks every strategy path before any other OnTick calculation,
//   2) deletes its pending orders,
//   3) closes its market orders,
//   4) clears all known runtime strategy memory,
//   5) requests ChartSetSymbolPeriod() so MT4 reloads every compiled global
//      variable from its declaration/default value,
//   6) keeps OnTick blocked through 23:59:59 GMT0.
// At 00:00 the existing strict fresh-day routine creates the new daily
// balance/equity cycle and the daily reinitialization performs a full startup.
// This is safer than a JSON variable file: no setting name, type, array or new
// runtime variable can be omitted from the actual MT4 program reload.
bool   InpUseStrict2345DayEndFreshBoot       = true;
int    InpDayEndFreshBootHour                = 23;
int    InpDayEndFreshBootMinute              = 45;
bool   InpDayEndCloseMarketOrders            = true;
bool   InpDayEndDeletePendingOrders          = true;
bool   InpDayEndResetRuntimeState            = true;
bool   InpDayEndReinitializeEA               = true;
bool   InpDayEndReinitializeEAInTesting      = false;
// A one-second timer makes 23:45 and 00:00 processing independent of ticks.
bool   InpUseFreshBootOneSecondTimer          = true;

//================ DAILY EA SELF-REINITIALIZATION ===================
// Optional final cleanup after the complete fresh-day reset finishes.
// The EA first closes/deletes its own orders, resets all daily state and
// captures the new opening balance. Only when the EA is flat does it request
// ChartSetSymbolPeriod(), which causes OnDeinit() followed by OnInit().
// Strategy Tester uses the deterministic internal fresh-day reset by default.
bool   InpRestartEADaily                = true;
bool   InpRestartEAOnlyWhenFlat         = true;
bool   InpRestartEAInTesting            = false;
int    InpRestartEAResumeDelayMinutes   = 1;
bool   InpRestartEAWaitForNewM1Bar      = true;

// Deposit detection reset
bool   InpResetEquityStatsOnDeposit = true;      // detect OP_BALANCE deposit and reuse equity reset method
bool   InpCloseOrdersOnDepositReset = false;     // optional: close EA orders before deposit reset

// Notifications
bool   InpSendPushNotifications       = true;    // MT4 mobile push notification
bool   InpSendTerminalAlerts          = false;    // desktop popup alert
bool   InpNotifyOnProfitLock          = true;    // one pause-reason notification when daily profit locks
bool   InpNotifyOnEquityStop          = true;    // one pause-reason notification when daily loss locks
bool   InpNotifyOnEquityRestart       = true;    // notify when trading restarts after reset hour
bool   InpNotifyOnEAStart             = false;   // generic attach/reload alert disabled by default
// Strict fresh-boot lifecycle notifications. Push delivery uses the existing
// InpSendPushNotifications switch; desktop popup uses InpSendTerminalAlerts.
bool   InpNotifyOnDayEndResetStarted   = true;   // one push when strict 23:45 GMT0 reset begins
bool   InpNotifyOnNewDayTradingStarted = true;   // one push after all 00:00 restart/resume holds finish
int    InpNewDayNotifyWindowMinutes     = 15;     // allow NEW DAY alert only from 00:00 through 00:15 GMT0

// Trading-pause reason notifications:
// Sends one mobile push/terminal alert when NEW orders become paused,
// including the active clock hour and the configured blocked-hour list.
// Existing market orders still continue normal TP/SL/profit management unless
// the pause reason itself is a full day equity/profit lock.
bool   InpNotifyOnTradingPausedReason    = true;
bool   InpNotifyOnNoNewOrderHourPause    = true;
bool   InpNotifyOnConsecutiveSLPause     = true;
bool   InpNotifyOnHalfLossPause          = true;
bool   InpNotifyOnSideLossPause          = true;
bool   InpNotifyOnOppositeDirectionPause = true;


// Continuous order controls
bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;       // 0 = disabled
double InpMinPriceGap             = 0.00;    // raw price gap, 0 = disabled

//================ CENTRAL SAME-DIRECTION ORDER GAP SAFETY ==========
// Prevents several BUY STOP or SELL STOP orders from activating together at
// nearly the same price. The rule applies to normal SAR, impulse, pyramid,
// pullback, breakout, good-market and recovery entry paths.
//
// 1) Only one untriggered pending order is allowed per BUY/SELL direction.
// 2) A new same-direction entry must be at least the configured RAW-price gap
//    from every existing same-direction market/pending entry.
// 3) After one pending activates, any remaining same-direction pending order
//    inside the gap is deleted immediately.
// 4) If broker execution/slippage still creates two live orders inside the
//    gap, the newer live order is closed as an emergency duplicate guard.
bool   InpUseCentralOrderGapSafety                 = true;
double InpMinimumSameDirectionOrderGapRaw          = 50.0;
bool   InpOnlyOnePendingOrderPerDirection          = true;
bool   InpDeletePendingTooCloseAfterActivation     = true;
bool   InpCloseNewerLiveOrderIfGapViolated         = true;

//================ LIVE TICK-SPEED DASHBOARD ========================
// Display-only adaptive market-speed monitor. It does not block or create orders.
// It combines:
//   1) average range of closed candles,
//   2) current-candle range expansion per elapsed second,
//   3) recent price travel/range inside a short tick window, and
//   4) live tick frequency compared with its own rolling baseline.
bool   InpShowTickSpeedPanel              = true;
int    InpTickSpeedAverageBars             = 10;
int    InpTickSpeedWindowSeconds           = 5;
double InpTickSpeedSlowCandleRatio         = 0.50;
double InpTickSpeedFastCandleRatio         = 1.50;
double InpTickSpeedDangerCandleRatio       = 2.50;
double InpTickSpeedExtremeCandleRatio      = 4.00;
double InpTickSpeedFastWindowMoveRatio     = 0.25;
double InpTickSpeedDangerWindowMoveRatio   = 0.50;
double InpTickSpeedExtremeWindowMoveRatio  = 0.75;
double InpTickSpeedHighTickRateRatio       = 1.50;
double InpTickSpeedSlowTickRateRatio       = 0.75;
double InpTickSpeedBaselineSmoothing       = 0.15;

// Adaptive basket stop loss selected from tick speed when a BUY/SELL basket
// first becomes active. Base SL comes from the CURRENT market mode:
// Continuous/Medium/Mixed/Danger. The selected USD loss is frozen for that
// side until the complete side basket closes. It can never widen later because
// of either a tick-speed change or a market-mode change while already open.
bool   InpUseTickSpeedAdaptiveBasketSL       = true;
double InpTickSpeedSlowSLMultiplier          = 1.25; // slower market may use slightly wider base SL
double InpTickSpeedNormalSLMultiplier        = 1.00; // normal market uses the selected mode base SL
double InpTickSpeedFastSLMultiplier          = 2;//0.75; // fast market reduces risk instead of widening SL
double InpTickSpeedDangerSLMultiplier        = 2;//0.50; // danger market uses the smallest adaptive SL
double InpTickSpeedWarmupSLMultiplier        = 1.00; // neutral fallback until speed engine is ready
double InpTickSpeedAdaptiveSLMaxUSD          = 0.00; // 0 = unlimited safety cap

//================ LIVE OPPOSITE-CANDLE TIGHT SL ====================
// This protection does NOT wait for the current M1 candle to close.
// It is checked on every tick after a BUY/SELL basket becomes active.
// BUY protection: the live M1 candle is bearish and its full range is larger
// than the previous closed M1 candle while the BUY basket is already negative.
// SELL protection: the live M1 candle is bullish under the same conditions.
// Once triggered, the reduced SL is latched for that side and can never widen
// again until the complete BUY/SELL side basket closes.
bool   InpUseLiveOppositeCandleTightSL       = true;
double InpLiveOppositeCandleRangeRatio       = 1.00; // live M1 range must be > previous M1 range x this value
double InpLiveOppositeCandleMinBodyPercent   = 35.0; // avoid arming only from a long wick; 0 disables
double InpLiveOppositeCandleSLMultiplier     = 1;//0.50; // frozen adaptive SL x 0.50, e.g. $0.50 -> $0.25
double InpLiveOppositeCandleMinimumSLUSD     = 0.01; // smallest permitted tightened basket SL

//================ OPPOSITE IMPULSE CONTINUATION ====================
// After a losing BUY/SELL side closes specifically by the LIVE OPPOSITE M1
// tightened SL, a strong opposite impulse can create ONE continuation pending
// STOP order without waiting for the next candle.
//
// BUY loss + strong bearish impulse -> SELLSTOP below the live M1 low.
// SELL loss + strong bullish impulse -> BUYSTOP above the live M1 high.
//
// This special entry bypasses normal strategy filters because the impulse itself
// is the confirmation. Hard protections remain: GMT0 no-new hours, tick speed,
// broker permission, equity locks, direction cap and total cap.
// Normally live SAR must match the impulse direction. A stricter pre-SAR DANGER
// override can enter before the SAR dots flip when the momentum candle is very
// strong. The activated order uses the existing adaptive SL, dynamic profit
// ladder and server-side profit lock.
bool   InpUseOppositeImpulseContinuation       = true;
double InpImpulseCurrentVsPreviousRatio        = 1.20; // live M1 range >= previous closed M1 range x this
double InpImpulseCurrentVsAverageRatio         = 1.50; // live M1 range >= average closed-candle range x this
double InpImpulseMinimumBodyPercent            = 60.0; // normal SAR-confirmed impulse body
double InpImpulseMaximumExitWickPercent        = 25.0; // SELL: lower wick; BUY: upper wick
double InpImpulsePendingGapRaw                 = 15.0; // SELLSTOP below low / BUYSTOP above high
int    InpImpulsePendingExpiryBars             = 2;    // cancel if not activated within this many M1 bars
double InpImpulseMaximumRetracePercent         = 50.0; // cancel after this retracement into impulse range
bool   InpImpulseRequireFastTickSpeed          = true; // normal impulse requires FAST or DANGER
bool   InpImpulseRequireLiveSARDirection       = true; // normal path: live SAR must match impulse direction
// Pre-SAR reversal override: catches a violent move before the slower SAR flip.
// Used only when live SAR still points to the stopped side. Defaults require
// DANGER speed, >=70% body and <=20% exit wick.
bool   InpImpulseAllowPreSARReversalOverride   = true;
bool   InpImpulsePreSARRequireDangerSpeed      = true;
double InpImpulsePreSARMinimumBodyPercent      = 70.0;
double InpImpulsePreSARMaximumExitWickPercent  = 20.0;
bool   InpImpulseSkipNormalAfterCloseRecovery  = true; // do not also create the ordinary after-SL recovery
int    InpImpulsePendingRetrySeconds           = 3;

// PRE-SAR reversal-suspect entry while the old-direction basket is still open.
// Example: active SAR BUY + open BUY basket + strong bearish live M1 candle
// + weak SAR score => queue one SELLSTOP before SAR dots fully flip to SELL.
// This is independent of the after-SL impulse trigger and is intentionally
// limited to one opposite pending order.
bool   InpUsePreSARReversalSuspectEntry        = true;
double InpPreSARSuspectCurrentVsPreviousRatio  = 1.10;
double InpPreSARSuspectCurrentVsAverageRatio   = 1.25;
double InpPreSARSuspectMinimumBodyPercent      = 55.0;
double InpPreSARSuspectMaximumExitWickPercent  = 30.0;
bool   InpPreSARSuspectRequireFastTickSpeed    = true; // FAST or DANGER
int    InpPreSARSuspectMaximumSARScore         = 4;    // weak/late SAR suspicion
bool   InpPreSARSuspectRequireOldSideNotProfit = true; // old basket P/L must be <= threshold
double InpPreSARSuspectMaxOldSideProfitUSD     = 0.05;

//================ SAR TREND CONTINUATION ADD-ONS ====================
// Mirrored for BUY and SELL. These are separate from recovery:
//   BUY SAR + profitable BUY basket  -> BUY continuation pending orders.
//   SELL SAR + profitable SELL basket -> SELL continuation pending orders.
// Only one continuation pending order is allowed per direction at a time.
// The default per-side cap is 3 total entries: one base order plus two add-ons.
bool   InpUseSARContinuationAddOns             = true;
int    InpMaxSARContinuationOrdersPerSide      = 5;
int    InpSARContinuationPendingExpiryBars     = 5;
bool   InpSARContinuationOneOrderPerM1Bar      = true;
bool   InpSARContinuationRequireNotSlow        = true;
double InpSARContinuationRenewedBodyPercent    = 60.0;
double InpSARContinuationRenewedRangeAvgRatio  = 1.00;

// Continuation growth is allowed only after the live side basket is already
// protected by broker-side SL at break-even or better.
// Daily ladder level controls how many SAR add-ons may be created.
bool   InpContinuationRequireProtectedProfit   = true;
bool   InpScaleContinuationByProfitLadder      = true;
int    InpContinuationMaxBelowLevel1           = 0;
int    InpContinuationMaxAtLevel1              = 1;
int    InpContinuationMaxAtLevel2              = 2;
int    InpContinuationMaxAtLevel3OrHigher      = 3;

// 1) PROFIT PYRAMID:
// Add in the existing SAR direction only when that side basket is already
// profitable, price has travelled farther in profit from the latest entry,
// and the live M1 candle creates a fresh trend extreme.
bool   InpUseProfitPyramidOrders               = true;
int    InpMaxProfitPyramidOrdersPerSide        = 2;
double InpPyramidMinimumBasketProfitUSD        = 0.10;
double InpPyramidRawGapFromLatestEntry         = 50.0;
double InpPyramidPendingGapRaw                 = 10.0;
double InpPyramidMinimumBodyPercent            = 50.0;
int    InpPyramidMinimumSARScore               = 4;

// 2) PULLBACK CONTINUATION:
// Remember a 30-80 raw pullback from the best live price, then wait for a
// new M1 candle to resume in the SAR direction before placing the STOP order.
bool   InpUsePullbackContinuationOrders        = true;
int    InpMaxPullbackContinuationOrdersPerSide = 1;
double InpPullbackContinuationMinimumProfitUSD = 0.05;
double InpPullbackContinuationMinRaw           = 30.0;
double InpPullbackContinuationMaxRaw           = 80.0;
double InpPullbackContinuationBreakRaw         = 5.0;
double InpPullbackContinuationPendingGapRaw    = 10.0;
double InpPullbackContinuationMinBodyPercent   = 45.0;
int    InpPullbackContinuationMinSARScore      = 3;

// 3) BREAKOUT CONTINUATION:
// A strong closed M1 candle in the SAR direction followed by a fresh break of
// its high/low can create another same-direction pending STOP.
bool   InpUseBreakoutContinuationOrders        = true;
int    InpMaxBreakoutContinuationOrdersPerSide = 2;
double InpBreakoutMinimumBasketProfitUSD       = 0.10;
double InpBreakoutTriggerRaw                   = 10.0;
double InpBreakoutPendingGapRaw                = 10.0;
double InpBreakoutMinimumBodyPercent           = 60.0;
double InpBreakoutMaximumExitWickPercent       = 25.0;
int    InpBreakoutMinimumSARScore              = 4;
bool   InpBreakoutRequireFastTickSpeed         = true;

//================ PENDING ORDER ENTRY MODE ==========================
// Every approved BUY entry is placed as a BUYSTOP and every approved SELL
// entry is placed as a SELLSTOP. The pending price is at least this RAW-price
// distance from the live market. Example BTCUSD: Ask 60000 + 20 = BUYSTOP 60020.
// For a same-SAR replacement after a normal order closes, the last close price
// is used as the preferred reference; broker/live-price safety may move it farther.
bool   InpUsePendingOrderEntries             = true;
double InpPendingOrderRawGap                 = 30.0;

// Runtime high-risk pending gap. The base input above is NEVER modified.
// This prevents a 50-raw value from carrying from one day into the next.
bool   InpUseHighRiskPendingOrderGap         = true;
double InpHighRiskPendingOrderRawGap         = 50.0;
int    InpHighRiskPendingGapStartHour        = 14; // inclusive
int    InpHighRiskPendingGapEndHour          = 22; // exclusive

bool   InpPendingUseLastClosedOrderPrice     = true;
bool   InpDeletePendingOrdersOnSARChange     = true;

// Good-market continuation after the FIRST SAR order closes in strong profit:
// If the first normal SAR order of the current cycle closes with NET profit
// strictly greater than InpGoodMarketFirstOrderProfitUSD, immediately place
// one same-direction BUYSTOP/SELLSTOP using InpPendingOrderRawGap.
// This bonus pending entry bypasses normal strategy/timing filters because the
// profitable first order is treated as live market confirmation. Hard safety
// checks remain: GMT0 no-new hours, current SAR direction, AutoTrading/broker
// permission, per-direction open-entry cap and total-order cap.
bool   InpOpenGoodMarketPendingAfterFirstProfit = true;
double InpGoodMarketFirstOrderProfitUSD          = 0.50;
int    InpGoodMarketPendingRetrySeconds           = 3;

// GMT0 / UTC no-new-order hours:
// Block ALL new EA entries during every GMT0 hour listed below:
// first SAR, later SAR, extra, recovery, recovery-gap and pending entries.
// Existing market-order close/profit/protection management continues.
// LIVE: TimeGMT() is used, so broker-server/VPS timezone does not matter.
// TESTER: TimeCurrent() is converted to GMT0 using InpTesterServerGMTOffsetHours.
//         GMT0 server/tester=0, GMT+2 server/tester=2.
bool   InpUseNoNewOrderHours      = true;
bool   InpApplyNoNewOrderHoursInTesting = true;
int    InpTesterServerGMTOffsetHours = 0; // Strategy Tester only: GMT0 server=0, GMT+2 server=2. Blocked hours remain GMT0.

// Single source of truth. Do not create Dubai/server-hour copies.
// Example: "6,7,11,12" blocks 06:00-06:59, 07:00-07:59, 11:00-11:59, 12:00-12:59 GMT0.
string InpNoNewOrderHourList      = "6,7,11,12,13,14,15,16,17,18,19,20,21,22,23"; // GMT0 / UTC only








// Consecutive basket-stop protection:
// Two basket SL events without an intervening profitable basket close pause
// every new entry path for 120 minutes. Existing market orders remain managed.
bool   InpUseConsecutiveSLPause       = true;
int    InpConsecutiveSLPauseCount     = 2;
int    InpConsecutiveSLPauseMinutes   = 120;
bool   InpDeletePendingOnSLPause      = true;
bool   InpResetSLStreakOnProfitClose  = true;

// Side-specific consecutive-loss pause:
// Two consecutive BUY losses pause only BUY entries.
// Two consecutive SELL losses pause only SELL entries.
// The pause ends after the configured minutes or earlier on the next SAR flip.
bool   InpUseSideLossPause             = true;
int    InpSideLossPauseAfterLosses     = 2;
int    InpSideLossPauseMinutes         = 120;
bool   InpSideLossPauseUntilSARFlip    = true;
bool   InpDeletePendingOnSideLossPause = true;




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

double InpSARConfirmPriceDiff     =0;// 20;//80.0;   // SAR signal-change raw price diff confirmation only
int    InpSARConfirmMinutes       = 5;      // used by the full profile only

// BUY-only stronger confirmation.
// SELL keeps the normal configured score and confirmation distance.
// BUY requires the higher score, a real H1 EMA trend match and an extra
// raw-price move from the SAR flip reference.
bool   InpUseBuyStrictConfirmation = false;
int    InpBuyStrictSARMinimumScore = 6;//7;
double InpBuyExtraSARConfirmRaw    = 50.0;
bool   InpBuyRequireH1TrendMatch   = false;
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

//================ COMPACT LIVE DASHBOARD ===========================
// true  = show the responsive three-panel dashboard:
//         LEFT order creation, TOP-CENTER latest actions, RIGHT account/risk.
// false = retain the older multi-panel diagnostic dashboard.
bool   InpUseCompactDashboard              = true;
bool   InpShowLegacyDashboardWhenCompactOff = true;

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
datetime g_lastInitialServerSLScanTime = 0;
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

// Side-specific consecutive-loss pause runtime.
int      g_buySideLossStreak = 0;
int      g_sellSideLossStreak = 0;
datetime g_buySideLossPauseUntil = 0;
datetime g_sellSideLossPauseUntil = 0;
int      g_buySideLossPauseTriggerTicket = 0;
int      g_sellSideLossPauseTriggerTicket = 0;
datetime g_buySideLossPauseTriggerCloseTime = 0;
datetime g_sellSideLossPauseTriggerCloseTime = 0;
int      g_buySideLossPauseTriggerSARDirection = 0;
int      g_sellSideLossPauseTriggerSARDirection = 0;
string   g_buySideLossPauseStatus = "READY";
string   g_sellSideLossPauseStatus = "READY";
datetime g_sideLossPauseLastScanTime = 0;

int      g_dotColor               = 0;       // 1 SAR below price, -1 SAR above price
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

// One-shot continuation request created only when the FIRST SAR order closes
// above the configured good-market profit threshold.
bool     g_goodMarketContinuationPending = false;
int      g_goodMarketContinuationDirection = 0;
int      g_goodMarketContinuationSourceTicket = 0;
double   g_goodMarketContinuationSourceProfit = 0.0;
double   g_goodMarketContinuationClosePrice = 0.0;
datetime g_goodMarketContinuationCloseTime = 0;
datetime g_goodMarketContinuationLastAttemptTime = 0;
string   g_goodMarketContinuationStatus = "WAIT FIRST PROFIT";

// One-shot opposite impulse continuation state.
// The request is created only after a LIVE OPPOSITE M1 tightened-SL close.
bool     g_oppositeImpulseRequestPending       = false;
int      g_oppositeImpulseDirection            = 0;
int      g_oppositeImpulseSourceDirection      = 0;
double   g_oppositeImpulseSourceLoss           = 0.0;
datetime g_oppositeImpulseSignalBarTime        = 0;
datetime g_oppositeImpulseQueuedTime           = 0;
datetime g_oppositeImpulseLastAttemptTime      = 0;
double   g_oppositeImpulseSignalHigh           = 0.0;
double   g_oppositeImpulseSignalLow            = 0.0;
double   g_oppositeImpulseSignalRange          = 0.0;
double   g_oppositeImpulsePreviousRange        = 0.0;
double   g_oppositeImpulseAverageRange         = 0.0;
double   g_oppositeImpulseBodyPercent          = 0.0;
double   g_oppositeImpulseExitWickPercent      = 0.0;
int      g_oppositeImpulsePendingTicket        = -1;
bool     g_oppositeImpulsePreSAROverride       = false;
string   g_oppositeImpulseStatus               = "WAIT IMPULSE";

// Consecutive basket-stop pause state. Persisted in terminal Global Variables
// so restarting MT4/VPS cannot immediately bypass an active safety pause.
int      g_consecutiveBasketSLCount          = 0;
datetime g_consecutiveBasketSLPauseUntil     = 0;
datetime g_lastConsecutiveSLRegisterTime     = 0;
int      g_lastConsecutiveSLRegisterDirection = 0;
string   g_consecutiveSLPauseStatus          = "READY | SL 0/2";

// SAR same-direction continuation add-on runtime state.
string   g_sarContinuationStatus              = "WAIT SAR ADD-ON";
datetime g_lastSARContinuationBuyBarTime      = 0;
datetime g_lastSARContinuationSellBarTime     = 0;
double   g_buySARContinuationExtreme          = 0.0;
double   g_sellSARContinuationExtreme         = 0.0;
bool     g_buyPullbackContinuationArmed       = false;
bool     g_sellPullbackContinuationArmed      = false;
datetime g_buyPullbackContinuationArmBarTime  = 0;
datetime g_sellPullbackContinuationArmBarTime = 0;
double   g_buyPullbackContinuationRaw         = 0.0;
double   g_sellPullbackContinuationRaw        = 0.0;


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

// Continuous SL-reverse recovery chain tracker.
// A chain starts with SLREV_REC1 after basket SL. Every chain recovery that
// later closes with net profit > $0 queues the next same-direction recovery.
// A zero/loss close ends the chain. Historical tickets are seeded on OnInit
// so old profitable recoveries cannot restart a chain after EA reload.
#define DXB_RECOVERY_CHAIN_HISTORY_CAPACITY 2000
int      g_recoveryChainProcessedTickets[DXB_RECOVERY_CHAIN_HISTORY_CAPACITY];
int      g_recoveryChainProcessedCount = 0;
bool     g_recoveryChainTrackerInitialized = false;
bool     g_recoveryChainContinuationPending = false;
int      g_recoveryChainPendingDirection = 0;
int      g_recoveryChainSourceTicket = 0;
double   g_recoveryChainSourceProfit = 0.0;
datetime g_recoveryChainSourceCloseTime = 0;
datetime g_recoveryChainLastOpenAttemptTime = 0;


int      g_equityDateKey        = 0;
int      g_freshDayDateKey      = 0;
datetime g_freshDayStartServerTime = 0;
// Strict history cutoff can be later than midnight. At a day reset it is
// placed after forced order closures so those closures cannot influence the
// new day's market mode, streak, continuation or recovery logic.
datetime g_freshDayHistoryCutoffTime = 0;
datetime g_freshDayInternalResumeAfter = 0;
datetime g_freshDayInternalResumeBarTime = 0;
bool     g_freshDayResetInProgress = false;
string   g_freshDayStatus       = "WAIT INIT";


// Strict 23:45 GMT0 shutdown state. Prepared/reloaded date keys are also stored in
// terminal Global Variables so a chart reload or terminal restart during the
// 23:45-00:00 hold cannot accidentally run the shutdown twice or resume trade.
int      g_dayEndPreparedDateKey = 0;
int      g_dayEndReloadedDateKey = 0;
bool     g_dayEndResetInProgress = false;
string   g_dayEndFreshBootStatus = "WAIT INIT";

// Daily chart-reinitialization state. The restart date and resume time are
// stored in terminal Global Variables so a chart reinitialization cannot loop
// and the post-restart delay survives OnDeinit()/OnInit().
datetime g_dailyEAResumeAfter   = 0;
datetime g_dailyEAReinitBarTime = 0;
string   g_dailyEAReinitStatus  = "WAIT INIT";
double   g_dayStartBalance      = 0.0;
double   g_dayStartEquity       = 0.0;
double   g_baseBalance          = 0.0;   // strategy capital reference used for lot/target scaling
double   g_equityCycleAnchor    = 0.0;   // actual equity at this day's fresh 00:00 start
double   g_testerInitialReferenceBalance = 0.0; // original tester deposit; intentionally survives daily resets
double   g_lossStopEquityLevel = 0.0;  // daily anchor minus configured reference-capital loss amount
double   g_profitTargetEquity  = 0.0;  // final ladder target, or legacy fixed target when ladder is OFF
double   g_dailyProfitTarget   = 0.0;  // dollar amount of final/legacy target from strategy reference
double   g_profitLadderLevel1Equity = 0.0;
double   g_profitLadderLevel2Equity = 0.0;
double   g_profitLadderLevel3Equity = 0.0;
double   g_profitLadderLevel4Equity = 0.0;
double   g_profitLadderLevel5Equity = 0.0;
double   g_profitLadderLevel6Equity = 0.0;
int      g_profitPercentHighestLevel = 0;
double   g_profitPercentProtectedPercent = 0.0;
double   g_profitPercentProtectedEquity = 0.0;
double   g_profitPercentPeakPercent = 0.0;
double   g_profitPercentLastTrailLogFloor = 0.0;
bool     g_profitPercentLadderHit = false;
bool     g_profitPercentAwaitingNewOrder = false;
int      g_profitPercentLastBookedLevel = 0;
datetime g_profitPercentLastBookTime = 0;
string   g_profitPercentLadderStatus = "READY";
double   g_lockedProfitToday    = 0.0;
bool     g_dailyProfitLock      = false;
bool     g_equityProtectionHit  = false;
datetime g_lastEquityStatsResetTime = 0;
int      g_equityCycleNumber    = 1;
int      g_lastEquityResetSlot  = -1;  // prevents repeated reset during the same reset hour
bool     g_notifyProfitLockSent = false;
bool     g_notifyEquityStopSent = false;

// One-shot half-loss cooling pause for the current equity cycle.
double   g_halfLossPauseEquityLevel = 0.0;
datetime g_halfLossPauseUntil       = 0;
bool     g_halfLossPauseTriggered   = false;
string   g_halfLossPauseStatus      = "READY";

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
               " | RequiredDiff=", DoubleToString(GetEffectiveSARConfirmPriceDiff(), Digits));
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
//| BUY-only stronger direction/score confirmation.                  |
//| Uses the real H1 EMA50/EMA200 helper, independent of mode bypass. |
//+------------------------------------------------------------------+
bool IsBuyStrictEntryAllowed(int direction,string source)
  {
   if(!InpUseBuyStrictConfirmation ||
      direction != 1)
      return(true);

   int required =
      MathMax(0,
              MathMin(7,
                      InpBuyStrictSARMinimumScore));
   int score =
      GetDynamicSARStrengthScore(direction);

   if(score < required)
     {
      string msg =
         "BUY STRICT BLOCK | SAR SCORE " +
         IntegerToString(score) + "/" +
         IntegerToString(required) +
         " | Source=" + source;

      SetLastOrderBlockDashboard(msg);
      Print(msg);
      return(false);
     }

   if(InpBuyRequireH1TrendMatch)
     {
      int h1Trend =
         GetH1TrendDirection1();

      if(h1Trend != 1)
        {
         string msg =
            "BUY STRICT BLOCK | H1 EMA TREND=" +
            DirectionText(h1Trend) +
            " | Required=BUY | Source=" +
            source;

         SetLastOrderBlockDashboard(msg);
         Print(msg);
         return(false);
        }
     }

   return(true);
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
// execution safety, including the hard GMT0 no-new-order hours.
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
         return(true);  // mandatory GMT0-time lock
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
      return("FIRST ORDER: PRICE DIFF + GMT0 TIME");

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
      if(!IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
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

         if(InpNotifyOnTradingPausedReason && InpNotifyOnOppositeDirectionPause)
           {
            NotifyTradingPausedReasonOnce(
               "OPPOSITE_PAUSE_" + IntegerToString(g_oppositeDirectionPauseTriggerTicket),
               DirectionText(g_oppositePausedDirection) + " TRADING PAUSED - OPPOSITE STREAK",
               "Reason: " + DirectionText(g_oppositeDirectionPauseWinner) +
               " profit streak " + IntegerToString(required) +
               " | Block " + DirectionText(g_oppositePausedDirection) +
               " | Resume " + TimeToString(g_oppositeDirectionPauseUntil,TIME_DATE|TIME_MINUTES) +
               " | " + GetPauseClockDetails());
           }
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
//| Consecutive losses for one BUY/SELL side in the current fresh day.|
//| Opposite-direction results do not reset this side's own streak.   |
//+------------------------------------------------------------------+
int GetCurrentSideConsecutiveLosses(int direction,
                                    int &latestTicket,
                                    datetime &latestCloseTime)
  {
   latestTicket = 0;
   latestCloseTime = 0;

   if(direction != 1 && direction != -1)
      return(0);

   int count = 0;
   int historyTotal = OrdersHistoryTotal();

   // MT4 history positions are normally oldest -> newest, so scan backward.
   for(int i = historyTotal - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(OrderType() != OP_BUY &&
         OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() <= 0 ||
         !IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
         continue;

      int orderDirection =
         (OrderType() == OP_BUY) ? 1 : -1;

      if(orderDirection != direction)
         continue;

      if(latestTicket == 0)
        {
         latestTicket = OrderTicket();
         latestCloseTime = OrderCloseTime();
        }

      double netProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      if(netProfit < -0.000001)
         count++;
      else
         break;
     }

   return(count);
  }

//+------------------------------------------------------------------+
void ClearSideLossPause(int direction,string reason)
  {
   if(direction == 1)
     {
      g_buySideLossPauseUntil = 0;
      g_buySideLossPauseTriggerSARDirection = 0;
      g_buySideLossPauseStatus = reason;
     }
   else
   if(direction == -1)
     {
      g_sellSideLossPauseUntil = 0;
      g_sellSideLossPauseTriggerSARDirection = 0;
      g_sellSideLossPauseStatus = reason;
     }
  }

//+------------------------------------------------------------------+
bool IsSideLossPauseActiveForDirection(int direction)
  {
   if(!InpUseSideLossPause ||
      (direction != 1 && direction != -1))
      return(false);

   datetime pauseUntil =
      (direction == 1)
      ? g_buySideLossPauseUntil
      : g_sellSideLossPauseUntil;

   if(pauseUntil <= 0)
      return(false);

   int triggerSAR =
      (direction == 1)
      ? g_buySideLossPauseTriggerSARDirection
      : g_sellSideLossPauseTriggerSARDirection;

   if(InpSideLossPauseUntilSARFlip &&
      triggerSAR != 0 &&
      g_activeSARDirection != 0 &&
      g_activeSARDirection != triggerSAR)
     {
      Print("SIDE LOSS PAUSE FINISHED BY SAR FLIP",
            " | Direction=",DirectionText(direction),
            " | TriggerSAR=",DirectionText(triggerSAR),
            " | CurrentSAR=",DirectionText(g_activeSARDirection));

      ClearSideLossPause(
         direction,
         "FINISHED BY SAR FLIP");
      return(false);
     }

   if(TimeCurrent() >= pauseUntil)
     {
      Print("SIDE LOSS PAUSE FINISHED BY TIME",
            " | Direction=",DirectionText(direction),
            " | EndedAt=",
            TimeToString(pauseUntil,
                         TIME_DATE|TIME_SECONDS));

      ClearSideLossPause(
         direction,
         "FINISHED BY TIME");
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
string SideLossPauseStatusText(int direction)
  {
   if(!InpUseSideLossPause)
      return("OFF");

   if(IsSideLossPauseActiveForDirection(direction))
     {
      datetime pauseUntil =
         (direction == 1)
         ? g_buySideLossPauseUntil
         : g_sellSideLossPauseUntil;

      int remaining =
         (int)MathMax(0,pauseUntil-TimeCurrent());

      return("BLOCK " + DirectionText(direction) +
             " | " + FormatSecondsToHHMM(remaining));
     }

   return(direction == 1
          ? g_buySideLossPauseStatus
          : g_sellSideLossPauseStatus);
  }

//+------------------------------------------------------------------+
void UpdateSideLossPauseState(bool forceScan=false)
  {
   if(!InpUseSideLossPause)
     {
      g_buySideLossStreak = 0;
      g_sellSideLossStreak = 0;
      ClearSideLossPause(1,"OFF");
      ClearSideLossPause(-1,"OFF");
      return;
     }

   datetime now = TimeCurrent();

   if(!forceScan &&
      g_sideLossPauseLastScanTime > 0 &&
      now-g_sideLossPauseLastScanTime < 2)
     {
      IsSideLossPauseActiveForDirection(1);
      IsSideLossPauseActiveForDirection(-1);
      return;
     }

   g_sideLossPauseLastScanTime = now;

   int buyLatestTicket = 0;
   int sellLatestTicket = 0;
   datetime buyLatestCloseTime = 0;
   datetime sellLatestCloseTime = 0;

   g_buySideLossStreak =
      GetCurrentSideConsecutiveLosses(
         1,
         buyLatestTicket,
         buyLatestCloseTime);

   g_sellSideLossStreak =
      GetCurrentSideConsecutiveLosses(
         -1,
         sellLatestTicket,
         sellLatestCloseTime);

   int required =
      MathMax(1,InpSideLossPauseAfterLosses);
   int pauseSeconds =
      MathMax(1,InpSideLossPauseMinutes)*60;

   if(g_buySideLossStreak >= required &&
      buyLatestTicket > 0 &&
      buyLatestTicket !=
      g_buySideLossPauseTriggerTicket)
     {
      g_buySideLossPauseTriggerTicket =
         buyLatestTicket;
      g_buySideLossPauseTriggerCloseTime =
         buyLatestCloseTime;
      g_buySideLossPauseTriggerSARDirection =
         g_activeSARDirection;
      g_buySideLossPauseUntil =
         now+pauseSeconds;
      g_buySideLossPauseStatus =
         "BLOCK BUY | LOSS " +
         IntegerToString(g_buySideLossStreak) +
         "/" + IntegerToString(required);

      Print("SIDE LOSS PAUSE STARTED",
            " | Direction=BUY",
            " | ConsecutiveLosses=",
            g_buySideLossStreak,
            "/",required,
            " | TriggerTicket=",
            buyLatestTicket,
            " | TriggerClose=",
            TimeToString(buyLatestCloseTime,
                         TIME_DATE|TIME_SECONDS),
            " | PauseUntil=",
            TimeToString(g_buySideLossPauseUntil,
                         TIME_DATE|TIME_SECONDS),
            " | TriggerSAR=",
            DirectionText(
               g_buySideLossPauseTriggerSARDirection));

      if(InpNotifyOnTradingPausedReason && InpNotifyOnSideLossPause)
        {
         NotifyTradingPausedReasonOnce(
            "SIDE_LOSS_BUY_" + IntegerToString(buyLatestTicket),
            "BUY TRADING PAUSED - SIDE LOSS",
            "Reason: BUY consecutive losses " +
            IntegerToString(g_buySideLossStreak) + "/" +
            IntegerToString(required) +
            " | Ticket " + IntegerToString(buyLatestTicket) +
            " | Resume " + TimeToString(g_buySideLossPauseUntil,TIME_DATE|TIME_MINUTES) +
            " | " + GetPauseClockDetails());
        }

      if(InpDeletePendingOnSideLossPause)
         DeletePendingOrdersByDirection(
            1,
            "BUY SIDE LOSS PAUSE",
            false);
     }

   if(g_sellSideLossStreak >= required &&
      sellLatestTicket > 0 &&
      sellLatestTicket !=
      g_sellSideLossPauseTriggerTicket)
     {
      g_sellSideLossPauseTriggerTicket =
         sellLatestTicket;
      g_sellSideLossPauseTriggerCloseTime =
         sellLatestCloseTime;
      g_sellSideLossPauseTriggerSARDirection =
         g_activeSARDirection;
      g_sellSideLossPauseUntil =
         now+pauseSeconds;
      g_sellSideLossPauseStatus =
         "BLOCK SELL | LOSS " +
         IntegerToString(g_sellSideLossStreak) +
         "/" + IntegerToString(required);

      Print("SIDE LOSS PAUSE STARTED",
            " | Direction=SELL",
            " | ConsecutiveLosses=",
            g_sellSideLossStreak,
            "/",required,
            " | TriggerTicket=",
            sellLatestTicket,
            " | TriggerClose=",
            TimeToString(sellLatestCloseTime,
                         TIME_DATE|TIME_SECONDS),
            " | PauseUntil=",
            TimeToString(g_sellSideLossPauseUntil,
                         TIME_DATE|TIME_SECONDS),
            " | TriggerSAR=",
            DirectionText(
               g_sellSideLossPauseTriggerSARDirection));

      if(InpNotifyOnTradingPausedReason && InpNotifyOnSideLossPause)
        {
         NotifyTradingPausedReasonOnce(
            "SIDE_LOSS_SELL_" + IntegerToString(sellLatestTicket),
            "SELL TRADING PAUSED - SIDE LOSS",
            "Reason: SELL consecutive losses " +
            IntegerToString(g_sellSideLossStreak) + "/" +
            IntegerToString(required) +
            " | Ticket " + IntegerToString(sellLatestTicket) +
            " | Resume " + TimeToString(g_sellSideLossPauseUntil,TIME_DATE|TIME_MINUTES) +
            " | " + GetPauseClockDetails());
        }

      if(InpDeletePendingOnSideLossPause)
         DeletePendingOrdersByDirection(
            -1,
            "SELL SIDE LOSS PAUSE",
            false);
     }

   IsSideLossPauseActiveForDirection(1);
   IsSideLossPauseActiveForDirection(-1);
  }

//+------------------------------------------------------------------+
bool IsOrderBlockedBySideLossPause(int direction,string source)
  {
   UpdateSideLossPauseState(false);

   if(!IsSideLossPauseActiveForDirection(direction))
      return(false);

   datetime pauseUntil =
      (direction == 1)
      ? g_buySideLossPauseUntil
      : g_sellSideLossPauseUntil;

   string message =
      "SIDE LOSS PAUSE | Direction=" +
      DirectionText(direction) +
      " | Remaining=" +
      FormatSecondsToHHMM(
         (int)MathMax(0,pauseUntil-TimeCurrent())) +
      " | Source=" + source;

   SetLastOrderBlockDashboard(message);
   Print("ORDER BLOCKED | ",message);
   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountRecentProfitableOrdersForMarketFlow(int direction)
  {
   int count = 0;
   datetime fromTime = TimeCurrent() - MathMax(1, InpMarketFlowProfitHours) * 3600;

   if(InpUseFreshDayStart &&
      InpFreshDayIgnorePreviousTradeHistory &&
      g_freshDayHistoryCutoffTime > fromTime)
      fromTime = g_freshDayHistoryCutoffTime;

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
//+------------------------------------------------------------------+
//| Opening-balance dynamic lot helpers                              |
//+------------------------------------------------------------------+
double GetFreshDayStrategyReferenceBalance()
  {
   // Unified tester/live behaviour: every new day uses the actual balance
   // captured at that day boundary. Only the time source differs.
   if(InpAutoUseCurrentBalanceBase && g_dayStartBalance > 0.0)
      return(g_dayStartBalance);

   if(!InpAutoUseCurrentBalanceBase && InpManualBaseCapitalUSD > 0.0)
      return(InpManualBaseCapitalUSD);

   return(MathMax(0.0,AccountBalance()));
  }

//+------------------------------------------------------------------+
//| Actual equity anchor for the current daily cycle.                |
//+------------------------------------------------------------------+
double GetEquityCycleAnchor()
  {
   if(g_equityCycleAnchor > 0.0)
      return(g_equityCycleAnchor);

   if(g_dayStartEquity > 0.0)
      return(g_dayStartEquity);

   if(g_baseBalance > 0.0)
      return(g_baseBalance);

   return(MathMax(0.0,AccountEquity()));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDynamicLotReferenceBalance()
  {
   if(g_baseBalance > 0.0)
      return(g_baseBalance);

   if(g_dayStartBalance > 0.0)
      return(g_dayStartBalance);

   return(MathMax(0.0,AccountBalance()));
  }

//+------------------------------------------------------------------+
double GetCurrentTradingLot()
  {
   if(!InpUseDynamicBalanceLot)
      return(NormalizeLot(InpFixedLot));

   double balanceStep = MathMax(0.01,InpDynamicLotBalanceStepUSD);
   double lotPerStep  = MathMax(0.0001,InpDynamicLotPerBalanceStep);
   double referenceBalance = GetDynamicLotReferenceBalance();

   // Use complete balance steps. Example: $10-$19.99=0.01, $20-$29.99=0.02.
   double completedSteps = MathFloor((referenceBalance + 0.0000001) / balanceStep);
   if(completedSteps < 1.0)
      completedSteps = 1.0;

   double lot = completedSteps * lotPerStep;

   if(InpDynamicLotMinimum > 0.0)
      lot = MathMax(lot,InpDynamicLotMinimum);

   if(InpDynamicLotMaximum > 0.0)
      lot = MathMin(lot,InpDynamicLotMaximum);

   return(NormalizeLot(lot));
  }

//+------------------------------------------------------------------+
double GetCurrentRecoveryTradingLot()
  {
   if(InpUseDynamicBalanceLot)
      return(GetCurrentTradingLot());

   return(NormalizeLot(InpRecoveryGapLot));
  }

//+------------------------------------------------------------------+
double GetDynamicLotMoneyMultiplier()
  {
   if(!InpUseDynamicBalanceLot ||
      !InpScaleTradeMoneyWithDynamicLot)
      return(1.0);

   double baseLot = MathMax(0.0001,InpDynamicLotPerBalanceStep);
   return(MathMax(0.01,GetCurrentTradingLot() / baseLot));
  }

//+------------------------------------------------------------------+
double ScaleTradeMoneyByCurrentLot(double baseUSD)
  {
   return(baseUSD * GetDynamicLotMoneyMultiplier());
  }

//+------------------------------------------------------------------+
string DynamicLotStatusText()
  {
   return("$" + DoubleToString(GetDynamicLotReferenceBalance(),2) +
          " -> " + DoubleToString(GetCurrentTradingLot(),2) +
          " lot | X" + DoubleToString(GetDynamicLotMoneyMultiplier(),2));
  }

//+------------------------------------------------------------------+
//| Average RAW height of the latest CLOSED M1 candles              |
//+------------------------------------------------------------------+
double GetAverageClosedM1CandleHeightRaw()
  {
   int requestedBars = InpAverageM1CandleSLBars;
   if(requestedBars < 1)
      requestedBars = 1;

   int availableBars = iBars(Symbol(), PERIOD_M1);
   if(availableBars <= 1)
      return(0.0);

   int usableBars = requestedBars;
   if(usableBars > availableBars - 1)
      usableBars = availableBars - 1;

   double totalHeightRaw = 0.0;
   int validBars = 0;

   for(int shift = 1; shift <= usableBars; shift++)
     {
      double candleHigh = iHigh(Symbol(), PERIOD_M1, shift);
      double candleLow  = iLow(Symbol(), PERIOD_M1, shift);

      if(candleHigh <= 0.0 || candleLow <= 0.0)
         continue;

      double candleHeightRaw = candleHigh - candleLow;
      if(candleHeightRaw <= 0.0)
         continue;

      totalHeightRaw += candleHeightRaw;
      validBars++;
     }

   if(validBars <= 0)
      return(0.0);

   return(totalHeightRaw / validBars);
  }

//+------------------------------------------------------------------+
//| Convert a RAW-price distance into estimated USD P/L             |
//+------------------------------------------------------------------+
double ConvertRawPriceDistanceToUSD(double rawDistance, double lots)
  {
   if(rawDistance <= 0.0 || lots <= 0.0)
      return(0.0);

   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   if(tickSize <= 0.0 || tickValue <= 0.0)
     {
      Print("AVERAGE M1 SL ERROR",
            " | Invalid tick information",
            " | TickSize=", DoubleToString(tickSize, 8),
            " | TickValue=", DoubleToString(tickValue, 8));
      return(0.0);
     }

   double tickCount = rawDistance / tickSize;
   return(MathAbs(tickCount * tickValue * lots));
  }

//+------------------------------------------------------------------+
//| Basket SL derived from the average closed-M1 candle height      |
//+------------------------------------------------------------------+
double GetAverageM1CandleBasketStopLossUSD()
  {
   if(!InpUseAverageM1CandleBasketSL)
      return(0.0);

   double averageHeightRaw = GetAverageClosedM1CandleHeightRaw();
   if(averageHeightRaw <= 0.0)
      return(0.0);

   double multiplier = MathMax(0.0, InpAverageM1CandleSLMultiplier);
   double effectiveHeightRaw = averageHeightRaw * multiplier;

   double basketSLUSD = ConvertRawPriceDistanceToUSD(effectiveHeightRaw, GetCurrentTradingLot());
   if(basketSLUSD <= 0.0)
      return(0.0);

   if(ScaleTradeMoneyByCurrentLot(InpAverageM1CandleSLMinimumUSD) > 0.0)
      basketSLUSD = MathMax(basketSLUSD, ScaleTradeMoneyByCurrentLot(InpAverageM1CandleSLMinimumUSD));

   if(ScaleTradeMoneyByCurrentLot(InpAverageM1CandleSLMaximumUSD) > 0.0)
      basketSLUSD = MathMin(basketSLUSD, ScaleTradeMoneyByCurrentLot(InpAverageM1CandleSLMaximumUSD));

   return(MathMax(0.0, basketSLUSD));
  }

//+------------------------------------------------------------------+
//| Select the base basket SL                                       |
//+------------------------------------------------------------------+
double GetBaseEffectiveBasketStopLossUSD()
  {
   double marketModeSL = 0.0;

   if(InpUseSimpleSideBasketCloseOnly)
      marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketStopLossUSD));
   else
      if(!InpUseAutoMarketFlowMode)
         marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketStopLossUSD));
      else
         if(g_autoMarketMode == DXB_MARKET_MODE_CONTINUOUS)
            marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpContinuousTrendBasketSLUSD));
         else
            if(g_autoMarketMode == DXB_MARKET_MODE_MEDIUM)
               marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpMediumTrendBasketSLUSD));
            else
               if(g_autoMarketMode == DXB_MARKET_MODE_MIXED)
                  marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpMixedTrendBasketSLUSD));
               else
                  if(g_autoMarketMode == DXB_MARKET_MODE_DANGER)
                     marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpDangerModeBasketSLUSD));
                  else
                     marketModeSL = MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketStopLossUSD));

   if(!InpUseAverageM1CandleBasketSL)
      return(marketModeSL);

   double averageM1SL = GetAverageM1CandleBasketStopLossUSD();
   if(averageM1SL <= 0.0)
      return(marketModeSL);

   // 1 = use the tighter/smaller value.
   if(InpAverageM1CandleSLCombineMode == 1)
     {
      if(marketModeSL <= 0.0)
         return(averageM1SL);
      return(MathMin(marketModeSL, averageM1SL));
     }

   // 2 = use the wider/larger value.
   if(InpAverageM1CandleSLCombineMode == 2)
      return(MathMax(marketModeSL, averageM1SL));

   // 0/default = average M1 candle SL replaces market-mode SL.
   return(averageM1SL);
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
                  MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD)) / 2.0));
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
                     ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD) / simpleCount));
     }

   int hourNow = TimeHour(TimeCurrent());

   int count = CountOpenOrders();

   if(count <= 0)
      count = 1;

   double baseTarget = ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD);

   if(hourNow >= 12 && hourNow <= 17)
      baseTarget = ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD_12_17);

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
                " | GMT0 " + TimeToString(GetGMT0Time(), TIME_DATE|TIME_SECONDS);

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

// A strongly profitable FIRST SAR order confirms a good market and queues
// one immediate same-direction pending continuation entry.
   QueueGoodMarketContinuationFromClosedTicket(ticket,
                                                type,
                                                profit,
                                                closePrice);

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
      if(!IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
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

// Live tick-speed engine state. BUY/SELL trading logic does not depend on it.
uint     g_tickSpeedWindowStartMs       = 0;
uint     g_tickSpeedLastTickMs          = 0;
double   g_tickSpeedWindowStartPrice    = 0.0;
double   g_tickSpeedWindowMinPrice      = 0.0;
double   g_tickSpeedWindowMaxPrice      = 0.0;
double   g_tickSpeedWindowLastPrice     = 0.0;
double   g_tickSpeedWindowPath          = 0.0;
int      g_tickSpeedWindowTicks         = 0;
int      g_tickSpeedCompletedWindows    = 0;
double   g_tickSpeedLastWindowNetMove   = 0.0;
double   g_tickSpeedLastWindowRange     = 0.0;
double   g_tickSpeedLastWindowPath      = 0.0;
double   g_tickSpeedLastWindowTickRate  = 0.0;
double   g_tickSpeedBaselineTickRate    = 0.0;

double   g_tickSpeedAvgCandleRange      = 0.0;
double   g_tickSpeedCurrentCandleRange  = 0.0;
double   g_tickSpeedCandleRatio         = 0.0;
double   g_tickSpeedRecentNetMove       = 0.0;
double   g_tickSpeedRecentRange         = 0.0;
double   g_tickSpeedRecentPath          = 0.0;
double   g_tickSpeedWindowMoveRatio     = 0.0;
double   g_tickSpeedWindowPathRatio     = 0.0;
double   g_tickSpeedCurrentTickRate     = 0.0;
double   g_tickSpeedTickRateRatio       = 1.0;
int      g_tickSpeedCandleElapsedSec    = 0;
string   g_tickSpeedStatus              = "WARMING UP";

// BUY and SELL keep independent adaptive SL snapshots.
double   g_buyTickSpeedLockedSL          = 0.0;
double   g_sellTickSpeedLockedSL         = 0.0;
double   g_buyTickSpeedLockedBaseSL      = 0.0;
double   g_sellTickSpeedLockedBaseSL     = 0.0;
string   g_buyTickSpeedLockedStatus      = "WAIT ORDER";
string   g_sellTickSpeedLockedStatus     = "WAIT ORDER";
string   g_buyTickSpeedLockedMode        = "WAIT MODE";
string   g_sellTickSpeedLockedMode       = "WAIT MODE";
datetime g_buyTickSpeedSLActivatedTime   = 0;
datetime g_sellTickSpeedSLActivatedTime  = 0;

// Live opposite-candle emergency SL state. BUY and SELL are independent.
// The tightened level is latched and is reset only after that side basket ends.
bool     g_buyLiveOppositeCandleSLArmed   = false;
bool     g_sellLiveOppositeCandleSLArmed  = false;
double   g_buyLiveOppositeCandleSLUSD     = 0.0;
double   g_sellLiveOppositeCandleSLUSD    = 0.0;
datetime g_buyLiveOppositeCandleArmTime   = 0;
datetime g_sellLiveOppositeCandleArmTime  = 0;
double   g_liveOppositeCurrentM1Range     = 0.0;
double   g_liveOppositePreviousM1Range    = 0.0;
double   g_liveOppositeM1RangeRatio       = 0.0;
double   g_liveOppositeCurrentBodyPercent = 0.0;
int      g_liveOppositeCurrentDirection   = 0;

//+------------------------------------------------------------------+
//| Convert the current tick-speed status into one SL snapshot.      |
//+------------------------------------------------------------------+
double GetTickSpeedAdaptiveBasketSLUSD(string speedStatus)
  {
   double baseSL = MathAbs(GetBaseEffectiveBasketStopLossUSD());
   if(baseSL <= 0.0)
      return(0.0);

   double multiplier = MathMax(0.0,InpTickSpeedWarmupSLMultiplier);

   if(speedStatus == "SLOW")
      multiplier = MathMax(0.0,InpTickSpeedSlowSLMultiplier);
   else
   if(speedStatus == "NORMAL")
      multiplier = MathMax(0.0,InpTickSpeedNormalSLMultiplier);
   else
   if(speedStatus == "FAST")
      multiplier = MathMax(0.0,InpTickSpeedFastSLMultiplier);
   else
   if(speedStatus == "DANGER")
      multiplier = MathMax(0.0,InpTickSpeedDangerSLMultiplier);

   double adaptiveSL = baseSL * multiplier;

   if(ScaleTradeMoneyByCurrentLot(InpTickSpeedAdaptiveSLMaxUSD) > 0.0)
      adaptiveSL = MathMin(adaptiveSL,MathAbs(ScaleTradeMoneyByCurrentLot(InpTickSpeedAdaptiveSLMaxUSD)));

   return(MathMax(0.0,adaptiveSL));
  }

//+------------------------------------------------------------------+
//| Snapshot/reset BUY and SELL adaptive SL independently.           |
//+------------------------------------------------------------------+
void UpdateTickSpeedAdaptiveBasketSLLocks()
  {
   if(!InpUseTickSpeedAdaptiveBasketSL)
     {
      g_buyTickSpeedLockedSL = 0.0;
      g_sellTickSpeedLockedSL = 0.0;
      g_buyTickSpeedLockedBaseSL = 0.0;
      g_sellTickSpeedLockedBaseSL = 0.0;
      g_buyTickSpeedLockedStatus = "OFF";
      g_sellTickSpeedLockedStatus = "OFF";
      g_buyTickSpeedLockedMode = "OFF";
      g_sellTickSpeedLockedMode = "OFF";
      return;
     }

   int buyCount = CountOrdersByDirection(1);
   int sellCount = CountOrdersByDirection(-1);

   if(buyCount <= 0)
     {
      g_buyTickSpeedLockedSL = 0.0;
      g_buyTickSpeedLockedBaseSL = 0.0;
      g_buyTickSpeedLockedStatus = "WAIT ORDER";
      g_buyTickSpeedLockedMode = "WAIT MODE";
      g_buyTickSpeedSLActivatedTime = 0;
     }
   else
   if(g_buyTickSpeedLockedSL <= 0.0)
     {
      g_buyTickSpeedLockedBaseSL = MathAbs(GetBaseEffectiveBasketStopLossUSD());
      g_buyTickSpeedLockedMode = g_autoMarketModeText;
      g_buyTickSpeedLockedSL = GetTickSpeedAdaptiveBasketSLUSD(g_tickSpeedStatus);
      g_buyTickSpeedLockedStatus = g_tickSpeedStatus;
      g_buyTickSpeedSLActivatedTime = TimeCurrent();
      Print("TICK SPEED SL SNAPSHOT | BUY | Mode=",g_buyTickSpeedLockedMode,
            " | Speed=",g_buyTickSpeedLockedStatus,
            " | BaseSL=$",DoubleToString(g_buyTickSpeedLockedBaseSL,2),
            " | LockedSL=$",DoubleToString(g_buyTickSpeedLockedSL,2),
            " | Orders=",buyCount);
     }

   if(sellCount <= 0)
     {
      g_sellTickSpeedLockedSL = 0.0;
      g_sellTickSpeedLockedBaseSL = 0.0;
      g_sellTickSpeedLockedStatus = "WAIT ORDER";
      g_sellTickSpeedLockedMode = "WAIT MODE";
      g_sellTickSpeedSLActivatedTime = 0;
     }
   else
   if(g_sellTickSpeedLockedSL <= 0.0)
     {
      g_sellTickSpeedLockedBaseSL = MathAbs(GetBaseEffectiveBasketStopLossUSD());
      g_sellTickSpeedLockedMode = g_autoMarketModeText;
      g_sellTickSpeedLockedSL = GetTickSpeedAdaptiveBasketSLUSD(g_tickSpeedStatus);
      g_sellTickSpeedLockedStatus = g_tickSpeedStatus;
      g_sellTickSpeedSLActivatedTime = TimeCurrent();
      Print("TICK SPEED SL SNAPSHOT | SELL | Mode=",g_sellTickSpeedLockedMode,
            " | Speed=",g_sellTickSpeedLockedStatus,
            " | BaseSL=$",DoubleToString(g_sellTickSpeedLockedBaseSL,2),
            " | LockedSL=$",DoubleToString(g_sellTickSpeedLockedSL,2),
            " | Orders=",sellCount);
     }
  }

//+------------------------------------------------------------------+
double GetNormalEffectiveBasketStopLossUSDForDirection(int direction)
  {
   double baseSL = GetBaseEffectiveBasketStopLossUSD();

   if(!InpUseTickSpeedAdaptiveBasketSL)
      return(baseSL);

   if(direction > 0 && g_buyTickSpeedLockedSL > 0.0)
      return(g_buyTickSpeedLockedSL);

   if(direction < 0 && g_sellTickSpeedLockedSL > 0.0)
      return(g_sellTickSpeedLockedSL);

   // Before a snapshot exists, use the current status calculation. This is
   // normally only the activation tick before Update... locks the value.
   return(GetTickSpeedAdaptiveBasketSLUSD(g_tickSpeedStatus));
  }

//+------------------------------------------------------------------+
// Final live SL for one side. The opposite-candle rule may only tighten the
// normal frozen adaptive SL; it can never widen it.
//+------------------------------------------------------------------+
double GetEffectiveBasketStopLossUSDForDirection(int direction)
  {
   double normalSL = GetNormalEffectiveBasketStopLossUSDForDirection(direction);

   if(normalSL <= 0.0 || !InpUseLiveOppositeCandleTightSL)
      return(normalSL);

   double tightenedSL = 0.0;

   if(direction > 0 && g_buyLiveOppositeCandleSLArmed)
      tightenedSL = g_buyLiveOppositeCandleSLUSD;
   else
   if(direction < 0 && g_sellLiveOppositeCandleSLArmed)
      tightenedSL = g_sellLiveOppositeCandleSLUSD;

   if(tightenedSL > 0.0)
      return(MathMin(normalSL,tightenedSL));

   return(normalSL);
  }

// Compatibility wrapper for existing status/dashboard calls.
double GetEffectiveBasketStopLossUSD()
  {
   bool hasBuy = (CountOrdersByDirection(1) > 0);
   bool hasSell = (CountOrdersByDirection(-1) > 0);

   if(hasBuy && !hasSell)
      return(GetEffectiveBasketStopLossUSDForDirection(1));
   if(hasSell && !hasBuy)
      return(GetEffectiveBasketStopLossUSDForDirection(-1));
   if(hasBuy && hasSell)
      return(MathMax(GetEffectiveBasketStopLossUSDForDirection(1),
                     GetEffectiveBasketStopLossUSDForDirection(-1)));

   return(GetBaseEffectiveBasketStopLossUSD());
  }

//+------------------------------------------------------------------+
string TickSpeedAdaptiveSLStatusText(int direction)
  {
   double lockedSL = (direction > 0)
                     ? g_buyTickSpeedLockedSL
                     : g_sellTickSpeedLockedSL;
   double lockedBaseSL = (direction > 0)
                         ? g_buyTickSpeedLockedBaseSL
                         : g_sellTickSpeedLockedBaseSL;
   string lockedStatus = (direction > 0)
                         ? g_buyTickSpeedLockedStatus
                         : g_sellTickSpeedLockedStatus;
   string lockedMode = (direction > 0)
                       ? g_buyTickSpeedLockedMode
                       : g_sellTickSpeedLockedMode;

   if(!InpUseTickSpeedAdaptiveBasketSL)
      return("OFF");

   if(lockedSL > 0.0)
      return(lockedMode + "/" + lockedStatus + " $" +
             DoubleToString(lockedBaseSL,2) + ">" +
             DoubleToString(lockedSL,2));

   return("NEXT " + g_autoMarketModeText + "/" + g_tickSpeedStatus + " $" +
          DoubleToString(MathAbs(GetBaseEffectiveBasketStopLossUSD()),2) + ">" +
          DoubleToString(GetTickSpeedAdaptiveBasketSLUSD(g_tickSpeedStatus),2));
  }

//+------------------------------------------------------------------+
void ResetLiveOppositeCandleEmergencySLState(int direction)
  {
   if(direction > 0)
     {
      g_buyLiveOppositeCandleSLArmed = false;
      g_buyLiveOppositeCandleSLUSD   = 0.0;
      g_buyLiveOppositeCandleArmTime = 0;
     }
   else
   if(direction < 0)
     {
      g_sellLiveOppositeCandleSLArmed = false;
      g_sellLiveOppositeCandleSLUSD   = 0.0;
      g_sellLiveOppositeCandleArmTime = 0;
     }
  }

//+------------------------------------------------------------------+
bool IsLiveOppositeCandleEmergencySLArmed(int direction)
  {
   if(direction > 0)
      return(g_buyLiveOppositeCandleSLArmed);
   if(direction < 0)
      return(g_sellLiveOppositeCandleSLArmed);
   return(false);
  }

//+------------------------------------------------------------------+
double GetLiveOppositeCandleEmergencySLUSD(int direction)
  {
   if(direction > 0)
      return(g_buyLiveOppositeCandleSLUSD);
   if(direction < 0)
      return(g_sellLiveOppositeCandleSLUSD);
   return(0.0);
  }

//+------------------------------------------------------------------+
// Checks the still-forming M1 candle. No next-candle or candle-close wait.
//+------------------------------------------------------------------+
bool IsCurrentM1CandleLargeAndOpposite(int direction)
  {
   if(direction == 0 || iBars(Symbol(),PERIOD_M1) < 3)
      return(false);

   double currentOpen  = iOpen(Symbol(),PERIOD_M1,0);
   double currentClose = iClose(Symbol(),PERIOD_M1,0);
   double currentHigh  = iHigh(Symbol(),PERIOD_M1,0);
   double currentLow   = iLow(Symbol(),PERIOD_M1,0);
   double previousHigh = iHigh(Symbol(),PERIOD_M1,1);
   double previousLow  = iLow(Symbol(),PERIOD_M1,1);

   g_liveOppositeCurrentM1Range  = MathMax(0.0,currentHigh-currentLow);
   g_liveOppositePreviousM1Range = MathMax(0.0,previousHigh-previousLow);
   g_liveOppositeM1RangeRatio =
      (g_liveOppositePreviousM1Range > 0.0)
      ? g_liveOppositeCurrentM1Range/g_liveOppositePreviousM1Range
      : 0.0;

   double body = MathAbs(currentClose-currentOpen);
   g_liveOppositeCurrentBodyPercent =
      (g_liveOppositeCurrentM1Range > 0.0)
      ? body/g_liveOppositeCurrentM1Range*100.0
      : 0.0;

   if(currentClose > currentOpen)
      g_liveOppositeCurrentDirection = 1;
   else
   if(currentClose < currentOpen)
      g_liveOppositeCurrentDirection = -1;
   else
      g_liveOppositeCurrentDirection = 0;

   bool oppositeDirection =
      (direction > 0 && g_liveOppositeCurrentDirection < 0) ||
      (direction < 0 && g_liveOppositeCurrentDirection > 0);

   double requiredRange =
      g_liveOppositePreviousM1Range *
      MathMax(0.0,InpLiveOppositeCandleRangeRatio);

   bool largerThanPrevious =
      (g_liveOppositeCurrentM1Range > requiredRange);

   bool bodyConfirmed =
      (InpLiveOppositeCandleMinBodyPercent <= 0.0 ||
       g_liveOppositeCurrentBodyPercent >=
       MathMin(100.0,InpLiveOppositeCandleMinBodyPercent));

   return(oppositeDirection && largerThanPrevious && bodyConfirmed);
  }

//+------------------------------------------------------------------+
// Arms a smaller basket SL as soon as the current M1 candle becomes larger
// than the previous M1 candle and moves against an already-losing side.
// The reduced value is latched, so a later intrabar reversal cannot widen it.
//+------------------------------------------------------------------+
void UpdateLiveOppositeCandleEmergencySL()
  {
   if(!InpUseLiveOppositeCandleTightSL)
     {
      ResetLiveOppositeCandleEmergencySLState(1);
      ResetLiveOppositeCandleEmergencySLState(-1);
      return;
     }

   for(int direction=1; direction>=-1; direction-=2)
     {
      int orderCount = CountOrdersByDirection(direction);

      if(orderCount <= 0)
        {
         ResetLiveOppositeCandleEmergencySLState(direction);
         continue;
        }

      if(IsLiveOppositeCandleEmergencySLArmed(direction))
         continue;

      double sideProfit = GetBasketProfit(direction);

      // The user's requested protection starts only after loss has begun.
      if(sideProfit >= 0.0)
         continue;

      if(!IsCurrentM1CandleLargeAndOpposite(direction))
         continue;

      double normalSL =
         MathAbs(GetNormalEffectiveBasketStopLossUSDForDirection(direction));

      if(normalSL <= 0.0)
         continue;

      double multiplier =
         MathMax(0.0,MathMin(1.0,InpLiveOppositeCandleSLMultiplier));
      double tightenedSL = normalSL*multiplier;
      tightenedSL = MathMax(MathAbs(ScaleTradeMoneyByCurrentLot(InpLiveOppositeCandleMinimumSLUSD)),
                            tightenedSL);
      tightenedSL = MathMin(normalSL,tightenedSL);
      tightenedSL = NormalizeDouble(tightenedSL,2);

      if(direction > 0)
        {
         g_buyLiveOppositeCandleSLArmed = true;
         g_buyLiveOppositeCandleSLUSD   = tightenedSL;
         g_buyLiveOppositeCandleArmTime = TimeCurrent();
        }
      else
        {
         g_sellLiveOppositeCandleSLArmed = true;
         g_sellLiveOppositeCandleSLUSD   = tightenedSL;
         g_sellLiveOppositeCandleArmTime = TimeCurrent();
        }

      Print("LIVE OPPOSITE M1 TIGHT SL ARMED | Direction=",
            DirectionText(direction),
            " | Basket=$",DoubleToString(sideProfit,2),
            " | CurrentRange=",DoubleToString(g_liveOppositeCurrentM1Range,1),
            " | PreviousRange=",DoubleToString(g_liveOppositePreviousM1Range,1),
            " | Ratio=",DoubleToString(g_liveOppositeM1RangeRatio,2),"x",
            " | Body=",DoubleToString(g_liveOppositeCurrentBodyPercent,1),"%",
            " | NormalSL=$",DoubleToString(normalSL,2),
            " | TightSL=$",DoubleToString(tightenedSL,2));
     }
  }

//+------------------------------------------------------------------+
string LiveOppositeCandleSLStatusText(int direction)
  {
   if(!InpUseLiveOppositeCandleTightSL)
      return("OFF");

   if(CountOrdersByDirection(direction) <= 0)
      return("WAIT ORDER");

   if(IsLiveOppositeCandleEmergencySLArmed(direction))
      return("ARMED $" +
             DoubleToString(GetLiveOppositeCandleEmergencySLUSD(direction),2));

   return("WATCH");
  }

//+------------------------------------------------------------------+
bool IsOppositeImpulseOrderComment(string commentText)
  {
   return(StringFind(commentText,"OPP_IMPULSE",0) >= 0);
  }

//+------------------------------------------------------------------+
void ClearOppositeImpulseRequest(string reason,bool keepTrackedTicket=false)
  {
   if(g_oppositeImpulseRequestPending ||
      g_oppositeImpulsePendingTicket > 0 ||
      g_oppositeImpulseDirection != 0)
     {
      Print("OPPOSITE IMPULSE STATE | Direction=",
            DirectionText(g_oppositeImpulseDirection),
            " | Source=",DirectionText(g_oppositeImpulseSourceDirection),
            " | Ticket=",g_oppositeImpulsePendingTicket,
            " | Reason=",reason);
     }

   g_oppositeImpulseRequestPending  = false;
   g_oppositeImpulseDirection       = 0;
   g_oppositeImpulseSourceDirection = 0;
   g_oppositeImpulseSourceLoss      = 0.0;
   g_oppositeImpulseSignalBarTime   = 0;
   g_oppositeImpulseQueuedTime      = 0;
   g_oppositeImpulseLastAttemptTime = 0;
   g_oppositeImpulseSignalHigh      = 0.0;
   g_oppositeImpulseSignalLow       = 0.0;
   g_oppositeImpulseSignalRange     = 0.0;
   g_oppositeImpulsePreviousRange   = 0.0;
   g_oppositeImpulseAverageRange    = 0.0;
   g_oppositeImpulseBodyPercent     = 0.0;
   g_oppositeImpulseExitWickPercent = 0.0;
   g_oppositeImpulsePreSAROverride = false;

   if(!keepTrackedTicket)
      g_oppositeImpulsePendingTicket = -1;

   g_oppositeImpulseStatus = reason;
  }

//+------------------------------------------------------------------+
bool IsOppositeImpulseContinuationBusy()
  {
   return(g_oppositeImpulseRequestPending ||
          g_oppositeImpulsePendingTicket > 0);
  }

//+------------------------------------------------------------------+
string OppositeImpulseStatusText()
  {
   if(!InpUseOppositeImpulseContinuation)
      return("OFF");

   if(g_oppositeImpulsePendingTicket > 0)
      return("PENDING #" + IntegerToString(g_oppositeImpulsePendingTicket) +
             " " + DirectionText(g_oppositeImpulseDirection) +
             (g_oppositeImpulsePreSAROverride ? " PRE-SAR" : ""));

   if(g_oppositeImpulseRequestPending)
      return("QUEUED " + DirectionText(g_oppositeImpulseDirection) +
             (g_oppositeImpulsePreSAROverride ? " PRE-SAR" : "") +
             " | " + g_oppositeImpulseStatus);

   return(g_oppositeImpulseStatus);
  }

//+------------------------------------------------------------------+
// Snapshot strict continuation conditions from the still-forming M1 candle.
// losingDirection is the side that is being closed; impulse direction is the
// opposite side.
//+------------------------------------------------------------------+
bool GetCurrentOppositeImpulseSignal(int losingDirection,
                                     int &impulseDirection,
                                     double &signalHigh,
                                     double &signalLow,
                                     double &signalRange,
                                     double &previousRange,
                                     double &averageRange,
                                     double &bodyPercent,
                                     double &exitWickPercent,
                                     string &blockReason)
  {
   impulseDirection = -losingDirection;
   signalHigh        = 0.0;
   signalLow         = 0.0;
   signalRange       = 0.0;
   previousRange     = 0.0;
   averageRange      = 0.0;
   bodyPercent       = 0.0;
   exitWickPercent   = 0.0;
   blockReason       = "NONE";
   g_oppositeImpulsePreSAROverride = false;

   if(!InpUseOppositeImpulseContinuation)
     {
      blockReason = "FEATURE OFF";
      return(false);
     }

   if(losingDirection != 1 && losingDirection != -1)
     {
      blockReason = "INVALID LOSING DIRECTION";
      return(false);
     }

   if(iBars(Symbol(),PERIOD_M1) < 12)
     {
      blockReason = "NOT ENOUGH M1 BARS";
      return(false);
     }

   double candleOpen  = iOpen(Symbol(),PERIOD_M1,0);
   double candleClose = iClose(Symbol(),PERIOD_M1,0);
   signalHigh         = iHigh(Symbol(),PERIOD_M1,0);
   signalLow          = iLow(Symbol(),PERIOD_M1,0);
   double prevHigh    = iHigh(Symbol(),PERIOD_M1,1);
   double prevLow     = iLow(Symbol(),PERIOD_M1,1);

   signalRange   = MathMax(0.0,signalHigh-signalLow);
   previousRange = MathMax(0.0,prevHigh-prevLow);
   averageRange  = g_tickSpeedAvgCandleRange;
   if(averageRange <= 0.0)
      averageRange = GetTickSpeedAverageClosedCandleRange();

   if(signalRange <= 0.0 || previousRange <= 0.0 || averageRange <= 0.0)
     {
      blockReason = "INVALID RANGE DATA";
      return(false);
     }

   int candleDirection = 0;
   if(candleClose > candleOpen)
      candleDirection = 1;
   else
   if(candleClose < candleOpen)
      candleDirection = -1;

   if(candleDirection != impulseDirection)
     {
      blockReason = "LIVE M1 NOT IN IMPULSE DIRECTION";
      return(false);
     }

   double body = MathAbs(candleClose-candleOpen);
   bodyPercent = body/signalRange*100.0;

   double exitWick = 0.0;
   if(impulseDirection < 0)
      exitWick = MathMax(0.0,MathMin(candleOpen,candleClose)-signalLow);
   else
      exitWick = MathMax(0.0,signalHigh-MathMax(candleOpen,candleClose));

   exitWickPercent = exitWick/signalRange*100.0;

   if(signalRange + Point*0.1 <
      previousRange*MathMax(0.0,InpImpulseCurrentVsPreviousRatio))
     {
      blockReason = "LIVE RANGE BELOW PREVIOUS RATIO";
      return(false);
     }

   if(signalRange + Point*0.1 <
      averageRange*MathMax(0.0,InpImpulseCurrentVsAverageRatio))
     {
      blockReason = "LIVE RANGE BELOW AVERAGE RATIO";
      return(false);
     }

   if(bodyPercent + 0.0001 <
      MathMax(0.0,MathMin(100.0,InpImpulseMinimumBodyPercent)))
     {
      blockReason = "BODY TOO SMALL";
      return(false);
     }

   if(exitWickPercent - 0.0001 >
      MathMax(0.0,MathMin(100.0,InpImpulseMaximumExitWickPercent)))
     {
      blockReason = "EXIT WICK TOO LARGE";
      return(false);
     }

   if(InpImpulseRequireFastTickSpeed &&
      g_tickSpeedStatus != "FAST" &&
      g_tickSpeedStatus != "DANGER")
     {
      blockReason = "TICK SPEED " + g_tickSpeedStatus;
      return(false);
     }

   if(InpImpulseRequireLiveSARDirection)
     {
      int liveSAR = GetSARDotDirection(0);
      if(liveSAR != impulseDirection)
        {
         bool preSARAllowed = InpImpulseAllowPreSARReversalOverride;

         if(InpImpulsePreSARRequireDangerSpeed &&
            g_tickSpeedStatus != "DANGER")
            preSARAllowed = false;

         double preSARMinBody =
            MathMax(0.0,MathMin(100.0,
                               InpImpulsePreSARMinimumBodyPercent));
         double preSARMaxWick =
            MathMax(0.0,MathMin(100.0,
                               InpImpulsePreSARMaximumExitWickPercent));

         if(bodyPercent + 0.0001 < preSARMinBody)
            preSARAllowed = false;

         if(exitWickPercent - 0.0001 > preSARMaxWick)
            preSARAllowed = false;

         if(!preSARAllowed)
           {
            blockReason = "LIVE SAR " + DirectionText(liveSAR) +
                          " != " + DirectionText(impulseDirection) +
                          " | PRE-SAR NEED DANGER/BODY/WICK";
            return(false);
           }

         g_oppositeImpulsePreSAROverride = true;
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
bool QueueOppositeImpulseContinuation(int losingDirection,double sourceLoss)
  {
   if(g_oppositeImpulseRequestPending ||
      g_oppositeImpulsePendingTicket > 0)
     {
      Print("OPPOSITE IMPULSE NOT QUEUED | Existing state | ",
            OppositeImpulseStatusText());
      return(false);
     }

   int impulseDirection = 0;
   double signalHigh = 0.0;
   double signalLow = 0.0;
   double signalRange = 0.0;
   double previousRange = 0.0;
   double averageRange = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;
   string blockReason = "NONE";

   if(!GetCurrentOppositeImpulseSignal(losingDirection,
                                       impulseDirection,
                                       signalHigh,
                                       signalLow,
                                       signalRange,
                                       previousRange,
                                       averageRange,
                                       bodyPercent,
                                       exitWickPercent,
                                       blockReason))
     {
      g_oppositeImpulseStatus = "NOT QUEUED | " + blockReason;
      Print("OPPOSITE IMPULSE NOT QUEUED | LosingSide=",
            DirectionText(losingDirection),
            " | Reason=",blockReason,
            " | TickSpeed=",g_tickSpeedStatus,
            " | LiveSAR=",DirectionText(GetSARDotDirection(0)));
      return(false);
     }

   // A loss-driven impulse setup takes priority over any old profitable
   // continuation request so both strategies cannot place orders together.
   ClearGoodMarketContinuation("CANCELLED | OPPOSITE IMPULSE PRIORITY");

   g_oppositeImpulseRequestPending  = true;
   g_oppositeImpulseDirection       = impulseDirection;
   g_oppositeImpulseSourceDirection = losingDirection;
   g_oppositeImpulseSourceLoss      = sourceLoss;
   g_oppositeImpulseSignalBarTime   = iTime(Symbol(),PERIOD_M1,0);
   g_oppositeImpulseQueuedTime      = TimeCurrent();
   g_oppositeImpulseLastAttemptTime = 0;
   g_oppositeImpulseSignalHigh      = signalHigh;
   g_oppositeImpulseSignalLow       = signalLow;
   g_oppositeImpulseSignalRange     = signalRange;
   g_oppositeImpulsePreviousRange   = previousRange;
   g_oppositeImpulseAverageRange    = averageRange;
   g_oppositeImpulseBodyPercent     = bodyPercent;
   g_oppositeImpulseExitWickPercent = exitWickPercent;
   g_oppositeImpulsePendingTicket   = -1;
   g_oppositeImpulseStatus          =
      g_oppositeImpulsePreSAROverride ? "QUEUED PRE-SAR" : "QUEUED SAR CONFIRMED";

   Print("OPPOSITE IMPULSE QUEUED | ClosedSide=",
         DirectionText(losingDirection),
         " | NewDirection=",DirectionText(impulseDirection),
         " | SourceLoss=$",DoubleToString(sourceLoss,2),
         " | Range=",DoubleToString(signalRange,1),
         " | Prev=",DoubleToString(previousRange,1),
         " | Avg=",DoubleToString(averageRange,1),
         " | Body=",DoubleToString(bodyPercent,1),"%",
         " | ExitWick=",DoubleToString(exitWickPercent,1),"%",
         " | TickSpeed=",g_tickSpeedStatus,
         " | LiveSAR=",DirectionText(GetSARDotDirection(0)),
         " | Confirmation=",
         (g_oppositeImpulsePreSAROverride ? "PRE-SAR DANGER OVERRIDE" : "SAR MATCH"));

   return(true);
  }

//+------------------------------------------------------------------+
// Queue one opposite pending order BEFORE SAR fully flips when the current
// live M1 candle strongly suggests reversal against an existing old-side
// basket. This does not wait for the old basket to close.
//+------------------------------------------------------------------+
bool TryQueuePreSARReversalSuspectEntry()
  {
   if(!InpUseOppositeImpulseContinuation ||
      !InpUsePreSARReversalSuspectEntry)
      return(false);

   if(IsOppositeImpulseContinuationBusy())
      return(false);

   int oldDirection = GetSARDotDirection(0);

   if(oldDirection != 1 && oldDirection != -1)
      return(false);

   // The suspect strategy can work in two situations:
   // 1. An old-direction market basket is still open.
   // 2. No market basket exists, but a strong opposite reversal is detected.
   bool hasOldSideBasket =
      (CountOrdersByDirection(oldDirection) > 0);

   double oldSideProfit = 0.0;

   if(hasOldSideBasket)
      oldSideProfit = GetBasketProfit(oldDirection);

   int newDirection = -oldDirection;

   // Never duplicate an already-live or pending opposite-side entry.
   if(CountDirectionEntriesForCap(newDirection) > 0)
     {
      g_oppositeImpulseStatus =
         "SUSPECT BLOCKED | OPPOSITE SIDE EXISTS";

      return(false);
     }

   // Apply the old-side profit restriction only when that basket exists.
   if(hasOldSideBasket &&
      InpPreSARSuspectRequireOldSideNotProfit &&
      oldSideProfit > ScaleTradeMoneyByCurrentLot(InpPreSARSuspectMaxOldSideProfitUSD))
     {
      g_oppositeImpulseStatus =
         "SUSPECT WAIT | OLD SIDE PROFIT $" +
         DoubleToString(oldSideProfit, 2);

      return(false);
     }

   // Continue here with candle, tick-speed, range, body,
   // wick, SAR-score and pending-order checks.
      if(iBars(Symbol(),PERIOD_M1) < 12)
      return(false);

   double candleOpen  = iOpen(Symbol(),PERIOD_M1,0);
   double candleClose = iClose(Symbol(),PERIOD_M1,0);
   double signalHigh  = iHigh(Symbol(),PERIOD_M1,0);
   double signalLow   = iLow(Symbol(),PERIOD_M1,0);
   double signalRange = MathMax(0.0,signalHigh-signalLow);
   double previousRange = MathMax(0.0,
      iHigh(Symbol(),PERIOD_M1,1)-iLow(Symbol(),PERIOD_M1,1));
   double averageRange = g_tickSpeedAvgCandleRange;
   if(averageRange <= 0.0)
      averageRange = GetTickSpeedAverageClosedCandleRange();

   if(signalRange <= 0.0 || previousRange <= 0.0 || averageRange <= 0.0)
      return(false);

   int candleDirection = 0;
   if(candleClose > candleOpen) candleDirection = 1;
   else if(candleClose < candleOpen) candleDirection = -1;

   if(candleDirection != newDirection)
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | LIVE M1 NOT OPPOSITE";
      return(false);
     }

   double body = MathAbs(candleClose-candleOpen);
   double bodyPercent = body/signalRange*100.0;
   double exitWick = 0.0;
   if(newDirection < 0)
      exitWick = MathMax(0.0,MathMin(candleOpen,candleClose)-signalLow);
   else
      exitWick = MathMax(0.0,signalHigh-MathMax(candleOpen,candleClose));
   double exitWickPercent = exitWick/signalRange*100.0;

   if(signalRange + Point*0.1 <
      previousRange*MathMax(0.0,InpPreSARSuspectCurrentVsPreviousRatio))
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | RANGE/PREV";
      return(false);
     }

   if(signalRange + Point*0.1 <
      averageRange*MathMax(0.0,InpPreSARSuspectCurrentVsAverageRatio))
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | RANGE/AVG";
      return(false);
     }

   if(bodyPercent + 0.0001 <
      MathMax(0.0,MathMin(100.0,InpPreSARSuspectMinimumBodyPercent)))
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | BODY " +
                                DoubleToString(bodyPercent,1) + "%";
      return(false);
     }

   if(exitWickPercent - 0.0001 >
      MathMax(0.0,MathMin(100.0,InpPreSARSuspectMaximumExitWickPercent)))
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | EXIT WICK " +
                                DoubleToString(exitWickPercent,1) + "%";
      return(false);
     }

   if(InpPreSARSuspectRequireFastTickSpeed &&
      g_tickSpeedStatus != "FAST" &&
      g_tickSpeedStatus != "DANGER")
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | SPEED " + g_tickSpeedStatus;
      return(false);
     }

   if(g_dynamicSARScore > InpPreSARSuspectMaximumSARScore)
     {
      g_oppositeImpulseStatus = "SUSPECT WAIT | SAR SCORE " +
                                IntegerToString(g_dynamicSARScore) + "/" +
                                IntegerToString(InpPreSARSuspectMaximumSARScore);
      return(false);
     }

   // Hard safety gates remain active.
   if(IsNewOrderHardPauseActive() ||
      g_dailyProfitLock || g_equityProtectionHit ||
      g_globalEquityTrailLocked || !IsTradingAllowedNow())
     {
      g_oppositeImpulseStatus = "SUSPECT BLOCKED | HARD SAFETY";
      return(false);
     }

   if(IsDirectionOrderCapReached(newDirection,"PRE-SAR SUSPECT") ||
      IsTotalOpenOrderCapReached("PRE-SAR SUSPECT"))
      return(false);

   ClearGoodMarketContinuation("CANCELLED | PRE-SAR SUSPECT PRIORITY");

   g_oppositeImpulseRequestPending  = true;
   g_oppositeImpulseDirection       = newDirection;
   g_oppositeImpulseSourceDirection = oldDirection;
   g_oppositeImpulseSourceLoss      = oldSideProfit;
   g_oppositeImpulseSignalBarTime   = iTime(Symbol(),PERIOD_M1,0);
   g_oppositeImpulseQueuedTime      = TimeCurrent();
   g_oppositeImpulseLastAttemptTime = 0;
   g_oppositeImpulseSignalHigh      = signalHigh;
   g_oppositeImpulseSignalLow       = signalLow;
   g_oppositeImpulseSignalRange     = signalRange;
   g_oppositeImpulsePreviousRange   = previousRange;
   g_oppositeImpulseAverageRange    = averageRange;
   g_oppositeImpulseBodyPercent     = bodyPercent;
   g_oppositeImpulseExitWickPercent = exitWickPercent;
   g_oppositeImpulsePendingTicket   = -1;
   g_oppositeImpulsePreSAROverride  = true;
   g_oppositeImpulseStatus          = "QUEUED PRE-SAR SUSPECT";

   Print("PRE-SAR REVERSAL SUSPECT QUEUED | OldSAR=",
         DirectionText(oldDirection),
         " | NewPending=",DirectionText(newDirection),
         " | OldSideP/L=$",DoubleToString(oldSideProfit,2),
         " | Range=",DoubleToString(signalRange,1),
         " | Prev=",DoubleToString(previousRange,1),
         " | Avg=",DoubleToString(averageRange,1),
         " | Body=",DoubleToString(bodyPercent,1),"%",
         " | ExitWick=",DoubleToString(exitWickPercent,1),"%",
         " | TickSpeed=",g_tickSpeedStatus,
         " | SARScore=",g_dynamicSARScore);

   return(true);
  }

//+------------------------------------------------------------------+
double GetEffectiveImpulsePendingGapRaw()
  {
   double stopRaw   = MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;
   double freezeRaw = MarketInfo(Symbol(),MODE_FREEZELEVEL)*Point;
   return(MathMax(MathMax(0.0,InpImpulsePendingGapRaw),
                  MathMax(stopRaw,freezeRaw)+Point));
  }

//+------------------------------------------------------------------+
double BuildOppositeImpulsePendingPrice(int direction)
  {
   RefreshRates();

   double gap = GetEffectiveImpulsePendingGapRaw();

   if(direction > 0)
      return(NormalizeDouble(
                MathMax(g_oppositeImpulseSignalHigh+gap,Ask+gap),
                Digits));

   if(direction < 0)
      return(NormalizeDouble(
                MathMin(g_oppositeImpulseSignalLow-gap,Bid-gap),
                Digits));

   return(0.0);
  }

//+------------------------------------------------------------------+
bool HasOppositeImpulseRetracedTooFar()
  {
   if(g_oppositeImpulseSignalRange <= 0.0 ||
      g_oppositeImpulseDirection == 0)
      return(true);

   double retraceFraction =
      MathMax(0.0,MathMin(100.0,InpImpulseMaximumRetracePercent))/100.0;

   if(g_oppositeImpulseDirection < 0)
     {
      double cancelAbove = g_oppositeImpulseSignalLow +
                           g_oppositeImpulseSignalRange*retraceFraction;
      return(Ask >= cancelAbove);
     }

   double cancelBelow = g_oppositeImpulseSignalHigh -
                        g_oppositeImpulseSignalRange*retraceFraction;
   return(Bid <= cancelBelow);
  }

//+------------------------------------------------------------------+
bool IsOppositeImpulseExpired()
  {
   if(g_oppositeImpulseSignalBarTime <= 0)
      return(true);

   int shift = iBarShift(Symbol(),PERIOD_M1,
                         g_oppositeImpulseSignalBarTime,false);
   if(shift < 0)
      return(true);

   return(shift >= (int)MathMax(1,InpImpulsePendingExpiryBars));
  }

//+------------------------------------------------------------------+
bool DeleteTrackedOppositeImpulsePending(string reason)
  {
   int ticket = g_oppositeImpulsePendingTicket;
   if(ticket <= 0)
     {
      ClearOppositeImpulseRequest(reason);
      return(true);
     }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      ClearOppositeImpulseRequest(reason + " | TICKET NOT LIVE");
      return(true);
     }

   if(OrderCloseTime() > 0)
     {
      ClearOppositeImpulseRequest(reason + " | ALREADY IN HISTORY");
      return(true);
     }

   int type = OrderType();
   if(type == OP_BUY || type == OP_SELL)
     {
      // The pending order has already activated. Do not delete the live trade.
      ClearOppositeImpulseRequest("ACTIVATED #"+IntegerToString(ticket));
      return(false);
     }

   if(!IsPendingOrderType(type))
     {
      ClearOppositeImpulseRequest(reason + " | NOT PENDING");
      return(true);
     }

   ResetLastError();
   if(!OrderDelete(ticket,clrNONE))
     {
      int err = GetLastError();
      g_oppositeImpulseStatus = "DELETE RETRY " + IntegerToString(err);
      Print("OPPOSITE IMPULSE DELETE FAILED | Ticket=",ticket,
            " | Error=",err,
            " | Reason=",reason);
      ResetLastError();
      return(false);
     }

   Print("OPPOSITE IMPULSE PENDING DELETED | Ticket=",ticket,
         " | Reason=",reason);
   ClearOppositeImpulseRequest(reason);
   return(true);
  }

//+------------------------------------------------------------------+
void RestoreOppositeImpulsePendingState()
  {
   g_oppositeImpulsePendingTicket = -1;
   g_oppositeImpulsePreSAROverride = false;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(!IsOppositeImpulseOrderComment(OrderComment()))
         continue;

      int type = OrderType();
      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP)
         continue;

      g_oppositeImpulsePendingTicket = OrderTicket();
      g_oppositeImpulseDirection = (type==OP_BUYSTOP) ? 1 : -1;
      g_oppositeImpulseSourceDirection = -g_oppositeImpulseDirection;
      g_oppositeImpulsePreSAROverride =
         (StringFind(OrderComment(),"PRESAR",0) >= 0);
      g_oppositeImpulseQueuedTime = OrderOpenTime();
      int openShift = iBarShift(Symbol(),PERIOD_M1,OrderOpenTime(),false);
      if(openShift < 0)
         openShift = 0;
      g_oppositeImpulseSignalBarTime =
         iTime(Symbol(),PERIOD_M1,openShift);
      int shift = iBarShift(Symbol(),PERIOD_M1,
                            g_oppositeImpulseSignalBarTime,false);
      if(shift < 0)
         shift = 0;
      g_oppositeImpulseSignalHigh = iHigh(Symbol(),PERIOD_M1,shift);
      g_oppositeImpulseSignalLow = iLow(Symbol(),PERIOD_M1,shift);
      g_oppositeImpulseSignalRange = MathMax(0.0,
         g_oppositeImpulseSignalHigh-g_oppositeImpulseSignalLow);
      g_oppositeImpulseStatus =
         g_oppositeImpulsePreSAROverride ?
         "RESTORED PRE-SAR PENDING" : "RESTORED PENDING";

      Print("OPPOSITE IMPULSE RESTORED | Ticket=",
            g_oppositeImpulsePendingTicket,
            " | Direction=",DirectionText(g_oppositeImpulseDirection),
            " | PreSAR=",(g_oppositeImpulsePreSAROverride ? "YES" : "NO"));
      return;
     }
  }

//+------------------------------------------------------------------+
// Place, retry and manage one special continuation pending order.
// Returns true only when a new pending order is placed on this call.
//+------------------------------------------------------------------+
bool ProcessOppositeImpulseContinuation()
  {
   if(!InpUseOppositeImpulseContinuation)
     {
      if(g_oppositeImpulsePendingTicket > 0)
         DeleteTrackedOppositeImpulsePending("FEATURE DISABLED");
      else
         ClearOppositeImpulseRequest("OFF");
      return(false);
     }

   // Manage a pending order that was already placed.
   if(g_oppositeImpulsePendingTicket > 0)
     {
      int ticket = g_oppositeImpulsePendingTicket;

      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
        {
         ClearOppositeImpulseRequest("PENDING FINISHED/REMOVED");
         return(false);
        }

      if(OrderCloseTime() > 0)
        {
         ClearOppositeImpulseRequest("PENDING MOVED TO HISTORY");
         return(false);
        }

      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
        {
         ClearOppositeImpulseRequest("ACTIVATED #"+IntegerToString(ticket));
         return(false);
        }

      if(!IsPendingOrderType(type))
        {
         ClearOppositeImpulseRequest("NO LONGER PENDING");
         return(false);
        }

      if(IsOppositeImpulseExpired())
        {
         DeleteTrackedOppositeImpulsePending("EXPIRED " +
            IntegerToString((int)MathMax(1,InpImpulsePendingExpiryBars)) +
            " M1 BARS");
         return(false);
        }

      int pendingLiveSAR = GetSARDotDirection(0);

      // A PRE-SAR pending is intentionally allowed while SAR still points to
      // the stopped side. Once SAR flips into the impulse direction, the
      // pending becomes normally SAR-confirmed and future invalidation applies.
      if(g_oppositeImpulsePreSAROverride &&
         pendingLiveSAR == g_oppositeImpulseDirection)
        {
         g_oppositeImpulsePreSAROverride = false;
         g_oppositeImpulseStatus = "PENDING | SAR NOW CONFIRMED";
        }

      if(InpImpulseRequireLiveSARDirection &&
         !g_oppositeImpulsePreSAROverride &&
         pendingLiveSAR != g_oppositeImpulseDirection)
        {
         DeleteTrackedOppositeImpulsePending("LIVE SAR INVALIDATED");
         return(false);
        }

      if(HasOppositeImpulseRetracedTooFar())
        {
         DeleteTrackedOppositeImpulsePending("RETRACE >= " +
            DoubleToString(InpImpulseMaximumRetracePercent,0) + "%");
         return(false);
        }

      g_oppositeImpulseStatus = "PENDING ACTIVE #"+
                                IntegerToString(ticket);
      return(false);
     }

   if(!g_oppositeImpulseRequestPending)
      return(false);

   int direction = g_oppositeImpulseDirection;

   if(direction != 1 && direction != -1)
     {
      ClearOppositeImpulseRequest("INVALID DIRECTION");
      return(false);
     }

   if(IsOppositeImpulseExpired())
     {
      ClearOppositeImpulseRequest("REQUEST EXPIRED");
      return(false);
     }

   if(HasOppositeImpulseRetracedTooFar())
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | RETRACED");
      return(false);
     }

   if(InpImpulseRequireFastTickSpeed &&
      g_tickSpeedStatus != "FAST" &&
      g_tickSpeedStatus != "DANGER")
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | SPEED " +
                                  g_tickSpeedStatus);
      return(false);
     }

   if(InpImpulseRequireLiveSARDirection &&
      !g_oppositeImpulsePreSAROverride &&
      GetSARDotDirection(0) != direction)
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | LIVE SAR " +
                                  DirectionText(GetSARDotDirection(0)));
      return(false);
     }

   if(IsNewOrderHardPauseActive())
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | " + GetNewOrderHardPauseReasonText());
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "OPPOSITE IMPULSE"))
     {
      ClearOppositeImpulseRequest(
         "REQUEST CANCELLED | SIDE LOSS PAUSE");
      return(false);
     }

   if(g_dailyProfitLock ||
      g_equityProtectionHit ||
      g_globalEquityTrailLocked)
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | EQUITY/PROFIT LOCK");
      return(false);
     }

   if(!IsTradingAllowedNow())
     {
      g_oppositeImpulseStatus = "WAIT TRADING PERMISSION";
      return(false);
     }

   if(IsDirectionOrderCapReached(direction,"OPPOSITE IMPULSE"))
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | DIRECTION CAP");
      return(false);
     }

   if(IsTotalOpenOrderCapReached("OPPOSITE IMPULSE"))
     {
      ClearOppositeImpulseRequest("REQUEST CANCELLED | TOTAL CAP");
      return(false);
     }

   int retrySeconds = (int)MathMax(0,InpImpulsePendingRetrySeconds);
   if(retrySeconds > 0 &&
      g_oppositeImpulseLastAttemptTime > 0 &&
      TimeCurrent()-g_oppositeImpulseLastAttemptTime < retrySeconds)
      return(false);

   g_oppositeImpulseLastAttemptTime = TimeCurrent();

   RefreshRates();
   double price = BuildOppositeImpulsePendingPrice(direction);
   if(price <= 0.0)
     {
      g_oppositeImpulseStatus = "PRICE BUILD FAILED";
      return(false);
     }

   int type = (direction > 0) ? OP_BUYSTOP : OP_SELLSTOP;
   double lot = GetCurrentTradingLot();
   string reason;
   if(g_oppositeImpulsePreSAROverride)
      reason = (direction > 0)
               ? "OPP_IMPULSE_PRESAR_BUY"
               : "OPP_IMPULSE_PRESAR_SELL";
   else
      reason = (direction > 0)
               ? "OPP_IMPULSE_BUY"
               : "OPP_IMPULSE_SELL";
   string orderComment = MakeSARParentOrderComment(reason);

   // A SAR-confirmed impulse receives one normal cycle slot. A PRE-SAR
   // override must not reset the still-active old SAR cycle before the dots
   // actually flip, so it remains a separate special pending entry.
   if(!g_oppositeImpulsePreSAROverride)
     {
      EnsureSARSignalOrderCycle(direction);
      if(g_sarCycleMaxOrders <= g_sarCycleOrdersCreated)
         g_sarCycleMaxOrders = g_sarCycleOrdersCreated + 1;
     }

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             true,
                                             "OPPOSITE IMPULSE"))
     {
      g_oppositeImpulseStatus = "WAIT ORDER GAP / PENDING SLOT";
      return(false);
     }

   ResetLastError();
   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          0,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          GetOrderIconColorByComment(direction,orderComment));

   if(ticket < 0)
     {
      int err = GetLastError();
      g_oppositeImpulseStatus = "ORDERSEND RETRY " +
                                IntegerToString(err);
      g_lastOrderOpenReason =
         "OPPOSITE IMPULSE PENDING FAILED | Error=" +
         IntegerToString(err) +
         " | Direction=" + DirectionText(direction) +
         " | Price=" + DoubleToString(price,Digits);

      Print(g_lastOrderOpenReason,
            " | Loss=$",DoubleToString(g_oppositeImpulseSourceLoss,2),
            " | Range=",DoubleToString(g_oppositeImpulseSignalRange,1),
            " | Body=",DoubleToString(g_oppositeImpulseBodyPercent,1),"%",
            " | ExitWick=",DoubleToString(g_oppositeImpulseExitWickPercent,1),"%");
      ResetLastError();
      return(false);
     }

   g_oppositeImpulsePendingTicket = ticket;
   g_oppositeImpulseRequestPending = false;
   g_oppositeImpulseStatus = "PENDING ACTIVE #"+
                             IntegerToString(ticket);
   ApplyInitialServerSideSLToTicket(ticket);
   g_lastOrderTime = TimeCurrent();
   g_lastConfirmedOrderPrice = price;
   g_lastConfirmedOrderTime = TimeCurrent();

   MarkOpenedOrderOnChart(ticket,direction,orderComment,TimeCurrent(),price);
   NotifyCreatedOrderTicket(ticket);
   if(!g_oppositeImpulsePreSAROverride)
      RegisterSARCycleOrderCreated(direction,false);

   g_lastOrderOpenReason =
      "OPPOSITE IMPULSE PENDING PLACED | Ticket="+
      IntegerToString(ticket)+
      " | Direction="+DirectionText(direction)+
      " | Price="+DoubleToString(price,Digits)+
      " | Gap="+DoubleToString(GetEffectiveImpulsePendingGapRaw(),1)+
      " | Expiry="+IntegerToString((int)MathMax(1,InpImpulsePendingExpiryBars))+
      " M1 bars";

   Print(g_lastOrderOpenReason,
         " | SourceSide=",DirectionText(g_oppositeImpulseSourceDirection),
         " | SourceLoss=$",DoubleToString(g_oppositeImpulseSourceLoss,2),
         " | Range/Prev/Avg=",
         DoubleToString(g_oppositeImpulseSignalRange,1),"/",
         DoubleToString(g_oppositeImpulsePreviousRange,1),"/",
         DoubleToString(g_oppositeImpulseAverageRange,1),
         " | Body=",DoubleToString(g_oppositeImpulseBodyPercent,1),"%",
         " | ExitWick=",DoubleToString(g_oppositeImpulseExitWickPercent,1),"%",
         " | TickSpeed=",g_tickSpeedStatus,
         " | Confirmation=",
         (g_oppositeImpulsePreSAROverride ? "PRE-SAR DANGER OVERRIDE" : "SAR MATCH"),
         " | BYPASS=normal market filters");

   return(true);
  }


//+------------------------------------------------------------------+
//| SAR SAME-DIRECTION CONTINUATION ADD-ON ENGINE                    |
//+------------------------------------------------------------------+
bool IsSARContinuationOrderComment(string commentText)
  {
   return(StringFind(commentText,"SAR_PYRAMID",0) >= 0 ||
          StringFind(commentText,"SAR_PULLBACK",0) >= 0 ||
          StringFind(commentText,"SAR_BREAKOUT",0) >= 0);
  }

//+------------------------------------------------------------------+
bool IsSARContinuationMarker(string commentText,string marker)
  {
   if(!IsSARContinuationOrderComment(commentText))
      return(false);

   if(marker == "")
      return(true);

   return(StringFind(commentText,marker,0) >= 0);
  }

//+------------------------------------------------------------------+
int CountSARContinuationOrdersCreated(int direction,string marker)
  {
   int count = 0;
   datetime cycleStart = 0;

   if(g_sarCycleDirection == direction)
      cycleStart = g_sarCycleStartTime;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(!IsOrderTypeForDirection(OrderType(),direction,true))
         continue;
      if(!IsSARContinuationMarker(OrderComment(),marker))
         continue;
      if(cycleStart > 0 && OrderOpenTime() < cycleStart)
         continue;

      count++;
     }

   // Count only activated BUY/SELL history. Deleted/expired pending orders do
   // not consume the cycle allowance, so a later valid setup can try again.
   for(int h=OrdersHistoryTotal()-1;h>=0;h--)
     {
      if(!OrderSelect(h,SELECT_BY_POS,MODE_HISTORY))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(!IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
         continue;

      int type = OrderType();
      if(direction > 0 && type != OP_BUY)
         continue;
      if(direction < 0 && type != OP_SELL)
         continue;
      if(!IsSARContinuationMarker(OrderComment(),marker))
         continue;
      if(cycleStart > 0 && OrderOpenTime() < cycleStart)
         continue;

      count++;
     }

   return(count);
  }

//+------------------------------------------------------------------+
bool HasSARContinuationPending(int direction)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(!IsPendingOrderType(OrderType()))
         continue;
      if(!IsOrderTypeForDirection(OrderType(),direction,true))
         continue;
      if(IsSARContinuationOrderComment(OrderComment()))
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
double GetLatestSARDirectionMarketEntryPrice(int direction)
  {
   double result = 0.0;
   datetime latestTime = 0;
   int requiredType = direction > 0 ? OP_BUY : OP_SELL;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(OrderType()!=requiredType)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;

      if(OrderOpenTime() >= latestTime)
        {
         latestTime = OrderOpenTime();
         result = OrderOpenPrice();
        }
     }

   return(result);
  }

//+------------------------------------------------------------------+
bool GetSARContinuationM1Stats(int shift,
                               int direction,
                               int &candleDirection,
                               double &rangeRaw,
                               double &bodyPercent,
                               double &exitWickPercent)
  {
   candleDirection = 0;
   rangeRaw = 0.0;
   bodyPercent = 0.0;
   exitWickPercent = 0.0;

   if(iBars(Symbol(),PERIOD_M1) <= shift+2)
      return(false);

   double o = iOpen(Symbol(),PERIOD_M1,shift);
   double c = iClose(Symbol(),PERIOD_M1,shift);
   double h = iHigh(Symbol(),PERIOD_M1,shift);
   double l = iLow(Symbol(),PERIOD_M1,shift);

   rangeRaw = MathMax(0.0,h-l);
   if(rangeRaw <= 0.0)
      return(false);

   if(c > o)
      candleDirection = 1;
   else
   if(c < o)
      candleDirection = -1;

   double body = MathAbs(c-o);
   bodyPercent = body/rangeRaw*100.0;

   double exitWick = 0.0;
   if(direction > 0)
      exitWick = MathMax(0.0,h-MathMax(o,c));
   else
      exitWick = MathMax(0.0,MathMin(o,c)-l);

   exitWickPercent = exitWick/rangeRaw*100.0;
   return(true);
  }

//+------------------------------------------------------------------+
bool IsSARContinuationTickSpeedAllowed(bool requireFast)
  {
   if(requireFast)
      return(g_tickSpeedStatus == "FAST" ||
             g_tickSpeedStatus == "DANGER");

   if(!InpSARContinuationRequireNotSlow)
      return(true);

   return(g_tickSpeedStatus == "NORMAL" ||
          g_tickSpeedStatus == "FAST" ||
          g_tickSpeedStatus == "DANGER");
  }

//+------------------------------------------------------------------+
bool IsSARContinuationRenewedMomentumStrong(int direction,
                                            int minimumSARScore)
  {
   int candleDirection = 0;
   double rangeRaw = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;

   if(!GetSARContinuationM1Stats(0,direction,candleDirection,
                                 rangeRaw,bodyPercent,exitWickPercent))
      return(false);

   double averageRange = g_tickSpeedAvgCandleRange;
   if(averageRange <= 0.0)
      averageRange = GetTickSpeedAverageClosedCandleRange();

   if(candleDirection != direction)
      return(false);

   if(bodyPercent + 0.0001 <
      MathMax(0.0,InpSARContinuationRenewedBodyPercent))
      return(false);

   if(averageRange > 0.0 &&
      rangeRaw + Point*0.1 <
      averageRange*MathMax(0.0,InpSARContinuationRenewedRangeAvgRatio))
      return(false);

   if(g_tickSpeedStatus != "FAST" &&
      g_tickSpeedStatus != "DANGER")
      return(false);

   if(g_dynamicSARScore < minimumSARScore)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
bool IsSideBasketProtectedAtBreakEvenOrProfit(int direction)
  {
   if(direction != 1 && direction != -1)
      return(false);

   int marketOrders = 0;
   double tolerance = Point*0.5;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(direction == 1 && OrderType() != OP_BUY)
         continue;
      if(direction == -1 && OrderType() != OP_SELL)
         continue;

      marketOrders++;

      double sl = OrderStopLoss();
      if(sl <= 0.0)
         return(false);

      if(direction == 1 &&
         sl+tolerance < OrderOpenPrice())
         return(false);

      if(direction == -1 &&
         sl-tolerance > OrderOpenPrice())
         return(false);
     }

   return(marketOrders > 0);
  }

//+------------------------------------------------------------------+
int GetAllowedSARContinuationOrdersByProfitLadder()
  {
   int configuredMax =
      (int)MathMax(0,
                   InpMaxSARContinuationOrdersPerSide);

   if(!InpScaleContinuationByProfitLadder ||
      !InpUseDailyProfitPercentLadder)
      return(configuredMax);

   int allowed =
      (int)MathMax(0,
                   InpContinuationMaxBelowLevel1);

   if(InpUseHighestProfitShareLock)
     {
      if(g_profitPercentHighestLevel >= 1)
         allowed =
            (int)MathMax(allowed,
                         InpContinuationMaxAtLevel1);

      if(g_profitPercentPeakPercent >=
         GetDailyProfitLadderPercent(2))
         allowed =
            (int)MathMax(allowed,
                         InpContinuationMaxAtLevel2);

      if(g_profitPercentPeakPercent >=
         GetDailyProfitLadderPercent(3))
         allowed =
            (int)MathMax(allowed,
                         InpContinuationMaxAtLevel3OrHigher);

      return(MathMin(configuredMax,allowed));
     }

   if(g_profitPercentHighestLevel >= 1)
      allowed =
         (int)MathMax(
            allowed,
            InpContinuationMaxAtLevel1);

   if(g_profitPercentHighestLevel >= 2)
      allowed =
         (int)MathMax(
            allowed,
            InpContinuationMaxAtLevel2);

   if(g_profitPercentHighestLevel >= 3)
      allowed =
         (int)MathMax(
            allowed,
            InpContinuationMaxAtLevel3OrHigher);

   return(MathMin(configuredMax,allowed));
  }

//+------------------------------------------------------------------+
bool IsSARContinuationCommonSafetyReady(int direction,
                                        string strategy,
                                        int minimumSARScore)
  {
   if(direction != 1 && direction != -1)
      return(false);

   if(GetSARDotDirection(0) != direction ||
      g_activeSARDirection != direction)
     {
      g_sarContinuationStatus =
         strategy + " WAIT | SAR " +
         DirectionText(GetSARDotDirection(0)) +
         " / Active " + DirectionText(g_activeSARDirection);
      return(false);
     }

   if(CountOrdersByDirection(direction) <= 0)
     {
      g_sarContinuationStatus =
         strategy + " WAIT | NO LIVE " + DirectionText(direction);
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "SAR CONTINUATION " + strategy))
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | SIDE LOSS PAUSE";
      return(false);
     }

   if(!IsBuyStrictEntryAllowed(
         direction,
         "SAR CONTINUATION " + strategy))
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | BUY STRICT";
      return(false);
     }

   if(InpContinuationRequireProtectedProfit &&
      !IsSideBasketProtectedAtBreakEvenOrProfit(direction))
     {
      g_sarContinuationStatus =
         strategy +
         " WAIT | SERVER SL NOT BE/PROFIT";
      return(false);
     }

   if(IsNewOrderHardPauseActive())
     {
      g_sarContinuationStatus = strategy + " BLOCK | " + GetNewOrderHardPauseReasonText();
      return(false);
     }

   if(g_dailyProfitLock ||
      g_equityProtectionHit ||
      g_globalEquityTrailLocked)
     {
      g_sarContinuationStatus = strategy + " BLOCK | EQUITY/PROFIT LOCK";
      return(false);
     }

   if(!IsTradingAllowedNow())
     {
      g_sarContinuationStatus = strategy + " WAIT | TRADING PERMISSION";
      return(false);
     }

   if(InpUseAutoMarketFlowMode && IsAutoMarketTradingPaused())
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | " + g_autoMarketModeText;
      return(false);
     }

   int spread = (int)MarketInfo(Symbol(),MODE_SPREAD);
   if(spread > InpMaxSpreadPoints)
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | SPREAD " +
         IntegerToString(spread) + "/" +
         IntegerToString(InpMaxSpreadPoints);
      return(false);
     }

   if(g_dynamicSARScore < minimumSARScore)
     {
      g_sarContinuationStatus =
         strategy + " WAIT | SAR SCORE " +
         IntegerToString(g_dynamicSARScore) + "/" +
         IntegerToString(minimumSARScore);
      return(false);
     }

   // Keep the weak-exit protection active. It is bypassed only after renewed
   // live momentum is independently reconfirmed by range, body, speed and score.
   if(g_earlySARWeakExitActive &&
      !IsSARContinuationRenewedMomentumStrong(direction,minimumSARScore))
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | EARLY WEAK | " +
         StringSubstr(g_earlySARWeakExitReason,0,28);
      return(false);
     }

   if(EnforceBigCandleOrderBlock(
         direction,"SAR_CONTINUATION_"+strategy))
     {
      g_sarContinuationStatus = strategy + " BLOCK | BIG CANDLE";
      return(false);
     }

   if(EnforceSpikeWickOrderBlock(
         "SAR_CONTINUATION_"+strategy,false,false))
     {
      g_sarContinuationStatus = strategy + " BLOCK | SPIKE/WICK";
      return(false);
     }

   if(IsDirectionOrderCapReached(direction,
                                 "SAR CONTINUATION "+strategy))
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | DIR CAP " +
         IntegerToString(CountDirectionEntriesForCap(direction)) +
         "/" + IntegerToString((int)MathMax(1,InpMaxOrders));
      return(false);
     }

   if(IsTotalOpenOrderCapReached("SAR CONTINUATION "+strategy))
     {
      g_sarContinuationStatus = strategy + " BLOCK | TOTAL CAP";
      return(false);
     }

   EnsureSARSignalOrderCycle(direction);

   int allowedContinuationOrders =
      GetAllowedSARContinuationOrdersByProfitLadder();
   int createdContinuationOrders =
      CountSARContinuationOrdersCreated(direction,"");

   if(allowedContinuationOrders <= 0)
     {
      g_sarContinuationStatus =
         strategy +
         " WAIT | DAILY LADDER LEVEL " +
         IntegerToString(g_profitPercentHighestLevel) +
         " ALLOWS 0 ADD-ONS";
      return(false);
     }

   if(createdContinuationOrders >=
      allowedContinuationOrders)
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | ADD-ON MAX " +
         IntegerToString(createdContinuationOrders) +
         "/" +
         IntegerToString(allowedContinuationOrders) +
         " | LadderLevel=" +
         IntegerToString(g_profitPercentHighestLevel);
      return(false);
     }

   if(HasSARContinuationPending(direction))
     {
      g_sarContinuationStatus =
         strategy + " WAIT | CONTINUATION PENDING EXISTS";
      return(false);
     }

   datetime currentM1Bar = iTime(Symbol(),PERIOD_M1,0);
   datetime lastBar = direction > 0
                      ? g_lastSARContinuationBuyBarTime
                      : g_lastSARContinuationSellBarTime;

   if(InpSARContinuationOneOrderPerM1Bar &&
      currentM1Bar > 0 && currentM1Bar == lastBar)
     {
      g_sarContinuationStatus =
         strategy + " WAIT | ONE ADD-ON/M1";
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
double GetEffectiveSARContinuationPendingGapRaw(double requestedGap)
  {
   double stopRaw = MarketInfo(Symbol(),MODE_STOPLEVEL)*Point;
   double freezeRaw = MarketInfo(Symbol(),MODE_FREEZELEVEL)*Point;

   return(MathMax(MathMax(0.0,requestedGap),
                  MathMax(stopRaw,freezeRaw)+Point));
  }

//+------------------------------------------------------------------+
bool PlaceSARContinuationPending(int direction,
                                 string strategy,
                                 double referencePrice,
                                 double requestedGap)
  {
   if(direction != 1 && direction != -1)
      return(false);

   if(GetSARDotDirection(0) != direction ||
      g_activeSARDirection != direction)
     {
      g_sarContinuationStatus =
         strategy + " CANCEL | SAR CHANGED";
      return(false);
     }

   if(IsNewOrderHardPauseActive() ||
      g_dailyProfitLock ||
      g_equityProtectionHit ||
      g_globalEquityTrailLocked ||
      !IsTradingAllowedNow())
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | FINAL HARD SAFETY";
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "SAR CONTINUATION FINAL " + strategy))
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | SIDE LOSS PAUSE";
      return(false);
     }

   if(InpContinuationRequireProtectedProfit &&
      !IsSideBasketProtectedAtBreakEvenOrProfit(direction))
     {
      g_sarContinuationStatus =
         strategy +
         " BLOCK | SERVER SL LOST PROTECTION";
      return(false);
     }

   int finalAllowedContinuation =
      GetAllowedSARContinuationOrdersByProfitLadder();

   if(CountSARContinuationOrdersCreated(direction,"") >=
      finalAllowedContinuation)
     {
      g_sarContinuationStatus =
         strategy + " BLOCK | FINAL ADD-ON MAX " +
         IntegerToString(finalAllowedContinuation);
      return(false);
     }

   if(IsDirectionOrderCapReached(direction,
                                 "SAR CONTINUATION FINAL "+strategy) ||
      IsTotalOpenOrderCapReached(
         "SAR CONTINUATION FINAL "+strategy))
      return(false);

   RefreshRates();

   double gap = GetEffectiveSARContinuationPendingGapRaw(requestedGap);
   double price = 0.0;
   int type = direction > 0 ? OP_BUYSTOP : OP_SELLSTOP;

   if(direction > 0)
      price = NormalizeDouble(
                 MathMax(referencePrice+gap,Ask+gap),
                 Digits);
   else
      price = NormalizeDouble(
                 MathMin(referencePrice-gap,Bid-gap),
                 Digits);

   double lot = GetCurrentTradingLot();
   string reason = strategy + "_" + DirectionText(direction);
   string orderComment = MakeSARParentOrderComment(reason);

   EnsureSARSignalOrderCycle(direction);
   if(g_sarCycleMaxOrders <= g_sarCycleOrdersCreated)
      g_sarCycleMaxOrders = g_sarCycleOrdersCreated + 1;

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             true,
                                             "SAR CONTINUATION " + strategy))
     {
      g_sarContinuationStatus =
         strategy + " WAIT | ORDER GAP / PENDING SLOT";
      return(false);
     }

   ResetLastError();
   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          0,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          GetOrderIconColorByComment(
                             direction,orderComment));

   if(ticket < 0)
     {
      int err = GetLastError();
      g_sarContinuationStatus =
         strategy + " ORDERSEND ERROR " +
         IntegerToString(err);

      Print("SAR CONTINUATION ORDER FAILED | Strategy=",
            strategy,
            " | Direction=",DirectionText(direction),
            " | Price=",DoubleToString(price,Digits),
            " | Gap=",DoubleToString(gap,1),
            " | Error=",err);
      ResetLastError();
      return(false);
     }

   ApplyInitialServerSideSLToTicket(ticket);
   g_lastOrderTime = TimeCurrent();
   g_lastConfirmedOrderPrice = price;
   g_lastConfirmedOrderTime = TimeCurrent();

   datetime currentM1Bar = iTime(Symbol(),PERIOD_M1,0);
   if(direction > 0)
      g_lastSARContinuationBuyBarTime = currentM1Bar;
   else
      g_lastSARContinuationSellBarTime = currentM1Bar;

   MarkOpenedOrderOnChart(ticket,direction,orderComment,
                          TimeCurrent(),price);
   NotifyCreatedOrderTicket(ticket);
   RegisterSARCycleOrderCreated(direction,false);

   g_lastOrderOpenReason =
      strategy + " " + DirectionText(direction) +
      " PENDING #" + IntegerToString(ticket) +
      " | Price=" + DoubleToString(price,Digits) +
      " | Basket=$" +
      DoubleToString(GetBasketProfit(direction),2);

   g_sarContinuationStatus =
      strategy + " " + DirectionText(direction) +
      " PENDING #" + IntegerToString(ticket);

   Print("SAR CONTINUATION PENDING PLACED | ",
         g_lastOrderOpenReason,
         " | SARScore=",g_dynamicSARScore,
         " | TickSpeed=",g_tickSpeedStatus,
         " | Cycle=",g_sarCycleOrdersCreated,
         "/",g_sarCycleMaxOrders);

   return(true);
  }

//+------------------------------------------------------------------+
void ResetSARPullbackContinuationState(int direction,string reason)
  {
   if(direction > 0)
     {
      g_buySARContinuationExtreme = 0.0;
      g_buyPullbackContinuationArmed = false;
      g_buyPullbackContinuationArmBarTime = 0;
      g_buyPullbackContinuationRaw = 0.0;
     }
   else
   if(direction < 0)
     {
      g_sellSARContinuationExtreme = 0.0;
      g_sellPullbackContinuationArmed = false;
      g_sellPullbackContinuationArmBarTime = 0;
      g_sellPullbackContinuationRaw = 0.0;
     }

   if(reason != "")
      Print("SAR PULLBACK STATE RESET | Direction=",
            DirectionText(direction),
            " | Reason=",reason);
  }

//+------------------------------------------------------------------+
void UpdateSARPullbackContinuationStateForDirection(int direction)
  {
   if(!InpUseSARContinuationAddOns ||
      !InpUsePullbackContinuationOrders ||
      CountOrdersByDirection(direction) <= 0 ||
      GetSARDotDirection(0) != direction ||
      g_activeSARDirection != direction)
     {
      ResetSARPullbackContinuationState(direction,"NO MATCHING LIVE BASKET/SAR");
      return;
     }

   RefreshRates();
   double livePrice = direction > 0 ? Bid : Ask;
   double extreme = direction > 0
                    ? g_buySARContinuationExtreme
                    : g_sellSARContinuationExtreme;
   bool armed = direction > 0
                ? g_buyPullbackContinuationArmed
                : g_sellPullbackContinuationArmed;

   if(extreme <= 0.0)
      extreme = livePrice;

   bool newExtreme = false;
   if(direction > 0 && livePrice > extreme)
     {
      extreme = livePrice;
      newExtreme = true;
     }
   else
   if(direction < 0 && livePrice < extreme)
     {
      extreme = livePrice;
      newExtreme = true;
     }

   if(newExtreme && armed)
      armed = false;

   double pullbackRaw = direction > 0
                        ? extreme-livePrice
                        : livePrice-extreme;

   int candleDirection = 0;
   double rangeRaw = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;
   GetSARContinuationM1Stats(0,direction,candleDirection,
                             rangeRaw,bodyPercent,exitWickPercent);

   double minRaw = MathMax(0.0,InpPullbackContinuationMinRaw);
   double maxRaw = MathMax(minRaw,InpPullbackContinuationMaxRaw);

   if(!armed &&
      pullbackRaw + Point*0.1 >= minRaw &&
      pullbackRaw <= maxRaw + Point*0.1 &&
      candleDirection == -direction)
     {
      armed = true;
      datetime armBar = iTime(Symbol(),PERIOD_M1,0);

      if(direction > 0)
         g_buyPullbackContinuationArmBarTime = armBar;
      else
         g_sellPullbackContinuationArmBarTime = armBar;

      g_sarContinuationStatus =
         "PULLBACK " + DirectionText(direction) +
         " ARMED " + DoubleToString(pullbackRaw,1);

      Print("SAR PULLBACK CONTINUATION ARMED | Direction=",
            DirectionText(direction),
            " | PullbackRaw=",DoubleToString(pullbackRaw,1),
            " | Range=",DoubleToString(minRaw,1),
            "-",DoubleToString(maxRaw,1));
     }

   if(direction > 0)
     {
      g_buySARContinuationExtreme = extreme;
      g_buyPullbackContinuationArmed = armed;
      g_buyPullbackContinuationRaw = pullbackRaw;
     }
   else
     {
      g_sellSARContinuationExtreme = extreme;
      g_sellPullbackContinuationArmed = armed;
      g_sellPullbackContinuationRaw = pullbackRaw;
     }
  }

//+------------------------------------------------------------------+
void UpdateSARPullbackContinuationState()
  {
   UpdateSARPullbackContinuationStateForDirection(1);
   UpdateSARPullbackContinuationStateForDirection(-1);
  }

//+------------------------------------------------------------------+
void ManageSARContinuationPendingOrders()
  {
   int expiryBars =
      (int)MathMax(1,InpSARContinuationPendingExpiryBars);
   int liveSAR = GetSARDotDirection(0);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() ||
         OrderMagicNumber()!=InpMagicNumber)
         continue;
      if(!IsPendingOrderType(OrderType()) ||
         !IsSARContinuationOrderComment(OrderComment()))
         continue;

      int direction =
         (OrderType()==OP_BUYSTOP ||
          OrderType()==OP_BUYLIMIT) ? 1 : -1;

      bool deletePending = false;
      string reason = "";

      if(liveSAR != direction)
        {
         deletePending = true;
         reason = "SAR CHANGED TO " + DirectionText(liveSAR);
        }
      else
        {
         int shift = iBarShift(Symbol(),PERIOD_M1,
                               OrderOpenTime(),false);
         if(shift < 0 || shift >= expiryBars)
           {
            deletePending = true;
            reason = "EXPIRED " +
                     IntegerToString(expiryBars) +
                     " M1 BARS";
           }
        }

      if(!deletePending)
         continue;

      int ticket = OrderTicket();
      string comment = OrderComment();

      ResetLastError();
      if(OrderDelete(ticket,clrNONE))
        {
         g_sarContinuationStatus =
            "DELETED " + comment + " | " + reason;
         Print("SAR CONTINUATION PENDING DELETED | Ticket=",
               ticket,
               " | Comment=",comment,
               " | Reason=",reason);
        }
      else
        {
         int err = GetLastError();
         g_sarContinuationStatus =
            "DELETE RETRY " + IntegerToString(err);
         Print("SAR CONTINUATION DELETE FAILED | Ticket=",
               ticket,
               " | Error=",err,
               " | Reason=",reason);
         ResetLastError();
        }
     }
  }

//+------------------------------------------------------------------+
bool TryOpenSARProfitPyramidOrder(int direction)
  {
   if(!InpUseSARContinuationAddOns ||
      !InpUseProfitPyramidOrders)
      return(false);

   EnsureSARSignalOrderCycle(direction);

   if(CountSARContinuationOrdersCreated(direction,"SAR_PYRAMID") >=
      (int)MathMax(0,InpMaxProfitPyramidOrdersPerSide))
      return(false);

   double basketProfit = GetBasketProfit(direction);
   if(basketProfit + 0.0001 <
      MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpPyramidMinimumBasketProfitUSD)))
     {
      g_sarContinuationStatus =
         "PYRAMID " + DirectionText(direction) +
         " WAIT | BASKET $" +
         DoubleToString(basketProfit,2);
      return(false);
     }

   double latestPrice =
      GetLatestSARDirectionMarketEntryPrice(direction);
   if(latestPrice <= 0.0)
      return(false);

   RefreshRates();
   double favorableMove = direction > 0
                          ? Ask-latestPrice
                          : latestPrice-Bid;

   if(favorableMove + Point*0.1 <
      MathMax(0.0,InpPyramidRawGapFromLatestEntry))
     {
      g_sarContinuationStatus =
         "PYRAMID " + DirectionText(direction) +
         " WAIT | GAP " +
         DoubleToString(favorableMove,1) + "/" +
         DoubleToString(InpPyramidRawGapFromLatestEntry,1);
      return(false);
     }

   int candleDirection = 0;
   double rangeRaw = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;

   if(!GetSARContinuationM1Stats(0,direction,candleDirection,
                                 rangeRaw,bodyPercent,exitWickPercent))
      return(false);

   if(candleDirection != direction ||
      bodyPercent + 0.0001 <
      MathMax(0.0,InpPyramidMinimumBodyPercent))
     {
      g_sarContinuationStatus =
         "PYRAMID " + DirectionText(direction) +
         " WAIT | CANDLE/BODY " +
         DoubleToString(bodyPercent,1) + "%";
      return(false);
     }

   bool freshExtreme = direction > 0
                       ? iHigh(Symbol(),PERIOD_M1,0) >
                         iHigh(Symbol(),PERIOD_M1,1)+Point*0.1
                       : iLow(Symbol(),PERIOD_M1,0) <
                         iLow(Symbol(),PERIOD_M1,1)-Point*0.1;

   if(!freshExtreme)
     {
      g_sarContinuationStatus =
         "PYRAMID " + DirectionText(direction) +
         " WAIT | NO FRESH EXTREME";
      return(false);
     }

   if(!IsSARContinuationTickSpeedAllowed(false))
     {
      g_sarContinuationStatus =
         "PYRAMID WAIT | SPEED " + g_tickSpeedStatus;
      return(false);
     }

   if(!IsSARContinuationCommonSafetyReady(
         direction,"SAR_PYRAMID",
         (int)MathMax(0,InpPyramidMinimumSARScore)))
      return(false);

   double reference = direction > 0
                      ? iHigh(Symbol(),PERIOD_M1,0)
                      : iLow(Symbol(),PERIOD_M1,0);

   return(PlaceSARContinuationPending(
             direction,"SAR_PYRAMID",
             reference,InpPyramidPendingGapRaw));
  }

//+------------------------------------------------------------------+
bool TryOpenSARPullbackContinuationOrder(int direction)
  {
   if(!InpUseSARContinuationAddOns ||
      !InpUsePullbackContinuationOrders)
      return(false);

   EnsureSARSignalOrderCycle(direction);

   if(CountSARContinuationOrdersCreated(direction,"SAR_PULLBACK") >=
      (int)MathMax(0,InpMaxPullbackContinuationOrdersPerSide))
      return(false);

   bool armed = direction > 0
                ? g_buyPullbackContinuationArmed
                : g_sellPullbackContinuationArmed;
   datetime armBar = direction > 0
                     ? g_buyPullbackContinuationArmBarTime
                     : g_sellPullbackContinuationArmBarTime;
   double pullbackRaw = direction > 0
                        ? g_buyPullbackContinuationRaw
                        : g_sellPullbackContinuationRaw;

   if(!armed)
      return(false);

   datetime currentBar = iTime(Symbol(),PERIOD_M1,0);
   if(currentBar <= 0 || currentBar == armBar)
     {
      g_sarContinuationStatus =
         "PULLBACK " + DirectionText(direction) +
         " ARMED | WAIT NEXT M1";
      return(false);
     }

   double basketProfit = GetBasketProfit(direction);
   if(basketProfit + 0.0001 <
      MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpPullbackContinuationMinimumProfitUSD)))
     {
      g_sarContinuationStatus =
         "PULLBACK " + DirectionText(direction) +
         " WAIT | BASKET $" +
         DoubleToString(basketProfit,2);
      return(false);
     }

   int candleDirection = 0;
   double rangeRaw = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;

   if(!GetSARContinuationM1Stats(0,direction,candleDirection,
                                 rangeRaw,bodyPercent,exitWickPercent))
      return(false);

   if(candleDirection != direction ||
      bodyPercent + 0.0001 <
      MathMax(0.0,InpPullbackContinuationMinBodyPercent))
     {
      g_sarContinuationStatus =
         "PULLBACK " + DirectionText(direction) +
         " ARMED | WAIT RESUME";
      return(false);
     }

   double breakRaw = MathMax(0.0,InpPullbackContinuationBreakRaw);
   bool resumeBreak = direction > 0
                      ? Ask >= iHigh(Symbol(),PERIOD_M1,1)+breakRaw
                      : Bid <= iLow(Symbol(),PERIOD_M1,1)-breakRaw;

   if(!resumeBreak)
     {
      g_sarContinuationStatus =
         "PULLBACK " + DirectionText(direction) +
         " WAIT | BREAK " +
         DoubleToString(breakRaw,1);
      return(false);
     }

   if(!IsSARContinuationTickSpeedAllowed(false))
     {
      g_sarContinuationStatus =
         "PULLBACK WAIT | SPEED " + g_tickSpeedStatus;
      return(false);
     }

   if(!IsSARContinuationCommonSafetyReady(
         direction,"SAR_PULLBACK",
         (int)MathMax(0,InpPullbackContinuationMinSARScore)))
      return(false);

   double reference = direction > 0
                      ? iHigh(Symbol(),PERIOD_M1,0)
                      : iLow(Symbol(),PERIOD_M1,0);

   bool placed = PlaceSARContinuationPending(
                    direction,"SAR_PULLBACK",
                    reference,
                    InpPullbackContinuationPendingGapRaw);

   if(placed)
      ResetSARPullbackContinuationState(
         direction,
         "PENDING PLACED AFTER " +
         DoubleToString(pullbackRaw,1) +
         " RAW PULLBACK");

   return(placed);
  }

//+------------------------------------------------------------------+
bool TryOpenSARBreakoutContinuationOrder(int direction)
  {
   if(!InpUseSARContinuationAddOns ||
      !InpUseBreakoutContinuationOrders)
      return(false);

   EnsureSARSignalOrderCycle(direction);

   if(CountSARContinuationOrdersCreated(direction,"SAR_BREAKOUT") >=
      (int)MathMax(0,InpMaxBreakoutContinuationOrdersPerSide))
      return(false);

   double basketProfit = GetBasketProfit(direction);
   if(basketProfit + 0.0001 <
      MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpBreakoutMinimumBasketProfitUSD)))
     {
      g_sarContinuationStatus =
         "BREAKOUT " + DirectionText(direction) +
         " WAIT | BASKET $" +
         DoubleToString(basketProfit,2);
      return(false);
     }

   int candleDirection = 0;
   double rangeRaw = 0.0;
   double bodyPercent = 0.0;
   double exitWickPercent = 0.0;

   if(!GetSARContinuationM1Stats(1,direction,candleDirection,
                                 rangeRaw,bodyPercent,exitWickPercent))
      return(false);

   if(candleDirection != direction)
     {
      g_sarContinuationStatus =
         "BREAKOUT " + DirectionText(direction) +
         " WAIT | PREV CANDLE";
      return(false);
     }

   if(bodyPercent + 0.0001 <
      MathMax(0.0,InpBreakoutMinimumBodyPercent))
     {
      g_sarContinuationStatus =
         "BREAKOUT WAIT | BODY " +
         DoubleToString(bodyPercent,1) + "%";
      return(false);
     }

   if(exitWickPercent - 0.0001 >
      MathMax(0.0,InpBreakoutMaximumExitWickPercent))
     {
      g_sarContinuationStatus =
         "BREAKOUT WAIT | EXIT WICK " +
         DoubleToString(exitWickPercent,1) + "%";
      return(false);
     }

   double triggerRaw = MathMax(0.0,InpBreakoutTriggerRaw);
   bool broke = direction > 0
                ? Ask >= iHigh(Symbol(),PERIOD_M1,1)+triggerRaw
                : Bid <= iLow(Symbol(),PERIOD_M1,1)-triggerRaw;

   if(!broke)
     {
      g_sarContinuationStatus =
         "BREAKOUT " + DirectionText(direction) +
         " WAIT | TRIGGER " +
         DoubleToString(triggerRaw,1);
      return(false);
     }

   if(!IsSARContinuationTickSpeedAllowed(
         InpBreakoutRequireFastTickSpeed))
     {
      g_sarContinuationStatus =
         "BREAKOUT WAIT | SPEED " + g_tickSpeedStatus;
      return(false);
     }

   if(!IsSARContinuationCommonSafetyReady(
         direction,"SAR_BREAKOUT",
         (int)MathMax(0,InpBreakoutMinimumSARScore)))
      return(false);

   double reference = direction > 0
                      ? MathMax(iHigh(Symbol(),PERIOD_M1,0),
                                iHigh(Symbol(),PERIOD_M1,1))
                      : MathMin(iLow(Symbol(),PERIOD_M1,0),
                                iLow(Symbol(),PERIOD_M1,1));

   return(PlaceSARContinuationPending(
             direction,"SAR_BREAKOUT",
             reference,InpBreakoutPendingGapRaw));
  }

//+------------------------------------------------------------------+
// Priority: completed pullback setup, profitable pyramid, then breakout.
// Only one add-on can be placed on a tick and one per M1 bar by default.
//+------------------------------------------------------------------+
bool ProcessSARContinuationAddOnOrders()
  {
   if(!InpUseSARContinuationAddOns)
     {
      g_sarContinuationStatus = "SAR ADD-ONS OFF";
      return(false);
     }

   if(IsOppositeImpulseContinuationBusy() ||
      g_goodMarketContinuationPending)
     {
      g_sarContinuationStatus =
         "SAR ADD-ON WAIT | SPECIAL PENDING PRIORITY";
      return(false);
     }

   int direction = GetSARDotDirection(0);
   if(direction != 1 && direction != -1)
     {
      g_sarContinuationStatus = "SAR ADD-ON WAIT | NO SAR";
      return(false);
     }

   if(CountOrdersByDirection(direction) <= 0)
     {
      g_sarContinuationStatus =
         "SAR ADD-ON WAIT | NO LIVE " +
         DirectionText(direction) + " BASKET";
      return(false);
     }

   if(TryOpenSARPullbackContinuationOrder(direction))
      return(true);

   if(TryOpenSARProfitPyramidOrder(direction))
      return(true);

   if(TryOpenSARBreakoutContinuationOrder(direction))
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
//| Convert a requested USD loss into symbol price distance          |
//+------------------------------------------------------------------+
double GetInitialServerSLPriceDistance(string symbol,
                                       double lots,
                                       double lossUSD)
  {
   if(lots <= 0.0 || lossUSD <= 0.0)
      return(0.0);

   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double tickSize  = MarketInfo(symbol, MODE_TICKSIZE);

   if(tickValue <= 0.0 || tickSize <= 0.0)
     {
      Print("INITIAL SERVER SL BLOCKED | Invalid tick data",
            " | Symbol=",symbol,
            " | TickValue=",DoubleToString(tickValue,8),
            " | TickSize=",DoubleToString(tickSize,8));
      return(0.0);
     }

   return((lossUSD / (tickValue * lots)) * tickSize);
  }

//+------------------------------------------------------------------+
//| Return BUY/SELL direction from a market or pending order type    |
//+------------------------------------------------------------------+
int GetInitialServerSLOrderDirection(int orderType)
  {
   if(orderType == OP_BUY ||
      orderType == OP_BUYSTOP ||
      orderType == OP_BUYLIMIT)
      return(1);

   if(orderType == OP_SELL ||
      orderType == OP_SELLSTOP ||
      orderType == OP_SELLLIMIT)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Select initial per-order USD risk from order direction vs SAR    |
//+------------------------------------------------------------------+
double GetInitialServerSLUSDForSelectedOrder(int &sarDirectionOut,
                                              bool &matchesSAROut)
  {
   int orderDirection = GetInitialServerSLOrderDirection(OrderType());

   sarDirectionOut = GetSARDotDirection(0);
   if(sarDirectionOut != 1 && sarDirectionOut != -1)
      sarDirectionOut = g_activeSARDirection;

   matchesSAROut = false;

   if(orderDirection != 1 && orderDirection != -1)
      return(0.0);

   if(sarDirectionOut != 1 && sarDirectionOut != -1)
      return(MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpInitialServerSLNoSARDirectionUSD)));

   matchesSAROut = (orderDirection == sarDirectionOut);

   if(matchesSAROut)
      return(MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpInitialServerSLWithSARUSD)));

   return(MathMax(0.0,ScaleTradeMoneyByCurrentLot(InpInitialServerSLAgainstSARUSD)));
  }

//+------------------------------------------------------------------+
//| Add the initial broker-side SL to the currently selected order   |
//+------------------------------------------------------------------+
bool ApplyInitialServerSideSLToSelectedOrder()
  {
   if(!InpUseInitialServerSideOrderSL)
      return(true);

   int type = OrderType();
   int orderDirection = GetInitialServerSLOrderDirection(type);

   if(orderDirection != 1 && orderDirection != -1)
      return(false);

   bool buySide = (orderDirection == 1);

   bool pending = (type == OP_BUYSTOP ||
                   type == OP_BUYLIMIT ||
                   type == OP_SELLSTOP ||
                   type == OP_SELLLIMIT);

   if(pending && !InpInitialServerSLForPending)
      return(true);

   // Never overwrite an existing SL. The existing server-profit-lock logic
   // can later move the same SL forward into protected profit.
   if(OrderStopLoss() > 0.0)
      return(true);

   int sarDirection = 0;
   bool matchesSAR = false;
   double selectedInitialSLUSD =
      GetInitialServerSLUSDForSelectedOrder(sarDirection,matchesSAR);

   if(selectedInitialSLUSD <= 0.0)
      return(true);

   string symbol = OrderSymbol();
   double lots   = OrderLots();
   double open   = OrderOpenPrice();
   double point  = MarketInfo(symbol, MODE_POINT);
   int digits    = (int)MarketInfo(symbol, MODE_DIGITS);

   double priceDistance =
      GetInitialServerSLPriceDistance(symbol,
                                      lots,
                                      selectedInitialSLUSD);

   if(priceDistance <= 0.0 || point <= 0.0)
      return(false);

   // Before the half-loss warning, use the normal calculated initial SL gap.
   // After the one-shot half-loss trigger has occurred in this equity cycle,
   // add the configured RAW price gap only to NEW orders without an existing SL.
   double extraRawPriceGap = 0.0;

   if(g_halfLossPauseTriggered)
   { 
      extraRawPriceGap =
         MathMax(0.0,InpInitialServerSLExtraRawAfterHalfLoss);

   }
   priceDistance += extraRawPriceGap;

   double brokerMinDistance =
      MathMax(MarketInfo(symbol, MODE_STOPLEVEL),
              MarketInfo(symbol, MODE_FREEZELEVEL)) * point;

   double bid = MarketInfo(symbol, MODE_BID);
   double ask = MarketInfo(symbol, MODE_ASK);
   double desiredSL = 0.0;
   double finalSL   = 0.0;

   if(buySide)
     {
      desiredSL = open - priceDistance;

      if(type == OP_BUY)
         finalSL = MathMin(desiredSL, bid - brokerMinDistance);
      else
         finalSL = MathMin(desiredSL, open - brokerMinDistance);
     }
   else
     {
      desiredSL = open + priceDistance;

      if(type == OP_SELL)
         finalSL = MathMax(desiredSL, ask + brokerMinDistance);
      else
         finalSL = MathMax(desiredSL, open + brokerMinDistance);
     }

   finalSL = NormalizeDouble(finalSL,digits);

   if(finalSL <= 0.0)
      return(false);

   ResetLastError();
   bool modified = OrderModify(OrderTicket(),
                               OrderOpenPrice(),
                               finalSL,
                               OrderTakeProfit(),
                               OrderExpiration(),
                               clrNONE);

   string relationText = "NO SAR";
   if(sarDirection == 1 || sarDirection == -1)
      relationText = matchesSAR ? "WITH SAR" : "AGAINST SAR";

   if(!modified)
     {
      int err = GetLastError();
      Print("INITIAL SERVER SL MODIFY FAILED",
            " | Ticket=",OrderTicket(),
            " | OrderDir=",DirectionText(orderDirection),
            " | SAR=",DirectionText(sarDirection),
            " | Relation=",relationText,
            " | Open=",DoubleToString(open,digits),
            " | SL=",DoubleToString(finalSL,digits),
            " | RequestedLoss=$",
            DoubleToString(selectedInitialSLUSD,2),
            " | BaseGapRaw=",DoubleToString(priceDistance-extraRawPriceGap,digits),
            " | ExtraGapRaw=",DoubleToString(extraRawPriceGap,digits),
            " | HalfLossTriggered=",(g_halfLossPauseTriggered ? "YES" : "NO"),
            " | Error=",err);
      ResetLastError();
      return(false);
     }

   double estimatedLossUSD = 0.0;
   double tickValue = MarketInfo(symbol, MODE_TICKVALUE);
   double tickSize  = MarketInfo(symbol, MODE_TICKSIZE);

   if(tickValue > 0.0 && tickSize > 0.0)
      estimatedLossUSD =
         (MathAbs(open-finalSL) / tickSize) * tickValue * lots;

   Print("INITIAL SERVER SL ADDED",
         " | Ticket=",OrderTicket(),
         " | OrderDir=",DirectionText(orderDirection),
         " | SAR=",DirectionText(sarDirection),
         " | Relation=",relationText,
         " | Open=",DoubleToString(open,digits),
         " | SL=",DoubleToString(finalSL,digits),
         " | RequestedLoss=$",
         DoubleToString(selectedInitialSLUSD,2),
         " | BaseGapRaw=",DoubleToString(priceDistance-extraRawPriceGap,digits),
         " | ExtraGapRaw=",DoubleToString(extraRawPriceGap,digits),
         " | HalfLossTriggered=",(g_halfLossPauseTriggered ? "YES" : "NO"),
         " | EstimatedLoss=$",
         DoubleToString(estimatedLossUSD,2));

   return(true);
  }

//+------------------------------------------------------------------+
//| Apply initial SL immediately to a newly created ticket           |
//+------------------------------------------------------------------+
bool ApplyInitialServerSideSLToTicket(int ticket)
  {
   if(ticket <= 0)
      return(false);

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return(false);

   if(OrderSymbol() != Symbol() ||
      OrderMagicNumber() != InpMagicNumber)
      return(false);

   return(ApplyInitialServerSideSLToSelectedOrder());
  }

//+------------------------------------------------------------------+
//| Retry missing initial server SL values for all live/pending EA   |
//+------------------------------------------------------------------+
void EnsureInitialServerSideSLForAllOrders()
  {
   if(!InpUseInitialServerSideOrderSL)
      return;

   if(ScaleTradeMoneyByCurrentLot(InpInitialServerSLWithSARUSD) <= 0.0 &&
      ScaleTradeMoneyByCurrentLot(InpInitialServerSLAgainstSARUSD) <= 0.0 &&
      ScaleTradeMoneyByCurrentLot(InpInitialServerSLNoSARDirectionUSD) <= 0.0)
      return;

   int retrySeconds = MathMax(1,InpInitialServerSLRetrySeconds);

   if(g_lastInitialServerSLScanTime > 0 &&
      TimeCurrent()-g_lastInitialServerSLScanTime < retrySeconds)
      return;

   g_lastInitialServerSLScanTime = TimeCurrent();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL &&
         type != OP_BUYSTOP && type != OP_SELLSTOP &&
         type != OP_BUYLIMIT && type != OP_SELLLIMIT)
         continue;

      if(OrderStopLoss() > 0.0)
         continue;

      ApplyInitialServerSideSLToSelectedOrder();
     }
  }

//+------------------------------------------------------------------+
//| Terminal Global Variable key for daily EA reinitialization       |
//+------------------------------------------------------------------+
//| Strict 23:45 day-end fresh-boot terminal Global Variable keys.   |
//+------------------------------------------------------------------+
string GetDayEndPreparedGlobalKey()
  {
   return("DXB_DAYEND_PREPARED_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
string GetDayEndReloadedGlobalKey()
  {
   return("DXB_DAYEND_RELOADED_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
//| Persistent one-time notification markers.                        |
//| RESET_STARTED stores the old GMT0 date that began the shutdown. |
//| TRADING_STARTED stores the new GMT0 date already announced.     |
//+------------------------------------------------------------------+
string GetDayEndResetStartedNotifyGlobalKey()
  {
   // Deliberately shared by every chart/timeframe copy of this EA inside
   // the same MT4 terminal. Only one reset-start push is allowed for the
   // account and symbol, regardless of Period() or magic-number copies.
   return("DXB_V5_DAYEND_STARTED_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol());
  }

//+------------------------------------------------------------------+
string GetNewDayTradingStartedNotifyGlobalKey()
  {
   // Shared by all chart/timeframe copies in this MT4 terminal.
   return("DXB_V5_NEWDAY_STARTED_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol());
  }

//+------------------------------------------------------------------+
//| Atomically claim a one-notification-per-date marker.             |
//| GlobalVariableSetOnCondition prevents several charts from        |
//| sending the same push when they process the same tick together.  |
//+------------------------------------------------------------------+
bool ClaimDailyNotificationMarker(string key,int dateKey)
  {
   if(dateKey <= 0 || StringLen(key) <= 0)
      return(false);

   if(!GlobalVariableCheck(key))
     {
      ResetLastError();
      if(GlobalVariableSet(key,0.0) == 0)
        {
         int createError = GetLastError();
         Print("NOTIFICATION MARKER CREATE FAILED | Key=",key,
               " | Error=",createError);
         ResetLastError();
         return(false);
        }
     }

   double oldValue = GlobalVariableGet(key);

   if((int)oldValue == dateKey)
      return(false);

   ResetLastError();
   if(!GlobalVariableSetOnCondition(key,(double)dateKey,oldValue))
     {
      int claimError = GetLastError();

      // Error 0 normally means another chart claimed the marker first.
      if(claimError != 0)
         Print("NOTIFICATION MARKER CLAIM FAILED | Key=",key,
               " | Date=",dateKey,
               " | Error=",claimError);

      ResetLastError();
      return(false);
     }

   GlobalVariablesFlush();
   return(true);
  }

//+------------------------------------------------------------------+
//| Fresh-boot push/terminal notification helper.                     |
//+------------------------------------------------------------------+
void SendFreshBootLifecycleNotification(string eventTitle,
                                        string details)
  {
   string msg = InpEAName + " | " + Symbol() + " | " +
                eventTitle + " | " + details;

   // MT4 push messages have a limited payload. Keep a safe margin.
   if(StringLen(msg) > 250)
      msg = StringSubstr(msg,0,250);

   Print("FRESH BOOT NOTIFICATION | ",msg);

   if(InpSendTerminalAlerts)
      Alert(msg);

   if(InpSendPushNotifications && !IsTesting())
     {
      ResetLastError();
      if(!SendNotification(msg))
        {
         int errorCode = GetLastError();
         Print("FRESH BOOT PUSH FAILED | Event=",eventTitle,
               " | Error=",errorCode);
         ResetLastError();
        }
     }
  }

//+------------------------------------------------------------------+
//| Persistent one-time trading-pause notification marker.           |
//| One PROFIT and one LOSS pause alert are allowed per trading date. |
//+------------------------------------------------------------------+
string GetTradingPauseNotifyGlobalKey(string reasonCode)
  {
   // One pause-reason push per account/symbol/date, shared by all chart copies.
   return("DXB_V5_TRADING_PAUSE_" + reasonCode + "_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol());
  }

//+------------------------------------------------------------------+
//| Push only the reason why trading became paused.                   |
//+------------------------------------------------------------------+
void NotifyTradingPausedReasonOnce(string reasonCode,
                                   string eventTitle,
                                   string details)
  {
   int currentDateKey = GetCurrentFreshDayDateKey();
   if(currentDateKey <= 0)
      return;

   string key = GetTradingPauseNotifyGlobalKey(reasonCode);

   // Atomic shared claim: repeated ticks, chart reloads and several chart
   // copies cannot send the same pause reason more than once for this date.
   if(!ClaimDailyNotificationMarker(key,currentDateKey))
      return;

   string msg = InpEAName + " | " + Symbol() + " | " +
                eventTitle + " | " + details;

   if(StringLen(msg) > 250)
      msg = StringSubstr(msg,0,250);

   Print("TRADING PAUSE NOTIFICATION | ",msg);

   if(InpSendTerminalAlerts)
      Alert(msg);

   if(InpSendPushNotifications && !IsTesting())
     {
      ResetLastError();
      if(!SendNotification(msg))
        {
         int errorCode = GetLastError();
         Print("TRADING PAUSE PUSH FAILED | Reason=",reasonCode,
               " | Error=",errorCode);
         ResetLastError();
        }
     }
  }

//+------------------------------------------------------------------+
//| Common clock/hour details appended to pause messages.             |
//+------------------------------------------------------------------+
string GetPauseClockDetails()
  {
   datetime activeClock = GetActiveNoNewOrderClock();
   string activeLabel = GetActiveNoNewOrderClockLabel();
   int activeHour = TimeHour(activeClock);

   string modeText = IsTesting() ? "TESTER" : "LIVE";

   string details =
      "Mode " + modeText +
      " | " + activeLabel + " " +
      TimeToString(activeClock,TIME_DATE|TIME_MINUTES) +
      " | Hour " + IntegerToString(activeHour);

   if(!IsTesting())
      details += " | Server " + TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES);

   return(details);
  }

//+------------------------------------------------------------------+
//| Notify when any hard new-order pause is active.                   |
//+------------------------------------------------------------------+
void NotifyNewOrderHardPauseReasonIfNeeded()
  {
   if(!InpNotifyOnTradingPausedReason)
      return;

   if(IsDubaiNoNewOrderHourNow() && InpNotifyOnNoNewOrderHourPause)
     {
      int activeHour = TimeHour(GetActiveNoNewOrderClock());
      string reasonCode = "NO_NEW_ORDER_HOUR_" + IntegerToString(activeHour);

      NotifyTradingPausedReasonOnce(
         reasonCode,
         "TRADING PAUSED - NO NEW ORDER HOUR",
         "Reason: blocked hour" +
         " | " + GetPauseClockDetails() +
         " | BlockHours " + GetActiveNoNewOrderHourList() +
         " | Existing orders managed");
     }

   if(IsConsecutiveSLPauseActive() && InpNotifyOnConsecutiveSLPause)
     {
      NotifyTradingPausedReasonOnce(
         "CONSECUTIVE_SL_PAUSE",
         "TRADING PAUSED - CONSECUTIVE SL",
         "Reason: consecutive basket SL" +
         " | " + ConsecutiveSLPauseStatusText() +
         " | " + GetPauseClockDetails() +
         " | Existing orders managed");
     }

   if(IsHalfLossPauseActive() && InpNotifyOnHalfLossPause)
     {
      NotifyTradingPausedReasonOnce(
         "HALF_LOSS_COOLING",
         "TRADING PAUSED - HALF LOSS COOLING",
         "Reason: half-loss cooling" +
         " | " + HalfLossPauseStatusText() +
         " | " + GetPauseClockDetails() +
         " | Existing orders managed");
     }
  }

//+------------------------------------------------------------------+
//| Send exactly once when the strict 23:45 GMT0 shutdown begins.         |
//+------------------------------------------------------------------+
void NotifyDayEndResetStartedOnce(int dateKey)
  {
   if(!InpNotifyOnDayEndResetStarted || dateKey <= 0)
      return;

   string key = GetDayEndResetStartedNotifyGlobalKey();

   // The shared account/symbol marker is claimed atomically so every chart
   // cannot announce the same 23:45 GMT0 shutdown.
   if(!ClaimDailyNotificationMarker(key,dateKey))
      return;

   string details =
      "GMT0 " + TimeToString(GetGMT0Time(),TIME_DATE|TIME_SECONDS) +
      " | Closing EA orders | Trading blocked to 00:00";

   SendFreshBootLifecycleNotification("23:45 RESET STARTED",details);
  }

//+------------------------------------------------------------------+
//| Send after every new-day reload/delay/new-bar hold has finished. |
//+------------------------------------------------------------------+
void NotifyNewDayTradingStartedOnce()
  {
   if(!InpNotifyOnNewDayTradingStarted)
      return;

   int currentDateKey = GetCurrentFreshDayDateKey();
   if(currentDateKey <= 0)
      return;

   datetime gmt0Now = GetGMT0Time();
   int minuteOfDay = TimeHour(gmt0Now) * 60 + TimeMinute(gmt0Now);
   int notifyWindow = MathMax(1,MathMin(120,InpNewDayNotifyWindowMinutes));

   // A genuine new-day notification is valid only shortly after 00:00 GMT0.
   // This blocks false alerts caused by attaching/reloading the EA at midday.
   if(minuteOfDay > notifyWindow)
      return;

   // The shutdown marker must be exactly yesterday's GMT0 date. An older
   // stale marker is not accepted as proof that last night's reset completed.
   string resetKey = GetDayEndResetStartedNotifyGlobalKey();
   if(!GlobalVariableCheck(resetKey))
      return;

   int resetDateKey = (int)GlobalVariableGet(resetKey);
   int previousDateKey = GetDateKeyFromTime(GetFreshDayReferenceTime()-86400);

   if(resetDateKey <= 0 || resetDateKey != previousDateKey)
      return;

   string startedKey = GetNewDayTradingStartedNotifyGlobalKey();

   // Atomic shared claim: only one chart/timeframe copy can announce today.
   if(!ClaimDailyNotificationMarker(startedKey,currentDateKey))
      return;

   string details =
      "GMT0 " + TimeToString(gmt0Now,TIME_DATE|TIME_SECONDS) +
      " | Balance $" + DoubleToString(AccountBalance(),2) +
      " | Equity $" + DoubleToString(AccountEquity(),2) +
      " | Lot " + DoubleToString(GetCurrentTradingLot(),2);
   SendFreshBootLifecycleNotification("NEW DAY TRADING STARTED",details);
  }

//+------------------------------------------------------------------+
//| True from the configured GMT0 time through 23:59:59 GMT0.     |
//+------------------------------------------------------------------+
bool IsStrictDayEndFreshBootWindowNow()
  {
   if(!InpUseStrict2345DayEndFreshBoot)
      return(false);

   datetime referenceTime = GetFreshDayReferenceTime();

   int configuredHour = MathMax(0,MathMin(23,InpDayEndFreshBootHour));
   int configuredMinute = MathMax(0,MathMin(59,InpDayEndFreshBootMinute));
   int currentMinuteOfDay = TimeHour(referenceTime) * 60 +
                            TimeMinute(referenceTime);
   int startMinuteOfDay = configuredHour * 60 + configuredMinute;

   return(currentMinuteOfDay >= startMinuteOfDay);
  }

//+------------------------------------------------------------------+
//| Read persistent shutdown markers during every OnInit().          |
//+------------------------------------------------------------------+
void InitializeStrictDayEndFreshBootState()
  {
   g_dayEndPreparedDateKey = 0;
   g_dayEndReloadedDateKey = 0;
   g_dayEndResetInProgress = false;

   string preparedKey = GetDayEndPreparedGlobalKey();
   string reloadedKey = GetDayEndReloadedGlobalKey();

   if(GlobalVariableCheck(preparedKey))
      g_dayEndPreparedDateKey = (int)GlobalVariableGet(preparedKey);

   if(GlobalVariableCheck(reloadedKey))
      g_dayEndReloadedDateKey = (int)GlobalVariableGet(reloadedKey);

   int currentDateKey = GetCurrentFreshDayDateKey();

   if(IsStrictDayEndFreshBootWindowNow())
     {
      if(g_dayEndPreparedDateKey == currentDateKey)
         g_dayEndFreshBootStatus =
            "23:45 RESET COMPLETE | TICKS BLOCKED TO 00:00";
      else
         g_dayEndFreshBootStatus =
            "23:45 RESET PENDING | TICKS BLOCKED";
     }
   else
      g_dayEndFreshBootStatus =
         "READY | NEXT 23:45 RESET";
  }

//+------------------------------------------------------------------+
//| First OnTick gate: prepare at 23:45 and block until midnight.    |
//+------------------------------------------------------------------+
bool HandleStrict2345DayEndFreshBoot()
  {
   if(!InpUseStrict2345DayEndFreshBoot)
      return(true);

   int currentDateKey = GetCurrentFreshDayDateKey();

   // Midnight/new day: release only this day-end gate. The existing fresh-day
   // handler and daily EA reinitializer run immediately after this function.
   if(!IsStrictDayEndFreshBootWindowNow())
     {
      g_dayEndResetInProgress = false;
      g_dayEndFreshBootStatus = "READY | NEXT 23:45 RESET";
      return(true);
     }

   string preparedKey = GetDayEndPreparedGlobalKey();
   string reloadedKey = GetDayEndReloadedGlobalKey();

   if(GlobalVariableCheck(preparedKey))
      g_dayEndPreparedDateKey = (int)GlobalVariableGet(preparedKey);

   if(GlobalVariableCheck(reloadedKey))
      g_dayEndReloadedDateKey = (int)GlobalVariableGet(reloadedKey);

   // Perform the close/delete/reset sequence only once for this date. If an
   // order close fails, remain blocked and retry on the next tick.
   if(g_dayEndPreparedDateKey != currentDateKey)
     {
      g_dayEndResetInProgress = true;
      g_dayEndFreshBootStatus =
         "23:45 RESETTING | ALL TICKS BLOCKED";

      NotifyDayEndResetStartedOnce(currentDateKey);

      string reason = "STRICT 23:45 DAY-END RESET " +
                      IntegerToString(currentDateKey);

      if(InpDayEndDeletePendingOrders)
         DeletePendingOrdersByDirection(0,reason,false);

      int marketRemaining = 0;
      if(InpDayEndCloseMarketOrders)
         marketRemaining = CloseAllEAMarketOrdersForFreshDay(reason);
      else
         marketRemaining = CountAllEAMarketOrdersForRestart();

      if(marketRemaining > 0)
        {
         g_dayEndFreshBootStatus =
            "23:45 WAIT CLOSE | " +
            IntegerToString(marketRemaining) +
            " MARKET ORDER(S) | TICKS BLOCKED";

         Print(g_dayEndFreshBootStatus);
         return(false);
        }

      // Catch any pending order that changed state during the close loop.
      if(InpDayEndDeletePendingOrders)
         DeletePendingOrdersByDirection(0,reason + " | FINAL",false);

      // Remove every known persistent strategy value that must not survive
      // into the next day. Keep only the strict day-end anti-loop markers
      // and the daily restart DATE marker required to trigger the 00:00
      // post-reset ChartSetSymbolPeriod() reinitialization.
      DeleteStrictDayEndPersistentStateExceptBootMarkers();

      if(InpDayEndResetRuntimeState)
         ResetAllFreshDayRuntimeState();

      g_dayEndPreparedDateKey = currentDateKey;
      g_dayEndResetInProgress = false;

      GlobalVariableSet(preparedKey,(double)currentDateKey);
      GlobalVariablesFlush();

      Print("STRICT 23:45 DAY-END RESET COMPLETE",
            " | Date=",currentDateKey,
            " | MarketOrders=",CountAllEAMarketOrdersForRestart(),
            " | PendingOrders=",CountAllEAPendingOrdersForRestart(),
            " | HoldUntil=00:00");
     }

   bool mayReinitialize = InpDayEndReinitializeEA &&
                          (!IsTesting() ||
                           InpDayEndReinitializeEAInTesting);

   // A real chart reinitialization reloads every compiled global/configuration
   // declaration. This is the complete fallback that cannot miss a newly added
   // runtime variable. The persistent RELOADED key prevents a reinit loop.
   if(mayReinitialize &&
      g_dayEndReloadedDateKey != currentDateKey)
     {
      GlobalVariableSet(reloadedKey,(double)currentDateKey);
      GlobalVariablesFlush();
      g_dayEndReloadedDateKey = currentDateKey;

      g_dayEndFreshBootStatus =
         "23:45 RESET COMPLETE | EA RELOAD REQUESTED | HOLD TO 00:00";

      ResetLastError();
      bool requested = ChartSetSymbolPeriod(
                           0,
                           NULL,
                           (ENUM_TIMEFRAMES)Period()
                       );

      if(!requested)
        {
         int errorCode = GetLastError();

         if(GlobalVariableCheck(reloadedKey))
            GlobalVariableDel(reloadedKey);
         GlobalVariablesFlush();

         g_dayEndReloadedDateKey = 0;
         g_dayEndFreshBootStatus =
            "23:45 EA RELOAD FAILED | ERR " +
            IntegerToString(errorCode) +
            " | TICKS BLOCKED";

         Print(g_dayEndFreshBootStatus);
         ResetLastError();
         return(false);
        }

      Print("STRICT 23:45 EA REINITIALIZATION REQUESTED",
            " | Date=",currentDateKey,
            " | Ticks remain blocked through 23:59:59");

      return(false);
     }

   g_dayEndFreshBootStatus =
      "23:45 RESET COMPLETE | TICKS BLOCKED TO 00:00";

   return(false);
  }

//+------------------------------------------------------------------+
string GetDailyEARestartGlobalKey()
  {
   return("DXB_REINIT_DATE_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
string GetDailyEAResumeGlobalKey()
  {
   return("DXB_REINIT_WAIT_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
//| Delete persistent strategy memory at the strict 23:45 GMT0 shutdown.  |
//|                                                                  |
//| PRESERVED intentionally:                                         |
//|   DXB_DAYEND_PREPARED_*  prevents repeated close/reset loops.     |
//|   DXB_DAYEND_RELOADED_*  prevents repeated chart reload loops.    |
//|   DXB_REINIT_DATE_*      keeps the OLD date so 00:00 requests the |
//|                          final post-reset EA reinitialization.     |
//|   DXB_DAYEND_NOTIFY_*     prevents duplicate reset-start pushes.   |
//|                                                                  |
//| DELETED: old fresh-day history cutoff, stale post-restart wait,   |
//| consecutive-SL persistence and legacy guard-parent mappings.      |
//+------------------------------------------------------------------+
void DeleteStrictDayEndPersistentStateExceptBootMarkers()
  {
   if(IsTesting())
      return;

   string cutoffTimeKey = GetFreshDayCutoffTimeGlobalKey();
   string cutoffDateKey = GetFreshDayCutoffDateGlobalKey();
   string resumeKey     = GetDailyEAResumeGlobalKey();
   string slCountKey    = ConsecutiveSLStateKey("COUNT");
   string slUntilKey    = ConsecutiveSLStateKey("UNTIL");

   if(GlobalVariableCheck(cutoffTimeKey))
      GlobalVariableDel(cutoffTimeKey);
   if(GlobalVariableCheck(cutoffDateKey))
      GlobalVariableDel(cutoffDateKey);
   if(GlobalVariableCheck(resumeKey))
      GlobalVariableDel(resumeKey);
   if(GlobalVariableCheck(slCountKey))
      GlobalVariableDel(slCountKey);
   if(GlobalVariableCheck(slUntilKey))
      GlobalVariableDel(slUntilKey);

   string guardPrefix = "SAR_GUARD_PARENT_" + Symbol() + "_" +
                        IntegerToString(InpMagicNumber) + "_";

   for(int i=GlobalVariablesTotal()-1; i>=0; i--)
     {
      string name = GlobalVariableName(i);
      if(StringFind(name,guardPrefix,0) == 0)
         GlobalVariableDel(name);
     }

   GlobalVariablesFlush();

   Print("STRICT 23:45 PERSISTENT STATE CLEARED",
         " | Preserved=DAYEND_PREPARED,DAYEND_RELOADED,REINIT_DATE,DAYEND_NOTIFY",
         " | Deleted=FRESH_CUTOFF,REINIT_WAIT,SL_STREAK,GUARD_MAPS");
  }

//+------------------------------------------------------------------+
//| Count every EA market order, including a legacy guard order.     |
//+------------------------------------------------------------------+
int CountAllEAMarketOrdersForRestart()
  {
   int total = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
//| Count every untriggered EA pending order.                        |
//+------------------------------------------------------------------+
int CountAllEAPendingOrdersForRestart()
  {
   int total = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(type == OP_BUYSTOP || type == OP_SELLSTOP ||
         type == OP_BUYLIMIT || type == OP_SELLLIMIT)
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
//| Initialize persistent daily restart tracking without restarting. |
//+------------------------------------------------------------------+
void InitializeDailyEARestart()
  {
   if(!InpRestartEADaily)
     {
      g_dailyEAReinitStatus = "OFF";
      return;
     }

   if(IsTesting() && !InpRestartEAInTesting)
     {
      g_dailyEAReinitStatus = "TEST MODE | STRICT INTERNAL BOOT";
      return;
     }

   string restartKey = GetDailyEARestartGlobalKey();
   string resumeKey  = GetDailyEAResumeGlobalKey();
   int currentDate   = GetCurrentFreshDayDateKey();

   // First installation or a new magic/symbol/timeframe combination:
   // remember today and do not immediately restart.
   if(!GlobalVariableCheck(restartKey))
     {
      GlobalVariableSet(restartKey,currentDate);
      GlobalVariablesFlush();
      g_dailyEAReinitStatus = "INITIALIZED | " + IntegerToString(currentDate);

      Print("EA DAILY RESTART INITIALIZED | Date=",currentDate,
            " | Key=",restartKey);
     }
   else
      g_dailyEAReinitStatus = "READY | " + IntegerToString(currentDate);

   // Recover the post-restart hold written before ChartSetSymbolPeriod().
   // Keep the hold even when the minute delay is zero because the optional
   // new-M1-bar condition may still need to be satisfied.
   if(GlobalVariableCheck(resumeKey))
     {
      datetime resumeTime = (datetime)GlobalVariableGet(resumeKey);

      if(resumeTime < TimeCurrent())
         resumeTime = TimeCurrent();

      g_dailyEAResumeAfter   = resumeTime;
      g_dailyEAReinitBarTime = iTime(Symbol(),PERIOD_M1,0);
      g_dailyEAReinitStatus  = "POST-RESTART WAIT";
     }
  }

//+------------------------------------------------------------------+
//| Hold new strategy processing after reinitialization.             |
//+------------------------------------------------------------------+
bool IsDailyEAResumeHoldActive()
  {
   if(g_dailyEAResumeAfter <= 0)
      return(false);

   bool timeReady = (TimeCurrent() >= g_dailyEAResumeAfter);
   datetime currentM1Bar = iTime(Symbol(),PERIOD_M1,0);
   bool barReady = (!InpRestartEAWaitForNewM1Bar ||
                    (currentM1Bar > 0 &&
                     currentM1Bar != g_dailyEAReinitBarTime));

   if(timeReady && barReady)
     {
      string resumeKey = GetDailyEAResumeGlobalKey();
      if(GlobalVariableCheck(resumeKey))
         GlobalVariableDel(resumeKey);

      GlobalVariablesFlush();

      g_dailyEAResumeAfter   = 0;
      g_dailyEAReinitBarTime = 0;
      g_dailyEAReinitStatus  = "READY AFTER REINIT | " +
                               IntegerToString(GetCurrentFreshDayDateKey());

      Print("EA DAILY RESTART HOLD COMPLETE | Trading may resume",
            " | Date=",GetCurrentFreshDayDateKey());

      return(false);
     }

   int secondsRemaining = (int)MathMax(0,g_dailyEAResumeAfter-TimeCurrent());

   g_dailyEAReinitStatus =
      "WAIT " + IntegerToString(secondsRemaining) + "s" +
      (barReady ? " | BAR READY" : " | WAIT NEW M1");

   return(true);
  }

//+------------------------------------------------------------------+
//| Request one EA reinitialization per fresh day.                   |
//+------------------------------------------------------------------+
bool CheckDailyEARestart()
  {
   if(!InpRestartEADaily)
     {
      g_dailyEAReinitStatus = "OFF";
      return(false);
     }

   if(IsTesting() && !InpRestartEAInTesting)
     {
      g_dailyEAReinitStatus = "TEST MODE | INTERNAL RESET ONLY";
      return(false);
     }

   string restartKey = GetDailyEARestartGlobalKey();
   string resumeKey  = GetDailyEAResumeGlobalKey();
   int currentDate   = GetCurrentFreshDayDateKey();
   int storedDate    = 0;

   if(!GlobalVariableCheck(restartKey))
     {
      GlobalVariableSet(restartKey,currentDate);
      GlobalVariablesFlush();
      g_dailyEAReinitStatus = "INITIALIZED | " + IntegerToString(currentDate);
      return(false);
     }

   storedDate = (int)GlobalVariableGet(restartKey);

   if(storedDate == currentDate)
      return(false);

   // Never reinitialize while the mandatory fresh-day close/reset sequence
   // is still incomplete.
   if(g_freshDayResetInProgress)
     {
      g_dailyEAReinitStatus = "WAIT FRESH-DAY RESET";
      return(false);
     }

   if(InpUseFreshDayStart && g_freshDayDateKey != currentDate)
     {
      g_dailyEAReinitStatus = "WAIT FRESH-DAY DATE";
      return(false);
     }

   int marketOrders  = CountAllEAMarketOrdersForRestart();
   int pendingOrders = CountAllEAPendingOrdersForRestart();

   if(InpRestartEAOnlyWhenFlat &&
      (marketOrders > 0 || pendingOrders > 0))
     {
      g_dailyEAReinitStatus =
         "WAIT FLAT | MKT " + IntegerToString(marketOrders) +
         " | PEND " + IntegerToString(pendingOrders);
      return(false);
     }

   // Save the date before requesting reinitialization. This prevents an
   // endless OnInit -> OnTick -> reinitialize loop.
   GlobalVariableSet(restartKey,currentDate);

   int delayMinutes = MathMax(0,InpRestartEAResumeDelayMinutes);
   g_dailyEAResumeAfter = TimeCurrent() + delayMinutes*60;
   g_dailyEAReinitBarTime = iTime(Symbol(),PERIOD_M1,0);

   // Store at least the current time. New-M1 waiting can still keep the EA
   // paused when the configured minute delay is zero.
   GlobalVariableSet(resumeKey,g_dailyEAResumeAfter);
   GlobalVariablesFlush();

   g_dailyEAReinitStatus = "REINITIALIZATION REQUESTED | " +
                            IntegerToString(currentDate);

   Print("NEW FRESH DAY | EA SELF-REINITIALIZATION REQUESTED",
         " | Date=",currentDate,
         " | MarketOrders=",marketOrders,
         " | PendingOrders=",pendingOrders,
         " | ResumeAfter=",
         TimeToString(g_dailyEAResumeAfter,TIME_DATE|TIME_SECONDS));

   ResetLastError();

   bool requested = ChartSetSymbolPeriod(
                        0,
                        NULL,
                        (ENUM_TIMEFRAMES)Period()
                    );

   if(!requested)
     {
      int errorCode = GetLastError();

      Print("EA DAILY REINITIALIZATION REQUEST FAILED",
            " | Error=",errorCode,
            " | Date=",currentDate);

      // Restore the previous date so the next tick may retry.
      GlobalVariableSet(restartKey,storedDate);
      if(GlobalVariableCheck(resumeKey))
         GlobalVariableDel(resumeKey);
      GlobalVariablesFlush();

      g_dailyEAResumeAfter   = 0;
      g_dailyEAReinitBarTime = 0;
      g_dailyEAReinitStatus  = "REQUEST FAILED | ERR " +
                               IntegerToString(errorCode);

      ResetLastError();
      return(false);
     }

   return(true);
  }
string CreateDubaiHourListFromGMT(string sourceHourList, int addHours = 4, bool sortResult = true)
{
   string parts[];
   int count = StringSplit(sourceHourList, ',', parts);

   bool used[24];
   for(int i = 0; i < 24; i++)
      used[i] = false;

   for(int i = 0; i < count; i++)
   {
      string txt = StringTrimLeft(StringTrimRight(parts[i]));
      if(txt == "")
         continue;

      int hour = (int)StringToInteger(txt);

      if(hour < 0 || hour > 23)
         continue;

      int dubaiHour = hour + addHours;

      while(dubaiHour >= 24)
         dubaiHour -= 24;

      while(dubaiHour < 0)
         dubaiHour += 24;

      used[dubaiHour] = true;
   }

   string result = "";

   if(sortResult)
   {
      for(int h = 0; h < 24; h++)
      {
         if(used[h])
         {
            if(result != "")
               result += ",";

            result += IntegerToString(h);
         }
      }
   }
   else
   {
      for(int i = 0; i < count; i++)
      {
         string txt = StringTrimLeft(StringTrimRight(parts[i]));
         if(txt == "")
            continue;

         int hour = (int)StringToInteger(txt);
         if(hour < 0 || hour > 23)
            continue;

         int dubaiHour = hour + addHours;

         while(dubaiHour >= 24)
            dubaiHour -= 24;

         while(dubaiHour < 0)
            dubaiHour += 24;

         if(result != "")
            result += ",";

         result += IntegerToString(dubaiHour);
      }
   }

   return result;
}
int OnInit()
  {
   // Resolve the final magic number before any order scan or terminal
   // Global-Variable key is initialized.
   InpMagicNumber = AccountNumber() + 202;

   Print("NO NEW ORDER HOURS GMT0 ONLY: ", InpNoNewOrderHourList);

   // Load only the persistent 23:45 anti-loop markers first. A chart reload
   // has already recreated every compiled global/static variable from its
   // declaration value. During the day-end hold we must NOT rebuild equity,
   // order-history, recovery, pause or SAR-cycle state from the old day.
   InitializeStrictDayEndFreshBootState();

   if(InpUseFreshBootOneSecondTimer)
      EventSetTimer(1);

   g_onInitTickCount        = GetTickCount();
   g_tickConfirmationCount = 0;

   if(IsStrictDayEndFreshBootWindowNow())
     {
      int holdDateKey = GetCurrentFreshDayDateKey();

      // Keep the OLD date only in these date trackers. At 00:00 the date
      // mismatch forces HandleFreshDayStart() through the complete close,
      // persistent cleanup, history-cutoff, opening-balance and startup path.
      g_freshDayDateKey         = holdDateKey;
      g_equityDateKey           = holdDateKey;
      g_freshDayStartServerTime = GetCurrentFreshDayStartServerTime();
      g_freshDayResetInProgress = false;
      g_freshDayStatus          = "STRICT 23:45 HOLD | WAIT 00:00";

      // This is one of the few values intentionally preserved. If the EA was
      // attached for the first time during the hold, create the OLD-day marker
      // now so CheckDailyEARestart() will still perform the final 00:00 reload.
      if(InpRestartEADaily &&
         (!IsTesting() || InpRestartEAInTesting))
        {
         string restartKey = GetDailyEARestartGlobalKey();
         if(!GlobalVariableCheck(restartKey))
           {
            GlobalVariableSet(restartKey,(double)holdDateKey);
            GlobalVariablesFlush();
           }
        }

      g_dailyEAReinitStatus = "DAY-END HOLD | FINAL REINIT AFTER 00:00 RESET";

      Print("EA INITIALIZED DURING STRICT 23:45 HOLD",
            " | All compiled globals/statics restored to declarations",
            " | Old-day strategy reconstruction skipped",
            " | Date=",holdDateKey,
            " | Status=",g_dayEndFreshBootStatus,
            " | ReferenceTime=",
            TimeToString(GetFreshDayReferenceTime(),TIME_DATE|TIME_SECONDS));

      Comment(g_dayEndFreshBootStatus);
      return(INIT_SUCCEEDED);
     }

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





   // Tester and live use the same trading protections. Only their clock source
   // differs. Account-number exemption remains a live/account configuration.
   if(AccountNumber() == InpEquityLockExemptAccount &&
      InpEquityLockExemptAccount > 0)
     {
      Print("LIVE ACCOUNT EXEMPT | Account=",AccountNumber(),
            " | Opening-balance equity lock disabled");
     }



   InitializeEquityDay();
   g_freshDayStatus = "READY | " + IntegerToString(g_freshDayDateKey);
   InitializeLastDepositBalanceOpTime();
   DeleteNonEarlySignalArrows();
   DeleteOldDashboardObjects();
   LoadLast5SARChangeDurations();

   // Initialize after the final runtime magic number is known so the
   // terminal Global Variable keys remain stable across reinitializations.
   InitializeDailyEARestart();

   LoadConsecutiveSLPauseState();

   RestoreOppositeImpulsePendingState();
   InitializeCreatedClosedPushTracker();
   InitializeSLReverseRecoveryChainTracker();

// Restore an active opposite-side pause after EA restart from account history.
   UpdateOppositeDirectionProfitPause(true);

   Print(InpEAName, " initialized. Magic=", InpMagicNumber,
         " | ActiveNoNewHours=",GetActiveNoNewOrderHourList(),
         " | SLStreak=",ConsecutiveSLPauseStatusText(),
         " | BaseBalance=$", DoubleToString(g_baseBalance,2),
         " | LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
         " | ProfitTargetEquity=$", DoubleToString(g_profitTargetEquity,2),
         " | TargetProfit=$", DoubleToString(g_dailyProfitTarget,2),
         " | FreshDay=",g_freshDayStatus,
         " | DailyBalanceMode=ACTUAL NEW-DAY BALANCE",
         " | DailyReinit=",g_dailyEAReinitStatus,
         " | PendingGap=",DoubleToString(GetConfiguredPendingOrderGapRaw(),1),
         " | HistoryCutoff=",
         TimeToString(g_freshDayHistoryCutoffTime,TIME_DATE|TIME_SECONDS));

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
   if(InpUseFreshBootOneSecondTimer)
      EventKillTimer();

   for(int i = ObjectsTotal(0,-1,-1)-1; i >= 0; i--)
     {
      string objectName = ObjectName(0,i);

      if(StringFind(objectName,"DXB_ENTRY_AUDIT_") == 0 ||
         StringFind(objectName,"DXB_RECOVERY_") == 0 ||
         StringFind(objectName,"DXB_PRO_REC_") == 0 ||
         StringFind(objectName,"DXB_PRO_LEFT_") == 0 ||
         StringFind(objectName,"DXB_PRO_RIGHT_") == 0 ||
         StringFind(objectName,"DXB_TICK_SPEED_") == 0 ||
         StringFind(objectName,"DXB_IMPULSE_") == 0 ||
         StringFind(objectName,"DXB_RIGHT_") == 0 ||
         StringFind(objectName,"DXB_LIVE_MODE_") == 0 ||
         StringFind(objectName,"DXB_ACC_") == 0 ||
         StringFind(objectName,"DXB_COMPACT_") == 0)
         ObjectDelete(0,objectName);
     }

   Comment("");
  }
//+------------------------------------------------------------------+
//| Normalized daily profit-percentage ladder levels                 |
//+------------------------------------------------------------------+
int GetDailyProfitLadderMaxLevel()
  {
   return(6);
  }

//+------------------------------------------------------------------+
double GetDailyProfitLadderPercent(int level)
  {
   double level1 = MathMax(0.0,InpProfitLadderPercent1);
   double level2 = MathMax(level1,InpProfitLadderPercent2);
   double level3 = MathMax(level2,InpProfitLadderPercent3);
   double level4 = MathMax(level3,InpProfitLadderPercent4);
   double level5 = MathMax(level4,InpProfitLadderPercent5);
   double level6 = MathMax(level5,InpProfitLadderPercent6);

   if(level <= 1) return(level1);
   if(level == 2) return(level2);
   if(level == 3) return(level3);
   if(level == 4) return(level4);
   if(level == 5) return(level5);
   return(level6);
  }

//+------------------------------------------------------------------+
double GetDailyProfitLadderArmPercent(int level)
  {
   double nominal =
      GetDailyProfitLadderPercent(level);

   if(InpProfitLadderFinalLevelExact &&
      level >= GetDailyProfitLadderMaxLevel())
      return(nominal);

   return(MathMax(
             0.0,
             nominal -
             MathMax(0.0,
                     InpProfitLadderArmTolerancePercent)));
  }

//+------------------------------------------------------------------+
double GetDailyProfitLadderProtectedPercent(int level)
  {
   double arm1 = GetDailyProfitLadderArmPercent(1);
   double arm2 = GetDailyProfitLadderArmPercent(2);
   double arm3 = GetDailyProfitLadderArmPercent(3);
   double arm4 = GetDailyProfitLadderArmPercent(4);
   double arm5 = GetDailyProfitLadderArmPercent(5);
   double arm6 = GetDailyProfitLadderArmPercent(6);

   double protect1 =
      MathMin(arm1,
              MathMax(0.0,
                      InpProfitLadderProtectPercent1));

   double protect2 =
      MathMin(arm2,
              MathMax(protect1,
                      InpProfitLadderProtectPercent2));

   double protect3 =
      MathMin(arm3,
              MathMax(protect2,
                      InpProfitLadderProtectPercent3));

   double protect4 =
      MathMin(arm4,
              MathMax(protect3,
                      InpProfitLadderProtectPercent4));

   double protect5 =
      MathMin(arm5,
              MathMax(protect4,
                      InpProfitLadderProtectPercent5));

   double protect6 =
      MathMin(arm6,
              MathMax(protect5,
                      InpProfitLadderProtectPercent6));

   if(level <= 1) return(protect1);
   if(level == 2) return(protect2);
   if(level == 3) return(protect3);
   if(level == 4) return(protect4);
   if(level == 5) return(protect5);
   return(protect6);
  }

//+------------------------------------------------------------------+
//| Fixed minimum floor belonging to the highest booked level       |
//+------------------------------------------------------------------+
double GetCurrentBookedLadderBaseFloorPercent()
  {
   if(g_profitPercentHighestLevel <= 0)
      return(0.0);

   return(GetDailyProfitLadderProtectedPercent(
             g_profitPercentHighestLevel));
  }

//+------------------------------------------------------------------+
//| Lock a share of the highest TOTAL daily profit                   |
//+------------------------------------------------------------------+
double GetHighestProfitShareLockedPercent()
  {
   if(!InpUseHighestProfitShareLock ||
      g_profitPercentHighestLevel <= 0)
      return(0.0);

   double lockShare =
      MathMax(0.0,
              MathMin(100.0,
                      InpHighestProfitLockSharePercent)) / 100.0;

   return(MathMax(0.0,
                  g_profitPercentPeakPercent * lockShare));
  }

//+------------------------------------------------------------------+
//| Early close trigger used to retain the intended protected floor |
//+------------------------------------------------------------------+
double GetDailyProfitLadderCloseTriggerPercent(double protectedPercent)
  {
   double earlyCloseBuffer =
      MathMax(0.0,InpProfitLadderFloorCloseBufferPercent);

   double returnBuffer =
      MathMax(0.0,InpProfitLadderReturnBufferPercent);

   return(MathMax(0.0,
                  MathMax(0.0,protectedPercent) +
                  earlyCloseBuffer -
                  returnBuffer));
  }

//+------------------------------------------------------------------+
//| Raise lock to the configured share of the remembered peak profit|
//+------------------------------------------------------------------+
void UpdateHighestDailyProfitShareFloor()
  {
   if(g_profitPercentHighestLevel <= 0 ||
      g_profitPercentAwaitingNewOrder ||
      !InpUseHighestProfitShareLock)
      return;

   double candidate =
      GetHighestProfitShareLockedPercent();

   if(candidate <= g_profitPercentProtectedPercent+0.0000001)
      return;

   g_profitPercentProtectedPercent = candidate;
   g_profitPercentProtectedEquity =
      GetDailyProfitLadderEquity(
         g_profitPercentProtectedPercent);

   // Avoid flooding the Experts log on every tiny tick increase.
   if(g_profitPercentProtectedPercent >=
      g_profitPercentLastTrailLogFloor+0.50)
     {
      g_profitPercentLastTrailLogFloor =
         g_profitPercentProtectedPercent;

      string trailMsg =
         "HIGHEST TOTAL DAILY PROFIT SHARE LOCK MOVED" +
         " | PeakProfit=" +
         DoubleToString(g_profitPercentPeakPercent,2) + "%" +
         " | LockShare=" +
         DoubleToString(
            MathMax(0.0,
                    MathMin(100.0,
                            InpHighestProfitLockSharePercent)),2) + "%" +
         " | LockedProfit=" +
         DoubleToString(g_profitPercentProtectedPercent,2) + "%" +
         " | LockedEquity=$" +
         DoubleToString(g_profitPercentProtectedEquity,2) +
         " | CloseTrigger=" +
         DoubleToString(
            GetDailyProfitLadderCloseTriggerPercent(
               g_profitPercentProtectedPercent),2) + "%";

      Print(trailMsg);
     }
  }

//+------------------------------------------------------------------+
string DailyProfitLadderLevelsText(int decimals)
  {
   string result = "";
   int maxLevel = GetDailyProfitLadderMaxLevel();

   for(int level=1; level<=maxLevel; level++)
     {
      if(level > 1)
         result += "/";

      result += DoubleToString(
                   GetDailyProfitLadderPercent(level),
                   decimals);
     }

   return(result + "%");
  }

//+------------------------------------------------------------------+
string DailyProfitLadderTargetProtectText(int decimals)
  {
   string result = "";
   int maxLevel = GetDailyProfitLadderMaxLevel();

   for(int level=1; level<=maxLevel; level++)
     {
      if(level > 1)
         result += "/";

      result += DoubleToString(
                   GetDailyProfitLadderPercent(level),
                   decimals);

      if(level >= maxLevel &&
         InpCloseAtFinalProfitLadderLevel)
         result += ">CLOSE";
      else
         result += ">" +
                   DoubleToString(
                      GetDailyProfitLadderProtectedPercent(level),
                      decimals);
     }

   return(result);
  }

//+------------------------------------------------------------------+
double GetDailyProfitLadderEquity(double profitPercent)
  {
   return(GetEquityCycleAnchor() +
          (MathMax(0.0,g_baseBalance) *
           MathMax(0.0,profitPercent) / 100.0));
  }

//+------------------------------------------------------------------+
double GetDailyEquityProfitPercent(double equityValue)
  {
   if(g_baseBalance <= 0.0)
      return(0.0);

   return((equityValue-GetEquityCycleAnchor()) /
          g_baseBalance * 100.0);
  }

//+------------------------------------------------------------------+
bool IsDailyProfitPauseActive()
  {
   if(!g_dailyProfitLock)
      return(false);

   if(InpUseDailyProfitPercentLadder)
      return(InpPauseAfterProfitLadderClose);

   return(InpPauseAfterProfitTarget);
  }

//+------------------------------------------------------------------+
string DailyProfitPercentLadderStatusText()
  {
   if(!InpUseDailyProfitLock)
      return("OFF | DAILY PROFIT LOCK OFF");

   if(!InpUseDailyProfitPercentLadder)
      return("FIXED " +
             DoubleToString(InpProfitTargetPercent,2) +
             "% | TARGET $" +
             DoubleToString(g_profitTargetEquity,2));

   double currentPercent =
      GetDailyEquityProfitPercent(AccountEquity());

   if(g_dailyProfitLock)
      return(g_profitPercentLadderStatus);

   if(InpUseHighestProfitShareLock)
     {
      double activationPercent =
         MathMax(0.0,GetDailyProfitLadderPercent(1));

      if(g_profitPercentHighestLevel <= 0)
         return("READY | NOW " +
                DoubleToString(currentPercent,2) +
                "% | ACTIVATE " +
                DoubleToString(activationPercent,2) +
                "% EXACT | THEN LOCK " +
                DoubleToString(
                   MathMax(0.0,
                           MathMin(100.0,
                                   InpHighestProfitLockSharePercent)),0) +
                "% OF PEAK PROFIT");

      if(g_profitPercentAwaitingNewOrder)
         return("FIRST " +
                DoubleToString(activationPercent,2) +
                "% BOOKED | WAIT NEW ORDER | PEAK " +
                DoubleToString(g_profitPercentPeakPercent,2) +
                "% | FUTURE LOCK " +
                DoubleToString(
                   GetHighestProfitShareLockedPercent(),2) + "%");

      return("UNLIMITED SHARE LOCK | PEAK " +
             DoubleToString(g_profitPercentPeakPercent,2) +
             "% | LOCKED " +
             DoubleToString(g_profitPercentProtectedPercent,2) +
             "% | CLOSE " +
             DoubleToString(
                GetDailyProfitLadderCloseTriggerPercent(
                   g_profitPercentProtectedPercent),2) +
             "% | NOW " +
             DoubleToString(currentPercent,2) + "%");
     }

   if(g_profitPercentHighestLevel <= 0)
      return("READY | NOW " +
             DoubleToString(currentPercent,2) +
             "% | FIRST TARGET " +
             DoubleToString(GetDailyProfitLadderPercent(1),2) +
             "% EXACT");

   int maxLevel = GetDailyProfitLadderMaxLevel();
   int nextLevel = MathMin(maxLevel,
                           g_profitPercentHighestLevel+1);

   if(g_profitPercentAwaitingNewOrder)
      return("L" +
             IntegerToString(g_profitPercentHighestLevel) +
             " BOOKED " +
             DoubleToString(
                GetDailyProfitLadderPercent(
                   g_profitPercentHighestLevel),2) +
             "% | WAIT NEW ORDER | BASE FLOOR " +
             DoubleToString(
                GetCurrentBookedLadderBaseFloorPercent(),2) +
             "% | PEAK " +
             DoubleToString(g_profitPercentPeakPercent,2) +
             "% | NOW " +
             DoubleToString(currentPercent,2) + "%");

   return("L" +
          IntegerToString(g_profitPercentHighestLevel) +
          " ACTIVE | PEAK " +
          DoubleToString(g_profitPercentPeakPercent,2) +
          "% | FLOOR " +
          DoubleToString(g_profitPercentProtectedPercent,2) +
          "% | CLOSE " +
          DoubleToString(
             GetDailyProfitLadderCloseTriggerPercent(
                g_profitPercentProtectedPercent),2) +
          "% | NOW " +
          DoubleToString(currentPercent,2) +
          (g_profitPercentHighestLevel < maxLevel
           ? "% | NEXT " +
             DoubleToString(
                GetDailyProfitLadderPercent(nextLevel),2) + "%"
           : "% | FINAL LEVEL"));
  }

//+------------------------------------------------------------------+
string DailyProfitPauseDashboardText()
  {
   if(g_equityProtectionHit)
      return("OPENING BALANCE LOSS LOCK - PAUSED");

   if(g_dailyProfitLock)
     {
      if(InpUseDailyProfitPercentLadder)
         return(InpUseHighestProfitShareLock
                ? "HIGHEST PROFIT SHARE LOCK - PAUSED"
                : "DAILY PROFIT PERCENT LADDER LOCK - PAUSED");

      return("OPENING BALANCE PROFIT LOCK - PAUSED");
     }

   return("EQUITY GUARD CLEAR");
  }

//+------------------------------------------------------------------+
bool LockDailyProfitPercentLadder(string lockReason,
                                  double currentEquity,
                                  double currentPercent)
  {
   if(g_dailyProfitLock)
      return(IsDailyProfitPauseActive());

   g_dailyProfitLock = true;
   g_profitPercentLadderHit = true;
   g_lockedProfitToday =
      currentEquity-GetEquityCycleAnchor();

   g_profitPercentLadderStatus =
      "LOCKED | " + lockReason +
      " | EQUITY $" +
      DoubleToString(currentEquity,2) +
      " | PROFIT " +
      DoubleToString(currentPercent,2) +
      "%";

   if(InpCloseOrdersOnProfitLock)
      CloseAllEAOrders("DAILY PROFIT PERCENT LADDER | " +
                       lockReason);

   Print("DAILY PROFIT PERCENT LADDER LOCK",
         " | Reason=",lockReason,
         " | EquityAnchor=$",
         DoubleToString(GetEquityCycleAnchor(),2),
         " | StrategyReference=$",
         DoubleToString(g_baseBalance,2),
         " | Equity=$",
         DoubleToString(currentEquity,2),
         " | Profit=$",
         DoubleToString(g_lockedProfitToday,2),
         " | ProfitPercent=",
         DoubleToString(currentPercent,2),"%",
         " | PeakPercent=",
         DoubleToString(g_profitPercentPeakPercent,2),"%",
         " | ProtectedPercent=",
         DoubleToString(g_profitPercentProtectedPercent,2),"%",
         " | ProtectedEquity=$",
         DoubleToString(g_profitPercentProtectedEquity,2),
         " | Trading ",
         InpPauseAfterProfitLadderClose
         ? "paused until next equity reset."
         : "not permanently paused by ladder setting.");

   if(InpNotifyOnProfitLock && !g_notifyProfitLockSent)
     {
      g_notifyProfitLockSent = true;

      string pauseDetails =
         "Reason: " + lockReason +
         " | Equity $" +
         DoubleToString(currentEquity,2) +
         " | Anchor $" +
         DoubleToString(GetEquityCycleAnchor(),2) +
         " | Ref $" +
         DoubleToString(g_baseBalance,2) +
         " | Profit " +
         DoubleToString(currentPercent,2) +
         "% | Peak " +
         DoubleToString(g_profitPercentPeakPercent,2) +
         "% | Protected " +
         DoubleToString(g_profitPercentProtectedPercent,2) +
         "%";

      NotifyTradingPausedReasonOnce(
         "PROFIT_PERCENT_LADDER_LOCK",
         "TRADING PAUSED - PROFIT LADDER LOCKED",
         pauseDetails);
     }

   return(true);
  }

//+------------------------------------------------------------------+
//| Unlimited highest-total-profit 50% share lock                    |
//+------------------------------------------------------------------+
bool CheckHighestProfitShareLock(double currentEquity)
  {
   if(!InpUseDailyProfitLock ||
      !InpUseDailyProfitPercentLadder ||
      !InpUseHighestProfitShareLock)
      return(false);

   if(g_dailyProfitLock)
      return(IsDailyProfitPauseActive());

   double currentPercent =
      GetDailyEquityProfitPercent(currentEquity);

   if(currentPercent > g_profitPercentPeakPercent)
      g_profitPercentPeakPercent = currentPercent;

   double activationPercent =
      MathMax(0.0,GetDailyProfitLadderPercent(1));

   // Before the first exact target there is no profit-share day lock.
   if(g_profitPercentHighestLevel <= 0)
     {
      if(currentPercent+0.0000001 < activationPercent)
        {
         g_profitPercentLadderStatus =
            "READY | NOW " +
            DoubleToString(currentPercent,2) +
            "% | ACTIVATE AT " +
            DoubleToString(activationPercent,2) +
            "% EXACT";
         return(false);
        }

      // First target reached: book existing exposure but do not stop the EA.
      g_profitPercentHighestLevel = 1;
      g_profitPercentLastBookedLevel = 1;
      g_profitPercentLastBookTime = TimeCurrent();
      g_profitPercentProtectedPercent =
         GetHighestProfitShareLockedPercent();
      g_profitPercentProtectedEquity =
         GetDailyProfitLadderEquity(
            g_profitPercentProtectedPercent);
      g_profitPercentLastTrailLogFloor =
         g_profitPercentProtectedPercent;
      g_profitPercentAwaitingNewOrder =
         InpProfitLadderProtectAfterNewOrder;

      g_profitPercentLadderStatus =
         "FIRST " +
         DoubleToString(activationPercent,2) +
         "% BOOKED | WAIT NEW ORDER | PEAK " +
         DoubleToString(g_profitPercentPeakPercent,2) +
         "% | LOCK " +
         DoubleToString(
            MathMax(0.0,
                    MathMin(100.0,
                            InpHighestProfitLockSharePercent)),2) +
         "% OF PEAK PROFIT";

      Print("HIGHEST PROFIT SHARE LOCK ACTIVATED",
            " | Activation=",DoubleToString(activationPercent,2),"%",
            " | CurrentProfit=",DoubleToString(currentPercent,2),"%",
            " | PeakProfit=",DoubleToString(g_profitPercentPeakPercent,2),"%",
            " | LockedProfit=",DoubleToString(g_profitPercentProtectedPercent,2),"%",
            " | LockedEquity=$",DoubleToString(g_profitPercentProtectedEquity,2),
            " | LockShare=",DoubleToString(
               MathMax(0.0,
                       MathMin(100.0,
                               InpHighestProfitLockSharePercent)),2),"%",
            " | Trading continues after booking.");

      if(InpProfitLadderBookAtEachTarget)
         CloseAllEAOrders(
            "FIRST DAILY PROFIT TARGET BOOKED - UNLIMITED SHARE LOCK CONTINUES");

      return(false);
     }

   // Activate protection only when a genuinely new market order opens after
   // the first-target booking. Pending orders alone do not activate the lock.
   if(g_profitPercentAwaitingNewOrder &&
      CountAllOrders() > 0)
     {
      g_profitPercentAwaitingNewOrder = false;
      UpdateHighestDailyProfitShareFloor();

      g_profitPercentLadderStatus =
         "UNLIMITED SHARE LOCK ACTIVE | PEAK " +
         DoubleToString(g_profitPercentPeakPercent,2) +
         "% | LOCKED " +
         DoubleToString(g_profitPercentProtectedPercent,2) +
         "% | CLOSE " +
         DoubleToString(
            GetDailyProfitLadderCloseTriggerPercent(
               g_profitPercentProtectedPercent),2) +
         "% | NOW " +
         DoubleToString(currentPercent,2) + "%";

      Print("UNLIMITED HIGHEST PROFIT SHARE LOCK NEW CYCLE STARTED",
            " | PeakProfit=",DoubleToString(g_profitPercentPeakPercent,2),"%",
            " | LockedProfit=",DoubleToString(g_profitPercentProtectedPercent,2),"%",
            " | LockedEquity=$",DoubleToString(g_profitPercentProtectedEquity,2),
            " | CloseTrigger=",DoubleToString(
               GetDailyProfitLadderCloseTriggerPercent(
                  g_profitPercentProtectedPercent),2),"%",
            " | CurrentProfit=",DoubleToString(currentPercent,2),"%");
     }

   // While waiting for the first post-booking market order, do not lock the day.
   if(g_profitPercentAwaitingNewOrder)
      return(false);

   // Peak and locked share only move upward. There is no upper target.
   UpdateHighestDailyProfitShareFloor();

   double closeThresholdPercent =
      GetDailyProfitLadderCloseTriggerPercent(
         g_profitPercentProtectedPercent);

   g_profitPercentLadderStatus =
      "UNLIMITED SHARE LOCK | PEAK " +
      DoubleToString(g_profitPercentPeakPercent,2) +
      "% | LOCKED " +
      DoubleToString(g_profitPercentProtectedPercent,2) +
      "% | CLOSE " +
      DoubleToString(closeThresholdPercent,2) +
      "% | NOW " +
      DoubleToString(currentPercent,2) + "%";

   if(currentPercent <= closeThresholdPercent+0.0000001)
     {
      return(LockDailyProfitPercentLadder(
         "50% SHARE OF HIGHEST TOTAL DAILY PROFIT HIT" +
         " | PEAK " +
         DoubleToString(g_profitPercentPeakPercent,2) +
         "% | LOCKED " +
         DoubleToString(g_profitPercentProtectedPercent,2) +
         "% | TRIGGER " +
         DoubleToString(closeThresholdPercent,2) + "%",
         currentEquity,
         currentPercent));
     }

   return(false);
  }

//+------------------------------------------------------------------+
bool CheckDailyProfitPercentLadder(double currentEquity)
  {
   if(!InpUseDailyProfitLock ||
      !InpUseDailyProfitPercentLadder)
      return(false);

   if(g_dailyProfitLock)
      return(IsDailyProfitPauseActive());

   if(InpUseHighestProfitShareLock)
      return(CheckHighestProfitShareLock(currentEquity));

   int maxLevel = GetDailyProfitLadderMaxLevel();
   double finalPercent =
      GetDailyProfitLadderPercent(maxLevel);
   double currentPercent =
      GetDailyEquityProfitPercent(currentEquity);

   if(currentPercent > g_profitPercentPeakPercent)
      g_profitPercentPeakPercent = currentPercent;

   // After an intermediate target is booked, the lower floor becomes active
   // only after a genuinely new market order opens.
   if(g_profitPercentAwaitingNewOrder &&
      CountAllOrders() > 0)
     {
      g_profitPercentAwaitingNewOrder = false;

      // Activate the fixed floor and immediately upgrade it from the
      // remembered highest daily profit when the trail is enabled.
      g_profitPercentProtectedPercent =
         MathMax(g_profitPercentProtectedPercent,
                 GetHighestProfitShareLockedPercent());
      g_profitPercentProtectedEquity =
         GetDailyProfitLadderEquity(
            g_profitPercentProtectedPercent);
      g_profitPercentLastTrailLogFloor =
         g_profitPercentProtectedPercent;

      g_profitPercentLadderStatus =
         "L" +
         IntegerToString(g_profitPercentHighestLevel) +
         " NEW ORDER ACTIVE | PEAK " +
         DoubleToString(g_profitPercentPeakPercent,2) +
         "% | FLOOR " +
         DoubleToString(g_profitPercentProtectedPercent,2) +
         "% | CLOSE " +
         DoubleToString(
            GetDailyProfitLadderCloseTriggerPercent(
               g_profitPercentProtectedPercent),2) +
         "% | NEXT " +
         DoubleToString(
            GetDailyProfitLadderPercent(
               MathMin(maxLevel,
                       g_profitPercentHighestLevel+1)),2) +
         "%";

      string newCycleMsg =
         "DAILY PROFIT LADDER NEW CYCLE STARTED" +
         " | BookedLevel=" +
         IntegerToString(g_profitPercentHighestLevel) +
         " | Peak=" +
         DoubleToString(g_profitPercentPeakPercent,2) + "%" +
         " | BaseFloor=" +
         DoubleToString(GetCurrentBookedLadderBaseFloorPercent(),2) + "%" +
         " | ActiveProtected=" +
         DoubleToString(g_profitPercentProtectedPercent,2) + "%" +
         " | CloseTrigger=" +
         DoubleToString(
            GetDailyProfitLadderCloseTriggerPercent(
               g_profitPercentProtectedPercent),2) + "%" +
         " | CurrentEquity=$" +
         DoubleToString(currentEquity,2) +
         " | CurrentPercent=" +
         DoubleToString(currentPercent,2) + "%";

      Print(newCycleMsg);
     }

   int reachedLevel = 0;
   for(int level=1; level<=maxLevel; level++)
     {
      double levelPercent =
         GetDailyProfitLadderPercent(level);
      double armPercent =
         GetDailyProfitLadderArmPercent(level);

      if(levelPercent > 0.0 &&
         currentPercent >= armPercent)
         reachedLevel = level;
     }

   // First visit to each higher intermediate target: book every order, but
   // do not pause the EA. The normal entry engine may start a fresh cycle.
   if(reachedLevel > g_profitPercentHighestLevel)
     {
      g_profitPercentHighestLevel = reachedLevel;

      double fixedProtectedPercent =
         GetDailyProfitLadderProtectedPercent(reachedLevel);
      double trailProtectedPercent =
         GetHighestProfitShareLockedPercent();

      g_profitPercentProtectedPercent =
         MathMax(fixedProtectedPercent,
                 trailProtectedPercent);
      g_profitPercentProtectedEquity =
         GetDailyProfitLadderEquity(
            g_profitPercentProtectedPercent);
      g_profitPercentLastTrailLogFloor =
         g_profitPercentProtectedPercent;

      Print("DAILY PROFIT LADDER TARGET REACHED",
            " | Level=",reachedLevel,"/",maxLevel,
            " | TargetPercent=",
            DoubleToString(
               GetDailyProfitLadderPercent(reachedLevel),2),"%",
            " | CurrentPercent=",
            DoubleToString(currentPercent,2),"%",
            " | PeakPercent=",
            DoubleToString(g_profitPercentPeakPercent,2),"%",
            " | BaseProtectedPercent=",
            DoubleToString(fixedProtectedPercent,2),"%",
            " | EffectiveProtectedPercent=",
            DoubleToString(g_profitPercentProtectedPercent,2),"%",
            " | CurrentEquity=$",
            DoubleToString(currentEquity,2));

      if(reachedLevel >= maxLevel &&
         finalPercent > 0.0 &&
         InpCloseAtFinalProfitLadderLevel)
        {
         g_profitPercentAwaitingNewOrder = false;

         return(LockDailyProfitPercentLadder(
            "FINAL " +
            DoubleToString(finalPercent,2) +
            "% TARGET REACHED",
            currentEquity,
            currentPercent));
        }

      g_profitPercentLastBookedLevel = reachedLevel;
      g_profitPercentLastBookTime = TimeCurrent();
      g_profitPercentAwaitingNewOrder =
         InpProfitLadderProtectAfterNewOrder;

      g_profitPercentLadderStatus =
         "L" + IntegerToString(reachedLevel) +
         " TARGET " +
         DoubleToString(
            GetDailyProfitLadderPercent(reachedLevel),2) +
         "% REACHED | BOOK ORDERS | CONTINUE | NEXT FLOOR " +
         DoubleToString(g_profitPercentProtectedPercent,2) +
         "% | EARLY CLOSE " +
         DoubleToString(
            GetDailyProfitLadderCloseTriggerPercent(
               g_profitPercentProtectedPercent),2) + "%";

      if(InpProfitLadderBookAtEachTarget)
        {
         // This method also deletes pending orders even when no market order
         // is open, ensuring the fresh cycle starts cleanly.
         CloseAllEAOrders(
            "DAILY PROFIT LADDER L" +
            IntegerToString(reachedLevel) +
            " TARGET BOOKED - CONTINUE TRADING");
        }

      Print("DAILY PROFIT LADDER TARGET BOOKED - TRADING CONTINUES",
            " | Level=",reachedLevel,
            " | Target=",
            DoubleToString(
               GetDailyProfitLadderPercent(reachedLevel),2),"%",
            " | Protection activates ",
            InpProfitLadderProtectAfterNewOrder
            ? "after the next market order opens"
            : "immediately",
            " | ProtectedFloor=",
            DoubleToString(g_profitPercentProtectedPercent,2),"%",
            " | EarlyCloseTrigger=",
            DoubleToString(
               GetDailyProfitLadderCloseTriggerPercent(
                  g_profitPercentProtectedPercent),2),"%",
            " | NextTarget=",
            DoubleToString(
               GetDailyProfitLadderPercent(
                  MathMin(maxLevel,reachedLevel+1)),2),"%");

      // Not a day lock. Keep the EA active.
      return(false);
     }

   // No floor check while waiting for the first new market order after a
   // target booking. With no market exposure there is no reason to end the day.
   if(g_profitPercentHighestLevel > 0 &&
      !g_profitPercentAwaitingNewOrder)
     {
      // Remembered peak and protected floor only move upward.
      UpdateHighestDailyProfitShareFloor();

      double closeThresholdPercent =
         GetDailyProfitLadderCloseTriggerPercent(
            g_profitPercentProtectedPercent);

      if(currentPercent <
         closeThresholdPercent-0.0000001)
        {
         return(LockDailyProfitPercentLadder(
            "HIGHEST PROFIT TRAIL PULLBACK BELOW " +
            DoubleToString(closeThresholdPercent,2) +
            "% | PEAK " +
            DoubleToString(g_profitPercentPeakPercent,2) +
            "% | PROTECTED " +
            DoubleToString(
               g_profitPercentProtectedPercent,2) +
            "%",
            currentEquity,
            currentPercent));
        }
     }

   return(false);
  }

//+------------------------------------------------------------------+
void InitializeEquityDay()
  {
   g_equityDateKey           = GetCurrentFreshDayDateKey();
   g_freshDayDateKey         = g_equityDateKey;
   g_freshDayStartServerTime = GetCurrentFreshDayStartServerTime();
   g_freshDayHistoryCutoffTime = LoadFreshDayHistoryCutoff();

   // The strict 23:45 GMT0 shutdown guarantees the new day is flat before these
   // values are captured.
   g_dayStartBalance = AccountBalance();
   g_dayStartEquity  = AccountEquity();

   // Unified tester/live behaviour: use the actual new-day opening balance
   // for dynamic lot, scaled money settings and equity-cycle calculations.
   g_testerInitialReferenceBalance = 0.0; // legacy value is intentionally unused
   g_baseBalance = GetFreshDayStrategyReferenceBalance();

   if(g_baseBalance <= 0.0)
      g_baseBalance = MathMax(0.01,g_dayStartBalance);

   g_equityCycleAnchor = g_baseBalance;

   if(g_equityCycleAnchor <= 0.0)
      g_equityCycleAnchor = MathMax(0.01,g_dayStartEquity);

   double configuredFinalProfitPercent =
      InpUseDailyProfitPercentLadder
      ? GetDailyProfitLadderArmPercent(
           GetDailyProfitLadderMaxLevel())
      : MathMax(0.0,InpProfitTargetPercent);

   g_dailyProfitTarget =
      g_baseBalance * configuredFinalProfitPercent / 100.0;

   g_profitTargetEquity =
      g_equityCycleAnchor + g_dailyProfitTarget;

   g_profitLadderLevel1Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(1) / 100.0);
   g_profitLadderLevel2Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(2) / 100.0);
   g_profitLadderLevel3Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(3) / 100.0);
   g_profitLadderLevel4Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(4) / 100.0);
   g_profitLadderLevel5Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(5) / 100.0);
   g_profitLadderLevel6Equity =
      g_equityCycleAnchor +
      (g_baseBalance *
       GetDailyProfitLadderArmPercent(6) / 100.0);

   double dailyLossAmount =
      g_baseBalance * InpLossStopPercent / 100.0;

   g_lossStopEquityLevel =
      g_equityCycleAnchor - dailyLossAmount - InpProtectionBufferUSD;

   if(g_lossStopEquityLevel < 0.0)
      g_lossStopEquityLevel = 0.0;

   double halfLossTriggerShare =
      MathMax(0.0,MathMin(100.0,InpHalfLossPauseTriggerPercent)) / 100.0;

   g_halfLossPauseEquityLevel =
      g_equityCycleAnchor - (dailyLossAmount * halfLossTriggerShare);

   if(g_halfLossPauseEquityLevel < g_lossStopEquityLevel)
      g_halfLossPauseEquityLevel = g_lossStopEquityLevel;

   g_halfLossPauseUntil     = 0;
   g_halfLossPauseTriggered = false;
   g_halfLossPauseStatus    = InpUseHalfLossPause
                              ? "READY | WAIT HALF LOSS"
                              : "OFF";

   g_profitPercentHighestLevel = 0;
   g_profitPercentProtectedPercent = 0.0;
   g_profitPercentProtectedEquity = 0.0;
   g_profitPercentPeakPercent = 0.0;
   g_profitPercentLastTrailLogFloor = 0.0;
   g_profitPercentLadderHit = false;
   g_profitPercentAwaitingNewOrder = false;
   g_profitPercentLastBookedLevel = 0;
   g_profitPercentLastBookTime = 0;
   g_profitPercentLadderStatus =
      InpUseDailyProfitPercentLadder
      ? (InpUseHighestProfitShareLock
         ? "READY | WAIT EXACT 10% SHARE-LOCK ACTIVATION"
         : "READY | WAIT LEVEL 1")
      : "OFF | LEGACY FIXED TARGET";

   g_buySideLossStreak = 0;
   g_sellSideLossStreak = 0;
   g_buySideLossPauseUntil = 0;
   g_sellSideLossPauseUntil = 0;
   g_buySideLossPauseTriggerTicket = 0;
   g_sellSideLossPauseTriggerTicket = 0;
   g_buySideLossPauseTriggerCloseTime = 0;
   g_sellSideLossPauseTriggerCloseTime = 0;
   g_buySideLossPauseTriggerSARDirection = 0;
   g_sellSideLossPauseTriggerSARDirection = 0;
   g_buySideLossPauseStatus = "READY";
   g_sellSideLossPauseStatus = "READY";
   g_sideLossPauseLastScanTime = 0;

   g_lockedProfitToday    = 0.0;
   g_dailyProfitLock      = false;
   g_equityProtectionHit  = false;
   g_notifyProfitLockSent = false;
   g_notifyEquityStopSent = false;
   g_lastEquityStatsResetTime = TimeCurrent();
   g_lastEquityResetSlot = GetEquityResetSlot(TimeCurrent());

   if(InpResetTradingCycleWithEquity)
      ResetTradingCycleState();

   string equityResetMsg =
   "EQUITY STATS INIT/RESET | Cycle=" + IntegerToString(g_equityCycleNumber) +
   " | ResetTime=" + TimeToString(g_lastEquityStatsResetTime,TIME_DATE|TIME_SECONDS) +
   " | ActualStartBalance=$" + DoubleToString(g_dayStartBalance,2) +
   " | ActualStartEquity=$" + DoubleToString(g_dayStartEquity,2) +
   " | StrategyReference=$" + DoubleToString(g_baseBalance,2) +
   " | EquityAnchor=$" + DoubleToString(g_equityCycleAnchor,2) +
   " | LossStopEquity=$" + DoubleToString(g_lossStopEquityLevel,2) +
   " | HalfLossPauseEquity=$" + DoubleToString(g_halfLossPauseEquityLevel,2) +
   " | HalfLossPauseMinutes=" + IntegerToString(InpHalfLossPauseMinutes) +
   " | ProfitMode=" + (InpUseDailyProfitPercentLadder ? "LADDER" : "FIXED") +
   " | HighestProfitShareLock=" +
   (InpUseHighestProfitShareLock ? "ON" : "OFF") +
   " | PeakProfitLockShare=" +
   DoubleToString(InpHighestProfitLockSharePercent,2) + "%" +
   " | FloorCloseBuffer=" +
   DoubleToString(InpProfitLadderFloorCloseBufferPercent,2) + "%" +
   " | ProfitL1=" + DoubleToString(GetDailyProfitLadderPercent(1),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(1),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(1),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel1Equity,2) +
   " | ProfitL2=" + DoubleToString(GetDailyProfitLadderPercent(2),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(2),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(2),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel2Equity,2) +
   " | ProfitL3=" + DoubleToString(GetDailyProfitLadderPercent(3),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(3),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(3),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel3Equity,2) +
   " | ProfitL4=" + DoubleToString(GetDailyProfitLadderPercent(4),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(4),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(4),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel4Equity,2) +
   " | ProfitL5=" + DoubleToString(GetDailyProfitLadderPercent(5),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(5),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(5),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel5Equity,2) +
   " | ProfitL6=" + DoubleToString(GetDailyProfitLadderPercent(6),2) + "%" +
   " Arm=" + DoubleToString(GetDailyProfitLadderArmPercent(6),2) + "%" +
   " Protect=" + DoubleToString(GetDailyProfitLadderProtectedPercent(6),2) + "%" +
   " @ $" + DoubleToString(g_profitLadderLevel6Equity,2) +
   " | ProfitTargetEquity=$" + DoubleToString(g_profitTargetEquity,2) +
   " | TargetProfit=$" + DoubleToString(g_dailyProfitTarget,2) +
   " | DailyBalanceMode=ACTUAL NEW-DAY BALANCE";

Print(equityResetMsg);
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
   g_lastSARFlipV2LastOrderTime    = 0;
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
   g_goodMarketContinuationPending = false;
   g_goodMarketContinuationDirection = 0;
   g_goodMarketContinuationSourceTicket = 0;
   g_goodMarketContinuationSourceProfit = 0.0;
   g_goodMarketContinuationClosePrice = 0.0;
   g_goodMarketContinuationCloseTime = 0;
   g_goodMarketContinuationLastAttemptTime = 0;
   g_goodMarketContinuationStatus = "WAIT FIRST PROFIT";
   g_oppositeImpulseRequestPending = false;
   g_oppositeImpulseDirection = 0;
   g_oppositeImpulseSourceDirection = 0;
   g_oppositeImpulseSourceLoss = 0.0;
   g_oppositeImpulseSignalBarTime = 0;
   g_oppositeImpulseQueuedTime = 0;
   g_oppositeImpulseLastAttemptTime = 0;
   g_oppositeImpulseSignalHigh = 0.0;
   g_oppositeImpulseSignalLow = 0.0;
   g_oppositeImpulseSignalRange = 0.0;
   g_oppositeImpulsePreviousRange = 0.0;
   g_oppositeImpulseAverageRange = 0.0;
   g_oppositeImpulseBodyPercent = 0.0;
   g_oppositeImpulseExitWickPercent = 0.0;
   g_oppositeImpulsePendingTicket = -1;
   g_oppositeImpulsePreSAROverride = false;
   g_oppositeImpulseStatus = "WAIT IMPULSE";
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

   // Do not restore an old pending request here. Startup/fresh-day code
   // performs restoration only after the final magic number and strict history
   // cutoff are known.
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
bool IsConfiguredNoNewOrderHourInList(int hourValue,string configuredHours)
  {
   StringReplace(configuredHours," ","");

   if(StringLen(configuredHours) <= 0)
      return(false);

   string parts[];
   int total = StringSplit(configuredHours,',',parts);

   if(total <= 0)
      return(false);

   for(int i=0; i<total; i++)
     {
      string value = parts[i];
      StringReplace(value," ","");

      if(StringLen(value) <= 0)
         continue;

      int h = (int)StrToInteger(value);
      if(h < 0 || h > 23)
         continue;

      if(h == hourValue)
         return(true);
     }

   return(false);
  }

//+------------------------------------------------------------------+
string GetActiveNoNewOrderHourList()
  {
   return(InpNoNewOrderHourList);
  }

//+------------------------------------------------------------------+
//| Canonical GMT0 / UTC reference clock.                            |
//| LIVE: TimeGMT() ignores broker-server and VPS timezone.           |
//| TESTER: TimeCurrent() minus InpTesterServerGMTOffsetHours.       |
//+------------------------------------------------------------------+
datetime GetGMT0Time()
  {
   if(IsTesting())
      return(TimeCurrent() - (InpTesterServerGMTOffsetHours * 3600));

   return(TimeGMT());
  }

//+------------------------------------------------------------------+
datetime GetActiveNoNewOrderClock()
  {
   return(GetGMT0Time());
  }

//+------------------------------------------------------------------+
string GetActiveNoNewOrderClockLabel()
  {
   return("GMT0");
  }

//+------------------------------------------------------------------+
bool IsConfiguredNoNewOrderHour(int hourValue)
  {
   return(IsConfiguredNoNewOrderHourInList(hourValue,
                                           GetActiveNoNewOrderHourList()));
  }

//+------------------------------------------------------------------+
//| Backward-compatible name kept so the rest of the EA compiles.     |
//| This now returns GMT0/UTC time, not Dubai time.                  |
//+------------------------------------------------------------------+
datetime GetDubaiTime()
  {
   return(GetGMT0Time());
  }


//+------------------------------------------------------------------+
//| Complete date key used by the fresh-day and equity-cycle logic.  |
//+------------------------------------------------------------------+
int GetDateKeyFromTime(datetime value)
  {
   return(TimeYear(value) * 10000 +
          TimeMonth(value) * 100 +
          TimeDay(value));
  }

//+------------------------------------------------------------------+
//| Fresh-day reference now uses GMT0 in both live and tester modes.  |
//+------------------------------------------------------------------+
datetime GetFreshDayReferenceTime()
  {
   return(GetGMT0Time());
  }

//+------------------------------------------------------------------+
int GetCurrentFreshDayDateKey()
  {
   return(GetDateKeyFromTime(GetFreshDayReferenceTime()));
  }

//+------------------------------------------------------------------+
string GetFreshDayCutoffTimeGlobalKey()
  {
   return("DXB_FRESH_CUTOFF_TIME_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
string GetFreshDayCutoffDateGlobalKey()
  {
   return("DXB_FRESH_CUTOFF_DATE_" +
          IntegerToString(AccountNumber()) + "_" +
          Symbol() + "_" +
          IntegerToString(Period()) + "_" +
          IntegerToString(InpMagicNumber));
  }

//+------------------------------------------------------------------+
void SaveFreshDayHistoryCutoff(datetime cutoffTime,int dateKey)
  {
   g_freshDayHistoryCutoffTime = cutoffTime;

   // Keep Strategy Tester runs isolated from terminal Global Variables.
   // The in-memory cutoff survives the internal day reset, while a new tester
   // run starts with the normal day-start cutoff exactly like a fresh attach.
   if(IsTesting())
      return;

   GlobalVariableSet(GetFreshDayCutoffTimeGlobalKey(),(double)cutoffTime);
   GlobalVariableSet(GetFreshDayCutoffDateGlobalKey(),(double)dateKey);
   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
datetime LoadFreshDayHistoryCutoff()
  {
   datetime defaultCutoff = GetCurrentFreshDayStartServerTime();

   if(!InpUseFreshDayStart || !InpFreshDayIgnorePreviousTradeHistory)
      return(defaultCutoff);

   int currentDate = GetCurrentFreshDayDateKey();

   if(IsTesting())
     {
      if(g_freshDayDateKey == currentDate &&
         g_freshDayHistoryCutoffTime >= defaultCutoff)
         return(g_freshDayHistoryCutoffTime);

      return(defaultCutoff);
     }

   string timeKey = GetFreshDayCutoffTimeGlobalKey();
   string dateKey = GetFreshDayCutoffDateGlobalKey();

   if(GlobalVariableCheck(timeKey) && GlobalVariableCheck(dateKey) &&
      (int)GlobalVariableGet(dateKey) == currentDate)
     {
      datetime stored = (datetime)GlobalVariableGet(timeKey);
      if(stored >= defaultCutoff)
         return(stored);
     }

   return(defaultCutoff);
  }

//+------------------------------------------------------------------+
//| Start of the current fresh day expressed in broker/server time.  |
//| This allows order-history filters to ignore yesterday's trades.  |
//+------------------------------------------------------------------+
datetime GetCurrentFreshDayStartServerTime()
  {
   datetime gmt0Now = GetGMT0Time();
   datetime gmt0Start = gmt0Now -
                        TimeHour(gmt0Now) * 3600 -
                        TimeMinute(gmt0Now) * 60 -
                        TimeSeconds(gmt0Now);

   int serverUtcOffset = IsTesting()
                         ? InpTesterServerGMTOffsetHours * 3600
                         : (int)(TimeCurrent() - TimeGMT());

   return(gmt0Start + serverUtcOffset);
  }

//+------------------------------------------------------------------+
bool IsHistoryTimeInsideCurrentFreshDay(datetime historyTime)
  {
   if(!InpUseFreshDayStart ||
      !InpFreshDayIgnorePreviousTradeHistory)
      return(true);

   datetime cutoff = g_freshDayHistoryCutoffTime;
   if(cutoff <= 0)
      cutoff = g_freshDayStartServerTime;

   if(cutoff <= 0)
      return(true);

   return(historyTime >= cutoff);
  }

//+------------------------------------------------------------------+
//| Close every EA market order, including a legacy guard order.     |
//| Returns the number of market orders still open after the attempt.|
//+------------------------------------------------------------------+
int CloseAllEAMarketOrdersForFreshDay(string reason)
  {
   RefreshRates();

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

      int ticket = OrderTicket();
      double lots = OrderLots();
      double closePrice = (type == OP_BUY) ? Bid : Ask;
      double closeProfit = OrderProfit() + OrderSwap() + OrderCommission();

      ResetLastError();
      if(OrderClose(ticket, lots, closePrice, InpSlippage, clrWhite))
        {
         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(ticket,
                                    type,
                                    closeProfit,
                                    closePrice,
                                    reason);

         Print("FRESH DAY MARKET ORDER CLOSED | Ticket=",ticket,
               " | Type=",type,
               " | P/L=$",DoubleToString(closeProfit,2),
               " | Reason=",reason);
        }
      else
        {
         int err = GetLastError();
         Print("FRESH DAY MARKET CLOSE FAILED | Ticket=",ticket,
               " | Error=",err,
               " | Reason=",reason);
         ResetLastError();
        }
     }

   int remaining = 0;
   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == InpMagicNumber &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
         remaining++;
     }

   return(remaining);
  }

//+------------------------------------------------------------------+
//| Clear all strategy/runtime memory that may carry across a day.   |
//+------------------------------------------------------------------+
void ResetAllFreshDayRuntimeState()
  {
   ResetTradingCycleState();
   ResetBasketProfitPeaksAfterClose(0);
   ResetRecoveryLossComebackState(1);
   ResetRecoveryLossComebackState(-1);
   ResetLiveOppositeCandleEmergencySLState(1);
   ResetLiveOppositeCandleEmergencySLState(-1);

   g_marketMode = MODE_RANGE;
   g_equityCycleAnchor = 0.0;
   g_halfLossPauseEquityLevel = 0.0;
   g_halfLossPauseUntil       = 0;
   g_halfLossPauseTriggered   = false;
   g_halfLossPauseStatus      = "READY";
   g_profitLadderLevel1Equity = 0.0;
   g_profitLadderLevel2Equity = 0.0;
   g_profitLadderLevel3Equity = 0.0;
   g_profitLadderLevel4Equity = 0.0;
   g_profitLadderLevel5Equity = 0.0;
   g_profitLadderLevel6Equity = 0.0;
   g_profitPercentHighestLevel = 0;
   g_profitPercentProtectedPercent = 0.0;
   g_profitPercentProtectedEquity = 0.0;
   g_profitPercentPeakPercent = 0.0;
   g_profitPercentLastTrailLogFloor = 0.0;
   g_profitPercentLadderHit = false;
   g_profitPercentAwaitingNewOrder = false;
   g_profitPercentLastBookedLevel = 0;
   g_profitPercentLastBookTime = 0;
   g_profitPercentLadderStatus = "READY";
   g_buySideLossStreak = 0;
   g_sellSideLossStreak = 0;
   g_buySideLossPauseUntil = 0;
   g_sellSideLossPauseUntil = 0;
   g_buySideLossPauseTriggerTicket = 0;
   g_sellSideLossPauseTriggerTicket = 0;
   g_buySideLossPauseTriggerCloseTime = 0;
   g_sellSideLossPauseTriggerCloseTime = 0;
   g_buySideLossPauseTriggerSARDirection = 0;
   g_sellSideLossPauseTriggerSARDirection = 0;
   g_buySideLossPauseStatus = "READY";
   g_sellSideLossPauseStatus = "READY";
   g_sideLossPauseLastScanTime = 0;
   ArrayInitialize(g_sarChangeTimes,0);
   ArrayInitialize(g_sarChangeDirections,0);
   ArrayInitialize(g_sarChangeDurationsSeconds,0);
   g_lastBarTime = 0;
   g_lastInitialServerSLScanTime = 0;
   g_lastActivatedPendingMarketTicket = -1;
   g_lastSARFlipV2LastOrderTime = 0;
   g_lastEarlyArrowTime = 0;
   g_lastSARArrowTime = 0;
   g_lastSAREveryBarTime = 0;
   g_lastFlatDotTime = 0;
   g_lastEarlySameSAROrderBarTime = 0;

   g_autoMarketMode = DXB_MARKET_MODE_OFF;
   g_autoMarketModeText = "OFF";
   g_autoMarketMoveRaw = 0.0;
   g_autoMarketLast3MoveRaw = 0.0;
   g_autoMarketBuyProfitCount = 0;
   g_autoMarketSellProfitCount = 0;
   g_autoMarketDirection = 0;

   g_sarGoodMomentum = false;
   g_sarGoodMomentumDotDistance = 0.0;
   g_sarGoodMomentumADX = 0.0;
   g_sarGoodMomentumATR = 0.0;
   g_dynamicSARScore = 0;
   g_dynamicSARDecision = "WAIT";
   g_dynamicSARRequiredDiff = 0.0;
   g_dynamicSARDotDistance = 0.0;
   g_dynamicSARATR = 0.0;
   g_dynamicSARADX = 0.0;
   g_dynamicSARLongBarMove = 0.0;

   g_earlySARWeakExitActive = false;
   g_earlySARWeakExitReason = "";
   g_activeBasketPeakProfit = 0.0;
   g_dynamicBasketProfitStatus = "WAIT BASKET";
   g_lastEarlySARWeakExitTime = 0;
   g_lastEarlySARWeakExitDirection = 0;

   g_sarContinuationStatus = "WAIT SAR ADD-ON";
   g_lastSARContinuationBuyBarTime = 0;
   g_lastSARContinuationSellBarTime = 0;
   g_buySARContinuationExtreme = 0.0;
   g_sellSARContinuationExtreme = 0.0;
   g_buyPullbackContinuationArmed = false;
   g_sellPullbackContinuationArmed = false;
   g_buyPullbackContinuationArmBarTime = 0;
   g_sellPullbackContinuationArmBarTime = 0;
   g_buyPullbackContinuationRaw = 0.0;
   g_sellPullbackContinuationRaw = 0.0;

   g_lastRecoveryAudit = "NONE";
   g_lastRecoveryAuditTime = 0;
   g_lastRecoveryAuditDirection = 0;
   g_lastRecoveryAuditGap = 0.0;
   ArrayInitialize(g_recoveryChainProcessedTickets,0);
   g_recoveryChainProcessedCount = 0;
   g_recoveryChainTrackerInitialized = false;
   g_recoveryChainContinuationPending = false;
   g_recoveryChainPendingDirection = 0;
   g_recoveryChainSourceTicket = 0;
   g_recoveryChainSourceProfit = 0.0;
   g_recoveryChainSourceCloseTime = 0;
   g_recoveryChainLastOpenAttemptTime = 0;

   g_oppositeProfitStreakDirection = 0;
   g_oppositeProfitStreakCount = 0;
   g_oppositePausedDirection = 0;
   g_oppositeDirectionPauseUntil = 0;
   g_oppositeDirectionPauseTriggerTime = 0;
   g_oppositeDirectionPauseTriggerTicket = 0;
   g_oppositeDirectionPauseWinner = 0;
   g_oppositePauseLastHistoryTotal = -1;
   g_oppositePauseLastScanTime = 0;
   g_oppositePauseLastBlockPrintTime = 0;
   g_oppositePauseLastPrintedDirection = 0;
   g_oppositeDirectionPauseStatus = "FRESH DAY | WAIT STREAK";

   if(InpFreshDayResetPersistentLocks)
     {
      g_consecutiveBasketSLCount = 0;
      g_consecutiveBasketSLPauseUntil = 0;
      g_lastConsecutiveSLRegisterTime = 0;
      g_lastConsecutiveSLRegisterDirection = 0;
      g_consecutiveSLPauseStatus = "READY | FRESH DAY";

      DeleteFreshDayEAStateGlobalVariables();
     }

   g_globalEquityPeak = AccountEquity();
   g_globalEquityTrailPauseUntil = 0;
   g_globalEquityTrailLocked = false;
   g_globalEquityTrailStatus = "OFF | FRESH DAY";
   g_profitProtectPauseUntil = 0;
   g_profitProtectCount = 0;
   ArrayInitialize(g_profitProtectTickets,0);
   ArrayInitialize(g_profitProtectPeakProfit,0.0);

   g_tickSpeedWindowStartMs = 0;
   g_tickSpeedLastTickMs = 0;
   g_tickSpeedWindowStartPrice = 0.0;
   g_tickSpeedWindowMinPrice = 0.0;
   g_tickSpeedWindowMaxPrice = 0.0;
   g_tickSpeedWindowLastPrice = 0.0;
   g_tickSpeedWindowPath = 0.0;
   g_tickSpeedWindowTicks = 0;
   g_tickSpeedCompletedWindows = 0;
   g_tickSpeedLastWindowNetMove = 0.0;
   g_tickSpeedLastWindowRange = 0.0;
   g_tickSpeedLastWindowPath = 0.0;
   g_tickSpeedLastWindowTickRate = 0.0;
   g_tickSpeedBaselineTickRate = 0.0;
   g_tickSpeedAvgCandleRange = 0.0;
   g_tickSpeedCurrentCandleRange = 0.0;
   g_tickSpeedCandleRatio = 0.0;
   g_tickSpeedRecentNetMove = 0.0;
   g_tickSpeedRecentRange = 0.0;
   g_tickSpeedRecentPath = 0.0;
   g_tickSpeedWindowMoveRatio = 0.0;
   g_tickSpeedWindowPathRatio = 0.0;
   g_tickSpeedCurrentTickRate = 0.0;
   g_tickSpeedTickRateRatio = 1.0;
   g_tickSpeedCandleElapsedSec = 0;
   g_tickSpeedStatus = "WARMING UP";

   g_buyTickSpeedLockedSL = 0.0;
   g_sellTickSpeedLockedSL = 0.0;
   g_buyTickSpeedLockedBaseSL = 0.0;
   g_sellTickSpeedLockedBaseSL = 0.0;
   g_buyTickSpeedLockedStatus = "WAIT ORDER";
   g_sellTickSpeedLockedStatus = "WAIT ORDER";
   g_buyTickSpeedLockedMode = "WAIT MODE";
   g_sellTickSpeedLockedMode = "WAIT MODE";
   g_buyTickSpeedSLActivatedTime = 0;
   g_sellTickSpeedSLActivatedTime = 0;

   g_buyLiveOppositeCandleSLArmed = false;
   g_sellLiveOppositeCandleSLArmed = false;
   g_buyLiveOppositeCandleSLUSD = 0.0;
   g_sellLiveOppositeCandleSLUSD = 0.0;
   g_buyLiveOppositeCandleArmTime = 0;
   g_sellLiveOppositeCandleArmTime = 0;
   g_liveOppositeCurrentM1Range = 0.0;
   g_liveOppositePreviousM1Range = 0.0;
   g_liveOppositeM1RangeRatio = 0.0;
   g_liveOppositeCurrentBodyPercent = 0.0;
   g_liveOppositeCurrentDirection = 0;

   g_onInitTickCount = GetTickCount();
   g_tickConfirmationCount = 0;
   g_compactDashboardLegacyCleared = false;

   ResetEntryDiagnosticSnapshot(0,"FRESH DAY START");
   g_lastEntryAttemptTime = 0;
   g_lastEntryAttemptDirection = 0;
   g_lastEntryAttemptSource = "NONE";
   g_lastEntryAttemptDecision = "NONE";
   g_lastEntryAttemptPrimary = "NONE";
   g_lastEntryAttemptBlockers = "NONE";
   g_lastEntryAttemptEnabled = 0;
   g_lastEntryAttemptPassed = 0;
   g_lastEntryAttemptBlocked = 0;
   g_lastAuditOpenedTicket = -1;
   g_lastAuditOpenedTime = 0;
   g_lastAuditOpenedDirection = 0;
   g_lastAuditOpenedPrice = 0.0;
   g_lastAuditOpenedLot = 0.0;
   g_lastAuditOpenedSource = "NONE";
   g_lastAuditOpenedMode = "NONE";
   g_lastAuditOpenedProfile = "NONE";
   g_lastAuditOpenedFilters = "NONE";
   g_lastAuditDisabledFilters = "NONE";
   g_lastAuditOpenedEnabled = 0;
   g_lastAuditOpenedPassed = 0;
   g_lastAuditSendResult = "NO ORDER ATTEMPT";

  }

//+------------------------------------------------------------------+
bool IsFreshDayInternalResumeHoldActive()
  {
   if(g_freshDayInternalResumeAfter <= 0)
      return(false);

   bool timeReady = (TimeCurrent() >= g_freshDayInternalResumeAfter);
   datetime currentBar = iTime(Symbol(),PERIOD_M1,0);
   bool barReady = (!InpFreshDayResumeOnlyOnNewM1Bar ||
                    (currentBar > 0 &&
                     currentBar != g_freshDayInternalResumeBarTime));

   if(timeReady && barReady)
     {
      g_freshDayInternalResumeAfter = 0;
      g_freshDayInternalResumeBarTime = 0;
      g_freshDayStatus = "STRICT FRESH RUN ACTIVE | " +
                         IntegerToString(GetCurrentFreshDayDateKey());
      return(false);
     }

   int left = (int)MathMax(0,g_freshDayInternalResumeAfter-TimeCurrent());
   g_freshDayStatus = "FRESH BOOT WAIT " + IntegerToString(left) + "s" +
                      (barReady ? " | BAR READY" : " | WAIT NEW M1");
   return(true);
  }

//+------------------------------------------------------------------+
//| Run before every other OnTick operation.                         |
//+------------------------------------------------------------------+
bool HandleFreshDayStart()
  {
   if(!InpUseFreshDayStart)
      return(true);

   int currentDateKey = GetCurrentFreshDayDateKey();

   if(g_freshDayDateKey <= 0)
     {
      g_freshDayDateKey = currentDateKey;
      g_equityDateKey = currentDateKey;
      g_freshDayStartServerTime = GetCurrentFreshDayStartServerTime();
      g_freshDayHistoryCutoffTime = LoadFreshDayHistoryCutoff();
      g_freshDayStatus = "READY | " + IntegerToString(currentDateKey);
      return(true);
     }

   if(currentDateKey == g_freshDayDateKey &&
      !g_freshDayResetInProgress)
      return(true);

   g_freshDayResetInProgress = true;
   g_freshDayStatus = "RESETTING NEW DAY " + IntegerToString(currentDateKey);

   string reason = "FRESH DAY START " + IntegerToString(currentDateKey);

   if(InpFreshDayDeletePendingOrders)
      DeletePendingOrdersByDirection(0,reason,false);

   int marketRemaining = 0;
   if(InpFreshDayCloseMarketOrders)
      marketRemaining = CloseAllEAMarketOrdersForFreshDay(reason);
   else
      marketRemaining = CountOpenOrders();

   if(marketRemaining > 0)
     {
      g_freshDayStatus = "WAIT CLOSE | " +
                         IntegerToString(marketRemaining) +
                         " MARKET ORDER(S)";

      SetLastOrderBlockDashboard(g_freshDayStatus);
      return(false);
     }

   // A second pending deletion catches anything created/activated while the
   // market-close loop was being processed.
   if(InpFreshDayDeletePendingOrders)
      DeletePendingOrdersByDirection(0,reason + " | FINAL",false);

   // Establish the new date and strict history cutoff BEFORE rebuilding any
   // startup tracker. Forced day-boundary closes are therefore invisible to
   // the new day's strategy logic.
   g_freshDayDateKey = currentDateKey;
   g_equityDateKey = currentDateKey;
   g_freshDayStartServerTime = GetCurrentFreshDayStartServerTime();

   // The 23:45 GMT0 shutdown already closed the old-day orders. Keep the new
   // history cutoff exactly at 00:00 so the first new-day tick/bar is not
   // skipped. This matches a standalone test that begins on this date.
   datetime strictCutoff = g_freshDayStartServerTime;

   SaveFreshDayHistoryCutoff(strictCutoff,currentDateKey);
   DeleteFreshDayEAStateGlobalVariables();

   ResetAllFreshDayRuntimeState();

   // A standalone test begins with equity cycle #1. Recreate that same
   // day-start state instead of carrying yesterday's cycle number.
   g_equityCycleNumber = 1;
   InitializeEquityDay();

   // Re-run the same strategy startup trackers used by OnInit(), but now with
   // today's strict cutoff and a flat order book.
   InitializeLastDepositBalanceOpTime();
   DeleteNonEarlySignalArrows();
   DeleteOldDashboardObjects();
   LoadLast5SARChangeDurations();
   RestoreOppositeImpulsePendingState();
   InitializeCreatedClosedPushTracker();
   InitializeSLReverseRecoveryChainTracker();
   UpdateOppositeDirectionProfitPause(true);

   g_freshDayInternalResumeAfter =
      TimeCurrent() + MathMax(0,InpFreshDayInternalResumeDelaySeconds);
   g_freshDayInternalResumeBarTime = iTime(Symbol(),PERIOD_M1,0);

   g_freshDayResetInProgress = false;
   g_freshDayStatus = "STRICT FRESH RUN READY | " + IntegerToString(currentDateKey);

   Print("FRESH DAY COMPLETE | DateKey=",currentDateKey,
         " | StrategyReference=$",DoubleToString(g_baseBalance,2),
         " | EquityAnchor=$",DoubleToString(g_equityCycleAnchor,2),
         " | DynamicLot=",DoubleToString(GetCurrentTradingLot(),2),
         " | ProfitTarget=$",DoubleToString(g_profitTargetEquity,2),
         " | LossLimit=$",DoubleToString(g_lossStopEquityLevel,2),
         " | PendingGap=",DoubleToString(GetConfiguredPendingOrderGapRaw(),1),
         " | HistoryCutoff=",
         TimeToString(g_freshDayHistoryCutoffTime,TIME_DATE|TIME_SECONDS));

   return(true);
  }

//+------------------------------------------------------------------+
bool IsDubaiNoNewOrderHourNow()
  {
   if(!InpUseNoNewOrderHours)
      return(false);

   if(IsTesting() && !InpApplyNoNewOrderHoursInTesting)
      return(false);

   string configuredHours = GetActiveNoNewOrderHourList();
   StringReplace(configuredHours," ","");

   if(StringLen(configuredHours) <= 0)
      return(false);

   int activeHour = TimeHour(GetActiveNoNewOrderClock());
   return(IsConfiguredNoNewOrderHourInList(activeHour,configuredHours));
  }

//+------------------------------------------------------------------+
// Backward-compatible name used throughout the EA. This is a hard
// no-new-order lock using GMT0/UTC in every environment.
bool IsNoNewOrderHour()
  {
   return(IsNewOrderHardPauseActive());
  }

//+------------------------------------------------------------------+
string NoNewOrderHoursStatusText()
  {
   if(!InpUseNoNewOrderHours)
      return("OFF");

   if(IsTesting() && !InpApplyNoNewOrderHoursInTesting)
      return("TEST MODE | DISABLED");

   datetime activeClock = GetActiveNoNewOrderClock();
   string activeLabel = GetActiveNoNewOrderClockLabel();
   int activeHour = TimeHour(activeClock);
   string activeHours = GetActiveNoNewOrderHourList();

   string status =
      IsDubaiNoNewOrderHourNow()
      ? "BLOCK NOW"
      : "ALLOW";

   return(status +
          " | " + activeLabel + "=" +
          TimeToString(activeClock,TIME_MINUTES) +
          " | HOUR=" + IntegerToString(activeHour) +
          " | HOURS=" + activeHours);
  }


//+------------------------------------------------------------------+
string ConsecutiveSLStateKey(string field)
  {
   return("DXB_SL_STREAK_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          Symbol() + "_" + field);
  }

//+------------------------------------------------------------------+
void DeleteFreshDayEAStateGlobalVariables()
  {
   if(!InpFreshDayDeleteEAStateGlobals || IsTesting())
      return;

   string countKey = ConsecutiveSLStateKey("COUNT");
   string untilKey = ConsecutiveSLStateKey("UNTIL");

   if(GlobalVariableCheck(countKey))
      GlobalVariableDel(countKey);
   if(GlobalVariableCheck(untilKey))
      GlobalVariableDel(untilKey);

   // Legacy guard-parent mappings are useless after the fresh-day routine
   // has made this EA flat. Delete only this symbol/magic prefix.
   string guardPrefix = "SAR_GUARD_PARENT_" + Symbol() + "_" +
                        IntegerToString(InpMagicNumber) + "_";

   for(int i=GlobalVariablesTotal()-1; i>=0; i--)
     {
      string name = GlobalVariableName(i);
      if(StringFind(name,guardPrefix,0) == 0)
         GlobalVariableDel(name);
     }

   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
void SaveConsecutiveSLPauseState()
  {
   if(IsTesting())
      return;

   GlobalVariableSet(ConsecutiveSLStateKey("COUNT"),
                     (double)g_consecutiveBasketSLCount);
   GlobalVariableSet(ConsecutiveSLStateKey("UNTIL"),
                     (double)g_consecutiveBasketSLPauseUntil);
   GlobalVariablesFlush();
  }

//+------------------------------------------------------------------+
void LoadConsecutiveSLPauseState()
  {
   g_consecutiveBasketSLCount      = 0;
   g_consecutiveBasketSLPauseUntil = 0;

   if(IsTesting())
     {
      // Strategy Tester uses the same pause logic but does not restore terminal
      // Global Variables from an earlier test run.
      g_consecutiveSLPauseStatus = "READY";
      return;
     }

   string countKey = ConsecutiveSLStateKey("COUNT");
   string untilKey = ConsecutiveSLStateKey("UNTIL");

   if(GlobalVariableCheck(countKey))
      g_consecutiveBasketSLCount =
         MathMax(0,(int)GlobalVariableGet(countKey));

   if(GlobalVariableCheck(untilKey))
      g_consecutiveBasketSLPauseUntil =
         (datetime)GlobalVariableGet(untilKey);

   if(g_consecutiveBasketSLPauseUntil > 0 &&
      TimeCurrent() >= g_consecutiveBasketSLPauseUntil)
     {
      g_consecutiveBasketSLCount      = 0;
      g_consecutiveBasketSLPauseUntil = 0;
      SaveConsecutiveSLPauseState();
     }
  }

//+------------------------------------------------------------------+
bool IsConsecutiveSLPauseActive()
  {
   if(!InpUseConsecutiveSLPause)
      return(false);

   if(g_consecutiveBasketSLPauseUntil <= 0)
      return(false);

   if(TimeCurrent() >= g_consecutiveBasketSLPauseUntil)
     {
      g_consecutiveBasketSLCount      = 0;
      g_consecutiveBasketSLPauseUntil = 0;
      g_consecutiveSLPauseStatus      = "READY | PAUSE EXPIRED";
      SaveConsecutiveSLPauseState();
      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
string ConsecutiveSLPauseStatusText()
  {
   int required = MathMax(1,InpConsecutiveSLPauseCount);

   if(!InpUseConsecutiveSLPause)
      return("OFF");

   if(IsConsecutiveSLPauseActive())
     {
      int leftSec = (int)(g_consecutiveBasketSLPauseUntil-TimeCurrent());
      if(leftSec < 0)
         leftSec = 0;

      return("BLOCK | SL " +
             IntegerToString(g_consecutiveBasketSLCount) + "/" +
             IntegerToString(required) +
             " | LEFT " + IntegerToString(leftSec/60) + "m " +
             IntegerToString(leftSec%60) + "s");
     }

   return("READY | SL " +
          IntegerToString(g_consecutiveBasketSLCount) + "/" +
          IntegerToString(required));
  }

//+------------------------------------------------------------------+
//| One-shot cooling pause at a configurable share of the day loss.  |
//| It blocks only NEW entries; existing market orders are managed.  |
//+------------------------------------------------------------------+
bool IsHalfLossPauseActive()
  {
   if(!InpUseHalfLossPause)
      return(false);

   if(g_halfLossPauseUntil <= 0)
      return(false);

   if(TimeCurrent() >= g_halfLossPauseUntil)
     {
      datetime expiredAt = g_halfLossPauseUntil;
      g_halfLossPauseUntil = 0;
      g_halfLossPauseStatus = "RESUMED | ONE-SHOT USED THIS CYCLE";

      Print("HALF LOSS COOLING PAUSE ENDED | Trading resumed",
            " | EndedAt=",TimeToString(expiredAt,TIME_DATE|TIME_SECONDS),
            " | Equity=$",DoubleToString(AccountEquity(),2),
            " | WarningLevel=$",DoubleToString(g_halfLossPauseEquityLevel,2),
            " | FullLossStop=$",DoubleToString(g_lossStopEquityLevel,2),
            " | BaseSARConfirmRaw=",DoubleToString(InpSARConfirmPriceDiff,2),
            " | AddedSARConfirmRaw=",DoubleToString(MathMax(0.0,InpInitialServerSLExtraRawAfterHalfLoss),2),
            " | EffectiveSARConfirmRaw=",DoubleToString(GetEffectiveSARConfirmPriceDiff(),2));

      SendEAAlert(
         "TRADING RESUMED - HALF LOSS PAUSE ENDED",
         "Equity $" + DoubleToString(AccountEquity(),2) +
         " | Full stop $" + DoubleToString(g_lossStopEquityLevel,2));

      return(false);
     }

   return(true);
  }

//+------------------------------------------------------------------+
string HalfLossPauseStatusText()
  {
   if(!InpUseHalfLossPause)
      return("OFF");

   if(IsHalfLossPauseActive())
     {
      int leftSec = (int)MathMax(0,g_halfLossPauseUntil-TimeCurrent());
      return("BLOCK | LEFT " + IntegerToString(leftSec/60) + "m " +
             IntegerToString(leftSec%60) + "s | LEVEL $" +
             DoubleToString(g_halfLossPauseEquityLevel,2));
     }

   return(g_halfLossPauseStatus +
          " | LEVEL $" + DoubleToString(g_halfLossPauseEquityLevel,2));
  }

//+------------------------------------------------------------------+
void UpdateHalfLossPauseState()
  {
   if(!InpUseHalfLossPause || !InpUseEquityProtection)
     {
      g_halfLossPauseStatus = !InpUseHalfLossPause
                              ? "OFF"
                              : "OFF | EQUITY PROTECTION OFF";
      return;
     }

   // Expire an active pause, but never trigger it again in the same cycle.
   if(g_halfLossPauseTriggered)
     {
      IsHalfLossPauseActive();
      return;
     }

   if(g_equityProtectionHit || g_dailyProfitLock)
      return;

   double currentEquity = AccountEquity();

   if(currentEquity > g_halfLossPauseEquityLevel)
      return;

   // The full day-loss lock has priority and is handled before this method.
   if(currentEquity <= g_lossStopEquityLevel)
      return;

   int pauseMinutes = MathMax(1,InpHalfLossPauseMinutes);

   g_halfLossPauseTriggered = true;
   g_halfLossPauseUntil = TimeCurrent() + pauseMinutes*60;
   g_halfLossPauseStatus =
      "BLOCK | UNTIL " +
      TimeToString(g_halfLossPauseUntil,TIME_DATE|TIME_MINUTES);

   if(InpDeletePendingOnHalfLossPause)
      DeletePendingOrdersByDirection(
         0,
         "HALF LOSS COOLING PAUSE | " + g_halfLossPauseStatus,
         false);

   double drawdownUSD =
      MathMax(0.0,GetEquityCycleAnchor()-currentEquity);

   Print("HALF LOSS COOLING PAUSE STARTED",
         " | Equity=$",DoubleToString(currentEquity,2),
         " | EquityAnchor=$",DoubleToString(GetEquityCycleAnchor(),2),
         " | StrategyReference=$",DoubleToString(g_baseBalance,2),
         " | LossPercent=",DoubleToString(InpLossStopPercent,2),"%",
         " | TriggerShare=",
         DoubleToString(InpHalfLossPauseTriggerPercent,2),"%",
         " | Drawdown=$",DoubleToString(drawdownUSD,2),
         " | WarningLevel=$",DoubleToString(g_halfLossPauseEquityLevel,2),
         " | FullLossStop=$",DoubleToString(g_lossStopEquityLevel,2),
         " | PauseMinutes=",pauseMinutes,
         " | Existing market orders remain managed.");

   NotifyTradingPausedReasonOnce(
      "HALF_LOSS_COOLING",
      "TRADING PAUSED - HALF LOSS COOLING",
      "Equity $" + DoubleToString(currentEquity,2) +
      " | Drawdown $" + DoubleToString(drawdownUSD,2) +
      " | Resume " +
      TimeToString(g_halfLossPauseUntil,TIME_DATE|TIME_MINUTES) +
      " | Full stop $" + DoubleToString(g_lossStopEquityLevel,2) +
      " | " + GetPauseClockDetails());
  }

//+------------------------------------------------------------------+
bool IsNewOrderHardPauseActive()
  {
   return(IsDubaiNoNewOrderHourNow() ||
          IsConsecutiveSLPauseActive() ||
          IsHalfLossPauseActive());
  }

//+------------------------------------------------------------------+
string GetNewOrderHardPauseReasonText()
  {
   string reason = "";

   if(IsDubaiNoNewOrderHourNow())
     {
      datetime lockClock = GetActiveNoNewOrderClock();
      string clockLabel = GetActiveNoNewOrderClockLabel();

      reason =
         (IsTesting()
          ? "TESTER BLOCKED HOUR | "
          : "GMT0 BLOCKED SESSION | ") +
         clockLabel + "=" +
         TimeToString(lockClock,TIME_DATE|TIME_MINUTES) +
         " | HOUR=" + IntegerToString(TimeHour(lockClock)) +
         " | HOURS=" +
         GetActiveNoNewOrderHourList();
     }

   if(IsConsecutiveSLPauseActive())
     {
      if(reason != "")
         reason += " | ";
      reason += "CONSECUTIVE SL PAUSE | " +
                ConsecutiveSLPauseStatusText();
     }

   if(IsHalfLossPauseActive())
     {
      if(reason != "")
         reason += " | ";
      reason += "HALF LOSS COOLING PAUSE | " +
                HalfLossPauseStatusText();
     }

   if(reason == "")
      reason = "NEW ORDERS ALLOWED";

   return(reason);
  }

//+------------------------------------------------------------------+
void RegisterConsecutiveBasketSL(int direction,
                                 double basketProfit,
                                 string reason)
  {
   if(!InpUseConsecutiveSLPause)
      return;

   // Multiple close paths can inspect the same side on the same server second.
   // Count that completed basket stop only once.
   if(g_lastConsecutiveSLRegisterTime == TimeCurrent() &&
      g_lastConsecutiveSLRegisterDirection == direction)
      return;

   g_lastConsecutiveSLRegisterTime      = TimeCurrent();
   g_lastConsecutiveSLRegisterDirection = direction;
   g_consecutiveBasketSLCount++;

   int required = MathMax(1,InpConsecutiveSLPauseCount);

   Print("CONSECUTIVE BASKET SL REGISTERED | Direction=",
         DirectionText(direction),
         " | BasketP/L=$",DoubleToString(basketProfit,2),
         " | Count=",g_consecutiveBasketSLCount,"/",required,
         " | Reason=",reason);

   if(g_consecutiveBasketSLCount >= required)
     {
      int pauseMinutes = MathMax(1,InpConsecutiveSLPauseMinutes);
      g_consecutiveBasketSLPauseUntil =
         TimeCurrent() + pauseMinutes*60;

      g_consecutiveSLPauseStatus =
         "BLOCK | SL " +
         IntegerToString(g_consecutiveBasketSLCount) + "/" +
         IntegerToString(required) +
         " | UNTIL " +
         TimeToString(g_consecutiveBasketSLPauseUntil,
                      TIME_DATE|TIME_MINUTES);

      if(InpDeletePendingOnSLPause)
         DeletePendingOrdersByDirection(
            0,
            "CONSECUTIVE BASKET SL PAUSE | " +
            g_consecutiveSLPauseStatus,
            false);

      Print("ALL NEW ORDERS PAUSED AFTER CONSECUTIVE SL | ",
            g_consecutiveSLPauseStatus);
     }
   else
     {
      g_consecutiveSLPauseStatus =
         "READY | SL " +
         IntegerToString(g_consecutiveBasketSLCount) + "/" +
         IntegerToString(required);
     }

   SaveConsecutiveSLPauseState();
  }

//+------------------------------------------------------------------+
void RegisterProfitableBasketClose(double basketProfit,
                                   string reason)
  {
   if(!InpUseConsecutiveSLPause ||
      !InpResetSLStreakOnProfitClose ||
      basketProfit <= 0.0)
      return;

   if(g_consecutiveBasketSLCount <= 0 &&
      g_consecutiveBasketSLPauseUntil <= 0)
      return;

   Print("CONSECUTIVE SL STREAK RESET BY PROFIT CLOSE | Profit=$",
         DoubleToString(basketProfit,2),
         " | PreviousCount=",g_consecutiveBasketSLCount,
         " | Reason=",reason);

   g_consecutiveBasketSLCount      = 0;
   g_consecutiveBasketSLPauseUntil = 0;
   g_consecutiveSLPauseStatus      = "READY | RESET BY PROFIT";
   SaveConsecutiveSLPauseState();
  }

//+------------------------------------------------------------------+
void ResetEquityDayIfNewDay()
  {
   // The complete fresh-day reset is handled as the first OnTick action.
   // When enabled, do not also perform a rolling 24-hour reset later.
   if(InpUseFreshDayStart && InpFreshDayDisableRollingEquityReset)
      return;

   datetime now = TimeCurrent();
   int currentDateKey = GetCurrentFreshDayDateKey();

   bool resetNow = false;
   string resetReason = "";

   if(InpResetEquityStatsEvery6Hours)
     {
      if(InpUseFixedEquityResetHours)
        {
         int currentSlot = GetEquityResetSlot(now);

         if(IsConfiguredEquityResetHour(TimeHour(now)) &&
            currentSlot != g_lastEquityResetSlot)
           {
            resetNow = true;
            resetReason = "FIXED EQUITY RESET HOUR";
           }
        }
      else
        {
         int resetSeconds = MathMax(1,InpEquityResetHours) * 3600;
         if(g_lastEquityStatsResetTime <= 0 ||
            now - g_lastEquityStatsResetTime >= resetSeconds)
           {
            resetNow = true;
            resetReason = "ROLLING EQUITY RESET";
           }
        }
     }

   if(!InpUseFixedEquityResetHours &&
      currentDateKey != g_equityDateKey)
     {
      resetNow = true;
      resetReason = "NEW DAY";
     }

   if(resetNow)
     {
      g_equityCycleNumber++;
      InitializeEquityDay();

      Print(resetReason,
            " | Equity statistics reset from AccountBalance(). Trading enabled. Hours=",
            InpEquityResetHourList);
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
   return(AccountEquity() - GetEquityCycleAnchor());
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
int CountPendingEntriesByDirection(int direction)
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
      if(!IsPendingOrderType(OrderType()))
         continue;
      if(!IsOrderTypeForDirection(OrderType(), direction, true))
         continue;

      total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
// Atomic pre-OrderSend guard shared by every entry strategy.
bool IsSameDirectionEntryGapAllowed(int direction,
                                    double candidatePrice,
                                    bool candidateIsPending,
                                    string source)
  {
   if(!InpUseCentralOrderGapSafety)
      return(true);

   if(direction != 1 && direction != -1)
      return(false);

   double minimumGap = MathMax(0.0,
                               InpMinimumSameDirectionOrderGapRaw);

   if(candidateIsPending &&
      InpOnlyOnePendingOrderPerDirection &&
      CountPendingEntriesByDirection(direction) > 0)
     {
      g_lastOrderOpenReason =
         "ORDER GAP BLOCK | ONE " + DirectionText(direction) +
         " PENDING ALREADY EXISTS | Source=" + source;
      SetLastOrderBlockDashboard(g_lastOrderOpenReason);
      Print(g_lastOrderOpenReason);
      return(false);
     }

   if(minimumGap <= 0.0)
      return(true);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(IsSARGuardOrderComment(OrderComment()))
         continue;
      if(!IsOrderTypeForDirection(OrderType(), direction, true))
         continue;

      double existingPrice = OrderOpenPrice();
      double gapRaw = MathAbs(candidatePrice - existingPrice);

      if(gapRaw + 0.0000001 < minimumGap)
        {
         g_lastOrderOpenReason =
            "ORDER GAP BLOCK | " + DirectionText(direction) +
            " GAP " + DoubleToString(gapRaw, 1) +
            "/" + DoubleToString(minimumGap, 1) +
            " | Existing #" + IntegerToString(OrderTicket()) +
            " @" + DoubleToString(existingPrice, Digits) +
            " | Candidate @" + DoubleToString(candidatePrice, Digits) +
            " | Source=" + source;

         SetLastOrderBlockDashboard(g_lastOrderOpenReason);
         Print(g_lastOrderOpenReason);
         return(false);
        }
     }

   return(true);
  }

//+------------------------------------------------------------------+
// Delete duplicate/too-close same-direction pending orders. The oldest
// pending ticket is kept when the one-pending option is enabled.
int EnforcePendingOrderGapSafetyForDirection(int direction)
  {
   if(!InpUseCentralOrderGapSafety)
      return(0);

   double minimumGap = MathMax(0.0,
                               InpMinimumSameDirectionOrderGapRaw);
   int deleted = 0;

   int keepTicket = -1;
   datetime keepTime = 0;

   if(InpOnlyOnePendingOrderPerDirection)
     {
      for(int k = OrdersTotal() - 1; k >= 0; k--)
        {
         if(!OrderSelect(k, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() ||
            OrderMagicNumber() != InpMagicNumber)
            continue;
         if(IsSARGuardOrderComment(OrderComment()) ||
            !IsPendingOrderType(OrderType()) ||
            !IsOrderTypeForDirection(OrderType(), direction, true))
            continue;

         if(keepTicket < 0 ||
            OrderOpenTime() < keepTime ||
            (OrderOpenTime() == keepTime && OrderTicket() < keepTicket))
           {
            keepTicket = OrderTicket();
            keepTime = OrderOpenTime();
           }
        }
     }

   int tickets[200];
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0 && count < 200; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(IsSARGuardOrderComment(OrderComment()) ||
         !IsPendingOrderType(OrderType()) ||
         !IsOrderTypeForDirection(OrderType(), direction, true))
         continue;

      tickets[count++] = OrderTicket();
     }

   for(int p = 0; p < count; p++)
     {
      int ticket = tickets[p];
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderCloseTime() != 0 || !IsPendingOrderType(OrderType()))
         continue;

      bool deletePending = false;
      string reason = "";

      if(InpOnlyOnePendingOrderPerDirection &&
         keepTicket > 0 && ticket != keepTicket)
        {
         deletePending = true;
         reason = "ONLY ONE PENDING PER DIRECTION | KEEP #" +
                  IntegerToString(keepTicket);
        }

      if(!deletePending &&
         InpDeletePendingTooCloseAfterActivation &&
         minimumGap > 0.0)
        {
         double pendingPrice = OrderOpenPrice();

         for(int j = OrdersTotal() - 1; j >= 0; j--)
           {
            if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
               continue;
            if(OrderSymbol() != Symbol() ||
               OrderMagicNumber() != InpMagicNumber)
               continue;
            if(IsSARGuardOrderComment(OrderComment()))
               continue;

            int marketType = OrderType();
            if(direction == 1 && marketType != OP_BUY)
               continue;
            if(direction == -1 && marketType != OP_SELL)
               continue;

            double gapRaw = MathAbs(pendingPrice - OrderOpenPrice());
            if(gapRaw + 0.0000001 < minimumGap)
              {
               deletePending = true;
               reason = "ACTIVE ORDER GAP " +
                        DoubleToString(gapRaw, 1) + "/" +
                        DoubleToString(minimumGap, 1) +
                        " | Open #" + IntegerToString(OrderTicket());
               break;
              }
           }
        }

      if(!deletePending)
         continue;

      // The nested scan changes the selected order; select the pending again.
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES) ||
         OrderCloseTime() != 0 || !IsPendingOrderType(OrderType()))
         continue;

      ResetLastError();
      if(OrderDelete(ticket))
        {
         deleted++;
         Print("CENTRAL PENDING GAP DELETE | Ticket=", ticket,
               " | Direction=", DirectionText(direction),
               " | Reason=", reason);
        }
      else
        {
         int err = GetLastError();
         Print("CENTRAL PENDING GAP DELETE FAILED | Ticket=", ticket,
               " | Direction=", DirectionText(direction),
               " | Reason=", reason,
               " | Error=", err);
         ResetLastError();
        }
     }

   return(deleted);
  }

//+------------------------------------------------------------------+
// Broker gaps or several pending triggers can still create live orders closer
// than requested. Keep the oldest order and close the newer duplicate.
int CloseNewerLiveOrdersInsideMinimumGap(int direction)
  {
   if(!InpUseCentralOrderGapSafety ||
      !InpCloseNewerLiveOrderIfGapViolated)
      return(0);

   double minimumGap = MathMax(0.0,
                               InpMinimumSameDirectionOrderGapRaw);
   if(minimumGap <= 0.0)
      return(0);

   int tickets[200];
   double prices[200];
   datetime openTimes[200];
   int count = 0;
   int marketTypeWanted = direction > 0 ? OP_BUY : OP_SELL;

   for(int i = OrdersTotal() - 1; i >= 0 && count < 200; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber ||
         OrderType() != marketTypeWanted ||
         IsSARGuardOrderComment(OrderComment()))
         continue;

      tickets[count] = OrderTicket();
      prices[count] = OrderOpenPrice();
      openTimes[count] = OrderOpenTime();
      count++;
     }

   // Oldest first. When several activate in the same second, the smaller
   // ticket is treated as the original order and newer tickets are checked
   // against only the orders that were actually kept.
   for(int a = 0; a < count - 1; a++)
     {
      for(int b = a + 1; b < count; b++)
        {
         bool bOlder =
            (openTimes[b] < openTimes[a]) ||
            (openTimes[b] == openTimes[a] && tickets[b] < tickets[a]);

         if(!bOlder)
            continue;

         int tempTicket = tickets[a];
         tickets[a] = tickets[b];
         tickets[b] = tempTicket;

         double tempPrice = prices[a];
         prices[a] = prices[b];
         prices[b] = tempPrice;

         datetime tempTime = openTimes[a];
         openTimes[a] = openTimes[b];
         openTimes[b] = tempTime;
        }
     }

   double keptPrices[200];
   int keptTickets[200];
   int keptCount = 0;
   int closed = 0;

   for(int n = 0; n < count; n++)
     {
      bool violates = false;
      int olderTicket = -1;
      double violatingGap = 0.0;

      for(int k = 0; k < keptCount; k++)
        {
         double gapRaw = MathAbs(prices[n] - keptPrices[k]);
         if(gapRaw + 0.0000001 < minimumGap)
           {
            violates = true;
            olderTicket = keptTickets[k];
            violatingGap = gapRaw;
            break;
           }
        }

      if(!violates)
        {
         keptPrices[keptCount] = prices[n];
         keptTickets[keptCount] = tickets[n];
         keptCount++;
         continue;
        }

      int ticketToClose = tickets[n];
      if(!OrderSelect(ticketToClose, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderCloseTime() != 0 || OrderType() != marketTypeWanted)
         continue;

      double detectedProfit =
         OrderProfit() + OrderSwap() + OrderCommission();
      double lots = OrderLots();

      RefreshRates();
      double closePrice = direction > 0 ? Bid : Ask;

      ResetLastError();
      if(OrderClose(ticketToClose,
                    lots,
                    closePrice,
                    InpSlippage,
                    clrWhite))
        {
         closed++;
         g_lastAnyOrderCloseTime = TimeCurrent();
         SetLastOrderCloseDashboard(ticketToClose,
                                    marketTypeWanted,
                                    detectedProfit,
                                    closePrice,
                                    "Minimum raw-gap duplicate-order guard");

         Print("CENTRAL LIVE GAP CLOSE | Newer #", ticketToClose,
               " | Keep older #", olderTicket,
               " | Direction=", DirectionText(direction),
               " | Gap=", DoubleToString(violatingGap, 1),
               "/", DoubleToString(minimumGap, 1),
               " | P/L=$", DoubleToString(detectedProfit, 2));
        }
      else
        {
         int err = GetLastError();
         Print("CENTRAL LIVE GAP CLOSE FAILED | Ticket=", ticketToClose,
               " | Keep older #", olderTicket,
               " | Gap=", DoubleToString(violatingGap, 1),
               "/", DoubleToString(minimumGap, 1),
               " | Error=", err);
         ResetLastError();

         // Keep the still-open order in the comparison set so another new
         // duplicate cannot also survive beside it on the same tick.
         keptPrices[keptCount] = prices[n];
         keptTickets[keptCount] = tickets[n];
         keptCount++;
        }
     }

   return(closed);
  }

//+------------------------------------------------------------------+
void EnforceCentralSameDirectionOrderGapSafety()
  {
   if(!InpUseCentralOrderGapSafety)
      return;

   // Close accidental live duplicates first, then remove stale pending orders.
   CloseNewerLiveOrdersInsideMinimumGap(1);
   CloseNewerLiveOrdersInsideMinimumGap(-1);

   EnforcePendingOrderGapSafetyForDirection(1);
   EnforcePendingOrderGapSafetyForDirection(-1);
  }

//+------------------------------------------------------------------+
double GetConfiguredPendingOrderGapRaw()
  {
   double normalGap = MathMax(0.0,InpPendingOrderRawGap);

   if(!InpUseHighRiskPendingOrderGap)
      return(normalGap);

   int hourValue = TimeHour(GetGMT0Time());

   int startHour = (int)MathMax(0,MathMin(23,InpHighRiskPendingGapStartHour));
   int endHour   = (int)MathMax(0,MathMin(23,InpHighRiskPendingGapEndHour));
   bool inWindow = false;

   if(startHour < endHour)
      inWindow = (hourValue >= startHour && hourValue < endHour);
   else
   if(startHour > endHour)
      inWindow = (hourValue >= startHour || hourValue < endHour);

   if(inWindow)
      return(MathMax(normalGap,MathMax(0.0,InpHighRiskPendingOrderRawGap)));

   return(normalGap);
  }

//+------------------------------------------------------------------+
double GetEffectivePendingOrderGapRaw()
  {
   double requested = GetConfiguredPendingOrderGapRaw();
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

   if(IsNewOrderHardPauseActive())
     {
      Print("PENDING ENTRY BLOCKED | ",GetNewOrderHardPauseReasonText()," | GMT0=",
            TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES),
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
//| Good-market first-order continuation helpers                     |
//+------------------------------------------------------------------+
bool IsFirstSARCycleOrderComment(string commentText)
  {
// Broker comments may be truncated to 30/31 characters. The stable prefix
// below remains present in SAR_PARENT_SAR_FLIP_FIRST_ORDER.
   return(IsSARParentOrderComment(commentText) &&
          StringFind(commentText, "SAR_FLIP_FIRST") >= 0);
  }

//+------------------------------------------------------------------+
void ClearGoodMarketContinuation(string reason)
  {
   if(g_goodMarketContinuationPending ||
      g_goodMarketContinuationSourceTicket > 0)
     {
      Print("GOOD MARKET CONTINUATION CLEARED | SourceTicket=",
            g_goodMarketContinuationSourceTicket,
            " | Direction=", DirectionText(g_goodMarketContinuationDirection),
            " | Profit=$", DoubleToString(g_goodMarketContinuationSourceProfit, 2),
            " | Reason=", reason);
     }

   g_goodMarketContinuationPending = false;
   g_goodMarketContinuationDirection = 0;
   g_goodMarketContinuationSourceTicket = 0;
   g_goodMarketContinuationSourceProfit = 0.0;
   g_goodMarketContinuationClosePrice = 0.0;
   g_goodMarketContinuationCloseTime = 0;
   g_goodMarketContinuationLastAttemptTime = 0;
   g_goodMarketContinuationStatus = reason;
  }

//+------------------------------------------------------------------+
void QueueGoodMarketContinuationFromClosedTicket(int ticket,
                                                  int type,
                                                  double netProfit,
                                                  double closePrice)
  {
   if(!InpOpenGoodMarketPendingAfterFirstProfit)
      return;

// User requirement is strictly MORE THAN the threshold, not equal to it.
   if(netProfit <= MathAbs(ScaleTradeMoneyByCurrentLot(InpGoodMarketFirstOrderProfitUSD)))
      return;

   if(type != OP_BUY && type != OP_SELL)
      return;

// SELECT_BY_TICKET confirms the actual historical comment. This excludes
// recovery, hedge and later normal orders even when they close profitably.
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
     {
      Print("GOOD MARKET CONTINUATION NOT QUEUED | History select failed | Ticket=",
            ticket,
            " | Error=", GetLastError());
      ResetLastError();
      return;
     }

   if(OrderSymbol() != Symbol() ||
      OrderMagicNumber() != InpMagicNumber ||
      !IsFirstSARCycleOrderComment(OrderComment()))
      return;

   int direction = (type == OP_BUY) ? 1 : -1;

// One first-order close creates exactly one continuation request.
   if(g_goodMarketContinuationPending &&
      g_goodMarketContinuationSourceTicket == ticket)
      return;

   g_goodMarketContinuationPending = true;
   g_goodMarketContinuationDirection = direction;
   g_goodMarketContinuationSourceTicket = ticket;
   g_goodMarketContinuationSourceProfit = netProfit;
   g_goodMarketContinuationClosePrice = closePrice;
   g_goodMarketContinuationCloseTime = OrderCloseTime();
   g_goodMarketContinuationLastAttemptTime = 0;
   g_goodMarketContinuationStatus = "QUEUED";

// Make the profitable close price available to the existing continuation
// reference logic, including broker/server-side closes detected from history.
   if(direction == g_activeSARDirection &&
      direction == g_sarCycleDirection)
     {
      g_lastClosedNormalOrderPrice = closePrice;
      g_lastClosedNormalOrderTime = TimeCurrent();
      g_lastClosedNormalOrderDirection = direction;
     }

   Print("GOOD MARKET CONFIRMED | FIRST ORDER CLOSED ABOVE THRESHOLD",
         " | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | NetProfit=$", DoubleToString(netProfit, 2),
         " | Required>$", DoubleToString(MathAbs(ScaleTradeMoneyByCurrentLot(InpGoodMarketFirstOrderProfitUSD)), 2),
         " | ClosePrice=", DoubleToString(closePrice, Digits),
         " | NEXT=IMMEDIATE PENDING");
  }

//+------------------------------------------------------------------+
double BuildGoodMarketContinuationPendingPrice(int direction,
                                                double sourceClosePrice)
  {
   RefreshRates();

   double gap = GetEffectivePendingOrderGapRaw();
   double referencePrice = sourceClosePrice;

   if(referencePrice <= 0.0)
      referencePrice = (direction == 1) ? Ask : Bid;

   double pendingPrice = 0.0;

   if(direction == 1)
      pendingPrice = MathMax(referencePrice + gap, Ask + gap);
   else
      if(direction == -1)
         pendingPrice = MathMin(referencePrice - gap, Bid - gap);

   return(NormalizeDouble(pendingPrice, Digits));
  }

//+------------------------------------------------------------------+
bool ProcessGoodMarketFirstOrderContinuation()
  {
   if(!g_goodMarketContinuationPending)
      return(false);

   int direction = g_goodMarketContinuationDirection;

// Never follow an old profitable direction after SAR has reversed.
   if(direction == 0 ||
      g_activeSARDirection == 0 ||
      direction != g_activeSARDirection ||
      direction != g_sarCycleDirection)
     {
      ClearGoodMarketContinuation("CANCELLED | SAR DIRECTION CHANGED");
      return(false);
     }

// GMT0 hours remain a hard lock. Do not keep a stale good-market request
// until many hours later.
   if(IsNewOrderHardPauseActive())
     {
      ClearGoodMarketContinuation("CANCELLED | " + GetNewOrderHardPauseReasonText());
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "GOOD MARKET CONTINUATION"))
     {
      ClearGoodMarketContinuation(
         "CANCELLED | SIDE LOSS PAUSE");
      return(false);
     }

   if(g_dailyProfitLock ||
      g_equityProtectionHit ||
      g_globalEquityTrailLocked)
     {
      ClearGoodMarketContinuation("CANCELLED | EQUITY/PROFIT LOCK");
      return(false);
     }

   if(!IsTradingAllowedNow())
     {
      g_goodMarketContinuationStatus = "WAIT TRADING PERMISSION";
      return(false);
     }

// The first order is already closed, so with InpMaxOrders=1 the slot is free.
// Still keep the normal hard caps to prevent accidental duplicate exposure.
   int directionEntries = CountDirectionEntriesForCap(direction);
   int maxPerDirection = (int)MathMax(1, InpMaxOrders);
   if(directionEntries >= maxPerDirection)
     {
      ClearGoodMarketContinuation(
         "CANCELLED | DIRECTION CAP " +
         IntegerToString(directionEntries) + "/" +
         IntegerToString(maxPerDirection));
      return(false);
     }

   int allEntries = CountAllEntriesForCap();
   if(InpMaxTotalOpenOrders > 0 &&
      allEntries >= InpMaxTotalOpenOrders)
     {
      ClearGoodMarketContinuation(
         "CANCELLED | TOTAL CAP " +
         IntegerToString(allEntries) + "/" +
         IntegerToString(InpMaxTotalOpenOrders));
      return(false);
     }

   int retrySeconds = (int)MathMax(0, InpGoodMarketPendingRetrySeconds);
   if(retrySeconds > 0 &&
      g_goodMarketContinuationLastAttemptTime > 0 &&
      TimeCurrent() - g_goodMarketContinuationLastAttemptTime < retrySeconds)
      return(false);

   g_goodMarketContinuationLastAttemptTime = TimeCurrent();

   RefreshRates();

   int type = (direction == 1) ? OP_BUYSTOP : OP_SELLSTOP;
   double price = BuildGoodMarketContinuationPendingPrice(
                     direction,
                     g_goodMarketContinuationClosePrice);
   double lot = GetCurrentTradingLot();
   string orderComment = MakeSARParentOrderComment("GOOD_FIRST_PROFIT_PENDING");

// A profitable first order earns exactly one bonus cycle slot even when the
// duration-based SAR-cycle maximum was originally one.
   EnsureSARSignalOrderCycle(direction);
   if(g_sarCycleMaxOrders <= g_sarCycleOrdersCreated)
      g_sarCycleMaxOrders = g_sarCycleOrdersCreated + 1;

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             true,
                                             "GOOD FIRST PROFIT"))
     {
      g_goodMarketContinuationStatus =
         "WAIT ORDER GAP / PENDING SLOT";
      return(false);
     }

   ResetLastError();
   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          InpSlippage,
                          0,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          GetOrderIconColorByComment(direction, orderComment));

   if(ticket < 0)
     {
      int err = GetLastError();
      g_goodMarketContinuationStatus =
         "ORDERSEND RETRY | ERROR " + IntegerToString(err);
      g_lastOrderOpenReason =
         "GOOD MARKET PENDING FAILED | Error=" + IntegerToString(err) +
         " | Direction=" + DirectionText(direction) +
         " | Price=" + DoubleToString(price, Digits);

      Print(g_lastOrderOpenReason,
            " | SourceTicket=", g_goodMarketContinuationSourceTicket,
            " | SourceProfit=$", DoubleToString(g_goodMarketContinuationSourceProfit, 2));
      ResetLastError();
      return(false);
     }

   ApplyInitialServerSideSLToTicket(ticket);
   g_lastOrderTime = TimeCurrent();
   g_lastConfirmedOrderPrice = price;
   g_lastConfirmedOrderTime = TimeCurrent();

   MarkOpenedOrderOnChart(ticket,
                          direction,
                          orderComment,
                          TimeCurrent(),
                          price);
   NotifyCreatedOrderTicket(ticket); // pending push waits until broker activation
   RegisterSARCycleOrderCreated(direction, false);

   g_lastOrderOpenReason =
      "GOOD MARKET PENDING PLACED | Ticket=" + IntegerToString(ticket) +
      " | Direction=" + DirectionText(direction) +
      " | Price=" + DoubleToString(price, Digits) +
      " | Gap=" + DoubleToString(GetEffectivePendingOrderGapRaw(), Digits) +
      " | FirstProfit=$" + DoubleToString(g_goodMarketContinuationSourceProfit, 2);

   Print(g_lastOrderOpenReason,
         " | SourceTicket=", g_goodMarketContinuationSourceTicket,
         " | SARCycleCreated=", g_sarCycleOrdersCreated,
         "/", g_sarCycleMaxOrders,
         " | BYPASS=normal filters",
         " | KEPT=GMT0/SAR/trading/caps");

   g_goodMarketContinuationStatus = "PENDING PLACED #" +
                                    IntegerToString(ticket);
   ClearGoodMarketContinuation(g_goodMarketContinuationStatus);
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

   double profitFromBase = eq - GetEquityCycleAnchor();

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
//| Opening-balance equity guard exemption                           |
//+------------------------------------------------------------------+
bool IsOpeningBalanceEquityLockExempt()
  {
   if(InpBypassEquityLockInTesting && IsTesting())
      return(true);

   if(InpEquityLockExemptAccount > 0 &&
      AccountNumber() == InpEquityLockExemptAccount)
      return(true);

   return(false);
  }

//+------------------------------------------------------------------+
bool CheckEquityConditions()
  {
   ResetEquityDayIfNewDay();

   if(CheckGlobalEquityTrailLock())
      return(true);

// Strategy Tester and the configured live account can be exempted from
// this opening-balance loss/profit guard.
   if(IsOpeningBalanceEquityLockExempt())
     {
      g_dailyProfitLock     = false;
      g_equityProtectionHit = false;
      return(false);
     }

// Keep a previously triggered lock latched until the next equity-cycle reset.
   if(g_equityProtectionHit)
      return(true);

   if(IsDailyProfitPauseActive())
      return(true);

   double currentEquity = AccountEquity();

// 1) Loss lock: equity reaches opening balance minus InpLossStopPercent.
   if(InpUseEquityProtection &&
      currentEquity <= g_lossStopEquityLevel)
     {
      g_equityProtectionHit = true;

      if(InpCloseOrdersOnEquityHit && CountAllOrders() > 0)
         CloseAllEAOrders("OPENING BALANCE LOSS LOCK");

      Print("OPENING BALANCE LOSS LOCK HIT",
            " | Equity=$",DoubleToString(currentEquity,2),
            " | EquityAnchor=$",DoubleToString(GetEquityCycleAnchor(),2),
            " | StrategyReference=$",DoubleToString(g_baseBalance,2),
            " | LossPercent=",DoubleToString(InpLossStopPercent,2),"%",
            " | StopEquity=$",DoubleToString(g_lossStopEquityLevel,2),
            " | Trading paused until next equity reset.");

      if(InpNotifyOnEquityStop && !g_notifyEquityStopSent)
        {
         g_notifyEquityStopSent = true;

         string pauseDetails =
            "Reason: equity reached day loss limit" +
            " | Equity $" + DoubleToString(currentEquity,2) +
            " | DayStart $" + DoubleToString(GetEquityCycleAnchor(),2) +
            " | Ref $" + DoubleToString(g_baseBalance,2) +
            " | Loss $" + DoubleToString(MathMax(0.0,GetEquityCycleAnchor()-currentEquity),2) +
            " | Stop $" + DoubleToString(g_lossStopEquityLevel,2);

         NotifyTradingPausedReasonOnce(
            "DAY_LOSS_LOCK",
            "TRADING PAUSED - DAY LOSS LOCKED",
            pauseDetails);
        }

      return(true);
     }

// Half-loss warning pause: block only NEW entries for a fixed cooling period.
// Existing market orders continue their normal management.
   UpdateHalfLossPauseState();

// 2) Daily profit lock.
// Ladder ON: exact book-and-restart targets 10/15/20/30/40/50.
// Intermediate targets close/book all EA orders but trading continues.
// The lower protected floor activates only after a new market order opens.
// Final target or a later fall below the active floor closes/pauses the day.
// Ladder OFF: retain the original fixed InpProfitTargetPercent behavior.
   if(InpUseDailyProfitLock &&
      InpUseDailyProfitPercentLadder)
     {
      if(CheckDailyProfitPercentLadder(currentEquity))
         return(true);
     }
   else
      if(InpUseDailyProfitLock)
        {
         double profitFromBase =
            currentEquity-GetEquityCycleAnchor();

         if(!g_dailyProfitLock &&
            currentEquity >= g_profitTargetEquity)
           {
            g_dailyProfitLock   = true;
            g_lockedProfitToday = profitFromBase;

            if(InpCloseOrdersOnProfitLock &&
               CountAllOrders() > 0)
               CloseAllEAOrders(
                  "OPENING BALANCE FIXED PROFIT LOCK");

            Print("OPENING BALANCE FIXED PROFIT LOCK HIT",
                  " | EquityAnchor=$",
                  DoubleToString(GetEquityCycleAnchor(),2),
                  " | StrategyReference=$",
                  DoubleToString(g_baseBalance,2),
                  " | Equity=$",
                  DoubleToString(currentEquity,2),
                  " | Profit=$",
                  DoubleToString(profitFromBase,2),
                  " | ProfitPercent=",
                  DoubleToString(
                     InpProfitTargetPercent,2),"%",
                  " | TargetEquity=$",
                  DoubleToString(
                     g_profitTargetEquity,2),
                  " | Trading paused until next equity reset.");

            if(InpNotifyOnProfitLock &&
               !g_notifyProfitLockSent)
              {
               g_notifyProfitLockSent = true;

               string pauseDetails =
                  "Reason: equity reached fixed day profit target" +
                  " | Equity $" +
                  DoubleToString(currentEquity,2) +
                  " | DayStart $" +
                  DoubleToString(GetEquityCycleAnchor(),2) +
                  " | Ref $" +
                  DoubleToString(g_baseBalance,2) +
                  " | Profit $" +
                  DoubleToString(
                     MathMax(0.0,profitFromBase),2) +
                  " | Target $" +
                  DoubleToString(
                     g_profitTargetEquity,2);

               NotifyTradingPausedReasonOnce(
                  "PROFIT_LOCK",
                  "TRADING PAUSED - PROFIT LOCKED",
                  pauseDetails);
              }
           }

         if(IsDailyProfitPauseActive())
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

   double allProfitBeforeClose = GetAllOpenEAOrdersProfit();

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

   if(CountAllOrders() == 0 && allProfitBeforeClose > 0.0)
      RegisterProfitableBasketClose(allProfitBeforeClose,reason);
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
   return(MathMax(0.01, MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD))));
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
   double buffer = MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpDynamicBasketReturnBufferUSD));

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
                                 MathAbs(ScaleTradeMoneyByCurrentLot(InpDynamicBasketMinimumCloseUSD)));
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
                              MathAbs(ScaleTradeMoneyByCurrentLot(InpDynamicBasketMinimumArmUSD)));
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
          MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpServerProfitLockBufferUSD)));
  }

//+------------------------------------------------------------------+
//| Number of completed negative drawdown steps touched.             |
//| -$1.xx => level 1, -$2.xx => level 2, -$3.xx => level 3.         |
//+------------------------------------------------------------------+
int GetDynamicBasketDrawdownLevel(double worstProfit)
  {
   if(!InpUseDynamicBasketDrawdownComebackTP || worstProfit >= 0.0)
      return(0);

   double stepUSD = MathMax(0.01, MathAbs(ScaleTradeMoneyByCurrentLot(InpDynamicBasketDrawdownStepUSD)));
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
                                  MathAbs(ScaleTradeMoneyByCurrentLot(InpDynamicBasketMinComebackProfitUSD)));

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
   g_lastBigCandlePauseBarTime = 0;
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
          StringFind(c, "RECOVERY") >= 0 ||
          StringFind(c, "SLREV_REC1_") == 0 ||  // v1.49 compatibility
          StringFind(c, "SLREV_REC2_") == 0);   // v1.49 compatibility
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
bool IsSLReverseRecoveryChainComment(string commentText)
  {
   return(StringFind(commentText, "SLREV_REC1_") == 0 ||             // v1.49 compatibility
          StringFind(commentText, "SLREV_REC2_") == 0 ||             // v1.49 compatibility
          StringFind(commentText, "SLREV_CHAIN_") == 0 ||            // early v1.50 compatibility
          StringFind(commentText, "SLREV_RECOVERY_1_") == 0 ||
          StringFind(commentText, "SLREV_RECOVERY_CHAIN_") == 0);
  }

//+------------------------------------------------------------------+
bool IsRecoveryChainTicketProcessed(int ticket)
  {
   if(ticket <= 0)
      return(false);

   for(int i = 0; i < g_recoveryChainProcessedCount; i++)
      if(g_recoveryChainProcessedTickets[i] == ticket)
         return(true);

   return(false);
  }

//+------------------------------------------------------------------+
void AddRecoveryChainProcessedTicket(int ticket)
  {
   if(ticket <= 0 || IsRecoveryChainTicketProcessed(ticket))
      return;

   if(g_recoveryChainProcessedCount < DXB_RECOVERY_CHAIN_HISTORY_CAPACITY)
     {
      g_recoveryChainProcessedTickets[g_recoveryChainProcessedCount++] = ticket;
      return;
     }

// Keep the newest tickets if the fixed safety array becomes full.
   for(int i = 1; i < DXB_RECOVERY_CHAIN_HISTORY_CAPACITY; i++)
      g_recoveryChainProcessedTickets[i - 1] = g_recoveryChainProcessedTickets[i];

   g_recoveryChainProcessedTickets[DXB_RECOVERY_CHAIN_HISTORY_CAPACITY - 1] = ticket;
  }

//+------------------------------------------------------------------+
void InitializeSLReverseRecoveryChainTracker()
  {
   g_recoveryChainProcessedCount = 0;
   g_recoveryChainContinuationPending = false;
   g_recoveryChainPendingDirection = 0;
   g_recoveryChainSourceTicket = 0;
   g_recoveryChainSourceProfit = 0.0;
   g_recoveryChainSourceCloseTime = 0;
   g_recoveryChainLastOpenAttemptTime = 0;

// Seed recent history silently. This prevents an old profitable recovery from
// opening a new chain order when the EA is attached or restarted.
   int historyTotal = OrdersHistoryTotal();
   int firstHistoryIndex = MathMax(0, historyTotal - DXB_PUSH_HISTORY_SCAN);

   for(int h = firstHistoryIndex; h < historyTotal; h++)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(!IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      if(IsSLReverseRecoveryChainComment(OrderComment()))
         AddRecoveryChainProcessedTicket(OrderTicket());
     }

   g_recoveryChainTrackerInitialized = true;

   Print("SL REVERSE RECOVERY CHAIN TRACKER READY | SeededClosed=",
         g_recoveryChainProcessedCount,
         " | ContinueAfterAnyProfit=",
         InpContinueSLReverseRecoveryAfterProfit ? "YES" : "NO");
  }

//+------------------------------------------------------------------+
void ProcessSLReverseRecoveryProfitContinuation()
  {
   if(!g_recoveryChainTrackerInitialized)
      return;

// Read newly closed chain tickets in chronological order. A chain continues
// only when the individual recovery order's final NET result is above $0.
   int historyTotal = OrdersHistoryTotal();
   int firstHistoryIndex = MathMax(0, historyTotal - DXB_PUSH_HISTORY_SCAN);

   for(int h = firstHistoryIndex; h < historyTotal; h++)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;
      if(!IsHistoryTimeInsideCurrentFreshDay(OrderCloseTime()))
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      int ticket = OrderTicket();
      if(IsRecoveryChainTicketProcessed(ticket))
         continue;

      string commentText = OrderComment();
      if(!IsSLReverseRecoveryChainComment(commentText))
         continue;

      AddRecoveryChainProcessedTicket(ticket);

      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();
      int closedDirection = (type == OP_BUY) ? 1 : -1;

      if(InpOpenRecoveryAfterClose &&
         InpRecoveryAfterSLReverse &&
         InpContinueSLReverseRecoveryAfterProfit &&
         netProfit > 0.0000001)
        {
         g_recoveryChainContinuationPending = true;
         g_recoveryChainPendingDirection = closedDirection;
         g_recoveryChainSourceTicket = ticket;
         g_recoveryChainSourceProfit = netProfit;
         g_recoveryChainSourceCloseTime = OrderCloseTime();

         Print("SL REVERSE RECOVERY PROFIT DETECTED | Ticket=", ticket,
               " | Direction=", DirectionText(closedDirection),
               " | NetProfit=$", DoubleToString(netProfit, 2),
               " | CloseReason independent | NEXT RECOVERY QUEUED");
        }
      else
        {
// A break-even/loss close ends this recovery chain. It does not matter which
// EA close rule produced the close.
         g_recoveryChainContinuationPending = false;
         g_recoveryChainPendingDirection = 0;
         g_recoveryChainSourceTicket = ticket;
         g_recoveryChainSourceProfit = netProfit;
         g_recoveryChainSourceCloseTime = OrderCloseTime();

         Print("SL REVERSE RECOVERY CHAIN ENDED | Ticket=", ticket,
               " | NetProfit=$", DoubleToString(netProfit, 2),
               " | Continue switch=",
               InpContinueSLReverseRecoveryAfterProfit ? "ON" : "OFF");
        }
     }

   if(!g_recoveryChainContinuationPending ||
      g_recoveryChainPendingDirection == 0)
      return;

// Do not spam OrderSend/filter checks. Keep the request pending and retry until
// current safety rules allow the next order.
   if(TimeCurrent() - g_recoveryChainLastOpenAttemptTime < 5)
      return;

   // SL-reverse chain continuation is allowed even when another recovery/order
   // exists when the dedicated bypass is enabled. OpenRecoveryOrder() still
   // enforces GMT0 hours, trading permission and equity protection.
   if(!InpSLReverseRecoveryBypassEntryLimits && CountRecoveryOrders() > 0)
      return;

   if(IsNewOrderHardPauseActive())
      return;

   g_recoveryChainLastOpenAttemptTime = TimeCurrent();

   int nextDirection = g_recoveryChainPendingDirection;
   int sourceTicket = g_recoveryChainSourceTicket;
   double sourceProfit = g_recoveryChainSourceProfit;

   bool opened = OpenRecoveryOrder(nextDirection,
                                   "Continuous SL reverse recovery after profitable close #" +
                                   IntegerToString(sourceTicket),
                                   2);

   if(opened)
     {
      Print("SL REVERSE RECOVERY CHAIN CONTINUED | PreviousTicket=", sourceTicket,
            " | PreviousProfit=$", DoubleToString(sourceProfit, 2),
            " | NewDirection=", DirectionText(nextDirection),
            " | Continues again after next profitable close");

      g_recoveryChainContinuationPending = false;
      g_recoveryChainPendingDirection = 0;
     }
   else
     {
      Print("SL REVERSE RECOVERY CHAIN WAITING | PreviousTicket=", sourceTicket,
            " | Direction=", DirectionText(nextDirection),
            " | Request remains pending and will retry");
     }
  }

//+------------------------------------------------------------------+
bool CloseRecoveryOrdersAtProfit()
  {
   double target = MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpRecoveryProfitUSD));
   if(target <= 0.0)
      return(false);

   RefreshRates();
   bool closedAny = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      if(IsSARGuardOrderComment(OrderComment()) || !IsRecoveryOrder())
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit + 0.0000001 < target)
         continue;

      int ticket = OrderTicket();
      double lots = OrderLots();
      double closePrice = (type == OP_BUY) ? Bid : Ask;
      string commentText = OrderComment();

      bool ok = OrderClose(ticket, lots, closePrice, InpSlippage, clrYellow);
      if(!ok)
        {
         int err = GetLastError();
         Print("RECOVERY FIXED PROFIT CLOSE FAILED | Ticket=", ticket,
               " | Profit=$", DoubleToString(profit, 2),
               " | Target=$", DoubleToString(target, 2),
               " | Error=", err);
         ResetLastError();
         continue;
        }

      closedAny = true;
      g_lastAnyOrderCloseTime = TimeCurrent();
      SetLastOrderCloseDashboard(ticket, type, profit, closePrice,
                                 "Recovery fixed profit target");

      int recoveryDirection = (type == OP_BUY) ? 1 : -1;
      if(CountOrdersByDirection(recoveryDirection) == 0)
         RegisterProfitableBasketClose(profit,
                                       "Recovery fixed profit target");

      int idx = FindProfitProtectIndex(ticket);
      if(idx >= 0)
         RemoveProfitProtectIndex(idx);

      Print("RECOVERY FIXED PROFIT CLOSED | Ticket=", ticket,
            " | Type=", type == OP_BUY ? "BUY" : "SELL",
            " | Profit=$", DoubleToString(profit, 2),
            " | Target=$", DoubleToString(target, 2),
            " | Comment=", commentText,
            " | Chain continuation is based on actual profitable close history");
     }

   return(closedAny);
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
bool OpenRecoveryOrder(int direction, string sourceReason, int slReverseStage = 0)
  {
   bool isSLReverseRecovery = (slReverseStage >= 1);
   bool bypassSLReverseEntryLimits =
      (isSLReverseRecovery && InpSLReverseRecoveryBypassEntryLimits);

   if(IsNewOrderHardPauseActive())
     {
      string msg = "RECOVERY ORDER BLOCKED | " + GetNewOrderHardPauseReasonText() + " | GMT0=" +
                   TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
                   " | Hours=" + InpNoNewOrderHourList +
                   " | Source=" + sourceReason;
      SetLastOrderBlockDashboard(msg);
      Print(msg);
      return(false);
     }

// Ordinary after-close recovery keeps big-candle protection.
// SL-reverse recovery has priority and bypasses this filter when enabled.
   if(!bypassSLReverseEntryLimits)
     {
      CheckBigCandlePauseOnNewBar(true);
      if(EnforceBigCandleOrderBlock(direction, "OpenRecoveryOrder " + sourceReason))
        {
         Print("RECOVERY ORDER BLOCKED BY BIG CANDLE PAUSE | Source=", sourceReason,
               " | ", BigCandlePauseStatusText());
         return(false);
        }
     }
   else
     {
      Print("SL REVERSE RECOVERY BYPASS | BIG CANDLE FILTER SKIPPED | Stage=",
            slReverseStage, " | Source=", sourceReason);
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

// AFTER-CLOSE recovery is intentionally independent from RECOVERY-GAP SAR matching.
// It may be opposite to the still-active SAR after basket SL or early reverse.
// Therefore do not apply IsRecoveryDirectionStillValid() or strict SAR score here.
// Recovery-gap orders continue to use those filters inside OpenRecoveryGapMarketOrder().

   UpdateAutoMarketFlowMode();
   if(!bypassSLReverseEntryLimits &&
      !IsAutoMarketNewOrderAllowed("RECOVERY " + sourceReason))
     {
      string modeMsg = "RECOVERY ORDER BLOCKED | " + AutoMarketModeStatusText() +
                       " | Source=" + sourceReason;
      SetLastOrderBlockDashboard(modeMsg);
      Print(modeMsg);
      return(false);
     }

   if(bypassSLReverseEntryLimits &&
      (g_autoMarketMode == DXB_MARKET_MODE_MIXED ||
       g_autoMarketMode == DXB_MARKET_MODE_DANGER))
     {
      Print("SL REVERSE RECOVERY BYPASS | MARKET MODE SKIPPED | Mode=",
            g_autoMarketModeText, " | Stage=", slReverseStage,
            " | Source=", sourceReason);
     }

   if(IsOrderBlockedByOppositeDirectionProfitPause(direction, "OpenRecoveryOrder " + sourceReason))
      return(false);

   RefreshRates();

// Ordinary recovery keeps per-direction and total-order limits.
// SL-reverse recovery bypasses both limits when priority bypass is enabled.
   if(!bypassSLReverseEntryLimits)
     {
      if(IsDirectionOrderCapReached(direction, "OpenRecoveryOrder"))
         return(false);

      if(IsTotalOpenOrderCapReached("OpenRecoveryOrder"))
         return(false);
     }
   else
     {
      Print("SL REVERSE RECOVERY BYPASS | DIRECTION/TOTAL ORDER LIMITS SKIPPED",
            " | Direction=", DirectionText(direction),
            " | Stage=", slReverseStage,
            " | Source=", sourceReason);
     }

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

// Ordinary recovery allows only one active recovery order.
// SL-reverse recovery bypasses this count limit when explicitly enabled.
   if(!bypassSLReverseEntryLimits && CountRecoveryOrders() >= 1)
     {
      Print("RECOVERY ORDER BLOCKED | One recovery order already active. Source=", sourceReason);
      return(false);
     }

   if(bypassSLReverseEntryLimits && CountRecoveryOrders() >= 1)
     {
      Print("SL REVERSE RECOVERY BYPASS | EXISTING RECOVERY COUNT SKIPPED",
            " | Existing=", CountRecoveryOrders(),
            " | Stage=", slReverseStage,
            " | Source=", sourceReason);
     }

// AFTER-CLOSE recovery may intentionally oppose the active SAR, so it must not
// be blocked by IsPendingEntryAllowedForCurrentSAR(). GMT0 hours, market mode,
// big-candle protection, equity locks and order caps are still enforced above.

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

   double lot = GetCurrentTradingLot();

   string comment = "AFTER_CLOSE_RECOVERY_" + DirectionText(direction);

// Stage tags identify the continuous SL-reverse recovery lineage:
//   SLREV_RECOVERY_1     = first reverse recovery opened after basket SL.
//   SLREV_RECOVERY_CHAIN = every later continuation in the same direction.
// The word RECOVERY keeps all existing recovery classification/protection active.
// Both tags are eligible to continue again after ANY profitable close.
   if(slReverseStage == 1)
      comment = "SLREV_RECOVERY_1_" + DirectionText(direction);
   else
   if(slReverseStage >= 2)
      comment = "SLREV_RECOVERY_CHAIN_" + DirectionText(direction);
   if(!IsTradingAllowedNow())
     {
      return(false);
     }

// Final atomic same-type check immediately before OrderSend.
// Skip only for priority SL-reverse recovery orders.
   if(!bypassSLReverseEntryLimits &&
      IsDirectionOrderCapReached(direction, "OpenRecoveryOrder FINAL"))
      return(false);

   if(IsNewOrderHardPauseActive())
     {
      Print("RECOVERY ORDERSEND CANCELLED | ",GetNewOrderHardPauseReasonText()," | GMT0=",
            TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES),
            " | Hours=", InpNoNewOrderHourList);
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "AFTER CLOSE RECOVERY"))
      return(false);

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             InpUsePendingOrderEntries,
                                             "AFTER CLOSE RECOVERY"))
      return(false);

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

   ApplyInitialServerSideSLToTicket(ticket);
   g_lastOrderTime = TimeCurrent();
   MarkOpenedOrderOnChart(ticket, direction, comment, TimeCurrent(), price);
   NotifyCreatedOrderTicket(ticket); // pending placement is ignored until activation

   Print(InpUsePendingOrderEntries ? "RECOVERY PENDING PLACED | Ticket=" : "RECOVERY ORDER OPENED | Ticket=", ticket,
         " | Direction=", DirectionText(direction),
         " | TargetProfit=$", DoubleToString(ScaleTradeMoneyByCurrentLot(InpRecoveryProfitUSD), 2),
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
   if(IsNewOrderHardPauseActive())
     {
      string msg = "RECOVERY GAP BLOCKED | " + GetNewOrderHardPauseReasonText() + " | GMT0=" +
                   TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
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

   double lot = GetCurrentRecoveryTradingLot();
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

   if(IsNewOrderHardPauseActive())
     {
      Print("RECOVERY GAP ORDERSEND CANCELLED | ",GetNewOrderHardPauseReasonText()," | GMT0=",
            TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES),
            " | Hours=", InpNoNewOrderHourList);
      return(false);
     }

   if(IsOrderBlockedBySideLossPause(
         direction,
         "RECOVERY GAP"))
      return(false);

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             InpUsePendingOrderEntries,
                                             "RECOVERY GAP"))
      return(false);

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

   ApplyInitialServerSideSLToTicket(ticket);
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

   double armLoss = MathMax(0.01, MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossArmUSD)));

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
                                      MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossArmUSD))), 2);
      return(false);
     }

   double comebackUSD = MathMax(0.01,
                                MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossComebackUSD)));
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

   if(GetCurrentRecoveryTradingLot() <= 0.0)
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
   bool openedRecoveryAfterSARClose = false;
   string sarRecoveryReason = "";

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
            int trackedDirectionToClose = g_sarCloseTrackedDirection;
            CloseOrdersByDirection(trackedDirectionToClose,
                                   "Delayed SAR close on change #" + IntegerToString(g_sarChangesAfterLastNormalOrder));

            if(CountOrdersByDirection(trackedDirectionToClose) == 0)
              {
               openedRecoveryAfterSARClose = true;
               sarRecoveryReason = "Delayed SAR flip close";
              }

            Print("DELAYED SAR CLOSE DONE | ClosedDirection=", DirectionText(trackedDirectionToClose),
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
        {
         bool hadOldDirectionOrders = (CountOrdersByDirection(oldDirection) > 0);
         CloseOrdersByDirection(oldDirection, "SAR signal changed");

         if(hadOldDirectionOrders && CountOrdersByDirection(oldDirection) == 0)
           {
            openedRecoveryAfterSARClose = true;
            sarRecoveryReason = "Immediate SAR flip close";
           }
        }

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

   // SAR direction is now refreshed. Open recovery in the new SAR direction
   // only when this SAR change actually closed a basket.
   if(openedRecoveryAfterSARClose)
      OpenRecoveryOrder(sarFlip, sarRecoveryReason);

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
   bool profitClose    = (basketProfit >= ScaleTradeMoneyByCurrentLot(InpEarlySARWeakExitMinProfitUSD));
   bool lossClose      = (basketProfit <= -MathAbs(ScaleTradeMoneyByCurrentLot(InpEarlySARWeakExitMaxLossUSD)));
   bool trailClose     = (g_activeBasketPeakProfit >= ScaleTradeMoneyByCurrentLot(InpEarlySARWeakExitMinProfitUSD) &&
                          basketProfit <= g_activeBasketPeakProfit - MathAbs(ScaleTradeMoneyByCurrentLot(InpEarlySARWeakExitTrailUSD)));
   bool candlePressureClose =
      (candleWeakExit && basketProfit >= -MathAbs(ScaleTradeMoneyByCurrentLot(InpEarlySARWeakExitMaxLossUSD)));

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
                       basketProfit >= MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpSARWeakMinProfitToClose)));

   double maxSmallLoss = MathAbs(ScaleTradeMoneyByCurrentLot(InpSARWeakMaxSmallLossToCloseUSD));
   bool oldSmallLossClose =
      (InpSARWeakCloseOldSmallLoss &&
       basketAgeMin >= MathMax(1, InpSARWeakBasketAgeMinutes) &&
       basketProfit < MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpSARWeakMinProfitToClose)) &&
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
      peakProfit > 0.0 && peakProfit>ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD) / sarClosedCount && peakProfit>ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD)/2)
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
         dynamicActivateProfit = MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpIndividualProtectActivateUSD));

      // Recovery orders must also be protected using the fixed manual values.
      // This protects RECOVERY_GAP_1 / RECOVERY_GAP_2 / RECOVERY_GAP_3 during sliding up/down market.
      if(recoveryOrder)
         dynamicActivateProfit = MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpIndividualProtectActivateUSD));

      // Close after profit pulls back. Default for normal orders: 50% of dynamic target.
      double dynamicCloseAtProfit = dynamicActivateProfit * 0.50;

      // Keep at least your manual close value.
      dynamicCloseAtProfit = MathMax(dynamicCloseAtProfit, MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpIndividualProtectCloseAtUSD)));

      // Recovery orders use exact manual close value, example: reached $0.50, close when back to $0.40.
      if(recoveryOrder)
         dynamicCloseAtProfit = MathMax(0.0, ScaleTradeMoneyByCurrentLot(InpIndividualProtectCloseAtUSD));

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
// Check BUY and SELL independently.
// This prevents one losing side from closing the opposite side.
   for(int d = 1; d >= -1; d -= 2)
     {
      if(CountOrdersByDirection(d) <= 0)
         continue;

      double effectiveBasketSL = GetEffectiveBasketStopLossUSDForDirection(d);
      if(effectiveBasketSL <= 0.0)
         continue;

      double sideProfit = GetBasketProfit(d);
      double limit = -MathAbs(effectiveBasketSL);
      bool liveOppositeTightSL =
         IsLiveOppositeCandleEmergencySLArmed(d);
      double liveOppositeRangeRatio = g_liveOppositeM1RangeRatio;
      double liveOppositeBodyPercent = g_liveOppositeCurrentBodyPercent;

      if(sideProfit <= limit)
        {
         string sideText = DirectionText(d);
         string closeReason =
            liveOppositeTightSL
            ? sideText + " LIVE OPPOSITE M1 TIGHT SL $" +
              DoubleToString(sideProfit,2)
            : sideText + " direction basket stop loss $" +
              DoubleToString(sideProfit,2);

         CloseOrdersByDirection(d,closeReason);

         if(CountOrdersByDirection(d) == 0)
            RegisterConsecutiveBasketSL(d,sideProfit,closeReason);

         // Open a strong opposite-impulse continuation first when the side
         // closed specifically by the LIVE OPPOSITE M1 tightened SL. If the
         // strict impulse conditions do not pass, preserve the original
         // configured after-close recovery behaviour.
         if(CountOrdersByDirection(d) == 0)
           {
            bool impulseQueued = false;

            if(liveOppositeTightSL)
               impulseQueued = QueueOppositeImpulseContinuation(d,sideProfit);

            // The old side basket is finished. Any future order starts with a
            // fresh live-candle protection state.
            ResetLiveOppositeCandleEmergencySLState(d);

            if(impulseQueued)
              {
               // Attempt the SELLSTOP/BUYSTOP immediately on this same tick.
               ProcessOppositeImpulseContinuation();

               if(!InpImpulseSkipNormalAfterCloseRecovery)
                 {
                  int recoveryDirection = InpRecoveryAfterSLReverse ? -d : d;
                  OpenRecoveryOrder(recoveryDirection,
                                    sideText +
                                    " live opposite M1 tight SL + impulse",
                                    InpRecoveryAfterSLReverse ? 1 : 0);
                 }
               else
                 {
                  Print("NORMAL AFTER-SL RECOVERY SKIPPED | Opposite impulse has priority",
                        " | ClosedSide=",sideText,
                        " | Impulse=",DirectionText(-d));
                 }
              }
            else
              {
               int recoveryDirection = InpRecoveryAfterSLReverse ? -d : d;
               OpenRecoveryOrder(recoveryDirection,
                                 liveOppositeTightSL
                                 ? sideText + " live opposite M1 tight SL close"
                                 : sideText + " direction basket stop loss close",
                                 InpRecoveryAfterSLReverse ? 1 : 0);
              }
           }
         else
           {
            Print("RECOVERY AFTER SL SKIPPED | Some ", sideText,
                  " orders are still open after close attempt");
           }

         if(d == g_sarCloseTrackedDirection)
           {
            g_sarChangesAfterLastNormalOrder = 0;
            g_sarCloseTrackedDirection       = 0;
            g_sarCloseTrackedOrderTime       = 0;
            g_sarDelayedCloseStatus          = sideText + " direction Basket SL reset";
           }

         Print(liveOppositeTightSL
               ? "LIVE OPPOSITE M1 TIGHT SL HIT | Direction="
               : "DIRECTION-WISE BASKET STOP LOSS HIT | Direction=",
               sideText,
               " | SideProfit=$", DoubleToString(sideProfit, 2),
               " | Limit=$", DoubleToString(MathAbs(effectiveBasketSL), 2),
               liveOppositeTightSL
               ? " | M1RangeRatio=" + DoubleToString(liveOppositeRangeRatio,2) +
                 "x | Body=" + DoubleToString(liveOppositeBodyPercent,1) + "%"
               : "",
               " | Opposite side left untouched");

         status = liveOppositeTightSL
                  ? sideText + " LIVE M1 TIGHT SL | " +
                    OppositeImpulseStatusText()
                  : sideText + " Basket SL only";
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
   double effectiveBasketSL2 = GetEffectiveBasketStopLossUSDForDirection(direction);

   if(effectiveBasketSL2 > 0.0 && profit <= -MathAbs(effectiveBasketSL2))
     {
      string sideSLReason =
         "Basket stop loss $" + DoubleToString(profit, 2);

      CloseOrdersByDirection(direction,sideSLReason);

      if(CountOrdersByDirection(direction) == 0)
        {
         RegisterConsecutiveBasketSL(direction,profit,sideSLReason);
         int recoveryDirection = InpRecoveryAfterSLReverse ? -direction : direction;
         OpenRecoveryOrder(recoveryDirection,
                           DirectionText(direction) + " basket stop loss close",
                           InpRecoveryAfterSLReverse ? 1 : 0);
        }

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
   double effectiveBasketSL3 = GetEffectiveBasketStopLossUSDForDirection(g_activeSARDirection);
   if(effectiveBasketSL3 > 0.0 && activeProfit <= -effectiveBasketSL3)
     {
      int oldDirection = g_activeSARDirection;
      string activeSLReason =
         "Basket stop loss $" + DoubleToString(activeProfit, 2);

      CloseOrdersByDirection(oldDirection,activeSLReason);

      if(CountOrdersByDirection(oldDirection) == 0)
         RegisterConsecutiveBasketSL(oldDirection,activeProfit,activeSLReason);

      // Stop loss means the current SAR cycle gets a fresh normal limit.
      // This ignores the previous SAR duration restriction until the next SAR signal change.
      ResetSARSignalOrderCycleToNormalAfterStopLoss(oldDirection, "Basket stop loss hit");

      int recoveryDirection = oldDirection;
      if(InpRecoveryAfterSLReverse)
         recoveryDirection = -oldDirection;

      OpenRecoveryOrder(recoveryDirection,
                        "Basket stop loss close",
                        InpRecoveryAfterSLReverse ? 1 : 0);

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
         MathMax(0.01, MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD)) * flipMultiplier);

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
         MathMax(0.01, MathAbs(ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD)) * timeMultiplier);

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

// HARD GMT0-TIME ENTRY LOCK: applies to order #1 and every later
// normal SAR order, regardless of the active filter profile.
   if(IsNewOrderHardPauseActive())
     {
      return(SetOrderBlockStatus(
                status,
                "NEW-ORDER HARD LOCK | " +
                GetNewOrderHardPauseReasonText()));
     }

// ORDER #1 AFTER SAR FLIP:
// Go directly to the dedicated price-difference-only profile. This branch
// bypasses optional strategy filters, but never bypasses the hard GMT0
// no-new-order hours, trading permission, direction or per-side cap.
   if(IsFirstSAROrderAfterFlip(g_activeSARDirection))
     {
      if(OpenMarketOrder(g_activeSARDirection, "SAR_FLIP_FIRST_ORDER"))
        {
         status = "FIRST SAR ORDER OPENED | PRICE DIFF + GMT0 TIME OK | " +
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
      return(SetOrderBlockStatus(status, "NEW-ORDER HARD LOCK | " + GetNewOrderHardPauseReasonText()));
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
//| Average High-Low range from fully closed candles only.           |
//+------------------------------------------------------------------+
double GetTickSpeedAverageClosedCandleRange()
  {
   int requested = MathMax(1, InpTickSpeedAverageBars);
   int available = MathMin(requested, Bars - 1);
   if(available <= 0)
      return(0.0);

   double total = 0.0;
   int valid = 0;

   for(int i = 1; i <= available; i++)
     {
      double range = High[i] - Low[i];
      if(range <= 0.0)
         continue;

      total += range;
      valid++;
     }

   if(valid <= 0)
      return(0.0);

   return(total / valid);
  }

//+------------------------------------------------------------------+
void ResetTickSpeedWindow(uint nowMs,double price)
  {
   g_tickSpeedWindowStartMs    = nowMs;
   g_tickSpeedLastTickMs       = nowMs;
   g_tickSpeedWindowStartPrice = price;
   g_tickSpeedWindowMinPrice   = price;
   g_tickSpeedWindowMaxPrice   = price;
   g_tickSpeedWindowLastPrice  = price;
   g_tickSpeedWindowPath       = 0.0;
   g_tickSpeedWindowTicks      = 1;
  }

//+------------------------------------------------------------------+
void FinalizeTickSpeedWindow(uint elapsedMs)
  {
   if(elapsedMs <= 0 || g_tickSpeedWindowTicks <= 0)
      return;

   double elapsedSec = MathMax(0.001, elapsedMs / 1000.0);
   int targetSeconds = MathMax(1, InpTickSpeedWindowSeconds);

   // A window that became very old because no ticks arrived is not a true
   // short-window movement sample. Keep its low tick rate but discard its
   // stale movement distance.
   bool staleWindow = (elapsedSec > targetSeconds * 2.5);

   g_tickSpeedLastWindowNetMove = staleWindow
                                  ? 0.0
                                  : MathAbs(g_tickSpeedWindowLastPrice -
                                            g_tickSpeedWindowStartPrice);
   g_tickSpeedLastWindowRange = staleWindow
                                ? 0.0
                                : MathMax(0.0,
                                          g_tickSpeedWindowMaxPrice -
                                          g_tickSpeedWindowMinPrice);
   g_tickSpeedLastWindowPath = staleWindow
                               ? 0.0
                               : MathMax(0.0,g_tickSpeedWindowPath);
   g_tickSpeedLastWindowTickRate =
      g_tickSpeedWindowTicks / elapsedSec;

   // Do not let a long no-tick gap destroy the normal tick-rate baseline.
   if(!staleWindow && g_tickSpeedLastWindowTickRate > 0.0)
     {
      double alpha = MathMax(0.01,
                     MathMin(1.0,InpTickSpeedBaselineSmoothing));

      if(g_tickSpeedBaselineTickRate <= 0.0)
         g_tickSpeedBaselineTickRate = g_tickSpeedLastWindowTickRate;
      else
         g_tickSpeedBaselineTickRate =
            (g_tickSpeedBaselineTickRate * (1.0 - alpha)) +
            (g_tickSpeedLastWindowTickRate * alpha);

      g_tickSpeedCompletedWindows++;
     }
  }

//+------------------------------------------------------------------+
string GetTickSpeedStatusText()
  {
   return(g_tickSpeedStatus);
  }

//+------------------------------------------------------------------+
color GetTickSpeedStatusColor()
  {
   if(g_tickSpeedStatus == "DANGER")
      return(clrRed);
   if(g_tickSpeedStatus == "FAST")
      return(clrOrange);
   if(g_tickSpeedStatus == "NORMAL")
      return(clrLime);
   if(g_tickSpeedStatus == "SLOW")
      return(clrSilver);

   return(clrAqua);
  }

//+------------------------------------------------------------------+
//| Update combined candle/tick movement statistics on every tick.   |
//+------------------------------------------------------------------+
void UpdateTickSpeedEngine()
  {
   // Always calculate tick speed because adaptive SL and impulse entry use it.
   // InpShowTickSpeedPanel controls only whether the panel is drawn.
   double price = Bid;
   if(price <= 0.0)
      price = Close[0];
   if(price <= 0.0)
      return;

   uint nowMs = GetTickCount();
   int windowSeconds = MathMax(1,InpTickSpeedWindowSeconds);
   uint targetMs = (uint)(windowSeconds * 1000);

   if(g_tickSpeedWindowStartMs == 0 ||
      g_tickSpeedWindowStartPrice <= 0.0)
     {
      ResetTickSpeedWindow(nowMs,price);
     }
   else
     {
      uint elapsedMs = nowMs - g_tickSpeedWindowStartMs;

      if(elapsedMs >= targetMs)
        {
         FinalizeTickSpeedWindow(elapsedMs);
         ResetTickSpeedWindow(nowMs,price);
        }
      else
        {
         g_tickSpeedWindowTicks++;
         g_tickSpeedWindowMinPrice =
            MathMin(g_tickSpeedWindowMinPrice,price);
         g_tickSpeedWindowMaxPrice =
            MathMax(g_tickSpeedWindowMaxPrice,price);
         g_tickSpeedWindowPath +=
            MathAbs(price - g_tickSpeedWindowLastPrice);
         g_tickSpeedWindowLastPrice = price;
         g_tickSpeedLastTickMs = nowMs;
        }
     }

   g_tickSpeedAvgCandleRange =
      GetTickSpeedAverageClosedCandleRange();
   g_tickSpeedCurrentCandleRange =
      MathMax(0.0,High[0] - Low[0]);

   int periodSeconds = MathMax(1,Period() * 60);
   g_tickSpeedCandleElapsedSec =
      (int)MathMax(1,MathMin(periodSeconds,
                   (int)(TimeCurrent() - Time[0])));

   double normalCandleSpeed =
      (g_tickSpeedAvgCandleRange > 0.0)
      ? g_tickSpeedAvgCandleRange / periodSeconds
      : 0.0;
   double currentCandleSpeed =
      g_tickSpeedCurrentCandleRange /
      MathMax(1,g_tickSpeedCandleElapsedSec);

   g_tickSpeedCandleRatio =
      (normalCandleSpeed > 0.0)
      ? currentCandleSpeed / normalCandleSpeed
      : 0.0;

   uint activeElapsedMs = nowMs - g_tickSpeedWindowStartMs;
   double activeElapsedSec = MathMax(1.0,activeElapsedMs / 1000.0);
   double activeNetMove =
      MathAbs(g_tickSpeedWindowLastPrice -
              g_tickSpeedWindowStartPrice);
   double activeRange =
      MathMax(0.0,g_tickSpeedWindowMaxPrice -
                  g_tickSpeedWindowMinPrice);
   double activePath = MathMax(0.0,g_tickSpeedWindowPath);
   double activeTickRate =
      g_tickSpeedWindowTicks / activeElapsedSec;

   // Keep the strongest valid short-window sample visible until the next
   // window completes. Range catches rapid up/down movement that net move
   // alone can miss.
   g_tickSpeedRecentNetMove =
      MathMax(activeNetMove,g_tickSpeedLastWindowNetMove);
   g_tickSpeedRecentRange =
      MathMax(activeRange,g_tickSpeedLastWindowRange);
   g_tickSpeedRecentPath =
      MathMax(activePath,g_tickSpeedLastWindowPath);
   g_tickSpeedCurrentTickRate =
      MathMax(activeTickRate,g_tickSpeedLastWindowTickRate);

   if(g_tickSpeedAvgCandleRange > 0.0)
     {
      g_tickSpeedWindowMoveRatio =
         MathMax(g_tickSpeedRecentNetMove,
                 g_tickSpeedRecentRange) /
         g_tickSpeedAvgCandleRange;
      g_tickSpeedWindowPathRatio =
         g_tickSpeedRecentPath /
         g_tickSpeedAvgCandleRange;
     }
   else
     {
      g_tickSpeedWindowMoveRatio = 0.0;
      g_tickSpeedWindowPathRatio = 0.0;
     }

   g_tickSpeedTickRateRatio =
      (g_tickSpeedBaselineTickRate > 0.0)
      ? g_tickSpeedCurrentTickRate /
        g_tickSpeedBaselineTickRate
      : 1.0;

   if(g_tickSpeedAvgCandleRange <= 0.0 ||
      g_tickSpeedCompletedWindows <= 0)
     {
      g_tickSpeedStatus = "WARMING UP";
      return;
     }

   bool highTickActivity =
      (g_tickSpeedTickRateRatio >=
       MathMax(1.0,InpTickSpeedHighTickRateRatio));

   bool extremeMovement =
      (g_tickSpeedCandleRatio >=
       MathMax(InpTickSpeedDangerCandleRatio,
               InpTickSpeedExtremeCandleRatio)) ||
      (g_tickSpeedWindowMoveRatio >=
       MathMax(InpTickSpeedDangerWindowMoveRatio,
               InpTickSpeedExtremeWindowMoveRatio));

   bool dangerMovement =
      (g_tickSpeedCandleRatio >=
       InpTickSpeedDangerCandleRatio) ||
      (g_tickSpeedWindowMoveRatio >=
       InpTickSpeedDangerWindowMoveRatio) ||
      (g_tickSpeedWindowPathRatio >=
       InpTickSpeedExtremeWindowMoveRatio);

   bool fastMovement =
      (g_tickSpeedCandleRatio >=
       InpTickSpeedFastCandleRatio) ||
      (g_tickSpeedWindowMoveRatio >=
       InpTickSpeedFastWindowMoveRatio) ||
      (g_tickSpeedWindowPathRatio >=
       InpTickSpeedDangerWindowMoveRatio);

   bool slowMovement =
      (g_tickSpeedCandleRatio <=
       InpTickSpeedSlowCandleRatio) &&
      (g_tickSpeedWindowMoveRatio <
       InpTickSpeedFastWindowMoveRatio * 0.40) &&
      (g_tickSpeedTickRateRatio <=
       InpTickSpeedSlowTickRateRatio);

   if(extremeMovement || (dangerMovement && highTickActivity))
      g_tickSpeedStatus = "DANGER";
   else
   if(fastMovement)
      g_tickSpeedStatus = "FAST";
   else
   if(slowMovement)
      g_tickSpeedStatus = "SLOW";
   else
      g_tickSpeedStatus = "NORMAL";
  }

//+------------------------------------------------------------------+
//| Compact panel in the free, absolute top-right chart corner.      |
//+------------------------------------------------------------------+
void DrawTickSpeedDashboardPanel()
  {
   if(InpUseCompactDashboard)
      return;
   if(!InpShowTickSpeedPanel)
      return;

   color stateColor = GetTickSpeedStatusColor();

   DrawCornerPanel("DXB_TICK_SPEED_PANEL",
                   CORNER_RIGHT_UPPER,
                   5,5,310,211,
                   clrBlack,stateColor);

   DrawCornerLabel("DXB_TICK_SPEED_TITLE",
                   "LIVE TICK SPEED",
                   CORNER_RIGHT_UPPER,
                   295,12,
                   stateColor,
                   12);

   DrawCornerLabel("DXB_TICK_SPEED_STATUS",
                   "STATUS : " + GetTickSpeedStatusText() +
                   " | Candle " +
                   DoubleToString(g_tickSpeedCandleRatio,2) + "x",
                   CORNER_RIGHT_UPPER,
                   295,35,
                   stateColor,
                   10);

   DrawCornerLabel("DXB_TICK_SPEED_CANDLE",
                   "Avg/Live candle : " +
                   DoubleToString(g_tickSpeedAvgCandleRange,1) +
                   " / " +
                   DoubleToString(g_tickSpeedCurrentCandleRange,1) +
                   " | " +
                   IntegerToString(g_tickSpeedCandleElapsedSec) + "s",
                   CORNER_RIGHT_UPPER,
                   295,57,
                   clrWhite,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_MOVE",
                   IntegerToString((int)MathMax(1,InpTickSpeedWindowSeconds)) +
                   "s Net/Range : " +
                   DoubleToString(g_tickSpeedRecentNetMove,1) +
                   " / " +
                   DoubleToString(g_tickSpeedRecentRange,1) +
                   " | " +
                   DoubleToString(g_tickSpeedWindowMoveRatio,2) + "x",
                   CORNER_RIGHT_UPPER,
                   295,75,
                   clrAqua,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_TICKS",
                   "Ticks/sec : " +
                   DoubleToString(g_tickSpeedCurrentTickRate,1) +
                   " | Base " +
                   DoubleToString(g_tickSpeedBaselineTickRate,1) +
                   " | " +
                   DoubleToString(g_tickSpeedTickRateRatio,2) + "x",
                   CORNER_RIGHT_UPPER,
                   295,93,
                   clrYellow,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_PATH",
                   "Tick path : " +
                   DoubleToString(g_tickSpeedRecentPath,1) +
                   " | " +
                   DoubleToString(g_tickSpeedWindowPathRatio,2) +
                   "x avg candle",
                   CORNER_RIGHT_UPPER,
                   295,111,
                   clrSilver,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_SL",
                   "Adaptive SL | B " +
                   TickSpeedAdaptiveSLStatusText(1) +
                   " | S " +
                   TickSpeedAdaptiveSLStatusText(-1),
                   CORNER_RIGHT_UPPER,
                   295,129,
                   stateColor,
                   8);

   bool anyLiveTight =
      g_buyLiveOppositeCandleSLArmed ||
      g_sellLiveOppositeCandleSLArmed;

   DrawCornerLabel("DXB_TICK_SPEED_OPP_M1",
                   "Opp M1 SL | B " +
                   LiveOppositeCandleSLStatusText(1) +
                   " | S " +
                   LiveOppositeCandleSLStatusText(-1) +
                   " | R " +
                   DoubleToString(g_liveOppositeM1RangeRatio,2) + "x",
                   CORNER_RIGHT_UPPER,
                   295,147,
                   anyLiveTight ? clrOrangeRed : clrSilver,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_IMPULSE",
                   "Impulse | " + OppositeImpulseStatusText(),
                   CORNER_RIGHT_UPPER,
                   295,165,
                   IsOppositeImpulseContinuationBusy()
                   ? clrMagenta
                   : clrSilver,
                   8);

   DrawCornerLabel("DXB_TICK_SPEED_CONTINUATION",
                   "SAR Add-ons | " +
                   StringSubstr(g_sarContinuationStatus,0,43),
                   CORNER_RIGHT_UPPER,
                   295,183,
                   StringFind(g_sarContinuationStatus,"PENDING",0) >= 0
                   ? clrLime
                   : clrSilver,
                   8);
  }

//+------------------------------------------------------------------+
//| One-second clock guard for exact 23:45 GMT0 shutdown and 00:00 boot.  |
//| MT4 event handlers are serialized, so this cannot run in parallel|
//| with OnTick. It performs only the mandatory day-boundary work.    |
//+------------------------------------------------------------------+
void OnTimer()
  {
   if(!InpUseFreshBootOneSecondTimer)
      return;

   // From 23:45 through 23:59:59 this performs/retries the shutdown and
   // always returns false, keeping every normal strategy operation stopped.
   if(!HandleStrict2345DayEndFreshBoot())
     {
      Comment(g_dayEndFreshBootStatus);
      return;
     }

   // At the first timer event after 00:00, run the same mandatory fresh-day
   // reset used by OnTick. This makes the new-day boot independent of quotes.
   if(InpUseFreshDayStart &&
      GetCurrentFreshDayDateKey() != g_freshDayDateKey)
     {
      if(!HandleFreshDayStart())
        {
         Comment(g_freshDayStatus);
         return;
        }

      if(CheckDailyEARestart())
        {
         Comment(g_dailyEAReinitStatus);
         return;
        }
     }
  }
//+------------------------------------------------------------------+
void OnTick()
  {

// ABSOLUTE FIRST GATE: from 23:45:00 through 23:59:59 no other
// calculation, order-management path or variable update is allowed to run.
   if(!HandleStrict2345DayEndFreshBoot())
     {
      Comment(g_dayEndFreshBootStatus);
      return;
     }

// COMPLETE NEW-DAY RESET MUST RUN BEFORE EVERY OTHER CALCULATION.
// If close/delete needs another tick, all new trading remains blocked.
   if(!HandleFreshDayStart())
     {
      DrawLeftOrderCreationChecklist(g_freshDayStatus);
      DrawDashboard(g_freshDayStatus);
      return;
     }

// Optional final cleanup: after the complete fresh-day reset is flat and
// finished, request one chart-based EA reinitialization for this date.
   if(CheckDailyEARestart())
     {
      DrawLeftOrderCreationChecklist(g_dailyEAReinitStatus);
      DrawDashboard(g_dailyEAReinitStatus);
      return;
     }

// After OnInit(), wait for the configured delay and a genuinely new M1 bar
// before allowing any strategy path to create another order.
   if(IsDailyEAResumeHoldActive())
     {
      DrawLeftOrderCreationChecklist(g_dailyEAReinitStatus);
      DrawDashboard(g_dailyEAReinitStatus);
      return;
     }

   // In Strategy Tester, and whenever chart reinitialization is disabled,
   // this strict internal hold completes the fresh-attach simulation.
   if(IsFreshDayInternalResumeHoldActive())
     {
      DrawLeftOrderCreationChecklist(g_freshDayStatus);
      DrawDashboard(g_freshDayStatus);
      return;
     }

// All mandatory new-day work is now complete: close/delete, runtime reset,
// history cutoff, opening-balance capture, final chart reinitialization,
// configured resume delay and optional new-M1-bar wait. Announce only once.
   NotifyNewDayTradingStartedOnce();

// Update and paint the display-only adaptive tick-speed monitor before any
// trading-path return, so the top-right status remains current.
   UpdateTickSpeedEngine();

   // Add/retry the optional broker-side per-order SL before any early return.
   EnsureInitialServerSideSLForAllOrders();

   // IMPORTANT: InpPendingOrderRawGap is never changed at runtime.
   // GetConfiguredPendingOrderGapRaw() selects 30 or 50 for this tick.

   // Draw the live speed values immediately. The adaptive BUY/SELL SL
   // snapshot is taken later, after UpdateAutoMarketFlowMode() refreshes
   // the CURRENT mode for this tick.
   DrawTickSpeedDashboardPanel();


// Print confirmation only for the first two received ticks.
   if(g_tickConfirmationCount < 2)
     {
      g_tickConfirmationCount++;
      string msg =
         "EA IS WORKING | TICK RECEIVED | Confirmation " +
         IntegerToString(g_tickConfirmationCount) +
         "/2" +
         " | Symbol " + Symbol() +
         " | Bid " + DoubleToString(Bid, Digits) +
         " | Ask " + DoubleToString(Ask, Digits) +
         " | GMT0 " +
         TimeToString(GetGMT0Time(), TIME_DATE | TIME_SECONDS);

      // Confirmation remains in the Experts log only.
      Print(msg);
       if(g_tickConfirmationCount < 2)

      SendNotification(msg);


       
       msg =
        "EQUITY SETTINGS"+
      " | LossPercent="+ DoubleToString(InpLossStopPercent,2)+
      " | LossStopEquity=$"+ DoubleToString(g_lossStopEquityLevel,2)+
      " | ProfitMode="+
      (InpUseDailyProfitPercentLadder
       ? "LADDER "+
         DailyProfitLadderTargetProtectText(2)
       : "FIXED "+
         DoubleToString(InpProfitTargetPercent,2)+"%");

      // Confirmation remains in the Experts log only.
      Print(msg);
       if(g_tickConfirmationCount < 3)

      SendNotification(msg);
     }

// Send only ORDER CREATED / ORDER CLOSED push events.
   ProcessCreatedClosedPushNotifications();

// Rebuild BUY/SELL consecutive-loss streaks from current-day history.
// This can pause only the losing direction while the other side continues.
   UpdateSideLossPauseState(false);

// HARD OPENING-BALANCE EQUITY GUARD FIRST:
// Loss lock uses InpLossStopPercent. Profit protection uses the enabled
// 10/15/20/30/40/50 book-and-restart ladder with highest-profit share locking lock, or the legacy fixed target when ladder is OFF.
   if(CheckEquityConditions())
     {
      string equityPauseStatus =
         DailyProfitPauseDashboardText();

      DrawLeftOrderCreationChecklist(equityPauseStatus);
      DrawDashboard(equityPauseStatus);
      return;
     }

// Continue the SL-reverse recovery chain after ANY profitable recovery close.
// This is based on final history profit, not only InpRecoveryProfitUSD closure.
   ProcessSLReverseRecoveryProfitContinuation();

// A pending BUYSTOP/SELLSTOP can otherwise activate at the broker during
// a blocked GMT0 hour. Remove all untriggered EA pending entries first.
   NotifyNewOrderHardPauseReasonIfNeeded();

   if(IsNewOrderHardPauseActive())
     {
      DeletePendingOrdersByDirection(
         0,
         "NEW-ORDER HARD LOCK | " +
         GetNewOrderHardPauseReasonText(),
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


// Central activation safety: if several pending orders trigger together,
// close the newer live duplicates and delete pending entries that are inside
// the required 50-raw same-direction spacing.
   EnforceCentralSameDirectionOrderGapSafety();

// Detect a new 3-profit streak immediately after history changes and maintain the 2-hour lock.
   UpdateOppositeDirectionProfitPause(false);

   UpdateAutoMarketFlowMode();

   // IMPORTANT ORDER OF EXECUTION:
   // 1. Auto Market Flow selects CONTINUOUS/MEDIUM/MIXED/DANGER base SL.
   // 2. Tick-speed status selects its multiplier.
   // 3. The resulting BUY/SELL SL is snapshotted once and cannot widen later.
   UpdateTickSpeedAdaptiveBasketSLLocks();

   // Live M1 adverse-candle protection is evaluated on this same tick.
   // It can tighten the already-frozen side SL before close processing below.
   UpdateLiveOppositeCandleEmergencySL();

   // Detect a strong opposite reversal suspicion while the old SAR-side
   // basket is still open. This can queue one pre-SAR SELLSTOP/BUYSTOP without
   // waiting for the old basket to hit its stop loss or for SAR dots to flip.
   TryQueuePreSARReversalSuspectEntry();

   // Retry/place/delete the special opposite-impulse pending order on every
   // tick. This manages expiry, SAR invalidation and retracement even when no
   // new normal order is allowed.
   bool oppositeImpulsePlacedThisTick =
      ProcessOppositeImpulseContinuation();

   // Maintain same-direction SAR add-on state and remove stale add-on
   // BUYSTOP/SELLSTOP orders after expiry or a SAR direction change.
   ManageSARContinuationPendingOrders();
   UpdateSARPullbackContinuationState();

   DrawTickSpeedDashboardPanel();

   ApplyMarketModeEntryFilterProfileState();

// Update spike/wick pause status on every tick so dashboard shows it immediately.
   EnforceSpikeWickOrderBlock("OnTick dashboard scan", InpSpikeWickBlockRecovery, InpSpikeWickBlockGuard);

   ProcessSARSpecialGuardCleanup();

// RECOVERY FIXED PROFIT TARGET FIRST:
// Every active after-close/recovery-gap market order closes immediately when
// its own net profit reaches InpRecoveryProfitUSD.
   if(CloseRecoveryOrdersAtProfit())
     {
      DrawLeftOrderCreationChecklist("RECOVERY PROFIT TARGET CLOSED");
      DrawDashboard("RECOVERY PROFIT TARGET CLOSED");
      return;
     }

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

// SECOND EQUITY SAFETY CHECK after close management. This hard account-level
// protection is intentionally independent of the active market-mode filter.
   if(CheckEquityConditions())
     {
      string equityPauseStatus =
         DailyProfitPauseDashboardText();

      DrawLeftOrderCreationChecklist(equityPauseStatus);
      DrawDashboard(equityPauseStatus);
      return;
     }

// Optional individual pullback protection remains available for normal and
// recovery orders that have not yet reached InpRecoveryProfitUSD.
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
   bool closedThisTick = closedByFirstPriority ||
                         oppositeImpulsePlacedThisTick ||
                         IsOppositeImpulseContinuationBusy();

   if(ProcessCloseOrdersFirst(status))
      closedThisTick = true;

   ProcessSARSpecialGuardCleanup();

   if(closedByFirstPriority)
      status = firstPriorityStatus + " | GOOD MARKET CHECK";

// CENTRAL NEW-ORDER HARD LOCK:
// Close/profit/SL management above always remains active. From this point down,
// every new-order path (normal, add-on, impulse, recovery and continuation)
// is stopped during GMT0 16:00-22:59 or an active consecutive-SL pause.
   if(IsNewOrderHardPauseActive())
     {
      DeletePendingOrdersByDirection(
         0,
         "CENTRAL NEW-ORDER HARD LOCK | " +
         GetNewOrderHardPauseReasonText(),
         false);

      status = GetNewOrderHardPauseReasonText() +
               " | EXISTING ORDERS MANAGED";

      DrawLeftOrderCreationChecklist(status);
      DrawDashboard(status);
      return;
     }

// FIRST-ORDER GOOD-MARKET CONTINUATION:
// Place the bonus pending entry immediately after close management and before
// recovery/standard entry logic. A placed or retrying request has priority so
// the normal entry path cannot create a duplicate order on the same tick.
   bool goodMarketPendingPlaced = false;
   if(!IsOppositeImpulseContinuationBusy())
      goodMarketPendingPlaced = ProcessGoodMarketFirstOrderContinuation();
   if(goodMarketPendingPlaced)
     {
      status = g_lastOrderOpenReason;
      closedThisTick = true;
     }
   else
      if(g_goodMarketContinuationPending)
        {
         status = "GOOD MARKET PENDING WAIT | " +
                  g_goodMarketContinuationStatus;
         closedThisTick = true;
        }

   if(IsOppositeImpulseContinuationBusy())
     {
      status = "OPPOSITE IMPULSE | " + OppositeImpulseStatusText();
      closedThisTick = true;
     }

// SAME-DIRECTION SAR CONTINUATION ADD-ONS:
// Pullback continuation has first priority, then profitable pyramid, then
// strong-candle breakout. These paths use their own confirmations and do not
// globally disable LATE_SAR/STRICT_SCORE/DOUBTFUL_CANDLE protections.
   bool sarContinuationPlacedThisTick = false;
   if(!closedThisTick)
      sarContinuationPlacedThisTick =
         ProcessSARContinuationAddOnOrders();

   if(sarContinuationPlacedThisTick)
     {
      status = g_lastOrderOpenReason;
      closedThisTick = true;
     }

// RECOVERY CREATION AFTER SAR UPDATE:
// g_activeSARDirection and the closed-candle SAR signal are now current.
// Profitable continuation additions receive priority over averaging recovery.
// Do not create a recovery order on the same tick that closed/placed an order.
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
//| Half-loss SAR confirmation adjustment                           |
//| The configured input is never modified at runtime.              |
//| Extra raw distance becomes active only AFTER cooling finishes.  |
//+------------------------------------------------------------------+
bool IsHalfLossCoolingPeriodCompleted()
  {
   if(!InpUseHalfLossPause || !g_halfLossPauseTriggered)
      return(false);

   if(g_halfLossPauseUntil <= 0)
      return(true);

   return(TimeCurrent() >= g_halfLossPauseUntil);
  }

//+------------------------------------------------------------------+
double GetHalfLossSARConfirmExtraRaw()
  {
   if(!IsHalfLossCoolingPeriodCompleted())
      return(0.0);

   return(MathMax(0.0,InpInitialServerSLExtraRawAfterHalfLoss));
  }

//+------------------------------------------------------------------+
double GetBuyStrictSARConfirmExtraRaw(int direction)
  {
   if(!InpUseBuyStrictConfirmation ||
      direction != 1)
      return(0.0);

   return(MathMax(0.0,InpBuyExtraSARConfirmRaw));
  }

//+------------------------------------------------------------------+
double GetEffectiveSARConfirmPriceDiffForDirection(int direction)
  {
   return(MathMax(0.0,InpSARConfirmPriceDiff) +
          GetHalfLossSARConfirmExtraRaw() +
          GetBuyStrictSARConfirmExtraRaw(direction));
  }

//+------------------------------------------------------------------+
double GetEffectiveSARConfirmPriceDiff()
  {
   int direction =
      (g_pendingSARConfirmDirection != 0)
      ? g_pendingSARConfirmDirection
      : g_activeSARDirection;

   return(GetEffectiveSARConfirmPriceDiffForDirection(direction));
  }

//+------------------------------------------------------------------+
bool IsFirstSAROrderPriceDiffReady(int direction)
  {
   if(direction == 0)
      return(false);

   double requiredDiff =
      GetEffectiveSARConfirmPriceDiffForDirection(direction);
   double currentDiff  = GetFirstSAROrderLivePriceDiff(direction);

   if(currentDiff < 0.0)
      return(false);

   return(currentDiff >= requiredDiff);
  }

//+------------------------------------------------------------------+
string FirstSAROrderPriceDiffStatusText(int direction)
  {
   double currentDiff  = GetFirstSAROrderLivePriceDiff(direction);
   double requiredDiff =
      GetEffectiveSARConfirmPriceDiffForDirection(direction);

   if(currentDiff < 0.0)
      return("NO SAR Min Distance " + DoubleToString(requiredDiff,Digits) + "/" + DoubleToString(currentDiff, Digits));

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
      double requiredDiff =
         GetEffectiveSARConfirmPriceDiffForDirection(direction);

      if(InpUseDynamicSAREngine)
         requiredDiff =
            GetDynamicSARRequiredConfirmDiffForDirection(direction);

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
double GetDynamicSARRequiredConfirmDiffForDirection(int direction)
  {
   double configuredBase =
      MathMax(0.0,InpSARConfirmPriceDiff);
   double conditionalExtra =
      GetHalfLossSARConfirmExtraRaw() +
      GetBuyStrictSARConfirmExtraRaw(direction);

   if(!InpUseDynamicSAREngine)
      return(configuredBase + conditionalExtra);

   double atr = GetDynamicSARATR();
   if(atr <= 0.0)
      return(configuredBase + conditionalExtra);

   double dynamicDiff =
      atr * InpDynamicConfirmATRMultiplier;

// Safety: do not allow the dynamic requirement to become almost zero in dead market.
   if(configuredBase > 0.0)
      dynamicDiff =
         MathMax(dynamicDiff,
                 configuredBase * 0.35);

// Half-loss and BUY-only confirmation extras are added after the ATR rule.
   dynamicDiff += conditionalExtra;

   return(dynamicDiff);
  }

//+------------------------------------------------------------------+
double GetDynamicSARRequiredConfirmDiff()
  {
   int direction =
      (g_pendingSARConfirmDirection != 0)
      ? g_pendingSARConfirmDirection
      : g_activeSARDirection;

   return(GetDynamicSARRequiredConfirmDiffForDirection(direction));
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
int GetStrictSARMinimumScoreForDirection(int direction)
  {
   int required = InpStrictSARMinimumScore;

   if(InpUseBuyStrictConfirmation &&
      direction == 1)
      required =
         MathMax(required,
                 InpBuyStrictSARMinimumScore);

   if(required < 0)
      required = 0;
   if(required > 7)
      required = 7;

   return(required);
  }

//+------------------------------------------------------------------+
int GetStrictSARMinimumScore()
  {
   int direction =
      (g_pendingSARConfirmDirection != 0)
      ? g_pendingSARConfirmDirection
      : g_activeSARDirection;

   return(GetStrictSARMinimumScoreForDirection(direction));
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

   int required =
      GetStrictSARMinimumScoreForDirection(direction);
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

   if(IsNewOrderHardPauseActive())
      return(BlockNormalOrderByModeProfile(
                "FIRST ORDER | GMT0 NO-NEW HOUR | GMT0=" +
                TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
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
      int required =
         GetStrictSARMinimumScoreForDirection(direction);

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
                "NEW-ORDER HARD LOCK | " + GetNewOrderHardPauseReasonText() +
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

   if(IsNewOrderHardPauseActive())
      return BlockOrder(
                "GMT0 NO-NEW HOUR HARD LOCK | GMT0=" +
                TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
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

   if(IsOrderBlockedBySideLossPause(
         direction,
         "OpenMarketOrder START | " + reason))
      return(false);

   // BUY-only hard safety applies even to the first SAR order profile.
   if(!IsBuyStrictEntryAllowed(
         direction,
         "OpenMarketOrder START | " + reason))
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

   double lot = GetCurrentTradingLot();

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
   if(IsNewOrderHardPauseActive())
      return BlockOrder(
                "OrderSend cancelled last check | GMT0 NO-NEW HOUR | GMT0=" +
                TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
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
   if(IsNewOrderHardPauseActive())
      return BlockOrder(
                "OrderSend aborted at broker boundary | GMT0 NO-NEW HOUR | GMT0=" +
                TimeToString(GetGMT0Time(), TIME_DATE|TIME_MINUTES) +
                " | Hours=" + InpNoNewOrderHourList +
                " | Source=" + reason);

   if(IsOrderBlockedBySideLossPause(
         direction,
         "OpenMarketOrder BROKER BOUNDARY | " + reason))
      return(false);

   if(!IsSameDirectionEntryGapAllowed(direction,
                                             price,
                                             InpUsePendingOrderEntries,
                                             "NORMAL SAR " + reason))
      return(false);

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

   ApplyInitialServerSideSLToTicket(ticket);
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

   int closingDirection = (type == OP_BUY) ? 1 : -1;
   double basketProfitBeforeClose = GetBasketProfit(closingDirection);

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

   if(CountOrdersByDirection(closingDirection) == 0 &&
      basketProfitBeforeClose > 0.0)
      RegisterProfitableBasketClose(basketProfitBeforeClose,reason);
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

      bool isDashboardObject =
         StringFind(name,"DXB_ROW_") == 0 ||
         StringFind(name,"DXB_LEFT_CHK_") == 0 ||
         StringFind(name,"DXB_PANEL") == 0 ||
         StringFind(name,"DXB_TICK_SPEED_") == 0 ||
         StringFind(name,"DXB_ENTRY_AUDIT_") == 0 ||
         StringFind(name,"DXB_RECOVERY_") == 0 ||
         StringFind(name,"DXB_PRO_LEFT_") == 0 ||
         StringFind(name,"DXB_PRO_RIGHT_") == 0 ||
         StringFind(name,"DXB_PRO_REC_") == 0 ||
         StringFind(name,"DXB_RIGHT_") == 0 ||
         StringFind(name,"DXB_LIVE_MODE_") == 0 ||
         StringFind(name,"DXB_ACC_") == 0 ||
         StringFind(name,"DXB_COMPACT_") == 0;

      if(isDashboardObject)
         ObjectDelete(0,name);
     }

   g_compactDashboardLegacyCleared = true;
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
            g_dotColor = 1;
        }
      else
        {
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotSellColor);
         if(i == 0)
            g_dotColor = -1;
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
                     "Lot " + DoubleToString(GetCurrentTradingLot(), 2) +
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
                     "Diff " + DoubleToString(GetEffectiveSARConfirmPriceDiff(), 0) +
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
                     " | Lot " + DoubleToString(GetCurrentRecoveryTradingLot(), 2),
                     InpUseRecoveryGapOrders ? clrLime : clrSilver);

   LeftChecklistInfo("Recovery Loss Return",
                     InpUseRecoveryLossComebackTrigger
                     ? "Touch -$" +
                     DoubleToString(MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossArmUSD)), 2) +
                     " | Improve +$" +
                     DoubleToString(MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossComebackUSD)), 2)
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
   g_entryDiagProfileText = "FIRST ORDER: PRICE DIFF + GMT0 TIME";

   bool directionOk = (direction != 0 &&
                       direction == g_activeSARDirection);
   bool priceDiffOk = IsFirstSAROrderPriceDiffReady(direction);
   bool tradingOk   = CheckListTradingAllowed();
   bool maxOpenOk   = CheckListMaxOpenAllowed(direction);
   bool noNewHourOk = !IsNewOrderHardPauseActive();
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
                     detail = "GMT0=" + TimeToString(GetGMT0Time(), TIME_MINUTES) +
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

   int strictRequired =
      GetStrictSARMinimumScoreForDirection(direction);
   int score = (direction != 0)
               ? GetDynamicSARStrengthScore(direction)
               : 0;
   bool rawStrict = (score >= strictRequired);
   bool rawDoubtful = IsDoubtfulCandleReadyForDashboard(direction);

   bool rawTrading = CheckListTradingAllowed();
   bool rawSpread = (spread <= InpMaxSpreadPoints);
   bool rawEquity =
      (!g_equityProtectionHit &&
       !IsDailyProfitPauseActive());
   bool rawNoHour = !IsDubaiNoNewOrderHourNow();
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
int g_compactDashRow = 0;
bool g_compactDashboardLegacyCleared = false;

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
      return("GMT0 No-New Hour");
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
   double requiredDiff =
      GetEffectiveSARConfirmPriceDiffForDirection(direction);

   if(InpUseDynamicSAREngine)
      requiredDiff =
         GetDynamicSARRequiredConfirmDiffForDirection(direction);

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
   if(IsOpeningBalanceEquityLockExempt())
      return(IsTesting()
             ? "EXEMPT | STRATEGY TESTER"
             : "EXEMPT | ACCOUNT " + IntegerToString(AccountNumber()));

   string state = "CLEAR";
   if(g_equityProtectionHit)
      state = "LOSS LOCKED";
   else
      if(g_dailyProfitLock)
         state = "PROFIT LOCKED";

   string profitText =
      InpUseDailyProfitPercentLadder
      ? " | " + DailyProfitPercentLadderStatusText()
      : " | Target $" +
        DoubleToString(g_profitTargetEquity,2);

   return("Equity $" + DoubleToString(AccountEquity(),2) +
          " | Anchor $" + DoubleToString(GetEquityCycleAnchor(),2) +
          " | Ref $" + DoubleToString(g_baseBalance,2) +
          " | Stop $" + DoubleToString(g_lossStopEquityLevel,2) +
          profitText +
          " | " + state);
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
   if(InpUseCompactDashboard)
      return;
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
   if(InpUseCompactDashboard)
      return;
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
   if(InpUseCompactDashboard)
      return;
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
   if(InpUseCompactDashboard)
      return;
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
//| Compact dashboard helpers                                        |
//+------------------------------------------------------------------+
int CompactCountMarketOrders(int direction)
  {
   int total = 0;

   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();

      if(direction > 0 && type == OP_BUY)
         total++;
      else
      if(direction < 0 && type == OP_SELL)
         total++;
      else
      if(direction == 0 && (type == OP_BUY || type == OP_SELL))
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
int CompactCountPendingOrders(int direction)
  {
   int total = 0;

   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();
      bool buyPending =
         (type == OP_BUYSTOP || type == OP_BUYLIMIT);
      bool sellPending =
         (type == OP_SELLSTOP || type == OP_SELLLIMIT);

      if(direction > 0 && buyPending)
         total++;
      else
      if(direction < 0 && sellPending)
         total++;
      else
      if(direction == 0 && (buyPending || sellPending))
         total++;
     }

   return(total);
  }

//+------------------------------------------------------------------+
string CompactEntryCoverageText()
  {
   int enabled = 1; // Normal SAR first/continuity order is always available.

   if(InpOpenGoodMarketPendingAfterFirstProfit)
      enabled++;
   if(InpUseSARContinuationAddOns && InpUseProfitPyramidOrders)
      enabled++;
   if(InpUseSARContinuationAddOns && InpUsePullbackContinuationOrders)
      enabled++;
   if(InpUseSARContinuationAddOns && InpUseBreakoutContinuationOrders)
      enabled++;
   if(InpUseOppositeImpulseContinuation &&
      InpUsePreSARReversalSuspectEntry)
      enabled++;
   if(InpUseOppositeImpulseContinuation)
      enabled++;
   if(InpUseRecoveryGapOrders)
      enabled++;
   if(InpOpenRecoveryAfterClose)
      enabled++;

   string result =
      IntegerToString(enabled) + "/9 ENTRY PATHS ENABLED";

   if(enabled >= 9)
      result += " | COMPLETE";

   return(result);
  }

//+------------------------------------------------------------------+
string CompactEntryGateText()
  {
   if(g_dailyProfitLock)
      return("BLOCK | +PROFIT EQUITY LOCK");

   if(g_equityProtectionHit)
      return("BLOCK | -LOSS EQUITY LOCK");

   if(g_globalEquityTrailLocked)
      return("BLOCK | GLOBAL EQUITY TRAIL");

   if(IsNewOrderHardPauseActive())
      return("BLOCK | " + GetNewOrderHardPauseReasonText());

   if(!IsTradingAllowedNow())
      return("BLOCK | AUTOTRADING/BROKER");

   if(IsAutoMarketTradingPaused())
      return("BLOCK | MODE " + g_autoMarketModeText);

   if(g_entryDiagBlockedCount > 0)
      return("BLOCK | " +
             StringSubstr(g_entryDiagPrimaryBlock,0,34));

   return("READY | " + DirectionText(g_activeSARDirection));
  }

//+------------------------------------------------------------------+
color CompactEntryGateColor()
  {
   string gate = CompactEntryGateText();

   if(StringFind(gate,"READY",0) >= 0)
      return(clrLime);

   return(clrOrangeRed);
  }

//+------------------------------------------------------------------+
string CompactNextOrderText()
  {
   if(g_dailyProfitLock ||
      g_equityProtectionHit ||
      g_globalEquityTrailLocked ||
      IsNewOrderHardPauseActive() ||
      !IsTradingAllowedNow() ||
      IsAutoMarketTradingPaused())
      return("NONE | HARD SAFETY ACTIVE");

   if(IsOppositeImpulseContinuationBusy())
      return("IMPULSE/REVERSE | " +
             StringSubstr(OppositeImpulseStatusText(),0,28));

   if(g_goodMarketContinuationPending)
      return("GOOD-FIRST | " +
             StringSubstr(g_goodMarketContinuationStatus,0,30));

   if(g_activeSARDirection != 0 &&
      HasSARContinuationPending(g_activeSARDirection))
      return("SAR ADD-ON PENDING | " +
             DirectionText(g_activeSARDirection));

   if(g_pendingRecoveryGapDirection != 0)
      return("RECOVERY WAIT | " +
             DirectionText(g_pendingRecoveryGapDirection));

   if(g_entryDiagBlockedCount > 0)
      return("NORMAL SAR WAIT | " +
             StringSubstr(g_entryDiagPrimaryBlock,0,27));

   return("NORMAL SAR " +
          DirectionText(g_activeSARDirection) +
          " | READY");
  }

//+------------------------------------------------------------------+
string CompactPullbackStateText(int direction)
  {
   if(!InpUseSARContinuationAddOns ||
      !InpUsePullbackContinuationOrders)
      return("OFF");

   bool armed = direction > 0
                ? g_buyPullbackContinuationArmed
                : g_sellPullbackContinuationArmed;

   double raw = direction > 0
                ? g_buyPullbackContinuationRaw
                : g_sellPullbackContinuationRaw;

   if(armed)
      return("ARMED " +
             DirectionText(direction) +
             " | " +
             DoubleToString(raw,1) +
             " RAW");

   return("WAIT | " +
          DirectionText(direction));
  }

//+------------------------------------------------------------------+
string CompactOpenOrderCountText()
  {
   int buyMarket  = CompactCountMarketOrders(1);
   int sellMarket = CompactCountMarketOrders(-1);
   int buyPending = CompactCountPendingOrders(1);
   int sellPending= CompactCountPendingOrders(-1);

   return("MKT B" + IntegerToString(buyMarket) +
          "/S" + IntegerToString(sellMarket) +
          " | PEND B" + IntegerToString(buyPending) +
          "/S" + IntegerToString(sellPending));
  }

//+------------------------------------------------------------------+
string CompactActiveCapText()
  {
   string totalCap = InpMaxTotalOpenOrders > 0
                     ? IntegerToString(InpMaxTotalOpenOrders)
                     : "UNLIMITED";

   return("SIDE " + IntegerToString(InpMaxOrders) +
          " | TOTAL " + totalCap +
          " | GAP " +
          DoubleToString(InpMinimumSameDirectionOrderGapRaw,0));
  }

//+------------------------------------------------------------------+
string CompactHardLockText()
  {
   string hours =
      IsDubaiNoNewOrderHourNow()
      ? "GMT0 BLOCK"
      : "GMT0 PASS";

   string streak =
      IsConsecutiveSLPauseActive()
      ? "SL-STREAK BLOCK"
      : "SL-STREAK PASS";

   string halfLoss =
      IsHalfLossPauseActive()
      ? "HALF-LOSS BLOCK"
      : (g_halfLossPauseTriggered ? "HALF-LOSS USED" : "HALF-LOSS READY");

   return(hours + " | " + streak + " | " + halfLoss);
  }

//+------------------------------------------------------------------+
void CompactDashRow(string title,
                    string value,
                    color textColor=clrWhite)
  {
   string rowName =
      "DXB_COMPACT_ROW_" +
      IntegerToString(g_compactDashRow);

   string rowText =
      PadTitle(title,18) +
      " : " +
      StringSubstr(value,0,48);

   DrawCornerLabel(rowName,
                   rowText,
                   CORNER_RIGHT_UPPER,
                   10,
                   44+(g_compactDashRow*15),
                   textColor,
                   8);

   g_compactDashRow++;
  }

//+------------------------------------------------------------------+
void CompactXYRow(string prefix,
                  int &row,
                  int x,
                  int startY,
                  string title,
                  string value,
                  color textColor=clrWhite,
                  int valueChars=42)
  {
   string objectName = prefix + IntegerToString(row);
   string rowText = PadTitle(title,15) + " : " +
                    StringSubstr(value,0,valueChars);

   DrawCornerLabel(objectName,
                   rowText,
                   CORNER_LEFT_UPPER,
                   x,
                   startY+(row*15),
                   textColor,
                   8);
   row++;
  }

//+------------------------------------------------------------------+
double CompactEquityChangePercent()
  {
   if(g_baseBalance <= 0.0)
      return(0.0);

   return(((AccountEquity()-GetEquityCycleAnchor())/g_baseBalance)*100.0);
  }

//+------------------------------------------------------------------+
string CompactNormalGateSummary()
  {
   if(g_entryDiagBlockedCount > 0)
      return("BLOCK | " + StringSubstr(g_entryDiagPrimaryBlock,0,35));

   return("READY | " + DirectionText(g_activeSARDirection));
  }

//+------------------------------------------------------------------+
string CompactRecoverySummary()
  {
   if(!InpUseRecoveryGapOrders && !InpOpenRecoveryAfterClose)
      return("OFF");

   if(g_pendingRecoveryGapDirection != 0)
      return("WAIT " + DirectionText(g_pendingRecoveryGapDirection) +
             " | " + StringSubstr(g_pendingRecoveryGapReason,0,24));

   return("GAP " + DoubleToString(InpRecoveryGapRawPrice,0) +
          " | B" + IntegerToString(CountRecoveryGapOrdersByDirection(1)) +
          "/S" + IntegerToString(CountRecoveryGapOrdersByDirection(-1)) +
          " | AFTER-SL " + OnOff(InpOpenRecoveryAfterClose));
  }

//+------------------------------------------------------------------+
void DrawCompactDashboard(string status)
  {
   if(!g_compactDashboardLegacyCleared)
      DeleteOldDashboardObjects();

   int chartWidth = (int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
   if(chartWidth < 1000)
      chartWidth = 1000;

   int margin  = 8;
   int sideW   = 300;
   int centerW = 760;

   if(chartWidth < 1500)
     {
      sideW = MathMax(330,(chartWidth-36)/2);
      centerW = MathMin(720,chartWidth-20);
     }

   int centerX = MathMax(margin,(chartWidth-centerW)/2);
   int leftX   = margin;
   int rightX  = MathMax(margin,chartWidth-sideW-margin);
   int topY    = 8;
   int sideY   = 142;

   color titleColor = DashboardTradePermissionColor();
   color gateColor  = CompactEntryGateColor();

   // TOP CENTER: latest order creation/close/account state.
   DrawCornerPanel("DXB_COMPACT_TOP_PANEL",
                   CORNER_LEFT_UPPER,
                   centerX,topY,centerW,140,
                   clrBlack,titleColor);

   DrawCornerLabel("DXB_COMPACT_TOP_TITLE",
                   "DXB SAR v1.90 | LATEST ACTIONS | " +
                   (IsTesting() ? "TEST" : "LIVE") +
                   " | " + Symbol() +
                   " | LOT " + DoubleToString(GetCurrentTradingLot(),2),
                   CORNER_LEFT_UPPER,
                   centerX+10,topY+7,
                   titleColor,10);

   int topRow=0;
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "STATUS",status,titleColor,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "FRESH DAY",g_freshDayStatus,
                g_freshDayResetInProgress?clrOrangeRed:clrAqua,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "EA REINIT",g_dailyEAReinitStatus,
                (StringFind(g_dailyEAReinitStatus,"WAIT") >= 0 ||
                 StringFind(g_dailyEAReinitStatus,"FAILED") >= 0)
                 ? clrOrangeRed : clrAqua,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "LAST OPEN",g_lastOrderOpenReason,clrLime,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "LAST CLOSE",g_lastOrderCloseMessage,clrAqua,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "NEXT ORDER",CompactNextOrderText(),gateColor,88);
   CompactXYRow("DXB_COMPACT_TOP_ROW_",topRow,
                centerX+10,topY+28,
                "ACCOUNT NOW",
                "$"+DoubleToString(AccountBalance(),2)+
                " / EQ $"+DoubleToString(AccountEquity(),2)+
                " / " + DoubleToString(CompactEquityChangePercent(),1)+"%",
                AccountEquity()>=GetEquityCycleAnchor() ? clrLime : clrOrangeRed,88);

   // LEFT: order-creation information only.
   DrawCornerPanel("DXB_COMPACT_LEFT_PANEL",
                   CORNER_LEFT_UPPER,
                   leftX,sideY,sideW,330,
                   clrBlack,gateColor);

   DrawCornerLabel("DXB_COMPACT_LEFT_TITLE",
                   "ORDER CREATION / LIVE GATES",
                   CORNER_LEFT_UPPER,
                   leftX+10,sideY+7,
                   clrYellow,10);

   int leftRow=0;
   int leftChars=MathMax(34,(sideW-135)/7);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "ENTRY GATE",CompactEntryGateText(),gateColor,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "NORMAL SAR",CompactNormalGateSummary(),gateColor,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "SAR / SCORE",
                DirectionText(g_activeSARDirection)+
                " | "+IntegerToString(g_dynamicSARScore)+
                " | AGE "+IntegerToString(GetSARSignalAgeMinutes())+"m"+
                " | CYCLE "+IntegerToString(g_sarCycleOrdersCreated)+
                "/"+IntegerToString(g_sarCycleMaxOrders),
                DirectionColor(g_activeSARDirection),leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "MODE / MOVE",
                g_autoMarketModeText+" | "+
                DoubleToString(g_autoMarketMoveRaw,0)+" RAW | "+
                (IsAutoMarketTradingPaused()?"BLOCK":"ALLOW"),
                IsAutoMarketTradingPaused()?clrOrangeRed:MarketFlowModeColor(),leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "H1 / SPEED",
                DirectionText(GetH1TrendDirection())+" / "+g_tickSpeedStatus,
                clrAqua,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "OPEN / PENDING",CompactOpenOrderCountText(),clrWhite,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "CAP / GAP",CompactActiveCapText(),clrAqua,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "GOOD-FIRST",g_goodMarketContinuationStatus,
                g_goodMarketContinuationPending?clrLime:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "PYRAMID",
                "B"+IntegerToString(CountSARContinuationOrdersCreated(1,"SAR_PYRAMID"))+
                "/S"+IntegerToString(CountSARContinuationOrdersCreated(-1,"SAR_PYRAMID"))+
                " | PROFIT $"+
                DoubleToString(ScaleTradeMoneyByCurrentLot(InpPyramidMinimumBasketProfitUSD),2),
                InpUseProfitPyramidOrders?clrLime:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "PULLBACK",
                CompactPullbackStateText(g_activeSARDirection),
                InpUsePullbackContinuationOrders?clrLime:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "BREAKOUT / BIG",
                "B"+IntegerToString(CountSARContinuationOrdersCreated(1,"SAR_BREAKOUT"))+
                "/S"+IntegerToString(CountSARContinuationOrdersCreated(-1,"SAR_BREAKOUT"))+
                " | "+BigCandleExactStatusText(g_activeSARDirection),
                InpUseBreakoutContinuationOrders?clrLime:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "PRE-SAR",
                InpUsePreSARReversalSuspectEntry?"ON | REVERSE SUSPECT":"OFF",
                InpUsePreSARReversalSuspectEntry?clrMagenta:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "IMPULSE",OppositeImpulseStatusText(),
                IsOppositeImpulseContinuationBusy()?clrMagenta:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "RECOVERY",CompactRecoverySummary(),
                InpUseRecoveryGapOrders?clrAqua:clrSilver,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "HARD LOCKS",CompactHardLockText(),
                IsNewOrderHardPauseActive()?clrOrangeRed:clrLime,leftChars);
   CompactXYRow("DXB_COMPACT_LEFT_ROW_",leftRow,leftX+10,sideY+28,
                "ENTRY COVERAGE",CompactEntryCoverageText(),clrYellow,leftChars);

   // RIGHT: account, dynamic lot, targets and risk.
   DrawCornerPanel("DXB_COMPACT_RIGHT_PANEL",
                   CORNER_LEFT_UPPER,
                   rightX,sideY,sideW,350,
                   clrBlack,clrDimGray);

   DrawCornerLabel("DXB_COMPACT_RIGHT_TITLE",
                   "ACCOUNT / DYNAMIC LOT / RISK",
                   CORNER_LEFT_UPPER,
                   rightX+10,sideY+7,
                   clrYellow,10);

   int rightRow=0;
   int rightChars=MathMax(34,(sideW-135)/7);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "BAL / EQUITY",
                "$"+DoubleToString(AccountBalance(),2)+
                " / $"+DoubleToString(AccountEquity(),2),
                AccountEquity()>=GetEquityCycleAnchor()?clrLime:clrOrangeRed,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "OPENING BASE","$"+DoubleToString(g_baseBalance,2),clrWhite,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "PROFIT LADDER",
                InpUseDailyProfitPercentLadder
                ? (InpUseHighestProfitShareLock
                   ? "ACT " +
                     DoubleToString(GetDailyProfitLadderPercent(1),0) +
                     "% | LOCK " +
                     DoubleToString(InpHighestProfitLockSharePercent,0) +
                     "% OF PEAK | UNLIMITED"
                   : DailyProfitLadderTargetProtectText(0) +
                     " | FINAL $" +
                     DoubleToString(g_profitLadderLevel6Equity,2))
                : "FIXED $"+
                  DoubleToString(g_profitTargetEquity,2),
                clrLime,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "LOSS -20%","$"+DoubleToString(g_lossStopEquityLevel,2),clrRed,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "EQUITY CHANGE",DoubleToString(CompactEquityChangePercent(),2)+"%",
                CompactEquityChangePercent()>=0?clrLime:clrOrangeRed,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "DYNAMIC LOT",DynamicLotStatusText(),clrAqua,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "LOT FORMULA",
                "$"+DoubleToString(InpDynamicLotBalanceStepUSD,0)+
                " = "+DoubleToString(InpDynamicLotPerBalanceStep,2)+
                " | MONEY X"+DoubleToString(GetDynamicLotMoneyMultiplier(),2),
                clrAqua,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "FLOAT B/S/T",
                "$"+DoubleToString(GetBasketProfit(1),2)+
                " / $"+DoubleToString(GetBasketProfit(-1),2)+
                " / $"+DoubleToString(GetAllOpenEAOrdersProfit(),2),
                GetAllOpenEAOrdersProfit()>=0?clrLime:clrRed,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "BASKET TP",
                "$"+DoubleToString(GetBasketProfitTargetUSD(),2)+
                " | LADDER BASE $"+
                DoubleToString(GetDynamicBasketProfitBaseUSD(),2),
                clrLime,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "AVG 10 M1",
                DoubleToString(GetAverageClosedM1CandleHeightRaw(),1)+
                " RAW | SL $"+
                DoubleToString(GetAverageM1CandleBasketStopLossUSD(),2),
                clrAqua,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "BASKET SL",
                "BASE $"+DoubleToString(GetBaseEffectiveBasketStopLossUSD(),2)+
                " | B $"+DoubleToString(g_buyTickSpeedLockedSL,2)+
                " / S $"+DoubleToString(g_sellTickSpeedLockedSL,2),
                clrRed,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "INITIAL SL",
                "WITH SAR $"+
                DoubleToString(ScaleTradeMoneyByCurrentLot(InpInitialServerSLWithSARUSD),2)+
                " | REVERSE $"+
                DoubleToString(ScaleTradeMoneyByCurrentLot(InpInitialServerSLAgainstSARUSD),2),
                clrOrange,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "SERVER LOCK",
                "B "+g_buyServerLockStatus+" | S "+g_sellServerLockStatus,
                InpUseServerSideProfitLock?clrLime:clrSilver,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "EQUITY GUARD",EquityLockExactStatusText(),
                (g_dailyProfitLock||g_equityProtectionHit)?clrOrangeRed:clrLime,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "PROFIT % STATUS",
                DailyProfitPercentLadderStatusText(),
                g_dailyProfitLock
                ? clrOrangeRed
                : (g_profitPercentHighestLevel>0
                   ? clrYellow
                   : clrLime),
                rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "NEXT RESET",FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()),clrAqua,rightChars);
   CompactXYRow("DXB_COMPACT_RIGHT_ROW_",rightRow,rightX+10,sideY+28,
                "PERMISSION",DashboardTradePermissionText(),titleColor,rightChars);

   ChartRedraw(0);
  }


//+------------------------------------------------------------------+
void DrawLegacyDashboard(string status)
  {
   DrawTickSpeedDashboardPanel();

   DrawCornerPanel("DXB_RIGHT_SETTINGS_PANEL",
                   CORNER_RIGHT_UPPER,
                   325,280,320,705,
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
                   liveModeText + " | VERSION 1.88",
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
   RightProRow("Lot Size",DoubleToString(GetCurrentTradingLot(),2),clrWhite);
   RightProRow("Slippage",IntegerToString(InpSlippage),clrWhite);
   RightProRow("Spread Limit",IntegerToString((int)MarketInfo(Symbol(),MODE_SPREAD))+" / "+IntegerToString(InpMaxSpreadPoints),((int)MarketInfo(Symbol(),MODE_SPREAD)<=InpMaxSpreadPoints) ? clrLime : clrRed);
   RightProRow("Basket TP Base","$"+DoubleToString(ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD),2),clrLime);
   RightProRow("Dynamic Basket TP",
               InpUseDynamicBasketProfitBooking
               ? "ON | X LADDER + DD EXIT"
               : "OFF | FIXED TP",
               InpUseDynamicBasketProfitBooking ? clrAqua : clrSilver);
   RightProRow("Drawdown Comeback",
               (InpUseDynamicBasketProfitBooking &&
                InpUseDynamicBasketDrawdownComebackTP)
               ? "ON | -$" +
               DoubleToString(ScaleTradeMoneyByCurrentLot(InpDynamicBasketDrawdownStepUSD),2) +
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
                                    ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD) * MathMax(0.0,
                                          MathMin(1.0, InpSARFlipOppositeBasketTPMultiplier))),2)
               : "OFF",
               InpUseSARFlipOppositeBasketHalfTP ? clrAqua : clrSilver);
   RightProRow("Aged Basket TP",
               InpUseBasketHalfTPAfterMinutes
               ? IntegerToString(MathMax(1, InpBasketHalfTPAfterMinutes)) +
               "m -> $" +
               DoubleToString(MathMax(0.01,
                                      ScaleTradeMoneyByCurrentLot(InpBasketProfitUSD) * MathMax(0.0,
                                            MathMin(1.0, InpBasketHalfTPAfterMinutesMultiplier))),2)
               : "OFF",
               InpUseBasketHalfTPAfterMinutes ? clrAqua : clrSilver);
   RightProRow("TP Time Decay",BasketProfitTimeDecayStatusText(),InpUseBasketProfitTimeDecay ? clrAqua : clrSilver);
   RightProRow("Basket SL Live",
               InpUseTickSpeedAdaptiveBasketSL
               ? "BUY " + TickSpeedAdaptiveSLStatusText(1) +
                 " | SELL " + TickSpeedAdaptiveSLStatusText(-1)
               : "$" + DoubleToString(GetEffectiveBasketStopLossUSD(),2) +
                 (InpUseSimpleSideBasketCloseOnly ? " SIMPLE" : ""),
               clrRed);
   RightProRow("Live Opp M1 SL",
               InpUseLiveOppositeCandleTightSL
               ? "B " + LiveOppositeCandleSLStatusText(1) +
                 " | S " + LiveOppositeCandleSLStatusText(-1) +
                 " | Current/Prev " +
                 DoubleToString(g_liveOppositeCurrentM1Range,1) + "/" +
                 DoubleToString(g_liveOppositePreviousM1Range,1)
               : "OFF",
               (g_buyLiveOppositeCandleSLArmed ||
                g_sellLiveOppositeCandleSLArmed)
               ? clrOrangeRed : clrSilver);
   RightProRow("Impulse Pending",
               OppositeImpulseStatusText(),
               IsOppositeImpulseContinuationBusy()
               ? clrMagenta : clrSilver);
   RightProRow("SAR Add-ons",
               StringSubstr(g_sarContinuationStatus,0,38),
               StringFind(g_sarContinuationStatus,"PENDING",0) >= 0
               ? clrLime
               : (InpUseSARContinuationAddOns ? clrAqua : clrSilver));
   RightProRow("Add-on Count",
               "BUY " +
               IntegerToString(
                  CountSARContinuationOrdersCreated(1,"")) +
               "/" +
               IntegerToString(
                  (int)MathMax(0,InpMaxSARContinuationOrdersPerSide)) +
               " | SELL " +
               IntegerToString(
                  CountSARContinuationOrdersCreated(-1,"")) +
               "/" +
               IntegerToString(
                  (int)MathMax(0,InpMaxSARContinuationOrdersPerSide)),
               clrAqua);
   RightProRow("Add-ons Allowed",
               IntegerToString(GetAllowedSARContinuationOrdersByProfitLadder()) +
               " | Daily L" + IntegerToString(g_profitPercentHighestLevel) +
               " | Protected " +
               (InpContinuationRequireProtectedProfit ? "YES" : "NO"),
               clrAqua);
   RightProRow("Market Mode",AutoMarketModeStatusText(),MarketFlowModeColor());
   RightProRow("Opposite Pause",OppositeDirectionProfitPauseStatusText(),IsOppositeDirectionProfitPauseActive() ? clrOrangeRed : clrSilver);
   RightProRow("BUY Loss Pause",SideLossPauseStatusText(1),IsSideLossPauseActiveForDirection(1) ? clrOrangeRed : clrSilver);
   RightProRow("SELL Loss Pause",SideLossPauseStatusText(-1),IsSideLossPauseActiveForDirection(-1) ? clrOrangeRed : clrSilver);
   RightProRow("Ind Profit Protect",OnOff(InpUseIndividualProfitProtect),InpUseIndividualProfitProtect ? clrLime : clrSilver);
   RightProRow("Basket Protect",OnOff(InpUseBasketProfitProtect),InpUseBasketProfitProtect ? clrLime : clrSilver);

   RightProRow("--- RECOVERY ---","",clrDimGray);
   RightProRow("Recovery Gap",DoubleToString(InpRecoveryGapRawPrice,0),clrAqua);
   RightProRow("Loss Comeback",
               InpUseRecoveryLossComebackTrigger
               ? "-$" + DoubleToString(MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossArmUSD)),2) +
               " +$" + DoubleToString(MathAbs(ScaleTradeMoneyByCurrentLot(InpRecoveryLossComebackUSD)),2)
               : "OFF",
               InpUseRecoveryLossComebackTrigger ? clrAqua : clrSilver);
   RightProRow("BUY Loss State",
               RecoveryLossComebackStatusText(1),
               g_buyRecoveryLossComebackArmed ? clrYellow : clrSilver);
   RightProRow("SELL Loss State",
               RecoveryLossComebackStatusText(-1),
               g_sellRecoveryLossComebackArmed ? clrYellow : clrSilver);
   RightProRow("Recovery Lot",DoubleToString(GetCurrentRecoveryTradingLot(),2),clrAqua);
   RightProRow("Max Recovery",IntegerToString(InpMaxRecoveryGapOrdersPerSide),clrAqua);
   RightProRow("Opp Move Block",OnOff(InpStopRecoveryOnStrongOppMove)+" | "+DoubleToString(InpStrongOppMoveBlockRecoveryGap,0),clrYellow);
   RightProRow("Mode Recovery",IsAutoMarketRecoveryAllowed() ? "ALLOW" : "BLOCK",IsAutoMarketRecoveryAllowed() ? clrLime : clrRed);
   RightProRow("Mode Auxiliary","MICRO CREATION REMOVED",clrSilver);

   RightProRow("--- SAR SETTINGS ---","",clrDimGray);
   RightProRow("SAR Direction",DirectionText(g_activeSARDirection),DirectionColor(g_activeSARDirection));
   RightProRow("Confirm Gap",DoubleToString(GetEffectiveSARConfirmPriceDiff(),0),
               (GetHalfLossSARConfirmExtraRaw() > 0.0 ||
                GetBuyStrictSARConfirmExtraRaw(g_activeSARDirection) > 0.0)
               ? clrOrange : clrAqua);
   RightProRow("BUY Strict",
               InpUseBuyStrictConfirmation
               ? "Score " + IntegerToString(InpBuyStrictSARMinimumScore) +
                 " | +Raw " + DoubleToString(InpBuyExtraSARConfirmRaw,0) +
                 " | H1 " + (InpBuyRequireH1TrendMatch ? "YES" : "NO")
               : "OFF",
               InpUseBuyStrictConfirmation ? clrYellow : clrSilver);
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
               " | Profit>=$" + DoubleToString(ScaleTradeMoneyByCurrentLot(InpSARWeakMinProfitToClose),2) +
               " | Age " + IntegerToString(InpSARWeakBasketAgeMinutes) +
               "m Loss<=$" + DoubleToString(ScaleTradeMoneyByCurrentLot(InpSARWeakMaxSmallLossToCloseUSD),2),
               InpUseConfirmedSARWeakBasketClose ? clrLime : clrSilver);
   RightProRow("Spike Status",SpikeWickPauseStatusText(),IsSpikeWickPauseActive() ? clrOrangeRed : clrSilver);
   RightProRow("Global Trail",g_globalEquityTrailStatus,g_globalEquityTrailLocked ? clrOrangeRed : clrAqua);
   RightProRow("No-New Hours",NoNewOrderHoursStatusText(),IsDubaiNoNewOrderHourNow() ? clrOrangeRed : clrLime);
   RightProRow("SL Streak Pause",ConsecutiveSLPauseStatusText(),IsConsecutiveSLPauseActive() ? clrOrangeRed : clrLime);
   RightProRow("Half Loss Pause",HalfLossPauseStatusText(),IsHalfLossPauseActive() ? clrOrangeRed : (g_halfLossPauseTriggered ? clrYellow : clrLime));

   DrawCornerPanel("DXB_RIGHT_ACCOUNT_PANEL",CORNER_RIGHT_UPPER,325,15,320,250,clrBlack,clrDimGray);
   DrawCornerLabel("DXB_RIGHT_ACCOUNT_TITLE","ACCOUNT / BASKET STATUS",CORNER_RIGHT_UPPER,300,23,clrYellow,10);

   int startRow = g_rightDashRow;
   g_rightDashRow = 0;
   int baseY = 47;

   DrawCornerLabel("DXB_ACC_0",PadTitle("Balance",20)+" : $"+DoubleToString(AccountBalance(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrWhite,8);
   DrawCornerLabel("DXB_ACC_1",PadTitle("Equity",20)+" : $"+DoubleToString(AccountEquity(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);
   DrawCornerLabel("DXB_ACC_2",PadTitle("Equity Peak",20)+" : $"+DoubleToString(g_globalEquityPeak,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrAqua,8);
   DrawCornerLabel("DXB_ACC_3",PadTitle("Opening Balance",20)+" : $"+DoubleToString(g_baseBalance,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrWhite,8);
   DrawCornerLabel("DXB_ACC_4",PadTitle("BUY Basket",20)+" : $"+DoubleToString(GetBasketProfit(1),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetBasketProfit(1)>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_5",PadTitle("SELL Basket",20)+" : $"+DoubleToString(GetBasketProfit(-1),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetBasketProfit(-1)>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_6",PadTitle("Floating Total",20)+" : $"+DoubleToString(GetAllOpenEAOrdersProfit(),2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),GetAllOpenEAOrdersProfit()>=0 ? clrLime : clrRed,8);
   DrawCornerLabel("DXB_ACC_7",
                   PadTitle("Profit % Ladder",20)+" : "+
                   (InpUseDailyProfitPercentLadder
                    ? DailyProfitLadderTargetProtectText(0)
                    : "FIXED "+
                      DoubleToString(InpProfitTargetPercent,0)+"%"),
                   CORNER_RIGHT_UPPER,315,
                   baseY+(g_rightDashRow++*16),
                   clrLime,8);
   DrawCornerLabel("DXB_ACC_8",PadTitle("Loss Lock -20%",20)+" : $"+DoubleToString(g_lossStopEquityLevel,2),CORNER_RIGHT_UPPER,315,baseY+(g_rightDashRow++*16),clrRed,8);
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


//+------------------------------------------------------------------+
void DrawDashboard(string status)
  {
   if(InpUseCompactDashboard)
     {
      DrawCompactDashboard(status);
      return;
     }

   if(InpShowLegacyDashboardWhenCompactOff)
      DrawLegacyDashboard(status);
  }

//tested

//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
