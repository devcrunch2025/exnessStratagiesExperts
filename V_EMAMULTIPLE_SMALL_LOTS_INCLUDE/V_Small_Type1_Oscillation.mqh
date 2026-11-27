//+------------------------------------------------------------------+
//|                                     V_Small_Type1_Oscillation.mqh|
//|                 TYPE 1: Oscillation / Range Engine (Angle <= 3)  |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Active when MathAbs(GlobalEmaAngle30) <= 3.0 (flat/choppy)    |
//| 2. Price oscillating between up and down around 200 EMA          |
//| 3. Micro-scalping, quick profit booking ($1.00 - $2.00 * mult)   |
//| 4. Tight breathing breakeven stop loss                           |
//| 5. Independent performance tracking and telemetry               |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Type 1 Telemetry Metrics
int    g_type1ClosedTrades = 0;
double g_type1ClosedProfit = 0.0;
int    g_type1WinCount     = 0;
int    g_type1LossCount    = 0;

//+------------------------------------------------------------------+
//| IsType1OscillationActive: Check if Type 1 regime is active       |
//+------------------------------------------------------------------+
bool IsType1OscillationActive()
  {
   // If Type 3 Spike is active, Type 1 is completely held/frozen
   if(IsType3SpikeActive())
      return false;

   // Active when EMA angle is flat/oscillating (<= 3.0 degrees)
   return (MathAbs(GlobalEmaAngle30) <= 3.0);
  }

//+------------------------------------------------------------------+
//| ManageType1ProfitBooking: Dedicated Type 1 Profit Booking Engine |
//+------------------------------------------------------------------+
void ManageType1ProfitBooking()
  {
   if(!IsType1OscillationActive())
      return;

   double mult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double targetProfit = 1.0 * mult; // Quick $1.00 micro-scalp in range
   double slGapMin = GetEffectiveMinSLModifyGap();
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      string cmt = OrderComment();
      // Exclude Type 3 and Recovery orders
      if(StringFind(cmt, "T3_") >= 0 || StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "M7_") >= 0 || IsAnyRecoveryOrder(OrderTicket(), cmt))
         continue;

      double curPL = OrderProfit() + OrderSwap() + OrderCommission();
      double openPrice = OrderOpenPrice();
      double curSL = OrderStopLoss();
      int tkt = OrderTicket();

      // Case 1: Order reached $1.00 * mult target in oscillation -> lock breakeven + tight cushion
      if(curPL >= targetProfit)
        {
         if(oType == OP_BUY)
           {
            double newSL = NormalizeDouble(openPrice + 10.0 * Point, Digits);
            if(newSL > openPrice && (curSL == 0.0 || newSL > curSL + slGapMin))
              {
               SafeOrderModify(tkt, openPrice, newSL, OrderTakeProfit(), 0, clrLime, "T1_OSC_BE_Lock");
              }
           }
         else if(oType == OP_SELL)
           {
            double newSL = NormalizeDouble(openPrice - 10.0 * Point, Digits);
            if(newSL < openPrice && (curSL == 0.0 || newSL < curSL - slGapMin))
              {
               SafeOrderModify(tkt, openPrice, newSL, OrderTakeProfit(), 0, clrTomato, "T1_OSC_BE_Lock");
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| RecordType1ClosedOrder: Tracks Type 1 trade outcome              |
//+------------------------------------------------------------------+
void RecordType1ClosedOrder(int ticket, double netPL)
  {
   g_type1ClosedTrades++;
   g_type1ClosedProfit += netPL;
   if(netPL >= 0.0)
      g_type1WinCount++;
   else
      g_type1LossCount++;
  }
