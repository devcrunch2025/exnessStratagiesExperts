//+------------------------------------------------------------------+
//| DXB_SAR_Dots_Pending_SARWeakSmallProfit_FIXED.mq4                |
//| Uses verified SAR dots code.                                     |
//| Rules:                                                           |
//| 1) SAR GREEN + closed bar GREEN -> BUY STOP pending              |
//| 2) SAR RED + closed bar RED -> SELL STOP pending                 |
//| 3) SAR weak reverse: opposite strong candle -> reverse pending   |
//| 4) Pending gap raw price                                         |
//| 5) Delete all pending orders when one pending becomes market      |
//| 6) TP minimum, full-body profit hold option                      |
//| 7) Dynamic SL: same SAR direction = SL * multiplier              |
//| 8) SAR weak closes open order with small profit                  |
//| 9) Block flat market                                             |
//+------------------------------------------------------------------+
#property strict
#property version "1.36"

//======================== SAR SETTINGS ONLY ========================
input double InpSARPeriod        = 1.2;
input int    InpSARStepSize      = 25;
input int    InpSARAcceleration  = 9;

//======================== SAR DOT VISUALS ==========================
input bool   InpDrawSARDots      = true;
input int    InpSARDotLookback   = 300;
input color  InpSARDotBuyColor   = clrLime;
input color  InpSARDotSellColor  = clrOrangeRed;
input int    InpSARDotArrowCode  = 159;
input int    InpSARDotWidth      = 2;

//======================== SIMPLE TRADING ===========================
input bool   InpEnableTrading       = true;
input int    InpMagicNumber         = 26061920;
input double InpLots                = 0.01;
input int    InpSlippage            = 30;
input int    InpMaxSpreadPoints     = 3000;

input double InpPendingGapRaw       = 10.0;
input int    InpMaxOpenOrders       = 2;
input int    InpMaxOpenBuyOrders    = 1;
input int    InpMaxOpenSellOrders   = 1;
input int    InpMaxPendingOrders    = 10;
input int    InpPendingExpireBars   = 60;

input double InpProfitTargetUSD     = 0.50;
input bool   InpUseFullBodyProfit   = true;
input double InpMinFullBodyUSD      = 0.25;
input double InpStopLossUSD         = 1.00;
input double InpTrendSLMultiplier   = 2.00;

// SAR weak reverse / close
input bool   InpUseSARWeakReverse       = true;
input double InpSARWeakReverseBodyRaw   = 100.0;
input bool   InpCloseOrdersOnSARFlip    = true;
input bool   InpDeletePendingsOnSARFlip = true;
input bool   InpCloseOnSARWeakSmallProfit = true;
input double InpSARWeakSmallProfitUSD     = 0.10;

// Re-entry protection
input bool   InpBlockNewOrderOnClosedCandle = true;

// Flat market block
input bool   InpUseFlatMarketBlock       = true;
input int    InpFlatLookbackBars         = 10;
input double InpFlatMaxRangeRaw          = 120.0;
input double InpFlatMaxNetMoveRaw        = 50.0;
input double InpFlatMaxBodyTotalRaw      = 180.0;

// Dashboard
input bool   InpShowDashboard    = true;
input color  InpDashBgColor      = clrBlack;
input color  InpDashBorderColor  = clrDimGray;

//======================== GLOBALS ==================================
string   OBJ_PREFIX = "DXB_SAR_SIMPLE_";
int      g_activeSARDirection = 0;
int      g_lastSARDirection   = 0;
datetime g_lastSARFlipTime    = 0;
double   g_lastSARFlipPrice   = 0.0;
datetime g_lastBarTime        = 0;
string   g_status             = "SAR dots + pending + weak small profit";

datetime g_lastOrderCloseBarTime = 0;
datetime g_lastOrderCloseTime    = 0;
string   g_lastCloseReason       = "NO CLOSE YET";
int      g_lastMarketOrderCount  = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   UpdateSARState();
   DrawDashboardFrame();
   DrawSARDots();
   g_lastMarketOrderCount = CountMyOpenOrders();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   UpdateSARState();

   if(InpDrawSARDots)
      DrawSARDots();

   ManagePendingOrders();
   DeletePendingsWhenMarketOrderOpened();
   ManageOpenOrders();

   if(Time[0] != g_lastBarTime)
   {
      g_lastBarTime = Time[0];
      ProcessNewBarTrading();
   }

   if(InpShowDashboard)
      DrawDashboard();
}

//======================== SAR CORE =================================
double SARStep()
{
   return(InpSARPeriod * InpSARStepSize / 10000.0);
}

double SARMaximum()
{
   return(SARStep() * InpSARAcceleration);
}

double SARValue(int shift)
{
   return(iSAR(Symbol(), Period(), SARStep(), SARMaximum(), shift));
}

int GetSARDotDirection(int shift)
{
   double sar = SARValue(shift);
   double cls = iClose(Symbol(), Period(), shift);

   if(sar < cls) return(1);
   if(sar > cls) return(-1);
   return(0);
}

int GetSARFlipSignal()
{
   int d1 = GetSARDotDirection(1);
   int d2 = GetSARDotDirection(2);

   if(d1 != 0 && d2 != 0 && d1 != d2)
      return(d1);

   return(0);
}

void UpdateSARState()
{
   int dir = GetSARDotDirection(1);
   if(dir == 0)
      return;

   if(g_activeSARDirection == 0)
   {
      g_activeSARDirection = dir;
      g_lastSARDirection   = dir;
      g_lastSARFlipTime    = Time[1];
      g_lastSARFlipPrice   = Close[1];
      return;
   }

   if(dir != g_activeSARDirection)
   {
      g_lastSARDirection   = g_activeSARDirection;
      g_activeSARDirection = dir;
      g_lastSARFlipTime    = Time[1];
      g_lastSARFlipPrice   = Close[1];
      g_status = "SAR flip detected: " + DirectionText(dir);

      if(InpCloseOrdersOnSARFlip)
         CloseAllOpenOrders("SAR flip close");

      if(InpDeletePendingsOnSARFlip)
         DeleteAllPendingOrders("SAR flip delete pending");
   }
}

//======================== ENTRY LOGIC ==============================
void ProcessNewBarTrading()
{
   if(!InpEnableTrading)
   {
      g_status = "Trading OFF";
      return;
   }

   if(!IsTradeAllowedNow())
      return;

   if(InpBlockNewOrderOnClosedCandle && g_lastOrderCloseBarTime == Time[1])
   {
      g_status = "Blocked: order closed on previous candle";
      return;
   }

   if(InpUseFlatMarketBlock && IsFlatMarket())
   {
      g_status = "Blocked: flat market";
      return;
   }

   if(CountMyOpenOrders() >= InpMaxOpenOrders)
   {
      g_status = "Blocked: max total open orders";
      return;
   }

   if(CountMyPendingOrders() >= InpMaxPendingOrders)
   {
      g_status = "Blocked: max pending orders";
      return;
   }

   int sarDir = g_activeSARDirection;
   int barDir = CandleDirection(1);

   if(sarDir == 0 || barDir == 0)
   {
      g_status = "No order: SAR/bar none";
      return;
   }

   if(InpUseSARWeakReverse && IsSARWeakReverseSignal())
   {
      int reverseDir = -sarDir;
      if(CanPlacePendingForDirection(reverseDir))
         PlacePendingOrder(reverseDir, "SAR_WEAK_REVERSE_PENDING");
      return;
   }

   if(sarDir == 1 && barDir == 1)
   {
      if(CanPlacePendingForDirection(1))
         PlacePendingOrder(1, "SAR_GREEN_BAR_GREEN_BUYSTOP");
      return;
   }

   if(sarDir == -1 && barDir == -1)
   {
      if(CanPlacePendingForDirection(-1))
         PlacePendingOrder(-1, "SAR_RED_BAR_RED_SELLSTOP");
      return;
   }

   g_status = "No order: SAR and candle not matching";
}

bool IsSARWeakReverseSignal()
{
   int sarDir = g_activeSARDirection;
   int barDir = CandleDirection(1);
   double body = CandleBodyRaw(1);

   if(sarDir == 0 || barDir == 0)
      return(false);

   if(barDir != -sarDir)
      return(false);

   if(body < InpSARWeakReverseBodyRaw)
   {
      g_status = "SAR weak but reverse body small: " + DoubleToString(body, 2);
      return(false);
   }

   return(true);
}

int CandleDirection(int shift)
{
   if(Close[shift] > Open[shift]) return(1);
   if(Close[shift] < Open[shift]) return(-1);
   return(0);
}

double CandleBodyRaw(int shift)
{
   return(MathAbs(Close[shift] - Open[shift]));
}

//======================== PROFIT / RISK ============================
double MoneyPerRawPriceForLot()
{
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);

   if(tickSize <= 0.0)
      return(0.0);

   return((tickValue / tickSize) * InpLots);
}

double CandleBodyProfitUSD(int shift)
{
   return(CandleBodyRaw(shift) * MoneyPerRawPriceForLot());
}

double GetDynamicStopLossUSD(int orderType)
{
   if((orderType == OP_BUY  && g_activeSARDirection == 1) ||
      (orderType == OP_SELL && g_activeSARDirection == -1))
      return(InpStopLossUSD * InpTrendSLMultiplier);

   return(InpStopLossUSD);
}

string StopLossModeText(int orderType)
{
   if((orderType == OP_BUY  && g_activeSARDirection == 1) ||
      (orderType == OP_SELL && g_activeSARDirection == -1))
      return("TREND SL");

   return("REVERSE SL");
}

void ManageOpenOrders()
{
   bool newBarNow = (Time[0] != g_lastBarTime);
   bool weakNow = IsSARWeakReverseSignal();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL) continue;

      int dir = (type == OP_BUY ? 1 : -1);
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      double currentSL = GetDynamicStopLossUSD(type);

      if(profit <= -currentSL)
      {
         CloseSelectedOrder(StopLossModeText(type) + " $" + DoubleToString(currentSL, 2));
         continue;
      }

      // SAR weak: accept small profit quickly
      if(InpCloseOnSARWeakSmallProfit && weakNow && profit >= InpSARWeakSmallProfitUSD)
      {
         CloseSelectedOrder("SAR weak small profit $" + DoubleToString(profit, 2));
         continue;
      }

      if(InpUseFullBodyProfit)
      {
         double currentBodyUSD = CandleBodyProfitUSD(0);
         double closedBodyUSD  = CandleBodyProfitUSD(1);

         if(newBarNow && CandleDirection(1) == dir &&
            closedBodyUSD >= MathMax(InpProfitTargetUSD, InpMinFullBodyUSD) &&
            profit >= InpProfitTargetUSD)
         {
            CloseSelectedOrder("Full body profit close $" + DoubleToString(profit, 2));
            continue;
         }

         if(CandleDirection(0) == dir &&
            currentBodyUSD >= MathMax(InpProfitTargetUSD, InpMinFullBodyUSD) &&
            profit >= InpProfitTargetUSD)
         {
            g_status = "Holding for full body profit | Now $" + DoubleToString(profit, 2);
            continue;
         }
      }

      if(profit >= InpProfitTargetUSD)
      {
         CloseSelectedOrder("Minimum profit target $" + DoubleToString(InpProfitTargetUSD, 2));
         continue;
      }
   }
}

//======================== ORDER FUNCTIONS ==========================
bool PlacePendingOrder(int direction, string comment)
{
   RefreshRates();

   int type;
   double price;

   if(direction == 1)
   {
      type = OP_BUYSTOP;
      price = Ask + InpPendingGapRaw;
   }
   else if(direction == -1)
   {
      type = OP_SELLSTOP;
      price = Bid - InpPendingGapRaw;
   }
   else
      return(false);

   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;

   if(direction == 1 && price < Ask + stopLevel)
      price = Ask + stopLevel;

   if(direction == -1 && price > Bid - stopLevel)
      price = Bid - stopLevel;

   price = NormalizeDouble(price, Digits);

   int ticket = OrderSend(Symbol(), type, InpLots, price, InpSlippage, 0, 0,
                          comment, InpMagicNumber, 0, clrNONE);

   if(ticket < 0)
   {
      int err = GetLastError();
      g_status = "Pending failed: " + IntegerToString(err);
      Print(g_status, " | type=", type, " | price=", DoubleToString(price, Digits));
      return(false);
   }

   g_status = "Pending placed #" + IntegerToString(ticket) + " " + DirectionText(direction);
   Print(g_status, " | ", comment, " | price=", DoubleToString(price, Digits));
   return(true);
}

bool CloseSelectedOrder(string reason)
{
   RefreshRates();

   int type = OrderType();
   double price = (type == OP_BUY ? Bid : Ask);
   int ticket = OrderTicket();

   bool ok = OrderClose(ticket, OrderLots(), price, InpSlippage, clrNONE);

   if(ok)
   {
      g_lastOrderCloseBarTime = Time[0];
      g_lastOrderCloseTime    = TimeCurrent();
      g_lastCloseReason       = reason;

      g_status = "Closed #" + IntegerToString(ticket) + " | " + reason;
      Print(g_status);
   }
   else
   {
      int err = GetLastError();
      g_status = "Close failed: " + IntegerToString(err);
      Print(g_status, " | ticket=", ticket);
   }

   return(ok);
}

void CloseAllOpenOrders(string reason)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
         CloseSelectedOrder(reason);
   }
}

void ManagePendingOrders()
{
   if(InpPendingExpireBars <= 0)
      return;

   int expireSeconds = PeriodSeconds() * InpPendingExpireBars;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type != OP_BUYSTOP && type != OP_SELLSTOP &&
         type != OP_BUYLIMIT && type != OP_SELLLIMIT)
         continue;

      int pendingDir = 0;
      if(type == OP_BUYSTOP || type == OP_BUYLIMIT) pendingDir = 1;
      if(type == OP_SELLSTOP || type == OP_SELLLIMIT) pendingDir = -1;

      if(pendingDir == 1 && CountMyOpenOrdersByDirection(1) >= InpMaxOpenBuyOrders)
      {
         int ticketSideBuy = OrderTicket();
         if(OrderDelete(ticketSideBuy, clrNONE))
            g_status = "Deleted BUY pending: BUY already open #" + IntegerToString(ticketSideBuy);
         continue;
      }

      if(pendingDir == -1 && CountMyOpenOrdersByDirection(-1) >= InpMaxOpenSellOrders)
      {
         int ticketSideSell = OrderTicket();
         if(OrderDelete(ticketSideSell, clrNONE))
            g_status = "Deleted SELL pending: SELL already open #" + IntegerToString(ticketSideSell);
         continue;
      }

      if(TimeCurrent() - OrderOpenTime() >= expireSeconds)
      {
         int ticket = OrderTicket();
         if(OrderDelete(ticket, clrNONE))
            g_status = "Deleted expired pending #" + IntegerToString(ticket);
         else
            g_status = "Pending delete failed: " + IntegerToString(GetLastError());
      }
   }
}

void DeleteAllPendingOrders(string reason)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type != OP_BUYSTOP && type != OP_SELLSTOP &&
         type != OP_BUYLIMIT && type != OP_SELLLIMIT)
         continue;

      int ticket = OrderTicket();
      if(OrderDelete(ticket, clrNONE))
      {
         g_status = reason + " #" + IntegerToString(ticket);
         Print(g_status);
      }
      else
      {
         g_status = "Pending delete failed: " + IntegerToString(GetLastError());
         Print(g_status, " | ticket=", ticket);
      }
   }
}

void DeletePendingsWhenMarketOrderOpened()
{
   int currentOpen = CountMyOpenOrders();
   if(currentOpen > g_lastMarketOrderCount && currentOpen > 0)
   {
      DeleteAllPendingOrders("Market order opened - delete all pendings");
   }
   g_lastMarketOrderCount = currentOpen;
}

//======================== COUNTS / CHECKS ==========================
bool IsTradeAllowedNow()
{
   int spread = (int)MarketInfo(Symbol(), MODE_SPREAD);
   if(spread > InpMaxSpreadPoints)
   {
      g_status = "Blocked: spread high " + IntegerToString(spread);
      return(false);
   }

   if(!IsTradeAllowed())
   {
      g_status = "Blocked: trade not allowed";
      return(false);
   }

   return(true);
}

int CountMyOpenOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
         count++;
   }
   return(count);
}

int CountMyOpenOrdersByDirection(int direction)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(direction == 1 && type == OP_BUY) count++;
      if(direction == -1 && type == OP_SELL) count++;
   }
   return(count);
}

bool CanPlacePendingForDirection(int direction)
{
   int openTotal = CountMyOpenOrders();
   if(openTotal >= InpMaxOpenOrders)
   {
      g_status = "Blocked: max total open orders " + IntegerToString(openTotal);
      return(false);
   }

   int openBuy = CountMyOpenOrdersByDirection(1);
   int openSell = CountMyOpenOrdersByDirection(-1);

   if(direction == 1 && openBuy >= InpMaxOpenBuyOrders)
   {
      g_status = "Blocked: BUY already open";
      return(false);
   }

   if(direction == -1 && openSell >= InpMaxOpenSellOrders)
   {
      g_status = "Blocked: SELL already open";
      return(false);
   }

   int pendingCount = CountMyPendingOrders();
   if(pendingCount >= InpMaxPendingOrders)
   {
      g_status = "Blocked: max pending orders " + IntegerToString(pendingCount);
      return(false);
   }

   return(true);
}

int CountMyPendingOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type == OP_BUYSTOP || type == OP_SELLSTOP ||
         type == OP_BUYLIMIT || type == OP_SELLLIMIT)
         count++;
   }
   return(count);
}

double MyFloatingPL()
{
   double total = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;

      int type = OrderType();
      if(type == OP_BUY || type == OP_SELL)
         total += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return(total);
}

//======================== FLAT MARKET ==============================
double FlatRangeRaw()
{
   int bars = MathMin(InpFlatLookbackBars, Bars - 2);
   if(bars <= 1) return(0.0);

   double hi = High[1];
   double lo = Low[1];

   for(int i = 1; i <= bars; i++)
   {
      if(High[i] > hi) hi = High[i];
      if(Low[i]  < lo) lo = Low[i];
   }

   return(MathAbs(hi - lo));
}

double FlatNetMoveRaw()
{
   int bars = MathMin(InpFlatLookbackBars, Bars - 2);
   if(bars <= 1) return(0.0);

   return(MathAbs(Close[1] - Close[bars]));
}

double FlatBodyTotalRaw()
{
   int bars = MathMin(InpFlatLookbackBars, Bars - 2);
   if(bars <= 1) return(0.0);

   double total = 0.0;
   for(int i = 1; i <= bars; i++)
      total += CandleBodyRaw(i);

   return(total);
}

bool IsFlatMarket()
{
   if(!InpUseFlatMarketBlock) return(false);

   int bars = MathMin(InpFlatLookbackBars, Bars - 2);
   if(bars <= 1) return(false);

   double rangeRaw = FlatRangeRaw();
   double netRaw   = FlatNetMoveRaw();
   double bodyRaw  = FlatBodyTotalRaw();

   if(rangeRaw <= InpFlatMaxRangeRaw) return(true);
   if(netRaw <= InpFlatMaxNetMoveRaw && bodyRaw <= InpFlatMaxBodyTotalRaw) return(true);

   return(false);
}

//======================== DRAWING ==================================
void DrawSARDots()
{
   int bars = MathMin(InpSARDotLookback, Bars - 2);
   if(bars <= 0) return;

   for(int i = bars; i >= 1; i--)
   {
      double sar = SARValue(i);
      if(sar <= 0.0) continue;

      int dir = GetSARDotDirection(i);
      color c = (dir == 1 ? InpSARDotBuyColor : InpSARDotSellColor);
      string name = OBJ_PREFIX + "DOT_" + TimeToString(Time[i], TIME_DATE|TIME_MINUTES);

      if(ObjectFind(0, name) < 0)
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);

      ObjectSetDouble(0, name, OBJPROP_PRICE1, sar);
      ObjectSetInteger(0, name, OBJPROP_TIME1, Time[i]);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, InpSARDotArrowCode);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, InpSARDotWidth);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
}

string DirectionText(int direction)
{
   if(direction == 1)  return("BUY / BULL");
   if(direction == -1) return("SELL / BEAR");
   return("NONE");
}

double DynamicOpenSLPreview()
{
   double sl = InpStopLossUSD;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
      {
         sl = GetDynamicStopLossUSD(OrderType());
         break;
      }
   }
   return(sl);
}

void DrawDashboardFrame()
{
   if(!InpShowDashboard) return;

   string bg = OBJ_PREFIX + "DASH_BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 430);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 315);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpDashBgColor);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, InpDashBorderColor);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
}

void SetLabel(string name, int y, string text, color clr)
{
   string obj = OBJ_PREFIX + name;
   if(ObjectFind(0, obj) < 0)
      ObjectCreate(0, obj, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, obj, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, obj, OBJPROP_XDISTANCE, 16);
   ObjectSetInteger(0, obj, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj, OBJPROP_TEXT, text);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, obj, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, obj, OBJPROP_FONT, "Arial");
}

void DrawDashboard()
{
   DrawDashboardFrame();

   double sar1 = SARValue(1);
   double price = Close[1];
   double dist = MathAbs(price - sar1);
   int flip = GetSARFlipSignal();
   int barDir = CandleDirection(1);
   double body = CandleBodyRaw(1);
   bool weakReverse = IsSARWeakReverseSignal();

   color sarColor = (g_activeSARDirection == 1 ? InpSARDotBuyColor : InpSARDotSellColor);

   SetLabel("L1", 30,  "DXB SAR SIMPLE + WEAK SMALL PROFIT", clrWhite);
   SetLabel("L2", 50,  "Symbol: " + Symbol() + " | TF: " + IntegerToString(Period()), clrSilver);
   SetLabel("L3", 70,  "SAR: " + DirectionText(g_activeSARDirection), sarColor);
   SetLabel("L4", 90,  "Bar[1]: " + DirectionText(barDir) + " | Body: " + DoubleToString(body, 2), barDir==1?clrLime:(barDir==-1?clrOrangeRed:clrSilver));
   SetLabel("L5", 110, "SAR Weak Reverse: " + (weakReverse ? "YES" : "NO") + " | SmallProfit: $" + DoubleToString(InpSARWeakSmallProfitUSD, 2), weakReverse?clrOrange:clrSilver);
   SetLabel("L6", 130, "SAR Price: " + DoubleToString(sar1, Digits), clrYellow);
   SetLabel("L7", 150, "Close[1]: " + DoubleToString(price, Digits) + " | Dist: " + DoubleToString(dist, 2), clrAqua);
   SetLabel("L8", 170, "Flip: " + DirectionText(flip) + " | PendingGap: " + DoubleToString(InpPendingGapRaw, 0), clrSilver);
   SetLabel("L9", 190, "Open: " + IntegerToString(CountMyOpenOrders()) + "/" + IntegerToString(InpMaxOpenOrders) +
                      " (B:" + IntegerToString(CountMyOpenOrdersByDirection(1)) + "/1 S:" + IntegerToString(CountMyOpenOrdersByDirection(-1)) + "/1)" +
                      " | Pending: " + IntegerToString(CountMyPendingOrders()) + "/" + IntegerToString(InpMaxPendingOrders), clrWhite);
   SetLabel("L10", 210, "Floating P/L: $" + DoubleToString(MyFloatingPL(), 2) +
                      " | TP: $" + DoubleToString(InpProfitTargetUSD, 2) +
                      " | BodyUSD: $" + DoubleToString(CandleBodyProfitUSD(1), 2), clrWhite);
   SetLabel("L11", 230, "Flat: " + (IsFlatMarket() ? "YES" : "NO") +
                      " | Range: " + DoubleToString(FlatRangeRaw(), 2) +
                      " | Net: " + DoubleToString(FlatNetMoveRaw(), 2), IsFlatMarket()?clrOrange:clrLime);
   SetLabel("L12", 250, "SL: Trend=$" + DoubleToString(InpStopLossUSD * InpTrendSLMultiplier, 2) +
                      " | Reverse=$" + DoubleToString(InpStopLossUSD, 2) +
                      " | Active=$" + DoubleToString(DynamicOpenSLPreview(), 2), clrYellow);
   SetLabel("L13", 270, "Last close: " + g_lastCloseReason + " | Bar: " + TimeToString(g_lastOrderCloseBarTime, TIME_MINUTES), clrSilver);
   SetLabel("L14", 290, "Status: " + g_status, clrAqua);
}
//+------------------------------------------------------------------+
