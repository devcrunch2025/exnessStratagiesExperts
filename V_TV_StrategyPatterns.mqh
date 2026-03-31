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

//--- Seq signal price history (built fresh each tick loop pass) -------
struct SeqSignalEntry
  {
   string label;   // e.g. "TREND SELL 2"
   double price;   // High[i] of the bar where this signal fired
  };

SeqSignalEntry g_trendSellSeq[];   // current SELL sequence entries

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
//| Define all strategy patterns here                                |
//| Called once from OnInit()                                        |
//+------------------------------------------------------------------+
void InitStrategyRules()
  {
   ArrayResize(g_seqRules, 0); // clear any previous rules


// W SHAPE SELL 1 → TREND SELL 1 → TREND SELL 2  ==>  NEW SELL order

//AddSeqRule("", "", "TREND SELL 1", "NEW_ORDER", "SELL");
//AddSeqRule("", "TREND SELL 1", "TREND SELL 2", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 2", "TREND SELL 3", "TREND SELL 4", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 3", "TREND SELL 4", "TREND SELL 5", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 5", "TREND SELL 6", "TREND SELL 7", "NEW_ORDER", "SELL");

AddSeqRule("TREND SELL 2", "TREND SELL 3", "PREE SELL 1", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 3", "TREND SELL 4", "PREE SELL 1", "NEW_ORDER", "SELL");
AddSeqRule("TREND SELL 5", "TREND SELL 6", "PREE SELL 1", "NEW_ORDER", "SELL");
   

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
  }

#endif
