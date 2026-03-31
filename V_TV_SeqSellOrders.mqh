//+------------------------------------------------------------------+
//| V_TV_SeqSellOrders.mqh                                           |
//| Executes NEW SELL orders based on matched SeqRule patterns       |
//| No SL/TP - closed manually                                       |
//|                                                                  |
//| CONDITIONS (applied to ALL patterns):                            |
//|  Condition 1 : Live signal exists                                |
//|  Condition 2 : Startup warm-up period has elapsed               |
//|  Condition 3 : Price is NOT inside NO TREND SELL ZONE           |
//|  Condition 4 : Max open SELL orders not reached                  |
//|  Condition 5 : Minimum downfall gap from last SELL entry         |
//|  Condition 6 : No existing SELL order is in loss                 |
//|  Condition 7 : SeqRule pattern matched (action=NEW_ORDER, SELL)  |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_SELL_ORDERS_MQH
#define V_TV_SEQ_SELL_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
input string   _SeqSell_        = "--- SEQ SELL ORDERS ---";
input double   SeqSellLotSize   = 0.01;   // Lot size
input int      SeqSellMagicNo   = 22001;  // Magic number
input int      SeqSellMaxOrders = 1;      // Max open SELL orders allowed
input int      SeqSellSlippage  = 30;     // Slippage in points
input double   SeqSellMinGapUSD = 20.0;   // Condition 5: Min price drop from last SELL entry (USD)

//+------------------------------------------------------------------+
//| CONDITION HELPERS                                                |
//+------------------------------------------------------------------+

// Condition 2: Startup warm-up elapsed
bool SellCond2_WarmupElapsed()
  {
   if(TimeCurrent() >= g_startupWaitUntil) return true;
   LogMessage("SeqSell | Cond2 FAILED - Warmup active, wait until " +
              TimeToString(g_startupWaitUntil, TIME_MINUTES));
   return false;
  }

// Condition 3: Price NOT inside NO TREND SELL ZONE
bool SellCond3_NotInNoSellZone()
  {
   double dailyLow = iLow(Symbol(), PERIOD_D1, 0);
   if(dailyLow <= 0) return true;
   double zoneTop = dailyLow + TrendSellDailyLowGapPrice;
   double bid     = MarketInfo(Symbol(), MODE_BID);
   if(bid > zoneTop) return true;
   LogMessage("SeqSell | Cond3 FAILED - Price " + DoubleToString(bid,2) +
              " inside NO SELL ZONE (<= " + DoubleToString(zoneTop,2) + ")");
   return false;
  }

// Condition 4: Max open orders not reached
bool SellCond4_MaxOrdersNotReached(int openCount)
  {
   if(openCount < SeqSellMaxOrders) return true;
   LogMessage("SeqSell | Cond4 FAILED - Max orders reached (" +
              IntegerToString(openCount) + "/" + IntegerToString(SeqSellMaxOrders) + ")");
   return false;
  }

// Condition 5: Each new SELL signal must be lower than previous signal by MinGapUSD
//              Uses g_trendSellSeq[] array built in the main tick loop
bool SellCond5_MinDownfallGap(int openCount)
  {
   if(SeqSellMinGapUSD <= 0) return true; // gap check disabled

   int n = ArraySize(g_trendSellSeq);
   if(n < 2)
     {
      LogMessage("SeqSell | Cond5 PASSED - Only 1 signal in sequence, no prev to compare");
      return true;
     }

   double prevPrice = g_trendSellSeq[n - 2].price;
   double currPrice = g_trendSellSeq[n - 1].price;
   double gap       = prevPrice - currPrice; // positive = current signal is lower (good)

   string prevLbl = g_trendSellSeq[n - 2].label;
   string currLbl = g_trendSellSeq[n - 1].label;

   if(gap >= SeqSellMinGapUSD)
     {
      LogMessage("SeqSell | Cond5 PASSED - " + prevLbl + "=" + DoubleToString(prevPrice,2) +
                 " > " + currLbl + "=" + DoubleToString(currPrice,2) +
                 " gap=" + DoubleToString(gap,2) + " >= " + DoubleToString(SeqSellMinGapUSD,2));
      return true;
     }
   LogMessage("SeqSell | Cond5 FAILED - " + prevLbl + "=" + DoubleToString(prevPrice,2) +
              " vs " + currLbl + "=" + DoubleToString(currPrice,2) +
              " gap=" + DoubleToString(gap,2) + " < required " + DoubleToString(SeqSellMinGapUSD,2));
   return false;
  }

// Condition 6: No existing SELL order is in loss
bool SellCond6_NoOrderInLoss()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())       continue;
      if(OrderMagicNumber() != SeqSellMagicNo) continue;
      if(OrderType()        != OP_SELL)        continue;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit < 0)
        {
         LogMessage("SeqSell | Cond6 FAILED - Order #" + IntegerToString(OrderTicket()) +
                    " in loss: " + DoubleToString(profit,2));
         return false;
        }
     }
   return true;
  }

// Condition 7: SeqRule pattern matched and is NEW_ORDER SELL
bool SellCond7_PatternMatched(int &ruleIdx)
  {
   ruleIdx = CheckSeqRules();
   if(ruleIdx < 0)
     {
      LogMessage("SeqSell | Cond7 FAILED - No pattern matched" +
                 " | PrePrev=" + g_prePrevSeqSignalText +
                 " | Prev=" + g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount) +
                 " | Curr=" + g_liveSignalName + " " + IntegerToString(g_currSeqCount));
      return false;
     }
   if(g_seqRules[ruleIdx].action != "NEW_ORDER" || g_seqRules[ruleIdx].tradeType != "SELL")
     {
      LogMessage("SeqSell | Cond7 FAILED - Rule[" + IntegerToString(ruleIdx) +
                 "] is not NEW_ORDER/SELL (action=" + g_seqRules[ruleIdx].action +
                 " type=" + g_seqRules[ruleIdx].tradeType + ")");
      return false;
     }
   LogMessage("SeqSell | Cond7 PASSED - Rule[" + IntegerToString(ruleIdx) + "] matched" +
              " | " + g_seqRules[ruleIdx].prePrev +
              " | " + g_seqRules[ruleIdx].prev +
              " | " + g_seqRules[ruleIdx].curr);
   return true;
  }

//+------------------------------------------------------------------+
//| Count open SELL orders by this module                            |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Place SELL order - no SL, no TP, closed manually                |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Main entry: called every tick from OnTick                        |
//| All 7 conditions evaluated independently, logged individually    |
//+------------------------------------------------------------------+
void ProcessSeqSellOrders()
  {
   // Condition 1: live signal exists
   if(g_liveSignalName == "")
     {
      LogMessage("SeqSell | Cond1 FAILED - No live signal");
      return;
     }
   LogMessage("SeqSell | Cond1 PASSED - Live signal: " + g_liveSignalName);

   // Condition 2: warmup elapsed
   if(!SellCond2_WarmupElapsed()) return;
   LogMessage("SeqSell | Cond2 PASSED - Warmup elapsed");

   // Condition 3: not in NO SELL ZONE
   if(!SellCond3_NotInNoSellZone()) return;
   LogMessage("SeqSell | Cond3 PASSED - Price above NO SELL ZONE");

   // Condition 4: max orders not reached
   int openCount = CountOpenSeqSellOrders();
   if(!SellCond4_MaxOrdersNotReached(openCount)) return;
   LogMessage("SeqSell | Cond4 PASSED - Open orders: " + IntegerToString(openCount) +
              "/" + IntegerToString(SeqSellMaxOrders));

   // Condition 5: minimum downfall gap
   if(!SellCond5_MinDownfallGap(openCount)) return;

   // Condition 6: no order in loss
   if(!SellCond6_NoOrderInLoss()) return;
   LogMessage("SeqSell | Cond6 PASSED - No SELL order in loss");

   // Condition 7: pattern matched
   int ruleIdx = -1;
   if(!SellCond7_PatternMatched(ruleIdx)) return;

   // All conditions passed - place order
   Print("SeqSell | ALL CONDITIONS PASSED - Placing SELL order");
   PlaceSeqSellOrder(ruleIdx);
  }

#endif
