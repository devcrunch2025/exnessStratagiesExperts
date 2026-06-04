//+------------------------------------------------------------------+
//| H1 Trend Separate BUY/SELL Basket Recovery EA                    |
//+------------------------------------------------------------------+
#property strict

double LotSize              = 0.01;
double RecoveryLot          = 0.02;
double RecoveryGapRawPrice  = 100.0;

double BuyBasketTPMoney     = 0.50;
double SellBasketTPMoney    = 0.50;
double BuyBasketSLMoney     = 5.00;
double SellBasketSLMoney    = 5.00;

double DailyProfitTarget    = 50.00;

int    BuyMaxOrders         = 3;
int    SellMaxOrders        = 3;

double BigCandleM1RawPrice  = 300.0;
int    BigCandlePauseMin    = 30;

int    TradingStartHour     = 0;
int    TradingEndHour       = 10;

int    MagicNumber          = 20260604;
int    Slippage             = 30;

int    H1FastEMA            = 50;
int    H1SlowEMA            = 200;

double TrendChangeBasketLoss = 3.00;

datetime pauseNewOrdersUntil = 0;
datetime lastCheckedM1Candle = 0;

bool DailyTargetReached = false;
int  ManualTrendDirection = 0; // 0 = follow H1, 1 = BUY, -1 = SELL

//+------------------------------------------------------------------+
int OnInit()
{
   Print("H1 Trend Separate Basket EA Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   CheckBasketTPAndSL(OP_BUY);
   CheckBasketTPAndSL(OP_SELL);

   if(IsDailyProfitReached())
   {
      DailyTargetReached = true;
      CloseBasket(OP_BUY);
      CloseBasket(OP_SELL);

      ShowDashboard(GetActiveTrend(), false);
      return;
   }

   int trend = GetActiveTrend();
   bool allowNewOrders = IsTradingHour();

   ShowDashboard(trend, allowNewOrders);

   if(!allowNewOrders) return;
   if(TimeCurrent() < pauseNewOrdersUntil) return;
   if(IsBigM1CandleFound()) return;

   if(trend == 1)
      ManageDirection(OP_BUY);

   if(trend == -1)
      ManageDirection(OP_SELL);

   OpenOppositeWhenMaxReached();
}

//+------------------------------------------------------------------+
int GetActiveTrend()
{
   if(ManualTrendDirection != 0)
      return ManualTrendDirection;

   return GetH1Trend();
}

//+------------------------------------------------------------------+
bool IsTradingHour()
{
   int serverHour = TimeHour(TimeCurrent());
   return(serverHour >= TradingStartHour && serverHour <= TradingEndHour);
}

//+------------------------------------------------------------------+
int GetH1Trend()
{
   double fast = iMA(Symbol(), PERIOD_H1, H1FastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slow = iMA(Symbol(), PERIOD_H1, H1SlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   if(fast > slow) return(1);
   if(fast < slow) return(-1);

   return(0);
}

//+------------------------------------------------------------------+
void ManageDirection(int orderType)
{
   int count = CountOrders(orderType);
   int maxCount = GetMaxOrders(orderType);

   if(count >= maxCount)
      return;

   if(count == 0)
   {
      OpenOrder(orderType, LotSize);
      return;
   }

   double lastPrice = GetLastOrderOpenPrice(orderType);
   if(lastPrice <= 0) return;

   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   double distance = MathAbs(currentPrice - lastPrice);

   if(distance >= RecoveryGapRawPrice)
      OpenOrder(orderType, RecoveryLot);
}

//+------------------------------------------------------------------+
void OpenOppositeWhenMaxReached()
{
   int buyCount  = CountOrders(OP_BUY);
   int sellCount = CountOrders(OP_SELL);

   if(buyCount >= BuyMaxOrders && sellCount < SellMaxOrders)
   {
      ManageDirection(OP_SELL);
      return;
   }

   if(sellCount >= SellMaxOrders && buyCount < BuyMaxOrders)
   {
      ManageDirection(OP_BUY);
      return;
   }
}

//+------------------------------------------------------------------+
int GetMaxOrders(int orderType)
{
   if(orderType == OP_BUY)  return BuyMaxOrders;
   if(orderType == OP_SELL) return SellMaxOrders;
   return 0;
}

//+------------------------------------------------------------------+
void CheckBasketTPAndSL(int orderType)
{
   int count = CountOrders(orderType);
   if(count <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(orderType == OP_BUY)
   {
      if(profit >= BuyBasketTPMoney)
      {
         Print("BUY basket TP hit. Profit=", profit);
         CloseBasket(OP_BUY);
         return;
      }

      if(profit <= -BuyBasketSLMoney)
      {
         Print("BUY basket SL hit. Trend changed to SELL. Profit=", profit);
         CloseBasket(OP_BUY);
         ManualTrendDirection = -1;
         return;
      }

      if(profit <= -TrendChangeBasketLoss)
      {
         Print("BUY basket P/L below -$", TrendChangeBasketLoss,
               ". Trend changed to SELL. Profit=", profit);

         ManualTrendDirection = -1;

         if(CountOrders(OP_SELL) == 0)
            OpenOrder(OP_SELL, LotSize);

         return;
      }
   }

   if(orderType == OP_SELL)
   {
      if(profit >= SellBasketTPMoney)
      {
         Print("SELL basket TP hit. Profit=", profit);
         CloseBasket(OP_SELL);
         return;
      }

      if(profit <= -SellBasketSLMoney)
      {
         Print("SELL basket SL hit. Trend changed to BUY. Profit=", profit);
         CloseBasket(OP_SELL);
         ManualTrendDirection = 1;
         return;
      }

      if(profit <= -TrendChangeBasketLoss)
      {
         Print("SELL basket P/L below -$", TrendChangeBasketLoss,
               ". Trend changed to BUY. Profit=", profit);

         ManualTrendDirection = 1;

         if(CountOrders(OP_BUY) == 0)
            OpenOrder(OP_BUY, LotSize);

         return;
      }
   }
}

//+------------------------------------------------------------------+
bool IsDailyProfitReached()
{
   double todayProfit = GetTodayClosedProfit();

   if(todayProfit >= DailyProfitTarget)
      return(true);

   return(false);
}

//+------------------------------------------------------------------+
double GetTodayClosedProfit()
{
   double profit = 0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderCloseTime() < todayStart) continue;

      profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(profit);
}

//+------------------------------------------------------------------+
void OpenOrder(int orderType, double lot)
{
   RefreshRates();

   double price = (orderType == OP_BUY) ? Ask : Bid;
   string comment = (orderType == OP_BUY) ? "H1_BUY_BASKET" : "H1_SELL_BASKET";

   int ticket = OrderSend(Symbol(), orderType, lot, price, Slippage, 0, 0,
                          comment, MagicNumber, 0, clrBlue);

   if(ticket < 0)
      Print("OrderSend failed. Error=", GetLastError());
   else
      Print("Order opened. Ticket=", ticket, " Type=", orderType, " Lot=", lot, " Price=", price);
}

//+------------------------------------------------------------------+
double GetBasketProfit(int orderType)
{
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != orderType) continue;

      profit += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return(profit);
}

//+------------------------------------------------------------------+
void CloseBasket(int orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != orderType) continue;

      RefreshRates();

      double price = (orderType == OP_BUY) ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrRed);

      if(closed)
         Print("Basket closed. Ticket=", OrderTicket());
      else
         Print("Basket close failed. Ticket=", OrderTicket(), " Error=", GetLastError());
   }
}

//+------------------------------------------------------------------+
int CountOrders(int orderType)
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
         count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
double GetLastOrderOpenPrice(int orderType)
{
   double price = 0;
   datetime latestTime = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
      {
         if(OrderOpenTime() > latestTime)
         {
            latestTime = OrderOpenTime();
            price = OrderOpenPrice();
         }
      }
   }

   return(price);
}

//+------------------------------------------------------------------+
bool IsBigM1CandleFound()
{
   datetime candleTime = iTime(Symbol(), PERIOD_M1, 1);

   if(candleTime == lastCheckedM1Candle)
      return(false);

   lastCheckedM1Candle = candleTime;

   double high1 = iHigh(Symbol(), PERIOD_M1, 1);
   double low1  = iLow(Symbol(), PERIOD_M1, 1);
   double range = MathAbs(high1 - low1);

   if(range >= BigCandleM1RawPrice)
   {
      pauseNewOrdersUntil = TimeCurrent() + BigCandlePauseMin * 60;
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
void ShowDashboard(int trend, bool allowNewOrders)
{
   string trendText = "NO TREND";
   if(trend == 1)  trendText = "BUY";
   if(trend == -1) trendText = "SELL";

   string tradingText = allowNewOrders ? "ACTIVE" : "TIME LOCKED";

   if(DailyTargetReached)
      tradingText = "DAILY TARGET HIT";

   Comment(
      "H1 TREND SEPARATE BASKET EA\n",
      "------------------------------\n",
      "Server Time: ", TimeToString(TimeCurrent(), TIME_DATE | TIME_SECONDS), "\n",
      "Trading Status: ", tradingText, "\n",
      "Active Trend: ", trendText, "\n",
      "Manual Trend Override: ", ManualTrendDirection, "\n\n",

      "Today's Closed Profit: $", DoubleToString(GetTodayClosedProfit(), 2), "\n",
      "Daily Profit Target: $", DoubleToString(DailyProfitTarget, 2), "\n\n",

      "BUY Orders: ", CountOrders(OP_BUY), " / ", BuyMaxOrders, "\n",
      "BUY Basket Profit: $", DoubleToString(GetBasketProfit(OP_BUY), 2), "\n",
      "BUY TP: $", DoubleToString(BuyBasketTPMoney, 2), "\n",
      "BUY SL: -$", DoubleToString(BuyBasketSLMoney, 2), "\n\n",

      "SELL Orders: ", CountOrders(OP_SELL), " / ", SellMaxOrders, "\n",
      "SELL Basket Profit: $", DoubleToString(GetBasketProfit(OP_SELL), 2), "\n",
      "SELL TP: $", DoubleToString(SellBasketTPMoney, 2), "\n",
      "SELL SL: -$", DoubleToString(SellBasketSLMoney, 2), "\n\n",

      "Recovery Gap Raw: ", DoubleToString(RecoveryGapRawPrice, 2), "\n",
      "Pause Until: ", TimeToString(pauseNewOrdersUntil, TIME_DATE | TIME_SECONDS)
   );
}
//+------------------------------------------------------------------+