//+------------------------------------------------------------------+
//| BTCUSD_EMA_BOS_PENDING_RECOVERY_DYNAMIC_LOCK_V4.mq4            |
//| All entries -> 20-raw pending STOP orders                       |
//| Recovery: raw gap OR deep-loss comeback                         |
//| Arm $0.25 -> broker SL lock $0.10 + dynamic X ladder           |
//+------------------------------------------------------------------+
#property strict
#property version   "4.00"

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

// Momentum continuation entry:
// BUY  = price continues above the bullish BOS price by this raw distance.
// SELL = price continues below the bearish BOS price by this raw distance.
// It is armed only if the pullback zone was not touched first.
bool   InpUseMomentumContinuation    = true;
double InpMomentumContinuationRaw    = 100.0;

// SIDE-BASKET dynamic profit management (BUY and SELL are independent).
// The small minimum close is NOT armed immediately. The basket must first
// reach InpDynamicBasketMinimumArmUSD, then the protected floor becomes
// InpDynamicBasketMinimumCloseUSD. After X1, locks advance by the configured
// multiplier step. Example: arm=$0.25, minimum close=$0.10, X1=$0.50,
// multiplier step=1.00 => no lock below $0.25, then $0.10, $0.50, $1.00,
// $1.50... InpDynamicBasketProfitMaxX=0.0 keeps the ladder unlimited.
// It does not close while profit is rising; it closes only when basket profit
// falls back to the highest completed protected level.
// Basket touched a full negative step: normal trailing is cancelled and the
// basket closes immediately when it recovers to the reduced positive target.
// Example with InpAdaptiveLossLevelUSD = 1.00:
//   minimum above -$1.00 => normal minimum/X1/X2/X3 ladder
//   touch -$1.00         => comeback target = TP / 2
//   touch -$2.00         => comeback target = TP / 3
//   touch -$3.00         => comeback target = TP / 4
// The worst BUY loss never changes SELL state, and vice versa.
double InpBasketProfitUSD                    = 0.50; // X1 base profit step
double InpDynamicBasketMinimumArmUSD        = 0.25; // arm small-profit protection only here
double InpDynamicBasketMinimumCloseUSD      = 0.10; // protected floor after minimum arm
double InpDynamicBasketMultiplierStep       = 0.50;//1.00; // X1, X2, X3... when set to 1.00
double InpDynamicBasketProfitMaxX            = 0.0; // 0.0 = unlimited; e.g. 5.0 caps at X5

// Broker/server-side profit protection:
// After the dynamic basket ladder arms a protected USD level, the EA converts
// that side-basket profit into a real SL price and applies it to every open
// BUY or SELL order in that side. The EA ladder still continues upward.
// The buffer is added only while converting the USD lock to a price, helping
// absorb commission, swap changes, tick rounding and normal execution slippage.
// Broker gaps and extreme slippage can still produce a different final result.
bool   InpUseServerSideProfitLock            = true;
double InpServerProfitLockBufferUSD          = 0.03;
int    InpServerProfitLockRetrySeconds       = 5;

double InpFixedStopLossUSD                   = 0.25;//2.00;



// Dubai daily account-profit protection.
// Example: day-start balance $40 and target 50% means close all EA orders
// when equity reaches $60 and pause until the next Dubai calendar date.
double InpProfitTargetPercent        =20;// 50;//20.0;//market will be weak after some profit - avoid stoploss 

bool   InpUseAdaptiveLossTarget      = false;
double InpAdaptiveLossLevelUSD       = 1.00;    
double InpBreakEvenCloseProfitUSD    = 0.00;
double InpBreakEvenAfterLossUSD      =10;// 7;////5.00;


int    InpMaxOpenOrders              = 1;

// Automatic MIXED-market detection based on CLOSED candles.
// MIXED requires:
// 1. Recent high-low range between MinRangeRaw and MaxRangeRaw, and
// 2. Low directional efficiency OR repeated EMA crossings.
int    InpMixedLookbackBars          = 20;
double InpMixedMinRangeRaw           = 50.0;
double InpMixedMaxRangeRaw           = 300.0;
double InpMixedMaxEfficiency         = 0.45;
int    InpMixedMinEMACrossings       = 3;

// Runtime state. The EA updates this automatically on every tick.
// true  = MIXED market: ALL new orders are paused and existing
//         BUY/SELL baskets use InpBasketProfitUSD / 2.
// false = not MIXED: normal entry rules and full TP are used.
bool   InpMarketMixedMode            = false;

bool   InpOnlyNewCandleEntry         = true;
bool   InpShowVisuals                = true;
int    InpEMALineBars                = 80;

// Professional right-side dashboard settings.
int    InpDashboardRightMargin       = 12;
int    InpDashboardTopMargin         = 18;
int    InpDashboardWidth             = 350;
int    InpDashboardFontSize          = 8;
int    InpDashboardRowHeight         = 17;

// Every entry path is converted to a direction-matching pending STOP order.
// BUY entries become BUYSTOP at Ask + raw gap.
// SELL entries become SELLSTOP at Bid - raw gap.
bool   InpUsePendingStopOrders       = true;
double InpPendingStopGapRawPrice     = 20.0;
int    InpPendingCleanupMinutes      = 30; // delete every untriggered EA pending order

// Dubai hours during which NEW orders are blocked.
// Enter individual hours from 0 to 23, separated by commas.
// Example: "14,15,16,17,18,19" blocks 14:00 through 19:59.
// Separate hours are also supported: "4,8,14,17,22".
// Leave empty ("") to disable the Dubai-hours pause.
string InpDubaiBlockedHours          = "14,15,16,17,18,19,20";

// Recovery order settings.
// Recovery opens in the SAME direction as a losing regular parent.
// Active BOS must match, and either the raw gap OR loss-comeback must trigger.
bool   InpUseRecoveryOrders                = true;
double InpRecoveryLotSize                  = 0.02;
double InpRecoveryRawDifference            = 50.0; // normal raw-price trigger
bool   InpUseRecoveryLossComebackTrigger   = true; // independent OR trigger
double InpRecoveryDeepLossUSD              = 2.00; // basket must first touch -$3
double InpRecoveryComebackImprovementUSD   = 1.00; // then improve by $1, e.g. -$3 to -$2
int    InpMaxRecoveryOrdersPerDirection    = 1;

// Close linked parent + recovery together at the assigned basket target.
bool   InpCloseRecoveryBasketAtTP        = true;

// Clean-profit BOS continuation re-entry.
// Any profitable REGULAR order that never recorded negative net P/L arms
// one same-direction re-entry. It then waits for an active matching BOS.
// The matching BOS does NOT need to exist at the exact closing tick.
bool   InpUseCleanProfitPullback          = true;
int    InpCleanProfitPullbackMaxBars      = 3;

// Emergency money stop. Keep it above the break-even trigger.

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

datetime g_lastBarTime             = 0;
long     g_lastPendingCleanupSlot   = -1;
datetime g_lastPendingCleanupTime  = 0;
string   g_lastStatus              = "Starting";
string   PFX                       = "EMABOSPB_";

//-------------------------- Daily target state -----------------------
int      g_dailyDubaiDateKey       = 0;
double   g_dailyStartBalance       = 0.0;
double   g_dailyTargetEquity       = 0.0;
bool     g_dailyProfitTargetHit    = false;

enum EA_PAUSE_REASON
{
   PAUSE_REASON_NONE         = 0,
   PAUSE_REASON_DAILY_TARGET = 1,
   PAUSE_REASON_DUBAI_HOURS  = 2,
   PAUSE_REASON_MIXED_MODE   = 3
};

//----------------------- Clean pullback state ------------------------
bool     g_cleanPullbackPending       = false;
int      g_cleanPullbackDirection     = 0;
int      g_cleanPullbackSourceTicket  = -1;
datetime g_cleanPullbackCloseTime     = 0;
datetime g_cleanPullbackCloseBarTime  = 0;
double   g_cleanPullbackClosePrice    = 0.0;

//------------------------- Adaptive TP state -------------------------
double   g_originalTakeProfitUSD      = 0.0;
// Per-order adaptive values remain available for linked recovery pairs.
// Main profit booking uses independent BUY/SELL side-basket memory.
double   g_assignedBuyTakeProfitUSD   = 0.0;
double   g_assignedSellTakeProfitUSD  = 0.0;
int      g_assignedBuyLossTier        = 0;
int      g_assignedSellLossTier       = 0;

// Last broker-side profit-lock modification attempts. BUY and SELL retry
// independently so a temporary broker trade-context/freeze restriction on one
// side does not block the other side.
datetime g_lastBuyServerLockAttemptTime  = 0;
datetime g_lastSellServerLockAttemptTime = 0;

//----------------------- Automatic market mode ----------------------
double   g_mixedRangeRaw              = 0.0;
double   g_mixedEfficiency            = 0.0;
int      g_mixedEMACrossings          = 0;

//+------------------------------------------------------------------+
datetime GetDubaiTime()
{
   return(TimeGMT() + 4 * 3600);
}

//+------------------------------------------------------------------+
// Returns true when the current Dubai hour appears in the configured
// comma-separated list. Surrounding both strings with commas prevents
// partial matches; hour 1 cannot accidentally match 10, 11, 12, etc.
//+------------------------------------------------------------------+
bool IsDubaiBlockedTime()
{
   int dubaiHour = TimeHour(GetDubaiTime());
   string configuredHours = InpDubaiBlockedHours;

   // Accept both "14,15,16" and "14, 15, 16".
   StringReplace(configuredHours, " ", "");

   if(StringLen(configuredHours) <= 0)
      return(false);

   string hourList = "," + configuredHours + ",";
   string hourText = "," + IntegerToString(dubaiHour) + ",";

   return(StringFind(hourList, hourText, 0) >= 0);
}

//+------------------------------------------------------------------+
string GetDubaiPauseWindowText()
{
   string configuredHours = InpDubaiBlockedHours;
   StringReplace(configuredHours, " ", "");

   if(StringLen(configuredHours) <= 0)
      return("DISABLED");

   return("[" + configuredHours + "]");
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
   GlobalVariableSet(DailyProfitStateKey("PERCENT"),
                     InpProfitTargetPercent);
}

//+------------------------------------------------------------------+
void DeleteGlobalVariableIfExists(string key)
{
   if(GlobalVariableCheck(key))
      GlobalVariableDel(key);
}

//+------------------------------------------------------------------+
// Reset only the daily-target Global Variables on EA initialization.
// Order-level adaptive TP, minimum-profit and recovery memory are kept.
//+------------------------------------------------------------------+
void ResetDailyTargetGlobalsOnInit()
{
   DeleteGlobalVariableIfExists(DailyProfitStateKey("DATE"));
   DeleteGlobalVariableIfExists(DailyProfitStateKey("BASE"));
   DeleteGlobalVariableIfExists(DailyProfitStateKey("TARGET"));
   DeleteGlobalVariableIfExists(DailyProfitStateKey("HIT"));
   DeleteGlobalVariableIfExists(DailyProfitStateKey("PERCENT"));

   GlobalVariablesFlush();

   g_dailyDubaiDateKey       = 0;
   g_dailyStartBalance       = 0.0;
   g_dailyTargetEquity       = 0.0;
   g_dailyProfitTargetHit    = false;

   ResetDailyProfitState(GetDubaiDateKey());

   Print("ONINIT DAILY RESET | Base $",
         DoubleToString(g_dailyStartBalance, 2),
         " | Target $",
         DoubleToString(g_dailyTargetEquity, 2),
         " | HIT cleared");
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

   string dateKey    = DailyProfitStateKey("DATE");
   string baseKey    = DailyProfitStateKey("BASE");
   string targetKey  = DailyProfitStateKey("TARGET");
   string hitKey     = DailyProfitStateKey("HIT");
   string percentKey = DailyProfitStateKey("PERCENT");

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

      bool percentChanged = true;

      if(GlobalVariableCheck(percentKey))
      {
         double storedPercent = GlobalVariableGet(percentKey);
         percentChanged =
            (MathAbs(storedPercent - InpProfitTargetPercent) > 0.0000001);
      }

      if(percentChanged)
      {
         g_dailyProfitTargetHit = false;
         GlobalVariableSet(hitKey, 0.0);
         GlobalVariableSet(percentKey, InpProfitTargetPercent);
      }
      else
      {
         g_dailyProfitTargetHit =
            (GlobalVariableCheck(hitKey) &&
             GlobalVariableGet(hitKey) >= 0.5);
      }

      GlobalVariableSet(targetKey, g_dailyTargetEquity);
   }

   if(InpProfitTargetPercent <= 0.0)
   {
      g_dailyProfitTargetHit = false;
      GlobalVariableSet(hitKey, 0.0);
      return;
   }

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
EA_PAUSE_REASON GetCurrentPauseReason()
{
   // Daily target has priority when both conditions are true.
   if(IsDailyNewOrderPaused())
      return(PAUSE_REASON_DAILY_TARGET);

   if(IsDubaiBlockedTime())
      return(PAUSE_REASON_DUBAI_HOURS);

   // MIXED mode blocks every NEW order type, but existing orders
   // continue to be managed with InpBasketProfitUSD / 2.
   if(InpMarketMixedMode)
      return(PAUSE_REASON_MIXED_MODE);

   return(PAUSE_REASON_NONE);
}

//+------------------------------------------------------------------+
string GetDubaiHoursPausedStatus()
{
   return("DUBAI BLOCKED HOURS " + GetDubaiPauseWindowText() +
          " | NEW ORDERS PAUSED | EXISTING ORDERS MANAGED");
}

//+------------------------------------------------------------------+
string GetMixedModePausedStatus()
{
   return("MIXED MARKET | ALL NEW ORDERS PAUSED | EXISTING TP $" +
          DoubleToString(GetMarketModeTakeProfitUSD(), 4) +
          " = InpBasketProfitUSD / 2");
}

//+------------------------------------------------------------------+
string GetEffectiveStatusText(string normalStatus)
{
   EA_PAUSE_REASON pauseReason = GetCurrentPauseReason();

   if(pauseReason == PAUSE_REASON_DAILY_TARGET)
   {
      if(CountMyOrders() > 0 ||
         CountMyPendingOrdersByDirection(OP_BUY) > 0 ||
         CountMyPendingOrdersByDirection(OP_SELL) > 0)
      {
         return("DAILY TARGET REACHED | CLOSING EA ORDERS | NEW ORDERS PAUSED");
      }

      return("DAILY TARGET REACHED | ALL EA ORDERS CLOSED | NEW ORDERS PAUSED");
   }

   if(pauseReason == PAUSE_REASON_DUBAI_HOURS)
      return(GetDubaiHoursPausedStatus());

   if(pauseReason == PAUSE_REASON_MIXED_MODE)
      return(GetMixedModePausedStatus());

   return(normalStatus);
}

//+------------------------------------------------------------------+
bool CloseAllMyOrdersAtDailyTarget()
{
   // Pending orders must be removed first so none can trigger after the
   // daily account target has paused trading.
   bool pendingCleared =
      DeleteAllMyPendingOrders("daily target reached");

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
         RestoreDefaultTakeProfitAfterClose();

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
      if(pendingCleared)
      {
         g_lastStatus = "DAILY TARGET REACHED | ALL ORDERS CLOSED | PAUSED";
         return(true);
      }

      g_lastStatus = "DAILY TARGET | PENDING DELETE RETRY | PAUSED";
      return(false);
   }

   if(failedOrders == 0 && pendingCleared)
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
// Detect a mixed/choppy market from CLOSED candles only.
// Directional efficiency = net movement / total candle-to-candle path.
// A lower value means price travelled back and forth instead of moving
// efficiently in one direction.
//+------------------------------------------------------------------+
bool DetectMarketMixedMode()
{
   g_mixedRangeRaw     = 0.0;
   g_mixedEfficiency   = 0.0;
   g_mixedEMACrossings = 0;

   int lookback = InpMixedLookbackBars;

   if(lookback < 5)
      lookback = 5;

   if(Bars < lookback + InpEMAPeriod + 5)
      return(false);

   int highestIndex = iHighest(Symbol(), Period(), MODE_HIGH,
                               lookback, 1);
   int lowestIndex  = iLowest(Symbol(), Period(), MODE_LOW,
                              lookback, 1);

   if(highestIndex < 0 || lowestIndex < 0)
      return(false);

   g_mixedRangeRaw = High[highestIndex] - Low[lowestIndex];

   double totalPath = 0.0;

   for(int i = 1; i < lookback; i++)
   {
      totalPath += MathAbs(Close[i] - Close[i + 1]);

      double emaCurrent = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                              MODE_EMA, PRICE_CLOSE, i);
      double emaPrevious = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                               MODE_EMA, PRICE_CLOSE, i + 1);

      double currentSide  = Close[i]     - emaCurrent;
      double previousSide = Close[i + 1] - emaPrevious;

      if((currentSide > 0.0 && previousSide < 0.0) ||
         (currentSide < 0.0 && previousSide > 0.0))
      {
         g_mixedEMACrossings++;
      }
   }

   double netMovement = MathAbs(Close[1] - Close[lookback]);

   if(totalPath > 0.0000001)
      g_mixedEfficiency = netMovement / totalPath;
   else
      g_mixedEfficiency = 0.0;

   bool rangeIsMixed =
      (g_mixedRangeRaw >= InpMixedMinRangeRaw &&
       g_mixedRangeRaw <= InpMixedMaxRangeRaw);

   bool movementIsMixed =
      (g_mixedEfficiency <= InpMixedMaxEfficiency ||
       g_mixedEMACrossings >= InpMixedMinEMACrossings);

   return(rangeIsMixed && movementIsMixed);
}

//+------------------------------------------------------------------+
void UpdateMarketMixedMode()
{
   bool previousMode = InpMarketMixedMode;

   InpMarketMixedMode = DetectMarketMixedMode();

   if(previousMode != InpMarketMixedMode)
   {
      Print("MARKET MODE CHANGED | ",
            (InpMarketMixedMode ? "MIXED" : "NOT MIXED"),
            " | Range raw ", DoubleToString(g_mixedRangeRaw, 1),
            " | Efficiency ", DoubleToString(g_mixedEfficiency, 2),
            " | EMA crossings ", IntegerToString(g_mixedEMACrossings));
   }
}
uint g_onInitTickCount = 0;
//+------------------------------------------------------------------+
int OnInit()
{

   g_onInitTickCount = GetTickCount();
   datetime dubaiNow = GetDubaiTime();
   string dubaiTimeText = TimeToString(dubaiNow,
                                       TIME_DATE | TIME_SECONDS);

   Print("EA INIT | Dubai time ",
         dubaiTimeText,
         " | GMT+4",
         " | Blocked hours ",
         GetDubaiPauseWindowText());

   if(IsTesting())
      InpProfitTargetPercent = 5000.0;

   g_originalTakeProfitUSD     = InpBasketProfitUSD;
   g_assignedBuyTakeProfitUSD  = g_originalTakeProfitUSD;
   g_assignedSellTakeProfitUSD = g_originalTakeProfitUSD;
   g_assignedBuyLossTier       = 0;
   g_assignedSellLossTier      = 0;

   DeleteObjectsByPrefix(PFX);

   // Requested behavior: every EA initialization starts a fresh
   // daily target using the current account balance as the new base.
   ResetDailyTargetGlobalsOnInit();

   UpdateMarketMixedMode();
   UpdateSideProfitStates();

   if(IsDubaiBlockedTime())
      g_lastStatus = GetDubaiHoursPausedStatus() +
                     " | DUBAI " + dubaiTimeText;
   else
      g_lastStatus = "INITIALIZED | DUBAI " + dubaiTimeText +
                     " | DAILY TARGET RESET | TRADING ACTIVE";

   Print("EMA BOS Pullback + Momentum EA started",
         " | Dubai time ", dubaiTimeText,
         " | Effective SL $",
         DoubleToString(GetEffectiveFixedStopLossUSD(), 2),
         " | Minimum arm $",
         DoubleToString(InpDynamicBasketMinimumArmUSD, 2),
         " | Minimum close $",
         DoubleToString(InpDynamicBasketMinimumCloseUSD, 2),
         " | X1 $",
         DoubleToString(g_originalTakeProfitUSD, 2),
         " | X step $",
         DoubleToString(GetDynamicProfitLadderStepUSD(), 4),
         " | Server SL lock ",
         (InpUseServerSideProfitLock ? "ON" : "OFF"),
         " | Server buffer $",
         DoubleToString(InpServerProfitLockBufferUSD, 2),
         " | Pending gap raw ",
         DoubleToString(InpPendingStopGapRawPrice, 1));

   if(InpShowVisuals)
      DrawDashboard(g_lastStatus);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(PFX);
   Comment("");
}

int CountMyOrdersByType(int orderType)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() == orderType)
         count++;
   }

   return count;
}
//+------------------------------------------------------------------+
// Effective emergency stop loss:
//   min(configured maximum SL, current balance - $2 protection)
// The configured input is never overwritten, so the effective SL can
// increase again automatically when the account balance increases.
//+------------------------------------------------------------------+
double GetEffectiveFixedStopLossUSD()
{
   // A value <= 0 disables the emergency money stop.
   if(InpFixedStopLossUSD <= 0.0)
      return(0.0);

   double balanceBasedSL =10000; //AccountBalance() - 2.0;

   // Avoid a zero/negative threshold on very small balances.
   balanceBasedSL = MathMax(0.01, balanceBasedSL);

   return(NormalizeDouble(
             MathMin(InpFixedStopLossUSD, balanceBasedSL),
             2));
}

//+------------------------------------------------------------------+
void OnTick()
{


   if(AccountEquity() <= 0)
   {
      g_lastStatus =
         "LOW EQUITY | NEW TRADING PAUSED | EQUITY $" +
         DoubleToString(AccountEquity(), 2);

      Print(g_lastStatus);
      DeleteAllMyPendingOrders("low equity pause");

      if(InpShowVisuals)
         UpdateVisuals(false, GetEMATrend());

      return;
   }

uint startupElapsedMs = GetTickCount() - g_onInitTickCount;

if(startupElapsedMs < 5*1000)
{
   Print("Tick is received",
         " | Startup second ",
         IntegerToString((int)(startupElapsedMs / 1000) + 1),
         "/60",
         " | Dubai ",
         TimeToString(GetDubaiTime(), TIME_SECONDS));
}

   RefreshRates();

   // Delete every untriggered EA pending order at each 30-minute slot
   // before BOS/recovery/new-cycle entry logic is evaluated.
   CleanupPendingOrdersEveryInterval();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
      g_lastBarTime = Time[0];

   // Refresh the automatic MIXED/not-MIXED runtime variable.
   // Closed-candle data keeps the result stable during the live candle.
   UpdateMarketMixedMode();

   UpdateDailyProfitTargetState();

   if(IsDailyNewOrderPaused())
   {
      bool allClosed = CloseAllMyOrdersAtDailyTarget();

      if(allClosed)
         g_lastStatus =
            "DAILY TARGET REACHED | ALL EA ORDERS CLOSED | NEW ORDERS PAUSED";
      else
         g_lastStatus =
            "DAILY TARGET REACHED | ORDER CLOSE RETRY | NEW ORDERS PAUSED";

      if(InpShowVisuals)
         UpdateVisuals(false, GetEMATrend());

      return;
   }

   // Record drawdown before any close logic.
   UpdateAllOrderDrawdownStates();

   // Close parent + recovery baskets before individual exits.
   CloseRecoveryBasketsAtTP();

   // Refresh BOS and remember intrabar pullback/momentum events.
   DetectBOS();
   UpdateBOSSetupMemory();

   // A clean profitable close is allowed to arm re-entry even when no BOS
   // is active at this exact tick. The pending setup waits for a future
   // same-direction BOS.
   CloseByProfitOrLoss();

   // Refresh BUY and SELL adaptive summaries independently.
   AssignTakeProfitFromOpenOrderLosses();
   UpdateSideProfitStates();

   // Existing orders have already been managed above. During the Dubai
   // pause window, stop here so regular, recovery and clean re-entry orders
   // cannot be opened. The dashboard always shows the time-pause reason.
   if(IsDubaiBlockedTime())
   {
      DeleteAllMyPendingOrders("Dubai blocked-hours pause");
      g_lastStatus = GetDubaiHoursPausedStatus();

      if(InpShowVisuals)
         UpdateVisuals(false, GetEMATrend());

      return;
   }

   // MIXED mode: manage/close existing BUY and SELL baskets above,
   // using the active TP returned by GetMarketModeTakeProfitUSD().
   // Stop here before recovery, clean pullback, momentum or regular BOS
   // entry logic so absolutely no new order is created.
   if(InpMarketMixedMode)
   {
      DeleteAllMyPendingOrders("MIXED market pause");
      g_lastStatus = GetMixedModePausedStatus();

      if(InpShowVisuals)
         UpdateVisuals(false, GetEMATrend());

      return;
   }

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



// Current BOS order direction.
int orderType = (g_bosDirection == 1) ? OP_BUY : OP_SELL;

// Profit of the side opposite to the current BOS.
double oppositeSideProfit = 0.0;
int oppositeSideOrders = 0;

if(orderType == OP_BUY)
{
   oppositeSideProfit = GetMyOpenProfitByType(OP_SELL);
   oppositeSideOrders = CountMyOrdersByType(OP_SELL);
}
else
{
   oppositeSideProfit = GetMyOpenProfitByType(OP_BUY);
   oppositeSideOrders = CountMyOrdersByType(OP_BUY);
}

// Opposite-BOS exception begins when the opposite-side basket reaches
// half of the current effective emergency stop-loss threshold.
double effectiveStopLossUSD = GetEffectiveFixedStopLossUSD();
double halfStopLossTrigger =
   -(effectiveStopLossUSD / 2.0);

// Allow one order in the BOS direction even when the normal total-order
// limit is reached, but only when the opposite side is already losing
// enough and MIXED-market mode is disabled.
/*
bool allowOppositeBOSOrder =
   (effectiveStopLossUSD > 0.0 &&
    oppositeSideOrders > 0 &&
    oppositeSideProfit <= halfStopLossTrigger);

   //  allowOppositeBOSOrder=false;

if(allowOppositeBOSOrder &&
   !InpMarketMixedMode &&
   CountRecoveryOrders(orderType) == 0)
{
   // Apply the maximum separately to the new BOS direction.
   if(CountMyOrderEntitiesByDirection(orderType) >= InpMaxOpenOrders )
   {
      g_lastStatus =
         (orderType == OP_BUY)
         ? "Blocked: max BUY orders"
         : "Blocked: max SELL orders";

      return;
   }
}
else
{
   // Under normal conditions, apply the maximum to all open orders.
   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus = InpMarketMixedMode
                     ? "Blocked: MIXED market + max total orders"
                     : "Blocked: max total open orders";
      return;
   }
}
*/
   
  // int orderType = (g_bosDirection > 0) ? OP_BUY : OP_SELL;

if(CountMyOrderEntitiesByDirection(orderType) >= InpMaxOpenOrders)
{
   g_lastStatus = (orderType == OP_BUY)
                  ? "Blocked: max BUY orders"
                  : "Blocked: max SELL orders";
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
         double entryPrice = InpUsePendingStopOrders ?
            GetPendingStopEntryPrice(orderType) :
            ((orderType == OP_BUY) ? Ask : Bid);

         if(entrySetup == 2)
            DrawMomentumArrow(g_bosDirection, entryPrice, TimeCurrent());
         else
            DrawEntryArrow(g_bosDirection, entryPrice, TimeCurrent());

         g_lastStatus = setupText + " " + side +
                        (InpUsePendingStopOrders ?
                         " pending placed" : " opened");
         ConsumeCurrentBOS(setupText +
                           (InpUsePendingStopOrders ?
                            " pending placed" : " entry opened"));
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
   double ema1 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 1);
   double ema5 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 5);

   if(Close[1] > ema1 && ema1 > ema5) return(1);
   if(Close[1] < ema1 && ema1 < ema5) return(-1);

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
   bool directionChanged =
      (g_bosDirection != 0 && g_bosDirection != direction);

   if(directionChanged)
      DeleteAllMyPendingOrders("BOS direction changed");

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
void DetectBOS()
{
   if(Bars < InpSwingLookback + 5)
      return;

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

   double buyTrigger  = structureHigh + InpMinBOSRawGap;
   double sellTrigger = structureLow  - InpMinBOSRawGap;

   if(Ask > buyTrigger)
   {
      bool newDirection = (g_bosDirection != 1);
      bool newLevel = (g_lastBullishStructureLevel <= 0.0 ||
                       structureHigh >
                       g_lastBullishStructureLevel + Point * 0.5);

      // Do not replace an already-active same-direction BOS because
      // that would erase its remembered pullback/momentum setup.
      bool canActivate = newDirection || !g_bosActive;

      if(canActivate && (newDirection || newLevel))
      {
         ActivateBOS(1,
                     structureHigh,
                     Ask,
                     TimeCurrent());
      }

      return;
   }

   if(Bid < sellTrigger)
   {
      bool newDirection = (g_bosDirection != -1);
      bool newLevel = (g_lastBearishStructureLevel <= 0.0 ||
                       structureLow <
                       g_lastBearishStructureLevel - Point * 0.5);

      // Do not replace an already-active same-direction BOS because
      // that would erase its remembered pullback/momentum setup.
      bool canActivate = newDirection || !g_bosActive;

      if(canActivate && (newDirection || newLevel))
      {
         ActivateBOS(-1,
                     structureLow,
                     Bid,
                     TimeCurrent());
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

   if(InpUseMomentumContinuation &&
      InpMomentumContinuationRaw > 0.0 &&
      !g_pullbackTouchLatched &&
      !g_momentumTouchLatched)
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

   if(InpOnlyNewCandleEntry)
   {
      if(!isNewBar)
         return(false);

      if(g_pullbackTouchLatched &&
         g_pullbackTouchBarTime > 0 &&
         Time[0] != g_pullbackTouchBarTime)
      {
         entrySetup = 1;
         return(true);
      }

      if(g_momentumTouchLatched &&
         g_momentumTouchBarTime > 0 &&
         Time[0] != g_momentumTouchBarTime)
      {
         entrySetup = 2;
         return(true);
      }

      return(false);
   }

   if(g_pullbackTouchLatched)
   {
      entrySetup = 1;
      return(true);
   }

   if(g_momentumTouchLatched)
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
bool IsPendingOrderType(int orderType)
{
   return(orderType == OP_BUYLIMIT ||
          orderType == OP_SELLLIMIT ||
          orderType == OP_BUYSTOP ||
          orderType == OP_SELLSTOP);
}

//+------------------------------------------------------------------+
bool IsOrderTypeForMarketDirection(int actualType, int marketType)
{
   if(marketType == OP_BUY)
      return(actualType == OP_BUY ||
             actualType == OP_BUYSTOP ||
             actualType == OP_BUYLIMIT);

   if(marketType == OP_SELL)
      return(actualType == OP_SELL ||
             actualType == OP_SELLSTOP ||
             actualType == OP_SELLLIMIT);

   return(false);
}

//+------------------------------------------------------------------+
int CountMyPendingOrdersByDirection(int marketType)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(!IsPendingOrderType(OrderType())) continue;
      if(!IsOrderTypeForMarketDirection(OrderType(), marketType)) continue;

      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
int CountMyOrderEntitiesByDirection(int marketType)
{
   return(CountMyOrdersByType(marketType) +
          CountMyPendingOrdersByDirection(marketType));
}

//+------------------------------------------------------------------+
bool HasMyPendingOrderComment(string orderComment)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(!IsPendingOrderType(OrderType())) continue;
      if(OrderComment() == orderComment) return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
double GetPendingStopEntryPrice(int marketType)
{
   RefreshRates();

   double requestedGap = MathMax(0.0, InpPendingStopGapRawPrice);
   double brokerMinimum = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double effectiveGap = MathMax(requestedGap,
                                 brokerMinimum + Point);

   if(marketType == OP_BUY)
      return(NormalizeDouble(Ask + effectiveGap, Digits));

   if(marketType == OP_SELL)
      return(NormalizeDouble(Bid - effectiveGap, Digits));

   return(0.0);
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

   if(type != OP_BUY && type != OP_SELL)
   {
      g_lastStatus = "Blocked: invalid market direction";
      return(false);
   }

   if(lots <= 0.0)
   {
      g_lastStatus = "Blocked: invalid lot size";
      return(false);
   }

   if(IsDailyNewOrderPaused())
   {
      g_lastStatus =
         "DAILY TARGET REACHED | ALL EA ORDERS CLOSED | NEW ORDERS PAUSED";
      return(false);
   }

   if(IsDubaiBlockedTime())
   {
      g_lastStatus = GetDubaiHoursPausedStatus();
      return(false);
   }

   // Central safety guard. Every regular, recovery, clean-pullback,
   // extra and retry path uses this one function.
   if(InpMarketMixedMode)
   {
      g_lastStatus = GetMixedModePausedStatus();
      Print(g_lastStatus, " | Blocked comment: ", orderComment);
      return(false);
   }

   if(HasMyPendingOrderComment(orderComment))
   {
      g_lastStatus = "Pending already exists | " + orderComment;
      return(false);
   }

   int sendType = type;
   double price = (type == OP_BUY) ? Ask : Bid;

   if(InpUsePendingStopOrders)
   {
      sendType = (type == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
      price = GetPendingStopEntryPrice(type);

      if(price <= 0.0)
      {
         g_lastStatus = "Pending price calculation failed";
         return(false);
      }
   }

   ResetLastError();

   int ticket = OrderSend(Symbol(),
                          sendType,
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
      Print(g_lastStatus,
            " | Type ", IntegerToString(sendType),
            " | Price ", DoubleToString(price, Digits),
            " | Comment ", orderComment);
      return(false);
   }

   DeleteProfitTrailState(ticket);
   SetTrailValue(ticket, "NEG", 0.0);

   string side = (type == OP_BUY) ? "BUY" : "SELL";

   if(InpUsePendingStopOrders)
   {
      g_lastStatus = side + " STOP pending #" +
                     IntegerToString(ticket) +
                     " placed at " +
                     DoubleToString(price, Digits) +
                     " | Gap raw " +
                     DoubleToString(InpPendingStopGapRawPrice, 1);
   }
   else
   {
      g_lastStatus = side + " market order opened #" +
                     IntegerToString(ticket);
   }

   Print(g_lastStatus, " | ", orderComment);
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
      if(!IsOrderTypeForMarketDirection(OrderType(), orderType)) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      // Count both a live recovery and its still-untriggered pending STOP.
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
bool DeleteAllMyPendingOrders(string reason)
{
   int deletedCount = 0;
   int failedCount  = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(!IsPendingOrderType(OrderType())) continue;

      int ticket = OrderTicket();
      string orderComment = OrderComment();
      int parentTicket = GetRecoveryParentTicket(orderComment);

      ResetLastError();
      if(OrderDelete(ticket, clrNONE))
      {
         deletedCount++;
         DeleteProfitTrailState(ticket);

         // A deleted recovery pending can be proposed again by a later
         // valid cycle because it never became a market recovery order.
         if(parentTicket > 0)
         {
            string key = RecoveryBOSKey(parentTicket);
            if(GlobalVariableCheck(key))
               GlobalVariableDel(key);
         }

         Print("PENDING DELETED | #", ticket,
               " | ", reason,
               " | ", orderComment);
      }
      else
      {
         failedCount++;
         Print("PENDING DELETE FAILED | #", ticket,
               " | Error ", GetLastError(),
               " | ", reason);
      }
   }

   if(deletedCount > 0 || failedCount > 0)
   {
      g_lastStatus = "Pending cleanup | Deleted " +
                     IntegerToString(deletedCount) +
                     " | Failed " +
                     IntegerToString(failedCount) +
                     " | " + reason;
   }

   return(failedCount == 0);
}

//+------------------------------------------------------------------+
void CleanupPendingOrdersEveryInterval()
{
   if(!InpUsePendingStopOrders)
      return;

   int cleanupMinutes = InpPendingCleanupMinutes;
   if(cleanupMinutes <= 0)
      cleanupMinutes = 30;

   long intervalSeconds = (long)cleanupMinutes * 60;
   long currentSlot = (long)TimeCurrent() / intervalSeconds;

   if(g_lastPendingCleanupSlot < 0)
   {
      g_lastPendingCleanupSlot = currentSlot;
      g_lastPendingCleanupTime = TimeCurrent();
      DeleteAllMyPendingOrders("EA startup pending cleanup");
      return;
   }

   if(currentSlot == g_lastPendingCleanupSlot)
      return;

   g_lastPendingCleanupSlot = currentSlot;
   g_lastPendingCleanupTime = TimeCurrent();

   DeleteAllMyPendingOrders(
      IntegerToString(cleanupMinutes) + "-minute cycle cleanup");
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
      RestoreDefaultTakeProfitAfterClose();

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

      int pairLossTier =
         (int)MathMax(GetStoredLossTier(parentTicket),
                      GetStoredLossTier(recoveryTicket));

      double basketTarget =
         GetAssignedTakeProfitForLossTier(pairLossTier);

      bool breakEvenMode =
         IsBreakEvenLossTier(pairLossTier);

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
         " | Pair loss tier " +
         IntegerToString(pairLossTier) +
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
bool IsRecoveryLossComebackReady(int orderType,
                                  double &basketCurrentProfit,
                                  double &basketMinimumProfit)
{
   basketCurrentProfit = 0.0;
   basketMinimumProfit = 0.0;

   if(!InpUseRecoveryLossComebackTrigger)
      return(false);

   if(InpRecoveryDeepLossUSD <= 0.0 ||
      InpRecoveryComebackImprovementUSD <= 0.0)
   {
      return(false);
   }

   if(CountMyOrdersByType(orderType) <= 0)
      return(false);

   // Refresh the independent BUY/SELL basket memory before reading it.
   UpdateSideProfitState(orderType);

   basketCurrentProfit = GetMyOpenProfitByType(orderType);
   basketMinimumProfit =
      GetSideProfitState(orderType,
                         "MINIMUM",
                         basketCurrentProfit);

   bool deepLossTouched =
      (basketMinimumProfit <= -MathAbs(InpRecoveryDeepLossUSD) +
                              0.0000001);

   bool improvedEnough =
      (basketCurrentProfit >=
       basketMinimumProfit +
       MathAbs(InpRecoveryComebackImprovementUSD) -
       0.0000001);

   // Recovery is only useful while the side basket is still losing.
   return(deepLossTouched &&
          improvedEnough &&
          basketCurrentProfit < -0.0000001);
}

//+------------------------------------------------------------------+
bool FindRecoveryParent(int requiredType,
                        bool lossComebackReady,
                        int &parentTicket,
                        double &parentProfit,
                        double &rawDifference,
                        bool &rawGapReached)
{
   parentTicket  = -1;
   parentProfit  = 0.0;
   rawDifference = 0.0;
   rawGapReached = false;

   double bestAdverseRaw = -1.0;
   bool selectedByRawGap = false;

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

      if(RecoveryAlreadyUsedForCurrentBOS(OrderTicket()))
         continue;

      double adverseRaw = 0.0;

      if(requiredType == OP_BUY)
         adverseRaw = OrderOpenPrice() - Bid;
      else
         adverseRaw = Ask - OrderOpenPrice();

      bool thisRawGapReached =
         (InpRecoveryRawDifference > 0.0 &&
          adverseRaw + 0.0000001 >= InpRecoveryRawDifference);

      // New rule: raw gap OR side basket loss-comeback trigger.
      if(!thisRawGapReached && !lossComebackReady)
         continue;

      // Prefer a parent that independently satisfies the raw gap. If all
      // candidates use the comeback trigger, choose the most adverse parent.
      bool betterCandidate = false;

      if(thisRawGapReached && !selectedByRawGap)
         betterCandidate = true;
      else if(thisRawGapReached == selectedByRawGap &&
              adverseRaw > bestAdverseRaw)
         betterCandidate = true;

      if(betterCandidate)
      {
         selectedByRawGap = thisRawGapReached;
         bestAdverseRaw   = adverseRaw;
         parentTicket     = OrderTicket();
         parentProfit     = profit;
         rawDifference    = adverseRaw;
         rawGapReached    = thisRawGapReached;
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
   if(InpRecoveryLotSize <= 0.0) return(false);
   if(InpMaxRecoveryOrdersPerDirection <= 0) return(false);

   bool rawTriggerEnabled =
      (InpRecoveryRawDifference > 0.0);

   bool comebackTriggerEnabled =
      (InpUseRecoveryLossComebackTrigger &&
       InpRecoveryDeepLossUSD > 0.0 &&
       InpRecoveryComebackImprovementUSD > 0.0);

   if(!rawTriggerEnabled && !comebackTriggerEnabled)
      return(false);

   if(IsDubaiBlockedTime())
   {
      g_lastStatus = GetDubaiHoursPausedStatus();
      return(false);
   }

   int requiredType =
      (g_bosDirection == 1) ? OP_BUY : OP_SELL;

   if(CountRecoveryOrders(requiredType) >=
      InpMaxRecoveryOrdersPerDirection)
   {
      return(false);
   }

   double basketCurrentProfit = 0.0;
   double basketMinimumProfit = 0.0;

   bool lossComebackReady =
      IsRecoveryLossComebackReady(requiredType,
                                  basketCurrentProfit,
                                  basketMinimumProfit);

   int parentTicket = -1;
   double parentProfit = 0.0;
   double rawDifference = 0.0;
   bool rawGapReached = false;

   if(!FindRecoveryParent(requiredType,
                          lossComebackReady,
                          parentTicket,
                          parentProfit,
                          rawDifference,
                          rawGapReached))
   {
      return(false);
   }

   string side =
      (requiredType == OP_BUY) ? "BUY" : "SELL";

   string triggerText = rawGapReached ?
      ("RAW GAP " + DoubleToString(rawDifference, 1)) :
      ("LOSS COMEBACK minimum $" +
       DoubleToString(basketMinimumProfit, 2) +
       " -> current $" +
       DoubleToString(basketCurrentProfit, 2));

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

   double entryPrice = InpUsePendingStopOrders ?
      GetPendingStopEntryPrice(requiredType) :
      ((requiredType == OP_BUY) ? Ask : Bid);

   DrawRecoveryArrow(g_bosDirection,
                     entryPrice,
                     TimeCurrent(),
                     parentTicket);

   g_lastStatus =
      "Recovery " + side +
      (InpUsePendingStopOrders ? " pending placed" : " opened") +
      " | Parent #" +
      IntegerToString(parentTicket) +
      " | Parent P/L $" +
      DoubleToString(parentProfit, 2) +
      " | Trigger " + triggerText;

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

   // if(CountMyOrders() >= InpMaxOpenOrders)
   // {
   //    g_lastStatus =
   //       "Clean pullback blocked: max open orders";

   //    return(false);
   // }
// Current BOS order direction.
int orderType = (g_bosDirection == 1) ? OP_BUY : OP_SELL;

// Profit of the side opposite to the current BOS.
double oppositeSideProfit = 0.0;
int oppositeSideOrders = 0;

if(orderType == OP_BUY)
{
   oppositeSideProfit = GetMyOpenProfitByType(OP_SELL);
   oppositeSideOrders = CountMyOrdersByType(OP_SELL);
}
else
{
   oppositeSideProfit = GetMyOpenProfitByType(OP_BUY);
   oppositeSideOrders = CountMyOrdersByType(OP_BUY);
}

// Opposite-BOS exception begins when the opposite-side basket reaches
// half of the current effective emergency stop-loss threshold.
double effectiveStopLossUSD = GetEffectiveFixedStopLossUSD();
double halfStopLossTrigger =
   -(effectiveStopLossUSD / 2.0);



// Allow one order in the BOS direction even when the normal total-order
// limit is reached, but only when the opposite side is already losing
// enough and MIXED-market mode is disabled.
/*
bool allowOppositeBOSOrder =
   (effectiveStopLossUSD > 0.0 &&
    oppositeSideOrders > 0 &&
    oppositeSideProfit <= halfStopLossTrigger);
if(allowOppositeBOSOrder &&
   !InpMarketMixedMode &&
   CountRecoveryOrders(orderType) == 0)
{
   // Apply the maximum separately to the new BOS direction.
   if(CountMyOrderEntitiesByDirection(orderType) >= InpMaxOpenOrders)
   {
      g_lastStatus =
         (orderType == OP_BUY)
         ? "Blocked: max BUY orders"
         : "Blocked: max SELL orders";

      return false;
   }
}
else
{
   // Under normal conditions, apply the maximum to all open orders.
   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus = InpMarketMixedMode
                     ? "Blocked: MIXED market + max total orders"
                     : "Blocked: max total open orders";
      return false;
   }
}*/
   
  // int orderType = (g_bosDirection > 0) ? OP_BUY : OP_SELL;

if(CountMyOrderEntitiesByDirection(orderType) >= InpMaxOpenOrders)
{
   g_lastStatus = (orderType == OP_BUY)
                  ? "Blocked: max BUY orders"
                  : "Blocked: max SELL orders";
   return(false);
}

   if(IsDubaiBlockedTime())
   {
      g_lastStatus = GetDubaiHoursPausedStatus();
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

   double entryPrice = InpUsePendingStopOrders ?
      GetPendingStopEntryPrice(type) :
      ((type == OP_BUY) ? Ask : Bid);

   DrawCleanPullbackArrow(direction,
                          entryPrice,
                          TimeCurrent(),
                          sourceTicket);

   ClearCleanProfitPullback("");
   ConsumeCurrentBOS(InpUsePendingStopOrders ?
                     "clean-profit continuation pending placed" :
                     "clean-profit continuation opened");

   g_lastStatus =
      "Clean BOS continuation " + side +
      (InpUsePendingStopOrders ? " pending placed" : " opened");

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
// Effective base TP used by every profit-management path.
// MIXED market uses half of the configured InpBasketProfitUSD, while
// NOT MIXED keeps the full configured value. The input itself is never
// overwritten, so returning to NOT MIXED automatically restores full TP.
// Example: InpBasketProfitUSD = $0.40
//   NOT MIXED = $0.40
//   MIXED     = $0.20
//+------------------------------------------------------------------+
double GetMarketModeTakeProfitUSD()
{
   double baseTakeProfit = g_originalTakeProfitUSD;

   if(baseTakeProfit <= 0.0)
      baseTakeProfit = InpBasketProfitUSD;

   if(baseTakeProfit <= 0.0)
      return(0.0);

   if(InpMarketMixedMode)
      baseTakeProfit = baseTakeProfit / 2.0;

   return(NormalizeDouble(baseTakeProfit, 4));
}

//+------------------------------------------------------------------+
// Dynamic-profit ladder increment after X1.
// InpDynamicBasketMultiplierStep=1.00 creates X1, X2, X3... levels.
// A value of 0.50 creates X1, X1.5, X2, X2.5... levels.
// The multiplier is applied to the active market-mode X1 value.
//+------------------------------------------------------------------+
double GetDynamicProfitLadderStepUSD()
{
   double activeTakeProfit = GetMarketModeTakeProfitUSD();

   if(activeTakeProfit <= 0.0)
      return(0.0);

   double multiplier = InpDynamicBasketMultiplierStep;

   // Invalid input falls back safely to whole-X steps.
   if(multiplier <= 0.0)
      multiplier = 1.00;

   return(NormalizeDouble(activeTakeProfit * multiplier, 4));
}

//+------------------------------------------------------------------+
double GetAssignedTakeProfitForLossTier(int lossTier)
{
   double marketModeTakeProfit = GetMarketModeTakeProfitUSD();

   if(marketModeTakeProfit <= 0.0)
      return(0.0);

   if(!InpUseAdaptiveLossTarget || lossTier <= 0)
      return(marketModeTakeProfit);

   if(IsBreakEvenLossTier(lossTier))
   {
      return(MathMax(0.0,
                     InpBreakEvenCloseProfitUSD));
   }

   return(NormalizeDouble(
             marketModeTakeProfit /
             (lossTier + 1.0),
             4));
}

//+------------------------------------------------------------------+
int GetDeepestLossTierByType(int orderType)
{
   int deepestTier = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      int tier = GetStoredLossTier(OrderTicket());

      if(tier > deepestTier)
         deepestTier = tier;
   }

   return(deepestTier);
}

//+------------------------------------------------------------------+
double GetLowestMinimumProfitByType(int orderType)
{
   bool found = false;
   double lowestProfit = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      double currentProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      double minimumProfit =
         GetStoredMinimumProfit(OrderTicket(), currentProfit);

      if(!found || minimumProfit < lowestProfit)
      {
         lowestProfit = minimumProfit;
         found = true;
      }
   }

   return(found ? lowestProfit : 0.0);
}

//+------------------------------------------------------------------+
void RefreshAssignedTargetsBySide(bool writeStatus)
{
   int oldBuyTier = g_assignedBuyLossTier;
   int oldSellTier = g_assignedSellLossTier;

   double oldBuyTP = g_assignedBuyTakeProfitUSD;
   double oldSellTP = g_assignedSellTakeProfitUSD;

   g_assignedBuyLossTier = GetDeepestLossTierByType(OP_BUY);
   g_assignedSellLossTier = GetDeepestLossTierByType(OP_SELL);

   g_assignedBuyTakeProfitUSD =
      GetAssignedTakeProfitForLossTier(g_assignedBuyLossTier);

   g_assignedSellTakeProfitUSD =
      GetAssignedTakeProfitForLossTier(g_assignedSellLossTier);

   bool buyChanged =
      (oldBuyTier != g_assignedBuyLossTier ||
       MathAbs(oldBuyTP - g_assignedBuyTakeProfitUSD) > 0.0000001);

   bool sellChanged =
      (oldSellTier != g_assignedSellLossTier ||
       MathAbs(oldSellTP - g_assignedSellTakeProfitUSD) > 0.0000001);

   if(writeStatus && (buyChanged || sellChanged))
   {
      g_lastStatus =
         "BUY TP $" + DoubleToString(g_assignedBuyTakeProfitUSD, 4) +
         " T" + IntegerToString(g_assignedBuyLossTier) +
         " | SELL TP $" + DoubleToString(g_assignedSellTakeProfitUSD, 4) +
         " T" + IntegerToString(g_assignedSellLossTier);

      Print("SIDE TARGETS | ", g_lastStatus,
            " | Default TP $",
            DoubleToString(g_originalTakeProfitUSD, 4));
   }
}

//+------------------------------------------------------------------+
void RestoreDefaultTakeProfitAfterClose()
{
   if(g_originalTakeProfitUSD <= 0.0)
      g_originalTakeProfitUSD = InpBasketProfitUSD;

   // The external/default input is never changed by BUY or SELL losses.
   InpBasketProfitUSD = g_originalTakeProfitUSD;

   // Recalculate remaining BUY and SELL targets separately.
   RefreshAssignedTargetsBySide(false);
   UpdateSideProfitStates();
}

//+------------------------------------------------------------------+
void AssignTakeProfitFromOpenOrderLosses()
{
   if(g_originalTakeProfitUSD <= 0.0)
      g_originalTakeProfitUSD = InpBasketProfitUSD;

   // Keep the configured input at its startup/default value.
   InpBasketProfitUSD = g_originalTakeProfitUSD;

   // No combined/global loss tier is used. Each direction has its own tier.
   RefreshAssignedTargetsBySide(true);
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
// Build a linear side-basket money model:
//   BUY  net P/L at price = (price - weighted open) * coefficient + costs
//   SELL net P/L at price = (weighted open - price) * coefficient + costs
// MODE_TICKVALUE is deposit-currency value for one tick at one lot.
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
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

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
   {
      return(0.0);
   }

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
// Convert a protected basket USD amount into one common broker SL price.
// If the exact buffered price is too close to market, use the nearest legal
// broker price only when that legal price still protects the requested lock.
// Otherwise wait and retry as profit moves farther beyond the lock.
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
      protectedProfitUSD +
      MathMax(0.0, InpServerProfitLockBufferUSD);

   // fixedCosts normally contains negative commission/swap. Therefore the
   // required gross price profit must replace those costs as well.
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

      // A lower BUY SL protects less money but is broker-valid.
      legalStopPrice =
         MathMin(desiredStopPrice,
                 highestLegalBuySL);

      legalStopPrice =
         NormalizeDouble(legalStopPrice, Digits);

      if(legalStopPrice <= 0.0 ||
         legalStopPrice >= Bid - Point * 0.5)
      {
         waitReason = "BUY SL inside broker stop/freeze level";
         return(false);
      }
   }
   else
   {
      double lowestLegalSellSL = Ask + minimumDistance;

      // A higher SELL SL protects less money but is broker-valid.
      legalStopPrice =
         MathMax(desiredStopPrice,
                 lowestLegalSellSL);

      legalStopPrice =
         NormalizeDouble(legalStopPrice, Digits);

      if(legalStopPrice <= Ask + Point * 0.5)
      {
         waitReason = "SELL SL inside broker stop/freeze level";
         return(false);
      }
   }

   estimatedNetProfit =
      EstimateSideNetProfitAtPrice(orderType,
                                   legalStopPrice);

   // Never install a broker stop that is estimated to protect less than the
   // ladder's requested minimum. Keep the older tighter SL and retry later.
   if(estimatedNetProfit + 0.0000001 <
      protectedProfitUSD)
   {
      waitReason =
         "market has not moved far enough beyond protected level";

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
// Apply the calculated common price to every market order in one side.
// Existing stops are never moved backwards. A new recovery/regular order
// joining an already-locked side receives the side's current broker lock on
// the next retry. The manual EA fallback close remains active as a backup.
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
      return(GetSideProfitState(orderType,
                                "SERVEROK",
                                0.0) >= 0.5 &&
             GetSideProfitState(orderType,
                                "SERVERLOCK",
                                0.0) +
             0.0000001 >= protectedProfitUSD);
   }

   if(orderType == OP_BUY)
      g_lastBuyServerLockAttemptTime = now;
   else
      g_lastSellServerLockAttemptTime = now;

   double stopPrice = 0.0;
   double estimatedNetProfit = 0.0;
   string waitReason = "";

   if(!CalculateSideServerLockPrice(orderType,
                                    protectedProfitUSD,
                                    stopPrice,
                                    estimatedNetProfit,
                                    waitReason))
   {
      SetSideProfitState(orderType,
                         "SERVEROK",
                         0.0);
      return(false);
   }

   int expectedOrders = 0;
   int modifyFailures = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      expectedOrders++;

      double existingStop = OrderStopLoss();

      if(IsOrderStopAtLeastAsProtective(orderType,
                                        existingStop,
                                        stopPrice))
      {
         continue;
      }

      // Never move a previously installed profitable stop backwards.
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

         // Error 1 means values were unchanged; the verification pass below
         // decides whether the existing stop is already sufficient.
         if(err != 1)
         {
            modifyFailures++;

            Print("SERVER PROFIT SL MODIFY FAILED | #",
                  ticket,
                  " | Side ",
                  (orderType == OP_BUY ? "BUY" : "SELL"),
                  " | Requested SL ",
                  DoubleToString(stopPrice, Digits),
                  " | Error ",
                  err);
         }
      }
   }

   // Verify every current side order. The side is considered server-protected
   // only after every order has an equal or tighter stop.
   int protectedOrders = 0;

   for(int v = OrdersTotal() - 1; v >= 0; v--)
   {
      if(!OrderSelect(v, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      if(IsOrderStopAtLeastAsProtective(orderType,
                                        OrderStopLoss(),
                                        stopPrice))
      {
         protectedOrders++;
      }
   }

   bool allProtected =
      (expectedOrders > 0 &&
       protectedOrders == expectedOrders);

   SetSideProfitState(orderType,
                      "SERVEROK",
                      allProtected ? 1.0 : 0.0);

   if(!allProtected)
      return(false);

   double previousServerLock =
      GetSideProfitState(orderType,
                         "SERVERLOCK",
                         0.0);

   SetSideProfitState(orderType,
                      "SERVERLOCK",
                      MathMax(previousServerLock,
                              protectedProfitUSD));
   SetSideProfitState(orderType,
                      "SERVERSL",
                      stopPrice);
   SetSideProfitState(orderType,
                      "SERVERNET",
                      estimatedNetProfit);

   if(protectedProfitUSD >
      previousServerLock + 0.0000001)
   {
      string side =
         (orderType == OP_BUY) ? "BUY" : "SELL";

      g_lastStatus =
         side +
         " broker SL protects $" +
         DoubleToString(protectedProfitUSD, 2) +
         " | SL " +
         DoubleToString(stopPrice, Digits) +
         " | Estimated net $" +
         DoubleToString(estimatedNetProfit, 2);

      Print(g_lastStatus,
            " | Orders ",
            IntegerToString(expectedOrders),
            " | Modify failures ",
            IntegerToString(modifyFailures));
   }

   return(true);
}

//+------------------------------------------------------------------+
bool CloseAllSideOrders(int orderType,
                        string reason,
                        double detectedBasketProfit,
                        double minimumBasketProfit,
                        int lossTier)
{
   int tickets[200];
   int ticketCount = 0;
   int regularSourceTicket = -1;
   bool hasRecoveryOrder = false;

   for(int i = OrdersTotal() - 1;
       i >= 0 && ticketCount < 200;
       i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      bool isRecovery = IsRecoveryOrderComment(OrderComment());

      tickets[ticketCount] = OrderTicket();
      ticketCount++;

      if(isRecovery)
         hasRecoveryOrder = true;
      else if(regularSourceTicket <= 0)
         regularSourceTicket = OrderTicket();
   }

   if(ticketCount <= 0)
   {
      ResetSideProfitState(orderType);
      return(false);
   }

   int closedCount = 0;
   int failedCount = 0;
   double lastClosePrice = 0.0;

   for(int t = 0; t < ticketCount; t++)
   {
      int ticket = tickets[t];

      if(!IsMyOpenMarketOrder(ticket))
         continue;

      int type = OrderType();
      double lots = OrderLots();
      string orderComment = OrderComment();
      double orderProfit =
         OrderProfit() + OrderSwap() + OrderCommission();

      int recoveryParentTicket =
         GetRecoveryParentTicket(orderComment);

      RefreshRates();

      double closePrice = (type == OP_BUY) ? Bid : Ask;
      color closeColor = (type == OP_BUY) ? clrLime : clrRed;

      ResetLastError();

      bool closed = OrderClose(ticket,
                               lots,
                               closePrice,
                               InpSlippage,
                               closeColor);

      if(closed)
      {
         closedCount++;
         lastClosePrice = closePrice;
         DeleteProfitTrailState(ticket);

         string ownRecoveryKey = RecoveryBOSKey(ticket);
         if(GlobalVariableCheck(ownRecoveryKey))
            GlobalVariableDel(ownRecoveryKey);

         if(recoveryParentTicket > 0)
         {
            string parentRecoveryKey =
               RecoveryBOSKey(recoveryParentTicket);

            if(GlobalVariableCheck(parentRecoveryKey))
               GlobalVariableDel(parentRecoveryKey);
         }

         Print(reason,
               " | Closed ticket #", ticket,
               " | Ticket P/L $", DoubleToString(orderProfit, 2));
      }
      else
      {
         failedCount++;
         int err = GetLastError();

         Print(reason,
               " | FAILED ticket #", ticket,
               " | Error ", err,
               " | Ticket P/L $", DoubleToString(orderProfit, 2));
      }
   }

   string side = (orderType == OP_BUY) ? "BUY" : "SELL";

   if(failedCount == 0 &&
      CountMyOrdersByType(orderType) == 0)
   {
      bool cleanBasket =
         (lossTier <= 0 &&
          minimumBasketProfit >= -0.0000001 &&
          detectedBasketProfit > 0.0 &&
          !hasRecoveryOrder &&
          regularSourceTicket > 0);

      ResetSideProfitState(orderType);

      if(cleanBasket)
      {
         int direction = (orderType == OP_BUY) ? 1 : -1;

         ArmCleanProfitPullback(regularSourceTicket,
                                direction,
                                TimeCurrent(),
                                lastClosePrice,
                                detectedBasketProfit);
      }

      RestoreDefaultTakeProfitAfterClose();

      g_lastStatus =
         reason + " | " + side +
         " basket closed " + IntegerToString(closedCount) +
         " order(s) | P/L $" +
         DoubleToString(detectedBasketProfit, 2);

      Print(g_lastStatus);
      return(true);
   }

   UpdateSideProfitState(orderType);
   RestoreDefaultTakeProfitAfterClose();

   g_lastStatus =
      reason + " | " + side +
      " partial close " + IntegerToString(closedCount) +
      " | Retry " + IntegerToString(failedCount);

   Print(g_lastStatus);
   return(closedCount > 0);
}

//+------------------------------------------------------------------+
bool CloseSideBasketByDynamicProfit(int orderType)
{
   int orderCount = CountMyOrdersByType(orderType);

   if(orderCount <= 0)
   {
      ResetSideProfitState(orderType);
      return(false);
   }

   double currentProfit = GetMyOpenProfitByType(orderType);
   int previousCount =
      (int)GetSideProfitState(orderType, "COUNT", 0.0);

   if(previousCount <= 0)
   {
      InitializeSideProfitState(orderType,
                                orderCount,
                                currentProfit);
      return(false);
   }

   double previousProfit =
      GetSideProfitState(orderType, "PREVIOUS", currentProfit);

   double peakProfit =
      GetSideProfitState(orderType, "PEAK", currentProfit);

   double minimumProfit =
      GetSideProfitState(orderType, "MINIMUM", currentProfit);

   double lockedProfit =
      GetSideProfitState(orderType, "LOCK", 0.0);

   int lossTier =
      (int)GetSideProfitState(orderType, "TIER", 0.0);

   if(currentProfit > peakProfit)
      peakProfit = currentProfit;

   if(currentProfit < minimumProfit)
      minimumProfit = currentProfit;

   int touchedTier = GetLossTierFromMinimumProfit(minimumProfit);

   if(touchedTier > lossTier)
   {
      lossTier = touchedTier;
      lockedProfit = 0.0;

      string tierSide = (orderType == OP_BUY) ? "BUY" : "SELL";

      g_lastStatus =
         tierSide + " basket touched loss tier " +
         IntegerToString(lossTier) +
         " | Minimum $" + DoubleToString(minimumProfit, 2);

      Print(g_lastStatus);
   }

   bool lockRaised = false;

   // Separate minimum activation and minimum protected close.
   // Example: arm=$0.25, close=$0.10, X1=$0.50, step X1:
   //   below $0.25 => no lock and no dynamic-profit close
   //   reach $0.25 => protect $0.10
   //   reach $0.50 => protect $0.50
   //   reach $1.00 => protect $1.00, then $1.50, $2.00...
   // InpDynamicBasketProfitMaxX=0.0 means the ladder has no maximum.
   double activeTakeProfit = GetMarketModeTakeProfitUSD();
   double ladderStep       = GetDynamicProfitLadderStepUSD();
   double minimumArm       =
      MathMax(0.0, InpDynamicBasketMinimumArmUSD);
   double minimumProtected =
      MathMax(0.0, InpDynamicBasketMinimumCloseUSD);

   // Never allow the protected close to exceed its activation threshold.
   if(minimumArm > 0.0 && minimumProtected > minimumArm)
      minimumProtected = minimumArm;

   if(lossTier <= 0)
   {
      double calculatedLock = lockedProfit;

      // The minimum close is armed only after a stronger profit move.
      if(minimumProtected > 0.0 &&
         minimumArm > 0.0 &&
         peakProfit + 0.0000001 >= minimumArm)
      {
         calculatedLock = MathMax(calculatedLock,
                                  minimumProtected);
      }

      if(activeTakeProfit > 0.0 &&
         ladderStep > 0.0 &&
         peakProfit + 0.0000001 >= activeTakeProfit)
      {
         double extraProfit = peakProfit - activeTakeProfit;
         if(extraProfit < 0.0)
            extraProfit = 0.0;

         double completedIncrements =
            MathFloor((extraProfit + 0.0000001) / ladderStep);

         double ladderLock =
            activeTakeProfit + completedIncrements * ladderStep;

         // Optional cap expressed as a multiplier of X1.
         // 0.0 means unlimited. Values below X1 are normalized to X1.
         if(InpDynamicBasketProfitMaxX > 0.0)
         {
            double maximumX = MathMax(1.0,
                                      InpDynamicBasketProfitMaxX);
            double maximumLock = activeTakeProfit * maximumX;
            ladderLock = MathMin(ladderLock, maximumLock);
         }

         calculatedLock =
            MathMax(calculatedLock,
                    NormalizeDouble(ladderLock, 4));
      }

      calculatedLock = NormalizeDouble(calculatedLock, 4);

      if(calculatedLock > lockedProfit + 0.0000001)
      {
         lockedProfit = calculatedLock;
         lockRaised = true;

         string lockSide =
            (orderType == OP_BUY) ? "BUY" : "SELL";

         if(activeTakeProfit > 0.0 &&
            lockedProfit + 0.0000001 >= activeTakeProfit)
         {
            double lockMultiplier =
               lockedProfit / activeTakeProfit;

            g_lastStatus =
               lockSide + " basket advanced lock X" +
               DoubleToString(lockMultiplier, 1) +
               " to $" + DoubleToString(lockedProfit, 2) +
               " | Peak $" + DoubleToString(peakProfit, 2);
         }
         else
         {
            g_lastStatus =
               lockSide + " basket minimum lock armed at $" +
               DoubleToString(lockedProfit, 2) +
               " after arm $" +
               DoubleToString(minimumArm, 2) +
               " | Peak $" + DoubleToString(peakProfit, 2);
         }

         Print(g_lastStatus);
      }
   }
   else
   {
      lockedProfit = 0.0;
   }

   double reducedTarget =
      GetAssignedTakeProfitForLossTier(lossTier);

   bool profitFalling =
      (currentProfit < previousProfit - 0.0000001);

   bool cleanTrailHit =
      (lossTier <= 0 &&
       lockedProfit > 0.0 &&
       !lockRaised &&
       profitFalling &&
       currentProfit <= lockedProfit + 0.0000001);

   // CHANGE 2: after a full negative tier was touched, close immediately
   // at TP/(tier+1). There is no pullback wait in comeback mode.
   bool reducedComebackHit =
      (lossTier > 0 &&
       currentProfit + 0.0000001 >= reducedTarget);

   SetSideProfitState(orderType, "COUNT", orderCount);
   SetSideProfitState(orderType, "CURRENT", currentProfit);
   SetSideProfitState(orderType, "PREVIOUS", currentProfit);
   SetSideProfitState(orderType, "PEAK", peakProfit);
   SetSideProfitState(orderType, "MINIMUM", minimumProfit);
   SetSideProfitState(orderType, "LOCK", lockedProfit);
   SetSideProfitState(orderType, "TIER", lossTier);

   // Install/retry the real broker-side SL after the minimum or X ladder
   // advances. It remains only a fallback: the EA dynamic fallback close
   // below still runs normally while the terminal is connected.
   if(lossTier <= 0 && lockedProfit > 0.0)
   {
      ApplyServerSideProfitLock(orderType,
                                lockedProfit,
                                lockRaised);
   }

   string side = (orderType == OP_BUY) ? "BUY" : "SELL";

   if(reducedComebackHit)
   {
      string targetText =
         IsBreakEvenLossTier(lossTier) ?
         "BREAK-EVEN" :
         ("$" + DoubleToString(reducedTarget, 4));

      return(CloseAllSideOrders(
         orderType,
         side + " reduced comeback target " + targetText +
         " | Tier " + IntegerToString(lossTier) +
         " | Minimum $" + DoubleToString(minimumProfit, 2),
         currentProfit,
         minimumProfit,
         lossTier));
   }

   if(cleanTrailHit)
   {
      return(CloseAllSideOrders(
         orderType,
         side + " advanced profit fallback | Lock $" +
         DoubleToString(lockedProfit, 2) +
         " | Peak $" + DoubleToString(peakProfit, 2),
         currentProfit,
         minimumProfit,
         lossTier));
   }

   return(false);
}

//+------------------------------------------------------------------+
void CloseByProfitOrLoss()
{
   // BUY and SELL basket profit engines are completely independent.
   CloseSideBasketByDynamicProfit(OP_BUY);
   CloseSideBasketByDynamicProfit(OP_SELL);

   // Preserve the existing emergency stop as a per-order protection.
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double profit =
         OrderProfit() + OrderSwap() + OrderCommission();

      double effectiveStopLossUSD =
         GetEffectiveFixedStopLossUSD();

      bool fixedStopHit =
         (effectiveStopLossUSD > 0.0 &&
          profit <= -effectiveStopLossUSD);

      if(fixedStopHit)
      {
         CloseSelectedOrder(
            "Effective emergency SL -$" +
            DoubleToString(effectiveStopLossUSD, 2),
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
      RestoreDefaultTakeProfitAfterClose();

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
   adaptiveTarget = g_originalTakeProfitUSD;

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
         GetAssignedTakeProfitForLossTier(lossTier);

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
//| Professional right-side dashboard helpers                       |
//+------------------------------------------------------------------+
string DashboardTimeframeText()
{
   int tf = Period();

   if(tf == PERIOD_M1)   return("M1");
   if(tf == PERIOD_M5)   return("M5");
   if(tf == PERIOD_M15)  return("M15");
   if(tf == PERIOD_M30)  return("M30");
   if(tf == PERIOD_H1)   return("H1");
   if(tf == PERIOD_H4)   return("H4");
   if(tf == PERIOD_D1)   return("D1");
   if(tf == PERIOD_W1)   return("W1");
   if(tf == PERIOD_MN1)  return("MN1");

   return(IntegerToString(tf));
}

//+------------------------------------------------------------------+
double GetMyOpenProfitByType(int orderType)
{
   double total = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(total);
}

//+------------------------------------------------------------------+
double GetMyLockedProfitByType(int orderType)
{
   return(GetSideProfitState(orderType,
                             "LOCK",
                             0.0));
}

//+------------------------------------------------------------------+
string SideProfitStateKey(int orderType, string field)
{
   string side = (orderType == OP_BUY) ? "BUY" : "SELL";

   return("EBP_SIDE_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          Symbol() + "_" + side + "_" + field);
}

//+------------------------------------------------------------------+
double GetSideProfitState(int orderType,
                          string field,
                          double defaultValue)
{
   string key = SideProfitStateKey(orderType, field);

   if(!GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, defaultValue);
      return(defaultValue);
   }

   return(GlobalVariableGet(key));
}

//+------------------------------------------------------------------+
void SetSideProfitState(int orderType,
                        string field,
                        double value)
{
   GlobalVariableSet(SideProfitStateKey(orderType, field), value);
}

//+------------------------------------------------------------------+
void ResetSideProfitState(int orderType)
{
   SetSideProfitState(orderType, "COUNT", 0.0);
   SetSideProfitState(orderType, "CURRENT", 0.0);
   SetSideProfitState(orderType, "PREVIOUS", 0.0);
   SetSideProfitState(orderType, "PEAK", 0.0);
   SetSideProfitState(orderType, "MINIMUM", 0.0);
   SetSideProfitState(orderType, "LOCK", 0.0);
   SetSideProfitState(orderType, "TIER", 0.0);
   SetSideProfitState(orderType, "SERVERLOCK", 0.0);
   SetSideProfitState(orderType, "SERVERSL", 0.0);
   SetSideProfitState(orderType, "SERVERNET", 0.0);
   SetSideProfitState(orderType, "SERVEROK", 0.0);
}

//+------------------------------------------------------------------+
void InitializeSideProfitState(int orderType,
                               int orderCount,
                               double currentProfit)
{
   int lossTier = GetLossTierFromMinimumProfit(currentProfit);

   SetSideProfitState(orderType, "COUNT", orderCount);
   SetSideProfitState(orderType, "CURRENT", currentProfit);
   SetSideProfitState(orderType, "PREVIOUS", currentProfit);
   SetSideProfitState(orderType, "PEAK", currentProfit);
   SetSideProfitState(orderType, "MINIMUM", currentProfit);
   SetSideProfitState(orderType, "LOCK", 0.0);
   SetSideProfitState(orderType, "TIER", lossTier);
   SetSideProfitState(orderType, "SERVERLOCK", 0.0);
   SetSideProfitState(orderType, "SERVERSL", 0.0);
   SetSideProfitState(orderType, "SERVERNET", 0.0);
   SetSideProfitState(orderType, "SERVEROK", 0.0);
}

//+------------------------------------------------------------------+
void UpdateSideProfitState(int orderType)
{
   int orderCount = CountMyOrdersByType(orderType);

   if(orderCount <= 0)
   {
      ResetSideProfitState(orderType);
      return;
   }

   double currentProfit = GetMyOpenProfitByType(orderType);
   int previousCount =
      (int)GetSideProfitState(orderType, "COUNT", 0.0);

   // A side becomes a new basket only after it was completely empty.
   // Adding a regular/recovery order to an active side must not erase the
   // already-touched worst drawdown tier or its highest profit memory.
   if(previousCount <= 0)
   {
      InitializeSideProfitState(orderType,
                                orderCount,
                                currentProfit);
      return;
   }

   double peakProfit =
      GetSideProfitState(orderType, "PEAK", currentProfit);

   double minimumProfit =
      GetSideProfitState(orderType, "MINIMUM", currentProfit);

   double lockedProfit =
      GetSideProfitState(orderType, "LOCK", 0.0);

   int storedTier =
      (int)GetSideProfitState(orderType, "TIER", 0.0);

   if(currentProfit > peakProfit)
      peakProfit = currentProfit;

   if(currentProfit < minimumProfit)
      minimumProfit = currentProfit;

   int currentTier = GetLossTierFromMinimumProfit(minimumProfit);
   if(currentTier < storedTier)
      currentTier = storedTier;

   // Once a negative tier is armed, the immediate reduced comeback target
   // replaces the clean-basket trailing lock.
   if(currentTier > 0)
      lockedProfit = 0.0;

   SetSideProfitState(orderType, "COUNT", orderCount);
   SetSideProfitState(orderType, "CURRENT", currentProfit);
   SetSideProfitState(orderType, "PREVIOUS", currentProfit);
   SetSideProfitState(orderType, "PEAK", peakProfit);
   SetSideProfitState(orderType, "MINIMUM", minimumProfit);
   SetSideProfitState(orderType, "LOCK", lockedProfit);
   SetSideProfitState(orderType, "TIER", currentTier);
}

//+------------------------------------------------------------------+
void UpdateSideProfitStates()
{
   UpdateSideProfitState(OP_BUY);
   UpdateSideProfitState(OP_SELL);
}

//+------------------------------------------------------------------+
void GetSideProfitSummary(int orderType,
                          double &currentProfit,
                          double &peakProfit,
                          double &lockedProfit,
                          double &minimumProfit,
                          int &lossTier,
                          double &adaptiveTarget)
{
   UpdateSideProfitState(orderType);

   currentProfit = GetMyOpenProfitByType(orderType);
   peakProfit = GetSideProfitState(orderType, "PEAK", currentProfit);
   lockedProfit = GetSideProfitState(orderType, "LOCK", 0.0);
   minimumProfit = GetSideProfitState(orderType, "MINIMUM", currentProfit);
   lossTier = (int)GetSideProfitState(orderType, "TIER", 0.0);
   adaptiveTarget = GetAssignedTakeProfitForLossTier(lossTier);
}

//+------------------------------------------------------------------+
color DashboardDirectionColor(int direction)
{
   if(direction > 0) return(C'65,220,125');
   if(direction < 0) return(C'255,95,95');

   return(C'255,195,65');
}

//+------------------------------------------------------------------+
color DashboardProfitColor(double profit)
{
   if(profit > 0.0000001)  return(C'65,220,125');
   if(profit < -0.0000001) return(C'255,95,95');

   return(C'205,210,220');
}

//+------------------------------------------------------------------+
color DashboardBoolColor(bool state)
{
   return(state ? C'65,220,125' : C'150,158,175');
}

//+------------------------------------------------------------------+
void DashboardBox(string id,
                  int x,
                  int y,
                  int width,
                  int height,
                  color background,
                  color border)
{
   string name = PFX + "DASH_BOX_" + id;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DashboardLabel(string id,
                    string text,
                    int x,
                    int y,
                    int fontSize,
                    color textColor,
                    int anchor,
                    string fontName)
{
   string name = PFX + "DASH_LBL_" + id;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anchor);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DashboardSection(string id,
                      string title,
                      int y,
                      color accent)
{
   int x = InpDashboardRightMargin + 8;
   int width = InpDashboardWidth - 16;

   DashboardBox("SEC_" + id,
                x,
                y,
                width,
                20,
                C'31,36,49',
                accent);

   DashboardLabel("SEC_" + id,
                  title,
                  InpDashboardRightMargin + InpDashboardWidth - 18,
                  y + 4,
                  8,
                  accent,
                  ANCHOR_LEFT_UPPER,
                  "Arial Bold");
}

//+------------------------------------------------------------------+
void DashboardRow(string id,
                  string caption,
                  string value,
                  int y,
                  color valueColor)
{
   DashboardLabel(id + "_K",
                  caption,
                  InpDashboardRightMargin + InpDashboardWidth - 18,
                  y,
                  InpDashboardFontSize,
                  C'172,180,196',
                  ANCHOR_LEFT_UPPER,
                  "Arial");

   DashboardLabel(id + "_V",
                  value,
                  InpDashboardRightMargin + 18,
                  y,
                  InpDashboardFontSize,
                  valueColor,
                  ANCHOR_RIGHT_UPPER,
                  "Arial Bold");
}

//+------------------------------------------------------------------+
string DashboardStatusPart(string text,
                           int start,
                           int length)
{
   if(start >= StringLen(text))
      return("");

   return(StringSubstr(text, start, length));
}

//+------------------------------------------------------------------+
void DrawDashboard(string status)
{
   Comment("");

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

   double pullbackRaw = GetCurrentPullbackRaw();
   double continuationRaw = GetCurrentContinuationRaw();

   double buyCurrentProfit = 0.0;
   double buyPeakProfit = 0.0;
   double buyLockedProfit = 0.0;
   double buyMinimumProfit = 0.0;
   int buyLossTier = 0;
   double buyAdaptiveTarget = GetMarketModeTakeProfitUSD();

   double sellCurrentProfit = 0.0;
   double sellPeakProfit = 0.0;
   double sellLockedProfit = 0.0;
   double sellMinimumProfit = 0.0;
   int sellLossTier = 0;
   double sellAdaptiveTarget = GetMarketModeTakeProfitUSD();

   GetSideProfitSummary(OP_BUY,
                        buyCurrentProfit,
                        buyPeakProfit,
                        buyLockedProfit,
                        buyMinimumProfit,
                        buyLossTier,
                        buyAdaptiveTarget);

   GetSideProfitSummary(OP_SELL,
                        sellCurrentProfit,
                        sellPeakProfit,
                        sellLockedProfit,
                        sellMinimumProfit,
                        sellLossTier,
                        sellAdaptiveTarget);

   double recoveryBasketProfit = 0.0;
   int recoveryParentTicket = -1;
   int recoveryTicket = -1;

   bool hasRecoveryBasket =
      GetRecoveryBasketInfo(recoveryBasketProfit,
                            recoveryParentTicket,
                            recoveryTicket);

   double buyProfit = buyCurrentProfit;
   double sellProfit = sellCurrentProfit;

   int buyOrders = CountMyOrdersByType(OP_BUY);
   int sellOrders = CountMyOrdersByType(OP_SELL);

   string cleanPBText = "IDLE";

   if(g_cleanPullbackPending)
   {
      cleanPBText =
         (g_cleanPullbackDirection == 1 ? "WAIT BUY" : "WAIT SELL") +
         " #" + IntegerToString(g_cleanPullbackSourceTicket);
   }

   bool emaMatch =
      (emaTrend == g_bosDirection && emaTrend != 0);

   EA_PAUSE_REASON pauseReason = GetCurrentPauseReason();

   string tradingState = "ACTIVE";
   string newOrdersText = "ACTIVE";
   color tradingColor = C'65,220,125';

   if(pauseReason == PAUSE_REASON_DAILY_TARGET)
   {
      tradingState = "DAILY PAUSED";
      newOrdersText = "PAUSED - DAILY TARGET";
      tradingColor = C'255,95,95';
   }
   else if(pauseReason == PAUSE_REASON_DUBAI_HOURS)
   {
      tradingState = "TIME PAUSED";
      newOrdersText = "PAUSED - DUBAI HOURS";
      tradingColor = C'255,180,55';
   }
   else if(pauseReason == PAUSE_REASON_MIXED_MODE)
   {
      tradingState = "MIXED PAUSED";
      newOrdersText = "PAUSED - MIXED MODE";
      tradingColor = C'255,180,55';
   }

   string displayStatus = GetEffectiveStatusText(status);
   color panelBorder = tradingColor;

   int panelHeight = 270 + 29 * InpDashboardRowHeight;
   int top = InpDashboardTopMargin;
   int right = InpDashboardRightMargin;
   int width = InpDashboardWidth;

   DashboardBox("MAIN",
                right,
                top,
                width,
                panelHeight,
                C'14,17,24',
                panelBorder);

   DashboardBox("HEADER",
                right + 1,
                top + 1,
                width - 2,
                54,
                C'20,30,48',
                C'38,98,170');

   DashboardLabel("TITLE",
                  "DXB EMA + BOS TRADING EA",
                  right + width - 16,
                  top + 9,
                  11,
                  C'235,242,255',
                  ANCHOR_LEFT_UPPER,
                  "Arial Bold");

   DashboardLabel("SUBTITLE",
                  Symbol() + "  |  " + DashboardTimeframeText() +
                  "  |  Dubai " + TimeToString(GetDubaiTime(), TIME_MINUTES),
                  right + width - 16,
                  top + 31,
                  8,
                  C'145,180,225',
                  ANCHOR_LEFT_UPPER,
                  "Arial");

   DashboardBox("STATE_BADGE",
                right + 12,
                top + 12,
                94,
                27,
                C'25,29,38',
                tradingColor);

   DashboardLabel("STATE",
                  tradingState,
                  right + 59,
                  top + 25,
                  8,
                  tradingColor,
                  ANCHOR_CENTER,
                  "Arial Bold");

   int y = top + 63;

   DashboardSection("ACCOUNT", "ACCOUNT & DAILY PROTECTION", y,
                    C'65,170,255');
   y += 26;

   DashboardRow("BALANCE", "Account Balance",
                "$" + DoubleToString(AccountBalance(), 2),
                y, C'225,232,245');
   y += InpDashboardRowHeight;

   DashboardRow("EQUITY", "Account Equity",
                "$" + DoubleToString(AccountEquity(), 2),
                y, DashboardProfitColor(AccountEquity() - AccountBalance()));
   y += InpDashboardRowHeight;

   DashboardRow("DAY_BASE", "Dubai Day Base",
                "$" + DoubleToString(g_dailyStartBalance, 2),
                y, C'145,205,255');
   y += InpDashboardRowHeight;

   DashboardRow("DAY_TARGET", "Daily Target",
                DoubleToString(InpProfitTargetPercent, 1) + "%  |  $" +
                DoubleToString(g_dailyTargetEquity, 2),
                y, C'80,220,205');
   y += InpDashboardRowHeight;

   DashboardRow("ORDER_STATE", "New Orders",
                newOrdersText,
                y, tradingColor);
   y += InpDashboardRowHeight + 4;

   DashboardSection("SIGNAL", "MARKET SIGNAL", y,
                    C'185,110,255');
   y += 26;

   DashboardRow("EMA_TREND", "EMA Trend",
                emaTxt,
                y, DashboardDirectionColor(emaTrend));
   y += InpDashboardRowHeight;

   DashboardRow("EMA_VALUE", "EMA" + IntegerToString(InpEMAPeriod),
                DoubleToString(ema, Digits),
                y, C'255,190,75');
   y += InpDashboardRowHeight;

   DashboardRow("MARKET_MODE", "Auto Market Mode",
                InpMarketMixedMode ? "MIXED | ORDERS PAUSED | TP / 2" : "NOT MIXED | FULL TP",
                y, InpMarketMixedMode ?
                C'255,180,55' : C'65,220,125');
   y += InpDashboardRowHeight;

   DashboardRow("MIX_METRICS", "Range / Efficiency / Cross",
                DoubleToString(g_mixedRangeRaw, 1) + " / " +
                DoubleToString(g_mixedEfficiency, 2) + " / " +
                IntegerToString(g_mixedEMACrossings),
                y, C'165,190,230');
   y += InpDashboardRowHeight;

   DashboardRow("BOS_DIR", "BOS Direction",
                dir,
                y, DashboardDirectionColor(g_bosDirection));
   y += InpDashboardRowHeight;

   DashboardRow("BOS_STATE", "BOS State / EMA Match",
                (g_bosActive ? "ACTIVE" : "IDLE") +
                " / " + (emaMatch ? "YES" : "NO"),
                y, (g_bosActive && emaMatch) ?
                C'65,220,125' : C'255,180,55');
   y += InpDashboardRowHeight;

   DashboardRow("PULLBACK", "Pullback Raw / Memory",
                DoubleToString(pullbackRaw, 1) + " / " +
                (g_pullbackTouchLatched ? "YES" : "NO"),
                y, g_pullbackTouchLatched ?
                C'80,225,210' : C'170,178,192');
   y += InpDashboardRowHeight;

   DashboardRow("MOMENTUM", "Momentum Raw / Memory",
                DoubleToString(continuationRaw, 1) + " / " +
                (g_momentumTouchLatched ? "YES" : "NO"),
                y, g_momentumTouchLatched ?
                C'255,205,70' : C'170,178,192');
   y += InpDashboardRowHeight;

   DashboardRow("CLEAN_PB", "Clean Re-entry",
                cleanPBText,
                y, g_cleanPullbackPending ?
                C'70,220,235' : C'150,158,175');
   y += InpDashboardRowHeight + 4;

   DashboardSection("ORDERS", "ORDERS & LIVE PROFIT", y,
                    C'65,220,125');
   y += 26;

   DashboardRow("ORDER_COUNT", "BUY / SELL Orders",
                IntegerToString(buyOrders) + " / " +
                IntegerToString(sellOrders) +
                "   Max " + IntegerToString(InpMaxOpenOrders) + "/side",
                y, C'225,232,245');
   y += InpDashboardRowHeight;

   DashboardRow("PENDING_COUNT", "BUY / SELL Pending",
                IntegerToString(CountMyPendingOrdersByDirection(OP_BUY)) +
                " / " +
                IntegerToString(CountMyPendingOrdersByDirection(OP_SELL)) +
                "   Gap " +
                DoubleToString(InpPendingStopGapRawPrice, 1),
                y, C'70,220,235');
   y += InpDashboardRowHeight;

   DashboardRow("BUY_LIVE_PEAK", "BUY Current / Peak",
                "$" + DoubleToString(buyCurrentProfit, 2) + " / $" +
                DoubleToString(buyPeakProfit, 2),
                y, DashboardProfitColor(buyCurrentProfit));
   y += InpDashboardRowHeight;

   DashboardRow("SELL_LIVE_PEAK", "SELL Current / Peak",
                "$" + DoubleToString(sellCurrentProfit, 2) + " / $" +
                DoubleToString(sellPeakProfit, 2),
                y, DashboardProfitColor(sellCurrentProfit));
   y += InpDashboardRowHeight;

   DashboardRow("SIDE_LOCKED", "BUY / SELL Ladder Lock",
                "$" + DoubleToString(buyLockedProfit, 2) + " / $" +
                DoubleToString(sellLockedProfit, 2),
                y, C'210,218,235');
   y += InpDashboardRowHeight;

   double buyServerLock =
      GetSideProfitState(OP_BUY, "SERVERLOCK", 0.0);
   double sellServerLock =
      GetSideProfitState(OP_SELL, "SERVERLOCK", 0.0);
   double buyServerSL =
      GetSideProfitState(OP_BUY, "SERVERSL", 0.0);
   double sellServerSL =
      GetSideProfitState(OP_SELL, "SERVERSL", 0.0);
   bool buyServerOK =
      (GetSideProfitState(OP_BUY, "SERVEROK", 0.0) >= 0.5);
   bool sellServerOK =
      (GetSideProfitState(OP_SELL, "SERVEROK", 0.0) >= 0.5);

   DashboardRow("SERVER_LOCK", "Broker Lock BUY / SELL",
                "$" + DoubleToString(buyServerLock, 2) + " / $" +
                DoubleToString(sellServerLock, 2) +
                "  " +
                (buyServerOK ? "B:OK" : "B:WAIT") + " " +
                (sellServerOK ? "S:OK" : "S:WAIT"),
                y, (buyServerOK || sellServerOK) ?
                C'80,225,210' : C'255,180,55');
   y += InpDashboardRowHeight;

   DashboardRow("SERVER_SL", "Broker SL BUY / SELL",
                (buyServerSL > 0.0 ?
                 DoubleToString(buyServerSL, Digits) : "--") +
                " / " +
                (sellServerSL > 0.0 ?
                 DoubleToString(sellServerSL, Digits) : "--"),
                y, C'145,205,255');
   y += InpDashboardRowHeight;

   DashboardRow("REC_COUNT", "Recovery BUY / SELL",
                IntegerToString(CountRecoveryOrders(OP_BUY)) + " / " +
                IntegerToString(CountRecoveryOrders(OP_SELL)),
                y, C'255,205,70');
   y += InpDashboardRowHeight;

   DashboardRow("PAIR", "Recovery Pair Basket",
                hasRecoveryBasket ?
                ("$" + DoubleToString(recoveryBasketProfit, 2) +
                 "  P#" + IntegerToString(recoveryParentTicket) +
                 " R#" + IntegerToString(recoveryTicket)) :
                "NONE",
                y, hasRecoveryBasket ?
                DashboardProfitColor(recoveryBasketProfit) :
                C'150,158,175');
   y += InpDashboardRowHeight;

   y += 4;

   DashboardSection("RISK", "ADAPTIVE TARGET & RISK", y,
                    C'255,145,65');
   y += 26;

   DashboardRow("DEFAULT_TP", "Arm / Min / X1 / X Step",
                "$" + DoubleToString(InpDynamicBasketMinimumArmUSD, 4) +
                " / $" + DoubleToString(InpDynamicBasketMinimumCloseUSD, 4) +
                " / $" + DoubleToString(GetMarketModeTakeProfitUSD(), 4) +
                " / $" + DoubleToString(GetDynamicProfitLadderStepUSD(), 4),
                y, InpMarketMixedMode ? C'255,180,55' : C'255,205,70');
   y += InpDashboardRowHeight;

   DashboardRow("BUY_TARGET", "BUY Target / Loss Tier",
                (IsBreakEvenLossTier(buyLossTier) ?
                 "BREAK-EVEN" :
                 ("$" + DoubleToString(buyAdaptiveTarget, 4))) +
                " / " + IntegerToString(buyLossTier),
                y, buyLossTier > 0 ?
                C'255,145,65' : C'65,220,125');
   y += InpDashboardRowHeight;

   DashboardRow("SELL_TARGET", "SELL Target / Loss Tier",
                (IsBreakEvenLossTier(sellLossTier) ?
                 "BREAK-EVEN" :
                 ("$" + DoubleToString(sellAdaptiveTarget, 4))) +
                " / " + IntegerToString(sellLossTier),
                y, sellLossTier > 0 ?
                C'255,145,65' : C'65,220,125');
   y += InpDashboardRowHeight;

   DashboardRow("BUY_MIN", "BUY Minimum Basket P/L",
                "$" + DoubleToString(buyMinimumProfit, 2),
                y, DashboardProfitColor(buyMinimumProfit));
   y += InpDashboardRowHeight;

   DashboardRow("SELL_MIN", "SELL Minimum Basket P/L",
                "$" + DoubleToString(sellMinimumProfit, 2),
                y, DashboardProfitColor(sellMinimumProfit));
   y += InpDashboardRowHeight;

   double effectiveStopLossUSD =
      GetEffectiveFixedStopLossUSD();

   DashboardRow("SL", "Effective / Configured SL",
                "-$" + DoubleToString(effectiveStopLossUSD, 2) +
                " / -$" + DoubleToString(InpFixedStopLossUSD, 2),
                y, C'255,95,95');
   y += InpDashboardRowHeight + 4;

   DashboardSection("STATUS", "EA STATUS", y,
                    tradingColor);
   y += 26;

   DashboardLabel("STATUS_1",
                  DashboardStatusPart(displayStatus, 0, 47),
                  right + width - 18,
                  y,
                  8,
                  C'235,242,255',
                  ANCHOR_LEFT_UPPER,
                  "Arial Bold");

   DashboardLabel("STATUS_2",
                  DashboardStatusPart(displayStatus, 47, 47),
                  right + width - 18,
                  y + 17,
                  8,
                  C'190,200,218',
                  ANCHOR_LEFT_UPPER,
                  "Arial");
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
