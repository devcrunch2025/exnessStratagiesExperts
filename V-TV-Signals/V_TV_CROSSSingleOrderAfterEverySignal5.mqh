double getAngleBetweenSignals(string prefix)
{
     datetime firstTime   = 0;
   double   firstPrice  = 0;
   datetime latestTime  = 0;
   double   latestPrice = 0;
   int      count       = 0;
   int      countSpecial       = 0;


   int total = ObjectsTotal();


datetime timeMinus5 = TimeCurrent() -2 * 60;
   for(int k = 0; k < total; k++)
   {
      string name = ObjectName(k);
      if(StringFind(name, prefix + "_") != 0)             continue;
      if(StringSubstr(name, StringLen(name) - 2) != "_A") continue;

      datetime objTime  = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME,  0);
      double   objPrice =           ObjectGetDouble( 0, name, OBJPROP_PRICE, 0);

      //if(objTime < g_lastCrossTime) continue;
       if(objTime < timeMinus5) continue; // ignore signals older than 5 minutes

      count++;
      if(firstTime == 0 || objTime < firstTime) { firstTime  = objTime;  firstPrice  = objPrice; }
      if(objTime > latestTime)                  { latestTime = objTime;  latestPrice = objPrice; }
   }

     for(int k = 0; k < total; k++)
   {
      string name = ObjectName(k);
      if(StringFind(name, prefix + "_") != 0)             continue;
      if(StringSubstr(name, StringLen(name) - 2) != "_A") continue;

      datetime objTime  = (datetime)ObjectGetInteger(0, name, OBJPROP_TIME,  0);
      double   objPrice =           ObjectGetDouble( 0, name, OBJPROP_PRICE, 0);

      if(objTime < g_lastCrossTime) continue;
    //    if(objTime < timeMinus5) continue; // ignore signals older than 5 minutes

      countSpecial++;
                   { latestTime = objTime;  latestPrice = objPrice; }
   }

   string lineName  = prefix + "CrossLine";
   string angleName = prefix + "CrossAngle";
   ObjectDelete(0, lineName);
   ObjectDelete(0, angleName);

     double movePoints      = (latestPrice - firstPrice) / Point;
   double chartPriceRange = ChartGetDouble(0, CHART_PRICE_MAX) - ChartGetDouble(0, CHART_PRICE_MIN);
   double chartTimeSecs   = (double)ChartGetInteger(0, CHART_VISIBLE_BARS) * PeriodSeconds(PERIOD_CURRENT);
   double timeSecs        = (double)(latestTime - firstTime);

   double normY    = (chartPriceRange > 0) ? (movePoints * Point) / chartPriceRange : 0;
   double normX    = (chartTimeSecs   > 0) ? timeSecs / chartTimeSecs : 0;
   double angleDeg = 0;
   if(normX > 0) angleDeg = MathArctan(normY / normX) * 180.0 / 3.14159265358979;

// Print(countSpecial);

 if(countSpecial<5 || countSpecial >8) return 0; // not enough signals to compare angles

   return angleDeg;



}


void V_TV_CROSSSingleOrderAfterEverySignal5()
{


    double SeqSellStopLossUSDDefault  =SeqSellStopLossUSD;
double SeqBuyStopLossUSDDefault   =SeqBuyStopLossUSD;







 double gap = GetEMAGapPoints(FastEMA, SlowEMA);


  
   if(gap<2000) return ;


  

    if(g_liveSignalName=="TREND SELL")// || g_liveSignalName=="STRONG SELL")
    {
//  CloseAllBuyOrders();


Print("TB: ", getAngleBetweenSignals("TB"), " |   TS: ", getAngleBetweenSignals("TS"), " | Live Signal: ", g_liveSignalName);    


        if(getAngleBetweenSignals("TS")>-60) return;

// if(gap>5000)
{
//         SeqSellStopLossUSD=getLast1HourProfit(SeqBuyLotSize);
// SeqBuyStopLossUSD=getLast1HourProfit(SeqBuyLotSize);
}
         ProcessSeqSellOrders(false,false,false);

    }
      else  if(g_liveSignalName=="TREND BUY")// || g_liveSignalName=="STRONG BUY")

    {

//  CloseAllSellOrders();
//  if(gap<2000) return ;


Print("TB: ", getAngleBetweenSignals("TB"), " |   TS: ", getAngleBetweenSignals("TS"), " | Live Signal: ", g_liveSignalName);    


        if(getAngleBetweenSignals("TB")<60) return;
// if(gap>5000)
// {
//         SeqSellStopLossUSD=3;
// SeqBuyStopLossUSD=3;
// }
//  SeqSellStopLossUSD=getLast1HourProfit(SeqBuyLotSize);
// SeqBuyStopLossUSD=getLast1HourProfit(SeqBuyLotSize);

            ProcessSeqBuyOrders(false,false,false);
    }
//CLOSE BEFORE 
//     if(g_liveSignalName=="PRE SELL" )
//     {
// CloseAllBuyOrders();
//     }
//       else  if(g_liveSignalName=="PRE BUY")

//     {
// CloseAllSellOrders();

//     }

// SeqSellStopLossUSD=SeqSellStopLossUSDDefault;
// SeqBuyStopLossUSD=SeqBuyStopLossUSDDefault;
       
}