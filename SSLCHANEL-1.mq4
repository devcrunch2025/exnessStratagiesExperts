//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - CONTINUOUS EQUITY LADDER             |
//|                  TWO-STAGE PROFIT LADDER | CONTINUOUS RESET RE-ENTRY | LIVE INTRABAR SSL      |
//+------------------------------------------------------------------+
#property strict

// Date	Opening Balance	Day P/L	Closing Balance
// Jul 01, 2026	$100.00	+$26.00	$126.00
// Jul 02, 2026	$126.00	+$2.67	$128.67
// Jul 03, 2026	$128.67	+$3.90	$132.57
// Jul 04, 2026	$132.57	-$0.46	$132.12
// Jul 05, 2026	$132.12	-$4.90	$127.22


// ===== INPUT SETTINGS =====
int SSLPeriod = 10;

// ===== EMA CONFIRMATION FILTER =====
// Optional directional filter for SSL entries.
// BUY  -> price must be above EMA.
// SELL -> price must be below EMA.
bool InpUseEMA200Filter = false;
int  InpEMA200Period = 200;
int  InpEMAPriceShift = 0;   // 0 = live/current candle, 1 = last closed candle
// ===== EMA CHART DISPLAY =====
// Displays the configured EMA directly on the MT4 chart even when the
// EMA trading filter is disabled.
bool ShowEMALine = true;
color EMALineColor = clrGold;
int EMALineWidth = 2;
int EMALineBars = 500;
string EMA_PREFIX = "SSL_EMA_LINE_";


bool EnableTrading = true;
double Lots = 0.01;
int MaxOpenOrders = 100;//20;
int AccountMultiplierLOT=200;
bool CloseOppositeOrdersOnSignal = false;
double closeOppositeLossThreshold =-2;//-0.50;// -10.0;
double OriginalStopLossUSD=2;//10;//5;//0.50;//50;
double StopLossUSD =2;//10;//3;//2;//0.50;// 50;

bool DeleteOppositePendingOnSignal = true;
bool EnableProfitReEntryStop = true;
double MinimumClosedProfitUSD = -9;
double ProfitReEntryGapRaw =25;//5;//20;// 5;
double MinimumSameOrderGapRaw =25;// 100;//10;//50;

// ===== STOP-LOSS / RE-ENTRY SAFETY =====
bool EnableSLProtection = false;
int MaxSameDirectionOrders = 3;
int MaxConsecutiveLosingSL = 2;
int SLCooldownCandles = 3;
double SLReEntryGapRaw = 50.0;
double BasketNewOrderLossLimitUSD = 7.50;
int SLProtectionSafetyBufferPoints = 2;
bool DeletePendingOrdersAfterLosingSL = true;
bool RequireFreshSSLAfterLosingSL = true;
bool ContinueTradingAfterSL = true; // Continue normal signal trading after any losing SL; risk limits remain active
bool EnableFreezeLevelProtection = true;
double MinimumSLModifyGapRaw = 2.0;

bool EnableProfitLadder1 = true;



double Ladder1ProfitUSD =0.20;//0.05;//1;//0.15;//0.25;//0.50;// 0.05;
bool EnableProfitLadder2 = true;
double Ladder1StopMaxPriceUSD = 1;//0.50;//0.20;
double Ladder2ProfitUSD = 0.10;//server api is has errors due to too many orders, so we need to limit the number of orders to 1, and increase the profit target to 0.20






bool EnableRecoveryOrders = false;
double RecoveryTriggerLossUSD = -5.0;
double RecoveryLotMultiplier = 1;
int MaxRecoveryOrders = 1;
double RecoveryBasketProfitUSD = 0.50;
bool EnableDailyLossProtection = false;// false= continue trading even after hit the stoploss  

// ===== DAY-1 CAPITAL PROTECTION EXIT =====
// Independent of the current equity-ladder target.
// If equity is still above the original day-start balance but the
// floating P/L of EA market orders reaches this loss, all EA orders close.
bool EnableDay1CapitalProtectionExit = false;
double ProtectionLossUSD = 50.0;

// Immutable Day-1 protection anchor. This is NOT changed by equity-ladder
// resets or protected-equity resets. It is refreshed only when a new
// trading day starts.
double Day1ProtectionStartBalance = 0.0;
datetime Day1ProtectionDate = 0;
bool ResetDailyProtectionEveryDay = false;
bool CloseOpenOrdersOnDailyLoss = false;
int MinimumClosedOrdersForDailyProtection =10;// 100;
bool EnableEquityLadder = true;
// Close all EA market + pending orders when the equity ladder increments.
// Re-entry after the increment is disabled by default.
bool EnableLadderReEntryAfterIncrement = true;
bool SkipSignalsAfterLadderIncrement = false;





double DailyEquityTargetPercent =5;//5;//5;//2;//3;//5;//10;//5;// 10;//2;//3;//1;//3;//10;//Trading continue with 10% profit reccuring
double DailyLossProtectionPercent =50;//20;//10;//20;//50;//20;//10;//20;//100;//50;// 30.0;// Trading stops if equity drops below this percentage of the starting balance for the day
bool EnableDynamicEquityLadder = true;////Trading continue with 10% profit reccuring
double OriginalDailyEquityTargetPercent =5;//10;//5;// 10;//2;//3;//1;//3;//10;//Trading continue with 10% profit reccuring


double OriginalDailyLossProtectionPercent =50;//20;//10;//20;//10;//80;// 30.0;

bool ResetLadderEveryDay = false;
int EquityLadderLevel = 1;
double NextEquityTarget = 0;
double LockedEquity = 0;
int Slippage = 30;
int MagicNumber = 6600123;

// ===== TICK PERFORMANCE / TRADE REQUEST CONTROL =====
// A failed trade request is never chased on the same tick.
// This limit also prevents a single tick from flooding the broker.
int MaxTradeRequestsPerTick = 5;
int TradeRequestsThisTick = 0;

// Per-tick order-count cache. It removes repeated full OrdersTotal()/OrderSelect()
// scans when several strategy functions only need the current EA-order count.
int CurrentTickSequence = 0;
int CachedTotalEAOrders = -1;
int CachedTotalEAOrdersTick = -1;

// GUI work is throttled so dashboard/chart drawing cannot slow trading.
int DashboardUpdateIntervalMs = 250;
uint LastDashboardUpdateMs = 0;
int EMARedrawIntervalMs = 100;
uint LastEMARedrawMs = 0;
bool EnableTickPerformanceLog = false;
int SlowTickLogThresholdMs = 50;
bool EnableTradeTimingLog = false;
int SlowTradeRequestLogThresholdMs = 50;
bool ShowHistoricalSignals = true;
bool ShowSSLLines = true;
int HistoryBarsToDraw = 500;
bool ShowSignalText = true;
bool ShowSignalArrows = true;
int SignalDistancePoints = 100;
int SignalArrowWidth = 2;
int SignalFontSize = 9;
color BuyColor = clrBlue;
color SellColor = clrRed;
color SSLUpColor = clrLime;
color SSLDownColor = clrRed;
int SSLLineWidth = 2;
bool ShowDashboard = true;
int DashboardRightGap = 300;
int DashboardTopGap = 20;
int DashboardWidth = 285;
int DashboardHeight = 480;
int DashboardFontSize = 9;

// ===== LEFT LIVE ORDERS DASHBOARD =====
bool ShowLeftLiveOrdersDashboard = true;
int LeftDashboardX = 10;
int LeftDashboardY = 20;
int LeftDashboardWidth = 330;
int LeftDashboardMaxRows = 20;

double OriginalLots = 0.01;
double OriginalLadder1ProfitUSD = 0.05;
double OriginalLadder2ProfitUSD = 0.20;
double OriginalLadder1StopMaxPriceUSD = 0.20;

// ===== STATE STRUCTURE =====
struct DailyProtectionState
  {
   datetime          DayDate;
   double            DayStartBalance;
   double            DayProtectedBalance;
   int               ClosedOrdersToday;
   bool              TradingStopped;
   bool              Initialized;
  };

// ===== RUNTIME VARIABLES =====
string PREFIX = "SSL_CROSS_";
string DASH_PREFIX = "SSL_DASHBOARD_";
datetime LastProcessedBar = 0;
datetime LastProcessedClosedOrderTime = 0;
datetime DailyProtectionStartTime = 0;
int LastProcessedClosedTicket = -1;
bool StartupSignalProcessed = false;
bool TradeResetThisTick = false;

//===============================================================
// LIVE SSL INTRABAR STATE
// SSL trading is evaluated on the currently forming candle (0).
//===============================================================
bool LiveSSLInitialized = false;
int LastLiveSSLDirection = 1;//0;
datetime LastLiveSignalCandle = 1;//0;

// Persistent request to start a fresh trade after an Equity Ladder reset.
// It remains TRUE until a market order is successfully opened.
bool EquityResetReEntryPending = true;

//===============================================================
// PROTECTED EQUITY RE-ENTRY DELAY
//===============================================================
bool ProtectedEquityWaitActive = true;
datetime ProtectedEquityWaitStartTime = 0;
int ProtectedEquityWaitMinutes =0;// 60;



//+------------------------------------------------------------------+
void InitializeEquityLadder(DailyProtectionState &state)
  {
   LockedEquity = state.DayStartBalance;

   NextEquityTarget =
      state.DayStartBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DRAW / UPDATE EMA LINE ON CHART                                   |
//+------------------------------------------------------------------+
void ClearEMALineObjects()
  {
   for(int i=ObjectsTotal()-1; i>=0; i--)
     {
      string name=ObjectName(i);
      if(StringFind(name,EMA_PREFIX,0)==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateEMALineOnChart()
  {
   if(!ShowEMALine || Bars < InpEMA200Period + 2)
      return;

   int barsToDraw=EMALineBars;
   if(barsToDraw<2)
      barsToDraw=2;
   if(barsToDraw>Bars-1)
      barsToDraw=Bars-1;

   static datetime lastDrawnBar=0;
   bool rebuild=(lastDrawnBar!=Time[0]);

   uint emaNow=GetTickCount();
   if(!rebuild && LastEMARedrawMs!=0 &&
      (uint)(emaNow-LastEMARedrawMs)<(uint)MathMax(0,EMARedrawIntervalMs))
      return;

// Build the historical EMA segments only when a new candle appears.
// On every tick, update the live segment so EMA(0) follows price.
   if(rebuild)
     {
      ClearEMALineObjects();

      for(int i=barsToDraw-1; i>=0; i--)
        {
         int j=i+1;
         if(j>=Bars)
            continue;

         double ema1=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,i);
         double ema2=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,j);
         if(ema1<=0 || ema2<=0)
            continue;

         string name=EMA_PREFIX+IntegerToString(i);
         if(!ObjectCreate(0,name,OBJ_TREND,0,Time[j],ema2,Time[i],ema1))
            continue;

         ObjectSetInteger(0,name,OBJPROP_COLOR,EMALineColor);
         ObjectSetInteger(0,name,OBJPROP_WIDTH,EMALineWidth);
         ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
         ObjectSetInteger(0,name,OBJPROP_RAY,false);
         ObjectSetInteger(0,name,OBJPROP_BACK,false);
         ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
         ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
        }

      lastDrawnBar=Time[0];
     }

// Always update the newest segment with the live EMA value.
   double ema0=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,0);
   double ema1=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,1);
   string liveName=EMA_PREFIX+"0";

   if(ema0>0 && ema1>0 && ObjectFind(0,liveName)>=0)
     {
      ObjectMove(0,liveName,0,Time[1],ema1);
      ObjectMove(0,liveName,1,Time[0],ema0);
     }

   uint now=GetTickCount();
   if(LastEMARedrawMs==0 ||
      (uint)(now-LastEMARedrawMs)>=(uint)MathMax(0,EMARedrawIntervalMs))
     {
      LastEMARedrawMs=now;
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//| PROCESS STARTUP SIGNAL                                            |
//| IMPORTANT: NEVER CLOSE EXISTING ORDERS ON EA RESTART             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| EMA directional confirmation                                     |
//+------------------------------------------------------------------+
bool PassesEMAFilter(int orderType)
  {
   if(!InpUseEMA200Filter)
      return true;

   if(Bars < InpEMA200Period + 5)
     {
      Print("EMA FILTER BLOCKED | Not enough bars. Required: ",
            InpEMA200Period + 5, " | Available: ", Bars);
      return false;
     }

   if(orderType != OP_BUY && orderType != OP_SELL)
      return false;

   int shift = InpEMAPriceShift;
   if(shift < 0)
      shift = 0;
   if(shift >= Bars)
      shift = Bars - 1;

   double ema = iMA(Symbol(), Period(), InpEMA200Period, 0,
                    MODE_EMA, PRICE_CLOSE, shift);

   if(ema <= 0.0)
     {
      Print("EMA FILTER BLOCKED | Invalid EMA value");
      return false;
     }

   RefreshRates();

   double price = (shift == 0)
                  ? ((orderType == OP_BUY) ? Ask : Bid)
                  : Close[shift];

   bool allowed = (orderType == OP_BUY)
                  ? (price > ema)
                  : (price < ema);

   Print("EMA FILTER | ",
         orderType == OP_BUY ? "BUY" : "SELL",
         " | Price=", DoubleToString(price, Digits),
         " | EMA(", InpEMA200Period, ")=", DoubleToString(ema, Digits),
         " | ", allowed ? "PASS" : "BLOCK");

   return allowed;
  }

//+------------------------------------------------------------------+
//| DRAW / UPDATE EMA LINE ON CHART                                   |
//+------------------------------------------------------------------+
void ClearEMALineObjects11()
  {
   for(int i=ObjectsTotal()-1; i>=0; i--)
     {
      string name=ObjectName(i);
      if(StringFind(name,EMA_PREFIX,0)==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateEMALineOnChart11()
  {
   if(!ShowEMALine)
      return;

   if(Bars < InpEMA200Period + 2)
      return;

   int barsToDraw=EMALineBars;
   if(barsToDraw<2)
      barsToDraw=2;
   if(barsToDraw>Bars-1)
      barsToDraw=Bars-1;

// Rebuild the EMA segments. This keeps the line synchronized with the
// live candle and with chart scrolling/timeframe changes.
   ClearEMALineObjects();

   for(int i=barsToDraw-1; i>=0; i--)
     {
      int j=i+1;
      if(j>=Bars)
         continue;

      double ema1=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,i);
      double ema2=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,j);
      if(ema1<=0 || ema2<=0)
         continue;

      string name=EMA_PREFIX+IntegerToString(i);
      if(!ObjectCreate(0,name,OBJ_TREND,0,Time[j],ema2,Time[i],ema1))
         continue;

      ObjectSetInteger(0,name,OBJPROP_COLOR,EMALineColor);
      ObjectSetInteger(0,name,OBJPROP_WIDTH,EMALineWidth);
      ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
      ObjectSetInteger(0,name,OBJPROP_RAY,false);
      ObjectSetInteger(0,name,OBJPROP_BACK,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
      ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
     }

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| PROCESS STARTUP SIGNAL                                            |
//| IMPORTANT: NEVER CLOSE EXISTING ORDERS ON EA RESTART             |
//+------------------------------------------------------------------+
void ProcessStartupSignal(DailyProtectionState &dailyState)
  {
   if(StartupSignalProcessed)
      return;

   if(Bars < SSLPeriod + 20)
      return;

// Mark processed BEFORE any trading action
   StartupSignalProcessed = true;

   int currentDirection = GetCurrentSSLDirection();

   bool buySignal  = (currentDirection > 0);
   bool sellSignal = (currentDirection < 0);

   Print("==================================================");
   Print("EA STARTUP / RESTART SIGNAL RECOVERY");
   Print("Current SSL Direction: ",
         buySignal ? "BUY" :
         sellSignal ? "SELL" : "NONE");
   Print("Existing EA Orders   : ", GetTotalEAOrders());
   Print("IMPORTANT: EXISTING ORDERS WILL NOT BE CLOSED");
   Print("==================================================");

//===============================================================
// BUY
//===============================================================
   if(buySignal)
     {
      DrawLiveSignal(0, true);

      // IMPORTANT:
      // Do NOT delete opposite pending orders on startup.
      // Do NOT close opposite market orders on startup.

      if(EnableTrading &&
         !IsDailyTradingStopped(dailyState) &&
         GetTotalEAOrders() < MaxOpenOrders &&
         PassesEMAFilter(OP_BUY))
        {
         OpenBuy();

         Print("EA RESTART -> BUY SIGNAL PROCESSED");
         Print("EA RESTART -> EXISTING ORDERS PRESERVED");
        }
      else
        {
         Print("EA RESTART BUY BLOCKED");
        }

      return;
     }

//===============================================================
// SELL
//===============================================================
   if(sellSignal)
     {
      DrawLiveSignal(0, false);

      // IMPORTANT:
      // Do NOT delete opposite pending orders on startup.
      // Do NOT close opposite market orders on startup.

      if(EnableTrading &&
         !IsDailyTradingStopped(dailyState) &&
         GetTotalEAOrders() < MaxOpenOrders &&
         PassesEMAFilter(OP_SELL))
        {
         OpenSell();

         Print("EA RESTART -> SELL SIGNAL PROCESSED");
         Print("EA RESTART -> EXISTING ORDERS PRESERVED");
        }
      else
        {
         Print("EA RESTART SELL BLOCKED");
        }

      return;
     }

   Print("EA RESTART -> NO VALID SSL DIRECTION");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool EAStartupComplete = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   Ladder1StopMaxPriceUSD=Ladder1ProfitUSD*2;

   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;
   OriginalLadder1StopMaxPriceUSD = Ladder1StopMaxPriceUSD;
   OriginalDailyEquityTargetPercent = DailyEquityTargetPercent;
   OriginalDailyLossProtectionPercent = DailyLossProtectionPercent;




   OriginalStopLossUSD = StopLossUSD;

   Print("========== SSL CHANNEL CROSS EA - FIXED VERSION V1- Final Version ==========");
   Print("Symbol: ", Symbol(), " | Timeframe: ", TimeframeToString(Period()), " | SSL Period: ", SSLPeriod);
   Print("Lots: ", DoubleToString(Lots, 2), " | Max Orders: ", MaxOpenOrders);
   Print("EMA Filter: ", InpUseEMA200Filter ? "ON" : "OFF",
         " | Period: ", InpEMA200Period,
         " | Price Shift: ", InpEMAPriceShift,
         " | Mode: ", InpEMAPriceShift == 0 ? "LIVE" : "CLOSED CANDLE");
   Print("Daily Protection: ", EnableDailyLossProtection ? "ON" : "OFF", " | Ladder 1: ", EnableProfitLadder1 ? "ON" : "OFF");
   Print("Ladder 1 Step: $", DoubleToString(Ladder1ProfitUSD, 2), " | Ladder 2 Step: $", DoubleToString(Ladder2ProfitUSD, 2));
   Print("Continue After SL: ",ContinueTradingAfterSL?"YES":"NO");
   Print("SL Protection: ",EnableSLProtection?"ON":"OFF",
         " | MaxSameDirection=",MaxSameDirectionOrders,
         " | MaxConsecutiveLossSL=",MaxConsecutiveLosingSL,
         " | CooldownCandles=",SLCooldownCandles,
         " | BasketLossLimit=$",DoubleToString(BasketNewOrderLossLimitUSD,2));
   Print("=========================================================");

   DeleteOurObjects();
   DeleteDashboardObjects();
   DeleteLeftLiveOrdersDashboardObjects();
   if(ShowHistoricalSignals || ShowSSLLines)
      DrawHistoricalSignals();

// Display the configured EMA on the chart.
   UpdateEMALineOnChart();

   DailyProtectionStartTime = TimeCurrent();
   InitializeLastProcessedClosedOrder();
   // Do not treat an old historical loss as a new SL event immediately after restart.
   LastProtectedLossTicket = LastProcessedClosedTicket;
   LoadReEntryCounter();
   return INIT_SUCCEEDED;
  }

datetime LastOrderCandleTime = 0;
bool OrderCreatedThisCandle = false;
bool IsOneCandleOrderAllowed()
  {
   if(Time[0] != LastOrderCandleTime)
     {
      LastOrderCandleTime = Time[0];
      OrderCreatedThisCandle = false;
     }

   if(OrderCreatedThisCandle)
     {
      Print("ORDER BLOCKED | Already opened on current candle");
      return false;
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) { DeleteOurObjects(); DeleteDashboardObjects(); DeleteLeftLiveOrdersDashboardObjects(); ClearEMALineObjects(); }
int StartupProtectionTicks = 0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| DAY-1 CAPITAL PROTECTION EXIT                                    |
//|                                                                  |
//| Example:                                                        |
//| Day Start Balance = $100                                         |
//| Current Balance  = $150                                         |
//| Current Equity   = $110                                         |
//| Floating P/L     = -$40                                          |
//| ProtectionLossUSD= $25                                           |
//|                                                                  |
//| Equity is still above the original day-start balance, but the    |
//| floating loss has reached the protection threshold.              |
//| Therefore ALL EA market/pending orders are closed.               |
//|                                                                  |
//| This check is completely independent of NextEquityTarget.         |
//+------------------------------------------------------------------+
double GetEAFloatingPL()
  {
   double floatingPL = 0.0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int type = OrderType();

      if(type==OP_BUY || type==OP_SELL)
         floatingPL += OrderProfit() + OrderSwap() + OrderCommission();
     }

   return floatingPL;
  }

//+------------------------------------------------------------------+
//| Close every open EA order for this symbol/magic                  |
//+------------------------------------------------------------------+
bool CloseAllEAOrdersForDay1Protection()
  {
   bool allClosed = true;

   RefreshRates();

// Delete pending orders first.
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int type = OrderType();

      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP &&
         type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;

      int ticket = OrderTicket();

      if(!SafeOrderDelete(ticket, clrNONE))
        {
         allClosed = false;
         Print("DAY-1 PROTECTION | PENDING DELETE FAILED | Ticket=",ticket);
        }
     }

// Close market orders.
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int marketType = OrderType();

      if(marketType!=OP_BUY && marketType!=OP_SELL)
         continue;

      int marketTicket = OrderTicket();
      double closeLots = OrderLots();

      if(!SafeOrderClose(marketTicket,
                         closeLots,
                         marketType,
                         Slippage,
                         clrNONE))
        {
         allClosed = false;

         Print("DAY-1 PROTECTION | MARKET CLOSE FAILED | Ticket=",
               marketTicket, " | Lots=", DoubleToString(closeLots,2));
        }
      else
        {
         Print("DAY-1 PROTECTION | CLOSED | Ticket=",marketTicket);
        }
     }

   return allClosed;
  }

//+------------------------------------------------------------------+
//| Independent Day-1 capital protection check                      |
//+------------------------------------------------------------------+
bool CheckDay1CapitalProtectionExit(DailyProtectionState &state)
  {
   if(!EnableDay1CapitalProtectionExit)
      return false;

   if(ProtectionLossUSD <= 0.0)
      return false;

   if(!state.Initialized)
      return false;

   if(state.TradingStopped)
      return false;

// IMPORTANT: use a separate immutable Day-1 anchor.
// The normal daily/equity-ladder code can change state.DayStartBalance
// after a reset. That must NEVER change this protection reference.
   datetime todayDate = StrToTime(TimeToString(TimeCurrent(), TIME_DATE));
   if(Day1ProtectionDate != todayDate || Day1ProtectionStartBalance <= 0.0)
     {
      Day1ProtectionDate = todayDate;
      if(Day1ProtectionDate != state.DayDate)
      Day1ProtectionStartBalance = AccountBalance();
      Print("DAY-1 PROTECTION ANCHOR SET | Balance=$",
            DoubleToString(Day1ProtectionStartBalance,2),
            " | Date=", TimeToString(Day1ProtectionDate,TIME_DATE));
     }

   double dayStartBalance = Day1ProtectionStartBalance;
   double currentEquity   = AccountEquity();
   double floatingPL      = GetEAFloatingPL();

// Required conditions:
// 1. Equity must still be ABOVE the original day-start balance.
// 2. EA floating P/L must be <= negative ProtectionLossUSD.
   if(currentEquity <= dayStartBalance)
      return false;

   if(floatingPL > -ProtectionLossUSD)
      return false;

   Print("================================================");
   Print("DAY-1 CAPITAL PROTECTION EXIT TRIGGERED");
   Print("Day Start Balance : $", DoubleToString(dayStartBalance,2));
   Print("Current Balance   : $", DoubleToString(AccountBalance(),2));
   Print("Current Equity    : $", DoubleToString(currentEquity,2));
   Print("Floating P/L      : $", DoubleToString(floatingPL,2));
   Print("Loss Threshold    : -$", DoubleToString(ProtectionLossUSD,2));
   Print("Current Ladder    : $", DoubleToString(NextEquityTarget,2));
   Print("Action            : CLOSE ALL EA ORDERS");
   Print("================================================");

   bool closed = CloseAllEAOrdersForDay1Protection();

// This is an EXIT, not a ladder reset.
// Preserve the original DayStartBalance so the protection remains
// anchored to the beginning-of-day capital.
   if(closed)
     {
      state.TradingStopped = true;

      // Cancel any queued ladder re-entry. Otherwise the continuous
      // ladder could immediately open a fresh trade after this exit.
      EquityResetReEntryPending = false;
      ProtectedEquityWaitActive = false;

      Print("DAY-1 CAPITAL PROTECTION | ALL EA ORDERS CLOSED");
      Print("DAY-1 CAPITAL PROTECTION | TRADING STOPPED FOR CURRENT DAY");
     }
   else
     {
      // Keep the protection active so failed closes are retried on the
      // next tick rather than allowing normal ladder processing.
      Print("DAY-1 CAPITAL PROTECTION | SOME ORDERS REMAIN OPEN - RETRYING");
     }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessPendingReEntry(DailyProtectionState &state)
  {
   if(!ReEntryRetryPending)
      return;

   if(!EnableTrading || IsDailyTradingStopped(state))
      return;

   Print("RETRYING PENDING RE-ENTRY | Counter=",reEntryCounter,
         " | Next #",reEntryCounter+1);

   CreateProfitReEntryStop(ReEntryRetryClosedType,
                           ReEntryRetryClosedPrice,
                           state);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   uint tickStartMs=GetTickCount();
   OnTickCore();
   OnTickPerformanceEnd(tickStartMs);
  }

void OnTickCore()
  {
   CurrentTickSequence++;
   CachedTotalEAOrders=-1;
   CachedTotalEAOrdersTick=-1;

   // A new OnTick means a new retry window. Failed trade requests from
   // the previous tick may be attempted now with fresh market data.
   ResetTradeErrorRetryGuards();
   ResetTradeRequestBudget();
   RefreshRates();

//    if(EquityLadderLevel>1)
//    {
//       DailyLossProtectionPercent =5;// AccountBalance();
// OriginalDailyLossProtectionPercent =5;//
//    }

   TradeResetThisTick = false;

//===============================================================
// STARTUP SAFETY
//===============================================================
   if(StartupProtectionTicks < 1)
     {
      StartupProtectionTicks++;

      EAStartupComplete = true;

      Print("==================================================");
      Print("FIRST TICK AFTER EA START");
      Print("Existing orders will be PRESERVED");
      Print("No startup opposite-order closing allowed");
      Print("==================================================");
     }
// else
// {
//    Ladder1ProfitUSD = OriginalLadder1ProfitUSD;
// }
   static DailyProtectionState dailyState;
   TradeResetThisTick = false;

   if(!dailyState.Initialized)
      InitializeDailyProtectionState(dailyState);

//===============================================================
// SERVER ERROR SELF-TEST / RECOVERY
// A trade-server error on the previous tick is checked first.
// If the next tick is abnormal, reset transient EA runtime state.
//===============================================================
   if(ProcessServerRecovery(dailyState))
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      UpdateDashboardsThrottled(dailyState);
      return;
     }

//===============================================================
// DAY-1 CAPITAL PROTECTION EXIT
// Run this BEFORE the normal daily/equity-ladder reset logic so the
// protection remains completely independent of ladder changes.
//===============================================================
   if(CheckDay1CapitalProtectionExit(dailyState))
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      UpdateDashboardsThrottled(dailyState);
      return;
     }

// Normal daily-loss protection is evaluated only after the independent
// Day-1 capital protection check.
   UpdateDailyLossProtection(dailyState);

   CheckLatestClosedTradeProtection();

//===============================================================
// PROTECTED EQUITY WAIT - NO NEW TRADING DURING COOLDOWN
//===============================================================
   if(IsProtectedEquityWaiting())
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   CheckRecoveryOrders();
   ManageRecoveryBasket();

   ProcessStartupSignal(dailyState);
   CheckDynamicEquityLadder(dailyState);

// Continuous Equity Ladder re-entry.
// Uses CURRENT SSL direction; no new crossover is required.
// If an order cannot be opened now, the request remains pending.
   if(EquityResetReEntryPending)
      ProcessEquityResetReEntry(dailyState);

   if(ShowSSLLines)
      UpdateSSLChannelOnTick();
   UpdateEMALineOnChart();

   // Retry a ReEntry that failed because of a trade/server error.
   // This happens independently of the already-processed history ticket.
   if(!TradeResetThisTick)
      ProcessPendingReEntry(dailyState);

   if(Bars >= SSLPeriod + 20 && !TradeResetThisTick)
      CheckForProfitableClosedOrder(dailyState);
   if(EnableProfitLadder1 || EnableProfitLadder2)
      ManageProfitLadder();
   // UI is deliberately throttled; trading logic remains tick-by-tick.
   UpdateDashboardsThrottled(dailyState);

   if(Bars < SSLPeriod + 20)
      return;

//===============================================================
// LIVE SSL CROSS - CURRENT FORMING CANDLE
//===============================================================
// No new-bar wait here. IsLiveBuySignal()/IsLiveSellSignal()
// evaluate candle 0 on every tick. This allows the EA to enter
// immediately when the SSL channel crosses during the candle.
// IsOneCandleOrderAllowed() prevents more than one successful
// normal market order from being opened on the same candle.
//===============================================================
   bool buySignal  = IsLiveBuySignal();
   bool sellSignal = IsLiveSellSignal();

   if(buySignal)
     {
      DrawLiveSignal(0, true);

      // Avoid repeated processing on every tick while the same live
      // cross remains active.
      if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != 1)
        {
         LastLiveSignalCandle = Time[0];
         LastLiveSSLDirection = 1;

         Print("LIVE SSL CROSS -> BUY | CURRENT FORMING CANDLE");

         if(FreshSSLRequiredDirection == -1) FreshSSLRequiredDirection = 0;

         if(DeleteOppositePendingOnSignal)
            DeleteOppositePendingOrders(OP_BUY);
         if(CloseOppositeOrdersOnSignal)
            CloseOppositeOrders(OP_BUY);

         if(EnableTrading && !IsDailyTradingStopped(dailyState))
           {
            if(GetTotalEAOrders() < MaxOpenOrders)
               OpenBuy();
            else
               Print("BUY BLOCKED | MAX ORDERS");
           }
         else
            Print("BUY BLOCKED | DAILY PROTECTION");
        }
     }
   else
      if(sellSignal)
        {
         DrawLiveSignal(0, false);

         if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != -1)
           {
            LastLiveSignalCandle = Time[0];
            LastLiveSSLDirection = -1;

            Print("LIVE SSL CROSS -> SELL | CURRENT FORMING CANDLE");

            if(FreshSSLRequiredDirection == 1) FreshSSLRequiredDirection = 0;

            if(DeleteOppositePendingOnSignal)
               DeleteOppositePendingOrders(OP_SELL);
            if(CloseOppositeOrdersOnSignal)
               CloseOppositeOrders(OP_SELL);

            if(EnableTrading && !IsDailyTradingStopped(dailyState))
              {
               if(GetTotalEAOrders() < MaxOpenOrders)
                  OpenSell();
               else
                  Print("SELL BLOCKED | MAX ORDERS");
              }
            else
               Print("SELL BLOCKED | DAILY PROTECTION");
           }
        }

  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasMinimumSameOrderGap(int orderType)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;
      if(MathAbs(currentPrice - OrderOpenPrice()) < MinimumSameOrderGapRaw)
        {
         Print("NEW ", orderType == OP_BUY ? "BUY" : "SELL", " BLOCKED | Order within ", DoubleToString(MathAbs(currentPrice - OrderOpenPrice()), Digits), " raw");
         return false;
        }
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetOpenPL(int OrderTypeFilter)
  {
   double OpenPL = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() == OrderTypeFilter)
         OpenPL += OrderProfit() + OrderSwap() + OrderCommission();
     }
   return OpenPL;
  }
//+------------------------------------------------------------------+
// Find highest profit order and adjust Ladder1
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Open Orders Count by Type                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Open Market Orders Count                                     |
//+------------------------------------------------------------------+
double GetOppositeOrdersLots(int orderType)
  {
// double totalLots = 0.0;
   double totalLots = 0.01;


   int oppositeType =
      (orderType == OP_BUY)
      ? OP_SELL
      : OP_BUY;

   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol())
         continue;

      if(OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderType() != oppositeType)
         continue;

      totalLots += OrderLots();
     }

   if(totalLots <= 0.0)
      return NormalizeLots(OriginalLots);

   return NormalizeLots(totalLots);
  }
  int reEntryCounter=0;

//===============================================================
// RE-ENTRY / SERVER RECOVERY SAFETY
//===============================================================
bool ServerRecoveryPending = false;
int  ServerRecoveryLastError = 0;
datetime ServerRecoveryDetectedTime = 0;
int ServerRecoveryResetCount = 0;
int ServerRecoveryMaxRetries = 5;
int ServerRecoveryRetryDelayMs = 400;
string ReEntryGVPrefix = "SSL_REENTRY_";
bool ReEntryRetryPending = false;
int ReEntryRetryClosedType = -1;
double ReEntryRetryClosedPrice = 0.0;

int LosingSLCount = 0;
int LastProtectedLossTicket = -1;
int BlockedSLDirection = 0;
int FreshSSLRequiredDirection = 0;
datetime SLProtectionUntil = 0;


// Return the lot required for a successful ReEntry number.
// #1 = 0.01, #2 = 0.10, #3 = 0.09 ... #10 = 0.02, #11+ = 0.01.
//0.03
double GetReEntryLot(int reEntryNumber)
  {
   if(reEntryNumber <=1)
      return NormalizeLots(0.02);
if(reEntryNumber <=2)
      return NormalizeLots(0.03);
     // if(reEntryNumber <= 10)
      return NormalizeLots(0.10);

      //  if(reEntryNumber > 5)
      // return NormalizeLots(0.01);



   double lot = 0.12 - (reEntryNumber * 0.01);
   if(lot < 0.01)
      lot = 0.01;

   return NormalizeLots(lot);
  }

// Persistent counter protects the sequence across an EA refresh/restart.
// It is only restored when an existing Profit ReEntry order is present.
string GetReEntryGVName()
  {
   return ReEntryGVPrefix + IntegerToString(AccountNumber()) + "_" +
          IntegerToString(MagicNumber) + "_" + Symbol();
  }

bool HasExistingProfitReEntryOrder()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      string c=OrderComment();
      if(StringFind(c,"SSL Profit ReEntry",0)==0)
         return true;
     }
   return false;
  }

void LoadReEntryCounter()
  {
   string gv=GetReEntryGVName();

   if(HasExistingProfitReEntryOrder() && GlobalVariableCheck(gv))
      reEntryCounter=(int)GlobalVariableGet(gv);
   else
     {
      reEntryCounter=0;
      GlobalVariableSet(gv,0.0);
     }

   Print("REENTRY SEQUENCE LOADED | Counter=",reEntryCounter,
         " | Next Lot=",DoubleToString(GetReEntryLot(reEntryCounter+1),2));
  }

void SaveReEntryCounter()
  {
   GlobalVariableSet(GetReEntryGVName(),(double)reEntryCounter);
  }

//---------------------------------------------------------------
// Server error classification.
// Temporary execution errors are retried. Any trade-operation
// error also activates the self-test watchdog.
//---------------------------------------------------------------
bool IsRetryableTradeError(int err)
  {
   switch(err)
     {
      case 4:   // ERR_SERVER_BUSY
      case 6:   // ERR_NO_CONNECTION
      case 128: // ERR_TRADE_TIMEOUT
      case 135: // ERR_PRICE_CHANGED
      case 136: // ERR_OFF_QUOTES
      case 137: // ERR_BROKER_BUSY
      case 138: // ERR_REQUOTE
      case 146: // ERR_TRADE_CONTEXT_BUSY
         return true;
     }
   return false;
  }

bool IsInvalidStopError(int err)
  {
   return (err == 130);
  }

double GetRequiredStopDistance()
  {
   double stopPts = MarketInfo(Symbol(),MODE_STOPLEVEL);
   double freezePts = 0.0;
   if(EnableFreezeLevelProtection)
      freezePts = MarketInfo(Symbol(),MODE_FREEZELEVEL);
   double requiredPts = MathMax(stopPts,freezePts) + SLProtectionSafetyBufferPoints;
   if(requiredPts < 1.0) requiredPts = 1.0;
   return requiredPts * Point;
  }

bool PrepareStopLossForOrder(int orderType,double referencePrice,double &stopLoss)
  {
   if(stopLoss <= 0.0) return true;
   RefreshRates();
   double minDistance=GetRequiredStopDistance();
   if(orderType==OP_BUY || orderType==OP_BUYSTOP)
     {
      double maxSL=Bid-minDistance;
      if(orderType==OP_BUYSTOP) maxSL=MathMin(maxSL,referencePrice-minDistance);
      if(maxSL<=0.0) return false;
      if(stopLoss>maxSL) stopLoss=maxSL;
     }
   else if(orderType==OP_SELL || orderType==OP_SELLSTOP)
     {
      double minSL=Ask+minDistance;
      if(orderType==OP_SELLSTOP) minSL=MathMax(minSL,referencePrice+minDistance);
      if(minSL<=0.0) return false;
      if(stopLoss<minSL) stopLoss=minSL;
     }
   else return true;
   stopLoss=NormalizeDouble(stopLoss,Digits);
   if(orderType==OP_BUY || orderType==OP_BUYSTOP)
     {
      if(stopLoss<=0.0 || stopLoss>=Bid) return false;
      if(orderType==OP_BUYSTOP && stopLoss>=referencePrice) return false;
     }
   else
     {
      if(stopLoss<=Ask) return false;
      if(orderType==OP_SELLSTOP && stopLoss<=referencePrice) return false;
     }
   return true;
  }

bool IsDirectionBlockedAfterSL(int orderType)
  {
   // User setting: a stop-loss must NOT stop normal trading.
   // Other safety limits (basket loss / max orders / server recovery) remain active.
   if(ContinueTradingAfterSL) return false;
   if(!EnableSLProtection) return false;
   int dir=(orderType==OP_BUY)?1:-1;
   if(SLProtectionUntil>TimeCurrent() && BlockedSLDirection==dir) return true;
   if(RequireFreshSSLAfterLosingSL && FreshSSLRequiredDirection==dir) return true;
   return false;
  }

bool HasBasketNewOrderLossLimit()
  {
   if(!EnableSLProtection || BasketNewOrderLossLimitUSD<=0.0) return false;
   double basket=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      basket += OrderProfit()+OrderSwap()+OrderCommission();
     }
   return basket<=-BasketNewOrderLossLimitUSD;
  }

int CountDirectionOrders(int orderType)
  {
   int count=0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderType()==orderType) count++;
     }
   return count;
  }

bool IsSafeToCreateMarketOrder(int orderType)
  {
   if(!EnableSLProtection) return true;
   if(!IsConnected()) return false;
   if(HasBasketNewOrderLossLimit())
     {
      Print("NEW ORDER BLOCKED | Basket floating loss limit reached");
      return false;
     }
   if(MaxSameDirectionOrders>0 && CountDirectionOrders(orderType)>=MaxSameDirectionOrders)
     {
      Print("NEW ORDER BLOCKED | Max same-direction orders reached | Direction=",orderType);
      return false;
     }
   if(IsDirectionBlockedAfterSL(orderType))
     {
      Print("NEW ORDER BLOCKED | Losing-SL protection | Direction=",orderType,
            " | LosingSLCount=",LosingSLCount);
      return false;
     }
   return true;
  }

void DeleteAllPendingEAOrders()
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
      {
 // Pending order age
      // int ageSeconds = (int)(TimeCurrent() - OrderOpenTime());
      // // Delete only if pending order is 1 hour or older
      // if(ageSeconds >= 3600)
      {
         SafeOrderDelete(OrderTicket(),clrRed);
      }

      }
     }
  }

void RegisterLosingSLProtection(int ticket,int orderType,double profit)
  {
   if(!EnableSLProtection || ticket<=0 || profit>=0.0 || ticket==LastProtectedLossTicket) return;
   LastProtectedLossTicket=ticket;
   LosingSLCount++;
   BlockedSLDirection=(orderType==OP_BUY)?1:-1;
   FreshSSLRequiredDirection=BlockedSLDirection;
   SLProtectionUntil=TimeCurrent()+MathMax(0,SLCooldownCandles)*Period()*60;
   Print("LOSING TRADE PROTECTION | Ticket=",ticket,
         " | Direction=",(orderType==OP_BUY?"BUY":"SELL"),
         " | Loss=$",DoubleToString(profit,2),
         " | ConsecutiveLosses=",LosingSLCount,
         " | CooldownUntil=",TimeToString(SLProtectionUntil,TIME_DATE|TIME_SECONDS));
   if(DeletePendingOrdersAfterLosingSL && !ContinueTradingAfterSL) DeleteAllPendingEAOrders();
  }

void RegisterProfitableClose()
  {
   LosingSLCount=0;
   BlockedSLDirection=0;
   SLProtectionUntil=0;
  }

void CheckLatestClosedTradeProtection()
  {
   if(!EnableSLProtection) return;
   datetime latest=0; int ticket=-1,type=-1; double profit=0.0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL) continue;
      if(OrderCloseTime()>latest)
        {
         latest=OrderCloseTime(); ticket=OrderTicket(); type=OrderType();
         profit=OrderProfit()+OrderSwap()+OrderCommission();
        }
     }
   if(ticket<0) return;
   static int lastSeenProtectionTicket=-1;
   if(ticket==lastSeenProtectionTicket) return;
   lastSeenProtectionTicket=ticket;
   if(profit<0.0) RegisterLosingSLProtection(ticket,type,profit);
   else if(profit>0.0) RegisterProfitableClose();
  }

void MarkServerError(int err,string operation)
  {
   ServerRecoveryPending=true;
   ServerRecoveryLastError=err;
   ServerRecoveryDetectedTime=TimeCurrent();

   Print("==================================================");
   Print("SERVER/TRADE ERROR WATCHDOG");
   Print("Operation : ",operation);
   Print("Error    : ",err);
   Print("Recovery : NEXT TICK SELF-TEST");
   Print("==================================================");
  }

bool IsTradeEnvironmentHealthy()
  {
   if(!IsConnected())
      return false;

   RefreshRates();

   if(Bid<=0 || Ask<=0)
      return false;

   // For a running market, MT4 must allow trading.
   if(!IsTradeAllowed())
      return false;

   return true;
  }

// Reset only transient EA runtime state. Existing broker orders,
// the ReEntry sequence and processed-history markers are preserved.
void ResetRuntimeAfterServerError(DailyProtectionState &state)
  {
   Print("==================================================");
   Print("EA SERVER RECOVERY RESET");
   Print("Existing orders will be PRESERVED");
   Print("ReEntry counter preserved: ",reEntryCounter);
   Print("Open EA orders: ",GetTotalEAOrders());
   Print("==================================================");

   RefreshRates();

   TradeResetThisTick=false;
   OrderCreatedThisCandle=false;
   LastOrderCandleTime=0;
   StartupProtectionTicks=0;
   EAStartupComplete=true;

   // Re-read the daily state from the current account/order reality
   // without changing the configured input settings.
   state.ClosedOrdersToday=CountClosedOrdersSinceInitialization();

   // Rebuild the SSL live state from the current market.
   LiveSSLInitialized=false;
   LastLiveSSLDirection=GetCurrentSSLDirection();
   LastLiveSignalCandle=Time[0];

   // Rebuild equity ladder reference from the current protected state
   // only if its current values are invalid.
   if(NextEquityTarget<=0 || LockedEquity<=0)
      InitializeEquityLadder(state);

   // Do not reset reEntryCounter. Restore it from terminal storage.
   if(HasExistingProfitReEntryOrder())
      LoadReEntryCounter();

   ServerRecoveryResetCount++;
   ServerRecoveryPending=false;
   ServerRecoveryLastError=0;
  }

// Called at the beginning of each tick after a trade-server error.
// The next tick is tested first. A healthy next tick simply clears
// recovery mode; an unhealthy tick causes a controlled runtime reset.
bool ProcessServerRecovery(DailyProtectionState &state)
  {
   if(!ServerRecoveryPending)
      return false;

   Print("SERVER RECOVERY TEST | Last error=",ServerRecoveryLastError,
         " | Tick=",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS));

   if(IsTradeEnvironmentHealthy())
     {
      Print("SERVER RECOVERY TEST PASSED | Trading environment is normal | "
            "NEXT TICK CONTINUES - failed order operation may retry with latest prices");
      ServerRecoveryPending=false;
      ServerRecoveryLastError=0;

      // IMPORTANT:
      // Do not consume/skip this tick. This IS the first retry opportunity.
      // The calling logic will refresh/recalculate its order parameters.
      return false;
     }

   Print("SERVER RECOVERY TEST FAILED | Resetting EA runtime state");
   ResetRuntimeAfterServerError(state);
   return true;
  }

// Find an order which was actually created even though MT4 returned
// an execution error/timeout. This prevents duplicate orders.
int FindExistingOrderForRequest(int orderType,double lots,double price,
                                string orderComment,datetime requestTime)
  {
   double priceTolerance=MathMax(Point*20.0,Point*Slippage*2.0);

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(OrderType()!=orderType)
         continue;
      if(MathAbs(OrderLots()-lots)>0.0000001)
         continue;
      if(OrderComment()!=orderComment)
         continue;
      if(OrderOpenTime()+3<requestTime)
         continue;

      if(orderType==OP_BUY || orderType==OP_SELL)
        {
         if(MathAbs(OrderOpenPrice()-price)<=priceTolerance)
            return OrderTicket();
        }
      else
        {
         if(MathAbs(OrderOpenPrice()-price)<=MathMax(Point,priceTolerance))
            return OrderTicket();
        }
     }

   return -1;
  }


//===============================================================
// FAST TICK / TRADE REQUEST BUDGET
//===============================================================
void ResetTradeRequestBudget()
  {
   TradeRequestsThisTick=0;
  }

bool CanSendTradeRequest(string operation,string details="")
  {
   if(MaxTradeRequestsPerTick<=0)
      return true;

   if(TradeRequestsThisTick>=MaxTradeRequestsPerTick)
     {
      Print("TRADE REQUEST BUDGET REACHED | Operation=",operation,
            " | RequestsThisTick=",TradeRequestsThisTick,
            " | Limit=",MaxTradeRequestsPerTick,
            " | Action=wait next tick | ",details);
      return false;
     }

   TradeRequestsThisTick++;
   return true;
  }

//===============================================================
// THROTTLED UI UPDATE
//===============================================================
void UpdateDashboardsThrottled(DailyProtectionState &state,bool force=false)
  {
   uint now=GetTickCount();
   if(!force && LastDashboardUpdateMs!=0 &&
      (uint)(now-LastDashboardUpdateMs)<(uint)MathMax(0,DashboardUpdateIntervalMs))
      return;

   LastDashboardUpdateMs=now;

   if(ShowDashboard)
      UpdateDashboard(state);
   if(ShowLeftLiveOrdersDashboard)
      UpdateLeftLiveOrdersDashboard();
  }

//===============================================================
// PERFORMANCE TIMING HELPERS
//===============================================================
void LogTradeTiming(string operation,uint startedMs)
  {
   if(!EnableTradeTimingLog)
      return;
   uint elapsed=GetTickCount()-startedMs;
   if((int)elapsed>=SlowTradeRequestLogThresholdMs)
      Print("SLOW TRADE REQUEST | ",operation,
            " | ElapsedMs=",elapsed,
            " | RequestsThisTick=",TradeRequestsThisTick);
  }

void OnTickPerformanceEnd(uint startedMs)
  {
   if(!EnableTickPerformanceLog)
      return;
   uint elapsed=GetTickCount()-startedMs;
   if((int)elapsed>=SlowTickLogThresholdMs)
      Print("SLOW EA TICK | ElapsedMs=",elapsed,
            " | TradeRequestsThisTick=",TradeRequestsThisTick,
            " | Bid=",DoubleToString(Bid,Digits),
            " | Ask=",DoubleToString(Ask,Digits));
  }

//===============================================================
// NEXT-TICK TRADE ERROR GUARD
// Every failed trade request is recorded for the current OnTick.
// The same request is NEVER chased again during that tick.
// On the next OnTick the guard is cleared and the caller gets a
// fresh opportunity using the latest market/order state.
//===============================================================
string TradeErrorBlockedKeys[200];
int TradeErrorBlockedCount=0;

void ResetTradeErrorRetryGuards()
  {
   TradeErrorBlockedCount=0;
  }

string MakeTradeErrorKey(string operation,int ticket,string extra)
  {
   return operation+"|"+IntegerToString(ticket)+"|"+extra;
  }

bool IsTradeErrorBlockedThisTick(string key)
  {
   for(int i=0;i<TradeErrorBlockedCount;i++)
      if(TradeErrorBlockedKeys[i]==key)
         return true;
   return false;
  }

void BlockTradeErrorUntilNextTick(string key)
  {
   if(IsTradeErrorBlockedThisTick(key))
      return;

   if(TradeErrorBlockedCount<200)
     {
      TradeErrorBlockedKeys[TradeErrorBlockedCount]=key;
      TradeErrorBlockedCount++;
     }
  }

void LogTradeOperationError(string operation,int ticket,string details,int err)
  {
   Print("==================================================");
   Print("TRADE OPERATION FAILED - RETRY NEXT TICK");
   Print("Operation : ",operation);
   if(ticket>0)
      Print("Ticket    : ",ticket);
   
   Print("Symbol    : ",Symbol());
   Print("Bid       : ",DoubleToString(Bid,Digits));
   Print("Ask       : ",DoubleToString(Ask,Digits));
   Print("Details   : ",details);
   Print("Action    : NO SAME-TICK RETRY");
   Print("Next     : Refresh latest tick and retry");
   Print("==================================================");
  }

// Safe OrderSend with retry + duplicate detection.
// Safe OrderSend: one broker request per failed request per tick.
// A failure is recorded; no Sleep()/same-tick retry is performed.
// The next tick retries with fresh Bid/Ask.
int SafeOrderSend(string symbol,int orderType,double lots,double price,
                  int slippage,double stopLoss,double takeProfit,
                  string comment,int magic,color arrowColor)
  {
   string key=MakeTradeErrorKey("SEND",-1,
                                 IntegerToString(orderType)+"|"+
                                 DoubleToString(lots,8)+"|"+comment);

   if(IsTradeErrorBlockedThisTick(key))
     {
      Print("OrderSend SKIPPED - previous failure this tick | ",
            "Type=",orderType," | Lots=",DoubleToString(lots,2),
            " | Comment=",comment,
            " | Action=wait next tick");
      return -1;
     }

   RefreshRates();

   double sendPrice=price;
   if(orderType==OP_BUY)
      sendPrice=Ask;
   else if(orderType==OP_SELL)
      sendPrice=Bid;

   sendPrice=NormalizeDouble(sendPrice,Digits);

   double safeSL=stopLoss;
   if(safeSL>0.0 && !PrepareStopLossForOrder(orderType,sendPrice,safeSL))
     {
      BlockTradeErrorUntilNextTick(key);
      LogTradeOperationError("OrderSend",-1,
         "Unsafe initial SL | Type="+IntegerToString(orderType)+
         " | Lots="+DoubleToString(lots,2)+
         " | Price="+DoubleToString(sendPrice,Digits)+
         " | RequestedSL="+DoubleToString(stopLoss,Digits)+
         " | Comment="+comment,130);
      MarkServerError(130,"OrderSend/unsafe-SL");
      return -1;
     }

   datetime requestTime=TimeCurrent();

   if(!CanSendTradeRequest("OrderSend",comment))
      return -1;

   ResetLastError();
   uint tradeStartMs=GetTickCount();
   int ticket=OrderSend(symbol,orderType,lots,sendPrice,slippage,
                        safeSL,takeProfit,comment,magic,0,arrowColor);
   LogTradeTiming("OrderSend",tradeStartMs);

   if(ticket>0)
     {
      InvalidateTotalEAOrdersCache();
      return ticket;
     }

   int err=GetLastError();

   // The broker can execute the request while the client receives
   // a timeout/connection error. Always check actual broker state.
   int existing=FindExistingOrderForRequest(orderType,lots,sendPrice,
                                             comment,requestTime);
   if(existing>0)
     {
      Print("ORDER SEND AMBIGUOUS RESULT | Existing ticket found: ",
            existing," | Original error=",err);
      ServerRecoveryPending=false;
      return existing;
     }

   BlockTradeErrorUntilNextTick(key);

   LogTradeOperationError("OrderSend",-1,
      "Type="+IntegerToString(orderType)+
      " | Lots="+DoubleToString(lots,2)+
      " | RequestedPrice="+DoubleToString(sendPrice,Digits)+
      " | SL="+DoubleToString(safeSL,Digits)+
      " | Comment="+comment,err);

   MarkServerError(err,"OrderSend");
   return -1;
  }



// Safe OrderClose. If the order disappeared after an error, it is
// considered successfully closed because the broker state is authoritative.
// Safe OrderClose: one broker request per ticket per tick.
// Any failure is logged and deferred to the next tick.
bool SafeOrderClose(int ticket,double lots,int orderType,int slippage,color arrowColor)
  {
   string key=MakeTradeErrorKey("CLOSE",ticket,"");

   if(IsTradeErrorBlockedThisTick(key))
     {
      Print("OrderClose SKIPPED - previous failure this tick | Ticket=",
            ticket," | Action=wait next tick");
      return false;
     }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))
         return true;

      BlockTradeErrorUntilNextTick(key);
      LogTradeOperationError("OrderClose",ticket,
         "Order no longer in active trades/history could not be selected",0);
      return false;
     }

   RefreshRates();

   double closePrice=(OrderType()==OP_BUY)?Bid:Ask;
   closePrice=NormalizeDouble(closePrice,Digits);

   if(!CanSendTradeRequest("OrderClose","Ticket="+IntegerToString(ticket)))
      return false;

   ResetLastError();
   uint tradeStartMs=GetTickCount();
   bool result=OrderClose(ticket,OrderLots(),closePrice,slippage,arrowColor);
   LogTradeTiming("OrderClose",tradeStartMs);

   if(result)
     {
      InvalidateTotalEAOrdersCache();
      return true;
     }

   int err=GetLastError();

   // Verify broker state before deciding it failed.
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))
         return true;
     }

   BlockTradeErrorUntilNextTick(key);

   LogTradeOperationError("OrderClose",ticket,
      "Type="+IntegerToString(orderType)+
      " | Lots="+DoubleToString(lots,2)+
      " | ClosePrice="+DoubleToString(closePrice,Digits),err);

   MarkServerError(err,"OrderClose");
   return false;
  }



// Safe OrderModify with strict SL validation and error classification.
// Prevent repeated OrderModify() attempts for the same ticket on the same tick.
// A failed modification is recorded and the caller must wait for a fresh tick,
// then recalculate the SL using the latest Bid/Ask before trying again.
bool WasOrderModifyAttemptedThisTick(int ticket)
  {
   static int  attemptTickets[100];
   static uint attemptTicks[100];
   static int  attemptCount=0;

   uint thisTick=GetTickCount();

   for(int i=0;i<attemptCount;i++)
     {
      if(attemptTickets[i]==ticket && attemptTicks[i]==thisTick)
         return true;
     }

   if(attemptCount<100)
     {
      attemptTickets[attemptCount]=ticket;
      attemptTicks[attemptCount]=thisTick;
      attemptCount++;
     }
   else
     {
      // Reuse a slot when the small runtime history is full.
      int slot=(int)(thisTick%100);
      attemptTickets[slot]=ticket;
      attemptTicks[slot]=thisTick;
     }

   return false;
  }

// Safe OrderModify: one broker request per ticket per tick.
// Any failure is logged with complete order/market details and deferred
// to the next tick. The caller must recalculate the requested SL/TP then.
bool SafeOrderModify(int ticket,double openPrice,double stopLoss,
                     double takeProfit,datetime expiration,color arrowColor)
  {
   string key=MakeTradeErrorKey("MODIFY",ticket,"");

   if(IsTradeErrorBlockedThisTick(key))
     {
      Print("OrderModify SKIPPED - previous failure this tick | Ticket=",
            ticket," | Action=wait next tick");
      return false;
     }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      BlockTradeErrorUntilNextTick(key);
      LogTradeOperationError("OrderModify",ticket,
         "Order could not be selected from active trades",0);
      return false;
     }

   int orderType=OrderType();

   RefreshRates();

   double requestedSL=stopLoss;

   if(requestedSL>0.0)
     {
      if(!PrepareStopLossForOrder(orderType,OrderOpenPrice(),requestedSL))
        {
         BlockTradeErrorUntilNextTick(key);
         LogTradeOperationError("OrderModify",ticket,
            "Unsafe SL at current tick | Type="+IntegerToString(orderType)+
            " | Lots="+DoubleToString(OrderLots(),2)+
            " | Open="+DoubleToString(OrderOpenPrice(),Digits)+
            " | ExistingSL="+DoubleToString(OrderStopLoss(),Digits)+
            " | RequestedSL="+DoubleToString(stopLoss,Digits),130);
         MarkServerError(130,"OrderModify/unsafe-SL");
         return false;
        }

      if(orderType==OP_BUY && OrderStopLoss()>0.0 &&
         requestedSL<=OrderStopLoss())
        {
         Print("OrderModify DEFERRED | BUY SL cannot improve at current tick | ",
               "Ticket=",ticket,
               " | ExistingSL=",DoubleToString(OrderStopLoss(),Digits),
               " | RequestedSL=",DoubleToString(requestedSL,Digits),
               " | Bid=",DoubleToString(Bid,Digits),
               " | Action=retry next tick with fresh calculation");
         BlockTradeErrorUntilNextTick(key);
         return false;
        }

      if(orderType==OP_SELL && OrderStopLoss()>0.0 &&
         requestedSL>=OrderStopLoss())
        {
         Print("OrderModify DEFERRED | SELL SL cannot improve at current tick | ",
               "Ticket=",ticket,
               " | ExistingSL=",DoubleToString(OrderStopLoss(),Digits),
               " | RequestedSL=",DoubleToString(requestedSL,Digits),
               " | Ask=",DoubleToString(Ask,Digits),
               " | Action=retry next tick with fresh calculation");
         BlockTradeErrorUntilNextTick(key);
         return false;
        }
     }

   bool sameSL=(requestedSL<=0.0 && OrderStopLoss()<=0.0) ||
               (requestedSL>0.0 &&
                MathAbs(OrderStopLoss()-requestedSL)<=MinimumSLModifyGapRaw*Point);
   bool sameTP=(takeProfit<=0.0 && OrderTakeProfit()<=0.0) ||
               (takeProfit>0.0 &&
                MathAbs(OrderTakeProfit()-takeProfit)<=Point);

   if(sameSL && sameTP)
      return true;

   ResetLastError();

   // EXACTLY ONE broker request for this ticket on this tick.
   if(!CanSendTradeRequest("OrderModify","Ticket="+IntegerToString(ticket)))
      return false;

   uint tradeStartMs=GetTickCount();
   bool modified=OrderModify(ticket,openPrice,requestedSL,
                              takeProfit,expiration,arrowColor);
   LogTradeTiming("OrderModify",tradeStartMs);

   if(modified)
     {
      Print("OrderModify SUCCESS | Ticket=",ticket,
            " | Type=",orderType,
            " | Lots=",DoubleToString(OrderLots(),2),
            " | NewSL=",DoubleToString(requestedSL,Digits),
            " | Bid=",DoubleToString(Bid,Digits),
            " | Ask=",DoubleToString(Ask,Digits));
      return true;
     }

   int err=GetLastError();

   BlockTradeErrorUntilNextTick(key);

   LogTradeOperationError("OrderModify",ticket,
      "Type="+IntegerToString(orderType)+
      " | Lots="+DoubleToString(OrderLots(),2)+
      " | Open="+DoubleToString(OrderOpenPrice(),Digits)+
      " | ExistingSL="+DoubleToString(OrderStopLoss(),Digits)+
      " | RequestedSL="+DoubleToString(requestedSL,Digits)+
      " | TP="+DoubleToString(takeProfit,Digits)+
      " | StopLevelPts="+DoubleToString(MarketInfo(Symbol(),MODE_STOPLEVEL),0)+
      " | FreezeLevelPts="+DoubleToString(MarketInfo(Symbol(),MODE_FREEZELEVEL),0),
      err);

   MarkServerError(err,"OrderModify");
   return false;
  }


bool ReducePendingOrderLotTo01()
{
   int ticket = OrderTicket();

   if(ticket <= 0)
      return false;

   int type = OrderType();

   // Only pending orders
   if(type != OP_BUYLIMIT &&
      type != OP_SELLLIMIT &&
      type != OP_BUYSTOP &&
      type != OP_SELLSTOP)
      return false;

   double oldLot       = OrderLots();
   double openPrice    = OrderOpenPrice();
   double stopLoss     = OrderStopLoss();
   double takeProfit   = OrderTakeProfit();
   datetime expiration = OrderExpiration();
   string comment      = OrderComment();

   // Only reduce orders greater than 0.02
   if(oldLot <= 0.02)
      return true;

   double newLot = 0.01;

   Print("REDUCING PENDING LOT | Ticket=", ticket,
         " | OldLot=", DoubleToString(oldLot, 2),
         " | NewLot=", DoubleToString(newLot, 2),
         " | Price=", DoubleToString(openPrice, Digits),
         " | SL=", DoubleToString(stopLoss, Digits),
         " | TP=", DoubleToString(takeProfit, Digits));

   // Delete original pending order. One broker request only.
   string deleteKey=MakeTradeErrorKey("REDUCE_DELETE",ticket,"");
   if(IsTradeErrorBlockedThisTick(deleteKey))
      return false;

   if(!CanSendTradeRequest("OrderDelete/ReduceLot","Ticket="+IntegerToString(ticket)))
      return false;

   ResetLastError();
   uint tradeStartMs=GetTickCount();
   bool reducedDelete=OrderDelete(ticket, clrLimeGreen);
   LogTradeTiming("OrderDelete/ReduceLot",tradeStartMs);
   if(!reducedDelete)
   {
      int errDelete=GetLastError();
      BlockTradeErrorUntilNextTick(deleteKey);
      LogTradeOperationError("OrderDelete/ReduceLot",ticket,
         "OldLot="+DoubleToString(oldLot,2)+
         " | NewLot=0.01"+
         " | OpenPrice="+DoubleToString(openPrice,Digits),errDelete);
      MarkServerError(errDelete,"OrderDelete/ReduceLot");
      return false;
   }

   InvalidateTotalEAOrdersCache();
   RefreshRates();

   // Recreate with 0.01 lot using all existing order parameters
   string sendKey=MakeTradeErrorKey("REDUCE_SEND",-1,
                                    IntegerToString(ticket)+"|"+comment);
   if(IsTradeErrorBlockedThisTick(sendKey))
      return false;

   if(!CanSendTradeRequest("OrderSend/ReduceLot","OldTicket="+IntegerToString(ticket)))
      return false;

   ResetLastError();
   tradeStartMs=GetTickCount();

   int newTicket = OrderSend(
      Symbol(),
      type,
      newLot,
      openPrice,
      0,
      stopLoss,
      takeProfit,
      comment,
      MagicNumber,
      expiration,
      clrLimeGreen
   );
   LogTradeTiming("OrderSend/ReduceLot",tradeStartMs);

   if(newTicket < 0)
   {
      int errSend=GetLastError();
      BlockTradeErrorUntilNextTick(sendKey);
      LogTradeOperationError("OrderSend/ReduceLot",-1,
         "OldTicket="+IntegerToString(ticket)+
         " | NewLot=0.01"+
         " | OpenPrice="+DoubleToString(openPrice,Digits)+
         " | Comment="+comment,errSend);
      MarkServerError(errSend,"OrderSend/ReduceLot");
      return false;
   }

   InvalidateTotalEAOrdersCache();

   Print("PENDING LOT REDUCED SUCCESSFULLY | OldTicket=", ticket,
         " | NewTicket=", newTicket,
         " | OldLot=", DoubleToString(oldLot, 2),
         " | NewLot=0.01");

   return true;
}
// Delete a pending order for equity-ladder/daily reset.
// The global pending-order rule applies here too: pending orders
// younger than 6 hours must remain active.
// ForceDeletePendingOrder: same next-tick rule as every other
// trade operation. The 6-hour pending-order rule remains intact.
bool ForceDeletePendingOrder(int ticket,color arrowColor)
  {
   string key=MakeTradeErrorKey("FORCE_DELETE",ticket,"");

   if(IsTradeErrorBlockedThisTick(key))
     {
      Print("ForceOrderDelete SKIPPED - previous failure this tick | Ticket=",
            ticket," | Action=wait next tick");
      return false;
     }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true;

   int type=OrderType();
   if(type!=OP_BUYSTOP && type!=OP_SELLSTOP &&
      type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
      return false;

   int ageSeconds=(int)(TimeCurrent()-OrderOpenTime());
   if(ageSeconds < 6*60*60)
     {
      Print("Pending order kept | Ticket=",ticket,
            " | Age=",DoubleToString(ageSeconds/3600.0,2),
            " hours | Required=6.00 hours");
      return false;
     }

   ResetLastError();
   uint tradeStartMs=GetTickCount();
   bool result=OrderDelete(ticket,arrowColor);
   LogTradeTiming("OrderDelete",tradeStartMs);

   if(result)
      return true;

   int err=GetLastError();

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true;

   BlockTradeErrorUntilNextTick(key);

   LogTradeOperationError("ForceOrderDelete",ticket,
      "Type="+IntegerToString(type)+
      " | Lots="+DoubleToString(OrderLots(),2)+
      " | OpenPrice="+DoubleToString(OrderOpenPrice(),Digits),err);

   MarkServerError(err,"ForceOrderDelete");
   return false;
  }




// Safe OrderDelete: one broker request per ticket per tick.
// Pending-order business rules remain unchanged.
bool SafeOrderDelete(int ticket,color arrowColor)
  {
   string key=MakeTradeErrorKey("DELETE",ticket,"");

   if(IsTradeErrorBlockedThisTick(key))
     {
      Print("OrderDelete SKIPPED - previous failure this tick | Ticket=",
            ticket," | Action=wait next tick");
      return false;
     }

   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true; // Already deleted.

   int ageSeconds=(int)(TimeCurrent()-OrderOpenTime());
   if(ageSeconds < 6*60*60)
     {
      Print("Pending order kept | Ticket=",ticket,
            " | Age=",DoubleToString(ageSeconds/3600.0,2),
            " hours | Required=6.00 hours");
      return false;
     }

   if(OrderLots()>0.02)
      ReducePendingOrderLotTo01();

   if(!CanSendTradeRequest("OrderDelete","Ticket="+IntegerToString(ticket)))
      return false;

   ResetLastError();
   bool result=OrderDelete(ticket,arrowColor);

   if(result)
      return true;

   int err=GetLastError();

   // If it disappeared, deletion actually succeeded.
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true;

   BlockTradeErrorUntilNextTick(key);

   LogTradeOperationError("OrderDelete",ticket,
      "Pending type="+IntegerToString(OrderType())+
      " | Lots="+DoubleToString(OrderLots(),2)+
      " | OpenPrice="+DoubleToString(OrderOpenPrice(),Digits),err);

   MarkServerError(err,"OrderDelete");
   return false;
  }



//0.03
void ChangeLots(double OpenPL, string reason, int orderType,int stoplevelStep)
  {

//    Final logic implemented
// Reason / condition	Lot
// SSL Profit ReEntry Buy Stop	0.06
// SSL Profit ReEntry Sell Stop	0.06
// SSL Long + opposite orders	0.02
// SSL Short + opposite orders	0.02
// SSL Long + no opposite	0.01
// SSL Short + no opposite	0.01
// Non-SSL + no opposite	0.03
// Non-SSL + opposite + OpenPL < -0.50	0.03
// Non-SSL + opposite + OpenPL >= -0.50	OriginalLots
   //==================================================
   // MAX LOT LIMIT
   //==================================================
   double MaxRecoveryLot = 0.20;

   //==================================================
   // OPPOSITE TYPE TOTAL LOTS
   //==================================================
   double oppositeLots = GetOppositeOrdersLots(orderType);

   //==================================================
   // IDENTIFY SSL SIGNAL
   //==================================================
   bool isSSLSignal =
      (reason == "SSL Long" ||
       reason == "SSL Short");

   //==================================================
   // IDENTIFY SSL PROFIT RE-ENTRY
   //==================================================
   bool isSSLProfitReEntry =
      (reason == "SSL Profit ReEntry Buy Stop" ||
       reason == "SSL Profit ReEntry Sell Stop");

   //==================================================
   // DEFAULT
   //==================================================
   Lots = NormalizeLots(OriginalLots);


   //==================================================
   // TYPE 1
   // SSL PROFIT RE-ENTRY
   //
   // ALWAYS = 0.10
   //
   // BUY STOP / SELL STOP
   
   //==================================================
   if(isSSLProfitReEntry)
     {
      // ReEntry sequence:
      // #1=0.01, #2=0.10, #3=0.09 ... #10=0.02, #11+=0.01.
      // The counter advances ONLY after a successful OrderSend.
      int nextReEntryNumber = reEntryCounter + 1;
      Lots = GetReEntryLot(nextReEntryNumber);

      Print("========================================");
      Print("SSL PROFIT RE-ENTRY");
      Print("ReEntry Number  : #", nextReEntryNumber);
      Print("Reason          : ", reason);
      Print("Open P/L        : $",
            DoubleToString(OpenPL, 2));
      Print("Opposite Lots   : ",
            DoubleToString(oppositeLots, 2));
      Print("New Lots        : ",
            DoubleToString(Lots, 2));
      Print("========================================");
     }


   //==================================================
   // TYPE 2
   // NORMAL SSL SIGNAL
   //
   // SSL LONG / SSL SHORT
   //
   // WITH OPPOSITE ORDERS    = 0.01
   // WITHOUT OPPOSITE ORDERS = 0.05
   //==================================================
   else
      if(isSSLSignal)
        {
         if(oppositeLots > 0.0)
           {
            //=========================================
            // SSL WITH OPPOSITE ORDERS
            //=========================================
            Lots = NormalizeLots(0.01); //0.05 is danger if market is moving continuous down with small ups and downs 

            Print("========================================");
            Print("SSL SIGNAL - OPPOSITE ORDERS");
            Print("Reason          : ", reason);
            Print("Open P/L        : $",
                  DoubleToString(OpenPL, 2));
            Print("Opposite Lots   : ",
                  DoubleToString(oppositeLots, 2));
            Print("New Lots        : ",
                  DoubleToString(Lots, 2));
            Print("========================================");
           }
         else
           {
            //=========================================
            // SSL WITHOUT OPPOSITE ORDERS
            //=========================================
            Lots = NormalizeLots(0.01); //0.05 is danger if market is moving continuous down with small ups and downs 

            Print("========================================");
            Print("SSL SIGNAL - NO OPPOSITE ORDERS");
            Print("Reason          : ", reason);
            Print("Open P/L        : $",
                  DoubleToString(OpenPL, 2));
            Print("Opposite Lots   : 0.00");
            Print("New Lots        : ",
                  DoubleToString(Lots, 2));
            Print("========================================");
           }
        }


   //==================================================
   // TYPE 3
   // NON SSL SIGNAL
   //
   // NO OPPOSITE ORDERS = 0.03
   //
   // OPPOSITE ORDERS + LOSS < -0.50 = 0.03
   //
   // OTHERWISE = OriginalLots
   //==================================================
      else
        {
         if(oppositeLots <= 0.0)
           {
            //=========================================
            // NO OPPOSITE ORDERS
            //=========================================
            Lots = NormalizeLots(0.03);

            Print("========================================");
            Print("NO OPPOSITE ORDERS");
            Print("Reason          : ", reason);
            Print("Open P/L        : $",
                  DoubleToString(OpenPL, 2));
            Print("Opposite Lots   : 0.00");
            Print("New Lots        : ",
                  DoubleToString(Lots, 2));
            Print("========================================");
           }
         else
            if(OpenPL < -0.50)
              {
               //======================================
               // OPPOSITE ORDERS + LOSS > $0.50
               //======================================
               Lots = NormalizeLots(0.03);

               Print("========================================");
               Print("OPPOSITE ORDERS - LOSS RECOVERY");
               Print("Reason          : ", reason);
               Print("Open P/L        : $",
                     DoubleToString(OpenPL, 2));
               Print("Opposite Lots   : ",
                     DoubleToString(oppositeLots, 2));
               Print("New Lots        : ",
                     DoubleToString(Lots, 2));
               Print("========================================");
              }
            else
              {
               //======================================
               // OPPOSITE ORDERS BUT LOSS <= $0.50
               //======================================
               Lots = NormalizeLots(OriginalLots);

               Print("========================================");
               Print("OPPOSITE ORDERS - NORMAL");
               Print("Reason          : ", reason);
               Print("Open P/L        : $",
                     DoubleToString(OpenPL, 2));
               Print("Opposite Lots   : ",
                     DoubleToString(oppositeLots, 2));
               Print("New Lots        : ",
                     DoubleToString(Lots, 2));
               Print("========================================");
              }
        }



 int balancelomultipler =
   (int)(AccountBalance() / AccountMultiplierLOT);

if(balancelomultipler < 1)
   balancelomultipler = 1;

Lots = Lots * balancelomultipler;
   //==================================================
   // HARD MAX LOT
   //==================================================
   if(Lots > MaxRecoveryLot)
     {
      Print("MAX LOT LIMIT APPLIED");
      Print("Calculated Lot : ",
            DoubleToString(Lots, 2));
      Print("Maximum Lot    : ",
            DoubleToString(MaxRecoveryLot, 2));

      Lots = NormalizeLots(MaxRecoveryLot);
     }


   //==================================================
   // FINAL NORMALIZATION
   //==================================================
   Lots = NormalizeLots(Lots);


 

// Lots = NormalizeLots(Lots);

   //==================================================
   // ACTUAL LOT MULTIPLIER
   //==================================================
   double lotMultiplier = 1.0;

   if(oppositeLots > 0.0)
     {
      lotMultiplier =
         Lots / oppositeLots;
     }

   if(lotMultiplier < 1.0)
      lotMultiplier = 1.0;


   //==================================================
   // SCALE SL / ORDER LADDER
   // BASED ON ACTUAL NEW LOT
   //==================================================
   StopLossUSD =
      OriginalStopLossUSD *
      Lots * 100;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD *
      Lots * 100;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD *
      Lots * 100;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD *
      Lots * 100;


   //==================================================
   // FINAL DEBUG
   //==================================================
   Print("========================================");
   Print("FINAL LOT CONFIGURATION");
   Print("Reason          : ", reason);
   Print("Open P/L        : $",
         DoubleToString(OpenPL, 2));
   Print("Opposite Lots   : ",
         DoubleToString(oppositeLots, 2));
   Print("New Lots        : ",
         DoubleToString(Lots, 2));
   Print("Maximum Lot     : ",
         DoubleToString(MaxRecoveryLot, 2));
   Print("Lot Multiplier  : ",
         DoubleToString(lotMultiplier, 2), "X");
   Print("Stop Loss       : $",
         DoubleToString(StopLossUSD, 2));
   Print("Ladder 1        : $",
         DoubleToString(Ladder1ProfitUSD, 2));
   Print("Ladder 2        : $",
         DoubleToString(Ladder2ProfitUSD, 2));
   Print("L1 Stop Max     : $",
         DoubleToString(Ladder1StopMaxPriceUSD, 2));
   Print("========================================");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
  {



   if(!EnableRecoveryOrders || GetTotalEAOrders() >= MaxOpenOrders)
      return;
   RefreshRates();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0 || (OrderType() != OP_BUY && OrderType() != OP_SELL))
         continue;

      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      if(profit > RecoveryTriggerLossUSD || HasRecoveryOrder(OrderTicket()))
         continue;
      if((OrderType() == OP_BUY && !IsBuySignal(0)) || (OrderType() == OP_SELL && !IsSellSignal(0)))
         continue;

      double lots = NormalizeLots(OrderLots() * RecoveryLotMultiplier);

      if(!IsOneCandleOrderAllowed())
         continue;
      if(OrderType() == OP_BUY)
        {
         // if(!HasMinimumSameOrderGap(OP_BUY)) continue;
         SafeOrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, clrAqua);
        }
      else
        {
         // if(!HasMinimumSameOrderGap(OP_SELL)) continue;
         SafeOrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, 0, 0, "RECOVERY_" + IntegerToString(OrderTicket()), MagicNumber, clrOrange);
        }

      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasRecoveryOrder(int ParentTicket)
  {
   string txt="RECOVERY_"+IntegerToString(ParentTicket);

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol())
         continue;

      if(OrderMagicNumber()!=MagicNumber)
         continue;

      if(OrderComment()==txt)
         return true;
     }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageRecoveryBasket()
  {
   if(!EnableRecoveryOrders)
      return;

   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() ||
         OrderMagicNumber()!=MagicNumber)
         continue;


      string comment = OrderComment();


      // Find recovery order
      if(StringFind(comment,"RECOVERY_") != 0)
         continue;


      int parentTicket = StrToInteger(
                            StringSubstr(comment,
                                         StringLen("RECOVERY_"))
                         );


      double recoveryProfit =
         OrderProfit()
         + OrderSwap()
         + OrderCommission();



      // Find parent order
      if(!OrderSelect(parentTicket,SELECT_BY_TICKET))
         continue;


      if(OrderCloseTime()>0)
         continue;


      double parentProfit =
         OrderProfit()
         + OrderSwap()
         + OrderCommission();



      double basketProfit =
         recoveryProfit
         + parentProfit;



      Print("RECOVERY CHECK | Parent:",
            parentTicket,
            " Basket Profit:",
            DoubleToString(basketProfit,2));


      if(basketProfit >= RecoveryBasketProfitUSD)
        {

         // close ONLY parent
         int closeType=OrderType();
         bool closed=SafeOrderClose(
                       OrderTicket(),
                       OrderLots(),
                       closeType,
                       Slippage,
                       (closeType==OP_BUY ? clrRed : clrBlue));


         if(closed)
           {
            Print("RECOVERY SUCCESS | Parent Closed Only : ",
                  parentTicket);
           }
         else
           {
            Print("FAILED Parent Close : ",
                  parentTicket,
                  " Error:",
                  GetLastError());
           }


         return;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDailyProtectionState(DailyProtectionState &state)
  {
   string today = TimeToString(TimeCurrent(), TIME_DATE);
   state.DayDate = StrToTime(today);
   state.DayStartBalance = AccountBalance();
// state.DayProtectedBalance = state.DayStartBalance;
   state.DayProtectedBalance =
      AccountBalance() *
      (1.0 - DailyLossProtectionPercent/100.0);
   state.ClosedOrdersToday = 0;
   state.TradingStopped = false;
   state.Initialized = true;

   // Capture the original Day-1 balance once. Equity-ladder resets must
   // not overwrite this value.
   Day1ProtectionDate = state.DayDate;
   if(Day1ProtectionDate != state.DayDate)
      Day1ProtectionStartBalance = AccountBalance();

   Print("==================================================");
   Print("NEW DAILY PROTECTION INITIALIZED");
   Print("Day Start Balance: $", DoubleToString(state.DayStartBalance, 2));
   Print("Min Required Closed Orders: ", MinimumClosedOrdersForDailyProtection);
   Print("Daily Protection: ", DoubleToString(DailyLossProtectionPercent, 2), "%");
   Print("==================================================");
  }

//+------------------------------------------------------------------+
//| Protected Equity Hit -> Close All -> Reset -> Continue Trading   |
//+------------------------------------------------------------------+
void ResetAfterProtectedEquity(DailyProtectionState &state)
  {
   Print("================================================");
   Print("PROTECTED EQUITY HIT");
   Print("Current Equity : $", DoubleToString(AccountEquity(), 2));
   Print("Closing ALL EA orders...");
   Print("================================================");

// ---------------------------------------------------------------
// 1. CLOSE ALL EA ORDERS
// ---------------------------------------------------------------
   // ONE PASS ONLY. Any failed close/delete is recorded and deferred
   // to the next tick. Never chase the trade server in the same tick.
   RefreshRates();
   CloseAllEAOrdersOnDailyLoss();

// ---------------------------------------------------------------
// 2. VERIFY ALL ORDERS CLOSED
// ---------------------------------------------------------------
   if(GetTotalEAOrders() > 0)
     {
      Print("PROTECTED EQUITY RESET FAILED");
      Print("Remaining Orders : ", GetTotalEAOrders());

      // Keep trading stopped if orders could not be closed
      state.TradingStopped = true;
      return;
     }

   RefreshRates();

// ---------------------------------------------------------------
// 3. GET REAL BALANCE AFTER CLOSING ORDERS
// ---------------------------------------------------------------
   double newBalance = AccountBalance();

   Print("ALL EA ORDERS CLOSED");
   Print("New Balance : $", DoubleToString(newBalance, 2));

// ---------------------------------------------------------------
// 4. NEW PROTECTED EQUITY / NEW STARTING BALANCE
// ---------------------------------------------------------------
   state.DayStartBalance   = newBalance;


   state.ClosedOrdersToday = 0;

// ---------------------------------------------------------------
// 5. IMPORTANT - ALLOW TRADING AGAIN
// ---------------------------------------------------------------
   state.TradingStopped = false;

// ---------------------------------------------------------------
// 6. RESET DAILY PROTECTION
// ---------------------------------------------------------------
   DailyProtectionStartTime = TimeCurrent();

   DailyLossProtectionPercent =
      OriginalDailyLossProtectionPercent;

   state.DayProtectedBalance =
      newBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

// ---------------------------------------------------------------
// 7. RESET LOT / RECOVERY SETTINGS
// ---------------------------------------------------------------
   Lots = OriginalLots;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD;






// ---------------------------------------------------------------
// 8. RESET EQUITY LADDER
// ---------------------------------------------------------------
   EquityLadderLevel++;
   // DailyLossProtectionPercent locked;
   // DailyLossProtectionPercent--;
   // if(EquityLadderLevel>1)
   //   {
   //    DailyEquityTargetPercent=OriginalDailyEquityTargetPercent/2;
   //   }
   // else
   //   {
      DailyEquityTargetPercent=OriginalDailyEquityTargetPercent;

   //   }

   LockedEquity = newBalance;

   NextEquityTarget =
      newBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);


// ---------------------------------------------------------------
// 9. RESET ORDER-CANDLE CONTROL
// ---------------------------------------------------------------
   OrderCreatedThisCandle = false;

// ---------------------------------------------------------------
// 10. QUEUE TRADING USING CURRENT SSL DIRECTION
// ---------------------------------------------------------------
// Uses the same persistent re-entry mechanism as the Equity Ladder.
   TradeResetThisTick = true;
   StartProtectedEquityWait();

   Print("================================================");
   Print("PROTECTED EQUITY RESET COMPLETE");
   Print("Trading : ENABLED");
   Print("New Start Balance : $",
         DoubleToString(state.DayStartBalance, 2));

   Print("New Protected Equity : $",
         DoubleToString(state.DayProtectedBalance, 2));

   Print("Next Equity Target : $",
         DoubleToString(NextEquityTarget, 2));

   Print("Lots Reset : ",
         DoubleToString(Lots, 2));

   Print("================================================");
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| EQUITY LADDER - CLOSE TARGET, RESET, CONTINUE                    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Start trading immediately after an Equity Ladder reset           |
//| Uses the CURRENT SSL direction - no new crossover required       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Queue continuous Equity Ladder re-entry                         |
//+------------------------------------------------------------------+
//| Start 1-hour wait after Protected Equity is hit                  |
//+------------------------------------------------------------------+
void StartProtectedEquityWait()
  {
   ProtectedEquityWaitActive = true;
   ProtectedEquityWaitStartTime = TimeCurrent();
   EquityResetReEntryPending = false;

   Print("================================================");
   Print("PROTECTED EQUITY WAIT STARTED");
   Print("Trading paused for ", ProtectedEquityWaitMinutes, " minutes");
   Print("Wait Start : ", TimeToString(ProtectedEquityWaitStartTime, TIME_DATE|TIME_SECONDS));
   Print("Resume At  : ", TimeToString(ProtectedEquityWaitStartTime + ProtectedEquityWaitMinutes * 60, TIME_DATE|TIME_SECONDS));
   Print("================================================");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsProtectedEquityWaiting()
  {
   if(!ProtectedEquityWaitActive)
      return false;

   datetime resumeTime = ProtectedEquityWaitStartTime + ProtectedEquityWaitMinutes * 60;
   if(TimeCurrent() < resumeTime)
      return true;

   ProtectedEquityWaitActive = false;
   Print("================================================");
   Print("PROTECTED EQUITY WAIT COMPLETED");
   Print("1 HOUR PASSED - TRADING CAN RESUME");
   Print("================================================");

   // // QueueEquityResetReEntry();
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetProtectedEquityWaitSeconds()
  {
   if(!ProtectedEquityWaitActive)
      return 0;
   int remaining = (int)((ProtectedEquityWaitStartTime + ProtectedEquityWaitMinutes * 60) - TimeCurrent());
   if(remaining < 0)
      remaining = 0;
   return remaining;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetProtectedEquityWaitText()
  {
   int seconds = GetProtectedEquityWaitSeconds();
   return StringFormat("%02d:%02d:%02d", seconds/3600, (seconds%3600)/60, seconds%60);
  }

//+------------------------------------------------------------------+
void QueueEquityResetReEntry()
  {
   EquityResetReEntryPending = true;

// Allow the first order of the new equity cycle immediately.
   OrderCreatedThisCandle = false;
   LastOrderCandleTime    = 0;

   Print("================================================");
   Print("EQUITY RESET RE-ENTRY QUEUED");
   Print("CURRENT SSL direction will be used");
   Print("NO NEW SSL CROSSOVER REQUIRED");
   Print("================================================");
  }

//+------------------------------------------------------------------+
//| Process continuous Equity Ladder re-entry                       |
//| Keeps retrying until a fresh market order is opened              |
//+------------------------------------------------------------------+
void ProcessEquityResetReEntry(DailyProtectionState &state)
  {
   if(!EquityResetReEntryPending)
      return;

// Temporary blocks do NOT cancel the request.
   if(!EnableTrading)
      return;

   if(IsDailyTradingStopped(state))
      return;

   if(Bars < SSLPeriod + 20)
      return;

// If an order is already present, the re-entry succeeded.
   if(GetTotalEAOrders() > 0)
     {
      EquityResetReEntryPending = false;
      return;
     }

   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;

// IMPORTANT: current state, not crossover detection.
   int currentDirection = GetCurrentSSLDirection();

   if(currentDirection > 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime    = 0;

      DrawLiveSignal(0, true);

      int beforeOrders = GetTotalEAOrders();
      OpenBuy();
      int afterOrders = GetTotalEAOrders();

      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;

         Print("================================================");
         Print("EQUITY RESET -> BUY OPENED");
         Print("CURRENT SSL : BUY");
         Print("NO NEW SSL CROSSOVER REQUIRED");
         Print("CONTINUOUS EQUITY LADDER TRADING RESUMED");
         Print("================================================");
        }
      else
        {
         Print("EQUITY RESET -> BUY FAILED/BLOCKED");
         Print("RE-ENTRY REMAINS PENDING - WILL RETRY");
        }
      return;
     }

   if(currentDirection < 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime    = 0;

      DrawLiveSignal(0, false);

      int beforeOrders = GetTotalEAOrders();
      OpenSell();
      int afterOrders = GetTotalEAOrders();

      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;

         Print("================================================");
         Print("EQUITY RESET -> SELL OPENED");
         Print("CURRENT SSL : SELL");
         Print("NO NEW SSL CROSSOVER REQUIRED");
         Print("CONTINUOUS EQUITY LADDER TRADING RESUMED");
         Print("================================================");
        }
      else
        {
         Print("EQUITY RESET -> SELL FAILED/BLOCKED");
         Print("RE-ENTRY REMAINS PENDING - WILL RETRY");
        }
      return;
     }

// Neutral SSL: keep pending and check again on the next tick.
   Print("EQUITY RESET -> CURRENT SSL = NONE");
   Print("RE-ENTRY REMAINS PENDING");
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close market orders for Equity Ladder.                           |
//| Pending orders follow the global 6-hour rule.                    |
//| IMPORTANT: young pending orders do NOT block ladder increment.   |
//+------------------------------------------------------------------+
bool CloseMarketOrdersForEquityLadder()
  {
   // ONE PASS ONLY.
   // Failed close/delete requests are guarded by the global next-tick
   // retry mechanism. Never Sleep() or loop against the server here.
   RefreshRates();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int type=OrderType();

      if(type==OP_BUY || type==OP_SELL)
        {
         int ticket=OrderTicket();
         double lots=OrderLots();

         if(SafeOrderClose(ticket,lots,type,Slippage,
                           (type==OP_SELL ? clrRed : clrBlue)))
            Print("EQUITY LADDER MARKET CLOSED | Ticket=",ticket);
         else
            Print("EQUITY LADDER MARKET CLOSE DEFERRED | Ticket=",ticket,
                  " | Retry next tick");
        }
      else
      if(type==OP_BUYSTOP || type==OP_SELLSTOP ||
         type==OP_BUYLIMIT || type==OP_SELLLIMIT)
        {
         int ageSeconds=(int)(TimeCurrent()-OrderOpenTime());

         if(ageSeconds >= 6*60*60)
          {
           int ticket=OrderTicket();

           if(ForceDeletePendingOrder(ticket,clrRed))
              Print("EQUITY LADDER PENDING DELETED | Ticket=",ticket);
           else
              Print("EQUITY LADDER PENDING DELETE DEFERRED | Ticket=",ticket,
                    " | Retry next tick");
          }
         else
           {
            Print("EQUITY LADDER PENDING KEPT | Ticket=",OrderTicket(),
                  " | Age=",DoubleToString(ageSeconds/3600.0,2),
                  " hours | Required=6.00 hours");
           }
        }
     }

   return (GetTotalBuyOrders()+GetTotalSellOrders()==0);
  }



//+------------------------------------------------------------------+

void CheckDynamicEquityLadder(DailyProtectionState &state)
  {
// Equity ladder disabled
   if(!EnableEquityLadder || !EnableDynamicEquityLadder)
      return;

// Do not process while daily protection has stopped trading
   if(state.TradingStopped)
      return;

   double equity = AccountEquity();

// Safety: initialize target if not available
   if(NextEquityTarget <= 0)
     {
      state.DayStartBalance = AccountBalance();

      LockedEquity = state.DayStartBalance;




      NextEquityTarget =
         state.DayStartBalance *
         (1.0 + DailyEquityTargetPercent / 100.0);



      Print("EQUITY LADDER INITIALIZED");
      Print("Start Balance : $",
            DoubleToString(state.DayStartBalance, 2));
      Print("Next Target   : $",
            DoubleToString(NextEquityTarget, 2));

      return;
     }

//===============================================================
// TARGET NOT REACHED
//===============================================================
   if(equity < NextEquityTarget)
      return;

   Print("================================================");
   Print("EQUITY TARGET REACHED");
   Print("Current Equity : $", DoubleToString(equity, 2));
   Print("Target Equity  : $", DoubleToString(NextEquityTarget, 2));
   Print("Ladder Level   : ", EquityLadderLevel);
   Print("================================================");

//===============================================================
// CLOSE ALL EA ORDERS
//===============================================================
   // Close all MARKET orders now. Pending orders are handled by the
   // global 6-hour rule and therefore do NOT block ladder progression.
   bool marketsClosed = CloseMarketOrdersForEquityLadder();

//===============================================================
// VERIFY MARKET ORDERS ARE CLOSED
//===============================================================
   int remainingMarkets = GetTotalBuyOrders() + GetTotalSellOrders();

   if(!marketsClosed || remainingMarkets > 0)
     {
      Print("EQUITY LADDER WAITING - MARKET ORDERS STILL OPEN");
      Print("Remaining Market Orders : ", remainingMarkets);
      return;
     }

   // Pending orders younger than 6 hours are intentionally allowed to
   // remain active. They must NOT prevent EquityLadderLevel++.
   int remainingEAOrders = GetTotalEAOrders();
   Print("EQUITY LADDER MARKET ORDERS CLOSED | Remaining EA Orders (pending may remain): ",
         remainingEAOrders);

//===============================================================
// IMPORTANT:
// Get REAL account balance AFTER orders are closed
//===============================================================
   RefreshRates();

   double newBalance = AccountBalance();

//===============================================================
// CALCULATE PROFIT FROM THIS LADDER CYCLE
//===============================================================
   double cycleProfit =
      newBalance - state.DayStartBalance;

   Print("EQUITY LADDER CYCLE CLOSED");
   Print("Previous Start : $",
         DoubleToString(state.DayStartBalance, 2));
   Print("New Balance    : $",
         DoubleToString(newBalance, 2));
   Print("Cycle Profit   : $",
         DoubleToString(cycleProfit, 2));

//===============================================================
// INCREASE LADDER LEVEL
//===============================================================
   EquityLadderLevel++;
   // DailyLossProtectionPercent locked;
   // DailyLossProtectionPercent--;
//===============================================================
// NEW LADDER START
//===============================================================
   state.DayStartBalance   = newBalance;

   state.ClosedOrdersToday = 0;

   state.TradingStopped = false;

   DailyProtectionStartTime = TimeCurrent();

   // if(EquityLadderLevel>1)
   //   {
   //    DailyEquityTargetPercent=OriginalDailyEquityTargetPercent/2;
   //   }
   // else
   //   {
       DailyEquityTargetPercent=OriginalDailyEquityTargetPercent;

   //   }

//===============================================================
// RESET TRADE / RECOVERY STATE
//===============================================================
   Lots = OriginalLots;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD;






//===============================================================
// LOCK CURRENT BALANCE
//===============================================================
   LockedEquity = newBalance;

//===============================================================
// RESET DAILY PROTECTION FROM NEW BALANCE
//===============================================================
   state.DayProtectedBalance =
      newBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

//===============================================================
// CALCULATE NEXT COMPOUNDING TARGET
//===============================================================
   NextEquityTarget =
      newBalance *
      (1.0 + DailyEquityTargetPercent / 100.0);

//===============================================================
// RESET TARGET TIMER
//===============================================================

//===============================================================
// LOG NEW LADDER
//===============================================================
   Print("================================================");
   Print("NEW EQUITY LADDER STARTED");
   Print("Ladder Level  : ", EquityLadderLevel);
   Print("Start Balance : $",
         DoubleToString(state.DayStartBalance, 2));
   Print("Locked Equity : $",
         DoubleToString(LockedEquity, 2));
   Print("Next Target   : $",
         DoubleToString(NextEquityTarget, 2));
   Print("Cycle Profit  : $",
         DoubleToString(cycleProfit, 2));
   Print("================================================");

//===============================================================
// LADDER INCREMENT COMPLETE
// All market + pending EA orders were closed before the increment.
//
// IMPORTANT:
// When EnableDynamicEquityLadder=true, the EA must NOT wait for a
// new SSL crossover or the next candle. Continue immediately using
// the CURRENT SSL direction after EquityLadderLevel++.
//===============================================================
   if(EnableDynamicEquityLadder)
     {
      EquityResetReEntryPending = true;

      // Reset candle/order guards because this is a NEW equity-ladder
      // cycle and the current SSL direction is intentionally reused.
      OrderCreatedThisCandle = false;
      LastOrderCandleTime    = 0;

      // Execute the current-SSL re-entry immediately on this tick.
      // If the broker/server blocks the order, the pending flag remains
      // true and ProcessEquityResetReEntry() retries on subsequent ticks.
      ProcessEquityResetReEntry(state);
     }
   else
     {
      // Dynamic ladder re-entry is disabled.
      TradeResetThisTick = true;

      if(EnableLadderReEntryAfterIncrement)
        {
         // Optional legacy/manual re-entry mode.
         // QueueEquityResetReEntry();
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDailyLossProtection(DailyProtectionState &state)
  {
   if(!EnableDailyLossProtection)
      return;

   string today = TimeToString(TimeCurrent(), TIME_DATE);
   datetime todayDate = StrToTime(today);

   if(ResetDailyProtectionEveryDay && state.DayDate != todayDate)
     {
      state.DayDate = todayDate;
      state.DayStartBalance = AccountBalance();
      // state.DayProtectedBalance = state.DayStartBalance;
      state.DayProtectedBalance =
         AccountBalance() *
         (1.0 - DailyLossProtectionPercent/100.0);
      state.ClosedOrdersToday = 0;
      state.TradingStopped = false;
      DailyLossProtectionPercent = OriginalDailyLossProtectionPercent;


      DailyProtectionStartTime = TimeCurrent();
      Lots = OriginalLots;
      Ladder1ProfitUSD = OriginalLadder1ProfitUSD;
      Ladder2ProfitUSD = OriginalLadder2ProfitUSD;
      Ladder1StopMaxPriceUSD=OriginalLadder1StopMaxPriceUSD;

      InitializeEquityLadder(state);
      EquityLadderLevel = 1;
      LockedEquity = state.DayStartBalance;

      Print("==== NEW DAY - DAILY PROFIT PROTECTION RESET ====");
      Print("Day Start: $", DoubleToString(state.DayStartBalance, 2), " | Protected: $", DoubleToString(state.DayProtectedBalance, 2));
      Print("==================================================");
     }

   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   double currentEquity = AccountEquity();
   double minEquity =
      state.DayStartBalance *
      (1.0 - DailyLossProtectionPercent / 100.0);

// One protection path only. The old EA checked this same condition
// three times, making the minimum-closed-orders condition ineffective.
   if(currentEquity <= minEquity)
     {
      Print("================================================");
      Print("PROTECTED EQUITY STOP TRIGGERED");
      Print("Start Balance     : $", DoubleToString(state.DayStartBalance, 2));
      Print("Protected Equity  : $", DoubleToString(minEquity, 2));
      Print("Current Equity    : $", DoubleToString(currentEquity, 2));
      Print("Closed Orders     : ", state.ClosedOrdersToday);
      Print("================================================");

      if(CloseOpenOrdersOnDailyLoss)
         ResetAfterProtectedEquity(state);
      else
         state.TradingStopped = true;

      return;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountClosedOrdersSinceInitialization()
  {
   int count = 0;
   if(DailyProtectionStartTime <= 0)
      return 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if((OrderType() != OP_BUY && OrderType() != OP_SELL) || OrderCloseTime() <= DailyProtectionStartTime)
         continue;
      count++;
     }
   return count;
  }

bool IsDailyTradingStopped(DailyProtectionState &state) { return EnableDailyLossProtection && state.TradingStopped; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOppositePendingOrders(int newSignalType)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      bool deleteOrder = ((newSignalType == OP_BUY && orderType == OP_SELLSTOP) || (newSignalType == OP_SELL && orderType == OP_BUYSTOP));

      if(deleteOrder)
        {
         int ticket = OrderTicket();
         if(SafeOrderDelete(ticket, clrYellow))
            Print("OPPOSITE PENDING DELETED | Ticket: ", ticket);
         else
            Print("FAILED TO DELETE | Ticket: ", ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newSignalType)
  {

//===============================================================
// NEVER CLOSE ORDERS DURING EA INITIALIZATION
//===============================================================
   if(!EAStartupComplete)
     {
      Print("CLOSE OPPOSITE BLOCKED | EA STARTUP NOT COMPLETE");
      return;
     }
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();

      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // Close only opposite orders at or below the configured loss threshold
      if(orderPL > closeOppositeLossThreshold)
         continue;

      if((newSignalType == OP_BUY && orderType == OP_SELL) ||
         (newSignalType == OP_SELL && orderType == OP_BUY))
        {
         bool closed = SafeOrderClose(
                           ticket,
                           lots,
                           orderType,
                           Slippage,
                           (orderType==OP_SELL ? clrRed : clrBlue));

         if(closed)
            Print("OPPOSITE LOSS CLOSED | Ticket: ", ticket,
                  " | P/L: $", DoubleToString(orderPL,2));
         else
            Print("FAILED CLOSE | Ticket: ", ticket);
        }
     }
  }

//+------------------------------------------------------------------+
//| Close ALL EA Orders and Pending Orders                           |
//| Wait until everything is closed                                  |
//+------------------------------------------------------------------+
void CloseAllEAOrdersOnDailyLoss()
  {
   // ONE PASS ONLY. Every failed close/delete is logged and deferred
   // until the next OnTick. No Sleep and no same-tick server chasing.
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;

      int ticket=OrderTicket();
      int type=OrderType();

      bool result=false;

      if(type==OP_BUY || type==OP_SELL)
        {
         result=SafeOrderClose(ticket,OrderLots(),type,Slippage,
                               (type==OP_SELL ? clrRed : clrBlue));
        }
      else
      if(type==OP_BUYSTOP || type==OP_SELLSTOP ||
         type==OP_BUYLIMIT || type==OP_SELLLIMIT)
        {
         result=ForceDeletePendingOrder(ticket,clrRed);
        }
      else
        {
         result=true;
        }

      if(!result)
         Print("Daily protection operation deferred | Ticket=",ticket,
               " | Type=",type," | Retry next tick");
     }

   RefreshRates();

   int remain=0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;

      if(OrderSymbol()==Symbol() &&
         OrderMagicNumber()==MagicNumber)
         remain++;
     }

   Print("----------------------------------------");
   Print("Remaining EA Orders : ",remain);

   if(remain==0)
      Print("ALL EA ORDERS CLOSED SUCCESSFULLY");
   else
      Print("Some orders remain - failed operations will be retried on next tick.");
   Print("----------------------------------------");
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSSLChannelOnTick()
  {
   if(!ShowSSLLines || Bars < SSLPeriod + 20)
      return;

   int maxRecentBars = 10;
   if(maxRecentBars > Bars - SSLPeriod - 2)
      maxRecentBars = Bars - SSLPeriod - 2;

   for(int i = maxRecentBars; i >= 0; i--)
     {
      if(i + 1 >= Bars)
         continue;

      double up1, down1, up2, down2;
      int hlv1, hlv2;

      CalculateSSL(i, up1, down1, hlv1);
      CalculateSSL(i + 1, up2, down2, hlv2);

      DrawTrendSegment(PREFIX + "LIVE_UP_" + IntegerToString(i), Time[i], up1, Time[i + 1], up2, SSLUpColor);
      DrawTrendSegment(PREFIX + "LIVE_DOWN_" + IntegerToString(i), Time[i], down1, Time[i + 1], down2, SSLDownColor);
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeLastProcessedClosedOrder()
  {
   datetime latestCloseTime = 0;
   int latestTicket = -1;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() > latestCloseTime)
        {
         latestCloseTime = OrderCloseTime();
         latestTicket = OrderTicket();
        }
     }

   LastProcessedClosedOrderTime = latestCloseTime;
   LastProcessedClosedTicket = latestTicket;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForProfitableClosedOrder(DailyProtectionState &state)
  {
   datetime latestCloseTime = 0;
   double latestProfit = 0;
   int latestTicket = -1, latestType = -1;
   double latestClosePrice = 0;

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() <= latestCloseTime)
         continue;

      latestCloseTime = OrderCloseTime();
      latestTicket = OrderTicket();
      latestType = OrderType();
      latestProfit = OrderProfit() + OrderSwap() + OrderCommission();
      latestClosePrice = OrderClosePrice();
     }

   if(latestTicket < 0)
      return;
   if(latestTicket == LastProcessedClosedTicket && latestCloseTime == LastProcessedClosedOrderTime)
      return;

   LastProcessedClosedTicket = latestTicket;
   LastProcessedClosedOrderTime = latestCloseTime;

   Print("ORDER CLOSED | Ticket=",latestTicket,
         " | Direction=",(latestType==OP_BUY ? "BUY" : "SELL"),
         " | Close=",DoubleToString(latestClosePrice,Digits),
         " | P/L=$",DoubleToString(latestProfit,2));

   // Profit AND loss now continue the same ReEntry cycle.
   if(EnableProfitReEntryStop && !IsDailyTradingStopped(state))
     {
      // After a losing/stop-loss close, same-direction re-entry must use the base lot 0.01.
      CreateProfitReEntryStop(latestType, latestClosePrice, state, (latestProfit < 0.0));
      return;
     }

   // If ReEntry is disabled, retain the original SSL continuation behavior.
   if(EnableTrading && !IsDailyTradingStopped(state))
     {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(0))
        {
         OpenBuy();
         Print("BUY opened after closed order");
        }

      if(GetTotalSellOrders() == 0 && IsSellSignal(0))
        {
         OpenSell();
         Print("SELL opened after closed order");
        }
     }
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasPendingProfitReEntry(int pendingType)
  {
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(OrderType()!=pendingType)
         continue;

      string c=OrderComment();
      if(StringFind(c,"SSL Profit ReEntry",0)==0)
         return true;
     }

   return false;
  }

void CreateProfitReEntryStop(int closedOrderType, double closedPrice, DailyProtectionState &state, bool afterStopLoss=false)
  {
   if(!EnableTrading || !EnableProfitReEntryStop || IsDailyTradingStopped(state))
      return;
   if(ServerRecoveryPending || !IsConnected())
     {
      ReEntryRetryPending=true;
      ReEntryRetryClosedType=closedOrderType;
      ReEntryRetryClosedPrice=closedPrice;
      Print("PROFIT RE-ENTRY BLOCKED | Server recovery/connection not healthy");
      return;
     }
   if(HasBasketNewOrderLossLimit())
     {
      Print("PROFIT RE-ENTRY BLOCKED | Basket floating loss limit reached");
      return;
     }
   if(IsDirectionBlockedAfterSL(closedOrderType))
     {
      Print("PROFIT RE-ENTRY BLOCKED | Losing-SL protection | Direction=",closedOrderType);
      return;
     }
   if(GetTotalEAOrders() >= MaxOpenOrders)
     {
      Print("PROFIT RE-ENTRY BLOCKED | MAX ORDERS");
      return;
     }
   if(MaxSameDirectionOrders > 0 && CountDirectionOrders(closedOrderType) >= MaxSameDirectionOrders)
     {
      Print("PROFIT RE-ENTRY BLOCKED | Max same-direction orders");
      return;
     }

   RefreshRates();

   double entryPrice = (closedOrderType == OP_BUY) ? (closedPrice + ProfitReEntryGapRaw) : (closedPrice - ProfitReEntryGapRaw);
   int pendingType = (closedOrderType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   color orderColor = (closedOrderType == OP_BUY) ? BuyColor : SellColor;
   string orderComment = (closedOrderType == OP_BUY) ? "SSL Profit ReEntry Buy Stop" : "SSL Profit ReEntry Sell Stop";
   // if(HasPendingProfitReEntry(pendingType))
   //   {
   //    ReEntryRetryPending=false;
   //    Print("PROFIT RE-ENTRY SKIPPED | Existing pending ReEntry already present");
   //    return;
   //   }


   double minimumGap = GetRequiredStopDistance();

   if(pendingType == OP_BUYSTOP && entryPrice < Ask + minimumGap)
      entryPrice = Ask + minimumGap;
   if(pendingType == OP_SELLSTOP && entryPrice > Bid - minimumGap)
      entryPrice = Bid - minimumGap;

   entryPrice = NormalizeDouble(entryPrice, Digits);

   ResetLastError();
   if(afterStopLoss)
     {
      // A stop-loss must NOT escalate the re-entry sequence.
      // Same-direction order after SL is always the base 0.01 lot.
      Lots = NormalizeLots(0.01);
      Print("SL RE-ENTRY LOT FIXED | Direction=",
            (closedOrderType==OP_BUY ? "BUY" : "SELL"),
            " | Lot=",DoubleToString(Lots,2));
     }
   else
     {
      if(pendingType == OP_BUYSTOP)
         ChangeLots(GetOpenPL(OP_SELL), "SSL Profit ReEntry Buy Stop", OP_BUY,0);
      else
         ChangeLots(GetOpenPL(OP_BUY), "SSL Profit ReEntry Sell Stop", OP_SELL,0);
     }

   // Do NOT increment here. A failed send must keep the same ReEntry number.
   int requestedReEntryNumber = reEntryCounter + 1;

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = (pendingType == OP_BUYSTOP) ?
                     (entryPrice - slDistance) :
                     (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);

   int ticket = SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage,
                              stopLoss, 0, orderComment, MagicNumber, orderColor);

   if(ticket < 0)
     {
      Print("PROFIT RE-ENTRY FAILED | ReEntry #",requestedReEntryNumber,
            " | Lot=",DoubleToString(Lots,2));

      // A server/trade error must be retried on a later tick. The
      // ReEntry number is deliberately NOT advanced.
      if(ServerRecoveryPending)
        {
         ReEntryRetryPending=true;
         ReEntryRetryClosedType=closedOrderType;
         ReEntryRetryClosedPrice=closedPrice;
        }
     }
   else
     {
      // Advance ONLY after the broker confirms/identifies the order.
      reEntryCounter=requestedReEntryNumber;
      SaveReEntryCounter();
      ReEntryRetryPending=false;

      Print("PROFIT RE-ENTRY CREATED | ReEntry #",reEntryCounter,
            " | SL-ReEntry=",afterStopLoss?"YES":"NO",
            " | Lot=",DoubleToString(Lots,2),
            " | Lot=",DoubleToString(Lots,2),
            " | Ticket: ", ticket);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalBuyOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalSellOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalEAOrders()
  {
   if(CachedTotalEAOrdersTick==CurrentTickSequence &&
      CachedTotalEAOrders>=0)
      return CachedTotalEAOrders;

   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int type = OrderType();
      if(type==OP_BUY ||
         type==OP_SELL ||
         type==OP_BUYSTOP ||
         type==OP_SELLSTOP ||
         type==OP_BUYLIMIT ||
         type==OP_SELLLIMIT)
         count++;
     }

   CachedTotalEAOrders=count;
   CachedTotalEAOrdersTick=CurrentTickSequence;
   return count;
  }

void InvalidateTotalEAOrdersCache()
  {
   CachedTotalEAOrders=-1;
   CachedTotalEAOrdersTick=-1;
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenBuy()
  {
   if(!IsSafeToCreateMarketOrder(OP_BUY))
      return;
   if(!PassesEMAFilter(OP_BUY))
      return;

   if(!IsOneCandleOrderAllowed())
      return;

   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_BUY))
      return;

      reEntryCounter=0;
      SaveReEntryCounter();
   ChangeLots(GetOpenPL(OP_SELL),"SSL Long",OP_BUY,0);
   RefreshRates();

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = NormalizeDouble(Ask - slDistance, Digits);
   int ticket = SafeOrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage,
                              stopLoss, 0, "SSL Long", MagicNumber, BuyColor);

   if(ticket < 0)
      Print("BUY FAILED | OrderSend/Server error");
   else
     {
      // Mark the candle only after OrderSend succeeds.
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];

      Print("BUY OPENED | Ticket: ", ticket,
            " | CANDLE: ", TimeToString(Time[0], TIME_DATE|TIME_SECONDS));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double NormalizeLots(double lots)
  {
   double minLot  = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot  = MarketInfo(Symbol(), MODE_MAXLOT);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

   if(lotStep <= 0.0)
      lotStep = minLot > 0.0 ? minLot : 0.01;

   lots = MathMax(minLot, MathMin(maxLot, lots));
   lots = MathFloor((lots + 1e-9) / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   int digits = 0;
   double step = lotStep;
   while(digits < 8 && MathAbs(step - MathRound(step)) > 1e-8)
     {
      step *= 10.0;
      digits++;
     }

   return NormalizeDouble(lots, digits);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenSell()
  {
   if(!IsSafeToCreateMarketOrder(OP_SELL))
      return;
   if(!PassesEMAFilter(OP_SELL))
      return;

   if(!IsOneCandleOrderAllowed())
      return;
   if(GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_SELL))
      return;

      reEntryCounter=0;
      SaveReEntryCounter();
   ChangeLots(GetOpenPL(OP_BUY),"SSL Short",OP_SELL,0);
   RefreshRates();

   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;

   double stopLoss = NormalizeDouble(Bid + slDistance, Digits);
   int ticket = SafeOrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage,
                              stopLoss, 0, "SSL Short", MagicNumber, SellColor);

   if(ticket < 0)
      Print("SELL FAILED | OrderSend/Server error");
   else
     {
      // Mark the candle only after OrderSend succeeds.
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];

      Print("SELL OPENED | Ticket: ", ticket,
            " | CANDLE: ", TimeToString(Time[0], TIME_DATE|TIME_SECONDS));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePriceDistanceUSD(double usdAmount, double orderLots)
  {
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0 || orderLots <= 0)
      return 0;
   return (usdAmount / (tickValue * orderLots)) * tickSize;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageProfitLadder()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      //==================================================
      // FILTER EA ORDERS
      //==================================================
      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();

      if(orderType != OP_BUY &&
         orderType != OP_SELL)
         continue;




      //==================================================
      // CURRENT ORDER PROFIT
      //==================================================
      double currentProfit =
         OrderProfit() +
         OrderSwap() +
         OrderCommission();

      if(currentProfit <= 0)
         continue;

      //==================================================
      // CURRENT ORDER LOT
      //==================================================
      double orderLots = OrderLots();

      if(orderLots <= 0)
         continue;

      //==================================================
      // DYNAMIC LADDER VALUES
      // BASED ON CURRENT ORDER LOT
      //==================================================
      double ladder1Profit =
         OriginalLadder1ProfitUSD *
         orderLots * 100.0;


         if(orderLots == 0.10)
         {
            ladder1Profit =0.10;// ladder1Profit/2;
         }

      double ladder2Profit =
         OriginalLadder2ProfitUSD *
         orderLots * 100.0;

      double ladder1StopMaxPrice =
         OriginalLadder1StopMaxPriceUSD *
         orderLots * 100.0;

      double lockedProfit = 0.0;

      //==================================================
      // LADDER 1
      //
      // Example:
      //
      // L1 = $0.10
      //
      // $0.09 -> NO MODIFY
      // $0.10 -> LOCK $0.10
      // $0.15 -> NO MODIFY
      // $0.19 -> NO MODIFY
      // $0.20 -> LOCK $0.20
      // $0.25 -> NO MODIFY
      // $0.30 -> LOCK $0.30
      //==================================================
      if(EnableProfitLadder1 &&
         ladder1Profit > 0 &&
         currentProfit < ladder1StopMaxPrice)
        {
         int ladder1Level =
            (int)MathFloor(
               currentProfit / ladder1Profit
            );

         if(ladder1Level >= 1)
           {
            lockedProfit =
               ladder1Level * ladder1Profit;
           }
        }

      //==================================================
      // LADDER 2
      //
      // Example:
      //
      // L2 = $0.50
      //
      // $0.50 -> first L2 step
      // $1.00 -> second L2 step
      // $1.50 -> third L2 step
      //==================================================
      if(EnableProfitLadder2 &&
         ladder2Profit > 0 &&
         currentProfit >= ladder1StopMaxPrice)
        {
         int ladder2Level =
            (int)MathFloor(
               currentProfit / ladder2Profit
            );

         if(ladder2Level >= 1)
           {
            lockedProfit =
               ladder2Level * ladder2Profit;
           }
        }

      //==================================================
      // NOTHING TO LOCK
      //==================================================
      if(lockedProfit <= 0)
         continue;

      lockedProfit =
         NormalizeDouble(lockedProfit, 2);

      //==================================================
      // TICK INFORMATION
      //==================================================
      double tickValue =
         MarketInfo(Symbol(), MODE_TICKVALUE);

      double tickSize =
         MarketInfo(Symbol(), MODE_TICKSIZE);

      if(tickValue <= 0 ||
         tickSize <= 0)
         continue;

      //==================================================
      // CALCULATE CURRENTLY LOCKED PROFIT FROM SL
      //==================================================
      double existingLockedProfit = 0.0;

      if(OrderStopLoss() > 0)
        {
         double existingPriceDistance = 0.0;

         // BUY
         if(orderType == OP_BUY)
           {
            existingPriceDistance =
               OrderStopLoss() -
               OrderOpenPrice();
           }

         // SELL
         if(orderType == OP_SELL)
           {
            existingPriceDistance =
               OrderOpenPrice() -
               OrderStopLoss();
           }

         if(existingPriceDistance > 0)
           {
            existingLockedProfit =
               (existingPriceDistance / tickSize) *
               tickValue *
               orderLots;

            existingLockedProfit =
               NormalizeDouble(
                  existingLockedProfit,
                  2
               );
           }
        }

      //==================================================
      // DO NOT MODIFY IF CURRENT SL ALREADY LOCKS
      // THIS LADDER LEVEL
      //==================================================
      if(existingLockedProfit >= lockedProfit)
         continue;

      //==================================================
      // CALCULATE REQUIRED PRICE DISTANCE
      // FOR DESIRED LOCKED PROFIT
      //==================================================
      double priceDistance =
         (lockedProfit /
          (tickValue * orderLots)) *
         tickSize;

      if(priceDistance <= 0)
         continue;

      //==================================================
      // BROKER MINIMUM STOP DISTANCE
      //==================================================
      double stopLevel = GetRequiredStopDistance();

      double newStopLoss = 0.0;

      //==================================================
      // BUY
      //==================================================
      if(orderType == OP_BUY)
        {
         //================================================
         // CALCULATE SL FROM OPEN PRICE
         //================================================
         newStopLoss =
            OrderOpenPrice() +
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         //================================================
         // SL MUST BE BETTER THAN EXISTING SL
         //================================================
         if(OrderStopLoss() > 0 &&
            newStopLoss <= OrderStopLoss())
           {
            continue;
           }

         //================================================
         // BROKER MINIMUM DISTANCE
         //================================================
         if(Bid - newStopLoss < stopLevel)
           {
            newStopLoss =
               Bid - stopLevel;

            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
           }

         //================================================
         // VALIDATE BUY SL
         //================================================
         if(newStopLoss <= 0)
            continue;

         if(newStopLoss >= Bid)
            continue;

         //================================================
         // FINAL DUPLICATE PROTECTION
         //================================================
         if(OrderStopLoss() > 0 &&
            MathAbs(
               newStopLoss -
               OrderStopLoss()
            ) < Point)
           {
            continue;
           }

         //================================================
         // MODIFY BUY
         //================================================
         ResetLastError();

         bool modified =
            SafeOrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrLimeGreen
            );

         if(modified)
           {
            Print(
               "BUY LADDER UPDATED | ",
               "Ticket=", OrderTicket(),
               " | Lots=", DoubleToString(orderLots, 2),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | Old Lock=$",
               DoubleToString(existingLockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits)
            );
           }
         else
           {
            int error =
               GetLastError();

            Print(
               "BUY LADDER MODIFY FAILED | ",
               "Ticket=", OrderTicket(),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits),
               " | Error=",
               error
            );
           }
        }

      //==================================================
      // SELL
      //==================================================
      if(orderType == OP_SELL)
        {
         //================================================
         // CALCULATE SL FROM OPEN PRICE
         //================================================
         newStopLoss =
            OrderOpenPrice() -
            priceDistance;

         newStopLoss =
            NormalizeDouble(
               newStopLoss,
               Digits
            );

         //================================================
         // SL MUST BE BETTER THAN EXISTING SL
         //================================================
         if(OrderStopLoss() > 0 &&
            newStopLoss >= OrderStopLoss())
           {
            continue;
           }

         //================================================
         // BROKER MINIMUM DISTANCE
         //================================================
         if(newStopLoss - Ask < stopLevel)
           {
            newStopLoss =
               Ask + stopLevel;

            newStopLoss =
               NormalizeDouble(
                  newStopLoss,
                  Digits
               );
           }

         //================================================
         // VALIDATE SELL SL
         //================================================
         if(newStopLoss <= Ask)
            continue;

         //================================================
         // FINAL DUPLICATE PROTECTION
         //================================================
         if(OrderStopLoss() > 0 &&
            MathAbs(
               newStopLoss -
               OrderStopLoss()
            ) < Point)
           {
            continue;
           }

         //================================================
         // MODIFY SELL
         //================================================
         ResetLastError();

         bool modified =
            SafeOrderModify(
               OrderTicket(),
               OrderOpenPrice(),
               newStopLoss,
               OrderTakeProfit(),
               0,
               clrTomato
            );

         if(modified)
           {
            Print(
               "SELL LADDER UPDATED | ",
               "Ticket=", OrderTicket(),
               " | Lots=", DoubleToString(orderLots, 2),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | Old Lock=$",
               DoubleToString(existingLockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits)
            );
           }
         else
           {
            int error =
               GetLastError();

            Print(
               "SELL LADDER MODIFY FAILED | ",
               "Ticket=", OrderTicket(),
               " | Profit=$",
               DoubleToString(currentProfit, 2),
               " | Target Lock=$",
               DoubleToString(lockedProfit, 2),
               " | New SL=",
               DoubleToString(newStopLoss, Digits),
               " | Error=",
               error
            );
           }
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateSSL(int shift, double &sslUp, double &sslDown, int &hlv)
  {
   int oldest = Bars - SSLPeriod - 2;
   if(oldest < shift)
      oldest = shift;

   int currentHlv = 0;

   for(int i = oldest; i >= shift; i--)
     {
      double smaHigh = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_HIGH, i);
      double smaLow = iMA(Symbol(), Period(), SSLPeriod, 0, MODE_SMA, PRICE_LOW, i);
      double candleClose = Close[i];

      if(candleClose > smaHigh)
         currentHlv = 1;
      else
         if(candleClose < smaLow)
            currentHlv = -1;

      if(i == shift)
        {
         hlv = currentHlv;
         sslUp = (currentHlv < 0) ? smaLow : smaHigh;
         sslDown = (currentHlv < 0) ? smaHigh : smaLow;
         return;
        }
     }

   hlv = currentHlv;
   sslUp = 0;
   sslDown = 0;
  }

//+------------------------------------------------------------------+
//| Cached current SSL direction                                    |
//|  1 = BUY, -1 = SELL, 0 = NONE                                  |
//+------------------------------------------------------------------+
int GetCurrentSSLDirection()
  {
   if(Bars < SSLPeriod + 20)
      return 0;

// IMPORTANT: candle 0 is the currently forming candle.
// Do not cache this by bar because Close[0] changes on every tick.
   double up, down;
   int hlv;
   CalculateSSL(0, up, down, hlv);

   if(up > down)
      return 1;
   if(up < down)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| LIVE FORMING-CANDLE SIGNALS                                      |
//+------------------------------------------------------------------+
bool IsLiveBuySignal()
  {
   return IsBuySignal(0);
  }

//+------------------------------------------------------------------+
bool IsLiveSellSignal()
  {
   return IsSellSignal(0);
  }

//+------------------------------------------------------------------+
bool IsBuySignal(int shift)
  {
   if(shift + 1 >= Bars)
      return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious <= downPrevious && upCurrent > downCurrent);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSellSignal(int shift)
  {
   if(shift + 1 >= Bars)
      return false;
   double upCurrent, downCurrent, upPrevious, downPrevious;
   int hlvCurrent, hlvPrevious;
   CalculateSSL(shift, upCurrent, downCurrent, hlvCurrent);
   CalculateSSL(shift + 1, upPrevious, downPrevious, hlvPrevious);
   return (upPrevious >= downPrevious && upCurrent < downCurrent);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignals()
  {
   int barsToProcess = HistoryBarsToDraw;
   if(barsToProcess > Bars - SSLPeriod - 3)
      barsToProcess = Bars - SSLPeriod - 3;
   if(barsToProcess <= 0)
      return;

   if(ShowSSLLines)
     {
      for(int i = barsToProcess; i >= 1; i--)
        {
         double up1, down1, up2, down2;
         int hlv1, hlv2;
         CalculateSSL(i, up1, down1, hlv1);
         CalculateSSL(i - 1, up2, down2, hlv2);
         DrawTrendSegment(PREFIX + "HIST_UP_" + IntegerToString(i), Time[i], up1, Time[i - 1], up2, SSLUpColor);
         DrawTrendSegment(PREFIX + "HIST_DOWN_" + IntegerToString(i), Time[i], down1, Time[i - 1], down2, SSLDownColor);
        }
     }

   if(ShowHistoricalSignals)
     {
      for(int i = barsToProcess; i >= 1; i--)
        {
         if(IsBuySignal(i))
            DrawHistoricalSignal(i, true);
         if(IsSellSignal(i))
            DrawHistoricalSignal(i, false);
        }
     }
   ChartRedraw();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawTrendSegment(string name, datetime time1, double price1, datetime time2, double price2, color lineColor)
  {
   if(price1 <= 0 || price2 <= 0)
      return;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TREND, 0, time1, price1, time2, price2);
   else
     {
      ObjectMove(0, name, 0, time1, price1);
      ObjectMove(0, name, 1, time2, price2);
     }

   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, SSLLineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalSignal(int shift, bool isBuy)
  {
   string type = isBuy ? "BUY" : "SELL";
   string baseName = PREFIX + type + "_" + IntegerToString((int)Time[shift]);
   double price = isBuy ? (Low[shift] - SignalDistancePoints * Point) : (High[shift] + SignalDistancePoints * Point);

   if(ShowSignalArrows)
     {
      string arrowName = baseName + "_ARROW";
      if(ObjectFind(0, arrowName) < 0)
         ObjectCreate(0, arrowName, OBJ_ARROW, 0, Time[shift], price);
      else
         ObjectMove(0, arrowName, 0, Time[shift], price);
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, SignalArrowWidth);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
     }

   if(ShowSignalText)
     {
      string textName = baseName + "_TEXT";
      double textPrice = isBuy ? (price - SignalDistancePoints * 0.30 * Point) : (price + SignalDistancePoints * 0.30 * Point);
      if(ObjectFind(0, textName) < 0)
         ObjectCreate(0, textName, OBJ_TEXT, 0, Time[shift], textPrice);
      else
         ObjectMove(0, textName, 0, Time[shift], textPrice);
      ObjectSetString(0, textName, OBJPROP_TEXT, isBuy ? "Long +1" : "Short -1");
      ObjectSetInteger(0, textName, OBJPROP_COLOR, isBuy ? BuyColor : SellColor);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, SignalFontSize);
      ObjectSetString(0, textName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, textName, OBJPROP_SELECTABLE, false);
     }
  }

void DrawLiveSignal(int shift, bool isBuy) { DrawHistoricalSignal(shift, isBuy); ChartRedraw(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string TimeframeToString(int timeframe)
  {
   switch(timeframe)
     {
      case PERIOD_M1:
         return "M1";
      case PERIOD_M5:
         return "M5";
      case PERIOD_M15:
         return "M15";
      case PERIOD_M30:
         return "M30";
      case PERIOD_H1:
         return "H1";
      case PERIOD_H4:
         return "H4";
      case PERIOD_D1:
         return "D1";
      case PERIOD_W1:
         return "W1";
      case PERIOD_MN1:
         return "MN1";
     }
   return "CURRENT";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardPanel(string name, int x, int y, int width, int height, color background)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x+10);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, background);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDimGray);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateDashboardLabel(string name, string text, int x, int y, int fontSize, color textColor)
  {
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetTotalLots(int orderType)
  {
   double lots=0.0;
   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      if(OrderType()!=orderType) continue;
      lots+=OrderLots();
     }
   return lots;
  }

void UpdateDashboard(DailyProtectionState &state)
  {
   int totalOrders=0,buyOrders=0,sellOrders=0,pendingOrders=0;
   double floatingProfit=0,totalSwap=0,totalCommission=0;

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT) continue;
      totalOrders++;
      if(type==OP_BUY || type==OP_SELL)
        {
         if(type==OP_BUY) buyOrders++; else sellOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
        }
      else pendingOrders++;
     }

   double netProfit=floatingProfit+totalSwap+totalCommission;
   color pnlColor=netProfit>0?clrLime:netProfit<0?clrTomato:clrWhite;

   int currentSSLDirection=GetCurrentSSLDirection();
   string sslDirection=currentSSLDirection>0?"BUY":currentSSLDirection<0?"SELL":"NONE";
   color sslColor=currentSSLDirection>0?clrDeepSkyBlue:currentSSLDirection<0?clrTomato:clrSilver;

   double ema=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,InpEMAPriceShift);
   string emaState="N/A";
   color emaColor=clrSilver;
   if(ema>0)
     {
      if(Bid>ema) { emaState="BULLISH"; emaColor=clrLime; }
      else if(Bid<ema) { emaState="BEARISH"; emaColor=clrTomato; }
      else { emaState="AT EMA"; emaColor=clrGold; }
     }

   string statusText="READY";
   color statusColor=clrLime;
   if(!EnableTrading) { statusText="TRADING DISABLED"; statusColor=clrTomato; }
   else if(ServerRecoveryPending) { statusText="SERVER RECOVERY"; statusColor=clrGold; }
   else if(!IsConnected()) { statusText="NO CONNECTION"; statusColor=clrTomato; }
   else if(IsDailyTradingStopped(state)) { statusText="TRADING STOPPED"; statusColor=clrTomato; }
   else if(HasBasketNewOrderLossLimit()) { statusText="BASKET RISK LOCK"; statusColor=clrOrangeRed; }
   else if(!ContinueTradingAfterSL && LosingSLCount>=MaxConsecutiveLosingSL && MaxConsecutiveLosingSL>0) { statusText="SL LOSS LIMIT"; statusColor=clrTomato; }
   else if(ProtectedEquityWaitActive) { statusText="PROTECTED EQUITY WAIT"; statusColor=clrGold; }
   else if(EquityResetReEntryPending) { statusText="RESET RE-ENTRY PENDING"; statusColor=clrGold; }
   else if(totalOrders>=MaxOpenOrders) { statusText="MAX ORDERS"; statusColor=clrOrangeRed; }
   else if(buyOrders>0 && sellOrders>0) { statusText="HEDGE / MIXED"; statusColor=clrGold; }
   else if(buyOrders>0) { statusText="BUY ACTIVE"; statusColor=clrDeepSkyBlue; }
   else if(sellOrders>0) { statusText="SELL ACTIVE"; statusColor=clrTomato; }

   double ladderProgress=0;
   if(NextEquityTarget>state.DayStartBalance)
     {
      ladderProgress=((AccountEquity()-state.DayStartBalance)/(NextEquityTarget-state.DayStartBalance))*100.0;
      if(ladderProgress<0) ladderProgress=0;
      if(ladderProgress>100) ladderProgress=100;
     }

   double dayPL=AccountEquity()-state.DayStartBalance;
   double dayPLPct=(state.DayStartBalance>0)?(dayPL/state.DayStartBalance)*100.0:0;
   double basketLoss=MathMin(0.0,netProfit);
   double riskRemaining=BasketNewOrderLossLimitUSD>0 ? BasketNewOrderLossLimitUSD+netProfit : 0;
   if(riskRemaining<0) riskRemaining=0;

   string serverText="CONNECTED / OK";
   color serverColor=clrLime;
   if(!IsConnected()) { serverText="NO CONNECTION"; serverColor=clrTomato; }
   else if(ServerRecoveryPending) { serverText="RECOVERY PENDING #"+IntegerToString(ServerRecoveryLastError); serverColor=clrGold; }
   else if(ServerRecoveryLastError!=0) { serverText="LAST ERROR #"+IntegerToString(ServerRecoveryLastError); serverColor=clrGold; }

   int x=DashboardRightGap;
   int y=DashboardTopGap;
   int tx=x+12;
   int w=DashboardWidth;
   int row=20;
   int panelHeight=610;

   CreateDashboardPanel(DASH_PREFIX+"PANEL",x,y,w,panelHeight,C'12,16,22');
   CreateDashboardPanel(DASH_PREFIX+"HEADER",x,y,w,38,C'25,70,115');
   CreateDashboardLabel(DASH_PREFIX+"TITLE","SSL CHANNEL EA  |  PRO CONTROL",tx,y+8,11,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"SUBTITLE",Symbol()+"  |  "+TimeframeToString(Period()),tx+w-125,y+10,8,clrLightGray);

   CreateDashboardLabel(DASH_PREFIX+"STATUS", "STATUS       : "+statusText,tx,y+47,10,statusColor);
   CreateDashboardLabel(DASH_PREFIX+"SIGNAL", "SSL SIGNAL   : "+sslDirection,tx,y+67,9,sslColor);
   CreateDashboardLabel(DASH_PREFIX+"EMA", "EMA "+IntegerToString(InpEMA200Period)+"      : "+emaState+"  "+(ema>0?DoubleToString(ema,Digits):"-"),tx,y+87,9,emaColor);
   CreateDashboardLabel(DASH_PREFIX+"PRICE", "BID / ASK    : "+DoubleToString(Bid,Digits)+" / "+DoubleToString(Ask,Digits),tx,y+107,9,clrWhite);

   CreateDashboardPanel(DASH_PREFIX+"SEC_ACCOUNT",x,y+130,w-0,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"ACCOUNT_H","ACCOUNT & EQUITY",tx,y+134,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"BALANCE","BALANCE      : $"+DoubleToString(AccountBalance(),2),tx,y+157,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"EQUITY","EQUITY       : $"+DoubleToString(AccountEquity(),2),tx,y+177,9,clrLime);
   CreateDashboardLabel(DASH_PREFIX+"FREEMARGIN","FREE MARGIN   : $"+DoubleToString(AccountFreeMargin(),2),tx,y+197,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"DAYPL","DAY P/L       : "+(dayPL>=0?"+":"")+DoubleToString(dayPL,2)+" ("+DoubleToString(dayPLPct,1)+"%)",tx,y+217,9,dayPL>=0?clrLime:clrTomato);

   CreateDashboardPanel(DASH_PREFIX+"SEC_LADDER",x,y+240,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"LADDER_H","EQUITY LADDER",tx,y+244,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"STEP","STEP         : "+IntegerToString(EquityLadderLevel),tx,y+267,9,clrYellow);
   CreateDashboardLabel(DASH_PREFIX+"TARGET","NEXT TARGET  : $"+DoubleToString(NextEquityTarget,2),tx,y+287,9,clrLime);
   CreateDashboardLabel(DASH_PREFIX+"LOCKED","LOCKED EQUITY : $"+DoubleToString(LockedEquity,2),tx,y+307,9,clrGold);
   CreateDashboardLabel(DASH_PREFIX+"PROTECTED","DAY PROTECTED : $"+DoubleToString(state.DayProtectedBalance,2),tx,y+327,9,clrGold);
   CreateDashboardLabel(DASH_PREFIX+"PROGRESS","PROGRESS      : "+DoubleToString(ladderProgress,1)+"%",tx,y+347,9,clrWhite);

   CreateDashboardPanel(DASH_PREFIX+"SEC_RISK",x,y+370,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"RISK_H","RISK & STOP-LOSS PROTECTION",tx,y+374,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"FLOAT","FLOATING P/L  : "+(netProfit>=0?"+":"")+DoubleToString(netProfit,2),tx,y+397,9,pnlColor);
   int balancelomultipler =
   (int)(AccountBalance() / AccountMultiplierLOT);
   if(balancelomultipler < 1)
   balancelomultipler = 1;
   CreateDashboardLabel(DASH_PREFIX+"ORDERS","ORDERS       : "+IntegerToString(totalOrders)+" / "+IntegerToString(MaxOpenOrders)+"   B:"+IntegerToString(buyOrders)+" S:"+IntegerToString(sellOrders),tx,y+417,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"LOTS","LOTS         : B "+DoubleToString(GetTotalLots(OP_BUY),2)+" / S "+DoubleToString(GetTotalLots(OP_SELL),2)+" Multi X "+IntegerToString(balancelomultipler),tx,y+437,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"SLRISK","SL LOSSES    : "+IntegerToString(LosingSLCount)+" | CONTINUE AFTER SL: "+(ContinueTradingAfterSL?"YES":"NO"),tx,y+457,9,ContinueTradingAfterSL?clrLime:(LosingSLCount>0?clrOrangeRed:clrLime));
   CreateDashboardLabel(DASH_PREFIX+"BASKET","BASKET LOCK  : $"+DoubleToString(BasketNewOrderLossLimitUSD,2)+" | ROOM $"+DoubleToString(riskRemaining,2),tx,y+477,9,HasBasketNewOrderLossLimit()?clrTomato:clrLime);
   CreateDashboardLabel(DASH_PREFIX+"COOLDOWN","SL COOLDOWN  : "+(SLProtectionUntil>TimeCurrent()?TimeToString(SLProtectionUntil,TIME_SECONDS):"READY"),tx,y+497,9,SLProtectionUntil>TimeCurrent()?clrGold:clrLime);

   CreateDashboardPanel(DASH_PREFIX+"SEC_SERVER",x,y+520,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"SERVER_H","SERVER / EA HEALTH",tx,y+524,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"SERVER","CONNECTION   : "+serverText,tx,y+547,9,serverColor);
   CreateDashboardLabel(DASH_PREFIX+"RECOVERY","RECOVERY CTS  : "+IntegerToString(ServerRecoveryResetCount)+"   LAST ERR: "+IntegerToString(ServerRecoveryLastError),tx,y+567,8,ServerRecoveryLastError==0?clrSilver:clrGold);
   CreateDashboardLabel(DASH_PREFIX+"REENTRY","RE-ENTRY      : "+(EquityResetReEntryPending?"PENDING":(ProtectedEquityWaitActive?"WAIT":"READY")),tx,y+587,8,EquityResetReEntryPending||ProtectedEquityWaitActive?clrGold:clrLime);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteOurObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteDashboardObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, DASH_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
  }

//+------------------------------------------------------------------+
//| LEFT LIVE ORDERS DASHBOARD - SEPARATE FROM RIGHT DASHBOARD       |
//+------------------------------------------------------------------+
string LEFT_LIVE_PREFIX = "SSL_LEFT_LIVE_";

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLeftLivePanel(string name,int x,int y,int width,int height,color background)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);


 // IMPORTANT:
   // Panel stays in front of chart lines
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,1000);

   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,background);
   ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateLeftLiveLabel(string name,string text,int x,int y,int fontSize,color textColor)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetString(0,name,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteLeftLiveOrdersDashboardObjects()
  {
   int total=ObjectsTotal(0,-1,-1);
   for(int i=total-1; i>=0; i--)
     {
      string name=ObjectName(0,i,-1,-1);
      if(StringFind(name,LEFT_LIVE_PREFIX,0)==0)
         ObjectDelete(0,name);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateLeftLiveOrdersDashboard()
  {
   int total=0,buyCount=0,sellCount=0,pendingCount=0;
   double buyLots=0,sellLots=0,netPL=0;
   int rows=LeftDashboardMaxRows;
   if(rows<1) rows=1;
   if(rows>24) rows=24;

   for(int i=OrdersTotal()-1;i>=0;i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT) continue;
      total++;
      if(type==OP_BUY) { buyCount++; buyLots+=OrderLots(); }
      else if(type==OP_SELL) { sellCount++; sellLots+=OrderLots(); }
      else pendingCount++;
      if(type==OP_BUY || type==OP_SELL) netPL+=OrderProfit()+OrderSwap()+OrderCommission();
     }

   int x=LeftDashboardX,y=LeftDashboardY,tx=x+12;
   int width=LeftDashboardWidth+40;
   int panelHeight=rows*20+132;
   color pnlColor=netPL>0?clrLime:netPL<0?clrTomato:clrWhite;

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PANEL",x,y,width,panelHeight,C'12,16,22');
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"HEADER",x,y,width,38,C'25,70,115');

   
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TITLE","LIVE POSITION MONITOR",tx,y+8,11,clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SYMBOL",Symbol()+"  |  "+TimeframeToString(Period()),x+width-112,y+10,8,clrLightGray);

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"SUMMARYBAR",x,y+38,width,42,C'25,31,42');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SUMMARY","ORDERS "+IntegerToString(total)+"/"+IntegerToString(MaxOpenOrders)+"   BUY "+IntegerToString(buyCount)+"   SELL "+IntegerToString(sellCount)+"   PEND "+IntegerToString(pendingCount),tx,y+45,8,clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TOTALS","BUY LOT "+DoubleToString(buyLots,2)+"   SELL LOT "+DoubleToString(sellLots,2)+"   NET P/L "+(netPL>=0?"+":"")+DoubleToString(netPL,2),tx,y+62,9,pnlColor);

   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD","TICKET        TYPE       LOT        OPEN          SL           P/L",tx,y+88,8,clrSilver);

   for(int r=0;r<24;r++)
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(r),"",tx,y+108+(r*20),8,clrWhite);

   int row=0;
   for(int j=OrdersTotal()-1;j>=0;j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES)) continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber) continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT) continue;
      if(row>=rows) break;

      string typeText=type==OP_BUY?"BUY":type==OP_SELL?"SELL":type==OP_BUYSTOP?"BUY ST":type==OP_SELLSTOP?"SELL ST":type==OP_BUYLIMIT?"BUY LM":"SELL LM";
      double pl=(type==OP_BUY || type==OP_SELL)?OrderProfit()+OrderSwap()+OrderCommission():0;
      double sl=OrderStopLoss();
      double open=OrderOpenPrice();
      string rowText=StringFormat("#%-8d %-8s %5.2f  %10s  %10s  %7s",OrderTicket(),typeText,OrderLots(),DoubleToString(open,Digits),sl>0?DoubleToString(sl,Digits):"-",(type==OP_BUY||type==OP_SELL)?DoubleToString(pl,2):"-");
      color rowColor=clrWhite;
      if(type==OP_BUY) rowColor=clrDeepSkyBlue;
      else if(type==OP_SELL) rowColor=clrTomato;
      else rowColor=clrGold;
      if((type==OP_BUY || type==OP_SELL) && pl>0) rowColor=clrLime;
      if((type==OP_BUY || type==OP_SELL) && pl<0) rowColor=clrOrangeRed;
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(row),rowText,tx,y+108+(row*20),8,rowColor);
      row++;
     }

   if(total==0)
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY","NO ACTIVE EA ORDERS",tx,y+108,9,clrSilver);
   else
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY","Showing "+IntegerToString(MathMin(total,rows))+" of "+IntegerToString(total)+" orders",tx,y+108+(rows*20)+4,8,clrSilver);

   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| END OF EA
//+------------------------------------------------------------------+
