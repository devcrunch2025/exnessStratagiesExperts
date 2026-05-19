//+------------------------------------------------------------------+
//| _Gap_Recovery_Parallel_Trend_EA.mq4                              |
//| Price Difference Recovery + Trend Filter + Balance Check          |
//+------------------------------------------------------------------+
#property strict

input double LOTValue      = 0.01;
input double StopLossValue = 20.00;//equity -10;
input double TPValue       = 0.50;

double BaseLot             = 0.01;
double GapPrice            = 0;//20;//50.0;

int    MagicNumber         = 5050801;
int    Slippage            = 70;

double BasketProfitTarget  = 0.00;
double BasketStopLoss      = 0.00;

datetime lastM5BarTime = 0;

datetime g_m1BarStartTime = 0;
bool     g_m1GapChecked   = false;

int maxOrderAfterTrendChanged=2;
int countOrderCountAfterTrendChanged=0;

//+------------------------------------------------------------------+
int OnInit()
  {
   MagicNumber = AccountNumber() + 5;

   BaseLot            = LOTValue;
   BasketProfitTarget = TPValue;
   BasketStopLoss     = StopLossValue;

   MathSrand((int)TimeLocal());
// GapPrice = GapPrice + (MathRand() % 11 - 5);

   Print("V5 PRICE GAP is started. MagicNumber: ", MagicNumber);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+

bool isOpenNextOrderAfterProfitClose=true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOrdersAfterOneHourIfSmallLoss()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();

      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      int openSeconds = (int)(TimeCurrent() - OrderOpenTime());

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      // Close after 1 hour if loss is smaller than $1
      // Example: -0.10, -0.50, -0.99 will close
      // But -1.00, -2.00, -5.00 will NOT close
      double allowedLoss = 0;

      // 1 hour
      if(openSeconds >= 3600)
         allowedLoss = -1.0;

      // 2 hours
      if(openSeconds >= 7200)
         allowedLoss = -2.0;

      // // 3 hours
      // if(openSeconds >= 10800*2)
      //    allowedLoss = -3.0;

      // close condition
      if(profit < 0 && profit > allowedLoss)
        {
         RefreshRates();

         double closePrice = OrderType() == OP_BUY ? Bid : Ask;

         bool closed = OrderClose(
                          OrderTicket(),
                          OrderLots(),
                          closePrice,
                          Slippage,
                          clrOrange
                       );

         if(closed)
           {
            Print("Time-based loss close. Ticket:",
                  OrderTicket(),
                  " Profit:",
                  DoubleToString(profit,2),
                  " OpenSeconds:",
                  openSeconds);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {


   // CloseOrdersAfterOneHourIfSmallLoss();


   CloseBasketByProfit(OP_BUY);
   CloseBasketByProfit(OP_SELL);

   datetime now = TimeCurrent();

   int hour = TimeHour(now);
   int minute = TimeMinute(now);
   if(minute==0 || minute==30)
     {
      // countOrderCountAfterTrendChanged=0;
     }

   int day  = TimeDayOfWeek(now);


// CloseAllOrdersIfEquityDrop();




   if(AccountBalance()<=0)
     {
      return;
     }

// if(IsAfter30SecFromNewM1Bar())

// Print("TrendGap "+GetLatestTrendGap()+" "+GetLatestTrendGapInMinutes());

// if((GetLatestTrendGap()==0 || GetLatestTrendGap()>50 )&& !IsPauseTradingTimeUTC() && countOrderCountAfterTrendChanged<maxOrderAfterTrendChanged)

//  if(( (GetLatestTrendGapInMinutes()==0 ||GetLatestTrendGapInMinutes()>30) && !IsFlatMarket() && !IsPauseTradingTimeUTC() && countOrderCountAfterTrendChanged<maxOrderAfterTrendChanged))
   if(( !IsPauseTradingTimeUTC() && !IsFlatMarket() && countOrderCountAfterTrendChanged<maxOrderAfterTrendChanged))

      CheckNewBaseSignal();
   else
     {
      // Print("CheckNewBaseSignal Missing ",GetLatestTrendGap());



     }

//   Print("Strong Candle Signal: ", CheckAndDrawStrongCandle(100));

   CheckStrongCandleAndTrade();



// Parallel recovery for both BUY and SELL
   if(GetTrendDirection()!=-1)
      ManageRecovery(OP_BUY);

   if(GetTrendDirection()!=1)
      ManageRecovery(OP_SELL);


// if(!IsPauseTradingTimeUTC() && GetLatestTrendGap()>50)
//    OpenNextOrderAfterProfitClose();


   DrawDashboard();
// DrawEveryCandleDiffFrom5th();

   CheckTrendChangedCloseOpposite();

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetQuickScalpSignal()
  {
   double ema9  = iMA(Symbol(), PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema21 = iMA(Symbol(), PERIOD_M1, 21,0, MODE_EMA, PRICE_CLOSE, 0);

   double ema9_prev  = iMA(Symbol(), PERIOD_M1, 9, 0, MODE_EMA, PRICE_CLOSE, 1);

   double rsi = iRSI(Symbol(), PERIOD_M1, 14, PRICE_CLOSE, 0);

   double atr = iATR(Symbol(), PERIOD_M1, 14, 0);

   double candleOpen = iOpen(Symbol(), PERIOD_M1, 0);

   double gap = Bid - candleOpen;

   double emaGap = MathAbs(ema9 - ema21);

// EMA slope
   double emaSlope = MathAbs(ema9 - ema9_prev);

// avoid dead market
   if(atr < 250)
      return 0;

// avoid flat EMA
   if(emaGap < 30)
      return 0;

// avoid weak EMA movement
   if(emaSlope < 10)
      return 0;

// current candle body
   double candleBody = MathAbs(Bid - candleOpen);

// avoid tiny candles
   if(candleBody < 40)
      return 0;

// =========================
// BUY MOMENTUM
// =========================
   if(ema9 > ema21 &&
      Bid > ema9 &&
      rsi > 55 &&
      gap > 60)
     {
      return 1;
     }

// =========================
// SELL MOMENTUM
// =========================
   if(ema9 < ema21 &&
      Bid < ema9 &&
      rsi < 45 &&
      gap < -60)
     {
      return -1;
     }

   return 0;
  }
datetime lastStrongCandleTradeTime = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckStrongCandleAndTrade()
  {
   datetime candleTime = iTime(Symbol(), PERIOD_M1, 0);

// already traded this candle
   if(candleTime == lastStrongCandleTradeTime)
      return;

// int signal = CheckAndDrawStrongCandle(80);

   int signal = GetQuickScalpSignal();
   bool buyOpen  = CountOrders(OP_BUY) > 0;
   bool sellOpen = CountOrders(OP_SELL) > 0;
   if(signal == 1 && !buyOpen)
     {
      OpenOrder(OP_BUY, GetLot(BaseLot), MakeComment(OP_BUY, 0));

      lastStrongCandleTradeTime = candleTime;
     }
   else
      if(signal == -1 && !sellOpen)
        {
         OpenOrder(OP_SELL, GetLot(BaseLot), MakeComment(OP_SELL, 0));

         lastStrongCandleTradeTime = candleTime;
        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double g_sarPeriod        = 0.56;
int    g_sarStepSize      = 25;
int    g_sarAccel         = 9;
int GetStrongSARSignal()
  {
   double ema21  = iMA(Symbol(),0,21,0,MODE_EMA,PRICE_CLOSE,1);
   double ema50  = iMA(Symbol(),0,50,0,MODE_EMA,PRICE_CLOSE,1);
   double ema200 = iMA(Symbol(),0,200,0,MODE_EMA,PRICE_CLOSE,1);

   double rsi = iRSI(Symbol(),0,14,PRICE_CLOSE,1);
   double atr = iATR(Symbol(),0,14,1) / Point;

   double step    = g_sarPeriod * g_sarStepSize / 10000.0;
   double maxStep = step * g_sarAccel;

   double sar1 = iSAR(Symbol(),0,step,maxStep,1);
   double sar2 = iSAR(Symbol(),0,step,maxStep,2);

// avoid dead / flat market
   if(atr < 300)
      return 0;

// avoid inside EMA zone
   double top    = MathMax(ema21, ema50);
   double bottom = MathMin(ema21, ema50);

   if(Close[1] <= top && Close[1] >= bottom)
      return 0;

// candle body / wick
   double body      = MathAbs(Close[1] - Open[1]);
   double upperWick = High[1] - MathMax(Open[1], Close[1]);
   double lowerWick = MathMin(Open[1], Close[1]) - Low[1];

   if(body <= 0)
      return 0;

// =========================
// BUY SIGNAL
// =========================
   if(sar1 < Close[1] && sar2 >= Close[2])
     {
      if(ema21 > ema50 && ema50 > ema200)
        {
         if(Close[1] > ema21)
           {
            if(rsi >= 55)
              {
               if(upperWick <= body * 1.5)
                  return 1;
              }
           }
        }
     }

// =========================
// SELL SIGNAL
// =========================
   if(sar1 > Close[1] && sar2 <= Close[2])
     {
      if(ema21 < ema50 && ema50 < ema200)
        {
         if(Close[1] < ema21)
           {
            if(rsi <= 45)
              {
               if(lowerWick <= body * 1.5)
                  return -1;
              }
           }
        }
     }

   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllOrdersIfEquityDrop()
  {
// double dynamicSL = StopLossValue;

// if(AccountEquity() > AccountBalance() - dynamicSL)
//    return;

// if(AccountEquity() > AccountBalance()/2)
//    return;

// Print("Equity protection triggered. Closing all orders.");

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      RefreshRates();

      double closePrice = OrderType() == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(),
                               OrderLots(),
                               closePrice,
                               Slippage,
                               clrRed);

      if(!closed)
        {
         Print("Emergency close failed. Ticket: ",
               OrderTicket(),
               " Error: ",
               GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
bool IsAfter30SecFromNewM1Bar()
  {
   datetime currentBarTime = iTime(Symbol(), PERIOD_M1, 0);

   if(currentBarTime != g_m1BarStartTime)
     {
      g_m1BarStartTime = currentBarTime;
      g_m1GapChecked = false;
      return false;
     }

   if(!g_m1GapChecked && TimeCurrent() >= g_m1BarStartTime + 30)
     {
      g_m1GapChecked = true;
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
int GetBalanceMultiplier()
  {
   double balance = AccountBalance();

   int multiplier = (int)MathCeil(balance / 200.0);

   if(multiplier < 1)
      multiplier = 1;

   return multiplier;
  }

//+------------------------------------------------------------------+
double GetLot(double baseLot)
  {
   double lot = baseLot * GetBalanceMultiplier();

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lot < minLot)
      lot = minLot;

   if(lot > maxLot)
      lot = maxLot;

   lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
  }

//+------------------------------------------------------------------+
double GetBasketTP()
  {
   return BasketProfitTarget * GetBalanceMultiplier();
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsPauseTradingTimeUTC()
  {
// return false;


   datetime now = TimeGMT();

   int hour = TimeHour(now);
   int day  = TimeDayOfWeek(now);

   if(hour == 13 || hour == 23 || hour == 0)
      return true;

//DAY TIME ON
// if(hour < 3 || hour > 18 || hour == 13)
//    return true;


   return false;

//DAY TIME ON
   if(hour <4 || hour > 14)
      return true;

// -------------------------------------------------
// DAILY PAUSE
// UTC 00:00 -> 06:00
// -------------------------------------------------
   if(hour >= 0 && hour < 1)
      return true;



// -------------------------------------------------
// US MARKET VOLATILITY
// UTC 12:30 -> 13:30 (approx UAE 16:30 -> 17:30)
// -------------------------------------------------
   if(hour == 12 || hour == 13 || hour == 16  || hour == 23)
      return true;

// -------------------------------------------------
// FRIDAY NIGHT PROTECTION
// Friday after 18:00 UTC
// -------------------------------------------------
   if(day == 5 && hour >= 18)
      return true;

// -------------------------------------------------
// WEEKEND BLOCK
// Saturday + Sunday
// -------------------------------------------------
// if(day == 6 || day == 0)
//    return true;

// -------------------------------------------------
// MONDAY EARLY MARKET OPEN
// Monday before 03:00 UTC
// -------------------------------------------------
   if(day == 1 && hour < 5)
      return true;

   return false;
  }
//+------------------------------------------------------------------+
double GetBasketSL()
  {


   return BasketStopLoss * GetBalanceMultiplier();
   /*
   //   dynamicSL =;


   // double balance = AccountBalance();
   //    double equity  = AccountEquity();
   double SL_values=MathMax(BasketStopLoss * GetBalanceMultiplier(), AccountEquity() / 2);
   if(IsPauseTradingTimeUTC())
     {
      SL_values=SL_values/2;
     }


   return  SL_values;
   */
  }

//+------------------------------------------------------------------+
double GetLiveM5Gap()
  {
   RefreshRates();

   double open = iOpen(Symbol(), PERIOD_M5, 0);
   double live = Bid;

   return NormalizeDouble(live - open, 2);
  }

//+------------------------------------------------------------------+
//| Trend direction using EMA9 and EMA21 on M5                       |
//|  1 = BUY trend, -1 = SELL trend, 0 = No clear trend               |
//+------------------------------------------------------------------+
// int GetTrendDirection()
// {
//    double ema9  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
//    double ema21 = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 1);

//    double close1 = iClose(Symbol(), PERIOD_M5, 1);

//    if(close1 > ema9 && ema9 > ema21)
//       return 1;

//    if(close1 < ema9 && ema9 < ema21)
//       return -1;

//    return 0;
// }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTrendGap()
  {
   double ema9  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema21 = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   double livePrice = Bid;

   return  MathAbs(ema9 - ema21);


  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTrendDirection()
  {
   double ema9  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema21 = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   double livePrice = Bid;

// Strong BUY trend
   if(livePrice > ema9 && ema9 > ema21)
      return 1;

// Strong SELL trend
   if(livePrice < ema9 && ema9 < ema21)
      return -1;

// Price inside EMA zone
   if((livePrice > ema21 && livePrice < ema9) ||
      (livePrice < ema21 && livePrice > ema9))
      return 0;

   return 0;
  }

//+------------------------------------------------------------------+
string GetTrendText()
  {
   int trend = GetTrendDirection();

   if(trend == 1)
      return "BUY TREND";

   if(trend == -1)
      return "SELL TREND";

   return "NO CLEAR TREND";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOrdersByType(int orderType)
  {
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderType() != orderType)
         continue;

      double price = (orderType == OP_BUY) ? Bid : Ask;

      bool closed = OrderClose(
                       OrderTicket(),
                       OrderLots(),
                       price,
                       30,
                       clrRed
                    );

      if(!closed)
         Print("OrderClose failed. Ticket:", OrderTicket(), " Error:", GetLastError());
     }
  }


// int lastTrend = 0;
// double trendChangedPrice = 0;
// datetime trendChangedTime = 0;

/*
void CheckTrendChangedCloseOpposite_old()
{
   int trend = GetTrendDirection();

   if(trend == 0)
      return;

   if(lastTrend != 0 && trend != lastTrend)
   {
      if(trend == 1)
      {
         CloseOrdersByType(OP_SELL);
         Print("Trend changed to BUY. Closed SELL orders.");
      }

      if(trend == -1)
      {
         CloseOrdersByType(OP_BUY);
         Print("Trend changed to SELL. Closed BUY orders.");
      }
   }

   lastTrend = trend;
}*/
double MinGapFromTrendChange = 300;
/*
void CheckTrendChangedCloseOpposite()
{
   int trend = GetTrendDirection();

   if(trend == 0)
      return;

   double livePrice = Bid;

   // first time setup
   if(lastTrend == 0)
   {
      lastTrend = trend;
      trendChangedPrice = livePrice;
      trendChangedTime = TimeCurrent();
      return;
   }

   // trend changed
   if(trend != lastTrend)
   {
      lastTrend = trend;
      trendChangedPrice = livePrice;
      trendChangedTime = TimeCurrent();

      Print("Trend changed. New trend: ", trend,
            " Price: ", trendChangedPrice,
            " Time: ", TimeToString(trendChangedTime, TIME_DATE|TIME_SECONDS));
   }

   // gap from trend changed price to live price
   double gap = MathAbs(livePrice - trendChangedPrice);

   if(gap < MinGapFromTrendChange)
      return;

   if(trend == 1)
   {
      CloseOrdersByType(OP_SELL);
      Print("BUY trend moved 300 gap from trend change price. Closed SELL orders.");
   }

   if(trend == -1)
   {
      CloseOrdersByType(OP_BUY);
      Print("SELL trend moved 300 gap from trend change price. Closed BUY orders.");
   }
}*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckTrendChangedCloseOpposite()
  {
   int trend = GetTrendDirection();

   if(trend == 0 && lastTrend==0)
      return;

   double livePrice = Bid;
//first time setup
   if(lastTrend == 0)
     {
      lastTrend = trend;
      trendChangedPrice = livePrice;
      trendChangedTime = TimeCurrent();

      AddTrendChangeHistory(trend, livePrice);
      // return;
     }

     if(  trend == lastTrend)

     {


      // countOrderCountAfterTrendChanged=0;

     }

   if(trend != lastTrend && lastTrend != 0 && trend != 0)
     {


      countOrderCountAfterTrendChanged=0;
      /*
      Print("Trend changed from ", TrendName(lastTrend),
            " to ", TrendName(trend),
            " | Old Price: ", trendChangedPrice,
            " | New Price: ", livePrice,
            " | Difference: ", MathAbs(livePrice - trendChangedPrice));

      lastTrend = trend;
      trendChangedPrice = livePrice;
      trendChangedTime = TimeCurrent();

      AddTrendChangeHistory(trend, livePrice);*/




      int oldTrend = lastTrend;

      double oldPrice = trendChangedPrice;

      double newPrice = Bid;

      DrawTrendChangeGap(
         oldTrend,
         trend,
         oldPrice,
         newPrice,
         TimeCurrent()
      );




      if(trend != lastTrend)

         Print("Trend changed from ",
               TrendName(lastTrend),
               " to ",
               TrendName(trend));

      lastTrend = trend;

      trendChangedPrice = livePrice;

      trendChangedTime = TimeCurrent();

      AddTrendChangeHistory(trend, livePrice);



     }


// if(GetLatestTrendGap()>50)
//   {
// if(trend == 1)
//    CloseOrdersByType(OP_SELL);

// if(trend == -1)
//    CloseOrdersByType(OP_BUY);

//   }

   double gap = MathAbs(livePrice - trendChangedPrice);

   if(gap < MinGapFromTrendChange)
      return;

// if(trend == 1)
//    CloseOrdersByType(OP_SELL);

// if(trend == -1)
//    CloseOrdersByType(OP_BUY);
  }
#define TREND_HISTORY_COUNT 50

int      trendHist[TREND_HISTORY_COUNT];
double   priceHist[TREND_HISTORY_COUNT];
datetime timeHist[TREND_HISTORY_COUNT];

int lastTrend = 0;
double trendChangedPrice = 0;
datetime trendChangedTime = 0;

//--------------------------------------------------
// ADD NEW TREND HISTORY
//--------------------------------------------------
void AddTrendChangeHistory(int newTrend, double price)
  {
   for(int i = TREND_HISTORY_COUNT - 1; i > 0; i--)
     {
      trendHist[i] = trendHist[i - 1];
      priceHist[i] = priceHist[i - 1];
      timeHist[i]  = timeHist[i - 1];
     }

   trendHist[0] = newTrend;
   priceHist[0] = price;
   timeHist[0]  = TimeCurrent();
  }

//--------------------------------------------------
// TREND NAME
//--------------------------------------------------
string TrendName(int trend)
  {
   if(trend == 1)
      return "BUY";

   if(trend == -1)
      return "SELL";

   return "NONE";
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLatestTrendGap()
  {
// Need at least 2 trend changes
   if(priceHist[0] == 0 || priceHist[1] == 0)
      return 0;

   return MathAbs(priceHist[0] - priceHist[1]);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLatestTrendGapInMinutes()
  {
// Need at least 2 trend changes
   if(timeHist[0] == 0 || timeHist[1] == 0)
      return 0;

   double seconds = MathAbs(timeHist[0] - timeHist[1]);

   return seconds / 60.0;
  }

//--------------------------------------------------
// DISPLAY LAST 5 TREND CHANGES
//--------------------------------------------------
string GetLast5TrendChangesText()
  {
   string txt = "LAST 5 TREND CHANGES\n\n";

   for(int i = 0; i < TREND_HISTORY_COUNT; i++)
     {
      if(trendHist[i] == 0)
         continue;

      txt += IntegerToString(i + 1) + ") ";

      txt += TrendName(trendHist[i]);

      txt += " @ ";

      txt += DoubleToString(priceHist[i], 2);

      txt += " | ";

      txt += TimeToString(timeHist[i], TIME_MINUTES);

      // Difference with previous history
      if(i < TREND_HISTORY_COUNT - 1 && trendHist[i + 1] != 0)
        {
         double diff = MathAbs(priceHist[i] - priceHist[i + 1]);

         txt += " | GAP: ";

         txt += DoubleToString(diff, 2);
        }

      txt += "\n";
     }

   return txt;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenNextOrderAfterProfitClose()
  {
   if(g_lastBasketProfitCloseTime <= 0)
      return;

// wait 5 minutes
   if(TimeCurrent() - g_lastBasketProfitCloseTime < 60 * 1)
      return;

   int trend = GetTrendDirection();

// BUY re-entry
   if(g_lastBasketProfitCloseType == OP_BUY)
     {
      if(trend == 1 && CountOrders(OP_BUY) == 0)
        {
         OpenOrder(OP_BUY,
                   GetLot(BaseLot),
                   MakeComment(OP_BUY, 0));

         Print("5 Min ReEntry BUY created.");

         g_lastBasketProfitCloseTime = 0;
         g_lastBasketProfitCloseType = -1;
        }
     }

// SELL re-entry
   if(g_lastBasketProfitCloseType == OP_SELL)
     {
      if(trend == -1 && CountOrders(OP_SELL) == 0)
        {
         OpenOrder(OP_SELL,
                   GetLot(BaseLot),
                   MakeComment(OP_SELL, 0));

         Print("5 Min ReEntry SELL created.");

         g_lastBasketProfitCloseTime = 0;
         g_lastBasketProfitCloseType = -1;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetM5CandleFormationSafe(double minGap)
  {
   double open = iOpen(Symbol(), PERIOD_M5, 0);
   double live = Bid;

   double diff = live - open;

   if(diff >= minGap)
      return 1;

   if(diff <= -minGap)
      return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsFlatMarket()
  {
   double ema9_now  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema21_now = iMA(Symbol(), PERIOD_M5, 21,0, MODE_EMA, PRICE_CLOSE, 0);

   double ema9_prev  = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 3);
   double ema21_prev = iMA(Symbol(), PERIOD_M5, 21,0, MODE_EMA, PRICE_CLOSE, 3);

// EMA distance
   double emaGap = MathAbs(ema9_now - ema21_now);


// EMA slope
   double ema9Slope  = MathAbs(ema9_now - ema9_prev);
   double ema21Slope = MathAbs(ema21_now - ema21_prev);

// Candle range average
   double avgRange = 0;

   for(int i=1; i<=5; i++)
     {
      avgRange += MathAbs(
                     iHigh(Symbol(), PERIOD_M5, i) -
                     iLow(Symbol(), PERIOD_M5, i)
                  );
     }

   avgRange = avgRange / 5;

   // Print("EMA Gap: ", DoubleToString(emaGap, 2), " EMA9 Slope: ", DoubleToString(ema9Slope, 2), " EMA21 Slope: ", DoubleToString(ema21Slope, 2), " Avg Range: ", DoubleToString(avgRange, 2));


// FLAT CONDITIONS
   if(emaGap < 30 &&
      ema9Slope < 20 &&
      ema21Slope < 20 &&
      avgRange < 80)
     {
      return true;
     }

   //   if(emaGap<100) return true;

   return false;
  }

// Detect current forming candle movement
// Returns:
//  1  = bullish strong candle
// -1  = bearish strong candle
//  0  = normal candle

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetStrongFormingCandleSignal(double minGap = 100)
  {
// Current forming candle
   double candleOpen  = iOpen(Symbol(), PERIOD_M1, 0);

   double livePrice   = Bid;

// Raw BTCUSD price difference
   double gap = livePrice - candleOpen;

// Strong bullish candle
   if(gap >= minGap)
      return 1;

// Strong bearish candle
   if(gap <= -minGap)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CheckAndDrawStrongCandle(double minGap = 100)
  {
   double candleOpen = iOpen(Symbol(), PERIOD_M1, 0);

   double livePrice  = Bid;

   double gap = livePrice - candleOpen;

// if(gap>50)
// Print("Current M1 candle gap: ", DoubleToString(gap, 2));

// no strong candle
   if(MathAbs(gap) < minGap)
      return 0;

   string name = "StrongCandle_" + IntegerToString(TimeCurrent());

   string txt;

   color clr;

   int signal = 0;

// BUY candle
   if(gap > 0)
     {
      txt = "BUY " + DoubleToString(gap,2);

      clr = clrLime;

      signal = 1;
     }
// SELL candle
   else
     {
      txt = "SELL " + DoubleToString(MathAbs(gap),2);

      clr = clrRed;

      signal = -1;
     }

// Draw text
// ObjectCreate(0, name, OBJ_TEXT, 0, TimeCurrent(), livePrice);

// ObjectSetString(0, name, OBJPROP_TEXT, txt);

// ObjectSetInteger(0, name, OBJPROP_COLOR, clr);

// ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);

// ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");

   return signal;
  }
//+------------------------------------------------------------------+
void CheckNewBaseSignal()
  {
// GapPrice =GapPrice;//  + MathRand() % 11;

// GapPrice = GapPrice + (MathRand() % 11 - 5);


   datetime m5Time = iTime(Symbol(), PERIOD_M1, 1);

   if(m5Time == lastM5BarTime)
      return;

   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double gap   = close - open;

   double open10  = iOpen(Symbol(), PERIOD_M10, 0);
   double close10 = iClose(Symbol(), PERIOD_M10, 0);
   double gap10   = close10 - open10;

   int trend = GetTrendDirection();

//  int trend =GetStrongSARSignal();

   bool buyOpen  = CountOrders(OP_BUY) > 0;
   bool sellOpen = CountOrders(OP_SELL) > 0;

// BUY base order: price gap UP + BUY trend
   if(gap >= GapPrice && trend == 1 && !buyOpen)
     {

      OpenOrder(OP_BUY, GetLot(BaseLot), MakeComment(OP_BUY, 0));

      lastM5BarTime = m5Time;

      countOrderCountAfterTrendChanged++;

     }

// SELL base order: price gap DOWN + SELL trend
   if(gap <= -GapPrice && trend == -1 && !sellOpen)
     {
      OpenOrder(OP_SELL, GetLot(BaseLot), MakeComment(OP_SELL, 0));

      lastM5BarTime = m5Time;

      countOrderCountAfterTrendChanged++;

     }

   lastM5BarTime = m5Time;


  }

//+------------------------------------------------------------------+
//| RECOVERY ONLY BY PRICE DIFFERENCE FROM LATEST ORDER              |
//+------------------------------------------------------------------+
bool CheckTrendChangedCloseOppositeTesting()
  {
   int trend = GetTrendDirection();

   if(trend == 1 && CountOrders(OP_SELL) > 0)
     {
      CloseOrdersByType(OP_SELL);
      return true;
     }

   if(trend == -1 && CountOrders(OP_BUY) > 0)
     {
      CloseOrdersByType(OP_BUY);
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckTrendChanged()
  {
   int trend = GetTrendDirection();

   if(trend == 1 && CountOrders(OP_SELL) > 0)
     {
      // CloseOrdersByType(OP_SELL);
      return true;
     }

   if(trend == -1 && CountOrders(OP_BUY) > 0)
     {
      // CloseOrdersByType(OP_BUY);
      return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageRecovery(int orderType)
  {
   if(GetBaseOrderTime(orderType) <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(profit > 0)
      return;

   int hour = TimeHour(TimeCurrent());

   double diff = GetLivePriceDiffFromLatestOrder(orderType);
   int timeDifferenceFromLatestOrder = GetLiveTimeDiffFromLatestTime(orderType);

   int currentStage = GetHighestStage(orderType);
   int nextStage    = currentStage + 1;

   double requiredGap = 0;
   double nextLot     = 0.01;

   bool nightSession = false;

   if(hour > 14 || hour < 1)
      nightSession = true;


   /* //$80
   // if(nextStage == 1) { requiredGap = 30;   nextLot = 0.02; }
   if(nextStage == 1) { requiredGap = 30;   nextLot = 0.01; }
   if(nextStage == 2) { requiredGap = 200;  nextLot = 0.02; }



   // if(nextStage == 1) { requiredGap = 50;   nextLot = 0.01; }
   // if(nextStage == 2) { requiredGap = 100;  nextLot = 0.02; }
   if(nextStage == 3) { requiredGap = 500;  nextLot = 0.03; }
   if(nextStage == 4) { requiredGap = 1000;  nextLot = 0.03; }
   if(nextStage == 5) { requiredGap = 1500; nextLot = 0.04; }
   if(nextStage == 6) { requiredGap = 3000; nextLot = 0.05; }*/



// if(nextStage == 1) { requiredGap = 30;   nextLot = 0.02; }
   if(nextStage == 1)
     {
      requiredGap = 500;
      nextLot = 0.01;
     }
   // if(nextStage == 2)
   //   {
   //    requiredGap = 800;
   //    nextLot = 0.01;
   //   }
   // if(nextStage == 3)
   //   {
   //    requiredGap = 1000;
   //    nextLot = 0.01;
   //   }
// if(nextStage == 4)
//   {
//    requiredGap = 300;
//    nextLot = 0.03;
//   }
// if(nextStage == 5)
//   {
//    requiredGap = 300;
//    nextLot = 0.03;
//   }
// if(nextStage == 6)
//   {
//    requiredGap = 500;
//    nextLot = 0.04;
//   }



//13th my $40 loss
// if(nextStage == 1) { requiredGap = 30;   nextLot = 0.02; }

   /*
   if(nextStage == 1) { requiredGap = 30;   nextLot = 0.01; }
   if(nextStage == 2) { requiredGap = 90;  nextLot = 0.01; }
   if(nextStage == 3) { requiredGap = 120;  nextLot = 0.02; }
   if(nextStage == 4) { requiredGap = 150;  nextLot = 0.01; }
   if(nextStage == 5) { requiredGap = 250;  nextLot = 0.01; }
   if(nextStage == 6) { requiredGap = 350;  nextLot = 0.01; }
   */






   if(nextStage > 1)
      return;

   if(nightSession)
      requiredGap = requiredGap + 50;

   bool canRecover = false;

   // requiredGap=200;

// BUY recovery: price must move DOWN from latest BUY order
   if(orderType == OP_BUY && diff <= -requiredGap)
      canRecover = true;

// SELL recovery: price must move UP from latest SELL order
   if(orderType == OP_SELL && diff >= requiredGap)
      canRecover = true;

   if(!canRecover)
      return;

   if(!StageExists(orderType, nextStage))
     {




      if(GetTrendDirection()==1 && orderType==OP_BUY)

         OpenOrder(orderType, GetLot(nextLot), MakeComment(orderType, nextStage));

      else

         if(GetTrendDirection()==-1 && orderType==OP_SELL)

            OpenOrder(orderType, GetLot(nextLot), MakeComment(orderType, nextStage));
     }
  }

//+------------------------------------------------------------------+
int GetLiveTimeDiffFromLatestTime(int orderType)
  {
   double latestPrice = 0;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(latestTime == 0 || OrderOpenTime() > latestTime)
        {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
        }
     }

   if(latestPrice <= 0)
      return 0;

   return (int)(TimeCurrent() - latestTime);
  }

//+------------------------------------------------------------------+
double GetLivePriceDiffFromLatestOrder(int orderType)
  {
   double latestPrice = 0;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(latestTime == 0 || OrderOpenTime() > latestTime)
        {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
        }
     }

   if(latestPrice <= 0)
      return 0;

   RefreshRates();

   double livePrice = orderType == OP_BUY ? Bid : Ask;

   return NormalizeDouble(livePrice - latestPrice, 2);
  }

//+------------------------------------------------------------------+
double GetLatestOrderPrice(int orderType)
  {
   double latestPrice = 0;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(latestTime == 0 || OrderOpenTime() > latestTime)
        {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
        }
     }

   return latestPrice;
  }

//+------------------------------------------------------------------+
int GetHighestStage(int orderType)
  {
   int highestStage = -1;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      string cmt = OrderComment();

      for(int s = 0; s <= 20; s++)
        {
         if(cmt == MakeComment(orderType, s))
           {
            if(s > highestStage)
               highestStage = s;
           }
        }
     }

   return highestStage;
  }

//+------------------------------------------------------------------+
double GetBaseOrderPrice(int orderType)
  {
   datetime oldestTime = 0;
   double basePrice = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(OrderComment() != MakeComment(orderType, 0))
         continue;

      if(oldestTime == 0 || OrderOpenTime() < oldestTime)
        {
         oldestTime = OrderOpenTime();
         basePrice  = OrderOpenPrice();
        }
     }

   return basePrice;
  }
bool buyReached80Once  = false;
bool sellReached80Once = false;

datetime g_lastBasketProfitCloseTime = 0;
int      g_lastBasketProfitCloseType = -1;
//+------------------------------------------------------------------+
void CloseBasketByProfit(int orderType)
  {
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
     {
      if(orderType == OP_BUY)
         buyReached80Once = false;

      if(orderType == OP_SELL)
         sellReached80Once = false;

      return;
     }

   double basketProfit  = GetBasketProfit(orderType);
   double dynamicTarget = GetDynamicBasketTarget(orderType);
   double dynamicSL     = GetBasketSL();



   double eightyPercentTarget = dynamicTarget * 0.80;

   bool closeNow = false;

// normal TP or SL
   if(((basketProfit <= -dynamicSL) || basketProfit >= dynamicTarget))
      closeNow = true;

// first time reached 80%
   if(basketProfit >= eightyPercentTarget)
     {
      if(orderType == OP_BUY)
        {
         if(buyReached80Once)
            closeNow = true;
         else
            buyReached80Once = true;
        }

      if(orderType == OP_SELL)
        {
         if(sellReached80Once)
            closeNow = true;
         else
            sellReached80Once = true;
        }
     }

   if(!closeNow)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      RefreshRates();

      double closePrice = orderType == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(),
                               OrderLots(),
                               closePrice,
                               Slippage,
                               clrGreen);

      if(!closed)
        {
         Print("Basket close failed. Ticket: ",
               OrderTicket(),
               " Error: ",
               GetLastError());
        }
     }

   Print("Basket closed. Type: ",
         orderType == OP_BUY ? "BUY" : "SELL",
         " Orders: ",
         openCount,
         " Profit: $",
         DoubleToString(basketProfit, 2),
         " TP: $",
         DoubleToString(dynamicTarget, 2),
         " 80% TP: $",
         DoubleToString(eightyPercentTarget, 2),
         " SL: $",
         DoubleToString(dynamicSL, 2));


   if(basketProfit > 0)
     {
      g_lastBasketProfitCloseTime = TimeCurrent();
      g_lastBasketProfitCloseType = orderType;
     }

   if(orderType == OP_BUY)
      buyReached80Once = false;

   if(orderType == OP_SELL)
      sellReached80Once = false;
  }

//+------------------------------------------------------------------+
bool CanOpenNewOrder(int type, double lot)
  {
   if(!IsTradeAllowed())
     {
      Print("Trading not allowed. Enable AutoTrading.");
      return false;
     }

   if(IsTradeContextBusy())
     {
      Print("Trade context busy. Try next tick.");
      return false;
     }

   if(lot <= 0)
     {
      Print("Invalid lot size: ", lot);
      return false;
     }

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);

   if(lot < minLot || lot > maxLot)
     {
      Print("Lot out of broker range. Lot: ",
            lot,
            " Min: ",
            minLot,
            " Max: ",
            maxLot);
      return false;
     }

   double freeMarginAfter = AccountFreeMarginCheck(Symbol(), type, lot);

   if(freeMarginAfter <= 0)
     {
      Print("Not enough margin. Balance: ",
            AccountBalance(),
            " Equity: ",
            AccountEquity(),
            " FreeMargin: ",
            AccountFreeMargin(),
            " Lot: ",
            lot,
            " Type: ",
            type == OP_BUY ? "BUY" : "SELL");
      return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
  {
   RefreshRates();

   lot = NormalizeDouble(lot, 2);

   if(!CanOpenNewOrder(type, lot))
      return false;

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          clr);

   if(ticket < 0)
     {
      int err = GetLastError();

      Print("OrderSend failed. Error: ",
            err,
            " Type: ",
            type == OP_BUY ? "BUY" : "SELL",
            " Lot: ",
            lot,
            " Comment: ",
            comment,
            " Balance: ",
            AccountBalance(),
            " Equity: ",
            AccountEquity(),
            " FreeMargin: ",
            AccountFreeMargin());

      return false;
     }

   Print("Order opened: ",
         comment,
         " Lot: ",
         DoubleToString(lot, 2),
         " Ticket: ",
         ticket);

   return true;
  }

//+------------------------------------------------------------------+
datetime GetBaseOrderTime(int orderType)
  {
   datetime baseTime = 0;
   string tag = MakeComment(orderType, 0);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
        {
         baseTime = OrderOpenTime();
        }
     }

   return baseTime;
  }

//+------------------------------------------------------------------+
bool StageExists(int orderType, int stage)
  {
   string tag = MakeComment(orderType, stage);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
        {
         return true;
        }
     }

   return false;
  }

//+------------------------------------------------------------------+
string MakeComment(int orderType, int stage)
  {
   if(orderType == OP_BUY)
      return "V5_PRICE_GAP_BUYS" + IntegerToString(stage);

   return "V5_PRICE_GAP_SELLS" + IntegerToString(stage);
  }

//+------------------------------------------------------------------+
int CountOrders(int orderType)
  {
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
        {
         count++;
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
int CountAllOrders()
  {
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber)
        {
         count++;
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
double GetBasketProfit(int orderType)
  {
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
        {
         profit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

   return profit;
  }

//+------------------------------------------------------------------+
double GetDynamicBasketTarget(int orderType)
  {
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return GetBasketTP();



   double tp = GetBasketTP() / openCount;


   if(openCount==1)
      tp=tp/2;



   int trend = GetTrendDirection();

// BUY basket but trend changed to SELL
   if(orderType == OP_BUY && trend == -1)
     {
      tp = tp * 0.20; // reduce TP to 50%
     }

// SELL basket but trend changed to BUY
   if(orderType == OP_SELL && trend == 1)
     {
      tp = tp * 0.20;
     }

// no clear trend
   if(trend == 0)
     {
      tp = tp * 0.50;
     }

// minimum protection
   if(tp < 0.30)
      tp = 0.30;

   return NormalizeDouble(tp, 2);
  }

//+------------------------------------------------------------------+
string GetActiveOrdersDirection()
  {
   bool buyOpen  = CountOrders(OP_BUY) > 0;
   bool sellOpen = CountOrders(OP_SELL) > 0;

   if(buyOpen && sellOpen)
      return "BUY + SELL";

   if(buyOpen)
      return "BUY ACTIVE";

   if(sellOpen)
      return "SELL ACTIVE";

   return "WAITING";
  }

//+------------------------------------------------------------------+
double GetLastM5Gap()
  {
   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);

   return close - open;
  }

//+------------------------------------------------------------------+
double GetLastClosedCandleDiffFrom(int timeframe)
  {
   RefreshRates();

   double livePrice = Bid;
   double oldPrice  = iClose(Symbol(), timeframe, 1);

   return NormalizeDouble(livePrice - oldPrice, 2);
  }

//+------------------------------------------------------------------+
double GetLastClosedCandleDiffFrom5th()
  {
   double lastClose  = iClose(Symbol(), PERIOD_M5, 1);
   double fifthClose = iClose(Symbol(), PERIOD_M5, 5);

   return NormalizeDouble(lastClose - fifthClose, 0);
  }

//+------------------------------------------------------------------+
void CreatePanel(string name,int x,int y,int w,int h,color bg)
  {
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
  }

//+------------------------------------------------------------------+
void CreateLabel(string name,
                 string text,
                 int x,
                 int y,
                 color clr,
                 int size=10)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
void DrawEMA9AndEMA21Lines()
  {
   int candles = 150;

   for(int i = candles; i >= 1; i--)
     {
      datetime t1 = iTime(Symbol(), PERIOD_CURRENT, i);
      datetime t2 = iTime(Symbol(), PERIOD_CURRENT, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      double ema9_1  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema9_2  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      double ema21_1 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema21_2 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      string name9  = "EMA9_LINE_" + IntegerToString(i);
      string name21 = "EMA21_LINE_" + IntegerToString(i);

      if(ObjectFind(0, name9) < 0)
         ObjectCreate(0, name9, OBJ_TREND, 0, t1, ema9_1, t2, ema9_2);
      else
        {
         ObjectMove(0, name9, 0, t1, ema9_1);
         ObjectMove(0, name9, 1, t2, ema9_2);
        }

      ObjectSetInteger(0, name9, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, name9, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name9, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name9, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, name21) < 0)
         ObjectCreate(0, name21, OBJ_TREND, 0, t1, ema21_1, t2, ema21_2);
      else
        {
         ObjectMove(0, name21, 0, t1, ema21_1);
         ObjectMove(0, name21, 1, t2, ema21_2);
        }

      ObjectSetInteger(0, name21, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name21, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name21, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name21, OBJPROP_SELECTABLE, false);
     }
  }

//+------------------------------------------------------------------+
void DrawDashboard()
  {

   Comment(GetLast5TrendChangesText());

   DrawEMA9AndEMA21Lines();

   int mult = GetBalanceMultiplier();

   double buyPL  = GetBasketProfit(OP_BUY);
   double sellPL = GetBasketProfit(OP_SELL);

   color buyClr  = buyPL >= 0 ? clrLime : clrTomato;
   color sellClr = sellPL >= 0 ? clrLime : clrTomato;

   string direction = GetActiveOrdersDirection();
   string trendText = GetTrendText() ;

   if(IsFlatMarket())
     {
      trendText=trendText+" (FLAT)";
     }
   else

     {
      trendText=trendText+" (Not FLAT)";
     }



   color dirClr = clrSilver;

   if(direction == "BUY ACTIVE")
      dirClr = clrLime;

   if(direction == "SELL ACTIVE")
      dirClr = clrTomato;

   if(direction == "BUY + SELL")
      dirClr = clrAqua;

   color trendClr = clrSilver;

   if(GetTrendDirection() == 1)
      trendClr = clrLime;

   if(GetTrendDirection() == -1)
      trendClr = clrTomato;

   double buyLatestPrice  = GetLatestOrderPrice(OP_BUY);
   double sellLatestPrice = GetLatestOrderPrice(OP_SELL);

   double buyLatestGap  = GetLivePriceDiffFromLatestOrder(OP_BUY);
   double sellLatestGap = GetLivePriceDiffFromLatestOrder(OP_SELL);

   CreatePanel("DXB_PANEL",300,10,380,560,C'15,15,15');

   CreateLabel("V5",
               "PRICE GAP V5 PARALLEL TREND",
               210,30,
               clrGold,
               12);

   CreateLabel("DXB_BUYPL",
               "BUY Basket   : $" + DoubleToString(buyPL,2)+" ("+DoubleToString(GetLatestTrendGap(),0)+")",
               290,50,
               buyClr);

   string marketStatus=IsPauseTradingTimeUTC()?"(Paused)":"Active";


   CreateLabel("DXB_SELLPL",
               "SELL Basket  : $" + DoubleToString(sellPL,2)+" "+marketStatus+" ("+countOrderCountAfterTrendChanged+"<"+maxOrderAfterTrendChanged+")",
               290,70,
               sellClr);

   CreateLabel("DXB_BUYGAP",
               "BUY LatestGap: " + DoubleToString(buyLatestGap,2)+" "+DoubleToString(GetTrendGap(),0),
               290,90,
               buyLatestGap <= -20 ? clrLime : clrSilver);

   CreateLabel("DXB_SELLGAP",
               "SELL LatestG : " + DoubleToString(sellLatestGap,2),
               290,110,
               sellLatestGap >= 20 ? clrLime : clrSilver);

   CreateLabel("DXB_BUYLP",
               "BUY LastPrice: " + DoubleToString(buyLatestPrice,2),
               290,130,
               clrSilver);

   CreateLabel("DXB_SELLLP",
               "SELL LastPr  : " + DoubleToString(sellLatestPrice,2),
               290,150,
               clrSilver);

   CreateLabel("DXB_LOT",
               "Base Lot     : " + DoubleToString(GetLot(BaseLot),2),
               290,175,
               clrOrange);

   CreateLabel("DXB_CLOSED_M5_GAP",
               "Closed M5 Gap: " + DoubleToString(GetLastM5Gap(),2),
               290,195,
               clrYellow);

   CreateLabel("DXB_TRIGGER",
               "Gap Trigger  : " + DoubleToString(GapPrice,2),
               290,215,
               clrYellow);

   CreateLabel("DXB_LIVE_M5_GAP",
               "Live M5 Gap  : " + DoubleToString(GetLiveM5Gap(),2),
               290,235,
               GetLiveM5Gap() >= 0 ? clrLime : clrTomato);

   CreateLabel("DXB_TREND",
               "Trend  EMA       : " + trendText,
               290,255,
               trendClr);

   CreateLabel("DXB_DIR",
               "Direction Orders   : " + direction,
               290,275,
               dirClr);

   CreateLabel("DXB_BUYORD",
               "BUY Orders   : " + IntegerToString(CountOrders(OP_BUY)),
               290,300,
               clrLime);

   CreateLabel("DXB_SELLORD",
               "SELL Orders  : " + IntegerToString(CountOrders(OP_SELL)),
               290,320,
               clrTomato);

   CreateLabel("DXB_TOTAL",
               "Total Orders : " + IntegerToString(CountAllOrders()),
               290,340,
               clrWhite);

   CreateLabel("DXB_BUYTP",
               "BUY TP       : $" + DoubleToString(GetDynamicBasketTarget(OP_BUY),2),
               290,365,
               clrDeepSkyBlue);

   CreateLabel("DXB_SELLTP",
               "SELL TP      : $" + DoubleToString(GetDynamicBasketTarget(OP_SELL),2),
               290,385,
               clrDeepSkyBlue);

   CreateLabel("DXB_SL",
               "Basket SL    : $" + DoubleToString(GetBasketSL(),2),
               290,410,
               clrOrangeRed);

   CreateLabel("DXB_BAL",
               "Balance      : $" + DoubleToString(AccountBalance(),2),
               290,435,
               clrWhite);

   CreateLabel("DXB_EQ",
               "Equity       : $" + DoubleToString(AccountEquity(),2),
               290,455,
               clrWhite);

   CreateLabel("DXB_FM",
               "Free Margin  : $" + DoubleToString(AccountFreeMargin(),2),
               290,475,
               clrWhite);

   CreateLabel("DXB_MULT",
               "Multiplier   : " + IntegerToString(mult) + "X",
               290,495,
               clrAqua);

   CreateLabel("DXB_STATUS",
               "RUNNING PARALLEL PRICE GAP RECOVERY",
               290,525,
               clrLime,
               10);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendChangeGap(
   int oldTrend,
   int newTrend,
   double oldPrice,
   double newPrice,
   datetime t
)
  {
   double gap = MathAbs(newPrice - oldPrice);

   string trendText =
      TrendName(oldTrend) +
      " -> " +
      TrendName(newTrend) +
      " : " +
      DoubleToString(gap, 2);

   string name = "TrendGap_" + IntegerToString((int)t);

// Print("trendText ",trendText);

// Create chart text
   ObjectCreate(0, name, OBJ_TEXT, 0, t, newPrice);

   ObjectSetString(0, name, OBJPROP_TEXT, trendText);

   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);

   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");

// Color
   if(newTrend == 1)
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
   else
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
  }
//+------------------------------------------------------------------+
void DrawEveryCandleDiffFrom5th()
  {
   int candlesToDraw = 100;

   for(int shift = 1; shift <= candlesToDraw; shift++)
     {
      if(shift + 5 >= Bars)
         continue;

      datetime t = iTime(Symbol(), PERIOD_M5, shift);

      string name = "DIFF5_" + IntegerToString((int)t);

      double currentClose = iClose(Symbol(), PERIOD_M5, shift);
      double fifthClose   = iClose(Symbol(), PERIOD_M5, shift + 5);

      double diff = NormalizeDouble(currentClose - fifthClose, 2);

      if(MathAbs(diff) < 50)
         continue;

      color txtColor = diff >= 0 ? clrLime : clrRed;

      double high = iHigh(Symbol(), PERIOD_M5, shift);
      double low  = iLow(Symbol(), PERIOD_M5, shift);

      double candleRange = MathAbs(high - low);
      double spacing = candleRange * 0.8;

      if(spacing < Point * 200)
         spacing = Point * 200;

      double y;

      if(diff >= 0)
         y = high + spacing;
      else
         y = low - spacing;

      if(ObjectFind(0, name) >= 0)
         continue;

      ObjectCreate(0, name, OBJ_TEXT, 0, t, y);

      ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(diff, 0));
      ObjectSetInteger(0, name, OBJPROP_COLOR, txtColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
