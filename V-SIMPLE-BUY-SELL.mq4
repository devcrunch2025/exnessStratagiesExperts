//+------------------------------------------------------------------+
//| Simple Reverse/Continue EA                                       |
//| Opens BUY first, closes at +0.10 profit or -1.00 loss            |
//| Profit  -> reopen same direction                                 |
//| Loss    -> open reverse direction                                |
//| Minimum 10 seconds between orders                                |
//+------------------------------------------------------------------+
#property strict

extern double LotSize              = 0.01;
extern double ProfitTargetMoney    = 0.10;   // close when profit >= 0.10
extern double StopLossMoney        = 0.50;   // close when loss >= 1.00
extern int    MinSecondsBetween    = 5;
extern int    Slippage             = 5;
extern int    MagicNumber          = 20260416;

// Next order direction
// OP_BUY or OP_SELL
int g_nextOrderType = OP_BUY;

// Track last close/open action time
datetime g_lastActionTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA started.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Count open orders for this symbol and magic                      |
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
//| Get current open order ticket for this EA                        |
//+------------------------------------------------------------------+
int GetMyOpenOrderTicket()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return OrderTicket();
   }

   return -1;
}

//+------------------------------------------------------------------+
//| Open order                                                       |
//+------------------------------------------------------------------+
bool OpenNewOrder(int orderType)
{
   if(TimeCurrent() - g_lastActionTime < MinSecondsBetween)
      return false;

   RefreshRates();

   double price = 0;
   color arrowColor = clrNONE;
   string comment = "";

   if(orderType == OP_BUY)
   {
      price = Ask;
      arrowColor = clrBlue;
      comment = "Simple EA BUY";
   }
   else if(orderType == OP_SELL)
   {
      price = Bid;
      arrowColor = clrRed;
      comment = "Simple EA SELL";
   }
   else
   {
      return false;
   }

   int ticket = OrderSend(Symbol(),
                          orderType,
                          LotSize,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          arrowColor);

   if(ticket < 0)
   {
      Print("OrderSend failed. Error = ", GetLastError());
      return false;
   }

   g_lastActionTime = TimeCurrent();

   if(orderType == OP_BUY)
      Print("Opened BUY ticket #", ticket);
   else
      Print("Opened SELL ticket #", ticket);

   return true;
}

//+------------------------------------------------------------------+
//| Close the current order                                          |
//+------------------------------------------------------------------+
bool CloseMyOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;

   RefreshRates();

   int type = OrderType();
   double lots = OrderLots();
   double closePrice = 0;

   if(type == OP_BUY)
      closePrice = Bid;
   else if(type == OP_SELL)
      closePrice = Ask;
   else
      return false;

   bool result = OrderClose(ticket, lots, closePrice, Slippage, clrYellow);

   if(!result)
   {
      Print("OrderClose failed. Ticket=", ticket, " Error=", GetLastError());
      return false;
   }

   g_lastActionTime = TimeCurrent();
   Print("Closed ticket #", ticket);

   return true;
}

//+------------------------------------------------------------------+
//| Manage open trade                                                |
//+------------------------------------------------------------------+
void ManageOpenTrade()
{
   int ticket = GetMyOpenOrderTicket();
   if(ticket < 0)
      return;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return;

   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   int type = OrderType();

   // Profit reached -> close and continue same direction
   if(profit >= ProfitTargetMoney)
   {
      Print("Profit target reached: ", DoubleToString(profit, 2));
      MinSecondsBetween=5;

      if(CloseMyOrder(ticket))
      {
         g_nextOrderType = type;   // same direction
      }
      return;
   }

   // Loss reached -> close and reverse direction
   if(profit <= -StopLossMoney)
   {
      Print("Stop loss reached: ", DoubleToString(profit, 2));
      
      MinSecondsBetween=0;

      if(CloseMyOrder(ticket))
      {
         if(type == OP_BUY)
            g_nextOrderType = OP_SELL;
         else
            g_nextOrderType = OP_BUY;
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| Main tick                                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   int openCount = CountMyOpenOrders();

   // Manage current trade
   if(openCount > 0)
   {
      ManageOpenTrade();
      return;
   }

   // No open trade -> open next order after delay
   if(openCount == 0)
   {
      if(TimeCurrent() - g_lastActionTime >= MinSecondsBetween)
      {
         OpenNewOrder(g_nextOrderType);
      }
   }
}