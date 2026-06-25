//+------------------------------------------------------------------+
//|                 DXB_SAR_Dots_Only_Verify.mq4                     |
//|  SAR signals and dots only. No trading, no filters, no orders.    |
//+------------------------------------------------------------------+
#property strict
#property version   "1.00"

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

//======================== DASHBOARD ================================
input bool   InpShowDashboard    = true;
input color  InpDashBgColor      = clrBlack;
input color  InpDashBorderColor  = clrDimGray;

//======================== GLOBALS ==================================
string   OBJ_PREFIX = "DXB_SAR_ONLY_";
int      g_activeSARDirection = 0;     // 1 BUY, -1 SELL
int      g_lastSARDirection   = 0;
datetime g_lastSARFlipTime    = 0;
double   g_lastSARFlipPrice   = 0.0;
datetime g_lastBarTime        = 0;
string   g_status             = "SAR dots only - no trading";

//+------------------------------------------------------------------+
int OnInit()
{
   ObjectsDeleteAll(0, OBJ_PREFIX);
   UpdateSARState();
   DrawDashboardFrame();
   DrawSARDots();
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
   UpdateSARState();

   if(InpDrawSARDots)
      DrawSARDots();

   if(InpShowDashboard)
      DrawDashboard();

   if(Time[0] != g_lastBarTime)
   {
      g_lastBarTime = Time[0];
      g_status = "New bar | SAR " + DirectionText(g_activeSARDirection);
   }
}

//+------------------------------------------------------------------+
//| Same SAR calculation style from your old EA:                      |
//| step = InpSARPeriod * InpSARStepSize / 10000                     |
//| maximum = step * InpSARAcceleration                              |
//+------------------------------------------------------------------+
double SARStep()
{
   return(InpSARPeriod * InpSARStepSize / 10000.0);
}

//+------------------------------------------------------------------+
double SARMaximum()
{
   return(SARStep() * InpSARAcceleration);
}

//+------------------------------------------------------------------+
double SARValue(int shift)
{
   return(iSAR(Symbol(), Period(), SARStep(), SARMaximum(), shift));
}

//+------------------------------------------------------------------+
int GetSARDotDirection(int shift)
{
   double sar = SARValue(shift);
   double cls = iClose(Symbol(), Period(), shift);

   if(sar < cls) return(1);    // SAR dot below candle = BUY / BULL
   if(sar > cls) return(-1);   // SAR dot above candle = SELL / BEAR
   return(0);
}

//+------------------------------------------------------------------+
int GetSARFlipSignal()
{
   int d1 = GetSARDotDirection(1);
   int d2 = GetSARDotDirection(2);

   if(d1 != 0 && d2 != 0 && d1 != d2)
      return(d1);

   return(0);
}

//+------------------------------------------------------------------+
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
   }
}

//+------------------------------------------------------------------+
void DrawSARDots()
{
   int bars = MathMin(InpSARDotLookback, Bars - 2);
   if(bars <= 0)
      return;

   for(int i = bars; i >= 1; i--)
   {
      double sar = SARValue(i);
      if(sar <= 0.0)
         continue;

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

//+------------------------------------------------------------------+
string DirectionText(int direction)
{
   if(direction == 1)  return("BUY / BULL");
   if(direction == -1) return("SELL / BEAR");
   return("NONE");
}

//+------------------------------------------------------------------+
void DrawDashboardFrame()
{
   if(!InpShowDashboard)
      return;

   string bg = OBJ_PREFIX + "DASH_BG";
   if(ObjectFind(0, bg) < 0)
      ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);

   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 8);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 20);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 330);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 170);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, InpDashBgColor);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, InpDashBorderColor);
   ObjectSetInteger(0, bg, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
void DrawDashboard()
{
   DrawDashboardFrame();

   double sar1 = SARValue(1);
   double price = Close[1];
   double dist = MathAbs(price - sar1);
   int flip = GetSARFlipSignal();

   color sarColor = (g_activeSARDirection == 1 ? InpSARDotBuyColor : InpSARDotSellColor);

   SetLabel("L1", 30,  "DXB SAR DOTS ONLY - NO TRADING", clrWhite);
   SetLabel("L2", 50,  "Symbol: " + Symbol() + " | TF: " + IntegerToString(Period()), clrSilver);
   SetLabel("L3", 70,  "SAR: " + DirectionText(g_activeSARDirection), sarColor);
   SetLabel("L4", 90,  "SAR Price: " + DoubleToString(sar1, Digits), clrYellow);
   SetLabel("L5", 110, "Close[1]: " + DoubleToString(price, Digits), clrAqua);
   SetLabel("L6", 130, "Distance: " + DoubleToString(dist, Digits), clrWhite);
   SetLabel("L7", 150, "Flip: " + DirectionText(flip) + " | Step: " + DoubleToString(SARStep(), 6) + " | Max: " + DoubleToString(SARMaximum(), 6), clrSilver);
   SetLabel("L8", 170, "Status: " + g_status, clrAqua);
}
//+------------------------------------------------------------------+
