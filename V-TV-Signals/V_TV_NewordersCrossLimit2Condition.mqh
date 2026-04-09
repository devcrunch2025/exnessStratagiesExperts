// 🔹 Global variable
datetime g_lastCrossTime = 0;

void DetectEMACross()
{
   static double prevFast = 0;
   static double prevSlow = 0;

   double emaFast = iMA(Symbol(), 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(prevFast != 0 && prevSlow != 0)
   {
      bool wasAbove = prevFast > prevSlow;
      bool isAbove  = emaFast > emaSlow;

      // 🔄 Cross detected
      if(wasAbove != isAbove)
      {
         g_lastCrossTime = TimeCurrent();

         Print("EMA CROSS DETECTED at: ", TimeToString(g_lastCrossTime));

         // Optional: close trades
         // CloseAllBuyOrders(true, "EMA Cross");
         // CloseAllSellOrders(true, "EMA Cross");
      }
   }

   prevFast = emaFast;
   prevSlow = emaSlow;
}

bool CanOpenTradeAfterCross(int direction)
{
   // direction: OP_BUY or OP_SELL

   if(g_lastCrossTime == 0)
      return false; // ❌ no cross yet

   int tradeCount = 0;

   for(int i = OrdersHistoryTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() != Symbol()) continue;

         // ✅ Only trades AFTER last cross
         if(OrderCloseTime() < g_lastCrossTime)
            break;

         if(OrderType() == direction)
            tradeCount++;
      }
   }

   // 🔒 Limit 2 trades after cross
   if(tradeCount >= 1)
   {
      Print("Blocked: Max 2 trades reached after last EMA cross");
      return false;
   }

   // 🔹 Trend validation
   double emaFast = iMA(Symbol(), 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(direction == OP_BUY && emaFast <= emaSlow)
      return false;

   if(direction == OP_SELL && emaFast >= emaSlow)
      return false;

   return true;
}