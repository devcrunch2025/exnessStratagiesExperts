//+------------------------------------------------------------------+
//| Micro Profit Smart Scalper EA v2                                 |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;
input double ProfitTarget = 0.5;
input double DummyProfitTrigger = 30;

input double DailyProfitTarget = 10;
input double DailyLossLimit = -3;

input int SpreadLimit = 80;

double dummyBuyPrice;
double dummySellPrice;

bool dummyActive=false;

//+------------------------------------------------------------------+
double GetTodayProfit()
{
   double profit=0;

   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
      {
         if(TimeDay(OrderCloseTime())==TimeDay(TimeCurrent()))
            profit+=OrderProfit();
      }
   }

   return profit;
}

//+------------------------------------------------------------------+
void CloseProfitTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderSymbol()!=Symbol()) continue;

         if(OrderProfit()>=ProfitTarget)
         {
            if(OrderType()==OP_BUY)
               OrderClose(OrderTicket(),OrderLots(),Bid,5);

            if(OrderType()==OP_SELL)
               OrderClose(OrderTicket(),OrderLots(),Ask,5);
         }
      }
   }
}

//+------------------------------------------------------------------+
void CreateDummyTrades()
{
   dummyBuyPrice = Ask;
   dummySellPrice = Bid;
   dummyActive = true;
}

//+------------------------------------------------------------------+
void CheckDummy()
{
   if(!dummyActive) return;

   double buyMove=(Bid-dummyBuyPrice)/Point;
   double sellMove=(dummySellPrice-Ask)/Point;

   if(buyMove > DummyProfitTrigger)
   {
      OrderSend(Symbol(),OP_BUY,LotSize,Ask,5,0,0,"RealBuy",0,0,clrBlue);
      dummyActive=false;
   }

   if(sellMove > DummyProfitTrigger)
   {
      OrderSend(Symbol(),OP_SELL,LotSize,Bid,5,0,0,"RealSell",0,0,clrRed);
      dummyActive=false;
   }
}

//+------------------------------------------------------------------+
bool MomentumDetected()
{
   double body=MathAbs(Close[1]-Open[1]);

   if(body > 20*Point)
      return true;

   return false;
}

//+------------------------------------------------------------------+
void OnTick()
{

   if(MarketInfo(Symbol(),MODE_SPREAD)>SpreadLimit)
      return;

   double todayProfit = GetTodayProfit();

   if(todayProfit >= DailyProfitTarget) return;
   if(todayProfit <= DailyLossLimit) return;

   CloseProfitTrades();

   if(!dummyActive && MomentumDetected())
      CreateDummyTrades();

   CheckDummy();
}