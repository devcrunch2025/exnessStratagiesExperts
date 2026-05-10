//+------------------------------------------------------------------+
//| _Gap_Recovery_OneDirection_EA.mq4                                |
//| Price Difference Recovery Version                                |
//+------------------------------------------------------------------+
#property strict

input double LOTValue      = 0.01;
input double StopLossValue = 100.00;
input double TPValue       = 2.00;
input double GapPriceInput = 70.0;

double BaseLot             = 0.01;
double GapPrice            = 50.0;
int    MagicNumber         = 5050801;
int    Slippage            = 70;

double BasketProfitTarget  = 2.00;
double BasketStopLoss      = 100.00;

datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   MagicNumber = AccountNumber() + 4;

   BaseLot            = LOTValue;
   BasketProfitTarget = TPValue;
   BasketStopLoss     = StopLossValue;
   GapPrice           = GapPriceInput;

   GapPrice = GapPrice + (MathRand() % 11 - 5);

   Print("Gap Recovery EA Started | Price Difference Recovery");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   CloseBasketByProfit(OP_BUY);
   CloseBasketByProfit(OP_SELL);

   CheckNewBaseSignal();

   ManageRecovery(OP_BUY);
   ManageRecovery(OP_SELL);

   DrawDashboard();
   DrawEveryCandleDiffFrom5th();
}

//+------------------------------------------------------------------+
int GetBalanceMultiplier()
{
   double balance = AccountBalance();

   int multiplier = (int)MathCeil(balance / 200.0);

   if(multiplier < 1)
      multiplier = 1;

   return multiplier;
}

//+------------------------------------------------------------------+
double GetLot(double baseLot)
{
   double lot = baseLot * GetBalanceMultiplier();

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lot < minLot)
      lot = minLot;

   if(lot > maxLot)
      lot = maxLot;

   lot = MathFloor(lot / lotStep) * lotStep;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
double GetBasketTP()
{
   return BasketProfitTarget * GetBalanceMultiplier();
}

//+------------------------------------------------------------------+
double GetBasketSL()
{
   return BasketStopLoss * GetBalanceMultiplier();
}
double GetLiveM5Gap()
{
   RefreshRates();

   double open = iOpen(Symbol(), PERIOD_M5, 0);
   double live = Bid;

   return NormalizeDouble(live - open, 2);
}
//+------------------------------------------------------------------+
void CheckNewBaseSignal()
{
   datetime m5Time = iTime(Symbol(), PERIOD_M5, 1);

   if(m5Time == lastM5BarTime)
      return;

   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double gap   = close - open;

   if(CountOrders(OP_BUY) > 0 || CountOrders(OP_SELL) > 0)
   {
      lastM5BarTime = m5Time;
      return;
   }

   if(gap > GapPrice)
   {
      OpenOrder(OP_BUY, GetLot(BaseLot), MakeComment(OP_BUY, 0));
      lastM5BarTime = m5Time;
      return;
   }

   if(gap < -GapPrice)
   {
      OpenOrder(OP_SELL, GetLot(BaseLot), MakeComment(OP_SELL, 0));
      lastM5BarTime = m5Time;
      return;
   }

   lastM5BarTime = m5Time;
}

//+------------------------------------------------------------------+
//| RECOVERY ONLY BY PRICE DIFFERENCE FROM LATEST ORDER              |
//+------------------------------------------------------------------+
void ManageRecovery(int orderType)
{
   if(GetBaseOrderTime(orderType) <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(profit >= 0)
      return;

   int hour = TimeHour(TimeCurrent());

   double diff = GetLivePriceDiffFromLatestOrder(orderType);

   int currentStage = GetHighestStage(orderType);
   int nextStage    = currentStage + 1;

   double requiredGap = 0;
   double nextLot     = 0.01;

   bool nightSession = false;

   if(hour > 18 || hour < 4)
      nightSession = true;



   if(nightSession)
   {
      if(nextStage == 1) { requiredGap = 50;  nextLot = 0.01; }
      if(nextStage == 2) { requiredGap = 100;  nextLot = 0.02; }
      if(nextStage == 3) { requiredGap = 200;  nextLot = 0.03; }
      if(nextStage == 4) { requiredGap = 400; nextLot = 0.04; }
      if(nextStage == 5) { requiredGap = 700; nextLot = 0.05; }
      if(nextStage == 6) { requiredGap = 1000; nextLot = 0.06; }

      if(nextStage > 6)
         return;
   }
   else
   {
      if(nextStage == 1) { requiredGap = 20;  nextLot = 0.01; }
      if(nextStage == 2) { requiredGap = 50;  nextLot = 0.02; }
      if(nextStage == 3) { requiredGap = 80;  nextLot = 0.03; }
      if(nextStage == 4) { requiredGap = 100; nextLot = 0.04; }
      if(nextStage == 5) { requiredGap = 300; nextLot = 0.05; }
      if(nextStage == 6) { requiredGap = 500; nextLot = 0.06; }
      if(nextStage == 7) { requiredGap = 700; nextLot = 0.07; }
      if(nextStage == 8) { requiredGap = 1000; nextLot = 0.08; }

      if(nextStage > 8)
         return;
   }

   bool canRecover = false;

      requiredGap=requiredGap+30;


   // BUY recovery: price must move DOWN from latest BUY order
   if(orderType == OP_BUY && diff <= -requiredGap)
      canRecover = true;

   // SELL recovery: price must move UP from latest SELL order
   if(orderType == OP_SELL && diff >= requiredGap)
      canRecover = true;

   if(!canRecover)
      return;

   if(!StageExists(orderType, nextStage))
   {
      OpenOrder(orderType, GetLot(nextLot), MakeComment(orderType, nextStage));
   }
}

//+------------------------------------------------------------------+
double GetLivePriceDiffFromLatestOrder(int orderType)
{
   double latestPrice = 0;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(latestTime == 0 || OrderOpenTime() > latestTime)
      {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   if(latestPrice <= 0)
      return 0;

   RefreshRates();

   double livePrice = orderType == OP_BUY ? Bid : Ask;

   return NormalizeDouble(livePrice - latestPrice, 2);
}

//+------------------------------------------------------------------+
double GetLatestOrderPrice(int orderType)
{
   double latestPrice = 0;
   datetime latestTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(latestTime == 0 || OrderOpenTime() > latestTime)
      {
         latestTime  = OrderOpenTime();
         latestPrice = OrderOpenPrice();
      }
   }

   return latestPrice;
}

//+------------------------------------------------------------------+
int GetHighestStage(int orderType)
{
   int highestStage = -1;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      string cmt = OrderComment();

      for(int s = 0; s <= 20; s++)
      {
         if(cmt == MakeComment(orderType, s))
         {
            if(s > highestStage)
               highestStage = s;
         }
      }
   }

   return highestStage;
}

//+------------------------------------------------------------------+
double GetBaseOrderPrice(int orderType)
{
   datetime oldestTime = 0;
   double basePrice = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != orderType)
         continue;

      if(OrderComment() != MakeComment(orderType, 0))
         continue;

      if(oldestTime == 0 || OrderOpenTime() < oldestTime)
      {
         oldestTime = OrderOpenTime();
         basePrice  = OrderOpenPrice();
      }
   }

   return basePrice;
}

//+------------------------------------------------------------------+
void CloseBasketByProfit(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return;

   double basketProfit = GetBasketProfit(orderType);
   double dynamicTarget = GetDynamicBasketTarget(orderType);
   double dynamicSL = GetBasketSL();

   if(basketProfit <= -dynamicSL || basketProfit >= dynamicTarget)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;

         if(OrderSymbol() != Symbol())
            continue;

         if(OrderMagicNumber() != MagicNumber)
            continue;

         if(OrderType() != orderType)
            continue;

         RefreshRates();

         double closePrice = orderType == OP_BUY ? Bid : Ask;

         bool closed = OrderClose(OrderTicket(),
                                  OrderLots(),
                                  closePrice,
                                  Slippage,
                                  clrGreen);

         if(!closed)
         {
            Print("Basket close failed. Ticket: ",
                  OrderTicket(),
                  " Error: ",
                  GetLastError());
         }
      }

      Print("Basket closed. Type: ",
            orderType == OP_BUY ? "BUY" : "SELL",
            " Orders: ",
            openCount,
            " Profit: $",
            DoubleToString(basketProfit, 2),
            " TP: $",
            DoubleToString(dynamicTarget, 2),
            " SL: $",
            DoubleToString(dynamicSL, 2));
   }
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(),
                          type,
                          lot,
                          price,
                          Slippage,
                          0,
                          0,
                          comment,
                          MagicNumber,
                          0,
                          clr);

   if(ticket < 0)
   {
      Print("OrderSend failed. Error: ",
            GetLastError(),
            " Type: ",
            type,
            " Lot: ",
            lot,
            " Comment: ",
            comment);
      return false;
   }

   Print("Order opened: ",
         comment,
         " Lot: ",
         DoubleToString(lot, 2),
         " Ticket: ",
         ticket);

   return true;
}

//+------------------------------------------------------------------+
datetime GetBaseOrderTime(int orderType)
{
   datetime baseTime = 0;
   string tag = MakeComment(orderType, 0);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
      {
         baseTime = OrderOpenTime();
      }
   }

   return baseTime;
}

//+------------------------------------------------------------------+
bool StageExists(int orderType, int stage)
{
   string tag = MakeComment(orderType, stage);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType &&
         OrderComment() == tag)
      {
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
string MakeComment(int orderType, int stage)
{
   if(orderType == OP_BUY)
      return "V4_GAP_BUY_S" + IntegerToString(stage);

   return "V4_GAP_SELL_S" + IntegerToString(stage);
}

//+------------------------------------------------------------------+
int CountOrders(int orderType)
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
int CountAllOrders()
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
double GetBasketProfit(int orderType)
{
   double profit = 0;

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
double GetDynamicBasketTarget(int orderType)
{
   int openCount = CountOrders(orderType);

   if(openCount <= 0)
      return GetBasketTP();

   return GetBasketTP() / openCount;
}

//+------------------------------------------------------------------+
string GetActiveDirection()
{
   if(CountOrders(OP_BUY) > 0)
      return "BUY ONLY";

   if(CountOrders(OP_SELL) > 0)
      return "SELL ONLY";

   return "WAITING";
}

//+------------------------------------------------------------------+
double GetLastM5Gap()
{
   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);

   return close - open;
}

//+------------------------------------------------------------------+
double GetLastClosedCandleDiffFrom(int timeframe)
{
   RefreshRates();

   double livePrice = Bid;
   double oldPrice  = iClose(Symbol(), timeframe, 1);

   return NormalizeDouble(livePrice - oldPrice, 2);
}

//+------------------------------------------------------------------+
double GetLastClosedCandleDiffFrom5th()
{
   double lastClose  = iClose(Symbol(), PERIOD_M5, 1);
   double fifthClose = iClose(Symbol(), PERIOD_M5, 5);

   return NormalizeDouble(lastClose - fifthClose, 0);
}

//+------------------------------------------------------------------+
void CreatePanel(string name,int x,int y,int w,int h,color bg)
{
   if(ObjectFind(0,name) < 0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,h);

   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrSilver);
}

//+------------------------------------------------------------------+
void CreateLabel(string name,
                 string text,
                 int x,
                 int y,
                 color clr,
                 int size=10)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);

   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);

   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");

   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
}
void DrawEMA9AndEMA21Lines()
{
   int candles = 150;

   for(int i = candles; i >= 1; i--)
   {
      datetime t1 = iTime(Symbol(), PERIOD_CURRENT, i);
      datetime t2 = iTime(Symbol(), PERIOD_CURRENT, i - 1);

      if(t1 <= 0 || t2 <= 0)
         continue;

      double ema9_1  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema9_2  = iMA(Symbol(), PERIOD_CURRENT, 9, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      double ema21_1 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i);
      double ema21_2 = iMA(Symbol(), PERIOD_CURRENT, 21, 0, MODE_EMA, PRICE_CLOSE, i - 1);

      string name9  = "EMA9_LINE_" + IntegerToString(i);
      string name21 = "EMA21_LINE_" + IntegerToString(i);

      if(ObjectFind(0, name9) < 0)
         ObjectCreate(0, name9, OBJ_TREND, 0, t1, ema9_1, t2, ema9_2);
      else
      {
         ObjectMove(0, name9, 0, t1, ema9_1);
         ObjectMove(0, name9, 1, t2, ema9_2);
      }

      ObjectSetInteger(0, name9, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, name9, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name9, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name9, OBJPROP_SELECTABLE, false);

      if(ObjectFind(0, name21) < 0)
         ObjectCreate(0, name21, OBJ_TREND, 0, t1, ema21_1, t2, ema21_2);
      else
      {
         ObjectMove(0, name21, 0, t1, ema21_1);
         ObjectMove(0, name21, 1, t2, ema21_2);
      }

      ObjectSetInteger(0, name21, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name21, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, name21, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name21, OBJPROP_SELECTABLE, false);
   }
}
//+------------------------------------------------------------------+
void DrawDashboard()
{

   DrawEMA9AndEMA21Lines();
   int mult = GetBalanceMultiplier();

   double buyPL  = GetBasketProfit(OP_BUY);
   double sellPL = GetBasketProfit(OP_SELL);

   color buyClr  = buyPL >= 0 ? clrLime : clrTomato;
   color sellClr = sellPL >= 0 ? clrLime : clrTomato;

   string direction = GetActiveDirection();

   color dirClr = clrSilver;

   if(direction == "BUY ONLY")
      dirClr = clrLime;

   if(direction == "SELL ONLY")
      dirClr = clrTomato;

   double buyLatestPrice  = GetLatestOrderPrice(OP_BUY);
   double sellLatestPrice = GetLatestOrderPrice(OP_SELL);

   double buyLatestGap  = GetLivePriceDiffFromLatestOrder(OP_BUY);
   double sellLatestGap = GetLivePriceDiffFromLatestOrder(OP_SELL);

   CreatePanel("DXB_PANEL",300,10,380,530,C'15,15,15');

   CreateLabel("V4",
               "GAP V4 PRICE RECOVERY",
               210,30,
               clrGold,
               12);

   CreateLabel("DXB_BUYPL",
               "BUY Basket   : $" + DoubleToString(buyPL,2),
               290,50,
               buyClr);

   CreateLabel("DXB_SELLPL",
               "SELL Basket  : $" + DoubleToString(sellPL,2),
               290,70,
               sellClr);

   CreateLabel("DXB_BUYGAP",
               "BUY LatestGap: " + DoubleToString(buyLatestGap,2),
               290,90,
               buyLatestGap <= -20 ? clrLime : clrSilver);

   CreateLabel("DXB_SELLGAP",
               "SELL LatestG : " + DoubleToString(sellLatestGap,2),
               290,110,
               sellLatestGap >= 20 ? clrLime : clrSilver);

   CreateLabel("DXB_BUYLP",
               "BUY LastPrice: " + DoubleToString(buyLatestPrice,2),
               290,130,
               clrSilver);

   CreateLabel("DXB_SELLLP",
               "SELL LastPr  : " + DoubleToString(sellLatestPrice,2),
               290,150,
               clrSilver);

   CreateLabel("DXB_BAL",
               "Balance      : $" + DoubleToString(AccountBalance(),2),
               290,420,
               clrWhite);

   CreateLabel("DXB_EQ",
               "Equity       : $" + DoubleToString(AccountEquity(),2),
               290,440,
               clrWhite);

   CreateLabel("DXB_MULT",
               "Multiplier   : " + IntegerToString(mult) + "X",
               290,465,
               clrAqua);

   CreateLabel("DXB_LOT",
               "Base Lot     : " + DoubleToString(GetLot(BaseLot),2),
               290,175,
               clrOrange);
CreateLabel("DXB_GAP",
            "Closed M5 Gap: " + DoubleToString(GetLastM5Gap(),2),
            290,185,
            clrYellow);

CreateLabel("DXB_LIVE_M5_GAP",
            "Live M5 Gap  : " + DoubleToString(GetLiveM5Gap(),2),
            290,225,
            GetLiveM5Gap() >= 0 ? clrLime : clrTomato);
   CreateLabel("DXB_GAP",
               "M5 Gap       : " + DoubleToString(GetLastM5Gap(),2),
               290,195,
               clrYellow);

   CreateLabel("DXB_TRIGGER",
               "Gap Trigger  : " + DoubleToString(GapPrice,2),
               290,205,
               clrYellow);

   CreateLabel("DXB_DIR",
               "Direction    : " + direction,
               290,240,
               dirClr);

   CreateLabel("DXB_BUYORD",
               "BUY Orders   : " + IntegerToString(CountOrders(OP_BUY)),
               290,265,
               clrLime);

   CreateLabel("DXB_SELLORD",
               "SELL Orders  : " + IntegerToString(CountOrders(OP_SELL)),
               290,285,
               clrTomato);

   CreateLabel("DXB_TOTAL",
               "Total Orders : " + IntegerToString(CountAllOrders()),
               290,305,
               clrWhite);

   CreateLabel("DXB_BUYTP",
               "BUY TP       : $" + DoubleToString(GetDynamicBasketTarget(OP_BUY),2),
               290,330,
               clrDeepSkyBlue);

   CreateLabel("DXB_SELLTP",
               "SELL TP      : $" + DoubleToString(GetDynamicBasketTarget(OP_SELL),2),
               290,350,
               clrDeepSkyBlue);

   CreateLabel("DXB_SL",
               "Basket SL    : $" + DoubleToString(GetBasketSL(),2),
               290,375,
               clrOrangeRed);

   CreateLabel("DXB_STATUS",
               "RUNNING PRICE GAP RECOVERY",
               290,495,
               clrLime,
               10);
}

//+------------------------------------------------------------------+
void DrawEveryCandleDiffFrom5th()
{
   int candlesToDraw = 100;

   for(int shift = 1; shift <= candlesToDraw; shift++)
   {
      if(shift + 5 >= Bars)
         continue;

      datetime t = iTime(Symbol(), PERIOD_M5, shift);

      string name = "DIFF5_" + IntegerToString((int)t);

      double currentClose = iClose(Symbol(), PERIOD_M5, shift);
      double fifthClose   = iClose(Symbol(), PERIOD_M5, shift + 5);

      double diff = NormalizeDouble(currentClose - fifthClose, 2);

      if(MathAbs(diff) < 50)
         continue;

      color txtColor = diff >= 0 ? clrLime : clrRed;

      double high = iHigh(Symbol(), PERIOD_M5, shift);
      double low  = iLow(Symbol(), PERIOD_M5, shift);

      double candleRange = MathAbs(high - low);
      double spacing = candleRange * 0.8;

      if(spacing < Point * 200)
         spacing = Point * 200;

      double y;

      if(diff >= 0)
         y = high + spacing;
      else
         y = low - spacing;

      if(ObjectFind(0, name) >= 0)
         continue;

      ObjectCreate(0, name, OBJ_TEXT, 0, t, y);

      ObjectSetString(0, name, OBJPROP_TEXT, DoubleToString(diff, 0));
      ObjectSetInteger(0, name, OBJPROP_COLOR, txtColor);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
}
//+------------------------------------------------------------------+