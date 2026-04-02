//+------------------------------------------------------------------+
//| V_TV_StrategyPatterns.mqh                                        |
//| Defines all sequence-based strategy patterns (signal rules)      |
//|                                                                  |
//| Pattern format:                                                  |
//|   AddSeqRule(prePrev, prev, curr, action, tradeType)             |
//|   prePrev / prev / curr : full signal+seq text                   |
//|                           e.g. "TREND SELL 2", "W SHAPE SELL 1"  |
//|                           Use "" as wildcard (matches anything)   |
//|   action    : "NEW_ORDER" | "CLOSE"                              |
//|   tradeType : "BUY"       | "SELL"                               |
//+------------------------------------------------------------------+
#ifndef V_TV_STRATEGY_PATTERNS_MQH
#define V_TV_STRATEGY_PATTERNS_MQH

//--- Universal signal price history -----------------------------------
// Stores price of every signal bar, keyed by full label (e.g. "TREND SELL 2")
// Used by Cond5 to find gap between any two signals in a matched pattern
struct SeqSignalEntry
  {
   string label;   // full signal+seq label e.g. "TREND SELL 2", "PRE SELL 1"
   double price;   // bar price (High for SELL, Low for BUY) when signal fired
  };

#define SIG_HISTORY_MAX 200
SeqSignalEntry g_sigHistory[SIG_HISTORY_MAX];
int            g_sigHistoryCount = 0;

// Record a signal price (overwrites if same label seen again)
void RecordSignalPrice(string label, double price)
  {
   // Update existing entry if label already exists
   for(int i = g_sigHistoryCount - 1; i >= 0; i--)
      if(g_sigHistory[i].label == label)
        { g_sigHistory[i].price = price; return; }
   // Add new entry (ring buffer)
   int idx = g_sigHistoryCount % SIG_HISTORY_MAX;
   g_sigHistory[idx].label = label;
   g_sigHistory[idx].price = price;
   if(g_sigHistoryCount < SIG_HISTORY_MAX) g_sigHistoryCount++;
  }

// Get price for a signal label; returns -1 if not found
double GetSignalPrice(string label)
  {
   if(label == "") return -1;
   for(int i = g_sigHistoryCount - 1; i >= 0; i--)
      if(g_sigHistory[i % SIG_HISTORY_MAX].label == label)
         return g_sigHistory[i % SIG_HISTORY_MAX].price;
   return -1;
  }

// Keep g_trendSellSeq for the diff display on chart markers
SeqSignalEntry g_trendSellSeq[];   // TREND SELL sequence for marker diff display only

//--- Struct -----------------------------------------------------------
struct SeqRule
  {
   string prePrev;    // pre-previous signal text pattern ("" = any)
   string prev;       // previous signal text pattern    ("" = any)
   string curr;       // current signal text pattern     ("" = any)
   string action;     // "NEW_ORDER" or "CLOSE"
   string tradeType;  // "BUY" or "SELL"
  };

//--- Global array of rules -------------------------------------------
SeqRule g_seqRules[];

//--- Add one rule to the array ---------------------------------------
void AddSeqRule(string prePrev, string prev, string curr,
                string action, string tradeType)
  {
   int n = ArraySize(g_seqRules);
   ArrayResize(g_seqRules, n + 1);
   g_seqRules[n].prePrev   = prePrev;
   g_seqRules[n].prev      = prev;
   g_seqRules[n].curr      = curr;
   g_seqRules[n].action    = action;
   g_seqRules[n].tradeType = tradeType;
  }

//--- Check current signal state against all rules --------------------
//    Returns index of first matched rule, or -1 if none match
int CheckSeqRules()
  {
   string cPrePrev = g_prePrevSeqSignalText;
   string cPrev    = (g_prevDisplaySignal == "") ? "" :
                     g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount);
   string cCurr    = (g_liveSignalName   == "") ? "" :
                     g_liveSignalName    + " " + IntegerToString(g_currSeqCount);

   for(int i = 0; i < ArraySize(g_seqRules); i++)
     {
      bool matchPP = (g_seqRules[i].prePrev == "" || g_seqRules[i].prePrev == cPrePrev);
      bool matchP  = (g_seqRules[i].prev    == "" || g_seqRules[i].prev    == cPrev);
      bool matchC  = (g_seqRules[i].curr    == "" || g_seqRules[i].curr    == cCurr);
      if(matchPP && matchP && matchC) return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| COLOR RULES — trigger by signal colour + sequence count          |
//|                                                                  |
//| colorType     : "ANY GREEN SIGNAL" / "ANY RED SIGNAL" etc.       |
//| countType     : "COUNT_1".."COUNT_N" or "COUNT_ANY"              |
//| action        : "NEW_ORDER" or "CLOSE"                           |
//| tradeType     : "BUY" or "SELL"                                  |
//| trendRequired : "" = no trend check (default)                    |
//|                 "DOWNTREND" = M30 close must be falling           |
//|                 "UPTREND"   = M30 close must be rising            |
//|                 Uses TrendLookbackBars + TrendMinMovePercent      |
//| emaRequired   : "" = no EMA check (default)                      |
//|                 "UP"   = EMA1 must be sloping UP (not flat)       |
//|                 "DOWN" = EMA1 must be sloping DOWN (not flat)     |
//|                 Uses SeqBuy/SellEMAPeriod, EMAShift, EMAFlatMinPts|
//+------------------------------------------------------------------+
struct ColorRule
  {
   string colorType;      // signal colour group
   int    minCount;       // minimum seqCount required (1 = any)
   string action;         // "NEW_ORDER" or "CLOSE"
   string tradeType;      // "BUY" or "SELL"
   string trendRequired;  // "" / "DOWNTREND" / "UPTREND"
   string emaRequired;    // "" / "UP" / "DOWN"
  };

ColorRule g_colorRules[];

void AddColorRule(string colorType,     string countType,
                  string action,        string tradeType,
                  string trendRequired = "",
                  string emaRequired   = "")
  {
   // Parse count: "COUNT_3" → 3, "COUNT_ANY" or "" → 1
   int minCount = 1;
   if(StringFind(countType, "COUNT_") == 0)
     {
      string numStr = StringSubstr(countType, 6);
      if(numStr != "ANY" && numStr != "")
         minCount = (int)StringToInteger(numStr);
     }

   int n = ArraySize(g_colorRules);
   ArrayResize(g_colorRules, n + 1);
   g_colorRules[n].colorType     = colorType;
   g_colorRules[n].minCount      = minCount;
   g_colorRules[n].action        = action;
   g_colorRules[n].tradeType     = tradeType;
   g_colorRules[n].trendRequired = trendRequired;
   g_colorRules[n].emaRequired   = emaRequired;
  }

// Signal colour groups (matches GetSignalColor in main EA):
//   GREEN  : TREND BUY, W SHAPE BUY               (clrLime / clrGreen)
//   BLUE   : STRONG BUY                            (clrDeepSkyBlue)
//   AQUA   : PRE BUY                               (clrAqua)
//   RED    : TREND SELL, W SHAPE SELL              (clrRed / clrCrimson)
//   PINK   : STRONG SELL                           (clrPink)
//   ORANGE : PRE SELL                              (clrOrange)
//
// ColorType keywords:
//   "ANY GREEN SIGNAL"  — any BUY-direction signal (TREND BUY, W SHAPE BUY, STRONG BUY, PRE BUY)
//   "ANY RED SIGNAL"    — any SELL-direction signal (TREND SELL, W SHAPE SELL, STRONG SELL, PRE SELL)
//   "ANY ORANGE SIGNAL" — PRE SELL only
//   "ANY AQUA SIGNAL"   — PRE BUY only
//   "ANY PINK SIGNAL"   — STRONG SELL only
//   "ANY BLUE SIGNAL"   — STRONG BUY only
int CheckColorRules(string forAction, string forTrade)
  {
   if(g_liveSignalName == "") return -1;

   bool hasBuy  = (StringFind(g_liveSignalName, "BUY")    >= 0);
   bool hasSell = (StringFind(g_liveSignalName, "SELL")   >= 0);
   bool isPre   = (StringFind(g_liveSignalName, "PRE")    >= 0);
   bool isStrong= (StringFind(g_liveSignalName, "STRONG") >= 0);

   // Derived colour flags
   bool isGreen  = hasBuy;                   // any BUY signal
   bool isRed    = hasSell;                  // any SELL signal
   bool isOrange = (isPre   && hasSell);     // PRE SELL
   bool isAqua   = (isPre   && hasBuy);      // PRE BUY
   bool isPink   = (isStrong && hasSell);    // STRONG SELL
   bool isBlue   = (isStrong && hasBuy);     // STRONG BUY

   for(int i = 0; i < ArraySize(g_colorRules); i++)
     {
      if(g_colorRules[i].action    != forAction) continue;
      if(g_colorRules[i].tradeType != forTrade)  continue;
      if(g_currSeqCount < g_colorRules[i].minCount) continue;

      string ct = g_colorRules[i].colorType;
      if(ct == "ANY GREEN SIGNAL"  && !isGreen)  continue;
      if(ct == "ANY RED SIGNAL"    && !isRed)    continue;
      if(ct == "ANY ORANGE SIGNAL" && !isOrange) continue;
      if(ct == "ANY AQUA SIGNAL"   && !isAqua)   continue;
      if(ct == "ANY PINK SIGNAL"   && !isPink)   continue;
      if(ct == "ANY BLUE SIGNAL"   && !isBlue)   continue;

      // --- Trend confirmation (Cond1 for ColorRules) ---
      string tr = g_colorRules[i].trendRequired;
      if(tr != "")
        {
         double closeCurrent = iClose(Symbol(), PERIOD_M5, 0);
         double closePast    = iClose(Symbol(), PERIOD_M5, TrendLookbackBars);
         if(closePast > 0)
           {
            double move       = closeCurrent - closePast;   // +ve = rising, -ve = falling
            double minMove    = closeCurrent * TrendMinMovePercent;
            bool   isUptrend  = (move >=  minMove);
            bool   isDowntrend= (move <= -minMove);

            if(tr == "DOWNTREND" && !isDowntrend)
              {
               Print("ColorRule | BLOCKED [Trend-NoDowntrend] " + ct +
                     " move=" + DoubleToString(move/Point,1) + "pts" +
                     " need DOWNTREND >=" + DoubleToString(TrendMinMovePercent,4) + "% drop");
               continue;
              }
            if(tr == "UPTREND" && !isUptrend)
              {
               Print("ColorRule | BLOCKED [Trend-NoUptrend] " + ct +
                     " move=" + DoubleToString(move/Point,1) + "pts" +
                     " need UPTREND >=" + DoubleToString(TrendMinMovePercent,4) + "% rise");
               continue;
              }
           }
        }

      // --- EMA trend / flat check (Cond2 for ColorRules) ---
      string er = g_colorRules[i].emaRequired;
      if(er != "")
        {
         // Pick EMA params based on trade direction
         int emaPeriod   = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAPeriod    : SeqBuyEMAPeriod;
         int emaShift    = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAShift     : SeqBuyEMAShift;
         int emaFlatMin  = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAFlatMinPts: SeqBuyEMAFlatMinPts;

         double emaNow  = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
         double emaPast = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, emaShift);
         double slopePts = (emaNow - emaPast) / Point;  // +ve = rising, -ve = falling

         // Flat check: slope magnitude must exceed minimum
         if(emaFlatMin > 0 && MathAbs(slopePts) < emaFlatMin)
           {
            Print("ColorRule | BLOCKED [EMA-Flat] " + ct +
                  " EMA(" + IntegerToString(emaPeriod) + ") slope=" +
                  DoubleToString(slopePts,1) + "pts over " + IntegerToString(emaShift) +
                  " bars — FLAT (min " + IntegerToString(emaFlatMin) + "pts required)");
            continue;
           }

         // Direction check
         if(er == "UP" && slopePts <= 0)
           {
            Print("ColorRule | BLOCKED [EMA-NotUp] " + ct +
                  " EMA slope=" + DoubleToString(slopePts,1) + "pts — not rising");
            continue;
           }
         if(er == "DOWN" && slopePts >= 0)
           {
            Print("ColorRule | BLOCKED [EMA-NotDown] " + ct +
                  " EMA slope=" + DoubleToString(slopePts,1) + "pts — not falling");
            continue;
           }
        }

      return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//| Define all strategy patterns here                                |
//| Called once from OnInit()                                        |
//+------------------------------------------------------------------+
void InitStrategyRules()
  {
   ArrayResize(g_seqRules, 0); // clear any previous rules


// W SHAPE SELL 1 → TREND SELL 1 → TREND SELL 2  ==>  NEW SELL order

//AddSeqRule("", "", "TREND SELL 1", "NEW_ORDER", "SELL");
//AddSeqRule("", "TREND SELL 1", "TREND SELL 2", "NEW_ORDER", "SELL");
//RISK //AddSeqRule("TREND SELL 1", "TREND SELL 2", "TREND SELL 3", "NEW_ORDER", "SELL");//RISK

// AddSeqRule("TREND SELL 5", "TREND SELL 6", "TREND SELL 7", "NEW_ORDER", "SELL");

/*AddSeqRule("TREND SELL 2", "TREND SELL 3", "PRE SELL 1", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 3", "TREND SELL 4", "PRE SELL 1", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 5", "TREND SELL 6", "PRE SELL 1", "NEW_ORDER", "SELL");*/

/*
AddSeqRule("TREND SELL 2", "TREND SELL 3", "TREND SELL 4", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 3", "TREND SELL 4", "TREND SELL 5", "NEW_ORDER", "SELL");

AddSeqRule("TREND SELL 2", "TREND SELL 3", "PRE SELL 1", "NEW_ORDER", "SELL");

AddSeqRule(  "TREND SELL 1", "PRE SELL 1","TREND SELL 1", "NEW_ORDER", "SELL");
AddSeqRule(  "TREND SELL 2", "PRE SELL 3","TREND SELL 1", "NEW_ORDER", "SELL");
AddSeqRule(  "TREND SELL 3", "PRE SELL 1","TREND SELL 1", "NEW_ORDER", "SELL");
AddSeqRule(  "TREND SELL 4", "PRE SELL 1","TREND SELL 1",  "NEW_ORDER", "SELL");
AddSeqRule(  "TREND SELL 5", "PRE SELL 1","TREND SELL 1",  "NEW_ORDER", "SELL");
*/

//buy rules
//AddSeqRule("", "", "TREND BUY 1", "NEW_ORDER", "BUY");
//AddSeqRule("", "TREND BUY 1", "TREND BUY 2", "NEW_ORDER", "BUY");

/*
AddSeqRule("PRE BUY 1", "TREND BUY 1", "TREND BUY 2", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 1", "TREND BUY 1", "PRE BUY 1", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 1", "TREND BUY 1", "TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 1", "PRE BUY 2", "PRE BUY 3", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 3", "PRE BUY 1", "PRE BUY 2", "NEW_ORDER", "BUY");

AddSeqRule("PRE BUY 1", "PRE BUY 2", "TREND BUY 3", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 1", "PRE BUY 3", "TREND BUY 1", "NEW_ORDER", "BUY");

 


AddSeqRule("TREND BUY 1", "TREND BUY 2", "TREND BUY 3", "NEW_ORDER", "BUY");

AddSeqRule("TREND BUY 2", "TREND BUY 3", "PRE BUY 1", "NEW_ORDER", "BUY");

//RISK - AddSeqRule("TREND BUY 2", "TREND BUY 3", "TREND BUY 4", "NEW_ORDER", "BUY");
AddSeqRule("TREND BUY 3", "TREND BUY 4", "TREND BUY 5", "NEW_ORDER", "BUY");

AddSeqRule(  "TREND BUY 1", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 2", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 3", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 4", "PRE BUY 1","TREND BUY 1",  "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 5", "PRE BUY 1","TREND BUY 1",  "NEW_ORDER", "BUY");

*/
//practical my idea 

//AddSeqRule("PRE BUY 1", "TREND BUY 1", "TREND BUY 2", "NEW_ORDER", "BUY");

 /*
AddSeqRule("TREND BUY 1","TREND BUY 2","TREND BUY 3","NEW_ORDER","BUY");
// AddSeqRule("TREND BUY 2","TREND BUY 3","TREND BUY 4","NEW_ORDER","BUY");
AddSeqRule("TREND BUY 3","TREND BUY 4","TREND BUY 5","NEW_ORDER","BUY");
// AddSeqRule("TREND BUY 4","TREND BUY 5","TREND BUY 6","NEW_ORDER","BUY");
AddSeqRule("TREND BUY 5","TREND BUY 6","TREND BUY 7","NEW_ORDER","BUY");
 
 

 
AddSeqRule("PRE BUY 1","TREND BUY 1","TREND BUY 2","NEW_ORDER","BUY");
 


AddSeqRule("","TREND SELL 1","TREND SELL 2","NEW_ORDER","SELL");
AddSeqRule("TREND SELL 1","TREND SELL 2","TREND SELL 3","NEW_ORDER","SELL");
// AddSeqRule("TREND SELL 2","TREND SELL 3","TREND SELL 4","NEW_ORDER","SELL");
AddSeqRule("TREND SELL 3","TREND SELL 4","TREND SELL 5","NEW_ORDER","SELL");
// AddSeqRule("TREND SELL 4","TREND SELL 5","TREND SELL 6","NEW_ORDER","SELL");
AddSeqRule("TREND SELL 5","TREND SELL 6","TREND SELL 7","NEW_ORDER","SELL");

*/
/*
   // ------------------------------------------------------------------
   // SELL patterns
   // ------------------------------------------------------------------
   // W SHAPE SELL 1 → TREND SELL 1 → TREND SELL 2  ==>  NEW SELL order
   AddSeqRule("W SHAPE SELL 1", "TREND SELL 1", "TREND SELL 2", "NEW_ORDER", "SELL");

   // PRE SELL 1 → TREND SELL 1 → TREND SELL 2  ==>  NEW SELL order
   AddSeqRule("PRE SELL 1",     "TREND SELL 1", "TREND SELL 2", "NEW_ORDER", "SELL");

   // any → TREND SELL 1 → TREND SELL 2  ==>  NEW SELL order
   AddSeqRule("",               "TREND SELL 1", "TREND SELL 2", "NEW_ORDER", "SELL");

   // ------------------------------------------------------------------
   // BUY patterns
   // ------------------------------------------------------------------
   // W SHAPE BUY 1 → TREND BUY 1 → TREND BUY 2  ==>  NEW BUY order
   AddSeqRule("W SHAPE BUY 1",  "TREND BUY 1",  "TREND BUY 2",  "NEW_ORDER", "BUY");

   // PRE BUY 1 → TREND BUY 1 → TREND BUY 2  ==>  NEW BUY order
   AddSeqRule("PRE BUY 1",      "TREND BUY 1",  "TREND BUY 2",  "NEW_ORDER", "BUY");

   // any → TREND BUY 1 → TREND BUY 2  ==>  NEW BUY order
   AddSeqRule("",               "TREND BUY 1",  "TREND BUY 2",  "NEW_ORDER", "BUY");

   // ------------------------------------------------------------------
   // REVERSAL / CROSS patterns
   // ------------------------------------------------------------------
   // any → TREND SELL 2 → TREND BUY 1  ==>  NEW BUY order (reversal)
   AddSeqRule("",               "TREND SELL 2", "TREND BUY 1",  "NEW_ORDER", "BUY");

   // any → TREND BUY 2 → TREND SELL 1  ==>  NEW SELL order (reversal)
   AddSeqRule("",               "TREND BUY 2",  "TREND SELL 1", "NEW_ORDER", "SELL");

   // ------------------------------------------------------------------
   // CLOSE patterns
   // ------------------------------------------------------------------
   // any → any → STRONG BUY 1  ==>  CLOSE SELL positions
   AddSeqRule("",               "",             "STRONG BUY 1", "CLOSE",     "SELL");

   // any → any → STRONG SELL 1  ==>  CLOSE BUY positions
   AddSeqRule("",               "",             "STRONG SELL 1","CLOSE",     "BUY");*/

/*

AddSeqRule("PRE BUY 1","TREND BUY 1","TREND BUY 2","NEW_ORDER","BUY");

AddSeqRule("","","PRE SELL 1","CLOSE","BUY");
AddSeqRule("","","W SHAPE SELL 1","CLOSE","BUY");




AddSeqRule("TREND SELL 2","TREND SELL 3","TREND SELL 4","NEW_ORDER","SELL");

 
AddSeqRule("","","PRE BUY 1","CLOSE","SELL");

*/
//-----------------BUY NEW ORDER--------------
AddColorRule( "ANY GREEN SIGNAL","COUNT_2","NEW_ORDER","BUY", "", "UP");

//-----------------BUY CLOSE ORDER--------------

// AddColorRule( "ANY ORANGE SIGNAL","COUNT_1","CLOSE","BUY");
AddColorRule( "ANY RED SIGNAL","COUNT_2","CLOSE","BUY");
// AddSeqRule("","","W SHAPE SELL 1","CLOSE","BUY"); //sometimes stop loss hitting
// AddSeqRule("","","PRE SELL 1","CLOSE","BUY");
// AddSeqRule("","","STRONG BUY 1","CLOSE","BUY");
// AddSeqRule("","","STRONG BUY 2","CLOSE","BUY");
//-----------------  SELL NEW_ORDER--------------
AddColorRule( "ANY RED SIGNAL","COUNT_2","NEW_ORDER","SELL", "", "DOWN");
AddColorRule( "ANY RED SIGNAL","COUNT_2","NEW_ORDER","SELL", "DOWNTREND", "DOWN");
AddSeqRule("TREND SELL 1","TREND SELL 2","TREND SELL 3","NEW_ORDER","SELL");
AddSeqRule("","TREND SELL 1","TREND SELL 2","NEW_ORDER","SELL");
AddSeqRule("","","W SHAPE BUY 1","NEW_ORDER","SELL");
AddSeqRule("","","W STRONG BUY 1","NEW_ORDER","SELL"); 
AddColorRule( "ANY BLUE SIGNAL","COUNT_1","NEW_ORDER","SELL", "", "");
// AddColorRule( "ANY ORANGE SIGNAL","COUNT_2","NEW_ORDER","SELL");
//-----------------CLOSE SELL ORDER--------------
AddColorRule( "ANY GREEN SIGNAL","COUNT_1","CLOSE","SELL");
// AddSeqRule("","","STRONG SELL 4","CLOSE","SELL");
// AddSeqRule("","","STRONG SELL 2","CLOSE","SELL");
AddSeqRule("","","W SHAPE SELL 1","CLOSE","SELL");


//WRONG ENTRIES - BLOCK 




// // No EMA check (existing behaviour — unchanged)
// AddColorRule("ANY GREEN SIGNAL", "COUNT_2", "NEW_ORDER", "BUY");

// // BUY only when EMA is trending UP and not flat
// AddColorRule("ANY GREEN SIGNAL", "COUNT_2", "NEW_ORDER", "BUY", "", "UP");

// // SELL only when EMA is trending DOWN and not flat  
// AddColorRule("ANY RED SIGNAL",   "COUNT_2", "NEW_ORDER", "SELL", "", "DOWN");

// // Both M30 downtrend AND EMA falling required
// AddColorRule("ANY RED SIGNAL",   "COUNT_2", "NEW_ORDER", "SELL", "DOWNTREND", "DOWN");


// // No trend check (existing behaviour — default)
// AddColorRule("ANY GREEN SIGNAL", "COUNT_2", "NEW_ORDER", "BUY");

// // Only BUY when M30 is confirmed rising
// AddColorRule("ANY GREEN SIGNAL", "COUNT_2", "NEW_ORDER", "BUY", "UPTREND");

// // Only SELL when M30 is confirmed falling
// AddColorRule("ANY RED SIGNAL",   "COUNT_2", "NEW_ORDER", "SELL", "DOWNTREND");

// // CLOSE rules usually don't need trend filter (leave blank)
// AddColorRule("ANY ORANGE SIGNAL","COUNT_1", "CLOSE",     "BUY");





  }

#endif
