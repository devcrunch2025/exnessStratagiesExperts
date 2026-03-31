//+------------------------------------------------------------------+
//| V_TV_SeqCloseOrders.mqh                                          |
//| Closes SELL orders when profit reaches target                    |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_CLOSE_ORDERS_MQH
#define V_TV_SEQ_CLOSE_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string _SeqClose_          = "--- SEQ CLOSE ORDERS ---";
input double SeqCloseProfitTarget = 1;  // Close when profit reaches this USD amount
input int    SeqCloseSlippage     = 30;    // Slippage in points
input double SeqCloseStopLossUSD  = 0.80;  // Close when loss reaches this USD amount


//--- Close all SELL orders that reached the profit target ------------
void ProcessSeqCloseOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())       continue;
      if(OrderMagicNumber() != SeqSellMagicNo) continue;
      if(OrderType()        != OP_SELL)        continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= SeqCloseProfitTarget)
        {
         double ask = MarketInfo(Symbol(), MODE_ASK);
         bool closed = OrderClose(OrderTicket(), OrderLots(), ask,
                                  SeqCloseSlippage, clrGreen);
         if(closed)
            Print("SeqClose: #", OrderTicket(), " closed at profit=", profit);
         else
            Print("SeqClose: FAILED to close #", OrderTicket(),
                  " Error=", GetLastError());
        }
     

     //--- CLOSE ON STOP LOSS (USD BASED)
      else if(profit <= -SeqCloseStopLossUSD)
        {
         double ask = MarketInfo(Symbol(), MODE_ASK);
         bool closed = OrderClose(OrderTicket(), OrderLots(), ask,
                                  SeqCloseSlippage, clrRed);
         if(closed)
            Print("SeqClose SL: #", OrderTicket(), " closed at loss=", profit);
         else
            Print("SeqClose SL FAILED: #", OrderTicket(),
                  " Error=", GetLastError());
        }
     }
      
  }

#endif
