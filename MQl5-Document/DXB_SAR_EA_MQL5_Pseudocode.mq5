//+------------------------------------------------------------------+
//| DXB SAR EA - MQL5 Pseudocode Design                              |
//| Scope: order placement, profit booking, stop-loss management      |
//| Note: Pseudocode only. Use as a blueprint for MQL5 implementation.|
//+------------------------------------------------------------------+

//================ ENUMS =================
enum ENUM_ENTRY_TYPE
{
   ENTRY_NORMAL_SAR,
   ENTRY_RECOVERY,
   ENTRY_RECOVERY_GAP,
   ENTRY_OPPOSITE_IMPULSE,
   ENTRY_GOOD_MARKET_CONTINUATION,
   ENTRY_PYRAMID,
   ENTRY_PULLBACK,
   ENTRY_BREAKOUT
};

enum ENUM_ENTRY_RESULT
{
   ENTRY_PASS,
   ENTRY_FAIL_DAILY_LOCK,
   ENTRY_FAIL_RESET,
   ENTRY_FAIL_BLOCKED_HOUR,
   ENTRY_FAIL_HALF_LOSS_PAUSE,
   ENTRY_FAIL_SIDE_PAUSE,
   ENTRY_FAIL_CAPACITY,
   ENTRY_FAIL_SAR_DIRECTION,
   ENTRY_FAIL_SAR_CONFIRM,
   ENTRY_FAIL_SIGNAL_QUALITY,
   ENTRY_FAIL_MARKET_SAFETY,
   ENTRY_FAIL_TYPE_NOT_ALLOWED,
   ENTRY_FAIL_ORDER_SEND
};

enum ENUM_SIDE { SIDE_BUY = 1, SIDE_SELL = -1 };

//================ DAILY PROFIT SHARE LOCK SETTINGS =================
input bool   InpUseHighestProfitShareLock = true;
input double InpHighestProfitLockActivationPercent = 10.0;
input double InpHighestProfitLockSharePercent = 50.0;
input double InpProfitLadderFloorCloseBufferPercent = 0.50;

//================ STATE =================
double   g_openingBase = 0.0;
double   g_highestEquityToday = 0.0;
double   g_lockedEquity = 0.0;
bool     g_firstProfitActivationReached = false;
bool     g_waitingForPostActivationOrder = false;
bool     g_profitShareLockActive = false;
bool     g_dayTradingPaused = false;
datetime g_profitShareActivationTime = 0;
ulong    g_firstPostActivationOrderTicket = 0;

//================ FRESH DAY RESET =================
void ResetDailyState()
{
   g_openingBase = AccountInfoDouble(ACCOUNT_BALANCE);
   g_highestEquityToday = AccountInfoDouble(ACCOUNT_EQUITY);
   g_lockedEquity = 0.0;
   g_firstProfitActivationReached = false;
   g_waitingForPostActivationOrder = false;
   g_profitShareLockActive = false;
   g_dayTradingPaused = false;
   g_profitShareActivationTime = 0;
   g_firstPostActivationOrderTicket = 0;
}

//================ NEW ORDER PLACEMENT =================
ENUM_ENTRY_RESULT CanPlaceNewOrder(ENUM_SIDE side, ENUM_ENTRY_TYPE type)
{
   if(g_dayTradingPaused || IsDailyEquityLockActive()) return ENTRY_FAIL_DAILY_LOCK;
   if(IsFreshDayResetInProgress()) return ENTRY_FAIL_RESET;
   if(IsBlockedHour()) return ENTRY_FAIL_BLOCKED_HOUR;
   if(IsHalfLossCoolingActive()) return ENTRY_FAIL_HALF_LOSS_PAUSE;
   if(IsSideLossPaused(side)) return ENTRY_FAIL_SIDE_PAUSE;
   if(IsCapacityExceeded(side, type)) return ENTRY_FAIL_CAPACITY;
   if(!IsSARDirectionValid(side)) return ENTRY_FAIL_SAR_DIRECTION;
   if(!PassesSARConfirmation(side)) return ENTRY_FAIL_SAR_CONFIRM;
   if(!PassesSignalQualityFilters(side)) return ENTRY_FAIL_SIGNAL_QUALITY;
   if(!PassesMarketSafetyFilters(side)) return ENTRY_FAIL_MARKET_SAFETY;
   if(!IsEntryTypeAllowed(side, type)) return ENTRY_FAIL_TYPE_NOT_ALLOWED;
   return ENTRY_PASS;
}

bool TryPlaceOrder(ENUM_SIDE side, ENUM_ENTRY_TYPE type)
{
   ENUM_ENTRY_RESULT result = CanPlaceNewOrder(side, type);
   if(result != ENTRY_PASS)
   {
      LogEntryReject(side, type, result);
      return false;
   }

   ulong ticket = SendOrder(side, type);
   if(ticket == 0) return false;

   AttachInitialSL(ticket);
   RegisterOrderState(ticket, side, type);

   if(g_waitingForPostActivationOrder && IsMarketPosition(ticket))
   {
      g_waitingForPostActivationOrder = false;
      g_profitShareLockActive = true;
      g_firstPostActivationOrderTicket = ticket;
      g_highestEquityToday = MathMax(g_highestEquityToday, AccountInfoDouble(ACCOUNT_EQUITY));
   }
   return true;
}

//================ PROFIT BOOKING / SHARE LOCK =================
void UpdateDailyProfitShareLock()
{
   if(!InpUseHighestProfitShareLock || g_dayTradingPaused || g_openingBase <= 0.0)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentProfit = equity - g_openingBase;
   double currentProfitPct = 100.0 * currentProfit / g_openingBase;

   // Phase 1: activate only at first 10% threshold.
   if(!g_firstProfitActivationReached)
   {
      if(currentProfitPct >= InpHighestProfitLockActivationPercent)
      {
         CloseAllEAPositions("FIRST_10_PERCENT_ACTIVATION_BOOK");
         DeleteAllEAPendingOrders("FIRST_10_PERCENT_ACTIVATION_BOOK");
         g_firstProfitActivationReached = true;
         g_waitingForPostActivationOrder = true;
         g_profitShareActivationTime = TimeCurrent();
         g_highestEquityToday = equity;
      }
      return;
   }

   // Phase 2: wait until the strategy opens a fresh valid market order.
   if(g_waitingForPostActivationOrder)
      return;

   if(!g_profitShareLockActive)
      return;

   // Phase 3: highest equity tracking.
   if(equity > g_highestEquityToday)
      g_highestEquityToday = equity;

   double highestProfit = MathMax(0.0, g_highestEquityToday - g_openingBase);
   double lockedProfit = highestProfit * InpHighestProfitLockSharePercent / 100.0;
   double candidateLockedEquity = g_openingBase + lockedProfit;

   if(candidateLockedEquity > g_lockedEquity)
      g_lockedEquity = candidateLockedEquity;

   double closeBuffer = g_openingBase * InpProfitLadderFloorCloseBufferPercent / 100.0;
   double closeTrigger = g_lockedEquity + closeBuffer;

   if(equity <= closeTrigger)
   {
      CloseAllEAPositions("HIGHEST_PROFIT_SHARE_LOCK");
      DeleteAllEAPendingOrders("HIGHEST_PROFIT_SHARE_LOCK");
      g_dayTradingPaused = true;
   }
}

//================ STOP LOSS MANAGEMENT =================
bool AttachInitialSL(ulong ticket)
{
   if(!SelectEAPosition(ticket)) return false;
   ENUM_SIDE side = GetPositionSide(ticket);
   int sarDirection = GetCurrentSARDirection();
   double slUSD = SelectInitialSLUSD(side, sarDirection);
   double slPrice = ConvertUSDToSLPrice(ticket, slUSD);
   return ModifySLForwardOnly(ticket, slPrice);
}

void ManageOpenPositionStops()
{
   for(each EA market position)
   {
      if(NeedsInitialSL(position)) AttachInitialSL(position.ticket);
      if(ShouldAdvanceServerProfitLock(position))
         ModifySLForwardOnly(position.ticket, CalculateProtectedSL(position));
   }

   if(HalfLossWarningReached()) StartHalfLossCoolingPause();
   if(FullDailyLossReached())
   {
      CloseAllEAPositions("FULL_DAILY_LOSS_STOP");
      DeleteAllEAPendingOrders("FULL_DAILY_LOSS_STOP");
      g_dayTradingPaused = true;
   }
}

//================ ONTICK STRUCTURE =================
void OnTick()
{
   if(IsNewFreshDay()) ResetDailyState();
   ManageOpenPositionStops();
   UpdateDailyProfitShareLock();
   if(g_dayTradingPaused) return;

   // Normal strategy engine remains unchanged.
   EvaluateSARSignalsAndPlaceOrders();
}
