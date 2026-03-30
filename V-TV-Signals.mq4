//+------------------------------------------------------------------+
//| Global signal tracking variables                                 |
//+------------------------------------------------------------------+
string currentSignal            = "";
string prevSignal               = "";
string lastAppearedStrongSignal = "";

// Per-bar single-order guard: prevents two different signal types from both
// firing on the same bar (e.g. TREND BUY fires tick 1, EMA PULLBACK fires tick 2).
datetime lastAnyBuyBarTime  = 0;
datetime lastAnySellBarTime = 0;
//+------------------------------------------------------------------+
//| Calculate spread cost in USD for current symbol and lot size     |
//+------------------------------------------------------------------+
double GetSpreadCostUSD(double lotSize)
  {
   double spread = Ask - Bid;
   double spreadPoints = spread / Point;
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   return spreadPoints * lotSize * tickValue;
  }
//+------------------------------------------------------------------+
//| Global enable/disable for each signal type (default true)        |
//+------------------------------------------------------------------+
bool EnableTrendBuy   = true;
bool EnableStrongBuy  = true;   // sequence starter for STRONG→TREND→TREND
bool EnableWShapeBuy  = false;   // reversal entry
bool EnableVShapeBuy  = false;  // broken in logic (hardcoded off) — leave false
bool EnableMomBuy     = false;  // no sequence guard — risky
bool EnableTrendSell  = true;
bool EnableStrongSell = true;   // sequence starter for STRONG→TREND→TREND
bool EnableWShapeSell = false;   // reversal entry
bool EnableVShapeSell = false;  // broken in logic (hardcoded off) — leave false
bool EnableMomSell    = false;  // no sequence guard — risky
//+------------------------------------------------------------------+
//| EDGE ALGO - SMART PATTERN DETECTION (PRO ELITE)                 |
//+------------------------------------------------------------------+
#property strict

#define TRADE_DIRECTION_BOTH 0
#define TRADE_DIRECTION_BUY_ONLY 1
#define TRADE_DIRECTION_SELL_ONLY 2

// ----- INPUTS ----- //
input int FastEMA   = 21;
input int SlowEMA   = 50;
input int TrendEMA  = 200;

input int RSI_Period = 14;
input double RSI_Buy  = 55;
input double RSI_Sell = 45;
input int ReversalStreakCandles = 3;


//-----------------------------------------------------------------------------
input string version="V1.3";
input int    TradeDirectionMode    = 0;     // Trade Direction: 0=both, 1=buy only, 2=sell only
input double ProfitBookingUSD      = 0.50;  // Profit Booking USD (default, overridden per symbol)
input double PreOpenCloseProfitUSD = 0.20;  // Pre-Open Close Profit USD
input double LossCutUSD            = 1.00;  // Loss Cut USD — set to 2x profit target (default, overridden per symbol)

double effProfitBookingUSD      = 0.50;
double effPreOpenCloseProfitUSD = 0.20;
double effLossCutUSD            = 1.00;

input double EquityProfitPauseUSD = 100.00;
input int MaxBuyOrders = 2;
input int MaxSellOrders = 2;
input int MaxTotalOrders = 4; // Max Total Orders (0 = unlimited)

input int waitStartSessiontime=1;



//------------------------------------------------------------------------------

input bool EnableAlert = false;
input bool EnableSound = true;
input bool EnableLogMessages = false;
input bool EnableAutoTrading = true;

input bool EnableTestBuyEvery5Min = false; // turn off after testing
input bool ExecuteEverySignalInTester = false;
input double LotSize = 0.01;
input int MagicNumber = 260328;
input int Slippage = 5;
input bool EnableSpreadFilter = false;
input int MaxSpreadPoints = 10; // Stricter spread filter
input int MaxEntryDistancePoints = 25; // 0 = no late-entry distance filter
input int MinSameDirectionGapPoints = 0; // 0 = no spacing filter between same-side orders
input int DashboardRefreshSeconds = 30;
input bool EnableEquityProfitPause = true;

input int EquityProfitPauseMinutes = 60;
input bool EnablePreOpenClose      = true;
input int  SessionOpenHour         = 21; // fallback open hour (GMT+2 server time)
input int  SessionOpenMinute       = 0;  // fallback open minute
input int  CloseBeforeOpenMinutes  = 30; // block trading X min BEFORE market open (spikes)
input int  WaitAfterOpenMinutes    = 30; // block trading X min AFTER  market open (spikes)

// Effective session times — set automatically per symbol in ApplySymbolSessionTimes()
int effSessionOpenHour   = 21;
int effSessionOpenMinute = 0;

input int  StopLossPoints   = 0;//500; // broker-side SL safety net (500 = 50 pips on 5-digit broker)
input int  TakeProfitPoints = 0;   // 0 = no broker-side TP

input bool EnableProfitBooking = false;
input bool EnableLossCut       = false;

input bool   EnableDurationClose       = false;
input int    MaxOrderDurationMin       = 10;   // close stalled order after 10 min
input double DurationSkipIfProfitUSD   = 0.20; // skip duration close if already this profitable — let it run to target

input bool EnableTrendReversalClose = false; // close BUY if market turns bearish, SELL if bullish

input bool EnableDailyLossLimit  = true;
input double DailyLossLimitUSD   = 50.00; // stop ALL trading today if account drops this much

input bool CloseOppositeOnEntry = false;

input bool EnableMaxOrderAutoUnlock  = true;
input int  MaxOrderUnlockMinutes     = 60;
input int  MaxBuyOrdersAfterUnlock   = 2;
input int  MaxSellOrdersAfterUnlock  = 2;

// --- Break-Even Stop ---
input bool   EnableBreakEven      = true;
input double BreakEvenProfitUSD   = 0.15; // move SL to entry once up $0.15 — trade becomes risk-free

// --- Trailing Stop ---
input bool   EnableTrailingStop   = true;
input double TrailingStopUSD      = 0.10; // lock in $0.10 profit as price moves further in favor

// --- Daily Profit Target ---
input bool   EnableDailyProfitTarget = true;
input double DailyProfitTargetUSD    = 30.00; // stop trading today after this profit

// --- Consecutive Loss Pause ---
input bool EnableConsecutiveLossPause = true;
input int  MaxConsecutiveLosses       = 3;    // pause after this many losses in a row
input int  ConsecutiveLossPauseMin    = 60;   // pause duration in minutes

// --- Weekend Close ---
input bool EnableWeekendClose     = true;
input int  WeekendCloseHour       = 21;   // GMT+2: close all orders at Friday 21:00
input int  WeekendCloseMinute     = 0;

// --- Higher Timeframe Filter ---
input bool EnableH1Filter         = false;  // only trade in direction of H1 trend (EMA crossover)
input bool EnableStrictH1Filter   = false; // also require H1 price > H1 200 EMA (very strict, may block signals for hours)

// --- EMA Pullback Signal ---
input bool EnableEmaPullback      = true; // buy dip to 21 EMA in uptrend

// --- RSI Bounce Signal ---
input bool EnableRsiBounce        = true; // buy RSI cross above 30, sell cross below 70
input double RsiOversold          = 30.0;
input double RsiOverbought        = 70.0;

// ----- GLOBALS ----- //
double   dailyStartBalance      = 0;
bool     dailyLossTriggered     = false;
bool     dailyProfitTriggered   = false;
datetime lastDailyResetDate     = 0;
int      consecutiveLosses      = 0;
datetime consecutiveLossPauseUntil = 0;
datetime lastEmaPullbackBuyTime = 0;
datetime lastEmaPullbackSellTime= 0;
datetime lastRsiBounceByTime    = 0;
datetime lastRsiBounceSellTime  = 0;

datetime eaStartTime = 0; // For initial 30-min pause
datetime lastAlertTime = 0;
datetime lastTestBuySlot = 0;
datetime lastTrendBuyTradeTime = 0;
datetime lastRevBuyTradeTime = 0;
datetime lastStrongBuyTradeTime = 0;
datetime lastMomBuyTradeTime = 0;
datetime lastTrendSellTradeTime = 0;
datetime lastRevSellTradeTime = 0;
datetime lastStrongSellTradeTime = 0;
datetime lastMomSellTradeTime = 0;
datetime lastBuyOrderUpdateTime = 0;
datetime lastSellOrderUpdateTime = 0;
bool tradeUpdateTimesInitialized = false;
datetime lastProcessedClosedBar = 0;
bool wasSessionPauseWindow = false;
bool wasEquityProfitPauseWindow = false;
datetime lastDashboardRefreshTime = 0;
datetime equityProfitPauseUntil = 0;
double equityProfitPauseBaseline = 0.0;




//+------------------------------------------------------------------+
//| DRAW MARKER                                                     |
//+------------------------------------------------------------------+
void DrawMarker(string prefix, string text, color clr, int arrow, datetime t, double price)
  {
   string id = prefix + "_" + IntegerToString(t);
   string arrowId = id + "_A";
   string textId  = id + "_T";

   if(ObjectFind(0, arrowId) == -1)
      ObjectCreate(0, arrowId, OBJ_ARROW, 0, t, price);

   ObjectMove(0, arrowId, 0, t, price);
   ObjectSetInteger(0, arrowId, OBJPROP_ARROWCODE, arrow);
   ObjectSetInteger(0, arrowId, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, arrowId, OBJPROP_WIDTH, 2);

   if(ObjectFind(0, textId) == -1)
      ObjectCreate(0, textId, OBJ_TEXT, 0, t, price);

   ObjectMove(0, textId, 0, t, price);
   ObjectSetText(textId, " " + text + " ", 9, "Arial Bold", clr);


   /* if(text=="STRONG SELL" || text=="STRONG BUY" || text==".")
      {

      }
    else*/
   if(text==".")
     {

     }
   else
      currentSignal=text;
  }

//+------------------------------------------------------------------+
bool IsSignalMarkerObject(string name)
  {
   if(StringFind(name, "MOM_BUY_") == 0)
      return true;
   if(StringFind(name, "MOM_SELL_") == 0)
      return true;
   if(StringFind(name, "TB_") == 0)
      return true;
   if(StringFind(name, "RB_") == 0)
      return true;
   if(StringFind(name, "SB_") == 0)
      return true;
   if(StringFind(name, "TS_") == 0)
      return true;
   if(StringFind(name, "RS_") == 0)
      return true;
   if(StringFind(name, "SS_") == 0)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
void DeleteSignalMarkers()
  {
   for(int i = ObjectsTotal() - 1; i >= 0; i--)
     {
      string name = ObjectName(i);
      if(IsSignalMarkerObject(name))
         ObjectDelete(name);
     }
  }

//+------------------------------------------------------------------+
void SendSignalAlert(string msg)
  {
   if(EnableAlert)
      Alert(msg);
   if(EnableSound)
      PlaySound("alert.wav");
  }

//+------------------------------------------------------------------+
void LogMessage(string msg)
  {
   if(EnableLogMessages)
      Print(msg);
  }

//+------------------------------------------------------------------+
string DashboardObjectName(string suffix)
  {
   return "VTV_DASH_" + suffix;
  }

//+------------------------------------------------------------------+
string GetTimeframeText()
  {
   if(Period() == PERIOD_M1)
      return "M1";
   if(Period() == PERIOD_M5)
      return "M5";
   if(Period() == PERIOD_M15)
      return "M15";
   if(Period() == PERIOD_M30)
      return "M30";
   if(Period() == PERIOD_H1)
      return "H1";
   if(Period() == PERIOD_H4)
      return "H4";
   if(Period() == PERIOD_D1)
      return "D1";

   return "TF";
  }

//+------------------------------------------------------------------+
bool IsBuyDirectionAllowed()
  {
   return (TradeDirectionMode != TRADE_DIRECTION_SELL_ONLY);
  }

//+------------------------------------------------------------------+
bool IsSellDirectionAllowed()
  {
   return (TradeDirectionMode != TRADE_DIRECTION_BUY_ONLY);
  }

//+------------------------------------------------------------------+
string GetTradeDirectionText()
  {
   if(TradeDirectionMode == TRADE_DIRECTION_BUY_ONLY)
      return "BUY ONLY";
   if(TradeDirectionMode == TRADE_DIRECTION_SELL_ONLY)
      return "SELL ONLY";

   return "BOTH";
  }

//+------------------------------------------------------------------+
string GetDirectionBlockReason(int orderType, string signalName = "")
  {
   if(orderType == OP_BUY && !IsBuyDirectionAllowed())
      return "SELL ONLY MODE";

   if(orderType == OP_SELL && !IsSellDirectionAllowed())
      return "BUY ONLY MODE";

   return "";
  }

//+------------------------------------------------------------------+
int GetMinutesOfDay(datetime value)
  {
   return (TimeHour(value) * 60) + TimeMinute(value);
  }

//+------------------------------------------------------------------+
bool IsTimeWithinWindow(int currentMinutes, int windowStartMinutes, int windowEndMinutes)
  {
   if(windowStartMinutes == windowEndMinutes)
      return true;

   if(windowStartMinutes < windowEndMinutes)
      return (currentMinutes >= windowStartMinutes && currentMinutes < windowEndMinutes);

   return (currentMinutes >= windowStartMinutes || currentMinutes < windowEndMinutes);
  }

//+------------------------------------------------------------------+
bool IsPreOpenCloseWindow()
  {
   if(!EnablePreOpenClose || CloseBeforeOpenMinutes <= 0 || effSessionOpenHour < 0)
      return false;

   datetime now = GetTradeClock();
   int currentMinutes = GetMinutesOfDay(now);
   int openMinutes = (effSessionOpenHour * 60) + effSessionOpenMinute;
   int startMinutes = openMinutes - CloseBeforeOpenMinutes;

   while(startMinutes < 0)
      startMinutes += 1440;

   while(openMinutes >= 1440)
      openMinutes -= 1440;

   return IsTimeWithinWindow(currentMinutes, startMinutes, openMinutes);
  }

//+------------------------------------------------------------------+
bool IsPostOpenWaitWindow()
  {
   if(!EnablePreOpenClose || WaitAfterOpenMinutes <= 0 || effSessionOpenHour < 0)
      return false;

   datetime now = GetTradeClock();
   int currentMinutes = GetMinutesOfDay(now);
   int openMinutes = (effSessionOpenHour * 60) + effSessionOpenMinute;
   int endMinutes = openMinutes + WaitAfterOpenMinutes;

   while(openMinutes >= 1440)
      openMinutes -= 1440;

   while(endMinutes >= 1440)
      endMinutes -= 1440;

   return IsTimeWithinWindow(currentMinutes, openMinutes, endMinutes);
  }

//+------------------------------------------------------------------+
bool IsSessionPauseWindow()
  {
   return (IsPreOpenCloseWindow() || IsPostOpenWaitWindow());
  }

//+------------------------------------------------------------------+
string GetSessionPauseReason()
  {
   if(IsPreOpenCloseWindow())
      return "PRE-OPEN CLOSE WINDOW";

   if(IsPostOpenWaitWindow())
      return "WAIT AFTER OPEN WINDOW";

   return "SESSION PAUSE WINDOW";
  }

//+------------------------------------------------------------------+
datetime GetTradeClock()
  {
   datetime now = TimeCurrent();

   if(now <= 0 && Bars > 0)
      now = Time[0];

   return now;
  }

//+------------------------------------------------------------------+
void ResetEquityProfitPauseBaseline()
  {
   equityProfitPauseBaseline = AccountBalance();
  }

//+------------------------------------------------------------------+
double GetEquityProfitSincePauseBaseline()
  {
   if(equityProfitPauseBaseline <= 0.0)
      ResetEquityProfitPauseBaseline();

   return AccountEquity() - equityProfitPauseBaseline;
  }

//+------------------------------------------------------------------+
bool IsEquityProfitPauseWindow()
  {
   if(!EnableEquityProfitPause || EquityProfitPauseMinutes <= 0)
      return false;

   return (equityProfitPauseUntil > GetTradeClock());
  }

//+------------------------------------------------------------------+
string GetEquityProfitPauseReason()
  {
   if(!IsEquityProfitPauseWindow())
      return "WITHDRAW PROFIT";

   int remainingMinutes = (int)MathCeil((equityProfitPauseUntil - GetTradeClock()) / 60.0);
   if(remainingMinutes < 0)
      remainingMinutes = 0;

   return "WITHDRAW PROFIT " + IntegerToString(remainingMinutes) + "M";
  }

//+------------------------------------------------------------------+
datetime GetLatestTradeUpdateTimeByType(int orderType)
  {
   datetime latest = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;

      if(OrderOpenTime() > latest)
         latest = OrderOpenTime();
     }

   for(int j = OrdersHistoryTotal() - 1; j >= 0; j--)
     {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;

      if(OrderCloseTime() > latest)
         latest = OrderCloseTime();
     }

   return latest;
  }

//+------------------------------------------------------------------+
void InitializeTradeUpdateTimes()
  {
   if(tradeUpdateTimesInitialized)
      return;

   lastBuyOrderUpdateTime = GetLatestTradeUpdateTimeByType(OP_BUY);
   lastSellOrderUpdateTime = GetLatestTradeUpdateTimeByType(OP_SELL);

   datetime now = GetTradeClock();
   if(lastBuyOrderUpdateTime == 0)
      lastBuyOrderUpdateTime = now;
   if(lastSellOrderUpdateTime == 0)
      lastSellOrderUpdateTime = now;

   tradeUpdateTimesInitialized = true;
  }

//+------------------------------------------------------------------+
void MarkTradeUpdate(int orderType)
  {
   datetime now = GetTradeClock();

   if(orderType == OP_BUY)
      lastBuyOrderUpdateTime = now;
   else
      if(orderType == OP_SELL)
         lastSellOrderUpdateTime = now;
  }

//+------------------------------------------------------------------+
string FormatDashboardDateTime(datetime value)
  {
   if(value <= 0)
      return "-";

   return TimeToString(value, TIME_DATE|TIME_MINUTES);
  }

//+------------------------------------------------------------------+
string GetSignalDisplayName(string signalName)
  {
   if(signalName == "REV BUY")
      return "W SHAPE BUY";

   if(signalName == "REV SELL")
      return "V SHAPE SELL";

   return signalName;
  }

//+------------------------------------------------------------------+
string FormatLimitValue(int limit)
  {
   if(limit <= 0)
      return "UNL";

   return IntegerToString(limit);
  }

//+------------------------------------------------------------------+
int GetEffectiveMaxOrdersForType(int orderType)
  {
   int baseMax = (orderType == OP_BUY) ? MaxBuyOrders : MaxSellOrders;
   if(baseMax <= 0)
      return 0;

   if(!EnableMaxOrderAutoUnlock)
      return baseMax;

   int unlockMax = (orderType == OP_BUY) ? MaxBuyOrdersAfterUnlock : MaxSellOrdersAfterUnlock;
   if(unlockMax <= baseMax)
      return baseMax;

   if(CountOpenOrdersByType(orderType) < baseMax)
      return baseMax;

   datetime lastUpdate = (orderType == OP_BUY) ? lastBuyOrderUpdateTime : lastSellOrderUpdateTime;
   if(lastUpdate <= 0)
      return baseMax;

   if(MaxOrderUnlockMinutes > 0 && (GetTradeClock() - lastUpdate) >= (MaxOrderUnlockMinutes * 60))
      return unlockMax;

   return baseMax;
  }

//+------------------------------------------------------------------+
bool IsMaxOrderUnlocked(int orderType)
  {
   int baseMax = (orderType == OP_BUY) ? MaxBuyOrders : MaxSellOrders;
   int effectiveMax = GetEffectiveMaxOrdersForType(orderType);

   return (baseMax > 0 && effectiveMax > baseMax);
  }

//+------------------------------------------------------------------+
color GetLimitColor(int orderType)
  {
   int baseMax = (orderType == OP_BUY) ? MaxBuyOrders : MaxSellOrders;
   int openCount = CountOpenOrdersByType(orderType);

   if(baseMax <= 0)
      return clrDarkGreen;

   if(IsMaxOrderUnlocked(orderType))
      return clrDodgerBlue;

   if(baseMax > 0 && openCount >= baseMax)
      return clrOrange;

   return clrDimGray;
  }

//+------------------------------------------------------------------+
color GetProfitColor(double amount)
  {
   if(amount > 0.0)
      return clrLime;
   if(amount < 0.0)
      return clrTomato;

   return clrSilver;
  }

//+------------------------------------------------------------------+
color GetStatusColor(string status)
  {
   if(StringFind(status, "WITHDRAW PROFIT") >= 0)
      return clrDodgerBlue;
   if(status == "BULL TREND")
      return clrLime;
   if(status == "BEAR TREND")
      return clrTomato;

   return clrSilver;
  }

//+------------------------------------------------------------------+
color GetReasonColor(string reason)
  {
   if(StringFind(reason, "WITHDRAW PROFIT") >= 0)
      return clrDodgerBlue;
   if(StringFind(reason, "BUY READY") >= 0)
      return clrGreen;
   if(StringFind(reason, "SELL READY") >= 0)
      return clrRed;
   if(StringFind(reason, "ONLY MODE") >= 0)
      return clrDodgerBlue;
   if(StringFind(reason, "WAIT") >= 0)
      return clrOrange;
   if(StringFind(reason, "WINDOW") >= 0)
      return clrOrange;
   if(StringFind(reason, "OFF") >= 0)
      return clrDimGray;
   if(StringFind(reason, "HIGH") >= 0 || StringFind(reason, "MAX") >= 0 || StringFind(reason, "FAR") >= 0 || StringFind(reason, "GAP") >= 0)
      return clrOrange;

   return clrBlack;
  }

//+------------------------------------------------------------------+
color GetCountColor(int count, color activeColor)
  {
   if(count > 0)
      return activeColor;

   return clrDimGray;
  }

//+------------------------------------------------------------------+
void SetDashboardPanel()
  {
   string name = DashboardObjectName("panel");

   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 16);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, 390);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 720);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C'180,180,180');
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void SetDashboardLine(string key, int x, int y, string text, color clr, int size)
  {
   string name = DashboardObjectName(key);

   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void SetDashboardValueLine(string key, int y, string labelText, string valueText, color valueColor, int valueX)
  {
   string labelName = DashboardObjectName(key + "_lbl");
   string valueName = DashboardObjectName(key + "_val");

   if(ObjectFind(0, labelName) == -1)
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);

   if(ObjectFind(0, valueName) == -1)
      ObjectCreate(0, valueName, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);

   ObjectSetInteger(0, valueName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, valueName, OBJPROP_XDISTANCE, valueX);
   ObjectSetInteger(0, valueName, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, valueName, OBJPROP_TEXT, valueText);
   ObjectSetString(0, valueName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, valueName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, valueName, OBJPROP_COLOR, valueColor);
   ObjectSetInteger(0, valueName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, valueName, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
void DeleteDashboardValueLine(string key)
  {
   ObjectDelete(0, DashboardObjectName(key + "_lbl"));
   ObjectDelete(0, DashboardObjectName(key + "_val"));
  }

//+------------------------------------------------------------------+
void DeleteDashboard()
  {
   ObjectDelete(0, DashboardObjectName("panel"));
   ObjectDelete(0, DashboardObjectName("title"));
   ObjectDelete(0, DashboardObjectName("symbol"));
   DeleteDashboardValueLine("status");
   DeleteDashboardValueLine("reason");
   DeleteDashboardValueLine("mode");
   DeleteDashboardValueLine("totalpl");
   DeleteDashboardValueLine("orders");
   DeleteDashboardValueLine("buypl");
   DeleteDashboardValueLine("sellpl");
   DeleteDashboardValueLine("book");
   DeleteDashboardValueLine("stop");
   DeleteDashboardValueLine("spread");
   DeleteDashboardValueLine("test");
   ObjectDelete(0, DashboardObjectName("statshead"));
   DeleteDashboardValueLine("stat_tb");
   DeleteDashboardValueLine("stat_rb");
   DeleteDashboardValueLine("stat_sb");
   DeleteDashboardValueLine("stat_ts");
   DeleteDashboardValueLine("stat_rs");
   DeleteDashboardValueLine("stat_ss");
   DeleteDashboardValueLine("best");
   ObjectDelete(0, DashboardObjectName("openstatshead"));
   DeleteDashboardValueLine("open_tb");
   DeleteDashboardValueLine("open_rb");
   DeleteDashboardValueLine("open_sb");
   DeleteDashboardValueLine("open_ts");
   DeleteDashboardValueLine("open_rs");
   DeleteDashboardValueLine("open_ss");
   DeleteDashboardValueLine("open_total");
   DeleteDashboardValueLine("buylimit");
   DeleteDashboardValueLine("selllimit");
  }

//+------------------------------------------------------------------+
bool SignalCommentMatches(string orderComment, string signalName, string legacySignalName = "")
  {
   if(orderComment == signalName)
      return true;

   if(legacySignalName != "" && orderComment == legacySignalName)
      return true;

   return false;
  }

//+------------------------------------------------------------------+
void GetSignalHistoryStats(string signalName, int &tradeCount, int &winCount, int &lossCount, double &netProfit, string legacySignalName = "")
  {
   tradeCount = 0;
   winCount = 0;
   lossCount = 0;
   netProfit = 0.0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      if(!SignalCommentMatches(OrderComment(), signalName, legacySignalName))
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      tradeCount++;
      netProfit += profit;

      if(profit >= 0.0)
         winCount++;
      else
         lossCount++;
     }
  }

//+------------------------------------------------------------------+
string BuildSignalStatsValueText(int tradeCount, int winCount, int lossCount, double netProfit)
  {
   return "T:" + IntegerToString(tradeCount) +
          " W:" + IntegerToString(winCount) +
          " L:" + IntegerToString(lossCount) +
          " P/L:$" + DoubleToString(netProfit, 2);
  }

//+------------------------------------------------------------------+
void GetSignalOpenStats(string signalName, int &openCount, double &floatingProfit, string legacySignalName = "")
  {
   openCount = 0;
   floatingProfit = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      if(!SignalCommentMatches(OrderComment(), signalName, legacySignalName))
         continue;

      openCount++;
      floatingProfit += OrderProfit() + OrderSwap() + OrderCommission();
     }
  }

//+------------------------------------------------------------------+
string BuildOpenSignalStatsValueText(int openCount, double floatingProfit)
  {
   return "Open:" + IntegerToString(openCount) +
          "  U P/L:$" + DoubleToString(floatingProfit, 2);
  }

//+------------------------------------------------------------------+
void ResetAnalysisState()
  {
   lastAlertTime = 0;
   lastTrendBuyTradeTime = 0;
   lastRevBuyTradeTime = 0;
   lastStrongBuyTradeTime = 0;
   lastMomBuyTradeTime = 0;
   lastTrendSellTradeTime = 0;
   lastRevSellTradeTime = 0;
   lastStrongSellTradeTime = 0;
   lastMomSellTradeTime = 0;

   if(Bars > 1)
      lastProcessedClosedBar = Time[1];
   else
      lastProcessedClosedBar = 0;
  }

//+------------------------------------------------------------------+
int CountConsecutiveCandleDirection(int startShift, bool bullishCandles)
  {
   int count = 0;

   for(int i = startShift; i < Bars; i++)
     {
      bool isBull = Close[i] > Open[i];
      bool isBear = Close[i] < Open[i];

      if(bullishCandles)
        {
         if(isBull)
            count++;
         else
            break;
        }
      else
        {
         if(isBear)
            count++;
         else
            break;
        }
     }

   return count;
  }

//+------------------------------------------------------------------+
string GetReversalSignalName(int shift, int orderType)
  {
   if(shift < 0 || shift + 2 >= Bars)
      return "";

   double emaFast  = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double emaTrend = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double rsiVal   = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift+1);
   double body     = MathAbs(Open[shift] - Close[shift]);
   double range    = High[shift] - Low[shift];
   double prevBody = MathAbs(Open[shift+1] - Close[shift+1]);
   double closeToLow  = (range > 0.0) ? ((Close[shift] - Low[shift]) / range) : 0.0;
   double closeToHigh = (range > 0.0) ? ((High[shift] - Close[shift]) / range) : 0.0;

   bool strongCandle = (range > 0.0) && (body > (range * 0.6));
   bool rsiUp   = rsiVal > rsiPrev;
   bool rsiDown = rsiVal < rsiPrev;
   bool currBull = Close[shift] > Open[shift];
   bool currBear = Close[shift] < Open[shift];
   bool reversalBodyStronger = body > prevBody;

   bool vReversalBuy  = Close[shift] > Close[shift+1] && Close[shift+1] < Close[shift+2];
   bool vReversalSell = Close[shift] < Close[shift+1] && Close[shift+1] > Close[shift+2];
   int previousBearStreak = CountConsecutiveCandleDirection(shift + 1, false);
   int previousBullStreak = CountConsecutiveCandleDirection(shift + 1, true);

   bool bullishReverseBreak = Close[shift] > High[shift+1];
   bool bearishReverseBreak = Close[shift] < Low[shift+1];
   bool streakReversalBuy = currBull && previousBearStreak >= ReversalStreakCandles && closeToLow >= 0.45 &&
                            reversalBodyStronger && bullishReverseBreak;
   bool streakReversalSell = currBear && previousBullStreak >= ReversalStreakCandles && closeToHigh >= 0.45 &&
                             reversalBodyStronger && bearishReverseBreak;
   bool vShapeBuy = vReversalBuy && Low[shift+1] < Low[shift+2] && currBull && closeToLow >= 0.55 &&
                    reversalBodyStronger && bullishReverseBreak;
   bool vShapeSell = vReversalSell && High[shift+1] > High[shift+2] && currBear && closeToHigh >= 0.55 &&
                     reversalBodyStronger && bearishReverseBreak;

   vShapeBuy=false;
   vShapeSell=false;

   // W SHAPE: RSI at the bottom of the bear streak must be below 50 (genuine weakness before reversal).
   // W SHAPE: RSI at the top of the bull streak must be above 50 (genuine strength before reversal).
   double rsiAtStreakBottom = (shift+1 < Bars) ? iRSI(NULL, 0, RSI_Period, PRICE_CLOSE, shift+1) : 50;

   if(orderType == OP_BUY)
     {
      if(streakReversalBuy && strongCandle && rsiUp && rsiAtStreakBottom < 50 &&
         Close[shift] > emaFast && Close[shift] > emaTrend)
         return "W SHAPE BUY";

      if(vShapeBuy && strongCandle && rsiUp && Close[shift] > emaFast)
         return "V SHAPE BUY";
     }
   else
      if(orderType == OP_SELL)
        {
         if(streakReversalSell && strongCandle && rsiDown && rsiAtStreakBottom > 50 &&
            Close[shift] < emaFast && Close[shift] < emaTrend)
            return "W SHAPE SELL";

         if(vShapeSell && strongCandle && rsiDown && Close[shift] < emaFast)
            return "V SHAPE SELL";
        }

   return "";
  }

//+------------------------------------------------------------------+
// Returns true if H1 trend aligns with the requested direction
bool IsH1TrendBullish()
  {
   double h1Fast  = iMA(NULL, PERIOD_H1, FastEMA,  0, MODE_EMA, PRICE_CLOSE, 0);
   double h1Slow  = iMA(NULL, PERIOD_H1, SlowEMA,  0, MODE_EMA, PRICE_CLOSE, 0);
   bool crossoverOK = (h1Fast > h1Slow);
   if(!EnableStrictH1Filter)
      return crossoverOK;
   // Strict mode: also require H1 close above H1 200 EMA (macro uptrend)
   double h1Trend = iMA(NULL, PERIOD_H1, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double h1Close = iClose(NULL, PERIOD_H1, 0);
   return (crossoverOK && h1Close > h1Trend);
  }

bool IsH1TrendBearish()
  {
   double h1Fast  = iMA(NULL, PERIOD_H1, FastEMA,  0, MODE_EMA, PRICE_CLOSE, 0);
   double h1Slow  = iMA(NULL, PERIOD_H1, SlowEMA,  0, MODE_EMA, PRICE_CLOSE, 0);
   bool crossoverOK = (h1Fast < h1Slow);
   if(!EnableStrictH1Filter)
      return crossoverOK;
   // Strict mode: also require H1 close below H1 200 EMA (macro downtrend)
   double h1Trend = iMA(NULL, PERIOD_H1, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 0);
   double h1Close = iClose(NULL, PERIOD_H1, 0);
   return (crossoverOK && h1Close < h1Trend);
  }

void EvaluateSignalFlags(int shift,
                         bool &bullMomentum,
                         bool &bearMomentum,
                         bool &trendBuy,
                         bool &reversalBuy,
                         bool &strongBuy,
                         bool &trendSell,
                         bool &reversalSell,
                         bool &strongSell,
                         bool &emaPullbackBuy,
                         bool &emaPullbackSell,
                         bool &rsiBounceBuy,
                         bool &rsiBounceSell)
  {
   bullMomentum    = false;
   bearMomentum    = false;
   trendBuy        = false;
   reversalBuy     = false;
   strongBuy       = false;
   trendSell       = false;
   reversalSell    = false;
   strongSell      = false;
   emaPullbackBuy  = false;
   emaPullbackSell = false;
   rsiBounceBuy    = false;
   rsiBounceSell   = false;

   if(shift < 0 || shift + 2 >= Bars)
      return;

   // Bar 0 just opened — High==Low (zero range). strongCandle and bullishCloseStrong
   // will always be false on the first tick, causing valid bar-1 signals to be missed.
   // Inherit bar 1's confirmed signal instead so the order fires on bar 0's first tick.
   if(shift == 0 && Bars > 1 && (High[0] - Low[0]) == 0.0)
     {
      EvaluateSignalFlags(1, bullMomentum, bearMomentum,
                          trendBuy, reversalBuy, strongBuy,
                          trendSell, reversalSell, strongSell,
                          emaPullbackBuy, emaPullbackSell, rsiBounceBuy, rsiBounceSell);
      return;
     }

   double emaFast  = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double emaSlow  = iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double emaTrend = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,shift);

   double rsiVal   = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift+1);

   double body   = MathAbs(Open[shift] - Close[shift]);
   double range  = High[shift] - Low[shift];
   double emaGap = MathAbs(emaFast - emaSlow);
   double closeToLow  = (range > 0.0) ? ((Close[shift] - Low[shift]) / range) : 0.0;
   double closeToHigh = (range > 0.0) ? ((High[shift] - Close[shift]) / range) : 0.0;
   double prevBody = MathAbs(Open[shift+1] - Close[shift+1]);

   // Reduced from 0.6 to 0.5: M1 candles have more wicks; 50% body still shows directional strength
   bool strongCandle = (range > 0.0) && (body > (range * 0.5));
   bool strongTrend  = emaGap > (10 * Point);

   bool rsiUp   = rsiVal > rsiPrev;
   bool rsiDown = rsiVal < rsiPrev;

   bool bullTrend = Close[shift] > emaTrend && emaFast > emaSlow;
   bool bearTrend = Close[shift] < emaTrend && emaFast < emaSlow;

   bullMomentum = bullTrend && rsiUp && strongTrend;
   bearMomentum = bearTrend && rsiDown && strongTrend;

   // Breakout: strong = close above prev HIGH; moderate = close above prev midpoint in confirmed trend
   double prevMid    = (High[shift+1] + Low[shift+1]) / 2.0;
   bool breakoutBuy  = Close[shift] > High[shift+1] || (Close[shift] > prevMid && bullTrend);
   bool breakoutSell = Close[shift] < Low[shift+1]  || (Close[shift] < prevMid && bearTrend);

   bool vReversalBuy  = Close[shift] > Close[shift+1] && Close[shift+1] < Close[shift+2];
   bool vReversalSell = Close[shift] < Close[shift+1] && Close[shift+1] > Close[shift+2];

   bool prevBear = Close[shift+1] < Open[shift+1];
   bool prevBull = Close[shift+1] > Open[shift+1];
   bool currBull = Close[shift] > Open[shift];
   bool currBear = Close[shift] < Open[shift];
   int previousBearStreak = CountConsecutiveCandleDirection(shift + 1, false);
   int previousBullStreak = CountConsecutiveCandleDirection(shift + 1, true);

   bool engulfBuy  = prevBear && currBull && Open[shift] <= Close[shift+1] && Close[shift] >= Open[shift+1];
   bool engulfSell = prevBull && currBear && Open[shift] >= Close[shift+1] && Close[shift] <= Open[shift+1];
   // Reduced from 0.65 to 0.55: allows close in top 45% of range (was top 35%)
   bool bullishCloseStrong = currBull && closeToLow >= 0.55;
   bool bearishCloseStrong = currBear && closeToHigh >= 0.55;
   bool reversalBodyStronger = body > prevBody;
   bool bullishReverseBreak = Close[shift] > High[shift+1];
   bool bearishReverseBreak = Close[shift] < Low[shift+1];
   bool streakReversalBuy = currBull && previousBearStreak >= ReversalStreakCandles && closeToLow >= 0.45 &&
                            reversalBodyStronger && bullishReverseBreak;
   bool streakReversalSell = currBear && previousBullStreak >= ReversalStreakCandles && closeToHigh >= 0.45 &&
                             reversalBodyStronger && bearishReverseBreak;
   bool reversalBuyStructure = (GetReversalSignalName(shift, OP_BUY) != "");
   bool reversalSellStructure = (GetReversalSignalName(shift, OP_SELL) != "");

   // H1 filter
   bool h1Bull = !EnableH1Filter || IsH1TrendBullish();
   bool h1Bear = !EnableH1Filter || IsH1TrendBearish();

   // TREND BUY: RSI capped at 72 — avoid overbought exhaustion entries.
   // TREND SELL: RSI floored at 28 — avoid oversold exhaustion entries.
   trendBuy  = bullMomentum && breakoutBuy  && rsiVal > RSI_Buy  && rsiVal < 72 && strongCandle && bullishCloseStrong && h1Bull;
   trendSell = bearMomentum && breakoutSell && rsiVal < RSI_Sell && rsiVal > 28 && strongCandle && bearishCloseStrong && h1Bear;

   reversalBuy  = reversalBuyStructure;
   reversalSell = reversalSellStructure;

   // STRONG BUY: bullish engulf must occur near FastEMA (pullback support level).
   // Requiring Low[shift] close to FastEMA prevents firing at overextended price.
   bool nearFastEmaBuy  = Low[shift]  <= emaFast * 1.002;
   bool nearFastEmaSell = High[shift] >= emaFast * 0.998;
   strongBuy  = engulfBuy  && bullTrend && strongCandle && bullishCloseStrong && nearFastEmaBuy  && h1Bull;
   strongSell = engulfSell && bearTrend && strongCandle && bearishCloseStrong && nearFastEmaSell && h1Bear;

   // EMA PULLBACK: check last 3 bars for EMA touch — pullbacks take 2-5 bars, not just 1.
   bool prevBelowFast = (shift+3 < Bars) &&
                        (Low[shift+1] <= emaFast || Low[shift+2] <= emaFast || Low[shift+3] <= emaFast);
   bool prevAboveFast = (shift+3 < Bars) &&
                        (High[shift+1] >= emaFast || High[shift+2] >= emaFast || High[shift+3] >= emaFast);
   emaPullbackBuy  = EnableEmaPullback && bullTrend && prevBelowFast && currBull &&
                     Close[shift] > emaFast && rsiVal > 45 && h1Bull;
   emaPullbackSell = EnableEmaPullback && bearTrend && prevAboveFast && currBear &&
                     Close[shift] < emaFast && rsiVal < 55 && h1Bear;

   // RSI BOUNCE: rsiPrev (shift+1) already holds the previous RSI — reuse it directly.
   // Buy: RSI was below oversold level, now crosses back up — bounce from bottom.
   // Sell: RSI was above overbought level, now crosses back down — bounce from top.
   rsiBounceBuy  = EnableRsiBounce && bullTrend && rsiPrev < RsiOversold  && rsiVal >= RsiOversold  && h1Bull;
   rsiBounceSell = EnableRsiBounce && bearTrend && rsiPrev > RsiOverbought && rsiVal <= RsiOverbought && h1Bear;
  }

//+------------------------------------------------------------------+
void UpdateDashboard(string status, string liveReason)
  {
   InitializeTradeUpdateTimes();

   double buyPL = GetOpenProfitByType(OP_BUY);
   double sellPL = GetOpenProfitByType(OP_SELL);
   double totalPL = buyPL + sellPL;
   int buyOrders = CountOpenOrdersByType(OP_BUY);
   int sellOrders = CountOpenOrdersByType(OP_SELL);
   int totalOrders = buyOrders + sellOrders;
   double spreadPoints = (Ask - Bid) / Point;
   int tbTrades = 0, vbTrades = 0, wbTrades = 0, sbTrades = 0;
   int tsTrades = 0, vsTrades = 0, wsTrades = 0, ssTrades = 0;
   int tbWins = 0, vbWins = 0, wbWins = 0, sbWins = 0;
   int tsWins = 0, vsWins = 0, wsWins = 0, ssWins = 0;
   int tbLosses = 0, vbLosses = 0, wbLosses = 0, sbLosses = 0;
   int tsLosses = 0, vsLosses = 0, wsLosses = 0, ssLosses = 0;
   int tbOpen = 0, vbOpen = 0, wbOpen = 0, sbOpen = 0;
   int tsOpen = 0, vsOpen = 0, wsOpen = 0, ssOpen = 0;
   double tbProfit = 0.0, vbProfit = 0.0, wbProfit = 0.0, sbProfit = 0.0;
   double tsProfit = 0.0, vsProfit = 0.0, wsProfit = 0.0, ssProfit = 0.0;
   double tbOpenProfit = 0.0, vbOpenProfit = 0.0, wbOpenProfit = 0.0, sbOpenProfit = 0.0;
   double tsOpenProfit = 0.0, vsOpenProfit = 0.0, wsOpenProfit = 0.0, ssOpenProfit = 0.0;
   int effectiveBuyMax = GetEffectiveMaxOrdersForType(OP_BUY);
   int effectiveSellMax = GetEffectiveMaxOrdersForType(OP_SELL);
   string bestSignal = "NO CLOSED TRADES";
   double bestProfit = -999999.0;

   GetSignalHistoryStats("TREND BUY", tbTrades, tbWins, tbLosses, tbProfit);
   GetSignalHistoryStats("V SHAPE BUY", vbTrades, vbWins, vbLosses, vbProfit);
   GetSignalHistoryStats("W SHAPE BUY", wbTrades, wbWins, wbLosses, wbProfit, "REV BUY");
   GetSignalHistoryStats("STRONG BUY", sbTrades, sbWins, sbLosses, sbProfit);
   GetSignalHistoryStats("TREND SELL", tsTrades, tsWins, tsLosses, tsProfit);
   GetSignalHistoryStats("V SHAPE SELL", vsTrades, vsWins, vsLosses, vsProfit, "REV SELL");
   GetSignalHistoryStats("W SHAPE SELL", wsTrades, wsWins, wsLosses, wsProfit);
   GetSignalHistoryStats("STRONG SELL", ssTrades, ssWins, ssLosses, ssProfit);
   GetSignalOpenStats("TREND BUY", tbOpen, tbOpenProfit);
   GetSignalOpenStats("V SHAPE BUY", vbOpen, vbOpenProfit);
   GetSignalOpenStats("W SHAPE BUY", wbOpen, wbOpenProfit, "REV BUY");
   GetSignalOpenStats("STRONG BUY", sbOpen, sbOpenProfit);
   GetSignalOpenStats("TREND SELL", tsOpen, tsOpenProfit);
   GetSignalOpenStats("V SHAPE SELL", vsOpen, vsOpenProfit, "REV SELL");
   GetSignalOpenStats("W SHAPE SELL", wsOpen, wsOpenProfit);
   GetSignalOpenStats("STRONG SELL", ssOpen, ssOpenProfit);

   if(tbTrades > 0 && tbProfit > bestProfit)
     {
      bestProfit = tbProfit;
      bestSignal = "TREND BUY";
     }
   if(vbTrades > 0 && vbProfit > bestProfit)
     {
      bestProfit = vbProfit;
      bestSignal = "V SHAPE BUY";
     }
   if(wbTrades > 0 && wbProfit > bestProfit)
     {
      bestProfit = wbProfit;
      bestSignal = "W SHAPE BUY";
     }
   if(sbTrades > 0 && sbProfit > bestProfit)
     {
      bestProfit = sbProfit;
      bestSignal = "STRONG BUY";
     }
   if(tsTrades > 0 && tsProfit > bestProfit)
     {
      bestProfit = tsProfit;
      bestSignal = "TREND SELL";
     }
   if(vsTrades > 0 && vsProfit > bestProfit)
     {
      bestProfit = vsProfit;
      bestSignal = "V SHAPE SELL";
     }
   if(wsTrades > 0 && wsProfit > bestProfit)
     {
      bestProfit = wsProfit;
      bestSignal = "W SHAPE SELL";
     }
   if(ssTrades > 0 && ssProfit > bestProfit)
     {
      bestProfit = ssProfit;
      bestSignal = "STRONG SELL";
     }

   SetDashboardPanel();

   SetDashboardLine("title",   20,  24, "EDGE ALGO "+version, clrNavy, 11);
   SetDashboardLine("symbol",  20,  46, Symbol() + "  " + GetTimeframeText(), clrBlack, 9);
   SetDashboardValueLine("status",  68, "Status", status, GetStatusColor(status), 108);
   SetDashboardValueLine("reason",  86, "Reason", liveReason, GetReasonColor(liveReason), 108);
   SetDashboardValueLine("mode",   104, "Mode", (EnableAutoTrading ? "AUTO " : "SIGNALS ") + GetTradeDirectionText(),
                         EnableAutoTrading ? clrGreen : clrDimGray, 108);
   SetDashboardValueLine("totalpl",126, "Total P/L", "$" + DoubleToString(totalPL, 2), GetProfitColor(totalPL), 108);
   SetDashboardValueLine("orders", 146, "Total Orders", IntegerToString(totalOrders), GetCountColor(totalOrders, clrBlue), 108);
   SetDashboardValueLine("buypl",  164, "Buy Orders", IntegerToString(buyOrders) + "  P/L $" + DoubleToString(buyPL, 2),
                         buyOrders > 0 ? GetProfitColor(buyPL) : clrDimGray, 108);
   SetDashboardValueLine("sellpl", 182, "Sell Orders", IntegerToString(sellOrders) + "  P/L $" + DoubleToString(sellPL, 2),
                         sellOrders > 0 ? GetProfitColor(sellPL) : clrDimGray, 108);
   SetDashboardValueLine("book",   200, "Profit Book", EnableProfitBooking ? ("$" + DoubleToString(effProfitBookingUSD, 2)) : "OFF",
                         EnableProfitBooking ? clrDarkGreen : clrDimGray, 108);
   SetDashboardValueLine("stop",   218, "Stop Loss", EnableLossCut ? ("$" + DoubleToString(effLossCutUSD, 2)) : "OFF",
                         EnableLossCut ? clrRed : clrDimGray, 108);
   double spreadCostUSD = GetSpreadCostUSD(LotSize);
   SetDashboardValueLine("spread", 236, "Spread",   DoubleToString((Ask - Bid),5)  +" "+   DoubleToString(spreadPoints, 0) + " pts ($" + DoubleToString(spreadCostUSD, 2) + ")",
                         (!EnableSpreadFilter || IsSpreadOK()) ? clrDarkGreen : clrOrange, 108);
   SetDashboardValueLine("test",   236, "Test", EnableTestBuyEvery5Min ? "ON" : "OFF",
                         EnableTestBuyEvery5Min ? clrBlue : clrDimGray, 285);

   SetDashboardLine("statshead", 20, 264, "Signal Stats  (closed trades)", clrBlack, 10);
   SetDashboardValueLine("stat_tb", 286, "TREND BUY", BuildSignalStatsValueText(tbTrades, tbWins, tbLosses, tbProfit), GetProfitColor(tbProfit), 130);
   SetDashboardValueLine("stat_vb", 304, "V SHAPE BUY", BuildSignalStatsValueText(vbTrades, vbWins, vbLosses, vbProfit), GetProfitColor(vbProfit), 130);
   SetDashboardValueLine("stat_wb", 322, "W SHAPE BUY", BuildSignalStatsValueText(wbTrades, wbWins, wbLosses, wbProfit), GetProfitColor(wbProfit), 130);
   SetDashboardValueLine("stat_sb", 340, "STRONG BUY", BuildSignalStatsValueText(sbTrades, sbWins, sbLosses, sbProfit), GetProfitColor(sbProfit), 130);
   SetDashboardValueLine("stat_ts", 358, "TREND SELL", BuildSignalStatsValueText(tsTrades, tsWins, tsLosses, tsProfit), GetProfitColor(tsProfit), 130);
   SetDashboardValueLine("stat_vs", 376, "V SHAPE SELL", BuildSignalStatsValueText(vsTrades, vsWins, vsLosses, vsProfit), GetProfitColor(vsProfit), 130);
   SetDashboardValueLine("stat_ws", 394, "W SHAPE SELL", BuildSignalStatsValueText(wsTrades, wsWins, wsLosses, wsProfit), GetProfitColor(wsProfit), 130);
   SetDashboardValueLine("stat_ss", 412, "STRONG SELL", BuildSignalStatsValueText(ssTrades, ssWins, ssLosses, ssProfit), GetProfitColor(ssProfit), 130);
   SetDashboardValueLine("best", 434, "Best Signal", GetSignalDisplayName(bestSignal) +
                         (bestSignal == "NO CLOSED TRADES" ? "" : ("  P/L:$" + DoubleToString(bestProfit, 2))),
                         bestSignal == "NO CLOSED TRADES" ? clrDimGray : GetProfitColor(bestProfit), 130);

   SetDashboardLine("openstatshead", 20, 462, "Signal Stats  (open trades / unrealised)", clrBlack, 10);
   SetDashboardValueLine("open_tb", 484, "TREND BUY", BuildOpenSignalStatsValueText(tbOpen, tbOpenProfit),
                         tbOpen > 0 ? GetProfitColor(tbOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_vb", 502, "V SHAPE BUY", BuildOpenSignalStatsValueText(vbOpen, vbOpenProfit),
                         vbOpen > 0 ? GetProfitColor(vbOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_wb", 520, "W SHAPE BUY", BuildOpenSignalStatsValueText(wbOpen, wbOpenProfit),
                         wbOpen > 0 ? GetProfitColor(wbOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_sb", 538, "STRONG BUY", BuildOpenSignalStatsValueText(sbOpen, sbOpenProfit),
                         sbOpen > 0 ? GetProfitColor(sbOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_ts", 556, "TREND SELL", BuildOpenSignalStatsValueText(tsOpen, tsOpenProfit),
                         tsOpen > 0 ? GetProfitColor(tsOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_vs", 574, "V SHAPE SELL", BuildOpenSignalStatsValueText(vsOpen, vsOpenProfit),
                         vsOpen > 0 ? GetProfitColor(vsOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_ws", 592, "W SHAPE SELL", BuildOpenSignalStatsValueText(wsOpen, wsOpenProfit),
                         wsOpen > 0 ? GetProfitColor(wsOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_ss", 610, "STRONG SELL", BuildOpenSignalStatsValueText(ssOpen, ssOpenProfit),
                         ssOpen > 0 ? GetProfitColor(ssOpenProfit) : clrDimGray, 130);
   SetDashboardValueLine("open_total", 632, "Open Signal P/L",
                         "$" + DoubleToString(tbOpenProfit + vbOpenProfit + wbOpenProfit + sbOpenProfit +
                               tsOpenProfit + vsOpenProfit + wsOpenProfit + ssOpenProfit, 2),
                         GetProfitColor(tbOpenProfit + vbOpenProfit + wbOpenProfit + sbOpenProfit +
                                        tsOpenProfit + vsOpenProfit + wsOpenProfit + ssOpenProfit), 130);
   SetDashboardValueLine("buylimit", 654, "Buy Limit",
                         IntegerToString(buyOrders) + "/" + FormatLimitValue(effectiveBuyMax) +
                         "  Upd " + FormatDashboardDateTime(lastBuyOrderUpdateTime),
                         GetLimitColor(OP_BUY), 108);
   SetDashboardValueLine("selllimit", 676, "Sell Limit",
                         IntegerToString(sellOrders) + "/" + FormatLimitValue(effectiveSellMax) +
                         "  Upd " + FormatDashboardDateTime(lastSellOrderUpdateTime),
                         GetLimitColor(OP_SELL), 108);
  }

//+------------------------------------------------------------------+
void BuildDashboardState(string &status, string &liveReason)
  {
   status = "WAIT";
   liveReason = "WAITING BARS";

   if(Bars < 5)
      return;

   double emaFast0 = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,0);
   double emaSlow0 = iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,0);
   double emaTrend0 = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,0);

   if(emaFast0 > emaSlow0 && Close[0] > emaTrend0)
      status = "BULL TREND";

   if(emaFast0 < emaSlow0 && Close[0] < emaTrend0)
      status = "BEAR TREND";

   liveReason = "NO SIGNAL";
   int signalShift = 0;

   if(IsEquityProfitPauseWindow())
     {
      status = "WITHDRAW PROFIT";
      liveReason = GetEquityProfitPauseReason();
      return;
     }

   if(IsSessionPauseWindow())
     {
      liveReason = GetSessionPauseReason();
      return;
     }

   bool bullMomentum1 = false, bearMomentum1 = false;
   bool trendBuy1 = false, reversalBuy1 = false, strongBuy1 = false;
   bool trendSell1 = false, reversalSell1 = false, strongSell1 = false;
   bool emaPullbackBuy1 = false, emaPullbackSell1 = false;
   bool rsiBounceBuy1 = false, rsiBounceSell1 = false;
   bool prevBullMomentum2 = false, prevBearMomentum2 = false;
   bool trendBuy2 = false, reversalBuy2 = false, strongBuy2 = false;
   bool trendSell2 = false, reversalSell2 = false, strongSell2 = false;
   bool emaPullbackBuy2 = false, emaPullbackSell2 = false;
   bool rsiBounceBuy2 = false, rsiBounceSell2 = false;

   EvaluateSignalFlags(signalShift, bullMomentum1, bearMomentum1,
                       trendBuy1, reversalBuy1, strongBuy1,
                       trendSell1, reversalSell1, strongSell1,
                       emaPullbackBuy1, emaPullbackSell1, rsiBounceBuy1, rsiBounceSell1);
   EvaluateSignalFlags(signalShift + 1, prevBullMomentum2, prevBearMomentum2,
                       trendBuy2, reversalBuy2, strongBuy2,
                       trendSell2, reversalSell2, strongSell2,
                       emaPullbackBuy2, emaPullbackSell2, rsiBounceBuy2, rsiBounceSell2);

   bool trendBuyConfirmed1 = trendBuy1;// true;//trendBuy1 && trendBuy2;
   bool trendSellConfirmed1 = trendSell1;// true;//trendSell1 && trendSell2;

   if(trendBuy1)
     {
      if(trendBuyConfirmed1)
         liveReason = GetEntryReason(OP_BUY, "TREND BUY READY", Close[signalShift]);
      else
         liveReason = "TREND BUY WAIT 2X";
     }
   else
      if(reversalBuy1)
         liveReason = GetEntryReason(OP_BUY, GetReversalSignalName(signalShift, OP_BUY) + " READY", Close[signalShift]);
      else
         if(strongBuy1)
            liveReason = GetEntryReason(OP_BUY, "STRONG BUY READY", Close[signalShift]);
         else
            if(trendSell1)
              {
               if(trendSellConfirmed1)
                  liveReason = GetEntryReason(OP_SELL, "TREND SELL READY", Close[signalShift]);
               else
                  liveReason = "TREND SELL WAIT 2X";
              }
            else
               if(reversalSell1)
                  liveReason = GetEntryReason(OP_SELL, GetReversalSignalName(signalShift, OP_SELL) + " READY", Close[signalShift]);
               else
                  if(strongSell1)
                     liveReason = GetEntryReason(OP_SELL, "STRONG SELL READY", Close[signalShift]);
                  else
                     if(bullMomentum1)
                        liveReason = GetEntryReason(OP_BUY, "MOM BUY READY", Close[signalShift]);
                     else
                        if(bearMomentum1)
                           liveReason = GetEntryReason(OP_SELL, "MOM SELL READY", Close[signalShift]);
                        else
                           if(!EnableAutoTrading)
                              liveReason = "AUTO TRADING INPUT OFF";
                           else
                              if(!IsTradeAllowed())
                                 liveReason = "MT4 LIVE TRADING OFF";
                              else
                                 if(!IsSpreadOK())
                                    liveReason = "SPREAD HIGH";
  }

//+------------------------------------------------------------------+
void RefreshDashboard()
  {
   string status = "WAIT";
   string liveReason = "WAITING BARS";

   BuildDashboardState(status, liveReason);
   UpdateDashboard(status, liveReason);
   Comment("");
   ChartRedraw();
   lastDashboardRefreshTime = GetTradeClock();
  }

//+------------------------------------------------------------------+
void MaybeRefreshDashboardOnTick()
  {
   datetime now = GetTradeClock();
   int refreshSeconds = MathMax(1, DashboardRefreshSeconds);

   if(lastDashboardRefreshTime == 0 || (now - lastDashboardRefreshTime) >= refreshSeconds)
      RefreshDashboard();
  }

//+------------------------------------------------------------------+
// Set market open time per symbol (GMT+2 broker server time).
// 30 min before and after this time will be blocked from trading.
// Add or edit entries below. Unrecognised symbols use input defaults.
//+------------------------------------------------------------------+
void ApplySymbolSessionTimes()
  {
   string name = Symbol();

   // start from input defaults
   effSessionOpenHour   = SessionOpenHour;
   effSessionOpenMinute = SessionOpenMinute;

   // --- Forex major pairs — weekly open Sunday 21:00 GMT+2 ---
   if(name=="EURUSDm" || name=="EURUSDt" || name=="EURUSD" ||
      name=="GBPUSDm" || name=="GBPUSDt" || name=="GBPUSD" ||
      name=="USDJPYm" || name=="USDJPYt" || name=="USDJPY" ||
      name=="USDCHFm" || name=="USDCHFt" || name=="USDCHF" ||
      name=="AUDUSDm" || name=="AUDUSDt" || name=="AUDUSD" ||
      name=="USDCADm" || name=="USDCADt" || name=="USDCAD" ||
      name=="NZDUSDm" || name=="NZDUSDt" || name=="NZDUSD")
     { effSessionOpenHour = 21; effSessionOpenMinute = 0; }

   // --- XAU/XAG (Gold/Silver) — commodity open Sunday 21:00 GMT+2 ---
   else if(name=="XAUUSDm" || name=="XAUUSDt" || name=="XAUUSD" ||
           name=="XAGUSDm" || name=="XAGUSDt" || name=="XAGUSD")
     { effSessionOpenHour = 21; effSessionOpenMinute = 0; }

   // --- US Indices — NYSE/NASDAQ open 15:30 GMT+2 (9:30 AM EST) ---
   else if(name=="US30m"   || name=="US30"   ||
           name=="NAS100m" || name=="NAS100" ||
           name=="SPX500m" || name=="SPX500")
     { effSessionOpenHour = 15; effSessionOpenMinute = 30; }

   // --- BTC/ETH — trades 24/7, disable session pause ---
   else if(name=="BTCUSDm" || name=="BTCUSDt" || name=="BTCUSD" ||
           name=="ETHUSDm" || name=="ETHUSDt" || name=="ETHUSD")
     { effSessionOpenHour = -1; effSessionOpenMinute = 0; } // -1 = no pause

   // else: uses input SessionOpenHour / SessionOpenMinute

   if(effSessionOpenHour >= 0)
      LogMessage(StringFormat("Session times: Symbol=%s  Open=%02d:%02d  Pause=±30min",
                 name, effSessionOpenHour, effSessionOpenMinute));
   else
      LogMessage("Session times: Symbol=" + name + "  24/7 — no session pause");
  }

//+------------------------------------------------------------------+
// Set LossCut / ProfitBooking / PreOpen values per symbol name.
// Add or edit entries below. Unrecognised symbols use the input defaults.
//+------------------------------------------------------------------+
void ApplySymbolDefaults()
  { 
   string name = Symbol();

   // start from input defaults
   effLossCutUSD            = LossCutUSD;
   effProfitBookingUSD      = ProfitBookingUSD;
   effPreOpenCloseProfitUSD = PreOpenCloseProfitUSD;

   // Loss cut is set to 2× profit target — risk is always proportional to reward.
   // Break-even at $0.15 means most trades become risk-free before reaching $0.50 target.
   if(name == "BTCUSDm" || name == "BTCUSDt" || name == "BTCUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "ETHUSDm" || name == "ETHUSDt" || name == "ETHUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "XAGUSDm" || name == "XAGUSDt" || name == "XAGUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "XAUUSDm" || name == "XAUUSDt" || name == "XAUUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "US30m" || name == "US30")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "NAS100m" || name == "NAS100" || name == "NASm")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "SPX500m" || name == "SPX500" || name == "SPXm")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "AUDUSDm" || name == "AUDUSDt" || name == "AUDUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "AUDJPYm" || name == "AUDJPYt" || name == "AUDJPY")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   else if(name == "EURUSDm" || name == "EURUSDt" || name == "EURUSD")
     { effLossCutUSD = 1.00; effProfitBookingUSD = 0.50; effPreOpenCloseProfitUSD = 0.20; }

   // else: symbol not listed — uses input defaults loaded above
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   eaStartTime = TimeCurrent();
   ApplySymbolSessionTimes();
   ApplySymbolDefaults();
   ResetEquityProfitPauseBaseline();
   EventSetTimer(MathMax(1, DashboardRefreshSeconds));
   RefreshDashboard();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Check if initial 30-min pause is active                          |
//+------------------------------------------------------------------+
bool IsInitialPauseActive()
  {
   return (TimeCurrent() - eaStartTime) < (waitStartSessiontime * 60); // 30 minutes in seconds
  }

//+------------------------------------------------------------------+
//| Check if MOM_BUY/MOM_SELL signals are enabled                    |
//+------------------------------------------------------------------+
bool IsMomBuyEnabled() { return EnableMomBuy; }
bool IsMomSellEnabled() { return EnableMomSell; }

//+------------------------------------------------------------------+
void OnTimer()
  {
   RefreshDashboard();
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   DeleteDashboard();
   Comment("");
  }

//+------------------------------------------------------------------+
double NormalizeLotSize(double lots)
  {
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   int lotDigits = 0;

   if(lotStep <= 0)
      lotStep = 0.01;

   double stepProbe = lotStep;
   while(stepProbe < 1.0 && lotDigits < 8)
     {
      stepProbe *= 10.0;
      lotDigits++;
     }

   double normalized = MathMax(minLot, MathMin(maxLot, lots));
   normalized = MathRound(normalized / lotStep) * lotStep;
   normalized = MathMax(minLot, MathMin(maxLot, normalized));

   return NormalizeDouble(normalized, lotDigits);
  }

//+------------------------------------------------------------------+
bool IsSpreadOK()
  {
   if(!EnableSpreadFilter)
      return true;

   if(MaxSpreadPoints <= 0)
      return true;

   RefreshRates();
   double spread = (Ask - Bid) / Point;
   return (spread <= MaxSpreadPoints);
  }

//+------------------------------------------------------------------+
bool IsEntryDistanceOK(int orderType, double signalPrice)
  {
   if(MaxEntryDistancePoints <= 0 || signalPrice <= 0.0)
      return true;

   RefreshRates();
// MT4 candle OHLC values are bid-based, so measure signal drift against Bid
// for both directions. Otherwise buy entries get blocked by spread alone.
   double currentPrice = Bid;
   double distancePoints = MathAbs(currentPrice - signalPrice) / Point;

   return (distancePoints <= MaxEntryDistancePoints);
  }

//+------------------------------------------------------------------+
bool IsSameDirectionGapOK(int orderType)
  {
   if(MinSameDirectionGapPoints <= 0)
      return true;

   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;

      double gapPoints = MathAbs(currentPrice - OrderOpenPrice()) / Point;
      if(gapPoints < MinSameDirectionGapPoints)
         return false;
     }

   return true;
  }

//+------------------------------------------------------------------+
int CountOpenOrdersByType(int orderType)
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
int CountOpenOrders()
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
double GetOpenProfitByType(int orderType)
  {
   double profit = 0.0;

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
void CloseOrdersAtProfitTarget()
  {
   if(!EnableAutoTrading || !EnableProfitBooking || effProfitBookingUSD <= 0.0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(orderProfit < effProfitBookingUSD)
         continue;

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;

      if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrGold))
        {
         LogMessage("Profit booking close failed for ticket " +
                    IntegerToString(OrderTicket()) + ": " +
                    IntegerToString(GetLastError()));
        }
      else
        {
         MarkTradeUpdate(orderType);
         prevSignal = "";
         lastAppearedStrongSignal = "";
         LogMessage("Profit target hit — prevSignal reset for fresh re-entry.");
        }
     }
  }

//+------------------------------------------------------------------+
void CloseOrdersAtLossLimit()
  {
   if(!EnableAutoTrading || !EnableLossCut || effLossCutUSD <= 0.0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(orderProfit > -effLossCutUSD)
         continue;

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;

      if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrTomato))
        {
         LogMessage("Loss cut close failed for ticket " +
                    IntegerToString(OrderTicket()) + ": " +
                    IntegerToString(GetLastError()));
        }
      else
        {
         MarkTradeUpdate(orderType);
         // Reset signal lock so the next signal in same direction is not blocked
         prevSignal = "";
         LogMessage("Loss cut hit — prevSignal reset for fresh re-entry.");
         RecordOrderResult(true);
        }
     }
  }

//+------------------------------------------------------------------+
// Daily loss limit — resets at midnight, blocks all new orders if hit
//+------------------------------------------------------------------+
void CheckDailyLossLimit()
  {
   if(!EnableDailyLossLimit || DailyLossLimitUSD <= 0)
      return;

   // Reset at start of new day
   datetime now       = GetTradeClock();
   datetime todayDate = now - (now % 86400);
   if(lastDailyResetDate != todayDate)
     {
      dailyStartBalance     = AccountBalance();
      dailyLossTriggered    = false;
      dailyProfitTriggered  = false;
      lastDailyResetDate  = todayDate;
      LogMessage(StringFormat("Daily loss limit reset. Start balance: %.2f", dailyStartBalance));
     }

   if(dailyLossTriggered)
      return;

   double todayLoss = dailyStartBalance - AccountEquity();
   if(todayLoss >= DailyLossLimitUSD)
     {
      dailyLossTriggered = true;
      LogMessage(StringFormat("Daily loss limit hit: -$%.2f. No more orders today.", todayLoss));

      // Close all open orders immediately
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
         int ot = OrderType();
         if(ot != OP_BUY && ot != OP_SELL) continue;
         RefreshRates();
         double cp = (ot == OP_BUY) ? Bid : Ask;
         if(OrderClose(OrderTicket(), OrderLots(), cp, Slippage, clrRed))
           { MarkTradeUpdate(ot); prevSignal = ""; }
        }
     }
  }

bool IsDailyLossLimitActive()
  {
   return (EnableDailyLossLimit && dailyLossTriggered);
  }

//+------------------------------------------------------------------+
// Break-Even: move SL to entry when profit reaches BreakEvenProfitUSD
// Trailing Stop: keep locking in profit as price moves further
//+------------------------------------------------------------------+
void ManageBreakEvenAndTrailing()
  {
   if(!EnableBreakEven && !EnableTrailingStop) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int    ot      = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;

      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double profit    = OrderProfit() + OrderSwap() + OrderCommission();
      double point     = MarketInfo(Symbol(), MODE_POINT);
      double tickVal   = MarketInfo(Symbol(), MODE_TICKVALUE);
      double lots      = OrderLots();
      double newSL     = currentSL;

      RefreshRates();

      if(ot == OP_BUY)
        {
         // Break-Even
         if(EnableBreakEven && profit >= BreakEvenProfitUSD && currentSL < openPrice)
            newSL = openPrice + point; // 1 point above entry = risk-free

         // Trailing Stop — lock in profit above breakeven
         if(EnableTrailingStop && profit >= BreakEvenProfitUSD)
           {
            double trailPrice = Bid - (TrailingStopUSD / (lots * tickVal / point)) * point;
            if(trailPrice > newSL)
               newSL = trailPrice;
           }

         if(newSL > currentSL && newSL < Bid)
            OrderModify(OrderTicket(), openPrice, NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrAqua);
        }
      else if(ot == OP_SELL)
        {
         // Break-Even
         if(EnableBreakEven && profit >= BreakEvenProfitUSD && (currentSL == 0 || currentSL > openPrice))
            newSL = openPrice - point;

         // Trailing Stop
         if(EnableTrailingStop && profit >= BreakEvenProfitUSD)
           {
            double trailPrice = Ask + (TrailingStopUSD / (lots * tickVal / point)) * point;
            if(currentSL == 0 || trailPrice < newSL)
               newSL = trailPrice;
           }

         if(newSL > 0 && (currentSL == 0 || newSL < currentSL) && newSL > Ask)
            OrderModify(OrderTicket(), openPrice, NormalizeDouble(newSL, Digits), OrderTakeProfit(), 0, clrOrange);
        }
     }
  }

//+------------------------------------------------------------------+
// Daily Profit Target — stop trading today when profit goal reached
//+------------------------------------------------------------------+
void CheckDailyProfitTarget()
  {
   if(!EnableDailyProfitTarget || DailyProfitTargetUSD <= 0 || dailyProfitTriggered) return;

   datetime now      = GetTradeClock();
   datetime today    = now - (now % 86400);
   if(lastDailyResetDate != today) return; // let CheckDailyLossLimit handle reset

   double todayProfit = AccountEquity() - dailyStartBalance;
   if(todayProfit >= DailyProfitTargetUSD)
     {
      dailyProfitTriggered = true;
      LogMessage(StringFormat("Daily profit target reached: +$%.2f. No more orders today.", todayProfit));
     }
  }

bool IsDailyProfitTargetActive()
  {
   return (EnableDailyProfitTarget && dailyProfitTriggered);
  }

//+------------------------------------------------------------------+
// Consecutive Loss Pause — pause trading after N losses in a row
//+------------------------------------------------------------------+
void RecordOrderResult(bool wasLoss)
  {
   if(!EnableConsecutiveLossPause) return;
   if(wasLoss)
     {
      consecutiveLosses++;
      if(consecutiveLosses >= MaxConsecutiveLosses)
        {
         consecutiveLossPauseUntil = GetTradeClock() + ConsecutiveLossPauseMin * 60;
         consecutiveLosses = 0;
         LogMessage(StringFormat("Consecutive loss pause: %d losses. Pausing %d min.", MaxConsecutiveLosses, ConsecutiveLossPauseMin));
        }
     }
   else
      consecutiveLosses = 0; // reset on any win
  }

bool IsConsecutiveLossPauseActive()
  {
   return (EnableConsecutiveLossPause && GetTradeClock() < consecutiveLossPauseUntil);
  }

//+------------------------------------------------------------------+
// Weekend Close — close all orders on Friday before market closes
//+------------------------------------------------------------------+
void CheckWeekendClose()
  {
   if(!EnableWeekendClose) return;

   datetime now = GetTradeClock();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   // Friday = day 5
   if(dt.day_of_week != 5) return;

   int currentMin = dt.hour * 60 + dt.min;
   int closeMin   = WeekendCloseHour * 60 + WeekendCloseMinute;
   if(currentMin < closeMin) return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      int ot = OrderType();
      if(ot != OP_BUY && ot != OP_SELL) continue;
      RefreshRates();
      double cp = (ot == OP_BUY) ? Bid : Ask;
      if(OrderClose(OrderTicket(), OrderLots(), cp, Slippage, clrGray))
        { MarkTradeUpdate(ot); prevSignal = ""; LogMessage("Weekend close executed."); }
     }
  }

//+------------------------------------------------------------------+
// Condition 2: Close order if it has been open longer than MaxOrderDurationMin
//+------------------------------------------------------------------+
void CloseOrdersByDuration()
  {
   if(!EnableAutoTrading || !EnableDurationClose || MaxOrderDurationMin <= 0)
      return;

   datetime now = GetTradeClock();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      int openMinutes = (int)((now - OrderOpenTime()) / 60);
      if(openMinutes < MaxOrderDurationMin)
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      // Skip duration close if trade is already profitable enough — let profit booking or
      // trailing stop handle it. Closing a +$0.40 trade early kills your scalping gains.
      if(DurationSkipIfProfitUSD > 0 && profit >= DurationSkipIfProfitUSD)
        {
         LogMessage("Duration elapsed but profit $" + DoubleToString(profit,2) + " — letting it run to target.");
         continue;
        }

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      bool wasLoss = (profit < 0); // capture before close — OrderProfit() becomes 0 after close
      if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrSilver))
         LogMessage("Duration close failed ticket " + IntegerToString(OrderTicket()) + ": " + IntegerToString(GetLastError()));
      else
        {
         MarkTradeUpdate(orderType);
         prevSignal = "";
         LogMessage("Duration close: " + IntegerToString(MaxOrderDurationMin) + " min elapsed. P/L $" + DoubleToString(profit,2));
         RecordOrderResult(wasLoss);
        }
     }
  }

//+------------------------------------------------------------------+
// Condition 3: Close BUY if market turns bearish, close SELL if bullish
//+------------------------------------------------------------------+
void CloseOrdersByTrendReversal()
  {
   if(!EnableAutoTrading || !EnableTrendReversalClose)
      return;

   double emaFast  = iMA(NULL, 0, FastEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow  = iMA(NULL, 0, SlowEMA,  0, MODE_EMA, PRICE_CLOSE, 1);
   double emaTrend = iMA(NULL, 0, TrendEMA, 0, MODE_EMA, PRICE_CLOSE, 1);

   bool marketBearish = (emaFast < emaSlow) && (Bid < emaTrend);
   bool marketBullish = (emaFast > emaSlow) && (Ask > emaTrend);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      bool shouldClose = false;
      string reason = "";

      if(orderType == OP_BUY && marketBearish)
        { shouldClose = true; reason = "BUY closed: market turned bearish"; }
      else if(orderType == OP_SELL && marketBullish)
        { shouldClose = true; reason = "SELL closed: market turned bullish"; }

      if(!shouldClose) continue;

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrOrange))
         LogMessage("Trend reversal close failed ticket " + IntegerToString(OrderTicket()) + ": " + IntegerToString(GetLastError()));
      else
        {
         MarkTradeUpdate(orderType);
         prevSignal = "";
         LogMessage(reason);
        }
     }
  }

//+------------------------------------------------------------------+
void CloseOrdersBeforeSessionOpen()
  {
   if(!EnableAutoTrading || !EnablePreOpenClose)
      return;

   if(!IsPreOpenCloseWindow())
      return;

   if(CountOpenOrders() <= 0)
      return;

   double totalOpenProfit = GetOpenProfitByType(OP_BUY) + GetOpenProfitByType(OP_SELL);
   if(totalOpenProfit < effPreOpenCloseProfitUSD)
      return;

   CloseOrdersByType(OP_BUY, clrSilver);
   CloseOrdersByType(OP_SELL, clrSilver);
   prevSignal = "";
   lastAppearedStrongSignal = "";
  }

//+------------------------------------------------------------------+
bool CloseOrdersByType(int orderType, color clr)
  {
   bool allClosed = true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber ||
         OrderType() != orderType)
        {
         continue;
        }

      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;

      if(!OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clr))
        {
         LogMessage("OrderClose failed for ticket " + IntegerToString(OrderTicket()) +
                    ": " + IntegerToString(GetLastError()));
         allClosed = false;
        }
      else
        {
         MarkTradeUpdate(orderType);
        }
     }

   return allClosed;
  }

//+------------------------------------------------------------------+
void StartEquityProfitPause()
  {
   datetime now = GetTradeClock();

   CloseOrdersByType(OP_BUY, clrSilver);
   CloseOrdersByType(OP_SELL, clrSilver);

   equityProfitPauseUntil = now + (EquityProfitPauseMinutes * 60);
   wasEquityProfitPauseWindow = true;
  }

//+------------------------------------------------------------------+
void HandleEquityProfitPause()
  {
   if(!EnableEquityProfitPause || EquityProfitPauseUSD <= 0.0 || EquityProfitPauseMinutes <= 0)
      return;

   if(IsEquityProfitPauseWindow())
     {
      if(CountOpenOrders() > 0)
        {
         CloseOrdersByType(OP_BUY, clrSilver);
         CloseOrdersByType(OP_SELL, clrSilver);
        }
      return;
     }

   if(GetEquityProfitSincePauseBaseline() < EquityProfitPauseUSD)
      return;

   StartEquityProfitPause();
  }

//+------------------------------------------------------------------+
void ResetAfterEquityProfitPause()
  {
   ResetAnalysisState();
   DeleteSignalMarkers();
   ResetEquityProfitPauseBaseline();
   equityProfitPauseUntil = 0;
  }

//+------------------------------------------------------------------+
bool OpenTestBuyOrder()
  {
   if(!EnableAutoTrading)
      return false;

   if(!IsTradeAllowed())
     {
      LogMessage("Test buy skipped: trading not allowed.");
      return false;
     }

   double lots = NormalizeLotSize(LotSize);
   if(AccountFreeMarginCheck(Symbol(), OP_BUY, lots) <= 0)
     {
      LogMessage("Test buy skipped: not enough free margin.");
      return false;
     }

   RefreshRates();
   int ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0,
                          "TEST BUY 5M", MagicNumber, 0, clrDodgerBlue);

   if(ticket < 0)
     {
      LogMessage("Test buy failed: " + IntegerToString(GetLastError()));
      return false;
     }

   MarkTradeUpdate(OP_BUY);
   return true;
  }

//+------------------------------------------------------------------+
void RunTestBuyEvery5Minutes()
  {
   if(!EnableTestBuyEvery5Min)
      return;

   datetime currentSlot = TimeCurrent() - (TimeCurrent() % 300);
   if(currentSlot == lastTestBuySlot)
      return;

   lastTestBuySlot = currentSlot;

   if(OpenTestBuyOrder())
      SendSignalAlert("TEST BUY - " + Symbol());
  }

//+------------------------------------------------------------------+
bool CanTradeSignalBar(int shift)
  {
   if(shift == 0)
      return true;

   return (ExecuteEverySignalInTester && IsTesting());
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetEntryReason(int orderType, string readyText, double signalPrice)
  {
   InitializeTradeUpdateTimes();

   string directionBlock = GetDirectionBlockReason(orderType, readyText);
   if(directionBlock != "")
      return directionBlock;

   if(!EnableAutoTrading)
      return "AUTO TRADING INPUT OFF";

   if(IsEquityProfitPauseWindow())
      return GetEquityProfitPauseReason();

   if(IsSessionPauseWindow())
      return GetSessionPauseReason();

   if(!IsTradeAllowed())
      return "MT4 LIVE TRADING OFF";

   if(!IsSpreadOK())
      return "SPREAD HIGH";

   if(!IsEntryDistanceOK(orderType, signalPrice))
      return "ENTRY TOO FAR";

   if(!IsSameDirectionGapOK(orderType))
      return (orderType == OP_BUY) ? "BUY GAP SMALL" : "SELL GAP SMALL";

   int oppositeType = (orderType == OP_BUY) ? OP_SELL : OP_BUY;
   int sameCount = CountOpenOrdersByType(orderType);
   int projectedTotal = CountOpenOrders();

   if(CloseOppositeOnEntry)
      projectedTotal -= CountOpenOrdersByType(oppositeType);

   int maxOrdersForType = GetEffectiveMaxOrdersForType(orderType);
   if(maxOrdersForType > 0 && sameCount >= maxOrdersForType)
      return (orderType == OP_BUY) ? "MAX BUY REACHED" : "MAX SELL REACHED";

   if(MaxTotalOrders > 0 && projectedTotal >= MaxTotalOrders)
      return "MAX ORDER REACHED";

   return readyText;
  }

//+------------------------------------------------------------------+
string GetCloseReason(int orderType, string readyText)
  {
   int sameCount = CountOpenOrdersByType(orderType);

   if(sameCount > 0)
      return readyText;

   return (orderType == OP_BUY) ? "NO BUY TO CLOSE" : "NO SELL TO CLOSE";
  }
//+------------------------------------------------------------------+
//| Returns the highest high over the last N bars (excluding current)|
//+------------------------------------------------------------------+
double GetRecentHighestHigh(int barsBack)
  {
   double highest = High[1];
   for(int i = 2; i <= barsBack; i++)
     {
      if(High[i] > highest)
         highest = High[i];
     }
   return highest;
  }
//+------------------------------------------------------------------+
bool OpenOrderByType(int orderType, string orderComment, color clr, double signalPrice)
  {
// Extra spread check for stricter filtering
   RefreshRates();
   double spreadPoints = (Ask - Bid) / Point;
   /*if(spreadPoints > 10) {
      LogMessage("Spread too high (" + DoubleToString(spreadPoints, 1) + " pts). No new order placed.");
      printf("Spread too high  " + spreadPoints +   " - "+  DoubleToString(spreadPoints, 1) + " pts). No new order placed.");
      return false;
   }*/

   InitializeTradeUpdateTimes();

// Block order if signal type is disabled
   string commentUpper = orderComment;
   if((commentUpper == "TREND BUY" && !EnableTrendBuy) ||
      (commentUpper == "V SHAPE BUY" && !EnableVShapeBuy) ||
      (commentUpper == "W SHAPE BUY" && !EnableWShapeBuy) ||
      (commentUpper == "STRONG BUY" && !EnableStrongBuy) ||
      (commentUpper == "MOM BUY" && !EnableMomBuy) ||
      (commentUpper == "TREND SELL" && !EnableTrendSell) ||
      (commentUpper == "V SHAPE SELL" && !EnableVShapeSell) ||
      (commentUpper == "W SHAPE SELL" && !EnableWShapeSell) ||
      (commentUpper == "STRONG SELL" && !EnableStrongSell) ||
      (commentUpper == "MOM SELL" && !EnableMomSell))
     {
      LogMessage(orderComment + " signal is disabled. No new order placed.");
      return false;
     }



   if((commentUpper == "TREND BUY" && !EnableTrendBuy))
     {
      LogMessage(orderComment + " signal is disabled. No new order placed.");
      return false;
     }
//2026.03.29 15:51:03.395  2026.03.16 07:29:06  V-TV-Signals EURUSDm,M1: STRONG SELL TREND SELL
   bool isPrevStrong    = StringFind(prevSignal, "STRONG") >= 0;
   bool isCurrentStrong = StringFind(currentSignal, "STRONG") >= 0;


   if(prevSignal=="STRONG BUY" && currentSignal=="TREND BUY" && Symbol()!="EURUSDm")
     {
      //continue
     }
   else
      if(prevSignal=="STRONG SELL" && currentSignal=="TREND SELL" && Symbol()!="EURUSDm")
        {
         //continue
        }

      else
         if(prevSignal == currentSignal ||   isCurrentStrong ||   isPrevStrong)
           {
            //Print("Blocked: Contains STRONG or duplicate | prev=" + prevSignal + " curr=" + currentSignal);
           // return false;
           }


   if(IsInitialPauseActive())
     {
      LogMessage("Initial 30-minute pause active. No new orders allowed.");
      return false;
     }

   string directionBlock = GetDirectionBlockReason(orderType, orderComment);
   if(directionBlock != "")
     {
      LogMessage(orderComment + " skipped: " + directionBlock);
      return false;
     }

   if(!EnableAutoTrading)
      return false;

   if(IsDailyLossLimitActive())
     {
      LogMessage(orderComment + " skipped: daily loss limit active — no more orders today.");
      return false;
     }

   if(IsDailyProfitTargetActive())
     {
      LogMessage(orderComment + " skipped: daily profit target reached — protecting gains.");
      return false;
     }

   if(IsConsecutiveLossPauseActive())
     {
      LogMessage(orderComment + " skipped: consecutive loss pause active.");
      return false;
     }

   if(IsEquityProfitPauseWindow())
     {
      LogMessage(orderComment + " skipped: " + GetEquityProfitPauseReason());
      return false;
     }

   if(IsSessionPauseWindow())
     {
      LogMessage(orderComment + " skipped: " + GetSessionPauseReason());
      return false;
     }

   if(!IsTradeAllowed())
     {
      LogMessage("Trading not allowed. Check AutoTrading and EA permissions.");
      return false;
     }

   if(!IsSpreadOK())
     {
      LogMessage("Spread too high for new order on " + Symbol());
      return false;
     }

   if(!IsEntryDistanceOK(orderType, signalPrice))
     {
      LogMessage(orderComment + " skipped: entry moved too far from signal close on " + Symbol());
      return false;
     }

   if(!IsSameDirectionGapOK(orderType))
     {
      LogMessage(orderComment + " skipped: same-direction order gap too small on " + Symbol());
      return false;
     }

   int oppositeType = (orderType == OP_BUY) ? OP_SELL : OP_BUY;
   if(CloseOppositeOnEntry)
      CloseOrdersByType(oppositeType, clrSilver);

   int maxOrdersForType = GetEffectiveMaxOrdersForType(orderType);
   if(maxOrdersForType > 0 &&
      CountOpenOrdersByType(orderType) >= maxOrdersForType)
     {
      LogMessage(orderComment + " skipped: max " +
                 ((orderType == OP_BUY) ? "buy" : "sell") +
                 " orders reached on " + Symbol());
      return false;
     }

   if(MaxTotalOrders > 0 && CountOpenOrders() >= MaxTotalOrders)
     {
      LogMessage(orderComment + " skipped: max total open orders reached on " + Symbol());
      return false;
     }

   double lots = NormalizeLotSize(LotSize);
   if(AccountFreeMarginCheck(Symbol(), orderType, lots) <= 0)
     {
      LogMessage("Not enough free margin to open " + orderComment);
      return false;
     }

   RefreshRates();

   double price = (orderType == OP_BUY) ? Ask : Bid;
   double sl = 0;
   double tp = 0;
   double minDistance = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;

   if(StopLossPoints > 0)
     {
      sl = (orderType == OP_BUY) ? price - StopLossPoints * Point
           : price + StopLossPoints * Point;

      if(minDistance > 0 && MathAbs(price - sl) < minDistance)
         sl = (orderType == OP_BUY) ? price - minDistance
              : price + minDistance;

      sl = NormalizeDouble(sl, Digits);
     }

   if(TakeProfitPoints > 0)
     {
      tp = (orderType == OP_BUY) ? price + TakeProfitPoints * Point
           : price - TakeProfitPoints * Point;

      if(minDistance > 0 && MathAbs(price - tp) < minDistance)
         tp = (orderType == OP_BUY) ? price + minDistance
              : price - minDistance;

      tp = NormalizeDouble(tp, Digits);
     }

// if(currentSignal=="TREND SELL")
//     orderType=OP_SELL;

   int ticket = OrderSend(Symbol(), orderType, lots, price, Slippage, sl, tp,
                          orderComment, MagicNumber, 0, clr);

   printf(prevSignal+" "+currentSignal);

   if(ticket < 0)
     {
      LogMessage("OrderSend failed for " + orderComment + ": " + IntegerToString(GetLastError()));
      return false;
     }

   MarkTradeUpdate(orderType);
   return true;
  }

//+------------------------------------------------------------------+
void OnTick()
  {


   if(Bars < 5)
     {
      MaybeRefreshDashboardOnTick();
      return;
     }

   InitializeTradeUpdateTimes();

   HandleEquityProfitPause();

   if(IsEquityProfitPauseWindow())
     {
      if(Bars > 1)
         lastProcessedClosedBar = Time[1];

      MaybeRefreshDashboardOnTick();
      return;
     }

   if(wasEquityProfitPauseWindow)
     {
      ResetAfterEquityProfitPause();
      wasEquityProfitPauseWindow = false;
      MaybeRefreshDashboardOnTick();
      return;
     }

   CheckDailyLossLimit();
   CheckDailyProfitTarget();
   CheckWeekendClose();
   CloseOrdersBeforeSessionOpen();
   CloseOrdersAtLossLimit();
   CloseOrdersAtProfitTarget();
   CloseOrdersByDuration();
   CloseOrdersByTrendReversal();
   ManageBreakEvenAndTrailing();

   if(IsSessionPauseWindow())
     {
      if(!wasSessionPauseWindow)
         ResetAnalysisState();

      wasSessionPauseWindow = true;

      if(Bars > 1)
         lastProcessedClosedBar = Time[1];

      MaybeRefreshDashboardOnTick();
      return;
     }

   if(wasSessionPauseWindow)
     {
      ResetAnalysisState();
      DeleteSignalMarkers();
      wasSessionPauseWindow = false;
      MaybeRefreshDashboardOnTick();
      return;
     }

//RunTestBuyEvery5Minutes();

   bool firstRun = (lastProcessedClosedBar == 0);
   bool hasNewClosedBar = (Time[1] != lastProcessedClosedBar);

   int maxStartBar = Bars - 3; // i+2 is used below, so keep 2 spare bars
   int startBar = 0;

   if(firstRun)
      startBar = MathMin(maxStartBar, 300); // initial chart backfill + live bar
   else
      if(hasNewClosedBar)
         startBar = 1; // redraw the newest closed candle and evaluate the live bar
      else
         startBar = 0; // always evaluate the live candle on every tick

   if(startBar >= 0)
     {
      for(int i = startBar; i >= 0; i--)
        {
         bool bullMomentum = false, bearMomentum = false;
         bool trendBuy = false, reversalBuy = false, strongBuy = false;
         bool trendSell = false, reversalSell = false, strongSell = false;
         bool emaPullbackBuy = false, emaPullbackSell = false;
         bool rsiBounceBuy = false, rsiBounceSell = false;
         bool prevBullMomentum = false, prevBearMomentum = false;
         bool prevTrendBuy = false, prevReversalBuy = false, prevStrongBuy = false;
         bool prevTrendSell = false, prevReversalSell = false, prevStrongSell = false;
         bool prevEmaPullbackBuy = false, prevEmaPullbackSell = false;
         bool prevRsiBounceBuy = false, prevRsiBounceSell = false;

         EvaluateSignalFlags(i, bullMomentum, bearMomentum,
                             trendBuy, reversalBuy, strongBuy,
                             trendSell, reversalSell, strongSell,
                             emaPullbackBuy, emaPullbackSell, rsiBounceBuy, rsiBounceSell);
         EvaluateSignalFlags(i + 1, prevBullMomentum, prevBearMomentum,
                             prevTrendBuy, prevReversalBuy, prevStrongBuy,
                             prevTrendSell, prevReversalSell, prevStrongSell,
                             prevEmaPullbackBuy, prevEmaPullbackSell, prevRsiBounceBuy, prevRsiBounceSell);

         bool trendBuyConfirmed = true;//trendBuy && prevTrendBuy;
         bool trendSellConfirmed = true;//trendSell && prevTrendSell;

         datetime t = Time[i];
         string reversalBuyName = GetReversalSignalName(i, OP_BUY);
         string reversalSellName = GetReversalSignalName(i, OP_SELL);

         // =========================
         // MOMENTUM DOT
         // =========================
         if(bullMomentum)
            DrawMarker("MOM_BUY",".",clrYellow,159,t,Low[i]-5*Point);

         if(bearMomentum)
            DrawMarker("MOM_SELL",".",clrOrange,159,t,High[i]+5*Point);

         // =========================
         // BUY SIGNALS
         // =========================
         if(trendBuy)
           {
            DrawMarker("TB","TREND BUY",clrLime,233,t,Low[i]-10*Point);
           }
         else
            if(reversalBuy)
              {
               DrawMarker("RB",reversalBuyName,clrAqua,233,t,Low[i]-10*Point);
              }
            else
               if(strongBuy)
                 {
                  DrawMarker("SB","STRONG BUY",clrBlue,233,t,Low[i]-10*Point);
                 }

         // =========================
         // SELL SIGNALS
         // =========================
         if(trendSell)
           {
            DrawMarker("TS","TREND SELL",clrRed,234,t,High[i]+10*Point);
           }
         else
            if(reversalSell)
              {
               DrawMarker("RS",reversalSellName,clrMagenta,234,t,High[i]+10*Point);
              }
            else
               if(strongSell)
                 {
                  DrawMarker("SS","STRONG SELL",clrPink,234,t,High[i]+10*Point);
                 }

         // =========================
         // ALERT (ONLY LATEST CLOSED CANDLE)
         // =========================
         if(CanTradeSignalBar(i))
           {
            if(trendBuyConfirmed && IsBuyDirectionAllowed() && lastTrendBuyTradeTime != t && lastAnyBuyBarTime != t)
              {
               int lookback = 10;
               double recentHigh = GetRecentHighestHigh(lookback);
               double minDistancePoints = 10;
               if((recentHigh - Ask) < minDistancePoints * Point)
                 {
                  //Print("Trend Buy blocked: price too close to recent high.");
                  //return;
                 }

               /*if(prevSignal==currentSignal)
                 {
                  Print("Trend Buy blocked: prevSignal"+prevSignal+" - "+currentSignal);
                  return  ;
                 }*/

               // Place order as usual
               if(EnableAutoTrading)
                 {
                  if(OpenOrderByType(OP_BUY, "TREND BUY", clrLime, Close[i]))
                    {
                     lastTrendBuyTradeTime = t;
                     lastAnyBuyBarTime     = t;
                     prevSignal = "TREND BUY";
                    }
                 }
               else
                 {
                  lastTrendBuyTradeTime = t;
                 }

               if(i == 1 && lastAlertTime != t)
                 {
                  SendSignalAlert("TREND BUY - " + Symbol());
                  lastAlertTime = t;
                 }
              }
            else
               if(reversalBuy && IsBuyDirectionAllowed() && lastRevBuyTradeTime != t && lastAnyBuyBarTime != t &&
                  ((reversalBuyName == "W SHAPE BUY" && EnableWShapeBuy) || (reversalBuyName == "V SHAPE BUY" && EnableVShapeBuy)))
                 {
                  if(EnableAutoTrading)
                    {
                     if(OpenOrderByType(OP_BUY, reversalBuyName, clrAqua, Close[i]))
                       {
                        lastRevBuyTradeTime = t;
                        lastAnyBuyBarTime   = t;
                        prevSignal = reversalBuyName;
                       }
                    }
                  else
                    {
                     lastRevBuyTradeTime = t;
                    }

                  if(i == 1 && lastAlertTime != t)
                    {
                     SendSignalAlert(reversalBuyName + " - " + Symbol());
                     lastAlertTime = t;
                    }
                 }
               else
                  if(strongBuy && IsBuyDirectionAllowed() && lastStrongBuyTradeTime != t && lastAnyBuyBarTime != t)
                    {
                     if(EnableAutoTrading)
                       {
                        if(OpenOrderByType(OP_BUY, "STRONG BUY", clrGreen, Close[i]))
                          {
                           lastStrongBuyTradeTime = t;
                           lastAnyBuyBarTime      = t;
                           prevSignal = "STRONG BUY";
                          }
                       }
                     else
                       {
                        lastStrongBuyTradeTime = t;
                       }

                     if(i == 1 && lastAlertTime != t)
                       {
                        SendSignalAlert("STRONG BUY - " + Symbol());
                        lastAlertTime = t;
                       }
                    }
                  else
                     if(bullMomentum && IsBuyDirectionAllowed() && lastMomBuyTradeTime != t)
                       {
                        if(EnableMomBuy)
                          {
                           if(EnableAutoTrading)
                             {
                              if(OpenOrderByType(OP_BUY, "MOM BUY", clrYellow, Close[i]))
                                {
                                 lastMomBuyTradeTime = t;
                                 prevSignal = "MOM BUY";
                                }
                             }
                           else
                             {
                              lastMomBuyTradeTime = t;
                             }

                           if(i == 1 && lastAlertTime != t)
                             {
                              SendSignalAlert("MOM BUY - " + Symbol());
                              lastAlertTime = t;
                             }
                          }
                       }
                     else
                        if(emaPullbackBuy && EnableEmaPullback && IsBuyDirectionAllowed() && lastEmaPullbackBuyTime != t && lastAnyBuyBarTime != t)
                          {
                           if(EnableAutoTrading)
                             {
                              if(OpenOrderByType(OP_BUY, "EMA PULLBACK BUY", clrCyan, Close[i]))
                                {
                                 lastEmaPullbackBuyTime = t;
                                 lastAnyBuyBarTime      = t;
                                 prevSignal = "EMA PULLBACK BUY";
                                }
                             }
                           else
                              lastEmaPullbackBuyTime = t;
                          }
                        else
                           if(rsiBounceBuy && EnableRsiBounce && IsBuyDirectionAllowed() && lastRsiBounceByTime != t && lastAnyBuyBarTime != t)
                             {
                              if(EnableAutoTrading)
                                {
                                 if(OpenOrderByType(OP_BUY, "RSI BOUNCE BUY", clrLimeGreen, Close[i]))
                                   {
                                    lastRsiBounceByTime = t;
                                    lastAnyBuyBarTime   = t;
                                    prevSignal = "RSI BOUNCE BUY";
                                   }
                                }
                              else
                                 lastRsiBounceByTime = t;
                             }
                           else
                              if(trendSellConfirmed && IsSellDirectionAllowed() && lastTrendSellTradeTime != t && lastAnySellBarTime != t && lastAnyBuyBarTime != t)
                          {
                           if(EnableAutoTrading)
                             {


                              int lookback =10; // Number of bars to look back
                              double recentLow = GetRecentLowestLow(lookback);
                              double minDistancePoints = 10; // Minimum distance from low in points

                              if((Bid - recentLow) < minDistancePoints * Point)
                                {
                                 // Print("Trend Sell blocked: price too close to recent low.");
                                 //return; // or return false; depending on your function
                                }






                              if(OpenOrderByType(OP_SELL, "TREND SELL", clrRed, Close[i]))
                                {
                                 lastTrendSellTradeTime = t;
                                 lastAnySellBarTime     = t;
                                 prevSignal = "TREND SELL";
                                }
                             }




                           else
                             {
                              lastTrendSellTradeTime = t;
                             }

                           if(i == 1 && lastAlertTime != t)
                             {
                              SendSignalAlert("TREND SELL - " + Symbol());
                              lastAlertTime = t;
                             }
                          }
                        else
                           if(reversalSell && IsSellDirectionAllowed() && lastRevSellTradeTime != t && lastAnySellBarTime != t && lastAnyBuyBarTime != t &&
                              ((reversalSellName == "W SHAPE SELL" && EnableWShapeSell) || (reversalSellName == "V SHAPE SELL" && EnableVShapeSell)))
                             {
                              if(EnableAutoTrading)
                                {
                                 if(OpenOrderByType(OP_SELL, reversalSellName, clrMagenta, Close[i]))
                                   {
                                    lastRevSellTradeTime = t;
                                    lastAnySellBarTime   = t;
                                    prevSignal = reversalSellName;
                                   }
                                }
                              else
                                {
                                 lastRevSellTradeTime = t;
                                }

                              if(i == 1 && lastAlertTime != t)
                                {
                                 SendSignalAlert(reversalSellName + " - " + Symbol());
                                 lastAlertTime = t;
                                }
                             }
                           else
                              if(strongSell && IsSellDirectionAllowed() && lastStrongSellTradeTime != t && lastAnySellBarTime != t && lastAnyBuyBarTime != t)
                                {
                                 if(EnableAutoTrading)
                                   {
                                    if(OpenOrderByType(OP_SELL, "STRONG SELL", clrOrangeRed, Close[i]))
                                      {
                                       lastStrongSellTradeTime = t;
                                       lastAnySellBarTime      = t;
                                       prevSignal = "STRONG SELL";
                                      }
                                   }
                                 else
                                   {
                                    lastStrongSellTradeTime = t;
                                   }

                                 if(i == 1 && lastAlertTime != t)
                                   {
                                    SendSignalAlert("STRONG SELL - " + Symbol());
                                    lastAlertTime = t;
                                   }
                                }
                              else
                                 if(bearMomentum && IsSellDirectionAllowed() && lastMomSellTradeTime != t)
                                   {
                                    if(EnableMomSell)
                                      {
                                       if(EnableAutoTrading)
                                         {
                                          if(OpenOrderByType(OP_SELL, "MOM SELL", clrOrange, Close[i]))
                                            {
                                             lastMomSellTradeTime = t;
                                             prevSignal = "MOM SELL";
                                            }
                                         }
                                       else
                                         {
                                          lastMomSellTradeTime = t;
                                         }

                                       if(i == 1 && lastAlertTime != t)
                                         {
                                          SendSignalAlert("MOM SELL - " + Symbol());
                                          lastAlertTime = t;
                                         }
                                      }
                                   }

         // EMA Pullback SELL
         if(emaPullbackSell && EnableEmaPullback && IsSellDirectionAllowed() && lastEmaPullbackSellTime != t && lastAnySellBarTime != t && lastAnyBuyBarTime != t)
           {
            if(EnableAutoTrading)
              {
               if(OpenOrderByType(OP_SELL, "EMA PULLBACK SELL", clrAquamarine, Close[i]))
                 {
                  lastEmaPullbackSellTime = t;
                  lastAnySellBarTime      = t;
                  prevSignal = "EMA PULLBACK SELL";
                 }
              }
            else
               lastEmaPullbackSellTime = t;
           }

         // RSI Bounce SELL
         if(rsiBounceSell && EnableRsiBounce && IsSellDirectionAllowed() && lastRsiBounceSellTime != t && lastAnySellBarTime != t && lastAnyBuyBarTime != t)
           {
            if(EnableAutoTrading)
              {
               if(OpenOrderByType(OP_SELL, "RSI BOUNCE SELL", clrTomato, Close[i]))
                 {
                  lastRsiBounceSellTime = t;
                  lastAnySellBarTime    = t;
                  prevSignal = "RSI BOUNCE SELL";
                 }
              }
            else
               lastRsiBounceSellTime = t;
           }
           }
        }

      lastProcessedClosedBar = Time[1];



      // prevSignal updated only on successful trade (see each signal block above)



     }

   MaybeRefreshDashboardOnTick();

// Place this in your OnTick() or OnTimer() function
   static datetime lastCall = 0;
   if(TimeCurrent() - lastCall >= 3600)  // 3600 seconds = 1 hour
     {
      lastCall = TimeCurrent();
      // prevSignal="";
     }
   DrawEMALines();
  }

//+------------------------------------------------------------------+
//| Draw EMA lines on the chart                                      |
//+------------------------------------------------------------------+
void DrawEMALines()
  {
// Draw Fast EMA (Blue)
   string fastName = "EMA_Fast";
   if(ObjectFind(0, fastName) < 0)
      ObjectCreate(0, fastName, OBJ_TREND, 0, Time[0], iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,0), Time[50], iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,50));
   ObjectSetInteger(0, fastName, OBJPROP_COLOR, clrBlue);
   ObjectSetInteger(0, fastName, OBJPROP_WIDTH, 2);

// Draw Slow EMA (Red)
   string slowName = "EMA_Slow";
   if(ObjectFind(0, slowName) < 0)
      ObjectCreate(0, slowName, OBJ_TREND, 0, Time[0], iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,0), Time[50], iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,50));
   ObjectSetInteger(0, slowName, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, slowName, OBJPROP_WIDTH, 2);

// Draw Trend EMA (Green)
   string trendName = "EMA_Trend";
   if(ObjectFind(0, trendName) < 0)
      ObjectCreate(0, trendName, OBJ_TREND, 0, Time[0], iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,0), Time[50], iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,50));
   ObjectSetInteger(0, trendName, OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, trendName, OBJPROP_WIDTH, 2);
  }

//+------------------------------------------------------------------+
//| Returns the lowest low over the last N bars (excluding current)  |
//+------------------------------------------------------------------+
double GetRecentLowestLow(int barsBack)
  {
   double lowest = Low[1];
   for(int i = 2; i <= barsBack; i++)
     {
      if(Low[i] < lowest)
         lowest = Low[i];
     }
   return lowest;
  }
//+------------------------------------------------------------------+
