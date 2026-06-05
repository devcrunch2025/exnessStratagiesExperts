#property strict

input double Lots = 0.01;
input double TakeProfitUSD = 100.0;
input double StopLossUSD   = 5.0;

input int    InpSARPeriod       = 2;
input double InpSARStepSize     = 20;
input double InpSARAcceleration = 10;

input bool   InpDrawSARDots = true;
input int    InpSARDotLookback = 200;
input color  InpSARDotBuyColor = clrLime;
input color  InpSARDotSellColor = clrRed;

input int MagicNumber = 20260605;
input int Slippage = 30;

string OBJ_PREFIX = "SAR_FLIP_EA_";

//+------------------------------------------------------------------+
int OnInit()
{
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(OBJ_PREFIX);
}

//+------------------------------------------------------------------+
void OnTick()
{
   DrawSARDots();

   static datetime lastBarTime = 0;

   if(Time[0] == lastBarTime)
      return;

   lastBarTime = Time[0];

   int signal = GetSARFlipSignal();

   if(signal == 1)
   {
      CloseOrders(OP_SELL);

      if(CountOrders(OP_BUY) == 0)
         OpenOrder(OP_BUY);
   }

   if(signal == -1)
   {
      CloseOrders(OP_BUY);

      if(CountOrders(OP_SELL) == 0)
         OpenOrder(OP_SELL);
   }
}

//+------------------------------------------------------------------+
int GetSARFlipSignal()
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2])
      return 1;

   if(sar1 > Close[1] && sar2 <= Close[2])
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{
   RefreshRates();

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

   if(tickValue <= 0 || tickSize <= 0)
      return;

   double tpDistance = (TakeProfitUSD / (Lots * tickValue)) * tickSize;
   double slDistance = (StopLossUSD   / (Lots * tickValue)) * tickSize;

   double price, tp, sl;

   if(type == OP_BUY)
   {
      price = Ask;
      tp = price + tpDistance;
      sl = price - slDistance;
   }
   else
   {
      price = Bid;
      tp = price - tpDistance;
      sl = price + slDistance;
   }

   price = NormalizeDouble(price, Digits);
   tp    = NormalizeDouble(tp, Digits);
   sl    = NormalizeDouble(sl, Digits);

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, sl, tp,
                          "SAR Flip EA", MagicNumber, 0,
                          type == OP_BUY ? clrBlue : clrRed);

   if(ticket < 0)
      Print("OrderSend failed. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
void CloseOrders(int type)
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrYellow);

      if(!closed)
         Print("OrderClose failed. Ticket: ", OrderTicket(), " Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
int CountOrders(int type)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
void DrawSARDots()
{
   if(!InpDrawSARDots)
      return;

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   int lookback = MathMin(InpSARDotLookback, Bars - 1);

   for(int i = 0; i < lookback; i++)
   {
      double sar = iSAR(Symbol(), Period(), step, maxstep, i);

      if(sar <= 0)
         continue;

      string name = OBJ_PREFIX + "SAR_DOT_" + IntegerToString(i);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_TIME, Time[i]);
         ObjectSetDouble(0, name, OBJPROP_PRICE, sar);
      }

      if(sar < Close[i])
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotBuyColor);
      else
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotSellColor);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
for(int i = ObjectsTotal() - 1; i >= 0; i--)   {
      string name = ObjectName(0, i);

      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}