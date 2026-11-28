//+------------------------------------------------------------------+
//|                                     V_Small_Type1_Oscillation.mqh|
//|         TYPE 1: Range / Steep Angle Engine (|Angle| <= 3 or > 8) |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Active when |Angle| <= 3.0 or |Angle| > 8.0 (not in Spike)    |
//| 2. Individual order profits follow Table A price-gap movement    |
//|    ($100 L1 -> +$25 SL, every +$50 step -> +$50 SL + half-close) |
//| 3. Executed cleanly via SecureOneDollarProfit() without early BE |
//| 4. Basket, Day Target & Method 6 profit engines run as usual     |
//| 5. Independent performance tracking and telemetry                |
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
   // If Type 3 Spike is active, Type 1 is held
   if(IsType3SpikeActive())
      return false;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   // Active outside Type 2 range (|Angle| <= 3.0 or |Angle| > 8.0) -> uses Table A
   return !IsLadderType2AngleRange(MathAbs(curAngle));
  }

//+------------------------------------------------------------------+
//| ManageType1ProfitBooking: Dedicated Type 1 Profit Booking Hook   |
//| Individual order profits follow Table A ($100 L1 / $50 step) via |
//| SecureOneDollarProfit() (no premature $1*mult BE clamp before L1)|
//+------------------------------------------------------------------+
void ManageType1ProfitBooking()
  {
   if(!IsType1OscillationActive())
      return;

   // Individual Type 1 orders are secured cleanly once per tick by SecureOneDollarProfit() -> Table A.
   // Basket, Day Target, and Method 6 run as usual at the top of OnTick().
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
