//+------------------------------------------------------------------+
//| TradeSmart_MACD_RSI_ADX_Defaults_EA.mq4                          |
//| MT4 EA using visible TradingView defaults                         |
//| MACD 12/26/9 on HLCC4, RSI 14 on HL2 Reverse, ADX 5 limiter       |
//| SMA100 trend filter, Volume > EMA10, basket TP $5 / SL $5        |
//+------------------------------------------------------------------+
#property strict

int      MagicNumber              = 260601;
double   Lots                     = 0.01;
int      Slippage                 = 30;
int      MaxSpreadPoints          = 3000;
ENUM_TIMEFRAMES SignalTF          = PERIOD_CURRENT;

bool     CloseOnExitSignal        = true;   // Close BUY on SELL signal, close SELL on BUY signal
bool     CloseOnProfitUSD         = true;   // Close basket when profit reaches target USD
double   BuyBasketTakeProfitUSD   = 5.00;   // Close BUY basket profit in USD
double   SellBasketTakeProfitUSD  = 5.00;   // Close SELL basket profit in USD
double   BuyBasketStopLossUSD     = -5.00;  // Fixed BUY basket stop loss in USD
double   SellBasketStopLossUSD    = -5.00;  // Fixed SELL basket stop loss in USD

bool     EnableRecovery           = true;
int      MaxBuyOrders             = 4;
int      MaxSellOrders            = 4;
double   RecoveryGapPrice         = 100;//0.05; // raw price distance. XAGUSD example 0.05, BTCUSD example 100

bool     TradeOnNewBarOnly        = true;
bool     EnableBuy                = true;
bool     EnableSell               = true;
bool     DebugPrint               = true;
bool     ShowDashboard            = true;
bool     ShowChartGraphics         = true;   // Draw arrows, filter status, SMA100 and recovery levels on chart
int      GraphicsLookbackBars      = 20;     // How many closed bars to scan for MACD crosses
bool     DrawFilterFailLabels      = true;   // Show why signal/order is blocked near candle
bool     DrawSMA100Line            = true;

// TradingView visible defaults
int      MACDFastEMA              = 12;
int      MACDSlowEMA              = 26;
int      MACDSignalEMA            = 9;

bool     UseLongTrendFilter       = true;
bool     UseShortTrendFilter      = true;
int      TrendMAPeriod            = 100;

bool     UseSimpleRSILimiter      = true;
bool     RSILimiterReverse        = true;
int      RSIPeriod                = 14;
double   RSILongBoundary          = 50.0;
double   RSIShortBoundary         = 50.0;

bool     UseADXLimiter            = true;
int      ADXLength                = 5;
double   ADXHighBoundary          = 50.0;
double   ADXLowBoundary           = 20.0;

bool     UseVolumeFilter          = true;
int      VolumeMAPeriod           = 10;

int      ATRLength                = 14;
double   BaseRiskMultiplier       = 1.5;
double   RiskRewardRatio          = 2.5;

bool     UseSessionFilter         = false;
int      SessionStartHour         = 9;
int      SessionStartMinute       = 30;
int      SessionEndHour           = 16;
int      SessionEndMinute         = 0;

// true = MACD cross only for debugging 0-order problem
bool     RelaxFiltersForTesting   = false;

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
   if(ShowChartGraphics) DrawChartGraphics();

   if(!IsTradingAllowedNow()) return;

   // Profit booking and stop loss protection are checked every tick.
   if(CloseOnProfitUSD)
   {
      ManageBasketTakeProfit(OP_BUY);
      ManageBasketTakeProfit(OP_SELL);
   }

   ManageBasketStopLoss(OP_BUY);
   ManageBasketStopLoss(OP_SELL);

   if(EnableRecovery)
   {
      ProcessRecovery(OP_BUY);
      ProcessRecovery(OP_SELL);
   }

   if(TradeOnNewBarOnly && !IsNewBar()) return;

   int signal = GetEntrySignal();
   if(DebugPrint) PrintSignalDebug(signal);

   // Exit is now signal based, not fixed profit based.
   // SELL signal closes BUY basket. BUY signal closes SELL basket.
   if(CloseOnExitSignal)
      CloseOrdersOnExitSignal(signal);

   // Create order immediately when a valid signal is received.
   // It does NOT wait for fixed TakeProfit. Opposite basket is closed first,
   // then new signal direction order is opened, protected by MaxBuyOrders/MaxSellOrders.
   OpenOrderWhenSignalReceived(signal);
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


void ManageBasketTakeProfit(int type)
{
   double profit = GetBasketProfit(type);

   if(type == OP_BUY && profit >= BuyBasketTakeProfitUSD)
   {
      Print("BUY basket PROFIT hit: $", DoubleToString(profit, 2),
            " Target=$", DoubleToString(BuyBasketTakeProfitUSD, 2));
      CloseOrdersByType(OP_BUY);
   }

   if(type == OP_SELL && profit >= SellBasketTakeProfitUSD)
   {
      Print("SELL basket PROFIT hit: $", DoubleToString(profit, 2),
            " Target=$", DoubleToString(SellBasketTakeProfitUSD, 2));
      CloseOrdersByType(OP_SELL);
   }
}

void ManageBasketStopLoss(int type)
{
   double profit = GetBasketProfit(type);

   if(type == OP_BUY && profit <= BuyBasketStopLossUSD)
   {
      Print("BUY basket SL hit: $", DoubleToString(profit, 2));
      CloseOrdersByType(OP_BUY);
   }

   if(type == OP_SELL && profit <= SellBasketStopLossUSD)
   {
      Print("SELL basket SL hit: $", DoubleToString(profit, 2));
      CloseOrdersByType(OP_SELL);
   }
}

void CloseOrdersOnExitSignal(int signal)
{
   if(signal == 1 && CountOrders(OP_SELL) > 0)
   {
      Print("EXIT SIGNAL: BUY signal detected. Closing SELL basket.");
      CloseOrdersByType(OP_SELL);
   }

   if(signal == -1 && CountOrders(OP_BUY) > 0)
   {
      Print("EXIT SIGNAL: SELL signal detected. Closing BUY basket.");
      CloseOrdersByType(OP_BUY);
   }
}

void OpenOrderWhenSignalReceived(int signal)
{
   if(signal == 1)
   {
      if(!EnableBuy)
      {
         if(DebugPrint) Print("BUY signal received but EnableBuy=false");
         return;
      }

      int buyCount = CountOrders(OP_BUY);
      if(buyCount >= MaxBuyOrders)
      {
         if(DebugPrint) Print("BUY signal received but MaxBuyOrders reached. Count=", buyCount, " Max=", MaxBuyOrders);
         return;
      }

      RefreshRates();
      OpenOrder(OP_BUY, "TS_SIGNAL_BUY");
      DrawSignalOrderMarker(OP_BUY, Time[0], Ask, "BUY ORDER CREATED ON SIGNAL");
      return;
   }

   if(signal == -1)
   {
      if(!EnableSell)
      {
         if(DebugPrint) Print("SELL signal received but EnableSell=false");
         return;
      }

      int sellCount = CountOrders(OP_SELL);
      if(sellCount >= MaxSellOrders)
      {
         if(DebugPrint) Print("SELL signal received but MaxSellOrders reached. Count=", sellCount, " Max=", MaxSellOrders);
         return;
      }

      RefreshRates();
      OpenOrder(OP_SELL, "TS_SIGNAL_SELL");
      DrawSignalOrderMarker(OP_SELL, Time[0], Bid, "SELL ORDER CREATED ON SIGNAL");
      return;
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


//+------------------------------------------------------------------+
//| Visual chart explanation before order creation                    |
//+------------------------------------------------------------------+
void DrawChartGraphics()
{
   static datetime lastVisualBar = 0;
   datetime t = iTime(Symbol(), TF(), 0);

   // Redraw full historical objects only once per candle. Live levels update every tick.
   if(t != lastVisualBar)
   {
      lastVisualBar = t;
      DeleteObjectsByPrefix("DXB_TS_VIS_");
      DrawSMA100Segments();
      DrawHistoricalSignalMarkers();
   }

   DrawLiveDecisionPanel();
   DrawRecoveryAndBasketLevels(OP_BUY);
   DrawRecoveryAndBasketLevels(OP_SELL);
   DrawOpenOrderMarkers();
}

void DrawHistoricalSignalMarkers()
{
   int bars = MathMin(GraphicsLookbackBars, iBars(Symbol(), TF()) - 3);
   if(bars <= 3) return;

   for(int shift=bars; shift>=1; shift--)
   {
      int rawSignal = GetRawMACDCrossSignal(shift);
      if(rawSignal == 0) continue;

      bool buyOk=false, sellOk=false;
      string buyReason="", sellReason="";
      GetFilterStatus(shift, buyOk, sellOk, buyReason, sellReason);

      datetime candleTime = iTime(Symbol(), TF(), shift);
      double high = iHigh(Symbol(), TF(), shift);
      double low  = iLow(Symbol(), TF(), shift);
      double atr  = iATR(Symbol(), TF(), ATRLength, shift);
      if(atr <= 0) atr = (high - low);
      if(atr <= 0) atr = Point * 100;

      if(rawSignal == 1)
      {
         bool finalOk = (RelaxFiltersForTesting || buyOk);
         DrawArrow("DXB_TS_VIS_BUY_" + IntegerToString((int)candleTime), candleTime, low - atr*0.35,
                   233, finalOk ? clrLime : clrGray, 2);

         string txt = finalOk ? "BUY READY" : "BUY BLOCKED";
         if(DrawFilterFailLabels && !finalOk) txt = "BUY BLOCKED: " + buyReason;
         DrawText("DXB_TS_VIS_BUY_TXT_" + IntegerToString((int)candleTime), txt,
                  candleTime, low - atr*0.75, finalOk ? clrLime : clrOrangeRed, 8);
      }

      if(rawSignal == -1)
      {
         bool finalOk = (RelaxFiltersForTesting || sellOk);
         DrawArrow("DXB_TS_VIS_SELL_" + IntegerToString((int)candleTime), candleTime, high + atr*0.35,
                   234, finalOk ? clrRed : clrGray, 2);

         string txt = finalOk ? "SELL READY" : "SELL BLOCKED";
         if(DrawFilterFailLabels && !finalOk) txt = "SELL BLOCKED: " + sellReason;
         DrawText("DXB_TS_VIS_SELL_TXT_" + IntegerToString((int)candleTime), txt,
                  candleTime, high + atr*0.75, finalOk ? clrRed : clrOrangeRed, 8);
      }
   }
}

int GetRawMACDCrossSignal(int shift)
{
   double macd1 = MACDMainHLCC4(shift);
   double sig1  = MACDSignalHLCC4(shift);
   double macd2 = MACDMainHLCC4(shift + 1);
   double sig2  = MACDSignalHLCC4(shift + 1);

   if(macd2 <= sig2 && macd1 > sig1) return(1);
   if(macd2 >= sig2 && macd1 < sig1) return(-1);
   return(0);
}

void GetFilterStatus(int shift, bool &buyOk, bool &sellOk, string &buyReason, string &sellReason)
{
   int tf = TF();
   double close1 = iClose(Symbol(), tf, shift);
   double ma100  = iMA(Symbol(), tf, TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, shift);
   double rsi    = RSIOnHL2(shift);
   double adx    = iADX(Symbol(), tf, ADXLength, PRICE_CLOSE, MODE_MAIN, shift);
   double vol1   = (double)iVolume(Symbol(), tf, shift);
   double vema   = VolumeEMA(shift);

   buyOk = true;
   sellOk = true;
   buyReason = "";
   sellReason = "";

   if(UseLongTrendFilter && close1 <= ma100)
   {
      buyOk = false;
      buyReason += "SMA100 ";
   }
   if(UseShortTrendFilter && close1 >= ma100)
   {
      sellOk = false;
      sellReason += "SMA100 ";
   }

   if(UseSimpleRSILimiter)
   {
      if(RSILimiterReverse)
      {
         if(rsi >= RSILongBoundary)  { buyOk=false;  buyReason += "RSI "; }
         if(rsi <= RSIShortBoundary) { sellOk=false; sellReason += "RSI "; }
      }
      else
      {
         if(rsi <= RSILongBoundary)  { buyOk=false;  buyReason += "RSI "; }
         if(rsi >= RSIShortBoundary) { sellOk=false; sellReason += "RSI "; }
      }
   }

   if(UseADXLimiter)
   {
      if(adx < ADXLowBoundary || adx > ADXHighBoundary)
      {
         buyOk = false;
         sellOk = false;
         buyReason += "ADX ";
         sellReason += "ADX ";
      }
   }

   if(UseVolumeFilter && vol1 <= vema)
   {
      buyOk = false;
      sellOk = false;
      buyReason += "VOL ";
      sellReason += "VOL ";
   }

   if(buyReason == "")  buyReason = "OK";
   if(sellReason == "") sellReason = "OK";
}

void DrawLiveDecisionPanel()
{
   string p = "DXB_TS_LIVE_";
   int x = 15, y = 170, line = 17;

   int raw = GetRawMACDCrossSignal(1);
   int finalSig = GetEntrySignal();

   bool buyOk=false, sellOk=false;
   string buyReason="", sellReason="";
   GetFilterStatus(1, buyOk, sellOk, buyReason, sellReason);

   bool tradeAllowed = IsTradeAllowed() && !IsTradeContextBusy() && ((int)MarketInfo(Symbol(), MODE_SPREAD) <= MaxSpreadPoints) && (!UseSessionFilter || IsInsideSession());

   DrawPanel(p+"BG", x-8, y-6, 360, 185, clrBlack);
   DrawLabel(p+"TITLE", "LIVE ORDER DECISION", x, y, clrYellow, 9); y += line;
   DrawLabel(p+"RAW", "MACD cross: " + SignalText(raw), x, y, SignalColor(raw), 8); y += line;
   DrawLabel(p+"BUYOK", "BUY filters: " + (buyOk ? "PASS" : "BLOCK") + "  " + buyReason, x, y, buyOk ? clrLime : clrTomato, 8); y += line;
   DrawLabel(p+"SELLOK", "SELL filters: " + (sellOk ? "PASS" : "BLOCK") + "  " + sellReason, x, y, sellOk ? clrLime : clrTomato, 8); y += line;
   DrawLabel(p+"FINAL", "Final signal: " + SignalText(finalSig), x, y, SignalColor(finalSig), 8); y += line;
   DrawLabel(p+"TRADE", "Trade allowed: " + (tradeAllowed ? "YES" : "NO"), x, y, tradeAllowed ? clrLime : clrRed, 8); y += line;
   DrawLabel(p+"NOTE", "Gray arrows = MACD crossed but filters blocked order", x, y, clrSilver, 8); y += line;
   DrawLabel(p+"NOTE2", "Opposite signal = exit open basket", x, y, clrSilver, 8); y += line;
   DrawLabel(p+"NOTE3", "Profit: BUY/SELL basket closes at +$5", x, y, clrLime, 8); y += line;
   DrawLabel(p+"NOTE4", "Stop loss: BUY/SELL basket closes at -$5", x, y, clrAqua, 8);
}

void DrawSMA100Segments()
{
   if(!DrawSMA100Line) return;

   int bars = MathMin(GraphicsLookbackBars, iBars(Symbol(), TF()) - TrendMAPeriod - 2);
   if(bars <= 2) return;

   for(int shift=bars; shift>=2; shift--)
   {
      datetime t1 = iTime(Symbol(), TF(), shift);
      datetime t2 = iTime(Symbol(), TF(), shift-1);
      double v1 = iMA(Symbol(), TF(), TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, shift);
      double v2 = iMA(Symbol(), TF(), TrendMAPeriod, 0, MODE_SMA, PRICE_CLOSE, shift-1);
      string name = "DXB_TS_VIS_SMA_" + IntegerToString(shift);
      DrawTrendSegment(name, t1, v1, t2, v2, clrDodgerBlue, 1, STYLE_SOLID);
   }
}

void DrawRecoveryAndBasketLevels(int type)
{
   int count = CountOrders(type);
   string side = (type == OP_BUY ? "BUY" : "SELL");
   string p = "DXB_TS_LEVEL_" + side + "_";

   if(count <= 0)
   {
      ObjectDelete(0, p+"REC");
      ObjectDelete(0, p+"TXT");
      return;
   }

   double profit = GetBasketProfit(type);
   double lastPrice = GetLastOrderOpenPrice(type);
   if(lastPrice <= 0) return;

   double nextRecovery = 0;
   if(type == OP_BUY)  nextRecovery = lastPrice - RecoveryGapPrice * count;
   if(type == OP_SELL) nextRecovery = lastPrice + RecoveryGapPrice * count;

   color c = (type == OP_BUY ? clrLime : clrRed);

   if(profit < 0 && EnableRecovery)
   {
      DrawHLine(p+"REC", nextRecovery, c, STYLE_DASHDOT, 1);
      DrawPriceText(p+"TXT", side + " next recovery @ " + DoubleToString(nextRecovery, Digits), nextRecovery, c);
   }
   else
   {
      ObjectDelete(0, p+"REC");
      ObjectDelete(0, p+"TXT");
   }
}

void DrawOpenOrderMarkers()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      string side = (OrderType() == OP_BUY ? "BUY" : "SELL");
      color c = (OrderType() == OP_BUY ? clrLime : clrRed);
      string name = "DXB_TS_ORDER_" + IntegerToString(OrderTicket());
      DrawHLine(name, OrderOpenPrice(), c, STYLE_DOT, 1);
      DrawPriceText(name+"_TXT", side + " #" + IntegerToString(OrderTicket()) + " open", OrderOpenPrice(), c);
   }
}

void DrawArrow(string name, datetime t, double price, int arrowCode, color clr, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME1, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void DrawText(string name, string text, datetime t, double price, color clr, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_TIME1, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void DrawHLine(string name, double price, color clr, int style, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

void DrawPriceText(string name, string text, double price, color clr)
{
   datetime t = Time[0] + PeriodSeconds() * 5;
   DrawText(name, text, t, price, clr, 8);
}

void DrawTrendSegment(string name, datetime t1, double p1, datetime t2, double p2, color clr, int width, int style)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);

   ObjectSetInteger(0, name, OBJPROP_TIME1, t1);
   ObjectSetDouble(0, name, OBJPROP_PRICE1, p1);
   ObjectSetInteger(0, name, OBJPROP_TIME2, t2);
   ObjectSetDouble(0, name, OBJPROP_PRICE2, p2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
}

void DrawPanel(string name, int x, int y, int w, int h, color bg)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void DeleteObjectsByPrefix(string prefix)
{
   for(int i=ObjectsTotal(0, -1, -1)-1; i>=0; i--)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(0, name);
   }
}

void DrawSignalOrderMarker(int type, datetime t, double price, string text)
{
   if(!ShowChartGraphics) return;

   string name = "DXB_TS_SIGNAL_ORDER_" + IntegerToString((int)t) + "_" + IntegerToString(type);
   int arrowCode = (type == OP_BUY) ? 233 : 234;
   color clr = (type == OP_BUY) ? clrLime : clrRed;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_ARROW, 0, t, price);

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);

   string labelName = name + "_TXT";
   if(ObjectFind(0, labelName) < 0)
      ObjectCreate(0, labelName, OBJ_TEXT, 0, t, price);

   ObjectSetString(0, labelName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
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
   DrawLabel(p+"MODE", "TP: $5 Profit | Exit: Opposite Signal | SL: $5 | Relax: " + (RelaxFiltersForTesting ? "YES" : "NO"), x, y, RelaxFiltersForTesting ? clrOrange : clrSilver, 9);
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
