//+------------------------------------------------------------------+
//| V_TV_SeqBuyOrders.mqh                                            |
//| Executes NEW BUY orders based on matched SeqRule patterns        |
//| No SL/TP - closed manually                                       |
//|                                                                  |
//| CONDITIONS (applied to ALL patterns):                            |
//|  Condition 1 : Live signal exists                                |
//|  Condition 2 : Startup warm-up period has elapsed               |
//|  Condition 2b: Min seconds between consecutive BUY orders        |
//|  Condition 3 : Price is NOT inside NO TREND BUY ZONE            |
//|  Condition 4 : Max open BUY orders not reached                   |
//|  Condition 5 : All 3 signal levels form an uprise chain          |
//|  Condition 6 : No existing BUY order is in loss                  |
//|  Condition 7 : SeqRule pattern matched (action=NEW_ORDER, BUY)   |
//|  Condition 8 : EMA1 trending UP                                  |
//|  Condition 9 : EMA1 above EMA2 (bullish structure)               |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_BUY_ORDERS_MQH
#define V_TV_SEQ_BUY_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
// Lot/risk inputs are in V_TV_LotVariables.mqh:
// SeqBuyLotSize, SeqBuySlippage, SeqBuyMinGapPoints,
// SeqBuyMaxOrders, SeqBuyMinSecsBetweenOrders,
// SeqBuyProfitTarget, SeqBuyStopLossUSD
input string   _SeqBuy_        = "--- SEQ BUY ORDERS ---";
input int      SeqBuyMagicNo   = 22002; // Magic number
input int      SeqBuyEMAPeriod = 20;    // EMA1 period for trend confirmation
input int      SeqBuyEMA2Period= 50;    // EMA2 period (slow)
input int      SeqBuyEMAShift  = 3;     // How many candles to compare slope

//+------------------------------------------------------------------+
//| CONDITION HELPERS                                                |
//+------------------------------------------------------------------+

// Returns current pattern context string for log messages
string BuyPatternContext()
  {
   return "[PrePrev=" + g_prePrevSeqSignalText +
          " | Prev=" + g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount) +
          " | Curr=" + g_liveSignalName    + " " + IntegerToString(g_currSeqCount) + "]";
  }

// Condition 2: Startup warm-up elapsed
bool BuyCond2_WarmupElapsed()
  {
   if(TimeCurrent() >= g_startupWaitUntil) return true;
   Print("SeqBuy | BLOCKED [Cond2-Warmup] Order blocked - warming up until " +
         TimeToString(g_startupWaitUntil, TIME_MINUTES) + " " + BuyPatternContext());
   return false;
  }

// Condition 2b: Minimum seconds between consecutive BUY orders
//               Reads the actual open time of the last placed BUY order from MT4
bool BuyCond2b_MinTimeBetweenOrders()
  {
   if(SeqBuyMinSecsBetweenOrders <= 0) return true;

   datetime lastOrderTime = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())      continue;
      if(OrderMagicNumber() != SeqBuyMagicNo) continue;
      if(OrderType()        != OP_BUY)        continue;
      if(OrderOpenTime() > lastOrderTime) lastOrderTime = OrderOpenTime();
     }

   if(lastOrderTime == 0) return true;

   int elapsed = (int)(TimeCurrent() - lastOrderTime);
   if(elapsed >= SeqBuyMinSecsBetweenOrders) return true;

   Print("SeqBuy | BLOCKED [Cond2b-MinTime] Only " + IntegerToString(elapsed) +
         "s since last real order at " + TimeToString(lastOrderTime, TIME_SECONDS) +
         " (need >=" + IntegerToString(SeqBuyMinSecsBetweenOrders) + "s) " + BuyPatternContext());
   return false;
  }

// Condition 3: Price NOT inside NO TREND BUY ZONE (near daily high)
bool BuyCond3_NotInNoBuyZone()
  {
   double dailyHigh = iHigh(Symbol(), PERIOD_D1, 0);
   if(dailyHigh <= 0) return true;
   double zoneBottom = dailyHigh - TrendBuyDailyHighGapPrice;
   double ask        = MarketInfo(Symbol(), MODE_ASK);
   if(ask < zoneBottom) return true;
   Print("SeqBuy | BLOCKED [Cond3-NoBuyZone] Price " + DoubleToString(ask,2) +
         " is inside NO BUY ZONE (must be < " + DoubleToString(zoneBottom,2) + ") " + BuyPatternContext());
   return false;
  }

// Condition 4: Max open orders not reached
bool BuyCond4_MaxOrdersNotReached(int openCount)
  {
   if(openCount < SeqBuyMaxOrders) return true;
   Print("SeqBuy | BLOCKED [Cond4-MaxOrders] Already " + IntegerToString(openCount) +
         "/" + IntegerToString(SeqBuyMaxOrders) + " BUY orders open " + BuyPatternContext());
   return false;
  }

// Condition 5: All 3 signal levels must form an uprise chain (each higher than previous)
//              prePrevPrice < prevPrice < currPrice  (each gap >= SeqBuyMinGapPoints)
bool BuyCond5_MinUpriseGap(int openCount)
  {
   if(SeqBuyMinGapPoints <= 0) return true;

   string ppLabel = g_prePrevSeqSignalText;
   string pvLabel = g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount);
   string crLabel = g_liveSignalName    + " " + IntegerToString(g_currSeqCount);

 bool finalStatus1=true;
 bool finalStatus2=true;
   // Level 1: prev must be higher than prePrev
   if(g_prePrevSignalPrice > 0 && g_prevSignalPrice > 0)
     {
      int gap1 = (Point > 0) ? (int)MathRound((g_prevSignalPrice - g_prePrevSignalPrice) / Point) : 0;
      if(gap1 < SeqBuyMinGapPoints)
        {
         Print("SeqBuy | BLOCKED [Cond5-Level1] " +
               ppLabel + "=" + DoubleToString(g_prePrevSignalPrice,2) +
               " vs " + pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
               " gap=" + IntegerToString(gap1) + "pts (need >=" +
               IntegerToString(SeqBuyMinGapPoints) + "pts) " + BuyPatternContext());
         finalStatus1= false;
        }
     }

   // Level 2: curr must be higher than prev
   if(g_prevSignalPrice > 0 && g_currSignalPrice > 0  )
     {
      int gap2 = (Point > 0) ? (int)MathRound((g_currSignalPrice - g_prevSignalPrice) / Point) : 0;
      if(gap2 < SeqBuyMinGapPoints)
        {
         Print("SeqBuy | BLOCKED [Cond5-Level2] " +
               pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
               " vs " + crLabel + "=" + DoubleToString(g_currSignalPrice,2) +
               " gap=" + IntegerToString(gap2) + "pts (need >=" +
               IntegerToString(SeqBuyMinGapPoints) + "pts) " + BuyPatternContext());
         finalStatus2= false;
        }
     }


if(!finalStatus1 && !finalStatus2)
{
  return false;
}
   LogMessage("SeqBuy | Cond5 PASSED - Uprise chain: " +
              ppLabel + "=" + DoubleToString(g_prePrevSignalPrice,2) +
              " < " + pvLabel + "=" + DoubleToString(g_prevSignalPrice,2) +
              " < " + crLabel + "=" + DoubleToString(g_currSignalPrice,2));
   return true;
  }

// Condition 6: No existing BUY order is in loss
bool BuyCond6_NoOrderInLoss()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())      continue;
      if(OrderMagicNumber() != SeqBuyMagicNo) continue;
      if(OrderType()        != OP_BUY)        continue;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit < 0)
        {
         Print("SeqBuy | BLOCKED [Cond6-OrderInLoss] Order #" + IntegerToString(OrderTicket()) +
               " P/L=" + DoubleToString(profit,2) + " is in loss " + BuyPatternContext());
         return false;
        }
     }
   return true;
  }

// Condition 7: SeqRule pattern matched and is NEW_ORDER BUY
bool BuyCond7_PatternMatched(int &ruleIdx)
  {
   ruleIdx = CheckSeqRules();
   if(ruleIdx < 0)
     {
      Print("SeqBuy | BLOCKED [Cond7-NoPattern] No matching rule for " + BuyPatternContext());
      return false;
     }
   if(g_seqRules[ruleIdx].action != "NEW_ORDER" || g_seqRules[ruleIdx].tradeType != "BUY")
     {
      Print("SeqBuy | BLOCKED [Cond7-WrongType] Rule[" + IntegerToString(ruleIdx) +
            "] action=" + g_seqRules[ruleIdx].action + " type=" + g_seqRules[ruleIdx].tradeType +
            " (expected NEW_ORDER/BUY) " + BuyPatternContext());
      return false;
     }
   Print("SeqBuy | Cond7 MATCHED - Pattern [" +
         g_seqRules[ruleIdx].prePrev + " | " +
         g_seqRules[ruleIdx].prev    + " | " +
         g_seqRules[ruleIdx].curr    + "]");
   return true;
  }

// Condition 8: EMA1 must be trending UP
bool BuyCond8_EMAUptrend()
  {
   double emaCurrent = iMA(Symbol(), 0, SeqBuyEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPast    = iMA(Symbol(), 0, SeqBuyEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, SeqBuyEMAShift);

   if(emaCurrent > emaPast)
      return true;
   Print("SeqBuy | BLOCKED [Cond8-EMA1Slope] EMA1(" + IntegerToString(SeqBuyEMAPeriod) +
         ") NOT sloping up: was " + DoubleToString(emaPast,2) +
         " now " + DoubleToString(emaCurrent,2) + " " + BuyPatternContext());
   return false;
  }

// Condition 9: EMA1 (fast) must be above EMA2 (slow) = bullish market structure
bool BuyCond9_EMA1AboveEMA2()
  {
   double ema1 = iMA(Symbol(), 0, SeqBuyEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2 = iMA(Symbol(), 0, SeqBuyEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(ema1 > ema2)
      return true;
   Print("SeqBuy | BLOCKED [Cond9-EMAStructure] EMA1(" + IntegerToString(SeqBuyEMAPeriod) + ")=" +
         DoubleToString(ema1,2) + " is NOT above EMA2(" + IntegerToString(SeqBuyEMA2Period) + ")=" +
         DoubleToString(ema2,2) + " (no bullish structure) " + BuyPatternContext());
   return false;
  }

//+------------------------------------------------------------------+
//| Count open BUY orders by this module                             |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Place BUY order - no SL, no TP, closed manually                 |
//+------------------------------------------------------------------+
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
      Print("SeqBuy | ORDER FAILED Error=" + IntegerToString(GetLastError()) +
            " Ask=" + DoubleToString(ask,2) + " " + BuyPatternContext());
      return false;
     }

   string pattern = g_seqRules[ruleIdx].prePrev + " | " +
                    g_seqRules[ruleIdx].prev    + " | " +
                    g_seqRules[ruleIdx].curr;

   Print("SeqBuy | *** ORDER CREATED #" + IntegerToString(ticket) + " ***" +
         " Pattern=[" + pattern + "]" +
         " Ask=" + DoubleToString(ask,2) + " Lot=" + DoubleToString(SeqBuyLotSize,2));

   ReportOrderOpened(ticket, pattern, "BUY");
   return true;
  }

//+------------------------------------------------------------------+
//| Main entry: called on new signal detection from OnTick           |
//+------------------------------------------------------------------+
void ProcessSeqBuyOrders()
  {
   // Condition 1: live signal exists
   if(g_liveSignalName == "")
     {
      LogMessage("SeqBuy | Cond1 FAILED - No live signal");
      return;
     }
   LogMessage("SeqBuy | Cond1 PASSED - Live signal: " + g_liveSignalName);

   // Condition 2: warmup elapsed
   if(!BuyCond2_WarmupElapsed()) return;
   LogMessage("SeqBuy | Cond2 PASSED - Warmup elapsed");

   // Condition 2b: min time between orders
   if(!BuyCond2b_MinTimeBetweenOrders()) return;

   // Condition 3: not in NO BUY ZONE
   if(!BuyCond3_NotInNoBuyZone()) return;
   LogMessage("SeqBuy | Cond3 PASSED - Price below NO BUY ZONE");

   // Condition 4: max orders not reached
   int openCount = CountOpenSeqBuyOrders();
   if(!BuyCond4_MaxOrdersNotReached(openCount)) return;
   LogMessage("SeqBuy | Cond4 PASSED - Open orders: " + IntegerToString(openCount) +
              "/" + IntegerToString(SeqBuyMaxOrders));

   // Condition 5: minimum uprise gap across 3 signal levels
   if(!BuyCond5_MinUpriseGap(openCount)) return;

   // Condition 6: no order in loss
   if(!BuyCond6_NoOrderInLoss()) return;
   LogMessage("SeqBuy | Cond6 PASSED - No BUY order in loss");

   // Condition 7: pattern matched
   int ruleIdx = -1;
   if(!BuyCond7_PatternMatched(ruleIdx)) return;

   // Condition 8: EMA1 trending up
   if(!BuyCond8_EMAUptrend()) return;

   // Condition 9: EMA1 above EMA2 (bullish structure)
   if(!BuyCond9_EMA1AboveEMA2()) return;

   // Condition 10: Real market — no fake ticks, no spread spike, sufficient volume
   ////////if(!BuyCond10_RealMarket()) return;
   ////////LogMessage("SeqBuy | Cond10 PASSED - Market is real");

   // All conditions passed - place order
   Print("SeqBuy | ALL CONDITIONS PASSED - Placing BUY order " + BuyPatternContext());
   PlaceSeqBuyOrder(ruleIdx);
  }

// Condition 10: Real market check — block fake ticks / broker manipulation
//   A) Spread must not exceed MaxSpreadPoints (absolute)
//   B) Spread must not be spiking vs running average (x SpreadSpikeMultiplier)
//   C) Last closed bar volume must not be suspiciously low vs average
bool BuyCond10_RealMarket()
  {
   if(!EnableFakeDetection) return true;

   double currentSpread = MarketInfo(Symbol(), MODE_SPREAD);

   // --- Running average spread (exponential smoothing, persists across ticks) ---
   static double avgSpread = 0;
   if(avgSpread <= 0) avgSpread = currentSpread;
   avgSpread = avgSpread * 0.98 + currentSpread * 0.02;  // slow EMA, ~50 tick memory

   // A) Absolute spread limit
   if(currentSpread > MaxSpreadPoints)
     {
      Print("SeqBuy | BLOCKED [Cond10-SpreadHigh] Spread=" + DoubleToString(currentSpread,1) +
            "pts > max=" + IntegerToString(MaxSpreadPoints) + "pts" +
            " (possible news or broker manipulation) " + BuyPatternContext());
      return false;
     }

   // B) Spread spike vs running average
   if(avgSpread > 0 && currentSpread > avgSpread * SpreadSpikeMultiplier)
     {
      Print("SeqBuy | BLOCKED [Cond10-SpreadSpike] Spread=" + DoubleToString(currentSpread,1) +
            "pts is " + DoubleToString(currentSpread / avgSpread, 1) +
            "x avg=" + DoubleToString(avgSpread,1) +
            "pts (fake spike suspected) " + BuyPatternContext());
      return false;
     }

   // C) Volume check — last closed bar must have meaningful volume
   if(VolumeMinRatio > 0 && VolumeAvgBars >= 2 && Bars > VolumeAvgBars + 2)
     {
      double avgVol = 0;
      for(int k = 2; k <= VolumeAvgBars + 1; k++) avgVol += (double)Volume[k];
      avgVol /= VolumeAvgBars;

      double lastVol = (double)Volume[1];
      if(avgVol > 0 && lastVol < avgVol * VolumeMinRatio)
        {
         Print("SeqBuy | BLOCKED [Cond10-LowVolume] Last bar volume=" + DoubleToString(lastVol,0) +
               " < " + DoubleToString(VolumeMinRatio * 100,0) +
               "% of avg=" + DoubleToString(avgVol,0) +
               " (no real conviction) " + BuyPatternContext());
         return false;
        }
     }

   LogMessage("SeqBuy | Cond10 PASSED - Spread=" + DoubleToString(currentSpread,1) +
              "pts AvgSpread=" + DoubleToString(avgSpread,1) + "pts Volume OK");
   return true;
  }

#endif
