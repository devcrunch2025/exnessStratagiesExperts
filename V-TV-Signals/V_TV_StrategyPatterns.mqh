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

//RISK - AddSeqRule(  "TREND BUY 1", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 2", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 3", "PRE BUY 1","TREND BUY 1", "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 4", "PRE BUY 1","TREND BUY 1",  "NEW_ORDER", "BUY");
AddSeqRule(  "TREND BUY 5", "PRE BUY 1","TREND BUY 1",  "NEW_ORDER", "BUY");

///***********************************************************************

//suggestions from chat
AddSeqRule("PRE BUY 3", "PRE BUY 1", "PRE BUY 2", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 3", "TREND BUY 1", "PRE BUY 1", "NEW_ORDER", "BUY");
//AddSeqRule("PRE BUY 3", "PRE BUY 1", "PRE BUY 2", "NEW_ORDER", "BUY");
AddSeqRule("PRE BUY 2", "PRE BUY 3", "PRE BUY 1", "NEW_ORDER", "BUY");

 


   

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
