#property strict

input double Lots              = 0.01;
input int    Slippage          = 30;
input int    MagicNumber       = 20262050;

input int    FastEMA           = 20;
input int    SlowEMA           = 50;

input double StopLossBuffer    = 2.0;   // raw price below/above 50 EMA
input double TakeProfitUSD     = 5.0;
input double StopLossUSD       = 10.0;

input bool   AllowBuy          = true;
input bool   AllowSell         = true;

datetime lastBarTime = 0;

//--------------------------------------------------
bool IsNewCandle()
{
   if(Time[0] != lastBarTime)
   {
      lastBarTime = Time[0];
      return true;
   }
   return false;
}

//--------------------------------------------------
double EMA(int period, int shift)
{
   return iMA(Symbol(), Period(), period, 0, MODE_EMA, PRICE_CLOSE, shift);
}

//--------------------------------------------------
int CountOrders()
{
   int count = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
            count++;
      }
   }

   return count;
}

//--------------------------------------------------
double BasketProfit()
{
   double profit = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
            profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return profit;
}

//--------------------------------------------------
void CloseAllOrders()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
         {
            bool closed = false;

            if(OrderType()==OP_BUY)
               closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrGreen);

            if(OrderType()==OP_SELL)
               closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);
         }
      }
   }
}

//--------------------------------------------------
bool BullCross()
{
   double ema20Prev = EMA(FastEMA, 2);
   double ema50Prev = EMA(SlowEMA, 2);

   double ema20Now  = EMA(FastEMA, 1);
   double ema50Now  = EMA(SlowEMA, 1);

   return ema20Prev <= ema50Prev && ema20Now > ema50Now;
}

//--------------------------------------------------
bool BearCross()
{
   double ema20Prev = EMA(FastEMA, 2);
   double ema50Prev = EMA(SlowEMA, 2);

   double ema20Now  = EMA(FastEMA, 1);
   double ema50Now  = EMA(SlowEMA, 1);

   return ema20Prev >= ema50Prev && ema20Now < ema50Now;
}

//--------------------------------------------------
bool BuyRetestZone()
{
   double ema20 = EMA(FastEMA, 1);
   double ema50 = EMA(SlowEMA, 1);

   return Low[1] <= ema20 && Low[1] >= ema50 && Close[1] > ema20;
}

//--------------------------------------------------
bool SellRetestZone()
{
   double ema20 = EMA(FastEMA, 1);
   double ema50 = EMA(SlowEMA, 1);

   return High[1] >= ema20 && High[1] <= ema50 && Close[1] < ema20;
}

//--------------------------------------------------
bool ThirdHoldBuy()
{
   return Close[1] > EMA(FastEMA,1) &&
          Close[2] > EMA(FastEMA,2) &&
          Close[3] > EMA(FastEMA,3);
}

//--------------------------------------------------
bool ThirdHoldSell()
{
   return Close[1] < EMA(FastEMA,1) &&
          Close[2] < EMA(FastEMA,2) &&
          Close[3] < EMA(FastEMA,3);
}

//--------------------------------------------------
void OpenBuy()
{
   double sl = EMA(SlowEMA,1) - StopLossBuffer;
   sl = NormalizeDouble(sl, Digits);

   int ticket = OrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, sl, 0,
                          "XAU 20/50 EMA BUY 3rd Hold",
                          MagicNumber, 0, clrBlue);

   if(ticket < 0)
      Print("BUY OrderSend failed. Error=", GetLastError());
}

//--------------------------------------------------
void OpenSell()
{
   double sl = EMA(SlowEMA,1) + StopLossBuffer;
   sl = NormalizeDouble(sl, Digits);

   int ticket = OrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, sl, 0,
                          "XAU 20/50 EMA SELL 3rd Hold",
                          MagicNumber, 0, clrRed);

   if(ticket < 0)
      Print("SELL OrderSend failed. Error=", GetLastError());
}

//--------------------------------------------------
void ExitByEMA50Close()
{
   double ema50 = EMA(SlowEMA,1);

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
            continue;

         if(OrderType()==OP_BUY && Close[1] < ema50)
            OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrOrange);

         if(OrderType()==OP_SELL && Close[1] > ema50)
            OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrOrange);
      }
   }
}

//--------------------------------------------------
void OnTick()
{
   double profit = BasketProfit();

   if(profit >= TakeProfitUSD)
   {
      CloseAllOrders();
      return;
   }

   if(profit <= -StopLossUSD)
   {
      CloseAllOrders();
      return;
   }

   if(!IsNewCandle())
      return;

   ExitByEMA50Close();

   if(CountOrders() > 0)
      return;

   if(AllowBuy)
   {
      if(EMA(FastEMA,1) > EMA(SlowEMA,1))
      {
         if(BuyRetestZone() && ThirdHoldBuy())
            OpenBuy();
      }
   }

   if(AllowSell)
   {
      if(EMA(FastEMA,1) < EMA(SlowEMA,1))
      {
         if(SellRetestZone() && ThirdHoldSell())
            OpenSell();
      }
   }
}