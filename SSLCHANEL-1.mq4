//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA                            |
//|                  COMPLETE MQL4 EA                                |
//+------------------------------------------------------------------+
#property strict

//==================================================================
// INPUTS
//==================================================================

input int      SSLPeriod = 10;

//========================= TRADING ================================

input bool     EnableTrading = true;

input double   Lots = 0.01;


//==================================================================
// PROFIT LADDER
//==================================================================

input bool     EnableProfitLadder = true;

// First ladder level
input double   LadderStepUSD = 1.00;

// Distance between current ladder level and locked profit
input double   LadderLockGapUSD = 0.50;

// Initial broker-side stop loss
input double   StopLossUSD = 0.50;

input int      Slippage = 30;

input int      MagicNumber = 6600123;


//==================================================================
// VISUALS
//==================================================================

input bool     ShowHistoricalSignals = true;

input bool     ShowSSLLines = true;

input int      HistoryBarsToDraw = 500;

input bool     ShowSignalText = true;

input bool     ShowSignalArrows = true;

input int      SignalDistancePoints = 100;

input int      SignalArrowWidth = 2;

input int      SignalFontSize = 9;

input color    BuyColor = clrBlue;

input color    SellColor = clrRed;

input color    SSLUpColor = clrLime;

input color    SSLDownColor = clrRed;

input int      SSLLineWidth = 2;


//==================================================================
// DASHBOARD
//==================================================================

input bool     ShowDashboard = true;

// Right side of chart
input int      DashboardCorner = 1;

// 300px gap from right edge
input int      DashboardRightGap = 300;

input int      DashboardTopGap = 20;

input int      DashboardWidth = 285;

input int      DashboardHeight = 430;

input int      DashboardFontSize = 9;


//==================================================================
// GLOBAL VARIABLES
//==================================================================

string PREFIX = "SSL_CROSS_";

string DASH_PREFIX = "SSL_DASHBOARD_";

datetime LastProcessedBar = 0;


//+------------------------------------------------------------------+
//| INITIALIZATION                                                    |
//+------------------------------------------------------------------+

int OnInit()
{
   Print("==================================================");

   Print("SSL CHANNEL CROSS EA INITIALIZED");

   Print("Symbol: ", Symbol());

   Print("Timeframe: ", TimeframeToString(Period()));

   Print("SSL Period: ", SSLPeriod);

   Print("Lots: ", DoubleToString(Lots, 2));

   Print("Initial SL: $",
         DoubleToString(StopLossUSD, 2));

   Print("Unlimited Profit Ladder: ENABLED");

   Print("==================================================");

   DeleteOurObjects();

   DeleteDashboardObjects();

   if(ShowHistoricalSignals)
      DrawHistoricalSignals();

   if(ShowDashboard)
      UpdateDashboard();

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                  |
//+------------------------------------------------------------------+

void OnDeinit(
   const int reason
)
{
   DeleteOurObjects();

   DeleteDashboardObjects();
}


//+------------------------------------------------------------------+
//| MAIN TICK                                                         |
//+------------------------------------------------------------------+

void OnTick()
{
   //===============================================================
   // LIVE DASHBOARD
   //===============================================================

   if(ShowDashboard)
      UpdateDashboard();


   //===============================================================
   // CHECK BARS
   //===============================================================

   if(Bars < SSLPeriod + 20)
      return;


   //===============================================================
   // DRAW HISTORICAL SIGNALS
   //===============================================================

   if(ShowHistoricalSignals)
      DrawHistoricalSignals();


   //===============================================================
   // MANAGE UNLIMITED SERVER-SIDE PROFIT LADDER
   //===============================================================

   if(EnableProfitLadder)
      ManageProfitLadder();


   //===============================================================
   // NEW CANDLE CHECK
   //===============================================================

   if(Time[0] == LastProcessedBar)
      return;


   LastProcessedBar = Time[0];


   //===============================================================
   // SIGNALS FROM LAST CLOSED CANDLE
   //===============================================================

   bool buySignal =
      IsBuySignal(1);

   bool sellSignal =
      IsSellSignal(1);


   //===============================================================
   // BUY SIGNAL
   //===============================================================

   if(buySignal)
   {
      DrawLiveSignal(
         1,
         true
      );

      Print(
         "SSL LONG SIGNAL -> BUY"
      );

      if(EnableTrading)
      {
         // IMPORTANT:
         // DO NOT CLOSE SELL ORDERS
         // WHEN BUY SIGNAL APPEARS.

         if(!HasBuyOrder())
            OpenBuy();
      }
   }


   //===============================================================
   // SELL SIGNAL
   //===============================================================

   if(sellSignal)
   {
      DrawLiveSignal(
         1,
         false
      );

      Print(
         "SSL SHORT SIGNAL -> SELL"
      );

      if(EnableTrading)
      {
         // IMPORTANT:
         // DO NOT CLOSE BUY ORDERS
         // WHEN SELL SIGNAL APPEARS.

         if(!HasSellOrder())
            OpenSell();
      }
   }
}


//+------------------------------------------------------------------+
//| CALCULATE SSL CHANNEL                                             |
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
      oldest = shift;


   int currentHlv = 0;


   for(
      int i = oldest;
      i >= shift;
      i--
   )
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


      double candleClose =
         Close[i];


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
         hlv =
            currentHlv;


         if(currentHlv < 0)
         {
            sslDown =
               smaHigh;

            sslUp =
               smaLow;
         }
         else
         {
            sslDown =
               smaLow;

            sslUp =
               smaHigh;
         }


         return;
      }
   }


   hlv =
      currentHlv;


   sslUp =
      0;

   sslDown =
      0;
}


//+------------------------------------------------------------------+
//| BUY SIGNAL                                                        |
//+------------------------------------------------------------------+

bool IsBuySignal(
   int shift
)
{
   if(shift + 1 >= Bars)
      return false;


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
//| SELL SIGNAL                                                       |
//+------------------------------------------------------------------+

bool IsSellSignal(
   int shift
)
{
   if(shift + 1 >= Bars)
      return false;


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
//| DRAW HISTORICAL SIGNALS                                           |
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
      return;


   //===============================================================
   // SSL LINES
   //===============================================================

   if(ShowSSLLines)
   {
      for(
         int i = barsToProcess;
         i >= 1;
         i--
      )
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


         string upName =
            PREFIX +
            "UP_" +
            IntegerToString(i);


         string downName =
            PREFIX +
            "DOWN_" +
            IntegerToString(i);


         DrawTrendSegment(
            upName,
            Time[i],
            up1,
            Time[i - 1],
            up2,
            SSLUpColor
         );


         DrawTrendSegment(
            downName,
            Time[i],
            down1,
            Time[i - 1],
            down2,
            SSLDownColor
         );
      }
   }


   //===============================================================
   // SIGNALS
   //===============================================================

   for(
      int i = barsToProcess;
      i >= 1;
      i--
   )
   {
      if(IsBuySignal(i))
      {
         DrawHistoricalSignal(
            i,
            true
         );
      }


      if(IsSellSignal(i))
      {
         DrawHistoricalSignal(
            i,
            false
         );
      }
   }


   ChartRedraw();
}


//+------------------------------------------------------------------+
//| DRAW SSL TREND SEGMENT                                            |
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
}


//+------------------------------------------------------------------+
//| DRAW SIGNAL                                                       |
//+------------------------------------------------------------------+

void DrawHistoricalSignal(
   int shift,
   bool isBuy
)
{
   string type;


   if(isBuy)
      type = "BUY";
   else
      type = "SELL";


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


   //===============================================================
   // ARROW
   //===============================================================

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
         isBuy ?
         233 :
         234
      );


      ObjectSetInteger(
         0,
         arrowName,
         OBJPROP_COLOR,
         isBuy ?
         BuyColor :
         SellColor
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


   //===============================================================
   // TEXT
   //===============================================================

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


      string signalText;


      if(isBuy)
         signalText = "Long +1";
      else
         signalText = "Short -1";


      ObjectSetString(
         0,
         textName,
         OBJPROP_TEXT,
         signalText
      );


      ObjectSetInteger(
         0,
         textName,
         OBJPROP_COLOR,
         isBuy ?
         BuyColor :
         SellColor
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
//| DRAW LIVE SIGNAL                                                  |
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
//| GET TICK VALUE                                                    |
//+------------------------------------------------------------------+

double GetTickValue()
{
   return(
      MarketInfo(
         Symbol(),
         MODE_TICKVALUE
      )
   );
}


//+------------------------------------------------------------------+
//| GET TICK SIZE                                                     |
//+------------------------------------------------------------------+

double GetTickSize()
{
   return(
      MarketInfo(
         Symbol(),
         MODE_TICKSIZE
      )
   );
}


//+------------------------------------------------------------------+
//| CALCULATE PRICE DISTANCE FROM USD                                |
//+------------------------------------------------------------------+

double CalculatePriceDistanceUSD(
   double usdAmount,
   double orderLots
)
{
   double tickValue =
      GetTickValue();


   double tickSize =
      GetTickSize();


   if(
      tickValue <= 0 ||
      tickSize <= 0 ||
      orderLots <= 0
   )
   {
      return 0;
   }


   double priceDistance =
      (
         usdAmount /
         (
            tickValue *
            orderLots
         )
      )
      *
      tickSize;


   return priceDistance;
}


//+------------------------------------------------------------------+
//| OPEN BUY                                                          |
//+------------------------------------------------------------------+

void OpenBuy()
{
   RefreshRates();


   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );


   if(slDistance <= 0)
   {
      Print(
         "BUY: Invalid SL calculation"
      );


      return;
   }


   double stopLoss =
      NormalizeDouble(
         Ask -
         slDistance,
         Digits
      );


   // IMPORTANT:
   // NO FIXED TAKE PROFIT.
   // Unlimited profit ladder manages the SL.

   double takeProfit = 0;


   int ticket =
      OrderSend(
         Symbol(),
         OP_BUY,
         Lots,
         Ask,
         Slippage,
         stopLoss,
         takeProfit,
         "SSL Long",
         MagicNumber,
         0,
         BuyColor
      );


   if(ticket < 0)
   {
      Print(
         "BUY OrderSend failed. Error: ",
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
//| OPEN SELL                                                         |
//+------------------------------------------------------------------+

void OpenSell()
{
   RefreshRates();


   double slDistance =
      CalculatePriceDistanceUSD(
         StopLossUSD,
         Lots
      );


   if(slDistance <= 0)
   {
      Print(
         "SELL: Invalid SL calculation"
      );


      return;
   }


   double stopLoss =
      NormalizeDouble(
         Bid +
         slDistance,
         Digits
      );


   // NO FIXED TAKE PROFIT

   double takeProfit = 0;


   int ticket =
      OrderSend(
         Symbol(),
         OP_SELL,
         Lots,
         Bid,
         Slippage,
         stopLoss,
         takeProfit,
         "SSL Short",
         MagicNumber,
         0,
         SellColor
      );


   if(ticket < 0)
   {
      Print(
         "SELL OrderSend failed. Error: ",
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
//| CHECK BUY ORDER                                                   |
//+------------------------------------------------------------------+

bool HasBuyOrder()
{
   for(
      int i = OrdersTotal() - 1;
      i >= 0;
      i--
   )
   {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
         continue;


      if(
         OrderSymbol() !=
         Symbol()
      )
         continue;


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
         continue;


      if(
         OrderType() ==
         OP_BUY
      )
         return true;
   }


   return false;
}


//+------------------------------------------------------------------+
//| CHECK SELL ORDER                                                  |
//+------------------------------------------------------------------+

bool HasSellOrder()
{
   for(
      int i = OrdersTotal() - 1;
      i >= 0;
      i--
   )
   {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
         continue;


      if(
         OrderSymbol() !=
         Symbol()
      )
         continue;


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
         continue;


      if(
         OrderType() ==
         OP_SELL
      )
         return true;
   }


   return false;
}


//+------------------------------------------------------------------+
//| CREATE DASHBOARD PANEL                                            |
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
//| CREATE DASHBOARD LABEL                                            |
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
//| UPDATE DASHBOARD                                                  |
//+------------------------------------------------------------------+

void UpdateDashboard()
{
   int totalOrders = 0;

   int buyOrders = 0;

   int sellOrders = 0;

   double totalLots = 0;

   double floatingProfit = 0;

   double totalSwap = 0;

   double totalCommission = 0;


   string ordersDetails = "";


   //===============================================================
   // READ EA ORDERS
   //===============================================================

   for(
      int i = OrdersTotal() - 1;
      i >= 0;
      i--
   )
   {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
         continue;


      if(
         OrderSymbol() !=
         Symbol()
      )
         continue;


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
         continue;


      int type =
         OrderType();


      if(
         type != OP_BUY &&
         type != OP_SELL
      )
         continue;


      totalOrders++;


      totalLots +=
         OrderLots();


      floatingProfit +=
         OrderProfit();


      totalSwap +=
         OrderSwap();


      totalCommission +=
         OrderCommission();


      if(type == OP_BUY)
         buyOrders++;


      if(type == OP_SELL)
         sellOrders++;


      string orderType;


      if(type == OP_BUY)
         orderType = "BUY";
      else
         orderType = "SELL";


      string orderLine =
         "#" +
         IntegerToString(
            OrderTicket()
         );


      orderLine +=
         "  " +
         orderType;


      orderLine +=
         "  " +
         DoubleToString(
            OrderLots(),
            2
         );


      orderLine +=
         "  P/L: ";


      double orderNetProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();


      if(orderNetProfit >= 0)
      {
         orderLine +=
            "+$" +
            DoubleToString(
               orderNetProfit,
               2
            );
      }
      else
      {
         orderLine +=
            "-$" +
            DoubleToString(
               MathAbs(orderNetProfit),
               2
            );
      }


      ordersDetails +=
         orderLine +
         "\n";
   }


   //===============================================================
   // NET P/L
   //===============================================================

   double netProfit =
      floatingProfit +
      totalSwap +
      totalCommission;


   //===============================================================
   // DASHBOARD COLORS
   //===============================================================

   color dashboardBackground =
      clrBlack;


   color headerColor =
      C'30,60,100';


   color profitColor;


   if(netProfit > 0)
      profitColor = clrLimeGreen;
   else
   if(netProfit < 0)
      profitColor = clrTomato;
   else
      profitColor = clrWhite;


   color statusColor;


   if(totalOrders > 0)
      statusColor = clrLimeGreen;
   else
      statusColor = clrSilver;


   //===============================================================
   // RIGHT-SIDE POSITION
   //===============================================================

   int x =
      DashboardRightGap;


   int y =
      DashboardTopGap;


   //===============================================================
   // MAIN BLACK PANEL
   //===============================================================

   CreateDashboardPanel(
      DASH_PREFIX + "PANEL",
      x,
      y,
      DashboardWidth,
      DashboardHeight,
      dashboardBackground
   );


   //===============================================================
   // HEADER
   //===============================================================

   CreateDashboardPanel(
      DASH_PREFIX + "HEADER",
      x,
      y,
      DashboardWidth,
      35,
      headerColor
   );


   //===============================================================
   // TITLE
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "TITLE",
      "SSL CHANNEL CROSS EA",
      x + DashboardWidth - 270,
      y + 8,
      11,
      clrWhite
   );


   //===============================================================
   // STATUS
   //===============================================================

   string statusText;


   if(totalOrders > 0)
      statusText = "TRADING ACTIVE";
   else
      statusText = "WAITING FOR SIGNAL";


   CreateDashboardLabel(
      DASH_PREFIX + "STATUS",
      statusText,
      x + DashboardWidth - 270,
      y + 50,
      DashboardFontSize,
      statusColor
   );


   //===============================================================
   // SYMBOL
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "SYMBOL",
      "Symbol: " + Symbol(),
      x + DashboardWidth - 270,
      y + 72,
      DashboardFontSize,
      clrWhite
   );


   //===============================================================
   // TIMEFRAME
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "TIMEFRAME",
      "Timeframe: " +
      TimeframeToString(Period()),
      x + DashboardWidth - 270,
      y + 94,
      DashboardFontSize,
      clrWhite
   );


   //===============================================================
   // SEPARATOR
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "SEP1",
      "-----------------------------",
      x + DashboardWidth - 270,
      y + 116,
      DashboardFontSize,
      clrGray
   );


   //===============================================================
   // LIVE P/L
   //===============================================================

   string pnlText;


   if(netProfit >= 0)
   {
      pnlText =
         "LIVE P/L: +$" +
         DoubleToString(
            netProfit,
            2
         );
   }
   else
   {
      pnlText =
         "LIVE P/L: -$" +
         DoubleToString(
            MathAbs(netProfit),
            2
         );
   }


   CreateDashboardLabel(
      DASH_PREFIX + "PNL",
      pnlText,
      x + DashboardWidth - 270,
      y + 142,
      13,
      profitColor
   );


   //===============================================================
   // ORDER COUNT
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "ORDERS",
      "Open Orders: " +
      IntegerToString(
         totalOrders
      ),
      x + DashboardWidth - 270,
      y + 174,
      DashboardFontSize,
      clrWhite
   );


   //===============================================================
   // BUY COUNT
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "BUY",
      "BUY: " +
      IntegerToString(
         buyOrders
      ),
      x + DashboardWidth - 270,
      y + 196,
      DashboardFontSize,
      clrDeepSkyBlue
   );


   //===============================================================
   // SELL COUNT
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "SELL",
      "SELL: " +
      IntegerToString(
         sellOrders
      ),
      x + DashboardWidth - 180,
      y + 196,
      DashboardFontSize,
      clrTomato
   );


   //===============================================================
   // LOTS
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "LOTS",
      "Lots: " +
      DoubleToString(
         totalLots,
         2
      ),
      x + DashboardWidth - 100,
      y + 196,
      DashboardFontSize,
      clrGold
   );


   //===============================================================
   // TRADE SETTINGS
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "SETTINGS",
      "TRADE SETTINGS",
      x + DashboardWidth - 270,
      y + 228,
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
      x + DashboardWidth - 270,
      y + 250,
      DashboardFontSize,
      clrTomato
   );


   CreateDashboardLabel(
      DASH_PREFIX + "LADDER",
      "Ladder: $" +
      DoubleToString(
         LadderStepUSD,
         2
      ) +
      " unlimited",
      x + DashboardWidth - 270,
      y + 272,
      DashboardFontSize,
      clrLimeGreen
   );


   //===============================================================
   // ORDER DETAILS
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "DETAIL_TITLE",
      "LIVE ORDER DETAILS",
      x + DashboardWidth - 270,
      y + 304,
      DashboardFontSize,
      clrGold
   );


   if(totalOrders > 0)
   {
      CreateDashboardLabel(
         DASH_PREFIX + "DETAILS",
         ordersDetails,
         x + DashboardWidth - 270,
         y + 326,
         DashboardFontSize,
         clrWhite
      );
   }
   else
   {
      CreateDashboardLabel(
         DASH_PREFIX + "DETAILS",
         "No active orders",
         x + DashboardWidth - 270,
         y + 326,
         DashboardFontSize,
         clrSilver
      );
   }


   //===============================================================
   // CURRENT PRICE
   //===============================================================

   string priceText =
      "Bid: " +
      DoubleToString(
         Bid,
         Digits
      );


   CreateDashboardLabel(
      DASH_PREFIX + "PRICE",
      priceText,
      x + DashboardWidth - 270,
      y + 390,
      DashboardFontSize,
      clrWhite
   );


   //===============================================================
   // LAST UPDATE
   //===============================================================

   CreateDashboardLabel(
      DASH_PREFIX + "UPDATE",
      "Updated: " +
      TimeToString(
         TimeCurrent(),
         TIME_SECONDS
      ),
      x + DashboardWidth - 270,
      y + 410,
      8,
      clrSilver
   );


   ChartRedraw();
}


//+------------------------------------------------------------------+
//| UNLIMITED SERVER-SIDE PROFIT LADDER                              |
//+------------------------------------------------------------------+

void ManageProfitLadder()
{
   for(
      int i = OrdersTotal() - 1;
      i >= 0;
      i--
   )
   {
      if(
         !OrderSelect(
            i,
            SELECT_BY_POS,
            MODE_TRADES
         )
      )
      {
         continue;
      }


      if(
         OrderSymbol() !=
         Symbol()
      )
      {
         continue;
      }


      if(
         OrderMagicNumber() !=
         MagicNumber
      )
      {
         continue;
      }


      int orderType =
         OrderType();


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
      // LADDER LEVEL
      //============================================================

      if(
         currentProfit <
         LadderStepUSD
      )
      {
         continue;
      }


      int multiplier =
         (int)MathFloor(
            currentProfit /
            LadderStepUSD
         );


      if(multiplier < 1)
         multiplier = 1;


      //============================================================
      // LOCK PROFIT
      //============================================================

      double lockedProfit =
         (
            multiplier *
            LadderStepUSD
         )
         -
         LadderLockGapUSD;


      if(lockedProfit <= 0)
         continue;


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


         // Never move SL backwards

         if(
            OrderStopLoss() > 0 &&
            newStopLoss <=
            OrderStopLoss()
         )
         {
            continue;
         }


         double stopLevel =
            MarketInfo(
               Symbol(),
               MODE_STOPLEVEL
            )
            *
            Point;


         if(
            Bid -
            newStopLoss
            <
            stopLevel
         )
         {
            newStopLoss =
               Bid -
               stopLevel;


            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
         }


         bool modified =
            OrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrLimeGreen
            );


         if(modified)
         {
            Print(
               "PROFIT LADDER BUY | ",
               multiplier,
               "X | Current Profit: $",
               DoubleToString(
                  currentProfit,
                  2
               ),
               " | Locked: $",
               DoubleToString(
                  lockedProfit,
                  2
               ),
               " | SL: ",
               DoubleToString(
                  newStopLoss,
                  Digits
               )
            );
         }
         else
         {
            Print(
               "BUY Profit Ladder OrderModify failed. Error: ",
               GetLastError()
            );
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


         // Never move SL backwards

         if(
            OrderStopLoss() > 0 &&
            newStopLoss >=
            OrderStopLoss()
         )
         {
            continue;
         }


         double stopLevel =
            MarketInfo(
               Symbol(),
               MODE_STOPLEVEL
            )
            *
            Point;


         if(
            newStopLoss -
            Ask
            <
            stopLevel
         )
         {
            newStopLoss =
               Ask +
               stopLevel;


            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
         }


         bool modified =
            OrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrTomato
            );


         if(modified)
         {
            Print(
               "PROFIT LADDER SELL | ",
               multiplier,
               "X | Current Profit: $",
               DoubleToString(
                  currentProfit,
                  2
               ),
               " | Locked: $",
               DoubleToString(
                  lockedProfit,
                  2
               ),
               " | SL: ",
               DoubleToString(
                  newStopLoss,
                  Digits
               )
            );
         }
         else
         {
            Print(
               "SELL Profit Ladder OrderModify failed. Error: ",
               GetLastError()
            );
         }
      }
   }
}


//+------------------------------------------------------------------+
//| TIMEFRAME STRING                                                  |
//+------------------------------------------------------------------+

string TimeframeToString(
   int timeframe
)
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
//| DELETE EA OBJECTS                                                 |
//+------------------------------------------------------------------+

void DeleteOurObjects()
{
   int total =
      ObjectsTotal(
         0,
         -1,
         -1
      );


   for(
      int i = total - 1;
      i >= 0;
      i--
   )
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
//| DELETE DASHBOARD OBJECTS                                          |
//+------------------------------------------------------------------+

void DeleteDashboardObjects()
{
   int total =
      ObjectsTotal(
         0,
         -1,
         -1
      );


   for(
      int i = total - 1;
      i >= 0;
      i--
   )
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