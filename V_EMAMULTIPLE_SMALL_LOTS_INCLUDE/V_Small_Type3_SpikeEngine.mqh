//+------------------------------------------------------------------+
//|                                     V_Small_Type3_SpikeEngine.mqh|
//|                 TYPE 3: Spike & Climax Reversal Engine           |
//|                                                                  |
//| Characteristics:                                                 |
//| 1. Sudden fast moving away from 200 EMA (violent momentum spike) |
//| 2. Priority State: FREEZES / HOLDS Type 1 and Type 2 methods     |
//| 3. Cuts opposite loss orders immediately to stop drawdown bleed  |
//| 4. Dedicated Spike Profit Booking ($50.00 minimum target)        |
//| 5. Speed Breakers: Horizontal lines (EQL-G / EQH-R) at climax    |
//|    bank maximum spike profit, close losses, & trigger Rebound!   |
//| 6. Rebound rides mean reversion back to yellow 200 EMA touch!    |
//+------------------------------------------------------------------+
#property copyright "Antigravity"
#property link      ""
#property strict

// Type 3 Telemetry Metrics
int    g_type3ClosedTrades      = 0;
double g_type3ClosedProfit      = 0.0;
int    g_type3WinCount          = 0;
int    g_type3LossCount         = 0;
bool   g_type3SpikeActiveState  = false;
datetime g_lastType3LogTime     = 0;

//+------------------------------------------------------------------+
//| IsType3SpikeActive: Check if Type 3 Spike / Climax is active     |
//+------------------------------------------------------------------+
bool IsType3SpikeActive()
  {
   double liveEma200 = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma200 <= 0.0)
      return false;

   double curPrice = (Bid > 0.0) ? Bid : Close[0];
   double distToEma = MathAbs(curPrice - liveEma200);

   // Condition A: Extreme Climax Distance (>= $1000)
   if(distToEma >= GetTwoWayClimaxMinDistance())
     {
      g_type3SpikeActiveState = true;
      return true;
     }

   // Condition B: Fast Distance Expansion away from 200 EMA with steep angle
   if(InpEnableFastMovingEmaSpike && distToEma >= InpFastSpikeMinDistance)
     {
      double fastAngle = GetEmaAngleDegrees(InpFastSpikeLookbackBars);
      double stdAngle  = GlobalEmaAngle30;

      // Fast Downward Spike below EMA
      if(curPrice < liveEma200 && (fastAngle <= -InpFastSpikeMinAngle || stdAngle <= -InpFastSpikeMinAngle))
        {
         g_type3SpikeActiveState = true;
         return true;
        }

      // Fast Upward Spike above EMA
      if(curPrice > liveEma200 && (fastAngle >= InpFastSpikeMinAngle || stdAngle >= InpFastSpikeMinAngle))
        {
         g_type3SpikeActiveState = true;
         return true;
        }
     }

   // Condition C: Velocity Shock - EMA Distance expanded >= $300 in 5 minutes (User Observation)
   if(InpEnableType3SpikeVelocityFilter)
     {
      int lookbackBars = (Period() == PERIOD_M1) ? InpType3SpikeVelocityLookbackM1 : (int)MathMax(1, 5 / Period());
      if(Bars > lookbackBars)
        {
         double pastEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, lookbackBars);
         double pastPrice = Close[lookbackBars];
         double pastDist = MathAbs(pastPrice - pastEma);
         double deltaDist = distToEma - pastDist;

         if(deltaDist >= InpType3Spike5MinDistanceChange)
           {
            g_type3SpikeActiveState = true;
            return true;
           }
        }
     }

   // Condition C: Active Open Spike or Two-Way orders exist on account
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string cmt = OrderComment();
      if(StringFind(cmt, "SPIKE") >= 0 || StringFind(cmt, "M7_") == 0 || StringFind(cmt, "T3_") == 0)
        {
         g_type3SpikeActiveState = true;
         return true;
        }
     }

   g_type3SpikeActiveState = false;
   return false;
  }

//+------------------------------------------------------------------+
//| ProcessType3SpikeExecution: Master Execution for Type 3 Engine   |
//+------------------------------------------------------------------+
void ProcessType3SpikeExecution()
  {
   if(!IsType3SpikeActive())
      return;

   double liveEma200 = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma200 <= 0.0)
      return;

   // 1. Process Two-Way Waterfall Distance-Expansion Orders
   double distForTwoWay = MathAbs(Bid - liveEma200);
   CheckTwoWayFallingAndRisingOrders(liveEma200, distForTwoWay, EMADirection);

   // 2. Process Climax Opposite Runner Liquidation
   CheckTwoWayClimaxRunnerLiquidation(distForTwoWay, EMADirection);

   // 3. Process Climax Horizontal Line ("Speed Breaker") Rebound Entries
   CheckTwoWayReboundEntries();
  }

//+------------------------------------------------------------------+
//| ManageType3ProfitBooking: Dedicated Type 3 Profit Booking Engine |
//+------------------------------------------------------------------+
void ManageType3ProfitBooking()
  {
   // 1. Manage Two-Way Waterfall Trailing Stops & Rebound EMA-touch profit closes
   ManageTwoWayReboundAndWaterfallOrders();

   // 2. Manage Spike $50 Minimum Profit Ladder with Climax Speed-Breaker Take-Profit
   ManageSpikeProfitLadder();
  }

//+------------------------------------------------------------------+
//| RecordType3ClosedOrder: Tracks Type 3 trade outcome              |
//+------------------------------------------------------------------+
void RecordType3ClosedOrder(int ticket, double netPL)
  {
   g_type3ClosedTrades++;
   g_type3ClosedProfit += netPL;
   if(netPL >= 0.0)
      g_type3WinCount++;
   else
      g_type3LossCount++;
  }

//+------------------------------------------------------------------+
//| PrintThreeTypeTelemetrySummary: Detailed Multi-Type Diagnostics  |
//+------------------------------------------------------------------+
void PrintThreeTypeTelemetrySummary()
  {
   if(TimeCurrent() - g_lastType3LogTime < 60)
      return;
   g_lastType3LogTime = TimeCurrent();

   double t1WinRate = (g_type1ClosedTrades > 0) ? ((double)g_type1WinCount / g_type1ClosedTrades * 100.0) : 0.0;
   double t2WinRate = (g_type2ClosedTrades > 0) ? ((double)g_type2WinCount / g_type2ClosedTrades * 100.0) : 0.0;
   double t3WinRate = (g_type3ClosedTrades > 0) ? ((double)g_type3WinCount / g_type3ClosedTrades * 100.0) : 0.0;

   string activeRegime = "[TYPE 1: OSCILLATION]";
   if(IsType3SpikeActive())
      activeRegime = "[TYPE 3: SPIKE & CLIMAX]";
   else if(IsType2GradualTrendActive())
      activeRegime = "[TYPE 2: GRADUAL TREND]";

   Print(">>> ================================================================================");
   PrintFormat(">>> [3-TYPE SYSTEM TELEMETRY] ACTIVE REGIME: %s | EMA Angle=%.1f deg", activeRegime, GlobalEmaAngle30);
   PrintFormat(">>> [TYPE 1: OSCILLATION ] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type1ClosedTrades, g_type1ClosedProfit, g_type1WinCount, g_type1LossCount, t1WinRate);
   PrintFormat(">>> [TYPE 2: GRADUAL TRD ] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type2ClosedTrades, g_type2ClosedProfit, g_type2WinCount, g_type2LossCount, t2WinRate);
   PrintFormat(">>> [TYPE 3: SPIKE/CLIMAX] Trades: %3d | Net P/L: $%7.2f | Wins: %d | Losses: %d | WinRate: %5.1f%%",
               g_type3ClosedTrades, g_type3ClosedProfit, g_type3WinCount, g_type3LossCount, t3WinRate);
   Print(">>> ================================================================================");
  }

//+------------------------------------------------------------------+
//| GetThreeTypeActiveStatusDisplay: For Dashboard Visualization     |
//+------------------------------------------------------------------+
string GetThreeTypeActiveStatusDisplay()
  {
   if(IsType3SpikeActive())
      return "[TYPE 3: SPIKE ACTIVE]";
   if(IsType2GradualTrendActive())
      return "[TYPE 2: TREND ACTIVE]";
   return "[TYPE 1: RANGE OSC]";
  }

//+------------------------------------------------------------------+
//| GetThreeTypeActiveStatusColor: For Dashboard Visualization       |
//+------------------------------------------------------------------+
color GetThreeTypeActiveStatusColor()
  {
   if(IsType3SpikeActive())
      return clrOrangeRed;
   if(IsType2GradualTrendActive())
      return clrAqua;
   return clrLime;
  }


//+------------------------------------------------------------------+
//| DrawSpikeLifecycleSignal: Display Visual Icons & Labels on Chart|
//| Stages:                                                          |
//| 1. "SPIKE_START"     : SPIKE started                             |
//| 2. "SPIKE_END"       : SPIKE END                                 |
//| 3. "SPIKE_REV_START" : SPIKE reverse started                     |
//| 4. "SPIKE_REV_END"   : SPIKE REVER END                           |
//+------------------------------------------------------------------+
void DrawSpikeLifecycleSignal(string stage, int dir, double price, string details = "")
  {
   if(!InpEnableSpikeLifecycleVisuals)
      return;

   static int s_spikeObjSeq = 0;
   s_spikeObjSeq++;

   datetime barTime = Time[0];
   double offset = (SignalDistancePoints > 0 ? SignalDistancePoints : 100) * Point;
   if(offset < 10.0 * Point)
      offset = 10.0 * Point;

   int    iconCode    = 233;
   color  sigColor    = clrLime;
   string labelText   = "";
   double markerPrice = price;
   double textPrice   = price;

   if(stage == "SPIKE_START")
     {
      if(dir >= 0) // Bullish Spike
        {
         iconCode    = 233; // Wingdings Bold UP Arrow
         sigColor    = clrLime;
         labelText   = "▲ SPIKE STARTED [BULL]";
         markerPrice = Low[0] - offset;
         textPrice   = markerPrice - (offset * 0.8);
        }
      else // Bearish Spike
        {
         iconCode    = 234; // Wingdings Bold DOWN Arrow
         sigColor    = clrRed;
         labelText   = "▼ SPIKE STARTED [BEAR]";
         markerPrice = High[0] + offset;
         textPrice   = markerPrice + (offset * 0.8);
        }
     }
   else if(stage == "SPIKE_END")
     {
      iconCode = 254; // Wingdings Solid Square (Speed Breaker Barrier)
      sigColor = clrOrangeRed;
      if(dir >= 0) // Top ceiling hit (EQH-R)
        {
         labelText   = "■ SPIKE END [EQH-R CEILING]";
         markerPrice = (price > 0.0) ? price : High[0];
         textPrice   = markerPrice + offset;
        }
      else // Bottom floor hit (EQL-G)
        {
         labelText   = "■ SPIKE END [EQL-G FLOOR]";
         markerPrice = (price > 0.0) ? price : Low[0];
         textPrice   = markerPrice - offset;
        }
     }
   else if(stage == "SPIKE_REV_START")
     {
      iconCode = 171; // Wingdings Solid Star (Rebound Ignition)
      if(dir >= 0) // BUY Rebound off floor
        {
         sigColor    = clrAqua;
         labelText   = "★ SPIKE REVERSE STARTED [BUY -> EMA]";
         markerPrice = Low[0] - offset;
         textPrice   = markerPrice - (offset * 0.8);
        }
      else // SELL Rebound off ceiling
        {
         sigColor    = clrMagenta;
         labelText   = "★ SPIKE REVERSE STARTED [SELL -> EMA]";
         markerPrice = High[0] + offset;
         textPrice   = markerPrice + (offset * 0.8);
        }
     }
   else if(stage == "SPIKE_REV_END")
     {
      iconCode    = 251; // Wingdings Checkmark (Target reached)
      sigColor    = clrGold;
      labelText   = "✔ SPIKE REVER END [200 EMA TOUCH]";
      markerPrice = (price > 0.0) ? price : Close[0];
      textPrice   = (dir >= 0) ? (markerPrice + offset * 0.8) : (markerPrice - offset * 0.8);
     }
   else
     {
      return;
     }

   string baseName = StringFormat("SPK_MKR_%s_%d_%d", stage, (int)TimeCurrent(), s_spikeObjSeq);
   string txtName  = StringFormat("SPK_TXT_%s_%d_%d", stage, (int)TimeCurrent(), s_spikeObjSeq);
   string tooltip  = StringFormat("%s at %.2f | %s | %s", labelText, price, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), details);

   // 1. Icon Marker
   if(ObjectFind(0, baseName) < 0)
      ObjectCreate(0, baseName, OBJ_ARROW, 0, barTime, markerPrice);
   else
      ObjectMove(0, baseName, 0, barTime, markerPrice);
   ObjectSetInteger(0, baseName, OBJPROP_ARROWCODE, iconCode);
   ObjectSetInteger(0, baseName, OBJPROP_COLOR, sigColor);
   ObjectSetInteger(0, baseName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, baseName, OBJPROP_BACK, false);
   ObjectSetInteger(0, baseName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, baseName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, baseName, OBJPROP_TOOLTIP, tooltip);

   // 2. Bold Text Label
   if(ObjectFind(0, txtName) < 0)
      ObjectCreate(0, txtName, OBJ_TEXT, 0, barTime, textPrice);
   else
      ObjectMove(0, txtName, 0, barTime, textPrice);
   ObjectSetString(0, txtName, OBJPROP_TEXT, labelText);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 9);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, sigColor);
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, txtName, OBJPROP_TOOLTIP, tooltip);

   ChartRedraw(0);

   PrintFormat(">>> [SPIKE CHART SIGNAL] Placed '%s' at %.2f | Bar=%s | Details: %s",
               labelText, price, TimeToString(barTime, TIME_DATE|TIME_MINUTES), details);
  }
