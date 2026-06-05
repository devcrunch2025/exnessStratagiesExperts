#property strict

double Lots                 = 0.01;
double AddStepUSD           = 1.00;   // Add same-side order when basket is in profit by this step
double ReverseLossTriggerUSD = 5.00;   // Opposite hedge/reverse order trigger. Example: BUY order loss -$5 creates SELL
double LossRecoveryGapPrice  = 50.0;   // Same-side recovery order raw price gap while basket/order is in loss
double BasketTPUSD          = 1.00;
double BasketSLUSD          = 5.00;
double MinSameTrendPriceGap = 50.0;

int    MaxOrdersPerSide     = 10;
int    MagicNumber          = 20260603;
int    Slippage             = 30;
int    StartHour            = 3;
int    EndHour              = 10;
int    StopLossPauseMinutes = 0;
int    MaxTotalOpenOrders   = 500;

bool   UseLockedPriceBreakOrder = true;
bool   UseDailyProfitLimit  = true;
double DailyProfitMultiplier = 2.0; // Daily target = opening balance * 2
bool   CloseOrdersOnDailyProfitLimit = true;

// Create only one order per chart candle
bool   UseOneOrderPerCandle = true;

// Pause NEW order creation after booked/equity profit reaches this amount
bool   UseProfitPauseAfterBooking = true;
double ProfitPauseTargetUSD       = 5.00;
bool   UseEquityForProfitPause    = true;  // true = Balance + floating P/L, false = Balance only
bool   CloseOrdersOnProfitPause   = true;  // close all BUY and SELL orders once $10 profit target is reached

// Colorful professional dashboard
bool   ShowDashboard          = true;
int    DashboardCorner        = CORNER_RIGHT_UPPER;
int    DashboardXDistance     = 20;
int    DashboardYDistance     = 25;
int    DashboardWidth         = 330;
int    DashboardRowHeight     = 20;
string DASH_PREFIX            = "EA_DASH_PANEL_";

// 1 = BUY, -1 = SELL
int ActiveDirection = 1;

double BuyLastAddLevel  = 0;
double SellLastAddLevel = 0;
double LastReverseLevel = 0;

// Separate reverse trigger levels for BUY-loss -> SELL and SELL-loss -> BUY
double BuyLossReverseLevel  = 0;
double SellLossReverseLevel = 0;

datetime BuyPauseUntil  = 0;
datetime SellPauseUntil = 0;

double   DailyStartBalance = 0;
double   DailyStartEquity  = 0;
double   DailyStartMargin  = 0;
double   DailyStartFreeMargin = 0;
int      DailyStartDay     = -1;
bool     DailyProfitLimitReached = false;

bool     ProfitPauseReached = false;
datetime LastOrderCandleTime = 0;

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
   DeleteDashboardObjects();
}

//+------------------------------------------------------------------+
void OnTick()
{
   ResetDailyProfitLimitIfNewDay();
   DrawDashboard();

   if(CheckProfitPauseAfterBooking())
   {
      DrawDashboard();
      return;
   }

   if(CheckDailyProfitLimit())
   {
      DrawDashboard();
      return;
   }

   // if(!IsTradingHour())
   //    return;

   if(CountMyOrders() == 0)
   {
      OpenOrderByDirection(ActiveDirection);
      ResetAddLevels();
      ResetReverseLevels();
      return;
   }

   ManageLockedPriceBreakOrder();
   ManageOldestOrderReverseEveryMinusOne();
   ManageLossRecoveryOrders();
   ManageBuyBasket();
   ManageSellBasket();

   DrawDashboard();
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{

   // return true;
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
   DailyStartEquity  = AccountEquity();
   DailyStartMargin  = AccountMargin();
   DailyStartFreeMargin = AccountFreeMargin();
   DailyStartDay = TimeDayOfYear(TimeCurrent());
   DailyProfitLimitReached = false;

   Print("Daily profit tracking started. Opening balance=",
         DoubleToString(DailyStartBalance, 2),
         " Opening equity=",
         DoubleToString(DailyStartEquity, 2),
         " Opening margin=",
         DoubleToString(DailyStartMargin, 2),
         " Opening free margin=",
         DoubleToString(DailyStartFreeMargin, 2),
         " Daily target profit=",
         DoubleToString(GetDailyProfitTargetAmount(), 2));
}

//+------------------------------------------------------------------+
void ResetDailyProfitLimitIfNewDay()
{
   int today = TimeDayOfYear(TimeCurrent());

   if(today != DailyStartDay)
   {
      DailyStartBalance = AccountBalance();
      DailyStartEquity  = AccountEquity();
      DailyStartMargin  = AccountMargin();
      DailyStartFreeMargin = AccountFreeMargin();
      DailyStartDay = today;
      DailyProfitLimitReached = false;
      ProfitPauseReached = false;
      LastOrderCandleTime = 0;

      BuyPauseUntil = 0;
      SellPauseUntil = 0;
      ResetAddLevels();
      ResetReverseLevels();

      Print("NEW DAY RESET: margin/profit baseline reset. Opening balance=",
            DoubleToString(DailyStartBalance, 2),
            " Opening equity=",
            DoubleToString(DailyStartEquity, 2),
            " Opening margin=",
            DoubleToString(DailyStartMargin, 2),
            " Opening free margin=",
            DoubleToString(DailyStartFreeMargin, 2),
            " Daily target profit=",
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
   // Daily target uses today's reset baseline.
   // If equity mode is enabled, floating profit/loss is included.
   if(UseEquityForProfitPause)
      return AccountEquity() - DailyStartEquity;

   return AccountBalance() - DailyStartBalance;
}

//+------------------------------------------------------------------+
bool CheckDailyProfitLimit()
{
   if(!UseDailyProfitLimit)
      return false;

   if(DailyProfitLimitReached)
      return true;

   double todayProfit = GetTodayProfitFromOpeningBalance();
   double targetProfit = GetDailyProfitTargetAmount();

   if(todayProfit >= targetProfit)
   {
      DailyProfitLimitReached = true;

      Print("DAILY PROFIT LIMIT REACHED. OpeningBalance=",
            DoubleToString(DailyStartBalance, 2),
            " CurrentEquity=",
            DoubleToString(AccountEquity(), 2),
            " Profit=",
            DoubleToString(todayProfit, 2),
            " Target=",
            DoubleToString(targetProfit, 2),
            ". Trading stopped for today.");

      if(CloseOrdersOnDailyProfitLimit)
         CloseAllMyOrders();

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
double GetProfitPauseCurrentProfit()
{
   // Reset automatically every new day by ResetDailyProfitLimitIfNewDay().
   if(UseEquityForProfitPause)
      return AccountEquity() - DailyStartEquity;    // Balance + floating P/L from today's opening equity

   return AccountBalance() - DailyStartBalance;     // Booked profit only from today's opening balance
}

//+------------------------------------------------------------------+
bool CheckProfitPauseAfterBooking()
{
   if(!UseProfitPauseAfterBooking)
      return false;

   if(ProfitPauseReached)
      return true;

   double profitNow = GetProfitPauseCurrentProfit();

   if(profitNow >= ProfitPauseTargetUSD)
   {
      ProfitPauseReached = true;

      Print("PROFIT PAUSE REACHED. OpeningBalance=",
            DoubleToString(DailyStartBalance, 2),
            " Balance=", DoubleToString(AccountBalance(), 2),
            " Equity=", DoubleToString(AccountEquity(), 2),
            " ProfitNow=", DoubleToString(profitNow, 2),
            " Target=", DoubleToString(ProfitPauseTargetUSD, 2),
            ". Closing all orders and stopping new order creation.");

      if(CloseOrdersOnProfitPause)
         CloseAllMyOrders();

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
bool CanCreateNewOrderNow()
{
   if(DailyProfitLimitReached)
      return false;

   if(CheckProfitPauseAfterBooking())
   {
      Print("New order blocked. Profit pause reached.");
      return false;
   }

   if(UseOneOrderPerCandle)
   {
      datetime currentCandleTime = iTime(Symbol(), Period(), 0);

      if(currentCandleTime == LastOrderCandleTime)
      {
         Print("New order blocked. One order already created on this candle.");
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
void MarkOrderCreatedOnThisCandle()
{
   if(UseOneOrderPerCandle)
      LastOrderCandleTime = iTime(Symbol(), Period(), 0);
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
         Print("Close all orders failed. Ticket=", OrderTicket(), " Error=", GetLastError());
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

   if(buyDistance < sellDistance && buyDistance >= MinSameTrendPriceGap)
   {
      ActiveDirection = 1;

      if(CountMyOrders() < MaxTotalOpenOrders)
         OpenOrder(OP_BUY);

      return;
   }

   if(sellDistance < buyDistance && sellDistance >= MinSameTrendPriceGap)
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

   // Opposite hedge/reverse order trigger is now separate from recovery gap.
   // Example: oldest BUY reaches -$5 => create SELL. Oldest SELL reaches -$5 => create BUY.
   if(type == OP_BUY && profit <= -(BuyLossReverseLevel + ReverseLossTriggerUSD))
   {
      ActiveDirection = -1;
      OpenOrder(OP_SELL);
      BuyLossReverseLevel += ReverseLossTriggerUSD;
      Print("BUY loss reverse trigger: BUY loss=", DoubleToString(profit, 2),
            " Next trigger level=", DoubleToString(BuyLossReverseLevel + ReverseLossTriggerUSD, 2));
      return;
   }

   if(type == OP_SELL && profit <= -(SellLossReverseLevel + ReverseLossTriggerUSD))
   {
      ActiveDirection = 1;
      OpenOrder(OP_BUY);
      SellLossReverseLevel += ReverseLossTriggerUSD;
      Print("SELL loss reverse trigger: SELL loss=", DoubleToString(profit, 2),
            " Next trigger level=", DoubleToString(SellLossReverseLevel + ReverseLossTriggerUSD, 2));
      return;
   }
}

//+------------------------------------------------------------------+
void ManageLossRecoveryOrders()
{
   // Same-side recovery while a basket is in loss.
   // BUY loss + price gap >= LossRecoveryGapPrice => add BUY recovery.
   // SELL loss + price gap >= LossRecoveryGapPrice => add SELL recovery.
   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(CountOrdersByType(OP_BUY) > 0)
   {
      double buyProfit = GetBasketProfitByType(OP_BUY);
      if(buyProfit < 0 && CountOrdersByType(OP_BUY) < MaxOrdersPerSide)
      {
         if(CanOpenRecoveryByPriceGap(OP_BUY))
            OpenRecoveryOrder(OP_BUY);
      }
   }

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(CountOrdersByType(OP_SELL) > 0)
   {
      double sellProfit = GetBasketProfitByType(OP_SELL);
      if(sellProfit < 0 && CountOrdersByType(OP_SELL) < MaxOrdersPerSide)
      {
         if(CanOpenRecoveryByPriceGap(OP_SELL))
            OpenRecoveryOrder(OP_SELL);
      }
   }
}

//+------------------------------------------------------------------+
bool CanOpenRecoveryByPriceGap(int type)
{
   double lastPrice = GetLastOrderOpenPriceByType(type);

   if(lastPrice <= 0)
      return false;

   RefreshRates();

   double currentPrice = 0;
   if(type == OP_BUY)
      currentPrice = Ask;
   if(type == OP_SELL)
      currentPrice = Bid;

   double gap = MathAbs(currentPrice - lastPrice);

   if(gap >= LossRecoveryGapPrice)
      return true;

   Print("Recovery blocked. Type=", type,
         " Gap=", DoubleToString(gap, Digits),
         " Required=", DoubleToString(LossRecoveryGapPrice, Digits));

   return false;
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

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
   {
      Print("Recovery blocked. MaxOrdersPerSide reached. Type=", type);
      return;
   }

   if(CountMyOrders() >= MaxTotalOpenOrders)
      return;

   if(!CanCreateNewOrderNow())
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "BUY_LOSS_RECOVERY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "SELL_LOSS_RECOVERY";
   }
   else
      return;

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0, comment, MagicNumber, 0, clrYellow);

   if(ticket < 0)
      Print("Recovery OrderSend failed. Type=", type, " Error=", GetLastError());
   else
   {
      MarkOrderCreatedOnThisCandle();
      Print("Recovery order opened. Ticket=", ticket, " ", comment,
            " GapRequired=", DoubleToString(LossRecoveryGapPrice, Digits));
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
      ResetReverseLevels();
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
      ResetReverseLevels();
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
void ResetReverseLevels()
{
   LastReverseLevel = 0;
   BuyLossReverseLevel = 0;
   SellLossReverseLevel = 0;
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

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
   {
      Print("Order blocked. MaxOrdersPerSide reached. Type=", type);
      return;
   }

   if(!CanCreateNewOrderNow())
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "SL_REVERSE_BUY";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "SL_REVERSE_SELL";
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
   {
      MarkOrderCreatedOnThisCandle();
      Print("SL reverse order opened immediately. Ticket=", ticket, " ", comment);
   }
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

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
   {
      Print("Order blocked. MaxOrdersPerSide reached. Type=", type);
      return;
   }

   if(!CanCreateNewOrderNow())
      return;

   if(!CanOpenBySameTrendGap(type))
      return;

   RefreshRates();

   double price = 0;
   string comment = "";

   if(type == OP_BUY)
   {
      price = Ask;
      comment = "BUY_BASKET";
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      comment = "SELL_BASKET";
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
   {
      MarkOrderCreatedOnThisCandle();
      Print("Order opened. Ticket=", ticket, " ", comment);
   }
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
// Colorful professional black background dashboard
//+------------------------------------------------------------------+
void DeleteDashboardObjects()
{
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
   {
      string name = ObjectName(i);
      if(StringFind(name, DASH_PREFIX, 0) == 0)
         ObjectDelete(name);
   }
}

//+------------------------------------------------------------------+
void CreateOrUpdatePanel(string name, int x, int y, int w, int h, color bg, color border)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, border);
}

//+------------------------------------------------------------------+
void CreateOrUpdateLabel(string name, string text, int x, int y, int fontSize, color clr, string font="Arial")
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }

   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
string YesNo(bool value)
{
   if(value) return "YES";
   return "NO";
}

//+------------------------------------------------------------------+
string DirectionText()
{
   if(ActiveDirection == 1)  return "BUY";
   if(ActiveDirection == -1) return "SELL";
   return "NONE";
}

//+------------------------------------------------------------------+
color ProfitColor(double value)
{
   if(value > 0.0) return clrLime;
   if(value < 0.0) return clrTomato;
   return clrWhite;
}

//+------------------------------------------------------------------+
void DashboardRow(int row, string label, string value, color valueColor)
{
   int xLabel = DashboardXDistance + 14;
   int xValue = DashboardXDistance + 175;
   int y = DashboardYDistance + 48 + (row * DashboardRowHeight);

   CreateOrUpdateLabel(DASH_PREFIX + "L_" + IntegerToString(row), label, xLabel, y, 9, clrSilver, "Arial");
   CreateOrUpdateLabel(DASH_PREFIX + "V_" + IntegerToString(row), value, xValue, y, 9, valueColor, "Arial Bold");
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   if(!ShowDashboard)
   {
      DeleteDashboardObjects();
      return;
   }

   double buyProfit   = GetBasketProfitByType(OP_BUY);
   double sellProfit  = GetBasketProfitByType(OP_SELL);
   double totalProfit = buyProfit + sellProfit;
   double todayProfit = GetProfitPauseCurrentProfit();

   int buyCount  = CountOrdersByType(OP_BUY);
   int sellCount = CountOrdersByType(OP_SELL);
   int allCount  = buyCount + sellCount;

   string status = "TRADING";
   color statusColor = clrLime;

   if(ProfitPauseReached)
   {
      status = "PROFIT TARGET HIT";
      statusColor = clrGold;
   }
   else if(DailyProfitLimitReached)
   {
      status = "DAILY LIMIT HIT";
      statusColor = clrOrange;
   }
   else if(!IsTradingHour())
   {
      status = "OUT OF HOURS";
      statusColor = clrTomato;
   }

   int rows = 18;
   int panelHeight = 60 + (rows * DashboardRowHeight);

   CreateOrUpdatePanel(DASH_PREFIX + "BG", DashboardXDistance, DashboardYDistance, DashboardWidth, panelHeight, clrBlack, clrDodgerBlue);
   CreateOrUpdatePanel(DASH_PREFIX + "HEAD", DashboardXDistance + 5, DashboardYDistance + 5, DashboardWidth - 10, 34, clrMidnightBlue, clrDeepSkyBlue);

   CreateOrUpdateLabel(DASH_PREFIX + "TITLE", "MT4 BASKET CONTROL DASHBOARD", DashboardXDistance + 18, DashboardYDistance + 12, 10, clrWhite, "Arial Bold");
   CreateOrUpdateLabel(DASH_PREFIX + "STATUS", status, DashboardXDistance + 200, DashboardYDistance + 30, 8, statusColor, "Arial Bold");

   DashboardRow(0,  "Symbol / TF", Symbol() + " / " + IntegerToString(Period()), clrAqua);
   DashboardRow(1,  "Active Direction", DirectionText(), ActiveDirection == 1 ? clrLime : clrTomato);
   DashboardRow(2,  "BUY Orders", IntegerToString(buyCount), clrLime);
   DashboardRow(3,  "SELL Orders", IntegerToString(sellCount), clrTomato);
   DashboardRow(4,  "Total Orders", IntegerToString(allCount) + " / " + IntegerToString(MaxTotalOpenOrders), clrWhite);
   DashboardRow(5,  "BUY Basket P/L", "$" + DoubleToString(buyProfit, 2), ProfitColor(buyProfit));
   DashboardRow(6,  "SELL Basket P/L", "$" + DoubleToString(sellProfit, 2), ProfitColor(sellProfit));
   DashboardRow(7,  "Open Basket P/L", "$" + DoubleToString(totalProfit, 2), ProfitColor(totalProfit));
   DashboardRow(8,  "Today Profit", "$" + DoubleToString(todayProfit, 2) + " / $" + DoubleToString(ProfitPauseTargetUSD, 2), ProfitColor(todayProfit));
   DashboardRow(9,  "Balance", "$" + DoubleToString(AccountBalance(), 2), clrWhite);
   DashboardRow(10, "Equity", "$" + DoubleToString(AccountEquity(), 2), ProfitColor(AccountEquity() - AccountBalance()));
   DashboardRow(11, "Margin", "$" + DoubleToString(AccountMargin(), 2), clrOrange);
   DashboardRow(12, "Free Margin", "$" + DoubleToString(AccountFreeMargin(), 2), clrAqua);
   DashboardRow(13, "Daily Base Balance", "$" + DoubleToString(DailyStartBalance, 2), clrSilver);
   DashboardRow(14, "Daily Base Equity", "$" + DoubleToString(DailyStartEquity, 2), clrSilver);
   DashboardRow(15, "One Order/Candle", YesNo(UseOneOrderPerCandle), UseOneOrderPerCandle ? clrLime : clrTomato);
   DashboardRow(16, "Reverse Loss", "$" + DoubleToString(ReverseLossTriggerUSD, 2), clrOrange);
   DashboardRow(17, "Recovery Gap", DoubleToString(LossRecoveryGapPrice, Digits), clrAqua);
   DashboardRow(18, "Profit Close All", YesNo(CloseOrdersOnProfitPause), CloseOrdersOnProfitPause ? clrLime : clrTomato);
   DashboardRow(19, "Trading Hours", IntegerToString(StartHour) + ":00 - " + IntegerToString(EndHour) + ":00", clrGold);

   ChartRedraw();
}
