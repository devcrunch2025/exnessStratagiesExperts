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
   if(tradeCount >= SeqBuyMaxOrders)
   {
      Print("Blocked: Max ", SeqBuyMaxOrders, " trades reached after last EMA cross");
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


 double GetEMAGapPoints(int fastPeriod, int slowPeriod, int shift = 0)
{
   double emaFast = iMA(Symbol(), 0, fastPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double emaSlow = iMA(Symbol(), 0, slowPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);

   double gap = MathAbs(emaFast - emaSlow);

   if(gap/Point<1000)
   {
       g_lastCrossTime = TimeCurrent();

         //Print("EMA NEAR CROSS DETECTED at: ", TimeToString(g_lastCrossTime), " | Gap: ", DoubleToString(gap/Point,1), " pts");

   }

   return gap / Point; // return in points
}

void ShowEMAGapLabel()
{
   string name = "EMA_GAP_LABEL";

   double gap = GetEMAGapPoints(FastEMA, SlowEMA);
   string text = "EMA Gap: " + DoubleToString(gap, 1) + " pts. "+IntegerToString(SeqBuyMaxOrders)+"/"+IntegerToString(SeqSellMaxOrders);
Print("Current EMA Gap: ", DoubleToString(gap,1), " pts. Max Orders: ", SeqBuyMaxOrders, "/", SeqSellMaxOrders);
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
}
      // ✅ RIGHT TOP
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 200);   // from right
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 50);   // from top
if(gap<=3000)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
else if(gap<=10000)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
else
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   

   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void createNewOrderBeforeCandle()
{

   double gap = GetEMAGapPoints(FastEMA, SlowEMA);

   if(gap>10000)
   {
      SeqBuyMaxOrders=3;
      SeqSellMaxOrders=3;

      // Print("EMA Gap > 10000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
   }
   else
   if(gap>20000)
   {
      SeqBuyMaxOrders=5;
      SeqSellMaxOrders=5;
      // Print("EMA Gap > 20000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
   }
   else
   {
      SeqBuyMaxOrders=defaultMaxBuyOrders;
      SeqSellMaxOrders=defaultMaxSellOrders;  
      // Print("EMA Gap <= 10000 pts: Using default max orders. Current gap: ", DoubleToString(gap,1), " pts");
      }

    if(  gap>3000)
    {


   double ema9  = iMA(Symbol(), 0, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
double ema20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
double ema50 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
double price = Close[0];

string trend = "SIDEWAYS";

if(price > ema9 && ema9 > ema20 && ema20 > ema50)
{
   trend = "UPTREND";

   ProcessSeqBuyOrders();
}
else if(price < ema9 && ema9 < ema20 && ema20 < ema50)
{
   trend = "DOWNTREND";
   ProcessSeqSellOrders();
}
 
  
    }
}