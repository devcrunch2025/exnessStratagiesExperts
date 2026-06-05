#property strict

double Lots = 0.01;
double TakeProfitUSD = 1.0;
double StopLossUSD   = 3.0;

double RecoveryGapRawPrice = 30.0;
int MaxRecoveryOrders = 5;

bool UseEarlyWeaknessClose = false;
int WeaknessCandles = 3;
double WeaknessRawPriceMove = 50.0;
double EarlyCloseMinProfit = -2.0;

bool ShowWeakStrongCircles = false;
color WeakCircleColor = clrRed;
color StrongCircleColor = clrLime;
int WeakStrongCircleCode = 108;
int WeakStrongCircleWidth = 2;

int TradingStartHour = 10;
int TradingEndHour   = 19;

int    InpSARPeriod       = 2;
double InpSARStepSize     = 20;
double InpSARAcceleration = 10;

bool   InpDrawSARDots = true;
int    InpSARDotLookback = 200;
color  InpSARDotBuyColor = clrLime;
color  InpSARDotSellColor = clrRed;

int MagicNumber = 20260605;
int Slippage = 30;

string OBJ_PREFIX = "SAR_FLIP_EA_";

int g_currentSARDirection = 0;

bool g_buySARWeakPaused  = false;
bool g_sellSARWeakPaused = false;

//+------------------------------------------------------------------+
int OnInit()
{
   g_currentSARDirection = GetCurrentSARDirection();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(OBJ_PREFIX);
}
int GetM30TrendDirection()
{



   double currentPrice = Close[0];

// M1 chart: 30 candles = 30 minutes ago
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 5);

   double diff = currentPrice - price30MinAgo;

   if(diff >= 100)
      return 1;   // BUY trend

   if(diff <= -100)
      return -1;  // SELL trend

   return 0;      // RANGE


   double emaFast = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 1);

   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   if(emaFast > emaSlow && close1 > emaFast)
      return 1;   // BUY trend

   if(emaFast < emaSlow && close1 < emaFast)
      return -1;  // SELL trend

   return 0;      // No clear trend
}
//+------------------------------------------------------------------+
void OnTick()
{
   int profitClosedDirection = CloseOrdersByProfitOrLossUSD();

   DrawSARDots();

   Print(GetM30TrendDirection());

   int signal = GetSARFlipSignal();

   if(signal != 0)
      g_currentSARDirection = signal;

   if(g_currentSARDirection == 0)
      g_currentSARDirection = GetCurrentSARDirection();

   CloseBySARWeaknessBeforeFlip();

   if(!IsTradingHour())
      return;

   if(signal == 1 )
   {
      g_sellSARWeakPaused = false;

      CloseOrders(OP_SELL);

      if(CountOrders(OP_BUY) == 0 && !g_buySARWeakPaused )
         OpenOrder(OP_BUY);

      return;
   }

   if(signal == -1 )
   {
      g_buySARWeakPaused = false;

      CloseOrders(OP_BUY);

      if(CountOrders(OP_SELL) == 0 && !g_sellSARWeakPaused )
         OpenOrder(OP_SELL);

      return;
   }

   if(profitClosedDirection == 1 && g_currentSARDirection == 1)
   {
      if(CountOrders(OP_BUY) == 0 && !g_buySARWeakPaused)
         OpenOrder(OP_BUY);
   }

   if(profitClosedDirection == -1 && g_currentSARDirection == -1)
   {
      if(CountOrders(OP_SELL) == 0 && !g_sellSARWeakPaused)
         OpenOrder(OP_SELL);
   }

   // Continuous SAR order creation
   if(g_currentSARDirection == 1 && CountOrders(OP_BUY) == 0 && !g_buySARWeakPaused)
      OpenOrder(OP_BUY);

   if(g_currentSARDirection == -1 && CountOrders(OP_SELL) == 0 && !g_sellSARWeakPaused)
      OpenOrder(OP_SELL);

   // ManageRecoveryOrders();
}

//+------------------------------------------------------------------+
void CloseBySARWeaknessBeforeFlip()
{
   if(!UseEarlyWeaknessClose)
      return;

   int sarDirection = GetCurrentSARDirection();

   if(sarDirection == 1)
   {
      g_sellSARWeakPaused = false;

      if(IsBearishWeaknessAgainstBUY())
      {
         if(!g_buySARWeakPaused)
            DrawWeakStrongCircle("BUY_WEAK", 1, WeakCircleColor);

         g_buySARWeakPaused = true;

         if(CountOrders(OP_BUY) > 0)
         {
            double buyProfit = GetBasketProfit(OP_BUY);

            if(buyProfit >= EarlyCloseMinProfit)
            {
               Print("BUY SAR weak. Closing BUY and pausing BUY re-entry.");
               CloseOrders(OP_BUY);
            }
         }
      }
      else
      {
         if(g_buySARWeakPaused)
            DrawWeakStrongCircle("BUY_STRONG", 1, StrongCircleColor);

         g_buySARWeakPaused = false;
      }
   }

   if(sarDirection == -1)
   {
      g_buySARWeakPaused = false;

      if(IsBullishWeaknessAgainstSELL())
      {
         if(!g_sellSARWeakPaused)
            DrawWeakStrongCircle("SELL_WEAK", -1, WeakCircleColor);

         g_sellSARWeakPaused = true;

         if(CountOrders(OP_SELL) > 0)
         {
            double sellProfit = GetBasketProfit(OP_SELL);

            if(sellProfit >= EarlyCloseMinProfit)
            {
               Print("SELL SAR weak. Closing SELL and pausing SELL re-entry.");
               CloseOrders(OP_SELL);
            }
         }
      }
      else
      {
         if(g_sellSARWeakPaused)
            DrawWeakStrongCircle("SELL_STRONG", -1, StrongCircleColor);

         g_sellSARWeakPaused = false;
      }
   }
}

//+------------------------------------------------------------------+
void DrawWeakStrongCircle(string type, int direction, color clr)
{
   if(!ShowWeakStrongCircles)
      return;

   string name = OBJ_PREFIX + type + "_" + TimeToString(Time[1], TIME_DATE|TIME_MINUTES);

   if(ObjectFind(0, name) >= 0)
      return;

   double price;

   if(direction == 1)
      price = Low[1] - (80 * Point);
   else
      price = High[1] + (80 * Point);

   ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, WeakStrongCircleCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, WeakStrongCircleWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
bool IsBearishWeaknessAgainstBUY()
{
   int bearishCount = 0;

   double startOpen = iOpen(Symbol(), Period(), WeaknessCandles);
   double lastClose = iClose(Symbol(), Period(), 1);

   for(int i = 1; i <= WeaknessCandles; i++)
   {
      double open  = iOpen(Symbol(), Period(), i);
      double close = iClose(Symbol(), Period(), i);

      if(close < open)
         bearishCount++;
   }

   double rawMoveDown = startOpen - lastClose;

   if(bearishCount >= 2 && rawMoveDown >= WeaknessRawPriceMove)
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool IsBullishWeaknessAgainstSELL()
{
   int bullishCount = 0;

   double startOpen = iOpen(Symbol(), Period(), WeaknessCandles);
   double lastClose = iClose(Symbol(), Period(), 1);

   for(int i = 1; i <= WeaknessCandles; i++)
   {
      double open  = iOpen(Symbol(), Period(), i);
      double close = iClose(Symbol(), Period(), i);

      if(close > open)
         bullishCount++;
   }

   double rawMoveUp = lastClose - startOpen;

   if(bullishCount >= 2 && rawMoveUp >= WeaknessRawPriceMove)
      return true;

   return false;
}

//+------------------------------------------------------------------+
void ManageRecoveryOrders()
{
   if(g_currentSARDirection == 1 && !g_buySARWeakPaused)
      CheckRecovery(OP_BUY);

   if(g_currentSARDirection == -1 && !g_sellSARWeakPaused)
      CheckRecovery(OP_SELL);
}

//+------------------------------------------------------------------+
void CheckRecovery(int type)
{
   int orderCount = CountOrders(type);

   if(orderCount <= 0)
      return;

   if(orderCount >= MaxRecoveryOrders)
      return;

   double basketProfit = GetBasketProfit(type);

   if(basketProfit >= 0)
      return;

   double latestPrice = GetLatestOrderOpenPrice(type);

   if(latestPrice <= 0)
      return;

   RefreshRates();

   if(type == OP_BUY)
   {
      if(Bid <= latestPrice - RecoveryGapRawPrice)
         OpenOrder(OP_BUY);
   }

   if(type == OP_SELL)
   {
      if(Ask >= latestPrice + RecoveryGapRawPrice)
         OpenOrder(OP_SELL);
   }
}

//+------------------------------------------------------------------+
double GetBasketProfit(int type)
{
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         profit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return profit;
}

//+------------------------------------------------------------------+
double GetLatestOrderOpenPrice(int type)
{
   datetime latestTime = 0;
   double latestPrice = 0;

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

      if(OrderOpenTime() > latestTime)
      {
         latestTime = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return latestPrice;
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
int GetCurrentSARDirection()
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar = iSAR(Symbol(), Period(), step, maxstep, 1);

   if(sar < Close[1])
      return 1;

   if(sar > Close[1])
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{

// if( GetM30TrendDirection() != type)
//       return;  

   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;

   price = NormalizeDouble(price, Digits);

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0,
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
int CloseOrdersByProfitOrLossUSD()
{
   RefreshRates();

   int profitClosedDirection = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      bool closeByProfit = profit >= TakeProfitUSD;
      bool closeByLoss   = profit <= -StopLossUSD;

      if(closeByProfit || closeByLoss)
      {
         int orderType = OrderType();
         double closePrice = orderType == OP_BUY ? Bid : Ask;

         bool closed = OrderClose(OrderTicket(),
                                  OrderLots(),
                                  closePrice,
                                  Slippage,
                                  closeByProfit ? clrLime : clrRed);

         if(closed)
         {
            Print("Closed by USD TP/SL. Ticket: ",
                  OrderTicket(),
                  " Profit/Loss: ",
                  DoubleToString(profit, 2));

            if(closeByProfit)
            {
               if(orderType == OP_BUY)
                  profitClosedDirection = 1;

               if(orderType == OP_SELL)
                  profitClosedDirection = -1;
            }
         }
         else
         {
            Print("USD TP/SL close failed. Ticket: ",
                  OrderTicket(),
                  " Error: ",
                  GetLastError());
         }
      }
   }

   return profitClosedDirection;
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
bool IsTradingHour()
{
   int h = TimeHour(TimeCurrent());
   return (h >= TradingStartHour && h < TradingEndHour);
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
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);

      if(StringFind(name, prefix) == 0)
         ObjectDelete(name);
   }
}