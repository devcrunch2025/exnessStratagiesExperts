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

#ifndef OP_BALANCE
#define OP_BALANCE 6
#endif
#property version   "1.34"

//======================== INPUTS ====================================
string InpEAName                  = "DXB Version 5 - SAR Confirm 50 in 5 Min";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 1;
double InpMinGapWhenMaxOrdersMoreThanOne = 70.0;
#define DXB_HARD_MAX_OPEN_ORDERS 6

double InpBasketProfitUSD         =0.50;// 1.00;
bool   InpUseMixedModeHalfBasketTP       = true;
double InpMixedModeBasketTPMultiplier    = 0.50;
bool   InpUseLowSARScoreHalfBasketTP      = true;
int    InpSARScoreHalfBasketTPMax         = 3;
bool   InpUseSARFlipOppositeBasketHalfTP = true;
double InpSARFlipOppositeBasketTPMultiplier = 0.50;
bool   InpUseBasketHalfTPAfterMinutes = true;
int    InpBasketHalfTPAfterMinutes = 30;
double InpBasketHalfTPAfterMinutesMultiplier = 0.50;

double InpBasketStopLossUSD       = 5;
double InpContinuousTrendBasketSLUSD   = 5;
double InpMediumTrendBasketSLUSD       = 10;
double InpMixedTrendBasketSLUSD        = 10;
double InpDangerModeBasketSLUSD        = 5;
bool   InpUseSimpleSideBasketCloseOnly = false;

bool   InpUseAutoMarketFlowMode        = true;
int    InpMarketFlowLookbackBars       = 60;
int    InpMarketFlowProfitHours        = 6;
int    InpContinuousTrendProfitOrders  = 5;
int    InpContinuousTrendOppProfitMax  = 0;
double InpContinuousTrendMoveRaw       = 500.0;
double InpMediumTrendMinMoveRaw        = 300.0;
double InpMediumTrendMaxMoveRaw        = 600.0;
double InpMixedTrendMinMoveRaw         = 50.0;
double InpMixedTrendMaxMoveRaw         = 300.0;
double InpDangerLast3MoveRaw           = 500.0;
bool   InpAutoModePauseOrdersInDanger  = true;
bool   InpAutoModePauseOrdersInMixed   = true;
bool   InpAutoModeAllowRecoveryMedium  = true;
bool   InpAutoModeAllowRecoveryMixed   = true;
bool   InpAutoModeAllowSARWeakMixed    = false;
bool   InpAutoModeAllowPullbackMixed   = true;
bool   InpUseMarketModeFilterProfiles = true;

bool   InpUseOppositeDirectionProfitPause = false;
int    InpOppositeDirectionProfitStreakOrders = 2;
int    InpOppositeDirectionPauseMinutes = 30;

double InpProfitTargetPercent      = 50.0;
double InpLossStopPercent          = 50.0;
double InpBasketProfitUSD_12_17 = 0.50;//1.00;

bool   InpUseBasketProfitTimeDecay       = false;
int    InpBasketProfitDecayStepMinutes   = 60;
double InpBasketProfitDecayMinMultiplier = 0.10;
bool   InpBasketProfitDecayIncludeGuards = false;

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
double InpBasketDynamicClosePercent       = 50.0;
double InpBasketDynamicMinPeakUSD         = 0.20;

bool   InpUseIndividualProfitProtect      = false;
double InpIndividualProtectActivateUSD    = 0.50;
double InpIndividualProtectCloseAtUSD     = 0.40;
bool   InpUseSARClosedProfitCountProtect = true;
int    InpSARClosedProfitCountStart      = 2;
bool   InpUseMultiIndividualProfitProtect = false;
double InpProtectActivateUSD_1 = 0.30;
double InpProtectCloseAtUSD_1  = 0.10;
double InpProtectActivateUSD_2 = 0.60;
double InpProtectCloseAtUSD_2  = 0.40;
double InpProtectActivateUSD_3 = 0.80;
double InpProtectCloseAtUSD_3  = 0.50;
double InpProtectActivateUSD_4 = 1.50;
double InpProtectCloseAtUSD_4  = 1.00;
double InpProtectActivateUSD_5 = 1.90;
double InpProtectCloseAtUSD_5  = 1.50;
int    InpIndividualProtectPauseMinutes = 5;
bool   InpCloseIfNextCandleNotProfit = false;

bool   InpOpenRecoveryAfterClose  = false;
double InpRecoveryProfitUSD       = 1;//2.00;
bool   InpRecoveryAfterSLReverse  = false;
bool   InpUseRecoveryGapOrders    = true;
bool   InpRecoveryGapMustMatchSARDirection = true;
bool   InpRecoveryGapMustMatchH1Trend = false;
bool   InpKeepPendingRecoveryGapAfterBlock = true;
bool   InpOpenPendingRecoveryWhenSARMatches = true;
double InpRecoveryGapRawPrice     = 100.0;
double InpRecoveryGapLot          = 0.01;
int    InpMaxRecoveryGapOrdersPerSide = 1;
string InpSARSpecialGuardPrefix = "SAR_SPECIAL_GUARD_ORDER_FOR_";
bool   InpSpecialGuardCloseOnlyInProfit = true;
double InpSpecialGuardMinProfitToClose  = 0.01;
string InpSARParentOrderPrefix        = "SAR_PARENT_";
string InpSARRecoveryGapOrderPrefix   = "RG_P";

int    InpStopLossPoints          = 0;
int    InpSlippage                = 30;
int    InpMaxSpreadPoints         = 3000;

bool   InpUseEquityProtection       = false;
bool   InpAutoUseCurrentBalanceBase = true;
double InpManualBaseCapitalUSD      = 20.0;
double InpProtectionBufferUSD      = 0.00;
bool   InpCloseOrdersOnEquityHit    = true;
bool   InpUseDailyProfitLock        = false;
bool   InpCloseOrdersOnProfitLock   = false;
bool   InpPauseAfterProfitTarget    = true;
bool   InpResetEquityStatsEvery6Hours = true;
int    InpEquityResetHours            = 24;
bool   InpUseFixedEquityResetHours    = false;
string InpEquityResetHourList         = "1";
bool   InpResetTradingCycleWithEquity = true;
bool   InpResetEquityStatsOnDeposit = true;
bool   InpCloseOrdersOnDepositReset = false;
bool   InpSendPushNotifications       = true;
bool   InpSendTerminalAlerts          = true;
bool   InpNotifyOnProfitLock          = true;
bool   InpNotifyOnEquityStop          = true;
bool   InpNotifyOnEquityRestart       = true;
bool   InpNotifyOnEAStart             = true;

bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;
double InpMinPriceGap             = 0.00;
bool   InpUseNoNewOrderHours      = true;
string InpNoNewOrderHourList      = "16,17,18,19,20";

bool   InpUseBigCandlePause       = true;
bool   InpBigCandleBlockOppositeDirectionOnly = true;
double InpBigCandleRawDifference  = 300;
int    InpBigCandlePauseMinutes   = 15;
bool   InpUseBigCandleFormationBlock = true;
bool   InpNotifyOnBigCandlePause  = true;
bool   InpDrawBigCandleRedMarker  = true;
int    InpBigCandleMarkerArrowCode = 159;
color  InpBigCandleMarkerColor    = clrRed;
bool   InpUseBigCandleProfitProtect = false;
double InpBigCandleProfitLockPercent = 80.0;
bool   InpBlockRecoveryGapOnBigCandle = true;
int    InpBigCandleRecoveryPauseMinutes = 5;
bool   InpUseLast3CandlesMovePause = true;
double InpLast3CandlesRawDifference = 300.0;
int    InpLast3CandlesPauseMinutes = 5;
bool   InpUseSpikeWickPauseFilter = false;
double InpSpikeWickMinRawPrice    = 30.0;
double InpSpikeWickBodyMaxPercent = 50.0;
double InpSpikeMomentumRangeRawPrice = 500.0;
double InpSpikeMomentumBodyRawPrice  = 100.0;
bool   InpDrawSpikeWickYellowMarker  = true;
int    InpSpikeWickMarkerArrowCode   = 159;
int    InpSpikeWickPauseMinutes   = 15;
bool   InpSpikeWickBlockRecovery  = true;
bool   InpSpikeWickBlockGuard     = true;

double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;
bool   InpUseSARFlipConfirmations = true;
bool   InpUseSAREMAConfirm        = false;
bool   InpUseSARClosedCandleConfirm = true;
bool   InpUseSARPriceDiffConfirm  = true;
bool   InpUseRepeatedPriceGapConfirm = true;
double InpContinuousOrderPriceGap    = 30;
int    InpContinuousOrderLookbackMinutes = 1;
int    InpContinuousOrderGapMinutes  = 1;
double InpSARConfirmPriceDiff     = 50.0;
int    InpSARConfirmMinutes       = 5;
bool   InpUseSARSignalPriceSideFilter = true;
double InpSARSignalPriceSideMinGap    = 0.0;

bool   InpUseEarlyTrend           = false;
int    InpFastEMA                 = 9;
int    InpSlowEMA                 = 21;
int    InpEarlyLookbackCandles    = 10;
double InpMinEarlyBodyMove        = 0.00;
bool   InpCloseOnEarlyReverse     = false;
bool   InpEarlyCloseAnyMagicOrders = true;
bool   InpDrawEarlyArrows         = true;
bool   InpUseFlatMode             = true;
int    InpFlatLookbackCandles     = 5;
double InpFlatMaxEMADistance      = 0.00;
double InpFlatMaxBodyTotal        = 0.00;
int    InpFlatMaxSameColor        = 3;
bool   InpDrawFlatDots            = true;
color  InpFlatDotColor            = clrSilver;

bool   InpDrawSARArrows           = false;
bool   InpDrawSAREveryBarArrows   = false;
int    InpSAREveryBarLookback     = 200;
color  InpBuyColor                = clrLime;
color  InpSellColor               = clrRed;
color  InpEarlyBuyColor           = clrAqua;
color  InpEarlySellColor          = clrOrangeRed;
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
bool   InpDrawSARDots            = true;
int    InpSARDotLookback         = 200;
color  InpSARDotBuyColor         = clrLime;
color  InpSARDotSellColor        = clrOrangeRed;

bool   InpUseSARDurationDynamicLimit = false;
int    InpSARDurationScanBars        = 1500;
int    InpSARVeryLongDurationMinutes = 60;
int    InpSARVeryLongDurationMaxOrders = 4;
int    InpSARDurationLongMinutes     = 30;
int    InpSARLongDurationMaxOrders   = 3;
int    InpSARDurationMediumMinutes   = 10;
int    InpSARMediumDurationMaxOrders = 1;
int    InpSARNormalDurationMaxOrders = 1;
int    InpSARGoodMomentumExtraOrders = 1;
bool   InpResetMaxOrdersWhenSARWeak = false;
bool   InpIncreaseSARMaxAfterActiveMinutes = true;
int    InpSARActiveMinutesForExtraOrders = 60;
int    InpSARActiveExtraOrders = 1;
bool   InpUseSARGoodMomentumMaxUpgrade = false;
double InpSARGoodMomentumMinDotDistance = 300.0;
int    InpSARGoodMomentumADXPeriod = 14;
double InpSARGoodMomentumMinADX = 20.0;
int    InpSARGoodMomentumATRPeriod = 14;
double InpSARGoodMomentumMinATR = 100.0;
int    InpSARGoodMomentumCandleLookback = 3;
int    InpSARGoodMomentumMinSameCandles = 1;

bool   InpUseDynamicSAREngine              = true;
bool   InpBlockNewOrdersWhenSARWeak        = true;
bool   InpBlockFastSARFlip                 = true;
bool   InpUseStrictSARScoreEntry            = true;
int    InpStrictSARMinimumScore             = 6;
bool   InpUseDoubtfulCandleNextConfirm       = true;
double InpDoubtfulOppositeWickMinRaw         = 20.0;
double InpDoubtfulOppositeWickBodyRatio      = 0.70;
double InpDoubtfulMinBodyPercentOfRange      = 35.0;
double InpDoubtfulStrongClosePercent         = 60.0;
bool   InpDoubtfulConfirmMustBreakExtreme    = true;
double InpDoubtfulConfirmBreakBufferRaw      = 0.0;
int    InpDynamicATRPeriod                 = 14;
int    InpDynamicMinSignalMinutes          = 20;
int    InpDynamicVeryStrongMinMinutes      = 10;
double InpDynamicConfirmATRMultiplier      = 0.80;
double InpDynamicStrongDotATRMultiplier    = 1.20;
double InpDynamicWeakDotATRMultiplier      = 0.45;
double InpDynamicEMADistanceATRMultiplier  = 0.10;
double InpDynamicLongBarATRMultiplier      = 1.50;
double InpDynamicOppositeBarATRMultiplier  = 1.20;
double InpDynamicADXStrong                 = 25.0;
double InpDynamicADXWeak                   = 18.0;
int    InpDynamicStrongScore               = 5;
int    InpDynamicVeryStrongScore           = 6;
int    InpDynamicWeakScore                 = 2;

bool   InpUseLateSARCycleEntryBlock       = true;
int    InpLateSARMinAgeMinutes            = 15;
int    InpLateSARMaxWeakScore             = 4;
bool   InpLateSARBlockOnOpposite3Candles  = true;
bool   InpLateSARBlockOnWeakExit          = true;
bool   InpUseEarlySARWeakExit          = true;
bool   InpStopNewOrdersOnSARWeakExit   = true;
bool   InpCloseBasketOnSARWeakExit     = false;
double InpEarlySARWeakExitMinProfitUSD = 1;
double InpEarlySARWeakExitMaxLossUSD   = 5;
double InpEarlySARWeakExitTrailUSD     = 0.75;
int    InpEarlySARWeakExitNeedSignals  = 4;
int    InpEarlySARWeakExitMinAgeMin    = 5;
int    InpEarlySARWeakExitCooldownSec  = 60;
bool   InpUseConfirmedSARWeakBasketClose = false;
int    InpSARWeakCloseRecentBars         = 3;
bool   InpSARWeakCloseProfitBasket       = true;
double InpSARWeakMinProfitToClose        = 0.10;
bool   InpSARWeakCloseOldSmallLoss       = false;
int    InpSARWeakBasketAgeMinutes        = 30;
double InpSARWeakMaxSmallLossToCloseUSD  = 2.00;
bool   InpSARWeakCloseResetCycle         = false;
bool   InpDrawSARWeakSignalMarker         = true;
color  InpSARWeakSignalMarkerColor        = clrViolet;
int    InpSARWeakSignalMarkerArrowCode    = 159;

bool   InpUseGlobalEquityTrailLock      = false;
double InpGlobalEquityTrailStartProfit  = 10.0;
double InpGlobalEquityTrailLockUSD      = 10.0;
int    InpGlobalEquityTrailPauseMinutes = 60;
bool   InpUseOppositeCandleWeakExit     = true;
int    InpWeakExitCandleLookback        = 5;
int    InpWeakExitOppositeMinCandles    = 4;
bool   InpStopRecoveryOnStrongOppMove   = true;
double InpStrongOppMoveBlockRecoveryGap = 300.0;
int    InpMaxTotalOpenOrders            = 0;
bool   InpUseDelayedSARChangeClose          = true;
int    InpCloseOrdersOnNthSARChangeAfterOrder = 10;
bool   InpResetSARCloseCounterOnNewOrder    = true;

bool   InpUseH1TrendFilter = false;
int    InpH1FastEMA = 50;
int    InpH1SlowEMA = 200;
bool   InpOpenExtraOrderOnEarlySameSAR = false;
int    InpEarlySameSARExtraMaxOrders = 1;
bool   InpAddOneOrderWhenSARDistanceH1Same = false;
double InpSARDistanceExtraOrderMin         = 300.0;
int    InpSARDistanceExtraOrders           = 1;

//================ CLEAN PROFIT BOS REENTRY =========================
bool   InpUseCleanProfitBOSReentry          = true;
int    InpCleanProfitBOSLookbackBars        = 20;
double InpCleanProfitBOSRawGap              = 20.0;
int    InpCleanProfitBOSActiveMaxBars       = 10;
int    InpCleanProfitReentryMaxBars         = 3;
bool   InpCleanProfitReentryOnlyNewBar      = true;
double InpCleanProfitNegativeToleranceUSD   = 0.00;

//================ ADAPTIVE LOSS-BASED SIDE TARGET ==================
bool   InpUseAdaptiveLossSideTarget         = true;
double InpAdaptiveLossStepUSD               = 1.00;
double InpAdaptiveBreakEvenLossUSD          = 5.00;
double InpAdaptiveBreakEvenTargetUSD        = 0.00;

//======================== GLOBALS ===================================
int      g_activeSARDirection = 0;
int      g_lastSARDotDirection = 0;
int      g_earlyDirection = 0;
bool     g_sarPausedByEarly = false;
bool     g_firstSARLocked = false;
datetime g_lastBarTime = 0;
datetime g_lastOrderTime = 0;
datetime g_lastAnyOrderCloseTime = 0;
datetime g_activeSARSignalChangeTime = 0;
double   g_activeSARSignalChangePrice = 0.0;
int      g_pendingSARConfirmDirection = 0;
double   g_pendingSARConfirmPrice = 0.0;
datetime g_pendingSARConfirmTime = 0;
datetime g_pendingSARConfirmBarTime = 0;
int      g_sarCycleDirection = 0;
int      g_sarCycleMaxOrders = 1;
int      g_sarCycleOrdersCreated = 0;
datetime g_sarCycleStartTime = 0;
double   g_lastConfirmedOrderPrice = 0.0;
datetime g_lastConfirmedOrderTime = 0;
double   g_lastClosedNormalOrderPrice = 0.0;
datetime g_lastClosedNormalOrderTime = 0;
int      g_lastClosedNormalOrderDirection = 0;
int      g_sarClosedProfitOrdersCount = 0;
string   g_lastOrderOpenReason = "WAIT ORDER";
string   g_lastOrderCloseMessage = "NO CLOSE YET";
datetime g_lastOrderCloseTime = 0;
string   OBJ_PREFIX = "DXB_SAR_CYCLE_";

int      g_autoMarketMode = 0;
string   g_autoMarketModeText = "OFF";
double   g_autoMarketMoveRaw = 0.0;
double   g_autoMarketLast3MoveRaw = 0.0;
int      g_autoMarketBuyProfitCount = 0;
int      g_autoMarketSellProfitCount = 0;
int      g_autoMarketDirection = 0;

bool     g_earlySARWeakExitActive = false;
string   g_earlySARWeakExitReason = "";
double   g_activeBasketPeakProfit = 0.0;
double   g_allBasketPeakProfit = 0.0;
double   g_buyBasketPeakProfit = 0.0;
double   g_sellBasketPeakProfit = 0.0;
datetime g_lastEarlySARWeakExitTime = 0;
int      g_lastEarlySARWeakExitDirection = 0;

bool     g_dailyProfitLock = false;
bool     g_equityProtectionHit = false;
double   g_baseBalance = 0.0;
double   g_lossStopEquityLevel = 0.0;
double   g_profitTargetEquity = 0.0;
double   g_dailyProfitTarget = 0.0;
datetime g_lastEquityStatsResetTime = 0;
int      g_equityDay = -1;

bool     g_bigCandlePause = false;
datetime g_bigCandlePauseUntil = 0;
datetime g_bigCandleBlockBuyUntil = 0;
datetime g_bigCandleBlockSellUntil = 0;
int      g_bigCandlePauseCandleDirection = 0;
double   g_lastBigCandleMove = 0.0;
datetime g_lastBigCandlePauseBarTime = 0;
datetime g_lastBigCandleFormationBarTime = 0;

bool     g_spikeWickPause = false;
datetime g_spikeWickPauseUntil = 0;
datetime g_lastSpikeWickBarTime = 0;
string   g_spikeWickLastReason = "OFF";

int      g_dynamicSARScore = 0;
string   g_dynamicSARDecision = "WAIT";
double   g_dynamicSARRequiredDiff = 0.0;
double   g_dynamicSARDotDistance = 0.0;
double   g_dynamicSARATR = 0.0;
double   g_dynamicSARADX = 0.0;
double   g_dynamicSARLongBarMove = 0.0;

int      g_profitProtectTickets[500];
double   g_profitProtectPeakProfit[500];
int      g_profitProtectCount = 0;
datetime g_profitProtectPauseUntil = 0;

int      g_pendingRecoveryGapDirection = 0;
double   g_pendingRecoveryGapMove = 0.0;
double   g_pendingRecoveryRequiredGap = 0.0;
datetime g_pendingRecoveryGapTime = 0;
string   g_pendingRecoveryGapReason = "NONE";
string   g_lastRecoveryAudit = "NONE";

// Clean BOS / adaptive state
datetime g_dxbCleanTrackerStartTime = 0;
int      g_dxbCleanBOSDirection = 0;
datetime g_dxbCleanBOSTime = 0;
double   g_dxbCleanBOSLevel = 0.0;
double   g_dxbCleanBOSPrice = 0.0;
bool     g_dxbCleanReentryArmed = false;
int      g_dxbCleanReentryDirection = 0;
int      g_dxbCleanReentrySourceTicket = 0;
datetime g_dxbCleanReentryArmTime = 0;
datetime g_dxbCleanReentryArmBarTime = 0;
string   g_dxbCleanReentryStatus = "WAIT CLEAN PROFIT CLOSE";

#define DXB_MARKET_MODE_OFF        0
#define DXB_MARKET_MODE_CONTINUOUS 1
#define DXB_MARKET_MODE_MEDIUM     2
#define DXB_MARKET_MODE_MIXED      3
#define DXB_MARKET_MODE_DANGER     4

//+------------------------------------------------------------------+
string DirectionText(int direction)
{
   if(direction == 1) return("BUY");
   if(direction == -1) return("SELL");
   return("NONE");
}

//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = MathMax(minLot, MathMin(maxLot, lot));
   if(step > 0.0) lot = MathFloor(lot / step) * step;
   return(NormalizeDouble(lot, 2));
}

//+------------------------------------------------------------------+
bool IsSARGuardOrderComment(string c)
{
   return(StringFind(c, InpSARSpecialGuardPrefix) >= 0);
}

bool IsSARParentOrderComment(string c)
{
   return(StringFind(c, InpSARParentOrderPrefix) >= 0);
}

bool IsRecoveryGapOrderComment(string c)
{
   return(StringFind(c, InpSARRecoveryGapOrderPrefix) >= 0 ||
          StringFind(c, "RECOVERY_GAP") >= 0);
}

bool IsRecoveryHedgeOrderComment(string c)
{
   return(StringFind(c, "RECOVERY_HEDGE") >= 0);
}

bool IsSARWeakReverseOrderComment(string c)
{
   return(StringFind(c, "SAR_WEAK_REVERSE") >= 0);
}

bool IsRecoveryOrderSelected()
{
   string c = OrderComment();
   return(IsRecoveryGapOrderComment(c) || IsRecoveryHedgeOrderComment(c) ||
          StringFind(c, "RECOVERY") >= 0);
}

//+------------------------------------------------------------------+
string MakeSARParentOrderComment(string reason)
{
   string c = InpSARParentOrderPrefix + reason;
   if(StringLen(c) > 30) c = StringSubstr(c, 0, 30);
   return(c);
}

//+------------------------------------------------------------------+
int GetSARDotDirection(int shift)
{
   double step = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar = iSAR(Symbol(), Period(), step, maxstep, shift);
   if(sar < Close[shift]) return(1);
   if(sar > Close[shift]) return(-1);
   return(0);
}

int GetSARFlipSignal()
{
   if(Bars < 4) return(0);
   double step = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);
   if(sar1 < Close[1] && sar2 >= Close[2]) return(1);
   if(sar1 > Close[1] && sar2 <= Close[2]) return(-1);
   return(0);
}

//+------------------------------------------------------------------+
double GetDynamicSARATR()
{
   double atr = iATR(Symbol(), Period(), InpDynamicATRPeriod, 1);
   if(atr <= 0.0) atr = iATR(Symbol(), PERIOD_M5, InpDynamicATRPeriod, 1);
   return(atr);
}

int CountDirectionalCandles(int direction, int lookback)
{
   int count = 0;
   for(int i=1; i<=lookback && i<Bars; i++)
   {
      if(direction == 1 && Close[i] > Open[i]) count++;
      if(direction == -1 && Close[i] < Open[i]) count++;
   }
   return(count);
}

bool HasOppositeLongBarDanger(int direction, double atr)
{
   if(direction == 0 || atr <= 0.0 || Bars < 3) return(false);
   double body = MathAbs(Close[1]-Open[1]);
   double range = MathAbs(High[1]-Low[1]);
   int candleDir = Close[1] > Open[1] ? 1 : (Close[1] < Open[1] ? -1 : 0);
   g_dynamicSARLongBarMove = range;
   if(candleDir == -direction && range >= atr * InpDynamicOppositeBarATRMultiplier) return(true);
   if(candleDir == -direction && body >= atr * InpDynamicWeakDotATRMultiplier) return(true);
   return(false);
}

int GetDynamicSARStrengthScore(int direction)
{
   g_dynamicSARScore = 0;
   g_dynamicSARDecision = "WAIT";
   if(direction == 0 || Bars < 50) return(0);
   double atr = GetDynamicSARATR();
   if(atr <= 0.0) return(0);
   double step = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double fast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDistance = MathAbs(fast-slow);
   double adx = iADX(Symbol(), Period(), InpSARGoodMomentumADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double dotDistance = MathAbs(Close[1]-sar1);
   double range = MathAbs(High[1]-Low[1]);
   int score = 0;
   if(direction == 1 && sar1 < Close[1]) score++;
   if(direction == -1 && sar1 > Close[1]) score++;
   if(dotDistance >= atr*InpDynamicStrongDotATRMultiplier) score++;
   if(direction == 1 && fast > slow && emaDistance >= atr*InpDynamicEMADistanceATRMultiplier) score++;
   if(direction == -1 && fast < slow && emaDistance >= atr*InpDynamicEMADistanceATRMultiplier) score++;
   if(adx >= InpDynamicADXStrong) score++;
   if(CountDirectionalCandles(direction,3) >= 2) score++;
   if(direction == 1 && Close[1] > Close[2]) score++;
   if(direction == -1 && Close[1] < Close[2]) score++;
   int candleDir = Close[1] > Open[1] ? 1 : (Close[1] < Open[1] ? -1 : 0);
   if(candleDir == direction && range >= atr*InpDynamicLongBarATRMultiplier) score++;
   if(dotDistance < atr*InpDynamicWeakDotATRMultiplier) score--;
   if(adx < InpDynamicADXWeak) score--;
   if(HasOppositeLongBarDanger(direction,atr)) score -= 2;
   if(score < 0) score = 0;
   g_dynamicSARScore = score;
   g_dynamicSARATR = atr;
   g_dynamicSARADX = adx;
   g_dynamicSARDotDistance = dotDistance;
   return(score);
}

int GetSARSignalAgeMinutes()
{
   if(g_sarCycleStartTime <= 0) return(0);
   return((int)MathMax(0,(TimeCurrent()-g_sarCycleStartTime)/60));
}

bool IsStrictSARScoreAllowedForNewOrder(int direction, string source)
{
   if(!InpUseStrictSARScoreEntry) return(true);
   int score = GetDynamicSARStrengthScore(direction);
   int required = (int)MathMax(0,MathMin(7,InpStrictSARMinimumScore));
   if(score < required)
   {
      g_lastOrderOpenReason = "STRICT SAR SCORE BLOCK " + IntegerToString(score) + "/" + IntegerToString(required) + " | " + source;
      return(false);
   }
   return(true);
}

bool IsDynamicSARAllowedForNewOrder(int direction, string &reason)
{
   reason = "";
   if(!InpUseDynamicSAREngine) return(true);
   int score = GetDynamicSARStrengthScore(direction);
   int age = GetSARSignalAgeMinutes();
   if(HasOppositeLongBarDanger(direction,g_dynamicSARATR))
   {
      reason = "OPPOSITE LONG BAR";
      return(false);
   }
   if(InpBlockFastSARFlip && age < InpDynamicVeryStrongMinMinutes)
   {
      reason = "FAST SAR AGE " + IntegerToString(age);
      return(false);
   }
   if(InpBlockFastSARFlip && age < InpDynamicMinSignalMinutes && score < InpDynamicVeryStrongScore)
   {
      reason = "WAIT AGE/SCORE";
      return(false);
   }
   if(InpBlockNewOrdersWhenSARWeak && score <= InpDynamicWeakScore)
   {
      reason = "WEAK SAR";
      return(false);
   }
   if(score < InpDynamicStrongScore)
   {
      reason = "WAIT STRONG SAR";
      return(false);
   }
   return(true);
}

//+------------------------------------------------------------------+
int CountOrdersByDirection(int direction)
{
   int type = direction == 1 ? OP_BUY : OP_SELL;
   int count = 0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      count++;
   }
   return(count);
}

int CountAllOrders()
{
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      count++;
   }
   return(count);
}

int CountOpenOrders(){ return(CountAllOrders()); }

double GetBasketProfit(int direction)
{
   int type = direction==1 ? OP_BUY : OP_SELL;
   double p=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      p += OrderProfit()+OrderSwap()+OrderCommission();
   }
   return(p);
}

double GetAllOpenEAOrdersProfit()
{
   return(GetBasketProfit(1)+GetBasketProfit(-1));
}

//+------------------------------------------------------------------+
string DXBOrderTrackKey(int ticket,string field)
{
   return("DXB_CT_"+IntegerToString(AccountNumber())+"_"+IntegerToString(InpMagicNumber)+"_"+IntegerToString(ticket)+"_"+field);
}

double DXBNetSelectedOrderProfit()
{
   return(OrderProfit()+OrderSwap()+OrderCommission());
}

void DXBUpdateOrderDrawdownTracking()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      string key=DXBOrderTrackKey(OrderTicket(),"MIN");
      double p=DXBNetSelectedOrderProfit();
      if(!GlobalVariableCheck(key)) GlobalVariableSet(key,p);
      else if(p<GlobalVariableGet(key)) GlobalVariableSet(key,p);
   }
}

double DXBGetTrackedMinimumProfit(int ticket,double fallback)
{
   string key=DXBOrderTrackKey(ticket,"MIN");
   if(!GlobalVariableCheck(key))
   {
      GlobalVariableSet(key,fallback);
      return(fallback);
   }
   return(GlobalVariableGet(key));
}

double DXBGetDeepestTrackedProfitForDirection(int direction)
{
   int type=direction==1?OP_BUY:OP_SELL;
   bool found=false;
   double deepest=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      double minp=DXBGetTrackedMinimumProfit(OrderTicket(),DXBNetSelectedOrderProfit());
      if(!found || minp<deepest){ deepest=minp; found=true; }
   }
   return(found?deepest:0.0);
}

int DXBGetAdaptiveLossTierForDirection(int direction)
{
   if(!InpUseAdaptiveLossSideTarget || direction==0) return(0);
   double step=MathAbs(InpAdaptiveLossStepUSD);
   if(step<=0.0) return(0);
   double deepest=DXBGetDeepestTrackedProfitForDirection(direction);
   if(deepest>-step+0.0000001) return(0);
   return((int)MathMax(1,(int)MathFloor((-deepest+0.0000001)/step)));
}

bool DXBIsAdaptiveBreakEvenActive(int direction)
{
   if(!InpUseAdaptiveLossSideTarget || direction==0) return(false);
   return(DXBGetDeepestTrackedProfitForDirection(direction)<=-MathAbs(InpAdaptiveBreakEvenLossUSD)+0.0000001);
}

double DXBApplyAdaptiveLossTarget(int direction,double target)
{
   if(!InpUseAdaptiveLossSideTarget || CountOrdersByDirection(direction)<=0) return(target);
   if(DXBIsAdaptiveBreakEvenActive(direction)) return(MathMax(0.0,InpAdaptiveBreakEvenTargetUSD));
   int tier=DXBGetAdaptiveLossTierForDirection(direction);
   if(tier<=0) return(target);
   return(MathMax(0.01,MathAbs(target)/(tier+1.0)));
}

string DXBAdaptiveTargetStatusText(int direction)
{
   if(!InpUseAdaptiveLossSideTarget) return("OFF");
   if(CountOrdersByDirection(direction)<=0) return("NO ORDERS");
   double minp=DXBGetDeepestTrackedProfitForDirection(direction);
   if(DXBIsAdaptiveBreakEvenActive(direction)) return("BREAK-EVEN | Min $"+DoubleToString(minp,2));
   int tier=DXBGetAdaptiveLossTierForDirection(direction);
   if(tier<=0) return("NORMAL | Min $"+DoubleToString(minp,2));
   return("TIER "+IntegerToString(tier)+" /"+IntegerToString(tier+1)+" | Min $"+DoubleToString(minp,2));
}

//+------------------------------------------------------------------+
void DXBUpdateCleanProfitBOSState()
{
   if(!InpUseCleanProfitBOSReentry || Bars<InpCleanProfitBOSLookbackBars+5) return;
   int lookback=(int)MathMax(3,InpCleanProfitBOSLookbackBars);
   int hi=iHighest(Symbol(),Period(),MODE_HIGH,lookback,2);
   int lo=iLowest(Symbol(),Period(),MODE_LOW,lookback,2);
   if(hi<0 || lo<0) return;
   double high=High[hi], low=Low[lo], gap=MathMax(0.0,InpCleanProfitBOSRawGap);
   if(Ask>high+gap)
   {
      g_dxbCleanBOSDirection=1; g_dxbCleanBOSTime=Time[0]; g_dxbCleanBOSLevel=high; g_dxbCleanBOSPrice=Ask; return;
   }
   if(Bid<low-gap)
   {
      g_dxbCleanBOSDirection=-1; g_dxbCleanBOSTime=Time[0]; g_dxbCleanBOSLevel=low; g_dxbCleanBOSPrice=Bid; return;
   }
   if(g_dxbCleanBOSTime>0)
   {
      int age=iBarShift(Symbol(),Period(),g_dxbCleanBOSTime,false);
      if(age<0 || age>MathMax(1,InpCleanProfitBOSActiveMaxBars))
      {
         g_dxbCleanBOSDirection=0; g_dxbCleanBOSTime=0; g_dxbCleanBOSLevel=0; g_dxbCleanBOSPrice=0;
      }
   }
}

bool DXBIsCleanBOSActiveForDirection(int direction)
{
   DXBUpdateCleanProfitBOSState();
   if(g_dxbCleanBOSDirection!=direction || g_dxbCleanBOSTime<=0) return(false);
   int age=iBarShift(Symbol(),Period(),g_dxbCleanBOSTime,false);
   return(age>=0 && age<=MathMax(1,InpCleanProfitBOSActiveMaxBars));
}

void DXBClearCleanProfitReentry(string reason)
{
   g_dxbCleanReentryArmed=false;
   g_dxbCleanReentryDirection=0;
   g_dxbCleanReentrySourceTicket=0;
   g_dxbCleanReentryArmTime=0;
   g_dxbCleanReentryArmBarTime=0;
   g_dxbCleanReentryStatus=reason;
}

void DXBArmCleanProfitReentry(int direction,int ticket)
{
   g_dxbCleanReentryArmed=true;
   g_dxbCleanReentryDirection=direction;
   g_dxbCleanReentrySourceTicket=ticket;
   g_dxbCleanReentryArmTime=TimeCurrent();
   g_dxbCleanReentryArmBarTime=Time[0];
   g_dxbCleanReentryStatus="ARMED "+DirectionText(direction)+" FROM #"+IntegerToString(ticket);
   if(g_sarCycleOrdersCreated>=g_sarCycleMaxOrders && g_sarCycleMaxOrders<DXB_HARD_MAX_OPEN_ORDERS)
      g_sarCycleMaxOrders=MathMin(DXB_HARD_MAX_OPEN_ORDERS,g_sarCycleOrdersCreated+1);
}

bool DXBIsEligibleCleanNormalComment(string c)
{
   if(!IsSARParentOrderComment(c)) return(false);
   if(IsRecoveryGapOrderComment(c) || IsRecoveryHedgeOrderComment(c) || IsSARWeakReverseOrderComment(c)) return(false);
   if(StringFind(c,"RECOVERY")>=0 || StringFind(c,"HEDGE")>=0) return(false);
   return(true);
}

void DXBProcessNewClosedOrdersForCleanReentry()
{
   if(!InpUseCleanProfitBOSReentry) return;
   double tolerance=MathAbs(InpCleanProfitNegativeToleranceUSD);
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      int ticket=OrderTicket();
      string done=DXBOrderTrackKey(ticket,"DONE");
      if(GlobalVariableCheck(done)) continue;
      if(OrderCloseTime()<g_dxbCleanTrackerStartTime){ GlobalVariableSet(done,1); continue; }
      string minKey=DXBOrderTrackKey(ticket,"MIN");
      if(!GlobalVariableCheck(minKey)){ GlobalVariableSet(done,1); continue; }
      double minp=GlobalVariableGet(minKey);
      double closed=DXBNetSelectedOrderProfit();
      int direction=OrderType()==OP_BUY?1:-1;
      GlobalVariableSet(done,1);
      bool clean=DXBIsEligibleCleanNormalComment(OrderComment()) && closed>0.0 && minp>=-tolerance-0.0000001;
      if(clean && g_activeSARDirection==direction && DXBIsCleanBOSActiveForDirection(direction))
         DXBArmCleanProfitReentry(direction,ticket);
      if(GlobalVariableCheck(minKey)) GlobalVariableDel(minKey);
   }
}

string DXBCleanProfitReentryStatusText()
{
   return(g_dxbCleanReentryStatus+" | BOS "+DirectionText(g_dxbCleanBOSDirection));
}

//+------------------------------------------------------------------+
void ResetSARFlipConfirmation()
{
   g_pendingSARConfirmDirection=0;
   g_pendingSARConfirmPrice=0.0;
   g_pendingSARConfirmTime=0;
   g_pendingSARConfirmBarTime=0;
}

void StartSARFlipConfirmation(int direction)
{
   g_pendingSARConfirmDirection=direction;
   g_pendingSARConfirmPrice=Close[1];
   g_pendingSARConfirmTime=TimeCurrent();
   g_pendingSARConfirmBarTime=Time[1];
   g_activeSARSignalChangePrice=Close[1];
   g_activeSARSignalChangeTime=TimeCurrent();
}

double GetSARConfirmCurrentPriceDiff()
{
   if(g_pendingSARConfirmDirection==1) return(Close[1]-g_pendingSARConfirmPrice);
   if(g_pendingSARConfirmDirection==-1) return(g_pendingSARConfirmPrice-Close[1]);
   return(0.0);
}

bool IsSARFlipConfirmationReady()
{
   if(!InpUseSARFlipConfirmations || g_pendingSARConfirmDirection==0) return(true);
   int direction=g_pendingSARConfirmDirection;
   if(InpUseSARClosedCandleConfirm && Time[1]<=g_pendingSARConfirmBarTime) return(false);
   if(InpUseSAREMAConfirm)
   {
      double fast=iMA(Symbol(),Period(),InpFastEMA,0,MODE_EMA,PRICE_CLOSE,1);
      double slow=iMA(Symbol(),Period(),InpSlowEMA,0,MODE_EMA,PRICE_CLOSE,1);
      if(direction==1 && fast<=slow) return(false);
      if(direction==-1 && fast>=slow) return(false);
   }
   double required=InpSARConfirmPriceDiff;
   if(InpUseDynamicSAREngine)
   {
      double atr=GetDynamicSARATR();
      if(atr>0.0) required=MathMax(InpSARConfirmPriceDiff*0.35,atr*InpDynamicConfirmATRMultiplier);
   }
   if(InpUseSARPriceDiffConfirm && GetSARConfirmCurrentPriceDiff()<required) return(false);
   return(true);
}

//+------------------------------------------------------------------+
void EnsureSARSignalOrderCycle(int direction)
{
   if(g_sarCycleDirection==direction && g_sarCycleStartTime>0) return;
   g_sarCycleDirection=direction;
   g_sarCycleMaxOrders=(int)MathMax(0,InpSARNormalDurationMaxOrders);
   g_sarCycleOrdersCreated=0;
   g_sarCycleStartTime=TimeCurrent();
   g_lastConfirmedOrderPrice=0;
   g_lastConfirmedOrderTime=0;
   g_lastClosedNormalOrderPrice=0;
   g_lastClosedNormalOrderTime=0;
   g_lastClosedNormalOrderDirection=0;
   g_sarClosedProfitOrdersCount=0;
}

bool RegisterSARCycleOrderCreated(int direction)
{
   EnsureSARSignalOrderCycle(direction);
   if(g_sarCycleOrdersCreated>=g_sarCycleMaxOrders) return(false);
   g_sarCycleOrdersCreated++;
   return(true);
}

//+------------------------------------------------------------------+
datetime GetDubaiTime(){ return(TimeGMT()+4*3600); }

bool IsConfiguredNoNewOrderHour(int hourValue)
{
   string parts[];
   int total=StringSplit(InpNoNewOrderHourList,',',parts);
   for(int i=0;i<total;i++) if((int)StrToInteger(parts[i])==hourValue) return(true);
   return(false);
}

bool IsNoNewOrderHour()
{
   return(InpUseNoNewOrderHours && IsConfiguredNoNewOrderHour(TimeHour(GetDubaiTime())));
}

//+------------------------------------------------------------------+
double GetRecentMarketRawMove(int bars)
{
   int lb=(int)MathMax(5,MathMin(bars,Bars-2));
   int hi=iHighest(Symbol(),PERIOD_M1,MODE_HIGH,lb,1);
   int lo=iLowest(Symbol(),PERIOD_M1,MODE_LOW,lb,1);
   if(hi<0 || lo<0) return(0.0);
   return(MathAbs(iHigh(Symbol(),PERIOD_M1,hi)-iLow(Symbol(),PERIOD_M1,lo)));
}

double GetLastNCandlesRawMove(int bars)
{
   int lb=(int)MathMax(1,MathMin(bars,Bars-2));
   int hi=iHighest(Symbol(),PERIOD_M1,MODE_HIGH,lb,1);
   int lo=iLowest(Symbol(),PERIOD_M1,MODE_LOW,lb,1);
   if(hi<0 || lo<0) return(0.0);
   return(MathAbs(iHigh(Symbol(),PERIOD_M1,hi)-iLow(Symbol(),PERIOD_M1,lo)));
}

void UpdateAutoMarketFlowMode()
{
   if(!InpUseAutoMarketFlowMode){ g_autoMarketMode=DXB_MARKET_MODE_OFF; g_autoMarketModeText="OFF"; return; }
   g_autoMarketMoveRaw=GetRecentMarketRawMove(InpMarketFlowLookbackBars);
   g_autoMarketLast3MoveRaw=GetLastNCandlesRawMove(3);
   if(g_autoMarketLast3MoveRaw>=InpDangerLast3MoveRaw || GetLastNCandlesRawMove(1)>=InpBigCandleRawDifference)
      g_autoMarketMode=DXB_MARKET_MODE_DANGER;
   else if(g_autoMarketMoveRaw>=InpContinuousTrendMoveRaw)
      g_autoMarketMode=DXB_MARKET_MODE_CONTINUOUS;
   else if(g_autoMarketMoveRaw>=InpMediumTrendMinMoveRaw && g_autoMarketMoveRaw<=InpMediumTrendMaxMoveRaw)
      g_autoMarketMode=DXB_MARKET_MODE_MEDIUM;
   else
      g_autoMarketMode=DXB_MARKET_MODE_MIXED;
   if(g_autoMarketMode==DXB_MARKET_MODE_CONTINUOUS) g_autoMarketModeText="CONTINUOUS TREND";
   else if(g_autoMarketMode==DXB_MARKET_MODE_MEDIUM) g_autoMarketModeText="MEDIUM TREND";
   else if(g_autoMarketMode==DXB_MARKET_MODE_MIXED) g_autoMarketModeText="MIXED TREND";
   else g_autoMarketModeText="DANGER SPIKE";
}

bool IsAutoMarketTradingPaused()
{
   if(!InpUseAutoMarketFlowMode) return(false);
   if(g_autoMarketMode==DXB_MARKET_MODE_DANGER && InpAutoModePauseOrdersInDanger) return(true);
   if(g_autoMarketMode==DXB_MARKET_MODE_MIXED && InpAutoModePauseOrdersInMixed) return(true);
   return(false);
}

bool IsAutoMarketRecoveryAllowed()
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(IsAutoMarketTradingPaused()) return(false);
   if(g_autoMarketMode==DXB_MARKET_MODE_CONTINUOUS || g_autoMarketMode==DXB_MARKET_MODE_DANGER) return(false);
   if(g_autoMarketMode==DXB_MARKET_MODE_MEDIUM) return(InpAutoModeAllowRecoveryMedium);
   return(InpAutoModeAllowRecoveryMixed);
}

bool IsAutoMarketPullbackAllowed()
{
   if(!InpUseAutoMarketFlowMode) return(true);
   if(IsAutoMarketTradingPaused()) return(false);
   if(g_autoMarketMode==DXB_MARKET_MODE_DANGER) return(false);
   return(true);
}

//+------------------------------------------------------------------+
double GetBasketProfitTimeDecayMultiplier()
{
   if(!InpUseBasketProfitTimeDecay || g_lastOrderTime<=0) return(1.0);
   int step=(int)MathMax(1,InpBasketProfitDecayStepMinutes);
   int elapsed=(int)((TimeCurrent()-g_lastOrderTime)/60);
   if(elapsed<step) return(1.0);
   int divisor=elapsed/step+1;
   return(MathMax(InpBasketProfitDecayMinMultiplier,1.0/divisor));
}

bool IsMixedModeHalfBasketTPActive()
{
   return(InpUseAutoMarketFlowMode && g_autoMarketMode==DXB_MARKET_MODE_MIXED);
}

bool IsLowSARScoreHalfBasketTPActive()
{
   return(InpUseLowSARScoreHalfBasketTP && g_activeSARDirection!=0 &&
          GetDynamicSARStrengthScore(g_activeSARDirection)<=InpSARScoreHalfBasketTPMax);
}

bool IsFixedHalfBasketTPActive(){ return(IsMixedModeHalfBasketTPActive()||IsLowSARScoreHalfBasketTPActive()); }

double GetBasketProfitTargetUSD()
{
   if(IsFixedHalfBasketTPActive()) return(MathMax(0.01,MathAbs(InpBasketProfitUSD)/2.0));
   double base=InpBasketProfitUSD;
   int hour=TimeHour(TimeCurrent());
   if(hour>=12 && hour<=17) base=InpBasketProfitUSD_12_17;
   return(MathMax(0.01,base*GetBasketProfitTimeDecayMultiplier()));
}

bool IsOppositeBasketAfterSARFlip(int direction)
{
   return(InpUseSARFlipOppositeBasketHalfTP && direction!=0 && g_activeSARDirection!=0 && direction!=g_activeSARDirection);
}

int GetBasketOpenAgeMinutes(int direction)
{
   int type=direction==1?OP_BUY:OP_SELL;
   datetime oldest=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(oldest==0 || OrderOpenTime()<oldest) oldest=OrderOpenTime();
   }
   return(oldest>0?(int)((TimeCurrent()-oldest)/60):0);
}

bool IsBasketHalfTPAfterTime(int direction)
{
   return(InpUseBasketHalfTPAfterMinutes && CountOrdersByDirection(direction)>0 &&
          GetBasketOpenAgeMinutes(direction)>=MathMax(1,InpBasketHalfTPAfterMinutes));
}

double GetBasketProfitTargetForDirection(int direction)
{
   double selected=GetBasketProfitTargetUSD();
   if(IsOppositeBasketAfterSARFlip(direction))
      selected=MathMin(selected,MathMax(0.01,MathAbs(InpBasketProfitUSD)*MathMin(1.0,MathMax(0.0,InpSARFlipOppositeBasketTPMultiplier))));
   if(IsBasketHalfTPAfterTime(direction))
      selected=MathMin(selected,MathMax(0.01,MathAbs(InpBasketProfitUSD)*MathMin(1.0,MathMax(0.0,InpBasketHalfTPAfterMinutesMultiplier))));
   return(DXBApplyAdaptiveLossTarget(direction,selected));
}

double GetEffectiveBasketStopLossUSD()
{
   if(!InpUseAutoMarketFlowMode) return(InpBasketStopLossUSD);
   if(g_autoMarketMode==DXB_MARKET_MODE_CONTINUOUS) return(InpContinuousTrendBasketSLUSD);
   if(g_autoMarketMode==DXB_MARKET_MODE_MEDIUM) return(InpMediumTrendBasketSLUSD);
   if(g_autoMarketMode==DXB_MARKET_MODE_MIXED) return(InpMixedTrendBasketSLUSD);
   if(g_autoMarketMode==DXB_MARKET_MODE_DANGER) return(InpDangerModeBasketSLUSD);
   return(InpBasketStopLossUSD);
}

//+------------------------------------------------------------------+
bool IsBigCandleOrderBlockedForDirection(int direction)
{
   if(!InpUseBigCandlePause) return(false);
   datetime now=TimeCurrent();
   if(now>=g_bigCandlePauseUntil) return(false);
   if(!InpBigCandleBlockOppositeDirectionOnly) return(true);
   if(direction==1 && now<g_bigCandleBlockBuyUntil) return(true);
   if(direction==-1 && now<g_bigCandleBlockSellUntil) return(true);
   return(false);
}

void CheckBigCandlePauseOnNewBar(bool isNewBar)
{
   if(!InpUseBigCandlePause || !isNewBar || Bars<4) return;
   double move=MathAbs(High[1]-Low[1]);
   if(move<InpBigCandleRawDifference) return;
   int dir=Close[1]>Open[1]?1:(Close[1]<Open[1]?-1:0);
   datetime until=TimeCurrent()+MathMax(1,InpBigCandlePauseMinutes)*60;
   g_bigCandlePause=true; g_bigCandlePauseUntil=until; g_bigCandlePauseCandleDirection=dir; g_lastBigCandleMove=move;
   if(!InpBigCandleBlockOppositeDirectionOnly){ g_bigCandleBlockBuyUntil=until; g_bigCandleBlockSellUntil=until; }
   else if(dir==1) g_bigCandleBlockSellUntil=until;
   else if(dir==-1) g_bigCandleBlockBuyUntil=until;
}

//+------------------------------------------------------------------+
bool IsTradingAllowedNow()
{
   if(!IsTradeAllowed() || IsTradeContextBusy()) return(false);
   if(AccountFreeMargin()<=0.0) return(false);
   return(true);
}

bool IsPriceGapValid(int direction,double gap)
{
   int type=direction==1?OP_BUY:OP_SELL;
   double price=direction==1?Ask:Bid;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(MathAbs(price-OrderOpenPrice())<gap) return(false);
   }
   return(true);
}

bool IsRepeatedPriceGapConfirmedForNormalOrder(int direction,string reason)
{
   if(StringFind(reason,"SAR_CLEAN_BOS_REENTRY")>=0) return(true);
   if(!InpUseRepeatedPriceGapConfirm || g_sarCycleOrdersCreated<=0) return(true);
   if(g_lastClosedNormalOrderPrice<=0.0 || g_lastClosedNormalOrderDirection!=direction) return(true);
   if(TimeCurrent()-g_lastClosedNormalOrderTime<MathMax(0,InpContinuousOrderGapMinutes)*60) return(false);
   double live=direction==1?Ask:Bid;
   double gap=direction==1?live-g_lastClosedNormalOrderPrice:g_lastClosedNormalOrderPrice-live;
   return(gap>=InpContinuousOrderPriceGap);
}

bool IsSARSignalPriceSideAllowed(int direction)
{
   if(!InpUseSARSignalPriceSideFilter) return(true);
   if(g_activeSARSignalChangePrice<=0.0) return(false);
   double live=direction==1?Ask:Bid;
   double diff=direction==1?live-g_activeSARSignalChangePrice:g_activeSARSignalChangePrice-live;
   return(diff>=MathMax(0.0,InpSARSignalPriceSideMinGap));
}

bool CanOpenNewOrder(int direction,string reason)
{
   if(direction==0 || !IsTradingAllowedNow()) return(false);
   if(IsNoNewOrderHour()) return(false);
   if(IsAutoMarketTradingPaused()) return(false);
   if(IsBigCandleOrderBlockedForDirection(direction)) return(false);
   if(MarketInfo(Symbol(),MODE_SPREAD)>InpMaxSpreadPoints) return(false);
   if(InpMaxTotalOpenOrders>0 && CountAllOrders()>=InpMaxTotalOpenOrders) return(false);
   if(CountOrdersByDirection(direction)>=InpMaxOrders) return(false);
   EnsureSARSignalOrderCycle(direction);
   if(g_sarCycleOrdersCreated>=g_sarCycleMaxOrders) return(false);
   double minGap=MathMax(InpMinPriceGap,InpMaxOrders>1?InpMinGapWhenMaxOrdersMoreThanOne:0.0);
   if(minGap>0.0 && !IsPriceGapValid(direction,minGap)) return(false);
   if(!IsSARSignalPriceSideAllowed(direction)) return(false);
   if(!IsRepeatedPriceGapConfirmedForNormalOrder(direction,reason)) return(false);
   if(!IsStrictSARScoreAllowedForNewOrder(direction,reason)) return(false);
   string dyn="";
   if(!IsDynamicSARAllowedForNewOrder(direction,dyn)) return(false);
   return(true);
}

//+------------------------------------------------------------------+
color GetOrderColor(int direction,string reason)
{
   if(StringFind(reason,"CLEAN_BOS")>=0) return(direction==1?InpPullbackBuyOrderIconColor:InpPullbackSellOrderIconColor);
   if(StringFind(reason,"RECOVERY")>=0) return(direction==1?InpRecoveryBuyOrderIconColor:InpRecoverySellOrderIconColor);
   return(direction==1?InpNormalBuyOrderIconColor:InpNormalSellOrderIconColor);
}

bool OpenMarketOrder(int direction,string reason)
{
   RefreshRates();
   if(direction!=g_activeSARDirection) return(false);
   if(!CanOpenNewOrder(direction,reason))
   {
      g_lastOrderOpenReason="BLOCKED | "+reason;
      return(false);
   }
   int type=direction==1?OP_BUY:OP_SELL;
   double price=direction==1?Ask:Bid;
   string comment=MakeSARParentOrderComment(reason);
   int ticket=OrderSend(Symbol(),type,NormalizeLot(InpFixedLot),price,InpSlippage,0,0,comment,InpMagicNumber,0,GetOrderColor(direction,reason));
   if(ticket<0)
   {
      g_lastOrderOpenReason="OrderSend error "+IntegerToString(GetLastError());
      ResetLastError();
      return(false);
   }
   g_lastOrderTime=TimeCurrent();
   g_lastConfirmedOrderPrice=price;
   g_lastConfirmedOrderTime=TimeCurrent();
   RegisterSARCycleOrderCreated(direction);
   g_lastOrderOpenReason="OPENED #"+IntegerToString(ticket)+" "+DirectionText(direction)+" | "+reason;
   return(true);
}

bool OpenRecoveryGapMarketOrder(int direction,double gapMove)
{
   if(!InpUseRecoveryGapOrders || !IsAutoMarketRecoveryAllowed()) return(false);
   if(direction!=g_activeSARDirection && InpRecoveryGapMustMatchSARDirection) return(false);
   if(CountOrdersByDirection(direction)<=0) return(false);
   if(MarketInfo(Symbol(),MODE_SPREAD)>InpMaxSpreadPoints) return(false);
   if(IsBigCandleOrderBlockedForDirection(direction)) return(false);
   int existing=0;
   int type=direction==1?OP_BUY:OP_SELL;
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==InpMagicNumber && OrderType()==type && IsRecoveryGapOrderComment(OrderComment())) existing++;
   }
   if(existing>=InpMaxRecoveryGapOrdersPerSide) return(false);
   double price=direction==1?Ask:Bid;
   string c=InpSARRecoveryGapOrderPrefix+IntegerToString(existing+1)+"_"+DirectionText(direction);
   int ticket=OrderSend(Symbol(),type,NormalizeLot(InpRecoveryGapLot),price,InpSlippage,0,0,c,InpMagicNumber,0,GetOrderColor(direction,"RECOVERY"));
   if(ticket<0){ ResetLastError(); return(false); }
   g_lastOrderTime=TimeCurrent();
   g_lastRecoveryAudit="OPENED #"+IntegerToString(ticket)+" Gap="+DoubleToString(gapMove,1);
   return(true);
}

void ProcessRecoveryGapOrders()
{
   if(!InpUseRecoveryGapOrders || !IsAutoMarketRecoveryAllowed()) return;
   RefreshRates();
   for(int d=1;d>=-1;d-=2)
   {
      if(InpRecoveryGapMustMatchSARDirection && d!=g_activeSARDirection) continue;
      int type=d==1?OP_BUY:OP_SELL;
      double base=0.0; datetime oldest=0; int recoveries=0;
      for(int i=OrdersTotal()-1;i>=0;i--)
      {
         if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
         if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
         if(IsSARGuardOrderComment(OrderComment())) continue;
         if(IsRecoveryGapOrderComment(OrderComment())) recoveries++;
         if(oldest==0 || OrderOpenTime()<oldest){ oldest=OrderOpenTime(); base=OrderOpenPrice(); }
      }
      if(oldest==0 || recoveries>=InpMaxRecoveryGapOrdersPerSide) continue;
      double gap=d==1?base-Bid:Ask-base;
      double required=InpRecoveryGapRawPrice*(recoveries+1);
      if(gap>=required && !(InpStopRecoveryOnStrongOppMove && gap>=InpStrongOppMoveBlockRecoveryGap))
      {
         OpenRecoveryGapMarketOrder(d,gap);
         return;
      }
   }
}

//+------------------------------------------------------------------+
void RecordLastClosedNormalOrderReference(int type,double closePrice,string comment)
{
   if(!DXBIsEligibleCleanNormalComment(comment)) return;
   int direction=type==OP_BUY?1:-1;
   if(direction!=g_activeSARDirection) return;
   g_lastClosedNormalOrderPrice=closePrice;
   g_lastClosedNormalOrderTime=TimeCurrent();
   g_lastClosedNormalOrderDirection=direction;
}

void SetLastOrderCloseDashboard(int ticket,int type,double profit,double price,string reason)
{
   g_lastOrderCloseTime=TimeCurrent();
   g_lastOrderCloseMessage="#"+IntegerToString(ticket)+" "+(type==OP_BUY?"BUY":"SELL")+" $"+DoubleToString(profit,2)+" | "+reason;
}

void CloseOrdersByDirection(int direction,string reason)
{
   int type=direction==1?OP_BUY:OP_SELL;
   RefreshRates();
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber || OrderType()!=type) continue;
      if(IsSARGuardOrderComment(OrderComment())) continue;
      int ticket=OrderTicket();
      double p=OrderProfit()+OrderSwap()+OrderCommission();
      double price=type==OP_BUY?Bid:Ask;
      string c=OrderComment();
      if(OrderClose(ticket,OrderLots(),price,InpSlippage,clrWhite))
      {
         g_lastAnyOrderCloseTime=TimeCurrent();
         RecordLastClosedNormalOrderReference(type,price,c);
         SetLastOrderCloseDashboard(ticket,type,p,price,reason);
      }
      else ResetLastError();
   }
}

void CloseAllEAOrders(string reason)
{
   CloseOrdersByDirection(1,reason);
   CloseOrdersByDirection(-1,reason);
}

//+------------------------------------------------------------------+
bool ProcessDirectionWiseBasketClose(string &status)
{
   double sl=MathAbs(GetEffectiveBasketStopLossUSD());
   for(int d=1;d>=-1;d-=2)
   {
      if(CountOrdersByDirection(d)<=0) continue;
      double p=GetBasketProfit(d);
      double target=GetBasketProfitTargetForDirection(d);
      if(sl>0.0 && p<=-sl)
      {
         CloseOrdersByDirection(d,DirectionText(d)+" basket SL");
         status=DirectionText(d)+" BASKET SL";
         return(true);
      }
      if(p>=target)
      {
         string reason=DXBIsAdaptiveBreakEvenActive(d)?"ADAPTIVE BREAK-EVEN":"BASKET TP";
         CloseOrdersByDirection(d,reason+" $"+DoubleToString(p,2));
         status=DirectionText(d)+" "+reason;
         return(true);
      }
   }
   return(false);
}

//+------------------------------------------------------------------+
void UpdateBarAndSARVisualState(bool isNewBar)
{
   int sar=GetSARDotDirection(1);
   if(!g_firstSARLocked && sar!=0)
   {
      g_firstSARLocked=true;
      g_activeSARDirection=sar;
      g_lastSARDotDirection=sar;
      g_activeSARSignalChangePrice=Close[1];
      g_activeSARSignalChangeTime=TimeCurrent();
      EnsureSARSignalOrderCycle(sar);
   }
}

void ProcessSARFlipStateAndClose()
{
   int flip=GetSARFlipSignal();
   if(flip==0 || flip==g_activeSARDirection) return;
   g_activeSARDirection=flip;
   g_lastSARDotDirection=flip;
   g_sarCycleDirection=0;
   EnsureSARSignalOrderCycle(flip);
   StartSARFlipConfirmation(flip);
   if(g_dxbCleanReentryArmed && g_dxbCleanReentryDirection!=flip)
      DXBClearCleanProfitReentry("SAR CHANGED");
}

//+------------------------------------------------------------------+
bool DXBTryOpenCleanProfitBOSReentry(bool isNewBar,string &status)
{
   if(!InpUseCleanProfitBOSReentry || !g_dxbCleanReentryArmed) return(false);
   int d=g_dxbCleanReentryDirection;
   int age=iBarShift(Symbol(),Period(),g_dxbCleanReentryArmTime,false);
   if(age<0 || age>MathMax(1,InpCleanProfitReentryMaxBars)){ DXBClearCleanProfitReentry("EXPIRED"); return(false); }
   if(d!=g_activeSARDirection){ DXBClearCleanProfitReentry("SAR CHANGED"); return(false); }
   if(!DXBIsCleanBOSActiveForDirection(d)){ status="CLEAN REENTRY WAIT BOS"; return(false); }
   if(InpCleanProfitReentryOnlyNewBar && (!isNewBar || Time[0]==g_dxbCleanReentryArmBarTime))
   {
      status="CLEAN REENTRY WAIT NEXT BAR";
      return(false);
   }
   int src=g_dxbCleanReentrySourceTicket;
   if(OpenMarketOrder(d,"SAR_CLEAN_BOS_REENTRY"))
   {
      status="CLEAN BOS REENTRY "+DirectionText(d)+" FROM #"+IntegerToString(src);
      DXBClearCleanProfitReentry(status);
      return(true);
   }
   status="CLEAN REENTRY BLOCKED | "+g_lastOrderOpenReason;
   return(false);
}

bool ProcessNewOrderCreationLast(bool isNewBar,string &status)
{
   if(g_activeSARDirection==0){ status="WAIT SAR"; return(false); }
   if(g_pendingSARConfirmDirection!=0)
   {
      if(!IsSARFlipConfirmationReady()){ status="WAIT SAR CONFIRM"; return(false); }
      ResetSARFlipConfirmation();
   }
   if(InpOneOrderPerBar && !isNewBar){ status="WAIT NEW BAR"; return(false); }
   if(OpenMarketOrder(g_activeSARDirection,"SAR_FLIP_V2LAST"))
   {
      status="ACTIVE "+DirectionText(g_activeSARDirection);
      return(true);
   }
   status=g_lastOrderOpenReason;
   return(false);
}

//+------------------------------------------------------------------+
void InitializeEquityDay()
{
   g_equityDay=TimeDay(TimeCurrent());
   g_baseBalance=InpAutoUseCurrentBalanceBase?AccountBalance():InpManualBaseCapitalUSD;
   if(g_baseBalance<=0.0) g_baseBalance=AccountBalance();
   g_dailyProfitTarget=g_baseBalance*InpProfitTargetPercent/100.0;
   g_profitTargetEquity=g_baseBalance+g_dailyProfitTarget;
   g_lossStopEquityLevel=MathMax(0.0,g_baseBalance-g_baseBalance*InpLossStopPercent/100.0-InpProtectionBufferUSD);
   g_dailyProfitLock=false;
   g_equityProtectionHit=false;
   g_lastEquityStatsResetTime=TimeCurrent();
}

bool CheckEquityConditions()
{
   if(InpUseEquityProtection && AccountEquity()<=g_lossStopEquityLevel)
   {
      g_equityProtectionHit=true;
      if(InpCloseOrdersOnEquityHit) CloseAllEAOrders("EQUITY PROTECTION");
      return(true);
   }
   if(InpUseDailyProfitLock && AccountEquity()>=g_profitTargetEquity)
   {
      g_dailyProfitLock=true;
      if(InpCloseOrdersOnProfitLock) CloseAllEAOrders("DAILY PROFIT LOCK");
      return(InpPauseAfterProfitTarget);
   }
   return(false);
}

//+------------------------------------------------------------------+
void DrawSARDots()
{
   if(!InpDrawSARDots) return;
   double step=InpSARPeriod*InpSARStepSize/10000.0;
   double maxstep=step*InpSARAcceleration;
   int lookback=(int)MathMin(InpSARDotLookback,Bars-1);
   for(int i=0;i<lookback;i++)
   {
      double sar=iSAR(Symbol(),Period(),step,maxstep,i);
      string name=OBJ_PREFIX+"SAR_DOT_"+IntegerToString(i);
      if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_ARROW,0,Time[i],sar);
      else ObjectMove(0,name,0,Time[i],sar);
      ObjectSetInteger(0,name,OBJPROP_ARROWCODE,159);
      ObjectSetInteger(0,name,OBJPROP_COLOR,sar<Close[i]?InpSARDotBuyColor:InpSARDotSellColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   }
}

void DrawDashboard(string status)
{
   Comment(
      InpEAName," | VERSION 1.34\n",
      "Status: ",status,"\n",
      "SAR: ",DirectionText(g_activeSARDirection)," | Score ",IntegerToString(g_dynamicSARScore),"\n",
      "BUY P/L: $",DoubleToString(GetBasketProfit(1),2)," | Target $",DoubleToString(GetBasketProfitTargetForDirection(1),2)," | ",DXBAdaptiveTargetStatusText(1),"\n",
      "SELL P/L: $",DoubleToString(GetBasketProfit(-1),2)," | Target $",DoubleToString(GetBasketProfitTargetForDirection(-1),2)," | ",DXBAdaptiveTargetStatusText(-1),"\n",
      "Clean Reentry: ",DXBCleanProfitReentryStatusText(),"\n",
      "Last Open: ",g_lastOrderOpenReason,"\n",
      "Last Close: ",g_lastOrderCloseMessage,"\n",
      "Mode: ",g_autoMarketModeText," | Move ",DoubleToString(g_autoMarketMoveRaw,0),"\n",
      "Dubai: ",TimeToString(GetDubaiTime(),TIME_MINUTES)," | No-New ",InpNoNewOrderHourList
   );
}

//+------------------------------------------------------------------+
int OnInit()
{
   InpMagicNumber=AccountNumber()+202;
   InitializeEquityDay();
   g_dxbCleanTrackerStartTime=TimeCurrent();
   DXBUpdateOrderDrawdownTracking();
   DXBUpdateCleanProfitBOSState();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   Comment("");
}

void OnTick()
{
   RefreshRates();
   DXBUpdateOrderDrawdownTracking();
   DXBUpdateCleanProfitBOSState();
   UpdateAutoMarketFlowMode();
   DrawSARDots();

   bool isNewBar=(Time[0]!=g_lastBarTime);
   if(isNewBar) g_lastBarTime=Time[0];
   CheckBigCandlePauseOnNewBar(isNewBar);

   string status="RUNNING";
   if(CheckEquityConditions()){ DrawDashboard("EQUITY/DAILY LOCK"); return; }

   bool closedThisTick=ProcessDirectionWiseBasketClose(status);

   UpdateBarAndSARVisualState(isNewBar);
   ProcessSARFlipStateAndClose();
   DXBUpdateCleanProfitBOSState();
   DXBProcessNewClosedOrdersForCleanReentry();

   if(!closedThisTick && CountOpenOrders()>0) ProcessRecoveryGapOrders();

   bool openedClean=false;
   if(!closedThisTick && g_dxbCleanReentryArmed)
      openedClean=DXBTryOpenCleanProfitBOSReentry(isNewBar,status);

   if(!closedThisTick && !openedClean && !g_dxbCleanReentryArmed)
      ProcessNewOrderCreationLast(isNewBar,status);

   DrawDashboard(status);
}
//+------------------------------------------------------------------+
