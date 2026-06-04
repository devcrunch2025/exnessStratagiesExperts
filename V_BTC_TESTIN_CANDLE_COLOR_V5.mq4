//+------------------------------------------------------------------+
//| Separate BUY SELL Profit Stop Bot                                |
//| Initial: Open BUY + SELL                                         |
//| BUY  +$1  -> close BUY only  -> open BUY                         |
//| BUY  -$10 -> close BUY only  -> open SELL                        |
//| SELL +$1  -> close SELL only -> open SELL                        |
//| SELL -$10 -> close SELL only -> open BUY                         |
//| Trading only hour 0 to 10                                        |
//+------------------------------------------------------------------+
#property strict

input double Lots            = 0.01;
input double ProfitTargetUSD = 1.00;
input double StopLossUSD     = 5.00;
input int    MaxOpenOrders   = 2;
input int    MagicNumber     = 20260603;
input int    Slippage        = 30;
input int    StartHour       = 0;
input int    EndHour         = 10;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Separate BUY SELL Profit Stop Bot Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
 

   ManageOrders();


  if(!IsTradingHour())
      return;
   if(CountMyOrders() == 0)
   {
      OpenOrder(OP_BUY);
      OpenOrder(OP_SELL);
   }
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{
   int h = TimeHour(TimeCurrent());
   return (h >= StartHour && h <= EndHour);
}

//+------------------------------------------------------------------+
void ManageOrders()
{
   ManageBuyOrders();
   ManageSellOrders();
}

//+------------------------------------------------------------------+
void ManageBuyOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != OP_BUY)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= ProfitTargetUSD)
      {
         if(CloseSelectedOrder())
            OpenOrder(OP_BUY);

         continue;
      }

      if(profit <= -StopLossUSD)
      {
         if(CloseSelectedOrder())
            OpenOrder(OP_SELL);

         continue;
      }
   }
}

//+------------------------------------------------------------------+
void ManageSellOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != OP_SELL)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= ProfitTargetUSD)
      {
         if(CloseSelectedOrder())
            OpenOrder(OP_SELL);

         continue;
      }

      if(profit <= -StopLossUSD)
      {
         if(CloseSelectedOrder())
            OpenOrder(OP_BUY);

         continue;
      }
   }
}

//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
bool CloseSelectedOrder()
{
   RefreshRates();

   bool result = false;
   int ticket = OrderTicket();

   if(OrderType() == OP_BUY)
      result = OrderClose(ticket, OrderLots(), Bid, Slippage, clrBlue);

   if(OrderType() == OP_SELL)
      result = OrderClose(ticket, OrderLots(), Ask, Slippage, clrRed);

   if(!result)
      Print("OrderClose failed. Ticket=", ticket, " Error=", GetLastError());
   else
      Print("Order closed. Ticket=", ticket);

   return result;
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{
   if(!IsTradingHour())
      return;

   if(CountMyOrders() >= MaxOpenOrders)
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "SEP_BUY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "SEP_SELL";
   }
   else
      return;

   int ticket = OrderSend(
      Symbol(),
      type,
      Lots,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      clrAqua
   );

   if(ticket < 0)
      Print("OrderSend failed. Type=", type, " Error=", GetLastError());
   else
      Print("Order opened. Ticket=", ticket, " Comment=", comment);
}
//+------------------------------------------------------------------+