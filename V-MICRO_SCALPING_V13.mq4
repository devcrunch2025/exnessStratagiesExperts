//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict



/*
   BTCUSD 50-TYPE MOMENTUM BASKET EA
   ------------------------------------------------------------
   TYPE 1 = BIG REVERSAL
      BIG UP   -> BIG_SELL
      BIG DOWN -> BIG_BUY

   TYPE 2 = RANGE RECOVERY
      Small oscillation range -> RANGE_BUY / RANGE_SELL

   TYPE 3 = TREND CONTINUATION
      M5 EMA trend -> TREND_BUY / TREND_SELL

   TYPE 4 = FAKE BREAKOUT
      Break high and close back below -> FAKE_SELL
      Break low and close back above  -> FAKE_BUY

   TYPE 5 = COMPRESSION BREAKOUT
      Low ATR/compression, then breakout -> SQUEEZE_BUY / SQUEEZE_SELL

   TYPE 6 = LIQUIDITY SWEEP
      Big upper wick -> SWEEP_SELL
      Big lower wick -> SWEEP_BUY

   TYPE 7 = TREND EXHAUSTION
      Weakening uptrend -> EXHAUST_SELL
      Weakening downtrend -> EXHAUST_BUY

   TYPE 8 = SESSION MODE

   TYPE 9-50 = ADVANCED BTC MARKET STATE MODULES
      Asian  -> RANGE priority
      London -> FAKE/SWEEP priority
      NY     -> TREND/BIG priority

   IMPORTANT:
   - Each type has separate BUY/SELL baskets by comment.
   - Recovery is allowed only when current market mode matches basket mode.
   - Each basket closes separately by TP/SL.
   - Designed for BTCUSD/BTCUSDm M1 chart.
*/

extern double BaseLot = 0.01;
extern int    MagicNumber = 20260522;

// ================================================================
//  BASKET TP / SL
// ================================================================
extern double BigBasketTPUSD      = 0.50;
extern double BigBasketSLUSD      = -20.00;

extern double RangeBasketTPUSD    = 0.50;
extern double RangeBasketSLUSD    = -20.00;

extern double TrendBasketTPUSD    = 0.50;
extern double TrendBasketSLUSD    = -20.00;

extern double FakeBasketTPUSD     = 0.50;
extern double FakeBasketSLUSD     = -20.00;

extern double SqueezeBasketTPUSD  = 0.50;
extern double SqueezeBasketSLUSD  = -20.00;

extern double SweepBasketTPUSD    = 0.50;
extern double SweepBasketSLUSD    = -20.00;

extern double ExhaustBasketTPUSD  = 0.50;
extern double ExhaustBasketSLUSD  = -20.00;

extern bool   UseGlobalBasketClose = true;

extern double GlobalBasketTPUSD = 0.50;
extern double GlobalBasketSLUSD = -20.00;

// ================================================================
//  MAX ORDERS PER BASKET SIDE
// ================================================================
extern int MaxBigOrdersPerSide     = 2;
extern int MaxRangeOrdersPerSide   = 5;
extern int MaxTrendOrdersPerSide   = 5;
extern int MaxFakeOrdersPerSide    = 2;
extern int MaxSqueezeOrdersPerSide = 3;
extern int MaxSweepOrdersPerSide   = 2;
extern int MaxExhaustOrdersPerSide = 3;

// ================================================================
//  BASIC SETTINGS
// ================================================================
extern int MaxSpreadPoints = 5000;
extern int Slippage = 100;

extern ENUM_TIMEFRAMES TradeTF = PERIOD_M1;
extern ENUM_TIMEFRAMES TrendTF = PERIOD_M5;

extern double MinCandleSize = 20.0;
extern double MaxTrendOrderCandleSize = 100.0;

// ================================================================
//  EMA TREND
// ================================================================
extern int TrendFastEMA = 9;
extern int TrendSlowEMA = 21;
extern double MinTrendEMAGap = 30.0;

// ================================================================
//  TYPE ENABLE/DISABLE
// ================================================================
extern bool UseBigMomentum       = true;
extern bool UseRangeMomentum     = true;
extern bool UseTrendMomentum     = true;
extern bool UseFakeBreakout      = true;
extern bool UseCompressionBreak  = true;
extern bool UseLiquiditySweep    = true;
extern bool UseTrendExhaustion   = true;
extern bool UseSessionMode       = true;

// ================================================================
//  TYPE 1 BIG REVERSAL
// ================================================================
extern int    BigMoveLookbackBars = 3;
extern double BigMoveMinPrice = 150.0;
extern double BigMomentumLot = 0.01;
extern bool   OnlyOneBigMoveOrderPerBar = true;

// ================================================================
//  TYPE 2 RANGE
// ================================================================
extern int    RangeLookbackBars = 5;
extern double RangeMinPrice = 50.0;
extern double RangeMaxPrice = 180.0;
extern double RangeOrderGapPrice = 80.0;

// ================================================================
//  TYPE 3 TREND
// ================================================================
extern double TrendOrderGapPrice = 150.0;

// ================================================================
//  TYPE 4 FAKE BREAKOUT
// ================================================================
extern int    FakeBreakLookbackBars = 5;
extern double FakeBreakBufferPrice = 20.0;
extern double FakeBreakLot = 0.01;

// ================================================================
//  TYPE 5 COMPRESSION BREAKOUT
// ================================================================
extern int    CompressionATRPeriod = 14;
extern double CompressionATRMax = 45.0;
extern double CompressionBreakBuffer = 30.0;
extern double SqueezeLot = 0.01;

// ================================================================
//  TYPE 6 LIQUIDITY SWEEP
// ================================================================
extern double SweepWickBodyRatio = 2.0;
extern double SweepMinWickSize = 80.0;
extern double SweepLot = 0.01;

// ================================================================
//  TYPE 7 TREND EXHAUSTION
// ================================================================
extern double ExhaustLot = 0.01;
extern int    ExhaustBars = 3;

// ================================================================
//  TYPE 8 SESSION MODE - server time
// ================================================================
extern int AsianStartHour  = 0;
extern int AsianEndHour    = 8;
extern int LondonStartHour = 8;
extern int LondonEndHour   = 14;
extern int NYStartHour     = 14;
extern int NYEndHour       = 23;


// ================================================================
//  TYPES 9-50 ADVANCED BTC MARKET STATE ENGINE
// ================================================================
extern bool   UseAdvancedTypes9To50 = true;
extern double AdvancedBasketTPUSD   = 0.50;
extern double AdvancedBasketSLUSD   = -10.00;
extern int    MaxAdvancedOrdersPerSide = 2;
extern double AdvancedLot = 0.01;
extern double AdvancedOrderGapPrice = 250.0;

// Type 21 intraday profit booker
extern bool   UseType21IntradayBooker = true;
extern double DayBasketTPUSD = 5.00;
extern double DayBasketSLUSD = -20.00;
extern double DayLot = 0.01;
extern int    DayMaxHoldMinutes = 480;
extern ENUM_TIMEFRAMES DayTrendTF1 = PERIOD_H1;
extern ENUM_TIMEFRAMES DayTrendTF2 = PERIOD_M15;

// Type 49 dead zone protection
extern bool   BlockTradingInDeadZone = true;
extern double DeadZoneATRMax = 25.0;

// Advanced volatility settings
extern double VolExpansionRatio = 1.80;
extern double VolCollapseRatio  = 0.50;
extern double RoundNumberStep   = 500.0;
extern double RoundNumberBuffer = 60.0;
extern int    EMACrossLookbackBars = 10;
extern int    MaxCrossesForNoise = 4;

// ================================================================
//  RECOVERY
// ================================================================
extern bool   UseRecoveryOrders = true;
extern double RecoveryGapPrice = 100.0;
extern int    MaxRecoveryOrdersPerBasket = 2;
extern bool   RecoverySameDirection = true;


// ================================================================
//  SAME TYPE + SAME DIRECTION COOLDOWN
// ================================================================
extern bool UseSameBasketCooldown = false;
extern int  SameBasketCooldownSeconds = 120;

// ================================================================
//  SAFETY
// ================================================================
extern bool UseEquityProtection = false;
extern double MinEquityPercent = 60.0;


// ================================================================
//  PROFESSIONAL RISK GATE - BEFORE ANY ORDER
// ================================================================
extern bool   UseProfessionalRiskGate = true;

// Higher timeframe confirmation
extern ENUM_TIMEFRAMES HTFTrendTF = PERIOD_M15;
extern int    HTFFastEMA = 9;
extern int    HTFSlowEMA = 21;
extern double MinHTFEMAGap = 50.0;

// Avoid chasing price too far from EMA
extern double MaxDistanceFromM5EMA = 1200.0;

// ATR spike protection
extern int    ATRPeriod = 14;
extern double MaxATRForNewOrder = 900.0;
extern double MinATRForNewOrder = 20.0;

// Confirmation score
extern int    MinOrderQualityScore = 3;

// Loss memory protection
extern bool   UseLossMemoryBlock = true;
extern double LossMemoryTriggerUSD = -10.0;
extern int    LossMemoryPauseBars = 5;

datetime lastLossMemoryTime = 0;
string   lastLossMemoryBasket = "";

// ================================================================
//  DASHBOARD + EMA
// ================================================================
extern bool DrawEMALines = true;
extern int  EMABarsToDraw = 120;
extern color EMAFastColor = clrLime;
extern color EMASlowColor = clrRed;

// ================================================================
//  GLOBALS
// ================================================================
datetime lastBarTime = 0;
datetime lastBigMoveBarTime = 0;
datetime lastBigMoveTradeTime = 0;
int      lastBigMoveDirection = 0;

#define MODE_NONE     0
#define MODE_BIG      1
#define MODE_RANGE    2
#define MODE_TREND    3
#define MODE_FAKE     4
#define MODE_SQUEEZE  5
#define MODE_SWEEP    6
#define MODE_EXHAUST  7
#define MODE_VOL_EXPANSION        9
#define MODE_VOL_COLLAPSE         10
#define MODE_EMA_RECLAIM          11
#define MODE_PARABOLIC_SPIKE      12
#define MODE_ORDER_BLOCK_RETEST   13
#define MODE_LIQUIDITY_VOID       14
#define MODE_STOP_HUNT_ENGINE     15
#define MODE_TREND_STAIRCASE      16
#define MODE_NEWS_CHAOS           17
#define MODE_HEDGE_TRAP           18
#define MODE_TREND_FAILURE        19
#define MODE_ACCUMULATION         20
#define MODE_INTRADAY_BOOKER      21
#define MODE_WEEKEND_TRAP         22
#define MODE_MONDAY_RESET         23
#define MODE_DAILY_OPEN_REJECT    24
#define MODE_PRE_NY_ACCUM         25
#define MODE_POST_LIQ_REVERSAL    26
#define MODE_FUNDING_FLIP         27
#define MODE_WHALE_DEFENSE        28
#define MODE_LIQUIDITY_MAGNET     29
#define MODE_EMA_PINBALL          30
#define MODE_CASCADE_LIQ          31
#define MODE_MICRO_CHANNEL        32
#define MODE_BREAK_FAIL_RETEST    33
#define MODE_DOUBLE_SWEEP         34
#define MODE_ASIAN_RANGE_EXP      35
#define MODE_HFT_NOISE            36
#define MODE_BTC_DOMINANCE        37
#define MODE_CORRELATION_BREAK    38
#define MODE_NEWS_ABSORPTION      39
#define MODE_DELAYED_REVERSAL     40
#define MODE_LIQUIDITY_LADDER     41
#define MODE_ROUND_NUMBER_MAGNET  42
#define MODE_MIDNIGHT_FLUSH       43
#define MODE_TREND_ACCELERATION   44
#define MODE_EXCHANGE_ARBITRAGE   45
#define MODE_MTF_CONFLICT         46
#define MODE_SESSION_TRANSITION   47
#define MODE_RETAIL_TRAP_SEQUENCE 48
#define MODE_DEAD_ZONE            49
#define MODE_DISTRIBUTION         50

//+------------------------------------------------------------------+
//| Higher timeframe trend direction                                |
//+------------------------------------------------------------------+
int GetHTFTrendDirection()
{
   double emaFast = iMA(Symbol(), HTFTrendTF,
                        HTFFastEMA, 0,
                        MODE_EMA,
                        PRICE_CLOSE, 1);

   double emaSlow = iMA(Symbol(), HTFTrendTF,
                        HTFSlowEMA, 0,
                        MODE_EMA,
                        PRICE_CLOSE, 1);

   double close1 = iClose(Symbol(), HTFTrendTF, 1);

   if(emaFast <= 0 || emaSlow <= 0)
      return 0;

   double gap = MathAbs(emaFast - emaSlow);

   if(gap < MinHTFEMAGap)
      return 0;

   if(close1 > emaFast && emaFast > emaSlow)
      return 1;

   if(close1 < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Professional risk gate before ALL orders                        |
//+------------------------------------------------------------------+
bool CanCreateProfessionalOrder(int type, string commentText)
{
   if(!UseProfessionalRiskGate)
      return true;

   // Spread filter
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpreadPoints)
      return false;

   // ATR filter
   double atr = iATR(Symbol(), TradeTF, ATRPeriod, 1);

   if(atr > MaxATRForNewOrder)
   {
      Print("BLOCKED: ATR too high");
      return false;
   }

   if(atr < MinATRForNewOrder)
   {
      Print("BLOCKED: ATR too low");
      return false;
   }

   // Avoid chasing huge BTC moves
   double ema = iMA(Symbol(),
                    TrendTF,
                    TrendSlowEMA,
                    0,
                    MODE_EMA,
                    PRICE_CLOSE,
                    1);

   double dist = MathAbs(Bid - ema);

   if(dist > MaxDistanceFromM5EMA)
   {
      Print("BLOCKED: price too far from EMA");
      return false;
   }

   // Higher timeframe trend
   int htfTrend = GetHTFTrendDirection();

   // Block weak counter-trend entries
   if(htfTrend == 1 && type == OP_SELL)
   {
      // allow only strong reversal situations
      if(!(IsLiquiditySweepUp()
         || IsFakeBreakoutUp()
         || IsTrendExhaustionUp()))
      {
         Print("BLOCKED: strong HTF BUY trend");
         return false;
      }
   }

   if(htfTrend == -1 && type == OP_BUY)
   {
      if(!(IsLiquiditySweepDown()
         || IsFakeBreakoutDown()
         || IsTrendExhaustionDown()))
      {
         Print("BLOCKED: strong HTF SELL trend");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| TYPES 9-50 ADVANCED BTC MARKET STATE ENGINE - FULL BODIES        |
//+------------------------------------------------------------------+
int DetectAdvancedMarketMode()
{
   if(!UseAdvancedTypes9To50)
      return MODE_NONE;

   if(IsDeadZone())                  return MODE_DEAD_ZONE;
   if(IsNewsChaosMode())             return MODE_NEWS_CHAOS;
   if(IsHFTNoiseMode())              return MODE_HFT_NOISE;
   if(IsMTFConflict())               return MODE_MTF_CONFLICT;

   if(IsVolatilityExpansion())       return MODE_VOL_EXPANSION;
   if(IsVolatilityCollapse())        return MODE_VOL_COLLAPSE;

   if(IsEMAReclaimBuy() || IsEMAReclaimSell())
      return MODE_EMA_RECLAIM;

   if(IsParabolicSpikeUp() || IsParabolicSpikeDown())
      return MODE_PARABOLIC_SPIKE;

   if(IsOrderBlockRetestBuy() || IsOrderBlockRetestSell())
      return MODE_ORDER_BLOCK_RETEST;

   if(IsLiquidityVoidUp() || IsLiquidityVoidDown())
      return MODE_LIQUIDITY_VOID;

   if(IsStopHuntUp() || IsStopHuntDown())
      return MODE_STOP_HUNT_ENGINE;

   if(IsTrendStaircaseBuy() || IsTrendStaircaseSell())
      return MODE_TREND_STAIRCASE;

   if(IsTrendFailureBuy() || IsTrendFailureSell())
      return MODE_TREND_FAILURE;

   if(IsAccumulationMode())          return MODE_ACCUMULATION;
   if(IsIntradayBookerMode())        return MODE_INTRADAY_BOOKER;
   if(IsWeekendTrap())               return MODE_WEEKEND_TRAP;
   if(IsMondayReset())               return MODE_MONDAY_RESET;

   if(IsDailyOpenRejectionBuy() || IsDailyOpenRejectionSell())
      return MODE_DAILY_OPEN_REJECT;

   if(IsPreNYAccumulation())         return MODE_PRE_NY_ACCUM;

   if(IsPostLiquidationReversalBuy() || IsPostLiquidationReversalSell())
      return MODE_POST_LIQ_REVERSAL;

   if(IsFundingFlipMode())           return MODE_FUNDING_FLIP;

   if(IsWhaleDefenseBuy() || IsWhaleDefenseSell())
      return MODE_WHALE_DEFENSE;

   if(IsLiquidityMagnetBuy() || IsLiquidityMagnetSell())
      return MODE_LIQUIDITY_MAGNET;

   if(IsEMAPinball())                return MODE_EMA_PINBALL;

   if(IsCascadeLiquidationUp() || IsCascadeLiquidationDown())
      return MODE_CASCADE_LIQ;

   if(IsMicroChannelBuy() || IsMicroChannelSell())
      return MODE_MICRO_CHANNEL;

   if(IsBreakoutFailureRetestBuy() || IsBreakoutFailureRetestSell())
      return MODE_BREAK_FAIL_RETEST;

   if(IsDoubleSweep())               return MODE_DOUBLE_SWEEP;
   if(IsAsianRangeExpansion())       return MODE_ASIAN_RANGE_EXP;
   if(IsBTCDominanceProxy())         return MODE_BTC_DOMINANCE;
   if(IsCorrelationBreakProxy())     return MODE_CORRELATION_BREAK;
   if(IsNewsAbsorption())            return MODE_NEWS_ABSORPTION;

   if(IsDelayedReversalBuy() || IsDelayedReversalSell())
      return MODE_DELAYED_REVERSAL;

   if(IsLiquidityLadderBuy() || IsLiquidityLadderSell())
      return MODE_LIQUIDITY_LADDER;

   if(IsRoundNumberMagnet())         return MODE_ROUND_NUMBER_MAGNET;

   if(IsMidnightFlushBuy() || IsMidnightFlushSell())
      return MODE_MIDNIGHT_FLUSH;

   if(IsTrendAccelerationBuy() || IsTrendAccelerationSell())
      return MODE_TREND_ACCELERATION;

   if(IsExchangeArbitrageProxy())    return MODE_EXCHANGE_ARBITRAGE;
   if(IsSessionTransitionChaos())    return MODE_SESSION_TRANSITION;

   if(IsRetailTrapSequenceBuy() || IsRetailTrapSequenceSell())
      return MODE_RETAIL_TRAP_SEQUENCE;

   if(IsDistributionMode())          return MODE_DISTRIBUTION;

   return MODE_NONE;
}

//+------------------------------------------------------------------+
void ProcessAdvancedType(int mode)
{
   if(mode == MODE_DEAD_ZONE && BlockTradingInDeadZone)
   {
      Print("TYPE 49 DEAD ZONE: trading blocked.");
      return;
   }

   if(mode == MODE_NEWS_CHAOS ||
      mode == MODE_HFT_NOISE ||
      mode == MODE_MTF_CONFLICT ||
      mode == MODE_SESSION_TRANSITION ||
      mode == MODE_EXCHANGE_ARBITRAGE)
   {
      Print("Advanced mode detected but trading blocked for safety. Mode=", mode);
      return;
   }

   int direction = GetAdvancedDirection(mode);

   if(direction == 0)
      return;

   string commentText;

   if(direction == 1)
      commentText = GetAdvancedBuyComment(mode);
   else
      commentText = GetAdvancedSellComment(mode);

   if(CountOrdersByComment(commentText) >= GetAdvancedMaxOrders(mode))
      return;

   if(!CanOpenByGap(commentText, AdvancedOrderGapPrice))
      return;

   double lot = GetAdvancedLot(mode);

   if(direction == 1)
      OpenOrder(OP_BUY, lot, commentText);
   else
      OpenOrder(OP_SELL, lot, commentText);
}

//+------------------------------------------------------------------+
int GetAdvancedDirection(int mode)
{
   if(mode == MODE_VOL_EXPANSION)        return GetTrendDirection();
   if(mode == MODE_VOL_COLLAPSE)         return GetLastCandleDirection();
   if(mode == MODE_EMA_RECLAIM)          return IsEMAReclaimBuy() ? 1 : (IsEMAReclaimSell() ? -1 : 0);
   if(mode == MODE_PARABOLIC_SPIKE)      return IsParabolicSpikeUp() ? -1 : (IsParabolicSpikeDown() ? 1 : 0);
   if(mode == MODE_ORDER_BLOCK_RETEST)   return IsOrderBlockRetestBuy() ? 1 : (IsOrderBlockRetestSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_VOID)       return IsLiquidityVoidUp() ? -1 : (IsLiquidityVoidDown() ? 1 : 0);
   if(mode == MODE_STOP_HUNT_ENGINE)     return IsStopHuntUp() ? -1 : (IsStopHuntDown() ? 1 : 0);
   if(mode == MODE_TREND_STAIRCASE)      return IsTrendStaircaseBuy() ? 1 : (IsTrendStaircaseSell() ? -1 : 0);
   if(mode == MODE_TREND_FAILURE)        return IsTrendFailureBuy() ? -1 : (IsTrendFailureSell() ? 1 : 0);
   if(mode == MODE_INTRADAY_BOOKER)      return GetType21DaySignal();
   if(mode == MODE_WEEKEND_TRAP)         return -GetLastCandleDirection();
   if(mode == MODE_MONDAY_RESET)         return -GetLastCandleDirection();
   if(mode == MODE_DAILY_OPEN_REJECT)    return IsDailyOpenRejectionBuy() ? 1 : (IsDailyOpenRejectionSell() ? -1 : 0);
   if(mode == MODE_POST_LIQ_REVERSAL)    return IsPostLiquidationReversalBuy() ? 1 : (IsPostLiquidationReversalSell() ? -1 : 0);
   if(mode == MODE_FUNDING_FLIP)         return -GetLastCandleDirection();
   if(mode == MODE_WHALE_DEFENSE)        return IsWhaleDefenseBuy() ? 1 : (IsWhaleDefenseSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_MAGNET)     return IsLiquidityMagnetBuy() ? 1 : (IsLiquidityMagnetSell() ? -1 : 0);
   if(mode == MODE_EMA_PINBALL)          return GetEMAPinballDirection();
   if(mode == MODE_CASCADE_LIQ)          return IsCascadeLiquidationUp() ? 1 : (IsCascadeLiquidationDown() ? -1 : 0);
   if(mode == MODE_MICRO_CHANNEL)        return IsMicroChannelBuy() ? 1 : (IsMicroChannelSell() ? -1 : 0);
   if(mode == MODE_BREAK_FAIL_RETEST)    return IsBreakoutFailureRetestBuy() ? 1 : (IsBreakoutFailureRetestSell() ? -1 : 0);
   if(mode == MODE_DOUBLE_SWEEP)         return GetTrendDirection();
   if(mode == MODE_ASIAN_RANGE_EXP)      return GetTrendDirection();
   if(mode == MODE_BTC_DOMINANCE)        return GetTrendDirection();
   if(mode == MODE_CORRELATION_BREAK)    return GetTrendDirection();
   if(mode == MODE_NEWS_ABSORPTION)      return -GetLastCandleDirection();
   if(mode == MODE_DELAYED_REVERSAL)     return IsDelayedReversalBuy() ? 1 : (IsDelayedReversalSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_LADDER)     return IsLiquidityLadderBuy() ? 1 : (IsLiquidityLadderSell() ? -1 : 0);
   if(mode == MODE_ROUND_NUMBER_MAGNET)  return GetRoundNumberDirection();
   if(mode == MODE_MIDNIGHT_FLUSH)       return IsMidnightFlushBuy() ? 1 : (IsMidnightFlushSell() ? -1 : 0);
   if(mode == MODE_TREND_ACCELERATION)   return IsTrendAccelerationBuy() ? 1 : (IsTrendAccelerationSell() ? -1 : 0);
   if(mode == MODE_RETAIL_TRAP_SEQUENCE) return IsRetailTrapSequenceBuy() ? 1 : (IsRetailTrapSequenceSell() ? -1 : 0);
   if(mode == MODE_DISTRIBUTION)         return -1;

   return 0;
}

//+------------------------------------------------------------------+
string GetAdvancedBuyComment(int mode)
{
   return StringConcatenate("TYPE", IntegerToString(mode), "_BUY");
}

//+------------------------------------------------------------------+
string GetAdvancedSellComment(int mode)
{
   return StringConcatenate("TYPE", IntegerToString(mode), "_SELL");
}

//+------------------------------------------------------------------+
int GetAdvancedMaxOrders(int mode)
{
   if(mode == MODE_INTRADAY_BOOKER)
      return 1;

   return MaxAdvancedOrdersPerSide;
}

//+------------------------------------------------------------------+
int ExtractAdvancedType(string commentText)
{
   if(StringFind(commentText, "TYPE") != 0)
      return 0;

   int p = StringFind(commentText, "_");

   if(p <= 4)
      return 0;

   string n = StringSubstr(commentText, 4, p - 4);

   return StrToInteger(n);
}

//+------------------------------------------------------------------+
double GetAdvancedTP(int mode)
{
   if(mode == MODE_INTRADAY_BOOKER)
      return DayBasketTPUSD;

   return AdvancedBasketTPUSD;
}

//+------------------------------------------------------------------+
double GetAdvancedSL(int mode)
{
   if(mode == MODE_INTRADAY_BOOKER)
      return DayBasketSLUSD;

   return AdvancedBasketSLUSD;
}

//+------------------------------------------------------------------+
double GetAdvancedLot(int mode)
{
   if(mode == MODE_INTRADAY_BOOKER)
      return DayLot;

   return AdvancedLot;
}

//+------------------------------------------------------------------+
string AdvancedModeText(int mode)
{
   if(mode == 9)  return "TYPE 9 VOL EXPANSION";
   if(mode == 10) return "TYPE 10 VOL COLLAPSE";
   if(mode == 11) return "TYPE 11 EMA RECLAIM";
   if(mode == 12) return "TYPE 12 PARABOLIC SPIKE";
   if(mode == 13) return "TYPE 13 ORDER BLOCK RETEST";
   if(mode == 14) return "TYPE 14 LIQUIDITY VOID";
   if(mode == 15) return "TYPE 15 STOP HUNT ENGINE";
   if(mode == 16) return "TYPE 16 TREND STAIRCASE";
   if(mode == 17) return "TYPE 17 NEWS CHAOS";
   if(mode == 18) return "TYPE 18 HEDGE TRAP";
   if(mode == 19) return "TYPE 19 TREND FAILURE";
   if(mode == 20) return "TYPE 20 ACCUMULATION";
   if(mode == 21) return "TYPE 21 INTRADAY BOOKER";
   if(mode == 22) return "TYPE 22 WEEKEND TRAP";
   if(mode == 23) return "TYPE 23 MONDAY RESET";
   if(mode == 24) return "TYPE 24 DAILY OPEN REJECT";
   if(mode == 25) return "TYPE 25 PRE-NY ACCUM";
   if(mode == 26) return "TYPE 26 POST-LIQ REVERSAL";
   if(mode == 27) return "TYPE 27 FUNDING FLIP";
   if(mode == 28) return "TYPE 28 WHALE DEFENSE";
   if(mode == 29) return "TYPE 29 LIQUIDITY MAGNET";
   if(mode == 30) return "TYPE 30 EMA PINBALL";
   if(mode == 31) return "TYPE 31 CASCADE LIQ";
   if(mode == 32) return "TYPE 32 MICRO CHANNEL";
   if(mode == 33) return "TYPE 33 BREAK FAIL RETEST";
   if(mode == 34) return "TYPE 34 DOUBLE SWEEP";
   if(mode == 35) return "TYPE 35 ASIAN RANGE EXP";
   if(mode == 36) return "TYPE 36 HFT NOISE";
   if(mode == 37) return "TYPE 37 BTC DOMINANCE";
   if(mode == 38) return "TYPE 38 CORRELATION BREAK";
   if(mode == 39) return "TYPE 39 NEWS ABSORPTION";
   if(mode == 40) return "TYPE 40 DELAYED REVERSAL";
   if(mode == 41) return "TYPE 41 LIQUIDITY LADDER";
   if(mode == 42) return "TYPE 42 ROUND NUMBER MAGNET";
   if(mode == 43) return "TYPE 43 MIDNIGHT FLUSH";
   if(mode == 44) return "TYPE 44 TREND ACCEL";
   if(mode == 45) return "TYPE 45 ARBITRAGE DISTORT";
   if(mode == 46) return "TYPE 46 MTF CONFLICT";
   if(mode == 47) return "TYPE 47 SESSION TRANSITION";
   if(mode == 48) return "TYPE 48 RETAIL TRAP";
   if(mode == 49) return "TYPE 49 DEAD ZONE";
   if(mode == 50) return "TYPE 50 DISTRIBUTION";

   return "ADVANCED TYPE";
}

//+------------------------------------------------------------------+
int CountAdvancedOrders11111()
{
   int total = 0;

   for(int t = 9; t <= 50; t++)
   {
      total += CountOrdersByComment(GetAdvancedBuyComment(t));
      total += CountOrdersByComment(GetAdvancedSellComment(t));
   }

   return total;
}

//+------------------------------------------------------------------+
int GetLastCandleDirection()
{
   double o = iOpen(Symbol(), TradeTF, 1);
   double c = iClose(Symbol(), TradeTF, 1);

   if(c > o) return 1;
   if(c < o) return -1;

   return 0;
}

//+------------------------------------------------------------------+
double GetATRAvg(ENUM_TIMEFRAMES tf, int period, int bars)
{
   double total = 0;
   int count = 0;

   for(int i = 1; i <= bars; i++)
   {
      double atr = iATR(Symbol(), tf, period, i);

      if(atr > 0)
      {
         total += atr;
         count++;
      }
   }

   if(count <= 0)
      return 0;

   return total / count;
}

//+------------------------------------------------------------------+
bool IsVolatilityExpansion()
{
   double atrNow = iATR(Symbol(), TradeTF, ATRPeriod, 1);
   double atrAvg = GetATRAvg(TradeTF, ATRPeriod, 20);

   if(atrAvg <= 0) return false;

   return atrNow >= atrAvg * VolExpansionRatio;
}

//+------------------------------------------------------------------+
bool IsVolatilityCollapse()
{
   double atrNow = iATR(Symbol(), TradeTF, ATRPeriod, 1);
   double atrAvg = GetATRAvg(TradeTF, ATRPeriod, 20);

   if(atrAvg <= 0) return false;

   return atrNow <= atrAvg * VolCollapseRatio;
}

//+------------------------------------------------------------------+
bool IsEMAReclaimBuy()
{
   double ema = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double c1 = iClose(Symbol(), TrendTF, 1);
   double c2 = iClose(Symbol(), TrendTF, 2);

   return c2 < ema && c1 > ema;
}

//+------------------------------------------------------------------+
bool IsEMAReclaimSell()
{
   double ema = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double c1 = iClose(Symbol(), TrendTF, 1);
   double c2 = iClose(Symbol(), TrendTF, 2);

   return c2 > ema && c1 < ema;
}

//+------------------------------------------------------------------+
bool IsParabolicSpikeUp()
{
   double b1 = MathAbs(iClose(Symbol(), TradeTF, 1) - iOpen(Symbol(), TradeTF, 1));
   double b2 = MathAbs(iClose(Symbol(), TradeTF, 2) - iOpen(Symbol(), TradeTF, 2));
   double b3 = MathAbs(iClose(Symbol(), TradeTF, 3) - iOpen(Symbol(), TradeTF, 3));

   return b1 > b2 && b2 > b3 && iClose(Symbol(), TradeTF, 1) > iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsParabolicSpikeDown()
{
   double b1 = MathAbs(iClose(Symbol(), TradeTF, 1) - iOpen(Symbol(), TradeTF, 1));
   double b2 = MathAbs(iClose(Symbol(), TradeTF, 2) - iOpen(Symbol(), TradeTF, 2));
   double b3 = MathAbs(iClose(Symbol(), TradeTF, 3) - iOpen(Symbol(), TradeTF, 3));

   return b1 > b2 && b2 > b3 && iClose(Symbol(), TradeTF, 1) < iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsOrderBlockRetestBuy()
{
   double impulseLow = iLow(Symbol(), PERIOD_M5, 2);
   double impulseBody = MathAbs(iClose(Symbol(), PERIOD_M5, 2) - iOpen(Symbol(), PERIOD_M5, 2));

   if(impulseBody < BigMoveMinPrice / 2) return false;

   return Bid <= impulseLow + 50 && GetTrendDirection() == 1;
}

//+------------------------------------------------------------------+
bool IsOrderBlockRetestSell()
{
   double impulseHigh = iHigh(Symbol(), PERIOD_M5, 2);
   double impulseBody = MathAbs(iClose(Symbol(), PERIOD_M5, 2) - iOpen(Symbol(), PERIOD_M5, 2));

   if(impulseBody < BigMoveMinPrice / 2) return false;

   return Ask >= impulseHigh - 50 && GetTrendDirection() == -1;
}

//+------------------------------------------------------------------+
bool IsLiquidityVoidUp()
{
   double body = MathAbs(iClose(Symbol(), TradeTF, 1) - iOpen(Symbol(), TradeTF, 1));
   double wick = (iHigh(Symbol(), TradeTF, 1) - iLow(Symbol(), TradeTF, 1)) - body;

   return body > BigMoveMinPrice && wick < body * 0.25 && iClose(Symbol(), TradeTF, 1) > iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsLiquidityVoidDown()
{
   double body = MathAbs(iClose(Symbol(), TradeTF, 1) - iOpen(Symbol(), TradeTF, 1));
   double wick = (iHigh(Symbol(), TradeTF, 1) - iLow(Symbol(), TradeTF, 1)) - body;

   return body > BigMoveMinPrice && wick < body * 0.25 && iClose(Symbol(), TradeTF, 1) < iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsStopHuntUp()
{
   return IsFakeBreakoutUp() || IsLiquiditySweepUp();
}

//+------------------------------------------------------------------+
bool IsStopHuntDown()
{
   return IsFakeBreakoutDown() || IsLiquiditySweepDown();
}

//+------------------------------------------------------------------+
bool IsTrendStaircaseBuy()
{
   return GetTrendDirection() == 1 &&
          iLow(Symbol(), TrendTF, 1) > iLow(Symbol(), TrendTF, 2) &&
          iLow(Symbol(), TrendTF, 2) > iLow(Symbol(), TrendTF, 3);
}

//+------------------------------------------------------------------+
bool IsTrendStaircaseSell()
{
   return GetTrendDirection() == -1 &&
          iHigh(Symbol(), TrendTF, 1) < iHigh(Symbol(), TrendTF, 2) &&
          iHigh(Symbol(), TrendTF, 2) < iHigh(Symbol(), TrendTF, 3);
}

//+------------------------------------------------------------------+
bool IsNewsChaosMode()
{
   return MarketInfo(Symbol(), MODE_SPREAD) > MaxSpreadPoints * 0.8 && IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
int CountEMACrosses(int bars)
{
   int crosses = 0;
   double prevDiff = 0;

   for(int i = bars; i >= 1; i--)
   {
      double fast = iMA(Symbol(), TradeTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, i);
      double slow = iMA(Symbol(), TradeTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, i);
      double diff = fast - slow;

      if(prevDiff != 0 && diff * prevDiff < 0)
         crosses++;

      prevDiff = diff;
   }

   return crosses;
}

//+------------------------------------------------------------------+
bool IsHFTNoiseMode()
{
   return CountEMACrosses(EMACrossLookbackBars) >= MaxCrossesForNoise;
}

//+------------------------------------------------------------------+
bool IsTrendFailureBuy()
{
   return GetTrendDirection() == 1 && IsFakeBreakoutUp();
}

//+------------------------------------------------------------------+
bool IsTrendFailureSell()
{
   return GetTrendDirection() == -1 && IsFakeBreakoutDown();
}

//+------------------------------------------------------------------+
bool IsAccumulationMode()
{
   return IsVolatilityCollapse() && IsRangeMomentum();
}

//+------------------------------------------------------------------+
int GetTrendByTF(ENUM_TIMEFRAMES tf)
{
   double emaFast = iMA(Symbol(), tf, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), tf, 21, 0, MODE_EMA, PRICE_CLOSE, 1);
   double c = iClose(Symbol(), tf, 1);

   if(c > emaFast && emaFast > emaSlow) return 1;
   if(c < emaFast && emaFast < emaSlow) return -1;

   return 0;
}

//+------------------------------------------------------------------+
int GetType21DaySignal()
{
   int h1  = GetTrendByTF(DayTrendTF1);
   int m15 = GetTrendByTF(DayTrendTF2);

   if(h1 == 1 && m15 == 1) return 1;
   if(h1 == -1 && m15 == -1) return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool IsIntradayBookerMode()
{
   if(!UseType21IntradayBooker) return false;

   return GetType21DaySignal() != 0;
}

//+------------------------------------------------------------------+
bool IsWeekendTrap()
{
   int d = TimeDayOfWeek(TimeCurrent());

   return d == 0 || d == 6;
}

//+------------------------------------------------------------------+
bool IsMondayReset()
{
   return TimeDayOfWeek(TimeCurrent()) == 1 && TimeHour(TimeCurrent()) < 6;
}

//+------------------------------------------------------------------+
double GetTodayOpen()
{
   datetime now = TimeCurrent();
   datetime dayStart = StrToTime(TimeToString(now, TIME_DATE));
   int shift = iBarShift(Symbol(), PERIOD_M1, dayStart, false);

   if(shift < 0)
      return iOpen(Symbol(), PERIOD_D1, 0);

   return iOpen(Symbol(), PERIOD_M1, shift);
}

//+------------------------------------------------------------------+
bool IsDailyOpenRejectionBuy()
{
   double op = GetTodayOpen();

   return iLow(Symbol(), TradeTF, 1) < op && iClose(Symbol(), TradeTF, 1) > op;
}

//+------------------------------------------------------------------+
bool IsDailyOpenRejectionSell()
{
   double op = GetTodayOpen();

   return iHigh(Symbol(), TradeTF, 1) > op && iClose(Symbol(), TradeTF, 1) < op;
}

//+------------------------------------------------------------------+
bool IsPreNYAccumulation()
{
   int h = TimeHour(TimeCurrent());

   return h >= NYStartHour - 2 && h < NYStartHour && IsAccumulationMode();
}

//+------------------------------------------------------------------+
bool IsPostLiquidationReversalBuy()
{
   return IsLiquiditySweepDown() && IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsPostLiquidationReversalSell()
{
   return IsLiquiditySweepUp() && IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsFundingFlipMode()
{
   int h = TimeHour(TimeCurrent());

   return (h == 0 || h == 8 || h == 16) && IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsWhaleDefenseBuy()
{
   double low1 = iLow(Symbol(), TradeTF, 1);
   double low2 = iLow(Symbol(), TradeTF, 2);
   double low3 = iLow(Symbol(), TradeTF, 3);

   return MathAbs(low1 - low2) < 40 &&
          MathAbs(low2 - low3) < 40 &&
          iClose(Symbol(), TradeTF, 1) > iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsWhaleDefenseSell()
{
   double h1 = iHigh(Symbol(), TradeTF, 1);
   double h2 = iHigh(Symbol(), TradeTF, 2);
   double h3 = iHigh(Symbol(), TradeTF, 3);

   return MathAbs(h1 - h2) < 40 &&
          MathAbs(h2 - h3) < 40 &&
          iClose(Symbol(), TradeTF, 1) < iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsLiquidityMagnetBuy()
{
   double prevHigh = GetRecentHigh(PERIOD_M5, 10, 2);

   return Bid < prevHigh && prevHigh - Bid < 120 && GetTrendDirection() == 1;
}

//+------------------------------------------------------------------+
bool IsLiquidityMagnetSell()
{
   double prevLow = GetRecentLow(PERIOD_M5, 10, 2);

   return Bid > prevLow && Bid - prevLow < 120 && GetTrendDirection() == -1;
}

//+------------------------------------------------------------------+
bool IsEMAPinball()
{
   double e1 = iMA(Symbol(), TradeTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double e2 = iMA(Symbol(), TradeTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double high = iHigh(Symbol(), TradeTF, 1);
   double low = iLow(Symbol(), TradeTF, 1);

   return high >= MathMax(e1, e2) && low <= MathMin(e1, e2);
}

//+------------------------------------------------------------------+
int GetEMAPinballDirection()
{
   double e1 = iMA(Symbol(), TradeTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double e2 = iMA(Symbol(), TradeTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double c = iClose(Symbol(), TradeTF, 1);

   if(c > MathMax(e1, e2)) return 1;
   if(c < MathMin(e1, e2)) return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool IsCascadeLiquidationUp()
{
   return iClose(Symbol(), TradeTF, 1) > iOpen(Symbol(), TradeTF, 1) &&
          iClose(Symbol(), TradeTF, 2) > iOpen(Symbol(), TradeTF, 2) &&
          iClose(Symbol(), TradeTF, 3) > iOpen(Symbol(), TradeTF, 3) &&
          DetectBigMoveDirection() == 1;
}

//+------------------------------------------------------------------+
bool IsCascadeLiquidationDown()
{
   return iClose(Symbol(), TradeTF, 1) < iOpen(Symbol(), TradeTF, 1) &&
          iClose(Symbol(), TradeTF, 2) < iOpen(Symbol(), TradeTF, 2) &&
          iClose(Symbol(), TradeTF, 3) < iOpen(Symbol(), TradeTF, 3) &&
          DetectBigMoveDirection() == -1;
}

//+------------------------------------------------------------------+
bool IsMicroChannelBuy()
{
   return IsTrendStaircaseBuy() && !IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsMicroChannelSell()
{
   return IsTrendStaircaseSell() && !IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsBreakoutFailureRetestBuy()
{
   return IsFakeBreakoutDown() && iClose(Symbol(), TradeTF, 1) > iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsBreakoutFailureRetestSell()
{
   return IsFakeBreakoutUp() && iClose(Symbol(), TradeTF, 1) < iOpen(Symbol(), TradeTF, 1);
}

//+------------------------------------------------------------------+
bool IsDoubleSweep()
{
   double high = iHigh(Symbol(), TradeTF, 1);
   double low  = iLow(Symbol(), TradeTF, 1);
   double prevHigh = GetRecentHigh(TradeTF, 5, 2);
   double prevLow  = GetRecentLow(TradeTF, 5, 2);

   return high > prevHigh && low < prevLow;
}

//+------------------------------------------------------------------+
bool IsAsianRangeExpansion()
{
   return GetSessionMode() == 2 && IsVolatilityExpansion();
}

//+------------------------------------------------------------------+
bool IsBTCDominanceProxy()
{
   return GetTrendDirection() != 0 && GetHTFTrendDirection() == GetTrendDirection();
}

//+------------------------------------------------------------------+
bool IsCorrelationBreakProxy()
{
   return IsVolatilityExpansion() && GetTrendDirection() == 0;
}

//+------------------------------------------------------------------+
bool IsNewsAbsorption()
{
   return IsVolatilityExpansion() && (IsLiquiditySweepUp() || IsLiquiditySweepDown());
}

//+------------------------------------------------------------------+
bool IsDelayedReversalBuy()
{
   return IsTrendExhaustionDown() || IsPostLiquidationReversalBuy();
}

//+------------------------------------------------------------------+
bool IsDelayedReversalSell()
{
   return IsTrendExhaustionUp() || IsPostLiquidationReversalSell();
}

//+------------------------------------------------------------------+
bool IsLiquidityLadderBuy()
{
   return iLow(Symbol(), TradeTF, 1) > iLow(Symbol(), TradeTF, 2) &&
          iLow(Symbol(), TradeTF, 2) > iLow(Symbol(), TradeTF, 3) &&
          IsRangeMomentum();
}

//+------------------------------------------------------------------+
bool IsLiquidityLadderSell()
{
   return iHigh(Symbol(), TradeTF, 1) < iHigh(Symbol(), TradeTF, 2) &&
          iHigh(Symbol(), TradeTF, 2) < iHigh(Symbol(), TradeTF, 3) &&
          IsRangeMomentum();
}

//+------------------------------------------------------------------+
bool IsRoundNumberMagnet()
{
   double nearest = MathRound(Bid / RoundNumberStep) * RoundNumberStep;

   return MathAbs(Bid - nearest) <= RoundNumberBuffer;
}

//+------------------------------------------------------------------+
int GetRoundNumberDirection()
{
   double nearest = MathRound(Bid / RoundNumberStep) * RoundNumberStep;

   if(Bid < nearest) return 1;
   if(Bid > nearest) return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool IsMidnightFlushBuy()
{
   int h = TimeHour(TimeCurrent());

   return h == 0 && IsLiquiditySweepDown();
}

//+------------------------------------------------------------------+
bool IsMidnightFlushSell()
{
   int h = TimeHour(TimeCurrent());

   return h == 0 && IsLiquiditySweepUp();
}

//+------------------------------------------------------------------+
bool IsTrendAccelerationBuy()
{
   return IsParabolicSpikeUp() && GetTrendDirection() == 1;
}

//+------------------------------------------------------------------+
bool IsTrendAccelerationSell()
{
   return IsParabolicSpikeDown() && GetTrendDirection() == -1;
}

//+------------------------------------------------------------------+
bool IsExchangeArbitrageProxy()
{
   return IsLiquidityVoidUp() || IsLiquidityVoidDown();
}

//+------------------------------------------------------------------+
bool IsMTFConflict()
{
   int m5 = GetTrendDirection();
   int m15 = GetHTFTrendDirection();

   return m5 != 0 && m15 != 0 && m5 != m15;
}

//+------------------------------------------------------------------+
bool IsSessionTransitionChaos()
{
   int h = TimeHour(TimeCurrent());

   return h == LondonStartHour || h == LondonEndHour || h == NYStartHour;
}

//+------------------------------------------------------------------+
bool IsRetailTrapSequenceBuy()
{
   return IsFakeBreakoutDown() && IsEMAReclaimBuy();
}

//+------------------------------------------------------------------+
bool IsRetailTrapSequenceSell()
{
   return IsFakeBreakoutUp() && IsEMAReclaimSell();
}

//+------------------------------------------------------------------+
bool IsDeadZone()
{
   double atr = iATR(Symbol(), TradeTF, ATRPeriod, 1);

   return atr > 0 && atr <= DeadZoneATRMax;
}

//+------------------------------------------------------------------+
bool IsDistributionMode()
{
   return IsWhaleDefenseSell() && IsTrendExhaustionUp();
}


//+------------------------------------------------------------------+
int OnInit()
  {
   Print("BTCUSD 8-Type Momentum Basket EA Started");
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   ObjectsDeleteAll(0, "BOT_EMA_FAST_");
   ObjectsDeleteAll(0, "BOT_EMA_SLOW_");
   ObjectsDeleteAll(0, "DASH_");
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {

      CheckGlobalBasketClose();

   RefreshRates();

   UpdateBigMoveStatus();

   DrawBotEMALines();
   DrawDashboard();

   if(!IsTradeAllowed())
      return;

   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpreadPoints)
      return;

   if(UseEquityProtection)
      CheckEquityProtection();

   CheckAllSeparateBasketClose();

   if(UseRecoveryOrders)
      CheckAllRecoveryOrders();

   ProcessNewBarLogic();
  }

//+------------------------------------------------------------------+
void ProcessNewBarLogic()
  {
   datetime currentBar = iTime(Symbol(), TradeTF, 0);

   if(currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double candleSize = MathAbs(close1 - open1);

   if(candleSize < MinCandleSize)
     {
      Print("No order: candle too small. Size=", candleSize);
      return;
     }

   int mode = DetectMarketMode();

   if(mode == MODE_BIG)
     {
      ProcessBigMomentum();
      return;
     }
   if(mode == MODE_RANGE)
     {
      ProcessRangeMomentum();
      return;
     }
   if(mode == MODE_TREND)
     {
      ProcessTrendMomentum();
      return;
     }
   if(mode == MODE_FAKE)
     {
      ProcessFakeBreakout();
      return;
     }
   if(mode == MODE_SQUEEZE)
     {
      ProcessCompressionBreakout();
      return;
     }
   if(mode == MODE_SWEEP)
     {
      ProcessLiquiditySweep();
      return;
     }
   if(mode == MODE_EXHAUST)
     {
      ProcessTrendExhaustion();
      return;
     }


   if(mode >= 9 && mode <= 50)
     {
      ProcessAdvancedType(mode);
      return;
     }

   Print("No order: no clear BTC market mode.");
  }

//+------------------------------------------------------------------+
// Mode detection priority includes session behavior.
//+------------------------------------------------------------------+
int DetectMarketMode()
  {
   int session = GetSessionMode();

// London: fake breakout and sweep are common.
   if(UseSessionMode && session == 2)
     {
      if(UseFakeBreakout && (IsFakeBreakoutUp() || IsFakeBreakoutDown()))
         return MODE_FAKE;

      if(UseLiquiditySweep && (IsLiquiditySweepUp() || IsLiquiditySweepDown()))
         return MODE_SWEEP;

      if(UseBigMomentum && DetectBigMoveDirection() != 0)
         return MODE_BIG;
     }

// NY: big momentum and trend continuation are common.
   if(UseSessionMode && session == 3)
     {
      if(UseBigMomentum && DetectBigMoveDirection() != 0)
         return MODE_BIG;

      if(UseTrendMomentum && GetTrendDirection() != 0)
         return MODE_TREND;

      if(UseTrendExhaustion && (IsTrendExhaustionUp() || IsTrendExhaustionDown()))
         return MODE_EXHAUST;
     }

// Asian: range is common.
   if(UseSessionMode && session == 1)
     {
      if(UseRangeMomentum && IsRangeMomentum())
         return MODE_RANGE;

      if(UseCompressionBreak && IsCompressionBreakoutMode())
         return MODE_SQUEEZE;
     }

// Default fallback priority.
   if(UseBigMomentum && DetectBigMoveDirection() != 0)
      return MODE_BIG;

   if(UseFakeBreakout && (IsFakeBreakoutUp() || IsFakeBreakoutDown()))
      return MODE_FAKE;

   if(UseLiquiditySweep && (IsLiquiditySweepUp() || IsLiquiditySweepDown()))
      return MODE_SWEEP;

   if(UseCompressionBreak && IsCompressionBreakoutMode())
      return MODE_SQUEEZE;

   if(UseRangeMomentum && IsRangeMomentum())
      return MODE_RANGE;

   if(UseTrendExhaustion && (IsTrendExhaustionUp() || IsTrendExhaustionDown()))
      return MODE_EXHAUST;

   if(UseTrendMomentum && GetTrendDirection() != 0)
      return MODE_TREND;


   if(UseAdvancedTypes9To50)
     {
      int advMode = DetectAdvancedMarketMode();

      if(advMode != MODE_NONE)
         return advMode;
     }

   return MODE_NONE;
  }

//+------------------------------------------------------------------+
// TYPE 1: BIG REVERSAL
//+------------------------------------------------------------------+
void ProcessBigMomentum()
  {
   if(lastBigMoveDirection == 0)
      return;

   if(OnlyOneBigMoveOrderPerBar && lastBigMoveTradeTime == lastBigMoveBarTime)
      return;

   if(lastBigMoveDirection == 1)
     {
      if(CountOrdersByComment("BIG_SELL") >= MaxBigOrdersPerSide)
         return;

      OpenOrder(OP_SELL, BigMomentumLot, "BIG_SELL");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
     }

   if(lastBigMoveDirection == -1)
     {
      if(CountOrdersByComment("BIG_BUY") >= MaxBigOrdersPerSide)
         return;

      OpenOrder(OP_BUY, BigMomentumLot, "BIG_BUY");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 2: RANGE RECOVERY
//+------------------------------------------------------------------+
void ProcessRangeMomentum()
  {
   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);

   if(close1 > open1)
     {
      if(CountOrdersByComment("RANGE_BUY") >= MaxRangeOrdersPerSide)
         return;

      if(!CanOpenByGap("RANGE_BUY", RangeOrderGapPrice))
         return;

      OpenOrder(OP_BUY, BaseLot, "RANGE_BUY");
      return;
     }

   if(close1 < open1)
     {
      if(CountOrdersByComment("RANGE_SELL") >= MaxRangeOrdersPerSide)
         return;

      if(!CanOpenByGap("RANGE_SELL", RangeOrderGapPrice))
         return;

      OpenOrder(OP_SELL, BaseLot, "RANGE_SELL");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 3: TREND CONTINUATION
//+------------------------------------------------------------------+
void ProcessTrendMomentum()
  {
   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double candleSize = MathAbs(close1 - open1);

   if(candleSize >= MaxTrendOrderCandleSize)
     {
      Print("Trend order blocked: big candle size=", candleSize);
      return;
     }

   int trend = GetTrendDirection();

   if(trend == 1)
     {
      if(CountOrdersByComment("TREND_BUY") >= MaxTrendOrdersPerSide)
         return;

      if(!CanOpenByGap("TREND_BUY", TrendOrderGapPrice))
         return;

      OpenOrder(OP_BUY, BaseLot, "TREND_BUY");
      return;
     }

   if(trend == -1)
     {
      if(CountOrdersByComment("TREND_SELL") >= MaxTrendOrdersPerSide)
         return;

      if(!CanOpenByGap("TREND_SELL", TrendOrderGapPrice))
         return;

      OpenOrder(OP_SELL, BaseLot, "TREND_SELL");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 4: FAKE BREAKOUT
//+------------------------------------------------------------------+
void ProcessFakeBreakout()
  {
   if(IsFakeBreakoutUp())
     {
      if(CountOrdersByComment("FAKE_SELL") >= MaxFakeOrdersPerSide)
         return;

      OpenOrder(OP_SELL, FakeBreakLot, "FAKE_SELL");
      return;
     }

   if(IsFakeBreakoutDown())
     {
      if(CountOrdersByComment("FAKE_BUY") >= MaxFakeOrdersPerSide)
         return;

      OpenOrder(OP_BUY, FakeBreakLot, "FAKE_BUY");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 5: COMPRESSION BREAKOUT
//+------------------------------------------------------------------+
void ProcessCompressionBreakout()
  {
   double high = GetRecentHigh(TradeTF, RangeLookbackBars);
   double low  = GetRecentLow(TradeTF, RangeLookbackBars);

   if(Ask > high + CompressionBreakBuffer)
     {
      if(CountOrdersByComment("SQUEEZE_BUY") >= MaxSqueezeOrdersPerSide)
         return;

      OpenOrder(OP_BUY, SqueezeLot, "SQUEEZE_BUY");
      return;
     }

   if(Bid < low - CompressionBreakBuffer)
     {
      if(CountOrdersByComment("SQUEEZE_SELL") >= MaxSqueezeOrdersPerSide)
         return;

      OpenOrder(OP_SELL, SqueezeLot, "SQUEEZE_SELL");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 6: LIQUIDITY SWEEP
//+------------------------------------------------------------------+
void ProcessLiquiditySweep()
  {
   if(IsLiquiditySweepUp())
     {
      if(CountOrdersByComment("SWEEP_SELL") >= MaxSweepOrdersPerSide)
         return;

      OpenOrder(OP_SELL, SweepLot, "SWEEP_SELL");
      return;
     }

   if(IsLiquiditySweepDown())
     {
      if(CountOrdersByComment("SWEEP_BUY") >= MaxSweepOrdersPerSide)
         return;

      OpenOrder(OP_BUY, SweepLot, "SWEEP_BUY");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 7: TREND EXHAUSTION
//+------------------------------------------------------------------+
void ProcessTrendExhaustion()
  {
   if(IsTrendExhaustionUp())
     {
      if(CountOrdersByComment("EXHAUST_SELL") >= MaxExhaustOrdersPerSide)
         return;

      OpenOrder(OP_SELL, ExhaustLot, "EXHAUST_SELL");
      return;
     }

   if(IsTrendExhaustionDown())
     {
      if(CountOrdersByComment("EXHAUST_BUY") >= MaxExhaustOrdersPerSide)
         return;

      OpenOrder(OP_BUY, ExhaustLot, "EXHAUST_BUY");
      return;
     }
  }

//+------------------------------------------------------------------+
// TYPE 8: SESSION MODE
// 1 Asian, 2 London, 3 NY, 0 other
//+------------------------------------------------------------------+
int GetSessionMode()
  {
   int h = TimeHour(TimeCurrent());

   if(h >= AsianStartHour && h < AsianEndHour)
      return 1;

   if(h >= LondonStartHour && h < LondonEndHour)
      return 2;

   if(h >= NYStartHour && h <= NYEndHour)
      return 3;

   return 0;
  }

//+------------------------------------------------------------------+
string SessionText()
  {
   int s = GetSessionMode();

   if(s == 1)
      return "ASIAN - RANGE PRIORITY";
   if(s == 2)
      return "LONDON - FAKE/SWEEP PRIORITY";
   if(s == 3)
      return "NY - TREND/BIG PRIORITY";

   return "OTHER";
  }

//+------------------------------------------------------------------+
void UpdateBigMoveStatus()
  {
   int dir = DetectBigMoveDirection();

   if(dir == 0)
      return;

   datetime moveTime = iTime(Symbol(), TradeTF, 1);

   if(moveTime == lastBigMoveBarTime && dir == lastBigMoveDirection)
      return;

   lastBigMoveDirection = dir;
   lastBigMoveBarTime = moveTime;

   Print("BIG MOMENTUM FOUND: ",
         dir == 1 ? "BIG UP -> BIG_SELL ready" : "BIG DOWN -> BIG_BUY ready");
  }

//+------------------------------------------------------------------+
int DetectBigMoveDirection()
  {
   double firstOpen = iOpen(Symbol(), TradeTF, BigMoveLookbackBars);
   double lastClose = iClose(Symbol(), TradeTF, 1);

   if(firstOpen <= 0 || lastClose <= 0)
      return 0;

   double move = lastClose - firstOpen;

   if(move >= BigMoveMinPrice)
      return 1;

   if(move <= -BigMoveMinPrice)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
bool IsRangeMomentum()
  {
   double highest = GetRecentHigh(TradeTF, RangeLookbackBars);
   double lowest  = GetRecentLow(TradeTF, RangeLookbackBars);
   double range = highest - lowest;

   if(range >= RangeMinPrice && range <= RangeMaxPrice)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
int GetTrendDirection()
  {
   double emaFast = iMA(Symbol(), TrendTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1  = iClose(Symbol(), TrendTF, 1);

   double emaGap = MathAbs(emaFast - emaSlow);

   if(emaGap < MinTrendEMAGap)
      return 0;

   if(close1 > emaFast && emaFast > emaSlow)
      return 1;

   if(close1 < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
bool IsFakeBreakoutUp()
  {
   double prevHigh = GetRecentHigh(PERIOD_M5, FakeBreakLookbackBars, 2);
   double high1 = iHigh(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   if(high1 > prevHigh + FakeBreakBufferPrice && close1 < prevHigh)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsFakeBreakoutDown()
  {
   double prevLow = GetRecentLow(PERIOD_M5, FakeBreakLookbackBars, 2);
   double low1 = iLow(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   if(low1 < prevLow - FakeBreakBufferPrice && close1 > prevLow)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsCompressionBreakoutMode()
  {
   double atr = iATR(Symbol(), PERIOD_M5, CompressionATRPeriod, 1);

   if(atr <= 0)
      return false;

   if(atr > CompressionATRMax)
      return false;

   double high = GetRecentHigh(TradeTF, RangeLookbackBars);
   double low  = GetRecentLow(TradeTF, RangeLookbackBars);

   if(Ask > high + CompressionBreakBuffer)
      return true;

   if(Bid < low - CompressionBreakBuffer)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsLiquiditySweepUp()
  {
   double open1 = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double high1 = iHigh(Symbol(), TradeTF, 1);

   double body = MathAbs(close1 - open1);
   if(body <= Point)
      body = Point;

   double upperWick = high1 - MathMax(open1, close1);

   if(upperWick >= SweepMinWickSize && upperWick >= body * SweepWickBodyRatio)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsLiquiditySweepDown()
  {
   double open1 = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double low1 = iLow(Symbol(), TradeTF, 1);

   double body = MathAbs(close1 - open1);
   if(body <= Point)
      body = Point;

   double lowerWick = MathMin(open1, close1) - low1;

   if(lowerWick >= SweepMinWickSize && lowerWick >= body * SweepWickBodyRatio)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsTrendExhaustionUp()
  {
   int trend = GetTrendDirection();

   if(trend != 1)
      return false;

   double c1 = iClose(Symbol(), TrendTF, 1);
   double c2 = iClose(Symbol(), TrendTF, 2);
   double c3 = iClose(Symbol(), TrendTF, 3);

   if(!(c1 > c2 && c2 > c3))
      return false;

   double gap1 = c1 - c2;
   double gap2 = c2 - c3;

   if(gap1 > 0 && gap2 > 0 && gap1 < gap2)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsTrendExhaustionDown()
  {
   int trend = GetTrendDirection();

   if(trend != -1)
      return false;

   double c1 = iClose(Symbol(), TrendTF, 1);
   double c2 = iClose(Symbol(), TrendTF, 2);
   double c3 = iClose(Symbol(), TrendTF, 3);

   if(!(c1 < c2 && c2 < c3))
      return false;

   double gap1 = c2 - c1;
   double gap2 = c3 - c2;

   if(gap1 > 0 && gap2 > 0 && gap1 < gap2)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
double GetRecentHigh(ENUM_TIMEFRAMES tf, int bars, int startShift = 1)
  {
   double highest = iHigh(Symbol(), tf, startShift);

   for(int i = startShift; i < startShift + bars; i++)
     {
      double h = iHigh(Symbol(), tf, i);
      if(h > highest)
         highest = h;
     }

   return highest;
  }

//+------------------------------------------------------------------+
double GetRecentLow(ENUM_TIMEFRAMES tf, int bars, int startShift = 1)
  {
   double lowest = iLow(Symbol(), tf, startShift);

   for(int i = startShift; i < startShift + bars; i++)
     {
      double l = iLow(Symbol(), tf, i);
      if(l < lowest)
         lowest = l;
     }

   return lowest;
  }

//+------------------------------------------------------------------+
bool CanOpenByGap(string commentText, double gapPrice)
  {
   double lastPrice = GetLastOrderPriceByComment(commentText);

   if(lastPrice <= 0)
      return true;

   double distance = MathAbs(Bid - lastPrice);

   if(distance >= gapPrice)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
void CheckAllRecoveryOrders()
  {
   CheckRecoveryByComment("BIG_BUY",       OP_BUY,  MaxBigOrdersPerSide);
   CheckRecoveryByComment("BIG_SELL",      OP_SELL, MaxBigOrdersPerSide);

   CheckRecoveryByComment("RANGE_BUY",     OP_BUY,  MaxRangeOrdersPerSide);
   CheckRecoveryByComment("RANGE_SELL",    OP_SELL, MaxRangeOrdersPerSide);

   CheckRecoveryByComment("TREND_BUY",     OP_BUY,  MaxTrendOrdersPerSide);
   CheckRecoveryByComment("TREND_SELL",    OP_SELL, MaxTrendOrdersPerSide);

   CheckRecoveryByComment("FAKE_BUY",      OP_BUY,  MaxFakeOrdersPerSide);
   CheckRecoveryByComment("FAKE_SELL",     OP_SELL, MaxFakeOrdersPerSide);

   CheckRecoveryByComment("SQUEEZE_BUY",   OP_BUY,  MaxSqueezeOrdersPerSide);
   CheckRecoveryByComment("SQUEEZE_SELL",  OP_SELL, MaxSqueezeOrdersPerSide);

   CheckRecoveryByComment("SWEEP_BUY",     OP_BUY,  MaxSweepOrdersPerSide);
   CheckRecoveryByComment("SWEEP_SELL",    OP_SELL, MaxSweepOrdersPerSide);

   CheckRecoveryByComment("EXHAUST_BUY",   OP_BUY,  MaxExhaustOrdersPerSide);
   CheckRecoveryByComment("EXHAUST_SELL",  OP_SELL, MaxExhaustOrdersPerSide);


   if(UseAdvancedTypes9To50)
     {
      for(int t = 9; t <= 50; t++)
        {
         CheckRecoveryByComment(GetAdvancedBuyComment(t),  OP_BUY,  GetAdvancedMaxOrders(t));
         CheckRecoveryByComment(GetAdvancedSellComment(t), OP_SELL, GetAdvancedMaxOrders(t));
        }
     }
  }

//+------------------------------------------------------------------+
bool IsRecoveryAllowedForBasket(string commentText)
  {
   int mode = DetectMarketMode();

   if(StringFind(commentText, "BIG_") == 0)
      return mode == MODE_BIG;

   if(StringFind(commentText, "RANGE_") == 0)
      return mode == MODE_RANGE;

   if(StringFind(commentText, "TREND_") == 0)
      return mode == MODE_TREND;

   if(StringFind(commentText, "FAKE_") == 0)
      return mode == MODE_FAKE;

   if(StringFind(commentText, "SQUEEZE_") == 0)
      return mode == MODE_SQUEEZE;

   if(StringFind(commentText, "SWEEP_") == 0)
      return mode == MODE_SWEEP;

   if(StringFind(commentText, "EXHAUST_") == 0)
      return mode == MODE_EXHAUST;


   if(StringFind(commentText, "TYPE") == 0)
     {
      int advType = ExtractAdvancedType(commentText);
      if(advType >= 9 && advType <= 50)
         return mode == advType;
     }

   return false;
  }

//+------------------------------------------------------------------+
void CheckRecoveryByComment(string commentText, int type, int maxOrders)
  {
   if(!IsRecoveryAllowedForBasket(commentText))
      return;

   int count = CountOrdersByComment(commentText);

   if(count <= 0)
      return;

   if(count >= maxOrders)
      return;

   if(CountRecoveryOrdersByComment(commentText) >= MaxRecoveryOrdersPerBasket)
      return;

   double profit = GetBasketProfitByComment(commentText);

   if(profit >= 0)
      return;

   double lastPrice = GetLastOrderPriceByComment(commentText);

   if(lastPrice <= 0)
      return;

   double distance = MathAbs(Bid - lastPrice);

   if(distance < RecoveryGapPrice)
      return;

   double lot = GetRecoveryLotByComment(commentText);

   int recoveryType = type;

   if(!RecoverySameDirection)
     {
      if(type == OP_BUY)
         recoveryType = OP_SELL;
      else
         recoveryType = OP_BUY;
     }

   OpenOrder(recoveryType, lot, commentText + "_RECOVERY");
  }

//+------------------------------------------------------------------+
double GetRecoveryLotByComment(string commentText)
  {
   int recoveryCount = CountRecoveryOrdersByComment(commentText);

   if(recoveryCount == 0)
      return BaseLot;
   if(recoveryCount == 1)
      return BaseLot;
   if(recoveryCount == 2)
      return BaseLot * 2;
   if(recoveryCount == 3)
      return BaseLot * 2;

   return BaseLot * 3;
  }


//+------------------------------------------------------------------+
//| Same basket cooldown: prevents repeat orders in same TYPE/side   |
//| Example: BIG_BUY blocks only BIG_BUY for 120 seconds             |
//+------------------------------------------------------------------+
bool IsSameBasketCooldownActive(string commentText)
  {
   if(!UseSameBasketCooldown)
      return false;

   datetime lastTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
              {
               if(OrderOpenTime() > lastTime)
                  lastTime = OrderOpenTime();
              }
           }
        }
     }

   if(lastTime <= 0)
      return false;

   int secondsPassed = (int)(TimeCurrent() - lastTime);

   if(secondsPassed < SameBasketCooldownSeconds)
     {
      Print("COOLDOWN ACTIVE: ", commentText,
            " wait ", SameBasketCooldownSeconds - secondsPassed, " seconds");
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
void OpenOrder(int type, double lot, string commentText)
  {
   RefreshRates();

   // Same TYPE + same direction cooldown.
   // Example: BIG_BUY blocks only BIG_BUY. BIG_SELL can still open.
   if(IsSameBasketCooldownActive(commentText))
      return;

   // Professional final gate before every TYPE 1-8 order.
   // Profit may happen or may not happen. This gate blocks low-quality BTC entries.
   if(!CanCreateProfessionalOrder(type, commentText))
     {
      Print("ORDER BLOCKED BY PROFESSIONAL RISK GATE | ", commentText);
      return;
     }

   if(AccountFreeMarginCheck(Symbol(), type, lot) <= 0)
     {
      Print("Not enough margin for ", commentText, " lot=", lot);
      return;
     }

   double price = type == OP_BUY ? Ask : Bid;
   color clr = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          commentText, MagicNumber, 0, clr);

   if(ticket > 0)
     {
      Print("Opened ", type == OP_BUY ? "BUY " : "SELL ",
            " Lot=", lot,
            " Comment=", commentText,
            " Ticket=", ticket);
     }
   else
     {
      Print("OrderSend failed. Error=", GetLastError(), " Comment=", commentText);
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| PROFESSIONAL TIME-DECAY BASKET CLOSE                            |
//+------------------------------------------------------------------+
void CheckAllSeparateBasketClose()
{


    CheckBasketComment("BIG_BUY",      BigBasketTPUSD,      BigBasketSLUSD);
   CheckBasketComment("BIG_SELL",     BigBasketTPUSD,      BigBasketSLUSD);

   CheckBasketComment("RANGE_BUY",    RangeBasketTPUSD,    RangeBasketSLUSD);
   CheckBasketComment("RANGE_SELL",   RangeBasketTPUSD,    RangeBasketSLUSD);

   CheckBasketComment("TREND_BUY",    TrendBasketTPUSD,    TrendBasketSLUSD);
   CheckBasketComment("TREND_SELL",   TrendBasketTPUSD,    TrendBasketSLUSD);

   CheckBasketComment("FAKE_BUY",     FakeBasketTPUSD,     FakeBasketSLUSD);
   CheckBasketComment("FAKE_SELL",    FakeBasketTPUSD,     FakeBasketSLUSD);

   CheckBasketComment("SQUEEZE_BUY",  SqueezeBasketTPUSD,  SqueezeBasketSLUSD);
   CheckBasketComment("SQUEEZE_SELL", SqueezeBasketTPUSD,  SqueezeBasketSLUSD);

   CheckBasketComment("SWEEP_BUY",    SweepBasketTPUSD,    SweepBasketSLUSD);
   CheckBasketComment("SWEEP_SELL",   SweepBasketTPUSD,    SweepBasketSLUSD);

   CheckBasketComment("EXHAUST_BUY",  ExhaustBasketTPUSD,  ExhaustBasketSLUSD);
   CheckBasketComment("EXHAUST_SELL", ExhaustBasketTPUSD,  ExhaustBasketSLUSD);


   // CheckBasketCommentDynamic("BIG_BUY",      BigBasketTPUSD);
   // CheckBasketCommentDynamic("BIG_SELL",     BigBasketTPUSD);

   // CheckBasketCommentDynamic("RANGE_BUY",    RangeBasketTPUSD);
   // CheckBasketCommentDynamic("RANGE_SELL",   RangeBasketTPUSD);

   // CheckBasketCommentDynamic("TREND_BUY",    TrendBasketTPUSD);
   // CheckBasketCommentDynamic("TREND_SELL",   TrendBasketTPUSD);

   // CheckBasketCommentDynamic("FAKE_BUY",     FakeBasketTPUSD);
   // CheckBasketCommentDynamic("FAKE_SELL",    FakeBasketTPUSD);

   // CheckBasketCommentDynamic("SQUEEZE_BUY",  SqueezeBasketTPUSD);
   // CheckBasketCommentDynamic("SQUEEZE_SELL", SqueezeBasketTPUSD);

   // CheckBasketCommentDynamic("SWEEP_BUY",    SweepBasketTPUSD);
   // CheckBasketCommentDynamic("SWEEP_SELL",   SweepBasketTPUSD);

   // CheckBasketCommentDynamic("EXHAUST_BUY",  ExhaustBasketTPUSD);
   // CheckBasketCommentDynamic("EXHAUST_SELL", ExhaustBasketTPUSD);
}
//+------------------------------------------------------------------+
//| Dynamic SL based on basket holding time                         |
//+------------------------------------------------------------------+
void CheckBasketCommentDynamic(string commentText,double tp)
{

// CheckBasketComment(commentText, tp, -1000); // Large negative SL to ensure only TP or time-decay SL can trigger   


// return ;

   int totalOrders = 0;

   double basketProfit = 0;

   datetime firstOpenTime = 0;

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText))
            {
               totalOrders++;

               basketProfit +=
                  OrderProfit() +
                  OrderSwap() +
                  OrderCommission();

               if(firstOpenTime == 0 ||
                  OrderOpenTime() < firstOpenTime)
               {
                  firstOpenTime = OrderOpenTime();
               }
            }
         }
      }
   }

   if(totalOrders <= 0)
      return;

   // Basket age in minutes
   int basketMinutes =
      (int)((TimeCurrent() - firstOpenTime) / 60);

   // ============================================================
   // PROFESSIONAL TIME-DECAY STOP LOSS
   // ============================================================

   double dynamicSL = -20.0;

   // 0-1 hour
   if(basketMinutes > 60)
      dynamicSL = -5.0;

   // 1-2 hours
   else if(basketMinutes > 120)
      dynamicSL = -10.0;

   // 2-4 hours
   else if(basketMinutes > 240)
      dynamicSL = -15.0;

   // more than 4 hours
   else
      dynamicSL = -20.0;

   // ============================================================
   // TAKE PROFIT
   // ============================================================

   if(basketProfit >= tp)
   {
      Print("TP HIT: ", commentText,
            " Profit=", basketProfit);

      CloseOrdersByComment(commentText);

      return;
   }

   // ============================================================
   // TIME-DECAY STOP LOSS
   // ============================================================

   if(basketProfit <= dynamicSL)
   {
      Print("TIME DECAY SL HIT: ",
            commentText,
            " Profit=", basketProfit,
            " Minutes=", basketMinutes,
            " DynamicSL=", dynamicSL);

      CloseOrdersByComment(commentText);

      return;
   }
}
//+------------------------------------------------------------------+
void CheckBasketComment(string commentText, double tp, double sl)
  {
   if(CountOrdersByComment(commentText) <= 0)
      return;

   double profit = GetBasketProfitByComment(commentText);

   if(profit >= tp)
     {
      Print(commentText, " TP close. Profit=", profit);
      CloseOrdersByComment(commentText);
      return;
     }

   if(profit <= sl)
     {
      Print(commentText, " SL close. Profit=", profit);

      if(UseLossMemoryBlock)
        {
         lastLossMemoryTime = iTime(Symbol(), TradeTF, 1);
         lastLossMemoryBasket = commentText;
        }

      CloseOrdersByComment(commentText);
      return;
     }
  }

//+------------------------------------------------------------------+
double GetBasketProfitByComment(string commentText)
  {
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
               total += OrderProfit() + OrderSwap() + OrderCommission();
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
int CountOrdersByComment(string commentText)
  {
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
               count++;
           }
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
int CountRecoveryOrdersByComment(string commentText)
  {
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText) &&
               StringFind(OrderComment(), "RECOVERY") >= 0)
               count++;
           }
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
bool IsCommentBasketMatch(string orderComment, string basketComment)
  {
   if(orderComment == basketComment)
      return true;

   if(StringFind(orderComment, basketComment + "_RECOVERY") == 0)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
double GetLastOrderPriceByComment(string commentText)
  {
   datetime lastTime = 0;
   double price = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
              {
               if(OrderOpenTime() > lastTime)
                 {
                  lastTime = OrderOpenTime();
                  price = OrderOpenPrice();
                 }
              }
           }
        }
     }

   return price;
  }

//+------------------------------------------------------------------+
void CloseOrdersByComment(string commentText)
  {
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
              {
               bool closed = false;

               if(OrderType() == OP_BUY)
                  closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

               if(OrderType() == OP_SELL)
                  closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

               if(!closed)
                  Print("Close failed Ticket=", OrderTicket(), " Error=", GetLastError());
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
void CheckEquityProtection()
  {
   double limit = AccountBalance() * MinEquityPercent / 100.0;

   if(AccountEquity() <= limit)
     {
      Print("Equity protection triggered. Closing all EA orders.");
      CloseAllEAOrders();
     }
  }
//+------------------------------------------------------------------+
//| GLOBAL BASKET CLOSE                                              |
//| Closes ALL BUY + SELL + ALL TYPES together                       |
//+------------------------------------------------------------------+
void CheckGlobalBasketClose()
{
   if(!UseGlobalBasketClose)
      return;

   double totalProfit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            totalProfit +=
               OrderProfit() +
               OrderSwap() +
               OrderCommission();
         }
      }
   }

   // GLOBAL TAKE PROFIT
   if(totalProfit >= GlobalBasketTPUSD)
   {
      Print("GLOBAL TP HIT: ", totalProfit);

      CloseAllEAOrders();

      return;
   }

   // GLOBAL STOP LOSS
   if(totalProfit <= GlobalBasketSLUSD)
   {
      Print("GLOBAL SL HIT: ", totalProfit);

      CloseAllEAOrders();

      return;
   }
}
//+------------------------------------------------------------------+
void CloseAllEAOrders()
  {
   CloseOrdersByComment("BIG_BUY");
   CloseOrdersByComment("BIG_SELL");
   CloseOrdersByComment("RANGE_BUY");
   CloseOrdersByComment("RANGE_SELL");
   CloseOrdersByComment("TREND_BUY");
   CloseOrdersByComment("TREND_SELL");
   CloseOrdersByComment("FAKE_BUY");
   CloseOrdersByComment("FAKE_SELL");
   CloseOrdersByComment("SQUEEZE_BUY");
   CloseOrdersByComment("SQUEEZE_SELL");
   CloseOrdersByComment("SWEEP_BUY");
   CloseOrdersByComment("SWEEP_SELL");
   CloseOrdersByComment("EXHAUST_BUY");
   CloseOrdersByComment("EXHAUST_SELL");

   if(UseAdvancedTypes9To50)
     {
      for(int t = 9; t <= 50; t++)
        {
         CloseOrdersByComment(GetAdvancedBuyComment(t));
         CloseOrdersByComment(GetAdvancedSellComment(t));
        }
     }
  }

//+------------------------------------------------------------------+
string ModeText()
  {
   int mode = DetectMarketMode();

   if(mode == MODE_BIG)
      return "TYPE 1 BIG REVERSAL";
   if(mode == MODE_RANGE)
      return "TYPE 2 RANGE RECOVERY";
   if(mode == MODE_TREND)
      return "TYPE 3 TREND CONTINUATION";
   if(mode == MODE_FAKE)
      return "TYPE 4 FAKE BREAKOUT";
   if(mode == MODE_SQUEEZE)
      return "TYPE 5 COMPRESSION BREAKOUT";
   if(mode == MODE_SWEEP)
      return "TYPE 6 LIQUIDITY SWEEP";
   if(mode == MODE_EXHAUST)
      return "TYPE 7 TREND EXHAUSTION";

   if(mode >= 9 && mode <= 50)
      return AdvancedModeText(mode);

   return "WAIT";
  }

//+------------------------------------------------------------------+
void DrawBotEMALines()
  {
   if(!DrawEMALines)
      return;

   DrawEMA("BOT_EMA_FAST", TrendFastEMA, EMAFastColor);
   DrawEMA("BOT_EMA_SLOW", TrendSlowEMA, EMASlowColor);
  }

//+------------------------------------------------------------------+
void DrawEMA(string name, int period, color clr)
  {
   for(int i = EMABarsToDraw; i >= 1; i--)
     {
      string objName = name + "_" + IntegerToString(i);

      datetime t1 = iTime(Symbol(), TrendTF, i);
      datetime t2 = iTime(Symbol(), TrendTF, i - 1);

      double p1 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i);
      double p2 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      if(ObjectFind(0, objName) < 0)
        {
         ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
        }
      else
        {
         ObjectMove(0, objName, 0, t1, p1);
         ObjectMove(0, objName, 1, t2, p2);
        }
     }
  }

//+------------------------------------------------------------------+
// Dashboard helpers
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize = 8)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
  }

//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bg)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
     }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
  }

//+------------------------------------------------------------------+
void DrawDashRow(string label, string value, int row, color labelColor, color valueColor)
  {
   int baseX = 300;
   int baseY = 25;
   int lineH = 14;

   DrawLabel("DASH_L_" + IntegerToString(row), label, baseX, baseY + row * lineH, labelColor);
   DrawLabel("DASH_V_" + IntegerToString(row), value, baseX - 190, baseY + row * lineH, valueColor);
  }


//+------------------------------------------------------------------+
int CountAdvancedOrders()
  {
   int total = 0;
   for(int t = 9; t <= 50; t++)
     {
      total += CountOrdersByComment(GetAdvancedBuyComment(t));
      total += CountOrdersByComment(GetAdvancedSellComment(t));
     }
   return total;
  }


//+------------------------------------------------------------------+
void DrawDashboard()
  {
   DrawPanel("DASH_BG_PANEL", 310, 15, 310, 650, clrBlack);

   DrawLabel("DASH_TITLE", "BTC 50-TYPE MOMENTUM EA", 300, 20, clrYellow, 9);

   DrawDashRow("MODE", ModeText(), 2, clrOrange, clrWhite);
   DrawDashRow("SESSION", SessionText(), 3, clrOrange, clrLime);

   DrawDashRow("BIG B/S", "$" + DoubleToString(GetBasketProfitByComment("BIG_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("BIG_SELL"), 2), 5, clrYellow, clrWhite);

   DrawDashRow("RANGE B/S", "$" + DoubleToString(GetBasketProfitByComment("RANGE_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("RANGE_SELL"), 2), 6, clrYellow, clrWhite);

   DrawDashRow("TREND B/S", "$" + DoubleToString(GetBasketProfitByComment("TREND_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("TREND_SELL"), 2), 7, clrYellow, clrWhite);

   DrawDashRow("FAKE B/S", "$" + DoubleToString(GetBasketProfitByComment("FAKE_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("FAKE_SELL"), 2), 8, clrYellow, clrWhite);

   DrawDashRow("SQUEEZE B/S", "$" + DoubleToString(GetBasketProfitByComment("SQUEEZE_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("SQUEEZE_SELL"), 2), 9, clrYellow, clrWhite);

   DrawDashRow("SWEEP B/S", "$" + DoubleToString(GetBasketProfitByComment("SWEEP_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("SWEEP_SELL"), 2), 10, clrYellow, clrWhite);

   DrawDashRow("EXHAUST B/S", "$" + DoubleToString(GetBasketProfitByComment("EXHAUST_BUY"), 2) +
               " / $" + DoubleToString(GetBasketProfitByComment("EXHAUST_SELL"), 2), 11, clrYellow, clrWhite);

   DrawDashRow("BIG ORD", IntegerToString(CountOrdersByComment("BIG_BUY")) + "/" + IntegerToString(CountOrdersByComment("BIG_SELL")), 13, clrDeepSkyBlue, clrWhite);
   DrawDashRow("RANGE ORD", IntegerToString(CountOrdersByComment("RANGE_BUY")) + "/" + IntegerToString(CountOrdersByComment("RANGE_SELL")), 14, clrDeepSkyBlue, clrWhite);
   DrawDashRow("TREND ORD", IntegerToString(CountOrdersByComment("TREND_BUY")) + "/" + IntegerToString(CountOrdersByComment("TREND_SELL")), 15, clrDeepSkyBlue, clrWhite);
   DrawDashRow("FAKE ORD", IntegerToString(CountOrdersByComment("FAKE_BUY")) + "/" + IntegerToString(CountOrdersByComment("FAKE_SELL")), 16, clrDeepSkyBlue, clrWhite);
   DrawDashRow("SQUEEZE ORD", IntegerToString(CountOrdersByComment("SQUEEZE_BUY")) + "/" + IntegerToString(CountOrdersByComment("SQUEEZE_SELL")), 17, clrDeepSkyBlue, clrWhite);
   DrawDashRow("SWEEP ORD", IntegerToString(CountOrdersByComment("SWEEP_BUY")) + "/" + IntegerToString(CountOrdersByComment("SWEEP_SELL")), 18, clrDeepSkyBlue, clrWhite);
   DrawDashRow("EXHAUST ORD", IntegerToString(CountOrdersByComment("EXHAUST_BUY")) + "/" + IntegerToString(CountOrdersByComment("EXHAUST_SELL")), 19, clrDeepSkyBlue, clrWhite);
   DrawDashRow("TYPE9-50 ORD", IntegerToString(CountAdvancedOrders()), 20, clrDeepSkyBlue, clrWhite);

   int trend = GetTrendDirection();
   string trendText = "WAIT";
   color trendColor = clrYellow;

   if(trend == 1)
     {
      trendText = "M5 BUY";
      trendColor = clrLime;
     }
   if(trend == -1)
     {
      trendText = "M5 SELL";
      trendColor = clrRed;
     }

   string bigText = "NO";
   if(lastBigMoveDirection == 1)
      bigText = "BIG UP -> SELL";
   if(lastBigMoveDirection == -1)
      bigText = "BIG DOWN -> BUY";

   DrawDashRow("TREND", trendText, 21, clrYellow, trendColor);
   DrawDashRow("BIG MOVE", bigText, 22, clrYellow, clrWhite);

   DrawDashRow("TP", "0.50 per basket", 24, clrLime, clrLime);
   DrawDashRow("SL", "20.00 per basket", 25, clrRed, clrRed);

   DrawDashRow("Base Lot", DoubleToString(BaseLot, 2), 27, clrOrange, clrYellow);
   DrawDashRow("Recovery Gap", DoubleToString(RecoveryGapPrice, 2), 28, clrOrange, clrYellow);
   DrawDashRow("Big Trigger", DoubleToString(BigMoveMinPrice, 2), 29, clrOrange, clrYellow);
   DrawDashRow("Range", DoubleToString(RangeMinPrice,0) + "-" + DoubleToString(RangeMaxPrice,0), 30, clrOrange, clrYellow);

   DrawDashRow("Balance", "$" + DoubleToString(AccountBalance(), 2), 32, clrWhite, clrWhite);
   DrawDashRow("Equity", "$" + DoubleToString(AccountEquity(), 2), 33, clrWhite, clrWhite);
   DrawDashRow("Free Margin", "$" + DoubleToString(AccountFreeMargin(), 2), 34, clrWhite, clrWhite);
   DrawDashRow("Spread", DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0), 35, clrWhite, clrYellow);

   DrawDashRow("HTF Trend", IntegerToString(GetHTFTrendDirection()), 36, clrWhite, clrYellow);
   DrawDashRow("ATR", DoubleToString(iATR(Symbol(), TradeTF, ATRPeriod, 1), 2), 37, clrWhite, clrYellow);
   DrawDashRow("Risk Gate", UseProfessionalRiskGate ? "ON" : "OFF", 38, clrWhite, UseProfessionalRiskGate ? clrLime : clrRed);
   DrawDashRow("Cooldown", UseSameBasketCooldown ? IntegerToString(SameBasketCooldownSeconds) + " sec" : "OFF", 39, clrWhite, UseSameBasketCooldown ? clrLime : clrRed);

   DrawLabel("DASH_STATUS", "RUNNING 24/7 - 50 TYPES + RISK + COOLDOWN", 300, 590, clrLime, 8);


DrawDashRow(
   "GLOBAL TP",
   "$" + DoubleToString(GlobalBasketTPUSD, 2),
   40,
   clrWhite,
   clrLime
);

DrawDashRow(
   "GLOBAL SL",
   "$" + DoubleToString(GlobalBasketSLUSD, 2),
   41,
   clrWhite,
   clrRed
);

  }
//+------------------------------------------------------------------+



