import os

mq4_path = r'V_EMAMULTIPLE_ORDERS.mq4'
with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    orig = f.read()

content = orig.replace('\r\n', '\n')

replacements = []

# 1. Version
old_v = 'string glbVersion = "VMULTI-1104- Special Chart Icons on EquityProfitLadder5 Every Step Hit";'
new_v = 'string glbVersion = "VMULTI-1105- EMA Angle > 4 Breakeven Extra -50 Raw Gap Breathing SL";'
replacements.append(("Version", old_v, new_v))

# 2. Inputs
old_inp = '''bool   InpEnableDoubleSlGapOnSteepAngle    = true;  // Double SL gap (e.g. $150 -> $300) when MathAbs(EMAangle) > 3.0 & raw profit gap > $500
double InpDoubleSlGapAngle                 = 3.0;   // Minimum EMA angle (degrees) to double the SL gap (MathAbs(EMAangle) > 3.0)
double InpDoubleSlMinProfitGapRaw          = 350;//500.0; // Minimum raw price gap ($500.0) in profit direction (openprice - liveprice)
double InpDoubleSlGapMultiplier            = 2.0;   // Gap multiplier (default 2.0 = double gap $150 to $300)'''

new_inp = '''bool   InpEnableDoubleSlGapOnSteepAngle    = true;  // Double SL gap (e.g. $150 -> $300) when MathAbs(EMAangle) > 3.0 & raw profit gap > $500
double InpDoubleSlGapAngle                 = 3.0;   // Minimum EMA angle (degrees) to double the SL gap (MathAbs(EMAangle) > 3.0)
double InpDoubleSlMinProfitGapRaw          = 350;//500.0; // Minimum raw price gap ($500.0) in profit direction (openprice - liveprice)
double InpDoubleSlGapMultiplier            = 2.0;   // Gap multiplier (default 2.0 = double gap $150 to $300)

// USER RULE (VMULTI-1105): EMA Angle > 4 Breakeven Extra -50 Raw Gap Breathing SL
bool   InpEnableEmaAngleBreakevenBreathing = true;   // When MathAbs(EMAangle) > 4: allow extra -50 raw gap when SL is at openPrice
double InpEmaAngleBreakevenBreathingAngle  = 4.0;    // Minimum MathAbs(EMAangle) threshold (default > 4.0)
double InpEmaAngleBreakevenBreathingGapRaw = 50.0;   // Extra raw price gap based on order price (-50.0 raw gap)'''
replacements.append(("Inputs", old_inp, new_inp))

# 3. Forward declaration
old_decl = 'void     DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step);'
new_decl = '''void     DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step);
double   GetEmaAngleBreakevenBreathingSL(int orderType, double openPrice, double proposedSL, double curAngle = 0.0);
double   GetEmaAngleDegrees(int lookbackBars = 5);'''
replacements.append(("Forward Decl", old_decl, new_decl))

# 4. GetEmaAngleBreakevenBreathingSL function definition
old_calc_header = '''//+------------------------------------------------------------------+
//| CalculateProportionalLadderSL:                                   |'''

new_calc_header = '''//+------------------------------------------------------------------+
//| GetEmaAngleBreakevenBreathingSL                                   |
//| USER RULE (VMULTI-1105):                                         |
//| When MathAbs(EMAangle) is more than 4, allow order to modify     |
//| extra -50 raw gap based on order price when new SL price is equal|
//| to order openprice (Breakeven).                                  |
//|   BUY : openPrice - 50.0 raw price gap                           |
//|   SELL: openPrice + 50.0 raw price gap                           |
//| Prevents orders from being stopped out at 0.00 profit during     |
//| minor 3-5 min pullbacks right before strong trend continuation.  |
//+------------------------------------------------------------------+
double GetEmaAngleBreakevenBreathingSL(int orderType, double openPrice, double proposedSL, double curAngle = 0.0)
  {
   if(!InpEnableEmaAngleBreakevenBreathing)
      return proposedSL;
   if(openPrice <= 0.0 || proposedSL <= 0.0)
      return proposedSL;

   // Check if proposed SL is equal to order openPrice (Breakeven)
   if(NormalizeDouble(proposedSL, Digits) != NormalizeDouble(openPrice, Digits))
      return proposedSL;

   if(curAngle == 0.0)
     {
      curAngle = GlobalEmaAngle30;
      if(curAngle == 0.0)
         curAngle = GetEmaAngleDegrees(30);
     }

   if(MathAbs(curAngle) > InpEmaAngleBreakevenBreathingAngle)
     {
      double breathingSL = proposedSL;
      if(orderType == OP_BUY)
         breathingSL = NormalizeDouble(openPrice - InpEmaAngleBreakevenBreathingGapRaw, Digits);
      else if(orderType == OP_SELL)
         breathingSL = NormalizeDouble(openPrice + InpEmaAngleBreakevenBreathingGapRaw, Digits);

      Print(">>> [EMA ANGLE BREAKEVEN BREATHING] OrderType=", (orderType == OP_BUY ? "BUY" : "SELL"),
            " | OpenPrice=", DoubleToString(openPrice, Digits),
            " | SL adjusted from openPrice to Breathing SL=", DoubleToString(breathingSL, Digits),
            " (extra -50 raw gap based on order price, MathAbs(EMAangle)=", DoubleToString(MathAbs(curAngle), 2),
            " > ", DoubleToString(InpEmaAngleBreakevenBreathingAngle, 1), " deg)");

      return breathingSL;
     }

   return proposedSL;
  }

//+------------------------------------------------------------------+
//| CalculateProportionalLadderSL:                                   |'''
replacements.append(("Def GetEmaAngleBreakevenBreathingSL", old_calc_header, new_calc_header))

# 5. CalculateProportionalLadderSL Level 1 breathing SL
old_ladder_sl = '''   double ladderSL = 0.0;

   if(orderType == OP_BUY)
      ladderSL = NormalizeDouble(openPrice + lockedDistance, Digits);
   else
      if(orderType == OP_SELL)
         ladderSL = NormalizeDouble(openPrice - lockedDistance, Digits);

   return ladderSL;'''

new_ladder_sl = '''   double ladderSL = 0.0;

   if(orderType == OP_BUY)
      ladderSL = NormalizeDouble(openPrice + lockedDistance, Digits);
   else
      if(orderType == OP_SELL)
         ladderSL = NormalizeDouble(openPrice - lockedDistance, Digits);

   // USER RULE (VMULTI-1105): When Level 1 (Breakeven) and MathAbs(EMAangle) > 4, allow extra -50 raw gap breathing SL
   if(ladderLevel == 1)
     {
      ladderSL = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, ladderSL);
     }

   return ladderSL;'''
replacements.append(("LadderSL Level 1", old_ladder_sl, new_ladder_sl))

# 6. Method 1 breathing floor
old_m1 = '''      // Clamp proposedSL to openPrice if profit gap reached (USER RULE: never modify with loss amount)
      if(isProfitGapReached)
        {
         if(oType == OP_BUY && proposedSL < oOpen)
            proposedSL = oOpen;
         else
            if(oType == OP_SELL && proposedSL > oOpen)
               proposedSL = oOpen;
        }

      bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= oOpen : proposedSL <= oOpen));'''

new_m1 = '''      // Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
      double beFloorM1 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
      if(isProfitGapReached)
        {
         if(oType == OP_BUY && proposedSL < beFloorM1)
            proposedSL = beFloorM1;
         else
            if(oType == OP_SELL && proposedSL > beFloorM1)
               proposedSL = beFloorM1;
        }

      bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM1 : proposedSL <= beFloorM1));'''
replacements.append(("Method 1", old_m1, new_m1))

# 7. Method 6 breathing floor
old_m6 = '''         // Ensure profit order maintains at least Breakeven
         if(oType == OP_BUY && targetSL < oOpen)
            targetSL = oOpen;
         else
            if(oType == OP_SELL && targetSL > oOpen)
               targetSL = oOpen;'''

new_m6 = '''         // Ensure profit order maintains at least Breakeven or breathing SL (USER RULE: VMULTI-1105)
         double beFloorM6 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
         if(oType == OP_BUY && targetSL < beFloorM6)
            targetSL = beFloorM6;
         else
            if(oType == OP_SELL && targetSL > beFloorM6)
               targetSL = beFloorM6;'''
replacements.append(("Method 6", old_m6, new_m6))

# 8. Method 4 breathing floor
old_m4 = '''// Clamp proposedSL to openPrice if profit gap reached (USER RULE: never modify with loss amount)
   if(isProfitGapReached)
     {
      if(oType == OP_BUY && proposedSL < oOpen)
         proposedSL = oOpen;
      else
         if(oType == OP_SELL && proposedSL > oOpen)
            proposedSL = oOpen;
     }

   bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= oOpen : proposedSL <= oOpen));'''

new_m4 = '''// Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
   double beFloorM4 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
   if(isProfitGapReached)
     {
      if(oType == OP_BUY && proposedSL < beFloorM4)
         proposedSL = beFloorM4;
      else
         if(oType == OP_SELL && proposedSL > beFloorM4)
            proposedSL = beFloorM4;
     }

   bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM4 : proposedSL <= beFloorM4));'''
replacements.append(("Method 4", old_m4, new_m4))

# 9. Method 5 breathing floor
old_m5 = '''         // Clamp proposedSL to openPrice if profit gap reached (USER RULE: never modify with loss amount)
         if(isProfitGapReached)
           {
            if(oType == OP_BUY && proposedSL < oOpen)
               proposedSL = oOpen;
            else
               if(oType == OP_SELL && proposedSL > oOpen)
                  proposedSL = oOpen;
           }

         bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= oOpen : proposedSL <= oOpen));'''

new_m5 = '''         // Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
         double beFloorM5 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
         if(isProfitGapReached)
           {
            if(oType == OP_BUY && proposedSL < beFloorM5)
               proposedSL = beFloorM5;
            else
               if(oType == OP_SELL && proposedSL > beFloorM5)
                  proposedSL = beFloorM5;
           }

         bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM5 : proposedSL <= beFloorM5));'''
replacements.append(("Method 5", old_m5, new_m5))

# 10. SafeOrderClose
old_soc = '''      // If before Level 1 step, protect 0 Loss (Breakeven) if currently in profit
      if((orderType == OP_BUY && Bid > openPrice) || (orderType == OP_SELL && Ask < openPrice))
        {
         newSL = openPrice;
        }'''

new_soc = '''      // If before Level 1 step, protect 0 Loss (Breakeven) or breathing SL if currently in profit
      if((orderType == OP_BUY && Bid > openPrice) || (orderType == OP_SELL && Ask < openPrice))
        {
         newSL = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice);
        }'''
replacements.append(("SafeOrderClose", old_soc, new_soc))

# 11. CanModifyStopLossForHigherProfit
old_guard = '''// USER RULE: Orders secured by Equity Target Hit:
// "profit stoploss value ok. loss stoploss is not ok."
   if(IsEquityHitSecuredOrder(ticket) && callerName != "EquityTargetHit_LossTighten" && callerName != "DrawdownRelief50Pct" && StringFind(callerName, "Method") < 0)
     {
      bool isLossSL = (oType == OP_BUY && normPropSL < oOpen) || (oType == OP_SELL && normPropSL > oOpen);
      if(isLossSL)
        {
         Print(">>> [EQUITY HIT ORDER PROTECTED] Ticket #", ticket, " (", (oType == OP_BUY ? "BUY " : "SELL "),
               DoubleToString(oLots, 2), "L) was secured by Equity Target Hit.",
               " | Proposed SL=", DoubleToString(normPropSL, Digits),
               " is a LOSS Stop Loss (Open=", DoubleToString(oOpen, Digits), ")",
               (callerName != "" ? " | Caller=" + callerName : ""),
               " | REJECTED: Rule: Only profit stoploss value is permitted, loss stoploss is NOT OK!");
         return false;
        }
     }'''

new_guard = '''// USER RULE: Orders secured by Equity Target Hit:
// "profit stoploss value ok. loss stoploss is not ok."
   if(IsEquityHitSecuredOrder(ticket) && callerName != "EquityTargetHit_LossTighten" && callerName != "DrawdownRelief50Pct" && StringFind(callerName, "Method") < 0)
     {
      bool isLossSL = (oType == OP_BUY && normPropSL < oOpen) || (oType == OP_SELL && normPropSL > oOpen);
      if(isLossSL)
        {
         // USER RULE (VMULTI-1105): Allow extra -50 raw gap breathing SL when MathAbs(EMAangle) > 4.0
         double beBreathing = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
         bool isAllowedBreathing = (InpEnableEmaAngleBreakevenBreathing &&
                                    ((oType == OP_BUY && normPropSL >= beBreathing) ||
                                     (oType == OP_SELL && normPropSL <= beBreathing)));
         if(!isAllowedBreathing)
           {
            Print(">>> [EQUITY HIT ORDER PROTECTED] Ticket #", ticket, " (", (oType == OP_BUY ? "BUY " : "SELL "),
                  DoubleToString(oLots, 2), "L) was secured by Equity Target Hit.",
                  " | Proposed SL=", DoubleToString(normPropSL, Digits),
                  " is a LOSS Stop Loss (Open=", DoubleToString(oOpen, Digits), ")",
                  (callerName != "" ? " | Caller=" + callerName : ""),
                  " | REJECTED: Rule: Only profit stoploss value is permitted, loss stoploss is NOT OK!");
            return false;
           }
        }
     }'''
replacements.append(("CanModifyStopLossForHigherProfit", old_guard, new_guard))

# 12. GetTrendAwareStopLoss
old_tasl = '''         if(openPrice > 0.0 && sl < openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))
            sl = openPrice; // USER RULE: Never modify order with loss amount (BUY order not less than openPrice)
         if(curSL > 0.0 && sl <= curSL)
            sl = curSL;
         return sl;
        }
      else
         if(orderType == OP_SELL)
           {
            double sl = NormalizeDouble(curAsk + gap, Digits);
            if((sl - curAsk) < minStopDist)
               sl = NormalizeDouble(curAsk + minStopDist, Digits);
            if(openPrice > 0.0 && sl > openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))
               sl = openPrice; // USER RULE: Never modify order with loss amount (SELL order not greater than openPrice)
            if(curSL > 0.0 && sl >= curSL)
               sl = curSL;
            return sl;
           }
      return 0.0;
     }

   bool isEmaWeak = IsEmaWEAKDistanceReduced50PercentFromPeak(orderType);
   double liveBuffer = (InpEmaTrendAwareLivePriceGapUSD > minStopDist) ? InpEmaTrendAwareLivePriceGapUSD : minStopDist;
   double targetSL = 0.0;

   if(orderType == OP_BUY)
     {
      // Condition 1: BUY and EMADirection == 1 and EMA strong -> standard gap logic
      if(EMADirection == 1 && !isEmaWeak)
        {
         targetSL = NormalizeDouble(curBid - gap, Digits);
         if((curBid - targetSL) < minStopDist)
            targetSL = NormalizeDouble(curBid - minStopDist, Digits);
        }
      else
        {
         // Condition 2: BUY and (EMADirection == -1 or EMA weak) -> live price to avoid extra loss
         targetSL = NormalizeDouble(curBid - liveBuffer, Digits);
         if(curSL <= 0.0 || targetSL > curSL)
           {
            Print(">>> [TREND-AWARE SL] BUY", (callerName != "" ? " (" + callerName + ")" : ""),
                  ": EMA Dir=", EMADirection, ", Weak=", isEmaWeak,
                  " -> Setting SL to Live Price (Bid - ", DoubleToString(liveBuffer, Digits), ") = ",
                  DoubleToString(targetSL, Digits), " (Standard gap $", DoubleToString(gap, 2), " skipped to prevent loss)");
           }
        }

      // Ensure profit-locking order maintains at least Breakeven
      if(openPrice > 0.0 && targetSL < openPrice && isProfitGapReached)
         targetSL = openPrice;

      // Universal Ratchet: StopLoss can never go backwards from existing curSL
      if(curSL > 0.0 && targetSL <= curSL)
         targetSL = curSL;
     }
   else
      if(orderType == OP_SELL)
        {
         // Condition 1: SELL and EMADirection == -1 and EMA strong -> standard gap logic
         if(EMADirection == -1 && !isEmaWeak)
           {
            targetSL = NormalizeDouble(curAsk + gap, Digits);
            if((targetSL - curAsk) < minStopDist)
               targetSL = NormalizeDouble(curAsk + minStopDist, Digits);
           }
         else
           {
            // Condition 2: SELL and (EMADirection == 1 or EMA weak) -> live price to avoid extra loss
            targetSL = NormalizeDouble(curAsk + liveBuffer, Digits);
            if(curSL <= 0.0 || targetSL < curSL)
              {
               Print(">>> [TREND-AWARE SL] SELL", (callerName != "" ? " (" + callerName + ")" : ""),
                     ": EMA Dir=", EMADirection, ", Weak=", isEmaWeak,
                     " -> Setting SL to Live Price (Ask + ", DoubleToString(liveBuffer, Digits), ") = ",
                     DoubleToString(targetSL, Digits), " (Standard gap $", DoubleToString(gap, 2), " skipped to prevent loss)");
              }
           }

         // Ensure profit-locking order maintains at least Breakeven
         if(openPrice > 0.0 && targetSL > openPrice && isProfitGapReached)
            targetSL = openPrice;'''

new_tasl = '''         if(openPrice > 0.0 && sl < openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))
            sl = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice, curAngle); // USER RULE (VMULTI-1105): Breakeven or breathing SL
         if(curSL > 0.0 && sl <= curSL)
            sl = curSL;
         return sl;
        }
      else
         if(orderType == OP_SELL)
           {
            double sl = NormalizeDouble(curAsk + gap, Digits);
            if((sl - curAsk) < minStopDist)
               sl = NormalizeDouble(curAsk + minStopDist, Digits);
            if(openPrice > 0.0 && sl > openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))
               sl = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice, curAngle); // USER RULE (VMULTI-1105): Breakeven or breathing SL
            if(curSL > 0.0 && sl >= curSL)
               sl = curSL;
            return sl;
           }
      return 0.0;
     }

   bool isEmaWeak = IsEmaWEAKDistanceReduced50PercentFromPeak(orderType);
   double liveBuffer = (InpEmaTrendAwareLivePriceGapUSD > minStopDist) ? InpEmaTrendAwareLivePriceGapUSD : minStopDist;
   double targetSL = 0.0;

   if(orderType == OP_BUY)
     {
      // Condition 1: BUY and EMADirection == 1 and EMA strong -> standard gap logic
      if(EMADirection == 1 && !isEmaWeak)
        {
         targetSL = NormalizeDouble(curBid - gap, Digits);
         if((curBid - targetSL) < minStopDist)
            targetSL = NormalizeDouble(curBid - minStopDist, Digits);
        }
      else
        {
         // Condition 2: BUY and (EMADirection == -1 or EMA weak) -> live price to avoid extra loss
         targetSL = NormalizeDouble(curBid - liveBuffer, Digits);
         if(curSL <= 0.0 || targetSL > curSL)
           {
            Print(">>> [TREND-AWARE SL] BUY", (callerName != "" ? " (" + callerName + ")" : ""),
                  ": EMA Dir=", EMADirection, ", Weak=", isEmaWeak,
                  " -> Setting SL to Live Price (Bid - ", DoubleToString(liveBuffer, Digits), ") = ",
                  DoubleToString(targetSL, Digits), " (Standard gap $", DoubleToString(gap, 2), " skipped to prevent loss)");
           }
        }

      // Ensure profit-locking order maintains at least Breakeven / breathing floor
      if(openPrice > 0.0 && targetSL < openPrice && isProfitGapReached)
         targetSL = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice, curAngle);

      // Universal Ratchet: StopLoss can never go backwards from existing curSL
      if(curSL > 0.0 && targetSL <= curSL)
         targetSL = curSL;
     }
   else
      if(orderType == OP_SELL)
        {
         // Condition 1: SELL and EMADirection == -1 and EMA strong -> standard gap logic
         if(EMADirection == -1 && !isEmaWeak)
           {
            targetSL = NormalizeDouble(curAsk + gap, Digits);
            if((targetSL - curAsk) < minStopDist)
               targetSL = NormalizeDouble(curAsk + minStopDist, Digits);
           }
         else
           {
            // Condition 2: SELL and (EMADirection == 1 or EMA weak) -> live price to avoid extra loss
            targetSL = NormalizeDouble(curAsk + liveBuffer, Digits);
            if(curSL <= 0.0 || targetSL < curSL)
              {
               Print(">>> [TREND-AWARE SL] SELL", (callerName != "" ? " (" + callerName + ")" : ""),
                     ": EMA Dir=", EMADirection, ", Weak=", isEmaWeak,
                     " -> Setting SL to Live Price (Ask + ", DoubleToString(liveBuffer, Digits), ") = ",
                     DoubleToString(targetSL, Digits), " (Standard gap $", DoubleToString(gap, 2), " skipped to prevent loss)");
              }
           }

         // Ensure profit-locking order maintains at least Breakeven / breathing floor
         if(openPrice > 0.0 && targetSL > openPrice && isProfitGapReached)
            targetSL = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice, curAngle);'''
replacements.append(("GetTrendAwareStopLoss", old_tasl, new_tasl))

# 13. SafeOrderModify Body
old_som = '''      double oOpen = OrderOpenPrice();
      double oLots = OrderLots();
      double curNetPL = OrderProfit() + OrderSwap() + OrderCommission();
      bool isSecuringProfit = (orderType == OP_BUY && requestedSL >= oOpen) || (orderType == OP_SELL && requestedSL <= oOpen);
      bool isMethodCaller = (StringFind(callerName, "Method") >= 0 || callerName == "Emergency90PercentSLCutDoubleSL");

      // USER RULE (VMULTI-1095): Double StopLoss gap (e.g. $150 -> $300) when MathAbs(EMAangle) > 3.0 and raw profit gap > $300.0
      double curEmaAng = GlobalEmaAngle30;
      if(curEmaAng == 0.0)
         curEmaAng = GetEmaAngleDegrees(30);

      double rawProfitGap = (orderType == OP_BUY) ? (Bid - oOpen) : (oOpen - Ask);
      bool isProfitGapReached = (rawProfitGap > InpDoubleSlMinProfitGapRaw);
      bool isSteepAngle = (InpEnableDoubleSlGapOnSteepAngle && MathAbs(curEmaAng) > InpDoubleSlGapAngle);

      if(!isMethodCaller && isSecuringProfit && isSteepAngle && isProfitGapReached)
        {
         double liveGap = (orderType == OP_BUY) ? (Bid - requestedSL) : (requestedSL - Ask);
         if(liveGap > 0.0)
           {
            double doubledLiveGap = liveGap * InpDoubleSlGapMultiplier;
            if(doubledLiveGap > liveGap)
              {
               double existingSL = NormalizeDouble(OrderStopLoss(), Digits);
               if(orderType == OP_BUY)
                 {
                  double wideSL = NormalizeDouble(Bid - doubledLiveGap, Digits);
                  if(wideSL < oOpen)
                     wideSL = oOpen; // Maintain at least Breakeven - USER RULE: never modify order with loss amount
                  if(existingSL > 0.0 && wideSL <= existingSL)
                     wideSL = existingSL; // Common Gate Barrier: never downgrade existing SL
                  if(wideSL < requestedSL && (existingSL <= 0.0 || wideSL > existingSL))
                    {
                     Print(">>> [DOUBLE SL GAP IN SAFEMODIFY] BUY #", ticket, " Raw Profit Gap=$", DoubleToString(rawProfitGap, 2),
                           " | Doubled gap from $", DoubleToString(liveGap, 2), " to $", DoubleToString(doubledLiveGap, 2),
                           " | SL adjusted from ", DoubleToString(requestedSL, Digits), " to ", DoubleToString(wideSL, Digits),
                           " (MathAbs(EMAangle)=", DoubleToString(MathAbs(curEmaAng), 2), " > ", DoubleToString(InpDoubleSlGapAngle, 1), " deg)");
                     requestedSL = wideSL;
                    }
                 }
               else
                  if(orderType == OP_SELL)
                    {
                     double wideSL = NormalizeDouble(Ask + doubledLiveGap, Digits);
                     if(wideSL > oOpen)
                        wideSL = oOpen; // Maintain at least Breakeven - USER RULE: never modify order with loss amount
                     if(existingSL > 0.0 && wideSL >= existingSL)
                        wideSL = existingSL; // Common Gate Barrier: never downgrade existing SL
                     if(wideSL > requestedSL && (existingSL <= 0.0 || wideSL < existingSL))
                       {
                        Print(">>> [DOUBLE SL GAP IN SAFEMODIFY] SELL #", ticket, " Raw Profit Gap=$", DoubleToString(rawProfitGap, 2),
                              " | Doubled gap from $", DoubleToString(liveGap, 2), " to $", DoubleToString(doubledLiveGap, 2),
                              " | SL adjusted from ", DoubleToString(requestedSL, Digits), " to ", DoubleToString(wideSL, Digits),
                              " (MathAbs(EMAangle)=", DoubleToString(MathAbs(curEmaAng), 2), " > ", DoubleToString(InpDoubleSlGapAngle, 1), " deg)");
                        requestedSL = wideSL;
                       }
                    }
              }
           }
        }

      // USER RULE (VMULTI-1096): "never modify order with loss amount (Example BUY order not less than openorderprice)"
      if(isSteepAngle && isProfitGapReached)
        {
         if(orderType == OP_BUY && requestedSL < oOpen)
           {
            Print(">>> [LOSS MODIFICATION PREVENTED] BUY #", ticket, " requestedSL=", DoubleToString(requestedSL, Digits),
                  " clamped to openPrice=", DoubleToString(oOpen, Digits), " (Rule: Never modify order with loss amount)");
            requestedSL = oOpen;
           }
         else
            if(orderType == OP_SELL && requestedSL > oOpen)
              {
               Print(">>> [LOSS MODIFICATION PREVENTED] SELL #", ticket, " requestedSL=", DoubleToString(requestedSL, Digits),
                     " clamped to openPrice=", DoubleToString(oOpen, Digits), " (Rule: Never modify order with loss amount)");
               requestedSL = oOpen;
              }
        }

      if(!isMethodCaller && curNetPL > 0.0 && isSecuringProfit && !IsAnyRecoveryOrder(ticket, comment) && !IsFLIPBasketSupportOrder(ticket, comment))
        {
         double propLadderSL = CalculateProportionalLadderSL(orderType, oOpen, oLots);
         double curExistingSL = OrderStopLoss();
         if(propLadderSL > 0.0)
           {
            // If caller proposes an SL tighter than the ladder rung (e.g. Bid - 20),
            // align it with propLadderSL so the trade retains its full 1-gap breathing cushion!
            // Common Gate Barrier: never downgrade below existing StopLoss!
            if(orderType == OP_BUY && requestedSL > propLadderSL && (curExistingSL <= 0.0 || propLadderSL > curExistingSL))
              {
               Print(">>> [COMMON LADDER ENFORCED] BUY #", ticket, " (", DoubleToString(oLots, 2),
                     "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                     " aligned to Proportional Ladder SL=", DoubleToString(propLadderSL, Digits),
                     " (Locks +$", DoubleToString(propLadderSL - oOpen, 2), " pts with breathing cushion)");
               requestedSL = propLadderSL;
              }
            else
               if(orderType == OP_SELL && requestedSL < propLadderSL && (curExistingSL <= 0.0 || propLadderSL < curExistingSL))
                 {
                  Print(">>> [COMMON LADDER ENFORCED] SELL #", ticket, " (", DoubleToString(oLots, 2),
                        "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                        " aligned to Proportional Ladder SL=", DoubleToString(propLadderSL, Digits),
                        " (Locks +$", DoubleToString(oOpen - propLadderSL, 2), " pts with breathing cushion)");
                  requestedSL = propLadderSL;
                 }
           }
         else
           {
            // Order has not reached Level 1 gap yet (favorable move < stepPriceGap)
            // Clamp to Breakeven so liveprice modifications do not prematurely choke the trade before Level 1!
            // Common Gate Barrier: never downgrade below existing StopLoss!
            if(orderType == OP_BUY && requestedSL > oOpen && (curExistingSL <= 0.0 || oOpen > curExistingSL))
              {
               Print(">>> [COMMON LADDER ENFORCED] BUY #", ticket, " (", DoubleToString(oLots, 2),
                     "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                     " clamped to Breakeven=", DoubleToString(oOpen, Digits),
                     " (Price has not reached Level 1 step gap yet)");
               requestedSL = oOpen;
              }
            else
               if(orderType == OP_SELL && requestedSL < oOpen && (curExistingSL <= 0.0 || oOpen < curExistingSL))
                 {
                  Print(">>> [COMMON LADDER ENFORCED] SELL #", ticket, " (", DoubleToString(oLots, 2),
                        "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                        " clamped to Breakeven=", DoubleToString(oOpen, Digits),
                        " (Price has not reached Level 1 step gap yet)");
                  requestedSL = oOpen;
                 }
           }
        }'''

new_som = '''      double oOpen = OrderOpenPrice();
      double oLots = OrderLots();
      double curNetPL = OrderProfit() + OrderSwap() + OrderCommission();
      bool isMethodCaller = (StringFind(callerName, "Method") >= 0 || callerName == "Emergency90PercentSLCutDoubleSL");

      // USER RULE (VMULTI-1095 & VMULTI-1105): EMA angle calculation & Breakeven Breathing Floor
      double curEmaAng = GlobalEmaAngle30;
      if(curEmaAng == 0.0)
         curEmaAng = GetEmaAngleDegrees(30);

      double beFloor = GetEmaAngleBreakevenBreathingSL(orderType, oOpen, oOpen, curEmaAng);
      bool isSecuringProfit = (orderType == OP_BUY && requestedSL >= beFloor) || (orderType == OP_SELL && requestedSL <= beFloor);

      double rawProfitGap = (orderType == OP_BUY) ? (Bid - oOpen) : (oOpen - Ask);
      bool isProfitGapReached = (rawProfitGap > InpDoubleSlMinProfitGapRaw);
      bool isSteepAngle = (InpEnableDoubleSlGapOnSteepAngle && MathAbs(curEmaAng) > InpDoubleSlGapAngle);

      if(!isMethodCaller && isSecuringProfit && isSteepAngle && isProfitGapReached)
        {
         double liveGap = (orderType == OP_BUY) ? (Bid - requestedSL) : (requestedSL - Ask);
         if(liveGap > 0.0)
           {
            double doubledLiveGap = liveGap * InpDoubleSlGapMultiplier;
            if(doubledLiveGap > liveGap)
              {
               double existingSL = NormalizeDouble(OrderStopLoss(), Digits);
               if(orderType == OP_BUY)
                 {
                  double wideSL = NormalizeDouble(Bid - doubledLiveGap, Digits);
                  if(wideSL < beFloor)
                     wideSL = beFloor; // Maintain at least Breakeven / Breathing Floor
                  if(existingSL > 0.0 && wideSL <= existingSL)
                     wideSL = existingSL; // Common Gate Barrier: never downgrade existing SL
                  if(wideSL < requestedSL && (existingSL <= 0.0 || wideSL > existingSL))
                    {
                     Print(">>> [DOUBLE SL GAP IN SAFEMODIFY] BUY #", ticket, " Raw Profit Gap=$", DoubleToString(rawProfitGap, 2),
                           " | Doubled gap from $", DoubleToString(liveGap, 2), " to $", DoubleToString(doubledLiveGap, 2),
                           " | SL adjusted from ", DoubleToString(requestedSL, Digits), " to ", DoubleToString(wideSL, Digits),
                           " (MathAbs(EMAangle)=", DoubleToString(MathAbs(curEmaAng), 2), " > ", DoubleToString(InpDoubleSlGapAngle, 1), " deg)");
                     requestedSL = wideSL;
                    }
                 }
               else
                  if(orderType == OP_SELL)
                    {
                     double wideSL = NormalizeDouble(Ask + doubledLiveGap, Digits);
                     if(wideSL > beFloor)
                        wideSL = beFloor; // Maintain at least Breakeven / Breathing Floor
                     if(existingSL > 0.0 && wideSL >= existingSL)
                        wideSL = existingSL; // Common Gate Barrier: never downgrade existing SL
                     if(wideSL > requestedSL && (existingSL <= 0.0 || wideSL < existingSL))
                       {
                        Print(">>> [DOUBLE SL GAP IN SAFEMODIFY] SELL #", ticket, " Raw Profit Gap=$", DoubleToString(rawProfitGap, 2),
                              " | Doubled gap from $", DoubleToString(liveGap, 2), " to $", DoubleToString(doubledLiveGap, 2),
                              " | SL adjusted from ", DoubleToString(requestedSL, Digits), " to ", DoubleToString(wideSL, Digits),
                              " (MathAbs(EMAangle)=", DoubleToString(MathAbs(curEmaAng), 2), " > ", DoubleToString(InpDoubleSlGapAngle, 1), " deg)");
                        requestedSL = wideSL;
                       }
                    }
              }
           }
        }

      // USER RULE (VMULTI-1096 & VMULTI-1105): Clamped to Breakeven or extra -50 raw gap breathing SL when MathAbs(EMAangle) > 4
      if(isSteepAngle && isProfitGapReached)
        {
         if(orderType == OP_BUY && requestedSL < beFloor)
           {
            Print(">>> [LOSS MODIFICATION PREVENTED] BUY #", ticket, " requestedSL=", DoubleToString(requestedSL, Digits),
                  " clamped to floor=", DoubleToString(beFloor, Digits), " (Rule: Breakeven / Breathing Floor)");
            requestedSL = beFloor;
           }
         else
            if(orderType == OP_SELL && requestedSL > beFloor)
              {
               Print(">>> [LOSS MODIFICATION PREVENTED] SELL #", ticket, " requestedSL=", DoubleToString(requestedSL, Digits),
                     " clamped to floor=", DoubleToString(beFloor, Digits), " (Rule: Breakeven / Breathing Floor)");
               requestedSL = beFloor;
              }
        }

      if(!isMethodCaller && curNetPL > 0.0 && isSecuringProfit && !IsAnyRecoveryOrder(ticket, comment) && !IsFLIPBasketSupportOrder(ticket, comment))
        {
         double propLadderSL = CalculateProportionalLadderSL(orderType, oOpen, oLots);
         double curExistingSL = OrderStopLoss();
         if(propLadderSL > 0.0)
           {
            // If caller proposes an SL tighter than the ladder rung (e.g. Bid - 20),
            // align it with propLadderSL so the trade retains its full 1-gap breathing cushion!
            // Common Gate Barrier: never downgrade below existing StopLoss!
            if(orderType == OP_BUY && requestedSL > propLadderSL && (curExistingSL <= 0.0 || propLadderSL > curExistingSL))
              {
               Print(">>> [COMMON LADDER ENFORCED] BUY #", ticket, " (", DoubleToString(oLots, 2),
                     "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                     " aligned to Proportional Ladder SL=", DoubleToString(propLadderSL, Digits),
                     " (Locks +$", DoubleToString(propLadderSL - oOpen, 2), " pts with breathing cushion)");
               requestedSL = propLadderSL;
              }
            else
               if(orderType == OP_SELL && requestedSL < propLadderSL && (curExistingSL <= 0.0 || propLadderSL < curExistingSL))
                 {
                  Print(">>> [COMMON LADDER ENFORCED] SELL #", ticket, " (", DoubleToString(oLots, 2),
                        "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                        " aligned to Proportional Ladder SL=", DoubleToString(propLadderSL, Digits),
                        " (Locks +$", DoubleToString(oOpen - propLadderSL, 2), " pts with breathing cushion)");
                  requestedSL = propLadderSL;
                 }
           }
         else
           {
            // Order has not reached Level 1 gap yet (favorable move < stepPriceGap)
            // Clamp to Breakeven/Floor so liveprice modifications do not prematurely choke the trade before Level 1!
            // Common Gate Barrier: never downgrade below existing StopLoss!
            if(orderType == OP_BUY && requestedSL > beFloor && (curExistingSL <= 0.0 || beFloor > curExistingSL))
              {
               Print(">>> [COMMON LADDER ENFORCED] BUY #", ticket, " (", DoubleToString(oLots, 2),
                     "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                     " clamped to Breakeven/Floor=", DoubleToString(beFloor, Digits),
                     " (Price has not reached Level 1 step gap yet)");
               requestedSL = beFloor;
              }
            else
               if(orderType == OP_SELL && requestedSL < beFloor && (curExistingSL <= 0.0 || beFloor < curExistingSL))
                 {
                  Print(">>> [COMMON LADDER ENFORCED] SELL #", ticket, " (", DoubleToString(oLots, 2),
                        "L): Proposed SL=", DoubleToString(requestedSL, Digits),
                        " clamped to Breakeven/Floor=", DoubleToString(beFloor, Digits),
                        " (Price has not reached Level 1 step gap yet)");
                  requestedSL = beFloor;
                 }
           }
        }'''
replacements.append(("SafeOrderModify Body", old_som, new_som))

# 14. SafeOrderModify Universal BE Check
old_prep = '''      if(!PrepareStopLossForOrder(orderType, OrderOpenPrice(), requestedSL))
        {
         BlockTradeErrorUntilNextTick(key);
         MarkServerError(130, "OrderModify/unsafe-SL");
         return false;
        }
      if(!CanModifyStopLossForHigherProfit(ticket, requestedSL, (callerName != "" ? callerName : comment)))'''

new_prep = '''      // USER RULE (VMULTI-1105): "when mathabs EMAangle is morethan 4 , then allow order to modify extra -50 raw gap based on order price . add this in common method where new SL price is equal to orderopenprice and mathabs emaangle is more than 4"
      if(NormalizeDouble(requestedSL, Digits) == NormalizeDouble(oOpen, Digits))
        {
         double breathingSL = GetEmaAngleBreakevenBreathingSL(orderType, oOpen, requestedSL, curEmaAng);
         if(NormalizeDouble(breathingSL, Digits) != NormalizeDouble(requestedSL, Digits))
           {
            double curExistingSL = OrderStopLoss();
            // Common Gate Barrier: Only move forward (BUY: higher, SELL: lower) relative to existing SL
            if((orderType == OP_BUY && (curExistingSL <= 0.0 || breathingSL > curExistingSL)) ||
               (orderType == OP_SELL && (curExistingSL <= 0.0 || breathingSL < curExistingSL)))
              {
               Print(">>> [COMMON METHOD: BE SL TO BREATHING SL] Ticket #", ticket, " (", (orderType == OP_BUY ? "BUY" : "SELL"),
                     ") SL adjusted from openPrice ", DoubleToString(requestedSL, Digits),
                     " to Breathing SL ", DoubleToString(breathingSL, Digits),
                     " (extra -50 raw gap based on order price, MathAbs(EMAangle)=", DoubleToString(MathAbs(curEmaAng), 2),
                     " > ", DoubleToString(InpEmaAngleBreakevenBreathingAngle, 1), " deg)");
               requestedSL = breathingSL;
              }
           }
        }

      if(!PrepareStopLossForOrder(orderType, OrderOpenPrice(), requestedSL))
        {
         BlockTradeErrorUntilNextTick(key);
         MarkServerError(130, "OrderModify/unsafe-SL");
         return false;
        }
      if(!CanModifyStopLossForHigherProfit(ticket, requestedSL, (callerName != "" ? callerName : comment)))'''
replacements.append(("SafeOrderModify Universal BE Check", old_prep, new_prep))

# 15. Method 2
old_m2 = '''               // Clamp newSL to openPrice if profit gap reached (USER RULE: never modify with loss amount)
               if(isProfitGapReached && newSL < openPrice)
                  newSL = openPrice;

               bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && newSL >= openPrice);'''

new_m2 = '''               // Clamp newSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
               double beFloorM2 = GetEmaAngleBreakevenBreathingSL(OP_BUY, openPrice, openPrice);
               if(isProfitGapReached && newSL < beFloorM2)
                  newSL = beFloorM2;

               bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && newSL >= beFloorM2);'''
replacements.append(("Method 2", old_m2, new_m2))

# 16. Method 3
old_m3 = '''               // Clamp newSL to openPrice if profit gap reached (USER RULE: never modify with loss amount)
               if(isProfitGapReached && newSL > openPrice)
                  newSL = openPrice;

               bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && newSL <= openPrice);'''

new_m3 = '''               // Clamp newSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
               double beFloorM3 = GetEmaAngleBreakevenBreathingSL(OP_SELL, openPrice, openPrice);
               if(isProfitGapReached && newSL > beFloorM3)
                  newSL = beFloorM3;

               bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && newSL <= beFloorM3);'''
replacements.append(("Method 3", old_m3, new_m3))

# 17. EquityTargetHit
old_eth = '''      if(netPL > 0.0)
        {
         double ladderSL = CalculateProportionalLadderSL(type, openPrice, OrderLots());
         double newSL = 0.0;
         if(ladderSL > 0.0)
            newSL = ladderSL;
         else
            newSL = openPrice; // Level 1 / Breakeven

         if(type == OP_BUY)
           {
            if(newSL >= openPrice && (currentSL == 0.0 || newSL >= currentSL + MinimumSLModifyGapRaw))
               SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrGreen);
           }
         else
            if(type == OP_SELL)
              {
               if(newSL <= openPrice && (currentSL == 0.0 || newSL <= currentSL - MinimumSLModifyGapRaw))
                  SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrRed);
              }
         // Register winning order as secured by Equity Target Hit
         RegisterEquityHitSecuredOrder(ticket);
        }'''

new_eth = '''      if(netPL > 0.0)
        {
         double ladderSL = CalculateProportionalLadderSL(type, openPrice, OrderLots());
         double newSL = 0.0;
         if(ladderSL > 0.0)
            newSL = ladderSL;
         else
            newSL = GetEmaAngleBreakevenBreathingSL(type, openPrice, openPrice); // Level 1 / Breakeven with breathing room

         double beFloorETH = GetEmaAngleBreakevenBreathingSL(type, openPrice, openPrice);
         if(type == OP_BUY)
           {
            if(newSL >= beFloorETH && (currentSL == 0.0 || newSL >= currentSL + MinimumSLModifyGapRaw))
               SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrGreen);
           }
         else
            if(type == OP_SELL)
              {
               if(newSL <= beFloorETH && (currentSL == 0.0 || newSL <= currentSL - MinimumSLModifyGapRaw))
                  SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrRed);
              }
         // Register winning order as secured by Equity Target Hit
         RegisterEquityHitSecuredOrder(ticket);
        }'''
replacements.append(("EquityTargetHit", old_eth, new_eth))

# Verify all before applying
all_matched = True
for name, old_s, new_s in replacements:
    cnt = content.count(old_s)
    if cnt != 1:
        print(f"FAILED count for [{name}]: {cnt}")
        all_matched = False
    else:
        print(f"Verified [{name}]")

if not all_matched:
    print("ABORTING: Not all targets matched uniquely.")
    exit(1)

# Apply all replacements
for name, old_s, new_s in replacements:
    content = content.replace(old_s, new_s)
    print(f"Applied [{name}]")

# Convert back to Windows CRLF
content_crlf = content.replace('\n', '\r\n')

with open(mq4_path, 'wb') as f:
    f.write(content_crlf.encode('utf-8'))

print("\nSuccessfully updated V_EMAMULTIPLE_ORDERS.mq4 to VMULTI-1105!")
