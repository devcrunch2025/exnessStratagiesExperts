#property strict

extern double LotSize        = 0.01;
extern double ProfitTarget   = 1.0;
extern double StopLossMoney  = 20.0;
extern int    MagicNumber    = 20260518;
extern int    Slippage       = 30;
extern int    MaxSpread      = 500;

datetime lastTradeCandle = 0;

//--------------------------------------------------
int OnInit()
{
   Print("Candlestick Pattern EA Started");
   return(INIT_SUCCEEDED);
}

//--------------------------------------------------
void OnTick()
{
   CloseByMoney();

   if(!IsNewCandle()) return;
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread) return;

   //if(CountOrders() > 0) return;

   int signal = GetPatternSignal();

   if(signal == 1)
      OpenOrder(OP_BUY, "BUY_PATTERN");

   if(signal == -1)
      OpenOrder(OP_SELL, "SELL_PATTERN");
}

//--------------------------------------------------
bool IsNewCandle()
{
   datetime t = iTime(Symbol(), PERIOD_M1, 0);

   if(t != lastTradeCandle)
   {
      lastTradeCandle = t;
      return true;
   }

   return false;
}

//--------------------------------------------------
int GetPatternSignal()
{
   int green = 0;
   int red   = 0;

   for(int i = 1; i <= 5; i++)
   {
      double open  = iOpen(Symbol(), PERIOD_M1, i);
      double close = iClose(Symbol(), PERIOD_M1, i);

      if(close > open) green++;
      if(close < open) red++;
   }

   double close1 = iClose(Symbol(), PERIOD_M1, 1);
   double close5 = iClose(Symbol(), PERIOD_M1, 5);

   double priceDiff = close1 - close5;

   // BUY reversal after down move
   if(red >= 3 && iClose(Symbol(), PERIOD_M1, 1) > iOpen(Symbol(), PERIOD_M1, 1))
      return 1;

   // SELL continuation after down move
   if(red >= 4 && priceDiff < -100 * Point)
      return -1;

   // BUY continuation
   if(green >= 4 && priceDiff > 100 * Point)
      return 1;

   // SELL reversal after up move
   if(green >= 3 && iClose(Symbol(), PERIOD_M1, 1) < iOpen(Symbol(), PERIOD_M1, 1))
      return -1;

   return 0;
}

//--------------------------------------------------
bool IsHammer(int shift)
{
   double open  = iOpen(Symbol(), PERIOD_M1, shift);
   double close = iClose(Symbol(), PERIOD_M1, shift);
   double high  = iHigh(Symbol(), PERIOD_M1, shift);
   double low   = iLow(Symbol(), PERIOD_M1, shift);

   double body = MathAbs(close - open);
   double lowerWick = MathMin(open, close) - low;
   double upperWick = high - MathMax(open, close);

   if(body <= 0) return false;

   if(lowerWick >= body * 2.0 && upperWick <= body * 0.8)
      return true;

   return false;
}

//--------------------------------------------------
bool IsShootingStar(int shift)
{
   double open  = iOpen(Symbol(), PERIOD_M1, shift);
   double close = iClose(Symbol(), PERIOD_M1, shift);
   double high  = iHigh(Symbol(), PERIOD_M1, shift);
   double low   = iLow(Symbol(), PERIOD_M1, shift);

   double body = MathAbs(close - open);
   double upperWick = high - MathMax(open, close);
   double lowerWick = MathMin(open, close) - low;

   if(body <= 0) return false;

   if(upperWick >= body * 2.0 && lowerWick <= body * 0.8)
      return true;

   return false;
}

//--------------------------------------------------
bool IsBullishEngulfing()
{
   double o1 = iOpen(Symbol(), PERIOD_M1, 1);
   double c1 = iClose(Symbol(), PERIOD_M1, 1);

   double o2 = iOpen(Symbol(), PERIOD_M1, 2);
   double c2 = iClose(Symbol(), PERIOD_M1, 2);

   bool prevBear = c2 < o2;
   bool currBull = c1 > o1;

   if(prevBear && currBull && c1 > o2 && o1 < c2)
      return true;

   return false;
}

//--------------------------------------------------
bool IsBearishEngulfing()
{
   double o1 = iOpen(Symbol(), PERIOD_M1, 1);
   double c1 = iClose(Symbol(), PERIOD_M1, 1);

   double o2 = iOpen(Symbol(), PERIOD_M1, 2);
   double c2 = iClose(Symbol(), PERIOD_M1, 2);

   bool prevBull = c2 > o2;
   bool currBear = c1 < o1;

   if(prevBull && currBear && c1 < o2 && o1 > c2)
      return true;

   return false;
}

//--------------------------------------------------
bool IsDoubleBottom()
{
   double low1 = iLow(Symbol(), PERIOD_M1, 1);
   double low3 = iLow(Symbol(), PERIOD_M1, 3);
   double close1 = iClose(Symbol(), PERIOD_M1, 1);
   double open1  = iOpen(Symbol(), PERIOD_M1, 1);

   double tolerance = 100 * Point;

   if(MathAbs(low1 - low3) <= tolerance && close1 > open1)
      return true;

   return false;
}

//--------------------------------------------------
bool IsSimpleHeadShoulder()
{
   double h5 = iHigh(Symbol(), PERIOD_M1, 5);
   double h3 = iHigh(Symbol(), PERIOD_M1, 3);
   double h1 = iHigh(Symbol(), PERIOD_M1, 1);

   double close1 = iClose(Symbol(), PERIOD_M1, 1);
   double open1  = iOpen(Symbol(), PERIOD_M1, 1);

   if(h3 > h5 && h3 > h1 && close1 < open1)
      return true;

   return false;
}

//--------------------------------------------------
void OpenOrder(int type, string comment)
{
   double price;

   if(type == OP_BUY)
      price = Ask;
   else
      price = Bid;

   int ticket = OrderSend(
      Symbol(),
      type,
      LotSize,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      clrBlue
   );

   if(ticket < 0)
      Print("OrderSend failed. Error: ", GetLastError());
   else
      Print("Order opened: ", comment, " Ticket: ", ticket);
}

//--------------------------------------------------
void CloseByMoney()
{
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;

      profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   if(profit >= ProfitTarget || profit <= -StopLossMoney)
   {
      CloseAllOrders();
   }
}

//--------------------------------------------------
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;

      bool closed = false;

      if(OrderType() == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrGreen);

      if(OrderType() == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(!closed)
         Print("OrderClose failed. Error: ", GetLastError());
   }
}

//--------------------------------------------------
int CountOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;

      count++;
   }

   return count;
}