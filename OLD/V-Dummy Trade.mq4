//+------------------------------------------------------------------+
//| BTC Micro Profit Scalper                                         |
//+------------------------------------------------------------------+
#property strict

input double LotSize = 0.01;

input double MicroTakeProfit = 0.5;   // small profit target ($)
input double MicroStopLoss   = 5;     // protection ($)

input int TickMomentum = 5;           // number of ticks to detect direction
input int MagicNumber = 9090;

double lastPrices[10];
int tickIndex=0;

//-------------------------------------------------------------

double MoneyToPrice(double money)
{
   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(),MODE_TICKSIZE);

   double move = (money / (tickValue * LotSize)) * tickSize;

   return move;
}

//-------------------------------------------------------------

int CountTrades()
{
   int total=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         total++;
   }

   return total;
}

//-------------------------------------------------------------

void OpenBuy()
{
   double sl = Ask - MoneyToPrice(MicroStopLoss);
   double tp = Ask + MoneyToPrice(MicroTakeProfit);

   OrderSend(Symbol(),OP_BUY,LotSize,Ask,10,sl,tp,"MicroBuy",MagicNumber,0,clrGreen);
}

//-------------------------------------------------------------

void OpenSell()
{
   double sl = Bid + MoneyToPrice(MicroStopLoss);
   double tp = Bid - MoneyToPrice(MicroTakeProfit);

   OrderSend(Symbol(),OP_SELL,LotSize,Bid,10,sl,tp,"MicroSell",MagicNumber,0,clrRed);
}

//-------------------------------------------------------------

int DetectMomentum()
{
   int up=0;
   int down=0;

   for(int i=1;i<TickMomentum;i++)
   {
      if(lastPrices[i] > lastPrices[i-1])
         up++;

      if(lastPrices[i] < lastPrices[i-1])
         down++;
   }

   if(up > down)
      return 1;

   if(down > up)
      return -1;

   return 0;
}

//-------------------------------------------------------------

void StorePrice()
{
   for(int i=TickMomentum-1;i>0;i--)
      lastPrices[i]=lastPrices[i-1];

   lastPrices[0]=Bid;
}

//-------------------------------------------------------------

void ShowPanel()
{
   Comment(
   "BTC MICRO PROFIT SCALPER\n",
   "----------------------------\n",
   "Symbol: ",Symbol(),"\n",
   "Lot: ",LotSize,"\n",
   "TakeProfit($): ",MicroTakeProfit,"\n",
   "StopLoss($): ",MicroStopLoss,"\n",
   "MomentumTicks: ",TickMomentum,"\n",
   "Active Trades: ",CountTrades(),"\n",
   "Bid: ",Bid
   );
}

//-------------------------------------------------------------

void OnTick()
{
   if(Symbol()!="BTCUSDm")
   {
      Comment("Attach EA only to BTCUSDm");
      return;
   }

   StorePrice();

   if(CountTrades()==0)
   {
      int dir = DetectMomentum();

      if(dir==1)
         OpenBuy();

      if(dir==-1)
         OpenSell();
   }

   ShowPanel();
}