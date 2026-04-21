// ===================================================
// Last 10 candles recorded as color string (oldest→newest)
// G = green, R = red, D = doji, X = any (wildcard)
//
// Add as many BUY / SELL patterns as you want below.
// Signal fires if ANY pattern matches.
// ===================================================

string BuyPatterns[]  = {
   //"RRRG",
   //"RRXG",
   "RRRR",
   // "RRRG"
  // "GGGGGG",


   // add more buy patterns here...
};

string SellPatterns[] = {
   //"GGGR",
   //"GGXR",
      "GGGG",
      // "GGGR"
  // "RRRRRR"


   // add more sell patterns here...
};

// ===================================================

bool MatchPattern(string colors, string pattern)
{
   int pLen = StringLen(pattern);
   int cLen = StringLen(colors);
   if(pLen > cLen) return false;

   string tail = StringSubstr(colors, cLen - pLen, pLen);
   for(int i = 0; i < pLen; i++)
   {
      string pc = StringSubstr(pattern, i, 1);
      if(pc == "X") continue;
      if(pc != StringSubstr(tail, i, 1)) return false;
   }
   return true;
}

int GetCreateNewOrderCandleReversalSignalStrong()
{

            double gap = GetEMAGapPoints(FastEMA, SlowEMA);

if(gap>3000) return 0;

   // Build 10-candle color string: index 0 = C9 (oldest), index 9 = C0 (newest)
   string colors = "";
   for(int i = 4; i >= 0; i--)
   {
      if(Close[i] > Open[i])      colors += "G";
      else if(Close[i] < Open[i]) colors += "R";
      else                        colors += "D";
   }

   Print("Candles (old→new): ", colors);

   // Check all buy patterns
   for(int b = 0; b < ArraySize(BuyPatterns); b++)
   {
      if(MatchPattern(colors, BuyPatterns[b]))
      {
         Print(">>> BUY pattern matched: ", BuyPatterns[b], " in ", colors);
         ProcessSeqBuyOrders(false,false,false);
         return 1;
      }
   }

   // Check all sell patterns
   for(int s = 0; s < ArraySize(SellPatterns); s++)
   {
      if(MatchPattern(colors, SellPatterns[s]))
      {
         Print(">>> SELL pattern matched: ", SellPatterns[s], " in ", colors);
         ProcessSeqSellOrders(false,false,false);
         return -1;
      }
   }

   return 0;
}
