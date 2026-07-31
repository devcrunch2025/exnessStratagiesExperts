//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA                            |
//|                  TWO-STAGE PROFIT LADDER                         |
//|                  DYNAMIC DAILY LOSS PROTECTION                    |
//|                  MINIMUM CLOSED ORDERS PROTECTION                 |
//|                  NO TERMINAL GLOBAL VARIABLES                    |
//|                  OPPOSITE PENDING DELETE ON SIGNAL               |
//+------------------------------------------------------------------+
#property strict


//==================================================================
// INPUTS
//==================================================================


//==================================================================
// SSL SETTINGS
//==================================================================

int SSLPeriod = 10;


//==================================================================
// TRADING
//==================================================================

bool EnableTrading = true;

double Lots = 0.01;

int MaxOpenOrders =10;// 4;


//==================================================================
// CLOSE OPPOSITE ORDERS
//==================================================================

bool CloseOppositeOrdersOnSignal = false;


//==================================================================
// DELETE OPPOSITE PENDING STOP ORDERS
//==================================================================

bool DeleteOppositePendingOnSignal = true;


//==================================================================
// PROFIT RE-ENTRY STOP
//==================================================================

bool EnableProfitReEntryStop = true;

double MinimumClosedProfitUSD =0.01;// -10;//0.01;

double ProfitReEntryGapRaw =20;//5;// 20.0;

//==================================================================
// SAME DIRECTION ORDER GAP
//==================================================================
double MinimumSameOrderGapRaw = 30;//20.0;
//==================================================================
// PROFIT LADDER 1
//==================================================================

bool EnableProfitLadder1 = true;

double Ladder1ProfitUSD =0.20;// 0.10;//0.05;


//==================================================================
// PROFIT LADDER 2
//==================================================================

bool EnableProfitLadder2 = true;

double Ladder1StopMaxPriceUSD = 10;//0.50;//0.50;//1.00;

double Ladder2ProfitUSD =0.50;// 1.00;


//==================================================================
// INITIAL STOP LOSS
//==================================================================

double StopLossUSD = 10;//5;//10;//2;//3;//1.00;

//========================================================
// RECOVERY
//========================================================
bool   EnableRecoveryOrders     = true;
double RecoveryTriggerLossUSD   = -2.0;
double RecoveryLotMultiplier    = 1.0;
int    MaxRecoveryOrders        = 3;
double RecoveryBasketProfitUSD  = 0.50;



//==================================================================
// DAILY PROFIT PROTECTION
//==================================================================

double DailyLossProtectionPercent = 75.0;

bool EnableDailyLossProtection = true;

bool ResetDailyProtectionEveryDay = true;

bool CloseOpenOrdersOnDailyLoss = false;


// Minimum closed market orders required before
// daily profit protection can activate
int MinimumClosedOrdersForDailyProtection =10000;// 50;

//===============================================================
// DAILY EQUITY TARGET
//===============================================================
bool EnableDailyEquityTarget = true;
double DailyEquityTargetPercent = 10.0;
bool CloseOrdersOnDailyEquityTarget = true;


//==================================================================
// ORDER SETTINGS
//==================================================================

int Slippage = 30;

int MagicNumber = 6600123;


//==================================================================
// VISUALS
//==================================================================

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


//==================================================================
// DASHBOARD
//==================================================================

bool ShowDashboard = true;

int DashboardRightGap = 300;

int DashboardTopGap = 20;

int DashboardWidth = 285;

int DashboardHeight = 480;

int DashboardFontSize = 9;


//==================================================================
// LOCAL STATE STRUCTURE
//==================================================================

struct DailyProtectionState
  {
   datetime          DayDate;

   double            DayStartBalance;

   double            DayHighestBalance;

   double            DayProtectedBalance;

   int               ClosedOrdersToday;

   bool              TradingStopped;

   bool              Initialized;
  };


//==================================================================
// RUNTIME VARIABLES
//==================================================================

string PREFIX = "SSL_CROSS_";

string DASH_PREFIX = "SSL_DASHBOARD_";

datetime LastProcessedBar = 0;

datetime LastProcessedClosedOrderTime = 0;

int LastProcessedClosedTicket = -1;


//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

datetime DailyProtectionStartTime = 0;
bool StartupSignalProcessed = false;
//+------------------------------------------------------------------+
//| RECOVER LAST SSL SIGNAL AFTER EA RESTART                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessStartupSignal(
   DailyProtectionState &dailyState
)
  {
   if(
      StartupSignalProcessed
   )
     {
      return;
     }


   if(
      Bars <
      SSLPeriod +
      20
   )
     {
      return;
     }


   StartupSignalProcessed =
      true;


   double upCurrent;

   double downCurrent;

   int hlvCurrent;


   double upPrevious;

   double downPrevious;

   int hlvPrevious;


//===============================================================
// USE THE LAST CLOSED CANDLE
//===============================================================

   CalculateSSL(
      1,

      upCurrent,

      downCurrent,

      hlvCurrent
   );


   CalculateSSL(
      2,

      upPrevious,

      downPrevious,

      hlvPrevious
   );


   bool buySignal =
      upCurrent >
      downCurrent;


   bool sellSignal =
      upCurrent <
      downCurrent;


   Print(
      "=================================================="
   );


   Print(
      "EA RESTART SIGNAL RECOVERY"
   );


   Print(
      "Previous SSL Direction: ",

      buySignal ?
      "BUY" :
      sellSignal ?
      "SELL" :
      "NONE"
   );


   Print(
      "=================================================="
   );


   if(
      buySignal
   )
     {
      DrawLiveSignal(
         1,

         true
      );


      if(
         DeleteOppositePendingOnSignal
      )
        {
         DeleteOppositePendingOrders(
            OP_BUY
         );
        }


      if(
         CloseOppositeOrdersOnSignal
      )
        {
         CloseOppositeOrders(
            OP_BUY
         );
        }


      if(
         EnableTrading &&
         !IsDailyTradingStopped(
            dailyState
         )
      )
        {
         if(
            GetTotalEAOrders() <
            MaxOpenOrders
         )
           {
            OpenBuy();

            Print(
               "EA RESTART -> BUY OPENED USING PREVIOUS SSL SIGNAL"
            );
           }
         else
           {
            Print(
               "EA RESTART BUY BLOCKED | MAX TOTAL ORDERS REACHED"
            );
           }
        }
      else
        {
         Print(
            "EA RESTART BUY BLOCKED | DAILY PROTECTION ACTIVE"
         );
        }
     }


   if(
      sellSignal
   )
     {
      DrawLiveSignal(
         1,

         false
      );


      if(
         DeleteOppositePendingOnSignal
      )
        {
         DeleteOppositePendingOrders(
            OP_SELL
         );
        }


      if(
         CloseOppositeOrdersOnSignal
      )
        {
         CloseOppositeOrders(
            OP_SELL
         );
        }


      if(
         EnableTrading &&
         !IsDailyTradingStopped(
            dailyState
         )
      )
        {
         if(
            GetTotalEAOrders() <
            MaxOpenOrders
         )
           {
            OpenSell();

            Print(
               "EA RESTART -> SELL OPENED USING PREVIOUS SSL SIGNAL"
            );
           }
         else
           {
            Print(
               "EA RESTART SELL BLOCKED | MAX TOTAL ORDERS REACHED"
            );
           }
        }
      else
        {
         Print(
            "EA RESTART SELL BLOCKED | DAILY PROTECTION ACTIVE"
         );
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {



   Print("==================================================");

   Print("SSL CHANNEL CROSS EA INITIALIZED");

   Print("TWO-STAGE PROFIT LADDER VERSION");

   Print("DYNAMIC DAILY PROFIT PROTECTION VERSION");

   Print("MINIMUM CLOSED ORDERS PROTECTION VERSION");

   Print("NO TERMINAL GLOBAL VARIABLES");

   Print("Symbol: ", Symbol());

   Print(
      "Timeframe: ",
      TimeframeToString(Period())
   );

   Print(
      "SSL Period: ",
      SSLPeriod
   );

   Print(
      "Lots: ",
      DoubleToString(
         Lots,
         2
      )
   );

   Print(
      "Max Total Orders: ",
      MaxOpenOrders
   );

   Print(
      "Close Opposite Orders On Signal: ",
      CloseOppositeOrdersOnSignal ?
      "TRUE" :
      "FALSE"
   );

   Print(
      "Delete Opposite Pending On Signal: ",
      DeleteOppositePendingOnSignal ?
      "TRUE" :
      "FALSE"
   );

   Print(
      "Daily Profit Protection: ",
      EnableDailyLossProtection ?
      "ON" :
      "OFF"
   );

   Print(
      "Minimum Closed Orders Required: ",
      MinimumClosedOrdersForDailyProtection
   );

   Print(
      "Daily Profit Protection Percent: ",
      DoubleToString(
         DailyLossProtectionPercent,
         2
      ),
      "%"
   );

   Print(
      "Ladder 1: ",
      EnableProfitLadder1 ?
      "ON" :
      "OFF"
   );

   Print(
      "Ladder 1 Profit Step: $",
      DoubleToString(
         Ladder1ProfitUSD,
         2
      )
   );

   Print(
      "Ladder 2 Activation: $",
      DoubleToString(
         Ladder1StopMaxPriceUSD,
         2
      )
   );

   Print(
      "Ladder 2 Profit Step: $",
      DoubleToString(
         Ladder2ProfitUSD,
         2
      )
   );

   Print(
      "Profit Re-Entry Gap: ",
      DoubleToString(
         ProfitReEntryGapRaw,
         Digits
      ),
      " raw price"
   );

   Print("==================================================");


   DeleteOurObjects();

   DeleteDashboardObjects();


   if(
      ShowHistoricalSignals ||
      ShowSSLLines
   )
     {
      DrawHistoricalSignals();
     }
   DailyProtectionStartTime = TimeCurrent();

   Print(
      "DAILY PROTECTION ORDER COUNT START TIME: ",
      TimeToString(
         DailyProtectionStartTime,
         TIME_DATE | TIME_SECONDS
      )
   );

   InitializeLastProcessedClosedOrder();


   return(
            INIT_SUCCEEDED
         );
  }


//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(
   const int reason
)
  {
   DeleteOurObjects();

   DeleteDashboardObjects();
  }


//+------------------------------------------------------------------+
//| MAIN TICK                                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| CHECK MINIMUM GAP BETWEEN SAME TYPE ORDERS                       |
//+------------------------------------------------------------------+
bool HasMinimumSameOrderGap(int orderType)
  {
   RefreshRates();

   double currentPrice =
      (orderType == OP_BUY) ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      double gap =
         MathAbs(currentPrice - OrderOpenPrice());

      if(gap < MinimumSameOrderGapRaw)
        {
         Print(
            "NEW ",
            orderType == OP_BUY ? "BUY" : "SELL",
            " BLOCKED | Existing order within ",
            DoubleToString(gap, Digits),
            " raw price."
         );

         return false;
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckDailyEquityTarget(DailyProtectionState &state)
  {
   if(!EnableDailyEquityTarget)
      return;

   if(state.TradingStopped)
      return;

   double targetEquity =
      state.DayStartBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);

   if(AccountEquity() >= targetEquity)
     {
      Print("==================================================");
      Print("DAILY EQUITY TARGET REACHED");
      Print("Day Start Balance : ", DoubleToString(state.DayStartBalance,2));
      Print("Current Equity    : ", DoubleToString(AccountEquity(),2));
      Print("Target Equity     : ", DoubleToString(targetEquity,2));
      Print("Trading stopped for today.");
      Print("==================================================");

      state.TradingStopped = true;

      if(CloseOrdersOnDailyEquityTarget)
         CloseAllEAOrdersOnDailyLoss();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   static DailyProtectionState dailyState;
   CheckRecoveryOrders();
   ManageRecoveryBasket();

   if(
      !dailyState.Initialized
   )
     {
      InitializeDailyProtectionState(
         dailyState
      );
     }

//===============================================================
// RECOVER LAST SIGNAL AFTER EA RESTART
//===============================================================

   ProcessStartupSignal(
      dailyState
   );
   UpdateDailyLossProtection(
      dailyState
   );
   CheckDailyEquityTarget(dailyState);

   if(
      ShowSSLLines
   )
     {
      UpdateSSLChannelOnTick();
     }


   if(
      Bars >=
      SSLPeriod +
      20
   )
     {
      CheckForProfitableClosedOrder(
         dailyState
      );
     }


   if(
      EnableProfitLadder1 ||
      EnableProfitLadder2
   )
     {
      ManageProfitLadder();
     }


   if(
      ShowDashboard
   )
     {
      UpdateDashboard(
         dailyState
      );
     }


   if(
      Bars <
      SSLPeriod +
      20
   )
     {
      return;
     }


   if(
      Time[0] ==
      LastProcessedBar
   )
     {
      return;
     }


   LastProcessedBar =
      Time[0];


   bool buySignal =
      IsBuySignal(
         1
      );


   bool sellSignal =
      IsSellSignal(
         1
      );


   if(
      buySignal
   )
     {
      DrawLiveSignal(
         1,
         true
      );


      Print(
         "SSL CROSS SIGNAL -> BUY"
      );


      if(
         DeleteOppositePendingOnSignal
      )
        {
         DeleteOppositePendingOrders(
            OP_BUY
         );
        }


      if(
         CloseOppositeOrdersOnSignal
      )
        {
         CloseOppositeOrders(
            OP_BUY
         );
        }


      if(
         EnableTrading &&
         !IsDailyTradingStopped(
            dailyState
         )
      )
        {
         if(
            GetTotalEAOrders() <
            MaxOpenOrders
         )
           {
            OpenBuy();
           }
         else
           {
            Print(
               "BUY BLOCKED | MAX TOTAL ORDERS REACHED"
            );
           }
        }
      else
        {
         Print(
            "BUY BLOCKED | DAILY PROFIT PROTECTION ACTIVE"
         );
        }
     }


   if(
      sellSignal
   )
     {
      DrawLiveSignal(
         1,
         false
      );


      Print(
         "SSL CROSS SIGNAL -> SELL"
      );


      if(
         DeleteOppositePendingOnSignal
      )
        {
         DeleteOppositePendingOrders(
            OP_SELL
         );
        }


      if(
         CloseOppositeOrdersOnSignal
      )
        {
         CloseOppositeOrders(
            OP_SELL
         );
        }


      if(
         EnableTrading &&
         !IsDailyTradingStopped(
            dailyState
         )
      )
        {
         if(
            GetTotalEAOrders() <
            MaxOpenOrders
         )
           {
            OpenSell();
           }
         else
           {
            Print(
               "SELL BLOCKED | MAX TOTAL ORDERS REACHED"
            );
           }
        }
      else
        {
         Print(
            "SELL BLOCKED | DAILY PROFIT PROTECTION ACTIVE"
         );
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
  {
   if(!EnableRecoveryOrders)
      return;

   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

   RefreshRates();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;

      double profit=
         OrderProfit()+
         OrderSwap()+
         OrderCommission();

      if(profit>RecoveryTriggerLossUSD)
         continue;

      // already recovered?
      if(HasRecoveryOrder(OrderTicket()))
         continue;

      // SSL confirmation
      if(OrderType()==OP_BUY && !IsBuySignal(1))
         continue;

      if(OrderType()==OP_SELL && !IsSellSignal(1))
         continue;

      double lots=
         NormalizeDouble(
            OrderLots()*RecoveryLotMultiplier,
            2);

      if(OrderType()==OP_BUY)
        {
         if(!HasMinimumSameOrderGap(OP_BUY))
            continue;

         OrderSend(Symbol(),
                   OP_BUY,
                   lots,
                   Ask,
                   Slippage,
                   0,
                   0,
                   "RECOVERY_"+IntegerToString(OrderTicket()),
                   MagicNumber,
                   0,
                   clrAqua);
        }
      else
        {
         if(!HasMinimumSameOrderGap(OP_SELL))
            continue;

         OrderSend(Symbol(),
                   OP_SELL,
                   lots,
                   Bid,
                   Slippage,
                   0,
                   0,
                   "RECOVERY_"+IntegerToString(OrderTicket()),
                   MagicNumber,
                   0,
                   clrOrange);
        }
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

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderComment()==txt)
         return(true);
     }

   return(false);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageRecoveryBasket()
  {
   double buyProfit=0;
   double sellProfit=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      double p=
         OrderProfit()+
         OrderSwap()+
         OrderCommission();

      if(OrderType()==OP_BUY)
         buyProfit+=p;

      if(OrderType()==OP_SELL)
         sellProfit+=p;
     }

   if(buyProfit>=RecoveryBasketProfitUSD)
     {
      CloseBasket(OP_BUY);
      if(GetTotalBuyOrders() == 0 && IsBuySignal(1))

        {
         if(IsBuySignal(1))
           {
            if(EnableTrading &&
               HasMinimumSameOrderGap(OP_BUY))
              {
               OpenBuy();
               Print("Recovery basket closed -> New BUY opened using current SSL.");
              }
           }
        }
     }

   if(sellProfit>=RecoveryBasketProfitUSD)
     {
      CloseBasket(OP_SELL);

      if(GetTotalSellOrders() == 0 && IsSellSignal(1))
        {
         if(IsSellSignal(1))
           {
            if(EnableTrading &&
               HasMinimumSameOrderGap(OP_SELL))
              {
               OpenSell();
               Print("Recovery basket closed -> New SELL opened using current SSL.");
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseBasket(int type)
  {
   RefreshRates();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(OrderType()!=type)
         continue;

      if(type==OP_BUY)
         OrderClose(OrderTicket(),
                    OrderLots(),
                    Bid,
                    Slippage,
                    clrRed);

      else
         OrderClose(OrderTicket(),
                    OrderLots(),
                    Ask,
                    Slippage,
                    clrBlue);
     }
  }

//+------------------------------------------------------------------+
//| INITIALIZE DAILY PROTECTION STATE                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDailyProtectionState(
   DailyProtectionState &state
)
  {
   string today =
      TimeToString(
         TimeCurrent(),
         TIME_DATE
      );


   state.DayDate =
      StrToTime(
         today
      );


   state.DayStartBalance =
      AccountBalance();


   state.DayHighestBalance =
      state.DayStartBalance;


   state.DayProtectedBalance =
      state.DayStartBalance;


// state.ClosedOrdersToday =
//    CountTodayClosedEAOrders();

   state.ClosedOrdersToday = 0;


   state.TradingStopped =
      false;


   state.Initialized =
      true;


   Print(
      "=================================================="
   );


   Print(
      "NEW DAILY PROFIT PROTECTION INITIALIZED"
   );


   Print(
      "Day Start Balance: $",
      DoubleToString(
         state.DayStartBalance,
         2
      )
   );


   Print(
      "Closed Orders Today: ",
      state.ClosedOrdersToday
   );


   Print(
      "Minimum Required Closed Orders: ",
      MinimumClosedOrdersForDailyProtection
   );


   Print(
      "Daily Profit Protection: ",
      DoubleToString(
         DailyLossProtectionPercent,
         2
      ),
      "%"
   );


   Print(
      "Initial Protected Balance: $",
      DoubleToString(
         state.DayProtectedBalance,
         2
      )
   );


   Print(
      "=================================================="
   );
  }


//+------------------------------------------------------------------+
//| UPDATE DAILY PROFIT PROTECTION                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDailyLossProtection(
   DailyProtectionState &state
)
  {
   if(
      !EnableDailyLossProtection
   )
     {
      return;
     }


   string today =
      TimeToString(
         TimeCurrent(),
         TIME_DATE
      );


   datetime todayDate =
      StrToTime(
         today
      );


//===============================================================
// NEW BROKER SERVER DAY
//===============================================================

   if(
      ResetDailyProtectionEveryDay &&

      state.DayDate !=
      todayDate
   )
     {
      state.DayDate =
         todayDate;


      state.DayStartBalance =
         AccountBalance();


      state.DayHighestBalance =
         state.DayStartBalance;


      state.DayProtectedBalance =
         state.DayStartBalance;


      state.ClosedOrdersToday =
         0;


      state.TradingStopped =
         false;


      DailyProtectionStartTime =
         TimeCurrent();

      state.TradingStopped =
         false;


      Print(
         "=================================================="
      );


      Print(
         "NEW DAY - DAILY PROFIT PROTECTION RESET"
      );


      Print(
         "New Day Start Balance: $",
         DoubleToString(
            state.DayStartBalance,
            2
         )
      );


      Print(
         "New Protected Balance: $",
         DoubleToString(
            state.DayProtectedBalance,
            2
         )
      );


      Print(
         "Minimum Closed Orders Required: ",
         MinimumClosedOrdersForDailyProtection
      );


      Print(
         "=================================================="
      );
     }


   state.ClosedOrdersToday =
      CountClosedOrdersSinceInitialization();

   double currentBalance =
      AccountBalance();


//===============================================================
// NEW BALANCE HIGH
//===============================================================

   if(
      currentBalance >
      state.DayHighestBalance
   )
     {
      state.DayHighestBalance =
         currentBalance;


      double profitAboveStart =
         state.DayHighestBalance -
         state.DayStartBalance;


      if(
         profitAboveStart >
         0
      )
        {
         double protectedProfit =
            profitAboveStart *
            DailyLossProtectionPercent /
            100.0;


         state.DayProtectedBalance =
            state.DayStartBalance +
            protectedProfit;
        }
      else
        {
         state.DayProtectedBalance =
            state.DayStartBalance;
        }


      Print(
         "DAILY BALANCE HIGH UPDATED"
      );


      Print(
         "New Highest Balance: $",
         DoubleToString(
            state.DayHighestBalance,
            2
         )
      );


      Print(
         "Profit Above Day Start: $",
         DoubleToString(
            profitAboveStart,
            2
         )
      );


      Print(
         "Protected Profit: $",
         DoubleToString(
            state.DayProtectedBalance -
            state.DayStartBalance,
            2
         )
      );


      Print(
         "New Protected Balance: $",
         DoubleToString(
            state.DayProtectedBalance,
            2
         )
      );
     }


//===============================================================
// MINIMUM CLOSED ORDER REQUIREMENT
//===============================================================

   if(
      state.ClosedOrdersToday <
      MinimumClosedOrdersForDailyProtection
   )
     {
      return;
     }


//===============================================================
// CHECK PROTECTED BALANCE
//===============================================================

   if(
      currentBalance <=
      state.DayProtectedBalance
   )
     {
      if(
         !state.TradingStopped
      )
        {
         state.TradingStopped =
            true;


         Print(
            "=================================================="
         );


         Print(
            "DAILY PROFIT PROTECTION ACTIVATED"
         );


         Print(
            "Closed Orders Today: ",
            state.ClosedOrdersToday
         );


         Print(
            "Current Balance: $",
            DoubleToString(
               currentBalance,
               2
            )
         );


         Print(
            "Protected Balance: $",
            DoubleToString(
               state.DayProtectedBalance,
               2
            )
         );


         Print(
            "NEW TRADING STOPPED FOR TODAY"
         );


         Print(
            "=================================================="
         );


         if(
            CloseOpenOrdersOnDailyLoss
         )
           {
            CloseAllEAOrdersOnDailyLoss();
           }
        }
     }
  }


//+------------------------------------------------------------------+
//| COUNT TODAY CLOSED EA ORDERS                                     |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| COUNT CLOSED ORDERS SINCE EA INITIALIZATION                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountClosedOrdersSinceInitialization()
  {
   int count =
      0;


   if(
      DailyProtectionStartTime <=
      0
   )
     {
      return 0;
     }


   for(
      int i =
         OrdersHistoryTotal() - 1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_HISTORY
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      if(
         OrderType() !=
         OP_BUY &&

         OrderType() !=
         OP_SELL
      )
        {
         continue;
        }


      //=============================================================
      // ONLY COUNT ORDERS CLOSED AFTER EA INITIALIZATION
      //=============================================================

      if(
         OrderCloseTime() <=
         DailyProtectionStartTime
      )
        {
         continue;
        }


      count++;
     }


   return count;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountTodayClosedEAOrdersold()
  {
   int count =
      0;


   datetime todayDate =
      StrToTime(
         TimeToString(
            TimeCurrent(),
            TIME_DATE
         )
      );


   for(
      int i =
         OrdersHistoryTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_HISTORY
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      if(
         OrderType() !=
         OP_BUY &&

         OrderType() !=
         OP_SELL
      )
        {
         continue;
        }


      if(
         OrderCloseTime() <
         todayDate
      )
        {
         continue;
        }


      count++;
     }


   return count;
  }


//+------------------------------------------------------------------+
//| IS DAILY TRADING STOPPED                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDailyTradingStopped(
   DailyProtectionState &state
)
  {
   if(
      !EnableDailyLossProtection
   )
     {
      return false;
     }


   return(
            state.TradingStopped
         );
  }


//+------------------------------------------------------------------+
//| DELETE OPPOSITE PENDING ORDERS                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOppositePendingOrders(
   int newSignalType
)
  {
   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int orderType =
         OrderType();


      bool deleteOrder =
         false;


      if(
         newSignalType ==
         OP_BUY &&

         orderType ==
         OP_SELLSTOP
      )
        {
         deleteOrder =
            true;
        }


      if(
         newSignalType ==
         OP_SELL &&

         orderType ==
         OP_BUYSTOP
      )
        {
         deleteOrder =
            true;
        }


      if(
         !deleteOrder
      )
        {
         continue;
        }


      int ticket =
         OrderTicket();


      ResetLastError();


      if(
         OrderDelete(
            ticket,
            clrYellow
         )
      )
        {
         Print(
            "OPPOSITE PENDING ORDER DELETED ON SIGNAL CHANGE | Ticket: ",
            ticket
         );
        }
      else
        {
         Print(
            "FAILED TO DELETE OPPOSITE PENDING ORDER | Ticket: ",
            ticket,
            " | Error: ",
            GetLastError()
         );
        }
     }
  }


//+------------------------------------------------------------------+
//| CLOSE OPPOSITE ORDERS ON SIGNAL                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(
   int newSignalType
)
  {
   RefreshRates();


   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int orderType =
         OrderType();


      if(
         newSignalType ==
         OP_BUY &&

         orderType ==
         OP_SELL
      )
        {
         int ticket =
            OrderTicket();


         double lots =
            OrderLots();


         RefreshRates();


         ResetLastError();


         bool closed =
            OrderClose(
               ticket,
               lots,
               Ask,
               Slippage,
               clrRed
            );


         if(
            closed
         )
           {
            Print(
               "OPPOSITE SELL CLOSED ON BUY SIGNAL | Ticket: ",
               ticket
            );
           }
         else
           {
            Print(
               "FAILED TO CLOSE OPPOSITE SELL | Ticket: ",
               ticket,
               " | Error: ",
               GetLastError()
            );
           }
        }


      if(
         newSignalType ==
         OP_SELL &&

         orderType ==
         OP_BUY
      )
        {
         int ticket =
            OrderTicket();


         double lots =
            OrderLots();


         RefreshRates();


         ResetLastError();


         bool closed =
            OrderClose(
               ticket,
               lots,
               Bid,
               Slippage,
               clrBlue
            );


         if(
            closed
         )
           {
            Print(
               "OPPOSITE BUY CLOSED ON SELL SIGNAL | Ticket: ",
               ticket
            );
           }
         else
           {
            Print(
               "FAILED TO CLOSE OPPOSITE BUY | Ticket: ",
               ticket,
               " | Error: ",
               GetLastError()
            );
           }
        }
     }
  }


//+------------------------------------------------------------------+
//| CLOSE ALL EA ORDERS ON DAILY LOSS                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllEAOrdersOnDailyLoss()
  {
   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int type =
         OrderType();


      int ticket =
         OrderTicket();


      if(
         type ==
         OP_BUY
      )
        {
         RefreshRates();


         ResetLastError();


         OrderClose(
            ticket,
            OrderLots(),
            Bid,
            Slippage,
            clrRed
         );
        }


      if(
         type ==
         OP_SELL
      )
        {
         RefreshRates();


         ResetLastError();


         OrderClose(
            ticket,
            OrderLots(),
            Ask,
            Slippage,
            clrRed
         );
        }


      if(
         type ==
         OP_BUYSTOP ||

         type ==
         OP_SELLSTOP
      )
        {
         ResetLastError();


         OrderDelete(
            ticket,
            clrRed
         );
        }
     }
  }


//+------------------------------------------------------------------+
//| UPDATE SSL CHANNEL ON EVERY TICK                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSSLChannelOnTick()
  {
   if(
      !ShowSSLLines
   )
     {
      return;
     }


   if(
      Bars <
      SSLPeriod +
      20
   )
     {
      return;
     }


   int maxRecentBars =
      10;


   if(
      maxRecentBars >
      Bars -
      SSLPeriod -
      2
   )
     {
      maxRecentBars =
         Bars -
         SSLPeriod -
         2;
     }


   for(
      int i =
         maxRecentBars;

      i >=
      0;

      i--
   )
     {
      if(
         i + 1 >=
         Bars
      )
        {
         continue;
        }


      double up1;

      double down1;

      int hlv1;


      double up2;

      double down2;

      int hlv2;


      CalculateSSL(
         i,
         up1,
         down1,
         hlv1
      );


      CalculateSSL(
         i + 1,
         up2,
         down2,
         hlv2
      );


      DrawTrendSegment(
         PREFIX +
         "LIVE_UP_" +
         IntegerToString(
            i
         ),

         Time[i],

         up1,

         Time[i + 1],

         up2,

         SSLUpColor
      );


      DrawTrendSegment(
         PREFIX +
         "LIVE_DOWN_" +
         IntegerToString(
            i
         ),

         Time[i],

         down1,

         Time[i + 1],

         down2,

         SSLDownColor
      );
     }


   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| INITIALIZE CLOSED ORDER TRACKING                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeLastProcessedClosedOrder()
  {
   datetime latestCloseTime =
      0;


   int latestTicket =
      -1;


   for(
      int i =
         OrdersHistoryTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_HISTORY
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      if(
         OrderType() !=
         OP_BUY &&

         OrderType() !=
         OP_SELL
      )
        {
         continue;
        }


      if(
         OrderCloseTime() >
         latestCloseTime
      )
        {
         latestCloseTime =
            OrderCloseTime();


         latestTicket =
            OrderTicket();
        }
     }


   LastProcessedClosedOrderTime =
      latestCloseTime;


   LastProcessedClosedTicket =
      latestTicket;
  }


//+------------------------------------------------------------------+
//| CHECK PROFITABLE CLOSED ORDER                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForProfitableClosedOrder(
   DailyProtectionState &state
)
  {
   datetime latestCloseTime =
      0;


   double latestProfit =
      0;


   int latestTicket =
      -1;


   int latestType =
      -1;


   double latestClosePrice =
      0;


   for(
      int i =
         OrdersHistoryTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_HISTORY
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      if(
         OrderType() !=
         OP_BUY &&

         OrderType() !=
         OP_SELL
      )
        {
         continue;
        }


      if(
         OrderCloseTime() <=
         latestCloseTime
      )
        {
         continue;
        }


      latestCloseTime =
         OrderCloseTime();


      latestTicket =
         OrderTicket();


      latestType =
         OrderType();


      latestProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();


      latestClosePrice =
         OrderClosePrice();
     }


   if(
      latestTicket <
      0
   )
     {
      return;
     }


   if(
      latestTicket ==
      LastProcessedClosedTicket &&

      latestCloseTime ==
      LastProcessedClosedOrderTime
   )
     {
      return;
     }


   LastProcessedClosedTicket =
      latestTicket;


   LastProcessedClosedOrderTime =
      latestCloseTime;


   if(
      latestProfit >=
      MinimumClosedProfitUSD
   )
     {
      Print(
         "=================================================="
      );


      Print(
         "PROFITABLE ORDER CLOSED"
      );


      Print(
         "Ticket: ",
         latestTicket
      );


      Print(
         "Direction: ",

         latestType ==
         OP_BUY ?
         "BUY" :
         "SELL"
      );


      Print(
         "Close Price: ",

         DoubleToString(
            latestClosePrice,
            Digits
         )
      );


      Print(
         "Profit: $",

         DoubleToString(
            latestProfit,
            2
         )
      );


      if(
         EnableProfitReEntryStop &&

         !IsDailyTradingStopped(
            state
         )
      )
        {
         CreateProfitReEntryStop(
            latestType,
            latestClosePrice,
            state
         );
        }


      Print(
         "=================================================="
      );


      return;
     }

// Order closed without required profit
Print(
   "ORDER CLOSED WITHOUT REQUIRED PROFIT | P/L: $",
   DoubleToString(latestProfit, 2)
);

// Open new order based on current SSL direction
if(EnableTrading &&
   !IsDailyTradingStopped(state))
{
   if(GetTotalBuyOrders() == 0 &&
      IsBuySignal(1))
   {
      OpenBuy();
      Print("BUY opened after closed order using current SSL.");
   }

   if(GetTotalSellOrders() == 0 &&
      IsSellSignal(1))
   {
      OpenSell();
      Print("SELL opened after closed order using current SSL.");
   }
}

  }


//+------------------------------------------------------------------+
//| CREATE PROFIT RE-ENTRY STOP                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateProfitReEntryStop(
   int closedOrderType,

   double closedPrice,

   DailyProtectionState &state
)
  {
   if(
      !EnableTrading
   )
     {
      return;
     }


   if(
      !EnableProfitReEntryStop
   )
     {
      return;
     }


   if(
      IsDailyTradingStopped(
         state
      )
   )
     {
      return;
     }


   if(
      GetTotalEAOrders() >=
      MaxOpenOrders
   )
     {
      Print(
         "PROFIT RE-ENTRY STOP BLOCKED | MAX ORDERS"
      );


      return;
     }


   RefreshRates();


   double entryPrice =
      0;


   int pendingType =
      -1;


   color orderColor;


   string orderComment;


   if(
      closedOrderType ==
      OP_BUY
   )
     {
      entryPrice =
         closedPrice +
         ProfitReEntryGapRaw;


      pendingType =
         OP_BUYSTOP;


      orderColor =
         BuyColor;


      orderComment =
         "SSL Profit ReEntry Buy Stop";
     }
   else
      if(
         closedOrderType ==
         OP_SELL
      )
        {
         entryPrice =
            closedPrice -
            ProfitReEntryGapRaw;


         pendingType =
            OP_SELLSTOP;


         orderColor =
            SellColor;


         orderComment =
            "SSL Profit ReEntry Sell Stop";
        }
      else
        {
         return;
        }


   double stopLevel =
      MarketInfo(
         Symbol(),
         MODE_STOPLEVEL
      )
      *
      Point;


   double minimumGap =
      stopLevel +
      Point;


   if(
      pendingType ==
      OP_BUYSTOP
   )
     {
      if(
         entryPrice <
         Ask +
         minimumGap
      )
        {
         entryPrice =
            Ask +
            minimumGap;
        }
     }


   if(
      pendingType ==
      OP_SELLSTOP
   )
     {
      if(
         entryPrice >
         Bid -
         minimumGap
      )
        {
         entryPrice =
            Bid -
            minimumGap;
        }
     }


   entryPrice =
      NormalizeDouble(
         entryPrice,
         Digits
      );


   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );


   if(
      slDistance <=
      0
   )
     {
      return;
     }


   double stopLoss;


   if(
      pendingType ==
      OP_BUYSTOP
   )
     {
      stopLoss =
         entryPrice -
         slDistance;
     }
   else
     {
      stopLoss =
         entryPrice +
         slDistance;
     }


   stopLoss =
      NormalizeDouble(
         stopLoss,
         Digits
      );


   ResetLastError();


   int ticket =
      OrderSend(
         Symbol(),
         pendingType,
         Lots,
         entryPrice,
         Slippage,
         stopLoss,
         0,
         orderComment,
         MagicNumber,
         0,
         orderColor
      );


   if(
      ticket <
      0
   )
     {
      Print(
         "PROFIT RE-ENTRY STOP FAILED | ERROR: ",
         GetLastError()
      );
     }
   else
     {
      Print(
         "PROFIT RE-ENTRY STOP CREATED | Ticket: ",
         ticket
      );
     }
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

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
         count++;
     }

   return(count);
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

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_SELL)
         count++;
     }

   return(count);
  }
//+------------------------------------------------------------------+
//| TOTAL EA ORDERS                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalEAOrders()
  {
   int count =
      0;


   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int type =
         OrderType();


      if(
         type ==
         OP_BUY ||

         type ==
         OP_SELL ||

         type ==
         OP_BUYSTOP ||

         type ==
         OP_SELLSTOP
      )
        {
         count++;
        }
     }


   return count;
  }


//+------------------------------------------------------------------+
//| OPEN BUY                                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenBuy()
  {
   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

   if(!HasMinimumSameOrderGap(OP_BUY))
      return;


   RefreshRates();


   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );


   if(
      slDistance <=
      0
   )
     {
      return;
     }


   double stopLoss =
      NormalizeDouble(
         Ask -
         slDistance,
         Digits
      );


   ResetLastError();


   int ticket =
      OrderSend(
         Symbol(),

         OP_BUY,

         Lots,

         Ask,

         Slippage,

         stopLoss,

         0,

         "SSL Long",

         MagicNumber,

         0,

         BuyColor
      );


   if(
      ticket <
      0
   )
     {
      Print(
         "BUY FAILED | ERROR: ",
         GetLastError()
      );
     }
   else
     {
      Print(
         "BUY OPENED | Ticket: ",
         ticket
      );
     }
  }


//+------------------------------------------------------------------+
//| OPEN SELL                                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenSell()
  {
   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

   if(!HasMinimumSameOrderGap(OP_SELL))
      return;


   RefreshRates();


   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );


   if(
      slDistance <=
      0
   )
     {
      return;
     }


   double stopLoss =
      NormalizeDouble(
         Bid +
         slDistance,
         Digits
      );


   ResetLastError();


   int ticket =
      OrderSend(
         Symbol(),

         OP_SELL,

         Lots,

         Bid,

         Slippage,

         stopLoss,

         0,

         "SSL Short",

         MagicNumber,

         0,

         SellColor
      );


   if(
      ticket <
      0
   )
     {
      Print(
         "SELL FAILED | ERROR: ",
         GetLastError()
      );
     }
   else
     {
      Print(
         "SELL OPENED | Ticket: ",
         ticket
      );
     }
  }


//+------------------------------------------------------------------+
//| CALCULATE USD PRICE DISTANCE                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePriceDistanceUSD(
   double usdAmount,

   double orderLots
)
  {
   double tickValue =
      MarketInfo(
         Symbol(),
         MODE_TICKVALUE
      );


   double tickSize =
      MarketInfo(
         Symbol(),
         MODE_TICKSIZE
      );


   if(
      tickValue <=
      0 ||

      tickSize <=
      0 ||

      orderLots <=
      0
   )
     {
      return 0;
     }


   return(
            usdAmount /
            (
               tickValue *
               orderLots
            )
         )
         *
         tickSize;
  }


//+------------------------------------------------------------------+
//| TWO-STAGE PROFIT LADDER                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageProfitLadder()
  {
   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int orderType =
         OrderType();


      if(
         orderType !=
         OP_BUY &&

         orderType !=
         OP_SELL
      )
        {
         continue;
        }


      double currentProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();


      if(
         currentProfit <=
         0
      )
        {
         continue;
        }


      double lockedProfit =
         0;


      if(
         EnableProfitLadder1 &&

         Ladder1ProfitUSD >
         0 &&

         currentProfit <
         Ladder1StopMaxPriceUSD
      )
        {
         int ladder1Level =
            (int)MathFloor(
               currentProfit /
               Ladder1ProfitUSD
            );


         if(
            ladder1Level >=
            2
         )
           {
            lockedProfit =
               (
                  ladder1Level -
                  1
               )
               *
               Ladder1ProfitUSD;
           }
        }


      if(
         EnableProfitLadder2 &&

         Ladder2ProfitUSD >
         0 &&

         currentProfit >=
         Ladder1StopMaxPriceUSD
      )
        {
         int ladder2Level =
            (int)MathFloor(
               currentProfit /
               Ladder2ProfitUSD
            );


         if(
            ladder2Level >=
            2
         )
           {
            lockedProfit =
               (
                  ladder2Level -
                  1
               )
               *
               Ladder2ProfitUSD;
           }
        }


      if(
         lockedProfit <=
         0
      )
        {
         continue;
        }


      lockedProfit =
         NormalizeDouble(
            lockedProfit,
            2
         );


      double tickValue =
         MarketInfo(
            Symbol(),
            MODE_TICKVALUE
         );


      double tickSize =
         MarketInfo(
            Symbol(),
            MODE_TICKSIZE
         );


      if(
         tickValue <=
         0 ||

         tickSize <=
         0
      )
        {
         continue;
        }


      double priceDistance =
         (
            lockedProfit /
            (
               tickValue *
               OrderLots()
            )
         )
         *
         tickSize;


      double stopLevel =
         MarketInfo(
            Symbol(),
            MODE_STOPLEVEL
         )
         *
         Point;


      double newStopLoss;


      if(
         orderType ==
         OP_BUY
      )
        {
         newStopLoss =
            OrderOpenPrice() +
            priceDistance;


         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );


         if(
            OrderStopLoss() >
            0 &&

            newStopLoss <=
            OrderStopLoss()
         )
           {
            continue;
           }


         if(
            Bid -
            newStopLoss <
            stopLevel
         )
           {
            newStopLoss =
               NormalizeDouble(
                  Bid -
                  stopLevel,
                  Digits
               );
           }


         if(
            newStopLoss >
            0 &&

            newStopLoss <
            Bid
         )
           {
            ResetLastError();


            if(
               OrderModify(
                  OrderTicket(),

                  OrderOpenPrice(),

                  newStopLoss,

                  OrderTakeProfit(),

                  0,

                  clrLimeGreen
               )
            )
              {
               Print(
                  "BUY PROFIT LADDER | ",

                  "Floating Profit: $",

                  DoubleToString(
                     currentProfit,
                     2
                  ),

                  " | Locked: $",

                  DoubleToString(
                     lockedProfit,
                     2
                  )
               );
              }
           }
        }


      if(
         orderType ==
         OP_SELL
      )
        {
         newStopLoss =
            OrderOpenPrice() -
            priceDistance;


         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );


         if(
            OrderStopLoss() >
            0 &&

            newStopLoss >=
            OrderStopLoss()
         )
           {
            continue;
           }


         if(
            newStopLoss -
            Ask <
            stopLevel
         )
           {
            newStopLoss =
               NormalizeDouble(
                  Ask +
                  stopLevel,
                  Digits
               );
           }


         if(
            newStopLoss >
            Ask
         )
           {
            ResetLastError();


            if(
               OrderModify(
                  OrderTicket(),

                  OrderOpenPrice(),

                  newStopLoss,

                  OrderTakeProfit(),

                  0,

                  clrTomato
               )
            )
              {
               Print(
                  "SELL PROFIT LADDER | ",

                  "Floating Profit: $",

                  DoubleToString(
                     currentProfit,
                     2
                  ),

                  " | Locked: $",

                  DoubleToString(
                     lockedProfit,
                     2
                  )
               );
              }
           }
        }
     }
  }


//+------------------------------------------------------------------+
//| CALCULATE SSL                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateSSL(
   int shift,

   double &sslUp,

   double &sslDown,

   int &hlv
)
  {
   int oldest =
      Bars -
      SSLPeriod -
      2;


   if(
      oldest <
      shift
   )
     {
      oldest =
         shift;
     }


   int currentHlv =
      0;


   for(
      int i =
         oldest;

      i >=
      shift;

      i--
   )
     {
      double smaHigh =
         iMA(
            Symbol(),

            Period(),

            SSLPeriod,

            0,

            MODE_SMA,

            PRICE_HIGH,

            i
         );


      double smaLow =
         iMA(
            Symbol(),

            Period(),

            SSLPeriod,

            0,

            MODE_SMA,

            PRICE_LOW,

            i
         );


      double candleClose =
         Close[i];


      if(
         candleClose >
         smaHigh
      )
        {
         currentHlv =
            1;
        }
      else
         if(
            candleClose <
            smaLow
         )
           {
            currentHlv =
               -1;
           }


      if(
         i ==
         shift
      )
        {
         hlv =
            currentHlv;


         if(
            currentHlv <
            0
         )
           {
            sslDown =
               smaHigh;


            sslUp =
               smaLow;
           }
         else
           {
            sslDown =
               smaLow;


            sslUp =
               smaHigh;
           }


         return;
        }
     }


   hlv =
      currentHlv;


   sslUp =
      0;


   sslDown =
      0;
  }


//+------------------------------------------------------------------+
//| BUY SIGNAL                                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBuySignal(
   int shift
)
  {
   if(
      shift + 1 >=
      Bars
   )
     {
      return false;
     }


   double upCurrent;

   double downCurrent;

   int hlvCurrent;


   double upPrevious;

   double downPrevious;

   int hlvPrevious;


   CalculateSSL(
      shift,

      upCurrent,

      downCurrent,

      hlvCurrent
   );


   CalculateSSL(
      shift + 1,

      upPrevious,

      downPrevious,

      hlvPrevious
   );


   return(
            upPrevious <=
            downPrevious &&

            upCurrent >
            downCurrent
         );
  }


//+------------------------------------------------------------------+
//| SELL SIGNAL                                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSellSignal(
   int shift
)
  {
   if(
      shift + 1 >=
      Bars
   )
     {
      return false;
     }


   double upCurrent;

   double downCurrent;

   int hlvCurrent;


   double upPrevious;

   double downPrevious;

   int hlvPrevious;


   CalculateSSL(
      shift,

      upCurrent,

      downCurrent,

      hlvCurrent
   );


   CalculateSSL(
      shift + 1,

      upPrevious,

      downPrevious,

      hlvPrevious
   );


   return(
            upPrevious >=
            downPrevious &&

            upCurrent <
            downCurrent
         );
  }


//+------------------------------------------------------------------+
//| DRAW HISTORICAL SIGNALS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignals()
  {
   int barsToProcess =
      HistoryBarsToDraw;


   if(
      barsToProcess >
      Bars -
      SSLPeriod -
      3
   )
     {
      barsToProcess =
         Bars -
         SSLPeriod -
         3;
     }


   if(
      barsToProcess <=
      0
   )
     {
      return;
     }


   if(
      ShowSSLLines
   )
     {
      for(
         int i =
            barsToProcess;

         i >=
         1;

         i--
      )
        {
         double up1;

         double down1;

         int hlv1;


         double up2;

         double down2;

         int hlv2;


         CalculateSSL(
            i,

            up1,

            down1,

            hlv1
         );


         CalculateSSL(
            i - 1,

            up2,

            down2,

            hlv2
         );


         DrawTrendSegment(
            PREFIX +
            "HIST_UP_" +
            IntegerToString(
               i
            ),

            Time[i],

            up1,

            Time[i - 1],

            up2,

            SSLUpColor
         );


         DrawTrendSegment(
            PREFIX +
            "HIST_DOWN_" +
            IntegerToString(
               i
            ),

            Time[i],

            down1,

            Time[i - 1],

            down2,

            SSLDownColor
         );
        }
     }


   if(
      ShowHistoricalSignals
   )
     {
      for(
         int i =
            barsToProcess;

         i >=
         1;

         i--
      )
        {
         if(
            IsBuySignal(
               i
            )
         )
           {
            DrawHistoricalSignal(
               i,

               true
            );
           }


         if(
            IsSellSignal(
               i
            )
         )
           {
            DrawHistoricalSignal(
               i,

               false
            );
           }
        }
     }


   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| DRAW TREND SEGMENT                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendSegment(
   string name,

   datetime time1,

   double price1,

   datetime time2,

   double price2,

   color lineColor
)
  {
   if(
      price1 <=
      0 ||

      price2 <=
      0
   )
     {
      return;
     }


   if(
      ObjectFind(
         0,

         name
      ) <
      0
   )
     {
      ObjectCreate(
         0,

         name,

         OBJ_TREND,

         0,

         time1,

         price1,

         time2,

         price2
      );
     }
   else
     {
      ObjectMove(
         0,

         name,

         0,

         time1,

         price1
      );


      ObjectMove(
         0,

         name,

         1,

         time2,

         price2
      );
     }


   ObjectSetInteger(
      0,

      name,

      OBJPROP_COLOR,

      lineColor
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_WIDTH,

      SSLLineWidth
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_RAY_RIGHT,

      false
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_BACK,

      false
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_SELECTABLE,

      false
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_HIDDEN,

      true
   );
  }


//+------------------------------------------------------------------+
//| DRAW SIGNAL                                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignal(
   int shift,

   bool isBuy
)
  {
   string type =
      isBuy ?
      "BUY" :
      "SELL";


   string baseName =
      PREFIX +
      type +
      "_" +
      IntegerToString(
         (int)Time[shift]
      );


   double price;


   if(
      isBuy
   )
     {
      price =
         Low[shift] -
         SignalDistancePoints *
         Point;
     }
   else
     {
      price =
         High[shift] +
         SignalDistancePoints *
         Point;
     }


   if(
      ShowSignalArrows
   )
     {
      string arrowName =
         baseName +
         "_ARROW";


      if(
         ObjectFind(
            0,

            arrowName
         ) <
         0
      )
        {
         ObjectCreate(
            0,

            arrowName,

            OBJ_ARROW,

            0,

            Time[shift],

            price
         );
        }


      ObjectMove(
         0,

         arrowName,

         0,

         Time[shift],

         price
      );


      ObjectSetInteger(
         0,

         arrowName,

         OBJPROP_ARROWCODE,

         isBuy ?
         233 :
         234
      );


      ObjectSetInteger(
         0,

         arrowName,

         OBJPROP_COLOR,

         isBuy ?
         BuyColor :
         SellColor
      );


      ObjectSetInteger(
         0,

         arrowName,

         OBJPROP_WIDTH,

         SignalArrowWidth
      );


      ObjectSetInteger(
         0,

         arrowName,

         OBJPROP_SELECTABLE,

         false
      );
     }


   if(
      ShowSignalText
   )
     {
      string textName =
         baseName +
         "_TEXT";


      double textPrice;


      if(
         isBuy
      )
        {
         textPrice =
            price -
            SignalDistancePoints *
            0.30 *
            Point;
        }
      else
        {
         textPrice =
            price +
            SignalDistancePoints *
            0.30 *
            Point;
        }


      if(
         ObjectFind(
            0,

            textName
         ) <
         0
      )
        {
         ObjectCreate(
            0,

            textName,

            OBJ_TEXT,

            0,

            Time[shift],

            textPrice
         );
        }


      ObjectMove(
         0,

         textName,

         0,

         Time[shift],

         textPrice
      );


      ObjectSetString(
         0,

         textName,

         OBJPROP_TEXT,

         isBuy ?
         "Long +1" :
         "Short -1"
      );


      ObjectSetInteger(
         0,

         textName,

         OBJPROP_COLOR,

         isBuy ?
         BuyColor :
         SellColor
      );


      ObjectSetInteger(
         0,

         textName,

         OBJPROP_FONTSIZE,

         SignalFontSize
      );


      ObjectSetString(
         0,

         textName,

         OBJPROP_FONT,

         "Arial"
      );


      ObjectSetInteger(
         0,

         textName,

         OBJPROP_SELECTABLE,

         false
      );
     }
  }


//+------------------------------------------------------------------+
//| DRAW LIVE SIGNAL                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLiveSignal(
   int shift,

   bool isBuy
)
  {
   DrawHistoricalSignal(
      shift,

      isBuy
   );


   ChartRedraw();
  }


//+------------------------------------------------------------------+
//| TIMEFRAME STRING                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeToString(
   int timeframe
)
  {
   switch(
      timeframe
   )
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
//| DASHBOARD PANEL                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardPanel(
   string name,

   int x,

   int y,

   int width,

   int height,

   color background
)
  {
   if(
      ObjectFind(
         0,

         name
      ) <
      0
   )
     {
      ObjectCreate(
         0,

         name,

         OBJ_RECTANGLE_LABEL,

         0,

         0,

         0
      );
     }


   ObjectSetInteger(
      0,

      name,

      OBJPROP_CORNER,

      CORNER_RIGHT_UPPER
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_XDISTANCE,

      x
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_YDISTANCE,

      y
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_XSIZE,

      width
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_YSIZE,

      height
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_BGCOLOR,

      background
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_BORDER_TYPE,

      BORDER_FLAT
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_COLOR,

      clrDimGray
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_SELECTABLE,

      false
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_HIDDEN,

      true
   );
  }


//+------------------------------------------------------------------+
//| DASHBOARD LABEL                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardLabel(
   string name,

   string text,

   int x,

   int y,

   int fontSize,

   color textColor
)
  {
   if(
      ObjectFind(
         0,

         name
      ) <
      0
   )
     {
      ObjectCreate(
         0,

         name,

         OBJ_LABEL,

         0,

         0,

         0
      );
     }


   ObjectSetInteger(
      0,

      name,

      OBJPROP_CORNER,

      CORNER_RIGHT_UPPER
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_XDISTANCE,

      x
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_YDISTANCE,

      y
   );


   ObjectSetString(
      0,

      name,

      OBJPROP_TEXT,

      text
   );


   ObjectSetString(
      0,

      name,

      OBJPROP_FONT,

      "Arial"
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_FONTSIZE,

      fontSize
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_COLOR,

      textColor
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_SELECTABLE,

      false
   );


   ObjectSetInteger(
      0,

      name,

      OBJPROP_HIDDEN,

      true
   );
  }


//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| LIVE ORDERS TABLE (LEFT SIDE)                                    |
//+------------------------------------------------------------------+
void DrawLiveOrdersTable()
  {
   string prefix = "LIVE_ORDERS_";

// Delete previous objects
   for(int i=0; i<100; i++)
     {
      ObjectDelete(prefix+"L"+IntegerToString(i));
     }

//====================================================
// BLACK BACKGROUND PANEL
//====================================================
   ObjectDelete("LIVE_ORDERS_PANEL");

   ObjectCreate("LIVE_ORDERS_PANEL",OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_CORNER,0);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_XDISTANCE,5);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_YDISTANCE,10);

   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_XSIZE,360);      // Width
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_YSIZE,320);      // Height (adjust as needed)

   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_BGCOLOR,clrBlack);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_COLOR,clrDimGray);   // Border
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_BACK,false);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_SELECTABLE,false);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_HIDDEN,true);
   ObjectSet("LIVE_ORDERS_PANEL",OBJPROP_ZORDER,0);

   int x = 10;      // Left margin
   int y = 20;      // Top margin
   int row = 0;

   string font = "Consolas";
   int size = 9;

//===============================
// Header
//===============================
   string txt =
      "Ticket     Type   Lot    Open        Profit";

   ObjectCreate(prefix+"L0",OBJ_LABEL,0,0,0);
   ObjectSet(prefix+"L0",OBJPROP_CORNER,0);
   ObjectSet(prefix+"L0",OBJPROP_XDISTANCE,x);
   ObjectSet(prefix+"L0",OBJPROP_YDISTANCE,y);
   ObjectSetText(prefix+"L0",txt,size,font,clrYellow);

   row++;

   double totalPL   = 0;
   double totalLots = 0;
   int totalOrders  = 0;

//===============================
// Live Orders
//===============================
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderType()!=OP_BUY &&
         OrderType()!=OP_SELL)
         continue;

      double pl =
         OrderProfit()+
         OrderSwap()+
         OrderCommission();

      totalPL   += pl;
      totalLots += OrderLots();
      totalOrders++;

      string type =
         OrderType()==OP_BUY ? "BUY " : "SELL";

      txt =
         StringFormat(
            "%-9d %-5s %0.2f %10."+IntegerToString(Digits)+"f %7.2f",
            OrderTicket(),
            type,
            OrderLots(),
            OrderOpenPrice(),
            pl);

      string name = prefix+"L"+IntegerToString(row);

      ObjectCreate(name,OBJ_LABEL,0,0,0);
      ObjectSet(name,OBJPROP_CORNER,0);
      ObjectSet(name,OBJPROP_XDISTANCE,x);
      ObjectSet(name,OBJPROP_YDISTANCE,y+(row*16));

      color c = clrWhite;
      if(pl>0)
         c=clrLime;
      if(pl<0)
         c=clrRed;

      ObjectSetText(name,txt,size,font,c);

      row++;
     }

//===============================
// Footer
//===============================
   txt="------------------------------------------------";

   ObjectCreate(prefix+"L"+IntegerToString(row),OBJ_LABEL,0,0,0);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_CORNER,0);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_XDISTANCE,x);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_YDISTANCE,y+(row*16));
   ObjectSetText(prefix+"L"+IntegerToString(row),txt,size,font,clrSilver);

   row++;

   txt=StringFormat(
          "Orders:%d   Lots:%.2f   Total P/L: %.2f",
          totalOrders,
          totalLots,
          totalPL);

   ObjectCreate(prefix+"L"+IntegerToString(row),OBJ_LABEL,0,0,0);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_CORNER,0);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_XDISTANCE,x);
   ObjectSet(prefix+"L"+IntegerToString(row),OBJPROP_YDISTANCE,y+(row*16));

   color totalColor=clrWhite;
   if(totalPL>0)
      totalColor=clrLime;
   if(totalPL<0)
      totalColor=clrRed;

   ObjectSetText(prefix+"L"+IntegerToString(row),txt,size,font,totalColor);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(
   DailyProtectionState &state
)
  {

   DrawLiveOrdersTable();
   int totalOrders =
      0;


   int buyOrders =
      0;


   int sellOrders =
      0;


   int pendingOrders =
      0;


   double floatingProfit =
      0;


   double totalSwap =
      0;


   double totalCommission =
      0;


   string ordersDetails =
      "";


   for(
      int i =
         OrdersTotal() -
         1;

      i >=
      0;

      i--
   )
     {
      if(
         !OrderSelect(
            i,

            SELECT_BY_POS,

            MODE_TRADES
         )
      )
        {
         continue;
        }


      if(
         OrderSymbol() !=
         Symbol()
      )
        {
         continue;
        }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
        {
         continue;
        }


      int type =
         OrderType();


      if(
         type !=
         OP_BUY &&

         type !=
         OP_SELL &&

         type !=
         OP_BUYSTOP &&

         type !=
         OP_SELLSTOP
      )
        {
         continue;
        }


      totalOrders++;


      if(
         type ==
         OP_BUY
      )
        {
         buyOrders++;


         floatingProfit +=
            OrderProfit();


         totalSwap +=
            OrderSwap();


         totalCommission +=
            OrderCommission();
        }


      if(
         type ==
         OP_SELL
      )
        {
         sellOrders++;


         floatingProfit +=
            OrderProfit();


         totalSwap +=
            OrderSwap();


         totalCommission +=
            OrderCommission();
        }


      if(
         type ==
         OP_BUYSTOP ||

         type ==
         OP_SELLSTOP
      )
        {
         pendingOrders++;
        }


      string orderType;


      if(
         type ==
         OP_BUY
      )
        {
         orderType =
            "BUY";
        }
      else
         if(
            type ==
            OP_SELL
         )
           {
            orderType =
               "SELL";
           }
         else
            if(
               type ==
               OP_BUYSTOP
            )
              {
               orderType =
                  "BUY STOP";
              }
            else
              {
               orderType =
                  "SELL STOP";
              }


      string orderLine =
         "#" +

         IntegerToString(
            OrderTicket()
         ) +

         " " +

         orderType;


      if(
         type ==
         OP_BUY ||

         type ==
         OP_SELL
      )
        {
         double orderNetProfit =
            OrderProfit() +

            OrderSwap() +

            OrderCommission();


         orderLine +=
            " P/L: " +

            DoubleToString(
               orderNetProfit,

               2
            );
        }
      else
        {
         orderLine +=
            " @ " +

            DoubleToString(
               OrderOpenPrice(),

               Digits
            );
        }


      ordersDetails +=
         orderLine +

         "\n";
     }


   double netProfit =
      floatingProfit +

      totalSwap +

      totalCommission;


   color profitColor;


   if(
      netProfit >
      0
   )
     {
      profitColor =
         clrLimeGreen;
     }
   else
      if(
         netProfit <
         0
      )
        {
         profitColor =
            clrTomato;
        }
      else
        {
         profitColor =
            clrWhite;
        }


   int x =
      DashboardRightGap;


   int y =
      DashboardTopGap;


   CreateDashboardPanel(
      DASH_PREFIX +
      "PANEL",

      x,

      y,

      DashboardWidth,

      DashboardHeight,

      clrBlack
   );


   CreateDashboardPanel(
      DASH_PREFIX +
      "HEADER",

      x,

      y,

      DashboardWidth,

      35,

      C'30,60,100'
   );


   int textX =
      x +

      DashboardWidth -

      300;


   CreateDashboardLabel(
      DASH_PREFIX +
      "TITLE",

      "SSL CHANNEL CROSS EA",

      textX,

      y + 8,

      11,

      clrWhite
   );


   string statusText;


   if(
      IsDailyTradingStopped(
         state
      )
   )
     {
      statusText =
         "DAILY PROFIT PROTECTION STOPPED";
     }
   else
      if(
         state.ClosedOrdersToday <
         MinimumClosedOrdersForDailyProtection
      )
        {
         statusText =
            "PROTECTION WAITING FOR ORDERS";
        }
      else
         if(
            totalOrders >=
            MaxOpenOrders
         )
           {
            statusText =
               "MAX ORDERS REACHED";
           }
         else
           {
            statusText =
               "READY FOR NEXT SIGNAL";
           }


   color statusColor;


   if(
      IsDailyTradingStopped(
         state
      )
   )
     {
      statusColor =
         clrTomato;
     }
   else
      if(
         state.ClosedOrdersToday <
         MinimumClosedOrdersForDailyProtection
      )
        {
         statusColor =
            clrGold;
        }
      else
        {
         statusColor =
            clrLimeGreen;
        }


   CreateDashboardLabel(
      DASH_PREFIX +
      "STATUS",

      statusText,

      textX,

      y + 50,

      DashboardFontSize,

      statusColor
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "SYMBOL",

      "Symbol: " +

      Symbol(),

      textX,

      y + 72,

      DashboardFontSize,

      clrWhite
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "TIMEFRAME",

      "Timeframe: " +

      TimeframeToString(
         Period()
      ),

      textX,

      y + 94,

      DashboardFontSize,

      clrWhite
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "PNL",

      "LIVE P/L: " +

      DoubleToString(
         netProfit,

         2
      ),

      textX,

      y + 142,

      13,

      profitColor
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "ORDERS",

      "Total Orders: " +

      IntegerToString(
         totalOrders
      ) +

      " / " +

      IntegerToString(
         MaxOpenOrders
      ),

      textX,

      y + 174,

      DashboardFontSize,

      clrWhite
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "BUY",

      "BUY: " +

      IntegerToString(
         buyOrders
      ),

      textX,

      y + 196,

      DashboardFontSize,

      clrDeepSkyBlue
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "SELL",

      "SELL: " +

      IntegerToString(
         sellOrders
      ),

      textX - 90,

      y + 196,

      DashboardFontSize,

      clrTomato
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "PENDING",

      "Pending: " +

      IntegerToString(
         pendingOrders
      ),

      textX - 180,

      y + 196,

      DashboardFontSize,

      clrGold
   );
   CreateDashboardLabel(
      DASH_PREFIX +
      "DAY_START1",

      "Day Start: $" +

      DoubleToString(
         state.DayStartBalance,
         2
      ),

      textX,

      y + 210,

      DashboardFontSize,

      clrWhite
   );
   CreateDashboardLabel(
      DASH_PREFIX + "EQUITY",
      "Equity : $" + DoubleToString(AccountEquity(), 2),
      textX,
      y + 230,
      DashboardFontSize,
      clrLime
   );

   CreateDashboardLabel(
      DASH_PREFIX +
      "SL",

      "Initial SL: -$" +

      DoubleToString(
         StopLossUSD,

         2
      ),

      textX,

      y + 250,

      DashboardFontSize,

      clrTomato
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "LADDER",

      "L1: $" +

      DoubleToString(
         Ladder1ProfitUSD,

         2
      ) +

      " | L2: $" +

      DoubleToString(
         Ladder2ProfitUSD,

         2
      ),

      textX,

      y + 272,

      DashboardFontSize,

      clrLimeGreen
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "LADDER2",

      "L2 Starts: $" +

      DoubleToString(
         Ladder1StopMaxPriceUSD,

         2
      ),

      textX,

      y + 294,

      DashboardFontSize,

      clrGold
   );


   CreateDashboardLabel(
      DASH_PREFIX +
      "REENTRY",

      "Re-entry Gap: " +

      DoubleToString(
         ProfitReEntryGapRaw,

         Digits
      ) +

      " raw",

      textX,

      y + 316,

      DashboardFontSize,

      clrGold
   );


   if(
      EnableDailyLossProtection
   )
     {
      CreateDashboardLabel(
         DASH_PREFIX +
         "CLOSED_TODAY",

         "Closed Today: " +

         IntegerToString(
            state.ClosedOrdersToday
         ) +

         " / " +

         IntegerToString(
            MinimumClosedOrdersForDailyProtection
         ),

         textX,

         y + 338,

         DashboardFontSize,

         state.ClosedOrdersToday >=
         MinimumClosedOrdersForDailyProtection ?

         clrLimeGreen :

         clrGold
      );


      CreateDashboardLabel(
         DASH_PREFIX +
         "DAY_START",

         "Day Start: $" +

         DoubleToString(
            state.DayStartBalance,
            2
         ),

         textX,

         y + 360,

         DashboardFontSize,

         clrWhite
      );


      CreateDashboardLabel(
         DASH_PREFIX +
         "DAY_HIGH",

         "Day High: $" +

         DoubleToString(
            state.DayHighestBalance,
            2
         ),

         textX,

         y + 380,

         DashboardFontSize,

         clrDeepSkyBlue
      );


      CreateDashboardLabel(
         DASH_PREFIX +
         "PROTECTED",

         "Protected: $" +

         DoubleToString(
            state.DayProtectedBalance,
            2
         ),

         textX,

         y + 400,

         DashboardFontSize,

         clrGold
      );
     }


   CreateDashboardLabel(
      DASH_PREFIX +
      "DETAIL_TITLE",

      "LIVE ORDER DETAILS",

      textX,

      y + 422,

      DashboardFontSize,

      clrGold
   );


   if(
      totalOrders >
      0
   )
     {
      CreateDashboardLabel(
         DASH_PREFIX +
         "DETAILS",

         ordersDetails,

         textX,

         y + 442,

         DashboardFontSize,

         clrWhite
      );
     }
   else
     {
      CreateDashboardLabel(
         DASH_PREFIX +
         "DETAILS",

         "No active orders",

         textX,

         y + 442,

         DashboardFontSize,

         clrSilver
      );
     }
  }


//+------------------------------------------------------------------+
//| DELETE EA OBJECTS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOurObjects()
  {
   int total =
      ObjectsTotal(
         0,

         -1,

         -1
      );


   for(
      int i =
         total -
         1;

      i >=
      0;

      i--
   )
     {
      string name =
         ObjectName(
            0,

            i,

            -1,

            -1
         );


      if(
         StringFind(
            name,

            PREFIX,

            0
         )
         ==
         0
      )
        {
         ObjectDelete(
            0,

            name
         );
        }
     }
  }


//+------------------------------------------------------------------+
//| DELETE DASHBOARD OBJECTS                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteDashboardObjects()
  {
   int total =
      ObjectsTotal(
         0,

         -1,

         -1
      );


   for(
      int i =
         total -
         1;

      i >=
      0;

      i--
   )
     {
      string name =
         ObjectName(
            0,

            i,

            -1,

            -1
         );


      if(
         StringFind(
            name,

            DASH_PREFIX,

            0
         )
         ==
         0
      )
        {
         ObjectDelete(
            0,

            name
         );
        }
     }
  }


//+------------------------------------------------------------------+
//| END OF EA                                                        |
//+------------------------------------------------------------------+
