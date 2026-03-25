//+------------------------------------------------------------------+
//| Adaptive Universal Trader EA                                     |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input double MaxDailyLoss = 10;
input int BaseCooldown = 300;
input int MaxSpread = 80;
input int MagicNumber = 9002;

datetime LastTradeTime=0;
datetime DayStart=0;

//------------------------------------------------------------

int CountOrders()
{
   int total=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderSymbol()==Symbol())
            total++;
      }
   }

   return total;
}

//------------------------------------------------------------

double DailyLoss()
{
   double loss=0;

   for(int i=0;i<OrdersHistoryTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
      {
         if(OrderCloseTime()>DayStart)
         {
            double p=OrderProfit()+OrderSwap()+OrderCommission();

            if(p<0)
               loss+=MathAbs(p);
         }
      }
   }

   return loss;
}

//------------------------------------------------------------

bool SpreadOK()
{
   double spread=(Ask-Bid)/Point;

   if(spread>MaxSpread)
      return false;

   return true;
}

//------------------------------------------------------------

bool NewsSpike()
{
   double atr=iATR(NULL,0,14,0);
   double candle=MathAbs(Close[0]-Open[0]);

   if(candle>atr*2)
      return true;

   return false;
}

//------------------------------------------------------------

bool MomentumUp()
{
   return Close[0]>Close[1] && Close[1]>Close[2];
}

bool MomentumDown()
{
   return Close[0]<Close[1] && Close[1]<Close[2];
}

//------------------------------------------------------------

bool VolumeStrong()
{
   return Volume[0]>Volume[1];
}

//------------------------------------------------------------

double AverageATR()
{
   double avg=0;

   for(int i=1;i<=20;i++)
      avg+=iATR(NULL,0,14,i);

   return avg/20;
}

//------------------------------------------------------------

bool VolatilityOK()
{
   double atr=iATR(NULL,0,14,0);
   double avg=AverageATR();

   if(atr>avg)
      return true;

   return false;
}

//------------------------------------------------------------

int DynamicCooldown()
{
   double atr=iATR(NULL,0,14,0);
   double avg=AverageATR();

   if(atr>avg*1.5)
      return BaseCooldown/2;

   if(atr<avg)
      return BaseCooldown*2;

   return BaseCooldown;
}

//------------------------------------------------------------

void OpenBuy(double atr)
{
   double price=Ask;

   double sl=price-(atr*1.5);
   double tp=price+(atr*2.5);

   int ticket=OrderSend(Symbol(),OP_BUY,LotSize,price,3,0,0,"AdaptiveBuy",MagicNumber,0,clrGreen);

   if(ticket>0)
   {
      OrderSelect(ticket,SELECT_BY_TICKET);
      OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
   }
}

//------------------------------------------------------------

void OpenSell(double atr)
{
   double price=Bid;

   double sl=price+(atr*1.5);
   double tp=price-(atr*2.5);

   int ticket=OrderSend(Symbol(),OP_SELL,LotSize,price,3,0,0,"AdaptiveSell",MagicNumber,0,clrRed);

   if(ticket>0)
   {
      OrderSelect(ticket,SELECT_BY_TICKET);
      OrderModify(ticket,OrderOpenPrice(),sl,tp,0);
   }
}

//------------------------------------------------------------

void OnTick()
{

   if(TimeDay(TimeCurrent())!=TimeDay(DayStart))
      DayStart=TimeCurrent();

   if(DailyLoss()>=MaxDailyLoss)
      return;

   if(CountOrders()>0)
      return;

   int cooldown=DynamicCooldown();

   if(TimeCurrent()-LastTradeTime < cooldown)
      return;

   if(!SpreadOK())
      return;

   if(NewsSpike())
      return;

   if(!VolumeStrong())
      return;

   if(!VolatilityOK())
      return;

   double atr=iATR(NULL,0,14,0);

   if(MomentumUp())
   {
      OpenBuy(atr);
      LastTradeTime=TimeCurrent();
      return;
   }

   if(MomentumDown())
   {
      OpenSell(atr);
      LastTradeTime=TimeCurrent();
      return;
   }

}