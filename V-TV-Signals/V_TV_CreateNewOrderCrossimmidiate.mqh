//+------------------------------------------------------------------+
//| Returns: 1 = BUY, -1 = SELL, 0 = No trade                       |
//| Logic: EMA20 vs EMA50 — first fresh cross on closed bars only    |
//+------------------------------------------------------------------+
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