//+------------------------------------------------------------------+
//| EDGE ALGO - SMART PATTERN DETECTION (PRO ELITE)                 |
//| Signals + Markers + No-Sell Zone display only                   |
//+------------------------------------------------------------------+
#property strict

#define TRADE_DIRECTION_BOTH      0
#define TRADE_DIRECTION_BUY_ONLY  1
#define TRADE_DIRECTION_SELL_ONLY 2

// ----- INPUTS ----- //
input string version             = "V2.0";
input int    FastEMA             = 21;
input int    SlowEMA             = 50;
input int    TrendEMA            = 200;
input int    RSI_Period          = 14;
input double RSI_Buy             = 55;
input double RSI_Sell            = 45;
input int    ReversalStreakCandles = 3;
input int    TradeDirectionMode  = 0;       // 0=both 1=buy only 2=sell only
input double TrendSellDailyLowGapPrice = 400; // NO SELL zone: min $ above daily low
input bool   EnableAlert         = false;
input bool   EnableSound         = true;
input bool   EnableLogMessages   = false;
input int    DashboardRefreshSeconds = 30;
input bool   ExecuteEverySignalInTester = false;

// ----- GLOBALS ----- //
string   currentSignal  = "";
string   prevSignal     = "";
string   g_liveSignalName = "";
string   g_csvFileName  = "";

datetime lastAlertTime            = 0;
datetime lastProcessedClosedBar   = 0;
datetime lastDashboardRefreshTime = 0;

datetime lastTrendBuyTradeTime  = 0;
datetime lastRevBuyTradeTime    = 0;
datetime lastStrongBuyTradeTime = 0;
datetime lastMomBuyTradeTime    = 0;
datetime lastTrendSellTradeTime = 0;
datetime lastRevSellTradeTime   = 0;
datetime lastStrongSellTradeTime= 0;
datetime lastMomSellTradeTime   = 0;

//+------------------------------------------------------------------+
// Utility
//+------------------------------------------------------------------+
bool IsBuyDirectionAllowed()  { return (TradeDirectionMode != TRADE_DIRECTION_SELL_ONLY); }
bool IsSellDirectionAllowed() { return (TradeDirectionMode != TRADE_DIRECTION_BUY_ONLY);  }

void LogMessage(string msg)  { if(EnableLogMessages) Print(msg); }

void SendSignalAlert(string msg)
  {
   if(EnableAlert)  Alert(msg);
   if(EnableSound)  PlaySound("alert.wav");
  }

datetime GetTradeClock()
  {
   datetime now = TimeCurrent();
   if(now <= 0 && Bars > 0) now = Time[0];
   return now;
  }

//+------------------------------------------------------------------+
// Draw signal marker (arrow + text) on chart
//+------------------------------------------------------------------+
void DrawMarker(string prefix, string text, color clr, int arrow, datetime t, double price)
  {
   string arrowId = prefix + "_" + IntegerToString(t) + "_A";
   string textId  = prefix + "_" + IntegerToString(t) + "_T";

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

   if(text != ".") currentSignal = text;
  }

//+------------------------------------------------------------------+
// Signal detection helpers
//+------------------------------------------------------------------+
int CountConsecutiveCandleDirection(int startShift, bool bullishCandles)
  {
   int count = 0;
   for(int i = startShift; i < Bars; i++)
     {
      bool isBull = Close[i] > Open[i];
      bool isBear = Close[i] < Open[i];
      if(bullishCandles) { if(isBull) count++; else break; }
      else               { if(isBear) count++; else break; }
     }
   return count;
  }

string GetReversalSignalName(int shift, int orderType)
  {
   if(shift < 0 || shift + 2 >= Bars) return "";

   double emaFast  = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double rsiVal   = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift+1);
   double body     = MathAbs(Open[shift] - Close[shift]);
   double range    = High[shift] - Low[shift];
   double prevBody = MathAbs(Open[shift+1] - Close[shift+1]);
   double closeToLow  = (range > 0.0) ? ((Close[shift] - Low[shift]) / range) : 0.0;
   double closeToHigh = (range > 0.0) ? ((High[shift] - Close[shift]) / range) : 0.0;

   bool strongCandle        = (range > 0.0) && (body > (range * 0.6));
   bool rsiUp               = rsiVal > rsiPrev;
   bool rsiDown             = rsiVal < rsiPrev;
   bool currBull            = Close[shift] > Open[shift];
   bool currBear            = Close[shift] < Open[shift];
   bool reversalBodyStronger= body > prevBody;

   bool vReversalBuy  = Close[shift] > Close[shift+1] && Close[shift+1] < Close[shift+2];
   bool vReversalSell = Close[shift] < Close[shift+1] && Close[shift+1] > Close[shift+2];
   int  previousBearStreak = CountConsecutiveCandleDirection(shift+1, false);
   int  previousBullStreak = CountConsecutiveCandleDirection(shift+1, true);

   bool bullishReverseBreak = Close[shift] > High[shift+1];
   bool bearishReverseBreak = Close[shift] < Low[shift+1];
   bool streakReversalBuy  = currBull && previousBearStreak >= ReversalStreakCandles &&
                             closeToLow >= 0.45 && reversalBodyStronger && bullishReverseBreak;
   bool streakReversalSell = currBear && previousBullStreak >= ReversalStreakCandles &&
                             closeToHigh >= 0.45 && reversalBodyStronger && bearishReverseBreak;

   if(orderType == OP_BUY)
     {
      if(streakReversalBuy && strongCandle && rsiUp && Close[shift] > emaFast)
         return "W SHAPE BUY";
     }
   else if(orderType == OP_SELL)
     {
      if(streakReversalSell && strongCandle && rsiDown && Close[shift] < emaFast)
         return "W SHAPE SELL";
     }
   return "";
  }

void EvaluateSignalFlags(int shift,
                         bool &bullMomentum, bool &bearMomentum,
                         bool &trendBuy,     bool &reversalBuy,  bool &strongBuy,
                         bool &trendSell,    bool &reversalSell, bool &strongSell)
  {
   bullMomentum = bearMomentum = false;
   trendBuy = reversalBuy = strongBuy = false;
   trendSell = reversalSell = strongSell = false;

   if(shift < 0 || shift + 2 >= Bars) return;

   double emaFast  = iMA(NULL,0,FastEMA, 0,MODE_EMA,PRICE_CLOSE,shift);
   double emaSlow  = iMA(NULL,0,SlowEMA, 0,MODE_EMA,PRICE_CLOSE,shift);
   double emaTrend = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,shift);
   double rsiVal   = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,shift+1);

   double body  = MathAbs(Open[shift] - Close[shift]);
   double range = High[shift] - Low[shift];
   double emaGap= MathAbs(emaFast - emaSlow);
   double closeToLow  = (range > 0.0) ? ((Close[shift] - Low[shift])  / range) : 0.0;
   double closeToHigh = (range > 0.0) ? ((High[shift]  - Close[shift])/ range) : 0.0;
   double prevBody = MathAbs(Open[shift+1] - Close[shift+1]);

   bool strongCandle = (range > 0.0) && (body > (range * 0.6));
   bool strongTrend  = emaGap > (10 * Point);
   bool rsiUp   = rsiVal > rsiPrev;
   bool rsiDown = rsiVal < rsiPrev;
   bool bullTrend = Close[shift] > emaTrend && emaFast > emaSlow;
   bool bearTrend = Close[shift] < emaTrend && emaFast < emaSlow;

   bullMomentum = bullTrend && rsiUp   && strongTrend;
   bearMomentum = bearTrend && rsiDown && strongTrend;

   bool breakoutBuy  = Close[shift] > High[shift+1];
   bool breakoutSell = Close[shift] < Low[shift+1];

   bool prevBear = Close[shift+1] < Open[shift+1];
   bool prevBull = Close[shift+1] > Open[shift+1];
   bool currBull = Close[shift] > Open[shift];
   bool currBear = Close[shift] < Open[shift];
   bool bullishCloseStrong = currBull && closeToLow  >= 0.65;
   bool bearishCloseStrong = currBear && closeToHigh >= 0.65;

   bool engulfBuy  = prevBear && currBull && Open[shift] <= Close[shift+1] && Close[shift] >= Open[shift+1];
   bool engulfSell = prevBull && currBear && Open[shift] >= Close[shift+1] && Close[shift] <= Open[shift+1];

   bool reversalBuyStructure  = (GetReversalSignalName(shift, OP_BUY)  != "");
   bool reversalSellStructure = (GetReversalSignalName(shift, OP_SELL) != "");

   trendBuy    = bullMomentum && breakoutBuy  && rsiVal > RSI_Buy  && strongCandle && bullishCloseStrong;
   trendSell   = bearMomentum && breakoutSell && rsiVal < RSI_Sell && strongCandle && bearishCloseStrong;
   reversalBuy  = reversalBuyStructure;
   reversalSell = reversalSellStructure;
   strongBuy    = engulfBuy  && bullTrend && strongCandle && bullishCloseStrong;
   strongSell   = engulfSell && bearTrend && strongCandle && bearishCloseStrong;
  }

//+------------------------------------------------------------------+
// No-sell zone: daily low + gap boundary lines on chart
//+------------------------------------------------------------------+
void UpdateDailyLowProximityLines()
  {
   double dailyLow = iLow(Symbol(), PERIOD_D1, 0);
   if(dailyLow <= 0) return;

   double zoneTop = dailyLow + TrendSellDailyLowGapPrice;

   // Daily Low line (red dashed)
   string lowLine = "TS_DailyLow";
   if(ObjectFind(0, lowLine) < 0)
      ObjectCreate(0, lowLine, OBJ_HLINE, 0, 0, dailyLow);
   ObjectMove(0, lowLine, 0, 0, dailyLow);
   ObjectSetInteger(0, lowLine, OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, lowLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, lowLine, OBJPROP_WIDTH, 2);
   ObjectSetString(0,  lowLine, OBJPROP_TOOLTIP, "Daily Low: " + DoubleToString(dailyLow, Digits));

   string lowLabel = "TS_DailyLow_Lbl";
   if(ObjectFind(0, lowLabel) < 0)
      ObjectCreate(0, lowLabel, OBJ_TEXT, 0, Time[5], dailyLow);
   ObjectMove(0, lowLabel, 0, Time[5], dailyLow);
   ObjectSetText(lowLabel, " Daily Low: " + DoubleToString(dailyLow, Digits), 8, "Arial Bold", clrRed);

   // No-sell zone boundary (orange dotted)
   string zoneLine = "TS_NoSellZone";
   if(ObjectFind(0, zoneLine) < 0)
      ObjectCreate(0, zoneLine, OBJ_HLINE, 0, 0, zoneTop);
   ObjectMove(0, zoneLine, 0, 0, zoneTop);
   ObjectSetInteger(0, zoneLine, OBJPROP_COLOR, clrOrangeRed);
   ObjectSetInteger(0, zoneLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, zoneLine, OBJPROP_WIDTH, 1);
   ObjectSetString(0,  zoneLine, OBJPROP_TOOLTIP,
                   "No-Sell Zone: $" + DoubleToString(TrendSellDailyLowGapPrice,2) + " above Daily Low");

   string zoneLabel = "TS_NoSellZone_Lbl";
   if(ObjectFind(0, zoneLabel) < 0)
      ObjectCreate(0, zoneLabel, OBJ_TEXT, 0, Time[5], zoneTop);
   ObjectMove(0, zoneLabel, 0, Time[5], zoneTop);
   ObjectSetText(zoneLabel, " No-Sell Zone ($" + DoubleToString(TrendSellDailyLowGapPrice,0) +
                 " above daily low)", 8, "Arial Bold", clrOrangeRed);
  }

//+------------------------------------------------------------------+
// Current live signal label (top-right, updates every tick)
//+------------------------------------------------------------------+
void UpdateCurrentSignalLabel()
  {
   string lbl = "TS_LiveSignal";
   string sig = (g_liveSignalName == "") ? "No Signal" : g_liveSignalName;
   color  clr = clrGray;
   if(sig == "TREND SELL")                  clr = clrRed;
   else if(sig == "TREND BUY")              clr = clrLime;
   else if(StringFind(sig, "SELL") >= 0)   clr = clrOrangeRed;
   else if(StringFind(sig, "BUY")  >= 0)   clr = clrAqua;

   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 20);
   ObjectSetString(0,  lbl, OBJPROP_TEXT,      "Signal: " + sig);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  lbl, OBJPROP_FONT,      "Arial Bold");
  }

//+------------------------------------------------------------------+
// CSV signal logger
//+------------------------------------------------------------------+
void InitCSVLog()
  {
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   g_csvFileName = dateStr + "_" + Symbol() + ".csv";
   int handle = FileOpen(g_csvFileName, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle != INVALID_HANDLE)
     {
      ulong sz = FileSize(handle);
      FileClose(handle);
      if(sz > 0) return;
     }
   handle = FileOpen(g_csvFileName, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE) return;
   FileWriteString(handle, "DateTime,Symbol,Action,Signal_Name,Prev_Signal,Curr_Signal,Price\n");
   FileClose(handle);
  }

void AppendSignalLog(string action, string signalName, string prevSig, string currSig, double price)
  {
   if(g_csvFileName == "") return;
   int handle = FileOpen(g_csvFileName, FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(handle == INVALID_HANDLE)
     {
      handle = FileOpen(g_csvFileName, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle == INVALID_HANDLE) return;
      FileWriteString(handle, "DateTime,Symbol,Action,Signal_Name,Prev_Signal,Curr_Signal,Price\n");
     }
   else
      FileSeek(handle, 0, SEEK_END);
   string line = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + "," +
                 Symbol() + "," +
                 action   + "," +
                 signalName + "," +
                 (prevSig == "" ? "NONE" : prevSig) + "," +
                 (currSig == "" ? "NONE" : currSig) + "," +
                 DoubleToString(price, Digits) + "\n";
   FileWriteString(handle, line);
   FileClose(handle);
  }

//+------------------------------------------------------------------+
// CanTradeSignalBar: allow order logic on live bar (i=0) and
// on just-closed bar (i=1) when not in first-run backfill.
//+------------------------------------------------------------------+
bool CanTradeSignalBar(int shift, bool isFirstRun = false)
  {
   if(shift == 0) return true;
   if(shift == 1 && !isFirstRun) return true;
   return (ExecuteEverySignalInTester && IsTesting());
  }

//+------------------------------------------------------------------+
void MaybeRefreshDashboard()
  {
   datetime now = GetTradeClock();
   int secs = MathMax(1, DashboardRefreshSeconds);
   if(lastDashboardRefreshTime == 0 || (now - lastDashboardRefreshTime) >= secs)
     {
      lastDashboardRefreshTime = now;
      UpdateDailyLowProximityLines();
     }
  }

//+------------------------------------------------------------------+
int OnInit()
  {
   lastTrendBuyTradeTime = lastRevBuyTradeTime = lastStrongBuyTradeTime = lastMomBuyTradeTime = 0;
   lastTrendSellTradeTime = lastRevSellTradeTime = lastStrongSellTradeTime = lastMomSellTradeTime = 0;
   lastProcessedClosedBar = (Bars > 1) ? Time[1] : 0;
   InitCSVLog();
   EventSetTimer(MathMax(1, DashboardRefreshSeconds));
   UpdateDailyLowProximityLines();
   UpdateCurrentSignalLabel();
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTimer()
  {
   UpdateDailyLowProximityLines();
  }

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   ObjectDelete(0, "TS_DailyLow");
   ObjectDelete(0, "TS_DailyLow_Lbl");
   ObjectDelete(0, "TS_NoSellZone");
   ObjectDelete(0, "TS_NoSellZone_Lbl");
   ObjectDelete(0, "TS_LiveSignal");
   Comment("");
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   if(Bars < 5) return;

   bool firstRun      = (lastProcessedClosedBar == 0);
   bool hasNewClosedBar = (Time[1] != lastProcessedClosedBar);

   int maxStartBar = Bars - 3;
   int startBar;
   if(firstRun)          startBar = MathMin(maxStartBar, 300);
   else if(hasNewClosedBar) startBar = 1;
   else                  startBar = 0;

   for(int i = startBar; i >= 0; i--)
     {
      bool bullMomentum = false, bearMomentum = false;
      bool trendBuy = false, reversalBuy = false, strongBuy = false;
      bool trendSell = false, reversalSell = false, strongSell = false;

      EvaluateSignalFlags(i, bullMomentum, bearMomentum,
                          trendBuy, reversalBuy, strongBuy,
                          trendSell, reversalSell, strongSell);

      datetime t = Time[i];
      string reversalBuyName  = GetReversalSignalName(i, OP_BUY);
      string reversalSellName = GetReversalSignalName(i, OP_SELL);

      // === Momentum dots ===
      if(bullMomentum) DrawMarker("MOM_BUY",  ".", clrYellow, 159, t, Low[i]  - 5*Point);
      if(bearMomentum) DrawMarker("MOM_SELL", ".", clrOrange, 159, t, High[i] + 5*Point);

      // === Buy signals ===
      if(trendBuy)
         DrawMarker("TB", "TREND BUY",  clrLime, 233, t, Low[i] - 10*Point);
      else if(reversalBuy)
         DrawMarker("RB", reversalBuyName, clrAqua, 233, t, Low[i] - 10*Point);
      else if(strongBuy)
         DrawMarker("SB", "STRONG BUY", clrBlue, 233, t, Low[i] - 10*Point);

      // === Sell signals ===
      if(trendSell)
         DrawMarker("TS", "TREND SELL",  clrRed,    234, t, High[i] + 10*Point);
      else if(reversalSell)
         DrawMarker("RS", reversalSellName, clrMagenta, 234, t, High[i] + 10*Point);
      else if(strongSell)
         DrawMarker("SS", "STRONG SELL", clrPink,   234, t, High[i] + 10*Point);

      // === Update live signal label (i=0 only) ===
      if(i == 0)
        {
         if(trendSell)        g_liveSignalName = "TREND SELL";
         else if(trendBuy)    g_liveSignalName = "TREND BUY";
         else if(strongSell)  g_liveSignalName = "STRONG SELL";
         else if(strongBuy)   g_liveSignalName = "STRONG BUY";
         else if(reversalSell)g_liveSignalName = reversalSellName;
         else if(reversalBuy) g_liveSignalName = reversalBuyName;
         else if(bearMomentum)g_liveSignalName = "MOM SELL";
         else if(bullMomentum)g_liveSignalName = "MOM BUY";
         else                 g_liveSignalName = "No Signal";
         UpdateCurrentSignalLabel();
        }

      // === Signal event logging (on tradeable bars only) ===
      if(CanTradeSignalBar(i, firstRun))
        {
         if(trendBuy && IsBuyDirectionAllowed() && lastTrendBuyTradeTime != t)
           {
            AppendSignalLog("SIGNAL", "TREND BUY", prevSignal, "TREND BUY", Close[i]);
            prevSignal = "TREND BUY";
            lastTrendBuyTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert("TREND BUY - " + Symbol()); lastAlertTime = t; }
           }
         else if(reversalBuy && IsBuyDirectionAllowed() && lastRevBuyTradeTime != t)
           {
            AppendSignalLog("SIGNAL", reversalBuyName, prevSignal, reversalBuyName, Close[i]);
            prevSignal = reversalBuyName;
            lastRevBuyTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert(reversalBuyName + " - " + Symbol()); lastAlertTime = t; }
           }
         else if(strongBuy && IsBuyDirectionAllowed() && lastStrongBuyTradeTime != t)
           {
            AppendSignalLog("SIGNAL", "STRONG BUY", prevSignal, "STRONG BUY", Close[i]);
            prevSignal = "STRONG BUY";
            lastStrongBuyTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert("STRONG BUY - " + Symbol()); lastAlertTime = t; }
           }
         else if(trendSell && IsSellDirectionAllowed() && lastTrendSellTradeTime != t)
           {
            AppendSignalLog("SIGNAL", "TREND SELL", prevSignal, "TREND SELL", Close[i]);
            prevSignal = "TREND SELL";
            lastTrendSellTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert("TREND SELL - " + Symbol()); lastAlertTime = t; }
           }
         else if(reversalSell && IsSellDirectionAllowed() && lastRevSellTradeTime != t)
           {
            AppendSignalLog("SIGNAL", reversalSellName, prevSignal, reversalSellName, Close[i]);
            prevSignal = reversalSellName;
            lastRevSellTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert(reversalSellName + " - " + Symbol()); lastAlertTime = t; }
           }
         else if(strongSell && IsSellDirectionAllowed() && lastStrongSellTradeTime != t)
           {
            AppendSignalLog("SIGNAL", "STRONG SELL", prevSignal, "STRONG SELL", Close[i]);
            prevSignal = "STRONG SELL";
            lastStrongSellTradeTime = t;
            if(i == 1 && lastAlertTime != t)
              { SendSignalAlert("STRONG SELL - " + Symbol()); lastAlertTime = t; }
           }
        }
     }

   if(hasNewClosedBar || firstRun)
      lastProcessedClosedBar = Time[1];

   MaybeRefreshDashboard();
  }
