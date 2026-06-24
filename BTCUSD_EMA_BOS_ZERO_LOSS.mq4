//+------------------------------------------------------------------+
//| BTCUSD_EMA_BOS_ASSIGNED_DYNAMIC_TP_PULLBACK_EA.mq4              |
//| Closed-candle BOS + confirmed pullback + spike protection       |
//| Clean-profit BOS re-entry + recovery basket + adaptive TP       |
//+------------------------------------------------------------------+
#property strict

double InpLotSize                    = 0.01;
int    InpMagicNumber                = 44001;
int    InpSlippage                   = 30;

int    InpEMAPeriod                  = 50;
int    InpSwingLookback              = 20;
int    InpPullbackMaxBars            = 10;
double InpMinBOSRawGap               = 20.0;
double InpPullbackMinRaw             = 30.0;
double InpPullbackMaxRaw             = 120.0;

// A pullback-zone touch is remembered during the candle. When
// InpOnlyNewCandleEntry=true, the entry is made on the next candle even
// if price has already moved out of the pullback zone.

// BOS confirmation and false-breakout protection.
// BOS is accepted only after candle 1 closes outside the structure.
// Oversized spike candles and weak-bodied/wick breakouts are rejected.
double InpMaxBOSCandleRangeRaw       = 250.0;
double InpMinBOSCandleBodyPercent    = 55.0;
double InpBOSCandleCloseEdgePercent  = 25.0;

// Require more than one closed candle on the correct side of EMA.
// This prevents one vertical spike from immediately flipping the trend.
int    InpEMAConfirmBars             = 2;

// The broken structure must remain held at entry.
double InpStructureHoldBufferRaw     = 5.0;
double InpBOSFailureBufferRaw        = 5.0;

// Pullback entry requires a confirmation candle in the BOS direction.
// If the retracement exceeds the configured maximum, the BOS is cancelled.
bool   InpRequirePullbackConfirmCandle = true;
bool   InpCancelBOSOnDeepPullback      = true;

// Block all entries for several bars after an oversized candle.
bool   InpUseSpikeEntryBlock         = true;
double InpSpikeRangeRaw              = 300.0;
int    InpSpikeBlockBars             = 3;

// Momentum continuation is disabled by default because it can chase a
// vertical breakout candle. It can be enabled only after testing.
bool   InpUseMomentumContinuation    = false;
double InpMomentumContinuationRaw    = 100.0;
int    InpMomentumMinBarsAfterBOS    = 2;

// InpTakeProfitUSD is the LIVE moving profit-lock step.
// The original input value is saved when the EA starts.
// Touch -$1 => Original TP / 2
// Touch -$2 => Original TP / 3
// Touch -$3 => Original TP / 4
// Touch -$4 => Original TP / 5
// Touch -$5 => break-even/cost-to-cost target.
double InpTakeProfitUSD              = 0.50;
bool   InpUseAdaptiveLossTarget      = true;
double InpAdaptiveLossLevelUSD       = 1.00;
double InpBreakEvenAfterLossUSD      = 5.00;
double InpBreakEvenCloseProfitUSD    = 0.00;

int    InpMaxOpenOrders              = 1;
bool   InpOnlyNewCandleEntry         = true;
bool   InpShowVisuals                = true;
int    InpEMALineBars                = 80;

// Dubai daily account-profit protection.
// Example: day-start balance $40 and target 50% means close all EA orders
// when equity reaches $60 and pause until the next Dubai calendar date.
double InpProfitTargetPercent        = 50.0;

// Recovery order settings.
// Recovery opens in the SAME direction as a losing regular parent only
// when adverse distance is large enough and active BOS matches direction.
bool   InpUseRecoveryOrders             = true;
double InpRecoveryLotSize               = 0.01;
double InpRecoveryRawDifference         = 100.0;
int    InpMaxRecoveryOrdersPerDirection = 1;

// Close linked parent + recovery together at the assigned basket target.
bool   InpCloseRecoveryBasketAtTP        = true;

// Clean-profit BOS continuation re-entry.
// Any profitable REGULAR order that never recorded negative net P/L arms
// one same-direction re-entry. It then waits for an active matching BOS.
// The matching BOS does NOT need to exist at the exact closing tick.
bool   InpUseCleanProfitPullback          = true;
int    InpCleanProfitPullbackMaxBars      = 3;

// Emergency money stop. Keep it above the break-even trigger.
double InpFixedStopLossUSD                = 6.00;

//----------------------------- BOS state -----------------------------
int      g_bosDirection = 0;
bool     g_bosActive    = false;
double   g_bosPrice     = 0.0;
double   g_bosLevel     = 0.0;
datetime g_bosTime      = 0;

// Prevent the same unchanged structure level from being detected repeatedly.
double   g_lastBullishStructureLevel = 0.0;
double   g_lastBearishStructureLevel = 0.0;

// Remembered entry setup state for the active BOS.
bool     g_pullbackTouchLatched      = false;
datetime g_pullbackTouchBarTime      = 0;
double   g_pullbackTouchRaw          = 0.0;
double   g_pullbackTouchPrice        = 0.0;

bool     g_momentumTouchLatched      = false;
datetime g_momentumTouchBarTime      = 0;
double   g_momentumTouchRaw          = 0.0;
double   g_momentumTouchPrice        = 0.0;

datetime g_lastBarTime          = 0;
datetime g_lastBOSDetectionBar = 0;
string   g_lastStatus           = "Starting";
string   PFX                    = "EMABOSPB_";

//-------------------------- Daily target state -----------------------
int      g_dailyDubaiDateKey       = 0;
double   g_dailyStartBalance       = 0.0;
double   g_dailyTargetEquity       = 0.0;
bool     g_dailyProfitTargetHit    = false;

//----------------------- Clean pullback state ------------------------
bool     g_cleanPullbackPending       = false;
int      g_cleanPullbackDirection     = 0;
int      g_cleanPullbackSourceTicket  = -1;
datetime g_cleanPullbackCloseTime     = 0;
datetime g_cleanPullbackCloseBarTime  = 0;
double   g_cleanPullbackClosePrice    = 0.0;

//------------------------- Adaptive TP state -------------------------
double   g_originalTakeProfitUSD      = 0.0;
int      g_assignedLossTier           = 0;

//+------------------------------------------------------------------+
// Dubai blocked period: 4:00 PM inclusive to 8:00 PM exclusive.
// Therefore blocked hours are 16, 17, 18 and 19 Dubai time.
//+------------------------------------------------------------------+
bool IsDubaiBlockedTime()
{
   datetime dubaiTime = TimeGMT() + 4 * 3600;
   int hour = TimeHour(dubaiTime);

   return(hour >= 16 && hour < 20);
}

//+------------------------------------------------------------------+
datetime GetDubaiTime()
{
   return(TimeGMT() + 4 * 3600);
}

//+------------------------------------------------------------------+
int GetDubaiDateKey()
{
   datetime dubaiTime = GetDubaiTime();

   return(TimeYear(dubaiTime) * 10000 +
          TimeMonth(dubaiTime) * 100 +
          TimeDay(dubaiTime));
}

//+------------------------------------------------------------------+
string DailyProfitStateKey(string field)
{
   return("EBP_DAY_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" + field);
}

//+------------------------------------------------------------------+
void SaveDailyProfitState()
{
   GlobalVariableSet(DailyProfitStateKey("DATE"),
                     (double)g_dailyDubaiDateKey);
   GlobalVariableSet(DailyProfitStateKey("BASE"),
                     g_dailyStartBalance);
   GlobalVariableSet(DailyProfitStateKey("TARGET"),
                     g_dailyTargetEquity);
   GlobalVariableSet(DailyProfitStateKey("HIT"),
                     g_dailyProfitTargetHit ? 1.0 : 0.0);
}

//+------------------------------------------------------------------+
void ResetDailyProfitState(int currentDubaiDateKey)
{
   g_dailyDubaiDateKey    = currentDubaiDateKey;
   g_dailyStartBalance    = AccountBalance();
   g_dailyTargetEquity    = g_dailyStartBalance *
                            (1.0 + InpProfitTargetPercent / 100.0);
   g_dailyProfitTargetHit = false;

   SaveDailyProfitState();

   Print("New Dubai trading day | Start balance $",
         DoubleToString(g_dailyStartBalance, 2),
         " | Profit target ",
         DoubleToString(InpProfitTargetPercent, 2),
         "% | Target equity $",
         DoubleToString(g_dailyTargetEquity, 2));
}

//+------------------------------------------------------------------+
void UpdateDailyProfitTargetState()
{
   int currentDubaiDateKey = GetDubaiDateKey();

   string dateKey   = DailyProfitStateKey("DATE");
   string baseKey   = DailyProfitStateKey("BASE");
   string targetKey = DailyProfitStateKey("TARGET");
   string hitKey    = DailyProfitStateKey("HIT");

   int storedDateKey = 0;

   if(GlobalVariableCheck(dateKey))
      storedDateKey = (int)GlobalVariableGet(dateKey);

   if(storedDateKey != currentDubaiDateKey ||
      !GlobalVariableCheck(baseKey) ||
      GlobalVariableGet(baseKey) <= 0.0)
   {
      ResetDailyProfitState(currentDubaiDateKey);
   }
   else
   {
      g_dailyDubaiDateKey = currentDubaiDateKey;
      g_dailyStartBalance = GlobalVariableGet(baseKey);

      g_dailyTargetEquity = g_dailyStartBalance *
                            (1.0 + InpProfitTargetPercent / 100.0);

      g_dailyProfitTargetHit =
         (GlobalVariableCheck(hitKey) &&
          GlobalVariableGet(hitKey) >= 0.5);

      GlobalVariableSet(targetKey, g_dailyTargetEquity);
   }

   if(InpProfitTargetPercent <= 0.0)
      return;

   if(!g_dailyProfitTargetHit &&
      AccountEquity() + 0.0000001 >= g_dailyTargetEquity)
   {
      g_dailyProfitTargetHit = true;
      g_bosActive = false;
      SaveDailyProfitState();

      g_lastStatus = "DAILY TARGET REACHED | CLOSING ALL ORDERS";

      Print(g_lastStatus,
            " | Start $", DoubleToString(g_dailyStartBalance, 2),
            " | Target equity $", DoubleToString(g_dailyTargetEquity, 2),
            " | Current equity $", DoubleToString(AccountEquity(), 2));
   }
}

//+------------------------------------------------------------------+
bool IsDailyNewOrderPaused()
{
   if(InpProfitTargetPercent <= 0.0)
      return(false);

   return(g_dailyProfitTargetHit);
}

//+------------------------------------------------------------------+
bool CloseAllMyOrdersAtDailyTarget()
{
   int matchingOrders = 0;
   int closedOrders   = 0;
   int failedOrders   = 0;
   double detectedNetProfit = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      matchingOrders++;

      int ticket    = OrderTicket();
      int type      = OrderType();
      double lots   = OrderLots();
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      detectedNetProfit += profit;

      RefreshRates();

      double closePrice = (type == OP_BUY) ? Bid : Ask;
      color closeColor  = (type == OP_BUY) ? clrLime : clrRed;

      ResetLastError();

      bool closed = OrderClose(ticket,
                               lots,
                               closePrice,
                               InpSlippage,
                               closeColor);

      if(closed)
      {
         closedOrders++;
         DeleteProfitTrailState(ticket);

         string recoveryKey = RecoveryBOSKey(ticket);
         if(GlobalVariableCheck(recoveryKey))
            GlobalVariableDel(recoveryKey);

         Print("DAILY TARGET CLOSE | Ticket #", ticket,
               " | P/L $", DoubleToString(profit, 2));
      }
      else
      {
         failedOrders++;
         int err = GetLastError();

         Print("DAILY TARGET CLOSE FAILED | Ticket #", ticket,
               " | Error ", err,
               " | P/L $", DoubleToString(profit, 2));
      }
   }

   if(matchingOrders == 0)
   {
      g_lastStatus = "DAILY TARGET REACHED | ALL ORDERS CLOSED | PAUSED";
      return(true);
   }

   if(failedOrders == 0)
   {
      g_lastStatus = "DAILY TARGET | CLOSED " +
                     IntegerToString(closedOrders) +
                     " ORDER(S) | PAUSED";
      return(true);
   }

   g_lastStatus = "DAILY TARGET | CLOSED " +
                  IntegerToString(closedOrders) +
                  " | RETRY " +
                  IntegerToString(failedOrders);

   Print(g_lastStatus,
         " | Detected basket P/L $",
         DoubleToString(detectedNetProfit, 2));

   return(false);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(IsTesting())
      InpProfitTargetPercent = 5000.0;

   g_originalTakeProfitUSD = InpTakeProfitUSD;
   g_assignedLossTier      = 0;

   DeleteObjectsByPrefix(PFX);
   UpdateDailyProfitTargetState();

   Print("EMA BOS Closed-Candle Confirmed Pullback EA started");

   if(InpShowVisuals)
      DrawDashboard("Initialized");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(PFX);
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
      g_lastBarTime = Time[0];

   UpdateDailyProfitTargetState();

   if(IsDailyNewOrderPaused())
   {
      CloseAllMyOrdersAtDailyTarget();

      if(InpShowVisuals)
         UpdateVisuals(false, GetEMATrend());

      return;
   }

   // Record drawdown before any close logic.
   UpdateAllOrderDrawdownStates();

   // Close parent + recovery baskets before individual exits.
   CloseRecoveryBasketsAtTP();

   // BOS is confirmed only from the newly closed candle. Existing BOS
   // state is first invalidated when price closes back through structure.
   if(isNewBar)
   {
      ValidateActiveBOSOnNewBar();
      DetectBOS();
   }

   // Remember intrabar pullback/momentum events only after a confirmed BOS.
   UpdateBOSSetupMemory();

   // A clean profitable close is allowed to arm re-entry even when no BOS
   // is active at this exact tick. The pending setup waits for a future
   // same-direction BOS.
   CloseByProfitOrLoss();

   // A close may remove the order that created the assigned loss tier.
   AssignTakeProfitFromOpenOrderLosses();

   if(!IsDailyNewOrderPaused())
   {
      // Recovery receives first priority.
      if(TryOpenRecoveryOrder())
      {
         if(InpShowVisuals)
            UpdateVisuals(false, GetEMATrend());

         return;
      }

      // Clean-profit continuation receives second priority.
      if(TryOpenCleanProfitPullback(isNewBar))
      {
         if(InpShowVisuals)
            UpdateVisuals(false, GetEMATrend());

         return;
      }
   }

   int entrySetup = 0;
   bool setupReady = GetBOSSetupEntryReady(isNewBar, entrySetup);

   int emaTrend = GetEMATrend();
   bool emaAllowed = (emaTrend == g_bosDirection && emaTrend != 0);
   bool entryReady = (setupReady && emaAllowed);

   if(InpShowVisuals)
      UpdateVisuals(entryReady, emaTrend);

   if(InpOnlyNewCandleEntry && !isNewBar)
   {
      if(!setupReady)
         g_lastStatus = GetBOSWaitingStatus();

      return;
   }

   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus = "Blocked: max open orders";
      return;
   }

   if(IsDubaiBlockedTime())
   {
      g_lastStatus = "TRADING PAUSED | Dubai 4PM-8PM";
      return;
   }

   if(entryReady)
   {
      int orderType = (g_bosDirection == 1) ? OP_BUY : OP_SELL;
      string side   = (orderType == OP_BUY) ? "BUY" : "SELL";
      string setupText;
      string orderComment;

      if(entrySetup == 2)
      {
         setupText    = "MOMENTUM";
         orderComment = "EMA_BOS_MOMENTUM_" + side;
      }
      else
      {
         setupText    = "PULLBACK";
         orderComment = "EMA_BOS_PULLBACK_" + side;
      }

      if(OpenOrder(orderType, orderComment))
      {
         double entryPrice = (orderType == OP_BUY) ? Ask : Bid;

         if(entrySetup == 2)
            DrawMomentumArrow(g_bosDirection, entryPrice, TimeCurrent());
         else
            DrawEntryArrow(g_bosDirection, entryPrice, TimeCurrent());

         g_lastStatus = setupText + " " + side + " opened";
         ConsumeCurrentBOS(setupText + " entry opened");
      }
   }
   else if(setupReady && !emaAllowed)
   {
      g_lastStatus = "Blocked: EMA trend mismatch";
   }
   else
   {
      g_lastStatus = GetBOSWaitingStatus();
   }
}

//+------------------------------------------------------------------+
int GetEMATrend()
{
   int confirmBars = (int)MathMax(1, InpEMAConfirmBars);

   if(Bars < InpEMAPeriod + confirmBars + 10)
      return(0);

   double ema1 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 1);
   double ema5 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 5);

   bool buySide  = (ema1 > ema5);
   bool sellSide = (ema1 < ema5);

   for(int shift = 1; shift <= confirmBars; shift++)
   {
      double emaShift = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                            MODE_EMA, PRICE_CLOSE, shift);

      if(Close[shift] <= emaShift)
         buySide = false;

      if(Close[shift] >= emaShift)
         sellSide = false;
   }

   if(buySide)  return(1);
   if(sellSide) return(-1);

   return(0);
}

//+------------------------------------------------------------------+
void ResetBOSSetupMemory()
{
   g_pullbackTouchLatched = false;
   g_pullbackTouchBarTime = 0;
   g_pullbackTouchRaw     = 0.0;
   g_pullbackTouchPrice   = 0.0;

   g_momentumTouchLatched = false;
   g_momentumTouchBarTime = 0;
   g_momentumTouchRaw     = 0.0;
   g_momentumTouchPrice   = 0.0;
}

//+------------------------------------------------------------------+
void ActivateBOS(int direction,
                 double structureLevel,
                 double detectionPrice,
                 datetime detectionTime)
{
   g_bosDirection = direction;
   g_bosActive    = true;
   g_bosLevel     = structureLevel;
   g_bosPrice     = detectionPrice;
   g_bosTime      = detectionTime;

   ResetBOSSetupMemory();

   if(direction == 1)
      g_lastBullishStructureLevel = structureLevel;
   else if(direction == -1)
      g_lastBearishStructureLevel = structureLevel;

   g_lastStatus = (direction == 1) ?
                  "Bullish BOS detected" :
                  "Bearish BOS detected";

   DrawBOS(direction, structureLevel, detectionPrice, detectionTime);
}

//+------------------------------------------------------------------+
void ConsumeCurrentBOS(string reason)
{
   if(reason != "")
      Print("BOS consumed | ", reason);

   g_bosActive = false;
   ResetBOSSetupMemory();

   string zoneName = PFX + "PULLBACK_ZONE";
   string bosPrice = PFX + "BOS_PRICE";

   if(ObjectFind(0, zoneName) >= 0)
      ObjectDelete(0, zoneName);

   if(ObjectFind(0, bosPrice) >= 0)
      ObjectDelete(0, bosPrice);
}

//+------------------------------------------------------------------+
double GetCandleBodyPercent(int shift)
{
   double range = High[shift] - Low[shift];

   if(range <= 0.0)
      return(0.0);

   double body = MathAbs(Close[shift] - Open[shift]);
   return(body / range * 100.0);
}

//+------------------------------------------------------------------+
bool IsBOSCandleCloseNearEdge(int direction, int shift)
{
   double range = High[shift] - Low[shift];

   if(range <= 0.0)
      return(false);

   double allowedDistance =
      range * MathMax(0.0, InpBOSCandleCloseEdgePercent) / 100.0;

   if(direction == 1)
      return((High[shift] - Close[shift]) <= allowedDistance);

   return((Close[shift] - Low[shift]) <= allowedDistance);
}

//+------------------------------------------------------------------+
bool IsRecentSpikeBlocked()
{
   if(!InpUseSpikeEntryBlock)
      return(false);

   if(InpSpikeRangeRaw <= 0.0 || InpSpikeBlockBars <= 0)
      return(false);

   int barsToCheck = (int)MathMin(InpSpikeBlockBars, Bars - 2);

   for(int shift = 1; shift <= barsToCheck; shift++)
   {
      double rangeRaw = High[shift] - Low[shift];

      if(rangeRaw >= InpSpikeRangeRaw)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool IsBOSStructureHolding()
{
   if(!g_bosActive || g_bosDirection == 0 || g_bosLevel <= 0.0)
      return(false);

   double buffer = MathMax(0.0, InpStructureHoldBufferRaw);

   if(g_bosDirection == 1)
   {
      return(Close[1] > g_bosLevel + buffer &&
             Bid      > g_bosLevel + buffer);
   }

   return(Close[1] < g_bosLevel - buffer &&
          Ask      < g_bosLevel - buffer);
}

//+------------------------------------------------------------------+
bool IsDirectionConfirmationCandle(int direction)
{
   if(direction == 1)
      return(Close[1] > Open[1]);

   if(direction == -1)
      return(Close[1] < Open[1]);

   return(false);
}

//+------------------------------------------------------------------+
void ValidateActiveBOSOnNewBar()
{
   if(!g_bosActive || g_bosDirection == 0 || g_bosLevel <= 0.0)
      return;

   double failureBuffer = MathMax(0.0, InpBOSFailureBufferRaw);

   if(g_bosDirection == 1 &&
      Close[1] < g_bosLevel - failureBuffer)
   {
      g_lastStatus = "Bullish BOS failed: candle closed below structure";
      ConsumeCurrentBOS("bullish structure failed");
      return;
   }

   if(g_bosDirection == -1 &&
      Close[1] > g_bosLevel + failureBuffer)
   {
      g_lastStatus = "Bearish BOS failed: candle closed above structure";
      ConsumeCurrentBOS("bearish structure failed");
      return;
   }
}

//+------------------------------------------------------------------+
void DetectBOS()
{
   if(Bars < InpSwingLookback + 5)
      return;

   // Evaluate each newly closed candle only once.
   if(g_lastBOSDetectionBar == Time[1])
      return;

   g_lastBOSDetectionBar = Time[1];

   int highIndex = iHighest(Symbol(), Period(), MODE_HIGH,
                            InpSwingLookback, 2);
   int lowIndex  = iLowest(Symbol(), Period(), MODE_LOW,
                           InpSwingLookback, 2);

   if(highIndex < 0 || lowIndex < 0)
      return;

   double structureHigh = High[highIndex];
   double structureLow  = Low[lowIndex];

   DrawHLine(PFX + "STRUCT_HIGH", structureHigh,
             clrDodgerBlue, STYLE_DOT, "Structure High");
   DrawHLine(PFX + "STRUCT_LOW", structureLow,
             clrTomato, STYLE_DOT, "Structure Low");

   double candleRange = High[1] - Low[1];
   double bodyPercent = GetCandleBodyPercent(1);

   bool rangeAllowed =
      (InpMaxBOSCandleRangeRaw <= 0.0 ||
       candleRange <= InpMaxBOSCandleRangeRaw);

   bool bodyAllowed =
      (bodyPercent + 0.0000001 >=
       MathMax(0.0, InpMinBOSCandleBodyPercent));

   bool bullishCandle =
      (Close[1] > Open[1] &&
       IsBOSCandleCloseNearEdge(1, 1));

   bool bearishCandle =
      (Close[1] < Open[1] &&
       IsBOSCandleCloseNearEdge(-1, 1));

   bool bullishBreak =
      (Close[1] > structureHigh + InpMinBOSRawGap);

   bool bearishBreak =
      (Close[1] < structureLow - InpMinBOSRawGap);

   if(bullishBreak)
   {
      if(!rangeAllowed)
      {
         g_lastStatus = "BOS BUY rejected: oversized spike candle";
         Print(g_lastStatus,
               " | Range ", DoubleToString(candleRange, 1));
         return;
      }

      if(!bodyAllowed || !bullishCandle)
      {
         g_lastStatus = "BOS BUY rejected: weak body/wick breakout";
         return;
      }

      bool newDirection = (g_bosDirection != 1);
      bool newLevel =
         (g_lastBullishStructureLevel <= 0.0 ||
          structureHigh >
          g_lastBullishStructureLevel + Point * 0.5);

      bool canActivate = newDirection || !g_bosActive;

      if(canActivate && (newDirection || newLevel))
      {
         ActivateBOS(1,
                     structureHigh,
                     Close[1],
                     Time[1]);
      }

      return;
   }

   if(bearishBreak)
   {
      if(!rangeAllowed)
      {
         g_lastStatus = "BOS SELL rejected: oversized spike candle";
         Print(g_lastStatus,
               " | Range ", DoubleToString(candleRange, 1));
         return;
      }

      if(!bodyAllowed || !bearishCandle)
      {
         g_lastStatus = "BOS SELL rejected: weak body/wick breakout";
         return;
      }

      bool newDirection = (g_bosDirection != -1);
      bool newLevel =
         (g_lastBearishStructureLevel <= 0.0 ||
          structureLow <
          g_lastBearishStructureLevel - Point * 0.5);

      bool canActivate = newDirection || !g_bosActive;

      if(canActivate && (newDirection || newLevel))
      {
         ActivateBOS(-1,
                     structureLow,
                     Close[1],
                     Time[1]);
      }

      return;
   }
}

//+------------------------------------------------------------------+
int GetBarsFromTime(datetime sourceTime)
{
   if(sourceTime <= 0)
      return(999999);

   int shift = iBarShift(Symbol(), Period(), sourceTime, false);

   if(shift < 0)
      return(999999);

   return(shift);
}

//+------------------------------------------------------------------+
bool ExpireActiveBOSIfRequired()
{
   if(!g_bosActive)
      return(false);

   int barsFromBOS = GetBarsFromTime(g_bosTime);

   if(InpPullbackMaxBars > 0 &&
      barsFromBOS > InpPullbackMaxBars)
   {
      g_lastStatus = "BOS expired after " +
                     IntegerToString(barsFromBOS) + " bars";

      ConsumeCurrentBOS("expired");
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
double GetCurrentPullbackRaw()
{
   if(!g_bosActive || g_bosDirection == 0)
      return(0.0);

   if(g_bosDirection == 1)
      return(g_bosPrice - Bid);

   return(Ask - g_bosPrice);
}

//+------------------------------------------------------------------+
double GetCurrentContinuationRaw()
{
   if(!g_bosActive || g_bosDirection == 0)
      return(0.0);

   if(g_bosDirection == 1)
      return(Ask - g_bosPrice);

   return(g_bosPrice - Bid);
}

//+------------------------------------------------------------------+
void UpdateBOSSetupMemory()
{
   if(!g_bosActive)
      return;

   if(ExpireActiveBOSIfRequired())
      return;

   double pullbackRaw = GetCurrentPullbackRaw();

   if(InpCancelBOSOnDeepPullback &&
      pullbackRaw > InpPullbackMaxRaw)
   {
      g_lastStatus = "BOS cancelled: pullback exceeded maximum";
      ConsumeCurrentBOS("deep pullback");
      return;
   }

   bool insidePullbackZone =
      (pullbackRaw >= InpPullbackMinRaw &&
       pullbackRaw <= InpPullbackMaxRaw);

   if(insidePullbackZone && !g_pullbackTouchLatched)
   {
      g_pullbackTouchLatched = true;
      g_pullbackTouchBarTime = Time[0];
      g_pullbackTouchRaw     = pullbackRaw;
      g_pullbackTouchPrice   =
         (g_bosDirection == 1) ? Bid : Ask;

      g_lastStatus = "Pullback touched and remembered";

      Print(g_lastStatus,
            " | Direction ",
            (g_bosDirection == 1 ? "BUY" : "SELL"),
            " | Raw ", DoubleToString(pullbackRaw, 1));
   }

   int barsFromBOS = GetBarsFromTime(g_bosTime);

   if(InpUseMomentumContinuation &&
      InpMomentumContinuationRaw > 0.0 &&
      barsFromBOS >= MathMax(1, InpMomentumMinBarsAfterBOS) &&
      !g_pullbackTouchLatched &&
      !g_momentumTouchLatched &&
      !IsRecentSpikeBlocked())
   {
      double continuationRaw = GetCurrentContinuationRaw();

      if(continuationRaw >= InpMomentumContinuationRaw)
      {
         g_momentumTouchLatched = true;
         g_momentumTouchBarTime = Time[0];
         g_momentumTouchRaw     = continuationRaw;
         g_momentumTouchPrice   =
            (g_bosDirection == 1) ? Ask : Bid;

         g_lastStatus = "Momentum continuation remembered";

         Print(g_lastStatus,
               " | Direction ",
               (g_bosDirection == 1 ? "BUY" : "SELL"),
               " | Raw ", DoubleToString(continuationRaw, 1));
      }
   }
}

//+------------------------------------------------------------------+
// Returns:
// 0 = no setup
// 1 = pullback setup
// 2 = momentum continuation setup
//+------------------------------------------------------------------+
bool GetBOSSetupEntryReady(bool isNewBar, int &entrySetup)
{
   entrySetup = 0;

   if(!g_bosActive || g_bosDirection == 0)
      return(false);

   if(ExpireActiveBOSIfRequired())
      return(false);

   if(IsRecentSpikeBlocked())
   {
      g_lastStatus = "Entry blocked: recent oversized candle";
      return(false);
   }

   if(!IsBOSStructureHolding())
   {
      g_lastStatus = "Entry waiting: broken structure not holding";
      return(false);
   }

   if(GetEMATrend() != g_bosDirection)
   {
      g_lastStatus = "Entry waiting: EMA confirmation";
      return(false);
   }

   bool directionCandleOK =
      (!InpRequirePullbackConfirmCandle ||
       IsDirectionConfirmationCandle(g_bosDirection));

   if(InpOnlyNewCandleEntry)
   {
      if(!isNewBar)
         return(false);

      if(g_pullbackTouchLatched &&
         g_pullbackTouchBarTime > 0 &&
         Time[0] != g_pullbackTouchBarTime &&
         directionCandleOK)
      {
         entrySetup = 1;
         return(true);
      }

      if(g_momentumTouchLatched &&
         g_momentumTouchBarTime > 0 &&
         Time[0] != g_momentumTouchBarTime &&
         directionCandleOK)
      {
         entrySetup = 2;
         return(true);
      }

      if(g_pullbackTouchLatched && !directionCandleOK)
         g_lastStatus = "Pullback remembered | waiting confirmation candle";

      return(false);
   }

   if(g_pullbackTouchLatched && directionCandleOK)
   {
      entrySetup = 1;
      return(true);
   }

   if(g_momentumTouchLatched && directionCandleOK)
   {
      entrySetup = 2;
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
string GetBOSWaitingStatus()
{
   if(!g_bosActive)
      return("Waiting BOS");

   if(g_pullbackTouchLatched)
   {
      if(InpOnlyNewCandleEntry &&
         Time[0] == g_pullbackTouchBarTime)
      {
         return("Pullback remembered | waiting next candle");
      }

      return("Pullback remembered");
   }

   if(g_momentumTouchLatched)
   {
      if(InpOnlyNewCandleEntry &&
         Time[0] == g_momentumTouchBarTime)
      {
         return("Momentum remembered | waiting next candle");
      }

      return("Momentum continuation remembered");
   }

   return("Waiting pullback or momentum continuation");
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, string orderComment)
{
   return(OpenOrderWithLots(type, InpLotSize, orderComment));
}

//+------------------------------------------------------------------+
bool OpenOrderWithLots(int type, double lots, string orderComment)
{
   RefreshRates();
   UpdateDailyProfitTargetState();

   if(IsDailyNewOrderPaused())
   {
      g_lastStatus = "DAILY TARGET REACHED | ALL ORDERS CLOSED | PAUSED";
      return(false);
   }

   double price = (type == OP_BUY) ? Ask : Bid;

   ResetLastError();

   int ticket = OrderSend(Symbol(),
                          type,
                          lots,
                          price,
                          InpSlippage,
                          0,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          clrNONE);

   if(ticket < 0)
   {
      int err = GetLastError();
      g_lastStatus = "OrderSend failed: " + IntegerToString(err);
      Print(g_lastStatus);
      return(false);
   }

   DeleteProfitTrailState(ticket);
   SetTrailValue(ticket, "NEG", 0.0);

   g_lastStatus = "Order opened #" + IntegerToString(ticket);
   return(true);
}

//+------------------------------------------------------------------+
bool IsRecoveryOrderComment(string orderComment)
{
   return(StringFind(orderComment, "BOS_RECOVERY_", 0) == 0);
}

//+------------------------------------------------------------------+
int CountRecoveryOrders(int orderType)
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
string RecoveryBOSKey(int parentTicket)
{
   return("EBP_REC_BOS_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          IntegerToString(parentTicket));
}

//+------------------------------------------------------------------+
bool RecoveryAlreadyUsedForCurrentBOS(int parentTicket)
{
   string key = RecoveryBOSKey(parentTicket);

   if(!GlobalVariableCheck(key))
      return(false);

   datetime usedBOSTime = (datetime)GlobalVariableGet(key);

   return(usedBOSTime == g_bosTime);
}

//+------------------------------------------------------------------+
void MarkRecoveryUsedForCurrentBOS(int parentTicket)
{
   GlobalVariableSet(RecoveryBOSKey(parentTicket),
                     (double)g_bosTime);
}

//+------------------------------------------------------------------+
int GetRecoveryParentTicket(string orderComment)
{
   if(!IsRecoveryOrderComment(orderComment))
      return(-1);

   int markerPos = StringFind(orderComment, "_P", 0);

   if(markerPos < 0)
      return(-1);

   string ticketText = StringSubstr(orderComment, markerPos + 2);
   int parentTicket = (int)StrToInteger(ticketText);

   return(parentTicket > 0 ? parentTicket : -1);
}

//+------------------------------------------------------------------+
bool IsMyOpenMarketOrder(int ticket)
{
   if(ticket <= 0) return(false);
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return(false);
   if(OrderCloseTime() != 0) return(false);
   if(OrderSymbol() != Symbol()) return(false);
   if(OrderMagicNumber() != InpMagicNumber) return(false);
   if(OrderType() != OP_BUY && OrderType() != OP_SELL) return(false);

   return(true);
}

//+------------------------------------------------------------------+
bool IsOrderInActiveRecoveryPair(int ticket)
{
   if(ticket <= 0)
      return(false);

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      int recoveryTicket = OrderTicket();
      int parentTicket   = GetRecoveryParentTicket(OrderComment());

      if(parentTicket <= 0) continue;
      if(ticket != recoveryTicket && ticket != parentTicket) continue;

      if(IsMyOpenMarketOrder(parentTicket) &&
         IsMyOpenMarketOrder(recoveryTicket))
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool CloseOrderByTicket(int ticket,
                        string reason,
                        double detectedProfit)
{
   if(!IsMyOpenMarketOrder(ticket))
      return(false);

   int type = OrderType();
   double lots = OrderLots();

   RefreshRates();

   double closePrice = (type == OP_BUY) ? Bid : Ask;
   color closeColor  = (type == OP_BUY) ? clrLime : clrRed;

   ResetLastError();

   bool closed = OrderClose(ticket,
                            lots,
                            closePrice,
                            InpSlippage,
                            closeColor);

   if(closed)
   {
      DeleteProfitTrailState(ticket);

      Print(reason,
            " | Ticket #", ticket,
            " | Detected P/L $", DoubleToString(detectedProfit, 2));

      return(true);
   }

   int err = GetLastError();

   Print("OrderClose failed #", ticket,
         " | Error ", err,
         " | ", reason);

   return(false);
}

//+------------------------------------------------------------------+
void CloseRecoveryBasketsAtTP()
{
   if(!InpCloseRecoveryBasketAtTP)
      return;

   if(g_originalTakeProfitUSD <= 0.0)
      return;

   int recoveryTickets[100];
   int recoveryCount = 0;

   for(int i = 0; i < OrdersTotal() && recoveryCount < 100; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      recoveryTickets[recoveryCount] = OrderTicket();
      recoveryCount++;
   }

   for(int r = 0; r < recoveryCount; r++)
   {
      int recoveryTicket = recoveryTickets[r];

      if(!IsMyOpenMarketOrder(recoveryTicket))
         continue;

      string recoveryComment = OrderComment();
      int recoveryType = OrderType();
      double recoveryProfit = OrderProfit() +
                              OrderSwap() +
                              OrderCommission();

      int parentTicket = GetRecoveryParentTicket(recoveryComment);

      if(parentTicket <= 0) continue;
      if(!IsMyOpenMarketOrder(parentTicket)) continue;
      if(OrderType() != recoveryType) continue;
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double parentProfit = OrderProfit() +
                            OrderSwap() +
                            OrderCommission();

      double basketProfit = parentProfit + recoveryProfit;
      double basketTarget = InpTakeProfitUSD;

      bool breakEvenMode =
         IsBreakEvenLossTier(g_assignedLossTier);

      if(basketProfit + 0.0000001 < basketTarget)
         continue;

      string side = (recoveryType == OP_BUY) ? "BUY" : "SELL";

      string targetMode =
         breakEvenMode ?
         "BREAK-EVEN" :
         "TP $" + DoubleToString(basketTarget, 2);

      string reason =
         "Recovery basket " + side +
         " " + targetMode +
         " | Assigned tier " +
         IntegerToString(g_assignedLossTier) +
         " | Basket $" +
         DoubleToString(basketProfit, 2);

      bool parentClosed =
         CloseOrderByTicket(parentTicket,
                            reason + " | ORIGINAL",
                            parentProfit);

      bool recoveryClosed =
         CloseOrderByTicket(recoveryTicket,
                            reason + " | RECOVERY",
                            recoveryProfit);

      if(parentClosed && recoveryClosed)
      {
         string recoveryKey = RecoveryBOSKey(parentTicket);

         if(GlobalVariableCheck(recoveryKey))
            GlobalVariableDel(recoveryKey);

         g_lastStatus = reason + " | Both closed";
      }
      else if(parentClosed || recoveryClosed)
      {
         g_lastStatus = reason +
                        " | Partial close; retrying remaining order";
      }
      else
      {
         g_lastStatus = reason + " | Close failed";
      }
   }
}

//+------------------------------------------------------------------+
bool GetRecoveryBasketInfo(double &basketProfit,
                           int &parentTicket,
                           int &recoveryTicket)
{
   basketProfit   = 0.0;
   parentTicket   = -1;
   recoveryTicket = -1;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      int selectedRecoveryTicket = OrderTicket();
      int selectedRecoveryType   = OrderType();

      double recoveryProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      int selectedParentTicket =
         GetRecoveryParentTicket(OrderComment());

      if(!IsMyOpenMarketOrder(selectedParentTicket)) continue;
      if(OrderType() != selectedRecoveryType) continue;
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double parentProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      basketProfit   = parentProfit + recoveryProfit;
      parentTicket   = selectedParentTicket;
      recoveryTicket = selectedRecoveryTicket;

      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool FindRecoveryParent(int requiredType,
                        int &parentTicket,
                        double &parentProfit,
                        double &rawDifference)
{
   parentTicket  = -1;
   parentProfit  = 0.0;
   rawDifference = 0.0;

   double largestRawDifference = -1.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != requiredType) continue;

      // Recovery orders cannot become parents.
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double profit =
         OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= 0.0)
         continue;

      double adverseRaw = 0.0;

      if(requiredType == OP_BUY)
         adverseRaw = OrderOpenPrice() - Bid;
      else
         adverseRaw = Ask - OrderOpenPrice();

      if(adverseRaw < InpRecoveryRawDifference) continue;
      if(RecoveryAlreadyUsedForCurrentBOS(OrderTicket())) continue;

      if(adverseRaw > largestRawDifference)
      {
         largestRawDifference = adverseRaw;
         parentTicket         = OrderTicket();
         parentProfit         = profit;
         rawDifference        = adverseRaw;
      }
   }

   return(parentTicket > 0);
}

//+------------------------------------------------------------------+
bool TryOpenRecoveryOrder()
{
   UpdateDailyProfitTargetState();

   if(IsDailyNewOrderPaused()) return(false);
   if(!InpUseRecoveryOrders) return(false);
   if(!g_bosActive || g_bosDirection == 0) return(false);
   if(InpRecoveryRawDifference <= 0.0) return(false);
   if(InpRecoveryLotSize <= 0.0) return(false);
   if(InpMaxRecoveryOrdersPerDirection <= 0) return(false);
   if(IsDubaiBlockedTime()) return(false);
   if(IsRecentSpikeBlocked()) return(false);
   if(!IsBOSStructureHolding()) return(false);
   if(GetEMATrend() != g_bosDirection) return(false);

   int requiredType =
      (g_bosDirection == 1) ? OP_BUY : OP_SELL;

   if(CountRecoveryOrders(requiredType) >=
      InpMaxRecoveryOrdersPerDirection)
   {
      return(false);
   }

   int parentTicket = -1;
   double parentProfit = 0.0;
   double rawDifference = 0.0;

   if(!FindRecoveryParent(requiredType,
                          parentTicket,
                          parentProfit,
                          rawDifference))
   {
      return(false);
   }

   string side =
      (requiredType == OP_BUY) ? "BUY" : "SELL";

   string orderComment =
      "BOS_RECOVERY_" + side +
      "_P" + IntegerToString(parentTicket);

   if(!OpenOrderWithLots(requiredType,
                         InpRecoveryLotSize,
                         orderComment))
   {
      return(false);
   }

   MarkRecoveryUsedForCurrentBOS(parentTicket);

   double entryPrice =
      (requiredType == OP_BUY) ? Ask : Bid;

   DrawRecoveryArrow(g_bosDirection,
                     entryPrice,
                     TimeCurrent(),
                     parentTicket);

   g_lastStatus =
      "Recovery " + side +
      " opened | Parent #" +
      IntegerToString(parentTicket) +
      " | Parent P/L $" +
      DoubleToString(parentProfit, 2) +
      " | Raw " +
      DoubleToString(rawDifference, 1);

   Print(g_lastStatus);
   return(true);
}

//+------------------------------------------------------------------+
void ClearCleanProfitPullback(string reason)
{
   if(g_cleanPullbackPending && reason != "")
      Print("Clean pullback cleared | ", reason);

   g_cleanPullbackPending      = false;
   g_cleanPullbackDirection    = 0;
   g_cleanPullbackSourceTicket = -1;
   g_cleanPullbackCloseTime    = 0;
   g_cleanPullbackCloseBarTime = 0;
   g_cleanPullbackClosePrice   = 0.0;
}

//+------------------------------------------------------------------+
void ArmCleanProfitPullback(int sourceTicket,
                            int direction,
                            datetime closeTime,
                            double closePrice,
                            double closeProfit)
{
   if(!InpUseCleanProfitPullback) return;
   if(direction != 1 && direction != -1) return;
   if(closeProfit <= 0.0) return;

   g_cleanPullbackPending      = true;
   g_cleanPullbackDirection    = direction;
   g_cleanPullbackSourceTicket = sourceTicket;
   g_cleanPullbackCloseTime    = closeTime;
   g_cleanPullbackCloseBarTime = Time[0];
   g_cleanPullbackClosePrice   = closePrice;

   string side = (direction == 1) ? "BUY" : "SELL";

   g_lastStatus =
      "Clean profit closed | " + side +
      " BOS continuation armed";

   Print(g_lastStatus,
         " | Source #", sourceTicket,
         " | Close P/L $", DoubleToString(closeProfit, 2),
         " | Close price ", DoubleToString(closePrice, Digits));
}

//+------------------------------------------------------------------+
bool TryOpenCleanProfitPullback(bool isNewBar)
{
   if(!InpUseCleanProfitPullback) return(false);
   if(!g_cleanPullbackPending) return(false);
   if(IsDailyNewOrderPaused()) return(false);

   if(g_cleanPullbackDirection != 1 &&
      g_cleanPullbackDirection != -1)
   {
      ClearCleanProfitPullback("invalid direction");
      return(false);
   }

   int barsFromClose =
      GetBarsFromTime(g_cleanPullbackCloseTime);

   if(InpCleanProfitPullbackMaxBars > 0 &&
      barsFromClose > InpCleanProfitPullbackMaxBars)
   {
      ClearCleanProfitPullback(
         "matching BOS did not arrive before expiry");

      g_lastStatus = "Clean pullback expired";
      return(false);
   }

   // Active opposite BOS invalidates the clean continuation.
   if(g_bosActive &&
      g_bosDirection != 0 &&
      g_bosDirection != g_cleanPullbackDirection)
   {
      ClearCleanProfitPullback("opposite BOS active");
      g_lastStatus = "Clean pullback cancelled: opposite BOS";
      return(false);
   }

   // Wait for a future/current active matching BOS.
   if(!g_bosActive ||
      g_bosDirection != g_cleanPullbackDirection)
   {
      g_lastStatus =
         "Clean pullback waiting same-direction BOS";

      return(false);
   }

   if(IsRecentSpikeBlocked())
   {
      g_lastStatus = "Clean pullback blocked: recent spike";
      return(false);
   }

   if(!IsBOSStructureHolding())
   {
      g_lastStatus = "Clean pullback waiting structure hold";
      return(false);
   }

   if(GetEMATrend() != g_cleanPullbackDirection)
   {
      g_lastStatus = "Clean pullback waiting EMA confirmation";
      return(false);
   }

   if(InpRequirePullbackConfirmCandle &&
      !IsDirectionConfirmationCandle(g_cleanPullbackDirection))
   {
      g_lastStatus = "Clean pullback waiting confirmation candle";
      return(false);
   }

   // Never reopen on the same candle as the clean close.
   if(Time[0] == g_cleanPullbackCloseBarTime)
   {
      g_lastStatus = "Clean pullback waiting next candle";
      return(false);
   }

   if(InpOnlyNewCandleEntry && !isNewBar)
   {
      g_lastStatus = "Clean pullback waiting new candle";
      return(false);
   }

   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus =
         "Clean pullback blocked: max open orders";

      return(false);
   }

   if(IsDubaiBlockedTime())
   {
      g_lastStatus =
         "Clean pullback paused: Dubai 4PM-8PM";

      return(false);
   }

   int type =
      (g_cleanPullbackDirection == 1) ?
      OP_BUY : OP_SELL;

   string side =
      (type == OP_BUY) ? "BUY" : "SELL";

   string orderComment =
      "BOS_CLEAN_PULLBACK_" + side +
      "_P" +
      IntegerToString(g_cleanPullbackSourceTicket);

   int sourceTicket = g_cleanPullbackSourceTicket;
   int direction    = g_cleanPullbackDirection;

   if(!OpenOrderWithLots(type,
                         InpLotSize,
                         orderComment))
   {
      return(false);
   }

   double entryPrice =
      (type == OP_BUY) ? Ask : Bid;

   DrawCleanPullbackArrow(direction,
                          entryPrice,
                          TimeCurrent(),
                          sourceTicket);

   ClearCleanProfitPullback("");
   ConsumeCurrentBOS("clean-profit continuation opened");

   g_lastStatus =
      "Clean BOS continuation " + side + " opened";

   Print(g_lastStatus, " | Source #", sourceTicket);
   return(true);
}

//+------------------------------------------------------------------+
int GetBreakEvenLossTier()
{
   if(!InpUseAdaptiveLossTarget) return(0);
   if(InpAdaptiveLossLevelUSD <= 0.0) return(0);
   if(InpBreakEvenAfterLossUSD <= 0.0) return(0);

   return((int)MathCeil(InpBreakEvenAfterLossUSD /
                        InpAdaptiveLossLevelUSD));
}

//+------------------------------------------------------------------+
bool IsBreakEvenLossTier(int lossTier)
{
   int breakEvenTier = GetBreakEvenLossTier();

   return(breakEvenTier > 0 &&
          lossTier >= breakEvenTier);
}

//+------------------------------------------------------------------+
int GetLossTierFromMinimumProfit(double minimumProfit)
{
   if(!InpUseAdaptiveLossTarget) return(0);
   if(InpAdaptiveLossLevelUSD <= 0.0) return(0);
   if(minimumProfit >= -0.0000001) return(0);

   double adverseLoss = -minimumProfit;

   int lossTier =
      (int)MathFloor((adverseLoss + 0.0000001) /
                     InpAdaptiveLossLevelUSD);

   int breakEvenTier = GetBreakEvenLossTier();

   if(breakEvenTier > 0 && lossTier > breakEvenTier)
      lossTier = breakEvenTier;

   return(lossTier < 0 ? 0 : lossTier);
}

//+------------------------------------------------------------------+
double GetAssignedTakeProfitForLossTier(int lossTier)
{
   if(g_originalTakeProfitUSD <= 0.0)
      return(0.0);

   if(!InpUseAdaptiveLossTarget || lossTier <= 0)
      return(g_originalTakeProfitUSD);

   if(IsBreakEvenLossTier(lossTier))
   {
      return(MathMax(0.0,
                     InpBreakEvenCloseProfitUSD));
   }

   return(NormalizeDouble(
             g_originalTakeProfitUSD /
             (lossTier + 1.0),
             4));
}

//+------------------------------------------------------------------+
void AssignTakeProfitFromOpenOrderLosses()
{
   if(g_originalTakeProfitUSD <= 0.0)
      g_originalTakeProfitUSD = InpTakeProfitUSD;

   int deepestTier = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int tier = GetStoredLossTier(OrderTicket());

      if(tier > deepestTier)
         deepestTier = tier;
   }

   double assignedTP =
      GetAssignedTakeProfitForLossTier(deepestTier);

   bool changed =
      (deepestTier != g_assignedLossTier ||
       MathAbs(InpTakeProfitUSD - assignedTP) >
       0.0000001);

   g_assignedLossTier = deepestTier;
   InpTakeProfitUSD   = assignedTP;

   if(changed)
   {
      string targetText =
         IsBreakEvenLossTier(deepestTier) ?
         "BREAK-EVEN $" +
         DoubleToString(InpTakeProfitUSD, 2) :
         "$" +
         DoubleToString(InpTakeProfitUSD, 4);

      g_lastStatus =
         "InpTakeProfitUSD assigned " +
         targetText +
         " | Loss tier " +
         IntegerToString(deepestTier);

      Print(g_lastStatus,
            " | Original TP $",
            DoubleToString(g_originalTakeProfitUSD, 4));
   }
}

//+------------------------------------------------------------------+
int GetStoredLossTier(int ticket)
{
   if(ticket <= 0)
      return(0);

   return((int)GetTrailValue(ticket,
                             "TIER",
                             0.0));
}

//+------------------------------------------------------------------+
double GetStoredMinimumProfit(int ticket,
                              double defaultValue)
{
   if(ticket <= 0)
      return(defaultValue);

   return(GetTrailValue(ticket,
                        "MINP",
                        defaultValue));
}

//+------------------------------------------------------------------+
void UpdateAllOrderDrawdownStates()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();

      double profit =
         OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < -0.0000001)
         SetTrailValue(ticket, "NEG", 1.0);

      double minimumProfit =
         GetTrailValue(ticket, "MINP", profit);

      if(profit < minimumProfit)
      {
         minimumProfit = profit;
         SetTrailValue(ticket,
                       "MINP",
                       minimumProfit);
      }

      int previousTier = GetStoredLossTier(ticket);
      int currentTier =
         GetLossTierFromMinimumProfit(minimumProfit);

      if(currentTier > previousTier)
      {
         SetTrailValue(ticket,
                       "TIER",
                       currentTier);

         g_lastStatus =
            "Loss tier " +
            IntegerToString(currentTier) +
            " touched | Reassigning TP";

         Print(g_lastStatus,
               " | Ticket #", ticket,
               " | Minimum P/L $",
               DoubleToString(minimumProfit, 2));
      }
   }

   AssignTakeProfitFromOpenOrderLosses();
}

//+------------------------------------------------------------------+
void CloseByProfitOrLoss()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();

      double profit =
         OrderProfit() + OrderSwap() + OrderCommission();

      bool activeRecoveryPair =
         IsOrderInActiveRecoveryPair(ticket);

      // Pair check changes the selected order.
      if(!OrderSelect(ticket,
                      SELECT_BY_TICKET,
                      MODE_TRADES))
      {
         continue;
      }

      if(OrderCloseTime() != 0)
         continue;

      double previousProfit =
         GetTrailValue(ticket, "PREV", profit);

      double peakProfit =
         GetTrailValue(ticket, "PEAK", profit);

      double lockedProfit =
         GetTrailValue(ticket, "LOCK", 0.0);

      double minimumProfit =
         GetStoredMinimumProfit(ticket, profit);

      int lossTier =
         GetStoredLossTier(ticket);

      double effectiveStep =
         InpTakeProfitUSD;

      bool breakEvenMode =
         IsBreakEvenLossTier(g_assignedLossTier);

      if(profit > peakProfit)
      {
         peakProfit = profit;

         SetTrailValue(ticket,
                       "PEAK",
                       peakProfit);
      }

      bool lockRaised = false;

      if(!activeRecoveryPair &&
         !breakEvenMode &&
         effectiveStep > 0.0 &&
         profit + 0.0000001 >= effectiveStep &&
         peakProfit >= effectiveStep)
      {
         double calculatedLock =
            MathFloor((peakProfit + 0.0000001) /
                      effectiveStep) *
            effectiveStep;

         calculatedLock =
            NormalizeDouble(calculatedLock, 2);

         if(calculatedLock >
            lockedProfit + 0.0000001)
         {
            lockedProfit = calculatedLock;

            SetTrailValue(ticket,
                          "LOCK",
                          lockedProfit);

            lockRaised = true;

            g_lastStatus =
               "Dynamic lock raised to $" +
               DoubleToString(lockedProfit, 2) +
               " | Assigned tier " +
               IntegerToString(g_assignedLossTier) +
               " | TP $" +
               DoubleToString(effectiveStep, 4);
         }
      }

      bool fixedStopHit =
         (InpFixedStopLossUSD > 0.0 &&
          profit <= -InpFixedStopLossUSD);

      bool breakEvenHit =
         (!activeRecoveryPair &&
          breakEvenMode &&
          profit + 0.0000001 >=
          MathMax(0.0,
                  InpBreakEvenCloseProfitUSD));

      bool profitFalling =
         (profit <
          previousProfit - 0.0000001);

      bool trailHit =
         (!activeRecoveryPair &&
          !breakEvenMode &&
          effectiveStep > 0.0 &&
          !lockRaised &&
          lockedProfit + 0.0000001 >= effectiveStep &&
          profitFalling &&
          profit <= lockedProfit);

      SetTrailValue(ticket,
                    "PREV",
                    profit);

      if(fixedStopHit)
      {
         CloseSelectedOrder(
            "Emergency SL -$" +
            DoubleToString(InpFixedStopLossUSD, 2),
            profit);
      }
      else if(breakEvenHit)
      {
         CloseSelectedOrder(
            "Recovered from $" +
            DoubleToString(minimumProfit, 2) +
            " | Cost-to-cost exit",
            profit);
      }
      else if(trailHit)
      {
         CloseSelectedOrder(
            "Dynamic trailing lock $" +
            DoubleToString(lockedProfit, 2) +
            " | Assigned TP $" +
            DoubleToString(InpTakeProfitUSD, 4) +
            " | Loss tier " +
            IntegerToString(lossTier),
            profit);
      }
   }
}

//+------------------------------------------------------------------+
bool CloseSelectedOrder(string reason,
                        double detectedProfit)
{
   int ticket = OrderTicket();
   int type   = OrderType();
   double lots = OrderLots();

   string orderComment = OrderComment();

   bool isRecoveryOrder =
      IsRecoveryOrderComment(orderComment);

   bool touchedNegative =
      (GetTrailValue(ticket,
                     "NEG",
                     0.0) >= 0.5);

   int orderDirection =
      (type == OP_BUY) ? 1 : -1;

   RefreshRates();

   double closePrice =
      (type == OP_BUY) ? Bid : Ask;

   color closeColor =
      (type == OP_BUY) ? clrLime : clrRed;

   ResetLastError();

   bool closed =
      OrderClose(ticket,
                 lots,
                 closePrice,
                 InpSlippage,
                 closeColor);

   if(closed)
   {
      // IMPORTANT CHANGE:
      // Arm after every clean profitable regular close. A matching BOS may
      // already exist or may arrive later during the allowed expiry period.
      if(!isRecoveryOrder &&
         detectedProfit > 0.0 &&
         !touchedNegative)
      {
         ArmCleanProfitPullback(ticket,
                                orderDirection,
                                TimeCurrent(),
                                closePrice,
                                detectedProfit);
      }

      DeleteProfitTrailState(ticket);

      g_lastStatus =
         reason +
         " | Closed P/L $" +
         DoubleToString(detectedProfit, 2) +
         " | Ever negative: " +
         (touchedNegative ? "YES" : "NO");

      Print(g_lastStatus,
            " | Ticket #", ticket);

      return(true);
   }

   int err = GetLastError();

   g_lastStatus =
      "OrderClose failed #" +
      IntegerToString(ticket) +
      " error " +
      IntegerToString(err);

   Print(g_lastStatus);
   return(false);
}

//+------------------------------------------------------------------+
string TrailKey(int ticket, string field)
{
   return("EBP_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          IntegerToString(ticket) + "_" +
          field);
}

//+------------------------------------------------------------------+
double GetTrailValue(int ticket,
                     string field,
                     double defaultValue)
{
   string key = TrailKey(ticket, field);

   if(!GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, defaultValue);
      return(defaultValue);
   }

   return(GlobalVariableGet(key));
}

//+------------------------------------------------------------------+
void SetTrailValue(int ticket,
                   string field,
                   double value)
{
   GlobalVariableSet(TrailKey(ticket, field),
                     value);
}

//+------------------------------------------------------------------+
void DeleteProfitTrailState(int ticket)
{
   string keyPrev = TrailKey(ticket, "PREV");
   string keyPeak = TrailKey(ticket, "PEAK");
   string keyLock = TrailKey(ticket, "LOCK");
   string keyNeg  = TrailKey(ticket, "NEG");
   string keyMinP = TrailKey(ticket, "MINP");
   string keyTier = TrailKey(ticket, "TIER");

   if(GlobalVariableCheck(keyPrev)) GlobalVariableDel(keyPrev);
   if(GlobalVariableCheck(keyPeak)) GlobalVariableDel(keyPeak);
   if(GlobalVariableCheck(keyLock)) GlobalVariableDel(keyLock);
   if(GlobalVariableCheck(keyNeg))  GlobalVariableDel(keyNeg);
   if(GlobalVariableCheck(keyMinP)) GlobalVariableDel(keyMinP);
   if(GlobalVariableCheck(keyTier)) GlobalVariableDel(keyTier);
}

//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == InpMagicNumber &&
         (OrderType() == OP_BUY ||
          OrderType() == OP_SELL))
      {
         count++;
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
void GetOpenOrderTrailInfo(double &currentProfit,
                           double &peakProfit,
                           double &lockedProfit,
                           double &minimumProfit,
                           int &lossTier,
                           double &adaptiveTarget)
{
   currentProfit  = 0.0;
   peakProfit     = 0.0;
   lockedProfit   = 0.0;
   minimumProfit  = 0.0;
   lossTier       = 0;
   adaptiveTarget = InpTakeProfitUSD;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();

      currentProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      peakProfit =
         GetTrailValue(ticket,
                       "PEAK",
                       currentProfit);

      lockedProfit =
         GetTrailValue(ticket,
                       "LOCK",
                       0.0);

      minimumProfit =
         GetStoredMinimumProfit(ticket,
                                currentProfit);

      lossTier =
         GetStoredLossTier(ticket);

      adaptiveTarget =
         InpTakeProfitUSD;

      return;
   }
}

//============================== VISUALS =============================
void UpdateVisuals(bool entryReady,
                   int emaTrend)
{
   DrawEMALine();

   if(g_bosActive)
      DrawPullbackZone();

   DrawDashboard(entryReady ?
                 "ENTRY READY" :
                 g_lastStatus);
}

//+------------------------------------------------------------------+
void DrawEMALine()
{
   int bars = (int)MathMin(InpEMALineBars,
                           Bars - 2);

   if(bars < 1)
      return;

   DeleteObjectsByPrefix(PFX + "EMA_SEG_");

   for(int i = bars; i >= 1; i--)
   {
      string name =
         PFX + "EMA_SEG_" +
         IntegerToString(i);

      double e1 =
         iMA(Symbol(), Period(),
             InpEMAPeriod, 0,
             MODE_EMA, PRICE_CLOSE, i);

      double e2 =
         iMA(Symbol(), Period(),
             InpEMAPeriod, 0,
             MODE_EMA, PRICE_CLOSE, i - 1);

      ObjectCreate(0,
                   name,
                   OBJ_TREND,
                   0,
                   Time[i], e1,
                   Time[i - 1], e2);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_RAY,
                       false);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_COLOR,
                       clrOrange);

      ObjectSetInteger(0,
                       name,
                       OBJPROP_WIDTH,
                       2);
   }
}

//+------------------------------------------------------------------+
void DrawBOS(int dir,
             double level,
             double bosPrice,
             datetime t)
{
   DeleteObjectsByPrefix(PFX + "BOS_LINE_");
   DeleteObjectsByPrefix(PFX + "BOS_TEXT_");

   string lineName = PFX + "BOS_LINE_CURRENT";
   string textName = PFX + "BOS_TEXT_CURRENT";

   DrawHLine(lineName,
             level,
             dir == 1 ? clrLime : clrRed,
             STYLE_SOLID,
             dir == 1 ? "BOS BUY" : "BOS SELL");

   DrawText(textName,
            t,
            bosPrice,
            dir == 1 ? "BOS BUY" : "BOS SELL",
            dir == 1 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
void DrawPullbackZone()
{
   double z1 = 0.0;
   double z2 = 0.0;

   if(g_bosDirection == 1)
   {
      z1 = g_bosPrice - InpPullbackMinRaw;
      z2 = g_bosPrice - InpPullbackMaxRaw;
   }
   else if(g_bosDirection == -1)
   {
      z1 = g_bosPrice + InpPullbackMinRaw;
      z2 = g_bosPrice + InpPullbackMaxRaw;
   }

   if(z1 == 0.0 || z2 == 0.0)
      return;

   double top = MathMax(z1, z2);
   double bot = MathMin(z1, z2);

   datetime t1 = g_bosTime;
   datetime t2 =
      TimeCurrent() +
      PeriodSeconds() *
      InpPullbackMaxBars;

   string name = PFX + "PULLBACK_ZONE";

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0,
                   name,
                   OBJ_RECTANGLE,
                   0,
                   t1, top,
                   t2, bot);
   }
   else
   {
      ObjectMove(0, name, 0, t1, top);
      ObjectMove(0, name, 1, t2, bot);
   }

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    g_bosDirection == 1 ?
                    clrPaleGreen :
                    clrMistyRose);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_BACK,
                    true);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_STYLE,
                    STYLE_SOLID);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    1);

   DrawHLine(PFX + "BOS_PRICE",
             g_bosPrice,
             clrGold,
             STYLE_DASH,
             "BOS Price");
}

//+------------------------------------------------------------------+
void DrawEntryArrow(int dir,
                    double price,
                    datetime t)
{
   string name =
      PFX + "ENTRY_" +
      IntegerToString((int)t);

   ObjectCreate(0,
                name,
                OBJ_ARROW,
                0,
                t,
                price);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    dir == 1 ? clrLime : clrRed);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    2);

   DrawText(PFX + "ENTRY_TEXT_" +
            IntegerToString((int)t),
            t,
            price,
            dir == 1 ?
            "PULLBACK BUY" :
            "PULLBACK SELL",
            dir == 1 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
void DrawMomentumArrow(int dir,
                       double price,
                       datetime t)
{
   string name =
      PFX + "MOMENTUM_ENTRY_" +
      IntegerToString((int)t);

   ObjectCreate(0,
                name,
                OBJ_ARROW,
                0,
                t,
                price);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    clrGold);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    3);

   DrawText(PFX + "MOMENTUM_TEXT_" +
            IntegerToString((int)t),
            t,
            price,
            dir == 1 ?
            "MOMENTUM BUY" :
            "MOMENTUM SELL",
            clrGold);
}

//+------------------------------------------------------------------+
void DrawCleanPullbackArrow(int dir,
                            double price,
                            datetime t,
                            int sourceTicket)
{
   string suffix =
      IntegerToString((int)t) + "_" +
      IntegerToString(sourceTicket);

   string name =
      PFX + "CLEAN_PULLBACK_ENTRY_" +
      suffix;

   ObjectCreate(0,
                name,
                OBJ_ARROW,
                0,
                t,
                price);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    clrAqua);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    3);

   DrawText(PFX + "CLEAN_PULLBACK_TEXT_" +
            suffix,
            t,
            price,
            dir == 1 ?
            "CLEAN BOS BUY" :
            "CLEAN BOS SELL",
            clrAqua);
}

//+------------------------------------------------------------------+
void DrawRecoveryArrow(int dir,
                       double price,
                       datetime t,
                       int parentTicket)
{
   string suffix =
      IntegerToString((int)t) + "_" +
      IntegerToString(parentTicket);

   string name =
      PFX + "RECOVERY_ENTRY_" +
      suffix;

   ObjectCreate(0,
                name,
                OBJ_ARROW,
                0,
                t,
                price);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    clrGold);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    3);

   DrawText(PFX + "RECOVERY_TEXT_" +
            suffix,
            t,
            price,
            dir == 1 ?
            "RECOVERY BUY" :
            "RECOVERY SELL",
            clrGold);
}

//+------------------------------------------------------------------+
void DrawDashboard(string status)
{
   string dir = "NONE";

   if(g_bosDirection == 1)  dir = "BUY";
   if(g_bosDirection == -1) dir = "SELL";

   int emaTrend = GetEMATrend();

   string emaTxt = "FLAT";

   if(emaTrend == 1)  emaTxt = "BUY";
   if(emaTrend == -1) emaTxt = "SELL";

   double ema =
      iMA(Symbol(), Period(),
          InpEMAPeriod, 0,
          MODE_EMA, PRICE_CLOSE, 1);

   double pullbackRaw =
      GetCurrentPullbackRaw();

   double continuationRaw =
      GetCurrentContinuationRaw();

   double currentProfit = 0.0;
   double peakProfit = 0.0;
   double lockedProfit = 0.0;
   double minimumProfit = 0.0;
   int lossTier = 0;
   double adaptiveTarget = InpTakeProfitUSD;

   GetOpenOrderTrailInfo(currentProfit,
                         peakProfit,
                         lockedProfit,
                         minimumProfit,
                         lossTier,
                         adaptiveTarget);

   double recoveryBasketProfit = 0.0;
   int recoveryParentTicket = -1;
   int recoveryTicket = -1;

   bool hasRecoveryBasket =
      GetRecoveryBasketInfo(recoveryBasketProfit,
                            recoveryParentTicket,
                            recoveryTicket);

   string cleanPBDir = "NONE";

   if(g_cleanPullbackDirection == 1)
      cleanPBDir = "BUY";

   if(g_cleanPullbackDirection == -1)
      cleanPBDir = "SELL";

   string txt =
      "EMA + CLOSED BOS + CONFIRMED PULLBACK EA\n";

   txt +=
      "Dubai Day Base: $" +
      DoubleToString(g_dailyStartBalance, 2) +
      "\n";

   txt +=
      "Daily Target  : " +
      DoubleToString(InpProfitTargetPercent, 2) +
      "% | $" +
      DoubleToString(g_dailyTargetEquity, 2) +
      "\n";

   txt +=
      "Account Equity: $" +
      DoubleToString(AccountEquity(), 2) +
      "\n";

   txt +=
      "New Orders    : " +
      (IsDailyNewOrderPaused() ?
       "PAUSED" :
       "ACTIVE") +
      "\n";

   txt +=
      "Dubai Pause   : 16:00-20:00\n";

   txt +=
      "EMA Trend     : " +
      emaTxt +
      "\n";

   txt +=
      "EMA" +
      IntegerToString(InpEMAPeriod) +
      "         : " +
      DoubleToString(ema, Digits) +
      "\n";

   txt +=
      "BOS Direction : " +
      dir +
      "\n";

   txt +=
      "BOS Active    : " +
      BoolText(g_bosActive) +
      "\n";

   txt +=
      "BOS Price     : " +
      DoubleToString(g_bosPrice, Digits) +
      "\n";

   txt +=
      "EMA Match     : " +
      BoolText(emaTrend == g_bosDirection &&
               emaTrend != 0) +
      "\n";

   txt +=
      "BOS Hold      : " +
      BoolText(IsBOSStructureHolding()) +
      "\n";

   txt +=
      "Spike Block   : " +
      BoolText(IsRecentSpikeBlocked()) +
      "\n";

   txt +=
      "Pullback Raw  : " +
      DoubleToString(pullbackRaw, 1) +
      " / " +
      DoubleToString(InpPullbackMinRaw, 0) +
      "-" +
      DoubleToString(InpPullbackMaxRaw, 0) +
      "\n";

   txt +=
      "PB Remembered : " +
      BoolText(g_pullbackTouchLatched) +
      " | Raw " +
      DoubleToString(g_pullbackTouchRaw, 1) +
      "\n";

   txt +=
      "Momentum Raw  : " +
      DoubleToString(continuationRaw, 1) +
      " / " +
      DoubleToString(InpMomentumContinuationRaw, 0) +
      "\n";

   txt +=
      "MOM Remembered: " +
      BoolText(g_momentumTouchLatched) +
      " | Raw " +
      DoubleToString(g_momentumTouchRaw, 1) +
      "\n";

   txt +=
      "Clean PB Rule : NEVER NEGATIVE + FUTURE/SAME BOS\n";

   txt +=
      "Clean PB Wait : " +
      BoolText(g_cleanPullbackPending) +
      " | " +
      cleanPBDir +
      " | Source #" +
      IntegerToString(g_cleanPullbackSourceTicket) +
      "\n";

   txt +=
      "Clean PB Exp. : " +
      IntegerToString(InpCleanProfitPullbackMaxBars) +
      " bars\n";

   txt +=
      "Open Orders   : " +
      IntegerToString(CountMyOrders()) +
      "\n";

   txt +=
      "Recovery Rule : LOSS + BOS SAME DIR\n";

   txt +=
      "Recovery Gap  : " +
      DoubleToString(InpRecoveryRawDifference, 0) +
      " raw\n";

   txt +=
      "Recovery B/S  : " +
      IntegerToString(CountRecoveryOrders(OP_BUY)) +
      "/" +
      IntegerToString(CountRecoveryOrders(OP_SELL)) +
      "\n";

   txt +=
      "Pair Target   : " +
      (hasRecoveryBasket ?
       (IsBreakEvenLossTier(g_assignedLossTier) ?
        "BREAK-EVEN" :
        "$" +
        DoubleToString(InpTakeProfitUSD, 2)) :
       "$" +
       DoubleToString(InpTakeProfitUSD, 2)) +
      " | Global tier " +
      IntegerToString(g_assignedLossTier) +
      "\n";

   txt +=
      "Pair Basket P/L: " +
      (hasRecoveryBasket ?
       "$" +
       DoubleToString(recoveryBasketProfit, 2) +
       " | P#" +
       IntegerToString(recoveryParentTicket) +
       " R#" +
       IntegerToString(recoveryTicket) :
       "NONE") +
      "\n";

   txt +=
      "Emergency SL  : -$" +
      DoubleToString(InpFixedStopLossUSD, 2) +
      "\n";

   txt +=
      "Original TP   : $" +
      DoubleToString(g_originalTakeProfitUSD, 4) +
      "\n";

   txt +=
      "Assigned TP   : $" +
      DoubleToString(InpTakeProfitUSD, 4) +
      "\n";

   txt +=
      "Global Tier   : " +
      IntegerToString(g_assignedLossTier) +
      "\n";

   txt +=
      "Min P/L Seen  : $" +
      DoubleToString(minimumProfit, 2) +
      "\n";

   txt +=
      "Loss Tier     : " +
      IntegerToString(lossTier) +
      "\n";

   txt +=
      "Active Target : " +
      (IsBreakEvenLossTier(g_assignedLossTier) ?
       "BREAK-EVEN" :
       "$" +
       DoubleToString(adaptiveTarget, 4)) +
      "\n";

   txt +=
      "Current P/L   : $" +
      DoubleToString(currentProfit, 2) +
      "\n";

   txt +=
      "Peak Profit   : $" +
      DoubleToString(peakProfit, 2) +
      "\n";

   txt +=
      "Locked Profit : $" +
      DoubleToString(lockedProfit, 2) +
      "\n";

   txt +=
      "Status        : " +
      status;

   Comment(txt);
}

//+------------------------------------------------------------------+
void DrawHLine(string name,
               double price,
               color clr,
               int style,
               string desc)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0,
                   name,
                   OBJ_HLINE,
                   0,
                   0,
                   price);
   }

   ObjectSetDouble(0,
                   name,
                   OBJPROP_PRICE1,
                   price);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    clr);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_STYLE,
                    style);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_WIDTH,
                    1);

   ObjectSetString(0,
                   name,
                   OBJPROP_TEXT,
                   desc);
}

//+------------------------------------------------------------------+
void DrawText(string name,
              datetime t,
              double price,
              string text,
              color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0,
                   name,
                   OBJ_TEXT,
                   0,
                   t,
                   price);
   }

   ObjectMove(0,
              name,
              0,
              t,
              price);

   ObjectSetString(0,
                   name,
                   OBJPROP_TEXT,
                   text);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_COLOR,
                    clr);

   ObjectSetInteger(0,
                    name,
                    OBJPROP_FONTSIZE,
                    9);
}

//+------------------------------------------------------------------+
string BoolText(bool value)
{
   return(value ? "YES" : "NO");
}

//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   int total =
      ObjectsTotal(ChartID(), -1, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name =
         ObjectName(ChartID(), i, -1, -1);

      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(ChartID(), name);
   }
}
//+------------------------------------------------------------------+
