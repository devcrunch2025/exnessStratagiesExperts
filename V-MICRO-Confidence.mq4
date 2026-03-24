//+------------------------------------------------------------------+
//| SMA Cross EA with Trade Execution                                |
//+------------------------------------------------------------------+
#property strict

input int    FastPeriod = 20;
input int    SlowPeriod = 50;
input double LotSize    = 0.01;
input int    StopLoss   = 200;
input int    TakeProfit = 200;
input int    Slippage   = 3;
input int    Magic      = 20260315;

//+------------------------------------------------------------------+
// Count current EA orders
//+------------------------------------------------------------------+
int GetCurrentOrderType()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
            return OrderType();
   }
   return -1;
}

//+------------------------------------------------------------------+
// Close existing orders
//+------------------------------------------------------------------+
void CloseOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
         {
            if(OrderType() == OP_BUY)
               OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);

            if(OrderType() == OP_SELL)
               OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);
         }
      }
   }
}

//+------------------------------------------------------------------+
// Open Buy
//+------------------------------------------------------------------+
void OpenBuy(double lot)
{
   double sl = Ask - StopLoss   * Point;
   double tp = Ask + TakeProfit * Point;

   int ticket = OrderSend(Symbol(), OP_BUY, lot, Ask, Slippage,
                          sl, tp, "SMA BUY", Magic, 0, clrBlue);
   if(ticket < 0)
      Print("OpenBuy failed, error: ", GetLastError());
}

//+------------------------------------------------------------------+
// Open Sell
//+------------------------------------------------------------------+
void OpenSell(double lot)
{
   double sl = Bid + StopLoss   * Point;
   double tp = Bid - TakeProfit * Point;

   int ticket = OrderSend(Symbol(), OP_SELL, lot, Bid, Slippage,
                          sl, tp, "SMA SELL", Magic, 0, clrRed);
   if(ticket < 0)
      Print("OpenSell failed, error: ", GetLastError());
}

//+------------------------------------------------------------------+
void OnTick()
{
   // Use shift=1 (last closed bar) so the signal is stable across ticks
   double fast = iMA(NULL, 0, FastPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double slow = iMA(NULL, 0, SlowPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);

   // Confidence: how far apart the SMAs are, capped at 1.0
   double edge       = MathAbs((fast - slow) / slow);
   double confidence = MathMin(1.0, edge * 2000);

   // Scale lot size by confidence, respecting broker minimum
   double minLot     = MarketInfo(Symbol(), MODE_MINLOT);
   double lotStep    = MarketInfo(Symbol(), MODE_LOTSTEP);
   double dynamicLot = MathFloor((LotSize * confidence) / lotStep) * lotStep;
   dynamicLot        = MathMax(dynamicLot, minLot);

   int current = GetCurrentOrderType();

   // BUY SIGNAL
   if(fast > slow)
   {
      if(current != OP_BUY)
      {
         CloseOrders();
         OpenBuy(dynamicLot);
      }
   }

   // SELL SIGNAL
   if(fast < slow)
   {
      if(current != OP_SELL)
      {
         CloseOrders();
         OpenSell(dynamicLot);
      }
   }

   Comment(
      "Fast SMA:   ", fast,       "\n",
      "Slow SMA:   ", slow,       "\n",
      "Edge:       ", DoubleToStr(edge * 100, 4), "%\n",
      "Confidence: ", DoubleToStr(confidence * 100, 1), "%\n",
      "Lot size:   ", DoubleToStr(dynamicLot, 2)
   );
}
//+------------------------------------------------------------------+