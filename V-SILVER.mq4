//+------------------------------------------------------------------+
//| Momentum Candle EA                                               |
//+------------------------------------------------------------------+
#property strict

input int MomentumCandles = 2;

input double FixedLot = 0.01;

input double StopLossMoney = 20;
input double TakeProfitMoney = 2;

input int MaxLiveTrades = 5;

input int MinTradeIntervalSeconds = 60;

input double MaxSpread = 60;

input int MagicNumber = 555;

datetime LastTradeTime = 0;

//------------------------------------------------------------

bool SpreadOK()
{
   double spread=(Ask-Bid)/Point;
   return spread <= MaxSpread;
}

//------------------------------------------------------------

bool BullishMomentum()
{
   for(int i=1;i<=MomentumCandles;i++)
   {
      if(Close[i] <= Open[i])
         return false;
   }
   return true;
}

//------------------------------------------------------------

bool BearishMomentum()
{
   for(int i=1;i<=MomentumCandles;i++)
   {
      if(Close[i] >= Open[i])
         return false;
   }
   return true;
}

//------------------------------------------------------------

int CountTrades()
{
   int count=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         count++;
   }

   return count;
}

//------------------------------------------------------------

double TradeProfit(int index)
{
   if(!OrderSelect(index,SELECT_BY_POS,MODE_TRADES))
      return 0;

   return OrderProfit()+OrderSwap()+OrderCommission();
}

//------------------------------------------------------------

void OpenBuy()
{
   RefreshRates();

   if(OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,0,0,"BUY",MagicNumber,0,clrGreen)>0)
      LastTradeTime = TimeCurrent();
}

//------------------------------------------------------------

void OpenSell()
{
   RefreshRates();

   if(OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,0,0,"SELL",MagicNumber,0,clrRed)>0)
      LastTradeTime = TimeCurrent();
}

//------------------------------------------------------------

void ManageTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol())
         continue;

      double profit = TradeProfit(i);

      if(profit >= TakeProfitMoney)
      {
         int type = OrderType();

         if(type==OP_BUY)
         {
            OrderClose(OrderTicket(),OrderLots(),Bid,10);

            if(CountTrades() < MaxLiveTrades)
               OpenBuy();
         }

         if(type==OP_SELL)
         {
            OrderClose(OrderTicket(),OrderLots(),Ask,10);

            if(CountTrades() < MaxLiveTrades)
               OpenSell();
         }

         return;
      }

      if(profit <= -StopLossMoney)
      {
         if(OrderType()==OP_BUY)
            OrderClose(OrderTicket(),OrderLots(),Bid,10);

         if(OrderType()==OP_SELL)
            OrderClose(OrderTicket(),OrderLots(),Ask,10);

         return;
      }
   }
}

//------------------------------------------------------------

void ShowStatus()
{
   Comment(
   "MOMENTUM EA\n",
   "----------------------\n",
   "MomentumCandles: ",MomentumCandles,"\n",
   "ActiveTrades: ",CountTrades(),"\n",
   "BullishMomentum: ",BullishMomentum(),"\n",
   "BearishMomentum: ",BearishMomentum()
   );
}

//------------------------------------------------------------

void OnTick()
{
   ManageTrades();

   if(!SpreadOK()) return;

   if(TimeCurrent() - LastTradeTime < MinTradeIntervalSeconds)
      return;

   if(CountTrades() >= MaxLiveTrades)
   {
      ShowStatus();
      return;
   }

   if(BullishMomentum())
   {
      OpenBuy();
      return;
   }

   if(BearishMomentum())
   {
      OpenSell();
      return;
   }

   ShowStatus();
}