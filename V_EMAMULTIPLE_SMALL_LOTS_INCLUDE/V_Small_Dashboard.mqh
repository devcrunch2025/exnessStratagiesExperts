//+------------------------------------------------------------------+
//|                                           V_Small_Dashboard.mqh |
//|                       V_EMAMULTIPLE_SMALL_LOTS DASHBOARD MODULE |
//+------------------------------------------------------------------+
#property strict

//====================================================================
// 1. DASHBOARD UI HELPER FUNCTIONS
//====================================================================
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardPanel(string name, int x, int y, int width, int height, color background)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
      return;
     }
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != background)
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   if((int)ObjectGetInteger(0, name, OBJPROP_XSIZE) != width)
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   if((int)ObjectGetInteger(0, name, OBJPROP_YSIZE) != height)
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
  }


//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, int fontSize, color textColor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 105);
      return;
     }
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 105);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != textColor)
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
  }

//+------------------------------------------------------------------+
//| CreateDashboardButton: Creates or updates an interactive button  |
//+------------------------------------------------------------------+
void CreateDashboardButton(string name, string text, int x, int y, int width, int height, color bgColor, color textColor, color borderColor)
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 100);
      return;
     }

   if((int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x)
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if((int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y)
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if((int)ObjectGetInteger(0, name, OBJPROP_XSIZE) != width)
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   if((int)ObjectGetInteger(0, name, OBJPROP_YSIZE) != height)
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != textColor)
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != bgColor)
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   if((color)ObjectGetInteger(0, name, OBJPROP_BORDER_COLOR) != borderColor)
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLeftLivePanel(string name,int x,int y,int width,int height,color background)
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
      ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
      ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,name,OBJPROP_COLOR,clrDimGray);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      return;
     }
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   if((color)ObjectGetInteger(0,name,OBJPROP_BGCOLOR) != background)
      ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   if((int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE) != y)
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   if((int)ObjectGetInteger(0,name,OBJPROP_XSIZE) != width)
      ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   if((int)ObjectGetInteger(0,name,OBJPROP_YSIZE) != height)
      ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLeftLiveLabel(string name,string text,int x,int y,int fontSize,color textColor,string font="Consolas")
  {
   if(ObjectFind(0,name)<0)
     {
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
      ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      ObjectSetString(0,name,OBJPROP_FONT,font);
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
      ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_ZORDER,105);
      return;
     }
   ObjectSetInteger(0,name,OBJPROP_ZORDER,105);
   if(ObjectGetString(0,name,OBJPROP_TEXT) != text)
      ObjectSetString(0,name,OBJPROP_TEXT,text);
   if((color)ObjectGetInteger(0,name,OBJPROP_COLOR) != textColor)
      ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   if((int)ObjectGetInteger(0,name,OBJPROP_XDISTANCE) != x)
      ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   if((int)ObjectGetInteger(0,name,OBJPROP_YDISTANCE) != y)
      ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   if((int)ObjectGetInteger(0,name,OBJPROP_FONTSIZE) != fontSize)
      ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   if(ObjectGetString(0,name,OBJPROP_FONT) != font)
      ObjectSetString(0,name,OBJPROP_FONT,font);
  }


void CreateTopCenterButton(string name, string text, int x, int y, int width, int height, color bgColor, color textColor, color borderColor, string tooltip = "")
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
      int targetFontSize = (width < 115) ? 8 : 9;
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, targetFontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 5002);
      if(tooltip != "")
         ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
      return;
     }

// Always guarantee top priority display on visible layers
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 5002);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);

   int targetFontSize = (width < 115) ? 8 : 9;
   if((int)ObjectGetInteger(0, name, OBJPROP_FONTSIZE) != targetFontSize)
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, targetFontSize);

   if((int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x)
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if((int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y)
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if((int)ObjectGetInteger(0, name, OBJPROP_XSIZE) != width)
      ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   if((int)ObjectGetInteger(0, name, OBJPROP_YSIZE) != height)
      ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != textColor)
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   if((color)ObjectGetInteger(0, name, OBJPROP_BGCOLOR) != bgColor)
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   if((color)ObjectGetInteger(0, name, OBJPROP_BORDER_COLOR) != borderColor)
      ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
   if(tooltip != "" && ObjectGetString(0, name, OBJPROP_TOOLTIP) != tooltip)
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
  }


//====================================================================
// 2. OBJECT CLEANUP AND DELETION FUNCTIONS
//====================================================================
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOurObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteDashboardObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, DASH_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }


void DeleteTopCenterGapObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, TOP_CENTER_GAP_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
   g_lastTopGapTooltip = "";
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteLeftLiveOrdersDashboardObjects(bool keepDayEqTarget = false)
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1; i>=0; i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,LEFT_LIVE_PREFIX,0)==0)
        {
         if(keepDayEqTarget && StringFind(name, "DEQTGT", 0) >= 0)
            continue;
         ObjectDelete(0,name);
        }
     }
  }



//====================================================================
// 3. MOMENTUM BACKGROUND & TOP WARNING / TIME DISPLAYS
//====================================================================
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateMomentumBackground()
  {
// Minimized: Disabled to eliminate expensive chart rectangle creation on every tick
   return;
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteTopCenterDubaiTimeObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if((StringFind(name, TOP_CENTER_DUBAI_PREFIX, 0) == 0 && StringFind(name, "NO_MANUAL", 0) < 0) || StringFind(name, TOP_CENTER_GAP_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
   g_lastTopDubaiUpdateMs  = 0;
   g_topDubaiLegacyCleaned = false;
   g_lastTopDubaiTooltip   = "";
   g_lastTopGapTooltip     = "";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateTopCenterDubaiLabel(string name, string text, int x, int y, int fontSize, color textColor, string font = "Consolas")
  {
   if(ObjectFind(0, name) < 0)
     {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, 5001);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetString(0, name, OBJPROP_FONT, font);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      return;
     }
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 5001);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   if(ObjectGetString(0, name, OBJPROP_TEXT) != text)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
   if((color)ObjectGetInteger(0, name, OBJPROP_COLOR) != textColor)
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   if((int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE) != x)
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   if((int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE) != y)
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   if((int)ObjectGetInteger(0, name, OBJPROP_FONTSIZE) != fontSize)
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   if((ENUM_ANCHOR_POINT)ObjectGetInteger(0, name, OBJPROP_ANCHOR) != ANCHOR_UPPER)
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_UPPER);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateNoManualWarningDisplay(int chartWidth, int leftEnd, int rightStart)
  {
   ObjectDelete(0, TOP_CENTER_DUBAI_PREFIX + "NO_MANUAL"); // Clean legacy object name if present
   if(!ShowTopCenterNoManualWarning)
     {
      ObjectDelete(0, NO_MANUAL_WARN_NAME);
      return;
     }

   int warnMidX = 0;
   int warnY    = (InpNoManualWarningCustomY > 0) ? InpNoManualWarningCustomY : MathMin(LeftDashboardY, DashboardTopGap);

   switch(InpNoManualWarningPosition)
     {
      case WARN_POS_RIGHT_UPPER_CORNER:
        {
         warnMidX = chartWidth - 130;
         break;
        }
      case WARN_POS_ABOVE_RIGHT_DASH:
        {
         int rW = (ShowDashboard && ObjectFind(0, DASH_PREFIX + "HEADER") >= 0)
                  ? (int)ObjectGetInteger(0, DASH_PREFIX + "HEADER", OBJPROP_XSIZE)
                  : MathMax(DashboardWidth, 375);
         warnMidX = rightStart + (rW / 2);
         if(InpNoManualWarningCustomY <= 0)
            warnY = MathMax(2, DashboardTopGap - 18);
         break;
        }
      case WARN_POS_TOP_CENTER:
        {
         warnMidX = (leftEnd + rightStart) / 2;
         break;
        }
      case WARN_POS_CUSTOM:
        {
         warnMidX = InpNoManualWarningCustomX;
         warnY    = InpNoManualWarningCustomY;
         break;
        }
      case WARN_POS_RIGHT_SIDE:
      default:
        {
         if(!g_dashboardsUserHidden && (rightStart - leftEnd) < 460)
           {
            int rW = (ShowDashboard && ObjectFind(0, DASH_PREFIX + "HEADER") >= 0)
                     ? (int)ObjectGetInteger(0, DASH_PREFIX + "HEADER", OBJPROP_XSIZE)
                     : MathMax(DashboardWidth, 375);
            warnMidX = rightStart + (rW / 2);
            warnY    = 4;
           }
         else
           {
            // Right Side: Anchored cleanly to the left of the Right Dashboard on top row (y=20)
            warnMidX = rightStart - 120;
            if(warnMidX < leftEnd + 120)
               warnMidX = leftEnd + 120;
           }
         break;
        }
     }

   string warnText  = InpTopCenterNoManualText;
   color  warnColor = C'255,45,45'; // Vivid Bright Red
   CreateTopCenterDubaiLabel(NO_MANUAL_WARN_NAME, warnText, warnMidX, warnY, 9, warnColor, "Arial Black");
   ObjectSetString(0, NO_MANUAL_WARN_NAME, OBJPROP_TOOLTIP, "WARNING: Do NOT place manual orders! Manual trading causes EA hedging calculations to desynchronize and result in losses.");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateTopCenterDubaiTimeDisplay(bool force = false)
  {
   int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   if(chartWidth <= 0)
      chartWidth = 1400;

// 1. Determine right boundary of Left Dashboard
   int leftEnd = 0;
   if(ShowLeftLiveOrdersDashboard && !g_dashboardsUserHidden && ObjectFind(0, LEFT_LIVE_PREFIX + "HEADER") >= 0)
     {
      int lX = (int)ObjectGetInteger(0, LEFT_LIVE_PREFIX + "HEADER", OBJPROP_XDISTANCE);
      int lW = (int)ObjectGetInteger(0, LEFT_LIVE_PREFIX + "HEADER", OBJPROP_XSIZE);
      leftEnd = lX + lW;
     }
   else
      if(ShowLeftLiveOrdersDashboard && !g_dashboardsUserHidden)
        {
         leftEnd = LeftDashboardX + 415;
        }

// 2. Determine left boundary of Right Dashboard
   int rightStart = chartWidth;
   if(ShowDashboard && !g_dashboardsUserHidden && ObjectFind(0, DASH_PREFIX + "HEADER") >= 0)
     {
      int rX      = (int)ObjectGetInteger(0, DASH_PREFIX + "HEADER", OBJPROP_XDISTANCE);
      int rW      = (int)ObjectGetInteger(0, DASH_PREFIX + "HEADER", OBJPROP_XSIZE);
      int rCorner = (int)ObjectGetInteger(0, DASH_PREFIX + "HEADER", OBJPROP_CORNER);
      if(rCorner == CORNER_RIGHT_UPPER)
         rightStart = chartWidth - (rX + rW);
      else
         rightStart = rX;
     }
   else
      if(ShowDashboard && !g_dashboardsUserHidden)
        {
         int rW = MathMax(DashboardWidth, 355);
         rightStart = chartWidth - (DashboardRightGap + 10 + rW);
        }

// Update warning message position (Right side by default)
   UpdateNoManualWarningDisplay(chartWidth, leftEnd, rightStart);

   if(!ShowTopCenterDubaiTime)
     {
      DeleteTopCenterDubaiTimeObjects();
      if(ShowDashboardToggleButton)
        {
         int fbW = 145, fbH = 32;
         int fbX = MathMax(10, (chartWidth - fbW) / 2);
         int fbY = 20;
         string fbText = g_dashboardsUserHidden ? "SHOW DASHBOARD" : "HIDE DASHBOARD";
         color  fbBg   = g_dashboardsUserHidden ? C'18,105,175' : C'35,50,75';
         color  fbBrd  = g_dashboardsUserHidden ? clrAqua : C'85,125,175';
         string fbTip  = g_dashboardsUserHidden ? "Dashboards are HIDDEN. Click to SHOW Left & Right Dashboards." : "Dashboards are VISIBLE. Click to HIDE Left & Right Dashboards.";
         CreateTopCenterButton(BTN_TOP_DASHBOARD_TOGGLE, fbText, fbX, fbY, fbW, fbH, fbBg, clrWhite, fbBrd, fbTip);
        }
      return;
     }

// Throttle UI/gap recalculation so Strategy Tester (especially while paused) runs at full speed
   uint nowMs = GetTickCount();
   uint minInterval = IsTesting() ? 1000 : 500;
   if(!force && g_lastTopDubaiUpdateMs != 0 && (uint)(nowMs - g_lastTopDubaiUpdateMs) < minInterval)
      return;
   g_lastTopDubaiUpdateMs = nowMs;

   int availGap = rightStart - leftEnd;
   bool showDubaiTimeInBar = ShowTopCenterDubaiTime && (g_dashboardsUserHidden || availGap >= 460);

   int dubaiWidth   = 195;
   int dubaiHeight  = 38;
   int btnWidth     = 170;
   int btnHeight    = 38;
   int toggleWidth  = (ShowDashboardToggleButton ? 145 : 0);
   int toggleHeight = 38;
   int gapWidth     = 360;
   int gapHeight    = 38;
   int gapSpacing   = 6;

   int dubaiX  = 10;
   int dubaiY  = MathMin(LeftDashboardY, DashboardTopGap);
   int btnX    = 10;
   int btnY    = dubaiY;
   int toggleX = 10;
   int toggleY = dubaiY;
   int gapX    = 10;
   int gapY    = dubaiY;

   if(!showDubaiTimeInBar)
     {
      DeleteTopCenterDubaiTimeObjects();
      DeleteTopCenterGapObjects();

      int usableSpace = MathMax(160, availGap - 12);
      btnWidth = MathMax(85, MathMin(140, (usableSpace - gapSpacing) / 2));
      toggleWidth = btnWidth;
      int totalBtns = btnWidth + gapSpacing + toggleWidth;
      int startX = leftEnd + MathMax(2, (availGap - totalBtns) / 2);
      toggleX = startX;
      btnX = toggleX + toggleWidth + gapSpacing;
      btnY = dubaiY;
      toggleY = dubaiY;
     }
   else
     {
      int totalWidth = (ShowDashboardToggleButton ? (toggleWidth + gapSpacing) : 0) + dubaiWidth + gapSpacing + btnWidth;
      int startX = 10;
      if(g_dashboardsUserHidden)
         startX = MathMax(10, (chartWidth - totalWidth) / 2);
      else
         startX = leftEnd + MathMax(2, (availGap - totalWidth) / 2);

      if(ShowDashboardToggleButton)
        {
         toggleX  = MathMax(10, startX);
         dubaiX   = toggleX + toggleWidth + gapSpacing;
        }
      else
        {
         toggleX  = MathMax(10, startX);
         dubaiX   = MathMax(10, startX);
        }
      btnX     = dubaiX + dubaiWidth + gapSpacing;
      btnY     = dubaiY;
      toggleY  = dubaiY;
      DeleteTopCenterGapObjects();

      int dubaiMidX = dubaiX + (dubaiWidth / 2);

      // --- BOX 1: DUBAI TIME PANEL ---
      string dubaiPnlName = TOP_CENTER_DUBAI_PREFIX + "PANEL";
      if(ObjectFind(0, dubaiPnlName) < 0)
        {
         ObjectCreate(0, dubaiPnlName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_BACK, false);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_ZORDER, 5000);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_XDISTANCE, dubaiX);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_YDISTANCE, dubaiY);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_XSIZE, dubaiWidth);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_YSIZE, dubaiHeight);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_BGCOLOR, C'20,48,82');
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_COLOR, C'45,95,155');
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_HIDDEN, true);
        }
      else
        {
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_ZORDER, 5000);
         ObjectSetInteger(0, dubaiPnlName, OBJPROP_BACK, false);
         if((int)ObjectGetInteger(0, dubaiPnlName, OBJPROP_XDISTANCE) != dubaiX)
            ObjectSetInteger(0, dubaiPnlName, OBJPROP_XDISTANCE, dubaiX);
         if((int)ObjectGetInteger(0, dubaiPnlName, OBJPROP_YDISTANCE) != dubaiY)
            ObjectSetInteger(0, dubaiPnlName, OBJPROP_YDISTANCE, dubaiY);
         if((int)ObjectGetInteger(0, dubaiPnlName, OBJPROP_XSIZE) != dubaiWidth)
            ObjectSetInteger(0, dubaiPnlName, OBJPROP_XSIZE, dubaiWidth);
         if((int)ObjectGetInteger(0, dubaiPnlName, OBJPROP_YSIZE) != dubaiHeight)
            ObjectSetInteger(0, dubaiPnlName, OBJPROP_YSIZE, dubaiHeight);
         if((color)ObjectGetInteger(0, dubaiPnlName, OBJPROP_BGCOLOR) != C'20,48,82')
            ObjectSetInteger(0, dubaiPnlName, OBJPROP_BGCOLOR, C'20,48,82');
        }

      // Time Calculation
      datetime nowServer = TimeCurrent();
      datetime dubaiTime = (nowServer > 0) ? (nowServer + (ServerToDubaiOffsetHours * 3600)) : 0;
      string   clockStr  = (dubaiTime > 0) ? TimeToString(dubaiTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) : "--:--:--";
      string   sessionTag = GetDayStartSessionShortTag();
      string   headerStr = StringFormat("DUBAI TIME (%s)", sessionTag);
      string   dubaiTooltip = StringFormat("Dubai GST (UTC+4) | Day Reset: %s Dubai | Server Offset: %+dh", sessionTag, ServerToDubaiOffsetHours);

      CreateTopCenterDubaiLabel(TOP_CENTER_DUBAI_PREFIX + "TITLE", headerStr, dubaiMidX, dubaiY + 4,  8, C'175,220,255', "Arial");
      CreateTopCenterDubaiLabel(TOP_CENTER_DUBAI_PREFIX + "CLOCK", clockStr,  dubaiMidX, dubaiY + 18, 9, clrWhite,       "Consolas");
      if(dubaiTooltip != g_lastTopDubaiTooltip)
        {
         ObjectSetString(0, dubaiPnlName, OBJPROP_TOOLTIP, dubaiTooltip);
         ObjectSetString(0, TOP_CENTER_DUBAI_PREFIX + "TITLE", OBJPROP_TOOLTIP, dubaiTooltip);
         ObjectSetString(0, TOP_CENTER_DUBAI_PREFIX + "CLOCK", OBJPROP_TOOLTIP, dubaiTooltip);
         g_lastTopDubaiTooltip = dubaiTooltip;
        }
     }
// --- BUTTON 1: STATUS BUTTON (TOP CENTER - SAME ROW AFTER DUBAI TIME) ---
   string topBtnName = BTN_TOP_RESUME_DAY;
   bool   isStopped   = (DayProfitLadderTradingStopped || g_dailyEquityAdverseLossHitToday || !EnableTrading);
   bool   isPaused    = (g_dailyEquityTradingBlocked || TradingHaltedUntilNextFlip || (TradeMonitoringLog != "") || g_manualTradingPaused);

   string topBtnText;
   color  topBtnBg;
   color  topBtnTxt;
   color  topBtnBrd;
   string topBtnTooltip;

   if(isStopped)
     {
      // RED: Trading Stopped
      topBtnText    = "TRADING STOPPED";
      topBtnBg      = C'190,30,30';   // Red
      topBtnTxt     = clrWhite;
      topBtnBrd     = clrWhite;
      topBtnTooltip = "Trading is STOPPED. Click to Resume Trading.";
     }
   else
      if(isPaused)
        {
         // YELLOW: Trading Paused / Waiting
         topBtnText    = "TRADING PAUSED";
         topBtnBg      = C'220,180,20';  // Yellow / Gold
         topBtnTxt     = clrBlack;       // Crisp black text on yellow
         topBtnBrd     = clrGold;
         topBtnTooltip = "Trading is PAUSED. Click to Resume Trading.";
        }
      else
        {
         // GREEN: Trading Running / Active
         topBtnText    = "TRADING RUNNING";
         topBtnBg      = C'22,145,55';   // Vibrant Green
         topBtnTxt     = clrWhite;
         topBtnBrd     = clrLime;
         if(g_lastTradingResumeTime > 0)
            topBtnTooltip = StringFormat("Trading is RUNNING (%s at %s) | Base Equity: $%.2f | Click to PAUSE", g_lastTradingResumeReason, TimeToString(g_lastTradingResumeTime, TIME_MINUTES|TIME_SECONDS), g_dayOpeningBalance);
         else
            topBtnTooltip = "Trading is RUNNING / Active. Click to PAUSE Trading.";
        }

   CreateTopCenterButton(topBtnName, topBtnText, btnX, btnY, btnWidth, btnHeight, topBtnBg, topBtnTxt, topBtnBrd, topBtnTooltip);

// --- BUTTON 2: SHOW/HIDE DASHBOARD BUTTON ---
   if(ShowDashboardToggleButton)
     {
      string toggleBtnText;
      color  toggleBtnBg;
      color  toggleBtnTxt;
      color  toggleBtnBrd;
      string toggleBtnTooltip;

      if(g_dashboardsUserHidden)
        {
         toggleBtnText    = "SHOW DASHBOARD";
         toggleBtnBg      = C'18,105,175'; // Vibrant Marine Blue
         toggleBtnTxt     = clrWhite;
         toggleBtnBrd     = clrAqua;
         toggleBtnTooltip = "Dashboards are currently HIDDEN. Click to SHOW Left & Right Dashboards.";
        }
      else
        {
         toggleBtnText    = "HIDE DASHBOARD";
         toggleBtnBg      = C'35,50,75';   // Slate Dark Navy
         toggleBtnTxt     = clrWhite;
         toggleBtnBrd     = C'85,125,175'; // Slate Blue border
         toggleBtnTooltip = "Dashboards are currently VISIBLE. Click to HIDE Left & Right Dashboards.";
        }

      CreateTopCenterButton(BTN_TOP_DASHBOARD_TOGGLE, toggleBtnText, toggleX, toggleY, toggleWidth, toggleHeight, toggleBtnBg, toggleBtnTxt, toggleBtnBrd, toggleBtnTooltip);
     }
   else
     {
      ObjectDelete(0, BTN_TOP_DASHBOARD_TOGGLE);
     }

// Clean up obsolete second button from chart if it exists
   ObjectDelete(0, BTN_TOP_PAUSE_DAY);


   if(ShowTopCenterRequiredGap)
     {
      int gapMidX = gapX + (gapWidth / 2);
      string buyGapStr    = "";
      string sellGapStr   = "";
      color  buyGapColor  = C'180,240,180';
      color  sellGapColor = C'180,240,180';
      string gapTooltip   = "";

      if(g_dailyEquityTradingBlocked)
        {
         // Skip heavy dynamic gap / iCustom calculations while daily trading is paused
         buyGapStr    = "TRADING PAUSED (DAILY TARGET HIT)";
         sellGapStr   = StringFormat("WAITING FOR NEXT SESSION (DUBAI %s)", GetNextSessionWaitHourStr());
         buyGapColor  = clrGold;
         sellGapColor = C'175,220,255';
         gapTooltip   = StringFormat("Daily Equity Stop Hit - Trading Paused Until Next Session Dubai %s", GetNextSessionWaitHourStr());
        }
      else
        {
         // Live Dynamic Gap Calculation (Dry-run without log spam)
         double rawBuy = 0.0, rawSell = 0.0;
         string reasonBuy = "", reasonSell = "";
         double finalBuy  = GetDynamicOrderGapDetails(OP_BUY, rawBuy, reasonBuy, false);
         double finalSell = GetDynamicOrderGapDetails(OP_SELL, rawSell, reasonSell, false);

         buyGapStr   = StringFormat("REQUIRED GAP BUY : $%.0f (%s)", finalBuy, reasonBuy);
         buyGapColor = (finalBuy >= 500.0) ? clrGold : C'180,240,180';

         sellGapStr   = StringFormat("REQUIRED GAP SELL: $%.0f (%s)", finalSell, reasonSell);
         sellGapColor = (finalSell >= 500.0) ? clrGold : C'180,240,180';

         gapTooltip = StringFormat("REQUIRED SAME ORDER GAP:\n" +
                                   "BUY : Req $%.2f (%s)\n" +
                                   "SELL: Req $%.2f (%s)",
                                   finalBuy, reasonBuy,
                                   finalSell, reasonSell);
        }

      // Remove any legacy labels that were inside the Dubai panel (once only)
      if(!g_topDubaiLegacyCleaned)
        {
         ObjectDelete(0, TOP_CENTER_DUBAI_PREFIX + "GAP_BUY");
         ObjectDelete(0, TOP_CENTER_DUBAI_PREFIX + "GAP_SELL");
         g_topDubaiLegacyCleaned = true;
        }

      CreateTopCenterDubaiLabel(TOP_CENTER_GAP_PREFIX + "GAP_BUY",  buyGapStr,  gapMidX, gapY + 4,  8, buyGapColor,  "Consolas");
      CreateTopCenterDubaiLabel(TOP_CENTER_GAP_PREFIX + "GAP_SELL", sellGapStr, gapMidX, gapY + 18, 8, sellGapColor, "Consolas");
      if(gapTooltip != g_lastTopGapTooltip)
        {
         ObjectSetString(0, TOP_CENTER_GAP_PREFIX + "PANEL", OBJPROP_TOOLTIP, gapTooltip);
         ObjectSetString(0, TOP_CENTER_GAP_PREFIX + "GAP_BUY", OBJPROP_TOOLTIP, gapTooltip);
         ObjectSetString(0, TOP_CENTER_GAP_PREFIX + "GAP_SELL", OBJPROP_TOOLTIP, gapTooltip);
         g_lastTopGapTooltip = gapTooltip;
        }
     }
   else
     {
      DeleteTopCenterGapObjects();
     }

// Warning message display is handled dynamically by UpdateNoManualWarningDisplay()
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct LeftDashOrderSnapshot
  {
   int               ticket;
   int               type;
   double            lots;
   double            openPrice;
   double            sl;
   double            pl;
   datetime          openTime;
   string            comment;
  };

//+------------------------------------------------------------------+
//| UpdateDayEquityTargetBarStandalone                               |
//| USER RULE: Exclude Day Equity target base info from Hide Dash    |
//| Draws / refreshes DEQTGT_BAR, DEQTGT_L, DEQTGT_R when hidden     |
//+------------------------------------------------------------------+
void UpdateDayEquityTargetBarStandalone()
  {
   if(!InpShowLeftDashDayEqTargetRow)
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_BAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_R");
      return;
     }

   string deqLeftTxt  = "";
   color  deqTxtClr   = clrSilver;
   string deqRightTxt = "";
   color  deqRightClr = clrSilver;
   color  deqBarClr   = C'18,22,34';

   double deqOpenBase   = (g_dayOpeningBalance > 0.0) ? g_dayOpeningBalance : AccountBalance();
   double deqMult       = (balancelomultipler > 0) ? balancelomultipler : 1;
   int    deqHoursDecay = 0;
   double deqDecayUSD   = 0.0;
   double deqTarget     = GetEffectiveDailyTargetEquity(deqHoursDecay, deqDecayUSD);
   double deqCurrent    = AccountEquity();
   double deqProfit     = deqCurrent - deqOpenBase;
   double deqRemaining  = MathMax(0.0, deqTarget - deqCurrent);
   double deqTgtProfit  = deqTarget - deqOpenBase;
   double deqPct        = (deqTgtProfit > 0.0) ? (deqProfit / deqTgtProfit * 100.0) : 0.0;
   string deqSign       = (deqProfit >= 0.0) ? "+" : "";
   string deqStatusTxt  = "";
   double deqPeakProfit = (g_dailyEquityPeakEquity > deqOpenBase) ? (g_dailyEquityPeakEquity - deqOpenBase) : (deqTarget - deqOpenBase);
   double deqFloorPct   = GetDailyEquityRetraceFloorPct(deqPeakProfit);
   double deqFloorUSD   = deqPeakProfit * (deqFloorPct / 100.0);

   if(g_dailyEquityTradingBlocked)
     {
      deqStatusTxt = "PAUSED";
      deqBarClr    = C'50,15,15';
      deqTxtClr    = clrWhite;
      if(g_dailyEquityAdverseLossHitToday)
         deqRightTxt  = StringFormat("P/L:%s$%.2f  PAUSED AT -$%.0f LOSS (TILL %s)", deqSign, deqProfit, DailyEquityMaxLossUSD * deqMult, GetNextSessionWaitHourStr());
      else
         deqRightTxt  = StringFormat("P/L:%s$%.2f  PAUSED AT %.0f%% RETRACE (TILL %s)", deqSign, deqProfit, deqFloorPct, GetNextSessionWaitHourStr());
      deqRightClr  = clrTomato;

      double pauseBaseUSD = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? g_dailyEquityResumeEquity : deqOpenBase;
      double pauseTgtUSD  = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? (g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult)) : deqTarget;
      string pauseMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
      deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                 deqStatusTxt, pauseBaseUSD, pauseTgtUSD, DailyEquityStopUSD * deqMult, pauseMultTag);
     }
   else
      if(g_dailyEquityIsResumedLeg && InpResumeDayTradingTargetMode == RESUME_MODE_TRAIL_STEP)
        {
         double resStepUSD = DailyEquityTrailStepUSD * deqMult;
         double resProfit  = deqCurrent - g_dailyEquityResumeEquity;
         string resSign    = (resProfit >= 0.0) ? "+" : "";
         deqStatusTxt = (g_dailyEquityStepCount > 0) ? StringFormat("+Step#%d", g_dailyEquityStepCount) : StringFormat("TRAIL+$%.0f", resStepUSD);

         double resFloorEq = 0.0;
         if(!g_dailyEquityResumedStepHit)
           {
            resFloorEq  = g_dailyEquityResumeSafetyFloor;
            deqRightTxt = StringFormat("P/L:%s$%.2f  StepTgt:$%.0f  SafetyFloor:$%.0f", resSign, resProfit, g_dailyEquityNextStepTarget, resFloorEq);
           }
         else
           {
            double legPeakProfit = (g_dailyEquityPeakEquity > g_dailyEquityResumeEquity) ? (g_dailyEquityPeakEquity - g_dailyEquityResumeEquity) : 0.0;
            double legFloorPct   = GetDailyEquityRetraceFloorPct(legPeakProfit);
            resFloorEq           = g_dailyEquityResumeEquity + (legPeakProfit * (legFloorPct / 100.0));
            if(resFloorEq < g_dailyEquityResumeEquity)
               resFloorEq = g_dailyEquityResumeEquity;
            deqRightTxt = StringFormat("P/L:%s$%.2f (Peak:$%.2f) Floor:$%.0f", resSign, resProfit, legPeakProfit, resFloorEq);
           }

         if(resProfit > 0.0)
           {
            deqBarClr   = C'20,40,12';
            deqTxtClr   = clrGold;
            deqRightClr = clrGold;
           }
         else
            if(resProfit < -0.01)
              {
               deqBarClr   = C'34,16,18';
               deqTxtClr   = clrWhite;
               deqRightClr = clrTomato;
              }
            else
              {
               deqBarClr   = C'18,22,34';
               deqTxtClr   = clrWhite;
               deqRightClr = clrWhite;
              }

         string resMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
         double freshDayTarget = g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult);
         deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                    deqStatusTxt, g_dailyEquityResumeEquity, freshDayTarget, DailyEquityStopUSD * deqMult, resMultTag);
        }
      else
         if(g_dailyEquityTargetHitToday)
           {
            deqStatusTxt = (g_dailyEquityStepCount > 0) ? StringFormat("+$5x%d", g_dailyEquityStepCount) : "TRAIL+$5";
            deqBarClr    = C'20,40,12';
            deqTxtClr    = clrGold;
            deqRightTxt  = StringFormat("P/L:%s$%.2f (Peak:$%.2f) Floor%.0f%%:$%.2f",
                                        deqSign, deqProfit, deqPeakProfit, deqFloorPct, deqFloorUSD);
            deqRightClr  = clrGold;
           }
         else
            if(deqPct >= 90.0)
              {
               deqStatusTxt = "NEAR";
               deqBarClr    = C'50,40,10';
               deqTxtClr    = clrGold;
               deqRightTxt  = StringFormat("P/L:%s$%.2f (%.0f%%)  Rem:$%.2f", deqSign, deqProfit, MathMax(0.0,MathMin(deqPct,100.0)), deqRemaining);
               deqRightClr  = clrGold;
              }
            else
               if(deqProfit > 0.0)
                 {
                  deqStatusTxt = "ACTIVE";
                  deqBarClr    = C'12,32,20';
                  deqTxtClr    = clrLime;
                  deqRightTxt  = StringFormat("P/L:%s$%.2f (%.0f%%)  Rem:$%.2f", deqSign, deqProfit, MathMax(0.0,MathMin(deqPct,100.0)), deqRemaining);
                  deqRightClr  = clrLime;
                 }
               else
                  if(deqProfit < -0.01)
                    {
                     deqStatusTxt = "WAIT";
                     deqBarClr    = C'34,16,18';
                     deqTxtClr    = clrWhite;
                     deqRightTxt  = StringFormat("P/L:%s$%.2f (0%%)  Rem:$%.2f", deqSign, deqProfit, deqRemaining);
                     deqRightClr  = clrTomato;
                    }
                  else
                    {
                     deqStatusTxt = "WAIT";
                     deqBarClr    = C'18,22,34';
                     deqTxtClr    = clrWhite;
                     deqRightTxt  = StringFormat("P/L:%s$%.2f (0%%)  Rem:$%.2f", deqSign, deqProfit, deqRemaining);
                     deqRightClr  = clrWhite;
                    }

   if(!g_dailyEquityIsResumedLeg || InpResumeDayTradingTargetMode != RESUME_MODE_TRAIL_STEP)
     {
      string multTag  = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
      string decayTag = (deqHoursDecay > 0) ? StringFormat(" (%dH-Decay)", deqHoursDecay) : "";
      deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s%s)",
                                 deqStatusTxt, deqOpenBase, deqTarget, deqTgtProfit, multTag, decayTag);
     }

   if(deqLeftTxt == "")
     {
      double fbBaseUSD = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? g_dailyEquityResumeEquity : deqOpenBase;
      double fbTgtUSD  = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? (g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult)) : deqTarget;
      string fbMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
      deqLeftTxt       = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                      deqStatusTxt, fbBaseUSD, fbTgtUSD, DailyEquityStopUSD * deqMult, fbMultTag);
     }

   int deqFontSize  = (InpLeftDashDayEqTargetFontSize > 0) ? InpLeftDashDayEqTargetFontSize : 16;
   int deqBarHeight = (InpShowLeftDashDayEqTargetRow && deqFontSize >= 14) ? 36 : 22;
   int minDashWidth = (InpShowLeftDashDayEqTargetRow && deqFontSize >= 14) ? 740 : 560;
   int x = LeftDashboardX;
   int curY = LeftDashboardY + 38;
   int tx = x + 12;
   int width = MathMax(LeftDashboardWidth + 230, minDashWidth);
   int deqTextY       = curY + ((deqBarHeight - deqFontSize) / 2) - 1;
   int deqRightOffset = (deqFontSize >= 14) ? 290 : 248;
   int deqRightX      = x + width - deqRightOffset;

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"DEQTGT_BAR", x, curY, width, deqBarHeight, deqBarClr);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DEQTGT_L",   deqLeftTxt,  tx,        deqTextY, deqFontSize, deqTxtClr,   InpLeftDashDayEqTargetFont);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DEQTGT_R",   deqRightTxt, deqRightX, deqTextY, deqFontSize, deqRightClr, InpLeftDashDayEqTargetFont);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateLeftLiveOrdersDashboard(bool force = false)
  {
   if(!ShowLeftLiveOrdersDashboard)
      return;

   uint nowMs = GetTickCount();
   uint minInterval = IsTesting() ? 1000 : 500;
   if(!force && g_lastLeftDashUpdateMs != 0 && (uint)(nowMs - g_lastLeftDashUpdateMs) < minInterval)
      return;
   g_lastLeftDashUpdateMs  = nowMs;
   g_lastLeftDashUpdateSec = TimeCurrent();

   if(g_dashboardsUserHidden)
     {
      UpdateDayEquityTargetBarStandalone();
      return;
     }

   if(!g_leftDashNightBarV3Reset || !g_leftDashStreamlinedV1Reset)
     {
      DeleteLeftLiveOrdersDashboardObjects();
      g_leftDashNightBarV3Reset    = true;
      g_leftDashStreamlinedV1Reset = true;
     }

   int total=0,buyCount=0,sellCount=0,pendingCount=0;
   int splittableBuyCount=0,splittableSellCount=0;
   double buyLots=0,sellLots=0,buyPL=0,sellPL=0,netPL=0;
   double symMinLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double symLotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(symMinLot <= 0.0)
      symMinLot = 0.01;
   if(symLotStep <= 0.0)
      symLotStep = 0.01;
   int symLotDigits = (symLotStep >= 1.0) ? 0 : ((symLotStep >= 0.1) ? 1 : ((symLotStep >= 0.01) ? 2 : 3));
   int rows=LeftDashboardMaxRows;
   if(rows<1)
      rows=1;
   if(rows>24)
      rows=24;
   LeftDashOrderSnapshot dashOrders[64];
   int dashOrderCount = 0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      total++;
      double orderLots = OrderLots();
      double orderPL = (type==OP_BUY || type==OP_SELL) ? (OrderProfit()+OrderSwap()+OrderCommission()) : 0.0;
      if(type==OP_BUY)
        {
         buyCount++;
         buyLots+=orderLots;
         buyPL+=orderPL;
         if(NormalizeDouble(orderLots - symMinLot, symLotDigits) >= (symLotStep - 1e-8))
            splittableBuyCount++;
        }
      else
         if(type==OP_SELL)
           {
            sellCount++;
            sellLots+=orderLots;
            sellPL+=orderPL;
            if(NormalizeDouble(orderLots - symMinLot, symLotDigits) >= (symLotStep - 1e-8))
               splittableSellCount++;
           }
         else
            pendingCount++;
      if(type==OP_BUY || type==OP_SELL)
         netPL+=orderPL;

      if(dashOrderCount < 64)
        {
         dashOrders[dashOrderCount].ticket    = OrderTicket();
         dashOrders[dashOrderCount].type      = type;
         dashOrders[dashOrderCount].lots      = orderLots;
         dashOrders[dashOrderCount].openPrice = OrderOpenPrice();
         dashOrders[dashOrderCount].sl        = OrderStopLoss();
         dashOrders[dashOrderCount].pl        = orderPL;
         dashOrders[dashOrderCount].openTime  = OrderOpenTime();
         dashOrders[dashOrderCount].comment   = OrderComment();
         dashOrderCount++;
        }
     }
   int deqFontSize  = (InpLeftDashDayEqTargetFontSize > 0) ? InpLeftDashDayEqTargetFontSize : 16;
   int deqBarHeight = (InpShowLeftDashDayEqTargetRow && deqFontSize >= 14) ? 36 : 22;
   int deqBarExtraY = InpShowLeftDashDayEqTargetRow ? (deqBarHeight - 22) : 0;
   int minDashWidth = (InpShowLeftDashDayEqTargetRow && deqFontSize >= 14) ? 740 : 560;
   int x=LeftDashboardX, y=LeftDashboardY, tx=x+12, width=MathMax(LeftDashboardWidth+230, minDashWidth);

   int intermediateBarsCount = 0;
   if(InpShowLeftDashHourlyEngineRows)
      intermediateBarsCount += 3;
   if(InpShowLeftDashDayEqTargetRow)
      intermediateBarsCount += 1;
   if(InpShowLeftDashNightCloseRow)
      intermediateBarsCount += 1;
   if(InpShowLeftDashPriceGapRow)
      intermediateBarsCount += 1;
   if(InpShowLeftDashStepLossRow)
      intermediateBarsCount += 1;

   int curY            = y + 38;
   int summaryBarY     = curY + (intermediateBarsCount * 22) + deqBarExtraY;
   int tableHeaderY    = summaryBarY + 42 + 8;
   int orderRowsStartY = tableHeaderY + 20;
   int panelHeight     = (orderRowsStartY - y) + (rows * 20) + 24;
   color pnlColor=clrWhite;
   if(netPL>0)
      pnlColor=clrLime;
   else
      if(netPL<0)
         pnlColor=clrTomato;

   string netPLStr  = (netPL>=0  ? "+" : "") + DoubleToString(netPL,2);
   string buyPLStr  = (buyPL>=0  ? "+" : "") + DoubleToString(buyPL,2);
   string sellPLStr = (sellPL>=0 ? "+" : "") + DoubleToString(sellPL,2);

   int leftHeaderWidth = 415;
   int panelTopY       = y + 38;
   int panelRemainH    = MathMax(20, panelHeight - 38);

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PANEL", x, panelTopY, width, panelRemainH, C'12,16,22');
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"HEADER", x, y, leftHeaderWidth, 38, C'25,70,115');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TITLE", "LIVE POSITION MONITOR", tx, y+8, 11, clrWhite);

   double liveBal = AccountBalance();
   double liveEq  = AccountEquity();
   double eqDiffUSD = liveEq - liveBal;
   double liveBuyDdUSD  = (buyPL  < 0.0) ? (-buyPL)  : 0.0;
   double liveSellDdUSD = (sellPL < 0.0) ? (-sellPL) : 0.0;
   double liveBuyDdPct  = (liveBal > 0.0 && liveBuyDdUSD  > 0.0) ? ((liveBuyDdUSD  / liveBal) * 100.0) : 0.0;
   double liveSellDdPct = (liveBal > 0.0 && liveSellDdUSD > 0.0) ? ((liveSellDdUSD / liveBal) * 100.0) : 0.0;
   double tmpCutB = 0.0, tmpCutS = 0.0;
   int    buyTier  = InpEnableEqDdLotReduction ? ResolveEqDdTierAndCut(liveBuyDdPct,  tmpCutB) : 0;
   int    sellTier = InpEnableEqDdLotReduction ? ResolveEqDdTierAndCut(liveSellDdPct, tmpCutS) : 0;
   int    leftTier = MathMax(buyTier, sellTier);
   bool   buyDom   = (liveBuyDdPct >= liveSellDdPct);
   double maxSideDdPct = buyDom ? liveBuyDdPct : liveSellDdPct;
   double maxSideDdUSD = buyDom ? liveBuyDdUSD : liveSellDdUSD;
   string maxSideName  = buyDom ? "BUY" : "SELL";
   bool   hrlyBreachBuy  = (!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut && InpEnableHourlyPlanBSideLossCut && liveBuyDdPct  > InpHourlySideLossThresholdPct);
   bool   hrlyBreachSell = (!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut && InpEnableHourlyPlanBSideLossCut && liveSellDdPct > InpHourlySideLossThresholdPct);
   bool   hrlyBreachAny  = (hrlyBreachBuy || hrlyBreachSell);
   datetime liveHrlyNow   = TimeCurrent();
   datetime liveHrlyDub   = (liveHrlyNow > 0) ? (liveHrlyNow + (ServerToDubaiOffsetHours * 3600)) : 0;
   int      liveHrlyDay   = (liveHrlyDub > 0) ? GetDubai16TradingDayKey(liveHrlyDub) : -1;
   double   liveHrlyOpenE = (g_dubaiDayOpeningEquity > 0.0 && g_dubaiNightCloseDayKey == liveHrlyDay)
                            ? g_dubaiDayOpeningEquity : liveEq;
   double   liveHrlyEqPct = (liveHrlyOpenE > 0.0) ? (((liveEq - liveHrlyOpenE) / liveHrlyOpenE) * 100.0) : 0.0;
   string   liveHrlySign  = (liveHrlyEqPct >= 0.0) ? "+" : "";
   double   liveHrlyAThr  = (InpHourlyPlanADayProfitPct > 0.0) ? InpHourlyPlanADayProfitPct : 5.0;
   double   liveHrlyCThr  = (InpHourlyPlanCDayProfitPct > 0.0) ? InpHourlyPlanCDayProfitPct : 10.0;
   int      liveHrlyDMin  = 1;
   long     liveHrlyDHour = 0;
   double   liveHrlyDThr  = ResolveHourlyPlanDMinuteAndThreshold(liveHrlyNow, liveHrlyDMin, liveHrlyDHour);
   bool     hrlyDLockedH  = ((InpHourlyPlanDOncePerHour && g_hourlyPlanDDoneHourSlot == liveHrlyDHour) ||
                             (InpHourlyPlanDOncePerDay && g_hourlyPlanDDoneToday));
   double   liveOpenBaseA = 0.0, liveTgtA = 0.0, liveValA = 0.0;
   double   liveReqEqA    = GetHourlyPlanRequiredEquity(liveHrlyAThr, liveOpenBaseA, liveTgtA, liveValA);
   double   liveOpenBaseC = 0.0, liveTgtC = 0.0, liveValC = 0.0;
   double   liveReqEqC    = GetHourlyPlanRequiredEquity(liveHrlyCThr, liveOpenBaseC, liveTgtC, liveValC);
   double   liveOpenBaseD = 0.0, liveTgtD = 0.0, liveValD = 0.0;
   double   liveReqEqD    = GetHourlyPlanRequiredEquity(liveHrlyDThr, liveOpenBaseD, liveTgtD, liveValD);

   bool     hrlyPlanAArmed = (!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut &&
                              InpEnableHourlyPlanADayProfitClose &&
                              (!InpHourlyPlanAOncePerDay || !g_hourlyPlanADoneToday) &&
                              liveOpenBaseA > 0.0 && liveEq > liveReqEqA &&
                              (!InpHourlyPlanARequireHigherHit || g_hourlyPlanAHitsToday == 0 || (liveEq > g_hourlyPlanALastHitEquity && ((liveEq - liveOpenBaseA)/liveOpenBaseA*100.0) > (g_hourlyPlanAHighestHitPct + MathMax(0.0, InpHourlyPlanAHitStepPct)))) &&
                              (buyCount + sellCount) > 0);
   bool     hrlyPlanCArmed = (!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut &&
                              InpEnableHourlyPlanCDayProfitClose &&
                              (!InpHourlyPlanCOncePerDay || !g_hourlyPlanCDoneToday) &&
                              liveOpenBaseC > 0.0 && liveEq > liveReqEqC &&
                              (!InpHourlyPlanCRequireHigherHit || g_hourlyPlanCHitsToday == 0 || (liveEq > g_hourlyPlanCLastHitEquity && ((liveEq - liveOpenBaseC)/liveOpenBaseC*100.0) > (g_hourlyPlanCHighestHitPct + MathMax(0.0, InpHourlyPlanCHitStepPct)))) &&
                              (buyCount + sellCount) > 0);
   bool     hrlyPlanDArmed = (!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut &&
                              InpEnableHourlyPlanDDayProfitClose &&
                              !hrlyDLockedH &&
                              liveOpenBaseD > 0.0 && liveEq > liveReqEqD &&
                              (!InpHourlyPlanDRequireHigherHit || g_hourlyPlanDHitsToday == 0 || (liveEq > g_hourlyPlanDLastHitEquity && ((liveEq - liveOpenBaseD)/liveOpenBaseD*100.0) > (g_hourlyPlanDHighestHitPct + MathMax(0.0, InpHourlyPlanDHitStepPct)))) &&
                              (buyCount + sellCount) > 0);

   double curAcctDdUSD = (liveBal > liveEq) ? (liveBal - liveEq) : 0.0;
   color  eqBadgeClr = clrSilver;
   string eqBadgeTxt = "";
   if(liveBuyDdPct > 0.0 && liveSellDdPct > 0.0)
     {
      string hitTag = "";
      if(leftTier >= 1)
        {
         string domCh = buyDom ? "B" : "S";
         datetime domHitT = buyDom ? g_eqDdBuyLastHitTime : g_eqDdSellLastHitTime;
         int      domHitR = buyDom ? g_eqDdBuyLastHitTier : g_eqDdSellLastHitTier;
         if(domHitT > 0 && domHitR == leftTier)
            hitTag = StringFormat(" [%s:T%d %s]", domCh, leftTier, TimeToString(domHitT + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES));
         else
            hitTag = StringFormat(" [%s:T%d]", domCh, leftTier);
        }
      else
         if(hrlyPlanDArmed)
            hitTag = StringFormat(" [1M-D:m%d +%.1f%%]", liveHrlyDMin, liveHrlyEqPct);
         else
            if(hrlyPlanCArmed)
               hitTag = StringFormat(" [15M-C +%.1f%%]", liveHrlyEqPct);
            else
               if(hrlyPlanAArmed)
                  hitTag = StringFormat(" [1H-A +%.1f%%]", liveHrlyEqPct);
               else
                  if(hrlyBreachAny)
                     hitTag = StringFormat(" [1H-B >%.0f%%L]", InpHourlySideLossThresholdPct);
                  else
                     if(InpEnableEqDdLotReduction && g_eqDdSessionPeakPct > 0.0)
                        hitTag = StringFormat(" | Pk:%.1f%%", g_eqDdSessionPeakPct);
      eqBadgeClr = (leftTier >= 1) ? GetEqDdTierColor(leftTier) : (hrlyPlanDArmed ? clrDeepSkyBlue : (hrlyPlanCArmed ? clrGold : (hrlyPlanAArmed ? clrLime : (hrlyBreachAny ? clrOrangeRed : clrTomato))));
      eqBadgeTxt = StringFormat("DD B:%.1f%% S:%.1f%%%s", liveBuyDdPct, liveSellDdPct, hitTag);
     }
   else
      if(maxSideDdPct > 0.0)
        {
         string absLossStr = (maxSideDdUSD >= 1000.0) ? DoubleToString(maxSideDdUSD, 0) : DoubleToString(maxSideDdUSD, 2);
         string tierTag    = "";
         int    domDoneT   = buyDom ? g_eqDdBuyCycleHighestTier : g_eqDdSellCycleHighestTier;
         double domCutPct  = buyDom ? tmpCutB : tmpCutS;
         if(leftTier >= 1)
            tierTag = StringFormat(" [T%d -%.0f%%L]", leftTier, domCutPct);
         else
            if(InpEnableEqDdLotReduction && domDoneT >= 1)
               tierTag = StringFormat(" [T%d Done]", domDoneT);
            else
               if(hrlyPlanDArmed)
                  tierTag = StringFormat(" [1M-D:m%d +%.1f%%]", liveHrlyDMin, liveHrlyEqPct);
               else
                  if(hrlyPlanCArmed)
                     tierTag = StringFormat(" [15M-C +%.1f%%]", liveHrlyEqPct);
                  else
                     if(hrlyPlanAArmed)
                        tierTag = StringFormat(" [1H-A +%.1f%%]", liveHrlyEqPct);
                     else
                        if(hrlyBreachAny)
                           tierTag = StringFormat(" [1H-B >%.0f%%L]", InpHourlySideLossThresholdPct);
                        else
                           if(InpEnableEqDdLotReduction && g_eqDdSessionPeakPct > 0.0)
                              tierTag = StringFormat(" | Pk:%.1f%%", g_eqDdSessionPeakPct);
         eqBadgeClr = (leftTier >= 1) ? GetEqDdTierColor(leftTier) : (hrlyPlanDArmed ? clrDeepSkyBlue : (hrlyPlanCArmed ? clrGold : (hrlyPlanAArmed ? clrLime : (hrlyBreachAny ? clrOrangeRed : clrTomato))));
         eqBadgeTxt = StringFormat("%s DD: %.1f%% (-$%s)%s", maxSideName, maxSideDdPct, absLossStr, tierTag);
        }
      else
        {
         string gainStr = (eqDiffUSD >= 1000.0) ? DoubleToString(eqDiffUSD, 0) : DoubleToString(eqDiffUSD, 2);
         string pkTag   = (InpEnableEqDdLotReduction && g_eqDdSessionPeakPct > 0.0)
                          ? StringFormat(" | Pk:%.1f%%", g_eqDdSessionPeakPct)
                          : ((!InpEnableEqDdLotReduction && InpEnableHourlySideLossCut)
                             ? StringFormat(" | D:m%d>%.0f%s %d/%d/%d/%d", liveHrlyDMin, liveHrlyDThr, (hrlyDLockedH ? "L" : "%"),
                                            g_hourlyPlanATotalSweeps, g_hourlySideLossTotalCuts, g_hourlyPlanCTotalSweeps, g_hourlyPlanDTotalSweeps)
                             : "");
         eqBadgeClr = hrlyPlanDArmed ? clrDeepSkyBlue : ((eqDiffUSD > 0.0) ? clrLime : clrSilver);
         eqBadgeTxt = StringFormat("SIDE DD: 0.0%% (+$%s)%s", gainStr, pkTag);
        }
   int eqBadgeWidth = MathMax(160, leftHeaderWidth - 210);
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"EQDD_BG", x+202, y+6, eqBadgeWidth, 26, C'14,18,26');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EQDD_TXT", eqBadgeTxt, x+208, y+11, 9, eqBadgeClr);
   ObjectDelete(0, LEFT_LIVE_PREFIX+"SYMBOL");

// Row 2 (y+38): Live Current DD Status Bar (Per-Side % / Active Tier / Wait / Next Trigger)
   bool leftWaitBuy  = (InpEnableEqDdLotReduction && buyTier  > 0 && g_eqDdBuyLastReachTime  > 0 && buyTier  >= g_eqDdBuyLastReachTier  && g_eqDdBuyLastReachTime  > g_eqDdBuyLastHitTime  && g_eqDdBuyLastReachReason  != "");
   bool leftWaitSell = (InpEnableEqDdLotReduction && sellTier > 0 && g_eqDdSellLastReachTime > 0 && sellTier >= g_eqDdSellLastReachTier && g_eqDdSellLastReachTime > g_eqDdSellLastHitTime && g_eqDdSellLastReachReason != "");
   bool leftPending  = (leftWaitBuy || leftWaitSell);
   bool anySideDone  = (g_eqDdBuyCycleHighestTier >= 1 || g_eqDdSellCycleHighestTier >= 1);

   string ddStatLeftTxt  = "";
   color  ddStatLeftClr  = clrSilver;
   string ddStatRightTxt = "";
   color  ddStatRightClr = clrLightGray;

   if(!InpEnableEqDdLotReduction)
     {
      if(InpEnableHourlySideLossCut)
        {
         string nxt1hClk = (g_hourlySideLossNextRunTime > 0)
                           ? TimeToString(g_hourlySideLossNextRunTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                           : "--:--";
         string nxt15mClk = (g_hourlyPlanCNextRunTime > 0)
                            ? TimeToString(g_hourlyPlanCNextRunTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                            : "--:--";
         string nxt1mClk = (g_hourlyPlanDNextRunTime > 0)
                           ? TimeToString(g_hourlyPlanDNextRunTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                           : "--:--";
         if(hrlyPlanDArmed)
           {
            ddStatLeftTxt = StringFormat("1M PLAN-D  : m%d Eq:$%.0f>Tgt:$%.0f WAIT %s -> CLOSE ALL",
                                         liveHrlyDMin, liveEq, liveReqEqD, nxt1mClk);
            ddStatLeftClr = clrDeepSkyBlue;
           }
         else
            if(hrlyPlanCArmed)
              {
               ddStatLeftTxt = StringFormat("15M PLAN-C : Eq:$%.0f>Tgt:$%.0f WAIT %s -> CLOSE ALL",
                                            liveEq, liveReqEqC, nxt15mClk);
               ddStatLeftClr = clrGold;
              }
            else
               if(hrlyPlanAArmed)
                 {
                  ddStatLeftTxt = StringFormat("1H PLAN-A  : Eq:$%.0f>Tgt:$%.0f WAIT %s -> CLOSE ALL",
                                               liveEq, liveReqEqA, nxt1hClk);
                  ddStatLeftClr = clrLime;
                 }
               else
                  if(hrlyBreachAny)
                    {
                     ddStatLeftTxt = StringFormat("1H PLAN-B  : B:%.1f%% S:%.1f%% (>%.0f%% WAIT %s)",
                                                  liveBuyDdPct, liveSellDdPct, InpHourlySideLossThresholdPct, nxt1hClk);
                     ddStatLeftClr = clrOrangeRed;
                    }
                  else
                    {
                     string dStateTag = !InpEnableHourlyPlanDDayProfitClose ? "Off"
                                        : (hrlyDLockedH ? StringFormat("m%dLOCK", liveHrlyDMin)
                                           : StringFormat("m%d>%.0f%%", liveHrlyDMin, liveHrlyDThr));
                     ddStatLeftTxt = StringFormat("1H %s : Eq:%s%.1f%% (D:%s) | B:%.1f%% S:%.1f%%",
                                                  (InpEnableHourlyPlanBSideLossCut ? "A/B/C/D" : "A/C/D  "),
                                                  liveHrlySign, liveHrlyEqPct, dStateTag,
                                                  liveBuyDdPct, liveSellDdPct);
                     ddStatLeftClr = (maxSideDdPct > 0.0) ? clrWhite : clrLime;
                    }
         ddStatRightTxt = StringFormat("1H:%s 15M:%s | %d/%d/%d/%d", nxt1hClk, nxt15mClk, g_hourlyPlanATotalSweeps, g_hourlySideLossTotalCuts, g_hourlyPlanCTotalSweeps, g_hourlyPlanDTotalSweeps);
         ddStatRightClr = (g_hourlyPlanATotalSweeps > 0 || g_hourlyPlanCTotalSweeps > 0 || g_hourlyPlanDTotalSweeps > 0 || g_hourlySideLossTotalCuts > 0 || hrlyPlanDArmed || hrlyPlanCArmed || hrlyPlanAArmed || hrlyBreachAny) ? clrGold : clrLightGray;
        }
      else
        {
         string rlfStateTag = g_drawdownReliefExecuted ? "SL SET" : (g_drawdownReliefArmed ? "ARMED" : (g_drawdownReliefPeakUSD > 0.0 ? "TRACK" : "IDLE"));
         ddStatLeftTxt  = StringFormat("DD STATUS  : EQ-DD DISABLED (RLF: %s | AcctDD:$%.0f)", rlfStateTag, curAcctDdUSD);
         ddStatLeftClr  = clrSilver;
         ddStatRightTxt = "EQ-DD Off";
         ddStatRightClr = clrSilver;
        }
     }
   else
     {
      bool   pickStatBuy = (MathMax(buyTier, g_eqDdBuyCycleHighestTier) > MathMax(sellTier, g_eqDdSellCycleHighestTier)) ||
                           (MathMax(buyTier, g_eqDdBuyCycleHighestTier) == MathMax(sellTier, g_eqDdSellCycleHighestTier) && liveBuyDdPct >= liveSellDdPct);
      int    statCurT   = pickStatBuy ? buyTier : sellTier;
      int    statDoneT  = pickStatBuy ? g_eqDdBuyCycleHighestTier : g_eqDdSellCycleHighestTier;
      double statCutPct = pickStatBuy ? tmpCutB : tmpCutS;
      string statSideCh = pickStatBuy ? "B" : "S";
      double nextThresh = 0.0;
      int    nextTier   = ResolveNextEqDdTier(statCurT, statDoneT, nextThresh);
      ddStatRightTxt = StringFormat("Next:T%d@%.0f%% | Cut:%d(-%.2fL)", nextTier, nextThresh, g_eqDdTotalPartialCuts, g_eqDdTotalLotsReduced);
      ddStatRightClr = (g_eqDdTotalPartialCuts > 0 || leftTier >= 1) ? clrGold : clrLightGray;

      if(g_eqDdCloseAllPending)
        {
         ddStatLeftTxt = StringFormat("DD STATUS  : CLOSE-ALL | B:%.1f%% S:%.1f%% | Pk:%.1f%%", liveBuyDdPct, liveSellDdPct, g_eqDdSessionPeakPct);
         ddStatLeftClr = clrRed;
        }
      else
         if(leftPending)
           {
            bool   pickWBuy = (leftWaitBuy && (!leftWaitSell || buyTier > sellTier || (buyTier == sellTier && liveBuyDdPct >= liveSellDdPct)));
            string wSCh     = pickWBuy ? "B" : "S";
            int    wT       = pickWBuy ? buyTier : sellTier;
            string wRsn     = pickWBuy ? g_eqDdBuyLastReachReason : g_eqDdSellLastReachReason;
            double wPct     = pickWBuy ? liveBuyDdPct : liveSellDdPct;
            ddStatLeftTxt = StringFormat("DD STATUS  : %s-T%d WAIT (%s) | B:%.1f%% S:%.1f%% | Pk:%.1f%%",
                                         wSCh, wT, wRsn, liveBuyDdPct, liveSellDdPct, g_eqDdSessionPeakPct);
            if(StringLen(ddStatLeftTxt) > 61)
               ddStatLeftTxt = StringFormat("DD STATUS  : %s-T%d WAIT (%s) | %.1f%% | Pk:%.1f%%", wSCh, wT, wRsn, wPct, g_eqDdSessionPeakPct);
            ddStatLeftClr = GetEqDdTierColor(wT);
           }
         else
            if(leftTier >= 1)
              {
               ddStatLeftTxt = StringFormat("DD STATUS  : %s-T%d ACTIVE (-%.0f%%L) | B:%.1f%% S:%.1f%% | Pk:%.1f%%",
                                            statSideCh, leftTier, statCutPct, liveBuyDdPct, liveSellDdPct, g_eqDdSessionPeakPct);
               ddStatLeftClr = GetEqDdTierColor(leftTier);
              }
            else
               if(anySideDone)
                 {
                  ddStatLeftTxt = StringFormat("DD STATUS  : %s-RECOV (T%d Done) | B:%.1f%% S:%.1f%% | Pk:%.1f%%",
                                               statSideCh, statDoneT, liveBuyDdPct, liveSellDdPct, g_eqDdSessionPeakPct);
                  ddStatLeftClr = clrGold;
                 }
               else
                 {
                  ddStatLeftTxt = StringFormat("DD STATUS  : OK | B:%.1f%% S:%.1f%% | AcctDD:$%.0f | Pk:%.1f%%",
                                               liveBuyDdPct, liveSellDdPct, curAcctDdUSD, g_eqDdSessionPeakPct);
                  ddStatLeftClr = (maxSideDdPct > 0.0) ? clrWhite : clrLime;
                 }
     }

// Row 3 (y+60): Chronological Latest DD Event Banner (Hit / Wait / Cleared in Dubai Time)
   string ddBannerTxt = "DD LATEST  : NONE YET";
   color  ddBannerClr = clrSilver;
   datetime leftPendTime = 0;
   if(leftWaitBuy && leftWaitSell)
      leftPendTime = MathMax(g_eqDdBuyLastReachTime, g_eqDdSellLastReachTime);
   else
      if(leftWaitBuy)
         leftPendTime = g_eqDdBuyLastReachTime;
      else
         if(leftWaitSell)
            leftPendTime = g_eqDdSellLastReachTime;

   if(!InpEnableEqDdLotReduction)
     {
      if(InpEnableHourlySideLossCut)
        {
         if(g_hourlyPlanDLastHitTime > 0 && g_hourlyPlanDLastHitTime >= g_hourlyPlanCLastHitTime && g_hourlyPlanDLastHitTime >= g_hourlyPlanALastHitTime && g_hourlyPlanDLastHitTime >= g_hourlySideLossLastHitTime)
           {
            string dPlSign = (g_hourlyPlanDLastPL >= 0.0) ? "+" : "-";
            ddBannerTxt = StringFormat("1M PLAN-D  : m%d>%.0f%% +%.1f%% @%s x%d (-%.2fL %s$%.1f)",
                                       g_hourlyPlanDLastHitMinIdx, g_hourlyPlanDLastHitThreshPct,
                                       g_hourlyPlanDLastPct,
                                       FormatDubaiShortDT(g_hourlyPlanDLastHitTime, false),
                                       g_hourlyPlanDLastOrders, g_hourlyPlanDLastLots,
                                       dPlSign, MathAbs(g_hourlyPlanDLastPL));
            ddBannerClr = clrDeepSkyBlue;
           }
         else
            if(g_hourlyPlanCLastHitTime > 0 && g_hourlyPlanCLastHitTime >= g_hourlyPlanALastHitTime && g_hourlyPlanCLastHitTime >= g_hourlySideLossLastHitTime)
              {
               string cPlSign = (g_hourlyPlanCLastPL >= 0.0) ? "+" : "-";
               ddBannerTxt = StringFormat("15M PLAN-C : +%.1f%% ALL @ %s x%d (-%.2fL %s$%.1f)",
                                          g_hourlyPlanCLastPct,
                                          FormatDubaiShortDT(g_hourlyPlanCLastHitTime, true),
                                          g_hourlyPlanCLastOrders, g_hourlyPlanCLastLots,
                                          cPlSign, MathAbs(g_hourlyPlanCLastPL));
               ddBannerClr = clrGold;
              }
            else
               if(g_hourlyPlanALastHitTime > 0 && g_hourlyPlanALastHitTime >= g_hourlySideLossLastHitTime)
                 {
                  string aPlSign = (g_hourlyPlanALastPL >= 0.0) ? "+" : "-";
                  ddBannerTxt = StringFormat("1H PLAN-A  : DAY +%.2f%% ALL @ %s GST | x%d (-%.2fL %s$%.1f)",
                                             g_hourlyPlanALastPct,
                                             FormatDubaiShortDT(g_hourlyPlanALastHitTime, true),
                                             g_hourlyPlanALastOrders, g_hourlyPlanALastLots,
                                             aPlSign, MathAbs(g_hourlyPlanALastPL));
                  ddBannerClr = clrLime;
                 }
               else
                  if(g_hourlySideLossLastHitTime > 0)
                    {
                     string hPlSign = (g_hourlySideLossLastHitPL >= 0.0) ? "+" : "-";
                     ddBannerTxt = StringFormat("1H PLAN-B  : %s %.1f%% (-%.0f%%L) @ %s GST | x%d (-%.2fL %s$%.1f)",
                                                g_hourlySideLossLastHitSide, g_hourlySideLossLastHitPct, InpHourlySideLossCutPct,
                                                FormatDubaiShortDT(g_hourlySideLossLastHitTime, true),
                                                g_hourlySideLossLastHitOrders, g_hourlySideLossLastHitLots,
                                                hPlSign, MathAbs(g_hourlySideLossLastHitPL));
                     ddBannerClr = clrOrangeRed;
                    }
                  else
                    {
                     string bLeftTag = InpEnableHourlyPlanBSideLossCut ? StringFormat("B>%.0f", InpHourlySideLossThresholdPct) : "B:OFF";
                     ddBannerTxt = StringFormat("1H A-D     : NONE | A>%.0f %s C>%.0f D:m%d>%.0f%s Chk:%d/%d/%d",
                                                liveHrlyAThr, bLeftTag,
                                                liveHrlyCThr, liveHrlyDMin, liveHrlyDThr, (hrlyDLockedH ? "L" : "%"),
                                                g_hourlySideLossCheckCount, g_hourlyPlanCCheckCount, g_hourlyPlanDCheckCount);
                     ddBannerClr = hrlyPlanDArmed ? clrDeepSkyBlue : (hrlyPlanCArmed ? clrGold : (hrlyPlanAArmed ? clrLime : (hrlyBreachAny ? clrOrangeRed : clrSilver)));
                    }
        }
      else
        {
         ddBannerTxt = "DD LATEST  : EQ-DD PROTECTION DISABLED";
         ddBannerClr = clrSilver;
        }
     }
   else
      if(leftPendTime > 0 && leftPendTime >= g_eqDdLastHitTime && leftPendTime >= g_eqDdLastResetTime)
        {
         bool   pickWBuy = (leftWaitBuy && (!leftWaitSell || g_eqDdBuyLastReachTime >= g_eqDdSellLastReachTime));
         string wSide    = pickWBuy ? "BUY" : "SELL";
         int    wT       = pickWBuy ? buyTier : sellTier;
         double wPct     = pickWBuy ? liveBuyDdPct : liveSellDdPct;
         double wUsd     = pickWBuy ? liveBuyDdUSD : liveSellDdUSD;
         string wRsn     = pickWBuy ? g_eqDdBuyLastReachReason : g_eqDdSellLastReachReason;
         ddBannerTxt = StringFormat("DD LATEST  : %s T%d WAIT @ %s GST | %.1f%% (-$%.1f) | %s",
                                    wSide, wT, FormatDubaiShortDT(leftPendTime, true), wPct, wUsd, wRsn);
         ddBannerClr = GetEqDdTierColor(wT);
        }
      else
         if(g_eqDdLastResetTime > 0 && g_eqDdLastResetTime > g_eqDdLastHitTime)
           {
            if(g_eqDdLastHitTime > 0)
              {
               string hCh = (g_eqDdLastHitSide != "" ? StringSubstr(g_eqDdLastHitSide, 0, 1) : "?");
               ddBannerTxt = StringFormat("DD LATEST  : %s CLEARED (T%d->OK) @ %s GST | Last:%s-T%d x%d(-%.2fL)",
                                          g_eqDdLastResetSide, g_eqDdLastResetTier, FormatDubaiShortDT(g_eqDdLastResetTime, false),
                                          hCh, g_eqDdLastHitTier, g_eqDdLastHitOrders, g_eqDdLastHitLots);
              }
            else
               ddBannerTxt = StringFormat("DD LATEST  : %s CLEARED (T%d->OK) @ %s GST | Loss Cleared [OK]",
                                          g_eqDdLastResetSide, g_eqDdLastResetTier, FormatDubaiShortDT(g_eqDdLastResetTime, true));
            ddBannerClr = clrLime;
           }
         else
            if(g_eqDdLastHitTime > 0)
              {
               string hitSideLbl = (g_eqDdLastHitSide != "" ? (g_eqDdLastHitSide + " ") : "");
               string okTag      = (!anySideDone && leftTier == 0) ? " [OK]" : "";
               ddBannerTxt = StringFormat("DD LATEST  : %sT%d (-%.0f%%L) @ %s GST | %.1f%% (-$%.1f) | x%d (-%.2fL)%s",
                                          hitSideLbl, g_eqDdLastHitTier, g_eqDdLastHitCutPct,
                                          FormatDubaiShortDT(g_eqDdLastHitTime, true),
                                          g_eqDdLastHitPct, g_eqDdLastHitUSD, g_eqDdLastHitOrders, g_eqDdLastHitLots, okTag);
               ddBannerClr = (!anySideDone && leftTier == 0) ? clrGold : GetEqDdTierColor(g_eqDdLastHitTier);
              }
            else
               if(g_eqDdLastReachTime > 0)
                 {
                  string reachSideLbl = (g_eqDdLastReachSide != "" ? (g_eqDdLastReachSide + " ") : "");
                  string rsnTag       = (g_eqDdLastReachReason != "" ? g_eqDdLastReachReason : "Waiting Elig");
                  ddBannerTxt = StringFormat("DD LATEST  : %sT%d REACH @ %s GST | %.1f%% | %s",
                                             reachSideLbl, g_eqDdLastReachTier, FormatDubaiShortDT(g_eqDdLastReachTime, true),
                                             g_eqDdLastReachPct, rsnTag);
                  ddBannerClr = GetEqDdTierColor(g_eqDdLastReachTier);
                 }
               else
                  if(g_drawdownReliefExecuted || g_drawdownReliefArmed)
                    {
                     string rTag = g_drawdownReliefExecuted ? StringFormat("SL SET (Hits:%d)", g_drawdownReliefHitSuccessCount)
                                   : StringFormat("ARMED (Tgt <=$%.0f)", g_drawdownReliefPeakUSD * (1.0 - InpDrawdownReliefPercent));
                     if(g_eqDdDailyResetTime > 0)
                        ddBannerTxt = StringFormat("DD LATEST  : DAY RESET @ %s GST | RLF %s | AcctDD:$%.1f",
                                                   FormatDubaiShortDT(g_eqDdDailyResetTime, false), rTag, curAcctDdUSD);
                     else
                        ddBannerTxt = StringFormat("DD LATEST  : EQ-DD NONE YET | RLF %s | AcctDD:$%.1f", rTag, curAcctDdUSD);
                     ddBannerClr = g_drawdownReliefExecuted ? clrLime : clrGold;
                    }
                  else
                     if(g_eqDdDailyResetTime > 0)
                       {
                        if(g_eqDdPriorDayCuts > 0)
                           ddBannerTxt = StringFormat("DD LATEST  : DAY RESET @ %s GST | Fresh Start (Yday:%d -%.2fL) [OK]",
                                                      FormatDubaiShortDT(g_eqDdDailyResetTime, false),
                                                      g_eqDdPriorDayCuts, g_eqDdPriorDayLotsCut);
                        else
                           ddBannerTxt = StringFormat("DD LATEST  : DAY RESET @ %s GST | Fresh Start [OK]",
                                                      FormatDubaiShortDT(g_eqDdDailyResetTime, false));
                        ddBannerClr = clrLime;
                       }
                     else
                        if(g_drawdownReliefPeakUSD > 0.0)
                          {
                           double rMult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
                           double rReq  = (InpDrawdownReliefMinPeakUSD > 0.0 ? InpDrawdownReliefMinPeakUSD * rMult : 100.0 * rMult);
                           string rTag  = StringFormat("TRACK $%.0f/$%.0f", g_drawdownReliefPeakUSD, rReq);
                           ddBannerTxt = StringFormat("DD LATEST  : EQ-DD NONE YET | RLF %s | AcctDD:$%.1f", rTag, curAcctDdUSD);
                           ddBannerClr = clrDeepSkyBlue;
                          }
                        else
                          {
                           int    firstTier   = InpEqDdEnableTier1 ? 1 : 2;
                           double firstThresh = InpEqDdEnableTier1 ? InpEqDdTier1Pct : InpEqDdTier2Pct;
                           double firstCut    = InpEqDdEnableTier1 ? InpEqDdTier1CutPct : InpEqDdTier2CutPct;
                           ddBannerTxt = StringFormat("DD LATEST  : NONE YET | Per-Side T%d@%.0f%% (-%.0f%%L) .. T%d@%.0f%% Armed",
                                                      firstTier, firstThresh, firstCut, InpEqDdMaxTier, GetEqDdTierThresholdPct(InpEqDdMaxTier));
                           ddBannerClr = clrSilver;
                          }

// Dubai Time & Night-Close Status Bars
   datetime dNowServer = TimeCurrent();
   datetime dDubaiTime = (dNowServer > 0) ? (dNowServer + (ServerToDubaiOffsetHours * 3600)) : 0;
   string   dDubaiClk  = (dDubaiTime > 0) ? TimeToString(dDubaiTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS) : "--:--:--";
   string   dSrvClk    = (dNowServer > 0) ? TimeToString(dNowServer, TIME_MINUTES) : "--:--";
   int      dDubaiHr   = (dDubaiTime > 0) ? TimeHour(dDubaiTime) : 0;
   int      dDubaiMin  = (dDubaiTime > 0) ? TimeMinute(dDubaiTime) : 0;
   int      dDubaiMod  = dDubaiHr * 60 + dDubaiMin;
   int      dDubaiDay  = (dDubaiTime > 0) ? GetDubai16TradingDayKey(dDubaiTime) : -1;
   int      dStartMod  = InpDubaiNightCloseStartHour * 60;
   int      dEndMod    = InpDubaiNightCloseEndHour   * 60;
   int      dForceMod  = InpDubaiNightForceCloseHour * 60 + InpDubaiNightForceCloseMinute;
   bool     dInNight   = false;
   if(dDubaiTime > 0)
     {
      if(InpDubaiNightCloseStartHour < InpDubaiNightCloseEndHour)
         dInNight = (dDubaiHr >= InpDubaiNightCloseStartHour && dDubaiHr < InpDubaiNightCloseEndHour);
      else
         if(InpDubaiNightCloseStartHour > InpDubaiNightCloseEndHour)
            dInNight = (dDubaiHr >= InpDubaiNightCloseStartHour || dDubaiHr < InpDubaiNightCloseEndHour);
         else
            dInNight = (dDubaiHr == InpDubaiNightCloseStartHour);
     }
   bool dInForce = false;
   bool dForceInWindow = false;
   if(InpEnableDubaiNightForceCloseAll)
     {
      if(dStartMod < dEndMod)
         dForceInWindow = (dForceMod >= dStartMod && dForceMod < dEndMod);
      else
         if(dStartMod > dEndMod)
            dForceInWindow = (dForceMod >= dStartMod || dForceMod < dEndMod);
         else
            dForceInWindow = (InpDubaiNightForceCloseHour == InpDubaiNightCloseStartHour);
     }
   bool dForceActive = (InpEnableDubaiNightForceCloseAll && dForceInWindow);
   if(dInNight && dForceActive)
     {
      if(dStartMod <= dEndMod)
         dInForce = (dDubaiMod >= dForceMod);
      else
         if(dForceMod >= dStartMod)
            dInForce = (dDubaiMod >= dForceMod || dDubaiMod < dEndMod);
         else
            dInForce = (dDubaiMod >= dForceMod && dDubaiMod < dEndMod);
     }
   double dAbsAng   = MathAbs(GetEmaAngleDegrees(30));
   bool   dAngOk    = (!InpEnableDubaiNightEmaAngleFilter ||
                       (dAbsAng + 1e-9 >= InpDubaiNightMinEmaAngleDeg &&
                        dAbsAng - 1e-9 <= InpDubaiNightMaxEmaAngleDeg));
   double dOpenEq   = (g_dubaiDayOpeningEquity > 0.0 && g_dubaiNightCloseDayKey == dDubaiDay)
                      ? g_dubaiDayOpeningEquity : liveEq;
   double dDayEqPct = (dOpenEq > 0.0) ? (((liveEq - dOpenEq) / dOpenEq) * 100.0) : 0.0;
   bool   dDayEqHit = (InpEnableDubaiNightDayProfitClose && dOpenEq > 0.0 && dDayEqPct > InpDubaiNightDayProfitPct);
   string dSign     = (dDayEqPct >= 0.0) ? "+" : "";
   double dDayTgtEq = (dOpenEq > 0.0) ? (dOpenEq * (1.0 + InpDubaiNightDayProfitPct / 100.0)) : 0.0;

   bool   dSameDayKey    = (g_dubaiNightCloseDayKey == dDubaiDay);
   int    dCutsTodayDisp = dSameDayKey ? g_dubaiNightCutCountToday : 0;
   int    dCooldownSec   = MathMax(60, InpDubaiNightCutIntervalMinutes * 60);
   bool   dCooldownOn    = (dSameDayKey && g_dubaiNightLastCutTime > 0 && dNowServer >= g_dubaiNightLastCutTime &&
                            (dNowServer - g_dubaiNightLastCutTime) < dCooldownSec);
   int    dCoolRemSec    = dCooldownOn ? MathMax(0, dCooldownSec - (int)(dNowServer - g_dubaiNightLastCutTime)) : 0;
   bool   dOneSideZero   = (buyCount == 0 && sellCount > 0) || (sellCount == 0 && buyCount > 0);
   string dZeroSideStr   = (buyCount == 0) ? "BUY" : "SELL";
   int    dActiveOrdCnt  = (buyCount > 0) ? buyCount : sellCount;
   int    dActiveSplit   = (buyCount == 0) ? splittableSellCount : splittableBuyCount;
   string dCloseClk      = (g_dubaiNightCloseLastHitTime > 0)
                           ? TimeToString(g_dubaiNightCloseLastHitTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES|TIME_SECONDS)
                           : "--:--:--";
   string dCutClk        = (g_dubaiNightLastCutTime > 0)
                           ? TimeToString(g_dubaiNightLastCutTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES|TIME_SECONDS)
                           : "--:--:--";
   string dCutMinClk     = (g_dubaiNightLastCutTime > 0)
                           ? TimeToString(g_dubaiNightLastCutTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                           : "--:--";

   string leftDubaiTimeTxt = StringFormat("DUBAI TIME : %s", dDubaiClk);
   color  leftDubaiTimeClr = clrAqua;
   string leftDubaiStatTxt = InpEnableDubaiNightDayProfitClose
                             ? StringFormat("Srv:%s | Open:$%.0f (%s%.1f%%/%.0f%%) | |Ang|:%.2f",
                                   dSrvClk, dOpenEq, dSign, dDayEqPct, InpDubaiNightDayProfitPct, dAbsAng)
                             : StringFormat("Srv:%s | Open:$%.0f (%s%.1f%%) | |Ang|:%.2f",
                                   dSrvClk, dOpenEq, dSign, dDayEqPct, dAbsAng);
   color  leftDubaiStatClr = dDayEqHit ? clrLime : (dAngOk ? clrAqua : clrSilver);

   string nightLeftTxt  = "";
   color  nightLeftClr  = clrLightGray;
   string nightRightTxt = "";
   color  nightRightClr = clrLightGray;

   if(!InpEnableDubaiNightOneSideCloseAll)
     {
      leftDubaiStatClr = clrSilver;
      nightLeftTxt     = StringFormat("NIGHT CLOSE: OFF (%02d-%02d GST | Enable=false)",
                                      InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour);
      nightLeftClr     = clrSilver;
      nightRightTxt    = "Path-A/B Off";
      nightRightClr    = clrSilver;
     }
   else
      if(g_dubaiNightCloseDoneToday && g_dubaiNightCloseDayKey == dDubaiDay)
        {
         leftDubaiTimeClr = clrGold;
         leftDubaiStatClr = clrGold;
         if(g_dubaiNightLastCloseTag != "")
           {
            if(g_dubaiNightLastCloseOrders > 0)
              {
               string cPlSign = (g_dubaiNightLastClosePL >= 0.0) ? "+" : "-";
               nightLeftTxt   = StringFormat("NIGHT CLOSE: DONE[%s] @%s x%d -%.2fL %s$%.1f",
                                             g_dubaiNightLastCloseTag, dCloseClk,
                                             g_dubaiNightLastCloseOrders, g_dubaiNightLastCloseLots,
                                             cPlSign, MathAbs(g_dubaiNightLastClosePL));
              }
            else
               nightLeftTxt = StringFormat("NIGHT CLOSE: DONE[%s] @%s GST | 0 Ord Closed",
                                           g_dubaiNightLastCloseTag, dCloseClk);
           }
         else
            nightLeftTxt = StringFormat("NIGHT CLOSE: DONE TODAY @ %s GST | Locked 1x/Day", dCloseClk);
         nightLeftClr  = clrGold;
         nightRightTxt = (g_dubaiNightCutCountToday > 0)
                         ? StringFormat("Cuts:%d | Reset 00:00", g_dubaiNightCutCountToday)
                         : "1x Done | Reset 00:00";
         nightRightClr = clrGold;
        }
      else
         if(dInNight && g_dubaiNightCloseRetryPending)
           {
            leftDubaiTimeClr = clrTomato;
            leftDubaiStatClr = clrTomato;
            nightLeftTxt     = StringFormat("NIGHT CLOSE: RETRY CLOSE ALL | Open:%d (B:%d S:%d)",
                                            buyCount + sellCount, buyCount, sellCount);
            nightLeftClr     = clrTomato;
            nightRightTxt    = "Partial Retry";
            nightRightClr    = clrTomato;
           }
         else
            if(dInNight && dDayEqHit)
              {
               leftDubaiTimeClr = clrLime;
               leftDubaiStatClr = clrLime;
               nightLeftTxt     = StringFormat("NIGHT CLOSE: PATH-A DAY %s%.1f%%>%.0f%% -> CLOSE ALL (%d)",
                                               dSign, dDayEqPct, InpDubaiNightDayProfitPct, buyCount + sellCount);
               nightLeftClr     = clrLime;
               nightRightTxt    = StringFormat("Tgt:>$%.0f [HIT]", dDayTgtEq);
               nightRightClr    = clrLime;
              }
            else
               if(dInForce)
                 {
                  if(dAngOk)
                    {
                     if((buyCount + sellCount) > 0)
                       {
                        leftDubaiTimeClr = clrTomato;
                        leftDubaiStatClr = clrTomato;
                        nightLeftTxt     = StringFormat("NIGHT CLOSE: %02d:%02d FORCE ALL | Close %d Ord (%.2fL)",
                                                        InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute,
                                                        buyCount + sellCount, buyLots + sellLots);
                        nightLeftClr     = clrTomato;
                        nightRightTxt    = StringFormat("Cuts:%d | |Ang|:%.2f", g_dubaiNightCutCountToday, dAbsAng);
                        nightRightClr    = clrTomato;
                       }
                     else
                       {
                        leftDubaiTimeClr = clrDeepSkyBlue;
                        leftDubaiStatClr = clrDeepSkyBlue;
                        nightLeftTxt     = StringFormat("NIGHT CLOSE: %02d:%02d FORCE ARMED | No Open Orders (0)",
                                                        InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute);
                        nightLeftClr     = clrDeepSkyBlue;
                        nightRightTxt    = StringFormat("|Ang|:%.2f <= %.1f", dAbsAng, InpDubaiNightMaxEmaAngleDeg);
                        nightRightClr    = clrDeepSkyBlue;
                       }
                    }
                  else
                    {
                     leftDubaiTimeClr = clrGold;
                     leftDubaiStatClr = clrGold;
                     nightLeftTxt     = StringFormat("NIGHT CLOSE: %02d:%02d WAIT ANG | |%.2f| (%.0f-%.0f)",
                                                     InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute,
                                                     dAbsAng, InpDubaiNightMinEmaAngleDeg, InpDubaiNightMaxEmaAngleDeg);
                     nightLeftClr     = clrGold;
                     nightRightTxt    = InpEnableDubaiNightDayProfitClose
                                        ? StringFormat("Cuts:%d | Tgt:>$%.0f", g_dubaiNightCutCountToday, dDayTgtEq)
                                        : StringFormat("Cuts:%d | 0..%.1f deg", g_dubaiNightCutCountToday, InpDubaiNightMaxEmaAngleDeg);
                     nightRightClr    = clrSilver;
                    }
                 }
               else
                  if(dInNight)
                    {
                     if(!dAngOk)
                       {
                        leftDubaiTimeClr = clrGold;
                        leftDubaiStatClr = clrGold;
                        if(g_dubaiNightCutCountToday > 0 && g_dubaiNightLastCutLots > 0.0)
                           nightLeftTxt = StringFormat("NIGHT CLOSE: HOLD |Ang|:%.2f | Last:CUT#%d @ %s",
                                                       dAbsAng, g_dubaiNightCutCountToday, dCutMinClk);
                        else
                           nightLeftTxt = StringFormat("NIGHT CLOSE: HOLD |Ang|:%.2f (Need %.0f-%.0f | B:%d S:%d)",
                                                       dAbsAng, InpDubaiNightMinEmaAngleDeg, InpDubaiNightMaxEmaAngleDeg,
                                                       buyCount, sellCount);
                        nightLeftClr = clrGold;
                        if(dCooldownOn)
                           nightRightTxt = dForceActive
                                           ? StringFormat("Cool:%02dm%02ds | %02d:%02d",
                                                          dCoolRemSec / 60, dCoolRemSec % 60,
                                                          InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                           : StringFormat("Cool:%02dm%02ds | End %02d:00",
                                                          dCoolRemSec / 60, dCoolRemSec % 60, InpDubaiNightCloseEndHour);
                        else
                           if(InpEnableDubaiNightDayProfitClose)
                              nightRightTxt = dForceActive
                                              ? StringFormat("Tgt:>$%.0f | %02d:%02d ALL",
                                                             dDayTgtEq, InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                              : StringFormat("Tgt:>$%.0f | End %02d:00", dDayTgtEq, InpDubaiNightCloseEndHour);
                           else
                              nightRightTxt = dForceActive
                                              ? StringFormat("Need %.0f-%.0f | %02d:%02d",
                                                             InpDubaiNightMinEmaAngleDeg, InpDubaiNightMaxEmaAngleDeg,
                                                             InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                              : StringFormat("Need %.0f-%.0f | End %02d:00",
                                                             InpDubaiNightMinEmaAngleDeg, InpDubaiNightMaxEmaAngleDeg, InpDubaiNightCloseEndHour);
                        nightRightClr = dCooldownOn ? clrDeepSkyBlue : clrSilver;
                       }
                     else
                        if(!dOneSideZero)
                          {
                           if(buyCount == 0 && sellCount == 0)
                             {
                              leftDubaiTimeClr = clrDeepSkyBlue;
                              leftDubaiStatClr = clrDeepSkyBlue;
                              if(g_dubaiNightCutCountToday > 0 && g_dubaiNightLastCutLots > 0.0)
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: OPEN:0 | Last:CUT#%d %s=0 @%s -%.2fL",
                                                             g_dubaiNightCutCountToday, g_dubaiNightLastCutZeroSide,
                                                             dCutMinClk, g_dubaiNightLastCutLots);
                              else
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: IN WINDOW %02d-%02d | Open:0 (Armed)",
                                                             InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour);
                              nightLeftClr = clrDeepSkyBlue;
                             }
                           else
                             {
                              leftDubaiTimeClr = clrAqua;
                              leftDubaiStatClr = clrAqua;
                              if(g_dubaiNightCutCountToday > 0 && g_dubaiNightLastCutLots > 0.0)
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: WAIT 1-SIDE=0 (B:%d S:%d) | CUT#%d @%s",
                                                             buyCount, sellCount, g_dubaiNightCutCountToday, dCutMinClk);
                              else
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: WAIT 1-SIDE=0 (B:%d S:%d | Need B=0/S=0)",
                                                             buyCount, sellCount);
                              nightLeftClr = clrSilver;
                             }
                           if(dCooldownOn)
                              nightRightTxt = dForceActive
                                              ? StringFormat("Cool:%02dm%02ds | %02d:%02d",
                                                             dCoolRemSec / 60, dCoolRemSec % 60,
                                                             InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                              : StringFormat("Cool:%02dm%02ds | End %02d:00",
                                                             dCoolRemSec / 60, dCoolRemSec % 60, InpDubaiNightCloseEndHour);
                           else
                              if(InpEnableDubaiNightDayProfitClose)
                                 nightRightTxt = dForceActive
                                                 ? StringFormat("Tgt:>$%.0f | %02d:%02d ALL",
                                                                dDayTgtEq, InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                 : StringFormat("Tgt:>$%.0f | 1-Side=0", dDayTgtEq);
                              else
                                 nightRightTxt = dForceActive
                                                 ? StringFormat("-%.0f%%/%dm | %02d:%02d ALL",
                                                                InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes,
                                                                InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                 : StringFormat("-%.0f%%/%dm | 1-Side=0",
                                                                InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes);
                           nightRightClr = dCooldownOn ? clrDeepSkyBlue : clrLightGray;
                          }
                        else
                           if(dCooldownOn)
                             {
                              leftDubaiTimeClr = clrDeepSkyBlue;
                              leftDubaiStatClr = clrDeepSkyBlue;
                              if(g_dubaiNightLastCutLots > 0.0)
                                {
                                 string cutPlSign = (g_dubaiNightLastCutPL >= 0.0) ? "+" : "-";
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: CUT#%d %s=0 @%s x%d -%.2fL %s$%.1f",
                                                             g_dubaiNightCutCountToday, g_dubaiNightLastCutZeroSide,
                                                             dCutClk, g_dubaiNightLastCutOrders, g_dubaiNightLastCutLots,
                                                             cutPlSign, MathAbs(g_dubaiNightLastCutPL));
                                }
                              else
                                 nightLeftTxt = StringFormat("NIGHT CLOSE: CUT#%d COOLDOWN @%s GST | %s=0",
                                                             g_dubaiNightCutCountToday, dCutClk, dZeroSideStr);
                              nightLeftClr = clrDeepSkyBlue;
                              if(dActiveSplit == 0)
                                 nightRightTxt = dForceActive
                                                 ? StringFormat("Nxt:%02dm%02ds MinL %02d:%02d", dCoolRemSec / 60, dCoolRemSec % 60,
                                                                InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                 : StringFormat("Nxt:%02dm%02ds | MinLot", dCoolRemSec / 60, dCoolRemSec % 60);
                              else
                                 nightRightTxt = dForceActive
                                                 ? StringFormat("Nxt:%02dm%02ds | All %02d:%02d", dCoolRemSec / 60, dCoolRemSec % 60,
                                                                InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                 : StringFormat("Nxt:%02dm%02ds | -%.0f%%/%dm", dCoolRemSec / 60, dCoolRemSec % 60,
                                                                InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes);
                              nightRightClr = clrDeepSkyBlue;
                             }
                           else
                              if(dActiveSplit == 0)
                                {
                                 leftDubaiTimeClr = clrAqua;
                                 leftDubaiStatClr = clrAqua;
                                 if(dCutsTodayDisp > 0)
                                    nightLeftTxt = StringFormat("NIGHT CLOSE: MINLOT KEPT %s=0 | CUT#%d (%d Ord@Min)",
                                                                dZeroSideStr, dCutsTodayDisp, dActiveOrdCnt);
                                 else
                                    nightLeftTxt = dForceActive
                                                   ? StringFormat("NIGHT CLOSE: MINLOT KEPT %s=0 (%d Ord@Min -> %02d:%02d)",
                                                                  dZeroSideStr, dActiveOrdCnt,
                                                                  InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                   : StringFormat("NIGHT CLOSE: MINLOT KEPT %s=0 (%d Ord@Min)",
                                                                  dZeroSideStr, dActiveOrdCnt);
                                 nightLeftClr  = clrAqua;
                                 if(dForceActive && InpEnableDubaiNightDayProfitClose && dOpenEq > 0.0)
                                    nightRightTxt = StringFormat("Final %02d:%02d | Tgt:$%.0f",
                                                                 InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute, dDayTgtEq);
                                 else
                                    if(dForceActive)
                                       nightRightTxt = StringFormat("Final %02d:%02d | Cuts:%d",
                                                                    InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute, dCutsTodayDisp);
                                    else
                                       nightRightTxt = StringFormat("Cuts:%d Skip:%d", dCutsTodayDisp, g_dubaiNightLastCutSkippedMin);
                                 nightRightClr = clrGold;
                                }
                              else
                                {
                                 leftDubaiTimeClr = clrOrange;
                                 leftDubaiStatClr = clrOrange;
                                 nightLeftTxt     = StringFormat("NIGHT CLOSE: PATH-B ARMED %s=0 | Cut:%d/%d -%.0f%%/%dm",
                                                                 dZeroSideStr, dActiveSplit, dActiveOrdCnt,
                                                                 InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes);
                                 nightLeftClr     = clrOrange;
                                 nightRightTxt    = dForceActive
                                                    ? StringFormat("Cuts:%d | %02d:%02d ALL",
                                                                   g_dubaiNightCutCountToday, InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                                    : StringFormat("Cuts:%d | End %02d:00",
                                                                   g_dubaiNightCutCountToday, InpDubaiNightCloseEndHour);
                                 nightRightClr    = clrOrange;
                                }
                    }
                  else
                    {
                     int minsToWin = (dDubaiTime > 0) ? ((dStartMod - dDubaiMod + 1440) % 1440) : 0;
                     if(minsToWin == 0 && dDubaiTime > 0)
                        minsToWin = 1440;
                     int hToWin = minsToWin / 60;
                     int mToWin = minsToWin % 60;
                     if(g_dubaiNightLastResetTime > 0)
                        nightLeftTxt = StringFormat("NIGHT CLOSE: %02d-%02d READY in %dh%02dm | Rst %s [OK]",
                                                    InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                    hToWin, mToWin, FormatDubaiShortDT(g_dubaiNightLastResetTime, false));
                     else
                        nightLeftTxt = StringFormat("NIGHT CLOSE: %02d-%02d READY in %dh%02dm | Path-B -%.0f%%/%dm",
                                                    InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                    hToWin, mToWin, InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes);
                     nightLeftClr = clrLightGray;
                     if(InpEnableDubaiNightDayProfitClose && dOpenEq > 0.0)
                        nightRightTxt = dForceActive
                                        ? StringFormat("Tgt:>$%.0f | %02d:%02d ALL",
                                                       dDayTgtEq, InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                        : StringFormat("Tgt:>$%.0f | 1-Side=0", dDayTgtEq);
                     else
                        nightRightTxt = dForceActive
                                        ? StringFormat("Ang 0-%.0f | %02d:%02d ALL",
                                                       InpDubaiNightMaxEmaAngleDeg, InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute)
                                        : StringFormat("Ang 0-%.0f | -%.0f%%/%dm",
                                                       InpDubaiNightMaxEmaAngleDeg, InpDubaiNightPartialCutPct, InpDubaiNightCutIntervalMinutes);
                     nightRightClr = clrSilver;
                    }

// ===== DAY EQUITY TARGET BAR =====
   string deqLeftTxt  = "";
   color  deqTxtClr   = clrSilver;
   string deqRightTxt = "";
   color  deqRightClr = clrSilver;
   color  deqBarClr   = C'18,22,34';
     {
      double deqOpenBase   = (g_dayOpeningBalance > 0.0) ? g_dayOpeningBalance : AccountBalance();
      double deqMult       = (balancelomultipler > 0) ? balancelomultipler : 1;
      int    deqHoursDecay = 0;
      double deqDecayUSD   = 0.0;
      double deqTarget     = GetEffectiveDailyTargetEquity(deqHoursDecay, deqDecayUSD);
      double deqCurrent    = AccountEquity();
      double deqProfit     = deqCurrent - deqOpenBase;
      double deqRemaining  = MathMax(0.0, deqTarget - deqCurrent);
      double deqTgtProfit  = deqTarget - deqOpenBase;
      double deqPct        = (deqTgtProfit > 0.0) ? (deqProfit / deqTgtProfit * 100.0) : 0.0;
      string deqSign       = (deqProfit >= 0.0) ? "+" : "";
      string deqStatusTxt  = "";
      double deqPeakProfit = (g_dailyEquityPeakEquity > deqOpenBase) ? (g_dailyEquityPeakEquity - deqOpenBase) : (deqTarget - deqOpenBase);
      double deqFloorPct   = GetDailyEquityRetraceFloorPct(deqPeakProfit);
      double deqFloorUSD   = deqPeakProfit * (deqFloorPct / 100.0);

      if(g_dailyEquityTradingBlocked)
        {
         deqStatusTxt = "PAUSED";
         deqBarClr    = C'50,15,15';
         deqTxtClr    = clrWhite;
         if(g_dailyEquityAdverseLossHitToday)
            deqRightTxt  = StringFormat("P/L:%s$%.2f  PAUSED AT -$%.0f LOSS (TILL %s)", deqSign, deqProfit, DailyEquityMaxLossUSD * deqMult, GetNextSessionWaitHourStr(dDubaiTime));
         else
            deqRightTxt  = StringFormat("P/L:%s$%.2f  PAUSED AT %.0f%% RETRACE (TILL %s)", deqSign, deqProfit, deqFloorPct, GetNextSessionWaitHourStr(dDubaiTime));
         deqRightClr  = clrTomato;

         double pauseBaseUSD = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? g_dailyEquityResumeEquity : deqOpenBase;
         double pauseTgtUSD  = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? (g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult)) : deqTarget;
         string pauseMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
         deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                    deqStatusTxt, pauseBaseUSD, pauseTgtUSD, DailyEquityStopUSD * deqMult, pauseMultTag);
        }
      else
         if(g_deepDrawdownLiveSlClamped)
           {
            deqStatusTxt = "DD-CLAMP";
            deqBarClr    = C'20,45,20';
            deqTxtClr    = clrLime;
            deqRightTxt  = StringFormat("P/L:%s$%.2f  DD RECOVERY CLAMPED (TRAIL SL)", deqSign, deqProfit);
            deqRightClr  = clrLime;
            deqLeftTxt   = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f", deqStatusTxt, deqOpenBase, deqTarget);
           }
         else
            if(g_deepDrawdownCooldownUntil > 0 && TimeCurrent() < g_deepDrawdownCooldownUntil)
              {
               int remainMin = (int)((g_deepDrawdownCooldownUntil - TimeCurrent()) / 60) + 1;
               deqStatusTxt = "DD-PAUSE";
               deqBarClr    = C'40,30,10';
               deqTxtClr    = clrYellow;
               deqRightTxt  = StringFormat("P/L:%s$%.2f  DD COOLDOWN (%dm REMAINING)", deqSign, deqProfit, remainMin);
               deqRightClr  = clrGold;
               deqLeftTxt   = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f", deqStatusTxt, deqOpenBase, deqTarget);
              }
            else
               if(g_deepDrawdownCycleArmed)
                 {
                  double baseThreshold = (g_deepDrawdownCycleStartBalance > 0.0) ? g_deepDrawdownCycleStartBalance : deqOpenBase;
                  double recTarget = (g_deepDrawdownArmedTarget > 0.0) ? g_deepDrawdownArmedTarget : (baseThreshold - (InpDeepDrawdownRecoveryBufferUSD * deqMult));
                  double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
                  double effTarget = recTarget;
                  string angTag = "";
                  if(InpDeepDrawdownSteepAngleDeg > 0.0 && MathAbs(curEmaAng) > InpDeepDrawdownSteepAngleDeg)
                    {
                     double armedTgt = (g_deepDrawdownArmedTarget > 0.0) ? g_deepDrawdownArmedTarget : recTarget;
                     effTarget = armedTgt * (InpDeepDrawdownSteepAngleTargetPct / 100.0);
                     angTag = StringFormat(" [90%%Ang:%.1f°]", curEmaAng);
                    }
                  deqStatusTxt = "DD-ARMED";
                  deqBarClr    = C'45,25,10';
                  deqTxtClr    = clrGold;
                  deqRightTxt  = StringFormat("P/L:%s$%.2f  DD ARMED (TGT:$%.0f%s)", deqSign, deqProfit, effTarget, angTag);
                  deqRightClr  = clrGold;
                  deqLeftTxt   = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f", deqStatusTxt, baseThreshold, effTarget);
                 }
               else
                  if(g_dailyEquityIsResumedLeg && InpResumeDayTradingTargetMode == RESUME_MODE_TRAIL_STEP)
                    {
                     double resStepUSD = DailyEquityTrailStepUSD * deqMult;
                     double resProfit  = deqCurrent - g_dailyEquityResumeEquity;
                     string resSign    = (resProfit >= 0.0) ? "+" : "";
                     deqStatusTxt = (g_dailyEquityStepCount > 0) ? StringFormat("+Step#%d", g_dailyEquityStepCount) : StringFormat("TRAIL+$%.0f", resStepUSD);

                     double resFloorEq = 0.0;
                     if(!g_dailyEquityResumedStepHit)
                       {
                        resFloorEq  = g_dailyEquityResumeSafetyFloor;
                        deqRightTxt = StringFormat("P/L:%s$%.2f  StepTgt:$%.0f  SafetyFloor:$%.0f", resSign, resProfit, g_dailyEquityNextStepTarget, resFloorEq);
                       }
                     else
                       {
                        double legPeakProfit = (g_dailyEquityPeakEquity > g_dailyEquityResumeEquity) ? (g_dailyEquityPeakEquity - g_dailyEquityResumeEquity) : 0.0;
                        double legFloorPct   = GetDailyEquityRetraceFloorPct(legPeakProfit);
                        resFloorEq           = g_dailyEquityResumeEquity + (legPeakProfit * (legFloorPct / 100.0));
                        if(resFloorEq < g_dailyEquityResumeEquity)
                           resFloorEq = g_dailyEquityResumeEquity;
                        deqRightTxt = StringFormat("P/L:%s$%.2f (Peak:$%.2f) Floor:$%.0f", resSign, resProfit, legPeakProfit, resFloorEq);
                       }

                     if(resProfit > 0.0)
                       {
                        deqBarClr   = C'20,40,12';
                        deqTxtClr   = clrGold;
                        deqRightClr = clrGold;
                       }
                     else
                        if(resProfit < -0.01)
                          {
                           deqBarClr   = C'34,16,18';
                           deqTxtClr   = clrWhite;
                           deqRightClr = clrTomato;
                          }
                        else
                          {
                           deqBarClr   = C'18,22,34';
                           deqTxtClr   = clrWhite;
                           deqRightClr = clrWhite;
                          }

                     string resMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
                     double freshDayTarget = g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult);
                     deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                                deqStatusTxt, g_dailyEquityResumeEquity, freshDayTarget, DailyEquityStopUSD * deqMult, resMultTag);
                    }
                  else
                     if(g_dailyEquityTargetHitToday)
                       {
                        deqStatusTxt = (g_dailyEquityStepCount > 0) ? StringFormat("+$5x%d", g_dailyEquityStepCount) : "TRAIL+$5";
                        deqBarClr    = C'20,40,12';
                        deqTxtClr    = clrGold;
                        deqRightTxt  = StringFormat("P/L:%s$%.2f (Peak:$%.2f) Floor%.0f%%:$%.2f",
                                                    deqSign, deqProfit, deqPeakProfit, deqFloorPct, deqFloorUSD);
                        deqRightClr  = clrGold;
                       }
                     else
                        if(deqPct >= 90.0)
                          {
                           deqStatusTxt = "NEAR";
                           deqBarClr    = C'50,40,10';
                           deqTxtClr    = clrGold;
                           deqRightTxt  = StringFormat("P/L:%s$%.2f (%.0f%%)  Rem:$%.2f", deqSign, deqProfit, MathMax(0.0,MathMin(deqPct,100.0)), deqRemaining);
                           deqRightClr  = clrGold;
                          }
                        else
                           if(deqProfit > 0.0)
                             {
                              deqStatusTxt = "ACTIVE";
                              deqBarClr    = C'12,32,20';
                              deqTxtClr    = clrLime;
                              deqRightTxt  = StringFormat("P/L:%s$%.2f (%.0f%%)  Rem:$%.2f", deqSign, deqProfit, MathMax(0.0,MathMin(deqPct,100.0)), deqRemaining);
                              deqRightClr  = clrLime;
                             }
                           else
                              if(deqProfit < -0.01)
                                {
                                 deqStatusTxt = "WAIT";
                                 deqBarClr    = C'34,16,18';
                                 deqTxtClr    = clrWhite;
                                 deqRightTxt  = StringFormat("P/L:%s$%.2f (0%%)  Rem:$%.2f", deqSign, deqProfit, deqRemaining);
                                 deqRightClr  = clrTomato;
                                }
                              else
                                {
                                 deqStatusTxt = "WAIT";
                                 deqBarClr    = C'18,22,34';
                                 deqTxtClr    = clrWhite;
                                 deqRightTxt  = StringFormat("P/L:%s$%.2f (0%%)  Rem:$%.2f", deqSign, deqProfit, deqRemaining);
                                 deqRightClr  = clrWhite;
                                }

      if(!g_dailyEquityIsResumedLeg || InpResumeDayTradingTargetMode != RESUME_MODE_TRAIL_STEP)
        {
         string multTag  = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
         string decayTag = (deqHoursDecay > 0) ? StringFormat(" (%dH-Decay)", deqHoursDecay) : "";
         deqLeftTxt  = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s%s)",
                                    deqStatusTxt, deqOpenBase, deqTarget, deqTgtProfit, multTag, decayTag);
        }

      if(deqLeftTxt == "")
        {
         double fbBaseUSD = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? g_dailyEquityResumeEquity : deqOpenBase;
         double fbTgtUSD  = (g_dailyEquityIsResumedLeg && g_dailyEquityResumeEquity > 0.0) ? (g_dailyEquityResumeEquity + (DailyEquityStopUSD * deqMult)) : deqTarget;
         string fbMultTag = (deqMult > 1) ? StringFormat(" [%dX]", (int)deqMult) : "";
         deqLeftTxt       = StringFormat("DAY: [%s] B:$%.0f  T:$%.0f (+$%.0f%s)",
                                         deqStatusTxt, fbBaseUSD, fbTgtUSD, DailyEquityStopUSD * deqMult, fbMultTag);
        }
     }

   double pGapLeftMid    = (Bid > 0.0 && Ask > 0.0) ? ((Bid + Ask) * 0.5)
                           : ((Bars > 0 && Close[0] > 0.0) ? Close[0] : Bid);
   double pGapLeftAnc    = (g_priceGapCloseAnchorPrice > 0.0) ? g_priceGapCloseAnchorPrice : GetEmaFlipPrice();
   double pGapLeftRaw    = (pGapLeftAnc > 0.0 && pGapLeftMid > 0.0) ? MathAbs(pGapLeftMid - pGapLeftAnc) : 0.0;
   double pGapLeftReq    = (InpPriceGapCloseRawGap > 0.0) ? InpPriceGapCloseRawGap : 1000.0;
   double pGapLeftPctReq = (InpPriceGapCloseDayProfitPct > 0.0) ? InpPriceGapCloseDayProfitPct : 5.0;
   bool   pGapLeftArmed  = (InpEnablePriceGapDayProfitClose && pGapLeftRaw > pGapLeftReq && dOpenEq > 0.0 && dDayEqPct > pGapLeftPctReq);
   bool   pGapAtFlipAnc  = (g_priceGapCloseSourceFlipPx > 0.0 && MathAbs(pGapLeftAnc - g_priceGapCloseSourceFlipPx) <= MathMax(Point, 0.5));
   string pGapAncTag     = pGapAtFlipAnc ? "Flip" : "Next";

   string pGapLeftTxt  = "";
   color  pGapLeftClr  = clrLightGray;
   string pGapRightTxt = "";
   color  pGapRightClr = clrSilver;

   if(!InpEnablePriceGapDayProfitClose)
     {
      pGapLeftTxt  = StringFormat("GAP CLOSE  : OFF (Raw>%.0f & DayEq>%.0f%%)", pGapLeftReq, pGapLeftPctReq);
      pGapLeftClr  = clrSilver;
      pGapRightTxt = "Disabled";
      pGapRightClr = clrSilver;
     }
   else
      if(pGapLeftArmed)
        {
         pGapLeftTxt  = StringFormat("GAP CLOSE  : ARMED Anc %s | Gap %.1f/%.0f | DayEq:%s%.1f%%>%.0f%%",
                                     DoubleToString(pGapLeftAnc, Digits), pGapLeftRaw, pGapLeftReq,
                                     dSign, dDayEqPct, pGapLeftPctReq);
         pGapLeftClr  = clrLime;
         pGapRightTxt = StringFormat("Hits:%d CLOSE ALL", g_priceGapCloseTotalSweeps);
         pGapRightClr = clrLime;
        }
      else
         if(g_priceGapCloseLastHitTime > 0)
           {
            pGapLeftTxt  = StringFormat("GAP CLOSE  : Anc %s (%s) Gap %.1f/%.0f | Last x%d -%.2fL @%s",
                                        DoubleToString(pGapLeftAnc, Digits), pGapAncTag,
                                        pGapLeftRaw, pGapLeftReq,
                                        g_priceGapCloseLastOrders, g_priceGapCloseLastLots,
                                        FormatDubaiShortDT(g_priceGapCloseLastHitTime, false));
            pGapLeftClr  = clrAqua;
            pGapRightTxt = StringFormat("Hits:%d Ord:%d Eq:%s%.1f%%",
                                        g_priceGapCloseTotalSweeps, g_priceGapCloseTotalOrders, dSign, dDayEqPct);
            pGapRightClr = clrAqua;
           }
         else
           {
            pGapLeftTxt  = StringFormat("GAP CLOSE  : Anc %s (%s) | Gap %.1f/%.0f | DayEq:%s%.2f%%/%.0f%%",
                                        DoubleToString(pGapLeftAnc, Digits), pGapAncTag,
                                        pGapLeftRaw, pGapLeftReq, dSign, dDayEqPct, pGapLeftPctReq);
            pGapLeftClr  = clrLightGray;
            pGapRightTxt = StringFormat("Hits:%d Waiting", g_priceGapCloseTotalSweeps);
            pGapRightClr = clrSilver;
           }

   double sLeftEqDdPct  = (liveBal > 0.0 && liveEq < liveBal) ? (((liveBal - liveEq) / liveBal) * 100.0) : 0.0;
   double sLeftActReq   = (InpStepLossActivateSidePct > 0.0) ? InpStepLossActivateSidePct : 10.0;
   double sLeftEmgReq   = (InpStepLossEmergencyDdPct > 0.0) ? InpStepLossEmergencyDdPct : 30.0;
   double sLeftNormGap  = (InpStepLossRawGap > 0.0) ? InpStepLossRawGap : 3000.0;
   double sLeftEmgGap   = (InpStepLossEmergencyRawGap > 0.0) ? InpStepLossEmergencyRawGap : 2000.0;
   bool   sLeftEmerg    = (InpEnableAdversePriceStepLossCut && sLeftEqDdPct > sLeftEmgReq);
   bool   sLeftActive   = (InpEnableAdversePriceStepLossCut && (liveBuyDdPct > sLeftActReq || liveSellDdPct > sLeftActReq));
   string sLossLeftTxt  = "";
   color  sLossLeftClr  = clrLightGray;
   string sLossRightTxt = "";
   color  sLossRightClr = clrSilver;

   if(!InpEnableAdversePriceStepLossCut)
     {
      sLossLeftTxt  = StringFormat("STEP LOSS  : OFF (Adv %.0f/%.0f Cut %.0f%%/%.0f%% + Worst 0.01L)",
                                   sLeftNormGap, sLeftEmgGap, InpStepLossCutPct, InpStepLossEmergencyCutPct);
      sLossLeftClr  = clrSilver;
      sLossRightTxt = "Disabled";
      sLossRightClr = clrSilver;
     }
   else
      if(sLeftEmerg)
        {
         sLossLeftTxt  = StringFormat("STEP LOSS  : EMERGENCY EqDD %.1f%%>%.0f%% | B:%.0f/%.0f S:%.0f/%.0f",
                                      sLeftEqDdPct, sLeftEmgReq,
                                      g_stepLossLastBuyAdv, g_stepLossLastReqBuyGap,
                                      g_stepLossLastSellAdv, g_stepLossLastReqSellGap);
         sLossLeftClr  = clrRed;
         sLossRightTxt = StringFormat("-%.0f%%L + %d Worst 0.01", InpStepLossEmergencyCutPct, InpStepLossEmergMinLotClosePerStep);
         sLossRightClr = clrRed;
        }
      else
         if(g_stepLossLastHitTime > 0)
           {
            sLossLeftTxt  = StringFormat("STEP LOSS  : Last %s#%d @%s | P%d/F%d -%.2fL | B:%.0f S:%.0f",
                                         g_stepLossLastHitSide, g_stepLossTotalSweeps,
                                         FormatDubaiShortDT(g_stepLossLastHitTime, false),
                                         g_stepLossLastHitPartials, g_stepLossLastHitFulls, g_stepLossLastHitLots,
                                         g_stepLossLastBuyAdv, g_stepLossLastSellAdv);
            sLossLeftClr  = clrOrange;
            sLossRightTxt = StringFormat("Sweeps:%d (-%.2fL Tot)", g_stepLossTotalSweeps, g_stepLossTotalLotsCut);
            sLossRightClr = clrOrange;
           }
         else
            if(sLeftActive)
              {
               sLossLeftTxt  = StringFormat("STEP LOSS  : ARMED B:%.1f%% (%.0f/%.0f) S:%.1f%% (%.0f/%.0f)",
                                            liveBuyDdPct, g_stepLossLastBuyAdv, g_stepLossLastReqBuyGap,
                                            liveSellDdPct, g_stepLossLastSellAdv, g_stepLossLastReqSellGap);
               sLossLeftClr  = clrGold;
               sLossRightTxt = StringFormat("-%.0f%%L + %d Worst 0.01", InpStepLossCutPct, InpStepLossMinLotClosePerStep);
               sLossRightClr = clrGold;
              }
            else
              {
               sLossLeftTxt  = StringFormat("STEP LOSS  : MONITOR >%.0f%% Side / %.0f | Emerg >%.0f%% DD / %.0f",
                                            sLeftActReq, sLeftNormGap, sLeftEmgReq, sLeftEmgGap);
               sLossLeftClr  = clrLightGray;
               sLossRightTxt = StringFormat("%.0f%%L + Worst 0.01L", InpStepLossCutPct);
               sLossRightClr = clrSilver;
              }

// ===== DYNAMIC LEFT DASHBOARD BARS (TOGGLEABLE) =====
   curY = y + 38;

   if(InpShowLeftDashHourlyEngineRows)
     {
      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"DD_STATBAR", x, curY, width, 22, C'18,24,34');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DD_STAT_L", ddStatLeftTxt, tx, curY+5, 8, ddStatLeftClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DD_STAT_R", ddStatRightTxt, x+width-186, curY+5, 8, ddStatRightClr);
      curY += 22;

      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"EQDD_HITBAR", x, curY, width, 22, C'14,20,30');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EQDD_HITTXT", ddBannerTxt, tx, curY+5, 8, ddBannerClr);
      curY += 22;

      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"DUBAI_BAR", x, curY, width, 22, C'16,28,44');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DUBAI_TIME", leftDubaiTimeTxt, tx, curY+5, 8, leftDubaiTimeClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DUBAI_STAT", leftDubaiStatTxt, x+252, curY+5, 8, leftDubaiStatClr);
      curY += 22;
     }
   else
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DD_STATBAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DD_STAT_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DD_STAT_R");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"EQDD_HITBAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"EQDD_HITTXT");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_BAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_TIME");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_STAT");
     }

   if(InpShowLeftDashDayEqTargetRow)
     {
      int deqTextY       = curY + ((deqBarHeight - deqFontSize) / 2) - 1;
      int deqRightOffset = (deqFontSize >= 14) ? 290 : 248;
      int deqRightX      = x + width - deqRightOffset;

      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"DEQTGT_BAR", x, curY, width, deqBarHeight, deqBarClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DEQTGT_L",   deqLeftTxt,  tx,        deqTextY, deqFontSize, deqTxtClr,   InpLeftDashDayEqTargetFont);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DEQTGT_R",   deqRightTxt, deqRightX, deqTextY, deqFontSize, deqRightClr, InpLeftDashDayEqTargetFont);
      curY += deqBarHeight;
     }
   else
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_BAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DEQTGT_R");
     }

   if(InpShowLeftDashNightCloseRow)
     {
      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"DUBAI_NIGHTBAR", x, curY, width, 22, C'12,24,38');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DUBAI_NIGHT_L", nightLeftTxt, tx, curY+5, 8, nightLeftClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"DUBAI_NIGHT_R", nightRightTxt, x+width-168, curY+5, 8, nightRightClr);
      curY += 22;
     }
   else
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_NIGHTBAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_NIGHT_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"DUBAI_NIGHT_R");
     }

   if(InpShowLeftDashPriceGapRow)
     {
      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PGAP_BAR", x, curY, width, 22, C'14,22,36');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"PGAP_L", pGapLeftTxt, tx, curY+5, 8, pGapLeftClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"PGAP_R", pGapRightTxt, x+width-168, curY+5, 8, pGapRightClr);
      curY += 22;
     }
   else
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"PGAP_BAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"PGAP_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"PGAP_R");
     }

   if(InpShowLeftDashStepLossRow)
     {
      CreateLeftLivePanel(LEFT_LIVE_PREFIX+"SLOSS_BAR", x, curY, width, 22, C'18,22,34');
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SLOSS_L", sLossLeftTxt, tx, curY+5, 8, sLossLeftClr);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SLOSS_R", sLossRightTxt, x+width-168, curY+5, 8, sLossRightClr);
      curY += 22;
     }
   else
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"SLOSS_BAR");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"SLOSS_L");
      ObjectDelete(0, LEFT_LIVE_PREFIX+"SLOSS_R");
     }

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"SUMMARYBAR", x, curY, width, 42, C'25,31,42');

// Top Row: Buy Lot and Buy P/L , sell LOT and sell P/l - Net P/L
   string topRowText = "BUY " + DoubleToString(buyLots,2) + " (P/L " + buyPLStr + ") , SELL " + DoubleToString(sellLots,2) + " (P/L " + sellPLStr + ") - NET " + netPLStr;
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TOTALS", topRowText, tx, curY+7, 9, pnlColor);

// Second Row: Orders Count Summary
   int revMaxCap   = (InpReverse100MaxActiveOrders > 0) ? InpReverse100MaxActiveOrders : 1;
   int revActCnt   = InpEnableReverse100Order ? CountActiveReverse100Orders() : 0;
   string revBadge = InpEnableReverse100Order
                     ? StringFormat("   REV %d/%d H:%d C:%d", revActCnt, revMaxCap, g_rev100TotalOpened, g_rev100StepCutTotalCuts)
                     : "   REV100 OFF";
   string summaryText = "ORDERS " + IntegerToString(total) + "/" + IntegerToString(MaxOpenOrders) +
                        "   BUY " + IntegerToString(buyCount) +
                        "   SELL " + IntegerToString(sellCount) +
                        "   PEND " + IntegerToString(pendingCount) +
                        revBadge;
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SUMMARY", summaryText, tx, curY+24, 8, clrWhite);
   curY += 42;

   tableHeaderY = curY + 8;
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD_ID", "ORDER ID", tx, tableHeaderY, 8, clrSilver);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD", "TYPE     LOT            SL     GAP      P/L", tx+76, tableHeaderY, 8, clrSilver);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD_CMT", "COMMENT", tx+340, tableHeaderY, 8, clrSilver);

   orderRowsStartY = tableHeaderY + 20;

   for(int r = rows; r < 24; r++)
     {
      ObjectDelete(0, LEFT_LIVE_PREFIX+"ID"+IntegerToString(r));
      ObjectDelete(0, LEFT_LIVE_PREFIX+"ROW"+IntegerToString(r));
      ObjectDelete(0, LEFT_LIVE_PREFIX+"VERIFY"+IntegerToString(r));
     }

   for(int r = 0; r < rows; r++)
     {
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ID"+IntegerToString(r), "", tx, orderRowsStartY+(r*20), 8, clrSilver);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(r), "", tx+76, orderRowsStartY+(r*20), 8, clrWhite);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"VERIFY"+IntegerToString(r), "", tx+340, orderRowsStartY+(r*20), 8, clrSilver);
     }

   int row=0;
   for(int j = 0; j < dashOrderCount && row < rows; j++)
     {
      int type = dashOrders[j].type;
      string typeText="";
      if(type==OP_BUY)
         typeText="BUY";
      else
         if(type==OP_SELL)
            typeText="SELL";
         else
            if(type==OP_BUYSTOP)
               typeText="BUY ST";
            else
               if(type==OP_SELLSTOP)
                  typeText="SELL ST";
               else
                  if(type==OP_BUYLIMIT)
                     typeText="BUY LM";
                  else
                     if(type==OP_SELLLIMIT)
                        typeText="SELL LM";

      double lots=dashOrders[j].lots;
      double open=dashOrders[j].openPrice;
      double sl=dashOrders[j].sl;
      double pl=dashOrders[j].pl;

      // SL Column: Displays Previous Display(New Display) -> e.g. 2028(-) or 150(+1.50)
      double slDiffPoints = 0;
      if(sl > 0)
         slDiffPoints = MathAbs(open - sl) / Point / 100;

      double slLockedUSD = 0.0;
      if(sl > 0.0 && (type == OP_BUY || type == OP_SELL))
         slLockedUSD = CalcOrderLockedProfitUSD(type, open, sl, lots);

      string slProfitStr = "-";
      if(slLockedUSD >= 0.005)
         slProfitStr = "+" + DoubleToString(slLockedUSD, 2);

      string slDiffText = "-";
      if(sl > 0)
         slDiffText = DoubleToString(slDiffPoints, 0) + "(" + slProfitStr + ")";

      int currentTicket=dashOrders[j].ticket;
      datetime currentOpenTime=dashOrders[j].openTime;
      datetime bestPrevTime=0;
      int bestPrevTicket=0;
      double prevSameOrderPrice=-1.0;

      for(int k=0; k<dashOrderCount; k++)
        {
         if(k==j)
            continue;
         int prevType=dashOrders[k].type;
         bool sameDir=false;
         if((type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT) &&
            (prevType==OP_BUY || prevType==OP_BUYSTOP || prevType==OP_BUYLIMIT))
            sameDir=true;
         else
            if((type==OP_SELL || type==OP_SELLSTOP || type==OP_SELLLIMIT) &&
               (prevType==OP_SELL || prevType==OP_SELLSTOP || prevType==OP_SELLLIMIT))
               sameDir=true;

         if(!sameDir)
            continue;

         datetime ot=dashOrders[k].openTime;
         int tk=dashOrders[k].ticket;
         if(ot<currentOpenTime || (ot==currentOpenTime && tk<currentTicket))
           {
            if(bestPrevTime==0 || ot>bestPrevTime || (ot==bestPrevTime && tk>bestPrevTicket))
              {
               bestPrevTime=ot;
               bestPrevTicket=tk;
               prevSameOrderPrice=dashOrders[k].openPrice;
              }
           }
        }

      string gapText="-";
      if(prevSameOrderPrice>0.0)
        {
         int gapDecimals=(Digits<=2) ? 1 : Digits;
         gapText=DoubleToString(MathAbs(open-prevSameOrderPrice),gapDecimals);
        }

      string plText="-";
      if(type==OP_BUY || type==OP_SELL)
         plText=(pl>=0?"+":"")+DoubleToString(pl,2);

      string verifiedStatus=dashOrders[j].comment;
      color verifiedColor=clrSilver;

      string orderIdText="#"+IntegerToString(currentTicket);
      string rowText=StringFormat("%-7s %5.2f %13s %7s %8s", typeText, lots, slDiffText, gapText, plText);
      color rowColor=clrWhite;
      if(type==OP_BUY)
         rowColor=clrDeepSkyBlue;
      else
         if(type==OP_SELL)
            rowColor=clrTomato;
         else
            rowColor=clrGold;

      if((type==OP_BUY || type==OP_SELL) && pl>0)
         rowColor=clrLime;
      if((type==OP_BUY || type==OP_SELL) && pl<0)
         rowColor=clrOrangeRed;
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ID"+IntegerToString(row), orderIdText, tx, orderRowsStartY+(row*20), 8, rowColor);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(row), rowText, tx+76, orderRowsStartY+(row*20), 8, rowColor);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"VERIFY"+IntegerToString(row), verifiedStatus, tx+340, orderRowsStartY+(row*20), 8, verifiedColor);
      row++;
     }
   if(total==0)
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY", "NO ACTIVE EA ORDERS", tx, orderRowsStartY, 9, clrSilver);
   else
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY", "Showing "+IntegerToString(MathMin(total,rows))+" of "+IntegerToString(total)+" orders", tx, orderRowsStartY+(rows*20)+4, 8, clrSilver);
   if(ShowTopCenterDubaiTime)
      UpdateTopCenterDubaiTimeDisplay(force);
   ChartRedraw(0);
  }


//====================================================================
// 4. MAIN RIGHT DASHBOARD DISPLAY
//====================================================================
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(DailyProtectionState &state)
  {
   if(g_dashboardsUserHidden || !ShowDashboard)
      return;

   UpdateOrderCacheIfNeeded();
   int totalOrders   = g_orderCache.totalOrders;
   int buyOrders     = g_orderCache.buyOrders;
   int sellOrders    = g_orderCache.sellOrders;
   int pendingOrders = g_orderCache.buyPending + g_orderCache.sellPending;
   double netProfit  = g_orderCache.buyPL + g_orderCache.sellPL;
   color pnlColor=netProfit>0?clrLime:netProfit<0?clrTomato:clrWhite;
   int currentSSLDirection=GlobalSSLDirection;
   string sslDirection=currentSSLDirection>0?"BUY":currentSSLDirection<0?"SELL":"NONE";
   color sslColor=currentSSLDirection>0?clrDeepSkyBlue:currentSSLDirection<0?clrTomato:clrSilver;
   double ema=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,InpEMAPriceShift);
   string emaState="N/A";
   color emaColor=clrSilver;
   if(ema>0)
     {
      if(Bid>ema)
        {
         emaState="BULLISH";
         emaColor=clrLime;
         EMADirection=1;
        }
      else
         if(Bid<ema)
           {
            emaState="BEARISH";
            emaColor=clrTomato;
            EMADirection=-1;
           }
         else
           {
            emaState="AT EMA";
            emaColor=clrGold;
            EMADirection=0;
           }
     }

   string statusText="READY";
   color statusColor=clrLime;

   if(TradeMonitoringLog!="")
     {
      statusText="PAUSE - Waiting for Angle>2";
      statusColor=clrGold;
     }
   else

      if(!EnableTrading)
        {
         statusText="TRADING DISABLED";
         statusColor=clrTomato;
        }
      else
         if(g_dailyEquityTradingBlocked)
           {
            statusText="DAY TRADING PAUSED";
            statusColor=clrTomato;
           }
         else
            if(TradingHaltedUntilNextFlip)
              {
               statusText="EMA LADDER HALT";
               statusColor=clrTomato;
              }
            else
               if(ServerRecoveryPending)
                 {
                  statusText="SERVER RECOVERY";
                  statusColor=clrGold;
                 }
               else
                  if(!IsConnected())
                    {
                     statusText="NO CONNECTION";
                     statusColor=clrTomato;
                    }
                  else
                     if(IsDailyTradingStopped(state))
                       {
                        statusText="TRADING STOPPED";
                        statusColor=clrTomato;
                       }
                     else
                        if(HasBasketNewOrderLossLimit())
                          {
                           statusText="BASKET RISK LOCK";
                           statusColor=clrOrangeRed;
                          }
                        else
                           if(!ContinueTradingAfterSL && LosingSLCount>=MaxConsecutiveLosingSL && MaxConsecutiveLosingSL>0)
                             {
                              statusText="SL LOSS LIMIT";
                              statusColor=clrTomato;
                             }
                           else
                              if(ProtectedEquityWaitActive)
                                {
                                 statusText="PROTECTED EQUITY WAIT";
                                 statusColor=clrGold;
                                }
                              else
                                 if(EquityResetReEntryPending)
                                   {
                                    statusText="RESET RE-ENTRY PENDING";
                                    statusColor=clrGold;
                                   }
                                 else
                                    if(totalOrders>=MaxOpenOrders)
                                      {
                                       statusText="MAX ORDERS";
                                       statusColor=clrOrangeRed;
                                      }
                                    else
                                       if(buyOrders>0 && sellOrders>0)
                                         {
                                          statusText="HEDGE / MIXED";
                                          statusColor=clrGold;
                                         }
                                       else
                                          if(buyOrders>0)
                                            {
                                             statusText="BUY ACTIVE";
                                             statusColor=clrDeepSkyBlue;
                                            }
                                          else
                                             if(sellOrders>0)
                                               {
                                                statusText="SELL ACTIVE";
                                                statusColor=clrTomato;
                                               }

   double ladderProgress=0;
   if(DayProfitLadderNextTargetEquity>DayProfitLadderProtectionEquity)
     {
      ladderProgress=((AccountEquity()-DayProfitLadderProtectionEquity) / (DayProfitLadderNextTargetEquity-DayProfitLadderProtectionEquity))*100.0;
      if(ladderProgress<0)
         ladderProgress=0;
      if(ladderProgress>100)
         ladderProgress=100;
     }
   double dayPL=AccountEquity()-state.DayStartBalance;
   double dayPLPct=(state.DayStartBalance>0)?(dayPL/state.DayStartBalance)*100.0:0;
   double riskRemaining=BasketNewOrderLossLimitUSD>0 ? BasketNewOrderLossLimitUSD+netProfit : 0;
   if(riskRemaining<0)
      riskRemaining=0;

   string serverText="CONNECTED / OK";
   color serverColor=clrLime;
   if(!IsConnected())
     {
      serverText="NO CONNECTION";
      serverColor=clrTomato;
     }
   else
      if(ServerRecoveryPending)
        {
         serverText="RECOVERY PENDING #"+IntegerToString(ServerRecoveryLastError);
         serverColor=clrGold;
        }
      else
         if(ServerRecoveryLastError!=0)
           {
            serverText="LAST ERROR #"+IntegerToString(ServerRecoveryLastError);
            serverColor=clrGold;
           }

   int x=DashboardRightGap, y=DashboardTopGap, tx=x+12, w=DashboardWidth, panelHeight=950;
   int h1Direction=GetH1Direction();
   int m5Direction=GetM5Direction();
   int dashboardDirection=(currentSSLDirection>0)?1:(currentSSLDirection<0?-1:0);
   string h1Text=h1Direction>0?"BUY":h1Direction<0?"SELL":"NONE";
   string m5Text=m5Direction>0?"BUY":m5Direction<0?"SELL":"NONE";
   bool h1Confirm=(dashboardDirection!=0 && h1Direction==dashboardDirection);
   bool m5Confirm=(dashboardDirection!=0 && m5Direction==dashboardDirection);
   bool emaConfirm=(dashboardDirection!=0 && EMADirection==dashboardDirection);
   bool h1Opposite=(dashboardDirection!=0 && h1Direction==-dashboardDirection);

   double dashboardMomentumDiff=0.0;
   double dashboardMomentumThreshold=MathAbs(Min30MinutePriceDifference);
   bool momentumConfirm=false;
   if(dashboardDirection!=0)
     {
      dashboardMomentumDiff = (dashboardDirection == 1) ? Global30MinDiffBuy : Global30MinDiffSell;
      momentumConfirm=(dashboardDirection==1) ? (dashboardMomentumDiff>dashboardMomentumThreshold) : (dashboardMomentumDiff<-dashboardMomentumThreshold);
     }
   double dashboardATRRatio=GetM5CandleATRRatio();
   bool dashboardExtremeVol=IsExtremeVolatility();

   int dashboardScore=0;
   if(h1Confirm)
      dashboardScore++;
   if(m5Confirm)
      dashboardScore++;
   if(emaConfirm)
      dashboardScore++;
   if(momentumConfirm)
      dashboardScore++;
   GlobalBUYSELLdashboardScore=dashboardScore;

   double dashboardSuggestedLot=0.01;
   if(dashboardScore==1)
      dashboardSuggestedLot=0.01;
   else
      if(dashboardScore==2)
         dashboardSuggestedLot=0.03;
      else
         if(dashboardScore==3)
            dashboardSuggestedLot=0.06;
         else
            if(dashboardScore>=4)
               dashboardSuggestedLot=0.10;

   if(CapLotWhenH1Opposite && h1Opposite)
      dashboardSuggestedLot=MathMin(dashboardSuggestedLot,0.01);
   if(dashboardExtremeVol)
      dashboardSuggestedLot=MathMin(dashboardSuggestedLot,MathAbs(VolatilityLotCap));

   int dayOfWeekDash = TimeDayOfWeek(TimeCurrent());
   if(dayOfWeekDash == 0 || dayOfWeekDash == 6)
      dashboardSuggestedLot = MathMin(dashboardSuggestedLot, 0.02);

   int dashboardLotMultiplier=(int)(AccountEquity()/AccountMultiplierLOT);
   if(dashboardLotMultiplier<1)
      dashboardLotMultiplier=1;
   double dashboardFinalLot=NormalizeLots(MathMin(0.10,dashboardSuggestedLot*dashboardLotMultiplier));

   string h1Mark=h1Confirm?"PASS":(h1Opposite?"OPPOSITE":"NO");
   string m5Mark=m5Confirm?"PASS":"NO";
   string emaMark=emaConfirm?"PASS":"NO";
   string momMark=momentumConfirm?"PASS":"NO";
   color h1Color=h1Confirm?clrLime:(h1Opposite?clrTomato:clrGold);
   color m5Color=m5Confirm?clrLime:clrTomato;
   color emaConfirmColor=emaConfirm?clrLime:clrTomato;
   color momentumColor=momentumConfirm?clrLime:clrTomato;
   string scoreText="SCORE        : "+IntegerToString(dashboardScore)+" / 4  -> LOT "+DoubleToString(dashboardFinalLot,2);
   color scoreColor=(h1Opposite||dashboardExtremeVol)?clrGold:(dashboardScore>=3?clrLime:(dashboardScore>=1?clrGold:clrTomato));

   int checkDir = (currentSSLDirection > 0) ? OP_BUY : OP_SELL;
   string strong = (currentSSLDirection != 0 && IsStrongMomentum(checkDir)) ? "STRONG" : "Normal";

   if(GetCachedPatternDirection()==1)
      strong=strong+" Double";
   else
      if(GetCachedPatternDirection()==-1)
         strong=strong+" - ";

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
      strong=" Weak";
   else
      strong= " STRONG";

   string txLock="FLIP Step "+FlipLadderStepUSD*balancelomultipler+"% Day Stop $"+DailyEquityStopUSD*balancelomultipler+""+" Flip Stop $"+TargetProfitPerFlipUSD*balancelomultipler+"";

   if(!g_dashRedesignV5Reset)
     {
      DeleteDashboardObjects();
      g_dashRedesignV5Reset = true;
     }

   if(FlipLadderStepUSD <= 0)
      FlipLadderStepUSD = 5;
   int currEmaLvl = (int)MathFloor(HighestCycleProfitUSD / (FlipLadderStepUSD * balancelomultipler));
   double emaLockedPrf = (currEmaLvl >= 1) ? (currEmaLvl - FlipStepbackLevelCount) * (FlipLadderStepUSD * balancelomultipler) : 0.0;
   double emaNextTarget = (currEmaLvl + 1) * FlipLadderStepUSD * balancelomultipler;
   double totalCycleProfit = profitAfterFlip + GetEAFloatingPL();

// Scan order status for regular baskets, pending orders, recovery orders, and support orders
   int regBuyOrders = 0;
   int regSellOrders = 0;
   double regBuyLots = 0.0;
   double regSellLots = 0.0;
   double regBuyPL = 0.0;
   double regSellPL = 0.0;

   int pendingBuyCount = 0;
   int pendingSellCount = 0;
   double pendingBuyPrice = 0.0;
   double pendingSellPrice = 0.0;

   int recCount = 0;
   int recTicket = 0;
   int recType = -1;
   double recLots = 0.0;
   double recPL = 0.0;

   int flipCount = 0;
   int flipTicket = 0;
   double flipLots = 0.0;
   double flipPL = 0.0;

   for(int ordIdx = OrdersTotal() - 1; ordIdx >= 0; ordIdx--)
     {
      if(!OrderSelect(ordIdx, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      int tkt = OrderTicket();
      string cmt = OrderComment();
      double lts = OrderLots();
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      double oPrice = OrderOpenPrice();

      if(oType == OP_BUY)
        {
         if(IsAnyRecoveryOrder(tkt, cmt))
           {
            recCount++;
            recTicket = tkt;
            recType = OP_BUY;
            recLots += lts;
            recPL += pl;
           }
         else
            if(IsFLIPBasketSupportOrder(tkt, cmt))
              {
               flipCount++;
               flipTicket = tkt;
               flipLots += lts;
               flipPL += pl;
               regBuyOrders++;
               regBuyLots += lts;
               regBuyPL += pl;
              }
            else
              {
               regBuyOrders++;
               regBuyLots += lts;
               regBuyPL += pl;
              }
        }
      else
         if(oType == OP_SELL)
           {
            if(IsAnyRecoveryOrder(tkt, cmt))
              {
               recCount++;
               recTicket = tkt;
               recType = OP_SELL;
               recLots += lts;
               recPL += pl;
              }
            else
               if(IsFLIPBasketSupportOrder(tkt, cmt))
                 {
                  flipCount++;
                  flipTicket = tkt;
                  flipLots += lts;
                  flipPL += pl;
                  regSellOrders++;
                  regSellLots += lts;
                  regSellPL += pl;
                 }
               else
                 {
                  regSellOrders++;
                  regSellLots += lts;
                  regSellPL += pl;
                 }
           }
         else
            if(oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
              {
               pendingBuyCount++;
               pendingBuyPrice = oPrice;
              }
            else
               if(oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
                 {
                  pendingSellCount++;
                  pendingSellPrice = oPrice;
                 }
     }

   w = MathMax(DashboardWidth, 375);
   panelHeight = 630;
   x = DashboardRightGap;
   y = DashboardTopGap;
   tx = x + 12;

   if(!g_dashRedesignV11Reset)
     {
      DeleteDashboardObjects();
      g_dashRedesignV11Reset = true;
     }

// Base Background Panel
   CreateDashboardPanel(DASH_PREFIX+"PANEL", x, y, w, panelHeight, C'14,18,24');

// Header Bar
   CreateDashboardPanel(DASH_PREFIX+"HEADER", x, y, w, 36, C'20,55,90');
   string eaTitle = StringFormat("%s | %s %s", glbVersion, Symbol(), TimeframeToString(Period()));
   if(InpHideBidAskRightDashboard)
     {
      CreateDashboardLabel(DASH_PREFIX+"TITLE", eaTitle, tx, y+10, 9, clrWhite);
      ObjectDelete(0, DASH_PREFIX+"PRICE");
     }
   else
     {
      CreateDashboardLabel(DASH_PREFIX+"TITLE", eaTitle, tx, y+4, 9, clrWhite);
      string priceStatus = StringFormat("BID: %." + IntegerToString(Digits) + "f | ASK: %." + IntegerToString(Digits) + "f | SPR: %d pts", Bid, Ask, (int)MarketInfo(Symbol(), MODE_SPREAD));
      CreateDashboardLabel(DASH_PREFIX+"PRICE", priceStatus, tx, y+19, 8, clrLightGray);
     }

// Status Line
   string regimeTag = (InpEnableTwoRegimeSystem) ? (" | " + GetTwoRegimeStatusDisplay()) : "";
   color dispStatusColor = (InpEnableTwoRegimeSystem && g_currentTradingRegime == REGIME_2_CRISIS_CLIMAX) ? clrOrangeRed : statusColor;
   CreateDashboardLabel(DASH_PREFIX+"STATUS", "EA STATUS   : " + statusText + regimeTag, tx, y+39, 9, dispStatusColor);

// ==========================================================
// SECTION 1: CAPITAL & EQUITY TARGETS
// ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_ACC", x, y+58, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"ACC_H", "--- CAPITAL & EQUITY TARGETS ---", tx, y+60, 8, clrAqua);

   string balEqStr = StringFormat("BALANCE / EQ: $%.2f / $%.2f (%dX)", AccountBalance(), AccountEquity(), balancelomultipler);
   CreateDashboardLabel(DASH_PREFIX+"BALEQ", balEqStr, tx, y+78, 8, clrWhite);

// Live Withdrawal Advisor
   double curBal = AccountBalance();
   double curEq = AccountEquity();
   double effectiveCap = MathMin(curBal, curEq);
   double safeWorkingBuffer = MathMax(MinimumOpeningBalanceUSD, InpMinSafeWorkingCapital);
   if(safeWorkingBuffer <= 0.0)
      safeWorkingBuffer = 500.0;

   double maxSafeWithdraw = MathMax(0.0, effectiveCap - safeWorkingBuffer);
   double recWithdraw = 0.0;
   string wdNote = "";
   color wdColor = clrSilver;

   bool isFlatAccount = (totalOrders == 0 && regBuyOrders == 0 && regSellOrders == 0 && recCount == 0);

   if(maxSafeWithdraw <= 0.0)
     {
      recWithdraw = 0.0;
      wdNote = StringFormat("[Cushion < $%.0f]", safeWorkingBuffer);
      wdColor = clrSilver;
     }
   else
      if(effectiveCap >= (safeWorkingBuffer * 2.0) && maxSafeWithdraw >= safeWorkingBuffer)
        {
         recWithdraw = safeWorkingBuffer;
         wdNote = isFlatAccount ? "[RECOUP SEED: READY]" : "[RECOUP SEED: WAIT]";
         wdColor = isFlatAccount ? clrLime : clrGold;
        }
      else
         if(maxSafeWithdraw >= 50.0)
           {
            recWithdraw = MathFloor(maxSafeWithdraw / 25.0) * 25.0;
            if(recWithdraw < 25.0)
               recWithdraw = maxSafeWithdraw;
            wdNote = isFlatAccount ? "[HARVEST: READY]" : "[HARVEST: WAIT]";
            wdColor = isFlatAccount ? clrLime : clrGold;
           }
         else
           {
            recWithdraw = maxSafeWithdraw;
            wdNote = isFlatAccount ? "[PROFIT W/D: READY]" : "[PROFIT W/D: WAIT]";
            wdColor = isFlatAccount ? clrLime : clrGold;
           }

   string withdrawStr = "";
   if(recWithdraw > 0.0)
      withdrawStr = StringFormat("REC. WITHDRAW: $%.2f (Max: $%.2f) %s", recWithdraw, maxSafeWithdraw, wdNote);
   else
      withdrawStr = StringFormat("REC. WITHDRAW: $0.00 (Keep $%.0f Buffer) %s", safeWorkingBuffer, wdNote);

   CreateDashboardLabel(DASH_PREFIX+"WITHDRAW", withdrawStr, tx, y+94, 8, wdColor);

   string tgtEqStr = StringFormat("TARGET EQ   : $%.2f (Hits: %d) | Day: %s$%.2f (%s%.1f%%)", gbltargetEquity, gbltargetEquityCounter, (dayPL >= 0 ? "+" : "-"), MathAbs(dayPL), (dayPL >= 0 ? "+" : ""), dayPLPct);
   color tgtClr = (gbltargetEquityCounter > 0 || dayPL >= 0) ? clrLime : clrTomato;
   CreateDashboardLabel(DASH_PREFIX+"TGTEQ", tgtEqStr, tx, y+110, 8, tgtClr);

   string cycleStr = StringFormat("CYCLE / LOCK: %s$%.2f / Next: $%.2f | Lock: $%.2f", (totalCycleProfit >= 0 ? "+" : "-"), MathAbs(totalCycleProfit), emaNextTarget, emaLockedPrf);
   CreateDashboardLabel(DASH_PREFIX+"LAD_CYCLE", cycleStr, tx, y+126, 8, (totalCycleProfit >= 0 ? clrLime : clrTomato));

// ==========================================================
// SECTION 2: BASKETS & FLOATING P/L
// ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_BSK", x, y+146, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"BSK_H", "--- BASKETS & FLOATING P/L ($2x TARGET + TRAIL) ---", tx, y+148, 8, clrAqua);

   double targetProfit = GetDynamicBasketProfitTarget() * (balancelomultipler > 0 ? balancelomultipler : 1);

   string buyStatus = (regBuyPL >= targetProfit && regBuyOrders > 0) ? "[READY TO CLOSE]" : StringFormat("[Tgt: >$%.2f]", targetProfit);
   color buyClr = (regBuyPL >= targetProfit && regBuyOrders > 0) ? clrLime : (regBuyPL > 0 ? clrDeepSkyBlue : (regBuyOrders > 0 ? clrTomato : clrSilver));
   string buyBskStr = StringFormat("BUY BASKET  : (%d | %.2fL) %s$%.2f  %s", regBuyOrders, regBuyLots, (regBuyPL >= 0 ? "+" : "-"), MathAbs(regBuyPL), buyStatus);
   CreateDashboardLabel(DASH_PREFIX+"BSK_BUY", buyBskStr, tx, y+166, 8, buyClr);

   string sellStatus = (regSellPL >= targetProfit && regSellOrders > 0) ? "[READY TO CLOSE]" : StringFormat("[Tgt: >$%.2f]", targetProfit);
   color sellClr = (regSellPL >= targetProfit && regSellOrders > 0) ? clrLime : (regSellPL > 0 ? clrDeepSkyBlue : (regSellOrders > 0 ? clrTomato : clrSilver));
   string sellBskStr = StringFormat("SELL BASKET : (%d | %.2fL) %s$%.2f  %s", regSellOrders, regSellLots, (regSellPL >= 0 ? "+" : "-"), MathAbs(regSellPL), sellStatus);
   CreateDashboardLabel(DASH_PREFIX+"BSK_SELL", sellBskStr, tx, y+182, 8, sellClr);

   double netPL = regBuyPL + regSellPL;
   double totLots = regBuyLots + regSellLots + recLots;
   string netStr = StringFormat("NET FLOAT   : %s$%.2f | Orders: %d/%d (Lots: %.2fL)", (netPL >= 0 ? "+" : "-"), MathAbs(netPL), totalOrders, MaxOpenOrders, totLots);
   CreateDashboardLabel(DASH_PREFIX+"FLOAT", netStr, tx, y+198, 8, (netPL >= 0 ? clrLime : clrTomato));

// ==========================================================
// SECTION 3: TREND & SIGNALS (Merged & High-Density)
// ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_SIG", x, y+218, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"SIG_H", "--- TREND & SIGNALS ---", tx, y+220, 8, clrAqua);

// 1. Trend & SSL Direction + Strength + Angle
   string emaShortDir = (EMADirection == 1) ? "BULL (+1)" : (EMADirection == -1 ? "BEAR (-1)" : "FLAT (0)");
   bool isEmaWeak = IsEmaWEAKDistanceReduced50PercentFromPeak();
   string emaStrength = isEmaWeak ? "WEAK" : "STRONG";
   string spikeTag = (EMADirection == 1 && GlobalEmaAngle30 < 0.0) ? ", SPIKE BULL" : ((EMADirection == -1 && GlobalEmaAngle30 > 0.0) ? ", SPIKE BEAR" : "");
   if(InpEnableSpikeProfitLadder)
     {
      double mult = (InpSpikeLadderUseMultiplier && balancelomultipler > 0) ? (double)balancelomultipler : 1.0;
      double minToProtect = InpSpikeMinProfitToProtectUSD * mult;
      if(g_spikeBuyBucketPeakPL >= minToProtect)
         spikeTag += StringFormat(" [LAD: B Pk=$%.1f Flr=$%.1f]", g_spikeBuyBucketPeakPL, g_spikeBuyBucketPeakPL * (InpSpikeLadderProtectPct / 100.0));
      if(g_spikeSellBucketPeakPL >= minToProtect)
         spikeTag += StringFormat(" [LAD: S Pk=$%.1f Flr=$%.1f]", g_spikeSellBucketPeakPL, g_spikeSellBucketPeakPL * (InpSpikeLadderProtectPct / 100.0));
     }
   string sslShortDir = (currentSSLDirection > 0) ? "BUY (+1)" : (currentSSLDirection < 0 ? "SELL (-1)" : "NONE");
   if(InpFollowEmaIgnoreSsl && ((EMADirection == 1 && currentSSLDirection < 0) || (EMADirection == -1 && currentSSLDirection > 0)))
      sslShortDir += " (IGNORED)";
   color trendColor = (EMADirection == 1) ? clrLime : (EMADirection == -1 ? clrTomato : clrGold);
   string trendStr = StringFormat("TREND & SSL : EMA: %s [%s, %+.1f deg%s] | SSL: %s", emaShortDir, emaStrength, GlobalEmaAngle30, spikeTag, sslShortDir);
   CreateDashboardLabel(DASH_PREFIX+"TREND", trendStr, tx, y+238, 8, trendColor);

// 2. EMA Distances: Live, Current Peak, Previous Peak
   if(g_prevEmaHighestDistance <= 0.0)
     {
      InitializePreviousEmaCycleValues();
     }

   double currHighestDist = 0.0;
   if(EMADirection == 1)
      currHighestDist = GetHighestEmaDistanceSinceEmaFlip();
   else
      if(EMADirection == -1)
         currHighestDist = GetLowestEmaDistanceSinceEmaFlip();
      else
         currHighestDist = MathMax(GetHighestEmaDistanceSinceEmaFlip(), GetLowestEmaDistanceSinceEmaFlip());

   double liveEmaVal = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double liveEmaDist = (liveEmaVal > 0.0) ? MathAbs(Bid - liveEmaVal) : 0.0;

   double mult4X = (InpEmaFlipWideBreathingMultiplier > 0.0) ? InpEmaFlipWideBreathingMultiplier : 4.0;
   double extraSafe = (InpEmaFlipWideBreathingSafeExtraRaw > 0.0) ? InpEmaFlipWideBreathingSafeExtraRaw : 100.0;
   double minFloor = (InpEmaFlipWideBreathingMinFloorRaw > 0.0) ? InpEmaFlipWideBreathingMinFloorRaw : 1000.0;
   double currBuffer4X = MathMax(minFloor, (currHighestDist * mult4X) + extraSafe);

   g_currentEmaHighestDistance = currHighestDist;
   g_currentEma4XBuffer        = currBuffer4X;
   g_currentEmaPeakPrice       = (EMADirection == 1 ? GetHighestPriceSinceEmaFlip() : GetLowestPriceSinceEmaFlip());

   string emaDistStr = StringFormat("EMA DISTANCE: Live: $%.1f | Peak: $%.1f | Prev: $%.1f", liveEmaDist, currHighestDist, g_prevEmaHighestDistance);
   CreateDashboardLabel(DASH_PREFIX+"EMA_DIST", emaDistStr, tx, y+254, 8, clrWhite);

// 3. LSD Sweep Summary
   bool hasRedLine = IsLsdSweepRedLinePresent();
   bool hasGreenLine = IsLsdSweepGreenLinePresent();
   string lsdSigName = (g_rememberedSweepSignal != "" ? g_rememberedSweepSignal : (g_lastSweepType != "" ? g_lastSweepType : "NONE"));
   color lsdClr = (lsdSigName == "SSLS") ? clrLime : (lsdSigName == "BSLS" ? clrTomato : clrSilver);
   string lineDesc = hasRedLine ? "RED (EQH-R)" : (hasGreenLine ? "GREEN (EQH-G)" : "Scanning");
   int actSweep = GetActiveLsdSweepSignalForGap();
   string gapAdvice = "1X";
   if(actSweep == -1)
      gapAdvice = "BUY 2X Guard";
   else
      if(actSweep == 1)
         gapAdvice = "SELL 2X Guard";
   string lsdSummary = StringFormat("LSD SWEEP   : %s | Line: %s | %s", lsdSigName, lineDesc, gapAdvice);
   CreateDashboardLabel(DASH_PREFIX+"SWEEP", lsdSummary, tx, y+270, 8, lsdClr);

// ==========================================================
// SECTION 4: SPECIAL ORDERS & RISK (Dynamic & Clean)
// ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_RSK", x, y+290, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"RSK_H", "--- SPECIAL ORDERS & RISK ---", tx, y+292, 8, clrAqua);

// Dynamic Special Orders: Pending / Recovery / Flip Support
   string spcSummary = "";
   color spcColor = clrSilver;
   if(recCount > 0)
     {
      spcSummary = StringFormat("RECOVERY #%d (%s %.2fL) %s$%.2f", recTicket, (recType == OP_BUY ? "BUY" : "SELL"), recLots, (recPL >= 0 ? "+" : "-"), MathAbs(recPL));
      spcColor = (recPL >= 0 ? clrLime : clrTomato);
     }
   else
      if(flipCount > 0)
        {
         spcSummary = StringFormat("FLIP SUPPORT #%d (%.2fL) %s$%.2f", flipTicket, flipLots, (flipPL >= 0 ? "+" : "-"), MathAbs(flipPL));
         spcColor = (flipPL >= 0 ? clrLime : clrGold);
        }
      else
         if(pendingBuyCount > 0 && pendingSellCount > 0)
           {
            double actBGap = GetSSLLongShortPendingGapRaw(OP_BUY, false);
            double actSGap = GetSSLLongShortPendingGapRaw(OP_SELL, false);
            spcSummary = StringFormat("BUY ($%.0f) & SELL ($%.0f) STOPS Active", actBGap, actSGap);
            spcColor = clrGold;
           }
         else
            if(pendingBuyCount > 0)
              {
               double actBGap = GetSSLLongShortPendingGapRaw(OP_BUY, false);
               spcSummary = StringFormat("BUY STOP @ %." + IntegerToString(Digits) + "f ($%.0f Gap%s)", pendingBuyPrice, actBGap, (actBGap > SSLLongShortPendingGapRaw ? " [2X]" : ""));
               spcColor = clrDeepSkyBlue;
              }
            else
               if(pendingSellCount > 0)
                 {
                  double actSGap = GetSSLLongShortPendingGapRaw(OP_SELL, false);
                  spcSummary = StringFormat("SELL STOP @ %." + IntegerToString(Digits) + "f ($%.0f Gap%s)", pendingSellPrice, actSGap, (actSGap > SSLLongShortPendingGapRaw ? " [2X]" : ""));
                  spcColor = clrTomato;
                 }
               else
                 {
                  spcSummary = "NONE (Market Active)";
                  spcColor = clrSilver;
                 }
   CreateDashboardLabel(DASH_PREFIX+"SPECIAL_ORD", "SPECIAL ORDS: " + spcSummary, tx, y+310, 8, spcColor);

// Day Risk Line
   string dayRiskStr = StringFormat("DAY RISK    : Tgt +$%.0f | MaxLoss -$%.0f | Room $%.2f [%s]", DailyEquityStopUSD * balancelomultipler, DailyEquityMaxLossUSD * balancelomultipler, riskRemaining, (g_dailyEquityTradingBlocked ? "PAUSED" : "OK"));
   color dayRiskClr = HasBasketNewOrderLossLimit() ? clrTomato : clrLime;
   CreateDashboardLabel(DASH_PREFIX+"DAY_RISK", dayRiskStr, tx, y+326, 8, dayRiskClr);

// ==========================================================
// SECTION 5: RLF & EQL PROTECTION & LADDER
// ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_RLF_EQL", x, y+346, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"RLF_EQL_H", "--- RLF (RELIEF SL) & EQL (EQUITY LADDER) ---", tx, y+348, 8, clrAqua);

// --- RLF Status Line ---
   double curDD = MathMax(0.0, AccountBalance() - AccountEquity());
   double rlfMult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double rlfMinPeak = InpDrawdownReliefMinPeakUSD * rlfMult;
   double rlfTargetDD = g_drawdownReliefPeakUSD * (1.0 - InpDrawdownReliefPercent);
   string rlfState = "OFF";
   color rlfClr = clrSilver;
   if(!InpEnableDrawdownReliefTightenSL)
     {
      rlfState = "DISABLED";
      rlfClr = clrSilver;
     }
   else
      if(g_drawdownReliefExecuted)
        {
         rlfState = StringFormat("ACTIVE [SL Set, Hits: %d]", g_drawdownReliefHitSuccessCount);
         rlfClr = clrLime;
        }
      else
         if(g_drawdownReliefArmed)
           {
            rlfState = StringFormat("ARMED [Need DD <= $%.0f]", rlfTargetDD);
            rlfClr = clrGold;
           }
         else
            if(g_drawdownReliefPeakUSD > 0.0)
              {
               rlfState = StringFormat("TRACKING [Peak $%.0f < $%.0f]", g_drawdownReliefPeakUSD, rlfMinPeak);
               rlfClr = clrDeepSkyBlue;
              }
            else
              {
               rlfState = StringFormat("IDLE [DD: $%.1f / Req $%.0f]", curDD, rlfMinPeak);
               rlfClr = clrLightGray;
              }

   string rlfLine1 = StringFormat("RLF RELIEF  : %s", rlfState);
   CreateDashboardLabel(DASH_PREFIX+"RLF_LINE1", rlfLine1, tx, y+366, 8, rlfClr);

// --- RLF Metrics & 2H Gate ---
   double live2hDiff = Get2HourPriceDifferenceRaw();
   string rlfGate2h = (InpDrawdownReliefMinPriceDiff2Hours > 0.0) ?
                      StringFormat("2H: $%.0f/$%.0f", live2hDiff, InpDrawdownReliefMinPriceDiff2Hours) : "2H: OFF";
   string rlfLine2 = StringFormat("RLF METRICS : Peak $%.1f | DD $%.1f | %s | Exec: %d",
                                  g_drawdownReliefPeakUSD, curDD, rlfGate2h, g_drawdownReliefAppliedCount);
   CreateDashboardLabel(DASH_PREFIX+"RLF_LINE2", rlfLine2, tx, y+382, 8, clrWhite);

// --- EQL Status Line ---
   double eqlStep = InpEquityProfitLadderStepUSD * (InpEquityLadderUseMultiplier && balancelomultipler > 0 ? balancelomultipler : 1.0);
   string eqlState = "";
   color eqlClr = clrSilver;
   if(!InpEnableEquityProfitLadder5)
     {
      eqlState = "DISABLED";
      eqlClr = clrSilver;
     }
   else
      if(LowestEquity <= 0.0)
        {
         eqlState = StringFormat("SCANNING [Step $%.0f | SL: -$%.0f raw]", eqlStep, InpEquityLadderSLDistanceRaw);
         eqlClr = clrDeepSkyBlue;
        }
      else
        {
         datetime minNextAllowed = g_lastEquityLadderHitTime + (datetime)(InpEquityLadderMinGapHours * 3600.0);
         if(InpEquityLadderMinGapHours > 0.0 && g_lastEquityLadderHitTime > 0 && TimeCurrent() < minNextAllowed)
           {
            double remHours = (double)(minNextAllowed - TimeCurrent()) / 3600.0;
            eqlState = StringFormat("COOLING [Wait %.1fh | Hits: #%d]", remHours, g_equityLadderStepCounter);
            eqlClr = clrGold;
           }
         else
           {
            double toTgt = g_equityLadderNextTarget - AccountEquity();
            eqlState = StringFormat("ACTIVE [Tgt $%.0f (+$%.0f) | Step #%d]", g_equityLadderNextTarget, MathMax(0.0, toTgt), g_equityLadderStepCounter);
            eqlClr = (toTgt <= 0.0) ? clrLime : clrAqua;
           }
        }
   string eqlLine1 = StringFormat("EQL LADDER  : %s", eqlState);
   CreateDashboardLabel(DASH_PREFIX+"EQL_LINE1", eqlLine1, tx, y+398, 8, eqlClr);

// --- EQL Metrics & 2H Gate ---
   string eqlGate2h = (InpEquityLadderMinPriceDiff2Hours > 0.0) ?
                      StringFormat("2H: $%.0f/$%.0f", live2hDiff, InpEquityLadderMinPriceDiff2Hours) : "2H: OFF";
   string eqlEmaStr = isEmaWeak ? "WEAK" : "STRONG";
   string eqlLine2 = StringFormat("EQL METRICS : Low $%.0f | Step $%.0f | %s | EMA: %s",
                                  LowestEquity, eqlStep, eqlGate2h, eqlEmaStr);
   CreateDashboardLabel(DASH_PREFIX+"EQL_LINE2", eqlLine2, tx, y+414, 8, clrWhite);

// --- EQ-DD Pure Per-Side (BUY / SELL) Current Status & Latest Chronological Event ---
   double dashBal = (g_dayOpeningBalance > 0.0) ? g_dayOpeningBalance :
                    ((g_dubaiDayOpeningEquity > 0.0) ? g_dubaiDayOpeningEquity : AccountBalance());
   double dashBuyPL = 0.0, dashBuyDdPct = 0.0, dashSellPL = 0.0, dashSellDdPct = 0.0;
   int    dashBuyCnt = 0, dashSellCnt = 0;
   CalcEqDdSideDrawdowns(dashBal, dashBuyPL, dashBuyDdPct, dashSellPL, dashSellDdPct, dashBuyCnt, dashSellCnt);
   double dashCutB = 0.0, dashCutS = 0.0;
   int    dashTierB = InpEnableEqDdLotReduction ? ResolveEqDdTierAndCut(dashBuyDdPct, dashCutB) : 0;
   int    dashTierS = InpEnableEqDdLotReduction ? ResolveEqDdTierAndCut(dashSellDdPct, dashCutS) : 0;
   int    dashMaxTier = MathMax(dashTierB, dashTierS);
   int    dashMaxDone = MathMax(g_eqDdBuyCycleHighestTier, g_eqDdSellCycleHighestTier);
   bool   dashWaitBuy  = (InpEnableEqDdLotReduction && dashTierB > 0 && g_eqDdBuyLastReachTime  > 0 &&
                          dashTierB >= g_eqDdBuyLastReachTier  && g_eqDdBuyLastReachTime  > g_eqDdBuyLastHitTime  && g_eqDdBuyLastReachReason  != "");
   bool   dashWaitSell = (InpEnableEqDdLotReduction && dashTierS > 0 && g_eqDdSellLastReachTime > 0 &&
                          dashTierS >= g_eqDdSellLastReachTier && g_eqDdSellLastReachTime > g_eqDdSellLastHitTime && g_eqDdSellLastReachReason != "");
   bool   dashPending  = (dashWaitBuy || dashWaitSell);
   bool   dashHrlyBreach = (InpEnableHourlySideLossCut && InpEnableHourlyPlanBSideLossCut &&
                            (dashBuyDdPct > InpHourlySideLossThresholdPct || dashSellDdPct > InpHourlySideLossThresholdPct));
   string dashHrlyNxt = (g_hourlySideLossNextRunTime > 0)
                        ? TimeToString(g_hourlySideLossNextRunTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                        : "--:--";
   string dashHrlyCNxt = (g_hourlyPlanCNextRunTime > 0)
                         ? TimeToString(g_hourlyPlanCNextRunTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                         : "--:--";
   datetime hrlyDashNow   = TimeCurrent();
   datetime hrlyDashDub   = (hrlyDashNow > 0) ? (hrlyDashNow + (ServerToDubaiOffsetHours * 3600)) : 0;
   int      hrlyDashDay   = (hrlyDashDub > 0) ? GetDubai16TradingDayKey(hrlyDashDub) : -1;
   double   hrlyDashOpen  = (g_dubaiDayOpeningEquity > 0.0 && g_dubaiNightCloseDayKey == hrlyDashDay)
                            ? g_dubaiDayOpeningEquity : AccountEquity();
   double   hrlyDashEqPct = (hrlyDashOpen > 0.0) ? (((AccountEquity() - hrlyDashOpen) / hrlyDashOpen) * 100.0) : 0.0;
   string   hrlyDashSign  = (hrlyDashEqPct >= 0.0) ? "+" : "";
   double   hrlyDashAThr  = (InpHourlyPlanADayProfitPct > 0.0) ? InpHourlyPlanADayProfitPct : 5.0;
   double   hrlyDashCThr  = (InpHourlyPlanCDayProfitPct > 0.0) ? InpHourlyPlanCDayProfitPct : 10.0;
   int      hrlyDashDMin  = 1;
   long     hrlyDashDHour = 0;
   double   hrlyDashDThr  = ResolveHourlyPlanDMinuteAndThreshold(hrlyDashNow, hrlyDashDMin, hrlyDashDHour);
   bool     hrlyDashDLock = ((InpHourlyPlanDOncePerHour && g_hourlyPlanDDoneHourSlot == hrlyDashDHour) ||
                             (InpHourlyPlanDOncePerDay && g_hourlyPlanDDoneToday));
   double   dOpenA = 0.0, dTgtA = 0.0, dValA = 0.0;
   double   dReqEqA = GetHourlyPlanRequiredEquity(hrlyDashAThr, dOpenA, dTgtA, dValA);
   double   dOpenC = 0.0, dTgtC = 0.0, dValC = 0.0;
   double   dReqEqC = GetHourlyPlanRequiredEquity(hrlyDashCThr, dOpenC, dTgtC, dValC);
   double   dOpenD = 0.0, dTgtD = 0.0, dValD = 0.0;
   double   dReqEqD = GetHourlyPlanRequiredEquity(hrlyDashDThr, dOpenD, dTgtD, dValD);
   double   dCurEq  = AccountEquity();

   bool     hrlyDashPlanA = (InpEnableHourlySideLossCut && InpEnableHourlyPlanADayProfitClose &&
                             (!InpHourlyPlanAOncePerDay || !g_hourlyPlanADoneToday) &&
                             dOpenA > 0.0 && dCurEq > dReqEqA &&
                             (!InpHourlyPlanARequireHigherHit || g_hourlyPlanAHitsToday == 0 || (dCurEq > g_hourlyPlanALastHitEquity && ((dCurEq - dOpenA)/dOpenA*100.0) > (g_hourlyPlanAHighestHitPct + MathMax(0.0, InpHourlyPlanAHitStepPct)))) &&
                             (dashBuyCnt + dashSellCnt) > 0);
   bool     hrlyDashPlanC = (InpEnableHourlySideLossCut && InpEnableHourlyPlanCDayProfitClose &&
                             (!InpHourlyPlanCOncePerDay || !g_hourlyPlanCDoneToday) &&
                             dOpenC > 0.0 && dCurEq > dReqEqC &&
                             (!InpHourlyPlanCRequireHigherHit || g_hourlyPlanCHitsToday == 0 || (dCurEq > g_hourlyPlanCLastHitEquity && ((dCurEq - dOpenC)/dOpenC*100.0) > (g_hourlyPlanCHighestHitPct + MathMax(0.0, InpHourlyPlanCHitStepPct)))) &&
                             (dashBuyCnt + dashSellCnt) > 0);
   bool     hrlyDashPlanD = (InpEnableHourlySideLossCut && InpEnableHourlyPlanDDayProfitClose &&
                             !hrlyDashDLock &&
                             dOpenD > 0.0 && dCurEq > dReqEqD &&
                             (!InpHourlyPlanDRequireHigherHit || g_hourlyPlanDHitsToday == 0 || (dCurEq > g_hourlyPlanDLastHitEquity && ((dCurEq - dOpenD)/dOpenD*100.0) > (g_hourlyPlanDHighestHitPct + MathMax(0.0, InpHourlyPlanDHitStepPct)))) &&
                             (dashBuyCnt + dashSellCnt) > 0);
   string eqDdState = "";
   color  eqDdClr   = clrSilver;
   if(!InpEnableEqDdLotReduction)
     {
      if(InpEnableHourlySideLossCut)
        {
         string hPlanStr = hrlyDashPlanD ? StringFormat("D%d>%.0f!", hrlyDashDMin, hrlyDashDThr)
                           : (hrlyDashPlanC ? "C:15M"
                              : (hrlyDashPlanA ? "A:ALL"
                                 : (dashHrlyBreach ? "B:CUT"
                                    : (InpEnableHourlyPlanDDayProfitClose
                                       ? (hrlyDashDLock ? StringFormat("D%dL", hrlyDashDMin) : StringFormat("D%d>%.0f", hrlyDashDMin, hrlyDashDThr))
                                       : "OK"))));
         eqDdState = StringFormat("1H %s %s%.1f%% %d/%d/%d/%d",
                                  hPlanStr, hrlyDashSign, hrlyDashEqPct,
                                  g_hourlyPlanATotalSweeps, g_hourlySideLossTotalCuts,
                                  g_hourlyPlanCTotalSweeps, g_hourlyPlanDTotalSweeps);
         eqDdClr = hrlyDashPlanD ? clrDeepSkyBlue
                   : (hrlyDashPlanC ? clrGold
                      : (hrlyDashPlanA ? clrLime
                         : (dashHrlyBreach ? clrOrangeRed
                            : ((g_hourlyPlanATotalSweeps > 0 || g_hourlyPlanCTotalSweeps > 0 || g_hourlyPlanDTotalSweeps > 0 || g_hourlySideLossTotalCuts > 0) ? clrGold : clrSilver))));
        }
      else
        {
         eqDdState = "DISABLED";
         eqDdClr = clrSilver;
        }
     }
   else
      if(g_eqDdCloseAllPending)
        {
         eqDdState = StringFormat("CLOSE-ALL PENDING | Cuts:%d", g_eqDdTotalPartialCuts);
         eqDdClr = clrRed;
        }
      else
         if(dashPending)
           {
            bool   pickWaitBuy = (dashWaitBuy && (!dashWaitSell || dashTierB > dashTierS || (dashTierB == dashTierS && dashBuyDdPct >= dashSellDdPct)));
            string wSideCh = pickWaitBuy ? "B" : "S";
            int    wTier   = pickWaitBuy ? dashTierB : dashTierS;
            string wReason = pickWaitBuy ? g_eqDdBuyLastReachReason : g_eqDdSellLastReachReason;
            eqDdState = StringFormat("%s-T%d WAIT (%s) | Pk:%.1f%%", wSideCh, wTier, wReason, g_eqDdSessionPeakPct);
            eqDdClr   = GetEqDdTierColor(wTier);
           }
         else
            if(dashMaxTier >= 1 || (InpEqDdOneShotPerTier && dashMaxDone >= 1))
              {
               bool   pickBuy  = (MathMax(dashTierB, g_eqDdBuyCycleHighestTier) > MathMax(dashTierS, g_eqDdSellCycleHighestTier)) ||
                                 (MathMax(dashTierB, g_eqDdBuyCycleHighestTier) == MathMax(dashTierS, g_eqDdSellCycleHighestTier) && dashBuyDdPct >= dashSellDdPct);
               string sideCh   = pickBuy ? "B" : "S";
               int    curSideT = pickBuy ? dashTierB : dashTierS;
               int    doneSide = pickBuy ? g_eqDdBuyCycleHighestTier : g_eqDdSellCycleHighestTier;
               int    effTier  = (curSideT > doneSide) ? curSideT : doneSide;
               double nextThresh = 0.0;
               ResolveNextEqDdTier(curSideT, doneSide, nextThresh);
               if(curSideT == 0 && doneSide >= 1)
                  eqDdState = StringFormat("%s-RECOV (T%d Next:%.0f%%) | Cuts:%d", sideCh, doneSide, nextThresh, g_eqDdTotalPartialCuts);
               else
                 {
                  string doneTag = (InpEqDdOneShotPerTier && doneSide >= effTier) ? " DONE" : "";
                  eqDdState = StringFormat("%s-T%d%s Next:%.0f%% | Cuts:%d", sideCh, effTier, doneTag, nextThresh, g_eqDdTotalPartialCuts);
                 }
               eqDdClr   = GetEqDdTierColor(effTier);
              }
            else
              {
               double firstThresh = InpEqDdEnableTier1 ? InpEqDdTier1Pct : InpEqDdTier2Pct;
               eqDdState = StringFormat("OK [Pk:%.1f%% Next:%.0f%%] | Cuts:%d", g_eqDdSessionPeakPct, firstThresh, g_eqDdTotalPartialCuts);
               eqDdClr = clrLightGray;
              }
   string eqDdLine = StringFormat("EQ-DD SIDE  : B:%.1f%% S:%.1f%% | %s", dashBuyDdPct, dashSellDdPct, eqDdState);
   CreateDashboardLabel(DASH_PREFIX+"EQDD_LINE", eqDdLine, tx, y+430, 8, eqDdClr);

   string eqDdHitLine = "DD LATEST   : NONE YET";
   color  eqDdHitClr  = clrLightGray;
   datetime dashPendTime = 0;
   if(dashWaitBuy && dashWaitSell)
      dashPendTime = MathMax(g_eqDdBuyLastReachTime, g_eqDdSellLastReachTime);
   else
      if(dashWaitBuy)
         dashPendTime = g_eqDdBuyLastReachTime;
      else
         if(dashWaitSell)
            dashPendTime = g_eqDdSellLastReachTime;

   if(!InpEnableEqDdLotReduction)
     {
      if(InpEnableHourlySideLossCut)
        {
         if(g_hourlyPlanDLastHitTime > 0 && g_hourlyPlanDLastHitTime >= g_hourlyPlanCLastHitTime && g_hourlyPlanDLastHitTime >= g_hourlyPlanALastHitTime && g_hourlyPlanDLastHitTime >= g_hourlySideLossLastHitTime)
           {
            eqDdHitLine = StringFormat("1H LATEST   : D[m%d>%.0f%%] +%.1f%% @%s x%d (-%.2fL)",
                                       g_hourlyPlanDLastHitMinIdx, g_hourlyPlanDLastHitThreshPct,
                                       g_hourlyPlanDLastPct,
                                       FormatDubaiShortDT(g_hourlyPlanDLastHitTime, false),
                                       g_hourlyPlanDLastOrders, g_hourlyPlanDLastLots);
            eqDdHitClr  = clrDeepSkyBlue;
           }
         else
            if(g_hourlyPlanCLastHitTime > 0 && g_hourlyPlanCLastHitTime >= g_hourlyPlanALastHitTime && g_hourlyPlanCLastHitTime >= g_hourlySideLossLastHitTime)
              {
               eqDdHitLine = StringFormat("1H LATEST   : PLAN-C +%.1f%% ALL @ %s x%d (-%.2fL)",
                                          g_hourlyPlanCLastPct,
                                          FormatDubaiShortDT(g_hourlyPlanCLastHitTime, false),
                                          g_hourlyPlanCLastOrders, g_hourlyPlanCLastLots);
               eqDdHitClr  = clrGold;
              }
            else
               if(g_hourlyPlanALastHitTime > 0 && g_hourlyPlanALastHitTime >= g_hourlySideLossLastHitTime)
                 {
                  eqDdHitLine = StringFormat("1H LATEST   : PLAN-A +%.1f%% ALL @ %s x%d (-%.2fL)",
                                             g_hourlyPlanALastPct,
                                             FormatDubaiShortDT(g_hourlyPlanALastHitTime, false),
                                             g_hourlyPlanALastOrders, g_hourlyPlanALastLots);
                  eqDdHitClr  = clrLime;
                 }
               else
                  if(g_hourlySideLossLastHitTime > 0)
                    {
                     eqDdHitLine = StringFormat("1H LATEST   : PLAN-B %s %.1f%% (-%.0f%%L) @ %s x%d (-%.2fL)",
                                                g_hourlySideLossLastHitSide, g_hourlySideLossLastHitPct, InpHourlySideLossCutPct,
                                                FormatDubaiShortDT(g_hourlySideLossLastHitTime, false),
                                                g_hourlySideLossLastHitOrders, g_hourlySideLossLastHitLots);
                     eqDdHitClr  = clrOrangeRed;
                    }
                  else
                    {
                     string bDashTag = InpEnableHourlyPlanBSideLossCut ? StringFormat("B>%.0f", InpHourlySideLossThresholdPct) : "B:OFF";
                     eqDdHitLine = StringFormat("1H LATEST   : A>%.0f %s C>%.0f D:m%d>%.0f%s (%s)",
                                                hrlyDashAThr, bDashTag, hrlyDashCThr,
                                                hrlyDashDMin, hrlyDashDThr, (hrlyDashDLock ? "L" : "%"), dashHrlyCNxt);
                     eqDdHitClr  = hrlyDashPlanD ? clrDeepSkyBlue : (hrlyDashPlanC ? clrGold : (hrlyDashPlanA ? clrLime : (dashHrlyBreach ? clrOrangeRed : clrSilver)));
                    }
        }
      else
        {
         eqDdHitLine = "DD LATEST   : DISABLED";
         eqDdHitClr  = clrSilver;
        }
     }
   else
      if(dashPendTime > 0 && dashPendTime >= g_eqDdLastHitTime && dashPendTime >= g_eqDdLastResetTime)
        {
         bool   pickWaitBuy = (dashWaitBuy && (!dashWaitSell || g_eqDdBuyLastReachTime >= g_eqDdSellLastReachTime));
         string pCh     = pickWaitBuy ? "B" : "S";
         int    pTier   = pickWaitBuy ? dashTierB : dashTierS;
         double pPct    = pickWaitBuy ? dashBuyDdPct : dashSellDdPct;
         string pReason = pickWaitBuy ? g_eqDdBuyLastReachReason : g_eqDdSellLastReachReason;
         eqDdHitLine = StringFormat("DD LATEST   : %s-T%d WAIT %.1f%% @ %s GST (%s)",
                                    pCh, pTier, pPct, FormatDubaiShortDT(dashPendTime, false), pReason);
         eqDdHitClr  = GetEqDdTierColor(pTier);
        }
      else
         if(g_eqDdLastResetTime > 0 && g_eqDdLastResetTime > g_eqDdLastHitTime)
           {
            eqDdHitLine = StringFormat("DD LATEST   : %s CLEARED (T%d->OK) @ %s GST",
                                       g_eqDdLastResetSide, g_eqDdLastResetTier,
                                       FormatDubaiShortDT(g_eqDdLastResetTime, false));
            eqDdHitClr  = clrLime;
           }
         else
            if(g_eqDdLastHitTime > 0)
              {
               string hitSideCh = (g_eqDdLastHitSide != "" ? StringSubstr(g_eqDdLastHitSide, 0, 1) : "?");
               string hitOkTag  = (dashMaxDone == 0 && dashMaxTier == 0) ? " [OK]" : "";
               eqDdHitLine = StringFormat("DD LATEST   : %s-T%d %.1f%% (-%.0f%%L) @ %s GST x%d%s",
                                          hitSideCh, g_eqDdLastHitTier, g_eqDdLastHitPct, g_eqDdLastHitCutPct,
                                          FormatDubaiShortDT(g_eqDdLastHitTime, false),
                                          g_eqDdLastHitOrders, hitOkTag);
               eqDdHitClr  = (dashMaxDone == 0 && dashMaxTier == 0) ? clrGold : GetEqDdTierColor(g_eqDdLastHitTier);
              }
            else
               if(g_eqDdLastReachTime > 0)
                 {
                  string rSideCh = (g_eqDdLastReachSide != "" ? StringSubstr(g_eqDdLastReachSide, 0, 1) : "?");
                  eqDdHitLine = StringFormat("DD LATEST   : %s-T%d REACH %.1f%% @ %s GST",
                                             rSideCh, g_eqDdLastReachTier, g_eqDdLastReachPct,
                                             FormatDubaiShortDT(g_eqDdLastReachTime, false));
                  eqDdHitClr  = GetEqDdTierColor(g_eqDdLastReachTier);
                 }
               else
                  if(g_drawdownReliefExecuted || g_drawdownReliefArmed)
                    {
                     eqDdHitLine = StringFormat("DD LATEST   : NONE YET | RLF Pk:$%.0f DD:$%.0f", g_drawdownReliefPeakUSD, curDD);
                     eqDdHitClr  = g_drawdownReliefExecuted ? clrLime : clrGold;
                    }
                  else
                     if(g_eqDdDailyResetTime > 0)
                       {
                        eqDdHitLine = StringFormat("DD LATEST   : DAY RESET @ %s GST [OK]",
                                                   FormatDubaiShortDT(g_eqDdDailyResetTime, false));
                        eqDdHitClr  = clrLime;
                       }
                     else
                        if(g_drawdownReliefPeakUSD > 0.0)
                          {
                           eqDdHitLine = StringFormat("DD LATEST   : NONE YET | RLF Pk:$%.0f DD:$%.0f", g_drawdownReliefPeakUSD, curDD);
                           eqDdHitClr  = clrDeepSkyBlue;
                          }
   CreateDashboardLabel(DASH_PREFIX+"EQDD_HIT", eqDdHitLine, tx, y+446, 8, eqDdHitClr);

   datetime dashNowServer = TimeCurrent();
   datetime dashDubaiTime = dashNowServer + (ServerToDubaiOffsetHours * 3600);
   int      dashDubaiHour = TimeHour(dashDubaiTime);
   int      dashDubaiMin  = TimeMinute(dashDubaiTime);
   int      dashDubaiMod  = dashDubaiHour * 60 + dashDubaiMin;
   int      dashDubaiDay  = GetDubai16TradingDayKey(dashDubaiTime);
   int      dashStartMod  = InpDubaiNightCloseStartHour * 60;
   int      dashEndMod    = InpDubaiNightCloseEndHour   * 60;
   int      dashForceMod  = InpDubaiNightForceCloseHour * 60 + InpDubaiNightForceCloseMinute;
   bool     dashInNightWin = false;
   if(InpDubaiNightCloseStartHour < InpDubaiNightCloseEndHour)
      dashInNightWin = (dashDubaiHour >= InpDubaiNightCloseStartHour && dashDubaiHour < InpDubaiNightCloseEndHour);
   else
      if(InpDubaiNightCloseStartHour > InpDubaiNightCloseEndHour)
         dashInNightWin = (dashDubaiHour >= InpDubaiNightCloseStartHour || dashDubaiHour < InpDubaiNightCloseEndHour);
      else
         dashInNightWin = (dashDubaiHour == InpDubaiNightCloseStartHour);

   bool dashInForceWin = false;
   bool dashForceInWindow = false;
   if(InpEnableDubaiNightForceCloseAll)
     {
      if(dashStartMod < dashEndMod)
         dashForceInWindow = (dashForceMod >= dashStartMod && dashForceMod < dashEndMod);
      else
         if(dashStartMod > dashEndMod)
            dashForceInWindow = (dashForceMod >= dashStartMod || dashForceMod < dashEndMod);
         else
            dashForceInWindow = (InpDubaiNightForceCloseHour == InpDubaiNightCloseStartHour);
     }
   if(dashInNightWin && InpEnableDubaiNightForceCloseAll)
     {
      if(dashStartMod <= dashEndMod)
         dashInForceWin = (dashDubaiMod >= dashForceMod);
      else
         if(dashForceMod >= dashStartMod)
            dashInForceWin = (dashDubaiMod >= dashForceMod || dashDubaiMod < dashEndMod);
         else
            dashInForceWin = (dashDubaiMod >= dashForceMod && dashDubaiMod < dashEndMod);
     }

   double   dashAbsAng    = MathAbs((GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30));
   bool     dashAngOk     = (!InpEnableDubaiNightEmaAngleFilter ||
                             (dashAbsAng + 1e-9 >= InpDubaiNightMinEmaAngleDeg &&
                              dashAbsAng - 1e-9 <= InpDubaiNightMaxEmaAngleDeg));
   double   dashDayOpenEq = (g_dubaiDayOpeningEquity > 0.0 && g_dubaiNightCloseDayKey == dashDubaiDay)
                            ? g_dubaiDayOpeningEquity : AccountEquity();
   double   dashDayEqPct  = (dashDayOpenEq > 0.0) ? (((AccountEquity() - dashDayOpenEq) / dashDayOpenEq) * 100.0) : 0.0;
   bool     dashDayEqHit  = (InpEnableDubaiNightDayProfitClose && dashDayOpenEq > 0.0 && dashDayEqPct > InpDubaiNightDayProfitPct);
   string   dashDayEqSign = (dashDayEqPct >= 0.0) ? "+" : "";

   string dubaiCloseTxt = "";
   color  dubaiCloseClr = clrLightGray;
   if(!InpEnableDubaiNightOneSideCloseAll)
     {
      dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : DISABLED (Dubai %s)",
                                   InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                   TimeToString(dashDubaiTime, TIME_MINUTES));
      dubaiCloseClr = clrSilver;
     }
   else
      if(g_dubaiNightCloseDoneToday && g_dubaiNightCloseDayKey == dashDubaiDay)
        {
         string hitClock = (g_dubaiNightCloseLastHitTime > 0)
                           ? TimeToString(g_dubaiNightCloseLastHitTime + (ServerToDubaiOffsetHours * 3600), TIME_MINUTES)
                           : "--:--";
         dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : DONE @ %s (EqDay:%s%.1f%% | Reset %s)",
                                      InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                      hitClock, dashDayEqSign, dashDayEqPct, GetNextSessionWaitHourStr(dashDubaiTime));
         dubaiCloseClr = clrGold;
        }
      else
         if(dashInNightWin && dashDayEqHit)
           {
            dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : EQ DAY %s%.2f%%>%.0f%% -> CLOSE ALL",
                                         InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                         dashDayEqSign, dashDayEqPct, InpDubaiNightDayProfitPct);
            dubaiCloseClr = clrLime;
           }
         else
            if(dashInForceWin)
              {
               if(dashAngOk)
                 {
                  dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : FORCE %s (Close ALL | Cuts:%d | Eq:%s%.1f%%)",
                                               InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                               TimeToString(dashDubaiTime, TIME_MINUTES), g_dubaiNightCutCountToday,
                                               dashDayEqSign, dashDayEqPct);
                  dubaiCloseClr = clrTomato;
                 }
               else
                 {
                  dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : WAIT ANG %s (|%.2f|>%.1f | Eq:%s%.1f%%/%.0f%%)",
                                               InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                               TimeToString(dashDubaiTime, TIME_MINUTES), dashAbsAng,
                                               InpDubaiNightMaxEmaAngleDeg, dashDayEqSign, dashDayEqPct, InpDubaiNightDayProfitPct);
                  dubaiCloseClr = clrSilver;
                 }
              }
            else
               if(dashInNightWin)
                 {
                  int dashCooldownSec = MathMax(60, InpDubaiNightCutIntervalMinutes * 60);
                  if(g_dubaiNightLastCutTime > 0 && (dashNowServer - g_dubaiNightLastCutTime) < dashCooldownSec)
                    {
                     int remMin = (int)MathCeil((double)(dashCooldownSec - (int)(dashNowServer - g_dubaiNightLastCutTime)) / 60.0);
                     dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : CUT#%d %s (Next:%dm | Eq:%s%.1f%%)",
                                                  InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                  g_dubaiNightCutCountToday, TimeToString(dashDubaiTime, TIME_MINUTES),
                                                  remMin, dashDayEqSign, dashDayEqPct);
                     dubaiCloseClr = clrDeepSkyBlue;
                    }
                  else
                     if(!dashAngOk)
                       {
                        dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : HOLD %s (|%.2f|>%.1f | Eq:%s%.1f%%/%.0f%%)",
                                                     InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                     TimeToString(dashDubaiTime, TIME_MINUTES), dashAbsAng,
                                                     InpDubaiNightMaxEmaAngleDeg, dashDayEqSign, dashDayEqPct, InpDubaiNightDayProfitPct);
                        dubaiCloseClr = clrSilver;
                       }
                     else
                       {
                        dubaiCloseTxt = dashForceInWindow
                                        ? StringFormat("DUBAI %02d-%02d : ARMED %s (-50%%/%dm | %02d:%02d All | Eq:%s%.1f%%)",
                                                       InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                       TimeToString(dashDubaiTime, TIME_MINUTES), InpDubaiNightCutIntervalMinutes,
                                                       InpDubaiNightForceCloseHour, InpDubaiNightForceCloseMinute,
                                                       dashDayEqSign, dashDayEqPct)
                                        : StringFormat("DUBAI %02d-%02d : ARMED %s (-50%%/%dm | End %02d:00 | Eq:%s%.1f%%)",
                                                       InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                                       TimeToString(dashDubaiTime, TIME_MINUTES), InpDubaiNightCutIntervalMinutes,
                                                       InpDubaiNightCloseEndHour, dashDayEqSign, dashDayEqPct);
                        dubaiCloseClr = clrOrange;
                       }
                 }
               else
                 {
                  dubaiCloseTxt = StringFormat("DUBAI %02d-%02d : READY (%s | -50%%/%dm | EqDay:%s%.1f%%/%.0f%%)",
                                               InpDubaiNightCloseStartHour, InpDubaiNightCloseEndHour,
                                               TimeToString(dashDubaiTime, TIME_MINUTES), InpDubaiNightCutIntervalMinutes,
                                               dashDayEqSign, dashDayEqPct, InpDubaiNightDayProfitPct);
                  dubaiCloseClr = clrLightGray;
                 }
   CreateDashboardLabel(DASH_PREFIX+"DUBAI_CLOSE", dubaiCloseTxt, tx, y+462, 8, dubaiCloseClr);

   double pGapDashMid   = (Bid > 0.0 && Ask > 0.0) ? ((Bid + Ask) * 0.5)
                          : ((Bars > 0 && Close[0] > 0.0) ? Close[0] : Bid);
   double pGapDashRef   = (g_priceGapCloseAnchorPrice > 0.0) ? g_priceGapCloseAnchorPrice : GetEmaFlipPrice();
   double pGapDashRaw   = (pGapDashRef > 0.0 && pGapDashMid > 0.0) ? MathAbs(pGapDashMid - pGapDashRef) : 0.0;
   double pGapDashReq   = (InpPriceGapCloseRawGap > 0.0) ? InpPriceGapCloseRawGap : 1000.0;
   double pGapDashPctRq = (InpPriceGapCloseDayProfitPct > 0.0) ? InpPriceGapCloseDayProfitPct : 5.0;
   bool   pGapDashArmed = (InpEnablePriceGapDayProfitClose && pGapDashRaw > pGapDashReq && dashDayOpenEq > 0.0 && dashDayEqPct > pGapDashPctRq);

   string pGapDashTxt = "";
   color  pGapDashClr = clrLightGray;
   if(!InpEnablePriceGapDayProfitClose)
     {
      pGapDashTxt = "GAP CLOSE   : DISABLED";
      pGapDashClr = clrSilver;
     }
   else
      if(pGapDashArmed)
        {
         pGapDashTxt = StringFormat("GAP>%.0f+%.0f%% : ARMED %.0f/%.0f Eq:%s%.1f%% (Hits:%d)",
                                    pGapDashReq, pGapDashPctRq, pGapDashRaw, pGapDashReq,
                                    dashDayEqSign, dashDayEqPct, g_priceGapCloseTotalSweeps);
         pGapDashClr = clrLime;
        }
      else
         if(g_priceGapCloseLastHitTime > 0)
           {
            pGapDashTxt = StringFormat("GAP>%.0f+%.0f%% : %.0f/%.0f Eq:%s%.1f%% | Hit#%d x%d @%s",
                                       pGapDashReq, pGapDashPctRq, pGapDashRaw, pGapDashReq,
                                       dashDayEqSign, dashDayEqPct, g_priceGapCloseTotalSweeps,
                                       g_priceGapCloseLastOrders, FormatDubaiShortDT(g_priceGapCloseLastHitTime, false));
            pGapDashClr = clrAqua;
           }
         else
           {
            pGapDashTxt = StringFormat("GAP>%.0f+%.0f%% : %.0f/%.0f | Eq:%s%.1f%%/%.0f%% | Anc:%s",
                                       pGapDashReq, pGapDashPctRq, pGapDashRaw, pGapDashReq,
                                       dashDayEqSign, dashDayEqPct, pGapDashPctRq,
                                       DoubleToString(pGapDashRef, Digits));
            pGapDashClr = (pGapDashRaw > pGapDashReq || dashDayEqPct > pGapDashPctRq) ? clrGold : clrLightGray;
           }
   CreateDashboardLabel(DASH_PREFIX+"PGAP_CLOSE", pGapDashTxt, tx, y+478, 8, pGapDashClr);

   double sLossDashEqDd  = (dashBal > 0.0 && curEq < dashBal) ? (((dashBal - curEq) / dashBal) * 100.0) : 0.0;
   double sLossEmergReq  = (InpStepLossEmergencyDdPct > 0.0) ? InpStepLossEmergencyDdPct : 30.0;
   double sLossActReq    = (InpStepLossActivateSidePct > 0.0) ? InpStepLossActivateSidePct : 10.0;
   double sLossNormGap   = (InpStepLossRawGap > 0.0) ? InpStepLossRawGap : 3000.0;
   bool   sLossDashEmerg = (InpEnableAdversePriceStepLossCut && sLossDashEqDd > sLossEmergReq);
   bool   sLossDashAct   = (InpEnableAdversePriceStepLossCut && (dashBuyDdPct > sLossActReq || dashSellDdPct > sLossActReq));
   string sLossDashTxt   = "";
   color  sLossDashClr   = clrLightGray;

   if(!InpEnableAdversePriceStepLossCut)
     {
      sLossDashTxt = "STEP LOSS   : DISABLED";
      sLossDashClr = clrSilver;
     }
   else
      if(sLossDashEmerg)
        {
         sLossDashTxt = StringFormat("STEP LOSS   : EMERG DD %.1f%%>%.0f%% | B:%.0f/%.0f S:%.0f/%.0f (-%.0f%%L)",
                                     sLossDashEqDd, sLossEmergReq,
                                     g_stepLossLastBuyAdv, g_stepLossLastReqBuyGap,
                                     g_stepLossLastSellAdv, g_stepLossLastReqSellGap,
                                     InpStepLossEmergencyCutPct);
         sLossDashClr = clrRed;
        }
      else
         if(g_stepLossLastHitTime > 0)
           {
            string slSideCh = (g_stepLossLastHitSide != "" ? StringSubstr(g_stepLossLastHitSide, 0, 1) : "?");
            sLossDashTxt = StringFormat("STEP LOSS   : %s#%d P%d/F%d (-%.2fL) @%s | B:%.0f S:%.0f",
                                        slSideCh, g_stepLossTotalSweeps,
                                        g_stepLossTotalPartialCuts, g_stepLossTotalFullCloses, g_stepLossTotalLotsCut,
                                        FormatDubaiShortDT(g_stepLossLastHitTime, false),
                                        g_stepLossLastBuyAdv, g_stepLossLastSellAdv);
            sLossDashClr = clrOrange;
           }
         else
            if(sLossDashAct)
              {
               sLossDashTxt = StringFormat("STEP LOSS   : ARMED >%.0f%% | B:%.0f/%.0f S:%.0f/%.0f",
                                           sLossActReq, g_stepLossLastBuyAdv, g_stepLossLastReqBuyGap,
                                           g_stepLossLastSellAdv, g_stepLossLastReqSellGap);
               sLossDashClr = clrGold;
              }
            else
              {
               sLossDashTxt = StringFormat("STEP LOSS   : READY (>%.0f%%/%.0f | Emerg >%.0f%% DD/%.0f)",
                                           sLossActReq, sLossNormGap, sLossEmergReq, InpStepLossEmergencyRawGap);
               sLossDashClr = clrLightGray;
              }
   CreateDashboardLabel(DASH_PREFIX+"STEP_LOSS", sLossDashTxt, tx, y+494, 8, sLossDashClr);

// ==========================================================
// SECTION 6: DAILY LOGS & ERROR TRACKER (DEMO / LIVE / TESTER)
// ==========================================================
   EnsureDailyLogFilesReady(false);
   string dashEnvMode = GetLoggerEnvMode();
   color  dashEnvClr  = (dashEnvMode == "LIVE") ? clrLime : ((dashEnvMode == "DEMO") ? clrAqua : clrGold);
   CreateDashboardPanel(DASH_PREFIX+"SEC_LOG", x, y+514, w, 18, C'28,38,50');
   string dashLogHdr = StringFormat("--- DAILY LOGS [%s | Acc #%s | EA_Logs\\%s] ---", dashEnvMode, GetLoggerAccountIdStr(), dashEnvMode);
   CreateDashboardLabel(DASH_PREFIX+"LOG_H", dashLogHdr, tx, y+516, 8, dashEnvClr);

   string dashErrLogFile = "LOG FILE  : " + GetActiveErrorLogDisplayName();
   CreateDashboardLabel(DASH_PREFIX+"LOG_FILE", dashErrLogFile, tx, y+534, 8, dashEnvClr);

   string dashCsvLogFile = "ORDER CSV : " + GetActiveOrderCsvDisplayName();
   CreateDashboardLabel(DASH_PREFIX+"CSV_FILE", dashCsvLogFile, tx, y+550, 8, clrWhite);

   string dashErrTrack = "";
   color  dashErrClr   = clrLime;
   if(!InpEnableOrderLogger)
     {
      dashErrTrack = "ERRORS    : LOGGER DISABLED";
      dashErrClr   = clrSilver;
     }
   else
      if(g_dailyErrorCount == 0)
        {
         dashErrTrack = StringFormat("ERRORS    : Today: 0 Errors | %s [CLEAN]", GetLoggerDateStamp());
         dashErrClr   = clrLime;
        }
      else
        {
         string shortOp = g_lastLoggedErrorOp;
         if(StringLen(shortOp) > 15)
            shortOp = StringSubstr(shortOp, 0, 15);
         string errClock = (g_lastLoggedErrorTime > 0)
                           ? StringFormat("%02d:%02d", TimeHour(g_lastLoggedErrorTime), TimeMinute(g_lastLoggedErrorTime))
                           : "--:--";
         dashErrTrack = StringFormat("ERRORS    : Today:%d | Last:#%d %s @%s",
                                     g_dailyErrorCount, g_lastLoggedErrorCode, shortOp, errClock);
         dashErrClr   = clrTomato;
        }
   CreateDashboardLabel(DASH_PREFIX+"LOG_ERR", dashErrTrack, tx, y+566, 8, dashErrClr);

// ==========================================================
// RESUME TRADING BUTTON (Manual unpause on chart click)
// ==========================================================
   string btnName = DASH_PREFIX + "BTN_RESUME_DAY";
   bool   isStopped   = (DayProfitLadderTradingStopped || g_dailyEquityAdverseLossHitToday || !EnableTrading);
   bool   isPaused    = (g_dailyEquityTradingBlocked || TradingHaltedUntilNextFlip || (TradeMonitoringLog != ""));

   string btnText;
   color  btnBg;
   color  btnTxt;
   color  btnBrd;

   if(isStopped)
     {
      btnText = "TRADING STOPPED (CLICK TO RESUME)";
      btnBg   = C'190,30,30';   // Red
      btnTxt  = clrWhite;
      btnBrd  = clrWhite;
     }
   else
      if(isPaused)
        {
         btnText = "TRADING PAUSED (CLICK TO RESUME)";
         btnBg   = C'220,180,20';  // Yellow / Gold
         btnTxt  = clrBlack;       // Crisp black text on yellow
         btnBrd  = clrGold;
        }
      else
        {
         btnText = "TRADING RUNNING (CLICK TO PAUSE)";
         btnBg   = C'22,145,55';   // Vibrant Green
         btnTxt  = clrWhite;
         btnBrd  = clrLime;
        }

   CreateDashboardButton(btnName, btnText, x + 20, y + 588, w - 20, 32, btnBg, btnTxt, btnBrd);

   ChartRedraw(0);

  }


//====================================================================
// 5. VISIBILITY TOGGLE & THROTTLED DASHBOARD UPDATE
//====================================================================
//+------------------------------------------------------------------+
//| ToggleDashboardsVisibility                                       |
//| User clicks SHOW/HIDE Dashboard button:                          |
//| - Toggles g_dashboardsUserHidden state                           |
//| - When HIDING: deletes left and right dashboard objects          |
//| - When SHOWING: recreates left and right dashboard objects       |
//| - Refreshes top center toolbar and chart immediately             |
//+------------------------------------------------------------------+
void ToggleDashboardsVisibility()
  {
   g_dashboardsUserHidden = !g_dashboardsUserHidden;
   if(g_dashboardsUserHidden)
     {
      DeleteDashboardObjects();
      DeleteLeftLiveOrdersDashboardObjects(true);
      UpdateDayEquityTargetBarStandalone();
      Print(">>> [UI] SHOW/HIDE Dashboard: User clicked HIDE. Dashboards hidden, Day Equity Target Bar retained.");
     }
   else
     {
      Print(">>> [UI] SHOW/HIDE Dashboard: User clicked SHOW. Left and right dashboards restored on chart.");
      DailyProtectionState activeState = GetCurrentDailyState();
      if(ShowDashboard)
         UpdateDashboard(activeState);
      if(ShowLeftLiveOrdersDashboard)
         UpdateLeftLiveOrdersDashboard(true);
     }

   if(ShowTopCenterDubaiTime)
      UpdateTopCenterDubaiTimeDisplay(true);
   ChartRedraw(0);
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboardsThrottled(DailyProtectionState &state, bool force = false)
  {
   uint now = GetTickCount();
   uint interval = IsTesting() ? 1000 : (uint)MathMax(500, DashboardUpdateIntervalMs);
   if(!force && LastDashboardUpdateMs != 0 && (uint)(now - LastDashboardUpdateMs) < interval)
      return;
   LastDashboardUpdateMs  = now;
   LastDashboardUpdateSec = TimeCurrent();

   if(ShowDashboard && !g_dashboardsUserHidden)
      UpdateDashboard(state);
   if(ShowLeftLiveOrdersDashboard)
      UpdateLeftLiveOrdersDashboard(force);
   if(ShowTopCenterDubaiTime)
      UpdateTopCenterDubaiTimeDisplay(force);
  }

