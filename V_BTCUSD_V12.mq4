//+------------------------------------------------------------------+
//| BTCUSD Top Down EA With Lines                                     |
//| 4H Direction + 1H BOS + 5M Engulfing Trigger                      |
//+------------------------------------------------------------------+
#property strict

extern double LotSize              = 0.01;
extern int    MagicNumber          = 448590;
extern int    Slippage             = 50;

extern double BasketProfitUSD      = 1.00;
extern double BasketStopLossUSD    = -25.00;

extern int    MaxSpreadPoints      = 3000;
extern int    CooldownMinutes      = 30;

extern int    Lookback4H           = 12;
extern int    Lookback1H           = 12;

extern double StopLossPoints       = 50000;
extern double TakeProfitPoints     = 10000;

extern bool   UseBrokerSLTP        = false;
extern bool   OneTradeOnly         = true;

extern bool   UseLondonNYOnly      = false;
extern int    SessionStartHour     = 10;
extern int    SessionEndHour       = 23;

extern int    ZoneSizePoints       = 5000;
extern int    LivePriceAreaPoints  = 7000;

datetime lastTradeTime = 0;
datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTCUSD Top Down EA With Lines Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   DrawAllLines();
   DrawDashboard();
   ManageBasketClose();

   if(!IsNewM5Candle())
      return;

    

   if(OneTradeOnly && CountMyOrders() > 0)
      return;

   if(TimeCurrent() - lastTradeTime < CooldownMinutes * 60)
      return;

   int bias4H = Get4HBias();
   if(bias4H == 0)
      return;

   int setup1H = Get1HSetup(bias4H);
   if(setup1H == 0)
      return;

   int trigger5M = Get5MTrigger(bias4H);
   if(trigger5M == 0)
      return;

   if(bias4H == 1 && setup1H == 1 && trigger5M == 1)
   {
      OpenOrder(OP_BUY);
      lastTradeTime = TimeCurrent();
   }

   if(bias4H == -1 && setup1H == -1 && trigger5M == -1)
   {
      OpenOrder(OP_SELL);
      lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
bool IsNewM5Candle()
{
   datetime currentBar = iTime(Symbol(), PERIOD_M5, 0);

   if(currentBar != lastM5BarTime)
   {
      lastM5BarTime = currentBar;
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
int Get4HBias()
{
   double ema50  = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema200 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 1);

   double close1   = iClose(Symbol(), PERIOD_H4, 1);
   double closeOld = iClose(Symbol(), PERIOD_H4, Lookback4H);

   double high1   = iHigh(Symbol(), PERIOD_H4, 1);
   double highOld = iHigh(Symbol(), PERIOD_H4, Lookback4H);

   double low1   = iLow(Symbol(), PERIOD_H4, 1);
   double lowOld = iLow(Symbol(), PERIOD_H4, Lookback4H);

   if(close1 > ema50 && ema50 > ema200 && close1 > closeOld && high1 > highOld)
      return 1;

   if(close1 < ema50 && ema50 < ema200 && close1 < closeOld && low1 < lowOld)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
int Get1HSetup(int bias)
{
   double close1 = iClose(Symbol(), PERIOD_H1, 1);

   int highIndex = iHighest(Symbol(), PERIOD_H1, MODE_HIGH, Lookback1H, 2);
   int lowIndex  = iLowest(Symbol(), PERIOD_H1, MODE_LOW, Lookback1H, 2);

   double prevHigh = iHigh(Symbol(), PERIOD_H1, highIndex);
   double prevLow  = iLow(Symbol(), PERIOD_H1, lowIndex);

   if(bias == 1 && close1 > prevHigh)
      return 1;

   if(bias == -1 && close1 < prevLow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
int Get5MTrigger(int bias)
{
   double open1  = iOpen(Symbol(), PERIOD_M5, 1);
   double close1 = iClose(Symbol(), PERIOD_M5, 1);
   double high1  = iHigh(Symbol(), PERIOD_M5, 1);
   double low1   = iLow(Symbol(), PERIOD_M5, 1);

   double open2  = iOpen(Symbol(), PERIOD_M5, 2);
   double close2 = iClose(Symbol(), PERIOD_M5, 2);

   double body1 = MathAbs(close1 - open1);

   if(body1 <= 0)
      return 0;

   double wickTop = high1 - MathMax(open1, close1);
   double wickLow = MathMin(open1, close1) - low1;

   bool bullishEngulf =
      close1 > open1 &&
      close2 < open2 &&
      close1 > open2 &&
      open1 < close2;

   bool bearishEngulf =
      close1 < open1 &&
      close2 > open2 &&
      close1 < open2 &&
      open1 > close2;

   bool bullishRejection = wickLow >= body1 * 0.40;
   bool bearishRejection = wickTop >= body1 * 0.40;

   if(bias == 1 && bullishEngulf && bullishRejection)
      return 1;

   if(bias == -1 && bearishEngulf && bearishRejection)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
void OpenOrder(int type)
{
   RefreshRates();

   double price = 0;
   double sl = 0;
   double tp = 0;

   if(type == OP_BUY)
   {
      price = Ask;

      if(UseBrokerSLTP)
      {
         sl = NormalizeDouble(price - StopLossPoints * Point, Digits);
         tp = NormalizeDouble(price + TakeProfitPoints * Point, Digits);
      }
   }

   if(type == OP_SELL)
   {
      price = Bid;

      if(UseBrokerSLTP)
      {
         sl = NormalizeDouble(price + StopLossPoints * Point, Digits);
         tp = NormalizeDouble(price - TakeProfitPoints * Point, Digits);
      }
   }

   int ticket = OrderSend(Symbol(), type, LotSize, price, Slippage, sl, tp,
                          "BTC_TOP_DOWN_LINES",
                          MagicNumber, 0,
                          type == OP_BUY ? clrBlue : clrRed);

   if(ticket < 0)
   {
      Print("OrderSend failed. Error: ", GetLastError());
   }
   else
   {
      if(type == OP_BUY)
         DrawArrow("BUY_ARROW_" + IntegerToString(ticket), TimeCurrent(), Ask, clrLime, 233);

      if(type == OP_SELL)
         DrawArrow("SELL_ARROW_" + IntegerToString(ticket), TimeCurrent(), Bid, clrRed, 234);

      Print("Order opened. Ticket: ", ticket);
   }
}

//+------------------------------------------------------------------+
void ManageBasketClose()
{
   double profit = GetBasketProfit();

   if(profit >= BasketProfitUSD)
   {
      CloseAllOrders();
      Print("Basket profit closed: ", profit);
   }

   if(profit <= BasketStopLossUSD)
   {
      CloseAllOrders();
      Print("Basket stoploss closed: ", profit);
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
               Print("OrderClose failed. Ticket: ", OrderTicket(), " Error: ", GetLastError());
         }
      }
   }
}

//+------------------------------------------------------------------+
int CountMyOrders()
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
bool SpreadTooHigh()
{
   double spread = MarketInfo(Symbol(), MODE_SPREAD);

   if(spread > MaxSpreadPoints)
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool IsTradingSession()
{
   int hour = TimeHour(TimeCurrent());

   if(SessionStartHour < SessionEndHour)
   {
      if(hour >= SessionStartHour && hour < SessionEndHour)
         return true;
   }
   else
   {
      if(hour >= SessionStartHour || hour < SessionEndHour)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| DRAWING FUNCTIONS                                                 |
//+------------------------------------------------------------------+
void DrawAllLines()
{
   Draw4HSupplyDemandZones();
   Draw1HBOSLines();
   DrawEMALines();
   DrawLivePriceLine();
   DrawLivePriceArea();
}

//+------------------------------------------------------------------+
void Draw4HSupplyDemandZones()
{
   int demandIndex = iLowest(Symbol(), PERIOD_H4, MODE_LOW, 20, 1);
   int supplyIndex = iHighest(Symbol(), PERIOD_H4, MODE_HIGH, 20, 1);

   double demandPrice = iLow(Symbol(), PERIOD_H4, demandIndex);
   double supplyPrice = iHigh(Symbol(), PERIOD_H4, supplyIndex);

   DrawZone("4H_DEMAND_ZONE",
            demandPrice - ZoneSizePoints * Point,
            demandPrice + ZoneSizePoints * Point,
            clrDarkGreen);

   DrawZone("4H_SUPPLY_ZONE",
            supplyPrice - ZoneSizePoints * Point,
            supplyPrice + ZoneSizePoints * Point,
            clrMaroon);

   DrawText("TXT_4H_DEMAND", "4H DEMAND", Time[30], demandPrice, clrLime);
   DrawText("TXT_4H_SUPPLY", "4H SUPPLY", Time[30], supplyPrice, clrRed);
}

//+------------------------------------------------------------------+
void Draw1HBOSLines()
{
   int highIndex = iHighest(Symbol(), PERIOD_H1, MODE_HIGH, Lookback1H, 2);
   int lowIndex  = iLowest(Symbol(), PERIOD_H1, MODE_LOW, Lookback1H, 2);

   double bosHigh = iHigh(Symbol(), PERIOD_H1, highIndex);
   double bosLow  = iLow(Symbol(), PERIOD_H1, lowIndex);

   DrawHLine("1H_BOS_HIGH", bosHigh, clrLime, STYLE_DASH);
   DrawHLine("1H_BOS_LOW", bosLow, clrRed, STYLE_DASH);

   DrawText("TXT_1H_BOS_HIGH", "1H BOS HIGH", Time[20], bosHigh, clrLime);
   DrawText("TXT_1H_BOS_LOW", "1H BOS LOW", Time[20], bosLow, clrRed);
}

//+------------------------------------------------------------------+
void DrawEMALines()
{
   double ema50H4  = iMA(Symbol(), PERIOD_H4, 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema200H4 = iMA(Symbol(), PERIOD_H4, 200, 0, MODE_EMA, PRICE_CLOSE, 0);

   double ema21M5 = iMA(Symbol(), PERIOD_M5, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   DrawHLine("H4_EMA_50", ema50H4, clrDodgerBlue, STYLE_SOLID);
   DrawHLine("H4_EMA_200", ema200H4, clrOrangeRed, STYLE_SOLID);
   DrawHLine("M5_EMA_21", ema21M5, clrYellow, STYLE_DOT);

   DrawText("TXT_H4_EMA_50", "4H EMA 50", Time[10], ema50H4, clrDodgerBlue);
   DrawText("TXT_H4_EMA_200", "4H EMA 200", Time[10], ema200H4, clrOrangeRed);
   DrawText("TXT_M5_EMA_21", "5M EMA 21", Time[10], ema21M5, clrYellow);
}

//+------------------------------------------------------------------+
void DrawLivePriceLine()
{
   DrawHLine("LIVE_PRICE_LINE", Bid, clrWhite, STYLE_SOLID);
   DrawText("TXT_LIVE_PRICE", "LIVE PRICE " + DoubleToString(Bid, Digits), Time[5], Bid, clrWhite);
}

//+------------------------------------------------------------------+
void DrawLivePriceArea()
{
   double upper = Bid + LivePriceAreaPoints * Point;
   double lower = Bid - LivePriceAreaPoints * Point;

   DrawZone("LIVE_PRICE_AREA", lower, upper, clrDimGray);
}

//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, int style)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

//+------------------------------------------------------------------+
void DrawZone(string name, double price1, double price2, color clr)
{
   datetime time1 = Time[300];
   datetime time2 = TimeCurrent() + 86400;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2);

   ObjectSetInteger(0, name, OBJPROP_TIME1, time1);
   ObjectSetInteger(0, name, OBJPROP_TIME2, time2);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price1);
   ObjectSetDouble(0, name, OBJPROP_PRICE2, price2);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
}

//+------------------------------------------------------------------+
void DrawArrow(string name, datetime t, double price, color clr, int code)
{
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
}

//+------------------------------------------------------------------+
void DrawText(string name, string text, datetime t, double price, color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_TIME1, t);
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   int bias = Get4HBias();
   int setup = Get1HSetup(bias);
   int trigger = Get5MTrigger(bias);

   string text =
      "BTCUSD TOP DOWN EA WITH LINES\n"
      "-----------------------------\n"
      "4H Bias: " + BiasText(bias) + "\n"
      "1H Setup: " + BiasText(setup) + "\n"
      "5M Trigger: " + BiasText(trigger) + "\n"
      "Orders: " + IntegerToString(CountMyOrders()) + "\n"
      "Basket P/L: $" + DoubleToString(GetBasketProfit(), 2) + "\n"
      "Spread: " + DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0) + "\n"
      "Rule: 4H + 1H + 5M must align";

   Comment(text);
}

//+------------------------------------------------------------------+
string BiasText(int bias)
{
   if(bias == 1)
      return "BUY / Bullish";

   if(bias == -1)
      return "SELL / Bearish";

   return "NO TRADE";
}
//+------------------------------------------------------------------+