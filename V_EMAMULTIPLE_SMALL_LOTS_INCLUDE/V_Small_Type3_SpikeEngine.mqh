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
double   g_spikeStartSpeedAbove        = 0.0; // Initial 5m distance speed at Bullish SPIKE_START
double   g_spikeStartSpeedBelow        = 0.0; // Initial 5m distance speed at Bearish SPIKE_START

//+------------------------------------------------------------------+
//| ResetSpikeLifecycleState: Reset chart signal & 5m step state     |
//+------------------------------------------------------------------+
void ResetSpikeLifecycleState()
  {
   s_spikeLifecycleState        = 0;
   s_lastSpikeSignalDir         = 0;
   s_lastSpikeSignalTime        = 0;
   s_lastSpikeEndTime           = 0;
   g_blockBuySpikeUntilNewSpike   = false;
   g_buySpikeBlockedSinceEndTime  = 0;
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
   g_spikeStartSpeedAbove      = 0.0;
   g_spikeStartSpeedBelow      = 0.0;
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

   // 1. Measure EXACT N-minute net EMA-distance expansion (no intra-window MIN cherry-picking)
   double rollingDeltaBelow = 0.0;
   double rollingDeltaAbove = 0.0;
   int m1BarsTotal = iBars(Symbol(), PERIOD_M1);
   if(m1BarsTotal > lookbackMins)
     {
      datetime anchorBarT = iTime(Symbol(), PERIOD_M1, lookbackMins);
      bool postEndReady = !(s_lastSpikeEndTime > 0 &&
                            (s_spikeLifecycleState >= 2 || g_blockBuySpikeUntilNewSpike || g_blockSellSpikeUntilNewSpike) &&
                            anchorBarT < s_lastSpikeEndTime);
      if(postEndReady)
        {
         double pM1_5    = iClose(Symbol(), PERIOD_M1, lookbackMins);
         int    emaShift = (Period() == PERIOD_M1) ? lookbackMins : iBarShift(Symbol(), Period(), anchorBarT, false);
         if(emaShift < 0)
            emaShift = 0;
         double emaAt5   = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, emaShift);
         if(emaAt5 > 0.0 && pM1_5 > 0.0)
           {
            double pastDistBelow5m = (pM1_5 < emaAt5) ? (emaAt5 - pM1_5) : 0.0;
            double pastDistAbove5m = (pM1_5 > emaAt5) ? (pM1_5 - emaAt5) : 0.0;
            if(curDistBelow > pastDistBelow5m)
               rollingDeltaBelow = curDistBelow - pastDistBelow5m;
            if(curDistAbove > pastDistAbove5m)
               rollingDeltaAbove = curDistAbove - pastDistAbove5m;
           }
        }
     }

   // 1B. Check violent 1-Bar M1 flash candle burst (surge >= $300 & >= 3.0x M1 ATR moving away from EMA)
   bool oneBarFlashBull = false;
   bool oneBarFlashBear = false;
   if(InpEnableType3Spike1BarShock && m1BarsTotal > 15)
     {
      double atrM1    = iATR(Symbol(), PERIOD_M1, 14, 1);
      double shockMin = (InpType3Spike1BarShockUSD > 0.0) ? InpType3Spike1BarShockUSD : 300.0;
      double atrReq   = (InpType3Spike1BarAtrMult > 0.0 && atrM1 > 0.0) ? (InpType3Spike1BarAtrMult * atrM1) : shockMin;
      double bar0Open = iOpen(Symbol(), PERIOD_M1, 0);
      double bar1Open = iOpen(Symbol(), PERIOD_M1, 1);
      double bar1Close= iClose(Symbol(), PERIOD_M1, 1);
      datetime bar1T  = iTime(Symbol(), PERIOD_M1, 1);

      double surgeBull0 = (curDistAbove > 0.0 && bar0Open > 0.0) ? (Bid - bar0Open) : 0.0;
      double surgeBull1 = (curDistAbove > 0.0 && bar1Open > 0.0 && bar1T >= s_lastSpikeEndTime) ? (bar1Close - bar1Open) : 0.0;
      double bestBullBar = MathMax(surgeBull0, surgeBull1);
      if(curDistAbove >= shockMin && bestBullBar >= shockMin && bestBullBar >= atrReq)
        {
         oneBarFlashBull = true;
         if(bestBullBar > rollingDeltaAbove)
            rollingDeltaAbove = bestBullBar;
        }

      double surgeBear0 = (curDistBelow > 0.0 && bar0Open > 0.0) ? (bar0Open - Bid) : 0.0;
      double surgeBear1 = (curDistBelow > 0.0 && bar1Open > 0.0 && bar1T >= s_lastSpikeEndTime) ? (bar1Open - bar1Close) : 0.0;
      double bestBearBar = MathMax(surgeBear0, surgeBear1);
      if(curDistBelow >= shockMin && bestBearBar >= shockMin && bestBearBar >= atrReq)
        {
         oneBarFlashBear = true;
         if(bestBearBar > rollingDeltaBelow)
            rollingDeltaBelow = bestBearBar;
        }
     }

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

   double minSpikeEmaDist = (InpType3SpikeMinEmaDistUSD > 0.0) ? InpType3SpikeMinEmaDistUSD : 400.0;
   if(InpEnableType3SpikeVelocityFilter || InpEnableFastMovingEmaSpike)
     {
      if(InpType3SpikeStrict5MinBoundaryOnly)
        {
         if(curDistAbove >= minSpikeEmaDist && boundaryConfirmedBull)
            outBullSpike = true;
         if(curDistBelow >= minSpikeEmaDist && boundaryConfirmedBear)
            outBearSpike = true;
        }
      else
        {
         if(curDistAbove > 0.0 && ((curDistAbove >= minSpikeEmaDist && bestDeltaAbove >= InpType3Spike5MinDistanceChange) || oneBarFlashBull))
            outBullSpike = true;
         if(curDistBelow > 0.0 && ((curDistBelow >= minSpikeEmaDist && bestDeltaBelow >= InpType3Spike5MinDistanceChange) || oneBarFlashBear))
            outBearSpike = true;
        }
     }

   // Unlock SPIKE END directional lock ONLY when a genuinely NEW velocity spike signal starts (5m expansion or 1-bar flash)
   bool anySpikeLockActive = (g_blockBuySpikeUntilNewSpike || g_blockSellSpikeUntilNewSpike);
   datetime lockSinceTime  = MathMax(g_buySpikeBlockedSinceEndTime, g_sellSpikeBlockedSinceEndTime);
   if(anySpikeLockActive && (nowServer - lockSinceTime) >= 60)
     {
      bool newVelocityStarted = (outBullSpike || outBearSpike) &&
                                (oneBarFlashBull || oneBarFlashBear ||
                                 (curDistAbove >= minSpikeEmaDist && (bestDeltaAbove >= InpType3Spike5MinDistanceChange || boundaryConfirmedBull)) ||
                                 (curDistBelow >= minSpikeEmaDist && (bestDeltaBelow >= InpType3Spike5MinDistanceChange || boundaryConfirmedBear)));
      if(newVelocityStarted)
        {
         g_blockBuySpikeUntilNewSpike   = false;
         g_buySpikeBlockedSinceEndTime  = 0;
         g_blockSellSpikeUntilNewSpike  = false;
         g_sellSpikeBlockedSinceEndTime = 0;
         PrintFormat(">>> [NEW SPIKE SIGNAL STARTED] Unlocking SPIKE END directional BUY/SELL-spike locks! (5m Delta A=$%.2f, B=$%.2f)",
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
//| IsType3ManagedOrder: Single check for Type 3 SPIKE/M7/T3 orders  |
//+------------------------------------------------------------------+
bool IsType3ManagedOrder(int ticket, string comment = "")
  {
   string cmt = comment;
   if(cmt == "" && ticket > 0 && OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      cmt = OrderComment();
   if(cmt == "")
      return false;
   return (StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "M7_") == 0 || StringFind(cmt, "T3_") == 0);
  }

//+------------------------------------------------------------------+
//| ShouldExcludeType3OrderFromStandardExit:                         |
//| - Always keeps M7_ Two-Way orders isolated to Method 7 trailing  |
//| - Allows SPIKE/T3_ in #1090 exits (Method 1/4/6, HLine SL, Table |
//|   A/B, Daily SL lock) unless InpIsolateSpikeFromStandardExits=on |
//+------------------------------------------------------------------+
bool ShouldExcludeType3OrderFromStandardExit(int ticket, string comment = "")
  {
   string cmt = comment;
   if(cmt == "" && ticket > 0 && OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      cmt = OrderComment();
   if(cmt == "")
      return false;

   if(StringFind(cmt, "M7_") == 0)
      return true;

   if(InpIsolateSpikeFromStandardExits && (StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "T3_") == 0))
      return true;

   return false;
  }

//+------------------------------------------------------------------+
//| GetOrderTypeCategoryForCreation: Map comment/regime to Type 1/2/3|
//+------------------------------------------------------------------+
int GetOrderTypeCategoryForCreation(string comment = "")
  {
   if(StringFind(comment, "SPIKE") >= 0 ||
      StringFind(comment, "M7_") == 0 ||
      StringFind(comment, "T3_") == 0 ||
      StringFind(comment, "_TYPE3") >= 0)
      return 3;

   if(StringFind(comment, "T1_") == 0)
      return 1;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   if(IsLadderType2AngleRange(MathAbs(curAngle)))
      return 2;

   return 1;
  }

//+------------------------------------------------------------------+
//| IsOrderTypeEnabledByConfig: Check master Type 1/2/3 switch       |
//+------------------------------------------------------------------+
bool IsOrderTypeEnabledByConfig(int typeNum)
  {
   if(typeNum == 1)
      return InpEnableType1Orders;
   if(typeNum == 2)
      return InpEnableType2Orders;
   if(typeNum == 3)
      return InpEnableType3Orders;
   return true;
  }

//+------------------------------------------------------------------+
//| IsOrderCreationAllowedByTypeSwitches: Unified Type 1/2/3 gate    |
//+------------------------------------------------------------------+
bool IsOrderCreationAllowedByTypeSwitches(string comment = "", bool logBlock = false)
  {
   if(StringFind(comment, "RECOVERY_") == 0 && StringFind(comment, "_LSD") >= 0 &&
      !InpEnableLsdStructuralRecovery && !InpEnableHorizontalLineRecovery)
      return false;

   int reqType = GetOrderTypeCategoryForCreation(comment);
   if(IsOrderTypeEnabledByConfig(reqType))
      return true;

   if(logBlock)
     {
      static datetime s_lastTypeBlockLog[4] = {0, 0, 0, 0};
      datetime nowSec = TimeCurrent();
      if(reqType >= 1 && reqType <= 3 &&
         (s_lastTypeBlockLog[reqType] == 0 || (nowSec - s_lastTypeBlockLog[reqType]) >= 30 || nowSec < s_lastTypeBlockLog[reqType]))
        {
         s_lastTypeBlockLog[reqType] = nowSec;
         PrintFormat(">>> [TYPE %d DISABLED] Order creation blocked (T1=%s T2=%s T3=%s | Ang=%.1f deg | Tag='%s')",
                     reqType,
                     (InpEnableType1Orders ? "ON" : "OFF"),
                     (InpEnableType2Orders ? "ON" : "OFF"),
                     (InpEnableType3Orders ? "ON" : "OFF"),
                     GlobalEmaAngle30, comment);
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| IsType3SpikeActive: Check if Type 3 Spike / Climax is active     |
//| includeOpenOrders=false checks only live velocity / climax dist  |
//+------------------------------------------------------------------+
bool IsType3SpikeActive(bool includeOpenOrders = true)
  {
   if(InpEnableType3Orders)
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
     }

   if(!includeOpenOrders)
     {
      if(!InpEnableType3Orders)
         g_type3SpikeActiveState = false;
      return false;
     }

   // Condition C: Active Open Spike or Two-Way orders exist on account (still manage exits even if Type 3 creation is OFF)
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(IsType3ManagedOrder(OrderTicket(), OrderComment()))
        {
         g_type3SpikeActiveState = true;
         return true;
        }
     }

   // If no spike velocity and no open spike/waterfall orders remain, clean up active signal near EMA
   if(InpEnableType3Orders)
     {
      double maxLiveDist = MathMax(g_spike5mCacheDistAbove, g_spike5mCacheDistBelow);
      if(s_spikeLifecycleState == 1 && maxLiveDist < 50.0 && (TimeCurrent() - s_lastSpikeSignalTime) >= 60)
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
   if(!InpEnableType3Orders || !IsType3SpikeActive())
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
   // Manage Two-Way Waterfall Trailing Stops & Rebound EMA-touch profit closes.
   // Note: ManageSpikeProfitLadder() runs once per tick at top of OnTick() so spike bucket peaks also reset when 0 orders remain.
   ManageTwoWayReboundAndWaterfallOrders();
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
   PrintFormat(">>> [3-TYPE SYSTEM TELEMETRY] ACTIVE REGIME: %s | Enabled: T1=%s T2=%s T3=%s | 5m StepGap(A/B)=$%.1f/$%.1f",
               activeRegime,
               (InpEnableType1Orders ? "ON" : "OFF"),
               (InpEnableType2Orders ? "ON" : "OFF"),
               (InpEnableType3Orders ? "ON" : "OFF"),
               g_spike5mLiveStepGapAbove, g_spike5mLiveStepGapBelow);
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
   string mask = StringFormat("[T1:%s T2:%s T3:%s]",
                              (InpEnableType1Orders ? "ON" : "OFF"),
                              (InpEnableType2Orders ? "ON" : "OFF"),
                              (InpEnableType3Orders ? "ON" : "OFF"));
   if(IsType3SpikeActive())
      return (InpEnableType3Orders ? "[TYPE 3: SPIKE ACTIVE] " : "[TYPE 3: MANAGE ONLY] ") + mask;
   if(IsType2GradualTrendActive())
      return (InpEnableType2Orders ? "[TYPE 2: TREND ACTIVE] " : "[TYPE 2: OFF] ") + mask;
   return (InpEnableType1Orders ? "[TYPE 1: RANGE OSC] " : "[TYPE 1: OFF] ") + mask;
  }

//+------------------------------------------------------------------+
//| GetThreeTypeActiveStatusColor: For Dashboard Visualization       |
//+------------------------------------------------------------------+
color GetThreeTypeActiveStatusColor()
  {
   if(IsType3SpikeActive())
      return clrOrangeRed;
   if(IsType2GradualTrendActive())
      return (InpEnableType2Orders ? clrAqua : clrSilver);
   return (InpEnableType1Orders ? clrLime : clrSilver);
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
         s_spikeLifecycleState  = 0;
         s_lastSpikeSignalDir   = 0;
         g_spikeStartSpeedAbove = 0.0;
         g_spikeStartSpeedBelow = 0.0;
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
      CaptureType3SpikeStartSpeed(dir, (dir >= 0 ? g_spike5mCacheDeltaAbove : g_spike5mCacheDeltaBelow));

      datetime lockSince = MathMax(g_buySpikeBlockedSinceEndTime, g_sellSpikeBlockedSinceEndTime);
      if((g_blockBuySpikeUntilNewSpike || g_blockSellSpikeUntilNewSpike) && (TimeCurrent() - lockSince) >= 5)
        {
         g_blockBuySpikeUntilNewSpike   = false;
         g_buySpikeBlockedSinceEndTime  = 0;
         g_blockSellSpikeUntilNewSpike  = false;
         g_sellSpikeBlockedSinceEndTime = 0;
         PrintFormat(">>> [NEW SPIKE SIGNAL STARTED] Cleared BUY/SELL-spike locks on new SPIKE_START (Dir=%+d).", dir);
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
      g_spikeStartSpeedAbove    = 0.0;
      g_spikeStartSpeedBelow    = 0.0;

      // USER RULE:
      // - Order closing on SPIKE END is DISABLED (InpType3CloseWithTrendOnSpikeEnd = false) -> keep existing orders open!
      // - Still lock new BUY spike orders (Bullish) / SELL spike orders (Bearish) until a NEW spike signal starts!
      int curEmaDir = (liveEma200 > 0.0) ? ((Bid > liveEma200) ? 1 : ((Bid < liveEma200) ? -1 : EMADirection)) : EMADirection;
      if(curEmaDir == 1 || curEmaDir == -1)
        {
         int reqOrdType   = (curEmaDir == 1) ? OP_BUY : OP_SELL;
         bool isEmaStrong = (!InpType3SpikeEndRequireStrongEmaForClose || !IsEmaWEAKDistanceReduced50PercentFromPeak(reqOrdType));

         if(curEmaDir == 1)
           {
            if(InpType3LockSpikeCreationOnSpikeEnd)
              {
               g_blockBuySpikeUntilNewSpike  = true;
               g_buySpikeBlockedSinceEndTime = TimeCurrent();
              }
            if(InpType3CloseWithTrendOnSpikeEnd && isEmaStrong)
              {
               CloseAllOpenBuyOrders("BULLISH_STRONG_EMA_SPIKE_END_CLOSE_ALL_BUYS");
               Print(">>> [BULLISH EMA (STRONG) + SPIKE END] Closed ALL open BUY orders and locked BUY spike creation until NEW spike signal starts!");
              }
            else
              {
               Print(">>> [BULLISH EMA + SPIKE END] Close on SPIKE END DISABLED -> Open BUY orders kept intact; BUY spike creation locked until NEW spike signal starts!");
              }
           }
         else if(curEmaDir == -1)
           {
            if(InpType3LockSpikeCreationOnSpikeEnd)
              {
               g_blockSellSpikeUntilNewSpike  = true;
               g_sellSpikeBlockedSinceEndTime = TimeCurrent();
              }
            if(InpType3CloseWithTrendOnSpikeEnd && isEmaStrong)
              {
               CloseAllOpenSellOrders("BEARISH_STRONG_EMA_SPIKE_END_CLOSE_ALL_SELLS");
               Print(">>> [BEARISH EMA (STRONG) + SPIKE END] Closed ALL open SELL orders and locked SELL spike creation until NEW spike signal starts!");
              }
            else
              {
               Print(">>> [BEARISH EMA + SPIKE END] Close on SPIKE END DISABLED -> Open SELL orders kept intact; SELL spike creation locked until NEW spike signal starts!");
              }
           }
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

      s_spikeLifecycleState  = 0; // Reset to IDLE (full cycle completed!)
      s_lastSpikeSignalDir   = 0;
      s_lastSpikeSignalTime  = TimeCurrent();
      g_spikeStartSpeedAbove = 0.0;
      g_spikeStartSpeedBelow = 0.0;
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

//+------------------------------------------------------------------+
//| CountActiveSpikeMarketOrders: Counts open market SPIKE orders    |
//+------------------------------------------------------------------+
int CountActiveSpikeMarketOrders(int orderType)
  {
   int count = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == orderType && StringFind(OrderComment(), "SPIKE") >= 0)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| GetEffectiveSpikeOrderCooldownSec:                               |
//| USER RULE:                                                       |
//| - Previous Spike order (same dir) in PROFIT (>= $0) -> 5 sec     |
//| - Previous Spike order (same dir) in LOSS   (<  $0) -> 30 sec    |
//+------------------------------------------------------------------+
int GetEffectiveSpikeOrderCooldownSec(int orderType, double &outPrevPL, datetime &outLastEventTime, bool &outFoundPrev)
  {
   outPrevPL        = 0.0;
   outLastEventTime = 0;
   outFoundPrev     = false;

   int    latestTicket = -1;
   double latestPL     = 0.0;

   // 1. Check active open Spike orders in the requested direction first
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != orderType || StringFind(OrderComment(), "SPIKE") < 0)
         continue;

      datetime ot = OrderOpenTime();
      int tkt     = OrderTicket();
      if(!outFoundPrev || ot > outLastEventTime || (ot == outLastEventTime && tkt > latestTicket))
        {
         outFoundPrev     = true;
         outLastEventTime = ot;
         latestTicket     = tkt;
         latestPL         = OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

   // 2. Fallback to most recent closed Spike order in history if no open Spike order exists
   if(!outFoundPrev)
     {
      int histTotal = OrdersHistoryTotal();
      int minHistIdx = MathMax(0, histTotal - 50);
      for(int h = histTotal - 1; h >= minHistIdx; h--)
        {
         if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(OrderType() != orderType || StringFind(OrderComment(), "SPIKE") < 0)
            continue;

         datetime ct = OrderCloseTime();
         int tkt     = OrderTicket();
         if(!outFoundPrev || ct > outLastEventTime || (ct == outLastEventTime && tkt > latestTicket))
           {
            outFoundPrev     = true;
            outLastEventTime = ct;
            latestTicket     = tkt;
            latestPL         = OrderProfit() + OrderSwap() + OrderCommission();
           }
        }
     }

   if(outFoundPrev)
     {
      outPrevPL = latestPL;
      if(latestPL < 0.0)
         return InpSpikeOrderLossCooldownSec; // 30s when previous Spike order is in loss
     }

   return InpSpikeOrderCooldownSec; // 5s when previous Spike order is in profit (or first Spike order)
  }

//+------------------------------------------------------------------+
//| CaptureType3SpikeStartSpeed: Store baseline 5m speed on start    |
//+------------------------------------------------------------------+
void CaptureType3SpikeStartSpeed(int dir, double curSpeed, bool overwrite = false)
  {
   double baseline = MathMax(InpType3Spike5MinDistanceChange, curSpeed);
   if(dir >= 0 && (overwrite || g_spikeStartSpeedAbove <= 0.0))
      g_spikeStartSpeedAbove = baseline;
   else if(dir < 0 && (overwrite || g_spikeStartSpeedBelow <= 0.0))
      g_spikeStartSpeedBelow = baseline;
  }

//+------------------------------------------------------------------+
//| GetType3DirectionNetPL: Current floating net PL of all Type 3    |
//| managed orders (SPIKE / M7_ / T3_) in the specified direction    |
//+------------------------------------------------------------------+
double GetType3DirectionNetPL(int baseOrdType)
  {
   double totalPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == baseOrdType && IsType3ManagedOrder(OrderTicket(), OrderComment()))
         totalPL += (OrderProfit() + OrderSwap() + OrderCommission());
     }
   return totalPL;
  }

//+------------------------------------------------------------------+
//| GetActiveSpikeDirectionNetPL: Current floating net PL of spikes  |
//+------------------------------------------------------------------+
double GetActiveSpikeDirectionNetPL(int baseOrdType)
  {
   double totalPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == baseOrdType && StringFind(OrderComment(), "SPIKE") >= 0)
         totalPL += (OrderProfit() + OrderSwap() + OrderCommission());
     }
   return totalPL;
  }

//+------------------------------------------------------------------+
//| CalculateType3SpikeLot:                                          |
//| Option B Progressive Schedule (0.01, 0.02, 0.02, 0.03, 0.03):    |
//| - With House-Money Boost (>=1.25x Start & bucket >=$2*mult):     |
//|   accelerates to (0.01, 0.02, 0.03, 0.03, 0.04 cap)              |
//| - Order #1 = 0.01 (Scout)                                        |
//| - Optional daily equity target cap (off by default in V-1140)    |
//| - EMA WEAK or Counter-EMA direction -> strictly 0.01             |
//| - Speed dropped below SPIKE Start speed -> strictly 0.01         |
//| - Previous same-direction Spike order in loss -> strictly 0.01   |
//+------------------------------------------------------------------+
double CalculateType3SpikeLot(int orderType, string &outLotReason)
  {
   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   bool isBuy = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT);
   int reqDir = isBuy ? 1 : -1;
   int baseOrdType = isBuy ? OP_BUY : OP_SELL;

   // Measure current 5m spike velocity so Order #1 seeds baseline speed & Orders #2..5 verify momentum
   bool spkBull = false, spkBear = false;
   double dAbove = 0.0, dBelow = 0.0, deltaAbove = 0.0, deltaBelow = 0.0;
   Evaluate5MinEmaDistanceStepGap(spkBull, spkBear, dAbove, dBelow, deltaAbove, deltaBelow);
   double curSpeed = isBuy ? deltaAbove : deltaBelow;

   int activeCount = CountActiveSpikeMarketOrders(baseOrdType);
   if(activeCount == 0)
     {
      CaptureType3SpikeStartSpeed(reqDir, curSpeed, true);
      double scoutLot = NormalizeLots(InpType3SpikeLotOrder1 * mult);
      outLotReason = StringFormat("Order #1 Scout (Base=%.2f x%d, StartSpeed=$%.1f)", InpType3SpikeLotOrder1, mult, (isBuy ? g_spikeStartSpeedAbove : g_spikeStartSpeedBelow));
      return scoutLot;
     }

   // Safety Rule 1: Daily equity target hit / resumed leg -> strictly safe 0.01
   if(InpType3CapLotOnDailyTargetHit && (g_dailyEquityTargetHitToday || g_dailyEquityIsResumedLeg))
     {
      int safeMult = InpStepTradingMomentumUsesMultiplier ? mult : 1;
      outLotReason = "DailyTargetHit -> Safe 0.01";
      return NormalizeLots(0.01 * safeMult);
     }

   // Safety Rule 2: EMA WEAK or direction mismatch -> strictly 0.01
   if(IsEmaWEAKDistanceReduced50PercentFromPeak(baseOrdType) || EMADirection != reqDir)
     {
      outLotReason = StringFormat("EMA %s/Mismatch (Dir=%d vs Req=%d) -> Strict 0.01",
                                  (IsEmaWEAKDistanceReduced50PercentFromPeak(baseOrdType) ? "WEAK" : "STRONG"),
                                  EMADirection, reqDir);
      return NormalizeLots(0.01 * mult);
     }

   // Safety Rule 3: Speed comparison vs SPIKE Start speed -> immediate drop to 0.01 on slowdown
   double startSpeed  = isBuy ? g_spikeStartSpeedAbove : g_spikeStartSpeedBelow;
   double speedRatio  = (InpType3SpikeLotMinSpeedRatio > 0.0) ? InpType3SpikeLotMinSpeedRatio : 1.0;
   double minReqSpeed = MathMax(InpType3Spike5MinDistanceChange, startSpeed * speedRatio);
   if(curSpeed < minReqSpeed)
     {
      outLotReason = StringFormat("SpeedDown (Cur=$%.1f < Req=$%.1f [Start=$%.1f]) -> Immediate 0.01", curSpeed, minReqSpeed, startSpeed);
      return NormalizeLots(0.01 * mult);
     }

   // Safety Rule 4: Previous Spike order must be in profit (>= $0) to pyramid
   if(InpType3RequirePrevProfitForScaleUp)
     {
      double prevPL = 0.0;
      datetime lastEvt = 0;
      bool hasPrev = false;
      GetEffectiveSpikeOrderCooldownSec(baseOrdType, prevPL, lastEvt, hasPrev);
      if(hasPrev && prevPL < 0.0)
        {
         outLotReason = StringFormat("PrevSpikeLoss ($%.2f < $0) -> Strict 0.01", prevPL);
         return NormalizeLots(0.01 * mult);
        }
     }

   // Confirmed strong acceleration -> Option B progressive lot schedule (0.01, 0.02, 0.02, 0.03, 0.03)
   // House-Money Boost when speed >= InpType3BoostSpeedMultiplier * Start & open bucket PL >= InpType3BoostMinBucketProfitUSD * mult
   double schedule[5];
   schedule[0] = InpType3SpikeLotOrder1;
   schedule[1] = InpType3SpikeLotOrder2;
   schedule[2] = InpType3SpikeLotOrder3;
   schedule[3] = InpType3SpikeLotOrder4;
   schedule[4] = InpType3SpikeLotOrder5;
   int idx = MathMin(activeCount, 4);
   double targetBase = (schedule[idx] > 0.0) ? schedule[idx] : 0.01;
   bool houseMoneyBoostApplied = false;
   double bucketPL = GetActiveSpikeDirectionNetPL(baseOrdType);

   if(InpEnableType3HouseMoneyBoost && startSpeed > 0.0 && curSpeed >= (startSpeed * InpType3BoostSpeedMultiplier))
     {
      if(bucketPL >= (InpType3BoostMinBucketProfitUSD * mult))
        {
         double maxBoostCap = (InpType3SpikeLotMaxBoostCap > 0.0) ? InpType3SpikeLotMaxBoostCap : 0.04;
         if(activeCount == 2 && InpType3SpikeLotOrder4 > targetBase)
           {
            targetBase = MathMin(InpType3SpikeLotOrder4, maxBoostCap);
            houseMoneyBoostApplied = true;
           }
         else if(activeCount >= 4 && maxBoostCap > targetBase)
           {
            targetBase = maxBoostCap;
            houseMoneyBoostApplied = true;
           }
        }
     }

   double finalLot = NormalizeLots(targetBase * mult);

   outLotReason = StringFormat("Order #%d %s (Base=%.2f x%d | CurSpeed=$%.1f vs Start=$%.1f | BucketPL=$%.2f | EMA=STRONG)",
                               activeCount + 1, (houseMoneyBoostApplied ? "HouseMoneyBoost" : "Boosted"),
                               targetBase, mult, curSpeed, startSpeed, bucketPL);
   return finalLot;
  }
