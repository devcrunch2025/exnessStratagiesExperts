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
//|  Condition 8 : EMA1 trending DOWN                                |
//|  Condition 9 : EMA1 below EMA2 (bearish structure)               |
//|  Condition 11: M15 downtrend — close below close N bars ago      |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_SELL_ORDERS_MQH
#define V_TV_SEQ_SELL_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
// Lot/risk inputs are in V_TV_LotVariables.mqh:
// SeqSellLotSize, SeqSellSlippage, SeqSellMinGapPoints,
// SeqSellMaxOrders, SeqSellMinSecsBetweenOrders,
// SeqSellProfitTarget, SeqSellStopLossUSD
input string   _SeqSell_        = "--- SEQ SELL ORDERS ---";
input int      SeqSellMagicNo   = 22001;  // Magic number
input int      SeqSellEMAPeriod = 20;     // EMA1 period for trend confirmation
input int      SeqSellEMA2Period= 50;     // EMA2 period (slow)
input int      SeqSellEMAShift  = 10;      // How many candles to compare slope
input int      SeqSellEMAFlatMinPts = 10;  // Min EMA movement in points to be considered trending (0=disable flat filter)
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
bool General_WarmupElapsed()
  {

 

   if(TimeCurrent() >= g_startupWaitUntil) return true;
   printdummy("SeqSell | BLOCKED [Cond2-Warmup] Order blocked - warming up until " +
         TimeToString(g_startupWaitUntil, TIME_MINUTES) + " " + SellPatternContext());
   return false;
  }
// Condition 2: Startup warm-up elapsed
bool SellCond2_WarmupElapsed()
  {


if(isEMATouchesInsideLines==true)
{

}
else
{
  return  false;
}

   if(TimeCurrent() >= g_startupWaitUntil) return true;
   printdummy("SeqSell | BLOCKED [Cond2-Warmup] Order blocked - warming up until " +
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
      if(OrderCloseTime() > lastOrderTime) lastOrderTime = OrderCloseTime();
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

    if(TrendSellDailyLowGapPrice==0) return true;
  double minGapPrice = 100 * Point;
  double gapPrice = MathMax(TrendSellDailyLowGapPrice, minGapPrice);

   double dailyLow = iLow(Symbol(), PERIOD_H4, 0);
   if(dailyLow <= 0) return true;
  double zoneTop = dailyLow + gapPrice;
   double bid     = MarketInfo(Symbol(), MODE_BID);
   if(bid > zoneTop) return true;
   printdummy("SeqSell | BLOCKED [Cond3-NoSellZone] Price " + DoubleToString(bid,2) +
         " is inside NO SELL ZONE (must be > " + DoubleToString(zoneTop,2) + ") " + SellPatternContext());
   return false;
  }

// Condition 4: Max open orders not reached
bool SellCond4_MaxOrdersNotReached(int openCount)
  {
   if(openCount < SeqSellMaxOrders) return true;
   printdummy("SeqSell | BLOCKED [Cond4-MaxOrders] Already " + IntegerToString(openCount) +
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
         printdummy("SeqSell | BLOCKED [Cond5-Level1] " +
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
         printdummy("SeqSell | BLOCKED [Cond5-Level2] " +
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
         printdummy("SeqSell | BLOCKED [Cond6-OrderInLoss] Order #" + IntegerToString(OrderTicket()) +
               " P/L=" + DoubleToString(profit,2) + " is in loss " + SellPatternContext());
         return false;
        }
     }
   return true;
  }

// Condition 7: SeqRule pattern matched and is NEW_ORDER SELL
bool SellCond7_PatternMatched(int &ruleIdx)
  {
    /*
   // --- Check SeqRules first ---
   ruleIdx = CheckSeqRules();
   if(ruleIdx >= 0)
     {
      if(g_seqRules[ruleIdx].action != "NEW_ORDER" || g_seqRules[ruleIdx].tradeType != "SELL")
        {
         // matched a rule but wrong type — fall through to color rules
         ruleIdx = -1;
        }
      else
        {
         Print("SeqSell | Cond7 MATCHED SeqRule [" +
               g_seqRules[ruleIdx].prePrev + " | " +
               g_seqRules[ruleIdx].prev    + " | " +
               g_seqRules[ruleIdx].curr    + "]");
         return true;
        }
     }
*/
   // --- Check ColorRules ---
   int cIdx = CheckColorRules("NEW_ORDER", "SELL");
   if(cIdx >= 0)
     {
      ruleIdx = -1;   // no SeqRule index; caller uses -1 to mean "color rule matched"
      // Print("SeqSell | Cond7 MATCHED ColorRule [" + g_colorRules[cIdx].colorType +
      //       " COUNT>=" + IntegerToString(g_colorRules[cIdx].minCount) +
      //       "] signal=" + g_liveSignalName + " " + IntegerToString(g_currSeqCount));
      return true;
     }

   printdummy("SeqSell | BLOCKED [Cond7-NoMatch] No SeqRule or ColorRule matched " + SellPatternContext());
   return false;
  }

//+------------------------------------------------------------------+
//| Count open SELL orders by this module                            |
//+------------------------------------------------------------------+
   int count = 0;

int CountOpenSeqSellOrders()
  {
    count=0;
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
   double gap = GetEMAGapPoints(FastEMA, SlowEMA);

    
   double bid = MarketInfo(Symbol(), MODE_BID);

   // ruleIdx == -1 means a ColorRule matched (not a SeqRule) — safe fallback comment
   string comment = "SeqSell|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].prePrev : "COLOR") + "|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].prev    : g_liveSignalName) + "|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].curr    : IntegerToString(g_currSeqCount))+"| gap=" + DoubleToString(gap,1) + "pts  ";

   int ticket = OrderSend(Symbol(), OP_SELL, SeqSellLotSize, bid,
                          SeqSellSlippage, 0, 0,
                          comment, SeqSellMagicNo, 0, clrRed);
   if(ticket <= 0)
     {
      Print("SeqSell | ORDER FAILED Error=" + IntegerToString(GetLastError()) +
            " Bid=" + DoubleToString(bid,2) + " " + SellPatternContext());
      return false;
     }

   string pattern = (ruleIdx >= 0)
                    ? g_seqRules[ruleIdx].prePrev + " | " +
                      g_seqRules[ruleIdx].prev    + " | " +
                      g_seqRules[ruleIdx].curr
                    : "" + g_liveSignalName + " " + IntegerToString(g_currSeqCount)+" | COLOR ";

   Print("SeqSell | *** ORDER CREATED #" + IntegerToString(ticket) + " ***" +
         " Pattern=[" + pattern + "]" +
         " Bid=" + DoubleToString(bid,2) + " Lot=" + DoubleToString(SeqSellLotSize,2));

   ReportOrderOpened(ticket, pattern, "SELL");
   
   return true;
  }

//+------------------------------------------------------------------+
//| Draw orange dashed rectangle on current bar when SELL is blocked |
//| Tooltip shows on mouse-hover in MetaTrader chart                 |
//+------------------------------------------------------------------+
void DrawBlockedSellSignal(string reason)
  {
   string ts    = IntegerToString((int)TimeCurrent());
   string nameR = "BlkSell_R_" + ts;   // rectangle
   string nameT = "BlkSell_T_" + ts;   // text label
   ObjectDelete(0, nameR);
   ObjectDelete(0, nameT);

   double boxH = High[0] + 8 * Point;
   double boxL = Low[0]  - 8 * Point;
   datetime t1 = Time[0];
   datetime t2 = Time[0] + (datetime)PeriodSeconds(PERIOD_CURRENT);

   // Extract short condition ID: e.g. "Cond8: EMA flat" -> "Cond8"
   string condId = reason;
   int colonPos = StringFind(reason, ":");
   if(colonPos > 0) condId = StringSubstr(reason, 0, colonPos);

   // Rectangle box
   if(ObjectCreate(0, nameR, OBJ_RECTANGLE, 0, t1, boxH, t2, boxL))
     {
      ObjectSetInteger(0, nameR, OBJPROP_COLOR,      clrOrangeRed);
      ObjectSetInteger(0, nameR, OBJPROP_STYLE,      STYLE_DASH);
      ObjectSetInteger(0, nameR, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, nameR, OBJPROP_BACK,       false);
      ObjectSetInteger(0, nameR, OBJPROP_FILL,       false);
      ObjectSetInteger(0, nameR, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameR, OBJPROP_HIDDEN,     false);
      ObjectSetString(0,  nameR, OBJPROP_TOOLTIP,
                      "SELL BLOCKED\n" +
                      "Pattern: " + SellPatternContext() + "\n" +
                      "Reason:  " + reason + "\n" +
                      "Time:    " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
     }

   // Text label inside the box showing condition ID
   if(ObjectCreate(0, nameT, OBJ_TEXT, 0, t1, boxH - 2 * Point))
     {
      ObjectSetString(0,  nameT, OBJPROP_TEXT,      "X " + condId);
      ObjectSetInteger(0, nameT, OBJPROP_COLOR,     clrOrangeRed);
      ObjectSetInteger(0, nameT, OBJPROP_FONTSIZE,  7);
      ObjectSetString(0,  nameT, OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, nameT, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nameT, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nameT, OBJPROP_HIDDEN,    false);
      ObjectSetString(0,  nameT, OBJPROP_TOOLTIP,
                      "SELL BLOCKED: " + reason);
     }

   ChartRedraw(0);
  }
   string blockReason = "";

//+------------------------------------------------------------------+
//| Main entry: called every tick from OnTick                        |
//+------------------------------------------------------------------+

int openCountS = 0;

void ProcessSeqSellOrders()
  {

blockReason="";
    //  Print("Cond44444444444444: Max SELL orders reached (" +
    //                  (openCountS) + "/" +  (SeqSellMaxOrders) + ")");


    double gap=GetEMAGapPoints(FastEMA, SlowEMA);

if(  gap<=3000)
                     {
blockReason = "Cond1: EMI gap too tight: " + DoubleToString(gap,1);
return ;
                    }


   // Condition 1 & 7: quick exits — no marker drawn if these fail
   if(g_liveSignalName == "")
     { LogMessage("SeqSell | Cond1 FAILED - No live signal"); return; }

   int ruleIdx = -1;
  //  if(!SellCond7_PatternMatched(ruleIdx)) return;

   // === PATTERN MATCHED — track which condition blocks and draw marker ===
       openCountS  = CountOpenSeqSellOrders();
// if(!CanOpenOrder_RSI_Range(OP_SELL))
//       blockReason = "Cond1: RSI not in allowed range (30-70)";
//     else
// double gap=GetEMAGapPoints(FastEMA, SlowEMA);
 if(  gap<=3000)
                     {
blockReason = "Cond1: EMI gap too tight: " + DoubleToString(gap,1);

                    }
                    else

   if(!SellCond2_WarmupElapsed())
   { 
      blockReason = "Cond2: Warmup not elapsed yet";
//  Print("Cond666666666666: Max SELL orders reached (" +
                    //  (openCountS) + "/" +  (SeqSellMaxOrders) + ")");

   }
   else if(!SellCond2b_MinTimeBetweenOrders())
      blockReason = "Cond2b: Too soon after last SELL (" +
                    IntegerToString(SeqSellMinSecsBetweenOrders) + "s minimum)";
   else if(!SellCond3_NotInNoSellZone()){ 
      blockReason = "Cond3: Price is inside NO SELL ZONE";
//  Print("Cond455555555555: Max SELL orders reached (" +
                    //  (openCountS) + "/" +  (SeqSellMaxOrders) + ")");

   }
   else if(!SellCond4_MaxOrdersNotReached(openCountS))
      blockReason = "Cond4: Max SELL orders reached (" +
                     (openCountS) + "/" +  (SeqSellMaxOrders) + ")";






                      // Print("CondFinal : Max SELL orders reached (" +
                    //  (openCountS) + "/" +  (SeqSellMaxOrders) + ")");
  //  else if(!SellCond5_MinDownfallGap(openCount))
  //     blockReason = "Cond5: Min downfall gap not reached (" +
  //                   IntegerToString(SeqSellMinGapPoints) + "pts required)";
  //  else if(!SellCond6_NoOrderInLoss())
  //     blockReason = "Cond6: An existing SELL order is in loss";
  //  else if(!SellCond8_EMADowntrend())
  //     blockReason = "Cond8: EMA not trending down or is flat (min " +
  //                   IntegerToString(SeqSellEMAFlatMinPts) + "pts slope required)";


else if(!CanOpenTradeAfterCross(OP_SELL))
      blockReason = "Cond10: CROSS Pending or Max orders Reached after cross not allowed (possible fake signal)";


  //  else if(!SellCond9_EMA1BelowEMA2())
  //     blockReason = "Cond9: EMA1 not below EMA2 — no bearish structure";
  //  else if(!SellCond11_M15Downtrend())
  //     blockReason = "Cond11: M30 downtrend not confirmed (need " +
  //                   DoubleToString(TrendMinMovePercent,2) + "% drop over " +
  //                   IntegerToString(TrendLookbackBars) + " bars)";
   Print("Blocked---------  SELL order Reason " + blockReason);

   if(blockReason != "")
     {

      g_blockReason = blockReason;

      // DrawBlockedSellSignal(blockReason);
      return;
     }

   // All conditions passed
   Print("SeqSell | ALL CONDITIONS PASSED - Placing SELL order " + SellPatternContext());
   PlaceSeqSellOrder(ruleIdx);
  }

// Condition 8: EMA1 must be trending DOWN and not flat (straight line)
bool SellCond8_EMADowntrend()
  {
   double emaCurrent = iMA(Symbol(), 0, SeqSellEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPast    = iMA(Symbol(), 0, SeqSellEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, SeqSellEMAShift);
   double slopePts   = (emaPast - emaCurrent) / Point;  // positive = falling

   // Direction check: EMA must be falling
   if(emaCurrent >= emaPast)
     {
      printdummy("SeqSell | BLOCKED [Cond8-EMA1Slope] EMA1(" + IntegerToString(SeqSellEMAPeriod) +
            ") NOT sloping down: was " + DoubleToString(emaPast,5) +
            " now " + DoubleToString(emaCurrent,5) +
            " slope=" + DoubleToString(slopePts,1) + "pts " + SellPatternContext());
      return false;
     }

   // Flatness check: slope must exceed minimum threshold
   if(SeqSellEMAFlatMinPts > 0 && slopePts < SeqSellEMAFlatMinPts)
     {
      printdummy("SeqSell | BLOCKED [Cond8-EMAFlat] EMA1 is STRAIGHT/FLAT: slope=" +
            DoubleToString(slopePts,1) + "pts over " + IntegerToString(SeqSellEMAShift) +
            " bars < min " + IntegerToString(SeqSellEMAFlatMinPts) +
            "pts — sideways market, skip SELL " + SellPatternContext());
      return false;
     }

   LogMessage("SeqSell | Cond8 PASSED - EMA slope=" + DoubleToString(slopePts,1) + "pts DOWN");
   return true;
  }

// Condition 9: EMA1 (fast) must be below EMA2 (slow) = bearish market structure
bool SellCond9_EMA1BelowEMA2()
  {
   double ema1 = iMA(Symbol(), 0, SeqSellEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2 = iMA(Symbol(), 0, SeqSellEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(ema1 < ema2)
      return true;
   printdummy("SeqSell | BLOCKED [Cond9-EMAStructure] EMA1(" + IntegerToString(SeqSellEMAPeriod) + ")=" +
         DoubleToString(ema1,2) + " is NOT below EMA2(" + IntegerToString(SeqSellEMA2Period) + ")=" +
         DoubleToString(ema2,2) + " (no bearish structure) " + SellPatternContext());
   return false;
  }

// Condition 10: Real market check — block fake ticks / broker manipulation
//   A) Spread must not exceed MaxSpreadPoints (absolute)
//   B) Spread must not be spiking vs running average (x SpreadSpikeMultiplier)
//   C) Last closed bar volume must not be suspiciously low vs average
bool SellCond10_RealMarket()
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
      printdummy("SeqSell | BLOCKED [Cond10-SpreadHigh] Spread=" + DoubleToString(currentSpread,1) +
            "pts > max=" + IntegerToString(MaxSpreadPoints) + "pts" +
            " (possible news or broker manipulation) " + SellPatternContext());
      return false;
     }

   // B) Spread spike vs running average
   if(avgSpread > 0 && currentSpread > avgSpread * SpreadSpikeMultiplier)
     {
      printdummy("SeqSell | BLOCKED [Cond10-SpreadSpike] Spread=" + DoubleToString(currentSpread,1) +
            "pts is " + DoubleToString(currentSpread / avgSpread, 1) +
            "x avg=" + DoubleToString(avgSpread,1) +
            "pts (fake spike suspected) " + SellPatternContext());
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
         printdummy("SeqSell | BLOCKED [Cond10-LowVolume] Last bar volume=" + DoubleToString(lastVol,0) +
               " < " + DoubleToString(VolumeMinRatio * 100,0) +
               "% of avg=" + DoubleToString(avgVol,0) +
               " (no real conviction) " + SellPatternContext());
         return false;
        }
     }

   LogMessage("SeqSell | Cond10 PASSED - Spread=" + DoubleToString(currentSpread,1) +
              "pts AvgSpread=" + DoubleToString(avgSpread,1) + "pts Volume OK");
   return true;
  }

// Condition 11: 15-min downtrend confirmation
//   Checks M15 timeframe: current close must be BELOW close TrendLookbackBars ago
//   Ensures we only SELL when the 15-min trend is already falling
bool SellCond11_M15Downtrend()
  {

    return true;
   if(!EnableTrendFilter) return true;
   if(TrendLookbackBars <= 0) return true;

   double closeCurrent = iClose(Symbol(), PERIOD_M1, 0);
   double closePast    = iClose(Symbol(), PERIOD_M1, TrendLookbackBars);

   if(closePast <= 0) return true;  // data not available, allow through

   double priceDrop   = closePast - closeCurrent;          // positive = price fell
   double minRequired = closeCurrent * TrendMinMovePercent  ;  // e.g. 0.15% of price

   bool directionOK  = (closeCurrent < closePast);         // price is lower than N bars ago
   bool magnitudeOK  = (priceDrop >= minRequired);         // drop is large enough

   if(directionOK && magnitudeOK)
     {
      LogMessage("SeqSell | Cond11 PASSED - M30 downtrend: drop=" +
                 DoubleToString(priceDrop / Point, 1) + "pts (" +
                 DoubleToString(priceDrop / closePast * 100.0, 3) + "%) >= min " +
                 DoubleToString(TrendMinMovePercent, 2) + "%");
      return true;
     }

   if(!directionOK)
      printdummy("SeqSell | BLOCKED [Cond11-NoDowntrend] M30 close=" + DoubleToString(closeCurrent,5) +
            " NOT below " + IntegerToString(TrendLookbackBars) + " bars ago=" + DoubleToString(closePast,5) +
            " (price flat/rising — SELL blocked) " + SellPatternContext());
   else
      printdummy("SeqSell | BLOCKED [Cond11-DropTooSmall] Drop=" + DoubleToString(priceDrop/Point,1) + "pts (" +
            DoubleToString(priceDrop/closePast*100.0,3) + "%) < min " + DoubleToString(TrendMinMovePercent,2) +
            "% (" + DoubleToString(minRequired/Point,1) + "pts required) — weak move, skip " +
            SellPatternContext());
   return false;
  }

#endif
