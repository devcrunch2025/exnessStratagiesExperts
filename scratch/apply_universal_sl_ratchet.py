import os

mq4_path = r'c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V_EMAMULTIPLE_ORDERS.mq4'

with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# 1. Update Version
old_v = 'string glbVersion = "VMULTI-1069- Protect Equity Hit Orders From Loss SL";'
new_v = 'string glbVersion = "VMULTI-1070- Universal One-Way SL Ratchet for All Orders";'
assert old_v in content, "old_v not found"
content = content.replace(old_v, new_v, 1)

# 2. Update InpKeepWideLossCushionSL declaration
old_keep_sl = 'bool   InpKeepWideLossCushionSL            = true;   // If order SL loss is -$10, keep -$10 and do not tighten to -$5 on small EMA changes'
new_keep_sl = 'bool   InpKeepWideLossCushionSL            = false;  // Universal Ratchet Rule: Always allow tightening SL towards profit/breakeven, strictly block widening loss'
assert old_keep_sl in content, "old_keep_sl not found"
content = content.replace(old_keep_sl, new_keep_sl, 1)

# 3. In ModifyOrdersOnEmaFlipWithBreathingSL - Route through SafeOrderModify
old_ema_mod_buy = '''            if(MathAbs(curSL - targetSL) >= Point * 10)
              {
               ResetLastError();
               bool res = OrderModify(tkt, openPrice, targetSL, curTP, 0, clrRed);
               if(res)
                 {
                  RegisterEmaFlipBreathingTicket(tkt);
                  InvalidateTotalEAOrdersCache();
                  Print(">>> [EMA FLIP WIDE SL] Bullish->Bearish Flip (+1 to -1): BUY Order #", tkt,
                        " in Loss ($", DoubleToString(pl, 2), ") modified with Wide Breathing SL=",
                        DoubleToString(targetSL, Digits), " (Buffer=$", DoubleToString(buffer, 2),
                        ", GapFromOpen=$", DoubleToString(openPrice - targetSL, 2),
                        ", Peak=", DoubleToString(peakPrice, Digits),
                        ", HighestEmaDist=$", DoubleToString(highestEmaDist, 2), ")");
                 }
               else
                 {
                  Print(">>> [EMA FLIP WIDE SL FAILED] Ticket #", tkt, " Err=", GetLastError());
                 }
              }'''

new_ema_mod_buy = '''            if(MathAbs(curSL - targetSL) >= Point * 10)
              {
               ResetLastError();
               bool res = SafeOrderModify(tkt, openPrice, targetSL, curTP, 0, clrRed, "EmaFlipBreathing");
               if(res)
                 {
                  RegisterEmaFlipBreathingTicket(tkt);
                  InvalidateTotalEAOrdersCache();
                  Print(">>> [EMA FLIP WIDE SL] Bullish->Bearish Flip (+1 to -1): BUY Order #", tkt,
                        " in Loss ($", DoubleToString(pl, 2), ") modified with Wide Breathing SL=",
                        DoubleToString(targetSL, Digits), " (Buffer=$", DoubleToString(buffer, 2),
                        ", GapFromOpen=$", DoubleToString(openPrice - targetSL, 2),
                        ", Peak=", DoubleToString(peakPrice, Digits),
                        ", HighestEmaDist=$", DoubleToString(highestEmaDist, 2), ")");
                 }
               else
                 {
                  Print(">>> [EMA FLIP WIDE SL SKIPPED/FAILED] Ticket #", tkt, " Err=", GetLastError());
                 }
              }'''
assert old_ema_mod_buy in content, "old_ema_mod_buy not found"
content = content.replace(old_ema_mod_buy, new_ema_mod_buy, 1)

old_ema_mod_sell = '''            if(MathAbs(curSL - targetSL) >= Point * 10)
              {
               ResetLastError();
               bool res = OrderModify(tkt, openPrice, targetSL, curTP, 0, clrBlue);
               if(res)
                 {
                  RegisterEmaFlipBreathingTicket(tkt);
                  InvalidateTotalEAOrdersCache();
                  Print(">>> [EMA FLIP WIDE SL] Bearish->Bullish Flip (-1 to +1): SELL Order #", tkt,
                        " in Loss ($", DoubleToString(pl, 2), ") modified with Wide Breathing SL=",
                        DoubleToString(targetSL, Digits), " (Buffer=$", DoubleToString(buffer, 2),
                        ", GapFromOpen=$", DoubleToString(targetSL - openPrice, 2),
                        ", Lowest=", DoubleToString(lowestPrice, Digits),
                        ", LowestEmaDist=$", DoubleToString(lowestEmaDist, 2), ")");
                 }
               else
                 {
                  Print(">>> [EMA FLIP WIDE SL FAILED] Ticket #", tkt, " Err=", GetLastError());
                 }
              }'''

new_ema_mod_sell = '''            if(MathAbs(curSL - targetSL) >= Point * 10)
              {
               ResetLastError();
               bool res = SafeOrderModify(tkt, openPrice, targetSL, curTP, 0, clrBlue, "EmaFlipBreathing");
               if(res)
                 {
                  RegisterEmaFlipBreathingTicket(tkt);
                  InvalidateTotalEAOrdersCache();
                  Print(">>> [EMA FLIP WIDE SL] Bearish->Bullish Flip (-1 to +1): SELL Order #", tkt,
                        " in Loss ($", DoubleToString(pl, 2), ") modified with Wide Breathing SL=",
                        DoubleToString(targetSL, Digits), " (Buffer=$", DoubleToString(buffer, 2),
                        ", GapFromOpen=$", DoubleToString(targetSL - openPrice, 2),
                        ", Lowest=", DoubleToString(lowestPrice, Digits),
                        ", LowestEmaDist=$", DoubleToString(lowestEmaDist, 2), ")");
                 }
               else
                 {
                  Print(">>> [EMA FLIP WIDE SL SKIPPED/FAILED] Ticket #", tkt, " Err=", GetLastError());
                 }
              }'''
assert old_ema_mod_sell in content, "old_ema_mod_sell not found"
content = content.replace(old_ema_mod_sell, new_ema_mod_sell, 1)

# 4. In CanModifyStopLossForHigherProfit - Universal One-Way SL Ratchet
old_can_mod_func = '''// 2. Evaluate BUY order: Higher profit strictly requires proposedSL > currentSL
   if(oType == OP_BUY)
     {
      if(normPropSL <= curSL)
        {
         double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
         double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);

         Print(">>> [LESS PROFIT BLOCKED] Ticket #", ticket, " (BUY ", DoubleToString(oLots, 2), "L)",
               " | Current Locked SL=", DoubleToString(curSL, Digits), " ($", DoubleToString(curLockedUSD, 2), ")",
               " | Proposed SL=", DoubleToString(normPropSL, Digits), " ($", DoubleToString(propLockedUSD, 2), ")",
               (callerName != "" ? " | Caller=" + callerName : ""),
               " | REJECTED: Keeping higher profit StopLoss!");
         return false;
        }

      // USER RULE: If order SL loss is -$10, next is -$5, keep -$10. Do not tighten to -$5 on small EMA changes!
      if(InpKeepWideLossCushionSL)
        {
         bool isInitialEmergencySL = (MathAbs(oOpen - curSL) >= 1000.0);
         if(!isInitialEmergencySL)
           {
            double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
            double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);
            if(curLockedUSD < 0.0 && propLockedUSD < 0.0 && propLockedUSD > curLockedUSD)
              {
               Print(">>> [WIDE LOSS CUSHION PRESERVED] Ticket #", ticket, " (BUY ", DoubleToString(oLots, 2), "L)",
                     " | Current SL Loss=$", DoubleToString(curLockedUSD, 2), " (SL=", DoubleToString(curSL, Digits), ")",
                     " | Proposed Tighter SL Loss=$", DoubleToString(propLockedUSD, 2), " (SL=", DoubleToString(normPropSL, Digits), ")",
                     (callerName != "" ? " | Caller=" + callerName : ""),
                     " | BLOCKED: Preserving -$10 loss cushion, do NOT tighten to -$5 on small EMA changes!");
               return false;
              }
           }
        }

      // Enforce anti-spam minimum modify gap
      if((normPropSL - curSL) < MinimumSLModifyGapRaw)
         return false;

      return true;
     }

// 3. Evaluate SELL order: Higher profit strictly requires proposedSL < currentSL
   if(oType == OP_SELL)
     {
      if(normPropSL >= curSL)
        {
         double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
         double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);

         Print(">>> [LESS PROFIT BLOCKED] Ticket #", ticket, " (SELL ", DoubleToString(oLots, 2), "L)",
               " | Current Locked SL=", DoubleToString(curSL, Digits), " ($", DoubleToString(curLockedUSD, 2), ")",
               " | Proposed SL=", DoubleToString(normPropSL, Digits), " ($", DoubleToString(propLockedUSD, 2), ")",
               (callerName != "" ? " | Caller=" + callerName : ""),
               " | REJECTED: Keeping higher profit StopLoss!");
         return false;
        }

      // USER RULE: If order SL loss is -$10, next is -$5, keep -$10. Do not tighten to -$5 on small EMA changes!
      if(InpKeepWideLossCushionSL)
        {
         bool isInitialEmergencySL = (MathAbs(oOpen - curSL) >= 1000.0);
         if(!isInitialEmergencySL)
           {
            double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
            double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);
            if(curLockedUSD < 0.0 && propLockedUSD < 0.0 && propLockedUSD > curLockedUSD)
              {
               Print(">>> [WIDE LOSS CUSHION PRESERVED] Ticket #", ticket, " (SELL ", DoubleToString(oLots, 2), "L)",
                     " | Current SL Loss=$", DoubleToString(curLockedUSD, 2), " (SL=", DoubleToString(curSL, Digits), ")",
                     " | Proposed Tighter SL Loss=$", DoubleToString(propLockedUSD, 2), " (SL=", DoubleToString(normPropSL, Digits), ")",
                     (callerName != "" ? " | Caller=" + callerName : ""),
                     " | BLOCKED: Preserving -$10 loss cushion, do NOT tighten to -$5 on small EMA changes!");
               return false;
              }
           }
        }

      // Enforce anti-spam minimum modify gap
      if((curSL - normPropSL) < MinimumSLModifyGapRaw)
         return false;

      return true;
     }'''

new_can_mod_func = '''// =========================================================================
// UNIVERSAL ONE-WAY STOPLOSS RATCHET (STRICT ANTI-LOSS-WIDENING GUARANTEE)
// USER RULE: "apply to all orders. Example, when any order is modified with one
//  stoploss value. example BUY order is modified with stoploss values with -$100
//  or -$50 or something (sl is 71000). next time if any method is trying to
//  modify with more than loss current like SL is below 71000 (do not allow this).
//  allow above 71000. same logic can apply for SELL orders also"
// =========================================================================

// 2. Evaluate BUY order: Must be strictly GREATER than curSL (above current SL)
   if(oType == OP_BUY)
     {
      // STRICT RULE: If proposed SL is below or equal to current SL, DO NOT ALLOW THIS!
      if(normPropSL <= curSL)
        {
         double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
         double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);

         Print(">>> [WIDER LOSS / LESS PROFIT BLOCKED] Ticket #", ticket, " (BUY ", DoubleToString(oLots, 2), "L)",
               " | Current SL=", DoubleToString(curSL, Digits), " ($", DoubleToString(curLockedUSD, 2), ")",
               " | Proposed Worse SL=", DoubleToString(normPropSL, Digits), " ($", DoubleToString(propLockedUSD, 2), ")",
               (callerName != "" ? " | Caller=" + callerName : ""),
               " | REJECTED: Rule: Never modify with more loss than current SL! Only above current SL allowed.");
         return false;
        }

      // Enforce anti-spam minimum modify gap
      if((normPropSL - curSL) < MinimumSLModifyGapRaw)
         return false;

      return true;
     }

// 3. Evaluate SELL order: Must be strictly LESS than curSL (below current SL)
   if(oType == OP_SELL)
     {
      // STRICT RULE: If proposed SL is above or equal to current SL, DO NOT ALLOW THIS!
      if(normPropSL >= curSL)
        {
         double curLockedUSD  = CalcOrderLockedProfitUSD(oType, oOpen, curSL, oLots);
         double propLockedUSD = CalcOrderLockedProfitUSD(oType, oOpen, normPropSL, oLots);

         Print(">>> [WIDER LOSS / LESS PROFIT BLOCKED] Ticket #", ticket, " (SELL ", DoubleToString(oLots, 2), "L)",
               " | Current SL=", DoubleToString(curSL, Digits), " ($", DoubleToString(curLockedUSD, 2), ")",
               " | Proposed Worse SL=", DoubleToString(normPropSL, Digits), " ($", DoubleToString(propLockedUSD, 2), ")",
               (callerName != "" ? " | Caller=" + callerName : ""),
               " | REJECTED: Rule: Never modify with more loss than current SL! Only below current SL allowed.");
         return false;
        }

      // Enforce anti-spam minimum modify gap
      if((curSL - normPropSL) < MinimumSLModifyGapRaw)
         return false;

      return true;
     }'''
assert old_can_mod_func in content, "old_can_mod_func not found"
content = content.replace(old_can_mod_func, new_can_mod_func, 1)

# 5. In ManageLsdSweepLineStopLossProtection - remove raw OrderModify fallbacks that bypass SafeOrderModify
old_lsd_raw_sell = '''                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime);
                  if(!modified)
                    {
                     ResetLastError();
                     modified = OrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime);
                    }'''
new_lsd_raw_sell = '''                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime, "LsdSweepLineSL");'''
assert old_lsd_raw_sell in content, "old_lsd_raw_sell not found"
content = content.replace(old_lsd_raw_sell, new_lsd_raw_sell, 1)

old_lsd_raw_buy = '''                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato);
                  if(!modified)
                    {
                     ResetLastError();
                     modified = OrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato);
                    }'''
new_lsd_raw_buy = '''                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato, "LsdSweepLineSL");'''
assert old_lsd_raw_buy in content, "old_lsd_raw_buy not found"
content = content.replace(old_lsd_raw_buy, new_lsd_raw_buy, 1)

with open(mq4_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: Universal One-Way Stop Loss Ratchet applied successfully to all orders!")
