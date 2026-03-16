//+------------------------------------------------------------------+
//| XAUUSD Gold Price Action EA                                      |
//+------------------------------------------------------------------+
#property strict

input double FixedLot = 0.01;
input double TakeProfitDollar = 50.0;
input int FixedStoplossPoint = 0;
input bool TrailingStop = true;
input int TrailingPoints = 300;

input double MinDistance = 50;
input int MaxTrade = 1;

input int MAGIC_NUMBER = 12345;

input int EMA_Period = 200;
input int ATR_Period = 14;
input double ATR_Filter = 0.3;


//+------------------------------------------------------------------+
bool AllowSymbol()
{
   if(Symbol()=="XAUUSD" || Symbol()=="XAUUSDm" || Symbol()=="XAUUSD.")
      return true;

   return false;
}

//+------------------------------------------------------------------+
int CountTrades()
{
   int total=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==MAGIC_NUMBER && OrderSymbol()==Symbol())
         total++;
      }
   }

   return total;
}

//+------------------------------------------------------------------+
bool DistanceOK()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==MAGIC_NUMBER)
         {
            if(MathAbs(OrderOpenPrice()-Bid) < MinDistance*Point)
               return false;
         }
      }
   }

   return true;
}

//+------------------------------------------------------------------+
bool BullishEngulfing()
{
   if(Close[1] > Open[1] &&
      Close[2] < Open[2] &&
      Close[1] > Open[2] &&
      Open[1] < Close[2])
      return true;

   return false;
}

//+------------------------------------------------------------------+
bool BearishEngulfing()
{
   if(Close[1] < Open[1] &&
      Close[2] > Open[2] &&
      Close[1] < Open[2] &&
      Open[1] > Close[2])
      return true;

   return false;
}

//+------------------------------------------------------------------+
double GetTPPrice(int type,double lot)
{
   double tickvalue = MarketInfo(Symbol(),MODE_TICKVALUE);
   double tp_points = (TakeProfitDollar/(tickvalue*lot))*Point;

   if(type==OP_BUY)
      return Ask + tp_points;

   if(type==OP_SELL)
      return Bid - tp_points;

   return 0;
}

//+------------------------------------------------------------------+
void ManageTrailing()
{
   if(!TrailingStop) return;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()!=MAGIC_NUMBER) continue;

         if(OrderType()==OP_BUY)
         {
            double newSL = Bid - TrailingPoints*Point;

            if(newSL > OrderStopLoss())
               OrderModify(OrderTicket(),OrderOpenPrice(),newSL,OrderTakeProfit(),0);
         }

         if(OrderType()==OP_SELL)
         {
            double newSL = Ask + TrailingPoints*Point;

            if(newSL < OrderStopLoss() || OrderStopLoss()==0)
               OrderModify(OrderTicket(),OrderOpenPrice(),newSL,OrderTakeProfit(),0);
         }
      }
   }
}

//+------------------------------------------------------------------+
void OnTick()
{

   if(!AllowSymbol()) return;

   ManageTrailing();

   if(MaxTrade>0 && CountTrades()>=MaxTrade)
      return;

   if(!DistanceOK())
      return;

   double ema = iMA(Symbol(),0,EMA_Period,0,MODE_EMA,PRICE_CLOSE,1);
   double atr = iATR(Symbol(),0,ATR_Period,1);

   if(atr < ATR_Filter)
      return;

   // BUY
   if(BullishEngulfing() && Close[1] > ema)
   {
      double sl=0;

      if(FixedStoplossPoint>0)
         sl = Ask - FixedStoplossPoint*Point;

      double tp = GetTPPrice(OP_BUY,FixedLot);

      OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,sl,tp,"Gold Buy",MAGIC_NUMBER,0,clrBlue);
   }

   // SELL
   if(BearishEngulfing() && Close[1] < ema)
   {
      double sl=0;

      if(FixedStoplossPoint>0)
         sl = Bid + FixedStoplossPoint*Point;

      double tp = GetTPPrice(OP_SELL,FixedLot);

      OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,sl,tp,"Gold Sell",MAGIC_NUMBER,0,clrRed);
   }
}