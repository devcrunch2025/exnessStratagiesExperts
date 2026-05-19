//+------------------------------------------------------------------+
//| EMA20 + MACD Centerline + Recovery EA                            |
//| Basket TP $1 | Basket SL $20 | Multiple Orders                   |
//| Recovery by PRICE DIFFERENCE from last losing order              |
//+------------------------------------------------------------------+
#property strict

extern double LotSize         = 0.01;
extern double ProfitTargetUSD = 1.0;

extern bool   UseStopLoss     = true;
extern double StopLossUSD     = 20.0;

extern int    TrendEMA        = 20;
extern int    FastEMA         = 12;
extern int    SlowEMA         = 26;
extern int    SignalSMA       = 9;

extern int    TimeFrame       = PERIOD_M5;
extern int    Slippage        = 30;
extern int    MagicNumber     = 20260518;

// Multiple Orders
extern bool   AllowMultipleBaseOrders = false;
extern int    MaxBaseOrders           = 10;

// Recovery Settings
extern bool   EnableRecovery       = true;
extern double RecoveryStartLossUSD = -0.01;
extern int    MaxRecoveryOrders    = 3;

// RAW PRICE DIFFERENCE, NOT POINTS
extern double RecoveryGap1Price = 100.0;
extern double RecoveryGap2Price = 300.0;
extern double RecoveryGap3Price = 600.0;

extern double Recovery1Lot = 0.01;
extern double Recovery2Lot = 0.01;
extern double Recovery3Lot = 0.01;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
void OnTick()
{
   DrawEMA20Line();

   ManageTrades();

   if(EnableRecovery)
      CheckRecoveryOrders();

   datetime currentBar = iTime(Symbol(), TimeFrame, 0);

   if(currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   CheckBuySignal();
   CheckSellSignal();
}

//+------------------------------------------------------------------+
void CheckBuySignal()
{
   if(!AllowMultipleBaseOrders && CountOpenTrades() > 0)
      return;

   if(CountBaseOrders() >= MaxBaseOrders)
      return;

   double ema20  = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1 = iClose(Symbol(), TimeFrame, 1);

   double macd1 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 1);

   double macd2 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 2);

   if(close1 > ema20 && macd1 > 0 && macd2 <= 0)
      OpenOrder(OP_BUY, LotSize, "V7_MACD_BASE_BUY");
}

//+------------------------------------------------------------------+
void CheckSellSignal()
{
   if(!AllowMultipleBaseOrders && CountOpenTrades() > 0)
      return;

   if(CountBaseOrders() >= MaxBaseOrders)
      return;

   double ema20  = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1 = iClose(Symbol(), TimeFrame, 1);

   double macd1 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 1);

   double macd2 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 2);

   if(close1 < ema20 && macd1 < 0 && macd2 >= 0)
      OpenOrder(OP_SELL, LotSize, "V7_MACD_BASE_SELL");
}

//+------------------------------------------------------------------+
void OpenOrder(int orderType, double lot, string comment)
{
   RefreshRates();

   double price = (orderType == OP_BUY) ? Ask : Bid;

   int ticket = OrderSend(Symbol(),
                          orderType,
                          lot,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          clrBlue);

   if(ticket < 0)
      Print("OrderSend failed. Error: ", GetLastError(), " Comment: ", comment);
   else
      Print("Order opened. Ticket: ", ticket, " Comment: ", comment);
}

//+------------------------------------------------------------------+
//| Basket TP and Basket SL                                          |
//+------------------------------------------------------------------+
void ManageTrades()
{
   double basketProfit = GetTotalOpenProfit();

   if(CountOpenTrades() <= 0)
      return;

   if(basketProfit >= ProfitTargetUSD)
   {
      Print("Basket TP Hit: ", basketProfit);
      CloseAllOrders();
      return;
   }

   if(UseStopLoss && basketProfit <= -StopLossUSD)
   {
      Print("Basket SL Hit: ", basketProfit);
      CloseAllOrders();
      return;
   }
}

//+------------------------------------------------------------------+
//| Recovery by raw price difference from latest losing order         |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
{
   if(CountRecoveryOrders() >= MaxRecoveryOrders)
      return;

   int losingType = GetWorstLosingOrderType();

   if(losingType == -1)
      return;

   double lastPrice = GetLatestLosingOrderPrice(losingType);

   if(lastPrice <= 0)
      return;

   RefreshRates();

   double priceDifference = 0;

   if(losingType == OP_BUY)
      priceDifference = lastPrice - Bid;

   if(losingType == OP_SELL)
      priceDifference = Ask - lastPrice;

   int nextRecoveryLevel = CountRecoveryOrders() + 1;

   double requiredGap = GetRecoveryGapPrice(nextRecoveryLevel);
   double recoveryLot = GetRecoveryLot(nextRecoveryLevel);

   if(priceDifference < requiredGap)
      return;

   if(losingType == OP_BUY)
   {
      OpenOrder(OP_BUY, recoveryLot, "V7_MACD_RECOVERY_BUY_" + IntegerToString(nextRecoveryLevel));
      return;
   }

   if(losingType == OP_SELL)
   {
      OpenOrder(OP_SELL, recoveryLot, "V7_MACD_RECOVERY_SELL_" + IntegerToString(nextRecoveryLevel));
      return;
   }
}

//+------------------------------------------------------------------+
double GetRecoveryGapPrice(int level)
{
   if(level == 1) return RecoveryGap1Price;
   if(level == 2) return RecoveryGap2Price;
   if(level == 3) return RecoveryGap3Price;

   return RecoveryGap1Price;
}

//+------------------------------------------------------------------+
double GetLatestLosingOrderPrice(int orderType)
{
   datetime latestTime = 0;
   double latestPrice = 0;

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

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= RecoveryStartLossUSD)
         continue;

      if(OrderOpenTime() > latestTime)
      {
         latestTime = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return latestPrice;
}

//+------------------------------------------------------------------+
int GetWorstLosingOrderType()
{
   double worstProfit = 0;
   int worstType = -1;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < RecoveryStartLossUSD && profit < worstProfit)
      {
         worstProfit = profit;
         worstType = OrderType();
      }
   }

   return worstType;
}

//+------------------------------------------------------------------+
double GetRecoveryLot(int level)
{
   if(level == 1) return Recovery1Lot;
   if(level == 2) return Recovery2Lot;
   if(level == 3) return Recovery3Lot;

   return Recovery1Lot;
}

//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   RefreshRates();

   bool result = false;

   if(OrderType() == OP_BUY)
      result = OrderClose(ticket, OrderLots(), Bid, Slippage, clrRed);

   if(OrderType() == OP_SELL)
      result = OrderClose(ticket, OrderLots(), Ask, Slippage, clrRed);

   if(result)
      Print("Order closed. Ticket: ", ticket);
   else
      Print("Order close failed. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      RefreshRates();

      bool result = false;

      if(OrderType() == OP_BUY)
         result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);

      if(OrderType() == OP_SELL)
         result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(result)
         Print("Basket closed ticket: ", OrderTicket());
      else
         Print("Basket close failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
double GetTotalOpenProfit()
{
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      total++;
   }

   return total;
}

//+------------------------------------------------------------------+
int CountBaseOrders()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(StringFind(OrderComment(), "BASE") >= 0)
         total++;
   }

   return total;
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

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(StringFind(OrderComment(), "RECOVERY") >= 0)
         total++;
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOrders(int type)
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == type)
         total++;
   }

   return total;
}

//+------------------------------------------------------------------+
bool RecoveryExists(string comment)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderComment() == comment)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
void DrawEMA20Line()
{
   string emaName = "EMA20_LINE";

   if(ObjectFind(0, emaName) < 0)
   {
      ObjectCreate(0, emaName, OBJ_TREND, 0, 0, 0);
      ObjectSetInteger(0, emaName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, emaName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, emaName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, emaName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, emaName, OBJPROP_BACK, false);
   }

   datetime time1 = iTime(Symbol(), TimeFrame, 50);
   datetime time2 = iTime(Symbol(), TimeFrame, 0);

   double ema1 = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 50);
   double ema2 = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   ObjectMove(0, emaName, 0, time1, ema1);
   ObjectMove(0, emaName, 1, time2, ema2);
}
//+------------------------------------------------------------------+