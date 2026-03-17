//+------------------------------------------------------------------+
//| AI Smart Momentum EA - FINAL SAFE MODE + DEBUG                   |
//+------------------------------------------------------------------+
#property strict

/*
=====================================================================
🛡️ SAFE MODE EA (NON-AGGRESSIVE)

✔ Momentum + Trend + Score
✔ Spread + ATR filter
✔ Distance filter (anti-cluster)
✔ Time gap between trades
✔ Basket TP (fixed + dynamic)
✔ Recovery exit (- → +)
✔ Peak trailing exit
✔ Stop loss
✔ Trend strength filter
✔ One trade per candle
✔ Controlled multi-trade (trend aligned only)

DEBUG:
✔ Candle score display
✔ Trend direction
✔ Trend strength
✔ Block reasons

=====================================================================
*/

//---------------- INPUTS ----------------//

input int MomentumCandles = 2;
input double FixedLot = 0.01;
input double StopLossMoney = 30;

input int MaxBuyTrades = 5;
input int MaxSellTrades = 5;

input int MinTradeIntervalSeconds = 60;
input double MinDistancePoints = 200;

input int TrendLookbackMinutes = 60;
input double TrendThreshold = 0.10;
input double MinTrendStrength = 0.20;

input int ATRPeriod = 14;
input double MinATR = 0.03;

input double MaxSpread = 60;

input int ScoreThreshold = 5;

input double FixedBasketTP = 5.0;
input double DailyTargetProfit = 3.0;

input bool ShowDebugSignals = true;

input int MagicNumber = 555;

//---------------- GLOBALS ----------------//

datetime LastTradeTime = 0;
datetime LastBarTime = 0;
bool TradeOpenedThisBar = false;

double PeakProfit[100];
bool WasNegative[100];

//------------------------------------------------------------
// BASIC FILTERS
//------------------------------------------------------------
bool SpreadOK(){ return ((Ask-Bid)/Point)<=MaxSpread; }
bool VolatilityOK(){ return iATR(NULL,0,ATRPeriod,1)>MinATR; }
bool TradeIntervalOK(){ return (TimeCurrent()-LastTradeTime>=MinTradeIntervalSeconds); }

//------------------------------------------------------------
bool NewBar()
{
   if(Time[0]!=LastBarTime)
   {
      LastBarTime=Time[0];
      TradeOpenedThisBar=false;
      return true;
   }
   return false;
}

//------------------------------------------------------------
// MOMENTUM
//------------------------------------------------------------
bool BullishMomentum()
{
   for(int i=1;i<=MomentumCandles;i++)
      if(Close[i]<=Open[i]) return false;
   return true;
}

bool BearishMomentum()
{
   for(int i=1;i<=MomentumCandles;i++)
      if(Close[i]>=Open[i]) return false;
   return true;
}

//------------------------------------------------------------
// TREND
//------------------------------------------------------------
double GetTrendChange()
{
   int shift=iBarShift(NULL,0,TimeCurrent()-TrendLookbackMinutes*60);
   if(shift<0) return 0;
   return (Close[0]-Close[shift]);
}

int GetTrendDirection()
{
   double c=GetTrendChange();
   if(c>TrendThreshold) return OP_BUY;
   if(c<-TrendThreshold) return OP_SELL;
   return -1;
}

double GetTrendStrength()
{
   int shift=iBarShift(NULL,0,TimeCurrent()-TrendLookbackMinutes*60);
   if(shift<0) return 0;
   return MathAbs(Close[0]-Close[shift]);
}

//------------------------------------------------------------
// DISTANCE
//------------------------------------------------------------
bool IsFarFromTrades(double price)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol()) continue;

      if(MathAbs(price-OrderOpenPrice())/Point < MinDistancePoints)
         return false;
   }
   return true;
}

//------------------------------------------------------------
// COUNTS
//------------------------------------------------------------
int CountBuyTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber && OrderType()==OP_BUY) c++;
   return c;
}

int CountSellTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber && OrderType()==OP_SELL) c++;
   return c;
}

//------------------------------------------------------------
// SCORE
//------------------------------------------------------------
int GetBuyScore()
{
   int s=0;
   if(BullishMomentum()) s+=2;
   if(GetTrendDirection()==OP_BUY) s+=3;
   if(VolatilityOK()) s+=1;
   if(SpreadOK()) s+=1;
   return s;
}

int GetSellScore()
{
   int s=0;
   if(BearishMomentum()) s+=2;
   if(GetTrendDirection()==OP_SELL) s+=3;
   if(VolatilityOK()) s+=1;
   if(SpreadOK()) s+=1;
   return s;
}

//------------------------------------------------------------
// PROFIT
//------------------------------------------------------------
double TotalBasketProfit()
{
   double t=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber)
            t+=OrderProfit()+OrderSwap()+OrderCommission();
   return t;
}

//------------------------------------------------------------
// DYNAMIC TP
//------------------------------------------------------------
double GetDynamicTP()
{
   double atr=iATR(NULL,0,ATRPeriod,1);
   double tp=atr*50;

   if(tp<2) tp=2;
   if(tp>10) tp=10;

   return tp;
}

double GetSmartBasketTP()
{
   double loss=0;
   if(TotalBasketProfit()<0)
      loss=MathAbs(TotalBasketProfit());

   return loss + DailyTargetProfit + GetDynamicTP();
}

//------------------------------------------------------------
// CLOSE
//------------------------------------------------------------
void CloseTrade(int ticket)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return;

   if(OrderType()==OP_BUY) OrderClose(ticket,OrderLots(),Bid,10);
   if(OrderType()==OP_SELL) OrderClose(ticket,OrderLots(),Ask,10);
}

void CloseAllTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber)
            CloseTrade(OrderTicket());
}

//------------------------------------------------------------
// MANAGE TRADES
//------------------------------------------------------------
void ManageTrades()
{
   double total=TotalBasketProfit();

   if(total>=FixedBasketTP || total>=GetSmartBasketTP())
   {
      CloseAllTrades();
      return;
   }

   int idx=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;

      double profit=OrderProfit();

      if(profit<0) WasNegative[idx]=true;
      if(profit>PeakProfit[idx]) PeakProfit[idx]=profit;

      if(WasNegative[idx] && profit>0)
      {
         CloseTrade(OrderTicket());
         return;
      }

      if(PeakProfit[idx]>=2 && (PeakProfit[idx]-profit)>=1)
      {
         CloseTrade(OrderTicket());
         return;
      }

      if(profit<=-StopLossMoney)
      {
         CloseTrade(OrderTicket());
         return;
      }

      idx++;
   }
}

//------------------------------------------------------------
// DEBUG DRAW
//------------------------------------------------------------
void DrawDebug(string name, datetime t, double price, string txt, color clr)
{
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_TEXT,0,t,price);

   ObjectSetText(name,txt,8,"Arial",clr);
   ObjectMove(0,name,0,t,price);
}

void AnalyzeCandle()
{
   if(!ShowDebugSignals) return;

   string id=IntegerToString(Time[1]);

   int buy=GetBuyScore();
   int sell=GetSellScore();
   int trend=GetTrendDirection();
   double str=GetTrendStrength();

   string txt="B:"+IntegerToString(buy)+" S:"+IntegerToString(sell);

   if(trend==OP_BUY) txt+=" T:BUY";
   else if(trend==OP_SELL) txt+=" T:SELL";
   else txt+=" T:NONE";

   txt+=" STR:"+DoubleToString(str,2);

   if(!SpreadOK()) txt+=" SPREAD";
   if(!VolatilityOK()) txt+=" ATR";
   if(!TradeIntervalOK()) txt+=" WAIT";
   if(CountBuyTrades()>=MaxBuyTrades) txt+=" MAXB";
   if(CountSellTrades()>=MaxSellTrades) txt+=" MAXS";
   if(!IsFarFromTrades(Ask)) txt+=" DIST";

   color clr=clrSilver;

   if(buy>=ScoreThreshold && buy>sell && trend==OP_BUY)
      clr=clrLime;
   else if(sell>=ScoreThreshold && sell>buy && trend==OP_SELL)
      clr=clrRed;

   DrawDebug("DBG_"+id,Time[1],High[1]+30*Point,txt,clr);
}

//------------------------------------------------------------
// OPEN
//------------------------------------------------------------
void OpenBuy()
{
   if(TradeOpenedThisBar) return;
   if(!TradeIntervalOK() || CountBuyTrades()>=MaxBuyTrades) return;
   if(!IsFarFromTrades(Ask)) return;

   if(OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,0,0,"BUY",MagicNumber,0,clrGreen)>0)
   {
      LastTradeTime=TimeCurrent();
      TradeOpenedThisBar=true;
   }
}

void OpenSell()
{
   if(TradeOpenedThisBar) return;
   if(!TradeIntervalOK() || CountSellTrades()>=MaxSellTrades) return;
   if(!IsFarFromTrades(Bid)) return;

   if(OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,0,0,"SELL",MagicNumber,0,clrRed)>0)
   {
      LastTradeTime=TimeCurrent();
      TradeOpenedThisBar=true;
   }
}

//------------------------------------------------------------
// MAIN
//------------------------------------------------------------
void OnTick()
{
   if(NewBar())
      AnalyzeCandle();

   ManageTrades();

   if(!SpreadOK() || !VolatilityOK() || !TradeIntervalOK())
      return;

   int buy=GetBuyScore();
   int sell=GetSellScore();

   int trend=GetTrendDirection();
   double strength=GetTrendStrength();

   if(buy>=ScoreThreshold && buy>sell && trend==OP_BUY && strength>=MinTrendStrength)
      OpenBuy();

   else if(sell>=ScoreThreshold && sell>buy && trend==OP_SELL && strength>=MinTrendStrength)
      OpenSell();
}