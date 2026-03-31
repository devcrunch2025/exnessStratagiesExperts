//+------------------------------------------------------------------+
//| V_TV_OrderReport.mqh                                             |
//| Tracks each order open/close with pattern, P/L, analysis        |
//| CSV columns:                                                     |
//|  Ticket, Type, Pattern, OpenTime, OpenPrice,                    |
//|  CloseTime, ClosePrice, Profit, ProfitReason, LossReason        |
//+------------------------------------------------------------------+
#ifndef V_TV_ORDER_REPORT_MQH
#define V_TV_ORDER_REPORT_MQH

string g_orderReportFile = "";

//--- In-memory record for open orders (to detect close events) -----
struct OrderRecord
  {
   int      ticket;
   string   pattern;       // "prePrev | prev | curr" at time of entry
   datetime openTime;
   double   openPrice;
   double   ema1AtOpen;    // EMA1 value when order placed
   double   ema2AtOpen;    // EMA2 value when order placed
   bool     ema1BelowEma2; // Cond9 state at open
   bool     ema1Falling;   // Cond8 state at open
   bool     tracked;       // slot in use
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

   // Only write header if file is new/empty
   int h = FileOpen(g_orderReportFile, FILE_TXT|FILE_READ|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
     {
      ulong sz = FileSize(h);
      FileClose(h);
      if(sz > 0) return;
     }

   h = FileOpen(g_orderReportFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h,
      "Ticket,Type,Pattern,OpenTime,OpenPrice,"
      "CloseTime,ClosePrice,Profit(USD),"
      "EMA1_at_Open,EMA2_at_Open,EMA1_Below_EMA2,EMA1_Falling,"
      "ProfitReason,LossReason\n");
   FileClose(h);

   // Init record slots
   for(int i = 0; i < ORDER_RECORD_MAX; i++)
      g_orderRecords[i].tracked = false;
  }

//+------------------------------------------------------------------+
//| Called right after a SELL order is placed                        |
//+------------------------------------------------------------------+
void ReportOrderOpened(int ticket, string pattern)
  {
   if(g_orderReportFile == "") return;

   // Find free slot
   int slot = -1;
   for(int i = 0; i < ORDER_RECORD_MAX; i++)
      if(!g_orderRecords[i].tracked) { slot = i; break; }
   if(slot < 0) { Print("OrderReport: record buffer full"); return; }

   if(!OrderSelect(ticket, SELECT_BY_TICKET)) return;

   double ema1 = iMA(Symbol(), 0, SeqSellEMAPeriod,  0, MODE_EMA, PRICE_CLOSE, 0);
   double ema2 = iMA(Symbol(), 0, SeqSellEMA2Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double ema1Past = iMA(Symbol(), 0, SeqSellEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, SeqSellEMAShift);

   g_orderRecords[slot].ticket       = ticket;
   g_orderRecords[slot].pattern      = pattern;
   g_orderRecords[slot].openTime     = OrderOpenTime();
   g_orderRecords[slot].openPrice    = OrderOpenPrice();
   g_orderRecords[slot].ema1AtOpen   = ema1;
   g_orderRecords[slot].ema2AtOpen   = ema2;
   g_orderRecords[slot].ema1BelowEma2= (ema1 < ema2);
   g_orderRecords[slot].ema1Falling  = (ema1 < ema1Past);
   g_orderRecords[slot].tracked      = true;

   Print("OrderReport: tracking #" + IntegerToString(ticket) + " pattern=[" + pattern + "]");
  }

//+------------------------------------------------------------------+
//| Analyse why order was profitable                                 |
//+------------------------------------------------------------------+
string AnalyseProfitReason(OrderRecord &rec, double closePrice, double profit)
  {
   string reasons = "";
   if(rec.ema1BelowEma2)  reasons += "EMA_bearish_structure;";
   if(rec.ema1Falling)    reasons += "EMA1_falling_at_entry;";
   if(closePrice < rec.openPrice) reasons += "price_dropped_as_expected;";
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
   if(!rec.ema1BelowEma2) reasons += "EMA1_above_EMA2_at_entry(Cond9_failed_or_disabled);";
   if(!rec.ema1Falling)   reasons += "EMA1_not_falling_at_entry(Cond8_issue);";
   if(closePrice > rec.openPrice) reasons += "price_rose_against_sell;";
   if(profit < -5.0)      reasons += "large_loss(>$5)_check_trend;";
   if(reasons == "")      reasons  = "no_specific_reason";
   return reasons;
  }

//+------------------------------------------------------------------+
//| Write one closed order row to CSV                                |
//+------------------------------------------------------------------+
void WriteOrderReportRow(OrderRecord &rec, datetime closeTime, double closePrice, double profit)
  {
   string profitReason = (profit >= 0) ? AnalyseProfitReason(rec, closePrice, profit) : "";
   string lossReason   = (profit <  0) ? AnalyseLossReason (rec, closePrice, profit) : "";

   string row =
      IntegerToString(rec.ticket)                              + "," +
      "SELL"                                                   + "," +
      "\"" + rec.pattern + "\""                               + "," +
      TimeToString(rec.openTime,  TIME_DATE|TIME_SECONDS)     + "," +
      DoubleToString(rec.openPrice,  2)                       + "," +
      TimeToString(closeTime,     TIME_DATE|TIME_SECONDS)     + "," +
      DoubleToString(closePrice,     2)                       + "," +
      DoubleToString(profit,         2)                       + "," +
      DoubleToString(rec.ema1AtOpen, 2)                       + "," +
      DoubleToString(rec.ema2AtOpen, 2)                       + "," +
      (rec.ema1BelowEma2 ? "YES" : "NO")                     + "," +
      (rec.ema1Falling   ? "YES" : "NO")                     + "," +
      "\"" + profitReason + "\""                              + "," +
      "\"" + lossReason   + "\""                              + "\n";

   int h = FileOpen(g_orderReportFile,
                    FILE_TXT|FILE_READ|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
      h = FileOpen(g_orderReportFile, FILE_TXT|FILE_WRITE|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, row);
   FileClose(h);

   Print("OrderReport: #" + IntegerToString(rec.ticket) +
         " closed P/L=" + DoubleToString(profit,2) +
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

      // Check if still in open orders
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

         double profit     = OrderProfit() + OrderSwap() + OrderCommission();
         datetime closeTime  = OrderCloseTime();
         double closePrice = OrderClosePrice();

         WriteOrderReportRow(g_orderRecords[s], closeTime, closePrice, profit);
         g_orderRecords[s].tracked = false;
         break;
        }
     }
  }

#endif
