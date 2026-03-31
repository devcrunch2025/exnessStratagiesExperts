//+------------------------------------------------------------------+
//| V_TV_SeqCloseOrders.mqh                                          |
//| Closes SELL and BUY orders on profit target or stop loss         |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_CLOSE_ORDERS_MQH
#define V_TV_SEQ_CLOSE_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string _SeqClose_           = "--- SEQ CLOSE ORDERS ---";
input int    SeqSellMaxOrders     = 1;     // Max open SELL orders allowed
input double SeqCloseProfitTarget = 0.50;  // Close when profit reaches this USD amount
input double SeqCloseStopLossUSD  = 0.80;  // Close when loss reaches this USD amount (positive value)
input int    SeqCloseSlippage     = 30;    // Slippage in points

//+------------------------------------------------------------------+
//| Close a single order with appropriate price (BUY=bid, SELL=ask)  |
//+------------------------------------------------------------------+
void CloseOrder(int ticket, double profit, string reason)
  {
   double closePrice;
   color  clr;

   if(OrderType() == OP_SELL)
     {
      closePrice = MarketInfo(Symbol(), MODE_ASK);
      clr        = (profit >= 0) ? clrGreen : clrRed;
     }
   else
     {
      closePrice = MarketInfo(Symbol(), MODE_BID);
      clr        = (profit >= 0) ? clrGreen : clrRed;
     }

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

      // Only handle orders placed by this EA (SELL or BUY magic numbers)
      int magicNo = OrderMagicNumber();
      if(magicNo != SeqSellMagicNo && magicNo != SeqBuyMagicNo) continue;

      // Only handle SELL and BUY market orders
      int orderType = OrderType();
      if(orderType != OP_SELL && orderType != OP_BUY) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      int    ticket = OrderTicket();

      if(profit >= SeqCloseProfitTarget)
        {
         CloseOrder(ticket, profit, "PROFIT TARGET $" + DoubleToString(SeqCloseProfitTarget,2));
        }
      else if(profit <= -SeqCloseStopLossUSD)
        {
         CloseOrder(ticket, profit, "STOP LOSS $" + DoubleToString(SeqCloseStopLossUSD,2));
        }
     }
  }

#endif
