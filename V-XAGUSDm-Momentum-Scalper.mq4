//+------------------------------------------------------------------+
//| XAGUSDm Momentum Scalper EA                                      |
//+------------------------------------------------------------------+
#property strict

input string TradeSymbol = "XAGUSDm";
input double FixedLot = 0.01;
input int Slippage = 10;
input int MagicNumber = 260318;
input double BudgetBalance = 100.0;

input int FastMAPeriod = 14;
input int SlowMAPeriod = 40;
input int MomentumLookbackBars = 3;
input double SmallMomentumPoints = 120;
input double BigMomentumPoints = 260;
input double MomentumFadePoints = 60;

input double SmallProfitTargetPoints = 90;
input double BigProfitTargetPoints = 170;
input double StopLossPoints = 180;
input double MaxSpreadPoints = 60;
input int MinTradeIntervalSeconds = 45;
input int MaxOpenTrades = 1;
input double MaxLossPerTradeMoney = 5.0;
input double MinFreeMarginMoney = 35.0;

datetime LastBarTime = 0;
datetime LastTradeTime = 0;

bool IsAllowedSymbol()
{
   return Symbol() == TradeSymbol;
}

bool NewBar()
{
   if(Time[0] != LastBarTime)
   {
      LastBarTime = Time[0];
      return true;
   }

   return false;
}

bool SpreadOK()
{
   return ((Ask - Bid) / Point) <= MaxSpreadPoints;
}

bool TradeIntervalOK()
{
   return (TimeCurrent() - LastTradeTime) >= MinTradeIntervalSeconds;
}

bool AccountRiskOK()
{
   if(AccountFreeMargin() < MinFreeMarginMoney)
      return false;

   if(AccountEquity() <= BudgetBalance - (BudgetBalance * 0.30))
      return false;

   return true;
}

int CountOpenTrades()
{
   int count = 0;

   for(int index = 0; index < OrdersTotal(); index++)
   {
      if(!OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
         count++;
   }

   return count;
}

double GetPriceMomentumPoints()
{
   int shift = MomentumLookbackBars + 1;

   if(Bars <= shift)
      return 0;

   return (Close[1] - Close[shift]) / Point;
}

double GetBodyMomentumPoints()
{
   double total = 0;

   for(int index = 1; index <= MomentumLookbackBars; index++)
      total += MathAbs(Close[index] - Open[index]) / Point;

   return total;
}

bool UpTrend()
{
   double fastMA = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowMA = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   return fastMA > slowMA && Close[1] > fastMA;
}

bool DownTrend()
{
   double fastMA = iMA(NULL, 0, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);
   double slowMA = iMA(NULL, 0, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 1);

   return fastMA < slowMA && Close[1] < fastMA;
}

int GetSignalStrength(int orderType)
{
   double priceMomentum = GetPriceMomentumPoints();
   double bodyMomentum = GetBodyMomentumPoints();

   if(orderType == OP_BUY)
   {
      if(!UpTrend())
         return 0;

      if(priceMomentum >= BigMomentumPoints && bodyMomentum >= BigMomentumPoints)
         return 2;

      if(priceMomentum >= SmallMomentumPoints)
         return 1;
   }

   if(orderType == OP_SELL)
   {
      if(!DownTrend())
         return 0;

      if(priceMomentum <= -BigMomentumPoints && bodyMomentum >= BigMomentumPoints)
         return 2;

      if(priceMomentum <= -SmallMomentumPoints)
         return 1;
   }

   return 0;
}

double NormalizePrice(double price)
{
   return NormalizeDouble(price, Digits);
}

bool CloseTrade(int ticket, int orderType, double lots)
{
   RefreshRates();

   if(orderType == OP_BUY)
      return OrderClose(ticket, lots, Bid, Slippage, clrDodgerBlue);

   if(orderType == OP_SELL)
      return OrderClose(ticket, lots, Ask, Slippage, clrTomato);

   return false;
}

void ManageTrades()
{
   for(int index = OrdersTotal() - 1; index >= 0; index--)
   {
      if(!OrderSelect(index, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      bool isBigTrade = StringFind(OrderComment(), "BIG") >= 0;
      double targetPoints = isBigTrade ? BigProfitTargetPoints : SmallProfitTargetPoints;
      double profitPoints = 0;
      double netProfit = OrderProfit() + OrderSwap() + OrderCommission();
      double momentum = GetPriceMomentumPoints();

      if(orderType == OP_BUY)
         profitPoints = (Bid - OrderOpenPrice()) / Point;

      if(orderType == OP_SELL)
         profitPoints = (OrderOpenPrice() - Ask) / Point;

      if(profitPoints >= targetPoints)
      {
         CloseTrade(OrderTicket(), orderType, OrderLots());
         continue;
      }

      if(netProfit <= -MaxLossPerTradeMoney)
      {
         CloseTrade(OrderTicket(), orderType, OrderLots());
         continue;
      }

      if(netProfit > 0)
      {
         if(orderType == OP_BUY && momentum < MomentumFadePoints)
         {
            CloseTrade(OrderTicket(), orderType, OrderLots());
            continue;
         }

         if(orderType == OP_SELL && momentum > -MomentumFadePoints)
         {
            CloseTrade(OrderTicket(), orderType, OrderLots());
            continue;
         }
      }
   }
}

void OpenTrade(int orderType, bool isBigTrade)
{
   if(!TradeIntervalOK())
      return;

   if(!AccountRiskOK())
      return;

   if(CountOpenTrades() >= MaxOpenTrades)
      return;

   RefreshRates();

   double openPrice = orderType == OP_BUY ? Ask : Bid;
   double stopLoss = 0;
   double takeProfit = 0;
   double targetPoints = isBigTrade ? BigProfitTargetPoints : SmallProfitTargetPoints;
   string tag = isBigTrade ? "BIG" : "SMALL";
   string comment = TradeSymbol + " " + tag + (orderType == OP_BUY ? " BUY" : " SELL");

   if(orderType == OP_BUY)
   {
      stopLoss = NormalizePrice(openPrice - StopLossPoints * Point);
      takeProfit = NormalizePrice(openPrice + targetPoints * Point);
   }
   else
   {
      stopLoss = NormalizePrice(openPrice + StopLossPoints * Point);
      takeProfit = NormalizePrice(openPrice - targetPoints * Point);
   }

   int ticket = OrderSend(Symbol(), orderType, FixedLot, openPrice, Slippage, stopLoss, takeProfit, comment, MagicNumber, 0, clrGold);

   if(ticket > 0)
      LastTradeTime = TimeCurrent();
}

void ShowStatus()
{
   Comment(
      "XAGUSDm MOMENTUM SCALPER\n",
      "BudgetBalance: ", DoubleToString(BudgetBalance, 2), "\n",
      "FreeMargin: ", DoubleToString(AccountFreeMargin(), 2), "\n",
      "PriceMomentumPoints: ", DoubleToString(GetPriceMomentumPoints(), 1), "\n",
      "BodyMomentumPoints: ", DoubleToString(GetBodyMomentumPoints(), 1), "\n",
      "BuySignal: ", GetSignalStrength(OP_BUY), "\n",
      "SellSignal: ", GetSignalStrength(OP_SELL), "\n",
      "OpenTrades: ", CountOpenTrades(), "\n",
      "SpreadPoints: ", DoubleToString((Ask - Bid) / Point, 1)
   );
}

int OnInit()
{
   if(MomentumLookbackBars < 1)
      return INIT_PARAMETERS_INCORRECT;

   return INIT_SUCCEEDED;
}

void OnTick()
{
   if(!IsAllowedSymbol())
   {
      Comment("Attach this EA only on ", TradeSymbol);
      return;
   }

   ManageTrades();

   if(!SpreadOK())
   {
      ShowStatus();
      return;
   }

   if(!NewBar())
   {
      ShowStatus();
      return;
   }

   if(CountOpenTrades() == 0)
   {
      int buyStrength = GetSignalStrength(OP_BUY);
      int sellStrength = GetSignalStrength(OP_SELL);

      if(buyStrength > sellStrength && buyStrength > 0)
      {
         OpenTrade(OP_BUY, buyStrength == 2);
         ShowStatus();
         return;
      }

      if(sellStrength > buyStrength && sellStrength > 0)
      {
         OpenTrade(OP_SELL, sellStrength == 2);
         ShowStatus();
         return;
      }
   }

   ShowStatus();
}