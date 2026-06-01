//+------------------------------------------------------------------+
//| MACD_RSI_ADX_Recovery_EA.mq4                                     |
//| MACD + RSI + ADX + SMA Trend Filter EA                           |
//| TP $1 / SL $20 per BUY basket and SELL basket separately          |
//| Recovery orders up to 4 orders per side, fixed 0.01 lot           |
//+------------------------------------------------------------------+
#property strict

//==================== INPUTS ====================
input int      MagicNumber              = 260531;
input double   Lots                     = 0.01;

input double   BuyBasketTakeProfitUSD   = 1.00;
input double   SellBasketTakeProfitUSD  = 1.00;
input double   BuyBasketStopLossUSD     = -20.00;
input double   SellBasketStopLossUSD    = -20.00;

input int      MaxBuyOrders             = 4;
input int      MaxSellOrders            = 4;

// Recovery distance is raw price difference, not points.
// For BTCUSD example: 100 means $100 price distance.
input double   RecoveryGapPrice         = 100.0;

input int      Slippage                 = 30;
input int      MaxSpreadPoints          = 3000;

input bool     TradeOnNewBarOnly        = true;
input bool     EnableBuy                = true;
input bool     EnableSell               = true;
input bool     EnableRecovery           = true;

input ENUM_TIMEFRAMES SignalTF          = PERIOD_CURRENT;

// MACD
input int      MACDFastEMA              = 12;
input int      MACDSlowEMA              = 26;
input int      MACDSignalEMA            = 9;
input int      MACDPrice                = PRICE_CLOSE;

// RSI
input int      RSIPeriod                = 14;
input double   RSIBuyLevel              = 50.0;
input double   RSISellLevel             = 50.0;

// ADX
input int      ADXPeriod                = 14;
input double   ADXMinLevel              = 20.0;
input bool     UseADXFilter             = true;

// Trend MA
input int      TrendMAPeriod            = 100;
input int      TrendMAMethod            = MODE_SMA;
input int      TrendMAPrice             = PRICE_CLOSE;
input bool     UseTrendFilter           = true;

// Testing helper
input bool     DebugPrint               = true;
input bool     RelaxFiltersForTesting   = false; // true = MACD cross only, useful when 0 orders

// Dashboard
input bool     ShowDashboard            = true;

//==================== GLOBALS ====================
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                             |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("MACD_RSI_ADX_Recovery_EA initialized. Symbol=", Symbol(), " TF=", Period());
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "DXB_MACD_EA_");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   if(ShowDashboard)
      DrawDashboard();

   if(!IsTradingAllowedNow())
      return;

   // Manage baskets every tick
   ManageBasket(OP_BUY);
   ManageBasket(OP_SELL);

   // Recovery every tick or new bar
   if(EnableRecovery)
   {
      ProcessRecovery(OP_BUY);
      ProcessRecovery(OP_SELL);
   }

   if(TradeOnNewBarOnly && !IsNewBar())
      return;

   int signal = GetEntrySignal();

   if(DebugPrint)
      PrintSignalDebug(signal);

   if(signal == 1 && EnableBuy)
   {
      if(CountOrders(OP_BUY) == 0)
         OpenOrder(OP_BUY, "MACD_BUY");
   }

   if(signal == -1 && EnableSell)
   {
      if(CountOrders(OP_SELL) == 0)
         OpenOrder(OP_SELL, "MACD_SELL");
   }
}

//+------------------------------------------------------------------+
//| Trading permission checks                                         |
//+------------------------------------------------------------------+
bool IsTradingAllowedNow()
{
   if(!IsTradeAllowed())
   {
      if(DebugPrint) Print("Blocked: IsTradeAllowed=false");
      return(false);
   }

   if(IsTradeContextBusy())
   {
      if(DebugPrint) Print("Blocked: Trade context busy");
      return(false);
   }

   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(spread > MaxSpreadPoints)
   {
      if(DebugPrint) Print("Blocked: Spread too high. Spread=", spread, " Max=", MaxSpreadPoints);
      return(false);
   }

   return(true);
}

//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime t = iTime(Symbol(), SignalTF, 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return(true);
   }
   return(false);
}

//+------------------------------------------------------------------+
//| Entry signal                                                      |
//+------------------------------------------------------------------+
int GetEntrySignal()
{
   int tf = SignalTF;
   if(tf == PERIOD_CURRENT) tf = Period();

   // Use closed candles: bar 1 and bar 2
   double macd1   = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_MAIN, 1);
   double sig1    = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_SIGNAL, 1);
   double macd2   = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_MAIN, 2);
   double sig2    = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_SIGNAL, 2);

   bool macdCrossUp   = (macd2 <= sig2 && macd1 > sig1);
   bool macdCrossDown = (macd2 >= sig2 && macd1 < sig1);

   if(RelaxFiltersForTesting)
   {
      if(macdCrossUp)   return(1);
      if(macdCrossDown) return(-1);
      return(0);
   }

   double rsi1   = iRSI(Symbol(), tf, RSIPeriod, PRICE_CLOSE, 1);
   double adx1   = iADX(Symbol(), tf, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double ma1    = iMA(Symbol(), tf, TrendMAPeriod, 0, TrendMAMethod, TrendMAPrice, 1);
   double close1 = iClose(Symbol(), tf, 1);

   bool buyOk = true;
   bool sellOk = true;

   // RSI filter
   buyOk  = buyOk  && (rsi1 > RSIBuyLevel);
   sellOk = sellOk && (rsi1 < RSISellLevel);

   // ADX filter
   if(UseADXFilter)
   {
      buyOk  = buyOk  && (adx1 > ADXMinLevel);
      sellOk = sellOk && (adx1 > ADXMinLevel);
   }

   // Trend filter
   if(UseTrendFilter)
   {
      buyOk  = buyOk  && (close1 > ma1);
      sellOk = sellOk && (close1 < ma1);
   }

   if(macdCrossUp && buyOk)
      return(1);

   if(macdCrossDown && sellOk)
      return(-1);

   return(0);
}

//+------------------------------------------------------------------+
//| Debug                                                            |
//+------------------------------------------------------------------+
void PrintSignalDebug(int signal)
{
   int tf = SignalTF;
   if(tf == PERIOD_CURRENT) tf = Period();

   double macd1   = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_MAIN, 1);
   double sig1    = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_SIGNAL, 1);
   double macd2   = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_MAIN, 2);
   double sig2    = iMACD(Symbol(), tf, MACDFastEMA, MACDSlowEMA, MACDSignalEMA, MACDPrice, MODE_SIGNAL, 2);
   double rsi1    = iRSI(Symbol(), tf, RSIPeriod, PRICE_CLOSE, 1);
   double adx1    = iADX(Symbol(), tf, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double ma1     = iMA(Symbol(), tf, TrendMAPeriod, 0, TrendMAMethod, TrendMAPrice, 1);
   double close1  = iClose(Symbol(), tf, 1);

   bool crossUp   = (macd2 <= sig2 && macd1 > sig1);
   bool crossDown = (macd2 >= sig2 && macd1 < sig1);

   Print("SignalDebug: signal=", signal,
         " crossUp=", crossUp,
         " crossDown=", crossDown,
         " MACD1=", DoubleToString(macd1, 6),
         " SIG1=", DoubleToString(sig1, 6),
         " RSI=", DoubleToString(rsi1, 2),
         " ADX=", DoubleToString(adx1, 2),
         " Close=", DoubleToString(close1, Digits),
         " MA100=", DoubleToString(ma1, Digits),
         " BuyOrders=", CountOrders(OP_BUY),
         " SellOrders=", CountOrders(OP_SELL));
}

//+------------------------------------------------------------------+
//| Open order                                                        |
//+------------------------------------------------------------------+
bool OpenOrder(int type, string comment)
{
   RefreshRates();

   double price = (type == OP_BUY) ? Ask : Bid;
   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0, comment, MagicNumber, 0,
                          (type == OP_BUY ? clrLime : clrRed));

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend failed. Type=", type, " Error=", err);
      ResetLastError();
      return(false);
   }

   Print("Order opened. Ticket=", ticket, " Type=", (type == OP_BUY ? "BUY" : "SELL"), " Price=", price);
   return(true);
}

//+------------------------------------------------------------------+
//| Count orders                                                      |
//+------------------------------------------------------------------+
int CountOrders(int type)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type)
         count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
//| Basket profit                                                     |
//+------------------------------------------------------------------+
double GetBasketProfit(int type)
{
   double profit = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type)
         profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(profit);
}

//+------------------------------------------------------------------+
//| Manage basket close separately                                    |
//+------------------------------------------------------------------+
void ManageBasket(int type)
{
   double profit = GetBasketProfit(type);

   if(type == OP_BUY)
   {
      if(profit >= BuyBasketTakeProfitUSD)
      {
         Print("BUY basket TP hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_BUY);
      }

      if(profit <= BuyBasketStopLossUSD)
      {
         Print("BUY basket SL hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_BUY);
      }
   }

   if(type == OP_SELL)
   {
      if(profit >= SellBasketTakeProfitUSD)
      {
         Print("SELL basket TP hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_SELL);
      }

      if(profit <= SellBasketStopLossUSD)
      {
         Print("SELL basket SL hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Close orders by type                                              |
//+------------------------------------------------------------------+
void CloseOrdersByType(int type)
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != type)
         continue;

      double closePrice = (type == OP_BUY) ? Bid : Ask;
      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrWhite);

      if(!closed)
      {
         int err = GetLastError();
         Print("OrderClose failed. Ticket=", OrderTicket(), " Error=", err);
         ResetLastError();
      }
      else
      {
         Print("Order closed. Ticket=", OrderTicket(), " Type=", (type == OP_BUY ? "BUY" : "SELL"));
      }
   }
}

//+------------------------------------------------------------------+
//| Recovery logic                                                    |
//+------------------------------------------------------------------+
void ProcessRecovery(int type)
{
   int count = CountOrders(type);

   if(type == OP_BUY && count <= 0) return;
   if(type == OP_SELL && count <= 0) return;

   if(type == OP_BUY && count >= MaxBuyOrders) return;
   if(type == OP_SELL && count >= MaxSellOrders) return;

   double basketProfit = GetBasketProfit(type);

   // Recovery only when that side basket is in loss
   if(basketProfit >= 0.0)
      return;

   double lastPrice = GetLastOrderOpenPrice(type);
   if(lastPrice <= 0.0)
      return;

   RefreshRates();

   if(type == OP_BUY)
   {
      // BUY recovery when price moved down from last BUY
      if((lastPrice - Bid) >= RecoveryGapPrice)
         OpenOrder(OP_BUY, "RECOVERY_BUY");
   }

   if(type == OP_SELL)
   {
      // SELL recovery when price moved up from last SELL
      if((Ask - lastPrice) >= RecoveryGapPrice)
         OpenOrder(OP_SELL, "RECOVERY_SELL");
   }
}

//+------------------------------------------------------------------+
double GetLastOrderOpenPrice(int type)
{
   datetime latestTime = 0;
   double latestPrice = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != type)
         continue;

      if(OrderOpenTime() > latestTime)
      {
         latestTime = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return(latestPrice);
}

//+------------------------------------------------------------------+
//| Dashboard                                                         |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   string prefix = "DXB_MACD_EA_";

   int x = 15;
   int y = 20;
   int line = 18;

   int tf = SignalTF;
   if(tf == PERIOD_CURRENT) tf = Period();

   double buyProfit  = GetBasketProfit(OP_BUY);
   double sellProfit = GetBasketProfit(OP_SELL);

   double rsi1   = iRSI(Symbol(), tf, RSIPeriod, PRICE_CLOSE, 1);
   double adx1   = iADX(Symbol(), tf, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 1);
   double ma1    = iMA(Symbol(), tf, TrendMAPeriod, 0, TrendMAMethod, TrendMAPrice, 1);
   double close1 = iClose(Symbol(), tf, 1);
   int sig = GetEntrySignal();

   DrawLabel(prefix+"TITLE", "MACD + RSI + ADX EA", x, y, clrYellow, 10); y += line;
   DrawLabel(prefix+"SYM", "Symbol: " + Symbol() + "  TF: " + IntegerToString(tf), x, y, clrWhite, 9); y += line;
   DrawLabel(prefix+"SIG", "Signal: " + SignalText(sig), x, y, SignalColor(sig), 9); y += line;
   DrawLabel(prefix+"BUY", "BUY Orders: " + IntegerToString(CountOrders(OP_BUY)) + "  P/L: $" + DoubleToString(buyProfit, 2), x, y, clrLime, 9); y += line;
   DrawLabel(prefix+"SELL", "SELL Orders: " + IntegerToString(CountOrders(OP_SELL)) + "  P/L: $" + DoubleToString(sellProfit, 2), x, y, clrTomato, 9); y += line;
   DrawLabel(prefix+"RSI", "RSI: " + DoubleToString(rsi1, 2) + "  ADX: " + DoubleToString(adx1, 2), x, y, clrAqua, 9); y += line;
   DrawLabel(prefix+"MA", "Close: " + DoubleToString(close1, Digits) + "  SMA100: " + DoubleToString(ma1, Digits), x, y, clrSilver, 9); y += line;
   DrawLabel(prefix+"MODE", "Relax Test Mode: " + (RelaxFiltersForTesting ? "YES" : "NO"), x, y, RelaxFiltersForTesting ? clrOrange : clrSilver, 9);
}

//+------------------------------------------------------------------+
string SignalText(int sig)
{
   if(sig == 1) return("BUY");
   if(sig == -1) return("SELL");
   return("NONE");
}

//+------------------------------------------------------------------+
color SignalColor(int sig)
{
   if(sig == 1) return(clrLime);
   if(sig == -1) return(clrRed);
   return(clrSilver);
}

//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//+------------------------------------------------------------------+
