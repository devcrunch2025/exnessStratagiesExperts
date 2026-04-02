//+------------------------------------------------------------------+
//| V_TV_SeqCloseOrders.mqh                                          |
//| Closes SELL and BUY orders on profit target or stop loss         |
//| Separate profit/loss targets for SELL and BUY                    |
//+------------------------------------------------------------------+
#ifndef V_TV_SEQ_CLOSE_ORDERS_MQH
#define V_TV_SEQ_CLOSE_ORDERS_MQH

//--- Inputs ----------------------------------------------------------
// All lot/risk inputs are in V_TV_LotVariables.mqh:
// SeqSellProfitTarget, SeqSellStopLossUSD, SeqBuyProfitTarget, SeqBuyStopLossUSD,
// SeqSellMaxOrders, SeqBuyMaxOrders, SeqCloseSlippage
input string _SeqClose_ = "--- SEQ CLOSE ORDERS ---";

// Track which tickets already had partial close this session (avoid repeat)
int g_partialClosedTickets[];
int g_partialClosedCount = 0;

bool IsPartialAlreadyClosed(int ticket)
  {
   for(int i = 0; i < g_partialClosedCount; i++)
      if(g_partialClosedTickets[i] == ticket) return true;
   return false;
  }

void MarkPartialClosed(int ticket)
  {
   ArrayResize(g_partialClosedTickets, g_partialClosedCount + 1);
   g_partialClosedTickets[g_partialClosedCount++] = ticket;
  }

//+------------------------------------------------------------------+
//| Close a single order with appropriate price                      |
//+------------------------------------------------------------------+
void CloseOrder(int ticket, double profit, string reason)
  {
   double closePrice = (OrderType() == OP_SELL)
                       ? MarketInfo(Symbol(), MODE_ASK)
                       : MarketInfo(Symbol(), MODE_BID);
   color clr = (profit >= 0) ? clrGreen : clrRed;

   bool closed = OrderClose(ticket, OrderLots(), closePrice, SeqCloseSlippage, clr);

   if(closed)
      Print("SeqClose | #" + IntegerToString(ticket) +
            " [" + (OrderType() == OP_SELL ? "SELL" : "BUY") + "]" +
            " closed [" + reason + "] P/L=" + DoubleToString(profit,2));
   else
      Print("SeqClose | FAILED #" + IntegerToString(ticket) +
            " [" + reason + "] Error=" + IntegerToString(GetLastError()));
  }

//+------------------------------------------------------------------+
//| Partial profit close — called every tick                        |
//| Closes PartialProfitCloseRatio of lot when profit >= trigger $  |
//| Each order is only partially closed ONCE per session            |
//+------------------------------------------------------------------+
void ProcessPartialProfitClose()
  {
   if(!EnablePartialProfit) return;

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol())                   continue;

      int magicNo = OrderMagicNumber();
      if(magicNo != SeqSellMagicNo && magicNo != SeqBuyMagicNo) continue;

      int orderType = OrderType();
      if(orderType != OP_SELL && orderType != OP_BUY) continue;

      int ticket = OrderTicket();
      if(IsPartialAlreadyClosed(ticket)) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit < PartialProfitTriggerUSD) continue;

      // Calculate partial lot to close
      double fullLot     = OrderLots();
      double partialLot  = NormalizeDouble(fullLot * PartialProfitCloseRatio, 2);

      // Round to lot step and enforce minimum
      partialLot = MathFloor(partialLot / lotStep) * lotStep;
      partialLot = NormalizeDouble(partialLot, 2);

      if(partialLot < minLot)
        {
         Print("SeqClose | PARTIAL SKIP #" + IntegerToString(ticket) +
               " partialLot=" + DoubleToString(partialLot,2) +
               " < minLot=" + DoubleToString(minLot,2) + " — closing full order instead");
         // Lot too small to partial close — close full order
         CloseOrder(ticket, profit, "PARTIAL->FULL profit=$" + DoubleToString(profit,2) +
                    " >= $" + DoubleToString(PartialProfitTriggerUSD,2));
         MarkPartialClosed(ticket);
         continue;
        }

      double closePrice = (orderType == OP_SELL)
                          ? MarketInfo(Symbol(), MODE_ASK)
                          : MarketInfo(Symbol(), MODE_BID);

      bool closed = OrderClose(ticket, partialLot, closePrice, SeqCloseSlippage, clrGold);

      if(closed)
        {
         MarkPartialClosed(ticket);
         Print("SeqClose | *** PARTIAL PROFIT *** #" + IntegerToString(ticket) +
               " [" + (orderType == OP_SELL ? "SELL" : "BUY") + "]" +
               " closed " + DoubleToString(partialLot,2) + " of " + DoubleToString(fullLot,2) + " lot" +
               " | profit=$" + DoubleToString(profit,2) +
               " >= trigger=$" + DoubleToString(PartialProfitTriggerUSD,2) +
               " | remaining lot=" + DoubleToString(fullLot - partialLot,2));
        }
      else
         Print("SeqClose | PARTIAL FAILED #" + IntegerToString(ticket) +
               " Error=" + IntegerToString(GetLastError()));
     }
  }
//+------------------------------------------------------------------+
//| Pattern-triggered close: called when a CLOSE rule matches       |
//| checkProfit=false (default) → close immediately regardless      |
//| checkProfit=true            → only close if profit >= target     |
//+------------------------------------------------------------------+
void ProcessPatternClose(string tradeType, string patternLabel,
                         bool checkProfit = false)
  {
   int    closeType   = (tradeType == "SELL") ? OP_SELL : OP_BUY;
   int    magicClose  = (tradeType == "SELL") ? SeqSellMagicNo : SeqBuyMagicNo;
   double profitTarget= (tradeType == "SELL") ? SeqSellProfitTarget : SeqBuyProfitTarget;

   int closed  = 0;
   int skipped = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol()      != Symbol())   continue;
      if(OrderMagicNumber() != magicClose) continue;
      if(OrderType()        != closeType)  continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(checkProfit && profit < profitTarget)
        {
         Print("SeqClose | PATTERN CLOSE [" + patternLabel + "] SKIPPED #" +
               IntegerToString(OrderTicket()) + " profit=$" + DoubleToString(profit,2) +
               " < target=$" + DoubleToString(profitTarget,2));
         skipped++;
         continue;
        }

      CloseOrder(OrderTicket(), profit, "PATTERN CLOSE [" + patternLabel + "] P/L=$" +
                 DoubleToString(profit,2));
      closed++;
     }

   if(closed > 0)
      Print("SeqClose | PATTERN CLOSE [" + patternLabel + "] closed " +
            IntegerToString(closed) + " " + tradeType + " order(s)" +
            (skipped > 0 ? " | " + IntegerToString(skipped) + " skipped (below target)" : ""));
   else if(skipped > 0)
      Print("SeqClose | PATTERN CLOSE [" + patternLabel + "] no " + tradeType +
            " orders at profit target — none closed");
   else
      Print("SeqClose | PATTERN CLOSE [" + patternLabel + "] no open " + tradeType + " orders found");
  }

//+------------------------------------------------------------------+
//| Main entry: called every tick                                    |
//+------------------------------------------------------------------+
void ProcessSeqCloseOrders()
  {
   // --- 0. Partial profit booking (every tick, once per ticket) ---
   ProcessPartialProfitClose();

   // --- 1a. SeqRule pattern-triggered close (action = "CLOSE") ---
   int ruleIdx = CheckSeqRules();
   if(ruleIdx >= 0 && g_seqRules[ruleIdx].action == "CLOSE")
     {
      string patLabel = g_seqRules[ruleIdx].prePrev + "|" +
                        g_seqRules[ruleIdx].prev    + "|" +
                        g_seqRules[ruleIdx].curr;
      ProcessPatternClose(g_seqRules[ruleIdx].tradeType, patLabel);
     }

  

   // --- 2. TP / SL threshold close (runs always) ---
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol())                   continue;

      int magicNo = OrderMagicNumber();
      if(magicNo != SeqSellMagicNo && magicNo != SeqBuyMagicNo) continue;

      int    orderType = OrderType();
      if(orderType != OP_SELL && orderType != OP_BUY)           continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      int    ticket = OrderTicket();

      if(orderType == OP_SELL)
        {
         if(profit >= SeqSellProfitTarget)
            CloseOrder(ticket, profit, "SELL PROFIT TARGET $" + DoubleToString(SeqSellProfitTarget,2));
         else if(profit <= -SeqSellStopLossUSD)
            CloseOrder(ticket, profit, "SELL STOP LOSS $" + DoubleToString(SeqSellStopLossUSD,2));
        }
      else // OP_BUY
        {
         if(profit >= SeqBuyProfitTarget)
            CloseOrder(ticket, profit, "BUY PROFIT TARGET $" + DoubleToString(SeqBuyProfitTarget,2));
         else if(profit <= -SeqBuyStopLossUSD)
            CloseOrder(ticket, profit, "BUY STOP LOSS $" + DoubleToString(SeqBuyStopLossUSD,2));
        }
     }

      // --- 1b. ColorRule pattern-triggered close ---
   // Check SELL close (red signal closes SELL orders)
   int cIdxSell = CheckColorRules("CLOSE", "SELL");
   if(cIdxSell >= 0)
     {
      string label = g_colorRules[cIdxSell].colorType + " COUNT>=" +
                     IntegerToString(g_colorRules[cIdxSell].minCount);
      ProcessPatternClose("SELL", label);
     }
   // Check BUY close (green signal closes BUY orders)
   int cIdxBuy = CheckColorRules("CLOSE", "BUY");
   if(cIdxBuy >= 0)
     {
      string label = g_colorRules[cIdxBuy].colorType + " COUNT>=" +
                     IntegerToString(g_colorRules[cIdxBuy].minCount);
      ProcessPatternClose("BUY", label);
     }


     SeqBuyProfitTarget=DefaultBuyTP;
SeqSellProfitTarget=DefaultSellTP;
  }

#endif
