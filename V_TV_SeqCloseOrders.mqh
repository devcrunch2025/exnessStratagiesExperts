//+------------------------------------------------------------------+
//| V_TV_SeqCloseOrders.mqh                                          |
//| Closes SELL and BUY orders on profit target or stop loss         |
//| Separate profit/loss targets for SELL and BUY                    |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_CLOSE_ORDERS_MQH
#define V_TV_SEQ_CLOSE_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
// All lot/risk inputs are in V_TV_LotVariables.mqh:
// SeqSellProfitTarget, SeqSellStopLossUSD, SeqBuyProfitTarget, SeqBuyStopLossUSD,
// SeqSellMaxOrders, SeqBuyMaxOrders, SeqCloseSlippage
input string _SeqClose_ = "--- SEQ CLOSE ORDERS ---";

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
