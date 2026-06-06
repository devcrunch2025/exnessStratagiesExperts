//+------------------------------------------------------------------+
//|                         SAR_FLIP_FULLPROFIT_BIG_CANDLE_300.mq4   |
//|  Big Candle + Last2 M1 filters for NORMAL entries only             |
//+------------------------------------------------------------------+
#property strict

double Lots = 0.01;
double TakeProfitUSD = 2.0;   // BUY/SELL basket take profit only
double StopLossUSD   = 15.0;   // BUY/SELL basket stop loss only

// Daily target profit. When account balance profit reaches this value,
// EA closes all orders and stops trading until next day.
double DailyTargetProfitUSD = 5.0;

// Option: close opposite basket immediately when SAR signal changes.
// true  = close opposite basket on SAR flip
// false = keep existing basket until basket TP/SL or daily target
bool CloseOnSARSignalChange = false;

//+------------------------------------------------------------------+
//| BIG CANDLE ENTRY FILTER                                          |
//| Create new orders only after previous candle body size >= 300     |
//| raw price difference. Direction must match SAR direction.         |
//+------------------------------------------------------------------+
bool   UseBigCandleEntryFilter       = true;
bool   UseBigCandleFilterForRecovery = false; // kept for settings reference; recovery filter is disabled in CheckRecovery()
double BigCandleMinSizeRawPrice      = 70.0;

//+------------------------------------------------------------------+
//| LAST 2 M1 CANDLES RAW MOVE ENTRY FILTER                          |
//| Compare M1 candle shift 2 OPEN price with M1 candle shift 1 CLOSE |
//| price. New orders allowed only when raw price difference > 100.   |
//+------------------------------------------------------------------+
bool   UseLast2M1RawMoveEntryFilter  = true;
double Last2M1RawMoveMinPrice        = 100.0;

// Daily target tracking
double g_dayStartBalance = 0.0;
int    g_lastDayOfYear   = -1;
bool   g_dailyTargetHit  = false;

double RecoveryGapRawPrice = 30.0;
int MaxRecoveryOrders = 10;

bool UseEarlyWeaknessClose = false;
int WeaknessCandles = 3;
double WeaknessRawPriceMove = 50.0;
double EarlyCloseMinProfit = -12.0;

bool ShowWeakStrongCircles = false;
color WeakCircleColor = clrRed;
color StrongCircleColor = clrLime;
int WeakStrongCircleCode = 108;
int WeakStrongCircleWidth = 2;

int TradingStartHour = 0;
int TradingEndHour   = 24;

int    InpSARPeriod       = 2;
double InpSARStepSize     = 20;
double InpSARAcceleration = 10;

bool   InpDrawSARDots = true;
int    InpSARDotLookback = 200;
color  InpSARDotBuyColor = clrLime;
color  InpSARDotSellColor = clrRed;

int MagicNumber = 20260605;
int Slippage = 30;

string OBJ_PREFIX = "SAR_FLIP_EA_";

int g_currentSARDirection = 0;

bool g_buySARWeakPaused  = false;
bool g_sellSARWeakPaused = false;

// Stop creating orders in same SAR direction after basket stop loss,
// until SAR signal changes to the opposite direction.
bool g_buyStopLossPaused  = false;
bool g_sellStopLossPaused = false;

//+------------------------------------------------------------------+
int OnInit()
  {
   g_currentSARDirection = GetCurrentSARDirection();

   g_dayStartBalance = AccountBalance();
   g_lastDayOfYear   = TimeDayOfYear(TimeCurrent());
   g_dailyTargetHit  = false;

   Print("EA initialized. Daily start balance: ",
         DoubleToString(g_dayStartBalance, 2),
         " Daily target: ",
         DoubleToString(DailyTargetProfitUSD, 2),
         " Big candle filter: ",
         UseBigCandleEntryFilter ? "ON" : "OFF",
         " Min size raw price: ",
         DoubleToString(BigCandleMinSizeRawPrice, Digits),
         " Last2 M1 raw move filter: ",
         UseLast2M1RawMoveEntryFilter ? "ON" : "OFF",
         " Min move: ",
         DoubleToString(Last2M1RawMoveMinPrice, Digits));

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   DeleteObjectsByPrefix(OBJ_PREFIX);
  }

//+------------------------------------------------------------------+
//| Check daily profit target and stop trading after target hit       |
//+------------------------------------------------------------------+
void CheckDailyProfitTarget()
  {
   int currentDay = TimeDayOfYear(TimeCurrent());

   // Reset every new broker day
   if(currentDay != g_lastDayOfYear)
     {
      g_lastDayOfYear   = currentDay;
      g_dayStartBalance = AccountBalance();
      g_dailyTargetHit  = false;

      Print("Daily target reset. New start balance = ",
            DoubleToString(g_dayStartBalance, 2));
     }

   double dailyProfit = AccountBalance() - g_dayStartBalance;

   if(!g_dailyTargetHit && dailyProfit >= DailyTargetProfitUSD)
     {
      g_dailyTargetHit = true;

      Print("DAILY TARGET HIT. Daily profit = ",
            DoubleToString(dailyProfit, 2),
            " Target = ",
            DoubleToString(DailyTargetProfitUSD, 2),
            ". Closing all orders and stopping trading until next day.");

      CloseOrders(OP_BUY);
      CloseOrders(OP_SELL);
     }
  }

//+------------------------------------------------------------------+
void UpdateDailyTargetComment()
  {
   double dailyProfit = AccountBalance() - g_dayStartBalance;
   int bigDir = GetBigCandleDirection();
   double last2Move = GetLast2M1RawMove();

   Comment(
      "SAR FLIP EA\n",
      "Daily Profit: $", DoubleToString(dailyProfit, 2), "\n",
      "Daily Target: $", DoubleToString(DailyTargetProfitUSD, 2), "\n",
      "Trading: ", g_dailyTargetHit ? "STOPPED - DAILY TARGET HIT" : "ACTIVE", "\n",
      "Close On SAR Change: ", CloseOnSARSignalChange ? "TRUE" : "FALSE", "\n",
      "Big Candle Filter: ", UseBigCandleEntryFilter ? "ON" : "OFF", " | Min: ", DoubleToString(BigCandleMinSizeRawPrice, 2), "\n",
      "Big Candle Direction: ", bigDir == 1 ? "BUY" : bigDir == -1 ? "SELL" : "NO BIG CANDLE", "\n",
      "Last 2 M1 Move: ", DoubleToString(last2Move, 2), " / Required > ", DoubleToString(Last2M1RawMoveMinPrice, 2), "\n",
      "BUY Orders: ", CountOrders(OP_BUY), " | BUY Basket P/L: $", DoubleToString(GetBasketProfit(OP_BUY), 2), "\n",
      "SELL Orders: ", CountOrders(OP_SELL), " | SELL Basket P/L: $", DoubleToString(GetBasketProfit(OP_SELL), 2), "\n",
      "SAR Direction: ", g_currentSARDirection == 1 ? "BUY" : g_currentSARDirection == -1 ? "SELL" : "NONE"
   );
  }

//+------------------------------------------------------------------+
//| Big candle direction based on previous CLOSED candle body         |
//| BUY  = candle close > open and body >= BigCandleMinSizeRawPrice   |
//| SELL = candle close < open and body >= BigCandleMinSizeRawPrice   |
//+------------------------------------------------------------------+
int GetBigCandleDirection()
  {
   if(Bars < 3)
      return(0);

   double open1  = iOpen(Symbol(), Period(), 1);
   double close1 = iClose(Symbol(), Period(), 1);

   double bodySize = MathAbs(close1 - open1);

   if(bodySize < BigCandleMinSizeRawPrice)
      return(0);

   if(close1 > open1)
      return(1);

   if(close1 < open1)
      return(-1);

   return(0);
  }

//+------------------------------------------------------------------+
//| Current previous candle body size for OrderSend comment           |
//+------------------------------------------------------------------+
double GetCurrentBigCandleSize()
  {
   if(Bars < 3)
      return(0);

   double open1  = iOpen(Symbol(), Period(), 1);
   double close1 = iClose(Symbol(), Period(), 1);

   return(MathAbs(close1 - open1));
  }

//+------------------------------------------------------------------+
//| Build OrderSend comment with entry type and candle move values    |
//| Example: BUY_BC125_M12115 / RECBUY_BC85_M12140                    |
//+------------------------------------------------------------------+
string BuildOrderComment(int type)
  {
   double bigSize  = GetCurrentBigCandleSize();
   double m1m2Move = GetLast2M1RawMove();

   bool isRecovery = (CountOrders(type) > 0);

   string side = type == OP_BUY ? "BUY" : "SELL";

   if(isRecovery)
      return(StringFormat("REC%s_BC%.0f_M12%.0f", side, bigSize, m1m2Move));

   return(StringFormat("%s_BC%.0f_M12%.0f", side, bigSize, m1m2Move));
  }

//+------------------------------------------------------------------+
//| Entry permission by BIG candle filter                             |
//+------------------------------------------------------------------+
bool IsBigCandleAllowedForDirection(int direction)
  {
   if(!UseBigCandleEntryFilter)
      return(true);

   int bigDir = GetBigCandleDirection();

   if(bigDir == direction)
      return(true);

   double bigSize = GetCurrentBigCandleSize();

Print(
   "Order blocked by Big Candle filter | ",
   "Required=", (direction == 1 ? "BUY" : "SELL"),
   " | BigDir=", (bigDir == 1 ? "BUY" : bigDir == -1 ? "SELL" : "NONE"),
   " | CandleHeight=", DoubleToString(bigSize,0),
   " | RequiredMin=", DoubleToString(BigCandleMinSizeRawPrice,0)
);
   return(false);
  }

//+------------------------------------------------------------------+
//| Raw movement from M1 candle shift 2 OPEN to M1 candle shift 1 CLOSE|
//| Example: MathAbs(iClose(M1,1) - iOpen(M1,2))                     |
//+------------------------------------------------------------------+
double GetLast2M1RawMove()
  {
   if(iBars(Symbol(), PERIOD_M1) < 3)
      return(0);

   double open2  = iOpen(Symbol(), PERIOD_M1, 2);
   double close1 = iClose(Symbol(), PERIOD_M1, 1);

   return(MathAbs(close1 - open2));
  }

//+------------------------------------------------------------------+
//| Entry permission by last 2 M1 candles raw price movement          |
//+------------------------------------------------------------------+
bool IsLast2M1RawMoveAllowed()
  {
   if(!UseLast2M1RawMoveEntryFilter)
      return(true);

   double move = GetLast2M1RawMove();

   if(move > Last2M1RawMoveMinPrice)
      return(true);

   Print("Order blocked by Last 2 M1 raw move filter. Move=",
         DoubleToString(move, 2),
         " Required > ",
         DoubleToString(Last2M1RawMoveMinPrice, 2),
         " Formula: Abs(M1 shift 1 close - M1 shift 2 open)");

   return(false);
  }

//+------------------------------------------------------------------+
//| Final entry filter: Big candle direction + Last 2 M1 raw move     |
//+------------------------------------------------------------------+
bool IsEntryAllowedForDirection(int direction)
  {
   if(!IsBigCandleAllowedForDirection(direction))
      return(false);

   if(!IsLast2M1RawMoveAllowed())
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetM30TrendDirection()
  {
   double currentPrice = Close[0];

// M1 chart: currently comparing 5 candles ago as per your original code
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 5);

   double diff = currentPrice - price30MinAgo;

   if(diff >= 100)
      return 1;   // BUY trend

   if(diff <= -100)
      return -1;  // SELL trend

   return 0;      // RANGE


   double emaFast = iMA(Symbol(), PERIOD_M5, 9, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 1);

   double close1 = iClose(Symbol(), PERIOD_M5, 1);

   if(emaFast > emaSlow && close1 > emaFast)
      return 1;   // BUY trend

   if(emaFast < emaSlow && close1 < emaFast)
      return -1;  // SELL trend

   return 0;      // No clear trend
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   CheckDailyProfitTarget();
   UpdateDailyTargetComment();

   // After daily target hit, EA must not create or manage new trading entries.
   // Orders are already closed by CheckDailyProfitTarget().
   if(g_dailyTargetHit)
      return;

   // IMPORTANT:
   // No individual order closing.
   // BUY and SELL sides are managed only by basket TakeProfitUSD and StopLossUSD.
   ManageBasketTakeProfitAndStopLoss();

   DrawSARDots();

   Print(GetM30TrendDirection());

   int signal = GetSARFlipSignal();

   if(signal != 0)
      g_currentSARDirection = signal;

   if(g_currentSARDirection == 0)
      g_currentSARDirection = GetCurrentSARDirection();

   CloseBySARWeaknessBeforeFlip();

   if(!IsTradingHour())
      return;

   if(signal == 1)
     {
      g_sellSARWeakPaused = false;

      // SAR changed to BUY, so SELL stop-loss pause is released.
      g_sellStopLossPaused = false;

      if(CloseOnSARSignalChange)
        {
         Print("SAR changed to BUY. CloseOnSARSignalChange=true, closing SELL basket.");
         CloseOrders(OP_SELL);
        }
      else
        {
         Print("SAR changed to BUY. CloseOnSARSignalChange=false, SELL basket will continue until basket TP/SL.");
        }

      if(CountOrders(OP_BUY) == 0 && !g_buySARWeakPaused && !g_buyStopLossPaused && IsEntryAllowedForDirection(1))
         OpenOrder(OP_BUY);

      ManageRecoveryOrders();
      return;
     }

   if(signal == -1)
     {
      g_buySARWeakPaused = false;

      // SAR changed to SELL, so BUY stop-loss pause is released.
      g_buyStopLossPaused = false;

      if(CloseOnSARSignalChange)
        {
         Print("SAR changed to SELL. CloseOnSARSignalChange=true, closing BUY basket.");
         CloseOrders(OP_BUY);
        }
      else
        {
         Print("SAR changed to SELL. CloseOnSARSignalChange=false, BUY basket will continue until basket TP/SL.");
        }

      if(CountOrders(OP_SELL) == 0 && !g_sellSARWeakPaused && !g_sellStopLossPaused && IsEntryAllowedForDirection(-1))
         OpenOrder(OP_SELL);

      ManageRecoveryOrders();
      return;
     }

// Continuous SAR order creation
   if(g_currentSARDirection == 1 && CountOrders(OP_BUY) == 0 && !g_buySARWeakPaused && !g_buyStopLossPaused && IsEntryAllowedForDirection(1))
      OpenOrder(OP_BUY);

   if(g_currentSARDirection == -1 && CountOrders(OP_SELL) == 0 && !g_sellSARWeakPaused && !g_sellStopLossPaused && IsEntryAllowedForDirection(-1))
      OpenOrder(OP_SELL);

   ManageRecoveryOrders();
  }

//+------------------------------------------------------------------+
void CloseBySARWeaknessBeforeFlip()
  {
   if(!UseEarlyWeaknessClose)
      return;

   int sarDirection = GetCurrentSARDirection();

   if(sarDirection == 1)
     {
      g_sellSARWeakPaused = false;

      if(IsBearishWeaknessAgainstBUY())
        {
         if(!g_buySARWeakPaused)
            DrawWeakStrongCircle("BUY_WEAK", 1, WeakCircleColor);

         g_buySARWeakPaused = true;

         if(CountOrders(OP_BUY) > 0)
           {
            // Do NOT close BUY basket here.
            // Basket must close only by TakeProfitUSD, StopLossUSD, or daily target.
            Print("BUY SAR weak. BUY re-entry paused. Existing BUY basket will continue until basket TP/SL.");
           }
        }
      else
        {
         if(g_buySARWeakPaused)
            DrawWeakStrongCircle("BUY_STRONG", 1, StrongCircleColor);

         g_buySARWeakPaused = false;
        }
     }

   if(sarDirection == -1)
     {
      g_buySARWeakPaused = false;

      if(IsBullishWeaknessAgainstSELL())
        {
         if(!g_sellSARWeakPaused)
            DrawWeakStrongCircle("SELL_WEAK", -1, WeakCircleColor);

         g_sellSARWeakPaused = true;

         if(CountOrders(OP_SELL) > 0)
           {
            // Do NOT close SELL basket here.
            // Basket must close only by TakeProfitUSD, StopLossUSD, or daily target.
            Print("SELL SAR weak. SELL re-entry paused. Existing SELL basket will continue until basket TP/SL.");
           }
        }
      else
        {
         if(g_sellSARWeakPaused)
            DrawWeakStrongCircle("SELL_STRONG", -1, StrongCircleColor);

         g_sellSARWeakPaused = false;
        }
     }
  }

//+------------------------------------------------------------------+
void DrawWeakStrongCircle(string type, int direction, color clr)
  {
   if(!ShowWeakStrongCircles)
      return;

   string name = OBJ_PREFIX + type + "_" + TimeToString(Time[1], TIME_DATE|TIME_MINUTES);

   if(ObjectFind(0, name) >= 0)
      return;

   double price;

   if(direction == 1)
      price = Low[1] - (80 * Point);
   else
      price = High[1] + (80 * Point);

   ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, WeakStrongCircleCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, WeakStrongCircleWidth);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
bool IsBearishWeaknessAgainstBUY()
  {
   int bearishCount = 0;

   double startOpen = iOpen(Symbol(), Period(), WeaknessCandles);
   double lastClose = iClose(Symbol(), Period(), 1);

   for(int i = 1; i <= WeaknessCandles; i++)
     {
      double open  = iOpen(Symbol(), Period(), i);
      double close = iClose(Symbol(), Period(), i);

      if(close < open)
         bearishCount++;
     }

   double rawMoveDown = startOpen - lastClose;

   if(bearishCount >= 2 && rawMoveDown >= WeaknessRawPriceMove)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
bool IsBullishWeaknessAgainstSELL()
  {
   int bullishCount = 0;

   double startOpen = iOpen(Symbol(), Period(), WeaknessCandles);
   double lastClose = iClose(Symbol(), Period(), 1);

   for(int i = 1; i <= WeaknessCandles; i++)
     {
      double open  = iOpen(Symbol(), Period(), i);
      double close = iClose(Symbol(), Period(), i);

      if(close > open)
         bullishCount++;
     }

   double rawMoveUp = lastClose - startOpen;

   if(bullishCount >= 2 && rawMoveUp >= WeaknessRawPriceMove)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
void ManageRecoveryOrders()
  {
   if(g_currentSARDirection == 1 && !g_buySARWeakPaused && !g_buyStopLossPaused)
      CheckRecovery(OP_BUY);

   if(g_currentSARDirection == -1 && !g_sellSARWeakPaused && !g_sellStopLossPaused)
      CheckRecovery(OP_SELL);
  }

//+------------------------------------------------------------------+
void CheckRecovery(int type)
  {
   // Recovery orders are intentionally NOT locked by Big Candle or Last2M1 filters.
   // They are controlled only by basket loss, max recovery count, and raw price gap.

   int orderCount = CountOrders(type);

   if(orderCount <= 0)
      return;

   if(orderCount >= MaxRecoveryOrders)
      return;

   double basketProfit = GetBasketProfit(type);

   if(basketProfit >= 0)
      return;

   double latestPrice = GetLatestOrderOpenPrice(type);

   if(latestPrice <= 0)
      return;

   RefreshRates();

   if(type == OP_BUY)
     {
      if(Bid <= latestPrice - RecoveryGapRawPrice * CountOrders(type))
         OpenOrder(OP_BUY);
     }

   if(type == OP_SELL)
     {
      if(Ask >= latestPrice + RecoveryGapRawPrice * CountOrders(type))
         OpenOrder(OP_SELL);
     }
  }

//+------------------------------------------------------------------+
double GetBasketProfit(int type)
  {
   double profit = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == type)
        {
         profit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

   return profit;
  }

//+------------------------------------------------------------------+
double GetLatestOrderOpenPrice(int type)
  {
   datetime latestTime = 0;
   double latestPrice = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      if(OrderOpenTime() > latestTime)
        {
         latestTime = OrderOpenTime();
         latestPrice = OrderOpenPrice();
        }
     }

   return latestPrice;
  }

//+------------------------------------------------------------------+
int GetSARFlipSignal()
  {
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2])
      return 1;

   if(sar1 > Close[1] && sar2 <= Close[2])
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
int GetCurrentSARDirection()
  {
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar = iSAR(Symbol(), Period(), step, maxstep, 1);

   if(sar < Close[1])
      return 1;

   if(sar > Close[1])
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
void OpenOrder(int type)
  {
   if(g_dailyTargetHit)
      return;

   // IMPORTANT:
   // OpenOrder() does NOT apply Big Candle or Last2M1 filters.
   // Normal SAR entries are filtered before calling OpenOrder().
   // Recovery orders can call OpenOrder() directly and will not be blocked
   // by Big Candle or Last2M1 movement filters.

// if( GetM30TrendDirection() != type)
//       return;

   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;

   price = NormalizeDouble(price, Digits);

   string orderComment = BuildOrderComment(type);

   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0,
                          orderComment, MagicNumber, 0,
                          type == OP_BUY ? clrBlue : clrRed);

   if(ticket < 0)
      Print("OrderSend failed. Error: ", GetLastError(), " Comment=", orderComment);
   else
      Print("Order opened. Ticket=", ticket, " Comment=", orderComment);
  }

//+------------------------------------------------------------------+
void CloseOrders(int type)
  {
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != type)
         continue;

      double closePrice = type == OP_BUY ? Bid : Ask;

      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrYellow);

      if(!closed)
         Print("OrderClose failed. Ticket: ", OrderTicket(), " Error: ", GetLastError());
     }
  }

//+------------------------------------------------------------------+
int CloseOrdersByProfitOrLossUSD()
  {
   // Disabled by request:
   // EA must not close individual orders.
   // Orders are closed only by BUY/SELL basket TP, basket SL, or daily target.
   return 0;
  }

//+------------------------------------------------------------------+
void ManageBasketTakeProfitAndStopLoss()
  {
   RefreshRates();

   double buyBasketProfit  = GetBasketProfit(OP_BUY);
   double sellBasketProfit = GetBasketProfit(OP_SELL);

   // BUY basket take profit
   if(CountOrders(OP_BUY) > 0 && buyBasketProfit >= TakeProfitUSD)
     {
      Print("BUY Basket TakeProfitUSD hit. Basket P/L: ",
            DoubleToString(buyBasketProfit, 2),
            " Target: ",
            DoubleToString(TakeProfitUSD, 2));

      CloseOrders(OP_BUY);
      return;
     }

   // SELL basket take profit
   if(CountOrders(OP_SELL) > 0 && sellBasketProfit >= TakeProfitUSD)
     {
      Print("SELL Basket TakeProfitUSD hit. Basket P/L: ",
            DoubleToString(sellBasketProfit, 2),
            " Target: ",
            DoubleToString(TakeProfitUSD, 2));

      CloseOrders(OP_SELL);
      return;
     }

   // BUY basket stop loss
   if(CountOrders(OP_BUY) > 0 && buyBasketProfit <= -StopLossUSD)
     {
      Print("BUY Basket StopLossUSD hit. Basket P/L: ",
            DoubleToString(buyBasketProfit, 2),
            " Limit: -",
            DoubleToString(StopLossUSD, 2));

      CloseOrders(OP_BUY);
      return;
     }

   // SELL basket stop loss
   if(CountOrders(OP_SELL) > 0 && sellBasketProfit <= -StopLossUSD)
     {
      Print("SELL Basket StopLossUSD hit. Basket P/L: ",
            DoubleToString(sellBasketProfit, 2),
            " Limit: -",
            DoubleToString(StopLossUSD, 2));

      CloseOrders(OP_SELL);
      return;
     }
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
bool IsTradingHour()
  {
   int h = TimeHour(TimeCurrent());
   return (h >= TradingStartHour && h < TradingEndHour);
  }

//+------------------------------------------------------------------+
void DrawSARDots()
  {
   if(!InpDrawSARDots)
      return;

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   int lookback = MathMin(InpSARDotLookback, Bars - 1);

   for(int i = 0; i < lookback; i++)
     {
      double sar = iSAR(Symbol(), Period(), step, maxstep, i);

      if(sar <= 0)
         continue;

      string name = OBJ_PREFIX + "SAR_DOT_" + IntegerToString(i);

      if(ObjectFind(0, name) < 0)
        {
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
        }
      else
        {
         ObjectSetInteger(0, name, OBJPROP_TIME, Time[i]);
         ObjectSetDouble(0, name, OBJPROP_PRICE, sar);
        }

      if(sar < Close[i])
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotBuyColor);
      else
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotSellColor);
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
  {
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
     {
      string name = ObjectName(i);

      if(StringFind(name, prefix) == 0)
         ObjectDelete(name);
     }
  }
//+------------------------------------------------------------------+
