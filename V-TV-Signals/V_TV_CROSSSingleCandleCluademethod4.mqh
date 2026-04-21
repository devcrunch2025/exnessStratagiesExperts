//+------------------------------------------------------------------+
//|  BTCUSD Scalper EA — 0.50 TP Precision                          |
//|  Signals: EMA crossover + RSI filter + Stochastic timing        |
//|  Timeframe: M1  |  Pair: BTCUSD                                 |
//+------------------------------------------------------------------+
 

//--- Input parameters
input double LotSize      = 0.01;    // Trade lot size
input double TakeProfit   = 1.00;    // Take profit in USD
input double StopLoss     = 1.00;    // Stop loss in USD
input int    EMA_Fast     = 5;       // Fast EMA period
input int    EMA_Slow     = 13;      // Slow EMA period
input int    RSI_Period1   = 14;      // RSI period
input int    Stoch_K      = 5;       // Stochastic %K
input int    Stoch_D      = 3;       // Stochastic %D
input int    Stoch_Slow   = 3;       // Stochastic slowing
input double RSI_OB       = 70.0;    // RSI overbought level
input double RSI_OS       = 30.0;    // RSI oversold level
input double Stoch_OB     = 80.0;    // Stochastic overbought
input double Stoch_OS     = 20.0;    // Stochastic oversold
input int    MagicNumber  = 202401;  // EA magic number
input bool   UseBreakout  = false;   // Enable breakout method 4
input int    BreakoutBars = 20;      // Breakout lookback bars
input int    MaxSpread    = 50*20;      // Max allowed spread (points)

//--- Global variables
datetime lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
// int OnInit()
// {
//    Print("BTCUSD Scalper started | TP=", TakeProfit, " SL=", StopLoss);
//    return(INIT_SUCCEEDED);
// }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void V_TV_CROSSSingleCandleCluademethod4OnTick()
{
   // Only run logic on a new bar to avoid multiple entries per candle
   if(Time[0] == lastBarTime) return;
   lastBarTime = Time[0];

   // Spread guard — skip if spread is too wide (common on BTC)
   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD);
   // if(currentSpread > MaxSpread)
   // {
   //    Print("Spread too wide: ", currentSpread, " points — skipping");
   //    return;
   // }

   // Don't open new trades if one is already open with this EA
   if(CountOpenTrades() > 0) return;

   //--- H1 trend filter: only trade in direction of H1 EMA alignment
   double h1EmaFast = iMA(NULL, PERIOD_H1, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double h1EmaSlow = iMA(NULL, PERIOD_H1, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   bool h1Uptrend   = (h1EmaFast > h1EmaSlow);
   bool h1Downtrend = (h1EmaFast < h1EmaSlow);

   //--- Read indicator values on closed bar [1]
   double emaFast_now  = iMA(NULL, 0, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow_now  = iMA(NULL, 0, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaFast_prev = iMA(NULL, 0, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE, 2);
   double emaSlow_prev = iMA(NULL, 0, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE, 2);

   double rsi     = iRSI(NULL, 0, RSI_Period1, PRICE_CLOSE, 1);

   double stochK  = iStochastic(NULL, 0, Stoch_K, Stoch_D, Stoch_Slow,
                                MODE_SMA, 0, MODE_MAIN,   1);
   double stochD  = iStochastic(NULL, 0, Stoch_K, Stoch_D, Stoch_Slow,
                                MODE_SMA, 0, MODE_SIGNAL, 1);
   double stochK2 = iStochastic(NULL, 0, Stoch_K, Stoch_D, Stoch_Slow,
                                MODE_SMA, 0, MODE_MAIN,   2);
   double stochD2 = iStochastic(NULL, 0, Stoch_K, Stoch_D, Stoch_Slow,
                                MODE_SMA, 0, MODE_SIGNAL, 2);

   //--- Signal conditions
   bool emaBullCross = (emaFast_now > emaSlow_now) && (emaFast_prev <= emaSlow_prev);
   bool emaBearCross = (emaFast_now < emaSlow_now) && (emaFast_prev >= emaSlow_prev);

   bool rsiBull = (rsi > 50.0 && rsi < RSI_OB);
   bool rsiBear = (rsi < 50.0 && rsi > RSI_OS);

   bool stochBull = (stochK > stochD) && (stochK2 <= stochD2) && (stochK < Stoch_OB);
   bool stochBear = (stochK < stochD) && (stochK2 >= stochD2) && (stochK > Stoch_OS);

   //--- Method 4: Breakout confirmation (optional)
   bool breakoutBull = true;
   bool breakoutBear = true;
   if(UseBreakout)
   {
      double highestHigh = High[iHighest(NULL, 0, MODE_HIGH, BreakoutBars, 2)];
      double lowestLow   = Low [iLowest (NULL, 0, MODE_LOW,  BreakoutBars, 2)];
      breakoutBull = (Close[1] > highestHigh);
      breakoutBear = (Close[1] < lowestLow);
   }

   //--- Final signal: all conditions must agree + H1 trend alignment
   bool buySignal  = emaBullCross && rsiBull  && stochBull  && breakoutBull  && h1Uptrend;
   bool sellSignal = emaBearCross && rsiBear  && stochBear  && breakoutBear  && h1Downtrend;

   //--- Execute trades
   if(buySignal)  OpenTrade(OP_BUY);
   if(sellSignal) OpenTrade(OP_SELL);
}

//+------------------------------------------------------------------+
//| Open a trade with TP/SL calculated in USD                        |
//+------------------------------------------------------------------+
void OpenTrade(int direction)
{
   double ask = MarketInfo(Symbol(), MODE_ASK);
   double bid = MarketInfo(Symbol(), MODE_BID);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);  // USD per 1 point per 1 lot
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
   {
      Print("Invalid tick data — aborting trade");
      return;
   }

   // Convert USD to price distance: dist = (USD / lot) / (tickValue / tickSize)
   double pricePer1USD = tickSize / (tickValue * LotSize);
   double tpDist = TakeProfit * pricePer1USD;
   double slDist = StopLoss   * pricePer1USD;

   double entryPrice, tp, sl;
   string direction_str;

   if(direction == OP_BUY)
   {
      entryPrice    = ask;
      tp            = NormalizeDouble(ask + tpDist, Digits);
      sl            = NormalizeDouble(ask - slDist, Digits);
      direction_str = "BUY";
   }
   else
   {
      entryPrice    = bid;
      tp            = NormalizeDouble(bid - tpDist, Digits);
      sl            = NormalizeDouble(bid + slDist, Digits);
      direction_str = "SELL";
   }

   int ticket = OrderSend(
      Symbol(),
      direction,
      LotSize,
      entryPrice,
      3,           // slippage in points
      sl,
      tp,
      "BTC Scalp " + direction_str,
      MagicNumber,
      0,
      (direction == OP_BUY) ? clrLime : clrRed
   );

   if(ticket > 0)
      Print("Trade opened: ", direction_str, " | Entry=", entryPrice,
            " | TP=", tp, " | SL=", sl, " | Ticket=", ticket);
   else
      Print("OrderSend failed: error=", GetLastError(),
            " | direction=", direction_str, " | entry=", entryPrice);
}

//+------------------------------------------------------------------+
//| Count open trades belonging to this EA                           |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
// void OnDeinit(const int reason)
// {
//    Print("BTCUSD Scalper stopped | Reason code: ", reason);
// }