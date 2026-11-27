//+------------------------------------------------------------------+
//|                                        V_Small_TwoWayEngine.mqh  |
//|                 Method 7: Two-Way Waterfall & V-Rebound Engine   |
//|                                                                  |
//| Handles:                                                         |
//| 1. Falling/Rising Waterfall orders with trailing profit ratchets |
//| 2. Pivot Hand-Off: Freeze trend orders & purge opposite pending  |
//| 3. Climax Rebound orders (M7_EQL_REBOUND / M7_EQH_REBOUND)      |
//| 4. 3-Tier Profit Harvesting (Breakeven, Step-Trail, EMA Retest)  |
//| 5. Climax opposite runner liquidation to prevent deep drawdowns  |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Static tracking for 1-order-per-line enforcement
static datetime s_lastTwoWayHandledEqlStart = 0;
static datetime s_lastTwoWayHandledEqhStart = 0;
static datetime s_lastTwoWayPurgedEqlStart  = 0;
static datetime s_lastTwoWayPurgedEqhStart  = 0;
static datetime s_lastTwoWayFallOrderTime   = 0;
static datetime s_lastTwoWayRiseOrderTime   = 0;
static double   s_lastFallingMilestoneDist  = 0.0;
static double   s_lastRisingMilestoneDist   = 0.0;

//+------------------------------------------------------------------+
//| GetTwoWayClimaxMinDistance: Enforces minimum $1000 threshold     |
//+------------------------------------------------------------------+
double GetTwoWayClimaxMinDistance()
  {
   return (InpTwoWayClimaxEmaDistance >= 1000.0) ? InpTwoWayClimaxEmaDistance : 1000.0;
  }

//+------------------------------------------------------------------+
//| IsTwoWayFreezeTrendActive: Check if trend orders should be frozen|
//+------------------------------------------------------------------+
bool IsTwoWayFreezeTrendActive(int requestedDirection)
  {
   if(!InpEnableTwoWayEngine || !InpTwoWayFreezeTrendOnHLineStart)
      return false;

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma <= 0.0)
      return false;

   double minClimaxDist = GetTwoWayClimaxMinDistance();

   // If SELL requested (trend following dump), check if Green Line (EQL-G) is active at the floor
   if(requestedDirection == -1)
     {
      bool isGreenActive = (GetLsdSweepActiveEqlLineStart() > 0 &&
                           (IsLsdSweepGreenLinePresent() || GetEQR_G_Price(true) > 0.0));
      if(isGreenActive && Bid < liveEma)
        {
         double distBelowEma = liveEma - Bid;
         if(distBelowEma >= minClimaxDist)
            return true; // FREEZE trend SELL into the bottom!
        }
     }

   // If BUY requested (trend following rocket), check if Red Line (EQH-R) is active at the ceiling
   if(requestedDirection == 1)
     {
      bool isRedActive = (GetLsdSweepActiveEqhLineStart() > 0 &&
                         (IsLsdSweepRedLinePresent() || GetEQR_R_Price(true) > 0.0));
      if(isRedActive && Ask > liveEma)
        {
         double distAboveEma = Ask - liveEma;
         if(distAboveEma >= minClimaxDist)
            return true; // FREEZE trend BUY into the top!
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| PurgeTwoWayPendingStopsOnHLine: Delete pending stops on pivot    |
//+------------------------------------------------------------------+
void PurgeTwoWayPendingStopsOnHLine(int sideToPurge)
  {
   if(!InpTwoWayPurgePendingOnHLineStart)
      return;

   for(int p = OrdersTotal() - 1; p >= 0; p--)
     {
      if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int pType = OrderType();
      // Purge SELL pending (SELLSTOP / SELLLIMIT) when green line starts at bottom
      if(sideToPurge == -1 && (pType == OP_SELLSTOP || pType == OP_SELLLIMIT))
        {
         PrintFormat(">>> [TWO-WAY ENGINE PIVOT] Purging pending SELL #%d (Type=%d, Lots=%.2f) to protect floor!",
                     OrderTicket(), pType, OrderLots());
         SafeOrderDelete(OrderTicket(), clrRed);
        }
      // Purge BUY pending (BUYSTOP / BUYLIMIT) when red line starts at top
      if(sideToPurge == 1 && (pType == OP_BUYSTOP || pType == OP_BUYLIMIT))
        {
         PrintFormat(">>> [TWO-WAY ENGINE PIVOT] Purging pending BUY #%d (Type=%d, Lots=%.2f) to protect ceiling!",
                     OrderTicket(), pType, OrderLots());
         SafeOrderDelete(OrderTicket(), clrGreen);
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckTwoWayClimaxRunnerLiquidation: Prevent deep runner losses   |
//+------------------------------------------------------------------+
void CheckTwoWayClimaxRunnerLiquidation(double emaDist, int emaDir)
  {
   double minClimax = GetTwoWayClimaxMinDistance();
   if(!InpTwoWayCutOppositeRunnersOnClimax || emaDist < minClimax)
      return;

   double mult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double maxLossThreshold = 5.0 * mult;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      // If market is cascading down (emaDir == -1), cut opposite BUY runners floating deep in loss
      if(emaDir == -1 && OrderType() == OP_BUY)
        {
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         if(pl <= -maxLossThreshold)
           {
            PrintFormat(">>> [TWO-WAY ENGINE RUNNER CUT] Climax fall detected (EMA Dist=$%.2f >= $%.2f). Liquidating counter-trend BUY #%d (P/L=$%.2f) to protect equity!",
                        emaDist, minClimax, OrderTicket(), pl);
            SafeOrderCloseMarket(OrderTicket(), OrderLots(), Slippage, clrYellow);
           }
        }

      // If market is rocketing up (emaDir == 1), cut opposite SELL runners floating deep in loss
      if(emaDir == 1 && OrderType() == OP_SELL)
        {
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         if(pl <= -maxLossThreshold)
           {
            PrintFormat(">>> [TWO-WAY ENGINE RUNNER CUT] Climax rocket detected (EMA Dist=$%.2f >= $%.2f). Liquidating counter-trend SELL #%d (P/L=$%.2f) to protect equity!",
                        emaDist, minClimax, OrderTicket(), pl);
            SafeOrderCloseMarket(OrderTicket(), OrderLots(), Slippage, clrYellow);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckTwoWayFallingAndRisingOrders: The Waterfall Cascade Engine  |
//| Creates orders as distance from EMA INCREASES during drops/surges|
//+------------------------------------------------------------------+
void CheckTwoWayFallingAndRisingOrders(double liveEma, double emaDist, int emaDir)
  {
   if(liveEma <= 0.0)
      return;

   double mult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double baseLots = (InpTwoWayWaterfallLotBase > 0.0) ? InpTwoWayWaterfallLotBase : 0.01;
   double lots = NormalizeLots(baseLots * mult);
   if(lots <= 0.0)
      lots = 0.01;

   int maxOrders = (InpTwoWayMaxWaterfallOrders > 0) ? InpTwoWayMaxWaterfallOrders : 6;
   double startDist = (InpTwoWayWaterfallStartDist > 0.0) ? InpTwoWayWaterfallStartDist : 150.0;
   double stepDist = (InpTwoWayWaterfallStepRaw > 0.0) ? InpTwoWayWaterfallStepRaw : 150.0;
   double initSL = (InpTwoWayWaterfallInitialSL > 0.0) ? InpTwoWayWaterfallInitialSL : 250.0;

   // -------------------------------------------------------------
   // 1. FALLING WATERFALL ORDERS (SELL on downward momentum)
   // -------------------------------------------------------------
   if(InpTwoWayEnableFallingOrders)
     {
      // If price returns near or above EMA, reset the falling milestone distance
      if(Bid >= (liveEma - 50.0))
        {
         s_lastFallingMilestoneDist = 0.0;
        }
      else if(Bid < (liveEma - startDist))
        {
         double curDistBelow = liveEma - Bid;

         // Check if Green Horizontal Line (EQL-G) is active at the floor
         bool isGreenActive = IsTwoWayFreezeTrendActive(-1);

         // Only open falling SELL orders if floor hasn't initiated
         if(!isGreenActive)
           {
            // Determine if a new distance milestone is reached
            bool isMilestoneReached = false;
            if(s_lastFallingMilestoneDist <= 0.0)
              {
               isMilestoneReached = true;
              }
            else if(curDistBelow >= (s_lastFallingMilestoneDist + stepDist))
              {
               isMilestoneReached = true;
              }

            if(isMilestoneReached)
              {
               int fallingCount = 0;
               for(int i = 0; i < OrdersTotal(); i++)
                 {
                  if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                     continue;
                  if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                     continue;
                  if(OrderType() == OP_SELL && StringFind(OrderComment(), "M7_FALL") == 0)
                     fallingCount++;
                 }

               if(fallingCount < maxOrders && (TimeCurrent() - s_lastTwoWayFallOrderTime >= 5))
                 {
                  RefreshRates();
                  double sl = NormalizeDouble(Ask + initSL, Digits);
                  int tkt = SafeOrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, 0, "M7_FALL_SELL", MagicNumber, clrRed);
                  if(tkt > 0)
                    {
                     s_lastFallingMilestoneDist = curDistBelow;
                     s_lastTwoWayFallOrderTime = TimeCurrent();
                     PrintFormat(">>> [TWO-WAY ENGINE] Opened Falling SELL #%d (Order #%d/%d) at %.2f | Dist to EMA=$%.2f (Milestone Step=$%.2f)",
                                 tkt, fallingCount + 1, maxOrders, Bid, curDistBelow, stepDist);
                    }
                 }
              }
           }
        }
     }

   // -------------------------------------------------------------
   // 2. RISING SURGE ORDERS (BUY on upward momentum)
   // -------------------------------------------------------------
   if(InpTwoWayEnableRisingOrders)
     {
      // If price returns near or below EMA, reset the rising milestone distance
      if(Ask <= (liveEma + 50.0))
        {
         s_lastRisingMilestoneDist = 0.0;
        }
      else if(Ask > (liveEma + startDist))
        {
         double curDistAbove = Ask - liveEma;

         // Check if Red Horizontal Line (EQH-R) is active at the ceiling
         bool isRedActive = IsTwoWayFreezeTrendActive(1);

         // Only open rising BUY orders if ceiling hasn't initiated
         if(!isRedActive)
           {
            // Determine if a new distance milestone is reached
            bool isMilestoneReached = false;
            if(s_lastRisingMilestoneDist <= 0.0)
              {
               isMilestoneReached = true;
              }
            else if(curDistAbove >= (s_lastRisingMilestoneDist + stepDist))
              {
               isMilestoneReached = true;
              }

            if(isMilestoneReached)
              {
               int risingCount = 0;
               for(int i = 0; i < OrdersTotal(); i++)
                 {
                  if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                     continue;
                  if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                     continue;
                  if(OrderType() == OP_BUY && StringFind(OrderComment(), "M7_RISE") == 0)
                     risingCount++;
                 }

               if(risingCount < maxOrders && (TimeCurrent() - s_lastTwoWayRiseOrderTime >= 5))
                 {
                  RefreshRates();
                  double sl = NormalizeDouble(Bid - initSL, Digits);
                  int tkt = SafeOrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, 0, "M7_RISE_BUY", MagicNumber, clrGreen);
                  if(tkt > 0)
                    {
                     s_lastRisingMilestoneDist = curDistAbove;
                     s_lastTwoWayRiseOrderTime = TimeCurrent();
                     PrintFormat(">>> [TWO-WAY ENGINE] Opened Rising BUY #%d (Order #%d/%d) at %.2f | Dist to EMA=$%.2f (Milestone Step=$%.2f)",
                                 tkt, risingCount + 1, maxOrders, Ask, curDistAbove, stepDist);
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckTwoWayReboundEntries: Climax Horizontal Line Rebound Entry  |
//+------------------------------------------------------------------+
void CheckTwoWayReboundEntries()
  {
   if(!InpEnableTwoWayEngine)
      return;

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma <= 0.0)
      return;

   double mult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double lots = NormalizeLots(InpTwoWayReboundLotBase * mult);
   if(lots <= 0.0)
      lots = 0.01;

   // CASE 1: GREEN LINE EQL-G (Bottom Rebound BUY)
   if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0)
     {
      datetime curEqlStart = g_lastEqLowLineStart;
      double distBelowEma = liveEma - Ask;

      // Purge pending SELL stops once per new green line
      if(s_lastTwoWayPurgedEqlStart != curEqlStart)
        {
         s_lastTwoWayPurgedEqlStart = curEqlStart;
         PurgeTwoWayPendingStopsOnHLine(-1);
        }

      double minClimax = GetTwoWayClimaxMinDistance();

      // Check distance qualification (minimum $1000 per user rule)
      if(distBelowEma >= minClimax)
        {
         if(s_lastTwoWayHandledEqlStart != curEqlStart)
           {
            RefreshRates();
            double sl = NormalizeDouble(g_lastEqLowPrice - InpTwoWaySLOffsetBeyondLine, Digits);
            double tp = (InpTwoWayCloseAtEmaTouch) ? 0.0 : NormalizeDouble(liveEma, Digits);

            int tkt = SafeOrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, "M7_EQL_REBOUND", MagicNumber, clrAqua);
            if(tkt > 0)
              {
               s_lastTwoWayHandledEqlStart = curEqlStart;
               PrintFormat(">>> [TWO-WAY ENGINE] Climax Floor Rebound BUY #%d opened at %.2f | GreenLine=%.2f | SL=%.2f (Cushion=$%.1f) | DistToEMA=$%.2f",
                           tkt, Ask, g_lastEqLowPrice, sl, InpTwoWaySLOffsetBeyondLine, distBelowEma);
              }
           }
        }
     }

   // CASE 2: RED LINE EQH-R (Top Rebound SELL)
   if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0)
     {
      datetime curEqhStart = g_lastEqHighLineStart;
      double distAboveEma = Bid - liveEma;

      // Purge pending BUY stops once per new red line
      if(s_lastTwoWayPurgedEqhStart != curEqhStart)
        {
         s_lastTwoWayPurgedEqhStart = curEqhStart;
         PurgeTwoWayPendingStopsOnHLine(1);
        }

      double minClimax = GetTwoWayClimaxMinDistance();

      // Check distance qualification (minimum $1000 per user rule)
      if(distAboveEma >= minClimax)
        {
         if(s_lastTwoWayHandledEqhStart != curEqhStart)
           {
            RefreshRates();
            double sl = NormalizeDouble(g_lastEqHighPrice + InpTwoWaySLOffsetBeyondLine, Digits);
            double tp = (InpTwoWayCloseAtEmaTouch) ? 0.0 : NormalizeDouble(liveEma, Digits);

            int tkt = SafeOrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, "M7_EQH_REBOUND", MagicNumber, clrMagenta);
            if(tkt > 0)
              {
               s_lastTwoWayHandledEqhStart = curEqhStart;
               PrintFormat(">>> [TWO-WAY ENGINE] Climax Ceiling Rebound SELL #%d opened at %.2f | RedLine=%.2f | SL=%.2f (Cushion=$%.1f) | DistToEMA=$%.2f",
                           tkt, Bid, g_lastEqHighPrice, sl, InpTwoWaySLOffsetBeyondLine, distAboveEma);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| ManageTwoWayReboundAndWaterfallOrders: Profit Trailing & Exit    |
//+------------------------------------------------------------------+
void ManageTwoWayReboundAndWaterfallOrders()
  {
   if(!InpEnableTwoWayEngine)
      return;

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;

   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string comm = OrderComment();
      int tkt = OrderTicket();
      int type = OrderType();
      double openPrice = OrderOpenPrice();
      double curSL = OrderStopLoss();

      // 1. REBOUND BUY ORDER (M7_EQL_REBOUND)
      if(type == OP_BUY && StringFind(comm, "M7_EQL_REBOUND") == 0)
        {
         // EMA Touch Take-Profit Exit
         if(InpTwoWayCloseAtEmaTouch && liveEma > 0.0 && Bid >= liveEma)
           {
            PrintFormat(">>> [TWO-WAY ENGINE PROFIT] Rebound BUY #%d reached yellow 200 EMA (Bid=%.2f >= EMA=%.2f). Closing with FULL PROFIT! P/L=$%.2f",
                        tkt, Bid, liveEma, OrderProfit());
            SafeOrderCloseMarket(tkt, OrderLots(), Slippage, clrGold);
            continue;
           }

         double profitPts = Bid - openPrice;
         // Breakeven Lock
         if(profitPts >= InpTwoWayBreakevenTriggerGap)
           {
            double targetSL = NormalizeDouble(openPrice + 10.0, Digits);
            if(targetSL > curSL && targetSL < (Bid - minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrAqua);
               curSL = targetSL;
              }
           }

         // Step-Trailing Ratchet ($100 steps)
         if(profitPts >= (InpTwoWayBreakevenTriggerGap + InpTwoWayTrailStepUSD))
           {
            double targetSL = NormalizeDouble(Bid - InpTwoWayTrailStepUSD, Digits);
            if(targetSL > curSL && targetSL < (Bid - minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrAqua);
              }
           }
        }

      // 2. REBOUND SELL ORDER (M7_EQH_REBOUND)
      if(type == OP_SELL && StringFind(comm, "M7_EQH_REBOUND") == 0)
        {
         // EMA Touch Take-Profit Exit
         if(InpTwoWayCloseAtEmaTouch && liveEma > 0.0 && Ask <= liveEma)
           {
            PrintFormat(">>> [TWO-WAY ENGINE PROFIT] Rebound SELL #%d reached yellow 200 EMA (Ask=%.2f <= EMA=%.2f). Closing with FULL PROFIT! P/L=$%.2f",
                        tkt, Ask, liveEma, OrderProfit());
            SafeOrderCloseMarket(tkt, OrderLots(), Slippage, clrGold);
            continue;
           }

         double profitPts = openPrice - Ask;
         // Breakeven Lock
         if(profitPts >= InpTwoWayBreakevenTriggerGap)
           {
            double targetSL = NormalizeDouble(openPrice - 10.0, Digits);
            if((curSL == 0.0 || targetSL < curSL) && targetSL > (Ask + minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrMagenta);
               curSL = targetSL;
              }
           }

         // Step-Trailing Ratchet ($100 steps)
         if(profitPts >= (InpTwoWayBreakevenTriggerGap + InpTwoWayTrailStepUSD))
           {
            double targetSL = NormalizeDouble(Ask + InpTwoWayTrailStepUSD, Digits);
            if((curSL == 0.0 || targetSL < curSL) && targetSL > (Ask + minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrMagenta);
              }
           }
        }

      // 3. FALLING WATERFALL SELL ORDER (M7_FALL_SELL)
      if(type == OP_SELL && StringFind(comm, "M7_FALL_SELL") == 0)
        {
         double profitPts = openPrice - Ask;
         double trailDist = (InpTwoWayWaterfallTrailDist > 0.0) ? InpTwoWayWaterfallTrailDist : 100.0;

         // Tier 1: Breakeven Lock (+10 pts locked once profit >= trailDist)
         if(profitPts >= trailDist)
           {
            double targetSL = NormalizeDouble(openPrice - 10.0, Digits);
            if((curSL == 0.0 || targetSL < curSL) && targetSL > (Ask + minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrOrangeRed);
               curSL = targetSL;
              }
           }
         // Tier 2: Dynamic Trailing Ratchet behind price (once profit >= trailDist * 1.5)
         if(profitPts >= (trailDist * 1.5))
           {
            double targetSL = NormalizeDouble(Ask + trailDist, Digits);
            if((curSL == 0.0 || (curSL - targetSL) >= 10.0) && targetSL > (Ask + minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrOrangeRed);
              }
           }
        }

      // 4. RISING SURGE BUY ORDER (M7_RISE_BUY)
      if(type == OP_BUY && StringFind(comm, "M7_RISE_BUY") == 0)
        {
         double profitPts = Bid - openPrice;
         double trailDist = (InpTwoWayWaterfallTrailDist > 0.0) ? InpTwoWayWaterfallTrailDist : 100.0;

         // Tier 1: Breakeven Lock (+10 pts locked once profit >= trailDist)
         if(profitPts >= trailDist)
           {
            double targetSL = NormalizeDouble(openPrice + 10.0, Digits);
            if((curSL == 0.0 || targetSL > curSL) && targetSL < (Bid - minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrLime);
               curSL = targetSL;
              }
           }
         // Tier 2: Dynamic Trailing Ratchet behind price (once profit >= trailDist * 1.5)
         if(profitPts >= (trailDist * 1.5))
           {
            double targetSL = NormalizeDouble(Bid - trailDist, Digits);
            if((curSL == 0.0 || (targetSL - curSL) >= 10.0) && targetSL < (Bid - minStopDist))
              {
               SafeOrderModify(tkt, openPrice, targetSL, OrderTakeProfit(), 0, clrLime);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
