//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - ULTRA COMPACT             |
//|                  TWO-STAGE PROFIT LADDER | FIXED & OPTIMIZED      |
//+------------------------------------------------------------------+
#property strict

// ===== INPUT SETTINGS =====
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
int MinimumClosedOrdersForDailyProtection =10;// 100;
bool EnableDailyEquityTarget = true;
bool CloseOrdersOnDailyEquityTarget = true;
bool EnableEquityLadder = true;


double DailyEquityTargetPercent =5;// 10;//2;//3;//1;//3;//10;//Trading continue with 10% profit reccuring 
double DailyLossProtectionPercent =100;//50;// 30.0;// Trading stops if equity drops below this percentage of the starting balance for the day
bool EnableDynamicEquityLadder = true;////Trading continue with 10% profit reccuring 
double EquityLadderLossPercentAfterstep1=50;//10;//50;//50% of ladder protection

double OriginalDailyEquityTargetPercent = 5.0;
double CurrentDynamicTargetPercent = 5.0;

double OriginalDailyLossProtectionPercent = 30.0;

double EquityLockPercent = 80;
bool ContinueTradingAfterTarget = true;
bool ResetLadderEveryDay = true;
int EquityLadderLevel = 1;
double NextEquityTarget = 0;
double LockedEquity = 0;
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
int LastProcessedClosedTicket = -1, RecoveryOrders = 0;
bool StartupSignalProcessed = false, RecoveryMode = false, BasketTrailingArmed = false;
bool ProfitLadder1Triggered = false, ProfitLadder2Triggered = false;
double GlbFinalPL = 0, OriginalLots = 0.01, OriginalLadder1ProfitUSD = 0.05, OriginalLadder2ProfitUSD = 0.20;
double CurrentMultiplier = 1.0, BasketHighestProfit = 0.0, BasketTrailingStop = 0.0, DynamicBasketHighestProfit = 0.0;

//+------------------------------------------------------------------+
void InitializeEquityLadder(DailyProtectionState &state)
{
   LockedEquity = state.DayStartBalance;

   NextEquityTarget =
      state.DayStartBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);
}

void ProcessStartupSignal(DailyProtectionState &dailyState) {
   if(StartupSignalProcessed || Bars < SSLPeriod + 20) return;
   StartupSignalProcessed = true;
   
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(1, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(2, upPrevious, downPrevious, hlvPrevious);
   
   bool buySignal = (upCurrent > downCurrent);
   bool sellSignal = (upCurrent < downCurrent);

//    bool buySignal = IsBuySignal(1);
// bool sellSignal = IsSellSignal(1);
   
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
void UpdateDynamicEquityTarget(DailyProtectionState &state)
{
   if(state.DayStartBalance <= 0)
      return;

   double drawdown =
      (state.DayStartBalance - AccountEquity()) /
      state.DayStartBalance * 100.0;

   int reduceSteps = (int)MathFloor(drawdown / 5.0);

   double newTarget =
      OriginalDailyEquityTargetPercent - reduceSteps;

   // Minimum allowed target
   if(newTarget < 1.0)
      newTarget = 1.0;

   // Only decrease, never increase
   if(newTarget < CurrentDynamicTargetPercent)
   {
      CurrentDynamicTargetPercent = newTarget;
      DailyEquityTargetPercent = CurrentDynamicTargetPercent;

      NextEquityTarget =
         state.DayStartBalance *
         (1.0 + DailyEquityTargetPercent / 100.0);

      Print("Dynamic Target Reduced -> ",
            DoubleToString(DailyEquityTargetPercent,2), "%");
   }
}
int OnInit() {
   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;

   OriginalDailyLossProtectionPercent = DailyLossProtectionPercent;
OriginalDailyEquityTargetPercent = DailyEquityTargetPercent;

OriginalDailyEquityTargetPercent = DailyEquityTargetPercent;
CurrentDynamicTargetPercent = DailyEquityTargetPercent;

   Print("========== SSL CHANNEL CROSS EA - FIXED VERSION ==========");
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
   int EAOrders = 0;

   datetime LastOrderCandleTime = 0;
bool OrderCreatedThisCandle = false;
bool IsOneCandleOrderAllowed()
{
   if(Time[0] != LastOrderCandleTime)
   {
      LastOrderCandleTime = Time[0];
      OrderCreatedThisCandle = false;
   }

   if(OrderCreatedThisCandle)
   {
      Print("ORDER BLOCKED | Already opened on current candle");
      return false;
   }

   return true;
}
void OnDeinit(const int reason) { DeleteOurObjects(); DeleteDashboardObjects(); }

void OnTick() {
   static DailyProtectionState dailyState;
   
   CheckRecoveryOrders();
   ManageRecoveryBasket();
   if(!dailyState.Initialized) InitializeDailyProtectionState(dailyState);
   
   ProcessStartupSignal(dailyState);
   UpdateDailyLossProtection(dailyState);
   UpdateDynamicEquityTarget(dailyState);

   CheckDynamicEquityLadder(dailyState);
   if(ShowSSLLines) UpdateSSLChannelOnTick();
   if(Bars >= SSLPeriod + 20 && EAOrders > 0) CheckForProfitableClosedOrder(dailyState);
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

bool HasMinimumSameOrderGap(int orderType) {
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

double GetOpenPL(int OrderTypeFilter) {
   double OpenPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() == OrderTypeFilter) OpenPL += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return OpenPL;
}
//0.03
void ChangeLots(double OpenPL,string reason) {
   int Multiplier = 1;//(OpenPL < -10) ? 2 : (OpenPL < -2) ? 2 : 1;

if(reason=="SSL Long" || reason=="SSL Short")
{
   Multiplier=3;
}

   Lots = OriginalLots * Multiplier;
   Ladder1ProfitUSD = OriginalLadder1ProfitUSD * Multiplier;
   Ladder2ProfitUSD = OriginalLadder2ProfitUSD * Multiplier;
}

void CheckRecoveryOrders() {


   
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

      if(!IsOneCandleOrderAllowed())
   continue;
      if(OrderType() == OP_BUY) {
         // if(!HasMinimumSameOrderGap(OP_BUY)) continue;
         OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrAqua);
      } else {
         // if(!HasMinimumSameOrderGap(OP_SELL)) continue;
         OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrOrange);
      }

      OrderCreatedThisCandle = true;
LastOrderCandleTime = Time[0];
   }
}
bool HasRecoveryOrder(int ParentTicket)
{
   string txt="RECOVERY_"+IntegerToString(ParentTicket);

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderComment()==txt)
         return true;
   }

   return false;
}
bool HasRecoveryOrderold(int ParentTicket) {
   string txt = "RECOVERY_" + IntegerToString(ParentTicket);
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() == MagicNumber && OrderComment() == txt) return true;
   }
   return false;
}

void ManageRecoveryBasket()
{
   if(!EnableRecoveryOrders)
      return;

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() ||
         OrderMagicNumber()!=MagicNumber)
         continue;


      string comment = OrderComment();


      // Find recovery order
      if(StringFind(comment,"RECOVERY_") != 0)
         continue;


      int parentTicket = StrToInteger(
                           StringSubstr(comment,
                           StringLen("RECOVERY_"))
                          );


      double recoveryProfit =
            OrderProfit()
          + OrderSwap()
          + OrderCommission();



      // Find parent order
      if(!OrderSelect(parentTicket,SELECT_BY_TICKET))
         continue;


      if(OrderCloseTime()>0)
         continue;


      double parentProfit =
            OrderProfit()
          + OrderSwap()
          + OrderCommission();



      double basketProfit =
            recoveryProfit
          + parentProfit;



      Print("RECOVERY CHECK | Parent:",
            parentTicket,
            " Basket Profit:",
            DoubleToString(basketProfit,2));


      if(basketProfit >= RecoveryBasketProfitUSD)
      {

         // close ONLY parent
         RefreshRates();

         bool closed=false;

         if(OrderType()==OP_BUY)
         {
            closed=OrderClose(
                    OrderTicket(),
                    OrderLots(),
                    Bid,
                    Slippage,
                    clrRed);
         }
         else if(OrderType()==OP_SELL)
         {
            closed=OrderClose(
                    OrderTicket(),
                    OrderLots(),
                    Ask,
                    Slippage,
                    clrBlue);
         }


         if(closed)
         {
            Print("RECOVERY SUCCESS | Parent Closed Only : ",
                  parentTicket);
         }
         else
         {
            Print("FAILED Parent Close : ",
                  parentTicket,
                  " Error:",
                  GetLastError());
         }


         return;
      }
   }
}

void CloseBasket(int type) {
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol() || OrderType() != type) continue;
      if(type == OP_BUY) OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
      else OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
   }
}

void InitializeDailyProtectionState(DailyProtectionState &state) {
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   state.DayDate = StrToTime(today);
   state.DayStartBalance = AccountBalance();
   state.DayHighestBalance = state.DayStartBalance;
   // state.DayProtectedBalance = state.DayStartBalance;
   state.DayProtectedBalance =
    state.DayStartBalance *
    (1.0 - DailyLossProtectionPercent/100.0);
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
void CheckDynamicEquityLadder(DailyProtectionState &state)
{
   if(!EnableDynamicEquityLadder && EAOrders > 0)
      return;

   double equity = AccountEquity();

   if(equity < NextEquityTarget )
      return;
      // else
      // Print("-------------------EQUITY TARGET REACHED | Current Equity: $", DoubleToString(equity, 2), " | Target: $", DoubleToString(NextEquityTarget, 2));

   Print("==============================");
   Print("EQUITY TARGET REACHED");
   Print("Current Equity : ", DoubleToString(equity,2));
   Print("==============================");

   // Close every EA order
   
int retry=0;

while(GetTotalEAOrders()>0 && retry<5)
{
   Sleep(500);
   RefreshRates();
   CloseAllEAOrdersOnDailyLoss();
   retry++;
}

if(GetTotalEAOrders()>0)
{
   Print("Unable to close all orders.");
   return;
}

   // -------- COMPLETE RESET --------

   Lots = OriginalLots;

   Ladder1ProfitUSD = OriginalLadder1ProfitUSD;
   Ladder2ProfitUSD = OriginalLadder2ProfitUSD;

   ProfitLadder1Triggered = false;
   ProfitLadder2Triggered = false;

   RecoveryMode = false;
   RecoveryOrders = 0;

   CurrentMultiplier = 1.0;

   BasketHighestProfit = 0;
   BasketTrailingStop = 0;
   BasketTrailingArmed = false;
   DynamicBasketHighestProfit = 0;

   state.DayStartBalance     = AccountBalance();
   state.DayHighestBalance   = state.DayStartBalance;
   // state.DayProtectedBalance = state.DayStartBalance;
   state.DayProtectedBalance =
    state.DayStartBalance *
    (1.0 - DailyLossProtectionPercent/100.0);
   state.DayPeakProfit       = 0;

   state.DailyClosedProfit   = 0;
   state.DailyClosedOrders   = 0;
   state.ClosedOrdersToday   = 0;

   state.TradingStopped = false;
   state.LossTriggered  = false;

   DailyProtectionStartTime = TimeCurrent();
// if(NextEquityTarget > 0)
   // EquityLadderLevel++;
   InitializeEquityLadder(state);

// Increase ladder step
EquityLadderLevel++;

// if(EquityLadderLevel > 2)
// {
//    DailyLossProtectionPercent = EquityLadderLossPercentAfterstep1;

//    Print("LADDER STEP ", EquityLadderLevel,
//          " ACTIVE | Loss Protection changed to ",
//          DoubleToString(DailyLossProtectionPercent,2),
//          "%");
// }

double newBalance = AccountBalance();

double earnedProfit = newBalance - state.DayHighestBalance;

state.DayStartBalance = newBalance;

if(EquityLadderLevel<=2)
{
   // First cycle uses normal daily loss %
   state.DayProtectedBalance =
      state.DayStartBalance *
      (1.0 - DailyLossProtectionPercent/100.0);
}
else
{
   // Lock part of earned profit
   state.DayProtectedBalance =
      state.DayStartBalance -
      (earnedProfit * EquityLadderLossPercentAfterstep1/100.0);
}


   NextEquityTarget =
      state.DayStartBalance *
      (1.0 + DailyEquityTargetPercent/100.0);

   Print("Fresh Trading Started");
   Print("New Start Balance : ",
         DoubleToString(state.DayStartBalance,2));
   Print("Next Target : ",
         DoubleToString(NextEquityTarget,2));
}
/*
void CheckDynamicEquityLadderold(DailyProtectionState &state) {
   if(!EnableDynamicEquityLadder || state.TradingStopped || state.ClosedOrdersToday < MinimumClosedOrdersForDailyProtection) return;
   
   double equity = AccountEquity();
   
   if(equity >= NextEquityTarget) {
      Print("=== NEW EQUITY LADDER LEVEL ", EquityLadderLevel, "X ===");
      
      double previousBalance = state.DayStartBalance;
      double gain = equity - previousBalance;
      
      state.DayStartBalance = equity;
      state.DayHighestBalance = equity;
      state.DayPeakProfit = 0.0;
      state.DailyClosedProfit = 0.0;
      state.DailyClosedOrders = 0;
      state.TradingStopped = false;
      state.LossTriggered = false;
      
      LockedEquity = previousBalance + (gain * EquityLockPercent / 100.0);
      state.DayProtectedBalance = LockedEquity;
      NextEquityTarget = equity * (1.0 + DailyEquityTargetPercent / 100.0);
      
      LastProfitTargetTime = TimeCurrent();
      RecoveryMode = false;
      RecoveryOrders = 0;
      CurrentMultiplier = 1.0;
      BasketHighestProfit = 0.0;
      BasketTrailingArmed = false;
      BasketTrailingStop = 0.0;
      DynamicBasketHighestProfit = 0.0;
      ProfitLadder1Triggered = false;
      ProfitLadder2Triggered = false;
      
      EquityLadderLevel++;
      
      Print("Level: ", EquityLadderLevel, "X | Equity: $", DoubleToString(equity, 2), " | Locked: $", DoubleToString(LockedEquity, 2));
      Print("Next Target: $", DoubleToString(NextEquityTarget, 2));
      CloseAllEAOrdersOnDailyLoss();
      return;
   }
   
   if(equity <= LockedEquity && EquityLadderLevel > 1) {
      Print("EQUITY LOCK HIT | Current: $", DoubleToString(equity, 2), " | Lock: $", DoubleToString(LockedEquity, 2));
      state.TradingStopped = true;
      if(CloseOrdersOnDailyEquityTarget) CloseAllEAOrdersOnDailyLoss();
   }
}
   */

void UpdateDailyLossProtection(DailyProtectionState &state) {
   if(!EnableDailyLossProtection) return;
   
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   datetime todayDate = StrToTime(today);
   
   if(ResetDailyProtectionEveryDay && state.DayDate != todayDate) {
      state.DayDate = todayDate;
      state.DayStartBalance = AccountBalance();
      state.DayHighestBalance = state.DayStartBalance;
      // state.DayProtectedBalance = state.DayStartBalance;
      state.DayProtectedBalance =
    state.DayStartBalance *
    (1.0 - DailyLossProtectionPercent/100.0);
      state.ClosedOrdersToday = 0;
      state.TradingStopped = false;
          DailyLossProtectionPercent = OriginalDailyLossProtectionPercent;

      
      DailyProtectionStartTime = TimeCurrent();
      Lots = OriginalLots;
      Ladder1ProfitUSD = OriginalLadder1ProfitUSD;
      Ladder2ProfitUSD = OriginalLadder2ProfitUSD;
      
      InitializeEquityLadder(state);
      EquityLadderLevel = 1;
      LockedEquity = state.DayStartBalance;
      
      Print("==== NEW DAY - DAILY PROFIT PROTECTION RESET ====");
      Print("Day Start: $", DoubleToString(state.DayStartBalance, 2), " | Protected: $", DoubleToString(state.DayProtectedBalance, 2));
      Print("==================================================");
   }
   
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   double currentBalance = AccountBalance();
   double currentEquity = AccountEquity();
   // double minEquity = state.DayStartBalance * (1.0 - DailyLossProtectionPercent / 100.0);
   double minEquity =
   state.DayStartBalance -
   (state.DayStartBalance * DailyLossProtectionPercent / 100.0);


if(AccountEquity() <= minEquity)
{
   state.TradingStopped=true;

   Print("PROTECTED EQUITY STOP");
   Print("Start Balance : $",DoubleToString(state.DayStartBalance,2));
   Print("Protection %  : ",DoubleToString(DailyLossProtectionPercent,2));
   Print("Stop Equity   : $",DoubleToString(minEquity,2));
   Print("Current Equity:",DoubleToString(AccountEquity(),2));

   if(CloseOpenOrdersOnDailyLoss)
      CloseAllEAOrdersOnDailyLoss();

   return;
}

   if(currentEquity <= minEquity) {
      if(!state.TradingStopped) {
         state.TradingStopped = true;
         Print("EQUITY LOSS LIMIT REACHED | "+DoubleToString(DailyLossProtectionPercent,2)+"% Start: $", DoubleToString(state.DayStartBalance, 2), " | Current: $", DoubleToString(currentEquity, 2));
         if(CloseOpenOrdersOnDailyLoss) CloseAllEAOrdersOnDailyLoss();
      }
      return;
   }
   
   // if(currentBalance > state.DayHighestBalance) {
   //    state.DayHighestBalance = currentBalance;
   //    double profitAboveStart = state.DayHighestBalance - state.DayStartBalance;
      
   //    if(profitAboveStart > 0) {
   //       double protectedProfit = profitAboveStart * DailyLossProtectionPercent / 100.0;
   //       state.DayProtectedBalance = state.DayStartBalance + protectedProfit;
   //    } else {
   //       // state.DayProtectedBalance = state.DayStartBalance;
   //       state.DayProtectedBalance =
   //  state.DayStartBalance *
   //  (1.0 - DailyLossProtectionPercent/100.0);
   //    }
      
   //    Print("DAILY HIGH: $", DoubleToString(state.DayHighestBalance, 2), " | Profit: $", DoubleToString(profitAboveStart, 2), " | Protected: $", DoubleToString(state.DayProtectedBalance, 2));
   // }
   
   if(state.ClosedOrdersToday < MinimumClosedOrdersForDailyProtection) return;
   
  // ================================
// PROTECTED EQUITY STOP
// ================================

if(AccountEquity() <= state.DayProtectedBalance)
{
   if(!state.TradingStopped)
   {
      state.TradingStopped = true;
      state.LossTriggered = true;

      Print("===============================");
      Print("PROTECTED EQUITY STOP TRIGGERED");
      Print("Protected Equity : $", 
            DoubleToString(state.DayProtectedBalance,2));
      Print("Current Equity   : $", 
            DoubleToString(AccountEquity(),2));
      Print("===============================");

      if(CloseOpenOrdersOnDailyLoss)
         CloseAllEAOrdersOnDailyLoss();
   }

   return;
}
}

int CountClosedOrdersSinceInitialization() {
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

bool IsDailyTradingStopped(DailyProtectionState &state) { return EnableDailyLossProtection && state.TradingStopped; }

void DeleteOppositePendingOrders(int newSignalType) {
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

void CloseOppositeOrders(int newSignalType) {
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
//| Close ALL EA Orders and Pending Orders                           |
//| Wait until everything is closed                                  |
//+------------------------------------------------------------------+
void CloseAllEAOrdersOnDailyLoss()
{
   Print("Closing all EA orders...");

   bool finished = false;
   int retries = 0;

   if(EAOrders == 0)
   {
      Print("No EA orders to close.");
      return;
   }

   while(!finished && retries < 3)
   {
      finished = true;
      RefreshRates();

      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol())
            continue;

         if(OrderMagicNumber() != MagicNumber)
            continue;

         int type = OrderType();
         bool result = false;

         ResetLastError();

         switch(type)
         {
            case OP_BUY:
               result = OrderClose(
                           OrderTicket(),
                           OrderLots(),
                           Bid,
                           Slippage,
                           clrRed);
               break;

            case OP_SELL:
               result = OrderClose(
                           OrderTicket(),
                           OrderLots(),
                           Ask,
                           Slippage,
                           clrBlue);
               break;

            case OP_BUYSTOP:
            case OP_SELLSTOP:
            case OP_BUYLIMIT:
            case OP_SELLLIMIT:
               result = OrderDelete(
                           OrderTicket(),
                           clrRed);
               break;
         }

         if(!result)
         {
            int err = GetLastError();

            Print("Failed Ticket ",
                  OrderTicket(),
                  " Error=",
                  err);

            finished = false;
         }
      }

      if(!finished)
      {
         retries++;
         Sleep(500);
      }
   }

   RefreshRates();

   int remain = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
      {
         remain++;
      }
   }

   Print("----------------------------------------");
   Print("Remaining EA Orders : ", remain);

   if(remain == 0)
      Print("ALL EA ORDERS CLOSED SUCCESSFULLY");
   else
      Print("WARNING : Some orders could not be closed.");
   Print("----------------------------------------");
}
void CloseAllEAOrdersOnDailyLossold() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      int type = OrderType();
      int ticket = OrderTicket();
      RefreshRates();
      ResetLastError();
      
      if(type == OP_BUY) OrderClose(ticket, OrderLots(), Bid, Slippage, clrRed);
      else if(type == OP_SELL) OrderClose(ticket, OrderLots(), Ask, Slippage, clrRed);
      else if(type == OP_BUYSTOP || type == OP_SELLSTOP) OrderDelete(ticket, clrRed);
   }
}

void UpdateSSLChannelOnTick() {
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

void InitializeLastProcessedClosedOrder() {
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

void CheckForProfitableClosedOrder(DailyProtectionState &state) {
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
      if(EnableProfitReEntryStop && !IsDailyTradingStopped(state)) CreateProfitReEntryStop(latestType, latestClosePrice, state);
      return;
   }
   
   Print("ORDER CLOSED WITHOUT PROFIT | P/L: $", DoubleToString(latestProfit, 2));
   if(EnableTrading && !IsDailyTradingStopped(state)) {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(1)) { OpenBuy(); Print("BUY opened after closed order"); }
      if(GetTotalSellOrders() == 0 && IsSellSignal(1)) { OpenSell(); Print("SELL opened after closed order"); }
   }
}

void CreateProfitReEntryStop(int closedOrderType, double closedPrice, DailyProtectionState &state) {
   if(!EnableTrading || !EnableProfitReEntryStop || IsDailyTradingStopped(state)) return;
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
   
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0) return;
   
   double stopLoss = (pendingType == OP_BUYSTOP) ? (entryPrice - slDistance) : (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);
   
   ResetLastError();
   if(pendingType == OP_BUYSTOP) ChangeLots(GetOpenPL(OP_BUY),"SSL Profit ReEntry Buy Stop");
   else if(pendingType == OP_SELLSTOP) ChangeLots(GetOpenPL(OP_SELL),"SSL Profit ReEntry Sell Stop");
   
   int ticket = OrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, 0, orderComment, MagicNumber, 0, orderColor);
   
   if(ticket < 0) Print("PROFIT RE-ENTRY FAILED | ERROR: ", GetLastError());
   else Print("PROFIT RE-ENTRY CREATED | Ticket: ", ticket);
}

int GetTotalBuyOrders() {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY) count++;
   }
   return count;
}

int GetTotalSellOrders() {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL) count++;
   }
   return count;
}

int GetTotalEAOrders() {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int type = OrderType();
     if(type==OP_BUY ||
   type==OP_SELL ||
   type==OP_BUYSTOP ||
   type==OP_SELLSTOP ||
   type==OP_BUYLIMIT ||
   type==OP_SELLLIMIT)
{
   count++;
}
   }
   return count;
}
 
void OpenBuy() {


   
 if(!IsOneCandleOrderAllowed())
      return;

   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_BUY)) return;
   ChangeLots(GetOpenPL(OP_SELL),"SSL Long");
   RefreshRates();
   EAOrders++;
   
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0) return;
   
   double stopLoss = NormalizeDouble(Ask - slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, stopLoss, 0, "SSL Long", MagicNumber, 0, BuyColor);
   
   if(ticket < 0) Print("BUY FAILED | ERROR: ", GetLastError());
   else Print("BUY OPENED | Ticket: ", ticket);
}

void OpenSell() {
    if(!IsOneCandleOrderAllowed())
      return;
   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_SELL)) return;
   ChangeLots(GetOpenPL(OP_BUY),"SSL Short");
   RefreshRates();
      EAOrders++;

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0) return;
   
   double stopLoss = NormalizeDouble(Bid + slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, stopLoss, 0, "SSL Short", MagicNumber, 0, SellColor);
   
   if(ticket < 0) Print("SELL FAILED | ERROR: ", GetLastError());
   else Print("SELL OPENED | Ticket: ", ticket);
}

double CalculatePriceDistanceUSD(double usdAmount, double orderLots) {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || orderLots <= 0) return 0;
   return (usdAmount / (tickValue * orderLots)) * tickSize;
}

void ManageProfitLadder() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      
      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL) continue;
      
      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(currentProfit <= 0) continue;
      
      double lockedProfit = 0;
      
      if(EnableProfitLadder1 && Ladder1ProfitUSD > 0 && currentProfit < Ladder1StopMaxPriceUSD) {
         int ladder1Level = (int)MathFloor(currentProfit / Ladder1ProfitUSD);
         if(ladder1Level >= 2) lockedProfit = (ladder1Level - 1) * Ladder1ProfitUSD;
      }
      
      if(EnableProfitLadder2 && Ladder2ProfitUSD > 0 && currentProfit >= Ladder1StopMaxPriceUSD) {
         int ladder2Level = (int)MathFloor(currentProfit / Ladder2ProfitUSD);
         if(ladder2Level >= 2) lockedProfit = (ladder2Level - 1) * Ladder2ProfitUSD;
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
      }
      
      if(orderType == OP_SELL) {
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

void CalculateSSL(int shift, double &sslUp, double &sslDown, int &hlv) {
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

bool IsBuySignal(int shift) {
   if(shift + 1 >= Bars) return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious <= downPrevious && upCurrent > downCurrent);
}

bool IsSellSignal(int shift) {
   if(shift + 1 >= Bars) return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious >= downPrevious && upCurrent < downCurrent);
}

void DrawHistoricalSignals() {
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

void DrawTrendSegment(string name, datetime time1, double price1, datetime time2, double price2, color lineColor) {
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

void DrawHistoricalSignal(int shift, bool isBuy) {
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

void DrawLiveSignal(int shift, bool isBuy) { DrawHistoricalSignal(shift, isBuy); ChartRedraw(); }

string TimeframeToString(int timeframe) {
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

void CreateDashboardPanel(string name, int x, int y, int width, int height, color background) {
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateDashboardLabel(string name, string text, int x, int y, int fontSize, color textColor) {
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

void DrawLiveOrdersTable() {
   string prefix = "LIVE_ORDERS_";
   for(int i = 0; i < 100; i++) ObjectDelete(prefix + "L" + IntegerToString(i));
   
   ObjectDelete("LIVE_ORDERS_PANEL");
   ObjectCreate("LIVE_ORDERS_PANEL", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_CORNER, 0);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_XDISTANCE, 5);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_YDISTANCE, 10);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_XSIZE, 360);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_YSIZE, 320);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_BGCOLOR, clrBlack);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_COLOR, clrDimGray);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_BACK, false);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_SELECTABLE, false);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_HIDDEN, true);
   ObjectSet("LIVE_ORDERS_PANEL", OBJPROP_ZORDER, 0);
   
   int x = 10, y = 20, row = 0;
   string font = "Consolas", txt = "Ticket     Type   Lot    Open        Profit";
   int size = 9;
   
   ObjectCreate(prefix + "L0", OBJ_LABEL, 0, 0, 0);
   ObjectSet(prefix + "L0", OBJPROP_CORNER, 0);
   ObjectSet(prefix + "L0", OBJPROP_XDISTANCE, x);
   ObjectSet(prefix + "L0", OBJPROP_YDISTANCE, y);
   ObjectSetText(prefix + "L0", txt, size, font, clrYellow);
   row++;
   
   double totalPL = 0, totalLots = 0;
   int totalOrders = 0;
   
   for(int i = OrdersTotal() - 1; i >= 0; i--) {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      totalPL += pl;
      totalLots += OrderLots();
      totalOrders++;
      
      string type = OrderType() == OP_BUY ? "BUY " : "SELL";
      txt = StringFormat("%-9d %-5s %0.2f %10." + IntegerToString(Digits) + "f %7.2f", OrderTicket(), type, OrderLots(), OrderOpenPrice(), pl);
      
      string name = prefix + "L" + IntegerToString(row);
      ObjectCreate(name, OBJ_LABEL, 0, 0, 0);
      ObjectSet(name, OBJPROP_CORNER, 0);
      ObjectSet(name, OBJPROP_XDISTANCE, x);
      ObjectSet(name, OBJPROP_YDISTANCE, y + (row * 16));
      
      color c = clrWhite;
      if(pl > 0) c = clrLime;
      if(pl < 0) c = clrRed;
      ObjectSetText(name, txt, size, font, c);
      row++;
   }
   
   txt = "------------------------------------------------";
   ObjectCreate(prefix + "L" + IntegerToString(row), OBJ_LABEL, 0, 0, 0);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_CORNER, 0);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_XDISTANCE, x);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_YDISTANCE, y + (row * 16));
   ObjectSetText(prefix + "L" + IntegerToString(row), txt, size, font, clrSilver);
   row++;
   
   txt = StringFormat("Orders:%d   Lots:%.2f   Total P/L: %.2f", totalOrders, totalLots, totalPL);
   GlbFinalPL = totalPL;
   
   ObjectCreate(prefix + "L" + IntegerToString(row), OBJ_LABEL, 0, 0, 0);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_CORNER, 0);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_XDISTANCE, x);
   ObjectSet(prefix + "L" + IntegerToString(row), OBJPROP_YDISTANCE, y + (row * 16));
   
   color totalColor = clrWhite;
   if(totalPL > 0) totalColor = clrLime;
   if(totalPL < 0) totalColor = clrRed;
   ObjectSetText(prefix + "L" + IntegerToString(row), txt, size, font, totalColor);
}
void UpdateDashboard(DailyProtectionState &state)
{
   DrawLiveOrdersTable();

   int totalOrders=0,buyOrders=0,sellOrders=0,pendingOrders=0;
   double floatingProfit=0,totalSwap=0,totalCommission=0;
   string ordersDetails="";

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() ||
         OrderMagicNumber()!=MagicNumber)
         continue;

      int type=OrderType();

      if(type!=OP_BUY &&
         type!=OP_SELL &&
         type!=OP_BUYSTOP &&
         type!=OP_SELLSTOP)
         continue;

      totalOrders++;

      if(type==OP_BUY)
      {
         buyOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
      }
      else if(type==OP_SELL)
      {
         sellOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
      }
      else
      {
         pendingOrders++;
      }

      string orderType=
         (type==OP_BUY)?"BUY":
         (type==OP_SELL)?"SELL":
         (type==OP_BUYSTOP)?"BUY STOP":"SELL STOP";

      string line="#"+IntegerToString(OrderTicket())+" "+orderType;

      if(type==OP_BUY || type==OP_SELL)
      {
         double p=OrderProfit()+OrderSwap()+OrderCommission();
         line+=" P/L:"+DoubleToString(p,2);
      }
      else
      {
         line+=" @"+DoubleToString(OrderOpenPrice(),Digits);
      }

      ordersDetails+=line+"\n";
   }

   double netProfit=floatingProfit+totalSwap+totalCommission;

   color pnlColor=
      netProfit>0 ? clrLime :
      netProfit<0 ? clrTomato :
      clrWhite;

   //---------------------------------
   // LIVE STATUS
   //---------------------------------

   string liveStatus="WAITING SIGNAL";
   color liveColor=clrLime;

   if(IsDailyTradingStopped(state))
   {
      liveStatus="TRADING STOPPED";
      liveColor=clrRed;
   }
   else if(RecoveryMode)
   {
      liveStatus="RECOVERY MODE";
      liveColor=clrOrange;
   }
   else if(GetTotalEAOrders()>=MaxOpenOrders)
   {
      liveStatus="MAX ORDERS";
      liveColor=clrTomato;
   }
   else if(buyOrders>0 && sellOrders==0)
   {
      liveStatus="BUY RUNNING";
      liveColor=clrDeepSkyBlue;
   }
   else if(sellOrders>0 && buyOrders==0)
   {
      liveStatus="SELL RUNNING";
      liveColor=clrTomato;
   }
   else if(buyOrders>0 && sellOrders>0)
   {
      liveStatus="BUY + SELL";
      liveColor=clrGold;
   }

   //---------------------------------

   string statusText=
      IsDailyTradingStopped(state)?
      "DAILY PROTECTION STOPPED":
      (state.ClosedOrdersToday<MinimumClosedOrdersForDailyProtection)?
      "WAITING FOR ORDERS":
      (totalOrders>=MaxOpenOrders)?
      "MAX ORDERS REACHED":
      "READY FOR SIGNAL";

   color statusColor=
      IsDailyTradingStopped(state)?
      clrTomato:
      (state.ClosedOrdersToday<MinimumClosedOrdersForDailyProtection)?
      clrGold:
      clrLimeGreen;

   int x=DashboardRightGap;
   int y=DashboardTopGap;
   int textX=x+DashboardWidth-300;

   CreateDashboardPanel(DASH_PREFIX+"PANEL",
                        x,y,
                        DashboardWidth,
                        DashboardHeight,
                        clrBlack);

   CreateDashboardPanel(DASH_PREFIX+"HEADER",
                        x,y,
                        DashboardWidth,
                        35,
                        C'30,60,100');

   CreateDashboardLabel(DASH_PREFIX+"TITLE",
                        "202608- EA",
                        textX,
                        y+8,
                        11,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"STATUS",
                        statusText,
                        textX,
                        y+50,
                        DashboardFontSize,
                        statusColor);

   CreateDashboardLabel(DASH_PREFIX+"LIVESTATUS",
                        "Live Status : "+liveStatus,
                        textX,
                        y+70,
                        DashboardFontSize,
                        liveColor);

   CreateDashboardLabel(DASH_PREFIX+"SYMBOL",
                        "Symbol : "+Symbol(),
                        textX,
                        y+92,
                        DashboardFontSize,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"TIMEFRAME",
                        "Timeframe : "+TimeframeToString(Period()),
                        textX,
                        y+114,
                        DashboardFontSize,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"PNL",
                        "Floating P/L : $"+DoubleToString(netProfit,2),
                        textX,
                        y+138,
                        12,
                        pnlColor);

   CreateDashboardLabel(DASH_PREFIX+"EQUITY",
                        "Equity : $"+DoubleToString(AccountEquity(),2),
                        textX,
                        y+160,
                        DashboardFontSize,
                        clrLime);

  CreateDashboardLabel(DASH_PREFIX+"OPENBAL",
                     "Opening Balance : $"+DoubleToString(state.DayStartBalance,2),
                     textX,
                     y+182,
                     DashboardFontSize,
                     clrAqua);


// ================================
// EQUITY LADDER INFORMATION
// ================================

CreateDashboardLabel(
                     DASH_PREFIX+"LADDERLEVEL",
                     "Equity Ladder Step : "+
                     IntegerToString(EquityLadderLevel)+" / "+DoubleToString(CurrentDynamicTargetPercent,0),
                     textX,
                     y+204,
                     DashboardFontSize,
                     clrYellow);


CreateDashboardLabel(
                     DASH_PREFIX+"LADDERSTART",
                     "Ladder Start Balance : $"+
                     DoubleToString(state.DayStartBalance,2),
                     textX,
                     y+226,
                     DashboardFontSize,
                     clrAqua);


CreateDashboardLabel(
                     DASH_PREFIX+"LOCKEDEQUITY",
                     "Protected Equity : $"+
                     DoubleToString(LockedEquity,2),
                     textX,
                     y+248,
                     DashboardFontSize,
                     clrGold);


CreateDashboardLabel(
                     DASH_PREFIX+"NEXTTARGET",
                     "Next Equity Target : $"+
                     DoubleToString(NextEquityTarget,2),
                     textX,
                     y+270,
                     DashboardFontSize,
                     clrLime);


double ladderProgress=0;

if(NextEquityTarget > state.DayStartBalance)
{
   ladderProgress =
   ((AccountEquity()-state.DayStartBalance) /
   (NextEquityTarget-state.DayStartBalance))*100;

   if(ladderProgress < 0)
      ladderProgress=0;
}


CreateDashboardLabel(
                     DASH_PREFIX+"TARGETPROGRESS",
                     "Target Progress : "+
                     DoubleToString(ladderProgress,1)+"%",
                     textX,
                     y+292,
                     DashboardFontSize,
                     clrWhite);


 

   CreateDashboardLabel(DASH_PREFIX+"ORDERS",
                        "Orders : "+
                        IntegerToString(totalOrders)+"/"+
                        IntegerToString(MaxOpenOrders),
                        textX,
                        y+310,
                        DashboardFontSize,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"BUY",
                        "BUY : "+IntegerToString(buyOrders),
                        textX,
                        y+332,
                        DashboardFontSize,
                        clrDeepSkyBlue);

   CreateDashboardLabel(DASH_PREFIX+"SELL",
                        "SELL : "+IntegerToString(sellOrders),
                        textX+90,
                        y+354,
                        DashboardFontSize,
                        clrTomato);

   CreateDashboardLabel(DASH_PREFIX+"PENDING",
                        "Pending : "+IntegerToString(pendingOrders),
                        textX,
                        y+376,
                        DashboardFontSize,
                        clrGold);

   CreateDashboardLabel(DASH_PREFIX+"LOT",
                        "Current Lot : "+DoubleToString(Lots,2),
                        textX,
                        y+398,
                        DashboardFontSize,
                        clrAqua);

   CreateDashboardLabel(DASH_PREFIX+"LADDER",
                        "L1:$"+DoubleToString(Ladder1ProfitUSD,2)+
                        "  L2:$"+DoubleToString(Ladder2ProfitUSD,2),
                        textX,
                        y+410,
                        DashboardFontSize,
                        clrLimeGreen);

   if(EnableDailyLossProtection)
   {
      CreateDashboardLabel(
         DASH_PREFIX+"CLOSED",
         "Closed Today : "+
         IntegerToString(state.ClosedOrdersToday)+"/"+
         IntegerToString(MinimumClosedOrdersForDailyProtection),
         textX,
         y+420,
         DashboardFontSize,
         state.ClosedOrdersToday>=MinimumClosedOrdersForDailyProtection ?
         clrLime : clrGold);

      CreateDashboardLabel(
         DASH_PREFIX+"PROTECTED",
         "Protected : $"+
         DoubleToString(state.DayProtectedBalance,2),
         textX,
         y+440,
         DashboardFontSize,
         clrGold);
   }

   CreateDashboardLabel(
      DASH_PREFIX+"DETAILTITLE",
      "LIVE ORDERS",
      textX,
      y+460,
      DashboardFontSize,
      clrYellow);

   CreateDashboardLabel(
      DASH_PREFIX+"DETAILS",
      totalOrders>0 ? ordersDetails : "No active orders",
      textX,
      y+480,
      DashboardFontSize,
      totalOrders>0 ? clrWhite : clrSilver);
}

void DeleteOurObjects() {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX, 0) == 0) ObjectDelete(0, name);
   }
}

void DeleteDashboardObjects() {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--) {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, DASH_PREFIX, 0) == 0) ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
//| END OF EA
//+------------------------------------------------------------------+