void V_TV_CreateNewOrderLIMITPrice()
{

   return ;
int signal = DetectBTCUSDTrendSignal();

   if(signal == 1)
   {

      // PlaceTrendPendingOrderSafe(1, 0.01, 2000, 5, 12345);
   }
   else if(signal == -1)
   {
      // PlaceTrendPendingOrderSafe(-1, 0.01, 2000, 5, 12345);
   }
}

//+------------------------------------------------------------------+
//| Cancel pending orders after given seconds                        |
//+------------------------------------------------------------------+
void CancelExpiredPendingOrders(int expirySeconds, int magicNo)
{

   /*
   datetime now = TimeCurrent();

    ;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != magicNo)
         continue;

      int type = OrderType();

      // Only pending orders
      if(type == OP_BUYSTOP || type == OP_SELLSTOP ||
         type == OP_BUYLIMIT || type == OP_SELLLIMIT)
      {
         datetime openTime = OrderOpenTime();

         if((now - openTime) >= expirySeconds)
         {
            int ticket = OrderTicket();

            if(!OrderDelete(ticket))
            {
               Print("Failed to delete pending order #", ticket,
                     " Error=", GetLastError());
            }
            else
            {
               Print("Deleted expired pending order #", ticket);

         //       if(type == OP_BUYSTOP || type == OP_BUYLIMIT)
         //  ProcessSeqSellOrders(false, false, false);

         //       // PlaceTrendPendingOrderSafe(-1, 0.01, 1000, 5, 12345);
                  
         //       else if(type == OP_SELLSTOP || type == OP_SELLLIMIT)
         //  ProcessSeqBuyOrders(false, false, false);

               // PlaceTrendPendingOrderSafe(1, 0.01, 1000, 5, 12345);
            }
         }
      }
   }

   */
}

int CountAllPendingOrders(int magicNo)
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != magicNo)
         continue;

      int type = OrderType();

      if(type == OP_BUYSTOP || type == OP_SELLSTOP ||
         type == OP_BUYLIMIT || type == OP_SELLLIMIT)
      {
         count++;
      }
   }

   return count;
}
int PlaceTrendPendingOrderSafe(int signal, double lots, int triggerPoints, int slippage, int magicNo)
{


if(CountAllPendingOrders(magicNo) > 0)
   {
      Print("Existing pending order found. Not placing new one.");
      return 0;
   }

   RefreshRates();
   // ATR-based trigger: 1.5x ATR(14) filters fake spikes dynamically
   int atrPoints = (int)(iATR(Symbol(), 0, 14, 1) / Point * 1.5);
   if(atrPoints > 500) triggerPoints = atrPoints;
   int stopLevel = (int)MarketInfo(Symbol(), MODE_STOPLEVEL);
   if(triggerPoints < stopLevel)
      triggerPoints = stopLevel + 10;

   double price = 0;
   int orderType = -1;
   string comment = "";

   if(signal == 1)
   {
      price = NormalizeDouble(Ask + triggerPoints * Point, Digits);
      orderType = OP_BUYSTOP;
      comment = "Trend BUY STOP";
   }
   else if(signal == -1)
   {
      price = NormalizeDouble(Bid - triggerPoints * Point, Digits);
      orderType = OP_SELLSTOP;
      comment = "Trend SELL STOP";
   }
   else
   {
      return 0;
   }

   int ticket = OrderSend(Symbol(), orderType, lots, price, slippage, 0, 0,
                          comment, magicNo, 0, clrBlue);

   if(ticket < 0)
   {
      Print("Pending order failed. Error=", GetLastError(),
            " stopLevel=", stopLevel, " triggerPoints=", triggerPoints);
      return 0;
   }

   Print("Pending order placed at ", DoubleToString(price, Digits));
   return ticket;
}
// Returns:
//  1 = small BUY momentum
// -1 = small SELL momentum
//  0 = no small momentum
int DetectSmallTrendMomentum()
{
   if(Bars < 5) return 0;

   double avg1 = (High[1] + Low[1]) / 2.0;
   double avg2 = (High[2] + Low[2]) / 2.0;
   double avg3 = (High[3] + Low[3]) / 2.0;

   double step1 = (avg1 - avg2) / Point;
   double step2 = (avg2 - avg3) / Point;

   double body1 = MathAbs(Close[1] - Open[1]) / Point;
   double body2 = MathAbs(Close[2] - Open[2]) / Point;

   double ema5  = iMA(Symbol(), 0, 5, 0, MODE_EMA, PRICE_CLOSE, 1);
   double ema20 = iMA(Symbol(), 0, 20, 0, MODE_EMA, PRICE_CLOSE, 1);
   double emaGap = MathAbs(ema5 - ema20) / Point;

   bool smallBodies = (body1 > 50 && body2 > 50 && body1 < 300 && body2 < 300); // BTC sample
   bool smallGap    = (emaGap > 50 && emaGap < 500);

   bool smallUp =
      (step1 > 0 && step2 > 0 &&
       step1 < 400 && step2 < 400 &&
       ema5 > ema20 &&
       smallBodies &&
       smallGap);

   bool smallDown =
      (step1 < 0 && step2 < 0 &&
       MathAbs(step1) < 400 && MathAbs(step2) < 400 &&
       ema5 < ema20 &&
       smallBodies &&
       smallGap);

   if(smallUp)  return 1;
   if(smallDown) return -1;

   return 0;
}