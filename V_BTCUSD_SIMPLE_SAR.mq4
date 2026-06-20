//+------------------------------------------------------------------+
//|               SIMPLE_SAR_RAW_GAP_EA.mq4                          |
//|  Minimal SAR entry, USD TP/SL and 4-candle weak exit              |
//+------------------------------------------------------------------+
#property strict
#property version "1.00"

input int      InpMagicNumber       = 989901;
input double   InpLotSize           = 0.01;
input int      InpSlippage          = 30;

input double   InpProfitTargetUSD   = 1.00;
input double   InpStopLossUSD       = 10.00;

input double   InpFirstEntryRawGap  = 50.0;
input double   InpProfitReentryRawGap = 10.0;
input double   InpWeakReentryRawGap   = 100.0;
input double   InpStopLossReentryRawGap = 10.0;

input double   InpSARPeriod         = 1.2;
input int      InpSARStepSize       = 25;
input int      InpSARAcceleration   = 9;

int      g_sarDirection        = 0;     // 1=BUY, -1=SELL
double   g_sarSignalPrice      = 0.0;

bool     g_hasClosedReference  = false;
double   g_lastClosedPrice     = 0.0;
datetime g_lastClosedBarTime   = 0;
int      g_lastClosedDirection = 0;
int      g_lastCloseReason     = 0;     // 1=profit, 2=weak, 3=stop loss

#define CLOSE_REASON_PROFIT   1
#define CLOSE_REASON_WEAK     2
#define CLOSE_REASON_STOPLOSS 3

int      g_trackedOrderTicket   = 0;
int      g_weakSequenceCount    = 0;
datetime g_lastWeakCheckedBar   = 0;

//+------------------------------------------------------------------+
double GetSARStep()
{
   return(InpSARPeriod * InpSARStepSize / 10000.0);
}

//+------------------------------------------------------------------+
double GetSARMaximum()
{
   return(GetSARStep() * InpSARAcceleration);
}

//+------------------------------------------------------------------+
int GetSARDirection(int shift)
{
   if(Bars <= shift + 2)
      return(0);

   double sarValue   = iSAR(Symbol(), Period(),
                            GetSARStep(), GetSARMaximum(), shift);
   double closePrice = iClose(Symbol(), Period(), shift);

   if(closePrice > sarValue)
      return(1);

   if(closePrice < sarValue)
      return(-1);

   return(0);
}

//+------------------------------------------------------------------+
void UpdateSARSignal()
{
   int direction = GetSARDirection(1);

   if(direction == 0)
      return;

   if(g_sarDirection == 0)
   {
      g_sarDirection   = direction;
      g_sarSignalPrice = Close[1];
      return;
   }

   if(direction != g_sarDirection)
   {
      g_sarDirection   = direction;
      g_sarSignalPrice = Close[1];

      g_hasClosedReference  = false;
      g_lastClosedPrice     = 0.0;
      g_lastClosedBarTime   = 0;
      g_lastClosedDirection = 0;
      g_lastCloseReason     = 0;

      Print("SAR CHANGED | Direction=",
            direction == 1 ? "BUY" : "SELL",
            " | SignalPrice=",
            DoubleToString(g_sarSignalPrice, Digits));
   }
}

//+------------------------------------------------------------------+
bool IsEAOrderSelected()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      if(OrderType() == OP_BUY || OrderType() == OP_SELL)
         return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
//| Count consecutive opposite candles only after the order opens.   |
//+------------------------------------------------------------------+
bool IsFourthWeakSequenceCandle(int direction, int ticket)
{
   if(Bars < 6)
      return(false);

   if(g_trackedOrderTicket != ticket)
   {
      g_trackedOrderTicket = ticket;
      g_weakSequenceCount  = 0;
      g_lastWeakCheckedBar = Time[1];
      return(false);
   }

   if(Time[1] != g_lastWeakCheckedBar)
   {
      g_lastWeakCheckedBar = Time[1];

      bool opposite = false;

      if(direction == 1)
         opposite = Close[1] < Open[1];
      else if(direction == -1)
         opposite = Close[1] > Open[1];

      if(opposite)
         g_weakSequenceCount++;
      else
         g_weakSequenceCount = 0;

      Print("WEAK SEQUENCE | Ticket=", ticket,
            " | Count=", g_weakSequenceCount, "/4");
   }

   return(g_weakSequenceCount >= 4);
}

//+------------------------------------------------------------------+
bool CloseSelectedOrder(string reason, int closeReason)
{
   int    type       = OrderType();
   int    direction  = type == OP_BUY ? 1 : -1;
   int    ticket     = OrderTicket();
   double lots       = OrderLots();

   RefreshRates();

   double closePrice = type == OP_BUY ? Bid : Ask;
   double netProfit  = OrderProfit() + OrderSwap() + OrderCommission();

   if(!OrderClose(ticket, lots, closePrice, InpSlippage, clrWhite))
   {
      int errorCode = GetLastError();

      Print("ORDER CLOSE FAILED | Ticket=", ticket,
            " | Error=", errorCode,
            " | Reason=", reason);

      ResetLastError();
      return(false);
   }

   g_hasClosedReference  = true;
   g_lastClosedPrice     = closePrice;
   g_lastClosedBarTime   = Time[0];
   g_lastClosedDirection = direction;
   g_lastCloseReason     = closeReason;

   g_trackedOrderTicket = 0;
   g_weakSequenceCount  = 0;
   g_lastWeakCheckedBar = 0;

   Print("ORDER CLOSED | Ticket=", ticket,
         " | Profit=", DoubleToString(netProfit, 2),
         " | Price=", DoubleToString(closePrice, Digits),
         " | Reason=", reason);

   return(true);
}

//+------------------------------------------------------------------+
//| Returns true when an EA order exists or was closed this tick.     |
//+------------------------------------------------------------------+
bool ManageOpenOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != InpMagicNumber)
         continue;

      int type = OrderType();

      if(type != OP_BUY && type != OP_SELL)
         continue;

      int direction = type == OP_BUY ? 1 : -1;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= InpProfitTargetUSD)
      {
         CloseSelectedOrder("Profit target", CLOSE_REASON_PROFIT);
         return(true);
      }

      if(profit <= -InpStopLossUSD)
      {
         CloseSelectedOrder("USD stop loss", CLOSE_REASON_STOPLOSS);
         return(true);
      }

      if(IsFourthWeakSequenceCandle(direction, OrderTicket()))
      {
         CloseSelectedOrder("Fourth opposite sequence candle", CLOSE_REASON_WEAK);
         return(true);
      }

      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
double GetDirectionalRawMove(int direction,
                             double referencePrice,
                             double livePrice)
{
   if(direction == 1)
      return(livePrice - referencePrice);

   if(direction == -1)
      return(referencePrice - livePrice);

   return(0.0);
}

//+------------------------------------------------------------------+
void TryOpenOrder()
{
   if(g_sarDirection == 0 || IsEAOrderSelected())
      return;

   RefreshRates();

   int orderType = g_sarDirection == 1 ? OP_BUY : OP_SELL;
   double price  = g_sarDirection == 1 ? Ask : Bid;

   double referencePrice = g_sarSignalPrice;
   double requiredGap    = InpFirstEntryRawGap;
   string orderComment   = "SAR_FIRST";

   if(g_hasClosedReference &&
      g_lastClosedDirection == g_sarDirection)
   {
      if(Time[0] == g_lastClosedBarTime)
         return;

      referencePrice = g_lastClosedPrice;

      if(g_lastCloseReason == CLOSE_REASON_WEAK)
      {
         requiredGap  = InpWeakReentryRawGap;
         orderComment = "SAR_REENTRY_WEAK";
      }
      else if(g_lastCloseReason == CLOSE_REASON_PROFIT)
      {
         requiredGap  = InpProfitReentryRawGap;
         orderComment = "SAR_REENTRY_PROFIT";
      }
      else
      {
         requiredGap  = InpStopLossReentryRawGap;
         orderComment = "SAR_REENTRY_SL";
      }
   }

   if(referencePrice <= 0.0)
      return;

   double rawMove =
      GetDirectionalRawMove(g_sarDirection, referencePrice, price);

   if(rawMove < requiredGap)
      return;

   double normalizedPrice = NormalizeDouble(price, Digits);

   int ticket = OrderSend(Symbol(),
                          orderType,
                          InpLotSize,
                          normalizedPrice,
                          InpSlippage,
                          0,
                          0,
                          orderComment,
                          InpMagicNumber,
                          0,
                          g_sarDirection == 1 ? clrLime : clrRed);

   if(ticket < 0)
   {
      int errorCode = GetLastError();

      Print("ORDER SEND FAILED | Error=", errorCode,
            " | Direction=",
            g_sarDirection == 1 ? "BUY" : "SELL",
            " | RawMove=", DoubleToString(rawMove, Digits),
            " | Required=", DoubleToString(requiredGap, Digits));

      ResetLastError();
      return;
   }

   g_hasClosedReference = false;
   g_lastCloseReason    = 0;
   g_trackedOrderTicket = ticket;
   g_weakSequenceCount  = 0;
   g_lastWeakCheckedBar = Time[1];

   Print("ORDER OPENED | Ticket=", ticket,
         " | Direction=",
         g_sarDirection == 1 ? "BUY" : "SELL",
         " | Price=", DoubleToString(normalizedPrice, Digits),
         " | RawMove=", DoubleToString(rawMove, Digits),
         " | Type=", orderComment);
}

//+------------------------------------------------------------------+
int OnInit()
{
   if(Bars > 3)
   {
      g_sarDirection   = GetSARDirection(1);
      g_sarSignalPrice = Close[1];
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(Bars < 10)
      return;

   UpdateSARSignal();

   if(ManageOpenOrder())
      return;

   TryOpenOrder();
}
//+------------------------------------------------------------------+
