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

double BaseLot = 0.01;
int    MagicNumber = 20260522;


// ================================================================
//  BALANCE MULTIPLIER ENGINE
//  Example: $100=1x, $200=2x, $300=3x
// ================================================================
bool   UseBalanceMultiplier = true;
double BalanceMultiplierStepUSD = 200.0;
double MinBalanceMultiplier = 1.0;
double MaxBalanceMultiplier = 50.0;
bool   ScaleLotsByBalance = true;
bool   ScaleTPByBalance   = true;
bool   ScaleSLByBalance   = true;

// ================================================================
//  BASKET TP / SL
// ================================================================
double BigBasketTPUSD      = 0.50;
double BigBasketSLUSD      = -20.00;

double RangeBasketTPUSD    = 0.15;
double RangeBasketSLUSD    = -20.00;

double TrendBasketTPUSD    = 0.50;
double TrendBasketSLUSD    = -20.00;

double FakeBasketTPUSD     = 0.50;
double FakeBasketSLUSD     = -20.00;

double SqueezeBasketTPUSD  = 0.50;
double SqueezeBasketSLUSD  = -20.00;

double SweepBasketTPUSD    = 0.50;
double SweepBasketSLUSD    = -20.00;

double ExhaustBasketTPUSD  = 0.50;
double ExhaustBasketSLUSD  = -20.00;

bool   UseGlobalBasketClose = true;

double Type51BasketTPUSD = 0.50;
double Type51BasketSLUSD = -20.00;



double Type52BasketTPUSD = 0.50;
double Type52BasketSLUSD = -20.00;

double AdvancedBasketTPUSD   = 0.50;
double AdvancedBasketSLUSD   = -20.00;

int MaxTotalOpenOrders = 5;
double GlobalBasketTPUSD = 0.50;
double GlobalBasketSLUSD = -30.00;

// ================================================================
//  MAX ORDERS PER BASKET SIDE
// ================================================================
int MaxBigOrdersPerSide     = 1;
int MaxRangeOrdersPerSide   = 5;
int MaxTrendOrdersPerSide   = 5;
int MaxFakeOrdersPerSide    = 1;
int MaxSqueezeOrdersPerSide = 3;
int MaxSweepOrdersPerSide   = 2;
int MaxExhaustOrdersPerSide = 3;

// ================================================================
//  BASIC SETTINGS
// ================================================================
int MaxSpreadPoints = 5000;
int Slippage = 100;

ENUM_TIMEFRAMES TradeTF = PERIOD_M1;
ENUM_TIMEFRAMES TrendTF = PERIOD_M5;

double MinCandleSize = 20.0;
double MaxTrendOrderCandleSize = 100.0;

// ================================================================
//  EMA TREND
// ================================================================
int TrendFastEMA = 9;
int TrendSlowEMA = 21;
double MinTrendEMAGap = 30.0;

// ================================================================
//  TYPE ENABLE/DISABLE
// ================================================================
bool UseBigMomentum       = true;//good
bool UseRangeMomentum     = false;//BIG LOSS No Recovery
bool UseTrendMomentum     = true;//Good
bool UseFakeBreakout      = false;
bool UseCompressionBreak  = false;
bool UseLiquiditySweep    = false;
bool UseTrendExhaustion   = false;
bool UseSessionMode       = false;
bool UseType51MACD = false;
bool   UseAdvancedTypes9To50 = false;//true


bool UseType52EdgeAlgo = false;
bool   UseType21IntradayBooker = false;//Big loss if TREND changed
double DayBasketTPUSD = 5.00;
double DayBasketSLUSD = -20.00;


int    MaxType52OrdersPerSide = 2;
double Type52Lot = 0.01;
double Type52OrderGapPrice = 150.0;

ENUM_TIMEFRAMES EdgeTF = PERIOD_M5;

int EdgeFastEMA  = 21;
int EdgeSlowEMA  = 50;
int EdgeTrendEMA = 200;

int EdgeRSILen   = 14;
double EdgeRSIBuy  = 55;
double EdgeRSISell = 45;

int EdgeATRLen = 14;
double EdgeATRMult = 1.5;


// ================================================================
//  TYPE 1 BIG REVERSAL
// ================================================================
int    BigMoveLookbackBars = 3;
double BigMoveMinPrice = 150.0;
double BigMomentumLot = 0.01;
bool   OnlyOneBigMoveOrderPerBar = true;

// ================================================================
//  TYPE 2 RANGE
// ================================================================
int    RangeLookbackBars = 5;
double RangeMinPrice = 50.0;
double RangeMaxPrice = 180.0;
double RangeOrderGapPrice = 80.0;

// ================================================================
//  TYPE 3 TREND
// ================================================================
double TrendOrderGapPrice = 150.0;

// ================================================================
//  TYPE 4 FAKE BREAKOUT
// ================================================================
int    FakeBreakLookbackBars = 5;
double FakeBreakBufferPrice = 20.0;
double FakeBreakLot = 0.01;

// ================================================================
//  TYPE 5 COMPRESSION BREAKOUT
// ================================================================
int    CompressionATRPeriod = 14;
double CompressionATRMax = 45.0;
double CompressionBreakBuffer = 30.0;
double SqueezeLot = 0.01;

// ================================================================
//  TYPE 6 LIQUIDITY SWEEP
// ================================================================
double SweepWickBodyRatio = 2.0;
double SweepMinWickSize = 80.0;
double SweepLot = 0.01;

// ================================================================
//  TYPE 7 TREND EXHAUSTION
// ================================================================
double ExhaustLot = 0.01;
int    ExhaustBars = 3;

// ================================================================
//  TYPE 8 SESSION MODE - server time
// ================================================================
int AsianStartHour  = 0;
int AsianEndHour    = 8;
int LondonStartHour = 8;
int LondonEndHour   = 14;
int NYStartHour     = 14;
int NYEndHour       = 23;


// ================================================================
//  TYPES 9-50 ADVANCED BTC MARKET STATE ENGINE
// ================================================================

int    MaxAdvancedOrdersPerSide = 1;
double AdvancedLot = 0.01;
double AdvancedOrderGapPrice = 250.0;

// Type 21 intraday profit booker

double DayLot = 0.01;
int    DayMaxHoldMinutes = 60*4;
ENUM_TIMEFRAMES DayTrendTF1 = PERIOD_H1;
ENUM_TIMEFRAMES DayTrendTF2 = PERIOD_M15;
double DayDailyProfitTargetUSD = 5.00;
bool   StopType21AfterDailyTarget = true;
datetime lastType21DailyTargetDate = 0;

// Type 49 dead zone protection
bool   BlockTradingInDeadZone = true;
double DeadZoneATRMax = 25.0;

// Advanced volatility settings
double VolExpansionRatio = 1.80;
double VolCollapseRatio  = 0.50;
double RoundNumberStep   = 500.0;
double RoundNumberBuffer = 60.0;
int    EMACrossLookbackBars = 10;
int    MaxCrossesForNoise = 4;

// ================================================================
//  RECOVERY
// ================================================================
bool   UseRecoveryOrders = true;
double RecoveryGapPrice = 2000.0;
int    MaxRecoveryOrdersPerBasket = 2;
bool   RecoverySameDirection = true;


// ================================================================
//  SAME TYPE + SAME DIRECTION COOLDOWN
// ================================================================
bool UseSameBasketCooldown = true;
int  SameBasketCooldownSeconds = 60*5;

// ================================================================
//  SAFETY
// ================================================================
bool UseEquityProtection = false;
double MinEquityPercent = 60.0;


// ================================================================
//  PROFESSIONAL RISK GATE - BEFORE ANY ORDER
// ================================================================
bool   UseProfessionalRiskGate = true;

// Higher timeframe confirmation
ENUM_TIMEFRAMES HTFTrendTF = PERIOD_M15;
int    HTFFastEMA = 9;
int    HTFSlowEMA = 21;
double MinHTFEMAGap = 50.0;

// Avoid chasing price too far from EMA
double MaxDistanceFromM5EMA = 1200.0;

// ATR spike protection
int    ATRPeriod = 14;
double MaxATRForNewOrder = 900.0;
double MinATRForNewOrder = 20.0;

// Confirmation score
int    MinOrderQualityScore = 3;

// Loss memory protection
bool   UseLossMemoryBlock = true;
double LossMemoryTriggerUSD = -10.0;
int    LossMemoryPauseBars = 5;

datetime lastLossMemoryTime = 0;
string   lastLossMemoryBasket = "";




// ================================================================
//  TYPE 1-50 PERFORMANCE TRACKER
// ================================================================
bool ShowTypePerformancePanel = true;
int  TypePerformanceTopN = 20;
bool ExportTypePerformanceCSV = true;
int  ExportTypePerformanceEverySeconds = 300;
datetime lastTypePerformanceExportTime = 0;

// ================================================================
//  CUMULATIVE TYPE P/L HISTORY
// ================================================================
bool ShowClosedTypePLHistory = true;
bool TodayOnlyTypePLHistory  = true;

// ================================================================
//  LEFT SIDE TYPE P/L SUMMARY PANEL
// ================================================================
bool ShowTypePLSummaryPanel = true;
int  TypeSummaryTopN = 15;

// ================================================================
//  DASHBOARD + EMA
// ================================================================
bool DrawEMALines = true;
int  EMABarsToDraw = 120;
color EMAFastColor = clrLime;
color EMASlowColor = clrRed;

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
#define MODE_MACD_STRATEGY 51
#define MODE_EDGE_ALGO_STRATEGY 52

#define MODE_INTRADAY_STANDALONE 53


int MaxType51OrdersPerSide = 2;
double Type51Lot = 0.01;
double Type51OrderGapPrice = 150.0;

int MACDFastEMA = 12;
int MACDSlowEMA = 26;
int MACDSignalSMA = 9;
ENUM_TIMEFRAMES MACDTF = PERIOD_M5;

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

   if(IsDeadZone())
      return MODE_DEAD_ZONE;
   if(IsNewsChaosMode())
      return MODE_NEWS_CHAOS;
   if(IsHFTNoiseMode())
      return MODE_HFT_NOISE;
   if(IsMTFConflict())
      return MODE_MTF_CONFLICT;

   if(IsVolatilityExpansion())
      return MODE_VOL_EXPANSION;
   if(IsVolatilityCollapse())
      return MODE_VOL_COLLAPSE;

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

   if(IsAccumulationMode())
      return MODE_ACCUMULATION;
   if(IsIntradayBookerMode())
      return MODE_INTRADAY_BOOKER;
   if(IsWeekendTrap())
      return MODE_WEEKEND_TRAP;
   if(IsMondayReset())
      return MODE_MONDAY_RESET;

   if(IsDailyOpenRejectionBuy() || IsDailyOpenRejectionSell())
      return MODE_DAILY_OPEN_REJECT;

   if(IsPreNYAccumulation())
      return MODE_PRE_NY_ACCUM;

   if(IsPostLiquidationReversalBuy() || IsPostLiquidationReversalSell())
      return MODE_POST_LIQ_REVERSAL;

   if(IsFundingFlipMode())
      return MODE_FUNDING_FLIP;

   if(IsWhaleDefenseBuy() || IsWhaleDefenseSell())
      return MODE_WHALE_DEFENSE;

   if(IsLiquidityMagnetBuy() || IsLiquidityMagnetSell())
      return MODE_LIQUIDITY_MAGNET;

   if(IsEMAPinball())
      return MODE_EMA_PINBALL;

   if(IsCascadeLiquidationUp() || IsCascadeLiquidationDown())
      return MODE_CASCADE_LIQ;

   if(IsMicroChannelBuy() || IsMicroChannelSell())
      return MODE_MICRO_CHANNEL;

   if(IsBreakoutFailureRetestBuy() || IsBreakoutFailureRetestSell())
      return MODE_BREAK_FAIL_RETEST;

   if(IsDoubleSweep())
      return MODE_DOUBLE_SWEEP;
   if(IsAsianRangeExpansion())
      return MODE_ASIAN_RANGE_EXP;
   if(IsBTCDominanceProxy())
      return MODE_BTC_DOMINANCE;
   if(IsCorrelationBreakProxy())
      return MODE_CORRELATION_BREAK;
   if(IsNewsAbsorption())
      return MODE_NEWS_ABSORPTION;

   if(IsDelayedReversalBuy() || IsDelayedReversalSell())
      return MODE_DELAYED_REVERSAL;

   if(IsLiquidityLadderBuy() || IsLiquidityLadderSell())
      return MODE_LIQUIDITY_LADDER;

   if(IsRoundNumberMagnet())
      return MODE_ROUND_NUMBER_MAGNET;

   if(IsMidnightFlushBuy() || IsMidnightFlushSell())
      return MODE_MIDNIGHT_FLUSH;

   if(IsTrendAccelerationBuy() || IsTrendAccelerationSell())
      return MODE_TREND_ACCELERATION;

   if(IsExchangeArbitrageProxy())
      return MODE_EXCHANGE_ARBITRAGE;
   if(IsSessionTransitionChaos())
      return MODE_SESSION_TRANSITION;

   if(IsRetailTrapSequenceBuy() || IsRetailTrapSequenceSell())
      return MODE_RETAIL_TRAP_SEQUENCE;

   if(IsDistributionMode())
      return MODE_DISTRIBUTION;





   return MODE_NONE;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsType51MACDBuy()
  {
   double macd1   = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
   double signal1 = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);

   double macd2   = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 2);
   double signal2 = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 2);

   double delta1 = macd1 - signal1;
   double delta2 = macd2 - signal2;

   return (delta2 <= 0 && delta1 > 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsType51MACDSell()
  {
   double macd1   = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 1);
   double signal1 = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 1);

   double macd2   = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_MAIN, 2);
   double signal2 = iMACD(Symbol(), MACDTF, 12, 26, 9, PRICE_CLOSE, MODE_SIGNAL, 2);

   double delta1 = macd1 - signal1;
   double delta2 = macd2 - signal2;

   return (delta2 >= 0 && delta1 < 0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessType51MACD()
  {
   if(IsType51MACDBuy())
     {
      if(CountOrdersByComment("TYPE51_BUY") >= MaxType51OrdersPerSide)
         return;

      if(!CanOpenByGap("TYPE51_BUY", Type51OrderGapPrice))
         return;

      OpenOrder(OP_BUY, Type51Lot, "TYPE51_BUY");
      return;
     }

   if(IsType51MACDSell())
     {
      if(CountOrdersByComment("TYPE51_SELL") >= MaxType51OrdersPerSide)
         return;

      if(!CanOpenByGap("TYPE51_SELL", Type51OrderGapPrice))
         return;

      OpenOrder(OP_SELL, Type51Lot, "TYPE51_SELL");
      return;
     }
  }

//+------------------------------------------------------------------+
void ProcessAdvancedType(int mode)
  {
   if(mode == MODE_INTRADAY_BOOKER && IsType21DailyTargetLocked())
     {
      Print("TYPE 21 blocked: daily target already reached.");
      return;
     }

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
   if(mode == MODE_VOL_EXPANSION)
      return GetTrendDirection();
   if(mode == MODE_VOL_COLLAPSE)
      return GetLastCandleDirection();
   if(mode == MODE_EMA_RECLAIM)
      return IsEMAReclaimBuy() ? 1 : (IsEMAReclaimSell() ? -1 : 0);
   if(mode == MODE_PARABOLIC_SPIKE)
      return IsParabolicSpikeUp() ? -1 : (IsParabolicSpikeDown() ? 1 : 0);
   if(mode == MODE_ORDER_BLOCK_RETEST)
      return IsOrderBlockRetestBuy() ? 1 : (IsOrderBlockRetestSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_VOID)
      return IsLiquidityVoidUp() ? -1 : (IsLiquidityVoidDown() ? 1 : 0);
   if(mode == MODE_STOP_HUNT_ENGINE)
      return IsStopHuntUp() ? -1 : (IsStopHuntDown() ? 1 : 0);
   if(mode == MODE_TREND_STAIRCASE)
      return IsTrendStaircaseBuy() ? 1 : (IsTrendStaircaseSell() ? -1 : 0);
   if(mode == MODE_TREND_FAILURE)
      return IsTrendFailureBuy() ? -1 : (IsTrendFailureSell() ? 1 : 0);
   if(mode == MODE_INTRADAY_BOOKER)
      return GetType21DaySignal();
   if(mode == MODE_WEEKEND_TRAP)
      return -GetLastCandleDirection();
   if(mode == MODE_MONDAY_RESET)
      return -GetLastCandleDirection();
   if(mode == MODE_DAILY_OPEN_REJECT)
      return IsDailyOpenRejectionBuy() ? 1 : (IsDailyOpenRejectionSell() ? -1 : 0);
   if(mode == MODE_POST_LIQ_REVERSAL)
      return IsPostLiquidationReversalBuy() ? 1 : (IsPostLiquidationReversalSell() ? -1 : 0);
   if(mode == MODE_FUNDING_FLIP)
      return -GetLastCandleDirection();
   if(mode == MODE_WHALE_DEFENSE)
      return IsWhaleDefenseBuy() ? 1 : (IsWhaleDefenseSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_MAGNET)
      return IsLiquidityMagnetBuy() ? 1 : (IsLiquidityMagnetSell() ? -1 : 0);
   if(mode == MODE_EMA_PINBALL)
      return GetEMAPinballDirection();
   if(mode == MODE_CASCADE_LIQ)
      return IsCascadeLiquidationUp() ? 1 : (IsCascadeLiquidationDown() ? -1 : 0);
   if(mode == MODE_MICRO_CHANNEL)
      return IsMicroChannelBuy() ? 1 : (IsMicroChannelSell() ? -1 : 0);
   if(mode == MODE_BREAK_FAIL_RETEST)
      return IsBreakoutFailureRetestBuy() ? 1 : (IsBreakoutFailureRetestSell() ? -1 : 0);
   if(mode == MODE_DOUBLE_SWEEP)
      return GetTrendDirection();
   if(mode == MODE_ASIAN_RANGE_EXP)
      return GetTrendDirection();
   if(mode == MODE_BTC_DOMINANCE)
      return GetTrendDirection();
   if(mode == MODE_CORRELATION_BREAK)
      return GetTrendDirection();
   if(mode == MODE_NEWS_ABSORPTION)
      return -GetLastCandleDirection();
   if(mode == MODE_DELAYED_REVERSAL)
      return IsDelayedReversalBuy() ? 1 : (IsDelayedReversalSell() ? -1 : 0);
   if(mode == MODE_LIQUIDITY_LADDER)
      return IsLiquidityLadderBuy() ? 1 : (IsLiquidityLadderSell() ? -1 : 0);
   if(mode == MODE_ROUND_NUMBER_MAGNET)
      return GetRoundNumberDirection();
   if(mode == MODE_MIDNIGHT_FLUSH)
      return IsMidnightFlushBuy() ? 1 : (IsMidnightFlushSell() ? -1 : 0);
   if(mode == MODE_TREND_ACCELERATION)
      return IsTrendAccelerationBuy() ? 1 : (IsTrendAccelerationSell() ? -1 : 0);
   if(mode == MODE_RETAIL_TRAP_SEQUENCE)
      return IsRetailTrapSequenceBuy() ? 1 : (IsRetailTrapSequenceSell() ? -1 : 0);
   if(mode == MODE_DISTRIBUTION)
      return -1;

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
   if(mode == 9)
      return "TYPE 9 VOL EXPANSION";
   if(mode == 10)
      return "TYPE 10 VOL COLLAPSE";
   if(mode == 11)
      return "TYPE 11 EMA RECLAIM";
   if(mode == 12)
      return "TYPE 12 PARABOLIC SPIKE";
   if(mode == 13)
      return "TYPE 13 ORDER BLOCK RETEST";
   if(mode == 14)
      return "TYPE 14 LIQUIDITY VOID";
   if(mode == 15)
      return "TYPE 15 STOP HUNT ENGINE";
   if(mode == 16)
      return "TYPE 16 TREND STAIRCASE";
   if(mode == 17)
      return "TYPE 17 NEWS CHAOS";
   if(mode == 18)
      return "TYPE 18 HEDGE TRAP";
   if(mode == 19)
      return "TYPE 19 TREND FAILURE";
   if(mode == 20)
      return "TYPE 20 ACCUMULATION";
   if(mode == 21)
      return "TYPE 21 INTRADAY BOOKER";
   if(mode == 22)
      return "TYPE 22 WEEKEND TRAP";
   if(mode == 23)
      return "TYPE 23 MONDAY RESET";
   if(mode == 24)
      return "TYPE 24 DAILY OPEN REJECT";
   if(mode == 25)
      return "TYPE 25 PRE-NY ACCUM";
   if(mode == 26)
      return "TYPE 26 POST-LIQ REVERSAL";
   if(mode == 27)
      return "TYPE 27 FUNDING FLIP";
   if(mode == 28)
      return "TYPE 28 WHALE DEFENSE";
   if(mode == 29)
      return "TYPE 29 LIQUIDITY MAGNET";
   if(mode == 30)
      return "TYPE 30 EMA PINBALL";
   if(mode == 31)
      return "TYPE 31 CASCADE LIQ";
   if(mode == 32)
      return "TYPE 32 MICRO CHANNEL";
   if(mode == 33)
      return "TYPE 33 BREAK FAIL RETEST";
   if(mode == 34)
      return "TYPE 34 DOUBLE SWEEP";
   if(mode == 35)
      return "TYPE 35 ASIAN RANGE EXP";
   if(mode == 36)
      return "TYPE 36 HFT NOISE";
   if(mode == 37)
      return "TYPE 37 BTC DOMINANCE";
   if(mode == 38)
      return "TYPE 38 CORRELATION BREAK";
   if(mode == 39)
      return "TYPE 39 NEWS ABSORPTION";
   if(mode == 40)
      return "TYPE 40 DELAYED REVERSAL";
   if(mode == 41)
      return "TYPE 41 LIQUIDITY LADDER";
   if(mode == 42)
      return "TYPE 42 ROUND NUMBER MAGNET";
   if(mode == 43)
      return "TYPE 43 MIDNIGHT FLUSH";
   if(mode == 44)
      return "TYPE 44 TREND ACCEL";
   if(mode == 45)
      return "TYPE 45 ARBITRAGE DISTORT";
   if(mode == 46)
      return "TYPE 46 MTF CONFLICT";
   if(mode == 47)
      return "TYPE 47 SESSION TRANSITION";
   if(mode == 48)
      return "TYPE 48 RETAIL TRAP";
   if(mode == 49)
      return "TYPE 49 DEAD ZONE";
   if(mode == 50)
      return "TYPE 50 DISTRIBUTION";
   if(mode == 51)
      return "TYPE 51 MACD STRATEGY";

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

   if(c > o)
      return 1;
   if(c < o)
      return -1;

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

   if(atrAvg <= 0)
      return false;

   return atrNow >= atrAvg * VolExpansionRatio;
  }

//+------------------------------------------------------------------+
bool IsVolatilityCollapse()
  {
   double atrNow = iATR(Symbol(), TradeTF, ATRPeriod, 1);
   double atrAvg = GetATRAvg(TradeTF, ATRPeriod, 20);

   if(atrAvg <= 0)
      return false;

   return atrNow <= atrAvg * VolCollapseRatio;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsType52CallBuy()
  {
   double close1 = iClose(Symbol(), EdgeTF, 1);

   double emaFast  = iMA(Symbol(), EdgeTF, EdgeFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow  = iMA(Symbol(), EdgeTF, EdgeSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaTrend = iMA(Symbol(), EdgeTF, EdgeTrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   double rsiVal = iRSI(Symbol(), EdgeTF, EdgeRSILen, PRICE_CLOSE, 1);

   bool bullTrend = close1 > emaTrend;

   if(bullTrend && emaFast > emaSlow && rsiVal > EdgeRSIBuy)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessType52EdgeAlgo()
  {
   if(IsType52CallBuy())
     {
      if(CountOrdersByComment("TYPE52_CALL_BUY") >= MaxType52OrdersPerSide)
         return;

      if(!CanOpenByGap("TYPE52_CALL_BUY", Type52OrderGapPrice))
         return;

      OpenOrder(OP_BUY, Type52Lot, "TYPE52_CALL_BUY");
      return;
     }

   if(IsType52PutBuy())
     {
      if(CountOrdersByComment("TYPE52_PUT_BUY") >= MaxType52OrdersPerSide)
         return;

      if(!CanOpenByGap("TYPE52_PUT_BUY", Type52OrderGapPrice))
         return;

      OpenOrder(OP_SELL, Type52Lot, "TYPE52_PUT_BUY");
      return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsType52PutBuy()
  {
   double close1 = iClose(Symbol(), EdgeTF, 1);

   double emaFast  = iMA(Symbol(), EdgeTF, EdgeFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow  = iMA(Symbol(), EdgeTF, EdgeSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaTrend = iMA(Symbol(), EdgeTF, EdgeTrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   double rsiVal = iRSI(Symbol(), EdgeTF, EdgeRSILen, PRICE_CLOSE, 1);

   bool bearTrend = close1 < emaTrend;

   if(bearTrend && emaFast < emaSlow && rsiVal < EdgeRSISell)
      return true;

   return false;
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

   if(impulseBody < BigMoveMinPrice / 2)
      return false;

   return Bid <= impulseLow + 50 && GetTrendDirection() == 1;
  }

//+------------------------------------------------------------------+
bool IsOrderBlockRetestSell()
  {
   double impulseHigh = iHigh(Symbol(), PERIOD_M5, 2);
   double impulseBody = MathAbs(iClose(Symbol(), PERIOD_M5, 2) - iOpen(Symbol(), PERIOD_M5, 2));

   if(impulseBody < BigMoveMinPrice / 2)
      return false;

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

   if(c > emaFast && emaFast > emaSlow)
      return 1;
   if(c < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
int GetType21DaySignal()
  {
   int h1  = GetTrendByTF(DayTrendTF1);
   int m15 = GetTrendByTF(DayTrendTF2);

   if(h1 == 1 && m15 == 1)
      return 1;
   if(h1 == -1 && m15 == -1)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
bool IsIntradayBookerMode()
  {
   if(!UseType21IntradayBooker)
      return false;

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

   if(c > MathMax(e1, e2))
      return 1;
   if(c < MathMin(e1, e2))
      return -1;

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

   if(Bid < nearest)
      return 1;
   if(Bid > nearest)
      return -1;

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
   ObjectsDeleteAll(0, "TYPEPL_");
   ObjectsDeleteAll(0, "TYPEPERF_");
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {

   CheckGlobalBasketClose();
   CheckType21DailyProfitTarget();

   RefreshRates();

   UpdateBigMoveStatus();

   DrawBotEMALines();
   DrawDashboard();
   DrawTypePLSummaryPanel();
   DrawTypePerformancePanel();
   ExportTypePerformanceCSVIfNeeded();

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
   if(mode == MODE_MACD_STRATEGY)
     {
      ProcessType51MACD();
      return;
     }

   if(mode == MODE_EDGE_ALGO_STRATEGY)
     {
      ProcessType52EdgeAlgo();
      return;
     }

   if(mode == MODE_INTRADAY_STANDALONE)
     {
      ProcessIntradayBookerStandalone();
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
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessIntradayBookerStandalone()
  {
   if(IsType21DailyTargetLocked())
     {
      Print("TYPE21 standalone blocked: daily target locked");
      return;
     }

   int signal = GetType21DaySignal();

   if(signal == 1)
     {
      if(CountOrdersByComment("TYPE21_BUY") >= 1)
         return;

      if(!CanOpenByGap("TYPE21_BUY", AdvancedOrderGapPrice))
         return;

      OpenOrder(OP_BUY, DayLot, "TYPE21_BUY");
      return;
     }

   if(signal == -1)
     {
      if(CountOrdersByComment("TYPE21_SELL") >= 1)
         return;

      if(!CanOpenByGap("TYPE21_SELL", AdvancedOrderGapPrice))
         return;

      OpenOrder(OP_SELL, DayLot, "TYPE21_SELL");
      return;
     }
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

      if(UseType51MACD && (IsType51MACDBuy() || IsType51MACDSell()))
         return MODE_MACD_STRATEGY;

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


   if(UseType51MACD && (IsType51MACDBuy() || IsType51MACDSell()))
      return MODE_MACD_STRATEGY;

   if(UseType52EdgeAlgo && (IsType52CallBuy() || IsType52PutBuy()))
      return MODE_EDGE_ALGO_STRATEGY;

   if(UseType21IntradayBooker && IsIntradayBookerMode())
      return MODE_INTRADAY_STANDALONE;

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
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTrendClean(int direction)
  {
   double emaFast = iMA(Symbol(), TrendTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1  = iClose(Symbol(), TrendTF, 1);





//====================================================
// M15 HIGHER TIMEFRAME FILTER
//====================================================

   double m15EmaFast = iMA(Symbol(), PERIOD_M15, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double m15EmaSlow = iMA(Symbol(), PERIOD_M15, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   double m15Close = iClose(Symbol(), PERIOD_M15, 0);

// distance from slow EMA
   double m15Dist = MathAbs(m15Close - m15EmaSlow);




// SELL only: price below both EMA lines
   if(direction == -1)
     {
      if(!(close1 < emaFast && close1 < emaSlow))
         return false;

      // EMA9 must be below EMA21
      if(!(emaFast < emaSlow))
         return false;
     }

// BUY only: opposite condition
   if(direction == 1)
     {
      if(!(close1 > emaFast && close1 > emaSlow))
         return false;

      // EMA9 must be above EMA21
      if(!(emaFast > emaSlow))
         return false;
     }

   double emaGap = MathAbs(emaFast - emaSlow);

   if(emaGap < MinTrendEMAGap)
      return false;

   double distFast = MathAbs(close1 - emaFast);
   double distSlow = MathAbs(close1 - emaSlow);

// price must stay away from both EMA lines
   if(distFast < MinPriceAwayFromEMA || distSlow < MinPriceAwayFromEMA)
      return false;

// block if EMA crossing too much
   if(CountEMACrosses(10) >= 2)
      return false;

// last 3 candles direction filter
   int sameCount = 0;

   for(int i = 1; i <= 3; i++)
     {
      double o = iOpen(Symbol(), TrendTF, i);
      double c = iClose(Symbol(), TrendTF, i);

      if(direction == 1 && c > o)
         sameCount++;
      if(direction == -1 && c < o)
         sameCount++;
     }

   if(sameCount < 2)
      return false;

   Print("M15 EMA distance = ", m15Dist/100);

// minimum strong trend distance
   if(!IsPriceAwayFromEMAs(90))
     {
      Print("Trend blocked: M15 distance too small = ", m15Dist);
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPriceAwayFromEMAs(double minDistance)
  {
   double ema9  = iMA(Symbol(), PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema21 = iMA(Symbol(), PERIOD_M1, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   double ema211 = iMA(Symbol(), PERIOD_M5, 51, 0, MODE_EMA, PRICE_CLOSE, 0);


   double dist9  = MathAbs(Bid - ema9);
   double dist21 = MathAbs(Bid - ema21);

   datetime candleTime = iTime(Symbol(), PERIOD_M1, 0);

   minDistance=90;
   double totalDist = dist9 + dist21;

   Print("Current price distance from EMAs: EMA9=", dist9, " EMA21=", dist21, " Total=", totalDist);

   if((dist9 >= minDistance && dist21 >= minDistance &&  totalDist < 500) || (totalDist > 250 && totalDist < 500))
      return true;



   return false;
  }

double MinPriceAwayFromEMA = 30;   // raw price distance, not points
int    TrendSLBlockMinutes = 30;

datetime LastTrendSLTime = 0;

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

   if(trend == 1 && IsTrendClean(1))

     {
      if(CountOrdersByComment("TREND_BUY") >= MaxTrendOrdersPerSide)
         return;

      if(!CanOpenByGap("TREND_BUY", TrendOrderGapPrice))
         return;

      OpenOrder(OP_BUY, BaseLot, "TREND_BUY");
      return;
     }

   if(trend == -1 && IsTrendClean(-1))

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

datetime lastTime = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSameBasketCooldownActive(string commentText)
  {
   if(!UseSameBasketCooldown)
      return false;


   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(IsCommentBasketMatch(OrderComment(), commentText))
              {
               // if(OrderCloseTime() > lastTime)
               // lastTime = OrderCloseTime();
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
//| Balance Multiplier Engine                                       |
//| $100 = 1x, $200 = 2x, $300 = 3x                                 |
//+------------------------------------------------------------------+
double GetBalanceMultiplier()
  {
   if(!UseBalanceMultiplier)
      return 1.0;

   double step = BalanceMultiplierStepUSD;

   if(step <= 0)
      step = 200.0;

   double mult = MathFloor(AccountBalance() / step);

   if(mult < MinBalanceMultiplier)
      mult = MinBalanceMultiplier;

   if(MaxBalanceMultiplier > 0 && mult > MaxBalanceMultiplier)
      mult = MaxBalanceMultiplier;

   return NormalizeDouble(mult, 2);
  }

//+------------------------------------------------------------------+
double GetDynamicLot(double baseLot)
  {
   if(!ScaleLotsByBalance)
      return NormalizeDouble(baseLot, 2);

   double lot = baseLot * GetBalanceMultiplier();

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0)
      lotStep = 0.01;

   lot = MathFloor(lot / lotStep) * lotStep;

   if(lot < minLot)
      lot = minLot;

   if(lot > maxLot)
      lot = maxLot;

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
double GetDynamicTP(double baseTP)
  {
   if(!ScaleTPByBalance)
      return NormalizeDouble(baseTP, 2);

   return NormalizeDouble(baseTP * GetBalanceMultiplier(), 2);
  }

//+------------------------------------------------------------------+
double GetDynamicSL(double baseSL)
  {
   if(!ScaleSLByBalance)
      return NormalizeDouble(baseSL, 2);

   return NormalizeDouble(baseSL * GetBalanceMultiplier(), 2);
  }

//+------------------------------------------------------------------+
double GetDynamicMoneyValue(double baseValue)
  {
   if(baseValue >= 0)
      return GetDynamicTP(baseValue);

   return GetDynamicSL(baseValue);
  }

//+------------------------------------------------------------------+
//| Total open orders protection                                     |
//+------------------------------------------------------------------+
bool CanOpenMoreOrders()
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            total++;
           }
        }
     }

   if(total >= MaxTotalOpenOrders)
     {
      Print("MAX OPEN ORDERS REACHED = ", total);
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
void OpenOrder(int type, double lot, string commentText)
  {

   if(!CanOpenMoreOrders())
      return;

   RefreshRates();

   lot = GetDynamicLot(lot);

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

   CheckBasketComment("TYPE51_BUY",  Type51BasketTPUSD, Type51BasketSLUSD);
   CheckBasketComment("TYPE51_SELL", Type51BasketTPUSD, Type51BasketSLUSD);

   CheckBasketComment("TYPE52_CALL_BUY", Type52BasketTPUSD, Type52BasketSLUSD);
   CheckBasketComment("TYPE52_PUT_BUY",  Type52BasketTPUSD, Type52BasketSLUSD);

   CheckBasketComment("TYPE21_BUY",  DayBasketTPUSD, DayBasketSLUSD);
   CheckBasketComment("TYPE21_SELL", DayBasketTPUSD, DayBasketSLUSD);



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
   tp = GetDynamicTP(tp);

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
   else
      if(basketMinutes > 120)
         dynamicSL = -10.0;

      // 2-4 hours
      else
         if(basketMinutes > 240)
            dynamicSL = -15.0;

         // more than 4 hours
         else
            dynamicSL = -20.0;

   dynamicSL = GetDynamicSL(dynamicSL);

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
   tp = GetDynamicTP(tp);
   sl = GetDynamicSL(sl);
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

               lastTime = TimeCurrent();


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
//| TYPE 21 Intraday Daily Profit Target                            |
//| Closes DAY_BUY + DAY_SELL when daily target is reached           |
//+------------------------------------------------------------------+
double GetType21DailyClosedProfit()
  {
   double total = 0.0;
   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber &&
            OrderCloseTime() >= todayStart)
           {
            if(IsCommentBasketMatch(OrderComment(), "TYPE21_BUY") ||
               IsCommentBasketMatch(OrderComment(), "TYPE21_SELL") ||
               IsCommentBasketMatch(OrderComment(), "DAY_BUY") ||
               IsCommentBasketMatch(OrderComment(), "DAY_SELL"))
              {
               total += OrderProfit() + OrderSwap() + OrderCommission();
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
double GetType21OpenProfit()
  {
   return GetBasketProfitByComment("TYPE21_BUY") +
          GetBasketProfitByComment("TYPE21_SELL") +
          GetBasketProfitByComment("DAY_BUY") +
          GetBasketProfitByComment("DAY_SELL");
  }

//+------------------------------------------------------------------+
double GetType21TodayTotalProfit()
  {
   return GetType21DailyClosedProfit() + GetType21OpenProfit();
  }

//+------------------------------------------------------------------+
bool IsType21DailyTargetLocked()
  {
   if(!StopType21AfterDailyTarget)
      return false;

   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   if(lastType21DailyTargetDate >= todayStart)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
void CheckType21DailyProfitTarget()
  {
   double dynamicTarget = GetDynamicTP(DayDailyProfitTargetUSD);
   double todayPL = GetType21TodayTotalProfit();

   if(todayPL >= dynamicTarget)
     {
      Print("TYPE 21 DAILY PROFIT TARGET HIT. TodayPL=", todayPL,
            " Target=", dynamicTarget,
            " Closing Type21 intraday orders.");

      CloseOrdersByComment("TYPE21_BUY");
      CloseOrdersByComment("TYPE21_SELL");
      CloseOrdersByComment("DAY_BUY");
      CloseOrdersByComment("DAY_SELL");

      lastType21DailyTargetDate = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));
     }
  }

//+------------------------------------------------------------------+
void CheckGlobalBasketClose()
  {


// CheckTimedIndividualClose();

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

   double dynamicGlobalTP = GetDynamicTP(GlobalBasketTPUSD);
   double dynamicGlobalSL = GetDynamicSL(GlobalBasketSLUSD);

// GLOBAL TAKE PROFIT
   if(totalProfit >= dynamicGlobalTP)
     {
      Print("GLOBAL TP HIT: ", totalProfit);

      CloseAllEAOrders();

      return;
     }

// GLOBAL STOP LOSS
   if(totalProfit <= dynamicGlobalSL)
     {
      Print("GLOBAL SL HIT: ", totalProfit);

      CloseAllEAOrders();

      return;
     }
  }
bool   UseTimedIndividualClose = true;
int    StartCloseAfterHours    = 5;
double LossPerHourUSD          = 1.0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
/*
void CheckTimedIndividualClose()
  {
   if(!UseTimedIndividualClose)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      double orderProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();

      double openHours = (TimeCurrent() - OrderOpenTime()) / 3600.0;

      if(openHours < StartCloseAfterHours)
         continue;

      int fullHours = (int)MathFloor(openHours);

      double allowedLoss = -1.0 * fullHours * LossPerHourUSD;

      // Example:
      // 5 hours = close if loss > -5
      // 6 hours = close if loss > -6
      if(orderProfit > allowedLoss && fullHours>4)
        {
         Print("Timed individual close. Ticket=", OrderTicket(),
               " Hours=", fullHours,
               " Profit=", orderProfit,
               " AllowedLoss=", allowedLoss);

         bool closed = false;

         if(OrderType() == OP_BUY)
            closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrAqua);

         if(OrderType() == OP_SELL)
            closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrOrange);

         if(!closed)
            Print("Timed close failed. Ticket=", OrderTicket(),
                  " Error=", GetLastError());
        }
     }
  }*/
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
   CloseOrdersByComment("TYPE51_BUY");
   CloseOrdersByComment("TYPE51_SELL");

   CloseOrdersByComment("TYPE52_CALL_BUY");
   CloseOrdersByComment("TYPE52_PUT_BUY");

   CloseOrdersByComment("TYPE21_BUY");
   CloseOrdersByComment("TYPE21_SELL");

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

   if(mode == MODE_MACD_STRATEGY)
      return "TYPE 51 MACD STRATEGY";

   if(mode == MODE_INTRADAY_STANDALONE)
      return "TYPE 21 INTRADAY STANDALONE";

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
//| TYPE P/L SUMMARY FUNCTIONS                                       |
//+------------------------------------------------------------------+
string GetBaseTypeBuyComment(int typeNo)
  {
   if(typeNo == 1)
      return "BIG_BUY";
   if(typeNo == 2)
      return "RANGE_BUY";
   if(typeNo == 3)
      return "TREND_BUY";
   if(typeNo == 4)
      return "FAKE_BUY";
   if(typeNo == 5)
      return "SQUEEZE_BUY";
   if(typeNo == 6)
      return "SWEEP_BUY";
   if(typeNo == 7)
      return "EXHAUST_BUY";

   return GetAdvancedBuyComment(typeNo);
  }

//+------------------------------------------------------------------+
string GetBaseTypeSellComment(int typeNo)
  {
   if(typeNo == 1)
      return "BIG_SELL";
   if(typeNo == 2)
      return "RANGE_SELL";
   if(typeNo == 3)
      return "TREND_SELL";
   if(typeNo == 4)
      return "FAKE_SELL";
   if(typeNo == 5)
      return "SQUEEZE_SELL";
   if(typeNo == 6)
      return "SWEEP_SELL";
   if(typeNo == 7)
      return "EXHAUST_SELL";

   return GetAdvancedSellComment(typeNo);
  }

//+------------------------------------------------------------------+
string GetTypeShortName(int typeNo)
  {
   if(typeNo == 1)
      return "BIG";
   if(typeNo == 2)
      return "RANGE";
   if(typeNo == 3)
      return "TREND";
   if(typeNo == 4)
      return "FAKE";
   if(typeNo == 5)
      return "SQUEEZE";
   if(typeNo == 6)
      return "SWEEP";
   if(typeNo == 7)
      return "EXHAUST";
   if(typeNo == 8)
      return "SESSION";
   if(typeNo == 9)
      return "VOL_EXP";
   if(typeNo == 10)
      return "VOL_COLL";
   if(typeNo == 11)
      return "EMA_REC";
   if(typeNo == 12)
      return "PARA";
   if(typeNo == 13)
      return "OB_RETEST";
   if(typeNo == 14)
      return "VOID";
   if(typeNo == 15)
      return "STOPHUNT";
   if(typeNo == 16)
      return "STAIR";
   if(typeNo == 17)
      return "NEWS";
   if(typeNo == 18)
      return "HEDGE";
   if(typeNo == 19)
      return "FAIL";
   if(typeNo == 20)
      return "ACCUM";
   if(typeNo == 21)
      return "DAY";
   if(typeNo == 22)
      return "WEEKEND";
   if(typeNo == 23)
      return "MONDAY";
   if(typeNo == 24)
      return "D_OPEN";
   if(typeNo == 25)
      return "PRE_NY";
   if(typeNo == 26)
      return "POST_LIQ";
   if(typeNo == 27)
      return "FUND";
   if(typeNo == 28)
      return "WHALE";
   if(typeNo == 29)
      return "MAGNET";
   if(typeNo == 30)
      return "PINBALL";
   if(typeNo == 31)
      return "CASCADE";
   if(typeNo == 32)
      return "CHANNEL";
   if(typeNo == 33)
      return "FAIL_RE";
   if(typeNo == 34)
      return "DBL_SWEEP";
   if(typeNo == 35)
      return "ASIA_EXP";
   if(typeNo == 36)
      return "HFT";
   if(typeNo == 37)
      return "DOM";
   if(typeNo == 38)
      return "CORR";
   if(typeNo == 39)
      return "ABSORB";
   if(typeNo == 40)
      return "DELAY";
   if(typeNo == 41)
      return "LADDER";
   if(typeNo == 42)
      return "ROUND";
   if(typeNo == 43)
      return "MIDNIGHT";
   if(typeNo == 44)
      return "ACCEL";
   if(typeNo == 45)
      return "ARBIT";
   if(typeNo == 46)
      return "MTF";
   if(typeNo == 47)
      return "TRANS";
   if(typeNo == 48)
      return "TRAP";
   if(typeNo == 49)
      return "DEAD";
   if(typeNo == 50)
      return "DIST";

   return "TYPE";
  }

//+------------------------------------------------------------------+
double GetTypeProfit(int typeNo)
  {
   if(typeNo == 8)
      return 0.0;

   return GetTypeOpenProfit(typeNo) + GetTypeClosedProfit(typeNo);
  }

//+------------------------------------------------------------------+
//| Current open floating P/L by Type                                |
//+------------------------------------------------------------------+
double GetTypeOpenProfit(int typeNo)
  {
   if(typeNo == 8)
      return 0.0;

   return GetBasketProfitByComment(GetBaseTypeBuyComment(typeNo)) +
          GetBasketProfitByComment(GetBaseTypeSellComment(typeNo));
  }

//+------------------------------------------------------------------+
//| Closed historical P/L by Type                                    |
//| Keeps cumulative P/L even after basket/order is closed           |
//+------------------------------------------------------------------+
double GetTypeClosedProfit(int typeNo)
  {
   if(!ShowClosedTypePLHistory)
      return 0.0;

   if(typeNo == 8)
      return 0.0;

   double total = 0.0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);

   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               total += OrderProfit() + OrderSwap() + OrderCommission();
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
//| Closed order count by Type                                       |
//+------------------------------------------------------------------+
int GetTypeClosedOrderCount(int typeNo)
  {
   if(!ShowClosedTypePLHistory)
      return 0;

   if(typeNo == 8)
      return 0;

   int total = 0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);

   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               total++;
              }
           }
        }
     }

   return total;
  }


//+------------------------------------------------------------------+
int GetTypeOrderCount(int typeNo)
  {
   if(typeNo == 8)
      return 0;

   return CountOrdersByComment(GetBaseTypeBuyComment(typeNo)) +
          CountOrdersByComment(GetBaseTypeSellComment(typeNo)) +
          GetTypeClosedOrderCount(typeNo);
  }

//+------------------------------------------------------------------+
int GetTopProfitType()
  {
   double bestProfit = -999999.0;
   int bestType = 0;

   for(int t = 1; t <= 50; t++)
     {
      if(t == 8)
         continue;

      double p = GetTypeProfit(t);

      if(p > bestProfit)
        {
         bestProfit = p;
         bestType = t;
        }
     }

   return bestType;
  }

//+------------------------------------------------------------------+
double GetAllTypesProfit()
  {
   double total = 0;

   for(int t = 1; t <= 50; t++)
     {
      if(t == 8)
         continue;

      total += GetTypeProfit(t);
     }

   return total;
  }

//+------------------------------------------------------------------+
void SortTypesByProfit(int &types[], double &profits[], int size)
  {
   for(int i = 0; i < size - 1; i++)
     {
      for(int j = i + 1; j < size; j++)
        {
         if(profits[j] > profits[i])
           {
            double p = profits[i];
            profits[i] = profits[j];
            profits[j] = p;

            int t = types[i];
            types[i] = types[j];
            types[j] = t;
           }
        }
     }
  }

//+------------------------------------------------------------------+
void DrawTypePLLabel(string name, string text, int x, int y, color clr, int fontSize = 8)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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
void DrawTypePLPanel(string name, int x, int y, int w, int h, color bg)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
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
void DrawTypePLSummaryPanel()
  {

   return ;
   if(!ShowTypePLSummaryPanel)
      return;

   int types[49];
   double profits[49];

   int idx = 0;

   for(int t = 1; t <= 50; t++)
     {
      if(t == 8)
         continue;

      types[idx] = t;
      profits[idx] = GetTypeProfit(t);
      idx++;
     }

   SortTypesByProfit(types, profits, 49);

   int panelX = 10;
   int panelY = 20;
   int panelW = 295;
   int panelH = 60 + (TypeSummaryTopN + 5) * 15;

   DrawTypePLPanel("TYPEPL_BG", panelX, panelY, panelW, panelH, clrBlack);
   DrawTypePLLabel("TYPEPL_TITLE", "CUMULATIVE TYPE P/L SUMMARY", panelX + 8, panelY + 8, clrYellow, 9);

   int topType = GetTopProfitType();
   double topProfit = GetTypeProfit(topType);
   color topColor = topProfit >= 0 ? clrLime : clrRed;

   DrawTypePLLabel(
      "TYPEPL_TOP",
      "TOP: TYPE " + IntegerToString(topType) + " " + GetTypeShortName(topType) +
      "  $" + DoubleToString(topProfit, 2),
      panelX + 8,
      panelY + 25,
      topColor,
      8
   );

   DrawTypePLLabel(
      "TYPEPL_TOTAL",
      "TOTAL CUM P/L: $" + DoubleToString(GetAllTypesProfit(), 2),
      panelX + 8,
      panelY + 40,
      GetAllTypesProfit() >= 0 ? clrLime : clrRed,
      8
   );

   DrawTypePLLabel("TYPEPL_HISTORY_MODE", TodayOnlyTypePLHistory ? "MODE: TODAY CLOSED + OPEN" : "MODE: ALL HISTORY + OPEN", panelX + 8, panelY + 56, clrSilver, 8);

   DrawTypePLLabel("TYPEPL_HEAD", "TYPE   NAME     ORD   OPEN   TOTAL", panelX + 8, panelY + 72, clrAqua, 8);

   int rows = TypeSummaryTopN;

   if(rows > 49)
      rows = 49;

   for(int r = 0; r < rows; r++)
     {
      int typeNo = types[r];
      double p = profits[r];
      int orders = GetTypeOrderCount(typeNo);

      color rowColor = clrWhite;

      if(p > 0)
         rowColor = clrLime;
      else
         if(p < 0)
            rowColor = clrRed;

      double openPL = GetTypeOpenProfit(typeNo);

      string line =
         "T" + IntegerToString(typeNo) + " " +
         GetTypeShortName(typeNo) + " " +
         IntegerToString(orders) + " $" +
         DoubleToString(openPL, 2) + " $" +
         DoubleToString(p, 2);

      DrawTypePLLabel(
         "TYPEPL_ROW_" + IntegerToString(r),
         line,
         panelX + 8,
         panelY + 90 + r * 15,
         rowColor,
         8
      );
     }
  }



//+------------------------------------------------------------------+
//| TYPE 1-50 PERFORMANCE TRACKER                                    |
//+------------------------------------------------------------------+
double GetTypeClosedGrossProfit(int typeNo)
  {
   double total = 0.0;

   if(typeNo == 8)
      return 0.0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);
   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               double p = OrderProfit() + OrderSwap() + OrderCommission();

               if(p > 0)
                  total += p;
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
double GetTypeClosedGrossLoss(int typeNo)
  {
   double total = 0.0;

   if(typeNo == 8)
      return 0.0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);
   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               double p = OrderProfit() + OrderSwap() + OrderCommission();

               if(p < 0)
                  total += p;
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
int GetTypeWinCount(int typeNo)
  {
   int total = 0;

   if(typeNo == 8)
      return 0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);
   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               double p = OrderProfit() + OrderSwap() + OrderCommission();

               if(p > 0)
                  total++;
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
int GetTypeLossCount(int typeNo)
  {
   int total = 0;

   if(typeNo == 8)
      return 0;

   string buyComment  = GetBaseTypeBuyComment(typeNo);
   string sellComment = GetBaseTypeSellComment(typeNo);
   datetime todayStart = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(TodayOnlyTypePLHistory && OrderCloseTime() < todayStart)
               continue;

            if(IsCommentBasketMatch(OrderComment(), buyComment) ||
               IsCommentBasketMatch(OrderComment(), sellComment))
              {
               double p = OrderProfit() + OrderSwap() + OrderCommission();

               if(p < 0)
                  total++;
              }
           }
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
double GetTypeWinRate(int typeNo)
  {
   int wins = GetTypeWinCount(typeNo);
   int losses = GetTypeLossCount(typeNo);
   int total = wins + losses;

   if(total <= 0)
      return 0.0;

   return (100.0 * wins) / total;
  }

//+------------------------------------------------------------------+
double GetTypeProfitFactor(int typeNo)
  {
   double gp = GetTypeClosedGrossProfit(typeNo);
   double gl = MathAbs(GetTypeClosedGrossLoss(typeNo));

   if(gl <= 0.0)
     {
      if(gp > 0.0)
         return 99.99;

      return 0.0;
     }

   return gp / gl;
  }

//+------------------------------------------------------------------+
double GetTypeAvgClosedPL(int typeNo)
  {
   int closed = GetTypeClosedOrderCount(typeNo);

   if(closed <= 0)
      return 0.0;

   return GetTypeClosedProfit(typeNo) / closed;
  }

//+------------------------------------------------------------------+
double GetTypeScore(int typeNo)
  {
   double totalPL = GetTypeProfit(typeNo);
   double winRate = GetTypeWinRate(typeNo);
   double pf = GetTypeProfitFactor(typeNo);
   int orders = GetTypeOrderCount(typeNo);

   return totalPL + (winRate / 10.0) + pf + (orders * 0.05);
  }

//+------------------------------------------------------------------+
void SortTypesByScore(int &types[], double &scores[], int size)
  {
   for(int i = 0; i < size - 1; i++)
     {
      for(int j = i + 1; j < size; j++)
        {
         if(scores[j] > scores[i])
           {
            double s = scores[i];
            scores[i] = scores[j];
            scores[j] = s;

            int t = types[i];
            types[i] = types[j];
            types[j] = t;
           }
        }
     }
  }

//+------------------------------------------------------------------+
void DrawTypePerformanceLabel(string name, string text, int x, int y, color clr, int fontSize = 8)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
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
void DrawTypePerformancePanelBg(string name, int x, int y, int w, int h, color bg)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
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
void DrawTypePerformancePanel()
  {
   if(!ShowTypePerformancePanel)
      return;

   int types[49];
   double scores[49];

   int idx = 0;

   for(int t = 1; t <= 50; t++)
     {
      if(t == 8)
         continue;

      types[idx] = t;
      scores[idx] = GetTypeScore(t);
      idx++;
     }

   SortTypesByScore(types, scores, 49);

   int rows = TypePerformanceTopN;

   if(rows > 49)
      rows = 49;

   int panelX = 10;
   int panelY = 25;
   int panelW = 430;
   int panelH = 45 + (rows + 3) * 15;

   DrawTypePerformancePanelBg("TYPEPERF_BG", panelX, panelY, panelW, panelH, clrBlack);

// CORNER_LEFT_LOWER uses y-distance from bottom, so larger y is visually higher.
   int y = panelY + panelH - 20;

   DrawTypePerformanceLabel("TYPEPERF_TITLE", "TYPE PERFORMANCE | CLOSED + OPEN", panelX + 8, y, clrYellow, 9);
   y -= 18;

   DrawTypePerformanceLabel("TYPEPERF_MODE", TodayOnlyTypePLHistory ? "MODE: TODAY HISTORY" : "MODE: FULL HISTORY", panelX + 8, y, clrSilver, 8);
   y -= 18;

   DrawTypePerformanceLabel("TYPEPERF_HEAD", "TYPE NAME    ORD  WIN%  PF    AVG    OPEN    TOTAL", panelX + 8, y, clrAqua, 8);
   y -= 15;

   for(int r = 0; r < rows; r++)
     {
      int typeNo = types[r];

      int orders = GetTypeOrderCount(typeNo);
      double wr = GetTypeWinRate(typeNo);
      double pf = GetTypeProfitFactor(typeNo);
      double avg = GetTypeAvgClosedPL(typeNo);
      double openPL = GetTypeOpenProfit(typeNo);
      double totalPL = GetTypeProfit(typeNo);

      color rowColor = clrWhite;

      if(totalPL > 0)
         rowColor = clrLime;
      else
         if(totalPL < 0)
            rowColor = clrRed;

      string line =
         "T" + IntegerToString(typeNo) + " " +
         GetTypeShortName(typeNo) + " " +
         IntegerToString(orders) + " " +
         DoubleToString(wr, 0) + "% " +
         DoubleToString(pf, 2) + " $" +
         DoubleToString(avg, 2) + " $" +
         DoubleToString(openPL, 2) + " $" +
         DoubleToString(totalPL, 2);

      DrawTypePerformanceLabel(
         "TYPEPERF_ROW_" + IntegerToString(r),
         line,
         panelX + 8,
         y,
         rowColor,
         8
      );

      y -= 15;
     }
  }

//+------------------------------------------------------------------+
void ExportTypePerformanceCSVIfNeeded()
  {
   if(!ExportTypePerformanceCSV)
      return;

   if(TimeCurrent() - lastTypePerformanceExportTime < ExportTypePerformanceEverySeconds)
      return;

   lastTypePerformanceExportTime = TimeCurrent();

   string fileName = "BTC_Type_Performance_" + Symbol() + "_" + IntegerToString(MagicNumber) + ".csv";

   int handle = FileOpen(fileName, FILE_CSV | FILE_WRITE, ',');

   if(handle == INVALID_HANDLE)
     {
      Print("Type performance CSV open failed. Error=", GetLastError());
      return;
     }

   FileWrite(
      handle,
      "Time",
      "Symbol",
      "Type",
      "Name",
      "Orders",
      "Wins",
      "Losses",
      "WinRate",
      "ProfitFactor",
      "AvgClosedPL",
      "OpenPL",
      "ClosedPL",
      "TotalPL"
   );

   for(int t = 1; t <= 50; t++)
     {
      if(t == 8)
         continue;

      FileWrite(
         handle,
         TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS),
         Symbol(),
         t,
         GetTypeShortName(t),
         GetTypeOrderCount(t),
         GetTypeWinCount(t),
         GetTypeLossCount(t),
         DoubleToString(GetTypeWinRate(t), 2),
         DoubleToString(GetTypeProfitFactor(t), 2),
         DoubleToString(GetTypeAvgClosedPL(t), 2),
         DoubleToString(GetTypeOpenProfit(t), 2),
         DoubleToString(GetTypeClosedProfit(t), 2),
         DoubleToString(GetTypeProfit(t), 2)
      );
     }

   FileClose(handle);
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
//|                                                                  |
//+------------------------------------------------------------------+
string OnOff(bool value)
  {
   return value ? "ON" : "OFF";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   DrawPanel("DASH_BG_PANEL", 310, 15, 310, 560, clrBlack);

   DrawLabel("DASH_TITLE", "BTC MOMENTUM EA", 300, 20, clrYellow, 9);

// ================================
// PART 1: RUNNING / LIVE VALUES
// ================================
   DrawDashRow("=== LIVE ===", "", 2, clrAqua, clrAqua);

   DrawDashRow("MODE", ModeText(), 3, clrOrange, clrWhite);
   DrawDashRow("SESSION", SessionText(), 4, clrOrange, clrLime);

   DrawDashRow("GLOBAL P/L",
               "$" + DoubleToString(GetAllEAProfit(), 2),
               6,
               clrWhite,
               GetAllEAProfit() >= 0 ? clrLime : clrRed
              );

   DrawDashRow("ORDERS",
               IntegerToString(CountEAOrders()) + " / " + IntegerToString(MaxTotalOpenOrders),
               7,
               clrDeepSkyBlue,
               clrWhite
              );

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

   int htfTrend = GetHTFTrendDirection();
   string htfText = "WAIT";
   color htfColor = clrYellow;

   if(htfTrend == 1)
     {
      htfText = "M15 BUY";
      htfColor = clrLime;
     }
   if(htfTrend == -1)
     {
      htfText = "M15 SELL";
      htfColor = clrRed;
     }

   DrawDashRow("M5 TREND", trendText, 9, clrWhite, trendColor);
   DrawDashRow("HTF TREND", htfText, 10, clrWhite, htfColor);

   DrawDashRow("SPREAD",
               DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0),
               12,
               clrWhite,
               clrYellow
              );

   DrawDashRow("ATR",
               DoubleToString(iATR(Symbol(), TradeTF, ATRPeriod, 1), 2),
               13,
               clrWhite,
               clrYellow
              );

   DrawDashRow("BAL/EQ",
               "$" + DoubleToString(AccountBalance(), 2) +
               " / $" + DoubleToString(AccountEquity(), 2),
               15,
               clrWhite,
               clrYellow
              );

   DrawDashRow("T21 DAY P/L",
               "$" + DoubleToString(GetType21TodayTotalProfit(), 2),
               16,
               clrWhite,
               GetType21TodayTotalProfit() >= 0 ? clrLime : clrRed
              );

   DrawDashRow("T21 LOCK",
               IsType21DailyTargetLocked() ? "LOCKED" : "OPEN",
               17,
               clrWhite,
               IsType21DailyTargetLocked() ? clrRed : clrLime
              );

// ================================
// PART 2: SETTINGS / ENABLED STATUS
// ================================
   DrawDashRow("=== SETTINGS ===", "", 20, clrAqua, clrAqua);

   DrawDashRow("CORE",
               "BIG:" + OnOff(UseBigMomentum) +
               " RNG:" + OnOff(UseRangeMomentum),
               21,
               clrWhite,
               clrYellow
              );

   DrawDashRow("MOMENTUM",
               "TRD:" + OnOff(UseTrendMomentum) +
               " FAKE:" + OnOff(UseFakeBreakout),
               22,
               clrWhite,
               clrYellow
              );

   DrawDashRow("BREAK/SWEEP",
               "SQZ:" + OnOff(UseCompressionBreak) +
               " SWP:" + OnOff(UseLiquiditySweep),
               23,
               clrWhite,
               clrYellow
              );

   DrawDashRow("ADVANCED",
               "EXH:" + OnOff(UseTrendExhaustion) +
               " SES:" + OnOff(UseSessionMode),
               24,
               clrWhite,
               clrYellow
              );

   DrawDashRow("TYPE 21",
               "ADV:" + OnOff(UseAdvancedTypes9To50) +
               " T21:" + OnOff(UseType21IntradayBooker),
               25,
               clrWhite,
               (UseAdvancedTypes9To50 && UseType21IntradayBooker) ? clrLime : clrRed
              );

   DrawDashRow("TYPE 51/52",
               "MACD:" + OnOff(UseType51MACD) +
               " EDGE:" + OnOff(UseType52EdgeAlgo),
               26,
               clrWhite,
               (UseType51MACD || UseType52EdgeAlgo) ? clrLime : clrRed
              );

   DrawDashRow("GLOBAL TP/SL",
               "$" + DoubleToString(GetDynamicTP(GlobalBasketTPUSD), 2) +
               " / $" + DoubleToString(GetDynamicSL(GlobalBasketSLUSD), 2),
               28,
               clrWhite,
               clrYellow
              );

   DrawDashRow("LOT",
               "B:" + DoubleToString(BaseLot, 2) +
               " D:" + DoubleToString(GetDynamicLot(BaseLot), 2),
               29,
               clrWhite,
               clrYellow
              );

   DrawDashRow("REC GAP",
               DoubleToString(RecoveryGapPrice, 0),
               30,
               clrWhite,
               clrYellow
              );

   DrawDashRow("RISK",
               "Gate:" + OnOff(UseProfessionalRiskGate) +
               " CD:" + OnOff(UseSameBasketCooldown),
               31,
               clrWhite,
               UseProfessionalRiskGate ? clrLime : clrRed
              );

   DrawDashRow("T21 TP/SL",
               "$" + DoubleToString(DayBasketTPUSD, 2) +
               " / $" + DoubleToString(DayBasketSLUSD, 2),
               33,
               clrWhite,
               clrYellow
              );

   DrawDashRow("TYPE52",
               "Max:" + IntegerToString(MaxType52OrdersPerSide) +
               " Lot:" + DoubleToString(Type52Lot, 2),
               34,
               clrWhite,
               clrYellow
              );

   DrawDashRow("T52 GAP",
               DoubleToString(Type52OrderGapPrice, 0),
               35,
               clrWhite,
               clrYellow
              );

   DrawLabel("DASH_STATUS", "RUNNING - LIVE + SETTINGS", 300, 520, clrLime, 8);
  }
//+------------------------------------------------------------------+
//| Count all EA orders                                              |
//+------------------------------------------------------------------+
int CountEAOrders()
  {
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
        {
         total++;
        }
     }

   return total;
  }

//+------------------------------------------------------------------+
//| Get total EA floating profit                                     |
//+------------------------------------------------------------------+
double GetAllEAProfit()
  {
   double totalProfit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
        {
         totalProfit +=
            OrderProfit() +
            OrderSwap() +
            OrderCommission();
        }
     }

   return totalProfit;
  }
//+------------------------------------------------------------------+
void DrawDashboard111()
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
   DrawDashRow("Multiplier", DoubleToString(GetBalanceMultiplier(), 2) + "x", 40, clrWhite, clrYellow);
   DrawDashRow("Dyn Lot", DoubleToString(GetDynamicLot(BaseLot), 2), 41, clrWhite, clrYellow);
   DrawDashRow("Dyn GTP/SL", "$" + DoubleToString(GetDynamicTP(GlobalBasketTPUSD), 2) + " / $" + DoubleToString(GetDynamicSL(GlobalBasketSLUSD), 2), 42, clrWhite, clrYellow);
   DrawDashRow("T21 Day P/L", "$" + DoubleToString(GetType21TodayTotalProfit(), 2), 43, clrWhite, GetType21TodayTotalProfit() >= 0 ? clrLime : clrRed);
   DrawDashRow("T21 Target", "$" + DoubleToString(GetDynamicTP(DayDailyProfitTargetUSD), 2), 44, clrWhite, clrLime);
   DrawDashRow("T21 Lock", IsType21DailyTargetLocked() ? "LOCKED" : "OPEN", 45, clrWhite, IsType21DailyTargetLocked() ? clrRed : clrLime);

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



//+------------------------------------------------------------------+
