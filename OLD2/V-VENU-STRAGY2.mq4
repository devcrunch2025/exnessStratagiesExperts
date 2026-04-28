//+------------------------------------------------------------------+
//|                                                Venu_Clean_EA.mq4 |
//|                       Clean Controlled Basket EA                  |
//+------------------------------------------------------------------+
#property strict

// =========================
// INPUTS
// =========================

// --- License / identity ---
extern int    MagicNumber                  = 222222;
extern string TradeComment                 = "Venu Clean EA";

// --- Signal mode ---
extern bool   UseSimpleSARSignal           = true;    // true = built-in signal
extern bool   UseTrendFilterEMA200         = true;    // buy only above EMA200, sell only below EMA200
extern int    TrendEMAPeriod               = 200;

// --- SAR signal settings ---
extern double SAR_Step                     = 0.02;
extern double SAR_Max                      = 0.2;

// --- Trade control ---
extern bool   AllowBuy                     = true;
extern bool   AllowSell                    = true;
extern bool   OneDirectionAtATime          = true;    // do not mix BUY and SELL baskets
extern bool   OneOrderPerCandle            = true;    // one new order per bar
extern int    MinDistanceBetweenTradesPts  = 500;     // minimum distance between same-direction entries
extern int    MaxTradesPerBasket           = 10;
extern int    Slippage                     = 5;
extern int    MaxSpreadPoints              = 300;

// --- Lots: controlled ladder ---
extern bool   UseAutoLotLadder             = true;
extern double BaseLot                      = 0.01;
extern double LotIncrement                 = 0.01;
extern double MaxLot                       = 0.10;

// If UseAutoLotLadder = false, custom per-trade lots below will be used
extern double Trade1Lot                    = 0.01;
extern double Trade2Lot                    = 0.01;
extern double Trade3Lot                    = 0.01;
extern double Trade4Lot                    = 0.01;
extern double Trade5Lot                    = 0.01;
extern double Trade6Lot                    = 0.02;
extern double Trade7Lot                    = 0.02;
extern double Trade8Lot                    = 0.02;
extern double Trade9Lot                    = 0.02;
extern double Trade10Lot                   = 0.03;

// --- Basket targets ---
extern double BasketTakeProfitMoney        = 3.0;     // close all when basket P/L >= this
extern bool   UseFloatingLossLimit         = true;
extern double FloatingLossLimitMoney       = 20.0;    // close all and stop trading for the day if hit

// --- Daily protection ---
extern bool   UseDailyLimits               = true;
extern double DailyProfitLimit             = 50.0;
extern double DailyLossLimit               = 30.0;

// --- Profit protect master ---
extern bool   EnableProfitProtection       = true;
extern double ActivateAfterProfit          = 5.0;

// --- Step lock settings ---
extern bool   EnableStepLock               = true;
extern double Step1Profit                  = 5.0;
extern double Step1Lock                    = 1.0;
extern double Step2Profit                  = 10.0;
extern double Step2Lock                    = 5.0;
extern double Step3Profit                  = 15.0;
extern double Step3Lock                    = 10.0;
extern double Step4Profit                  = 20.0;
extern double Step4Lock                    = 15.0;

// --- Optional hard SL/TP per order (0 = unused) ---
extern int    HardStopLossPoints           = 0;
extern int    HardTakeProfitPoints         = 0;

// --- Display ---
extern bool   ShowPanel                    = true;

// =========================
// GLOBALS
// =========================
datetime g_lastBuyBarTime  = 0;
datetime g_lastSellBarTime = 0;

double   g_buyPeakProfit   = 0.0;
double   g_sellPeakProfit  = 0.0;

bool     g_stopTradingToday = false;
datetime g_dayStart         = 0;

// =========================
// HELPERS
// =========================
double PipPoint()
{
   if(Digits == 3 || Digits == 5) return Point * 10.0;
   return Point;
}

bool IsNewDay()
{
   datetime now = TimeCurrent();
   if(g_dayStart == 0)
   {
      g_dayStart = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
      return false;
   }

   datetime todayStart = StringToTime(TimeToString(now, TIME_DATE) + " 00:00");
   if(todayStart != g_dayStart)
   {
      g_dayStart = todayStart;
      return true;
   }
   return false;
}

double NormalizeLot(double lot)
{
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;

   lot = MathFloor(lot / lotStep) * lotStep;
   lot = NormalizeDouble(lot, 2);
   return lot;
}

double GetSpreadPoints()
{
   return (Ask - Bid) / Point;
}

bool IsSpreadOK()
{
   return (GetSpreadPoints() <= MaxSpreadPoints);
}

int CountOpenOrders(int type)
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() == type) count++;
   }
   return count;
}

int CountAllOpenManagedOrders()
{
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() == OP_BUY || OrderType() == OP_SELL) count++;
   }
   return count;
}

double BasketProfitByType(int type)
{
   double total = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != type) continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return total;
}

double BasketProfitAll()
{
   double total = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return total;
}

double TodayClosedProfit()
{
   double total = 0.0;
   datetime todayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderCloseTime() < todayStart) continue;

      total += OrderProfit() + OrderSwap() + OrderCommission();
   }
   return total;
}

double TodayNetProfit()
{
   return TodayClosedProfit() + BasketProfitAll();
}

double GetLastOpenPriceByType(int type)
{
   double lastPrice = 0.0;
   datetime lastTime = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != type) continue;

      if(OrderOpenTime() > lastTime)
      {
         lastTime  = OrderOpenTime();
         lastPrice = OrderOpenPrice();
      }
   }
   return lastPrice;
}

bool DistanceOK(int type)
{
   int count = CountOpenOrders(type);
   if(count == 0) return true;

   double lastOpenPrice = GetLastOpenPriceByType(type);
   double distPts = MathAbs(((type == OP_BUY ? Ask : Bid) - lastOpenPrice) / Point);

   return (distPts >= MinDistanceBetweenTradesPts);
}

bool NewBarForType(int type)
{
   datetime barTime = iTime(Symbol(), Period(), 0);

   if(type == OP_BUY)
   {
      if(g_lastBuyBarTime == barTime) return false;
      return true;
   }
   else if(type == OP_SELL)
   {
      if(g_lastSellBarTime == barTime) return false;
      return true;
   }
   return false;
}

void MarkBarUsed(int type)
{
   datetime barTime = iTime(Symbol(), Period(), 0);

   if(type == OP_BUY)  g_lastBuyBarTime  = barTime;
   if(type == OP_SELL) g_lastSellBarTime = barTime;
}

double GetLotForTradeNumber(int tradeNo)
{
   double lot = BaseLot;

   if(UseAutoLotLadder)
   {
      lot = BaseLot + (tradeNo - 1) * LotIncrement;
      if(lot > MaxLot) lot = MaxLot;
      return NormalizeLot(lot);
   }

   switch(tradeNo)
   {
      case 1:  lot = Trade1Lot;  break;
      case 2:  lot = Trade2Lot;  break;
      case 3:  lot = Trade3Lot;  break;
      case 4:  lot = Trade4Lot;  break;
      case 5:  lot = Trade5Lot;  break;
      case 6:  lot = Trade6Lot;  break;
      case 7:  lot = Trade7Lot;  break;
      case 8:  lot = Trade8Lot;  break;
      case 9:  lot = Trade9Lot;  break;
      default: lot = Trade10Lot; break;
   }

   return NormalizeLot(lot);
}

bool TrendAllowsBuy()
{
   if(!UseTrendFilterEMA200) return true;
   double ema = iMA(Symbol(), 0, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   return (Close[0] > ema);
}

bool TrendAllowsSell()
{
   if(!UseTrendFilterEMA200) return true;
   double ema = iMA(Symbol(), 0, TrendEMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
   return (Close[0] < ema);
}

// =========================
// SIGNALS
// =========================
bool BuySignal()
{
   if(!UseSimpleSARSignal) return false;

   double sar0 = iSAR(Symbol(), 0, SAR_Step, SAR_Max, 0);
   double sar1 = iSAR(Symbol(), 0, SAR_Step, SAR_Max, 1);

   bool flipUp = (sar1 > High[1] && sar0 < Low[0]);
   return flipUp;
}

bool SellSignal()
{
   if(!UseSimpleSARSignal) return false;

   double sar0 = iSAR(Symbol(), 0, SAR_Step, SAR_Max, 0);
   double sar1 = iSAR(Symbol(), 0, SAR_Step, SAR_Max, 1);

   bool flipDown = (sar1 < Low[1] && sar0 > High[0]);
   return flipDown;
}

// =========================
// ORDER OPERATIONS
// =========================
bool OpenOrder(int type)
{
   if(g_stopTradingToday) return false;
   if(!IsSpreadOK()) return false;

   int sameCount = CountOpenOrders(type);
   if(sameCount >= MaxTradesPerBasket) return false;

   if(OneDirectionAtATime)
   {
      int opposite = (type == OP_BUY ? OP_SELL : OP_BUY);
      if(CountOpenOrders(opposite) > 0) return false;
   }

   if(OneOrderPerCandle && !NewBarForType(type)) return false;
   if(!DistanceOK(type)) return false;

   int tradeNo = sameCount + 1;
   double lot = GetLotForTradeNumber(tradeNo);

   double price = (type == OP_BUY ? Ask : Bid);
   double sl = 0;
   double tp = 0;

   if(HardStopLossPoints > 0)
   {
      if(type == OP_BUY)  sl = price - HardStopLossPoints * Point;
      if(type == OP_SELL) sl = price + HardStopLossPoints * Point;
   }

   if(HardTakeProfitPoints > 0)
   {
      if(type == OP_BUY)  tp = price + HardTakeProfitPoints * Point;
      if(type == OP_SELL) tp = price - HardTakeProfitPoints * Point;
   }

   int ticket = OrderSend(Symbol(), type, lot, price, Slippage, sl, tp, TradeComment, MagicNumber, 0,
                          (type == OP_BUY ? clrBlue : clrRed));

   if(ticket > 0)
   {
      MarkBarUsed(type);
      Print("Opened ", (type == OP_BUY ? "BUY" : "SELL"), " ticket=", ticket,
            " lot=", DoubleToString(lot, 2), " tradeNo=", tradeNo);
      return true;
   }

   Print("OrderSend failed. Type=", type, " Error=", GetLastError());
   return false;
}

void CloseOrdersByType(int type)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != MagicNumber) continue;
      if(OrderType() != type) continue;

      double price = (type == OP_BUY ? Bid : Ask);
      bool closed = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrWhite);

      if(!closed)
         Print("OrderClose failed. Ticket=", OrderTicket(), " Error=", GetLastError());
   }
}

void CloseAllManagedOrders()
{
   for(int pass = 0; pass < 3; pass++)
   {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
      {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
         if(OrderSymbol() != Symbol()) continue;
         if(OrderMagicNumber() != MagicNumber) continue;
         if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

         double price = (OrderType() == OP_BUY ? Bid : Ask);
         bool closed = OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrWhite);

         if(!closed)
            Print("CloseAll failed. Ticket=", OrderTicket(), " Error=", GetLastError());
      }
   }
}

// =========================
// PROFIT PROTECT
// =========================
double CurrentStepLockValue(double profit)
{
   double lockValue = -1.0;

   if(profit >= Step1Profit) lockValue = Step1Lock;
   if(profit >= Step2Profit) lockValue = Step2Lock;
   if(profit >= Step3Profit) lockValue = Step3Lock;
   if(profit >= Step4Profit) lockValue = Step4Lock;

   return lockValue;
}

void HandleBasketProfitProtection()
{
   if(!EnableProfitProtection || !EnableStepLock) return;

   double buyProfit  = BasketProfitByType(OP_BUY);
   double sellProfit = BasketProfitByType(OP_SELL);

   if(buyProfit > g_buyPeakProfit) g_buyPeakProfit = buyProfit;
   if(sellProfit > g_sellPeakProfit) g_sellPeakProfit = sellProfit;

   // BUY basket
   if(CountOpenOrders(OP_BUY) > 0 && g_buyPeakProfit >= ActivateAfterProfit)
   {
      double lockVal = CurrentStepLockValue(g_buyPeakProfit);
      if(lockVal >= 0 && buyProfit <= lockVal)
      {
         Print("BUY basket step lock hit. Peak=", DoubleToString(g_buyPeakProfit,2),
               " current=", DoubleToString(buyProfit,2), " lock=", DoubleToString(lockVal,2));
         CloseOrdersByType(OP_BUY);
         g_buyPeakProfit = 0.0;
      }
   }
   else if(CountOpenOrders(OP_BUY) == 0)
   {
      g_buyPeakProfit = 0.0;
   }

   // SELL basket
   if(CountOpenOrders(OP_SELL) > 0 && g_sellPeakProfit >= ActivateAfterProfit)
   {
      double lockVal2 = CurrentStepLockValue(g_sellPeakProfit);
      if(lockVal2 >= 0 && sellProfit <= lockVal2)
      {
         Print("SELL basket step lock hit. Peak=", DoubleToString(g_sellPeakProfit,2),
               " current=", DoubleToString(sellProfit,2), " lock=", DoubleToString(lockVal2,2));
         CloseOrdersByType(OP_SELL);
         g_sellPeakProfit = 0.0;
      }
   }
   else if(CountOpenOrders(OP_SELL) == 0)
   {
      g_sellPeakProfit = 0.0;
   }
}

void HandleBasketTakeProfit()
{
   double buyProfit  = BasketProfitByType(OP_BUY);
   double sellProfit = BasketProfitByType(OP_SELL);

   if(CountOpenOrders(OP_BUY) > 0 && buyProfit >= BasketTakeProfitMoney)
   {
      Print("BUY basket take profit hit: ", DoubleToString(buyProfit,2));
      CloseOrdersByType(OP_BUY);
      g_buyPeakProfit = 0.0;
   }

   if(CountOpenOrders(OP_SELL) > 0 && sellProfit >= BasketTakeProfitMoney)
   {
      Print("SELL basket take profit hit: ", DoubleToString(sellProfit,2));
      CloseOrdersByType(OP_SELL);
      g_sellPeakProfit = 0.0;
   }
}

void HandleFloatingLossLimit()
{
   if(!UseFloatingLossLimit) return;

   double totalOpenProfit = BasketProfitAll();

   if(totalOpenProfit <= -FloatingLossLimitMoney)
   {
      Print("Floating loss limit hit: ", DoubleToString(totalOpenProfit,2));
      CloseAllManagedOrders();
      g_stopTradingToday = true;
   }
}

void HandleDailyLimits()
{
   if(!UseDailyLimits) return;

   double net = TodayNetProfit();

   if(net >= DailyProfitLimit)
   {
      Print("Daily profit limit reached: ", DoubleToString(net,2));
      g_stopTradingToday = true;
      CloseAllManagedOrders();
   }
   else if(net <= -DailyLossLimit)
   {
      Print("Daily loss limit reached: ", DoubleToString(net,2));
      g_stopTradingToday = true;
      CloseAllManagedOrders();
   }
}

// =========================
// PANEL
// =========================
void DrawLabel(string name, string text, int x, int y, color clr, int size=10)
{
   if(ObjectFind(0, name) == -1)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void UpdatePanel()
{
   if(!ShowPanel) return;

   string status = g_stopTradingToday ? "STOPPED" : "ACTIVE";

   DrawLabel("vc_ea_1", Symbol() + " | " + status, 10, 20, clrAqua, 12);
   DrawLabel("vc_ea_2", "BUY Orders: " + IntegerToString(CountOpenOrders(OP_BUY)) +
                        " | SELL Orders: " + IntegerToString(CountOpenOrders(OP_SELL)), 10, 40, clrWhite, 10);

   DrawLabel("vc_ea_3", "Open P/L: $" + DoubleToString(BasketProfitAll(), 2), 10, 60,
             BasketProfitAll() >= 0 ? clrLime : clrRed, 10);

   DrawLabel("vc_ea_4", "Today Net: $" + DoubleToString(TodayNetProfit(), 2), 10, 80,
             TodayNetProfit() >= 0 ? clrLime : clrRed, 10);

   DrawLabel("vc_ea_5", "BUY Peak: $" + DoubleToString(g_buyPeakProfit, 2) +
                        " | SELL Peak: $" + DoubleToString(g_sellPeakProfit, 2), 10, 100, clrYellow, 10);

   DrawLabel("vc_ea_6", "Spread: " + DoubleToString(GetSpreadPoints(), 1) + " pts", 10, 120, clrOrange, 10);
}

// =========================
// MAIN
// =========================
int OnInit()
{
   g_dayStart = StringToTime(TimeToString(TimeCurrent(), TIME_DATE) + " 00:00");
   g_stopTradingToday = false;
   g_buyPeakProfit = 0.0;
   g_sellPeakProfit = 0.0;
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   string objs[6] = {"vc_ea_1","vc_ea_2","vc_ea_3","vc_ea_4","vc_ea_5","vc_ea_6"};
   for(int i=0; i<ArraySize(objs); i++)
      ObjectDelete(0, objs[i]);
}

void OnTick()
{
   if(IsNewDay())
   {
      g_stopTradingToday = false;
      g_buyPeakProfit = 0.0;
      g_sellPeakProfit = 0.0;
      Print("New trading day reset.");
   }

   HandleDailyLimits();
   HandleFloatingLossLimit();
   HandleBasketTakeProfit();
   HandleBasketProfitProtection();

   if(g_stopTradingToday)
   {
      UpdatePanel();
      return;
   }

   bool buySignal  = BuySignal();
   bool sellSignal = SellSignal();

   // BUY
   if(AllowBuy && buySignal && TrendAllowsBuy())
   {
      OpenOrder(OP_BUY);
   }

   // SELL
   if(AllowSell && sellSignal && TrendAllowsSell())
   {
      OpenOrder(OP_SELL);
   }

   UpdatePanel();
}