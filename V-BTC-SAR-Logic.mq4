//+------------------------------------------------------------------+
//|                                                BTC_SAR_Bot.mq4   |
//|                    Parabolic SAR Auto Trading EA for MT4         |
//|                    3rd Dot Entry Version                         |
//+------------------------------------------------------------------+
#property strict

//---- Inputs
input double FixedLot            = 0.01;
input double TargetProfitUSD     = 1;      // manual TP on tick
input double StopLossUSD         = 0.50;   // manual SL on tick
input double SAR_Step            = 0.02;
input double SAR_Max             = 0.2;
input int    Slippage            = 30;
input int    MagicNumber         = 20260423;
input bool   OneTradeAtATime     = true;
input bool   ReverseOnOpposite   = true;
input bool   TradeOnlyOnNewBar   = true;

//---- Dot display inputs
input bool   ShowSignalDots      = true;
input color  BuyDotColor         = clrLime;
input color  SellDotColor        = clrRed;
input int    DotArrowCode        = 159;     // Wingdings dot
input int    DotSize             = 2;
input double DotOffsetPoints     = 3000;    // distance from candle

//---- Globals
datetime g_lastBarTime = 0;

//---- Dot counters
int g_buyDotCount  = 0;
int g_sellDotCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTC SAR Bot initialized. 3rd Dot Entry Version");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1) Manage open trade by manual money TP/SL
   ManageOpenTradesByMoney();

   // 2) Optional: only evaluate entry once per new candle
   if(TradeOnlyOnNewBar)
   {
      if(!IsNewBar())
         return;
   }

   // 3) Get SAR signal from closed candles
   int signal = GetSARSignal();   // 1 = BUY, -1 = SELL, 0 = none

   // 4) Draw signal dots on chart
   if(signal == 1)
   {
      datetime sigTime = iTime(Symbol(), Period(), 1);
      double sigLow    = iLow(Symbol(), Period(), 1);
      DrawBuyDot(sigTime, sigLow);
   }
   else
   if(signal == -1)
   {
      datetime sigTime = iTime(Symbol(), Period(), 1);
      double sigHigh   = iHigh(Symbol(), Period(), 1);
      DrawSellDot(sigTime, sigHigh);
   }

   if(signal == 0)
      return;

   int openType = GetOpenPositionType(); // OP_BUY, OP_SELL, or -1

   // 5) Reverse if opposite signal appears
   if(ReverseOnOpposite)
   {
      if(openType == OP_BUY && signal == -1)
      {
         Print("Opposite SELL signal detected while BUY is open. Closing BUY orders.");
         CloseAllMyOrders();
         Sleep(300);
      }
      else
      if(openType == OP_SELL && signal == 1)
      {
         Print("Opposite BUY signal detected while SELL is open. Closing SELL orders.");
         CloseAllMyOrders();
         Sleep(300);
      }
   }

   // Refresh after possible closing
   openType = GetOpenPositionType();

   // 6) Entry logic: open only on 3rd dot
   if(signal == 1) // BUY DOT
   {
      g_buyDotCount++;
      g_sellDotCount = 0; // reset opposite side

      Print("BUY DOT COUNT = ", g_buyDotCount);

      if(g_buyDotCount >= 3)
      {
         Print(">>> 3rd BUY DOT reached.");

         if(OneTradeAtATime && openType != -1)
         {
            Print("BUY blocked by OneTradeAtATime. Existing open position type = ", openType);
         }
         else
         {
            if(openType != OP_BUY)
               OpenBuy();
            else
               Print("BUY skipped: BUY already open.");
         }

         g_buyDotCount = 0; // reset after attempt
      }
   }
   else
   if(signal == -1) // SELL DOT
   {
      g_sellDotCount++;
      g_buyDotCount = 0; // reset opposite side

      Print("SELL DOT COUNT = ", g_sellDotCount);

      if(g_sellDotCount >= 3)
      {
         Print(">>> 3rd SELL DOT reached.");

         if(OneTradeAtATime && openType != -1)
         {
            Print("SELL blocked by OneTradeAtATime. Existing open position type = ", openType);
         }
         else
         {
            if(openType != OP_SELL)
               OpenSell();
            else
               Print("SELL skipped: SELL already open.");
         }

         g_sellDotCount = 0; // reset after attempt
      }
   }
}

//+------------------------------------------------------------------+
//| Detect new bar                                                   |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime currentBarTime = iTime(Symbol(), Period(), 0);
   if(currentBarTime != g_lastBarTime)
   {
      g_lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Parabolic SAR signal                                             |
//| Uses closed candles                                              |
//| BUY  = SAR below previous closed candle                          |
//| SELL = SAR above previous closed candle                          |
//| Flip confirmation using shift 1 and shift 2                      |
//+------------------------------------------------------------------+
int GetSARSignal()
{
   double sar1   = iSAR(Symbol(), Period(), SAR_Step, SAR_Max, 1); // last closed candle
   double sar2   = iSAR(Symbol(), Period(), SAR_Step, SAR_Max, 2); // previous candle

   double close1 = iClose(Symbol(), Period(), 1);
   double close2 = iClose(Symbol(), Period(), 2);

   // BUY flip: was above candle, now below candle
   if(sar2 >= close2 && sar1 < close1)
      return 1;

   // SELL flip: was below candle, now above candle
   if(sar2 <= close2 && sar1 > close1)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
//| Open BUY                                                         |
//+------------------------------------------------------------------+
bool OpenBuy()
{
   RefreshRates();

   double ask = NormalizeDouble(Ask, Digits);
   int ticket = OrderSend(Symbol(), OP_BUY, FixedLot, ask, Slippage, 0, 0,
                          "SAR BUY", MagicNumber, 0, clrBlue);

   if(ticket < 0)
   {
      Print("BUY OrderSend failed. Error = ", GetLastError());
      return false;
   }

   Print("BUY opened. Ticket = ", ticket, " Price = ", ask);
   return true;
}

//+------------------------------------------------------------------+
//| Open SELL                                                        |
//+------------------------------------------------------------------+
bool OpenSell()
{
   RefreshRates();

   double bid = NormalizeDouble(Bid, Digits);
   int ticket = OrderSend(Symbol(), OP_SELL, FixedLot, bid, Slippage, 0, 0,
                          "SAR SELL", MagicNumber, 0, clrRed);

   if(ticket < 0)
   {
      Print("SELL OrderSend failed. Error = ", GetLastError());
      return false;
   }

   Print("SELL opened. Ticket = ", ticket, " Price = ", bid);
   return true;
}

//+------------------------------------------------------------------+
//| Manage open trades by money TP/SL                                |
//| Closes all EA trades for this symbol when total P/L hits target  |
//+------------------------------------------------------------------+
void ManageOpenTradesByMoney()
{
   double totalPL = GetOpenProfitLossUSD();
   int totalMyOrders = CountMyOpenOrders();

   if(totalMyOrders <= 0)
      return;

   // Manual TP
   if(totalPL >= TargetProfitUSD)
   {
      Print("Manual TP reached: $", DoubleToString(totalPL, 2), " -> Closing all.");
      CloseAllMyOrders();

      // Reset counters after close
      g_buyDotCount  = 0;
      g_sellDotCount = 0;
      return;
   }

   // Manual SL
   if(totalPL <= -StopLossUSD)
   {
      Print("Manual SL reached: $", DoubleToString(totalPL, 2), " -> Closing all.");
      CloseAllMyOrders();

      // Reset counters after close
      g_buyDotCount  = 0;
      g_sellDotCount = 0;
      return;
   }
}

//+------------------------------------------------------------------+
//| Get total open profit/loss for this EA and symbol                |
//+------------------------------------------------------------------+
double GetOpenProfitLossUSD()
{
   double totalPL = 0.0;

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

      totalPL += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return totalPL;
}

//+------------------------------------------------------------------+
//| Count my open orders                                             |
//+------------------------------------------------------------------+
int CountMyOpenOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         count++;
   }

   return count;
}

//+------------------------------------------------------------------+
//| Get current open position type                                   |
//| Returns OP_BUY / OP_SELL / -1                                    |
//+------------------------------------------------------------------+
int GetOpenPositionType()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY)
         return OP_BUY;

      if(OrderType() == OP_SELL)
         return OP_SELL;
   }

   return -1;
}

//+------------------------------------------------------------------+
//| Close all my open orders                                         |
//+------------------------------------------------------------------+
void CloseAllMyOrders()
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

      int type = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      bool closed = false;

      if(type == OP_BUY)
      {
         double price = NormalizeDouble(Bid, Digits);
         closed = OrderClose(ticket, lots, price, Slippage, clrAqua);
      }
      else if(type == OP_SELL)
      {
         double price = NormalizeDouble(Ask, Digits);
         closed = OrderClose(ticket, lots, price, Slippage, clrOrange);
      }

      if(!closed)
         Print("OrderClose failed. Ticket=", ticket, " Error=", GetLastError());
      else
         Print("Order closed successfully. Ticket=", ticket);
   }
}

//+------------------------------------------------------------------+
//| Draw BUY dot                                                     |
//+------------------------------------------------------------------+
void DrawBuyDot(datetime barTime, double candleLow)
{
   if(!ShowSignalDots)
      return;

   string name = "BUY_DOT_" + IntegerToString((int)barTime);

   if(ObjectFind(0, name) != -1)
      return;

   double price = candleLow - (DotOffsetPoints * Point);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price))
   {
      Print("Failed to create BUY dot object. Error=", GetLastError());
      return;
   }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, DotArrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, BuyDotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, DotSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
//| Draw SELL dot                                                    |
//+------------------------------------------------------------------+
void DrawSellDot(datetime barTime, double candleHigh)
{
   if(!ShowSignalDots)
      return;

   string name = "SELL_DOT_" + IntegerToString((int)barTime);

   if(ObjectFind(0, name) != -1)
      return;

   double price = candleHigh + (DotOffsetPoints * Point);

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, barTime, price))
   {
      Print("Failed to create SELL dot object. Error=", GetLastError());
      return;
   }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, DotArrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, SellDotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, DotSize);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}
//+------------------------------------------------------------------+