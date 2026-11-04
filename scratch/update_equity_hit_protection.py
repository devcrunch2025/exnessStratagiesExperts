import os

mq4_path = r'c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V_EMAMULTIPLE_ORDERS.mq4'

with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# 1. Update Version
old_v = 'string glbVersion = "VMULTI-1068- Cap 0.01 Loss and Prevent SL Widening Creep";'
new_v = 'string glbVersion = "VMULTI-1069- Protect Equity Hit Orders From Loss SL";'
assert old_v in content, "old_v not found"
content = content.replace(old_v, new_v, 1)

# 2. Add g_equityHitSecuredTickets registry after ResetEmaFlipCutTickets
target_anchor_1 = '''void ResetEmaFlipCutTickets()
  {
   ArrayResize(g_emaFlipCutTickets, 0);
   g_emaFlipHalfDistanceCutGap = 0.0;
   g_emaFlipHalfDistanceReferencePrice = 0.0;
   g_emaFlipHalfDistanceDirection = 0;
  }'''

replacement_1 = '''void ResetEmaFlipCutTickets()
  {
   ArrayResize(g_emaFlipCutTickets, 0);
   g_emaFlipHalfDistanceCutGap = 0.0;
   g_emaFlipHalfDistanceReferencePrice = 0.0;
   g_emaFlipHalfDistanceDirection = 0;
  }

//+------------------------------------------------------------------+
//| Equity Hit Target Secured Orders Tracking                         |
//| USER RULE: "equity hit target is modified 2 orders. next time    |
//|  horizontal line or emaflip changed or soemthing is happend.     |
//|  then, do not modify these orders with high stoploss values.     |
//|  means, profit stoploss valu ok. , loss stoploss is not ok."     |
//+------------------------------------------------------------------+
int  g_equityHitSecuredTickets[];
bool InpProtectEquityHitOrdersFromLossSL = true; // Protect orders secured by equity target hit from receiving loss StopLoss

void RegisterEquityHitSecuredOrder(int ticket)
  {
   int sz = ArraySize(g_equityHitSecuredTickets);
   for(int i = 0; i < sz; i++)
     {
      if(g_equityHitSecuredTickets[i] == ticket)
         return;
     }
   ArrayResize(g_equityHitSecuredTickets, sz + 1);
   g_equityHitSecuredTickets[sz] = ticket;
  }

bool IsEquityHitSecuredOrder(int ticket)
  {
   if(!InpProtectEquityHitOrdersFromLossSL)
      return false;
   int sz = ArraySize(g_equityHitSecuredTickets);
   for(int i = 0; i < sz; i++)
     {
      if(g_equityHitSecuredTickets[i] == ticket)
         return true;
     }
   return false;
  }

void PruneEquityHitSecuredTickets()
  {
   int sz = ArraySize(g_equityHitSecuredTickets);
   if(sz == 0) return;
   int kept = 0;
   for(int i = 0; i < sz; i++)
     {
      int tkt = g_equityHitSecuredTickets[i];
      if(OrderSelect(tkt, SELECT_BY_TICKET, MODE_TRADES))
        {
         if(OrderCloseTime() == 0)
           {
            g_equityHitSecuredTickets[kept] = tkt;
            kept++;
           }
        }
     }
   if(kept < sz)
      ArrayResize(g_equityHitSecuredTickets, kept);
  }

void ResetEquityHitSecuredTickets()
  {
   ArrayResize(g_equityHitSecuredTickets, 0);
  }'''

assert target_anchor_1 in content, "target_anchor_1 not found"
content = content.replace(target_anchor_1, replacement_1, 1)

# 3. Add forward declarations
target_anchor_decl = 'void     ResetEmaFlipCutTickets();'
replacement_decl = '''void     ResetEmaFlipCutTickets();
void     RegisterEquityHitSecuredOrder(int ticket);
bool     IsEquityHitSecuredOrder(int ticket);
void     PruneEquityHitSecuredTickets();
void     ResetEquityHitSecuredTickets();'''
assert target_anchor_decl in content, "target_anchor_decl not found"
content = content.replace(target_anchor_decl, replacement_decl, 1)

# 4. In ModifyOrdersOnEmaFlipWithBreathingSL - BUY orders
target_anchor_ema_buy = '''         int tkt = OrderTicket();
         string comm = OrderComment();
         if(!InpApplyBreathingToHorizontalOrders && IsHorizontalLineOrder(tkt, comm))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] BUY Order #", tkt, " is a horizontal line order. Keeping existing SL logic.");
            continue;
           }'''

replacement_ema_buy = '''         int tkt = OrderTicket();
         string comm = OrderComment();
         if(IsEquityHitSecuredOrder(tkt))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] BUY Order #", tkt,
                  " was secured by Equity Target Hit. Preserving secured StopLoss against wide loss SL!");
            continue;
           }
         if(!InpApplyBreathingToHorizontalOrders && IsHorizontalLineOrder(tkt, comm))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] BUY Order #", tkt, " is a horizontal line order. Keeping existing SL logic.");
            continue;
           }'''
assert target_anchor_ema_buy in content, "target_anchor_ema_buy not found"
content = content.replace(target_anchor_ema_buy, replacement_ema_buy, 1)

# 5. In ModifyOrdersOnEmaFlipWithBreathingSL - SELL orders
target_anchor_ema_sell = '''         int tkt = OrderTicket();
         string comm = OrderComment();
         if(!InpApplyBreathingToHorizontalOrders && IsHorizontalLineOrder(tkt, comm))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] SELL Order #", tkt, " is a horizontal line order. Keeping existing SL logic.");
            continue;
           }'''

replacement_ema_sell = '''         int tkt = OrderTicket();
         string comm = OrderComment();
         if(IsEquityHitSecuredOrder(tkt))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] SELL Order #", tkt,
                  " was secured by Equity Target Hit. Preserving secured StopLoss against wide loss SL!");
            continue;
           }
         if(!InpApplyBreathingToHorizontalOrders && IsHorizontalLineOrder(tkt, comm))
           {
            Print(">>> [EMA FLIP WIDE SL SKIPPED] SELL Order #", tkt, " is a horizontal line order. Keeping existing SL logic.");
            continue;
           }'''
assert target_anchor_ema_sell in content, "target_anchor_ema_sell not found"
content = content.replace(target_anchor_ema_sell, replacement_ema_sell, 1)

# 6. In OnTick - add PruneEquityHitSecuredTickets
target_anchor_ontick = '''   SecureOneDollarProfit();
   CheckEmaFlipHalfDistancePartialLossCut();
   CheckMaxLossCap001Lots();
   CheckEquitySurplusReset();'''

replacement_ontick = '''   SecureOneDollarProfit();
   CheckEmaFlipHalfDistancePartialLossCut();
   CheckMaxLossCap001Lots();
   CheckEquitySurplusReset();
   PruneEquityHitSecuredTickets();'''
assert target_anchor_ontick in content, "target_anchor_ontick not found"
content = content.replace(target_anchor_ontick, replacement_ontick, 1)

# 7. In CanModifyStopLossForHigherProfit - check IsEquityHitSecuredOrder
target_anchor_guard = '''// 1. If order currently has NO Stop Loss, any valid SL is permitted
   if(curSL <= 0.0)
      return true;'''

replacement_guard = '''// USER RULE: Orders secured by Equity Target Hit:
// "profit stoploss value ok. loss stoploss is not ok."
// If an order was secured by Equity Target Hit:
// - Permitted: Stop Loss that locks in PROFIT (normPropSL >= oOpen for BUY, normPropSL <= oOpen for SELL)
// - REJECTED: Stop Loss in LOSS (normPropSL < oOpen for BUY, normPropSL > oOpen for SELL)
   if(IsEquityHitSecuredOrder(ticket) && callerName != "EquityTargetHit_LossTighten")
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
     }

// 1. If order currently has NO Stop Loss, any valid SL is permitted
   if(curSL <= 0.0)
      return true;'''
assert target_anchor_guard in content, "target_anchor_guard not found"
content = content.replace(target_anchor_guard, replacement_guard, 1)

# 8. In SafeOrderModify - add callerName parameter
target_anchor_som = '''bool SafeOrderModify(int ticket,double openPrice,double stopLoss,double takeProfit,datetime expiration,color arrowColor)'''
replacement_som = '''bool SafeOrderModify(int ticket,double openPrice,double stopLoss,double takeProfit,datetime expiration,color arrowColor,string callerName = "")'''
assert target_anchor_som in content, "target_anchor_som not found"
content = content.replace(target_anchor_som, replacement_som, 1)

# And in SafeOrderModify call to CanModifyStopLossForHigherProfit
target_anchor_som_call = '''      if(!CanModifyStopLossForHigherProfit(ticket, requestedSL, comment))
        {
         return false;
        }'''
replacement_som_call = '''      if(!CanModifyStopLossForHigherProfit(ticket, requestedSL, (callerName != "" ? callerName : comment)))
        {
         return false;
        }'''
assert target_anchor_som_call in content, "target_anchor_som_call not found"
content = content.replace(target_anchor_som_call, replacement_som_call, 1)

# 9. In ModifyOpenOrdersToSecureProfit - register tickets and tag loss tightening
target_anchor_reg = '''         if(type == OP_BUY)
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
        }

      // ==============================================================
      // 2. LOSING ORDERS: Tighten SL to $20 from market
      // ==============================================================
      else
         if(netPL < 0.0)
           {
            double newSL = 0.0;
            if(type == OP_BUY)
              {
               newSL = Bid - lossRecoveryGapUSD;
               if(Bid - newSL < minStopDist)
                  newSL = Bid - minStopDist;
              }
            else
               if(type == OP_SELL)
                 {
                  newSL = Ask + lossRecoveryGapUSD;
                  if(newSL - Ask < minStopDist)
                     newSL = Ask + minStopDist;
                 }

            newSL = NormalizeDouble(newSL, Digits);

            // Tighten losing order SL if current SL is wider than $20 (+5 anti-spam margin)
            double distToSL = (type == OP_BUY) ? (Bid - currentSL) : (currentSL - Ask);
            if(currentSL == 0.0 || distToSL > lossRecoveryGapUSD + 5.0)
              {
               SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrOrange);
              }
           }'''

replacement_reg = '''         if(type == OP_BUY)
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
        }

      // ==============================================================
      // 2. LOSING ORDERS: Tighten SL to $20 from market
      // ==============================================================
      else
         if(netPL < 0.0)
           {
            double newSL = 0.0;
            if(type == OP_BUY)
              {
               newSL = Bid - lossRecoveryGapUSD;
               if(Bid - newSL < minStopDist)
                  newSL = Bid - minStopDist;
              }
            else
               if(type == OP_SELL)
                 {
                  newSL = Ask + lossRecoveryGapUSD;
                  if(newSL - Ask < minStopDist)
                     newSL = Ask + minStopDist;
                 }

            newSL = NormalizeDouble(newSL, Digits);

            // Tighten losing order SL if current SL is wider than $20 (+5 anti-spam margin)
            double distToSL = (type == OP_BUY) ? (Bid - currentSL) : (currentSL - Ask);
            if(currentSL == 0.0 || distToSL > lossRecoveryGapUSD + 5.0)
              {
               SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrOrange, "EquityTargetHit_LossTighten");
              }
            // Register losing order as secured/tightened by Equity Target Hit
            RegisterEquityHitSecuredOrder(ticket);
           }'''
assert target_anchor_reg in content, "target_anchor_reg not found"
content = content.replace(target_anchor_reg, replacement_reg, 1)

# 10. In TryModifyOrderStopLossToLinePrice - reject loss SL for equity hit secured orders
target_anchor_line_sl = '''// USER RULE: "this is only for first order ."
   if(InpModifyLinePriceSLOnlyFirstOrder)'''

replacement_line_sl = '''// USER RULE: If order was secured by Equity Target Hit, reject any loss stoploss
   if(IsEquityHitSecuredOrder(ticket))
     {
      double oOpenPrice = OrderOpenPrice();
      double testSL = (oType == OP_BUY) ? NormalizeDouble(linePrice + ((InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0), Digits)
                                        : NormalizeDouble(linePrice + ((InpLinePriceSLOffsetRaw != 0.0) ? InpLinePriceSLOffsetRaw : 50.0), Digits);
      bool isLoss = (oType == OP_BUY && testSL < oOpenPrice) || (oType == OP_SELL && testSL > oOpenPrice);
      if(isLoss)
        {
         Print(">>> [LINE SL MODIFY SKIPPED] Order #", ticket, " was secured by Equity Target Hit.",
               " Proposed Line SL=", DoubleToString(testSL, Digits),
               " is a LOSS Stop Loss (Open=", DoubleToString(oOpenPrice, Digits),
               "). REJECTED: Only profit stoploss is permitted!");
         return false;
        }
     }

// USER RULE: "this is only for first order ."
   if(InpModifyLinePriceSLOnlyFirstOrder)'''
assert target_anchor_line_sl in content, "target_anchor_line_sl not found"
content = content.replace(target_anchor_line_sl, replacement_line_sl, 1)

# 11. In ManageHorizontalOrderEndedStopLoss - reject loss SL
target_anchor_ended = '''      if(!isOrderLineEnded)
         continue;'''

replacement_ended = '''      if(!isOrderLineEnded)
         continue;

      if(IsEquityHitSecuredOrder(tkt))
        {
         double oOpenPrice = OrderOpenPrice();
         double testSL = (oType == OP_BUY) ? NormalizeDouble(Bid - gap, Digits) : NormalizeDouble(Ask + gap, Digits);
         bool isLoss = (oType == OP_BUY && testSL < oOpenPrice) || (oType == OP_SELL && testSL > oOpenPrice);
         if(isLoss)
           {
            Print(">>> [HORIZONTAL LINE ENDED SKIPPED] Order #", tkt, " was secured by Equity Target Hit.",
                  " Proposed Ended SL=", DoubleToString(testSL, Digits),
                  " is a LOSS Stop Loss (Open=", DoubleToString(oOpenPrice, Digits),
                  "). Preserving secured StopLoss!");
            continue;
           }
        }'''
assert target_anchor_ended in content, "target_anchor_ended not found"
content = content.replace(target_anchor_ended, replacement_ended, 1)

# 12. In ManageHorizontalLineEndedBreakoutStopLoss - guard both red and green breakout
target_anchor_breakout_red = '''               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip!
               if(EMADirection == 1 || IsEmaFlipBreathingOrder(OrderTicket()))'''

replacement_breakout_red = '''               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip or Equity Target Hit!
               if(EMADirection == 1 || IsEmaFlipBreathingOrder(OrderTicket()) || IsEquityHitSecuredOrder(OrderTicket()))'''
assert target_anchor_breakout_red in content, "target_anchor_breakout_red not found"
content = content.replace(target_anchor_breakout_red, replacement_breakout_red, 1)

target_anchor_breakout_green = '''               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip!
               if(EMADirection == -1 || IsEmaFlipBreathingOrder(OrderTicket()))'''

replacement_breakout_green = '''               // USER RULE: Do NOT overwrite wide breathing Stop Loss of orders guarded by EMA flip or Equity Target Hit!
               if(EMADirection == -1 || IsEmaFlipBreathingOrder(OrderTicket()) || IsEquityHitSecuredOrder(OrderTicket()))'''
assert target_anchor_breakout_green in content, "target_anchor_breakout_green not found"
content = content.replace(target_anchor_breakout_green, replacement_breakout_green, 1)

with open(mq4_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: V_EMAMULTIPLE_ORDERS.mq4 updated successfully!")
