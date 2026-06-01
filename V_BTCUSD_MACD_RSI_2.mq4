//+------------------------------------------------------------------+
//| TradeSmart_MACD_RSI_ADX_Defaults_EA.mq4                          |
//| MT4 EA using visible TradingView defaults                         |
//| MACD 12/26/9 on HLCC4, RSI 14 on HL2 Reverse, ADX 5 limiter       |
//| SMA100 trend filter, Volume > EMA10, separate BUY/SELL basket     |
//+------------------------------------------------------------------+
#property strict

input int      MagicNumber              = 260601;
input double   Lots                     = 0.01;
input int      Slippage                 = 30;
input int      MaxSpreadPoints          = 3000;
input ENUM_TIMEFRAMES SignalTF          = PERIOD_CURRENT;

input double   BuyBasketTakeProfitUSD   = 1.00;
input double   SellBasketTakeProfitUSD  = 1.00;
input double   BuyBasketStopLossUSD     = -20.00;
input double   SellBasketStopLossUSD    = -20.00;

input bool     EnableRecovery           = true;
input int      MaxBuyOrders             = 4;
input int      MaxSellOrders            = 4;
input double   RecoveryGapPrice         = 100;//0.05; // raw price distance. XAGUSD example 0.05, BTCUSD example 100

input bool     TradeOnNewBarOnly        = true;
input bool     EnableBuy                = true;
input bool     EnableSell               = true;
input bool     DebugPrint               = true;
input bool     ShowDashboard            = true;

// TradingView visible defaults
input int      MACDFastEMA              = 12;
input int      MACDSlowEMA              = 26;
input int      MACDSignalEMA            = 9;

input bool     UseLongTrendFilter       = true;
input bool     UseShortTrendFilter      = true;
input int      TrendMAPeriod            = 100;

input bool     UseSimpleRSILimiter      = true;
input bool     RSILimiterReverse        = true;
input int      RSIPeriod                = 14;
input double   RSILongBoundary          = 50.0;
input double   RSIShortBoundary         = 50.0;

input bool     UseADXLimiter            = true;
input int      ADXLength                = 5;
input double   ADXHighBoundary          = 50.0;
input double   ADXLowBoundary           = 20.0;

input bool     UseVolumeFilter          = true;
input int      VolumeMAPeriod           = 10;

input int      ATRLength                = 14;
input double   BaseRiskMultiplier       = 1.5;
input double   RiskRewardRatio          = 2.5;

input bool     UseSessionFilter         = false;
input int      SessionStartHour         = 9;
input int      SessionStartMinute       = 30;
input int      SessionEndHour           = 16;
input int      SessionEndMinute         = 0;

// true = MACD cross only for debugging 0-order problem
input bool     RelaxFiltersForTesting   = false;

datetime g_lastBarTime = 0;

int TF()
{
   if(SignalTF == PERIOD_CURRENT) return(Period());
   return((int)SignalTF);
}

int OnInit()
{
   Print("TradeSmart MACD RSI ADX Defaults EA initialized. Symbol=", Symbol(), " Period=", Period());
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "DXB_TS_");
}

void OnTick()
{
   RefreshRates();

   if(ShowDashboard) DrawDashboard();

   if(!IsTradingAllowedNow()) return;

   ManageBasket(OP_BUY);
   ManageBasket(OP_SELL);

   if(EnableRecovery)
   {
      ProcessRecovery(OP_BUY);
      ProcessRecovery(OP_SELL);
   }

   if(TradeOnNewBarOnly && !IsNewBar()) return;

   int signal = GetEntrySignal();
   if(DebugPrint) PrintSignalDebug(signal);

   if(signal == 1 && EnableBuy && CountOrders(OP_BUY) == 0)
      OpenOrder(OP_BUY, "TS_MACD_BUY");

   if(signal == -1 && EnableSell && CountOrders(OP_SELL) == 0)
      OpenOrder(OP_SELL, "TS_MACD_SELL");
}

bool IsTradingAllowedNow()
{
   if(!IsTradeAllowed())
   {
      if(DebugPrint) Print("Blocked: IsTradeAllowed=false");
      return(false);
   }

   if(IsTradeContextBusy())
   {
      if(DebugPrint) Print("Blocked: Trade context busy");
      return(false);
   }

   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(spread > MaxSpreadPoints)
   {
      if(DebugPrint) Print("Blocked: Spread too high. Spread=", spread, " Max=", MaxSpreadPoints);
      return(false);
   }

   if(UseSessionFilter && !IsInsideSession())
   {
      if(DebugPrint) Print("Blocked: outside session");
      return(false);
   }

   return(true);
}

bool IsInsideSession()
{
   datetime now = TimeCurrent();
   int mins = TimeHour(now) * 60 + TimeMinute(now);
   int startMins = SessionStartHour * 60 + SessionStartMinute;
   int endMins = SessionEndHour * 60 + SessionEndMinute;

   if(startMins <= endMins)
      return(mins >= startMins && mins <= endMins);

   return(mins >= startMins || mins <= endMins);
}

bool IsNewBar()
{
   datetime t = iTime(Symbol(), TF(), 0);
   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return(true);
   }
   return(false);
}

double HLCC4(int shift)
{
   int tf = TF();
   return((iHigh(Symbol(), tf, shift) + iLow(Symbol(), tf, shift) + iClose(Symbol(), tf, shift) + iClose(Symbol(), tf, shift)) / 4.0);
}

double HL2(int shift)
{
   int tf = TF();
   return((iHigh(Symbol(), tf, shift) + iLow(Symbol(), tf, shift)) / 2.0);
}

int SafeBars(int need)
{
   int bars = iBars(Symbol(), TF());
   if(bars < need) return(bars - 1);
   return(need);
}

void BuildHLCC4Array(double &arr[], int bars)
{
   ArrayResize(arr, bars);
   ArraySetAsSeries(arr, true);
   for(int i=0; i<bars; i++)
      arr[i] = HLCC4(i);
}

void BuildHL2Array(double &arr[], int bars)
{
   ArrayResize(arr, bars);
   ArraySetAsSeries(arr, true);
   for(int i=0; i<bars; i++)
      arr[i] = HL2(i);
}

double EMAOnHLCC4(int period, int shift)
{
   int bars = SafeBars(MathMax(300, period + shift + 80));
   if(bars <= period + shift + 10) return(0);

   double src[];
   BuildHLCC4Array(src, bars);
   return(iMAOnArray(src, bars, period, 0, MODE_EMA, shift));
}

double MACDMainHLCC4(int shift)
{
   return(EMAOnHLCC4(MACDFastEMA, shift) - EMAOnHLCC4(MACDSlowEMA, shift));
}

double MACDSignalHLCC4(int shift)
{
   int bars = SafeBars(MathMax(400, MACDSlowEMA + MACDSignalEMA + shift + 120));
   if(bars <= MACDSlowEMA + MACDSignalEMA + shift + 10) return(0);

   double macdArr[];
   ArrayResize(macdArr, bars);
   ArraySetAsSeries(macdArr, true);

   for(int i=0; i<bars; i++)
      macdArr[i] = MACDMainHLCC4(i);

   return(iMAOnArray(macdArr, bars, MACDSignalEMA, 0, MODE_EMA, shift));
}

double RSIOnHL2(int shift)
{
   int bars = SafeBars(MathMax(300, RSIPeriod + shift + 80));
   if(bars <= RSIPeriod + shift + 10) return(50);

   double src[];
   BuildHL2Array(src, bars);
   return(iRSIOnArray(src, bars, RSIPeriod, shift));
}

double VolumeEMA(int shift)
{
   int bars = SafeBars(MathMax(300, VolumeMAPeriod + shift + 80));
   if(bars <= VolumeMAPeriod + shift + 10) return(0);

   double vol[];
   ArrayResize(vol, bars);
   ArraySetAsSeries(vol, true);

   for(int i=0; i<bars; i++)
      vol[i] = (double)iVolume(Symbol(), TF(), i);

   return(iMAOnArray(vol, bars, VolumeMAPeriod, 0, MODE_EMA, shift));
}

int GetEntrySignal()
{
   int tf = TF();

   double macd1 = MACDMainHLCC4(1);
   double sig1  = MACDSignalHLCC4(1);
   double macd2 = MACDMainHLCC4(2);
   double sig2  = MACDSignalHLCC4(2);

   bool macdCrossUp   = (macd2 <= sig2 && macd1 > sig1);
   bool macdCrossDown = (macd2 >= sig2 && macd1 < sig1);

   if(RelaxFiltersForTesting)
   {
      if(macdCrossUp) return(1);
      if(macdCrossDown) return(-1);
      return(0);
   }

   double close1 = iClose(Symbol(), tf, 1);
   double ma100  = iMA(Symbol(), tf, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double rsi    = RSIOnHL2(1);
   double adx    = iADX(Symbol(), tf, ADXLength, PRICE_CLOSE, MODE_MAIN, 1);
   double vol1   = (double)iVolume(Symbol(), tf, 1);
   double vema   = VolumeEMA(1);

   bool buyOk = true;
   bool sellOk = true;

   if(UseLongTrendFilter)
      buyOk = buyOk && (close1 > ma100);

   if(UseShortTrendFilter)
      sellOk = sellOk && (close1 < ma100);

   if(UseSimpleRSILimiter)
   {
      if(RSILimiterReverse)
      {
         buyOk  = buyOk  && (rsi < RSILongBoundary);
         sellOk = sellOk && (rsi > RSIShortBoundary);
      }
      else
      {
         buyOk  = buyOk  && (rsi > RSILongBoundary);
         sellOk = sellOk && (rsi < RSIShortBoundary);
      }
   }

   if(UseADXLimiter)
   {
      buyOk  = buyOk  && (adx >= ADXLowBoundary && adx <= ADXHighBoundary);
      sellOk = sellOk && (adx >= ADXLowBoundary && adx <= ADXHighBoundary);
   }

   if(UseVolumeFilter)
   {
      buyOk  = buyOk  && (vol1 > vema);
      sellOk = sellOk && (vol1 > vema);
   }

   if(macdCrossUp && buyOk) return(1);
   if(macdCrossDown && sellOk) return(-1);

   return(0);
}

void PrintSignalDebug(int signal)
{
   int tf = TF();

   double macd1 = MACDMainHLCC4(1);
   double sig1  = MACDSignalHLCC4(1);
   double macd2 = MACDMainHLCC4(2);
   double sig2  = MACDSignalHLCC4(2);

   bool up = (macd2 <= sig2 && macd1 > sig1);
   bool dn = (macd2 >= sig2 && macd1 < sig1);

   double close1 = iClose(Symbol(), tf, 1);
   double ma100 = iMA(Symbol(), tf, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double rsi = RSIOnHL2(1);
   double adx = iADX(Symbol(), tf, ADXLength, PRICE_CLOSE, MODE_MAIN, 1);
   double vol1 = (double)iVolume(Symbol(), tf, 1);
   double vema = VolumeEMA(1);

   Print("TS Debug | signal=", signal,
         " crossUp=", up,
         " crossDown=", dn,
         " MACD=", DoubleToString(macd1, 6),
         " SIG=", DoubleToString(sig1, 6),
         " RSI_HL2=", DoubleToString(rsi, 2),
         " ADX5=", DoubleToString(adx, 2),
         " Close=", DoubleToString(close1, Digits),
         " SMA100=", DoubleToString(ma100, Digits),
         " Vol=", DoubleToString(vol1, 0),
         " VolEMA10=", DoubleToString(vema, 2),
         " BuyOrders=", CountOrders(OP_BUY),
         " SellOrders=", CountOrders(OP_SELL));
}

bool OpenOrder(int type, string comment)
{
   RefreshRates();

   double price = (type == OP_BUY) ? Ask : Bid;
   int ticket = OrderSend(Symbol(), type, Lots, price, Slippage, 0, 0, comment, MagicNumber, 0,
                          (type == OP_BUY ? clrLime : clrRed));

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend failed. Type=", type, " Error=", err);
      ResetLastError();
      return(false);
   }

   Print("Order opened. Ticket=", ticket, " Type=", (type == OP_BUY ? "BUY" : "SELL"), " Price=", DoubleToString(price, Digits));
   return(true);
}

int CountOrders(int type)
{
   int count = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type)
         count++;
   }
   return(count);
}

double GetBasketProfit(int type)
{
   double profit = 0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == type)
         profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(profit);
}

void ManageBasket(int type)
{
   double profit = GetBasketProfit(type);

   if(type == OP_BUY)
   {
      if(profit >= BuyBasketTakeProfitUSD)
      {
         Print("BUY basket TP hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_BUY);
      }
      else if(profit <= BuyBasketStopLossUSD)
      {
         Print("BUY basket SL hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_BUY);
      }
   }

   if(type == OP_SELL)
   {
      if(profit >= SellBasketTakeProfitUSD)
      {
         Print("SELL basket TP hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_SELL);
      }
      else if(profit <= SellBasketStopLossUSD)
      {
         Print("SELL basket SL hit: $", DoubleToString(profit, 2));
         CloseOrdersByType(OP_SELL);
      }
   }
}

void CloseOrdersByType(int type)
{
   RefreshRates();

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != type) continue;

      double closePrice = (type == OP_BUY) ? Bid : Ask;
      bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrWhite);

      if(!closed)
      {
         int err = GetLastError();
         Print("OrderClose failed. Ticket=", OrderTicket(), " Error=", err);
         ResetLastError();
      }
   }
}

void ProcessRecovery(int type)
{
   int count = CountOrders(type);

   if(type == OP_BUY  && (count <= 0 || count >= MaxBuyOrders)) return;
   if(type == OP_SELL && (count <= 0 || count >= MaxSellOrders)) return;

   double basketProfit = GetBasketProfit(type);
   if(basketProfit >= 0.0) return;

   double lastPrice = GetLastOrderOpenPrice(type);
   if(lastPrice <= 0.0) return;

   RefreshRates();

   if(type == OP_BUY)
   {
      if((lastPrice - Bid) >= RecoveryGapPrice*count)
         OpenOrder(OP_BUY, "TS_RECOVERY_BUY");
   }

   if(type == OP_SELL)
   {
      if((Ask - lastPrice) >= RecoveryGapPrice*count)
         OpenOrder(OP_SELL, "TS_RECOVERY_SELL");
   }
}

double GetLastOrderOpenPrice(int type)
{
   datetime latestTime = 0;
   double latestPrice = 0.0;

   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != type) continue;

      if(OrderOpenTime() > latestTime)
      {
         latestTime = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return(latestPrice);
}

void DrawDashboard()
{
   string p = "DXB_TS_";
   int x = 15, y = 20, line = 18;

   int sig = GetEntrySignal();
   double buyProfit = GetBasketProfit(OP_BUY);
   double sellProfit = GetBasketProfit(OP_SELL);
   double rsi = RSIOnHL2(1);
   double adx = iADX(Symbol(), TF(), ADXLength, PRICE_CLOSE, MODE_MAIN, 1);
   double vol1 = (double)iVolume(Symbol(), TF(), 1);
   double vema = VolumeEMA(1);
   double ma100 = iMA(Symbol(), TF(), TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double atr = iATR(Symbol(), TF(), ATRLength, 1);

   DrawLabel(p+"TITLE", "TradeSmart MACD+RSI+ADX EA", x, y, clrYellow, 10); y += line;
   DrawLabel(p+"SIG", "Signal: " + SignalText(sig), x, y, SignalColor(sig), 9); y += line;
   DrawLabel(p+"BUY", "BUY: " + IntegerToString(CountOrders(OP_BUY)) + " P/L $" + DoubleToString(buyProfit, 2), x, y, clrLime, 9); y += line;
   DrawLabel(p+"SELL", "SELL: " + IntegerToString(CountOrders(OP_SELL)) + " P/L $" + DoubleToString(sellProfit, 2), x, y, clrTomato, 9); y += line;
   DrawLabel(p+"RSIADX", "RSI HL2: " + DoubleToString(rsi, 2) + " ADX5: " + DoubleToString(adx, 2), x, y, clrAqua, 9); y += line;
   DrawLabel(p+"VOL", "Vol: " + DoubleToString(vol1, 0) + " EMA10: " + DoubleToString(vema, 2), x, y, clrSilver, 9); y += line;
   DrawLabel(p+"MA", "SMA100: " + DoubleToString(ma100, Digits) + " ATR14: " + DoubleToString(atr, Digits), x, y, clrSilver, 9); y += line;
   DrawLabel(p+"MODE", "Relax Test: " + (RelaxFiltersForTesting ? "YES" : "NO"), x, y, RelaxFiltersForTesting ? clrOrange : clrSilver, 9);
}

string SignalText(int sig)
{
   if(sig == 1) return("BUY");
   if(sig == -1) return("SELL");
   return("NONE");
}

color SignalColor(int sig)
{
   if(sig == 1) return(clrLime);
   if(sig == -1) return(clrRed);
   return(clrSilver);
}

void DrawLabel(string name, string text, int x, int y, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}
//+------------------------------------------------------------------+
