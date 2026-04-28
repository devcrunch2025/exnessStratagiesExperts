//+------------------------------------------------------------------+
//|                                   BTCUSD_SmartScalper.mq4      |
//|         Smart Scalper - Trend Aware + Hedge Recovery            |
//|         Fixes: No more stacking buys in a falling market        |
//+------------------------------------------------------------------+
#property copyright "BTCUSD Smart Scalper"
#property version   "4.00"
#property strict

//--- Input Parameters
input double BaseLot          = 0.01;    // Base lot size
input double LotMultiplier    = 1.5;     // Lot multiplier on recovery trades
input double ProfitTarget     = 0.50;    // Close all when total profit = $0.10
input double GridStep_USD     = 15.0;    // Open recovery trade every $15 loss
input int    MaxTrades        = 5;       // Max trades at once
input double HardStopAll_USD  = 10.0;   // Emergency close all at -$10 total loss
input int    MagicNumber      = 777222;  // Magic number
input int    Slippage         = 50;      // Slippage
input int    FastEMA          = 5;       // Fast EMA period
input int    SlowEMA          = 21;      // Slow EMA period
input int    TrendEMA         = 50;      // Trend filter EMA
input int    RSI_Period       = 7;       // RSI period
input bool   HedgeOnReversal  = true;   // Open SELL hedge if trend reverses
input double HedgeLot         = 0.02;   // Hedge lot size (bigger to recover faster)
input int    CooldownSeconds  = 15;     // Wait after all trades closed

//--- Global
datetime lastClosedTime = 0;
bool     hedgeOpen      = false;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Smart Scalper v4.0 | MaxTrades:", MaxTrades, " | HardStop: -$", HardStopAll_USD);
   return(INIT_SUCCEEDED);
}
void OnDeinit(const int reason) { Print("Smart Scalper stopped."); }

//+------------------------------------------------------------------+
//| MAIN TICK                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   int    totalTrades  = CountMyTrades();
   double totalProfit  = GetTotalProfit();

   //--- 1. EMERGENCY HARD STOP
   if (totalTrades > 0 && totalProfit <= -HardStopAll_USD)
   {
      Print("!!! HARD STOP HIT !!! Loss: $", totalProfit, " | Closing ALL trades NOW.");
      CloseAllTrades();
      lastClosedTime = TimeCurrent();
      return;
   }

   //--- 2. PROFIT TARGET - close everything together
   if (totalTrades > 0 && totalProfit >= ProfitTarget)
   {
      Print("*** TARGET HIT *** Profit: $", totalProfit, " | Closing all trades.");
      CloseAllTrades();
      lastClosedTime = TimeCurrent();
      return;
   }

   //--- 3. NO TRADES - open fresh
   if (totalTrades == 0)
   {
      if (TimeCurrent() - lastClosedTime < CooldownSeconds) return;
      hedgeOpen = false;
      OpenFirstTrade();
      return;
   }

   //--- 4. TRADES OPEN - manage them
   if (totalTrades > 0)
   {
      ManageOpenTrades(totalProfit, totalTrades);
   }
}

//+------------------------------------------------------------------+
//| TREND DETECTION                                                  |
//+------------------------------------------------------------------+
int GetTrend()
{
   double fast  = iMA(Symbol(), 0, FastEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double slow  = iMA(Symbol(), 0, SlowEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double trend = iMA(Symbol(), 0, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double price = Close[1];
   double rsi   = iRSI(Symbol(), 0, RSI_Period, PRICE_CLOSE, 1);

   // Strong uptrend: price above trend EMA, fast > slow, RSI not overbought
   if (fast > slow && price > trend && rsi < 70) return OP_BUY;

   // Strong downtrend: price below trend EMA, fast < slow, RSI not oversold
   if (fast < slow && price < trend && rsi > 30) return OP_SELL;

   return -1; // No clear trend
}

//+------------------------------------------------------------------+
//| Detect if trend has REVERSED against open trades                |
//+------------------------------------------------------------------+
bool TrendReversed(int originalDirection)
{
   double fast  = iMA(Symbol(), 0, FastEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double slow  = iMA(Symbol(), 0, SlowEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double trend = iMA(Symbol(), 0, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double price = Close[1];

   if (originalDirection == OP_BUY)
      return (fast < slow && price < trend); // Was buy, now bearish

   if (originalDirection == OP_SELL)
      return (fast > slow && price > trend); // Was sell, now bullish

   return false;
}

//+------------------------------------------------------------------+
//| OPEN FIRST TRADE                                                |
//+------------------------------------------------------------------+
void OpenFirstTrade()
{
   static datetime lastBar = 0;
   if (Time[0] == lastBar) return; // Only on new bar
   lastBar = Time[0];

   int direction = GetTrend();
   if (direction == -1)
   {
      Print("No clear trend - waiting...");
      return;
   }

   SendOrder(direction, BaseLot, 1);
}

//+------------------------------------------------------------------+
//| MANAGE OPEN TRADES - recovery + hedge logic                     |
//+------------------------------------------------------------------+
void ManageOpenTrades(double totalProfit, int tradeCount)
{
   int    firstDir   = GetFirstTradeType();
   double lastPrice  = GetLastTradeOpenPrice();
   double currPrice  = (firstDir == OP_BUY) ? Bid : Ask;
   double tickVal    = MarketInfo(Symbol(), MODE_TICKVALUE);
   double priceDiff  = MathAbs(currPrice - lastPrice);
   double lossUSD    = (tickVal > 0) ? (priceDiff / Point) * tickVal * BaseLot : 0;

   //--- CHECK: Has trend reversed?
   bool reversed = TrendReversed(firstDir);

   //--- HEDGE: If trend reversed and hedge not yet opened
   if (HedgeOnReversal && reversed && !hedgeOpen && tradeCount < MaxTrades)
   {
      int hedgeDir = (firstDir == OP_BUY) ? OP_SELL : OP_BUY;
      Print("Trend REVERSED! Opening hedge ", (hedgeDir == OP_BUY ? "BUY" : "SELL"),
            " lot:", HedgeLot, " | Current loss: $", totalProfit);
      SendOrder(hedgeDir, HedgeLot, tradeCount + 1);
      hedgeOpen = true;
      return;
   }

   //--- GRID RECOVERY: Add same-direction trade if price moved GridStep away
   //    Only if trend NOT reversed (avoid stacking into a falling market)
   if (!reversed && !hedgeOpen && tradeCount < MaxTrades && lossUSD >= GridStep_USD)
   {
      double nextLot = NormalizeLot(BaseLot * MathPow(LotMultiplier, tradeCount));
      Print("Grid recovery trade #", tradeCount + 1,
            " | Loss: $", totalProfit, " | Lot: ", nextLot);
      SendOrder(firstDir, nextLot, tradeCount + 1);
   }
}

//+------------------------------------------------------------------+
//| SEND ORDER                                                       |
//+------------------------------------------------------------------+
void SendOrder(int type, double lot, int num)
{
   double price = (type == OP_BUY) ? Ask : Bid;
   color  clr   = (type == OP_BUY) ? clrDodgerBlue : clrOrangeRed;
   string cmt   = StringConcatenate("Smart#", num, (type == OP_BUY ? "_BUY" : "_SELL"));

   int tkt = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                       cmt, MagicNumber, 0, clr);
   if (tkt > 0)
      Print("Order sent: ", cmt, " | Lot:", lot, " | Price:", price, " | #", tkt);
   else
      Print("OrderSend FAILED | Error:", GetLastError(), " | Type:", type, " | Lot:", lot);
}

//+------------------------------------------------------------------+
//| CLOSE ALL TRADES                                                |
//+------------------------------------------------------------------+
void CloseAllTrades()
{
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      double cp = (OrderType() == OP_BUY) ? Bid : Ask;
      bool ok = OrderClose(OrderTicket(), OrderLots(), cp, Slippage, clrYellow);
      if (!ok) Print("Close failed #", OrderTicket(), " Err:", GetLastError());
   }
   hedgeOpen = false;
}

//+------------------------------------------------------------------+
//| HELPERS                                                          |
//+------------------------------------------------------------------+
int CountMyTrades()
{
   int c = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--)
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) c++;
   return c;
}

double GetTotalProfit()
{
   double t = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--)
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            t += OrderProfit() + OrderSwap() + OrderCommission();
   return t;
}

double GetLastTradeOpenPrice()
{
   double lp = 0; datetime lt = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      if (OrderOpenTime() > lt) { lt = OrderOpenTime(); lp = OrderOpenPrice(); }
   }
   return lp;
}

int GetFirstTradeType()
{
   int ft = OP_BUY; datetime et = D'3000.01.01';
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;
      if (OrderOpenTime() < et) { et = OrderOpenTime(); ft = OrderType(); }
   }
   return ft;
}

double NormalizeLot(double lot)
{
   double mn = MarketInfo(Symbol(), MODE_MINLOT);
   double mx = MarketInfo(Symbol(), MODE_MAXLOT);
   double st = MarketInfo(Symbol(), MODE_LOTSTEP);
   lot = MathFloor(lot / st) * st;
   return NormalizeDouble(MathMax(mn, MathMin(mx, lot)), 2);
}
//+------------------------------------------------------------------+
