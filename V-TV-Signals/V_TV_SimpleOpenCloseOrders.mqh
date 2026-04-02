

 void ProcessSimplyBuyandCloseOrders()
 {
   string currSeqText = (g_liveSignalName == "") ? "---" :
                        g_liveSignalName + " " + IntegerToString(g_currSeqCount);



   // if(currSeqText=="TREND BUY 1"  ) {
   //   SeqBuyProfitTarget=0.10;
   //   SeqSellProfitTarget=0.10;

      

   //   }
//  if(currSeqText=="PRE BUY 3" || currSeqText=="STRONG BUY 1" ||  currSeqText=="TREND BUY 2" ||  currSeqText=="TREND BUY 3" || currSeqText=="TREND BUY 4"  )
//      { 
//       CloseAllBuyOrders();

//      }

if( currSeqText=="PRE BUY 3" || currSeqText=="STRONG BUY 1" || currSeqText=="TREND BUY 3"   )
     { 
      CloseAllBuyOrders();

     }




 }






void CheckForNewClosedBarAndProcessSignals()
{
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

   if(curveDir == "FLAT")
   {
      // Caution: flat market, maybe skip new entries or tighten filters
       // Allow SELL logic
      CloseAllBuyOrders();
   }
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

void CloseAllBuyOrders()
{
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
            Print("BUY LOSS → TP reduced to ", CurrentBuyTP);
         }
         else
         {
            CurrentBuyTP = DefaultBuyTP;
            Print("BUY PROFIT → TP reset to ", CurrentBuyTP);
         }
      }

      if(OrderType() == OP_SELL)
      {
         if(profit < 0)
         {
            CurrentSellTP = DefaultSellTP / 2.0;
            Print("SELL LOSS → TP reduced to ", CurrentSellTP);
         }
         else
         {
            CurrentSellTP = DefaultSellTP;
            Print("SELL PROFIT → TP reset to ", CurrentSellTP);
         }
      }
   }
}