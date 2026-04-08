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
//|  Condition 11: M15 uptrend — close above close N bars ago        |
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
input int      SeqBuyEMAFlatMinPts = 3; // Min EMA movement in points to be considered trending (0=disable flat filter)
input bool     ShowBlockedBuyMarkers = false; // Show/hide blue blocked-BUY rectangles on chart

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

if(isEMATouchesInsideLines==true)
{

}
else
{
  return  false;
}

   if(TimeCurrent() >= g_startupWaitUntil) return true;
  //  printdummy("SeqBuy | BLOCKED [Cond2-Warmup] Order blocked - warming up until " +
  //        TimeToString(g_startupWaitUntil, TIME_MINUTES) + " " + BuyPatternContext());
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
      if(OrderCloseTime() > lastOrderTime) lastOrderTime = OrderCloseTime();
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
  double minGapPrice = 100 * Point;
  double gapPrice = MathMax(TrendBuyDailyHighGapPrice, minGapPrice);
   double dailyHigh = iHigh(Symbol(), PERIOD_D1, 0);
   if(dailyHigh <= 0) return true;
  double zoneBottom = dailyHigh - gapPrice;
   double ask        = MarketInfo(Symbol(), MODE_ASK);
   if(ask < zoneBottom) return true;
  //  printdummy("SeqBuy | BLOCKED [Cond3-NoBuyZone] Price " + DoubleToString(ask,2) +
  //        " is inside NO BUY ZONE (must be < " + DoubleToString(zoneBottom,2) + ") " + BuyPatternContext());
   return false;
  }
void printdummy(string msg)
  {
   // Print(msg);
  }

  //+------------------------------------------------------------------+
//| Allow trade only if RSI is between 30 and 70                     |
//| Works for BOTH BUY & SELL                                       |
//+------------------------------------------------------------------+
bool CanOpenOrder_RSI_Range_old(int rsiPeriod = 14, double minRSI = 35, double maxRSI = 65)
{
   double rsi = iRSI(NULL, 0, rsiPeriod, PRICE_CLOSE, 0);


   // 🔴 Block if outside range
   if(rsi < minRSI || rsi > maxRSI)
   {
      Print("❌ Trade blocked (RSI outside range)");
      return false;
   }

   Print("RSI = ", rsi);


   // ✅ Allow trade
   return true;

  

}

//+------------------------------------------------------------------+
//| Smart Entry Filter (RSI + EMA + Reversal)                        |
//| Returns true = SAFE to trade                                     |
//+------------------------------------------------------------------+
bool CanOpenOrder_RSI_Range(int orderType)
{
   // 🔹 1. RSI Filter
   double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);

   if(rsi < 40 )
   {
       SeqSellProfitTarget=0.50;
      Print("RSI is low (", rsi, ") - setting lower profit target for SELL orders: $", SeqSellProfitTarget);

   }
   else 
   {
       SeqSellProfitTarget=DefaultSellTP;
      Print("RSI is high (", rsi, ") - setting DefaultSellTP profit target for SELL orders: $", DefaultSellTP);

   }

   if(rsi > 60 )
   {
       SeqBuyProfitTarget=0.50;
      Print("RSI is high (", rsi, ") - setting lower profit target for BUY orders: $", SeqBuyProfitTarget);

   }
   else 
   {
       SeqBuyProfitTarget=DefaultBuyTP;
      Print("RSI is low (", rsi, ") - setting DefaultBuyTP profit target for BUY orders: $", DefaultBuyTP);
   }

   return true;

   if(rsi < 40 || rsi > 60)
   {
      Print("❌ Blocked: RSI danger zone (", rsi, ")");
      return false;
   }

   // 🔹 2. EMA Filter (trend + distance)
   double ema = iMA(NULL, 0, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double price = (orderType == OP_BUY) ? Ask : Bid;

   // Auto adjust for BTC / XAG
   double maxDistance;
   if(Symbol() == "XAGUSDm")
      maxDistance = 30 * Point;
   else
      maxDistance = 300 * Point; // BTC default

  //  // Too far from EMA → possible exhaustion
  //  if(MathAbs(price - ema) > maxDistance)
  //  {
  //     Print("❌ Blocked: Price too far from EMA");
  //     return false;
  //  }

  //  // Trend direction filter
  //  if(orderType == OP_BUY && price < ema)
  //  {
  //     Print("❌ Blocked: BUY below EMA (downtrend)");
  //     return false;
  //  }

  //  if(orderType == OP_SELL && price > ema)
  //  {
  //     Print("❌ Blocked: SELL above EMA (uptrend)");
  //     return false;
  //  }

   // 🔹 3. Reversal Detection (last candle)
   double body = MathAbs(Close[1] - Open[1]);
   double upperWick = High[1] - MathMax(Open[1], Close[1]);
   double lowerWick = MathMin(Open[1], Close[1]) - Low[1];

   // Strong rejection = reversal signal
   if(orderType == OP_BUY && upperWick > 2 * body)
   {
      Print("❌ Blocked: Bearish rejection (top)");
      return false;
   }

   if(orderType == OP_SELL && lowerWick > 2 * body)
   {
      Print("❌ Blocked: Bullish rejection (bottom)");
      return false;
   }

   return true; // ✅ SAFE
}
 
// Condition 4: Max open orders not reached
bool BuyCond4_MaxOrdersNotReached(int openCount)
  {
   if(openCount < SeqBuyMaxOrders) return true;
  //  printdummy("SeqBuy | BLOCKED [Cond4-MaxOrders] Already " + IntegerToString(openCount) +
  //        "/" + IntegerToString(SeqBuyMaxOrders) + " BUY orders open " + BuyPatternContext());
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
         printdummy("SeqBuy | BLOCKED [Cond5-Level1] " +
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
         printdummy("SeqBuy | BLOCKED [Cond5-Level2] " +
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
         printdummy("SeqBuy | BLOCKED [Cond6-OrderInLoss] Order #" + IntegerToString(OrderTicket()) +
               " P/L=" + DoubleToString(profit,2) + " is in loss " + BuyPatternContext());
         return false;
        }
     }
   return true;
  }

// Condition 7: SeqRule pattern matched and is NEW_ORDER BUY
bool BuyCond7_PatternMatched(int &ruleIdx)
  {
   // --- Check SeqRules first ---
   /*
   ruleIdx = CheckSeqRules();
   if(ruleIdx >= 0)
     {
      if(g_seqRules[ruleIdx].action != "NEW_ORDER" || g_seqRules[ruleIdx].tradeType != "BUY")
        {
         ruleIdx = -1;  // wrong type — fall through to color rules
        }
      else
        {
         Print("SeqBuy | Cond7 MATCHED SeqRule [" +
               g_seqRules[ruleIdx].prePrev + " | " +
               g_seqRules[ruleIdx].prev    + " | " +
               g_seqRules[ruleIdx].curr    + "]");
         return true;
        }
     }
*/
   // --- Check ColorRules ---
   int cIdx = CheckColorRules("NEW_ORDER", "BUY");
   if(cIdx >= 0)
     {
      ruleIdx = -1;   // no SeqRule index; caller uses -1 to mean "color rule matched"
      Print("SeqBuy | Cond7 MATCHED ColorRule [" + g_colorRules[cIdx].colorType +
            " COUNT>=" + IntegerToString(g_colorRules[cIdx].minCount) +
            "] signal=" + g_liveSignalName + " " + IntegerToString(g_currSeqCount));
      return true;
     } 

   printdummy("SeqBuy | BLOCKED [Cond7-NoMatch] No SeqRule or ColorRule matched---------- "+g_liveSignalName+" " + BuyPatternContext());
   return false;
  }

// Condition 8: EMA1 must be trending UP and not flat (straight line)
bool BuyCond8_EMAUptrend()
  {
   double emaCurrent = iMA(Symbol(), 0, SeqBuyEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPast    = iMA(Symbol(), 0, SeqBuyEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, SeqBuyEMAShift);
   double slopePts   = (emaCurrent - emaPast) / Point;  // positive = rising

   // Direction check: EMA must be rising
   if(emaCurrent <= emaPast)
     {
      printdummy("SeqBuy | BLOCKED [Cond8-EMA1Slope] EMA1(" + IntegerToString(SeqBuyEMAPeriod) +
            ") NOT sloping up: was " + DoubleToString(emaPast,5) +
            " now " + DoubleToString(emaCurrent,5) +
            " slope=" + DoubleToString(slopePts,1) + "pts " + BuyPatternContext());
      return false;
     }

   // Flatness check: slope must exceed minimum threshold
   if(SeqBuyEMAFlatMinPts > 0 && slopePts < SeqBuyEMAFlatMinPts)
     {
      printdummy("SeqBuy | BLOCKED [Cond8-EMAFlat] EMA1 is STRAIGHT/FLAT: slope=" +
            DoubleToString(slopePts,1) + "pts over " + IntegerToString(SeqBuyEMAShift) +
            " bars < min " + IntegerToString(SeqBuyEMAFlatMinPts) +
            "pts — sideways market, skip BUY " + BuyPatternContext());
      return false;
     }

   LogMessage("SeqBuy | Cond8 PASSED - EMA slope=" + DoubleToString(slopePts,1) + "pts UP");
   return true;
  }

// Condition 9: EMA1 (fast) must be above EMA2 (slow) = bullish market structure
bool BuyCond9_EMA1AboveEMA2()
  {
   double ema1 = iMA(Symbol(), 0, SeqBuyEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2 = iMA(Symbol(), 0, SeqBuyEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);

   if(ema1 > ema2)
      return true;
   printdummy("SeqBuy | BLOCKED [Cond9-EMAStructure] EMA1(" + IntegerToString(SeqBuyEMAPeriod) + ")=" +
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

   // ruleIdx == -1 means a ColorRule matched (not a SeqRule) — safe fallback comment
   string comment = "SeqBuy|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].prePrev : "COLOR") + "|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].prev    : g_liveSignalName) + "|" +
                    (ruleIdx >= 0 ? g_seqRules[ruleIdx].curr    : IntegerToString(g_currSeqCount));

   int ticket = OrderSend(Symbol(), OP_BUY, SeqBuyLotSize, ask,
                          SeqBuySlippage, 0, 0,
                          comment, SeqBuyMagicNo, 0, clrLime);
   if(ticket <= 0)
     {
      Print("SeqBuy | ORDER FAILED Error=" + IntegerToString(GetLastError()) +
            " Ask=" + DoubleToString(ask,2) + " " + BuyPatternContext());
      return false;
     }

   string pattern = (ruleIdx >= 0)
                    ? g_seqRules[ruleIdx].prePrev + " | " +
                      g_seqRules[ruleIdx].prev    + " | " +
                      g_seqRules[ruleIdx].curr
                    : "" + g_liveSignalName + "  " + IntegerToString(g_currSeqCount)+" | COLOR   ";

   Print("SeqBuy | *** ORDER CREATED #" + IntegerToString(ticket) + " ***" +
         " Pattern=[" + pattern + "]" +
         " Ask=" + DoubleToString(ask,2) + " Lot=" + DoubleToString(SeqBuyLotSize,2));

   ReportOrderOpened(ticket, pattern, "BUY");
  
   return true;
  }

//+------------------------------------------------------------------+
//| Apply ShowBlockedBuyMarkers toggle to all existing BlkBuy_ objs  |
//+------------------------------------------------------------------+
void RefreshBlockedBuyMarkersVisibility()
  {
   long timeframes = ShowBlockedBuyMarkers ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   int total = ObjectsTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(i);
      if(StringFind(name, "BlkBuy_") == 0)
         ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, timeframes);
     }
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Draw blue dashed rectangle on current bar when BUY is blocked   |
//| Tooltip shows on mouse-hover in MetaTrader chart                 |
//+------------------------------------------------------------------+
void DrawBlockedBuySignal(string reason)
  {
   string ts    = IntegerToString((int)TimeCurrent());
   string nameR = "BlkBuy_R_" + ts;   // rectangle
   string nameT = "BlkBuy_T_" + ts;   // text label
   ObjectDelete(0, nameR);
   ObjectDelete(0, nameT);

   double boxH = High[0] + 8 * Point;
   double boxL = Low[0]  - 8 * Point;
   datetime t1 = Time[0];
   datetime t2 = Time[0] + (datetime)PeriodSeconds(PERIOD_CURRENT);

   // Extract short condition ID: e.g. "Cond9: EMA1 not above EMA2" -> "Cond9"
   string condId = reason;
   int colonPos = StringFind(reason, ":");
   if(colonPos > 0) condId = StringSubstr(reason, 0, colonPos);

   // Rectangle box
   if(ObjectCreate(0, nameR, OBJ_RECTANGLE, 0, t1, boxH, t2, boxL))
     {
      ObjectSetInteger(0, nameR, OBJPROP_COLOR,      clrDodgerBlue);
      ObjectSetInteger(0, nameR, OBJPROP_STYLE,      STYLE_DASH);
      ObjectSetInteger(0, nameR, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, nameR, OBJPROP_BACK,       false);
      ObjectSetInteger(0, nameR, OBJPROP_FILL,       false);
      ObjectSetInteger(0, nameR, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nameR, OBJPROP_HIDDEN,     false);
      ObjectSetString(0,  nameR, OBJPROP_TOOLTIP,
                      "BUY BLOCKED\n" +
                      "Pattern: " + BuyPatternContext() + "\n" +
                      "Reason:  " + reason + "\n" +
                      "Time:    " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
     }

   // Text label inside the box showing condition ID
   if(ObjectCreate(0, nameT, OBJ_TEXT, 0, t1, boxH - 2 * Point))
     {
      ObjectSetString(0,  nameT, OBJPROP_TEXT,      "X " + condId);
      ObjectSetInteger(0, nameT, OBJPROP_COLOR,     clrDodgerBlue);
      ObjectSetInteger(0, nameT, OBJPROP_FONTSIZE,  7);
      ObjectSetString(0,  nameT, OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, nameT, OBJPROP_ANCHOR,    ANCHOR_LEFT_UPPER);
      ObjectSetInteger(0, nameT, OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0, nameT, OBJPROP_HIDDEN,    false);
      ObjectSetString(0,  nameT, OBJPROP_TOOLTIP,
                      "BUY BLOCKED: " + reason);
     }

   // Apply current visibility toggle to the just-created objects
   long timeframes = ShowBlockedBuyMarkers ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;
   ObjectSetInteger(0, nameR, OBJPROP_TIMEFRAMES, timeframes);
   ObjectSetInteger(0, nameT, OBJPROP_TIMEFRAMES, timeframes);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| Main entry: called on new signal detection from OnTick           |
//+------------------------------------------------------------------+
void ProcessSeqBuyOrders()
  {
   // Condition 1 & 7: quick exits — no marker drawn if these fail
   if(g_liveSignalName == "")
     { LogMessage("SeqBuy | Cond1 FAILED - No live signal"); return; }

   int ruleIdx = -1;
   if(!BuyCond7_PatternMatched(ruleIdx)) return;

   // === PATTERN MATCHED — track which condition blocks and draw marker ===
   int    openCount   = CountOpenSeqBuyOrders();
   string blockReason = "";

   if(!CanOpenOrder_RSI_Range(OP_BUY))
      blockReason = "Cond1: RSI not in allowed range (30-70)";
    else

   if(!BuyCond2_WarmupElapsed())
      blockReason = "Cond2: Warmup not elapsed yet";
   else if(!BuyCond2b_MinTimeBetweenOrders())
      blockReason = "Cond2b: Too soon after last BUY (" +
                    IntegerToString(SeqBuyMinSecsBetweenOrders) + "s minimum)";
   else if(!BuyCond3_NotInNoBuyZone())
      blockReason = "Cond3: Price is inside NO BUY ZONE";
   else if(!BuyCond4_MaxOrdersNotReached(openCount))
      blockReason = "Cond4: Max BUY orders reached (" +
                    IntegerToString(openCount) + "/" + IntegerToString(SeqBuyMaxOrders) + ")";
  //  else if(!BuyCond5_MinUpriseGap(openCount))
  //     blockReason = "Cond5: Min uprise gap not reached (" +
  //                   IntegerToString(SeqBuyMinGapPoints) + "pts required)";
  //  else if(!BuyCond6_NoOrderInLoss())
  //     blockReason = "Cond6: An existing BUY order is in loss";
   else if(!BuyCond8_EMAUptrend())
      blockReason = "Cond8: EMA not trending up or is flat (min " +
                    IntegerToString(SeqBuyEMAFlatMinPts) + "pts slope required)";
   else if(!BuyCond9_EMA1AboveEMA2())
      blockReason = "Cond9: EMA1 not above EMA2 — no bullish structure";
  //  else if(!BuyCond11_M15Uptrend())
  //     blockReason = "Cond11: M30 uptrend not confirmed (need " +
  //                   DoubleToString(TrendMinMovePercent,2) + "% rise over " +
  //                   IntegerToString(TrendLookbackBars) + " bars)";
   Print("Blocked---------  BUY order Reason " + blockReason);

   if(blockReason != "")
     {
      DrawBlockedBuySignal(blockReason);
      return;
     }

   // All conditions passed
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
      printdummy("SeqBuy | BLOCKED [Cond10-SpreadHigh] Spread=" + DoubleToString(currentSpread,1) +
            "pts > max=" + IntegerToString(MaxSpreadPoints) + "pts" +
            " (possible news or broker manipulation) " + BuyPatternContext());
      return false;
     }

   // B) Spread spike vs running average
   if(avgSpread > 0 && currentSpread > avgSpread * SpreadSpikeMultiplier)
     {
      printdummy("SeqBuy | BLOCKED [Cond10-SpreadSpike] Spread=" + DoubleToString(currentSpread,1) +
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
         printdummy("SeqBuy | BLOCKED [Cond10-LowVolume] Last bar volume=" + DoubleToString(lastVol,0) +
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

// Condition 11: 15-min uptrend confirmation
//   Checks M15 timeframe: current close must be ABOVE close TrendLookbackBars ago
//   Ensures we only BUY when the 15-min trend is already rising
bool BuyCond11_M15Uptrend()
  {

    return true;
   if(!EnableTrendFilter) return true;
   if(TrendLookbackBars <= 0) return true;

   double closeCurrent = iClose(Symbol(), PERIOD_M1, 0);
   double closePast    = iClose(Symbol(), PERIOD_M1, TrendLookbackBars);

   if(closePast <= 0) return true;  // data not available, allow through

   double priceRise   = closeCurrent - closePast;          // positive = price rose
   double minRequired = closeCurrent * TrendMinMovePercent  ;  // e.g. 0.15% of price

   bool directionOK  = (closeCurrent > closePast);         // price is higher than N bars ago
   bool magnitudeOK  = (priceRise >= minRequired);         // rise is large enough

   if(directionOK && magnitudeOK)
     {
      LogMessage("SeqBuy | Cond11 PASSED - M30 uptrend: rise=" +
                 DoubleToString(priceRise / Point, 1) + "pts (" +
                 DoubleToString(priceRise / closePast * 100.0, 3) + "%) >= min " +
                 DoubleToString(TrendMinMovePercent, 2) + "%");
      return true;
     }

   if(!directionOK)
      printdummy("SeqBuy | BLOCKED [Cond11-NoUptrend] M30 close=" + DoubleToString(closeCurrent,5) +
            " NOT above " + IntegerToString(TrendLookbackBars) + " bars ago=" + DoubleToString(closePast,5) +
            " (price flat/falling — BUY blocked) " + BuyPatternContext());
   else
      printdummy("SeqBuy | BLOCKED [Cond11-RiseTooSmall] Rise=" + DoubleToString(priceRise/Point,1) + "pts (" +
            DoubleToString(priceRise/closePast*100.0,3) + "%) < min " + DoubleToString(TrendMinMovePercent,2) +
            "% (" + DoubleToString(minRequired/Point,1) + "pts required) — weak move, skip " +
            BuyPatternContext());
   return false;
  }

#endif
