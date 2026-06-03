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
#define DXB_HARD_MAX_OPEN_ORDERS 1   // absolute safety limit before every OrderSend

double InpBasketProfitUSD         = 1.00;
double InpBasketStopLossUSD       = 3.00;   // basket stop loss in USD, 0 = disabled
bool   InpOpenRecoveryAfterClose  = true;   // open recovery order after SL/SAR flip/early reverse close
double InpRecoveryProfitUSD       = 0.50;   // close recovery order when this USD profit is reached
bool   InpRecoveryAfterSLReverse  = true;   // true: after basket SL, open opposite direction
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
double InpMinPriceGap             = 100.00;    // raw price gap, 0 = disabled

// SAR settings
double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;

// SAR flip confirmation filters
// 1) EMA9/EMA21 trend filter
// 2) Wait for one fully closed candle after SAR flip
// 3) Confirm raw price difference from SAR flip price
bool   InpUseSARFlipConfirmations = true;
bool   InpUseSAREMAConfirm        = true;
bool   InpUseSARClosedCandleConfirm = true;
bool   InpUseSARPriceDiffConfirm  = true;
double InpSARConfirmPriceDiff     = 50.0;   // raw price diff for BTCUSD, not points

// Early trend settings
bool   InpUseEarlyTrend           = true;
int    InpFastEMA                 = 9;
int    InpSlowEMA                 = 21;
int    InpEarlyLookbackCandles    = 10;
double InpMinEarlyBodyMove        = 0.00;    // raw price diff, 0 = disabled
bool   InpCloseOnEarlyReverse     = true;
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

// SAR flip pending confirmation state
int      g_pendingSARConfirmDirection = 0;  // 1 BUY, -1 SELL, 0 none
double   g_pendingSARConfirmPrice     = 0.0;
datetime g_pendingSARConfirmTime      = 0;
datetime g_pendingSARConfirmBarTime   = 0;

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
   ResetSARFlipConfirmation();

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
      Print("FIRST SAR LOCKED | Direction=", DirectionText(g_activeSARDirection));
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
bool OpenRecoveryOrder(int direction, string sourceReason)
{
   if(!InpOpenRecoveryAfterClose)
      return(false);

   if(direction == 0)
      return(false);

   RefreshRates();

   if(CheckEquityConditions())
   {
      Print("RECOVERY ORDER BLOCKED | Equity/profit lock active. Source=", sourceReason);
      return(false);
   }

   // Recovery is independent, but only ONE recovery order is allowed at a time.
   // It is NOT blocked by normal order count, normal price gap, or normal order creation gates.
   if(CountRecoveryOrders() >= 1)
   {
      Print("RECOVERY ORDER BLOCKED | One recovery order already active. Source=", sourceReason);
      return(false);
   }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;
   double sl = 0;

   if(InpStopLossPoints > 0)
   {
      if(direction == 1)
         sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else
         sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
   }

   double lot = NormalizeLot(InpFixedLot);

   string comment = "RECOVERY_TP_0.50_" + DirectionText(direction);

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
void ProcessSARFlipStateAndClose()
{
   int sarFlip = GetSARFlipSignal();
   if(sarFlip == 0 || sarFlip == g_activeSARDirection)
      return;

   g_activeSARDirection  = sarFlip;
   g_lastSARDotDirection = sarFlip;
   g_sarPausedByEarly    = false;
   g_earlyDirection      = 0;

   StartSARFlipConfirmation(sarFlip);

   Print("SAR CHANGED | New SAR=", DirectionText(sarFlip),
         " -> closing opposite orders and waiting confirmation");

   // SAR flip close is order-management and must run before any new-order gate.
   CloseOppositeOrders(sarFlip, "SAR changed");

   // After reverse/SAR trend close, immediately open recovery order in new SAR direction.
   OpenRecoveryOrder(sarFlip, "SAR reverse trend close");
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

   // PRIORITY 2: Basket stop loss / basket profit close.
   double activeProfit = GetBasketProfit(g_activeSARDirection);

   if(InpBasketStopLossUSD > 0.0 && activeProfit <= -InpBasketStopLossUSD)
   {
      int oldDirection = g_activeSARDirection;
      CloseOrdersByDirection(oldDirection,
                             "Basket stop loss $" + DoubleToString(activeProfit, 2));

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

   if(activeProfit >= InpBasketProfitUSD)
   {
      CloseOrdersByDirection(g_activeSARDirection,
                             "Basket profit $" + DoubleToString(activeProfit, 2));

      Print("BASKET PROFIT HIT | Direction=", DirectionText(g_activeSARDirection),
            " | Profit=$", DoubleToString(activeProfit, 2));

      status = "Basket profit booked";
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool ProcessNewOrderCreationLast(bool isNewBar, string &status)
{
   if(g_activeSARDirection == 0)
   {
      status = "Waiting for first SAR";
      return(false);
   }

   // Pending SAR confirmation blocks ONLY new orders. It cannot block close management.
   if(g_pendingSARConfirmDirection != 0)
   {
      if(!IsSARFlipConfirmationReady())
      {
         status = "WAIT SAR CONFIRM " + DirectionText(g_pendingSARConfirmDirection);
         return(false);
      }

      Print("SAR CONFIRMED | Direction=", DirectionText(g_pendingSARConfirmDirection),
            " | FlipPrice=", DoubleToString(g_pendingSARConfirmPrice, Digits),
            " | Close[1]=", DoubleToString(Close[1], Digits));

      ResetSARFlipConfirmation();
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

   if(CountAllSymbolMarketOrders() >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      status = "MAX ORDERS ACTIVE - WAIT CLOSE";
      return(false);
   }

   if(InpOneOrderPerBar && !isNewBar)
   {
      status = "Waiting new bar";
      return(false);
   }

   if(!CanOpenNewOrder(g_activeSARDirection))
   {
      status = "Order gate blocked";
      return(false);
   }

   if(OpenMarketOrder(g_activeSARDirection, "SAR continuous cycle"))
      status = "Active " + DirectionText(g_activeSARDirection);
   else
      status = "OrderSend failed";

   return(true);
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

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

   DrawSARDots();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
      g_lastBarTime = Time[0];

   string status = "RUNNING";

   // SECTION 1: Signal state update. No new orders here.
   UpdateBarAndSARVisualState(isNewBar);
   ProcessSARFlipStateAndClose();

   // SECTION 2: Close management FIRST. No new-order gate is allowed before this.
   bool closedThisTick = ProcessCloseOrdersFirst(status);

   // SECTION 3: New order creation LAST. Runs only if nothing closed this tick.
   if(!closedThisTick)
      ProcessNewOrderCreationLast(isNewBar, status);

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

   if(Bars < 10)
      return(false);

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

   // 3) Raw price difference confirmation from SAR flip reference price.
   //    BUY: Close[1] must move above flip price by InpSARConfirmPriceDiff.
   //    SELL: Close[1] must move below flip price by InpSARConfirmPriceDiff.
   if(InpUseSARPriceDiffConfirm && InpSARConfirmPriceDiff > 0.0)
   {
      double diff = 0.0;

      if(direction == 1)
         diff = Close[1] - g_pendingSARConfirmPrice;
      else
         diff = g_pendingSARConfirmPrice - Close[1];

      if(diff < InpSARConfirmPriceDiff)
      {
         Print("SAR CONFIRM WAIT | Price diff ",
               DoubleToString(diff, Digits), " < required ",
               DoubleToString(InpSARConfirmPriceDiff, Digits));
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

   DashRow("Pending SAR",
           DirectionText(g_pendingSARConfirmDirection),
           g_pendingSARConfirmDirection == 0 ? clrLime : clrOrange);

   DashRow("SAR Confirm Diff",
           DoubleToString(InpSARConfirmPriceDiff, 2),
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

   DashRow("Basket TP",
           "$"+DoubleToString(InpBasketProfitUSD,2),
           clrLime);

   DashRow("Basket SL",
           "$"+DoubleToString(InpBasketStopLossUSD,2),
           clrRed);

   DashRow("Recovery TP",
           "$"+DoubleToString(InpRecoveryProfitUSD,2),
           clrGold);

   DashRow("Recovery Orders",
           IntegerToString(CountRecoveryOrders()),
           CountRecoveryOrders() > 0 ? clrOrange : clrLime);

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

   DashRow("Notifications",
           InpSendPushNotifications ? "PUSH ON" : "PUSH OFF",
           InpSendPushNotifications ? clrLime : clrRed);

   DashRow("Lot Size",
           DoubleToString(InpFixedLot,2),
           clrWhite);
}
//+------------------------------------------------------------------+
