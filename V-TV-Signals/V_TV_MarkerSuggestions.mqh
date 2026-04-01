//+------------------------------------------------------------------+
//| V_TV_MarkerSuggestions.mqh                                       |
//|                                                                  |
//| AI MARKER QUALITY TRAINER                                        |
//| ---------------------------------------------------------------  |
//| Since all trading depends on markers, this module trains on      |
//| every individual marker and answers:                             |
//|  - Is this marker type reliable?                                 |
//|  - Does EMA alignment improve it?                                |
//|  - Does a recent spike improve it?                               |
//|  - Which sequence count (1st, 2nd, 3rd) is most accurate?       |
//|  - Which hours of day is this marker most reliable?              |
//|  - Is the marker appearing too early or too late?                |
//|  - What specific filter would improve accuracy?                  |
//|                                                                  |
//| FILES:                                                           |
//|  MarkerSuggestions_DATE_SYMBOL.csv  - every marker observation   |
//|  MarkerStats_SYMBOL.csv             - aggregated per marker type |
//+------------------------------------------------------------------+
#ifndef V_TV_MARKER_SUGGESTIONS_MQH
#define V_TV_MARKER_SUGGESTIONS_MQH

//--- Config (shares LearnObserveBars, SpikeMultiplier, SpikeLookback from main EA)
input string _MarkerAI_            = "--- MARKER AI TRAINER ---";
input bool   MarkerAIEnabled       = true;  // Enable marker quality training
input int    MarkerObserveBars     = 25;    // Bars to observe after each marker
input int    MarkerEarlyMinBars    = 4;     // Min bars before early finalization
input double MarkerEarlyWinRR     = 2.0;   // Finalize early on clear win
input double MarkerEarlyLossRatio  = 3.0;  // Finalize early on clear loss

//+------------------------------------------------------------------+
//| Per-marker observation                                           |
//+------------------------------------------------------------------+
struct MarkerObservation
  {
   string   markerType;      // "TREND SELL", "TREND BUY", "PRE SELL" etc.
   int      seqCount;        // which number in sequence (1=first, 2=second...)
   datetime markerTime;
   double   markerPrice;     // High[i] for sell, Low[i] for buy
   bool     isSell;
   double   ema1;
   double   ema2;
   bool     emaAligned;      // EMA in correct direction for this signal
   string   spikeContext;    // AFTER_SPIKE_UP / AFTER_SPIKE_DOWN / NO_SPIKE
   double   spikeSizePts;
   int      hourOfDay;       // 0-23
   double   maxFavour;       // points in expected direction
   double   maxAdverse;      // points against
   int      barsToFavourPeak;// bars until maxFavour was reached
   int      barsObserved;
   bool     active;
   bool     written;
   string   finalizeReason;  // EARLY_WIN / EARLY_LOSS / TIMEOUT
   int      milestone50;     // 1 once printed
  };

#define MOBS_MAX 150
MarkerObservation g_mobs[MOBS_MAX];

//+------------------------------------------------------------------+
//| Per-marker-type aggregated stats                                 |
//+------------------------------------------------------------------+
struct MarkerTypeStats
  {
   string markerType;
   string direction;
   int    count;
   int    accurate;     // rr >= 1.5 and fast (barsToFavour <= half window)
   int    good;         // rr >= 1.0
   int    weak;         // rr 0.5 - 1.0
   int    falseSig;     // rr < 0.5
   double totalFavourUSD;
   double totalAdverseUSD;
   double totalRR;
   double totalBarsToFavour;
   int    emaWins;      int emaTotal;
   int    noEmaWins;    int noEmaTotal;
   int    spikeWins;    int spikeTotal;
   int    noSpikeWins;  int noSpikeTotal;
   int    seq1Wins;     int seq1Total;
   int    seq2Wins;     int seq2Total;
   int    seq3plusWins; int seq3plusTotal;
   int    hourWins[24];
   int    hourTotal[24];
   bool   active;
  };

#define MSTATS_MAX 20
MarkerTypeStats g_mstats[MSTATS_MAX];
int             g_mstatsCount = 0;

string   g_markerSuggestFile = "";
string   g_markerStatsFile   = "";
datetime g_lastMarkerLiveBar = 0;

//+------------------------------------------------------------------+
//| Helper: points to USD                                            |
//+------------------------------------------------------------------+
double MkrPointsToUSD(double pts, bool isSell)
  {
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lot       = isSell ? SeqSellLotSize : SeqBuyLotSize;
   if(tickSize <= 0) return 0;
   return NormalizeDouble(pts * (Point / tickSize) * tickValue * lot, 2);
  }

//+------------------------------------------------------------------+
//| Detect spike (same logic as DrawSpikeMarkers)                    |
//+------------------------------------------------------------------+
string MkrDetectSpikeContext(double &spikeSize)
  {
   spikeSize = 0;
   for(int offset = 0; offset <= SpikeSearchBars; offset++)
     {
      int b = offset;
      if(b + SpikeLookback >= Bars) continue;
      double avgRange = 0;
      for(int k = b + 1; k <= b + SpikeLookback; k++) avgRange += (High[k] - Low[k]);
      avgRange /= SpikeLookback;
      if(avgRange <= 0) continue;
      double candleRange = High[b] - Low[b];
      if(candleRange < avgRange * SpikeMultiplier) continue;
      double body      = MathAbs(Open[b] - Close[b]);
      double upperWick = High[b]  - MathMax(Open[b], Close[b]);
      double lowerWick = MathMin(Open[b], Close[b]) - Low[b];
      bool isUp = (upperWick > body * 1.5);
      if(!isUp && !(lowerWick > body * 1.5)) isUp = (Close[b] <= Open[b]);
      spikeSize = candleRange / Point;
      return isUp ? "AFTER_SPIKE_UP" : "AFTER_SPIKE_DOWN";
     }
   return "NO_SPIKE";
  }

//+------------------------------------------------------------------+
//| Find or create stats slot for a marker type                      |
//+------------------------------------------------------------------+
int FindOrCreateMStats(string markerType, string dir)
  {
   string key = markerType + "|" + dir;
   for(int i = 0; i < g_mstatsCount; i++)
      if(g_mstats[i].active && g_mstats[i].markerType + "|" + g_mstats[i].direction == key)
         return i;
   if(g_mstatsCount >= MSTATS_MAX) return -1;
   int s = g_mstatsCount++;
   g_mstats[s].markerType       = markerType;
   g_mstats[s].direction        = dir;
   g_mstats[s].count            = 0;
   g_mstats[s].accurate         = 0;
   g_mstats[s].good             = 0;
   g_mstats[s].weak             = 0;
   g_mstats[s].falseSig         = 0;
   g_mstats[s].totalFavourUSD   = 0;
   g_mstats[s].totalAdverseUSD  = 0;
   g_mstats[s].totalRR          = 0;
   g_mstats[s].totalBarsToFavour= 0;
   g_mstats[s].emaWins          = 0; g_mstats[s].emaTotal      = 0;
   g_mstats[s].noEmaWins        = 0; g_mstats[s].noEmaTotal    = 0;
   g_mstats[s].spikeWins        = 0; g_mstats[s].spikeTotal    = 0;
   g_mstats[s].noSpikeWins      = 0; g_mstats[s].noSpikeTotal  = 0;
   g_mstats[s].seq1Wins         = 0; g_mstats[s].seq1Total     = 0;
   g_mstats[s].seq2Wins         = 0; g_mstats[s].seq2Total     = 0;
   g_mstats[s].seq3plusWins     = 0; g_mstats[s].seq3plusTotal = 0;
   for(int h = 0; h < 24; h++) { g_mstats[s].hourWins[h] = 0; g_mstats[s].hourTotal[h] = 0; }
   g_mstats[s].active = true;
   return s;
  }

//+------------------------------------------------------------------+
//| Build improvement suggestion string from stats                   |
//+------------------------------------------------------------------+
string BuildMarkerSuggestion(int si)
  {
   MarkerTypeStats s = g_mstats[si];
   if(s.count < 3) return "Need " + IntegerToString(3 - s.count) + " more samples to suggest improvements.";

   double totalRate  = (s.count > 0)       ? ((s.accurate + s.good) * 100.0 / s.count)  : 0;
   double emaRate    = (s.emaTotal > 0)     ? ((s.emaWins  * 100.0) / s.emaTotal)         : -1;
   double noEmaRate  = (s.noEmaTotal > 0)   ? ((s.noEmaWins * 100.0) / s.noEmaTotal)      : -1;
   double spikeRate  = (s.spikeTotal > 0)   ? ((s.spikeWins * 100.0) / s.spikeTotal)      : -1;
   double noSpikeRate= (s.noSpikeTotal > 0) ? ((s.noSpikeWins * 100.0) / s.noSpikeTotal)  : -1;
   double seq1Rate   = (s.seq1Total > 0)    ? ((s.seq1Wins  * 100.0) / s.seq1Total)        : -1;
   double seq2Rate   = (s.seq2Total > 0)    ? ((s.seq2Wins  * 100.0) / s.seq2Total)        : -1;
   double seq3Rate   = (s.seq3plusTotal > 0)? ((s.seq3plusWins * 100.0) / s.seq3plusTotal) : -1;

   // Find best and worst hours
   int bestHour = -1, worstHour = -1;
   double bestHourRate = -1, worstHourRate = 200;
   for(int h = 0; h < 24; h++)
     {
      if(s.hourTotal[h] < 2) continue;
      double hr = s.hourWins[h] * 100.0 / s.hourTotal[h];
      if(hr > bestHourRate)  { bestHourRate  = hr;  bestHour  = h; }
      if(hr < worstHourRate) { worstHourRate = hr;  worstHour = h; }
     }

   string suggestion = "";

   // Overall assessment
   if(totalRate >= 70)
      suggestion += "RELIABLE marker (" + DoubleToString(totalRate,0) + "% accurate). ";
   else if(totalRate >= 50)
      suggestion += "MODERATE marker (" + DoubleToString(totalRate,0) + "% accurate). ";
   else
      suggestion += "UNRELIABLE marker (" + DoubleToString(totalRate,0) + "% accurate) - needs filters. ";

   // EMA filter advice
   if(emaRate >= 0 && noEmaRate >= 0)
     {
      if(emaRate > noEmaRate + 25)
         suggestion += "FILTER: Require EMA alignment (+" + DoubleToString(emaRate-noEmaRate,0) + "% accuracy). ";
      else if(noEmaRate > emaRate + 15)
         suggestion += "NOTE: EMA filter hurts this marker (non-EMA wins more). ";
      else
         suggestion += "EMA has minor effect on this marker. ";
     }

   // Spike filter advice
   if(spikeRate >= 0 && noSpikeRate >= 0)
     {
      if(spikeRate > noSpikeRate + 25)
         suggestion += "FILTER: Only trade after spike (spike=" + DoubleToString(spikeRate,0) +
                       "% vs no-spike=" + DoubleToString(noSpikeRate,0) + "%). ";
      else if(noSpikeRate > spikeRate + 20)
         suggestion += "AVOID after spikes (spike=" + DoubleToString(spikeRate,0) +
                       "% vs no-spike=" + DoubleToString(noSpikeRate,0) + "%). ";
     }

   // Sequence count advice
   if(seq1Rate >= 0 && seq2Rate >= 0)
     {
      if(seq2Rate > seq1Rate + 20)
         suggestion += "WAIT for 2nd signal (seq1=" + DoubleToString(seq1Rate,0) +
                       "% vs seq2=" + DoubleToString(seq2Rate,0) + "%). ";
      else if(seq1Rate > seq2Rate + 15)
         suggestion += "Trade on 1st signal (seq1=" + DoubleToString(seq1Rate,0) +
                       "% best). ";
     }
   if(seq3Rate >= 0 && seq3Rate < 40)
      suggestion += "AVOID 3rd+ signals (only " + DoubleToString(seq3Rate,0) + "% accurate). ";

   // Hour advice
   if(bestHour >= 0)
      suggestion += "Best hour: " + IntegerToString(bestHour) + ":00 (" + DoubleToString(bestHourRate,0) + "%). ";
   if(worstHour >= 0 && worstHourRate < 40)
      suggestion += "AVOID at " + IntegerToString(worstHour) + ":00 (" + DoubleToString(worstHourRate,0) + "%). ";

   return suggestion;
  }

//+------------------------------------------------------------------+
//| Rewrite MarkerStats CSV                                          |
//+------------------------------------------------------------------+
void WriteMarkerStatsCSV()
  {
   int h = FileOpen(g_markerStatsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;

   FileWriteString(h,
      "MarkerType,Direction,TotalFired,Accurate,Good,Weak,False,"
      "Accurate%,AvgProfit_USD,AvgLoss_USD,AvgRR,AvgBarsToFavour,"
      "EMA_Accurate%,NoEMA_Accurate%,"
      "Spike_Accurate%,NoSpike_Accurate%,"
      "Seq1_Accurate%,Seq2_Accurate%,Seq3plus_Accurate%,"
      "BestHour,BestHourRate%,WorstHour,WorstHourRate%,"
      "Verdict,ImprovementSuggestion\n");

   for(int i = 0; i < g_mstatsCount; i++)
     {
      if(!g_mstats[i].active) continue;
      MarkerTypeStats s = g_mstats[i];

      int    losers     = s.weak + s.falseSig;
      double accRate    = (s.count > 0)       ? ((s.accurate + s.good) * 100.0 / s.count) : 0;
      double avgProfit  = (s.accurate + s.good > 0)
                          ? s.totalFavourUSD  / (s.accurate + s.good) : 0;
      double avgLoss    = (losers > 0)        ? s.totalAdverseUSD / losers                : 0;
      double avgRR      = (s.count > 0)       ? s.totalRR / s.count                       : 0;
      double avgBars    = (s.count > 0)       ? s.totalBarsToFavour / s.count             : 0;

      string emaRateStr    = (s.emaTotal > 0)      ? DoubleToString(s.emaWins*100.0/s.emaTotal,1)               : "N/A";
      string noEmaRateStr  = (s.noEmaTotal > 0)    ? DoubleToString(s.noEmaWins*100.0/s.noEmaTotal,1)           : "N/A";
      string spikeRateStr  = (s.spikeTotal > 0)    ? DoubleToString(s.spikeWins*100.0/s.spikeTotal,1)           : "N/A";
      string noSpikeStr    = (s.noSpikeTotal > 0)  ? DoubleToString(s.noSpikeWins*100.0/s.noSpikeTotal,1)       : "N/A";
      string seq1Str       = (s.seq1Total > 0)     ? DoubleToString(s.seq1Wins*100.0/s.seq1Total,1)             : "N/A";
      string seq2Str       = (s.seq2Total > 0)     ? DoubleToString(s.seq2Wins*100.0/s.seq2Total,1)             : "N/A";
      string seq3Str       = (s.seq3plusTotal > 0) ? DoubleToString(s.seq3plusWins*100.0/s.seq3plusTotal,1)     : "N/A";

      // Best/worst hour
      int bh = -1, wh = -1;
      double bhr = -1, whr = 200;
      for(int hh = 0; hh < 24; hh++)
        {
         if(s.hourTotal[hh] < 2) continue;
         double r = s.hourWins[hh] * 100.0 / s.hourTotal[hh];
         if(r > bhr) { bhr = r; bh = hh; }
         if(r < whr) { whr = r; wh = hh; }
        }

      string verdict = (accRate >= 70) ? "RELIABLE" :
                       (accRate >= 50) ? "MODERATE" :
                       (accRate >= 35) ? "NEEDS_FILTER" : "UNRELIABLE";

      string suggestion = BuildMarkerSuggestion(i);

      string row =
         s.markerType                          + "," +
         s.direction                           + "," +
         IntegerToString(s.count)              + "," +
         IntegerToString(s.accurate)           + "," +
         IntegerToString(s.good)               + "," +
         IntegerToString(s.weak)               + "," +
         IntegerToString(s.falseSig)           + "," +
         DoubleToString(accRate,  1)           + "," +
         DoubleToString(avgProfit,2)           + "," +
         DoubleToString(avgLoss,  2)           + "," +
         DoubleToString(avgRR,    2)           + "," +
         DoubleToString(avgBars,  1)           + "," +
         emaRateStr                            + "," +
         noEmaRateStr                          + "," +
         spikeRateStr                          + "," +
         noSpikeStr                            + "," +
         seq1Str                               + "," +
         seq2Str                               + "," +
         seq3Str                               + "," +
         (bh >= 0 ? IntegerToString(bh) : "N/A")                      + "," +
         (bh >= 0 ? DoubleToString(bhr,0) : "N/A")                    + "," +
         (wh >= 0 ? IntegerToString(wh) : "N/A")                      + "," +
         (wh >= 0 ? DoubleToString(whr,0) : "N/A")                    + "," +
         verdict                               + "," +
         "\"" + suggestion + "\""             + "\n";

      FileWriteString(h, row);
     }
   FileClose(h);
  }

//+------------------------------------------------------------------+
//| Write one marker observation to MarkerSuggestions CSV            |
//+------------------------------------------------------------------+
void WriteMarkerSuggestionRow(int slot)
  {
   if(g_markerSuggestFile == "") return;
   MarkerObservation r = g_mobs[slot];

   double rr        = (r.maxAdverse > 0) ? r.maxFavour / r.maxAdverse : 0;
   double favUSD    = MkrPointsToUSD(r.maxFavour,  r.isSell);
   double advUSD    = MkrPointsToUSD(r.maxAdverse, r.isSell);
   bool   isWin     = (r.maxFavour > r.maxAdverse);

   // Marker quality
   string quality = "FALSE";
   if(rr >= 1.5 && r.barsToFavourPeak <= MarkerObserveBars / 2)
      quality = "ACCURATE";
   else if(rr >= 1.0)
      quality = "GOOD";
   else if(rr >= 0.5)
      quality = "WEAK";

   // Per-signal suggestion
   string suggestion = "";
   if(quality == "ACCURATE")
      suggestion = "Good entry. Move in expected direction quickly.";
   else if(quality == "GOOD")
      suggestion = "Decent marker. Consider tighter TP to capture move.";
   else if(quality == "WEAK")
      {
       suggestion = "Weak signal. ";
       if(!r.emaAligned) suggestion += "EMA not aligned - filter may help. ";
       if(r.spikeContext == "NO_SPIKE") suggestion += "No spike context. ";
       if(r.seqCount == 1) suggestion += "Wait for 2nd confirmation. ";
      }
   else // FALSE
      {
       suggestion = "FALSE signal. Price moved opposite. ";
       if(!r.emaAligned) suggestion += "EMA was NOT aligned - this filter would have blocked it. ";
       if(r.seqCount >= 3) suggestion += "High seq count (" + IntegerToString(r.seqCount) + ") - avoid late entries. ";
       if(r.hourOfDay >= 21 || r.hourOfDay <= 2) suggestion += "Late night hour - low reliability. ";
      }

   string emaStr = r.isSell ? (r.ema1 < r.ema2 ? "BEARISH" : "BULLISH")
                             : (r.ema1 > r.ema2 ? "BULLISH" : "BEARISH");

   string row =
      TimeToString(r.markerTime, TIME_DATE|TIME_SECONDS) + "," +
      r.markerType                                       + "," +
      IntegerToString(r.seqCount)                        + "," +
      (r.isSell ? "SELL" : "BUY")                        + "," +
      (r.emaAligned ? "YES" : "NO")                      + "," +
      emaStr                                             + "," +
      r.spikeContext                                     + "," +
      DoubleToString(r.spikeSizePts, 0)                  + "," +
      IntegerToString(r.hourOfDay)                       + "," +
      IntegerToString((int)r.maxFavour)                  + "," +
      DoubleToString(favUSD, 2)                          + "," +
      IntegerToString((int)r.maxAdverse)                 + "," +
      DoubleToString(advUSD, 2)                          + "," +
      IntegerToString(r.barsToFavourPeak)                + "," +
      DoubleToString(rr, 2)                              + "," +
      quality                                            + "," +
      r.finalizeReason                                   + "," +
      "\"" + suggestion + "\""                           + "\n";

   int h = FileOpen(g_markerSuggestFile,
                    FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_markerSuggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileSeek(h, 0, SEEK_END);
      FileWriteString(h, row);
      FileClose(h);
     }

   // Update stats
   string dir = r.isSell ? "SELL" : "BUY";
   int si = FindOrCreateMStats(r.markerType, dir);
   if(si >= 0)
     {
      g_mstats[si].count++;
      g_mstats[si].totalRR           += rr;
      g_mstats[si].totalBarsToFavour += r.barsToFavourPeak;

      if(quality == "ACCURATE")     g_mstats[si].accurate++;
      else if(quality == "GOOD")    g_mstats[si].good++;
      else if(quality == "WEAK")    g_mstats[si].weak++;
      else                           g_mstats[si].falseSig++;

      if(isWin)
        {
         g_mstats[si].totalFavourUSD += favUSD;
         if(r.emaAligned) { g_mstats[si].emaWins++; }
         else             { g_mstats[si].noEmaWins++; }
         if(r.spikeContext != "NO_SPIKE") g_mstats[si].spikeWins++;
         else                             g_mstats[si].noSpikeWins++;
         if(r.seqCount == 1)      g_mstats[si].seq1Wins++;
         else if(r.seqCount == 2) g_mstats[si].seq2Wins++;
         else                     g_mstats[si].seq3plusWins++;
         if(r.hourOfDay >= 0 && r.hourOfDay < 24) g_mstats[si].hourWins[r.hourOfDay]++;
        }
      else
        {
         g_mstats[si].totalAdverseUSD += advUSD;
        }

      if(r.emaAligned) g_mstats[si].emaTotal++; else g_mstats[si].noEmaTotal++;
      if(r.spikeContext != "NO_SPIKE") g_mstats[si].spikeTotal++; else g_mstats[si].noSpikeTotal++;
      if(r.seqCount == 1)      g_mstats[si].seq1Total++;
      else if(r.seqCount == 2) g_mstats[si].seq2Total++;
      else                     g_mstats[si].seq3plusTotal++;
      if(r.hourOfDay >= 0 && r.hourOfDay < 24) g_mstats[si].hourTotal[r.hourOfDay]++;

      WriteMarkerStatsCSV();
     }

   // Journal
   Print("MARKER AI | [" + r.markerType + " #" + IntegerToString(r.seqCount) + "] " +
         quality + " | " + (isWin ? "WIN" : "LOSS") +
         " Favour=$" + DoubleToString(favUSD,2) +
         " Adverse=$" + DoubleToString(advUSD,2) +
         " RR=" + DoubleToString(rr,2) +
         " BarsToFavour=" + IntegerToString(r.barsToFavourPeak) +
         " | EMA=" + (r.emaAligned ? "YES" : "NO") +
         " Spike=" + r.spikeContext);

   // Cross-check journal
   if(si >= 0 && g_mstats[si].count >= 3)
     {
      double ar = (g_mstats[si].accurate + g_mstats[si].good) * 100.0 / g_mstats[si].count;
      string mkrVerdict = (ar >= 70) ? "RELIABLE" : (ar >= 50) ? "MODERATE" : "NEEDS IMPROVEMENT";
      Print("MARKER AI | STATS [" + r.markerType + "] " +
            IntegerToString(g_mstats[si].count) + " markers: " +
            DoubleToString(ar,0) + "% accurate -> " + mkrVerdict +
            " | " + BuildMarkerSuggestion(si));
     }
  }

//+------------------------------------------------------------------+
//| Init                                                             |
//+------------------------------------------------------------------+
void InitMarkerSuggestions()
  {
   if(!MarkerAIEnabled) return;

   g_markerSuggestFile = "MarkerSuggestions_" + g_runTimestamp + "_" + Symbol() + ".csv";
   g_markerStatsFile   = "MarkerStats_"       + g_runTimestamp + "_" + Symbol() + ".csv";

   // MarkerSuggestions — header for new file only
   bool needHeader = true;
   int h = FileOpen(g_markerSuggestFile, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      if(FileSize(h) > 0) needHeader = false;
      FileClose(h);
     }
   if(needHeader)
     {
      h = FileOpen(g_markerSuggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h,
            "MarkerTime,MarkerType,SeqCount,Direction,"
            "EMA_Aligned,EMA_Structure,SpikeContext,SpikeSize_pts,HourOfDay,"
            "MaxFavourPts,MaxFavourUSD,MaxAdversePts,MaxAdverseUSD,"
            "BarsToFavourPeak,RewardRisk,"
            "MarkerQuality,FinalizeReason,Suggestion\n");
         FileClose(h);
        }
     }

   // MarkerStats — always fresh header
   h = FileOpen(g_markerStatsFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      FileWriteString(h,
         "MarkerType,Direction,TotalFired,Accurate,Good,Weak,False,"
         "Accurate%,AvgProfit_USD,AvgLoss_USD,AvgRR,AvgBarsToFavour,"
         "EMA_Accurate%,NoEMA_Accurate%,"
         "Spike_Accurate%,NoSpike_Accurate%,"
         "Seq1_Accurate%,Seq2_Accurate%,Seq3plus_Accurate%,"
         "BestHour,BestHourRate%,WorstHour,WorstHourRate%,"
         "Verdict,ImprovementSuggestion\n");
      FileClose(h);
     }

   for(int i = 0; i < MOBS_MAX;   i++) g_mobs[i].active    = false;
   for(int i = 0; i < MSTATS_MAX; i++) g_mstats[i].active  = false;
   g_mstatsCount = 0;

   Print("MARKER AI: Initialised -> " + g_markerSuggestFile);
   Print("MARKER AI: Stats file  -> " + g_markerStatsFile);
  }

//+------------------------------------------------------------------+
//| Called at every marker fire from OnTick signal block            |
//+------------------------------------------------------------------+
void RecordMarkerObs(string markerType, int seqCount,
                     double markerPrice, bool isSell)
  {
   if(!MarkerAIEnabled) return;

   int slot = -1;
   for(int i = 0; i < MOBS_MAX; i++)
      if(!g_mobs[i].active) { slot = i; break; }
   if(slot < 0)
      for(int i = 0; i < MOBS_MAX; i++)
         if(g_mobs[i].written) { slot = i; break; }
   if(slot < 0) return;

   int    emaPeriod = isSell ? SeqSellEMAPeriod : SeqBuyEMAPeriod;
   int    ema2Per   = isSell ? SeqSellEMA2Period : SeqBuyEMA2Period;
   double ema1      = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2      = iMA(Symbol(), 0, ema2Per,   0, MODE_EMA, PRICE_CLOSE, 0);
   bool   emaAlgn   = isSell ? (ema1 < ema2) : (ema1 > ema2);

   double spikeSize  = 0;
   string spikeCt    = MkrDetectSpikeContext(spikeSize);

   g_mobs[slot].markerType      = markerType;
   g_mobs[slot].seqCount        = seqCount;
   g_mobs[slot].markerTime      = TimeCurrent();
   g_mobs[slot].markerPrice     = markerPrice;
   g_mobs[slot].isSell          = isSell;
   g_mobs[slot].ema1            = ema1;
   g_mobs[slot].ema2            = ema2;
   g_mobs[slot].emaAligned      = emaAlgn;
   g_mobs[slot].spikeContext    = spikeCt;
   g_mobs[slot].spikeSizePts    = spikeSize;
   g_mobs[slot].hourOfDay       = TimeHour(TimeCurrent());
   g_mobs[slot].maxFavour       = 0;
   g_mobs[slot].maxAdverse      = 0;
   g_mobs[slot].barsToFavourPeak= 0;
   g_mobs[slot].barsObserved    = 0;
   g_mobs[slot].active          = true;
   g_mobs[slot].written         = false;
   g_mobs[slot].finalizeReason  = "TIMEOUT";
   g_mobs[slot].milestone50     = 0;
  }

//+------------------------------------------------------------------+
//| Called every tick: update all active marker observations         |
//+------------------------------------------------------------------+
void UpdateMarkerObs()
  {
   if(!MarkerAIEnabled) return;
   if(g_markerSuggestFile == "") return;

   double bid = MarketInfo(Symbol(), MODE_BID);
   double ask = MarketInfo(Symbol(), MODE_ASK);
   bool hasNewBar = (Time[0] != g_lastMarkerLiveBar);

   for(int s = 0; s < MOBS_MAX; s++)
     {
      if(!g_mobs[s].active || g_mobs[s].written) continue;

      double entryPx = g_mobs[s].markerPrice;
      double favour  = 0, adverse = 0;

      if(g_mobs[s].isSell)
        { favour = (entryPx - bid) / Point;  adverse = (ask - entryPx) / Point; }
      else
        { favour = (ask - entryPx) / Point;  adverse = (entryPx - bid) / Point; }

      if(favour  < 0) favour  = 0;
      if(adverse < 0) adverse = 0;

      // Track bar at which max favour was reached
      if(favour > g_mobs[s].maxFavour)
        {
         g_mobs[s].maxFavour       = favour;
         g_mobs[s].barsToFavourPeak = g_mobs[s].barsObserved;
        }
      if(adverse > g_mobs[s].maxAdverse) g_mobs[s].maxAdverse = adverse;

      int barsNow = iBarShift(Symbol(), PERIOD_M1, g_mobs[s].markerTime, false);
      g_mobs[s].barsObserved = barsNow;

      double rr     = (g_mobs[s].maxAdverse > 0) ? g_mobs[s].maxFavour / g_mobs[s].maxAdverse : 0;
      double favUSD = MkrPointsToUSD(g_mobs[s].maxFavour, g_mobs[s].isSell);
      double advUSD = MkrPointsToUSD(g_mobs[s].maxAdverse,g_mobs[s].isSell);

      // 50% milestone print
      if(hasNewBar && barsNow >= MarkerObserveBars / 2 && g_mobs[s].milestone50 == 0)
        {
         g_mobs[s].milestone50 = 1;
         string trend = (rr >= 1.5) ? "GOOD" : (rr >= 0.8) ? "MIXED" : "POOR";
         Print("MARKER AI | [" + g_mobs[s].markerType + " #" + IntegerToString(g_mobs[s].seqCount) +
               "] 50% | Favour=$" + DoubleToString(favUSD,2) +
               " Adverse=$" + DoubleToString(advUSD,2) +
               " RR=" + DoubleToString(rr,2) + " -> " + trend);
        }

      // Early finalization: clear win
      if(barsNow >= MarkerEarlyMinBars && rr >= MarkerEarlyWinRR && g_mobs[s].maxFavour >= 80)
        {
         g_mobs[s].finalizeReason = "EARLY_WIN";
         Print("MARKER AI | [" + g_mobs[s].markerType + " #" + IntegerToString(g_mobs[s].seqCount) +
               "] EARLY WIN R:R=" + DoubleToString(rr,2) +
               " $" + DoubleToString(favUSD,2) + " in " + IntegerToString(barsNow) + " bars");
         WriteMarkerSuggestionRow(s);
         g_mobs[s].written = true;
         g_mobs[s].active  = false;
         continue;
        }

      // Early finalization: clear loss
      if(barsNow >= MarkerEarlyMinBars
         && g_mobs[s].maxAdverse > g_mobs[s].maxFavour * MarkerEarlyLossRatio
         && g_mobs[s].maxAdverse >= 80)
        {
         g_mobs[s].finalizeReason = "EARLY_LOSS";
         Print("MARKER AI | [" + g_mobs[s].markerType + " #" + IntegerToString(g_mobs[s].seqCount) +
               "] EARLY LOSS Adverse=$" + DoubleToString(advUSD,2) +
               " in " + IntegerToString(barsNow) + " bars - FALSE MARKER");
         WriteMarkerSuggestionRow(s);
         g_mobs[s].written = true;
         g_mobs[s].active  = false;
         continue;
        }

      // Normal timeout
      if(barsNow >= MarkerObserveBars)
        {
         g_mobs[s].finalizeReason = "TIMEOUT";
         WriteMarkerSuggestionRow(s);
         g_mobs[s].written = true;
         g_mobs[s].active  = false;
        }
     }

   if(hasNewBar) g_lastMarkerLiveBar = Time[0];
  }

#endif
