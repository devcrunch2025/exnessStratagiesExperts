//+------------------------------------------------------------------+
//| V_TV_SeqCloseOrders.mqh                                          |
//| Closes SELL and BUY orders on profit target or stop loss         |
//| Separate profit/loss targets for SELL and BUY                    |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_CLOSE_ORDERS_MQH
#define V_TV_SEQ_CLOSE_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string _SeqClose_              = "--- SEQ CLOSE ORDERS ---";


input string _SeqCloseSell_          = "--- SELL Close Settings ---";
input double SeqSellProfitTarget     = 0.50;  // SELL: Close when profit >= this USD
input double SeqSellStopLossUSD      = 20.00;  // SELL: Close when loss >= this USD

input string _SeqCloseBuy_           = "--- BUY Close Settings ---";
input double SeqBuyProfitTarget      = 0.50;  // BUY: Close when profit >= this USD
input double SeqBuyStopLossUSD       = 20.00;  // BUY: Close when loss >= this USD

input int    SeqSellMaxOrders        = 2;     // Max open SELL orders allowed
input int      SeqBuyMaxOrders           = 2;     // Max open BUY orders allowed


input int      SeqBuyMinSecsBetweenOrders= 30;    // Min seconds between two BUY orders
input int SeqSellMinSecsBetweenOrders = 30; // Min seconds between two SELL orders


input int    SeqCloseSlippage        = 30;    // Slippage in points

//+------------------------------------------------------------------+
//| Close a single order with appropriate price                      |
//+------------------------------------------------------------------+
void CloseOrder(int ticket, double profit, string reason)
  {
   double closePrice = (OrderType() == OP_SELL)
                       ? MarketInfo(Symbol(), MODE_ASK)
                       : MarketInfo(Symbol(), MODE_BID);
   color clr = (profit >= 0) ? clrGreen : clrRed;

   bool closed = OrderClose(ticket, OrderLots(), closePrice, SeqCloseSlippage, clr);

   if(closed)
      Print("SeqClose | #" + IntegerToString(ticket) +
            " [" + (OrderType() == OP_SELL ? "SELL" : "BUY") + "]" +
            " closed [" + reason + "] P/L=" + DoubleToString(profit,2));
   else
      Print("SeqClose | FAILED #" + IntegerToString(ticket) +
            " [" + reason + "] Error=" + IntegerToString(GetLastError()));
  }

//+------------------------------------------------------------------+
//| Main entry: called every tick                                    |
//+------------------------------------------------------------------+
void ProcessSeqCloseOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol())                   continue;

      int magicNo = OrderMagicNumber();
      if(magicNo != SeqSellMagicNo && magicNo != SeqBuyMagicNo) continue;

      int    orderType = OrderType();
      if(orderType != OP_SELL && orderType != OP_BUY)           continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      int    ticket = OrderTicket();

      if(orderType == OP_SELL)
        {
         if(profit >= SeqSellProfitTarget)
            CloseOrder(ticket, profit, "SELL PROFIT TARGET $" + DoubleToString(SeqSellProfitTarget,2));
         else if(profit <= -SeqSellStopLossUSD)
            CloseOrder(ticket, profit, "SELL STOP LOSS $" + DoubleToString(SeqSellStopLossUSD,2));
        }
      else // OP_BUY
        {
         if(profit >= SeqBuyProfitTarget)
            CloseOrder(ticket, profit, "BUY PROFIT TARGET $" + DoubleToString(SeqBuyProfitTarget,2));
         else if(profit <= -SeqBuyStopLossUSD)
            CloseOrder(ticket, profit, "BUY STOP LOSS $" + DoubleToString(SeqBuyStopLossUSD,2));
        }
     }
  }

#endif
