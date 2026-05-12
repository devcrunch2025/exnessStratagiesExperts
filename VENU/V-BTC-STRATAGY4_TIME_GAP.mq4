//+------------------------------------------------------------------+
//| _Gap_Recovery_OneDirection_EA.mq4                            |
//| Balance multiplier + basket TP/SL                                |
//+------------------------------------------------------------------+
#property strict

    

input double LOTValue=0.01;
input double StopLossValue=50.00;
input double TPValue=2.00;

double BaseLot             = 0.01;
double GapPrice            = 70.0;
int    MagicNumber         = 5050801;
int    Slippage            = 50;

double BasketProfitTarget  = 2.00;   // Will be multiplied
 double BasketStopLoss      = 50.00;  // Will be multiplied

datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   MagicNumber = AccountNumber() + 4;

   Print("Gap Recovery One Direction EA Started");

 

BaseLot=LOTValue;
BasketProfitTarget=TPValue;
BasketStopLoss=StopLossValue;


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
   // multiplier=multiplier-1;

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
   return BasketStopLoss * (GetBalanceMultiplier());
}

//+------------------------------------------------------------------+
void CheckNewBaseSignal()
{

// GapPrice = 65 + MathRand() % 6;
GapPrice = 60 + MathRand() % 11;
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
      OpenOrder(OP_BUY, GetLot(BaseLot), "V4_TIME_GAP_BUY_S0");
      lastM5BarTime = m5Time;
      return;
   }

   if(gap < -GapPrice)
   {
      OpenOrder(OP_SELL, GetLot(BaseLot), "V4_TIME_GAP_SELL_S0");
      lastM5BarTime = m5Time;
      return;
   }

   lastM5BarTime = m5Time;
}

//+------------------------------------------------------------------+
void ManageRecovery(int orderType)
{
   datetime baseTime = GetBaseOrderTime(orderType);

   if(baseTime <= 0)
      return;

   double profit = GetBasketProfit(orderType);

   if(profit >= 0)
      return;

   int minutesPassed = (int)((TimeCurrent() - baseTime) / 60);

   datetime t = TimeCurrent();

int hour = TimeHour(t);

//  if(hour>18 || hour<4)
 {

   if(minutesPassed >= 2 && !StageExists(orderType, 1)  && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.01), MakeComment(orderType, 1));

   if(minutesPassed >= 5 && !StageExists(orderType, 2) && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.01), MakeComment(orderType, 2));

   if(minutesPassed >= 10 && !StageExists(orderType, 3) && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.02), MakeComment(orderType, 3));

   if(minutesPassed >= 30 && !StageExists(orderType, 4) && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.03), MakeComment(orderType, 4));

   if(minutesPassed >= 60 && !StageExists(orderType, 5) && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.04), MakeComment(orderType, 5));

       if(minutesPassed >= 90 && !StageExists(orderType, 6) && LatestOrderInLoss(orderType))
      OpenOrder(orderType, GetLot(0.05), MakeComment(orderType, 6));

 }
//  else
//  {
//    if(minutesPassed >= 2 && !StageExists(orderType, 1))
//       OpenOrder(orderType, 0.01, MakeComment(orderType, 1));

//    if(minutesPassed >= 5 && !StageExists(orderType, 2))
//       OpenOrder(orderType, 0.01, MakeComment(orderType, 2));

//    if(minutesPassed >= 10 && !StageExists(orderType, 3))
//       OpenOrder(orderType, 0.02, MakeComment(orderType, 3));

//    if(minutesPassed >= 15 && !StageExists(orderType, 4))
//       OpenOrder(orderType, 0.03, MakeComment(orderType, 4));

//       if(minutesPassed >= 20 && !StageExists(orderType, 4))
//       OpenOrder(orderType, 0.04, MakeComment(orderType, 4));

//    if(minutesPassed >= 30 && !StageExists(orderType, 5))
//       OpenOrder(orderType, GetLot(0.04), MakeComment(orderType, 5));

//        if(minutesPassed >= 60 && !StageExists(orderType, 6))
//       OpenOrder(orderType, GetLot(0.05), MakeComment(orderType, 6));

//       if(minutesPassed >= 90 && !StageExists(orderType, 7))
//       OpenOrder(orderType, GetLot(0.05), MakeComment(orderType, 7));
//  }
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

         bool closed = OrderClose(OrderTicket(), OrderLots(), closePrice, Slippage, clrGreen);

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

   return;
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{
   RefreshRates();

   double price = type == OP_BUY ? Ask : Bid;
   color clr    = type == OP_BUY ? clrBlue : clrRed;

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, 0, 0,
                          comment, MagicNumber, 0, clr);

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
   string tag = orderType == OP_BUY ? "V4_TIME_GAP_BUY_S0" : "V4_TIME_GAP_SELL_S0";

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
bool LatestOrderInLoss(int orderType)
{
   datetime latestTime = 0;
   double latestOpenPrice = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == MagicNumber &&
         OrderType() == orderType)
      {
         if(OrderOpenTime() > latestTime)
         {
            latestTime = OrderOpenTime();
            latestOpenPrice = OrderOpenPrice();
         }
      }
   }

   if(latestTime == 0)
      return false;

   RefreshRates();

   if(orderType == OP_BUY)
   {
      // BUY is loss when live Bid is below open price
      if(Bid+30 < latestOpenPrice)
         return true;
   }

   if(orderType == OP_SELL)
   {
      // SELL is loss when live Ask is above open price
      if(Ask-30 > latestOpenPrice)
         return true;
   }

   return false;
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
      return "V4_TIME_GAP_" + IntegerToString(stage);

   return "V4_TIME_GAP" + IntegerToString(stage);
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
void DrawDashboardOLD()
{
   string text =
      "GAP RECOVERY EA\n"
      "-----------------------------\n"
      "Symbol: " + Symbol() + "\n"
      "Balance: $" + DoubleToString(AccountBalance(), 2) + "\n"
      "Multiplier: " + IntegerToString(GetBalanceMultiplier()) + "X\n"
      "Base Lot: " + DoubleToString(GetLot(BaseLot), 2) + "\n"
      "Active Direction: " + GetActiveDirection() + "\n"
      "M5 Gap Trigger: +/- " + DoubleToString(GapPrice, 2) + "\n"
      "Last Closed M5 Gap: " + DoubleToString(GetLastM5Gap(), 2) + "\n"
      "Basket TP Base: $" + DoubleToString(BasketProfitTarget, 2) + "\n"
      "Basket TP Multiplied: $" + DoubleToString(GetBasketTP(), 2) + "\n"
      "Basket SL Multiplied: $" + DoubleToString(GetBasketSL(), 2) + "\n"
      "BUY Orders: " + IntegerToString(CountOrders(OP_BUY)) + "\n"
      "SELL Orders: " + IntegerToString(CountOrders(OP_SELL)) + "\n"
      "Total Orders: " + IntegerToString(CountAllOrders()) + "\n"
      "BUY Basket P/L: $" + DoubleToString(GetBasketProfit(OP_BUY), 2) + "\n"
      "SELL Basket P/L: $" + DoubleToString(GetBasketProfit(OP_SELL), 2) + "\n"
      "BUY Dynamic TP: $" + DoubleToString(GetDynamicBasketTarget(OP_BUY), 2) + "\n"
      "SELL Dynamic TP: $" + DoubleToString(GetDynamicBasketTarget(OP_SELL), 2) + "\n"
      "Rule: BUY open = no SELL | SELL open = no BUY\n"
      "Close Rule: Basket TP / Open Orders OR Basket SL";

   Comment(text);
}

//+------------------------------------------------------------------+
//| PROFESSIONAL DASHBOARD                                           |
//+------------------------------------------------------------------+
void CreatePanel(string name,int x,int y,int w,int h,color bg)
{
   if(ObjectFind(0,name) < 0)
   {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   }

   // ALWAYS update properties
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

//+------------------------------------------------------------------+
void DrawDashboard()
{
   int mult = GetBalanceMultiplier();

   double buyPL  = GetBasketProfit(OP_BUY);
   double sellPL = GetBasketProfit(OP_SELL);

   color buyClr  = buyPL >= 0 ? clrLime : clrTomato;
   color sellClr = sellPL >= 0 ? clrLime : clrTomato;

   string direction = GetActiveDirection();

   color dirClr = clrSilver;

   if(direction=="BUY ONLY")
      dirClr=clrLime;

   if(direction=="SELL ONLY")
      dirClr=clrTomato;

   // PANEL
CreatePanel("DXB_PANEL",300,10,380,470,C'15,15,15');   // TITLE
   CreateLabel("V4",
               "GAP V 4- Time",
               210,30,
               clrGold,
               12);

   CreateLabel("DXB_T2",
               "PROFESSIONAL VERSION",
               210,50,
               clrSilver,
               9);

   // BALANCE
   CreateLabel("DXB_BAL",
               "Balance      : $" + DoubleToString(AccountBalance(),2),
               290,80,
               clrWhite);

   CreateLabel("DXB_EQ",
               "Equity       : $" + DoubleToString(AccountEquity(),2),
               290,100,
               clrWhite);

   CreateLabel("DXB_MULT",
               "Multiplier   : " + IntegerToString(mult) + "X",
               290,120,
               clrAqua);

   // LOTS
   CreateLabel("DXB_LOT",
               "Base Lot     : " + DoubleToString(GetLot(BaseLot),2),
               290,145,
               clrOrange);

   // GAP
   CreateLabel("DXB_GAP",
               "M5 Gap       : " + DoubleToString(GetLastM5Gap(),2),
               290,170,
               clrYellow);

   CreateLabel("DXB_TRIGGER",
               "Gap Trigger  : " + DoubleToString(GapPrice,2),
               290,190,
               clrYellow);

   // DIRECTION
   CreateLabel("DXB_DIR",
               "Direction    : " + direction,
               290,215,
               dirClr);

   // ORDERS
   CreateLabel("DXB_BUYORD",
               "BUY Orders   : " + IntegerToString(CountOrders(OP_BUY)),
               290,240,
               clrLime);

   CreateLabel("DXB_SELLORD",
               "SELL Orders  : " + IntegerToString(CountOrders(OP_SELL)),
               290,260,
               clrTomato);

   CreateLabel("DXB_TOTAL",
               "Total Orders : " + IntegerToString(CountAllOrders()),
               290,280,
               clrWhite);

   // PROFITS
   CreateLabel("DXB_BUYPL",
               "BUY Basket   : $" + DoubleToString(buyPL,2),
               290,305,
               buyClr);

   CreateLabel("DXB_SELLPL",
            "SELL Basket  : $" + DoubleToString(sellPL,2),
            290,325,
            sellClr);

   // TP
   CreateLabel("DXB_BUYTP",
               "BUY TP       : $" + DoubleToString(GetDynamicBasketTarget(OP_BUY),2),
               290,350,
               clrDeepSkyBlue);

   CreateLabel("DXB_SELLTP",
               "SELL TP      : $" + DoubleToString(GetDynamicBasketTarget(OP_SELL),2),
               290,370,
               clrDeepSkyBlue);

   // SL
   CreateLabel("DXB_SL",
               "Basket SL    : $" + DoubleToString(GetBasketSL(),2),
               290,395,
               clrOrangeRed);

   // STATUS
   CreateLabel("DXB_STATUS",
               "RUNNING...",
               290,425,
               clrLime,
               11);
}
double GetLastClosedCandleDiffFrom5th()
{
   // Last closed candle
   double lastClose = iClose(Symbol(), PERIOD_M5, 1);

   // Previous 5th candle
   double fifthClose = iClose(Symbol(), PERIOD_M5, 5);

   // Raw price difference
   double diff = NormalizeDouble(lastClose - fifthClose, 0);

   return diff;
}
void DrawEveryCandleDiffFrom5th()
{
   int candlesToDraw = 100;

   for(int shift = 1; shift <= candlesToDraw; shift++)
   {
      // Need previous 5 candles
      if(shift + 5 >= Bars)
         continue;

      datetime t = iTime(Symbol(), PERIOD_M5, shift);

      string name = "DIFF5_" + IntegerToString((int)t);

      // Current candle close
      double currentClose = iClose(Symbol(), PERIOD_M5, shift);

      // 5th previous candle close
      double fifthClose = iClose(Symbol(), PERIOD_M5, shift + 5);

      // RAW PRICE DIFFERENCE
      double diff = NormalizeDouble(currentClose - fifthClose, 2);

      // SHOW ONLY > 50 or < -50
      if(MathAbs(diff) < 50)
         continue;

      color txtColor = diff >= 0 ? clrLime : clrRed;

      double high = iHigh(Symbol(), PERIOD_M5, shift);
      double low  = iLow(Symbol(), PERIOD_M5, shift);

      // Dynamic spacing
      double candleRange = MathAbs(high - low);

      double spacing = candleRange * 0.8;

      if(spacing < Point * 200)
         spacing = Point * 200;

      double y;

      if(diff >= 0)
         y = high + spacing;
      else
         y = low - spacing;

      // Create once
      if(ObjectFind(0, name) >= 0)
         continue;

      ObjectCreate(0, name, OBJ_TEXT, 0, t, y);

      ObjectSetString(0, name, OBJPROP_TEXT,
                      DoubleToString(diff, 0));

      ObjectSetInteger(0, name, OBJPROP_COLOR, txtColor);

      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);

      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");

      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
}
//+------------------------------------------------------------------+