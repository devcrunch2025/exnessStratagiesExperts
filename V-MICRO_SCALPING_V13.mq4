//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property strict

/*
   BTCUSD 8-TYPE MOMENTUM BASKET EA
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
//  RECOVERY
// ================================================================
extern bool   UseRecoveryOrders = true;
extern double RecoveryGapPrice = 500.0;
extern int    MaxRecoveryOrdersPerBasket = 2;
extern bool   RecoverySameDirection = true;

// ================================================================
//  SAFETY
// ================================================================
extern bool UseEquityProtection = false;
extern double MinEquityPercent = 60.0;

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
void OpenOrder(int type, double lot, string commentText)
  {
   RefreshRates();

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
void DrawDashboard()
  {
   DrawPanel("DASH_BG_PANEL", 310, 15, 310, 650, clrBlack);

   DrawLabel("DASH_TITLE", "BTC 8-TYPE MOMENTUM EA", 300, 20, clrYellow, 9);

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

   DrawLabel("DASH_STATUS", "RUNNING 24/7 - 8 BTC MOMENTUM TYPES", 300, 400, clrLime, 8);
  }
//+------------------------------------------------------------------+
