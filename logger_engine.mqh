//+------------------------------------------------------------------+
//| TESTER & LIVE ORDER LOGGER ENGINE                                |
//| High-Performance, Zero-Lag Trade Analysis Engine                |
//| Generates independent Live & Testing logs with loss explanations |
//+------------------------------------------------------------------+

struct OrderCloseReasonRecord
  {
   int    ticket;
   string reason;
  };
OrderCloseReasonRecord g_orderCloseReasonRegistry[500];
int g_orderCloseReasonCount = 0;

struct BasketOutcomeRecord
  {
   int    parentTicket;
   int    recoveryTicket;
   double netProfit;
  };
BasketOutcomeRecord g_basketOutcomeRegistry[300];
int g_basketOutcomeCount = 0;

struct ActiveOrderLogInfo
  {
   int      ticket;
   double   openEmaDist;
   int      openEmaDir;
  };
ActiveOrderLogInfo g_activeOrderLogInfo[500];
int g_activeOrderLogCount = 0;

int g_loggedHistoryTickets[3000];
int g_loggedHistoryTicketsCount = 0;

//+------------------------------------------------------------------+
//| GetActiveLogFileName: Dynamically selects Live vs Tester CSV     |
//+------------------------------------------------------------------+
string GetActiveLogFileName()
  {
   return (IsTesting() ? InpTesterLogFileName : InpLiveLogFileName);
  }

//+------------------------------------------------------------------+
//| GetActiveSummaryFileName: Dynamically selects Live vs Tester TXT |
//+------------------------------------------------------------------+
string GetActiveSummaryFileName()
  {
   return (IsTesting() ? InpTesterSummaryFileName : InpLiveSummaryFileName);
  }

//+------------------------------------------------------------------+
//| SanitizeCsvField: Replaces delimiters to preserve CSV formatting |
//+------------------------------------------------------------------+
string SanitizeCsvField(string text)
  {
   string res = text;
   int len = StringLen(res);
   for(int i = 0; i < len; i++)
     {
      ushort ch = StringGetChar(res, i);
      if(ch == ',' || ch == '\r' || ch == '\n' || ch == '"')
         StringSetCharacter(res, i, ';');
     }
   return res;
  }

//+------------------------------------------------------------------+
//| WriteReportLineToFile: Writes line to local Files & Common\Files |
//+------------------------------------------------------------------+
void WriteReportLineToFile(string fileName, string lineText, bool appendMode)
  {
   // 1. Write to local MT4 files (MQL4\Files in live, tester\files in Strategy Tester)
   int flags = FILE_TXT | FILE_SHARE_READ;
   if(appendMode)
      flags |= (FILE_READ | FILE_WRITE);
   else
      flags |= FILE_WRITE;

   int handle = FileOpen(fileName, flags);
   if(handle == INVALID_HANDLE && appendMode)
      handle = FileOpen(fileName, FILE_TXT | FILE_WRITE | FILE_SHARE_READ);

   if(handle != INVALID_HANDLE)
     {
      if(appendMode)
         FileSeek(handle, 0, SEEK_END);
      FileWriteString(handle, lineText + "\r\n");
      FileClose(handle);
     }

   // 2. Also write to Common\Files (accessible globally outside tester sandbox)
   if(InpLogToCommonFolder)
     {
      int commonFlags = FILE_TXT | FILE_SHARE_READ | FILE_COMMON;
      if(appendMode)
         commonFlags |= (FILE_READ | FILE_WRITE);
      else
         commonFlags |= FILE_WRITE;

      int commonHandle = FileOpen(fileName, commonFlags);
      if(commonHandle == INVALID_HANDLE && appendMode)
         commonHandle = FileOpen(fileName, FILE_TXT | FILE_WRITE | FILE_SHARE_READ | FILE_COMMON);

      if(commonHandle != INVALID_HANDLE)
        {
         if(appendMode)
            FileSeek(commonHandle, 0, SEEK_END);
         FileWriteString(commonHandle, lineText + "\r\n");
         FileClose(commonHandle);
        }
     }
  }

//+------------------------------------------------------------------+
//| RecordOrderCloseReason: Registers explicit close reason          |
//+------------------------------------------------------------------+
void RecordOrderCloseReason(int ticket, string reason)
  {
   if(ticket <= 0) return;
   for(int i = 0; i < g_orderCloseReasonCount; i++)
     {
      if(g_orderCloseReasonRegistry[i].ticket == ticket)
        {
         g_orderCloseReasonRegistry[i].reason = reason;
         return;
        }
     }
   if(g_orderCloseReasonCount < 500)
     {
      g_orderCloseReasonRegistry[g_orderCloseReasonCount].ticket = ticket;
      g_orderCloseReasonRegistry[g_orderCloseReasonCount].reason = reason;
      g_orderCloseReasonCount++;
     }
  }

//+------------------------------------------------------------------+
//| GetOrderCloseReason: Retrieves registered explicit close reason  |
//+------------------------------------------------------------------+
string GetOrderCloseReason(int ticket)
  {
   for(int i = 0; i < g_orderCloseReasonCount; i++)
     {
      if(g_orderCloseReasonRegistry[i].ticket == ticket)
         return g_orderCloseReasonRegistry[i].reason;
     }
   return "";
  }

//+------------------------------------------------------------------+
//| RecordBasketOutcome: Records parent/child basket net result      |
//+------------------------------------------------------------------+
void RecordBasketOutcome(int parentTicket, int recoveryTicket, double netProfit)
  {
   if(parentTicket <= 0 || recoveryTicket <= 0) return;
   if(g_basketOutcomeCount < 300)
     {
      g_basketOutcomeRegistry[g_basketOutcomeCount].parentTicket   = parentTicket;
      g_basketOutcomeRegistry[g_basketOutcomeCount].recoveryTicket = recoveryTicket;
      g_basketOutcomeRegistry[g_basketOutcomeCount].netProfit      = netProfit;
      g_basketOutcomeCount++;
     }
  }

//+------------------------------------------------------------------+
//| IsTicketRescuedInProfitableBasket: Checks if order was in basket |
//+------------------------------------------------------------------+
bool IsTicketRescuedInProfitableBasket(int ticket, double &outBasketNetProfit, int &outRecoveryTicket)
  {
   for(int i = 0; i < g_basketOutcomeCount; i++)
     {
      if(g_basketOutcomeRegistry[i].parentTicket == ticket)
        {
         outBasketNetProfit = g_basketOutcomeRegistry[i].netProfit;
         outRecoveryTicket  = g_basketOutcomeRegistry[i].recoveryTicket;
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| RegisterActiveOrderForLog: Captures indicator state at open time |
//+------------------------------------------------------------------+
void RegisterActiveOrderForLog(int ticket)
  {
   if(ticket <= 0) return;
   for(int i = 0; i < g_activeOrderLogCount; i++)
     {
      if(g_activeOrderLogInfo[i].ticket == ticket)
         return; // Already registered
     }
   if(g_activeOrderLogCount < 500)
     {
      g_activeOrderLogInfo[g_activeOrderLogCount].ticket = ticket;
      double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
      g_activeOrderLogInfo[g_activeOrderLogCount].openEmaDist = (ema > 0.0) ? MathAbs(Close[0] - ema) : 0.0;
      g_activeOrderLogInfo[g_activeOrderLogCount].openEmaDir  = EMADirection;
      g_activeOrderLogCount++;
     }
  }

//+------------------------------------------------------------------+
//| IsOrderAlreadyLogged: Prevents duplicate logging of same ticket  |
//+------------------------------------------------------------------+
bool IsOrderAlreadyLogged(int ticket)
  {
   for(int i = 0; i < g_loggedHistoryTicketsCount; i++)
     {
      if(g_loggedHistoryTickets[i] == ticket)
         return true;
     }
   return false;
  }

void MarkOrderAsLogged(int ticket)
  {
   if(g_loggedHistoryTicketsCount < 3000)
     {
      g_loggedHistoryTickets[g_loggedHistoryTicketsCount] = ticket;
      g_loggedHistoryTicketsCount++;
     }
  }

//+------------------------------------------------------------------+
//| CategorizeOrderStrategy: Identifies strategy from comment/ticket |
//+------------------------------------------------------------------+
string CategorizeOrderStrategy(int ticket, string comment)
  {
   string effComment = GetRootOrderComment(ticket, comment);
   if(StringFind(effComment, "_TYPE3") >= 0)
      return "RECOVERY_TYPE3";
   if(StringFind(effComment, "_LSD") >= 0)
      return "RECOVERY_TYPE2_LSD";
   if(StringFind(effComment, "RECOVERY_") == 0)
      return "RECOVERY_TYPE1";
   if(IsFLIPBasketSupportOrder(ticket, effComment))
      return "FLIP_SUPPORT";
   if(StringFind(effComment, "ReEntry") >= 0)
      return "REENTRY";
   if(StringFind(effComment, "SSL Long") >= 0)
      return "SSL_LONG";
   if(StringFind(effComment, "SSL Short") >= 0)
      return "SSL_SHORT";
   return "OTHER";
  }

//+------------------------------------------------------------------+
//| DetermineOrderCloseReason: Classifies exact exit trigger         |
//+------------------------------------------------------------------+
string DetermineOrderCloseReason(int ticket, string comment, double openPrice, double closePrice, double sl, double tp, double netProfit, string strategy)
  {
   // 1. Explicit registered reason
   string explicitReason = GetOrderCloseReason(ticket);
   if(explicitReason != "")
      return explicitReason;

   // 2. MT4 broker comments [sl] / [tp]
   bool hasSlComment = (StringFind(comment, "[sl]") >= 0 || StringFind(comment, "[sl ") >= 0);
   bool hasTpComment = (StringFind(comment, "[tp]") >= 0 || StringFind(comment, "[tp ") >= 0);

   if(hasTpComment || (tp > 0.0 && MathAbs(closePrice - tp) <= Point * 10))
      return "TAKE_PROFIT_HIT";

   if(hasSlComment || (sl > 0.0 && MathAbs(closePrice - sl) <= Point * 10))
     {
      if(netProfit > 0.05)
         return "STEP_TRAILING_SL_PROFIT";
      if(MathAbs(netProfit) <= 0.05)
         return "STEP_TRAILING_SL_BE";
      return "STOP_LOSS_HIT";
     }

   // 3. Fallback based on outcome
   if(netProfit > 0.05)
      return "PROFIT_CLOSE_LOGIC";
   if(netProfit < -0.05)
      return "LOSS_CLOSE_LOGIC";
   return "BREAKEVEN_CLOSE";
  }

//+------------------------------------------------------------------+
//| ExplainLossReasonWithinTick: Clear human explanation of loss     |
//+------------------------------------------------------------------+
string ExplainLossReasonWithinTick(int ticket, double netProfit, string exitReason, double openPrice, double closePrice, double sl, double tp, string strategy, string comment)
  {
   if(netProfit >= -0.05)
      return "None - Trade was profitable (+$" + DoubleToString(netProfit, 2) + ")";

   // 1. Check if this losing trade was rescued by a profitable recovery basket
   double basketNet = 0.0;
   int recTicket = 0;
   if(IsTicketRescuedInProfitableBasket(ticket, basketNet, recTicket))
     {
      return "Rescued in Recovery Basket with #" + IntegerToString(recTicket) + " (Basket Net Profit: +$" + DoubleToString(basketNet, 2) + " WIN)";
     }

   // 2. Initial StopLoss hit
   if(exitReason == "STOP_LOSS_HIT" || (sl > 0.0 && MathAbs(closePrice - sl) <= Point * 10))
     {
      double rawLossGap = MathAbs(closePrice - openPrice);
      return "Initial SL ($" + DoubleToString(rawLossGap, 1) + " raw gap) hit due to adverse market move";
     }

   // 3. Trailing StopLoss Breakeven / Pullback
   if(exitReason == "STEP_TRAILING_SL_BE")
     {
      return "Price reversed after +100 move and hit breakeven step-trailing stop";
     }

   // 4. Trend Flip / Signal change
   if(exitReason == "OPPOSITE_FLIP_CLOSE" || StringFind(exitReason, "FLIP") >= 0)
     {
      return "Closed on EMA/SSL trend flip to prevent deeper drawdown";
     }

   // 5. Daily profit ladder reset
   if(StringFind(exitReason, "LADDER") >= 0)
     {
      return "Closed during Daily Profit Ladder target cleanup";
     }

   return "Adverse market move closed by logic (-$" + DoubleToString(MathAbs(netProfit), 2) + ")";
  }

//+------------------------------------------------------------------+
//| InitTesterOrderLogger: Initializes report files and registry     |
//+------------------------------------------------------------------+
void InitTesterOrderLogger()
  {
   if(!InpEnableOrderLogger)
      return;

   g_orderCloseReasonCount     = 0;
   g_basketOutcomeCount        = 0;
   g_activeOrderLogCount       = 0;
   g_loggedHistoryTicketsCount = 0;

   string csvFileName     = GetActiveLogFileName();
   string summaryFileName = GetActiveSummaryFileName();

   string csvHeader = "Ticket,ParentTicket,Symbol,Type,Lots,OpenTime,OpenPrice,CloseTime,ClosePrice,DurationMin,NetProfitUSD,Outcome,MethodName,ExitReason,LossReasonWithinTick,WasLossInBasketNetWin,StopLoss,TakeProfit,OpenEmaDist,CloseEmaDist,EmaDirClose,EmaFlipElapsedMin,OrderComment";

   // If testing, reset CSV and summary header
   if(IsTesting())
     {
      WriteReportLineToFile(csvFileName, csvHeader, false);
      string initialSummary = "=== MetaTrader 4 Strategy Tester Log Started: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " ===";
      WriteReportLineToFile(summaryFileName, initialSummary, false);
      Print(">>> [ORDER LOGGER] Strategy Tester logger initialized: ", csvFileName, " and ", summaryFileName);
     }
   else
     {
      // In live/demo mode, ensure CSV header exists without erasing historical logs
      int flags = FILE_TXT | FILE_READ | FILE_SHARE_READ;
      int testHandle = FileOpen(csvFileName, flags);
      if(testHandle == INVALID_HANDLE)
         WriteReportLineToFile(csvFileName, csvHeader, false);
      else
         FileClose(testHandle);

      // Mark existing history orders so only trades from THIS live session are logged
      int totalHist = OrdersHistoryTotal();
      for(int i = 0; i < totalHist; i++)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            MarkOrderAsLogged(OrderTicket());
        }
      Print(">>> [ORDER LOGGER] Live order logger initialized (", csvFileName, "). Existing history marked: ", totalHist, " orders.");
     }
  }

//+------------------------------------------------------------------+
//| ProcessOrderLoggerTick: Decoupled Zero-Lag tick processor        |
//+------------------------------------------------------------------+
void ProcessOrderLoggerTick()
  {
   if(!InpEnableOrderLogger)
      return;

   // ULTRA-FAST GUARD: If order counts have not changed, return in 0.00 ms
   static int s_lastKnownHistTotal = -1;
   static int s_lastKnownOpenTotal = -1;

   int curHistTotal = OrdersHistoryTotal();
   int curOpenTotal = OrdersTotal();

   if(curHistTotal == s_lastKnownHistTotal && curOpenTotal == s_lastKnownOpenTotal)
      return;

   // 1. If open orders changed, register any newly opened active orders
   if(curOpenTotal != s_lastKnownOpenTotal)
     {
      for(int i = curOpenTotal - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         RegisterActiveOrderForLog(OrderTicket());
        }
      s_lastKnownOpenTotal = curOpenTotal;
     }

   // 2. If history orders changed, log newly closed orders
   if(curHistTotal != s_lastKnownHistTotal)
     {
      int startIdx = (s_lastKnownHistTotal > 0) ? s_lastKnownHistTotal : 0;
      for(int h = startIdx; h < curHistTotal; h++)
        {
         if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         int oType = OrderType();
         if(oType != OP_BUY && oType != OP_SELL)
            continue;

         int ticket = OrderTicket();
         if(IsOrderAlreadyLogged(ticket))
            continue;

         LogClosedOrderRecord(ticket);
         MarkOrderAsLogged(ticket);
        }
      s_lastKnownHistTotal = curHistTotal;
     }
  }

//+------------------------------------------------------------------+
//| LogClosedOrderRecord: Formats and writes closed order to CSV     |
//+------------------------------------------------------------------+
void LogClosedOrderRecord(int ticket)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
      return;

   string symbol     = OrderSymbol();
   int    oType      = OrderType();
   string typeStr    = (oType == OP_BUY ? "BUY" : "SELL");
   double lots       = OrderLots();
   datetime openTime = OrderOpenTime();
   double openPrice  = OrderOpenPrice();
   datetime closeTime= OrderCloseTime();
   double closePrice = OrderClosePrice();
   double sl         = OrderStopLoss();
   double tp         = OrderTakeProfit();
   double grossProfit= OrderProfit();
   double swap       = OrderSwap();
   double comm       = OrderCommission();
   double netProfit  = grossProfit + swap + comm;
   double durMin     = (closeTime > openTime) ? ((closeTime - openTime) / 60.0) : 0.0;
   string rawComment = OrderComment();

   string strategy = CategorizeOrderStrategy(ticket, rawComment);
   string reason   = DetermineOrderCloseReason(ticket, rawComment, openPrice, closePrice, sl, tp, netProfit, strategy);

   int parentTicket = 0;
   if(StringFind(strategy, "RECOVERY") >= 0)
      parentTicket = GetRecoveryOrderParentTicket(ticket, rawComment);

   double basketNet = 0.0;
   int recTicket = 0;
   bool wasRescuedInBasket = IsTicketRescuedInProfitableBasket(ticket, basketNet, recTicket);

   string outcome = "BREAKEVEN";
   if(wasRescuedInBasket)
      outcome = "BASKET_NET_WIN";
   else if(netProfit > 0.05)
      outcome = "PROFIT_WIN";
   else if(netProfit < -0.05)
      outcome = "LOSS";

   string lossExplanation = ExplainLossReasonWithinTick(ticket, netProfit, reason, openPrice, closePrice, sl, tp, strategy, rawComment);

   double openEmaDist = 0.0;
   int    openEmaDir  = 0;
   for(int a = 0; a < g_activeOrderLogCount; a++)
     {
      if(g_activeOrderLogInfo[a].ticket == ticket)
        {
         openEmaDist = g_activeOrderLogInfo[a].openEmaDist;
         openEmaDir  = g_activeOrderLogInfo[a].openEmaDir;
         break;
        }
     }

   double closeEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double closeEmaDist = (closeEma > 0.0) ? MathAbs(closePrice - closeEma) : 0.0;
   int closeEmaDir = EMADirection;

   datetime flipTime = EmaFlipTime;
   if(flipTime == 0) flipTime = GetActualEmaFlipTime(EMADirection);
   int flipElapsedMin = (flipTime > 0 && closeTime >= flipTime) ? (int)((closeTime - flipTime) / 60) : 0;

   // CSV Columns: Ticket,ParentTicket,Symbol,Type,Lots,OpenTime,OpenPrice,CloseTime,ClosePrice,DurationMin,NetProfitUSD,Outcome,MethodName,ExitReason,LossReasonWithinTick,WasLossInBasketNetWin,StopLoss,TakeProfit,OpenEmaDist,CloseEmaDist,EmaDirClose,EmaFlipElapsedMin,OrderComment
   string csvLine = StringFormat("%d,%d,%s,%s,%.2f,%s,%.2f,%s,%.2f,%.1f,%.2f,%s,%s,%s,%s,%s,%.2f,%.2f,%.1f,%.1f,%d,%d,%s",
                                 ticket, parentTicket, symbol, typeStr, lots,
                                 TimeToString(openTime, TIME_DATE|TIME_SECONDS), openPrice,
                                 TimeToString(closeTime, TIME_DATE|TIME_SECONDS), closePrice,
                                 durMin, netProfit, outcome, strategy,
                                 SanitizeCsvField(reason), SanitizeCsvField(lossExplanation),
                                 (wasRescuedInBasket ? "YES" : "NO"),
                                 sl, tp, openEmaDist, closeEmaDist, closeEmaDir, flipElapsedMin,
                                 SanitizeCsvField(rawComment));

   WriteReportLineToFile(GetActiveLogFileName(), csvLine, true);

   Print(">>> [ORDER LOGGED] #", ticket, " Method=", strategy, " ", typeStr, " Lots=", DoubleToString(lots, 2),
         " Net=$", DoubleToString(netProfit, 2), " [", outcome, "] Reason: ", reason,
         " | Explanation: ", lossExplanation);
  }

//+------------------------------------------------------------------+
//| GenerateTesterSummaryReport: Generates detailed summary table    |
//+------------------------------------------------------------------+
void GenerateTesterSummaryReport()
  {
   if(!InpEnableOrderLogger)
      return;

   // Flush any remaining closed orders
   ProcessOrderLoggerTick();

   int totalOrders = 0;
   int winCount    = 0;
   int lossCount   = 0;
   int beCount     = 0;
   int basketWins  = 0;
   double grossProfit = 0.0;
   double grossLoss   = 0.0;
   double netTotal    = 0.0;

   // Strategy counters: [0]=SSL_MAIN, [1]=REENTRY, [2]=TYPE1, [3]=TYPE2_LSD, [4]=TYPE3_EMA, [5]=FLIP_SUPPORT, [6]=OTHER
   int stratTotal[7];
   int stratWins[7];
   int stratLosses[7];
   double stratNet[7];
   ArrayInitialize(stratTotal, 0);
   ArrayInitialize(stratWins, 0);
   ArrayInitialize(stratLosses, 0);
   ArrayInitialize(stratNet, 0.0);

   // Exit reason counters: [0]=SL_HIT, [1]=TRAILING_SL, [2]=TP_HIT, [3]=RECOVERY_BASKET, [4]=SCALP_PROFIT, [5]=BASKET_PROFIT, [6]=OTHER
   int reasonCount[7];
   double reasonNet[7];
   ArrayInitialize(reasonCount, 0);
   ArrayInitialize(reasonNet, 0.0);

   int histTotal = OrdersHistoryTotal();
   for(int h = 0; h < histTotal; h++)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;

      int ticket     = OrderTicket();
      double profit  = OrderProfit() + OrderSwap() + OrderCommission();
      string comment = OrderComment();
      string strat   = CategorizeOrderStrategy(ticket, comment);
      string reason  = DetermineOrderCloseReason(ticket, comment, OrderOpenPrice(), OrderClosePrice(), OrderStopLoss(), OrderTakeProfit(), profit, strat);

      double bNet = 0.0;
      int rTkt = 0;
      bool inBasket = IsTicketRescuedInProfitableBasket(ticket, bNet, rTkt);

      totalOrders++;
      netTotal += profit;
      if(inBasket)
         basketWins++;
      else if(profit > 0.05)
        {
         winCount++;
         grossProfit += profit;
        }
      else if(profit < -0.05)
        {
         lossCount++;
         grossLoss += profit;
        }
      else
         beCount++;

      // Strat index
      int sIdx = 6;
      if(strat == "SSL_LONG" || strat == "SSL_SHORT") sIdx = 0;
      else if(strat == "REENTRY")                     sIdx = 1;
      else if(strat == "RECOVERY_TYPE1")              sIdx = 2;
      else if(strat == "RECOVERY_TYPE2_LSD")          sIdx = 3;
      else if(strat == "RECOVERY_TYPE3")              sIdx = 4;
      else if(strat == "FLIP_SUPPORT")                sIdx = 5;

      stratTotal[sIdx]++;
      stratNet[sIdx] += profit;
      if(profit > 0.05 || inBasket) stratWins[sIdx]++;
      else if(profit < -0.05) stratLosses[sIdx]++;

      // Reason index
      int rIdx = 6;
      if(StringFind(reason, "STOP_LOSS_HIT") >= 0)           rIdx = 0;
      else if(StringFind(reason, "STEP_TRAILING_SL") >= 0)   rIdx = 1;
      else if(StringFind(reason, "TAKE_PROFIT_HIT") >= 0)    rIdx = 2;
      else if(StringFind(reason, "RECOVERY_BASKET") >= 0)    rIdx = 3;
      else if(StringFind(reason, "SCALP_SECURE_1") >= 0)     rIdx = 4;
      else if(StringFind(reason, "BASKET_PROFIT") >= 0)      rIdx = 5;

      reasonCount[rIdx]++;
      reasonNet[rIdx] += profit;
     }

   int effectiveWins = winCount + basketWins;
   double winRate = (totalOrders > 0) ? ((double)effectiveWins / totalOrders * 100.0) : 0.0;
   double profitFactor = (MathAbs(grossLoss) > 0.0) ? (grossProfit / MathAbs(grossLoss)) : (grossProfit > 0.0 ? 999.0 : 0.0);

   string sep = "========================================================================================";
   string subSep = "----------------------------------------------------------------------------------------";
   string summaryFileName = GetActiveSummaryFileName();

   WriteReportLineToFile(summaryFileName, sep, false);
   WriteReportLineToFile(summaryFileName, (IsTesting() ? "                STRATEGY TESTER ORDER & LOSS ANALYSIS REPORT" : "                LIVE TRADING ORDER & LOSS ANALYSIS REPORT"), true);
   WriteReportLineToFile(summaryFileName, sep, true);
   WriteReportLineToFile(summaryFileName, "Generated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " | Symbol: " + Symbol() + " | Period: " + IntegerToString(Period()) + " | Version: " + glbVersion, true);
   WriteReportLineToFile(summaryFileName, "Account: #" + IntegerToString(AccountNumber()) + " | Balance: $" + DoubleToString(AccountBalance(), 2) + " | Equity: $" + DoubleToString(AccountEquity(), 2), true);
   WriteReportLineToFile(summaryFileName, subSep, true);

   WriteReportLineToFile(summaryFileName, ">>> OVERALL PERFORMANCE METRICS:", true);
   WriteReportLineToFile(summaryFileName, StringFormat("Total Trades Closed : %d", totalOrders), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Effective Winners   : %d (%.2f%%) [Direct Wins=%d, Rescued Basket Wins=%d]", effectiveWins, winRate, winCount, basketWins), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Pure Losing Trades   : %d (%.2f%%)", lossCount, (totalOrders > 0 ? (double)lossCount/totalOrders*100.0 : 0.0)), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Breakeven Trades     : %d", beCount), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Gross Profit         : +$%.2f USD", grossProfit), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Gross Loss           : -$%.2f USD", MathAbs(grossLoss)), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Net Profit           : %s$%.2f USD", (netTotal >= 0 ? "+" : "-"), MathAbs(netTotal)), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Profit Factor        : %.2f", profitFactor), true);
   WriteReportLineToFile(summaryFileName, subSep, true);

   WriteReportLineToFile(summaryFileName, ">>> WHICH METHOD BOOKED PROFITS (METHOD PROFITABILITY ANALYSIS):", true);
   string stratNames[7] = {"1. SSL Regular Orders      ",
                           "2. ReEntry Orders          ",
                           "3. Recovery Type 1 Classic ",
                           "4. Recovery Type 2 (LSD)   ",
                           "5. Recovery Type 3 (WeakEMA)",
                           "6. FLIP Basket Support     ",
                           "7. Other / Scalp           "};
   for(int s = 0; s < 7; s++)
     {
      double sWinRate = (stratTotal[s] > 0) ? ((double)stratWins[s] / stratTotal[s] * 100.0) : 0.0;
      WriteReportLineToFile(summaryFileName,
                            StringFormat("%s : Total=%3d | Wins=%3d (%.1f%%) | Losses=%3d | Net=%s$%.2f USD",
                                         stratNames[s], stratTotal[s], stratWins[s], sWinRate, stratLosses[s],
                                         (stratNet[s] >= 0 ? "+" : "-"), MathAbs(stratNet[s])), true);
     }
   WriteReportLineToFile(summaryFileName, subSep, true);

   WriteReportLineToFile(summaryFileName, ">>> WHY ORDERS LOST / EXITED (LOSS & EXIT TRIGGER ANALYSIS):", true);
   string reasonNames[7] = {"- Stop Loss (SL) Hits       ",
                            "- Step-Trailing SL Profit   ",
                            "- Take Profit (TP) Hits     ",
                            "- Recovery Basket Closes    ",
                            "- Scalp / Secure $1 Closes  ",
                            "- Basket Profit (Net $1)    ",
                            "- Other / Logic Closes      "};
   for(int r = 0; r < 7; r++)
     {
      WriteReportLineToFile(summaryFileName,
                            StringFormat("%s : Count=%3d | Total Net=%s$%.2f USD",
                                         reasonNames[r], reasonCount[r],
                                         (reasonNet[r] >= 0 ? "+" : "-"), MathAbs(reasonNet[r])), true);
     }
   WriteReportLineToFile(summaryFileName, sep, true);

   Print(">>> =================== ORDER & LOSS PERFORMANCE SUMMARY ===================");
   Print(">>> Mode: ", (IsTesting() ? "STRATEGY TESTER" : "LIVE TRADING"), " | Trades: ", totalOrders,
         " | Effective WinRate: ", DoubleToString(winRate, 1), "% | Net Profit: $", DoubleToString(netTotal, 2),
         " | Profit Factor: ", DoubleToString(profitFactor, 2));
   Print(">>> Recorders: T1=$", DoubleToString(stratNet[2], 2), " | T2(LSD)=$", DoubleToString(stratNet[3], 2), " | T3(WeakEMA)=$", DoubleToString(stratNet[4], 2));
   Print(">>> Detailed CSV: ", GetActiveLogFileName(), " | Summary: ", GetActiveSummaryFileName());
   Print(">>> ========================================================================");
  }
