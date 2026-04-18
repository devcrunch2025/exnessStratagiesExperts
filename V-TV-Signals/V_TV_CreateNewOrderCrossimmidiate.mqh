//+------------------------------------------------------------------+
//| Returns: 1 = BUY, -1 = SELL, 0 = No trade                       |
//| Logic: EMA20 vs EMA50 — first fresh cross on closed bars only    |
//+------------------------------------------------------------------+
// Returns:
//  1 = BUY signal
// -1 = SELL signal
//  0 = no signal
// Returns:
//  1 = BUY
// -1 = SELL
//  0 = no signal
      // ProcessSeqSellOrders(false,false,false); // checkpattern, check3000, checkMaxorders
      // ProcessSeqBuyOrders(false,false,false); // checkpattern, check3000, checkMaxorders
//
datetime lastBuyCandleTime = 0;
datetime lastSellCandleTime = 0;

// Returns:
//  1 = BUY reversal after downtrend
// -1 = SELL reversal after uptrend
//  0 = no signal
// Returns:
//  1 = BUY
// -1 = SELL
//  0 = no signal
// Returns:
//  1 = BUY
// -1 = SELL
//  0 = no signal
//+------------------------------------------------------------------+
//| BTCUSD Trend Detection with EMA + Candle Structure + Flat Filter |
//| Returns:  1 = BUY, -1 = SELL, 0 = NO SIGNAL                      |
//+------------------------------------------------------------------+
int DetectBTCUSDTrendSignal()
{
   static int lastTrendSignal = 0;   // 1=BUY, -1=SELL, 0=none

   if(Bars < 8)
      return 0;

   // ================= EMA TREND FILTER =================
   double ema5_1  = iMA(Symbol(), 0, 5,  0, MODE_EMA, PRICE_CLOSE, 1);
   double ema5_2  = iMA(Symbol(), 0, 5,  0, MODE_EMA, PRICE_CLOSE, 2);

   double ema20_1 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_2 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool emaBuyTrend  = (ema5_1 > ema20_1 && ema5_1 > ema5_2 && ema20_1 >= ema20_2);
   bool emaSellTrend = (ema5_1 < ema20_1 && ema5_1 < ema5_2 && ema20_1 <= ema20_2);

   // Optional: avoid when EMA gap too small
   double emaGapPoints = MathAbs(ema5_1 - ema20_1) / Point;
   double minEMAGapPoints = 500;   // BTCUSD starting value

   if(emaGapPoints < minEMAGapPoints)
   {
      lastTrendSignal = 0;
      return 0;
   }

   // ================= FLAT / STRAIGHT-LINE FILTER =================
   int flatLookback = 5;

   double avgNewest = (High[1] + Low[1]) / 2.0;
   double avgOldest = (High[flatLookback] + Low[flatLookback]) / 2.0;

   double avgMovePoints = MathAbs(avgNewest - avgOldest) / Point;

   double highestAvg = avgNewest;
   double lowestAvg  = avgNewest;

   for(int i = 1; i <= flatLookback; i++)
   {
      double avg = (High[i] + Low[i]) / 2.0;
      if(avg > highestAvg) highestAvg = avg;
      if(avg < lowestAvg)  lowestAvg  = avg;
   }

   double avgRangePoints = (highestAvg - lowestAvg) / Point;

   double minAvgMove  = 1000;   // BTCUSD
   double minAvgRange = 1500;   // BTCUSD

   if(avgMovePoints < minAvgMove || avgRangePoints < minAvgRange)
   {
      lastTrendSignal = 0;
      return 0;
   }

   // ================= CANDLE STRUCTURE =================
   bool sell1 = (High[1] < High[2] && Low[1] < Low[2]);
   bool sell2 = (High[2] < High[3] && Low[2] < Low[3]);

   bool buy1  = (High[1] > High[2] && Low[1] > Low[2]);
   bool buy2  = (High[2] > High[3] && Low[2] > Low[3]);

   // ================= HEALTHY CANDLE FILTER =================
   double candle1Height = (High[1] - Low[1]) / Point;
   double candle2Height = (High[2] - Low[2]) / Point;
   double totalHeight   = candle1Height + candle2Height;

   double body1 = MathAbs(Close[1] - Open[1]) / Point;
   double body2 = MathAbs(Close[2] - Open[2]) / Point;

   double minEachHeight  = 500;   // BTCUSD
   double minTotalHeight = 1200;  // BTCUSD
   double minEachBody    = 200;   // BTCUSD

   if(candle1Height < minEachHeight || candle2Height < minEachHeight)
   {
      lastTrendSignal = 0;
      return 0;
   }

   if(totalHeight < minTotalHeight)
   {
      lastTrendSignal = 0;
      return 0;
   }

   if(body1 < minEachBody || body2 < minEachBody)
   {
      lastTrendSignal = 0;
      return 0;
   }

   // ================= FINAL SELL =================
   if(emaSellTrend && sell1 && sell2)
   {
      if(lastTrendSignal != -1)
      {
         lastTrendSignal = -1;
         return -1;
      }
      return 0;
   }

   // ================= FINAL BUY =================
   if(emaBuyTrend && buy1 && buy2)
   {
      if(lastTrendSignal != 1)
      {
         lastTrendSignal = 1;
         return 1;
      }
      return 0;
   }

   // ================= RESET =================
   lastTrendSignal = 0;
   return 0;
}
int DetectPrevCandleAndCurrentMoveSignal()
{

   return 0;

      // CancelExpiredPendingOrders(10, 12345);
      CancelExpiredPendingOrders(60, SeqBuyMagicNo);
      CancelExpiredPendingOrders(60, SeqSellMagicNo);





 static datetime lastTradeTime = 0;

   // minimum 10 sec gap
   if(TimeCurrent() - lastTradeTime < 10)
      return 0;

   int signal = DetectBTCUSDTrendSignal();

   if(signal == 0)
      return 0;

   // ---------------- Count existing orders ----------------
   int buyCount = 0;
   int sellCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;

      if(OrderType() == OP_BUY)  buyCount++;
      if(OrderType() == OP_SELL) sellCount++;
   }

   // ---------------- BUY ----------------
   if(signal == 1)
   {
      if(buyCount == 0)   // only 1 BUY allowed
      {
         ProcessSeqBuyOrders(false, false, false);
             //  PlaceTrendPendingOrderSafe(1, 0.01, 1000, 5, 12345);

         lastTradeTime = TimeCurrent();
      }
   }

   // ---------------- SELL ----------------
   if(signal == -1)
   {
      if(sellCount == 0)  // only 1 SELL allowed
      {
         ProcessSeqSellOrders(false, false, false);
              // PlaceTrendPendingOrderSafe(-1, 0.01, 1000, 5, 12345);

         lastTradeTime = TimeCurrent();
      }
   }











   return 0;

bool checkPattern = false; // Set to true to enable pattern checks in order processing (e.g. no buy/sell zones, EMA gap, etc.)
bool check3000      = false;
   bool checkMaxOrders = false;
   double gap = GetEMAGapPoints(FastEMA, SlowEMA);
/*
   if(  gap>1000)

  {
// BUY
if(g_liveSignalName == "W SHAPE BUY" || g_liveSignalName == "STRONG BUY")
{
   if(Time[0] != lastBuyCandleTime)   // ✅ new candle check
   {
      ProcessSeqBuyOrders(false, false, false);
      lastBuyCandleTime = Time[0];    // mark candle used

      return 0;
   }
}

// SELL
if(g_liveSignalName == "W SHAPE SELL" || g_liveSignalName == "STRONG SELL")
{
   if(Time[0] != lastSellCandleTime)  // ✅ new candle check
   {
      ProcessSeqSellOrders(false, false, false);
      lastSellCandleTime = Time[0];   // mark candle used

      return 0;

   }
}

}

*/


 double ema5  = iMA(Symbol(),0,5,0,MODE_EMA,PRICE_CLOSE,0);
double ema20 = iMA(Symbol(),0,20,0,MODE_EMA,PRICE_CLOSE,0);

int rawSignal = 0;

if(ema5 > ema20)  rawSignal = 1;   // BUY
if(ema5 < ema20)  rawSignal = -1;  // SELL

   // your signal here
   // rawSignal = 1;   // BUY
   // rawSignal = -1;  // SELL

   int confirmedSignal = Detect2CandlePriceTrend();



   if(confirmedSignal == 1 )
   {
      ProcessSeqBuyOrders(checkPattern, check3000, checkMaxOrders);

      // Your BUY code here
      Print("BUY confirmed");
   }
   else if(confirmedSignal == -1  )
   {
      // Your SELL code here
      Print("SELL confirmed");
      ProcessSeqSellOrders(checkPattern, check3000, checkMaxOrders);

   }




return 0;




}
//+------------------------------------------------------------------+
//| Confirm entry after signal with spread + tick movement filter    |
//| signal:  1 = BUY signal, -1 = SELL signal, 0 = no signal         |
//| return:  1 = confirmed BUY, -1 = confirmed SELL, 0 = wait/no     |
//+------------------------------------------------------------------+
int ConfirmScalpEntry(int signal,
                      double minMovePoints = 100,
                      double maxSpreadPoints = 80,
                      int confirmTicks = 2,
                      int expirySeconds = 10)
{
   static int      pendingSignal      = 0;
   static double   signalStartPrice   = 0.0;
   static datetime signalStartTime    = 0;
   static int      goodTickCount      = 0;
   static double   lastCheckPrice     = 0.0;

   RefreshRates();

   double bid    = Bid;
   double ask    = Ask;
   double spread = (ask - bid) / Point;
   double mid    = (bid + ask) / 2.0;

   // No new signal
   if(signal == 0)
   {
      return 0;
   }

   // Start new pending confirmation when signal changes
   if(pendingSignal != signal)
   {
      pendingSignal    = signal;
      signalStartPrice = mid;
      signalStartTime  = TimeCurrent();
      goodTickCount    = 0;
      lastCheckPrice   = mid;
      return 0;
   }

   // Cancel if signal expired
   if(TimeCurrent() - signalStartTime > expirySeconds)
   {
      pendingSignal    = 0;
      signalStartPrice = 0.0;
      signalStartTime  = 0;
      goodTickCount    = 0;
      lastCheckPrice   = 0.0;
      return 0;
   }

   // Cancel if spread too high
   if(spread > maxSpreadPoints)
   {
      return 0;
   }

   // BUY confirmation
   if(pendingSignal == 1)
   {
      double movedFromStart = (mid - signalStartPrice) / Point;
      bool tickUp = (mid > lastCheckPrice);

      if(tickUp)
         goodTickCount++;
      else
         goodTickCount = 0;

      lastCheckPrice = mid;

      if(movedFromStart >= minMovePoints && goodTickCount >= confirmTicks)
      {
         pendingSignal    = 0;
         signalStartPrice = 0.0;
         signalStartTime  = 0;
         goodTickCount    = 0;
         lastCheckPrice   = 0.0;
         return 1;
      }
   }

   // SELL confirmation
   if(pendingSignal == -1)
   {
      double movedFromStart = (signalStartPrice - mid) / Point;
      bool tickDown = (mid < lastCheckPrice);

      if(tickDown)
         goodTickCount++;
      else
         goodTickCount = 0;

      lastCheckPrice = mid;

      if(movedFromStart >= minMovePoints && goodTickCount >= confirmTicks)
      {
         pendingSignal    = 0;
         signalStartPrice = 0.0;
         signalStartTime  = 0;
         goodTickCount    = 0;
         lastCheckPrice   = 0.0;
         return -1;
      }
   }

   return 0;
}
int Detect2CandlePriceTrend()
{
   static int lastTrendSignal = 0;   // 1=BUY, -1=SELL, 0=none

   if(Bars < 4) return 0;

   bool sell1 = (High[1] < High[2] && Low[1] < Low[2]);
   bool sell2 = (High[2] < High[3] && Low[2] < Low[3]);

   bool buy1  = (High[1] > High[2] && Low[1] > Low[2]);
   bool buy2  = (High[2] > High[3] && Low[2] > Low[3]);

   double candle1Height = (High[1] - Low[1]) / Point;
   double candle2Height = (High[2] - Low[2]) / Point;
   double totalHeight   = candle1Height + candle2Height;

   double minTotalHeight = 200;

   // weak candles = reset trend memory
   if(totalHeight < minTotalHeight)
   {
      lastTrendSignal = 0;
      return 0;
   }

   // SELL trend
   if(sell1 && sell2)
   {
      if(lastTrendSignal != -1)
      {
         lastTrendSignal = -1;
         return -1;
      }
      return 0;
   }

   // BUY trend
   if(buy1 && buy2)
   {
      if(lastTrendSignal != 1)
      {
         lastTrendSignal = 1;
         return 1;
      }
      return 0;
   }

   // no clear trend
   lastTrendSignal = 0;
   return 0;
}
bool CheckOrderJumpAcrossEMAsFiltered()
{
   static double prevMidPrice = 0.0;

   RefreshRates();

   double midPrice = (Bid + Ask) / 2.0;

   double ema5  = iMA(Symbol(), 0, 5,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 0);

   string signalText = "";

   if(prevMidPrice == 0.0)
   {
      prevMidPrice = midPrice;
      return false;
   }

   if(prevMidPrice < ema20 && midPrice > ema5 && ema5 > ema20)
   {
      signalText = "BUY";
      prevMidPrice = midPrice;
   double gap = GetEMAGapPoints(FastEMA, SlowEMA);

if(gap>1000)
{
Print("BUY Signal: Price jumped above EMA20. MidPrice=", DoubleToString(midPrice, 5), " EMA5=", DoubleToString(ema5, 5), " EMA20=", DoubleToString(ema20, 5));
         ProcessSeqBuyOrders(true,false);

}
      return true;
   }

   if(prevMidPrice > ema20 && midPrice < ema5 && ema5 < ema20)
   {
      signalText = "SELL";
      prevMidPrice = midPrice;

       double gap = GetEMAGapPoints(FastEMA, SlowEMA);

if(gap>1000)
{ 
         ProcessSeqSellOrders(true,false);

Print("SELL Signal: Price jumped below EMA20. MidPrice=", DoubleToString(midPrice, 5), " EMA5=", DoubleToString(ema5, 5), " EMA20=", DoubleToString(ema20, 5));
}

      return true;
   }

   prevMidPrice = midPrice;
   return false;
}
/*
void  CreateTradeCROSSOVER_EMA20_EMA50_Trend()
{


return ;

   static int   lastTrendSignal = 0;
   static datetime lastBarTime  = 0; // ← ties signal to a specific bar

   datetime currentBarTime = iTime(Symbol(), 0, 1); // closed bar time

   // --- Closed candle EMA values (shift 1 & 2 = fully closed, no repaint) ---
   double ema20_1 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_2 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema50_1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50_2 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 2);

   // --- Detect fresh cross ---
   bool buyCross  = (ema20_2 <= ema50_2 && ema20_1 > ema50_1);
   bool sellCross = (ema20_2 >= ema50_2 && ema20_1 < ema50_1);

   // --- Guard: only fire ONCE per bar regardless of tick frequency ---
   if(currentBarTime == lastBarTime)
   {
// Print(" CROSSOVER - No Trade Guard: only fire ONCE per bar regardless of tick frequency");
   }
       
   // --- BUY cross: only if trend direction changed ---
   if(buyCross && lastTrendSignal != 1)
   {
      lastTrendSignal = 1;
      lastBarTime     = currentBarTime; // ← lock this bar
Print(" CROSSOVER - BUY Trade");

         ProcessSeqBuyOrders(false,false);

   }

   // --- SELL cross: only if trend direction changed ---
   if(sellCross && lastTrendSignal != -1)
   {
      lastTrendSignal = -1;
      lastBarTime     = currentBarTime;
Print(" CROSSOVER - SELL Trade");

         ProcessSeqSellOrders(false,false);

   }

    
}
*/
//+------------------------------------------------------------------+
//| Returns: 1 = BUY, -1 = SELL, 0 = No trade                      |
//+------------------------------------------------------------------+
int GetTradeSignalCluade()
{
   //--- Safety guards (from Claude version)
   double spread = MarketInfo(Symbol(), MODE_SPREAD) * MarketInfo(Symbol(), MODE_POINT);
   if(spread > 2.0) return 0;

   int hourUTC = TimeHour(TimeGMT());
   if(hourUTC < 7 || hourUTC >= 18) return 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol()) return 0;

   //--- EMA values (from ChatGPT version)
   double fast1  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 1);
   double fast2  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 2);
   double slow1  = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow2  = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double trend1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double trend2 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 2);

   //--- RSI (from Claude version — replaces candle body check)
   double rsi = iRSI(Symbol(), 0, 14, PRICE_CLOSE, 1);

   //--- Gap filter (from ChatGPT — critical for BTC noise)
   double gap = MathAbs(fast1 - slow1) / Point;
   if(gap < 100) return 0;

   //--- Cross + trend + slope + RSI
   bool crossUp   = (fast2 <= slow2 && fast1 > slow1);
   bool trendUp   = (Close[1] > trend1 && trend1 > trend2);
   bool slopeUp   = (fast1 > fast2 && slow1 > slow2);

   bool crossDown = (fast2 >= slow2 && fast1 < slow1);
   bool trendDown = (Close[1] < trend1 && trend1 < trend2);
   bool slopeDown = (fast1 < fast2 && slow1 < slow2);

   if(crossUp   && trendUp   && slopeUp   && rsi > 45 && rsi < 70) return  1;
   if(crossDown && trendDown && slopeDown && rsi < 55 && rsi > 30) return -1;

   return 0;
}
//+------------------------------------------------------------------+
//| Returns: 1 = BUY, -1 = SELL, 0 = No trade                        |
//+------------------------------------------------------------------+
int GetTradeSignalChatgpt()
{
   //--- Spread filter
   double spreadPoints = MarketInfo(Symbol(), MODE_SPREAD);
   if(spreadPoints > 200) return 0;   // tune for your broker

   //--- Session filter (optional)
   int hourUTC = TimeHour(TimeGMT());
   if(hourUTC < 7 || hourUTC >= 18) return 0;

   //--- Only 1 open trade for this symbol
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol()) return 0;
   }

   //--- EMA values (closed candles only)
   double fast1  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 1);
   double slow1  = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   double fast2  = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 2);
   double slow2  = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 2);

   double trend1 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double trend2 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 2);

   //--- RSI filter
   double rsi = iRSI(Symbol(), 0, 14, PRICE_CLOSE, 1);

   //--- Candle confirmation
   bool bullish = (Close[1] > Open[1]);
   bool bearish = (Close[1] < Open[1]);

   //--- EMA gap filter
   double gapPoints = MathAbs(fast1 - slow1) / Point;
   if(gapPoints < 100) return 0;   // tune this for BTC

   //--- BUY logic
   bool crossUp   = (fast2 <= slow2 && fast1 > slow1);
   bool trendUp   = (Close[1] > trend1);
   bool slopeUp   = (fast1 > fast2 && slow1 > slow2 && trend1 > trend2);
   bool rsiBuyOk  = (rsi > 45 && rsi < 70);

   if(crossUp && trendUp && slopeUp && bullish && rsiBuyOk)
      return 1;

   //--- SELL logic
   bool crossDown = (fast2 >= slow2 && fast1 < slow1);
   bool trendDown = (Close[1] < trend1);
   bool slopeDown = (fast1 < fast2 && slow1 < slow2 && trend1 < trend2);
   bool rsiSellOk = (rsi < 55 && rsi > 30);

   if(crossDown && trendDown && slopeDown && bearish && rsiSellOk)
      return -1;

   return 0;
}