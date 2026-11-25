//+------------------------------------------------------------------+
//|                                     V_Small_LiquiditySweep.mqh |
//|        V_EMAMULTIPLE_SMALL_LOTS LIQUIDITY SWEEP & LINES MODULE   |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// 1. HORIZONTAL LINE & SWEEP OPPOSITE BLOCKING
//====================================================================
//+------------------------------------------------------------------+
//| IsBlockedByActiveHorizontalLines:                                |
//| Shared Physical Gate for SafeOrderSend & direct LSD/FLIP helpers |
//| 1. When BOTH Red (EQH-R) & Green (EQH-G) lines are active:       |
//|    Conflicting signals -> block ALL orders until 1 line confirms |
//| 2. When a single horizontal line is active:                      |
//|    Red active  -> block BUY orders within $50 range              |
//|    Green active -> block SELL orders within $50 range            |
//+------------------------------------------------------------------+
bool IsBlockedByActiveHorizontalLines(int orderType, double reqPrice, string orderComment = "")
  {
   RefreshRates();
   bool hasActiveRed   = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0);
   bool hasActiveGreen = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0);

   static datetime s_lastBothLinesBlockLog       = 0;
   static datetime s_lastActiveRedBuyBlockLog    = 0;
   static datetime s_lastActiveGreenSellBlockLog = 0;
   datetime nowLineBlockT = TimeCurrent();
   if(nowLineBlockT < s_lastBothLinesBlockLog)
      s_lastBothLinesBlockLog = 0;
   if(nowLineBlockT < s_lastActiveRedBuyBlockLog)
      s_lastActiveRedBuyBlockLog = 0;
   if(nowLineBlockT < s_lastActiveGreenSellBlockLog)
      s_lastActiveGreenSellBlockLog = 0;

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double minAngleToBlock = (InpBothHorizontalLinesBlockMinEmaAngle > 0.0) ? InpBothHorizontalLinesBlockMinEmaAngle : 4.0;

   // Rule 1: Both Red (EQH-R) AND Green (EQH-G) active simultaneously -> block ALL orders only when MathAbs(EMA Angle) >= 4.0
   if(InpBlockAllOrdersWhenBothHorizontalLinesActive && hasActiveRed && hasActiveGreen && absEmaAng >= minAngleToBlock)
     {
      if(s_lastBothLinesBlockLog == 0 || (nowLineBlockT - s_lastBothLinesBlockLog) >= 30)
        {
         PrintFormat("SAFEORDERSEND BLOCKED [BOTH HORIZONTAL LINES ACTIVE]: Conflicting Red (EQH-R=%.2f Start=%s) & Green (EQH-G=%.2f Start=%s) -> blocking type=%d Bid=%.2f Ask=%.2f Req=%.2f (EMA Angle=%.1f >= %.1f) | Wait for single line confirmation | %s",
                     g_lastEqHighPrice, TimeToString(g_lastEqHighLineStart, TIME_DATE|TIME_SECONDS),
                     g_lastEqLowPrice, TimeToString(g_lastEqLowLineStart, TIME_DATE|TIME_SECONDS),
                     orderType, Bid, Ask, reqPrice, absEmaAng, minAngleToBlock, orderComment);
         s_lastBothLinesBlockLog = nowLineBlockT;
        }
      return true;
     }

// Rule 2: Single active line -> block opposite-direction orders (at any distance if InpBlockAllOppositeWhenLineActive, else within range)
   double lineBlockRange = InpActiveLineOppositeBlockRangeRaw;
   if(!InpBlockAllOppositeWhenLineActive && lineBlockRange <= 0.0)
      return false;

   bool isBuySideOrder  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSellSideOrder = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);

   // USER RULE: Spike Orders Bypass Active Horizontal Line Opposite Block
   bool isSpikeOrder = (StringFind(orderComment, "SPIKE") >= 0) ||
                       (InpEnableSpikeOrderCreation &&
                        ((isBuySideOrder  && EMADirection == 1  && curEmaAng < 0.0) ||
                         (isSellSideOrder && EMADirection == -1 && curEmaAng > 0.0)));

   if(InpBlockBuyNearActiveRedLine && isBuySideOrder && hasActiveRed)
     {
      if(InpSpikeBypassHorizontalLineBlock && isSpikeOrder)
        {
         static datetime s_lastSpikeRedBypassLog = 0;
         if(s_lastSpikeRedBypassLog == 0 || (nowLineBlockT - s_lastSpikeRedBypassLog) >= 30)
           {
            PrintFormat(">>> [SPIKE ORDER BYPASS ACTIVE RED LINE] Bullish Spike (EMA=+1, Angle=%+.1f deg) -> Allowing BUY order despite active Red EQH-R | %s",
                        curEmaAng, orderComment);
            s_lastSpikeRedBypassLog = nowLineBlockT;
           }
        }
      else
        {
         double checkBuyReq    = (orderType == OP_BUY) ? Ask : NormalizeDouble(reqPrice, Digits);
         double liveBuyDistRed = MathAbs(Ask - g_lastEqHighPrice);
         double reqBuyDistRed  = (checkBuyReq > 0.0) ? MathAbs(checkBuyReq - g_lastEqHighPrice) : liveBuyDistRed;
         if(InpBlockAllOppositeWhenLineActive || liveBuyDistRed <= lineBlockRange + 1e-8 || reqBuyDistRed <= lineBlockRange + 1e-8)
           {
            if(s_lastActiveRedBuyBlockLog == 0 || (nowLineBlockT - s_lastActiveRedBuyBlockLog) >= 30)
              {
               PrintFormat("SAFEORDERSEND BLOCKED [ACTIVE RED EQH-R]: Blocking BUY type=%d | Ask=%.2f Req=%.2f RedLine=%.2f Start=%s LiveDist=$%.2f ReqDist=$%.2f Mode=%s | %s",
                           orderType, Ask, checkBuyReq, g_lastEqHighPrice,
                           TimeToString(g_lastEqHighLineStart, TIME_DATE|TIME_SECONDS),
                           liveBuyDistRed, reqBuyDistRed,
                           (InpBlockAllOppositeWhenLineActive ? "ALL_DIST" : ("$" + DoubleToString(lineBlockRange, 2))),
                           orderComment);
               s_lastActiveRedBuyBlockLog = nowLineBlockT;
              }
            return true;
           }
        }
     }

   if(InpBlockSellNearActiveGreenLine && isSellSideOrder && hasActiveGreen)
     {
      if(InpSpikeBypassHorizontalLineBlock && isSpikeOrder)
        {
         static datetime s_lastSpikeGreenBypassLog = 0;
         if(s_lastSpikeGreenBypassLog == 0 || (nowLineBlockT - s_lastSpikeGreenBypassLog) >= 30)
           {
            PrintFormat(">>> [SPIKE ORDER BYPASS ACTIVE GREEN LINE] Bearish Spike (EMA=-1, Angle=%+.1f deg) -> Allowing SELL order despite active Green EQH-G | %s",
                        curEmaAng, orderComment);
            s_lastSpikeGreenBypassLog = nowLineBlockT;
           }
        }
      else
        {
         double checkSellReq      = (orderType == OP_SELL) ? Bid : NormalizeDouble(reqPrice, Digits);
         double liveSellDistGreen = MathAbs(Bid - g_lastEqLowPrice);
         double reqSellDistGreen  = (checkSellReq > 0.0) ? MathAbs(checkSellReq - g_lastEqLowPrice) : liveSellDistGreen;
         if(InpBlockAllOppositeWhenLineActive || liveSellDistGreen <= lineBlockRange + 1e-8 || reqSellDistGreen <= lineBlockRange + 1e-8)
           {
            if(s_lastActiveGreenSellBlockLog == 0 || (nowLineBlockT - s_lastActiveGreenSellBlockLog) >= 30)
              {
               PrintFormat("SAFEORDERSEND BLOCKED [ACTIVE GREEN EQH-G]: Blocking SELL type=%d | Bid=%.2f Req=%.2f GreenLine=%.2f Start=%s LiveDist=$%.2f ReqDist=$%.2f Mode=%s | %s",
                           orderType, Bid, checkSellReq, g_lastEqLowPrice,
                           TimeToString(g_lastEqLowLineStart, TIME_DATE|TIME_SECONDS),
                           liveSellDistGreen, reqSellDistGreen,
                           (InpBlockAllOppositeWhenLineActive ? "ALL_DIST" : ("$" + DoubleToString(lineBlockRange, 2))),
                           orderComment);
               s_lastActiveGreenSellBlockLog = nowLineBlockT;
              }
            return true;
           }
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
//| ResetSweepOppositeBlockState:                                    |
//| Clears active SSLS/BSLS opposite-order block state.              |
//+------------------------------------------------------------------+
void ResetSweepOppositeBlockState(string reason = "")
  {
   if(reason != "" && g_sweepOppositeBlockSignal != "None")
      Print(">>> [SWEEP OPPOSITE BLOCK RESET] ", reason);

   g_sweepOppositeBlockSignal         = "None";
   g_sweepOppositeBlockBarTime        = 0;
   g_sweepOppositeBlockActivatedAt    = 0;
   g_sweepOppositeBlockInitEmaDir     = 0;
   g_sweepOppositeBlockInitTrackDir   = 0;
   g_sweepOppositeBlockInitEqHStart   = 0;
   g_sweepOppositeBlockInitEqLStart   = 0;
   g_sweepOppositeBlockBannedEqHStart = 0;
   g_sweepOppositeBlockBannedEqLStart = 0;
   g_sweepPendingCleanupDir           = 0;
  }

//+------------------------------------------------------------------+
//| DeleteOppositePendingOrdersForGuard:                             |
//| Deletes open EA pending orders on the blocked opposite side.     |
//| Returns number deleted (>=0), or -failedCount if any retry needed|
//+------------------------------------------------------------------+
int DeleteOppositePendingOrdersForGuard(bool deleteBuyPending, string reason, bool onlyMom = false)
  {
   int deletedCount = 0;
   int failedCount  = 0;
   color delClr     = deleteBuyPending ? clrRed : clrGreen;
   string sideName  = deleteBuyPending ? "BUY" : "SELL";

   for(int p = OrdersTotal() - 1; p >= 0; p--)
     {
      if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int pType = OrderType();
      bool isTargetPending = deleteBuyPending
                             ? (pType == OP_BUYSTOP || pType == OP_BUYLIMIT)
                             : (pType == OP_SELLSTOP || pType == OP_SELLLIMIT);
      if(!isTargetPending)
         continue;

      int    tkt    = OrderTicket();
      double lots   = OrderLots();
      double openPx = OrderOpenPrice();
      string cmt    = OrderComment();

      if(onlyMom && StringFind(cmt, "MOM") < 0)
         continue;

      if(StringFind(cmt, "SPIKE") >= 0)
         continue;

      if(SafeOrderDelete(tkt, delClr))
        {
         deletedCount++;
         InvalidateTotalEAOrdersCache();
         PrintFormat(">>> [PENDING ORDER DELETED - %s] Deleted %s pending #%d (Type=%d, Lots=%.2f, Entry=%.2f, Comment='%s')",
                     reason, sideName, tkt, pType, lots, openPx, cmt);
        }
      else
        {
         failedCount++;
         PrintFormat(">>> [PENDING DELETE DEFERRED - %s] Failed to delete %s pending #%d (Err=%d)",
                     reason, sideName, tkt, GetLastError());
        }
     }

   return (failedCount > 0) ? -failedCount : deletedCount;
  }

//+------------------------------------------------------------------+
//| SyncHorizontalLineStartPendingCleanup:                           |
//| USER RULE:                                                       |
//| - When GREEN horizontal line (EQH-G) starts -> delete SELL       |
//|   pending orders (OP_SELLSTOP / OP_SELLLIMIT).                   |
//| - When RED horizontal line (EQH-R) starts -> delete BUY          |
//|   pending orders (OP_BUYSTOP / OP_BUYLIMIT).                     |
//+------------------------------------------------------------------+
void SyncHorizontalLineStartPendingCleanup()
  {
   if(!InpDeleteOppositePendingOnHLineStart)
      return;

   if(!EAStartupComplete)
     {
      if(g_lastEqHighLineStart > g_lastDeletedPendingEqHStart)
         g_lastDeletedPendingEqHStart = g_lastEqHighLineStart;
      if(g_lastEqLowLineStart > g_lastDeletedPendingEqLStart)
         g_lastDeletedPendingEqLStart = g_lastEqLowLineStart;
      return;
     }

   if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 &&
      g_lastEqHighLineStart > g_lastDeletedPendingEqHStart &&
      g_lastEqHighLineStart > g_lastSweptEqHighLineStart)
     {
      int redDelRes = DeleteOppositePendingOrdersForGuard(true,
                      StringFormat("RED EQH-R START %s @ %.2f",
                                   TimeToString(g_lastEqHighLineStart, TIME_DATE|TIME_MINUTES),
                                   g_lastEqHighPrice));
      if(redDelRes >= 0)
         g_lastDeletedPendingEqHStart = g_lastEqHighLineStart;
     }

   if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0 &&
      g_lastEqLowLineStart > g_lastDeletedPendingEqLStart &&
      g_lastEqLowLineStart > g_lastSweptEqLowLineStart)
     {
      int greenDelRes = DeleteOppositePendingOrdersForGuard(false,
                        StringFormat("GREEN EQH-G START %s @ %.2f",
                                     TimeToString(g_lastEqLowLineStart, TIME_DATE|TIME_MINUTES),
                                     g_lastEqLowPrice));
      if(greenDelRes >= 0)
         g_lastDeletedPendingEqLStart = g_lastEqLowLineStart;
     }
  }

//+------------------------------------------------------------------+
//| SyncSweepOppositeBlockState:                                     |
//| Expires the 5-min SSLS/BSLS opposite-order block or resets early |
//| when a new horizontal line (EQH-R/EQH-G) or EMADirection flip    |
//| is detected.                                                     |
//+------------------------------------------------------------------+
void SyncSweepOppositeBlockState()
  {
   if(g_sweepPendingCleanupDir != 0)
     {
      if(InpDeleteOppositePendingOnSweep && EAStartupComplete)
        {
         int retryDel = DeleteOppositePendingOrdersForGuard((g_sweepPendingCleanupDir > 0),
                        StringFormat("SWEEP %s RETRY", (g_sweepPendingCleanupDir > 0 ? "BSLS" : "SSLS")),
                        InpSweepOppositeBlockOnlyMOMOrders);
         if(retryDel >= 0)
            g_sweepPendingCleanupDir = 0;
        }
      else
        {
         g_sweepPendingCleanupDir = 0;
        }
     }

   if(g_sweepOppositeBlockSignal != "SSLS" && g_sweepOppositeBlockSignal != "BSLS")
      return;

   if(!InpEnableSweepOppositeBlock || InpSweepOppositeBlockMinutes <= 0)
     {
      ResetSweepOppositeBlockState("Opposite-order sweep block disabled via settings");
      return;
     }

   datetime nowT = TimeCurrent();
   int blockSec  = InpSweepOppositeBlockMinutes * 60;
   if(g_sweepOppositeBlockActivatedAt <= 0 || nowT < g_sweepOppositeBlockActivatedAt ||
      (nowT - g_sweepOppositeBlockActivatedAt) >= blockSec)
     {
      int elapsedSec = (g_sweepOppositeBlockActivatedAt > 0 && nowT >= g_sweepOppositeBlockActivatedAt)
                       ? (int)(nowT - g_sweepOppositeBlockActivatedAt) : 0;
      ResetSweepOppositeBlockState(StringFormat("%s %dm cooldown expired (Elapsed=%ds / %ds)",
                                   g_sweepOppositeBlockSignal, InpSweepOppositeBlockMinutes, elapsedSec, blockSec));
      return;
     }

   if(InpResetSweepOppositeBlockOnEmaFlip)
     {
      if(g_sweepOppositeBlockInitEmaDir == 0 && EMADirection != 0)
         g_sweepOppositeBlockInitEmaDir = EMADirection;
      if(g_sweepOppositeBlockInitTrackDir == 0 && LastTrackedEmaDirection != 0)
         g_sweepOppositeBlockInitTrackDir = LastTrackedEmaDirection;

      bool emaChanged   = (EMADirection != 0 && g_sweepOppositeBlockInitEmaDir != 0 && EMADirection != g_sweepOppositeBlockInitEmaDir);
      bool trackChanged = (LastTrackedEmaDirection != 0 && g_sweepOppositeBlockInitTrackDir != 0 && LastTrackedEmaDirection != g_sweepOppositeBlockInitTrackDir);
      if(emaChanged || trackChanged)
        {
         ResetSweepOppositeBlockState(StringFormat("%s block cleared: EMADirection flipped (EMA=%d->%d, Track=%d->%d)",
                                      g_sweepOppositeBlockSignal,
                                      g_sweepOppositeBlockInitEmaDir, EMADirection,
                                      g_sweepOppositeBlockInitTrackDir, LastTrackedEmaDirection));
         return;
        }
     }

   if(InpResetSweepOppositeBlockOnNewHLine)
     {
      if(g_lastEqHighLineStart == 0)
         g_sweepOppositeBlockInitEqHStart = 0;
      if(g_lastEqLowLineStart == 0)
         g_sweepOppositeBlockInitEqLStart = 0;

      bool newRedDetected   = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 &&
                               g_lastEqHighLineStart != g_sweepOppositeBlockInitEqHStart &&
                               g_lastEqHighLineStart > g_sweepOppositeBlockBannedEqHStart);
      bool newGreenDetected = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0 &&
                               g_lastEqLowLineStart  != g_sweepOppositeBlockInitEqLStart &&
                               g_lastEqLowLineStart  > g_sweepOppositeBlockBannedEqLStart);

      if(newRedDetected || newGreenDetected)
        {
         string hDesc = newRedDetected
                        ? StringFormat("New EQH-R Red line (Start=%s, Price=%.2f)", TimeToString(g_lastEqHighLineStart, TIME_DATE|TIME_MINUTES), g_lastEqHighPrice)
                        : StringFormat("New EQH-G Green line (Start=%s, Price=%.2f)", TimeToString(g_lastEqLowLineStart, TIME_DATE|TIME_MINUTES), g_lastEqLowPrice);
         ResetSweepOppositeBlockState(StringFormat("%s block cleared: New horizontal signal detected (%s)",
                                      g_sweepOppositeBlockSignal, hDesc));
         return;
        }
     }
  }

//+------------------------------------------------------------------+
//| ActivateSweepOppositeBlockOnSweep:                               |
//| Arms the 5-min opposite-order block in SafeOrderSend() when a    |
//| fresh live SSLS or BSLS sweep fires.                             |
//+------------------------------------------------------------------+
void ActivateSweepOppositeBlockOnSweep(string sweepSig, datetime sweepBarTime)
  {
   if(!InpEnableSweepOppositeBlock || InpSweepOppositeBlockMinutes <= 0)
      return;
   if(sweepSig != "SSLS" && sweepSig != "BSLS")
      return;
   if(sweepBarTime <= 0)
      return;

// Ignore pre-existing historical sweeps present before EA initialization completes
   if(!EAStartupComplete)
     {
      if(sweepBarTime > g_lastHandledSweepBlockBarTime)
        {
         g_lastHandledSweepBlockBarTime = sweepBarTime;
         g_lastHandledSweepBlockType    = sweepSig;
        }
      return;
     }

   datetime nowT = TimeCurrent();
   int blockSec  = InpSweepOppositeBlockMinutes * 60;

// Ignore stale historical sweeps (or intra-bar flicker falling back to an older sweep)
   if(nowT < sweepBarTime || (nowT - sweepBarTime) >= blockSec)
      return;
   if(sweepBarTime < g_lastHandledSweepBlockBarTime)
      return;
   if(sweepBarTime == g_lastHandledSweepBlockBarTime && sweepSig == g_lastHandledSweepBlockType)
      return;

   g_lastHandledSweepBlockBarTime   = sweepBarTime;
   g_lastHandledSweepBlockType      = sweepSig;

   g_sweepOppositeBlockSignal         = sweepSig;
   g_sweepOppositeBlockBarTime        = sweepBarTime;
   g_sweepOppositeBlockActivatedAt    = nowT;
   g_sweepOppositeBlockInitEmaDir     = EMADirection;
   g_sweepOppositeBlockInitTrackDir   = LastTrackedEmaDirection;
   g_sweepOppositeBlockInitEqHStart   = g_lastEqHighLineStart;
   g_sweepOppositeBlockInitEqLStart   = g_lastEqLowLineStart;
   g_sweepOppositeBlockBannedEqHStart = MathMax(g_lastEqHighLineStart, (sweepSig == "BSLS" ? g_lastSweptEqHighLineStart : 0));
   g_sweepOppositeBlockBannedEqLStart = MathMax(g_lastEqLowLineStart, (sweepSig == "SSLS" ? g_lastSweptEqLowLineStart  : 0));

   PrintFormat(">>> [SWEEP OPPOSITE BLOCK ARMED] '%s' triggered (SweepBar=%s) -> Blocking %s orders in SafeOrderSend() for %d min (until %s, or reset on new horizontal line / EMA flip)",
               sweepSig,
               TimeToString(sweepBarTime, TIME_DATE|TIME_MINUTES),
               (sweepSig == "SSLS" ? "SELL" : "BUY"),
               InpSweepOppositeBlockMinutes,
               TimeToString(nowT + blockSec, TIME_DATE|TIME_SECONDS));

   if(InpDeleteOppositePendingOnSweep)
     {
      double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
      double absEmaAng = MathAbs(curEmaAng);
      double minAngleToBlock = (InpSweepOppositeBlockMinEmaAngle > 0.0) ? InpSweepOppositeBlockMinEmaAngle : 4.0;
      if(absEmaAng >= minAngleToBlock)
        {
         bool delBuyPending = (sweepSig == "BSLS");
         int sweepDelRes = DeleteOppositePendingOrdersForGuard(delBuyPending,
                           StringFormat("SWEEP %s (%s)", sweepSig, TimeToString(sweepBarTime, TIME_DATE|TIME_MINUTES)),
                           InpSweepOppositeBlockOnlyMOMOrders);
         g_sweepPendingCleanupDir = (sweepDelRes < 0) ? (delBuyPending ? 1 : -1) : 0;
        }
     }
  }

//+------------------------------------------------------------------+
//| IsBlockedByActiveSweepOppositeRule:                              |
//| SafeOrderSend() physical gate:                                   |
//| - SSLS active (<5m) -> blocks SELL / SELLSTOP / SELLLIMIT orders |
//| - BSLS active (<5m) -> blocks BUY  / BUYSTOP  / BUYLIMIT  orders |
//+------------------------------------------------------------------+
bool IsBlockedByActiveSweepOppositeRule(int orderType, string orderComment = "")
  {
   SyncSweepOppositeBlockState();
   if(g_sweepOppositeBlockSignal != "SSLS" && g_sweepOppositeBlockSignal != "BSLS")
      return false;

   // USER RULE: Do not block if EMA angle is less than 4 (Strategy 1: Range/Consolidation regime)
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double minAngleToBlock = (InpSweepOppositeBlockMinEmaAngle > 0.0) ? InpSweepOppositeBlockMinEmaAngle : 4.0;
   if(absEmaAng < minAngleToBlock)
      return false;

   // USER RULE (V-SMALL-1058): When MathAbs(EMA Angle) >= 4.0, then only block MOM orders (allow non-MOM orders)
   if(InpSweepOppositeBlockOnlyMOMOrders)
     {
      bool isMom = (isMOMOrder || StringFind(orderComment, "MOM") >= 0);
      if(!isMom)
         return false;
     }

   bool isBuySideOrder  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSellSideOrder = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);

   // USER RULE: Spike Orders Bypass Sweep Opposite Block
   bool isSpikeOrder = (StringFind(orderComment, "SPIKE") >= 0) ||
                       (InpEnableSpikeOrderCreation &&
                        ((isBuySideOrder  && EMADirection == 1  && curEmaAng < 0.0) ||
                         (isSellSideOrder && EMADirection == -1 && curEmaAng > 0.0)));
   if(InpSpikeBypassSweepBlock && isSpikeOrder)
      return false;

   bool shouldBlock = (g_sweepOppositeBlockSignal == "SSLS" && isSellSideOrder) ||
                      (g_sweepOppositeBlockSignal == "BSLS" && isBuySideOrder);
   if(!shouldBlock)
      return false;

   datetime nowT     = TimeCurrent();
   int blockSec      = InpSweepOppositeBlockMinutes * 60;
   int elapsedSec    = (g_sweepOppositeBlockActivatedAt > 0 && nowT >= g_sweepOppositeBlockActivatedAt)
                       ? (int)(nowT - g_sweepOppositeBlockActivatedAt) : 0;
   int remainingSec  = MathMax(0, blockSec - elapsedSec);

   static datetime s_lastSweepBlockLogTime = 0;
   if(s_lastSweepBlockLogTime == 0 || nowT < s_lastSweepBlockLogTime || (nowT - s_lastSweepBlockLogTime) >= 30)
     {
      RefreshRates();
      PrintFormat("SAFEORDERSEND BLOCKED [ACTIVE %s SWEEP]: Blocking %s type=%d | Remaining=%ds/%ds | SweepBar=%s | Bid=%.2f Ask=%.2f | %s",
                  g_sweepOppositeBlockSignal,
                  (isSellSideOrder ? "SELL" : "BUY"),
                  orderType, remainingSec, blockSec,
                  TimeToString(g_sweepOppositeBlockBarTime, TIME_DATE|TIME_MINUTES),
                  Bid, Ask, orderComment);
      s_lastSweepBlockLogTime = nowT;
     }

   return true;
  }


//====================================================================
// 2. LSD STRUCTURAL RECOVERY ORDERS
//====================================================================

//+------------------------------------------------------------------+
//| CountActiveLsdRecoveryOrders: Counts active Type 2 Recovery      |
//+------------------------------------------------------------------+
int CountActiveLsdRecoveryOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      string cmt = GetEffectiveOrderComment(OrderTicket(), OrderComment());
      if(StringFind(cmt, "RECOVERY_") == 0 && StringFind(cmt, "_LSD") >= 0)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| CountActiveHedgeRecoveryOrders: Counts active Hedge Recoveries   |
//+------------------------------------------------------------------+
int CountActiveHedgeRecoveryOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      string cmt = GetEffectiveOrderComment(OrderTicket(), OrderComment());
      if(StringFind(cmt, "RECOVERY_") == 0 && StringFind(cmt, "_HEDGE") >= 0)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//| CheckLsdStructuralRecoveryOrders: EQL/EQH Structural Recovery    |
//| (Type 2). Opens recovery order at confirmed EQL support line     |
//| for losing BUYs, or confirmed EQH resistance line for losing     |
//| SELLs, reducing breakeven distance from $200+ to just ~.      |
//+------------------------------------------------------------------+
void CheckLsdStructuralRecoveryOrders()
  {
   if(!InpEnableLsdStructuralRecovery || GetTotalEAOrders() >= MaxOpenOrders || !IsOneCandleOrderAllowed())
      return;

   int maxActive = (InpLsdRecoveryMaxActiveOrders > 0) ? InpLsdRecoveryMaxActiveOrders : 1;
   if(CountActiveLsdRecoveryOrders() >= maxActive)
      return;

   RefreshRates();

   bool eqhRPresent = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 && IsHorizontalLineActivationWaitSatisfied(true));
   bool eqhGPresent = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0 && IsHorizontalLineActivationWaitSatisfied(false));

   if(!eqhRPresent && !eqhGPresent)
      return; // No active single structural liquidity lines past activation wait

   double eqhPrice = eqhRPresent ? g_lastEqHighPrice : 0.0;
   double eqlPrice = eqhGPresent ? g_lastEqLowPrice  : 0.0;

   double tolGap     = (InpLsdRecoveryLevelToleranceRaw > 0.0) ? InpLsdRecoveryLevelToleranceRaw : 50.0;
   double minAdvGap   = (InpLsdRecoveryMinAdverseGap > 0.0)      ? InpLsdRecoveryMinAdverseGap     : 100.0;
   double minLossUSD  = (InpLsdRecoveryTriggerLossUSD > 0.0)     ? InpLsdRecoveryTriggerLossUSD    : 1.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int parentTicket = OrderTicket();
      int parentType   = OrderType();
      if(parentType != OP_BUY && parentType != OP_SELL)
         continue;

      string comment = OrderComment();
      if(IsAnyRecoveryOrder(parentTicket, comment) || IsFLIPBasketSupportOrder(parentTicket, comment))
         continue;
      if(!InpAllowRecoveryForHorizontalOrders && IsHorizontalLineOrder(parentTicket, comment))
         continue;

      // Only rescue regular trades (SSL Long, SSL Short, ReEntry)
      bool validParent = (StringFind(comment, "SSL Long") >= 0 || StringFind(comment, "SSL Short") >= 0 || StringFind(comment, "ReEntry") >= 0);
      if(!validParent)
         continue;

      if(InpEnableRecoveryAttemptShield && HasParentExhaustedRecoveryAttempts(parentTicket))
         continue;

      if(HasRecoveryOrder(parentTicket))
         continue; // Parent already has an active recovery order (strictly max 1 per parent)

      double parentLots = OrderLots();
      double currentProfitUSD = OrderProfit() + OrderSwap() + OrderCommission();

      // Must be in loss >= minLossUSD
      if(currentProfitUSD > -MathAbs(minLossUSD))
         continue;

      double parentOpen = OrderOpenPrice();

      // =================================================================
      // CASE 1: Underwater BUY parent + GREEN LINE (EQL Support) Detected
      // =================================================================
      if(parentType == OP_BUY && eqhGPresent && eqlPrice > 0.0)
        {
         double livePrice = Ask;
         double adverseDistance = parentOpen - livePrice;

         // Must have dropped at least minAdvGap from parent entry
         if(adverseDistance >= minAdvGap)
           {
            // Price must be near the GREEN Line (within tolerance)
            double distToLine = MathAbs(livePrice - eqlPrice);
            if(distToLine <= tolGap)
              {
               double mult = (InpLsdRecoveryLotMultiplier > 0.0) ? InpLsdRecoveryLotMultiplier : 2.0;
               double recLots = NormalizeLots(parentLots * mult);
               if(recLots <= 0.0)
                  recLots = parentLots * 2.0;

               double slDist = (InpLsdRecoveryStopLossRaw > 0.0) ? InpLsdRecoveryStopLossRaw : 300.0;
               double tpDist = (InpLsdRecoveryTakeProfitRaw > 0.0) ? InpLsdRecoveryTakeProfitRaw : 500.0;

               double recSL = NormalizeDouble(livePrice - slDist, Digits);
               double recTP = NormalizeDouble(livePrice + tpDist, Digits);
               string recComment = "RECOVERY_" + IntegerToString(parentTicket) + "_LSD";

               int recTicket = SafeOrderSend(Symbol(), OP_BUY, recLots, livePrice, Slippage, recSL, recTP, recComment, MagicNumber, clrAqua);
               if(recTicket > 0)
                 {
                  RegisterParentRecoveryAttempt(parentTicket);
                  OrderCreatedThisCandle = true;
                  LastOrderCandleTime    = Time[0];
                  Print(">>> [EQL STRUCTURAL RECOVERY (Type 2)] Created BUY Recovery #", recTicket,
                        " Lots=", DoubleToString(recLots, 2), " at Support EQL=", DoubleToString(eqlPrice, Digits),
                        " (Ask=", DoubleToString(livePrice, Digits), ", DistToLine=$", DoubleToString(distToLine, 2),
                        ") for Parent BUY #", parentTicket, " Open=", DoubleToString(parentOpen, Digits),
                        " AdverseGap=$", DoubleToString(adverseDistance, 2), " Loss=$", DoubleToString(currentProfitUSD, 2));
                  break; // 1 order created per check cycle
                 }
              }
           }
        }

      // =================================================================
      // CASE 2: Underwater SELL parent + RED LINE (EQH Resistance) Detected
      // =================================================================
      else
         if(parentType == OP_SELL && eqhRPresent && eqhPrice > 0.0)
           {
            double livePrice = Bid;
            double adverseDistance = livePrice - parentOpen;

            // Must have risen at least minAdvGap from parent entry
            if(adverseDistance >= minAdvGap)
              {
               // Price must be near the RED Line (within tolerance)
               double distToLine = MathAbs(livePrice - eqhPrice);
               if(distToLine <= tolGap)
                 {
                  double mult = (InpLsdRecoveryLotMultiplier > 0.0) ? InpLsdRecoveryLotMultiplier : 2.0;
                  double recLots = NormalizeLots(parentLots * mult);
                  if(recLots <= 0.0)
                     recLots = parentLots * 2.0;

                  double slDist = (InpLsdRecoveryStopLossRaw > 0.0) ? InpLsdRecoveryStopLossRaw : 300.0;
                  double tpDist = (InpLsdRecoveryTakeProfitRaw > 0.0) ? InpLsdRecoveryTakeProfitRaw : 500.0;

                  double recSL = NormalizeDouble(livePrice + slDist, Digits);
                  double recTP = NormalizeDouble(livePrice - tpDist, Digits);
                  string recComment = "RECOVERY_" + IntegerToString(parentTicket) + "_LSD";

                  int recTicket = SafeOrderSend(Symbol(), OP_SELL, recLots, livePrice, Slippage, recSL, recTP, recComment, MagicNumber, clrMagenta);
                  if(recTicket > 0)
                    {
                     RegisterParentRecoveryAttempt(parentTicket);
                     OrderCreatedThisCandle = true;
                     LastOrderCandleTime    = Time[0];
                     Print(">>> [EQH STRUCTURAL RECOVERY (Type 2)] Created SELL Recovery #", recTicket,
                           " Lots=", DoubleToString(recLots, 2), " at Resistance EQH=", DoubleToString(eqhPrice, Digits),
                           " (Bid=", DoubleToString(livePrice, Digits), ", DistToLine=$", DoubleToString(distToLine, 2),
                           ") for Parent SELL #", parentTicket, " Open=", DoubleToString(parentOpen, Digits),
                           " AdverseGap=$", DoubleToString(adverseDistance, 2), " Loss=$", DoubleToString(currentProfitUSD, 2));
                     break; // 1 order created per check cycle
                    }
                 }
              }
           }
     }
  }


//====================================================================
// 3. LIQUIDITY SWEEP DETECTOR & LINE DISTANCE CALCULATIONS
//====================================================================

//+------------------------------------------------------------------+
//| LIQUIDITY SWEEP DETECTOR & GLOBAL VARIABLE MANAGEMENT           |
//| Replicated from V-EMASingleOrder.mq4                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ManageSweepGlobalVariables: Sets both EA global variables and   |
//| MT4 Terminal Global Variables (viewable via F3) with SWEEP       |
//| buy signal or SWEEP sell signal.                                 |
//+------------------------------------------------------------------+
void ManageSweepGlobalVariables(string signalType)
  {
   if(signalType == "SSLS" || signalType == "SSL" || signalType == "BUY" || signalType == "SWEEP buy signal")
     {
      GlobalSweepBuy    = true;
      GlobalSweepSell   = false;
      GlobalSweepSignal = "SWEEP buy signal";
     }
   else
      if(signalType == "BSLS" || signalType == "BSL" || signalType == "SELL" || signalType == "SWEEP sell signal")
        {
         GlobalSweepBuy    = false;
         GlobalSweepSell   = true;
         GlobalSweepSignal = "SWEEP sell signal";
        }
      else
        {
         GlobalSweepBuy    = false;
         GlobalSweepSell   = false;
         GlobalSweepSignal = "None";
        }
  }

//+------------------------------------------------------------------+
//| ClearSweepGlobalVariables: Cleans up Terminal Global Variables  |
//+------------------------------------------------------------------+
void ClearSweepGlobalVariables()
  {
   GlobalSweepBuy    = false;
   GlobalSweepSell   = false;
   GlobalSweepSignal = "None";
  }

//+------------------------------------------------------------------+
//| GetActualEmaFlipTime: Scans backward to identify exact EMA flip |
//+------------------------------------------------------------------+
datetime GetActualEmaFlipTime(int targetType = 0)
  {
   int dir = targetType;
   if(dir == 0)
      dir = EMADirection;
   if(dir == 0)
      dir = LastTrackedEmaDirection;
   if(dir == 0 && Bars > 0)
     {
      double curEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
      if(curEma > 0.0)
         dir = (Close[0] >= curEma) ? 1 : -1;
     }

   int lookback = MathMin(Bars - 2, 5000);

   if(dir == 1) // BULLISH (+1): price above EMA-200
     {
      for(int i = 1; i < lookback; i++)
        {
         double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, i);
         if(ema <= 0.0)
            continue;
         bool crossed = (Close[i] <= ema);
         if(crossed)
           {
            return Time[MathMax(0, i - 1)];
           }
        }
     }
   else
      if(dir == -1) // BEARISH (-1): price below EMA-200
        {
         for(int i = 1; i < lookback; i++)
           {
            double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, i);
            if(ema <= 0.0)
               continue;
            bool crossed = (Close[i] >= ema);
            if(crossed)
              {
               return Time[MathMax(0, i - 1)];
              }
           }
        }
   return 0;
  }

//+------------------------------------------------------------------+
//| GetEmaFlipPrice:                                                 |
//| Returns the price level where the current EMA flip took place.   |
//| Reconstructs from candle history if not yet set in memory.       |
//+------------------------------------------------------------------+
double GetEmaFlipPrice()
  {
   if(g_emaFlipPrice > 0.0)
      return g_emaFlipPrice;

   datetime flipTime = GetActualEmaFlipTime(EMADirection);
   if(flipTime > 0)
     {
      int flipShift = iBarShift(Symbol(), Period(), flipTime, false);
      if(flipShift >= 0 && flipShift < Bars)
        {
         double pClose = iClose(Symbol(), Period(), flipShift);
         if(pClose > 0.0)
           {
            g_emaFlipPrice = pClose;
            return g_emaFlipPrice;
           }
         double pEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, flipShift);
         if(pEma > 0.0)
           {
            g_emaFlipPrice = pEma;
            return g_emaFlipPrice;
           }
        }
     }

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma > 0.0)
      g_emaFlipPrice = liveEma;
   else
      g_emaFlipPrice = (Ask + Bid) * 0.5;

   return g_emaFlipPrice;
  }

//+------------------------------------------------------------------+
//| EMAflipdistance:                                                 |
//| USER RULE: "create one function EMAflipdistance to get the raw   |
//| price distance from EMAflip to live tick price."                 |
//| Computes raw price distance ($ USD) between the EMA flip price   |
//| and the live tick price.                                         |
//+------------------------------------------------------------------+
double EMAflipdistance(int orderType = -1)
  {
   static double cachedDist = 0.0;
   static int    cachedType = -999;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && cachedType == orderType && CurrentTickSequence > 0)
      return cachedDist;

   RefreshRates();
   double flipPrice = GetEmaFlipPrice();
   if(flipPrice <= 0.0)
     {
      cachedDist = 0.0;
      cachedType = orderType;
      cachedTick = CurrentTickSequence;
      return 0.0;
     }

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - flipPrice);

   cachedDist = rawDist;
   cachedType = orderType;
   cachedTick = CurrentTickSequence;
   return rawDist;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepEqlPrice:                                             |
//| Returns the price level of the active LSD_SWEEP EQL (Green line).|
//| Checks memory variable first; if 0, scans chart objects.         |
//+------------------------------------------------------------------+
double GetLsdSweepEqlPrice()
  {
   if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0)
      return g_lastEqLowPrice;

   static double cachedVal = 0.0;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   if(g_lastEqLowPrice > 0.0)
     {
      cachedVal = g_lastEqLowPrice;
      cachedTick = CurrentTickSequence;
      return cachedVal;
     }

   cachedVal = 0.0;
   if(!InpShowLiquiditySweeps)
     {
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0 && StringFind(name, "EQL_M_", 0) < 0)
           {
            datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
            if(TimeCurrent() < t2)
              {
               double p = ObjectGet(name, OBJPROP_PRICE1);
               if(p > 0.0)
                 {
                  cachedVal = p;
                  break;
                 }
              }
           }
        }
     }
   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepEqhPrice:                                             |
//| Returns the price level of the active LSD_SWEEP EQH (Red line).  |
//| Checks memory variable first; if 0, scans chart objects.         |
//+------------------------------------------------------------------+
double GetLsdSweepEqhPrice()
  {
   if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0)
      return g_lastEqHighPrice;

   static double cachedVal = 0.0;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   if(g_lastEqHighPrice > 0.0)
     {
      cachedVal = g_lastEqHighPrice;
      cachedTick = CurrentTickSequence;
      return cachedVal;
     }

   cachedVal = 0.0;
   if(!InpShowLiquiditySweeps)
     {
      int total = ObjectsTotal(0, -1, -1);
      for(int i = total - 1; i >= 0; i--)
        {
         string name = ObjectName(0, i, -1, -1);
         if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0 && StringFind(name, "EQH_M_", 0) < 0)
           {
            datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
            if(TimeCurrent() < t2)
              {
               double p = ObjectGet(name, OBJPROP_PRICE1);
               if(p > 0.0)
                 {
                  cachedVal = p;
                  break;
                 }
              }
           }
        }
     }
   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| LsdSweepEqlDistance:                                             |
//| USER RULE: "Get Raw price gap between LSD_SWEEP_EQL and live     |
//| tick price . create a method to get distance"                    |
//| Computes raw price distance ($ USD) between the active           |
//| LSD_SWEEP EQL (Equal Low green line) and live tick price.        |
//| Returns 0.0 if no EQL line is active.                            |
//+------------------------------------------------------------------+
double LsdSweepEqlDistance(int orderType = -1)
  {
   RefreshRates();
   double eqlPrice = GetLsdSweepEqlPrice();
   if(eqlPrice <= 0.0)
      return 0.0;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqlPrice);
   return rawDist;
  }

// Aliases for user convenience & exact naming match:
double LSD_SWEEP_EQL_distance(int orderType = -1)
  {
   return LsdSweepEqlDistance(orderType);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLsdSweepEqlDistance(int orderType = -1)
  {
   return LsdSweepEqlDistance(orderType);
  }

// Distance in broker Points (Pipettes)
double LsdSweepEqlDistancePoints(int orderType = -1)
  {
   if(Point <= 0.0)
      return 0.0;
   return (LsdSweepEqlDistance(orderType) / Point);
  }

// Companion: Equal High Red line raw price gap
double LsdSweepEqhDistance(int orderType = -1)
  {
   RefreshRates();
   double eqhPrice = GetLsdSweepEqhPrice();
   if(eqhPrice <= 0.0)
      return 0.0;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqhPrice);
   return rawDist;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LSD_SWEEP_EQH_distance(int orderType = -1)
  {
   return LsdSweepEqhDistance(orderType);
  }

//+------------------------------------------------------------------+
//| GetEQR_G_Price: Returns price of active or latest EQR-G Green line
//| (Equal Low support level).                                       |
//+------------------------------------------------------------------+
double GetEQR_G_Price(bool activeOnly = false)
  {
   double p = GetLsdSweepEqlPrice();
   if(p > 0.0)
      return p;
   if(activeOnly)
      return 0.0;

// Fallback: search newest EQR-G / EQL line on chart
   datetime newestTime = 0;
   double newestPrice = 0.0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0 && StringFind(name, "EQL_M_", 0) < 0)
        {
         datetime t1 = (datetime)ObjectGet(name, OBJPROP_TIME1);
         if(t1 > newestTime)
           {
            newestTime = t1;
            newestPrice = ObjectGet(name, OBJPROP_PRICE1);
           }
        }
     }
   return newestPrice;
  }

//+------------------------------------------------------------------+
//| GetEQR_R_Price: Returns price of active or latest EQR-R Red line
//| (Equal High resistance level).                                   |
//+------------------------------------------------------------------+
double GetEQR_R_Price(bool activeOnly = false)
  {
   double p = GetLsdSweepEqhPrice();
   if(p > 0.0)
      return p;
   if(activeOnly)
      return 0.0;

// Fallback: search newest EQR-R / EQH line on chart
   datetime newestTime = 0;
   double newestPrice = 0.0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0 && StringFind(name, "EQH_M_", 0) < 0)
        {
         datetime t1 = (datetime)ObjectGet(name, OBJPROP_TIME1);
         if(t1 > newestTime)
           {
            newestTime = t1;
            newestPrice = ObjectGet(name, OBJPROP_PRICE1);
           }
        }
     }
   return newestPrice;
  }

//+------------------------------------------------------------------+
//| GetRawDistance_EQR_G_ToLivePrice:                                |
//| USER REQUEST: Get raw distance gap between EQR-G to Live price.  |
//| Computes raw price gap ($ USD) between the EQR-G (Equal Low      |
//| Green line / EQH-G) and current live tick price.                 |
//| Parameters:                                                      |
//|   orderType: OP_BUY (uses Ask), OP_SELL (uses Bid),              |
//|              -1 (default, uses current Ask/Bid execution price)  |
//|   defaultIfNone: value to return if no line exists (def 999999.0)|
//| Returns:                                                         |
//|   Raw price difference in USD (e.g. 15.50 on Gold/BTC)           |
//+------------------------------------------------------------------+
double GetRawDistance_EQR_G_ToLivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   RefreshRates();
   double eqlPrice = GetEQR_G_Price(false);
   if(eqlPrice <= 0.0)
      return defaultIfNone;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqlPrice);
   return rawDist;
  }

//+------------------------------------------------------------------+
//| GetRawDistance_EQR_R_ToLivePrice:                                |
//| USER REQUEST: Get raw distance gap between EQR-R to Live price.  |
//| Computes raw price gap ($ USD) between the EQR-R (Equal High     |
//| Red line / EQH-R) and current live tick price.                   |
//| Parameters:                                                      |
//|   orderType: OP_BUY (uses Ask), OP_SELL (uses Bid),              |
//|              -1 (default, uses current Ask/Bid execution price)  |
//|   defaultIfNone: value to return if no line exists (def 999999.0)|
//| Returns:                                                         |
//|   Raw price difference in USD (e.g. 15.50 on Gold/BTC)           |
//+------------------------------------------------------------------+
double GetRawDistance_EQR_R_ToLivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   RefreshRates();
   double eqhPrice = GetEQR_R_Price(false);
   if(eqhPrice <= 0.0)
      return defaultIfNone;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqhPrice);
   return rawDist;
  }

// Convenient exact aliases for user flexibility:
double Distance_EQR_G_To_LivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_G_ToLivePrice(orderType, defaultIfNone);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Distance_EQR_R_To_LivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_R_ToLivePrice(orderType, defaultIfNone);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double EQR_G_To_LivePrice_Distance(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_G_ToLivePrice(orderType, defaultIfNone);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double EQR_R_To_LivePrice_Distance(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_R_ToLivePrice(orderType, defaultIfNone);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetRawDistance_EQH_G_ToLivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_G_ToLivePrice(orderType, defaultIfNone);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetRawDistance_EQH_R_ToLivePrice(int orderType = -1, double defaultIfNone = 999999.0)
  {
   return GetRawDistance_EQR_R_ToLivePrice(orderType, defaultIfNone);
  }


//+------------------------------------------------------------------+
//| DeleteLiquiditySweepObjects: Removes all sweep markers/lines     |
//+------------------------------------------------------------------+
void DeleteLiquiditySweepObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
   g_lastEqHighPrice = 0.0;
   g_lastEqLowPrice  = 0.0;
   g_lastEqHighLineStart = 0;
   g_lastEqLowLineStart  = 0;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepChartSignal: Scans chart objects for LSD_SWEEP markers|
//| Returns:                                                         |
//|   +1 = Green/Lime Buy sweep marker (SSLS)                        |
//|   -1 = Red Sell sweep marker (BSLS)                              |
//|    0 = None found                                                |
//+------------------------------------------------------------------+
int GetLsdSweepChartSignal()
  {
   int total = ObjectsTotal(0, -1, -1);
   datetime newestTime = 0;
   int newestSig = 0;

   for(int k = total - 1; k >= 0; k--)
     {
      string objName = ObjectName(0, k, -1, -1);
      if(StringFind(objName, LSD_PREFIX, 0) == 0 || StringFind(objName, "LSD_SWEEP", 0) >= 0)
        {
         int objType = ObjectType(objName);
         if(objType == OBJ_ARROW || objType == OBJ_TEXT)
           {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME1);
            if(objTime == 0)
               objTime = (datetime)ObjectGet(objName, OBJPROP_TIME1);

            color objColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            int arrowCode  = (int)ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);

            int sig = 0;
            // Check for Buy / Green signal (SSLS / Arrow 241 / Green / Lime)
            if(StringFind(objName, "SSL", 0) >= 0 || StringFind(objName, "BUY", 0) >= 0 ||
               arrowCode == 241 || objColor == InpSslSweepColor || objColor == clrLime || objColor == clrGreen)
              {
               sig = 1;
              }
            // Check for Sell / Red signal (BSLS / Arrow 242 / Red / Tomato)
            else
               if(StringFind(objName, "BSL", 0) >= 0 || StringFind(objName, "SELL", 0) >= 0 ||
                  arrowCode == 242 || objColor == InpBslSweepColor || objColor == clrRed || objColor == clrTomato)
                 {
                  sig = -1;
                 }

            if(sig != 0 && (objTime >= newestTime || newestTime == 0))
              {
               newestTime = objTime;
               newestSig  = sig;
              }
           }
        }
     }
   return newestSig;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepSignal: Evaluates active LSD_SWEEP Buy/Sell signal.   |
//| Checks:                                                          |
//|   1. EA internal state (GlobalSweepBuy, GlobalSweepSell,         |
//|      GlobalSweepSignal, g_rememberedSweepSignal)                 |
//|   2. MT4 Terminal Global Variables (F3)                          |
//|   3. Chart objects (LSD_SWEEP markers & arrows)                  |
//| Returns:                                                         |
//|   +1 = LSD_SWEEP BUY green signal (SSLS)                         |
//|   -1 = LSD_SWEEP SELL red signal (BSLS)                          |
//|    0 = None                                                      |
//+------------------------------------------------------------------+
int GetLsdSweepSignal()
  {
// 1. Check EA internal state
   if(GlobalSweepBuy || GlobalSweepSignal == "SWEEP buy signal" || g_rememberedSweepSignal == "SSLS" || g_lastSweepType == "SSLS")
      return 1;
   if(GlobalSweepSell || GlobalSweepSignal == "SWEEP sell signal" || g_rememberedSweepSignal == "BSLS" || g_lastSweepType == "BSLS")
      return -1;

// Terminal Globals disabled - Pure In-Memory EA Variables in RAM

// 3. Fallback: Scan Chart Objects
   int chartSig = GetLsdSweepChartSignal();
   if(chartSig != 0)
      return chartSig;

   return 0;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepBuySignal: Returns true if LSD_SWEEP BUY green active  |
//+------------------------------------------------------------------+
bool IsLsdSweepBuySignal()
  {
   return (GetLsdSweepSignal() == 1);
  }

//+------------------------------------------------------------------+
//| IsLsdSweepSellSignal: Returns true if LSD_SWEEP SELL red active  |
//+------------------------------------------------------------------+
bool IsLsdSweepSellSignal()
  {
   return (GetLsdSweepSignal() == -1);
  }

//+------------------------------------------------------------------+
//| IsLsdSweepGreenLinePresent: Checks if EQL green line exists      |
//+------------------------------------------------------------------+
bool IsLsdSweepGreenLinePresent()
  {
   static bool cachedVal = false;
   static int  cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   cachedVal = false;
   if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0)
     {
      cachedVal = true;
     }
   else
      if(!InpShowLiquiditySweeps)
        {
         int total = ObjectsTotal(0, -1, -1);
         for(int i = total - 1; i >= 0; i--)
           {
            string name = ObjectName(0, i, -1, -1);
            if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0 && StringFind(name, "EQL_M_", 0) < 0)
              {
               datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
               if(TimeCurrent() < t2)
                 {
                  cachedVal = true;
                  break;
                 }
              }
           }
        }

   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepRedLinePresent: Checks if EQH red line exists          |
//+------------------------------------------------------------------+
bool IsLsdSweepRedLinePresent()
  {
   static bool cachedVal = false;
   static int  cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   cachedVal = false;
   if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0)
     {
      cachedVal = true;
     }
   else
      if(!InpShowLiquiditySweeps)
        {
         int total = ObjectsTotal(0, -1, -1);
         for(int i = total - 1; i >= 0; i--)
           {
            string name = ObjectName(0, i, -1, -1);
            if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0 && StringFind(name, "EQH_M_", 0) < 0)
              {
               datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
               if(TimeCurrent() < t2)
                 {
                  cachedVal = true;
                  break;
                 }
              }
           }
        }

   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepGreenLineActive:                                       |
//| Returns true if the LSD_SWEEP green line (EQL Equal Low level)   |
//| is present on the chart, or if green sweep signal (SSLS) is active.|
//+------------------------------------------------------------------+
bool IsLsdSweepGreenLineActive()
  {
   if(IsLsdSweepGreenLinePresent())
      return true;
   if(InpSweepLineTriggerOnSweepSignal && IsLsdSweepBuySignal())
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepRedLineActive:                                         |
//| Returns true if the LSD_SWEEP red line (EQH Equal High level)    |
//| is present on the chart, or if red sweep signal (BSLS) is active. |
//+------------------------------------------------------------------+
bool IsLsdSweepRedLineActive()
  {
   if(IsLsdSweepRedLinePresent())
      return true;
   if(InpSweepLineTriggerOnSweepSignal && IsLsdSweepSellSignal())
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| ManageLsdSweepLineStopLossProtection:                            |
//| USER OPTION 2 RULE:                                              |
//| ACTIVE LINE: RED LINE -> Close all BUY orders (or modify SL)     |
//| ACTIVE LINE: GREEN LINE -> Close all SELL orders (or modify SL)   |
void ManageLsdSweepLineStopLossProtection()
  {
   return; // DISABLED: LSD Sweep lines only create new Order FlipBasketSupport, DO NOT modify or close existing orders
   if(!InpEnableSweepLineSLProtection)
      return;

   bool greenLineActive = IsLsdSweepGreenLineActive();
   bool redLineActive   = IsLsdSweepRedLineActive();

   if(!greenLineActive && !redLineActive)
      return;

   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   double buffer = MathMax(minDistance, InpSweepLineSLBufferPoints * Point);

   double buyTargetSL  = NormalizeDouble(Bid - buffer, Digits);
   double sellTargetSL = NormalizeDouble(Ask + buffer, Digits);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType        = OrderType();
      int ticket       = OrderTicket();
      double lots      = OrderLots();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentTP = OrderTakeProfit();

      // 1. GREEN LINE ACTIVE -> Close all SELL (or modify SL to current price)
      if(oType == OP_SELL && greenLineActive)
        {
         if(InpSweepLineAction == SWEEP_LINE_CLOSE_ALL_OPPOSITE)
           {
            ResetLastError();
            bool closed = SafeOrderClose(ticket, lots, OP_SELL, Slippage, clrLime);
            if(closed)
              {
               Print(">>> [LSD_SWEEP GREEN LINE ACTION] Closed SELL Order #", ticket,
                     " (", DoubleToString(lots, 2), "L) at market Ask=", DoubleToString(Ask, Digits));
              }
            else
              {
               int err = GetLastError();
               if(err != 0 && err != 1)
                  Print(">>> [LSD_SWEEP GREEN LINE ACTION] Failed to close SELL Order #", ticket, " | Err=", err);
              }
           }
         else // SWEEP_LINE_MODIFY_SL_CURRENT_PRICE
           {
            if(sellTargetSL > 0.0)
              {
               if(currentSL == 0.0 || (sellTargetSL < currentSL && MathAbs(currentSL - sellTargetSL) >= MinimumSLModifyGapRaw))
                 {
                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime, "LsdSweepLineSL");

                  if(modified)
                    {
                     Print(">>> [LSD_SWEEP GREEN LINE SL] Modified SELL Order #", ticket,
                           " | StopLoss set to Current Price Ask=", DoubleToString(sellTargetSL, Digits),
                           " (Previous SL=", DoubleToString(currentSL, Digits), ")");
                    }
                  else
                    {
                     int err = GetLastError();
                     if(err != 1 && err != 0)
                        Print(">>> [LSD_SWEEP GREEN LINE SL] Failed to modify SELL Order #", ticket,
                              " | TargetSL=", DoubleToString(sellTargetSL, Digits), " | Err=", err);
                    }
                 }
              }
           }
        }

      // 2. RED LINE ACTIVE -> Close all BUY (or modify SL to current price)
      if(oType == OP_BUY && redLineActive)
        {
         if(InpSweepLineAction == SWEEP_LINE_CLOSE_ALL_OPPOSITE)
           {
            ResetLastError();
            bool closed = SafeOrderClose(ticket, lots, OP_BUY, Slippage, clrTomato);
            if(closed)
              {
               Print(">>> [LSD_SWEEP RED LINE ACTION] Closed BUY Order #", ticket,
                     " (", DoubleToString(lots, 2), "L) at market Bid=", DoubleToString(Bid, Digits));
              }
            else
              {
               int err = GetLastError();
               if(err != 0 && err != 1)
                  Print(">>> [LSD_SWEEP RED LINE ACTION] Failed to close BUY Order #", ticket, " | Err=", err);
              }
           }
         else // SWEEP_LINE_MODIFY_SL_CURRENT_PRICE
           {
            if(buyTargetSL > 0.0)
              {
               if(currentSL == 0.0 || (buyTargetSL > currentSL && MathAbs(currentSL - buyTargetSL) >= MinimumSLModifyGapRaw))
                 {
                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato, "LsdSweepLineSL");

                  if(modified)
                    {
                     Print(">>> [LSD_SWEEP RED LINE SL] Modified BUY Order #", ticket,
                           " | StopLoss set to Current Price Bid=", DoubleToString(buyTargetSL, Digits),
                           " (Previous SL=", DoubleToString(currentSL, Digits), ")");
                    }
                  else
                    {
                     int err = GetLastError();
                     if(err != 1 && err != 0)
                        Print(">>> [LSD_SWEEP RED LINE SL] Failed to modify BUY Order #", ticket,
                              " | TargetSL=", DoubleToString(buyTargetSL, Digits), " | Err=", err);
                    }
                 }
              }
           }
        }
     }
  }


//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| HasMinimumHorizontalOrderGap                                     |
//| USER RULE: Enforce configured min gap (e.g. $100) between 2        |
//| horizontal EQH orders of same type.                                |
//| Checks whether proposed entry price has at least minGapUSD       |
//| distance from all existing open horizontal orders of same type.  |
//| For BUY: checks existing "EQH-G" / "EQH-G Long" orders           |
//| For SELL: checks existing "EQH-R" / "EQH-R Short" orders         |
//+------------------------------------------------------------------+
bool HasMinimumHorizontalOrderGap(int orderType, double proposedPrice, double minGapUSD)
  {
// Honor configured InpHorizontalOrderSameTypeMinGapUSD (disabled if false or <= 0.0)
   if(!InpEnableHorizontalOrderSameTypeMinGap || minGapUSD <= 0.0)
      return true;
   double effectiveGap = minGapUSD;

   string targetPattern = (orderType == OP_BUY) ? "EQH-G" : "EQH-R";

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int t = OrderType();
      if(t != orderType)
         continue;

      string comm = OrderComment();
      bool isTargetHoriz = (StringFind(comm, targetPattern) >= 0) ||
                           (StringFind(comm, "LSD") >= 0 && (orderType == OP_BUY ? StringFind(comm, "EQHG") >= 0 : StringFind(comm, "EQHR") >= 0)) ||
                           (orderType == OP_BUY && OrderTicket() == g_lastEqlBuyOrderTicket) ||
                           (orderType == OP_SELL && OrderTicket() == g_lastEqhSellOrderTicket);

      if(!isTargetHoriz)
         continue;

      double existingOpen = OrderOpenPrice();
      double dist = MathAbs(proposedPrice - existingOpen);

      if(dist < effectiveGap)
        {
         static datetime s_lastGapBlockLogBuy  = 0;
         static datetime s_lastGapBlockLogSell = 0;
         datetime nowT    = TimeCurrent();
         datetime lastLog = (orderType == OP_BUY) ? s_lastGapBlockLogBuy : s_lastGapBlockLogSell;
         if(lastLog == 0 || (nowT - lastLog) >= 30 || nowT < lastLog)
           {
            if(orderType == OP_BUY)
               s_lastGapBlockLogBuy = nowT;
            else
               s_lastGapBlockLogSell = nowT;
            Print(">>> [HORIZONTAL ORDER GAP BLOCKED] Proposed ", (orderType == OP_BUY ? "EQH-G Long" : "EQH-R Short"),
                  " at ", DoubleToString(proposedPrice, Digits),
                  " is within $", DoubleToString(dist, 2), " of open Ticket #", OrderTicket(),
                  " (Open=", DoubleToString(existingOpen, Digits),
                  ", Gap=$", DoubleToString(dist, 2), " < Minimum $", DoubleToString(effectiveGap, 2), "). Order creation BLOCKED!");
           }
         return false;
        }
     }

   return true;
  }

//+------------------------------------------------------------------+
//| SendLsdRedLineSellOrder:                                         |
//| Sends immediate market SELL order ("EQH-R Short") without any      |
//| condition, with lot 0.02 * multiplier.                           |
//+------------------------------------------------------------------+
int SendLsdRedLineSellOrder(double sellLot, double linePrice = 0.0)
  {
   // USER RULE: "do not create any horizontal order when mathabs emaangle is more than >=4"
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
   if(absEmaAng >= maxHorizAngle)
     {
      PrintFormat(">>> [EQH-R SHORT BLOCKED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal orders strictly blocked!",
                  absEmaAng, maxHorizAngle);
      return -1;
     }

   RefreshRates();
   if(IsBlockedByActiveHorizontalLines(OP_SELL, Bid, "EQH-R Short"))
      return -1;
   if(!HasMinimumHorizontalOrderGap(OP_SELL, Bid, InpHorizontalOrderSameTypeMinGapUSD))
      return -1;
   double slDistance  = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance  = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;

   double stopLoss = 0.0;
   double offset   = (InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0;

// USER RULE: First order after horizontal line is started: SL = Line Price + 50
   if(linePrice > 0.0)
     {
      double lineSL = NormalizeDouble(linePrice + offset, Digits);
      if(lineSL > (Ask + minStopDist))
         stopLoss = lineSL;
      else
         if(slDistance > 0.0)
            stopLoss = NormalizeDouble(Bid + slDistance, Digits);
     }
   else
      if(slDistance > 0.0)
        {
         stopLoss = NormalizeDouble(Bid + slDistance, Digits);
        }

   double takeProfit = (tpDistance > 0.0) ? NormalizeDouble(Bid - tpDistance, Digits) : 0.0;

   ResetLastError();
   int finalErr = 0;
   int ticket = OrderSend(Symbol(), OP_SELL, sellLot, Bid, Slippage, stopLoss, takeProfit, "EQH-R Short", MagicNumber, 0, SellColor);
   if(ticket < 0)
     {
      finalErr = GetLastError();
      // Error 130 (ERR_INVALID_STOPS) on ECN brokers: send with 0 SL/TP first
      if(finalErr == 130 || finalErr == 4107)
        {
         ResetLastError();
         ticket = OrderSend(Symbol(), OP_SELL, sellLot, Bid, Slippage, 0, 0, "EQH-R Short", MagicNumber, 0, SellColor);
         if(ticket < 0)
            finalErr = GetLastError();
         else
            if(stopLoss > 0.0 || takeProfit > 0.0)
               SafeOrderModify(ticket, OrderOpenPrice(), stopLoss, takeProfit, 0, SellColor);
        }
     }

   if(ticket > 0)
     {
      InvalidateTotalEAOrdersCache();
      OrderCreatedThisCandle = true;
      LastOrderCandleTime    = Time[0];
      Print(">>> [NEW RED LINE] Successfully opened immediate market SELL order Ticket #", ticket,
            " 'EQH-R Short' Lots=", DoubleToString(sellLot, 2), " OpenPrice=", DoubleToString(Bid, Digits),
            " SL=", DoubleToString(stopLoss, Digits), " (LinePrice=", DoubleToString(linePrice, Digits),
            ", Line+50=", DoubleToString(linePrice + offset, Digits), ") TP=", DoubleToString(takeProfit, Digits));
     }
   else
     {
      Print(">>> [NEW RED LINE] OrderSend OP_SELL 'EQH-R Short' failed. Error=", finalErr);
      LogEAError(finalErr, "OrderSend(EQH-R Short)", -1, StringFormat("Lots=%.2f Bid=%s SL=%s TP=%s", sellLot, DoubleToString(Bid, Digits), DoubleToString(stopLoss, Digits), DoubleToString(takeProfit, Digits)));
     }
   return ticket;
  }

//+------------------------------------------------------------------+
//| GetSmallestLossOrderTicket:                                      |
//| USER RULE: "When horizantal line is started. create recovery     |
//| order which is smallest loss amount. if RED line started create  |
//| immidtate recovery order for lowest open sell order. same logic  |
//| for GREEN horizontal line"                                       |
//| Finds the open market order of targetType with the SMALLEST      |
//| dollar loss amount (closest to $0 loss / breakeven).             |
//| Respects recovery attempt shield and max 1 recovery per parent.  |
//+------------------------------------------------------------------+
int GetSmallestLossOrderTicket(int targetType)
  {
   int bestTicket = -1;
   double smallestLoss = 999999999.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;
      if(OrderType() != targetType)
         continue;

      int tkt = OrderTicket();
      string comm = OrderComment();

      // Skip recovery orders, support orders, and horizontal line orders
      if(IsAnyRecoveryOrder(tkt, comm) || IsFLIPBasketSupportOrder(tkt, comm))
         continue;
      if(!InpAllowRecoveryForHorizontalOrders && IsHorizontalLineOrder(tkt, comm))
         continue;

      // Parent must not already have an active recovery order
      if(HasRecoveryOrder(tkt))
         continue;

      // Respect 1-attempt shield if enabled
      if(InpEnableRecoveryAttemptShield && HasParentExhaustedRecoveryAttempts(tkt))
         continue;

      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      // Must be strictly in loss (pl < 0.0)
      if(pl < 0.0)
        {
         double lossAmount = MathAbs(pl);
         if(lossAmount < smallestLoss)
           {
            smallestLoss = lossAmount;
            bestTicket   = tkt;
           }
        }
     }

   return bestTicket;
  }

//+------------------------------------------------------------------+
//| CreateHorizontalLineRecoveryOrder:                               |
//| Creates immediate recovery order for losing parent order at      |
//| the newly started horizontal line price.                         |
//| Lots = 2.0x parent lot (InpLsdRecoveryLotMultiplier).            |
//| Managed by ManageRecoveryBasket() targeting +$2.00 net basket.   |
//+------------------------------------------------------------------+
int CreateHorizontalLineRecoveryOrder(int parentTicket, int orderType, double linePrice)
  {
   // USER RULE: "do not create any horizontal order when mathabs emaangle is more than >=4"
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
   if(absEmaAng >= maxHorizAngle)
     {
      PrintFormat(">>> [HORIZONTAL RECOVERY BLOCKED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal recovery orders strictly blocked!",
                  absEmaAng, maxHorizAngle);
      return -1;
     }

   if(!OrderSelect(parentTicket, SELECT_BY_TICKET, MODE_TRADES))
      return -1;
   if(!InpAllowRecoveryForHorizontalOrders && IsHorizontalLineOrder(parentTicket, OrderComment()))
     {
      Print(">>> [HORIZONTAL LINE RECOVERY BLOCKED] Parent #", parentTicket, " is a horizontal line order. Recovery blocked.");
      return -1;
     }

   double parentLots = OrderLots();
   double parentLoss = OrderProfit() + OrderSwap() + OrderCommission();
   double mult = (InpLsdRecoveryLotMultiplier > 0.0) ? InpLsdRecoveryLotMultiplier : 2.0;
   double recLots = NormalizeLots(parentLots * mult);
   if(recLots <= 0.0)
      recLots = parentLots * 2.0;

   RefreshRates();
   double livePrice = (orderType == OP_BUY) ? Ask : Bid;
   string recComment = "RECOVERY_" + IntegerToString(parentTicket) + "_LSD";
   if(IsBlockedByActiveHorizontalLines(orderType, livePrice, recComment))
      return -1;
   double slDist = (InpLsdRecoveryStopLossRaw > 0.0) ? InpLsdRecoveryStopLossRaw : 3000.0;
   double tpDist = (InpLsdRecoveryTakeProfitRaw > 0.0) ? InpLsdRecoveryTakeProfitRaw : 500.0;

   double recSL = 0.0;
   double recTP = 0.0;
   color arrowColor = clrNONE;

   if(orderType == OP_BUY)
     {
      recSL = (slDist > 0.0) ? NormalizeDouble(livePrice - slDist, Digits) : 0.0;
      recTP = (tpDist > 0.0) ? NormalizeDouble(livePrice + tpDist, Digits) : 0.0;
      arrowColor = clrAqua;
     }
   else // OP_SELL
     {
      recSL = (slDist > 0.0) ? NormalizeDouble(livePrice + slDist, Digits) : 0.0;
      recTP = (tpDist > 0.0) ? NormalizeDouble(livePrice - tpDist, Digits) : 0.0;
      arrowColor = clrMagenta;
     }

   ResetLastError();
   int recErr = 0;
   int recTicket = OrderSend(Symbol(), orderType, recLots, livePrice, Slippage, recSL, recTP, recComment, MagicNumber, 0, arrowColor);
   if(recTicket < 0)
     {
      recErr = GetLastError();
      if(recErr == 130)
        {
         ResetLastError();
         recTicket = OrderSend(Symbol(), orderType, recLots, livePrice, Slippage, 0, 0, recComment, MagicNumber, 0, arrowColor);
         if(recTicket < 0)
            recErr = GetLastError();
         else
            if(recSL > 0.0 || recTP > 0.0)
               SafeOrderModify(recTicket, livePrice, recSL, recTP, 0, arrowColor);
        }
     }

   if(recTicket > 0)
     {
      RegisterParentRecoveryAttempt(parentTicket);
      OrderCreatedThisCandle = true;
      LastOrderCandleTime    = Time[0];
      Print(">>> [HORIZONTAL LINE RECOVERY] Created ", (orderType == OP_BUY ? "BUY" : "SELL"),
            " Recovery Order #", recTicket, " Lots=", DoubleToString(recLots, 2),
            " (2.0x of Parent #", parentTicket, " Lots=", DoubleToString(parentLots, 2),
            ") at Market=", DoubleToString(livePrice, Digits),
            " for Parent with SMALLEST Loss=$", DoubleToString(parentLoss, 2),
            " | SL=", DoubleToString(recSL, Digits), " TP=", DoubleToString(recTP, Digits));
     }
   else
     {
      Print(">>> [HORIZONTAL LINE RECOVERY] Failed to create Recovery Order for Parent #", parentTicket,
            " | Error=", recErr);
      LogEAError(recErr, "OrderSend(HorizRec)", parentTicket, StringFormat("Lots=%.2f Px=%s Cmt=%s", recLots, DoubleToString(livePrice, Digits), recComment));
     }

   return recTicket;
  }
//+------------------------------------------------------------------+
//| CheckNewRedLineCloseBuyAndOpenSell:                              |
//| USER RULE:                                                       |
//| "BUY order is open , new red hotizontal line is started .        |
//|  if any BUY order is open and loss is less than $1Xmultipler     |
//|  close buy open orders . and create NEW sell order SSL Short     |
//|  with LOT 0.02Xmultipler immiditaly without any condition"       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| GetFirstOpenOrderTicket: Returns ticket of FIRST (oldest) open   |
//| order of the specified type (OP_BUY or OP_SELL).                 |
//| USER RULE: "this is only for first order ."                      |
//+------------------------------------------------------------------+
int GetFirstOpenOrderTicket(int targetType)
  {
   int firstTicket = -1;
   datetime earliestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != targetType)
         continue;

      datetime oTime = OrderOpenTime();
      if(earliestTime == 0 || oTime < earliestTime)
        {
         earliestTime = oTime;
         firstTicket = OrderTicket();
        }
      else
         if(oTime == earliestTime)
           {
            // Tie-breaker: lowest ticket number
            if(firstTicket == -1 || OrderTicket() < firstTicket)
              {
               firstTicket = OrderTicket();
              }
           }
     }
   return firstTicket;
  }


//====================================================================
// 4. HORIZONTAL LINE ORDER EXECUTION & ON-CHART DETECTOR
//====================================================================


//+------------------------------------------------------------------+
//| TryModifyOrderStopLossToLinePrice:                               |
//| USER RULE: "BUY order is open and RED horizontal line is started |
//|  . try to modify BUY order stoploss with Line price.             |
//|  same logic apply to GREEN line also"                            |
//| USER UPDATE: "Modify Order Stop Loss with Line Price+50"         |
//| USER UPDATE: "this is only for first order ."                    |
//+------------------------------------------------------------------+
bool TryModifyOrderStopLossToLinePrice(int ticket, double linePrice, string lineName)
  {
   if(linePrice <= 0.0)
      return false;
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;

   int oType        = OrderType();
   double oOpen     = OrderOpenPrice();
   double curSL     = OrderStopLoss();
   double curTP     = OrderTakeProfit();
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;

// USER RULE: If order was secured by Equity Target Hit, reject any loss stoploss
   if(IsEquityHitSecuredOrder(ticket))
     {
      double oOpenPrice = OrderOpenPrice();
      double testSL = (oType == OP_BUY) ? NormalizeDouble(linePrice + ((InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0), Digits)
                      : NormalizeDouble(linePrice + ((InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0), Digits);
      bool isLoss = (oType == OP_BUY && testSL < oOpenPrice) || (oType == OP_SELL && testSL > oOpenPrice);
      if(isLoss)
        {
         Print(">>> [LINE SL MODIFY SKIPPED] Order #", ticket, " was secured by Equity Target Hit.",
               " Proposed Line SL=", DoubleToString(testSL, Digits),
               " is a LOSS Stop Loss (Open=", DoubleToString(oOpenPrice, Digits),
               "). REJECTED: Only profit stoploss is permitted!");
         return false;
        }
     }

// USER RULE: "this is only for first order ."
   if(InpModifyLinePriceSLOnlyFirstOrder)
     {
      int firstTkt = GetFirstOpenOrderTicket(oType);
      if(firstTkt > 0 && ticket != firstTkt)
        {
         Print(">>> [LINE SL MODIFY SKIPPED] Ticket #", ticket, " is NOT the first open ",
               (oType == OP_BUY ? "BUY" : "SELL"), " order (First Order is #", firstTkt,
               "). Rule: Line Price StopLoss modification applies ONLY to the first order!");
         return false;
        }
     }

   RefreshRates();
   double targetSL = 0.0;
   bool canModify = false;
   double offset = (InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0;

   if(oType == OP_BUY)
     {
      // USER RULE: "Modify Order Stop Loss with Line Price+50"
      targetSL = NormalizeDouble(linePrice + offset, Digits);

      if(targetSL >= (Bid - minStopDist))
        {
         // CRITICAL: Stop loss cannot be above or at market price for BUY order!
         // DO NOT force to Bid - minStopDist (which chokes the order to death).
         // Leave existing SL untouched!
         Print(">>> [LINE SL MODIFY SKIPPED] First BUY Order #", ticket, " target (LinePrice+50=", DoubleToString(targetSL, Digits),
               ") is >= Bid (", DoubleToString(Bid, Digits), "). Broker requires SL < Bid - StopLevel. Leaving SL untouched!");
         return false;
        }

      if(targetSL > 0.0)
        {
         // Never widen SL: targetSL must be strictly higher than curSL (or curSL == 0)
         if(curSL == 0.0 || targetSL > (curSL + Point * 5))
           {
            canModify = true;
           }
         else
           {
            Print(">>> [LINE SL MODIFY SKIPPED] First BUY Order #", ticket, " target SL ", DoubleToString(targetSL, Digits),
                  " <= current SL ", DoubleToString(curSL, Digits), ". Keeping higher/tighter current SL!");
            return false;
           }
        }
     }
   else
      if(oType == OP_SELL)
        {
         // USER RULE: "same logic apply to GREEN line also"
         // For SELL order: SL must be strictly above Ask + minStopDist.
         targetSL = NormalizeDouble(linePrice + offset, Digits);

         if(targetSL <= (Ask + minStopDist))
           {
            // CRITICAL: Stop loss cannot be below or at market price for SELL order!
            // DO NOT force to Ask + minStopDist (which chokes the order to death).
            // Leave existing SL untouched!
            Print(">>> [LINE SL MODIFY SKIPPED] First SELL Order #", ticket, " target (LinePrice+50=", DoubleToString(targetSL, Digits),
                  ") is <= Ask (", DoubleToString(Ask, Digits), "). Broker requires SL > Ask + StopLevel. Leaving SL untouched!");
            return false;
           }

         if(targetSL > 0.0)
           {
            // Never widen SL: targetSL must be strictly lower than curSL (or curSL == 0)
            if(curSL == 0.0 || targetSL < (curSL - Point * 5))
              {
               canModify = true;
              }
            else
              {
               Print(">>> [LINE SL MODIFY SKIPPED] First SELL Order #", ticket, " target SL ", DoubleToString(targetSL, Digits),
                     " >= current SL ", DoubleToString(curSL, Digits), ". Keeping lower/tighter current SL!");
               return false;
              }
           }
        }

   if(canModify)
     {
      Print(">>> [LINE SL MODIFY] Modifying FIRST ", (oType == OP_BUY ? "BUY" : "SELL"), " Order #", ticket,
            " SL with ", lineName, " Price+50: NewSL=", DoubleToString(targetSL, Digits),
            " (OldSL=", DoubleToString(curSL, Digits), ", LinePrice=", DoubleToString(linePrice, Digits),
            ", Offset=+$", DoubleToString(offset, 2), ")");
      bool res = SafeOrderModify(ticket, oOpen, targetSL, curTP, 0, (oType == OP_BUY ? clrGold : clrOrange));
      return res;
     }

   return false;
  }
//+------------------------------------------------------------------+
//| GetSmallestLossOrderTicket:                                      |
//| USER RULE: "When horizantal line is started. create recovery     |
//| order which is smallest loss amount. if RED line started create  |
//| immidtate recovery order for lowest open sell order. same logic  |
//| for GREEN horizontal line"                                       |
//| Finds the open market order of targetType with the SMALLEST      |
//| dollar loss amount (closest to $0 loss / breakeven).             |
//| Respects recovery attempt shield and max 1 recovery per parent.  |
//+------------------------------------------------------------------+
//| CheckNewRedLineCloseBuyAndOpenSell:                              |
//| USER RULE:                                                       |
//| "BUY order is open , new red hotizontal line is started .        |
//|  if any BUY order is open and loss is less than $1Xmultipler     |
//|  close buy open orders . and create NEW sell order SSL Short     |
//|  with LOT 0.02Xmultipler immiditaly without any condition"       |
//| USER RULE: "Do not create any HOrizontal line orders when gap    |
//|  between horizontal line and EMAdirection gap is <$200 gap"      |
//| USER RULE: "BUY order is open and RED horizontal line is started |
//|  . try to modify BUY order stoploss with Line price -> this is   |
//|  only for first order ."                                         |
//+------------------------------------------------------------------+
void CheckNewRedLineCloseBuyAndOpenSell()
  {
   if(!InpCloseBuyOnNewEqhRedLine)
      return;




// DISABLED: Dubai Time-of-Day Block (Hours 15, 16, 17)
// datetime dubaiTime1 = TimeCurrent() + (ServerToDubaiOffsetHours * 3600);
// int currentHour1 = TimeHour(dubaiTime1);
// if(currentHour1==15 || currentHour1==16 || currentHour1==17)
//    return;


   if(!EAStartupComplete)
      return;

   SyncHorizontalLineActivationTimers();

// Track initial sweep vs Step-3 retry state while within the valid activation window
   static datetime s_lastHandledRedLineStart   = 0;
   static datetime s_pendingRetryRedLineStart  = 0;

   if(g_lastEqHighPrice <= 0.0 || g_lastEqHighLineStart <= 0)
     {
      if(s_pendingRetryRedLineStart > 0)
        {
         s_lastHandledRedLineStart  = s_pendingRetryRedLineStart;
         s_pendingRetryRedLineStart = 0;
        }
      return;
     }

   datetime curEqhStart = g_lastEqHighLineStart;

   bool initialPhaseDone = (curEqhStart == s_lastHandledRedLineStart);
   bool retryPending     = (curEqhStart == s_pendingRetryRedLineStart);

// If already handled this red horizontal line (and not awaiting a 5-min gap retry), exit immediately
   if(initialPhaseDone && !retryPending)
      return;

// If retrying after a gap/send block, stop immediately if the line has already ended on the chart
   if(retryPending && g_endedEqHighStart == curEqhStart)
     {
      s_lastHandledRedLineStart  = curEqhStart;
      s_pendingRetryRedLineStart = 0;
      return;
     }

// Check if an order was already created for this red line
   if(HasOrderBeenCreatedForLsdLine("EQHR", curEqhStart))
     {
      s_lastHandledRedLineStart  = curEqhStart;
      s_pendingRetryRedLineStart = 0;
      return;
     }

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
   bool blockHorizByAngle = (absEmaAng >= maxHorizAngle);

   if(retryPending && blockHorizByAngle)
     {
      s_lastHandledRedLineStart  = curEqhStart;
      s_pendingRetryRedLineStart = 0;
      g_lastOrderEqHighLineStart = curEqhStart;
      PrintFormat(">>> [RED LINE RETRY CANCELLED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal order creation blocked!", absEmaAng, maxHorizAngle);
      return;
     }

// Confusion Block: While BOTH Red & Green lines are active, wait for single-line confirmation (only when MathAbs(EMA Angle) >= 4.0)
   double minBothLinesAngleRed = (InpBothHorizontalLinesBlockMinEmaAngle > 0.0) ? InpBothHorizontalLinesBlockMinEmaAngle : 4.0;
   if(InpBlockAllOrdersWhenBothHorizontalLinesActive &&
      g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0 &&
      MathAbs(GlobalEmaAngle30) >= minBothLinesAngleRed)
      return;

// USER RULE: Wait 2 to 3 min from line activation before creating horizontal orders (filters out brief/small lines)
   int waitSec        = (InpHorizontalLineMinActiveWaitSeconds > 0) ? InpHorizontalLineMinActiveWaitSeconds : 0;
   int maxDurationSec = (InpHorizontalLineMaxDurationSeconds > 0) ? InpHorizontalLineMaxDurationSeconds : 300;
   int elapsedSec     = GetHorizontalLineActiveWaitElapsedSeconds(true);
   if(elapsedSec < 0)
      return;

   if(waitSec > 0 && elapsedSec < waitSec)
     {
      static datetime s_lastWaitLogEqh = 0;
      if(s_lastWaitLogEqh == 0 || TimeCurrent() - s_lastWaitLogEqh >= 30 || TimeCurrent() < s_lastWaitLogEqh)
        {
         s_lastWaitLogEqh = TimeCurrent();
         Print(">>> [RED LINE WAIT] EQH-R line active (Start=", TimeToStr(curEqhStart, TIME_DATE|TIME_MINUTES),
               ", Price=", DoubleToString(g_lastEqHighPrice, Digits),
               ") | Waiting ", waitSec, "s before horizontal actions (Elapsed=", elapsedSec, "s / ", waitSec, "s)");
        }
      return;
     }

// USER RULE: "Horizontal orders should create within 5 min duration when the Line is initialed . do not create horizontal orders after 5 min"
   if(elapsedSec > maxDurationSec)
     {
      static datetime s_lastExpiredLogEqh = 0;
      if(s_lastExpiredLogEqh == 0 || TimeCurrent() - s_lastExpiredLogEqh >= 30 || TimeCurrent() < s_lastExpiredLogEqh)
        {
         s_lastExpiredLogEqh = TimeCurrent();
         Print(">>> [RED LINE ORDER BLOCKED] EQH-R line activated at ", TimeToStr(g_activeEqHighActivatedAt, TIME_DATE|TIME_MINUTES),
               " is older than max window (Elapsed=", elapsedSec, "s > ", maxDurationSec,
               "s). Rule: Do not create horizontal orders after 5 min!");
        }
      s_lastHandledRedLineStart  = curEqhStart;
      s_pendingRetryRedLineStart = 0;
      g_lastOrderEqHighLineStart = curEqhStart; // Mark line as handled so it never creates later
      return;
     }

   double liveEma  = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double eqhPrice = g_lastEqHighPrice;

   double mult      = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   int    recTicket = -1;

   if(!initialPhaseDone)
     {
      s_pendingRetryRedLineStart = 0;

      // USER RULE: "Do not create any HOrizontal line orders when gap between horizontal line and EMAdirection gap is <$200 gap"
      double minEmaGap   = InpHorizontalLineMinEmaGapRaw;
      double lineEmaGap  = (liveEma > 0.0 && eqhPrice > 0.0) ? MathAbs(eqhPrice - liveEma) : 999999.0;
      double priceEmaGap = (liveEma > 0.0) ? MathAbs(Bid - liveEma) : 999999.0;

      if(minEmaGap > 0.0 && (lineEmaGap < minEmaGap || priceEmaGap < minEmaGap))
        {
         double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
         if(MathAbs(curAngle) > InpHorizontalLineIgnoreEmaGapAngle)
           {
            Print(">>> [RED LINE EMA GAP IGNORED] Gap to EMA is < $", DoubleToString(minEmaGap, 2),
                  " but MathAbs(EMAangle)=", DoubleToString(MathAbs(curAngle), 2), " > ",
                  DoubleToString(InpHorizontalLineIgnoreEmaGapAngle, 1),
                  " deg (USER RULE: Ignore EMA distance filter if MathAbs(EMAangle) > 4). Filter bypassed!");
           }
         else
           {
            static datetime s_lastBlockedLogEqh = 0;
            if(s_lastBlockedLogEqh == 0 || TimeCurrent() - s_lastBlockedLogEqh >= 30 || TimeCurrent() < s_lastBlockedLogEqh)
              {
               s_lastBlockedLogEqh = TimeCurrent();
               Print(">>> [RED LINE ORDER BLOCKED] Gap between EQH-R and EMA is < $", DoubleToString(minEmaGap, 2),
                     " (Line-EMA Gap=$", DoubleToString(lineEmaGap, 2), ", Price-EMA Gap=$", DoubleToString(priceEmaGap, 2),
                     ", EQH-R=", DoubleToString(eqhPrice, Digits), ", EMA200=", DoubleToString(liveEma, Digits),
                     ", MathAbs(EMAangle)=", DoubleToString(MathAbs(curAngle), 2), " <= 4.0). Skipping horizontal line order creation!");
              }
            s_lastHandledRedLineStart  = curEqhStart;
            s_pendingRetryRedLineStart = 0;
            g_lastOrderEqHighLineStart = curEqhStart; // Mark line as handled to enforce 1-order limit
            return;
           }
        }
      // A NEW RED HORIZONTAL LINE HAS STARTED AND QUALIFIES!
      s_lastHandledRedLineStart = curEqhStart;

      double maxLossUSD = (InpCloseBuyMaxLossUSD > 0.0) ? (InpCloseBuyMaxLossUSD * mult) : (1.0 * mult);

      Print(">>> [NEW RED LINE DETECTED] EQH-R line started at ", TimeToStr(curEqhStart, TIME_DATE|TIME_MINUTES),
            " | Price=", DoubleToString(eqhPrice, Digits), " | EMA200=", DoubleToString(liveEma, Digits),
            " | Gap=$", DoubleToString(lineEmaGap, 2), " (>= $", DoubleToString(minEmaGap, 2), " OK) | Closing eligible BUY orders...");

      // Step 1: Scan and delete ALL pending BUY orders immediately (BUYSTOP / BUYLIMIT)
      // UNCONDITIONAL: Must run regardless of whether open market BUY orders exist!
      for(int p = OrdersTotal() - 1; p >= 0; p--)
        {
         if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         int pType = OrderType();
         if(pType == OP_BUYSTOP || pType == OP_BUYLIMIT)
           {
            Print(">>> [NEW RED LINE] Deleting pending BUY order #", OrderTicket(), " Type=", pType, " Lots=", DoubleToString(OrderLots(), 2));
            SafeOrderDelete(OrderTicket(), clrYellow);
           }
        }

      // Step 2: Scan all open market BUY orders
      int openBuyCount = 0;
      double totalBuyPL = 0.0;
      int buyTickets[];
      double buyPLs[];
      ArrayResize(buyTickets, 0);
      ArrayResize(buyPLs, 0);

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(OrderType() != OP_BUY)
            continue;

         openBuyCount++;
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         totalBuyPL += pl;

         int idx = ArraySize(buyTickets);
         ArrayResize(buyTickets, idx + 1);
         ArrayResize(buyPLs, idx + 1);
         buyTickets[idx] = OrderTicket();
         buyPLs[idx]     = pl;
        }

      if(openBuyCount > 0)
        {
         bool closeAll = (totalBuyPL >= -maxLossUSD);

         for(int b = 0; b < ArraySize(buyTickets); b++)
           {
            int tkt = buyTickets[b];
            double pl = buyPLs[b];

            if(closeAll || pl >= -maxLossUSD)
              {
               if(OrderSelect(tkt, SELECT_BY_TICKET, MODE_TRADES))
                 {
                  Print(">>> [NEW RED LINE] Closing BUY Order #", tkt, " Lots=", DoubleToString(OrderLots(), 2),
                        " P/L=$", DoubleToString(pl, 2), " (Loss < $", DoubleToString(maxLossUSD, 2), " limit)");
                  if(!SafeOrderCloseMarket(tkt, OrderLots(), Slippage, clrYellow))
                    {
                     bool closeRes = OrderClose(tkt, OrderLots(), Bid, Slippage, clrYellow);
                    }
                 }
              }
            else
              {
               Print(">>> [NEW RED LINE] BUY Order #", tkt, " kept open: P/L=$", DoubleToString(pl, 2),
                     " (Loss exceeds $", DoubleToString(maxLossUSD, 2), " limit)");
              }
           }
        }

      // Step 2b: USER RULE: "BUY order is open and RED horizontal line is started . try to modify BUY order stoploss with Line price -> this is only for first order ."
      if(InpModifyOppositeOrderSLToLinePrice && eqhPrice > 0.0)
        {
         int firstBuyTkt = GetFirstOpenOrderTicket(OP_BUY);
         if(firstBuyTkt > 0)
           {
            TryModifyOrderStopLossToLinePrice(firstBuyTkt, eqhPrice, "EQH-R Red Line");
           }
        }

      // Step 2b-2: USER RULE: "RED horizontal line is started then BUY orders are in profit >$0 then modify all open BUY orders stoploss with live price"
      ManageHorizontalLineProfitLiveStopLoss();

      // Step 2c: USER RULE: "When horizantal line is started. create recovery order which is smallest loss amount.
      // if RED line started create immidtate recovery order for lowest open sell order. same logic for GREEN horizontal line"
      if(!blockHorizByAngle && InpEnableHorizontalLineRecovery)
        {
         int parentSellTicket = GetSmallestLossOrderTicket(OP_SELL);
         if(parentSellTicket > 0)
           {
            recTicket = CreateHorizontalLineRecoveryOrder(parentSellTicket, OP_SELL, eqhPrice);
            if(recTicket > 0)
              {
               g_lastOrderEqHighLineStart = curEqhStart; // Enforce 1-order-per-line limit
               g_lastEqhSellOrderTicket   = recTicket;
              }
           }
        }
     }

// Step 3: If no recovery order was created (or if InpOpenLineOrderIfRecoveryCreated is true):
// Create NEW sell order "EQH-R Short" with LOT InpNewEqhSellOrderLotBase * multiplier
// Retries while within the 5-minute window if blocked by same-type gap or OrderSend failure.
   if(blockHorizByAngle)
     {
      static datetime s_lastRedBlockLog = 0;
      if(s_lastRedBlockLog == 0 || TimeCurrent() - s_lastRedBlockLog >= 30 || TimeCurrent() < s_lastRedBlockLog)
        {
         s_lastRedBlockLog = TimeCurrent();
         PrintFormat(">>> [RED LINE ORDER CREATION BLOCKED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal order creation blocked!", absEmaAng, maxHorizAngle);
        }
      g_lastOrderEqHighLineStart = curEqhStart;
      s_pendingRetryRedLineStart = 0;
     }
   else if(retryPending || recTicket <= 0 || InpOpenLineOrderIfRecoveryCreated)
     {
      double baseLot = (InpNewEqhSellOrderLotBase > 0.0) ? InpNewEqhSellOrderLotBase : 0.06;
      double sellLot = NormalizeLots(baseLot * mult);

      RefreshRates();
      if(!HasMinimumHorizontalOrderGap(OP_SELL, Bid, InpHorizontalOrderSameTypeMinGapUSD))
        {
         s_pendingRetryRedLineStart = curEqhStart;
         return;
        }

      int tkt = SendLsdRedLineSellOrder(sellLot, eqhPrice);
      if(tkt > 0)
        {
         g_lastOrderEqHighLineStart = curEqhStart; // Enforce 1-order-per-line limit
         g_lastEqhSellOrderTicket   = tkt;
         s_pendingRetryRedLineStart = 0;
        }
      else
        {
         s_pendingRetryRedLineStart = curEqhStart;
        }
     }
  }

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| SendLsdGreenLineBuyOrder:                                        |
//| Sends immediate market BUY order ("EQH-G Long") without any        |
//| condition, with lot 0.02 * multiplier.                           |
//+------------------------------------------------------------------+
int SendLsdGreenLineBuyOrder(double buyLot, double linePrice = 0.0)
  {
   // USER RULE: "do not create any horizontal order when mathabs emaangle is more than >=4"
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
   if(absEmaAng >= maxHorizAngle)
     {
      PrintFormat(">>> [EQH-G LONG BLOCKED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal orders strictly blocked!",
                  absEmaAng, maxHorizAngle);
      return -1;
     }

   RefreshRates();
   if(IsBlockedByActiveHorizontalLines(OP_BUY, Ask, "EQH-G Long"))
      return -1;
   if(!HasMinimumHorizontalOrderGap(OP_BUY, Ask, InpHorizontalOrderSameTypeMinGapUSD))
      return -1;
   double slDistance  = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance  = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;

   double stopLoss = 0.0;
   double offset   = (InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0;

// USER RULE: First order after horizontal line is started: SL = Line Price - 50
   if(linePrice > 0.0)
     {
      double lineSL = NormalizeDouble(linePrice - offset, Digits);
      if(lineSL < (Bid - minStopDist))
         stopLoss = lineSL;
      else
         if(slDistance > 0.0)
            stopLoss = NormalizeDouble(Ask - slDistance, Digits);
     }
   else
      if(slDistance > 0.0)
        {
         stopLoss = NormalizeDouble(Ask - slDistance, Digits);
        }

   double takeProfit = (tpDistance > 0.0) ? NormalizeDouble(Ask + tpDistance, Digits) : 0.0;

   ResetLastError();
   int finalErr = 0;
   int ticket = OrderSend(Symbol(), OP_BUY, buyLot, Ask, Slippage, stopLoss, takeProfit, "EQH-G Long", MagicNumber, 0, BuyColor);
   if(ticket < 0)
     {
      finalErr = GetLastError();
      // Error 130 (ERR_INVALID_STOPS) on ECN brokers: send with 0 SL/TP first
      if(finalErr == 130 || finalErr == 4107)
        {
         ResetLastError();
         ticket = OrderSend(Symbol(), OP_BUY, buyLot, Ask, Slippage, 0, 0, "EQH-G Long", MagicNumber, 0, BuyColor);
         if(ticket < 0)
            finalErr = GetLastError();
         else
            if(stopLoss > 0.0 || takeProfit > 0.0)
               SafeOrderModify(ticket, OrderOpenPrice(), stopLoss, takeProfit, 0, BuyColor);
        }
     }

   if(ticket > 0)
     {
      InvalidateTotalEAOrdersCache();
      OrderCreatedThisCandle = true;
      LastOrderCandleTime    = Time[0];
      Print(">>> [NEW GREEN LINE] Successfully opened immediate market BUY order Ticket #", ticket,
            " 'EQH-G Long' Lots=", DoubleToString(buyLot, 2), " OpenPrice=", DoubleToString(Ask, Digits),
            " SL=", DoubleToString(stopLoss, Digits), " (LinePrice=", DoubleToString(linePrice, Digits),
            ", Line-50=", DoubleToString(linePrice - offset, Digits), ") TP=", DoubleToString(takeProfit, Digits));
     }
   else
     {
      Print(">>> [NEW GREEN LINE] OrderSend OP_BUY 'EQH-G Long' failed. Error=", finalErr);
      LogEAError(finalErr, "OrderSend(EQH-G Long)", -1, StringFormat("Lots=%.2f Ask=%s SL=%s TP=%s", buyLot, DoubleToString(Ask, Digits), DoubleToString(stopLoss, Digits), DoubleToString(takeProfit, Digits)));
     }
   return ticket;
  }

//+------------------------------------------------------------------+
//| CheckNewGreenLineCloseSellAndOpenBuy:                            |
//| USER RULE:                                                       |
//| "SELL order is open , new green hotizontal line is started .      |
//|  if any SELL order is open and loss is less than $1Xmultipler    |
//|  close sell open orders . and create NEW buy order SSL Long      |
//|  with LOT 0.02Xmultipler immiditaly without any condition"       |
//+------------------------------------------------------------------+
void CheckNewGreenLineCloseSellAndOpenBuy()
  {
   if(!InpCloseSellOnNewEqlGreenLine)
      return;
   if(!EAStartupComplete)
      return;


// DISABLED: Dubai Time-of-Day Block (Hours 15, 16, 17)
// datetime dubaiTime1 = TimeCurrent() + (ServerToDubaiOffsetHours * 3600);
// int currentHour1 = TimeHour(dubaiTime1);
// if(currentHour1==15 || currentHour1==16 || currentHour1==17)
//    return;

   SyncHorizontalLineActivationTimers();

// Track initial sweep vs Step-3 retry state while within the valid activation window
   static datetime s_lastHandledGreenLineStart   = 0;
   static datetime s_pendingRetryGreenLineStart  = 0;

   if(g_lastEqLowPrice <= 0.0 || g_lastEqLowLineStart <= 0)
     {
      if(s_pendingRetryGreenLineStart > 0)
        {
         s_lastHandledGreenLineStart  = s_pendingRetryGreenLineStart;
         s_pendingRetryGreenLineStart = 0;
        }
      return;
     }

   datetime curEqlStart = g_lastEqLowLineStart;

   bool initialPhaseDone = (curEqlStart == s_lastHandledGreenLineStart);
   bool retryPending     = (curEqlStart == s_pendingRetryGreenLineStart);

// If already handled this green horizontal line (and not awaiting a 5-min gap retry), exit immediately
   if(initialPhaseDone && !retryPending)
      return;

// If retrying after a gap/send block, stop immediately if the line has already ended on the chart
   if(retryPending && g_endedEqLowStart == curEqlStart)
     {
      s_lastHandledGreenLineStart  = curEqlStart;
      s_pendingRetryGreenLineStart = 0;
      return;
     }

// Check if an order was already created for this green line
   if(HasOrderBeenCreatedForLsdLine("EQHG", curEqlStart))
     {
      s_lastHandledGreenLineStart  = curEqlStart;
      s_pendingRetryGreenLineStart = 0;
      return;
     }

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
   bool blockHorizByAngle = (absEmaAng >= maxHorizAngle);

   if(retryPending && blockHorizByAngle)
     {
      s_lastHandledGreenLineStart  = curEqlStart;
      s_pendingRetryGreenLineStart = 0;
      g_lastOrderEqLowLineStart    = curEqlStart;
      PrintFormat(">>> [GREEN LINE RETRY CANCELLED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal order creation blocked!", absEmaAng, maxHorizAngle);
      return;
     }

// Confusion Block: While BOTH Red & Green lines are active, wait for single-line confirmation (only when MathAbs(EMA Angle) >= 4.0)
   double minBothLinesAngleGreen = (InpBothHorizontalLinesBlockMinEmaAngle > 0.0) ? InpBothHorizontalLinesBlockMinEmaAngle : 4.0;
   if(InpBlockAllOrdersWhenBothHorizontalLinesActive &&
      g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 &&
      MathAbs(GlobalEmaAngle30) >= minBothLinesAngleGreen)
      return;

// USER RULE: Wait 2 to 3 min from line activation before creating horizontal orders (filters out brief/small lines)
   int waitSec        = (InpHorizontalLineMinActiveWaitSeconds > 0) ? InpHorizontalLineMinActiveWaitSeconds : 0;
   int maxDurationSec = (InpHorizontalLineMaxDurationSeconds > 0) ? InpHorizontalLineMaxDurationSeconds : 300;
   int elapsedSec     = GetHorizontalLineActiveWaitElapsedSeconds(false);
   if(elapsedSec < 0)
      return;

   if(waitSec > 0 && elapsedSec < waitSec)
     {
      static datetime s_lastWaitLogEql = 0;
      if(s_lastWaitLogEql == 0 || TimeCurrent() - s_lastWaitLogEql >= 30 || TimeCurrent() < s_lastWaitLogEql)
        {
         s_lastWaitLogEql = TimeCurrent();
         Print(">>> [GREEN LINE WAIT] EQH-G line active (Start=", TimeToStr(curEqlStart, TIME_DATE|TIME_MINUTES),
               ", Price=", DoubleToString(g_lastEqLowPrice, Digits),
               ") | Waiting ", waitSec, "s before horizontal actions (Elapsed=", elapsedSec, "s / ", waitSec, "s)");
        }
      return;
     }

// USER RULE: "Horizontal orders should create within 5 min duration when the Line is initialed . do not create horizontal orders after 5 min"
   if(elapsedSec > maxDurationSec)
     {
      static datetime s_lastExpiredLogEql = 0;
      if(s_lastExpiredLogEql == 0 || TimeCurrent() - s_lastExpiredLogEql >= 30 || TimeCurrent() < s_lastExpiredLogEql)
        {
         s_lastExpiredLogEql = TimeCurrent();
         Print(">>> [GREEN LINE ORDER BLOCKED] EQH-G line activated at ", TimeToStr(g_activeEqLowActivatedAt, TIME_DATE|TIME_MINUTES),
               " is older than max window (Elapsed=", elapsedSec, "s > ", maxDurationSec,
               "s). Rule: Do not create horizontal orders after 5 min!");
        }
      s_lastHandledGreenLineStart  = curEqlStart;
      s_pendingRetryGreenLineStart = 0;
      g_lastOrderEqLowLineStart    = curEqlStart; // Mark line as handled so it never creates later
      return;
     }

   double liveEma  = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double eqlPrice = g_lastEqLowPrice;

   double mult      = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   int    recTicket = -1;

   if(!initialPhaseDone)
     {
      s_pendingRetryGreenLineStart = 0;

      // USER RULE: "Do not create any HOrizontal line orders when gap between horizontal line and EMAdirection gap is <$200 gap"
      double minEmaGap   = InpHorizontalLineMinEmaGapRaw;
      double lineEmaGap  = (liveEma > 0.0 && eqlPrice > 0.0) ? MathAbs(eqlPrice - liveEma) : 999999.0;
      double priceEmaGap = (liveEma > 0.0) ? MathAbs(Ask - liveEma) : 999999.0;

      if(minEmaGap > 0.0 && (lineEmaGap < minEmaGap || priceEmaGap < minEmaGap))
        {
         double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
         if(MathAbs(curAngle) > InpHorizontalLineIgnoreEmaGapAngle)
           {
            Print(">>> [GREEN LINE EMA GAP IGNORED] Gap to EMA is < $", DoubleToString(minEmaGap, 2),
                  " but MathAbs(EMAangle)=", DoubleToString(MathAbs(curAngle), 2), " > ",
                  DoubleToString(InpHorizontalLineIgnoreEmaGapAngle, 1),
                  " deg (USER RULE: Ignore EMA distance filter if MathAbs(EMAangle) > 4). Filter bypassed!");
           }
         else
           {
            static datetime s_lastBlockedLogEql = 0;
            if(s_lastBlockedLogEql == 0 || TimeCurrent() - s_lastBlockedLogEql >= 30 || TimeCurrent() < s_lastBlockedLogEql)
              {
               s_lastBlockedLogEql = TimeCurrent();
               Print(">>> [GREEN LINE ORDER BLOCKED] Gap between EQH-G and EMA is < $", DoubleToString(minEmaGap, 2),
                     " (Line-EMA Gap=$", DoubleToString(lineEmaGap, 2), ", Price-EMA Gap=$", DoubleToString(priceEmaGap, 2),
                     ", EQH-G=", DoubleToString(eqlPrice, Digits), ", EMA200=", DoubleToString(liveEma, Digits),
                     ", MathAbs(EMAangle)=", DoubleToString(MathAbs(curAngle), 2), " <= 4.0). Skipping horizontal line order creation!");
              }
            s_lastHandledGreenLineStart  = curEqlStart;
            s_pendingRetryGreenLineStart = 0;
            g_lastOrderEqLowLineStart    = curEqlStart; // Mark line as handled to enforce 1-order limit
            return;
           }
        }
      // A NEW GREEN HORIZONTAL LINE HAS STARTED AND QUALIFIES!
      s_lastHandledGreenLineStart = curEqlStart;

      double maxLossUSD = (InpCloseSellMaxLossUSD > 0.0) ? (InpCloseSellMaxLossUSD * mult) : (1.0 * mult);

      Print(">>> [NEW GREEN LINE DETECTED] EQH-G line started at ", TimeToStr(curEqlStart, TIME_DATE|TIME_MINUTES),
            " | Price=", DoubleToString(eqlPrice, Digits), " | EMA200=", DoubleToString(liveEma, Digits),
            " | Gap=$", DoubleToString(lineEmaGap, 2), " (>= $", DoubleToString(minEmaGap, 2), " OK) | Closing eligible SELL orders...");

      // Step 1: Scan and delete ALL pending SELL orders immediately (SELLSTOP / SELLLIMIT)
      // UNCONDITIONAL: Must run regardless of whether open market SELL orders exist!
      for(int p = OrdersTotal() - 1; p >= 0; p--)
        {
         if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         int pType = OrderType();
         if(pType == OP_SELLSTOP || pType == OP_SELLLIMIT)
           {
            Print(">>> [NEW GREEN LINE] Deleting pending SELL order #", OrderTicket(), " Type=", pType, " Lots=", DoubleToString(OrderLots(), 2));
            SafeOrderDelete(OrderTicket(), clrYellow);
           }
        }

      // Step 2: Scan all open market SELL orders
      int openSellCount = 0;
      double totalSellPL = 0.0;
      int sellTickets[];
      double sellPLs[];
      ArrayResize(sellTickets, 0);
      ArrayResize(sellPLs, 0);

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(OrderType() != OP_SELL)
            continue;

         openSellCount++;
         double pl = OrderProfit() + OrderSwap() + OrderCommission();
         totalSellPL += pl;

         int idx = ArraySize(sellTickets);
         ArrayResize(sellTickets, idx + 1);
         ArrayResize(sellPLs, idx + 1);
         sellTickets[idx] = OrderTicket();
         sellPLs[idx]     = pl;
        }

      if(openSellCount > 0)
        {
         bool closeAll = (totalSellPL >= -maxLossUSD);

         for(int s = 0; s < ArraySize(sellTickets); s++)
           {
            int tkt = sellTickets[s];
            double pl = sellPLs[s];

            if(closeAll || pl >= -maxLossUSD)
              {
               if(OrderSelect(tkt, SELECT_BY_TICKET, MODE_TRADES))
                 {
                  Print(">>> [NEW GREEN LINE] Closing SELL Order #", tkt, " Lots=", DoubleToString(OrderLots(), 2),
                        " P/L=$", DoubleToString(pl, 2), " (Loss < $", DoubleToString(maxLossUSD, 2), " limit)");
                  if(!SafeOrderCloseMarket(tkt, OrderLots(), Slippage, clrYellow))
                    {
                     bool closeRes = OrderClose(tkt, OrderLots(), Ask, Slippage, clrYellow);
                    }
                 }
              }
            else
              {
               Print(">>> [NEW GREEN LINE] SELL Order #", tkt, " kept open: P/L=$", DoubleToString(pl, 2),
                     " (Loss exceeds $", DoubleToString(maxLossUSD, 2), " limit)");
              }
           }
        }

      // Step 2b: USER RULE: "same logic apply to GREEN line also -> this is only for first order ."
      if(InpModifyOppositeOrderSLToLinePrice && eqlPrice > 0.0)
        {
         int firstSellTkt = GetFirstOpenOrderTicket(OP_SELL);
         if(firstSellTkt > 0)
           {
            TryModifyOrderStopLossToLinePrice(firstSellTkt, eqlPrice, "EQH-G Green Line");
           }
        }

      // Step 2b-2: USER RULE: "GREEEN horizontal line is started then SELL orders are in profit >$0 then modify all open SELL orders stoploss with liveprice"
      ManageHorizontalLineProfitLiveStopLoss();

      // Step 2c: USER RULE: "When horizantal line is started. create recovery order which is smallest loss amount.
      // if RED line started create immidtate recovery order for lowest open sell order. same logic for GREEN horizontal line"
      if(!blockHorizByAngle && InpEnableHorizontalLineRecovery)
        {
         int parentBuyTicket = GetSmallestLossOrderTicket(OP_BUY);
         if(parentBuyTicket > 0)
           {
            recTicket = CreateHorizontalLineRecoveryOrder(parentBuyTicket, OP_BUY, eqlPrice);
            if(recTicket > 0)
              {
               g_lastOrderEqLowLineStart = curEqlStart; // Enforce 1-order-per-line limit
               g_lastEqlBuyOrderTicket   = recTicket;
              }
           }
        }
     }

// Step 3: If no recovery order was created (or if InpOpenLineOrderIfRecoveryCreated is true):
// Create NEW buy order "EQH-G Long" with LOT InpNewEqlBuyOrderLotBase * multiplier
// Retries while within the 5-minute window if blocked by same-type gap or OrderSend failure.
   if(blockHorizByAngle)
     {
      static datetime s_lastGreenBlockLog = 0;
      if(s_lastGreenBlockLog == 0 || TimeCurrent() - s_lastGreenBlockLog >= 30 || TimeCurrent() < s_lastGreenBlockLog)
        {
         s_lastGreenBlockLog = TimeCurrent();
         PrintFormat(">>> [GREEN LINE ORDER CREATION BLOCKED] MathAbs(EMA Angle)=%.2f >= %.1f deg (Strategy 2: Strong Trend). Horizontal order creation blocked!", absEmaAng, maxHorizAngle);
        }
      g_lastOrderEqLowLineStart    = curEqlStart; // Mark line as handled so it never creates later
      s_pendingRetryGreenLineStart = 0;
     }
   else if(retryPending || recTicket <= 0 || InpOpenLineOrderIfRecoveryCreated)
     {
      double baseLot = (InpNewEqlBuyOrderLotBase > 0.0) ? InpNewEqlBuyOrderLotBase : 0.06;
      double buyLot = NormalizeLots(baseLot * mult);

      RefreshRates();
      if(!HasMinimumHorizontalOrderGap(OP_BUY, Ask, InpHorizontalOrderSameTypeMinGapUSD))
        {
         s_pendingRetryGreenLineStart = curEqlStart;
         return;
        }

      int tkt = SendLsdGreenLineBuyOrder(buyLot, eqlPrice);
      if(tkt > 0)
        {
         g_lastOrderEqLowLineStart    = curEqlStart; // Enforce 1-order-per-line limit
         g_lastEqlBuyOrderTicket      = tkt;
         s_pendingRetryGreenLineStart = 0;
        }
      else
        {
         s_pendingRetryGreenLineStart = curEqlStart;
        }
     }
  }

//| ManageHorizontalOrderEndedStopLoss:                              |
//| USER RULE:                                                       |
//| "Hotizontal line is started , Horizontal LOT 0.02 order is open, |
//|  but, horizontal line is ended but Horizontal LOT order is still |
//|  open then modify Horizontal LOT order with stoploss $50 gap"    |
//+------------------------------------------------------------------+
void ManageHorizontalOrderEndedStopLoss()
  {
   if(!InpEnableModifySLOnLineEnded)
      return;
   if(!EAStartupComplete)
      return;

   double gap = (InpHorizontalLineEndedSLGapRaw > 0.0) ? InpHorizontalLineEndedSLGapRaw : 50.0;
   double minStopDist = GetRequiredStopDistance();
   if(gap < minStopDist)
      gap = minStopDist;

// 1. Check if active EQH-R (Red line) is still active on chart
   bool isEqhLineActive = false;
   datetime activeEqhStart = GetLsdSweepActiveEqhLineStart();
   if(activeEqhStart > 0 && activeEqhStart == g_lastOrderEqHighLineStart)
     {
      if(IsLsdSweepRedLinePresent() || GetEQR_R_Price(true) > 0.0)
         isEqhLineActive = true;
     }

// 2. Check if active EQH-G (Green line) is still active on chart
   bool isEqlLineActive = false;
   datetime activeEqlStart = GetLsdSweepActiveEqlLineStart();
   if(activeEqlStart > 0 && activeEqlStart == g_lastOrderEqLowLineStart)
     {
      if(IsLsdSweepGreenLinePresent() || GetEQR_G_Price(true) > 0.0)
         isEqlLineActive = true;
     }

   bool eqhLineEnded = (!isEqhLineActive && g_lastOrderEqHighLineStart > 0);
   bool eqlLineEnded = (!isEqlLineActive && g_lastOrderEqLowLineStart > 0);

// One-time modification guard per ended line
   static datetime s_lastEndedModifiedEqhLine = 0;
   static datetime s_lastEndedModifiedEqlLine = 0;

   if(eqhLineEnded && s_lastEndedModifiedEqhLine == g_lastOrderEqHighLineStart)
      eqhLineEnded = false;
   if(eqlLineEnded && s_lastEndedModifiedEqlLine == g_lastOrderEqLowLineStart)
      eqlLineEnded = false;

// If neither line has ended with an open order tracked, nothing to do
   if(!eqhLineEnded && !eqlLineEnded)
      return;

   RefreshRates();

// 3. Scan open market orders in MODE_TRADES
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
      string comm = OrderComment();
      if(IsAnyRecoveryOrder(tkt, comm))
         continue; // Recovery orders managed exclusively by ManageRecoveryBasket
      bool isOrderLineEnded = false;
      string lineTypeStr = "";

      // Check if order belongs to EQH-R line and EQH-R has ended
      if(eqhLineEnded && oType == OP_SELL)
        {
         if(g_lastEqhSellOrderTicket > 0 && tkt == g_lastEqhSellOrderTicket)
           {
            isOrderLineEnded = true;
            lineTypeStr = "EQH-R Sell Order #" + IntegerToString(tkt);
           }
         else
            if(StringFind(comm, "FLIPBasketSupport_LSD_EQHR") >= 0)
              {
               isOrderLineEnded = true;
               lineTypeStr = "EQH-R Support";
              }
            else
               if(StringFind(comm, "EQH-R Short") >= 0 && MathAbs(OrderOpenTime() - g_lastOrderEqHighLineStart) <= 300)
                 {
                  isOrderLineEnded = true;
                  lineTypeStr = "EQH-R Short";
                 }
        }

      // Check if order belongs to EQH-G line and EQH-G has ended
      if(eqlLineEnded && oType == OP_BUY)
        {
         if(g_lastEqlBuyOrderTicket > 0 && tkt == g_lastEqlBuyOrderTicket)
           {
            isOrderLineEnded = true;
            lineTypeStr = "EQH-G Buy Order #" + IntegerToString(tkt);
           }
         else
            if(StringFind(comm, "FLIPBasketSupport_LSD_EQHG") >= 0)
              {
               isOrderLineEnded = true;
               lineTypeStr = "EQH-G Support";
              }
            else
               if((StringFind(comm, "EQH-G") >= 0 || StringFind(comm, "SSL Long") >= 0) && MathAbs(OrderOpenTime() - g_lastOrderEqLowLineStart) <= 300)
                 {
                  isOrderLineEnded = true;
                  lineTypeStr = "EQH-G Long";
                 }
        }

      if(!isOrderLineEnded)
         continue;

      if(IsEquityHitSecuredOrder(tkt))
        {
         double oOpenPrice = OrderOpenPrice();
         double testSL = (oType == OP_BUY) ? NormalizeDouble(Bid - gap, Digits) : NormalizeDouble(Ask + gap, Digits);
         bool isLoss = (oType == OP_BUY && testSL < oOpenPrice) || (oType == OP_SELL && testSL > oOpenPrice);
         if(isLoss)
           {
            Print(">>> [HORIZONTAL LINE ENDED SKIPPED] Order #", tkt, " was secured by Equity Target Hit.",
                  " Proposed Ended SL=", DoubleToString(testSL, Digits),
                  " is a LOSS Stop Loss (Open=", DoubleToString(oOpenPrice, Digits),
                  "). Preserving secured StopLoss!");
            continue;
           }
        }

      double curSL = OrderStopLoss();
      double newSL = 0.0;

      if(oType == OP_BUY)
        {
         newSL = NormalizeDouble(Bid - gap, Digits);
         if(newSL <= 0.0)
            continue;

         if(Bid - newSL < minStopDist)
            newSL = NormalizeDouble(Bid - minStopDist, Digits);

         if(curSL > 0.0)
           {
            // Never widen SL: newSL must be strictly higher than curSL
            if(curSL >= newSL)
               continue;
            // Avoid modifying for tiny jitter under 5 points
            if(MathAbs(newSL - curSL) < Point * 5)
               continue;
           }
        }
      else
         if(oType == OP_SELL)
           {
            newSL = NormalizeDouble(Ask + gap, Digits);
            if(newSL <= 0.0)
               continue;

            if(newSL - Ask < minStopDist)
               newSL = NormalizeDouble(Ask + minStopDist, Digits);

            if(curSL > 0.0)
              {
               // Never widen SL: newSL must be strictly lower than curSL
               if(curSL <= newSL)
                  continue;
               // Avoid modifying for tiny jitter under 5 points
               if(MathAbs(curSL - newSL) < Point * 5)
                  continue;
              }
           }

      Print(">>> [HORIZONTAL LINE ENDED] ", lineTypeStr, " Order #", tkt, " Lots=", DoubleToString(OrderLots(), 2),
            " is open but line has ended. Modifying SL to $", DoubleToString(gap, 2), " gap from market: NewSL=",
            DoubleToString(newSL, Digits), " (OldSL=", DoubleToString(curSL, Digits), ")");

      bool modOk = SafeOrderModify(tkt, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);
      if(modOk)
        {
         if(isOrderLineEnded && eqhLineEnded)
            s_lastEndedModifiedEqhLine = g_lastOrderEqHighLineStart;
         if(isOrderLineEnded && eqlLineEnded)
            s_lastEndedModifiedEqlLine = g_lastOrderEqLowLineStart;
        }
     }
  }

//+------------------------------------------------------------------+
//| Check1HourHorizontalLinePendingOrders:                           |
//| USER RULE:                                                       |
//| "if any horizontal line is live more than 1 hour and tick live   |
//|  price is near $50 then create Horizonal order.                  |
//|  if red line then create sell horizontal pending order,          |
//|  if green line create buy horizontal pending order"              |
//+------------------------------------------------------------------+
void Check1HourHorizontalLinePendingOrders()
  {
   if(!InpEnable1HourHLinePendingOrder)
      return;
   if(!EAStartupComplete)
      return;

   // USER RULE: "if any horizontal line is live more than 1 hour and tick live price is near $50 ->ignore ema angle condition this situvation"
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   if(!InpHLine1HourIgnoreEmaAngle)
     {
      double absEmaAng = MathAbs(curEmaAng);
      double maxHorizAngle = (InpHorizontalOrderMaxEmaAngle > 0.0) ? InpHorizontalOrderMaxEmaAngle : 4.0;
      if(absEmaAng >= maxHorizAngle)
         return;
     }

   RefreshRates();
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;

   double mult             = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double nearThresholdUSD = (InpHLine1HourNearPriceUSD > 0.0) ? InpHLine1HourNearPriceUSD : 50.0;
   int    minDurationSec   = (InpHLine1HourMinDurationSeconds > 0) ? InpHLine1HourMinDurationSeconds : 3600;
   double slOffset         = (InpHLine1HourSLOffsetUSD > 0.0) ? InpHLine1HourSLOffsetUSD : 50.0;
   double tpDist           = (InpHLine1HourTPRawUSD > 0.0) ? InpHLine1HourTPRawUSD : 500.0;
   double defaultSLDist    = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;

   // ----------------------------------------------------------------
   // Tracking variables (enforces strictly 1 pending order per line lifetime)
   // ----------------------------------------------------------------
   static datetime s_last1hPendingRedLineStart   = 0;
   static int      s_last1hPendingRedTicket      = 0;
   static datetime s_last1hPendingGreenLineStart = 0;
   static int      s_last1hPendingGreenTicket    = 0;

   bool hasActiveRed   = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 && g_endedEqHighStart != g_lastEqHighLineStart);
   bool hasActiveGreen = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0 && g_endedEqLowStart  != g_lastEqLowLineStart);

   // ----------------------------------------------------------------
   // Cleanup unfilled pending orders when line ends
   // ----------------------------------------------------------------
   if(InpDelete1HourPendingOnLineEnded)
     {
      if(!hasActiveRed && s_last1hPendingRedTicket > 0)
        {
         if(OrderSelect(s_last1hPendingRedTicket, SELECT_BY_TICKET, MODE_TRADES))
           {
            int pType = OrderType();
            if(pType == OP_SELLLIMIT || pType == OP_SELLSTOP)
              {
               PrintFormat(">>> [1H HLINE ENDED] Deleting unfilled Red line Sell pending order #%d (Type=%d, Entry=%.2f, LineStart=%s)",
                           s_last1hPendingRedTicket, pType, OrderOpenPrice(), TimeToString(s_last1hPendingRedLineStart, TIME_DATE|TIME_MINUTES));
               SafeOrderDelete(s_last1hPendingRedTicket, clrRed);
              }
           }
         s_last1hPendingRedTicket = 0;
        }

      if(!hasActiveGreen && s_last1hPendingGreenTicket > 0)
        {
         if(OrderSelect(s_last1hPendingGreenTicket, SELECT_BY_TICKET, MODE_TRADES))
           {
            int pType = OrderType();
            if(pType == OP_BUYLIMIT || pType == OP_BUYSTOP)
              {
               PrintFormat(">>> [1H HLINE ENDED] Deleting unfilled Green line Buy pending order #%d (Type=%d, Entry=%.2f, LineStart=%s)",
                           s_last1hPendingGreenTicket, pType, OrderOpenPrice(), TimeToString(s_last1hPendingGreenLineStart, TIME_DATE|TIME_MINUTES));
               SafeOrderDelete(s_last1hPendingGreenTicket, clrGreen);
              }
           }
         s_last1hPendingGreenTicket = 0;
        }
     }

   // ----------------------------------------------------------------
   // 1. RED LINE: Resistance -> SELL pending order
   // ----------------------------------------------------------------
   if(hasActiveRed)
     {
      int redElapsedSec = (int)(TimeCurrent() - g_lastEqHighLineStart);
      if(redElapsedSec >= minDurationSec && s_last1hPendingRedLineStart != g_lastEqHighLineStart)
        {
         double distRed = MathAbs(Bid - g_lastEqHighPrice);
         if(distRed <= nearThresholdUSD)
           {
            // Verify no open 1-hour pending Sell order currently exists
            bool hasExistingRedPending = false;
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               int oType = OrderType();
               if(oType == OP_SELLLIMIT || oType == OP_SELLSTOP)
                 {
                  if(StringFind(OrderComment(), "EQH-R 1h") >= 0)
                    {
                     hasExistingRedPending = true;
                     s_last1hPendingRedTicket = OrderTicket();
                     s_last1hPendingRedLineStart = g_lastEqHighLineStart;
                     break;
                    }
                 }
              }

            if(!hasExistingRedPending)
              {
               int pendingType = OP_SELLLIMIT;
               double targetPrice = NormalizeDouble(g_lastEqHighPrice, Digits);

               if(Bid < g_lastEqHighPrice)
                 {
                  pendingType = OP_SELLLIMIT;
                  if((targetPrice - Bid) < minStopDist)
                     targetPrice = NormalizeDouble(Bid + minStopDist, Digits);
                 }
               else
                 {
                  pendingType = OP_SELLSTOP;
                  if((Bid - targetPrice) < minStopDist)
                     targetPrice = NormalizeDouble(Bid - minStopDist, Digits);
                 }

               double stopLoss = 0.0;
               double lineSL = NormalizeDouble(targetPrice + slOffset, Digits);
               if(lineSL > (Ask + minStopDist))
                  stopLoss = lineSL;
               else
                  if(defaultSLDist > 0.0)
                     stopLoss = NormalizeDouble(targetPrice + defaultSLDist, Digits);

               double takeProfit = (tpDist > 0.0) ? NormalizeDouble(targetPrice - tpDist, Digits) : 0.0;

               double baseLot = (InpHLine1HourSellLotBase > 0.0) ? InpHLine1HourSellLotBase : 0.03;
               double sellLot = NormalizeLots(baseLot * mult);

               ResetLastError();
               int tkt = OrderSend(Symbol(), pendingType, sellLot, targetPrice, Slippage, stopLoss, takeProfit, "EQH-R 1h Pending", MagicNumber, 0, SellColor);
               if(tkt < 0)
                 {
                  int err = GetLastError();
                  if(err == 130 || err == 4107)
                    {
                     ResetLastError();
                     tkt = OrderSend(Symbol(), pendingType, sellLot, targetPrice, Slippage, 0, 0, "EQH-R 1h Pending", MagicNumber, 0, SellColor);
                     if(tkt > 0 && (stopLoss > 0.0 || takeProfit > 0.0))
                        SafeOrderModify(tkt, targetPrice, stopLoss, takeProfit, 0, SellColor);
                    }
                 }

               if(tkt > 0)
                 {
                  s_last1hPendingRedLineStart = g_lastEqHighLineStart;
                  s_last1hPendingRedTicket    = tkt;
                  InvalidateTotalEAOrdersCache();
                  PrintFormat(">>> [1H RED LINE PENDING] Created SELL pending #%d (Type=%s) Lots=%.2f at Price=%.2f (Bid=%.2f Dist=$%.2f <= $%.2f) SL=%.2f TP=%.2f LineStart=%s (Active %d min, EMA Angle=%.1f deg [Angle Ignored])",
                              tkt, (pendingType == OP_SELLLIMIT ? "SELL_LIMIT" : "SELL_STOP"),
                              sellLot, targetPrice, Bid, distRed, nearThresholdUSD,
                              stopLoss, takeProfit,
                              TimeToString(g_lastEqHighLineStart, TIME_DATE|TIME_MINUTES),
                              redElapsedSec / 60, curEmaAng);
                 }
               else
                 {
                  int sendErr = GetLastError();
                  PrintFormat(">>> [1H RED LINE PENDING FAILED] Err=%d Type=%d Lots=%.2f Price=%.2f Bid=%.2f SL=%.2f TP=%.2f",
                              sendErr, pendingType, sellLot, targetPrice, Bid, stopLoss, takeProfit);
                 }
              }
           }
        }
     }

   // ----------------------------------------------------------------
   // 2. GREEN LINE: Support -> BUY pending order
   // ----------------------------------------------------------------
   if(hasActiveGreen)
     {
      int greenElapsedSec = (int)(TimeCurrent() - g_lastEqLowLineStart);
      if(greenElapsedSec >= minDurationSec && s_last1hPendingGreenLineStart != g_lastEqLowLineStart)
        {
         double distGreen = MathAbs(Ask - g_lastEqLowPrice);
         if(distGreen <= nearThresholdUSD)
           {
            // Verify no open 1-hour pending Buy order currently exists
            bool hasExistingGreenPending = false;
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               int oType = OrderType();
               if(oType == OP_BUYLIMIT || oType == OP_BUYSTOP)
                 {
                  if(StringFind(OrderComment(), "EQH-G 1h") >= 0)
                    {
                     hasExistingGreenPending = true;
                     s_last1hPendingGreenTicket = OrderTicket();
                     s_last1hPendingGreenLineStart = g_lastEqLowLineStart;
                     break;
                    }
                 }
              }

            if(!hasExistingGreenPending)
              {
               int pendingType = OP_BUYLIMIT;
               double targetPrice = NormalizeDouble(g_lastEqLowPrice, Digits);

               if(Ask > g_lastEqLowPrice)
                 {
                  pendingType = OP_BUYLIMIT;
                  if((Ask - targetPrice) < minStopDist)
                     targetPrice = NormalizeDouble(Ask - minStopDist, Digits);
                 }
               else
                 {
                  pendingType = OP_BUYSTOP;
                  if((targetPrice - Ask) < minStopDist)
                     targetPrice = NormalizeDouble(Ask + minStopDist, Digits);
                 }

               double stopLoss = 0.0;
               double lineSL = NormalizeDouble(targetPrice - slOffset, Digits);
               if(lineSL < (Bid - minStopDist))
                  stopLoss = lineSL;
               else
                  if(defaultSLDist > 0.0)
                     stopLoss = NormalizeDouble(targetPrice - defaultSLDist, Digits);

               double takeProfit = (tpDist > 0.0) ? NormalizeDouble(targetPrice + tpDist, Digits) : 0.0;

               double baseLot = (InpHLine1HourBuyLotBase > 0.0) ? InpHLine1HourBuyLotBase : 0.03;
               double buyLot = NormalizeLots(baseLot * mult);

               ResetLastError();
               int tkt = OrderSend(Symbol(), pendingType, buyLot, targetPrice, Slippage, stopLoss, takeProfit, "EQH-G 1h Pending", MagicNumber, 0, BuyColor);
               if(tkt < 0)
                 {
                  int err = GetLastError();
                  if(err == 130 || err == 4107)
                    {
                     ResetLastError();
                     tkt = OrderSend(Symbol(), pendingType, buyLot, targetPrice, Slippage, 0, 0, "EQH-G 1h Pending", MagicNumber, 0, BuyColor);
                     if(tkt > 0 && (stopLoss > 0.0 || takeProfit > 0.0))
                        SafeOrderModify(tkt, targetPrice, stopLoss, takeProfit, 0, BuyColor);
                    }
                 }

               if(tkt > 0)
                 {
                  s_last1hPendingGreenLineStart = g_lastEqLowLineStart;
                  s_last1hPendingGreenTicket    = tkt;
                  InvalidateTotalEAOrdersCache();
                  PrintFormat(">>> [1H GREEN LINE PENDING] Created BUY pending #%d (Type=%s) Lots=%.2f at Price=%.2f (Ask=%.2f Dist=$%.2f <= $%.2f) SL=%.2f TP=%.2f LineStart=%s (Active %d min, EMA Angle=%.1f deg [Angle Ignored])",
                              tkt, (pendingType == OP_BUYLIMIT ? "BUY_LIMIT" : "BUY_STOP"),
                              buyLot, targetPrice, Ask, distGreen, nearThresholdUSD,
                              stopLoss, takeProfit,
                              TimeToString(g_lastEqLowLineStart, TIME_DATE|TIME_MINUTES),
                              greenElapsedSec / 60, curEmaAng);
                 }
               else
                 {
                  int sendErr = GetLastError();
                  PrintFormat(">>> [1H GREEN LINE PENDING FAILED] Err=%d Type=%d Lots=%.2f Price=%.2f Ask=%.2f SL=%.2f TP=%.2f",
                              sendErr, pendingType, buyLot, targetPrice, Ask, stopLoss, takeProfit);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| ManageHorizontalLineEndedBreakoutStopLoss:                       |
//| USER RULE:                                                       |
//| "Red horizontal line started and endded but market price is      |
//|  moving above $100 the redline even red line ended. then modify  |
//|  all open sell orders with redline current price+$200 .          |
//|  similary logic for green horizontal line also ."                |
//+------------------------------------------------------------------+
void ManageHorizontalLineEndedBreakoutStopLoss()
  {
   if(!InpEnableLineEndedBreakoutSLModify)
      return;
   if(!EAStartupComplete)
      return;

   RefreshRates();
   double minStopDist = GetRequiredStopDistance();
   double triggerGap  = (InpLineEndedBreakoutTriggerGapRaw > 0.0) ? InpLineEndedBreakoutTriggerGapRaw : 100.0;
   double slOffset    = (InpLineEndedBreakoutSLOffsetRaw > 0.0)   ? InpLineEndedBreakoutSLOffsetRaw   : 200.0;

// One-time breakout handling guard per ended line (prevents infinite delete loop on every tick)
   static datetime s_lastHandledRedBreakoutStart   = 0;
   static datetime s_lastHandledGreenBreakoutStart = 0;

// =========================================================================
// 1. RED LINE (EQH-R) ENDED & PRICE MOVING ABOVE $100 -> MODIFY ALL SELLS & DELETE PENDING (ONCE)
// =========================================================================
// Must be a recently ended active EQH-R line, NOT arbitrary stale chart history
   double   redLinePrice = g_endedEqHighPrice;
   datetime redLineStart = g_endedEqHighStart;
   datetime redLineTime  = g_endedEqHighTime;

// Only valid if line actually ended in current session and within 30 minutes
   if(redLinePrice > 0.0 && redLineStart > 0 && redLineTime > 0 && (TimeCurrent() - redLineTime) <= 1800 && GetEQR_R_Price(true) <= 0.0)
     {
      double redBreakoutLevel = redLinePrice + triggerGap;
      if(Ask >= redBreakoutLevel || Bid >= redBreakoutLevel)
        {
         // 1a. USER RULE: Delete pending orders on line-ended breakout (ONCE per ended line)
         if(InpLineEndedBreakoutDeletePending && s_lastHandledRedBreakoutStart != redLineStart)
           {
            for(int p = OrdersTotal() - 1; p >= 0; p--)
              {
               if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               int pType = OrderType();
               bool isSellPending = (pType == OP_SELLSTOP || pType == OP_SELLLIMIT);
               bool isAnyPending  = (pType == OP_BUYSTOP  || pType == OP_BUYLIMIT || isSellPending);
               if(InpLineEndedBreakoutDeleteAllPending ? isAnyPending : isSellPending)
                 {
                  Print(">>> [RED LINE ENDED +$100 BREAKOUT] Deleting pending order #", OrderTicket(),
                        " Type=", pType, " Lots=", DoubleToString(OrderLots(), 2),
                        " Entry=", DoubleToString(OrderOpenPrice(), Digits),
                        " (RedLine=", DoubleToString(redLinePrice, Digits),
                        " Ask=", DoubleToString(Ask, Digits), ")");
                  SafeOrderDelete(OrderTicket(), clrRed);
                 }
              }
           }

         // 1b. Modify SL for all open market SELL orders
         double targetSL = NormalizeDouble(redLinePrice + slOffset, Digits);
         if(InpLimitSLToEmaHighestDistance)
           {
            targetSL = CapStopLossByEmaDistance(OP_SELL, targetSL);
           }

         // Anti-chasing: If targetSL is already below Ask + minStopDist, price has breached it; do NOT chase Ask higher!
         if(targetSL >= (Ask + minStopDist))
           {
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               if(OrderType() != OP_SELL)
                  continue;

               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip or Equity Target Hit!
               if(EMADirection == 1 || IsEmaFlipBreathingOrder(OrderTicket()) || IsEquityHitSecuredOrder(OrderTicket()))
                 {
                  Print(">>> [RED LINE BREAKOUT SKIPPED] SELL #", OrderTicket(), " is guarded by EMA Flip Breathing SL.");
                  continue;
                 }

               double curSL = OrderStopLoss();
               // NEVER widen an existing StopLoss: for SELL, targetSL must be strictly lower (tighter) than curSL
               if(curSL > 0.0 && targetSL >= curSL)
                  continue;

               if(curSL > 0.0 && MathAbs(curSL - targetSL) <= Point * 5)
                  continue;

               Print(">>> [RED LINE ENDED +$100 BREAKOUT] Red Line (Price=", DoubleToString(redLinePrice, Digits),
                     ") ended & price (Ask=", DoubleToString(Ask, Digits),
                     ") >= RedLine+$", DoubleToString(triggerGap, 2), " (", DoubleToString(redBreakoutLevel, Digits),
                     "). Modifying open SELL Order #", OrderTicket(), " SL to ", DoubleToString(targetSL, Digits),
                     " (OldSL=", DoubleToString(curSL, Digits), ")");

               SafeOrderModify(OrderTicket(), OrderOpenPrice(), targetSL, OrderTakeProfit(), 0, clrRed);
              }
           }

         // Mark this ended line's breakout as completely handled and clear tracking
         s_lastHandledRedBreakoutStart = redLineStart;
         g_endedEqHighPrice            = 0.0;
         g_endedEqHighStart            = 0;
         g_endedEqHighTime             = 0;
        }
     }

// =========================================================================
// 2. GREEN LINE (EQH-G) ENDED & PRICE MOVING BELOW $100 -> MODIFY ALL BUYS & DELETE PENDING (ONCE)
// =========================================================================
// Must be a recently ended active EQH-G line, NOT arbitrary stale chart history
   double   greenLinePrice = g_endedEqLowPrice;
   datetime greenLineStart = g_endedEqLowStart;
   datetime greenLineTime  = g_endedEqLowTime;

// Only valid if line actually ended in current session and within 30 minutes
   if(greenLinePrice > 0.0 && greenLineStart > 0 && greenLineTime > 0 && (TimeCurrent() - greenLineTime) <= 1800 && GetEQR_G_Price(true) <= 0.0)
     {
      double greenBreakoutLevel = greenLinePrice - triggerGap;
      if(Bid <= greenBreakoutLevel || Ask <= greenBreakoutLevel)
        {
         // 2a. USER RULE: Delete pending orders on line-ended breakout (ONCE per ended line)
         if(InpLineEndedBreakoutDeletePending && s_lastHandledGreenBreakoutStart != greenLineStart)
           {
            for(int p = OrdersTotal() - 1; p >= 0; p--)
              {
               if(!OrderSelect(p, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               int pType = OrderType();
               bool isBuyPending = (pType == OP_BUYSTOP || pType == OP_BUYLIMIT);
               bool isAnyPending = (pType == OP_SELLSTOP || pType == OP_SELLLIMIT || isBuyPending);
               if(InpLineEndedBreakoutDeleteAllPending ? isAnyPending : isBuyPending)
                 {
                  Print(">>> [GREEN LINE ENDED -$100 BREAKOUT] Deleting pending order #", OrderTicket(),
                        " Type=", pType, " Lots=", DoubleToString(OrderLots(), 2),
                        " Entry=", DoubleToString(OrderOpenPrice(), Digits),
                        " (GreenLine=", DoubleToString(greenLinePrice, Digits),
                        " Bid=", DoubleToString(Bid, Digits), ")");
                  SafeOrderDelete(OrderTicket(), clrGreen);
                 }
              }
           }

         // 2b. Modify SL for all open market BUY orders
         double targetSL = NormalizeDouble(greenLinePrice - slOffset, Digits);
         if(InpLimitSLToEmaHighestDistance)
           {
            targetSL = CapStopLossByEmaDistance(OP_BUY, targetSL);
           }

         // Anti-chasing: If targetSL is already above Bid - minStopDist, price has breached it; do NOT chase Bid lower!
         if(targetSL > 0.0 && targetSL <= (Bid - minStopDist))
           {
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;
               if(OrderType() != OP_BUY)
                  continue;

               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip or Equity Target Hit!
               if(EMADirection == -1 || IsEmaFlipBreathingOrder(OrderTicket()) || IsEquityHitSecuredOrder(OrderTicket()))
                 {
                  Print(">>> [GREEN LINE BREAKOUT SKIPPED] BUY #", OrderTicket(), " is guarded by EMA Flip Breathing SL.");
                  continue;
                 }

               double curSL = OrderStopLoss();
               // NEVER widen an existing StopLoss: for BUY, targetSL must be strictly higher (tighter) than curSL
               if(curSL > 0.0 && targetSL <= curSL)
                  continue;

               if(curSL > 0.0 && MathAbs(curSL - targetSL) <= Point * 5)
                  continue;

               Print(">>> [GREEN LINE ENDED -$100 BREAKOUT] Green Line (Price=", DoubleToString(greenLinePrice, Digits),
                     ") ended & price (Bid=", DoubleToString(Bid, Digits),
                     ") <= GreenLine-$", DoubleToString(triggerGap, 2), " (", DoubleToString(greenBreakoutLevel, Digits),
                     "). Modifying open BUY Order #", OrderTicket(), " SL to ", DoubleToString(targetSL, Digits),
                     " (OldSL=", DoubleToString(curSL, Digits), ")");

               SafeOrderModify(OrderTicket(), OrderOpenPrice(), targetSL, OrderTakeProfit(), 0, clrGreen);
              }
           }

         // Mark this ended line's breakout as completely handled and clear tracking
         s_lastHandledGreenBreakoutStart = greenLineStart;
         g_endedEqLowPrice               = 0.0;
         g_endedEqLowStart               = 0;
         g_endedEqLowTime                = 0;
        }
     }
  }

//| CheckLsdSweepFlipBasketSupportOrder:                             |
//| USER RULE:                                                       |
//| SEPARATE MAXIMUM COUNTS:                                         |
//| - Flipbasketsupport SELL maximum is 1                            |
//| - FLIPBasketSupport BUY order count is 1                         |
//| - Separate maximum counts (BUY and SELL run independently)       |
//|                                                                  |
//| 1. EQH-R detects & EMA direction is -1:                          |
//|    all SELL orders changelots method LOT are maximum 0.01 only.  |
//|    booster for BUY orders: MINIMUM lot is 0.02.                  |
//|    if price is above EQH-R (range upto $100 raw gap):           |
//|    CREATE BUY EMAflipsupportorder immediately with condition     |
//|    BUY EMAflipsupportorder maximum count is 1.                   |
//|                                                                  |
//| 2. EQH-G detects & EMA direction is 1:                           |
//|    all BUY orders changelots method LOT are maximum 0.01 only.   |
//|    booster for SELL orders: MINIMUM lot is 0.02.                 |
//|    if price is below EQH-G (range upto $100 raw gap):           |
//|    CREATE SELL EMAflipsupportorder immediately with condition    |
//|    SELL EMAflipsupportorder maximum count is 1.                  |
//+------------------------------------------------------------------+
//| CheckLsdSweepFlipBasketSupportOrder:                             |
//| SUPPORT ORDER LOGIC METHODS:                                     |
//| SEPARATE MAXIMUM COUNTS:                                         |
//| - Flipbasketsupport SELL maximum is 1                            |
//| - FLIPBasketSupport BUY order count is 1                         |
//|                                                                  |
//| METHOD 1 (Breakout / Sweep):                                     |
//| - EQH-R detected & EMA is -1: Price > EQH-R (gap <= $100)        |
//|   -> CREATE BUY EMAflipsupportorder                              |
//| - EQH-G detected & EMA is 1: Price < EQH-G (gap <= $100)         |
//|   -> CREATE SELL EMAflipsupportorder                             |
//|                                                                  |
//| METHOD 2 (Range / Bounce Proximity):                             |
//| - EQH-R detected & EMA is ANY: Price < EQH-R (gap <= $50)        |
//|   -> CREATE SELL EMAflipsupportorder                             |
//| - EQH-G detected & EMA is ANY: Price > EQH-G (gap <= $50)        |
//|   -> CREATE BUY EMAflipsupportorder                              |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| GetLsdSweepActiveEqhLineStart:                                   |
//| Returns start time (Pivot 1) of currently active EQH-R red line. |
//| Strictly active-only: never returns ended historical lines.      |
//+------------------------------------------------------------------+
datetime GetLsdSweepActiveEqhLineStart()
  {
   if(g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0)
      return g_lastEqHighLineStart;
   if(InpShowLiquiditySweeps)
      return 0;

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0 && StringFind(name, "EQH_M_", 0) < 0)
        {
         datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
         if(TimeCurrent() < t2)
           {
            datetime t1 = (datetime)ObjectGet(name, OBJPROP_TIME1);
            if(t1 > 0)
               return t1;
           }
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepActiveEqlLineStart:                                   |
//| Returns start time (Pivot 1) of currently active EQH-G green line.|
//| Strictly active-only: never returns ended historical lines.      |
//+------------------------------------------------------------------+
datetime GetLsdSweepActiveEqlLineStart()
  {
   if(g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0)
      return g_lastEqLowLineStart;
   if(InpShowLiquiditySweeps)
      return 0;

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0 && StringFind(name, "EQL_M_", 0) < 0)
        {
         datetime t2 = (datetime)ObjectGet(name, OBJPROP_TIME2);
         if(TimeCurrent() < t2)
           {
            datetime t1 = (datetime)ObjectGet(name, OBJPROP_TIME1);
            if(t1 > 0)
               return t1;
           }
        }
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| SyncHorizontalLineActivationTimers:                              |
//| Tracks live single-line activation duration and resets whenever  |
//| a line ends or both Red & Green lines are simultaneously active. |
//+------------------------------------------------------------------+
void SyncHorizontalLineActivationTimers()
  {
   if(!EAStartupComplete)
     {
      g_activeEqHighTrackedStart = 0;
      g_activeEqHighActivatedAt  = 0;
      g_activeEqLowTrackedStart  = 0;
      g_activeEqLowActivatedAt   = 0;
      return;
     }

   datetime nowT          = TimeCurrent();
   bool redLiveActive     = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0);
   bool greenLiveActive   = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0);

   if(!redLiveActive)
     {
      g_activeEqHighTrackedStart = 0;
      g_activeEqHighActivatedAt  = 0;
     }
   else
      if(g_lastEqHighLineStart != g_activeEqHighTrackedStart || g_activeEqHighActivatedAt == 0 || nowT < g_activeEqHighActivatedAt)
        {
         g_activeEqHighTrackedStart = g_lastEqHighLineStart;
         g_activeEqHighActivatedAt  = nowT;
        }

   if(!greenLiveActive)
     {
      g_activeEqLowTrackedStart = 0;
      g_activeEqLowActivatedAt  = 0;
     }
   else
      if(g_lastEqLowLineStart != g_activeEqLowTrackedStart || g_activeEqLowActivatedAt == 0 || nowT < g_activeEqLowActivatedAt)
        {
         g_activeEqLowTrackedStart = g_lastEqLowLineStart;
         g_activeEqLowActivatedAt  = nowT;
        }

   double curEmaAngTimer = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double minBothLinesAngleTimer = (InpBothHorizontalLinesBlockMinEmaAngle > 0.0) ? InpBothHorizontalLinesBlockMinEmaAngle : 4.0;
   if(InpBlockAllOrdersWhenBothHorizontalLinesActive && redLiveActive && greenLiveActive && MathAbs(curEmaAngTimer) >= minBothLinesAngleTimer)
     {
      g_activeEqHighActivatedAt = nowT;
      g_activeEqLowActivatedAt  = nowT;
     }
  }

//+------------------------------------------------------------------+
//| GetHorizontalLineActiveWaitElapsedSeconds:                       |
//| Returns seconds elapsed since active single-line stabilization.  |
//+------------------------------------------------------------------+
int GetHorizontalLineActiveWaitElapsedSeconds(bool isRedLine)
  {
   SyncHorizontalLineActivationTimers();
   if(isRedLine)
     {
      if(g_lastEqHighPrice <= 0.0 || g_lastEqHighLineStart <= 0 || g_activeEqHighActivatedAt <= 0)
         return -1;
      return (int)(TimeCurrent() - g_activeEqHighActivatedAt);
     }
   if(g_lastEqLowPrice <= 0.0 || g_lastEqLowLineStart <= 0 || g_activeEqLowActivatedAt <= 0)
      return -1;
   return (int)(TimeCurrent() - g_activeEqLowActivatedAt);
  }

//+------------------------------------------------------------------+
//| IsHorizontalLineActivationWaitSatisfied:                         |
//| True only when the line is live-active, single-line confirmed,   |
//| and has stayed active >= InpHorizontalLineMinActiveWaitSeconds.  |
//+------------------------------------------------------------------+
bool IsHorizontalLineActivationWaitSatisfied(bool isRedLine)
  {
   SyncHorizontalLineActivationTimers();
   bool redLiveActive   = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0);
   bool greenLiveActive = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0);

   double curEmaAngWait = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double minBothLinesAngleWait = (InpBothHorizontalLinesBlockMinEmaAngle > 0.0) ? InpBothHorizontalLinesBlockMinEmaAngle : 4.0;
   if(InpBlockAllOrdersWhenBothHorizontalLinesActive && redLiveActive && greenLiveActive && MathAbs(curEmaAngWait) >= minBothLinesAngleWait)
      return false;

   int elapsedSec = GetHorizontalLineActiveWaitElapsedSeconds(isRedLine);
   if(elapsedSec < 0)
      return false;

   int waitSec = (InpHorizontalLineMinActiveWaitSeconds > 0) ? InpHorizontalLineMinActiveWaitSeconds : 0;
   if(waitSec > 0 && elapsedSec < waitSec)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| CountOrdersForLsdLine:                                           |
//| Counts total orders (open trades + closed history) created for   |
//| the specified horizontal line (identified by line start time).   |
//+------------------------------------------------------------------+
int CountOrdersForLsdLine(string lineType, datetime lineStartTime, int &outPendingTicket)
  {
   outPendingTicket = -1;
   int count = 0;
   string searchPattern = (lineType == "EQHR") ? "FLIPBasketSupport_LSD_EQHR" : "FLIPBasketSupport_LSD_EQHG";
   string eqhPattern    = (lineType == "EQHR") ? "EQH-R" : "EQH-G";
   string sslPattern    = (lineType == "EQHR") ? "EQH-R Short" : "EQH-G Long";
   int targetTicket     = (lineType == "EQHR") ? g_lastEqhSellOrderTicket : g_lastEqlBuyOrderTicket;

// 1. Scan open positions & pending orders in MODE_TRADES
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int tkt = OrderTicket();
      int oType = OrderType();
      datetime ordOpenTime = OrderOpenTime();
      string rawCmt = OrderComment();
      string comm = GetEffectiveOrderComment(tkt, rawCmt);
      bool isMatch = false;

      if(targetTicket > 0 && (tkt == targetTicket || ResolveRootTicketFromPartialChain(tkt, rawCmt) == targetTicket))
         isMatch = true;
      else
         if(StringFind(comm, searchPattern) >= 0)
            isMatch = true;
         else
            if((StringFind(comm, eqhPattern) >= 0 || StringFind(comm, sslPattern) >= 0) && lineStartTime > 0 && MathAbs(ordOpenTime - lineStartTime) <= 300)
               isMatch = true;

      if(!isMatch)
         continue;

      // Allow 60 second buffer between line start time and order open time
      if(lineStartTime > 0 && ordOpenTime >= (lineStartTime - 60))
        {
         count++;
         if(oType == OP_BUYSTOP || oType == OP_SELLSTOP || oType == OP_BUYLIMIT || oType == OP_SELLLIMIT)
           {
            outPendingTicket = tkt;
           }
        }
     }

// 2. Scan trade history for closed orders in MODE_HISTORY
   int histTotal = OrdersHistoryTotal();
   for(int h = histTotal - 1; h >= 0; h--)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int tkt = OrderTicket();
      datetime ordOpenTime = OrderOpenTime();
      string rawCmt = OrderComment();
      string comm = GetEffectiveOrderComment(tkt, rawCmt);
      bool isMatch = false;

      if(targetTicket > 0 && (tkt == targetTicket || ResolveRootTicketFromPartialChain(tkt, rawCmt) == targetTicket))
         isMatch = true;
      else
         if(StringFind(comm, searchPattern) >= 0)
            isMatch = true;
         else
            if((StringFind(comm, eqhPattern) >= 0 || StringFind(comm, sslPattern) >= 0) && lineStartTime > 0 && MathAbs(ordOpenTime - lineStartTime) <= 300)
               isMatch = true;

      if(!isMatch)
         continue;

      if(lineStartTime > 0 && ordOpenTime >= (lineStartTime - 60))
        {
         count++;
        }
     }

// 3. In-memory check fallback
   if(count == 0 && lineStartTime > 0)
     {
      if(lineType == "EQHR" && g_lastOrderEqHighLineStart == lineStartTime)
         count = 1;
      else
         if(lineType == "EQHG" && g_lastOrderEqLowLineStart == lineStartTime)
            count = 1;
     }

   return count;
  }

//+------------------------------------------------------------------+
//| HasOrderBeenCreatedForLsdLine:                                   |
//| Returns true if 1 order has ALREADY been created for this line.  |
//| USER RULE: "one horizontal line total limit one order only."     |
//+------------------------------------------------------------------+
bool HasOrderBeenCreatedForLsdLine(string lineType, datetime lineStartTime)
  {
   if(lineStartTime <= 0)
      return false;

   if(lineType == "EQHR" && g_lastOrderEqHighLineStart == lineStartTime)
      return true;
   if(lineType == "EQHG" && g_lastOrderEqLowLineStart == lineStartTime)
      return true;

   int dummyPending = -1;
   int cnt = CountOrdersForLsdLine(lineType, lineStartTime, dummyPending);
   return (cnt >= 1);
  }

//+------------------------------------------------------------------+
//| CleanDuplicateLsdLinePendingOrders:                              |
//| Deletes any duplicate pending orders placed on horizontal lines  |
//| that have already spawned an order (enforcing 1 order max).      |
//+------------------------------------------------------------------+
void CleanDuplicateLsdLinePendingOrders()
  {
// Check EQH-R
   datetime eqhStart = GetLsdSweepActiveEqhLineStart();
   if(eqhStart > 0)
     {
      for(int iter = 0; iter < 5; iter++)
        {
         int pendingTkt = -1;
         int cnt = CountOrdersForLsdLine("EQHR", eqhStart, pendingTkt);
         if(cnt <= 1 || pendingTkt <= 0)
            break;

         Print(">>> [LSD CLEANUP] Duplicate pending order #", pendingTkt,
               " detected for EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES),
               ", Total orders for line: ", cnt, "). Deleting duplicate pending order!");
         if(!SafeOrderDelete(pendingTkt, clrRed))
            break;
        }
     }

// Check EQH-G
   datetime eqlStart = GetLsdSweepActiveEqlLineStart();
   if(eqlStart > 0)
     {
      for(int iter = 0; iter < 5; iter++)
        {
         int pendingTkt = -1;
         int cnt = CountOrdersForLsdLine("EQHG", eqlStart, pendingTkt);
         if(cnt <= 1 || pendingTkt <= 0)
            break;

         Print(">>> [LSD CLEANUP] Duplicate pending order #", pendingTkt,
               " detected for EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES),
               ", Total orders for line: ", cnt, "). Deleting duplicate pending order!");
         if(!SafeOrderDelete(pendingTkt, clrRed))
            break;
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckLsdSweepFlipBasketSupportOrder:                             |
//| USER RULE: "one horizontal line total limit one order only."     |
//| Creates at most 1 order when horizontal line starts; never       |
//| creates 2nd order when price moves back to distance threshold.   |
//+------------------------------------------------------------------+
void CheckLsdSweepFlipBasketSupportOrder()
  {
   if(!InpEnableLsdSweepFlipBasketSupport)
      return;
   if(!EAStartupComplete)
      return;

// 0. Auto-clean any duplicate pending orders exceeding 1 order limit
   CleanDuplicateLsdLinePendingOrders();

   SyncHorizontalLineActivationTimers();

// USER RULE: "Horizontal orders should create within 5 min duration when the Line is initialed . do not create horizontal orders after 5 min"
   int maxDurationSec = (InpHorizontalLineMaxDurationSeconds > 0) ? InpHorizontalLineMaxDurationSeconds : 300;

   datetime eqhStart = GetLsdSweepActiveEqhLineStart();
   datetime eqlStart = GetLsdSweepActiveEqlLineStart();

   RefreshRates();
   bool runMethod1 = (InpLsdSupportMode == LSD_MODE_METHOD1_BREAKOUT || InpLsdSupportMode == LSD_MODE_BOTH);
   bool runMethod2 = (InpLsdSupportMode == LSD_MODE_METHOD2_BOUNCE   || InpLsdSupportMode == LSD_MODE_BOTH);

   double m1MaxGap    = (InpLsdSweepFlipBasketMaxGapRaw > 0.0) ? InpLsdSweepFlipBasketMaxGapRaw : 100.0;
   double m2MaxGap    = (InpLsdMethod2BounceGapRaw > 0.0)      ? InpLsdMethod2BounceGapRaw      : 50.0;
   double minEmaDist  = (InpLsdMinEmaDistanceRaw > 0.0)        ? InpLsdMinEmaDistanceRaw        : 100.0;
   double liveEma     = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);

   bool eqhRPresent = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0 && IsHorizontalLineActivationWaitSatisfied(true));
   bool eqhGPresent = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0 && IsHorizontalLineActivationWaitSatisfied(false));

   int eqhWaitElapsed = GetHorizontalLineActiveWaitElapsedSeconds(true);
   int eqlWaitElapsed = GetHorizontalLineActiveWaitElapsedSeconds(false);

   double eqhPrice = eqhRPresent ? g_lastEqHighPrice : 0.0;
   double eqlPrice = eqhGPresent ? g_lastEqLowPrice  : 0.0;

// =================================================================
// 1. BUY SUPPORT ORDER EVALUATION (Max open BUY support count is 1)
// =================================================================
   if(!HasOpenFLIPBasketSupportOrder(OP_BUY))
     {
      // --- Method 1: EQH-R detects & EMA -1: Price > EQH-R (gap <= $100) -> CREATE BUY ---
      // USER RULE: 2-3 min activation wait + 5-min line duration limit
      if(runMethod1 && eqhRPresent && EMADirection == -1 && eqhPrice > 0.0 && eqhStart > 0 && eqhWaitElapsed >= 0 && eqhWaitElapsed <= maxDurationSec)
        {
         if(HasOrderBeenCreatedForLsdLine("EQHR", eqhStart))
           {
            static datetime lastEqhrM1BuyLog = 0;
            if(TimeCurrent() - lastEqhrM1BuyLog >= 60)
              {
               lastEqhrM1BuyLog = TimeCurrent();
               Print(">>> [LSD M1 BUY BLOCKED] EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES),
                     ") has ALREADY spawned an order. 1-order-per-line limit strictly enforced!");
              }
           }
         else
           {
            double livePrice = Ask;
            double rawGap = livePrice - eqhPrice;
            double emaGap = (liveEma > 0.0) ? MathAbs(livePrice - liveEma) : 999.0;

            if(livePrice > eqhPrice && rawGap <= m1MaxGap)
              {
               if(!HasMinimumHorizontalOrderGap(OP_BUY, Ask, InpHorizontalOrderSameTypeMinGapUSD))
                 {
                  // Blocked by horizontal order minimum gap ($200)
                 }
               else
                  if(MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && emaGap < minEmaDist)
                    {
                     Print(">>> [LSD M1 BUY BLOCKED] In EMA Chop Zone: Ask=", DoubleToString(livePrice, Digits),
                           ", EMA200=", DoubleToString(liveEma, Digits), ", Gap=$", DoubleToString(emaGap, 2),
                           " < Required Min $", DoubleToString(minEmaDist, 2));
                    }
                  else
                    {
                     Print(">>> [LSD M1 BUY TRIGGER] EMA=-1, EQH-R detected at ", DoubleToString(eqhPrice, Digits),
                           ", Ask=", DoubleToString(livePrice, Digits), " > EQH-R by ", DoubleToString(rawGap, 2),
                           " (<= $", DoubleToString(m1MaxGap, 2), ") | EMA Gap=$", DoubleToString(emaGap, 2),
                           " -> Creating BUY EMAflipsupportorder (M1 Breakout)...");

                     int tkt = CreateFLIPBasketSupportOrder(1, true, true, "_LSD_EQHR");
                     if(tkt > 0)
                       {
                        FLIPBasketSupportOpenedThisCycle = true;
                        g_lastOrderEqHighLineStart = eqhStart;
                        Print(">>> [LSD M1 BUY TRIGGER] Successfully created BUY EMAflipsupportorder Ticket #", tkt,
                              " for EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                       }
                    }
              }
           }
        }

      // --- Method 2: EQH-G detects & EMA ANY: Price > EQH-G (gap <= $50) -> CREATE BUY ---
      // USER RULE: 2-3 min activation wait + 5-min line duration limit
      if(!HasOpenFLIPBasketSupportOrder(OP_BUY) && runMethod2 && eqhGPresent && eqlPrice > 0.0 && eqlStart > 0 && eqlWaitElapsed >= 0 && eqlWaitElapsed <= maxDurationSec)
        {
         if(HasOrderBeenCreatedForLsdLine("EQHG", eqlStart))
           {
            static datetime lastEqhgM2BuyLog = 0;
            if(TimeCurrent() - lastEqhgM2BuyLog >= 60)
              {
               lastEqhgM2BuyLog = TimeCurrent();
               Print(">>> [LSD M2 BUY BLOCKED] EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES),
                     ") has ALREADY spawned an order. 1-order-per-line limit strictly enforced!");
              }
           }
         else
           {
            double livePrice = Ask;
            double rawGap = livePrice - eqlPrice;
            double emaGap = (liveEma > 0.0) ? MathAbs(livePrice - liveEma) : 999.0;

            if(livePrice > eqlPrice && rawGap <= m2MaxGap)
              {
               if(!HasMinimumHorizontalOrderGap(OP_BUY, Ask, InpHorizontalOrderSameTypeMinGapUSD))
                 {
                  // Blocked by horizontal order minimum gap ($200)
                 }
               else
                  // SAFE-SIDE CHECK 1: Must NOT be inside the EMA Chop Zone (< minEmaDist from EMA200)
                  if(MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && emaGap < minEmaDist)
                    {
                     Print(">>> [LSD M2 BUY BLOCKED] In EMA Chop Zone: Ask=", DoubleToString(livePrice, Digits),
                           ", EMA200=", DoubleToString(liveEma, Digits), ", Gap=$", DoubleToString(emaGap, 2),
                           " < Required Min $", DoubleToString(minEmaDist, 2), ". Skipping buy order!");
                    }
                  else
                     // SAFE-SIDE CHECK 2: Directional Runway / Momentum
                     if(InpLsdRequireDirectionalRunway && MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && liveEma > 0.0 && livePrice < liveEma && (liveEma - livePrice) < minEmaDist)
                       {
                        Print(">>> [LSD M2 BUY BLOCKED] Insufficient bounce runway up to EMA: LivePrice=",
                              DoubleToString(livePrice, Digits), ", EMA200=", DoubleToString(liveEma, Digits),
                              ", Runway=$", DoubleToString(liveEma - livePrice, 2),
                              " < Required Min $", DoubleToString(minEmaDist, 2));
                       }
                     else
                        if(InpLsdRequireDirectionalRunway && liveEma > 0.0 && livePrice > liveEma)
                          {
                           double highestSinceFlip = GetHighestPriceSinceEmaFlip();
                           double upExpansion = highestSinceFlip - liveEma;
                           if(upExpansion < minEmaDist)
                             {
                              Print(">>> [LSD M2 BUY BLOCKED] Insufficient previous upward impulse: HighestSinceFlip=",
                                    DoubleToString(highestSinceFlip, Digits), ", UpExpansion=$",
                                    DoubleToString(upExpansion, 2), " < Required Min $", DoubleToString(minEmaDist, 2));
                             }
                           else
                             {
                              Print(">>> [LSD M2 BUY TRIGGER] EMA ANY, EQH-G detected at ", DoubleToString(eqlPrice, Digits),
                                    ", Ask=", DoubleToString(livePrice, Digits), " > EQH-G by ", DoubleToString(rawGap, 2),
                                    " (<= $", DoubleToString(m2MaxGap, 2), ") | EMA Gap=$", DoubleToString(emaGap, 2),
                                    " -> Creating BUY EMAflipsupportorder (M2 Bounce)...");

                              int tkt = CreateFLIPBasketSupportOrder(1, true, true, "_LSD_EQHG_M2");
                              if(tkt > 0)
                                {
                                 FLIPBasketSupportOpenedThisCycle = true;
                                 g_lastOrderEqLowLineStart = eqlStart;
                                 Print(">>> [LSD M2 BUY TRIGGER] Successfully created BUY EMAflipsupportorder Ticket #", tkt,
                                       " for EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                                }
                             }
                          }
                        else
                          {
                           Print(">>> [LSD M2 BUY TRIGGER] EMA ANY, EQH-G detected at ", DoubleToString(eqlPrice, Digits),
                                 ", Ask=", DoubleToString(livePrice, Digits), " > EQH-G by ", DoubleToString(rawGap, 2),
                                 " (<= $", DoubleToString(m2MaxGap, 2), ") | Runway to EMA=$", DoubleToString(liveEma - livePrice, 2),
                                 " -> Creating BUY EMAflipsupportorder (M2 Bounce)...");

                           int tkt = CreateFLIPBasketSupportOrder(1, true, true, "_LSD_EQHG_M2");
                           if(tkt > 0)
                             {
                              FLIPBasketSupportOpenedThisCycle = true;
                              g_lastOrderEqLowLineStart = eqlStart;
                              Print(">>> [LSD M2 BUY TRIGGER] Successfully created BUY EMAflipsupportorder Ticket #", tkt,
                                    " for EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                             }
                          }
              }
           }
        }
     }

// =================================================================
// 2. SELL SUPPORT ORDER EVALUATION (Max open SELL support count is 1)
// =================================================================
   if(!HasOpenFLIPBasketSupportOrder(OP_SELL))
     {
      // --- Method 1: EQH-G detects & EMA +1: Price < EQH-G (gap <= $100) -> CREATE SELL ---
      // USER RULE: 2-3 min activation wait + 5-min line duration limit
      if(runMethod1 && eqhGPresent && EMADirection == 1 && eqlPrice > 0.0 && eqlStart > 0 && eqlWaitElapsed >= 0 && eqlWaitElapsed <= maxDurationSec)
        {
         if(HasOrderBeenCreatedForLsdLine("EQHG", eqlStart))
           {
            static datetime lastEqhgM1SellLog = 0;
            if(TimeCurrent() - lastEqhgM1SellLog >= 60)
              {
               lastEqhgM1SellLog = TimeCurrent();
               Print(">>> [LSD M1 SELL BLOCKED] EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES),
                     ") has ALREADY spawned an order. 1-order-per-line limit strictly enforced!");
              }
           }
         else
           {
            double livePrice = Bid;
            double rawGap = eqlPrice - livePrice;
            double emaGap = (liveEma > 0.0) ? MathAbs(livePrice - liveEma) : 999.0;

            if(livePrice < eqlPrice && rawGap <= m1MaxGap)
              {
               if(!HasMinimumHorizontalOrderGap(OP_SELL, Bid, InpHorizontalOrderSameTypeMinGapUSD))
                 {
                  // Blocked by horizontal order minimum gap ($200)
                 }
               else
                  if(MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && emaGap < minEmaDist)
                    {
                     Print(">>> [LSD M1 SELL BLOCKED] In EMA Chop Zone: Bid=", DoubleToString(livePrice, Digits),
                           ", EMA200=", DoubleToString(liveEma, Digits), ", Gap=$", DoubleToString(emaGap, 2),
                           " < Required Min $", DoubleToString(minEmaDist, 2));
                    }
                  else
                    {
                     Print(">>> [LSD M1 SELL TRIGGER] EMA=1, EQH-G detected at ", DoubleToString(eqlPrice, Digits),
                           ", Bid=", DoubleToString(livePrice, Digits), " < EQH-G by ", DoubleToString(rawGap, 2),
                           " (<= $", DoubleToString(m1MaxGap, 2), ") | EMA Gap=$", DoubleToString(emaGap, 2),
                           " -> Creating SELL EMAflipsupportorder (M1 Breakout)...");

                     int tkt = CreateFLIPBasketSupportOrder(-1, true, true, "_LSD_EQHG");
                     if(tkt > 0)
                       {
                        FLIPBasketSupportOpenedThisCycle = true;
                        g_lastOrderEqLowLineStart = eqlStart;
                        Print(">>> [LSD M1 SELL TRIGGER] Successfully created SELL EMAflipsupportorder Ticket #", tkt,
                              " for EQH-G line (Start: ", TimeToStr(eqlStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                       }
                    }
              }
           }
        }

      // --- Method 2: EQH-R detects & EMA ANY: Price < EQH-R (gap <= $50) -> CREATE SELL ---
      // USER RULE: 2-3 min activation wait + 5-min line duration limit
      if(!HasOpenFLIPBasketSupportOrder(OP_SELL) && runMethod2 && eqhRPresent && eqhPrice > 0.0 && eqhStart > 0 && eqhWaitElapsed >= 0 && eqhWaitElapsed <= maxDurationSec)
        {
         if(HasOrderBeenCreatedForLsdLine("EQHR", eqhStart))
           {
            static datetime lastEqhrM2SellLog = 0;
            if(TimeCurrent() - lastEqhrM2SellLog >= 60)
              {
               lastEqhrM2SellLog = TimeCurrent();
               Print(">>> [LSD M2 SELL BLOCKED] EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES),
                     ") has ALREADY spawned an order. 1-order-per-line limit strictly enforced!");
              }
           }
         else
           {
            double livePrice = Bid;
            double rawGap = eqhPrice - livePrice;
            double emaGap = (liveEma > 0.0) ? MathAbs(livePrice - liveEma) : 999.0;

            if(livePrice < eqhPrice && rawGap <= m2MaxGap)
              {
               if(!HasMinimumHorizontalOrderGap(OP_SELL, Bid, InpHorizontalOrderSameTypeMinGapUSD))
                 {
                  // Blocked by horizontal order minimum gap ($200)
                 }
               else
                  // SAFE-SIDE CHECK 1: Must NOT be inside the EMA Chop Zone (< minEmaDist from EMA200)
                  if(MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && emaGap < minEmaDist)
                    {
                     Print(">>> [LSD M2 SELL BLOCKED] In EMA Chop Zone: Bid=", DoubleToString(livePrice, Digits),
                           ", EMA200=", DoubleToString(liveEma, Digits), ", Gap=$", DoubleToString(emaGap, 2),
                           " < Required Min $", DoubleToString(minEmaDist, 2), ". Skipping sell order!");
                    }
                  else
                     // SAFE-SIDE CHECK 2: Directional Runway / Momentum
                     if(InpLsdRequireDirectionalRunway && MathAbs(GlobalEmaAngle30) <= InpHorizontalLineIgnoreEmaGapAngle && liveEma > 0.0 && livePrice > liveEma && (livePrice - liveEma) < minEmaDist)
                       {
                        Print(">>> [LSD M2 SELL BLOCKED] Insufficient drop runway down to EMA: LivePrice=",
                              DoubleToString(livePrice, Digits), ", EMA200=", DoubleToString(liveEma, Digits),
                              ", Runway=$", DoubleToString(livePrice - liveEma, 2),
                              " < Required Min $", DoubleToString(minEmaDist, 2));
                       }
                     else
                        if(InpLsdRequireDirectionalRunway && liveEma > 0.0 && livePrice < liveEma)
                          {
                           double lowestSinceFlip = GetLowestPriceSinceEmaFlip();
                           double downExpansion = liveEma - lowestSinceFlip;
                           if(downExpansion < minEmaDist)
                             {
                              Print(">>> [LSD M2 SELL BLOCKED] Insufficient previous downward impulse: LowestSinceFlip=",
                                    DoubleToString(lowestSinceFlip, Digits), ", DownExpansion=$",
                                    DoubleToString(downExpansion, 2), " < Required Min $", DoubleToString(minEmaDist, 2),
                                    ". (Market hasn't dropped from EMA). Skipping sell order!");
                             }
                           else
                             {
                              Print(">>> [LSD M2 SELL TRIGGER] EMA ANY, EQH-R detected at ", DoubleToString(eqhPrice, Digits),
                                    ", Bid=", DoubleToString(livePrice, Digits), " < EQH-R by ", DoubleToString(rawGap, 2),
                                    " (<= $", DoubleToString(m2MaxGap, 2), ") | DownExpansion=$", DoubleToString(downExpansion, 2),
                                    " -> Creating SELL EMAflipsupportorder (M2 Bounce)...");

                              int tkt = CreateFLIPBasketSupportOrder(-1, true, true, "_LSD_EQHR_M2");
                              if(tkt > 0)
                                {
                                 FLIPBasketSupportOpenedThisCycle = true;
                                 g_lastOrderEqHighLineStart = eqhStart;
                                 Print(">>> [LSD M2 SELL TRIGGER] Successfully created SELL EMAflipsupportorder Ticket #", tkt,
                                       " for EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                                }
                             }
                          }
                        else
                          {
                           Print(">>> [LSD M2 SELL TRIGGER] EMA ANY, EQH-R detected at ", DoubleToString(eqhPrice, Digits),
                                 ", Bid=", DoubleToString(livePrice, Digits), " < EQH-R by ", DoubleToString(rawGap, 2),
                                 " (<= $", DoubleToString(m2MaxGap, 2), ") | Runway to EMA=$", DoubleToString(livePrice - liveEma, 2),
                                 " -> Creating SELL EMAflipsupportorder (M2 Bounce)...");

                           int tkt = CreateFLIPBasketSupportOrder(-1, true, true, "_LSD_EQHR_M2");
                           if(tkt > 0)
                             {
                              FLIPBasketSupportOpenedThisCycle = true;
                              g_lastOrderEqHighLineStart = eqhStart;
                              Print(">>> [LSD M2 SELL TRIGGER] Successfully created SELL EMAflipsupportorder Ticket #", tkt,
                                    " for EQH-R line (Start: ", TimeToStr(eqhStart, TIME_DATE|TIME_MINUTES), "). Total line limit (1) enforced.");
                             }
                          }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
void UpdateLiquiditySweepDetectorOnChart()
  {
   if(!InpShowLiquiditySweeps)
     {
      DeleteLiquiditySweepObjects();
      ManageSweepGlobalVariables("None");
      return;
     }

   if(Bars < (InpSweepPivotLen * 2 + 15))
      return;

   static datetime lastSweepBar = 0;
   static uint lastSweepCalcMs = 0;
   bool rebuild = (lastSweepBar != Time[0]);
   uint nowMs = GetTickCount();

// Throttle calculation: run on every new bar OR forced on EMA flip OR once every 1000ms
   if(!rebuild && !g_forceSweepRecalc && lastSweepCalcMs != 0 && (uint)(nowMs - lastSweepCalcMs) < 1000)
      return;

   g_forceSweepRecalc = false;
   lastSweepCalcMs = nowMs;
   lastSweepBar = Time[0];

   int maxLookbackBars = 1000;
   int limit = Bars - (InpSweepPivotLen * 2 + 2);
   if(limit > maxLookbackBars)
      limit = maxLookbackBars;
   if(limit <= 0)
      return;

   DeleteLiquiditySweepObjects();

// Tracking for Equal Highs (Red Line - Resistance)
   double lastPhPrice = 0.0;
   datetime lastPhTime = 0;
   string curHighLineName = "";
   string curHighMarkerName = "";
   double activeEqHighPrice = 0.0;
   datetime activeEqHighStart = 0;

// Tracking for Equal Lows (Green Line - Support)
   double lastPlPrice = 0.0;
   datetime lastPlTime = 0;
   string curLowLineName = "";
   string curLowMarkerName = "";
   double activeEqLowPrice = 0.0;
   datetime activeEqLowStart = 0;

   int sweepDurationSec = (InpLsdSweepMaxDisplayMinutes > 0) ? (InpLsdSweepMaxDisplayMinutes * 60) : 0;

   bool sweepFoundInCurrentFlip = false;
   string sweepTypeInCurrentFlip = "None";
   datetime sweepTimeInCurrentFlip = 0;
   datetime flipTime = GetActualEmaFlipTime(EMADirection);
   if(flipTime == 0 && EmaFlipTime > 0)
      flipTime = EmaFlipTime;
   if(flipTime <= 0 && Bars > 0)
      flipTime = Time[MathMin(Bars - 1, limit)];

// Forward chronological iteration from oldest bar (limit) down to current bar (0)
   for(int i = limit; i >= 0; i--)
     {
      double atr = iATR(Symbol(), Period(), 14, i);

      // ================================================================
      // A. Active High Line (EQH-R) Check: Sweep, Mitigation, or Timeout
      // ================================================================
      if(curHighLineName != "" && activeEqHighPrice > 0.0)
        {
         bool bslSweep = (High[i] > activeEqHighPrice && Close[i] < activeEqHighPrice);
         bool bslMitigated = ((!InpSweepMitigationWaitCandleClose || i >= 1) && Close[i] >= activeEqHighPrice + atr * 0.15);
         bool timeout = (sweepDurationSec > 0 && (Time[i] - activeEqHighStart) >= sweepDurationSec);

         if(bslSweep)
           {
            // FREEZE LINE AT EXACT SWEEP CANDLE
            ObjectSet(curHighLineName, OBJPROP_TIME2, Time[i]);

            if(InpShowLiquiditySweeps)
              {
               // Red down arrow marker above bar (Bearish SWEEP sell signal)
               string arrName = LSD_PREFIX + "BSL_ARR_" + IntegerToString((int)Time[i]);
               ObjectCreate(0, arrName, OBJ_ARROW, 0, Time[i], High[i] + atr * 0.25);
               ObjectSetInteger(0, arrName, OBJPROP_ARROWCODE, 242);
               ObjectSetInteger(0, arrName, OBJPROP_COLOR, InpBslSweepColor);
               ObjectSetInteger(0, arrName, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, arrName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, arrName, OBJPROP_HIDDEN, true);

               if(InpShowSweepLabels)
                 {
                  // Red badge text: BSLS
                  string lblName = LSD_PREFIX + "BSL_LBL_" + IntegerToString((int)Time[i]);
                  ObjectCreate(0, lblName, OBJ_TEXT, 0, Time[i], High[i] + atr * 0.45);
                  ObjectSetString(0, lblName, OBJPROP_TEXT, "BSLS");
                  ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
                  ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
                  ObjectSetInteger(0, lblName, OBJPROP_COLOR, InpBslSweepColor);
                  ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
                 }
              }

            g_lastSweepType = "BSLS";
            g_lastSweepBarTime = Time[i];

            if(flipTime > 0 && Time[i] >= flipTime)
              {
               sweepFoundInCurrentFlip = true;
               sweepTypeInCurrentFlip   = "BSLS";
               sweepTimeInCurrentFlip   = Time[i];
              }

            // Completed line is preserved on chart from Pivot 1 to Sweep Candle
            if(!InpKeepHistoricalSweepLines)
              {
               ObjectDelete(0, curHighLineName);
               if(curHighMarkerName != "")
                  ObjectDelete(0, curHighMarkerName);
              }

            g_lastSweptEqHighLineStart = activeEqHighStart;
            curHighLineName = "";
            curHighMarkerName = "";
            activeEqHighPrice = 0.0;
            activeEqHighStart = 0;
           }
         else
            if(bslMitigated || timeout)
              {
               // Line broken by strong candle body or timed out: freeze at this candle
               ObjectSet(curHighLineName, OBJPROP_TIME2, Time[i]);
               if(!InpKeepHistoricalSweepLines)
                 {
                  ObjectDelete(0, curHighLineName);
                  if(curHighMarkerName != "")
                     ObjectDelete(0, curHighMarkerName);
                 }
               curHighLineName = "";
               curHighMarkerName = "";
               activeEqHighPrice = 0.0;
               activeEqHighStart = 0;
              }
            else
              {
               // Still active: extend to current bar (or live future bar if i == 0)
               ObjectSet(curHighLineName, OBJPROP_TIME2, (i == 0) ? (Time[0] + Period() * 60) : Time[i]);
              }
        }

      // ================================================================
      // B. Active Low Line (EQH-G) Check: Sweep, Mitigation, or Timeout
      // ================================================================
      if(curLowLineName != "" && activeEqLowPrice > 0.0)
        {
         bool sslSweep = (Low[i] < activeEqLowPrice && Close[i] > activeEqLowPrice);
         bool sslMitigated = ((!InpSweepMitigationWaitCandleClose || i >= 1) && Close[i] <= activeEqLowPrice - atr * 0.15);
         bool timeout = (sweepDurationSec > 0 && (Time[i] - activeEqLowStart) >= sweepDurationSec);

         if(sslSweep)
           {
            // FREEZE LINE AT EXACT SWEEP CANDLE
            ObjectSet(curLowLineName, OBJPROP_TIME2, Time[i]);

            if(InpShowLiquiditySweeps)
              {
               // Lime up arrow marker below bar (Bullish SWEEP buy signal)
               string arrName = LSD_PREFIX + "SSL_ARR_" + IntegerToString((int)Time[i]);
               ObjectCreate(0, arrName, OBJ_ARROW, 0, Time[i], Low[i] - atr * 0.25);
               ObjectSetInteger(0, arrName, OBJPROP_ARROWCODE, 241);
               ObjectSetInteger(0, arrName, OBJPROP_COLOR, InpSslSweepColor);
               ObjectSetInteger(0, arrName, OBJPROP_WIDTH, 3);
               ObjectSetInteger(0, arrName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, arrName, OBJPROP_HIDDEN, true);

               if(InpShowSweepLabels)
                 {
                  // Lime badge text: SSLS
                  string lblName = LSD_PREFIX + "SSL_LBL_" + IntegerToString((int)Time[i]);
                  ObjectCreate(0, lblName, OBJ_TEXT, 0, Time[i], Low[i] - atr * 0.45);
                  ObjectSetString(0, lblName, OBJPROP_TEXT, "SSLS");
                  ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
                  ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
                  ObjectSetInteger(0, lblName, OBJPROP_COLOR, InpSslSweepColor);
                  ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
                  ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
                 }
              }

            g_lastSweepType = "SSLS";
            g_lastSweepBarTime = Time[i];

            if(flipTime > 0 && Time[i] >= flipTime)
              {
               sweepFoundInCurrentFlip = true;
               sweepTypeInCurrentFlip   = "SSLS";
               sweepTimeInCurrentFlip   = Time[i];
              }

            // Completed line is preserved on chart from Pivot 1 to Sweep Candle
            if(!InpKeepHistoricalSweepLines)
              {
               ObjectDelete(0, curLowLineName);
               if(curLowMarkerName != "")
                  ObjectDelete(0, curLowMarkerName);
              }

            g_lastSweptEqLowLineStart = activeEqLowStart;
            curLowLineName = "";
            curLowMarkerName = "";
            activeEqLowPrice = 0.0;
            activeEqLowStart = 0;
           }
         else
            if(sslMitigated || timeout)
              {
               // Line broken by strong candle body or timed out: freeze at this candle
               ObjectSet(curLowLineName, OBJPROP_TIME2, Time[i]);
               if(!InpKeepHistoricalSweepLines)
                 {
                  ObjectDelete(0, curLowLineName);
                  if(curLowMarkerName != "")
                     ObjectDelete(0, curLowMarkerName);
                 }
               curLowLineName = "";
               curLowMarkerName = "";
               activeEqLowPrice = 0.0;
               activeEqLowStart = 0;
              }
            else
              {
               // Still active: extend to current bar (or live future bar if i == 0)
               ObjectSet(curLowLineName, OBJPROP_TIME2, (i == 0) ? (Time[0] + Period() * 60) : Time[i]);
              }
        }

      // ================================================================
      // C. Pivot High Detection at bar (i + InpSweepPivotLen)
      // ================================================================
      int phBar = i + InpSweepPivotLen;
      if(phBar < Bars - InpSweepPivotLen)
        {
         bool isPh = true;
         double candidateH = High[phBar];
         for(int j = 1; j <= InpSweepPivotLen; j++)
           {
            if(candidateH <= High[phBar + j])
              {
               isPh = false;
               break;
              }
            if(candidateH < High[phBar - j])
              {
               isPh = false;
               break;
              }
           }

         if(isPh)
           {
            double ph = candidateH;
            if(lastPhPrice > 0.0)
              {
               double phAtr = iATR(Symbol(), Period(), 14, phBar);
               if(MathAbs(ph - lastPhPrice) <= phAtr * InpSweepToleranceATR)
                 {
                  // MATCH CONFIRMED! Equal Highs (EQH-R)
                  double confirmedEqHigh = (lastPhPrice + ph) * 0.5;

                  // If an older unswept line was running, freeze it at this pivot
                  if(curHighLineName != "")
                     ObjectSet(curHighLineName, OBJPROP_TIME2, Time[phBar]);

                  if(InpShowSweepLevels)
                    {
                     curHighLineName = LSD_PREFIX + "EQH_" + IntegerToString((int)lastPhTime);

                     // REAL START TIME: Starts at Pivot 1 (lastPhTime) and extends across Pivot 2
                     datetime initEndTime = (i == 0) ? (Time[0] + Period() * 60) : Time[i];
                     ObjectCreate(0, curHighLineName, OBJ_TREND, 0, lastPhTime, confirmedEqHigh, initEndTime, confirmedEqHigh);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_COLOR, InpBslSweepColor);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_WIDTH, 2);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_HIDDEN, true);

                     // Marker text icon: EQH-R placed at confirming Pivot 2 (phBar)
                     string eqhMarker = LSD_PREFIX + "EQH_M_" + IntegerToString((int)Time[phBar]);
                     curHighMarkerName = eqhMarker;
                     ObjectCreate(0, eqhMarker, OBJ_TEXT, 0, Time[phBar], confirmedEqHigh + phAtr * 0.25);
                     ObjectSetString(0, eqhMarker, OBJPROP_TEXT, "EQH-R");
                     ObjectSetString(0, eqhMarker, OBJPROP_FONT, "Arial Bold");
                     ObjectSetInteger(0, eqhMarker, OBJPROP_FONTSIZE, 9);
                     ObjectSetInteger(0, eqhMarker, OBJPROP_COLOR, InpBslSweepColor);
                     ObjectSetInteger(0, eqhMarker, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, eqhMarker, OBJPROP_HIDDEN, true);
                    }
                  activeEqHighPrice = confirmedEqHigh;
                  activeEqHighStart = lastPhTime;
                 }
              }
            lastPhPrice = ph;
            lastPhTime = Time[phBar];
           }
        }

      // ================================================================
      // D. Pivot Low Detection at bar (i + InpSweepPivotLen)
      // ================================================================
      int plBar = i + InpSweepPivotLen;
      if(plBar < Bars - InpSweepPivotLen)
        {
         bool isPl = true;
         double candidateL = Low[plBar];
         for(int j = 1; j <= InpSweepPivotLen; j++)
           {
            if(candidateL >= Low[plBar + j])
              {
               isPl = false;
               break;
              }
            if(candidateL > Low[plBar - j])
              {
               isPl = false;
               break;
              }
           }

         if(isPl)
           {
            double pl = candidateL;
            if(lastPlPrice > 0.0)
              {
               double plAtr = iATR(Symbol(), Period(), 14, plBar);
               if(MathAbs(pl - lastPlPrice) <= plAtr * InpSweepToleranceATR)
                 {
                  // MATCH CONFIRMED! Equal Lows (EQH-G)
                  double confirmedEqLow = (lastPlPrice + pl) * 0.5;

                  // If an older unswept line was running, freeze it at this pivot
                  if(curLowLineName != "")
                     ObjectSet(curLowLineName, OBJPROP_TIME2, Time[plBar]);

                  if(InpShowSweepLevels)
                    {
                     curLowLineName = LSD_PREFIX + "EQL_" + IntegerToString((int)lastPlTime);

                     // REAL START TIME: Starts at Pivot 1 (lastPlTime) and extends across Pivot 2
                     datetime initEndTime = (i == 0) ? (Time[0] + Period() * 60) : Time[i];
                     ObjectCreate(0, curLowLineName, OBJ_TREND, 0, lastPlTime, confirmedEqLow, initEndTime, confirmedEqLow);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_COLOR, InpSslSweepColor);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_WIDTH, 2);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_HIDDEN, true);

                     // Marker text icon: EQH-G placed at confirming Pivot 2 (plBar)
                     string eqlMarker = LSD_PREFIX + "EQL_M_" + IntegerToString((int)Time[plBar]);
                     curLowMarkerName = eqlMarker;
                     ObjectCreate(0, eqlMarker, OBJ_TEXT, 0, Time[plBar], confirmedEqLow - plAtr * 0.25);
                     ObjectSetString(0, eqlMarker, OBJPROP_TEXT, "EQH-G");
                     ObjectSetString(0, eqlMarker, OBJPROP_FONT, "Arial Bold");
                     ObjectSetInteger(0, eqlMarker, OBJPROP_FONTSIZE, 9);
                     ObjectSetInteger(0, eqlMarker, OBJPROP_COLOR, InpSslSweepColor);
                     ObjectSetInteger(0, eqlMarker, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, eqlMarker, OBJPROP_HIDDEN, true);
                    }
                  activeEqLowPrice = confirmedEqLow;
                  activeEqLowStart = lastPlTime;
                 }
              }
            lastPlPrice = pl;
            lastPlTime = Time[plBar];
           }
        }
     }

   g_lastEqHighPrice = (curHighLineName != "") ? activeEqHighPrice : 0.0;
   g_lastEqLowPrice  = (curLowLineName != "") ? activeEqLowPrice : 0.0;
   g_lastEqHighLineStart = (curHighLineName != "") ? activeEqHighStart : 0;
   g_lastEqLowLineStart  = (curLowLineName != "") ? activeEqLowStart : 0;

// --- Track Active & Ended Horizontal Lines for Breakout SL Management ---
   static double   s_prevActiveEqHighPrice = 0.0;
   static datetime s_prevActiveEqHighStart = 0;
   static double   s_prevActiveEqLowPrice  = 0.0;
   static datetime s_prevActiveEqLowStart  = 0;

// 1. Red Line (EQH-R)
   if(curHighLineName != "" && activeEqHighPrice > 0.0)
     {
      s_prevActiveEqHighPrice = activeEqHighPrice;
      s_prevActiveEqHighStart = activeEqHighStart;
      g_endedEqHighPrice      = 0.0;
      g_endedEqHighStart      = 0;
     }
   else
     {
      if(s_prevActiveEqHighStart > 0 && s_prevActiveEqHighPrice > 0.0)
        {
         g_endedEqHighPrice = s_prevActiveEqHighPrice;
         g_endedEqHighStart = s_prevActiveEqHighStart;
         g_endedEqHighTime  = TimeCurrent();
         g_lastHLineEndedTime      = g_endedEqHighTime;
         g_lastHLineEndedType      = "RED";
         g_lastHLineEndedLineStart = g_endedEqHighStart;
         g_lastHLineEndedPrice     = g_endedEqHighPrice;
         Print(">>> [RED LINE ENDED] EQH-R line (Start: ", TimeToStr(g_endedEqHighStart, TIME_DATE|TIME_MINUTES),
               ", Price=", DoubleToString(g_endedEqHighPrice, Digits),
               ") ended. Monitoring for breakout > $", DoubleToString(g_endedEqHighPrice + InpLineEndedBreakoutTriggerGapRaw, 2));
         ManageHorizontalLineEndedProfitLiveStopLoss();
         s_prevActiveEqHighPrice = 0.0;
         s_prevActiveEqHighStart = 0;
        }
     }

// 2. Green Line (EQH-G)
   if(curLowLineName != "" && activeEqLowPrice > 0.0)
     {
      s_prevActiveEqLowPrice = activeEqLowPrice;
      s_prevActiveEqLowStart = activeEqLowStart;
      g_endedEqLowPrice      = 0.0;
      g_endedEqLowStart      = 0;
     }
   else
     {
      if(s_prevActiveEqLowStart > 0 && s_prevActiveEqLowPrice > 0.0)
        {
         g_endedEqLowPrice = s_prevActiveEqLowPrice;
         g_endedEqLowStart = s_prevActiveEqLowStart;
         g_endedEqLowTime  = TimeCurrent();
         g_lastHLineEndedTime      = g_endedEqLowTime;
         g_lastHLineEndedType      = "GREEN";
         g_lastHLineEndedLineStart = g_endedEqLowStart;
         g_lastHLineEndedPrice     = g_endedEqLowPrice;
         Print(">>> [GREEN LINE ENDED] EQH-G line (Start: ", TimeToStr(g_endedEqLowStart, TIME_DATE|TIME_MINUTES),
               ", Price=", DoubleToString(g_endedEqLowPrice, Digits),
               ") ended. Monitoring for breakout < $", DoubleToString(g_endedEqLowPrice - InpLineEndedBreakoutTriggerGapRaw, 2));
         ManageHorizontalLineEndedProfitLiveStopLoss();
         s_prevActiveEqLowPrice = 0.0;
         s_prevActiveEqLowStart = 0;
        }
     }

// USER RULE: Sweep updated signal is remembered until EMA flip or sweep signal change
   string activeFoundSweep = "None";
   datetime activeFoundTime = 0;
   if(sweepFoundInCurrentFlip && sweepTypeInCurrentFlip != "None")
     {
      activeFoundSweep = sweepTypeInCurrentFlip;
      activeFoundTime = sweepTimeInCurrentFlip;
     }
   else
      if(g_lastSweepType == "BSLS" || g_lastSweepType == "SSLS")
        {
         activeFoundSweep = g_lastSweepType;
         activeFoundTime = g_lastSweepBarTime;
        }

   if(activeFoundSweep != "None")
     {
      if(g_rememberedSweepSignal != activeFoundSweep)
        {
         Print(">>> [SWEEP SIGNAL UPDATED] Sweep signal active: '", activeFoundSweep,
               "' (", (activeFoundSweep == "SSLS" ? "SWEEP buy signal" : "SWEEP sell signal"),
               ") at bar time ", TimeToStr(activeFoundTime, TIME_DATE|TIME_MINUTES),
               " | Remembered until EMA flip or signal change!");
        }
      g_rememberedSweepSignal             = activeFoundSweep;
      g_rememberedSweepBarTime            = activeFoundTime;
      g_isSweepSignalConfirmed            = true;
      g_sweepSignalActiveInCurrentEmaFlip = true;
      g_sweepSignalTypeInCurrentEmaFlip   = activeFoundSweep;
      g_sweepSignalDetectedTimeInFlip     = activeFoundTime;
      ManageSweepGlobalVariables(activeFoundSweep);
      ActivateSweepOppositeBlockOnSweep(activeFoundSweep, activeFoundTime);
     }
   else
      if(g_isSweepSignalConfirmed && g_rememberedSweepSignal != "None")
        {
         // Preserve remembered sweep state across ticks until EMA flip or sweep signal change!
         g_sweepSignalActiveInCurrentEmaFlip = true;
         g_sweepSignalTypeInCurrentEmaFlip   = g_rememberedSweepSignal;
         g_sweepSignalDetectedTimeInFlip     = g_rememberedSweepBarTime;
         ManageSweepGlobalVariables(g_rememberedSweepSignal);
        }
      else
        {
         g_sweepSignalActiveInCurrentEmaFlip = false;
         g_sweepSignalTypeInCurrentEmaFlip   = "None";
         g_sweepSignalDetectedTimeInFlip     = 0;
         ManageSweepGlobalVariables("None");
        }
  }

