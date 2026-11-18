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

// Cumulative P/L Tracking per Function
double g_cumAccountNetUSD           = 0.0;
double g_cumFuncNet_StepTrailProfit = 0.0;
double g_cumFuncNet_SellBasket      = 0.0;
double g_cumFuncNet_BuyBasket       = 0.0;
double g_cumFuncNet_Combination    = 0.0;
double g_cumFuncNet_RecoveryBasket  = 0.0;
double g_cumFuncNet_BreakevenSL     = 0.0;
double g_cumFuncNet_StopLossHit     = 0.0;
double g_cumFuncNet_LossCloseLogic  = 0.0;
double g_cumFuncNet_RunnerProtect   = 0.0;
double g_cumFuncNet_Other           = 0.0;

// Daily Environment-Separated Logger & Error Tracker State
string   g_loggerActiveDateStamp    = "";
string   g_loggerActiveEnvMode      = "";
int      g_loggerLastCheckedDay     = -1;
int      g_loggerLastKnownHistTotal = -1;
int      g_loggerLastKnownOpenTotal = -1;
int      g_dailyErrorCount          = 0;
int      g_sessionErrorCount        = 0;
int      g_lastLoggedErrorCode      = 0;
string   g_lastLoggedErrorOp        = "";
datetime g_lastLoggedErrorTime      = 0;
string   g_lastDedupErrorKey        = "";
datetime g_lastDedupErrorTime       = 0;
int      g_suppressedErrorRepeats   = 0;
int      g_loggerLastConnState      = -1;
int      g_loggerLastTradeAllowed   = -1;

//+------------------------------------------------------------------+
//| GetLoggerEnvMode: Returns "TESTER", "LIVE", or "DEMO"            |
//+------------------------------------------------------------------+
string GetLoggerEnvMode()
  {
   if(IsTesting() || IsOptimization())
      return "TESTER";
   long tradeMode = AccountInfoInteger(ACCOUNT_TRADE_MODE);
   if(tradeMode == ACCOUNT_TRADE_MODE_REAL && !IsDemo())
      return "LIVE";
   return "DEMO";
  }

//+------------------------------------------------------------------+
//| GetLoggerNowDateTime: Current Dubai datetime (broker + offset)   |
//+------------------------------------------------------------------+
datetime GetLoggerNowDateTime()
  {
   datetime srv = TimeCurrent();
   if(srv > 0)
      return srv + (ServerToDubaiOffsetHours * 3600);
   return TimeLocal();
  }

//+------------------------------------------------------------------+
//| GetLoggerDateStamp: Returns YYYY-MM-DD for date-wise daily logs  |
//+------------------------------------------------------------------+
string GetLoggerDateStamp()
  {
   datetime dt = GetLoggerNowDateTime();
   return StringFormat("%04d-%02d-%02d", TimeYear(dt), TimeMonth(dt), TimeDay(dt));
  }

//+------------------------------------------------------------------+
//| GetLoggerFolderRelPath: EA_Logs\LIVE\, EA_Logs\DEMO\, TESTER\   |
//+------------------------------------------------------------------+
string GetLoggerFolderRelPath()
  {
   return "EA_Logs\\" + GetLoggerEnvMode() + "\\";
  }

//+------------------------------------------------------------------+
//| GetLoggerBaseFilePrefix: <MODE>_<YYYY-MM-DD>_<Account>_<Magic>   |
//+------------------------------------------------------------------+
string GetLoggerBaseFilePrefix()
  {
   string mode    = GetLoggerEnvMode();
   string dateStr = GetLoggerDateStamp();
   int    accNum  = AccountNumber();
   return StringFormat("%s_%s_%d_%d", mode, dateStr, accNum, MagicNumber);
  }

//+------------------------------------------------------------------+
//| Short display filenames (without folder prefix, for Dashboard)   |
//+------------------------------------------------------------------+
string GetActiveErrorLogDisplayName()
  {
   return GetLoggerBaseFilePrefix() + ".log";
  }

string GetActiveOrderCsvDisplayName()
  {
   return GetLoggerBaseFilePrefix() + "_Orders.csv";
  }

string GetActiveSummaryDisplayName()
  {
   return GetLoggerBaseFilePrefix() + "_Summary.txt";
  }

string GetActiveMethodAnalyticsDisplayName()
  {
   return GetLoggerBaseFilePrefix() + "_Methods.txt";
  }

//+------------------------------------------------------------------+
//| Full relative paths (under MQL4\Files and Common\Files)          |
//+------------------------------------------------------------------+
string GetActiveErrorLogFileName()
  {
   return GetLoggerFolderRelPath() + GetActiveErrorLogDisplayName();
  }

string GetActiveLogFileName()
  {
   return GetLoggerFolderRelPath() + GetActiveOrderCsvDisplayName();
  }

string GetActiveSummaryFileName()
  {
   return GetLoggerFolderRelPath() + GetActiveSummaryDisplayName();
  }

string GetActiveMethodAnalyticsFileName()
  {
   return GetLoggerFolderRelPath() + GetActiveMethodAnalyticsDisplayName();
  }

//+------------------------------------------------------------------+
//| GetMT4ErrorDescription: Plain-English MT4 trade/runtime error    |
//+------------------------------------------------------------------+
string GetMT4ErrorDescription(int err)
  {
   switch(err)
     {
      case 0:    return "No error";
      case 1:    return "No error, but result unknown";
      case 2:    return "Common error";
      case 3:    return "Invalid trade parameters";
      case 4:    return "Trade server is busy";
      case 5:    return "Old version of client terminal";
      case 6:    return "No connection with trade server";
      case 7:    return "Not enough rights";
      case 8:    return "Too frequent requests";
      case 9:    return "Malfunctional trade operation";
      case 64:   return "Account disabled";
      case 65:   return "Invalid account";
      case 128:  return "Trade timeout";
      case 129:  return "Invalid price";
      case 130:  return "Invalid stops (SL/TP too close)";
      case 131:  return "Invalid trade volume (lot size)";
      case 132:  return "Market is closed";
      case 133:  return "Trade is disabled";
      case 134:  return "Not enough money (insufficient margin)";
      case 135:  return "Price changed";
      case 136:  return "Off quotes";
      case 137:  return "Broker is busy";
      case 138:  return "Requote";
      case 139:  return "Order is locked";
      case 140:  return "Long positions only allowed";
      case 141:  return "Too many requests";
      case 145:  return "Modification denied (order too close to market)";
      case 146:  return "Trade context is busy";
      case 147:  return "Expirations are denied by broker";
      case 148:  return "Too many open/pending orders";
      case 149:  return "Hedging is prohibited";
      case 150:  return "Prohibited by FIFO rule";
      case 4051: return "Invalid function parameter value";
      case 4106: return "Unknown symbol";
      case 4107: return "Invalid price parameter for trade function";
      case 4108: return "Invalid ticket";
      case 4109: return "Trade is not allowed (Enable AutoTrading)";
      case 4110: return "Longs are not allowed in EA properties";
      case 4111: return "Shorts are not allowed in EA properties";
      default:   return "MT4 Error #" + IntegerToString(err);
     }
  }

//+------------------------------------------------------------------+
//| GetDeinitReasonText: Plain-English OnDeinit reason               |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
  {
   switch(reason)
     {
      case REASON_PROGRAM:     return "EA terminated by ExpertRemove()";
      case REASON_REMOVE:      return "EA removed from chart";
      case REASON_RECOMPILE:   return "EA recompiled";
      case REASON_CHARTCHANGE: return "Symbol or timeframe changed";
      case REASON_CHARTCLOSE:  return "Chart closed";
      case REASON_PARAMETERS:  return "Input parameters changed";
      case REASON_ACCOUNT:     return "Account changed / reconnected";
      case REASON_TEMPLATE:    return "New template applied";
      case REASON_INITFAILED:  return "OnInit() failed";
      case REASON_CLOSE:       return "Terminal closed";
      default:                 return "Reason #" + IntegerToString(reason);
     }
  }

//+------------------------------------------------------------------+
//| EnsureFileHasHeader: Creates daily file w/ header without wiping |
//| existing LIVE/DEMO logs on mid-day restart                       |
//+------------------------------------------------------------------+
void EnsureFileHasHeader(string fileName, string headerLine, bool forceOverwrite)
  {
   // 1. Local MQL4\Files (or tester\files in Strategy Tester)
   bool needLocalHeader = forceOverwrite;
   if(!needLocalHeader)
     {
      int chk = FileOpen(fileName, FILE_TXT | FILE_READ | FILE_SHARE_READ);
      if(chk == INVALID_HANDLE)
         needLocalHeader = true;
      else
        {
         if(FileSize(chk) == 0)
            needLocalHeader = true;
         FileClose(chk);
        }
     }
   if(needLocalHeader)
     {
      int h = FileOpen(fileName, FILE_TXT | FILE_WRITE | FILE_SHARE_READ);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h, headerLine + "\r\n");
         FileClose(h);
        }
     }

   // 2. Common\Files (independently checked so LIVE/DEMO history is preserved)
   if(InpLogToCommonFolder)
     {
      bool needCommonHeader = forceOverwrite;
      if(!needCommonHeader)
        {
         int chkC = FileOpen(fileName, FILE_TXT | FILE_READ | FILE_SHARE_READ | FILE_COMMON);
         if(chkC == INVALID_HANDLE)
            needCommonHeader = true;
         else
           {
            if(FileSize(chkC) == 0)
               needCommonHeader = true;
            FileClose(chkC);
           }
        }
      if(needCommonHeader)
        {
         int hc = FileOpen(fileName, FILE_TXT | FILE_WRITE | FILE_SHARE_READ | FILE_COMMON);
         if(hc != INVALID_HANDLE)
           {
            FileWriteString(hc, headerLine + "\r\n");
            FileClose(hc);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| GetOrderCsvHeaderLine: Shared CSV header definition              |
//+------------------------------------------------------------------+
string GetOrderCsvHeaderLine()
  {
   return "Ticket,ParentTicket,Symbol,Type,Lots,OpenTime,OpenPrice,CloseTime,ClosePrice,DurationMin,NetProfitUSD,CumulativeAccountNetUSD,ClosingFunction,FunctionCumulativeNetUSD,Outcome,MethodName,ExitReason,LossReasonWithinTick,WasLossInBasketNetWin,StopLoss,TakeProfit,OpenEmaDist,CloseEmaDist,EmaDirClose,EmaFlipElapsedMin,OrderComment,OscillationRangeUSD,OscillationRegime";
  }

//+------------------------------------------------------------------+
//| FormatLoggerTimestamp: "[YYYY-MM-DD HH:MM:SS GST | Srv HH:MM:SS]"|
//+------------------------------------------------------------------+
string FormatLoggerTimestamp()
  {
   datetime dubaiDt = GetLoggerNowDateTime();
   datetime srvDt   = TimeCurrent();
   string dubaiStr  = StringFormat("%04d-%02d-%02d %02d:%02d:%02d GST",
                                   TimeYear(dubaiDt), TimeMonth(dubaiDt), TimeDay(dubaiDt),
                                   TimeHour(dubaiDt), TimeMinute(dubaiDt), TimeSeconds(dubaiDt));
   if(srvDt > 0)
     {
      string srvStr = StringFormat("%02d:%02d:%02d", TimeHour(srvDt), TimeMinute(srvDt), TimeSeconds(srvDt));
      return "[" + dubaiStr + " | Srv " + srvStr + "]";
     }
   return "[" + dubaiStr + "]";
  }

//+------------------------------------------------------------------+
//| EnsureDailyLogFilesReady: Creates/rolls over date-wise files     |
//+------------------------------------------------------------------+
void EnsureDailyLogFilesReady(bool isInitCall = false)
  {
   if(!InpEnableOrderLogger)
      return;

   string curDate = GetLoggerDateStamp();
   string curMode = GetLoggerEnvMode();
   if(!isInitCall && curDate == g_loggerActiveDateStamp && curMode == g_loggerActiveEnvMode)
      return;

   bool isRollover = (!isInitCall && g_loggerActiveDateStamp != "" && curDate != g_loggerActiveDateStamp);
   if(isRollover)
     {
      string prevLogFile = "EA_Logs\\" + g_loggerActiveEnvMode + "\\" +
                           StringFormat("%s_%s_%d_%d.log", g_loggerActiveEnvMode, g_loggerActiveDateStamp, AccountNumber(), MagicNumber);
      WriteReportLineToFile(prevLogFile,
                            FormatLoggerTimestamp() + " [" + g_loggerActiveEnvMode + "] [INFO] [DAILY_ROLLOVER] Day ended (" +
                            g_loggerActiveDateStamp + " -> " + curDate + ") | Errors Today=" + IntegerToString(g_dailyErrorCount) +
                            " | Bal=$" + DoubleToString(AccountBalance(), 2) + " Eq=$" + DoubleToString(AccountEquity(), 2),
                            true);

      g_dailyErrorCount        = 0;
      g_lastLoggedErrorCode    = 0;
      g_lastLoggedErrorOp      = "";
      g_lastLoggedErrorTime    = 0;
      g_lastDedupErrorKey      = "";
      g_lastDedupErrorTime     = 0;
      g_suppressedErrorRepeats = 0;
     }

   g_loggerActiveDateStamp = curDate;
   g_loggerActiveEnvMode   = curMode;
   g_loggerLastCheckedDay  = TimeDay(GetLoggerNowDateTime());

   bool isTesterRun = (IsTesting() || IsOptimization());
   string csvFile = GetActiveLogFileName();
   string logFile = GetActiveErrorLogFileName();

   // Ensure daily Orders CSV has its header (reset only in Strategy Tester; never wipe LIVE/DEMO)
   EnsureFileHasHeader(csvFile, GetOrderCsvHeaderLine(), isTesterRun);

   // Ensure daily Error/Event log file exists and append session/day banner
   string bannerSep = "====================================================================================================";
   EnsureFileHasHeader(logFile, bannerSep, isTesterRun);

   string eventTag = isRollover ? "DAILY_ROLLOVER" : "SESSION_START";
   string header1 = StringFormat("%s [%s] [INFO] [%s] Date=%s | Version=%s | Symbol=%s | Period=M%d | Magic=%d",
                                 FormatLoggerTimestamp(), curMode, eventTag, curDate, glbVersion, Symbol(), Period(), MagicNumber);
   string header2 = StringFormat("%s [%s] [INFO] [ACCOUNT] Acc=#%d | Broker=%s | Server=%s | Currency=%s | Lev=1:%d | Bal=$%.2f | Eq=$%.2f | FreeMgn=$%.2f",
                                 FormatLoggerTimestamp(), curMode, AccountNumber(), AccountCompany(), AccountServer(), AccountCurrency(),
                                 AccountLeverage(), AccountBalance(), AccountEquity(), AccountFreeMargin());
   string header3 = StringFormat("%s [%s] [INFO] [SYMBOL_SPECS] MinLot=%.2f | LotStep=%.2f | MaxLot=%.2f | StopLvl=%d pts | Spread=%d pts | TradeAllowed=%s | Connected=%s",
                                 FormatLoggerTimestamp(), curMode,
                                 MarketInfo(Symbol(), MODE_MINLOT), MarketInfo(Symbol(), MODE_LOTSTEP), MarketInfo(Symbol(), MODE_MAXLOT),
                                 (int)MarketInfo(Symbol(), MODE_STOPLEVEL), (int)MarketInfo(Symbol(), MODE_SPREAD),
                                 (IsTradeAllowed() ? "YES" : "NO"), (IsConnected() ? "YES" : "NO"));
   string header4 = StringFormat("%s [%s] [INFO] [FILES] ErrorLog=%s | OrdersCSV=%s | Summary=%s",
                                 FormatLoggerTimestamp(), curMode, logFile, csvFile, GetActiveSummaryFileName());

   WriteReportLineToFile(logFile, header1, true);
   WriteReportLineToFile(logFile, header2, true);
   WriteReportLineToFile(logFile, header3, true);
   WriteReportLineToFile(logFile, header4, true);

   Print(">>> [DAILY LOGGER] [", curMode, "] Active Date=", curDate,
         " | ErrorLog=", logFile, " | OrdersCSV=", csvFile);
  }

//+------------------------------------------------------------------+
//| LogEAEvent: Writes structured INFO/WARN/CRITICAL event to .log   |
//+------------------------------------------------------------------+
void LogEAEvent(string level, string category, string message)
  {
   if(!InpEnableOrderLogger)
      return;

   EnsureDailyLogFilesReady(false);
   string mode = GetLoggerEnvMode();
   string line = StringFormat("%s [%s] [%s] [%s] %s",
                              FormatLoggerTimestamp(), mode, level, category, message);
   WriteReportLineToFile(GetActiveErrorLogFileName(), line, true);
  }

//+------------------------------------------------------------------+
//| LogEAError: Logs trade/server/runtime error with full context    |
//+------------------------------------------------------------------+
void LogEAError(int errCode, string operation, int ticket = -1, string details = "")
  {
   if(!InpEnableOrderLogger)
      return;

   EnsureDailyLogFilesReady(false);

   datetime nowDt = GetLoggerNowDateTime();
   string dedupKey = IntegerToString(errCode) + "|" + operation + "|" + IntegerToString(ticket);
   if(errCode != 0 && dedupKey == g_lastDedupErrorKey && g_lastDedupErrorTime > 0 && (nowDt - g_lastDedupErrorTime) < 5)
     {
      g_suppressedErrorRepeats++;
      return;
     }

   string repeatNote = "";
   if(g_suppressedErrorRepeats > 0)
     {
      repeatNote = StringFormat(" (suppressed %d identical repeats)", g_suppressedErrorRepeats);
      g_suppressedErrorRepeats = 0;
     }

   g_lastDedupErrorKey   = dedupKey;
   g_lastDedupErrorTime  = nowDt;
   g_dailyErrorCount++;
   g_sessionErrorCount++;
   g_lastLoggedErrorCode = errCode;
   g_lastLoggedErrorOp   = operation;
   g_lastLoggedErrorTime = nowDt;

   string mode    = GetLoggerEnvMode();
   string errDesc = GetMT4ErrorDescription(errCode);
   string tktStr  = (ticket > 0) ? ("#" + IntegerToString(ticket)) : "N/A";
   string detStr  = (details != "") ? (" | Details=" + details) : "";

   string line = StringFormat("%s [%s] [ERROR] [Err=%d: %s] Op=%s | Ticket=%s | Bid=%s Ask=%s Spr=%d | Bal=$%.2f Eq=$%.2f FreeMgn=$%.2f OpenOrds=%d | Conn=%s TradeOK=%s%s%s",
                              FormatLoggerTimestamp(), mode, errCode, errDesc, operation, tktStr,
                              DoubleToString(Bid, Digits), DoubleToString(Ask, Digits), (int)MarketInfo(Symbol(), MODE_SPREAD),
                              AccountBalance(), AccountEquity(), AccountFreeMargin(), OrdersTotal(),
                              (IsConnected() ? "Y" : "N"), (IsTradeAllowed() ? "Y" : "N"),
                              detStr, repeatNote);

   WriteReportLineToFile(GetActiveErrorLogFileName(), line, true);
   Print(">>> [", mode, " ERROR LOGGED #", g_dailyErrorCount, "] Err=", errCode, " (", errDesc, ") Op=", operation, " Ticket=", tktStr, detStr);
  }

//+------------------------------------------------------------------+
//| LogLoggerDeinit: Logs clean EA shutdown / reload metadata        |
//+------------------------------------------------------------------+
void LogLoggerDeinit(int reason)
  {
   if(!InpEnableOrderLogger)
      return;

   string msg = StringFormat("Reason=%d (%s) | DailyErrors=%d | SessionErrors=%d | Bal=$%.2f | Eq=$%.2f | OpenOrds=%d",
                             reason, GetDeinitReasonText(reason), g_dailyErrorCount, g_sessionErrorCount,
                             AccountBalance(), AccountEquity(), OrdersTotal());
   LogEAEvent("INFO", "SESSION_END", msg);
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
   if(StringFind(effComment, "_REV") >= 0)
      return "RECOVERY_REVERSE100";
   if(StringFind(effComment, "_HEDGE") >= 0)
      return "RECOVERY_HEDGE";
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
   if(StringFind(comment, "from #") >= 0 || StringFind(comment, "to #") >= 0)
      return "PARTIAL_CLOSE_RUNNER";
   return "OTHER";
  }

//+------------------------------------------------------------------+
//| GetClosingFunctionName: Identifies primary closing function      |
//+------------------------------------------------------------------+
string GetClosingFunctionName(string reason, string strategy)
  {
   if(reason == "STEP_TRAILING_SL_PROFIT")
      return "STEP_TRAILING_PROFIT";
   if(reason == "STEP_TRAILING_SL_BE")
      return "BREAKEVEN_TRAILING_STOP";
   if(StringFind(reason, "SELL Basket Profit Hit") >= 0 || StringFind(reason, "SELL Basket Micro-Trail Hit") >= 0)
      return "SELL_BASKET_CLOSE";
   if(StringFind(reason, "BUY Basket Profit Hit") >= 0 || StringFind(reason, "BUY Basket Micro-Trail Hit") >= 0)
      return "BUY_BASKET_CLOSE";
   if(StringFind(reason, "Total Net Profit Hit") >= 0)
      return "COMBINATION_PROFIT_CLOSE";
   if(StringFind(reason, "RECOVERY_BASKET") >= 0)
      return "RECOVERY_BASKET_CLOSE";
   if(reason == "STOP_LOSS_HIT" || StringFind(reason, "[sl]") >= 0)
      return "STOP_LOSS_HIT";
   if(reason == "LOSS_CLOSE_LOGIC")
      return "LOSS_CLOSE_LOGIC";
   if(strategy == "PARTIAL_CLOSE_RUNNER")
      return "PARTIAL_CLOSE_RUNNER";
   return "OTHER_LOGIC_CLOSE";
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

   g_cumAccountNetUSD           = 0.0;
   g_cumFuncNet_StepTrailProfit = 0.0;
   g_cumFuncNet_SellBasket      = 0.0;
   g_cumFuncNet_BuyBasket       = 0.0;
   g_cumFuncNet_Combination    = 0.0;
   g_cumFuncNet_RecoveryBasket  = 0.0;
   g_cumFuncNet_BreakevenSL     = 0.0;
   g_cumFuncNet_StopLossHit     = 0.0;
   g_cumFuncNet_LossCloseLogic  = 0.0;
   g_cumFuncNet_RunnerProtect   = 0.0;
   g_cumFuncNet_Other           = 0.0;

   g_loggerActiveDateStamp    = "";
   g_loggerActiveEnvMode      = "";
   g_loggerLastCheckedDay     = -1;
   g_loggerLastKnownHistTotal = -1;
   g_loggerLastKnownOpenTotal = -1;
   g_dailyErrorCount          = 0;
   g_sessionErrorCount        = 0;
   g_lastLoggedErrorCode      = 0;
   g_lastLoggedErrorOp        = "";
   g_lastLoggedErrorTime      = 0;
   g_lastDedupErrorKey        = "";
   g_lastDedupErrorTime       = 0;
   g_suppressedErrorRepeats   = 0;
   g_loggerLastConnState      = IsConnected() ? 1 : 0;
   g_loggerLastTradeAllowed   = IsTradeAllowed() ? 1 : 0;

   EnsureDailyLogFilesReady(true);

   string mode            = GetLoggerEnvMode();
   string csvFileName     = GetActiveLogFileName();
   string summaryFileName = GetActiveSummaryFileName();
   string errorFileName   = GetActiveErrorLogFileName();

   if(IsTesting() || IsOptimization())
     {
      string initialSummary = "=== MetaTrader 4 Strategy Tester Log Started: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " ===";
      WriteReportLineToFile(summaryFileName, initialSummary, false);
      Print(">>> [ORDER LOGGER] [", mode, "] Initialized: ErrorLog=", errorFileName, " | OrdersCSV=", csvFileName, " | Summary=", summaryFileName);
     }
   else
     {
      // Mark existing history orders so only trades from THIS session are appended to today's CSV
      int totalHist = OrdersHistoryTotal();
      for(int i = 0; i < totalHist; i++)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
            MarkOrderAsLogged(OrderTicket());
        }
      g_loggerLastKnownHistTotal = totalHist;
      LogEAEvent("INFO", "INIT_COMPLETE",
                 StringFormat("Logger ready (%s) | Existing history skipped=%d | OpenOrders=%d", mode, totalHist, OrdersTotal()));
      if(!IsTradeAllowed())
         LogEAError(4109, "InitCheck", -1, "AutoTrading / TradeAllowed is DISABLED at EA startup!");
      Print(">>> [ORDER LOGGER] [", mode, "] Initialized: ErrorLog=", errorFileName, " | OrdersCSV=", csvFileName, " | Existing history marked: ", totalHist);
     }
  }

//+------------------------------------------------------------------+
//| ProcessOrderLoggerTick: Decoupled Zero-Lag tick processor        |
//+------------------------------------------------------------------+
void ProcessOrderLoggerTick()
  {
   if(!InpEnableOrderLogger)
      return;

   // 0. Ultra-fast daily date rollover check (rotates date-wise files automatically at midnight)
   int curDay = TimeDay(GetLoggerNowDateTime());
   if(curDay != g_loggerLastCheckedDay || g_loggerActiveDateStamp == "")
      EnsureDailyLogFilesReady(false);

   // 0b. LIVE/DEMO runtime health transitions (Connection & AutoTrading)
   if(!IsTesting() && !IsOptimization())
     {
      int connNow = IsConnected() ? 1 : 0;
      if(g_loggerLastConnState != -1 && connNow != g_loggerLastConnState)
        {
         if(connNow == 0)
            LogEAError(6, "ConnectionMonitor", -1, "Lost connection to broker trade server (" + AccountServer() + ")");
         else
            LogEAEvent("INFO", "CONNECTION", "Connection RESTORED to broker server (" + AccountServer() + ")");
        }
      g_loggerLastConnState = connNow;

      int tradeNow = IsTradeAllowed() ? 1 : 0;
      if(g_loggerLastTradeAllowed != -1 && tradeNow != g_loggerLastTradeAllowed)
        {
         if(tradeNow == 0)
            LogEAError(4109, "AutoTradingMonitor", -1, "AutoTrading / IsTradeAllowed turned OFF while EA is running!");
         else
            LogEAEvent("INFO", "AUTOTRADING", "AutoTrading / IsTradeAllowed turned ON");
        }
      g_loggerLastTradeAllowed = tradeNow;
     }

   // ULTRA-FAST GUARD: If order counts have not changed, return in 0.00 ms
   int curHistTotal = OrdersHistoryTotal();
   int curOpenTotal = OrdersTotal();

   if(curHistTotal == g_loggerLastKnownHistTotal && curOpenTotal == g_loggerLastKnownOpenTotal)
      return;

   // 1. If open orders changed, register any newly opened active orders
   if(curOpenTotal != g_loggerLastKnownOpenTotal)
     {
      for(int i = curOpenTotal - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;
         RegisterActiveOrderForLog(OrderTicket());
        }
      g_loggerLastKnownOpenTotal = curOpenTotal;
     }

   // 2. If history orders changed, log newly closed orders
   if(curHistTotal != g_loggerLastKnownHistTotal)
     {
      int startIdx = (g_loggerLastKnownHistTotal > 0) ? g_loggerLastKnownHistTotal : 0;
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
      g_loggerLastKnownHistTotal = curHistTotal;
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

   string closingFunction = GetClosingFunctionName(reason, strategy);

   g_cumAccountNetUSD += netProfit;
   double funcCumNet = 0.0;
   if(closingFunction == "STEP_TRAILING_PROFIT")
     {
      g_cumFuncNet_StepTrailProfit += netProfit;
      funcCumNet = g_cumFuncNet_StepTrailProfit;
     }
   else if(closingFunction == "SELL_BASKET_CLOSE")
     {
      g_cumFuncNet_SellBasket += netProfit;
      funcCumNet = g_cumFuncNet_SellBasket;
     }
   else if(closingFunction == "BUY_BASKET_CLOSE")
     {
      g_cumFuncNet_BuyBasket += netProfit;
      funcCumNet = g_cumFuncNet_BuyBasket;
     }
   else if(closingFunction == "COMBINATION_PROFIT_CLOSE")
     {
      g_cumFuncNet_Combination += netProfit;
      funcCumNet = g_cumFuncNet_Combination;
     }
   else if(closingFunction == "RECOVERY_BASKET_CLOSE")
     {
      g_cumFuncNet_RecoveryBasket += netProfit;
      funcCumNet = g_cumFuncNet_RecoveryBasket;
     }
   else if(closingFunction == "BREAKEVEN_TRAILING_STOP")
     {
      g_cumFuncNet_BreakevenSL += netProfit;
      funcCumNet = g_cumFuncNet_BreakevenSL;
     }
   else if(closingFunction == "STOP_LOSS_HIT")
     {
      g_cumFuncNet_StopLossHit += netProfit;
      funcCumNet = g_cumFuncNet_StopLossHit;
     }
   else if(closingFunction == "LOSS_CLOSE_LOGIC")
     {
      g_cumFuncNet_LossCloseLogic += netProfit;
      funcCumNet = g_cumFuncNet_LossCloseLogic;
     }
   else if(closingFunction == "PARTIAL_CLOSE_RUNNER")
     {
      g_cumFuncNet_RunnerProtect += netProfit;
      funcCumNet = g_cumFuncNet_RunnerProtect;
     }
   else
     {
      g_cumFuncNet_Other += netProfit;
      funcCumNet = g_cumFuncNet_Other;
     }

   // CSV Columns: Ticket,ParentTicket,Symbol,Type,Lots,OpenTime,OpenPrice,CloseTime,ClosePrice,DurationMin,NetProfitUSD,CumulativeAccountNetUSD,ClosingFunction,FunctionCumulativeNetUSD,Outcome,MethodName,ExitReason,LossReasonWithinTick,WasLossInBasketNetWin,StopLoss,TakeProfit,OpenEmaDist,CloseEmaDist,EmaDirClose,EmaFlipElapsedMin,OrderComment
      double rH = 0.0, rL = 0.0, rPos = 50.0;
   double rWidth = GetCurrentOscillationRange(rH, rL, rPos);
   string regimeStr = GetOscillationRegimeName(rWidth);

   string csvLine = StringFormat("%d,%d,%s,%s,%.2f,%s,%.2f,%s,%.2f,%.1f,%.2f,%.2f,%s,%.2f,%s,%s,%s,%s,%s,%.2f,%.2f,%.1f,%.1f,%d,%d,%s,%.2f,%s",
                                 ticket, parentTicket, symbol, typeStr, lots,
                                 TimeToString(openTime, TIME_DATE|TIME_SECONDS), openPrice,
                                 TimeToString(closeTime, TIME_DATE|TIME_SECONDS), closePrice,
                                 durMin, netProfit, g_cumAccountNetUSD,
                                 closingFunction, funcCumNet,
                                 outcome, strategy,
                                 SanitizeCsvField(reason), SanitizeCsvField(lossExplanation),
                                 (wasRescuedInBasket ? "YES" : "NO"),
                                 sl, tp, openEmaDist, closeEmaDist, closeEmaDir, flipElapsedMin,
                                 SanitizeCsvField(rawComment), rWidth, regimeStr);

   EnsureDailyLogFilesReady(false);
   WriteReportLineToFile(GetActiveLogFileName(), csvLine, true);

   LogEAEvent("INFO", "ORDER_CLOSED",
              StringFormat("#%d %s %.2fL | Open=%s Close=%s | Net=%s$%.2f [%s] | Strat=%s | Reason=%s | Bal=$%.2f Eq=$%.2f",
                           ticket, typeStr, lots, DoubleToString(openPrice, Digits), DoubleToString(closePrice, Digits),
                           (netProfit >= 0 ? "+" : "-"), MathAbs(netProfit), outcome, strategy, reason,
                           AccountBalance(), AccountEquity()));

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
   int stratTotal[8];
   int stratWins[8];
   int stratLosses[8];
   double stratNet[8];
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
      int sIdx = 7;
      if(strat == "SSL_LONG" || strat == "SSL_SHORT") sIdx = 0;
      else if(strat == "REENTRY")                     sIdx = 1;
      else if(strat == "RECOVERY_TYPE1")              sIdx = 2;
      else if(strat == "RECOVERY_TYPE2_LSD")          sIdx = 3;
      else if(strat == "RECOVERY_TYPE3")              sIdx = 4;
      else if(strat == "RECOVERY_HEDGE" || strat == "RECOVERY_REVERSE100") sIdx = 5;
      else if(strat == "FLIP_SUPPORT")                sIdx = 6;

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
   EnsureDailyLogFilesReady(false);
   string envMode         = GetLoggerEnvMode();
   string summaryFileName = GetActiveSummaryFileName();
   string reportTitle     = (envMode == "TESTER")
                            ? "                STRATEGY TESTER ORDER & LOSS ANALYSIS REPORT"
                            : ((envMode == "LIVE")
                               ? "                LIVE ACCOUNT ORDER & LOSS ANALYSIS REPORT"
                               : "                DEMO ACCOUNT ORDER & LOSS ANALYSIS REPORT");

   WriteReportLineToFile(summaryFileName, sep, false);
   WriteReportLineToFile(summaryFileName, reportTitle, true);
   WriteReportLineToFile(summaryFileName, sep, true);
   WriteReportLineToFile(summaryFileName, "Mode: " + envMode + " | Date: " + GetLoggerDateStamp() + " | Generated: " + TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + " | Symbol: " + Symbol() + " | Period: M" + IntegerToString(Period()) + " | Version: " + glbVersion, true);
   WriteReportLineToFile(summaryFileName, "Account: #" + IntegerToString(AccountNumber()) + " (" + AccountServer() + ") | Magic: " + IntegerToString(MagicNumber) + " | Balance: $" + DoubleToString(AccountBalance(), 2) + " | Equity: $" + DoubleToString(AccountEquity(), 2), true);
   WriteReportLineToFile(summaryFileName, "Daily Errors: " + IntegerToString(g_dailyErrorCount) + " | Session Errors: " + IntegerToString(g_sessionErrorCount) + " | ErrorLog: " + GetActiveErrorLogFileName(), true);
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
   string stratNames[8] = {"1. SSL Regular Orders      ",
                           "2. ReEntry Orders          ",
                           "3. Recovery Type 1 Classic ",
                           "4. Recovery Type 2 (LSD)   ",
                           "5. Recovery Type 3 (WeakEMA)",
                           "6. Recovery Rev100 / Hedge ",
                           "7. FLIP Basket Support     ",
                           "8. Other / Scalp           "};
   for(int s = 0; s < 8; s++)
     {
      double sWinRate = (stratTotal[s] > 0) ? ((double)stratWins[s] / stratTotal[s] * 100.0) : 0.0;
      WriteReportLineToFile(summaryFileName,
                            StringFormat("%s : Total=%3d | Wins=%3d (%.1f%%) | Losses=%3d | Net=%s$%.2f USD",
                                         stratNames[s], stratTotal[s], stratWins[s], sWinRate, stratLosses[s],
                                         (stratNet[s] >= 0 ? "+" : "-"), MathAbs(stratNet[s])), true);
     }
   WriteReportLineToFile(summaryFileName, subSep, true);

      WriteReportLineToFile(summaryFileName, ">>> OSCILLATION ENGINE & BOUNDARY ASYMMETRY METRICS:", true);
   double rCurH = 0.0, rCurL = 0.0, rCurPos = 50.0;
   double curRange = GetCurrentOscillationRange(rCurH, rCurL, rCurPos);
   string curRegime = GetOscillationRegimeName(curRange);
   WriteReportLineToFile(summaryFileName, StringFormat("Final Oscillation Range : $%.2f USD [%s] (RelPos: %.1f%%)", curRange, curRegime, rCurPos), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Blocked Counter BUYs    : %d (Upper Ceiling / Bearish Breakout Gate)", g_oscillationBlockedBuys), true);
   WriteReportLineToFile(summaryFileName, StringFormat("Blocked Counter SELLs   : %d (Lower Floor / Bullish Breakout Gate)", g_oscillationBlockedSells), true);
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
    WriteReportLineToFile(summaryFileName, subSep, true);
    WriteReportLineToFile(summaryFileName, ">>> FUNCTION-WISE CLOSING & CUMULATIVE P/L BREAKDOWN:", true);
    WriteReportLineToFile(summaryFileName, StringFormat("1. Individual Step-Trailing Profit : Net=%s$%.2f USD", (g_cumFuncNet_StepTrailProfit >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_StepTrailProfit)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("2. SELL Basket Profit Closes       : Net=%s$%.2f USD", (g_cumFuncNet_SellBasket >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_SellBasket)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("3. BUY Basket Profit Closes        : Net=%s$%.2f USD", (g_cumFuncNet_BuyBasket >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_BuyBasket)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("4. $1 / Combination Profit Closes  : Net=%s$%.2f USD", (g_cumFuncNet_Combination >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_Combination)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("5. Recovery Baskets (LSD & Rev100)  : Net=%s$%.2f USD", (g_cumFuncNet_RecoveryBasket >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_RecoveryBasket)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("6. Breakeven Step Trailing Stop    : Net=%s$%.2f USD (Protected Trades)", (g_cumFuncNet_BreakevenSL >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_BreakevenSL)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("7. Stop Loss Hits (Adverse Moves)  : Net=-$%.2f USD", MathAbs(g_cumFuncNet_StopLossHit)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("8. Loss Close Logic (Safety Stops) : Net=-$%.2f USD", MathAbs(g_cumFuncNet_LossCloseLogic)), true);
    WriteReportLineToFile(summaryFileName, StringFormat("9. Partial Close Runners           : Net=%s$%.2f USD", (g_cumFuncNet_RunnerProtect >= 0 ? "+" : "-"), MathAbs(g_cumFuncNet_RunnerProtect)), true);

   Print(">>> =================== ORDER & LOSS PERFORMANCE SUMMARY ===================");
   Print(">>> Mode: ", envMode, " | Trades: ", totalOrders,
         " | Effective WinRate: ", DoubleToString(winRate, 1), "% | Net Profit: $", DoubleToString(netTotal, 2),
         " | Profit Factor: ", DoubleToString(profitFactor, 2), " | DailyErrors: ", g_dailyErrorCount);
   Print(">>> Recorders: T1=$", DoubleToString(stratNet[2], 2), " | T2(LSD)=$", DoubleToString(stratNet[3], 2), " | T3(WeakEMA)=$", DoubleToString(stratNet[4], 2), " | Rev100/Hedge=$", DoubleToString(stratNet[5], 2));
   Print(">>> Error Log: ", GetActiveErrorLogFileName(), " | Detailed CSV: ", GetActiveLogFileName(), " | Summary: ", GetActiveSummaryFileName());
   Print(">>> ========================================================================");
  }
