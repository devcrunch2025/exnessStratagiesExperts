// ===================================================
// GLOBAL VARIABLES — declare at top of EA
// ===================================================
int    g_consecutiveLosses  = 0;
int    g_lastCheckedTicket  = 0;  // tracks last processed order
double defaultBuyTarget     = 3;
double defaultSellTarget    = 3;

// ===================================================
// AUTO LOSS TRACKER — reads from order history
// Call this in OnTick() BEFORE GetMarketTrendStrengthClaude1()
// ===================================================
void AutoUpdateLossTracker()
{
   int totalHistory = OrdersHistoryTotal();
   if(totalHistory == 0) return;

   // Find the most recent closed order
   int    lastTicket    = 0;
   double lastProfit    = 0;
   datetime lastCloseTime = 0;

   for(int i = totalHistory - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;

      // Only check BUY and SELL orders (not balance/deposit)
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      // Only check orders from this EA (magic number filter)
      if(OrderType()==OP_BUY && OrderMagicNumber() != SeqBuyMagicNo) continue;
      else if(OrderType()==OP_SELL && OrderMagicNumber() != SeqSellMagicNo) continue;   

      // Only check orders on this symbol
      if(OrderSymbol() != Symbol()) continue;

      // Get the most recent closed order
      if(OrderCloseTime() > lastCloseTime)
      {
         lastCloseTime = OrderCloseTime();
         lastTicket    = OrderTicket();
         lastProfit    = OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   // Only process if this is a NEW closed order we haven't seen
   if(lastTicket == 0) return;
   if(lastTicket == g_lastCheckedTicket) return;

   // Update tracker with new result
   g_lastCheckedTicket = lastTicket;

   if(lastProfit < 0)
   {
      g_consecutiveLosses++;
      Print("Loss detected. Ticket: ", lastTicket,
            " | Profit: ", lastProfit,
            " | Consecutive losses: ", g_consecutiveLosses);
   }
   else
   {
      g_consecutiveLosses = 0;
      Print("Win detected. Ticket: ", lastTicket,
            " | Profit: ", lastProfit,
            " | Loss streak reset.");
   }
}

// ===================================================
// LOSS STATS HELPER — shows full history analysis
// Optional: call in OnInit() to see historical stats
// ===================================================
void PrintLossStats()
{
   int totalHistory = OrdersHistoryTotal();
   int totalOrders  = 0;
   int totalWins    = 0;
   int totalLosses  = 0;
   double totalProfit = 0;
   double totalLoss   = 0;
   int    currentStreak = 0;
   int    maxLossStreak = 0;
   bool   lastWasLoss   = false;

   for(int i = 0; i < totalHistory; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
    //   if(OrderMagicNumber() != MagicNumber) continue;

if(OrderType()==OP_BUY && OrderMagicNumber() != SeqBuyMagicNo) continue;
else if(OrderType()==OP_SELL && OrderMagicNumber() != SeqSellMagicNo) continue;

      if(OrderSymbol() != Symbol()) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      totalOrders++;

      if(profit >= 0)
      {
         totalWins++;
         totalProfit += profit;
         currentStreak = 0;
         lastWasLoss   = false;
      }
      else
      {
         totalLosses++;
         totalLoss += profit;
         if(lastWasLoss) currentStreak++;
         else            currentStreak = 1;
         if(currentStreak > maxLossStreak)
            maxLossStreak = currentStreak;
         lastWasLoss = true;
      }
   }

   double winRate = (totalOrders > 0) ?
      (double)totalWins / totalOrders * 100 : 0;

   Print("=== LOSS STATS ===");
   Print("Total Orders  : ", totalOrders);
   Print("Total Wins    : ", totalWins);
   Print("Total Losses  : ", totalLosses);
   Print("Win Rate      : ", DoubleToStr(winRate, 1), "%");
   Print("Total Profit  : ", DoubleToStr(totalProfit, 2));
   Print("Total Loss    : ", DoubleToStr(totalLoss, 2));
   Print("Net P&L       : ", DoubleToStr(totalProfit + totalLoss, 2));
   Print("Max Loss Streak: ", maxLossStreak);
   Print("Current Losses: ", g_consecutiveLosses);
   Print("==================");
}

// ===================================================
// MAIN TREND FUNCTION
// ===================================================
void CreateNewTrendStrengthClaude()
{
   // Auto-detect losses from history first
   AutoUpdateLossTracker();

   int trend = GetMarketTrendStrengthClaude1();
   UpdateProfitTargets(trend);

   Print("Current Trend Strength: ", trend,
         " | Consecutive Losses: ", g_consecutiveLosses,
         " | Max Buy Orders: ", SeqBuyMaxOrders,
         " | Max Sell Orders: ", SeqSellMaxOrders,
         " | Buy TP: $", SeqBuyProfitTarget,
         " | Sell TP: $", SeqSellProfitTarget);

   if(trend == 4)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders + 2;
      SeqSellMaxOrders = defaultMaxSellOrders;
      ProcessSeqBuyOrders(true);
   }
   else if(trend == 3)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders + 1;
      SeqSellMaxOrders = defaultMaxSellOrders;
      ProcessSeqBuyOrders(true);
   }
   else if(trend == 2)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      SeqSellMaxOrders = defaultMaxSellOrders;
      ProcessSeqBuyOrders(true);
   }
   else if(trend == 1)
   {
      SeqBuyMaxOrders  = MathMax(1, defaultMaxBuyOrders - 1);
      SeqSellMaxOrders = defaultMaxSellOrders;
      ProcessSeqBuyOrders(true);
   }
   else if(trend == -4)
   {
      SeqSellMaxOrders = defaultMaxSellOrders + 2;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      ProcessSeqSellOrders(true);
   }
   else if(trend == -3)
   {
      SeqSellMaxOrders = defaultMaxSellOrders + 1;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      ProcessSeqSellOrders(true);
   }
   else if(trend == -2)
   {
      SeqSellMaxOrders = defaultMaxSellOrders;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      ProcessSeqSellOrders(true);
   }
   else if(trend == -1)
   {
      SeqSellMaxOrders = MathMax(1, defaultMaxSellOrders - 1);
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      ProcessSeqSellOrders(true);
   }
   else
   {
      // No trend — reset everything to default
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      SeqSellMaxOrders = defaultMaxSellOrders;
   }
}

// ===================================================
// PROFIT TARGET UPDATER
// ===================================================
void UpdateProfitTargets(int trend)
{
   switch(trend)
   {
      case  1:
      case -1:
         SeqBuyProfitTarget  = 1;
         SeqSellProfitTarget = 1;
         break;

      case  2:
      case -2:
         SeqBuyProfitTarget  = 2;
         SeqSellProfitTarget = 2;
         break;

      case  3:
      case -3:
         SeqBuyProfitTarget  = 3;
         SeqSellProfitTarget = 3;
         break;

      case  4:
      case -4:
         SeqBuyProfitTarget  = 4;
         SeqSellProfitTarget = 4;
         break;

      default:
         SeqBuyProfitTarget  = BuyProfitTargetInput;
         SeqSellProfitTarget = SellProfitTargetInput;
         break;
   }
}

// ===================================================
// TREND STRENGTH FUNCTION
// ===================================================
int GetMarketTrendStrengthClaude1()
{
   if(Bars < 250) return 0;

   // ===================================================
   // HARD BLOCK 1 — TRADING TIME FILTER
   // ===================================================
   int currentHour = TimeHour(TimeCurrent());
   bool goodTradingTime =
      (currentHour >= 9  && currentHour <= 12) ||
      (currentHour >= 14 && currentHour <= 17);
   if(!goodTradingTime) return 0;

   // ===================================================
   // HARD BLOCK 2 — CONSECUTIVE LOSS BLOCK
   // Auto-detected from history via AutoUpdateLossTracker()
   // ===================================================
   if(g_consecutiveLosses >= 2)
   {
      Print("Trading BLOCKED — consecutive losses: ", g_consecutiveLosses);
      return 0;
   }

   // ===================================================
   // EMA VALUES
   // ===================================================
   double ema9_1   = iMA(Symbol(), 0,   9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema9_2   = iMA(Symbol(), 0,   9, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema20_1  = iMA(Symbol(), 0,  20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20_2  = iMA(Symbol(), 0,  20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema50_1  = iMA(Symbol(), 0,  50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema50_2  = iMA(Symbol(), 0,  50, 0, MODE_EMA, PRICE_CLOSE, 2);
   double ema200_1 = iMA(Symbol(), 0, 200, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200_2 = iMA(Symbol(), 0, 200, 0, MODE_EMA, PRICE_CLOSE, 2);

   double price = Close[1];

   // ===================================================
   // HARD BLOCK 3 — SPIKE FILTER
   // ===================================================
   double prevMoveFast = MathAbs(Close[3] - Close[8]) / Point;
   bool afterDownSpike = (prevMoveFast >= 3000 && Close[3] < Close[8]);
   bool afterUpSpike   = (prevMoveFast >= 3000 && Close[3] > Close[8]);

   // ===================================================
   // HARD BLOCK 4 — SIDEWAYS FILTER
   // ===================================================
   double gap9_20 = MathAbs(ema9_1 - ema20_1) / Point;

   double b1 = MathAbs(Close[1] - Open[1]) / Point;
   double b2 = MathAbs(Close[2] - Open[2]) / Point;
   double b3 = MathAbs(Close[3] - Open[3]) / Point;

   double avg1 = (High[1] + Low[1]) / 2.0;
   double avg2 = (High[2] + Low[2]) / 2.0;
   double avg3 = (High[3] + Low[3]) / 2.0;
   double avg4 = (High[4] + Low[4]) / 2.0;
   double avg5 = (High[5] + Low[5]) / 2.0;

   double highestAvg = avg1, lowestAvg = avg1;
   for(int i = 1; i <= 5; i++)
   {
      double avgI = (High[i] + Low[i]) / 2.0;
      if(avgI > highestAvg) highestAvg = avgI;
      if(avgI < lowestAvg)  lowestAvg  = avgI;
   }
   double avgRangePoints = (highestAvg - lowestAvg) / Point;

   bool sideways =
      (gap9_20 < 250) ||
      (avgRangePoints < 800) ||
      ((b1 < 100) && (b2 < 100) && (b3 < 100));
   if(sideways) return 0;

   // ===================================================
   // FIX 1 — EMA CROSSOVER CONFIRMATION
   // ===================================================
   bool recentBullCross = false;
   bool recentBearCross = false;

   for(int x = 1; x <= 10; x++)
   {
      double e9now   = iMA(Symbol(), 0,  9, 0, MODE_EMA, PRICE_CLOSE, x);
      double e20now  = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, x);
      double e9prev  = iMA(Symbol(), 0,  9, 0, MODE_EMA, PRICE_CLOSE, x+1);
      double e20prev = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, x+1);

      if(e9prev <= e20prev && e9now > e20now) recentBullCross = true;
      if(e9prev >= e20prev && e9now < e20now) recentBearCross = true;
   }

   // ===================================================
   // FIX 2 — BOTTOM / TOP FISHING FILTER
   // ===================================================
   double lowestClose  = Close[1];
   double highestClose = Close[1];
   for(int n = 1; n <= 20; n++)
   {
      if(Close[n] < lowestClose)  lowestClose  = Close[n];
      if(Close[n] > highestClose) highestClose = Close[n];
   }

   double recentLow5  = Low[1];
   double recentHigh5 = High[1];
   for(int n2 = 1; n2 <= 5; n2++)
   {
      if(Low[n2]  < recentLow5)  recentLow5  = Low[n2];
      if(High[n2] > recentHigh5) recentHigh5 = High[n2];
   }

   double recoveryFromLow = (Close[1] - lowestClose)  / Point;
   double dropFromHigh    = (highestClose - Close[1]) / Point;

   bool bottomFishing =
      (recoveryFromLow < 2000) &&
      (MathAbs(recentLow5 - lowestClose) / Point < 500);

   bool topFishing =
      (dropFromHigh < 2000) &&
      (MathAbs(recentHigh5 - highestClose) / Point < 500);

   // ===================================================
   // SCORING SYSTEM
   // ===================================================
   int buyScore  = 0;
   int sellScore = 0;

   // --- [3pts] EMA Alignment ---
   bool emaUpStrong =
      (price > ema9_1)  && (ema9_1  > ema20_1) && (ema20_1 > ema50_1) &&
      (ema9_1 > ema9_2) && (ema20_1 >= ema20_2) && (ema50_1 >= ema50_2);

   bool emaDownStrong =
      (price < ema9_1)  && (ema9_1  < ema20_1) && (ema20_1 < ema50_1) &&
      (ema9_1 < ema9_2) && (ema20_1 <= ema20_2) && (ema50_1 <= ema50_2);

   bool emaUpWeak   = (price > ema9_1) && (ema9_1 > ema20_1) && (ema9_1 > ema9_2);
   bool emaDownWeak = (price < ema9_1) && (ema9_1 < ema20_1) && (ema9_1 < ema9_2);

   if(emaUpStrong)      buyScore  += 3;
   else if(emaUpWeak)   buyScore  += 1;
   if(emaDownStrong)    sellScore += 3;
   else if(emaDownWeak) sellScore += 1;

   // --- [2pts] EMA200 Macro ---
   bool macroUp   = (price > ema200_1 && ema200_1 >= ema200_2);
   bool macroDown = (price < ema200_1 && ema200_1 <= ema200_2);

   if(macroUp)   buyScore  += 2;
   if(macroDown) sellScore += 2;

   // --- [2pts] H4 Timeframe Agreement ---
   double htf_ema50  = iMA(Symbol(), PERIOD_H4,  50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double htf_ema200 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);
   double htf_price  = iClose(Symbol(), PERIOD_H4, 1);

   if(htf_price > htf_ema50 && htf_ema50 > htf_ema200) buyScore  += 2;
   if(htf_price < htf_ema50 && htf_ema50 < htf_ema200) sellScore += 2;

   // --- [2pts] ATR Momentum ---
   double atrPoints = iATR(Symbol(), 0, 14, 1) / Point;
   if(atrPoints >= 2000)      { buyScore += 2; sellScore += 2; }
   else if(atrPoints >= 1000) { buyScore += 1; sellScore += 1; }

   // --- [2pts] EMA50 Consistency ---
   int ema50UpCount = 0, ema50DownCount = 0;
   for(int k = 1; k <= 50; k++)
   {
      double eA = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, k);
      double eB = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, k+1);
      if(eA > eB) ema50UpCount++;
      if(eA < eB) ema50DownCount++;
   }
   if(ema50UpCount   >= 35) buyScore  += 2;
   if(ema50DownCount >= 35) sellScore += 2;

   // --- [1-3pts] Swing Distance ---
   double swingLowS = Low[1],  swingHighS = High[1];
   double swingLowM = Low[1],  swingHighM = High[1];
   double swingLowL = Low[1],  swingHighL = High[1];

   for(int j = 1; j <= 200; j++)
   {
      if(j <= 30)
      {
         if(Low[j]  < swingLowS)  swingLowS  = Low[j];
         if(High[j] > swingHighS) swingHighS = High[j];
      }
      if(j <= 100)
      {
         if(Low[j]  < swingLowM)  swingLowM  = Low[j];
         if(High[j] > swingHighM) swingHighM = High[j];
      }
      if(Low[j]  < swingLowL)  swingLowL  = Low[j];
      if(High[j] > swingHighL) swingHighL = High[j];
   }

   double riseSml = (Close[1] - swingLowS)  / Point;
   double fallSml = (swingHighS - Close[1]) / Point;
   double riseMed = (Close[1] - swingLowM)  / Point;
   double fallMed = (swingHighM - Close[1]) / Point;
   double riseLng = (Close[1] - swingLowL)  / Point;
   double fallLng = (swingHighL - Close[1]) / Point;

   if(riseSml >= 3000  && riseSml < 8000)  buyScore  += 1;
   if(fallSml >= 3000  && fallSml < 8000)  sellScore += 1;
   if(riseMed >= 8000  && riseMed < 15000) buyScore  += 2;
   if(fallMed >= 8000  && fallMed < 15000) sellScore += 2;
   if(riseLng >= 15000)                    buyScore  += 3;
   if(fallLng >= 15000)                    sellScore += 3;

   // --- [1pt] Trend Age ---
   int alignedUpBars = 0, alignedDownBars = 0;
   for(int m = 1; m <= 20; m++)
   {
      double e9  = iMA(Symbol(), 0,  9, 0, MODE_EMA, PRICE_CLOSE, m);
      double e20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, m);
      double e50 = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, m);
      if(e9 > e20 && e20 > e50) alignedUpBars++;
      if(e9 < e20 && e20 < e50) alignedDownBars++;
   }
   if(alignedUpBars   >= 10) buyScore  += 1;
   if(alignedDownBars >= 10) sellScore += 1;

   // --- [1pt] Candle Direction ---
   double step1 = (avg1 - avg2) / Point;
   double step2 = (avg2 - avg3) / Point;
   double step3 = (avg3 - avg4) / Point;

   bool avgUp   = (step1 > 0 && step2 > 0) || (step1 > 0 && step2 > 0 && step3 > 0);
   bool avgDown = (step1 < 0 && step2 < 0) || (step1 < 0 && step2 < 0 && step3 < 0);

   if(avgUp)   buyScore  += 1;
   if(avgDown) sellScore += 1;

   // --- [1pt] Higher Low / Lower High ---
   bool higherLow = (Low[1]  > Low[2]  && Low[2]  > Low[3]);
   bool lowerHigh = (High[1] < High[2] && High[2] < High[3]);

   if(higherLow) buyScore  += 1;
   if(lowerHigh) sellScore += 1;

   // --- [1pt] Pullback to EMA9 ---
   if(MathAbs(price - ema9_1) / Point <= 500)
   { buyScore += 1; sellScore += 1; }

   // --- [1pt] Room to Move ---
   double recentHighR = High[1], recentLowR = Low[1];
   for(int r = 1; r <= 20; r++)
   {
      if(High[r] > recentHighR) recentHighR = High[r];
      if(Low[r]  < recentLowR)  recentLowR  = Low[r];
   }
   if((recentHighR - Close[1]) / Point >= 1500) buyScore  += 1;
   if((Close[1]   - recentLowR) / Point >= 1500) sellScore += 1;

   // --- [1pt] Recent EMA Cross ---
   if(recentBullCross) buyScore  += 1;
   if(recentBearCross) sellScore += 1;

   // ===================================================
   // PENALTIES
   // ===================================================
   if(!recentBullCross && buyScore  > sellScore)
      buyScore  = MathMax(0, buyScore  - 4);
   if(!recentBearCross && sellScore > buyScore)
      sellScore = MathMax(0, sellScore - 4);

   if(bottomFishing) buyScore  = MathMax(0, buyScore  - 5);
   if(topFishing)    sellScore = MathMax(0, sellScore - 5);

   if(afterDownSpike) buyScore  = MathMax(0, buyScore  - 6);
   if(afterUpSpike)   sellScore = MathMax(0, sellScore - 6);

   // ===================================================
   // CONFLICT FILTER
   // ===================================================
   if(MathAbs(buyScore - sellScore) < 5) return 0;

   // ===================================================
   // DOMINANT DIRECTION
   // ===================================================
   bool isBuy  = (buyScore  > sellScore);
   bool isSell = (sellScore > buyScore);

   // ===================================================
   // TREND SIZE CLASSIFICATION
   // ===================================================
   bool isSmallTrend  = false;
   bool isMediumTrend = false;
   bool isLongTrend   = false;

   if(isBuy)
   {
      if     (riseLng >= 15000)                   isLongTrend   = true;
      else if(riseMed >= 8000 && riseMed < 15000) isMediumTrend = true;
      else if(riseSml >= 3000 && riseSml < 8000)  isSmallTrend  = true;
   }
   else if(isSell)
   {
      if     (fallLng >= 15000)                   isLongTrend   = true;
      else if(fallMed >= 8000 && fallMed < 15000) isMediumTrend = true;
      else if(fallSml >= 3000 && fallSml < 8000)  isSmallTrend  = true;
   }

   if(!isSmallTrend && !isMediumTrend && !isLongTrend) return 0;

   // ===================================================
   // SIGNAL OUTPUT
   // ===================================================
   if(isBuy)
   {
      if(isSmallTrend)  return 1;
      if(isMediumTrend) return (buyScore >= 14) ?  2 :  1;
      if(isLongTrend)
      {
         if(buyScore >= 18) return  4;
         if(buyScore >= 14) return  3;
         return  2;
      }
   }
   else if(isSell)
   {
      if(isSmallTrend)  return -1;
      if(isMediumTrend) return (sellScore >= 14) ? -2 : -1;
      if(isLongTrend)
      {
         if(sellScore >= 18) return -4;
         if(sellScore >= 14) return -3;
         return -2;
      }
   }

   return 0;
}