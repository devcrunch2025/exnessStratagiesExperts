//+------------------------------------------------------------------+
//| V201 TradingView MACD Histogram Cross + Recovery EA              |
//| Basket TP $1 | Basket SL $20 | Multiple Orders                   |
//| Recovery by PRICE DIFFERENCE from last losing order              |
//| Professional Dashboard + BUY/SELL Chart Signals                  |
//+------------------------------------------------------------------+
#property strict

double LotSize         = 0.01;
double ProfitTargetUSD = 0.50;

bool   UseStopLoss     = true;
double StopLossUSD     = 20.0;

int    TrendEMA        = 20;
int    FastEMA         = 12;
int    SlowEMA         = 26;
int    SignalSMA       = 9;

int    TimeFrame       = PERIOD_M5;
int    Slippage        = 30;
int    MagicNumber     = 20260518;

// Multiple Orders
bool   AllowMultipleBaseOrders = false;
int    MaxBaseOrders           = 10;

// Recovery Settings
bool   EnableRecovery       = true;
double RecoveryStartLossUSD = -0.01;
int    MaxRecoveryOrders    = 3;

// RAW PRICE DIFFERENCE, NOT POINTS
double RecoveryGap1Price = 100.0;
double RecoveryGap2Price = 300.0;
double RecoveryGap3Price = 600.0;

double Recovery1Lot = 0.01;
double Recovery2Lot = 0.01;
double Recovery3Lot = 0.01;

// Chart Display Settings
bool   ShowDashboard     = true;
bool   ShowSignalArrows  = true;
bool   ShowSignalLabels  = true;
bool   ShowEMA20Line     = true;
int    DashboardCorner   = CORNER_RIGHT_UPPER;
int    DashboardX        = 15;
int    DashboardY        = 20;
int    SignalArrowGap    = 300; // points gap from candle high/low for arrow

#define DASH_PREFIX "V201_DASH_"
#define SIG_PREFIX  "V201_SIGNAL_"

datetime lastBarTime = 0;
string   lastSignalText = "WAIT";
datetime lastSignalTime = 0;
int      lastSignalDirection = 0;

//+------------------------------------------------------------------+
int OnInit()
{
if(!IsTesting())
{
   if(AccountNumber() != 289058672 &&
      AccountNumber() != 291058458)
   {
      Print("Unauthorized Account: ", AccountNumber());
      return(INIT_SUCCEEDED);
   }
}
   MagicNumber=AccountNumber() +201;

   Print("V201 MACD Histogram Cross EA initialized. Symbol=", Symbol(), " TF=", TFToString(TimeFrame));
   DrawDashboard();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(DASH_PREFIX);
}

//+------------------------------------------------------------------+
void OnTick()
{


if(!IsTesting())
{
   if(AccountNumber() != 289058672 &&
      AccountNumber() != 291058458)
   {
      // Print("Unauthorized Account: ", AccountNumber());
      return;
   }
}


   if(ShowEMA20Line)
      DrawEMA20Line();

   ManageTrades();

   if(EnableRecovery)
      CheckRecoveryOrders();

   DrawDashboard();

   datetime currentBar = iTime(Symbol(), TimeFrame, 0);

   if(currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   CheckV201MACDSignal();
   DrawDashboard();
}

//+------------------------------------------------------------------+
//| TradingView MACD Strategy Logic                                  |
//| delta = MACD main - MACD signal                                  |
//| BUY  = delta crosses above 0                                     |
//| SELL = delta crosses below 0                                     |
//+------------------------------------------------------------------+
void CheckV201MACDSignal()
{
   int signal = dxb_GetMACDSignal_V201();

   if(signal == 0)
      return;

   datetime signalTime = iTime(Symbol(), TimeFrame, 1);
   double signalPrice  = iClose(Symbol(), TimeFrame, 1);

   // Draw signal on chart even if order is blocked. This helps verify TradingView signal matching.
   if(signal == 1)
      DrawSignalOnChart(1, signalTime, signalPrice, "BUY SIGNAL");

   if(signal == -1)
      DrawSignalOnChart(-1, signalTime, signalPrice, "SELL SIGNAL");

   if(!AllowMultipleBaseOrders && CountOpenTrades() > 0)
   {
      Print("V201 signal detected but blocked: AllowMultipleBaseOrders=false and trade already open.");
      return;
   }

   if(CountBaseOrders() >= MaxBaseOrders)
   {
      Print("V201 signal detected but blocked: MaxBaseOrders reached. Count=", CountBaseOrders());
      return;
   }

   if(signal == 1)
   {
      int ticketBuy = OpenOrder(OP_BUY, LotSize, "V201_MACD_BASE_BUY");
      if(ticketBuy > 0)
         lastSignalText = "BUY ORDER";
   }

   if(signal == -1)
   {
      int ticketSell = OpenOrder(OP_SELL, LotSize, "V201_MACD_BASE_SELL");
      if(ticketSell > 0)
         lastSignalText = "SELL ORDER";
   }

   lastSignalDirection = signal;
   lastSignalTime = signalTime;
}

//+------------------------------------------------------------------+
int dxb_GetMACDSignal_V201()
{
   double macd1 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 1);
   double sig1  = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_SIGNAL, 1);

   double macd2 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_MAIN, 2);
   double sig2  = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA,
                        PRICE_CLOSE, MODE_SIGNAL, 2);

   double delta1 = macd1 - sig1; // just closed candle
   double delta2 = macd2 - sig2; // previous candle

   // TradingView: ta.crossover(delta, 0)
   if(delta1 > 0 && delta2 <= 0)
      return 1; // BUY

   // TradingView: ta.crossunder(delta, 0)
   if(delta1 < 0 && delta2 >= 0)
      return -1; // SELL

   return 0;
}

//+------------------------------------------------------------------+
int OpenOrder(int orderType, double lot, string comment)
{
   RefreshRates();

   double price = (orderType == OP_BUY) ? Ask : Bid;
   color  clr   = (orderType == OP_BUY) ? clrLime : clrRed;

   int ticket = OrderSend(Symbol(),
                          orderType,
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
      Print("OrderSend failed. Error: ", GetLastError(), " Comment: ", comment);
      return -1;
   }

   Print("Order opened. Ticket: ", ticket, " Comment: ", comment);
   return ticket;
}

//+------------------------------------------------------------------+
//| Basket TP and Basket SL                                          |
//+------------------------------------------------------------------+
void ManageTrades()
{
   double basketProfit = GetTotalOpenProfit();

   if(CountOpenTrades() <= 0)
      return;

   if(basketProfit >= ProfitTargetUSD)
   {
      Print("Basket TP Hit: ", basketProfit);
      CloseAllOrders();
      return;
   }

   if(UseStopLoss && basketProfit <= -StopLossUSD)
   {
      Print("Basket SL Hit: ", basketProfit);
      CloseAllOrders();
      return;
   }
}

//+------------------------------------------------------------------+
//| Recovery by raw price difference from latest losing order         |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
{
   if(CountRecoveryOrders() >= MaxRecoveryOrders)
      return;

   int losingType = GetWorstLosingOrderType();

   if(losingType == -1)
      return;

   double lastPrice = GetLatestLosingOrderPrice(losingType);

   if(lastPrice <= 0)
      return;

   RefreshRates();

   double priceDifference = 0;

   if(losingType == OP_BUY)
      priceDifference = lastPrice - Bid;

   if(losingType == OP_SELL)
      priceDifference = Ask - lastPrice;

   int nextRecoveryLevel = CountRecoveryOrders() + 1;

   double requiredGap = GetRecoveryGapPrice(nextRecoveryLevel);
   double recoveryLot = GetRecoveryLot(nextRecoveryLevel);

   if(priceDifference < requiredGap)
      return;

   if(losingType == OP_BUY)
   {
      OpenOrder(OP_BUY, recoveryLot, "V201_MACD_RECOVERY_BUY_" + IntegerToString(nextRecoveryLevel));
      return;
   }

   if(losingType == OP_SELL)
   {
      OpenOrder(OP_SELL, recoveryLot, "V201_MACD_RECOVERY_SELL_" + IntegerToString(nextRecoveryLevel));
      return;
   }
}

//+------------------------------------------------------------------+
double GetRecoveryGapPrice(int level)
{
   if(level == 1) return RecoveryGap1Price;
   if(level == 2) return RecoveryGap2Price;
   if(level == 3) return RecoveryGap3Price;

   return RecoveryGap1Price;
}

//+------------------------------------------------------------------+
double GetLatestLosingOrderPrice(int orderType)
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

      if(OrderType() != orderType)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= RecoveryStartLossUSD)
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
int GetWorstLosingOrderType()
{
   double worstProfit = 0;
   int worstType = -1;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < RecoveryStartLossUSD && profit < worstProfit)
      {
         worstProfit = profit;
         worstType = OrderType();
      }
   }

   return worstType;
}

//+------------------------------------------------------------------+
double GetRecoveryLot(int level)
{
   if(level == 1) return Recovery1Lot;
   if(level == 2) return Recovery2Lot;
   if(level == 3) return Recovery3Lot;

   return Recovery1Lot;
}

//+------------------------------------------------------------------+
void CloseOrder(int ticket)
{
   if(!OrderSelect(ticket, SELECT_BY_TICKET))
      return;

   RefreshRates();

   bool result = false;

   if(OrderType() == OP_BUY)
      result = OrderClose(ticket, OrderLots(), Bid, Slippage, clrRed);

   if(OrderType() == OP_SELL)
      result = OrderClose(ticket, OrderLots(), Ask, Slippage, clrRed);

   if(result)
      Print("Order closed. Ticket: ", ticket);
   else
      Print("Order close failed. Error: ", GetLastError());
}

//+------------------------------------------------------------------+
void CloseAllOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      RefreshRates();

      bool result = false;

      if(OrderType() == OP_BUY)
         result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);

      if(OrderType() == OP_SELL)
         result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

      if(result)
         Print("Basket closed ticket: ", OrderTicket());
      else
         Print("Basket close failed. Error: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
double GetTotalOpenProfit()
{
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOpenTrades()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      total++;
   }

   return total;
}

//+------------------------------------------------------------------+
int CountBaseOrders()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(StringFind(OrderComment(), "BASE") >= 0)
         total++;
   }

   return total;
}

//+------------------------------------------------------------------+
int CountRecoveryOrders()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(StringFind(OrderComment(), "RECOVERY") >= 0)
         total++;
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOrders(int type)
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() == type)
         total++;
   }

   return total;
}

//+------------------------------------------------------------------+
bool RecoveryExists(string comment)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderComment() == comment)
         return true;
   }

   return false;
}

//+------------------------------------------------------------------+
void DrawEMA20Line()
{
   string emaName = "EMA20_LINE";

   if(ObjectFind(0, emaName) < 0)
   {
      ObjectCreate(0, emaName, OBJ_TREND, 0, 0, 0);
      ObjectSetInteger(0, emaName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, emaName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, emaName, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, emaName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, emaName, OBJPROP_BACK, false);
   }

   datetime time1 = iTime(Symbol(), TimeFrame, 50);
   datetime time2 = iTime(Symbol(), TimeFrame, 0);

   double ema1 = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 50);
   double ema2 = iMA(Symbol(), TimeFrame, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 0);

   ObjectMove(0, emaName, 0, time1, ema1);
   ObjectMove(0, emaName, 1, time2, ema2);
}

//+------------------------------------------------------------------+
//| Signal Drawing                                                   |
//+------------------------------------------------------------------+
void DrawSignalOnChart(int signal, datetime signalTime, double closePrice, string labelText)
{
   if(!ShowSignalArrows && !ShowSignalLabels)
      return;

   string dirText = (signal == 1) ? "BUY" : "SELL";
   string nameBase = SIG_PREFIX + dirText + "_" + IntegerToString((int)signalTime);

   double high1 = iHigh(Symbol(), TimeFrame, 1);
   double low1  = iLow(Symbol(), TimeFrame, 1);
   double gap   = SignalArrowGap * Point;
   double arrowPrice = (signal == 1) ? (low1 - gap) : (high1 + gap);
   double textPrice  = (signal == 1) ? (low1 - gap * 2.2) : (high1 + gap * 2.2);

   color sigColor = (signal == 1) ? clrLime : clrTomato;
   int arrowCode  = (signal == 1) ? 233 : 234; // Wingdings up/down arrows

   if(ShowSignalArrows)
   {
      string arrowName = nameBase + "_ARROW";
      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, signalTime, arrowPrice);
         ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, arrowCode);
         ObjectSetInteger(0, arrowName, OBJPROP_COLOR, sigColor);
         ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
      }
   }

   if(ShowSignalLabels)
   {
      string textName = nameBase + "_TEXT";
      if(ObjectFind(0, textName) < 0)
      {
         ObjectCreate(0, textName, OBJ_TEXT, 0, signalTime, textPrice);
         ObjectSetText(textName, labelText, 9, "Arial Bold", sigColor);
         ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
      }
   }
}

//+------------------------------------------------------------------+
//| Professional Dashboard                                           |
//+------------------------------------------------------------------+
void DrawDashboard()
{
   if(!ShowDashboard)
      return;

   int x = DashboardX;
   int y = DashboardY;
   int w = 330;
   int h = 300;

   DrawRect(DASH_PREFIX + "BG", x, y, w, h, clrBlack, clrDimGray);
   DrawLabel(DASH_PREFIX + "TITLE", "V201 MACD HISTOGRAM CROSS EA", x + 12, y + 10, clrGold, 10, "Arial Bold");
   DrawLabel(DASH_PREFIX + "SUB", Symbol() + "  |  " + TFToString(TimeFrame) + "  |  Magic " + IntegerToString(MagicNumber), x + 12, y + 30, clrSilver, 8, "Arial");

   double macd1 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE, MODE_MAIN, 1);
   double sig1  = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE, MODE_SIGNAL, 1);
   double macd2 = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE, MODE_MAIN, 2);
   double sig2  = iMACD(Symbol(), TimeFrame, FastEMA, SlowEMA, SignalSMA, PRICE_CLOSE, MODE_SIGNAL, 2);
   double delta1 = macd1 - sig1;
   double delta2 = macd2 - sig2;

   int liveSignal = dxb_GetMACDSignal_V201();
   string signalText = "WAIT";
   color signalColor = clrSilver;
   if(liveSignal == 1) { signalText = "BUY CROSS"; signalColor = clrLime; }
   if(liveSignal == -1){ signalText = "SELL CROSS"; signalColor = clrTomato; }

   double basketProfit = GetTotalOpenProfit();
   color profitColor = basketProfit >= 0 ? clrLime : clrTomato;

   int row = y + 58;
   DrawDashRow("Status", "RUNNING", x, row, clrAqua); row += 20;
   DrawDashRow("Signal", signalText, x, row, signalColor); row += 20;
   DrawDashRow("MACD", DoubleToString(macd1, Digits), x, row, clrWhite); row += 20;
   DrawDashRow("Signal Line", DoubleToString(sig1, Digits), x, row, clrWhite); row += 20;
   DrawDashRow("Delta Now", DoubleToString(delta1, Digits), x, row, delta1 >= 0 ? clrLime : clrTomato); row += 20;
   DrawDashRow("Delta Prev", DoubleToString(delta2, Digits), x, row, delta2 >= 0 ? clrLime : clrTomato); row += 20;
   DrawDashRow("Open Orders", IntegerToString(CountOpenTrades()) + "  BUY " + IntegerToString(CountOrders(OP_BUY)) + " / SELL " + IntegerToString(CountOrders(OP_SELL)), x, row, clrWhite); row += 20;
   DrawDashRow("Base Orders", IntegerToString(CountBaseOrders()) + " / " + IntegerToString(MaxBaseOrders), x, row, CountBaseOrders() >= MaxBaseOrders ? clrTomato : clrWhite); row += 20;
   DrawDashRow("Recovery", (EnableRecovery ? "ON" : "OFF") + StringConcatenate("  ", CountRecoveryOrders(), " / ", MaxRecoveryOrders), x, row, EnableRecovery ? clrLime : clrTomato); row += 20;
   DrawDashRow("Basket P/L", "$" + DoubleToString(basketProfit, 2), x, row, profitColor); row += 20;
   DrawDashRow("TP / SL", "$" + DoubleToString(ProfitTargetUSD, 2) + " / " + (UseStopLoss ? "$" + DoubleToString(StopLossUSD, 2) : "OFF"), x, row, clrWhite); row += 20;

   string lastText = lastSignalText;
   if(lastSignalTime > 0)
      lastText = lastText + " @ " + TimeToString(lastSignalTime, TIME_DATE|TIME_MINUTES);
   DrawDashRow("Last Signal", lastText, x, row, lastSignalDirection == 1 ? clrLime : (lastSignalDirection == -1 ? clrTomato : clrSilver)); row += 20;

   string modeText = AllowMultipleBaseOrders ? "MULTIPLE BASE ORDERS" : "ONE TRADE ONLY";
   DrawLabel(DASH_PREFIX + "FOOT", modeText, x + 12, y + h - 25, AllowMultipleBaseOrders ? clrLime : clrOrange, 8, "Arial Bold");
}

//+------------------------------------------------------------------+
void DrawDashRow(string leftText, string rightText, int x, int y, color rightColor)
{
   DrawLabel(DASH_PREFIX + "L_" + leftText, leftText + ":", x + 14, y, clrSilver, 8, "Arial");
   DrawLabel(DASH_PREFIX + "R_" + leftText, rightText, x + 135, y, rightColor, 8, "Arial Bold");
}

//+------------------------------------------------------------------+
void DrawRect(string name, int x, int y, int width, int height, color bgColor, color borderColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color textColor, int fontSize, string fontName)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, DashboardCorner);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, prefix) == 0)
         ObjectDelete(0, name);
   }
}

//+------------------------------------------------------------------+
string TFToString(int tf)
{
   if(tf == PERIOD_M1)  return "M1";
   if(tf == PERIOD_M5)  return "M5";
   if(tf == PERIOD_M15) return "M15";
   if(tf == PERIOD_M30) return "M30";
   if(tf == PERIOD_H1)  return "H1";
   if(tf == PERIOD_H4)  return "H4";
   if(tf == PERIOD_D1)  return "D1";
   if(tf == PERIOD_W1)  return "W1";
   if(tf == PERIOD_MN1) return "MN1";
   return IntegerToString(tf);
}
//+------------------------------------------------------------------+
