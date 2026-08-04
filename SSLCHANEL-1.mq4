//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - ULTRA COMPACT             |
//|                  TWO-STAGE PROFIT LADDER | OPTIMIZED VERSION      |
//+------------------------------------------------------------------+
#property strict

// ===== SETTINGS =====
int SSLPeriod = 10;
bool EnableTrading = true;
double Lots = 0.01;
int MaxOpenOrders = 20;
bool CloseOppositeOrdersOnSignal = false;
bool DeleteOppositePendingOnSignal = true;
bool EnableProfitReEntryStop = true;
double MinimumClosedProfitUSD = -9;
double ProfitReEntryGapRaw = 20;
double MinimumSameOrderGapRaw = 50;
bool EnableProfitLadder1 = true;
double Ladder1ProfitUSD = 0.05;
bool EnableProfitLadder2 = true;
double Ladder1StopMaxPriceUSD = 0.20;
double Ladder2ProfitUSD = 0.20;
double StopLossUSD = 50;
bool EnableRecoveryOrders = true;
double RecoveryTriggerLossUSD = -2.0;
double RecoveryLotMultiplier = 1;
int MaxRecoveryOrders = 1;
double RecoveryBasketProfitUSD = 0.50;
bool EnableDailyLossProtection = true;
bool ResetDailyProtectionEveryDay = true;
bool CloseOpenOrdersOnDailyLoss = true;
int MinimumClosedOrdersForDailyProtection = 10;
bool EnableDailyEquityTarget = true;
bool CloseOrdersOnDailyEquityTarget = true;
bool EnableDynamicEquityLadder = true;
//--------------
double DailyEquityTargetPercent = 3;
double DailyLossProtectionPercent = 50;
bool EnableEquityLadder = true;
double EquityLadderLossPercentAfterStep1 = 10;
//-------------------
double EquityLockPercent = 80;
bool ContinueTradingAfterTarget = true;
bool ResetLadderEveryDay = true;
int Slippage = 30;
int MagicNumber = 6600123;
bool ShowHistoricalSignals = true;
bool ShowSSLLines = true;
int HistoryBarsToDraw = 500;
bool ShowSignalText = true;
bool ShowSignalArrows = true;
int SignalDistancePoints = 100;
int SignalArrowWidth = 2;
int SignalFontSize = 9;
color BuyColor = clrBlue;
color SellColor = clrRed;
color SSLUpColor = clrLime;
color SSLDownColor = clrRed;
int SSLLineWidth = 2;
bool ShowDashboard = true;
int DashboardRightGap = 300;
int DashboardTopGap = 20;
int DashboardWidth = 285;
int DashboardHeight = 480;
int DashboardFontSize = 9;

// ===== STATE STRUCTURE =====
struct DailyProtectionState {
   datetime DayDate;
   double DayStartBalance, DayHighestBalance, DayProtectedBalance, DayPeakProfit, DailyClosedProfit;
   int DailyClosedOrders, ClosedOrdersToday;
   bool TradingStopped, LossTriggered, Initialized;
};

// ===== RUNTIME VARIABLES =====
string PREFIX = "SSL_CROSS_", DASH_PREFIX = "SSL_DASHBOARD_";
datetime LastProcessedBar = 0, LastProcessedClosedOrderTime = 0, DailyProtectionStartTime = 0, LastProfitTargetTime = 0;
int LastProcessedClosedTicket = -1;
bool StartupSignalProcessed = false, RecoveryMode = false, BasketTrailingArmed = false;
bool ProfitLadder1Triggered = false, ProfitLadder2Triggered = false;

double GlbFinalPL = 0;

// Original values (cannot be modified)
double OriginalLots = 0.01, OriginalLadder1ProfitUSD = 0.05, OriginalLadder2ProfitUSD = 0.20;
double OriginalDailyLossProtectionPercent = 50;

// Runtime variables (can be modified)
double RuntimeLots = 0.01;
double RuntimeLadder1ProfitUSD = 0.05;
double RuntimeLadder2ProfitUSD = 0.20;
double RuntimeDailyLossProtectionPercent = 50;

double CurrentMultiplier = 1.0, BasketHighestProfit = 0.0, BasketTrailingStop = 0.0, DynamicBasketHighestProfit = 0.0;
double LockedEquity = 0, NextEquityTarget = 0;
int EquityLadderLevel = 1;

//+------------------------------------------------------------------+
void InitializeEquityLadder(DailyProtectionState &state)
{
   LockedEquity = state.DayStartBalance;
   NextEquityTarget = state.DayStartBalance * (1.0 + DailyEquityTargetPercent / 100.0);
}

void ProcessStartupSignal(DailyProtectionState &dailyState)
{
   if(StartupSignalProcessed || Bars < SSLPeriod + 20) return;
   StartupSignalProcessed = true;
   
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(1, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(2, upPrevious, downPrevious, hlvPrevious);
   
   bool buySignal = (upCurrent > downCurrent);
   bool sellSignal = (upCurrent < downCurrent);

   Print("==================================================");
   Print("EA RESTART SIGNAL RECOVERY - Direction: ", buySignal ? "BUY" : (sellSignal ? "SELL" : "NONE"));
   Print("==================================================");
   
   if(buySignal) {
      DrawLiveSignal(1, true);
      if(DeleteOppositePendingOnSignal) DeleteOppositePendingOrders(OP_BUY);
      if(CloseOppositeOrdersOnSignal) CloseOppositeOrders(OP_BUY);
      if(EnableTrading && !IsDailyTradingStopped(dailyState) && GetTotalEAOrders() < MaxOpenOrders) {
         OpenBuy();
         Print("EA RESTART -> BUY OPENED");
      } else Print("EA RESTART BUY BLOCKED");
   }
   
   if(sellSignal) {
      DrawLiveSignal(1, false);
      if(DeleteOppositePendingOnSignal) DeleteOppositePendingOrders(OP_SELL);
      if(CloseOppositeOrdersOnSignal) CloseOppositeOrders(OP_SELL);
      if(EnableTrading && !IsDailyTradingStopped(dailyState) && GetTotalEAOrders() < MaxOpenOrders) {
         OpenSell();
         Print("EA RESTART -> SELL OPENED");
      } else Print("EA RESTART SELL BLOCKED");
   }
}

int OnInit()
{
   // Store original values
   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;
   OriginalDailyLossProtectionPercent = DailyLossProtectionPercent;
   
   // Initialize runtime variables with values
   RuntimeLots = Lots;
   RuntimeLadder1ProfitUSD = Ladder1ProfitUSD;
   RuntimeLadder2ProfitUSD = Ladder2ProfitUSD;
   RuntimeDailyLossProtectionPercent = DailyLossProtectionPercent;
   
   Print("========== SSL CHANNEL CROSS EA - OPTIMIZED VERSION ==========");
   Print("Symbol: ", Symbol(), " | Timeframe: ", TimeframeToString(Period()), " | SSL Period: ", SSLPeriod);
   Print("Lots: ", DoubleToString(Lots, 2), " | Max Orders: ", MaxOpenOrders);
   Print("Daily Protection: ", EnableDailyLossProtection ? "ON" : "OFF", " | Ladder 1: ", EnableProfitLadder1 ? "ON" : "OFF");
   Print("Ladder 1 Step: $", DoubleToString(Ladder1ProfitUSD, 2), " | Ladder 2 Step: $", DoubleToString(Ladder2ProfitUSD, 2));
   Print("=========================================================");
   
   DeleteOurObjects();
   DeleteDashboardObjects();
   if(ShowHistoricalSignals || ShowSSLLines) DrawHistoricalSignals();
   
   DailyProtectionStartTime = TimeCurrent();
   InitializeLastProcessedClosedOrder();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DeleteOurObjects();
   DeleteDashboardObjects();
}

void OnTick()
{
   static DailyProtectionState dailyState;
   
   if(!dailyState.Initialized) InitializeDailyProtectionState(dailyState);
   
   CheckRecoveryOrders();
   ManageRecoveryBasket();
   ProcessStartupSignal(dailyState);
   UpdateDailyLossProtection(dailyState);
   CheckDynamicEquityLadder(dailyState);
   
   if(ShowSSLLines) UpdateSSLChannelOnTick();
   if(Bars >= SSLPeriod + 20 && GetTotalEAOrders() > 0) CheckForProfitableClosedOrder(dailyState);
   if(EnableProfitLadder1 || EnableProfitLadder2) ManageProfitLadder();
   if(ShowDashboard) UpdateDashboard(dailyState);
   
   if(Bars < SSLPeriod + 20 || Time[0] == LastProcessedBar) return;
   LastProcessedBar = Time[0];
   
   bool buySignal = IsBuySignal(1);
   bool sellSignal = IsSellSignal(1);
   
   if(buySignal) {
      DrawLiveSignal(1, true);
      Print("SSL CROSS SIGNAL -> BUY");
      if(DeleteOppositePendingOnSignal) DeleteOppositePendingOrders(OP_BUY);
      if(CloseOppositeOrdersOnSignal) CloseOppositeOrders(OP_BUY);
      if(EnableTrading && !IsDailyTradingStopped(dailyState)) {
         if(GetTotalEAOrders() < MaxOpenOrders) OpenBuy();
         else Print("BUY BLOCKED | MAX ORDERS");
      } else Print("BUY BLOCKED | DAILY PROTECTION");
   }
   
   if(sellSignal) {
      DrawLiveSignal(1, false);
      Print("SSL CROSS SIGNAL -> SELL");
      if(DeleteOppositePendingOnSignal) DeleteOppositePendingOrders(OP_SELL);
      if(CloseOppositeOrdersOnSignal) CloseOppositeOrders(OP_SELL);
      if(EnableTrading && !IsDailyTradingStopped(dailyState)) {
         if(GetTotalEAOrders() < MaxOpenOrders) OpenSell();
         else Print("SELL BLOCKED | MAX ORDERS");
      } else Print("SELL BLOCKED | DAILY PROTECTION");
   }
}

//+------------------------------------------------------------------+
//| ORDER MANAGEMENT FUNCTIONS
//+------------------------------------------------------------------+

bool HasMinimumSameOrderGap(int orderType)
{
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType) continue;
      if(MathAbs(currentPrice - OrderOpenPrice()) < MinimumSameOrderGapRaw) {
         Print("NEW ", orderType == OP_BUY ? "BUY" : "SELL", " BLOCKED | Order within ", DoubleToString(MathAbs(currentPrice - OrderOpenPrice()), Digits), " raw");
         return false;
      }
   }
   return true;
}

double GetOpenPL(int OrderTypeFilter)
{
   double OpenPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() == OrderTypeFilter) OpenPL += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return OpenPL;
}

void ChangeLots(double OpenPL)
{
   int Multiplier = (OpenPL < -10) ? 3 : (OpenPL < -5) ? 2 : 1;
   CurrentMultiplier = Multiplier;
   RuntimeLots = OriginalLots * Multiplier;
   RuntimeLadder1ProfitUSD = OriginalLadder1ProfitUSD * Multiplier;
   RuntimeLadder2ProfitUSD = OriginalLadder2ProfitUSD * Multiplier;
}

void CheckRecoveryOrders()
{
   if(!EnableRecoveryOrders || GetTotalEAOrders() >= MaxOpenOrders) return;
   
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0 || (OrderType() != OP_BUY && OrderType() != OP_SELL)) continue;
      
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > RecoveryTriggerLossUSD || HasRecoveryOrder(OrderTicket())) continue;
      if((OrderType() == OP_BUY && !IsBuySignal(1)) || (OrderType() == OP_SELL && !IsSellSignal(1))) continue;
      
      double lots = NormalizeDouble(OrderLots() * RecoveryLotMultiplier, 2);
      ResetLastError();
      int ticket = -1;
      if(OrderType() == OP_BUY) {
         ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrAqua);
      } else {
         ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrOrange);
      }
      if(ticket <= 0) Print("Recovery order failed | Error: ", GetLastError());
   }
}

bool HasRecoveryOrder(int ParentTicket)
{
   string txt = "RECOVERY_" + IntegerToString(ParentTicket);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() == MagicNumber && OrderComment() == txt) return true;
   }
   return false;
}

void ManageRecoveryBasket()
{
   double buyProfit = 0, sellProfit = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      double p = OrderProfit() + OrderSwap() + OrderCommission();
      if(OrderType() == OP_BUY) buyProfit += p;
      else if(OrderType() == OP_SELL) sellProfit += p;
   }
   
   if(buyProfit >= RecoveryBasketProfitUSD) {
      CloseBasket(OP_BUY); 
      if(GetTotalBuyOrders() == 0 && IsBuySignal(1) && EnableTrading && HasMinimumSameOrderGap(OP_BUY)) {
         OpenBuy();
         Print("Recovery basket closed -> New BUY opened");
      }
   }
   
   if(sellProfit >= RecoveryBasketProfitUSD) {
      CloseBasket(OP_SELL);
      if(GetTotalSellOrders() == 0 && IsSellSignal(1) && EnableTrading && HasMinimumSameOrderGap(OP_SELL)) {
         OpenSell();
         Print("Recovery basket closed -> New SELL opened");
      }
   }
}

void CloseBasket(int type)
{
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type) continue;
      ResetLastError();
      bool result = false;
      if(type == OP_BUY) result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
      else result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
      if(!result) Print("CloseBasket failed for ticket ", OrderTicket(), " | Error: ", GetLastError());
   }
}

void OpenBuy()
{
   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_BUY)) return;
   ChangeLots(GetOpenPL(OP_SELL));
   RefreshRates();
   
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, RuntimeLots);
   if(slDistance <= 0) return;
   
   double stopLoss = NormalizeDouble(Ask - slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_BUY, RuntimeLots, Ask, Slippage, stopLoss, 0, "SSL Long", MagicNumber, 0, BuyColor);
   
   if(ticket > 0) Print("BUY OPENED | Ticket: ", ticket);
   else { int err = GetLastError(); Print("BUY FAILED | ERROR: ", err); }
}

void OpenSell()
{
   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_SELL)) return;
   ChangeLots(GetOpenPL(OP_BUY));
   RefreshRates();
   
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, RuntimeLots);
   if(slDistance <= 0) return;
   
   double stopLoss = NormalizeDouble(Bid + slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_SELL, RuntimeLots, Bid, Slippage, stopLoss, 0, "SSL Short", MagicNumber, 0, SellColor);
   
   if(ticket > 0) Print("SELL OPENED | Ticket: ", ticket);
   else { int err = GetLastError(); Print("SELL FAILED | ERROR: ", err); }
}

double CalculatePriceDistanceUSD(double usdAmount, double orderLots)
{
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || orderLots <= 0) return 0;
   return (usdAmount / (tickValue * orderLots)) * tickSize;
}

//+------------------------------------------------------------------+
//| DAILY PROTECTION & EQUITY LADDER FUNCTIONS
//+------------------------------------------------------------------+

void InitializeDailyProtectionState(DailyProtectionState &state)
{
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   state.DayDate = StrToTime(today);
   state.DayStartBalance = AccountBalance();
   state.DayHighestBalance = state.DayStartBalance;
   state.DayProtectedBalance = state.DayStartBalance * (1.0 - DailyLossProtectionPercent / 100.0);
   state.DayPeakProfit = 0.0;
   state.DailyClosedProfit = 0.0;
   state.DailyClosedOrders = 0;
   state.ClosedOrdersToday = 0;
   state.TradingStopped = false;
   state.LossTriggered = false;
   state.Initialized = true;
   
   Print("==================================================");
   Print("NEW DAILY PROTECTION INITIALIZED");
   Print("Day Start Balance: $", DoubleToString(state.DayStartBalance, 2));
   Print("Min Required Closed Orders: ", MinimumClosedOrdersForDailyProtection);
   Print("Daily Protection: ", DoubleToString(DailyLossProtectionPercent, 2), "%");
   Print("==================================================");
}

void UpdateDailyLossProtection(DailyProtectionState &state)
{
   if(!EnableDailyLossProtection) return;
   
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   datetime todayDate = StrToTime(today);
   
   if(ResetDailyProtectionEveryDay && state.DayDate != todayDate) {
      state.DayDate = todayDate;
      state.DayStartBalance = AccountBalance();
      state.DayHighestBalance = state.DayStartBalance;
      state.DayProtectedBalance = state.DayStartBalance * (1.0 - OriginalDailyLossProtectionPercent / 100.0);
      state.ClosedOrdersToday = 0;
      state.TradingStopped = false;
      RuntimeDailyLossProtectionPercent = OriginalDailyLossProtectionPercent;
      
      DailyProtectionStartTime = TimeCurrent();
      RuntimeLots = OriginalLots;
      RuntimeLadder1ProfitUSD = OriginalLadder1ProfitUSD;
      RuntimeLadder2ProfitUSD = OriginalLadder2ProfitUSD;
      
      InitializeEquityLadder(state);
      EquityLadderLevel = 1;
      LockedEquity = state.DayStartBalance;
      
      Print("==== NEW DAY - DAILY PROFIT PROTECTION RESET ====");
      Print("Day Start: $", DoubleToString(state.DayStartBalance, 2), " | Protected: $", DoubleToString(state.DayProtectedBalance, 2));
      Print("==================================================");
   }
   
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   double currentEquity = AccountEquity();
   double minEquity = state.DayStartBalance - (state.DayStartBalance * RuntimeDailyLossProtectionPercent / 100.0);

   if(currentEquity <= minEquity) {
      if(!state.TradingStopped) {
         state.TradingStopped = true;
         Print("PROTECTED EQUITY STOP");
         Print("Start Balance : $", DoubleToString(state.DayStartBalance, 2));
         Print("Protection %  : ", DoubleToString(RuntimeDailyLossProtectionPercent, 2));
         Print("Stop Equity   : $", DoubleToString(minEquity, 2));
         Print("Current Equity: $", DoubleToString(currentEquity, 2));
         
         if(CloseOpenOrdersOnDailyLoss)
            CloseAllEAOrders();
      }
      return;
   }
   
   if(state.ClosedOrdersToday >= MinimumClosedOrdersForDailyProtection) {
      if(currentEquity <= state.DayProtectedBalance) {
         if(!state.TradingStopped) {
            state.TradingStopped = true;
            state.LossTriggered = true;
            Print("===============================");
            Print("PROTECTED EQUITY STOP TRIGGERED");
            Print("Protected Equity : $", DoubleToString(state.DayProtectedBalance, 2));
            Print("Current Equity   : $", DoubleToString(currentEquity, 2));
            Print("===============================");
            
            if(CloseOpenOrdersOnDailyLoss)
               CloseAllEAOrders();
         }
      }
   }
}

void CheckDynamicEquityLadder(DailyProtectionState &state)
{
   if(!EnableDynamicEquityLadder || GetTotalEAOrders() > 0)
      return;

   double equity = AccountEquity();

   if(equity < NextEquityTarget)
      return;

   Print("==============================");
   Print("EQUITY TARGET REACHED");
   Print("Current Equity : ", DoubleToString(equity, 2));
   Print("==============================");

   int retry = 0;
   while(GetTotalEAOrders() > 0 && retry < 5) {
      Sleep(500);
      RefreshRates();
      CloseAllEAOrders();
      retry++;
   }

   if(GetTotalEAOrders() > 0) {
      Print("Unable to close all orders.");
      return;
   }

   // -------- COMPLETE RESET --------
   RuntimeLots = OriginalLots;
   RuntimeLadder1ProfitUSD = OriginalLadder1ProfitUSD;
   RuntimeLadder2ProfitUSD = OriginalLadder2ProfitUSD;
   ProfitLadder1Triggered = false;
   ProfitLadder2Triggered = false;
   RecoveryMode = false;
   CurrentMultiplier = 1.0;
   BasketHighestProfit = 0;
   BasketTrailingStop = 0;
   BasketTrailingArmed = false;
   DynamicBasketHighestProfit = 0;

   state.DayStartBalance = AccountBalance();
   state.DayHighestBalance = state.DayStartBalance;
   state.DayProtectedBalance = state.DayStartBalance * (1.0 - RuntimeDailyLossProtectionPercent / 100.0);
   state.DayPeakProfit = 0;
   state.DailyClosedProfit = 0;
   state.DailyClosedOrders = 0;
   state.ClosedOrdersToday = 0;
   state.TradingStopped = false;
   state.LossTriggered = false;

   DailyProtectionStartTime = TimeCurrent();
   InitializeEquityLadder(state);
   EquityLadderLevel++;

   double newBalance = AccountBalance();
   double earnedProfit = newBalance - state.DayHighestBalance;
   state.DayStartBalance = newBalance;

   if(EquityLadderLevel <= 2) {
      state.DayProtectedBalance = state.DayStartBalance * (1.0 - RuntimeDailyLossProtectionPercent / 100.0);
   } else {
      state.DayProtectedBalance = state.DayStartBalance - (earnedProfit * EquityLadderLossPercentAfterStep1 / 100.0);
   }

   NextEquityTarget = state.DayStartBalance * (1.0 + DailyEquityTargetPercent / 100.0);

   Print("Fresh Trading Started");
   Print("New Start Balance : ", DoubleToString(state.DayStartBalance, 2));
   Print("Next Target : ", DoubleToString(NextEquityTarget, 2));
}

int CountClosedOrdersSinceInitialization()
{
   int count = 0;
   if(DailyProtectionStartTime <= 0) return 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if((OrderType() != OP_BUY && OrderType() != OP_SELL) || OrderCloseTime() <= DailyProtectionStartTime) continue;
      count++;
   }
   return count;
}

bool IsDailyTradingStopped(DailyProtectionState &state)
{
   return EnableDailyLossProtection && state.TradingStopped;
}

//+------------------------------------------------------------------+
//| PROFIT LADDER MANAGEMENT
//+------------------------------------------------------------------+

void ManageProfitLadder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL) continue;
      
      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(currentProfit <= 0) continue;
      
      double lockedProfit = 0;
      
      if(EnableProfitLadder1 && RuntimeLadder1ProfitUSD > 0 && currentProfit < Ladder1StopMaxPriceUSD) {
         int ladder1Level = (int)MathFloor(currentProfit / RuntimeLadder1ProfitUSD);
         if(ladder1Level >= 2) lockedProfit = (ladder1Level - 1) * RuntimeLadder1ProfitUSD;
      }
      
      if(EnableProfitLadder2 && RuntimeLadder2ProfitUSD > 0 && currentProfit >= Ladder1StopMaxPriceUSD) {
         int ladder2Level = (int)MathFloor(currentProfit / RuntimeLadder2ProfitUSD);
         if(ladder2Level >= 2) lockedProfit = (ladder2Level - 1) * RuntimeLadder2ProfitUSD;
      }
      
      if(lockedProfit <= 0) continue;
      
      lockedProfit = NormalizeDouble(lockedProfit, 2);
      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      if(tickValue <= 0 || tickSize <= 0) continue;
      
      double priceDistance = (lockedProfit / (tickValue * OrderLots())) * tickSize;
      double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      double newStopLoss;
      
      if(orderType == OP_BUY) {
         newStopLoss = NormalizeDouble(OrderOpenPrice() + priceDistance, Digits);
         if(OrderStopLoss() > 0 && newStopLoss <= OrderStopLoss()) continue;
         if(Bid - newStopLoss < stopLevel) newStopLoss = NormalizeDouble(Bid - stopLevel, Digits);
         
         if(newStopLoss > 0 && newStopLoss < Bid) {
            ResetLastError();
            if(OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrLimeGreen)) {
               Print("BUY LADDER | Profit: $", DoubleToString(currentProfit, 2), " | Locked: $", DoubleToString(lockedProfit, 2));
            }
         }
      } else if(orderType == OP_SELL) {
         newStopLoss = NormalizeDouble(OrderOpenPrice() - priceDistance, Digits);
         if(OrderStopLoss() > 0 && newStopLoss >= OrderStopLoss()) continue;
         if(newStopLoss - Ask < stopLevel) newStopLoss = NormalizeDouble(Ask + stopLevel, Digits);
         
         if(newStopLoss > Ask) {
            ResetLastError();
            if(OrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, OrderTakeProfit(), 0, clrTomato)) {
               Print("SELL LADDER | Profit: $", DoubleToString(currentProfit, 2), " | Locked: $", DoubleToString(lockedProfit, 2));
            }
         }
      }
   }
}

void CheckForProfitableClosedOrder(DailyProtectionState &state)
{
   datetime latestCloseTime = 0;
   double latestProfit = 0;
   int latestTicket = -1, latestType = -1;
   double latestClosePrice = 0;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() <= latestCloseTime) continue;
      
      latestCloseTime = OrderCloseTime();
      latestTicket = OrderTicket();
      latestType = OrderType();
      latestProfit = OrderProfit() + OrderSwap() + OrderCommission();
      latestClosePrice = OrderClosePrice();
   }
   
   if(latestTicket < 0) return;
   if(latestTicket == LastProcessedClosedTicket && latestCloseTime == LastProcessedClosedOrderTime) return;
   
   LastProcessedClosedTicket = latestTicket;
   LastProcessedClosedOrderTime = latestCloseTime;
   
   if(latestProfit >= MinimumClosedProfitUSD) {
      Print("PROFITABLE ORDER CLOSED | Ticket: ", latestTicket, " | Direction: ", (latestType == OP_BUY ? "BUY" : "SELL"));
      Print("Close: ", DoubleToString(latestClosePrice, Digits), " | Profit: $", DoubleToString(latestProfit, 2));
      if(EnableProfitReEntryStop && !IsDailyTradingStopped(state)) CreateProfitReEntryStop(latestType, latestClosePrice);
      return;
   }
   
   Print("ORDER CLOSED WITHOUT PROFIT | P/L: $", DoubleToString(latestProfit, 2));
   if(EnableTrading && !IsDailyTradingStopped(state)) {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(1)) { OpenBuy(); Print("BUY opened after closed order"); }
      if(GetTotalSellOrders() == 0 && IsSellSignal(1)) { OpenSell(); Print("SELL opened after closed order"); }
   }
}

void CreateProfitReEntryStop(int closedOrderType, double closedPrice)
{
   if(!EnableTrading || !EnableProfitReEntryStop) return;
   if(GetTotalEAOrders() >= MaxOpenOrders) { Print("PROFIT RE-ENTRY BLOCKED | MAX ORDERS"); return; }
   
   RefreshRates();
   
   double entryPrice = (closedOrderType == OP_BUY) ? (closedPrice + ProfitReEntryGapRaw) : (closedPrice - ProfitReEntryGapRaw);
   int pendingType = (closedOrderType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   color orderColor = (closedOrderType == OP_BUY) ? BuyColor : SellColor;
   string orderComment = (closedOrderType == OP_BUY) ? "SSL Profit ReEntry Buy Stop" : "SSL Profit ReEntry Sell Stop";
   
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double minimumGap = stopLevel + Point;
   
   if(pendingType == OP_BUYSTOP && entryPrice < Ask + minimumGap) entryPrice = Ask + minimumGap;
   if(pendingType == OP_SELLSTOP && entryPrice > Bid - minimumGap) entryPrice = Bid - minimumGap;
   
   entryPrice = NormalizeDouble(entryPrice, Digits);
   
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, RuntimeLots);
   if(slDistance <= 0) return;
   
   double stopLoss = (pendingType == OP_BUYSTOP) ? (entryPrice - slDistance) : (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);
   
   ResetLastError();
   if(pendingType == OP_BUYSTOP) ChangeLots(GetOpenPL(OP_BUY));
   else if(pendingType == OP_SELLSTOP) ChangeLots(GetOpenPL(OP_SELL));
   
   int ticket = OrderSend(Symbol(), pendingType, RuntimeLots, entryPrice, Slippage, stopLoss, 0, orderComment, MagicNumber, 0, orderColor);
   
   if(ticket > 0) Print("PROFIT RE-ENTRY CREATED | Ticket: ", ticket);
   else { int err = GetLastError(); Print("PROFIT RE-ENTRY FAILED | ERROR: ", err); }
}

//+------------------------------------------------------------------+
//| CLOSE ALL ORDERS
//+------------------------------------------------------------------+

void CloseAllEAOrders()
{
   Print("Closing all EA orders...");
   bool finished = false;
   int retries = 0;

   while(!finished && retries < 3) {
      finished = true;
      RefreshRates();

      for(int i = OrdersTotal() - 1; i >= 0; i--) {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

         int type = OrderType();
         bool result = false;
         ResetLastError();

         if(type == OP_BUY) {
            result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
         } else if(type == OP_SELL) {
            result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
         } else {
            result = OrderDelete(OrderTicket(), clrRed);
         }

         if(!result) {
            int err = GetLastError();
            Print("Failed Ticket ", OrderTicket(), " Error=", err);
            finished = false;
         }
      }

      if(!finished) {
         retries++;
         Sleep(500);
      }
   }

   RefreshRates();
   int remain = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber) remain++;
   }

   Print("----------------------------------------");
   Print("Remaining EA Orders : ", remain);
   if(remain == 0) Print("ALL EA ORDERS CLOSED SUCCESSFULLY");
   else Print("WARNING : Some orders could not be closed.");
   Print("----------------------------------------");
}

void DeleteOppositePendingOrders(int newSignalType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      int orderType = OrderType();
      bool deleteOrder = ((newSignalType == OP_BUY && orderType == OP_SELLSTOP) || (newSignalType == OP_SELL && orderType == OP_BUYSTOP));
      
      if(deleteOrder) {
         int ticket = OrderTicket();
         ResetLastError();
         if(OrderDelete(ticket, clrYellow)) Print("OPPOSITE PENDING DELETED | Ticket: ", ticket);
         else Print("FAILED TO DELETE | Ticket: ", ticket, " | Error: ", GetLastError());
      }
   }
}

void CloseOppositeOrders(int newSignalType)
{
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      
      if((newSignalType == OP_BUY && orderType == OP_SELL) || (newSignalType == OP_SELL && orderType == OP_BUY)) {
         RefreshRates();
         ResetLastError();
         bool closed = (orderType == OP_SELL) ? OrderClose(ticket, lots, Ask, Slippage, clrRed) : OrderClose(ticket, lots, Bid, Slippage, clrBlue);
         if(closed) Print("OPPOSITE ", (orderType == OP_SELL ? "SELL" : "BUY"), " CLOSED | Ticket: ", ticket);
         else Print("FAILED TO CLOSE | Ticket: ", ticket, " | Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| ORDER COUNT FUNCTIONS
//+------------------------------------------------------------------+

int GetTotalBuyOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY) count++;
   }
   return count;
}

int GetTotalSellOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL) count++;
   }
   return count;
}

int GetTotalEAOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL || type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| SSL CHANNEL CALCULATION & SIGNALS
//+------------------------------------------------------------------+

void CalculateSSL(int shift, double &sslUp, double &sslDown, int &hlv)
{
   int oldest = Bars - SSLPeriod - 2;
   if(oldest < shift) oldest = shift;
   
   int currentHlv = 0;
   
   for(int i = oldest; i >= shift; i--) {
      double smaHigh = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_HIGH, i);
      double smaLow = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_LOW, i);
      double candleClose = Close[i];
      
      if(candleClose > smaHigh) currentHlv = 1;
      else if(candleClose < smaLow) currentHlv = -1;
      
      if(i == shift) {
         hlv = currentHlv;
         sslUp = (currentHlv < 0) ? smaLow : smaHigh;
         sslDown = (currentHlv < 0) ? smaHigh : smaLow;
         return;
      }
   }
   
   hlv = currentHlv;
   sslUp = 0;
   sslDown = 0;
}

bool IsBuySignal(int shift)
{
   if(shift + 1 >= Bars) return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious <= downPrevious && upCurrent > downCurrent);
}

bool IsSellSignal(int shift)
{
   if(shift + 1 >= Bars) return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious >= downPrevious && upCurrent < downCurrent);
}

//+------------------------------------------------------------------+
//| DRAWING & VISUALIZATION FUNCTIONS
//+------------------------------------------------------------------+

void UpdateSSLChannelOnTick()
{
   if(!ShowSSLLines || Bars < SSLPeriod + 20) return;
   
   int maxRecentBars = 10;
   if(maxRecentBars > Bars - SSLPeriod - 2) maxRecentBars = Bars - SSLPeriod - 2;
   
   for(int i = maxRecentBars; i >= 0; i--) {
      if(i + 1 >= Bars) continue;
      
      double up1, down1, up2, down2;
      int hlv1, hlv2;
      
      CalculateSSL(i, up1, down1, hlv1);
      CalculateSSL(i + 1, up2, down2, hlv2);
      
      DrawTrendSegment(PREFIX + "LIVE_UP_" + IntegerToString(i), Time[i], up1, Time[i + 1], up2, SSLUpColor);
      DrawTrendSegment(PREFIX + "LIVE_DOWN_" + IntegerToString(i), Time[i], down1, Time[i + 1], down2, SSLDownColor);
   }
   ChartRedraw();
}

void DrawHistoricalSignals()
{
   int barsToProcess = HistoryBarsToDraw;
   if(barsToProcess > Bars - SSLPeriod - 3) barsToProcess = Bars - SSLPeriod - 3;
   if(barsToProcess <= 0) return;
   
   if(ShowSSLLines) {
      for(int i = barsToProcess; i >= 1; i--) {
         double up1, down1, up2, down2;
         int hlv1, hlv2;
         CalculateSSL(i, up1, down1, hlv1);
         CalculateSSL(i - 1, up2, down2, hlv2);
         DrawTrendSegment(PREFIX + "HIST_UP_" + IntegerToString(i), Time[i], up1, Time[i - 1], up2, SSLUpColor);
         DrawTrendSegment(PREFIX + "HIST_DOWN_" + IntegerToString(i), Time[i], down1, Time[i - 1], down2, SSLDownColor);
      }
   }
   
   if(ShowHistoricalSignals) {
      for(int i = barsToProcess; i >= 1; i--) {
         if(IsBuySignal(i)) DrawHistoricalSignal(i, true);
         if(IsSellSignal(i)) DrawHistoricalSignal(i, false);
      }
   }
   ChartRedraw();
}

void DrawTrendSegment(string name, datetime time1, double price1, datetime time2, double price2, color lineColor)
{
   if(price1 <= 0 || price2 <= 0) return;
   
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   else { ObjectMove(0, name, 0, time1, price1); ObjectMove(0, name, 1, time2, price2); }
   
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SSLLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void DrawHistoricalSignal(int shift, bool isBuy)
{
   string type = isBuy ? "BUY" : "SELL";
   string baseName = PREFIX + type + "_" + IntegerToString((int)Time[shift]);
   double price = isBuy ? (Low[shift] - SignalDistancePoints * Point) : (High[shift] + SignalDistancePoints * Point);
   
   if(ShowSignalArrows) {
      string arrowName = baseName + "_ARROW";
      if(ObjectFind(0, arrowName) < 0) ObjectCreate(0, arrowName, OBJ_ARROW, 0, Time[shift], price);
      else ObjectMove(0, arrowName, 0, Time[shift], price);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, SignalArrowWidth);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   }
   
   if(ShowSignalText) {
      string textName = baseName + "_TEXT";
      double textPrice = isBuy ? (price - SignalDistancePoints * 0.30 * Point) : (price + SignalDistancePoints * 0.30 * Point);
      if(ObjectFind(0, textName) < 0) ObjectCreate(0, textName, OBJ_TEXT, 0, Time[shift], textPrice);
      else ObjectMove(0, textName, 0, Time[shift], textPrice);
      ObjectSetString(0, textName, OBJPROP_TEXT, isBuy ? "Long +1" : "Short -1");
      ObjectSetInteger(0, textName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, SignalFontSize);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
   }
}

void DrawLiveSignal(int shift, bool isBuy)
{
   DrawHistoricalSignal(shift, isBuy);
   ChartRedraw();
}

string TimeframeToString(int timeframe)
{
   switch(timeframe) {
      case PERIOD_M1: return "M1";
      case PERIOD_M5: return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1: return "H1";
      case PERIOD_H4: return "H4";
      case PERIOD_D1: return "D1";
      case PERIOD_W1: return "W1";
      case PERIOD_MN1: return "MN1";
   }
   return "CURRENT";
}

//+------------------------------------------------------------------+
//| DASHBOARD FUNCTIONS
//+------------------------------------------------------------------+

void CreateDashboardLabel(string name, string text, int x, int y, int fontSize, color textColor)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateDashboard(DailyProtectionState &state)
{
   if(!ShowDashboard) return;
   
   int totalOrders = 0, buyOrders = 0, sellOrders = 0, pendingOrders = 0;
   double floatingProfit = 0, totalSwap = 0, totalCommission = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL && type != OP_BUYSTOP && type != OP_SELLSTOP) continue;

      totalOrders++;
      floatingProfit += OrderProfit();
      totalSwap += OrderSwap();
      totalCommission += OrderCommission();

      if(type == OP_BUY) buyOrders++;
      else if(type == OP_SELL) sellOrders++;
      else pendingOrders++;
   }

   double netProfit = floatingProfit + totalSwap + totalCommission;
   color pnlColor = (netProfit > 0) ? clrLime : (netProfit < 0) ? clrTomato : clrWhite;

   string liveStatus = "WAITING SIGNAL";
   color liveColor = clrLime;

   if(IsDailyTradingStopped(state)) {
      liveStatus = "TRADING STOPPED";
      liveColor = clrRed;
   } else if(RecoveryMode) {
      liveStatus = "RECOVERY MODE";
      liveColor = clrOrange;
   } else if(GetTotalEAOrders() >= MaxOpenOrders) {
      liveStatus = "MAX ORDERS";
      liveColor = clrTomato;
   } else if(buyOrders > 0 && sellOrders == 0) {
      liveStatus = "BUY RUNNING";
      liveColor = clrDeepSkyBlue;
   } else if(sellOrders > 0 && buyOrders == 0) {
      liveStatus = "SELL RUNNING";
      liveColor = clrTomato;
   } else if(buyOrders > 0 && sellOrders > 0) {
      liveStatus = "BUY + SELL";
      liveColor = clrGold;
   }

   string statusText = IsDailyTradingStopped(state) ? "DAILY PROTECTION STOPPED" :
                       (state.ClosedOrdersToday < MinimumClosedOrdersForDailyProtection) ? "WAITING FOR ORDERS" :
                       (totalOrders >= MaxOpenOrders) ? "MAX ORDERS REACHED" : "READY FOR SIGNAL";

   color statusColor = IsDailyTradingStopped(state) ? clrTomato :
                       (state.ClosedOrdersToday < MinimumClosedOrdersForDailyProtection) ? clrGold : clrLimeGreen;

   int x = DashboardRightGap;
   int y = DashboardTopGap;

   CreateDashboardLabel(DASH_PREFIX + "STATUS", statusText, x, y + 50, DashboardFontSize, statusColor);
   CreateDashboardLabel(DASH_PREFIX + "LIVESTATUS", "Live Status : " + liveStatus, x, y + 70, DashboardFontSize, liveColor);
   CreateDashboardLabel(DASH_PREFIX + "SYMBOL", "Symbol : " + Symbol(), x, y + 92, DashboardFontSize, clrWhite);
   CreateDashboardLabel(DASH_PREFIX + "TIMEFRAME", "Timeframe : " + TimeframeToString(Period()), x, y + 114, DashboardFontSize, clrWhite);
   CreateDashboardLabel(DASH_PREFIX + "PNL", "Floating P/L : $" + DoubleToString(netProfit, 2), x, y + 138, 12, pnlColor);
   CreateDashboardLabel(DASH_PREFIX + "EQUITY", "Equity : $" + DoubleToString(AccountEquity(), 2), x, y + 160, DashboardFontSize, clrLime);
   CreateDashboardLabel(DASH_PREFIX + "OPENBAL", "Opening Balance : $" + DoubleToString(state.DayStartBalance, 2), x, y + 182, DashboardFontSize, clrAqua);
   CreateDashboardLabel(DASH_PREFIX + "LADDERLEVEL", "Equity Ladder Step : " + IntegerToString(EquityLadderLevel), x, y + 204, DashboardFontSize, clrYellow);
   CreateDashboardLabel(DASH_PREFIX + "LOCKEDEQUITY", "Protected Equity : $" + DoubleToString(LockedEquity, 2), x, y + 248, DashboardFontSize, clrGold);
   CreateDashboardLabel(DASH_PREFIX + "NEXTTARGET", "Next Equity Target : $" + DoubleToString(NextEquityTarget, 2), x, y + 270, DashboardFontSize, clrLime);

   double ladderProgress = 0;
   if(NextEquityTarget > state.DayStartBalance) {
      ladderProgress = ((AccountEquity() - state.DayStartBalance) / (NextEquityTarget - state.DayStartBalance)) * 100;
      if(ladderProgress < 0) ladderProgress = 0;
   }

   CreateDashboardLabel(DASH_PREFIX + "TARGETPROGRESS", "Target Progress : " + DoubleToString(ladderProgress, 1) + "%", x, y + 292, DashboardFontSize, clrWhite);
   CreateDashboardLabel(DASH_PREFIX + "ORDERS", "Orders : " + IntegerToString(totalOrders) + "/" + IntegerToString(MaxOpenOrders), x, y + 310, DashboardFontSize, clrWhite);
   CreateDashboardLabel(DASH_PREFIX + "BUY", "BUY : " + IntegerToString(buyOrders), x, y + 332, DashboardFontSize, clrDeepSkyBlue);
   CreateDashboardLabel(DASH_PREFIX + "SELL", "SELL : " + IntegerToString(sellOrders), x + 90, y + 354, DashboardFontSize, clrTomato);
   CreateDashboardLabel(DASH_PREFIX + "PENDING", "Pending : " + IntegerToString(pendingOrders), x, y + 376, DashboardFontSize, clrGold);
   CreateDashboardLabel(DASH_PREFIX + "LOT", "Current Lot : " + DoubleToString(RuntimeLots, 2), x, y + 398, DashboardFontSize, clrAqua);
   CreateDashboardLabel(DASH_PREFIX + "LADDER", "L1:$" + DoubleToString(RuntimeLadder1ProfitUSD, 2) + "  L2:$" + DoubleToString(RuntimeLadder2ProfitUSD, 2), x, y + 410, DashboardFontSize, clrLimeGreen);

   if(EnableDailyLossProtection) {
      CreateDashboardLabel(DASH_PREFIX + "CLOSED", "Closed Today : " + IntegerToString(state.ClosedOrdersToday) + "/" + IntegerToString(MinimumClosedOrdersForDailyProtection),
                          x, y + 420, DashboardFontSize, (state.ClosedOrdersToday >= MinimumClosedOrdersForDailyProtection) ? clrLime : clrGold);
      CreateDashboardLabel(DASH_PREFIX + "PROTECTED", "Protected : $" + DoubleToString(state.DayProtectedBalance, 2), x, y + 440, DashboardFontSize, clrGold);
   }
}

void InitializeLastProcessedClosedOrder()
{
   datetime latestCloseTime = 0;
   int latestTicket = -1;
   
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderCloseTime() > latestCloseTime) { latestCloseTime = OrderCloseTime(); latestTicket = OrderTicket(); }
   }
   
   LastProcessedClosedOrderTime = latestCloseTime;
   LastProcessedClosedTicket = latestTicket;
}

void DeleteOurObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX, 0) == 0) ObjectDelete(0, name);
   }
}

void DeleteDashboardObjects()
{
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, DASH_PREFIX, 0) == 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| END OF EA
//+------------------------------------------------------------------+
