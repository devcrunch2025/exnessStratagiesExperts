//+------------------------------------------------------------------+
//|                                                BTC_SAR_Bot.mq4   |
//|                    Parabolic SAR Auto Trading EA for MT4         |
//+------------------------------------------------------------------+
#property strict

//---- Inputs
input double FixedLot            = 0.01;
input double TargetProfitUSD     = 1;   // manual TP on tick
input double StopLossUSD         = 0.50;   // manual SL on tick
input double SAR_Step            = 0.02;
input double SAR_Max             = 0.2;
input int    Slippage            = 30;
input int    MagicNumber         = 20260423;
input bool   OneTradeAtATime     = true;
input bool   ReverseOnOpposite   = true;
input bool   TradeOnlyOnNewBar   = true;

//---- Globals
datetime g_lastBarTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTC SAR Bot initialized.");
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

   if(signal == 0)
      return;

   int openType = GetOpenPositionType(); // OP_BUY, OP_SELL, or -1

   // 4) Reverse if opposite signal appears
   if(ReverseOnOpposite)
   {
      if(openType == OP_BUY && signal == -1)
      {
         CloseAllMyOrders();
         Sleep(300);
      }
      else if(openType == OP_SELL && signal == 1)
      {
         CloseAllMyOrders();
         Sleep(300);
      }
   }

   // Refresh after possible closing
   openType = GetOpenPositionType();

   // 5) Entry logic
   if(OneTradeAtATime && openType != -1)
      return;

   if(signal == 1)
   {
      if(openType != OP_BUY)
         OpenBuy();
   }
   else if(signal == -1)
   {
      if(openType != OP_SELL)
         OpenSell();
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
      return;
   }

   // Manual SL
   if(totalPL <= -StopLossUSD)
   {
      Print("Manual SL reached: $", DoubleToString(totalPL, 2), " -> Closing all.");
      CloseAllMyOrders();
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