//+------------------------------------------------------------------+
//|                                    V_Small_Type2_GradualTrend.mqh|
//|                 TYPE 2: Gradual Trend Engine (Angle >= 4)        |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Active when MathAbs(GlobalEmaAngle30) >= 4.0 gradually        |
//| 2. Orderly trend momentum following SSL & EMA slope              |
//| 3. Medium-range basket profit ladder ($5.00 - $10.00 * mult)     |
//| 4. Multi-order pair combination profit booking                   |
//| 5. Independent performance tracking and telemetry               |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Type 2 Telemetry Metrics
int    g_type2ClosedTrades = 0;
double g_type2ClosedProfit = 0.0;
int    g_type2WinCount     = 0;
int    g_type2LossCount    = 0;

//+------------------------------------------------------------------+
//| IsType2GradualTrendActive: Check if Type 2 regime is active      |
//+------------------------------------------------------------------+
bool IsType2GradualTrendActive()
  {
   // If Type 3 Spike is active, Type 2 is completely held/frozen
   if(IsType3SpikeActive())
      return false;

   // Active when EMA angle is directional (>= 4.0 degrees)
   return (MathAbs(GlobalEmaAngle30) >= 4.0);
  }

//+------------------------------------------------------------------+
//| ManageType2ProfitBooking: Dedicated Type 2 Profit Booking Engine |
//+------------------------------------------------------------------+
void ManageType2ProfitBooking()
  {
   if(!IsType2GradualTrendActive())
      return;

   // 1. Process standard dynamic multi-order pair combinations
   ModifyPairProfitWithStopLoss();

   // 2. Process standard trend basket profit close
   CheckBasketProfitClose();

   // 3. Process Method 6 multi-order combinations
   ModifyMethod6MultiOrderCombinationsOver5USD();
  }

//+------------------------------------------------------------------+
//| RecordType2ClosedOrder: Tracks Type 2 trade outcome              |
//+------------------------------------------------------------------+
void RecordType2ClosedOrder(int ticket, double netPL)
  {
   g_type2ClosedTrades++;
   g_type2ClosedProfit += netPL;
   if(netPL >= 0.0)
      g_type2WinCount++;
   else
      g_type2LossCount++;
  }
