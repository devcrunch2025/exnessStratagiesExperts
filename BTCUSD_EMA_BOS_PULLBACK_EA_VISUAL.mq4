//+------------------------------------------------------------------+
//| BTCUSD_EMA_BOS_PULLBACK_EA_VISUAL_STEP_TRAIL.mq4                 |
//| Strategy 4: EMA trend + BOS + Pullback with chart visuals        |
//| Profit exit: step trail + paired recovery basket TP            |
//+------------------------------------------------------------------+
#property strict

 double InpLotSize              = 0.01;
 int    InpMagicNumber          = 44001;
 int    InpSlippage             = 30;

 int    InpEMAPeriod            = 50;
 int    InpSwingLookback        = 20;
 int    InpPullbackMaxBars      = 10;
 double InpMinBOSRawGap         = 20.0;
 double InpPullbackMinRaw       = 30.0;
 double InpPullbackMaxRaw       = 120.0;

// InpTakeProfitUSD is now the moving profit-lock step.
// Example: 1.00 locks $1, $2, $3, $4... as peak profit rises.
 double InpTakeProfitUSD        = 0.50;//1.00;
 int    InpMaxOpenOrders        = 1;//2;//1;$40 at 1
 bool   InpOnlyNewCandleEntry   = true;
 bool   InpShowVisuals          = true;
 int    InpEMALineBars          = 80;

// Recovery order settings.
// A recovery order is opened in the SAME direction as a losing parent order
// only when the adverse raw-price distance is at least the configured gap
// and the currently active BOS signal matches the parent order direction.
 bool   InpUseRecoveryOrders             = true;
 double InpRecoveryLotSize               = 0.01;
 double InpRecoveryRawDifference         = 100.0;
 int    InpMaxRecoveryOrdersPerDirection = 1;

// Close the recovery order and its original parent together when their
// combined net profit reaches InpTakeProfitUSD.
 bool   InpCloseRecoveryBasketAtTP        = true;

// Fixed money-based stop loss for every order.
const double FIXED_STOP_LOSS_USD     = 6;//4;//5.00;$40 at 6

int      g_bosDirection = 0;
bool     g_bosActive    = false;
double   g_bosPrice     = 0.0;
datetime g_bosTime      = 0;
datetime g_lastBarTime  = 0;
string   g_lastStatus   = "Starting";
string   PFX            = "EMABOSPB_";


bool IsDubaiBlockedTime()
{
   datetime gmtTime = TimeGMT();
   datetime dubaiTime = gmtTime + 4 * 3600;

   int hour = TimeHour(dubaiTime);

   if(hour >= 16 && hour < 20) // 4PM,5PM,6PM,7PM
      return(true);

   return(false);
}
//+------------------------------------------------------------------+
int OnInit()
{
     DeleteObjectsByPrefix(PFX);

   Print("EMA BOS Pullback Visual EA started");

   if(InpShowVisuals)
      DrawDashboard("Initialized");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   DeleteObjectsByPrefix(PFX);
   Comment("");
}

//+------------------------------------------------------------------+
void OnTick()
{
   RefreshRates();

   // Paired recovery basket exit has priority over individual exits.
   // This lets recovery profit offset the original order loss.
   CloseRecoveryBasketsAtTP();
   CloseByProfitOrLoss();

   bool isNewBar = (Time[0] != g_lastBarTime);
   if(isNewBar) g_lastBarTime = Time[0];

   DetectBOS();

   // Recovery has priority over the normal pullback entry.
   // It is allowed beside the losing parent order, so InpMaxOpenOrders
   // does not block this special recovery order.
   if(TryOpenRecoveryOrder())
   {
      if(InpShowVisuals) UpdateVisuals(false, GetEMATrend());
      return;
   }

   int emaTrend = GetEMATrend();
   bool pullbackReady = (g_bosActive && IsPullbackEntryReady());
   bool emaAllowed = (emaTrend == g_bosDirection && emaTrend != 0);
   bool entryReady = (pullbackReady && emaAllowed);

   if(InpShowVisuals) UpdateVisuals(entryReady, emaTrend);

   if(InpOnlyNewCandleEntry && !isNewBar)
   {
      g_lastStatus = "Waiting new candle";
      return;
   }

   if(CountMyOrders() >= InpMaxOpenOrders)
   {
      g_lastStatus = "Blocked: max open orders";
      return;
   }

//    if(IsDubaiBlockedTime())
// {

//    g_lastStatus="TRADING PAUSED | Dubai Time 4PM-8PM";
//    // Comment("TRADING PAUSED | Dubai Time 4PM-8PM");
//    return;
// }

   if(entryReady)
   {
      if(g_bosDirection == 1)
      {
         if(OpenOrder(OP_BUY, "EMA_BOS_PULLBACK_BUY"))
            DrawEntryArrow(1, Ask, TimeCurrent());
      }
      else if(g_bosDirection == -1)
      {
         if(OpenOrder(OP_SELL, "EMA_BOS_PULLBACK_SELL"))
            DrawEntryArrow(-1, Bid, TimeCurrent());
      }

      g_bosActive = false;
   }
   else if(pullbackReady && !emaAllowed)
   {
      g_lastStatus = "Blocked: EMA trend mismatch";
   }
}

//+------------------------------------------------------------------+
int GetEMATrend()
{
   double ema1 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 1);
   double ema5 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                     MODE_EMA, PRICE_CLOSE, 5);

   if(Close[1] > ema1 && ema1 > ema5) return(1);
   if(Close[1] < ema1 && ema1 < ema5) return(-1);
   return(0);
}

//+------------------------------------------------------------------+
void DetectBOS()
{
   if(Bars < InpSwingLookback + 5) return;

   int highIndex = iHighest(Symbol(), Period(), MODE_HIGH,
                            InpSwingLookback, 2);
   int lowIndex  = iLowest(Symbol(), Period(), MODE_LOW,
                           InpSwingLookback, 2);

   double structureHigh = High[highIndex];
   double structureLow  = Low[lowIndex];

   DrawHLine(PFX+"STRUCT_HIGH", structureHigh,
             clrDodgerBlue, STYLE_DOT, "Structure High");
   DrawHLine(PFX+"STRUCT_LOW", structureLow,
             clrTomato, STYLE_DOT, "Structure Low");

   if(Ask > structureHigh + InpMinBOSRawGap)
   {
      if(g_bosDirection != 1 || !g_bosActive)
      {
         g_bosDirection = 1;
         g_bosActive    = true;
         g_bosPrice     = Ask;
         g_bosTime      = TimeCurrent();
         g_lastStatus   = "Bullish BOS detected";
         DrawBOS(1, structureHigh, g_bosPrice, g_bosTime);
      }
      return;
   }

   if(Bid < structureLow - InpMinBOSRawGap)
   {
      if(g_bosDirection != -1 || !g_bosActive)
      {
         g_bosDirection = -1;
         g_bosActive    = true;
         g_bosPrice     = Bid;
         g_bosTime      = TimeCurrent();
         g_lastStatus   = "Bearish BOS detected";
         DrawBOS(-1, structureLow, g_bosPrice, g_bosTime);
      }
      return;
   }
}

//+------------------------------------------------------------------+
bool IsPullbackEntryReady()
{
   if(!g_bosActive || g_bosDirection == 0) return(false);

   int barsFromBOS = iBarShift(Symbol(), Period(), g_bosTime, false);
   if(barsFromBOS > InpPullbackMaxBars)
   {
      g_bosActive  = false;
      g_lastStatus = "BOS expired";
      return(false);
   }

   double pullbackRaw = 0.0;
   if(g_bosDirection == 1)
      pullbackRaw = g_bosPrice - Bid;
   else if(g_bosDirection == -1)
      pullbackRaw = Ask - g_bosPrice;

   if(pullbackRaw >= InpPullbackMinRaw &&
      pullbackRaw <= InpPullbackMaxRaw)
   {
      g_lastStatus = "Pullback ready";
      return(true);
   }

   g_lastStatus = "Waiting pullback";
   return(false);
}

//+------------------------------------------------------------------+
bool OpenOrder(int type, string orderComment)
{
   return(OpenOrderWithLots(type, InpLotSize, orderComment));
}

//+------------------------------------------------------------------+
bool OpenOrderWithLots(int type, double lots, string orderComment)
{
   RefreshRates();

   double price = (type == OP_BUY) ? Ask : Bid;
   ResetLastError();

   int ticket = OrderSend(Symbol(), type, lots, price,
                          InpSlippage, 0, 0, orderComment,
                          InpMagicNumber, 0, clrNONE);

   if(ticket < 0)
   {
      int err = GetLastError();
      g_lastStatus = "OrderSend failed: " + IntegerToString(err);
      Print(g_lastStatus);
      return(false);
   }

   DeleteProfitTrailState(ticket);
   g_lastStatus = "Order opened #" + IntegerToString(ticket);
   return(true);
}

//+------------------------------------------------------------------+
bool IsRecoveryOrderComment(string orderComment)
{
   return(StringFind(orderComment, "BOS_RECOVERY_", 0) == 0);
}

//+------------------------------------------------------------------+
int CountRecoveryOrders(int orderType)
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != orderType) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      count++;
   }

   return(count);
}

//+------------------------------------------------------------------+
string RecoveryBOSKey(int parentTicket)
{
   return("EBP_REC_BOS_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          IntegerToString(parentTicket));
}

//+------------------------------------------------------------------+
bool RecoveryAlreadyUsedForCurrentBOS(int parentTicket)
{
   string key = RecoveryBOSKey(parentTicket);

   if(!GlobalVariableCheck(key))
      return(false);

   datetime usedBOSTime = (datetime)GlobalVariableGet(key);
   return(usedBOSTime == g_bosTime);
}

//+------------------------------------------------------------------+
void MarkRecoveryUsedForCurrentBOS(int parentTicket)
{
   GlobalVariableSet(RecoveryBOSKey(parentTicket), (double)g_bosTime);
}

//+------------------------------------------------------------------+
int GetRecoveryParentTicket(string orderComment)
{
   if(!IsRecoveryOrderComment(orderComment))
      return(-1);

   int markerPos = StringFind(orderComment, "_P", 0);
   if(markerPos < 0)
      return(-1);

   string ticketText = StringSubstr(orderComment, markerPos + 2);
   int parentTicket = (int)StrToInteger(ticketText);

   return(parentTicket > 0 ? parentTicket : -1);
}

//+------------------------------------------------------------------+
bool IsMyOpenMarketOrder(int ticket)
{
   if(ticket <= 0) return(false);
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) return(false);
   if(OrderCloseTime() != 0) return(false);
   if(OrderSymbol() != Symbol()) return(false);
   if(OrderMagicNumber() != InpMagicNumber) return(false);
   if(OrderType() != OP_BUY && OrderType() != OP_SELL) return(false);

   return(true);
}

//+------------------------------------------------------------------+
bool IsOrderInActiveRecoveryPair(int ticket)
{
   if(ticket <= 0) return(false);

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      int recoveryTicket = OrderTicket();
      int parentTicket = GetRecoveryParentTicket(OrderComment());

      if(parentTicket <= 0) continue;
      if(ticket != recoveryTicket && ticket != parentTicket) continue;

      if(IsMyOpenMarketOrder(parentTicket) &&
         IsMyOpenMarketOrder(recoveryTicket))
      {
         return(true);
      }
   }

   return(false);
}

//+------------------------------------------------------------------+
bool CloseOrderByTicket(int ticket,
                        string reason,
                        double detectedProfit)
{
   if(!IsMyOpenMarketOrder(ticket))
      return(false);

   int type = OrderType();
   double lots = OrderLots();

   RefreshRates();
   double closePrice = (type == OP_BUY) ? Bid : Ask;
   color closeColor  = (type == OP_BUY) ? clrLime : clrRed;

   ResetLastError();
   bool closed = OrderClose(ticket,
                            lots,
                            closePrice,
                            InpSlippage,
                            closeColor);

   if(closed)
   {
      DeleteProfitTrailState(ticket);
      Print(reason,
            " | Ticket #", ticket,
            " | Detected P/L $", DoubleToString(detectedProfit, 2));
      return(true);
   }

   int err = GetLastError();
   Print("OrderClose failed #", ticket,
         " | Error ", err,
         " | ", reason);
   return(false);
}

//+------------------------------------------------------------------+
void CloseRecoveryBasketsAtTP()
{
   if(!InpCloseRecoveryBasketAtTP) return;
   if(InpTakeProfitUSD <= 0.0) return;

   int recoveryTickets[100];
   int recoveryCount = 0;

   // Collect tickets first because closing orders changes OrdersTotal().
   for(int i = 0; i < OrdersTotal() && recoveryCount < 100; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      recoveryTickets[recoveryCount] = OrderTicket();
      recoveryCount++;
   }

   for(int r = 0; r < recoveryCount; r++)
   {
      int recoveryTicket = recoveryTickets[r];

      if(!IsMyOpenMarketOrder(recoveryTicket)) continue;

      string recoveryComment = OrderComment();
      int recoveryType = OrderType();
      double recoveryProfit = OrderProfit() +
                              OrderSwap() +
                              OrderCommission();

      int parentTicket = GetRecoveryParentTicket(recoveryComment);
      if(parentTicket <= 0) continue;
      if(!IsMyOpenMarketOrder(parentTicket)) continue;
      if(OrderType() != recoveryType) continue;
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double parentProfit = OrderProfit() +
                            OrderSwap() +
                            OrderCommission();
      double basketProfit = parentProfit + recoveryProfit;

      if(basketProfit + 0.0000001 < InpTakeProfitUSD)
         continue;

      string side = (recoveryType == OP_BUY) ? "BUY" : "SELL";
      string reason = "Recovery basket " + side +
                      " TP $" + DoubleToString(InpTakeProfitUSD, 2) +
                      " | Basket $" + DoubleToString(basketProfit, 2);

      // Close the original first to remove its stop-loss exposure,
      // then close the linked recovery order immediately afterward.
      bool parentClosed = CloseOrderByTicket(parentTicket,
                                             reason + " | ORIGINAL",
                                             parentProfit);
      bool recoveryClosed = CloseOrderByTicket(recoveryTicket,
                                               reason + " | RECOVERY",
                                               recoveryProfit);

      if(parentClosed && recoveryClosed)
      {
         string recoveryKey = RecoveryBOSKey(parentTicket);
         if(GlobalVariableCheck(recoveryKey))
            GlobalVariableDel(recoveryKey);

         g_lastStatus = reason + " | Both closed";
      }
      else if(parentClosed || recoveryClosed)
      {
         g_lastStatus = reason + " | Partial close; retrying remaining order";
      }
      else
      {
         g_lastStatus = reason + " | Close failed";
      }
   }
}

//+------------------------------------------------------------------+
bool GetRecoveryBasketInfo(double &basketProfit,
                           int &parentTicket,
                           int &recoveryTicket)
{
   basketProfit = 0.0;
   parentTicket = -1;
   recoveryTicket = -1;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;
      if(!IsRecoveryOrderComment(OrderComment())) continue;

      int selectedRecoveryTicket = OrderTicket();
      int selectedRecoveryType = OrderType();
      double recoveryProfit = OrderProfit() +
                              OrderSwap() +
                              OrderCommission();
      int selectedParentTicket = GetRecoveryParentTicket(OrderComment());

      if(!IsMyOpenMarketOrder(selectedParentTicket)) continue;
      if(OrderType() != selectedRecoveryType) continue;
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double parentProfit = OrderProfit() +
                            OrderSwap() +
                            OrderCommission();

      basketProfit = parentProfit + recoveryProfit;
      parentTicket = selectedParentTicket;
      recoveryTicket = selectedRecoveryTicket;
      return(true);
   }

   return(false);
}

//+------------------------------------------------------------------+
bool FindRecoveryParent(int requiredType,
                        int &parentTicket,
                        double &parentProfit,
                        double &rawDifference)
{
   parentTicket = -1;
   parentProfit = 0.0;
   rawDifference = 0.0;

   double largestRawDifference = -1.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != requiredType) continue;

      // Do not build an uncontrolled recovery-on-recovery chain.
      // Only regular orders can act as recovery parents.
      if(IsRecoveryOrderComment(OrderComment())) continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit >= 0.0) continue;

      double adverseRaw = 0.0;

      if(requiredType == OP_BUY)
         adverseRaw = OrderOpenPrice() - Bid;
      else if(requiredType == OP_SELL)
         adverseRaw = Ask - OrderOpenPrice();

      if(adverseRaw < InpRecoveryRawDifference) continue;
      if(RecoveryAlreadyUsedForCurrentBOS(OrderTicket())) continue;

      // When multiple losing parents qualify, recover the order with
      // the largest adverse raw-price distance first.
      if(adverseRaw > largestRawDifference)
      {
         largestRawDifference = adverseRaw;
         parentTicket = OrderTicket();
         parentProfit = profit;
         rawDifference = adverseRaw;
      }
   }

   return(parentTicket > 0);
}

//+------------------------------------------------------------------+
bool TryOpenRecoveryOrder()
{
   if(!InpUseRecoveryOrders) return(false);
   if(!g_bosActive || g_bosDirection == 0) return(false);
   if(InpRecoveryRawDifference <= 0.0) return(false);
   if(InpRecoveryLotSize <= 0.0) return(false);
   if(InpMaxRecoveryOrdersPerDirection <= 0) return(false);

   int requiredType = (g_bosDirection == 1) ? OP_BUY : OP_SELL;

   // Recovery maximum is separate for BUY and SELL directions.
   if(CountRecoveryOrders(requiredType) >=
      InpMaxRecoveryOrdersPerDirection)
   {
      return(false);
   }

   int parentTicket = -1;
   double parentProfit = 0.0;
   double rawDifference = 0.0;

   if(!FindRecoveryParent(requiredType,
                          parentTicket,
                          parentProfit,
                          rawDifference))
   {
      return(false);
   }

   string side = (requiredType == OP_BUY) ? "BUY" : "SELL";
   string orderComment = "BOS_RECOVERY_" + side +
                         "_P" + IntegerToString(parentTicket);

   if(!OpenOrderWithLots(requiredType,
                         InpRecoveryLotSize,
                         orderComment))
   {
      return(false);
   }

   MarkRecoveryUsedForCurrentBOS(parentTicket);

   double entryPrice = (requiredType == OP_BUY) ? Ask : Bid;
   DrawRecoveryArrow(g_bosDirection,
                     entryPrice,
                     TimeCurrent(),
                     parentTicket);

   g_lastStatus = "Recovery " + side +
                  " opened | Parent #" +
                  IntegerToString(parentTicket) +
                  " | Parent P/L $" +
                  DoubleToString(parentProfit, 2) +
                  " | Raw " +
                  DoubleToString(rawDifference, 1);

   Print(g_lastStatus);
   return(true);
}

//+------------------------------------------------------------------+
// Profit logic:
// 1. Fixed stop loss closes at -$5.
// 2. Profit is not closed immediately at InpTakeProfitUSD.
// 3. Peak profit continuously raises the locked level in USD steps.
// 4. Close only after profit starts falling to/below the latest lock.
//
// Example with InpTakeProfitUSD = 1.00:
// Peak $1.xx -> lock $1
// Peak $2.xx -> lock $2
// Peak $3.xx -> lock $3
//+------------------------------------------------------------------+
void CloseByProfitOrLoss()
{
   for(int i = OrdersTotal()-1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();
      double profit = OrderProfit() + OrderSwap() + OrderCommission();

      // While both linked orders are open, do not allow either order's
      // individual profit trail to close it alone. The pair is managed by
      // CloseRecoveryBasketsAtTP(). The fixed emergency SL stays active.
      bool activeRecoveryPair = IsOrderInActiveRecoveryPair(ticket);

      // The pair check changes the selected order, so restore this ticket.
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES)) continue;
      if(OrderCloseTime() != 0) continue;

      double previousProfit = GetTrailValue(ticket, "PREV", profit);
      double peakProfit     = GetTrailValue(ticket, "PEAK", profit);
      double lockedProfit   = GetTrailValue(ticket, "LOCK", 0.0);

      if(profit > peakProfit)
      {
         peakProfit = profit;
         SetTrailValue(ticket, "PEAK", peakProfit);
      }

      bool lockRaised = false;

      if(!activeRecoveryPair &&
         InpTakeProfitUSD > 0.0 &&
         peakProfit >= InpTakeProfitUSD)
      {
         double calculatedLock = MathFloor(
                                    (peakProfit + 0.0000001) /
                                    InpTakeProfitUSD
                                 ) * InpTakeProfitUSD;

         calculatedLock = NormalizeDouble(calculatedLock, 2);

         if(calculatedLock > lockedProfit + 0.0000001)
         {
            lockedProfit = calculatedLock;
            SetTrailValue(ticket, "LOCK", lockedProfit);
            lockRaised = true;

            g_lastStatus = "Profit lock raised to $" +
                           DoubleToString(lockedProfit, 2) +
                           " | Peak $" +
                           DoubleToString(peakProfit, 2);
         }
      }

      bool fixedStopHit = (profit <= -FIXED_STOP_LOSS_USD);

      // A falling tick is required, so touching a new level does not
      // close the order immediately on the same tick.
      bool profitFalling = (profit < previousProfit - 0.0000001);
      bool trailHit = (!activeRecoveryPair &&
                       InpTakeProfitUSD > 0.0 &&
                       !lockRaised &&
                       lockedProfit >= InpTakeProfitUSD &&
                       profitFalling &&
                       profit <= lockedProfit);

      SetTrailValue(ticket, "PREV", profit);

      if(fixedStopHit)
      {
         CloseSelectedOrder("Fixed SL -$" +
                            DoubleToString(FIXED_STOP_LOSS_USD, 2),
                            profit);
      }
      else if(trailHit)
      {
         CloseSelectedOrder("Trailing lock $" +
                            DoubleToString(lockedProfit, 2),
                            profit);
      }
   }
}

//+------------------------------------------------------------------+
bool CloseSelectedOrder(string reason, double detectedProfit)
{
   int ticket = OrderTicket();
   int type   = OrderType();
   double lots = OrderLots();

   RefreshRates();
   double closePrice = (type == OP_BUY) ? Bid : Ask;
   color closeColor  = (type == OP_BUY) ? clrLime : clrRed;

   ResetLastError();
   bool closed = OrderClose(ticket, lots, closePrice,
                            InpSlippage, closeColor);

   if(closed)
   {
      DeleteProfitTrailState(ticket);
      g_lastStatus = reason +
                     " | Closed P/L $" +
                     DoubleToString(detectedProfit, 2);
      Print(g_lastStatus, " | Ticket #", ticket);
      return(true);
   }

   int err = GetLastError();
   g_lastStatus = "OrderClose failed #" +
                  IntegerToString(ticket) +
                  " error " + IntegerToString(err);
   Print(g_lastStatus);
   return(false);
}

//+------------------------------------------------------------------+
string TrailKey(int ticket, string field)
{
   return("EBP_" +
          IntegerToString(AccountNumber()) + "_" +
          IntegerToString(InpMagicNumber) + "_" +
          IntegerToString(ticket) + "_" + field);
}

//+------------------------------------------------------------------+
double GetTrailValue(int ticket, string field, double defaultValue)
{
   string key = TrailKey(ticket, field);

   if(!GlobalVariableCheck(key))
   {
      GlobalVariableSet(key, defaultValue);
      return(defaultValue);
   }

   return(GlobalVariableGet(key));
}

//+------------------------------------------------------------------+
void SetTrailValue(int ticket, string field, double value)
{
   GlobalVariableSet(TrailKey(ticket, field), value);
}

//+------------------------------------------------------------------+
void DeleteProfitTrailState(int ticket)
{
   string keyPrev = TrailKey(ticket, "PREV");
   string keyPeak = TrailKey(ticket, "PEAK");
   string keyLock = TrailKey(ticket, "LOCK");

   if(GlobalVariableCheck(keyPrev)) GlobalVariableDel(keyPrev);
   if(GlobalVariableCheck(keyPeak)) GlobalVariableDel(keyPeak);
   if(GlobalVariableCheck(keyLock)) GlobalVariableDel(keyLock);
}

//+------------------------------------------------------------------+
int CountMyOrders()
{
   int count = 0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;

      if(OrderSymbol() == Symbol() &&
         OrderMagicNumber() == InpMagicNumber &&
         (OrderType() == OP_BUY || OrderType() == OP_SELL))
      {
         count++;
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
void GetOpenOrderTrailInfo(double &currentProfit,
                           double &peakProfit,
                           double &lockedProfit)
{
   currentProfit = 0.0;
   peakProfit    = 0.0;
   lockedProfit  = 0.0;

   for(int i = 0; i < OrdersTotal(); i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(OrderMagicNumber() != InpMagicNumber) continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL) continue;

      int ticket = OrderTicket();
      currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      peakProfit    = GetTrailValue(ticket, "PEAK", currentProfit);
      lockedProfit  = GetTrailValue(ticket, "LOCK", 0.0);
      return;
   }
}

//========================== VISUALS ================================
void UpdateVisuals(bool entryReady, int emaTrend)
{
   DrawEMALine();
   if(g_bosActive) DrawPullbackZone();
   DrawDashboard(entryReady ? "ENTRY READY" : g_lastStatus);
}

//+------------------------------------------------------------------+
void DrawEMALine()
{
   int bars = MathMin(InpEMALineBars, Bars-2);
   DeleteObjectsByPrefix(PFX+"EMA_SEG_");

   for(int i = bars; i >= 1; i--)
   {
      string name = PFX + "EMA_SEG_" + IntegerToString(i);
      double e1 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                      MODE_EMA, PRICE_CLOSE, i);
      double e2 = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                      MODE_EMA, PRICE_CLOSE, i-1);

      ObjectCreate(0, name, OBJ_TREND, 0,
                   Time[i], e1, Time[i-1], e2);
      ObjectSetInteger(0, name, OBJPROP_RAY, false);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   }
}
void DrawBOS(int dir, double level, double bosPrice, datetime t)
{
   // Remove previous BOS lines and labels.
   DeleteObjectsByPrefix(PFX + "BOS_LINE_");
   DeleteObjectsByPrefix(PFX + "BOS_TEXT_");

   string lineName = PFX + "BOS_LINE_CURRENT";
   string textName = PFX + "BOS_TEXT_CURRENT";

   DrawHLine(
      lineName,
      level,
      dir == 1 ? clrLime : clrRed,
      STYLE_SOLID,
      dir == 1 ? "BOS BUY" : "BOS SELL"
   );

   DrawText(
      textName,
      t,
      bosPrice,
      dir == 1 ? "BOS BUY" : "BOS SELL",
      dir == 1 ? clrLime : clrRed
   );
} 

//+------------------------------------------------------------------+
void DrawPullbackZone()
{
   double z1 = 0.0;
   double z2 = 0.0;

   if(g_bosDirection == 1)
   {
      z1 = g_bosPrice - InpPullbackMinRaw;
      z2 = g_bosPrice - InpPullbackMaxRaw;
   }
   else if(g_bosDirection == -1)
   {
      z1 = g_bosPrice + InpPullbackMinRaw;
      z2 = g_bosPrice + InpPullbackMaxRaw;
   }

   if(z1 == 0.0 || z2 == 0.0) return;

   double top = MathMax(z1, z2);
   double bot = MathMin(z1, z2);
   datetime t1 = g_bosTime;
   datetime t2 = TimeCurrent() +
                 PeriodSeconds() * InpPullbackMaxBars;

   string name = PFX + "PULLBACK_ZONE";

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0,
                   t1, top, t2, bot);
   }
   else
   {
      ObjectMove(0, name, 0, t1, top);
      ObjectMove(0, name, 1, t2, bot);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR,
                    g_bosDirection == 1 ?
                    clrPaleGreen : clrMistyRose);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);

   DrawHLine(PFX+"BOS_PRICE", g_bosPrice,
             clrGold, STYLE_DASH, "BOS Price");
}

//+------------------------------------------------------------------+
void DrawEntryArrow(int dir, double price, datetime t)
{
   string name = PFX + "ENTRY_" + IntegerToString((int)t);

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR,
                    dir == 1 ? clrLime : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

   DrawText(PFX+"ENTRY_TEXT_"+IntegerToString((int)t),
            t, price,
            dir == 1 ? "BUY" : "SELL",
            dir == 1 ? clrLime : clrRed);
}

//+------------------------------------------------------------------+
void DrawRecoveryArrow(int dir,
                       double price,
                       datetime t,
                       int parentTicket)
{
   string suffix = IntegerToString((int)t) + "_" +
                   IntegerToString(parentTicket);
   string name = PFX + "RECOVERY_ENTRY_" + suffix;

   ObjectCreate(0, name, OBJ_ARROW, 0, t, price);
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE,
                    dir == 1 ? 233 : 234);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 3);

   DrawText(PFX + "RECOVERY_TEXT_" + suffix,
            t,
            price,
            dir == 1 ? "RECOVERY BUY" : "RECOVERY SELL",
            clrGold);
}

//+------------------------------------------------------------------+
void DrawDashboard(string status)
{
   string dir = "NONE";
   if(g_bosDirection == 1) dir = "BUY";
   if(g_bosDirection == -1) dir = "SELL";

   int emaTrend = GetEMATrend();
   string emaTxt = "FLAT";
   if(emaTrend == 1) emaTxt = "BUY";
   if(emaTrend == -1) emaTxt = "SELL";

   double ema = iMA(Symbol(), Period(), InpEMAPeriod, 0,
                    MODE_EMA, PRICE_CLOSE, 1);

   double pullbackRaw = 0.0;
   if(g_bosActive && g_bosDirection == 1)
      pullbackRaw = g_bosPrice - Bid;
   if(g_bosActive && g_bosDirection == -1)
      pullbackRaw = Ask - g_bosPrice;

   double currentProfit = 0.0;
   double peakProfit = 0.0;
   double lockedProfit = 0.0;
   GetOpenOrderTrailInfo(currentProfit, peakProfit, lockedProfit);

   double recoveryBasketProfit = 0.0;
   int recoveryParentTicket = -1;
   int recoveryTicket = -1;
   bool hasRecoveryBasket = GetRecoveryBasketInfo(recoveryBasketProfit,
                                                  recoveryParentTicket,
                                                  recoveryTicket);

   string txt = "EMA + BOS + PULLBACK EA\n";
   txt += "EMA Trend     : " + emaTxt + "\n";
   txt += "EMA" + IntegerToString(InpEMAPeriod) +
          "         : " + DoubleToString(ema, Digits) + "\n";
   txt += "BOS Direction : " + dir + "\n";
   txt += "BOS Active    : " + BoolText(g_bosActive) + "\n";
   txt += "BOS Price     : " +
          DoubleToString(g_bosPrice, Digits) + "\n";
   txt += "EMA Match     : " +
          BoolText(emaTrend == g_bosDirection &&
                   emaTrend != 0) + "\n";
   txt += "Pullback Raw  : " +
          DoubleToString(pullbackRaw, 1) + " / " +
          DoubleToString(InpPullbackMinRaw, 0) + "-" +
          DoubleToString(InpPullbackMaxRaw, 0) + "\n";
   txt += "Open Orders   : " +
          IntegerToString(CountMyOrders()) + "\n";
   txt += "Recovery Rule : LOSS + BOS SAME DIR\n";
   txt += "Recovery Gap  : " +
          DoubleToString(InpRecoveryRawDifference, 0) + " raw\n";
   txt += "Recovery B/S  : " +
          IntegerToString(CountRecoveryOrders(OP_BUY)) + "/" +
          IntegerToString(CountRecoveryOrders(OP_SELL)) + "\n";
   txt += "Pair Basket TP: $" +
          DoubleToString(InpTakeProfitUSD, 2) + "\n";
   txt += "Pair Basket P/L: " +
          (hasRecoveryBasket ?
           "$" + DoubleToString(recoveryBasketProfit, 2) +
           " | P#" + IntegerToString(recoveryParentTicket) +
           " R#" + IntegerToString(recoveryTicket) :
           "NONE") + "\n";
   txt += "Fixed SL      : -$" +
          DoubleToString(FIXED_STOP_LOSS_USD, 2) + "\n";
   txt += "Profit Step   : $" +
          DoubleToString(InpTakeProfitUSD, 2) + "\n";
   txt += "Current P/L   : $" +
          DoubleToString(currentProfit, 2) + "\n";
   txt += "Peak Profit   : $" +
          DoubleToString(peakProfit, 2) + "\n";
   txt += "Locked Profit : $" +
          DoubleToString(lockedProfit, 2) + "\n";
   txt += "Status        : " + status;

   Comment(txt);
}

//+------------------------------------------------------------------+
void DrawHLine(string name, double price,
               color clr, int style, string desc)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE1, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetString(0, name, OBJPROP_TEXT, desc);
}

//+------------------------------------------------------------------+
void DrawText(string name, datetime t, double price,
              string text, color clr)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectMove(0, name, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
}

//+------------------------------------------------------------------+
string BoolText(bool value)
{
   return(value ? "YES" : "NO");
}

//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   int total = ObjectsTotal(ChartID(), -1, -1);

   for(int i = total-1; i >= 0; i--)
   {
      string name = ObjectName(ChartID(), i, -1, -1);

      if(StringFind(name, prefix, 0) == 0)
         ObjectDelete(ChartID(), name);
   }
}
//+------------------------------------------------------------------+
