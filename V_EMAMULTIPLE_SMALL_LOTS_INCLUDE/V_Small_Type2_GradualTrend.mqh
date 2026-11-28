//+------------------------------------------------------------------+
//|                                    V_Small_Type2_GradualTrend.mqh|
//|         TYPE 2: Gradual Trend Engine (3.0 < |Angle| <= 8.0)      |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Active when 3.0 < |EMA Angle| <= 8.0 (not in Spike)           |
//| 2. Individual order profits follow Table B price-gap movement    |
//|    ($200 L1 -> +$25 SL, every +$150 step -> +$150 SL + half-close)|
//| 3. Executed cleanly via SecureOneDollarProfit()                  |
//| 4. Basket, Day Target & Method 6 profit engines run as usual     |
//| 5. Independent performance tracking and telemetry                |
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
   // If Type 3 Spike is active, Type 2 is held
   if(IsType3SpikeActive())
      return false;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   // Active when 3.0 < |EMA Angle| <= 8.0 -> uses Table B
   return IsLadderType2AngleRange(MathAbs(curAngle));
  }

//+------------------------------------------------------------------+
//| ManageType2ProfitBooking: Dedicated Type 2 Profit Booking Hook   |
//| Individual Type 2 orders follow Table B ($200 L1 / $150 step)    |
//| via SecureOneDollarProfit(); Method 6 / Basket / Day run as usual|
//+------------------------------------------------------------------+
void ManageType2ProfitBooking()
  {
   if(!IsType2GradualTrendActive())
      return;

   // Individual Type 2 orders are secured cleanly once per tick by SecureOneDollarProfit() -> Table B.
   // Basket, Day Target, and Method 6 run as usual once per tick at the top of OnTick().
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
