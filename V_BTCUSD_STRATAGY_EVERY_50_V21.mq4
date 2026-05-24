//+------------------------------------------------------------------+
//| BTCUSD Professional Gap Recovery EA                             |
//| Version: V21                                                     |
//| Logic: M30 Trend Filter + Trend Change Basket Exit + Dashboard   |
//| Added: configurable pause after any order close                  |
//+------------------------------------------------------------------+
#property strict

extern double BaseLot             = 0.01;
extern double GapPrice            = 50.0;

extern int    MaxBuyOrders        = 4;
extern int    MaxSellOrders       = 4;

extern bool   EnableIndividualTP  = true;
extern double IndividualTP        = 1.00;

extern bool   EnableBasketTP      = true;
extern double FastProfitTarget    = 1.00;
extern double SlowProfitTarget    = 0.50;
extern int    FastProfitMinutes   = 30;

extern bool   EnableBasketSL      = true;
extern double BasketStopLoss      = -20.0;

extern bool   EnableRecovery      = true;
extern double RecoveryGap1        = 200.0;
extern double RecoveryGap2        = 1000.0;
extern double RecoveryGap3        = 1500.0;

extern double RecoveryLot1        = 0.02;
extern double RecoveryLot2        = 0.03;
extern double RecoveryLot3        = 0.01;

extern int    MaxSpreadPoints     = 3000;
extern int    Slippage            = 5;
extern int    MagicNumber         = 505021;

extern bool   EnableBuy           = true;
extern bool   EnableSell          = true;

extern bool   OneOrderPerCandle   = true;
extern int    TradeTimeframe      = PERIOD_M1;

extern bool   EnableM30TrendFilter    = true;
extern int    TrendTimeframe          = PERIOD_M15;
extern int    TrendFastEMA            = 9;
extern int    TrendSlowEMA            = 21;
extern bool   AllowTradeWhenTrendFlat = false;
extern bool   EnableCloseBasketOnTrendChange = true;
extern bool   CloseSingleOrderOnTrendChange  = false;

extern bool   EnablePauseAfterClose = true;
extern int    PauseMinutesAfterClose = 0;

extern bool   ShowDashboard       = true;
extern int    DashX               = 250;
extern int    DashY               = 20;
extern int    DashWidth           = 200;
extern int    DashHeight          = 530;

datetime lastBuyCandleTime  = 0;
datetime lastSellCandleTime = 0;
datetime lastCloseTime      = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   UpdateLastCloseTime();
   Print("BTCUSD Professional Gap Recovery EA Started - Version V21");
   
   DefaultTP=IndividualTP;
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDashboard();
   
    
}

//+------------------------------------------------------------------+

double DefaultTP=0;
void OnTick()
{
   RefreshRates();
   
   
   
   if(GetM30TrendText()=="FLAT - BLOCK")
   {
   
   IndividualTP=0;
   
   }
   else
   {
   IndividualTP=DefaultTP;
   }
   
   

   UpdateLastCloseTime();
   
   if(ShowDashboard)
      DrawDashboard();

   if(!IsSpreadOK())
      return;

   if(EnableIndividualTP)
      CheckIndividualProfitClose();

   if(EnableBasketTP || EnableBasketSL)
      CheckBasketClose();

   if(EnableCloseBasketOnTrendChange)
      CheckTrendChangeBasketClose();

   // Pause only blocks new orders, not closing/protection logic
   if(EnablePauseAfterClose && IsPauseActive())
      return;

   if(EnableBuy)
      ProcessBuyOrders();

   if(EnableSell)
      ProcessSellOrders();

   if(EnableRecovery)
      ProcessRecoveryOrders();
}

//+------------------------------------------------------------------+
//| BUY every 50 price up                                            |
//+------------------------------------------------------------------+
void ProcessBuyOrders()
{
   if(CountOrders(OP_BUY) >= MaxBuyOrders)
      return;
      
      
      if(!CanOpenByM30Trend(OP_BUY))
      return;

   if(OneOrderPerCandle && !CanTradeThisCandle(OP_BUY))
      return;

   double lastBuyPrice = GetLastOrderPrice(OP_BUY);

   if(lastBuyPrice == 0)
   {
      if(OpenOrder(OP_BUY, BaseLot, "V21_BASE_BUY"))
         UpdateCandleTradeTime(OP_BUY);
      return;
   }

   if(Ask >= lastBuyPrice + GapPrice)
   {
      if(OpenOrder(OP_BUY, BaseLot, "V21_GAP_BUY"))
         UpdateCandleTradeTime(OP_BUY);
   }
}

//+------------------------------------------------------------------+
//| SELL every 50 price down                                         |
//+------------------------------------------------------------------+
void ProcessSellOrders()
{
   if(CountOrders(OP_SELL) >= MaxSellOrders)
      return;

   if(OneOrderPerCandle && !CanTradeThisCandle(OP_SELL))
      return;
      
       if(!CanOpenByM30Trend(OP_SELL))
      return;

   double lastSellPrice = GetLastOrderPrice(OP_SELL);

   if(lastSellPrice == 0)
   {
      if(OpenOrder(OP_SELL, BaseLot, "V21_BASE_SELL"))
         UpdateCandleTradeTime(OP_SELL);
      return;
   }

   if(Bid <= lastSellPrice - GapPrice)
   {
      if(OpenOrder(OP_SELL, BaseLot, "V21_GAP_SELL"))
         UpdateCandleTradeTime(OP_SELL);
   }
}

//+------------------------------------------------------------------+
//| Recovery Orders                                                  |
//+------------------------------------------------------------------+
void ProcessRecoveryOrders()
{
   if(CountOrders(OP_BUY) < MaxBuyOrders)
      ProcessBuyRecovery();

   if(CountOrders(OP_SELL) < MaxSellOrders)
      ProcessSellRecovery();
}

//+------------------------------------------------------------------+
void ProcessBuyRecovery()
{
   if(CountOrders(OP_BUY) >= MaxBuyOrders)
      return;

  // if(!CanOpenByM30Trend(OP_BUY))
   //   return;

   double firstBuyPrice = GetFirstOrderPrice(OP_BUY);
   if(firstBuyPrice == 0)
      return;

   double gap = firstBuyPrice - Bid;

   if(gap >= RecoveryGap1 && !RecoveryExists("V21_BUY_REC_100"))
   {
      OpenOrder(OP_BUY, RecoveryLot1, "V21_BUY_REC_100");
      return;
   }

   if(gap >= RecoveryGap2 && !RecoveryExists("V21_BUY_REC_300"))
   {
      OpenOrder(OP_BUY, RecoveryLot2, "V21_BUY_REC_300");
      return;
   }

   if(gap >= RecoveryGap3 && !RecoveryExists("V21_BUY_REC_500"))
   {
      OpenOrder(OP_BUY, RecoveryLot3, "V21_BUY_REC_500");
      return;
   }
}

//+------------------------------------------------------------------+
void ProcessSellRecovery()
{
   if(CountOrders(OP_SELL) >= MaxSellOrders)
      return;

  // if(!CanOpenByM30Trend(OP_SELL))
    //  return;

   double firstSellPrice = GetFirstOrderPrice(OP_SELL);
   if(firstSellPrice == 0)
      return;

   double gap = Ask - firstSellPrice;

   if(gap >= RecoveryGap1 && !RecoveryExists("V21_SELL_REC_100"))
   {
      OpenOrder(OP_SELL, RecoveryLot1, "V21_SELL_REC_100");
      return;
   }

   if(gap >= RecoveryGap2 && !RecoveryExists("V21_SELL_REC_300"))
   {
      OpenOrder(OP_SELL, RecoveryLot2, "V21_SELL_REC_300");
      return;
   }

   if(gap >= RecoveryGap3 && !RecoveryExists("V21_SELL_REC_500"))
   {
      OpenOrder(OP_SELL, RecoveryLot3, "V21_SELL_REC_500");
      return;
   }
}

//+------------------------------------------------------------------+
//| Individual TP only when same side count is 1                     |
//+------------------------------------------------------------------+
void CheckIndividualProfitClose()
{
   RefreshRates();

   int buyCount  = CountOrders(OP_BUY);
   int sellCount = CountOrders(OP_SELL);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(OrderType() == OP_BUY && buyCount == 1 && profit >= IndividualTP)
      {
         bool closedBuy = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

         if(closedBuy)
         {
            lastCloseTime = TimeCurrent();
            Print("V21 Individual BUY TP Closed. Profit: $", DoubleToString(profit, 2));
         }
         else
            Print("V21 Individual BUY TP Close Failed. Error: ", GetLastError());
      }

      if(OrderType() == OP_SELL && sellCount == 1 && profit >= IndividualTP)
      {
         bool closedSell = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

         if(closedSell)
         {
            lastCloseTime = TimeCurrent();
            Print("V21 Individual SELL TP Closed. Profit: $", DoubleToString(profit, 2));
         }
         else
            Print("V21 Individual SELL TP Close Failed. Error: ", GetLastError());
      }
   }
}

//+------------------------------------------------------------------+
//| Separate BUY / SELL Basket TP and SL                             |
//+------------------------------------------------------------------+
void CheckBasketClose()
{
   CheckSideBasketClose(OP_BUY);
   CheckSideBasketClose(OP_SELL);
}

//+------------------------------------------------------------------+
void CheckSideBasketClose(int type)
{
   int orderCount = CountOrders(type);

   if(orderCount <= 1)
      return;

   double sideProfit = GetSideBasketProfit(type);
   string sideName   = type == OP_BUY ? "BUY" : "SELL";

   if(EnableBasketSL && sideProfit <= BasketStopLoss)
   {
      CloseOrdersByType(type);
      lastCloseTime = TimeCurrent();
      Print("V21 ", sideName, " Basket SL Hit: $", DoubleToString(sideProfit, 2));
      return;
   }

   if(!EnableBasketTP)
      return;

   int basketMinutes = GetSideBasketAgeMinutes(type);

   double targetProfit = SlowProfitTarget;

   if(basketMinutes < FastProfitMinutes)
      targetProfit = FastProfitTarget;

   if(sideProfit >= targetProfit)
   {
      CloseOrdersByType(type);
      lastCloseTime = TimeCurrent();
      Print("V21 ", sideName, " Basket TP Closed: $", DoubleToString(sideProfit, 2),
            " Minutes: ", basketMinutes,
            " Target: $", DoubleToString(targetProfit, 2));
   }
}


//+------------------------------------------------------------------+
//| Close basket/orders when M30 trend changes against open side     |
//| M30 DOWN -> close BUY basket                                     |
//| M30 UP   -> close SELL basket                                    |
//+------------------------------------------------------------------+
void CheckTrendChangeBasketClose()
{
   if(!EnableM30TrendFilter)
      return;

   int trend = GetM30TrendDirection();

   // trend  1 = M30 uptrend
   // trend -1 = M30 downtrend
   // trend  0 = flat/no clean trend
   if(trend == 0)
      return;

   int buyCount  = CountOrders(OP_BUY);
   int sellCount = CountOrders(OP_SELL);

   if(trend == -1 && buyCount > 0)
   {
      if(buyCount > 1 || CloseSingleOrderOnTrendChange)
      {
         double buyProfit = GetSideBasketProfit(OP_BUY);

         CloseOrdersByType(OP_BUY);
         lastCloseTime = TimeCurrent();

         Print("V21 BUY Basket Closed By M30 Trend Change. Trend=DOWN, P/L=$",
               DoubleToString(buyProfit, 2));
      }
   }

   if(trend == 1 && sellCount > 0)
   {
      if(sellCount > 1 || CloseSingleOrderOnTrendChange)
      {
         double sellProfit = GetSideBasketProfit(OP_SELL);

         CloseOrdersByType(OP_SELL);
         lastCloseTime = TimeCurrent();

         Print("V21 SELL Basket Closed By M30 Trend Change. Trend=UP, P/L=$",
               DoubleToString(sellProfit, 2));
      }
   }
}

//+------------------------------------------------------------------+
double GetSideBasketProfit(int type)
{
   double totalProfit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return totalProfit;
}

//+------------------------------------------------------------------+
int GetSideBasketAgeMinutes(int type)
{
   datetime firstTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         if(firstTime == 0 || OrderOpenTime() < firstTime)
            firstTime = OrderOpenTime();
      }
   }

   if(firstTime == 0)
      return 0;

   return (int)((TimeCurrent() - firstTime) / 60);
}

//+------------------------------------------------------------------+
void CloseOrdersByType(int type)
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != type)
         continue;

      bool closed = false;

      if(type == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

      if(type == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(!closed)
         Print("V21 Side Basket Close Failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   if(type == OP_BUY && CountOrders(OP_BUY) >= MaxBuyOrders)
      return false;

   if(type == OP_SELL && CountOrders(OP_SELL) >= MaxSellOrders)
      return false;

   if(!IsTradeAllowed())
   {
      Print("V21 Trade not allowed. Enable AutoTrading.");
      return false;
   }

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(
      Symbol(),
      type,
      lot,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      clr
   );

   if(ticket < 0)
   {
      Print("V21 OrderSend Failed. Error: ", GetLastError(),
            " Comment: ", comment,
            " Lot: ", DoubleToString(lot, 2));
      return false;
   }

   Print("V21 Order Opened. Ticket: ", ticket,
         " Comment: ", comment,
         " Price: ", DoubleToString(price, Digits),
         " Lot: ", DoubleToString(lot, 2));

   return true;
}

//+------------------------------------------------------------------+
double GetLastOrderPrice(int type)
{
   double lastPrice = 0;
   datetime lastTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         if(OrderOpenTime() > lastTime)
         {
            lastTime = OrderOpenTime();
            lastPrice = OrderOpenPrice();
         }
      }
   }

   return lastPrice;
}

//+------------------------------------------------------------------+
double GetFirstOrderPrice(int type)
{
   double firstPrice = 0;
   datetime firstTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         if(firstTime == 0 || OrderOpenTime() < firstTime)
         {
            firstTime = OrderOpenTime();
            firstPrice = OrderOpenPrice();
         }
      }
   }

   return firstPrice;
}

//+------------------------------------------------------------------+
double GetAverageOrderPrice(int type)
{
   double lotSum = 0;
   double weightedPrice = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         lotSum += OrderLots();
         weightedPrice += OrderOpenPrice() * OrderLots();
      }
   }

   if(lotSum <= 0)
      return 0;

   return weightedPrice / lotSum;
}

//+------------------------------------------------------------------+
int CountOrders(int type)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
bool RecoveryExists(string comment)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderComment() == comment)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| M30 Trend Filter                                                 |
//| Return: 1 = Uptrend, -1 = Downtrend, 0 = Flat / no clean trend    |
//+------------------------------------------------------------------+
int GetM30TrendDirection()
{
   double emaFast = iMA(Symbol(), TrendTimeframe, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), TrendTimeframe, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1  = iClose(Symbol(), TrendTimeframe, 1);

   if(close1 > emaFast && emaFast > emaSlow)
      return 1;

   if(close1 < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool CanOpenByM30Trend(int type)
{
   if(!EnableM30TrendFilter)
      return true;

   int trend = GetM30TrendDirection();

   if(trend == 0 && AllowTradeWhenTrendFlat)
      return true;

   if(type == OP_BUY && trend == 1)
      return true;

   if(type == OP_SELL && trend == -1)
      return true;

   return false;
}

//+------------------------------------------------------------------+
string GetM30TrendText()
{
   if(!EnableM30TrendFilter)
      return "OFF";

   int trend = GetM30TrendDirection();

   if(trend == 1)
      return "UP - BUY ONLY";

   if(trend == -1)
      return "DOWN - SELL ONLY";

   return "FLAT - BLOCK";
}

//+------------------------------------------------------------------+
color GetM30TrendColor()
{
   if(!EnableM30TrendFilter)
      return clrGray;

   int trend = GetM30TrendDirection();

   if(trend == 1)
      return clrDeepSkyBlue;

   if(trend == -1)
      return clrOrange;

   return clrTomato;
}

//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   int spread = MarketInfo(Symbol(), MODE_SPREAD);

   if(spread > MaxSpreadPoints)
   {
      Print("V21 Spread Too High: ", spread);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
bool CanTradeThisCandle(int type)
{
   datetime candleTime = iTime(Symbol(), TradeTimeframe, 0);

   if(type == OP_BUY && candleTime == lastBuyCandleTime)
      return false;

   if(type == OP_SELL && candleTime == lastSellCandleTime)
      return false;

   return true;
}

//+------------------------------------------------------------------+
void UpdateCandleTradeTime(int type)
{
   datetime candleTime = iTime(Symbol(), TradeTimeframe, 0);

   if(type == OP_BUY)
      lastBuyCandleTime = candleTime;

   if(type == OP_SELL)
      lastSellCandleTime = candleTime;
}

//+------------------------------------------------------------------+
//| Pause after close                                                |
//+------------------------------------------------------------------+
void UpdateLastCloseTime()
{
   datetime latestClose = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
      {
         if(OrderCloseTime() > latestClose)
            latestClose = OrderCloseTime();
      }
   }

   if(latestClose > lastCloseTime)
      lastCloseTime = latestClose;
}

//+------------------------------------------------------------------+
bool IsPauseActive()
{
   if(!EnablePauseAfterClose)
      return false;

   if(lastCloseTime <= 0)
      return false;

   int pauseSeconds = PauseMinutesAfterClose * 60;
   int passed       = (int)(TimeCurrent() - lastCloseTime);

   if(passed < pauseSeconds)
      return true;

   return false;
}

//+------------------------------------------------------------------+
int GetPauseRemainingSeconds()
{
   if(!EnablePauseAfterClose || lastCloseTime <= 0)
      return 0;

   int pauseSeconds = PauseMinutesAfterClose * 60;
   int passed       = (int)(TimeCurrent() - lastCloseTime);

   if(passed >= pauseSeconds)
      return 0;

   return pauseSeconds - passed;
}

//+------------------------------------------------------------------+
//| Professional Right Side Dashboard                                |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   int buyCount       = CountOrders(OP_BUY);
   int sellCount      = CountOrders(OP_SELL);

   double buyProfit   = GetSideBasketProfit(OP_BUY);
   double sellProfit  = GetSideBasketProfit(OP_SELL);
   double totalProfit = buyProfit + sellProfit;

   int buyAge         = GetSideBasketAgeMinutes(OP_BUY);
   int sellAge        = GetSideBasketAgeMinutes(OP_SELL);

   double buyAvg      = GetAverageOrderPrice(OP_BUY);
   double sellAvg     = GetAverageOrderPrice(OP_SELL);

   int spread         = MarketInfo(Symbol(), MODE_SPREAD);
   int pauseRemain    = GetPauseRemainingSeconds();

   DrawPanel("V21_DASH_BG", DashX, DashY, DashWidth, DashHeight, clrBlack);

   int y = DashY + 12;

   DrawDashLabel("V21_TITLE", "BTCUSD PROFESSIONAL EA", DashX + 15, y, clrGold, 10);
   y += 22;

   DrawDashLabel("V21_VERSION", "VERSION: V21 | MAGIC: " + IntegerToString(MagicNumber), DashX + 15, y, clrAqua, 8);
   y += 22;

   DrawDashLabel("V21_LINE1", "--------------------------------------", DashX + 15, y, clrDimGray, 8);
   y += 18;

   DrawDashLabel("V21_SYMBOL", "Symbol: " + Symbol(), DashX + 15, y, clrWhite, 9);
   y += 18;

   DrawDashLabel("V21_PRICE", "Bid: " + DoubleToString(Bid, Digits) + " | Ask: " + DoubleToString(Ask, Digits), DashX + 15, y, clrWhite, 8);
   y += 18;

   DrawDashLabel("V21_SPREAD", "Spread: " + IntegerToString(spread) + " / " + IntegerToString(MaxSpreadPoints), DashX + 15, y, spread <= MaxSpreadPoints ? clrLime : clrRed, 9);
   y += 18;

   DrawDashLabel("V21_M30_TREND", "M30 Trend: " + GetM30TrendText(), DashX + 15, y, GetM30TrendColor(), 8);
   y += 18;

   DrawDashLabel("V21_TREND_EXIT", "Trend Exit: " + (EnableCloseBasketOnTrendChange ? "ON" : "OFF"), DashX + 15, y, EnableCloseBasketOnTrendChange ? clrLime : clrGray, 8);
   y += 18;

   DrawDashLabel("V21_PAUSE", "Pause After Close: " + IntegerToString(pauseRemain) + " sec", DashX + 15, y, pauseRemain > 0 ? clrOrange : clrLime, 8);
   y += 22;

   DrawDashLabel("V21_LINE2", "--------------------------------------", DashX + 15, y, clrDimGray, 8);
   y += 18;

   DrawDashLabel("V21_BUY_HEAD", "BUY BASKET", DashX + 15, y, clrDeepSkyBlue, 9);
   y += 18;

   DrawDashLabel("V21_BUY_COUNT", "Orders: " + IntegerToString(buyCount) + " / " + IntegerToString(MaxBuyOrders), DashX + 15, y, clrWhite, 9);
   y += 18;

   DrawDashLabel("V21_BUY_PROFIT", "P/L: $" + DoubleToString(buyProfit, 2), DashX + 15, y, buyProfit >= 0 ? clrLime : clrTomato, 9);
   y += 18;

   DrawDashLabel("V21_BUY_AVG", "Avg Price: " + DoubleToString(buyAvg, Digits), DashX + 15, y, clrWhite, 8);
   y += 18;

   DrawDashLabel("V21_BUY_AGE", "Age: " + IntegerToString(buyAge) + " min", DashX + 15, y, clrWhite, 8);
   y += 22;

   DrawDashLabel("V21_SELL_HEAD", "SELL BASKET", DashX + 15, y, clrOrange, 9);
   y += 18;

   DrawDashLabel("V21_SELL_COUNT", "Orders: " + IntegerToString(sellCount) + " / " + IntegerToString(MaxSellOrders), DashX + 15, y, clrWhite, 9);
   y += 18;

   DrawDashLabel("V21_SELL_PROFIT", "P/L: $" + DoubleToString(sellProfit, 2), DashX + 15, y, sellProfit >= 0 ? clrLime : clrTomato, 9);
   y += 18;

   DrawDashLabel("V21_SELL_AVG", "Avg Price: " + DoubleToString(sellAvg, Digits), DashX + 15, y, clrWhite, 8);
   y += 18;

   DrawDashLabel("V21_SELL_AGE", "Age: " + IntegerToString(sellAge) + " min", DashX + 15, y, clrWhite, 8);
   y += 22;

   DrawDashLabel("V21_LINE3", "--------------------------------------", DashX + 15, y, clrDimGray, 8);
   y += 18;

   DrawDashLabel("V21_TOTAL_PROFIT", "Total Floating P/L: $" + DoubleToString(totalProfit, 2), DashX + 15, y, totalProfit >= 0 ? clrLime : clrRed, 10);
   y += 22;

   DrawDashLabel("V21_INDIV_TP", "Individual TP: $" + DoubleToString(IndividualTP, 2), DashX + 15, y, EnableIndividualTP ? clrLime : clrGray, 8);
   y += 18;

   DrawDashLabel("V21_FAST_TP", "Basket TP < " + IntegerToString(FastProfitMinutes) + " min: $" + DoubleToString(FastProfitTarget, 2), DashX + 15, y, EnableBasketTP ? clrLime : clrGray, 8);
   y += 18;

   DrawDashLabel("V21_SLOW_TP", "Basket TP >= " + IntegerToString(FastProfitMinutes) + " min: $" + DoubleToString(SlowProfitTarget, 2), DashX + 15, y, EnableBasketTP ? clrLime : clrGray, 8);
   y += 18;

   DrawDashLabel("V21_BASKET_SL", "Separate Basket SL: $" + DoubleToString(BasketStopLoss, 2), DashX + 15, y, EnableBasketSL ? clrTomato : clrGray, 8);
   y += 22;

   string status = pauseRemain > 0 ? "PAUSED AFTER CLOSE" : "RUNNING";
   color statusColor = pauseRemain > 0 ? clrOrange : clrAqua;

   DrawDashLabel("V21_STATUS", "Status: " + status, DashX + 15, y, statusColor, 9);
}

//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bg)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
}

//+------------------------------------------------------------------+
void DrawDashLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
void DeleteDashboard()
{
   string prefix = "V21_";

   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);

      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}
//+------------------------------------------------------------------+
