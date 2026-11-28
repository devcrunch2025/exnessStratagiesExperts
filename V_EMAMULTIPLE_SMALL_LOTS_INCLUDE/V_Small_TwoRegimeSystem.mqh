//+------------------------------------------------------------------+
//|                                       V_Small_TwoRegimeSystem.mqh|
//|                 Two-Regime Trading System (TRTS) State Machine   |
//|                                                                  |
//| Regime 1: Normal Trading Regime (Capital Growth)                 |
//|   - Operates when price is within normal distance (< $1000)      |
//|   - Standard SSL/EMA momentum, scalping, and orderly baskets     |
//|                                                                  |
//| Regime 2: Crisis / Climax Regime (Capital Preservation)          |
//|   - Engages when distance to 200 EMA >= $1000 or flash move      |
//|   - Freezes low-prob trend-chasing entries into exhaustion       |
//|   - Purges opposite pending stops into the floor/ceiling         |
//|   - Liquidates stale counter-trend runners                       |
//|   - Activates structural mean reversion (Method 7 Rebound)       |
//|   - Resumes Regime 1 when price returns to EMA or dist < $400    |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

//+------------------------------------------------------------------+
//| GetTwoRegimeStatusDisplay: Returns user-facing regime name       |
//+------------------------------------------------------------------+
string GetTwoRegimeStatusDisplay()
  {
   if(!InpEnableTwoRegimeSystem)
      return "[TRTS: OFF]";

   if(g_currentTradingRegime == REGIME_2_CRISIS_CLIMAX)
      return "[REGIME 2: CRISIS]";

   return "[REGIME 1: NORMAL]";
  }

//+------------------------------------------------------------------+
//| GetTwoRegimeStatusColor: Returns color for dashboard             |
//+------------------------------------------------------------------+
color GetTwoRegimeStatusColor()
  {
   if(!InpEnableTwoRegimeSystem)
      return clrSilver;

   if(g_currentTradingRegime == REGIME_2_CRISIS_CLIMAX)
      return clrOrangeRed;

   return clrLime;
  }

//+------------------------------------------------------------------+
//| UpdateTwoRegimeStateMachine: Main state transition engine        |
//+------------------------------------------------------------------+
void UpdateTwoRegimeStateMachine()
  {
   if(!InpEnableTwoRegimeSystem)
     {
      g_currentTradingRegime = REGIME_1_NORMAL_GROWTH;
      return;
     }

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma <= 0.0)
      return;

   double curPrice = (Bid > 0.0) ? Bid : Close[0];
   double distToEma = MathAbs(curPrice - liveEma);

   double climaxThreshold = (InpTwoRegimeClimaxDistance >= 1000.0) ? InpTwoRegimeClimaxDistance : 1000.0;
   double resumeThreshold = (InpTwoRegimeResumeDistance > 0.0) ? InpTwoRegimeResumeDistance : 400.0;

   // -------------------------------------------------------------
   // STATE 1: CURRENTLY IN REGIME 1 (NORMAL TRADING - CAPITAL GROWTH)
   // -------------------------------------------------------------
   if(g_currentTradingRegime == REGIME_1_NORMAL_GROWTH)
     {
      bool triggerRegime2 = false;
      string triggerReason = "";

      // Trigger A: EMA Distance Climax (>= $1000)
      if(distToEma >= climaxThreshold)
        {
         triggerRegime2 = true;
         triggerReason = StringFormat("EMA Distance ($%.2f >= $%.2f)", distToEma, climaxThreshold);
        }
      // Trigger B: Structural line formed far below/above EMA
      else if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0 && (liveEma - Bid >= climaxThreshold))
        {
         triggerRegime2 = true;
         triggerReason = StringFormat("Green Line EQL-G at Floor (Dist=$%.2f)", liveEma - Bid);
        }
      else if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 && (Ask - liveEma >= climaxThreshold))
        {
         triggerRegime2 = true;
         triggerReason = StringFormat("Red Line EQH-R at Ceiling (Dist=$%.2f)", Ask - liveEma);
        }

      if(triggerRegime2)
        {
         g_currentTradingRegime    = REGIME_2_CRISIS_CLIMAX;
         g_regime2EnteredTime      = TimeCurrent();
         g_regime2PeakDistance     = distToEma;
         g_regime2TriggerReason    = triggerReason;
         g_regime2TotalTransitions++;
         g_regime2EntrySide        = (curPrice >= liveEma) ? 1 : -1;

         PrintFormat(">>> ================================================================================");
         PrintFormat(">>> [TWO-REGIME SYSTEM] *** TRANSITION TO REGIME 2: CRISIS / CLIMAX PRESERVATION ***");
         PrintFormat(">>> Trigger: %s | LiveDist=$%.2f | Price=%.2f | EMA=%.2f",
                     triggerReason, distToEma, curPrice, liveEma);
         PrintFormat(">>> Actions: Freezing trend-chasing entries, purging pending stops, protecting capital.");
         PrintFormat(">>> ================================================================================");

         // Execute Immediate Crisis Regime Actions
         if(InpTwoRegimePurgePendingInRegime2)
           {
            // If below EMA, purge sell pending
            if(curPrice < liveEma)
               PurgeTwoWayPendingStopsOnHLine(-1);
            // If above EMA, purge buy pending
            else
               PurgeTwoWayPendingStopsOnHLine(1);
           }

         if(InpTwoRegimeLiquidateRunnersInRegime2)
           {
            int emaDir = (curPrice < liveEma) ? -1 : 1;
            CheckTwoWayClimaxRunnerLiquidation(distToEma, emaDir);
           }
        }
     }
   // -------------------------------------------------------------
   // STATE 2: CURRENTLY IN REGIME 2 (CRISIS / CLIMAX PRESERVATION)
   // -------------------------------------------------------------
   else if(g_currentTradingRegime == REGIME_2_CRISIS_CLIMAX)
     {
      // Track peak distance while in Regime 2
      if(distToEma > g_regime2PeakDistance)
         g_regime2PeakDistance = distToEma;

      bool resumeRegime1 = false;
      string resumeReason = "";

      // Check Condition 1: Distance contracted back below resume threshold ($400)
      if(distToEma <= resumeThreshold)
        {
         resumeRegime1 = true;
         resumeReason = StringFormat("EMA Distance Normalized ($%.2f <= $%.2f)", distToEma, resumeThreshold);
        }
      // Check Condition 2: Price crossed or touched yellow 200 EMA from opposite entry side
      else if(g_regime2PeakDistance > 0.0)
        {
         // Entered below EMA -> resume only if price rallies back up to/above EMA
         if(g_regime2EntrySide < 0 && curPrice >= liveEma)
           {
            resumeRegime1 = true;
            resumeReason = StringFormat("Price Retested/Crossed 200 EMA from Below (Price=%.2f >= EMA=%.2f)", curPrice, liveEma);
           }
         // Entered above EMA -> resume only if price pulls back down to/below EMA
         else if(g_regime2EntrySide > 0 && curPrice <= liveEma)
           {
            resumeRegime1 = true;
            resumeReason = StringFormat("Price Retested/Crossed 200 EMA from Above (Price=%.2f <= EMA=%.2f)", curPrice, liveEma);
           }
        }

      if(resumeRegime1)
        {
         g_currentTradingRegime = REGIME_1_NORMAL_GROWTH;
         g_regime2EntrySide     = 0;
         g_regime2PeakDistance  = 0.0;

         PrintFormat(">>> ================================================================================");
         PrintFormat(">>> [TWO-REGIME SYSTEM] *** RESUMING REGIME 1: NORMAL TRADING (GROWTH MODE) ***");
         PrintFormat(">>> Reason: %s | PeakDistInRegime2=$%.2f | CurrentDist=$%.2f",
                     resumeReason, g_regime2PeakDistance, distToEma);
         PrintFormat(">>> Actions: Resuming standard trend momentum, scalping, and orderly basket targets.");
         PrintFormat(">>> ================================================================================");
        }
     }
  }

//+------------------------------------------------------------------+
//| IsOrderAllowedUnderCurrentRegime: Central Order Permission Gate  |
//+------------------------------------------------------------------+
bool IsOrderAllowedUnderCurrentRegime(int orderType, string comment, int requestedDirection)
  {
   if(!InpEnableTwoRegimeSystem)
      return true;

   // REGIME 1: All standard growth and trend orders are permitted
   if(g_currentTradingRegime == REGIME_1_NORMAL_GROWTH)
      return true;

   // REGIME 2: CRISIS / CLIMAX CAPITAL PRESERVATION
   // 1. Dedicated Rebound (M7_), Recovery (RECOVERY_), and FLIP orders are ALWAYS ALLOWED
   //    (trend-chasing SPIKE entries remain gated at >=$1000 climax extension below)
   if(StringFind(comment, "M7_") == 0)
      return true;
   if(StringFind(comment, "RECOVERY_") == 0)
      return true;
   if(StringFind(comment, "FLIP") >= 0)
      return true;

   // 2. If trend-chasing freeze is enabled in Regime 2:
   if(InpTwoRegimeFreezeChasingInRegime2)
     {
      double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
      if(liveEma > 0.0)
        {
         datetime nowSec = TimeCurrent();
         static datetime s_lastRegime2SellBlockLog = 0;
         static datetime s_lastRegime2BuyBlockLog  = 0;

         // If price is deep below EMA (climax dump), DO NOT ALLOW new SELL orders!
         if(Bid < liveEma && requestedDirection == -1)
           {
            if(s_lastRegime2SellBlockLog == 0 || (nowSec - s_lastRegime2SellBlockLog) >= 30 || nowSec < s_lastRegime2SellBlockLog)
              {
               s_lastRegime2SellBlockLog = nowSec;
               PrintFormat("SAFEORDERSEND BLOCKED [Two-Regime System - REGIME 2]: Low-probability trend SELL '%s' blocked into climax floor! Preserving capital.", comment);
              }
            return false;
           }

         // If price is deep above EMA (climax rocket), DO NOT ALLOW new BUY orders!
         if(Ask > liveEma && requestedDirection == 1)
           {
            if(s_lastRegime2BuyBlockLog == 0 || (nowSec - s_lastRegime2BuyBlockLog) >= 30 || nowSec < s_lastRegime2BuyBlockLog)
              {
               s_lastRegime2BuyBlockLog = nowSec;
               PrintFormat("SAFEORDERSEND BLOCKED [Two-Regime System - REGIME 2]: Low-probability trend BUY '%s' blocked into climax ceiling! Preserving capital.", comment);
              }
            return false;
           }
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
