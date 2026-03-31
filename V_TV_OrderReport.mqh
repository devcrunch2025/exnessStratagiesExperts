//+------------------------------------------------------------------+
//| V_TV_OrderReport.mqh                                             |
//| Tracks each SELL and BUY order open/close with pattern, P/L     |
//| CSV columns:                                                     |
//|  Ticket,Type,Pattern,OpenTime,OpenPrice,                        |
//|  CloseTime,ClosePrice,Profit(USD),                              |
//|  EMA1_at_Open,EMA2_at_Open,EMA1_Trend_OK,EMA_Structure_OK,      |
//|  CloseReason,ProfitReason,LossReason                            |
//+------------------------------------------------------------------+
#ifndef V_TV_ORDER_REPORT_MQH
#define V_TV_ORDER_REPORT_MQH

string g_orderReportFile = "";

//--- In-memory record for tracking open orders --------------------
struct OrderRecord
  {
   int      ticket;
   string   orderType;     // "SELL" or "BUY"
   string   pattern;       // "prePrev | prev | curr" at time of entry
   datetime openTime;
   double   openPrice;
   double   ema1AtOpen;
   double   ema2AtOpen;
   bool     emaTrendOK;    // Cond8: EMA1 sloping in correct direction
   bool     emaStructureOK;// Cond9: EMA1/EMA2 correct side
   bool     tracked;
  };

#define ORDER_RECORD_MAX 50
OrderRecord g_orderRecords[ORDER_RECORD_MAX];

//+------------------------------------------------------------------+
//| Init: create CSV with header                                     |
//+------------------------------------------------------------------+
void InitOrderReport()
  {
   string dateStr = TimeToString(TimeCurrent(), TIME_DATE);
   StringReplace(dateStr, ".", "");
   g_orderReportFile = "OrderReport_" + dateStr + "_" + Symbol() + ".csv";

   bool needHeader = true;
   int h = FileOpen(g_orderReportFile, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      ulong sz = FileSize(h);
      FileClose(h);
      if(sz > 0) needHeader = false;
     }

   if(needHeader)
     {
      h = FileOpen(g_orderReportFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(h != INVALID_HANDLE)
        {
         FileWriteString(h,
            "Ticket,Type,Pattern,OpenTime,OpenPrice,"
            "CloseTime,ClosePrice,Profit(USD),"
            "EMA1_at_Open,EMA2_at_Open,EMA1_Below_EMA2,EMA1_Falling,"
            "ProfitReason,LossReason\n");
         FileClose(h);
        }
     }

   for(int i = 0; i < ORDER_RECORD_MAX; i++)
      g_orderRecords[i].tracked = false;
  }

//+------------------------------------------------------------------+
//| Called right after any order is placed                           |
//+------------------------------------------------------------------+
void ReportOrderOpened(int ticket, string pattern, string orderType)
  {
   if(g_orderReportFile == "") return;

   int slot = -1;
   for(int i = 0; i < ORDER_RECORD_MAX; i++)
      if(!g_orderRecords[i].tracked) { slot = i; break; }
   if(slot < 0) { Print("OrderReport: record buffer full"); return; }

   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

   bool isSell = (orderType == "SELL");
   int  emaPeriod  = isSell ? SeqSellEMAPeriod  : SeqBuyEMAPeriod;
   int  ema2Period = isSell ? SeqSellEMA2Period  : SeqBuyEMA2Period;
   int  emaShift   = isSell ? SeqSellEMAShift    : SeqBuyEMAShift;

   double ema1     = iMA(Symbol(), 0, emaPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2     = iMA(Symbol(), 0, ema2Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema1Past = iMA(Symbol(), 0, emaPeriod,  0, MODE_EMA, PRICE_CLOSE, emaShift);

   g_orderRecords[slot].ticket         = ticket;
   g_orderRecords[slot].orderType      = orderType;
   g_orderRecords[slot].pattern        = pattern;
   g_orderRecords[slot].openTime       = OrderOpenTime();
   g_orderRecords[slot].openPrice      = OrderOpenPrice();
   g_orderRecords[slot].ema1AtOpen     = ema1;
   g_orderRecords[slot].ema2AtOpen     = ema2;
   g_orderRecords[slot].emaTrendOK     = isSell ? (ema1 < ema1Past) : (ema1 > ema1Past);
   g_orderRecords[slot].emaStructureOK = isSell ? (ema1 < ema2)     : (ema1 > ema2);
   g_orderRecords[slot].tracked        = true;

   Print("OrderReport: tracking #" + IntegerToString(ticket) +
         " [" + orderType + "] pattern=[" + pattern + "]");
  }

//+------------------------------------------------------------------+
//| Analyse why order was profitable                                 |
//+------------------------------------------------------------------+
string AnalyseProfitReason(OrderRecord &rec, double closePrice, double profit)
  {
   string reasons = "";
   if(rec.emaTrendOK)     reasons += "EMA_trend_confirmed_at_entry;";
   if(rec.emaStructureOK) reasons += "EMA_structure_confirmed_at_entry;";
   if(rec.orderType == "SELL" && closePrice < rec.openPrice) reasons += "price_dropped_as_expected;";
   if(rec.orderType == "BUY"  && closePrice > rec.openPrice) reasons += "price_rose_as_expected;";
   if(profit > 1.0)       reasons += "strong_move(>$1);";
   if(reasons == "")      reasons  = "no_specific_reason";
   return reasons;
  }

//+------------------------------------------------------------------+
//| Analyse why order was a loss                                     |
//+------------------------------------------------------------------+
string AnalyseLossReason(OrderRecord &rec, double closePrice, double profit)
  {
   string reasons = "";
   if(!rec.emaTrendOK)     reasons += "EMA_trend_not_confirmed(Cond8);";
   if(!rec.emaStructureOK) reasons += "EMA_structure_wrong(Cond9);";
   if(rec.orderType == "SELL" && closePrice > rec.openPrice) reasons += "price_rose_against_sell;";
   if(rec.orderType == "BUY"  && closePrice < rec.openPrice) reasons += "price_dropped_against_buy;";
   if(profit < -5.0) reasons += "large_loss(>$5)_check_trend;";
   if(reasons == "") reasons  = "no_specific_reason";
   return reasons;
  }

//+------------------------------------------------------------------+
//| Write one closed order row to CSV                                |
//+------------------------------------------------------------------+
void WriteOrderReportRow(OrderRecord &rec, datetime closeTime, double closePrice, double profit)
  {
   string profitReason = (profit >= 0) ? AnalyseProfitReason(rec, closePrice, profit) : "";
   string lossReason   = (profit <  0) ? AnalyseLossReason (rec, closePrice, profit) : "";

   // EMA1_Below_EMA2: for SELL emaTrendOK=EMA1<EMA2, for BUY emaStructureOK=EMA1>EMA2
   string ema1BelowEma2 = (rec.orderType == "SELL") ? (rec.emaStructureOK ? "YES" : "NO")
                                                     : (rec.emaStructureOK ? "NO"  : "YES");
   // EMA1_Falling: emaTrendOK = EMA1 sloping in the right direction
   string ema1Falling   = rec.emaTrendOK ? "YES" : "NO";

   string row =
      IntegerToString(rec.ticket)                          + "," +
      rec.orderType                                        + "," +
      "\"" + rec.pattern + "\""                           + "," +
      TimeToString(rec.openTime, TIME_DATE|TIME_SECONDS)  + "," +
      DoubleToString(rec.openPrice, 2)                    + "," +
      TimeToString(closeTime,    TIME_DATE|TIME_SECONDS)  + "," +
      DoubleToString(closePrice,    2)                    + "," +
      DoubleToString(profit,        2)                    + "," +
      DoubleToString(rec.ema1AtOpen,2)                    + "," +
      DoubleToString(rec.ema2AtOpen,2)                    + "," +
      ema1BelowEma2                                       + "," +
      ema1Falling                                         + "," +
      "\"" + profitReason + "\""                          + "," +
      "\"" + lossReason   + "\""                          + "\n";

   int h = FileOpen(g_orderReportFile,
                    FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_orderReportFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, row);
   FileClose(h);

   Print("OrderReport: #" + IntegerToString(rec.ticket) +
         " [" + rec.orderType + "] P/L=" + DoubleToString(profit,2) +
         (profit >= 0 ? " PROFIT: " + profitReason : " LOSS: " + lossReason));
  }

//+------------------------------------------------------------------+
//| Called every tick: detect any tracked order that just closed     |
//+------------------------------------------------------------------+
void CheckClosedOrders()
  {
   if(g_orderReportFile == "") return;

   for(int s = 0; s < ORDER_RECORD_MAX; s++)
     {
      if(!g_orderRecords[s].tracked) continue;

      bool stillOpen = false;
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderTicket() == g_orderRecords[s].ticket) { stillOpen = true; break; }
        }
      if(stillOpen) continue;

      // Order closed — find it in history
      int histTotal = OrdersHistoryTotal();
      for(int i = histTotal - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderTicket() != g_orderRecords[s].ticket)   continue;

         double   profit     = OrderProfit() + OrderSwap() + OrderCommission();
         datetime closeTime  = OrderCloseTime();
         double   closePrice = OrderClosePrice();

         WriteOrderReportRow(g_orderRecords[s], closeTime, closePrice, profit);
         g_orderRecords[s].tracked = false;
         break;
        }
     }
  }

#endif
