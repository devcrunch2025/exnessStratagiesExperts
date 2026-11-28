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
static double   s_m7PrevEntrySpeedSell      = 0.0;
static double   s_m7PrevEntrySpeedBuy       = 0.0;
static int      s_m7PrevLotTierSell         = 0;
static int      s_m7PrevLotTierBuy          = 0;

//+------------------------------------------------------------------+
//| ResetTwoWayWaterfallState: Reset Waterfall distance & momentum   |
//+------------------------------------------------------------------+
void ResetTwoWayWaterfallState(int dir = 0)
  {
   if(dir <= 0)
     {
      s_lastFallingMilestoneDist = 0.0;
      s_m7PrevEntrySpeedSell     = 0.0;
      s_m7PrevLotTierSell        = 0;
     }
   if(dir >= 0)
     {
      s_lastRisingMilestoneDist  = 0.0;
      s_m7PrevEntrySpeedBuy      = 0.0;
      s_m7PrevLotTierBuy         = 0;
     }
  }

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
//| GetLatestOpenM7WaterfallPL: Latest open M7_FALL/M7_RISE order PL |
//+------------------------------------------------------------------+
double GetLatestOpenM7WaterfallPL(int ordType, string commentPrefix, bool &outHasOpen)
  {
   outHasOpen = false;
   datetime latestTime = 0;
   int latestTicket = 0;
   double latestPL = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != ordType || StringFind(OrderComment(), commentPrefix) != 0)
         continue;

      datetime ot = OrderOpenTime();
      int tkt = OrderTicket();
      if(!outHasOpen || ot > latestTime || (ot == latestTime && tkt > latestTicket))
        {
         outHasOpen   = true;
         latestTime   = ot;
         latestTicket = tkt;
         latestPL     = OrderProfit() + OrderSwap() + OrderCommission();
        }
     }
   return latestPL;
  }

//+------------------------------------------------------------------+
//| RecordTwoWayWaterfallEntry: Store momentum baseline on open      |
//+------------------------------------------------------------------+
void RecordTwoWayWaterfallEntry(int dir, double speed, int tier)
  {
   if(dir < 0)
     {
      s_m7PrevEntrySpeedSell = speed;
      s_m7PrevLotTierSell    = tier;
     }
   else
     {
      s_m7PrevEntrySpeedBuy  = speed;
      s_m7PrevLotTierBuy     = tier;
     }
  }

//+------------------------------------------------------------------+
//| CalculateTwoWayWaterfallLot:                                     |
//| Scales M7_FALL_SELL / M7_RISE_BUY lots dynamically with 5m EMA   |
//| momentum (0.01 -> 0.02 -> 0.03 -> 0.04 x mult) and steps down or |
//| resets to base when momentum slows, EMA weakens, or prior loses. |
//+------------------------------------------------------------------+
double CalculateTwoWayWaterfallLot(int dir, double &outSpeed, int &outTier, string &outReason)
  {
   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   double baseLot  = (InpTwoWayWaterfallLotBase  > 0.0) ? InpTwoWayWaterfallLotBase  : 0.01;
   double tier2Lot = (InpTwoWayWaterfallLotTier2 > 0.0) ? InpTwoWayWaterfallLotTier2 : 0.02;
   double tier3Lot = (InpTwoWayWaterfallLotTier3 > 0.0) ? InpTwoWayWaterfallLotTier3 : 0.03;
   double tier4Lot = (InpTwoWayWaterfallLotTier4 > 0.0) ? InpTwoWayWaterfallLotTier4 : 0.04;

   double schedule[4];
   schedule[0] = baseLot;
   schedule[1] = tier2Lot;
   schedule[2] = tier3Lot;
   schedule[3] = tier4Lot;

   bool spkBull = false, spkBear = false;
   double dAbove = 0.0, dBelow = 0.0, deltaAbove = 0.0, deltaBelow = 0.0;
   Evaluate5MinEmaDistanceStepGap(spkBull, spkBear, dAbove, dBelow, deltaAbove, deltaBelow);
   double curSpeed = (dir > 0) ? deltaAbove : deltaBelow;
   outSpeed = curSpeed;

   if(!InpTwoWayEnableMomentumLots)
     {
      outTier   = 0;
      outReason = "FlatBase";
      double flatLot = NormalizeLots(baseLot * mult);
      return (flatLot > 0.0) ? flatLot : 0.01;
     }

   int ordType    = (dir > 0) ? OP_BUY : OP_SELL;
   string cmtPfx  = (dir > 0) ? "M7_RISE" : "M7_FALL";
   double prevSpd = (dir > 0) ? s_m7PrevEntrySpeedBuy : s_m7PrevEntrySpeedSell;
   int    prevTr  = (dir > 0) ? s_m7PrevLotTierBuy    : s_m7PrevLotTierSell;

   double reqT2 = (InpTwoWayMomentumSpeedT2 > 0.0) ? InpTwoWayMomentumSpeedT2 : 200.0;
   double reqT3 = (InpTwoWayMomentumSpeedT3 > 0.0) ? InpTwoWayMomentumSpeedT3 : 350.0;
   double reqT4 = (InpTwoWayMomentumSpeedT4 > 0.0) ? InpTwoWayMomentumSpeedT4 : 500.0;
   double redRatio = (InpTwoWayMomentumReduceRatio > 0.0 && InpTwoWayMomentumReduceRatio < 1.0) ? InpTwoWayMomentumReduceRatio : 0.85;

   int speedTier = 0;
   if(curSpeed >= reqT4)
      speedTier = 3;
   else if(curSpeed >= reqT3)
      speedTier = 2;
   else if(curSpeed >= reqT2)
      speedTier = 1;

   int finalTier = 0;
   bool hasPrevOpen = false;
   double prevOpenPL = GetLatestOpenM7WaterfallPL(ordType, cmtPfx, hasPrevOpen);

   if(IsEmaWEAKDistanceReduced50PercentFromPeak(ordType) || EMADirection != dir)
     {
      finalTier = 0;
      outReason = StringFormat("EMA %s/Counter -> Base %.2f",
                               (IsEmaWEAKDistanceReduced50PercentFromPeak(ordType) ? "WEAK" : "STRONG"), baseLot);
     }
   else if(hasPrevOpen && prevOpenPL < 0.0)
     {
      finalTier = 0;
      outReason = StringFormat("PrevM7Loss ($%.2f) -> Base %.2f", prevOpenPL, baseLot);
     }
   else if(speedTier == 0)
     {
      finalTier = 0;
      outReason = StringFormat("LowMom ($%.0f<$%.0f) -> Base %.2f", curSpeed, reqT2, baseLot);
     }
   else if(prevSpd <= 0.0)
     {
      // Initial entry in leg: allow Tier 2 (0.02) on immediate >=T3 burst, else start at Tier 1 (0.01)
      finalTier = (speedTier >= 2) ? 1 : 0;
      outReason = StringFormat("StartMom ($%.0f) -> T%d %.2f", curSpeed, finalTier + 1, schedule[finalTier]);
     }
   else if(curSpeed < (prevSpd * redRatio))
     {
      // Momentum slowed significantly compared to previous Waterfall entry -> reduce lot tier
      finalTier = MathMin(speedTier, MathMax(0, prevTr - 1));
      outReason = StringFormat("MomReduced ($%.0f<$%.0f*%.2f) -> T%d %.2f", curSpeed, prevSpd, redRatio, finalTier + 1, schedule[finalTier]);
     }
   else
     {
      // Momentum accelerating or sustained -> step up (+1 tier normally, or direct jump if >=1.25x faster)
      if(curSpeed >= (prevSpd * 1.25))
         finalTier = speedTier;
      else
         finalTier = MathMin(speedTier, prevTr + 1);
      outReason = StringFormat("Mom%s ($%.0f vs Prev $%.0f) -> T%d %.2f",
                               (finalTier > prevTr ? "Up" : "Hold"), curSpeed, prevSpd, finalTier + 1, schedule[finalTier]);
     }

   outTier = finalTier;
   double resLots = NormalizeLots(schedule[finalTier] * mult);
   if(resLots <= 0.0)
      resLots = 0.01;
   return resLots;
  }

//+------------------------------------------------------------------+
//| ProcessTwoWayWaterfallDirection: Shared Falling SELL / Rising BUY|
//+------------------------------------------------------------------+
void ProcessTwoWayWaterfallDirection(int dir, double liveEma, double startDist, double stepDist, int maxOrders, double initSL)
  {
   bool isBuy = (dir > 0);
   double priceCheck = isBuy ? Ask : Bid;

   // Reset milestone & momentum state when price returns within $50 of 200 EMA
   if((isBuy && priceCheck <= (liveEma + 50.0)) || (!isBuy && priceCheck >= (liveEma - 50.0)))
     {
      ResetTwoWayWaterfallState(dir);
      return;
     }

   bool beyondStart = isBuy ? (priceCheck > (liveEma + startDist)) : (priceCheck < (liveEma - startDist));
   if(!beyondStart)
      return;

   double curDist = isBuy ? (Ask - liveEma) : (liveEma - Bid);
   if(IsTwoWayFreezeTrendActive(dir))
      return;

   double lastMilestone = isBuy ? s_lastRisingMilestoneDist : s_lastFallingMilestoneDist;
   if(lastMilestone > 0.0 && curDist < (lastMilestone + stepDist))
      return;

   int ordType      = isBuy ? OP_BUY : OP_SELL;
   string prefix    = isBuy ? "M7_RISE" : "M7_FALL";
   string comment   = isBuy ? "M7_RISE_BUY" : "M7_FALL_SELL";
   string dirLabel  = isBuy ? "Rising BUY" : "Falling SELL";
   bool spikeLocked = isBuy ? g_blockBuySpikeUntilNewSpike : g_blockSellSpikeUntilNewSpike;
   datetime lastT   = isBuy ? s_lastTwoWayRiseOrderTime : s_lastTwoWayFallOrderTime;

   if(spikeLocked || (TimeCurrent() - lastT < 5))
      return;

   int activeCount = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == ordType && StringFind(OrderComment(), prefix) == 0)
         activeCount++;
     }
   if(activeCount >= maxOrders)
      return;

   double curSpeed = 0.0;
   int chosenTier = 0;
   string lotReason = "";
   double lots = CalculateTwoWayWaterfallLot(dir, curSpeed, chosenTier, lotReason);

   RefreshRates();
   double entryPx = isBuy ? Ask : Bid;
   double sl = NormalizeDouble((isBuy ? (Bid - initSL) : (Ask + initSL)), Digits);
   int tkt = SafeOrderSend(Symbol(), ordType, lots, entryPx, Slippage, sl, 0, comment, MagicNumber, (isBuy ? clrGreen : clrRed));
   if(tkt > 0)
     {
      if(isBuy)
        {
         s_lastRisingMilestoneDist = curDist;
         s_lastTwoWayRiseOrderTime = TimeCurrent();
        }
      else
        {
         s_lastFallingMilestoneDist = curDist;
         s_lastTwoWayFallOrderTime = TimeCurrent();
        }
      RecordTwoWayWaterfallEntry(dir, curSpeed, chosenTier);
      PrintFormat(">>> [TWO-WAY ENGINE] Opened %s #%d (Order #%d/%d, Lots=%.2f | %s) at %.2f | Dist to EMA=$%.2f (Step=$%.2f)",
                  dirLabel, tkt, activeCount + 1, maxOrders, lots, lotReason, entryPx, curDist, stepDist);
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

   int maxOrders    = (InpTwoWayMaxWaterfallOrders > 0) ? InpTwoWayMaxWaterfallOrders : 6;
   double startDist = (InpTwoWayWaterfallStartDist > 0.0) ? InpTwoWayWaterfallStartDist : 150.0;
   double stepDist  = (InpTwoWayWaterfallStepRaw   > 0.0) ? InpTwoWayWaterfallStepRaw   : 150.0;
   double initSL    = (InpTwoWayWaterfallInitialSL > 0.0) ? InpTwoWayWaterfallInitialSL : 250.0;

   if(InpTwoWayEnableFallingOrders)
      ProcessTwoWayWaterfallDirection(-1, liveEma, startDist, stepDist, maxOrders, initSL);

   if(InpTwoWayEnableRisingOrders)
      ProcessTwoWayWaterfallDirection(1, liveEma, startDist, stepDist, maxOrders, initSL);
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
         static datetime s_lastSpikeEndEqlSignal = 0;
         if(s_lastSpikeEndEqlSignal != curEqlStart)
           {
            s_lastSpikeEndEqlSignal = curEqlStart;
            DrawSpikeLifecycleSignal("SPIKE_END", -1, g_lastEqLowPrice, StringFormat("EQL-G Climax Floor Speed Breaker at %.2f (Dist=$%.2f)", g_lastEqLowPrice, distBelowEma));
           }

         if(s_lastTwoWayHandledEqlStart != curEqlStart)
           {
            RefreshRates();
            double sl = NormalizeDouble(g_lastEqLowPrice - InpTwoWaySLOffsetBeyondLine, Digits);
            double tp = (InpTwoWayCloseAtEmaTouch) ? 0.0 : NormalizeDouble(liveEma, Digits);

            int tkt = SafeOrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, sl, tp, "M7_EQL_REBOUND", MagicNumber, clrAqua);
            if(tkt > 0)
              {
               s_lastTwoWayHandledEqlStart = curEqlStart;
               DrawSpikeLifecycleSignal("SPIKE_REV_START", 1, Ask, StringFormat("Climax Floor Rebound BUY #%d (Target: 200 EMA)", tkt));
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
         static datetime s_lastSpikeEndEqhSignal = 0;
         if(s_lastSpikeEndEqhSignal != curEqhStart)
           {
            s_lastSpikeEndEqhSignal = curEqhStart;
            DrawSpikeLifecycleSignal("SPIKE_END", 1, g_lastEqHighPrice, StringFormat("EQH-R Climax Ceiling Speed Breaker at %.2f (Dist=$%.2f)", g_lastEqHighPrice, distAboveEma));
           }

         if(s_lastTwoWayHandledEqhStart != curEqhStart)
           {
            RefreshRates();
            double sl = NormalizeDouble(g_lastEqHighPrice + InpTwoWaySLOffsetBeyondLine, Digits);
            double tp = (InpTwoWayCloseAtEmaTouch) ? 0.0 : NormalizeDouble(liveEma, Digits);

            int tkt = SafeOrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, sl, tp, "M7_EQH_REBOUND", MagicNumber, clrMagenta);
            if(tkt > 0)
              {
               s_lastTwoWayHandledEqhStart = curEqhStart;
               DrawSpikeLifecycleSignal("SPIKE_REV_START", -1, Bid, StringFormat("Climax Ceiling Rebound SELL #%d (Target: 200 EMA)", tkt));
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
            DrawSpikeLifecycleSignal("SPIKE_REV_END", 1, liveEma, StringFormat("Rebound BUY #%d reached yellow 200 EMA (Bid=%.2f >= EMA=%.2f) | P/L=$%.2f", tkt, Bid, liveEma, OrderProfit()));
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
            DrawSpikeLifecycleSignal("SPIKE_REV_END", -1, liveEma, StringFormat("Rebound SELL #%d reached yellow 200 EMA (Ask=%.2f <= EMA=%.2f) | P/L=$%.2f", tkt, Ask, liveEma, OrderProfit()));
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
