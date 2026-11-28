//+------------------------------------------------------------------+
//|                                     V_Small_Type1_Oscillation.mqh|
//|         TYPE 1: Range / Steep Angle Engine (|Angle| <= 3 or > 8) |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Active when |Angle| <= 3.0 or |Angle| > 8.0 (not in Spike)    |
//| 2. Individual order profits follow Table A price-gap movement    |
//|    ($100 L1 -> +$25 SL, every +$50 step -> +$50 SL + half-close) |
//| 3. Sideways Peak-Stall Collector (|Angle| <= 3.0): secures profit|
//|    when sideways price stalls at ceiling/floor ($60+ move, 10m   |
//|    plateau) and places auto-expiring breakout pending or waits   |
//| 4. Basket, Day Target & Method 6 profit engines run as usual     |
//| 5. Independent performance tracking and telemetry                |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Type 1 Telemetry Metrics
int    g_type1ClosedTrades = 0;
double g_type1ClosedProfit = 0.0;
int    g_type1WinCount     = 0;
int    g_type1LossCount    = 0;

// Type 1 Sideways Peak-Stall State Trackers (self-pruning per open ticket)
int      g_t1PeakTickets[];
double   g_t1BestExcursion[];
double   g_t1PlateauAnchor[];
datetime g_t1LastPushTime[];

// Armed tight-SL Type 1 tickets awaiting exit detection for breakout pending / telemetry
int      g_t1ArmedCloseTickets[];
int      g_t1ArmedCloseTypes[];

//+------------------------------------------------------------------+
//| FindType1TicketSlot: Locate index of ticket in parallel arrays   |
//+------------------------------------------------------------------+
int FindType1TicketSlot(const int &arr[], int ticket)
  {
   int n = ArraySize(arr);
   for(int i = 0; i < n; i++)
     {
      if(arr[i] == ticket)
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| RemoveType1StallTrackerAt: Remove slot cleanly from peak arrays  |
//+------------------------------------------------------------------+
void RemoveType1StallTrackerAt(int idx)
  {
   int n = ArraySize(g_t1PeakTickets);
   if(idx < 0 || idx >= n)
      return;
   int last = n - 1;
   if(idx != last)
     {
      g_t1PeakTickets[idx]   = g_t1PeakTickets[last];
      g_t1BestExcursion[idx] = g_t1BestExcursion[last];
      g_t1PlateauAnchor[idx] = g_t1PlateauAnchor[last];
      g_t1LastPushTime[idx]  = g_t1LastPushTime[last];
     }
   ArrayResize(g_t1PeakTickets, last);
   ArrayResize(g_t1BestExcursion, last);
   ArrayResize(g_t1PlateauAnchor, last);
   ArrayResize(g_t1LastPushTime, last);
  }

//+------------------------------------------------------------------+
//| RemoveType1ArmedSlotAt: Remove slot cleanly from armed arrays    |
//+------------------------------------------------------------------+
void RemoveType1ArmedSlotAt(int idx)
  {
   int n = ArraySize(g_t1ArmedCloseTickets);
   if(idx < 0 || idx >= n)
      return;
   int last = n - 1;
   if(idx != last)
     {
      g_t1ArmedCloseTickets[idx] = g_t1ArmedCloseTickets[last];
      g_t1ArmedCloseTypes[idx]   = g_t1ArmedCloseTypes[last];
     }
   ArrayResize(g_t1ArmedCloseTickets, last);
   ArrayResize(g_t1ArmedCloseTypes, last);
  }

//+------------------------------------------------------------------+
//| RegisterType1ArmedTicket: Track ticket with stall-tightened SL   |
//+------------------------------------------------------------------+
void RegisterType1ArmedTicket(int ticket, int oType)
  {
   if(ticket <= 0 || FindType1TicketSlot(g_t1ArmedCloseTickets, ticket) >= 0)
      return;
   int n = ArraySize(g_t1ArmedCloseTickets);
   ArrayResize(g_t1ArmedCloseTickets, n + 1);
   ArrayResize(g_t1ArmedCloseTypes, n + 1);
   g_t1ArmedCloseTickets[n] = ticket;
   g_t1ArmedCloseTypes[n]   = oType;
  }

//+------------------------------------------------------------------+
//| UpdateType1OrderPeakState: Track best excursion & stall plateau  |
//+------------------------------------------------------------------+
void UpdateType1OrderPeakState(int ticket, int oType, double openPrice, datetime openTime, double curPrice,
                               double &outPeakPrice, datetime &outLastPushTime)
  {
   bool isBuy = (oType == OP_BUY);
   int idx = FindType1TicketSlot(g_t1PeakTickets, ticket);
   double pushStep = (InpType1StallNewPeakPushStepRaw > 0.0) ? InpType1StallNewPeakPushStepRaw : 10.0;

   if(idx < 0)
     {
      // Seed initial peak from M1 bars since order entry so EA restarts keep accurate plateau timing
      double initPeak = curPrice;
      datetime initTime = TimeCurrent();
      int barsSince = iBarShift(Symbol(), PERIOD_M1, openTime, false);
      if(barsSince >= 1)
        {
         // Scan shifts 0..(barsSince-1) strictly after the opening M1 candle to exclude pre-entry wicks
         int scanBars = MathMin(barsSince, 240);
         int extrIdx = isBuy ? iHighest(Symbol(), PERIOD_M1, MODE_HIGH, scanBars, 0)
                             : iLowest(Symbol(), PERIOD_M1, MODE_LOW, scanBars, 0);
         if(extrIdx >= 0)
           {
            double barExtr = isBuy ? iHigh(Symbol(), PERIOD_M1, extrIdx) : iLow(Symbol(), PERIOD_M1, extrIdx);
            bool better = isBuy ? (barExtr > initPeak) : (barExtr > 0.0 && barExtr < initPeak);
            if(better)
              {
               initPeak = barExtr;
               initTime = iTime(Symbol(), PERIOD_M1, extrIdx);
               if(initTime < openTime)
                  initTime = openTime;
              }
           }
        }
      if((isBuy && initPeak < openPrice) || (!isBuy && initPeak > openPrice))
        {
         initPeak = curPrice;
         initTime = TimeCurrent();
        }

      idx = ArraySize(g_t1PeakTickets);
      ArrayResize(g_t1PeakTickets, idx + 1);
      ArrayResize(g_t1BestExcursion, idx + 1);
      ArrayResize(g_t1PlateauAnchor, idx + 1);
      ArrayResize(g_t1LastPushTime, idx + 1);

      g_t1PeakTickets[idx]   = ticket;
      g_t1BestExcursion[idx] = initPeak;
      g_t1PlateauAnchor[idx] = initPeak;
      g_t1LastPushTime[idx]  = initTime;
     }
   else
     {
      bool beatBest = isBuy ? (curPrice > g_t1BestExcursion[idx]) : (curPrice < g_t1BestExcursion[idx]);
      if(beatBest)
         g_t1BestExcursion[idx] = curPrice;

      // Only reset stall clock when price clears the previous stalled plateau by >= InpType1StallNewPeakPushStepRaw
      bool brokePlateau = isBuy ? (curPrice >= g_t1PlateauAnchor[idx] + pushStep)
                                : (curPrice <= g_t1PlateauAnchor[idx] - pushStep);
      if(brokePlateau)
        {
         g_t1PlateauAnchor[idx] = curPrice;
         g_t1LastPushTime[idx]  = TimeCurrent();
        }
     }

   outPeakPrice    = g_t1BestExcursion[idx];
   outLastPushTime = g_t1LastPushTime[idx];
  }

//+------------------------------------------------------------------+
//| CreateType1StallBreakoutPendingOrder:                            |
//| Places breakout pending stop after sideways stall profit exit    |
//| ONLY when 0 open market & 0 pending orders exist in same dir.    |
//+------------------------------------------------------------------+
void CreateType1StallBreakoutPendingOrder(int dirType)
  {
   if(!InpEnableType1Orders || !InpType1StallCreatePendingOnClose || (dirType != OP_BUY && dirType != OP_SELL))
      return;

   bool isBuy = (dirType == OP_BUY);
   int expectedPendingType = isBuy ? OP_BUYSTOP : OP_SELLSTOP;

   int openSameDir = 0;
   int pendingSameDir = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int t = OrderType();
      if(t == dirType)
         openSameDir++;
      else if(t == expectedPendingType)
         pendingSameDir++;
     }

   if(openSameDir > 0 || pendingSameDir > 0)
     {
      PrintFormat(">>> [TYPE 1 STALL PENDING SKIPPED] %s open=%d pending=%d -> waiting for existing order/signal.",
                  (isBuy ? "BUY" : "SELL"), openSameDir, pendingSameDir);
      return;
     }

   if(!EnableTrading || GetTotalEAOrders() >= MaxOpenOrders || !PassesEMAFilter(dirType) ||
      !IsSafeToCreateMarketOrder(dirType) || (InpEnableCustomRules && !PassesUserRules(dirType)))
     {
      PrintFormat(">>> [TYPE 1 STALL WAIT] %s gate inactive -> waiting for fresh signal instead of placing pending stop.",
                  (isBuy ? "BUY" : "SELL"));
      return;
     }

   RefreshRates();
   double gapRaw      = (InpType1StallPendingBreakoutGapRaw > 0.0) ? InpType1StallPendingBreakoutGapRaw : 30.0;
   double minStopDist = GetRequiredStopDistance();
   if(gapRaw < minStopDist)
      gapRaw = minStopDist;

   double entryPrice  = NormalizeDouble(isBuy ? (Ask + gapRaw) : (Bid - gapRaw), Digits);
   double slDistance  = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance  = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   double stopLoss    = (slDistance > 0.0) ? NormalizeDouble(isBuy ? (entryPrice - slDistance) : (entryPrice + slDistance), Digits) : 0.0;
   double takeProfit  = (tpDistance > 0.0) ? NormalizeDouble(isBuy ? (entryPrice + tpDistance) : (entryPrice - tpDistance), Digits) : 0.0;

   ChangeLots(isBuy ? GlobalSellPL : GlobalBuyPL, isBuy ? "SSL Long" : "SSL Short", dirType, 0, "");
   Lots = NormalizeLots(Lots);

   string comment  = isBuy ? "T1_STALL_PENDING BUY" : "T1_STALL_PENDING SELL";
   color  clr      = isBuy ? BuyColor : SellColor;

   int ticket = SafeOrderSend(Symbol(), expectedPendingType, Lots, entryPrice, Slippage, stopLoss, takeProfit, comment, MagicNumber, clr);
   if(ticket > 0)
     {
      PrintFormat(">>> [TYPE 1 STALL PENDING CREATED] #%d %s Lots=%.2f Entry=%s (Gap=$%.1f, AutoExpire=%ds)",
                  ticket, comment, Lots, DoubleToString(entryPrice, Digits), gapRaw, InpType1StallPendingExpireSec);
      InvalidateTotalEAOrdersCache();
     }
  }

//+------------------------------------------------------------------+
//| HandleType1StallClosedOrder: Record Type 1 exit & optional pend  |
//+------------------------------------------------------------------+
void HandleType1StallClosedOrder(int closedTicket, int closedType, double netPL)
  {
   RecordType1ClosedOrder(closedTicket, netPL);
   if(netPL > 0.0)
      CreateType1StallBreakoutPendingOrder(closedType);
  }

//+------------------------------------------------------------------+
//| CleanupType1StallPendingAndArmedOrders:                          |
//| 1. Auto-expires stale or EMA-flipped T1_STALL_PENDING orders     |
//| 2. Detects tight-SL-closed armed tickets & triggers pending/wait |
//| 3. Prunes peak state for tickets no longer open                  |
//+------------------------------------------------------------------+
void CleanupType1StallPendingAndArmedOrders()
  {
   datetime nowSec = TimeCurrent();

   // 1. Auto-cancel expired or EMA-opposite T1_STALL_PENDING orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int oType = OrderType();
      if(oType != OP_BUYSTOP && oType != OP_SELLSTOP)
         continue;
      if(StringFind(OrderComment(), "T1_STALL_PENDING") < 0)
         continue;

      bool expired = (InpType1StallPendingExpireSec > 0 && (nowSec - OrderOpenTime()) >= InpType1StallPendingExpireSec);
      bool flipped = ((oType == OP_BUYSTOP && EMADirection == -1) || (oType == OP_SELLSTOP && EMADirection == 1));
      if(expired || flipped)
        {
         int tkt = OrderTicket();
         PrintFormat(">>> [TYPE 1 STALL PENDING CANCELLED] #%d %s (%s) -> waiting for next signal.",
                     tkt, OrderComment(), (flipped ? "EMA Flipped Opposite" : "Breakout Window Expired"));
         SafeOrderDelete(tkt, clrGray);
        }
     }

   // 2. Check armed tight-SL Type 1 tickets for broker SL fill
   for(int a = ArraySize(g_t1ArmedCloseTickets) - 1; a >= 0; a--)
     {
      int armedTkt = g_t1ArmedCloseTickets[a];
      int armedType = g_t1ArmedCloseTypes[a];
      if(OrderSelect(armedTkt, SELECT_BY_TICKET, MODE_TRADES) && OrderCloseTime() == 0)
         continue;

      if(OrderSelect(armedTkt, SELECT_BY_TICKET, MODE_HISTORY) && OrderCloseTime() > 0)
        {
         double closedPL = OrderProfit() + OrderSwap() + OrderCommission();
         PrintFormat(">>> [TYPE 1 STALL SL CLOSED] Ticket #%d (%s) hit stall SL | Net P/L=$%.2f",
                     armedTkt, (armedType == OP_BUY ? "BUY" : "SELL"), closedPL);
         RemoveType1ArmedSlotAt(a);
         HandleType1StallClosedOrder(armedTkt, armedType, closedPL);
        }
      else
        {
         RemoveType1ArmedSlotAt(a);
        }
     }

   // 3. Prune peak trackers for tickets no longer open
   for(int p = ArraySize(g_t1PeakTickets) - 1; p >= 0; p--)
     {
      int tkt = g_t1PeakTickets[p];
      if(!OrderSelect(tkt, SELECT_BY_TICKET, MODE_TRADES) || OrderCloseTime() > 0)
         RemoveType1StallTrackerAt(p);
     }
  }

//+------------------------------------------------------------------+
//| IsType1OscillationActive: Check if Type 1 regime is active       |
//+------------------------------------------------------------------+
bool IsType1OscillationActive()
  {
   // If Type 3 Spike is active, Type 1 is held
   if(IsType3SpikeActive())
      return false;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   // Active outside Type 2 range (|Angle| <= 3.0 or |Angle| > 8.0) -> uses Table A
   return !IsLadderType2AngleRange(MathAbs(curAngle));
  }

//+------------------------------------------------------------------+
//| ManageType1ProfitBooking: Dedicated Type 1 Profit Booking Engine |
//| - Individual SL Ladder follows Table A ($100 L1 / $50 step) via  |
//|   SecureOneDollarProfit() without early BE clamping.             |
//| - In Flat Sideways (|Angle| <= 3.0): tracks each order's peak &  |
//|   detects sideways stall at ceiling/floor ($60+ move, 10m no push|
//|   ) -> tightens live SL ($15 behind price) or closes on retrace, |
//|   then creates auto-expiring breakout pending or waits.          |
//+------------------------------------------------------------------+
void ManageType1ProfitBooking()
  {
   if(!IsType1OscillationActive() || !InpEnableType1SidewayStallCollect)
      return;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   // Sideways stall collection runs strictly in Flat Range (|Angle| <= 3.0), never choking >8 deg runners
   if(MathAbs(curAngle) > InpLadderAngleRangeMin)
      return;

   double mult        = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double minFavMove  = (InpType1StallMinFavMoveRaw > 0.0) ? InpType1StallMinFavMoveRaw : 60.0;
   double minProfit   = (InpType1StallMinProfitUSD > 0.0 ? InpType1StallMinProfitUSD : 0.50) * mult;
   int    stallSecReq = (InpType1StallTimeoutSeconds > 0) ? InpType1StallTimeoutSeconds : 600;
   double retraceRaw  = (InpType1StallTrailOrRetraceRaw > 0.0) ? InpType1StallTrailOrRetraceRaw : 15.0;
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10.0)
      minStopDist = Point * 10.0;
   double trailBuffer = MathMax(minStopDist, retraceRaw);
   double slGapMin    = GetEffectiveMinSLModifyGap();

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      int tkt = OrderTicket();
      string cmt = OrderComment();
      if(IsFLIPBasketSupportOrder(tkt, cmt) || IsAnyRecoveryOrder(tkt, cmt) || IsType3ManagedOrder(tkt, cmt))
         continue;

      bool   isBuy     = (oType == OP_BUY);
      double curPrice  = isBuy ? Bid : Ask;
      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      double curTP     = OrderTakeProfit();
      double netPL     = OrderProfit() + OrderSwap() + OrderCommission();

      double peakPrice = curPrice;
      datetime lastPushTime = TimeCurrent();
      UpdateType1OrderPeakState(tkt, oType, openPrice, OrderOpenTime(), curPrice, peakPrice, lastPushTime);

      double peakMove = isBuy ? (peakPrice - openPrice) : (openPrice - peakPrice);
      double curMove  = isBuy ? (curPrice - openPrice) : (openPrice - curPrice);
      double retrace  = peakMove - curMove;
      int    elapsedStall = (int)(TimeCurrent() - lastPushTime);

      if(peakMove < minFavMove || curMove < MathMax(20.0, minFavMove * 0.5) || netPL < minProfit)
         continue;
      if(elapsedStall < stallSecReq)
         continue;

      // Sideways Stall Confirmed: Collect at market if configured or already retracing >= $15 from peak
      if(InpType1StallDirectMarketClose || retrace >= retraceRaw)
        {
         PrintFormat(">>> [TYPE 1 STALL COLLECT CLOSE] #%d %s | PeakMove=$%.1f, CurMove=$%.1f, Retrace=$%.1f, Stall=%ds, P/L=$%.2f",
                     tkt, (isBuy ? "BUY" : "SELL"), peakMove, curMove, retrace, elapsedStall, netPL);
         if(SafeOrderCloseMarket(tkt, OrderLots(), Slippage, (isBuy ? clrLime : clrOrangeRed)))
           {
            int peakSlot = FindType1TicketSlot(g_t1PeakTickets, tkt);
            if(peakSlot >= 0)
               RemoveType1StallTrackerAt(peakSlot);
            int armedSlot = FindType1TicketSlot(g_t1ArmedCloseTickets, tkt);
            if(armedSlot >= 0)
               RemoveType1ArmedSlotAt(armedSlot);
            HandleType1StallClosedOrder(tkt, oType, netPL);
           }
        }
      else
        {
         // Still holding right near ceiling/floor: lock tight live SL $15 behind price (MethodT1SidewayStall keeps breakout upside)
         double targetSL = NormalizeDouble(isBuy ? (curPrice - trailBuffer) : (curPrice + trailBuffer), Digits);
         bool validDirSL = isBuy ? (targetSL > openPrice && targetSL < curPrice) : (targetSL < openPrice && targetSL > curPrice);
         bool improvesSL = isBuy ? (curSL == 0.0 || targetSL > curSL + slGapMin)
                                 : (curSL == 0.0 || targetSL < curSL - slGapMin);
         if(validDirSL && improvesSL)
           {
            if(SafeOrderModify(tkt, openPrice, targetSL, curTP, 0, (isBuy ? clrLimeGreen : clrTomato), "MethodT1SidewayStall"))
              {
               RegisterType1ArmedTicket(tkt, oType);
               PrintFormat(">>> [TYPE 1 STALL TIGHT SL] #%d %s | PeakMove=$%.1f, CurMove=$%.1f, Stall=%ds -> SL=%s ($%.1f lock)",
                           tkt, (isBuy ? "BUY" : "SELL"), peakMove, curMove, elapsedStall,
                           DoubleToString(targetSL, Digits), MathAbs(targetSL - openPrice));
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| RecordType1ClosedOrder: Tracks Type 1 trade outcome              |
//+------------------------------------------------------------------+
void RecordType1ClosedOrder(int ticket, double netPL)
  {
   g_type1ClosedTrades++;
   g_type1ClosedProfit += netPL;
   if(netPL >= 0.0)
      g_type1WinCount++;
   else
      g_type1LossCount++;
  }
