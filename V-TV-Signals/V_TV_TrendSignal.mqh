// ===================================================
// GLOBAL VARIABLES — declare at top of EA
// ===================================================
int    g_consecutiveLosses     = 0;
int    g_consecutiveBuyLosses  = 0;
int    g_consecutiveSellLosses = 0;
int    g_lastCheckedTicket     = 0;
double defaultBuyTarget        = 3;
double defaultSellTarget       = 3;

// ===================================================
// AUTO LOSS TRACKER — reads from order history
// Call this in OnTick() BEFORE GetMarketTrendStrengthClaude1()
// ===================================================
void AutoUpdateLossTracker()
{
   int totalHistory = OrdersHistoryTotal();
   if(totalHistory == 0) return;

   int      lastTicket   = 0;
   double   lastProfit   = 0;
   int      lastType     = -1;
   datetime lastCloseTime = 0;

   for(int i = totalHistory - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(OrderType()==OP_BUY  && OrderMagicNumber() != SeqBuyMagicNo)  continue;
      if(OrderType()==OP_SELL && OrderMagicNumber() != SeqSellMagicNo) continue;
      if(OrderSymbol() != Symbol()) continue;

      if(OrderCloseTime() > lastCloseTime)
      {
         lastCloseTime = OrderCloseTime();
         lastTicket    = OrderTicket();
         lastProfit    = OrderProfit() + OrderSwap() + OrderCommission();
         lastType      = OrderType();
      }
   }

   if(lastTicket == 0) return;
   if(lastTicket == g_lastCheckedTicket) return;

   g_lastCheckedTicket = lastTicket;

   if(lastProfit < 0)
   {
      g_consecutiveLosses++;
      if(lastType == OP_BUY)  { g_consecutiveBuyLosses++;  g_consecutiveSellLosses = 0; }
      if(lastType == OP_SELL) { g_consecutiveSellLosses++; g_consecutiveBuyLosses  = 0; }
      Print("Loss detected. Ticket: ", lastTicket,
            " | Type: ", (lastType==OP_BUY?"BUY":"SELL"),
            " | Profit: ", lastProfit,
            " | BuyLosses: ", g_consecutiveBuyLosses,
            " | SellLosses: ", g_consecutiveSellLosses);
   }
   else
   {
      g_consecutiveLosses = 0;
      if(lastType == OP_BUY)  g_consecutiveBuyLosses  = 0;
      if(lastType == OP_SELL) g_consecutiveSellLosses = 0;
      Print("Win detected. Ticket: ", lastTicket,
            " | Type: ", (lastType==OP_BUY?"BUY":"SELL"),
            " | Profit: ", lastProfit,
            " | Loss streaks reset.");
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
         " | Sell TP: $", SeqSellProfitTarget,
         " | BlockReason: ", (g_blockReason != "" ? g_blockReason : "none"));

   if(trend == 4)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders + 2;
      SeqSellMaxOrders = defaultMaxSellOrders;
      if(CountOpenSeqBuyOrders() < SeqBuyMaxOrders) PlaceSeqBuyOrder(-1);
   }
   else if(trend == 3)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders + 1;
      SeqSellMaxOrders = defaultMaxSellOrders;
      if(CountOpenSeqBuyOrders() < SeqBuyMaxOrders) PlaceSeqBuyOrder(-1);
   }
   else if(trend == 2)
   {
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      SeqSellMaxOrders = defaultMaxSellOrders;
      if(CountOpenSeqBuyOrders() < SeqBuyMaxOrders) PlaceSeqBuyOrder(-1);
   }
   else if(trend == 1)
   {
      SeqBuyMaxOrders  = MathMax(1, defaultMaxBuyOrders - 1);
      SeqSellMaxOrders = defaultMaxSellOrders;
      if(CountOpenSeqBuyOrders() < SeqBuyMaxOrders) PlaceSeqBuyOrder(-1);
   }
   else if(trend == -4)
   {
      SeqSellMaxOrders = defaultMaxSellOrders + 2;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      if(CountOpenSeqSellOrders() < SeqSellMaxOrders) PlaceSeqSellOrder(-1);
   }
   else if(trend == -3)
   {
      SeqSellMaxOrders = defaultMaxSellOrders + 1;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      if(CountOpenSeqSellOrders() < SeqSellMaxOrders) PlaceSeqSellOrder(-1);
   }
   else if(trend == -2)
   {
      SeqSellMaxOrders = defaultMaxSellOrders;
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      if(CountOpenSeqSellOrders() < SeqSellMaxOrders) PlaceSeqSellOrder(-1);
   }
   else if(trend == -1)
   {
      SeqSellMaxOrders = MathMax(1, defaultMaxSellOrders - 1);
      SeqBuyMaxOrders  = defaultMaxBuyOrders;
      if(CountOpenSeqSellOrders() < SeqSellMaxOrders) PlaceSeqSellOrder(-1);
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
// MINUTE TREND DETECTOR — last 3 to 10 minutes (M1 bars)
// Returns:  1 = Up trend
//          -1 = Down trend
//           0 = Straight (mixed / no clear direction)
// ===================================================
int GetMinuteTrend(int minMinutes = 3, int maxMinutes = 60, int minAnglePoints = 1000)
{
   double priceNow  = iClose(Symbol(), PERIOD_M1, 1);
   double priceMin  = iClose(Symbol(), PERIOD_M1, minMinutes);
   double priceMax  = iClose(Symbol(), PERIOD_M1, maxMinutes);

   datetime timeNow = iTime(Symbol(), PERIOD_M1, 1);
   datetime timeMax = iTime(Symbol(), PERIOD_M1, maxMinutes);

   double moveShort = (priceNow - priceMin) / Point;
   double moveLong  = (priceNow - priceMax) / Point;

   // Calculate angle in degrees using chart visible scale
   double chartPriceRange = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
   double chartTimeSecs   = (double)ChartGetInteger(0, CHART_VISIBLE_BARS) * PeriodSeconds(PERIOD_CURRENT);
   double timeSecs        = (double)(timeNow - timeMax);

   double normY = (chartPriceRange > 0) ? (moveLong * Point) / chartPriceRange : 0;
   double normX = (chartTimeSecs  > 0) ? timeSecs / chartTimeSecs : 0;
   double angleDeg = 0;
   if(normX > 0) angleDeg = MathArctan(normY / normX) * 180.0 / 3.14159265358979;

   // Direction requires angle above 50° (or below -50°)
   bool hasAngleUp   = (angleDeg >=  50.0);
   bool hasAngleDown = (angleDeg <= -50.0);

   string label = "STRAIGHT";
   int    result = 0;
   color  lineColor = clrGray;

   if(hasAngleUp)
   { label = "UP";   result =  1; lineColor = clrLime; }
   else if(hasAngleDown)
   { label = "DOWN"; result = -1; lineColor = clrRed;  }

   string angleStr = DoubleToString(angleDeg, 1) + "°";

   // Draw trend line from maxMinutes ago → now
   string lineName  = "MinuteTrendLine";
   string angleName = "MinuteTrendAngle";
   ObjectDelete(0, lineName);
   ObjectDelete(0, angleName);

   if(ObjectCreate(0, lineName, OBJ_TREND, 0, timeMax, priceMax, timeNow, priceNow))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,     lineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,     2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,     STYLE_SOLID);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE,false);
      ObjectSetString(0,  lineName, OBJPROP_TOOLTIP,
                      "Minute Trend: " + label +
                      "\nAngle: " + angleStr +
                      "\n" + IntegerToString(maxMinutes) + "m ago: " + DoubleToString(priceMax, 2) +
                      "\nNow: " + DoubleToString(priceNow, 2) +
                      "\nMove: " + DoubleToString(moveLong, 0) + " pts");
   }

   // Angle label at the right end of the line
   if(ObjectCreate(0, angleName, OBJ_TEXT, 0, timeNow, priceNow))
   {
      ObjectSetString(0,  angleName, OBJPROP_TEXT,      label + " " + angleStr);
      ObjectSetInteger(0, angleName, OBJPROP_COLOR,     lineColor);
      ObjectSetInteger(0, angleName, OBJPROP_FONTSIZE,  9);
      ObjectSetString(0,  angleName, OBJPROP_FONT,      "Arial Bold");
      ObjectSetInteger(0, angleName, OBJPROP_ANCHOR,    ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, angleName, OBJPROP_SELECTABLE,false);
   }
   ChartRedraw(0);

   Print("Minute Trend (", minMinutes, "-", maxMinutes, "min): ", label,
         " | Angle=", angleStr,
         " | Now=", DoubleToString(priceNow, 2),
         " | ", maxMinutes, "m ago=", DoubleToString(priceMax, 2),
         " | Move=", DoubleToString(moveLong, 0), "pts");

         g_blockReason = "Minute Trend: "+ label+
         " | Angle="+ angleStr+     
            " | Now="+ DoubleToString(priceNow, 2)+
            " | "+ maxMinutes+"m ago="+ DoubleToString(priceMax, 2)+
            " | Move="+ DoubleToString(moveLong, 0)+"pts";

   return result;
}

// ===================================================
// M15 TREND DIRECTION DETECTOR
// Returns:  1 = Up trend
//          -1 = Down trend
//           0 = Straight (sideways)
// ===================================================
int GetM15TrendDirection()
{
   // Use M15 close prices directly — 4 consecutive closes must confirm direction
   double p1 = iClose(Symbol(), PERIOD_M15, 1);
   double p2 = iClose(Symbol(), PERIOD_M15, 2);
   double p3 = iClose(Symbol(), PERIOD_M15, 3);
   double p4 = iClose(Symbol(), PERIOD_M15, 4);

   // Total price move must exceed minimum to avoid flat/sideways
   double totalMovePoints = MathAbs(p1 - p4) / Point;
   bool hasMove = (totalMovePoints >= 500);

   bool upTrend   = hasMove && (p1 > p2) && (p2 > p3) && (p3 > p4);
   bool downTrend = hasMove && (p1 < p2) && (p2 < p3) && (p3 < p4);

   string label = upTrend ? "UP" : (downTrend ? "DOWN" : "STRAIGHT");
   Print("M15 Trend: ", label,
         " | p1=", DoubleToString(p1, 2),
         " | p4=", DoubleToString(p4, 2),
         " | Move pts=", DoubleToString(totalMovePoints, 0));


g_blockReason ="M15 Trend: "+ label+
         " | p1="+ DoubleToString(p1, 2)+
         " | p4="+ DoubleToString(p4, 2)+
         " | Move pts="+  DoubleToString(totalMovePoints, 0);
   if(upTrend)   return  1;
   if(downTrend) return -1;
   return 0;
}

// ===================================================
// TREND STRENGTH FUNCTION — M10 trend direction
// ===================================================
int GetMarketTrendStrengthClaude1()
{
   if(Bars < 50) return 0;

   // M10 EMA20: need 3 consecutive bars confirming direction
   double m10_ema1 = iMA(Symbol(), PERIOD_M10, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double m10_ema2 = iMA(Symbol(), PERIOD_M10, 20, 0, MODE_EMA, PRICE_CLOSE, 2);
   double m10_ema3 = iMA(Symbol(), PERIOD_M10, 20, 0, MODE_EMA, PRICE_CLOSE, 3);
   double m10_price = iClose(Symbol(), PERIOD_M10, 1);

   bool m10Up   = (m10_ema1 > m10_ema2 && m10_ema2 > m10_ema3 && m10_price > m10_ema1);
   bool m10Down = (m10_ema1 < m10_ema2 && m10_ema2 < m10_ema3 && m10_price < m10_ema1);

   Print("M10 Trend | EMA: ", DoubleToString(m10_ema1,2),
         " Price: ", DoubleToString(m10_price,2),
         " Up=", m10Up, " Down=", m10Down);

   if(m10Up)   return 1;
   if(m10Down) return -1;
   return 0;
}