//+------------------------------------------------------------------+
//| V_TV_ColorPatternAnalysis.mqh                                    |
//|                                                                  |
//| Tracks every ColorRule-matched signal and analyses results:      |
//|  - Per color group: win rate, avg profit/loss in $               |
//|  - EMA trend filter effect: with vs without                      |
//|  - M30 trend filter effect: with vs without                      |
//|  - Verdict: GOOD_PATTERN / BAD_PATTERN / MONITOR                 |
//|  - Rewritten every finalization → always up to date              |
//|                                                                  |
//| FILES:                                                           |
//|  AI_ColorPattern_TIMESTAMP_SYMBOL.csv — per-signal rows          |
//|  AI_ColorStats_TIMESTAMP_SYMBOL.csv  — aggregated verdict        |
//+------------------------------------------------------------------+
#ifndef V_TV_COLOR_PATTERN_ANALYSIS_MQH
#define V_TV_COLOR_PATTERN_ANALYSIS_MQH

//+------------------------------------------------------------------+
//| Per-signal observation                                           |
//+------------------------------------------------------------------+
struct ColorPatternObs
  {
   string   colorType;      // "ANY GREEN SIGNAL" etc.
   string   signalName;     // exact signal e.g. "TREND BUY"
   int      seqCount;       // seqCount when rule fired
   string   action;         // "NEW_ORDER" or "CLOSE"
   string   tradeType;      // "BUY" or "SELL"
   string   trendRequired;  // "" / "UPTREND" / "DOWNTREND"
   string   emaRequired;    // "" / "UP" / "DOWN"
   datetime signalTime;
   double   entryPrice;
   bool     isSell;
   double   maxFavourUSD;
   double   maxAdverseUSD;
   int      barsObserved;
   bool     active;
   bool     written;
   string   finalizeReason;
  };

#define CP_OBS_MAX 200
ColorPatternObs g_cpObs[CP_OBS_MAX];
int             g_cpObsCount = 0;

//+------------------------------------------------------------------+
//| Per color-type aggregated stats                                  |
//+------------------------------------------------------------------+
struct ColorPatternStats
  {
   string colorType;
   string action;
   string tradeType;
   string trendRequired;
   string emaRequired;
   int    count;
   int    wins;
   double totalFavourUSD;
   double totalAdverseUSD;
   double totalRR;
   double bestProfitUSD;
   double worstLossUSD;
   int    slHits;
   double totalSlLossUSD;
   bool   active;
  };

#define CP_STATS_MAX 40
ColorPatternStats g_cpStats[CP_STATS_MAX];
int               g_cpStatsCount = 0;

string g_cpSignalFile = "";
string g_cpStatsFile  = "";

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void InitColorPatternAnalysis()
  {
   g_cpSignalFile = "AI_ColorPattern_" + g_runTimestamp + "_" + Symbol() + ".csv";
   g_cpStatsFile  = "AI_ColorStats_"   + g_runTimestamp + "_" + Symbol() + ".csv";

   // Signal CSV header
   int h = FileOpen(g_cpSignalFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h,
         "SignalTime,ColorType,SignalName,SeqCount,Action,TradeType,"
         "TrendFilter,EMAFilter,EntryPrice,"
         "MaxFavour_USD,MaxAdverse_USD,RewardRisk,"
         "Outcome,FinalizeReason,BotAdvice\n");
      FileClose(h);
     }

   // Stats CSV header (will be rewritten on every update)
   for(int i = 0; i < CP_OBS_MAX;   i++) g_cpObs[i].active   = false;
   for(int i = 0; i < CP_STATS_MAX; i++) g_cpStats[i].active = false;
   g_cpObsCount   = 0;
   g_cpStatsCount = 0;

   Print("ColorPattern AI | Signal file: " + g_cpSignalFile);
   Print("ColorPattern AI | Stats  file: " + g_cpStatsFile);
  }

//+------------------------------------------------------------------+
//| Find or create a stats slot                                      |
//+------------------------------------------------------------------+
int CPFindOrCreateStats(string colorType, string action,
                        string tradeType, string trendReq, string emaReq)
  {
   string key = colorType + "|" + action + "|" + tradeType + "|" + trendReq + "|" + emaReq;
   for(int i = 0; i < g_cpStatsCount; i++)
      if(g_cpStats[i].active &&
         g_cpStats[i].colorType     == colorType  &&
         g_cpStats[i].action        == action      &&
         g_cpStats[i].tradeType     == tradeType   &&
         g_cpStats[i].trendRequired == trendReq    &&
         g_cpStats[i].emaRequired   == emaReq)
         return i;

   if(g_cpStatsCount >= CP_STATS_MAX) return -1;
   int s = g_cpStatsCount++;
   g_cpStats[s].colorType     = colorType;
   g_cpStats[s].action        = action;
   g_cpStats[s].tradeType     = tradeType;
   g_cpStats[s].trendRequired = trendReq;
   g_cpStats[s].emaRequired   = emaReq;
   g_cpStats[s].count         = 0;
   g_cpStats[s].wins          = 0;
   g_cpStats[s].totalFavourUSD  = 0;
   g_cpStats[s].totalAdverseUSD = 0;
   g_cpStats[s].totalRR         = 0;
   g_cpStats[s].bestProfitUSD   = 0;
   g_cpStats[s].worstLossUSD    = 0;
   g_cpStats[s].slHits          = 0;
   g_cpStats[s].totalSlLossUSD  = 0;
   g_cpStats[s].active          = true;
   return s;
  }

//+------------------------------------------------------------------+
//| Record a ColorRule-triggered signal observation                  |
//+------------------------------------------------------------------+
void CPRecordSignal(int colorRuleIdx)
  {
   if(g_cpSignalFile == "") return;
   if(colorRuleIdx < 0 || colorRuleIdx >= ArraySize(g_colorRules)) return;

   // Find free slot
   int slot = -1;
   for(int i = 0; i < CP_OBS_MAX; i++)
      if(!g_cpObs[i].active) { slot = i; break; }
   if(slot < 0)
      for(int i = 0; i < CP_OBS_MAX; i++)
         if(g_cpObs[i].written) { slot = i; break; }
   if(slot < 0) return;

   ColorRule cr = g_colorRules[colorRuleIdx];

   g_cpObs[slot].colorType     = cr.colorType;
   g_cpObs[slot].signalName    = g_liveSignalName;
   g_cpObs[slot].seqCount      = g_currSeqCount;
   g_cpObs[slot].action        = cr.action;
   g_cpObs[slot].tradeType     = cr.tradeType;
   g_cpObs[slot].trendRequired = cr.trendRequired;
   g_cpObs[slot].emaRequired   = cr.emaRequired;
   g_cpObs[slot].signalTime    = TimeCurrent();
   g_cpObs[slot].isSell        = (cr.tradeType == "SELL");
   g_cpObs[slot].entryPrice    = g_cpObs[slot].isSell
                                  ? MarketInfo(Symbol(), MODE_BID)
                                  : MarketInfo(Symbol(), MODE_ASK);
   g_cpObs[slot].maxFavourUSD  = 0;
   g_cpObs[slot].maxAdverseUSD = 0;
   g_cpObs[slot].barsObserved  = 0;
   g_cpObs[slot].active        = true;
   g_cpObs[slot].written       = false;
   g_cpObs[slot].finalizeReason= "TIMEOUT";
   if(g_cpObsCount <= slot) g_cpObsCount = slot + 1;
  }

//+------------------------------------------------------------------+
//| Rewrite aggregated stats CSV                                     |
//+------------------------------------------------------------------+
void CPWriteStatsCSV()
  {
   int h = FileOpen(g_cpStatsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "ColorType,Action,TradeType,TrendFilter,EMAFilter,"
      "Samples,Wins,Losses,WinRate%,"
      "AvgProfit_USD,AvgLoss_USD,AvgRR,"
      "BestProfit_USD,WorstLoss_USD,"
      "SL_HitRate%,AvgSL_Loss_USD,"
      "Verdict,Score,BotAdvice\n");

   for(int i = 0; i < g_cpStatsCount; i++)
     {
      if(!g_cpStats[i].active) continue;
      ColorPatternStats s = g_cpStats[i];

      int    losses    = s.count - s.wins;
      double winRate   = (s.count  > 0) ? s.wins          * 100.0 / s.count  : 0;
      double avgProfit = (s.wins   > 0) ? s.totalFavourUSD  / s.wins  : 0;
      double avgLoss   = (losses   > 0) ? s.totalAdverseUSD / losses  : 0;
      double avgRR     = (s.count  > 0) ? s.totalRR         / s.count : 0;
      double slRate    = (s.count  > 0) ? s.slHits * 100.0  / s.count : 0;
      double avgSlLoss = (s.slHits > 0) ? s.totalSlLossUSD  / s.slHits: 0;

      // Score: same formula as Top5
      double slPenalty = (slRate > 30) ? (slRate - 30) * 0.3 : 0;
      double score     = winRate * 0.5 + avgRR * 25.0 + avgProfit * 5.0 - slPenalty;

      // Verdict
      string verdict  = "MONITOR";
      string advice   = "";

      if(s.count < 3)
        {
         verdict = "LEARNING";
         advice  = "Only " + IntegerToString(s.count) + " sample(s). Need at least 3 to judge.";
        }
      else if(winRate >= 65 && avgRR >= 1.5)
        {
         verdict = "GOOD_PATTERN";
         advice  = "Strong! Win rate " + DoubleToString(winRate,0) + "%" +
                   " avg profit $" + DoubleToString(avgProfit,2) +
                   " avg loss $"   + DoubleToString(avgLoss,2) + "." +
                   " Best seen $"  + DoubleToString(s.bestProfitUSD,2) + ".";
        }
      else if(winRate >= 50 && avgRR >= 1.0)
        {
         verdict = "GOOD_PATTERN";
         advice  = "Reliable. Win rate " + DoubleToString(winRate,0) + "%" +
                   " avg profit $" + DoubleToString(avgProfit,2) + ".";
        }
      else if(winRate >= 40)
        {
         verdict = "MONITOR";
         advice  = "Mixed results. Win rate " + DoubleToString(winRate,0) + "%." +
                   " Add EMA/trend filter to improve.";
        }
      else
        {
         verdict = "BAD_PATTERN";
         advice  = "Poor! Win rate " + DoubleToString(winRate,0) + "%." +
                   " Avg loss $" + DoubleToString(avgLoss,2) +
                   " worst $"    + DoubleToString(s.worstLossUSD,2) + "." +
                   " STOP TRADING this color rule.";
        }

      if(slRate >= 50)
         advice += " WARNING: SL hit " + DoubleToString(slRate,0) + "% — too risky!";

      // Suggest EMA/trend filter if not already applied
      if(verdict != "GOOD_PATTERN" && s.trendRequired == "" && s.count >= 3)
         advice += " TRY: add trendRequired=\"" +
                   (s.tradeType == "SELL" ? "DOWNTREND" : "UPTREND") + "\" to filter noise.";
      if(verdict != "GOOD_PATTERN" && s.emaRequired == "" && s.count >= 3)
         advice += " TRY: add emaRequired=\"" +
                   (s.tradeType == "SELL" ? "DOWN" : "UP") + "\" to avoid flat EMA entries.";

      string trendDisp = (s.trendRequired == "") ? "NONE" : s.trendRequired;
      string emaDisp   = (s.emaRequired   == "") ? "NONE" : s.emaRequired;

      string row =
         "\"" + s.colorType + "\""      + "," +
         s.action                       + "," +
         s.tradeType                    + "," +
         trendDisp                      + "," +
         emaDisp                        + "," +
         IntegerToString(s.count)       + "," +
         IntegerToString(s.wins)        + "," +
         IntegerToString(losses)        + "," +
         DoubleToString(winRate,   1)   + "," +
         DoubleToString(avgProfit, 2)   + "," +
         DoubleToString(avgLoss,   2)   + "," +
         DoubleToString(avgRR,     2)   + "," +
         DoubleToString(s.bestProfitUSD,2) + "," +
         DoubleToString(s.worstLossUSD, 2) + "," +
         DoubleToString(slRate,    1)   + "," +
         DoubleToString(avgSlLoss, 2)   + "," +
         verdict                        + "," +
         DoubleToString(score,     1)   + "," +
         "\"" + advice + "\""           + "\n";

      FileWriteString(h, row);
     }

   FileWriteString(h, "\n\"Updated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) +
                      " | Total color rules tracked: " + IntegerToString(g_cpStatsCount) + "\"\n");
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Finalize one observation — write signal row + update stats       |
//+------------------------------------------------------------------+
void CPFinalizeObs(int slot)
  {
   if(g_cpSignalFile == "") return;
   ColorPatternObs r = g_cpObs[slot];

   double rr      = (r.maxAdverseUSD > 0) ? r.maxFavourUSD / r.maxAdverseUSD : 0;
   bool   isWin   = (r.maxFavourUSD  > r.maxAdverseUSD);
   string outcome = isWin ? "WIN" : (r.maxAdverseUSD > r.maxFavourUSD ? "LOSS" : "NEUTRAL");

   double slSetting = r.isSell ? SeqSellStopLossUSD : SeqBuyStopLossUSD;
   bool   slHit     = (r.maxAdverseUSD >= slSetting);

   // Bot advice per signal
   string advice = "";
   if(isWin)
      advice = "WIN $" + DoubleToString(r.maxFavourUSD,2) +
               " RR=" + DoubleToString(rr,2) + " — good entry.";
   else
      advice = "LOSS $" + DoubleToString(r.maxAdverseUSD,2) +
               " RR=" + DoubleToString(rr,2);
   if(slHit) advice += " SL HIT.";

   string trendDisp = (r.trendRequired == "") ? "NONE" : r.trendRequired;
   string emaDisp   = (r.emaRequired   == "") ? "NONE" : r.emaRequired;

   // Write signal row
   string row =
      TimeToString(r.signalTime, TIME_DATE|TIME_SECONDS) + "," +
      "\"" + r.colorType + "\""                          + "," +
      "\"" + r.signalName + " " + IntegerToString(r.seqCount) + "\"" + "," +
      IntegerToString(r.seqCount)                        + "," +
      r.action                                           + "," +
      r.tradeType                                        + "," +
      trendDisp                                          + "," +
      emaDisp                                            + "," +
      DoubleToString(r.entryPrice,   5)                  + "," +
      DoubleToString(r.maxFavourUSD, 2)                  + "," +
      DoubleToString(r.maxAdverseUSD,2)                  + "," +
      DoubleToString(rr,             2)                  + "," +
      outcome                                            + "," +
      r.finalizeReason                                   + "," +
      "\"" + advice + "\""                               + "\n";

   int h = FileOpen(g_cpSignalFile, FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_cpSignalFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     { FileSeek(h, 0, SEEK_END); FileWriteString(h, row); FileClose(h); }

   // Update stats
   int si = CPFindOrCreateStats(r.colorType, r.action, r.tradeType,
                                 r.trendRequired, r.emaRequired);
   if(si >= 0)
     {
      g_cpStats[si].count++;
      g_cpStats[si].totalRR += rr;
      if(isWin)
        {
         g_cpStats[si].wins++;
         g_cpStats[si].totalFavourUSD += r.maxFavourUSD;
         if(r.maxFavourUSD > g_cpStats[si].bestProfitUSD)
            g_cpStats[si].bestProfitUSD = r.maxFavourUSD;
        }
      else
        {
         g_cpStats[si].totalAdverseUSD += r.maxAdverseUSD;
         if(r.maxAdverseUSD > g_cpStats[si].worstLossUSD)
            g_cpStats[si].worstLossUSD = r.maxAdverseUSD;
        }
      if(slHit)
        {
         g_cpStats[si].slHits++;
         g_cpStats[si].totalSlLossUSD += slSetting;
        }
      CPWriteStatsCSV();
     }

   Print("ColorPattern AI | [" + r.colorType + " " + r.signalName + " " +
         IntegerToString(r.seqCount) + "] " + outcome +
         " Favour=$" + DoubleToString(r.maxFavourUSD,2) +
         " Adverse=$" + DoubleToString(r.maxAdverseUSD,2) +
         " RR=" + DoubleToString(rr,2) +
         " | " + r.finalizeReason);
  }

//+------------------------------------------------------------------+
//| Update active observations every tick                            |
//+------------------------------------------------------------------+
void CPUpdateObservations()
  {
   if(g_cpSignalFile == "") return;

   double bid = MarketInfo(Symbol(), MODE_BID);
   double ask = MarketInfo(Symbol(), MODE_ASK);

   for(int s = 0; s < g_cpObsCount; s++)
     {
      if(!g_cpObs[s].active || g_cpObs[s].written) continue;

      double entryPx  = g_cpObs[s].entryPrice;
      double favour   = 0, adverse = 0;

      if(g_cpObs[s].isSell)
        { favour = (entryPx - bid) / Point;  adverse = (ask - entryPx) / Point; }
      else
        { favour = (ask - entryPx) / Point;  adverse = (entryPx - bid) / Point; }

      if(favour  < 0) favour  = 0;
      if(adverse < 0) adverse = 0;

      double favUSD = PointsToUSD(favour,  g_cpObs[s].isSell);
      double advUSD = PointsToUSD(adverse, g_cpObs[s].isSell);

      if(favUSD > g_cpObs[s].maxFavourUSD)  g_cpObs[s].maxFavourUSD  = favUSD;
      if(advUSD > g_cpObs[s].maxAdverseUSD) g_cpObs[s].maxAdverseUSD = advUSD;

      int barsNow = iBarShift(Symbol(), PERIOD_M1, g_cpObs[s].signalTime, false);
      g_cpObs[s].barsObserved = barsNow;

      // Early finalization
      double rr = (g_cpObs[s].maxAdverseUSD > 0)
                  ? g_cpObs[s].maxFavourUSD / g_cpObs[s].maxAdverseUSD : 0;

      if(barsNow >= LearnEarlyMinBars)
        {
         if(rr >= LearnEarlyWinRR)
           { g_cpObs[s].finalizeReason = "EARLY_WIN";  goto finalize; }
         if(g_cpObs[s].maxAdverseUSD > g_cpObs[s].maxFavourUSD * LearnEarlyLossRatio)
           { g_cpObs[s].finalizeReason = "EARLY_LOSS"; goto finalize; }
        }

      if(barsNow >= LearnObserveBars)
        { g_cpObs[s].finalizeReason = "TIMEOUT"; goto finalize; }
      continue;

      finalize:
      CPFinalizeObs(s);
      g_cpObs[s].active  = false;
      g_cpObs[s].written = true;
     }
  }

#endif
