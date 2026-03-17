//+------------------------------------------------------------------+
//| AI Smart Momentum EA - FINAL STABLE VERSION                      |
//+------------------------------------------------------------------+
#property strict

/*
=====================================================================
🚀 FEATURES
=====================================================================
✔ Momentum + Trend + AI scoring
✔ Spread + ATR filter
✔ Time interval control
✔ Distance filter (anti-cluster)
✔ Basket TP (dynamic + FIXED $5)
✔ Recovery exit (- → +)
✔ Peak trailing exit
✔ Stop loss
✔ Reset system
✔ UI panel
✔ ✅ FIXED array crash (safe indexing)
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

input int ATRPeriod = 14;
input double ATRMultiplier = 1.5;
input double MinATR = 0.03;

input double MaxSpread = 60;

input int ScoreThreshold = 5;

input double DailyTargetProfit = 3.0;
input double FixedBasketTP = 5.0;

input bool ResetStats = true;

input double TrailStartProfit = 2.0;
input double TrailDrop = 1.0;

input int MagicNumber = 555;

//---------------- GLOBALS ----------------//

datetime LastTradeTime = 0;
datetime LastBarTime = 0;

double ManualStartProfit = 0;
bool ResetDone = false;

// SAFE ARRAYS (by index, not ticket)
double PeakProfit[100];
bool WasNegative[100];

//------------------------------------------------------------
int OnInit()
{
   ManualStartProfit = TodayProfitRaw();
   return(INIT_SUCCEEDED);
}

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
      return true;
   }
   return false;
}

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

//------------------------------------------------------------
bool IsFarFromTrades(double price)
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol())
         continue;

      if(MathAbs(price - OrderOpenPrice())/Point < MinDistancePoints)
         return false;
   }
   return true;
}

//------------------------------------------------------------
int CountBuyTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber && OrderType()==OP_BUY)
            c++;
   return c;
}

int CountSellTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber && OrderType()==OP_SELL)
            c++;
   return c;
}

//------------------------------------------------------------
double TradeProfit(int i)
{
   if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) return 0;
   return OrderProfit()+OrderSwap()+OrderCommission();
}

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
void CloseTrade(int ticket)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return;

   if(OrderType()==OP_BUY)
      OrderClose(ticket,OrderLots(),Bid,10);

   if(OrderType()==OP_SELL)
      OrderClose(ticket,OrderLots(),Ask,10);
}

void CloseAllTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         if(OrderMagicNumber()==MagicNumber)
            CloseTrade(OrderTicket());
}

//------------------------------------------------------------
double TodayProfitRaw()
{
   double t=0;
   datetime d=iTime(NULL,PERIOD_D1,0);

   for(int i=0;i<OrdersHistoryTotal();i++)
      if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         if(OrderMagicNumber()==MagicNumber)
            if(OrderCloseTime()>=d)
               t+=OrderProfit()+OrderSwap()+OrderCommission();

   return t;
}

double TodayProfit()
{
   return TodayProfitRaw()-ManualStartProfit;
}

//------------------------------------------------------------
double GetDynamicTP()
{
   double atr=iATR(NULL,0,ATRPeriod,1);
   double tp=atr*ATRMultiplier*50;

   if(tp<2) tp=2;
   if(tp>10) tp=10;

   return tp;
}

double GetSmartBasketTP()
{
   double today=TodayProfit();
   double loss=(today<0)?MathAbs(today):0;

   return loss+DailyTargetProfit+GetDynamicTP();
}

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
void OpenBuy()
{
   if(!TradeIntervalOK() || CountBuyTrades()>=MaxBuyTrades) return;
   if(!IsFarFromTrades(Ask)) return;

   if(OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,0,0,"BUY",MagicNumber,0,clrGreen)>0)
      LastTradeTime=TimeCurrent();
}

void OpenSell()
{
   if(!TradeIntervalOK() || CountSellTrades()>=MaxSellTrades) return;
   if(!IsFarFromTrades(Bid)) return;

   if(OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,0,0,"SELL",MagicNumber,0,clrRed)>0)
      LastTradeTime=TimeCurrent();
}

//------------------------------------------------------------
void ManageTrades()
{
   double total = TotalBasketProfit();

   if(total >= FixedBasketTP)
   {
      CloseAllTrades();
      return;
   }

   if(total >= GetSmartBasketTP())
   {
      CloseAllTrades();
      return;
   }

   int idx=0;

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()!=MagicNumber) continue;

      double profit=TradeProfit(i);

      if(profit<0) WasNegative[idx]=true;
      if(profit>PeakProfit[idx]) PeakProfit[idx]=profit;

      if(WasNegative[idx] && profit>0)
      {
         CloseTrade(OrderTicket());
         return;
      }

      if(PeakProfit[idx]>=TrailStartProfit &&
         (PeakProfit[idx]-profit)>=TrailDrop)
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
void OnTick()
{
   if(ResetStats && !ResetDone)
   {
      ManualStartProfit=TodayProfitRaw();
      ResetDone=true;
   }

   if(!ResetStats) ResetDone=false;

   ManageTrades();

   if(!SpreadOK() || !VolatilityOK() || !NewBar() || !TradeIntervalOK())
      return;

   int buy=GetBuyScore();
   int sell=GetSellScore();

   if(buy>=ScoreThreshold && buy>sell)
      OpenBuy();
   else if(sell>=ScoreThreshold && sell>buy)
      OpenSell();
}