//+------------------------------------------------------------------+
//|                                       V_Small_OrderClosing.mqh |
//|         V_EMAMULTIPLE_SMALL_LOTS ORDER CLOSING & BASKET PROFIT   |
//+------------------------------------------------------------------+
#property strict


//====================================================================
// R1: Method 6, Combos & 5% Ladder
//====================================================================

//+------------------------------------------------------------------+
//| ModifyPairProfitWithStopLoss                                     |
//| Multi-Order Combination Profit Live SL Modifier:                 |
//| Evaluates 2-order pairs, 3-order triplets, and basket orders     |
//| (profit or loss). If combined profit >= $1.00 * multiplier,      |
//| modifies all qualifying orders with -$100 raw gap StopLoss.      |
//+------------------------------------------------------------------+
void ModifyPairProfitWithStopLoss()
  {
   if(!EnablePairProfitSLModify)
      return;

// 1. Scan and collect all eligible market orders
#define MAX_PAIR_SCAN_ORDERS 100
   int    candTickets[MAX_PAIR_SCAN_ORDERS];
   int    candTypes[MAX_PAIR_SCAN_ORDERS];
   double candLots[MAX_PAIR_SCAN_ORDERS];
   double candOpenPrices[MAX_PAIR_SCAN_ORDERS];
   double candStopLosses[MAX_PAIR_SCAN_ORDERS];
   double candTakeProfits[MAX_PAIR_SCAN_ORDERS];
   double candProfits[MAX_PAIR_SCAN_ORDERS];
   bool   qualifyForSL[MAX_PAIR_SCAN_ORDERS];
   int    candComboSize[MAX_PAIR_SCAN_ORDERS];
   ArrayInitialize(candTickets, 0);
   ArrayInitialize(candTypes, 0);
   ArrayInitialize(candLots, 0.0);
   ArrayInitialize(candOpenPrices, 0.0);
   ArrayInitialize(candStopLosses, 0.0);
   ArrayInitialize(candTakeProfits, 0.0);
   ArrayInitialize(candProfits, 0.0);
   ArrayInitialize(qualifyForSL, false);
   ArrayInitialize(candComboSize, 0);
   int    candCount = 0;

   double mult = (balancelomultipler > 0) ? balancelomultipler : 1.0;
   double targetThreshold = PairCombinationProfitThresholdUSD * (PairCombinationUseBalanceMultiplier ? mult : 1.0);

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
     {
      targetThreshold = targetThreshold / 2.0;
     }

   for(int i = OrdersTotal() - 1; i >= 0 && candCount < MAX_PAIR_SCAN_ORDERS; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      string cmt = OrderComment();
      int tkt    = OrderTicket();

      // Exclude recovery orders: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(tkt, cmt) || IsRecoveryOrderWithActiveParent(tkt, cmt))
         continue;

      // Exclude FLIPBasketSupport orders unless explicitly enabled
      if(!InpPairCombinationIncludeFlipBasket)
        {
         if(IsFLIPBasketSupportOrder(tkt, cmt) || StringFind(cmt, "FLIPBasketSupport") >= 0)
            continue;
        }

      candTickets[candCount]    = tkt;
      candTypes[candCount]      = oType;
      candLots[candCount]       = OrderLots();
      candOpenPrices[candCount] = OrderOpenPrice();
      candStopLosses[candCount] = OrderStopLoss();
      candTakeProfits[candCount]= OrderTakeProfit();
      candProfits[candCount]    = OrderProfit() + OrderSwap() + OrderCommission();
      qualifyForSL[candCount]   = false;
      candCount++;
     }

   if(candCount < 2)
      return; // Need at least 2 orders to form a combination

   int qualifyingCombinationsCount = 0;

// 2A. Total Basket Check (All open orders combined)
   double totalBasketPL = 0.0;
   for(int b = 0; b < candCount; b++)
      totalBasketPL += candProfits[b];

   if(totalBasketPL >= targetThreshold)
     {
      for(int b = 0; b < candCount; b++)
        {
         qualifyForSL[b] = true;
         candComboSize[b] = candCount;
        }
      qualifyingCombinationsCount++;
      Print("COMBINATION BASKET PROFIT >= $", DoubleToString(targetThreshold, 2), " HIT: All ", candCount,
            " orders = Total $", DoubleToString(totalBasketPL, 2),
            " | Qualifying all orders for -$100 StopLoss modification.");
     }

// 2B. Evaluate all 2-order combinations (Pairs: i, j) - profit or loss
   for(int i = 0; i < candCount - 1; i++)
     {
      for(int j = i + 1; j < candCount; j++)
        {
         double pairProfit = candProfits[i] + candProfits[j];
         if(pairProfit >= targetThreshold)
           {
            qualifyForSL[i] = true;
            qualifyForSL[j] = true;
            if(candComboSize[i] == 0)
               candComboSize[i] = 2;
            if(candComboSize[j] == 0)
               candComboSize[j] = 2;
            qualifyingCombinationsCount++;
            Print("COMBINATION PAIR PROFIT >= $", DoubleToString(targetThreshold, 2), " HIT: Pair [Ticket #", candTickets[i],
                  " ($", DoubleToString(candProfits[i], 2), ") + Ticket #", candTickets[j],
                  " ($", DoubleToString(candProfits[j], 2), ")] = Total $", DoubleToString(pairProfit, 2),
                  " | Qualifying both orders for -$100 StopLoss modification.");
           }
        }
     }

// 2C. Evaluate all 3-order combinations (Triplets: i, j, k) - profit or loss
   int maxTripletSearch = MathMin(candCount, 15);
   for(int i = 0; i < maxTripletSearch - 2; i++)
     {
      for(int j = i + 1; j < maxTripletSearch - 1; j++)
        {
         for(int k = j + 1; k < maxTripletSearch; k++)
           {
            double tripletProfit = candProfits[i] + candProfits[j] + candProfits[k];
            if(tripletProfit >= targetThreshold)
              {
               qualifyForSL[i] = true;
               qualifyForSL[j] = true;
               qualifyForSL[k] = true;
               if(candComboSize[i] == 0)
                  candComboSize[i] = 3;
               if(candComboSize[j] == 0)
                  candComboSize[j] = 3;
               if(candComboSize[k] == 0)
                  candComboSize[k] = 3;
               qualifyingCombinationsCount++;
               Print("COMBINATION TRIPLET PROFIT >= $", DoubleToString(targetThreshold, 2), " HIT: Triplet [Ticket #", candTickets[i],
                     " ($", DoubleToString(candProfits[i], 2), "), #", candTickets[j],
                     " ($", DoubleToString(candProfits[j], 2), "), #", candTickets[k],
                     " ($", DoubleToString(candProfits[k], 2), ")] = Total $", DoubleToString(tripletProfit, 2),
                     " | Qualifying 3 orders for -$100 StopLoss modification.");
              }
           }
        }
     }

   if(qualifyingCombinationsCount == 0)
      return;

// 3. Modify qualifying orders with -$100 raw gap StopLoss to protect profit/loss recovery
   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   if(minDistance < 20.0)
      minDistance = 20.0;

   double rawGap = (PairCombinationSLDistanceRaw > 0.0) ? PairCombinationSLDistanceRaw : 100.0;
   if(rawGap < minDistance)
      rawGap = minDistance;

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);

   for(int k = 0; k < candCount; k++)
     {
      if(!qualifyForSL[k])
         continue;

      int    tkt   = candTickets[k];
      int    oType = candTypes[k];
      double oOpen = candOpenPrices[k];
      double curSL = candStopLosses[k];
      double curTP = candTakeProfits[k];

      RefreshRates();
      curBid = MarketInfo(Symbol(), MODE_BID);
      curAsk = MarketInfo(Symbol(), MODE_ASK);

      double curPL = candProfits[k];
      double proposedSL = GetTrendAwareStopLoss(oType, rawGap, curSL, "Method 1", curPL, oOpen);
      bool   shouldModify = false;

      double rawProfitGap = (oType == OP_BUY) ? (curBid - oOpen) : (oOpen - curAsk);
      bool isSteepAngle = (InpEnableDoubleSlGapOnSteepAngle && MathAbs(GlobalEmaAngle30) > InpDoubleSlGapAngle);
      bool isProfitGapReached = (rawProfitGap > InpDoubleSlMinProfitGapRaw);

      // Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
      double beFloorM1 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
      if(isProfitGapReached)
        {
         if(oType == OP_BUY && proposedSL < beFloorM1)
            proposedSL = beFloorM1;
         else
            if(oType == OP_SELL && proposedSL > beFloorM1)
               proposedSL = beFloorM1;
        }

      bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM1 : proposedSL <= beFloorM1));

      if(oType == OP_BUY)
        {
         // Ensure SL is strictly valid below Bid
         if(proposedSL >= curBid)
            continue;

         // For BUY: Set if no SL (0.0), or move SL strictly forward (higher)
         if(curSL == 0.0 || (proposedSL > curSL && (proposedSL - curSL) >= MinimumSLModifyGapRaw))
           {
            shouldModify = true;
           }
        }
      else
         if(oType == OP_SELL)
           {
            // Ensure SL is strictly valid above Ask
            if(proposedSL <= curAsk)
               continue;

            // For SELL: Set if no SL (0.0), or move SL strictly forward (lower)
            if(curSL == 0.0 || (proposedSL < curSL && (curSL - proposedSL) >= MinimumSLModifyGapRaw))
              {
               shouldModify = true;
              }
           }

      if(shouldModify && proposedSL > 0.0)
        {
         ResetLastError();
         bool modified = SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato), "Method 1");
         if(modified)
           {
            RecordMethodModification(tkt, 1, (candComboSize[k] > 0 ? candComboSize[k] : 2), candProfits[k]);
            Print("COMBINATION PROFIT SL MODIFIED | Ticket #", tkt,
                  " | Type=", (oType == OP_BUY ? "BUY" : "SELL"),
                  " | P/L=$", DoubleToString(candProfits[k], 2),
                  " | Old SL=", DoubleToString(curSL, Digits),
                  " | New SL=", DoubleToString(proposedSL, Digits),
                  " (Gap=$", DoubleToString(rawGap, 1), ")");
           }
         else
           {
            Print("COMBINATION PROFIT SL MODIFY FAILED | Ticket #", tkt, " | Error=", GetLastError());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| METHOD 6: Multi-Order Combination (> 2 Orders) Execution         |
//| Checks combinations of >= 2 orders (pairs, triplets, quartets,   |
//| basket) where combined profit >= $20 * multiplier.               |
//| USER ACTION:                                                     |
//| 1) FIRST: Close losing orders in the combination at market       |
//| 2) THEN:  Modify winning orders with StopLoss at Current Price   |
//+------------------------------------------------------------------+
void ExecuteMethod6CombinationAction(int &comboIndices[], int comboCount, double comboSum,
                                     int &candTickets[], int &candTypes[], double &candLots[],
                                     double &candOpenPrices[], double &candTakeProfits[],
                                     double &candProfits[], bool &isProcessed[])
  {
   int m6Tkts[10];
   double m6Pls[10];
   for(int m6i = 0; m6i < comboCount && m6i < 10; m6i++)
     {
      m6Tkts[m6i] = candTickets[comboIndices[m6i]];
      m6Pls[m6i]  = candProfits[comboIndices[m6i]];
     }
   RecordMethodActionCluster(6, m6Tkts, m6Pls, comboCount, comboSum, "1) Close losing orders at market, 2) Modify winning orders with SL at current price");

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double baseThreshold = InpMethod6ProfitThresholdUSD;
   if(baseThreshold <= 0.0)
      baseThreshold = 2.0;
   // Check if all orders in combo are same type (all BUY or all SELL)
   bool isAllSameType = true;
   int firstComboType = candTypes[comboIndices[0]];
   for(int c = 1; c < comboCount; c++)
     {
      if(candTypes[comboIndices[c]] != firstComboType)
        {
         isAllSameType = false;
         break;
        }
     }

   double angleMult    = (absEmaAng > InpMethod6SteepAngleDegrees) ? InpMethod6SteepAngleMultiplier : 1.0;
   double sameTypeMult = isAllSameType ? ((InpMethod6SameTypeMultiplier > 0.0) ? InpMethod6SameTypeMultiplier : 3.0) : 1.0;
   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   bool isEmaAligned   = isAllSameType && ((firstComboType == OP_BUY && EMADirection == 1) || (firstComboType == OP_SELL && EMADirection == -1));
   double emaAlignMult = isEmaAligned ? ((InpMethod6EmaAlignedMultiplier > 0.0) ? InpMethod6EmaAlignedMultiplier : 2.0) : 1.0;
   double activeThresholdUSD = baseThreshold * sameTypeMult * angleMult * emaAlignMult * mult;
   string emaAlignStr = isEmaAligned ? " [EMA ALIGNED 2X]" : "";

   string sameTypeStr = isAllSameType ? (firstComboType == OP_BUY ? " [SAME TYPE ALL-BUY 3X]" : " [SAME TYPE ALL-SELL 3X]") : " [OPPOSITE]";
   string angleStr    = (absEmaAng > InpMethod6SteepAngleDegrees) ? (isAllSameType ? " [DOUBLED >4 deg -> 6X TOTAL]" : " [DOUBLED >4 deg -> 2X]") : "";

   Print(">>> [METHOD 6 TRIGGERED] Combination of ", comboCount, " orders hit Profit = $", DoubleToString(comboSum, 2),
         " >= Threshold $", DoubleToString(activeThresholdUSD, 2),
         sameTypeStr, angleStr, emaAlignStr,
         " (EMA Angle=", DoubleToString(curEmaAng, 1), " deg)",
         ". Executing Action: 1) Close losing orders at market, 2) Modify profit orders with SL at current price.");

// 1. FIRST: Close losing orders at market (Priority 1: Opposite order type, Priority 2: Same order type)
   bool allLosersClosed = true;

// Identify primary winning order type in combo
   int primaryWinType = -1;
   for(int c = 0; c < comboCount; c++)
     {
      int idx = comboIndices[c];
      if(candProfits[idx] >= 0.0)
        {
         primaryWinType = candTypes[idx];
         break;
        }
     }

// Priority 1: Close losing orders with OPPOSITE order type first
   for(int c = 0; c < comboCount; c++)
     {
      int idx = comboIndices[c];
      if(candProfits[idx] < 0.0 && (primaryWinType < 0 || candTypes[idx] != primaryWinType))
        {
         int tkt = candTickets[idx];
         double lossUSD = candProfits[idx];
         Print(">>> [METHOD 6: CLOSING OPPOSITE LOSING ORDER FIRST] Ticket #", tkt,
               " (", (candTypes[idx] == OP_BUY ? "BUY " : "SELL "), DoubleToString(candLots[idx], 2), "L)",
               " | Loss=-$", DoubleToString(MathAbs(lossUSD), 2),
               " closed at market as part of +$", DoubleToString(comboSum, 2), " combination!");

         if(CloseMarketOrderDirect(tkt))
           {
            RecordMethodModification(tkt, 6, comboCount, lossUSD);
            isProcessed[idx] = true;
           }
         else
           {
            Print(">>> [METHOD 6 ERROR] Failed to close opposite losing order Ticket #", tkt, ". Aborting combination to protect winners!");
            allLosersClosed = false;
            break;
           }
        }
     }

// Priority 2: Close losing orders with SAME order type second
   if(allLosersClosed)
     {
      for(int c = 0; c < comboCount; c++)
        {
         int idx = comboIndices[c];
         if(candProfits[idx] < 0.0 && !isProcessed[idx])
           {
            int tkt = candTickets[idx];
            double lossUSD = candProfits[idx];
            Print(">>> [METHOD 6: CLOSING SAME-TYPE LOSING ORDER SECOND] Ticket #", tkt,
                  " (", (candTypes[idx] == OP_BUY ? "BUY " : "SELL "), DoubleToString(candLots[idx], 2), "L)",
                  " | Loss=-$", DoubleToString(MathAbs(lossUSD), 2),
                  " closed at market as part of +$", DoubleToString(comboSum, 2), " combination!");

            if(CloseMarketOrderDirect(tkt))
              {
               RecordMethodModification(tkt, 6, comboCount, lossUSD);
               isProcessed[idx] = true;
              }
            else
              {
               Print(">>> [METHOD 6 ERROR] Failed to close same-type losing order Ticket #", tkt, ". Aborting combination to protect winners!");
               allLosersClosed = false;
               break;
              }
           }
        }
     }

   if(!allLosersClosed)
     {
      Print(">>> [METHOD 6 ABORTED] Not all losing orders were closed. Winning orders kept untouched.");
      return;
     }

// 2. SECOND: Modify winning orders with StopLoss at Current Price
   RefreshRates();
   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < 20.0)
      minStopDist = 20.0;

   int closedWinType  = -1;
   int closedWinCount = 0;

   for(int c = 0; c < comboCount; c++)
     {
      int idx = comboIndices[c];
      if(candProfits[idx] >= 0.0)
        {
         int tkt = candTickets[idx];
         int oType = candTypes[idx];
         double oOpen = candOpenPrices[idx];
         double oTP = candTakeProfits[idx];
         double winUSD = candProfits[idx];

         if(InpMethod6CloseWinnerAtMarket)
           {
            RefreshRates();
            double curClosePrice = (oType == OP_BUY) ? Bid : Ask;
            curClosePrice = NormalizeDouble(curClosePrice, Digits);
            bool winClosed = CloseMarketOrderDirect(tkt);
            if(winClosed)
              {
               RecordMethodModification(tkt, 6, comboCount, winUSD);
               Print(">>> [METHOD 6: FULL COMBO WINNER CLOSED AT MARKET] Ticket #", tkt,
                     " (", (oType == OP_BUY ? "BUY " : "SELL "), DoubleToString(candLots[idx], 2), "L)",
                     " closed at ", DoubleToString(curClosePrice, Digits),
                     " | Realized Profit = +$", DoubleToString(winUSD, 2));
               closedWinType = oType;
               closedWinCount++;
              }
            isProcessed[idx] = true;
            continue;
           }

         RefreshRates();
         curBid = MarketInfo(Symbol(), MODE_BID);
         curAsk = MarketInfo(Symbol(), MODE_ASK);

         // Current Price StopLoss (tightest broker-allowed stop)
         double targetSL = (oType == OP_BUY) ? NormalizeDouble(curBid - minStopDist, Digits)
                           : NormalizeDouble(curAsk + minStopDist, Digits);

         // Ensure profit order maintains at least Breakeven or breathing SL (USER RULE: VMULTI-1105)
         double beFloorM6 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
         if(oType == OP_BUY && targetSL < beFloorM6)
            targetSL = beFloorM6;
         else
            if(oType == OP_SELL && targetSL > beFloorM6)
               targetSL = beFloorM6;

         if(targetSL > 0.0)
           {
            bool modified = SafeOrderModify(tkt, oOpen, targetSL, oTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato), "Method 6");
            if(modified)
              {
               RecordMethodModification(tkt, 6, comboCount, winUSD);
               Print(">>> [METHOD 6: WINNER SL LOCKED AT CURRENT PRICE] Ticket #", tkt,
                     " (", (oType == OP_BUY ? "BUY " : "SELL "), DoubleToString(candLots[idx], 2), "L)",
                     " | Profit=+$", DoubleToString(winUSD, 2),
                     " | Locked SL=", DoubleToString(targetSL, Digits),
                     " (Current Price - ", DoubleToString(minStopDist, Digits), ")");
              }
           }
         isProcessed[idx] = true;
        }
     }

// After all combo winners are closed at market, create the new pending order with regular SSL gap
   if(InpMethod6CloseWinnerAtMarket && InpMethod6CreatePendingOnWinnerClose && closedWinCount > 0 && closedWinType >= 0)
     {
      CreateMethod6PendingOrderAfterClose(closedWinType);
     }

// Draw chart icon
   double iconPrice = (candTypes[comboIndices[0]] == OP_BUY ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK));
   DrawMethod6HitIcon(comboCount, comboSum, TimeCurrent(), iconPrice);
   g_lastMethod6ActionTick = CurrentTickSequence;
   InvalidateTotalEAOrdersCache();
  }

//+------------------------------------------------------------------+
//| METHOD 6: Create Pending Re-entry Order After Closing Winner     |
//| Places new pending order (BUY STOP "SSL Long" / SELL STOP        |
//| "SSL Short"). Parameter requireZeroOpen controls whether all     |
//| open orders in that direction must be 0 (default true).          |
//+------------------------------------------------------------------+
void CreateMethod6PendingOrderAfterClose(int winType, bool requireZeroOpen = true)
  {
   if(winType != OP_BUY && winType != OP_SELL)
      return;

// USER RULE: Condition: only when openordercount is 0 in same direction (when requireZeroOpen is true)
   int openCountSameDir = 0;
   int pendingCountSameDir = 0;
   int expectedPendingType = (winType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == winType)
         openCountSameDir++;
      else
         if(OrderType() == expectedPendingType)
            pendingCountSameDir++;
     }

   if(requireZeroOpen && openCountSameDir > 0)
     {
      Print(">>> [METHOD 6 PENDING SKIPPED] Open order count in ", (winType == OP_BUY ? "BUY" : "SELL"),
            " direction is ", openCountSameDir, " (> 0). Pending re-entry not created.");
      return;
     }

   if(pendingCountSameDir > 0)
     {
      // If a pending order already exists in same direction, delete it to ensure the fresh pending order #3 has regular SSL gap!
      for(int p_i = OrdersTotal() - 1; p_i >= 0; p_i--)
        {
         if(!OrderSelect(p_i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(OrderType() == expectedPendingType)
           {
            SafeOrderDelete(OrderTicket(), clrGray);
           }
        }
     }

   RefreshRates();
   double pendingGap = GetSSLLongShortPendingGapRaw(winType, true);
   double minStopDist = GetRequiredStopDistance();
   double entryPrice = 0.0;
   double stopLoss = 0.0;
   double takeProfit = 0.0;
   string orderComment = "";
   color orderColor = clrNONE;

   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;

   if(winType == OP_BUY)
     {
      entryPrice = Ask + pendingGap;
      if(entryPrice < Ask + minStopDist)
         entryPrice = Ask + minStopDist;
      entryPrice = NormalizeDouble(entryPrice, Digits);

      stopLoss = (slDistance > 0.0) ? NormalizeDouble(entryPrice - slDistance, Digits) : 0.0;
      takeProfit = (tpDistance > 0.0) ? NormalizeDouble(entryPrice + tpDistance, Digits) : 0.0;

      ChangeLots(GlobalSellPL, "SSL Long", OP_BUY, 0, "");
      Lots = NormalizeLots(Lots);
      orderComment = "SSL Long";
      orderColor = BuyColor;
     }
   else // OP_SELL
     {
      entryPrice = Bid - pendingGap;
      if(entryPrice > Bid - minStopDist)
         entryPrice = Bid - minStopDist;
      entryPrice = NormalizeDouble(entryPrice, Digits);

      stopLoss = (slDistance > 0.0) ? NormalizeDouble(entryPrice + slDistance, Digits) : 0.0;
      takeProfit = (tpDistance > 0.0) ? NormalizeDouble(entryPrice - tpDistance, Digits) : 0.0;

      ChangeLots(GlobalBuyPL, "SSL Short", OP_SELL, 0, "");
      Lots = NormalizeLots(Lots);
      orderComment = "SSL Short";
      orderColor = SellColor;
     }

   if(DeleteOppositePendingOnSignal)
      DeleteOppositePendingOrders(winType);

   int ticket = SafeOrderSend(Symbol(), expectedPendingType, Lots, entryPrice, Slippage, stopLoss, takeProfit, orderComment, MagicNumber, orderColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
      Print(">>> [METHOD 6 PENDING CREATED] ", orderComment, " Ticket #", ticket,
            " Lots=", DoubleToString(Lots, 2),
            " Entry=", DoubleToString(entryPrice, Digits),
            " SL=", DoubleToString(stopLoss, Digits),
            " TP=", DoubleToString(takeProfit, Digits),
            " (requireZeroOpen=", (requireZeroOpen ? "true" : "false"), ", Open count=", openCountSameDir, ")");
      InvalidateTotalEAOrdersCache();
     }
   else
     {
      Print(">>> [METHOD 6 PENDING FAILED] SafeOrderSend failed for ", orderComment, " Error=", GetLastError());
     }
  }

//+------------------------------------------------------------------+
//| METHOD 6: Partial Combo Winner Lot Helper                        |
//| USER RULE (VMULTI-1238):                                         |
//| - If winner lot == 0.01 (minLot) -> full close (0.01L)           |
//| - If winner lot >  0.01          -> half close (aligned to step) |
//+------------------------------------------------------------------+
double GetMethod6PartialWinnerCloseLots(double winLots)
  {
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   if(minLot <= 0.0)
      minLot = 0.01;
   if(lotStep <= 0.0)
      lotStep = 0.01;

   double normWinLots = NormalizeDouble(winLots, 2);
   if(!InpMethod6PartialHalfCloseWinner || normWinLots <= minLot + 0.00001)
      return normWinLots; // 0.01L -> full close

// > 0.01L -> close half lot aligned to broker lotStep
   double halfLots = MathFloor(((normWinLots * 0.5) + 0.00001) / lotStep) * lotStep;
   halfLots = NormalizeDouble(halfLots, 2);
   if(halfLots < minLot)
      halfLots = minLot;

// Ensure remaining lot stays >= minLot for valid MT4 partial close
   if(normWinLots - halfLots < minLot - 0.00001)
      return normWinLots;

   return halfLots;
  }

//+------------------------------------------------------------------+
//| METHOD 6: Partial LOT Combination Action                         |
//| Closes partial lot from losing order and either closes winner    |
//| (full if 0.01L, half if >0.01L) at market or tightens SL.        |
//+------------------------------------------------------------------+
void ExecuteMethod6PartialLotAction(int winIdx, int lossIdx, double partialLots, double partialLossUSD, double netProfitUSD,
                                    int &candTickets[], int &candTypes[], double &candLots[],
                                    double &candOpenPrices[], double &candTakeProfits[],
                                    double &candProfits[], bool &isProcessed[])
  {
   int winTkt         = candTickets[winIdx];
   int winType        = candTypes[winIdx];
   double winLots     = candLots[winIdx];
   double winOpen     = candOpenPrices[winIdx];
   double winTP       = candTakeProfits[winIdx];
   double winPL       = candProfits[winIdx];

   int lossTkt        = candTickets[lossIdx];
   int lossType       = candTypes[lossIdx];
   double lossLots    = candLots[lossIdx];
   double lossPL      = candProfits[lossIdx];

   double winCloseLots    = InpMethod6PartialCloseWinnerAtMarket ? GetMethod6PartialWinnerCloseLots(winLots) : winLots;
   bool   isFullWinClose  = (winCloseLots >= winLots - 0.00001);
   double winCloseRatio   = (winLots > 0.0) ? (winCloseLots / winLots) : 1.0;
   double winRealizedPL   = NormalizeDouble(winPL * winCloseRatio, 2);
   double winRemainLots   = NormalizeDouble(MathMax(0.0, winLots - winCloseLots), 2);

   int m6Tkts[10];
   double m6Pls[10];
   ArrayInitialize(m6Tkts, 0);
   ArrayInitialize(m6Pls, 0.0);
   m6Tkts[0] = winTkt;
   m6Pls[0]  = winRealizedPL;
   m6Tkts[1] = lossTkt;
   m6Pls[1]  = partialLossUSD;

   string actionDesc = "";
   if(InpMethod6PartialCloseWinnerAtMarket)
      actionDesc = isFullWinClose ?
                   "1) Close partial losing lot at market, 2) Full close 0.01L winning order at market" :
                   "1) Close partial losing lot at market, 2) Half close winning order at market (remaining stays open)";
   else
      actionDesc = "1) Close partial losing lot at market, 2) Modify winning order SL at live price";

   RecordMethodActionCluster(6, m6Tkts, m6Pls, 2, netProfitUSD, actionDesc);

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double baseThreshold = InpMethod6ProfitThresholdUSD;
   if(baseThreshold <= 0.0)
      baseThreshold = 2.0;
   bool isSameTypePartial = (winType == lossType);
   double angleMult    = (absEmaAng > InpMethod6SteepAngleDegrees) ? InpMethod6SteepAngleMultiplier : 1.0;
   double sameTypeMult = isSameTypePartial ? ((InpMethod6SameTypeMultiplier > 0.0) ? InpMethod6SameTypeMultiplier : 3.0) : 1.0;
   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   bool isEmaAligned   = isSameTypePartial && ((winType == OP_BUY && EMADirection == 1) || (winType == OP_SELL && EMADirection == -1));
   double emaAlignMult = isEmaAligned ? ((InpMethod6EmaAlignedMultiplier > 0.0) ? InpMethod6EmaAlignedMultiplier : 2.0) : 1.0;
   double activeThresholdUSD = baseThreshold * sameTypeMult * angleMult * emaAlignMult * mult;
   string emaAlignStr = isEmaAligned ? " [EMA ALIGNED 2X]" : "";

   string sameTypeStr = isSameTypePartial ? (winType == OP_BUY ? " [SAME TYPE BUY 3X]" : " [SAME TYPE SELL 3X]") : " [OPPOSITE]";
   string angleStr    = (absEmaAng > InpMethod6SteepAngleDegrees) ? (isSameTypePartial ? " [DOUBLED >4 deg -> 6X TOTAL]" : " [DOUBLED >4 deg -> 2X]") : "";

   Print(">>> [METHOD 6 PARTIAL LOT TRIGGERED] Winner Ticket #", winTkt,
         " (", (winType == OP_BUY ? "BUY " : "SELL "), DoubleToString(winLots, 2), "L, Total P/L=+$", DoubleToString(winPL, 2),
         " -> ", (isFullWinClose ? "Full Close " : "Half Close "), DoubleToString(winCloseLots, 2), "L, Realized=+$", DoubleToString(winRealizedPL, 2), ")",
         " paired with Loser Ticket #", lossTkt,
         " (", (lossType == OP_BUY ? "BUY " : "SELL "), DoubleToString(lossLots, 2), "L, Total Loss=-$", DoubleToString(MathAbs(lossPL), 2), ")",
         " | Partial Cut = ", DoubleToString(partialLots, 2), "L (Loss=-$", DoubleToString(MathAbs(partialLossUSD), 2), ")",
         " | Net Combo Profit = +$", DoubleToString(netProfitUSD, 2),
         " >= Threshold $", DoubleToString(activeThresholdUSD, 2),
         sameTypeStr, angleStr, emaAlignStr,
         " (EMA Angle=", DoubleToString(curEmaAng, 1), " deg)");

// 1. FIRST: Close partial lot of losing order at market
   bool lossClosed = false;
   double lossClosePrice = 0.0;
   for(int attempt = 0; attempt < 3; attempt++)
     {
      RefreshRates();
      lossClosePrice = (lossType == OP_BUY) ? Bid : Ask;
      lossClosePrice = NormalizeDouble(lossClosePrice, Digits);
      ResetLastError();
      lossClosed = OrderClose(lossTkt, partialLots, lossClosePrice, Slippage, (lossType == OP_BUY ? clrRed : clrBlue));
      if(lossClosed)
         break;
      int err = GetLastError();
      Print("Method 6 Partial Close attempt ", (attempt + 1), " failed for Ticket #", lossTkt, " | Error=", err);
      LogEAError(err, "OrderClose(Method6-Loss)", lossTkt, StringFormat("Attempt=%d Lots=%.2f Px=%s", (attempt + 1), partialLots, DoubleToString(lossClosePrice, Digits)));
      Sleep(100);
     }

   if(!lossClosed)
     {
      Print(">>> [METHOD 6 PARTIAL LOT ABORTED] Failed to close partial lot for Ticket #", lossTkt, ". Winner #", winTkt, " kept untouched.");
      return;
     }

   RecordMethodModification(lossTkt, 6, 2, partialLossUSD);
   Print(">>> [METHOD 6: PARTIAL LOSS CUT EXECUTED] Ticket #", lossTkt,
         " closed ", DoubleToString(partialLots, 2), "L of ", DoubleToString(lossLots, 2), "L at ",
         DoubleToString(lossClosePrice, Digits), " | Realized Loss = -$", DoubleToString(MathAbs(partialLossUSD), 2));

// 2. SECOND: Handle winning order (if 0.01L -> full close; if >0.01L -> half close)
   if(InpMethod6PartialCloseWinnerAtMarket)
     {
      bool winClosed = false;
      double winClosePrice = 0.0;
      for(int attempt = 0; attempt < 3; attempt++)
        {
         RefreshRates();
         winClosePrice = (winType == OP_BUY) ? Bid : Ask;
         winClosePrice = NormalizeDouble(winClosePrice, Digits);
         ResetLastError();
         winClosed = OrderClose(winTkt, winCloseLots, winClosePrice, Slippage, (winType == OP_BUY ? clrLimeGreen : clrTomato));
         if(winClosed)
            break;
         int err = GetLastError();
         Print("Method 6 Winner ", (isFullWinClose ? "Full" : "Half"), " Close attempt ", (attempt + 1), " failed for Ticket #", winTkt, " | Error=", err);
         LogEAError(err, "OrderClose(Method6-Win)", winTkt, StringFormat("Attempt=%d Lots=%.2f Px=%s", (attempt + 1), winCloseLots, DoubleToString(winClosePrice, Digits)));
         Sleep(100);
        }

      if(winClosed)
        {
         RecordMethodModification(winTkt, 6, 2, winRealizedPL);
         if(isFullWinClose)
           {
            Print(">>> [METHOD 6: WINNER FULL CLOSED AT MARKET] Ticket #", winTkt,
                  " (", (winType == OP_BUY ? "BUY " : "SELL "), DoubleToString(winCloseLots, 2), "L)",
                  " closed at ", DoubleToString(winClosePrice, Digits),
                  " | Realized Profit = +$", DoubleToString(winRealizedPL, 2),
                  " | Net Combo Realized = +$", DoubleToString(netProfitUSD, 2));

            if(InpMethod6CreatePendingOnWinnerClose)
              {
               CreateMethod6PendingOrderAfterClose(winType);
              }
           }
         else
           {
            Print(">>> [METHOD 6: WINNER HALF CLOSED AT MARKET] Ticket #", winTkt,
                  " (", (winType == OP_BUY ? "BUY " : "SELL "), DoubleToString(winCloseLots, 2), "L of ", DoubleToString(winLots, 2), "L closed; ",
                  DoubleToString(winRemainLots, 2), "L remains open)",
                  " at ", DoubleToString(winClosePrice, Digits),
                  " | Realized Profit = +$", DoubleToString(winRealizedPL, 2),
                  " | Net Combo Realized = +$", DoubleToString(netProfitUSD, 2));
           }
        }
      else
        {
         RefreshRates();
         double curBid = MarketInfo(Symbol(), MODE_BID);
         double curAsk = MarketInfo(Symbol(), MODE_ASK);
         double minStopDist = GetRequiredStopDistance();
         if(minStopDist < 20.0)
            minStopDist = 20.0;
         double targetSL = (winType == OP_BUY) ? NormalizeDouble(curBid - minStopDist, Digits)
                           : NormalizeDouble(curAsk + minStopDist, Digits);
         SafeOrderModify(winTkt, winOpen, targetSL, winTP, 0, (winType == OP_BUY ? clrLimeGreen : clrTomato), "Method 6 Fallback");
        }
     }
   else
     {
      // Tighten StopLoss to Live Price (Classic Method 6 runner behavior)
      RefreshRates();
      double curBid = MarketInfo(Symbol(), MODE_BID);
      double curAsk = MarketInfo(Symbol(), MODE_ASK);
      double minStopDist = GetRequiredStopDistance();
      if(minStopDist < 20.0)
         minStopDist = 20.0;
      double targetSL = (winType == OP_BUY) ? NormalizeDouble(curBid - minStopDist, Digits)
                        : NormalizeDouble(curAsk + minStopDist, Digits);

      double beFloorM6 = GetEmaAngleBreakevenBreathingSL(winType, winOpen, winOpen);
      if(winType == OP_BUY && targetSL < beFloorM6)
         targetSL = beFloorM6;
      else
         if(winType == OP_SELL && targetSL > beFloorM6)
            targetSL = beFloorM6;

      if(targetSL > 0.0)
        {
         bool modified = SafeOrderModify(winTkt, winOpen, targetSL, winTP, 0, (winType == OP_BUY ? clrLimeGreen : clrTomato), "Method 6");
         if(modified)
           {
            RecordMethodModification(winTkt, 6, 2, winPL);
            Print(">>> [METHOD 6: WINNER SL LOCKED AT CURRENT PRICE] Ticket #", winTkt,
                  " (", (winType == OP_BUY ? "BUY " : "SELL "), DoubleToString(winLots, 2), "L)",
                  " | Profit=+$", DoubleToString(winPL, 2),
                  " | Locked SL=", DoubleToString(targetSL, Digits));
           }
        }
     }

   isProcessed[winIdx]  = true;
   isProcessed[lossIdx] = true;

   double iconPrice = (winType == OP_BUY ? MarketInfo(Symbol(), MODE_BID) : MarketInfo(Symbol(), MODE_ASK));
   DrawMethod6HitIcon(2, netProfitUSD, TimeCurrent(), iconPrice);
   g_lastMethod6ActionTick = CurrentTickSequence;
   InvalidateTotalEAOrdersCache();
  }

//+------------------------------------------------------------------+
//| METHOD 6: Partial Lot Slice Search Helper                        |
//| targetOpposite = true  -> search strictly for OPPOSITE losers    |
//| targetOpposite = false -> search strictly for SAME-TYPE losers   |
//+------------------------------------------------------------------+
void ExecuteMethod6PartialLotSearch(bool targetOpposite, double threshold, int candCount,
                                    int &candTickets[], int &candTypes[], double &candLots[],
                                    double &candOpenPrices[], double &candTakeProfits[],
                                    double &candProfits[], bool &isProcessed[])
  {
   if(!InpMethod6EnablePartialLotCombination)
      return;

   int searchLimitP = MathMin(candCount, 30);
   for(int i = 0; i < searchLimitP; i++)
     {
      if(isProcessed[i])
         continue;

      double winTotalLots = candLots[i];
      double winCloseLots = InpMethod6PartialCloseWinnerAtMarket ? GetMethod6PartialWinnerCloseLots(winTotalLots) : winTotalLots;
      double winCloseRatio = (winTotalLots > 0.0) ? (winCloseLots / winTotalLots) : 1.0;
      double winPL = NormalizeDouble(candProfits[i] * winCloseRatio, 2);

      double effThreshold = threshold;
      if(!targetOpposite)
        {
         bool isAligned = ((candTypes[i] == OP_BUY && EMADirection == 1) || (candTypes[i] == OP_SELL && EMADirection == -1));
         double emaAlignMult = (InpMethod6EmaAlignedMultiplier > 0.0) ? InpMethod6EmaAlignedMultiplier : 2.0;
         if(isAligned)
            effThreshold = threshold * emaAlignMult;
        }

      if(winPL < effThreshold)
         continue; // Realized profit of closed winner lot (half if >0.01L, full if 0.01L) must reach base threshold

      int bestLossIdx = -1;
      double bestCutLots = 0.0;
      double bestPartialLoss = 0.0;
      double bestNetProfit = 0.0;

      for(int j = 0; j < searchLimitP; j++)
        {
         if(i == j || isProcessed[j])
            continue;
         if(candProfits[j] >= 0.0)
            continue; // Target must be losing order

         // Filter by opposite vs same order type
         bool isOpp = (candTypes[j] != candTypes[i]);
         if(targetOpposite && !isOpp)
            continue; // Looking strictly for OPPOSITE losers
         if(!targetOpposite && isOpp)
            continue; // Looking strictly for SAME-TYPE losers

         double lossTotalLots = candLots[j];
         if(lossTotalLots <= 0.01)
            continue; // Cannot partially close 0.01 lots in MT4

         double lossPL = candProfits[j];
         double absLoss = MathAbs(lossPL);
         if(absLoss <= 0.0001)
            continue;

         double lossPerLot = absLoss / lossTotalLots;
         if(lossPerLot <= 0.0)
            continue;

         double maxAbsorbableLoss = winPL - effThreshold;
         if(maxAbsorbableLoss <= 0.0)
            continue;

         double maxLotsToCut = maxAbsorbableLoss / lossPerLot;
         double pLots = MathFloor((maxLotsToCut + 0.00001) / 0.01) * 0.01;
         pLots = NormalizeDouble(pLots, 2);

         // Ensure remaining lot is at least 0.01 (partial cut only)
         double maxAllowedCut = NormalizeDouble(lossTotalLots - 0.01, 2);
         if(pLots > maxAllowedCut)
            pLots = maxAllowedCut;

         // Apply user cap if specified
         if(InpMethod6PartialMaxCutLots > 0.0 && pLots > InpMethod6PartialMaxCutLots)
            pLots = NormalizeDouble(InpMethod6PartialMaxCutLots, 2);

         if(pLots < 0.01)
            continue;

         double pLossUSD = -1.0 * NormalizeDouble(lossPerLot * pLots, 2);
         double nProfitUSD = NormalizeDouble(winPL + pLossUSD, 2);

         if(nProfitUSD >= effThreshold)
           {
            if(pLots > bestCutLots || (pLots == bestCutLots && MathAbs(pLossUSD) > MathAbs(bestPartialLoss)))
              {
               bestCutLots     = pLots;
               bestLossIdx     = j;
               bestPartialLoss = pLossUSD;
               bestNetProfit   = nProfitUSD;
              }
           }
        }

      if(bestLossIdx >= 0 && bestCutLots >= 0.01)
        {
         ExecuteMethod6PartialLotAction(i, bestLossIdx, bestCutLots, bestPartialLoss, bestNetProfit,
                                        candTickets, candTypes, candLots, candOpenPrices,
                                        candTakeProfits, candProfits, isProcessed);
        }
     }
  }

#ifndef MAX_M6_ORDERS
#define MAX_M6_ORDERS 100
#endif

//+------------------------------------------------------------------+
//| Method 6 Modified StopLoss Tracking Registry                     |
//| Tracks orders modified with Method 6 StopLoss to detect when     |
//| they hit StopLoss. If MathAbs(EMA Angle) > 4.0 deg upon SL hit,  |
//| a pending order is created in that same profit direction.        |
//+------------------------------------------------------------------+
#define MAX_M6_TRACKED_SL_ORDERS 50
struct M6TrackedSLOrder
  {
   int      ticket;
   int      orderType;
   double   targetSL;
   datetime modifyTime;
   bool     isActive;
  };
M6TrackedSLOrder g_m6TrackedSLOrders[MAX_M6_TRACKED_SL_ORDERS];
int g_m6TrackedSLOrderCount = 0;

void RegisterMethod6ModifiedSLOrder(int ticket, int orderType, double targetSL)
  {
   if(ticket <= 0)
      return;

   for(int i = 0; i < g_m6TrackedSLOrderCount; i++)
     {
      if(g_m6TrackedSLOrders[i].ticket == ticket)
        {
         g_m6TrackedSLOrders[i].targetSL   = targetSL;
         g_m6TrackedSLOrders[i].modifyTime = TimeCurrent();
         g_m6TrackedSLOrders[i].isActive   = true;
         return;
        }
     }

   int slot = -1;
   for(int i = 0; i < g_m6TrackedSLOrderCount; i++)
     {
      if(!g_m6TrackedSLOrders[i].isActive)
        {
         slot = i;
         break;
        }
     }

   if(slot < 0)
     {
      if(g_m6TrackedSLOrderCount < MAX_M6_TRACKED_SL_ORDERS)
        {
         slot = g_m6TrackedSLOrderCount;
         g_m6TrackedSLOrderCount++;
        }
      else
        {
         slot = 0;
        }
     }

   g_m6TrackedSLOrders[slot].ticket     = ticket;
   g_m6TrackedSLOrders[slot].orderType  = orderType;
   g_m6TrackedSLOrders[slot].targetSL   = targetSL;
   g_m6TrackedSLOrders[slot].modifyTime = TimeCurrent();
   g_m6TrackedSLOrders[slot].isActive   = true;

   PrintFormat(">>> [METHOD 6 TRACK SL] Registered Ticket #%d (%s) | Target SL=%s for SL-Hit Pending Re-entry tracking",
               ticket, (orderType == OP_BUY ? "BUY" : "SELL"), DoubleToString(targetSL, Digits));
  }

void CheckMethod6SLHitPendingReEntry()
  {
   if(!InpMethod6CreatePendingOnSLHit)
      return;

   if(g_m6TrackedSLOrderCount == 0)
      return;

   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);

   for(int i = 0; i < g_m6TrackedSLOrderCount; i++)
     {
      if(!g_m6TrackedSLOrders[i].isActive)
         continue;

      int tkt = g_m6TrackedSLOrders[i].ticket;
      int oType = g_m6TrackedSLOrders[i].orderType;

      // Check if ticket is still open in MODE_TRADES
      if(OrderSelect(tkt, SELECT_BY_TICKET, MODE_TRADES))
        {
         if(OrderCloseTime() == 0)
            continue; // Order is still active
        }

      // Order is no longer open in MODE_TRADES. Check history to see how it closed.
      if(OrderSelect(tkt, SELECT_BY_TICKET, MODE_HISTORY))
        {
         if(OrderCloseTime() > 0)
           {
            double closePx = OrderClosePrice();
            double orderSL = OrderStopLoss();
            string cmt     = OrderComment();
            bool isSLHit   = false;

            if(orderSL > 0.0 && MathAbs(closePx - orderSL) <= (50.0 * Point))
               isSLHit = true;
            else if(StringFind(cmt, "[sl]") >= 0 || StringFind(cmt, "sl") >= 0)
               isSLHit = true;
            else if(g_m6TrackedSLOrders[i].targetSL > 0.0 && MathAbs(closePx - g_m6TrackedSLOrders[i].targetSL) <= (50.0 * Point))
               isSLHit = true;

            if(isSLHit)
              {
               PrintFormat(">>> [METHOD 6 SL HIT DETECTED] Ticket #%d (%s) closed at SL (ClosePx=%s, SL=%s, Cmt='%s') | EMA Angle=%.1f deg",
                           tkt, (oType == OP_BUY ? "BUY" : "SELL"),
                           DoubleToString(closePx, Digits), DoubleToString(orderSL, Digits), cmt, curEmaAng);

               if(absEmaAng > InpMethod6PendingOnSLEmaAngle)
                 {
                  PrintFormat(">>> [METHOD 6 TREND SL RE-ENTRY] MathAbs(EMA Angle) %.1f > %.1f deg! Creating pending stop order in same %s direction...",
                              absEmaAng, InpMethod6PendingOnSLEmaAngle, (oType == OP_BUY ? "BUY" : "SELL"));
                  CreateMethod6PendingOrderAfterClose(oType, InpMethod6PendingSLRequireZeroOpen);
                 }
               else
                 {
                  PrintFormat(">>> [METHOD 6 TREND SL RE-ENTRY SKIPPED] MathAbs(EMA Angle) %.1f <= %.1f deg (weak trend / range). No pending order created.",
                              absEmaAng, InpMethod6PendingOnSLEmaAngle);
                 }
              }
            else
              {
               PrintFormat(">>> [METHOD 6 TRACK SL CLEARED] Ticket #%d (%s) closed NOT by SL (ClosePx=%s, SL=%s, Cmt='%s'). Tracker cleared.",
                           tkt, (oType == OP_BUY ? "BUY" : "SELL"),
                           DoubleToString(closePx, Digits), DoubleToString(orderSL, Digits), cmt);
              }

            g_m6TrackedSLOrders[i].isActive = false;
           }
        }
      else
        {
         g_m6TrackedSLOrders[i].isActive = false;
        }
     }
  }

//+------------------------------------------------------------------+
//| ApplyMethod6LivePriceStopLoss:                                   |
//| User Rule: Modify profit orders with StopLoss $50 from live      |
//| price direction:                                                 |
//| If EMADirection BULLISH (1)  -> Live Price - $50 (Bid - $50)     |
//| If EMADirection BEARISH (-1) -> Live Price + $50 (Ask + $50)     |
//| (Broker compliant: BUY SL < Bid, SELL SL > Ask)                  |
//+------------------------------------------------------------------+
bool ApplyMethod6LivePriceStopLoss(int ticket, int orderType, double openPrice, double currentSL, double takeProfit)
  {
   RefreshRates();
   double slGap = (InpMethod6LivePriceSLGapUSD > 0.0) ? InpMethod6LivePriceSLGapUSD : 50.0;
   double minStopDist = GetRequiredStopDistance();
   if(slGap < minStopDist)
      slGap = minStopDist;

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);
   double targetSL = 0.0;

   if(EMADirection == 1)
     {
      // Bullish: Live Price - $50
      targetSL = (orderType == OP_BUY) ? NormalizeDouble(curBid - slGap, Digits)
                                       : NormalizeDouble(curAsk + slGap, Digits);
     }
   else if(EMADirection == -1)
     {
      // Bearish: Live Price + $50
      targetSL = (orderType == OP_SELL) ? NormalizeDouble(curAsk + slGap, Digits)
                                        : NormalizeDouble(curBid - slGap, Digits);
     }
   else
     {
      targetSL = (orderType == OP_BUY) ? NormalizeDouble(curBid - slGap, Digits)
                                       : NormalizeDouble(curAsk + slGap, Digits);
     }

   // Respect Breakeven Breathing Floor
   double beFloor = GetEmaAngleBreakevenBreathingSL(orderType, openPrice, openPrice);
   if(orderType == OP_BUY)
     {
      if(targetSL < beFloor)
         targetSL = beFloor;
     }
   else if(orderType == OP_SELL)
     {
      if(targetSL > beFloor)
         targetSL = beFloor;
     }

   bool needModify = false;
   if(orderType == OP_BUY)
     {
      if(currentSL == 0.0 || targetSL > currentSL + Point)
         needModify = true;
     }
   else if(orderType == OP_SELL)
     {
      if(currentSL == 0.0 || targetSL < currentSL - Point)
         needModify = true;
     }

   if(needModify)
     {
      bool mod = SafeOrderModify(ticket, openPrice, targetSL, takeProfit, 0, (orderType == OP_BUY ? clrLimeGreen : clrTomato), "M6 $50 Live SL");
      if(mod)
        {
         RegisterMethod6ModifiedSLOrder(ticket, orderType, targetSL);
         PrintFormat(">>> [METHOD 6 LIVE SL] Ticket #%d (%s) | EMA Dir=%s | SL modified to $50 from live price: %s",
                     ticket, (orderType == OP_BUY ? "BUY" : "SELL"),
                     (EMADirection == 1 ? "BULLISH (-$50)" : (EMADirection == -1 ? "BEARISH (+$50)" : "FLAT")),
                     DoubleToString(targetSL, Digits));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| STAGE S0: OPPOSITE LOSER ELIMINATION (>= $0.00)                  |
//| User Rule: Any Profit Order(s) + Opposite Loss Order (Full or    |
//| Partial) >= $0.00. Closes opposite loser at market and modifies  |
//| winning order(s) StopLoss to $50 from live price direction.      |
//+------------------------------------------------------------------+
bool ExecuteMethod6StageS0(int candCount,
                           int &candTickets[], int &candTypes[], double &candLots[],
                           double &candOpenPrices[], double &candStopLosses[], double &candTakeProfits[],
                           double &candProfits[], bool &isProcessed[])
  {
   if(!InpMethod6EnableZeroNetLossCutSLModify)
      return false;

   int winIndices[MAX_M6_ORDERS];
   int lossIndices[MAX_M6_ORDERS];
   ArrayInitialize(winIndices, 0);
   ArrayInitialize(lossIndices, 0);
   int winCount = 0;
   int lossCount = 0;

   for(int i = 0; i < candCount && i < MAX_M6_ORDERS; i++)
     {
      if(isProcessed[i])
         continue;
      if(candProfits[i] > 0.0)
        {
         winIndices[winCount] = i;
         winCount++;
        }
      else if(candProfits[i] < 0.0)
        {
         lossIndices[lossCount] = i;
         lossCount++;
        }
     }

   if(winCount == 0 || lossCount == 0)
      return false;

   double minNetUSD = InpMethod6ZeroNetMinProfitUSD; // Default 0.0

   int selectedWinners[MAX_M6_ORDERS];
   ArrayInitialize(selectedWinners, 0);
   int selectedWinCount = 0;
   int selectedLoserIdx = -1;
   double bestNetPL = -999999.0;
   double bestLossAbs = 0.0;
   bool isPartialCut = false;
   double partialCutLots = 0.0;
   double partialLossUSD = 0.0;

   //------------------------------------------------------------------
   // PHASE 1: FULL OPPOSITE LOSING ORDER CLOSE
   //------------------------------------------------------------------
   // 1 Winner + 1 Opposite Loser
   for(int l = 0; l < lossCount; l++)
     {
      int lIdx = lossIndices[l];
      if(isProcessed[lIdx])
         continue;

      for(int w = 0; w < winCount; w++)
        {
         int wIdx = winIndices[w];
         if(isProcessed[wIdx])
            continue;

         // Must be OPPOSITE order types
         if(candTypes[wIdx] == candTypes[lIdx])
            continue;

         double netPL = NormalizeDouble(candProfits[wIdx] + candProfits[lIdx], 2);
         if(netPL >= minNetUSD)
           {
            double lossAbs = MathAbs(candProfits[lIdx]);
            if(lossAbs > bestLossAbs || (lossAbs == bestLossAbs && netPL > bestNetPL))
              {
               bestLossAbs = lossAbs;
               bestNetPL   = netPL;
               selectedLoserIdx = lIdx;
               selectedWinCount = 1;
               selectedWinners[0] = wIdx;
               isPartialCut = false;
              }
           }
        }
     }

   // 2 Winners + 1 Opposite Loser
   if(selectedLoserIdx < 0 && winCount >= 2)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         for(int w1 = 0; w1 < winCount - 1; w1++)
           {
            int w1Idx = winIndices[w1];
            if(isProcessed[w1Idx])
               continue;

            for(int w2 = w1 + 1; w2 < winCount; w2++)
              {
               int w2Idx = winIndices[w2];
               if(isProcessed[w2Idx])
                  continue;

               if(candTypes[w1Idx] == candTypes[lIdx] && candTypes[w2Idx] == candTypes[lIdx])
                  continue;

               double netPL = NormalizeDouble(candProfits[w1Idx] + candProfits[w2Idx] + candProfits[lIdx], 2);
               if(netPL >= minNetUSD)
                 {
                  double lossAbs = MathAbs(candProfits[lIdx]);
                  if(lossAbs > bestLossAbs || (lossAbs == bestLossAbs && netPL > bestNetPL))
                    {
                     bestLossAbs = lossAbs;
                     bestNetPL   = netPL;
                     selectedLoserIdx = lIdx;
                     selectedWinCount = 2;
                     selectedWinners[0] = w1Idx;
                     selectedWinners[1] = w2Idx;
                     isPartialCut = false;
                    }
                 }
              }
           }
        }
     }

   // 3+ Winners + 1 Opposite Loser
   if(selectedLoserIdx < 0 && winCount >= 3)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         double sumOppWins = 0.0;
         int oppCount = 0;
         for(int w = 0; w < winCount; w++)
           {
            int wIdx = winIndices[w];
            if(!isProcessed[wIdx] && candTypes[wIdx] != candTypes[lIdx])
              {
               sumOppWins += candProfits[wIdx];
               oppCount++;
              }
           }

         double netPL = NormalizeDouble(sumOppWins + candProfits[lIdx], 2);
         if(oppCount >= 3 && netPL >= minNetUSD)
           {
            selectedLoserIdx = lIdx;
            selectedWinCount = 0;
            for(int w = 0; w < winCount && selectedWinCount < MAX_M6_ORDERS; w++)
              {
               int wIdx = winIndices[w];
               if(!isProcessed[wIdx] && candTypes[wIdx] != candTypes[lIdx])
                 {
                  selectedWinners[selectedWinCount] = wIdx;
                  selectedWinCount++;
                 }
              }
            bestNetPL   = netPL;
            bestLossAbs = MathAbs(candProfits[lIdx]);
            isPartialCut = false;
            break;
           }
        }
     }

   //------------------------------------------------------------------
   // PHASE 2: PARTIAL OPPOSITE LOSING ORDER CUT
   //------------------------------------------------------------------
   if(InpMethod6EnablePartialLotCombination && selectedLoserIdx < 0)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         double lossTotalLots = candLots[lIdx];
         if(lossTotalLots <= 0.01)
            continue;

         double lossPL = candProfits[lIdx];
         double lossPerLot = MathAbs(lossPL) / lossTotalLots;
         if(lossPerLot <= 0.0)
            continue;

         for(int w = 0; w < winCount; w++)
           {
            int wIdx = winIndices[w];
            if(isProcessed[wIdx])
               continue;

            if(candTypes[wIdx] == candTypes[lIdx])
               continue;

            double winPL = candProfits[wIdx];
            double maxAbsorbable = winPL - minNetUSD;
            if(maxAbsorbable <= 0.0)
               continue;

            double maxLotsToCut = maxAbsorbable / lossPerLot;
            double pLots = MathFloor((maxLotsToCut + 0.00001) / 0.01) * 0.01;
            pLots = NormalizeDouble(pLots, 2);

            double maxAllowedCut = NormalizeDouble(lossTotalLots - 0.01, 2);
            if(pLots > maxAllowedCut)
               pLots = maxAllowedCut;
            if(InpMethod6PartialMaxCutLots > 0.0 && pLots > InpMethod6PartialMaxCutLots)
               pLots = NormalizeDouble(InpMethod6PartialMaxCutLots, 2);
            if(pLots < 0.01)
               continue;

            double pLossUSD = -1.0 * NormalizeDouble(lossPerLot * pLots, 2);
            double nProfitUSD = NormalizeDouble(winPL + pLossUSD, 2);

            if(nProfitUSD >= minNetUSD)
              {
               if(pLots > partialCutLots || (pLots == partialCutLots && nProfitUSD > bestNetPL))
                 {
                  partialCutLots   = pLots;
                  partialLossUSD   = pLossUSD;
                  bestNetPL        = nProfitUSD;
                  selectedLoserIdx = lIdx;
                  selectedWinCount = 1;
                  selectedWinners[0] = wIdx;
                  isPartialCut     = true;
                 }
              }
           }
        }
     }

   if(selectedLoserIdx < 0 || selectedWinCount == 0)
      return false;

   // EXECUTE S0 ACTION:
   int lossTkt  = candTickets[selectedLoserIdx];
   int lossType = candTypes[selectedLoserIdx];
   double lossLots = candLots[selectedLoserIdx];
   double lossPL   = candProfits[selectedLoserIdx];

   if(!isPartialCut)
     {
      PrintFormat(">>> [STAGE S0: FULL OPPOSITE LOSER CLOSED] Ticket #%d (%s %.2fL, Loss=-$%.2f) CLOSED at market | Covered by %d Winner(s) (Net=+$%.2f >= $0.00)",
                  lossTkt, (lossType == OP_BUY ? "BUY" : "SELL"), lossLots, MathAbs(lossPL),
                  selectedWinCount, bestNetPL);

      bool closed = CloseMarketOrderDirect(lossTkt);
      if(!closed)
        {
         PrintFormat(">>> [STAGE S0 ERROR] Failed to close opposite loser Ticket #%d. Aborting.", lossTkt);
         return false;
        }

      RecordMethodModification(lossTkt, 6, selectedWinCount + 1, lossPL);
      isProcessed[selectedLoserIdx] = true;
     }
   else
     {
      PrintFormat(">>> [STAGE S0: PARTIAL OPPOSITE LOSER CUT] Slicing %.2fL of %.2fL from Ticket #%d (%s, Slice Loss=-$%.2f) | Net=+$%.2f >= $0.00",
                  partialCutLots, lossLots, lossTkt, (lossType == OP_BUY ? "BUY" : "SELL"),
                  MathAbs(partialLossUSD), bestNetPL);

      bool partClosed = false;
      double lossClosePrice = 0.0;
      for(int attempt = 0; attempt < 3; attempt++)
        {
         RefreshRates();
         lossClosePrice = (lossType == OP_BUY) ? Bid : Ask;
         lossClosePrice = NormalizeDouble(lossClosePrice, Digits);
         ResetLastError();
         partClosed = OrderClose(lossTkt, partialCutLots, lossClosePrice, Slippage, (lossType == OP_BUY ? clrRed : clrBlue));
         if(partClosed)
            break;
         Sleep(100);
        }

      if(!partClosed)
        {
         PrintFormat(">>> [STAGE S0 ERROR] Failed to slice opposite loser Ticket #%d. Aborting.", lossTkt);
         return false;
        }

      RecordMethodModification(lossTkt, 6, 2, partialLossUSD);
      isProcessed[selectedLoserIdx] = true;
     }

   // Modify winner(s) StopLoss with $50 buffer from live price direction
   for(int w = 0; w < selectedWinCount; w++)
     {
      int wIdx = selectedWinners[w];
      ApplyMethod6LivePriceStopLoss(candTickets[wIdx], candTypes[wIdx], candOpenPrices[wIdx], candStopLosses[wIdx], candTakeProfits[wIdx]);
      isProcessed[wIdx] = true;
     }

   double iconPrice = (lossType == OP_BUY ? Bid : Ask);
   string s0Action = isPartialCut ? "1 Opposite Loser Sliced + Winner SL Modified ($50 Live)"
                                  : "1 Opposite Loser Closed at Market + Winner SL Modified ($50 Live)";
   DrawMethod6HitIcon(selectedWinCount + 1, bestNetPL, TimeCurrent(), iconPrice,
                      "Method 6 Stage S0: Zero-Net Relief", InpMethod6ZeroNetMinProfitUSD, s0Action);
   g_lastMethod6ActionTick = CurrentTickSequence;
   InvalidateTotalEAOrdersCache();
   return true;
  }

//+------------------------------------------------------------------+
//| STAGE S1: SAME-TYPE LOSER ELIMINATION (>= $0.00)                 |
//| User Rule: Any Profit Order(s) + Same-Type Loss Order (Full or   |
//| Partial) >= $0.00. Closes same-type loser at market and modifies |
//| winning order(s) StopLoss to $50 from live price direction.      |
//+------------------------------------------------------------------+
bool ExecuteMethod6StageS1(int candCount,
                           int &candTickets[], int &candTypes[], double &candLots[],
                           double &candOpenPrices[], double &candStopLosses[], double &candTakeProfits[],
                           double &candProfits[], bool &isProcessed[])
  {
   if(!InpMethod6EnableZeroNetLossCutSLModify)
      return false;

   int winIndices[MAX_M6_ORDERS];
   int lossIndices[MAX_M6_ORDERS];
   ArrayInitialize(winIndices, 0);
   ArrayInitialize(lossIndices, 0);
   int winCount = 0;
   int lossCount = 0;

   for(int i = 0; i < candCount && i < MAX_M6_ORDERS; i++)
     {
      if(isProcessed[i])
         continue;
      if(candProfits[i] > 0.0)
        {
         winIndices[winCount] = i;
         winCount++;
        }
      else if(candProfits[i] < 0.0)
        {
         lossIndices[lossCount] = i;
         lossCount++;
        }
     }

   if(winCount == 0 || lossCount == 0)
      return false;

   double minNetUSD = InpMethod6ZeroNetMinProfitUSD; // Default 0.0

   int selectedWinners[MAX_M6_ORDERS];
   ArrayInitialize(selectedWinners, 0);
   int selectedWinCount = 0;
   int selectedLoserIdx = -1;
   double bestNetPL = -999999.0;
   double bestLossAbs = 0.0;
   bool isPartialCut = false;
   double partialCutLots = 0.0;
   double partialLossUSD = 0.0;

   //------------------------------------------------------------------
   // PHASE 1: FULL SAME-TYPE LOSING ORDER CLOSE
   //------------------------------------------------------------------
   // 1 Winner + 1 Same-Type Loser
   for(int l = 0; l < lossCount; l++)
     {
      int lIdx = lossIndices[l];
      if(isProcessed[lIdx])
         continue;

      for(int w = 0; w < winCount; w++)
        {
         int wIdx = winIndices[w];
         if(isProcessed[wIdx])
            continue;

         // Must be SAME order types
         if(candTypes[wIdx] != candTypes[lIdx])
            continue;

         double netPL = NormalizeDouble(candProfits[wIdx] + candProfits[lIdx], 2);
         if(netPL >= minNetUSD)
           {
            double lossAbs = MathAbs(candProfits[lIdx]);
            if(lossAbs > bestLossAbs || (lossAbs == bestLossAbs && netPL > bestNetPL))
              {
               bestLossAbs = lossAbs;
               bestNetPL   = netPL;
               selectedLoserIdx = lIdx;
               selectedWinCount = 1;
               selectedWinners[0] = wIdx;
               isPartialCut = false;
              }
           }
        }
     }

   // 2 Winners + 1 Same-Type Loser
   if(selectedLoserIdx < 0 && winCount >= 2)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         for(int w1 = 0; w1 < winCount - 1; w1++)
           {
            int w1Idx = winIndices[w1];
            if(isProcessed[w1Idx])
               continue;

            for(int w2 = w1 + 1; w2 < winCount; w2++)
              {
               int w2Idx = winIndices[w2];
               if(isProcessed[w2Idx])
                  continue;

               if(candTypes[w1Idx] != candTypes[lIdx] || candTypes[w2Idx] != candTypes[lIdx])
                  continue;

               double netPL = NormalizeDouble(candProfits[w1Idx] + candProfits[w2Idx] + candProfits[lIdx], 2);
               if(netPL >= minNetUSD)
                 {
                  double lossAbs = MathAbs(candProfits[lIdx]);
                  if(lossAbs > bestLossAbs || (lossAbs == bestLossAbs && netPL > bestNetPL))
                    {
                     bestLossAbs = lossAbs;
                     bestNetPL   = netPL;
                     selectedLoserIdx = lIdx;
                     selectedWinCount = 2;
                     selectedWinners[0] = w1Idx;
                     selectedWinners[1] = w2Idx;
                     isPartialCut = false;
                    }
                 }
              }
           }
        }
     }

   // 3+ Winners + 1 Same-Type Loser
   if(selectedLoserIdx < 0 && winCount >= 3)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         double sumSameWins = 0.0;
         int sameCount = 0;
         for(int w = 0; w < winCount; w++)
           {
            int wIdx = winIndices[w];
            if(!isProcessed[wIdx] && candTypes[wIdx] == candTypes[lIdx])
              {
               sumSameWins += candProfits[wIdx];
               sameCount++;
              }
           }

         double netPL = NormalizeDouble(sumSameWins + candProfits[lIdx], 2);
         if(sameCount >= 3 && netPL >= minNetUSD)
           {
            selectedLoserIdx = lIdx;
            selectedWinCount = 0;
            for(int w = 0; w < winCount && selectedWinCount < MAX_M6_ORDERS; w++)
              {
               int wIdx = winIndices[w];
               if(!isProcessed[wIdx] && candTypes[wIdx] == candTypes[lIdx])
                 {
                  selectedWinners[selectedWinCount] = wIdx;
                  selectedWinCount++;
                 }
              }
            bestNetPL   = netPL;
            bestLossAbs = MathAbs(candProfits[lIdx]);
            isPartialCut = false;
            break;
           }
        }
     }

   //------------------------------------------------------------------
   // PHASE 2: PARTIAL SAME-TYPE LOSING ORDER CUT
   //------------------------------------------------------------------
   if(InpMethod6EnablePartialLotCombination && selectedLoserIdx < 0)
     {
      for(int l = 0; l < lossCount; l++)
        {
         int lIdx = lossIndices[l];
         if(isProcessed[lIdx])
            continue;

         double lossTotalLots = candLots[lIdx];
         if(lossTotalLots <= 0.01)
            continue;

         double lossPL = candProfits[lIdx];
         double lossPerLot = MathAbs(lossPL) / lossTotalLots;
         if(lossPerLot <= 0.0)
            continue;

         for(int w = 0; w < winCount; w++)
           {
            int wIdx = winIndices[w];
            if(isProcessed[wIdx])
               continue;

            if(candTypes[wIdx] != candTypes[lIdx])
               continue;

            double winPL = candProfits[wIdx];
            double maxAbsorbable = winPL - minNetUSD;
            if(maxAbsorbable <= 0.0)
               continue;

            double maxLotsToCut = maxAbsorbable / lossPerLot;
            double pLots = MathFloor((maxLotsToCut + 0.00001) / 0.01) * 0.01;
            pLots = NormalizeDouble(pLots, 2);

            double maxAllowedCut = NormalizeDouble(lossTotalLots - 0.01, 2);
            if(pLots > maxAllowedCut)
               pLots = maxAllowedCut;
            if(InpMethod6PartialMaxCutLots > 0.0 && pLots > InpMethod6PartialMaxCutLots)
               pLots = NormalizeDouble(InpMethod6PartialMaxCutLots, 2);
            if(pLots < 0.01)
               continue;

            double pLossUSD = -1.0 * NormalizeDouble(lossPerLot * pLots, 2);
            double nProfitUSD = NormalizeDouble(winPL + pLossUSD, 2);

            if(nProfitUSD >= minNetUSD)
              {
               if(pLots > partialCutLots || (pLots == partialCutLots && nProfitUSD > bestNetPL))
                 {
                  partialCutLots   = pLots;
                  partialLossUSD   = pLossUSD;
                  bestNetPL        = nProfitUSD;
                  selectedLoserIdx = lIdx;
                  selectedWinCount = 1;
                  selectedWinners[0] = wIdx;
                  isPartialCut     = true;
                 }
              }
           }
        }
     }

   if(selectedLoserIdx < 0 || selectedWinCount == 0)
      return false;

   // EXECUTE S1 ACTION:
   int lossTkt  = candTickets[selectedLoserIdx];
   int lossType = candTypes[selectedLoserIdx];
   double lossLots = candLots[selectedLoserIdx];
   double lossPL   = candProfits[selectedLoserIdx];

   if(!isPartialCut)
     {
      PrintFormat(">>> [STAGE S1: FULL SAME-TYPE LOSER CLOSED] Ticket #%d (%s %.2fL, Loss=-$%.2f) CLOSED at market | Covered by %d Winner(s) (Net=+$%.2f >= $0.00)",
                  lossTkt, (lossType == OP_BUY ? "BUY" : "SELL"), lossLots, MathAbs(lossPL),
                  selectedWinCount, bestNetPL);

      bool closed = CloseMarketOrderDirect(lossTkt);
      if(!closed)
        {
         PrintFormat(">>> [STAGE S1 ERROR] Failed to close same-type loser Ticket #%d. Aborting.", lossTkt);
         return false;
        }

      RecordMethodModification(lossTkt, 6, selectedWinCount + 1, lossPL);
      isProcessed[selectedLoserIdx] = true;
     }
   else
     {
      PrintFormat(">>> [STAGE S1: PARTIAL SAME-TYPE LOSER CUT] Slicing %.2fL of %.2fL from Ticket #%d (%s, Slice Loss=-$%.2f) | Net=+$%.2f >= $0.00",
                  partialCutLots, lossLots, lossTkt, (lossType == OP_BUY ? "BUY" : "SELL"),
                  MathAbs(partialLossUSD), bestNetPL);

      bool partClosed = false;
      double lossClosePrice = 0.0;
      for(int attempt = 0; attempt < 3; attempt++)
        {
         RefreshRates();
         lossClosePrice = (lossType == OP_BUY) ? Bid : Ask;
         lossClosePrice = NormalizeDouble(lossClosePrice, Digits);
         ResetLastError();
         partClosed = OrderClose(lossTkt, partialCutLots, lossClosePrice, Slippage, (lossType == OP_BUY ? clrRed : clrBlue));
         if(partClosed)
            break;
         Sleep(100);
        }

      if(!partClosed)
        {
         PrintFormat(">>> [STAGE S1 ERROR] Failed to slice same-type loser Ticket #%d. Aborting.", lossTkt);
         return false;
        }

      RecordMethodModification(lossTkt, 6, 2, partialLossUSD);
      isProcessed[selectedLoserIdx] = true;
     }

   // Modify winner(s) StopLoss with $50 buffer from live price direction
   for(int w = 0; w < selectedWinCount; w++)
     {
      int wIdx = selectedWinners[w];
      ApplyMethod6LivePriceStopLoss(candTickets[wIdx], candTypes[wIdx], candOpenPrices[wIdx], candStopLosses[wIdx], candTakeProfits[wIdx]);
      isProcessed[wIdx] = true;
     }

   double iconPrice = (lossType == OP_BUY ? Bid : Ask);
   string s1Action = isPartialCut ? "1 Same-Type Loser Sliced + Winner SL Modified ($50 Live)"
                                  : "1 Same-Type Loser Closed at Market + Winner SL Modified ($50 Live)";
   DrawMethod6HitIcon(selectedWinCount + 1, bestNetPL, TimeCurrent(), iconPrice,
                      "Method 6 Stage S1: Same-Type Relief", InpMethod6ZeroNetMinProfitUSD, s1Action);
   g_lastMethod6ActionTick = CurrentTickSequence;
   InvalidateTotalEAOrdersCache();
   return true;
  }

//+------------------------------------------------------------------+
//| STAGE S2 & S3: PROFIT COMBINATIONS (RANGE vs STRONG TREND)       |
//| S2: MathAbs(EMA Angle) <= 4.0 -> Target = $InpMethod6ProfitThresholdUSD ($2.00) |
//| S3: MathAbs(EMA Angle) >  4.0 -> Target = $InpMethod6ProfitThresholdUSD * 1.5 ($3.00) |
//+------------------------------------------------------------------+
bool ExecuteMethod6StageS2_S3(int candCount,
                              int &candTickets[], int &candTypes[], double &candLots[],
                              double &candOpenPrices[], double &candStopLosses[], double &candTakeProfits[],
                              double &candProfits[], bool &isProcessed[])
  {
   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absEmaAng = MathAbs(curEmaAng);
   double baseThreshold = (InpMethod6ProfitThresholdUSD > 0.0) ? InpMethod6ProfitThresholdUSD : 2.0;

   bool isSteep = (absEmaAng > InpMethod6SteepAngleDegrees);
   double angleMultiplier = isSteep ? ((InpMethod6SteepAngleMultiplier > 0.0) ? InpMethod6SteepAngleMultiplier : 1.5) : 1.0;

   // S2 Target ($2.00 * mult) vs S3 Target ($3.00 * mult)
   double requiredTarget = NormalizeDouble(baseThreshold * angleMultiplier * mult, 2);
   string stageLabel = isSteep ? "STAGE S3 (STRONG TREND >4 deg)" : "STAGE S2 (RANGE <=4 deg)";

   int selectedIndices[MAX_M6_ORDERS];
   ArrayInitialize(selectedIndices, 0);
   int selectedCount = 0;
   double bestComboPL = 0.0;

   // 1. Same-Type Pairs
   int searchLimit2 = MathMin(candCount, 30);
   for(int i = 0; i < searchLimit2 - 1; i++)
     {
      if(isProcessed[i] || candProfits[i] <= 0.0)
         continue;
      for(int j = i + 1; j < searchLimit2; j++)
        {
         if(isProcessed[j] || candProfits[j] <= 0.0)
            continue;
         if(candTypes[i] != candTypes[j])
            continue;

         double sum2 = NormalizeDouble(candProfits[i] + candProfits[j], 2);
         if(sum2 >= requiredTarget)
           {
            selectedIndices[0] = i;
            selectedIndices[1] = j;
            selectedCount = 2;
            bestComboPL = sum2;
            break;
           }
        }
      if(selectedCount > 0)
         break;
     }

   // 2. Same-Type Triplets if no pair reached target
   if(selectedCount == 0 && candCount >= 3)
     {
      int searchLimit3 = MathMin(candCount, 20);
      for(int i = 0; i < searchLimit3 - 2; i++)
        {
         if(isProcessed[i] || candProfits[i] <= 0.0)
            continue;
         for(int j = i + 1; j < searchLimit3 - 1; j++)
           {
            if(isProcessed[j] || candProfits[j] <= 0.0)
               continue;
            if(candTypes[i] != candTypes[j])
               continue;

            for(int k = j + 1; k < searchLimit3; k++)
              {
               if(isProcessed[k] || candProfits[k] <= 0.0)
                  continue;
               if(candTypes[i] != candTypes[k])
                  continue;

               double sum3 = NormalizeDouble(candProfits[i] + candProfits[j] + candProfits[k], 2);
               if(sum3 >= requiredTarget)
                 {
                  selectedIndices[0] = i;
                  selectedIndices[1] = j;
                  selectedIndices[2] = k;
                  selectedCount = 3;
                  bestComboPL = sum3;
                  break;
                 }
              }
            if(selectedCount > 0)
               break;
           }
         if(selectedCount > 0)
            break;
        }
     }

   // 3. All Open Winning Basket if not triggered yet
   if(selectedCount == 0 && candCount >= 2)
     {
      double sumBasket = 0.0;
      int basketCount = 0;
      int bIndices[MAX_M6_ORDERS];
      ArrayInitialize(bIndices, 0);

      for(int b = 0; b < candCount && b < MAX_M6_ORDERS; b++)
        {
         if(!isProcessed[b] && candProfits[b] > 0.0)
           {
            bIndices[basketCount] = b;
            sumBasket += candProfits[b];
            basketCount++;
           }
        }

      sumBasket = NormalizeDouble(sumBasket, 2);
      if(basketCount >= 2 && sumBasket >= requiredTarget)
        {
         for(int b = 0; b < basketCount; b++)
            selectedIndices[b] = bIndices[b];
         selectedCount = basketCount;
         bestComboPL = sumBasket;
        }
     }

   if(selectedCount == 0)
      return false;

   // EXECUTE S2/S3 ACTION:
   PrintFormat(">>> [METHOD 6 %s TRIGGERED] %d Orders Hit Combo Profit = +$%.2f >= Required $%.2f (EMA Angle=%.1f deg)",
               stageLabel, selectedCount, bestComboPL, requiredTarget, curEmaAng);

   int closedWinType = candTypes[selectedIndices[0]];

   bool s3ModifySL = (isSteep && InpMethod6S3ModifySLInsteadOfClose);
   bool shouldCloseMarket = InpMethod6CloseWinnerAtMarket && !s3ModifySL;

   if(shouldCloseMarket)
     {
      for(int c = 0; c < selectedCount; c++)
        {
         int idx = selectedIndices[c];
         int tkt = candTickets[idx];
         double profitUSD = candProfits[idx];
         bool closed = CloseMarketOrderDirect(tkt);
         if(closed)
           {
            RecordMethodModification(tkt, 6, selectedCount, profitUSD);
            PrintFormat(">>> [METHOD 6 %s: CLOSED AT MARKET] Ticket #%d (%s %.2fL) Realized Profit = +$%.2f",
                        stageLabel, tkt, (candTypes[idx] == OP_BUY ? "BUY" : "SELL"), candLots[idx], profitUSD);
           }
         isProcessed[idx] = true;
        }

      if(InpMethod6CreatePendingOnWinnerClose)
        {
         CreateMethod6PendingOrderAfterClose(closedWinType, true);
        }
     }
   else
     {
      // Modify StopLoss with $50 buffer from live price direction (Stage S3 trend runner or user setting)
      for(int c = 0; c < selectedCount; c++)
        {
         int idx = selectedIndices[c];
         ApplyMethod6LivePriceStopLoss(candTickets[idx], candTypes[idx], candOpenPrices[idx], candStopLosses[idx], candTakeProfits[idx]);
         isProcessed[idx] = true;
        }
     }

   double iconPrice = (closedWinType == OP_BUY ? Bid : Ask);
   string s2s3Action = shouldCloseMarket ? "Winners Closed at Market" : "Winners SL Modified ($50 Live)";
   DrawMethod6HitIcon(selectedCount, bestComboPL, TimeCurrent(), iconPrice,
                      StringFormat("Method 6 Stage %s", stageLabel), requiredTarget, s2s3Action);
   g_lastMethod6ActionTick = CurrentTickSequence;
   InvalidateTotalEAOrdersCache();
   return true;
  }

//+------------------------------------------------------------------+
//| ExecuteMethod6ZeroNetRelief: Backward-compatibility wrapper      |
//+------------------------------------------------------------------+
bool ExecuteMethod6ZeroNetRelief(int candCount,
                                 int &candTickets[], int &candTypes[], double &candLots[],
                                 double &candOpenPrices[], double &candStopLosses[], double &candTakeProfits[],
                                 double &candProfits[], bool &isProcessed[])
  {
   if(ExecuteMethod6StageS0(candCount, candTickets, candTypes, candLots,
                            candOpenPrices, candStopLosses, candTakeProfits,
                            candProfits, isProcessed))
      return true;
   return ExecuteMethod6StageS1(candCount, candTickets, candTypes, candLots,
                                candOpenPrices, candStopLosses, candTakeProfits,
                                candProfits, isProcessed);
  }

//+------------------------------------------------------------------+
//| ModifyMethod6MultiOrderCombinationsOver5USD                      |
//+------------------------------------------------------------------+
void ModifyMethod6MultiOrderCombinationsOver5USD()
  {
   if(!InpEnableMethod6CombinationSLModify)
      return;

   int    candTickets[MAX_M6_ORDERS];
   int    candTypes[MAX_M6_ORDERS];
   double candLots[MAX_M6_ORDERS];
   double candOpenPrices[MAX_M6_ORDERS];
   double candStopLosses[MAX_M6_ORDERS];
   double candTakeProfits[MAX_M6_ORDERS];
   double candProfits[MAX_M6_ORDERS];
   bool   isProcessed[MAX_M6_ORDERS];
   ArrayInitialize(candTickets, 0);
   ArrayInitialize(candTypes, 0);
   ArrayInitialize(candLots, 0.0);
   ArrayInitialize(candOpenPrices, 0.0);
   ArrayInitialize(candStopLosses, 0.0);
   ArrayInitialize(candTakeProfits, 0.0);
   ArrayInitialize(candProfits, 0.0);
   ArrayInitialize(isProcessed, false);
   int candCount = 0;

   int minOrders = (InpMethod6MinOrderCount >= 2) ? InpMethod6MinOrderCount : 2;

   for(int i = OrdersTotal() - 1; i >= 0 && candCount < MAX_M6_ORDERS; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      string cmt = OrderComment();
      int tkt    = OrderTicket();

      // Exclude recovery orders
      if(IsAnyRecoveryOrder(tkt, cmt) || IsRecoveryOrderWithActiveParent(tkt, cmt))
         continue;

      // Exclude FLIPBasketSupport orders
      if(IsFLIPBasketSupportOrder(tkt, cmt) || StringFind(cmt, "FLIPBasketSupport") >= 0)
         continue;

      candTickets[candCount]    = tkt;
      candTypes[candCount]      = oType;
      candLots[candCount]       = OrderLots();
      candOpenPrices[candCount] = OrderOpenPrice();
      candStopLosses[candCount] = OrderStopLoss();
      candTakeProfits[candCount]= OrderTakeProfit();
      candProfits[candCount]    = OrderProfit() + OrderSwap() + OrderCommission();
      isProcessed[candCount]    = false;
      candCount++;
     }

   if(candCount < minOrders)
      return;

//====================================================================
// STAGE S0: OPPOSITE LOSER ELIMINATION (>= $0.00)
// USER RULE: Any Profit order(s) + Opposite Loss order (full or partial) >= $0.00
// Always close losing order (or partial cut) on priority; modify profit order SL to $50 from live price.
//====================================================================
   if(ExecuteMethod6StageS0(candCount, candTickets, candTypes, candLots,
                            candOpenPrices, candStopLosses, candTakeProfits,
                            candProfits, isProcessed))
      return;

//====================================================================
// STAGE S1: SAME-TYPE LOSER ELIMINATION (>= $0.00)
// USER RULE: Any Profit order(s) + Same-type Loss order (full or partial) >= $0.00
// Always close losing order (or partial cut) on priority; modify profit order SL to $50 from live price.
//====================================================================
   if(ExecuteMethod6StageS1(candCount, candTickets, candTypes, candLots,
                            candOpenPrices, candStopLosses, candTakeProfits,
                            candProfits, isProcessed))
      return;

//====================================================================
// STAGE S2 & S3: PROFIT COMBINATIONS (RANGE <=4 deg vs STRONG TREND >4 deg)
// USER RULE: S2: Profit combinations > InpMethod6ProfitThresholdUSD ($2.00) if MathAbs(EMA Angle) <= 4 deg.
//            S3: Profit combinations > InpMethod6ProfitThresholdUSD * 1.5 ($3.00) if MathAbs(EMA Angle) > 4 deg.
//====================================================================
   if(ExecuteMethod6StageS2_S3(candCount, candTickets, candTypes, candLots,
                               candOpenPrices, candStopLosses, candTakeProfits,
                               candProfits, isProcessed))
      return;
  }

//+------------------------------------------------------------------+
//| Direct market close with 3-attempt retries for combinations      |
//+------------------------------------------------------------------+
bool CloseMarketOrderDirect(int ticket)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return true; // Already closed

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return false;

   double lots = OrderLots();

   bool closed = false;
   for(int attempt = 0; attempt < 3; attempt++)
     {
      RefreshRates();
      ResetLastError();
      closed = SafeOrderCloseMarket(ticket, lots, Slippage, (type == OP_BUY ? clrRed : clrBlue));
      if(closed)
         return true;
      int err = GetLastError();
      Print("CloseMarketOrderDirect attempt ", (attempt + 1), " failed for Ticket #", ticket, " | Error=", err);
      Sleep(100);
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Close any combination of open orders when sum > $1 * multiplier  |
//| Supports 1, 2, 3 orders or entire basket, Buy or Sell or mixed   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Helper to modify StopLoss with $150 gap or close combination order|
//+------------------------------------------------------------------+
bool ModifyOrCloseCombinationOrder(int ticket)
  {
   if(!InpCombinationModifySLWithGap)
      return CloseMarketOrderDirect(ticket);

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return false;

   int oType = OrderType();
   double oOpen = OrderOpenPrice();
   double curSL = OrderStopLoss();
   double curTP = OrderTakeProfit();
   RefreshRates();
   double minStopDist = GetRequiredStopDistance();
   double curPL = OrderProfit() + OrderSwap() + OrderCommission();
   double gap = (InpCombinationSLGapUSD > 0.0) ? InpCombinationSLGapUSD : 150.0;
   double proposedSL = GetTrendAwareStopLoss(oType, gap, curSL, "Method 4", curPL, oOpen);

   double rawProfitGap = (oType == OP_BUY) ? (Bid - oOpen) : (oOpen - Ask);
   bool isSteepAngle = (InpEnableDoubleSlGapOnSteepAngle && MathAbs(GlobalEmaAngle30) > InpDoubleSlGapAngle);
   bool isProfitGapReached = (rawProfitGap > InpDoubleSlMinProfitGapRaw);

// Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
   double beFloorM4 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
   if(isProfitGapReached)
     {
      if(oType == OP_BUY && proposedSL < beFloorM4)
         proposedSL = beFloorM4;
      else
         if(oType == OP_SELL && proposedSL > beFloorM4)
            proposedSL = beFloorM4;
     }

   bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM4 : proposedSL <= beFloorM4));

   if(oType == OP_BUY)
     {
      if(proposedSL < Bid && (curSL == 0.0 || (proposedSL > curSL && (proposedSL - curSL) >= MinimumSLModifyGapRaw) ||
                              (allowBreathingWidening && MathAbs(proposedSL - curSL) >= MinimumSLModifyGapRaw)))
         return SafeOrderModify(ticket, oOpen, proposedSL, curTP, 0, clrLimeGreen, "Method 4");
     }
   else
      if(oType == OP_SELL)
        {
         if(proposedSL > Ask && (curSL == 0.0 || (proposedSL < curSL && (curSL - proposedSL) >= MinimumSLModifyGapRaw) ||
                                 (allowBreathingWidening && MathAbs(proposedSL - curSL) >= MinimumSLModifyGapRaw)))
            return SafeOrderModify(ticket, oOpen, proposedSL, curTP, 0, clrTomato, "Method 4");
        }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseProfitableOrderCombinations()
  {
   if(!InpEnableCombinationProfitClose)
      return;

   int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
   double minProfitUSD = (InpCombinationCloseProfitUSD > 0.0 ? InpCombinationCloseProfitUSD : 5.0) * mult;

// 1. Collect all open market orders for current symbol & magic number
#define MAX_COMB_ORDERS 100
   int    candTickets[MAX_COMB_ORDERS];
   int    candTypes[MAX_COMB_ORDERS];
   double candLots[MAX_COMB_ORDERS];
   double candProfits[MAX_COMB_ORDERS];
   bool   isClosed[MAX_COMB_ORDERS];
   ArrayInitialize(candTickets, 0);
   ArrayInitialize(candTypes, 0);
   ArrayInitialize(candLots, 0.0);
   ArrayInitialize(candProfits, 0.0);
   ArrayInitialize(isClosed, false);
   int    candCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0 && candCount < MAX_COMB_ORDERS; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      string cmt = OrderComment();
      int tkt    = OrderTicket();

      // EXCLUDE RECOVERY ORDERS: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(tkt, cmt) || IsRecoveryOrderWithActiveParent(tkt, cmt))
         continue;

      // Exclude FLIPBasketSupport orders unless explicitly enabled
      if(!InpPairCombinationIncludeFlipBasket)
        {
         if(IsFLIPBasketSupportOrder(tkt, cmt) || StringFind(cmt, "FLIPBasketSupport") >= 0)
            continue;
        }

      candTickets[candCount] = tkt;
      candTypes[candCount]   = oType;
      candLots[candCount]    = OrderLots();
      candProfits[candCount] = OrderProfit() + OrderSwap() + OrderCommission();
      isClosed[candCount]    = false;
      candCount++;
     }

   if(candCount <= 0)
      return;

   bool anyOrdersClosed = false;

// 2. TOTAL BASKET CHECK (if all open orders combined sum >= minProfitUSD and count >= 2)
   if(candCount >= 2)
     {
      double totalBasketPL = 0.0;
      for(int b = 0; b < candCount; b++)
         totalBasketPL += candProfits[b];

      if(totalBasketPL >= minProfitUSD)
        {
         int m4bTkts[10];
         double m4bPls[10];
         for(int m4bi = 0; m4bi < candCount && m4bi < 10; m4bi++)
           {
            m4bTkts[m4bi] = candTickets[m4bi];
            m4bPls[m4bi] = candProfits[m4bi];
           }
         RecordMethodActionCluster(4, m4bTkts, m4bPls, candCount, totalBasketPL, "Method 4: Basket Combo Close at market");

         Print(">>> [COMBINATION CLOSE - ALL ORDERS] Total Basket Profit = $", DoubleToString(totalBasketPL, 2),
               " >= $", DoubleToString(minProfitUSD, 2), " | Closing ALL ", candCount, " open orders!");

         for(int b = 0; b < candCount; b++)
           {
            if(ModifyOrCloseCombinationOrder(candTickets[b]))
              {
               isClosed[b] = true;
               RecordMethodModification(candTickets[b], 4, candCount, totalBasketPL);
              }
           }
         if(!InpCombinationModifySLWithGap)
            DrawMultiOrderClosedIcon(candCount, TimeCurrent(), (candTypes[0] == OP_BUY ? Bid : Ask), totalBasketPL, "Method 4: Basket Combo Close", candTickets[0]);
         InvalidateTotalEAOrdersCache();
         return;
        }
     }

// 3. PRIORITY PAIR CHECK (Win + Loss): Pair a winning order with a losing order if sum >= minProfitUSD
   for(int i = 0; i < candCount - 1; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < candCount; j++)
        {
         if(isClosed[j])
            continue;

         // Check if at least one order is in loss (offsets losing order)
         if(candProfits[i] < 0.0 || candProfits[j] < 0.0)
           {
            double pairSum = candProfits[i] + candProfits[j];
            if(pairSum >= minProfitUSD)
              {
               int m4pTkts[2];
               double m4pPls[2];
               m4pTkts[0] = candTickets[i];
               m4pPls[0] = candProfits[i];
               m4pTkts[1] = candTickets[j];
               m4pPls[1] = candProfits[j];
               RecordMethodActionCluster(4, m4pTkts, m4pPls, 2, pairSum, "Method 4: Pair Combo Close at market");

               Print(">>> [COMBINATION CLOSE - PAIR (WIN+LOSS)] Ticket #", candTickets[i],
                     " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[i], 2), ") + Ticket #",
                     candTickets[j], " (", (candTypes[j] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[j], 2),
                     ") = Total $", DoubleToString(pairSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Pair!");

               int firstIdx  = (candProfits[i] >= candProfits[j]) ? i : j;
               int secondIdx = (firstIdx == i) ? j : i;

               if(ModifyOrCloseCombinationOrder(candTickets[firstIdx]))
                 {
                  isClosed[firstIdx] = true;
                  RecordMethodModification(candTickets[firstIdx], 4, 2, pairSum);
                 }
               if(ModifyOrCloseCombinationOrder(candTickets[secondIdx]))
                 {
                  isClosed[secondIdx] = true;
                  RecordMethodModification(candTickets[secondIdx], 4, 2, pairSum);
                 }
               if(!InpCombinationModifySLWithGap)
                  DrawMultiOrderClosedIcon(2, TimeCurrent(), (candTypes[i] == OP_BUY ? Bid : Ask), pairSum, "Method 4: Pair Combo Close", candTickets[i]);
               anyOrdersClosed = true;
               break; // ticket i is consumed, break inner loop
              }
           }
        }
     }

// 4. PRIORITY TRIPLET CHECK (Win + Losses): Check combinations of 3 orders with at least one loss
   int maxTripletSearch = MathMin(candCount, 30);
   for(int i = 0; i < maxTripletSearch - 2; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < maxTripletSearch - 1; j++)
        {
         if(isClosed[j])
            continue;
         for(int k = j + 1; k < maxTripletSearch; k++)
           {
            if(isClosed[k])
               continue;

            if(candProfits[i] < 0.0 || candProfits[j] < 0.0 || candProfits[k] < 0.0)
              {
               double tripletSum = candProfits[i] + candProfits[j] + candProfits[k];
               if(tripletSum >= minProfitUSD)
                 {
                  int m4tTkts[3];
                  double m4tPls[3];
                  m4tTkts[0] = candTickets[i];
                  m4tPls[0] = candProfits[i];
                  m4tTkts[1] = candTickets[j];
                  m4tPls[1] = candProfits[j];
                  m4tTkts[2] = candTickets[k];
                  m4tPls[2] = candProfits[k];
                  RecordMethodActionCluster(4, m4tTkts, m4tPls, 3, tripletSum, "Method 4: Triplet Combo Close at market");

                  Print(">>> [COMBINATION CLOSE - TRIPLET (WITH LOSS)] Tickets [#", candTickets[i], ", #", candTickets[j], ", #", candTickets[k],
                        "] = Total $", DoubleToString(tripletSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Triplet!");

                  int tIdx[3];
                  tIdx[0] = i;
                  tIdx[1] = j;
                  tIdx[2] = k;
                  for(int x = 0; x < 2; x++)
                    {
                     for(int y = x + 1; y < 3; y++)
                       {
                        if(candProfits[tIdx[x]] < candProfits[tIdx[y]])
                          {
                           int tmp = tIdx[x];
                           tIdx[x] = tIdx[y];
                           tIdx[y] = tmp;
                          }
                       }
                    }

                  for(int t = 0; t < 3; t++)
                    {
                     if(ModifyOrCloseCombinationOrder(candTickets[tIdx[t]]))
                       {
                        isClosed[tIdx[t]] = true;
                        RecordMethodModification(candTickets[tIdx[t]], 4, 3, tripletSum);
                       }
                    }
                  if(!InpCombinationModifySLWithGap)
                     DrawMultiOrderClosedIcon(3, TimeCurrent(), (candTypes[i] == OP_BUY ? Bid : Ask), tripletSum, "Method 4: Triplet Combo Close", candTickets[i]);
                  anyOrdersClosed = true;
                  break; // break k loop
                 }
              }
           }
         if(isClosed[i])
            break; // ticket i is consumed, break j loop
        }
     }

// 5. ANY REMAINING PAIR CHECK (e.g. 2 Wins >= minProfitUSD)
   for(int i = 0; i < candCount - 1; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < candCount; j++)
        {
         if(isClosed[j])
            continue;

         double pairSum = candProfits[i] + candProfits[j];
         if(pairSum >= minProfitUSD)
           {
            Print(">>> [COMBINATION CLOSE - PAIR] Ticket #", candTickets[i],
                  " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[i], 2), ") + Ticket #",
                  candTickets[j], " (", (candTypes[j] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[j], 2),
                  ") = Total $", DoubleToString(pairSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Pair!");

            int firstIdx  = (candProfits[i] >= candProfits[j]) ? i : j;
            int secondIdx = (firstIdx == i) ? j : i;

            if(ModifyOrCloseCombinationOrder(candTickets[firstIdx]))
              {
               isClosed[firstIdx] = true;
               RecordMethodModification(candTickets[firstIdx], 4, 2, pairSum);
              }
            if(ModifyOrCloseCombinationOrder(candTickets[secondIdx]))
              {
               isClosed[secondIdx] = true;
               RecordMethodModification(candTickets[secondIdx], 4, 2, pairSum);
              }
            if(!InpCombinationModifySLWithGap)
               DrawMultiOrderClosedIcon(2, TimeCurrent(), (candTypes[i] == OP_BUY ? Bid : Ask), pairSum, "Method 4: Pair Combo Close", candTickets[i]);
            anyOrdersClosed = true;
            break; // ticket i is consumed, break j loop
           }
        }
     }

// 6. ANY REMAINING TRIPLET CHECK (e.g. 3 Wins >= minProfitUSD)
   for(int i = 0; i < maxTripletSearch - 2; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < maxTripletSearch - 1; j++)
        {
         if(isClosed[j])
            continue;
         for(int k = j + 1; k < maxTripletSearch; k++)
           {
            if(isClosed[k])
               continue;

            double tripletSum = candProfits[i] + candProfits[j] + candProfits[k];
            if(tripletSum >= minProfitUSD)
              {
               Print(">>> [COMBINATION CLOSE - TRIPLET] Tickets [#", candTickets[i], ", #", candTickets[j], ", #", candTickets[k],
                     "] = Total $", DoubleToString(tripletSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Triplet!");

               int tIdx[3];
               tIdx[0] = i;
               tIdx[1] = j;
               tIdx[2] = k;
               for(int x = 0; x < 2; x++)
                 {
                  for(int y = x + 1; y < 3; y++)
                    {
                     if(candProfits[tIdx[x]] < candProfits[tIdx[y]])
                       {
                        int tmp = tIdx[x];
                        tIdx[x] = tIdx[y];
                        tIdx[y] = tmp;
                       }
                    }
                 }

               for(int t = 0; t < 3; t++)
                 {
                  if(ModifyOrCloseCombinationOrder(candTickets[tIdx[t]]))
                    {
                     isClosed[tIdx[t]] = true;
                     RecordMethodModification(candTickets[tIdx[t]], 4, 3, tripletSum);
                    }
                 }
               if(!InpCombinationModifySLWithGap)
                  DrawMultiOrderClosedIcon(3, TimeCurrent(), (candTypes[i] == OP_BUY ? Bid : Ask), tripletSum, "Method 4: Triplet Combo Close", candTickets[i]);
               anyOrdersClosed = true;
               break; // break k loop
              }
           }
         if(isClosed[i])
            break; // ticket i is consumed, break j loop
        }
     }

// 7. SINGLE ORDER CHECK (Any individual order with profit >= minProfitUSD, disabled by default to preserve ladder/TP)
   if(InpCombinationIncludeSingleOrders)
     {
      for(int i = 0; i < candCount; i++)
        {
         if(isClosed[i])
            continue;

         if(candProfits[i] >= minProfitUSD)
           {
            Print(">>> [COMBINATION CLOSE - SINGLE ORDER] Ticket #", candTickets[i],
                  " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " ", DoubleToString(candLots[i], 2),
                  " lots) Profit = $", DoubleToString(candProfits[i], 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Order!");

            if(ModifyOrCloseCombinationOrder(candTickets[i]))
               isClosed[i] = true;
            anyOrdersClosed = true;
           }
        }
     }

   if(anyOrdersClosed)
      InvalidateTotalEAOrdersCache();
  }

//+------------------------------------------------------------------+
void SecureDistanceProfitLadder()
  {
// The raw price gap increment (e.g., 50.0 represents a $50 price movement in BTC)
   double distanceStep = 104;//50.0*3;

   if(distanceStep <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      RefreshRates();

      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();

      // 1. Calculate safe StopLevel (Fallback to 2x Spread for Crypto brokers with bugged limits)
      double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      double spreadBuf = (Ask - Bid) * 2.0;
      double minSafeDistance = MathMax(stopLevel, spreadBuf);

      double maxLockableDistance = 0.0;

      // 2. Calculate the maximum raw distance we can safely lock right now
      if(type == OP_BUY)
         maxLockableDistance = (Bid - minSafeDistance) - openPrice;
      else
         if(type == OP_SELL)
            maxLockableDistance = openPrice - (Ask + minSafeDistance);

      // If we aren't even in profit, skip
      if(maxLockableDistance <= 0)
         continue;

      // 3. Determine the ladder level (1 = $50, 2 = $100, 3 = $150, etc.)
      int ladderLevel = (int)MathFloor(maxLockableDistance / distanceStep);

      // If price hasn't moved far enough to even lock the first step, skip
      if(ladderLevel < 1)
         continue;

      // 4. Calculate the exact price for this distance ladder rung
      double lockedDistance = ladderLevel * distanceStep;
      double newSL = 0.0;
      bool canModify = false;

      if(type == OP_BUY)
        {
         newSL = NormalizeDouble(openPrice + lockedDistance, Digits);

         // FINAL BROKER CHECK: Ensure live price hasn't suddenly dropped too close to our new SL
         if(Bid - newSL >= minSafeDistance)
           {
            // Ensure we only move the SL forward
            if(currentSL == 0.0 || newSL > currentSL + (Point / 2.0))
               canModify = true;
           }
        }
      else
         if(type == OP_SELL)
           {
            newSL = NormalizeDouble(openPrice - lockedDistance, Digits);

            // FINAL BROKER CHECK: Ensure live price hasn't suddenly spiked too close to our new SL
            if(newSL - Ask >= minSafeDistance)
              {
               // Ensure we only move the SL forward
               if(currentSL == 0.0 || newSL < currentSL - (Point / 2.0))
                  canModify = true;
              }
           }

      // 5. Modify the order with enhanced diagnostic logging
      if(canModify)
        {
         ResetLastError();
         bool modified =SafeOrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrDodgerBlue);

         if(modified)
           {
            Print("Secured Distance Ladder: ", ladderLevel, "X (+$", DoubleToString(lockedDistance, 2), " price gap)",
                  " | Ticket=", OrderTicket(),
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | New SL=", DoubleToString(newSL, Digits));
           }
         else
           {
            // If it still fails, this print will tell you exactly why
            Print("FAILED MODIFY DISTANCE SL | Ticket=", OrderTicket(),
                  " | Error=", GetLastError(),
                  " | Ask=", DoubleToString(Ask, Digits),
                  " | Bid=", DoubleToString(Bid, Digits),
                  " | Curr SL=", DoubleToString(currentSL, Digits),
                  " | Attempted SL=", DoubleToString(newSL, Digits),
                  " | Min Broker Distance=", DoubleToString(minSafeDistance, Digits));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| GetLotBasedPriceGap: Dynamic price gap based on lot & multiplier  |
//| Base Lot 0.01 ->  gap                                        |
//| Base Lot 0.02 ->  gap                                         |
//| Base Lot 0.03 ->  gap                                         |
//| Base Lot 0.04 ->  gap                                         |
//| Base Lot 0.05 and above ->  gap                               |
//| Floor strictly at MinimumSLModifyGapRaw (.0)                  |
//+------------------------------------------------------------------+
double GetLotBasedPriceGap(double orderLots, int multiplier)
  {
   if(multiplier < 1)
      multiplier = 1;

// 1. Normalize lot size back to Base Lot
   double baseLot = NormalizeDouble(orderLots / (double)multiplier, 2);

// 2. Apply tiered gap schedule:
   double gap = 50.0;

   if(baseLot <= 0.015)
      gap = 100.0;
   else
      if(baseLot <= 0.025)
         gap = 80.0;
      else
         if(baseLot <= 0.035)
            gap = 70.0;
         else
            if(baseLot <= 0.045)
               gap = 60.0;
            else
               gap = 50.0; // 0.05 and all higher lots

// 3. Absolute safety floor against broker MinimumSLModifyGapRaw ()
   if(gap < MinimumSLModifyGapRaw)
      gap = MinimumSLModifyGapRaw;

   return gap;
  }

//+------------------------------------------------------------------+
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
      else
         if(orderType == OP_SELL)
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
//| CalculateProportionalLadderSL:                                   |
//| MAIN COMMON METHOD for Proportional Profit Ladder across ALL     |
//| methods and lot tiers:                                           |
//| Base Lot 0.01 -> Gap $100 (Level 1 @ +$125 -> SL openPrice +/-25)|
//| Base Lot 0.02 -> Gap $80  (Level 1 @ +$105 -> SL openPrice +/-25)|
//| Base Lot 0.03 -> Gap $70  (Level 1 @ +$95  -> SL openPrice +/-25)|
//| Base Lot 0.04 -> Gap $60  (Level 1 @ +$85  -> SL openPrice +/-25)|
//| Base Lot 0.05+-> Gap $50  (Level 1 @ +$75  -> SL openPrice +/-25)|
//|                                                                  |
//| Level 1: triggers at stepPriceGap + 25, locks +25 (openPrice+/-25|
//| Level 2: locks +1x stepPriceGap + 25 ($125 for 0.01L)            |
//| Level 3+:                                                        |
//|   - Under STRONG EMA: locks +(ladderLevel - 2)*stepPriceGap + 25 |
//|   - Under WEAK EMA:   locks +(ladderLevel - 1)*stepPriceGap + 25 |
//+------------------------------------------------------------------+
//| CalculateProportionalLadderSL:                                   |
//| USER RULE (VMULTI-1222): Universal Common Logic for ALL Lots:    |
//| - EMA Angle < 4:  order moves $100 -> SL to $25 (locks +$25)     |
//|   Next every $50 move -> SL moves extra $50 ($75, $125, $175...) |
//| - EMA Angle >= 4: order moves $125 -> SL to $25 (locks +$25)     |
//|   Next every $50 move -> SL moves extra $50 ($75, $125, $175...) |
//+------------------------------------------------------------------+
double CalculateProportionalLadderSLWithLevel(int orderType, double openPrice, double orderLots, int &outLadderLevel)
  {
   outLadderLevel = 0;
   if(orderLots <= 0.0 || openPrice <= 0.0)
      return 0.0;

   RefreshRates();
   double stopLevel = GetRequiredStopDistance();
   if(stopLevel < 10.0)
      stopLevel = 10.0;

   double curAngle = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
   double absAngle = MathAbs(curAngle);

// User Rule: When EMA angle between 3 to 8: Level 1 -> $200, Level 2 -> $350, Level 3 -> $500, every step +150
   bool isAngle3to8 = (absAngle >= InpLadderAngleRangeMin && absAngle <= InpLadderAngleRangeMax);

   double level1TriggerMove = 100.0;
   double stepPriceGap      = InpLadderStepIncrementRaw; // 50.0
   double baseLockSL        = InpLadderStepExtraSLRaw;   // 25.0

   if(isAngle3to8)
     {
      level1TriggerMove = InpLadderAngleRangeLevel1MoveRaw;       // 200.0
      stepPriceGap      = InpLadderAngleRangeStepIncrementRaw;    // 150.0
      baseLockSL        = InpLadderStepExtraSLRaw;                // 25.0
     }
   else
      if(absAngle >= InpLadderSteepAngleThreshold) // Angle >= 4.0 fallback if outside 3 to 8
        {
         level1TriggerMove = 100.0 + InpLadderStepExtraMoveRaw;      // 125.0
         stepPriceGap      = InpLadderStepIncrementRaw;              // 50.0
         baseLockSL        = InpLadderStepExtraSLRaw;                // 25.0
        }

// Calculate maximum distance price has traveled into profit beyond broker buffer
   double maxLockableDistance = 0.0;
   if(orderType == OP_BUY)
      maxLockableDistance = (Bid - stopLevel) - openPrice;
   else
      if(orderType == OP_SELL)
         maxLockableDistance = openPrice - (Ask + stopLevel);

   if(maxLockableDistance + (Point * 0.5) < level1TriggerMove)
      return 0.0;

// ladderLevel: 1 = Level 1, 2 = Level 2, 3 = Level 3, etc.
   int ladderLevel = 1 + (int)MathFloor(((maxLockableDistance - level1TriggerMove) + (Point * 0.5)) / stepPriceGap);
   outLadderLevel = ladderLevel;

// SL locked distance: Level 1 locks $25; next every step adds +$50 (Level 2 = $75, Level 3 = $125, Level 4 = $175...)
   double lockedDistance = baseLockSL + ((ladderLevel - 1) * stepPriceGap);

   double ladderSL = 0.0;
   if(orderType == OP_BUY)
      ladderSL = NormalizeDouble(openPrice + lockedDistance, Digits);
   else
      if(orderType == OP_SELL)
         ladderSL = NormalizeDouble(openPrice - lockedDistance, Digits);

   return ladderSL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateProportionalLadderSL(int orderType, double openPrice, double orderLots)
  {
   int dummyLevel = 0;
   return CalculateProportionalLadderSLWithLevel(orderType, openPrice, orderLots, dummyLevel);
  }



//+------------------------------------------------------------------+
//| SecureOneDollarProfit: Lot & Multiplier-based Profit Ladder      |
//+------------------------------------------------------------------+
void SecureOneDollarProfit()
  {
   if(SecureOneDollarProfitPerOrder <= 0.0 || GetTotalEAOrders() <= 0)
      return;

   double slGapMin = GetEffectiveMinSLModifyGap();
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      double orderLots = OrderLots();
      if(orderLots <= 0.0)
         continue;

      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();
      int ticket       = OrderTicket();
      double currentTP = OrderTakeProfit();
      double curPL     = OrderProfit() + OrderSwap() + OrderCommission();

      // Check minimum profit with multiplier ($1.00 * multiplier)
      int mult = (balancelomultipler > 0) ? balancelomultipler : 1;
      double minProfitUSD = 1.0 * mult;
      if(curPL < minProfitUSD)
         continue; // Order must reach at least $1.00 * multiplier before securing profit

      int ladderLevel = 0;
      double ladderSL = CalculateProportionalLadderSLWithLevel(type, openPrice, orderLots, ladderLevel);
      if(ladderSL <= 0.0)
         continue;

      double newSL = ladderSL;
      bool canModify = false;

      if(type == OP_BUY)
        {
         if(newSL >= openPrice && (currentSL == 0.0 || newSL >= currentSL + slGapMin))
            canModify = true;
        }
      else
         if(type == OP_SELL)
           {
            if(newSL <= openPrice && (currentSL == 0.0 || newSL <= currentSL - slGapMin))
               canModify = true;
           }

      // Modify order to lock profit at this ladder rung
      if(canModify)
        {
         ResetLastError();
         bool modified = SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, (type == OP_BUY ? clrGreen : clrTomato));

         if(modified)
           {
            double actualSL = newSL;
            if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
               actualSL = OrderStopLoss();
            if(currentSL == 0.0 || MathAbs(actualSL - currentSL) >= Point * 0.5)
              {
               double curAngLog = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
               string angModeStr = (MathAbs(curAngLog) >= InpLadderAngleRangeMin && MathAbs(curAngLog) <= InpLadderAngleRangeMax) ?
                                   StringFormat(" [EMA Ang:%.1f° (3-8 Range: L1=$200, Step=$150)]", curAngLog) :
                                   StringFormat(" [EMA Ang:%.1f°]", curAngLog);

               Print("Secured Common Profit Ladder | Level=", ladderLevel,
                     " | Ticket=", ticket,
                     " | Lots=", DoubleToString(orderLots, 2),
                     " | Type=", (type == OP_BUY ? "BUY" : "SELL"),
                     " | P/L=$", DoubleToString(curPL, 2), " >= $", DoubleToString(minProfitUSD, 2),
                     " | New SL=", DoubleToString(actualSL, Digits),
                     angModeStr);

               // USER RULE (VMULTI-1241): Half-close order (>0.01L) after every ladder SL modify from Level 1+ (any EMA angle)
               if(InpEnableSteepAngleLadderHalfClose && ladderLevel >= InpSteepAngleLadderHalfCloseStartLevel)
                 {
                  double curAngleLadder = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
                  double minLotL  = MarketInfo(Symbol(), MODE_MINLOT);
                  double lotStepL = MarketInfo(Symbol(), MODE_LOTSTEP);
                  if(minLotL <= 0.0)
                     minLotL = 0.01;
                  if(lotStepL <= 0.0)
                     lotStepL = 0.01;

                  double normLotsL = NormalizeDouble(orderLots, 2);
                  if(normLotsL > minLotL + 0.00001)
                    {
                     double halfCloseLots = MathFloor(((normLotsL * 0.5) + 0.00001) / lotStepL) * lotStepL;
                     halfCloseLots = NormalizeDouble(halfCloseLots, 2);
                     if(halfCloseLots < minLotL)
                        halfCloseLots = minLotL;

                     if(halfCloseLots >= minLotL && (normLotsL - halfCloseLots) >= (minLotL - 0.00001))
                       {
                        bool halfClosed = false;
                        double closePx = 0.0;
                        for(int attempt = 0; attempt < 3; attempt++)
                          {
                           RefreshRates();
                           closePx = (type == OP_BUY) ? Bid : Ask;
                           closePx = NormalizeDouble(closePx, Digits);
                           ResetLastError();
                           halfClosed = OrderClose(ticket, halfCloseLots, closePx, Slippage, (type == OP_BUY ? clrLimeGreen : clrOrangeRed));
                           if(halfClosed)
                              break;
                           int err = GetLastError();
                           Print(">>> [LADDER HALF-CLOSE RETRY] Ticket=#", ticket,
                                 " | Attempt=", (attempt + 1), " | Lots=", DoubleToString(halfCloseLots, 2), " | Error=", err);
                           LogEAError(err, "OrderClose(LadderHalf)", ticket, StringFormat("Attempt=%d Lots=%.2f Px=%s", (attempt + 1), halfCloseLots, DoubleToString(closePx, Digits)));
                           Sleep(100);
                          }

                        if(halfClosed)
                          {
                           double remLotsL = NormalizeDouble(normLotsL - halfCloseLots, 2);
                           Print(">>> [LADDER HALF-CLOSE] Level=", ladderLevel,
                                 " | Ticket=#", ticket,
                                 " | Type=", (type == OP_BUY ? "BUY" : "SELL"),
                                 " | Closed=", DoubleToString(halfCloseLots, 2), "L of ", DoubleToString(normLotsL, 2), "L",
                                 " | Remaining=", DoubleToString(remLotsL, 2), "L (SL=", DoubleToString(actualSL, Digits), ")",
                                 " | ClosePrice=", DoubleToString(closePx, Digits),
                                 " | EMA Angle=", DoubleToString(curAngleLadder, 1), " deg");
                           InvalidateTotalEAOrdersCache();
                          }
                       }
                    }
                 }
              }
           }
         else
           {
            Print("Failed to secure profit for Ticket: ", ticket, " | Error: ", GetLastError());
           }
        }
     }
  }
//2026.09.22 09:42:18.950   2026.08.02 09:29:21  SSLCHANEL-1 BTCUSDm,M1: 5% EQUITY LADDER TARGET ADJUSTED | Baseline=$124.88 | CurrentEquity=$103.89 | OldTarget=$131.12 | Difference=$27.23 | NewTarget=$108.89
double gbltargetEquity=0;
int gbltargetEquityCounter=0;

//+------------------------------------------------------------------+
//| DrawTargetEquityHitCircle: Draws green circle icon on chart      |
//| when target equity (gbltargetEquity) is hit.                     |
//+------------------------------------------------------------------+
void DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step)
  {
   static datetime lastHitTime = 0;
   static double   lastHitTarget = 0.0;
// Prevent duplicate drawing on same bar for identical target value
   if(time == lastHitTime && MathAbs(targetVal - lastHitTarget) < 0.01)
      return;

   string objName = PREFIX + "TARGET_EQ_HIT_" + IntegerToString((int)time) + "_" + IntegerToString((int)targetVal);

   if(ObjectFind(0, objName) < 0)
     {
      // 1. Solid Green Circle Icon (Wingdings 159, Max Width 5)
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159); // Wingdings 159: Solid circle / dot
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime); // Vibrant green color
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 5);       // Thick, highly visible
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, StringFormat("Target Equity Hit: $%.2f | Step %d | Time: %s", targetVal, step, TimeToString(TimeCurrent(), TIME_SECONDS)));

      // 2. Descriptive Label Underneath Circle
      string lblName = objName + "_LBL";
      if(ObjectFind(0, lblName) < 0)
        {
         double lblPrice = price - MathMax(30 * Point, 15.0);
         ObjectCreate(0, lblName, OBJ_TEXT, 0, time, lblPrice);
         ObjectSetString(0, lblName, OBJPROP_TEXT, StringFormat("EQ Hit #%d ($%.2f)", step, targetVal));
         ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, false);
        }

      ChartRedraw(0);
      lastHitTime = time;
      lastHitTarget = targetVal;
     }
  }

//+------------------------------------------------------------------+
//| Manage 5% / Step Ladder Target and Baseline                      |
//| Automatically resets target when account balance drops (e.g. SL) |
//| and trails target forward as profits are secured.                |
//+------------------------------------------------------------------+
void Manage5PercentLadderReset()
  {
   if(CloseOrdersAtProfitFromOpeningBalanceEveryStep <= 0.0)
      return;

   double currentBalance = AccountBalance();
   double curEquity      = AccountEquity();

// 1. Initial setup of baseline if uninitialized
   if(Ladder5PercentBaseline <= 0.0)
     {
      Ladder5PercentBaseline = currentBalance;
      gbltargetEquityCounter = 0;
     }

// 2. If no open market orders, keep baseline synchronized with current balance
   int marketOrders = GetTotalBuyOrders() + GetTotalSellOrders();
   if(marketOrders == 0)
     {
      Ladder5PercentBaseline = currentBalance;
      gbltargetEquityCounter = 0;
     }
// 3. Balance fall-down check: If an order hit negative loss SL and balance dropped below baseline
   else
      if(Ladder5PercentBaseline - currentBalance >= 0.01)
        {
         Print(
            "5% EQUITY LADDER RESET (BALANCE DROP) | OldBaseline=$", DoubleToString(Ladder5PercentBaseline, 2),
            " | NewBalance=$", DoubleToString(currentBalance, 2),
            " | DroppedBy=$", DoubleToString(Ladder5PercentBaseline - currentBalance, 2),
            " | Resetting baseline and target."
         );
         Ladder5PercentBaseline = currentBalance;
         gbltargetEquityCounter = 0;
        }
      // 4. Balance increase check: If orders closed in profit and balance increased above baseline
      else
         if(currentBalance - Ladder5PercentBaseline >= 0.01)
           {
            Print(
               "5% EQUITY LADDER BASELINE ADVANCED (PROFIT BANKED) | OldBaseline=$", DoubleToString(Ladder5PercentBaseline, 2),
               " | NewBalance=$", DoubleToString(currentBalance, 2),
               " | Gained=$", DoubleToString(currentBalance - Ladder5PercentBaseline, 2)
            );
            Ladder5PercentBaseline = currentBalance;
            gbltargetEquityCounter = 0;
           }

// 5. Calculate step amount based on multiplier
   double stepVal = (CloseOrdersAtProfitFromOpeningBalanceEveryStep > 0.0) ? CloseOrdersAtProfitFromOpeningBalanceEveryStep : 2.0;
   double stepAmount = stepVal * (balancelomultipler > 0 ? balancelomultipler : 1);

// 6. Calculate target equity based on baseline + current ladder step
   double targetEquity = Ladder5PercentBaseline + (stepAmount * (gbltargetEquityCounter + 1));
   gbltargetEquity = targetEquity;

// 7. Check if target equity reached
   if(curEquity >= targetEquity)
     {
      // USER RULE: If only ONE order is open and moving in positive profit direction,
      // PAUSE the equity profit hit process! Let the single-order profit ladder manage it.
      if(InpPauseEquityProfitHitOnSingleWinningOrder)
        {
         int mktCount = 0;
         int posCount = 0;
         int singleTkt = 0;
         double singlePL = 0.0;
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
               continue;
            if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
               continue;
            if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
               continue;
            int oType = OrderType();
            if(oType == OP_BUY || oType == OP_SELL)
              {
               mktCount++;
               double pl = OrderProfit() + OrderSwap() + OrderCommission();
               if(pl > 0.0)
                 {
                  posCount++;
                  singleTkt = OrderTicket();
                  singlePL = pl;
                 }
              }
           }
         if(mktCount == 1 && posCount == 1)
           {
            static datetime lastLogTime = 0;
            if(TimeCurrent() - lastLogTime >= 10)
              {
               lastLogTime = TimeCurrent();
               Print(">>> [TARGET EQUITY HIT PAUSED] Only 1 order open (#", singleTkt,
                     ") moving in profit direction (+$", DoubleToString(singlePL, 2),
                     "). Pausing target equity hit process to let single-order ladder run!");
              }
            return;
           }
        }

      Print(
         "5% EQUITY LADDER TARGET REACHED (Step ", (gbltargetEquityCounter + 1), ")",
         " | Equity=$", DoubleToString(curEquity, 2),
         " | Target=$", DoubleToString(targetEquity, 2),
         " | Baseline=$", DoubleToString(Ladder5PercentBaseline, 2),
         " | Securing open orders profit."
      );

      // Display circle green color icon on chart
      double iconOffset = MathMax(50 * Point, 25.0);
      DrawTargetEquityHitCircle(Time[0], Low[0] - iconOffset, targetEquity, gbltargetEquityCounter + 1);

      // Modify open orders to secure profit
      ModifyOpenOrdersToSecureProfit();

      // Advance to next ladder step
      gbltargetEquityCounter++;
      gbltargetEquity = Ladder5PercentBaseline + (stepAmount * (gbltargetEquityCounter + 1));

      InitializeDayProfitLadder();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Manage5PercentLadderResetOld()
  {
   if(Ladder5PercentBaseline <= 0.0)
     {
      Ladder5PercentBaseline = AccountBalance();
      return;
     }

   double targetEquity = Ladder5PercentBaseline * (1.0 + (CloseOrdersAtProfitFromOpeningBalanceEveryStep*balancelomultipler / 100.0));

   if(AccountEquity() >= targetEquity)
     {
      Print("5% Equity Ladder Target Reached. Closing all orders and resetting.");
      // for(int i = OrdersTotal() - 1; i >= 0; i--)
      //   {
      //    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      //      {
      //       if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      //         {
      //          int type = OrderType();
      //          if(type == OP_BUY || type == OP_SELL)
      //             SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
      //          else
      //             if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
      //                SafeOrderDelete(OrderTicket(), clrRed);
      //         }
      //      }
      //   }
      ModifyOpenOrdersToSecureProfit();


      Ladder5PercentBaseline = AccountBalance();

      InitializeDayProfitLadder();
      // DayProfitLadderTradingStopped = false;
      // OrderCreatedThisCandle = false;
      // LastOrderCandleTime = 0;
      // TradeResetThisTick = true;

      // int currentSignal = GlobalSSLDirection;
      // if(currentSignal == 1)
      //    OpenBuy();
      // else
      //    if(currentSignal == -1)
      //       OpenSell();
     }
  }


//====================================================================
// R2: ManageFlipProfitLadder
//====================================================================
//+------------------------------------------------------------------+
//| Manage Continuous EMA Flip Profit Ladder                         |
//+------------------------------------------------------------------+
void ManageFlipProfitLadder()
  {
   if(TradingHaltedUntilNextFlip || (FlipLadderStepUSD*balancelomultipler) <= 0)
      return;

// 1. Initialize the baseline if it is empty
   if(ActiveEquityBaseline <= 0.0 || OrdersTotal() == 0)
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

// === DIRECT SAFETY CHECK: HARD BASELINE FLOOR ===
   if(AccountEquity() <= ActiveEquityBaseline && GetDistanceToEMAPrice(OP_BUY, true) > 100)
     {
      Print("EMA SECURED BASELINE BREACHED | Equity ($", AccountEquity(), ") fell to or below baseline ($", ActiveEquityBaseline, ") | Halting trading.");

      DrawLadderHaltCircle(Time[0], High[0] + (50 * Point));
      TradingHaltedUntilNextFlip = true;
      LadderHaltStartTime = TimeCurrent();
      //CloseAndDeleteAllEAOrdersOnTradingStop();
      ///////////CloseAndDeleteNonEmaMatchingOrders();

      ModifyOpenOrdersToSecureProfit();


      return;
     }

// 2. Calculate continuous profit based on actual Account Equity
   double totalContinuousProfit = AccountEquity() - ActiveEquityBaseline;

// 3. Track the highest watermark profit reached
   if(totalContinuousProfit > HighestCycleProfitUSD)
     {
      HighestCycleProfitUSD = totalContinuousProfit;
     }

// 4. Calculate ladder level
//  if(FlipLadderStepUSD==0) FlipLadderStepUSD=1;

   int ladderLevel = (int)MathFloor(HighestCycleProfitUSD / (FlipLadderStepUSD*balancelomultipler));

// 5. Action taken when a new level is reached
   if(ladderLevel > HighestLadderLevelThisCycle && ladderLevel >= 1)
     {
      HighestLadderLevelThisCycle = ladderLevel;
      DrawLadderBox(Time[0], High[0] + (30 * Point), ladderLevel);

      // RATCHET UPWARD: Shift the secured baseline upward with each new level achieved
      // This locks in a higher baseline floor (e.g., 90% of current equity or stepping up by the ladder step)
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

      Print("LEVEL UP: Reached Level ", ladderLevel, " | Secured Baseline Ratcheted to: $", ActiveEquityBaseline);
     }

// 6. Manage locked profit targets for the current tier
   if(ladderLevel >= 1)
     {
      double lockedProfitTarget = (ladderLevel - FlipStepbackLevelCount) * (FlipLadderStepUSD*balancelomultipler);

      if(totalContinuousProfit <= lockedProfitTarget)
        {
         Print("EMA CONTINUOUS LADDER TRIGGERED | Peak was +$", HighestCycleProfitUSD,
               " | Retraced to lock +$", lockedProfitTarget,
               " | Halting trading and updating secured baseline.");

         ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

         DrawLadderHaltCircle(Time[0], High[0] + (50 * Point));
         TradingHaltedUntilNextFlip = true;
         LadderHaltStartTime = TimeCurrent();
         //CloseAndDeleteAllEAOrdersOnTradingStop();
         //////////////////CloseAndDeleteNonEmaMatchingOrders();
         //////////// ModifyOpenOrdersToSecureProfit();

        }
     }
  }


//====================================================================
// R3: CloseOppositeOrdersOnEmaDistance
//====================================================================

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersOnEmaDistance()
  {
   if(!EnableEmaDistanceClose || EmaCloseDistancePoints <= 0)
      return;
   if(!HasEmaFlippedSinceLoad)
      return;
   if(GetTotalEAOrders() <= 0)
      return;
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0)
      return;
   RefreshRates();
   double buyCutoff  = ema - EmaCloseDistancePoints;
   double sellCutoff = ema + EmaCloseDistancePoints;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderOpenTime() > EmaFlipTime)
         continue;

      // ADD THIS EXACT LINE TO PROTECT YOUR RECOVERY BASKETS
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int type = OrderType();
      if(type == OP_BUY && Bid < buyCutoff && EMADirection == -1)
        {
         Print("EMA DISTANCE TRIGGER: Closing PRE-FLIP BUY.");
         SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrRed);
        }
      if(type == OP_SELL && Ask > sellCutoff && EMADirection == 1)
        {
         Print("EMA DISTANCE TRIGGER: Closing PRE-FLIP SELL.");
         SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrBlue);
        }
     }
  }


//====================================================================
// R4: Live Price SL & Close Losing Orders
//====================================================================
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| ModifyOpenOrdersToCurrentPriceSL                                 |
//| Locks in profit by moving SL of all open market orders to        |
//| current live market price (with minimum stop distance buffer).   |
//| Called on DailyEquityStopUSD target hit and on each +$5 step hit.|
//+------------------------------------------------------------------+
void ModifyOpenOrdersToCurrentPriceSL(string reason = "Daily Equity Target Hit", bool forceAllOrders = false)
  {
   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   if(minDistance < 20.0)
      minDistance = 20.0;

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);
   int modifiedCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(!forceAllOrders)
        {
         // Exclude recovery orders: they have their own recovery logic
         if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
            continue;

         // Exclude FLIPBasketSupport orders: they have dedicated step-trailing SL
         if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()))
            continue;
        }

      int    tkt   = OrderTicket();
      int    oType = OrderType();
      double oOpen = OrderOpenPrice();
      double curSL = OrderStopLoss();
      double curTP = OrderTakeProfit();
      double netPL = OrderProfit() + OrderSwap() + OrderCommission();

      RefreshRates();
      curBid = MarketInfo(Symbol(), MODE_BID);
      curAsk = MarketInfo(Symbol(), MODE_ASK);

      double proposedSL   = 0.0;
      bool   shouldModify = false;

      if(oType == OP_BUY)
        {
         proposedSL = NormalizeDouble(curBid - minDistance, Digits);
         if((curBid - proposedSL) < minDistance)
            proposedSL = NormalizeDouble(curBid - minDistance, Digits);

         if(proposedSL >= curBid)
            continue;

         // For BUY: Set if no SL (0.0), or move SL forward (higher)
         if(curSL == 0.0 || (proposedSL > curSL && (proposedSL - curSL) >= Point))
           {
            shouldModify = true;
           }
        }
      else
         if(oType == OP_SELL)
           {
            proposedSL = NormalizeDouble(curAsk + minDistance, Digits);
            if((proposedSL - curAsk) < minDistance)
               proposedSL = NormalizeDouble(curAsk + minDistance, Digits);

            if(proposedSL <= curAsk)
               continue;

            // For SELL: Set if no SL (0.0), or move SL forward (lower)
            if(curSL == 0.0 || (proposedSL < curSL && (curSL - proposedSL) >= Point))
              {
               shouldModify = true;
              }
           }

      if(shouldModify && proposedSL > 0.0)
        {
         ResetLastError();
         bool modified = SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato));
         if(modified)
           {
            modifiedCount++;
            Print(StringFormat("[DAILY EQ STEP SL - %s] Ticket #%d | Type=%s | P/L=$%.2f | Old SL=%.2f -> New SL=%.2f",
                               reason, tkt, (oType == OP_BUY ? "BUY" : "SELL"), netPL, curSL, proposedSL));
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CloseLosingOrdersAndLiveSLProfitOrders                           |
//| USER RULE (V-SMALL-1022 / VMULTI-1267):                          |
//| When Reversal Protection (> $10 * Multiplier Loss) triggers:     |
//| 1. Closes ALL losing EA orders immediately at market price.      |
//| 2. Modifies ALL profitable EA orders with live stop-loss price.  |
//+------------------------------------------------------------------+
void CloseLosingOrdersAndLiveSLProfitOrders(string reason = "Max Floating Loss Reversal Protection")
  {
   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   if(minDistance < 20.0)
      minDistance = 20.0;

   int closedLossCount   = 0;
   int modifiedProfCount = 0;

// Pass 1: Close all losing EA market orders immediately at market price
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      double netPL = OrderProfit() + OrderSwap() + OrderCommission();
      if(netPL < 0.0)
        {
         int    tkt    = OrderTicket();
         double lots   = OrderLots();
         bool   closed = SafeOrderCloseMarket(tkt, lots, Slippage, (oType == OP_BUY ? clrTomato : clrOrangeRed));
         if(!closed)
           {
            RefreshRates();
            double cPx = (oType == OP_BUY) ? Bid : Ask;
            closed = OrderClose(tkt, lots, cPx, Slippage, clrTomato);
           }
         if(closed)
           {
            closedLossCount++;
            PrintFormat("[%s - CLOSE LOSS ORDER] Ticket #%d | Type=%s | Lots=%.2f | Net Loss=$%.2f",
                        reason, tkt, (oType == OP_BUY ? "BUY" : "SELL"), lots, netPL);
           }
        }
     }

// Pass 2: Modify remaining profitable EA market orders with Live Stop Loss price
   RefreshRates();
   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);

   for(int j = OrdersTotal() - 1; j >= 0; j--)
     {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      double netPL = OrderProfit() + OrderSwap() + OrderCommission();
      if(netPL >= 0.0)
        {
         int    tkt   = OrderTicket();
         double oOpen = OrderOpenPrice();
         double curSL = OrderStopLoss();
         double curTP = OrderTakeProfit();

         RefreshRates();
         curBid = MarketInfo(Symbol(), MODE_BID);
         curAsk = MarketInfo(Symbol(), MODE_ASK);

         double proposedSL   = 0.0;
         bool   shouldModify = false;

         if(oType == OP_BUY)
           {
            proposedSL = NormalizeDouble(curBid - minDistance, Digits);
            if((curBid - proposedSL) < minDistance)
               proposedSL = NormalizeDouble(curBid - minDistance, Digits);

            if(proposedSL >= curBid)
               continue;

            if(curSL == 0.0 || proposedSL > curSL || MathAbs(proposedSL - curSL) >= Point)
              {
               shouldModify = true;
              }
           }
         else
            if(oType == OP_SELL)
              {
               proposedSL = NormalizeDouble(curAsk + minDistance, Digits);
               if((proposedSL - curAsk) < minDistance)
                  proposedSL = NormalizeDouble(curAsk + minDistance, Digits);

               if(proposedSL <= curAsk)
                  continue;

               if(curSL == 0.0 || proposedSL < curSL || MathAbs(proposedSL - curSL) >= Point)
                 {
                  shouldModify = true;
                 }
              }

         if(shouldModify && proposedSL > 0.0)
           {
            ResetLastError();
            bool modified = SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato));
            if(modified)
              {
               modifiedProfCount++;
               PrintFormat("[%s - LIVE SL PROFIT ORDER] Ticket #%d | Type=%s | Profit=+$%.2f | Old SL=%.2f -> Live SL=%.2f",
                           reason, tkt, (oType == OP_BUY ? "BUY" : "SELL"), netPL, curSL, proposedSL);
              }
           }
        }
     }

   PrintFormat("[%s COMPLETE] Closed %d losing orders | Clamped %d profitable orders to Live SL",
               reason, closedLossCount, modifiedProfCount);
  }


//====================================================================
// R5: ManageOverallBasketProfit
//====================================================================
//+------------------------------------------------------------------+
//| Manage Overall Basket Profit (Requires Both Buy and Sell Orders) |
//+------------------------------------------------------------------+
void ManageOverallBasketProfit()
  {
   if(!InpEnableOverallBasketProfitModify)
      return;

   UpdateOrderCacheIfNeeded();
   if(g_orderCache.buyOrders <= 0 && g_orderCache.sellOrders <= 0)
      return;

   double totalBasketProfit = g_orderCache.buyPL + g_orderCache.sellPL;
   double targetProfit = (InpOverallBasketProfitTargetUSD > 0.0 ? InpOverallBasketProfitTargetUSD : 1.0) * balancelomultipler;

   if(totalBasketProfit > targetProfit)
     {
      RefreshRates();
      double minStopDist = GetRequiredStopDistance();
      double gap = (InpOverallBasketSLGapUSD > 0.0) ? InpOverallBasketSLGapUSD : 150.0;

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
            continue;

         int tkt = OrderTicket();
         int oType = OrderType();
         double oOpen = OrderOpenPrice();
         double curSL = OrderStopLoss();
         double curTP = OrderTakeProfit();

         double curPL = OrderProfit() + OrderSwap() + OrderCommission();
         double proposedSL = GetTrendAwareStopLoss(oType, gap, curSL, "Method 5", curPL, oOpen);

         double rawProfitGap = (oType == OP_BUY) ? (Bid - oOpen) : (oOpen - Ask);
         bool isSteepAngle = (InpEnableDoubleSlGapOnSteepAngle && MathAbs(GlobalEmaAngle30) > InpDoubleSlGapAngle);
         bool isProfitGapReached = (rawProfitGap > InpDoubleSlMinProfitGapRaw);

         // Clamp proposedSL to openPrice or breathing SL if profit gap reached (USER RULE: VMULTI-1096 & VMULTI-1105)
         double beFloorM5 = GetEmaAngleBreakevenBreathingSL(oType, oOpen, oOpen);
         if(isProfitGapReached)
           {
            if(oType == OP_BUY && proposedSL < beFloorM5)
               proposedSL = beFloorM5;
            else
               if(oType == OP_SELL && proposedSL > beFloorM5)
                  proposedSL = beFloorM5;
           }

         bool allowBreathingWidening = (isSteepAngle && isProfitGapReached && (oType == OP_BUY ? proposedSL >= beFloorM5 : proposedSL <= beFloorM5));

         if(oType == OP_BUY)
           {
            if(proposedSL < Bid && (curSL == 0.0 || (proposedSL > curSL && (proposedSL - curSL) >= MinimumSLModifyGapRaw) ||
                                    (allowBreathingWidening && MathAbs(proposedSL - curSL) >= MinimumSLModifyGapRaw)))
              {
               if(SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, clrLimeGreen, "Method 5"))
                 {
                  int totalBasketOrders = g_orderCache.buyOrders + g_orderCache.sellOrders;
                  RecordMethodModification(tkt, 5, totalBasketOrders, totalBasketProfit);
                 }
              }
           }
         else
            if(oType == OP_SELL)
              {
               if(proposedSL > Ask && (curSL == 0.0 || (proposedSL < curSL && (curSL - proposedSL) >= MinimumSLModifyGapRaw) ||
                                       (allowBreathingWidening && MathAbs(proposedSL - curSL) >= MinimumSLModifyGapRaw)))
                 {
                  if(SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, clrTomato, "Method 5"))
                    {
                     int totalBasketOrders = g_orderCache.buyOrders + g_orderCache.sellOrders;
                     RecordMethodModification(tkt, 5, totalBasketOrders, totalBasketProfit);
                    }
                 }
              }
        }
     }
  }


//====================================================================
// R6: CloseOpposite Orders
//====================================================================
//+------------------------------------------------------------------+
//| Close opposite orders created before signal change with loss > $2 |
//+------------------------------------------------------------------+
void CloseOppositeLosingOrdersBeforeSignal(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// Loop through all open trades
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // 1. Check if the open order is directly opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      // 2. Check if the order was created before the last EMA flip / signal change
      bool isBeforeSignalChange = (EmaFlipTime > 0 && OrderOpenTime() < EmaFlipTime);

      // 3. Calculate loss threshold: $2.00 per 0.01 lot step (scaled by lot size)
      double lossThreshold = -2.0 * (lots / 0.01);
      bool isLossExceeded = (orderPL <= lossThreshold);

      // If all conditions match, close the losing opposite order immediately
      if(isOppositeSignal && isBeforeSignalChange && isLossExceeded)
        {
         Print("OPPOSITE LOSING ORDER CLOSED: Ticket #", ticket,
               " | Type: ", GetOrderTypeText(orderType),
               " | Loss: $", DoubleToString(orderPL, 2),
               " | Threshold: $", DoubleToString(lossThreshold, 2));

         SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));
        }
     }
  }
//+------------------------------------------------------------------+
//| Standalone: Close profitable opposite orders on SSL signal       |
//+------------------------------------------------------------------+
void CloseOppositeProfitableOrdersIndependent(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// Loop through all open trades
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // Calculate profit threshold: $0.25 per 0.01 lot step
      double profitThreshold = 0.25 * (lots / 0.01);

      // Check if the open order is directly opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      // If it's an opposite signal and has reached or exceeded the profit threshold, close it immediately
      if(isOppositeSignal && orderPL >= profitThreshold)
        {
         Print("INDEPENDENT CLOSE TRIGGERED: Ticket #", ticket,
               " | Type: ", GetOrderTypeText(orderType),
               " | Profit: $", DoubleToString(orderPL, 2),
               " | Threshold: $", DoubleToString(profitThreshold, 2));

         // SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));

         double targetSL = Bid - (15 * Point); // Example for a Buy order
         ModifyOrderStopLossByTicket(ticket, targetSL);
        }
     }
  }


//====================================================================
// R7: CheckEquityBalanceProfitTarget
//====================================================================

//+------------------------------------------------------------------+
//| Close all orders if Equity exceeds Balance by $1.00 or more     |
//+------------------------------------------------------------------+
void CheckEquityBalanceProfitTarget()
  {
   if(!InpEnableEquityBalanceProfitTarget)
      return; // DISABLED: Manage5PercentLadderReset handles equity targets cleanly

   double accountBalance = AccountBalance();
   double accountEquity  = AccountEquity();
   double targetProfit   = accountBalance + (Ladder1ProfitUSD * 5);

// Check if Equity has reached the protection target
   if(accountEquity >= targetProfit)
     {
      Print("Equity Target Reached! Balance: $", DoubleToString(accountBalance, 2),
            " | Equity: $", DoubleToString(accountEquity, 2), ". Modifying open orders to lock in profit and continuing trading.");

      // Modify open positions to lock in profit instead of closing them
      ModifyOpenOrdersToSecureProfit();
     }
  }


//====================================================================
// R8: CloseAll Buy/Sell/Spike & Spike Ladder & Basket Profit
//====================================================================
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CloseAllOpenBuyOrders: Closes all open BUY market orders and     |
//| deletes any pending BUY stop/limit orders.                       |
//+------------------------------------------------------------------+
void CloseAllOpenBuyOrders(string reason = "")
  {
   static datetime lastBuyCloseLog = 0;
   if(TimeCurrent() - lastBuyCloseLog >= 5)
     {
      Print(">>> [BASKET CLOSE] Securing/Closing ALL open BUY orders (Reason: ", reason, ")...");
      lastBuyCloseLog = TimeCurrent();
     }
   int buyTickets[100];
   double buyLotsArr[100];
   int buyCount = 0;
   int pendingTickets[100];
   int pendingCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType == OP_BUY)
        {
         if(buyCount < 100)
           {
            buyTickets[buyCount]   = OrderTicket();
            buyLotsArr[buyCount]   = OrderLots();
            buyCount++;
           }
        }
      else
         if(oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
           {
            if(pendingCount < 100)
              {
               pendingTickets[pendingCount] = OrderTicket();
               pendingCount++;
              }
           }
     }

   for(int m = 0; m < buyCount; m++)
     {
      int tkt = buyTickets[m];
      double lts = buyLotsArr[m];

      if(ServerRecoveryPending || !IsConnected())
        {
         SafeOrderCloseMarket(tkt, lts, Slippage, clrRed);
         continue;
        }

      // Protect recovery orders: never close recovery orders via regular basket close
      if(IsAnyRecoveryOrder(tkt))
         continue;
      RecordOrderCloseReason(tkt, (reason != "" ? reason : "BASKET_PROFIT_CLOSE"));
      SafeOrderClose(tkt, lts, OP_BUY, Slippage, clrRed);
     }

   for(int p = 0; p < pendingCount; p++)
     {
      SafeOrderDelete(pendingTickets[p], clrYellow);
     }

   InvalidateTotalEAOrdersCache();
   InitializeFLIPBasketSupportTracking();
  }

//+------------------------------------------------------------------+
//| CloseAllOpenSellOrders: Closes all open SELL market orders and    |
//| deletes any pending SELL stop/limit orders.                      |
//+------------------------------------------------------------------+
void CloseAllOpenSellOrders(string reason = "")
  {
   static datetime lastSellCloseLog = 0;
   if(TimeCurrent() - lastSellCloseLog >= 5)
     {
      Print(">>> [BASKET CLOSE] Securing/Closing ALL open SELL orders (Reason: ", reason, ")...");
      lastSellCloseLog = TimeCurrent();
     }
   int sellTickets[100];
   double sellLotsArr[100];
   int sellCount = 0;
   int pendingTickets[100];
   int pendingCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType == OP_SELL)
        {
         if(sellCount < 100)
           {
            sellTickets[sellCount] = OrderTicket();
            sellLotsArr[sellCount] = OrderLots();
            sellCount++;
           }
        }
      else
         if(oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
           {
            if(pendingCount < 100)
              {
               pendingTickets[pendingCount] = OrderTicket();
               pendingCount++;
              }
           }
     }

   for(int m = 0; m < sellCount; m++)
     {
      int tkt = sellTickets[m];
      double lts = sellLotsArr[m];

      if(ServerRecoveryPending || !IsConnected())
        {
         SafeOrderCloseMarket(tkt, lts, Slippage, clrBlue);
         continue;
        }

      // Protect recovery orders: never close recovery orders via regular basket close
      if(IsAnyRecoveryOrder(tkt))
         continue;
      RecordOrderCloseReason(tkt, (reason != "" ? reason : "BASKET_PROFIT_CLOSE"));
      SafeOrderClose(tkt, lts, OP_SELL, Slippage, clrBlue);
     }

   for(int p = 0; p < pendingCount; p++)
     {
      SafeOrderDelete(pendingTickets[p], clrYellow);
     }

   InvalidateTotalEAOrdersCache();
   InitializeFLIPBasketSupportTracking();
  }

//+------------------------------------------------------------------+
//| CloseAllOpenSpikeOrders: Closes open market Spike orders         |
//+------------------------------------------------------------------+
void CloseAllOpenSpikeOrders(int orderType, string reason = "")
  {
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != orderType)
         continue;

      string cmt = OrderComment();
      if(StringFind(cmt, "SPIKE") < 0)
         continue;

      RecordOrderCloseReason(OrderTicket(), (reason != "" ? reason : "SPIKE_LADDER_50PCT_CLOSE"));
      SafeOrderCloseMarket(OrderTicket(), OrderLots(), Slippage, (orderType == OP_BUY ? clrLimeGreen : clrTomato));
     }
   InvalidateTotalEAOrdersCache();
  }

//+------------------------------------------------------------------+
//| ManageSpikeProfitLadder: $5 Step Profit Ladder with 50% Protect  |
//| - Tracks peak floating profit for Spike BUY and SELL buckets     |
//| - When peak profit >= $5.00 (InpSpikeLadderStepUSD):             |
//|   a) Protects 50% of peak profit (InpSpikeLadderProtectPct)      |
//|   b) Modifies all spike orders' StopLoss forward with live price |
//|   c) Closes spike orders immediately if profit retraces to 50%   |
//+------------------------------------------------------------------+
void ManageSpikeProfitLadder()
  {
   if(!InpEnableSpikeProfitLadder)
      return;

   RefreshRates();

   double mult = (InpSpikeLadderUseMultiplier && balancelomultipler > 0) ? (double)balancelomultipler : 1.0;
   double minToProtect = InpSpikeMinProfitToProtectUSD * mult;
   double stepUSD      = InpSpikeLadderStepUSD * mult;
   if(minToProtect <= 0.0)
      minToProtect = 1.0 * mult;

   int    spikeBuyCount     = 0;
   double spikeBuyLots      = 0.0;
   double spikeBuyPL        = 0.0;
   int    spikeBuyTickets[];
   double spikeBuyOpenPrices[];
   double spikeBuyLotsArr[];
   double spikeBuySLs[];
   double spikeBuyTPs[];

   int    spikeSellCount    = 0;
   double spikeSellLots     = 0.0;
   double spikeSellPL       = 0.0;
   int    spikeSellTickets[];
   double spikeSellOpenPrices[];
   double spikeSellLotsArr[];
   double spikeSellSLs[];
   double spikeSellTPs[];

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string cmt = OrderComment();
      if(StringFind(cmt, "SPIKE") < 0)
         continue;

      int oType = OrderType();
      double netPL = OrderProfit() + OrderSwap() + OrderCommission();

      if(oType == OP_BUY)
        {
         int idx = ArraySize(spikeBuyTickets);
         ArrayResize(spikeBuyTickets, idx + 1);
         ArrayResize(spikeBuyOpenPrices, idx + 1);
         ArrayResize(spikeBuyLotsArr, idx + 1);
         ArrayResize(spikeBuySLs, idx + 1);
         ArrayResize(spikeBuyTPs, idx + 1);

         spikeBuyTickets[idx]    = OrderTicket();
         spikeBuyOpenPrices[idx] = OrderOpenPrice();
         spikeBuyLotsArr[idx]    = OrderLots();
         spikeBuySLs[idx]        = OrderStopLoss();
         spikeBuyTPs[idx]        = OrderTakeProfit();

         spikeBuyCount++;
         spikeBuyLots += OrderLots();
         spikeBuyPL   += netPL;
        }
      else if(oType == OP_SELL)
        {
         int idx = ArraySize(spikeSellTickets);
         ArrayResize(spikeSellTickets, idx + 1);
         ArrayResize(spikeSellOpenPrices, idx + 1);
         ArrayResize(spikeSellLotsArr, idx + 1);
         ArrayResize(spikeSellSLs, idx + 1);
         ArrayResize(spikeSellTPs, idx + 1);

         spikeSellTickets[idx]    = OrderTicket();
         spikeSellOpenPrices[idx] = OrderOpenPrice();
         spikeSellLotsArr[idx]    = OrderLots();
         spikeSellSLs[idx]        = OrderStopLoss();
         spikeSellTPs[idx]        = OrderTakeProfit();

         spikeSellCount++;
         spikeSellLots += OrderLots();
         spikeSellPL   += netPL;
        }
     }

   // 1. Manage BUY Spike Bucket
   if(spikeBuyCount == 0)
     {
      g_spikeBuyBucketPeakPL      = 0.0;
      g_spikeBuyBucketLadderLevel = 0;
     }
   else
     {
      // Record highest spike bucket profit on every incoming tick
      if(spikeBuyPL > g_spikeBuyBucketPeakPL)
         g_spikeBuyBucketPeakPL = spikeBuyPL;

      // START LOGIC: Minimum profit is $1Xmul of SPIKE BUY basket
      if(g_spikeBuyBucketPeakPL >= minToProtect)
        {
         int curLevel = (stepUSD > 0.0) ? (int)MathFloor(g_spikeBuyBucketPeakPL / stepUSD) : 1;
         if(curLevel > g_spikeBuyBucketLadderLevel)
           {
            g_spikeBuyBucketLadderLevel = curLevel;
            PrintFormat(">>> [SPIKE BUY LADDER LEVEL %d] Peak=$%.2f >= Step $%.2f (Min=$%.2f) | Floating PL=$%.2f (Lots=%.2fL, Orders=%d, Mult=%.0fX)",
                        curLevel, g_spikeBuyBucketPeakPL, curLevel * stepUSD, minToProtect, spikeBuyPL, spikeBuyLots, spikeBuyCount, mult);
           }

         double protectFloorPL = g_spikeBuyBucketPeakPL * (InpSpikeLadderProtectPct / 100.0);

         // A. REVERSAL CLOSE: Close spike orders if profit retraced to or below 50% floor
         if(spikeBuyPL <= protectFloorPL)
           {
            string closeReason = StringFormat("Spike BUY Ladder 50%% Retrace Hit: Peak=$%.2f, Closed=$%.2f <= Floor=$%.2f (Min=$%.2f, Lvl %d)",
                                              g_spikeBuyBucketPeakPL, spikeBuyPL, protectFloorPL, minToProtect, curLevel);
            Print(">>> [SPIKE BUCKET CLOSE - BUY] ", closeReason);
            CloseAllOpenSpikeOrders(OP_BUY, closeReason);
            CleanupStaleSpikePendingOrders(OP_BUYSTOP, 0.0);
            g_spikeBuyBucketPeakPL      = 0.0;
            g_spikeBuyBucketLadderLevel = 0;
           }
         // B. LIVE TRAILING SL: Adjust StopLoss forward based on live price
         else
           {
            double tickVal = MarketInfo(Symbol(), MODE_TICKVALUE);
            double tickSz  = MarketInfo(Symbol(), MODE_TICKSIZE);
            double pointPerDollar = 1.0;
            if(tickVal > 0.0 && tickSz > 0.0)
               pointPerDollar = tickVal / tickSz;

            double dollarPerUnit = spikeBuyLots * pointPerDollar;
            if(dollarPerUnit > 0.0)
              {
               double priceBuffer = (spikeBuyPL - protectFloorPL) / dollarPerUnit;
               double targetSL = NormalizeDouble(Bid - priceBuffer, Digits);
               double minStop = GetRequiredStopDistance();
               if(targetSL > Bid - minStop)
                  targetSL = NormalizeDouble(Bid - minStop, Digits);

               double minModGap = GetEffectiveMinSLModifyGap();

               for(int b = 0; b < spikeBuyCount; b++)
                 {
                  int tkt = spikeBuyTickets[b];
                  double curSL = spikeBuySLs[b];
                  double oOpen = spikeBuyOpenPrices[b];
                  double curTP = spikeBuyTPs[b];

                  if(targetSL > 0.0 && (curSL == 0.0 || targetSL >= curSL + minModGap))
                    {
                     SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrLimeGreen, "SpikeLadder50PctSL");
                    }
                 }
              }
           }
        }
     }

   // 2. Manage SELL Spike Bucket
   if(spikeSellCount == 0)
     {
      g_spikeSellBucketPeakPL      = 0.0;
      g_spikeSellBucketLadderLevel = 0;
     }
   else
     {
      // Record highest spike bucket profit on every incoming tick
      if(spikeSellPL > g_spikeSellBucketPeakPL)
         g_spikeSellBucketPeakPL = spikeSellPL;

      // START LOGIC: Minimum profit is $1Xmul of SPIKE SELL basket
      if(g_spikeSellBucketPeakPL >= minToProtect)
        {
         int curLevel = (stepUSD > 0.0) ? (int)MathFloor(g_spikeSellBucketPeakPL / stepUSD) : 1;
         if(curLevel > g_spikeSellBucketLadderLevel)
           {
            g_spikeSellBucketLadderLevel = curLevel;
            PrintFormat(">>> [SPIKE SELL LADDER LEVEL %d] Peak=$%.2f >= Step $%.2f (Min=$%.2f) | Floating PL=$%.2f (Lots=%.2fL, Orders=%d, Mult=%.0fX)",
                        curLevel, g_spikeSellBucketPeakPL, curLevel * stepUSD, minToProtect, spikeSellPL, spikeSellLots, spikeSellCount, mult);
           }

         double protectFloorPL = g_spikeSellBucketPeakPL * (InpSpikeLadderProtectPct / 100.0);

         // A. REVERSAL CLOSE: Close spike orders if profit retraced to or below 50% floor
         if(spikeSellPL <= protectFloorPL)
           {
            string closeReason = StringFormat("Spike SELL Ladder 50%% Retrace Hit: Peak=$%.2f, Closed=$%.2f <= Floor=$%.2f (Min=$%.2f, Lvl %d)",
                                              g_spikeSellBucketPeakPL, spikeSellPL, protectFloorPL, minToProtect, curLevel);
            Print(">>> [SPIKE BUCKET CLOSE - SELL] ", closeReason);
            CloseAllOpenSpikeOrders(OP_SELL, closeReason);
            CleanupStaleSpikePendingOrders(OP_SELLSTOP, 0.0);
            g_spikeSellBucketPeakPL      = 0.0;
            g_spikeSellBucketLadderLevel = 0;
           }
         // B. LIVE TRAILING SL: Adjust StopLoss forward based on live price
         else
           {
            double tickVal = MarketInfo(Symbol(), MODE_TICKVALUE);
            double tickSz  = MarketInfo(Symbol(), MODE_TICKSIZE);
            double pointPerDollar = 1.0;
            if(tickVal > 0.0 && tickSz > 0.0)
               pointPerDollar = tickVal / tickSz;

            double dollarPerUnit = spikeSellLots * pointPerDollar;
            if(dollarPerUnit > 0.0)
              {
               double priceBuffer = (spikeSellPL - protectFloorPL) / dollarPerUnit;
               double targetSL = NormalizeDouble(Ask + priceBuffer, Digits);
               double minStop = GetRequiredStopDistance();
               if(targetSL < Ask + minStop)
                  targetSL = NormalizeDouble(Ask + minStop, Digits);

               double minModGap = GetEffectiveMinSLModifyGap();

               for(int s = 0; s < spikeSellCount; s++)
                 {
                  int tkt = spikeSellTickets[s];
                  double curSL = spikeSellSLs[s];
                  double oOpen = spikeSellOpenPrices[s];
                  double curTP = spikeSellTPs[s];

                  if(targetSL > 0.0 && (curSL == 0.0 || targetSL <= curSL - minModGap))
                    {
                     SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrTomato, "SpikeLadder50PctSL");
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckBasketProfitClose:                                          |
//| 1. If Buy basket total profit >  * multiplier (and Flip order  |
//|    is in profit >= 0 if present) -> Close all open BUY orders    |
//| 2. If Sell basket total profit >  * multiplier (and Flip order |
//|    is in profit >= 0 if present) -> Close all open SELL orders   |
//| 3. If Total Net profit (BUY + SELL) >  * multiplier ->         |
//|    Close ALL open orders (BUY and SELL)                          |
//+------------------------------------------------------------------+
void CheckBasketProfitClose()
  {
   if(!InpEnableBasketProfitClose)
      return;
   if(!EAStartupComplete)
      return;

   double targetProfit = GetDynamicBasketProfitTarget() * (balancelomultipler > 0 ? balancelomultipler : 1);

   double buyPL = 0.0;
   double sellPL = 0.0;
   int buyMarketCount = 0;
   int sellMarketCount = 0;
   int buySupportCount = 0;
   int sellSupportCount = 0;
   double buySupportPL = 0.0;
   double sellSupportPL = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;
      // EXCLUDE RECOVERY ORDERS: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      bool isSupport = IsFLIPBasketSupportOrder(OrderTicket(), OrderComment());

      if(oType == OP_BUY)
        {
         buyMarketCount++;
         buyPL += pl;
         if(isSupport)
           {
            buySupportCount++;
            buySupportPL += pl;
           }
        }
      else
         if(oType == OP_SELL)
           {
            sellMarketCount++;
            sellPL += pl;
            if(isSupport)
              {
               sellSupportCount++;
               sellSupportPL += pl;
              }
           }
     }

// (Peak basket P/L tracking moved to global g_buyBasketPeakPL and g_sellBasketPeakPL for fresh start on OnInit)
   int totalMarketOrders = buyMarketCount + sellMarketCount;
   double netPL = buyPL + sellPL;
   int mult = (balancelomultipler > 0 ? balancelomultipler : 1);

// 1. Overall Total Net Profit Target: If Net Profit across BUY + SELL > targetProfit -> Close ALL open orders
   if(totalMarketOrders > 0 && netPL > targetProfit)
     {
      string netReason = StringFormat("Total Net Profit Hit: $%.2f > Target $%.2f (%.1f * %d)", netPL, targetProfit, InpBasketProfitTargetUSD, mult);
      Print(">>> [BASKET PROFIT CLOSE - ALL] ", netReason);
      CloseAllOpenBuyOrders(netReason);
      CloseAllOpenSellOrders(netReason);
      g_buyBasketPeakPL = 0.0;
      g_sellBasketPeakPL = 0.0;
      return;
     }

// 2. Buy Basket Target & Micro-Trailing ( -  Sweet Spot)
   if(buyMarketCount == 0 || buyPL <= 0.0)
      g_buyBasketPeakPL = 0.0;

   if(buyMarketCount > 0 && buyPL >= targetProfit)
     {
      bool buyFlipConditionMet = (buySupportCount == 0 || buySupportPL >= 0.0);
      if(buyFlipConditionMet)
        {
         if(InpEnableBasketMicroTrailing)
           {
            g_buyBasketPeakPL = MathMax(g_buyBasketPeakPL, buyPL);
            double trailFloor = g_buyBasketPeakPL - (InpBasketTrailStepUSD * mult);
            if(buyPL <= trailFloor || buyPL >= 5.0 * mult)
              {
               string buyReason = StringFormat("BUY Basket Micro-Trail Hit: Peak=$%.2f, Closed=$%.2f >= Floor=$%.2f (Tgt $%.2f)",
                                               g_buyBasketPeakPL, buyPL, trailFloor, targetProfit);
               Print(">>> [BASKET PROFIT CLOSE - BUY] ", buyReason);
               CloseAllOpenBuyOrders(buyReason);
               g_buyBasketPeakPL = 0.0;
              }
           }
         else
           {
            string buyReason = StringFormat("BUY Basket Profit Hit: $%.2f > Target $%.2f (%.1f * %d) | Buy Support PL=$%.2f",
                                            buyPL, targetProfit, InpBasketProfitTargetUSD, mult, buySupportPL);
            Print(">>> [BASKET PROFIT CLOSE - BUY] ", buyReason);
            CloseAllOpenBuyOrders(buyReason);
           }
        }
     }

// 3. Sell Basket Target & Micro-Trailing ( -  Sweet Spot)
   if(sellMarketCount == 0 || sellPL <= 0.0)
      g_sellBasketPeakPL = 0.0;

   if(sellMarketCount > 0 && sellPL >= targetProfit)
     {
      bool sellFlipConditionMet = (sellSupportCount == 0 || sellSupportPL >= 0.0);
      if(sellFlipConditionMet)
        {
         if(InpEnableBasketMicroTrailing)
           {
            g_sellBasketPeakPL = MathMax(g_sellBasketPeakPL, sellPL);
            double trailFloor = g_sellBasketPeakPL - (InpBasketTrailStepUSD * mult);
            if(sellPL <= trailFloor || sellPL >= 5.0 * mult)
              {
               string sellReason = StringFormat("SELL Basket Micro-Trail Hit: Peak=$%.2f, Closed=$%.2f >= Floor=$%.2f (Tgt $%.2f)",
                                                g_sellBasketPeakPL, sellPL, trailFloor, targetProfit);
               Print(">>> [BASKET PROFIT CLOSE - SELL] ", sellReason);
               CloseAllOpenSellOrders(sellReason);
               g_sellBasketPeakPL = 0.0;
              }
           }
         else
           {
            string sellReason = StringFormat("SELL Basket Profit Hit: $%.2f > Target $%.2f (%.1f * %d) | Sell Support PL=$%.2f",
                                             sellPL, targetProfit, InpBasketProfitTargetUSD, mult, sellSupportPL);
            Print(">>> [BASKET PROFIT CLOSE - SELL] ", sellReason);
            CloseAllOpenSellOrders(sellReason);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyOpenOrdersToSecureProfitNEW()
  {

   return ;
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Current symbol only
      if(OrderSymbol() != Symbol())
         continue;

      // Current EA only
      if(OrderMagicNumber() != MagicNumber)
         continue;

      int ticket = OrderTicket();
      int type   = OrderType();

      // Only BUY / SELL
      if(type != OP_BUY && type != OP_SELL)
         continue;

      RefreshRates();

      double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();

      //==============================================================
      // LOSS ORDER → WIDEN SL BY $50 GAP (1-Min Cooldown)
      //==============================================================
      //==============================================================
      // LOSS ORDER → WIDEN SL BY $50 GAP FROM CURRENT TICK PRICE
      //==============================================================
      if(orderProfit < 0.0)
        {
         double gapPrice =105;// 50.0*5;//ordermodifywith50
         double currentSL = OrderStopLoss();
         double newSL = 0.0;

         // 1. Calculate the distance from the current live price to the existing Stop Loss
         double distanceToSL = 0.0;
         if(type == OP_BUY)
            distanceToSL = Bid - currentSL;
         else
            if(type == OP_SELL)
               distanceToSL = currentSL - Ask;

         // 2. FILTER: If an SL is already set and its distance from the live price is $50 or less, IGNORE IT.
         // This ensures it never modifies an order that has already been adjusted to the $50 gap.
         if(currentSL != 0.0 && distanceToSL <= gapPrice+10)
           {
            continue; // Skip this order
           }

         // 3. Calculate new SL based strictly on the CURRENT LIVE TICK PRICE
         if(type == OP_BUY)
           {
            newSL = Bid - gapPrice;
           }
         else // OP_SELL
           {
            newSL = Ask + gapPrice;
           }

         newSL = NormalizeDouble(newSL, Digits);

         // 4. Modify the order
         if(MathAbs(newSL - currentSL) > Point / 2.0)
           {
            ResetLastError();
            bool modified =SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);

            if(modified)
              {
               Print("LOSS ORDER PROTECTED",
                     " | Ticket=", ticket,
                     " | Type=", type == OP_BUY ? "BUY" : "SELL",
                     " | Old SL=", DoubleToString(currentSL, Digits),
                     " | New SL=", DoubleToString(newSL, Digits),
                     " | Gap Set to $50 from Current Price");
              }
            else
              {
               Print("FAILED TO MODIFY LOSS ORDER SL",
                     " | Ticket=", ticket,
                     " | Error=", GetLastError());
              }
           }

         continue; // Move to the next order
        }

      //==============================================================
      // PROFIT ORDER → MODIFY SL
      //==============================================================
      if(orderProfit > 0.0)
        {

         RefreshRates();

         double openPrice = OrderOpenPrice();
         double currentSL = OrderStopLoss();
         double currentTP = OrderTakeProfit();

         double newSL = 0.0;
         bool modify = false;

         // BUY
         if(type == OP_BUY)
           {
            newSL = Bid - (20 * Point);
            newSL = NormalizeDouble(newSL, Digits);

            // SL must secure profit
            if(newSL > openPrice)
              {
               // Only move SL forward
               if(currentSL == 0.0 || newSL > currentSL)
                  modify = true;
              }
           }

         // SELL
         else
            if(type == OP_SELL)
              {
               newSL = Ask + (20 * Point);
               newSL = NormalizeDouble(newSL, Digits);

               // SL must secure profit
               if(newSL < openPrice)
                 {
                  // Only move SL forward
                  if(currentSL == 0.0 || newSL < currentSL)
                     modify = true;
                 }
              }

         if(modify)
           {
            ResetLastError();

            bool modified =SafeOrderModify(
                              ticket,
                              openPrice,
                              newSL,
                              currentTP,
                              0,
                              type == OP_BUY ? clrGreen : clrRed
                           );

            if(modified)
              {
               Print(
                  "PROFIT ORDER SL MODIFIED",
                  " | Ticket=", ticket,
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | Profit=$", DoubleToString(orderProfit, 2),
                  " | NewSL=", DoubleToString(newSL, Digits)
               );
              }
            else
              {
               Print(
                  "FAILED TO MODIFY PROFIT ORDER",
                  " | Ticket=", ticket,
                  " | Error=", GetLastError()
               );
              }
           }
        }
     }


   ForceDeleteAllPendingOrders();

   CloseAllOrders();

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyOpenOrdersToSecureProfit()
  {
   RefreshRates();

// USER RULE: If only ONE order is open and moving in positive profit direction,
// PAUSE the equity profit hit process! Let the single-order profit ladder manage it.
   if(InpPauseEquityProfitHitOnSingleWinningOrder)
     {
      int mktCount = 0;
      int posCount = 0;
      int singleTkt = 0;
      double singlePL = 0.0;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
            continue;
         int oType = OrderType();
         if(oType == OP_BUY || oType == OP_SELL)
           {
            mktCount++;
            double pl = OrderProfit() + OrderSwap() + OrderCommission();
            if(pl > 0.0)
              {
               posCount++;
               singleTkt = OrderTicket();
               singlePL = pl;
              }
           }
        }
      if(mktCount == 1 && posCount == 1)
        {
         Print(">>> [MODIFY TO SECURE PROFIT PAUSED] Only 1 order open (#", singleTkt,
               ") moving in profit direction (+$", DoubleToString(singlePL, 2),
               "). Skipping target equity SL modification to let single-order ladder run!");
         return;
        }
     }

// USER RULE:
// A. For Profitable Orders (netPL > 0): Keep same logic (Proportional Ladder / Lock Profit)
// B. For Losing Orders (netPL < 0):     Close immediately on Equity Target Hit
   double trailingBufferUSD  = (InpTargetEquityProfitTrailingGapUSD > 0.0) ? InpTargetEquityProfitTrailingGapUSD : 102.0;
   double lossRecoveryGapUSD = (InpTargetEquityLossTighteningGapUSD > 0.0) ? InpTargetEquityLossTighteningGapUSD : 20.0;

   double minStopDist = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   if(minStopDist < 10.0 * Point)
      minStopDist = 10.0 * Point;

   int    losingTickets[];
   double losingLots[];
   double losingPLs[];
   int    losingTypes[];
   ArrayResize(losingTickets, 0);
   ArrayResize(losingLots, 0);
   ArrayResize(losingPLs, 0);
   ArrayResize(losingTypes, 0);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int ticket       = OrderTicket();
      int type         = OrderType();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentTP = OrderTakeProfit();
      double netPL     = OrderProfit() + OrderSwap() + OrderCommission();

      // ==============================================================
      // 1. PROFITABLE ORDERS: Use Common Proportional Profit Ladder (SAME LOGIC)
      // ==============================================================
      if(netPL > 0.0)
        {
         double ladderSL = CalculateProportionalLadderSL(type, openPrice, OrderLots());
         double newSL = 0.0;
         if(ladderSL > 0.0)
            newSL = ladderSL;
         else
            newSL = GetEmaAngleBreakevenBreathingSL(type, openPrice, openPrice); // Level 1 / Breakeven with breathing room

         double beFloorETH = GetEmaAngleBreakevenBreathingSL(type, openPrice, openPrice);
         double slGapMinETH = GetEffectiveMinSLModifyGap();
         if(type == OP_BUY)
           {
            if(newSL >= beFloorETH && (currentSL == 0.0 || newSL >= currentSL + slGapMinETH))
               SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrGreen);
           }
         else
            if(type == OP_SELL)
              {
               if(newSL <= beFloorETH && (currentSL == 0.0 || newSL <= currentSL - slGapMinETH))
                  SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrRed);
              }
         // Register winning order as secured by Equity Target Hit
         RegisterEquityHitSecuredOrder(ticket);
        }

      // ==============================================================
      // 2. LOSING ORDERS: Queue for immediate close or tighten
      // ==============================================================
      else
         if(netPL < 0.0)
           {
            if(InpCloseLosingOrdersOnEquityTargetHit)
              {
               int lIdx = ArraySize(losingTickets);
               ArrayResize(losingTickets, lIdx + 1);
               ArrayResize(losingLots, lIdx + 1);
               ArrayResize(losingPLs, lIdx + 1);
               ArrayResize(losingTypes, lIdx + 1);
               losingTickets[lIdx] = ticket;
               losingLots[lIdx]    = OrderLots();
               losingPLs[lIdx]     = netPL;
               losingTypes[lIdx]   = type;
              }
            else
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
              }
           }
     }

// ==============================================================
// CLOSE ALL QUEUED LOSING ORDERS ON EQUITY TARGET HIT
// ==============================================================
   if(InpCloseLosingOrdersOnEquityTargetHit && ArraySize(losingTickets) > 0)
     {
      for(int k = 0; k < ArraySize(losingTickets); k++)
        {
         int lTkt = losingTickets[k];
         double lLot = losingLots[k];
         double lPL = losingPLs[k];
         int lType = losingTypes[k];

         PrintFormat(">>> [EQUITY TARGET HIT - CLOSE LOSING ORDER] Closing losing Order #%d (Type=%s, Lots=%.2f, P/L=$-%.2f). Equity target reached!",
                     lTkt, (lType == OP_BUY ? "BUY" : "SELL"), lLot, MathAbs(lPL));

         bool closeOk = SafeOrderCloseMarket(lTkt, lLot, Slippage, clrOrange);
         if(!closeOk)
           {
            for(int retry = 0; retry < 3; retry++)
              {
               Sleep(100);
               RefreshRates();
               if(SafeOrderCloseMarket(lTkt, lLot, Slippage, clrOrange))
                  break;
              }
           }
        }
      InvalidateTotalEAOrdersCache();
     }
  }

//+------------------------------------------------------------------+
// Modify open orders to secure profit and keep trading active
//+------------------------------------------------------------------+
void ModifyOpenOrdersToSecureProfitOLD()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         // Ensure we only modify orders for the current chart symbol
         if(OrderSymbol() == Symbol())
           {
            int    ticket    = OrderTicket();
            int    type      = OrderType();
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            double currentTP = OrderTakeProfit();

            bool modified = false;
            double newSL  = 0;

            if(type == OP_BUY)
              {
               // Lock in profit by moving SL above the open price (e.g., securing a buffer below current Bid)
               newSL = Bid - (20 * Point);

               // Only update if the new SL is higher than the entry price and better than the current SL
               // if(newSL > openPrice && (currentSL == 0 || newSL > currentSL))
                 {
                  modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrGreen);
                 }
              }
            else
               if(type == OP_SELL)
                 {
                  // Lock in profit by moving SL below the open price (e.g., securing a buffer above current Ask)
                  newSL = Ask + (20 * Point);

                  // Only update if the new SL is lower than the entry price and better than the current SL
                  // if(newSL < openPrice && (currentSL == 0 || newSL < currentSL))
                    {
                     modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrRed);
                    }
                 }

            if(!modified && GetLastError() != 0)
              {
               Print("Failed to modify order #", ticket, ". Error: ", GetLastError());
              }
           }
        }
     }
  }


//====================================================================
// R9: Close Non-EMA & Trading Stop & Day Profit Ladder
//====================================================================
//+------------------------------------------------------------------+
//| Close and delete orders whose direction does not match EMADirection|
//+------------------------------------------------------------------+
void CloseAndDeleteNonEmaMatchingOrders()
  {
   int nonMatchingPendingTickets[1000];
   int nonMatchingPendingCount = 0;

   int nonMatchingOpenTickets[1000];
   int nonMatchingOpenCount = 0;

// 1. Scan and filter open and pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      bool isPending = (type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT);
      bool isMarket  = (type == OP_BUY || type == OP_SELL);

      if(isMarket)
        {
         bool isBuy = (type == OP_BUY);
         // Check if market order direction matches EMADirection (Buy needs EMADirection == 1, Sell needs EMADirection == -1)
         bool matchesEma = (isBuy && EMADirection == 1) || (!isBuy && EMADirection == -1);

         if(!matchesEma && nonMatchingOpenCount < 1000)
           {
            nonMatchingOpenTickets[nonMatchingOpenCount++] = OrderTicket();
           }
        }
      else
         if(isPending)
           {
            bool isBuyPending = (type == OP_BUYSTOP || type == OP_BUYLIMIT);
            bool matchesEma = (isBuyPending && EMADirection == 1) || (!isBuyPending && EMADirection == -1);

            if(!matchesEma && nonMatchingPendingCount < 1000)
              {
               nonMatchingPendingTickets[nonMatchingPendingCount++] = OrderTicket();
              }
           }
     }

// 2. Close non-matching open market orders
   for(int k = 0; k < nonMatchingOpenCount; k++)
     {
      int ticket = nonMatchingOpenTickets[k];
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      double lots = OrderLots();
      SafeOrderClose(ticket, lots, type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
     }

// 3. Delete non-matching pending orders
   for(int p = 0; p < nonMatchingPendingCount; p++)
     {
      int pendingTicket = nonMatchingPendingTickets[p];
      if(!OrderSelect(pendingTicket, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      SafeOrderDelete(pendingTicket, clrRed);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAndDeleteAllEAOrdersOnTradingStop()
  {
   Print(">>> [TRADING STOP ACTIVATED] Starting full emergency flattening of all EA orders & deleting all pending orders...");

   bool prevForceBudget = g_eqDdForceCloseBudget;
   g_eqDdForceCloseBudget = true; // Bypass rate limiting and failure guards for emergency close

// Multiple passes to ensure complete closure even with high volatility / requotes
   for(int pass = 0; pass < 3; pass++)
     {
      // 1. Delete all pending orders first so they don't trigger while closing market orders
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         int pType = OrderType();
         if(pType == OP_BUYSTOP || pType == OP_SELLSTOP || pType == OP_BUYLIMIT || pType == OP_SELLLIMIT)
           {
            int pTicket = OrderTicket();
            ResetLastError();
            if(!SafeOrderDelete(pTicket, clrRed))
              {
               ResetLastError();
               OrderDelete(pTicket, clrRed);
              }
           }
        }

      // Also call ForceDeleteAllPendingOrders as secondary safety net
      ForceDeleteAllPendingOrders();

      // 2. Close all open market orders directly at MARKET
      for(int j = OrdersTotal() - 1; j >= 0; j--)
        {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         int mType = OrderType();
         if(mType == OP_BUY || mType == OP_SELL)
           {
            int mTicket = OrderTicket();
            double mLots = OrderLots();
            color closeClr = (mType == OP_BUY ? clrRed : clrBlue);

            // True market close via SafeOrderCloseMarket
            bool closed = SafeOrderCloseMarket(mTicket, mLots, Slippage, closeClr);
            if(!closed)
              {
               // Fallback direct OrderClose if SafeOrderCloseMarket failed
               ResetLastError();
               RefreshRates();
               double closePrice = (mType == OP_BUY) ? Bid : Ask;
               closePrice = NormalizeDouble(closePrice, Digits);
               OrderClose(mTicket, mLots, closePrice, Slippage, closeClr);
              }
           }
        }

      // Check remaining EA orders
      int remaining = 0;
      for(int k = OrdersTotal() - 1; k >= 0; k--)
        {
         if(!OrderSelect(k, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            remaining++;
        }
      if(remaining == 0)
         break;
      Sleep(50);
     }

   g_eqDdForceCloseBudget = prevForceBudget;
   InvalidateTotalEAOrdersCache();
   InvalidateOrderCache();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CloseAllEAOrdersForLadderReset()
  {
   bool anyRemaining = false;
   int marketTickets[1000];
   int marketCount = 0;
   int pendingTickets[1000];
   int pendingCount = 0;
   if(DayProfitLadderCleanupStartTime > 0)
     {
      if((int)(TimeCurrent() - DayProfitLadderCleanupStartTime) >= LADDER_CLEANUP_TIMEOUT_SECONDS)
        {
         DayProfitLadderCleanupStartTime = 0;
         return true;
        }
     }
   else
      DayProfitLadderCleanupStartTime = TimeCurrent();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type==OP_BUY || type==OP_SELL)
        {
         if(marketCount<1000)
            marketTickets[marketCount++]=OrderTicket();
        }
      else
         if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
           {
            if(pendingCount<1000)
               pendingTickets[pendingCount++]=OrderTicket();
           }
     }
   for(int m=0; m<marketCount; m++)
     {
      int ticket=marketTickets[m];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)
         continue;
      double lots=OrderLots();
      if(!SafeOrderCloseMarket(ticket,lots,Slippage,(type==OP_BUY ? clrRed : clrBlue)))
         anyRemaining=true;
     }
   for(int q=0; q<pendingCount; q++)
     {
      int ticket=pendingTickets[q];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      if(!SafeOrderDelete(ticket,clrRed))
         anyRemaining=true;
     }
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
        {
         anyRemaining=true;
         break;
        }
     }
   if(anyRemaining)
      return false;
   DayProfitLadderCleanupStartTime = 0;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CreateDayProfitLadderPending(int direction)
  {
   if(InpEnableCustomRules && !PassesUserRules(direction == OP_BUY ? OP_BUY : OP_SELL))
      return false;
   if(!EnableTrading || DayProfitLadderTradingStopped)
      return false;
   if(direction!=OP_BUY && direction!=OP_SELL)
      return false;
   if(ServerRecoveryPending || !IsConnected() || GetTotalEAOrders() >= MaxOpenOrders)
      return false;
   RefreshRates();
   int pendingType=(direction==OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   double minimumGap=GetRequiredStopDistance();
   double gap=MathAbs(ProfitReEntryGapRaw);
   if(gap<minimumGap)
      gap=minimumGap;
   double entryPrice=0.0;
   if(direction==OP_BUY)
      entryPrice=Ask+gap;
   else
      entryPrice=Bid-gap;
   entryPrice=NormalizeDouble(entryPrice,Digits);
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(0.0, direction==OP_BUY ? "Day Ladder Buy Stop" : "Day Ladder Sell Stop", direction, 0);
   Lots=NormalizeLots(Lots);
   if(Lots<=0.0)
      return false;
   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;

   double stopLoss=(direction==OP_BUY) ? (entryPrice-slDistance) : (entryPrice+slDistance);
   stopLoss=NormalizeDouble(stopLoss,Digits);
   double takeProfit = (direction == OP_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
   takeProfit = NormalizeDouble(takeProfit, Digits);
   string comment=(direction==OP_BUY) ? "Day Ladder Buy Stop" : "Day Ladder Sell Stop";
   color orderColor=(direction==OP_BUY) ? BuyColor : SellColor;
   int ticket=SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, takeProfit, comment, MagicNumber, orderColor);
   if(ticket<0)
      return false;
   InvalidateTotalEAOrdersCache();
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageDayProfitLadder()
  {
   if(!EnableDayProfitLadder)
      return;

   double equity = AccountEquity();
   double balance = AccountBalance();

   datetime oldestOrderTime = GetOldestOpenOrderTime();
   if(oldestOrderTime > 0)
     {
      int openDurationSeconds = (int)(TimeCurrent() - oldestOrderTime);
      if(openDurationSeconds >= 7200)
        {
         double previousTarget = (DayProfitLadderStage == 0) ? DayProfitLadderStartBalance : GetDayProfitLadderTarget(DayProfitLadderStage);
         double nextTarget = GetDayProfitLadderTarget(DayProfitLadderStage + 1);
         double requiredLegProfit = nextTarget - previousTarget;
         double halfTargetEquity = previousTarget + (requiredLegProfit * 0.5);

         if(equity >= halfTargetEquity)
           {
            Print("TACTICAL EXIT: 2 Hours elapsed & 50% of leg target reached ($", DoubleToString(equity, 2), "). Closing stale orders.");
            // CloseAndDeleteAllEAOrdersOnTradingStop();
            return;
           }
        }
     }

   if(DayProfitLadderStage > 0)
     {
      double targetEquity = GetDayProfitLadderTarget(DayProfitLadderStage);
      double targetProfit = targetEquity - DayProfitLadderStartBalance;

      if(targetProfit > 0)
        {
         double lockedProfitAmount = targetProfit * (PeakProfitLockPercent / 100.0);
         double dynamicEquityFloor = DayProfitLadderStartBalance + lockedProfitAmount;

         if(AccountEquity() <= dynamicEquityFloor)
           {
            Print("Target Profit Lock Hit! Stage: ", DayProfitLadderStage, " | Target: $", targetEquity, " | Equity dropped below $", dynamicEquityFloor, ". Flattening trades.");
            CloseAndDeleteAllEAOrdersOnTradingStop();
            InitializeDayProfitLadder();
            return;
           }
        }
     }

   datetime today = GetDayProfitLadderDate();
   if(!DayProfitLadderInitialized)
     {
      InitializeDayProfitLadder();
      return;
     }

   if(DayProfitLadderDate != today)
     {
      if(GetEAFloatingPL() >= 0.0)
        {
         InitializeDayProfitLadder();
         return;
        }
     }

   if(DayProfitLadderTradingStopped)
     {
      CloseAndDeleteAllEAOrdersOnTradingStop();
      return;
     }

   if(DayProfitLadderStartBalance <= 0.0)
      return;

   int checkStage = DayProfitLadderStage + 1;
   while(equity >= GetDayProfitLadderTarget(checkStage))
     {
      checkStage++;
     }

   int reachedStage = checkStage - 1;
   if(reachedStage > DayProfitLadderStage)
     {
      DayProfitLadderStage = reachedStage;
      DayProfitLadderTargetReachedCandle = Time[0];
      DayProfitLadderResumeDirection = GlobalSSLDirection;
      if(DayProfitLadderResumeDirection == 0)
         DayProfitLadderResumeDirection = LastLiveSSLDirection;
      DayProfitLadderTargetCleanupPending = true;
      DayProfitLadderResumePending = (DayProfitLadderResumeDirection != 0);

      DayProfitLadderProtectionEquity = GetDayProfitLadderProtection(DayProfitLadderStage);
      DayProfitLadderNextTargetEquity = GetDayProfitLadderTarget(DayProfitLadderStage + 1);
      SaveDayProfitLadderState();
     }

   if(equity <= DayProfitLadderProtectionEquity)
     {
      DayProfitLadderTradingStopped = true;
      DayProfitLadderTargetReachedCandle = 0;
      DayProfitLadderResumePending = false;
      DayProfitLadderResumeDirection = 0;
      DayProfitLadderResumeTradeAttempt = false;
      DayProfitLadderTargetCleanupPending = false;
      SaveDayProfitLadderState();
      CloseAndDeleteAllEAOrdersOnTradingStop();
      for(int dpl_i=0; dpl_i<MAX_DEFERRED_ORDERS; dpl_i++)
         DeferredActive[dpl_i]=false;
      EquityResetReEntryPending=false;

      ReEntryRetryPending=false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDayProfitLadderTradingAllowed()
  {
   if(!EnableDayProfitLadder)
      return true;
   ManageDayProfitLadder();
   if(DayProfitLadderTradingStopped)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDailyProtectionState(DailyProtectionState &state)
  {
   ManageDayProfitLadder();
   state.DayDate = DayProfitLadderDate;
   state.DayStartBalance = DayProfitLadderStartBalance;
   state.DayProtectedBalance = DayProfitLadderProtectionEquity;
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   state.TradingStopped = DayProfitLadderTradingStopped;
   state.Initialized = true;
   DailyProtectionStartTime = TimeCurrent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void StartProtectedEquityWait()
  {
   ProtectedEquityWaitActive = true;
   ProtectedEquityWaitStartTime = TimeCurrent();
   EquityResetReEntryPending = false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsProtectedEquityWaiting()
  {
   if(!ProtectedEquityWaitActive)
      return false;
   datetime resumeTime = ProtectedEquityWaitStartTime + ProtectedEquityWaitMinutes * 60;
   if(TimeCurrent() < resumeTime)
      return true;
   ProtectedEquityWaitActive = false;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetProtectedEquityWaitSeconds()
  {
   if(!ProtectedEquityWaitActive)
      return 0;
   int remaining = (int)((ProtectedEquityWaitStartTime + ProtectedEquityWaitMinutes * 60) - TimeCurrent());
   if(remaining < 0)
      remaining = 0;
   return remaining;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetProtectedEquityWaitText()
  {
   int seconds = GetProtectedEquityWaitSeconds();
   return StringFormat("%02d:%02d:%02d", seconds/3600, (seconds%3600)/60, seconds%60);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void QueueEquityResetReEntry()
  {
   EquityResetReEntryPending = true;
   OrderCreatedThisCandle = false;
   LastOrderCandleTime = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessEquityResetReEntry(DailyProtectionState &state)
  {
   if(!EquityResetReEntryPending || !EnableTrading || IsDailyTradingStopped(state) || Bars < SSLPeriod + 20)
      return;
   if(GetTotalEAOrders() > 0)
     {
      EquityResetReEntryPending = false;
      return;
     }
   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

   int currentDirection = GlobalSSLDirection;
   if(currentDirection > 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime = 0;
      DrawLiveSignal(0, true);
      int beforeOrders = GetTotalEAOrders();
      OpenBuy();
      int afterOrders = GetTotalEAOrders();
      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;
        }
      return;
     }
   if(currentDirection < 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime = 0;
      DrawLiveSignal(0, false);
      int beforeOrders = GetTotalEAOrders();
      OpenSell();
      int afterOrders = GetTotalEAOrders();
      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;
        }
      return;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDailyLossProtection(DailyProtectionState &state)
  {
   if(!EnableDayProfitLadder)
      return;
   state.DayDate = DayProfitLadderDate;
   state.DayStartBalance = DayProfitLadderStartBalance;
   state.DayProtectedBalance = DayProfitLadderProtectionEquity;
   state.TradingStopped = DayProfitLadderTradingStopped;
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountClosedOrdersSinceInitialization()
  {
   int count = 0;
   if(DailyProtectionStartTime <= 0)
      return 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if((OrderType() != OP_BUY && OrderType() != OP_SELL) || OrderCloseTime() <= DailyProtectionStartTime)
         continue;
      count++;
     }
   return count;
  }

bool IsDailyTradingStopped(DailyProtectionState &state) { return EnableDayProfitLadder && DayProfitLadderTradingStopped; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOppositePendingOrders(int newSignalType)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();

      // When new signal is OP_BUY, delete opposite pending SELL orders
      // When new signal is OP_SELL, delete opposite pending BUY orders
      bool deleteOrder = ((newSignalType == OP_BUY && (orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)) ||
                          (newSignalType == OP_SELL && (orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)));

      if(deleteOrder)
         SafeOrderDelete(OrderTicket(), clrYellow);
     }
  }
//+------------------------------------------------------------------+
//| Close opposite profitable orders on SSL signal + EMA condition   |
//+------------------------------------------------------------------+
void CloseOppositeProfitableOrdersOnSignal(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// 1. Calculate current EMA and local direction
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   int localEmaDirection = 0;

   if(ema > 0)
     {
      if(Bid > ema)
         localEmaDirection = 1;      // Bullish EMA
      else
         if(Bid < ema)
            localEmaDirection = -1;   // Bearish EMA
     }

// 2. Loop through open orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // Calculate profit threshold: $0.25 per 0.01 lot step
      double profitThreshold = 0.25 * (lots / 0.01);

      // Check if the order is opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // SCENARIO A: Sell order is open, EMA is Bullish (1), new signal is Buy
         bool isSellOpenBullishEma = (orderType == OP_SELL && localEmaDirection == 1 && newSignalType == OP_BUY);

         // SCENARIO B: Buy order is open, EMA is Bearish (-1), new signal is Sell
         bool isBuyOpenBearishEma  = (orderType == OP_BUY && localEmaDirection == -1 && newSignalType == OP_SELL);

         // If either conflicting condition matches and the order has crossed the profit threshold
         if((isSellOpenBullishEma || isBuyOpenBearishEma) && orderPL >= profitThreshold)
           {
            Print("PROFITABLE OPPOSITE CLOSE: Ticket #", ticket, " | Type: ", GetOrderTypeText(orderType),
                  " | Profit: $", DoubleToString(orderPL, 2), " | Reaching threshold ($", DoubleToString(profitThreshold, 2), ")");

            SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newSignalType)
  {
   if(!EAStartupComplete)
      return;
   RefreshRates();

// 1. Calculate EMA and True Direction instantly on this exact tick
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   int localEmaDirection = 0;

   if(ema > 0)
     {
      if(Bid > ema)
         localEmaDirection = 1;
      else
         if(Bid < ema)
            localEmaDirection = -1;
     }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();
      double profitThreshold = 0.25 * (lots / 0.01);

      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // 2. Use localEmaDirection for absolute precision
         bool emaMatchesOrder = ((orderType == OP_BUY && localEmaDirection == 1) ||
                                 (orderType == OP_SELL && localEmaDirection == -1));

         bool emaMatchesSignal = ((newSignalType == OP_BUY && localEmaDirection == 1) ||
                                  (newSignalType == OP_SELL && localEmaDirection == -1));

         if(emaMatchesOrder)
           {
            // Instead of closing, lock the SL at the profit threshold
            if(orderPL > profitThreshold)
              {
               double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
               double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

               if(tickValue > 0 && tickSize > 0)
                 {
                  // Convert USD profit threshold into raw price distance
                  double lockDistance = (profitThreshold / (tickValue * lots)) * tickSize;
                  double newSL = 0.0;

                  if(orderType == OP_BUY)
                    {
                     newSL = NormalizeDouble(OrderOpenPrice() + lockDistance, Digits);
                     // Only modify if the current SL is lower than the new SL or doesn't exist
                     if(OrderStopLoss() == 0 || newSL > OrderStopLoss())
                       {
                        Print("OPPOSITE SIGNAL: Locking Buy profit at threshold SL.");
                        SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrLimeGreen);
                       }
                    }
                  else
                     if(orderType == OP_SELL)
                       {
                        newSL = NormalizeDouble(OrderOpenPrice() - lockDistance, Digits);
                        // Only modify if the current SL is higher than the new SL or doesn't exist
                        if(OrderStopLoss() == 0 || newSL < OrderStopLoss())
                          {
                           Print("OPPOSITE SIGNAL: Locking Sell profit at threshold SL.");
                           SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrTomato);
                          }
                       }
                 }
              }
           }
         else
            if(emaMatchesSignal)
              {
               // Close immediately if distance > 100
               double currentPrice = (orderType == OP_BUY) ? Bid : Ask;
               double distanceToEma = MathAbs(currentPrice - ema);

               if(distanceToEma > 100.0)
                 {
                  Print("CLOSE EXECUTED: Fighting EMA & SSL + Distance > 100.");
                  SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetOrderDirection(int orderType)
  {
   if(orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
      return 1;
   if(orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersold2(int newSignalType)
  {
   if(!EAStartupComplete)
      return;
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();
      double profitThreshold = 0.25 * (lots / 0.01);

      // 1. Check if the order is opposite to the new SSL signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // 2. ONLY close if it has reached the profit threshold.
         // If it is below the threshold, it is ignored and left running.
         if(orderPL > profitThreshold)
           {
            SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersold(int newSignalType)
  {
   if(!EAStartupComplete)
      return;
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // if(orderPL <= closeOppositeLossThreshold)
      //    continue;

      if((newSignalType == OP_BUY && orderType == OP_SELL && EMADirection == 1) || (newSignalType == OP_SELL && orderType == OP_BUY && EMADirection == -1))
        {
         SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
        }
     }
  }


//====================================================================
// R10: CloseAll & Dynamic Step Ladder & EquityProfitLadder5
//====================================================================
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Close all open orders for current symbol and magic number        |
//+------------------------------------------------------------------+
void CloseAllOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Match current symbol and magic number
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      // Skip recovery orders if your EA uses them separately
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      if(orderType == OP_BUY || orderType == OP_SELL)
        {
         SafeOrderCloseMarket(OrderTicket(), OrderLots(), Slippage, (orderType == OP_BUY ? clrRed : clrBlue));
        }
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckDynamicStepLadder()
  {
   if(!InpEnableDynamicStepLadder)
      return; // DISABLED: Consolidated into master Manage5PercentLadderReset

   double currentOpenProfit = 0.0;
   int openOrdersCount = 0;

// 1. Calculate current open profit
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      if(orderType == OP_BUY || orderType == OP_SELL)
        {
         currentOpenProfit += OrderProfit() + OrderSwap() + OrderCommission();
         openOrdersCount++;
        }
     }

// If no orders are open, reset peak tracking for the next cycle
   if(openOrdersCount == 0)
     {
      g_peakCycleProfit = 0.0;
      return;
     }

// 2. Calculate realized profit from closed history since last reset
   double realizedHistoryProfit = 0.0;
   int historyTotal = HistoryTotal();

   for(int i = 0; i < historyTotal; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderCloseTime() > g_lastLadderCloseTime)
        {
         realizedHistoryProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

// 3. Current active cycle profit
   double cycleProfit = realizedHistoryProfit + currentOpenProfit;

// 4. Update Peak Profit Watermark if we make a new high
   if(cycleProfit > g_peakCycleProfit)
     {
      g_peakCycleProfit = cycleProfit;
     }

// 5. Dynamically calculate the highest $5 step milestone unlocked by the peak
// e.g., if peak is $14, MathFloor(14 / 5) * 5 = $10 floor milestone.
// If peak is $17, MathFloor(17 / 5) * 5 = $15 floor milestone.
   double unlockedStepFloor = MathFloor(g_peakCycleProfit / g_stepSize) * g_stepSize;

// Ensure we have at least crossed the first $5 step before trailing starts
   if(unlockedStepFloor >= g_stepSize)
     {
      // 6. If the current profit drops down to or below the previous step floor, close all orders!
      // (e.g., Peak hit $14 -> Floor is $10. If current profit drops back to $10, trigger close.)
      if(cycleProfit <= unlockedStepFloor)
        {
         Print("Dynamic Step Exit! Peak reached: $", DoubleToString(g_peakCycleProfit, 2),
               " | Market came down to step floor: $", DoubleToString(unlockedStepFloor, 2), ". Closing all open orders.");

         // CloseAllOrders();
         ModifyOpenOrdersToSecureProfit();


         // Save baseline time and reset peak for the next cycle
         g_lastLadderCloseTime = TimeCurrent();
         g_peakCycleProfit = 0.0;
        }
     }
  }

//+------------------------------------------------------------------+
//| EquityProfitLadder5                                              |
//| Continuous Lowest Equity Tracking & $5 * Multiplier Step Ladder  |
//| 1. Stores the lowest equity reached during active trading.       |
//| 2. Every time equity moves UP by $5.00 * balancelomultipler:     |
//|    - Modifies all open market orders with -$100 raw gap SL       |
//|    - Ratchets the baseline to current equity                     |
//|    - Draws visual circle marker on chart                         |
//| 3. If equity falls to a new low, updates LowestEquity baseline.  |
//| 4. When no orders are open, synchronizes state cleanly.          |
//+------------------------------------------------------------------+
// State variables LowestEquity, LowestEquityInitialized, g_equityLadderNextTarget, g_equityLadderStepCounter
// are defined as EA globals in V_EMAMULTIPLE_SMALL_LOTS.mq4
datetime g_lastEquityLadderHitTime  = 0;

//+------------------------------------------------------------------+
//| DrawEquityProfitLadder5HitIcon:                                  |
//| Draws vibrant Aqua marker & text label on chart when an          |
//| EquityProfitLadder5 step is hit.                                 |
//+------------------------------------------------------------------+
void DrawEquityProfitLadder5HitIcon(int step, double curEquity, double lowestEquity, double targetVal, datetime hitTime = 0, double hitPrice = 0.0)
  {
   if(!InpDrawEquityLadder5Icon)
      return;

   if(hitTime <= 0)
      hitTime = TimeCurrent();

   datetime barTime = (Time[0] > 0 ? Time[0] : hitTime);
   string baseName = PREFIX + "EQL5_STEP_" + IntegerToString(step) + "_" + IntegerToString((int)barTime);

// Prevent duplicate icon on same bar for the same step
   if(ObjectFind(0, baseName) >= 0 || ObjectFind(0, baseName + "_TXT") >= 0)
      return;

   double atr = iATR(Symbol(), Period(), 14, 1);
   if(atr <= 0.0)
      atr = 30 * Point;
   if(atr <= 0.0)
      atr = 1.0;

   double markerPrice = 0.0;
   double labelPrice  = 0.0;

   if(hitPrice > 0.0)
     {
      if(hitPrice == Low[0])
        {
         markerPrice = Low[0] - (atr * 0.25);
         labelPrice  = markerPrice - (atr * 0.35);
        }
      else
        {
         markerPrice = High[0] + (atr * 0.25);
         labelPrice  = markerPrice + (atr * 0.35);
        }
     }
   else
     {
      markerPrice = Low[0] - (atr * 0.25);
      labelPrice  = markerPrice - (atr * 0.35);
     }

   color iconColor = InpEquityLadder5IconColor;
   int   iconCode  = (InpEquityLadder5IconCode > 0 ? InpEquityLadder5IconCode : 159);
   int   fontSize  = (InpEquityLadder5FontSize > 0 ? InpEquityLadder5FontSize : 10);

   string txtName = baseName + "_TXT";
   double gainFromLow = curEquity - lowestEquity;
   string labelText = StringFormat("EQL #%d (+$%.0f)", step, gainFromLow);
   string tooltip   = StringFormat("Equity Profit Ladder Step #%d HIT | Current Equity: $%.2f | Low Baseline: $%.2f | Gain from Low: +$%.2f | Target: $%.2f | All Open Orders SL Tightened (-$100 gap) | Time: %s",
                                   step, curEquity, lowestEquity, gainFromLow, targetVal,
                                   TimeToString(hitTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

// 1. Solid Marker Icon (Wingdings 159 dot, 171 star, 251 check, etc.)
   ObjectCreate(0, baseName, OBJ_ARROW, 0, barTime, markerPrice);
   ObjectSetInteger(0, baseName, OBJPROP_ARROWCODE, iconCode);
   ObjectSetInteger(0, baseName, OBJPROP_COLOR, iconColor);
   ObjectSetInteger(0, baseName, OBJPROP_WIDTH, 4);
   ObjectSetInteger(0, baseName, OBJPROP_BACK, false);
   ObjectSetInteger(0, baseName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, baseName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, baseName, OBJPROP_TOOLTIP, tooltip);

// 2. Bold Text Label
   ObjectCreate(0, txtName, OBJ_TEXT, 0, barTime, labelPrice);
   ObjectSetString(0, txtName, OBJPROP_TEXT, labelText);
   ObjectSetString(0, txtName, OBJPROP_FONT, "Arial Black");
   ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, txtName, OBJPROP_COLOR, iconColor);
   ObjectSetInteger(0, txtName, OBJPROP_BACK, false);
   ObjectSetInteger(0, txtName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, txtName, OBJPROP_HIDDEN, false);
   ObjectSetString(0, txtName, OBJPROP_TOOLTIP, tooltip);

   ChartRedraw(0);

   Print(">>> [EQUITY PROFIT LADDER 5 CHART ICON] Placed '", labelText, "' on chart at bar ",
         TimeToString(barTime, TIME_DATE|TIME_MINUTES), " | Equity: $", DoubleToString(curEquity, 2),
         " | Gain from Low: +$", DoubleToString(gainFromLow, 2));
  }

//+------------------------------------------------------------------+
//| Calculate raw price difference from 2 hours ago                  |
//+------------------------------------------------------------------+
double GetEquityLadder2HourPriceDiff()
  {
   return Get2HourPriceDifferenceRaw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void EquityProfitLadder5()
  {
   if(!InpEnableEquityProfitLadder5)
      return;

// 1. Count active symbol & magic market orders (excluding recovery orders)
   int openCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int oType = OrderType();
      if(oType == OP_BUY || oType == OP_SELL)
         openCount++;
     }

// 2. If no open market orders, keep tracking synchronized with current balance/equity
   if(openCount == 0)
     {
      LowestEquity              = AccountEquity();
      g_equityLadderNextTarget  = 0.0;
      g_equityLadderStepCounter = 0;
      // Note: g_lastEquityLadderHitTime is preserved so the 6-hour cooldown strictly applies globally across order cycles!
      LowestEquityInitialized   = false;
      return;
     }

   double curEquity = AccountEquity();
   double mult = (InpEquityLadderUseMultiplier && balancelomultipler > 0) ? balancelomultipler : 1.0;
   double stepUSD = InpEquityProfitLadderStepUSD * mult;
   if(stepUSD <= 0.0)
      stepUSD = 5.0;

// 3. First run / Initialization with open orders
   if(!LowestEquityInitialized || LowestEquity <= 0.0)
     {
      LowestEquity              = curEquity;
      g_equityLadderNextTarget  = curEquity + stepUSD;
      g_equityLadderStepCounter = 0;
      // Note: g_lastEquityLadderHitTime is preserved so the 6-hour cooldown strictly applies globally across order cycles!
      LowestEquityInitialized   = true;

      Print("EQUITY PROFIT LADDER $5 INITIALIZED | Equity=$", DoubleToString(curEquity, 2),
            " | LowestEquity=$", DoubleToString(LowestEquity, 2),
            " | Step=$", DoubleToString(stepUSD, 2),
            " | NextTarget=$", DoubleToString(g_equityLadderNextTarget, 2),
            " | MinGapHours=", DoubleToString(InpEquityLadderMinGapHours, 1));
      return;
     }

// 4. Equity makes a new low (Drawdown tracking downwards)
   if(curEquity < LowestEquity)
     {
      LowestEquity             = curEquity;
      g_equityLadderNextTarget = curEquity + stepUSD; // Reset bounce target to $5 * multiplier above the new low
      return;
     }

// 5. Equity moved UP by step ($5 * multiplier) from the low
   if(curEquity >= g_equityLadderNextTarget)
     {
      // Check minimum time gap between step hits (e.g. 6 hours)
      if(InpEquityLadderMinGapHours > 0.0 && g_lastEquityLadderHitTime > 0)
        {
         datetime minNextAllowedTime = g_lastEquityLadderHitTime + (datetime)(InpEquityLadderMinGapHours * 3600.0);
         if(TimeCurrent() < minNextAllowedTime)
           {
            // Minimum time gap has not elapsed yet; keep waiting
            return;
           }
        }

      // Check minimum EMA angle condition (MathAbs(EMAangle) > 6.0)
      double curEmaAng = (GlobalEmaAngle30 != 0.0) ? GlobalEmaAngle30 : GetEmaAngleDegrees(30);
      if(InpEquityLadderMinEmaAngle > 0.0 && MathAbs(curEmaAng) <= InpEquityLadderMinEmaAngle)
        {
         // EMA angle is too flat (<= 6.0 deg); wait for strong trend momentum
         return;
        }

      // Check EMA strength condition (EMA should be STRONG, not weak / pulling back from peak)
      if(InpEquityLadderRequireStrongEma && IsEmaWEAKDistanceReduced50PercentFromPeak())
        {
         // EMA is WEAK (pulling back >= 50% or $100 from peak); wait for strong trend
         return;
        }

      // Check 2-hour price difference condition (> $2000 raw price)
      double priceDiff2h = 0.0;
      if(InpEquityLadderMinPriceDiff2Hours > 0.0)
        {
         priceDiff2h = GetEquityLadder2HourPriceDiff();
         if(priceDiff2h <= InpEquityLadderMinPriceDiff2Hours)
           {
            // Price difference in last 2 hours is <= $2000; wait for large price movement
            return;
           }
        }

      if(InpPauseEquityProfitHitOnSingleWinningOrder)
        {
         int mktCount = 0;
         int posCount = 0;
         for(int i = OrdersTotal() - 1; i >= 0; i--)
           {
            if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
               continue;
            if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
               continue;
            if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
               continue;
            int oType = OrderType();
            if(oType == OP_BUY || oType == OP_SELL)
              {
               mktCount++;
               if((OrderProfit() + OrderSwap() + OrderCommission()) > 0.0)
                  posCount++;
              }
           }
         if(mktCount == 1 && posCount == 1)
            return; // Pause Equity Profit Ladder $5 when only 1 order open and profitable
        }

      g_equityLadderStepCounter++;
      g_lastEquityLadderHitTime = TimeCurrent();
      double gainFromLow = curEquity - LowestEquity;

      Print("==================================================================");
      Print(">>> EQUITY PROFIT LADDER $5 STEP #", g_equityLadderStepCounter, " HIT!",
            " | Equity=$", DoubleToString(curEquity, 2),
            " >= Target=$", DoubleToString(g_equityLadderNextTarget, 2),
            " | LowestEquity=$", DoubleToString(LowestEquity, 2),
            " | Gain From Low=+$", DoubleToString(gainFromLow, 2),
            " | Time=", TimeToString(g_lastEquityLadderHitTime, TIME_DATE|TIME_SECONDS),
            " | EMA Angle=", DoubleToString(curEmaAng, 2), " deg (MathAbs > ", DoubleToString(InpEquityLadderMinEmaAngle, 1), ")",
            " | EMA Strength=STRONG",
            " | 2H Price Diff=$", DoubleToString(priceDiff2h, 2), " (> $", DoubleToString(InpEquityLadderMinPriceDiff2Hours, 0), ")",
            " | Modifying ALL Open Orders with -$", DoubleToString(InpEquityLadderSLDistanceRaw, 0), " StopLoss gap.");
      Print("==================================================================");

      // Modify all eligible open orders with -$100 raw gap SL
      ModifyAllOrdersWithEquityLadderSL(InpEquityLadderSLDistanceRaw);

      // Draw dedicated chart icon and text label for EquityProfitLadder5 step hit
      DrawEquityProfitLadder5HitIcon(g_equityLadderStepCounter, curEquity, LowestEquity, g_equityLadderNextTarget, TimeCurrent(), ((Close[0] > Open[0]) ? Low[0] : High[0]));

      // Ratchet: Baseline becomes current equity, next target is current equity + stepUSD
      LowestEquity             = curEquity;
      g_equityLadderNextTarget = curEquity + stepUSD;

      Print("EQUITY PROFIT LADDER RATCHETED | New Lowest Baseline=$", DoubleToString(LowestEquity, 2),
            " | Next Step Target=$", DoubleToString(g_equityLadderNextTarget, 2),
            " | Next Hit Earliest=", TimeToString(g_lastEquityLadderHitTime + (datetime)(InpEquityLadderMinGapHours * 3600.0), TIME_DATE|TIME_MINUTES));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MonitorLowestEquityRecovery()
  {
   EquityProfitLadder5();
  }

//+------------------------------------------------------------------+
//| ModifyAllOrdersWithEquityLadderSL                                |
//| Modifies all open market orders with StopLoss at -$100 raw gap   |
//| from live market price (Bid - 100 for BUY / Ask + 100 for SELL)  |
//+------------------------------------------------------------------+
void ModifyAllOrdersWithEquityLadderSL(double slGapRaw)
  {
   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   if(minDistance < 20.0)
      minDistance = 20.0;

   if(slGapRaw < minDistance)
      slGapRaw = minDistance;

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);

   int modifiedCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      // Exclude recovery orders: they have their own recovery logic
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      // Exclude FLIPBasketSupport orders: they have dedicated step-trailing SL
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()))
         continue;

      int    tkt   = OrderTicket();
      int    oType = OrderType();
      double oOpen = OrderOpenPrice();
      double curSL = OrderStopLoss();
      double curTP = OrderTakeProfit();
      double netPL = OrderProfit() + OrderSwap() + OrderCommission();

      RefreshRates();
      curBid = MarketInfo(Symbol(), MODE_BID);
      curAsk = MarketInfo(Symbol(), MODE_ASK);

      double proposedSL = 0.0;
      bool   shouldModify = false;

      if(oType == OP_BUY)
        {
         proposedSL = NormalizeDouble(curBid - slGapRaw, Digits);
         if((curBid - proposedSL) < minDistance)
            proposedSL = NormalizeDouble(curBid - minDistance, Digits);

         // Ensure SL is strictly valid below Bid
         if(proposedSL >= curBid)
            continue;

         // For BUY: Set if no SL (0.0), or only move SL forward (higher) by at least MinimumSLModifyGapRaw ($25)
         if(curSL == 0.0 || (proposedSL > curSL && (proposedSL - curSL) >= MinimumSLModifyGapRaw))
           {
            shouldModify = true;
           }
        }
      else
         if(oType == OP_SELL)
           {
            proposedSL = NormalizeDouble(curAsk + slGapRaw, Digits);
            if((proposedSL - curAsk) < minDistance)
               proposedSL = NormalizeDouble(curAsk + minDistance, Digits);

            // Ensure SL is strictly valid above Ask
            if(proposedSL <= curAsk)
               continue;

            // For SELL: Set if no SL (0.0), or only move SL forward (lower) by at least MinimumSLModifyGapRaw ($25)
            if(curSL == 0.0 || (proposedSL < curSL && (curSL - proposedSL) >= MinimumSLModifyGapRaw))
              {
               shouldModify = true;
              }
           }

      if(shouldModify && proposedSL > 0.0)
        {
         ResetLastError();
         bool modified = SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato));
         if(modified)
           {
            modifiedCount++;
            Print("EQUITY LADDER $5 SL MODIFIED | Ticket #", tkt,
                  " | Type=", (oType == OP_BUY ? "BUY" : "SELL"),
                  " | P/L=$", DoubleToString(netPL, 2),
                  " | Old SL=", DoubleToString(curSL, Digits),
                  " | New SL=", DoubleToString(proposedSL, Digits),
                  " (Gap=$", DoubleToString(slGapRaw, 1), ")");
           }
         else
           {
            Print("EQUITY LADDER $5 SL MODIFY FAILED | Ticket #", tkt, " | Error=", GetLastError());
           }
        }
     }
  }


//====================================================================
// R11: HLine Profit Live SL & Ended Live SL
//====================================================================

//+------------------------------------------------------------------+
//| ManageHorizontalLineProfitLiveStopLoss:                          |
//| USER RULE:                                                       |
//| - "GREEEN horizontal line is started then SELL orders are in     |
//|   profit >$0 then modify all open SELL orders stoploss with      |
//|   liveprice."                                                    |
//| - "RED horizontal line is started then BUY orders are in profit  |
//|   >$0 then modify all open BUY orders stoploss with live price"  |
//+------------------------------------------------------------------+
void ManageHorizontalLineProfitLiveStopLoss()
  {
   if(!InpEnableHLineProfitLiveSLModify)
      return;

   bool curGreenActive = (g_lastEqLowPrice  > 0.0 && g_lastEqLowLineStart  > 0) || IsLsdSweepGreenLinePresent() || (GetEQR_G_Price(true) > 0.0);
   bool curRedActive   = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0) || IsLsdSweepRedLinePresent()   || (GetEQR_R_Price(true) > 0.0);

   if(!curGreenActive && !curRedActive)
      return;

   datetime curGreenStart = (g_lastEqLowLineStart > 0) ? g_lastEqLowLineStart : GetLsdSweepActiveEqlLineStart();
   double   curGreenPrice = (g_lastEqLowPrice > 0.0)   ? g_lastEqLowPrice     : GetEQR_G_Price(true);

   datetime curRedStart   = (g_lastEqHighLineStart > 0) ? g_lastEqHighLineStart : GetLsdSweepActiveEqhLineStart();
   double   curRedPrice   = (g_lastEqHighPrice > 0.0)   ? g_lastEqHighPrice     : GetEQR_R_Price(true);

   // Log once when a line is newly detected as started
   static datetime s_lastLoggedGreenStart = 0;
   static datetime s_lastLoggedRedStart   = 0;
   if(curGreenActive && curGreenStart > 0 && curGreenStart != s_lastLoggedGreenStart)
     {
      PrintFormat(">>> [HLINE LIVE SL] GREEN Line Started (%s @ %.2f) -> Checking all open SELL orders with profit > $0 and live price near green line (range <= $%.2f) to modify SL with live price",
                  TimeToString(curGreenStart, TIME_DATE|TIME_MINUTES), curGreenPrice, InpHLineModifyGreenLineRangeUSD);
      s_lastLoggedGreenStart = curGreenStart;
     }
   if(curRedActive && curRedStart > 0 && curRedStart != s_lastLoggedRedStart)
     {
      PrintFormat(">>> [HLINE LIVE SL] RED Line Started (%s @ %.2f) -> Checking all open BUY orders with profit > $0 to modify SL with live price",
                  TimeToString(curRedStart, TIME_DATE|TIME_MINUTES), curRedPrice);
      s_lastLoggedRedStart = curRedStart;
     }

   double mult = (InpHLineModifyUsesMultiplier && balancelomultipler > 0) ? (double)balancelomultipler : 1.0;
   double minProfit = InpHLineModifyProfitThresholdUSD * mult;
   if(minProfit < 0.0)
      minProfit = 0.0;

   RefreshRates();

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;
   double minModGap = GetEffectiveMinSLModifyGap();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      int tkt = OrderTicket();
      double netPL = OrderProfit() + OrderSwap() + OrderCommission();
      if(netPL <= minProfit)
         continue;

      double oOpen = OrderOpenPrice();
      double curSL = OrderStopLoss();
      double curTP = OrderTakeProfit();

      // Rule 1: GREEN horizontal line started -> modify all open SELL orders (profit > $0) SL with liveprice
      // USER RULE: Live price is near to green line $50 range only
      if(curGreenActive && oType == OP_SELL)
        {
         if(InpHLineModifyGreenLineRangeUSD > 0.0)
           {
            if(curGreenPrice <= 0.0 || MathAbs(curBid - curGreenPrice) > InpHLineModifyGreenLineRangeUSD)
               continue;
           }

         double targetSL = NormalizeDouble(curAsk + minStopDist, Digits);
         if(targetSL > curAsk && (curSL <= 0.0 || (targetSL < curSL - minModGap)))
           {
            bool ok = SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrTomato, "HLineLiveSL_Sell");
            if(ok)
              {
               PrintFormat(">>> [HLINE LIVE SL] GREEN Line Started/Active (%s @ %.2f): SELL #%d SL modified to Live Price (Ask+StopDist=%.2f) | DistToLine=$%.2f <= $%.2f | Profit=+$%.2f > $%.2f",
                           TimeToString(curGreenStart, TIME_DATE|TIME_MINUTES), curGreenPrice, tkt, targetSL, MathAbs(curBid - curGreenPrice), InpHLineModifyGreenLineRangeUSD, netPL, minProfit);
              }
           }
        }
      // Rule 2: RED horizontal line started -> modify all open BUY orders (profit > $0) SL with live price
      else if(curRedActive && oType == OP_BUY)
        {
         if(InpHLineModifyRedLineRangeUSD > 0.0)
           {
            if(curRedPrice <= 0.0 || MathAbs(curBid - curRedPrice) > InpHLineModifyRedLineRangeUSD)
               continue;
           }

         double targetSL = NormalizeDouble(curBid - minStopDist, Digits);
         if(targetSL < curBid && (curSL <= 0.0 || (targetSL > curSL + minModGap)))
           {
            bool ok = SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrLimeGreen, "HLineLiveSL_Buy");
            if(ok)
              {
               PrintFormat(">>> [HLINE LIVE SL] RED Line Started/Active (%s @ %.2f): BUY #%d SL modified to Live Price (Bid-StopDist=%.2f) | Profit=+$%.2f > $%.2f",
                           TimeToString(curRedStart, TIME_DATE|TIME_MINUTES), curRedPrice, tkt, targetSL, netPL, minProfit);
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| ManageHorizontalLineEndedProfitLiveStopLoss:                     |
//| USER RULE: "GREEN line ends or RED line ends any horizontal ends |
//|  means something is unpredictable so, modify all individual open |
//|  orders stoploss with current live price if any order individual |
//|  profit is more than $0.50"                                      |
//+------------------------------------------------------------------+
void ManageHorizontalLineEndedProfitLiveStopLoss()
  {
   if(!InpEnableHLineEndedProfitLiveSLModify)
      return;

   double mult = (InpHLineEndedModifyUsesMultiplier && balancelomultipler > 0) ? (double)balancelomultipler : 1.0;
   double minProfit = InpHLineEndedProfitThresholdUSD * mult;
   if(minProfit <= 0.0)
      minProfit = 0.50 * mult;

   // 1. Detect state transitions (line active on last tick -> no longer active on current tick)
   static bool     s_prevRedActive   = false;
   static datetime s_prevRedStart    = 0;
   static double   s_prevRedPrice    = 0.0;
   static bool     s_prevGreenActive = false;
   static datetime s_prevGreenStart  = 0;
   static double   s_prevGreenPrice  = 0.0;

   bool curRedActive = (g_lastEqHighPrice > 0.0 && g_lastEqHighLineStart > 0) || IsLsdSweepRedLinePresent() || (GetEQR_R_Price(true) > 0.0);
   datetime curRedStart = (g_lastEqHighLineStart > 0) ? g_lastEqHighLineStart : GetLsdSweepActiveEqhLineStart();
   double curRedPrice = (g_lastEqHighPrice > 0.0) ? g_lastEqHighPrice : GetEQR_R_Price(true);

   bool curGreenActive = (g_lastEqLowPrice > 0.0 && g_lastEqLowLineStart > 0) || IsLsdSweepGreenLinePresent() || (GetEQR_G_Price(true) > 0.0);
   datetime curGreenStart = (g_lastEqLowLineStart > 0) ? g_lastEqLowLineStart : GetLsdSweepActiveEqlLineStart();
   double curGreenPrice = (g_lastEqLowPrice > 0.0) ? g_lastEqLowPrice : GetEQR_G_Price(true);

   // Check if Red line ended on this tick
   if(s_prevRedActive && !curRedActive)
     {
      g_lastHLineEndedTime      = TimeCurrent();
      g_lastHLineEndedType      = "RED";
      g_lastHLineEndedLineStart = s_prevRedStart;
      g_lastHLineEndedPrice     = s_prevRedPrice;
      PrintFormat(">>> [HLINE ENDED TRIGGER] RED Line ended (Start: %s, Price=%.2f). Market unpredictable -> Modifying open orders (profit > $%.2f [Base=$%.2f x Mult=%.0f]) SL to live price!",
                  TimeToString(s_prevRedStart, TIME_DATE|TIME_SECONDS), s_prevRedPrice, minProfit, InpHLineEndedProfitThresholdUSD, mult);
     }

   // Check if Green line ended on this tick
   if(s_prevGreenActive && !curGreenActive)
     {
      g_lastHLineEndedTime      = TimeCurrent();
      g_lastHLineEndedType      = "GREEN";
      g_lastHLineEndedLineStart = s_prevGreenStart;
      g_lastHLineEndedPrice     = s_prevGreenPrice;
      PrintFormat(">>> [HLINE ENDED TRIGGER] GREEN Line ended (Start: %s, Price=%.2f). Market unpredictable -> Modifying open orders (profit > $%.2f [Base=$%.2f x Mult=%.0f]) SL to live price!",
                  TimeToString(s_prevGreenStart, TIME_DATE|TIME_SECONDS), s_prevGreenPrice, minProfit, InpHLineEndedProfitThresholdUSD, mult);
     }

   // Synchronize with ended line tracking from UpdateLiquiditySweepDetectorOnChart
   static datetime s_lastHandledEndedEqHighTime = 0;
   static datetime s_lastHandledEndedEqLowTime  = 0;
   if(g_endedEqHighTime > 0 && g_endedEqHighTime != s_lastHandledEndedEqHighTime)
     {
      s_lastHandledEndedEqHighTime = g_endedEqHighTime;
      g_lastHLineEndedTime         = g_endedEqHighTime;
      g_lastHLineEndedType         = "RED";
      g_lastHLineEndedLineStart    = g_endedEqHighStart;
      g_lastHLineEndedPrice        = g_endedEqHighPrice;
     }
   if(g_endedEqLowTime > 0 && g_endedEqLowTime != s_lastHandledEndedEqLowTime)
     {
      s_lastHandledEndedEqLowTime  = g_endedEqLowTime;
      g_lastHLineEndedTime         = g_endedEqLowTime;
      g_lastHLineEndedType         = "GREEN";
      g_lastHLineEndedLineStart    = g_endedEqLowStart;
      g_lastHLineEndedPrice        = g_endedEqLowPrice;
     }

   // Update previous tracking state
   s_prevRedActive   = curRedActive;
   s_prevRedStart    = curRedStart;
   s_prevRedPrice    = curRedPrice;
   s_prevGreenActive = curGreenActive;
   s_prevGreenStart  = curGreenStart;
   s_prevGreenPrice  = curGreenPrice;

   // If a new horizontal line is active on chart, the ended-line unpredictable phase is superseded by active line logic
   if(curRedActive || curGreenActive)
      return;

   // Check if any horizontal line has ended
   if(g_lastHLineEndedTime <= 0)
      return;

   int elapsedSec = (int)(TimeCurrent() - g_lastHLineEndedTime);
   if(InpHLineEndedActiveWindowSeconds > 0 && elapsedSec > InpHLineEndedActiveWindowSeconds)
      return;

   RefreshRates();

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);
   double minStopDist = GetRequiredStopDistance();
   if(minStopDist < Point * 10)
      minStopDist = Point * 10;
   double minModGap = GetEffectiveMinSLModifyGap();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      int tkt = OrderTicket();
      double netPL = OrderProfit() + OrderSwap() + OrderCommission();
      if(netPL <= minProfit)
         continue;

      double oOpen = OrderOpenPrice();
      double curSL = OrderStopLoss();
      double curTP = OrderTakeProfit();

      // Case 1: BUY order with individual profit > $0.50 -> modify SL to Live Price (Bid - minStopDist)
      if(oType == OP_BUY)
        {
         double targetSL = NormalizeDouble(curBid - minStopDist, Digits);
         if(targetSL < curBid && (curSL <= 0.0 || (targetSL > curSL + minModGap)))
           {
            bool ok = SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrLimeGreen, "HLineLiveSL_Ended_Buy");
            if(ok)
              {
               PrintFormat(">>> [HLINE ENDED LIVE SL] %s Line Ended (elapsed=%ds): BUY #%d SL modified to Live Price (Bid-StopDist=%.2f) | Profit=+$%.2f > $%.2f",
                           g_lastHLineEndedType, elapsedSec, tkt, targetSL, netPL, minProfit);
              }
           }
        }
      // Case 2: SELL order with individual profit > $0.50 -> modify SL to Live Price (Ask + minStopDist)
      else if(oType == OP_SELL)
        {
         double targetSL = NormalizeDouble(curAsk + minStopDist, Digits);
         if(targetSL > curAsk && (curSL <= 0.0 || (targetSL < curSL - minModGap)))
           {
            bool ok = SafeOrderModify(tkt, oOpen, targetSL, curTP, 0, clrTomato, "HLineLiveSL_Ended_Sell");
            if(ok)
              {
               PrintFormat(">>> [HLINE ENDED LIVE SL] %s Line Ended (elapsed=%ds): SELL #%d SL modified to Live Price (Ask+StopDist=%.2f) | Profit=+$%.2f > $%.2f",
                           g_lastHLineEndedType, elapsedSec, tkt, targetSL, netPL, minProfit);
              }
           }
        }
     }
  }

