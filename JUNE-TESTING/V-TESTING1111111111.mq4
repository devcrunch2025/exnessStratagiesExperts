//+------------------------------------------------------------------+
//| BTCUSD Momentum Scalper - TP $1 / SL $25                         |
//| Price Difference: 5 min, 10 min, 30 min                          |
//+------------------------------------------------------------------+
#property strict

extern double LotSize              = 0.01;
extern double TakeProfitMoney      = 1.00;
extern double StopLossMoney        = 2.00;

extern int    MagicNumber          = 5062026;
extern int    Slippage             = 50;
extern int    MaxOpenOrders        = 1;
extern int    MinSecondsBetweenOrders = 300; // 5 minutes

extern double MinMove5Min          = 20.0;   // BTC price difference
extern double MinMove10Min         = 35.0;
extern double MinMove30Min         = 60.0;

extern int    ATRPeriod            = 14;
extern double MinATR               = 15.0;
extern double MaxATR               = 300.0;

extern int    MaxSpreadPoints      = 3000;
extern bool   CloseOppositeSignal  = false;
extern bool   AllowBuy             = true;
extern bool   AllowSell            = true;

datetime g_lastOrderTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTCUSD Momentum Scalper Started: ", _Symbol);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   ManageOpenOrders();

   if(!IsTradeAllowed()) return;
   if(!SpreadOK()) return;
   if(TimeCurrent() - g_lastOrderTime < MinSecondsBetweenOrders) return;

   int openCount = CountMyOrders();
   if(openCount >= MaxOpenOrders) return;

   int signal = GetMomentumSignal();

   if(signal == 1 && AllowBuy)
   {
      if(CloseOppositeSignal) CloseOrdersByType(OP_SELL);
      OpenOrder(OP_BUY);
   }
   else if(signal == -1 && AllowSell)
   {
      if(CloseOppositeSignal) CloseOrdersByType(OP_BUY);
      OpenOrder(OP_SELL);
   }

   DrawDashboard(signal);
}

//+------------------------------------------------------------------+
//| Momentum Signal                                                   |
//| BUY  = 5m, 10m, 30m all positive and strong                       |
//| SELL = 5m, 10m, 30m all negative and strong                       |
//+------------------------------------------------------------------+
int GetMomentumSignal()
{
   double diff5  = GetPriceDiffMinutes(5);
   double diff10 = GetPriceDiffMinutes(10);
   double diff30 = GetPriceDiffMinutes(30);

   double atr = iATR(_Symbol, PERIOD_M1, ATRPeriod, 1);

   if(atr < MinATR || atr > MaxATR)
      return 0;

   bool bullCandle = Close[1] > Open[1];
   bool bearCandle = Close[1] < Open[1];

   bool buySignal =
      diff5  >= MinMove5Min &&
      diff10 >= MinMove10Min &&
      diff30 >= MinMove30Min &&
      bullCandle;

   bool sellSignal =
      diff5  <= -MinMove5Min &&
      diff10 <= -MinMove10Min &&
      diff30 <= -MinMove30Min &&
      bearCandle;

   if(buySignal)  return 1;
   if(sellSignal) return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Raw price difference from X minutes ago                           |
//+------------------------------------------------------------------+
double GetPriceDiffMinutes(int minutesBack)
{
   datetime pastTime = TimeCurrent() - minutesBack * 60;
   int shift = iBarShift(_Symbol, PERIOD_M1, pastTime, false);

   if(shift < 1)
      return 0;

   double oldPrice = iClose(_Symbol, PERIOD_M1, shift);
   double nowPrice = Bid;

   return NormalizeDouble(nowPrice - oldPrice, Digits);
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{
   RefreshRates();

   double price = 0;
   color clr;

   if(type == OP_BUY)
   {
      price = Ask;
      clr = clrLime;
   }
   else
   {
      price = Bid;
      clr = clrRed;
   }

   int ticket = OrderSend(
      _Symbol,
      type,
      LotSize,
      price,
      Slippage,
      0,
      0,
      "BTC Momentum Scalper",
      MagicNumber,
      0,
      clr
   );

   if(ticket > 0)
   {
      g_lastOrderTime = TimeCurrent();
      Print("Order opened: ", type == OP_BUY ? "BUY" : "SELL",
            " Ticket: ", ticket,
            " Price: ", price);
   }
   else
   {
      Print("OrderSend failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Manual TP/SL by money                                             |
//+------------------------------------------------------------------+
void ManageOpenOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderMagicNumber() != MagicNumber) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= TakeProfitMoney)
      {
         CloseOrder(OrderTicket());
         Print("TP money reached: $", DoubleToString(profit, 2));
      }
      else if(profit <= -StopLossMoney)
      {
         CloseOrder(OrderTicket());
         Print("SL money reached: $", DoubleToString(profit, 2));
      }
   }
}

//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

   RefreshRates();

   bool closed = false;

   if(OrderType() == OP_BUY)
      closed = OrderClose(ticket, OrderLots(), Bid, Slippage, clrYellow);

   if(OrderType() == OP_SELL)
      closed = OrderClose(ticket, OrderLots(), Ask, Slippage, clrYellow);

   if(!closed)
      Print("OrderClose failed. Ticket: ", ticket, " Error: ", GetLastError());
}

//+------------------------------------------------------------------+
void CloseOrdersByType(int type)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != type) continue;

      CloseOrder(OrderTicket());
   }
}

//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == _Symbol && OrderMagicNumber() == MagicNumber)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
bool SpreadOK()
{
   int spread = (int)MarketInfo(_Symbol, MODE_SPREAD);

   if(spread > MaxSpreadPoints)
   {
      DrawDashboard(0);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
double GetTotalOpenProfit()
{
   double total = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != _Symbol) continue;
      if(OrderMagicNumber() != MagicNumber) continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

//+------------------------------------------------------------------+
void DrawDashboard(int signal)
{
   string name = "BTC_MOMENTUM_DASH";

   double diff5  = GetPriceDiffMinutes(5);
   double diff10 = GetPriceDiffMinutes(10);
   double diff30 = GetPriceDiffMinutes(30);
   double atr    = iATR(_Symbol, PERIOD_M1, ATRPeriod, 1);
   int spread    = (int)MarketInfo(_Symbol, MODE_SPREAD);

   string sigText = "NO TRADE";
   color sigColor = clrWhite;

   if(signal == 1)
   {
      sigText = "BUY MOMENTUM";
      sigColor = clrLime;
   }
   else if(signal == -1)
   {
      sigText = "SELL MOMENTUM";
      sigColor = clrRed;
   }

   string txt =
      "BTCUSD MOMENTUM SCALPER\n" +
      "-----------------------------\n" +
      "Signal: " + sigText + "\n" +
      "5 Min Diff : " + DoubleToString(diff5, 2) + "\n" +
      "10 Min Diff: " + DoubleToString(diff10, 2) + "\n" +
      "30 Min Diff: " + DoubleToString(diff30, 2) + "\n" +
      "ATR M1     : " + DoubleToString(atr, 2) + "\n" +
      "Spread     : " + IntegerToString(spread) + "\n" +
      "Orders     : " + IntegerToString(CountMyOrders()) + "\n" +
      "Open P/L   : $" + DoubleToString(GetTotalOpenProfit(), 2) + "\n" +
      "TP Money   : $" + DoubleToString(TakeProfitMoney, 2) + "\n" +
      "SL Money   : $" + DoubleToString(StopLossMoney, 2);

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 20);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 11);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   }

   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, sigColor);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "BTC_MOMENTUM_DASH");
}
//+------------------------------------------------------------------+