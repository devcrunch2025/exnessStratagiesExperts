//+------------------------------------------------------------------+
//| VENU_Gap_Recovery_OneDirection_EA.mq4                            |
//| M5 candle gap + one-direction recovery orders                     |
//| Basket profit close = $1                                         |
//+------------------------------------------------------------------+
#property strict

extern double BaseLot             = 0.01;
extern double GapPrice            = 70.0;     // Raw price gap
extern int    MagicNumber         = 5050801;
extern int    Slippage            = 50;

extern double BasketProfitTarget  = 1.00;     // Basket TP $1

datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("VENU Gap Recovery One Direction EA Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   CloseBasketByProfit(OP_BUY);
   CloseBasketByProfit(OP_SELL);

   CheckNewBaseSignal();

   ManageRecovery(OP_BUY);
   ManageRecovery(OP_SELL);

   DrawDashboard();
}

//+------------------------------------------------------------------+
void CheckNewBaseSignal()
{
   datetime m5Time = iTime(Symbol(), PERIOD_M5, 1);

   if(m5Time == lastM5BarTime)
      return;

   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double gap   = close - open;

   // BUY open = no SELL
   // SELL open = no BUY
   // No new base order while any basket is active
   if(CountOrders(OP_BUY) > 0 || CountOrders(OP_SELL) > 0)
   {
      lastM5BarTime = m5Time;
      return;
   }

   if(gap > GapPrice)
   {
      OpenOrder(OP_BUY, BaseLot, "GAP_BUY_S0");
      lastM5BarTime = m5Time;
      return;
   }

   if(gap < -GapPrice)
   {
      OpenOrder(OP_SELL, BaseLot, "GAP_SELL_S0");
      lastM5BarTime = m5Time;
      return;
   }

   lastM5BarTime = m5Time;
}

//+------------------------------------------------------------------+
void ManageRecovery(int orderType)
{
   datetime baseTime = GetBaseOrderTime(orderType);

   if(baseTime <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(profit >= 0)
      return;

   int minutesPassed = (int)((TimeCurrent() - baseTime) / 60);

   if(minutesPassed >= 3 && !StageExists(orderType, 1))
      OpenOrder(orderType, 0.01, MakeComment(orderType, 1));

   if(minutesPassed >= 10 && !StageExists(orderType, 2))
      OpenOrder(orderType, 0.02, MakeComment(orderType, 2));

   if(minutesPassed >= 20 && !StageExists(orderType, 3))
      OpenOrder(orderType, 0.03, MakeComment(orderType, 3));

   if(minutesPassed >= 30 && !StageExists(orderType, 4))
      OpenOrder(orderType, 0.04, MakeComment(orderType, 4));
}
void CloseBasketByProfit(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return;

   double basketProfit = GetBasketProfit(orderType);
   double dynamicTarget = BasketProfitTarget / openCount;

   if(basketProfit < dynamicTarget)
      return;

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

      RefreshRates();

      double closePrice = orderType == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrGreen);

      if(!closed)
      {
         Print("Basket close failed. Ticket: ",
               OrderTicket(),
               " Error: ",
               GetLastError());
      }
   }

   Print("Basket closed. Type: ",
         orderType == OP_BUY ? "BUY" : "SELL",
         " Orders: ",
         openCount,
         " Profit: $",
         DoubleToString(basketProfit, 2),
         " Target: $",
         DoubleToString(dynamicTarget, 2));
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          comment, MagicNumber, 0, clr);

   if(ticket < 0)
   {
      Print("OrderSend failed. Error: ",
            GetLastError(),
            " Type: ",
            type,
            " Lot: ",
            lot,
            " Comment: ",
            comment);
      return false;
   }

   Print("Order opened: ",
         comment,
         " Lot: ",
         DoubleToString(lot, 2),
         " Ticket: ",
         ticket);

   return true;
}

//+------------------------------------------------------------------+
datetime GetBaseOrderTime(int orderType)
{
   datetime baseTime = 0;
   string tag = orderType == OP_BUY ? "GAP_BUY_S0" : "GAP_SELL_S0";

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
      {
         baseTime = OrderOpenTime();
      }
   }

   return baseTime;
}

//+------------------------------------------------------------------+
bool StageExists(int orderType, int stage)
{
   string tag = MakeComment(orderType, stage);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
string MakeComment(int orderType, int stage)
{
   if(orderType == OP_BUY)
      return "GAP_BUY_S" + IntegerToString(stage);

   return "GAP_SELL_S" + IntegerToString(stage);
}

//+------------------------------------------------------------------+
int CountOrders(int orderType)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
int CountAllOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
double GetBasketProfit(int orderType)
{
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
      {
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return profit;
}

//+------------------------------------------------------------------+
string GetActiveDirection()
{
   if(CountOrders(OP_BUY) > 0)
      return "BUY ONLY";

   if(CountOrders(OP_SELL) > 0)
      return "SELL ONLY";

   return "WAITING";
}

//+------------------------------------------------------------------+
double GetLastM5Gap()
{
   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);

   return close - open;
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   string text =
      "VENU GAP RECOVERY EA\n"
      "-----------------------------\n"
      "Symbol: " + Symbol() + "\n"
      "Active Direction: " + GetActiveDirection() + "\n"
      "M5 Gap Trigger: +/- " + DoubleToString(GapPrice, 2) + "\n"
      "Last Closed M5 Gap: " + DoubleToString(GetLastM5Gap(), 2) + "\n"
      "Basket TP: $" + DoubleToString(BasketProfitTarget, 2) + "\n"
      "BUY Orders: " + IntegerToString(CountOrders(OP_BUY)) + "\n"
      "SELL Orders: " + IntegerToString(CountOrders(OP_SELL)) + "\n"
      "Total Orders: " + IntegerToString(CountAllOrders()) + "\n"
      "BUY Basket P/L: $" + DoubleToString(GetBasketProfit(OP_BUY), 2) + "\n"
      "SELL Basket P/L: $" + DoubleToString(GetBasketProfit(OP_SELL), 2) + "\n"
      
      "BUY Dynamic TP: $" + DoubleToString(GetDynamicBasketTarget(OP_BUY), 2) + "\n"
"SELL Dynamic TP: $" + DoubleToString(GetDynamicBasketTarget(OP_SELL), 2) + "\n"
      "Rule: BUY open = no SELL | SELL open = no BUY\n"
      "Close Rule: Basket Profit >= $" + DoubleToString(BasketProfitTarget, 2);

   Comment(text);
}
double GetDynamicBasketTarget(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return BasketProfitTarget;

   return BasketProfitTarget / openCount;
}
//+------------------------------------------------------------------+