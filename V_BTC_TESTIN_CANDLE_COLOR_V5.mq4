#property strict

input double Lots                 = 0.01;
input double AddStepUSD           = 1.00;
input double ReverseStepUSD       = 1.00;
input double BasketTPUSD          = 1.00;
input double BasketSLUSD          = 10.00;
input double MinSameTrendPriceGap = 50.0;

input int    MaxOrdersPerSide     = 5;
input int    MagicNumber          = 20260603;
input int    Slippage             = 30;
input int    StartHour            = 0;
input int    EndHour              = 10;
input int    StopLossPauseMinutes = 0;

input bool   UseLockedPriceBreakOrder = true;

// 1 = BUY, -1 = SELL
int ActiveDirection = 1;

double BuyLastAddLevel  = 0;
double SellLastAddLevel = 0;
double LastReverseLevel = 0;

datetime BuyPauseUntil  = 0;
datetime SellPauseUntil = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("Separate BUY SELL Basket Bot Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(!IsTradingHour())
      return;

   if(CountMyOrders() == 0)
   {
      OpenOrderByDirection(ActiveDirection);
      ResetAddLevels();
      LastReverseLevel = 0;
      return;
   }

   ManageLockedPriceBreakOrder();
   ManageOldestOrderReverseEveryMinusOne();
   ManageBuyBasket();
   ManageSellBasket();
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{
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
void ManageLockedPriceBreakOrder()
{
   if(!UseLockedPriceBreakOrder)
      return;

   if(CountOrdersByType(OP_BUY) <= 0 || CountOrdersByType(OP_SELL) <= 0)
      return;

   if(CountMyOrders() >= MaxOrdersPerSide * 2)
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

      if(CountOrdersByType(OP_BUY) < MaxOrdersPerSide)
         OpenOrder(OP_BUY);

      return;
   }

   if(sellDistance < buyDistance && sellDistance >= MinSameTrendPriceGap)
   {
      ActiveDirection = -1;

      if(CountOrdersByType(OP_SELL) < MaxOrdersPerSide)
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
      if(CountOrdersByType(OP_BUY) < MaxOrdersPerSide)
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
      if(CountOrdersByType(OP_SELL) < MaxOrdersPerSide)
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
// Force open reverse order immediately after basket stop loss.
// This bypasses direction pause and same-trend gap filter,
// but still respects trading hour and MaxOrdersPerSide.
//+------------------------------------------------------------------+
void OpenReverseOrderAfterSL(int type)
{
   if(!IsTradingHour())
      return;

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
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
      Print("SL reverse order opened immediately. Ticket=", ticket, " ", comment);
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

   if(CountOrdersByType(type) >= MaxOrdersPerSide)
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