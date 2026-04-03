//+------------------------------------------------------------------+
//| EDGE ALGO - SMART PATTERN DETECTION (PRO ELITE)                 |
//| Signals + Markers + No-Sell Zone display only                   |
//+------------------------------------------------------------------+
#property strict

#include "V_TV_LotVariables.mqh"
#include "V_TV_StrategyPatterns.mqh"
#include "V_TV_SeqSellOrders.mqh"
#include "V_TV_SeqBuyOrders.mqh"
#include "V_TV_SeqCloseOrders.mqh"
#include "V_TV_OrderReport.mqh"
#include "V_TV_LearningSuggestions.mqh"
#include "V_TV_MarkerSuggestions.mqh"
#include "V_TV_SimpleOpenCloseOrders.mqh"

 

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
input double TrendSellDailyLowGapPrice  =0; // NO SELL zone: min $ above daily low
input double TrendBuyDailyHighGapPrice  = 0; // NO BUY zone: min $ below daily high
input bool   EnableAlert         = false;
input bool   EnableSound         = true;
input bool   EnableLogMessages   = false;
input string _Spike_             = "--- SPIKE MARKERS ---";
input bool   EnableSpikeMarkers  = true;   // Draw spike arrows on chart
input double SpikeMultiplier     = 2.5;    // Candle range must be X times avg to count as spike
input int    SpikeLookback       = 20;     // Bars used to calculate average candle size
input int    DashboardRefreshSeconds = 30;
input bool   ExecuteEverySignalInTester = false;
input bool   EnablePreSignals           = true;
input int    StartupWaitMinutes         = 1;   // Wait N minutes on first load before placing orders

// ----- GLOBALS ----- //
string   currentSignal      = "";
string   prevSignal         = "";
string   g_liveSignalName      = "";  // current display (sticky, last valid signal)
string   g_prevDisplaySignal  = "";  // previous display (signal before current)
datetime g_lastDisplayBarTime = 0;   // bar time of last curr/prev shift
string   g_csvFileName  = "";

string   g_seqSignalName = "";  // signal type currently being counted
int      g_seqCount      = 0;   // consecutive count for that signal type
datetime g_seqBarTime    = 0;   // bar time of last sequence update (prevents re-increment per tick)

string   g_currSignalLabel    = "TS_LiveSignal";      // chart object name for current signal label
string   g_prevSignalLabel    = "TS_PrevSignal";      // chart object name for previous signal label
string   g_currSeqLabel       = "TS_CurrSeqSignal";   // chart object name for current signal+seq label
string   g_prevSeqLabel       = "TS_PrevSeqSignal";   // chart object name for previous signal+seq label
string   g_prePrevSignalLabel = "TS_PrePrevSignal";   // chart object name for pre-prev signal label
string   g_prePrevSeqLabel    = "TS_PrePrevSeqSignal";// chart object name for pre-prev signal+seq label

int      g_currSeqCount = 0;  // sequence number of the current signal
int      g_prevSeqCount = 0;  // sequence number of the previous signal (at time of shift)

string   g_prePrevSignal       = "";  // signal name 2 steps back
string   g_prePrevSeqSignalText = ""; // signal name + seq number 2 steps back (e.g. "TREND SELL 2")

double   g_prePrevSignalPrice = 0; // bar price when pre-previous signal fired
double   g_prevSignalPrice    = 0; // bar price when previous signal fired
double   g_currSignalPrice    = 0; // bar price when current signal fired

string   g_runTimestamp = ""; // set once in OnInit — used as postfix for all CSV filenames
double CurrentBuyTP  = 0;
double CurrentSellTP = 0;

double DefaultBuyTP  = 0;
double DefaultSellTP = 0;

datetime lastAlertTime            = 0;
datetime lastProcessedClosedBar   = 0;
datetime lastDashboardRefreshTime = 0;
datetime g_startupWaitUntil       = 0;  // orders blocked until this time on first load
double   g_initialBalance         = 0;  // account balance captured at EA startup
bool     g_newSignalDetected      = false; // set true when a new signal fires this tick

datetime lastTrendBuyTradeTime  = 0;
datetime lastRevBuyTradeTime    = 0;
datetime lastStrongBuyTradeTime = 0;
datetime lastTrendSellTradeTime = 0;
datetime lastRevSellTradeTime   = 0;
datetime lastStrongSellTradeTime= 0;

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

color GetSignalColor(string sig)
  {
   if(sig == "TREND SELL")               return clrRed;
   if(sig == "PRE SELL")                 return clrOrange;
   if(sig == "STRONG SELL")              return clrPink;
   if(StringFind(sig, "SHAPE SELL") >= 0)return clrMagenta;
   if(StringFind(sig, "SELL") >= 0)      return clrOrangeRed;
   if(sig == "TREND BUY")                return clrLime;
   if(sig == "PRE BUY")                  return clrAqua;
   if(sig == "STRONG BUY")               return clrDeepSkyBlue;
   if(StringFind(sig, "SHAPE BUY") >= 0) return clrBlue;
   if(StringFind(sig, "BUY") >= 0)       return clrAqua;
   return clrDimGray;
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
// Draw entry quality circle at signal bar                           |
// Blue = EMA conditions good (Cond8+Cond9 pass) = good entry zone  |
// Red  = EMA conditions bad = bad entry zone                        |
//+------------------------------------------------------------------+
void DrawEntryMark(string prefix, datetime t, double price, int period)
  {

   return  ;
   double ema1      = iMA(Symbol(), 0, SeqSellEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2      = iMA(Symbol(), 0, SeqSellEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema1Past  = iMA(Symbol(), 0, SeqSellEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, SeqSellEMAShift);
   bool   cond8     = (ema1 < ema1Past);       // EMA1 sloping down
   bool   cond9     = (ema1 < ema2);           // EMA1 below EMA2

   color  clr  = (cond8 && cond9) ? clrDodgerBlue : clrRed;
   string name = prefix + "_EQ_" + IntegerToString(t);

   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectMove(0, name, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // filled circle
   ObjectSetInteger(0, name, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,     4);
   ObjectSetInteger(0, name, OBJPROP_BACK,      false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
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
                         bool &trendBuy,     bool &reversalBuy,  bool &strongBuy,
                         bool &trendSell,    bool &reversalSell, bool &strongSell)
  {
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

   bool bullMomentum = bullTrend && rsiUp   && strongTrend;
   bool bearMomentum = bearTrend && rsiDown && strongTrend;

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
   ObjectSetText(zoneLabel, " NO TREND SELL ZONE ($" + DoubleToString(TrendSellDailyLowGapPrice,0) +
                 " above daily low)", 8, "Arial Bold", clrOrangeRed);

   // No-Sell Zone background rectangle (light red, drawn behind candles)
   datetime bgStart = (Bars > 2) ? Time[Bars-2] : Time[0];
   datetime bgEnd   = D'2099.12.31 00:00';
   string sellBg = "TS_NoSellZone_Bg";
   if(ObjectFind(0, sellBg) < 0)
      ObjectCreate(0, sellBg, OBJ_RECTANGLE, 0, bgStart, zoneTop, bgEnd, dailyLow);
   ObjectMove(0, sellBg, 0, bgStart, zoneTop);
   ObjectMove(0, sellBg, 1, bgEnd,   dailyLow);
   ObjectSetInteger(0, sellBg, OBJPROP_COLOR,   clrIndianRed);
   ObjectSetInteger(0, sellBg, OBJPROP_FILL,    true);
   ObjectSetInteger(0, sellBg, OBJPROP_BACK,    true);
   ObjectSetInteger(0, sellBg, OBJPROP_WIDTH,   1);
   ObjectSetInteger(0, sellBg, OBJPROP_SELECTED,false);

   // ---- NO BUY ZONE (daily high) ----
   double dailyHigh = iHigh(Symbol(), PERIOD_D1, 0);
   if(dailyHigh <= 0) return;

   double noBuyBottom = dailyHigh - TrendBuyDailyHighGapPrice;

   // Daily High line (blue dashed)
   string highLine = "TB_DailyHigh";
   if(ObjectFind(0, highLine) < 0)
      ObjectCreate(0, highLine, OBJ_HLINE, 0, 0, dailyHigh);
   ObjectMove(0, highLine, 0, 0, dailyHigh);
   ObjectSetInteger(0, highLine, OBJPROP_COLOR, clrDodgerBlue);
   ObjectSetInteger(0, highLine, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, highLine, OBJPROP_WIDTH, 2);
   ObjectSetString(0,  highLine, OBJPROP_TOOLTIP, "Daily High: " + DoubleToString(dailyHigh, Digits));

   string highLabel = "TB_DailyHigh_Lbl";
   if(ObjectFind(0, highLabel) < 0)
      ObjectCreate(0, highLabel, OBJ_TEXT, 0, Time[5], dailyHigh);
   ObjectMove(0, highLabel, 0, Time[5], dailyHigh);
   ObjectSetText(highLabel, " Daily High: " + DoubleToString(dailyHigh, Digits), 8, "Arial Bold", clrDodgerBlue);

   // No-Buy Zone boundary (cyan dotted)
   string noBuyLine = "TB_NoBuyZone";
   if(ObjectFind(0, noBuyLine) < 0)
      ObjectCreate(0, noBuyLine, OBJ_HLINE, 0, 0, noBuyBottom);
   ObjectMove(0, noBuyLine, 0, 0, noBuyBottom);
   ObjectSetInteger(0, noBuyLine, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, noBuyLine, OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, noBuyLine, OBJPROP_WIDTH, 1);
   ObjectSetString(0,  noBuyLine, OBJPROP_TOOLTIP,
                   "NO TREND BUY ZONE: $" + DoubleToString(TrendBuyDailyHighGapPrice,2) + " below Daily High");

   string noBuyLabel = "TB_NoBuyZone_Lbl";
   if(ObjectFind(0, noBuyLabel) < 0)
      ObjectCreate(0, noBuyLabel, OBJ_TEXT, 0, Time[5], noBuyBottom);
   ObjectMove(0, noBuyLabel, 0, Time[5], noBuyBottom);
   ObjectSetText(noBuyLabel, " NO TREND BUY ZONE ($" + DoubleToString(TrendBuyDailyHighGapPrice,0) +
                 " below daily high)", 8, "Arial Bold", clrAqua);

   // No-Buy Zone background rectangle (light red, drawn behind candles)
   datetime bgStart2 = (Bars > 2) ? Time[Bars-2] : Time[0];
   datetime bgEnd2   = D'2099.12.31 00:00';
   string buyBg = "TB_NoBuyZone_Bg";
   if(ObjectFind(0, buyBg) < 0)
      ObjectCreate(0, buyBg, OBJ_RECTANGLE, 0, bgStart2, dailyHigh, bgEnd2, noBuyBottom);
   ObjectMove(0, buyBg, 0, bgStart2, dailyHigh);
   ObjectMove(0, buyBg, 1, bgEnd2,   noBuyBottom);
   ObjectSetInteger(0, buyBg, OBJPROP_COLOR,   clrIndianRed);
   ObjectSetInteger(0, buyBg, OBJPROP_FILL,    true);
   ObjectSetInteger(0, buyBg, OBJPROP_BACK,    true);
   ObjectSetInteger(0, buyBg, OBJPROP_WIDTH,   1);
   ObjectSetInteger(0, buyBg, OBJPROP_SELECTED,false);
  }
void dipslayCurrentTime()
{
  
string name = "TimeLabel";

   datetime serverTime = TimeCurrent();
   datetime dubaiTime  = TimeLocal();

   string text = "Server: " + TimeToString(serverTime, TIME_SECONDS) +
                 " | Dubai: " + TimeToString(dubaiTime, TIME_SECONDS);

   // ✅ Create only once
   if(ObjectFind(0, name) == -1)
   {

      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = chartWidth / 2 - 150;
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 50);

      ObjectSetInteger(0, name, OBJPROP_COLOR, clrYellow);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 12);
   }

   // ✅ Only update text (NO overlap)
   ObjectSetString(0, name, OBJPROP_TEXT, text);
 
}
//+------------------------------------------------------------------+
// Current live signal label (top-right, updates every tick)
//+------------------------------------------------------------------+
void UpdateCurrentSignalLabel()
  {
   // --- Current Signal ---
   string lbl = g_currSignalLabel;
   string sig = (g_liveSignalName == "") ? "---" : g_liveSignalName;
   color  clr = GetSignalColor(sig);






 // --- Curr + Sequence ---
   string currSeqText = (g_liveSignalName == "") ? "---" :
                        g_liveSignalName + " " + IntegerToString(g_currSeqCount);
   color  clrCS = GetSignalColor(g_liveSignalName);
   if(ObjectFind(0, g_currSeqLabel) < 0)
      ObjectCreate(0, g_currSeqLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_YDISTANCE, 20);
   ObjectSetString(0,  g_currSeqLabel, OBJPROP_TEXT,      "Seq.Curr : " + currSeqText);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_COLOR,     clrCS);
   ObjectSetInteger(0, g_currSeqLabel, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  g_currSeqLabel, OBJPROP_FONT,      "Arial Bold");










   if(ObjectFind(0, lbl) < 0)
      ObjectCreate(0, lbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lbl, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, lbl, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, lbl, OBJPROP_YDISTANCE, 68);
   ObjectSetString(0,  lbl, OBJPROP_TEXT,      "Curr     : " + sig);
   ObjectSetInteger(0, lbl, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  lbl, OBJPROP_FONT,      "Arial Bold");

   // --- Previous Signal ---
   string lblPrev = g_prevSignalLabel;
   string prev    = (g_prevDisplaySignal == "") ? "---" : g_prevDisplaySignal;
   color  clrPrev = GetSignalColor(prev);

   if(ObjectFind(0, lblPrev) < 0)
      ObjectCreate(0, lblPrev, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, lblPrev, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, lblPrev, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, lblPrev, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, lblPrev, OBJPROP_YDISTANCE, 44);
   ObjectSetString(0,  lblPrev, OBJPROP_TEXT,      "Prev     : " + prev);
   ObjectSetInteger(0, lblPrev, OBJPROP_COLOR,     clrPrev);
   ObjectSetInteger(0, lblPrev, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  lblPrev, OBJPROP_FONT,      "Arial Bold");

  

   // --- Prev + Sequence ---
   string prevSeqText = (g_prevDisplaySignal == "") ? "---" :
                        g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount);
   color  clrPS = GetSignalColor(g_prevDisplaySignal);
   if(ObjectFind(0, g_prevSeqLabel) < 0)
      ObjectCreate(0, g_prevSeqLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_YDISTANCE, 92);
   ObjectSetString(0,  g_prevSeqLabel, OBJPROP_TEXT,      "Seq.Prev : " + prevSeqText);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_COLOR,     clrPS);
   ObjectSetInteger(0, g_prevSeqLabel, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  g_prevSeqLabel, OBJPROP_FONT,      "Arial Bold");

   // --- Pre-Previous signal name ---
   string prePrev    = (g_prePrevSignal == "") ? "---" : g_prePrevSignal;
   color  clrPP      = GetSignalColor(g_prePrevSignal);
   if(ObjectFind(0, g_prePrevSignalLabel) < 0)
      ObjectCreate(0, g_prePrevSignalLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_YDISTANCE, 116);
   ObjectSetString(0,  g_prePrevSignalLabel, OBJPROP_TEXT,      "Pre.Prev : " + prePrev);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_COLOR,     clrPP);
   ObjectSetInteger(0, g_prePrevSignalLabel, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  g_prePrevSignalLabel, OBJPROP_FONT,      "Arial Bold");

   // --- Pre-Previous signal + sequence text ---
   string prePrevSeq = (g_prePrevSeqSignalText == "") ? "---" : g_prePrevSeqSignalText;
   if(ObjectFind(0, g_prePrevSeqLabel) < 0)
      ObjectCreate(0, g_prePrevSeqLabel, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_YDISTANCE, 140);
   ObjectSetString(0,  g_prePrevSeqLabel, OBJPROP_TEXT,      "Seq.Pre  : " + prePrevSeq);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_COLOR,     clrPP);
   ObjectSetInteger(0, g_prePrevSeqLabel, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  g_prePrevSeqLabel, OBJPROP_FONT,      "Arial Bold");

   // --- Startup warm-up status ---
   string warmupLbl = "TS_WarmupStatus";
   datetime now = TimeCurrent();
   string warmupText;
   color  warmupClr;
   if(now < g_startupWaitUntil)
     {
      int secsLeft = (int)(g_startupWaitUntil - now);
      int minsLeft = secsLeft / 60;
      int sLeft    = secsLeft % 60;
      warmupText = "Warmup  : " + IntegerToString(minsLeft) + "m " +
                   IntegerToString(sLeft) + "s (no orders)";
      warmupClr  = clrYellow;
     }
   else
     {
      warmupText = "Warmup  : READY - Orders active";
      warmupClr  = clrLime;
     }
   if(ObjectFind(0, warmupLbl) < 0)
      ObjectCreate(0, warmupLbl, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, warmupLbl, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, warmupLbl, OBJPROP_ANCHOR,    ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, warmupLbl, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, warmupLbl, OBJPROP_YDISTANCE, 164);
   ObjectSetString(0,  warmupLbl, OBJPROP_TEXT,      warmupText);
   ObjectSetInteger(0, warmupLbl, OBJPROP_COLOR,     warmupClr);
   ObjectSetInteger(0, warmupLbl, OBJPROP_FONTSIZE,  12);
   ObjectSetString(0,  warmupLbl, OBJPROP_FONT,      "Arial Bold");
  }

//+------------------------------------------------------------------+
// CSV signal logger
//+------------------------------------------------------------------+
void InitCSVLog()
  {
   g_csvFileName = "SignalLog_" + g_runTimestamp + "_" + Symbol() + ".csv";
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
// Dashboard background: white card with shadow effect              |
//+------------------------------------------------------------------+
void DrawDashBG(int totalHeight)
  {
   // Shadow layer (dark, slightly offset)
   string sid = "DB_Shadow";
   if(ObjectFind(0, sid) < 0) ObjectCreate(0, sid, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, sid, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, sid, OBJPROP_XDISTANCE,   3);
   ObjectSetInteger(0, sid, OBJPROP_YDISTANCE,   3);
   ObjectSetInteger(0, sid, OBJPROP_XSIZE,       210);
   ObjectSetInteger(0, sid, OBJPROP_YSIZE,       totalHeight);
   ObjectSetInteger(0, sid, OBJPROP_BGCOLOR,     C'190,190,190');
   ObjectSetInteger(0, sid, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, sid, OBJPROP_COLOR,       C'190,190,190');
   ObjectSetInteger(0, sid, OBJPROP_BACK,        true);
   ObjectSetInteger(0, sid, OBJPROP_SELECTABLE,  false);

   // Main white card
   string bid = "DB_BG";
   if(ObjectFind(0, bid) < 0) ObjectCreate(0, bid, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bid, OBJPROP_CORNER,      CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bid, OBJPROP_XDISTANCE,   0);
   ObjectSetInteger(0, bid, OBJPROP_YDISTANCE,   0);
   ObjectSetInteger(0, bid, OBJPROP_XSIZE,       210);
   ObjectSetInteger(0, bid, OBJPROP_YSIZE,       totalHeight);
   ObjectSetInteger(0, bid, OBJPROP_BGCOLOR,     clrWhite);
   ObjectSetInteger(0, bid, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bid, OBJPROP_COLOR,       C'210,210,210');
   ObjectSetInteger(0, bid, OBJPROP_BACK,        true);
   ObjectSetInteger(0, bid, OBJPROP_SELECTABLE,  false);
  }

//+------------------------------------------------------------------+
// Dashboard helper: create/update one left-side label row          |
//+------------------------------------------------------------------+
void DashRow(string id, string text, color clr, int y)
  {
   if(ObjectFind(0, id) < 0) ObjectCreate(0, id, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, id, OBJPROP_CORNER,    CORNER_LEFT_UPPER);
   ObjectSetInteger(0, id, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, id, OBJPROP_YDISTANCE, y);
   ObjectSetString(0,  id, OBJPROP_TEXT,      text);
   ObjectSetInteger(0, id, OBJPROP_COLOR,     clr);
   ObjectSetInteger(0, id, OBJPROP_FONTSIZE,  9);
   ObjectSetString(0,  id, OBJPROP_FONT,      "Arial Bold");
   ObjectSetInteger(0, id, OBJPROP_BACK,      false);
  }

//+------------------------------------------------------------------+
// Draw EMA line as connected segments across last N bars            |
//+------------------------------------------------------------------+
void DrawEMALine(int period, color clr, string prefix, int barsBack = 300)
  {
   int limit = MathMin(barsBack, Bars - 1);
   for(int i = limit; i >= 1; i--)
     {
      double e1 = iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, i);
      double e0 = iMA(NULL, 0, period, 0, MODE_EMA, PRICE_CLOSE, i - 1);
      if(e1 <= 0 || e0 <= 0) continue;

      string name = prefix + "_" + IntegerToString(i);
      if(ObjectFind(0, name) == -1)
         ObjectCreate(0, name, OBJ_TREND, 0, Time[i], e1, Time[i-1], e0);
      else
        {
         ObjectMove(0, name, 0, Time[i],   e1);
         ObjectMove(0, name, 1, Time[i-1], e0);
        }
      ObjectSetInteger(0, name, OBJPROP_COLOR,   clr);
      ObjectSetInteger(0, name, OBJPROP_WIDTH,   1);
      ObjectSetInteger(0, name, OBJPROP_RAY,     false);
      ObjectSetInteger(0, name, OBJPROP_BACK,    true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
     }
  }

//+------------------------------------------------------------------+
// Spike marker: arrow above spike-up candles, below spike-down      |
// Spike UP  (wick up)   → RED   down arrow above High               |
// Spike DOWN (wick down) → BLUE  up arrow below Low                 |
//+------------------------------------------------------------------+
void DrawSpikeMarkers(int barsBack = 300)
  {
   if(!EnableSpikeMarkers) return;
   int limit = MathMin(barsBack, Bars - SpikeLookback - 2);

   for(int i = limit; i >= 1; i--)
     {
      // Average candle range over SpikeLookback bars before this candle
      double avgRange = 0;
      for(int k = i + 1; k <= i + SpikeLookback; k++)
         avgRange += (High[k] - Low[k]);
      avgRange /= SpikeLookback;
      if(avgRange <= 0) continue;

      double candleRange = High[i] - Low[i];
      if(candleRange < avgRange * SpikeMultiplier) continue; // not a spike

      double body      = MathAbs(Open[i] - Close[i]);
      double upperWick = High[i]  - MathMax(Open[i], Close[i]);
      double lowerWick = MathMin(Open[i], Close[i]) - Low[i];

      bool spikeUp   = (upperWick > body * 1.5); // long upper wick → spike shot UP
      bool spikeDown = (lowerWick > body * 1.5); // long lower wick → spike shot DOWN

      // Full-body spike: no clear wick dominance → use candle direction
      if(!spikeUp && !spikeDown)
        {
         if(Close[i] > Open[i]) spikeDown = true; // bullish full spike = shot down then recovered
         else                   spikeUp   = true;  // bearish full spike = shot up then sold off
        }

      if(spikeUp)
        {
         string name = "SPIKE_UP_" + IntegerToString(i);
         if(ObjectFind(0, name) == -1)
           {
            ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], High[i] + 3 * Point);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 242);   // down arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR,     clrRed);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
            ObjectSetInteger(0, name, OBJPROP_BACK,      false);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
            // Tooltip shows spike size
            string tip = "SPIKE UP | Range=" + DoubleToString(candleRange/Point,0) +
                         "pts (" + DoubleToString(candleRange/avgRange,1) + "x avg)" +
                         " | Wick=" + DoubleToString(upperWick/Point,0) + "pts";
            ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
           }
        }

      if(spikeDown)
        {
         string name = "SPIKE_DN_" + IntegerToString(i);
         if(ObjectFind(0, name) == -1)
           {
            ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], Low[i] - 3 * Point);
            ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 241);   // up arrow
            ObjectSetInteger(0, name, OBJPROP_COLOR,     clrDodgerBlue);
            ObjectSetInteger(0, name, OBJPROP_WIDTH,     2);
            ObjectSetInteger(0, name, OBJPROP_BACK,      false);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE,false);
            string tip = "SPIKE DOWN | Range=" + DoubleToString(candleRange/Point,0) +
                         "pts (" + DoubleToString(candleRange/avgRange,1) + "x avg)" +
                         " | Wick=" + DoubleToString(lowerWick/Point,0) + "pts";
            ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
           }
        }
     }
  }

//+------------------------------------------------------------------+
// Main dashboard draw: call every tick
//+------------------------------------------------------------------+
void DrawDashboard()
  {
   double balance     = AccountBalance();
   double equity      = AccountEquity();
   double margin      = AccountMargin();
   double freeMargin  = AccountFreeMargin();
   double marginLevel = (margin > 0) ? (equity / margin * 100.0) : 0;
   double pl          = equity - balance;
   double initPL      = equity - g_initialBalance;
   int    spread      = (int)MarketInfo(Symbol(), MODE_SPREAD);
   double tickSize    = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue   = MarketInfo(Symbol(), MODE_TICKVALUE);
   double spreadUSD   = (tickSize > 0) ? (spread * Point / tickSize) * tickValue * SeqSellLotSize : 0;

   // Count open orders and sum profit
   int    openBuy = 0, openSell = 0;
   double openProfit = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderType() == OP_BUY)  openBuy++;
      if(OrderType() == OP_SELL) openSell++;
      openProfit += OrderProfit() + OrderSwap() + OrderCommission();
     }

   // --- Color palette for white background ---
   // Status-driven colors
   color plClr      = (pl >= 0)         ? C'27,94,32'   : C'183,28,28';   // dark green / dark red
   color initPlClr  = (initPL >= 0)     ? C'27,94,32'   : C'183,28,28';
   color profitClr  = (openProfit >= 0) ? C'27,94,32'   : C'198,40,40';
   color marginClr  = (marginLevel > 200) ? C'27,94,32' :
                      (marginLevel > 100) ? C'230,81,0'  : C'183,28,28';  // green/orange/red
   color spreadClr  = (spread <= MaxSpreadPoints)       ? C'97,97,97'  : C'198,40,40';

   // Fixed palette
   color cTitle     = C'26,35,126';    // deep indigo
   color cSymbol    = C'21,101,192';   // material blue
   color cTime      = C'97,97,97';     // medium gray
   color cHdr       = C'38,50,56';     // blue-gray dark  (section headers)
   color cValue     = C'33,33,33';     // near-black (normal values)
   color cSubtle    = C'117,117,117';  // gray (secondary values)
   color cSell      = C'183,28,28';    // dark red  (SELL)
   color cBuy       = C'27,94,32';     // dark green (BUY)
   color cTP        = C'27,94,32';     // forest green
   color cSL        = C'183,28,28';    // crimson
   color cLot       = C'74,20,140';    // deep purple

   int y = 10; int step = 17;

   // Background card (calculated height: ~31 rows × step + padding)
   DrawDashBG(31 * step + 55);

   // Title block
   DashRow("DB_Title",    "  EDGE ALGO  v2.0",               cTitle,    y); y += step+3;
   DashRow("DB_Symbol",   "  " + Symbol() + "   " +
                          EnumToString((ENUM_TIMEFRAMES)Period()), cSymbol, y); y += step;
   DashRow("DB_Time",     "  " + TimeToString(TimeCurrent(),
                          TIME_DATE|TIME_MINUTES),            cTime,     y); y += step+6;

   // Account
   DashRow("DB_Hdr1",     " ACCOUNT",                        cHdr,      y); y += step;
   DashRow("DB_InitBal",  "  Init Bal  : $" +
                          DoubleToString(g_initialBalance,2), cSubtle,   y); y += step;
   DashRow("DB_Bal",      "  Balance   : $" +
                          DoubleToString(balance,2),          cValue,    y); y += step;
   DashRow("DB_Equity",   "  Equity    : $" +
                          DoubleToString(equity,2),           cValue,    y); y += step;
   DashRow("DB_PL",       "  P / L     : $" +
                          DoubleToString(pl,2),               plClr,     y); y += step;
   DashRow("DB_InitPL",   "  Since Load: $" +
                          DoubleToString(initPL,2),           initPlClr, y); y += step+6;

   // Margin
   DashRow("DB_Hdr2",     " MARGIN",                         cHdr,      y); y += step;
   DashRow("DB_Margin",   "  Used      : $" +
                          DoubleToString(margin,2),           cSubtle,   y); y += step;
   DashRow("DB_FreeMgn",  "  Free      : $" +
                          DoubleToString(freeMargin,2),       cSubtle,   y); y += step;
   DashRow("DB_MgnLvl",   "  Level     : " +
                          DoubleToString(marginLevel,1) + "%",marginClr, y); y += step+6;

   // Orders
   DashRow("DB_Hdr3",     " OPEN ORDERS",                    cHdr,      y); y += step;
   DashRow("DB_BuyOrds",  "  BUY       : " +
                          IntegerToString(openBuy),           (openBuy  > 0 ? cBuy  : cSubtle), y); y += step;
   DashRow("DB_SellOrds", "  SELL      : " +
                          IntegerToString(openSell),          (openSell > 0 ? cSell : cSubtle), y); y += step;
   DashRow("DB_OProfit",  "  Float P/L : $" +
                          DoubleToString(openProfit,2),       profitClr, y); y += step+6;

   // Risk Settings
   DashRow("DB_Hdr5",     " RISK SETTINGS",                  cHdr,      y); y += step;
   DashRow("DB_SellLot",  "  SELL Lot  : " +
                          DoubleToString(SeqSellLotSize,2),   cLot,      y); y += step;
   DashRow("DB_SellTP",   "  SELL TP   : $" +
                          DoubleToString(SeqSellProfitTarget,2), cTP,    y); y += step;
   DashRow("DB_SellSL",   "  SELL SL   : $" +
                          DoubleToString(SeqSellStopLossUSD,2),  cSL,    y); y += step;
   DashRow("DB_BuyLot",   "  BUY  Lot  : " +
                          DoubleToString(SeqBuyLotSize,2),    cLot,      y); y += step;
   DashRow("DB_BuyTP",    "  BUY  TP   : $" +
                          DoubleToString(SeqBuyProfitTarget,2),  cTP,    y); y += step;
   DashRow("DB_BuySL",    "  BUY  SL   : $" +
                          DoubleToString(SeqBuyStopLossUSD,2),   cSL,    y); y += step+6;

   // Market
   DashRow("DB_Hdr4",     " MARKET",                         cHdr,      y); y += step;
   DashRow("DB_Bid",      "  Bid       : " +
                          DoubleToString(MarketInfo(Symbol(),MODE_BID),Digits), cValue,  y); y += step;
   DashRow("DB_Ask",      "  Ask       : " +
                          DoubleToString(MarketInfo(Symbol(),MODE_ASK),Digits), cValue,  y); y += step;
   DashRow("DB_Spread",   "  Spread    : " +
                          IntegerToString(spread) + " pts  $" +
                          DoubleToString(spreadUSD,2),        spreadClr, y);
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

    DefaultBuyTP  = SeqBuyProfitTarget;
DefaultSellTP = SeqSellProfitTarget;

CurrentBuyTP  = DefaultBuyTP;
CurrentSellTP = DefaultSellTP;
   // Force chart to M1 if not already
   if(Period() != PERIOD_M1)
     {
      Print("EDGE ALGO: Chart is not M1 (current=" + IntegerToString(Period()) + "). Switching to M1.");
      ChartSetSymbolPeriod(0, Symbol(), PERIOD_M1);
     }

   // Build run timestamp once — YYYYMMDD_HHMMSS — shared by all CSV files
   datetime now = TimeCurrent();
   string d = TimeToString(now, TIME_DATE);   // "YYYY.MM.DD"
   string t = TimeToString(now, TIME_SECONDS);// "HH:MM:SS"
   StringReplace(d, ".", "");
   StringReplace(t, ":", "");
   g_runTimestamp = d + "_" + t;             // e.g. "20260401_143022"

   InitLotDependentVars();

   lastTrendBuyTradeTime = lastRevBuyTradeTime = lastStrongBuyTradeTime = 0;
   lastTrendSellTradeTime = lastRevSellTradeTime = lastStrongSellTradeTime = 0;
   lastProcessedClosedBar = (Bars > 1) ? Time[1] : 0;

   g_initialBalance   = AccountBalance();
   g_startupWaitUntil = TimeCurrent() + StartupWaitMinutes * 60;
   Print("EDGE ALGO: Startup warm-up active. Orders blocked until ",
         TimeToString(g_startupWaitUntil, TIME_DATE|TIME_SECONDS));
   InitStrategyRules();
   InitCSVLog();
   InitOrderReport();
   InitLearningSuggestions();
   InitMarkerSuggestions();
   RefreshBlockedBuyMarkersVisibility();   // apply ShowBlockedBuyMarkers toggle on (re)load
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
   ObjectDelete(0, "TB_DailyHigh");
   ObjectDelete(0, "TB_DailyHigh_Lbl");
   ObjectDelete(0, "TB_NoBuyZone");
   ObjectDelete(0, "TB_NoBuyZone_Lbl");
   ObjectDelete(0, "TS_NoSellZone_Bg");
   ObjectDelete(0, "TB_NoBuyZone_Bg");
   ObjectDelete(0, g_currSignalLabel);
   ObjectDelete(0, g_prevSignalLabel);
   ObjectDelete(0, g_currSeqLabel);
   ObjectDelete(0, g_prevSeqLabel);
   ObjectDelete(0, g_prePrevSignalLabel);
   ObjectDelete(0, g_prePrevSeqLabel);
   ObjectDelete(0, "TS_WarmupStatus");
   Comment("");
  }
bool IsTradingTime()
{
  //  int hour = TimeHour(TimeCurrent());  // server time

  //  if(hour >= 0 && hour < 13)
  //     return true;

  //  return false;


     int hour = TimeHour(TimeLocal());
    if(hour >= 18 && hour < 24)
        return true;  
        else return false;
}
//+------------------------------------------------------------------+
void OnTick()
  {

    //  if(!IsTradingTime())
    //   return;
  ////////// verfyEMAInsideLogic();
   // --- Close orders that reached profit target (checked every tick) ---


   GetEMACrossDirection();

   double balance     = AccountBalance();
   double equity      = AccountEquity();
   if(equity  == balance && balance>20 && OrdersTotal() > 0) // no open trades but balance is healthy (e.g. after TP hit) - close any lingering orders just in case
     {
       CloseAllBuyOrders();
       CloseAllSellOrders();

       Print("No open trades but balance is healthy. Closed any lingering orders just in case. Equity="+DoubleToString(equity,2)+" Balance="+DoubleToString(balance,2 ));

       return;
     }
   
   CheckClosedOrders();
//CheckForNewClosedBarAndProcessSignals();


  //  if(Bars < 5) return;

   bool firstRun      = (lastProcessedClosedBar == 0);
   bool hasNewClosedBar = (Time[1] != lastProcessedClosedBar);

   int maxStartBar = Bars - 3;
   int startBar;
   if(firstRun)          startBar = MathMin(maxStartBar, 300);
   else if(hasNewClosedBar) startBar = 1;
   else                  startBar = 0;

   for(int i = startBar; i >= 0; i--)
     {
      bool preTrendSell = false, preTrendBuy = false;
      if(EnablePreSignals)
        {
         preTrendSell = DetectPreTrendSell(i);
         preTrendBuy  = DetectPreTrendBuy(i);
        }
      bool trendBuy = false, reversalBuy = false, strongBuy = false;
      bool trendSell = false, reversalSell = false, strongSell = false;

      EvaluateSignalFlags(i, trendBuy, reversalBuy, strongBuy,
                             trendSell, reversalSell, strongSell);

      datetime t = Time[i];
      string reversalBuyName  = GetReversalSignalName(i, OP_BUY);
      string reversalSellName = GetReversalSignalName(i, OP_SELL);

      // === Sequence counter: increment if same signal, reset if different ===
      string detectedSig = "";
      if(trendSell)        detectedSig = "TREND SELL";
      else if(preTrendSell)detectedSig = "PRE SELL";
      else if(trendBuy)    detectedSig = "TREND BUY";
      else if(preTrendBuy) detectedSig = "PRE BUY";
      else if(strongSell)  detectedSig = "STRONG SELL";
      else if(strongBuy)   detectedSig = "STRONG BUY";
      else if(reversalSell)detectedSig = reversalSellName;
      else if(reversalBuy) detectedSig = reversalBuyName;

      if(detectedSig != "" && t != g_seqBarTime)
        {
         if(detectedSig == g_seqSignalName) g_seqCount++;
         else { g_seqCount = 1; g_seqSignalName = detectedSig; }
         g_seqBarTime = t;
        }
      string seqLabel = detectedSig + (detectedSig != "" ? IntegerToString(g_seqCount) : "");

      // === Buy signals ===
      // 🔥 PRE BUY
if(preTrendBuy)
  {
   string _lbl = "PRE BUY " + IntegerToString(g_seqCount);
   DrawMarker("PTB", _lbl, clrAqua, 233, t, Low[i] - 15*Point);
   RecordSignalPrice(_lbl, Low[i]);
   LearnRecordSignal(_lbl, g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount), g_prePrevSeqSignalText, Low[i], false);
   RecordMarkerObs("PRE BUY", g_seqCount, Low[i], false);
  }

// 🟢 TREND BUY
if(trendBuy)
  {
   string _lbl = "TREND BUY " + IntegerToString(g_seqCount);
   DrawMarker("TB", _lbl, clrLime, 233, t, Low[i] - 10*Point);
   RecordSignalPrice(_lbl, Low[i]);
   LearnRecordSignal(_lbl, g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount), g_prePrevSeqSignalText, Low[i], false);
   RecordMarkerObs("TREND BUY", g_seqCount, Low[i], false);
  }

// 🔵 REVERSAL BUY
if(reversalBuy)
  {
   string _lbl = reversalBuyName + " " + IntegerToString(g_seqCount);
   DrawMarker("RB", _lbl, clrBlue, 233, t, Low[i] - 10*Point);
   RecordSignalPrice(_lbl, Low[i]);
   RecordMarkerObs(reversalBuyName, g_seqCount, Low[i], false);
  }

// 💙 STRONG BUY
if(strongBuy)
  {
   string _lbl = "STRONG BUY " + IntegerToString(g_seqCount);
   DrawMarker("SB", _lbl, clrDeepSkyBlue, 233, t, Low[i] - 10*Point);
   RecordSignalPrice(_lbl, Low[i]);
   RecordMarkerObs("STRONG BUY", g_seqCount, Low[i], false);
  }

      // === Sell signals ===

// 🔥 PRE SELL
if(preTrendSell)
  {
   string _lbl = "PRE SELL " + IntegerToString(g_seqCount);
   DrawMarker("PTS", _lbl, clrOrange, 234, t, High[i] + 15*Point);
   RecordSignalPrice(_lbl, High[i]);
   LearnRecordSignal(_lbl, g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount), g_prePrevSeqSignalText, High[i], true);
   RecordMarkerObs("PRE SELL", g_seqCount, High[i], true);
  }

// 🔴 TREND SELL
if(trendSell)
  {
   string _lbl = "TREND SELL " + IntegerToString(g_seqCount);
   // Build g_trendSellSeq for chart diff display
   int idx = g_seqCount - 1;
   if(g_seqCount == 1) ArrayResize(g_trendSellSeq, 0);
   if(ArraySize(g_trendSellSeq) <= idx) ArrayResize(g_trendSellSeq, idx + 1);
   g_trendSellSeq[idx].label = _lbl;
   g_trendSellSeq[idx].price = High[i];

   string tsDiffStr = "";
   if(g_seqCount > 1)
     {
      double diff = High[i] - g_trendSellSeq[idx - 1].price;
      tsDiffStr = " (" + (diff >= 0 ? "+" : "") + DoubleToString(diff, 0) + ")";
     }
   DrawMarker("TS", _lbl + tsDiffStr, clrRed, 234, t, High[i] + 10*Point);
   DrawEntryMark("TS", t, High[i] + 25*Point, SeqSellEMAPeriod);
   RecordSignalPrice(_lbl, High[i]);
   LearnRecordSignal(_lbl, g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount), g_prePrevSeqSignalText, High[i], true);
   RecordMarkerObs("TREND SELL", g_seqCount, High[i], true);
  }

// 🟣 REVERSAL SELL
if(reversalSell)
  {
   string _lbl = reversalSellName + " " + IntegerToString(g_seqCount);
   DrawMarker("RS", _lbl, clrMagenta, 234, t, High[i] + 10*Point);
   RecordSignalPrice(_lbl, High[i]);
   RecordMarkerObs(reversalSellName, g_seqCount, High[i], true);
  }

// 🌸 STRONG SELL
if(strongSell)
  {
   string _lbl = "STRONG SELL " + IntegerToString(g_seqCount);
   DrawMarker("SS", _lbl, clrPink, 234, t, High[i] + 10*Point);
   RecordSignalPrice(_lbl, High[i]);
   LearnRecordSignal(_lbl, g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount), g_prePrevSeqSignalText, High[i], true);
   RecordMarkerObs("STRONG SELL", g_seqCount, High[i], true);
  }
      // === Update Curr/Prev display labels (i=0 live bar, i=1 just-closed bar) ===
      if(i == 0 || i == 1)
        {
         string newSig = "";
        if(trendSell)             newSig = "TREND SELL";
else if(preTrendSell)     newSig = "PRE SELL";
         else if(trendBuy)    newSig = "TREND BUY";
         else if(preTrendBuy)     newSig = "PRE BUY";
         else if(strongSell)  newSig = "STRONG SELL";
         else if(strongBuy)   newSig = "STRONG BUY";
         else if(reversalSell)newSig = reversalSellName;
         else if(reversalBuy) newSig = reversalBuyName;

         // Shift prev←curr whenever a valid signal appears on a new bar
         // (bar-time guard prevents re-shifting on every tick for the same bar)
         if(newSig != "" && Time[i] != g_lastDisplayBarTime)
           {
            // shift: pre-prev ← prev ← curr ← new
            g_prePrevSignal        = g_prevDisplaySignal;
            g_prePrevSeqSignalText = g_prevDisplaySignal == "" ? "" :
                                     g_prevDisplaySignal + " " + IntegerToString(g_prevSeqCount);
            g_prePrevSignalPrice   = g_prevSignalPrice;   // shift: prePrev ← prev ← curr
            g_prevDisplaySignal    = g_liveSignalName;
            g_prevSeqCount         = g_currSeqCount;
            g_prevSignalPrice      = g_currSignalPrice;
            g_liveSignalName       = newSig;
            g_currSeqCount         = g_seqCount;
            bool _isSellSig        = (StringFind(newSig, "SELL") >= 0);
            g_currSignalPrice      = _isSellSig ? High[i] : Low[i];
            g_lastDisplayBarTime   = Time[i];
            g_newSignalDetected    = true;  // trigger order check this tick
           }

         if(i == 0) UpdateCurrentSignalLabel();
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

   // --- Sequence-based order execution ---
   // --- Order logic: only when a new signal was detected this tick ---
   if(g_newSignalDetected)
     {
       ProcessSeqSellOrders();
       ProcessSeqBuyOrders();
       ProcessSimplyBuyandCloseOrders();
      g_newSignalDetected = false;

        

   ProcessSeqCloseOrders();
      
     }


   LearnUpdateObservations();
   UpdateMarkerObs();

   DrawEMALine(SeqSellEMAPeriod,  clrDodgerBlue, "EMA_SELL");
   DrawEMALine(SeqSellEMA2Period, clrOrange,     "EMA_SELL2");
   DrawSpikeMarkers();
   DrawDashboard();
   MaybeRefreshDashboard();

   dipslayCurrentTime();
  }


// ===== ADD THIS FUNCTION (below EvaluateSignalFlags) =====
bool DetectPreTrendSell(int i)
{
   if(i < 0 || i + 2 >= Bars) return false;

   double emaFast  = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,i);
   double emaSlow  = iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,i);
   double emaTrend = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,i);

   double rsi      = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,i);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,i+1);

   double body  = MathAbs(Open[i] - Close[i]);
   double range = High[i] - Low[i];

   if(range <= 0) return false;

   bool currBear = Close[i] < Open[i];

   bool rsiDown      = rsi < rsiPrev;
   bool belowFastEMA = Close[i] < emaFast;
   bool weakTrend    = (Close[i] < emaTrend || emaFast < emaSlow);
   bool noBreakout   = Close[i] >= Low[i+1];

   bool exhaustion =
      Close[i+1] > Close[i+2] &&
      Close[i]   < Close[i+1];

   bool decentCandle = body > (range * 0.4);

   return (currBear && rsiDown && belowFastEMA &&
           weakTrend && noBreakout && exhaustion && decentCandle);
}
bool DetectPreTrendBuy(int i)
{
   if(i < 0 || i + 2 >= Bars) return false;

   double emaFast  = iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,i);
   double emaSlow  = iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,i);
   double emaTrend = iMA(NULL,0,TrendEMA,0,MODE_EMA,PRICE_CLOSE,i);

   double rsi      = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,i);
   double rsiPrev  = iRSI(NULL,0,RSI_Period,PRICE_CLOSE,i+1);

   double body  = MathAbs(Open[i] - Close[i]);
   double range = High[i] - Low[i];

   if(range <= 0) return false;

   bool currBull = Close[i] > Open[i];

   // 🔥 Mirror logic of SELL
   bool rsiUp        = rsi > rsiPrev;
   bool aboveFastEMA = Close[i] > emaFast;
   bool strongTrend  = (Close[i] > emaTrend || emaFast > emaSlow);

   // ❗ No breakout yet
   bool noBreakout   = Close[i] <= High[i+1];

   // 🔥 Seller exhaustion
   bool exhaustion =
      Close[i+1] < Close[i+2] &&
      Close[i]   > Close[i+1];

   bool decentCandle = body > (range * 0.4);

   return (currBull && rsiUp && aboveFastEMA &&
           strongTrend && noBreakout && exhaustion && decentCandle);
}