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

   // --- Base detection ---
   bool hasBuy  = (StringFind(g_liveSignalName, "TREND BUY")  >= 0);
   bool hasSell = (StringFind(g_liveSignalName, "TREND SELL") >= 0);

   bool anyBuy  =  (StringFind(g_liveSignalName, "BUY")  >= 0);
   bool anySell = (StringFind(g_liveSignalName, "SELL") >= 0);

   bool isPre    = (StringFind(g_liveSignalName, "PRE")    >= 0);
   bool isStrong = (StringFind(g_liveSignalName, "STRONG") >= 0);

   bool isShape = (StringFind(g_liveSignalName, "SHAPE") >= 0);
double emaFast = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 0);
double emaSlow = iMA(Symbol(), 0, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

double gapPoints =  MathAbs(emaFast - emaSlow) / Point;
// double minGap = 150;   // 🔥 adjust this

double atr = iATR(Symbol(), 0, 14, 0) / Point;
double minGap = atr * 0.5;   // 50% of volatility
// 2️⃣ Price position
   double price = iClose(Symbol(), 0, 0);

   double upper = MathMax(emaFast, emaSlow);
   double lower = MathMin(emaFast, emaSlow);
// --- APPLY ONLY FOR NEW ORDER ---
if(forAction == "NEW_ORDER")
{

 
   if(gapPoints < minGap)
   {
      //Print("EMA GAP TOO SMALL → Skip trade | Gap=", gapPoints);
      return -1;
   }
 

   // 1️⃣ Flat market filter
   if(gapPoints < 20    )
   {
     //////// Print("Market is flat → skip trade");
      return -1;
   }

   

   // --- ABOVE both EMAs ---
   if(price > upper)
   {
      if(forTrade != "BUY"  )
      {
         ///////Print("ABOVE → Block SELL");
         return -1;
      }
   }

   // --- BELOW both EMAs ---
   else if(price < lower  )
   {

    
      if(forTrade != "SELL")
      {
         //Print("BELOW → Block BUY");
         return -1;
      }
   }

   // --- INSIDE zone ---
   else if(forAction == "NEW_ORDER")
   {
      /////Print("INSIDE → Skip trade");
      return -1;
   }
}
 



   // --- Derived colors ---
   bool isGreen  = hasBuy;                   // TREND BUY
   bool isRed    = hasSell;                  // TREND SELL
   bool isOrange = (isPre   && anySell);     // PRE SELL
   bool isAqua   = (isPre   && anyBuy);      // PRE BUY
   bool isPink   = ((isStrong || isShape) && anySell);    // STRONG SELL
   bool isBlue   = ((isStrong || isShape) && anyBuy);     // STRONG BUY

   for(int i = 0; i < ArraySize(g_colorRules); i++)
   {
      if(g_colorRules[i].action    != forAction) continue;
      if(g_colorRules[i].tradeType != forTrade)  continue;
      if(g_currSeqCount < g_colorRules[i].minCount) continue;

      string ct = g_colorRules[i].colorType;

      // --- PURE COLOR MATCH ---
      if(ct == "ANY GREEN SIGNAL"  && hasBuy)  return i;
      if(ct == "ANY RED SIGNAL"    && hasSell)    return i;
      if(ct == "ANY ORANGE SIGNAL" && isOrange) return i;
      if(ct == "ANY AQUA SIGNAL"   && isAqua)   return i;
      if(ct == "ANY PINK SIGNAL"   && isPink)   return i;
      if(ct == "ANY BLUE SIGNAL"   && isBlue)   return i;

      // --- OPTIONAL fallback (if you want generic BUY/SELL) ---
      // if(ct == "ANY BUY SIGNAL"  && anyBuy)  return i;
      // if(ct == "ANY SELL SIGNAL" && anySell) return i;
   }

   return -1;
}
int CheckColorRules_OLD(string forAction, string forTrade)
  {
   if(g_liveSignalName == "") return -1;

   bool hasBuy  = (StringFind(g_liveSignalName, "TREND BUY")    >= 0);
   bool hasSell = (StringFind(g_liveSignalName, "TREND SELL")   >= 0);

   bool anyBuy  = (StringFind(g_liveSignalName, "BUY")    >= 0);
   bool anySell = (StringFind(g_liveSignalName, "SELL")   >= 0);

   bool isPre   = (StringFind(g_liveSignalName, "PRE")    >= 0);
   bool isStrong= (StringFind(g_liveSignalName, "STRONG") >= 0);

   // Derived colour flags
   bool isGreen  = hasBuy;                   // any BUY signal
   bool isRed    = hasSell;                  // any SELL signal
   bool isOrange = (isPre   && anySell);     // PRE SELL
   bool isAqua   = (isPre   && anyBuy);      // PRE BUY
   bool isPink   = (isStrong && anySell);    // STRONG SELL
   bool isBlue   = (isStrong && anyBuy);     // STRONG BUY

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

        //check price gap between signals (Cond5 for ColorRules) - compare current signal price to previous signal price in pattern
      // --- Direction check (NEW CONDITION) ---
if(hasBuy)
  {
/*int emaPeriod   =SeqBuyEMAPeriod ;
  
double ema = iMA(Symbol(),0,emaPeriod,0,MODE_EMA,PRICE_CLOSE,0);
double distancePts = MathAbs(Bid - ema) / Point;

// 🔧 tune this per pair
double maxDistance = 150; 

if(distancePts > maxDistance)
{
   Print("BLOCKED: Price too far from EMA (overextended)");
   continue;
}*/
/*
   // BUY: current price must be higher than previous signal price
   if(g_currSignalPrice <= g_prevSignalPrice)
     {
      Print("ColorRule | BLOCKED [BUY-PriceDirection] " + ct +
            " current=" + DoubleToString(g_currSignalPrice,Digits) +
            " <= prev=" + DoubleToString(g_prevSignalPrice,Digits));
      continue;
     }
  }

if(hasSell)
  {
   // SELL: current price must be lower than previous signal price
   if(g_currSignalPrice >= g_prevSignalPrice)
     {
      Print("ColorRule | BLOCKED [SELL-PriceDirection] " + ct +
            " current=" + DoubleToString(g_currSignalPrice,Digits) +
            " >= prev=" + DoubleToString(g_prevSignalPrice,Digits));
      continue;
     }*/
  }

      // --- EMA trend / flat check (Cond2 for ColorRules) ---
     string er = g_colorRules[i].emaRequired;
if(er != "")
{
   // Params
   int emaPeriod   = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAPeriod     : SeqBuyEMAPeriod;
   int emaShift    = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAShift      : SeqBuyEMAShift;
   int emaFlatMin  = (g_colorRules[i].tradeType == "SELL") ? SeqSellEMAFlatMinPts : SeqBuyEMAFlatMinPts;

   // EMA values
   double emaNow  = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   double emaPast = iMA(Symbol(), 0, emaPeriod, 0, MODE_EMA, PRICE_CLOSE, emaShift);

   // Slope in points
   double slopePts = (emaNow - emaPast) / Point;

   // 👉 Convert to ANGLE (degrees)
   double angle = MathArctan(slopePts) * 180.0 / M_PI;

   // --- FLAT CHECK ---
   if(emaFlatMin > 0 && MathAbs(slopePts) < emaFlatMin)
   {
      Print("ColorRule | BLOCKED [EMA-FLAT] " + ct +
            " slope=" + DoubleToString(slopePts,1) +
            " angle=" + DoubleToString(angle,1));
      continue;
   }

   // --- DIRECTION + STRENGTH CHECK ---
   // Tune these thresholds
   double weakAngle   = 5.0;
   double strongAngle = 20.0;

   // UP required
   if(er == "UP")
   {
      if(angle <= weakAngle)
      {
         Print("ColorRule | BLOCKED [EMA-NOT-UP] " + ct +
               " angle=" + DoubleToString(angle,1));
         continue;
      }
   }

   // DOWN required
   if(er == "DOWN")
   {
      if(angle >= -weakAngle)
      {
         Print("ColorRule | BLOCKED [EMA-NOT-DOWN] " + ct +
               " angle=" + DoubleToString(angle,1));
         continue;
      }
   }

   // --- OPTIONAL: STRONG FILTER (very useful for TREND signals) ---
   if(er == "STRONG_UP" && angle < strongAngle)
   {
      Print("ColorRule | BLOCKED [EMA-WEAK-UP] " + ct +
            " angle=" + DoubleToString(angle,1));
      continue;
   }

   if(er == "STRONG_DOWN" && angle > -strongAngle)
   {
      Print("ColorRule | BLOCKED [EMA-WEAK-DOWN] " + ct +
            " angle=" + DoubleToString(angle,1));
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
 
AddColorRule( "ANY GREEN SIGNAL","COUNT_1","NEW_ORDER","BUY");


//-----------------BUY CLOSE ORDER--------------
 if(CloseOrderONLYProfitNotSignal==false)
    {
AddColorRule( "ANY RED SIGNAL","COUNT_1","CLOSE","BUY");
AddColorRule( "ANY PINK SIGNAL","COUNT_1","CLOSE","BUY");
AddColorRule( "ANY ORANGE SIGNAL","COUNT_1","CLOSE","BUY");
 AddSeqRule("TREND BUY 1","TREND BUY 2","TREND BUY 3","CLOSE","BUY");// this just for stop loss
 
    }


//-----------------SELL NEW ORDER--------------

AddColorRule( "ANY RED SIGNAL","COUNT_1","NEW_ORDER","SELL");

if(CloseOrderONLYProfitNotSignal==false)
    {

    AddColorRule( "ANY GREEN SIGNAL","COUNT_1","CLOSE","SELL");
AddColorRule( "ANY BLUE SIGNAL","COUNT_1","CLOSE","SELL");
AddColorRule( "ANY PINK SIGNAL","COUNT_1","CLOSE","SELL");
 AddSeqRule("TREND SELL 1","TREND SELL 2","TREND SELL 3","CLOSE","SELL");// this just for stop loss

    }
 
  
 

  }

#endif
