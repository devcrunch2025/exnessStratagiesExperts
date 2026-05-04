//+------------------------------------------------------------------+
//| DXB SAR Session Profit Booker EA V3.10 XAUUSD                               |
//| SAR BUY/SELL + Sessions + Auto Lot + SAR Chart Dots               |
//+------------------------------------------------------------------+
#property strict
#property version "3.10"

//====================================================================
// ORDER COOLDOWN
//====================================================================
datetime g_lastOrderTime = 0;
// INPUTS
//====================================================================
extern int    MagicNumber = 989899; // XAUUSD version

//---------------- GENERAL ----------------
extern bool   ShowDashboard      = true;
extern bool   OneTradePerCandle  = true;
extern int    Slippage           = 50; // XAUUSD can move fast

//---------------- LOT / RECOVERY ----------------
extern bool   Auto_Increment_Lots = true;
extern double BaseLot             = 0.01;
extern double LotIncrement        = 0.01;
extern double MaxLot              = 0.03; // safer for XAUUSD
extern bool   ResetLotAfterProfit = true;

//---------------- VISUALS ----------------
extern bool ShowSARDots      = true;
extern int  SARDotsLookback  = 120;
extern bool ShowSignalArrows = true;

//---------------- SESSION ENABLE ----------------
extern bool EnableAsiaSession = true;
extern bool EnableEUSession   = true;
extern bool EnableUSSession   = true;
extern bool EnableNYSession   = true;

//---------------- ASIA SETTINGS ----------------
extern double Asia_TP              = 1;
extern double Asia_SL              = 5.0;
extern int    Asia_MaxProfitOrders = 3;
extern int    Asia_MaxOrders       = 6;
extern int    Asia_MaxSpread       = 350;
extern double Asia_SAR_Period      = 2.0;
extern int    Asia_SAR_StepSize    = 100;
extern int    Asia_SAR_Accel       = 10;

//---------------- EU SETTINGS ----------------
extern double EU_TP              = 1;
extern double EU_SL              = 6.0;
extern int    EU_MaxProfitOrders = 3;
extern int    EU_MaxOrders       = 5;
extern int    EU_MaxSpread       = 300;
extern double EU_SAR_Period      = 2.0;
extern int    EU_SAR_StepSize    = 100;
extern int    EU_SAR_Accel       = 10;

//---------------- US SETTINGS ----------------
extern double US_TP              = 1.00;
extern double US_SL              = 7.0;
extern int    US_MaxProfitOrders = 2;
extern int    US_MaxOrders       = 4;
extern int    US_MaxSpread       = 250;
extern double US_SAR_Period      = 2.0;
extern int    US_SAR_StepSize    = 100;
extern int    US_SAR_Accel       = 10;

//---------------- NY SETTINGS ----------------
extern double NY_TP              = 1.00;
extern double NY_SL              = 8.0;
extern int    NY_MaxProfitOrders = 2;
extern int    NY_MaxOrders       = 4;
extern int    NY_MaxSpread       = 250;
extern double NY_SAR_Period      = 2.0;
extern int    NY_SAR_StepSize    = 100;
extern int    NY_SAR_Accel       = 10;

//---------------- SAFETY ----------------
extern int MaxTotalOrdersPerDay       = 18;
extern int MaxTotalProfitOrdersPerDay = 8;
extern int MaxOpenTrades              = 4; // safer for XAUUSD averaging
extern int MinSecondsBetweenRecoveryTrades = 300; // 5 minutes between averaging orders

//====================================================================
// GLOBALS
//====================================================================
datetime g_lastBarTime = 0;
datetime g_lastRecoveryTradeTime = 0;
int      g_today       = -1;

string g_sessionName = "NONE";

int g_totalOrdersToday       = 0;
int g_totalProfitOrdersToday = 0;
int g_totalLossOrdersToday   = 0;

double g_totalProfitToday = 0.0;
double g_totalLossToday   = 0.0;

//---------------- AUTO LOT GLOBALS ----------------
double g_currentLot       = 0.01;
bool   g_lastTradeWasLoss = false;
int    g_lossStreak       = 0;

// Session counters
int asia_orders = 0;
int eu_orders   = 0;
int us_orders   = 0;
int ny_orders   = 0;

int asia_profit_orders = 0;
int eu_profit_orders   = 0;
int us_profit_orders   = 0;
int ny_profit_orders   = 0;

double asia_profit = 0;
double eu_profit   = 0;
double us_profit   = 0;
double ny_profit   = 0;

// Hourly stats
int    g_hourTrades[24];
int    g_hourWins[24];
int    g_hourLoss[24];
double g_hourProfit[24];

// Active session dynamic settings
double g_sessionTP        = 0.50;
double g_sessionSL        = 5.0;
int    g_sessionMaxSpread = 350;
double g_sarPeriod        = 2.0;
int    g_sarStepSize      = 100;
int    g_sarAccel         = 10;

//====================================================================
// INIT
//====================================================================
int OnInit()
{
   ResetDailyStats();
   g_currentLot = BaseLot;
   Print("DXB SAR Session Profit Booker EA V3.10 XAUUSD started.");
   return(INIT_SUCCEEDED);
}

//====================================================================
void OnDeinit(const int reason)
{
   Comment("");
   ObjectsDeleteAll(0, "DXB_SAR_");
}

//====================================================================
// MAIN
//====================================================================
void OnTick()
{
   ResetDailyStats();
   ApplySessionSettings();

   if(ShowSARDots)
      DrawSARDots();

   if(ShowDashboard)
      DrawDashboard();

   if(!IsSessionAllowed())
      return;

   if(!SpreadOK())
      return;

   //============================================================
   // ORDER COOLDOWN: Prevent new order if less than 1 minute since last order
   //============================================================
   if (TimeCurrent() - g_lastOrderTime < 60)
      return;

   //============================================================
   // MANAGE OPEN TRADE / PROFIT BOOKING
   //============================================================
   if(CountOpenTrades() > 0)
   {
      double openPL = GetTotalOpenProfit();

      Print("g_sessionTP "+ DoubleToString(g_sessionTP)+" openPL "+ DoubleToString(openPL));


      if(openPL >= g_sessionTP)
      {
         CloseAllTrades("Session TP Hit");

         g_lastTradeWasLoss = false;
         g_lossStreak = 0;

         if(ResetLotAfterProfit)
            g_currentLot = BaseLot;

         g_totalProfitOrdersToday++;
         g_totalProfitToday += openPL;

         AddSessionProfit(openPL);
         AddHourlyStats(true, openPL);

         g_lastBarTime = 0;
         return;
      }

      // XAUUSD safety: close basket if floating loss reaches session SL
      if(openPL <= -g_sessionSL)
      {
         CloseAllTrades("XAUUSD Session SL Hit");

         g_lastRecoveryTradeTime = TimeCurrent();

         g_lastTradeWasLoss = true;
         g_lossStreak++;

         g_totalLossOrdersToday++;
         g_totalLossToday += MathAbs(openPL);

         AddHourlyStats(false, openPL);

         g_lastBarTime = 0;
         return;
      }

      // Averaging down: open additional trade in same direction, keep old trades, whenever openPL < 0
      // XAUUSD protection: only once every MinSecondsBetweenRecoveryTrades seconds
      if(openPL < 0 && CountOpenTrades() < MaxOpenTrades &&
         (TimeCurrent() - g_lastRecoveryTradeTime) >= MinSecondsBetweenRecoveryTrades)
      {
         int lastType = -1;
         for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
            if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
               if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
               {
                  lastType = OrderType();
                  break;
               }
            }
         }
         double lot = GetNextLot();
         if(lastType == OP_BUY)
         {
            DrawSignalArrow("BUY");
            if(OpenTrade(OP_BUY, lot, "Averaging Down BUY"))
               g_lastOrderTime = TimeCurrent();
         }
         else if(lastType == OP_SELL)
         {
            DrawSignalArrow("SELL");
            if(OpenTrade(OP_SELL, lot, "Averaging Down SELL"))
               g_lastOrderTime = TimeCurrent();
         }

         g_lastTradeWasLoss = true;
         g_lossStreak++;

         g_totalLossOrdersToday++;
         g_totalLossToday += MathAbs(openPL);

         AddHourlyStats(false, openPL);

         g_lastBarTime = 0;
         return;
      }

      return;
   }

   //============================================================
   // DAILY AND SESSION LIMITS
   //============================================================
   if(g_totalOrdersToday >= MaxTotalOrdersPerDay)
      return;

   if(g_totalProfitOrdersToday >= MaxTotalProfitOrdersPerDay)
      return;

   if(SessionLimitReached())
      return;

   if(CountOpenTrades() >= MaxOpenTrades)
      return;

   //============================================================
   // ONE CANDLE ONE SIGNAL
   //============================================================
   if(OneTradePerCandle)
   {
      if(Time[0] == g_lastBarTime)
         return;

      g_lastBarTime = Time[0];
   }

   //============================================================
   // SAR SIGNAL ONLY
   //============================================================
   int signal = GetSARSignal();

   if(signal == 0)
      return;

   double lot = GetNextLot();

   if(signal == 1)
   {
      DrawSignalArrow("BUY");
      if(OpenTrade(OP_BUY, lot, "SAR BUY Signal"))
         g_lastOrderTime = TimeCurrent();
   }

   if(signal == -1)
   {
      DrawSignalArrow("SELL");
      if(OpenTrade(OP_SELL, lot, "SAR SELL Signal"))
         g_lastOrderTime = TimeCurrent();
   }
}

//====================================================================
// SESSION SETTINGS
// Server time assumed GMT+3
// Asia: 03:00–10:00
// EU:   10:00–16:00
// NY:   16:30–18:00
// US:   16:00–23:00
//====================================================================
void ApplySessionSettings()
{
   int h = TimeHour(TimeCurrent());
   int m = TimeMinute(TimeCurrent());

   bool isNY = (h == 16 && m >= 30) || (h == 17);
   bool isUS = (h >= 16 && h <= 22);
   bool isEU = (h >= 10 && h < 16);
   bool isAS = (h >= 3  && h < 10);

   if(isNY)
   {
      g_sessionName      = "NY";
      g_sessionTP        = NY_TP;
      g_sessionSL        = NY_SL;
      g_sessionMaxSpread = NY_MaxSpread;
      g_sarPeriod        = NY_SAR_Period;
      g_sarStepSize      = NY_SAR_StepSize;
      g_sarAccel         = NY_SAR_Accel;
   }
   else if(isUS)
   {
      g_sessionName      = "US";
      g_sessionTP        = US_TP;
      g_sessionSL        = US_SL;
      g_sessionMaxSpread = US_MaxSpread;
      g_sarPeriod        = US_SAR_Period;
      g_sarStepSize      = US_SAR_StepSize;
      g_sarAccel         = US_SAR_Accel;
   }
   else if(isEU)
   {
      g_sessionName      = "EU";
      g_sessionTP        = EU_TP;
      g_sessionSL        = EU_SL;
      g_sessionMaxSpread = EU_MaxSpread;
      g_sarPeriod        = EU_SAR_Period;
      g_sarStepSize      = EU_SAR_StepSize;
      g_sarAccel         = EU_SAR_Accel;
   }
   else if(isAS)
   {
      g_sessionName      = "ASIA";
      g_sessionTP        = Asia_TP;
      g_sessionSL        = Asia_SL;
      g_sessionMaxSpread = Asia_MaxSpread;
      g_sarPeriod        = Asia_SAR_Period;
      g_sarStepSize      = Asia_SAR_StepSize;
      g_sarAccel         = Asia_SAR_Accel;
   }
   else
   {
      g_sessionName = "DEAD";
   }
}

//====================================================================
bool IsSessionAllowed()
{
   if(g_sessionName == "ASIA" && EnableAsiaSession) return true;
   if(g_sessionName == "EU"   && EnableEUSession)   return true;
   if(g_sessionName == "US"   && EnableUSSession)   return true;
   if(g_sessionName == "NY"   && EnableNYSession)   return true;

   return false;
}

//====================================================================
bool SpreadOK()
{
   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   return spread <= g_sessionMaxSpread;
}

//====================================================================
// SAR BUY / SELL LOGIC
//====================================================================
int GetSARSignal()
{
   double step    = g_sarPeriod * g_sarStepSize / 10000.0;
   double maxStep = step * g_sarAccel;

   double sar1 = iSAR(Symbol(), 0, step, maxStep, 1);
   double sar2 = iSAR(Symbol(), 0, step, maxStep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2])
      return 1;

   if(sar1 > Close[1] && sar2 <= Close[2])
      return -1;

   return 0;
}

//====================================================================
// AUTO LOT
//====================================================================
double GetNextLot()
{
   if(!Auto_Increment_Lots)
   {
      g_currentLot = BaseLot;
      return NormalizeLot(BaseLot);
   }

   if(g_lastTradeWasLoss)
   {
      g_currentLot = BaseLot + (g_lossStreak * LotIncrement);

      if(g_currentLot > MaxLot)
         g_currentLot = MaxLot;
   }
   else
   {
      g_currentLot = BaseLot;
   }

   return NormalizeLot(g_currentLot);
}

//====================================================================
bool SessionLimitReached()
{
   if(g_sessionName == "ASIA")
   {
      if(asia_orders >= Asia_MaxOrders) return true;
      if(asia_profit_orders >= Asia_MaxProfitOrders) return true;
   }

   if(g_sessionName == "EU")
   {
      if(eu_orders >= EU_MaxOrders) return true;
      if(eu_profit_orders >= EU_MaxProfitOrders) return true;
   }

   if(g_sessionName == "US")
   {
      if(us_orders >= US_MaxOrders) return true;
      if(us_profit_orders >= US_MaxProfitOrders) return true;
   }

   if(g_sessionName == "NY")
   {
      if(ny_orders >= NY_MaxOrders) return true;
      if(ny_profit_orders >= NY_MaxProfitOrders) return true;
   }

   return false;
}

//====================================================================
bool OpenTrade(int type, double lot, string reason)
{
   RefreshRates();

   double price = 0;
   color clr = clrWhite;

   if(type == OP_BUY)
   {
      price = Ask;
      clr = clrLime;
   }
   else if(type == OP_SELL)
   {
      price = Bid;
      clr = clrRed;
   }
   else
      return false;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          reason, MagicNumber, 0, clr);

   if(ticket > 0)
   {
      g_totalOrdersToday++;
      AddSessionOrder();

      Print("OPENED ",
            type == OP_BUY ? "BUY" : "SELL",
            " | Ticket=", ticket,
            " | Lot=", DoubleToString(lot, 2),
            " | Session=", g_sessionName,
            " | Reason=", reason);

      return true;
   }

   Print("OrderSend failed. Error=", GetLastError());
   return false;
}

//====================================================================
void CloseAllTrades(string reason)
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

      bool closed = false;

      if(OrderType() == OP_BUY)
         closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrAqua);

      if(OrderType() == OP_SELL)
         closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrOrange);

      if(closed)
         Print("Closed #", OrderTicket(), " | ", reason);
      else
         Print("Close failed #", OrderTicket(), " Error=", GetLastError());
   }
}

//====================================================================
int CountOpenTrades()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         count++;
   }

   return count;
}

//====================================================================
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

//====================================================================
double NormalizeLot(double lot)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
}

//====================================================================
void AddSessionOrder()
{
   if(g_sessionName == "ASIA") asia_orders++;
   if(g_sessionName == "EU")   eu_orders++;
   if(g_sessionName == "US")   us_orders++;
   if(g_sessionName == "NY")   ny_orders++;
}

//====================================================================
void AddSessionProfit(double profit)
{
   if(g_sessionName == "ASIA")
   {
      asia_profit_orders++;
      asia_profit += profit;
   }

   if(g_sessionName == "EU")
   {
      eu_profit_orders++;
      eu_profit += profit;
   }

   if(g_sessionName == "US")
   {
      us_profit_orders++;
      us_profit += profit;
   }

   if(g_sessionName == "NY")
   {
      ny_profit_orders++;
      ny_profit += profit;
   }
}

//====================================================================
void AddHourlyStats(bool win, double profit)
{
   int h = TimeHour(TimeCurrent());

   g_hourTrades[h]++;

   if(win)
      g_hourWins[h]++;
   else
      g_hourLoss[h]++;

   g_hourProfit[h] += profit;
}

//====================================================================
void ResetDailyStats()
{
   int today = TimeDay(TimeCurrent());

   if(today == g_today)
      return;

   g_today = today;

   g_totalOrdersToday       = 0;
   g_totalProfitOrdersToday = 0;
   g_totalLossOrdersToday   = 0;

   g_totalProfitToday = 0;
   g_totalLossToday   = 0;

   asia_orders = 0;
   eu_orders   = 0;
   us_orders   = 0;
   ny_orders   = 0;

   asia_profit_orders = 0;
   eu_profit_orders   = 0;
   us_profit_orders   = 0;
   ny_profit_orders   = 0;

   asia_profit = 0;
   eu_profit   = 0;
   us_profit   = 0;
   ny_profit   = 0;

   for(int i = 0; i < 24; i++)
   {
      g_hourTrades[i] = 0;
      g_hourWins[i]   = 0;
      g_hourLoss[i]   = 0;
      g_hourProfit[i] = 0;
   }

   Print("Daily stats reset.");
}

//====================================================================
// SAR DOTS ON CHART
//====================================================================
void DrawSARDots()
{
   double step    = g_sarPeriod * g_sarStepSize / 10000.0;
   double maxStep = step * g_sarAccel;

   int barsToDraw = MathMin(SARDotsLookback, Bars - 3);

   for(int i = barsToDraw; i >= 1; i--)
   {
      double sar = iSAR(Symbol(), 0, step, maxStep, i);

      string name = "DXB_SAR_DOT_" + IntegerToString(i) + "_" + TimeToString(Time[i], TIME_DATE|TIME_MINUTES);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);

         if(sar < Close[i])
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
         }
         else
         {
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
            ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
         }

         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      }
      else
      {
         ObjectMove(0, name, 0, Time[i], sar);
      }
   }
}

//====================================================================
// BUY / SELL SIGNAL ARROWS
//====================================================================
void DrawSignalArrow(string signalType)
{
   if(!ShowSignalArrows) return;

   string name = "DXB_SAR_SIGNAL_" + signalType + "_" + TimeToString(Time[1], TIME_DATE|TIME_MINUTES);

   if(ObjectFind(0, name) >= 0)
      return;

   double price;

   if(signalType == "BUY")
   {
      price = Low[1] - (50 * Point);
      ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 233);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   }
   else
   {
      price = High[1] + (50 * Point);
      ObjectCreate(0, name, OBJ_ARROW, 0, Time[1], price);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 234);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);
   }
}

//====================================================================
// DASHBOARD
//====================================================================
void DrawDashboard()
{
   string text = "";

   text += "DXB SAR SESSION PROFIT BOOKER V3.10 XAUUSD\n";
   text += "--------------------------------------\n";
   text += "Symbol: " + Symbol() + "\n";
   text += "Session: " + g_sessionName + "\n";
   text += "Allowed: " + string(IsSessionAllowed() ? "YES" : "NO") + "\n";
   text += "Spread: " + IntegerToString((int)MarketInfo(Symbol(), MODE_SPREAD)) +
           " / " + IntegerToString(g_sessionMaxSpread) + "\n";
   text += "Open Trades: " + IntegerToString(CountOpenTrades()) + "\n";
   text += "Open P/L: $" + DoubleToString(GetTotalOpenProfit(), 2) + "\n";
   text += "Session TP: $" + DoubleToString(g_sessionTP, 2) + "\n";
   text += "Session SL: $" + DoubleToString(g_sessionSL, 2) + "\n";
   text += "SAR: Period=" + DoubleToString(g_sarPeriod, 2) +
           " Step=" + IntegerToString(g_sarStepSize) +
           " Accel=" + IntegerToString(g_sarAccel) + "\n";

   text += "\nLOT CONTROL\n";
   text += "Auto Lot: " + string(Auto_Increment_Lots ? "ON" : "OFF") + "\n";
   text += "Current Lot: " + DoubleToString(g_currentLot, 2) + "\n";
   text += "Base Lot: " + DoubleToString(BaseLot, 2) +
           " | Inc: " + DoubleToString(LotIncrement, 2) +
           " | Max: " + DoubleToString(MaxLot, 2) + "\n";
   text += "Loss Streak: " + IntegerToString(g_lossStreak) + "\n";
   text += "Recovery Wait: " + IntegerToString(MinSecondsBetweenRecoveryTrades) + " sec\n";
   text += "Last Result: " + string(g_lastTradeWasLoss ? "LOSS - NEXT LOT UP" : "PROFIT/RESET") + "\n\n";

   text += "DAILY TOTAL\n";
   text += "Orders: " + IntegerToString(g_totalOrdersToday) +
           " / " + IntegerToString(MaxTotalOrdersPerDay) + "\n";
   text += "Profit Orders: " + IntegerToString(g_totalProfitOrdersToday) +
           " / " + IntegerToString(MaxTotalProfitOrdersPerDay) + "\n";
   text += "Loss Orders: " + IntegerToString(g_totalLossOrdersToday) + "\n";
   text += "Profit Today: $" + DoubleToString(g_totalProfitToday, 2) + "\n";
   text += "Loss Today: $" + DoubleToString(g_totalLossToday, 2) + "\n\n";

   text += "SESSION TARGETS\n";
   text += "ASIA Orders: " + IntegerToString(asia_orders) +
           "/" + IntegerToString(Asia_MaxOrders) +
           " | TP Booked: " + IntegerToString(asia_profit_orders) +
           "/" + IntegerToString(Asia_MaxProfitOrders) +
           " | $" + DoubleToString(asia_profit, 2) + "\n";

   text += "EU   Orders: " + IntegerToString(eu_orders) +
           "/" + IntegerToString(EU_MaxOrders) +
           " | TP Booked: " + IntegerToString(eu_profit_orders) +
           "/" + IntegerToString(EU_MaxProfitOrders) +
           " | $" + DoubleToString(eu_profit, 2) + "\n";

   text += "US   Orders: " + IntegerToString(us_orders) +
           "/" + IntegerToString(US_MaxOrders) +
           " | TP Booked: " + IntegerToString(us_profit_orders) +
           "/" + IntegerToString(US_MaxProfitOrders) +
           " | $" + DoubleToString(us_profit, 2) + "\n";

   text += "NY   Orders: " + IntegerToString(ny_orders) +
           "/" + IntegerToString(NY_MaxOrders) +
           " | TP Booked: " + IntegerToString(ny_profit_orders) +
           "/" + IntegerToString(NY_MaxProfitOrders) +
           " | $" + DoubleToString(ny_profit, 2) + "\n\n";

   text += "HOURLY STATS\n";
   text += "Hour | Trades | Win | Loss | Profit\n";

   for(int h = 0; h < 24; h++)
   {
      if(g_hourTrades[h] > 0)
      {
         text += StringFormat("%02d   | %d      | %d   | %d    | $%.2f\n",
                              h,
                              g_hourTrades[h],
                              g_hourWins[h],
                              g_hourLoss[h],
                              g_hourProfit[h]);
      }
   }

   Comment(text);
}
//+------------------------------------------------------------------+