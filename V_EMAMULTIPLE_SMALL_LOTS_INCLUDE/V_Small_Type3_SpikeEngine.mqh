//+------------------------------------------------------------------+
//|                                     V_Small_Type3_SpikeEngine.mqh|
//|                 TYPE 3: Spike & Climax Reversal Engine           |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Pure 5-Min EMA Distance Velocity (NO EMAangle condition!)     |
//| 2. Checks EVERY 5-min step gap for Start, Continuation & End     |
//| 3. Priority State: FREEZES / HOLDS Type 1 and Type 2 methods     |
//| 4. Auto-Resumes Trading immediately when Spike is detected       |
//| 5. Cuts opposite loss orders immediately to stop drawdown bleed  |
//| 6. Dedicated Spike Profit Booking ($50.00 minimum target)        |
//| 7. Speed Breakers: Horizontal lines (EQL-G / EQH-R) at climax    |
//|    or 5-min step deceleration signal SPIKE END & trigger Rebound |
//| 8. Rebound rides mean reversion back to yellow 200 EMA touch!    |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Type 3 Telemetry Metrics
int      g_type3ClosedTrades      = 0;
double   g_type3ClosedProfit      = 0.0;
int      g_type3WinCount          = 0;
int      g_type3LossCount         = 0;
bool     g_type3SpikeActiveState  = false;
datetime g_lastType3LogTime       = 0;

// Spike Lifecycle Visualizer State Tracker (Strict 1:1 Deduplication)
// States: 0 = STAGE_IDLE, 1 = STAGE_SPIKE_STARTED, 2 = STAGE_SPIKE_ENDED, 3 = STAGE_REVERSE_STARTED
int      s_spikeLifecycleState    = 0;
int      s_lastSpikeSignalDir     = 0;
datetime s_lastSpikeSignalTime    = 0;
datetime s_lastSpikeEndTime       = 0;

// 5-Minute Step Gap Trackers (Evaluated on every 5-min boundary & rolling M1 window)
long     g_spike5mLastStepSlot         = -1;
double   g_spike5mStepStartDistAbove   = 0.0;
double   g_spike5mStepStartDistBelow   = 0.0;
double   g_spike5mPrevStepGapAbove     = 0.0;
double   g_spike5mPrevStepGapBelow     = 0.0;
double   g_spike5mLiveStepGapAbove     = 0.0;
double   g_spike5mLiveStepGapBelow     = 0.0;
datetime g_spike5mLastConfirmTime      = 0;
int      g_spike5mLastConfirmDir       = 0;

// Per-Tick Evaluation Cache (Zero repeated iMA calls when checked multiple times in same tick)
datetime g_spike5mCacheTickTime        = 0;
double   g_spike5mCacheBid             = 0.0;
double   g_spike5mCacheAsk             = 0.0;
bool     g_spike5mCacheBullSpike       = false;
bool     g_spike5mCacheBearSpike       = false;
double   g_spike5mCacheDistAbove       = 0.0;
double   g_spike5mCacheDistBelow       = 0.0;
double   g_spike5mCacheDeltaAbove      = 0.0;
double   g_spike5mCacheDeltaBelow      = 0.0;

//+------------------------------------------------------------------+
//| ResetSpikeLifecycleState: Reset chart signal & 5m step state     |
//+------------------------------------------------------------------+
void ResetSpikeLifecycleState()
  {
   s_spikeLifecycleState        = 0;
   s_lastSpikeSignalDir         = 0;
   s_lastSpikeSignalTime        = 0;
   s_lastSpikeEndTime           = 0;
   g_blockSellSpikeUntilNewSpike  = false;
   g_sellSpikeBlockedSinceEndTime = 0;

   g_spike5mLastStepSlot       = -1;
   g_spike5mStepStartDistAbove = 0.0;
   g_spike5mStepStartDistBelow = 0.0;
   g_spike5mPrevStepGapAbove   = 0.0;
   g_spike5mPrevStepGapBelow   = 0.0;
   g_spike5mLiveStepGapAbove   = 0.0;
   g_spike5mLiveStepGapBelow   = 0.0;
   g_spike5mLastConfirmTime    = 0;
   g_spike5mLastConfirmDir     = 0;

   g_spike5mCacheTickTime      = 0;
   g_spike5mCacheBid           = 0.0;
   g_spike5mCacheAsk           = 0.0;
   g_spike5mCacheBullSpike     = false;
   g_spike5mCacheBearSpike     = false;
   g_spike5mCacheDistAbove     = 0.0;
   g_spike5mCacheDistBelow     = 0.0;
   g_spike5mCacheDeltaAbove    = 0.0;
   g_spike5mCacheDeltaBelow    = 0.0;
  }

//+------------------------------------------------------------------+
//| Evaluate5MinEmaDistanceStepGap:                                  |
//| Evaluates BOTH:                                                  |
//| 1. Rolling 5-min M1 window (side-aware EMA distance expansion)   |
//| 2. Discrete every-5-minute step boundaries (00, 05, 10, 15...)   |
//|    to confirm Spike Start, Continuation, and 5-Min Step END!     |
//+------------------------------------------------------------------+
void Evaluate5MinEmaDistanceStepGap(bool &outBullSpike, bool &outBearSpike,
                                    double &outCurDistAbove, double &outCurDistBelow,
                                    double &outDeltaAbove, double &outDeltaBelow)
  {
   datetime nowServer = TimeCurrent();

   if(nowServer > 0 && nowServer == g_spike5mCacheTickTime &&
      Bid == g_spike5mCacheBid && Ask == g_spike5mCacheAsk &&
      g_spike5mLastStepSlot >= 0)
     {
      outBullSpike    = g_spike5mCacheBullSpike;
      outBearSpike    = g_spike5mCacheBearSpike;
      outCurDistAbove = g_spike5mCacheDistAbove;
      outCurDistBelow = g_spike5mCacheDistBelow;
      outDeltaAbove   = g_spike5mCacheDeltaAbove;
      outDeltaBelow   = g_spike5mCacheDeltaBelow;
      return;
     }

   outBullSpike    = false;
   outBearSpike    = false;
   outCurDistAbove = 0.0;
   outCurDistBelow = 0.0;
   outDeltaAbove   = 0.0;
   outDeltaBelow   = 0.0;

   double liveEma200 = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma200 <= 0.0 || nowServer <= 0)
      return;

   double curDistBelow = (Bid < liveEma200) ? (liveEma200 - Bid) : 0.0;
   double curDistAbove = (Ask > liveEma200) ? (Ask - liveEma200) : 0.0;
   outCurDistAbove = curDistAbove;
   outCurDistBelow = curDistBelow;

   int lookbackMins    = MathMax(1, InpType3SpikeVelocityLookbackM1);
   int stepIntervalSec = lookbackMins * 60; // Default: 300s (5 minutes)

   // 1. Scan past 1..5 minute M1 bars to measure exact rolling 5-min distance expansion
   double minPastDistBelow5m = curDistBelow;
   double minPastDistAbove5m = curDistAbove;
   int m1BarsTotal = iBars(Symbol(), PERIOD_M1);
   if(m1BarsTotal > lookbackMins)
     {
      bool firstSample = true;
      for(int m = 1; m <= lookbackMins; m++)
        {
         datetime barT = iTime(Symbol(), PERIOD_M1, m);
         // Do not reuse pre-SPIKE_END candles as rolling baseline once a spike has ended
         if(s_lastSpikeEndTime > 0 && (s_spikeLifecycleState >= 2 || g_blockSellSpikeUntilNewSpike) && barT < s_lastSpikeEndTime)
            continue;
         double   pM1  = iClose(Symbol(), PERIOD_M1, m);
         int emaShift  = (Period() == PERIOD_M1) ? m : iBarShift(Symbol(), Period(), barT, false);
         if(emaShift < 0)
            emaShift = 0;
         double emaAtM = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, emaShift);
         if(emaAtM <= 0.0 || pM1 <= 0.0)
            continue;

         double dBelow = (pM1 < emaAtM) ? (emaAtM - pM1) : 0.0;
         double dAbove = (pM1 > emaAtM) ? (pM1 - emaAtM) : 0.0;

         if(firstSample)
           {
            minPastDistBelow5m = dBelow;
            minPastDistAbove5m = dAbove;
            firstSample = false;
           }
         else
           {
            if(dBelow < minPastDistBelow5m) minPastDistBelow5m = dBelow;
            if(dAbove < minPastDistAbove5m) minPastDistAbove5m = dAbove;
           }
        }
     }

   double rollingDeltaBelow = (curDistBelow > 0.0) ? (curDistBelow - minPastDistBelow5m) : 0.0;
   double rollingDeltaAbove = (curDistAbove > 0.0) ? (curDistAbove - minPastDistAbove5m) : 0.0;

   // 2. Check EVERY 5-Minute Step Gap Boundary (00, 05, 10, 15, ...)
   long curSlot = (long)(((long)nowServer) / stepIntervalSec);
   bool boundaryJustCrossed   = false;
   bool boundaryConfirmedBull = false;
   bool boundaryConfirmedBear = false;

   if(g_spike5mLastStepSlot == -1)
     {
      g_spike5mLastStepSlot       = curSlot;
      g_spike5mStepStartDistAbove = curDistAbove;
      g_spike5mStepStartDistBelow = curDistBelow;
     }
   else if(curSlot != g_spike5mLastStepSlot)
     {
      boundaryJustCrossed = true;
      double completedGapAbove = (curDistAbove > 0.0) ? (curDistAbove - g_spike5mStepStartDistAbove) : -g_spike5mStepStartDistAbove;
      double completedGapBelow = (curDistBelow > 0.0) ? (curDistBelow - g_spike5mStepStartDistBelow) : -g_spike5mStepStartDistBelow;

      g_spike5mPrevStepGapAbove = completedGapAbove;
      g_spike5mPrevStepGapBelow = completedGapBelow;

      double reqThreshold = InpType3Spike5MinDistanceChange;
      string stepStatus   = "NORMAL";

      if(curDistBelow > 0.0 && completedGapBelow >= reqThreshold)
        {
         boundaryConfirmedBear = true;
         g_spike5mLastConfirmTime = nowServer;
         g_spike5mLastConfirmDir  = -1;
         stepStatus = StringFormat("BEAR SPIKE STEP (+$%.2f >= $%.0f)", completedGapBelow, reqThreshold);
        }
      else if(curDistAbove > 0.0 && completedGapAbove >= reqThreshold)
        {
         boundaryConfirmedBull = true;
         g_spike5mLastConfirmTime = nowServer;
         g_spike5mLastConfirmDir  = 1;
         stepStatus = StringFormat("BULL SPIKE STEP (+$%.2f >= $%.0f)", completedGapAbove, reqThreshold);
        }

      // Check if an active spike slowed down/reversed over this completed 5-min step -> SPIKE END!
      if(InpType3CheckEvery5MinStepGap && s_spikeLifecycleState == 1 && (nowServer - s_lastSpikeSignalTime) >= stepIntervalSec)
        {
         if(s_lastSpikeSignalDir == -1 && completedGapBelow < InpType3Spike5MinEndMinStepGap && rollingDeltaBelow < reqThreshold)
           {
            stepStatus = StringFormat("BEAR SPIKE ENDED (5m StepGap=$%.2f < $%.0f)", completedGapBelow, InpType3Spike5MinEndMinStepGap);
            DrawSpikeLifecycleSignal("SPIKE_END", -1, Bid, stepStatus);
           }
         else if(s_lastSpikeSignalDir == 1 && completedGapAbove < InpType3Spike5MinEndMinStepGap && rollingDeltaAbove < reqThreshold)
           {
            stepStatus = StringFormat("BULL SPIKE ENDED (5m StepGap=$%.2f < $%.0f)", completedGapAbove, InpType3Spike5MinEndMinStepGap);
            DrawSpikeLifecycleSignal("SPIKE_END", 1, Ask, stepStatus);
           }
        }

      if(InpType3CheckEvery5MinStepGap)
        {
         PrintFormat(">>> [5-MIN STEP GAP] Time=%s | Dist(A/B)=$%.2f/$%.2f | PrevStart(A/B)=$%.2f/$%.2f | StepGap(A/B)=$%.2f/$%.2f | %s",
                     TimeToString(nowServer, TIME_DATE|TIME_MINUTES),
                     curDistAbove, curDistBelow,
                     g_spike5mStepStartDistAbove, g_spike5mStepStartDistBelow,
                     completedGapAbove, completedGapBelow,
                     stepStatus);
        }

      g_spike5mLastStepSlot       = curSlot;
      g_spike5mStepStartDistAbove = curDistAbove;
      g_spike5mStepStartDistBelow = curDistBelow;
     }

   g_spike5mLiveStepGapAbove = (curDistAbove > 0.0) ? (curDistAbove - g_spike5mStepStartDistAbove) : 0.0;
   g_spike5mLiveStepGapBelow = (curDistBelow > 0.0) ? (curDistBelow - g_spike5mStepStartDistBelow) : 0.0;

   double bestDeltaAbove = MathMax(rollingDeltaAbove, g_spike5mLiveStepGapAbove);
   double bestDeltaBelow = MathMax(rollingDeltaBelow, g_spike5mLiveStepGapBelow);
   if(boundaryJustCrossed)
     {
      bestDeltaAbove = MathMax(bestDeltaAbove, g_spike5mPrevStepGapAbove);
      bestDeltaBelow = MathMax(bestDeltaBelow, g_spike5mPrevStepGapBelow);
     }

   outDeltaAbove = bestDeltaAbove;
   outDeltaBelow = bestDeltaBelow;

   if(InpEnableType3SpikeVelocityFilter || InpEnableFastMovingEmaSpike)
     {
      double climaxDist = GetTwoWayClimaxMinDistance();
      // Static climax distance only spawns spike orders before SPIKE_END; once ended, require a fresh 5m velocity shock
      bool allowStaticClimax = (s_spikeLifecycleState <= 1 && !g_blockSellSpikeUntilNewSpike);
      if(InpType3SpikeStrict5MinBoundaryOnly)
        {
         if(curDistAbove > 0.0 && (boundaryConfirmedBull || (allowStaticClimax && curDistAbove >= climaxDist)))
            outBullSpike = true;
         if(curDistBelow > 0.0 && (boundaryConfirmedBear || (allowStaticClimax && curDistBelow >= climaxDist)))
            outBearSpike = true;
        }
      else
        {
         if(curDistAbove > 0.0 && (bestDeltaAbove >= InpType3Spike5MinDistanceChange || (allowStaticClimax && curDistAbove >= climaxDist)))
            outBullSpike = true;
         if(curDistBelow > 0.0 && (bestDeltaBelow >= InpType3Spike5MinDistanceChange || (allowStaticClimax && curDistBelow >= climaxDist)))
            outBearSpike = true;
        }
     }

   // Unlock Bullish SPIKE END SELL lock ONLY when a genuinely NEW velocity spike signal starts (>= $300/5m after SPIKE_END)
   if(g_blockSellSpikeUntilNewSpike && (nowServer - g_sellSpikeBlockedSinceEndTime) >= 60)
     {
      bool newVelocityStarted = (bestDeltaAbove >= InpType3Spike5MinDistanceChange ||
                                 bestDeltaBelow >= InpType3Spike5MinDistanceChange ||
                                 boundaryConfirmedBull || boundaryConfirmedBear);
      if(newVelocityStarted && (outBullSpike || outBearSpike))
        {
         g_blockSellSpikeUntilNewSpike  = false;
         g_sellSpikeBlockedSinceEndTime = 0;
         PrintFormat(">>> [NEW SPIKE SIGNAL STARTED] Unlocking Bullish SPIKE END SELL-spike lock! (5m Delta A=$%.2f, B=$%.2f)",
                     bestDeltaAbove, bestDeltaBelow);
        }
     }

   // Store tick cache
   g_spike5mCacheTickTime   = nowServer;
   g_spike5mCacheBid        = Bid;
   g_spike5mCacheAsk        = Ask;
   g_spike5mCacheBullSpike  = outBullSpike;
   g_spike5mCacheBearSpike  = outBearSpike;
   g_spike5mCacheDistAbove  = outCurDistAbove;
   g_spike5mCacheDistBelow  = outCurDistBelow;
   g_spike5mCacheDeltaAbove = outDeltaAbove;
   g_spike5mCacheDeltaBelow = outDeltaBelow;
  }

//+------------------------------------------------------------------+
//| IsType3SpikeActive: Check if Type 3 Spike / Climax is active     |
//+------------------------------------------------------------------+
bool IsType3SpikeActive()
  {
   bool   isBull5m = false, isBear5m = false;
   double distAbove = 0.0, distBelow = 0.0;
   double deltaAbove = 0.0, deltaBelow = 0.0;

   // Condition A & B: Run unified 5-min step gap evaluator (Climax >= $1000 OR 5-min gap >= $300)
   Evaluate5MinEmaDistanceStepGap(isBull5m, isBear5m, distAbove, distBelow, deltaAbove, deltaBelow);
   double climaxMin = GetTwoWayClimaxMinDistance();
   if(isBull5m || isBear5m || distAbove >= climaxMin || distBelow >= climaxMin)
     {
      g_type3SpikeActiveState = true;
      return true;
     }

   // Condition C: Active Open Spike or Two-Way orders exist on account
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string cmt = OrderComment();
      if(StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "M7_") == 0 || StringFind(cmt, "T3_") == 0)
        {
         g_type3SpikeActiveState = true;
         return true;
        }
     }

   // If no spike velocity and no open spike/waterfall orders remain, clean up active signal near EMA
   double maxLiveDist = MathMax(distAbove, distBelow);
   if(s_spikeLifecycleState == 1 && maxLiveDist < 50.0 && (TimeCurrent() - s_lastSpikeSignalTime) >= 60)
     {
      DrawSpikeLifecycleSignal("SPIKE_END", s_lastSpikeSignalDir, (Bid + Ask) * 0.5, "Price returned near 200 EMA");
     }

   g_type3SpikeActiveState = false;
   return false;
  }

//+------------------------------------------------------------------+
//| ProcessType3SpikeExecution: Master Execution for Type 3 Engine   |
//+------------------------------------------------------------------+
void ProcessType3SpikeExecution()
  {
   if(!IsType3SpikeActive())
      return;

   double liveEma200 = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma200 <= 0.0)
      return;

   // 1. Process Two-Way Waterfall Distance-Expansion Orders
   double distForTwoWay = MathAbs(Bid - liveEma200);
   CheckTwoWayFallingAndRisingOrders(liveEma200, distForTwoWay, EMADirection);

   // 2. Process Climax Opposite Runner Liquidation
   CheckTwoWayClimaxRunnerLiquidation(distForTwoWay, EMADirection);

   // 3. Process Climax Horizontal Line ("Speed Breaker") Rebound Entries
   CheckTwoWayReboundEntries();
  }

//+------------------------------------------------------------------+
//| ManageType3ProfitBooking: Dedicated Type 3 Profit Booking Engine |
//+------------------------------------------------------------------+
void ManageType3ProfitBooking()
  {
   // 1. Manage Two-Way Waterfall Trailing Stops & Rebound EMA-touch profit closes
   ManageTwoWayReboundAndWaterfallOrders();

   // 2. Manage Spike $50 Minimum Profit Ladder with Climax Speed-Breaker Take-Profit
   ManageSpikeProfitLadder();
  }

//+------------------------------------------------------------------+
//| RecordType3ClosedOrder: Tracks Type 3 trade outcome              |
//+------------------------------------------------------------------+
void RecordType3ClosedOrder(int ticket, double netPL)
  {
   g_type3ClosedTrades++;
   g_type3ClosedProfit += netPL;
   if(netPL >= 0.0)
      g_type3WinCount++;
   else
      g_type3LossCount++;
  }

//+------------------------------------------------------------------+
//| PrintThreeTypeTelemetrySummary: Detailed Multi-Type Diagnostics  |
//+------------------------------------------------------------------+
void PrintThreeTypeTelemetrySummary()
  {
   if(TimeCurrent() - g_lastType3LogTime < 60)
      return;
   g_lastType3LogTime = TimeCurrent();

   double t1WinRate = (g_type1ClosedTrades > 0) ? ((double)g_type1WinCount / g_type1ClosedTrades * 100.0) : 0.0;
   double t2WinRate = (g_type2ClosedTrades > 0) ? ((double)g_type2WinCount / g_type2ClosedTrades * 100.0) : 0.0;
   double t3WinRate = (g_type3ClosedTrades > 0) ? ((double)g_type3WinCount / g_type3ClosedTrades * 100.0) : 0.0;

   string activeRegime = "[TYPE 1: OSCILLATION]";
   if(IsType3SpikeActive())
      activeRegime = "[TYPE 3: SPIKE & CLIMAX]";
   else if(IsType2GradualTrendActive())
      activeRegime = "[TYPE 2: GRADUAL TREND]";

   Print(">>> ================================================================================");
   PrintFormat(">>> [3-TYPE SYSTEM TELEMETRY] ACTIVE REGIME: %s | 5m StepGap(A/B)=$%.1f/$%.1f",
               activeRegime, g_spike5mLiveStepGapAbove, g_spike5mLiveStepGapBelow);
   PrintFormat(">>> [TYPE 1: OSCILLATION ] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type1ClosedTrades, g_type1ClosedProfit, g_type1WinCount, g_type1LossCount, t1WinRate);
   PrintFormat(">>> [TYPE 2: GRADUAL TRD ] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type2ClosedTrades, g_type2ClosedProfit, g_type2WinCount, g_type2LossCount, t2WinRate);
   PrintFormat(">>> [TYPE 3: SPIKE/CLIMAX] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type3ClosedTrades, g_type3ClosedProfit, g_type3WinCount, g_type3LossCount, t3WinRate);
   Print(">>> ================================================================================");
  }

//+------------------------------------------------------------------+
//| GetThreeTypeActiveStatusDisplay: For Dashboard Visualization     |
//+------------------------------------------------------------------+
string GetThreeTypeActiveStatusDisplay()
  {
   if(IsType3SpikeActive())
      return "[TYPE 3: SPIKE ACTIVE]";
   if(IsType2GradualTrendActive())
      return "[TYPE 2: TREND ACTIVE]";
   return "[TYPE 1: RANGE OSC]";
  }

//+------------------------------------------------------------------+
//| GetThreeTypeActiveStatusColor: For Dashboard Visualization       |
//+------------------------------------------------------------------+
color GetThreeTypeActiveStatusColor()
  {
   if(IsType3SpikeActive())
      return clrOrangeRed;
   if(IsType2GradualTrendActive())
      return clrAqua;
   return clrLime;
  }

//+------------------------------------------------------------------+
//| DrawSpikeLifecycleSignal: Display Visual Icons & Labels on Chart|
//| Stages:                                                          |
//| 1. "SPIKE_START"     : SPIKE started                             |
//| 2. "SPIKE_END"       : SPIKE END                                 |
//| 3. "SPIKE_REV_START" : SPIKE reverse started                     |
//| 4. "SPIKE_REV_END"   : SPIKE REVER END                           |
//+------------------------------------------------------------------+
void DrawSpikeLifecycleSignal(string stage, int dir, double price, string details = "")
  {
   if(!InpEnableSpikeLifecycleVisuals)
      return;

   // -------------------------------------------------------------
   // 1. AUTO-RESET TO IDLE WHEN PRICE RETURNS TO 200 EMA
   // -------------------------------------------------------------
   double liveEma200 = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma200 > 0.0 && MathAbs(Bid - liveEma200) < 50.0)
     {
      bool hasOpenSpikes = false;
      for(int sp_i = 0; sp_i < OrdersTotal(); sp_i++)
        {
         if(!OrderSelect(sp_i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
         string cmt = OrderComment();
         if(StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "M7_") == 0)
           {
            hasOpenSpikes = true;
            break;
           }
        }
      if(!hasOpenSpikes && s_spikeLifecycleState != 0 && stage != "SPIKE_END" && stage != "SPIKE_REV_END")
        {
         s_spikeLifecycleState = 0;
         s_lastSpikeSignalDir  = 0;
        }
     }

   // -------------------------------------------------------------
   // 2. STRICT STATE TRANSITION FILTER (NO DUPLICATES)
   // User Rule: "[SPIKE started and SPIKE ended]. do not display like
   //             SPIKE started, SPIKE started SPIKE ended, SPIKE ended..."
   // -------------------------------------------------------------
   if(stage == "SPIKE_START")
     {
      if(s_spikeLifecycleState == 1 && s_lastSpikeSignalDir == dir)
         return;

      s_spikeLifecycleState = 1; // Mark SPIKE_ACTIVE
      s_lastSpikeSignalDir  = dir;
      s_lastSpikeSignalTime = TimeCurrent();

      if(g_blockSellSpikeUntilNewSpike && (TimeCurrent() - g_sellSpikeBlockedSinceEndTime) >= 5)
        {
         g_blockSellSpikeUntilNewSpike  = false;
         g_sellSpikeBlockedSinceEndTime = 0;
         PrintFormat(">>> [NEW SPIKE SIGNAL STARTED] Cleared SELL-spike lock on new SPIKE_START (Dir=%+d).", dir);
        }
     }
   else if(stage == "SPIKE_END")
     {
      if(s_spikeLifecycleState != 1)
         return;

      s_spikeLifecycleState = 2; // Mark SPIKE_ENDED
      s_lastSpikeSignalTime = TimeCurrent();
      s_lastSpikeEndTime    = TimeCurrent();

      // Re-anchor 5m step baseline strictly at SPIKE END so pre-end candles don't re-trigger immediately
      if(liveEma200 > 0.0)
        {
         g_spike5mStepStartDistAbove = (Ask > liveEma200) ? (Ask - liveEma200) : 0.0;
         g_spike5mStepStartDistBelow = (Bid < liveEma200) ? (liveEma200 - Bid) : 0.0;
        }
      g_spike5mPrevStepGapAbove = 0.0;
      g_spike5mPrevStepGapBelow = 0.0;
      g_spike5mCacheTickTime    = 0;

      // USER RULE: If EMADirection is BULLISH when SPIKE END is detected -> close all open SELL orders
      // and block SELL spike orders until a NEW spike signal starts!
      int curEmaDir = (liveEma200 > 0.0) ? ((Bid > liveEma200) ? 1 : ((Bid < liveEma200) ? -1 : EMADirection)) : EMADirection;
      if(InpType3CloseSellOnBullishSpikeEnd && curEmaDir == 1)
        {
         g_blockSellSpikeUntilNewSpike  = true;
         g_sellSpikeBlockedSinceEndTime = TimeCurrent();
         CloseAllOpenSellOrders("BULLISH_EMA_SPIKE_END_CLOSE_ALL_SELLS");
         Print(">>> [BULLISH EMA + SPIKE END] Closed ALL open SELL orders and locked SELL spike creation until NEW spike signal starts!");
        }
     }
   else if(stage == "SPIKE_REV_START")
     {
      if(s_spikeLifecycleState == 3)
         return;

      s_spikeLifecycleState = 3; // Mark REVERSE_ACTIVE
      s_lastSpikeSignalTime = TimeCurrent();
     }
   else if(stage == "SPIKE_REV_END")
     {
      if(s_spikeLifecycleState == 0)
         return;

      s_spikeLifecycleState = 0; // Reset to IDLE (full cycle completed!)
      s_lastSpikeSignalDir  = 0;
      s_lastSpikeSignalTime = TimeCurrent();
     }
   else
     {
      return;
     }

   static int s_spikeObjSeq = 0;
   s_spikeObjSeq++;

   datetime barTime = Time[0];
   double offset = (SignalDistancePoints > 0 ? SignalDistancePoints : 100) * Point;
   if(offset < 10.0 * Point)
      offset = 10.0 * Point;

   int    iconCode    = 233;
   color  sigColor    = clrLime;
   string labelText   = "";
   double markerPrice = price;
   double textPrice   = price;

   if(stage == "SPIKE_START")
     {
      if(dir >= 0) // Bullish Spike
        {
         iconCode    = 233;
         sigColor    = clrLime;
         labelText   = "▲ SPIKE STARTED [BULL]";
         markerPrice = Low[0] - offset;
         textPrice   = markerPrice - (offset * 0.8);
        }
      else // Bearish Spike
        {
         iconCode    = 234;
         sigColor    = clrRed;
         labelText   = "▼ SPIKE STARTED [BEAR]";
         markerPrice = High[0] + offset;
         textPrice   = markerPrice + (offset * 0.8);
        }
     }
   else if(stage == "SPIKE_END")
     {
      iconCode = 254;
      sigColor = clrOrangeRed;
      if(dir >= 0)
        {
         labelText   = "■ SPIKE END [BULL]";
         markerPrice = (price > 0.0) ? price : High[0];
         textPrice   = markerPrice + offset;
        }
      else
        {
         labelText   = "■ SPIKE END [BEAR]";
         markerPrice = (price > 0.0) ? price : Low[0];
         textPrice   = markerPrice - offset;
        }
     }
   else if(stage == "SPIKE_REV_START")
     {
      iconCode = 171;
      if(dir >= 0)
        {
         sigColor    = clrAqua;
         labelText   = "★ SPIKE REVERSE STARTED [BUY -> EMA]";
         markerPrice = Low[0] - offset;
         textPrice   = markerPrice - (offset * 0.8);
        }
      else
        {
         sigColor    = clrMagenta;
         labelText   = "★ SPIKE REVERSE STARTED [SELL -> EMA]";
         markerPrice = High[0] + offset;
         textPrice   = markerPrice + (offset * 0.8);
        }
     }
   else if(stage == "SPIKE_REV_END")
     {
      iconCode    = 251;
      sigColor    = clrGold;
      labelText   = "✔ SPIKE REVER END [200 EMA TOUCH]";
      markerPrice = (price > 0.0) ? price : Close[0];
      textPrice   = (dir >= 0) ? (markerPrice + offset * 0.8) : (markerPrice - offset * 0.8);
     }

   string baseName = StringFormat("SPK_MKR_%s_%d_%d", stage, (int)TimeCurrent(), s_spikeObjSeq);
   string txtName  = StringFormat("SPK_TXT_%s_%d_%d", stage, (int)TimeCurrent(), s_spikeObjSeq);
   string tooltip  = StringFormat("%s at %.2f | %s | %s", labelText, price, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), details);

   // 1. Icon Marker
   if(ObjectFind(0, baseName) < 0)
      ObjectCreate(0, baseName, OBJ_ARROW, 0, barTime, markerPrice);
   else
      ObjectMove(0, baseName, 0, barTime, markerPrice);
   ObjectSetInteger(0, baseName, OBJPROP_ARROWCODE, iconCode);
   ObjectSetInteger(0, baseName, OBJPROP_COLOR, sigColor);
   ObjectSetInteger(0, baseName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, baseName, OBJPROP_BACK, false);
   ObjectSetInteger(0, baseName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, baseName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, baseName, OBJPROP_TOOLTIP, tooltip);

   // 2. Bold Text Label
   if(ObjectFind(0, txtName) < 0)
      ObjectCreate(0, txtName, OBJ_TEXT, 0, barTime, textPrice);
   else
      ObjectMove(0, txtName, 0, barTime, textPrice);
   ObjectSetString(0, txtName, OBJPROP_TEXT, labelText);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, sigColor);
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, txtName, OBJPROP_TOOLTIP, tooltip);

   ChartRedraw(0);

   PrintFormat(">>> [SPIKE CHART SIGNAL] Placed '%s' at %.2f | Bar=%s | State=%d | Details: %s",
               labelText, price, TimeToString(barTime, TIME_DATE|TIME_MINUTES), s_spikeLifecycleState, details);
  }
