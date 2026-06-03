//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA.mq4                  |
//|  First SAR signal -> continuous orders -> $1 basket profit        |
//|  SAR flip closes opposite orders. Early reverse trend pauses SAR  |
//|  cycle, draws arrows, closes opposite orders, resumes when aligned |
//+------------------------------------------------------------------+
#property strict
#property version   "1.06"

//======================== INPUTS ====================================
string InpEAName                  = "DXB SAR Early Trend Cycle EA";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 1;     // display only; hard max is 2
double InpBasketProfitUSD         = 1.00;
int    InpStopLossPoints          = 0;       // 0 = no hard SL
int    InpSlippage                = 30;
int    InpMaxSpreadPoints         = 3000;

// Daily equity protection / profit lock
// Example: Balance=$100 -> Protected=$50, TradingCapital=$50, ProfitTarget=$25.
// When target is reached, EA closes its orders and pauses until next day.
// MT4 cannot literally move profit aside; this EA protects it by stopping new trades.
bool   InpUseEquityProtection       = true;
bool   InpAutoUseCurrentBalanceBase = true;   // true = take current account balance on EA load/new day
double InpManualBaseCapitalUSD      = 20.0;   // used only when Auto=false

double InpProfitTargetPercent      = 50.0;   // stop trading when equity reaches Base + 50%
double InpLossStopPercent          = 50.0;   // stop trading when equity reaches Base - 50%
double InpProtectionBufferUSD      = 0.00;   // optional buffer below loss-stop level
bool   InpCloseOrdersOnEquityHit    = true;

bool   InpUseDailyProfitLock        = true;
bool   InpCloseOrdersOnProfitLock   = true;
bool   InpPauseAfterProfitTarget    = true;

// Equity statistics reset cycle
bool   InpResetEquityStatsEvery6Hours = true;
int    InpEquityResetHours            = 6;      // fallback rolling reset if fixed hours are disabled
bool   InpUseFixedEquityResetHours    = true;   // true = reset only at configured server hours
string InpEquityResetHourList         = "1,7,13,19"; // server-time hours to reset equity base
bool   InpResetTradingCycleWithEquity = true;   // reset SAR/early/flat cycle when equity stats reset

#define DXB_HARD_MAX_OPEN_ORDERS 1   // absolute safety limit before every OrderSend

// Continuous order controls
bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;       // 0 = disabled
double InpMinPriceGap             = 0.00;    // raw price gap, 0 = disabled

// SAR settings
double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;

// Early trend settings
bool   InpUseEarlyTrend           = true;
int    InpFastEMA                 = 9;
int    InpSlowEMA                 = 21;
int    InpEarlyLookbackCandles    = 2;
double InpMinEarlyBodyMove        = 0.00;    // raw price diff, 0 = disabled
bool   InpCloseOnEarlyReverse     = true;
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
int    InpSAREveryBarLookback     = 300;    // historical SAR direction arrows to draw
color  InpBuyColor                = clrLime;
color  InpSellColor               = clrRed;
color  InpEarlyBuyColor           = clrAqua;
color  InpEarlySellColor          = clrOrangeRed;

// SAR dot visuals
bool   InpDrawSARDots            = true;
int    InpSARDotLookback         = 200;      // historical SAR dots to draw
color  InpSARDotBuyColor         = clrLime;
color  InpSARDotSellColor        = clrOrangeRed;

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

//+------------------------------------------------------------------+
int OnInit()
{
   InitializeEquityDay();
   DeleteNonEarlySignalArrows();

   InpMagicNumber=AccountNumber()+202; // override magic number with account number to prevent interference between charts/accounts. Orders are still filtered by symbol and magic in this EA.

   Print(InpEAName, " initialized. Magic=", InpMagicNumber,
         " | BaseBalance=$", DoubleToString(g_baseBalance,2),
         " | LossStopEquity=$", DoubleToString(g_lossStopEquityLevel,2),
         " | ProfitTargetEquity=$", DoubleToString(g_profitTargetEquity,2),
         " | TargetProfit=$", DoubleToString(g_dailyProfitTarget,2));

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
      if(h < 0)  h = 0;
      if(h > 23) h = 23;

      if(h == hourValue)
         return(true);
   }

   return(false);
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
double GetTodayProfitFromBase()
{
   return(AccountEquity() - g_baseBalance);
}
//+------------------------------------------------------------------+
bool CheckEquityConditions()
{
   ResetEquityDayIfNewDay();

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
void OnTick()
{
   RefreshRates();

   if(CheckEquityConditions())
   {
      if(g_dailyProfitLock)
         DrawDashboard("DAILY PROFIT LOCK - PAUSED");
      else
         DrawDashboard("EQUITY PROTECTION - PAUSED");
      return;
   }

   if(!IsTradeAllowed())
   {
      DrawDashboard("Trading not allowed");
      return;
   }

   if(MarketInfo(Symbol(), MODE_SPREAD) > InpMaxSpreadPoints)
   {
      DrawDashboard("Spread blocked");
      return;
   }

   // Draw/update SAR dots and SAR direction arrows on every tick so they do not disappear when chart moves.
   DrawSARDots();
   // SAR bar arrows disabled: only early trend arrows are displayed

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
      g_lastBarTime = Time[0];

   // 1) Lock first SAR direction from current SAR dot side.
   int sarDotDirection = GetSARDotDirection(1);

   // Draw SAR signal arrow for every closed bar.
   // This is separate from SAR flip arrows; it shows the current SAR direction on each M1/current TF bar.
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
      Print("FIRST SAR LOCKED | Direction=", DirectionText(g_activeSARDirection));
   }

   // 2) Detect real SAR flip. Close opposite orders and reset cycle.
   int sarFlip = GetSARFlipSignal();
   if(sarFlip != 0 && sarFlip != g_activeSARDirection)
   {
      g_activeSARDirection = sarFlip;
      g_lastSARDotDirection = sarFlip;
      g_sarPausedByEarly = false;
      g_earlyDirection = 0;

      Print("SAR CHANGED | New SAR=", DirectionText(sarFlip), " -> closing opposite orders");
      CloseOppositeOrders(sarFlip, "SAR changed");

   }

   if(g_activeSARDirection == 0)
   {
      DrawDashboard("Waiting for first SAR");
      return;
   }

   // 3) Basket profit booking. After close, same SAR cycle continues/resumes.
   double activeProfit = GetBasketProfit(g_activeSARDirection);
   if(activeProfit >= InpBasketProfitUSD)
   {
      CloseOrdersByDirection(g_activeSARDirection, "Basket profit $" + DoubleToString(activeProfit, 2));
      Print("Profit booked. Resume same SAR direction=", DirectionText(g_activeSARDirection));
      DrawDashboard("Profit booked - resume same SAR");
      return;
   }

   // 4) Flat mode detection BEFORE early trend detection.
   // Flat mode means EMA compression + small/mixed candles.
   // During flat mode we draw circle dots and pause fresh entries until breakout/early trend appears.
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

         // Do not open fresh orders inside compression. Existing orders are still managed above by basket TP/SAR flip.
         DrawDashboard("FLAT MODE - WAIT BREAKOUT");
         return;
      }
   }
   else
   {
      g_flatMode = false;
   }

   // 5) Early trend detection cycle.
   if(InpUseEarlyTrend)
   {
      int early = DetectEarlyTrend();
      if(early != 0)
      {
         if(early != g_earlyDirection)
         {
            g_earlyDirection = early;
            if(InpDrawEarlyArrows && Time[1] != g_lastEarlyArrowTime)
            {
               DrawSignalArrow("EARLY", early, Time[1], early == 1 ? Low[1] : High[1], true);
               g_lastEarlyArrowTime = Time[1];
            }
         }

         // Early trend opposite to SAR: close SAR-side orders and pause SAR order creation.
         if(early != g_activeSARDirection)
         {
            if(!g_sarPausedByEarly)
               Print("EARLY REVERSE DETECTED | Early=", DirectionText(early), " SAR=", DirectionText(g_activeSARDirection), " -> pause SAR orders");

            g_sarPausedByEarly = true;

            if(InpCloseOnEarlyReverse)
               CloseOppositeOrders(early, "Early reverse detected");

            DrawDashboard("Paused by early reverse " + DirectionText(early));
            return;
         }

         // Early trend changed back to same SAR direction: resume SAR order creation.
         if(early == g_activeSARDirection && g_sarPausedByEarly)
         {
            g_sarPausedByEarly = false;
            Print("EARLY TREND BACK TO SAR | Resume SAR orders. Direction=", DirectionText(g_activeSARDirection));
         }
      }
   }

   if(g_sarPausedByEarly)
   {
      DrawDashboard("Paused by early reverse");
      return;
   }

   // 5) Continuous order creation in active SAR direction.
   // Hard block: never open more than 2 symbol orders.
   if(CountAllSymbolMarketOrders() >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      DrawDashboard("MAX 2 ORDERS ACTIVE - WAIT CLOSE");
      return;
   }

   if(InpOneOrderPerBar && !isNewBar)
   {
      DrawDashboard("Waiting new bar");
      return;
   }

   if(!CanOpenNewOrder(g_activeSARDirection))
   {
      DrawDashboard("Order gate blocked");
      return;
   }

   OpenMarketOrder(g_activeSARDirection, "SAR continuous cycle");
   DrawDashboard("Active " + DirectionText(g_activeSARDirection));
}
//+------------------------------------------------------------------+
int GetSARFlipSignal()
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2]) return 1;
   if(sar1 > Close[1] && sar2 <= Close[2]) return -1;
   return 0;
}
//+------------------------------------------------------------------+
int GetSARDotDirection(int shift)
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar     = iSAR(Symbol(), Period(), step, maxstep, shift);

   if(sar < Close[shift]) return 1;
   if(sar > Close[shift]) return -1;
   return 0;
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

      if(Close[i] > Open[i]) green++;
      if(Close[i] < Open[i]) red++;

      if(High[i] > rangeHigh) rangeHigh = High[i];
      if(Low[i]  < rangeLow)  rangeLow  = Low[i];
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
      if(Close[i] > Open[i]) green++;
      if(Close[i] < Open[i]) red++;
   }

   bool bodyOK = (InpMinEarlyBodyMove <= 0.0 || totalBody >= InpMinEarlyBodyMove);

   if(bodyOK && emaBuy  && green >= MathMax(1, lookback - 1)) return 1;
   if(bodyOK && emaSell && red   >= MathMax(1, lookback - 1)) return -1;

   return 0;
}
//+------------------------------------------------------------------+
bool CanOpenNewOrder(int direction)
{
   if(direction == 0)
      return(false);

   // HARD GLOBAL SYMBOL LIMIT.
   // Counts ALL open BUY/SELL orders on this symbol, not only this EA magic.
   // This prevents SAR continuous cycle / early trend cycle from opening order #3.
   int openOrders = CountAllSymbolMarketOrders();
   if(openOrders >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDER BLOCKED | Max open orders reached. Symbol=", Symbol(),
            " Open=", openOrders,
            " Max=", DXB_HARD_MAX_OPEN_ORDERS,
            " Direction=", DirectionText(direction));
      DrawDashboard("MAX 2 ORDERS ACTIVE - WAIT CLOSE");
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != type) continue;

      if(MathAbs(price - OrderOpenPrice()) < minGap)
         return false;
   }
   return true;
}
//+------------------------------------------------------------------+
bool OpenMarketOrder(int direction, string reason)
{
   RefreshRates();

   if(CheckEquityConditions())
   {
      Print("ORDERSEND BLOCKED | Equity/profit lock active. Reason=", reason);
      return(false);
   }

   // FINAL SAFETY CHECK DIRECTLY BEFORE OrderSend.
   // Even if any logic path bypasses CanOpenNewOrder(), no 3rd order can be sent.
   int openOrders = CountAllSymbolMarketOrders();
   if(openOrders >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDERSEND BLOCKED | Max open orders reached. Symbol=", Symbol(),
            " Open=", openOrders,
            " Max=", DXB_HARD_MAX_OPEN_ORDERS,
            " Reason=", reason);
      DrawDashboard("ORDERSEND BLOCKED - MAX 2 ORDERS");
      return(false);
   }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;
   double sl = 0;

   if(InpStopLossPoints > 0)
   {
      if(direction == 1) sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else               sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
   }

   double lot = NormalizeLot(InpFixedLot);

   // Re-check immediately before OrderSend after lot/SL calculations.
   RefreshRates();
   if(CountAllSymbolMarketOrders() >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDERSEND CANCELLED LAST CHECK | Open=", CountAllSymbolMarketOrders(),
            " Max=", DXB_HARD_MAX_OPEN_ORDERS);
      return(false);
   }

   int ticket = OrderSend(Symbol(), type, lot, price, InpSlippage, sl, 0, reason, InpMagicNumber, 0, direction == 1 ? InpBuyColor : InpSellColor);

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend failed. Direction=", DirectionText(direction), " Error=", err);
      ResetLastError();
      return(false);
   }

   g_lastOrderTime = TimeCurrent();
   Print("Opened ", DirectionText(direction), " ticket=", ticket,
         " lot=", DoubleToString(lot, 2),
         " reason=", reason,
         " | TotalSymbolOrders=", CountAllSymbolMarketOrders(),
         "/", DXB_HARD_MAX_OPEN_ORDERS);
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != type) continue;

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
   if(ObjectFind(0, name) >= 0) return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, direction == 1 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, early ? (direction == 1 ? InpEarlyBuyColor : InpEarlySellColor) : (direction == 1 ? InpBuyColor : InpSellColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, early ? 2 : 3);
}
//+------------------------------------------------------------------+
string DirectionText(int direction)
{
   if(direction == 1)  return "BUY";
   if(direction == -1) return "SELL";
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

void DashRow(string title,string value,color clrText=clrWhite)
{
   DrawLabel(
      "DXB_ROW_"+IntegerToString(g_dashRow),
      title+" : "+value,
      200,
      30+(g_dashRow*18),
      clrText,
      9
   );

   g_dashRow++;
}

void DrawDashboard(string status)
{
   DrawPanel(
      "DXB_PANEL",
      220,
      20,
      340,
      450,
      clrBlack
   );

   g_dashRow=0;

   DashRow("DXB SAR EA",status,clrYellow);

   Print("DASHBOARD UPDATE | Status=", status,
         " | SAR=", DirectionText(g_activeSARDirection),
         " | Early=", DirectionText(g_earlyDirection),
         " | SAR Paused=", (g_sarPausedByEarly ? "YES" : "NO"),
         " | Flat Mode=", (g_flatMode ? "YES" : "NO"),
         " | EquityCycle=#", IntegerToString(g_equityCycleNumber),
         " | NextReset=", FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()));

   DashRow("--------------------------------","",clrGray);

   DashRow("SAR Direction",
           DirectionText(g_activeSARDirection),
           g_activeSARDirection==1 ? clrLime : clrRed);

   DashRow("Early Trend",
           DirectionText(g_earlyDirection),
           clrAqua);

   DashRow("SAR Paused",
           g_sarPausedByEarly ? "YES":"NO",
           g_sarPausedByEarly ? clrOrangeRed : clrLime);

   DashRow("Flat Mode",
           g_flatMode ? "YES":"NO",
           g_flatMode ? clrOrange : clrLime);

   DashRow("--------------------------------","",clrGray);

   DashRow("BUY Orders",
           IntegerToString(CountOrdersByDirection(1)));

   DashRow("BUY Profit",
           "$"+DoubleToString(GetBasketProfit(1),2),
           GetBasketProfit(1)>=0 ? clrLime : clrRed);

   DashRow("SELL Orders",
           IntegerToString(CountOrdersByDirection(-1)));

   DashRow("SELL Profit",
           "$"+DoubleToString(GetBasketProfit(-1),2),
           GetBasketProfit(-1)>=0 ? clrLime : clrRed);

   DashRow("--------------------------------","",clrGray);

   DashRow("Balance",
           "$"+DoubleToString(AccountBalance(),2),
           clrWhite);

   DashRow("Equity",
           "$"+DoubleToString(AccountEquity(),2),
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

   DashRow("--------------------------------","",clrGray);

   DashRow("Daily Profit",
           "$"+DoubleToString(GetTodayProfitFromBase(),2),
           GetTodayProfitFromBase()>=0 ? clrLime : clrRed);

   DashRow("Profit Lock",
           g_dailyProfitLock ? "ON":"OFF",
           g_dailyProfitLock ? clrOrange : clrLime);

   DashRow("Symbol Orders",
           IntegerToString(CountAllSymbolMarketOrders())+
           "/"+
           IntegerToString(DXB_HARD_MAX_OPEN_ORDERS),
           clrWhite);

   DashRow("Equity Cycle",
           "#"+IntegerToString(g_equityCycleNumber),
           clrAqua);

   DashRow("Next Reset",
           FormatSecondsToHHMM(GetSecondsUntilNextEquityReset()),
           clrAqua);

   DashRow("Early Arrows",
           InpDrawEarlyArrows ? "ON" : "OFF",
           InpDrawEarlyArrows ? clrLime : clrRed);

   DashRow("Lot Size",
           DoubleToString(InpFixedLot,2),
           clrWhite);
}
//+------------------------------------------------------------------+
