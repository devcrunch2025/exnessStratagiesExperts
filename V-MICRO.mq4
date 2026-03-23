//+------------------------------------------------------------------+
//| SMA Cross EA with Trade Execution                               |
//+------------------------------------------------------------------+
#property strict

input int FastPeriod = 20;
input int SlowPeriod = 50;

input double LotSize = 0.01;
input int StopLoss = 200;
input int TakeProfit = 5;

input int Slippage = 3;
input int Magic = 20260315;

//+------------------------------------------------------------------+
// Count current EA orders
//+------------------------------------------------------------------+
int GetCurrentOrderType()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==Magic && OrderSymbol()==Symbol())
         {
            return OrderType();
         }
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
// Close existing order
//+------------------------------------------------------------------+
void CloseOrders()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==Magic && OrderSymbol()==Symbol())
         {
            if(OrderType()==OP_BUY)
               OrderClose(OrderTicket(),OrderLots(),Bid,Slippage,clrRed);

            if(OrderType()==OP_SELL)
               OrderClose(OrderTicket(),OrderLots(),Ask,Slippage,clrBlue);
         }
      }
   }
}

//+------------------------------------------------------------------+
// Open Buy
//+------------------------------------------------------------------+
void OpenBuy()
{
   double sl = Ask - StopLoss * Point;
   double tp = Ask + TakeProfit * Point;

   OrderSend(Symbol(),OP_BUY,LotSize,Ask,Slippage,sl,tp,
   "SMA BUY",Magic,0,clrBlue);
}

//+------------------------------------------------------------------+
// Open Sell
//+------------------------------------------------------------------+
void OpenSell()
{
   double sl = Bid + StopLoss * Point;
   double tp = Bid - TakeProfit * Point;

   OrderSend(Symbol(),OP_SELL,LotSize,Bid,Slippage,sl,tp,
   "SMA SELL",Magic,0,clrRed);
}

//+------------------------------------------------------------------+
void OnTick()
{
   double fast = iMA(NULL,0,FastPeriod,0,MODE_SMA,PRICE_CLOSE,0);
   double slow = iMA(NULL,0,SlowPeriod,0,MODE_SMA,PRICE_CLOSE,0);

   double edge = MathAbs((fast - slow) / slow);
   double confidence = MathMin(1, edge * 2000);

   int current = GetCurrentOrderType();

   // BUY SIGNAL
   if(fast > slow)
   {
      if(current != OP_BUY)
      {
         CloseOrders();
         OpenBuy();
      }
   }

   // SELL SIGNAL
   if(fast < slow)
   {
      if(current != OP_SELL)
      {
         CloseOrders();
         OpenSell();
      }
   }

   Comment(
   "Fast SMA: ",fast,"\n",
   "Slow SMA: ",slow,"\n",
   "Confidence: ",confidence
   );
}
//+------------------------------------------------------------------+