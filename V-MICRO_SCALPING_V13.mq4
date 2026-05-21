#property strict

extern double BaseLot            = 0.01;
extern int    MagicNumber        = 20260522;

extern double BasketProfitUSD    = 0.50;
extern double BasketStopLossUSD  = -15.00;

extern int    MaxOrders          = 5;
extern int    MaxSpreadPoints    = 5000;
extern int    Slippage           = 100;

extern ENUM_TIMEFRAMES TradeTF   = PERIOD_M1;

// REGULAR ORDER TREND = M5
extern bool UseTrendFilter       = true;
extern ENUM_TIMEFRAMES TrendTF   = PERIOD_M5;
extern int TrendFastEMA          = 9;
extern int TrendSlowEMA          = 21;

extern double MinCandleSize      = 50;

extern bool UseRecoveryOrders     = true;
extern double RecoveryGapPrice    = 500.00;
extern bool RecoverySameDirection = true;
extern int MaxRecoveryOrders      = 4;

// BIG MOVE REVERSE SYSTEM
extern bool   UseBigMoveReverseOrder  = true;
extern int    BigMoveLookbackBars     = 3;
extern double BigMoveMinPrice         = 100.0;
extern double BigMoveReverseLot       = 0.01;
extern bool   OnlyOneBigMoveOrder     = true;

extern bool DrawEMALines         = true;
extern int  EMABarsToDraw        = 120;
extern color EMAFastColor        = clrLime;
extern color EMASlowColor        = clrRed;

datetime lastBarTime = 0;
datetime lastBigMoveBarTime = 0;
datetime lastBigMoveTradeTime = 0;

int lastBigMoveDirection = 0; // 1 = big up, -1 = big down

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTC M5 Trend + Big Move Reverse EA Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "BOT_EMA_FAST_");
   ObjectsDeleteAll(0, "BOT_EMA_SLOW_");
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   UpdateBigMoveStatus();

   DrawBotEMALines();
   DrawDashboard();

   if(!IsTradeAllowed())
      return;

   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpreadPoints)
      return;

   CheckBasketClose();

   if(CountOrders() >= MaxOrders)
      return;

   CheckBigMoveReverseOrder();

   CheckRecoveryOrders();

   ProcessNewBar();
}

//+------------------------------------------------------------------+
// BIG UP > 100  = SELL
// BIG DOWN >100 = BUY
//+------------------------------------------------------------------+
void CheckBigMoveReverseOrder()
{
   if(!UseBigMoveReverseOrder)
      return;

   if(lastBigMoveDirection == 0)
      return;

   if(lastBigMoveBarTime <= 0)
      return;

   if(CountOrders() > 0)
      return;

   if(OnlyOneBigMoveOrder && lastBigMoveTradeTime == lastBigMoveBarTime)
      return;

   if(lastBigMoveDirection == 1)
   {
      OpenOrder(OP_SELL, BigMoveReverseLot, "BIG_MOVE_REVERSE_SELL");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
   }

   if(lastBigMoveDirection == -1)
   {
      OpenOrder(OP_BUY, BigMoveReverseLot, "BIG_MOVE_REVERSE_BUY");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
   }
}

//+------------------------------------------------------------------+
// REGULAR ORDER ONLY BY M5 TREND
//+------------------------------------------------------------------+
void ProcessNewBar()
{
   datetime currentBar = iTime(Symbol(), TradeTF, 0);

   if(currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   if(CountOrders() > 0)
      return;

   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);

   double candleSize = MathAbs(close1 - open1);

   if(candleSize < MinCandleSize)
   {
      Print("No regular trade: candle too small. Size: ", candleSize);
      return;
   }

   // IMPORTANT: block normal trend order after big candle
   if(candleSize >= MaxTrendOrderCandleSize)
   {
      Print("No regular trend order: big candle detected. Size: ", candleSize);
      return;
   }

   // If big move exists, reverse system handles it, not regular trend order
   if(DetectBigMoveDirection() != 0)
   {
      Print("No regular trend order: big move detected. Reverse system handles it.");
      return;
   }

   int trend = GetTrendDirection();

   if(trend == 1)
   {
      OpenOrder(OP_BUY, BaseLot, "M5_TREND_BUY");
      return;
   }

   if(trend == -1)
   {
      OpenOrder(OP_SELL, BaseLot, "M5_TREND_SELL");
      return;
   }

   Print("No regular trade: M5 trend not clear.");
}
extern double MaxTrendOrderCandleSize = 60.0;

//+------------------------------------------------------------------+
void CheckRecoveryOrders()
{
   if(!UseRecoveryOrders)
      return;

   if(CountOrders() <= 0)
      return;

   if(CountOrders() >= MaxOrders)
      return;

   if(CountRecoveryOrders() >= MaxRecoveryOrders)
      return;

   if(GetBasketProfit() >= 0)
      return;

   int lastType = GetLastOrderType();
   double lastPrice = GetLastOrderPrice();

   if(lastType < 0 || lastPrice <= 0)
      return;

   double distance = MathAbs(Bid - lastPrice);

   if(distance < RecoveryGapPrice)
      return;

   double lot = GetRecoveryLot();

   int recoveryType = lastType;

   if(!RecoverySameDirection)
   {
      if(lastType == OP_BUY)
         recoveryType = OP_SELL;
      else
         recoveryType = OP_BUY;
   }

   OpenOrder(recoveryType, lot, "RECOVERY_100_GAP");
}

//+------------------------------------------------------------------+
void UpdateBigMoveStatus()
{
   int dir = DetectBigMoveDirection();

   if(dir == 0)
      return;

   datetime moveTime = iTime(Symbol(), TradeTF, 1);

   if(moveTime == lastBigMoveBarTime && dir == lastBigMoveDirection)
      return;

   lastBigMoveDirection = dir;
   lastBigMoveBarTime = moveTime;

   Print("BIG MOVE > ", BigMoveMinPrice, " FOUND: ",
         dir == 1 ? "BIG UP - SELL REVERSE READY" : "BIG DOWN - BUY REVERSE READY");
}

//+------------------------------------------------------------------+
int DetectBigMoveDirection()
{
   double firstOpen = iOpen(Symbol(), TradeTF, BigMoveLookbackBars);
   double lastClose = iClose(Symbol(), TradeTF, 1);

   if(firstOpen <= 0 || lastClose <= 0)
      return 0;

   double move = lastClose - firstOpen;

   if(move >= BigMoveMinPrice)
      return 1;

   if(move <= -BigMoveMinPrice)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
double GetRecoveryLot()
{
   int recoveryCount = CountRecoveryOrders();

   if(recoveryCount == 0) return BaseLot;
   if(recoveryCount == 1) return BaseLot;
   if(recoveryCount == 2) return BaseLot * 2;
   if(recoveryCount == 3) return BaseLot * 2;

   return BaseLot * 3;
}

//+------------------------------------------------------------------+
int CountRecoveryOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber &&
            StringFind(OrderComment(), "RECOVERY") >= 0)
         {
            count++;
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
int GetLastOrderType()
{
   datetime lastTime = 0;
   int type = -1;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderOpenTime() > lastTime)
            {
               lastTime = OrderOpenTime();
               type = OrderType();
            }
         }
      }
   }

   return type;
}

//+------------------------------------------------------------------+
double GetLastOrderPrice()
{
   datetime lastTime = 0;
   double price = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            if(OrderOpenTime() > lastTime)
            {
               lastTime = OrderOpenTime();
               price = OrderOpenPrice();
            }
         }
      }
   }

   return price;
}

//+------------------------------------------------------------------+
int GetTrendDirection()
{
   double emaFast = iMA(Symbol(), TrendTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1  = iClose(Symbol(), TrendTF, 1);

   if(close1 > emaFast && emaFast > emaSlow)
      return 1;

   if(close1 < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
void OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   if(AccountFreeMarginCheck(Symbol(), type, lot) <= 0)
   {
      Print("Not enough margin");
      return;
   }

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          comment, MagicNumber, 0, clr);

   if(ticket > 0)
   {
      Print("Opened ", type == OP_BUY ? "BUY" : "SELL",
            " Lot: ", lot,
            " Ticket: ", ticket,
            " Comment: ", comment);
   }
   else
   {
      Print("OrderSend Failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
void CheckBasketClose()
{
   double profit = GetBasketProfit();

   if(profit >= BasketProfitUSD)
   {
      CloseAllOrders();
      Print("Basket Profit Closed: ", profit);
      return;
   }

   if(profit <= BasketStopLossUSD)
   {
      CloseAllOrders();
      Print("Basket StopLoss Closed: ", profit);
      return;
   }
}

//+------------------------------------------------------------------+
double GetBasketProfit()
{
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            total += OrderProfit() + OrderSwap() + OrderCommission();
      }
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
void CloseAllOrders()
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         {
            bool closed = false;

            if(OrderType() == OP_BUY)
               closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

            if(OrderType() == OP_SELL)
               closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

            if(!closed)
               Print("Close Failed Ticket: ", OrderTicket(), " Error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
void DrawBotEMALines()
{
   if(!DrawEMALines)
      return;

   DrawEMA("BOT_EMA_FAST", TrendFastEMA, EMAFastColor);
   DrawEMA("BOT_EMA_SLOW", TrendSlowEMA, EMASlowColor);
}

//+------------------------------------------------------------------+
void DrawEMA(string name, int period, color clr)
{
   for(int i = EMABarsToDraw; i >= 1; i--)
   {
      string objName = name + "_" + IntegerToString(i);

      datetime t1 = iTime(Symbol(), TrendTF, i);
      datetime t2 = iTime(Symbol(), TrendTF, i - 1);

      double p1 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i);
      double p2 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      }
      else
      {
         ObjectMove(0, objName, 0, t1, p1);
         ObjectMove(0, objName, 1, t2, p2);
      }
   }
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   string trendText = "FLAT / WAIT";
   int trend = GetTrendDirection();

   if(trend == 1)  trendText = "M5 BUY TREND";
   if(trend == -1) trendText = "M5 SELL TREND";

   string bigText = "NO BIG MOVE";

   if(lastBigMoveDirection == 1)
      bigText = "BIG UP >100 | REVERSE SELL";
   else if(lastBigMoveDirection == -1)
      bigText = "BIG DOWN >100 | REVERSE BUY";

   Comment(
      "BTC M5 TREND + BIG MOVE REVERSE EA\n",
      "--------------------------------\n",
      "Orders: ", CountOrders(), "/", MaxOrders, "\n",
      "Recovery: ", CountRecoveryOrders(), "/", MaxRecoveryOrders, "\n",
      "Basket P/L: $", DoubleToString(GetBasketProfit(), 2), "\n",
      "Basket TP: $", DoubleToString(BasketProfitUSD, 2), "\n",
      "Basket SL: $", DoubleToString(BasketStopLossUSD, 2), "\n",
      "Regular Trend: ", trendText, "\n",
      "Big Move: ", bigText, "\n",
      "BigMoveMinPrice: ", DoubleToString(BigMoveMinPrice, 2), "\n",
      "Recovery Gap: ", DoubleToString(RecoveryGapPrice, 2), "\n",
      "Spread: ", MarketInfo(Symbol(), MODE_SPREAD)
   );
}