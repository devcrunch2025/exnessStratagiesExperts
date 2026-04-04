


bool stopTrading()
{
   double maxProfit=5.00; // 🔧 adjust this threshold (e.g. 10.00 for $10 profit)
double totalProfit = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol()) // optional (current pair only)
         {
            totalProfit += OrderProfit();
            totalProfit += OrderSwap();
            totalProfit += OrderCommission();
         }
      }
   }

    // 🔹 2. Closed Orders (history)
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderSymbol() == Symbol()) // optional filter
         {
            totalProfit += OrderProfit();
            totalProfit += OrderSwap();
            totalProfit += OrderCommission();
         }
      }
   }

      Print("Total open profit ($", DoubleToString(totalProfit, 2), ")   threshold ($", DoubleToString(maxProfit, 2), "). ");

if(totalProfit > maxProfit)
   {

      CloseAllBuyOrders(true);
      CloseAllSellOrders(true);
      Print("Total open profit ($", DoubleToString(totalProfit, 2), ") exceeds threshold ($", DoubleToString(maxProfit, 2), "). Stopping new trades.");
 
 
 
 
 
string name = "Trading Status: ";

    

   string text = "🟢 TRADING STOPPED: Booked Profit > $" + DoubleToString(maxProfit, 2);

   // ✅ Create only once
   if(ObjectFind(0, name) == -1)
   {

      int chartWidth = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS, 0);
   int x = chartWidth / 2 - 150;
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 100);

      ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 30);
   ObjectSetString(0,  name, OBJPROP_FONT,      "Arial Bold");

   }

   // ✅ Only update text (NO overlap)
   ObjectSetString(0, name, OBJPROP_TEXT, text);
 
 
 
 
 return true;
 
   }

   return false; // Stop trading if total open profit is below -$10
    

}

int isFirstBuyOrderClosed=false;
int isFirstSellOrderClosed=false;
double FirstOrderLossThreshold = -4.0; // $4 loss threshold to trigger close of oldest order
void CloseOldestBuyIfLoss()
{
if(isFirstBuyOrderClosed)
   {
      return ;
   }

   int ticket = -1;
   datetime oldestTime = 0;
   double lots = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderType() == OP_BUY)
         {
            if(ticket == -1 || OrderOpenTime() < oldestTime)
            {
               ticket = OrderTicket();
               oldestTime = OrderOpenTime();
               lots = OrderLots();
            }
         }
      }
   }

   // 👉 Check and close ONLY oldest BUY
   if(ticket != -1 && OrderSelect(ticket, SELECT_BY_TICKET))
   {
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < FirstOrderLossThreshold)
      {
         RefreshRates();

         bool result = OrderClose(ticket, lots, Bid, 5, clrRed);
         isFirstBuyOrderClosed = true; // Set flag to prevent multiple closures in same session
         if(result)
            Print("Closed oldest BUY (loss > $", DoubleToString(-FirstOrderLossThreshold, 2), "): ", ticket);
         else
            Print("Failed to close BUY: ", GetLastError());
      }
   }
}void CloseOldestSellIfLoss()
{

   if(isFirstSellOrderClosed)
   {
      return ;
   }
   int ticket = -1;
   datetime oldestTime = 0;
   double lots = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderType() == OP_SELL)
         {
            if(ticket == -1 || OrderOpenTime() < oldestTime)
            {
               ticket = OrderTicket();
               oldestTime = OrderOpenTime();
               lots = OrderLots();
            }
         }
      }
   }

   // 👉 Check and close ONLY oldest SELL
   if(ticket != -1 && OrderSelect(ticket, SELECT_BY_TICKET))
   {
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit < FirstOrderLossThreshold)
      {
         RefreshRates();

         bool result = OrderClose(ticket, lots, Ask, 5, clrRed);

         isFirstSellOrderClosed = true; // Set flag to prevent multiple closures in same session

         if(result)
            Print("Closed oldest SELL (loss > $", DoubleToString(-FirstOrderLossThreshold, 2), "): ", ticket);
         else
            Print("Failed to close SELL: ", GetLastError());
      }
   }
}

void CheckEMAPosition()
{

   // Return:
//  1  = Above EMAs (BUY zone)
// -1  = Below EMAs (SELL zone)
//  0  = Inside EMAs (no trade)
//  2  = EMAs tight (no trade - squeeze)

 
   double emaFast = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), 0, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   double price = Bid;

   double upper = MathMax(emaFast, emaSlow);
   double lower = MathMin(emaFast, emaSlow);

   double gapPoints = MathAbs(emaFast - emaSlow) / Point;

   double minGap = 100; // 🔧 adjust (BTC: 100–200, Forex: 20–50)

   // 🔹 4️⃣ EMAs tight → squeeze zone
   if(gapPoints < minGap)
       
      {
//          Print("EMAs tight (gap: " + DoubleToString(gapPoints, 1) + " pts) → NO TRADE");
// CloseAllSellOrders(true); 
// CloseAllBuyOrders(); 
      return ;

       
      }

   // 🔹 1️⃣ Above both EMAs → BUY zone
   if(price > upper)
      
      {
      //    Print("Tick is ABOVE EMAs → BUY zone");
      //     ProcessSeqBuyOrders();
      // CloseAllSellOrders(true); // 🔥 close opposite SELL orders immediately
      return ;

      }

   // 🔹 2️⃣ Below both EMAs → SELL zone
   if(price < lower)
     
     {
      // Print("Tick is BELOW EMAs → SELL zone");
      //   ProcessSeqSellOrders();
      // CloseAllBuyOrders(); // 🔥 close opposite BUY orders immediately

      return ;
     }

     Print("Tick is INSIDE EMAs → NO TRADE");

     isEMATouchesInsideLines=true;

   // // 🔹 3️⃣ Between EMAs → Inside
   //    CloseAllSellOrders(true);
   //    CloseAllBuyOrders(); // 🔥 close opposite BUY orders immediately
 
}

 void ProcessSimplyBuyandCloseOrders()
 {
   string currSeqText = (g_liveSignalName == "") ? "---" :
                        g_liveSignalName + " " + IntegerToString(g_currSeqCount);

 

      if((  StringFind(g_liveSignalName, "PRE SELL")    >= 0)  )
      { 
       CloseAllBuyOrders();

      }

       if((  StringFind(g_liveSignalName, "PRE BUY")    >= 0)  )
      { 
       CloseAllSellOrders();

      }
  if((  StringFind(g_liveSignalName, "W SHAPE SELL")    >= 0)  )
      { 
       CloseAllSellOrders();

      }
      if((  StringFind(g_liveSignalName, "STRONG SELL")    >= 0)  )
      { 
       CloseAllSellOrders();

      }


      




 }

void GetEMACrossDirection()
{

   return ;
   /*
   int seconds = 10;  // ✅ fixed

   static datetime lastCrossTime = 0;
   static int lastDirection = 0; // 1 = BUY, -1 = SELL
   static double prevFast = 0;
   static double prevSlow = 0;

   double emaFast = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 0);
   double emaSlow = iMA(Symbol(), 0, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

   // --- Detect cross ---
   if(prevFast != 0 && prevSlow != 0)
   {
      // 🔺 CROSS UP → BUY
      if(prevFast < prevSlow && emaFast > emaSlow)
      {
         lastCrossTime = TimeCurrent();
         lastDirection = 1;

         Print("EMA CROSS UP → BUY");
      }

      // 🔻 CROSS DOWN → SELL
      else if(prevFast > prevSlow && emaFast < emaSlow)
      {
         lastCrossTime = TimeCurrent();
         lastDirection = -1;

         Print("EMA CROSS DOWN → SELL");
      }
   }

   prevFast = emaFast;
   prevSlow = emaSlow;

   // --- No cross yet ---
   if(lastCrossTime == 0)
      return  ;

   int diff = (int)(TimeCurrent() - lastCrossTime);

   // --- Within 10 seconds ---
   if(diff <= seconds)
   {
      // ✅ Execute only once per cross
      static datetime lastHandled = 0;

      if(lastHandled != lastCrossTime)
      {
         lastHandled = lastCrossTime;

         if(lastDirection == 1)
         {
            ProcessSeqBuyOrders();
         }
         else if(lastDirection == -1)
         {
            ProcessSeqSellOrders();
         }
      }

      return  ;
   }

   return  ;*/
}
void verfyEMAInsideLogic()
{

   return ;
   /*
 double emaFast = iMA(Symbol(), 0, 9,  0, MODE_EMA, PRICE_CLOSE, 0);
double emaSlow = iMA(Symbol(), 0, 21, 0, MODE_EMA, PRICE_CLOSE, 0);

// Use LIVE tick price
double price = Bid;

double upper = MathMax(emaFast, emaSlow);
double lower = MathMin(emaFast, emaSlow);

// --- INSIDE CHECK ---
bool isInside = (price > lower && price < upper);

if(isInside)
{
   Print("Tick is INSIDE EMA zone");
   CloseAllBuyOrders(); // Close BUY if inside
   CloseAllSellOrders(); // Close SELL if inside
}
}

void CheckForNewClosedBarAndProcessSignals()
{

   return ;
string curveDir = GetEMACurveDirection(50);

   Print("EMA Curve: ", curveDir);

   if(curveDir == "CURVING UP")
   {
      // Allow BUY logic
   }
int emaPeriod = 50; // or 100 / 200

   double ema0 = iMA(Symbol(),0,emaPeriod,0,MODE_EMA,PRICE_CLOSE,0);
double ema5 = iMA(Symbol(),0,emaPeriod,0,MODE_EMA,PRICE_CLOSE,5);

// slope (trend direction)
double slope = (ema0 - ema5) / Point;

// curve (your improved function)
string curve = GetEMACurveDirection(emaPeriod);

// --- EXIT LOGIC ---
bool strongDown = (slope < -5);   // strong downtrend
bool curveDown  = (curve == "CURVING DOWN");

// 🚫 CLOSE BUY only if BOTH confirm
if(strongDown && curveDown)
{
   Print("EXIT BUY: Strong Downtrend Confirmed");
   CloseAllBuyOrders();
} 
else
{
   Print("BUY allowed: No strong downtrend");
      CloseAllSellOrders();

}

   if(curveDir == "FLAT")
   {
      // Caution: flat market, maybe skip new entries or tighten filters
       // Allow SELL logic
      CloseAllBuyOrders();
      CloseAllSellOrders();

   }
   */
}
 
string GetEMACurveDirection(int period)
{
   int bars = 10; // 🔥 increase for accuracy (5–10)

   double slopeNow = 0;
   double slopePrev = 0;

   // Average current slope
   for(int i = 0; i < bars; i++)
   {
      double ema1 = iMA(Symbol(),0,period,0,MODE_EMA,PRICE_CLOSE,i);
      double ema2 = iMA(Symbol(),0,period,0,MODE_EMA,PRICE_CLOSE,i+1);
      slopeNow += (ema1 - ema2);
   }
   slopeNow /= bars;

   // Average previous slope
   for(int i = bars; i < bars*2; i++)
   {
      double ema1 = iMA(Symbol(),0,period,0,MODE_EMA,PRICE_CLOSE,i);
      double ema2 = iMA(Symbol(),0,period,0,MODE_EMA,PRICE_CLOSE,i+1);
      slopePrev += (ema1 - ema2);
   }
   slopePrev /= bars;

   // Curve (acceleration)
   double curve = (slopeNow - slopePrev) / Point;

   double minCurve = 1.5; // 🔧 tune this

   if(curve > minCurve)   return "CURVING UP";
   if(curve < -minCurve)  return "CURVING DOWN";
   return "FLAT";
}

void CloseAllSellOrders(bool foreceClose = false)
{

  if(CloseOrderONLYProfitNotSignal==true && !foreceClose)
    {

     // Print("CloseAllSellOrders | CloseOrderONLYProfitNotSignal=true — skipping all close logic");
       return ;
    }
   bool anyClosed = false;

   RefreshRates(); // 🔥 always refresh prices

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderType() == OP_SELL)
         {
            double closePrice = Ask;

            bool result = OrderClose(
               OrderTicket(),
               OrderLots(),
               closePrice,
               5,
               clrRed
            );

            if(!result)
            {
               Print("Failed to close SELL order: ", OrderTicket(),
                     " Error: ", GetLastError());
            }
            else
            {
               Print("Closed SELL order: ", OrderTicket());
               anyClosed = true;
            }
         }
      }
   }

   // 🔥 Call ONLY ONCE after all orders processed
    if(anyClosed)
   {
      UpdateTPBasedOnLastClosed();
   }
}
void CloseAllBuyOrders(bool foreceClose = false)
{

   if(CloseOrderONLYProfitNotSignal==true && !foreceClose)
    {

      //Print("CloseAllBuyOrders | CloseOrderONLYProfitNotSignal=true — skipping all close logic");
       return ;
    }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         if(OrderSymbol() == Symbol() && OrderType() == OP_BUY)
         {
            double closePrice = Bid; // BUY closes at Bid

            bool result = OrderClose(
               OrderTicket(),
               OrderLots(),
               closePrice,
               5,              // slippage
               clrRed
            );

            if(!result)
            {
               Print("Failed to close BUY order: ", OrderTicket(),
                     " Error: ", GetLastError());
            }
             
 if(result)
{
   Print("Closed BUY order: ", OrderTicket());
   UpdateTPBasedOnLastClosed();   // 🔥 ADD THIS
}

         }
      }
   }
}

void UpdateTPBasedOnLastClosed()
{
   int total = OrdersHistoryTotal();
   if(total == 0) return;

   // Get last closed order
   if(OrderSelect(total - 1, SELECT_BY_POS, MODE_HISTORY))
   {
      if(OrderSymbol() != Symbol()) return;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(OrderType() == OP_BUY)
      {
         if(profit < 0)
         {
            CurrentBuyTP = DefaultBuyTP / 2.0;
            SeqBuyProfitTarget = SeqBuyProfitTarget / 2.0; // also reduce SL for next BUY
            Print("BUY LOSS → TP reduced to ", CurrentBuyTP," #"+total);
         }
         else
         {
            CurrentBuyTP = DefaultBuyTP;
            SeqBuyProfitTarget = DefaultBuyTP; // increase SL for next BUY
            Print("BUY PROFIT → TP reset to ", CurrentBuyTP," #"+total);
         }
      }

      if(OrderType() == OP_SELL)
      {
         if(profit < 0)
         {
            CurrentSellTP = DefaultSellTP / 2.0;
            
            SeqSellProfitTarget = SeqSellProfitTarget / 2.0; // also reduce SL for next SELL
            Print("SELL LOSS → TP reduced to ", CurrentSellTP," #"+total);
         }
         else
         {
            CurrentSellTP = DefaultSellTP;
               SeqSellProfitTarget = DefaultSellTP; // increase SL for next SELL
            Print("SELL PROFIT → TP reset to ", CurrentSellTP," #"+total);
         }
      }
   }
}