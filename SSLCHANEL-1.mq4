//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - CONTINUOUS EQUITY LADDER             |
//|                  TWO-STAGE PROFIT LADDER | CONTINUOUS RESET RE-ENTRY      |
//+------------------------------------------------------------------+
#property strict

// ===== INPUT SETTINGS =====
int SSLPeriod = 10;
bool EnableTrading = true;
double Lots = 0.01;
int MaxOpenOrders = 20;
bool CloseOppositeOrdersOnSignal = false;
double closeOppositeLossThreshold = -10.0;
double OriginalStopLossUSD=10;//5;//0.50;//50;
double StopLossUSD =10;//3;//2;//0.50;// 50;

bool DeleteOppositePendingOnSignal = true;
bool EnableProfitReEntryStop = true;
double MinimumClosedProfitUSD = -9;
double ProfitReEntryGapRaw = 5;
double MinimumSameOrderGapRaw = 50;
bool EnableProfitLadder1 = true;



double Ladder1ProfitUSD =0.05;//1;//0.15;//0.25;//0.50;// 0.05;
bool EnableProfitLadder2 = true;
double Ladder1StopMaxPriceUSD = 1;//0.50;//0.20;
double Ladder2ProfitUSD = 0.10;//server api is has errors due to too many orders, so we need to limit the number of orders to 1, and increase the profit target to 0.20






bool EnableRecoveryOrders = true;
double RecoveryTriggerLossUSD = -5.0;
double RecoveryLotMultiplier = 1;
int MaxRecoveryOrders = 1;
double RecoveryBasketProfitUSD = 0.50;
bool EnableDailyLossProtection = true;
bool ResetDailyProtectionEveryDay = false;
bool CloseOpenOrdersOnDailyLoss = true;
int MinimumClosedOrdersForDailyProtection =10;// 100;
bool EnableEquityLadder = true;




double DailyEquityTargetPercent =3;//5;//10;//5;// 10;//2;//3;//1;//3;//10;//Trading continue with 10% profit reccuring
double DailyLossProtectionPercent =20;//50;//20;//10;//20;//100;//50;// 30.0;// Trading stops if equity drops below this percentage of the starting balance for the day
bool EnableDynamicEquityLadder = true;////Trading continue with 10% profit reccuring
double OriginalDailyEquityTargetPercent =5;//10;//5;// 10;//2;//3;//1;//3;//10;//Trading continue with 10% profit reccuring


double OriginalDailyLossProtectionPercent =20;//10;//80;// 30.0;

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

// ===== LEFT LIVE ORDERS DASHBOARD =====
bool ShowLeftLiveOrdersDashboard = true;
int LeftDashboardX = 10;
int LeftDashboardY = 20;
int LeftDashboardWidth = 330;
int LeftDashboardMaxRows = 20;

double OriginalLots = 0.01;
double OriginalLadder1ProfitUSD = 0.05;
double OriginalLadder2ProfitUSD = 0.20;
double OriginalLadder1StopMaxPriceUSD = 0.20;

// ===== STATE STRUCTURE =====
struct DailyProtectionState
  {
   datetime          DayDate;
   double DayStartBalance;
   double DayProtectedBalance;
   int ClosedOrdersToday;
   bool TradingStopped;
   bool Initialized;
  };

// ===== RUNTIME VARIABLES =====
string PREFIX = "SSL_CROSS_";
string DASH_PREFIX = "SSL_DASHBOARD_";
datetime LastProcessedBar = 0;
datetime LastProcessedClosedOrderTime = 0;
datetime DailyProtectionStartTime = 0;
int LastProcessedClosedTicket = -1;
bool StartupSignalProcessed = false;
bool TradeResetThisTick = false;

// Persistent request to start a fresh trade after an Equity Ladder reset.
// It remains TRUE until a market order is successfully opened.
bool EquityResetReEntryPending = false;



//+------------------------------------------------------------------+
void InitializeEquityLadder(DailyProtectionState &state)
  {
   LockedEquity = state.DayStartBalance;

   NextEquityTarget =
      state.DayStartBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| PROCESS STARTUP SIGNAL                                            |
//| IMPORTANT: NEVER CLOSE EXISTING ORDERS ON EA RESTART             |
//+------------------------------------------------------------------+
void ProcessStartupSignal(DailyProtectionState &dailyState)
{
   if(StartupSignalProcessed)
      return;

   if(Bars < SSLPeriod + 20)
      return;

   // Mark processed BEFORE any trading action
   StartupSignalProcessed = true;

   int currentDirection = GetCurrentSSLDirection();

   bool buySignal  = (currentDirection > 0);
   bool sellSignal = (currentDirection < 0);

   Print("==================================================");
   Print("EA STARTUP / RESTART SIGNAL RECOVERY");
   Print("Current SSL Direction: ",
         buySignal ? "BUY" :
         sellSignal ? "SELL" : "NONE");
   Print("Existing EA Orders   : ", GetTotalEAOrders());
   Print("IMPORTANT: EXISTING ORDERS WILL NOT BE CLOSED");
   Print("==================================================");

   //===============================================================
   // BUY
   //===============================================================
   if(buySignal)
   {
      DrawLiveSignal(1, true);

      // IMPORTANT:
      // Do NOT delete opposite pending orders on startup.
      // Do NOT close opposite market orders on startup.

      if(EnableTrading &&
         !IsDailyTradingStopped(dailyState) &&
         GetTotalEAOrders() < MaxOpenOrders)
      {
         OpenBuy();

         Print("EA RESTART -> BUY SIGNAL PROCESSED");
         Print("EA RESTART -> EXISTING ORDERS PRESERVED");
      }
      else
      {
         Print("EA RESTART BUY BLOCKED");
      }

      return;
   }

   //===============================================================
   // SELL
   //===============================================================
   if(sellSignal)
   {
      DrawLiveSignal(1, false);

      // IMPORTANT:
      // Do NOT delete opposite pending orders on startup.
      // Do NOT close opposite market orders on startup.

      if(EnableTrading &&
         !IsDailyTradingStopped(dailyState) &&
         GetTotalEAOrders() < MaxOpenOrders)
      {
         OpenSell();

         Print("EA RESTART -> SELL SIGNAL PROCESSED");
         Print("EA RESTART -> EXISTING ORDERS PRESERVED");
      }
      else
      {
         Print("EA RESTART SELL BLOCKED");
      }

      return;
   }

   Print("EA RESTART -> NO VALID SSL DIRECTION");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EAStartupComplete = false;

int OnInit()
  {
   Ladder1StopMaxPriceUSD=Ladder1ProfitUSD*2;

   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;
   OriginalLadder1StopMaxPriceUSD = Ladder1StopMaxPriceUSD;
   OriginalDailyEquityTargetPercent = DailyEquityTargetPercent;
   OriginalDailyLossProtectionPercent = DailyLossProtectionPercent;




   OriginalStopLossUSD = StopLossUSD;

   Print("========== SSL CHANNEL CROSS EA - FIXED VERSION V1- Final Version ==========");
   Print("Symbol: ", Symbol(), " | Timeframe: ", TimeframeToString(Period()), " | SSL Period: ", SSLPeriod);
   Print("Lots: ", DoubleToString(Lots, 2), " | Max Orders: ", MaxOpenOrders);
   Print("Daily Protection: ", EnableDailyLossProtection ? "ON" : "OFF", " | Ladder 1: ", EnableProfitLadder1 ? "ON" : "OFF");
   Print("Ladder 1 Step: $", DoubleToString(Ladder1ProfitUSD, 2), " | Ladder 2 Step: $", DoubleToString(Ladder2ProfitUSD, 2));
   Print("=========================================================");

   DeleteOurObjects();
   DeleteDashboardObjects();
   DeleteLeftLiveOrdersDashboardObjects();
   if(ShowHistoricalSignals || ShowSSLLines)
      DrawHistoricalSignals();

   DailyProtectionStartTime = TimeCurrent();
   InitializeLastProcessedClosedOrder();
   return INIT_SUCCEEDED;
  }

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
void OnDeinit(const int reason) { DeleteOurObjects(); DeleteDashboardObjects(); DeleteLeftLiveOrdersDashboardObjects(); }
int StartupProtectionTicks = 0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

   TradeResetThisTick = false;

   //===============================================================
   // STARTUP SAFETY
   //===============================================================
   if(StartupProtectionTicks < 1)
   {
      StartupProtectionTicks++;

      EAStartupComplete = true;

      Print("==================================================");
      Print("FIRST TICK AFTER EA START");
      Print("Existing orders will be PRESERVED");
      Print("No startup opposite-order closing allowed");
      Print("==================================================");
   }
// else
// {
//    Ladder1ProfitUSD = OriginalLadder1ProfitUSD;
// }
   static DailyProtectionState dailyState;
   TradeResetThisTick = false;

   CheckRecoveryOrders();
   ManageRecoveryBasket();
   if(!dailyState.Initialized)
      InitializeDailyProtectionState(dailyState);

   ProcessStartupSignal(dailyState);
   UpdateDailyLossProtection(dailyState);
   CheckDynamicEquityLadder(dailyState);

   // Continuous Equity Ladder re-entry.
   // Uses CURRENT SSL direction; no new crossover is required.
   // If an order cannot be opened now, the request remains pending.
   if(EquityResetReEntryPending)
      ProcessEquityResetReEntry(dailyState);

   if(ShowSSLLines)
      UpdateSSLChannelOnTick();
   if(Bars >= SSLPeriod + 20 && GetTotalEAOrders() > 0 && !TradeResetThisTick)
      CheckForProfitableClosedOrder(dailyState);
   if(EnableProfitLadder1 || EnableProfitLadder2)
      ManageProfitLadder();
   if(ShowDashboard)
      UpdateDashboard(dailyState);

   // Separate LEFT dashboard. Existing RIGHT dashboard is untouched.
   if(ShowLeftLiveOrdersDashboard)
      UpdateLeftLiveOrdersDashboard();

   if(Bars < SSLPeriod + 20 || Time[0] == LastProcessedBar)
      return;
   LastProcessedBar = Time[0];

   bool buySignal = IsBuySignal(1);
   bool sellSignal = IsSellSignal(1);

   if(buySignal)
     {
      DrawLiveSignal(1, true);
      Print("SSL CROSS SIGNAL -> BUY");
      if(DeleteOppositePendingOnSignal)
         DeleteOppositePendingOrders(OP_BUY);
      if(CloseOppositeOrdersOnSignal)
         CloseOppositeOrders(OP_BUY);
      if(EnableTrading && !IsDailyTradingStopped(dailyState))
        {
         if(GetTotalEAOrders() < MaxOpenOrders)
            OpenBuy();
         else
            Print("BUY BLOCKED | MAX ORDERS");
        }
      else
         Print("BUY BLOCKED | DAILY PROTECTION");
     }

   if(sellSignal)
     {
      DrawLiveSignal(1, false);
      Print("SSL CROSS SIGNAL -> SELL");
      if(DeleteOppositePendingOnSignal)
         DeleteOppositePendingOrders(OP_SELL);
      if(CloseOppositeOrdersOnSignal)
         CloseOppositeOrders(OP_SELL);
      if(EnableTrading && !IsDailyTradingStopped(dailyState))
        {
         if(GetTotalEAOrders() < MaxOpenOrders)
            OpenSell();
         else
            Print("SELL BLOCKED | MAX ORDERS");
        }
      else
         Print("SELL BLOCKED | DAILY PROTECTION");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasMinimumSameOrderGap(int orderType)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;
      if(MathAbs(currentPrice - OrderOpenPrice()) < MinimumSameOrderGapRaw)
        {
         Print("NEW ", orderType == OP_BUY ? "BUY" : "SELL", " BLOCKED | Order within ", DoubleToString(MathAbs(currentPrice - OrderOpenPrice()), Digits), " raw");
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetOpenPL(int OrderTypeFilter)
  {
   double OpenPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OrderTypeFilter)
         OpenPL += OrderProfit() + OrderSwap() + OrderCommission();
     }
   return OpenPL;
  }
//+------------------------------------------------------------------+
// Find highest profit order and adjust Ladder1
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Open Orders Count by Type                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Open Market Orders Count                                     |
//+------------------------------------------------------------------+
double GetOppositeOrdersLots(int orderType)
{
   // double totalLots = 0.0;
   double totalLots = 0.01;


   int oppositeType =
      (orderType == OP_BUY)
      ? OP_SELL
      : OP_BUY;

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != oppositeType)
         continue;

      totalLots += OrderLots();
   }

   if(totalLots <= 0.0)
      return NormalizeLots(OriginalLots);

   return NormalizeLots(totalLots);
}
//0.03 
void ChangeLots(double OpenPL, string reason, int orderType)
{
   //==================================================
   // MAX LOT LIMIT
   //==================================================
   double MaxRecoveryLot = 0.03;

   //==================================================
   // DEFAULT LOT
   //==================================================
   Lots = NormalizeLots(OriginalLots);

   //==================================================
   // TOTAL OPPOSITE TYPE LOTS
   //==================================================
   double oppositeLots = GetOppositeOrdersLots(orderType);

   //==================================================
   // SSL SIGNAL?
   //==================================================
   bool isSSLSignal =
      (reason == "SSL Long" || reason == "SSL Short");

   //==================================================
   // TYPE 1 - SSL SIGNAL
   //
   // Base Lot =
   // Opposite Total Lots + Original Lot
   //
   // Multiplier:
   // $0     to <$5  = 1X
   // $5     to <$10 = 1X
   // $10    to <$15 = 2X
   // $15    to <$20 = 3X
   //
   // If you want:
   // $0-$4.99 = 1X
   // $5-$9.99 = 2X
   // then use CEIL instead.
   //==================================================
   if(isSSLSignal && oppositeLots > 0.0)
   {
      // Base recovery lot
      double baseLots =
         oppositeLots + OriginalLots;

      baseLots =
         NormalizeLots(baseLots);

      //================================================
      // SSL LOSS MULTIPLIER
      //================================================
      double lossMultiplier1 = 1.0;

      if(OpenPL < 0.0)
      {
         lossMultiplier1 =
            MathFloor(MathAbs(OpenPL) / 10.0);

         // Never allow zero
         if(lossMultiplier1 < 1.0)
            lossMultiplier1 = 1.0;

            lossMultiplier1 = 1.0;




      }

      // Apply multiplier
      Lots =
         NormalizeLots(
            baseLots * lossMultiplier1
         );

      Print("========================================");
      Print("TYPE 1 - SSL RECOVERY");
      Print("Reason          : ", reason);
      Print("Opposite P/L    : $",
            DoubleToString(OpenPL, 2));
      Print("Opposite Lots   : ",
            DoubleToString(oppositeLots, 2));
      Print("Original Lot    : ",
            DoubleToString(OriginalLots, 2));
      Print("Base Lots       : ",
            DoubleToString(baseLots, 2));
      Print("Loss Multiplier : ",
            DoubleToString(lossMultiplier1, 2), "X");
      Print("Calculated Lots : ",
            DoubleToString(Lots, 2));
      Print("========================================");
   }

   //==================================================
   // TYPE 2 - NON SSL SIGNAL
   //
   // Loss multiplier based on $3
   //
   // -0 to -2.99 = 1X
   // -3 to -5.99 = 1X
   // -6 to -8.99 = 2X
   // -9 to -11.99 = 3X
   //==================================================
   else if(!isSSLSignal && oppositeLots > 0.0)
   {
      double lossMultiplier = 1.0;

      if(OpenPL < 0.0)
      {
         lossMultiplier =
            MathFloor(MathAbs(OpenPL) / 5.0);

         // Never allow zero
         if(lossMultiplier < 1.0)
            lossMultiplier = 1.0;
      }

      Lots =
         NormalizeLots(
            OriginalLots * lossMultiplier
         );

      Print("========================================");
      Print("TYPE 2 - NON SSL RECOVERY");
      Print("Reason          : ", reason);
      Print("Opposite P/L    : $",
            DoubleToString(OpenPL, 2));
      Print("Opposite Lots   : ",
            DoubleToString(oppositeLots, 2));
      Print("P/L Multiplier  : ",
            DoubleToString(lossMultiplier, 2), "X");
      Print("Calculated Lots : ",
            DoubleToString(Lots, 2));
      Print("========================================");
   }

   //==================================================
   // NO OPPOSITE ORDERS
   //==================================================
   else
   {
      Lots = NormalizeLots(OriginalLots);

      Print("========================================");
      Print("NO RECOVERY");
      Print("Reason          : ", reason);
      Print("Original Lots   : ",
            DoubleToString(Lots, 2));
      Print("========================================");
   }

   //==================================================
   // HARD MAX LOT = 0.10
   //==================================================
   if(Lots > MaxRecoveryLot)
   {
      Print("MAX LOT LIMIT APPLIED");
      Print("Calculated Lot : ",
            DoubleToString(Lots, 2));
      Print("Maximum Lot    : ",
            DoubleToString(MaxRecoveryLot, 2));

      Lots = NormalizeLots(MaxRecoveryLot);
   }

   //==================================================
   // FINAL NORMALIZATION
   //==================================================
   Lots = NormalizeLots(Lots);

   if(Lots > MaxRecoveryLot)
      Lots = NormalizeLots(MaxRecoveryLot);

   //==================================================
   // ACTUAL LOT MULTIPLIER
   //==================================================
   double lotMultiplier = 1.0;

   if(oppositeLots > 0.0)
   {
      lotMultiplier =
         Lots / oppositeLots;
   }

   if(lotMultiplier < 1.0)
      lotMultiplier = 1.0;

   //==================================================
   // SCALE SL / ORDER LADDER
   // BASED ON ACTUAL NEW LOT
   //==================================================
   StopLossUSD =
      OriginalStopLossUSD *
      Lots * 100;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD *
      Lots * 100;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD *
      Lots * 100;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD *
      Lots * 100;

   //==================================================
   // FINAL DEBUG
   //==================================================
   Print("========================================");
   Print("FINAL LOT CONFIGURATION");
   Print("Reason          : ", reason);
   Print("Open P/L        : $",
         DoubleToString(OpenPL, 2));
   Print("Opposite Lots   : ",
         DoubleToString(oppositeLots, 2));
   Print("New Lots        : ",
         DoubleToString(Lots, 2));
   Print("Maximum Lot     : ",
         DoubleToString(MaxRecoveryLot, 2));
   Print("Lot Multiplier  : ",
         DoubleToString(lotMultiplier, 2), "X");
   Print("Stop Loss       : $",
         DoubleToString(StopLossUSD, 2));
   Print("Ladder 1        : $",
         DoubleToString(Ladder1ProfitUSD, 2));
   Print("Ladder 2        : $",
         DoubleToString(Ladder2ProfitUSD, 2));
   Print("L1 Stop Max     : $",
         DoubleToString(Ladder1StopMaxPriceUSD, 2));
   Print("========================================");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
  {



   if(!EnableRecoveryOrders || GetTotalEAOrders() >= MaxOpenOrders)
      return;
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0 || (OrderType() != OP_BUY && OrderType() != OP_SELL))
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > RecoveryTriggerLossUSD || HasRecoveryOrder(OrderTicket()))
         continue;
      if((OrderType() == OP_BUY && !IsBuySignal(1)) || (OrderType() == OP_SELL && !IsSellSignal(1)))
         continue;

      double lots = NormalizeLots(OrderLots() * RecoveryLotMultiplier);

      if(!IsOneCandleOrderAllowed())
         continue;
      if(OrderType() == OP_BUY)
        {
         // if(!HasMinimumSameOrderGap(OP_BUY)) continue;
         OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrAqua);
        }
      else
        {
         // if(!HasMinimumSameOrderGap(OP_SELL)) continue;
         OrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, 0, clrOrange);
        }

      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasRecoveryOrder(int ParentTicket)
  {
   string txt="RECOVERY_"+IntegerToString(ParentTicket);

   for(int i=OrdersTotal()-1; i>=0; i--)
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
 

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
         else
            if(OrderType()==OP_SELL)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDailyProtectionState(DailyProtectionState &state)
  {
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   state.DayDate = StrToTime(today);
   state.DayStartBalance = AccountBalance();
// state.DayProtectedBalance = state.DayStartBalance;
   state.DayProtectedBalance =
      state.DayStartBalance *
      (1.0 - DailyLossProtectionPercent/100.0);
   state.ClosedOrdersToday = 0;
   state.TradingStopped = false;
   state.Initialized = true;

   Print("==================================================");
   Print("NEW DAILY PROTECTION INITIALIZED");
   Print("Day Start Balance: $", DoubleToString(state.DayStartBalance, 2));
   Print("Min Required Closed Orders: ", MinimumClosedOrdersForDailyProtection);
   Print("Daily Protection: ", DoubleToString(DailyLossProtectionPercent, 2), "%");
   Print("==================================================");
  }

  //+------------------------------------------------------------------+
//| Protected Equity Hit -> Close All -> Reset -> Continue Trading   |
//+------------------------------------------------------------------+
void ResetAfterProtectedEquity(DailyProtectionState &state)
{
   Print("================================================");
   Print("PROTECTED EQUITY HIT");
   Print("Current Equity : $", DoubleToString(AccountEquity(), 2));
   Print("Closing ALL EA orders...");
   Print("================================================");

   // ---------------------------------------------------------------
   // 1. CLOSE ALL EA ORDERS
   // ---------------------------------------------------------------
   int retry = 0;

   while(GetTotalEAOrders() > 0 && retry < 10)
   {
      RefreshRates();

      CloseAllEAOrdersOnDailyLoss();

      Sleep(300);
      retry++;
   }

   // ---------------------------------------------------------------
   // 2. VERIFY ALL ORDERS CLOSED
   // ---------------------------------------------------------------
   if(GetTotalEAOrders() > 0)
   {
      Print("PROTECTED EQUITY RESET FAILED");
      Print("Remaining Orders : ", GetTotalEAOrders());

      // Keep trading stopped if orders could not be closed
      state.TradingStopped = true;
      return;
   }

   RefreshRates();

   // ---------------------------------------------------------------
   // 3. GET REAL BALANCE AFTER CLOSING ORDERS
   // ---------------------------------------------------------------
   double newBalance = AccountBalance();

   Print("ALL EA ORDERS CLOSED");
   Print("New Balance : $", DoubleToString(newBalance, 2));

   // ---------------------------------------------------------------
   // 4. NEW PROTECTED EQUITY / NEW STARTING BALANCE
   // ---------------------------------------------------------------
   state.DayStartBalance   = newBalance;


   state.ClosedOrdersToday = 0;

   // ---------------------------------------------------------------
   // 5. IMPORTANT - ALLOW TRADING AGAIN
   // ---------------------------------------------------------------
   state.TradingStopped = false;

   // ---------------------------------------------------------------
   // 6. RESET DAILY PROTECTION
   // ---------------------------------------------------------------
   DailyProtectionStartTime = TimeCurrent();

   DailyLossProtectionPercent =
      OriginalDailyLossProtectionPercent;

   state.DayProtectedBalance =
      newBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

   // ---------------------------------------------------------------
   // 7. RESET LOT / RECOVERY SETTINGS
   // ---------------------------------------------------------------
   Lots = OriginalLots;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD;






   // ---------------------------------------------------------------
   // 8. RESET EQUITY LADDER
   // ---------------------------------------------------------------
   EquityLadderLevel++;

   if(EquityLadderLevel>1)
         {
             DailyEquityTargetPercent=OriginalDailyEquityTargetPercent/2;
         }
         else
         {
             DailyEquityTargetPercent=OriginalDailyEquityTargetPercent;
            
         }

   LockedEquity = newBalance;

   NextEquityTarget =
      newBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);


   // ---------------------------------------------------------------
   // 9. RESET ORDER-CANDLE CONTROL
   // ---------------------------------------------------------------
   OrderCreatedThisCandle = false;

   // ---------------------------------------------------------------
   // 10. QUEUE TRADING USING CURRENT SSL DIRECTION
   // ---------------------------------------------------------------
   // Uses the same persistent re-entry mechanism as the Equity Ladder.
   TradeResetThisTick = true;
   QueueEquityResetReEntry();

   Print("================================================");
   Print("PROTECTED EQUITY RESET COMPLETE");
   Print("Trading : ENABLED");
   Print("New Start Balance : $",
         DoubleToString(state.DayStartBalance, 2));

   Print("New Protected Equity : $",
         DoubleToString(state.DayProtectedBalance, 2));

   Print("Next Equity Target : $",
         DoubleToString(NextEquityTarget, 2));

   Print("Lots Reset : ",
         DoubleToString(Lots, 2));

   Print("================================================");
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| EQUITY LADDER - CLOSE TARGET, RESET, CONTINUE                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Start trading immediately after an Equity Ladder reset           |
//| Uses the CURRENT SSL direction - no new crossover required       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Queue continuous Equity Ladder re-entry                         |
//+------------------------------------------------------------------+
void QueueEquityResetReEntry()
  {
   EquityResetReEntryPending = true;

   // Allow the first order of the new equity cycle immediately.
   OrderCreatedThisCandle = false;
   LastOrderCandleTime    = 0;

   Print("================================================");
   Print("EQUITY RESET RE-ENTRY QUEUED");
   Print("CURRENT SSL direction will be used");
   Print("NO NEW SSL CROSSOVER REQUIRED");
   Print("================================================");
  }

//+------------------------------------------------------------------+
//| Process continuous Equity Ladder re-entry                       |
//| Keeps retrying until a fresh market order is opened              |
//+------------------------------------------------------------------+
void ProcessEquityResetReEntry(DailyProtectionState &state)
  {
   if(!EquityResetReEntryPending)
      return;

   // Temporary blocks do NOT cancel the request.
   if(!EnableTrading)
      return;

   if(IsDailyTradingStopped(state))
      return;

   if(Bars < SSLPeriod + 20)
      return;

   // If an order is already present, the re-entry succeeded.
   if(GetTotalEAOrders() > 0)
     {
      EquityResetReEntryPending = false;
      return;
     }

   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

   // IMPORTANT: current state, not crossover detection.
   int currentDirection = GetCurrentSSLDirection();

   if(currentDirection > 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime    = 0;

      DrawLiveSignal(1, true);

      int beforeOrders = GetTotalEAOrders();
      OpenBuy();
      int afterOrders = GetTotalEAOrders();

      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;

         Print("================================================");
         Print("EQUITY RESET -> BUY OPENED");
         Print("CURRENT SSL : BUY");
         Print("NO NEW SSL CROSSOVER REQUIRED");
         Print("CONTINUOUS EQUITY LADDER TRADING RESUMED");
         Print("================================================");
        }
      else
        {
         Print("EQUITY RESET -> BUY FAILED/BLOCKED");
         Print("RE-ENTRY REMAINS PENDING - WILL RETRY");
        }
      return;
     }

   if(currentDirection < 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime    = 0;

      DrawLiveSignal(1, false);

      int beforeOrders = GetTotalEAOrders();
      OpenSell();
      int afterOrders = GetTotalEAOrders();

      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;

         Print("================================================");
         Print("EQUITY RESET -> SELL OPENED");
         Print("CURRENT SSL : SELL");
         Print("NO NEW SSL CROSSOVER REQUIRED");
         Print("CONTINUOUS EQUITY LADDER TRADING RESUMED");
         Print("================================================");
        }
      else
        {
         Print("EQUITY RESET -> SELL FAILED/BLOCKED");
         Print("RE-ENTRY REMAINS PENDING - WILL RETRY");
        }
      return;
     }

   // Neutral SSL: keep pending and check again on the next tick.
   Print("EQUITY RESET -> CURRENT SSL = NONE");
   Print("RE-ENTRY REMAINS PENDING");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckDynamicEquityLadder(DailyProtectionState &state)
{
   // Equity ladder disabled
   if(!EnableEquityLadder || !EnableDynamicEquityLadder)
      return;

   // Do not process while daily protection has stopped trading
   if(state.TradingStopped)
      return;

   double equity = AccountEquity();

   // Safety: initialize target if not available
   if(NextEquityTarget <= 0)
   {
      state.DayStartBalance = AccountBalance();

      LockedEquity = state.DayStartBalance;



      
      NextEquityTarget =
         state.DayStartBalance *
         (1.0 + DailyEquityTargetPercent / 100.0);

         

      Print("EQUITY LADDER INITIALIZED");
      Print("Start Balance : $",
            DoubleToString(state.DayStartBalance, 2));
      Print("Next Target   : $",
            DoubleToString(NextEquityTarget, 2));

      return;
   }

   //===============================================================
   // TARGET NOT REACHED
   //===============================================================
   if(equity < NextEquityTarget)
      return;

   Print("================================================");
   Print("EQUITY TARGET REACHED");
   Print("Current Equity : $", DoubleToString(equity, 2));
   Print("Target Equity  : $", DoubleToString(NextEquityTarget, 2));
   Print("Ladder Level   : ", EquityLadderLevel);
   Print("================================================");

   //===============================================================
   // CLOSE ALL EA ORDERS
   //===============================================================
   int retry = 0;

   while(GetTotalEAOrders() > 0 && retry < 10)
   {
      RefreshRates();

      CloseAllEAOrdersOnDailyLoss();

      Sleep(300);

      retry++;
   }

   //===============================================================
   // VERIFY ALL ORDERS ARE CLOSED
   //===============================================================
   if(GetTotalEAOrders() > 0)
   {
      Print("EQUITY LADDER ERROR");
      Print("Unable to close all EA orders.");
      Print("Remaining Orders : ",
            GetTotalEAOrders());

      return;
   }

   //===============================================================
   // IMPORTANT:
   // Get REAL account balance AFTER orders are closed
   //===============================================================
   RefreshRates();

   double newBalance = AccountBalance();

   //===============================================================
   // CALCULATE PROFIT FROM THIS LADDER CYCLE
   //===============================================================
   double cycleProfit =
      newBalance - state.DayStartBalance;

   Print("EQUITY LADDER CYCLE CLOSED");
   Print("Previous Start : $",
         DoubleToString(state.DayStartBalance, 2));
   Print("New Balance    : $",
         DoubleToString(newBalance, 2));
   Print("Cycle Profit   : $",
         DoubleToString(cycleProfit, 2));

   //===============================================================
   // INCREASE LADDER LEVEL
   //===============================================================
   EquityLadderLevel++;

   //===============================================================
   // NEW LADDER START
   //===============================================================
   state.DayStartBalance   = newBalance;

   state.ClosedOrdersToday = 0;

   state.TradingStopped = false;

   DailyProtectionStartTime = TimeCurrent();

   if(EquityLadderLevel>1)
         {
             DailyEquityTargetPercent=OriginalDailyEquityTargetPercent/2;
         }
         else
         {
             DailyEquityTargetPercent=OriginalDailyEquityTargetPercent;
            
         }

   //===============================================================
   // RESET TRADE / RECOVERY STATE
   //===============================================================
   Lots = OriginalLots;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD;






   //===============================================================
   // LOCK CURRENT BALANCE
   //===============================================================
   LockedEquity = newBalance;

   //===============================================================
   // RESET DAILY PROTECTION FROM NEW BALANCE
   //===============================================================
   state.DayProtectedBalance =
      newBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

   //===============================================================
   // CALCULATE NEXT COMPOUNDING TARGET
   //===============================================================
   NextEquityTarget =
      newBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);

   //===============================================================
   // RESET TARGET TIMER
   //===============================================================

   //===============================================================
   // LOG NEW LADDER
   //===============================================================
   Print("================================================");
   Print("NEW EQUITY LADDER STARTED");
   Print("Ladder Level  : ", EquityLadderLevel);
   Print("Start Balance : $",
         DoubleToString(state.DayStartBalance, 2));
   Print("Locked Equity : $",
         DoubleToString(LockedEquity, 2));
   Print("Next Target   : $",
         DoubleToString(NextEquityTarget, 2));
   Print("Cycle Profit  : $",
         DoubleToString(cycleProfit, 2));
   Print("================================================");

   //===============================================================
   // QUEUE CONTINUOUS NEW TRADE
   // Uses CURRENT SSL direction. No new crossover is required.
   //===============================================================
   TradeResetThisTick = true;
   QueueEquityResetReEntry();
} 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDailyLossProtection(DailyProtectionState &state)
  {
   if(!EnableDailyLossProtection)
      return;

   string today = TimeToString(TimeCurrent(), TIME_DATE);
   datetime todayDate = StrToTime(today);

   if(ResetDailyProtectionEveryDay && state.DayDate != todayDate)
     {
      state.DayDate = todayDate;
      state.DayStartBalance = AccountBalance();
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
      Ladder1StopMaxPriceUSD=OriginalLadder1StopMaxPriceUSD;

      InitializeEquityLadder(state);
      EquityLadderLevel = 1;
      LockedEquity = state.DayStartBalance;

      Print("==== NEW DAY - DAILY PROFIT PROTECTION RESET ====");
      Print("Day Start: $", DoubleToString(state.DayStartBalance, 2), " | Protected: $", DoubleToString(state.DayProtectedBalance, 2));
      Print("==================================================");
     }

   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   double currentEquity = AccountEquity();
   double minEquity =
      state.DayStartBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

   // One protection path only. The old EA checked this same condition
   // three times, making the minimum-closed-orders condition ineffective.
   if(currentEquity <= minEquity)
   {
      Print("================================================");
      Print("PROTECTED EQUITY STOP TRIGGERED");
      Print("Start Balance     : $", DoubleToString(state.DayStartBalance, 2));
      Print("Protected Equity  : $", DoubleToString(minEquity, 2));
      Print("Current Equity    : $", DoubleToString(currentEquity, 2));
      Print("Closed Orders     : ", state.ClosedOrdersToday);
      Print("================================================");

      if(CloseOpenOrdersOnDailyLoss)
         ResetAfterProtectedEquity(state);
      else
         state.TradingStopped = true;

      return;
   }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountClosedOrdersSinceInitialization()
  {
   int count = 0;
   if(DailyProtectionStartTime <= 0)
      return 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if((OrderType() != OP_BUY && OrderType() != OP_SELL) || OrderCloseTime() <= DailyProtectionStartTime)
         continue;
      count++;
     }
   return count;
  }

bool IsDailyTradingStopped(DailyProtectionState &state) { return EnableDailyLossProtection && state.TradingStopped; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOppositePendingOrders(int newSignalType)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      bool deleteOrder = ((newSignalType == OP_BUY && orderType == OP_SELLSTOP) || (newSignalType == OP_SELL && orderType == OP_BUYSTOP));

      if(deleteOrder)
        {
         int ticket = OrderTicket();
         ResetLastError();
         if(OrderDelete(ticket, clrYellow))
            Print("OPPOSITE PENDING DELETED | Ticket: ", ticket);
         else
            Print("FAILED TO DELETE | Ticket: ", ticket, " | Error: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newSignalType)
{

   //===============================================================
   // NEVER CLOSE ORDERS DURING EA INITIALIZATION
   //===============================================================
   if(!EAStartupComplete)
   {
      Print("CLOSE OPPOSITE BLOCKED | EA STARTUP NOT COMPLETE");
      return;
   }
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();

      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // Close only opposite orders at or below the configured loss threshold
      if(orderPL > closeOppositeLossThreshold)
         continue;

      if((newSignalType == OP_BUY && orderType == OP_SELL) ||
         (newSignalType == OP_SELL && orderType == OP_BUY))
      {
         RefreshRates();
         ResetLastError();

         bool closed = false;

         if(orderType == OP_SELL)
            closed = OrderClose(ticket, lots, Ask, Slippage, clrRed);
         else if(orderType == OP_BUY)
            closed = OrderClose(ticket, lots, Bid, Slippage, clrBlue);

         if(closed)
            Print("OPPOSITE LOSS CLOSED | Ticket: ", ticket,
                  " | P/L: $", DoubleToString(orderPL,2));
         else
            Print("FAILED CLOSE | Ticket: ", ticket,
                  " | Error: ", GetLastError());
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

   if(GetTotalEAOrders() == 0)
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
 
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSSLChannelOnTick()
  {
   if(!ShowSSLLines || Bars < SSLPeriod + 20)
      return;

   int maxRecentBars = 10;
   if(maxRecentBars > Bars - SSLPeriod - 2)
      maxRecentBars = Bars - SSLPeriod - 2;

   for(int i = maxRecentBars; i >= 0; i--)
     {
      if(i + 1 >= Bars)
         continue;

      double up1, down1, up2, down2;
      int hlv1, hlv2;

      CalculateSSL(i, up1, down1, hlv1);
      CalculateSSL(i + 1, up2, down2, hlv2);

      DrawTrendSegment(PREFIX + "LIVE_UP_" + IntegerToString(i), Time[i], up1, Time[i + 1], up2, SSLUpColor);
      DrawTrendSegment(PREFIX + "LIVE_DOWN_" + IntegerToString(i), Time[i], down1, Time[i + 1], down2, SSLDownColor);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeLastProcessedClosedOrder()
  {
   datetime latestCloseTime = 0;
   int latestTicket = -1;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() > latestCloseTime)
        {
         latestCloseTime = OrderCloseTime();
         latestTicket = OrderTicket();
        }
     }

   LastProcessedClosedOrderTime = latestCloseTime;
   LastProcessedClosedTicket = latestTicket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForProfitableClosedOrder(DailyProtectionState &state)
  {
   datetime latestCloseTime = 0;
   double latestProfit = 0;
   int latestTicket = -1, latestType = -1;
   double latestClosePrice = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() <= latestCloseTime)
         continue;

      latestCloseTime = OrderCloseTime();
      latestTicket = OrderTicket();
      latestType = OrderType();
      latestProfit = OrderProfit() + OrderSwap() + OrderCommission();
      latestClosePrice = OrderClosePrice();
     }

   if(latestTicket < 0)
      return;
   if(latestTicket == LastProcessedClosedTicket && latestCloseTime == LastProcessedClosedOrderTime)
      return;

   LastProcessedClosedTicket = latestTicket;
   LastProcessedClosedOrderTime = latestCloseTime;

   if(latestProfit >= MinimumClosedProfitUSD)
     {
      Print("PROFITABLE ORDER CLOSED | Ticket: ", latestTicket, " | Direction: ", (latestType == OP_BUY ? "BUY" : "SELL"));
      Print("Close: ", DoubleToString(latestClosePrice, Digits), " | Profit: $", DoubleToString(latestProfit, 2));
      if(EnableProfitReEntryStop && !IsDailyTradingStopped(state))
         CreateProfitReEntryStop(latestType, latestClosePrice, state);
      return;
     }

   Print("ORDER CLOSED WITHOUT PROFIT | P/L: $", DoubleToString(latestProfit, 2));
   if(EnableTrading && !IsDailyTradingStopped(state))
     {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(1))
        {
         OpenBuy();
         Print("BUY opened after closed order");
        }
      if(GetTotalSellOrders() == 0 && IsSellSignal(1))
        {
         OpenSell();
         Print("SELL opened after closed order");
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateProfitReEntryStop(int closedOrderType, double closedPrice, DailyProtectionState &state)
  {
   if(!EnableTrading || !EnableProfitReEntryStop || IsDailyTradingStopped(state))
      return;
   if(GetTotalEAOrders() >= MaxOpenOrders)
     {
      Print("PROFIT RE-ENTRY BLOCKED | MAX ORDERS");
      return;
     }

   RefreshRates();

   double entryPrice = (closedOrderType == OP_BUY) ? (closedPrice + ProfitReEntryGapRaw) : (closedPrice - ProfitReEntryGapRaw);
   int pendingType = (closedOrderType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   color orderColor = (closedOrderType == OP_BUY) ? BuyColor : SellColor;
   string orderComment = (closedOrderType == OP_BUY) ? "SSL Profit ReEntry Buy Stop" : "SSL Profit ReEntry Sell Stop";

   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double minimumGap = stopLevel + Point;

   if(pendingType == OP_BUYSTOP && entryPrice < Ask + minimumGap)
      entryPrice = Ask + minimumGap;
   if(pendingType == OP_SELLSTOP && entryPrice > Bid - minimumGap)
      entryPrice = Bid - minimumGap;

   entryPrice = NormalizeDouble(entryPrice, Digits);

   ResetLastError();
   if(pendingType == OP_BUYSTOP)
      ChangeLots(GetOpenPL(OP_SELL), "SSL Profit ReEntry Buy Stop", OP_BUY);
   else
      ChangeLots(GetOpenPL(OP_BUY), "SSL Profit ReEntry Sell Stop", OP_SELL);

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = (pendingType == OP_BUYSTOP) ?
                     (entryPrice - slDistance) :
                     (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);

   int ticket = OrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, 0, orderComment, MagicNumber, 0, orderColor);

   if(ticket < 0)
      Print("PROFIT RE-ENTRY FAILED | ERROR: ", GetLastError());
   else
      Print("PROFIT RE-ENTRY CREATED | Ticket: ", ticket);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalBuyOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalSellOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalEAOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenBuy()
  {



   if(!IsOneCandleOrderAllowed())
      return;

   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_BUY))
      return;
   ChangeLots(GetOpenPL(OP_SELL),"SSL Long",OP_BUY);
   RefreshRates();

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = NormalizeDouble(Ask - slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, stopLoss, 0, "SSL Long", MagicNumber, 0, BuyColor);

   if(ticket < 0)
      Print("BUY FAILED | ERROR: ", GetLastError());
   else
      Print("BUY OPENED | Ticket: ", ticket);
  }
double NormalizeLots(double lots)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0)
      lotStep = minLot > 0.0 ? minLot : 0.01;

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor((lots + 1e-9) / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   int digits = 0;
   double step = lotStep;
   while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-8)
   {
      step *= 10.0;
      digits++;
   }

   return NormalizeDouble(lots, digits);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenSell()
  {
   if(!IsOneCandleOrderAllowed())
      return;
   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_SELL))
      return;
   ChangeLots(GetOpenPL(OP_BUY),"SSL Short",OP_SELL);
   RefreshRates();

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = NormalizeDouble(Bid + slDistance, Digits);
   ResetLastError();
   int ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, stopLoss, 0, "SSL Short", MagicNumber, 0, SellColor);

   if(ticket < 0)
      Print("SELL FAILED | ERROR: ", GetLastError());
   else
      Print("SELL OPENED | Ticket: ", ticket);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePriceDistanceUSD(double usdAmount, double orderLots)
  {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || orderLots <= 0)
      return 0;
   return (usdAmount / (tickValue * orderLots)) * tickSize;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageProfitLadder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      //==================================================
      // FILTER EA ORDERS
      //==================================================
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();

      if(orderType != OP_BUY &&
         orderType != OP_SELL)
         continue;

      //==================================================
      // CURRENT ORDER PROFIT
      //==================================================
      double currentProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();

      if(currentProfit <= 0)
         continue;

      //==================================================
      // CURRENT ORDER LOT
      //==================================================
      double orderLots = OrderLots();

      if(orderLots <= 0)
         continue;

      //==================================================
      // DYNAMIC LADDER VALUES
      // BASED ON CURRENT ORDER LOT
      //==================================================
      double ladder1Profit =
         OriginalLadder1ProfitUSD *
         orderLots * 100.0;

      double ladder2Profit =
         OriginalLadder2ProfitUSD *
         orderLots * 100.0;

      double ladder1StopMaxPrice =
         OriginalLadder1StopMaxPriceUSD *
         orderLots * 100.0;

      double lockedProfit = 0.0;

      //==================================================
      // LADDER 1
      //
      // Example:
      //
      // L1 = $0.10
      //
      // $0.09 -> NO MODIFY
      // $0.10 -> LOCK $0.10
      // $0.15 -> NO MODIFY
      // $0.19 -> NO MODIFY
      // $0.20 -> LOCK $0.20
      // $0.25 -> NO MODIFY
      // $0.30 -> LOCK $0.30
      //==================================================
      if(EnableProfitLadder1 &&
         ladder1Profit > 0 &&
         currentProfit < ladder1StopMaxPrice)
      {
         int ladder1Level =
            (int)MathFloor(
               currentProfit / ladder1Profit
            );

         if(ladder1Level >= 1)
         {
            lockedProfit =
               ladder1Level * ladder1Profit;
         }
      }

      //==================================================
      // LADDER 2
      //
      // Example:
      //
      // L2 = $0.50
      //
      // $0.50 -> first L2 step
      // $1.00 -> second L2 step
      // $1.50 -> third L2 step
      //==================================================
      if(EnableProfitLadder2 &&
         ladder2Profit > 0 &&
         currentProfit >= ladder1StopMaxPrice)
      {
         int ladder2Level =
            (int)MathFloor(
               currentProfit / ladder2Profit
            );

         if(ladder2Level >= 1)
         {
            lockedProfit =
               ladder2Level * ladder2Profit;
         }
      }

      //==================================================
      // NOTHING TO LOCK
      //==================================================
      if(lockedProfit <= 0)
         continue;

      lockedProfit =
         NormalizeDouble(lockedProfit, 2);

      //==================================================
      // TICK INFORMATION
      //==================================================
      double tickValue =
         MarketInfo(Symbol(), MODE_TICKVALUE);

      double tickSize =
         MarketInfo(Symbol(), MODE_TICKSIZE);

      if(tickValue <= 0 ||
         tickSize <= 0)
         continue;

      //==================================================
      // CALCULATE CURRENTLY LOCKED PROFIT FROM SL
      //==================================================
      double existingLockedProfit = 0.0;

      if(OrderStopLoss() > 0)
      {
         double existingPriceDistance = 0.0;

         // BUY
         if(orderType == OP_BUY)
         {
            existingPriceDistance =
               OrderStopLoss() -
               OrderOpenPrice();
         }

         // SELL
         if(orderType == OP_SELL)
         {
            existingPriceDistance =
               OrderOpenPrice() -
               OrderStopLoss();
         }

         if(existingPriceDistance > 0)
         {
            existingLockedProfit =
               (existingPriceDistance / tickSize) *
               tickValue *
               orderLots;

            existingLockedProfit =
               NormalizeDouble(
                  existingLockedProfit,
                  2
               );
         }
      }

      //==================================================
      // DO NOT MODIFY IF CURRENT SL ALREADY LOCKS
      // THIS LADDER LEVEL
      //==================================================
      if(existingLockedProfit >= lockedProfit)
         continue;

      //==================================================
      // CALCULATE REQUIRED PRICE DISTANCE
      // FOR DESIRED LOCKED PROFIT
      //==================================================
      double priceDistance =
         (lockedProfit /
         (tickValue * orderLots)) *
         tickSize;

      if(priceDistance <= 0)
         continue;

      //==================================================
      // BROKER MINIMUM STOP DISTANCE
      //==================================================
      double stopLevel =
         MarketInfo(Symbol(), MODE_STOPLEVEL) *
         Point;

      double newStopLoss = 0.0;

      //==================================================
      // BUY
      //==================================================
      if(orderType == OP_BUY)
      {
         //================================================
         // CALCULATE SL FROM OPEN PRICE
         //================================================
         newStopLoss =
            OrderOpenPrice() +
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         //================================================
         // SL MUST BE BETTER THAN EXISTING SL
         //================================================
         if(OrderStopLoss() > 0 &&
            newStopLoss <= OrderStopLoss())
         {
            continue;
         }

         //================================================
         // BROKER MINIMUM DISTANCE
         //================================================
         if(Bid - newStopLoss < stopLevel)
         {
            newStopLoss =
               Bid - stopLevel;

            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
         }

         //================================================
         // VALIDATE BUY SL
         //================================================
         if(newStopLoss <= 0)
            continue;

         if(newStopLoss >= Bid)
            continue;

         //================================================
         // FINAL DUPLICATE PROTECTION
         //================================================
         if(OrderStopLoss() > 0 &&
            MathAbs(
               newStopLoss -
               OrderStopLoss()
            ) < Point)
         {
            continue;
         }

         //================================================
         // MODIFY BUY
         //================================================
         ResetLastError();

         bool modified =
            OrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrLimeGreen
            );

         if(modified)
         {
            Print(
               "BUY LADDER UPDATED | ",
               "Ticket=", OrderTicket(),
               " | Lots=", DoubleToString(orderLots, 2),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | Old Lock=$",
               DoubleToString(existingLockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits)
            );
         }
         else
         {
            int error =
               GetLastError();

            Print(
               "BUY LADDER MODIFY FAILED | ",
               "Ticket=", OrderTicket(),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits),
               " | Error=",
               error
            );
         }
      }

      //==================================================
      // SELL
      //==================================================
      if(orderType == OP_SELL)
      {
         //================================================
         // CALCULATE SL FROM OPEN PRICE
         //================================================
         newStopLoss =
            OrderOpenPrice() -
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         //================================================
         // SL MUST BE BETTER THAN EXISTING SL
         //================================================
         if(OrderStopLoss() > 0 &&
            newStopLoss >= OrderStopLoss())
         {
            continue;
         }

         //================================================
         // BROKER MINIMUM DISTANCE
         //================================================
         if(newStopLoss - Ask < stopLevel)
         {
            newStopLoss =
               Ask + stopLevel;

            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
         }

         //================================================
         // VALIDATE SELL SL
         //================================================
         if(newStopLoss <= Ask)
            continue;

         //================================================
         // FINAL DUPLICATE PROTECTION
         //================================================
         if(OrderStopLoss() > 0 &&
            MathAbs(
               newStopLoss -
               OrderStopLoss()
            ) < Point)
         {
            continue;
         }

         //================================================
         // MODIFY SELL
         //================================================
         ResetLastError();

         bool modified =
            OrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrTomato
            );

         if(modified)
         {
            Print(
               "SELL LADDER UPDATED | ",
               "Ticket=", OrderTicket(),
               " | Lots=", DoubleToString(orderLots, 2),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | Old Lock=$",
               DoubleToString(existingLockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits)
            );
         }
         else
         {
            int error =
               GetLastError();

            Print(
               "SELL LADDER MODIFY FAILED | ",
               "Ticket=", OrderTicket(),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits),
               " | Error=",
               error
            );
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateSSL(int shift, double &sslUp, double &sslDown, int &hlv)
  {
   int oldest = Bars - SSLPeriod - 2;
   if(oldest < shift)
      oldest = shift;

   int currentHlv = 0;

   for(int i = oldest; i >= shift; i--)
     {
      double smaHigh = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_HIGH, i);
      double smaLow = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_LOW, i);
      double candleClose = Close[i];

      if(candleClose > smaHigh)
         currentHlv = 1;
      else
         if(candleClose < smaLow)
            currentHlv = -1;

      if(i == shift)
        {
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

//+------------------------------------------------------------------+
//| Cached current SSL direction                                    |
//|  1 = BUY, -1 = SELL, 0 = NONE                                  |
//+------------------------------------------------------------------+
int GetCurrentSSLDirection()
{
   static datetime cachedBar = 0;
   static int cachedDirection = 0;

   if(Bars < SSLPeriod + 20)
      return 0;

   if(cachedBar != Time[0])
   {
      double up, down;
      int hlv;
      CalculateSSL(1, up, down, hlv);

      if(up > down)
         cachedDirection = 1;
      else if(up < down)
         cachedDirection = -1;
      else
         cachedDirection = 0;

      cachedBar = Time[0];
   }

   return cachedDirection;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBuySignal(int shift)
  {
   if(shift + 1 >= Bars)
      return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious <= downPrevious && upCurrent > downCurrent);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSellSignal(int shift)
  {
   if(shift + 1 >= Bars)
      return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious >= downPrevious && upCurrent < downCurrent);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignals()
  {
   int barsToProcess = HistoryBarsToDraw;
   if(barsToProcess > Bars - SSLPeriod - 3)
      barsToProcess = Bars - SSLPeriod - 3;
   if(barsToProcess <= 0)
      return;

   if(ShowSSLLines)
     {
      for(int i = barsToProcess; i >= 1; i--)
        {
         double up1, down1, up2, down2;
         int hlv1, hlv2;
         CalculateSSL(i, up1, down1, hlv1);
         CalculateSSL(i - 1, up2, down2, hlv2);
         DrawTrendSegment(PREFIX + "HIST_UP_" + IntegerToString(i), Time[i], up1, Time[i - 1], up2, SSLUpColor);
         DrawTrendSegment(PREFIX + "HIST_DOWN_" + IntegerToString(i), Time[i], down1, Time[i - 1], down2, SSLDownColor);
        }
     }

   if(ShowHistoricalSignals)
     {
      for(int i = barsToProcess; i >= 1; i--)
        {
         if(IsBuySignal(i))
            DrawHistoricalSignal(i, true);
         if(IsSellSignal(i))
            DrawHistoricalSignal(i, false);
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendSegment(string name, datetime time1, double price1, datetime time2, double price2, color lineColor)
  {
   if(price1 <= 0 || price2 <= 0)
      return;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   else
     {
      ObjectMove(0, name, 0, time1, price1);
      ObjectMove(0, name, 1, time2, price2);
     }

   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SSLLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignal(int shift, bool isBuy)
  {
   string type = isBuy ? "BUY" : "SELL";
   string baseName = PREFIX + type + "_" + IntegerToString((int)Time[shift]);
   double price = isBuy ? (Low[shift] - SignalDistancePoints * Point) : (High[shift] + SignalDistancePoints * Point);

   if(ShowSignalArrows)
     {
      string arrowName = baseName + "_ARROW";
      if(ObjectFind(0, arrowName) < 0)
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, Time[shift], price);
      else
         ObjectMove(0, arrowName, 0, Time[shift], price);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, SignalArrowWidth);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
     }

   if(ShowSignalText)
     {
      string textName = baseName + "_TEXT";
      double textPrice = isBuy ? (price - SignalDistancePoints * 0.30 * Point) : (price + SignalDistancePoints * 0.30 * Point);
      if(ObjectFind(0, textName) < 0)
         ObjectCreate(0, textName, OBJ_TEXT, 0, Time[shift], textPrice);
      else
         ObjectMove(0, textName, 0, Time[shift], textPrice);
      ObjectSetString(0, textName, OBJPROP_TEXT, isBuy ? "Long +1" : "Short -1");
      ObjectSetInteger(0, textName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, SignalFontSize);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
     }
  }

void DrawLiveSignal(int shift, bool isBuy) { DrawHistoricalSignal(shift, isBuy); ChartRedraw(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeToString(int timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H4:
         return "H4";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN1";
     }
   return "CURRENT";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardPanel(string name, int x, int y, int width, int height, color background)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, int fontSize, color textColor)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(DailyProtectionState &state)
  {
   int totalOrders=0,buyOrders=0,sellOrders=0,pendingOrders=0;
   double floatingProfit=0,totalSwap=0,totalCommission=0;
   string ordersDetails="";

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int type=OrderType();

      if(type!=OP_BUY && type!=OP_SELL &&
         type!=OP_BUYSTOP && type!=OP_SELLSTOP)
         continue;

      totalOrders++;

      if(type==OP_BUY)
        {
         buyOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
        }
      else
      if(type==OP_SELL)
        {
         sellOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
        }
      else
         pendingOrders++;

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
         line+=" @"+DoubleToString(OrderOpenPrice(),Digits);

      ordersDetails+=line+" | ";
     }

   double netProfit=floatingProfit+totalSwap+totalCommission;

   color pnlColor=
      netProfit>0 ? clrLime :
      netProfit<0 ? clrTomato :
      clrWhite;

   //===============================================================
   // CURRENT SSL DIRECTION
   //===============================================================
   string sslDirection="NONE";
   color sslColor=clrSilver;

   int currentSSLDirection = GetCurrentSSLDirection();
   if(currentSSLDirection > 0)
     {
      sslDirection="BUY";
      sslColor=clrDeepSkyBlue;
     }
   else
   if(currentSSLDirection < 0)
     {
      sslDirection="SELL";
      sslColor=clrTomato;
     }

   //===============================================================
   // STATUS
   //===============================================================
   string statusText="READY - CURRENT SSL "+sslDirection;
   color statusColor=sslColor;

   if(IsDailyTradingStopped(state))
     {
      statusText="TRADING STOPPED";
      statusColor=clrTomato;
     }
   else
   if(EquityResetReEntryPending)
     {
      statusText="EQUITY RESET - WAITING RE-ENTRY";
      statusColor=clrGold;
     }
   else
   if(GetTotalEAOrders()>=MaxOpenOrders)
     {
      statusText="MAX ORDERS REACHED";
      statusColor=clrTomato;
     }
   else
   if(buyOrders>0 && sellOrders==0)
     {
      statusText="BUY RUNNING";
      statusColor=clrDeepSkyBlue;
     }
   else
   if(sellOrders>0 && buyOrders==0)
     {
      statusText="SELL RUNNING";
      statusColor=clrTomato;
     }
   else
   if(buyOrders>0 && sellOrders>0)
     {
      statusText="BUY + SELL";
      statusColor=clrGold;
     }

   //===============================================================
   // EQUITY LADDER PROGRESS
   //===============================================================
   double ladderProgress=0;

   if(NextEquityTarget>state.DayStartBalance)
     {
      ladderProgress=
         ((AccountEquity()-state.DayStartBalance)/
          (NextEquityTarget-state.DayStartBalance))*100.0;

      if(ladderProgress<0)
         ladderProgress=0;

      if(ladderProgress>100)
         ladderProgress=100;
     }

   int x=DashboardRightGap;
   int y=DashboardTopGap;
   int textX=x+10;
   int panelHeight=520;

   CreateDashboardPanel(DASH_PREFIX+"PANEL",
                        x,y,
                        DashboardWidth,
                        panelHeight,
                        clrBlack);

   CreateDashboardPanel(DASH_PREFIX+"HEADER",
                        x,y,
                        DashboardWidth,
                        35,
                        C'30,60,100');

   CreateDashboardLabel(DASH_PREFIX+"TITLE",
                        "SSL CHANNEL EA - VERSION1-FINAL1",
                        textX,
                        y+8,
                        11,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"STATUS",
                        "STATUS : "+statusText,
                        textX,
                        y+48,
                        DashboardFontSize,
                        statusColor);

   CreateDashboardLabel(DASH_PREFIX+"ENTRYMODE",
                        "ENTRY MODE : SSL CROSS + CONTINUOUS RESET RE-ENTRY",
                        textX,
                        y+68,
                        DashboardFontSize,
                        clrAqua);

   CreateDashboardLabel(DASH_PREFIX+"SSL",
                        "CURRENT SSL : "+sslDirection,
                        textX,
                        y+88,
                        DashboardFontSize,
                        sslColor);

   CreateDashboardLabel(DASH_PREFIX+"SYMBOL",
                        "SYMBOL : "+Symbol(),
                        textX,
                        y+108,
                        DashboardFontSize,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"TIMEFRAME",
                        "TIMEFRAME : "+TimeframeToString(Period()),
                        textX,
                        y+128,
                        DashboardFontSize,
                        clrWhite);

   CreateDashboardLabel(DASH_PREFIX+"EQUITY",
                        "EQUITY : $"+DoubleToString(AccountEquity(),2),
                        textX,
                        y+150,
                        DashboardFontSize,
                        clrLime);

   CreateDashboardLabel(DASH_PREFIX+"PNL",
                        "FLOATING P/L : $"+DoubleToString(netProfit,2),
                        textX,
                        y+170,
                        DashboardFontSize,
                        pnlColor);

   CreateDashboardLabel(DASH_PREFIX+"START",
                        "LADDER START : $"+DoubleToString(state.DayStartBalance,2),
                        textX,
                        y+190,
                        DashboardFontSize,
                        clrAqua);

   //===============================================================
   // EQUITY LADDER
   //===============================================================
   CreateDashboardLabel(
      DASH_PREFIX+"LADDERLEVEL",
      "EQUITY LADDER : STEP "+IntegerToString(EquityLadderLevel),
      textX,
      y+214,
      DashboardFontSize,
      clrYellow);

   CreateDashboardLabel(
      DASH_PREFIX+"TARGETPERCENT",
      "TARGET PERCENT : "+DoubleToString(DailyEquityTargetPercent,2)+"%",
      textX,
      y+234,
      DashboardFontSize,
      clrYellow);

   CreateDashboardLabel(
      DASH_PREFIX+"PROTECTED",
      "PROTECTED EQUITY : $"+DoubleToString(state.DayProtectedBalance,2),
      textX,
      y+254,
      DashboardFontSize,
      clrRed);

   CreateDashboardLabel(
      DASH_PREFIX+"NEXTTARGET",
      "NEXT TARGET : $"+DoubleToString(NextEquityTarget,2),
      textX,
      y+274,
      DashboardFontSize,
      clrLime);

   CreateDashboardLabel(
      DASH_PREFIX+"PROGRESS",
      "TARGET PROGRESS : "+DoubleToString(ladderProgress,1)+"%",
      textX,
      y+294,
      DashboardFontSize,
      clrWhite);

   CreateDashboardLabel(
      DASH_PREFIX+"REENTRY",
      "RESET RE-ENTRY : "+(EquityResetReEntryPending ? "PENDING" : "READY"),
      textX,
      y+314,
      DashboardFontSize,
      EquityResetReEntryPending ? clrGold : clrLime);

   //===============================================================
   // ORDERS
   //===============================================================
   CreateDashboardLabel(
      DASH_PREFIX+"ORDERS",
      "ORDERS : "+IntegerToString(totalOrders)+"/"+IntegerToString(MaxOpenOrders),
      textX,
      y+338,
      DashboardFontSize,
      clrWhite);

   CreateDashboardLabel(
      DASH_PREFIX+"BUYSELL",
      "BUY : "+IntegerToString(buyOrders)+
      "     SELL : "+IntegerToString(sellOrders),
      textX,
      y+358,
      DashboardFontSize,
      clrWhite);

   CreateDashboardLabel(
      DASH_PREFIX+"PENDING",
      "PENDING : "+IntegerToString(pendingOrders),
      textX,
      y+378,
      DashboardFontSize,
      clrGold);

   CreateDashboardLabel(
      DASH_PREFIX+"LOT",
      "CURRENT LOT : "+DoubleToString(Lots,2),
      textX,
      y+398,
      DashboardFontSize,
      clrAqua);

   CreateDashboardLabel(
      DASH_PREFIX+"SL",
      "STOP LOSS : $"+DoubleToString(StopLossUSD,2),
      textX,
      y+418,
      DashboardFontSize,
      clrTomato);

   //===============================================================
   // PROFIT LADDER / DAILY
   //===============================================================
   CreateDashboardLabel(
      DASH_PREFIX+"LADDER",
      "ORDER LADDER : L1 $"+DoubleToString(Ladder1ProfitUSD,2)+
      " | L2 $"+DoubleToString(Ladder2ProfitUSD,2),
      textX,
      y+440,
      DashboardFontSize,
      clrLimeGreen);

   if(EnableDailyLossProtection)
     {
      CreateDashboardLabel(
         DASH_PREFIX+"CLOSED",
         "CLOSED TODAY : "+
         IntegerToString(state.ClosedOrdersToday)+"/"+
         IntegerToString(MinimumClosedOrdersForDailyProtection),
         textX,
         y+460,
         DashboardFontSize,
         state.ClosedOrdersToday>=MinimumClosedOrdersForDailyProtection ?
         clrLime : clrGold);
     }

   CreateDashboardLabel(
      DASH_PREFIX+"DETAILTITLE",
      "LIVE ORDERS : "+(totalOrders>0 ? ordersDetails : "NO ACTIVE ORDERS"),
      textX,
      y+482,
      DashboardFontSize,
      totalOrders>0 ? clrWhite : clrSilver);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOurObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteDashboardObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, DASH_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| LEFT LIVE ORDERS DASHBOARD - SEPARATE FROM RIGHT DASHBOARD       |
//+------------------------------------------------------------------+
string LEFT_LIVE_PREFIX = "SSL_LEFT_LIVE_";

void CreateLeftLivePanel(string name,int x,int y,int width,int height,color background)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void CreateLeftLiveLabel(string name,string text,int x,int y,int fontSize,color textColor)
  {
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

void DeleteLeftLiveOrdersDashboardObjects()
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,LEFT_LIVE_PREFIX,0)==0) ObjectDelete(0,name);
     }
  }

void UpdateLeftLiveOrdersDashboard()
  {
   int total=0,buyCount=0,sellCount=0,pendingCount=0;
   double buyLots=0,sellLots=0,netPL=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT) continue;
      total++;
      if(type==OP_BUY)
        {
         buyCount++; buyLots+=OrderLots();
         netPL+=OrderProfit()+OrderSwap()+OrderCommission();
        }
      else if(type==OP_SELL)
        {
         sellCount++; sellLots+=OrderLots();
         netPL+=OrderProfit()+OrderSwap()+OrderCommission();
        }
      else pendingCount++;
     }

   int rows=LeftDashboardMaxRows;
   if(rows<1) rows=1;
   if(rows>30) rows=30;
   int panelHeight=(total>0 ? 105+(rows*19) : 155);
   int x=LeftDashboardX,y=LeftDashboardY,tx=x+12;

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PANEL",x,y,LeftDashboardWidth,panelHeight,C'12,16,22');
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"HEADER",x,y,LeftDashboardWidth,34,C'25,70,115');

   color pnlColor=netPL>0 ? clrLime : netPL<0 ? clrTomato : clrWhite;

   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TITLE","LIVE ORDERS  |  "+Symbol(),tx,y+8,11,clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SUMMARY",
      "ORDERS "+IntegerToString(total)+"/"+IntegerToString(MaxOpenOrders)+
      "   BUY "+IntegerToString(buyCount)+"   SELL "+IntegerToString(sellCount)+
      "   PENDING "+IntegerToString(pendingCount),tx,y+43,8,clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"LOTS",
      "BUY LOT "+DoubleToString(buyLots,2)+"   SELL LOT "+DoubleToString(sellLots,2)+
      "   P/L "+(netPL>=0?"+":"")+DoubleToString(netPL,2),tx,y+61,9,pnlColor);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD",
      "TICKET       TYPE       LOT       OPEN PRICE       P/L",tx,y+82,8,clrSilver);

   for(int r=0;r<30;r++)
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(r),"",tx,y+101+(r*19),8,clrWhite);

   int row=0;
   for(int j=OrdersTotal()-1;j>=0;j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT) continue;
      if(row>=rows) break;

      string typeText=type==OP_BUY ? "BUY" : type==OP_SELL ? "SELL" : type==OP_BUYSTOP ? "BUY ST" : type==OP_SELLSTOP ? "SELL ST" : type==OP_BUYLIMIT ? "BUY LM" : "SELL LM";
      double pl=0;
      if(type==OP_BUY || type==OP_SELL) pl=OrderProfit()+OrderSwap()+OrderCommission();

      string rowText="#"+IntegerToString(OrderTicket())+
         "   "+typeText+
         "   "+DoubleToString(OrderLots(),2)+
         "   "+DoubleToString(OrderOpenPrice(),Digits)+
         "   "+(pl>=0?"+":"")+DoubleToString(pl,2);

      color rowColor=clrWhite;
      if(type==OP_BUY) rowColor=clrDeepSkyBlue;
      if(type==OP_SELL) rowColor=clrTomato;
      if(pl>0) rowColor=clrLime;
      if(pl<0) rowColor=clrOrangeRed;

      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(row),rowText,tx,y+101+(row*19),8,rowColor);
      row++;
     }

   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY",total==0 ? "NO ACTIVE EA ORDERS" : "",tx,y+105,9,clrSilver);
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//| END OF EA
//+------------------------------------------------------------------+