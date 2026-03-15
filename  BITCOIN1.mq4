#property strict

input double LotSize = 0.01;
input int StopLoss = 6000;
input int TakeProfit = 9000;
input int MagicNumber = 2026;

int CountOrders()
{
   int total=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
            total++;
      }
   }

   return total;
}

void OpenBuy()
{
   int ticket = OrderSend(Symbol(),OP_BUY,LotSize,Ask,3,0,0,"PullbackBuy",MagicNumber,0,clrGreen);

   if(ticket>0)
   {
      if(OrderSelect(ticket,SELECT_BY_TICKET))
      {
         double sl = OrderOpenPrice() - StopLoss*Point;
         double tp = OrderOpenPrice() + TakeProfit*Point;

         OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
      }
   }
}

void OpenSell()
{
   int ticket = OrderSend(Symbol(),OP_SELL,LotSize,Bid,3,0,0,"PullbackSell",MagicNumber,0,clrRed);

   if(ticket>0)
   {
      if(OrderSelect(ticket,SELECT_BY_TICKET))
      {
         double sl = OrderOpenPrice() + StopLoss*Point;
         double tp = OrderOpenPrice() - TakeProfit*Point;

         OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
      }
   }
}

void OnTick()
{
   if(CountOrders()>0)
      return;

   double ema200 = iMA(NULL,0,200,0,MODE_EMA,PRICE_CLOSE,0);
   double rsi = iRSI(NULL,0,14,PRICE_CLOSE,0);

   if(Bid > ema200 && rsi < 40)
      OpenBuy();

   if(Bid < ema200 && rsi > 60)
      OpenSell();
}