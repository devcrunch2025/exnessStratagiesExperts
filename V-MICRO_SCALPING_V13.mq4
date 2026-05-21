#property strict

/*
   BTCUSD 3-Momentum Basket Scalper EA
   ------------------------------------------------------------
   TYPE 1: BIG MOMENTUM
      - Big move over BigMoveMinPrice in BigMoveLookbackBars
      - Opens reverse order:
          BIG UP   -> BIG_SELL
          BIG DOWN -> BIG_BUY

   TYPE 2: RANGE / SMALL MOMENTUM
      - Price oscillates inside RangeMinPrice..RangeMaxPrice over RangeLookbackBars
      - Opens small BUY/SELL baskets and recovery orders

   TYPE 3: TREND MOMENTUM
      - M5 EMA9/EMA21 trend direction
      - Opens trend BUY/SELL baskets

   Basket close is separated by comment:
      BIG_BUY, BIG_SELL
      RANGE_BUY, RANGE_SELL
      TREND_BUY, TREND_SELL
*/

extern double BaseLot = 0.01;
extern int    MagicNumber = 20260522;

// Basket TP/SL per mode
extern double BigBasketTPUSD   = 0.50;
extern double BigBasketSLUSD   = -20.00;

extern double RangeBasketTPUSD = 0.50;
extern double RangeBasketSLUSD = -20.00;

extern double TrendBasketTPUSD = 0.50;
extern double TrendBasketSLUSD = -20.00;

// Max orders per basket comment
extern int MaxBigOrdersPerSide   = 2;
extern int MaxRangeOrdersPerSide = 5;
extern int MaxTrendOrdersPerSide = 5;

extern int MaxSpreadPoints = 5000;
extern int Slippage = 100;

// Timeframes
extern ENUM_TIMEFRAMES TradeTF = PERIOD_M1;
extern ENUM_TIMEFRAMES TrendTF = PERIOD_M5;

// EMA trend
extern int TrendFastEMA = 9;
extern int TrendSlowEMA = 21;
extern double MinTrendEMAGap = 30.0;

// Candle filters
extern double MinCandleSize = 20.0;
extern double MaxTrendOrderCandleSize = 100.0;

// Big momentum detection
extern bool   UseBigMomentum = true;
extern int    BigMoveLookbackBars = 3;
extern double BigMoveMinPrice = 150.0;
extern double BigMomentumLot = 0.01;
extern bool   OnlyOneBigMoveOrderPerBar = true;

// Range momentum detection
extern bool   UseRangeMomentum = true;
extern int    RangeLookbackBars = 5;
extern double RangeMinPrice = 50.0;
extern double RangeMaxPrice = 180.0;
extern double RangeOrderGapPrice = 80.0;

// Trend momentum
extern bool   UseTrendMomentum = true;
extern double TrendOrderGapPrice = 150.0;

// Recovery
extern bool   UseRecoveryOrders = true;
extern double RecoveryGapPrice = 300.0;
extern int    MaxRecoveryOrdersPerBasket = 4;
extern bool   RecoverySameDirection = true;

// Safety
extern bool UseEquityProtection = true;
extern double MinEquityPercent = 60.0; // close all if equity <= balance * 60%

// Dashboard + EMA
extern bool DrawEMALines = true;
extern int  EMABarsToDraw = 120;
extern color EMAFastColor = clrLime;
extern color EMASlowColor = clrRed;

// Globals
datetime lastBarTime = 0;
datetime lastBigMoveBarTime = 0;
datetime lastBigMoveTradeTime = 0;
int      lastBigMoveDirection = 0; // 1 big up, -1 big down

// Mode constants
#define MODE_NONE  0
#define MODE_BIG   1
#define MODE_RANGE 2
#define MODE_TREND 3

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BTCUSD 3-Momentum Basket Scalper EA Started");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "BOT_EMA_FAST_");
   ObjectsDeleteAll(0, "BOT_EMA_SLOW_");
   ObjectsDeleteAll(0, "DASH_");
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   UpdateBigMoveStatus();
   DrawBotEMALines();
   DrawDashboard();

   if(!IsTradeAllowed())
      return;

   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpreadPoints)
      return;

   if(UseEquityProtection)
      CheckEquityProtection();

   CheckAllSeparateBasketClose();

   if(UseRecoveryOrders)
      CheckAllRecoveryOrders();

   ProcessNewBarLogic();
}

//+------------------------------------------------------------------+
void ProcessNewBarLogic()
{
   datetime currentBar = iTime(Symbol(), TradeTF, 0);

   if(currentBar == lastBarTime)
      return;

   lastBarTime = currentBar;

   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double candleSize = MathAbs(close1 - open1);

   if(candleSize < MinCandleSize)
   {
      Print("No order: candle too small. Size=", candleSize);
      return;
   }

   int mode = DetectMarketMode();

   if(mode == MODE_BIG)
   {
      ProcessBigMomentum();
      return;
   }

   if(mode == MODE_RANGE)
   {
      ProcessRangeMomentum();
      return;
   }

   if(mode == MODE_TREND)
   {
      ProcessTrendMomentum();
      return;
   }

   Print("No order: no clear BTC momentum mode.");
}

//+------------------------------------------------------------------+
int DetectMarketMode()
{
   if(UseBigMomentum && DetectBigMoveDirection() != 0)
      return MODE_BIG;

   if(UseRangeMomentum && IsRangeMomentum())
      return MODE_RANGE;

   if(UseTrendMomentum && GetTrendDirection() != 0)
      return MODE_TREND;

   return MODE_NONE;
}

//+------------------------------------------------------------------+
// TYPE 1: Big momentum reversal
//+------------------------------------------------------------------+
void ProcessBigMomentum()
{
   if(lastBigMoveDirection == 0)
      return;

   if(OnlyOneBigMoveOrderPerBar && lastBigMoveTradeTime == lastBigMoveBarTime)
      return;

   // Big UP -> reverse SELL
   if(lastBigMoveDirection == 1)
   {
      if(CountOrdersByComment("BIG_SELL") >= MaxBigOrdersPerSide)
         return;

      OpenOrder(OP_SELL, BigMomentumLot, "BIG_SELL");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
   }

   // Big DOWN -> reverse BUY
   if(lastBigMoveDirection == -1)
   {
      if(CountOrdersByComment("BIG_BUY") >= MaxBigOrdersPerSide)
         return;

      OpenOrder(OP_BUY, BigMomentumLot, "BIG_BUY");
      lastBigMoveTradeTime = lastBigMoveBarTime;
      return;
   }
}

//+------------------------------------------------------------------+
// TYPE 2: Range/small momentum with separate small baskets
//+------------------------------------------------------------------+
void ProcessRangeMomentum()
{
   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);

   // bullish small candle -> RANGE_BUY
   if(close1 > open1)
   {
      if(CountOrdersByComment("RANGE_BUY") >= MaxRangeOrdersPerSide)
         return;

      if(!CanOpenByGap("RANGE_BUY", RangeOrderGapPrice))
         return;

      OpenOrder(OP_BUY, BaseLot, "RANGE_BUY");
      return;
   }

   // bearish small candle -> RANGE_SELL
   if(close1 < open1)
   {
      if(CountOrdersByComment("RANGE_SELL") >= MaxRangeOrdersPerSide)
         return;

      if(!CanOpenByGap("RANGE_SELL", RangeOrderGapPrice))
         return;

      OpenOrder(OP_SELL, BaseLot, "RANGE_SELL");
      return;
   }
}

//+------------------------------------------------------------------+
// TYPE 3: Trend momentum with M5 EMA9/EMA21
//+------------------------------------------------------------------+
void ProcessTrendMomentum()
{
   double open1  = iOpen(Symbol(), TradeTF, 1);
   double close1 = iClose(Symbol(), TradeTF, 1);
   double candleSize = MathAbs(close1 - open1);

   // avoid chasing a huge candle in trend mode
   if(candleSize >= MaxTrendOrderCandleSize)
   {
      Print("Trend order blocked: big candle size=", candleSize);
      return;
   }

   int trend = GetTrendDirection();

   if(trend == 1)
   {
      if(CountOrdersByComment("TREND_BUY") >= MaxTrendOrdersPerSide)
         return;

      if(!CanOpenByGap("TREND_BUY", TrendOrderGapPrice))
         return;

      OpenOrder(OP_BUY, BaseLot, "TREND_BUY");
      return;
   }

   if(trend == -1)
   {
      if(CountOrdersByComment("TREND_SELL") >= MaxTrendOrdersPerSide)
         return;

      if(!CanOpenByGap("TREND_SELL", TrendOrderGapPrice))
         return;

      OpenOrder(OP_SELL, BaseLot, "TREND_SELL");
      return;
   }
}

//+------------------------------------------------------------------+
void UpdateBigMoveStatus()
{
   int dir = DetectBigMoveDirection();

   if(dir == 0)
      return;

   datetime moveTime = iTime(Symbol(), TradeTF, 1);

   if(moveTime == lastBigMoveBarTime && dir == lastBigMoveDirection)
      return;

   lastBigMoveDirection = dir;
   lastBigMoveBarTime = moveTime;

   Print("BIG MOMENTUM FOUND: ",
         dir == 1 ? "BIG UP -> BIG_SELL ready" : "BIG DOWN -> BIG_BUY ready");
}

//+------------------------------------------------------------------+
int DetectBigMoveDirection()
{
   double firstOpen = iOpen(Symbol(), TradeTF, BigMoveLookbackBars);
   double lastClose = iClose(Symbol(), TradeTF, 1);

   if(firstOpen <= 0 || lastClose <= 0)
      return 0;

   double move = lastClose - firstOpen;

   if(move >= BigMoveMinPrice)
      return 1;

   if(move <= -BigMoveMinPrice)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool IsRangeMomentum()
{
   double highest = iHigh(Symbol(), TradeTF, 1);
   double lowest  = iLow(Symbol(), TradeTF, 1);

   for(int i = 1; i <= RangeLookbackBars; i++)
   {
      highest = MathMax(highest, iHigh(Symbol(), TradeTF, i));
      lowest  = MathMin(lowest,  iLow(Symbol(), TradeTF, i));
   }

   double range = highest - lowest;

   if(range >= RangeMinPrice && range <= RangeMaxPrice)
      return true;

   return false;
}

//+------------------------------------------------------------------+
int GetTrendDirection()
{
   double emaFast = iMA(Symbol(), TrendTF, TrendFastEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaSlow = iMA(Symbol(), TrendTF, TrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE, 1);
   double close1  = iClose(Symbol(), TrendTF, 1);

   double emaGap = MathAbs(emaFast - emaSlow);

   if(emaGap < MinTrendEMAGap)
      return 0;

   if(close1 > emaFast && emaFast > emaSlow)
      return 1;

   if(close1 < emaFast && emaFast < emaSlow)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
bool CanOpenByGap(string commentText, double gapPrice)
{
   double lastPrice = GetLastOrderPriceByComment(commentText);

   if(lastPrice <= 0)
      return true;

   double distance = MathAbs(Bid - lastPrice);

   if(distance >= gapPrice)
      return true;

   return false;
}

//+------------------------------------------------------------------+
void CheckAllRecoveryOrders()
{
   CheckRecoveryByComment("BIG_BUY",    OP_BUY,  MaxBigOrdersPerSide);
   CheckRecoveryByComment("BIG_SELL",   OP_SELL, MaxBigOrdersPerSide);

   CheckRecoveryByComment("RANGE_BUY",  OP_BUY,  MaxRangeOrdersPerSide);
   CheckRecoveryByComment("RANGE_SELL", OP_SELL, MaxRangeOrdersPerSide);

   CheckRecoveryByComment("TREND_BUY",  OP_BUY,  MaxTrendOrdersPerSide);
   CheckRecoveryByComment("TREND_SELL", OP_SELL, MaxTrendOrdersPerSide);
}

//+------------------------------------------------------------------+
//| Recovery allowed only in same market mode                        |
//+------------------------------------------------------------------+
bool IsRecoveryAllowedForBasket(string commentText)
{
   int mode = DetectMarketMode();

   if(StringFind(commentText, "BIG_") == 0)
   {
      if(mode == MODE_BIG)
         return true;

      return false;
   }

   if(StringFind(commentText, "RANGE_") == 0)
   {
      if(mode == MODE_RANGE)
         return true;

      return false;
   }

   if(StringFind(commentText, "TREND_") == 0)
   {
      if(mode == MODE_TREND)
         return true;

      return false;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Replace old CheckRecoveryByComment() with this                   |
//+------------------------------------------------------------------+
void CheckRecoveryByComment(string commentText, int type, int maxOrders)
{
   // IMPORTANT:
   // TREND recovery only in TREND mode
   // RANGE recovery only in RANGE mode
   // BIG recovery only in BIG mode
   if(!IsRecoveryAllowedForBasket(commentText))
   {
      Print("Recovery blocked. Basket=", commentText,
            " Current Mode=", ModeText());
      return;
   }

   int count = CountOrdersByComment(commentText);

   if(count <= 0)
      return;

   if(count >= maxOrders)
      return;

   if(CountRecoveryOrdersByComment(commentText) >= MaxRecoveryOrdersPerBasket)
      return;

   double profit = GetBasketProfitByComment(commentText);

   if(profit >= 0)
      return;

   double lastPrice = GetLastOrderPriceByComment(commentText);

   if(lastPrice <= 0)
      return;

   double distance = MathAbs(Bid - lastPrice);

   if(distance < RecoveryGapPrice)
      return;

   double lot = GetRecoveryLotByComment(commentText);

   int recoveryType = type;

   if(!RecoverySameDirection)
   {
      if(type == OP_BUY)
         recoveryType = OP_SELL;
      else
         recoveryType = OP_BUY;
   }

   OpenOrder(recoveryType, lot, commentText + "_RECOVERY");
}

//+------------------------------------------------------------------+
void CheckRecoveryByCommentOLD(string commentText, int type, int maxOrders)
{
   int count = CountOrdersByComment(commentText);

   if(count <= 0)
      return;

   if(count >= maxOrders)
      return;

   if(CountRecoveryOrdersByComment(commentText) >= MaxRecoveryOrdersPerBasket)
      return;

   double profit = GetBasketProfitByComment(commentText);

   if(profit >= 0)
      return;

   double lastPrice = GetLastOrderPriceByComment(commentText);

   if(lastPrice <= 0)
      return;

   double distance = MathAbs(Bid - lastPrice);

   if(distance < RecoveryGapPrice)
      return;

   double lot = GetRecoveryLotByComment(commentText);

   int recoveryType = type;

   if(!RecoverySameDirection)
   {
      if(type == OP_BUY)
         recoveryType = OP_SELL;
      else
         recoveryType = OP_BUY;
   }

   OpenOrder(recoveryType, lot, commentText + "_RECOVERY");
}

//+------------------------------------------------------------------+
double GetRecoveryLotByComment(string commentText)
{
   int recoveryCount = CountRecoveryOrdersByComment(commentText);

   if(recoveryCount == 0) return BaseLot;
   if(recoveryCount == 1) return BaseLot;
   if(recoveryCount == 2) return BaseLot * 2;
   if(recoveryCount == 3) return BaseLot * 2;

   return BaseLot * 3;
}

//+------------------------------------------------------------------+
void OpenOrder(int type, double lot, string commentText)
{
   RefreshRates();

   if(AccountFreeMarginCheck(Symbol(), type, lot) <= 0)
   {
      Print("Not enough margin for ", commentText, " lot=", lot);
      return;
   }

   double price = type == OP_BUY ? Ask : Bid;
   color clr = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          commentText, MagicNumber, 0, clr);

   if(ticket > 0)
   {
      Print("Opened ", type == OP_BUY ? "BUY " : "SELL ",
            " Lot=", lot,
            " Comment=", commentText,
            " Ticket=", ticket);
   }
   else
   {
      Print("OrderSend failed. Error=", GetLastError(), " Comment=", commentText);
   }
}

//+------------------------------------------------------------------+
void CheckAllSeparateBasketClose()
{
   CheckBasketComment("BIG_BUY",    BigBasketTPUSD,   BigBasketSLUSD);
   CheckBasketComment("BIG_SELL",   BigBasketTPUSD,   BigBasketSLUSD);

   CheckBasketComment("RANGE_BUY",  RangeBasketTPUSD, RangeBasketSLUSD);
   CheckBasketComment("RANGE_SELL", RangeBasketTPUSD, RangeBasketSLUSD);

   CheckBasketComment("TREND_BUY",  TrendBasketTPUSD, TrendBasketSLUSD);
   CheckBasketComment("TREND_SELL", TrendBasketTPUSD, TrendBasketSLUSD);
}

//+------------------------------------------------------------------+
void CheckBasketComment(string commentText, double tp, double sl)
{
   if(CountOrdersByComment(commentText) <= 0)
      return;

   double profit = GetBasketProfitByComment(commentText);

   if(profit >= tp)
   {
      Print(commentText, " TP close. Profit=", profit);
      CloseOrdersByComment(commentText);
      return;
   }

   if(profit <= sl)
   {
      Print(commentText, " SL close. Profit=", profit);
      CloseOrdersByComment(commentText);
      return;
   }
}

//+------------------------------------------------------------------+
double GetBasketProfitByComment(string commentText)
{
   double total = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText))
               total += OrderProfit() + OrderSwap() + OrderCommission();
         }
      }
   }

   return total;
}

//+------------------------------------------------------------------+
int CountOrdersByComment(string commentText)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText))
               count++;
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
int CountRecoveryOrdersByComment(string commentText)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText) &&
               StringFind(OrderComment(), "RECOVERY") >= 0)
               count++;
         }
      }
   }

   return count;
}

//+------------------------------------------------------------------+
bool IsCommentBasketMatch(string orderComment, string basketComment)
{
   // Matches exact basket comment and basket recovery comment.
   // Example: TREND_BUY and TREND_BUY_RECOVERY
   if(orderComment == basketComment)
      return true;

   if(StringFind(orderComment, basketComment + "_RECOVERY") == 0)
      return true;

   return false;
}

//+------------------------------------------------------------------+
double GetLastOrderPriceByComment(string commentText)
{
   datetime lastTime = 0;
   double price = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText))
            {
               if(OrderOpenTime() > lastTime)
               {
                  lastTime = OrderOpenTime();
                  price = OrderOpenPrice();
               }
            }
         }
      }
   }

   return price;
}

//+------------------------------------------------------------------+
void CloseOrdersByComment(string commentText)
{
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() &&
            OrderMagicNumber() == MagicNumber)
         {
            if(IsCommentBasketMatch(OrderComment(), commentText))
            {
               bool closed = false;

               if(OrderType() == OP_BUY)
                  closed = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrBlue);

               if(OrderType() == OP_SELL)
                  closed = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrRed);

               if(!closed)
                  Print("Close failed Ticket=", OrderTicket(), " Error=", GetLastError());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
void CheckEquityProtection()
{
   double limit = AccountBalance() * MinEquityPercent / 100.0;

   if(AccountEquity() <= limit)
   {
      Print("Equity protection triggered. Closing all EA orders.");
      CloseAllEAOrders();
   }
}

//+------------------------------------------------------------------+
void CloseAllEAOrders()
{
   CloseOrdersByComment("BIG_BUY");
   CloseOrdersByComment("BIG_SELL");
   CloseOrdersByComment("RANGE_BUY");
   CloseOrdersByComment("RANGE_SELL");
   CloseOrdersByComment("TREND_BUY");
   CloseOrdersByComment("TREND_SELL");
}

//+------------------------------------------------------------------+
int CurrentMode()
{
   return DetectMarketMode();
}

//+------------------------------------------------------------------+
string ModeText()
{
   int mode = CurrentMode();

   if(mode == MODE_BIG)   return "BIG MOMENTUM";
   if(mode == MODE_RANGE) return "RANGE MOMENTUM";
   if(mode == MODE_TREND) return "TREND MOMENTUM";

   return "WAIT";
}

//+------------------------------------------------------------------+
void DrawBotEMALines()
{
   if(!DrawEMALines)
      return;

   DrawEMA("BOT_EMA_FAST", TrendFastEMA, EMAFastColor);
   DrawEMA("BOT_EMA_SLOW", TrendSlowEMA, EMASlowColor);
}

//+------------------------------------------------------------------+
void DrawEMA(string name, int period, color clr)
{
   for(int i = EMABarsToDraw; i >= 1; i--)
   {
      string objName = name + "_" + IntegerToString(i);

      datetime t1 = iTime(Symbol(), TrendTF, i);
      datetime t2 = iTime(Symbol(), TrendTF, i - 1);

      double p1 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i);
      double p2 = iMA(Symbol(), TrendTF, period, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_TREND, 0, t1, p1, t2, p2);
         ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
         ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, objName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      }
      else
      {
         ObjectMove(0, objName, 0, t1, p1);
         ObjectMove(0, objName, 1, t2, p2);
      }
   }
}

//+------------------------------------------------------------------+
// Dashboard helpers
//+------------------------------------------------------------------+
void DrawLabel(string name, string text, int x, int y, color clr, int fontSize = 8)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
void DrawPanel(string name, int x, int y, int w, int h, color bg)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   }

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
}

//+------------------------------------------------------------------+
void DrawDashRow(string label, string value, int row, color labelColor, color valueColor)
{
   int baseX = 350;
   int baseY = 25;
   int lineH = 15;

   DrawLabel("DASH_L_" + IntegerToString(row), label, baseX, baseY + row * lineH, labelColor);
   DrawLabel("DASH_V_" + IntegerToString(row), value, baseX - 170, baseY + row * lineH, valueColor);
}

//+------------------------------------------------------------------+
void DrawDashboard()
{
   DrawPanel("DASH_BG_PANEL", 365, 15, 360, 520, clrBlack);

   DrawLabel("DASH_TITLE", "BTC 3-MOMENTUM BASKET EA", 345, 20, clrYellow, 9);

   DrawDashRow("MODE", ModeText(), 2, clrOrange, clrWhite);

   DrawDashRow("BIG BUY",    "$" + DoubleToString(GetBasketProfitByComment("BIG_BUY"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("BIG_BUY")) + ")", 4, clrDeepSkyBlue, clrWhite);
   DrawDashRow("BIG SELL",   "$" + DoubleToString(GetBasketProfitByComment("BIG_SELL"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("BIG_SELL")) + ")", 5, clrOrangeRed, clrWhite);

   DrawDashRow("RANGE BUY",  "$" + DoubleToString(GetBasketProfitByComment("RANGE_BUY"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("RANGE_BUY")) + ")", 7, clrDeepSkyBlue, clrWhite);
   DrawDashRow("RANGE SELL", "$" + DoubleToString(GetBasketProfitByComment("RANGE_SELL"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("RANGE_SELL")) + ")", 8, clrOrangeRed, clrWhite);

   DrawDashRow("TREND BUY",  "$" + DoubleToString(GetBasketProfitByComment("TREND_BUY"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("TREND_BUY")) + ")", 10, clrDeepSkyBlue, clrWhite);
   DrawDashRow("TREND SELL", "$" + DoubleToString(GetBasketProfitByComment("TREND_SELL"), 2) +
                              " (" + IntegerToString(CountOrdersByComment("TREND_SELL")) + ")", 11, clrOrangeRed, clrWhite);

   int trend = GetTrendDirection();
   string trendText = "WAIT";
   color trendColor = clrYellow;

   if(trend == 1) { trendText = "M5 BUY"; trendColor = clrLime; }
   if(trend == -1){ trendText = "M5 SELL"; trendColor = clrRed; }

   string bigText = "NO";
   if(lastBigMoveDirection == 1) bigText = "BIG UP -> SELL";
   if(lastBigMoveDirection == -1) bigText = "BIG DOWN -> BUY";

   DrawDashRow("TREND", trendText, 13, clrYellow, trendColor);
   DrawDashRow("BIG MOVE", bigText, 14, clrYellow, clrWhite);

   DrawDashRow("TP", "$0.50 each basket", 16, clrLime, clrLime);
   DrawDashRow("SL", "$20 each basket", 17, clrRed, clrRed);

   DrawDashRow("Base Lot", DoubleToString(BaseLot, 2), 19, clrOrange, clrYellow);
   DrawDashRow("Recovery Gap", DoubleToString(RecoveryGapPrice, 2), 20, clrOrange, clrYellow);
   DrawDashRow("Big Trigger", DoubleToString(BigMoveMinPrice, 2), 21, clrOrange, clrYellow);
   DrawDashRow("Range", DoubleToString(RangeMinPrice,0) + "-" + DoubleToString(RangeMaxPrice,0), 22, clrOrange, clrYellow);

   DrawDashRow("Balance", "$" + DoubleToString(AccountBalance(), 2), 24, clrWhite, clrWhite);
   DrawDashRow("Equity", "$" + DoubleToString(AccountEquity(), 2), 25, clrWhite, clrWhite);
   DrawDashRow("Free Margin", "$" + DoubleToString(AccountFreeMargin(), 2), 26, clrWhite, clrWhite);
   DrawDashRow("Spread", DoubleToString(MarketInfo(Symbol(), MODE_SPREAD), 0), 27, clrWhite, clrYellow);

   DrawLabel("DASH_STATUS", "RUNNING 24/7 - THREE BTC MOMENTUM MODES", 345, 510, clrLime, 8);
}
