import os

mq4_path = r'c:\Users\venuadmin\AppData\Roaming\MetaQuotes\Terminal\2191F4A3D14D7B4B1EBB84F924777883\MQL4\Experts\V_EMAMULTIPLE_ORDERS.mq4'

with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    content = f.read()

# 1. Update Version
old_v = 'string glbVersion = "VMULTI-1070- Universal One-Way SL Ratchet for All Orders";'
new_v = 'string glbVersion = "VMULTI-1071- Streamline Methods and Remove Overlapping Conflicts";'
assert old_v in content, "old_v not found"
content = content.replace(old_v, new_v, 1)

# 2. Disable InpEnableEquityProfitLadder5 at top
old_eq5 = 'bool   InpEnableEquityProfitLadder5        = true;   // Enable Equity Profit Ladder $5 * multiplier'
new_eq5 = 'bool   InpEnableEquityProfitLadder5        = false;  // DISABLED: Consolidated into master Manage5PercentLadderReset ($50 step)'
assert old_eq5 in content, "old_eq5 not found"
content = content.replace(old_eq5, new_eq5, 1)

# 3. Disable EnablePairProfitSLModify at top
old_pair_sl = 'bool   EnablePairProfitSLModify             = true;   // Enable multi-order combination SL modification'
new_pair_sl = 'bool   EnablePairProfitSLModify             = false;  // DISABLED: Eliminates 145,000+ redundant combination pair calculations'
assert old_pair_sl in content, "old_pair_sl not found"
content = content.replace(old_pair_sl, new_pair_sl, 1)

# 4. Add control flags for CheckEquityBalanceProfitTarget, CheckDynamicStepLadder, modifyOnlyBuy/SellOrders
old_flags_anchor = '''//Chance 1B: Multi-Order Combination Profit Live SL Modifier (> $1 * multiplier profit)'''
new_flags_anchor = '''// STREAMLINING CONTROL FLAGS:
bool   InpEnableEquityBalanceProfitTarget   = false;  // DISABLED: Prevents premature 25-cent clamp; Manage5PercentLadderReset handles equity targets
bool   InpEnableDynamicStepLadder           = false;  // DISABLED: Consolidated into master Manage5PercentLadderReset
bool   InpEnableModifyOnlyBuySellBasket     = false;  // DISABLED: Prevents premature Bid-20 tightening that overrides SecureOneDollarProfit

//Chance 1B: Multi-Order Combination Profit Live SL Modifier (> $1 * multiplier profit)'''
assert old_flags_anchor in content, "old_flags_anchor not found"
content = content.replace(old_flags_anchor, new_flags_anchor, 1)

# 5. Guard CheckEquityBalanceProfitTarget body
old_eq_target_body = '''void CheckEquityBalanceProfitTarget()
  {
   double accountBalance = AccountBalance();
   double accountEquity  = AccountEquity();
   double targetProfit   = accountBalance + (Ladder1ProfitUSD * 5);'''

new_eq_target_body = '''void CheckEquityBalanceProfitTarget()
  {
   if(!InpEnableEquityBalanceProfitTarget)
      return; // DISABLED: Manage5PercentLadderReset handles equity targets cleanly

   double accountBalance = AccountBalance();
   double accountEquity  = AccountEquity();
   double targetProfit   = accountBalance + (Ladder1ProfitUSD * 5);'''
assert old_eq_target_body in content, "old_eq_target_body not found"
content = content.replace(old_eq_target_body, new_eq_target_body, 1)

# 6. Guard CheckDynamicStepLadder body
old_dynamic_ladder = '''void CheckDynamicStepLadder()
  {
   double currentOpenProfit = 0.0;
   int openOrdersCount = 0;'''

new_dynamic_ladder = '''void CheckDynamicStepLadder()
  {
   if(!InpEnableDynamicStepLadder)
      return; // DISABLED: Consolidated into master Manage5PercentLadderReset

   double currentOpenProfit = 0.0;
   int openOrdersCount = 0;'''
assert old_dynamic_ladder in content, "old_dynamic_ladder not found"
content = content.replace(old_dynamic_ladder, new_dynamic_ladder, 1)

# 7. Guard modifyOnlyBuyOrders & modifyOnlySellOrders
old_mod_buy = '''void modifyOnlyBuyOrders()
  {
   UpdateOrderCacheIfNeeded();
   double basketBuyProfit = g_orderCache.buyPL;'''

new_mod_buy = '''void modifyOnlyBuyOrders()
  {
   if(!InpEnableModifyOnlyBuySellBasket)
      return; // DISABLED: Preserves SecureOneDollarProfit proportional ladder breathing room

   UpdateOrderCacheIfNeeded();
   double basketBuyProfit = g_orderCache.buyPL;'''
assert old_mod_buy in content, "old_mod_buy not found"
content = content.replace(old_mod_buy, new_mod_buy, 1)

old_mod_sell = '''void modifyOnlySellOrders()
  {
   UpdateOrderCacheIfNeeded();
   double basketSellProfit = g_orderCache.sellPL;'''

new_mod_sell = '''void modifyOnlySellOrders()
  {
   if(!InpEnableModifyOnlyBuySellBasket)
      return; // DISABLED: Preserves SecureOneDollarProfit proportional ladder breathing room

   UpdateOrderCacheIfNeeded();
   double basketSellProfit = g_orderCache.sellPL;'''
assert old_mod_sell in content, "old_mod_sell not found"
content = content.replace(old_mod_sell, new_mod_sell, 1)

# 8. Clean up OnTick execution calls
old_ontick_block = '''   if(GetTotalSellOrders()>1)
      modifyOnlySellOrders();
   if(GetTotalBuyOrders()>1)
      modifyOnlyBuyOrders();
   CheckAndCloseOrphanFLIPBasketSupportOrders();

   CheckForNewDay();

   IsDailyEquityStopReached();

   UpdateMomentumBackground();
   UpdateDubaiTradingPauseDashboard();
   uint tickStartMs=GetTickCount();

   CheckEquityBalanceProfitTarget();

   CheckDynamicStepLadder();

   EquityProfitLadder5();
   CloseOppositeOrdersOnEmaDistance();

   UpdateLiquiditySweepDetectorOnChart();
// ManageLsdSweepLineStopLossProtection(); // DISABLED: LSD Sweep lines only create FlipBasketSupport, DO NOT modify/close orders
   CheckNewRedLineCloseBuyAndOpenSell();
   CheckNewGreenLineCloseSellAndOpenBuy(); // USER RULE: On new EQH-G green line: close SELL if loss < $1*mult & open SSL Long 0.02*mult
   if(InpEnableLsdSweepFlipBasketSupport)
      CheckLsdSweepFlipBasketSupportOrder(); // Stage 2: Line Active support order creation (Disabled)
   ManageHorizontalOrderEndedStopLoss(); // USER RULE: When horizontal line ends, modify open horizontal order with $50 gap SL
   ManageHorizontalLineEndedBreakoutStopLoss(); // USER RULE: When horizontal line ends & price breaks past line by $100: modify ALL open orders SL to LinePrice +/- $200

   OnTickCore();
   OnTickPerformanceEnd(tickStartMs);



   ModifyPairProfitWithStopLoss();'''

new_ontick_block = '''   // modifyOnlySellOrders & modifyOnlyBuyOrders DISABLED: Preserves SecureOneDollarProfit proportional ladder breathing room
   if(InpEnableModifyOnlyBuySellBasket)
     {
      if(GetTotalSellOrders()>1)
         modifyOnlySellOrders();
      if(GetTotalBuyOrders()>1)
         modifyOnlyBuyOrders();
     }
   CheckAndCloseOrphanFLIPBasketSupportOrders();

   CheckForNewDay();

   IsDailyEquityStopReached();

   UpdateMomentumBackground();
   UpdateDubaiTradingPauseDashboard();
   uint tickStartMs=GetTickCount();

   // STREAMLINED EXITS: Disabled conflicting secondary ladders to let Manage5PercentLadderReset & SecureOneDollarProfit lead
   // CheckEquityBalanceProfitTarget(); // DISABLED: Prevents premature 25-cent clamp
   // CheckDynamicStepLadder();          // DISABLED: Consolidated into master Manage5PercentLadderReset
   // EquityProfitLadder5();             // DISABLED: Consolidated into master Manage5PercentLadderReset
   // CloseOppositeOrdersOnEmaDistance();// DISABLED: Preserves breathing cushion during EMA trend shifts

   UpdateLiquiditySweepDetectorOnChart();
// ManageLsdSweepLineStopLossProtection(); // DISABLED: LSD Sweep lines only create FlipBasketSupport, DO NOT modify/close orders
   CheckNewRedLineCloseBuyAndOpenSell();
   CheckNewGreenLineCloseSellAndOpenBuy(); // USER RULE: On new EQH-G green line: close SELL if loss < $1*mult & open SSL Long 0.02*mult
   if(InpEnableLsdSweepFlipBasketSupport)
      CheckLsdSweepFlipBasketSupportOrder(); // Stage 2: Line Active support order creation (Disabled)
   ManageHorizontalOrderEndedStopLoss(); // USER RULE: When horizontal line ends, modify open horizontal order with $50 gap SL
   ManageHorizontalLineEndedBreakoutStopLoss(); // USER RULE: When horizontal line ends & price breaks past line by $100: modify ALL open orders SL to LinePrice +/- $200

   OnTickCore();
   OnTickPerformanceEnd(tickStartMs);

   // ModifyPairProfitWithStopLoss(); // DISABLED: Eliminates 145,000+ redundant combination pair calculations'''
assert old_ontick_block in content, "old_ontick_block not found"
content = content.replace(old_ontick_block, new_ontick_block, 1)

with open(mq4_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("SUCCESS: Conflicting methods streamlined and disabled successfully!")
