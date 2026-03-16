//+------------------------------------------------------------------+
//| Smart Pullback Momentum EA - Clean Chart Version                 |
//+------------------------------------------------------------------+
#property strict

input double FixedLot = 0.01;

input double TakeProfitMoney = 5;
input double StopLossMoney   = 20;

input int FastEMA = 50;
input int SlowEMA = 200;

input int ATRPeriod = 14;
input double ATRMinimum = 0.03;

input double MaxSpread = 60;
input int MinimumSignal = 50;

input int MagicNumber = 555;

datetime LastTradeBar=0;
string TradePlan="Waiting...";

//------------------------------------------------------------
// Remove any old chart objects from previous versions
//------------------------------------------------------------

void ClearChartLines()
{
   ObjectDelete(0,"FastEMA");
   ObjectDelete(0,"SlowEMA");
   ObjectDelete(0,"BuyZone");
   ObjectDelete(0,"SellZone");
   ObjectDelete(0,"PlannedTrade");
}

//------------------------------------------------------------

int OnInit()
{
   ClearChartLines();
   return(INIT_SUCCEEDED);
}

//------------------------------------------------------------

void OnDeinit(const int reason)
{
   ClearChartLines();
}

//------------------------------------------------------------

bool SpreadOK()
{
   double spread=(Ask-Bid)/Point;
   return spread<=MaxSpread;
}

//------------------------------------------------------------

bool NewBar()
{
   if(Time[0]!=LastTradeBar)
   {
      LastTradeBar=Time[0];
      return true;
   }
   return false;
}

//------------------------------------------------------------

bool UpTrend()
{
   double fast=iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double slow=iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,1);

   return fast>slow;
}

//------------------------------------------------------------

bool DownTrend()
{
   double fast=iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,1);
   double slow=iMA(NULL,0,SlowEMA,0,MODE_EMA,PRICE_CLOSE,1);

   return fast<slow;
}

//------------------------------------------------------------

bool PullbackBuy()
{
   double ema=iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,1);

   if(Close[2] < ema && Close[1] > ema && Close[1] > Open[1])
      return true;

   return false;
}

//------------------------------------------------------------

bool PullbackSell()
{
   double ema=iMA(NULL,0,FastEMA,0,MODE_EMA,PRICE_CLOSE,1);

   if(Close[2] > ema && Close[1] < ema && Close[1] < Open[1])
      return true;

   return false;
}

//------------------------------------------------------------

bool VolatilityOK()
{
   double atr=iATR(NULL,0,ATRPeriod,1);
   return atr>ATRMinimum;
}

//------------------------------------------------------------

int SignalStrength()
{
   int score=0;

   if(UpTrend() || DownTrend())
      score+=40;

   if(PullbackBuy() || PullbackSell())
      score+=40;

   if(VolatilityOK())
      score+=20;

   return score;
}

//------------------------------------------------------------

double TotalProfit()
{
   double p=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         p+=OrderProfit()+OrderSwap()+OrderCommission();
   }

   return p;
}

//------------------------------------------------------------

void DrawArrow(string name,double price,color clr)
{
   ObjectCreate(0,name,OBJ_ARROW,0,Time[0],price);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
}

//------------------------------------------------------------

void OpenBuy()
{
   RefreshRates();

   OrderSend(Symbol(),OP_BUY,FixedLot,Ask,10,0,0,"SmartBuy",MagicNumber,0,clrGreen);

   DrawArrow("BUY_"+Time[0],Low[0],clrGreen);
}

//------------------------------------------------------------

void OpenSell()
{
   RefreshRates();

   OrderSend(Symbol(),OP_SELL,FixedLot,Bid,10,0,0,"SmartSell",MagicNumber,0,clrRed);

   DrawArrow("SELL_"+Time[0],High[0],clrRed);
}

//------------------------------------------------------------

void CloseAll()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol())
         continue;

      if(OrderType()==OP_BUY)
         OrderClose(OrderTicket(),OrderLots(),Bid,10);

      if(OrderType()==OP_SELL)
         OrderClose(OrderTicket(),OrderLots(),Ask,10);
   }
}

//------------------------------------------------------------

int CountTrades()
{
   int c=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         c++;
   }

   return c;
}

//------------------------------------------------------------

void ManageProfit()
{
   double profit=TotalProfit();

   if(profit>=TakeProfitMoney)
      CloseAll();

   if(profit<=-StopLossMoney)
      CloseAll();
}

//------------------------------------------------------------

void ShowStatus()
{
   double spread=(Ask-Bid)/Point;

   Comment(
   "SMART PULLBACK EA\n",
   "-----------------------------\n",
   "Symbol: ",Symbol(),"\n",
   "Spread: ",DoubleToString(spread,1),"\n\n",

   "FixedLot: ",FixedLot,"\n",
   "Trade Plan: ",TradePlan,"\n",
   "Signal Strength: ",SignalStrength(),"%\n\n",

   "UpTrend: ",UpTrend(),"\n",
   "PullbackBuy: ",PullbackBuy(),"\n",
   "PullbackSell: ",PullbackSell(),"\n",
   "ATR OK: ",VolatilityOK(),"\n\n",

   "Trades: ",CountTrades(),"\n",
   "Profit: ",DoubleToString(TotalProfit(),2)
   );
}

//------------------------------------------------------------

void OnTick()
{
   ManageProfit();

   if(!SpreadOK())
   {
      TradePlan="Spread too high";
      ShowStatus();
      return;
   }

   if(!NewBar())
   {
      TradePlan="Waiting new candle";
      ShowStatus();
      return;
   }

   if(CountTrades()>0)
   {
      TradePlan="Trade already open";
      ShowStatus();
      return;
   }

   if(!VolatilityOK())
   {
      TradePlan="Low volatility";
      ShowStatus();
      return;
   }

   int signal=SignalStrength();

   if(signal<MinimumSignal)
   {
      TradePlan="Signal too weak";
      ShowStatus();
      return;
   }

   if(UpTrend() && PullbackBuy())
   {
      TradePlan="Executing BUY";
      ShowStatus();
      OpenBuy();
      return;
   }

   if(DownTrend() && PullbackSell())
   {
      TradePlan="Executing SELL";
      ShowStatus();
      OpenSell();
      return;
   }

   TradePlan="No setup";
   ShowStatus();
}