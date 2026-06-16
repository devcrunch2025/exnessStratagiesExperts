#property strict

extern double LotSize            = 0.01;
extern double BasketTakeProfit   = 0.20;   // book small profit
extern double BasketStopLoss     = -1.00;  // basket SL
extern int    MaxOrders          = 5;
extern int    Slippage           = 30;
extern int    MagicNumber        = 20260517;

extern int    TradeTimeframe     = PERIOD_M1;
extern int    CandlesToCheck     = 5;

extern double MinCandleSize      = 80;     // minimum candle body points
extern int    MaxSpreadPoints    = 1500;

extern bool   EnableHammerFilter = true;
extern bool   ShowDashboard      = true;

datetime lastBarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Last 5 Candle Majority Scalper Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectDelete(0, "LAST5_DASH");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   if(ShowDashboard)
      DrawDashboard();

   double basketProfit = GetBasketProfit();

   // Basket TP
   if(basketProfit >= BasketTakeProfit)
   {
      Print("Basket TP hit: $", DoubleToString(basketProfit, 2));
      CloseAllOrders();
      return;
   }

   // Basket SL
   if(basketProfit <= BasketStopLoss)
   {
      Print("Basket SL hit: $", DoubleToString(basketProfit, 2));
      CloseAllOrders();
      return;
   }

   if(CountOrders() >= MaxOrders)
      return;

   if(!IsSpreadOK())
      return;

   datetime currentBarTime = iTime(Symbol(), TradeTimeframe, 0);

   // only one order per candle
   if(currentBarTime == lastBarTime)
      return;

   lastBarTime = currentBarTime;

   int signal = GetMajoritySignal();

   if(signal == 0)
   {
      Print("No majority signal");
      return;
   }

   // Optional hammer reversal override
   if(EnableHammerFilter)
   {
      if(IsBullishHammer())
      {
         signal = OP_BUY;
         Print("Bullish Hammer Override BUY");
      }

      if(IsShootingStar())
      {
         signal = OP_SELL;
         Print("Shooting Star Override SELL");
      }
   }

   if(signal == OP_BUY)
      OpenOrder(OP_BUY, "LAST5_BUY");

   if(signal == OP_SELL)
      OpenOrder(OP_SELL, "LAST5_SELL");
}

//+------------------------------------------------------------------+
// Count last N candles
// More green = BUY
// More red   = SELL
//+------------------------------------------------------------------+
int GetMajoritySignal()
{
   int greenCount = 0;
   int redCount   = 0;

   for(int i = 1; i <= CandlesToCheck; i++)
   {
      double open1  = iOpen(Symbol(), TradeTimeframe, i);
      double close1 = iClose(Symbol(), TradeTimeframe, i);

      double bodyPoints = MathAbs(close1 - open1) / Point;

      // skip tiny candles
      if(bodyPoints < MinCandleSize)
         continue;

      if(close1 > open1)
         greenCount++;

      if(close1 < open1)
         redCount++;
   }

   Print("Last ", CandlesToCheck,
         " candles | Green: ", greenCount,
         " | Red: ", redCount);

   if(greenCount > redCount)
      return OP_BUY;

   if(redCount > greenCount)
      return OP_SELL;

   return 0;
}

//+------------------------------------------------------------------+
// Bullish Hammer
//+------------------------------------------------------------------+
bool IsBullishHammer()
{
   double open1  = iOpen(Symbol(), TradeTimeframe, 1);
   double close1 = iClose(Symbol(), TradeTimeframe, 1);
   double high1  = iHigh(Symbol(), TradeTimeframe, 1);
   double low1   = iLow(Symbol(), TradeTimeframe, 1);

   double body  = MathAbs(close1 - open1);
   double range = high1 - low1;

   if(range <= 0)
      return false;

   double lowerWick = MathMin(open1, close1) - low1;
   double upperWick = high1 - MathMax(open1, close1);

   if(lowerWick > body * 2 &&
      upperWick < body * 0.7)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
// Shooting Star
//+------------------------------------------------------------------+
bool IsShootingStar()
{
   double open1  = iOpen(Symbol(), TradeTimeframe, 1);
   double close1 = iClose(Symbol(), TradeTimeframe, 1);
   double high1  = iHigh(Symbol(), TradeTimeframe, 1);
   double low1   = iLow(Symbol(), TradeTimeframe, 1);

   double body  = MathAbs(close1 - open1);
   double range = high1 - low1;

   if(range <= 0)
      return false;

   double lowerWick = MathMin(open1, close1) - low1;
   double upperWick = high1 - MathMax(open1, close1);

   if(upperWick > body * 2 &&
      lowerWick < body * 0.7)
   {
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   double spread = (Ask - Bid) / Point;

   if(spread > MaxSpreadPoints)
   {
      Print("Spread too high: ", spread);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
void OpenOrder(int type, string comment)
{
   RefreshRates();

   double price = 0;

   if(type == OP_BUY)
      price = Ask;

   if(type == OP_SELL)
      price = Bid;

   int ticket = OrderSend(Symbol(), type, LotSize, price,
                          Slippage, 0, 0,
                          comment,
                          MagicNumber,
                          0,
                          clrBlue);

   if(ticket > 0)
   {
      Print("Order opened: ", comment,
            " Ticket: ", ticket);
   }
   else
   {
      Print("OrderSend failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
double GetBasketProfit()
{
   double profit = 0;

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            profit += OrderProfit()
                    + OrderSwap()
                    + OrderCommission();
         }
      }
   }

   return profit;
}

//+------------------------------------------------------------------+
int CountOrders()
{
   int count = 0;

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            count++;
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
void CloseAllOrders()
{
   RefreshRates();

   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            bool closed = false;

            if(OrderType() == OP_BUY)
               closed = OrderClose(OrderTicket(),
                                   OrderLots(),
                                   Bid,
                                   Slippage,
                                   clrRed);

            if(OrderType() == OP_SELL)
               closed = OrderClose(OrderTicket(),
                                   OrderLots(),
                                   Ask,
                                   Slippage,
                                   clrRed);

            if(!closed)
            {
               Print("Close failed: ",
                     OrderTicket(),
                     " Error: ",
                     GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   string name = "LAST5_DASH";

   int greenCount = 0;
   int redCount   = 0;

   for(int i = 1; i <= CandlesToCheck; i++)
   {
      double open1  = iOpen(Symbol(), TradeTimeframe, i);
      double close1 = iClose(Symbol(), TradeTimeframe, i);

      if(close1 > open1)
         greenCount++;

      if(close1 < open1)
         redCount++;
   }

   string signal = "WAIT";

   if(greenCount > redCount)
      signal = "BUY";

   if(redCount > greenCount)
      signal = "SELL";

   string txt =
      "LAST 5 CANDLE SCALPER\n"
      + "Basket P/L: $" + DoubleToString(GetBasketProfit(),2) + "\n"
      + "TP: $" + DoubleToString(BasketTakeProfit,2)
      + " | SL: $" + DoubleToString(BasketStopLoss,2) + "\n"
      + "Green: " + IntegerToString(greenCount)
      + " | Red: " + IntegerToString(redCount) + "\n"
      + "Signal: " + signal + "\n"
      + "Orders: " + IntegerToString(CountOrders()) + "\n"
      + "Spread: " + DoubleToString((Ask-Bid)/Point,1);

   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,10);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,20);

      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,10);

      ObjectSetString(0,name,OBJPROP_FONT,"Arial");

      ObjectSetInteger(0,name,OBJPROP_COLOR,clrWhite);
   }

   ObjectSetString(0,name,OBJPROP_TEXT,txt);
}