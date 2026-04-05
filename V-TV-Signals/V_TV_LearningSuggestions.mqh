//+------------------------------------------------------------------+
//| V_TV_LearningSuggestions.mqh                                     |
//|                                                                  |
//| AI BOT PATTERN ANALYSER (Spike-aware)                            |
//| ---------------------------------------------------------------  |
//| How it works:                                                    |
//|  1. Every signal fires → record entry price + EMA + spike state  |
//|  2. Every tick → track how far price moved (favour / adverse)    |
//|  3. After N bars → finalise, write to Suggestions CSV            |
//|  4. Aggregate by pattern → PatternStats with spike win rates     |
//|  5. Journal bot advice: spike vs no-spike performance compared   |
//|                                                                  |
//| FILES:                                                           |
//|  Suggestions_DATE_SYMBOL.csv  - every signal, every session      |
//|  PatternStats_SYMBOL.csv      - aggregated verdict per pattern   |
//+------------------------------------------------------------------+
#ifndef V_TV_LEARNING_SUGGESTIONS_MQH
#define V_TV_LEARNING_SUGGESTIONS_MQH

//--- Config inputs --------------------------------------------------
input string _Learn_              = "--- AI BOT ANALYSER ---";
input int    LearnObserveBars     = 30;  // Max bars to track after each signal
input double LearnMinRR           = 1.5; // Min R:R to mark STRONG
input bool   LearnEnabled         = true;// Enable/disable AI analyser
input int    SpikeSearchBars      = 5;   // How many bars back to look for a recent spike
input double LearnEarlyWinRR      = 2.5; // Finalize early if R:R reaches this (clear win)
input double LearnEarlyLossRatio  = 3.0; // Finalize early if adverse > favour * this (clear loss)
input int    LearnEarlyMinBars    = 5;   // Min bars before early finalization allowed

//+------------------------------------------------------------------+
//| Per-signal observation (one row in Suggestions CSV)              |
//+------------------------------------------------------------------+
struct SignalObservation
  {
   string   label;
   string   prePrev;
   string   prev;
   datetime signalTime;
   double   entryPrice;
   double   ema1;
   double   ema2;
   bool     isSell;
   double   maxFavour;       // points
   double   maxAdverse;      // points
   int      barsObserved;
   // Spike context at signal time
   string   spikeContext;    // "AFTER_SPIKE_UP" / "AFTER_SPIKE_DOWN" / "NO_SPIKE"
   int      barsAfterSpike;  // bars since the spike (0 = spike on same bar)
   double   spikeSizePts;    // spike candle range in points
   bool     active;
   bool     written;
   bool     earlyFinalized;  // true if closed before LearnObserveBars
   string   finalizeReason;  // "EARLY_WIN" / "EARLY_LOSS" / "TIMEOUT"
   int      milestone25;     // 1 once printed at 25% progress
   int      milestone50;
   int      milestone75;
  };

#define OBS_MAX 100
SignalObservation g_obs[OBS_MAX];

//+------------------------------------------------------------------+
//| Per-pattern aggregated stats (one row in PatternStats CSV)       |
//+------------------------------------------------------------------+
struct PatternStats
  {
   string key;
   string prePrev;
   string prev;
   string label;
   string direction;
   int    count;
   int    wins;
   double totalFavourUSD;
   double totalAdverseUSD;
   double totalRR;
   double bestProfitUSD;
   double worstLossUSD;
   int    emaAlignedWins;
   int    emaAlignedTotal;
   // Spike split stats
   int    spikeWins;         // wins where signal came after a spike
   int    spikeTotal;        // total observations after a spike
   int    noSpikeWins;       // wins with no recent spike
   int    noSpikeTotal;      // total observations without spike
   // Stop loss analysis
   int    slHits;            // times SL would have been triggered
   int    slPrematureHits;   // SL hit BUT price later went in favour (SL too tight)
   double totalSlLossUSD;    // cumulative loss from SL hits
   // ALL-observation totals for TP/SL recommendation
   double totalObsFavourUSD;  // sum of maxFavourUSD across every observation
   double totalObsAdverseUSD; // sum of maxAdverseUSD across every observation
   double maxObsFavourUSD;    // single best favour seen (upper bound for TP)
   double maxObsAdverseUSD;   // worst adverse seen (absolute SL floor needed)
   bool   active;
  };

#define STATS_MAX 50
PatternStats g_stats[STATS_MAX];
int          g_statsCount = 0;

string   g_suggestFile    = "";
string   g_statsFile      = "";
string   g_top5File       = "";   // Top5Patterns_SYMBOL.csv — best actionable patterns
string   g_liveFile       = "";   // LiveTraining_SYMBOL.csv — rewritten every bar
datetime g_lastLiveBar    = 0;    // last bar time when live CSV was updated

//+------------------------------------------------------------------+
//| Helper: points → USD                                             |
//+------------------------------------------------------------------+
double PointsToUSD(double pts, bool isSell)
  {
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lot       = isSell ? SeqSellLotSize : SeqBuyLotSize;
   if(tickSize <= 0) return 0;
   return NormalizeDouble(pts * (Point / tickSize) * tickValue * lot, 2);
  }

//+------------------------------------------------------------------+
//| Detect if a spike occurred within SpikeSearchBars of current bar |
//| Returns bars-since-spike (0=same bar), -1 if none found          |
//| spikeDir: 1=up  -1=down  0=none                                  |
//+------------------------------------------------------------------+
int DetectRecentSpike(int &spikeDir, double &spikeSizePts)
  {
   spikeDir     = 0;
   spikeSizePts = 0;

   for(int offset = 0; offset <= SpikeSearchBars; offset++)
     {
      int b = offset;
      if(b + SpikeLookback >= Bars) continue;

      double avgRange = 0;
      for(int k = b + 1; k <= b + SpikeLookback; k++)
         avgRange += (High[k] - Low[k]);
      avgRange /= SpikeLookback;
      if(avgRange <= 0) continue;

      double candleRange = High[b] - Low[b];
      if(candleRange < avgRange * SpikeMultiplier) continue;

      double body      = MathAbs(Open[b] - Close[b]);
      double upperWick = High[b]  - MathMax(Open[b], Close[b]);
      double lowerWick = MathMin(Open[b], Close[b]) - Low[b];

      bool isUp   = (upperWick > body * 1.5);
      bool isDown = (lowerWick > body * 1.5);
      if(!isUp && !isDown)
        {
         if(Close[b] > Open[b]) isDown = true;
         else                   isUp   = true;
        }

      spikeDir     = isUp ? 1 : -1;
      spikeSizePts = candleRange / Point;
      return offset;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Init both CSV files                                              |
//+------------------------------------------------------------------+
void InitLearningSuggestions()
  {
   if(!LearnEnabled) return;

   g_suggestFile = "AI_Suggestions_" + g_runTimestamp + "_" + Symbol() + ".csv";
   g_statsFile   = "PatternStats_" + g_runTimestamp + "_" + Symbol() + ".csv";
   g_top5File    = "Top5Patterns_" + g_runTimestamp + "_" + Symbol() + ".csv";

   // Suggestions CSV — write header only for new file
   bool needHeader = true;
   int h = FileOpen(g_suggestFile, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      if(FileSize(h) > 0) needHeader = false;
      FileClose(h);
     }
   if(needHeader)
     {
      h = FileOpen(g_suggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h,
            "SignalTime,Signal,PrePrev,Prev,Direction,EntryPrice,"
            "EMA1,EMA2,EMA1_Trend,EMA_Structure,"
            "SpikeContext,BarsAfterSpike,SpikeSize_pts,"
            "MaxFavourPts,MaxFavourUSD,MaxAdversePts,MaxAdverseUSD,"
            "RewardRisk,Outcome,FinalizeReason,MissedProfit_USD,"
            "SL_Setting_USD,SL_WouldHit,SL_PrematureHit,"
            "SuggestedTP_pts,SuggestedTP_USD,SuggestedSL_pts,SuggestedSL_USD,"
            "Rating,BotAdvice\n");
         FileClose(h);
        }
     }

   // LiveTraining CSV — always fresh on init
   g_liveFile = "AI_LiveTraining_" + g_runTimestamp + "_" + Symbol() + ".csv";
   h = FileOpen(g_liveFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h,
         "Signal,Direction,SpikeContext,EntryPrice,BarsObserved,Progress%,"
         "CurrentRR,MaxFavourPts,MaxFavourUSD,MaxAdversePts,MaxAdverseUSD,"
         "Status,LiveVerdict\n");
      FileClose(h);
     }

   // PatternStats CSV — always rewrite header on init
   h = FileOpen(g_statsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h,
         "Pattern,Direction,Times_Seen,Wins,Losses,WinRate%,"
         "AvgProfit_USD,AvgLoss_USD,AvgRR,"
         "BestProfit_USD,WorstLoss_USD,"
         "EMA_WinRate%,"
         "SpikeWinRate%,NoSpikeWinRate%,SpikeSamples,NoSpikeSamples,"
         "SL_HitRate%,SL_PrematureRate%,AvgSL_Loss_USD,SL_Warning,SL_Advice,"
         "AvgMaxFavour_USD,AvgMaxAdverse_USD,BestFavour_USD,WorstAdverse_USD,"
         "Recommended_TP_USD,Recommended_SL_USD,TP_Assessment,SL_Assessment,Action_Required,"
         "Verdict,BotAdvice\n");
      FileClose(h);
     }

   for(int i = 0; i < OBS_MAX;   i++) g_obs[i].active    = false;
   for(int i = 0; i < STATS_MAX; i++) g_stats[i].active  = false;
   g_statsCount = 0;

   //Print("AI BOT: Initialised -> " + g_suggestFile);
   //Print("AI BOT: Pattern stats -> " + g_statsFile);
  }

//+------------------------------------------------------------------+
//| Called at every signal fire                                      |
//+------------------------------------------------------------------+
void LearnRecordSignal(string label, string prevSig, string prePrevSig,
                       double entryPrice, bool isSell)
  {
   if(!LearnEnabled) return;

   int slot = -1;
   for(int i = 0; i < OBS_MAX; i++)
      if(!g_obs[i].active) { slot = i; break; }
   if(slot < 0)
      for(int i = 0; i < OBS_MAX; i++)
         if(g_obs[i].written) { slot = i; break; }
   if(slot < 0) return;

   int    emaPeriod = isSell ? SeqSellEMAPeriod : SeqBuyEMAPeriod;
   int    ema2Per   = isSell ? SeqSellEMA2Period : SeqBuyEMA2Period;

   // Detect spike context at this signal bar
   int    spikeDir  = 0;
   double spikeSize = 0;
   int    barsAgo   = DetectRecentSpike(spikeDir, spikeSize);

   string spikeCtx = "NO_SPIKE";
   if(barsAgo >= 0)
      spikeCtx = (spikeDir > 0) ? "AFTER_SPIKE_UP" : "AFTER_SPIKE_DOWN";

   g_obs[slot].label          = label;
   g_obs[slot].prePrev        = prePrevSig;
   g_obs[slot].prev           = prevSig;
   g_obs[slot].signalTime     = TimeCurrent();
   g_obs[slot].entryPrice     = entryPrice;
   g_obs[slot].ema1           = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   g_obs[slot].ema2           = iMA(Symbol(), 0, ema2Per,   0, MODE_EMA, PRICE_CLOSE, 0);
   g_obs[slot].isSell         = isSell;
   g_obs[slot].maxFavour      = 0;
   g_obs[slot].maxAdverse     = 0;
   g_obs[slot].barsObserved   = 0;
   g_obs[slot].spikeContext   = spikeCtx;
   g_obs[slot].barsAfterSpike = (barsAgo >= 0) ? barsAgo : 0;
   g_obs[slot].spikeSizePts   = spikeSize;
   g_obs[slot].active          = true;
   g_obs[slot].written         = false;
   g_obs[slot].earlyFinalized  = false;
   g_obs[slot].finalizeReason  = "TIMEOUT";
   g_obs[slot].milestone25     = 0;
   g_obs[slot].milestone50     = 0;
   g_obs[slot].milestone75     = 0;

   // Immediate journal note if spike detected
   //if(barsAgo >= 0)
     /*Print("AI BOT | [" + label + "] fired " + IntegerToString(barsAgo) +
            " bar(s) after " + spikeCtx + " (" + DoubleToString(spikeSize,0) + "pts)" +
            " - tracking reversal quality...");*/
  }

//+------------------------------------------------------------------+
//| Find or create pattern stats slot                                |
//+------------------------------------------------------------------+
int FindOrCreateStats(string prePrev, string prev, string label, string dir)
  {
   string key = prePrev + "|" + prev + "|" + label + "|" + dir;
   for(int i = 0; i < STATS_MAX; i++)
      if(g_stats[i].active && g_stats[i].key == key) return i;

   if(g_statsCount >= STATS_MAX) return -1;
   int s = g_statsCount++;
   g_stats[s].key             = key;
   g_stats[s].prePrev         = prePrev;
   g_stats[s].prev            = prev;
   g_stats[s].label           = label;
   g_stats[s].direction       = dir;
   g_stats[s].count           = 0;
   g_stats[s].wins            = 0;
   g_stats[s].totalFavourUSD  = 0;
   g_stats[s].totalAdverseUSD = 0;
   g_stats[s].totalRR         = 0;
   g_stats[s].bestProfitUSD   = 0;
   g_stats[s].worstLossUSD    = 0;
   g_stats[s].emaAlignedWins  = 0;
   g_stats[s].emaAlignedTotal = 0;
   g_stats[s].spikeWins       = 0;
   g_stats[s].spikeTotal      = 0;
   g_stats[s].noSpikeWins     = 0;
   g_stats[s].noSpikeTotal    = 0;
   g_stats[s].slHits             = 0;
   g_stats[s].slPrematureHits    = 0;
   g_stats[s].totalSlLossUSD     = 0;
   g_stats[s].totalObsFavourUSD  = 0;
   g_stats[s].totalObsAdverseUSD = 0;
   g_stats[s].maxObsFavourUSD    = 0;
   g_stats[s].maxObsAdverseUSD   = 0;
   g_stats[s].active             = true;
   return s;
  }

//+------------------------------------------------------------------+
//| Write Top5Patterns CSV — best actionable patterns ranked by score|
//| Score = WinRate% * 0.5 + AvgRR * 25 + AvgProfit * 5            |
//| Rewritten every time stats are updated                          |
//+------------------------------------------------------------------+
void WriteTop5PatternsCSV()
  {
   if(g_top5File == "") return;

   // --- Score each eligible pattern ---
   int    ranked[STATS_MAX];
   double scores[STATS_MAX];
   int    eligibleCount = 0;

   for(int i = 0; i < g_statsCount; i++)
     {
      if(!g_stats[i].active || g_stats[i].count < 3) continue;  // need min 3 samples

      PatternStats s = g_stats[i];
      int    losses      = s.count - s.wins;
      double winRate     = s.wins  * 100.0 / s.count;
      double avgProfit   = (s.wins   > 0) ? s.totalFavourUSD  / s.wins  : 0;
      double avgRR       = (s.count  > 0) ? s.totalRR         / s.count : 0;
      double slHitRate   = (s.count  > 0) ? s.slHits * 100.0  / s.count : 0;

      // Score formula: win rate is most important, then RR, then avg profit
      // Penalise heavy SL hit rate (subtract 0.3 per % above 30%)
      double slPenalty = (slHitRate > 30) ? (slHitRate - 30) * 0.3 : 0;
      double score     = winRate * 0.5 + avgRR * 25.0 + avgProfit * 5.0 - slPenalty;

      ranked[eligibleCount] = i;
      scores[eligibleCount] = score;
      eligibleCount++;
     }

   // --- Bubble sort descending by score (top 5 only, small array) ---
   for(int a = 0; a < eligibleCount - 1; a++)
      for(int b = a + 1; b < eligibleCount; b++)
         if(scores[b] > scores[a])
           {
            double tmpS = scores[a]; scores[a] = scores[b]; scores[b] = tmpS;
            int    tmpI = ranked[a]; ranked[a] = ranked[b]; ranked[b] = tmpI;
           }

   int top = (eligibleCount < 5) ? eligibleCount : 5;

   // --- Write CSV ---
   int h = FileOpen(g_top5File, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "Rank,Pattern,Direction,Samples,WinRate%,AvgRR,"
      "AvgMaxFavour_USD,AvgMaxAdverse_USD,"
      "Recommended_TP_USD,Recommended_SL_USD,"
      "Current_TP_USD,Current_SL_USD,"
      "TP_Assessment,SL_Assessment,"
      "SL_HitRate%,SL_PrematureRate%,"
      "BestProfit_USD,Score,"
      "Action,Trade_Advice\n");

   for(int r = 0; r < top; r++)
     {
      int i = ranked[r];
      PatternStats s = g_stats[i];

      int    losses       = s.count - s.wins;
      double winRate      = s.wins  * 100.0 / s.count;
      double avgProfit    = (s.wins  > 0) ? s.totalFavourUSD  / s.wins   : 0;
      double avgLoss      = (losses  > 0) ? s.totalAdverseUSD / losses   : 0;
      double avgRR        = (s.count > 0) ? s.totalRR         / s.count  : 0;
      double avgFavour    = (s.count > 0) ? s.totalObsFavourUSD  / s.count : 0;
      double avgAdverse   = (s.count > 0) ? s.totalObsAdverseUSD / s.count : 0;
      double recTP        = NormalizeDouble(avgFavour  * 0.75, 2);
      double recSL        = NormalizeDouble(avgAdverse * 1.20, 2);
      if(recSL < 0.01) recSL = 0.01;
      double curTP        = (s.direction == "SELL") ? SeqSellProfitTarget : SeqBuyProfitTarget;
      double curSL        = (s.direction == "SELL") ? SeqSellStopLossUSD  : SeqBuyStopLossUSD;
      double slHitRate    = (s.count  > 0) ? s.slHits          * 100.0 / s.count  : 0;
      double slPremRate   = (s.slHits > 0) ? s.slPrematureHits * 100.0 / s.slHits : 0;

      // TP assessment
      string tpAssess = "OK";
      if(curTP > avgFavour * 0.9)       tpAssess = "TOO_AMBITIOUS";
      else if(curTP < avgFavour * 0.4)  tpAssess = "TOO_TIGHT";

      // SL assessment
      string slAssess = "OK";
      if(curSL < avgAdverse * 0.8)                       slAssess = "TOO_TIGHT";
      else if(curSL > avgAdverse * 2.5 && avgAdverse > 0) slAssess = "TOO_WIDE";

      // Action label
      string action = "TRADE_IT";
      if(winRate < 55)      action = "MONITOR";
      if(winRate < 40)      action = "AVOID";
      if(slHitRate >= 60)   action = "REDUCE_LOT";

      // Plain-English trade advice
      string advice = "";
      advice += "Win rate " + DoubleToString(winRate,0) + "% over " + IntegerToString(s.count) + " trades. ";
      advice += "Set TP=$" + DoubleToString(recTP,2) + " SL=$" + DoubleToString(recSL,2) + ". ";
      if(tpAssess == "TOO_AMBITIOUS")
         advice += "Lower your TP — market rarely reaches current target ($" + DoubleToString(curTP,2) + "). ";
      else if(tpAssess == "TOO_TIGHT")
         advice += "Raise your TP — market has more room. ";
      if(slAssess == "TOO_TIGHT")
         advice += "SL too tight! Hits " + DoubleToString(slHitRate,0) + "% of trades — widen to $" + DoubleToString(recSL,2) + ". ";
      else if(slAssess == "TOO_WIDE")
         advice += "SL wider than needed — tighten to $" + DoubleToString(recSL,2) + " to protect capital. ";
      if(slPremRate >= 40)
         advice += "WARNING: " + DoubleToString(slPremRate,0) + "% of SL hits were premature (price recovered). ";
      if(s.spikeTotal > 0 && s.noSpikeTotal > 0)
        {
         double swr = s.spikeWins   * 100.0 / s.spikeTotal;
         double nwr = s.noSpikeWins * 100.0 / s.noSpikeTotal;
         if(swr > nwr + 20)       advice += "Best after spikes (" + DoubleToString(swr,0) + "% win). ";
         else if(nwr > swr + 20)  advice += "Avoid after spikes (" + DoubleToString(swr,0) + "% vs " + DoubleToString(nwr,0) + "%). ";
        }

      string pattern = s.prePrev + " > " + s.prev + " > " + s.label;

      string row =
         IntegerToString(r + 1)           + "," +
         "\"" + pattern + "\""            + "," +
         s.direction                      + "," +
         IntegerToString(s.count)         + "," +
         DoubleToString(winRate,   1)     + "," +
         DoubleToString(avgRR,     2)     + "," +
         DoubleToString(avgFavour, 2)     + "," +
         DoubleToString(avgAdverse,2)     + "," +
         DoubleToString(recTP,     2)     + "," +
         DoubleToString(recSL,     2)     + "," +
         DoubleToString(curTP,     2)     + "," +
         DoubleToString(curSL,     2)     + "," +
         tpAssess                         + "," +
         slAssess                         + "," +
         DoubleToString(slHitRate, 1)     + "," +
         DoubleToString(slPremRate,1)     + "," +
         DoubleToString(s.bestProfitUSD,2)+ "," +
         DoubleToString(scores[r], 1)     + "," +
         action                           + "," +
         "\"" + advice + "\""             + "\n";

      FileWriteString(h, row);
     }

   // Footer: summary line
   if(top == 0)
      FileWriteString(h, "\"No patterns with 3+ samples yet. Keep running the EA.\"\n");
   else
      FileWriteString(h, "\n\"Updated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) +
                         " | Total patterns: " + IntegerToString(g_statsCount) +
                         " | Eligible (3+ samples): " + IntegerToString(eligibleCount) + "\"\n");

   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Rewrite full PatternStats CSV                                    |
//+------------------------------------------------------------------+
void WritePatternStatsCSV()
  {
   int h = FileOpen(g_statsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "Pattern,Direction,Times_Seen,Wins,Losses,WinRate%,"
      "AvgProfit_USD,AvgLoss_USD,AvgRR,"
      "BestProfit_USD,WorstLoss_USD,"
      "EMA_WinRate%,"
      "SpikeWinRate%,NoSpikeWinRate%,SpikeSamples,NoSpikeSamples,"
      "SL_HitRate%,SL_PrematureRate%,AvgSL_Loss_USD,SL_Warning,SL_Advice,"
      "AvgMaxFavour_USD,AvgMaxAdverse_USD,BestFavour_USD,WorstAdverse_USD,"
      "Recommended_TP_USD,Recommended_SL_USD,TP_Assessment,SL_Assessment,Action_Required,"
      "Verdict,BotAdvice\n");

   for(int i = 0; i < g_statsCount; i++)
     {
      if(!g_stats[i].active) continue;
      PatternStats s = g_stats[i];

      int    losses       = s.count - s.wins;
      double winRate      = (s.count > 0)           ? (s.wins            * 100.0 / s.count)           : 0;
      double avgProfit    = (s.wins   > 0)           ? (s.totalFavourUSD  / s.wins)                    : 0;
      double avgLoss      = (losses   > 0)           ? (s.totalAdverseUSD / losses)                    : 0;
      double avgRR        = (s.count  > 0)           ? (s.totalRR         / s.count)                   : 0;
      double emaWinRate   = (s.emaAlignedTotal > 0)  ? (s.emaAlignedWins  * 100.0 / s.emaAlignedTotal) : 0;
      double spikeWinRate = (s.spikeTotal   > 0)     ? (s.spikeWins       * 100.0 / s.spikeTotal)      : -1;
      double noSpikeWR    = (s.noSpikeTotal > 0)     ? (s.noSpikeWins     * 100.0 / s.noSpikeTotal)    : -1;

      // Build spike insight string
      string spikeInsight = "";
      if(spikeWinRate >= 0 && noSpikeWR >= 0)
        {
         if(spikeWinRate > noSpikeWR + 20)
            spikeInsight = "WORKS BEST AFTER SPIKES (" + DoubleToString(spikeWinRate,0) +
                           "% spike vs " + DoubleToString(noSpikeWR,0) + "% no-spike). ";
         else if(noSpikeWR > spikeWinRate + 20)
            spikeInsight = "AVOID AFTER SPIKES (" + DoubleToString(spikeWinRate,0) +
                           "% spike vs " + DoubleToString(noSpikeWR,0) + "% no-spike). ";
         else
            spikeInsight = "Spike does not significantly affect this pattern. ";
        }
      else if(spikeWinRate >= 0)
         spikeInsight = "Only spike data available (" + DoubleToString(spikeWinRate,0) + "% win). ";
      else if(noSpikeWR >= 0)
         spikeInsight = "No spike data yet (no-spike win " + DoubleToString(noSpikeWR,0) + "%). ";

      // Verdict
      string verdict  = "MONITOR";
      string botAdvice = "";

      if(s.count < 2)
        {
         verdict   = "LEARNING";
         botAdvice = "Only " + IntegerToString(s.count) + " sample(s). Need more data. " + spikeInsight;
        }
      else if(winRate >= 65 && avgRR >= 1.5)
        {
         verdict   = "TRADE_IT";
         botAdvice = "Strong edge! Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg profit $" + DoubleToString(avgProfit,2) +
                     " vs loss $"   + DoubleToString(avgLoss,2)   + ". " +
                     "Best seen $"  + DoubleToString(s.bestProfitUSD,2) + ". " +
                     spikeInsight;
        }
      else if(winRate >= 55 && avgRR >= 1.0)
        {
         verdict   = "GOOD_PATTERN";
         botAdvice = "Reliable. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg profit $" + DoubleToString(avgProfit,2) + ". " +
                     "EMA win rate " + DoubleToString(emaWinRate,0) + "%. " +
                     spikeInsight;
        }
      else if(winRate >= 45)
        {
         verdict   = "MONITOR";
         botAdvice = "Mixed results. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Use EMA + pattern confluence. " + spikeInsight;
        }
      else if(winRate < 35)
        {
         verdict   = "AVOID";
         botAdvice = "Poor performance. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg loss $" + DoubleToString(avgLoss,2) + ". DO NOT TRADE. " +
                     spikeInsight;
        }
      else
        {
         verdict   = "RISKY";
         botAdvice = "High risk. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Worst loss $" + DoubleToString(s.worstLossUSD,2) + ". " +
                     spikeInsight;
        }

      string spikeWRStr   = (spikeWinRate >= 0) ? DoubleToString(spikeWinRate,1) : "N/A";
      string noSpikeWRStr = (noSpikeWR    >= 0) ? DoubleToString(noSpikeWR,   1) : "N/A";

      // --- SL analysis ---
      double slHitRate       = (s.count > 0)    ? (s.slHits          * 100.0 / s.count) : 0;
      double slPremRate      = (s.slHits > 0)   ? (s.slPrematureHits * 100.0 / s.slHits): 0;
      double avgSlLoss       = (s.slHits > 0)   ? (s.totalSlLossUSD  / s.slHits)         : 0;

      string slWarning = "OK";
      string slAdvice  = "SL is rarely hit.";
      if(slHitRate >= 60 && slPremRate >= 40)
        {
         slWarning = "SL_TOO_TIGHT";
         slAdvice  = "SL too tight! Hit " + DoubleToString(slHitRate,0) + "% of trades and " +
                     DoubleToString(slPremRate,0) + "% were premature (price recovered). " +
                     "Widen SL to $" + DoubleToString(avgSlLoss * 1.5, 2) + " to avoid early exits.";
        }
      else if(slHitRate >= 60)
        {
         slWarning = "FREQUENT_SL_HITS";
         slAdvice  = "SL hit " + DoubleToString(slHitRate,0) + "% of trades! Avg loss $" +
                     DoubleToString(avgSlLoss,2) + " per hit. " +
                     "Consider skipping this pattern OR reduce lot size to limit damage.";
        }
      else if(slHitRate >= 35)
        {
         slWarning = "MODERATE_SL_RISK";
         slAdvice  = "SL hit " + DoubleToString(slHitRate,0) + "% of trades. Avg loss $" +
                     DoubleToString(avgSlLoss,2) + ". " +
                     (slPremRate >= 30 ? "Some premature hits — consider widening SL slightly." :
                                         "Pattern is marginal. Use EMA/spike filters.");
        }
      else if(s.slHits == 0 && s.count >= 3)
        {
         slWarning = "SAFE";
         slAdvice  = "SL never hit in " + IntegerToString(s.count) + " trades. Pattern stays within SL.";
        }

      // --- TP/SL recommendation from ALL-observation totals ---
      double avgMaxFavour  = (s.count > 0) ? (s.totalObsFavourUSD  / s.count) : 0;
      double avgMaxAdverse = (s.count > 0) ? (s.totalObsAdverseUSD / s.count) : 0;
      // Recommend TP at 75% of avg max favour, SL at 120% of avg max adverse
      double recTP = NormalizeDouble(avgMaxFavour  * 0.75, 2);
      double recSL = NormalizeDouble(avgMaxAdverse * 1.20, 2);
      if(recSL < 0.01) recSL = 0.01;

      double curTP = (s.direction == "SELL") ? SeqSellProfitTarget : SeqBuyProfitTarget;
      double curSL = (s.direction == "SELL") ? SeqSellStopLossUSD  : SeqBuyStopLossUSD;

      string tpAssess = "OK";
      string slAssess = "OK";
      string actionReq = "No change needed.";

      if(s.count >= 3)
        {
         // TP assessment
         if(curTP > avgMaxFavour * 0.9)
            tpAssess = "TOO_AMBITIOUS";
         else if(curTP < avgMaxFavour * 0.4)
            tpAssess = "TOO_TIGHT";

         // SL assessment
         if(curSL < avgMaxAdverse * 0.8)
            slAssess = "TOO_TIGHT";
         else if(curSL > avgMaxAdverse * 2.5 && avgMaxAdverse > 0)
            slAssess = "TOO_WIDE";

         // Action required
         bool tpBad = (tpAssess != "OK");
         bool slBad = (slAssess != "OK");
         if(tpBad && slBad)
            actionReq = "ADJUST BOTH: Set TP=$" + DoubleToString(recTP,2) +
                        " SL=$" + DoubleToString(recSL,2) +
                        " (market avg favour=$" + DoubleToString(avgMaxFavour,2) +
                        " adverse=$" + DoubleToString(avgMaxAdverse,2) + ")";
         else if(tpBad)
            actionReq = "ADJUST TP: Set to $" + DoubleToString(recTP,2) +
                        " (current=$" + DoubleToString(curTP,2) +
                        " avg market favour=$" + DoubleToString(avgMaxFavour,2) + ")";
         else if(slBad)
            actionReq = "ADJUST SL: Set to $" + DoubleToString(recSL,2) +
                        " (current=$" + DoubleToString(curSL,2) +
                        " avg market adverse=$" + DoubleToString(avgMaxAdverse,2) + ")";
        }
      else
        {
         tpAssess  = "LEARNING";
         slAssess  = "LEARNING";
         actionReq = "Need " + IntegerToString(3 - s.count) + " more sample(s) for TP/SL advice.";
        }

      string pattern = s.prePrev + " > " + s.prev + " > " + s.label;

      string row =
         "\"" + pattern + "\""              + "," +
         s.direction                        + "," +
         IntegerToString(s.count)           + "," +
         IntegerToString(s.wins)            + "," +
         IntegerToString(losses)            + "," +
         DoubleToString(winRate,   1)       + "," +
         DoubleToString(avgProfit, 2)       + "," +
         DoubleToString(avgLoss,   2)       + "," +
         DoubleToString(avgRR,     2)       + "," +
         DoubleToString(s.bestProfitUSD, 2) + "," +
         DoubleToString(s.worstLossUSD,  2) + "," +
         DoubleToString(emaWinRate,  1)     + "," +
         spikeWRStr                         + "," +
         noSpikeWRStr                       + "," +
         IntegerToString(s.spikeTotal)      + "," +
         IntegerToString(s.noSpikeTotal)    + "," +
         DoubleToString(slHitRate,  1)      + "," +
         DoubleToString(slPremRate, 1)      + "," +
         DoubleToString(avgSlLoss,  2)      + "," +
         slWarning                          + "," +
         "\"" + slAdvice + "\""             + "," +
         DoubleToString(avgMaxFavour,  2)   + "," +
         DoubleToString(avgMaxAdverse, 2)   + "," +
         DoubleToString(s.maxObsFavourUSD,  2) + "," +
         DoubleToString(s.maxObsAdverseUSD, 2) + "," +
         DoubleToString(recTP, 2)           + "," +
         DoubleToString(recSL, 2)           + "," +
         tpAssess                           + "," +
         slAssess                           + "," +
         "\"" + actionReq + "\""            + "," +
         verdict                            + "," +
         "\"" + botAdvice + "\""            + "\n";

      FileWriteString(h, row);
     }
   FileClose(h);

   // Also refresh Top 5 whenever PatternStats is updated
   WriteTop5PatternsCSV();
  }

//+------------------------------------------------------------------+
//| Finalise observation: write Suggestions row + update stats       |
//+------------------------------------------------------------------+
void LearnWriteSuggestion(int slot)
  {
   if(g_suggestFile == "") return;
   SignalObservation r = g_obs[slot];

   double rr = (r.maxAdverse > 0) ? r.maxFavour / r.maxAdverse : 0;

   int suggestedTP = (int)(r.maxFavour  * 0.8);
   int suggestedSL = (int)(r.maxAdverse * 1.2);
   if(suggestedSL < 1) suggestedSL = 1;

   double maxFavourUSD    = PointsToUSD(r.maxFavour,  r.isSell);
   double maxAdverseUSD   = PointsToUSD(r.maxAdverse, r.isSell);
   double suggestedTPUSD  = PointsToUSD(suggestedTP,  r.isSell);
   double suggestedSLUSD  = PointsToUSD(suggestedSL,  r.isSell);
   double missedProfitUSD = NormalizeDouble(maxFavourUSD - suggestedTPUSD, 2);

   // --- SL hit analysis ---
   double slSetting      = r.isSell ? SeqSellStopLossUSD : SeqBuyStopLossUSD;
   double tpSetting      = r.isSell ? SeqSellProfitTarget : SeqBuyProfitTarget;
   bool   slWouldHit     = (maxAdverseUSD >= slSetting);
   // Premature = SL would have triggered BUT max favour also reached TP (price recovered)
   bool   slPremature    = slWouldHit && (maxFavourUSD >= tpSetting);

   // Outcome
   string outcome = "NEUTRAL";
   bool   isWin   = false;
   if(r.maxFavour > r.maxAdverse)      { outcome = "WIN";  isWin = true; }
   else if(r.maxAdverse > r.maxFavour) { outcome = "LOSS"; }

   // EMA labels
   int    emaPeriod = r.isSell ? SeqSellEMAPeriod : SeqBuyEMAPeriod;
   int    emaShift  = r.isSell ? SeqSellEMAShift  : SeqBuyEMAShift;
   double emaPast   = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, emaShift);
   string emaTrend     = r.isSell ? (r.ema1 < emaPast ? "DOWN" : "FLAT")
                                  : (r.ema1 > emaPast ? "UP"   : "FLAT");
   string emaStructure = r.isSell ? (r.ema1 < r.ema2  ? "BEARISH" : "BULLISH")
                                  : (r.ema1 > r.ema2  ? "BULLISH" : "BEARISH");
   bool   emaAligned   = r.isSell ? (r.ema1 < r.ema2) : (r.ema1 > r.ema2);
   bool   hasSpike     = (r.spikeContext != "NO_SPIKE");

   // Rating
   string rating = "WEAK";
   if(rr >= LearnMinRR && r.maxFavour >= 100) rating = "STRONG";
   else if(rr >= 1.0)                          rating = "MODERATE";

   // Spike annotation for bot advice
   string spikeNote = "";
   if(hasSpike)
      spikeNote = " [" + r.spikeContext + " " + DoubleToString(r.spikeSizePts,0) +
                  "pts, " + IntegerToString(r.barsAfterSpike) + "bar(s) ago]";

   // Bot advice
   string botAdvice = "";
   if(rating == "STRONG")
      botAdvice = "ADD TO PATTERNS: AddSeqRule(\"" + r.prePrev + "\",\"" + r.prev +
                  "\",\"" + r.label + "\",\"NEW_ORDER\",\"" + (r.isSell ? "SELL" : "BUY") + "\");" +
                  " TP=" + IntegerToString(suggestedTP) + "pts($" + DoubleToString(suggestedTPUSD,2) + ")" +
                  " SL=" + IntegerToString(suggestedSL) + "pts($" + DoubleToString(suggestedSLUSD,2) + ")" +
                  spikeNote;
   else if(rating == "MODERATE")
      botAdvice = "CONSIDER: RR=" + DoubleToString(rr,2) +
                  " TP=$" + DoubleToString(suggestedTPUSD,2) +
                  " SL=$" + DoubleToString(suggestedSLUSD,2) + spikeNote;
   else
      botAdvice = "SKIP: R:R=" + DoubleToString(rr,2) +
                  " StopTradingMaxProfit=$" + DoubleToString(maxFavourUSD,2) +
                  " MaxLoss=$"   + DoubleToString(maxAdverseUSD,2) + spikeNote;

   // Write Suggestions row
   string row =
      TimeToString(r.signalTime, TIME_DATE|TIME_SECONDS) + "," +
      r.label                                            + "," +
      "\"" + r.prePrev + "\""                           + "," +
      "\"" + r.prev    + "\""                           + "," +
      (r.isSell ? "SELL" : "BUY")                       + "," +
      DoubleToString(r.entryPrice,  2)                  + "," +
      DoubleToString(r.ema1,        2)                  + "," +
      DoubleToString(r.ema2,        2)                  + "," +
      emaTrend                                          + "," +
      emaStructure                                      + "," +
      r.spikeContext                                    + "," +
      IntegerToString(r.barsAfterSpike)                 + "," +
      DoubleToString(r.spikeSizePts, 0)                 + "," +
      IntegerToString((int)r.maxFavour)                 + "," +
      DoubleToString(maxFavourUSD,   2)                 + "," +
      IntegerToString((int)r.maxAdverse)                + "," +
      DoubleToString(maxAdverseUSD,  2)                 + "," +
      DoubleToString(rr, 2)                             + "," +
      outcome                                           + "," +
      r.finalizeReason                                  + "," +
      DoubleToString(missedProfitUSD, 2)                + "," +
      DoubleToString(slSetting, 2)                      + "," +
      (slWouldHit  ? "YES" : "NO")                      + "," +
      (slPremature ? "YES" : "NO")                      + "," +
      IntegerToString(suggestedTP)                      + "," +
      DoubleToString(suggestedTPUSD, 2)                 + "," +
      IntegerToString(suggestedSL)                      + "," +
      DoubleToString(suggestedSLUSD, 2)                 + "," +
      rating                                            + "," +
      "\"" + botAdvice + "\""                           + "\n";

   int h = FileOpen(g_suggestFile,
                    FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_suggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, row);
      FileClose(h);
     }

   // Update pattern stats
   string dir = r.isSell ? "SELL" : "BUY";
   int si = FindOrCreateStats(r.prePrev, r.prev, r.label, dir);
   if(si >= 0)
     {
      g_stats[si].count++;
      g_stats[si].totalRR += rr;
      if(isWin)
        {
         g_stats[si].wins++;
         g_stats[si].totalFavourUSD += maxFavourUSD;
         if(maxFavourUSD > g_stats[si].bestProfitUSD) g_stats[si].bestProfitUSD = maxFavourUSD;
        }
      else
        {
         g_stats[si].totalAdverseUSD += maxAdverseUSD;
         if(maxAdverseUSD > g_stats[si].worstLossUSD) g_stats[si].worstLossUSD = maxAdverseUSD;
        }
      if(emaAligned)
        {
         g_stats[si].emaAlignedTotal++;
         if(isWin) g_stats[si].emaAlignedWins++;
        }
      // SL tracking
      if(slWouldHit)
        {
         g_stats[si].slHits++;
         g_stats[si].totalSlLossUSD += slSetting;
         if(slPremature) g_stats[si].slPrematureHits++;
        }
      // Spike split
      if(hasSpike)
        {
         g_stats[si].spikeTotal++;
         if(isWin) g_stats[si].spikeWins++;
        }
      else
        {
         g_stats[si].noSpikeTotal++;
         if(isWin) g_stats[si].noSpikeWins++;
        }
      // ALL-observation TP/SL tracking (every signal, not just wins/losses)
      g_stats[si].totalObsFavourUSD  += maxFavourUSD;
      g_stats[si].totalObsAdverseUSD += maxAdverseUSD;
      if(maxFavourUSD  > g_stats[si].maxObsFavourUSD)  g_stats[si].maxObsFavourUSD  = maxFavourUSD;
      if(maxAdverseUSD > g_stats[si].maxObsAdverseUSD) g_stats[si].maxObsAdverseUSD = maxAdverseUSD;
      WritePatternStatsCSV();
     }

   // Journal output
   string outcomeStr = isWin
      ? ("WIN  $" + DoubleToString(maxFavourUSD,2) + " | Missed extra $" + DoubleToString(missedProfitUSD,2))
      : ("LOSS $" + DoubleToString(maxAdverseUSD,2));

   string spikeTag = hasSpike
      ? (" | SPIKE=" + r.spikeContext + " " + DoubleToString(r.spikeSizePts,0) + "pts")
      : " | NO_SPIKE";

   /*Print("AI BOT | [" + r.label + "] " + outcomeStr +
         " | R:R=" + DoubleToString(rr,2) +
         " | " + rating +
         " | EMA=" + emaStructure +
         spikeTag);*/

   // SL warning journal
   if(slWouldHit)
     {
    /*  if(slPremature)
         //Print("AI BOT | *** SL PREMATURE *** [" + r.label + "]" +
               " SL($" + DoubleToString(slSetting,2) + ") was hit BUT price later reached TP($" +
               DoubleToString(tpSetting,2) + "). SL is TOO TIGHT — widen it!");
      else
         //Print("AI BOT | *** SL HIT *** [" + r.label + "]" +
               " Adverse=$" + DoubleToString(maxAdverseUSD,2) +
               " exceeded SL=$" + DoubleToString(slSetting,2) +
               " | Cumulative SL hits this session: " +
               (si >= 0 ? IntegerToString(g_stats[si].slHits) : "?"));*/
     }

  //  if(rating == "STRONG")
  //     //Print("AI BOT | *** STRONG *** " + r.label +
  //           " TP=$" + DoubleToString(suggestedTPUSD,2) +
  //           " SL=$" + DoubleToString(suggestedSLUSD,2) +
  //           spikeTag + " | See PatternStats_" + Symbol() + ".csv");

   // Cross-verify with spike context
   if(si >= 0 && g_stats[si].count >= 3)
     {
      double wr = (g_stats[si].wins * 100.0 / g_stats[si].count);
      string verdict = (wr >= 65) ? "TRADE IT" : (wr >= 45) ? "MONITOR" : "AVOID";

      string spikeCompare = "";
      if(g_stats[si].spikeTotal > 0 && g_stats[si].noSpikeTotal > 0)
        {
         double swr = g_stats[si].spikeWins   * 100.0 / g_stats[si].spikeTotal;
         double nwr = g_stats[si].noSpikeWins * 100.0 / g_stats[si].noSpikeTotal;
         if(swr > nwr + 20)
            spikeCompare = " | TIP: Trade this ONLY after spikes (" +
                           DoubleToString(swr,0) + "% vs " + DoubleToString(nwr,0) + "% no-spike)";
         else if(nwr > swr + 20)
            spikeCompare = " | TIP: Avoid after spikes (" +
                           DoubleToString(swr,0) + "% spike vs " + DoubleToString(nwr,0) + "% no-spike)";
        }

      // //Print("AI BOT | CROSS-CHECK [" + r.label + "] " +
      //       IntegerToString(g_stats[si].count) + " trades: " +
      //       DoubleToString(wr,0) + "% win -> " + verdict + spikeCompare);
     }
  }

//+------------------------------------------------------------------+
//| Write live training status CSV — called every new bar            |
//+------------------------------------------------------------------+
void WriteLiveStatusCSV()
  {
   if(g_liveFile == "") return;

   int h = FileOpen(g_liveFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "Signal,Direction,SpikeContext,EntryPrice,BarsObserved,Progress%,"
      "CurrentRR,MaxFavourPts,MaxFavourUSD,MaxAdversePts,MaxAdverseUSD,"
      "Status,LiveVerdict\n");

   int activeCount = 0;
   for(int s = 0; s < OBS_MAX; s++)
     {
      if(!g_obs[s].active || g_obs[s].written) continue;
      activeCount++;

      double rr         = (g_obs[s].maxAdverse > 0)
                          ? g_obs[s].maxFavour / g_obs[s].maxAdverse : 0;
      double progress   = (LearnObserveBars > 0)
                          ? (g_obs[s].barsObserved * 100.0 / LearnObserveBars) : 0;
      double favUSD     = PointsToUSD(g_obs[s].maxFavour,  g_obs[s].isSell);
      double advUSD     = PointsToUSD(g_obs[s].maxAdverse, g_obs[s].isSell);

      string status     = "WATCHING";
      string liveVerdict = "WAIT";

      if(rr >= LearnEarlyWinRR && g_obs[s].barsObserved >= LearnEarlyMinBars)
        { status = "EARLY_WIN";  liveVerdict = "STRONG_WIN"; }
      else if(g_obs[s].maxAdverse > g_obs[s].maxFavour * LearnEarlyLossRatio
              && g_obs[s].barsObserved >= LearnEarlyMinBars)
        { status = "EARLY_LOSS"; liveVerdict = "CONFIRMED_LOSS"; }
      else if(rr >= 1.5)
        liveVerdict = "LOOKING_GOOD";
      else if(rr >= 1.0)
        liveVerdict = "MODERATE";
      else if(g_obs[s].maxAdverse > g_obs[s].maxFavour)
        liveVerdict = "LOSING";

      string row =
         g_obs[s].label                                + "," +
         (g_obs[s].isSell ? "SELL" : "BUY")           + "," +
         g_obs[s].spikeContext                         + "," +
         DoubleToString(g_obs[s].entryPrice,  2)       + "," +
         IntegerToString(g_obs[s].barsObserved)        + "," +
         DoubleToString(progress, 0)                   + "," +
         DoubleToString(rr, 2)                         + "," +
         IntegerToString((int)g_obs[s].maxFavour)      + "," +
         DoubleToString(favUSD,  2)                    + "," +
         IntegerToString((int)g_obs[s].maxAdverse)     + "," +
         DoubleToString(advUSD,  2)                    + "," +
         status                                        + "," +
         liveVerdict                                   + "\n";

      FileWriteString(h, row);
     }

   // Summary line
   FileWriteString(h, "\nActive observations: " + IntegerToString(activeCount) +
                       " | Patterns learned: " + IntegerToString(g_statsCount) +
                       " | Updated: " + TimeToString(TimeCurrent(), TIME_SECONDS) + "\n");
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Called every tick: update active observations                    |
//+------------------------------------------------------------------+
void LearnUpdateObservations()
  {
   if(!LearnEnabled) return;
   if(g_suggestFile == "") return;

   double bid = MarketInfo(Symbol(), MODE_BID);
   double ask = MarketInfo(Symbol(), MODE_ASK);

   bool hasNewBar = (Time[0] != g_lastLiveBar);

   for(int s = 0; s < OBS_MAX; s++)
     {
      if(!g_obs[s].active || g_obs[s].written) continue;

      // --- Update max favour / adverse every tick ---
      double entryPx = g_obs[s].entryPrice;
      double favour  = 0, adverse = 0;

      if(g_obs[s].isSell)
        { favour = (entryPx - bid) / Point;  adverse = (ask - entryPx) / Point; }
      else
        { favour = (ask - entryPx) / Point;  adverse = (entryPx - bid) / Point; }

      if(favour  < 0) favour  = 0;
      if(adverse < 0) adverse = 0;

      if(favour  > g_obs[s].maxFavour)  g_obs[s].maxFavour  = favour;
      if(adverse > g_obs[s].maxAdverse) g_obs[s].maxAdverse = adverse;

      int barsNow = iBarShift(Symbol(), PERIOD_M1, g_obs[s].signalTime, false);
      g_obs[s].barsObserved = barsNow;

      double rr       = (g_obs[s].maxAdverse > 0) ? g_obs[s].maxFavour / g_obs[s].maxAdverse : 0;
      double favUSD   = PointsToUSD(g_obs[s].maxFavour,  g_obs[s].isSell);
      double advUSD   = PointsToUSD(g_obs[s].maxAdverse, g_obs[s].isSell);
      double progress = (LearnObserveBars > 0) ? (barsNow * 100.0 / LearnObserveBars) : 0;

      // --- Milestone journal prints (per new bar) ---
      if(hasNewBar)
        {
         if(barsNow >= LearnObserveBars / 4  && g_obs[s].milestone25 == 0)
           {
            g_obs[s].milestone25 = 1;
            /*Print("AI BOT | [" + g_obs[s].label + "] 25% | " +
                  "Favour=$" + DoubleToString(favUSD,2) +
                  " Adverse=$" + DoubleToString(advUSD,2) +
                  " R:R=" + DoubleToString(rr,2) +
                  " | " + g_obs[s].spikeContext);*/
           }
         if(barsNow >= LearnObserveBars / 2  && g_obs[s].milestone50 == 0)
           {
            g_obs[s].milestone50 = 1;
            /*Print("AI BOT | [" + g_obs[s].label + "] 50% | " +
                  "Favour=$" + DoubleToString(favUSD,2) +
                  " Adverse=$" + DoubleToString(advUSD,2) +
                  " R:R=" + DoubleToString(rr,2) +
                  (rr >= 1.5 ? " -> LOOKING GOOD" : (rr < 0.5 ? " -> LOSING" : " -> MIXED")));*/
           }
         if(barsNow >= (LearnObserveBars * 3) / 4 && g_obs[s].milestone75 == 0)
           {
            g_obs[s].milestone75 = 1;
            string verdict75 = (rr >= LearnMinRR) ? "LIKELY STRONG" :
                               (rr >= 1.0)        ? "MODERATE"      :
                               (rr >= 0.5)        ? "WEAK"          : "LIKELY LOSS";
           /*Print("AI BOT | [" + g_obs[s].label + "] 75% | " +
                  "Favour=$" + DoubleToString(favUSD,2) +
                  " Adverse=$" + DoubleToString(advUSD,2) +
                  " R:R=" + DoubleToString(rr,2) +
                  " -> " + verdict75);*/
           }
        }

      // --- Early finalization: clear WIN ---
      if(barsNow >= LearnEarlyMinBars
         && rr >= LearnEarlyWinRR
         && g_obs[s].maxFavour >= 100)
        {
         g_obs[s].finalizeReason = "EARLY_WIN";
        /*Print("AI BOT | [" + g_obs[s].label + "] *** EARLY WIN *** " +
               "R:R=" + DoubleToString(rr,2) +
               " Profit=$" + DoubleToString(favUSD,2) +
               " after only " + IntegerToString(barsNow) + " bars");*/
         LearnWriteSuggestion(s);
         g_obs[s].written = true;
         g_obs[s].active  = false;
         continue;
        }

      // --- Early finalization: clear LOSS ---
      if(barsNow >= LearnEarlyMinBars
         && g_obs[s].maxAdverse > g_obs[s].maxFavour * LearnEarlyLossRatio
         && g_obs[s].maxAdverse >= 100)
        {
         g_obs[s].finalizeReason = "EARLY_LOSS";
         /*Print("AI BOT | [" + g_obs[s].label + "] *** EARLY LOSS *** " +
               "Adverse=$" + DoubleToString(advUSD,2) +
               " >> Favour=$" + DoubleToString(favUSD,2) +
               " after " + IntegerToString(barsNow) + " bars - PATTERN FAILED");*/
         LearnWriteSuggestion(s);
         g_obs[s].written = true;
         g_obs[s].active  = false;
         continue;
        }

      // --- Normal timeout finalization ---
      if(barsNow >= LearnObserveBars)
        {
         g_obs[s].finalizeReason = "TIMEOUT";
         LearnWriteSuggestion(s);
         g_obs[s].written = true;
         g_obs[s].active  = false;
        }
     }

   // --- Update live status CSV once per new bar ---
   if(hasNewBar)
     {
      g_lastLiveBar = Time[0];
      WriteLiveStatusCSV();
     }
  }

#endif
