//+------------------------------------------------------------------+
//| Momentum Candle EA                                               |
//+------------------------------------------------------------------+
#property strict

input int MomentumCandles = 2;

input double FixedLot = 0.01;

input double StopLossMoney = 10;
input double TakeProfitMoney = 3;

input int MaxBuyTrades = 5;
input int MaxSellTrades = 5;

input int MinTradeIntervalSeconds = 60*3;

input double MaxSpread = 60;

input int MagicNumber = 555;

datetime LastTradeTime = 0;
datetime LastBarTime = 0;

//------------------------------------------------------------

bool SpreadOK()
{
   double spread=(Ask-Bid)/Point;
   return spread <= MaxSpread;
}

//------------------------------------------------------------

bool TradeIntervalOK()
{
   return (TimeCurrent() - LastTradeTime >= MinTradeIntervalSeconds);
}

//------------------------------------------------------------

bool NewBar()
{
   if(Time[0] != LastBarTime)
   {
      LastBarTime = Time[0];
      return true;
   }
   return false;
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

int CountBuyTrades()
{
   int count=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()==MagicNumber &&
         OrderSymbol()==Symbol() &&
         OrderType()==OP_BUY)
         count++;
   }

   return count;
}

//------------------------------------------------------------

int CountSellTrades()
{
   int count=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()==MagicNumber &&
         OrderSymbol()==Symbol() &&
         OrderType()==OP_SELL)
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
   if(!TradeIntervalOK()) return;

   if(CountBuyTrades() >= MaxBuyTrades) return;

   RefreshRates();

   if(OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,0,0,"BUY",MagicNumber,0,clrGreen)>0)
      LastTradeTime = TimeCurrent();
}

//------------------------------------------------------------

void OpenSell()
{
   if(!TradeIntervalOK()) return;

   if(CountSellTrades() >= MaxSellTrades) return;

   RefreshRates();

   if(OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,0,0,"SELL",MagicNumber,0,clrRed)>0)
      LastTradeTime = TimeCurrent();
}

//------------------------------------------------------------

void ManageTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol())
         continue;

      double profit = TradeProfit(i);

      if(profit >= TakeProfitMoney)
      {
         int type = OrderType();

         if(type==OP_BUY)
         {
            OrderClose(OrderTicket(),OrderLots(),Bid,10);
            OpenBuy();
         }

         if(type==OP_SELL)
         {
            OrderClose(OrderTicket(),OrderLots(),Ask,10);
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
   "BUY Trades: ",CountBuyTrades(),"\n",
   "SELL Trades: ",CountSellTrades(),"\n",
   "SecondsSinceLastTrade: ",TimeCurrent()-LastTradeTime,"\n",
   "BullishMomentum: ",BullishMomentum(),"\n",
   "BearishMomentum: ",BearishMomentum()
   );
}

//------------------------------------------------------------

void OnTick()
{
   ManageTrades();

   if(!SpreadOK()) return;

   if(NewBar())
   {
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
   }

   ShowStatus();
}