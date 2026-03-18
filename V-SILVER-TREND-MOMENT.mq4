//+------------------------------------------------------------------+
//| AI Momentum + Trend EA                                           |
//+------------------------------------------------------------------+
#property strict

//---------------- INPUTS ----------------//

input int MomentumCandles = 2;

input double FixedLot = 0.01;

input double StopLossMoney = 30;

input int MaxBuyTrades = 5;
input int MaxSellTrades = 5;

input int MinTradeIntervalSeconds = 60;

input int TrendLookbackMinutes = 60;
input double TrendThreshold = 0.10;

input int ATRPeriod = 14;
input double ATRMultiplier = 1.5;

input double MinATR = 0.03;

input double MaxSpread = 60;

input int ScoreThreshold = 5;

input int MagicNumber = 555;

//---------------- GLOBALS ----------------//

datetime LastTradeTime = 0;
datetime LastBarTime = 0;

//------------------------------------------------------------

bool SpreadOK()
{
   return ((Ask - Bid) / Point) <= MaxSpread;
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
      if(Close[i] <= Open[i]) return false;

   return true;
}

//------------------------------------------------------------

bool BearishMomentum()
{
   for(int i=1;i<=MomentumCandles;i++)
      if(Close[i] >= Open[i]) return false;

   return true;
}

//------------------------------------------------------------

double GetTrendChange()
{
   int shift = iBarShift(NULL,0,TimeCurrent() - TrendLookbackMinutes*60);
   if(shift < 0) return 0;

   return (Close[0] - Close[shift]);
}

//------------------------------------------------------------

int GetTrendDirection()
{
   double change = GetTrendChange();

   if(change > TrendThreshold) return OP_BUY;
   if(change < -TrendThreshold) return OP_SELL;

   return -1;
}

//------------------------------------------------------------

int CurrentDirection()
{
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol())
      {
         if(OrderType()==OP_BUY) return OP_BUY;
         if(OrderType()==OP_SELL) return OP_SELL;
      }
   }
   return -1;
}

//------------------------------------------------------------

int CountBuyTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol() && OrderType()==OP_BUY)
         c++;
   }
   return c;
}

//------------------------------------------------------------

int CountSellTrades()
{
   int c=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderMagicNumber()==MagicNumber && OrderSymbol()==Symbol() && OrderType()==OP_SELL)
         c++;
   }
   return c;
}

//------------------------------------------------------------

double TradeProfit(int i)
{
   if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) return 0;
   return OrderProfit()+OrderSwap()+OrderCommission();
}

//------------------------------------------------------------

double GetDynamicTP()
{
   double atr = iATR(NULL,0,ATRPeriod,1);
   double tp = atr * ATRMultiplier * 50;

   if(tp < 2) tp = 2;
   if(tp > 10) tp = 10;

   return tp;
}

//------------------------------------------------------------

int GetBuyScore()
{
   int score = 0;

   if(BullishMomentum()) score += 2;
   if(GetTrendDirection() == OP_BUY) score += 3;
   if(iATR(NULL,0,ATRPeriod,1) > MinATR) score += 1;
   if(SpreadOK()) score += 1;
   if(Close[1] < Close[2]) score += 2;

   return score;
}

//------------------------------------------------------------

int GetSellScore()
{
   int score = 0;

   if(BearishMomentum()) score += 2;
   if(GetTrendDirection() == OP_SELL) score += 3;
   if(iATR(NULL,0,ATRPeriod,1) > MinATR) score += 1;
   if(SpreadOK()) score += 1;
   if(Close[1] > Close[2]) score += 2;

   return score;
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
   double dynamicTP = GetDynamicTP();

   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;

      if(OrderMagicNumber()!=MagicNumber || OrderSymbol()!=Symbol()) continue;

      double profit = TradeProfit(i);

      if(profit >= dynamicTP)
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
   "AI MOMENTUM EA\n",
   "--------------------------\n",
   "BuyScore: ",GetBuyScore(),"\n",
   "SellScore: ",GetSellScore(),"\n",
   "Trend: ",GetTrendDirection(),"\n",
   "Dynamic TP: ",DoubleToString(GetDynamicTP(),2),"\n",
   "BUY Trades: ",CountBuyTrades(),"\n",
   "SELL Trades: ",CountSellTrades(),"\n",
   "Time Gap: ",TimeCurrent()-LastTradeTime
   );
}

//------------------------------------------------------------

void OnTick()
{
   ManageTrades();

   if(!SpreadOK()) return;
   if(!NewBar()) return;
   if(!TradeIntervalOK()) return;

   int buyScore  = GetBuyScore();
   int sellScore = GetSellScore();

   int dir = CurrentDirection();

   if(dir == -1)
   {
      if(buyScore >= ScoreThreshold && buyScore > sellScore)
      {
         OpenBuy();
         return;
      }

      if(sellScore >= ScoreThreshold && sellScore > buyScore)
      {
         OpenSell();
         return;
      }
   }

   if(dir == OP_BUY && buyScore >= ScoreThreshold)
   {
      OpenBuy();
      return;
   }

   if(dir == OP_SELL && sellScore >= ScoreThreshold)
   {
      OpenSell();
      return;
   }

   ShowStatus();
}