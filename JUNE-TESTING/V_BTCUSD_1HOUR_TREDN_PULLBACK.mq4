#property strict

input double Lots              = 0.01;
input double ProfitTargetUSD   = 2.0;
input double BasketStopLossUSD = 20.0;

input int    MaxOrders         = 5;
input double MinOrderGapPrice  = 50;

input int    Slippage          = 30;
input int    Magic             = 20260607;

input int EMAFast = 21;
input int EMASlow = 50;

input double SARStep = 0.02;
input double SARMax  = 0.2;

// Exhaustion protection
input bool   UseExhaustionProtection = true;
input double ExhaustionMovePrice     = 300;
input int    ExhaustionCandles       = 10;
input int    ExhaustionMinSameColor  = 7;

// Early reversal protection
input bool   UseEarlyReversalClose   = true;
input double EarlyReverseMovePrice   = 150;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Continuous Trend Capture EA Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageBasket();

   if(Time[0] == lastBarTime)
      return;

   lastBarTime = Time[0];

   int trend = GetContinuousTrend();

   if(trend == 1)
   {
      if(!UseExhaustionProtection || !IsBuyExhausted())
         OpenTrendOrder(OP_BUY);
      else
         Print("BUY blocked: trend exhausted");
   }

   if(trend == -1)
   {
      if(!UseExhaustionProtection || !IsSellExhausted())
         OpenTrendOrder(OP_SELL);
      else
         Print("SELL blocked: trend exhausted");
   }
}

//+------------------------------------------------------------------+
int GetContinuousTrend()
{
   double emaFast1 = iMA(Symbol(), PERIOD_M1, EMAFast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow1 = iMA(Symbol(), PERIOD_M1, EMASlow, 0, MODE_EMA, PRICE_CLOSE, 1);

   double emaFast3 = iMA(Symbol(), PERIOD_M1, EMAFast, 0, MODE_EMA, PRICE_CLOSE, 3);
   double emaSlow3 = iMA(Symbol(), PERIOD_M1, EMASlow, 0, MODE_EMA, PRICE_CLOSE, 3);

   double sar    = iSAR(Symbol(), PERIOD_M1, SARStep, SARMax, 1);
   double close1 = iClose(Symbol(), PERIOD_M1, 1);

   int bullish = 0;
   int bearish = 0;

   for(int i = 1; i <= 5; i++)
   {
      if(iClose(Symbol(), PERIOD_M1, i) > iOpen(Symbol(), PERIOD_M1, i))
         bullish++;

      if(iClose(Symbol(), PERIOD_M1, i) < iOpen(Symbol(), PERIOD_M1, i))
         bearish++;
   }

   bool higherHigh = iHigh(Symbol(), PERIOD_M1, 1) > iHigh(Symbol(), PERIOD_M1, 3);
   bool lowerLow   = iLow(Symbol(), PERIOD_M1, 1)  < iLow(Symbol(), PERIOD_M1, 3);

   bool emaBuyStrong =
      emaFast1 > emaSlow1 &&
      emaFast1 > emaFast3 &&
      emaSlow1 >= emaSlow3;

   bool emaSellStrong =
      emaFast1 < emaSlow1 &&
      emaFast1 < emaFast3 &&
      emaSlow1 <= emaSlow3;

   if(emaBuyStrong && sar < close1 && bullish >= 3 && higherHigh)
      return 1;

   if(emaSellStrong && sar > close1 && bearish >= 3 && lowerLow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool IsSellExhausted()
{
   double fall = iOpen(Symbol(), PERIOD_M1, ExhaustionCandles) -
                 iClose(Symbol(), PERIOD_M1, 1);

   int bearish = 0;

   for(int i = 1; i <= ExhaustionCandles; i++)
   {
      if(iClose(Symbol(), PERIOD_M1, i) < iOpen(Symbol(), PERIOD_M1, i))
         bearish++;
   }

   if(fall >= ExhaustionMovePrice && bearish >= ExhaustionMinSameColor)
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool IsBuyExhausted()
{
   double rise = iClose(Symbol(), PERIOD_M1, 1) -
                 iOpen(Symbol(), PERIOD_M1, ExhaustionCandles);

   int bullish = 0;

   for(int i = 1; i <= ExhaustionCandles; i++)
   {
      if(iClose(Symbol(), PERIOD_M1, i) > iOpen(Symbol(), PERIOD_M1, i))
         bullish++;
   }

   if(rise >= ExhaustionMovePrice && bullish >= ExhaustionMinSameColor)
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool IsEarlyReversalAgainstBasket()
{
   double emaFast = iMA(Symbol(), PERIOD_M1, EMAFast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), PERIOD_M1, EMASlow, 0, MODE_EMA, PRICE_CLOSE, 1);

   double sar    = iSAR(Symbol(), PERIOD_M1, SARStep, SARMax, 1);
   double close1 = iClose(Symbol(), PERIOD_M1, 1);

   double lastMove = iClose(Symbol(), PERIOD_M1, 1) -
                     iOpen(Symbol(), PERIOD_M1, 5);

   int buyCount  = CountType(OP_BUY);
   int sellCount = CountType(OP_SELL);

   if(sellCount > 0)
   {
      if(close1 > sar && emaFast > emaSlow && lastMove > EarlyReverseMovePrice)
         return true;
   }

   if(buyCount > 0)
   {
      if(close1 < sar && emaFast < emaSlow && lastMove < -EarlyReverseMovePrice)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
void OpenTrendOrder(int type)
{
   if(CountOrders() >= MaxOrders)
      return;

   if(!IsPriceGapOK(type))
      return;

   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;

   string comment = type == OP_BUY
      ? "CONT_TREND_BUY"
      : "CONT_TREND_SELL";

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0,
                          comment, Magic, 0,
                          type == OP_BUY ? clrBlue : clrRed);

   if(ticket < 0)
      Print("OrderSend failed. Error=", GetLastError());
   else
      Print("Order opened: ", comment, " Ticket=", ticket);
}

//+------------------------------------------------------------------+
bool IsPriceGapOK(int type)
{
   RefreshRates();

   double currentPrice = type == OP_BUY ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
         continue;

      if(OrderType() != type)
         continue;

      double gap = MathAbs(currentPrice - OrderOpenPrice());

      if(gap < MinOrderGapPrice)
      {
         Print("Order blocked by gap. Gap=", DoubleToString(gap, Digits));
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
void ManageBasket()
{
   double profit = GetBasketProfit();

   if(UseEarlyReversalClose && IsEarlyReversalAgainstBasket())
   {
      CloseAllOrders();
      Print("Basket closed by early reversal. Profit=", DoubleToString(profit, 2));
      return;
   }

   if(profit >= ProfitTargetUSD)
   {
      CloseAllOrders();
      Print("Basket profit closed: ", DoubleToString(profit, 2));
      return;
   }

   if(profit <= -BasketStopLossUSD)
   {
      CloseAllOrders();
      Print("Basket stop loss closed: ", DoubleToString(profit, 2));
      return;
   }
}

//+------------------------------------------------------------------+
double GetBasketProfit()
{
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
         continue;

      profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return profit;
}

//+------------------------------------------------------------------+
int CountOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
int CountType(int type)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == Magic &&
         OrderType() == type)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
void CloseAllOrders()
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != Magic)
         continue;

      bool closed = false;

      if(OrderType() == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

      if(OrderType() == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(!closed)
         Print("OrderClose failed. Ticket=", OrderTicket(), " Error=", GetLastError());
   }
}
//+------------------------------------------------------------------+