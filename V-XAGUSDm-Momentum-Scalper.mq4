//+------------------------------------------------------------------+
//| Simple Silver (XAGUSDm) Buy/Sell EA - Single Trade Only        |
//+------------------------------------------------------------------+
#property strict

input string  TradeSymbol = "XAGUSDm";
input double  FixedLot    = 0.01;
input int     Slippage    = 10;
input int     MagicNumber = 260318;
input double TakeProfitMoney = 5.0;
input double StopLossMoney   = 100.0;

// Helper: Check 1-hour momentum (returns 1 for bullish, -1 for bearish, 0 for unclear)
int GetH1Momentum()
{
   double h1ClosePrev = iClose(TradeSymbol, PERIOD_H1, 1);
   double h1OpenPrev  = iOpen(TradeSymbol, PERIOD_H1, 1);
   if(h1ClosePrev > h1OpenPrev + Point*2) return 1; // Bullish
   if(h1ClosePrev < h1OpenPrev - Point*2) return -1; // Bearish
   return 0; // Unclear
}

void OnTick()
{
   if(Symbol() != TradeSymbol) return;

   CheckAndCloseByProfitOrLoss();

   int tradeCount = 0;
   if(tradeCount >= 2) return;

   RefreshRates();

   int h1momentum = GetH1Momentum();
   if(h1momentum == 0) return; // Wait for clear 1H momentum before any new trade

   if(tradeCount == 0)
   {
      if(h1momentum == 1)
      {
         OrderSend(TradeSymbol, OP_BUY, FixedLot, Ask, Slippage, 0, 0, "BUY", MagicNumber, 0, clrGreen);
         return;
      }
      if(h1momentum == -1)
      {
         OrderSend(TradeSymbol, OP_SELL, FixedLot, Bid, Slippage, 0, 0, "SELL", MagicNumber, 0, clrRed);
         return;
      }
   }
   else if(tradeCount == 1)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderMagicNumber() != MagicNumber || OrderSymbol() != TradeSymbol) continue;
         double profit = OrderProfit() + OrderSwap() + OrderCommission();
         int lastType = OrderType();
         if(profit < -20.0)
         {
            if(h1momentum == 0) return; // Wait for clear 1H momentum
            if(lastType == OP_BUY && h1momentum == -1)
               OrderSend(TradeSymbol, OP_SELL, FixedLot, Bid, Slippage, 0, 0, "REV SELL", MagicNumber, 0, clrRed);
            else if(lastType == OP_SELL && h1momentum == 1)
               OrderSend(TradeSymbol, OP_BUY, FixedLot, Ask, Slippage, 0, 0, "REV BUY", MagicNumber, 0, clrGreen);
         }
         break;
      }
   }
}

void CheckAndCloseByProfitOrLoss()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != TradeSymbol) continue;
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit >= TakeProfitMoney)
         OrderClose(OrderTicket(), OrderLots(), (OrderType() == OP_BUY ? Bid : Ask), Slippage, clrViolet);
   }
}

void DisplayStatus()
{
   double h1ClosePrev = iClose(TradeSymbol, PERIOD_H1, 1);
   string msg = StringFormat(
      "Symbol: %s\nBid: %.3f\n1H Close: %.3f\nMomentum: %s\n", 
      TradeSymbol, Bid, h1ClosePrev,
      (GetH1Momentum() == 1 ? "Bullish" : (GetH1Momentum() == -1 ? "Bearish" : "Unclear"))
   );
   int profitCount = 0, lossCount = 0;
   double todayProfit = 0, todayLoss = 0;
   datetime today = DateOfDay(TimeCurrent());
   for(int i = 0; i < OrdersHistoryTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != TradeSymbol) continue;
      if(DateOfDay(OrderCloseTime()) == today)
      {
         double p = OrderProfit() + OrderSwap() + OrderCommission();
         if(p >= 0) { todayProfit += p; profitCount++; }
         else { todayLoss += p; lossCount++; }
      }
   }
   msg += StringFormat("Today Profit: $%.2f (%d)\nToday Loss: $%.2f (%d)", todayProfit, profitCount, todayLoss, lossCount);
   Comment(msg);
}

int DateOfDay(datetime t) { return t - (t % 86400); }