//+------------------------------------------------------------------+
//|                 DXB_SAR_EarlyTrend_Cycle_EA.mq4                  |
//|  First SAR signal -> continuous orders -> $1 basket profit        |
//|  SAR flip closes opposite orders. Early reverse trend pauses SAR  |
//|  cycle, draws arrows, closes opposite orders, resumes when aligned |
//+------------------------------------------------------------------+
#property strict
#property version   "1.01"

//======================== INPUTS ====================================
string InpEAName                  = "DXB SAR Early Trend Cycle EA";
int    InpMagicNumber             = 989899;
double InpFixedLot                = 0.01;
int    InpMaxOrders               = 1;     // display only; hard max is 2
double InpBasketProfitUSD         = 1.00;
int    InpStopLossPoints          = 0;       // 0 = no hard SL
int    InpSlippage                = 30;
int    InpMaxSpreadPoints         = 3000;

#define DXB_HARD_MAX_OPEN_ORDERS 1   // absolute safety limit before every OrderSend

// Continuous order controls
bool   InpOneOrderPerBar          = true;
int    InpOrderCooldownSeconds    = 0;       // 0 = disabled
double InpMinPriceGap             = 0.00;    // raw price gap, 0 = disabled

// SAR settings
double InpSARPeriod               = 1.2;
int    InpSARStepSize             = 25;
int    InpSARAcceleration         = 9;

// Early trend settings
bool   InpUseEarlyTrend           = true;
int    InpFastEMA                 = 9;
int    InpSlowEMA                 = 21;
int    InpEarlyLookbackCandles    = 2;
double InpMinEarlyBodyMove        = 0.00;    // raw price diff, 0 = disabled
bool   InpCloseOnEarlyReverse     = true;
bool   InpDrawEarlyArrows         = true;

// Flat mode detection before early trend
bool   InpUseFlatMode             = true;
int    InpFlatLookbackCandles     = 5;       // closed candles to scan
double InpFlatMaxEMADistance      = 0.00;    // raw price diff, 0 = auto using ATR
double InpFlatMaxBodyTotal        = 0.00;    // raw price diff, 0 = auto using ATR
int    InpFlatMaxSameColor        = 3;       // max green/red count allowed in flat
bool   InpDrawFlatDots            = true;
color  InpFlatDotColor            = clrSilver;

// Visuals
bool   InpDrawSARArrows           = true;
color  InpBuyColor                = clrLime;
color  InpSellColor               = clrRed;
color  InpEarlyBuyColor           = clrAqua;
color  InpEarlySellColor          = clrOrangeRed;

// SAR dot visuals
bool   InpDrawSARDots            = true;
int    InpSARDotLookback         = 200;      // historical SAR dots to draw
color  InpSARDotBuyColor         = clrLime;
color  InpSARDotSellColor        = clrOrangeRed;

//======================== GLOBALS ===================================
int      g_activeSARDirection   = 0;       // 1 BUY, -1 SELL
int      g_lastSARDotDirection  = 0;       // current SAR side memory
int      g_earlyDirection       = 0;       // 1 BUY, -1 SELL, 0 none
bool     g_sarPausedByEarly     = false;   // true when early reverse fights SAR
bool     g_firstSARLocked       = false;
datetime g_lastBarTime          = 0;
datetime g_lastOrderTime        = 0;
datetime g_lastEarlyArrowTime   = 0;
datetime g_lastSARArrowTime     = 0;
datetime g_lastFlatDotTime      = 0;
string   OBJ_PREFIX             = "DXB_SAR_CYCLE_";
int      dotColor               = 0;       // 1 SAR below price, -1 SAR above price
bool     g_flatMode             = false;   // true when price is compressed/sideways

//+------------------------------------------------------------------+
int OnInit()
{
   Print(InpEAName, " initialized. Magic=", InpMagicNumber);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}
//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   if(!IsTradeAllowed())
   {
      DrawDashboard("Trading not allowed");
      return;
   }

   if(MarketInfo(Symbol(), MODE_SPREAD) > InpMaxSpreadPoints)
   {
      DrawDashboard("Spread blocked");
      return;
   }

   // Draw/update SAR dots on every tick so they do not disappear when chart moves.
   DrawSARDots();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar)
      g_lastBarTime = Time[0];

   // 1) Lock first SAR direction from current SAR dot side.
   int sarDotDirection = GetSARDotDirection(1);
   if(!g_firstSARLocked && sarDotDirection != 0)
   {
      g_firstSARLocked      = true;
      g_activeSARDirection  = sarDotDirection;
      g_lastSARDotDirection = sarDotDirection;
      DrawSignalArrow("FIRST_SAR", g_activeSARDirection, Time[1], g_activeSARDirection == 1 ? Low[1] : High[1], false);
      Print("FIRST SAR LOCKED | Direction=", DirectionText(g_activeSARDirection));
   }

   // 2) Detect real SAR flip. Close opposite orders and reset cycle.
   int sarFlip = GetSARFlipSignal();
   if(sarFlip != 0 && sarFlip != g_activeSARDirection)
   {
      g_activeSARDirection = sarFlip;
      g_lastSARDotDirection = sarFlip;
      g_sarPausedByEarly = false;
      g_earlyDirection = 0;

      Print("SAR CHANGED | New SAR=", DirectionText(sarFlip), " -> closing opposite orders");
      CloseOppositeOrders(sarFlip, "SAR changed");

      if(InpDrawSARArrows && isNewBar)
         DrawSignalArrow("SAR_FLIP", sarFlip, Time[1], sarFlip == 1 ? Low[1] : High[1], false);
   }

   if(g_activeSARDirection == 0)
   {
      DrawDashboard("Waiting for first SAR");
      return;
   }

   // 3) Basket profit booking. After close, same SAR cycle continues/resumes.
   double activeProfit = GetBasketProfit(g_activeSARDirection);
   if(activeProfit >= InpBasketProfitUSD)
   {
      CloseOrdersByDirection(g_activeSARDirection, "Basket profit $" + DoubleToString(activeProfit, 2));
      Print("Profit booked. Resume same SAR direction=", DirectionText(g_activeSARDirection));
      DrawDashboard("Profit booked - resume same SAR");
      return;
   }

   // 4) Flat mode detection BEFORE early trend detection.
   // Flat mode means EMA compression + small/mixed candles.
   // During flat mode we draw circle dots and pause fresh entries until breakout/early trend appears.
   if(InpUseFlatMode)
   {
      g_flatMode = DetectFlatMode();
      if(g_flatMode)
      {
         if(InpDrawFlatDots && Time[1] != g_lastFlatDotTime)
         {
            DrawFlatDot(Time[1], (High[1] + Low[1]) / 2.0);
            g_lastFlatDotTime = Time[1];
         }

         // Do not open fresh orders inside compression. Existing orders are still managed above by basket TP/SAR flip.
         DrawDashboard("FLAT MODE - WAIT BREAKOUT");
         return;
      }
   }
   else
   {
      g_flatMode = false;
   }

   // 5) Early trend detection cycle.
   if(InpUseEarlyTrend)
   {
      int early = DetectEarlyTrend();
      if(early != 0)
      {
         if(early != g_earlyDirection)
         {
            g_earlyDirection = early;
            if(InpDrawEarlyArrows && Time[1] != g_lastEarlyArrowTime)
            {
               DrawSignalArrow("EARLY", early, Time[1], early == 1 ? Low[1] : High[1], true);
               g_lastEarlyArrowTime = Time[1];
            }
         }

         // Early trend opposite to SAR: close SAR-side orders and pause SAR order creation.
         if(early != g_activeSARDirection)
         {
            if(!g_sarPausedByEarly)
               Print("EARLY REVERSE DETECTED | Early=", DirectionText(early), " SAR=", DirectionText(g_activeSARDirection), " -> pause SAR orders");

            g_sarPausedByEarly = true;

            if(InpCloseOnEarlyReverse)
               CloseOppositeOrders(early, "Early reverse detected");

            DrawDashboard("Paused by early reverse " + DirectionText(early));
            return;
         }

         // Early trend changed back to same SAR direction: resume SAR order creation.
         if(early == g_activeSARDirection && g_sarPausedByEarly)
         {
            g_sarPausedByEarly = false;
            Print("EARLY TREND BACK TO SAR | Resume SAR orders. Direction=", DirectionText(g_activeSARDirection));
         }
      }
   }

   if(g_sarPausedByEarly)
   {
      DrawDashboard("Paused by early reverse");
      return;
   }

   // 5) Continuous order creation in active SAR direction.
   // Hard block: never open more than 2 symbol orders.
   if(CountAllSymbolMarketOrders() >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      DrawDashboard("MAX 2 ORDERS ACTIVE - WAIT CLOSE");
      return;
   }

   if(InpOneOrderPerBar && !isNewBar)
   {
      DrawDashboard("Waiting new bar");
      return;
   }

   if(!CanOpenNewOrder(g_activeSARDirection))
   {
      DrawDashboard("Order gate blocked");
      return;
   }

   OpenMarketOrder(g_activeSARDirection, "SAR continuous cycle");
   DrawDashboard("Active " + DirectionText(g_activeSARDirection));
}
//+------------------------------------------------------------------+
int GetSARFlipSignal()
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   double sar1 = iSAR(Symbol(), Period(), step, maxstep, 1);
   double sar2 = iSAR(Symbol(), Period(), step, maxstep, 2);

   if(sar1 < Close[1] && sar2 >= Close[2]) return 1;
   if(sar1 > Close[1] && sar2 <= Close[2]) return -1;
   return 0;
}
//+------------------------------------------------------------------+
int GetSARDotDirection(int shift)
{
   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;
   double sar     = iSAR(Symbol(), Period(), step, maxstep, shift);

   if(sar < Close[shift]) return 1;
   if(sar > Close[shift]) return -1;
   return 0;
}
//+------------------------------------------------------------------+
bool DetectFlatMode()
{
   int lookback = MathMax(2, InpFlatLookbackCandles);
   if(Bars <= lookback + 5)
      return(false);

   double emaFast = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaDistance = MathAbs(emaFast - emaSlow);

   double atr = iATR(Symbol(), Period(), 14, 1);
   if(atr <= 0)
      atr = Point * 100;

   double maxEMADistance = InpFlatMaxEMADistance;
   if(maxEMADistance <= 0.0)
      maxEMADistance = atr * 0.25;

   double maxBodyTotal = InpFlatMaxBodyTotal;
   if(maxBodyTotal <= 0.0)
      maxBodyTotal = atr * 0.80;

   int green = 0;
   int red   = 0;
   double bodyTotal = 0.0;
   double rangeHigh = High[1];
   double rangeLow  = Low[1];

   for(int i = 1; i <= lookback; i++)
   {
      double body = MathAbs(Close[i] - Open[i]);
      bodyTotal += body;

      if(Close[i] > Open[i]) green++;
      if(Close[i] < Open[i]) red++;

      if(High[i] > rangeHigh) rangeHigh = High[i];
      if(Low[i]  < rangeLow)  rangeLow  = Low[i];
   }

   double rangeSize = rangeHigh - rangeLow;

   bool emaCompressed = (emaDistance <= maxEMADistance);
   bool smallBodies   = (bodyTotal <= maxBodyTotal);
   bool mixedCandles  = (green <= InpFlatMaxSameColor && red <= InpFlatMaxSameColor);
   bool tightRange    = (rangeSize <= atr * 1.20);

   return(emaCompressed && smallBodies && mixedCandles && tightRange);
}

//+------------------------------------------------------------------+
void DrawFlatDot(datetime t, double price)
{
   string name = OBJ_PREFIX + "FLAT_DOT_" + IntegerToString((int)t);
   if(ObjectFind(0, name) >= 0)
      return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 108); // circle
   ObjectSetInteger(0, name, OBJPROP_COLOR, InpFlatDotColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
int DetectEarlyTrend()
{
   double emaFast1 = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow1 = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaFast2 = iMA(Symbol(), Period(), InpFastEMA, 0, MODE_EMA, PRICE_CLOSE, 2);
   double emaSlow2 = iMA(Symbol(), Period(), InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 2);

   bool emaBuy  = (emaFast1 > emaSlow1 && emaFast1 >= emaFast2);
   bool emaSell = (emaFast1 < emaSlow1 && emaFast1 <= emaFast2);

   int green = 0, red = 0;
   double totalBody = 0;
   int lookback = MathMax(1, InpEarlyLookbackCandles);

   for(int i = 1; i <= lookback; i++)
   {
      double body = MathAbs(Close[i] - Open[i]);
      totalBody += body;
      if(Close[i] > Open[i]) green++;
      if(Close[i] < Open[i]) red++;
   }

   bool bodyOK = (InpMinEarlyBodyMove <= 0.0 || totalBody >= InpMinEarlyBodyMove);

   if(bodyOK && emaBuy  && green >= MathMax(1, lookback - 1)) return 1;
   if(bodyOK && emaSell && red   >= MathMax(1, lookback - 1)) return -1;

   return 0;
}
//+------------------------------------------------------------------+
bool CanOpenNewOrder(int direction)
{
   if(direction == 0)
      return(false);

   // HARD GLOBAL SYMBOL LIMIT.
   // Counts ALL open BUY/SELL orders on this symbol, not only this EA magic.
   // This prevents SAR continuous cycle / early trend cycle from opening order #3.
   int openOrders = CountAllSymbolMarketOrders();
   if(openOrders >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDER BLOCKED | Max open orders reached. Symbol=", Symbol(),
            " Open=", openOrders,
            " Max=", DXB_HARD_MAX_OPEN_ORDERS,
            " Direction=", DirectionText(direction));
      DrawDashboard("MAX 2 ORDERS ACTIVE - WAIT CLOSE");
      return(false);
   }

   if(InpOrderCooldownSeconds > 0 && TimeCurrent() - g_lastOrderTime < InpOrderCooldownSeconds)
      return(false);

   if(InpMinPriceGap > 0.0 && !IsPriceGapValid(direction, InpMinPriceGap))
      return(false);

   return(true);
}
//+------------------------------------------------------------------+
bool IsPriceGapValid(int direction, double minGap)
{
   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != type) continue;

      if(MathAbs(price - OrderOpenPrice()) < minGap)
         return false;
   }
   return true;
}
//+------------------------------------------------------------------+
bool OpenMarketOrder(int direction, string reason)
{
   RefreshRates();

   // FINAL SAFETY CHECK DIRECTLY BEFORE OrderSend.
   // Even if any logic path bypasses CanOpenNewOrder(), no 3rd order can be sent.
   int openOrders = CountAllSymbolMarketOrders();
   if(openOrders >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDERSEND BLOCKED | Max open orders reached. Symbol=", Symbol(),
            " Open=", openOrders,
            " Max=", DXB_HARD_MAX_OPEN_ORDERS,
            " Reason=", reason);
      DrawDashboard("ORDERSEND BLOCKED - MAX 2 ORDERS");
      return(false);
   }

   int type = direction == 1 ? OP_BUY : OP_SELL;
   double price = direction == 1 ? Ask : Bid;
   double sl = 0;

   if(InpStopLossPoints > 0)
   {
      if(direction == 1) sl = NormalizeDouble(price - InpStopLossPoints * Point, Digits);
      else               sl = NormalizeDouble(price + InpStopLossPoints * Point, Digits);
   }

   double lot = NormalizeLot(InpFixedLot);

   // Re-check immediately before OrderSend after lot/SL calculations.
   RefreshRates();
   if(CountAllSymbolMarketOrders() >= DXB_HARD_MAX_OPEN_ORDERS)
   {
      Print("ORDERSEND CANCELLED LAST CHECK | Open=", CountAllSymbolMarketOrders(),
            " Max=", DXB_HARD_MAX_OPEN_ORDERS);
      return(false);
   }

   int ticket = OrderSend(Symbol(), type, lot, price, InpSlippage, sl, 0, reason, InpMagicNumber, 0, direction == 1 ? InpBuyColor : InpSellColor);

   if(ticket < 0)
   {
      int err = GetLastError();
      Print("OrderSend failed. Direction=", DirectionText(direction), " Error=", err);
      ResetLastError();
      return(false);
   }

   g_lastOrderTime = TimeCurrent();
   Print("Opened ", DirectionText(direction), " ticket=", ticket,
         " lot=", DoubleToString(lot, 2),
         " reason=", reason,
         " | TotalSymbolOrders=", CountAllSymbolMarketOrders(),
         "/", DXB_HARD_MAX_OPEN_ORDERS);
   return(true);
}
//+------------------------------------------------------------------+
double NormalizeLot(double lot)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   lot = MathMax(minLot, MathMin(maxLot, lot));
   if(lotStep > 0)
      lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
}
//+------------------------------------------------------------------+
int CountAllOrders()
{
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber)
      {
         if(OrderType() == OP_BUY || OrderType() == OP_SELL)
            total++;
      }
   }
   return total;
}
//+------------------------------------------------------------------+
int CountAllSymbolMarketOrders()
{
   int total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
      {
         total++;
      }
   }

   return(total);
}
//+------------------------------------------------------------------+
int CountOrdersByDirection(int direction)
{
   int type = direction == 1 ? OP_BUY : OP_SELL;
   int total = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type)
         total++;
   }
   return total;
}
//+------------------------------------------------------------------+
double GetBasketProfit(int direction)
{
   int type = direction == 1 ? OP_BUY : OP_SELL;
   double profit = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == InpMagicNumber && OrderType() == type)
         profit += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return profit;
}
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newDirection, string reason)
{
   int closeType = newDirection == 1 ? OP_SELL : OP_BUY;
   CloseOrdersByType(closeType, reason);
}
//+------------------------------------------------------------------+
void CloseOrdersByDirection(int direction, string reason)
{
   int type = direction == 1 ? OP_BUY : OP_SELL;
   CloseOrdersByType(type, reason);
}
//+------------------------------------------------------------------+
void CloseOrdersByType(int type, string reason)
{
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != type) continue;

      double closePrice = type == OP_BUY ? Bid : Ask;
      bool ok = OrderClose(OrderTicket(), OrderLots(), closePrice, InpSlippage, clrWhite);

      if(!ok)
      {
         int err = GetLastError();
         Print("Close failed. Ticket=", OrderTicket(), " reason=", reason, " error=", err);
         ResetLastError();
      }
      else
      {
         Print("Closed ticket=", OrderTicket(), " reason=", reason);
      }
   }
}
//+------------------------------------------------------------------+
void DrawSARDots()
{
   if(!InpDrawSARDots)
      return;

   double step    = InpSARPeriod * InpSARStepSize / 10000.0;
   double maxstep = step * InpSARAcceleration;

   int lookback = MathMin(InpSARDotLookback, Bars - 1);
   if(lookback <= 0)
      return;

   for(int i = 0; i < lookback; i++)
   {
      double sar = iSAR(Symbol(), Period(), step, maxstep, i);
      if(sar <= 0)
         continue;

      string name = OBJ_PREFIX + "SAR_DOT_" + IntegerToString(i);

      if(ObjectFind(0, name) < 0)
      {
         ObjectCreate(0, name, OBJ_ARROW, 0, Time[i], sar);
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159); // small dot
         ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, name, OBJPROP_BACK, true);
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_TIME, Time[i]);
         ObjectSetDouble(0, name, OBJPROP_PRICE, sar);
      }

      // Color based on SAR position relative to candle close.
      if(sar < Close[i])
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotBuyColor);
         if(i == 0)
            dotColor = 1;
      }
      else
      {
         ObjectSetInteger(0, name, OBJPROP_COLOR, InpSARDotSellColor);
         if(i == 0)
            dotColor = -1;
      }
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DrawSignalArrow(string tag, int direction, datetime t, double price, bool early)
{
   string name = OBJ_PREFIX + tag + "_" + IntegerToString((int)t) + "_" + IntegerToString(direction);
   if(ObjectFind(0, name) >= 0) return;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, direction == 1 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, early ? (direction == 1 ? InpEarlyBuyColor : InpEarlySellColor) : (direction == 1 ? InpBuyColor : InpSellColor));
   ObjectSetInteger(0, name, OBJPROP_WIDTH, early ? 2 : 3);
}
//+------------------------------------------------------------------+
string DirectionText(int direction)
{
   if(direction == 1)  return "BUY";
   if(direction == -1) return "SELL";
   return "NONE";
}
//+------------------------------------------------------------------+
void DrawDashboard(string status)
{
   string msg = "";
   msg += InpEAName + "\n";
   msg += "Status: " + status + "\n";
   msg += "SAR Direction: " + DirectionText(g_activeSARDirection) + "\n";
   msg += "Early Direction: " + DirectionText(g_earlyDirection) + "\n";
   msg += "Paused by Early: " + (g_sarPausedByEarly ? "YES" : "NO") + "\n";
   msg += "Flat Mode: " + (g_flatMode ? "YES" : "NO") + "\n";
   msg += "BUY Orders: " + IntegerToString(CountOrdersByDirection(1)) + " | Profit: $" + DoubleToString(GetBasketProfit(1), 2) + "\n";
   msg += "SELL Orders: " + IntegerToString(CountOrdersByDirection(-1)) + " | Profit: $" + DoubleToString(GetBasketProfit(-1), 2) + "\n";
   msg += "EA Orders: " + IntegerToString(CountAllOrders()) + " | Symbol Orders: " + IntegerToString(CountAllSymbolMarketOrders()) + " / " + IntegerToString(DXB_HARD_MAX_OPEN_ORDERS) + "\n";
   msg += "Basket TP: $" + DoubleToString(InpBasketProfitUSD, 2) + " | Lot: " + DoubleToString(InpFixedLot, 2) + "\n";
   Comment(msg);
}
//+------------------------------------------------------------------+
