//+------------------------------------------------------------------+
//| BTCUSD_BOS_PULLBACK_EA_VISUAL.mq4                                |
//| Strategy 3: BOS + Pullback only with chart visual debugging       |
//+------------------------------------------------------------------+
#property strict

input double InpLotSize              = 0.01;
input int    InpMagicNumber          = 33001;
input int    InpSlippage             = 30;

input int    InpSwingLookback        = 20;     // candles for structure high/low
input int    InpPullbackMaxBars      = 10;     // entry valid bars after BOS
input double InpMinBOSRawGap         = 20.0;   // minimum break raw price
input double InpPullbackMinRaw       = 30.0;   // minimum pullback from BOS price
input double InpPullbackMaxRaw       = 120.0;  // maximum pullback from BOS price

input double InpTakeProfitUSD        = 1.00;   // close order profit in account currency
input double InpStopLossUSD          = 5.00;   // close order loss in account currency
input int    InpMaxOpenOrders        = 1;
input bool   InpOnlyNewCandleEntry   = true;
input bool   InpShowVisuals          = true;

int      g_bosDirection = 0; // 1 buy, -1 sell
bool     g_bosActive    = false;
double   g_bosPrice     = 0.0;
datetime g_bosTime      = 0;
datetime g_lastBarTime  = 0;
string   g_lastStatus   = "Starting";
string   PFX            = "BOSPB_";

//+------------------------------------------------------------------+
int OnInit()
{
   Print("BOS Pullback Visual EA started");
   if(InpShowVisuals) DrawDashboard("Initialized");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(PFX);
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();
   CloseByProfitOrLoss();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar) g_lastBarTime = Time[0];

   DetectBOS();

   bool pullbackReady = (g_bosActive && IsPullbackEntryReady());
   if(InpShowVisuals) UpdateVisuals(pullbackReady, isNewBar);

   if(InpOnlyNewCandleEntry && !isNewBar)
   {
      g_lastStatus = "Waiting new candle";
      return;
   }

   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus = "Blocked: max open orders";
      return;
   }

   if(pullbackReady)
   {
      if(g_bosDirection == 1)
      {
         if(OpenOrder(OP_BUY, "BOS_PULLBACK_BUY")) DrawEntryArrow(1, Ask, TimeCurrent());
      }
      else if(g_bosDirection == -1)
      {
         if(OpenOrder(OP_SELL, "BOS_PULLBACK_SELL")) DrawEntryArrow(-1, Bid, TimeCurrent());
      }
      g_bosActive = false;
   }
}

//+------------------------------------------------------------------+
void DetectBOS()
{
   if(Bars < InpSwingLookback + 5) return;

   int highIndex = iHighest(Symbol(), Period(), MODE_HIGH, InpSwingLookback, 2);
   int lowIndex  = iLowest(Symbol(), Period(), MODE_LOW, InpSwingLookback, 2);

   double structureHigh = High[highIndex];
   double structureLow  = Low[lowIndex];

   DrawHLine(PFX+"STRUCT_HIGH", structureHigh, clrDodgerBlue, STYLE_DOT, "Structure High");
   DrawHLine(PFX+"STRUCT_LOW",  structureLow,  clrTomato,     STYLE_DOT, "Structure Low");

   if(Ask > structureHigh + InpMinBOSRawGap)
   {
      if(g_bosDirection != 1 || !g_bosActive)
      {
         g_bosDirection = 1;
         g_bosActive    = true;
         g_bosPrice     = Ask;
         g_bosTime      = TimeCurrent();
         g_lastStatus   = "Bullish BOS detected";
         DrawBOS(1, structureHigh, g_bosPrice, g_bosTime);
      }
      return;
   }

   if(Bid < structureLow - InpMinBOSRawGap)
   {
      if(g_bosDirection != -1 || !g_bosActive)
      {
         g_bosDirection = -1;
         g_bosActive    = true;
         g_bosPrice     = Bid;
         g_bosTime      = TimeCurrent();
         g_lastStatus   = "Bearish BOS detected";
         DrawBOS(-1, structureLow, g_bosPrice, g_bosTime);
      }
      return;
   }
}

//+------------------------------------------------------------------+
bool IsPullbackEntryReady()
{
   if(!g_bosActive || g_bosDirection == 0) return(false);

   int barsFromBOS = iBarShift(Symbol(), Period(), g_bosTime, false);
   if(barsFromBOS > InpPullbackMaxBars)
   {
      g_bosActive = false;
      g_lastStatus = "BOS expired";
      return(false);
   }

   double pullbackRaw = 0.0;
   if(g_bosDirection == 1)
      pullbackRaw = g_bosPrice - Bid;
   else
      pullbackRaw = Ask - g_bosPrice;

   if(pullbackRaw >= InpPullbackMinRaw && pullbackRaw <= InpPullbackMaxRaw)
   {
      g_lastStatus = "Pullback ready";
      return(true);
   }

   g_lastStatus = "Waiting pullback";
   return(false);
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, string comment)
{
   RefreshRates();
   double price = (type == OP_BUY) ? Ask : Bid;
   int ticket = OrderSend(Symbol(), type, InpLotSize, price, InpSlippage, 0, 0, comment, InpMagicNumber, 0, clrNONE);
   if(ticket < 0)
   {
      g_lastStatus = "OrderSend failed: " + IntegerToString(GetLastError());
      return(false);
   }
   g_lastStatus = "Order opened #" + IntegerToString(ticket);
   return(true);
}

//+------------------------------------------------------------------+
void CloseByProfitOrLoss()
{
   for(int i=OrdersTotal()-1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=InpMagicNumber) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit >= InpTakeProfitUSD || profit <= -InpStopLossUSD)
      {
         RefreshRates();
         bool closed=false;
         if(OrderType()==OP_BUY)  closed=OrderClose(OrderTicket(), OrderLots(), Bid, InpSlippage, clrLime);
         if(OrderType()==OP_SELL) closed=OrderClose(OrderTicket(), OrderLots(), Ask, InpSlippage, clrRed);
         if(closed) g_lastStatus = "Closed order P/L: " + DoubleToString(profit,2);
      }
   }
}

//+------------------------------------------------------------------+
int CountMyOrders()
{
   int c=0;
   for(int i=0; i<OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==InpMagicNumber) c++;
   }
   return(c);
}

//========================== VISUALS ================================
void UpdateVisuals(bool pullbackReady, bool isNewBar)
{
   if(g_bosActive) DrawPullbackZone();
   DrawDashboard(pullbackReady ? "ENTRY READY" : g_lastStatus);
}

void DrawBOS(int dir, double level, double bosPrice, datetime t)
{
   string name = PFX + "BOS_LINE_" + TimeToString(t, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   DrawHLine(name, level, dir==1 ? clrLime : clrRed, STYLE_SOLID, dir==1 ? "BOS BUY" : "BOS SELL");
   DrawText(PFX+"BOS_TEXT_"+IntegerToString((int)t), t, bosPrice, dir==1 ? "BOS BUY" : "BOS SELL", dir==1 ? clrLime : clrRed);
}

void DrawPullbackZone()
{
   double z1=0,z2=0;
   if(g_bosDirection==1)
   {
      z1 = g_bosPrice - InpPullbackMinRaw;
      z2 = g_bosPrice - InpPullbackMaxRaw;
   }
   else if(g_bosDirection==-1)
   {
      z1 = g_bosPrice + InpPullbackMinRaw;
      z2 = g_bosPrice + InpPullbackMaxRaw;
   }
   if(z1==0 || z2==0) return;

   double top = MathMax(z1,z2);
   double bot = MathMin(z1,z2);
   datetime t1 = g_bosTime;
   datetime t2 = TimeCurrent() + PeriodSeconds()*InpPullbackMaxBars;

   string name = PFX + "PULLBACK_ZONE";
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE,0,t1,top,t2,bot);
   else
   {
      ObjectMove(0,name,0,t1,top);
      ObjectMove(0,name,1,t2,bot);
   }
   ObjectSetInteger(0,name,OBJPROP_COLOR, g_bosDirection==1 ? clrPaleGreen : clrMistyRose);
   ObjectSetInteger(0,name,OBJPROP_BACK,true);
   ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);

   DrawHLine(PFX+"BOS_PRICE", g_bosPrice, clrGold, STYLE_DASH, "BOS Price");
}

void DrawEntryArrow(int dir, double price, datetime t)
{
   string name = PFX + "ENTRY_" + IntegerToString((int)t);
   ObjectCreate(0,name,OBJ_ARROW,0,t,price);
   ObjectSetInteger(0,name,OBJPROP_ARROWCODE, dir==1 ? 233 : 234);
   ObjectSetInteger(0,name,OBJPROP_COLOR, dir==1 ? clrLime : clrRed);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,2);
   DrawText(PFX+"ENTRY_TEXT_"+IntegerToString((int)t), t, price, dir==1 ? "BUY" : "SELL", dir==1 ? clrLime : clrRed);
}

void DrawDashboard(string status)
{
   string dir = "NONE";
   if(g_bosDirection==1) dir="BUY";
   if(g_bosDirection==-1) dir="SELL";
   double pullbackRaw=0;
   if(g_bosActive && g_bosDirection==1) pullbackRaw = g_bosPrice - Bid;
   if(g_bosActive && g_bosDirection==-1) pullbackRaw = Ask - g_bosPrice;

   string txt = "BOS + PULLBACK EA\n";
   txt += "BOS Direction : " + dir + "\n";
   txt += "BOS Active    : " + BoolText(g_bosActive) + "\n";
   txt += "BOS Price     : " + DoubleToString(g_bosPrice, Digits) + "\n";
   txt += "Pullback Raw  : " + DoubleToString(pullbackRaw,1) + " / " + DoubleToString(InpPullbackMinRaw,0) + "-" + DoubleToString(InpPullbackMaxRaw,0) + "\n";
   txt += "Open Orders   : " + IntegerToString(CountMyOrders()) + "\n";
   txt += "Status        : " + status;
   Comment(txt);
}

void DrawHLine(string name, double price, color clr, int style, string desc)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_HLINE,0,0,price);
   ObjectSetDouble(0,name,OBJPROP_PRICE1,price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_STYLE,style);
   ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetString(0,name,OBJPROP_TEXT,desc);
}

void DrawText(string name, datetime t, double price, string text, color clr)
{
   if(ObjectFind(0,name)<0) ObjectCreate(0,name,OBJ_TEXT,0,t,price);
   ObjectMove(0,name,0,t,price);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
}

string BoolText(bool v){ return(v ? "YES" : "NO"); }

void DeleteObjectsByPrefix(string prefix)
{
   for(int i=ObjectsTotal(0)-1; i>=0; i--)
   {
      string name = ObjectName(0,i);
      if(StringFind(name,prefix,0)==0) ObjectDelete(0,name);
   }
}
