#property strict

double Lots                 = 0.01;
double AddStepUSD           = 1.00;
double ReverseStepUSD       = 2.00;
double BasketTPUSD          = 0.50;
double BasketSLUSD          = 10.00;
double MinSameTrendPriceGap = 20.0;

int    MaxOrdersPerSide     = 20;
int    MagicNumber          = 20260603;
int    Slippage             = 30;
int    StartHour            = 0;
int    EndHour              = 10;
int    StopLossPauseMinutes = 0;
int    MaxTotalOpenOrders   = 500;

// M30 trend filter
bool   UseM30TrendFilter    = true;
int    M30TrendFastEMA      = 9;
int    M30TrendSlowEMA      = 21;
bool   UseClosedM30Candle   = true;   // true = use closed M30 candle, safer than current candle

// Recovery order settings
bool   UseRecoveryOrders       = true;
double RecoveryLossUSD         = 1.00;   // create recovery when latest/current order loss reaches this amount
double RecoveryPriceGap        = 20.0;   // raw price gap against latest/current order
int    MaxRecoveryOrdersPerSide = 20;

bool   UseLockedPriceBreakOrder = true;
bool   UseDailyProfitLimit  = true;
double DailyProfitMultiplier = 2.0; // Daily equity target = opening balance * 2
bool   CloseOrdersOnDailyProfitLimit = true;

// 1 = BUY, -1 = SELL
int ActiveDirection = 1;

double BuyLastAddLevel  = 0;
double SellLastAddLevel = 0;
double LastReverseLevel = 0;

datetime BuyPauseUntil  = 0;
datetime SellPauseUntil = 0;

double   DailyStartBalance = 0;
int      DailyStartDay     = -1;
bool     DailyProfitLimitReached = false;

//+------------------------------------------------------------------+
int OnInit()
{
   InitDailyProfitLimit();
   DrawDashboard();
   Print("Separate BUY SELL Basket Bot Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteDashboard();
}

//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyProfitLimitIfNewDay();
   DrawDashboard();

   if(CheckDailyProfitLimit())
   {
      DrawDashboard();
      return;
   }

   if(!IsTradingHour())
      return;

   if(CountMyOrders() == 0)
   {
      int m30Trend = GetM30TrendDirection();

      if(UseM30TrendFilter)
      {
         if(m30Trend == 0)
         {
            Print("First order blocked. M30 trend is neutral.");
            return;
         }

         ActiveDirection = m30Trend;
      }

      OpenOrderByDirection(ActiveDirection);
      ResetAddLevels();
      LastReverseLevel = 0;
      return;
   }

   ManageRecoveryOrders();
   ManageLockedPriceBreakOrder();
   ManageOldestOrderReverseEveryMinusOne();
   ManageBuyBasket();
   ManageSellBasket();
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{

    return true;
   int h = TimeHour(TimeCurrent());
   return (h >= StartHour && h <= EndHour);
}

//+------------------------------------------------------------------+
bool IsDirectionPaused(int type)
{
   if(type == OP_BUY && TimeCurrent() < BuyPauseUntil)
      return true;

   if(type == OP_SELL && TimeCurrent() < SellPauseUntil)
      return true;

   return false;
}


//+------------------------------------------------------------------+
void InitDailyProfitLimit()
{
   DailyStartBalance = AccountBalance();
   DailyStartDay = TimeDayOfYear(TimeCurrent());
   DailyProfitLimitReached = false;

   Print("Daily profit tracking started. Opening balance=",
         DoubleToString(DailyStartBalance, 2),
         " Daily equity target=",
         DoubleToString(GetDailyProfitTargetAmount(), 2));
}

//+------------------------------------------------------------------+
void ResetDailyProfitLimitIfNewDay()
{
   int today = TimeDayOfYear(TimeCurrent());

   if(today != DailyStartDay)
   {
      DailyStartBalance = AccountBalance();
      DailyStartDay = today;
      DailyProfitLimitReached = false;

      BuyPauseUntil = 0;
      SellPauseUntil = 0;
      ResetAddLevels();
      LastReverseLevel = 0;

      Print("New day reset. Opening balance=",
            DoubleToString(DailyStartBalance, 2),
            " Daily equity target=",
            DoubleToString(GetDailyProfitTargetAmount(), 2));
   }
}

//+------------------------------------------------------------------+
double GetDailyProfitTargetAmount()
{
   return DailyStartBalance * DailyProfitMultiplier;
}

//+------------------------------------------------------------------+
double GetTodayProfitFromOpeningBalance()
{
   return AccountEquity() - DailyStartBalance;
}

//+------------------------------------------------------------------+
bool CheckDailyProfitLimit()
{
   if(!UseDailyProfitLimit)
      return false;

   if(DailyProfitLimitReached)
      return true;

   double currentEquity = AccountEquity();
   double targetEquity  = GetDailyProfitTargetAmount();
   double todayProfit   = GetTodayProfitFromOpeningBalance();

   // Stop trading when equity reaches daily equity target.
   // Example: Opening balance 100 and multiplier 2.0 => stop when equity >= 200.
   if(currentEquity >= targetEquity)
   {
      DailyProfitLimitReached = true;

      Print("DAILY EQUITY PROFIT LIMIT REACHED. OpeningBalance=",
            DoubleToString(DailyStartBalance, 2),
            " CurrentEquity=",
            DoubleToString(currentEquity, 2),
            " ProfitFromOpeningBalance=",
            DoubleToString(todayProfit, 2),
            " TargetEquity=",
            DoubleToString(targetEquity, 2),
            ". Trading stopped for today.");

      if(CloseOrdersOnDailyProfitLimit)
         CloseAllMyOrders();

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
void CloseAllMyOrders()
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      bool closed = false;

      if(OrderType() == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

      if(OrderType() == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(!closed)
         Print("Daily limit close failed. Ticket=", OrderTicket(), " Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
void ManageLockedPriceBreakOrder()
{
   if(!UseLockedPriceBreakOrder)
      return;

   if(CountOrdersByType(OP_BUY) <= 0 || CountOrdersByType(OP_SELL) <= 0)
      return;

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   double nearestBuyPrice  = GetNearestOrderPrice(OP_BUY);
   double nearestSellPrice = GetNearestOrderPrice(OP_SELL);

   if(nearestBuyPrice <= 0 || nearestSellPrice <= 0)
      return;

   RefreshRates();

   double livePrice = Bid;

   double highPrice = MathMax(nearestBuyPrice, nearestSellPrice);
   double lowPrice  = MathMin(nearestBuyPrice, nearestSellPrice);

   if(livePrice <= lowPrice || livePrice >= highPrice)
      return;

   double buyDistance  = MathAbs(livePrice - nearestBuyPrice);
   double sellDistance = MathAbs(livePrice - nearestSellPrice);

   if(buyDistance < sellDistance && buyDistance >= MinSameTrendPriceGap*CountOrdersByType(OP_BUY))
   {
      ActiveDirection = 1;

      if(CountMyOrders() < MaxTotalOpenOrders)
         OpenOrder(OP_BUY);

      return;
   }

   if(sellDistance < buyDistance && sellDistance >= MinSameTrendPriceGap*CountOrdersByType(OP_SELL))
   {
      ActiveDirection = -1;

      if(CountMyOrders() < MaxTotalOpenOrders)
         OpenOrder(OP_SELL);

      return;
   }
}

//+------------------------------------------------------------------+
double GetNearestOrderPrice(int type)
{
   RefreshRates();

   double livePrice = Bid;
   double nearestPrice = 0;
   double nearestDistance = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != type)
         continue;

      double dist = MathAbs(livePrice - OrderOpenPrice());

      if(nearestPrice == 0 || dist < nearestDistance)
      {
         nearestPrice = OrderOpenPrice();
         nearestDistance = dist;
      }
   }

   return nearestPrice;
}

//+------------------------------------------------------------------+
void ManageOldestOrderReverseEveryMinusOne()
{
   int ticket = GetOldestOrderTicket();

   if(ticket <= 0)
      return;

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   int type = OrderType();

   if(profit <= -(LastReverseLevel + ReverseStepUSD))
   {
      if(type == OP_BUY)
      {
         ActiveDirection = -1;
         OpenOrder(OP_SELL);
      }

      if(type == OP_SELL)
      {
         ActiveDirection = 1;
         OpenOrder(OP_BUY);
      }

      LastReverseLevel += ReverseStepUSD;
   }
}

//+------------------------------------------------------------------+
void ManageBuyBasket()
{
   if(CountOrdersByType(OP_BUY) <= 0)
      return;

   double profit = GetBasketProfitByType(OP_BUY);

   if(profit >= BasketTPUSD)
   {
      CloseOrdersByType(OP_BUY);
      BuyLastAddLevel = 0;
      LastReverseLevel = 0;
      return;
   }

   if(profit <= -BasketSLUSD)
   {
      CloseOrdersByType(OP_BUY);
      BuyLastAddLevel = 0;
      LastReverseLevel = 0;

      BuyPauseUntil = TimeCurrent() + (StopLossPauseMinutes * 60);

      ActiveDirection = -1;

      Print("BUY basket SL hit. BUY paused until ",
            TimeToString(BuyPauseUntil, TIME_DATE | TIME_MINUTES));

      OpenReverseOrderAfterSL(OP_SELL);
      return;
   }

   if(ActiveDirection != 1)
      return;

   if(profit >= BuyLastAddLevel + AddStepUSD)
   {
      if(CountMyOrders() < MaxTotalOpenOrders)
      {
         OpenOrder(OP_BUY);
         BuyLastAddLevel += AddStepUSD;
      }
   }
}

//+------------------------------------------------------------------+
void ManageSellBasket()
{
   if(CountOrdersByType(OP_SELL) <= 0)
      return;

   double profit = GetBasketProfitByType(OP_SELL);

   if(profit >= BasketTPUSD)
   {
      CloseOrdersByType(OP_SELL);
      SellLastAddLevel = 0;
      LastReverseLevel = 0;
      return;
   }

   if(profit <= -BasketSLUSD)
   {
      CloseOrdersByType(OP_SELL);
      SellLastAddLevel = 0;
      LastReverseLevel = 0;

      SellPauseUntil = TimeCurrent() + (StopLossPauseMinutes * 60);

      ActiveDirection = 1;

      Print("SELL basket SL hit. SELL paused until ",
            TimeToString(SellPauseUntil, TIME_DATE | TIME_MINUTES));

      OpenReverseOrderAfterSL(OP_BUY);
      return;
   }

   if(ActiveDirection != -1)
      return;

   if(profit >= SellLastAddLevel + AddStepUSD)
   {
      if(CountMyOrders() < MaxTotalOpenOrders)
      {
         OpenOrder(OP_SELL);
         SellLastAddLevel += AddStepUSD;
      }
   }
}

//+------------------------------------------------------------------+
void OpenOrderByDirection(int direction)
{
   if(direction == 1)
      OpenOrder(OP_BUY);

   if(direction == -1)
      OpenOrder(OP_SELL);
}

//+------------------------------------------------------------------+
void ResetAddLevels()
{
   BuyLastAddLevel  = 0;
   SellLastAddLevel = 0;
}

//+------------------------------------------------------------------+
double GetBasketProfitByType(int type)
{
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
      {
         total += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOrdersByType(int type)
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
int CountMyOrders()
{
   return CountOrdersByType(OP_BUY) + CountOrdersByType(OP_SELL);
}

//+------------------------------------------------------------------+
int GetOldestOrderTicket()
{
   int oldestTicket = -1;
   datetime oldestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber)
         continue;

      if(oldestTime == 0 || OrderOpenTime() < oldestTime)
      {
         oldestTime = OrderOpenTime();
         oldestTicket = OrderTicket();
      }
   }

   return oldestTicket;
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
         Print("Close failed. Ticket=", OrderTicket(), " Error=", GetLastError());
   }
}



//+------------------------------------------------------------------+
// Recovery logic: when latest/current BUY or SELL order is in loss,
// create another order in the SAME direction, following M30 trend.
// It opens only after price moved against the latest order by RecoveryPriceGap.
//+------------------------------------------------------------------+
void ManageRecoveryOrders()
{
   if(!UseRecoveryOrders)
      return;

   if(DailyProfitLimitReached)
      return;

   if(!IsTradingHour())
      return;

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   ManageRecoveryOrderByType(OP_BUY);
   ManageRecoveryOrderByType(OP_SELL);
}

//+------------------------------------------------------------------+
void ManageRecoveryOrderByType(int type)
{
   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(CountOrdersByType(type) <= 0)
      return;

   if(CountOrdersByType(type) >= MaxRecoveryOrdersPerSide)
      return;

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
      return;

   int ticket = GetLatestOrderTicketByType(type);
   if(ticket <= 0)
      return;

   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   double profit = OrderProfit() + OrderSwap() + OrderCommission();
   if(profit > -RecoveryLossUSD)
      return;

   RefreshRates();

   double openPrice = OrderOpenPrice();
   bool priceMovedAgainst = false;

   // BUY is losing when price moves down from open price.
   if(type == OP_BUY)
   {
      if((openPrice - Bid) >= RecoveryPriceGap)
         priceMovedAgainst = true;
   }

   // SELL is losing when price moves up from open price.
   if(type == OP_SELL)
   {
      if((Ask - openPrice) >= RecoveryPriceGap)
         priceMovedAgainst = true;
   }

   if(!priceMovedAgainst)
   {
      Print("Recovery blocked. Price gap not reached. Type=", type,
            " Ticket=", ticket,
            " Profit=", DoubleToString(profit, 2),
            " RequiredGap=", DoubleToString(RecoveryPriceGap, Digits));
      return;
   }

   OpenRecoveryOrder(type);
}

//+------------------------------------------------------------------+
int GetLatestOrderTicketByType(int type)
{
   int latestTicket = -1;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != type)
         continue;

      if(OrderOpenTime() >= latestTime)
      {
         latestTime = OrderOpenTime();
         latestTicket = OrderTicket();
      }
   }

   return latestTicket;
}

//+------------------------------------------------------------------+
void OpenRecoveryOrder(int type)
{
   if(!IsTradingHour())
      return;

   if(IsDirectionPaused(type))
   {
      Print("Recovery blocked. Direction paused. Type=", type);
      return;
   }

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(DailyProfitLimitReached)
      return;

   // Recovery must follow M30 trend also.
   if(!CanOpenByM30Trend(type))
      return;

   RefreshRates();

   double price = 0;
   string comment = "";
   color orderColor = clrDeepSkyBlue;

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "V3BUYSELL_RECOVERY_BUY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "V3BUYSELL_RECOVERY_SELL";
   }
   else
      return;

   int ticket = OrderSend(
      Symbol(),
      type,
      Lots,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      orderColor
   );

   if(ticket < 0)
      Print("Recovery OrderSend failed. Type=", type, " Error=", GetLastError());
   else
      Print("Recovery order opened. Ticket=", ticket, " ", comment);
}

//+------------------------------------------------------------------+
// Force open reverse order immediately after basket stop loss.
// This bypasses direction pause and same-trend gap filter,
// but still respects trading hour and MaxOrdersPerSide.
//+------------------------------------------------------------------+
void OpenReverseOrderAfterSL(int type)
{
   if(!IsTradingHour())
      return;

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(DailyProfitLimitReached)
      return;

   if(!CanOpenByM30Trend(type))
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "V3BUYSELL_SL_REVERSE_BUY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "V3BUYSELL_SL_REVERSE_SELL";
   }
   else
      return;

   int ticket = OrderSend(
      Symbol(),
      type,
      Lots,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      clrOrange
   );

   if(ticket < 0)
      Print("SL reverse OrderSend failed. Type=", type, " Error=", GetLastError());
   else
      Print("SL reverse order opened immediately. Ticket=", ticket, " ", comment);
}

//+------------------------------------------------------------------+
// M30 trend direction.
// Returns  1 = BUY trend, -1 = SELL trend, 0 = neutral/no clear trend.
// Uses EMA fast/slow on M30. Closed candle is safer for avoiding repaint.
int GetM30TrendDirection()
{
   int shift = 0;

   if(UseClosedM30Candle)
      shift = 1;

   double fastEMA = iMA(Symbol(), PERIOD_M30, M30TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, shift);
   double slowEMA = iMA(Symbol(), PERIOD_M30, M30TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, shift);
   double closeM30 = iClose(Symbol(), PERIOD_M30, shift);

   if(fastEMA <= 0 || slowEMA <= 0 || closeM30 <= 0)
      return 0;

   if(fastEMA > slowEMA && closeM30 > fastEMA)
      return 1;

   if(fastEMA < slowEMA && closeM30 < fastEMA)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
// Blocks order creation unless the requested order type follows M30 trend.
bool CanOpenByM30Trend(int type)
{
   if(!UseM30TrendFilter)
      return true;

   int trend = GetM30TrendDirection();

   if(trend == 0)
   {
      Print("Order blocked. M30 trend is neutral. Type=", type);
      return false;
   }

   if(type == OP_BUY && trend == 1)
      return true;

   if(type == OP_SELL && trend == -1)
      return true;

   string trendText = "NEUTRAL";
   if(trend == 1)
      trendText = "BUY";
   if(trend == -1)
      trendText = "SELL";

   Print("Order blocked. M30 trend filter mismatch. Trend=",
         trendText,
         " RequestedType=",
         type);

   return false;
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{
   if(!IsTradingHour())
      return;

   if(IsDirectionPaused(type))
   {
      Print("Order blocked. Direction paused. Type=", type);
      return;
   }

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(DailyProfitLimitReached)
      return;

   if(!CanOpenByM30Trend(type))
      return;

   if(!CanOpenBySameTrendGap(type))
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "V3BUYSELL_BUY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "V3BUYSELL_SELL";
   }
   else
      return;

   int ticket = OrderSend(
      Symbol(),
      type,
      Lots,
      price,
      Slippage,
      0,
      0,
      comment,
      MagicNumber,
      0,
      clrAqua
   );

   if(ticket < 0)
      Print("OrderSend failed. Error=", GetLastError());
   else
      Print("Order opened. Ticket=", ticket, " ", comment);
}

//+------------------------------------------------------------------+
bool CanOpenBySameTrendGap(int type)
{
   double lastPrice = GetLastOrderOpenPriceByType(type);

   if(lastPrice <= 0)
      return true;

   RefreshRates();

   double currentPrice = 0;

   if(type == OP_BUY)
      currentPrice = Ask;

   if(type == OP_SELL)
      currentPrice = Bid;

   double gap = MathAbs(currentPrice - lastPrice);

   if(gap >= MinSameTrendPriceGap)
      return true;

   Print("Same basket order blocked. Gap=",
         DoubleToString(gap, Digits),
         " Required=",
         DoubleToString(MinSameTrendPriceGap, Digits));

   return false;
}

//+------------------------------------------------------------------+
double GetLastOrderOpenPriceByType(int type)
{
   double lastPrice = 0;
   datetime lastTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != type)
         continue;

      if(OrderOpenTime() >= lastTime)
      {
         lastTime = OrderOpenTime();
         lastPrice = OrderOpenPrice();
      }
   }

   return lastPrice;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
string GetTrendText(int trend)
{
   if(trend == 1)
      return "BUY";

   if(trend == -1)
      return "SELL";

   return "NEUTRAL";
}

//+------------------------------------------------------------------+
color GetTrendColor(int trend)
{
   if(trend == 1)
      return clrLime;

   if(trend == -1)
      return clrTomato;

   return clrSilver;
}

//+------------------------------------------------------------------+
// Professional colorful dashboard only. No trading logic changed.
//+------------------------------------------------------------------+
void DrawDashboard()
{
   int x = 300;
   int y = 20;
   int w = 330;
   int h = 500;

   DrawPanel("V3_DASH_BG", x, y, w, h, clrBlack);

   int row = y + 12;

   DrawText("V3_DASH_TITLE", "V3 BUY SELL BASKET BOT", x + 15, row, clrGold, 11);
   row += 24;

   DrawText("V3_DASH_LINE", "--------------------------------------", x + 15, row, clrDimGray, 8);
   row += 18;

   string tradeStatus = "ACTIVE";
   color  tradeColor  = clrLime;

   if(DailyProfitLimitReached)
   {
      tradeStatus = "DAILY TARGET HIT - STOPPED";
      tradeColor  = clrRed;
   }
   else if(!IsTradingHour())
   {
      tradeStatus = "OUTSIDE TRADING HOURS";
      tradeColor  = clrOrange;
   }

   string dirText = "BUY";
   color  dirColor = clrLime;
   if(ActiveDirection == -1)
   {
      dirText = "SELL";
      dirColor = clrTomato;
   }

   double buyProfit  = GetBasketProfitByType(OP_BUY);
   double sellProfit = GetBasketProfitByType(OP_SELL);
   double totalProfit = buyProfit + sellProfit;

   DrawDashRow("Status", tradeStatus, x, row, clrWhite, tradeColor); row += 22;
   DrawDashRow("Symbol", Symbol(), x, row, clrWhite, clrAqua); row += 22;
   DrawDashRow("Magic", IntegerToString(MagicNumber), x, row, clrWhite, clrLightSkyBlue); row += 22;
   DrawDashRow("Direction", dirText, x, row, clrWhite, dirColor); row += 22;

   string m30TrendText = GetTrendText(GetM30TrendDirection());
   color  m30TrendColor = GetTrendColor(GetM30TrendDirection());
   DrawDashRow("M30 Trend", m30TrendText, x, row, clrWhite, m30TrendColor); row += 22;

   DrawText("V3_DASH_LINE2", "--------------------------------------", x + 15, row, clrDimGray, 8);
   row += 18;

   DrawDashRow("Balance", DoubleToString(AccountBalance(), 2), x, row, clrWhite, clrLightSkyBlue); row += 22;
   DrawDashRow("Equity", DoubleToString(AccountEquity(), 2), x, row, clrWhite, clrAqua); row += 22;
   DrawDashRow("Daily Start", DoubleToString(DailyStartBalance, 2), x, row, clrWhite, clrYellow); row += 22;
   DrawDashRow("Target Equity", DoubleToString(GetDailyProfitTargetAmount(), 2), x, row, clrWhite, clrGold); row += 22;
   DrawDashRow("Today P/L", DoubleToString(GetTodayProfitFromOpeningBalance(), 2), x, row, clrWhite, ProfitColor(GetTodayProfitFromOpeningBalance())); row += 22;

   DrawText("V3_DASH_LINE3", "--------------------------------------", x + 15, row, clrDimGray, 8);
   row += 18;

   DrawDashRow("BUY Orders", IntegerToString(CountOrdersByType(OP_BUY)), x, row, clrWhite, clrLime); row += 22;
   DrawDashRow("SELL Orders", IntegerToString(CountOrdersByType(OP_SELL)), x, row, clrWhite, clrTomato); row += 22;
   DrawDashRow("Total Orders", IntegerToString(CountMyOrders()) + " / " + IntegerToString(MaxTotalOpenOrders), x, row, clrWhite, clrAqua); row += 22;
   DrawDashRow("BUY Basket P/L", DoubleToString(buyProfit, 2), x, row, clrWhite, ProfitColor(buyProfit)); row += 22;
   DrawDashRow("SELL Basket P/L", DoubleToString(sellProfit, 2), x, row, clrWhite, ProfitColor(sellProfit)); row += 22;
   DrawDashRow("Total Basket P/L", DoubleToString(totalProfit, 2), x, row, clrWhite, ProfitColor(totalProfit)); row += 22;

   DrawText("V3_DASH_LINE4", "--------------------------------------", x + 15, row, clrDimGray, 8);
   row += 18;

   DrawDashRow("Trading Hours", IntegerToString(StartHour) + ":00 - " + IntegerToString(EndHour) + ":00", x, row, clrWhite, clrSilver); row += 22;
   DrawDashRow("Basket TP / SL", DoubleToString(BasketTPUSD, 2) + " / " + DoubleToString(BasketSLUSD, 2), x, row, clrWhite, clrGold); row += 22;
   DrawDashRow("Min Gap", DoubleToString(MinSameTrendPriceGap, 2), x, row, clrWhite, clrLightSkyBlue); row += 22;
   DrawDashRow("Recovery Loss", DoubleToString(RecoveryLossUSD, 2), x, row, clrWhite, clrOrange); row += 22;
   DrawDashRow("Recovery Gap", DoubleToString(RecoveryPriceGap, 2), x, row, clrWhite, clrOrange); row += 22;
}

//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DrawText(string name, string textValue, int x, int y, color textColor, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, textValue);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DrawDashRow(string label, string value, int x, int y, color labelColor, color valueColor)
{

    x=x-200;
   string safeLabel = label;
   StringReplace(safeLabel, " ", "_");
   StringReplace(safeLabel, "/", "_");

   DrawText("V3_DASH_L_" + safeLabel, label + " :", x + 170, y, labelColor, 8);
   DrawText("V3_DASH_V_" + safeLabel, value, x + 15, y, valueColor, 8);
}

//+------------------------------------------------------------------+
color ProfitColor(double value)
{
   if(value > 0)
      return clrLime;

   if(value < 0)
      return clrTomato;

   return clrSilver;
}

//+------------------------------------------------------------------+
void DeleteDashboard()
{
   int total = ObjectsTotal(0, -1, -1);

   for(int i = total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);

      if(StringFind(name, "V3_DASH_") == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
