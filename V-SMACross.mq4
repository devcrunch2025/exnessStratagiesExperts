//+------------------------------------------------------------------+
//| SMA Scalper — M1, Close at Minimum Profit                       |
//+------------------------------------------------------------------+
#property strict

input int    FastPeriod       = 5;
input int    SlowPeriod       = 20;
input int    RSIPeriod        = 14;
input double RSIMidLine       = 50.0;
input double PinWickRatio     = 1.5;
input double PinBodyMaxPct    = 0.45;
input double MomBodyMinPct    = 0.60;
input int    ATRPeriod        = 14;
input double ATRMinFactor     = 0.3;
input double LotSize          = 0.01;
input int    StopLoss         = 30;
input int    TakeProfit       = 20;
input int    MicroTPPips      = 8;
input double MicroCloseFrac   = 0.5;
input int    CooldownMinutes  = 5;
input double MinConfidence    = 0.20;
input double MinProfitUSD     = 0.02;
input int    Slippage         = 3;
input int    Magic            = 20260315;

datetime g_lastSignalBar = 0;
datetime g_lastTradeTime = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(Period() != PERIOD_M1)
      ChartSetSymbolPeriod(0, Symbol(), PERIOD_M1);
   Print("Scalper EA initialised on ", Symbol(), " M1");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
double PipSize()
{
   return Point * ((Digits == 5 || Digits == 3) ? 10 : 1);
}

//+------------------------------------------------------------------+
bool IsCandleSizeValid(int shift)
{
   double atr   = iATR(NULL, PERIOD_M1, ATRPeriod, shift);
   double range = iHigh(NULL, PERIOD_M1, shift) - iLow(NULL, PERIOD_M1, shift);
   if(atr <= 0) return false;
   return range >= atr * ATRMinFactor;
}

//+------------------------------------------------------------------+
bool IsBullishPinBar(int shift)
{
   double o = iOpen (NULL, PERIOD_M1, shift);
   double h = iHigh (NULL, PERIOD_M1, shift);
   double l = iLow  (NULL, PERIOD_M1, shift);
   double c = iClose(NULL, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   double body      = MathAbs(c - o);
   double lowerWick = MathMin(o, c) - l;
   double upperWick = h - MathMax(o, c);
   if(body / range > PinBodyMaxPct)    return false;
   if(lowerWick < body * PinWickRatio) return false;
   if(upperWick > lowerWick * 0.5)     return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsBearishPinBar(int shift)
{
   double o = iOpen (NULL, PERIOD_M1, shift);
   double h = iHigh (NULL, PERIOD_M1, shift);
   double l = iLow  (NULL, PERIOD_M1, shift);
   double c = iClose(NULL, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   double body      = MathAbs(c - o);
   double upperWick = h - MathMax(o, c);
   double lowerWick = MathMin(o, c) - l;
   if(body / range > PinBodyMaxPct)    return false;
   if(upperWick < body * PinWickRatio) return false;
   if(lowerWick > upperWick * 0.5)     return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsBullishMomentum(int shift)
{
   double o = iOpen (NULL, PERIOD_M1, shift);
   double h = iHigh (NULL, PERIOD_M1, shift);
   double l = iLow  (NULL, PERIOD_M1, shift);
   double c = iClose(NULL, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   if(c <= o)     return false;
   double body      = c - o;
   double upperWick = h - c;
   if(body / range < MomBodyMinPct) return false;
   if(upperWick > body * 0.3)       return false;
   return true;
}

//+------------------------------------------------------------------+
bool IsBearishMomentum(int shift)
{
   double o = iOpen (NULL, PERIOD_M1, shift);
   double h = iHigh (NULL, PERIOD_M1, shift);
   double l = iLow  (NULL, PERIOD_M1, shift);
   double c = iClose(NULL, PERIOD_M1, shift);
   double range = h - l;
   if(range <= 0) return false;
   if(c >= o)     return false;
   double body      = o - c;
   double lowerWick = c - l;
   if(body / range < MomBodyMinPct) return false;
   if(lowerWick > body * 0.3)       return false;
   return true;
}

//+------------------------------------------------------------------+
// Minimum profit close — closes full position when profit >= MinProfitUSD
//+------------------------------------------------------------------+
bool CheckMinProfit()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic)                 continue;
      if(OrderSymbol()      != Symbol())              continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      if(profit >= MinProfitUSD)
      {
         double closePrice = (OrderType() == OP_BUY) ? Bid : Ask;
         bool closed = OrderClose(OrderTicket(), OrderLots(),
                                  closePrice, Slippage, clrGreen);
         if(closed)
         {
            Print("Min profit close: USD ", DoubleToStr(profit, 2),
                  " on ticket #", OrderTicket());
            return true;
         }
         else
            Print("Min profit close failed: ", GetLastError());
      }
   }
   return false;
}

//+------------------------------------------------------------------+
// Micro profit booking — partial close at MicroTPPips then close remainder
//+------------------------------------------------------------------+
void CheckMicroProfit()
{
   double pip     = PipSize();
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic)                 continue;
      if(OrderSymbol()      != Symbol())              continue;

      int    ticket    = OrderTicket();
      double lots      = OrderLots();
      int    orderType = OrderType();
      double openPrice = OrderOpenPrice();

      double profitPips = 0;
      if(orderType == OP_BUY)
         profitPips = (Bid - openPrice) / pip;
      else if(orderType == OP_SELL)
         profitPips = (openPrice - Ask) / pip;
      else continue;

      if(profitPips < MicroTPPips) continue;

      double closeLot = MathFloor(lots * MicroCloseFrac / lotStep) * lotStep;
      if(closeLot < minLot) continue;
      if(lots - closeLot < minLot)
         closeLot = MathFloor((lots - minLot) / lotStep) * lotStep;
      if(closeLot < minLot) continue;

      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      bool   booked     = OrderClose(ticket, closeLot, closePrice, Slippage, clrYellow);

      if(booked)
      {
         Print("Micro TP booked: ", DoubleToStr(closeLot, 2),
               " lots at +", DoubleToStr(profitPips, 1), " pips");

         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            if(OrderCloseTime() == 0)
            {
               double rc = (OrderType() == OP_BUY) ? Bid : Ask;
               bool closed = OrderClose(ticket, OrderLots(), rc, Slippage, clrOrange);
               if(closed)
                  Print("Remainder closed");
               else
                  Print("Remainder close failed: ", GetLastError());
            }
      }
      else
         Print("Micro TP failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
// Signal engine
//+------------------------------------------------------------------+
int GetSignal(double fast, double slow, double confidence)
{
   if(TimeCurrent() - g_lastTradeTime < CooldownMinutes * 60) return 0;
   if(confidence < MinConfidence)                              return 0;

   datetime currentBar = iTime(NULL, PERIOD_M1, 1);
   if(currentBar == g_lastSignalBar) return 0;

   if(!IsCandleSizeValid(1)) return 0;

   double rsi = iRSI(NULL, PERIOD_M1, RSIPeriod, PRICE_CLOSE, 1);

   bool trendUp   = fast > slow;
   bool trendDown = fast < slow;
   bool rsiBull   = rsi > RSIMidLine;
   bool rsiBear   = rsi < RSIMidLine;

   bool bullConfirm = IsBullishPinBar(1)  || IsBullishMomentum(1);
   bool bearConfirm = IsBearishPinBar(1)  || IsBearishMomentum(1);

   if(trendUp   && rsiBull && bullConfirm) return  1;
   if(trendDown && rsiBear && bearConfirm) return -1;

   return 0;
}

//+------------------------------------------------------------------+
int GetCurrentOrderType()
{
   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
            return OrderType();
   }
   return -1;
}

//+------------------------------------------------------------------+
void CloseOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderMagicNumber() != Magic)                 continue;
      if(OrderSymbol()      != Symbol())              continue;

      bool result = false;
      if(OrderType() == OP_BUY)
         result = OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
      if(OrderType() == OP_SELL)
         result = OrderClose(OrderTicket(), OrderLots(), Ask, Slippage, clrBlue);

      if(!result)
         Print("CloseOrders failed: ", GetLastError());
   }
}

//+------------------------------------------------------------------+
void OpenBuy(double lot)
{
   double sl = Ask - StopLoss   * PipSize();
   double tp = Ask + TakeProfit * PipSize();
   int ticket = OrderSend(Symbol(), OP_BUY, lot, Ask, Slippage,
                          sl, tp, "SCALP BUY", Magic, 0, clrBlue);
   if(ticket < 0)
      Print("OpenBuy failed: ", GetLastError());
   else
   {
      Print("BUY ", DoubleToStr(lot,2), " @ ", DoubleToStr(Ask,Digits));
      g_lastSignalBar = iTime(NULL, PERIOD_M1, 1);
      g_lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void OpenSell(double lot)
{
   double sl = Bid + StopLoss   * PipSize();
   double tp = Bid - TakeProfit * PipSize();
   int ticket = OrderSend(Symbol(), OP_SELL, lot, Bid, Slippage,
                          sl, tp, "SCALP SELL", Magic, 0, clrRed);
   if(ticket < 0)
      Print("OpenSell failed: ", GetLastError());
   else
   {
      Print("SELL ", DoubleToStr(lot,2), " @ ", DoubleToStr(Bid,Digits));
      g_lastSignalBar = iTime(NULL, PERIOD_M1, 1);
      g_lastTradeTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   double fast = iMA(NULL, PERIOD_M1, FastPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double slow = iMA(NULL, PERIOD_M1, SlowPeriod, 0, MODE_SMA, PRICE_CLOSE, 1);
   double rsi  = iRSI(NULL, PERIOD_M1, RSIPeriod, PRICE_CLOSE, 1);
   double atr  = iATR(NULL, PERIOD_M1, ATRPeriod, 1);

   double edge       = MathAbs((fast - slow) / slow);
   double confidence = MathMin(1.0, edge * 2000);

   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double dynLot  = MathFloor((LotSize * confidence) / lotStep) * lotStep;
   dynLot         = MathMax(dynLot, minLot);

   // Priority 1 — min profit close
   bool closedByMinProfit = CheckMinProfit();

   // Priority 2 — micro TP partial close
   if(!closedByMinProfit)
      CheckMicroProfit();

   // Re-read position after any close
   int current = GetCurrentOrderType();

   if(current == -1)
   {
      int signal = GetSignal(fast, slow, confidence);
      if(signal ==  1) OpenBuy(dynLot);
      if(signal == -1) OpenSell(dynLot);
   }
   else
   {
      // Early exit on SMA flip only
      bool exitBuy  = (current == OP_BUY)  && (fast < slow);
      bool exitSell = (current == OP_SELL) && (fast > slow);
      if(exitBuy || exitSell)
      {
         CloseOrders();
         Print("Early exit — SMA flipped");
      }
   }

   // Current open profit
   double openProfit = 0;
   for(int i = 0; i < OrdersTotal(); i++)
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         if(OrderMagicNumber() == Magic && OrderSymbol() == Symbol())
            openProfit = OrderProfit() + OrderSwap() + OrderCommission();

   int cooldownLeft = (int)MathMax(0,
                      CooldownMinutes * 60 - (TimeCurrent() - g_lastTradeTime));

   string candleType = "none";
   if(IsBullishPinBar(1))        candleType = "bullish pin";
   else if(IsBearishPinBar(1))   candleType = "bearish pin";
   else if(IsBullishMomentum(1)) candleType = "bullish momentum";
   else if(IsBearishMomentum(1)) candleType = "bearish momentum";

   string blockReason = "";
   if(current == -1)
   {
      if(TimeCurrent() - g_lastTradeTime < CooldownMinutes * 60)
         blockReason = "Cooldown: " + (string)cooldownLeft + "s left";
      else if(confidence < MinConfidence)
         blockReason = "Waiting: confidence too low";
      else if(!IsCandleSizeValid(1))
         blockReason = "Waiting: candle too small";
      else if(candleType == "none")
         blockReason = "Waiting: no signal candle";
      else
         blockReason = "Waiting: RSI or trend mismatch";
   }

   string trendStr = (fast > slow) ? "UP" : (fast < slow) ? "DOWN" : "FLAT";
   string rsiState = (rsi > RSIMidLine) ? "BULLISH" : "BEARISH";
   string posStr   = (current == OP_BUY)  ? "LONG" :
                     (current == OP_SELL) ? "SHORT" : "FLAT";

   Comment(
      "Symbol:        ", Symbol(),                                   "\n",
      "Timeframe:     M1",                                           "\n",
      "────────────────────────────",                                "\n",
      "Trend (", FastPeriod, "/", SlowPeriod, " SMA):  ", trendStr, "\n",
      "RSI (", RSIPeriod, "):     ",
                         DoubleToStr(rsi, 2), "  [", rsiState, "]\n",
      "ATR:           ", DoubleToStr(atr / PipSize(), 1), " pips\n",
      "Candle:        ", candleType,                                 "\n",
      "Confidence:    ", DoubleToStr(confidence * 100, 1), "%",
                         (confidence < MinConfidence) ? " (LOW)" : "", "\n",
      "────────────────────────────",                                "\n",
      "Position:      ", posStr,                                     "\n",
      "Open P/L:      USD ", DoubleToStr(openProfit, 2),            "\n",
      "Min close at:  USD ", DoubleToStr(MinProfitUSD, 2),          "\n",
      "SL / TP:       ", StopLoss, " / ", TakeProfit, " pips\n",
      "Cooldown:      ",
         (cooldownLeft > 0) ? (string)cooldownLeft + "s" : "ready", "\n",
      blockReason
   );
}
//+------------------------------------------------------------------+