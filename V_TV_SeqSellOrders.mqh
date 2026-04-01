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

input int      SeqSellSlippage  = 30;     // Slippage in points
input int      SeqSellMinGapPoints = 200; // Condition 5: Min price drop from prev signal (in points)


input int SeqSellEMAPeriod  = 20;  // EMA1 period for trend confirmation
input int SeqSellEMA2Period = 50;  // EMA2 period (slow)
input int SeqSellEMAShift   = 3;  // How many candles to compare slope
//+------------------------------------------------------------------+
//| CONDITION HELPERS                                                |
//+------------------------------------------------------------------+

 
// Returns current pattern context string for log messages
string SellPatternContext()
  {
   return "[PrePrev=" + g_prePrevSeqSignalText +
          " | Prev=" + g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount) +
          " | Curr=" + g_liveSignalName    + " " + IntegerToString(g_currSeqCount) + "]";
  }

// Condition 2: Startup warm-up elapsed
bool SellCond2_WarmupElapsed()
  {
   if(TimeCurrent() >= g_startupWaitUntil) return true;
   Print("SeqSell | BLOCKED [Cond2-Warmup] Order blocked - warming up until " +
         TimeToString(g_startupWaitUntil, TIME_MINUTES) + " " + SellPatternContext());
   return false;
  }

// Condition 2b: Minimum seconds between consecutive SELL orders
//               Reads the actual open time of the last placed SELL order from MT4
bool SellCond2b_MinTimeBetweenOrders()
  {
   if(SeqSellMinSecsBetweenOrders <= 0) return true;

   // Find the most recently opened SELL order by this EA
   datetime lastOrderTime = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())       continue;
      if(OrderMagicNumber() != SeqSellMagicNo) continue;
      if(OrderType()        != OP_SELL)        continue;
      if(OrderOpenTime() > lastOrderTime) lastOrderTime = OrderOpenTime();
     }

   if(lastOrderTime == 0) return true; // no existing orders, allow

   int elapsed = (int)(TimeCurrent() - lastOrderTime);
   if(elapsed >= SeqSellMinSecsBetweenOrders) return true;

   Print("SeqSell | BLOCKED [Cond2b-MinTime] Only " + IntegerToString(elapsed) +
         "s since last real order at " + TimeToString(lastOrderTime, TIME_SECONDS) +
         " (need >=" + IntegerToString(SeqSellMinSecsBetweenOrders) + "s) " + SellPatternContext());
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
   Print("SeqSell | BLOCKED [Cond3-NoSellZone] Price " + DoubleToString(bid,2) +
         " is inside NO SELL ZONE (must be > " + DoubleToString(zoneTop,2) + ") " + SellPatternContext());
   return false;
  }

// Condition 4: Max open orders not reached
bool SellCond4_MaxOrdersNotReached(int openCount)
  {
   if(openCount < SeqSellMaxOrders) return true;
   Print("SeqSell | BLOCKED [Cond4-MaxOrders] Already " + IntegerToString(openCount) +
         "/" + IntegerToString(SeqSellMaxOrders) + " SELL orders open " + SellPatternContext());
   return false;
  }

// Condition 5: All 3 signal levels must form a downfall chain (each lower than previous)
//              prePrevPrice > prevPrice > currPrice  (each gap >= SeqSellMinGapPoints)
bool SellCond5_MinDownfallGap(int openCount)
  {
   if(SeqSellMinGapPoints <= 0) return true; // gap check disabled

   string ppLabel = g_prePrevSeqSignalText;
   string pvLabel = g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount);
   string crLabel = g_liveSignalName    + " " + IntegerToString(g_currSeqCount);

   // Level 1: prev must be lower than prePrev
   if(g_prePrevSignalPrice > 0 && g_prevSignalPrice > 0)
     {
      int gap1 = (Point > 0) ? (int)MathRound((g_prePrevSignalPrice - g_prevSignalPrice) / Point) : 0;
      if(gap1 < SeqSellMinGapPoints)
        {
         Print("SeqSell | BLOCKED [Cond5-Level1] " +
               ppLabel + "=" + DoubleToString(g_prePrevSignalPrice,2) +
               " vs " + pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
               " gap=" + IntegerToString(gap1) + "pts (need >=" +
               IntegerToString(SeqSellMinGapPoints) + "pts) " + SellPatternContext());
         return false;
        }
     }

   // Level 2: curr must be lower than prev
   if(g_prevSignalPrice > 0 && g_currSignalPrice > 0)
     {
      int gap2 = (Point > 0) ? (int)MathRound((g_prevSignalPrice - g_currSignalPrice) / Point) : 0;
      if(gap2 < SeqSellMinGapPoints)
        {
         Print("SeqSell | BLOCKED [Cond5-Level2] " +
               pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
               " vs " + crLabel + "=" + DoubleToString(g_currSignalPrice,2) +
               " gap=" + IntegerToString(gap2) + "pts (need >=" +
               IntegerToString(SeqSellMinGapPoints) + "pts) " + SellPatternContext());
         return false;
        }
     }

   LogMessage("SeqSell | Cond5 PASSED - Downfall chain: " +
              ppLabel + "=" + DoubleToString(g_prePrevSignalPrice,2) +
              " > " + pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
              " > " + crLabel + "=" + DoubleToString(g_currSignalPrice,2));
   return true;
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
         Print("SeqSell | BLOCKED [Cond6-OrderInLoss] Order #" + IntegerToString(OrderTicket()) +
               " P/L=" + DoubleToString(profit,2) + " is in loss " + SellPatternContext());
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
      Print("SeqSell | BLOCKED [Cond7-NoPattern] No matching rule for " + SellPatternContext());
      return false;
     }
   if(g_seqRules[ruleIdx].action != "NEW_ORDER" || g_seqRules[ruleIdx].tradeType != "SELL")
     {
      Print("SeqSell | BLOCKED [Cond7-WrongType] Rule[" + IntegerToString(ruleIdx) +
            "] action=" + g_seqRules[ruleIdx].action + " type=" + g_seqRules[ruleIdx].tradeType +
            " (expected NEW_ORDER/SELL) " + SellPatternContext());
      return false;
     }
   Print("SeqSell | Cond7 MATCHED - Pattern [" +
         g_seqRules[ruleIdx].prePrev + " | " +
         g_seqRules[ruleIdx].prev    + " | " +
         g_seqRules[ruleIdx].curr    + "]");
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
      Print("SeqSell | ORDER FAILED Error=" + IntegerToString(GetLastError()) +
            " Bid=" + DoubleToString(bid,2) + " " + SellPatternContext());
      return false;
     }

   string pattern = g_seqRules[ruleIdx].prePrev + " | " +
                    g_seqRules[ruleIdx].prev    + " | " +
                    g_seqRules[ruleIdx].curr;

   Print("SeqSell | *** ORDER CREATED #" + IntegerToString(ticket) + " ***" +
         " Pattern=[" + pattern + "]" +
         " Bid=" + DoubleToString(bid,2) + " Lot=" + DoubleToString(SeqSellLotSize,2));

   ReportOrderOpened(ticket, pattern, "SELL");
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

   // Condition 2b: min time between orders
   if(!SellCond2b_MinTimeBetweenOrders()) return;

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


   // Condition 8: EMA1 trending down
   if(!SellCond8_EMADowntrend()) return;

   // Condition 9: EMA1 below EMA2 (bearish structure)
   if(!SellCond9_EMA1BelowEMA2()) return;

   // All conditions passed - place order
   Print("SeqSell | ALL CONDITIONS PASSED - Placing SELL order " + SellPatternContext());
   PlaceSeqSellOrder(ruleIdx);
  }

// Condition 8: EMA1 must be trending DOWN
bool SellCond8_EMADowntrend()
  {
   double emaCurrent = iMA(Symbol(), 0, SeqSellEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPast    = iMA(Symbol(), 0, SeqSellEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, SeqSellEMAShift);

   if(emaCurrent < emaPast)
      return true;
   Print("SeqSell | BLOCKED [Cond8-EMA1Slope] EMA1(" + IntegerToString(SeqSellEMAPeriod) +
         ") NOT sloping down: was " + DoubleToString(emaPast,2) +
         " now " + DoubleToString(emaCurrent,2) + " " + SellPatternContext());
   return false;
  }

// Condition 9: EMA1 (fast) must be below EMA2 (slow) = bearish market structure
bool SellCond9_EMA1BelowEMA2()
  {
   double ema1 = iMA(Symbol(), 0, SeqSellEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2 = iMA(Symbol(), 0, SeqSellEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(ema1 < ema2)
      return true;
   Print("SeqSell | BLOCKED [Cond9-EMAStructure] EMA1(" + IntegerToString(SeqSellEMAPeriod) + ")=" +
         DoubleToString(ema1,2) + " is NOT below EMA2(" + IntegerToString(SeqSellEMA2Period) + ")=" +
         DoubleToString(ema2,2) + " (no bearish structure) " + SellPatternContext());
   return false;
  }

#endif
