
void checkCandleLength()
{
   double candleLength = (High[1] - Low[1]) / Point;
   double candleLength2 = (High[2] - Low[2]) / Point;
   double candleLength3 = (High[3] - Low[3]) / Point;
   double candleLength4 = (High[4] - Low[4]) / Point;
   double candleLength5 = (High[5] - Low[5]) / Point;
   double candleLength6 = (High[6] - Low[6]) / Point;
   double candleLength7 = (High[7] - Low[7]) / Point;
double candleLength8 = (High[8] - Low[8]) / Point;
double candleLength9 = (High[9] - Low[9]) / Point;
double candleLength10 = (High[10] - Low[10]) / Point;

bool isBullish = (Close[1] > Open[1]); // green candle
bool isBearish = (Close[1] < Open[1]); // red candle
bool isBullish2 = (Close[2] > Open[2]); // green candle
bool isBearish2 = (Close[2] < Open[2]); // red candle


// Print("Candle length in points: ",isBullish,isBearish2, " | ", candleLength, " | ", candleLength2, " | ", candleLength3, " | ", candleLength4);
if(isBullish && isBearish2 && candleLength > 5000 && candleLength2 > 5000 && candleLength3 > 15000) // adjust threshold as needed
   {
        SeqBuyMaxOrders  = 1;
      SeqSellMaxOrders = 1;
         ProcessSeqSellOrders(false,false,true); 

       
   }
   else if(isBearish && isBullish2 && candleLength > 5000 && candleLength2 > 5000 && candleLength3 > 15000) // adjust threshold as needed
   {
       SeqBuyMaxOrders  = 1;
      SeqSellMaxOrders = 1;
              ProcessSeqBuyOrders(false,false,true); 

       
   }


   // Print("Candle length in points: ", candleLength);
   if(candleLength > 20000 || candleLength2 > 20000 || candleLength3 > 20000 || candleLength4 > 20000 || candleLength5 > 20000 || candleLength6 > 20000 || candleLength7 > 20000 || candleLength8 > 20000 || candleLength9 > 20000 || candleLength10 > 20000) // adjust threshold as needed
   {
      Print("Long candle detected: ", candleLength, " points — skipping signal");
      SeqBuyMaxOrders  = 0;
      SeqSellMaxOrders = 0;
       
   }
   else
   {
       SeqBuyMaxOrders  = defaultMaxBuyOrders;
      SeqSellMaxOrders =defaultMaxSellOrders;
   }

}
double DrawCrossSignalLine2(string prefix, string sigLabel, color lineCol, color textCol, int &outCount)
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

      // if(objTime < g_lastCrossTime) continue;
      if(objTime < timeMinus5) continue; // ignore signals older than 5 minutes

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

   int minimumCount = 5;
   double minimumAngle =70.0;

// Print("NOOOOOOOOOOOO ORDER  ------------------  Signal: ", sigLabel,
//        " | Count: ", count,
//        " | Angle: ", angleStr,
//        "  ");


            double gap = GetEMAGapPoints(FastEMA, SlowEMA);
// if(gap>4000)
// {
//    minimumCount = 4;
//    minimumAngle = 40.0;
// }

// if(gap<1000)
// {
//    Print("Small EMA gap detected: ", gap, " pts — increasing thresholds");

//    return EMPTY_VALUE;
// }

/*
   int minimumCount = 15;
   double minimumAngle =60.0;
if(angleDeg>80 || angleDeg<-80)
{
      minimumCount =5;//spike with very strong angle, allow even 3 signals to count as valid trend
      // Print("Minimum count increased to ", minimumCount, " due to strong angle of ", angleStr);

     
}
else if(angleDeg>75 || angleDeg<-75)
{
      minimumCount = 10;
      // Print("Minimum count increased to ", minimumCount, " due to strong angle of ", angleStr);
     
   //   SeqBuyMaxOrders  = 1;
   //    SeqSellMaxOrders =1;
}else if(angleDeg>65 || angleDeg<-65)
{
      minimumCount = 15;
      // Print("Minimum count increased to ", minimumCount, " due to strong angle of ", angleStr);
     
   //   SeqBuyMaxOrders  = 1;
   //    SeqSellMaxOrders =1;
}else if(angleDeg>50 || angleDeg<-50)
{
      minimumCount = 30;
      minimumAngle = 50.0;
      // Print("Minimum count increased to ", minimumCount, " due to strong angle of ", angleStr);
     
   //   SeqBuyMaxOrders  = 1;
   //    SeqSellMaxOrders =1;
}else if(angleDeg>40 || angleDeg<-40)
{
      minimumCount = 40;
      minimumAngle = 40.0;
      // Print("Minimum count increased to ", minimumCount, " due to strong angle of ", angleStr);
     
   //   SeqBuyMaxOrders  = 1;
   //    SeqSellMaxOrders =1;
}
else
{
   // SeqBuyMaxOrders  = defaultMaxBuyOrders;
   //    SeqSellMaxOrders =defaultMaxSellOrders;
}
*/


 
 
 if(prefix == "TB" && angleDeg <= minimumAngle) {
      Print("TB angle is   ", angleStr, " < ", minimumAngle, " — ignoring signal");

   return EMPTY_VALUE;
 } 
  else if(prefix == "TS" && angleDeg >= -minimumAngle){
      Print("TS angle is   ", angleStr, " > ", -minimumAngle, " — ignoring signal");
   return EMPTY_VALUE;

   }

   else if(count<minimumCount)
 {  
      Print("count ", count, " < ", minimumCount, " — ignoring signal", angleStr);
   
   return  EMPTY_VALUE;
 }



 

g_order_creation_reason_signal_count_angle = "2222222222 "+sigLabel + " signal : " +
      "Count=" + IntegerToString(count) + " (min " + IntegerToString(minimumCount) + "), " +
      "Angle=" + angleStr + " (min " + DoubleToString(minimumAngle, 1) + ")";

//  Print("ORDER  ------------------  Signal: ", sigLabel,
//        " | Count: ", count,
//        " | Angle: ", angleStr,
//        "  ");

   return angleDeg;
}
// string g_order_creation_reason_signal_count_angle="";
// ===================================================
// Returns:  1 = TREND BUY  angle above count-based threshold
//          -1 = TREND SELL angle below count-based threshold
//           0 = no clear direction / insufficient data
// Threshold: count >8 → 40°, count >5 → 50°, else 60°
// ===================================================
/*
int GetMinuteTrendAftercross()
{

string statusName = "TrendAfterCrossStatus";

   if(g_lastCrossTime == 0) 
   {

   Print("Checking TREND signals after last cross at ", TimeToString(g_lastCrossTime));
string statusText = "Checking TREND signals after last cross at " + TimeToString(g_lastCrossTime);
   if(ObjectFind(0, statusName) == -1)
      ObjectCreate(0, statusName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, statusName, OBJPROP_CORNER,    CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, statusName, OBJPROP_XDISTANCE, 500);
   ObjectSetInteger(0, statusName, OBJPROP_YDISTANCE, 300);
   ObjectSetInteger(0, statusName, OBJPROP_COLOR,     clrRed);
   ObjectSetInteger(0, statusName, OBJPROP_FONTSIZE,  11);
   ObjectSetString( 0, statusName, OBJPROP_FONT,      "Arial Bold");
   ObjectSetString( 0, statusName, OBJPROP_TEXT,      statusText);

      return 0;

   }
   else
   {
         //if(ObjectFind(0, statusName) == 1)
         {
            ObjectDelete(0, statusName);
         }

   }

   int    tbCount = 0, tsCount = 0;
   double tbAngle = DrawCrossSignalLine("TB", "TREND BUY",  clrYellow, clrYellow, tbCount);
   double tsAngle = DrawCrossSignalLine("TS", "TREND SELL", clrYellow,  clrYellow,  tsCount);

   ChartRedraw(0);

   // Print(tbAngle, " | ", tsAngle);

   if(tbAngle != EMPTY_VALUE)
   {
      // double tbThreshold = (tbCount > 10) ? 30.0 : (tbCount > 8) ? 40.0 : (tbCount > 5) ? 50.0 : 60.0;
      // if(tbAngle >= tbThreshold) return 1;



      return 1;
   }
   if(tsAngle != EMPTY_VALUE)
   {
      // double tsThreshold = (tsCount > 10) ? 30.0 : (tsCount > 8) ? 40.0 : (tsCount > 5) ? 50.0 : 60.0;
      // if(tsAngle <= -tsThreshold) return -1;

      return -1;
   }
   return 0;
}*/