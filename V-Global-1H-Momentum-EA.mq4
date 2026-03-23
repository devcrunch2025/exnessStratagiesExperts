//+------------------------------------------------------------------+
//| Global 1H Momentum EA for All Symbols                           |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window

input double FixedLot = 0.01;
input int    Slippage = 10;
input int    MagicNumber = 260318;
input double TakeProfitMoney = 5.0;
input double StopLossMoney   = 20.0;

double TodayProfit = 0;
double TodayLoss = 0;
datetime lastTradeTime = 0;
int lastClosedTicket = -1;
datetime lastSLTime = 0;

void OnTick()
{
   int minWait = 60*5; //5 minutes
   string sym = Symbol();
   double price = Bid;
   datetime compareTime = TimeCurrent() - 3600; // 1 hour before now
   int compareBar = iBarShift(sym, PERIOD_M1, compareTime, true);
   double comparePrice = iClose(sym, PERIOD_M1, compareBar);
   if(comparePrice == 0) return;

   // Calculate percent change from 1 hour ago
   double pct = (price - comparePrice) / comparePrice * 100.0;

   // Only one trade per symbol at a time
   int myTrades = 0;
   int myTicket = -1;
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() == sym && OrderMagicNumber() == MagicNumber)
      {
         myTrades++;
         myTicket = OrderTicket();
      }
   }

   // Detect manual close: check for new closed order
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != sym || OrderMagicNumber() != MagicNumber) continue;
      int ticket = OrderTicket();
      if(ticket != lastClosedTicket && OrderCloseTime() > 0 && OrderCloseTime() >= TimeCurrent() - 60)
      {
         lastClosedTicket = ticket;
         // Manual close detected, trigger next process here
         Print("Order manually closed: ", ticket, ", profit=", OrderProfit());
         // Place your next process logic here
      }
      break;
   }

   // Check for close by profit/loss
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != sym || OrderMagicNumber() != MagicNumber) continue;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit >= TakeProfitMoney)
      {
         OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY ? Bid : Ask), Slippage, clrViolet);
         TodayProfit += profit;
      }
      else if(profit <= -StopLossMoney)
      {
         OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY ? Bid : Ask), Slippage, clrRed);
         TodayLoss += -profit;
         lastSLTime = TimeCurrent(); // Record time of SL hit
      }
   }

   // Only open new trade if none open for this symbol and time since last trade/SL is sufficient
   if(lastSLTime > 0 && (TimeCurrent() - lastSLTime < 3600))
      minWait = 60*30; // 60 minutes if last trade was SL

   if(myTrades == 0 && (TimeCurrent() - lastTradeTime >= minWait))
   {
      if(pct > 1.0)
      {
         OrderSend(sym, OP_BUY, FixedLot, Ask, Slippage, 0, 0, "BUY", MagicNumber, 0, clrGreen);
         lastTradeTime = TimeCurrent();
      }
      else if(pct < -1.0)
      {
         OrderSend(sym, OP_SELL, FixedLot, Bid, Slippage, 0, 0, "SELL", MagicNumber, 0, clrRed);
         lastTradeTime = TimeCurrent();
      }
   }
   // Display status on chart
   string msg = StringFormat("Status: %s | Price: %.3f | 1H Ago: %.3f\nMomentum: %s\nTP: $%.2f | SL: $%.2f\nToday Profit: $%.2f | Today Loss: $%.2f",
      sym, price, comparePrice,
      (pct > 1.0 ? "Bullish (Buy Signal)" : (pct < -1.0 ? "Bearish (Sell Signal)" : "Unclear")),
      TakeProfitMoney, StopLossMoney,
      TodayProfit, TodayLoss);
   Comment(msg);
   DrawH1ComparisonLine();
}

void DrawH1ComparisonLine()
{
   datetime compareTime = TimeCurrent() - 3600; // 1 hour before now
   string vlineName = "H1CompareLine";
   if(ObjectFind(0, vlineName) < 0)
   {
      ObjectCreate(0, vlineName, OBJ_VLINE, 0, compareTime, 0);
      ObjectSetInteger(0, vlineName, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, vlineName, OBJPROP_WIDTH, 2);
   }
   else
   {
      ObjectMove(0, vlineName, 0, compareTime, 0);
   }
}

void DisplayStatus()
{
   string sym = Symbol();
   double price = Bid;
   double h1close = iClose(sym, PERIOD_H1, 1);
   double pct = (price - h1close) / h1close * 100.0;
   string momentum = "Unclear";
   color momentumColor = clrWhite;
   if(pct > 1.0) { momentum = "Bullish (Buy Signal)"; momentumColor = clrLime; }
   else if(pct < -1.0) { momentum = "Bearish (Sell Signal)"; momentumColor = clrRed; }
   string msg = StringFormat(
      "Status: %s | Price: %.3f | 1H Close: %.3f\n",
      sym, price, h1close
   );
   Comment(msg);
   // Draw momentum as a label with color
   string labelName = "MomentumLabel";
   if(ObjectFind(0, labelName) < 0)
   {
      ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName, OBJPROP_CORNER, 0);
      ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 40);
   }
   ObjectSetString(0, labelName, OBJPROP_TEXT, "Momentum: " + momentum);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, momentumColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);

   // Show profit/loss and SL/TP as before
   string msg2 = StringFormat("TP: $%.2f | SL: $%.2f\nToday Profit: $%.2f | Today Loss: $%.2f",
      TakeProfitMoney, StopLossMoney, TodayProfit, TodayLoss);
   string labelName2 = "PLLabel";
   if(ObjectFind(0, labelName2) < 0)
   {
      ObjectCreate(0, labelName2, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, labelName2, OBJPROP_CORNER, 0);
      ObjectSetInteger(0, labelName2, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, labelName2, OBJPROP_YDISTANCE, 60);
   }
   ObjectSetString(0, labelName2, OBJPROP_TEXT, msg2);
   ObjectSetInteger(0, labelName2, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName2, OBJPROP_FONTSIZE, 10);
}

int OnInit()
{
   TodayProfit = 0;
   TodayLoss = 0;
   return INIT_SUCCEEDED;
}
