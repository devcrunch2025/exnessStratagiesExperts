//+------------------------------------------------------------------+
//| V_TV_LearningSuggestions.mqh                                     |
//|                                                                  |
//| SELF-LEARNING PATTERN ANALYSER                                   |
//| ---------------------------------------------------------------  |
//| How it works:                                                    |
//|  1. Every time a new signal fires, record:                       |
//|     - Signal label, bar time, entry price                        |
//|     - EMA state at that moment                                   |
//|  2. On every tick, measure how far price moved AFTER the signal  |
//|     (max favourable move = potential TP)                         |
//|     (max adverse move   = potential SL)                          |
//|  3. After N ticks or a new opposing signal, the observation ends |
//|  4. Write one row to Suggestions.csv for YOU to review           |
//|  5. Patterns with high reward:risk are highlighted as STRONG     |
//|                                                                  |
//| YOU review the CSV and manually add good patterns to             |
//| V_TV_StrategyPatterns.mqh                                        |
//+------------------------------------------------------------------+
#ifndef V_TV_LEARNING_SUGGESTIONS_MQH
#define V_TV_LEARNING_SUGGESTIONS_MQH

//--- Config inputs --------------------------------------------------
input string _Learn_              = "--- LEARNING ENGINE ---";
input int    LearnObserveBars     = 30;    // How many bars to track after each signal
input double LearnMinRR           = 1.5;   // Min reward:risk to mark suggestion STRONG
input bool   LearnEnabled         = true;  // Enable/disable learning engine

//--- Internal observation record -----------------------------------
struct SignalObservation
  {
   string   label;          // Full signal label e.g. "TREND SELL 3"
   string   prePrev;        // Context: pre-previous signal
   string   prev;           // Context: previous signal
   datetime signalTime;     // Bar time when signal fired
   double   entryPrice;     // High (SELL) or Low (BUY) at signal bar
   double   ema1;           // EMA1 at signal
   double   ema2;           // EMA2 at signal
   bool     isSell;         // true=SELL signal, false=BUY signal
   double   maxFavour;      // Max favourable price move (points) seen after signal
   double   maxAdverse;     // Max adverse price move (points) seen after signal
   int      barsObserved;   // How many bars since signal
   bool     active;         // Still being observed
   bool     written;        // Already written to CSV
  };

#define OBS_MAX 100
SignalObservation g_obs[OBS_MAX];
int               g_obsCount = 0;

string g_suggestFile = "";

//+------------------------------------------------------------------+
//| Init suggestions CSV                                             |
//+------------------------------------------------------------------+
void InitLearningSuggestions()
  {
   if(!LearnEnabled) return;

   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   g_suggestFile = "Suggestions_" + dateStr + "_" + Symbol() + ".csv";

   bool needHeader = true;
   int h = FileOpen(g_suggestFile, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      ulong sz = FileSize(h);
      FileClose(h);
      if(sz > 0) needHeader = false;
     }

   if(needHeader)
     {
      h = FileOpen(g_suggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h,
            "SignalTime,Signal,PrePrev,Prev,Direction,EntryPrice,"
            "EMA1,EMA2,EMA1_Trend,EMA_Structure,"
            "MaxFavourPts,MaxAdversePts,RewardRisk,"
            "SuggestedTP_pts,SuggestedSL_pts,"
            "Rating,Suggestion\n");
         FileClose(h);
        }
     }

   for(int i = 0; i < OBS_MAX; i++) g_obs[i].active = false;
   Print("LearnEngine: Initialised -> " + g_suggestFile);
  }

//+------------------------------------------------------------------+
//| Called when a new signal fires (from main bar loop)             |
//+------------------------------------------------------------------+
void LearnRecordSignal(string label, string prevSig, string prePrevSig,
                       double entryPrice, bool isSell)
  {
   if(!LearnEnabled) return;

   // Find free slot (reuse oldest written slot if full)
   int slot = -1;
   for(int i = 0; i < OBS_MAX; i++)
      if(!g_obs[i].active) { slot = i; break; }
   if(slot < 0)
     {
      // Overwrite first written slot
      for(int i = 0; i < OBS_MAX; i++)
         if(g_obs[i].written) { slot = i; break; }
     }
   if(slot < 0) return; // all slots busy

   int emaPeriod = isSell ? SeqSellEMAPeriod  : SeqBuyEMAPeriod;
   int ema2Per   = isSell ? SeqSellEMA2Period  : SeqBuyEMA2Period;
   int emaShift  = isSell ? SeqSellEMAShift    : SeqBuyEMAShift;

   double ema1     = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2     = iMA(Symbol(), 0, ema2Per,   0, MODE_EMA, PRICE_CLOSE, 0);

   g_obs[slot].label        = label;
   g_obs[slot].prePrev      = prePrevSig;
   g_obs[slot].prev         = prevSig;
   g_obs[slot].signalTime   = TimeCurrent();
   g_obs[slot].entryPrice   = entryPrice;
   g_obs[slot].ema1         = ema1;
   g_obs[slot].ema2         = ema2;
   g_obs[slot].isSell       = isSell;
   g_obs[slot].maxFavour    = 0;
   g_obs[slot].maxAdverse   = 0;
   g_obs[slot].barsObserved = 0;
   g_obs[slot].active       = true;
   g_obs[slot].written      = false;
  }

//+------------------------------------------------------------------+
//| Write one observation to CSV                                     |
//+------------------------------------------------------------------+
void LearnWriteSuggestion(int slot)
  {
   if(g_suggestFile == "") return;
   SignalObservation r = g_obs[slot];

   double rr = (r.maxAdverse > 0) ? r.maxFavour / r.maxAdverse : 0;

   // Suggested TP = 80% of max favourable move (conservative)
   // Suggested SL = 120% of max adverse move (give a little room)
   int suggestedTP = (int)(r.maxFavour * 0.8);
   int suggestedSL = (int)(r.maxAdverse * 1.2);
   if(suggestedSL < 1) suggestedSL = 1;

   string emaTrend     = r.isSell ? (r.ema1 < iMA(Symbol(),0,SeqSellEMAPeriod,0,MODE_EMA,PRICE_CLOSE,SeqSellEMAShift) ? "DOWN" : "FLAT")
                                  : (r.ema1 > iMA(Symbol(),0,SeqBuyEMAPeriod, 0,MODE_EMA,PRICE_CLOSE,SeqBuyEMAShift)  ? "UP"   : "FLAT");
   string emaStructure = r.isSell ? (r.ema1 < r.ema2 ? "BEARISH" : "BULLISH")
                                  : (r.ema1 > r.ema2 ? "BULLISH" : "BEARISH");

   // Rating
   string rating = "WEAK";
   if(rr >= LearnMinRR && r.maxFavour >= 100) rating = "STRONG";
   else if(rr >= 1.0)                          rating = "MODERATE";

   // Suggestion text
   string suggestion = "";
   if(rating == "STRONG")
      suggestion = "ADD TO PATTERNS: AddSeqRule(\"" + r.prePrev + "\",\"" + r.prev + "\",\"" + r.label + "\",\"NEW_ORDER\",\"" + (r.isSell ? "SELL" : "BUY") + "\"); TP=" + IntegerToString(suggestedTP) + "pts SL=" + IntegerToString(suggestedSL) + "pts";
   else if(rating == "MODERATE")
      suggestion = "CONSIDER: " + r.label + " RR=" + DoubleToString(rr,2) + " TP=" + IntegerToString(suggestedTP) + "pts SL=" + IntegerToString(suggestedSL) + "pts";
   else
      suggestion = "SKIP: low reward:risk=" + DoubleToString(rr,2);

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
      IntegerToString((int)r.maxAdverse)                + "," +
      DoubleToString(rr, 2)                             + "," +
      IntegerToString(suggestedTP)                      + "," +
      IntegerToString(suggestedSL)                      + "," +
      rating                                            + "," +
      "\"" + suggestion + "\""                          + "\n";

   int h = FileOpen(g_suggestFile,
                    FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_suggestFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, row);
   FileClose(h);

   if(rating == "STRONG")
      Print("LearnEngine: *** STRONG PATTERN *** " + r.label +
            " RR=" + DoubleToString(rr,2) +
            " TP=" + IntegerToString(suggestedTP) + "pts" +
            " SL=" + IntegerToString(suggestedSL) + "pts" +
            " | Check Suggestions.csv");
  }

//+------------------------------------------------------------------+
//| Called every tick: update all active observations                |
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
         // SELL: favour = price dropped below entry, adverse = price rose above entry
         favour  = (entryPx - bid) / Point;
         adverse = (ask - entryPx) / Point;
        }
      else
        {
         // BUY: favour = price rose above entry, adverse = price dropped below entry
         favour  = (ask - entryPx) / Point;
         adverse = (entryPx - bid) / Point;
        }

      if(favour  > g_obs[s].maxFavour)  g_obs[s].maxFavour  = favour;
      if(adverse > g_obs[s].maxAdverse) g_obs[s].maxAdverse = adverse;

      // Check if observation window expired (count closed bars)
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
