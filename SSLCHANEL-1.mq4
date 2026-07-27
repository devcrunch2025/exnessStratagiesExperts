//+------------------------------------------------------------------+
//|                 SSL Channel Cross EA - ADVANCED                  |
//|              With Enhanced Graphics & Statistics                 |
//+------------------------------------------------------------------+
#property strict

//+------------------------------------------------------------------+
//| Input Parameters
//+------------------------------------------------------------------+
input int      SSLPeriod = 10;              // SSL Channel Period
input double   RiskPercent = 1.0;           // Risk per trade
input int      TakeProfit = 100;            // Take Profit in pips
input int      StopLoss = 50;               // Stop Loss in pips
input int      MaxSpread = 20;              // Maximum spread
input bool     UseTrailingStop = false;     // Enable trailing stop
input int      TrailingStop = 30;           // Trailing stop distance
input string   TradeComment = "SSL_Channel";

// Visual Settings
input bool     ShowSSLBands = true;         // Show SSL channels
input bool     ShowSignals = true;          // Show arrows
input bool     ShowDashboard = true;        // Show dashboard
input bool     ShowPriceLevels = true;      // Show price levels for orders
input bool     ShowPriceInfo = true;        // Show current price box
input int      DashboardX = 10;             // Dashboard X
input int      DashboardY = 40;             // Dashboard Y
input color    DashboardBG = C'30,30,30';   // Dashboard background
input color    BullishColor = clrLime;      // Bullish color
input color    BearishColor = clrRed;       // Bearish color
input bool     ShowChannelFill = true;      // Show channel background

//+------------------------------------------------------------------+
//| Global Variables
//+------------------------------------------------------------------+
int slippage = 10;
double lastSslUp = 0;
double lastSslDown = 0;
double currentSslUp = 0;
double currentSslDown = 0;
int hlv = 0;
int lastHlv = 0;

struct TradeStats
{
   int total;
   int wins;
   int losses;
   double profit;
   int today;
   double profitToday;
   double maxDrawdown;
   double avgWin;
   double avgLoss;
};

TradeStats stats;

//+------------------------------------------------------------------+
//| Expert initialization function
//+------------------------------------------------------------------+
int OnInit()
{
   if(Digits == 0)
   {
      Alert("Invalid currency pair");
      return(INIT_FAILED);
   }
   
   Print("SSL Channel Advanced EA initialized");
   Print("Graphics Enabled: SSL=", ShowSSLBands, " Dashboard=", ShowDashboard);
   
   stats.total = 0;
   stats.wins = 0;
   stats.losses = 0;
   stats.profit = 0;
   stats.today = 0;
   stats.profitToday = 0;
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("SSL Channel Advanced EA deinitialized");
   ObjectsDeleteAll(0, -1);
}

//+------------------------------------------------------------------+
//| Expert tick function
//+------------------------------------------------------------------+
void OnTick()
{
   if(Bars < SSLPeriod + 5)
      return;
   
   if(Ask - Bid > MaxSpread * Point)
      return;
   
   lastSslUp = currentSslUp;
   lastSslDown = currentSslDown;
   lastHlv = hlv;
   
   CalculateSSLChannel();
   
   if(ShowSSLBands)
      DrawSSLBandsAdvanced();
   
   bool longCondition = CrossoverDetected(lastSslUp, lastSslDown, currentSslUp, currentSslDown);
   bool shortCondition = CrossunderDetected(lastSslUp, lastSslDown, currentSslUp, currentSslDown);
   
   if(longCondition)
   {
      if(ShowSignals)
         DrawSignalArrow(1);
      CloseAllShortPositions();
      OpenLongPosition();
   }
   
   if(shortCondition)
   {
      if(ShowSignals)
         DrawSignalArrow(-1);
      CloseAllLongPositions();
      OpenShortPosition();
   }
   
   if(ShowPriceLevels)
      DrawPriceLevels();
   
   if(UseTrailingStop)
      UpdateTrailingStops();
   
   if(ShowDashboard)
      UpdateAdvancedDashboard();
   
   if(ShowPriceInfo)
      DrawPriceInfo();
}

//+------------------------------------------------------------------+
//| Calculate SSL Channel
//+------------------------------------------------------------------+
void CalculateSSLChannel()
{
   double smaHigh = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_HIGH, 1);
   double smaLow = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_LOW, 1);
   double close = Close[1];
   
   if(close > smaHigh)
      hlv = 1;
   else if(close < smaLow)
      hlv = -1;
   
   if(hlv < 0)
   {
      currentSslDown = smaHigh;
      currentSslUp = smaLow;
   }
   else
   {
      currentSslDown = smaLow;
      currentSslUp = smaHigh;
   }
}

//+------------------------------------------------------------------+
//| Draw Advanced SSL Bands with Channel Fill
//+------------------------------------------------------------------+
void DrawSSLBandsAdvanced()
{
   ObjectDelete(0, "SSL_UP_LINE");
   ObjectDelete(0, "SSL_DOWN_LINE");
   ObjectDelete(0, "SSL_CHANNEL_FILL");
   
   // Draw SSL Up
   if(ObjectCreate(0, "SSL_UP_LINE", OBJ_HLINE, 0, 0, currentSslUp))
   {
      ObjectSetInteger(0, "SSL_UP_LINE", OBJPROP_COLOR, BullishColor);
      ObjectSetInteger(0, "SSL_UP_LINE", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SSL_UP_LINE", OBJPROP_BACK, false);
   }
   
   // Draw SSL Down
   if(ObjectCreate(0, "SSL_DOWN_LINE", OBJ_HLINE, 0, 0, currentSslDown))
   {
      ObjectSetInteger(0, "SSL_DOWN_LINE", OBJPROP_COLOR, BearishColor);
      ObjectSetInteger(0, "SSL_DOWN_LINE", OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, "SSL_DOWN_LINE", OBJPROP_BACK, false);
   }
   
   // Draw channel fill
   if(ShowChannelFill)
   {
      color fillColor = (hlv > 0) ? C'0,80,0' : C'80,0,0';
      if(ObjectCreate(0, "SSL_CHANNEL_FILL", OBJ_RECTANGLE, 0, Time[5], currentSslUp, Time[0], currentSslDown))
      {
         ObjectSetInteger(0, "SSL_CHANNEL_FILL", OBJPROP_COLOR, fillColor);
         ObjectSetInteger(0, "SSL_CHANNEL_FILL", OBJPROP_BACK, true);
         ObjectSetInteger(0, "SSL_CHANNEL_FILL", OBJPROP_FILL, true);
      }
   }
   
   // Draw SSL values as text
   DrawSSLLabels();
}

//+------------------------------------------------------------------+
//| Draw SSL Band Labels
//+------------------------------------------------------------------+
void DrawSSLLabels()
{
   ObjectDelete(0, "SSL_UP_LABEL");
   ObjectDelete(0, "SSL_DOWN_LABEL");
   
   if(ObjectCreate(0, "SSL_UP_LABEL", OBJ_TEXT, 0, Time[0], currentSslUp))
   {
      ObjectSetString(0, "SSL_UP_LABEL", OBJPROP_TEXT, "SSL Up: " + DoubleToString(currentSslUp, Digits));
      ObjectSetInteger(0, "SSL_UP_LABEL", OBJPROP_COLOR, BullishColor);
      ObjectSetInteger(0, "SSL_UP_LABEL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SSL_UP_LABEL", OBJPROP_FONT, "Arial");
   }
   
   if(ObjectCreate(0, "SSL_DOWN_LABEL", OBJ_TEXT, 0, Time[0], currentSslDown))
   {
      ObjectSetString(0, "SSL_DOWN_LABEL", OBJPROP_TEXT, "SSL Down: " + DoubleToString(currentSslDown, Digits));
      ObjectSetInteger(0, "SSL_DOWN_LABEL", OBJPROP_COLOR, BearishColor);
      ObjectSetInteger(0, "SSL_DOWN_LABEL", OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, "SSL_DOWN_LABEL", OBJPROP_FONT, "Arial");
   }
}

//+------------------------------------------------------------------+
//| Draw Signal Arrows
//+------------------------------------------------------------------+
void DrawSignalArrow(int direction)
{
   static int count = 0;
   string name;
   
   if(direction > 0)
   {
      name = "SIGNAL_UP_" + IntegerToString(count);
      if(ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], Low[1] - 100 * Point))
      {
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 241);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrGreen);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
      }
   }
   else
   {
      name = "SIGNAL_DOWN_" + IntegerToString(count);
      if(ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], High[1] + 100 * Point))
      {
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 242);
         ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 4);
      }
   }
   
   count++;
   if(count > 50) count = 0;
}

//+------------------------------------------------------------------+
//| Draw Price Levels for Orders
//+------------------------------------------------------------------+
void DrawPriceLevels()
{
   ObjectsDeleteAll(0, -1, OBJ_HLINE);
   
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      string ticket = IntegerToString(OrderTicket());
      
      // Entry line
      if(ObjectCreate(0, "ENTRY_" + ticket, OBJ_HLINE, 0, 0, OrderOpenPrice()))
      {
         ObjectSetInteger(0, "ENTRY_" + ticket, OBJPROP_COLOR, clrBlue);
         ObjectSetInteger(0, "ENTRY_" + ticket, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, "ENTRY_" + ticket, OBJPROP_STYLE, STYLE_SOLID);
      }
      
      // Stop Loss line
      if(OrderStopLoss() != 0 && ObjectCreate(0, "SL_" + ticket, OBJ_HLINE, 0, 0, OrderStopLoss()))
      {
         ObjectSetInteger(0, "SL_" + ticket, OBJPROP_COLOR, clrDarkRed);
         ObjectSetInteger(0, "SL_" + ticket, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "SL_" + ticket, OBJPROP_STYLE, STYLE_DASHDOT);
      }
      
      // Take Profit line
      if(OrderTakeProfit() != 0 && ObjectCreate(0, "TP_" + ticket, OBJ_HLINE, 0, 0, OrderTakeProfit()))
      {
         ObjectSetInteger(0, "TP_" + ticket, OBJPROP_COLOR, clrDarkGreen);
         ObjectSetInteger(0, "TP_" + ticket, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, "TP_" + ticket, OBJPROP_STYLE, STYLE_DASHDOT);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Price Information Box
//+------------------------------------------------------------------+
void DrawPriceInfo()
{
   int x = DashboardX;
   int y = DashboardY + 450;
   
   // Background
   ObjectDelete(0, "PRICE_INFO_BG");
   if(ObjectCreate(0, "PRICE_INFO_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_XSIZE, 300);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_YSIZE, 100);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_BGCOLOR, DashboardBG);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_BORDER_COLOR, clrWhite);
      // ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_BORDER_WIDTH, 2);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "PRICE_INFO_BG", OBJPROP_BACK, true);
   }
   
   // Price info text
   string priceInfo = "CURRENT PRICE\n";
   priceInfo += "Bid: " + DoubleToString(Bid, Digits) + "\n";
   priceInfo += "Ask: " + DoubleToString(Ask, Digits) + "\n";
   priceInfo += "Spread: " + DoubleToString((Ask - Bid) / Point, 0) + " pips";
   
   DrawDashboardText(priceInfo, x + 5, y + 5, 9, clrWhite);
}

//+------------------------------------------------------------------+
//| Update Advanced Dashboard
//+------------------------------------------------------------------+
void UpdateAdvancedDashboard()
{
   CalculateAdvancedStats();
   DrawDashboardBackground();
   DrawAdvancedStats();
}

//+------------------------------------------------------------------+
//| Calculate Advanced Statistics
//+------------------------------------------------------------------+
void CalculateAdvancedStats()
{
   stats.total = 0;
   stats.wins = 0;
   stats.losses = 0;
   stats.profit = 0;
   stats.profitToday = 0;
   
   double totalWinAmount = 0;
   double totalLossAmount = 0;
   int winCount = 0;
   int lossCount = 0;
   
   // Read history
   int historyTotal = OrdersHistoryTotal();
   for(int i = 0; i < historyTotal; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderCloseTime() > TimeCurrent() - 86400) // Today
      {
         stats.today++;
         stats.profitToday += OrderProfit() + OrderCommission() + OrderSwap();
      }
      
      stats.total++;
      double orderProfit = OrderProfit() + OrderCommission() + OrderSwap();
      stats.profit += orderProfit;
      
      if(orderProfit > 0)
      {
         stats.wins++;
         totalWinAmount += orderProfit;
         winCount++;
      }
      else
      {
         stats.losses++;
         totalLossAmount += orderProfit;
         lossCount++;
      }
   }
   
   if(winCount > 0)
      stats.avgWin = totalWinAmount / winCount;
   
   if(lossCount > 0)
      stats.avgLoss = totalLossAmount / lossCount;
}

//+------------------------------------------------------------------+
//| Draw Dashboard Background
//+------------------------------------------------------------------+
void DrawDashboardBackground()
{
   ObjectDelete(0, "DASHBOARD_BG");
   
   if(ObjectCreate(0, "DASHBOARD_BG", OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_XDISTANCE, DashboardX);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_YDISTANCE, DashboardY);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_XSIZE, 330);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_YSIZE, 440);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_BGCOLOR, DashboardBG);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_BORDER_COLOR, clrGold);
      // ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_BORDER_WIDTH, 2);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, "DASHBOARD_BG", OBJPROP_BACK, true);
   }
}

//+------------------------------------------------------------------+
//| Draw Advanced Statistics
//+------------------------------------------------------------------+
void DrawAdvancedStats()
{
   int x = DashboardX + 10;
   int y = DashboardY + 10;
   
   // Title
   DrawDashboardText("═ SSL CHANNEL EA DASHBOARD ═", x, y, 11, clrGold);
   y += 25;
   
   // Account Section
   DrawDashboardText("ACCOUNT", x, y, 10, clrYellow);
   y += 15;
   DrawDashboardText("Balance: $" + DoubleToString(AccountBalance(), 2), x, y, 9, clrWhite);
   y += 14;
   DrawDashboardText("Equity: $" + DoubleToString(AccountEquity(), 2), x, y, 9, clrWhite);
   y += 14;
   DrawDashboardText("Margin: $" + DoubleToString(AccountFreeMargin(), 2), x, y, 9, clrWhite);
   y += 20;
   
   // SSL Section
   DrawDashboardText("SSL CHANNEL", x, y, 10, clrYellow);
   y += 15;
   DrawDashboardText("Up: " + DoubleToString(currentSslUp, Digits), x, y, 9, BullishColor);
   y += 14;
   DrawDashboardText("Down: " + DoubleToString(currentSslDown, Digits), x, y, 9, BearishColor);
   y += 14;
   color dirColor = (hlv > 0) ? BullishColor : BearishColor;
   string dirText = (hlv > 0) ? "BULLISH" : "BEARISH";
   DrawDashboardText("Trend: " + dirText, x, y, 9, dirColor);
   y += 20;
   
   // Statistics Section
   DrawDashboardText("STATISTICS", x, y, 10, clrYellow);
   y += 15;
   DrawDashboardText("Total Trades: " + IntegerToString(stats.total), x, y, 9, clrWhite);
   y += 14;
   DrawDashboardText("Wins: " + IntegerToString(stats.wins) + 
      " | Losses: " + IntegerToString(stats.losses), x, y, 9, clrWhite);
   y += 14;
   
   int winRate = (stats.total > 0) ? (int)((stats.wins * 100.0) / stats.total) : 0;
   color rateColor = (winRate >= 50) ? clrGreen : clrRed;
   DrawDashboardText("Win Rate: " + IntegerToString(winRate) + "%", x, y, 9, rateColor);
   y += 20;
   
   // Profit Section
   DrawDashboardText("PROFITABILITY", x, y, 10, clrYellow);
   y += 15;
   color profitColor = (stats.profit >= 0) ? clrGreen : clrRed;
   DrawDashboardText("Total P/L: $" + DoubleToString(stats.profit, 2), x, y, 9, profitColor);
   y += 14;
   color todayColor = (stats.profitToday >= 0) ? clrGreen : clrRed;
   DrawDashboardText("Today P/L: $" + DoubleToString(stats.profitToday, 2), x, y, 9, todayColor);
   y += 14;
   DrawDashboardText("Avg Win: $" + DoubleToString(stats.avgWin, 2), x, y, 9, clrGreen);
   y += 14;
   DrawDashboardText("Avg Loss: $" + DoubleToString(stats.avgLoss, 2), x, y, 9, clrRed);
}

//+------------------------------------------------------------------+
//| Draw Dashboard Text
//+------------------------------------------------------------------+
void DrawDashboardText(string text, int x, int y, int fontSize, color textColor)
{
   string objName = "DTEXT_" + IntegerToString(rand());
   ObjectDelete(0, objName);
   
   if(ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, objName, OBJPROP_TEXT, text);
      ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetString(0, objName, OBJPROP_FONT, "Courier New");
      ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
   }
}

//+------------------------------------------------------------------+
//| Crossover Detection
//+------------------------------------------------------------------+
bool CrossoverDetected(double prevUp, double prevDown, double currUp, double currDown)
{
   if(prevUp <= prevDown && currUp > currDown)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Crossunder Detection
//+------------------------------------------------------------------+
bool CrossunderDetected(double prevUp, double prevDown, double currUp, double currDown)
{
   if(prevUp >= prevDown && currUp < currDown)
      return true;
   return false;
}

//+------------------------------------------------------------------+
//| Position Size Calculation
//+------------------------------------------------------------------+
double CalculateLotSize(int stopLossInPips)
{
   if(stopLossInPips <= 0)
      return 0.01;
   
   double riskAmount = (AccountBalance() * RiskPercent) / 100;
   double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double lotSize = riskAmount / (stopLossInPips * pipValue);
   
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   
   lotSize = MathMax(minLot, MathMin(maxLot, lotSize));
   lotSize = MathFloor(lotSize / lotStep) * lotStep;
   
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Open Long Position
//+------------------------------------------------------------------+
void OpenLongPosition()
{
   if(HasOpenLongPosition())
      return;
   
   double lotSize = CalculateLotSize(StopLoss);
   double stopLoss = NormalizeDouble(Bid - StopLoss * Point, Digits);
   double takeProfit = NormalizeDouble(Ask + TakeProfit * Point, Digits);
   
   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, slippage, stopLoss, takeProfit, 
                          TradeComment, 0, 0, clrGreen);
   
   if(ticket > 0)
   {
      Print("Long opened: Ticket=", ticket);
      stats.total++;
      stats.today++;
   }
}

//+------------------------------------------------------------------+
//| Open Short Position
//+------------------------------------------------------------------+
void OpenShortPosition()
{
   if(HasOpenShortPosition())
      return;
   
   double lotSize = CalculateLotSize(StopLoss);
   double stopLoss = NormalizeDouble(Ask + StopLoss * Point, Digits);
   double takeProfit = NormalizeDouble(Bid - TakeProfit * Point, Digits);
   
   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, slippage, stopLoss, takeProfit,
                          TradeComment, 0, 0, clrRed);
   
   if(ticket > 0)
   {
      Print("Short opened: Ticket=", ticket);
      stats.total++;
      stats.today++;
   }
}

//+------------------------------------------------------------------+
//| Close All Long Positions
//+------------------------------------------------------------------+
void CloseAllLongPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderType() == OP_BUY)
      {
         OrderClose(OrderTicket(), OrderOpenPrice(), Bid, slippage, clrRed);
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Short Positions
//+------------------------------------------------------------------+
void CloseAllShortPositions()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderType() == OP_SELL)
      {
         OrderClose(OrderTicket(), OrderOpenPrice(), Ask, slippage, clrGreen);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Long Position
//+------------------------------------------------------------------+
bool HasOpenLongPosition()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderType() == OP_BUY)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check Short Position
//+------------------------------------------------------------------+
bool HasOpenShortPosition()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() == Symbol() && OrderType() == OP_SELL)
         return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Update Trailing Stops
//+------------------------------------------------------------------+
void UpdateTrailingStops()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      
      if(OrderSymbol() != Symbol())
         continue;
      
      if(OrderType() == OP_BUY)
      {
         double newSL = Bid - TrailingStop * Point;
         if(newSL > OrderStopLoss())
            OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrGreen);
      }
      else if(OrderType() == OP_SELL)
      {
         double newSL = Ask + TrailingStop * Point;
         if(newSL < OrderStopLoss())
            OrderModify(OrderTicket(), OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrRed);
      }
   }
}

//+------------------------------------------------------------------+
//| End of Expert Advisor
//+------------------------------------------------------------------+
