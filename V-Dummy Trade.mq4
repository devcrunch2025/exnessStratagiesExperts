//+------------------------------------------------------------------+
//| Virtual Dummy Momentum EA - Protected Version                    |
//+------------------------------------------------------------------+
#property strict

input double RealLot = 0.02;

input double TriggerProfit = 0.5;
input double TriggerLoss   = 0.5;

input double TakeProfitAmount = 0.08;
input double StopLossAmount   = 0.5;

input int MaxSpread = 80;          // spread filter
input int TradeDelaySeconds = 15;  // delay between trades

input int MagicNumber = 777;

bool DummyActive=false;
bool RealTradeOpened=false;

double DummyPrice=0;
int DummyDirection=1;

int LastDirection=1;
datetime LastTradeTime=0;

//+------------------------------------------------------------------+

double TotalProfit()
{
   double p=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         p+=OrderProfit()+OrderSwap()+OrderCommission();
   }

   return p;
}

//+------------------------------------------------------------------+

int CountTrades()
{
   int c=0;

   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
         c++;
   }

   return c;
}

//+------------------------------------------------------------------+

bool SpreadOK()
{
   double spread=(Ask-Bid)/Point;

   if(spread > MaxSpread)
      return false;

   return true;
}

//+------------------------------------------------------------------+

bool MomentumOK()
{
   double body=MathAbs(Close[1]-Open[1]);

   if(body < 10*Point)
      return false;

   return true;
}

//+------------------------------------------------------------------+

void CreateDummy()
{
   RefreshRates();

   DummyDirection=1;
   DummyPrice=Ask;
   DummyActive=true;
}

//+------------------------------------------------------------------+

double DummyProfit()
{
   if(!DummyActive)
      return 0;

   double tickValue = MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(),MODE_TICKSIZE);

   double move;

   if(DummyDirection==1)
      move = Bid-DummyPrice;
   else
      move = DummyPrice-Ask;

   double profit = (move/tickSize)*tickValue*RealLot;

   return profit;
}

//+------------------------------------------------------------------+

void OpenBuy()
{
   if(!SpreadOK()) return;

   if(TimeCurrent()-LastTradeTime < TradeDelaySeconds)
      return;

   RefreshRates();

   int ticket=OrderSend(Symbol(),OP_BUY,RealLot,Ask,10,0,0,"RealBuy",MagicNumber,0,clrGreen);

   if(ticket>0)
   {
      LastDirection=1;
      RealTradeOpened=true;
      LastTradeTime=TimeCurrent();
   }
}

//+------------------------------------------------------------------+

void OpenSell()
{
   if(!SpreadOK()) return;

   if(TimeCurrent()-LastTradeTime < TradeDelaySeconds)
      return;

   RefreshRates();

   int ticket=OrderSend(Symbol(),OP_SELL,RealLot,Bid,10,0,0,"RealSell",MagicNumber,0,clrRed);

   if(ticket>0)
   {
      LastDirection=-1;
      RealTradeOpened=true;
      LastTradeTime=TimeCurrent();
   }
}

//+------------------------------------------------------------------+

void CloseAllTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol())
         continue;

      if(OrderType()==OP_BUY)
         OrderClose(OrderTicket(),OrderLots(),Bid,10);

      if(OrderType()==OP_SELL)
         OrderClose(OrderTicket(),OrderLots(),Ask,10);
   }
}

//+------------------------------------------------------------------+

void OpenSameDirectionTrade()
{
   if(LastDirection==1)
      OpenBuy();
   else
      OpenSell();
}

//+------------------------------------------------------------------+

void OpenReverseTrade()
{
   if(LastDirection==1)
      OpenSell();
   else
      OpenBuy();
}

//+------------------------------------------------------------------+

void ManageStrategy()
{
   double total = TotalProfit();

   // TAKE PROFIT
   if(total >= TakeProfitAmount)
   {
      CloseAllTrades();
      Sleep(1000);

      RealTradeOpened=false;
      DummyActive=false;

      OpenSameDirectionTrade();
      return;
   }

   // STOP LOSS
   if(total <= -StopLossAmount)
   {
      CloseAllTrades();
      Sleep(1000);

      RealTradeOpened=false;
      DummyActive=false;

      OpenReverseTrade();
      return;
   }

   // DUMMY CHECK
   if(!RealTradeOpened && DummyActive)
   {
      if(!MomentumOK())
         return;

      double dp = DummyProfit();

      if(dp >= TriggerProfit)
      {
         OpenBuy();
         DummyActive=false;
      }

      if(dp <= -TriggerLoss)
      {
         OpenSell();
         DummyActive=false;
      }
   }
}

//+------------------------------------------------------------------+

void ShowPanel()
{
   Comment(
   "PROTECTED MOMENTUM EA\n",
   "----------------------------\n",
   "Symbol: ",Symbol(),"\n\n",

   "Spread: ",DoubleToString((Ask-Bid)/Point,0),"\n",

   "Dummy Active: ",DummyActive,"\n",
   "Dummy Profit: ",DoubleToString(DummyProfit(),2),"\n\n",

   "Trades: ",CountTrades(),"\n",
   "Total Profit: ",DoubleToString(TotalProfit(),2),"\n",

   "Last Direction: ",LastDirection
   );
}

//+------------------------------------------------------------------+

void OnTick()
{
   if(!DummyActive && CountTrades()==0)
   {
      CreateDummy();
      return;
   }

   ManageStrategy();

   ShowPanel();
}