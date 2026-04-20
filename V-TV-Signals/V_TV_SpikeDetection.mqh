// ===================================================
// MASTER SPIKE CHECK — combines all 3 methods
// ===================================================
bool IsSpikeActive()
{
   // Method 1: single big candle
   bool candleSpike = IsSpikeCandleDetected();

   // Method 2: real-time tick gap
   //////bool tickSpike = g_spikeDetected;

   // Method 3: abnormal vs average
   //////bool abnormalC1 = IsAbnormalCandle(1);
   /////bool abnormalC2 = IsAbnormalCandle(2);

//    return (candleSpike || tickSpike || abnormalC1 || abnormalC2);

return (candleSpike);
}

// ===================================================
// USE IN YOUR OnTick()
// ===================================================
// void OnTick()
// {
//    // Step 1: always detect tick spike first
//    DetectTickSpike();

//    // Step 2: check spike before any trading
//    if(IsSpikeActive())
//    {
//       Print("Trading PAUSED — spike active.");
//       return;
//    }

   
// }

// ===================================================
// DETECT IF CURRENT CANDLE IS ABNORMALLY LARGE
// Compares to average of last N candles
// ===================================================
bool IsAbnormalCandle(int bar = 1)
{
   int    lookback     = 20;   // compare to last 20 candles
   double multiplier   = 3.0;  // spike = 3x average size

   // Calculate average candle body over lookback
   double totalBody = 0;
   for(int i = 2; i <= lookback + 1; i++)
      totalBody += MathAbs(Close[i] - Open[i]);

   double avgBody    = totalBody / lookback;
   double thisBody   = MathAbs(Close[bar] - Open[bar]);
   double thisHeight = High[bar] - Low[bar];

   // Spike if body is 3x average OR height is 4x average
   bool bodySpike   = (thisBody   >= avgBody * multiplier);
   bool heightSpike = (thisHeight >= avgBody * 4.0);

   if(bodySpike || heightSpike)
   {
      Print("Abnormal candle on bar ", bar,
            " | Body: ", thisBody / Point, " pts",
            " | Avg body: ", avgBody / Point, " pts",
            " | Ratio: ", DoubleToStr(thisBody / avgBody, 1), "x");
      return true;
   }

   return false;
}

// ===================================================
// GLOBAL — declare at top of EA
// ===================================================
double g_lastBid         = 0;
double g_lastAsk         = 0;
double g_maxTickGap      = 0;
bool   g_spikeDetected   = false;
datetime g_spikeTime     = 0;
int    g_spikeCooldown   = 5; // seconds to stay blocked after spike

// ===================================================
// CALL THIS AT THE VERY TOP OF OnTick()
// ===================================================
void DetectTickSpike()
{
   double currentBid = Bid;
   double currentAsk = Ask;

   if(g_lastBid == 0)
   {
      g_lastBid = currentBid;
      g_lastAsk = currentAsk;
      return;
   }

   // Gap between this tick and last tick
   double tickGapPoints = MathAbs(currentBid - g_lastBid) / Point;

   // Track max gap seen
   if(tickGapPoints > g_maxTickGap)
      g_maxTickGap = tickGapPoints;

   // -----------------------------------------------
   // BTCUSD: flag spike if single tick moves 1000+ pts
   // Tune this threshold to your broker's data quality
   // -----------------------------------------------
   double spikeTickThreshold = 1000*10; // points in single tick

   if(tickGapPoints >= spikeTickThreshold)
   {
      g_spikeDetected = true;
      g_spikeTime     = TimeCurrent();

      Print("!!! SPIKE DETECTED !!!");
    //   Print("Tick gap    : ", tickGapPoints, " points");
    //   Print("Last Bid    : ", g_lastBid);
    //   Print("Current Bid : ", currentBid);
    //   Print("Time        : ", TimeToStr(g_spikeTime));
   }

   // Auto-clear spike flag after cooldown period
   if(g_spikeDetected &&
      TimeCurrent() - g_spikeTime > g_spikeCooldown)
   {
      g_spikeDetected = false;
      g_maxTickGap    = 0;
      Print("Spike cooldown ended — trading resumed.");
   }

   // Update last tick prices
   g_lastBid = currentBid;
   g_lastAsk = currentAsk;
}

// ===================================================
// DETECT SPIKE CANDLE — checks current and recent bars
// ===================================================
bool IsSpikeCandleDetected()
{
   // Current candle (bar 0 = live forming candle)
   double c0Body   = MathAbs(Close[0] - Open[0]) / Point;
   double c0Height = (High[0] - Low[0]) / Point;

   // Last closed candle (bar 1)
   double c1Body   = MathAbs(Close[1] - Open[1]) / Point;
   double c1Height = (High[1] - Low[1]) / Point;

   // Last 2 closed candles (bar 2)
   double c2Body   = MathAbs(Close[2] - Open[2]) / Point;
   double c2Height = (High[2] - Low[2]) / Point;

   // -----------------------------------------------
   // BTCUSD spike thresholds — tune these
   // -----------------------------------------------
   double minSpikeBody   = 2000*10;  // body  >= 2000 pts = spike
   double minSpikeHeight = 3000*10;  // total wick >= 3000 pts = spike

   Print("Candle 0 | Body: ", c0Body, " pts | Height: ", c0Height, " pts");
   Print("Candle 1 | Body: ", c1Body, " pts | Height: ", c1Height, " pts");
   Print("Candle 2 | Body: ", c2Body, " pts | Height: ", c2Height, " pts");

   // Detect on any of last 3 bars
   bool spike0 = (c0Body >= minSpikeBody || c0Height >= minSpikeHeight);
   bool spike1 = (c1Body >= minSpikeBody || c1Height >= minSpikeHeight);
   bool spike2 = (c2Body >= minSpikeBody || c2Height >= minSpikeHeight);

//    2026.04.20 20:32:31.619	2026.04.16 00:09:01  V-TV-Signals BTCUSDm,M1: Candle 2 | Body: 3306.999999999243 pts | Height: 4430.999999999767 pts
// 2026.04.20 20:32:31.619	2026.04.16 00:09:01  V-TV-Signals BTCUSDm,M1: Candle 1 | Body: 4241.000000000349 pts | Height: 6822.000000000116 pts
// 2026.04.20 20:32:31.619	2026.04.16 00:09:01  V-TV-Signals BTCUSDm,M1: Candle 0 | Body: 580.9999999997672 pts | Height: 580.9999999997672 pts


   return (spike0 || spike1 || spike2);
}