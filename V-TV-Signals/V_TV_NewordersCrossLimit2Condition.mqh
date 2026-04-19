// 🔹 Global variables
datetime g_lastCrossTime = 0;
string   g_blockReason   = "";

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

         // Print("EMA CROSS DETECTED at: ", TimeToString(g_lastCrossTime));

         // Optional: close trades
         // CloseAllBuyOrders(true, "EMA Cross");
         // CloseAllSellOrders(true, "EMA Cross");
      }
   }

   prevFast = emaFast;
   prevSlow = emaSlow;
}

int openTradeBuyCount=0;
int openTradeSellCount=0;

bool CanOpenTradeAfterCross(int direction)
{

     openTradeBuyCount=0;
  openTradeSellCount=0;

   //return true; // TEMP: Remove this line to enable the full logic
   // direction: OP_BUY or OP_SELL

   if(g_lastCrossTime == 0)
   { 
      // Print("Blocked: Cross is not Reached");

     // return false; // ❌ no cross yet
   }
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
         {
            tradeCount++;

         }
      }
   }

   if(direction == OP_BUY)
   {
      openTradeBuyCount=tradeCount;
   }
   else
   {
      openTradeSellCount=tradeCount;
   }

   // 🔒 Limit 2 trades after cross
   if(tradeCount >= SeqBuyMaxOrders)
   {
      Print("Blocked: Max "+tradeCount+"/"+SeqBuyMaxOrders+" trades reached after last EMA cross");
       
      g_blockReason = "Blocked: Max "+tradeCount+"/"+SeqBuyMaxOrders+" trades reached after last EMA cross";
      return false;
   }

   // // 🔹 Trend validation
   // double emaFast = iMA(Symbol(), 0, FastEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   // double emaSlow = iMA(Symbol(), 0, SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   // if(direction == OP_BUY && emaFast <= emaSlow)
   // {
   //    Print("Blocked: Buy Direction is not clear emaFast emaSlow EMA cross");

   //    return false;
   // }

   // if(direction == OP_SELL && emaFast >= emaSlow)
   //    {
   //    Print("Blocked: SELL Direction is not clear emaFast emaSlow EMA cross");

   //    return false;
   // }
   return true;
}


 double GetEMAGapPoints(int fastPeriod, int slowPeriod, int shift = 0)
{
   double emaFast = iMA(Symbol(), 0, fastPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);
   double emaSlow = iMA(Symbol(), 0, slowPeriod, 0, MODE_EMA, PRICE_CLOSE, shift);

   double gap = MathAbs(emaFast - emaSlow);

   if(gap/Point<100)
   {
       g_lastCrossTime = TimeCurrent();

         // Print("EMA NEAR CROSS DETECTED at: ", TimeToString(g_lastCrossTime), " | Gap: ", DoubleToString(gap/Point,1), " pts");

   }

   return gap / Point; // return in points
}
string trend="";
void ShowEMAGapLabel()
{
   string name = "EMA_GAP_LABEL";

   double gap = GetEMAGapPoints(FastEMA, SlowEMA);
   string text = "EMA Gap: " + DoubleToString(gap, 1) + " pts. "+IntegerToString(SeqBuyMaxOrders)+"/"+IntegerToString(SeqSellMaxOrders)+" TREND "+trendnumber;
//Print("Current EMA Gap: ", DoubleToString(gap,1), " pts. Max Orders: ", SeqBuyMaxOrders, "/", SeqSellMaxOrders);
  

  text=text+" B("+openTradeBuyCount+") S("+openTradeSellCount+")";
  text=text+"  :"+trend; 


  
   if(ObjectFind(0, name) == -1)
   { 
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
}
      // ✅ RIGHT TOP
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 500);   // from right
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 50);   // from top
if(gap<=EMAGAP3000Condition)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
else if(gap<=10000)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
else
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ShowBlockReasonLabel();
}

void ShowBlockReasonLabel()
{
   string name = "BLOCK_REASON_LABEL";

   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER,   CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
      ObjectSetString( 0, name, OBJPROP_FONT,     "Arial Bold");
   }

   // Centre horizontally, position vertically — update every tick so changes take effect immediately
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = chartWidth / 2 - 200;
   if(x < 0) x = 0;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 80);

   if(g_blockReason == "")
   {
      ObjectSetString(0, name, OBJPROP_TEXT, "");
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
      ObjectSetString( 0, name, OBJPROP_TEXT,  "BLOCKED: " + g_blockReason);
   }
}

// Returns:
// true  = NO TRADE zone
// false = market is tradable
bool IsNoTradeZoneBTC()
{
   if(Bars < 15) return true;

   // --- EMA flat check
   double ema9_1  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_1 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50_1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);

   double emaGap9_20  = MathAbs(ema9_1 - ema20_1) / Point;
   double emaGap20_50 = MathAbs(ema20_1 - ema50_1) / Point;

   // --- recent range box
   int lookback = 8;
   double highest = High[1];
   double lowest  = Low[1];

   for(int i = 1; i <= lookback; i++)
   {
      if(High[i] > highest) highest = High[i];
      if(Low[i]  < lowest)  lowest  = Low[i];
   }

   double boxRange = (highest - lowest) / Point;

   // --- candle body analysis
   int smallBodyCount = 0;
   int overlapCount   = 0;

   for(int j = 1; j <= 5; j++)
   {
      double body = MathAbs(Close[j] - Open[j]) / Point;
      if(body < 200) smallBodyCount++;

      // overlap with previous candle
      double highA = High[j];
      double lowA  = Low[j];
      double highB = High[j+1];
      double lowB  = Low[j+1];

      double overlapHigh = MathMin(highA, highB);
      double overlapLow  = MathMax(lowA, lowB);

      if(overlapHigh > overlapLow)
      {
         double overlapSize = (overlapHigh - overlapLow) / Point;
         double rangeA = (highA - lowA) / Point;
         if(rangeA > 0 && overlapSize >= rangeA * 0.5)
            overlapCount++;
      }
   }

   // --- direction consistency
   int upCount = 0;
   int downCount = 0;

   for(int k = 1; k <= 5; k++)
   {
      double avgNow  = (High[k] + Low[k]) / 2.0;
      double avgPrev = (High[k+1] + Low[k+1]) / 2.0;

      if(avgNow > avgPrev) upCount++;
      if(avgNow < avgPrev) downCount++;
   }

   bool mixedDirection = (upCount >= 2 && downCount >= 2);

   // --- no trade conditions for BTCUSD
   bool emaFlat      = (emaGap9_20 < 500);
   bool emaCompressed= (emaGap20_50 < 1200);
   bool tightBox     = (boxRange < 2500);
   bool smallBodies  = (smallBodyCount >= 3);
   bool heavyOverlap = (overlapCount >= 3);

   if((emaFlat && tightBox) ||
      (emaCompressed && smallBodies) ||
      (heavyOverlap && mixedDirection) ||
      (tightBox && mixedDirection))
   {
      return true;
   }

   return false;
}
//+------------------------------------------------------------------+
//| Market strength classifier                                       |
//| Returns:                                                         |
//|  2 = strong buy                                                  |
//|  1 = weak buy                                                    |
//|  0 = sideways / no trade                                         |
//| -1 = weak sell                                                   |
//| -2 = strong sell                                                 |
//+------------------------------------------------------------------+


// Returns:
//  0  = no trend / sideways
//  1  = weak buy   (medium trend)
//  2  = strong buy (medium trend)
//  3  = weak buy   (long trend)
//  4  = strong buy (long trend)
// -1  = weak sell   (medium trend)
// -2  = strong sell (medium trend)
// -3  = weak sell   (long trend)
// -4  = strong sell (long trend)

 
// Returns:
//  0  = no trend / sideways / blocked
//  1  = weak buy   (medium trend)
//  2  = strong buy (medium trend)
//  3  = weak buy   (long trend)
//  4  = strong buy (long trend)
// -1  = weak sell   (medium trend)
// -2  = strong sell (medium trend)
// -3  = weak sell   (long trend)
// -4  = strong sell (long trend)

// Global loss tracker — declare outside function in your EA
// int g_consecutiveLosses = 0;

int GetMarketTrendStrengthCluade()
{
   if(Bars < 250) return 0;

   // ===================================================
   // 1. TRADING TIME FILTER
   // ===================================================
   int currentHour = TimeHour(TimeCurrent());
   bool goodTradingTime =
      (currentHour >= 9  && currentHour <= 12) ||  // London open
      (currentHour >= 14 && currentHour <= 17);     // NY open

   if(!goodTradingTime) return 0;

   // ===================================================
   // 2. CONSECUTIVE LOSS BLOCK
   // ===================================================
   if(g_consecutiveLosses >= 2) return 0;

   // ===================================================
   // 3. EMA VALUES
   // ===================================================
   double ema9_1   = iMA(Symbol(), 0,   9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema9_2   = iMA(Symbol(), 0,   9, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema20_1  = iMA(Symbol(), 0,  20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_2  = iMA(Symbol(), 0,  20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema50_1  = iMA(Symbol(), 0,  50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50_2  = iMA(Symbol(), 0,  50, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema200_1 = iMA(Symbol(), 0, 200, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200_2 = iMA(Symbol(), 0, 200, 0, MODE_EMA, PRICE_CLOSE, 2);

   double price = Close[1];

   // ===================================================
   // 4. EMA DIRECTION
   // ===================================================
   bool emaUpStrong =
      (price   > ema9_1)   &&
      (ema9_1  > ema20_1)  &&
      (ema20_1 > ema50_1)  &&
      (ema9_1  > ema9_2)   &&
      (ema20_1 >= ema20_2) &&
      (ema50_1 >= ema50_2);

   bool emaDownStrong =
      (price   < ema9_1)   &&
      (ema9_1  < ema20_1)  &&
      (ema20_1 < ema50_1)  &&
      (ema9_1  < ema9_2)   &&
      (ema20_1 <= ema20_2) &&
      (ema50_1 <= ema50_2);

   bool emaUpWeak =
      (price  > ema9_1)  &&
      (ema9_1 > ema20_1) &&
      (ema9_1 > ema9_2);

   bool emaDownWeak =
      (price  < ema9_1)  &&
      (ema9_1 < ema20_1) &&
      (ema9_1 < ema9_2);

   // ===================================================
   // 5. EMA200 MACRO FILTER
   // ===================================================
   bool macroUp   = (price > ema200_1 && ema200_1 >= ema200_2);
   bool macroDown = (price < ema200_1 && ema200_1 <= ema200_2);

   // ===================================================
   // 6. HIGHER TIMEFRAME FILTER (H4)
   // ===================================================
   double htf_ema50  = iMA(Symbol(), PERIOD_H4, 50,  0, MODE_EMA, PRICE_CLOSE, 1);
   double htf_ema200 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);
   double htf_price  = iClose(Symbol(), PERIOD_H4, 1);

   bool htfBullish = (htf_price > htf_ema50 && htf_ema50 > htf_ema200);
   bool htfBearish = (htf_price < htf_ema50 && htf_ema50 < htf_ema200);

   // ===================================================
   // 7. EMA GAPS
   // ===================================================
   double gap9_20  = MathAbs(ema9_1  - ema20_1) / Point;
   double gap20_50 = MathAbs(ema20_1 - ema50_1) / Point;

   // ===================================================
   // 8. CANDLE MIDPOINT MOVEMENT
   // ===================================================
   double avg1 = (High[1] + Low[1]) / 2.0;
   double avg2 = (High[2] + Low[2]) / 2.0;
   double avg3 = (High[3] + Low[3]) / 2.0;
   double avg4 = (High[4] + Low[4]) / 2.0;
   double avg5 = (High[5] + Low[5]) / 2.0;

   double step1 = (avg1 - avg2) / Point;
   double step2 = (avg2 - avg3) / Point;
   double step3 = (avg3 - avg4) / Point;

   bool avgUp   = (step1 > 0 && step2 > 0) || (step1 > 0 && step2 > 0 && step3 > 0);
   bool avgDown = (step1 < 0 && step2 < 0) || (step1 < 0 && step2 < 0 && step3 < 0);

   double highestAvg = avg1;
   double lowestAvg  = avg1;
   for(int i = 1; i <= 5; i++)
   {
      double avgI = (High[i] + Low[i]) / 2.0;
      if(avgI > highestAvg) highestAvg = avgI;
      if(avgI < lowestAvg)  lowestAvg  = avgI;
   }
   double avgRangePoints = (highestAvg - lowestAvg) / Point;

   // ===================================================
   // 9. CANDLE SIZE
   // ===================================================
   double c1Height = (High[1] - Low[1]) / Point;
   double c2Height = (High[2] - Low[2]) / Point;

   double b1 = MathAbs(Close[1] - Open[1]) / Point;
   double b2 = MathAbs(Close[2] - Open[2]) / Point;
   double b3 = MathAbs(Close[3] - Open[3]) / Point;

   // ===================================================
   // 10. ATR MOMENTUM
   // ===================================================
   double atrPoints = iATR(Symbol(), 0, 14, 1) / Point;

   bool momentumWeak   = (atrPoints >= 1000);
   bool momentumStrong = (atrPoints >= 2000);

   // ===================================================
   // 11. TREND CONSISTENCY (EMA50 slope over 50 bars)
   // ===================================================
   int ema50UpCount   = 0;
   int ema50DownCount = 0;

   for(int k = 1; k <= 50; k++)
   {
      double eA = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, k);
      double eB = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, k + 1);
      if(eA > eB) ema50UpCount++;
      if(eA < eB) ema50DownCount++;
   }

   bool trendConsistentUp   = (ema50UpCount   >= 35);
   bool trendConsistentDown = (ema50DownCount >= 35);

   // ===================================================
   // 12. TREND AGE
   // ===================================================
   int alignedUpBars   = 0;
   int alignedDownBars = 0;

   for(int m = 1; m <= 20; m++)
   {
      double e9  = iMA(Symbol(), 0,  9, 0, MODE_EMA, PRICE_CLOSE, m);
      double e20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, m);
      double e50 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, m);
      if(e9 > e20 && e20 > e50) alignedUpBars++;
      if(e9 < e20 && e20 < e50) alignedDownBars++;
   }

   bool trendMatureUp   = (alignedUpBars   >= 10);
   bool trendMatureDown = (alignedDownBars >= 10);

   // ===================================================
   // 13. PULLBACK FILTER
   // ===================================================
   double pullbackZone = 500;
   bool pullbackBuy  = (MathAbs(price - ema9_1) / Point <= pullbackZone);
   bool pullbackSell = (MathAbs(price - ema9_1) / Point <= pullbackZone);

   // ===================================================
   // 14. HIGHER LOW / LOWER HIGH CONFIRMATION
   // ===================================================
   bool higherLow  = (Low[1]  > Low[2]  && Low[2]  > Low[3]);
   bool lowerHigh  = (High[1] < High[2] && High[2] < High[3]);

   // ===================================================
   // 15. ROOM TO MOVE FILTER
   // ===================================================
   double recentHigh = High[1];
   double recentLow  = Low[1];

   for(int r = 1; r <= 20; r++)
   {
      if(High[r] > recentHigh) recentHigh = High[r];
      if(Low[r]  < recentLow)  recentLow  = Low[r];
   }

   double roomUp   = (recentHigh - Close[1]) / Point;
   double roomDown = (Close[1]   - recentLow) / Point;

   bool hasRoomUp   = (roomUp   >= 1500);
   bool hasRoomDown = (roomDown >= 1500);

   // ===================================================
   // 16. SPIKE FILTER — block entry after explosive move
   // ===================================================
   double prevMoveFast = MathAbs(Close[3] - Close[8]) / Point;
   bool afterDownSpike = (prevMoveFast >= 3000 && Close[3] < Close[8]);
   bool afterUpSpike   = (prevMoveFast >= 3000 && Close[3] > Close[8]);

   // ===================================================
   // 17. SWING HIGH / LOW — TREND DISTANCE
   // ===================================================
   double swingLowMedium  = Low[1],  swingHighMedium = High[1];
   double swingLowLong    = Low[1],  swingHighLong   = High[1];

   for(int j = 1; j <= 200; j++)
   {
      if(j <= 100)
      {
         if(Low[j]  < swingLowMedium)  swingLowMedium  = Low[j];
         if(High[j] > swingHighMedium) swingHighMedium = High[j];
      }
      if(Low[j]  < swingLowLong)  swingLowLong  = Low[j];
      if(High[j] > swingHighLong) swingHighLong = High[j];
   }

   double risePointsMedium = (Close[1] - swingLowMedium)  / Point;
   double fallPointsMedium = (swingHighMedium - Close[1]) / Point;
   double risePointsLong   = (Close[1] - swingLowLong)    / Point;
   double fallPointsLong   = (swingHighLong  - Close[1])  / Point;

   bool mediumUp   = (risePointsMedium >= 8000);
   bool mediumDown = (fallPointsMedium >= 8000);
   bool longUp     = (risePointsLong   >= 15000);
   bool longDown   = (fallPointsLong   >= 15000);

   // ===================================================
   // 18. THRESHOLDS
   // ===================================================
   double strongGap9_20     = 800;
   double strongGap20_50    = 1200;
   double weakGap9_20Min    = 250;
   double minAvgRangeWeak   = 800;
   double minAvgRangeStrong = 1500;
   double minHeightWeak     = 250;
   double minHeightStrong   = 500;
   double minBodyWeak       = 100;
   double minBodyStrong     = 200;

   // ===================================================
   // 19. SIDEWAYS FILTER
   // ===================================================
   bool sideways =
      (gap9_20 < weakGap9_20Min) ||
      (avgRangePoints < minAvgRangeWeak) ||
      ((b1 < minBodyWeak) && (b2 < minBodyWeak) && (b3 < minBodyWeak));

   if(sideways) return 0;

   // ===================================================
   // LONG TREND SIGNALS  (highest priority)
   // ===================================================

   // Strong BUY - Long
   if(emaUpStrong        &&
      avgUp              &&
      longUp             &&
      macroUp            &&
      htfBullish         &&
      trendConsistentUp  &&
      trendMatureUp      &&
      pullbackBuy        &&
      higherLow          &&
      hasRoomUp          &&
      !afterDownSpike    &&
      momentumStrong     &&
      gap9_20  >= strongGap9_20   &&
      gap20_50 >= strongGap20_50  &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong         &&
      b2 >= minBodyStrong)
      return 4;

   // Strong SELL - Long
   if(emaDownStrong        &&
      avgDown               &&
      longDown              &&
      macroDown             &&
      htfBearish            &&
      trendConsistentDown   &&
      trendMatureDown       &&
      pullbackSell          &&
      lowerHigh             &&
      hasRoomDown           &&
      !afterUpSpike         &&
      momentumStrong        &&
      gap9_20  >= strongGap9_20   &&
      gap20_50 >= strongGap20_50  &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong         &&
      b2 >= minBodyStrong)
      return -4;

   // Weak BUY - Long
   if(emaUpWeak           &&
      avgUp               &&
      longUp              &&
      macroUp             &&
      htfBullish          &&
      trendConsistentUp   &&
      trendMatureUp       &&
      pullbackBuy         &&
      higherLow           &&
      hasRoomUp           &&
      !afterDownSpike     &&
      momentumWeak        &&
      gap9_20 >= weakGap9_20Min   &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak   &&
      b1 >= minBodyWeak)
      return 3;

   // Weak SELL - Long
   if(emaDownWeak          &&
      avgDown              &&
      longDown             &&
      macroDown            &&
      htfBearish           &&
      trendConsistentDown  &&
      trendMatureDown      &&
      pullbackSell         &&
      lowerHigh            &&
      hasRoomDown          &&
      !afterUpSpike        &&
      momentumWeak         &&
      gap9_20 >= weakGap9_20Min   &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak   &&
      b1 >= minBodyWeak)
      return -3;

   // ===================================================
   // MEDIUM TREND SIGNALS
   // ===================================================

   // Strong BUY - Medium
   if(emaUpStrong        &&
      avgUp              &&
      mediumUp           &&
      macroUp            &&
      htfBullish         &&
      trendMatureUp      &&
      higherLow          &&
      hasRoomUp          &&
      !afterDownSpike    &&
      momentumStrong     &&
      gap9_20  >= strongGap9_20   &&
      gap20_50 >= strongGap20_50  &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong         &&
      b2 >= minBodyStrong)
      return 2;

   // Strong SELL - Medium
   if(emaDownStrong       &&
      avgDown             &&
      mediumDown          &&
      macroDown           &&
      htfBearish          &&
      trendMatureDown     &&
      lowerHigh           &&
      hasRoomDown         &&
      !afterUpSpike       &&
      momentumStrong      &&
      gap9_20  >= strongGap9_20   &&
      gap20_50 >= strongGap20_50  &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong         &&
      b2 >= minBodyStrong)
      return -2;

   // Weak BUY - Medium
   if(emaUpWeak          &&
      avgUp              &&
      mediumUp           &&
      macroUp            &&
      htfBullish         &&
      trendMatureUp      &&
      higherLow          &&
      hasRoomUp          &&
      !afterDownSpike    &&
      momentumWeak       &&
      gap9_20 >= weakGap9_20Min   &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak   &&
      b1 >= minBodyWeak)
      return 1;

   // Weak SELL - Medium
   if(emaDownWeak         &&
      avgDown             &&
      mediumDown          &&
      macroDown           &&
      htfBearish          &&
      trendMatureDown     &&
      lowerHigh           &&
      hasRoomDown         &&
      !afterUpSpike       &&
      momentumWeak        &&
      gap9_20 >= weakGap9_20Min   &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak   &&
      b1 >= minBodyWeak)
      return -1;

   return 0;
}

// ===================================================
// Call this from your EA after each closed trade
// ===================================================
// void UpdateLossTracker(bool wasLoss)
// {
//    if(wasLoss)
//       g_consecutiveLosses++;
//    else
//       g_consecutiveLosses = 0; // reset on any win
// }

int GetMarketTrendStrength()
{
   if(Bars < 10) return 0;

   // ===== EMA values =====
   double ema9_1  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 1);
   double ema9_2  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 2);

   double ema20_1 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_2 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 2);

   double ema50_1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50_2 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 2);

   double price = Close[1];

   // ===== EMA direction =====
   bool emaUpStrong =
      (price   > ema9_1)  &&
      (ema9_1  > ema20_1) &&
      (ema20_1 > ema50_1) &&
      (ema9_1  > ema9_2)  &&
      (ema20_1 >= ema20_2) &&
      (ema50_1 >= ema50_2);

   bool emaDownStrong =
      (price   < ema9_1)  &&
      (ema9_1  < ema20_1) &&
      (ema20_1 < ema50_1) &&
      (ema9_1  < ema9_2)  &&
      (ema20_1 <= ema20_2) &&
      (ema50_1 <= ema50_2);

   bool emaUpWeak =
      (price > ema9_1) &&
      (ema9_1 > ema20_1) &&
      (ema9_1 > ema9_2);

   bool emaDownWeak =
      (price < ema9_1) &&
      (ema9_1 < ema20_1) &&
      (ema9_1 < ema9_2);

   // ===== EMA gaps =====
   double gap9_20  = MathAbs(ema9_1  - ema20_1) / Point;
   double gap20_50 = MathAbs(ema20_1 - ema50_1) / Point;

   // ===== Candle movement =====
   double avg1 = (High[1] + Low[1]) / 2.0;
   double avg2 = (High[2] + Low[2]) / 2.0;
   double avg3 = (High[3] + Low[3]) / 2.0;
   double avg4 = (High[4] + Low[4]) / 2.0;
   double avg5 = (High[5] + Low[5]) / 2.0;

   double step1 = (avg1 - avg2) / Point;
   double step2 = (avg2 - avg3) / Point;
   double step3 = (avg3 - avg4) / Point;
   double step4 = (avg4 - avg5) / Point;

   bool avgUp =
      (step1 > 0 && step2 > 0) ||
      (step1 > 0 && step2 > 0 && step3 > 0);

   bool avgDown =
      (step1 < 0 && step2 < 0) ||
      (step1 < 0 && step2 < 0 && step3 < 0);

   double highestAvg = avg1;
   double lowestAvg  = avg1;

   for(int i = 1; i <= 5; i++)
   {
      double avg = (High[i] + Low[i]) / 2.0;
      if(avg > highestAvg) highestAvg = avg;
      if(avg < lowestAvg)  lowestAvg  = avg;
   }

   double avgRangePoints = (highestAvg - lowestAvg) / Point;

   // ===== Candle size =====
   double c1Height = (High[1] - Low[1]) / Point;
   double c2Height = (High[2] - Low[2]) / Point;
   double c3Height = (High[3] - Low[3]) / Point;

   double b1 = MathAbs(Close[1] - Open[1]) / Point;
   double b2 = MathAbs(Close[2] - Open[2]) / Point;
   double b3 = MathAbs(Close[3] - Open[3]) / Point;

   // ===== BTCUSD values - tune if needed =====
   double strongGap9_20   = 800;
   double strongGap20_50  = 1200;
   double weakGap9_20Min  = 250;
   double minAvgRangeWeak = 800;
   double minAvgRangeStrong = 1500;
   double minHeightWeak   = 250;
   double minHeightStrong = 500;
   double minBodyWeak     = 100;
   double minBodyStrong   = 200;

   // ===== Sideways filter =====
   bool sideways =
      (gap9_20 < weakGap9_20Min) ||
      (avgRangePoints < minAvgRangeWeak) ||
      ((b1 < minBodyWeak) && (b2 < minBodyWeak) && (b3 < minBodyWeak));

   if(sideways)
      return 0;

   // ===== Strong BUY =====
   if(emaUpStrong &&
      avgUp &&
      gap9_20 >= strongGap9_20 &&
      gap20_50 >= strongGap20_50 &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong &&
      b2 >= minBodyStrong)
   {
      return 2;
   }

   // ===== Strong SELL =====
   if(emaDownStrong &&
      avgDown &&
      gap9_20 >= strongGap9_20 &&
      gap20_50 >= strongGap20_50 &&
      avgRangePoints >= minAvgRangeStrong &&
      c1Height >= minHeightStrong &&
      c2Height >= minHeightStrong &&
      b1 >= minBodyStrong &&
      b2 >= minBodyStrong)
   {
      return -2;
   }

   // ===== Weak BUY =====
   if(emaUpWeak &&
      avgUp &&
      gap9_20 >= weakGap9_20Min &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak &&
      b1 >= minBodyWeak)
   {
      return 1;
   }

   // ===== Weak SELL =====
   if(emaDownWeak &&
      avgDown &&
      gap9_20 >= weakGap9_20Min &&
      avgRangePoints >= minAvgRangeWeak &&
      c1Height >= minHeightWeak &&
      b1 >= minBodyWeak)
   {
      return -1;
   }

   return 0;
}
void createNewOrder3000BeforeCandle()
{

   double gap = GetEMAGapPoints(FastEMA, SlowEMA);

   // Print("gap","-",gap," - ",DoubleToString(gap,1));


// if(gap<2000)
//    {
//        CloseAllSellOrders(true, "EMA Gap < 2000 pts");
//        CloseAllBuyOrders(true, "EMA Gap < 2000 pts");
//    }

   //SeqBuyMaxOrders=gap/1000;
   //SeqSellMaxOrders=gap/1000;

   trend="";

   //  SeqSellMaxOrders=defaultMaxSellOrders+4;

   // if(IsNoTradeZoneBTC())
   // {
   //    Print("BTCUSD detected: Market is in NO TRADE zone based on EMA and price action analysis.");
   //    g_blockReason = "BTCUSD detected: Market is in NO TRADE zone based on EMA and price action analysis.";

   //      Print("NO Trade ZONE");
   //    trend="NO TRADE ZONE";
   //    return;
   // }

   int trendnumber = 0;

   if(gap>EMAGAP3000Condition)
   {

       trendnumber = GetMarketTrendStrength();

   if(trendnumber == 1 || trendnumber == 3 || trendnumber == 2 || trendnumber == 4)
   {
      Print("Strong BUY trend");
      trend="UPTREND";
      ProcessSeqBuyOrders(true,true,true);
   }
   else if(trendnumber == 0)
   {
      Print("Weak BUY trend");
      trend="Weak BUY trend";
      g_blockReason = "EMA Gap Weak trend detected: "+trend;
   }
   else if(trendnumber == 0)
   {
      Print("Weak SELL trend");
      trend="Weak SELL trend";

      g_blockReason = "EMA Gap Weak trend detected: "+trend;

   }
   else if(trendnumber == -1 || trendnumber == -2 || trendnumber == -3 || trendnumber == -4)
   {
      Print("Strong SELL trend");
      trend="DOWNTREND";
       ProcessSeqSellOrders(true,true,true);
   }
   else
   {
      Print("SIDEWAYS / NO TRADE");
      trend="SIDEWAYS / NO TRADE";

      g_blockReason = "EMA Gap > "+EMAGAP3000Condition+" pts but Market is SIDEWAYS / NO CLEAR TREND";
   }
   }
   else
   {
      Print("EMA Gap is less than "+EMAGAP3000Condition+" pts: No new orders allowed");
      trend="";

      g_blockReason = "EMA Gap is less than "+EMAGAP3000Condition+" pts: No new orders allowed";   
   }

   trend=trend+" "+trendnumber;
   g_blockReason = g_blockReason+" "+trendnumber;
     
   
/*
   if(gap>20000 && enableEMAGapDynamicMaxOrders)
   {
      //SeqBuyMaxOrders=defaultMaxBuyOrders+4;
      // SeqSellMaxOrders=defaultMaxSellOrders+4;
      //g_blockReason = "EMA Gap > 20000 pts: Allowing up to "+ SeqBuyMaxOrders+ " new orders. Current gap: "+ DoubleToString(gap,1)+ " pts";
      // Print("EMA Gap > 20000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
   }
   else
   if(gap>15000 && enableEMAGapDynamicMaxOrders)
   {
      //SeqBuyMaxOrders=defaultMaxBuyOrders+3;
      //SeqSellMaxOrders=defaultMaxSellOrders+3;
     // g_blockReason = "EMA Gap > 10000 pts: Allowing up to "+ SeqBuyMaxOrders+ " new orders. Current gap: "+ DoubleToString(gap,1)+ " pts";

      // Print("EMA Gap > 10000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
    } else
   if(gap>8000 && enableEMAGapDynamicMaxOrders)
   {
      //SeqBuyMaxOrders=defaultMaxBuyOrders+2;
      //SeqSellMaxOrders=defaultMaxSellOrders+2;
     // g_blockReason = "EMA Gap > 10000 pts: Allowing up to "+ SeqBuyMaxOrders+ " new orders. Current gap: "+ DoubleToString(gap,1)+ " pts";

      // Print("EMA Gap > 10000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
   }else
   if(gap>5000 && enableEMAGapDynamicMaxOrders)
   {
     // SeqBuyMaxOrders=defaultMaxBuyOrders+1;
      //SeqSellMaxOrders=defaultMaxSellOrders+1;;
      //g_blockReason = "EMA Gap > 5000 pts: Allowing up to "+ SeqBuyMaxOrders+" new orders. Current gap: "+ DoubleToString(gap,1)+ " pts";

      // Print("EMA Gap > 10000 pts: Allowing up to ", SeqBuyMaxOrders, " new orders. Current gap: ", DoubleToString(gap,1), " pts");
   }
   else
   {
      SeqBuyMaxOrders=defaultMaxBuyOrders;
      SeqSellMaxOrders=defaultMaxSellOrders;
     // g_blockReason = "EMA Gap <= 3000 pts: Using default max orders. Current gap: "+DoubleToString(gap,1)+ " pts";

      // Print("EMA Gap <= 10000 pts: Using default max orders. Current gap: ", DoubleToString(gap,1), " pts");
      }

      */


/*
    if(  gap>EMAGAP3000Condition)
    {

 double ema9_0  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema9_1  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 1);

   double ema20_0 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema20_1 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   double ema50_0 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema50_1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);

   double price = Close[0];

   double emaGap = MathAbs(ema9 - ema20) / Point;


   bool emaUp =
      (ema9_0 > ema9_1) &&
      (ema20_0 >= ema20_1) &&
      (ema50_0 >= ema50_1);

   bool emaDown =
      (ema9_0 < ema9_1) &&
      (ema20_0 <= ema20_1) &&
      (ema50_0 <= ema50_1);

   // UPTREND
   if(price > ema9_0 && ema9_0 > ema20_0 && ema20_0 > ema50_0 && emaUp && emaGap>500)
      
      {
         trend="UPTREND";
            ProcessSeqBuyOrders(true);

      }

   // DOWNTREND
  else if(price < ema9_0 && ema9_0 < ema20_0 && ema20_0 < ema50_0 && emaDown && emaGap>500)
      {
         trend="DOWNTREND";
         ProcessSeqSellOrders(true);
      }
      {
   g_blockReason = "Gap above "+EMAGAP3000Condition+" but No UPTREND or NO DownTREND detected";

      }

    }
    else
    {
      g_blockReason = "EMA GAP is less than "+EMAGAP3000Condition+" — orders are blocked";
    }
 
*/
/*

   double ema9  = iMA(Symbol(), 0, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
double ema20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);
double ema50 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
double price = Close[0];

 trend = "SIDEWAYS";

if(price > ema9 && ema9 > ema20 && ema20 > ema50)
{
   trend = "UPTREND";
   // g_blockReason = "";
   ProcessSeqBuyOrders(true);
}
else if(price < ema9 && ema9 < ema20 && ema20 < ema50)
{


   trend = "DOWNTREND";
   // g_blockReason = "";
   ProcessSeqSellOrders(true);
}
else
{
   // Print("Gap above "+EMAGAP3000Condition+" but No UPTREND or NO DownTREND detected");
   g_blockReason = "Gap above "+EMAGAP3000Condition+" but No UPTREND or NO DownTREND detected";
}
 
   // Print("Trend is ", trend);
  
    }
    else
    {
   g_blockReason = "EMA GAP is less than "+EMAGAP3000Condition+" — orders are blocked";
    

    }
*/

   //  Print(g_blockReason);
}