//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA                            |
//|                  SIGNAL + PROFIT RE-ENTRY STOP                   |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INPUTS
//==================================================================

int SSLPeriod = 10;

//==================================================================
// TRADING
//==================================================================

bool   EnableTrading = true;
double Lots = 0.01;
int    MaxOpenOrders = 4;

//==================================================================
// PROFIT RE-ENTRY STOP
//==================================================================

bool EnableProfitReEntryStop = false;

double MinimumClosedProfitUSD = 0.01;

double ProfitReEntryGapRaw = 30.0;

//==================================================================
// PROFIT LADDER
//==================================================================

bool EnableProfitLadder = true;

double LadderLockGapUSD = 0.05;

double StopLossUSD = 0.25;

//==================================================================
// ORDER SETTINGS
//==================================================================

int Slippage = 30;

int MagicNumber = 6600123;

//==================================================================
// VISUALS
//==================================================================

bool ShowHistoricalSignals = true;

bool ShowSSLLines = true;

int HistoryBarsToDraw = 500;

bool ShowSignalText = true;

bool ShowSignalArrows = true;

int SignalDistancePoints = 100;

int SignalArrowWidth = 2;

int SignalFontSize = 9;

color BuyColor = clrBlue;

color SellColor = clrRed;

color SSLUpColor = clrLime;

color SSLDownColor = clrRed;

int SSLLineWidth = 2;

//==================================================================
// DASHBOARD
//==================================================================

bool ShowDashboard = true;

int DashboardRightGap = 300;

int DashboardTopGap = 20;

int DashboardWidth = 285;

int DashboardHeight = 430;

int DashboardFontSize = 9;

//==================================================================
// GLOBALS
//==================================================================

string PREFIX = "SSL_CROSS_";

string DASH_PREFIX = "SSL_DASHBOARD_";

datetime LastProcessedBar = 0;

datetime LastProcessedClosedOrderTime = 0;

int LastProcessedClosedTicket = -1;

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

int OnInit()
{
   Print("==================================================");
   Print("SSL CHANNEL CROSS EA INITIALIZED");
   Print("SIGNAL + PROFIT RE-ENTRY STOP VERSION");
   Print("Symbol: ", Symbol());
   Print("Timeframe: ", TimeframeToString(Period()));
   Print("SSL Period: ", SSLPeriod);
   Print("Lots: ", DoubleToString(Lots, 2));
   Print("Max Total Orders: ", MaxOpenOrders);
   Print("Profit Re-Entry Gap: ",
         DoubleToString(ProfitReEntryGapRaw, Digits),
         " raw price");
   Print("==================================================");

   DeleteOurObjects();

   DeleteDashboardObjects();

   if(ShowHistoricalSignals || ShowSSLLines)
   {
      DrawHistoricalSignals();
   }

   InitializeLastProcessedClosedOrder();

   if(ShowDashboard)
   {
      UpdateDashboard();
   }

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+

void OnDeinit(const int reason)
{
   DeleteOurObjects();

   DeleteDashboardObjects();
}

//+------------------------------------------------------------------+
//| MAIN TICK                                                        |
//+------------------------------------------------------------------+

void OnTick()
{
   //===============================================================
   // LIVE SSL LINES ON EVERY TICK
   //===============================================================

   if(ShowSSLLines)
   {
      UpdateSSLChannelOnTick();
   }

   //===============================================================
   // PROFITABLE CLOSED ORDER CHECK
   //===============================================================

   if(Bars >= SSLPeriod + 20)
   {
      CheckForProfitableClosedOrder();
   }

   //===============================================================
   // PROFIT LADDER
   //===============================================================

   if(EnableProfitLadder)
   {
      ManageProfitLadder();
   }

   //===============================================================
   // DASHBOARD
   //===============================================================

   if(ShowDashboard)
   {
      UpdateDashboard();
   }

   //===============================================================
   // BAR DATA CHECK
   //===============================================================

   if(Bars < SSLPeriod + 20)
   {
      return;
   }

   //===============================================================
   // PROCESS ONLY ONE SSL SIGNAL PER NEW CANDLE
   //===============================================================

   if(Time[0] == LastProcessedBar)
   {
      return;
   }

   LastProcessedBar = Time[0];

   //===============================================================
   // SSL SIGNALS
   //===============================================================

   bool buySignal = IsBuySignal(1);

   bool sellSignal = IsSellSignal(1);

   //===============================================================
   // BUY SIGNAL
   //===============================================================

   if(buySignal)
   {
      DrawLiveSignal(1, true);

      Print("SSL CROSS SIGNAL -> BUY");

      if(EnableTrading)
      {
         if(GetTotalEAOrders() < MaxOpenOrders)
         {
            OpenBuy();
         }
         else
         {
            Print("BUY BLOCKED | MAX TOTAL ORDERS REACHED");
         }
      }
   }

   //===============================================================
   // SELL SIGNAL
   //===============================================================

   if(sellSignal)
   {
      DrawLiveSignal(1, false);

      Print("SSL CROSS SIGNAL -> SELL");

      if(EnableTrading)
      {
         if(GetTotalEAOrders() < MaxOpenOrders)
         {
            OpenSell();
         }
         else
         {
            Print("SELL BLOCKED | MAX TOTAL ORDERS REACHED");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| UPDATE SSL CHANNEL ON EVERY TICK                                 |
//+------------------------------------------------------------------+

void UpdateSSLChannelOnTick()
{
   if(!ShowSSLLines)
   {
      return;
   }

   if(Bars < SSLPeriod + 20)
   {
      return;
   }

   int maxRecentBars = 10;

   if(maxRecentBars > Bars - SSLPeriod - 2)
   {
      maxRecentBars = Bars - SSLPeriod - 2;
   }

   for(int i = maxRecentBars; i >= 0; i--)
   {
      if(i + 1 >= Bars)
      {
         continue;
      }

      double up1;
      double down1;
      int hlv1;

      double up2;
      double down2;
      int hlv2;

      CalculateSSL(i, up1, down1, hlv1);

      CalculateSSL(i + 1, up2, down2, hlv2);

      DrawTrendSegment(
         PREFIX + "LIVE_UP_" + IntegerToString(i),
         Time[i],
         up1,
         Time[i + 1],
         up2,
         SSLUpColor
      );

      DrawTrendSegment(
         PREFIX + "LIVE_DOWN_" + IntegerToString(i),
         Time[i],
         down1,
         Time[i + 1],
         down2,
         SSLDownColor
      );
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| INITIALIZE CLOSED ORDER TRACKING                                 |
//+------------------------------------------------------------------+

void InitializeLastProcessedClosedOrder()
{
   datetime latestCloseTime = 0;

   int latestTicket = -1;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         continue;
      }

      if(OrderSymbol() != Symbol())
      {
         continue;
      }

      if(OrderMagicNumber() != MagicNumber)
      {
         continue;
      }

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
      {
         continue;
      }

      if(OrderCloseTime() > latestCloseTime)
      {
         latestCloseTime = OrderCloseTime();

         latestTicket = OrderTicket();
      }
   }

   LastProcessedClosedOrderTime = latestCloseTime;

   LastProcessedClosedTicket = latestTicket;
}

//+------------------------------------------------------------------+
//| CHECK PROFITABLE CLOSED ORDER                                    |
//+------------------------------------------------------------------+

void CheckForProfitableClosedOrder()
{
   datetime latestCloseTime = 0;

   double latestProfit = 0;

   int latestTicket = -1;

   int latestType = -1;

   double latestClosePrice = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
      {
         continue;
      }

      if(OrderSymbol() != Symbol())
      {
         continue;
      }

      if(OrderMagicNumber() != MagicNumber)
      {
         continue;
      }

      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
      {
         continue;
      }

      if(OrderCloseTime() <= latestCloseTime)
      {
         continue;
      }

      latestCloseTime = OrderCloseTime();

      latestTicket = OrderTicket();

      latestType = OrderType();

      latestProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();

      latestClosePrice = OrderClosePrice();
   }

   if(latestTicket < 0)
   {
      return;
   }

   if(
      latestTicket == LastProcessedClosedTicket &&
      latestCloseTime == LastProcessedClosedOrderTime
   )
   {
      return;
   }

   LastProcessedClosedTicket = latestTicket;

   LastProcessedClosedOrderTime = latestCloseTime;

   //===============================================================
   // PROFITABLE CLOSE
   //===============================================================

   if(latestProfit >= MinimumClosedProfitUSD)
   {
      Print("==================================================");

      Print("PROFITABLE ORDER CLOSED");

      Print("Ticket: ", latestTicket);

      Print(
         "Direction: ",
         latestType == OP_BUY ? "BUY" : "SELL"
      );

      Print(
         "Close Price: ",
         DoubleToString(latestClosePrice, Digits)
      );

      Print(
         "Profit: $",
         DoubleToString(latestProfit, 2)
      );

      Print("Creating new profit re-entry stop...");

      if(EnableProfitReEntryStop)
      {
         CreateProfitReEntryStop(
            latestType,
            latestClosePrice
         );
      }

      Print("==================================================");

      return;
   }

   Print(
      "ORDER CLOSED WITHOUT REQUIRED PROFIT | P/L: $",
      DoubleToString(latestProfit, 2)
   );
}

//+------------------------------------------------------------------+
//| CREATE PROFIT RE-ENTRY STOP                                      |
//+------------------------------------------------------------------+

void CreateProfitReEntryStop(
   int closedOrderType,
   double closedPrice
)
{
   if(!EnableTrading)
   {
      return;
   }

   if(!EnableProfitReEntryStop)
   {
      return;
   }

   if(GetTotalEAOrders() >= MaxOpenOrders)
   {
      Print(
         "PROFIT RE-ENTRY STOP BLOCKED | MAX ORDERS"
      );

      return;
   }

   RefreshRates();

   double entryPrice = 0;

   int pendingType = -1;

   color orderColor;

   string orderComment;

   //===============================================================
   // BUY PROFIT CLOSE -> BUY STOP
   //===============================================================

   if(closedOrderType == OP_BUY)
   {
      entryPrice =
         closedPrice +
         ProfitReEntryGapRaw;

      pendingType = OP_BUYSTOP;

      orderColor = BuyColor;

      orderComment = "SSL Profit ReEntry Buy Stop";
   }

   //===============================================================
   // SELL PROFIT CLOSE -> SELL STOP
   //===============================================================

   else
   if(closedOrderType == OP_SELL)
   {
      entryPrice =
         closedPrice -
         ProfitReEntryGapRaw;

      pendingType = OP_SELLSTOP;

      orderColor = SellColor;

      orderComment = "SSL Profit ReEntry Sell Stop";
   }
   else
   {
      return;
   }

   //===============================================================
   // BROKER MINIMUM STOP DISTANCE
   //===============================================================

   double stopLevel =
      MarketInfo(Symbol(), MODE_STOPLEVEL) *
      Point;

   double minimumGap =
      stopLevel +
      Point;

   if(pendingType == OP_BUYSTOP)
   {
      if(entryPrice < Ask + minimumGap)
      {
         entryPrice = Ask + minimumGap;
      }
   }

   if(pendingType == OP_SELLSTOP)
   {
      if(entryPrice > Bid - minimumGap)
      {
         entryPrice = Bid - minimumGap;
      }
   }

   entryPrice =
      NormalizeDouble(entryPrice, Digits);

   //===============================================================
   // INITIAL STOP LOSS
   //===============================================================

   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );

   if(slDistance <= 0)
   {
      return;
   }

   double stopLoss;

   if(pendingType == OP_BUYSTOP)
   {
      stopLoss =
         entryPrice -
         slDistance;
   }
   else
   {
      stopLoss =
         entryPrice +
         slDistance;
   }

   stopLoss =
      NormalizeDouble(stopLoss, Digits);

   //===============================================================
   // CREATE PENDING ORDER
   //===============================================================

   int ticket =
      OrderSend(
         Symbol(),
         pendingType,
         Lots,
         entryPrice,
         Slippage,
         stopLoss,
         0,
         orderComment,
         MagicNumber,
         0,
         orderColor
      );

   if(ticket < 0)
   {
      int error = GetLastError();

      Print(
         "PROFIT RE-ENTRY STOP FAILED | ERROR: ",
         error
      );
   }
   else
   {
      Print(
         "PROFIT RE-ENTRY STOP CREATED | Ticket: ",
         ticket
      );

      Print(
         "Type: ",
         pendingType == OP_BUYSTOP ?
         "BUY STOP" :
         "SELL STOP"
      );

      Print(
         "Entry: ",
         DoubleToString(entryPrice, Digits)
      );
   }
}

//+------------------------------------------------------------------+
//| TOTAL EA ORDERS                                                  |
//+------------------------------------------------------------------+

int GetTotalEAOrders()
{
   int count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(OrderSymbol() != Symbol())
      {
         continue;
      }

      if(OrderMagicNumber() != MagicNumber)
      {
         continue;
      }

      int type = OrderType();

      if(
         type == OP_BUY ||
         type == OP_SELL ||
         type == OP_BUYSTOP ||
         type == OP_SELLSTOP
      )
      {
         count++;
      }
   }

   return count;
}

//+------------------------------------------------------------------+
//| OPEN BUY                                                         |
//+------------------------------------------------------------------+

void OpenBuy()
{
   if(GetTotalEAOrders() >= MaxOpenOrders)
   {
      return;
   }

   RefreshRates();

   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );

   if(slDistance <= 0)
   {
      return;
   }

   double stopLoss =
      NormalizeDouble(
         Ask - slDistance,
         Digits
      );

   int ticket =
      OrderSend(
         Symbol(),
         OP_BUY,
         Lots,
         Ask,
         Slippage,
         stopLoss,
         0,
         "SSL Long",
         MagicNumber,
         0,
         BuyColor
      );

   if(ticket < 0)
   {
      Print(
         "BUY FAILED | ERROR: ",
         GetLastError()
      );
   }
   else
   {
      Print(
         "BUY OPENED | Ticket: ",
         ticket
      );
   }
}

//+------------------------------------------------------------------+
//| OPEN SELL                                                        |
//+------------------------------------------------------------------+

void OpenSell()
{
   if(GetTotalEAOrders() >= MaxOpenOrders)
   {
      return;
   }

   RefreshRates();

   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );

   if(slDistance <= 0)
   {
      return;
   }

   double stopLoss =
      NormalizeDouble(
         Bid + slDistance,
         Digits
      );

   int ticket =
      OrderSend(
         Symbol(),
         OP_SELL,
         Lots,
         Bid,
         Slippage,
         stopLoss,
         0,
         "SSL Short",
         MagicNumber,
         0,
         SellColor
      );

   if(ticket < 0)
   {
      Print(
         "SELL FAILED | ERROR: ",
         GetLastError()
      );
   }
   else
   {
      Print(
         "SELL OPENED | Ticket: ",
         ticket
      );
   }
}

//+------------------------------------------------------------------+
//| CALCULATE USD PRICE DISTANCE                                     |
//+------------------------------------------------------------------+

double CalculatePriceDistanceUSD(
   double usdAmount,
   double orderLots
)
{
   double tickValue =
      MarketInfo(
         Symbol(),
         MODE_TICKVALUE
      );

   double tickSize =
      MarketInfo(
         Symbol(),
         MODE_TICKSIZE
      );

   if(
      tickValue <= 0 ||
      tickSize <= 0 ||
      orderLots <= 0
   )
   {
      return 0;
   }

   return(
      usdAmount /
      (tickValue * orderLots)
   )
   *
   tickSize;
}

//+------------------------------------------------------------------+
//| PROFIT LADDER                                                    |
//+------------------------------------------------------------------+

void ManageProfitLadder()
{
   if(LadderLockGapUSD <= 0)
   {
      return;
   }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(OrderSymbol() != Symbol())
      {
         continue;
      }

      if(OrderMagicNumber() != MagicNumber)
      {
         continue;
      }

      int orderType = OrderType();

      if(
         orderType != OP_BUY &&
         orderType != OP_SELL
      )
      {
         continue;
      }

      double currentProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();

      //============================================================
      // EXAMPLE:
      //
      // LadderLockGapUSD = 0.10
      //
      // Profit 0.20 -> lock 0.10
      // Profit 0.30 -> lock 0.20
      // Profit 0.40 -> lock 0.30
      // Profit 0.50 -> lock 0.40
      //
      //============================================================

      double firstTrigger =
         LadderLockGapUSD * 2.0;

      if(currentProfit < firstTrigger)
      {
         continue;
      }

      int ladderLevel =
         (int)MathFloor(
            (
               currentProfit -
               LadderLockGapUSD
            )
            /
            LadderLockGapUSD
         );

      if(ladderLevel < 1)
      {
         ladderLevel = 1;
      }

      if(ladderLevel >2 && ladderLevel % 2 == 0)
      {
         continue;

      }

      double lockedProfit =
         ladderLevel *
         LadderLockGapUSD;

      lockedProfit =
         NormalizeDouble(
            lockedProfit,
            2
         );

      double tickValue =
         MarketInfo(
            Symbol(),
            MODE_TICKVALUE
         );

      double tickSize =
         MarketInfo(
            Symbol(),
            MODE_TICKSIZE
         );

      if(
         tickValue <= 0 ||
         tickSize <= 0
      )
      {
         continue;
      }

      double priceDistance =
         (
            lockedProfit /
            (
               tickValue *
               OrderLots()
            )
         )
         *
         tickSize;

      double newStopLoss;

      double stopLevel =
         MarketInfo(
            Symbol(),
            MODE_STOPLEVEL
         )
         *
         Point;

      //============================================================
      // BUY
      //============================================================

      if(orderType == OP_BUY)
      {
         newStopLoss =
            OrderOpenPrice() +
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         if(
            OrderStopLoss() > 0 &&
            newStopLoss <= OrderStopLoss()
         )
         {
            continue;
         }

         if(Bid - newStopLoss < stopLevel)
         {
            newStopLoss =
               NormalizeDouble(
                  Bid - stopLevel,
                  Digits
               );
         }

         if(
            newStopLoss > 0 &&
            newStopLoss < Bid
         )
         {
            if(
               OrderModify(
                  OrderTicket(),
                  OrderOpenPrice(),
                  newStopLoss,
                  OrderTakeProfit(),
                  0,
                  clrLimeGreen
               )
            )
            {
               Print(
                  "BUY LADDER | Locked: $",
                  DoubleToString(
                     lockedProfit,
                     2
                  )
               );
            }
         }
      }

      //============================================================
      // SELL
      //============================================================

      if(orderType == OP_SELL)
      {
         newStopLoss =
            OrderOpenPrice() -
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         if(
            OrderStopLoss() > 0 &&
            newStopLoss >= OrderStopLoss()
         )
         {
            continue;
         }

         if(newStopLoss - Ask < stopLevel)
         {
            newStopLoss =
               NormalizeDouble(
                  Ask + stopLevel,
                  Digits
               );
         }

         if(newStopLoss > Ask)
         {
            if(
               OrderModify(
                  OrderTicket(),
                  OrderOpenPrice(),
                  newStopLoss,
                  OrderTakeProfit(),
                  0,
                  clrTomato
               )
            )
            {
               Print(
                  "SELL LADDER | Locked: $",
                  DoubleToString(
                     lockedProfit,
                     2
                  )
               );
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| CALCULATE SSL                                                    |
//+------------------------------------------------------------------+

void CalculateSSL(
   int shift,
   double &sslUp,
   double &sslDown,
   int &hlv
)
{
   int oldest =
      Bars -
      SSLPeriod -
      2;

   if(oldest < shift)
   {
      oldest = shift;
   }

   int currentHlv = 0;

   for(int i = oldest; i >= shift; i--)
   {
      double smaHigh =
         iMA(
            Symbol(),
            Period(),
            SSLPeriod,
            0,
            MODE_SMA,
            PRICE_HIGH,
            i
         );

      double smaLow =
         iMA(
            Symbol(),
            Period(),
            SSLPeriod,
            0,
            MODE_SMA,
            PRICE_LOW,
            i
         );

      double candleClose = Close[i];

      if(candleClose > smaHigh)
      {
         currentHlv = 1;
      }
      else
      if(candleClose < smaLow)
      {
         currentHlv = -1;
      }

      if(i == shift)
      {
         hlv = currentHlv;

         if(currentHlv < 0)
         {
            sslDown = smaHigh;

            sslUp = smaLow;
         }
         else
         {
            sslDown = smaLow;

            sslUp = smaHigh;
         }

         return;
      }
   }

   hlv = currentHlv;

   sslUp = 0;

   sslDown = 0;
}

//+------------------------------------------------------------------+
//| BUY SIGNAL                                                       |
//+------------------------------------------------------------------+

bool IsBuySignal(int shift)
{
   if(shift + 1 >= Bars)
   {
      return false;
   }

   double upCurrent;
   double downCurrent;
   int hlvCurrent;

   double upPrevious;
   double downPrevious;
   int hlvPrevious;

   CalculateSSL(
      shift,
      upCurrent,
      downCurrent,
      hlvCurrent
   );

   CalculateSSL(
      shift + 1,
      upPrevious,
      downPrevious,
      hlvPrevious
   );

   return(
      upPrevious <= downPrevious &&
      upCurrent > downCurrent
   );
}

//+------------------------------------------------------------------+
//| SELL SIGNAL                                                      |
//+------------------------------------------------------------------+

bool IsSellSignal(int shift)
{
   if(shift + 1 >= Bars)
   {
      return false;
   }

   double upCurrent;
   double downCurrent;
   int hlvCurrent;

   double upPrevious;
   double downPrevious;
   int hlvPrevious;

   CalculateSSL(
      shift,
      upCurrent,
      downCurrent,
      hlvCurrent
   );

   CalculateSSL(
      shift + 1,
      upPrevious,
      downPrevious,
      hlvPrevious
   );

   return(
      upPrevious >= downPrevious &&
      upCurrent < downCurrent
   );
}

//+------------------------------------------------------------------+
//| DRAW HISTORICAL SIGNALS                                          |
//+------------------------------------------------------------------+

void DrawHistoricalSignals()
{
   int barsToProcess =
      HistoryBarsToDraw;

   if(
      barsToProcess >
      Bars -
      SSLPeriod -
      3
   )
   {
      barsToProcess =
         Bars -
         SSLPeriod -
         3;
   }

   if(barsToProcess <= 0)
   {
      return;
   }

   if(ShowSSLLines)
   {
      for(int i = barsToProcess; i >= 1; i--)
      {
         double up1;
         double down1;
         int hlv1;

         double up2;
         double down2;
         int hlv2;

         CalculateSSL(
            i,
            up1,
            down1,
            hlv1
         );

         CalculateSSL(
            i - 1,
            up2,
            down2,
            hlv2
         );

         DrawTrendSegment(
            PREFIX +
            "HIST_UP_" +
            IntegerToString(i),
            Time[i],
            up1,
            Time[i - 1],
            up2,
            SSLUpColor
         );

         DrawTrendSegment(
            PREFIX +
            "HIST_DOWN_" +
            IntegerToString(i),
            Time[i],
            down1,
            Time[i - 1],
            down2,
            SSLDownColor
         );
      }
   }

   if(ShowHistoricalSignals)
   {
      for(int i = barsToProcess; i >= 1; i--)
      {
         if(IsBuySignal(i))
         {
            DrawHistoricalSignal(i, true);
         }

         if(IsSellSignal(i))
         {
            DrawHistoricalSignal(i, false);
         }
      }
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| DRAW TREND SEGMENT                                               |
//+------------------------------------------------------------------+

void DrawTrendSegment(
   string name,
   datetime time1,
   double price1,
   datetime time2,
   double price2,
   color lineColor
)
{
   if(price1 <= 0 || price2 <= 0)
   {
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_TREND,
         0,
         time1,
         price1,
         time2,
         price2
      );
   }
   else
   {
      ObjectMove(
         0,
         name,
         0,
         time1,
         price1
      );

      ObjectMove(
         0,
         name,
         1,
         time2,
         price2
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      lineColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_WIDTH,
      SSLLineWidth
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_RAY_RIGHT,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BACK,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );
}

//+------------------------------------------------------------------+
//| DRAW SIGNAL                                                      |
//+------------------------------------------------------------------+

void DrawHistoricalSignal(
   int shift,
   bool isBuy
)
{
   string type =
      isBuy ? "BUY" : "SELL";

   string baseName =
      PREFIX +
      type +
      "_" +
      IntegerToString(
         (int)Time[shift]
      );

   double price;

   if(isBuy)
   {
      price =
         Low[shift] -
         SignalDistancePoints *
         Point;
   }
   else
   {
      price =
         High[shift] +
         SignalDistancePoints *
         Point;
   }

   if(ShowSignalArrows)
   {
      string arrowName =
         baseName +
         "_ARROW";

      if(ObjectFind(0, arrowName) < 0)
      {
         ObjectCreate(
            0,
            arrowName,
            OBJ_ARROW,
            0,
            Time[shift],
            price
         );
      }

      ObjectMove(
         0,
         arrowName,
         0,
         Time[shift],
         price
      );

      ObjectSetInteger(
         0,
         arrowName,
         OBJPROP_ARROWCODE,
         isBuy ? 233 : 234
      );

      ObjectSetInteger(
         0,
         arrowName,
         OBJPROP_COLOR,
         isBuy ? BuyColor : SellColor
      );

      ObjectSetInteger(
         0,
         arrowName,
         OBJPROP_WIDTH,
         SignalArrowWidth
      );

      ObjectSetInteger(
         0,
         arrowName,
         OBJPROP_SELECTABLE,
         false
      );
   }

   if(ShowSignalText)
   {
      string textName =
         baseName +
         "_TEXT";

      double textPrice;

      if(isBuy)
      {
         textPrice =
            price -
            SignalDistancePoints *
            0.30 *
            Point;
      }
      else
      {
         textPrice =
            price +
            SignalDistancePoints *
            0.30 *
            Point;
      }

      if(ObjectFind(0, textName) < 0)
      {
         ObjectCreate(
            0,
            textName,
            OBJ_TEXT,
            0,
            Time[shift],
            textPrice
         );
      }

      ObjectMove(
         0,
         textName,
         0,
         Time[shift],
         textPrice
      );

      ObjectSetString(
         0,
         textName,
         OBJPROP_TEXT,
         isBuy ? "Long +1" : "Short -1"
      );

      ObjectSetInteger(
         0,
         textName,
         OBJPROP_COLOR,
         isBuy ? BuyColor : SellColor
      );

      ObjectSetInteger(
         0,
         textName,
         OBJPROP_FONTSIZE,
         SignalFontSize
      );

      ObjectSetString(
         0,
         textName,
         OBJPROP_FONT,
         "Arial"
      );

      ObjectSetInteger(
         0,
         textName,
         OBJPROP_SELECTABLE,
         false
      );
   }
}

//+------------------------------------------------------------------+
//| DRAW LIVE SIGNAL                                                 |
//+------------------------------------------------------------------+

void DrawLiveSignal(
   int shift,
   bool isBuy
)
{
   DrawHistoricalSignal(
      shift,
      isBuy
   );

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| TIMEFRAME STRING                                                 |
//+------------------------------------------------------------------+

string TimeframeToString(int timeframe)
{
   switch(timeframe)
   {
      case PERIOD_M1:
         return "M1";

      case PERIOD_M5:
         return "M5";

      case PERIOD_M15:
         return "M15";

      case PERIOD_M30:
         return "M30";

      case PERIOD_H1:
         return "H1";

      case PERIOD_H4:
         return "H4";

      case PERIOD_D1:
         return "D1";

      case PERIOD_W1:
         return "W1";

      case PERIOD_MN1:
         return "MN1";
   }

   return "CURRENT";
}

//+------------------------------------------------------------------+
//| DASHBOARD PANEL                                                  |
//+------------------------------------------------------------------+

void CreateDashboardPanel(
   string name,
   int x,
   int y,
   int width,
   int height,
   color background
)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_RECTANGLE_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XSIZE,
      width
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YSIZE,
      height
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BGCOLOR,
      background
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_BORDER_TYPE,
      BORDER_FLAT
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      clrDimGray
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );
}

//+------------------------------------------------------------------+
//| DASHBOARD LABEL                                                  |
//+------------------------------------------------------------------+

void CreateDashboardLabel(
   string name,
   string text,
   int x,
   int y,
   int fontSize,
   color textColor
)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(
         0,
         name,
         OBJ_LABEL,
         0,
         0,
         0
      );
   }

   ObjectSetInteger(
      0,
      name,
      OBJPROP_CORNER,
      CORNER_RIGHT_UPPER
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_XDISTANCE,
      x
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_YDISTANCE,
      y
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_TEXT,
      text
   );

   ObjectSetString(
      0,
      name,
      OBJPROP_FONT,
      "Arial"
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_FONTSIZE,
      fontSize
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_COLOR,
      textColor
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_SELECTABLE,
      false
   );

   ObjectSetInteger(
      0,
      name,
      OBJPROP_HIDDEN,
      true
   );
}

//+------------------------------------------------------------------+
//| DASHBOARD                                                        |
//+------------------------------------------------------------------+

void UpdateDashboard()
{
   int totalOrders = 0;

   int buyOrders = 0;

   int sellOrders = 0;

   int pendingOrders = 0;

   double floatingProfit = 0;

   double totalSwap = 0;

   double totalCommission = 0;

   string ordersDetails = "";

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      {
         continue;
      }

      if(OrderSymbol() != Symbol())
      {
         continue;
      }

      if(OrderMagicNumber() != MagicNumber)
      {
         continue;
      }

      int type = OrderType();

      if(
         type != OP_BUY &&
         type != OP_SELL &&
         type != OP_BUYSTOP &&
         type != OP_SELLSTOP
      )
      {
         continue;
      }

      totalOrders++;

      if(type == OP_BUY)
      {
         buyOrders++;

         floatingProfit += OrderProfit();

         totalSwap += OrderSwap();

         totalCommission += OrderCommission();
      }

      if(type == OP_SELL)
      {
         sellOrders++;

         floatingProfit += OrderProfit();

         totalSwap += OrderSwap();

         totalCommission += OrderCommission();
      }

      if(
         type == OP_BUYSTOP ||
         type == OP_SELLSTOP
      )
      {
         pendingOrders++;
      }

      string orderType;

      if(type == OP_BUY)
      {
         orderType = "BUY";
      }
      else
      if(type == OP_SELL)
      {
         orderType = "SELL";
      }
      else
      if(type == OP_BUYSTOP)
      {
         orderType = "BUY STOP";
      }
      else
      {
         orderType = "SELL STOP";
      }

      string orderLine =
         "#" +
         IntegerToString(OrderTicket()) +
         " " +
         orderType;

      if(
         type == OP_BUY ||
         type == OP_SELL
      )
      {
         double orderNetProfit =
            OrderProfit() +
            OrderSwap() +
            OrderCommission();

         orderLine +=
            " P/L: " +
            DoubleToString(
               orderNetProfit,
               2
            );
      }
      else
      {
         orderLine +=
            " @ " +
            DoubleToString(
               OrderOpenPrice(),
               Digits
            );
      }

      ordersDetails +=
         orderLine +
         "\n";
   }

   double netProfit =
      floatingProfit +
      totalSwap +
      totalCommission;

   color profitColor;

   if(netProfit > 0)
   {
      profitColor = clrLimeGreen;
   }
   else
   if(netProfit < 0)
   {
      profitColor = clrTomato;
   }
   else
   {
      profitColor = clrWhite;
   }

   int x = DashboardRightGap;

   int y = DashboardTopGap;

   CreateDashboardPanel(
      DASH_PREFIX + "PANEL",
      x,
      y,
      DashboardWidth,
      DashboardHeight,
      clrBlack
   );

   CreateDashboardPanel(
      DASH_PREFIX + "HEADER",
      x,
      y,
      DashboardWidth,
      35,
      C'30,60,100'
   );

   int textX =
      x +
      DashboardWidth -
      300;

   CreateDashboardLabel(
      DASH_PREFIX + "TITLE",
      "SSL CHANNEL CROSS EA",
      textX,
      y + 8,
      11,
      clrWhite
   );

   string statusText;

   if(totalOrders >= MaxOpenOrders)
   {
      statusText = "MAX ORDERS REACHED";
   }
   else
   {
      statusText = "READY FOR NEXT SIGNAL";
   }

   CreateDashboardLabel(
      DASH_PREFIX + "STATUS",
      statusText,
      textX,
      y + 50,
      DashboardFontSize,
      clrLimeGreen
   );

   CreateDashboardLabel(
      DASH_PREFIX + "SYMBOL",
      "Symbol: " + Symbol(),
      textX,
      y + 72,
      DashboardFontSize,
      clrWhite
   );

   CreateDashboardLabel(
      DASH_PREFIX + "TIMEFRAME",
      "Timeframe: " +
      TimeframeToString(Period()),
      textX,
      y + 94,
      DashboardFontSize,
      clrWhite
   );

   CreateDashboardLabel(
      DASH_PREFIX + "PNL",
      "LIVE P/L: " +
      DoubleToString(netProfit, 2),
      textX,
      y + 142,
      13,
      profitColor
   );

   CreateDashboardLabel(
      DASH_PREFIX + "ORDERS",
      "Total Orders: " +
      IntegerToString(totalOrders) +
      " / " +
      IntegerToString(MaxOpenOrders),
      textX,
      y + 174,
      DashboardFontSize,
      clrWhite
   );

   CreateDashboardLabel(
      DASH_PREFIX + "BUY",
      "BUY: " +
      IntegerToString(buyOrders),
      textX,
      y + 196,
      DashboardFontSize,
      clrDeepSkyBlue
   );

   CreateDashboardLabel(
      DASH_PREFIX + "SELL",
      "SELL: " +
      IntegerToString(sellOrders),
      textX + 90,
      y + 196,
      DashboardFontSize,
      clrTomato
   );

   CreateDashboardLabel(
      DASH_PREFIX + "PENDING",
      "Pending: " +
      IntegerToString(pendingOrders),
      textX + 180,
      y + 196,
      DashboardFontSize,
      clrGold
   );

   CreateDashboardLabel(
      DASH_PREFIX + "SL",
      "Initial SL: -$" +
      DoubleToString(
         StopLossUSD,
         2
      ),
      textX,
      y + 250,
      DashboardFontSize,
      clrTomato
   );

   CreateDashboardLabel(
      DASH_PREFIX + "LADDER",
      "Ladder Gap: $" +
      DoubleToString(
         LadderLockGapUSD,
         2
      ),
      textX,
      y + 272,
      DashboardFontSize,
      clrLimeGreen
   );

   CreateDashboardLabel(
      DASH_PREFIX + "REENTRY",
      "Re-entry Gap: " +
      DoubleToString(
         ProfitReEntryGapRaw,
         Digits
      ) +
      " raw",
      textX,
      y + 294,
      DashboardFontSize,
      clrGold
   );

   CreateDashboardLabel(
      DASH_PREFIX + "DETAIL_TITLE",
      "LIVE ORDER DETAILS",
      textX,
      y + 326,
      DashboardFontSize,
      clrGold
   );

   if(totalOrders > 0)
   {
      CreateDashboardLabel(
         DASH_PREFIX + "DETAILS",
         ordersDetails,
         textX,
         y + 348,
         DashboardFontSize,
         clrWhite
      );
   }
   else
   {
      CreateDashboardLabel(
         DASH_PREFIX + "DETAILS",
         "No active orders",
         textX,
         y + 348,
         DashboardFontSize,
         clrSilver
      );
   }

   CreateDashboardLabel(
      DASH_PREFIX + "PRICE",
      "Bid: " +
      DoubleToString(
         Bid,
         Digits
      ),
      textX,
      y + 390,
      DashboardFontSize,
      clrWhite
   );

   CreateDashboardLabel(
      DASH_PREFIX + "UPDATE",
      "Updated: " +
      TimeToString(
         TimeCurrent(),
         TIME_SECONDS
      ),
      textX,
      y + 410,
      8,
      clrSilver
   );
}

//+------------------------------------------------------------------+
//| DELETE EA OBJECTS                                                |
//+------------------------------------------------------------------+

void DeleteOurObjects()
{
   int total =
      ObjectsTotal(
         0,
         -1,
         -1
      );

   for(int i = total - 1; i >= 0; i--)
   {
      string name =
         ObjectName(
            0,
            i,
            -1,
            -1
         );

      if(
         StringFind(
            name,
            PREFIX,
            0
         ) == 0
      )
      {
         ObjectDelete(
            0,
            name
         );
      }
   }
}

//+------------------------------------------------------------------+
//| DELETE DASHBOARD OBJECTS                                         |
//+------------------------------------------------------------------+

void DeleteDashboardObjects()
{
   int total =
      ObjectsTotal(
         0,
         -1,
         -1
      );

   for(int i = total - 1; i >= 0; i--)
   {
      string name =
         ObjectName(
            0,
            i,
            -1,
            -1
         );

      if(
         StringFind(
            name,
            DASH_PREFIX,
            0
         ) == 0
      )
      {
         ObjectDelete(
            0,
            name
         );
      }
   }
}

//+------------------------------------------------------------------+
//| END OF EA                                                        |
//+------------------------------------------------------------------+