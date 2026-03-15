//+------------------------------------------------------------------+
//|                ETH Momentum Pullback EA                          |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input double StopLossPercent = 0.5;   // 0.5%
input double TakeProfitPercent = 0.9; // 0.9%
input int Slippage = 3;
input int MagicNumber = 8888;

//------------------------------------------------------------

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

//------------------------------------------------------------

void OpenBuy()
{
   double price = Ask;

   double sl = price - (price * StopLossPercent / 100);
   double tp = price + (price * TakeProfitPercent / 100);

   int ticket = OrderSend(Symbol(),OP_BUY,LotSize,price,Slippage,0,0,
                          "ETH Pullback Buy",MagicNumber,0,clrGreen);

   if(ticket > 0)
   {
      if(OrderSelect(ticket,SELECT_BY_TICKET))
         OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
   }
   else
      Print("Buy Error:",GetLastError());
}

//------------------------------------------------------------

void OpenSell()
{
   double price = Bid;

   double sl = price + (price * StopLossPercent / 100);
   double tp = price - (price * TakeProfitPercent / 100);

   int ticket = OrderSend(Symbol(),OP_SELL,LotSize,price,Slippage,0,0,
                          "ETH Pullback Sell",MagicNumber,0,clrRed);

   if(ticket > 0)
   {
      if(OrderSelect(ticket,SELECT_BY_TICKET))
         OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
   }
   else
      Print("Sell Error:",GetLastError());
}

//------------------------------------------------------------

void OnTick()
{

   if(CountOrders()>0)
      return;

   double ema50  = iMA(NULL,0,50,0,MODE_EMA,PRICE_CLOSE,0);
   double ema200 = iMA(NULL,0,200,0,MODE_EMA,PRICE_CLOSE,0);
   double rsi    = iRSI(NULL,0,14,PRICE_CLOSE,0);

   // BUY condition (trend up + pullback)
   if(Bid > ema200 && ema50 > ema200 && rsi < 40)
   {
      OpenBuy();
      return;
   }

   // SELL condition (trend down + pullback)
   if(Bid < ema200 && ema50 < ema200 && rsi > 60)
   {
      OpenSell();
      return;
   }

}