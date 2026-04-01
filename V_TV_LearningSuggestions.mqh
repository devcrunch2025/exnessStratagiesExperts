//+------------------------------------------------------------------+
//| V_TV_LearningSuggestions.mqh                                     |
//|                                                                  |
//| AI BOT PATTERN ANALYSER                                          |
//| ---------------------------------------------------------------  |
//| How it works:                                                    |
//|  1. Every signal fires → record entry price + EMA state          |
//|  2. Every tick → track how far price moved (favour / adverse)    |
//|  3. After N bars → finalise observation, write to Suggestions    |
//|  4. Aggregate by pattern → write PatternStats (AI verdict)       |
//|  5. Journal prints bot-style TRADE IT / MONITOR / AVOID advice   |
//|                                                                  |
//| FILES:                                                           |
//|  Suggestions_DATE_SYMBOL.csv  - every signal, every session      |
//|  PatternStats_SYMBOL.csv      - aggregated verdict per pattern   |
//+------------------------------------------------------------------+
#ifndef V_TV_LEARNING_SUGGESTIONS_MQH
#define V_TV_LEARNING_SUGGESTIONS_MQH

//--- Config inputs --------------------------------------------------
input string _Learn_          = "--- AI BOT ANALYSER ---";
input int    LearnObserveBars = 30;   // Bars to track after each signal
input double LearnMinRR       = 1.5;  // Min R:R to mark STRONG
input bool   LearnEnabled     = true; // Enable/disable AI analyser

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
   double   maxFavour;    // points
   double   maxAdverse;   // points
   int      barsObserved;
   bool     active;
   bool     written;
  };

#define OBS_MAX 100
SignalObservation g_obs[OBS_MAX];
int               g_obsCount = 0;

//+------------------------------------------------------------------+
//| Per-pattern aggregated stats (one row in PatternStats CSV)       |
//+------------------------------------------------------------------+
struct PatternStats
  {
   string key;            // "prePrev|prev|label|direction"
   string prePrev;
   string prev;
   string label;
   string direction;
   int    count;
   int    wins;           // favour > adverse
   double totalFavourUSD;
   double totalAdverseUSD;
   double totalRR;
   double bestProfitUSD;
   double worstLossUSD;
   int    emaAlignedWins; // wins where EMA structure matched direction
   int    emaAlignedTotal;
   bool   active;
  };

#define STATS_MAX 50
PatternStats g_stats[STATS_MAX];
int          g_statsCount = 0;

string g_suggestFile  = "";
string g_statsFile    = "";

//+------------------------------------------------------------------+
//| Helper: points → USD for given lot size                          |
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
//| Init both CSV files                                              |
//+------------------------------------------------------------------+
void InitLearningSuggestions()
  {
   if(!LearnEnabled) return;

   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   g_suggestFile = "Suggestions_" + dateStr + "_" + Symbol() + ".csv";
   g_statsFile   = "PatternStats_" + Symbol() + ".csv";

   // --- Suggestions CSV header (new file only) ---
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
            "MaxFavourPts,MaxFavourUSD,MaxAdversePts,MaxAdverseUSD,"
            "RewardRisk,Outcome,MissedProfit_USD,"
            "SuggestedTP_pts,SuggestedTP_USD,SuggestedSL_pts,SuggestedSL_USD,"
            "Rating,BotAdvice\n");
         FileClose(h);
        }
     }

   // --- PatternStats CSV header (always rewrite on init) ---
   h = FileOpen(g_statsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h,
         "Pattern,Direction,Times_Seen,Wins,Losses,WinRate%,"
         "AvgProfit_USD,AvgLoss_USD,AvgRR,"
         "BestProfit_USD,WorstLoss_USD,"
         "EMA_WinRate%,Verdict,BotAdvice\n");
      FileClose(h);
     }

   for(int i = 0; i < OBS_MAX;   i++) g_obs[i].active   = false;
   for(int i = 0; i < STATS_MAX; i++) g_stats[i].active = false;
   g_statsCount = 0;

   Print("AI BOT: Initialised -> " + g_suggestFile);
   Print("AI BOT: Pattern stats -> " + g_statsFile);
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

   int emaPeriod = isSell ? SeqSellEMAPeriod  : SeqBuyEMAPeriod;
   int ema2Per   = isSell ? SeqSellEMA2Period  : SeqBuyEMA2Period;

   g_obs[slot].label        = label;
   g_obs[slot].prePrev      = prePrevSig;
   g_obs[slot].prev         = prevSig;
   g_obs[slot].signalTime   = TimeCurrent();
   g_obs[slot].entryPrice   = entryPrice;
   g_obs[slot].ema1         = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   g_obs[slot].ema2         = iMA(Symbol(), 0, ema2Per,   0, MODE_EMA, PRICE_CLOSE, 0);
   g_obs[slot].isSell       = isSell;
   g_obs[slot].maxFavour    = 0;
   g_obs[slot].maxAdverse   = 0;
   g_obs[slot].barsObserved = 0;
   g_obs[slot].active       = true;
   g_obs[slot].written      = false;
  }

//+------------------------------------------------------------------+
//| Find or create pattern stats slot                                |
//+------------------------------------------------------------------+
int FindOrCreateStats(string prePrev, string prev, string label, string dir)
  {
   string key = prePrev + "|" + prev + "|" + label + "|" + dir;
   for(int i = 0; i < STATS_MAX; i++)
     {
      if(g_stats[i].active && g_stats[i].key == key) return i;
     }
   // create new
   if(g_statsCount >= STATS_MAX) return -1;
   int s = g_statsCount++;
   g_stats[s].key            = key;
   g_stats[s].prePrev        = prePrev;
   g_stats[s].prev           = prev;
   g_stats[s].label          = label;
   g_stats[s].direction      = dir;
   g_stats[s].count          = 0;
   g_stats[s].wins           = 0;
   g_stats[s].totalFavourUSD = 0;
   g_stats[s].totalAdverseUSD= 0;
   g_stats[s].totalRR        = 0;
   g_stats[s].bestProfitUSD  = 0;
   g_stats[s].worstLossUSD   = 0;
   g_stats[s].emaAlignedWins = 0;
   g_stats[s].emaAlignedTotal= 0;
   g_stats[s].active         = true;
   return s;
  }

//+------------------------------------------------------------------+
//| Rewrite full PatternStats CSV with current in-memory data        |
//+------------------------------------------------------------------+
void WritePatternStatsCSV()
  {
   int h = FileOpen(g_statsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "Pattern,Direction,Times_Seen,Wins,Losses,WinRate%,"
      "AvgProfit_USD,AvgLoss_USD,AvgRR,"
      "BestProfit_USD,WorstLoss_USD,"
      "EMA_WinRate%,Verdict,BotAdvice\n");

   for(int i = 0; i < g_statsCount; i++)
     {
      if(!g_stats[i].active) continue;
      PatternStats s = g_stats[i];

      int    losses      = s.count - s.wins;
      double winRate     = (s.count > 0) ? (s.wins  * 100.0 / s.count) : 0;
      double avgProfit   = (s.wins   > 0) ? (s.totalFavourUSD  / s.wins)   : 0;
      double avgLoss     = (losses   > 0) ? (s.totalAdverseUSD / losses)   : 0;
      double avgRR       = (s.count  > 0) ? (s.totalRR / s.count)           : 0;
      double emaWinRate  = (s.emaAlignedTotal > 0)
                           ? (s.emaAlignedWins * 100.0 / s.emaAlignedTotal) : 0;

      // --- Verdict ---
      string verdict  = "MONITOR";
      string botAdvice = "";

      if(s.count < 2)
        {
         verdict   = "LEARNING";
         botAdvice = "Only " + IntegerToString(s.count) + " sample(s). Need more data.";
        }
      else if(winRate >= 65 && avgRR >= 1.5)
        {
         verdict   = "TRADE_IT";
         botAdvice = "Strong edge! Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg profit $" + DoubleToString(avgProfit,2) + " vs loss $" + DoubleToString(avgLoss,2) + ". " +
                     "Best seen $" + DoubleToString(s.bestProfitUSD,2) + ". Use EMA filter.";
        }
      else if(winRate >= 55 && avgRR >= 1.0)
        {
         verdict   = "GOOD_PATTERN";
         botAdvice = "Reliable pattern. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg profit $" + DoubleToString(avgProfit,2) + ". " +
                     "EMA win rate " + DoubleToString(emaWinRate,0) + "% - use EMA confirmation.";
        }
      else if(winRate >= 45)
        {
         verdict   = "MONITOR";
         botAdvice = "Mixed results. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Only trade with EMA + pattern confluence. Need more samples.";
        }
      else if(winRate < 35)
        {
         verdict   = "AVOID";
         botAdvice = "Poor performance. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Avg loss $" + DoubleToString(avgLoss,2) + ". DO NOT TRADE this pattern.";
        }
      else
        {
         verdict   = "RISKY";
         botAdvice = "High risk. Win rate " + DoubleToString(winRate,0) + "%. " +
                     "Worst loss $" + DoubleToString(s.worstLossUSD,2) + ". Wait for confirmation.";
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
         DoubleToString(emaWinRate, 1)      + "," +
         verdict                            + "," +
         "\"" + botAdvice + "\""            + "\n";

      FileWriteString(h, row);
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Finalise one observation: write Suggestions row + update stats   |
//+------------------------------------------------------------------+
void LearnWriteSuggestion(int slot)
  {
   if(g_suggestFile == "") return;
   SignalObservation r = g_obs[slot];

   double rr = (r.maxAdverse > 0) ? r.maxFavour / r.maxAdverse : 0;

   int suggestedTP = (int)(r.maxFavour  * 0.8);
   int suggestedSL = (int)(r.maxAdverse * 1.2);
   if(suggestedSL < 1) suggestedSL = 1;

   double maxFavourUSD   = PointsToUSD(r.maxFavour,  r.isSell);
   double maxAdverseUSD  = PointsToUSD(r.maxAdverse, r.isSell);
   double suggestedTPUSD = PointsToUSD(suggestedTP,  r.isSell);
   double suggestedSLUSD = PointsToUSD(suggestedSL,  r.isSell);
   double missedProfitUSD = NormalizeDouble(maxFavourUSD - suggestedTPUSD, 2);

   // Outcome
   string outcome = "NEUTRAL";
   bool   isWin   = false;
   if(r.maxFavour > r.maxAdverse)      { outcome = "WIN";  isWin = true; }
   else if(r.maxAdverse > r.maxFavour) { outcome = "LOSS"; }

   // EMA trend / structure labels
   int emaPeriod = r.isSell ? SeqSellEMAPeriod : SeqBuyEMAPeriod;
   int emaShift  = r.isSell ? SeqSellEMAShift  : SeqBuyEMAShift;
   double emaPast = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, emaShift);
   string emaTrend     = r.isSell ? (r.ema1 < emaPast  ? "DOWN" : "FLAT")
                                  : (r.ema1 > emaPast  ? "UP"   : "FLAT");
   string emaStructure = r.isSell ? (r.ema1 < r.ema2   ? "BEARISH" : "BULLISH")
                                  : (r.ema1 > r.ema2   ? "BULLISH" : "BEARISH");
   bool emaAligned = r.isSell ? (r.ema1 < r.ema2) : (r.ema1 > r.ema2);

   // Rating
   string rating = "WEAK";
   if(rr >= LearnMinRR && r.maxFavour >= 100) rating = "STRONG";
   else if(rr >= 1.0)                          rating = "MODERATE";

   // Bot advice for this signal
   string botAdvice = "";
   if(rating == "STRONG")
      botAdvice = "ADD TO PATTERNS: AddSeqRule(\"" + r.prePrev + "\",\"" + r.prev + "\",\"" + r.label + "\",\"NEW_ORDER\",\"" + (r.isSell ? "SELL" : "BUY") + "\"); TP=" + IntegerToString(suggestedTP) + "pts($" + DoubleToString(suggestedTPUSD,2) + ") SL=" + IntegerToString(suggestedSL) + "pts($" + DoubleToString(suggestedSLUSD,2) + ")";
   else if(rating == "MODERATE")
      botAdvice = "CONSIDER: RR=" + DoubleToString(rr,2) + " TP=$" + DoubleToString(suggestedTPUSD,2) + " SL=$" + DoubleToString(suggestedSLUSD,2);
   else
      botAdvice = "SKIP: poor R:R=" + DoubleToString(rr,2) + " MaxProfit=$" + DoubleToString(maxFavourUSD,2) + " MaxLoss=$" + DoubleToString(maxAdverseUSD,2);

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
      IntegerToString((int)r.maxFavour)                 + "," +
      DoubleToString(maxFavourUSD,  2)                  + "," +
      IntegerToString((int)r.maxAdverse)                + "," +
      DoubleToString(maxAdverseUSD, 2)                  + "," +
      DoubleToString(rr,  2)                            + "," +
      outcome                                           + "," +
      DoubleToString(missedProfitUSD, 2)                + "," +
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

   // --- Update pattern stats ---
   string dir = r.isSell ? "SELL" : "BUY";
   int si = FindOrCreateStats(r.prePrev, r.prev, r.label, dir);
   if(si >= 0)
     {
      g_stats[si].count++;
      g_stats[si].totalRR        += rr;
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
      WritePatternStatsCSV();
     }

   // --- Journal bot message ---
   string outcomeStr = isWin
      ? ("WIN  | Profit potential $" + DoubleToString(maxFavourUSD,2) +
         " | Missed extra $" + DoubleToString(missedProfitUSD,2))
      : ("LOSS | Adverse move $" + DoubleToString(maxAdverseUSD,2));

   Print("AI BOT | [" + r.label + "] " + outcomeStr +
         " | R:R=" + DoubleToString(rr,2) +
         " | " + rating +
         " | EMA=" + emaStructure);

   if(rating == "STRONG")
      Print("AI BOT | *** STRONG PATTERN FOUND *** " + r.label +
            " | TP=$" + DoubleToString(suggestedTPUSD,2) +
            " SL=$"   + DoubleToString(suggestedSLUSD,2) +
            " | See PatternStats_" + Symbol() + ".csv");

   // Cross-verify: check if this pattern has stats and warn/confirm
   if(si >= 0 && g_stats[si].count >= 3)
     {
      double wr = (g_stats[si].wins * 100.0 / g_stats[si].count);
      string verdict = (wr >= 65) ? "TRADE IT" : (wr >= 45) ? "MONITOR" : "AVOID";
      Print("AI BOT | CROSS-CHECK [" + r.label + "] after " +
            IntegerToString(g_stats[si].count) + " trades: Win rate=" +
            DoubleToString(wr,0) + "% -> " + verdict);
     }
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

   for(int s = 0; s < OBS_MAX; s++)
     {
      if(!g_obs[s].active || g_obs[s].written) continue;

      double entryPx = g_obs[s].entryPrice;
      double favour  = 0;
      double adverse = 0;

      if(g_obs[s].isSell)
        {
         favour  = (entryPx - bid) / Point;
         adverse = (ask - entryPx) / Point;
        }
      else
        {
         favour  = (ask - entryPx) / Point;
         adverse = (entryPx - bid) / Point;
        }
      if(favour  < 0) favour  = 0;
      if(adverse < 0) adverse = 0;

      if(favour  > g_obs[s].maxFavour)  g_obs[s].maxFavour  = favour;
      if(adverse > g_obs[s].maxAdverse) g_obs[s].maxAdverse = adverse;

      int barsNow = iBarShift(Symbol(), PERIOD_M1, g_obs[s].signalTime, false);
      g_obs[s].barsObserved = barsNow;

      if(barsNow >= LearnObserveBars)
        {
         LearnWriteSuggestion(s);
         g_obs[s].written = true;
         g_obs[s].active  = false;
        }
     }
  }

#endif
