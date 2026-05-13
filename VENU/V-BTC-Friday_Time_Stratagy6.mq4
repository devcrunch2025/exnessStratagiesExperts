//+------------------------------------------------------------------+
//| _Gap_Recovery_OneDirection_EA.mq4                            |
//| Balance multiplier + basket TP/SL                                |
//+------------------------------------------------------------------+
#property strict

double BaseLot             = 0.01;
double GapPrice            = 50;//70.0;
int    MagicNumber         = 5050801;
int    Slippage            = 50;


double BasketProfitTarget  = 1.00;   // Will be multiplied
double BasketStopLoss      = 20.00;  // Will be multiplied

datetime lastM5BarTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   MagicNumber = AccountNumber() + 6;

   Print("Gap Recovery One Direction EA Started");
   return(INIT_SUCCEEDED);
}
string GetRunningEnvironment()
{
   string path = MQLInfoString(MQL_PROGRAM_PATH);

   // Detect your laptop username/path
   if(StringFind(path, "venuadmin") >= 0)
      return "LAPTOP";

   return "VPS";
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
int GetStrongM30Trend()
{
   double open  = iOpen(Symbol(), PERIOD_M30, 1);
   double close = iClose(Symbol(), PERIOD_M30, 1);

   double gap = close - open;

   // STRONG BUY candle
   if(gap >= 100)
      return 1;

   // STRONG SELL candle
   if(gap <= -100)
      return -1;

   return 0;
}
//+------------------------------------------------------------------+
void CheckNewBaseSignal()
{
   datetime m5Time = iTime(Symbol(), PERIOD_M1, 1);


// Print(GetRunningEnvironment());

   // if(GetRunningEnvironment()=="VPS")
   // {
   // Print("New bar time"+" "+m5Time+"  lastM5BarTime "+lastM5BarTime);

   // }



   if(m5Time == lastM5BarTime)
      return;
      else
   Print("New bar time"+" "+m5Time+"  lastM5BarTime "+lastM5BarTime);


   double open  = iOpen(Symbol(), PERIOD_M5, 1);
   double close = iClose(Symbol(), PERIOD_M5, 1);
   double gap   = close - open;

   

   Print("gap   "+" "+gap+" Trend "+DoubleToString(GetStrongM30Trend(),0));

   if(CountOrders(OP_BUY) > 0 || CountOrders(OP_SELL) > 0)
   {
      lastM5BarTime = m5Time;
      return;
   }

   if(gap > GapPrice && GetStrongM30Trend()==1)
   {
      OpenOrder(OP_BUY, GetLot(BaseLot), "V6_SIMPLE__BUY_S0");
      lastM5BarTime = m5Time;
      return;
   }

   if(gap < -GapPrice && GetStrongM30Trend()==-1)
   {
      OpenOrder(OP_SELL, GetLot(BaseLot), "V6_SIMPLE__SELL_S0");
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

   if(minutesPassed >= 3 && !StageExists(orderType, 1))
      OpenOrder(orderType, GetLot(0.01), MakeComment(orderType, 1));

   if(minutesPassed >= 15 && !StageExists(orderType, 2))
      OpenOrder(orderType, GetLot(0.02), MakeComment(orderType, 2));

   if(minutesPassed >= 30 && !StageExists(orderType, 3))
      OpenOrder(orderType, GetLot(0.03), MakeComment(orderType, 3));

   if(minutesPassed >= 45 && !StageExists(orderType, 4))
      OpenOrder(orderType, GetLot(0.04), MakeComment(orderType, 4));

   if(minutesPassed >= 60 && !StageExists(orderType, 5))
      OpenOrder(orderType, GetLot(0.05), MakeComment(orderType, 5));

       if(minutesPassed >= 90 && !StageExists(orderType, 6))
      OpenOrder(orderType, GetLot(0.06), MakeComment(orderType, 6));
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
bool HasEnoughMargin(int orderType,double lot)
{
   double marginRequired =
      MarketInfo(Symbol(), MODE_MARGINREQUIRED) * lot;

   double freeMargin = AccountFreeMargin();

   Print("FreeMargin=",freeMargin,
         " Required=",marginRequired);

   if(freeMargin < marginRequired)
   {
      Print("Not enough margin for new order.");
      return false;
   }

   return true;
}
//+------------------------------------------------------------------+
bool OpenOrder(int type, double lot, string comment)
{


   if(HasEnoughMargin(type,lot)==false) return false;
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
   string tag = orderType == OP_BUY ? "V6_SIMPLE__BUY_S0" : "V6_SIMPLE__SELL_S0";

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
      return "V6_SIMPLE__" + IntegerToString(stage);

   return "V6_SIMPLE_" + IntegerToString(stage);
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

      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_UPPER);

      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);

      ObjectSetInteger(0,name,OBJPROP_BACK,false);

      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);

      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);

      ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   }

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
CreatePanel("DXB_PANEL",10,10,380,470,C'15,15,15');   // TITLE
   CreateLabel("V6",
               "Time GAP V 6",
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
//+------------------------------------------------------------------+