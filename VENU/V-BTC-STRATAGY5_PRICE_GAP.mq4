//+------------------------------------------------------------------+
//| _Gap_Recovery_Parallel_Trend_EA.mq4                              |
//| Price Difference Recovery + Trend Filter + Balance Check          |
//+------------------------------------------------------------------+
#property strict

input double LOTValue      = 0.01;
input double StopLossValue = 20.00;//equity -10;
input double TPValue       = 1.00;

double BaseLot             = 0.01;
double GapPrice            = 50.0;

int    MagicNumber         = 5050801;
int    Slippage            = 70;

double BasketProfitTarget  = 0.00;
double BasketStopLoss      = 0.00;

datetime lastM5BarTime = 0;

datetime g_m1BarStartTime = 0;
bool     g_m1GapChecked   = false;

//+------------------------------------------------------------------+
int OnInit()
{
   MagicNumber = AccountNumber() + 5;

   BaseLot            = LOTValue;
   BasketProfitTarget = TPValue;
   BasketStopLoss     = StopLossValue;

   MathSrand((int)TimeLocal());
   GapPrice = GapPrice + (MathRand() % 11 - 5);

   Print("Gap Recovery EA Started | Parallel Trend Version");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{

   CloseAllOrdersIfEquityDrop();

   
   CloseBasketByProfit(OP_BUY);
   CloseBasketByProfit(OP_SELL);

   // if(IsAfter30SecFromNewM1Bar())
      CheckNewBaseSignal();

   // Parallel recovery for both BUY and SELL
   ManageRecovery(OP_BUY);
   ManageRecovery(OP_SELL);

      OpenNextOrderAfterProfitClose();


   DrawDashboard();
   DrawEveryCandleDiffFrom5th();
}
void CloseAllOrdersIfEquityDrop()
{
   // double dynamicSL = StopLossValue;

   // if(AccountEquity() > AccountBalance() - dynamicSL)
   //    return;

       if(AccountEquity() > AccountBalance()/2)
      return;

   Print("Equity protection triggered. Closing all orders.");

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      RefreshRates();

      double closePrice = OrderType() == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(),
                               OrderLots(),
                               closePrice,
                               Slippage,
                               clrRed);

      if(!closed)
      {
         Print("Emergency close failed. Ticket: ",
               OrderTicket(),
               " Error: ",
               GetLastError());
      }
   }
}
//+------------------------------------------------------------------+
bool IsAfter30SecFromNewM1Bar()
{
   datetime currentBarTime = iTime(Symbol(), PERIOD_M1, 0);

   if(currentBarTime != g_m1BarStartTime)
   {
      g_m1BarStartTime = currentBarTime;
      g_m1GapChecked = false;
      return false;
   }

   if(!g_m1GapChecked && TimeCurrent() >= g_m1BarStartTime + 30)
   {
      g_m1GapChecked = true;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
int GetBalanceMultiplier()
{
   double balance = AccountBalance();

   int multiplier = (int)MathCeil(balance / 200.0);

   if(multiplier < 1)
      multiplier = 1;

   return multiplier;
}

//+------------------------------------------------------------------+
double GetLot(double baseLot)
{
   double lot = baseLot * GetBalanceMultiplier();

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lot < minLot)
      lot = minLot;

   if(lot > maxLot)
      lot = maxLot;

   lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
double GetBasketTP()
{
   return BasketProfitTarget * GetBalanceMultiplier();
}

//+------------------------------------------------------------------+
double GetBasketSL()
{
   return BasketStopLoss * GetBalanceMultiplier();
}

//+------------------------------------------------------------------+
double GetLiveM5Gap()
{
   RefreshRates();

   double open = iOpen(Symbol(), PERIOD_M5, 0);
   double live = Bid;

   return NormalizeDouble(live - open, 2);
}

//+------------------------------------------------------------------+
//| Trend direction using EMA9 and EMA21 on M5                       |
//|  1 = BUY trend, -1 = SELL trend, 0 = No clear trend               |
//+------------------------------------------------------------------+
int GetTrendDirection()
{
   double ema9  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema21 = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 1);

   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   if(close1 > ema9 && ema9 > ema21)
      return 1;

   if(close1 < ema9 && ema9 < ema21)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
string GetTrendText()
{
   int trend = GetTrendDirection();

   if(trend == 1)
      return "BUY TREND";

   if(trend == -1)
      return "SELL TREND";

   return "NO CLEAR TREND";
}
void OpenNextOrderAfterProfitClose()
{
   if(g_lastBasketProfitCloseTime <= 0)
      return;

   // wait 5 minutes
   if(TimeCurrent() - g_lastBasketProfitCloseTime < 60 * 5)
      return;

   int trend = GetTrendDirection();

   // BUY re-entry
   if(g_lastBasketProfitCloseType == OP_BUY)
   {
      if(trend == 1 && CountOrders(OP_BUY) == 0)
      {
         OpenOrder(OP_BUY,
                   GetLot(BaseLot),
                   MakeComment(OP_BUY, 0));

         Print("5 Min ReEntry BUY created.");

         g_lastBasketProfitCloseTime = 0;
         g_lastBasketProfitCloseType = -1;
      }
   }

   // SELL re-entry
   if(g_lastBasketProfitCloseType == OP_SELL)
   {
      if(trend == -1 && CountOrders(OP_SELL) == 0)
      {
         OpenOrder(OP_SELL,
                   GetLot(BaseLot),
                   MakeComment(OP_SELL, 0));

         Print("5 Min ReEntry SELL created.");

         g_lastBasketProfitCloseTime = 0;
         g_lastBasketProfitCloseType = -1;
      }
   }
}
//+------------------------------------------------------------------+
void CheckNewBaseSignal()
{
   GapPrice = 60 + MathRand() % 11;

   datetime m5Time = iTime(Symbol(), PERIOD_M5, 1);

   if(m5Time == lastM5BarTime)
      return;

   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double gap   = close - open;

   int trend = GetTrendDirection();

   bool buyOpen  = CountOrders(OP_BUY) > 0;
   bool sellOpen = CountOrders(OP_SELL) > 0;

   // BUY base order: price gap UP + BUY trend
   if(gap > GapPrice && trend == 1 && !buyOpen)
   {
      OpenOrder(OP_BUY, GetLot(BaseLot), MakeComment(OP_BUY, 0));

   lastM5BarTime = m5Time;

   }

   // SELL base order: price gap DOWN + SELL trend
   if(gap < -GapPrice && trend == -1 && !sellOpen)
   {
      OpenOrder(OP_SELL, GetLot(BaseLot), MakeComment(OP_SELL, 0));

   lastM5BarTime = m5Time;

   }

   lastM5BarTime = m5Time;


}

//+------------------------------------------------------------------+
//| RECOVERY ONLY BY PRICE DIFFERENCE FROM LATEST ORDER              |
//+------------------------------------------------------------------+
void ManageRecovery(int orderType)
{
   if(GetBaseOrderTime(orderType) <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(profit >= 0)
      return;

   int hour = TimeHour(TimeCurrent());

   double diff = GetLivePriceDiffFromLatestOrder(orderType);
   int timeDifferenceFromLatestOrder = GetLiveTimeDiffFromLatestTime(orderType);

   int currentStage = GetHighestStage(orderType);
   int nextStage    = currentStage + 1;

   double requiredGap = 0;
   double nextLot     = 0.01;

   bool nightSession = false;

   if(hour > 14 || hour < 1)
      nightSession = true;

   if(nextStage == 1) { requiredGap = 50;   nextLot = 0.01; }
   if(nextStage == 2) { requiredGap = 100;  nextLot = 0.02; }
   if(nextStage == 3) { requiredGap = 300;  nextLot = 0.03; }
   if(nextStage == 4) { requiredGap = 800;  nextLot = 0.03; }
   if(nextStage == 5) { requiredGap = 1200; nextLot = 0.04; }
   if(nextStage == 6) { requiredGap = 2000; nextLot = 0.05; }

   if(nextStage > 8)
      return;

   if(nightSession)
      requiredGap = requiredGap + 50;

   bool canRecover = false;

   // BUY recovery: price must move DOWN from latest BUY order
   if(orderType == OP_BUY && diff <= -requiredGap)
      canRecover = true;

   // SELL recovery: price must move UP from latest SELL order
   if(orderType == OP_SELL && diff >= requiredGap)
      canRecover = true;

   if(!canRecover)
      return;

   if(!StageExists(orderType, nextStage))
   {
      OpenOrder(orderType, GetLot(nextLot), MakeComment(orderType, nextStage));
   }
}

//+------------------------------------------------------------------+
int GetLiveTimeDiffFromLatestTime(int orderType)
{
   double latestPrice = 0;
   datetime latestTime = 0;

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

      if(latestTime == 0 || OrderOpenTime() > latestTime)
      {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   if(latestPrice <= 0)
      return 0;

   return (int)(TimeCurrent() - latestTime);
}

//+------------------------------------------------------------------+
double GetLivePriceDiffFromLatestOrder(int orderType)
{
   double latestPrice = 0;
   datetime latestTime = 0;

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

      if(latestTime == 0 || OrderOpenTime() > latestTime)
      {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   if(latestPrice <= 0)
      return 0;

   RefreshRates();

   double livePrice = orderType == OP_BUY ? Bid : Ask;

   return NormalizeDouble(livePrice - latestPrice, 2);
}

//+------------------------------------------------------------------+
double GetLatestOrderPrice(int orderType)
{
   double latestPrice = 0;
   datetime latestTime = 0;

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

      if(latestTime == 0 || OrderOpenTime() > latestTime)
      {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return latestPrice;
}

//+------------------------------------------------------------------+
int GetHighestStage(int orderType)
{
   int highestStage = -1;

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

      string cmt = OrderComment();

      for(int s = 0; s <= 20; s++)
      {
         if(cmt == MakeComment(orderType, s))
         {
            if(s > highestStage)
               highestStage = s;
         }
      }
   }

   return highestStage;
}

//+------------------------------------------------------------------+
double GetBaseOrderPrice(int orderType)
{
   datetime oldestTime = 0;
   double basePrice = 0;

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

      if(OrderComment() != MakeComment(orderType, 0))
         continue;

      if(oldestTime == 0 || OrderOpenTime() < oldestTime)
      {
         oldestTime = OrderOpenTime();
         basePrice  = OrderOpenPrice();
      }
   }

   return basePrice;
}
bool buyReached80Once  = false;
bool sellReached80Once = false;

datetime g_lastBasketProfitCloseTime = 0;
int      g_lastBasketProfitCloseType = -1;
//+------------------------------------------------------------------+
void CloseBasketByProfit(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
   {
      if(orderType == OP_BUY)
         buyReached80Once = false;

      if(orderType == OP_SELL)
         sellReached80Once = false;

      return;
   }

   double basketProfit  = GetBasketProfit(orderType);
   double dynamicTarget = GetDynamicBasketTarget(orderType);
   double dynamicSL     = GetBasketSL();

   double eightyPercentTarget = dynamicTarget * 0.80;

   bool closeNow = false;

   // normal TP or SL
   if(basketProfit <= -dynamicSL || basketProfit >= dynamicTarget)
      closeNow = true;

   // first time reached 80%
   if(basketProfit >= eightyPercentTarget)
   {
      if(orderType == OP_BUY)
      {
         if(buyReached80Once)
            closeNow = true;
         else
            buyReached80Once = true;
      }

      if(orderType == OP_SELL)
      {
         if(sellReached80Once)
            closeNow = true;
         else
            sellReached80Once = true;
      }
   }

   if(!closeNow)
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

      bool closed = OrderClose(OrderTicket(),
                               OrderLots(),
                               closePrice,
                               Slippage,
                               clrGreen);

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
         " TP: $",
         DoubleToString(dynamicTarget, 2),
         " 80% TP: $",
         DoubleToString(eightyPercentTarget, 2),
         " SL: $",
         DoubleToString(dynamicSL, 2));


  if(basketProfit > 0)
{
   g_lastBasketProfitCloseTime = TimeCurrent();
   g_lastBasketProfitCloseType = orderType;
}

   if(orderType == OP_BUY)
      buyReached80Once = false;

   if(orderType == OP_SELL)
      sellReached80Once = false;
}

//+------------------------------------------------------------------+
bool CanOpenNewOrder(int type, double lot)
{
   if(!IsTradeAllowed())
   {
      Print("Trading not allowed. Enable AutoTrading.");
      return false;
   }

   if(IsTradeContextBusy())
   {
      Print("Trade context busy. Try next tick.");
      return false;
   }

   if(lot <= 0)
   {
      Print("Invalid lot size: ", lot);
      return false;
   }

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);

   if(lot < minLot || lot > maxLot)
   {
      Print("Lot out of broker range. Lot: ",
            lot,
            " Min: ",
            minLot,
            " Max: ",
            maxLot);
      return false;
   }

   double freeMarginAfter = AccountFreeMarginCheck(Symbol(), type, lot);

   if(freeMarginAfter <= 0)
   {
      Print("Not enough margin. Balance: ",
            AccountBalance(),
            " Equity: ",
            AccountEquity(),
            " FreeMargin: ",
            AccountFreeMargin(),
            " Lot: ",
            lot,
            " Type: ",
            type == OP_BUY ? "BUY" : "SELL");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   lot = NormalizeDouble(lot, 2);

   if(!CanOpenNewOrder(type, lot))
      return false;

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          clr);

   if(ticket < 0)
   {
      int err = GetLastError();

      Print("OrderSend failed. Error: ",
            err,
            " Type: ",
            type == OP_BUY ? "BUY" : "SELL",
            " Lot: ",
            lot,
            " Comment: ",
            comment,
            " Balance: ",
            AccountBalance(),
            " Equity: ",
            AccountEquity(),
            " FreeMargin: ",
            AccountFreeMargin());

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
   string tag = MakeComment(orderType, 0);

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
      return "V5_PRICE_GAP_BUYS" + IntegerToString(stage);

   return "V5_PRICE_GAP_SELLS" + IntegerToString(stage);
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
double GetDynamicBasketTarget(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return GetBasketTP();

   double tp = GetBasketTP() / openCount;

   int trend = GetTrendDirection();

   // BUY basket but trend changed to SELL
   if(orderType == OP_BUY && trend == -1)
   {
      tp = tp * 0.20; // reduce TP to 50%
   }

   // SELL basket but trend changed to BUY
   if(orderType == OP_SELL && trend == 1)
   {
      tp = tp * 0.20;
   }

   // no clear trend
   if(trend == 0)
   {
      tp = tp * 0.50;
   }

   // minimum protection
   if(tp < 0.30)
      tp = 0.30;

   return NormalizeDouble(tp, 2);
}

//+------------------------------------------------------------------+
string GetActiveOrdersDirection()
{
   bool buyOpen  = CountOrders(OP_BUY) > 0;
   bool sellOpen = CountOrders(OP_SELL) > 0;

   if(buyOpen && sellOpen)
      return "BUY + SELL";

   if(buyOpen)
      return "BUY ACTIVE";

   if(sellOpen)
      return "SELL ACTIVE";

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
double GetLastClosedCandleDiffFrom(int timeframe)
{
   RefreshRates();

   double livePrice = Bid;
   double oldPrice  = iClose(Symbol(), timeframe, 1);

   return NormalizeDouble(livePrice - oldPrice, 2);
}

//+------------------------------------------------------------------+
double GetLastClosedCandleDiffFrom5th()
{
   double lastClose  = iClose(Symbol(), PERIOD_M5, 1);
   double fifthClose = iClose(Symbol(), PERIOD_M5, 5);

   return NormalizeDouble(lastClose - fifthClose, 0);
}

//+------------------------------------------------------------------+
void CreatePanel(string name,int x,int y,int w,int h,color bg)
{
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
}

//+------------------------------------------------------------------+
void CreateLabel(string name,
                 string text,
                 int x,
                 int y,
                 color clr,
                 int size=10)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}

//+------------------------------------------------------------------+
void DrawEMA9AndEMA21Lines()
{
   int candles = 150;

   for(int i = candles; i >= 1; i--)
   {
      datetime t1 = iTime(Symbol(), PERIOD_CURRENT, i);
      datetime t2 = iTime(Symbol(), PERIOD_CURRENT, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      double ema9_1  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema9_2  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      double ema21_1 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema21_2 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      string name9  = "EMA9_LINE_" + IntegerToString(i);
      string name21 = "EMA21_LINE_" + IntegerToString(i);

      if(ObjectFind(0, name9) < 0)
         ObjectCreate(0, name9, OBJ_TREND, 0, t1, ema9_1, t2, ema9_2);
      else
      {
         ObjectMove(0, name9, 0, t1, ema9_1);
         ObjectMove(0, name9, 1, t2, ema9_2);
      }

      ObjectSetInteger(0, name9, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, name9, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name9, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name9, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, name21) < 0)
         ObjectCreate(0, name21, OBJ_TREND, 0, t1, ema21_1, t2, ema21_2);
      else
      {
         ObjectMove(0, name21, 0, t1, ema21_1);
         ObjectMove(0, name21, 1, t2, ema21_2);
      }

      ObjectSetInteger(0, name21, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name21, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name21, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name21, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   DrawEMA9AndEMA21Lines();

   int mult = GetBalanceMultiplier();

   double buyPL  = GetBasketProfit(OP_BUY);
   double sellPL = GetBasketProfit(OP_SELL);

   color buyClr  = buyPL >= 0 ? clrLime : clrTomato;
   color sellClr = sellPL >= 0 ? clrLime : clrTomato;

   string direction = GetActiveOrdersDirection();
   string trendText = GetTrendText();

   color dirClr = clrSilver;

   if(direction == "BUY ACTIVE")
      dirClr = clrLime;

   if(direction == "SELL ACTIVE")
      dirClr = clrTomato;

   if(direction == "BUY + SELL")
      dirClr = clrAqua;

   color trendClr = clrSilver;

   if(GetTrendDirection() == 1)
      trendClr = clrLime;

   if(GetTrendDirection() == -1)
      trendClr = clrTomato;

   double buyLatestPrice  = GetLatestOrderPrice(OP_BUY);
   double sellLatestPrice = GetLatestOrderPrice(OP_SELL);

   double buyLatestGap  = GetLivePriceDiffFromLatestOrder(OP_BUY);
   double sellLatestGap = GetLivePriceDiffFromLatestOrder(OP_SELL);

   CreatePanel("DXB_PANEL",300,10,380,560,C'15,15,15');

   CreateLabel("V5",
               "PRICE GAP V5 PARALLEL TREND",
               210,30,
               clrGold,
               12);

   CreateLabel("DXB_BUYPL",
               "BUY Basket   : $" + DoubleToString(buyPL,2),
               290,50,
               buyClr);

   CreateLabel("DXB_SELLPL",
               "SELL Basket  : $" + DoubleToString(sellPL,2),
               290,70,
               sellClr);

   CreateLabel("DXB_BUYGAP",
               "BUY LatestGap: " + DoubleToString(buyLatestGap,2),
               290,90,
               buyLatestGap <= -20 ? clrLime : clrSilver);

   CreateLabel("DXB_SELLGAP",
               "SELL LatestG : " + DoubleToString(sellLatestGap,2),
               290,110,
               sellLatestGap >= 20 ? clrLime : clrSilver);

   CreateLabel("DXB_BUYLP",
               "BUY LastPrice: " + DoubleToString(buyLatestPrice,2),
               290,130,
               clrSilver);

   CreateLabel("DXB_SELLLP",
               "SELL LastPr  : " + DoubleToString(sellLatestPrice,2),
               290,150,
               clrSilver);

   CreateLabel("DXB_LOT",
               "Base Lot     : " + DoubleToString(GetLot(BaseLot),2),
               290,175,
               clrOrange);

   CreateLabel("DXB_CLOSED_M5_GAP",
               "Closed M5 Gap: " + DoubleToString(GetLastM5Gap(),2),
               290,195,
               clrYellow);

   CreateLabel("DXB_TRIGGER",
               "Gap Trigger  : " + DoubleToString(GapPrice,2),
               290,215,
               clrYellow);

   CreateLabel("DXB_LIVE_M5_GAP",
               "Live M5 Gap  : " + DoubleToString(GetLiveM5Gap(),2),
               290,235,
               GetLiveM5Gap() >= 0 ? clrLime : clrTomato);

   CreateLabel("DXB_TREND",
               "Trend  EMA       : " + trendText,
               290,255,
               trendClr);

   CreateLabel("DXB_DIR",
               "Direction Orders   : " + direction,
               290,275,
               dirClr);

   CreateLabel("DXB_BUYORD",
               "BUY Orders   : " + IntegerToString(CountOrders(OP_BUY)),
               290,300,
               clrLime);

   CreateLabel("DXB_SELLORD",
               "SELL Orders  : " + IntegerToString(CountOrders(OP_SELL)),
               290,320,
               clrTomato);

   CreateLabel("DXB_TOTAL",
               "Total Orders : " + IntegerToString(CountAllOrders()),
               290,340,
               clrWhite);

   CreateLabel("DXB_BUYTP",
               "BUY TP       : $" + DoubleToString(GetDynamicBasketTarget(OP_BUY),2),
               290,365,
               clrDeepSkyBlue);

   CreateLabel("DXB_SELLTP",
               "SELL TP      : $" + DoubleToString(GetDynamicBasketTarget(OP_SELL),2),
               290,385,
               clrDeepSkyBlue);

   CreateLabel("DXB_SL",
               "Basket SL    : $" + DoubleToString(GetBasketSL(),2),
               290,410,
               clrOrangeRed);

   CreateLabel("DXB_BAL",
               "Balance      : $" + DoubleToString(AccountBalance(),2),
               290,435,
               clrWhite);

   CreateLabel("DXB_EQ",
               "Equity       : $" + DoubleToString(AccountEquity(),2),
               290,455,
               clrWhite);

   CreateLabel("DXB_FM",
               "Free Margin  : $" + DoubleToString(AccountFreeMargin(),2),
               290,475,
               clrWhite);

   CreateLabel("DXB_MULT",
               "Multiplier   : " + IntegerToString(mult) + "X",
               290,495,
               clrAqua);

   CreateLabel("DXB_STATUS",
               "RUNNING PARALLEL PRICE GAP RECOVERY",
               290,525,
               clrLime,
               10);
}

//+------------------------------------------------------------------+
void DrawEveryCandleDiffFrom5th()
{
   int candlesToDraw = 100;

   for(int shift = 1; shift <= candlesToDraw; shift++)
   {
      if(shift + 5 >= Bars)
         continue;

      datetime t = iTime(Symbol(), PERIOD_M5, shift);

      string name = "DIFF5_" + IntegerToString((int)t);

      double currentClose = iClose(Symbol(), PERIOD_M5, shift);
      double fifthClose   = iClose(Symbol(), PERIOD_M5, shift + 5);

      double diff = NormalizeDouble(currentClose - fifthClose, 2);

      if(MathAbs(diff) < 50)
         continue;

      color txtColor = diff >= 0 ? clrLime : clrRed;

      double high = iHigh(Symbol(), PERIOD_M5, shift);
      double low  = iLow(Symbol(), PERIOD_M5, shift);

      double candleRange = MathAbs(high - low);
      double spacing = candleRange * 0.8;

      if(spacing < Point * 200)
         spacing = Point * 200;

      double y;

      if(diff >= 0)
         y = high + spacing;
      else
         y = low - spacing;

      if(ObjectFind(0, name) >= 0)
         continue;

      ObjectCreate(0, name, OBJ_TEXT, 0, t, y);

      ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(diff, 0));
      ObjectSetInteger(0, name, OBJPROP_COLOR, txtColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
}
//+------------------------------------------------------------------+