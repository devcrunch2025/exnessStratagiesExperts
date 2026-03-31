//+------------------------------------------------------------------+
//| V_TV_SeqBuyOrders.mqh                                            |
//| Executes NEW BUY orders based on matched SeqRule patterns        |
//| No SL/TP - closed manually                                       |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_BUY_ORDERS_MQH
#define V_TV_SEQ_BUY_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string   _SeqBuy_        = "--- SEQ BUY ORDERS ---";
input double   SeqBuyLotSize   = 0.01;  // Lot size
input int      SeqBuyMagicNo   = 22002; // Magic number
input int      SeqBuyMaxOrders = 1;     // Max open BUY orders allowed
input int      SeqBuySlippage  = 30;    // Slippage in points

//--- Returns true if any open BUY order by this module is in loss ---
bool HasSeqBuyOrderInLoss()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())      continue;
      if(OrderMagicNumber() != SeqBuyMagicNo) continue;
      if(OrderType()        != OP_BUY)        continue;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit < 0) return true;
     }
   return false;
  }

//--- Count open BUY orders placed by this module --------------------
int CountOpenSeqBuyOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())      continue;
      if(OrderMagicNumber() != SeqBuyMagicNo) continue;
      if(OrderType()        == OP_BUY) count++;
     }
   return count;
  }

//--- Place BUY order - no SL, no TP, closed manually ----------------
bool PlaceSeqBuyOrder(int ruleIdx)
  {
   double ask = MarketInfo(Symbol(), MODE_ASK);

   string comment = "SeqBuy|" +
                    g_seqRules[ruleIdx].prePrev + "|" +
                    g_seqRules[ruleIdx].prev    + "|" +
                    g_seqRules[ruleIdx].curr;

   int ticket = OrderSend(Symbol(), OP_BUY, SeqBuyLotSize, ask,
                          SeqBuySlippage, 0, 0,
                          comment, SeqBuyMagicNo, 0, clrLime);

   if(ticket <= 0)
     {
      Print("SeqBuy ORDER FAILED. Error=", GetLastError(), " Ask=", ask);
      return false;
     }

   Print("SeqBuy ORDER placed #", ticket,
         " | PrePrev=", g_seqRules[ruleIdx].prePrev,
         " | Prev=",    g_seqRules[ruleIdx].prev,
         " | Curr=",    g_seqRules[ruleIdx].curr);
   return true;
  }

//--- Returns true if current price is inside the NO TREND BUY ZONE --
bool IsInNoBuyZone()
  {
   double dailyHigh = iHigh(Symbol(), PERIOD_D1, 0);
   if(dailyHigh <= 0) return false;
   return (MarketInfo(Symbol(), MODE_ASK) >= dailyHigh - TrendBuyDailyHighGapPrice);
  }

//--- Main entry: called every tick from OnTick ----------------------
void ProcessSeqBuyOrders()
  {
   if(g_liveSignalName == "") return;

   // Block orders during startup warm-up period
   if(TimeCurrent() < g_startupWaitUntil)
     {
      LogMessage("SeqBuy: skipped - startup warm-up active");
      return;
     }

   if(IsInNoBuyZone())
     {
      LogMessage("SeqBuy: skipped - price inside NO TREND BUY ZONE");
      return;
     }

   if(CountOpenSeqBuyOrders() >= SeqBuyMaxOrders) return;

   // Block new order if any existing BUY order is in loss
   if(HasSeqBuyOrderInLoss())
     {
      LogMessage("SeqBuy: skipped - existing BUY order in loss");
      return;
     }

   int ruleIdx = CheckSeqRules();
   if(ruleIdx < 0) return;

   if(g_seqRules[ruleIdx].action    != "NEW_ORDER") return;
   if(g_seqRules[ruleIdx].tradeType != "BUY")       return;

   PlaceSeqBuyOrder(ruleIdx);
  }

#endif
