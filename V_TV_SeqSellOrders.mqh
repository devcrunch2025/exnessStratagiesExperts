//+------------------------------------------------------------------+
//| V_TV_SeqSellOrders.mqh                                           |
//| Executes NEW SELL orders based on matched SeqRule patterns       |
//| No SL/TP - closed manually                                       |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_SELL_ORDERS_MQH
#define V_TV_SEQ_SELL_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string   _SeqSell_        = "--- SEQ SELL ORDERS ---";
input double   SeqSellLotSize   = 0.01;  // Lot size
input int      SeqSellMagicNo   = 22001; // Magic number
input int      SeqSellMaxOrders = 5;     // Max open SELL orders allowed
input int      SeqSellSlippage  = 30;    // Slippage in points

//--- Count open SELL orders placed by this module --------------------
int CountOpenSeqSellOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())       continue;
      if(OrderMagicNumber() != SeqSellMagicNo) continue;
      if(OrderType()        == OP_SELL) count++;
     }
   return count;
  }

//--- Place SELL order - no SL, no TP, closed manually ---------------
bool PlaceSeqSellOrder(int ruleIdx)
  {
   double bid = MarketInfo(Symbol(), MODE_BID);

   string comment = "SeqSell|" +
                    g_seqRules[ruleIdx].prePrev + "|" +
                    g_seqRules[ruleIdx].prev    + "|" +
                    g_seqRules[ruleIdx].curr;

   int ticket = OrderSend(Symbol(), OP_SELL, SeqSellLotSize, bid,
                          SeqSellSlippage, 0, 0,
                          comment, SeqSellMagicNo, 0, clrRed);

   if(ticket <= 0)
     {
      Print("SeqSell ORDER FAILED. Error=", GetLastError(), " Bid=", bid);
      return false;
     }

   Print("SeqSell ORDER placed #", ticket,
         " | PrePrev=", g_seqRules[ruleIdx].prePrev,
         " | Prev=",    g_seqRules[ruleIdx].prev,
         " | Curr=",    g_seqRules[ruleIdx].curr);
   return true;
  }

//--- Returns true if current price is inside the NO TREND SELL ZONE -
bool IsInNoSellZone()
  {
   double dailyLow = iLow(Symbol(), PERIOD_D1, 0);
   if(dailyLow <= 0) return false;
   return (MarketInfo(Symbol(), MODE_BID) <= dailyLow + TrendSellDailyLowGapPrice);
  }

//--- Main entry: called every tick from OnTick ----------------------
void ProcessSeqSellOrders()
  {
   if(g_liveSignalName == "") return;

   if(IsInNoSellZone())
     {
      LogMessage("SeqSell: skipped - price inside NO TREND SELL ZONE");
      return;
     }

   if(CountOpenSeqSellOrders() >= SeqSellMaxOrders) return;

   int ruleIdx = CheckSeqRules();
   if(ruleIdx < 0) return;

   if(g_seqRules[ruleIdx].action    != "NEW_ORDER") return;
   if(g_seqRules[ruleIdx].tradeType != "SELL")      return;

   PlaceSeqSellOrder(ruleIdx);
  }

#endif
