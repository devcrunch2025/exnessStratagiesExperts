 
double DrawCrossSignalLine1OrderAftercross(string prefix, string sigLabel, color lineCol, color textCol, int &outCount)
{



// g_order_creation_reason_signal_count_angle="";

   datetime firstTime   = 0;
   double   firstPrice  = 0;
   datetime latestTime  = 0;
   double   latestPrice = 0;
   int      count       = 0;

   int total = ObjectsTotal();


datetime timeMinus5 = TimeCurrent() -5 * 60;
   for(int k = 0; k < total; k++)
   {
      string name = ObjectName(k);
      if(StringFind(name, prefix + "_") != 0)             continue;
      if(StringSubstr(name, StringLen(name) - 2) != "_A") continue;

      datetime objTime  = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME,  0);
      double   objPrice =           ObjectGetDouble( 0, name, OBJPROP_PRICE, 0);

      if(objTime < g_lastCrossTime) continue;
    //   if(objTime < timeMinus5) continue; // ignore signals older than 5 minutes

      count++;
      if(firstTime == 0 || objTime < firstTime) { firstTime  = objTime;  firstPrice  = objPrice; }
      if(objTime > latestTime)                  { latestTime = objTime;  latestPrice = objPrice; }
   }

   string lineName  = prefix + "CrossLine";
   string angleName = prefix + "CrossAngle";
   ObjectDelete(0, lineName);
   ObjectDelete(0, angleName);

   outCount = count;
   // if(count < 5 || firstTime == latestTime) return EMPTY_VALUE;

   // if(count>1 )
   // {

   // }
   // else
   // {
   //    return EMPTY_VALUE
   // }

   double movePoints      = (latestPrice - firstPrice) / Point;
   double chartPriceRange = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
   double chartTimeSecs   = (double)ChartGetInteger(0, CHART_VISIBLE_BARS) * PeriodSeconds(PERIOD_CURRENT);
   double timeSecs        = (double)(latestTime - firstTime);

   double normY    = (chartPriceRange > 0) ? (movePoints * Point) / chartPriceRange : 0;
   double normX    = (chartTimeSecs   > 0) ? timeSecs / chartTimeSecs : 0;
   double angleDeg = 0;
   if(normX > 0) angleDeg = MathArctan(normY / normX) * 180.0 / 3.14159265358979;

//    double threshold = (count > 10) ? 40.0 : (count > 8) ? 45.0 : (count > 5) ? 50.0 : 60.0;

   double threshold=50;

   string label = "STRAIGHT";
   if(angleDeg >=  threshold) label = "UP";
   else if(angleDeg <= -threshold) label = "DOWN";

   string angleStr = DoubleToString(angleDeg, 1) + "°";

   if(ObjectCreate(0, lineName, OBJ_TREND, 0, firstTime, firstPrice, latestTime, latestPrice))
   {
      ObjectSetInteger(0, lineName, OBJPROP_COLOR,      lineCol);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH,      2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE,      STYLE_DASH);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT,  false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetString( 0, lineName, OBJPROP_TOOLTIP,
                       "AfterCross " + sigLabel + ": " + label +
                       "\nAngle: " + angleStr +
                       "\nFirst:  " + DoubleToString(firstPrice,  2) + " @ " + TimeToString(firstTime) +
                       "\nLatest: " + DoubleToString(latestPrice, 2) + " @ " + TimeToString(latestTime) +
                       "\nCount: " + IntegerToString(count));
   }

   if(ObjectCreate(0, angleName, OBJ_TEXT, 0, latestTime, latestPrice))
   {
      ObjectSetString( 0, angleName, OBJPROP_TEXT,       prefix + " " + label + " " + angleStr + " (" + IntegerToString(count) + ")");
      ObjectSetInteger(0, angleName, OBJPROP_COLOR,      textCol);
      ObjectSetInteger(0, angleName, OBJPROP_FONTSIZE,   9);
      ObjectSetString( 0, angleName, OBJPROP_FONT,       "Arial Bold");
      ObjectSetInteger(0, angleName, OBJPROP_ANCHOR,     ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, angleName, OBJPROP_SELECTABLE, false);
   }

   Print(sigLabel, " AfterCross | ", label,
         " | Angle=", angleStr,angleDeg,
          " | Signals=", count);

   // Top-right chart label — same text as Print(), TB=row3 (Y=100), TS=row4 (Y=125)
   string statusName = prefix + "CrossStatus";
   int    statusY    = (prefix == "TB") ? 100 : 125;
   string statusText = sigLabel + " AfterCross | " + label +
                       " | Angle=" + angleStr +
                       " | Signals=" + IntegerToString(count);
   color  statusCol  = (label == "UP") ? clrLime : (label == "DOWN") ? clrRed : clrGray;

   if(ObjectFind(0, statusName) == -1)
      ObjectCreate(0, statusName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, statusName, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, statusName, OBJPROP_XDISTANCE, 500);
   ObjectSetInteger(0, statusName, OBJPROP_YDISTANCE, statusY);
   ObjectSetInteger(0, statusName, OBJPROP_COLOR,     statusCol);
   ObjectSetInteger(0, statusName, OBJPROP_FONTSIZE,  11);
   ObjectSetString( 0, statusName, OBJPROP_FONT,      "Arial Bold");
   ObjectSetString( 0, statusName, OBJPROP_TEXT,      statusText);

   // if(count < 5 || angleDeg <50) return EMPTY_VALUE;

   int minimumCount = 2;
   int maximumCount = 5;

   double minimumAngle =80.0;

 


//             double gap = GetEMAGapPoints(FastEMA, SlowEMA);
// // if(gap>4000)
// // {
// //    minimumCount = 4;
// //    minimumAngle = 40.0;
// // }
 

 
 
 if(prefix == "TB" && angleDeg <= minimumAngle) {
      // Print("TB angle is   ", angleStr, " < ", minimumAngle, " — ignoring signal");

   return EMPTY_VALUE;
 } 
  else if(prefix == "TS" && angleDeg >= -minimumAngle){
      // Print("TS angle is   ", angleStr, " > ", -minimumAngle, " — ignoring signal");
   return EMPTY_VALUE;

   }

   else if( count < minimumCount || count > maximumCount)
 {  
      // Print("count ", count, " < ", minimumCount, " — ignoring signal", angleStr);
   
   return  EMPTY_VALUE;
 }



 

g_order_creation_reason_signal_count_angle = "2222222222 "+sigLabel + " signal : " +
      "Count=" + IntegerToString(count) + " (min " + IntegerToString(minimumCount) + "), " +
      "Angle=" + angleStr + " (min " + DoubleToString(minimumAngle, 1) + ")";

 Print("ORDER  ------------------  Signal: ", sigLabel,
       " | Count: ", count,
       " | Angle: ", angleStr,
       "  ");

   return angleDeg;
}
 