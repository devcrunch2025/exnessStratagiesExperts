//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - CONTINUOUS EQUITY LADDER |
//|                  TWO-STAGE PROFIT LADDER | CONTINUOUS RESET      |
//+------------------------------------------------------------------+
#property strict

// ===== INPUT SETTINGS =====
int SSLPeriod = 10;
bool InpUseEMA200Filter = false;
int  InpEMA200Period = 200;
int  InpEMAPriceShift = 0;
bool ShowEMALine = true;
color EMALineColor = clrGold;
int EMALineWidth = 2;
int EMALineBars = 500;
string EMA_PREFIX = "SSL_EMA_LINE_";
bool EnableTrading = true;
bool EnableDubaiTradingPause = true;
// string DubaiTradingPauseHours = "0,1,21,22,23,24";//final
string DubaiTradingPauseHours = "0,1,21,22,23,24";

// ===== 5% CONTINUOUS LADDER SETTINGS =====
  double CloseOrdersAtProfitFromOpeningBalance =2;// 5.0; // 5% profit increment
double Ladder5PercentBaseline = 0.0;


// ===== SPREAD & RISK SETTINGS FOR $100 BALANCE =====
double MaxAllowedSpreadUSD = 35.0;
int AccountMultiplierLOT = 100;
double OriginalStopLossUSD =3;// 1.50;
double StopLossUSD = 3;//1.50;

// ===== 30-MINUTE PRICE MOMENTUM FILTER =====
bool Enable30MinuteMomentumFilter = false;
double Min30MinutePriceDifference = 200;
double Min30MinutePriceDifferenceDuration = 30;
bool Enable30MinuteMomentumForProfitReEntry = false;
bool Enable30MinuteMomentumForAllOrders = false;

// ===== MARKET-MOMENT SAFETY FILTERS FOR NORMAL LOT SIZING =====
bool CapLotWhenH1Opposite = true;
int M5ConfirmationCandles = 3;
bool EnableATRVolatilityProtection = true;
int ATRVolatilityTimeframe = PERIOD_M5;
int ATRVolatilityPeriod = 14;
double MaxCandleRangeATRMultiple = 1.80;
double VolatilityLotCap = 0.01;

#define MAX_DEFERRED_ORDERS 50
bool   DeferredActive[MAX_DEFERRED_ORDERS];
string DeferredSymbol[MAX_DEFERRED_ORDERS];
int    DeferredType[MAX_DEFERRED_ORDERS];
double DeferredLots[MAX_DEFERRED_ORDERS];
double DeferredPrice[MAX_DEFERRED_ORDERS];
int    DeferredSlippage[MAX_DEFERRED_ORDERS];
double DeferredSL[MAX_DEFERRED_ORDERS];
double DeferredTP[MAX_DEFERRED_ORDERS];
string DeferredComment[MAX_DEFERRED_ORDERS];
int    DeferredMagic[MAX_DEFERRED_ORDERS];
color  DeferredColor[MAX_DEFERRED_ORDERS];
datetime DeferredCreated[MAX_DEFERRED_ORDERS];

double Lots = 0.01;
int MaxOpenOrders = 100;
bool CloseOppositeOrdersOnSignal = false;
double closeOppositeLossThreshold =-2;
bool DeleteOppositePendingOnSignal = true;
bool EnableProfitReEntryStop = true;
double MinimumClosedProfitUSD = -9;
double ProfitReEntryGapRaw =25;
double MinimumSameOrderGapRaw =10;//0;//20;

// ===== STOP-LOSS / RE-ENTRY SAFETY =====
bool EnableSLProtection = false;
int MaxSameDirectionOrders = 1000;
int MaxConsecutiveLosingSL = 1000;
int SLCooldownCandles = 3;
double SLReEntryGapRaw = 50.0;
double BasketNewOrderLossLimitUSD = 10.00; // Increased for strict 10% protection
int SLProtectionSafetyBufferPoints = 2;
bool DeletePendingOrdersAfterLosingSL = false;
bool RequireFreshSSLAfterLosingSL = false;
bool ContinueTradingAfterSL = true;
bool EnableFreezeLevelProtection = true;
double MinimumSLModifyGapRaw = 2.0;
bool EnableProfitLadder1 = true;



bool EnableProfitLadder2 = true;
//0.40 is default candle is jumping to 0
double Ladder1ProfitUSD =0.50;//1.00;//0.20;//0.40;// 0.20;//0.15; // Tightened for faster lock-in

double Ladder1StopMaxPriceUSD =2;//0.50;
double Ladder2ProfitUSD = 0.15; // Accelerates trailing increments
double DefaultOrderProfitUSD =2.00;// 0.75;

// ===== ONE-TIME POST-ORDER SL/TP VERIFICATION =====
bool   EnablePostOrderSLTPVerification = false;
int    PostOrderSLTPVerificationDelaySeconds = 60;
double PostOrderSLTPTolerancePercent = 20.0;
#define MAX_POST_ORDER_SLTP_VERIFY 200
bool     PostOrderSLTPVerifyActive[MAX_POST_ORDER_SLTP_VERIFY];
int      PostOrderSLTPVerifyTicket[MAX_POST_ORDER_SLTP_VERIFY];
datetime PostOrderSLTPVerifyCreated[MAX_POST_ORDER_SLTP_VERIFY];
bool     PostOrderSLTPVerifyChecked[MAX_POST_ORDER_SLTP_VERIFY];
string   PostOrderSLTPVerifyStatus[MAX_POST_ORDER_SLTP_VERIFY];
int      PostOrderSLTPVerifyLastError[MAX_POST_ORDER_SLTP_VERIFY];
double   PostOrderSLTPVerifyExpectedSL[MAX_POST_ORDER_SLTP_VERIFY];
double   PostOrderSLTPVerifyExpectedTP[MAX_POST_ORDER_SLTP_VERIFY];
double   PostOrderSLTPVerifyExpectedOpen[MAX_POST_ORDER_SLTP_VERIFY];
int      PostOrderSLTPVerifyType[MAX_POST_ORDER_SLTP_VERIFY];
double   PostOrderSLTPVerifyLots[MAX_POST_ORDER_SLTP_VERIFY];

bool EnableRecoveryOrders = true;
double RecoveryTriggerLossUSD =1;
double RecoveryLotMultiplier = 1;
int MaxRecoveryOrders = 1;
double RecoveryBasketProfitUSD =0.20;

bool   EnableDayProfitLadder = true;
double DayProfitLadder1Percent =25;//5;//30;
double DayProfitLadder1Amount =5;//10;//25;
double DayProfitLadderLockRatio = 0.10;
double DayProfitInitialProtectionPercent = 50.0;

int Slippage = 30;
int MagicNumber = 6600123;
int MaxTradeRequestsPerTick = 10;
int TradeRequestsThisTick = 0;
int CurrentTickSequence = 0;
int CachedTotalEAOrders = -1;
int CachedTotalEAOrdersTick = -1;
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
bool ShowLeftLiveOrdersDashboard = true;
int LeftDashboardX = 10;
int LeftDashboardY = 20;
int LeftDashboardWidth = 330;
int LeftDashboardMaxRows = 20;

double OriginalLots = 0.01;
double OriginalLadder1ProfitUSD = 0.05;
double OriginalLadder2ProfitUSD = 0.20;
double OriginalLadder1StopMaxPriceUSD = 0.20;

struct DailyProtectionState
  {
   datetime          DayDate;
   double            DayStartBalance;
   double            DayProtectedBalance;
   int               ClosedOrdersToday;
   bool              TradingStopped;
   bool              Initialized;
  };

double   DayProfitLadderStartBalance = 0.0;
double   DayProfitLadderStartEquity  = 0.0;
double   DayProfitLadderProtectionEquity = 0.0;
int      DayProfitLadderStage = 0;
double   DayProfitLadderNextTargetEquity = 0.0;
bool     DayProfitLadderTradingStopped = false;
datetime DayProfitLadderDate = 0;
bool     DayProfitLadderInitialized = false;
datetime DayProfitLadderTargetReachedCandle = 0;
bool DayProfitLadderResumePending = false;
int  DayProfitLadderResumeDirection = 0;
bool DayProfitLadderResumeTradeAttempt = false;
bool DayProfitLadderTargetCleanupPending = false;
datetime DayProfitLadderCleanupStartTime = 0;
int      LADDER_CLEANUP_TIMEOUT_SECONDS = 60;
string PREFIX = "SSL_CROSS_";
string DASH_PREFIX = "SSL_DASHBOARD_";
datetime LastProcessedBar = 0;
datetime LastProcessedClosedOrderTime = 0;
datetime DailyProtectionStartTime = 0;
int LastProcessedClosedTicket = -1;
bool StartupSignalProcessed = false;
bool TradeResetThisTick = false;
bool TradeOperationFailedThisTick = false;
bool LiveSSLInitialized = false;
int LastLiveSSLDirection = 1;
datetime LastLiveSignalCandle = 1;
bool EquityResetReEntryPending = true;
bool ProtectedEquityWaitActive = true;
datetime ProtectedEquityWaitStartTime = 0;
int ProtectedEquityWaitMinutes =0;

//+------------------------------------------------------------------+
bool IsH1BuyAllowed() { return (GetH1Direction() == 1); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsH1SellAllowed() { return (GetH1Direction() == -1); }
bool EnableSSLImmediateOrderCreation = true;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountOrdersByType(int orderType)
  {
   int count = 0;
   int total = OrdersTotal();
   for(int i = 0; i < total; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol())
         continue;
      if(OrderType() == orderType)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Continuous 5% Balance Ladder Reset                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Continuous 5% Balance Ladder Reset                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Continuous 5% Balance Ladder Reset                               |
//+------------------------------------------------------------------+
void Manage5PercentLadderReset()
  {
   // 1. Initialize the baseline balance if it hasn't been set yet
   if(Ladder5PercentBaseline <= 0.0)
     {
      Ladder5PercentBaseline = AccountBalance();
      return;
     }

   // 2. Calculate the target equity based on the 5% increment
   double targetEquity = Ladder5PercentBaseline * (1.0 + (CloseOrdersAtProfitFromOpeningBalance / 100.0));

   // 3. Trigger the reset if current equity hits or exceeds the target
   if(AccountEquity() >= targetEquity)
     {
      Print("5% Equity Ladder Target Reached. Closing all orders and resetting.");

      // Close all open and pending EA orders
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
           {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
              {
               int type = OrderType();
               if(type == OP_BUY || type == OP_SELL)
                 {
                  SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
                 }
               else if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
                 {
                  SafeOrderDelete(OrderTicket(), clrRed);
                 }
              }
           }
        }

      // 4. Update the baseline for the next 5% run
      Ladder5PercentBaseline = AccountBalance();

      // --- THE FIX: Reset the Daily Ladder so it doesn't block trading ---
      InitializeDayProfitLadder(); 
      DayProfitLadderTradingStopped = false; 
      // -------------------------------------------------------------------

      // Reset the candle block so the new order opens immediately
      OrderCreatedThisCandle = false;
      LastOrderCandleTime = 0;
      TradeResetThisTick = true; 

      // 5. Open a new order immediately based on the current SSL signal
      int currentSignal = GetCurrentSSLDirection();
      if(currentSignal == 1)
        {
         OpenBuy();
        }
      else if(currentSignal == -1)
        {
         OpenSell();
        }
     }
  }
int GetSSLSignal()
  {
   double upper = iATR(Symbol(), 0, SSLPeriod, 0) + iMA(Symbol(), 0, SSLPeriod, 0, MODE_SMA, PRICE_CLOSE, 0);
   double lower = iMA(Symbol(), 0, SSLPeriod, 0, MODE_SMA, PRICE_CLOSE, 0) - iATR(Symbol(), 0, SSLPeriod, 0);
   double currentClose = Close[0];
   double previousClose = Close[1];
   if(previousClose <= upper && currentClose > upper)
     {
      if(InpUseEMA200Filter)
        {
         if(currentClose > iMA(Symbol(), 0, InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0))
            return 1;
        }
      else
         return 1;
     }
   if(previousClose >= lower && currentClose < lower)
     {
      if(InpUseEMA200Filter)
        {
         if(currentClose < iMA(Symbol(), 0, InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0))
            return -1;
        }
      else
         return -1;
     }
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateLotSize()
  {
   double calculatedLots = (AccountBalance() / 100000.0) * Lots * AccountMultiplierLOT;
   double maxLots = MarketInfo(Symbol(), MODE_MAXLOT);
   double minLots = MarketInfo(Symbol(), MODE_MINLOT);
   calculatedLots = MathMin(calculatedLots, maxLots);
   calculatedLots = MathMax(calculatedLots, minLots);
   return NormalizeDouble(calculatedLots, 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetH1Direction()
  {
   double h1Open  = iOpen(Symbol(), PERIOD_H1, 1);
   double h1Close = iClose(Symbol(), PERIOD_H1, 1);
   if(h1Close > h1Open)
      return 1;
   if(h1Close < h1Open)
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
   if(!rebuild && LastEMARedrawMs!=0 && (uint)(emaNow-LastEMARedrawMs)<(uint)MathMax(0,EMARedrawIntervalMs))
      return;
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
   double ema0=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,0);
   double ema1=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,1);
   string liveName=EMA_PREFIX+"0";
   if(ema0>0 && ema1>0 && ObjectFind(0,liveName)>=0)
     {
      ObjectMove(0,liveName,0,Time[1],ema1);
      ObjectMove(0,liveName,1,Time[0],ema0);
     }
   uint now=GetTickCount();
   if(LastEMARedrawMs==0 || (uint)(now-LastEMARedrawMs)>=(uint)MathMax(0,EMARedrawIntervalMs))
     {
      LastEMARedrawMs=now;
      ChartRedraw(0);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PassesEMAFilter(int orderType)
  {
   if(!InpUseEMA200Filter)
      return true;
   if(Bars < InpEMA200Period + 5)
      return false;
   if(orderType != OP_BUY && orderType != OP_SELL)
      return false;
   int shift = InpEMAPriceShift;
   if(shift < 0)
      shift = 0;
   if(shift >= Bars)
      shift = Bars - 1;
   double ema = iMA(Symbol(), Period(), InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   if(ema <= 0.0)
      return false;
   RefreshRates();
   double price = (shift == 0) ? ((orderType == OP_BUY) ? Ask : Bid) : Close[shift];
   return (orderType == OP_BUY) ? (price > ema) : (price < ema);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessStartupSignal(DailyProtectionState &dailyState)
  {
   if(StartupSignalProcessed)
      return;
   if(Bars < SSLPeriod + 20)
      return;
   StartupSignalProcessed = true;
   int currentDirection = GetCurrentSSLDirection();
   bool buySignal  = (currentDirection > 0);
   bool sellSignal = (currentDirection < 0);
   if(buySignal)
     {
      DrawLiveSignal(0, true);
      if(EnableTrading && !IsDailyTradingStopped(dailyState) && GetTotalEAOrders() < MaxOpenOrders && PassesEMAFilter(OP_BUY))
         OpenBuy();
      return;
     }
   if(sellSignal)
     {
      DrawLiveSignal(0, false);
      if(EnableTrading && !IsDailyTradingStopped(dailyState) && GetTotalEAOrders() < MaxOpenOrders && PassesEMAFilter(OP_SELL))
         OpenSell();
      return;
     }
  }

bool EAStartupComplete = false;
int OnInit()
  {
   for(int initIndex = OrdersTotal() - 1; initIndex >= 0; initIndex--)
     {
      if(!OrderSelect(initIndex, SELECT_BY_POS, MODE_TRADES))
         continue;
      int initOrderType = OrderType();
      if(initOrderType == OP_BUYSTOP || initOrderType == OP_SELLSTOP || initOrderType == OP_BUYLIMIT || initOrderType == OP_SELLLIMIT)
         OrderDelete(OrderTicket(), clrNONE);
     }


// double OriginalLots = 0.01;
// double OriginalLadder1ProfitUSD = 0.05;
// double OriginalLadder2ProfitUSD = 0.20;
// double OriginalLadder1StopMaxPriceUSD = 0.20;
 

OriginalLadder1ProfitUSD=Ladder1ProfitUSD;
Ladder1StopMaxPriceUSD=Ladder1ProfitUSD*1.2;
DefaultOrderProfitUSD=Ladder1ProfitUSD*2;//


   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;
   OriginalLadder1StopMaxPriceUSD = Ladder1StopMaxPriceUSD;
   RecoveryTriggerLossUSD = MathAbs(RecoveryTriggerLossUSD);
   OriginalStopLossUSD = StopLossUSD;

   DeleteOurObjects();
   DeleteDashboardObjects();
   DeleteLeftLiveOrdersDashboardObjects();
   if(ShowHistoricalSignals || ShowSSLLines)
      DrawHistoricalSignals();
   UpdateEMALineOnChart();
   DailyProtectionStartTime = TimeCurrent();
   InitializeLastProcessedClosedOrder();
   LastProtectedLossTicket = LastProcessedClosedTicket;
   DayProfitLadderInitialized = false;
   DayProfitLadderTradingStopped = false;
   DayProfitLadderStage = 0;
   DayProfitLadderTargetReachedCandle = 0;
   InitializeDayProfitLadder();
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
      if(DayProfitLadderResumeTradeAttempt)
         return true;
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   RemoveDubaiTradingPauseDashboard();
   DeleteOurObjects();
   ClearEMALineObjects();
  }

int StartupProtectionTicks = 0;
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
//|                                                                  |
//+------------------------------------------------------------------+
void ManageProfitReEntryMomentumGate() { return; }
void ProcessPendingReEntry(DailyProtectionState &state) { return; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
   UpdateMomentumBackground();
   UpdateDubaiTradingPauseDashboard();
   uint tickStartMs=GetTickCount();
   OnTickCore();
   OnTickPerformanceEnd(tickStartMs);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Force delete all pending orders bypassing age restrictions       |
//+------------------------------------------------------------------+
void ForceDeleteAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Ensure it belongs to this EA and Symbol
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();

      // Check if it's a pending order
      if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
        {
         ResetLastError();
         // Use native OrderDelete to bypass the 6-hour restriction
         if(!OrderDelete(OrderTicket(), clrYellow))
           {
            Print("Force delete failed for ticket: ", OrderTicket(), " Error: ", GetLastError());
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTickCore()
  {
   CurrentTickSequence++;
   CachedTotalEAOrders=-1;
   CachedTotalEAOrdersTick=-1;
   ResetTradeErrorRetryGuards();
   TradeOperationFailedThisTick = false;
   ProcessPostOrderSLTPVerification();
   ProcessDeferredOrders();

   if(TradeOperationFailedThisTick)
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      return;
     }

   ResetTradeRequestBudget();
   RefreshRates();
   TradeResetThisTick = false;

   if(StartupProtectionTicks < 1)
     {
      StartupProtectionTicks++;
      EAStartupComplete = true;
     }

   static DailyProtectionState dailyState;
   if(!dailyState.Initialized)
      InitializeDailyProtectionState(dailyState);
   ManageDayProfitLadder();


   Manage5PercentLadderReset();

   if(ProcessServerRecovery(dailyState))
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   UpdateDailyLossProtection(dailyState);
   CheckLatestClosedTradeProtection();

   if(IsProtectedEquityWaiting())
     {
      if(ShowSSLLines)
         UpdateSSLChannelOnTick();
      UpdateEMALineOnChart();
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   CheckRecoveryOrders();
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   ManageRecoveryBasket();
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   if(DayProfitLadderTargetCleanupPending && !DayProfitLadderTradingStopped)
     {
      if(!CloseAllEAOrdersForLadderReset())
        {
         UpdateDashboardsThrottled(dailyState);
         return;
        }
      DayProfitLadderTargetCleanupPending = false;
      SaveDayProfitLadderState();
     }

   if(DayProfitLadderResumePending && DayProfitLadderResumeDirection != 0 && !DayProfitLadderTradingStopped)
     {
      int resumeDirection = DayProfitLadderResumeDirection;
      DayProfitLadderResumeTradeAttempt = true;
      bool ladderPendingCreated=false;
      if(resumeDirection == 1)
         ladderPendingCreated=CreateDayProfitLadderPending(OP_BUY);
      else
         if(resumeDirection == -1)
            ladderPendingCreated=CreateDayProfitLadderPending(OP_SELL);
      DayProfitLadderResumeTradeAttempt = false;
      if(ladderPendingCreated)
        {
         DayProfitLadderResumePending = false;
         DayProfitLadderResumeDirection = 0;
        }
     }

   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   ProcessStartupSignal(dailyState);
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   if(EquityResetReEntryPending)
      ProcessEquityResetReEntry(dailyState);
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   if(ShowSSLLines)
      UpdateSSLChannelOnTick();
   UpdateEMALineOnChart();

   if(!TradeResetThisTick)
      ManageProfitReEntryMomentumGate();
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   if(!TradeResetThisTick)
      ProcessPendingReEntry(dailyState);
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   if(Bars >= SSLPeriod + 20 && !TradeResetThisTick)
      CheckForProfitableClosedOrder(dailyState);
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }
   if(EnableProfitLadder1 || EnableProfitLadder2)
      ManageProfitLadder();
   if(TradeOperationFailedThisTick)
     {
      UpdateDashboardsThrottled(dailyState);
      return;
     }

   UpdateDashboardsThrottled(dailyState);

   if(Bars < SSLPeriod + 20)
      return;

   bool buySignal  = IsLiveBuySignal();
   bool sellSignal = IsLiveSellSignal();

// --- CONTINUOUS FALLBACK DETECTION ---
// Check if we are missing orders for the current active trend
   int currentTrend = GetCurrentSSLDirection();
   bool missingBuyOrder = (currentTrend == 1 && CountDirectionOrders(OP_BUY) == 0 && CountDirectionOrders(OP_BUYSTOP) == 0);
   bool missingSellOrder = (currentTrend == -1 && CountDirectionOrders(OP_SELL) == 0 && CountDirectionOrders(OP_SELLSTOP) == 0);

// --- EXECUTE BUY ---
   if(buySignal || missingBuyOrder)
     {
      if(buySignal)
         DrawLiveSignal(0, true); // Only draw arrows on the actual cross

      if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != 1 || missingBuyOrder)
        {
         LastLiveSignalCandle = Time[0];
         LastLiveSSLDirection = 1;

         if(FreshSSLRequiredDirection == -1)
            FreshSSLRequiredDirection = 0;

         // Only delete/close opposite orders on a fresh cross, not on a continuous fill
         if(buySignal)
           {
            if(DeleteOppositePendingOnSignal)
               DeleteOppositePendingOrders(OP_BUY);
            if(CloseOppositeOrdersOnSignal)
               CloseOppositeOrders(OP_BUY);


            if(DeleteOppositePendingOnSignal)
               ForceDeleteAllPendingOrders(); // Replaced here
           }

         if(TradeOperationFailedThisTick)
           {
            UpdateDashboardsThrottled(dailyState);
            return;
           }

         if(EnableTrading && !IsDailyTradingStopped(dailyState))
           {
            if(GetTotalEAOrders() < MaxOpenOrders)
               OpenBuy();
           }
        }
     }
// --- EXECUTE SELL ---
   else
      if(sellSignal || missingSellOrder)
        {
         if(sellSignal)
            DrawLiveSignal(0, false); // Only draw arrows on the actual cross

         if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != -1 || missingSellOrder)
           {
            LastLiveSignalCandle = Time[0];
            LastLiveSSLDirection = -1;

            if(FreshSSLRequiredDirection == 1)
               FreshSSLRequiredDirection = 0;

            // Only delete/close opposite orders on a fresh cross, not on a continuous fill
            if(sellSignal)
              {
               if(DeleteOppositePendingOnSignal)
                  DeleteOppositePendingOrders(OP_SELL);
               if(CloseOppositeOrdersOnSignal)
                  CloseOppositeOrders(OP_SELL);


               if(DeleteOppositePendingOnSignal)
                  ForceDeleteAllPendingOrders(); // Replaced here
              }

            if(TradeOperationFailedThisTick)
              {
               UpdateDashboardsThrottled(dailyState);
               return;
              }

            if(EnableTrading && !IsDailyTradingStopped(dailyState))
              {
               if(GetTotalEAOrders() < MaxOpenOrders)
                  OpenSell();
              }
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
         return false;
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
//|                                                                  |
//+------------------------------------------------------------------+
double GetOppositeOrdersLots(int orderType)
  {
   double totalLots = 0.01;
   int oppositeType = (orderType == OP_BUY) ? OP_SELL : OP_BUY;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != oppositeType)
         continue;
      totalLots += OrderLots();
     }
   return NormalizeLots(totalLots > 0.0 ? totalLots : OriginalLots);
  }

int reEntryCounter=0;
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CanOpenRiskOrder(int orderType, double requestedLot)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;
      double existingLot = OrderLots();
      if(MathAbs(existingLot - requestedLot) > 0.000001)
         continue;
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      double lossLimit = 3.0 * (requestedLot / 0.01);
      if(pl <= -lossLimit)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMaxOpenLotByType(int orderType)
  {
   double maxLot = 0.0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber || OrderType() != orderType)
         continue;
      if(OrderLots() > maxLot)
         maxLot = OrderLots();
     }
   return maxLot;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetReEntryLot(int reEntryNumber)
  {
   double lot = 0.05 - (reEntryNumber * 0.01);
   if(lot < 0.01)
      lot = 0.01;
   return NormalizeLots(lot);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasExistingProfitReEntryOrder()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(StringFind(OrderComment(),"SSL Profit ReEntry",0)==0)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadReEntryCounter() { reEntryCounter=0; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SaveReEntryCounter() { return; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsRetryableTradeError(int err)
  {
   switch(err)
     {
      case 4:
      case 6:
      case 128:
      case 135:
      case 136:
      case 137:
      case 138:
      case 146:
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsInvalidStopError(int err) { return (err == 130); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetRequiredStopDistance()
  {
   double stopPts = MarketInfo(Symbol(),MODE_STOPLEVEL);
   double freezePts = 0.0;
   if(EnableFreezeLevelProtection)
      freezePts = MarketInfo(Symbol(),MODE_FREEZELEVEL);
   double requiredPts = MathMax(stopPts,freezePts) + SLProtectionSafetyBufferPoints;
   if(requiredPts < 1.0)
      requiredPts = 1.0;
   return requiredPts * Point;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PrepareStopLossForOrder(int orderType,double referencePrice,double &stopLoss)
  {
   if(stopLoss <= 0.0)
      return true;
   RefreshRates();
   double minDistance=GetRequiredStopDistance();
   if(orderType==OP_BUY || orderType==OP_BUYSTOP)
     {
      double maxSL=Bid-minDistance;
      if(orderType==OP_BUYSTOP)
         maxSL=MathMin(maxSL,referencePrice-minDistance);
      if(maxSL<=0.0)
         return false;
      if(stopLoss>maxSL)
         stopLoss=maxSL;
     }
   else
      if(orderType==OP_SELL || orderType==OP_SELLSTOP)
        {
         double minSL=Ask+minDistance;
         if(orderType==OP_SELLSTOP)
            minSL=MathMax(minSL,referencePrice+minDistance);
         if(minSL<=0.0)
            return false;
         if(stopLoss<minSL)
            stopLoss=minSL;
        }
      else
         return true;
   stopLoss=NormalizeDouble(stopLoss,Digits);
   if(orderType==OP_BUY || orderType==OP_BUYSTOP)
     {
      if(stopLoss<=0.0 || stopLoss>=Bid)
         return false;
      if(orderType==OP_BUYSTOP && stopLoss>=referencePrice)
         return false;
     }
   else
     {
      if(stopLoss<=Ask)
         return false;
      if(orderType==OP_SELLSTOP && stopLoss<=referencePrice)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDirectionBlockedAfterSL(int orderType)
  {
   if(ContinueTradingAfterSL || !EnableSLProtection)
      return false;
   int dir=(orderType==OP_BUY)?1:-1;
   if(SLProtectionUntil>TimeCurrent() && BlockedSLDirection==dir)
      return true;
   if(RequireFreshSSLAfterLosingSL && FreshSSLRequiredDirection==dir)
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasBasketNewOrderLossLimit()
  {
   if(!EnableSLProtection || BasketNewOrderLossLimitUSD<=0.0)
      return false;
   double basket=0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;
      basket += OrderProfit()+OrderSwap()+OrderCommission();
     }
   return basket<=-BasketNewOrderLossLimitUSD;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountDirectionOrders(int orderType)
  {
   int count=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && OrderType()==orderType)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSafeToCreateMarketOrder(int orderType)
  {
   if(!IsDayProfitLadderTradingAllowed())
      return false;
   if(!EnableSLProtection)
      return true;
   if(!IsConnected())
      return false;
   if(HasBasketNewOrderLossLimit())
      return false;
   if(MaxSameDirectionOrders>0 && CountDirectionOrders(orderType)>=MaxSameDirectionOrders)
      return false;
   if(IsDirectionBlockedAfterSL(orderType))
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DeleteAllPendingEAOrders()
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
         SafeOrderDelete(OrderTicket(),clrRed);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RegisterLosingSLProtection(int ticket,int orderType,double profit)
  {
   if(!EnableSLProtection || ticket<=0 || profit>=0.0 || ticket==LastProtectedLossTicket)
      return;
   LastProtectedLossTicket=ticket;
   LosingSLCount++;
   BlockedSLDirection=(orderType==OP_BUY)?1:-1;
   FreshSSLRequiredDirection=BlockedSLDirection;
   SLProtectionUntil=TimeCurrent()+MathMax(0,SLCooldownCandles)*Period()*60;
   if(DeletePendingOrdersAfterLosingSL && !ContinueTradingAfterSL)
      DeleteAllPendingEAOrders();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RegisterProfitableClose()
  {
   LosingSLCount=0;
   BlockedSLDirection=0;
   SLProtectionUntil=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckLatestClosedTradeProtection()
  {
   if(!EnableSLProtection)
      return;
   datetime latest=0;
   int ticket=-1,type=-1;
   double profit=0.0;
   for(int i=OrdersHistoryTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(OrderType()!=OP_BUY && OrderType()!=OP_SELL)
         continue;
      if(OrderCloseTime()>latest)
        {
         latest=OrderCloseTime();
         ticket=OrderTicket();
         type=OrderType();
         profit=OrderProfit()+OrderSwap()+OrderCommission();
        }
     }
   if(ticket<0)
      return;
   static int lastSeenProtectionTicket=-1;
   if(ticket==lastSeenProtectionTicket)
      return;
   lastSeenProtectionTicket=ticket;
   if(profit<0.0)
      RegisterLosingSLProtection(ticket,type,profit);
   else
      if(profit>0.0)
         RegisterProfitableClose();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MarkServerError(int err,string operation)
  {
   TradeOperationFailedThisTick = true;
   ServerRecoveryPending=true;
   ServerRecoveryLastError=err;
   ServerRecoveryDetectedTime=TimeCurrent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeEnvironmentHealthy()
  {
   if(!IsConnected())
      return false;
   RefreshRates();
   if(Bid<=0 || Ask<=0 || !IsTradeAllowed())
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetRuntimeAfterServerError(DailyProtectionState &state)
  {
   RefreshRates();
   TradeResetThisTick=false;
   OrderCreatedThisCandle=false;
   LastOrderCandleTime=0;
   StartupProtectionTicks=0;
   EAStartupComplete=true;
   state.ClosedOrdersToday=CountClosedOrdersSinceInitialization();
   LiveSSLInitialized=false;
   LastLiveSSLDirection=GetCurrentSSLDirection();
   LastLiveSignalCandle=Time[0];
   if(HasExistingProfitReEntryOrder())
      LoadReEntryCounter();
   ServerRecoveryResetCount++;
   ServerRecoveryPending=false;
   ServerRecoveryLastError=0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ProcessServerRecovery(DailyProtectionState &state)
  {
   if(!ServerRecoveryPending)
      return false;
   if(IsTradeEnvironmentHealthy())
     {
      ServerRecoveryPending=false;
      ServerRecoveryLastError=0;
      return false;
     }
   ResetRuntimeAfterServerError(state);
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FindExistingOrderForRequest(int orderType,double lots,double price,string orderComment,datetime requestTime)
  {
   RefreshRates();
   double priceTolerance=MathMax(Point*20.0,Point*Slippage*2.0);
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber || OrderType()!=orderType)
         continue;
      if(MathAbs(OrderLots()-lots)>0.0000001 || OrderComment()!=orderComment || OrderOpenTime()+3<requestTime)
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetTradeRequestBudget() { TradeRequestsThisTick=0; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CanSendTradeRequest(string operation,string details="")
  {
   if(MaxTradeRequestsPerTick<=0)
      return true;
   if(TradeRequestsThisTick>=MaxTradeRequestsPerTick)
      return false;
   TradeRequestsThisTick++;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboardsThrottled(DailyProtectionState &state,bool force=false)
  {
   uint now=GetTickCount();
   if(!force && LastDashboardUpdateMs!=0 && (uint)(now-LastDashboardUpdateMs)<(uint)MathMax(0,DashboardUpdateIntervalMs))
      return;
   LastDashboardUpdateMs=now;
   if(ShowDashboard)
      UpdateDashboard(state);
   if(ShowLeftLiveOrdersDashboard)
      UpdateLeftLiveOrdersDashboard();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogTradeTiming(string operation,uint startedMs)
  {
   if(!EnableTradeTimingLog)
      return;
   uint elapsed=GetTickCount()-startedMs;
   if((int)elapsed>=SlowTradeRequestLogThresholdMs)
      Print("SLOW TRADE REQUEST: ",operation," ElapsedMs=",elapsed);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTickPerformanceEnd(uint startedMs)
  {
   if(!EnableTickPerformanceLog)
      return;
   uint elapsed=GetTickCount()-startedMs;
   if((int)elapsed>=SlowTickLogThresholdMs)
      Print("SLOW EA TICK: ElapsedMs=",elapsed);
  }

string TradeErrorBlockedKeys[200];
int TradeErrorBlockedCount=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ResetTradeErrorRetryGuards() { TradeErrorBlockedCount=0; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string MakeTradeErrorKey(string operation,int ticket,string extra) { return operation+"|"+IntegerToString(ticket)+"|"+extra; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradeErrorBlockedThisTick(string key)
  {
   for(int i=0; i<TradeErrorBlockedCount; i++)
      if(TradeErrorBlockedKeys[i]==key)
         return true;
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogTradeOperationError(string operation,int ticket,string details,int err)
  {
   Print("TRADE OP FAILED: ", operation, " ticket: ", ticket, " err: ", err, " details: ", details);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Get30MinDifference(int orderType = OP_BUY)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   int lookbackMinutes = (int)MathMax(1.0, Min30MinutePriceDifferenceDuration);
   datetime targetTime = TimeCurrent() - lookbackMinutes * 60;
   int shift = iBarShift(Symbol(), PERIOD_M1, targetTime, false);
   if(shift < 0)
      return 0.0;
   double oldPrice = iClose(Symbol(), PERIOD_M1, shift);
   if(oldPrice <= 0.0)
      return 0.0;
   return currentPrice - oldPrice;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool Passes30MinuteMomentumFilter(int orderType)
  {
   if(!Enable30MinuteMomentumFilter)
      return true;
   if(orderType != OP_BUY && orderType != OP_SELL)
      return true;
   double diff = Get30MinDifference(orderType);
   double threshold = MathAbs(Min30MinutePriceDifference);
   if(orderType == OP_BUY)
      return (diff > threshold);
   return (diff < -threshold);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int DeferredDirection(int orderType)
  {
   if(orderType==OP_BUY || orderType==OP_BUYSTOP || orderType==OP_BUYLIMIT)
      return OP_BUY;
   if(orderType==OP_SELL || orderType==OP_SELLSTOP || orderType==OP_SELLLIMIT)
      return OP_SELL;
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PassesDeferredMomentum(int orderType)
  {
   if(!Enable30MinuteMomentumFilter || !Enable30MinuteMomentumForAllOrders)
      return true;
   int direction=DeferredDirection(orderType);
   if(direction!=OP_BUY && direction!=OP_SELL)
      return true;
   return Passes30MinuteMomentumFilter(direction);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int FindDeferredOrder(string symbol,int orderType,string comment,int magic)
  {
   for(int i=0; i<MAX_DEFERRED_ORDERS; i++)
     {
      if(!DeferredActive[i])
         continue;
      if(DeferredSymbol[i]!=symbol || DeferredType[i]!=orderType || DeferredMagic[i]!=magic)
         continue;
      if(DeferredComment[i]==comment)
         return i;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int QueueDeferredOrder(string symbol,int orderType,double lots,double price,int slippage,double stopLoss,double takeProfit,string comment,int magic,color arrowColor,bool bypassDeferred=false)
  {
   int existing=FindDeferredOrder(symbol,orderType,comment,magic);
   if(existing>=0)
      return existing;
   for(int i=0; i<MAX_DEFERRED_ORDERS; i++)
     {
      if(DeferredActive[i])
         continue;
      DeferredActive[i]=true;
      DeferredSymbol[i]=symbol;
      DeferredType[i]=orderType;
      DeferredLots[i]=lots;
      DeferredPrice[i]=price;
      DeferredSlippage[i]=slippage;
      DeferredSL[i]=stopLoss;
      DeferredTP[i]=takeProfit;
      DeferredComment[i]=comment;
      DeferredMagic[i]=magic;
      DeferredColor[i]=arrowColor;
      DeferredCreated[i]=TimeCurrent();
      return -2;
     }
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessDeferredOrders()
  {
   if(!EnableTrading || !IsDayProfitLadderTradingAllowed())
      return;
   for(int i=0; i<MAX_DEFERRED_ORDERS; i++)
     {
      if(!DeferredActive[i])
         continue;
      int type=DeferredType[i];
      if(Enable30MinuteMomentumFilter && Enable30MinuteMomentumForAllOrders && !PassesDeferredMomentum(type))
         continue;
      if(GetTotalEAOrders() >= MaxOpenOrders)
         continue;
      double sendPrice=DeferredPrice[i];
      if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
        {
         RefreshRates();
         double minGap=GetRequiredStopDistance();
         if(type==OP_BUYSTOP)
            sendPrice=MathMax(sendPrice,Ask+minGap);
         else
            if(type==OP_SELLSTOP)
               sendPrice=MathMin(sendPrice,Bid-minGap);
         sendPrice=NormalizeDouble(sendPrice,Digits);
        }
      int ticket=SafeOrderSend(DeferredSymbol[i],type,DeferredLots[i],sendPrice,DeferredSlippage[i],DeferredSL[i],DeferredTP[i],DeferredComment[i],DeferredMagic[i],DeferredColor[i]);
      if(ticket>0)
        {
         if(type==OP_BUY || type==OP_SELL)
           {
            OrderCreatedThisCandle=true;
            LastOrderCandleTime=Time[0];
           }
         if(StringFind(DeferredComment[i],"SSL Profit ReEntry",0)==0)
           {
            reEntryCounter++;
            SaveReEntryCounter();
            ReEntryRetryPending=false;
           }
         DeferredActive[i]=false;
         InvalidateTotalEAOrdersCache();
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateDefaultProfitTargetPrice(int orderType,double openPrice,double orderLots,double profitUSD)
  {
   if(openPrice<=0.0 || orderLots<=0.0 || profitUSD<=0.0)
      return 0.0;
   double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE);
   double tickSize =MarketInfo(Symbol(),MODE_TICKSIZE);
   if(tickValue<=0.0 || tickSize<=0.0)
      return 0.0;
   double scaledProfit=profitUSD*(orderLots/0.01);
   double priceDistance=(scaledProfit/(tickValue*orderLots))*tickSize;
   if(priceDistance<=0.0)
      return 0.0;
   double target=0.0;
   if(orderType==OP_BUY || orderType==OP_BUYLIMIT || orderType==OP_BUYSTOP)
      target=openPrice+priceDistance;
   else
      if(orderType==OP_SELL || orderType==OP_SELLLIMIT || orderType==OP_SELLSTOP)
         target=openPrice-priceDistance;
      else
         return 0.0;
   return NormalizeDouble(target,Digits);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RegisterPostOrderSLTPVerification(int ticket,double expectedSL,double expectedTP)
  {
   if(!EnablePostOrderSLTPVerification || ticket<=0)
      return;
   for(int i=0; i<MAX_POST_ORDER_SLTP_VERIFY; i++)
      if(PostOrderSLTPVerifyActive[i] && PostOrderSLTPVerifyTicket[i]==ticket)
         return;
   int slot=-1;
   for(int i=0; i<MAX_POST_ORDER_SLTP_VERIFY; i++)
      if(!PostOrderSLTPVerifyActive[i])
        {
         slot=i;
         break;
        }
   if(slot<0)
      return;
   double openPrice=0.0;
   int orderType=-1;
   double lots=0.0;
   if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      openPrice=OrderOpenPrice();
      orderType=OrderType();
      lots=OrderLots();
      if(expectedSL<=0.0)
        {
         if(orderType==OP_BUY)
            expectedSL=openPrice-Slippage-(StopLossUSD*100);
         else
            if(orderType==OP_SELL)
               expectedSL=openPrice+Slippage+(StopLossUSD*100);
        }
      if(expectedTP<=0.0)
        {
         if(orderType==OP_BUY)
            expectedTP=openPrice+Slippage+(DefaultOrderProfitUSD*100);
         else
            if(orderType==OP_SELL)
               expectedTP=openPrice-Slippage-(DefaultOrderProfitUSD*100);
        }
     }
   PostOrderSLTPVerifyActive[slot]=true;
   PostOrderSLTPVerifyTicket[slot]=ticket;
   PostOrderSLTPVerifyCreated[slot]=TimeCurrent();
   PostOrderSLTPVerifyChecked[slot]=false;
   PostOrderSLTPVerifyStatus[slot]="CHECKING";
   PostOrderSLTPVerifyExpectedSL[slot]=expectedSL;
   PostOrderSLTPVerifyExpectedTP[slot]=expectedTP;
   PostOrderSLTPVerifyExpectedOpen[slot]=openPrice;
   PostOrderSLTPVerifyType[slot]=orderType;
   PostOrderSLTPVerifyLots[slot]=lots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PostOrderSLTPWithinTolerance(int orderType,double openPrice,double expectedPrice,double actualPrice,bool isSL)
  {
   if(expectedPrice<=0.0)
      return (actualPrice<=0.0);
   if(actualPrice<=0.0 || openPrice<=0.0)
      return false;
   double expectedDistance=MathAbs(expectedPrice-openPrice);
   double actualDistance=MathAbs(actualPrice-openPrice);
   if(expectedDistance<=Point)
      return (MathAbs(actualPrice-expectedPrice)<=Point);
   double tolerance=expectedDistance*(PostOrderSLTPTolerancePercent/100.0);
   if(MathAbs(actualDistance-expectedDistance)>tolerance)
      return false;
   if(orderType==OP_BUY || orderType==OP_BUYSTOP || orderType==OP_BUYLIMIT)
     {
      if(isSL && actualPrice>=openPrice)
         return false;
      if(!isSL && actualPrice<=openPrice)
         return false;
     }
   else
      if(orderType==OP_SELL || orderType==OP_SELLSTOP || orderType==OP_SELLLIMIT)
        {
         if(isSL && actualPrice<=openPrice)
            return false;
         if(!isSL && actualPrice>=openPrice)
            return false;
        }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetPostOrderSLTPVerificationStatus(int ticket)
  {
   if(ticket<=0)
      return "NOT CHECKED";
   for(int i=0; i<MAX_POST_ORDER_SLTP_VERIFY; i++)
      if(PostOrderSLTPVerifyTicket[i]==ticket)
        {
         if(PostOrderSLTPVerifyStatus[i]!="")
            return PostOrderSLTPVerifyStatus[i];
         if(PostOrderSLTPVerifyActive[i] && !PostOrderSLTPVerifyChecked[i])
            return "CHECKING";
         if(PostOrderSLTPVerifyChecked[i])
            return "CHECKED";
        }
   return "NOT CHECKED";
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessPostOrderSLTPVerification()
  {
   if(!EnablePostOrderSLTPVerification)
      return;
   datetime now=TimeCurrent();
   for(int i=0; i<MAX_POST_ORDER_SLTP_VERIFY; i++)
     {
      if(!PostOrderSLTPVerifyActive[i] || PostOrderSLTPVerifyChecked[i])
         continue;
      if((now-PostOrderSLTPVerifyCreated[i]) < PostOrderSLTPVerificationDelaySeconds)
         continue;
      int ticket=PostOrderSLTPVerifyTicket[i];
      PostOrderSLTPVerifyChecked[i]=true;
      PostOrderSLTPVerifyActive[i]=false;
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
        {
         PostOrderSLTPVerifyStatus[i]="CHECKED";
         continue;
        }
      int orderType=OrderType();
      double openPrice=OrderOpenPrice();
      double actualSL=OrderStopLoss();
      double actualTP=OrderTakeProfit();
      double expectedSL=PostOrderSLTPVerifyExpectedSL[i];
      double expectedTP=PostOrderSLTPVerifyExpectedTP[i];
      double expectedOpen=PostOrderSLTPVerifyExpectedOpen[i];
      double actualPending=openPrice;
      bool isPendingOrder=(orderType==OP_BUYSTOP || orderType==OP_SELLSTOP || orderType==OP_BUYLIMIT || orderType==OP_SELLLIMIT);
      bool pendingPriceOK=true;
      if(isPendingOrder)
         pendingPriceOK=(MathAbs(actualPending-expectedOpen) <= Point*50);
      bool slOK=PostOrderSLTPWithinTolerance(orderType,openPrice,expectedSL,actualSL,true);
      bool tpOK=PostOrderSLTPWithinTolerance(orderType,openPrice,expectedTP,actualTP,false);
      bool allOK=slOK && tpOK;
      if(isPendingOrder)
         allOK=allOK && pendingPriceOK;
      if(allOK)
        {
         PostOrderSLTPVerifyStatus[i]="VERIFIED";
         continue;
        }
      if(!CanSendTradeRequest("PostOrderSLTPVerify","Ticket="+IntegerToString(ticket)))
        {
         PostOrderSLTPVerifyStatus[i]="FAILED";
         continue;
        }
      RefreshRates();
      ResetLastError();
      if(OrderModify(ticket,openPrice,expectedSL,expectedTP,OrderExpiration(),CLR_NONE))
         PostOrderSLTPVerifyStatus[i]="VERIFIED";
      else
         PostOrderSLTPVerifyStatus[i]="FAILED";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetOrderTypeText(int orderType)
  {
   switch(orderType)
     {
      case OP_BUY:
         return "BUY";
      case OP_SELL:
         return "SELL";
      case OP_BUYSTOP:
         return "BUY STOP";
      case OP_SELLSTOP:
         return "SELL STOP";
      case OP_BUYLIMIT:
         return "BUY LIMIT";
      case OP_SELLLIMIT:
         return "SELL LIMIT";
      default:
         return "UNKNOWN";
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDubaiTradingPauseHour() { return false; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradingSloweHours()
  {
   datetime dubaiTime = TimeGMT() + 4 * 60 * 60;
   int currentHour = TimeHour(dubaiTime);
   string hours[];
   int count = StringSplit(DubaiTradingPauseHours, ',', hours);
   if(count <= 0)
      return false;
   for(int i=0; i<count; i++)
     {
      int pauseHour = (int)StringToInteger(hours[i]);
      if(pauseHour == 24)
         pauseHour = 0;
      if(currentHour == pauseHour)
         return true;
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LogDubaiTradingPause() { Print("TRADING PAUSED | Dubai GST"); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetDubaiTradingPauseReason() { return ""; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDubaiTradingPauseDashboard() { }
void RemoveDubaiTradingPauseDashboard() { }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SafeOrderSend(string symbol,int orderType,double lots,double price,int slippage,double stopLoss,double takeProfit,string comment,int magic,color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;
   if(IsDubaiTradingPauseHour())
      return -1;
   if(!IsDayProfitLadderTradingAllowed())
      return -1;

// --- SPREAD FILTER ---
   RefreshRates();
   double currentSpreadUSD = Ask - Bid;
   if(currentSpreadUSD > MaxAllowedSpreadUSD)
     {
      Print("TRADE BLOCKED | Spread too high: $", DoubleToString(currentSpreadUSD, 2), " | Max allowed: $", DoubleToString(MaxAllowedSpreadUSD, 2));
      return -1;
     }

   if(Enable30MinuteMomentumFilter && Enable30MinuteMomentumForAllOrders)
     {
      if(!PassesDeferredMomentum(orderType))
         return QueueDeferredOrder(symbol,orderType,lots,price,slippage,stopLoss,takeProfit,comment,magic,arrowColor);
     }
   string key=MakeTradeErrorKey("SEND",-1,IntegerToString(orderType)+"|"+DoubleToString(lots,8)+"|"+comment);
   if(IsTradeErrorBlockedThisTick(key))
      return -1;
   lots = NormalizeLots(lots);

   double sendPrice=price;
   if(orderType==OP_BUY)
      sendPrice=Ask;
   else
      if(orderType==OP_SELL)
         sendPrice=Bid;
   sendPrice=NormalizeDouble(sendPrice,Digits);
   if(takeProfit<=0.0 && DefaultOrderProfitUSD>0.0)
     {
      double defaultTP=CalculateDefaultProfitTargetPrice(orderType,sendPrice,lots,DefaultOrderProfitUSD);
      if(defaultTP>0.0)
         takeProfit=defaultTP;
     }
   double safeSL=stopLoss;
   if(safeSL>0.0 && !PrepareStopLossForOrder(orderType,sendPrice,safeSL))
     {
      BlockTradeErrorUntilNextTick(key);
      MarkServerError(130,"OrderSend/unsafe-SL");
      return -1;
     }
   datetime requestTime=TimeCurrent();
   if(!CanSendTradeRequest("OrderSend",comment))
      return -1;
   ResetLastError();
   uint tradeStartMs=GetTickCount();
   int ticket=OrderSend(symbol,orderType,lots,sendPrice,slippage,safeSL,takeProfit,comment,magic,0,arrowColor);
   LogTradeTiming("OrderSend",tradeStartMs);
   if(ticket>0)
     {
      InvalidateTotalEAOrdersCache();
      RegisterPostOrderSLTPVerification(ticket,safeSL,takeProfit);
      return ticket;
     }
   int err=GetLastError();
   int existing=FindExistingOrderForRequest(orderType,lots,sendPrice,comment,requestTime);
   if(existing>0)
     {
      if(OrderSelect(existing,SELECT_BY_TICKET,MODE_TRADES))
         RegisterPostOrderSLTPVerification(existing,safeSL,takeProfit);
      ServerRecoveryPending=false;
      return existing;
     }
   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err,"OrderSend");
   return -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SafeOrderClose(int ticket,double lots,int orderType,int slippage,color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;
   string key=MakeTradeErrorKey("CLOSE",ticket,"");
   if(IsTradeErrorBlockedThisTick(key))
      return false;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))
         return true;
      return false;
     }
   RefreshRates();
   double closePrice=(OrderType()==OP_BUY)?Bid:Ask;
   closePrice=NormalizeDouble(closePrice,Digits);
   if(!CanSendTradeRequest("OrderClose","Ticket="+IntegerToString(ticket)))
      return false;
   ResetLastError();
   bool result=OrderClose(ticket,OrderLots(),closePrice,slippage,arrowColor);
   if(result)
     {
      InvalidateTotalEAOrdersCache();
      return true;
     }
   int err=GetLastError();
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
     {
      if(OrderSelect(ticket,SELECT_BY_TICKET,MODE_HISTORY))
         return true;
     }
   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err,"OrderClose");
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SafeOrderModify(int ticket,double openPrice,double stopLoss,double takeProfit,datetime expiration,color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;
   string key=MakeTradeErrorKey("MODIFY",ticket,"");
   if(IsTradeErrorBlockedThisTick(key))
      return false;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return false;
   int orderType=OrderType();
   RefreshRates();
   double requestedSL=stopLoss;
   if(requestedSL>0.0)
     {
      if(!PrepareStopLossForOrder(orderType,OrderOpenPrice(),requestedSL))
        {
         BlockTradeErrorUntilNextTick(key);
         MarkServerError(130,"OrderModify/unsafe-SL");
         return false;
        }
      if(orderType==OP_BUY && OrderStopLoss()>0.0 && requestedSL<=OrderStopLoss())
        {
         BlockTradeErrorUntilNextTick(key);
         return false;
        }
      if(orderType==OP_SELL && OrderStopLoss()>0.0 && requestedSL>=OrderStopLoss())
        {
         BlockTradeErrorUntilNextTick(key);
         return false;
        }
     }
   bool sameSL=(requestedSL<=0.0 && OrderStopLoss()<=0.0) || (requestedSL>0.0 && MathAbs(OrderStopLoss()-requestedSL)<=MinimumSLModifyGapRaw*Point);
   bool sameTP=(takeProfit<=0.0 && OrderTakeProfit()<=0.0) || (takeProfit>0.0 && MathAbs(OrderTakeProfit()-takeProfit)<=Point);
   if(sameSL && sameTP)
      return true;
   ResetLastError();
   if(!CanSendTradeRequest("OrderModify","Ticket="+IntegerToString(ticket)))
      return false;
   bool modified=OrderModify(ticket,openPrice,requestedSL,takeProfit,expiration,arrowColor);
   if(modified)
      return true;
   int err=GetLastError();
   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err,"OrderModify");
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool ReducePendingOrderLotTo01() { return true; }
bool ForceDeletePendingOrder(int ticket,color arrowColor) { return SafeOrderDelete(ticket, arrowColor); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SafeOrderDelete(int ticket,color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;
   string key=MakeTradeErrorKey("DELETE",ticket,"");
   if(IsTradeErrorBlockedThisTick(key))
      return false;
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true;
   int ageSeconds=(int)(TimeCurrent()-OrderOpenTime());
   int requiredAgeSeconds = 6*60*60;
   if(ageSeconds < requiredAgeSeconds)
      return false;
   if(!CanSendTradeRequest("OrderDelete","Ticket="+IntegerToString(ticket)))
      return false;
   ResetLastError();
   bool result=OrderDelete(ticket,arrowColor);
   if(result)
      return true;
   int err=GetLastError();
   if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
      return true;
   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err,"OrderDelete");
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetM5Direction()
  {
   int candles = M5ConfirmationCandles;
   if(candles < 1)
      candles = 1;
   if(candles > 5)
      candles = 5;
   int bullish = 0, bearish = 0;
   for(int shift=1; shift<=candles; shift++)
     {
      double m5Open  = iOpen(Symbol(), PERIOD_M5, shift);
      double m5Close = iClose(Symbol(), PERIOD_M5, shift);
      if(m5Open <= 0.0 || m5Close <= 0.0)
         continue;
      if(m5Close > m5Open)
         bullish++;
      else
         if(m5Close < m5Open)
            bearish++;
     }
   if(bullish > bearish && bullish >= (candles/2 + 1))
      return 1;
   if(bearish > bullish && bearish >= (candles/2 + 1))
      return -1;
   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetM5CandleATRRatio()
  {
   if(!EnableATRVolatilityProtection)
      return 0.0;
   int tf = ATRVolatilityTimeframe;
   if(tf <= 0)
      tf = PERIOD_M5;
   int period = ATRVolatilityPeriod;
   if(period < 2)
      period = 2;
   double high1 = iHigh(Symbol(), tf, 1);
   double low1  = iLow(Symbol(), tf, 1);
   double atr1  = iATR(Symbol(), tf, period, 1);
   if(high1 <= 0.0 || low1 <= 0.0 || atr1 <= 0.0)
      return 0.0;
   return (high1-low1)/atr1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsExtremeVolatility()
  {
   if(!EnableATRVolatilityProtection)
      return false;
   double ratio = GetM5CandleATRRatio();
   double limit = MathMax(0.1, MaxCandleRangeATRMultiple);
   return (ratio > limit);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetMarketMomentLot(int orderType)
  {
   if(orderType != OP_BUY && orderType != OP_SELL)
      return NormalizeLots(OriginalLots);
   int sslDirection = GetCurrentSSLDirection();
   int requestedDirection = (orderType == OP_BUY) ? 1 : -1;
   if(sslDirection != requestedDirection)
      return NormalizeLots(0.01);
   int h1Direction = GetH1Direction();
   bool h1Aligned = (h1Direction == requestedDirection);
   bool h1Opposite = (h1Direction == -requestedDirection);
   int m5Direction = GetM5Direction();
   bool m5Aligned = (m5Direction == requestedDirection);
   int emaShift = InpEMAPriceShift;
   if(emaShift < 0)
      emaShift = 0;
   int chartBars = iBars(Symbol(), Period());
   if(chartBars <= 0)
      chartBars = Bars;
   if(emaShift >= chartBars)
      emaShift = chartBars - 1;
   double ema = iMA(Symbol(), Period(), InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE, emaShift);
   RefreshRates();
   double emaPrice = (emaShift == 0) ? ((orderType == OP_BUY) ? Ask : Bid) : iClose(Symbol(), Period(), emaShift);
   int emaDirection = 0;
   if(ema > 0.0 && emaPrice > 0.0)
     {
      if(emaPrice > ema)
         emaDirection = 1;
      else
         if(emaPrice < ema)
            emaDirection = -1;
     }
   bool emaAligned = (emaDirection == requestedDirection);
   double momentumDiff = Get30MinDifference(orderType);
   double momentumThreshold = MathAbs(Min30MinutePriceDifference);
   bool momentumAligned = false;
   if(orderType == OP_BUY)
      momentumAligned = (momentumDiff > momentumThreshold);
   else
      momentumAligned = (momentumDiff < -momentumThreshold);
   int confirmationScore = 0;
   if(h1Aligned)
      confirmationScore++;
   if(m5Aligned)
      confirmationScore++;
   if(emaAligned)
      confirmationScore++;
   if(momentumAligned)
      confirmationScore++;

// --- STRICT LOT ALLOCATION CURVE ---
   double lot = 0.01;
   if(confirmationScore == 1)
      lot = 0.01;
   else
      if(confirmationScore == 2)
         lot = 0.03;
      else
         if(confirmationScore == 3)
            lot = 0.06;
         else
            if(confirmationScore >= 4)
               lot = 0.10; // Max aggression unlocked

   if(CapLotWhenH1Opposite && h1Opposite)
      lot = MathMin(lot, 0.01);
   bool extremeVolatility = IsExtremeVolatility();
   if(extremeVolatility)
      lot = MathMin(lot, MathAbs(VolatilityLotCap));

// --- WEEKEND RISK CAP ---
   int dayOfWeek = TimeDayOfWeek(TimeCurrent());
   if(dayOfWeek == 0 || dayOfWeek == 6)
     {
      lot = MathMin(lot, 0.02);
     }

   return NormalizeLots(lot);
  }
//+------------------------------------------------------------------+
//| Check if an order with the same type & lot size is nearby        |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check if ANY order (Market or Pending) with same lot is nearby   |
//+------------------------------------------------------------------+
bool IsSameLotOrderNearBy(int orderType, double checkLot, double gapRawThreshold)
  {
   RefreshRates();

// Reference price based on the trade being evaluated
   double currentPrice = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Filter for this EA and symbol
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int existingType = OrderType();

      // Check all valid order types: Market (BUY/SELL) and Pending (STOP/LIMIT)
      if(existingType != OP_BUY && existingType != OP_SELL &&
         existingType != OP_BUYSTOP && existingType != OP_SELLSTOP &&
         existingType != OP_BUYLIMIT && existingType != OP_SELLLIMIT)
         continue;

      // Check if lot size matches (safe float comparison)
      if(MathAbs(OrderLots() - checkLot) > 0.00001)
         continue;

      // Calculate absolute distance between current price and existing order/pending price
      double distance = MathAbs(currentPrice - OrderOpenPrice());

      // If within threshold, trigger safeguard
      if(distance < gapRawThreshold)
        {
         Print("NEARBY ORDER/PENDING DETECTED | Ticket: ", OrderTicket(),
               " | Type: ", GetOrderTypeText(existingType),
               " | Lot: ", DoubleToString(OrderLots(), 2),
               " | Gap: ", DoubleToString(distance, Digits));

         return true; // Match found!
        }
     }

   return false; // No matching order or pending order nearby
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

// Method 1: Decrease Lots
// Method 1: Decrease Lots (Looping)
double CalculateDecreaseLots(int reEntryCounter, double startLot, double endLot)
  {
// Exception Case: Prevent negative counters
   if(reEntryCounter < 0)
     {
      reEntryCounter = 0;
     }

// Calculate total valid steps between start and end
   int totalSteps = (int)MathRound((startLot - endLot) / 0.01) + 1;
   
// Failsafe in case of invalid inputs
   if(totalSteps <= 0) 
      return startLot; 

// Cycle dynamically based on actual steps instead of a hardcoded 10
   int currentStep = reEntryCounter % totalSteps;

// Calculate current lot and normalize to prevent floating-point decimals
   double calculatedLots = startLot - (currentStep * 0.01);

   return NormalizeDouble(calculatedLots, 2);
  }

// Method 2: Increase Lots (Looping)
double CalculateIncreaseLots(int reEntryCounter, double startLot, double endLot)
  {
// Exception Case: Prevent negative counters
   if(reEntryCounter < 0)
     {
      reEntryCounter = 0;
     }

// Calculate total valid steps between start and end
   int totalSteps = (int)MathRound((endLot - startLot) / 0.01) + 1;
   
// Failsafe in case of invalid inputs
   if(totalSteps <= 0) 
      return startLot; 

// Cycle dynamically based on actual steps instead of a hardcoded 10
   int currentStep = reEntryCounter % totalSteps;

// Calculate current lot and normalize to prevent floating-point decimals
   double calculatedLots = startLot + (currentStep * 0.01);

   return NormalizeDouble(calculatedLots, 2);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChangeLots(double OpenPL, string reason, int orderType, int stoplevelStep)
  {
   double MaxRecoveryLot = 0.10;

   double oppositeLots = GetOppositeOrdersLots(orderType);

   bool isSSLSignal =
      (reason == "SSL Long" || reason == "SSL Short");

   bool isSSLProfitReEntry =
      (reason == "SSL Profit ReEntry Buy Stop" ||
       reason == "SSL Profit ReEntry Sell Stop");

//==================================================
// BASE LOT CALCULATION
//==================================================
   if(isSSLSignal)
     {
      Lots = GetMarketMomentLot(orderType);

      // if(GlobalBUYSELLdashboardScore>=2 && GetCurrentSSLDirection() == EMADirection)
      if(GetCurrentSSLDirection() == EMADirection || GlobalBUYSELLdashboardScore==4)

         Lots=0.10;
      else
         Lots=0.01;

     }
   else
     {
      if(isSSLProfitReEntry)
        {
         Lots = 0.10;

         // if(reEntryCounter > 2)

         if(GetCurrentSSLDirection() == EMADirection)
           {
            // Start at 0.10 and decrease until it hits the floor of 0.01
            Lots = CalculateDecreaseLots(reEntryCounter, 0.05, 0.01);
           }
         else
           {
            // Start at 0.01 and increase until it hits the ceiling of 0.05
            Lots = CalculateIncreaseLots(reEntryCounter, 0.01, 0.05);
           }

         // if(reEntryCounter > 3) { Lots = Lots - (reEntryCounter * 0.01); if(Lots < 0.01) Lots = 0.01; }
        }
      /* else
         {
          if(oppositeLots <= 0.0)
             Lots = NormalizeLots(0.02);
          else
             if(OpenPL < -0.50)
                Lots = NormalizeLots(0.03);
             else
                Lots = NormalizeLots(OriginalLots);
         }*/


      //
      //==================================================
      // SSL / EMA REVERSE DIRECTION OVERRIDE
      //==================================================
      /*
          bool sslEmaMismatch = (GetCurrentSSLDirection() != EMADirection);

          if(sslEmaMismatch && Lots<0.05 && reEntryCounter >= 2)
            {

                Lots = 0.05;

            }
      */

      //==================================================
      // DASHBOARD SCORE PROTECTION
      //==================================================
      // if(GlobalBUYSELLdashboardScore <= 1)
      //    Lots = 0.01;

      // if(IsTradingSloweHours() &&
      //    GlobalBUYSELLdashboardScore <= 2)
      //   {
      //    Lots = 0.01;
      //   }


     }// ReEntry
   /*

   //==================================================
   // STRONG MOMENTUM OVERRIDE
   //==================================================
      if((orderType == OP_BUY || orderType == OP_SELL) &&
         IsStrongMomentum(orderType))
        {
         // Lots = 0.10;

         int dayOfWeek = TimeDayOfWeek(TimeCurrent());

         // Weekend protection
         if(dayOfWeek == 0 || dayOfWeek == 6)
           {
            Lots = MathMin(Lots, 0.02);
           }
        }

        */


   if(Lots>0.05 && IsSameLotOrderNearBy(orderType,Lots,100))
     {
      Lots=0.02;//
     }


//==================================================
// BALANCE LOT MULTIPLIER
//==================================================
   int balancelomultipler =
      (int)(AccountBalance() / AccountMultiplierLOT);

   if(balancelomultipler < 1)
      balancelomultipler = 1;

   Lots = Lots * balancelomultipler;


//==================================================
// MAX LOT PROTECTION
//==================================================
   if(Lots > MaxRecoveryLot)
      Lots = MaxRecoveryLot;

   Lots = NormalizeLots(Lots);

   if(Lots < 0.01)
      Lots = 0.01;


//==================================================
// DYNAMIC SL / LADDER VALUES
//==================================================
   StopLossUSD =
      OriginalStopLossUSD * Lots * 100;

   Ladder1ProfitUSD =
      OriginalLadder1ProfitUSD * Lots * 100;

   Ladder2ProfitUSD =
      OriginalLadder2ProfitUSD * Lots * 100;

   Ladder1StopMaxPriceUSD =
      OriginalLadder1StopMaxPriceUSD * Lots * 100;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check Recovery Orders (With Strict Momentum Confirmation)        |
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
      
      int parentTicket = OrderTicket();
      int parentType   = OrderType();
      
      if(parentType != OP_BUY && parentType != OP_SELL)
         continue;
         
      string comment = OrderComment();
      if(StringFind(comment, "RECOVERY_") == 0)
         continue;
         
      bool validParent = false;
      if(StringFind(comment, "SSL Long") >= 0 || StringFind(comment, "SSL Short") >= 0 || StringFind(comment, "ReEntry") >= 0)
         validParent = true;
      if(!validParent)
         continue;
         
      if(HasRecoveryOrder(parentTicket))
         continue;
         
      double profit = OrderProfit() + OrderSwap() + OrderCommission();
      double lots = NormalizeLots(OrderLots() * RecoveryLotMultiplier);
      if(lots <= 0)
         continue;
         
      double recoveryTrigger = -MathAbs(RecoveryTriggerLossUSD) * (lots / 0.01);
      if(profit > recoveryTrigger)
         continue;
         
      // --- STRICT MOMENTUM CONFIRMATION LOGIC ---
      if(parentType == OP_BUY)
        {
         // Wait for SSL to flip back to Buy AND require strong ADX/Candle momentum
         if(!IsBuySignal(0) || !IsStrongMomentum(OP_BUY))
            continue; 
        }
      else
        {
         // Wait for SSL to flip back to Sell AND require strong ADX/Candle momentum
         if(!IsSellSignal(0) || !IsStrongMomentum(OP_SELL))
            continue;
        }
      // ------------------------------------------
        
      if(!IsOneCandleOrderAllowed() || HasRecoveryOrder(parentTicket))
         continue;

      int recoveryTicket = -1;
      
      double slDistance = CalculatePriceDistanceUSD(StopLossUSD, lots);
      double recoverySL = 0.0;
      
      if(parentType == OP_BUY)
        {
         recoverySL = (slDistance > 0) ? NormalizeDouble(Ask - slDistance, Digits) : 0;
         recoveryTicket = SafeOrderSend(Symbol(), OP_BUY, lots, Ask, Slippage, recoverySL, 0, "RECOVERY_" + IntegerToString(parentTicket), MagicNumber, clrAqua);
        }
      else
        {
         recoverySL = (slDistance > 0) ? NormalizeDouble(Bid + slDistance, Digits) : 0;
         recoveryTicket = SafeOrderSend(Symbol(), OP_SELL, lots, Bid, Slippage, recoverySL, 0, "RECOVERY_" + IntegerToString(parentTicket), MagicNumber, clrOrange);
        }

      if(recoveryTicket > 0)
        {
         OrderCreatedThisCandle = true;
         LastOrderCandleTime    = Time[0];
        }
      break;
     }
  }
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
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
         
      string comment = OrderComment();
      if(StringFind(comment,"RECOVERY_") != 0)
         continue;
         
      // Save Recovery Order details before selecting parent
      int recoveryTicket = OrderTicket();
      double recoveryLots = OrderLots();
      int recoveryType = OrderType();
      double recoveryProfit = OrderProfit() + OrderSwap() + OrderCommission();
      
      int parentTicket = StrToInteger(StringSubstr(comment, StringLen("RECOVERY_")));
      
      // Select the parent order
      if(!OrderSelect(parentTicket,SELECT_BY_TICKET))
         continue;
      if(OrderCloseTime()>0)
         continue;
         
      // Save Parent Order details
      double parentLots = OrderLots();
      int parentType = OrderType();
      double parentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      
      double basketProfit = recoveryProfit + parentProfit;
      
      // FIX 3: Close BOTH the parent and the recovery order simultaneously
      if(basketProfit >= RecoveryBasketProfitUSD)
        {
         SafeOrderClose(parentTicket, parentLots, parentType, Slippage, (parentType==OP_BUY ? clrRed : clrBlue));
         SafeOrderClose(recoveryTicket, recoveryLots, recoveryType, Slippage, (recoveryType==OP_BUY ? clrRed : clrBlue));
        }
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
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      if(OrderComment()==txt)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageRecoveryBasketold()
  {
   if(!EnableRecoveryOrders)
      return;
   for(int i = OrdersTotal()-1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      string comment = OrderComment();
      if(StringFind(comment,"RECOVERY_") != 0)
         continue;
      int parentTicket = StrToInteger(StringSubstr(comment, StringLen("RECOVERY_")));
      double recoveryProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(!OrderSelect(parentTicket,SELECT_BY_TICKET))
         continue;
      if(OrderCloseTime()>0)
         continue;
      double parentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      double basketProfit = recoveryProfit + parentProfit;
      if(basketProfit >= RecoveryBasketProfitUSD)
        {
         int closeType=OrderType();
         SafeOrderClose(OrderTicket(), OrderLots(), closeType, Slippage, (closeType==OP_BUY ? clrRed : clrBlue));
         return;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetDayProfitLadderGVPrefix() { return "SSL_DPL_" + IntegerToString(AccountNumber()) + "_" + IntegerToString(MagicNumber) + "_" + Symbol() + "_"; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetDayProfitLadderDateText() { return TimeToString(TimeCurrent(), TIME_DATE); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetDayProfitLadderDate() { return StrToTime(GetDayProfitLadderDateText()); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SaveDayProfitLadderState() { return; }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDayProfitLadderTarget(int stage)
  {
   if(stage <= 0 || DayProfitLadderStartBalance <= 0.0)
      return DayProfitLadderStartBalance;
   double step = MathAbs(DayProfitLadder1Percent) / 100.0;
   if(step <= 0.0)
      return DayProfitLadderStartBalance;
   return DayProfitLadderStartBalance * (1.0 + step * stage);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDayProfitLadderTarget111(int stage)
  {
   if(DayProfitLadderStartBalance <= 0.0)
      return 0.0;
   if(stage <= 0)
      return DayProfitLadderStartBalance;
   double stepAmount = MathAbs(DayProfitLadder1Amount);
   if(stepAmount <= 0.0)
      return DayProfitLadderStartBalance;
   return DayProfitLadderStartBalance + (stepAmount * stage);
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDayProfitLadderProtection(int stage)
  {
   if(DayProfitLadderStartBalance<=0.0)
      return 0.0;
   if(stage<=0)
      return DayProfitLadderStartBalance * (1.0-DayProfitInitialProtectionPercent/100.0);
   double step=MathAbs(DayProfitLadder1Percent)/100.0;
   double protectionLockRatio=0.50;
   double accumulatedProfit= DayProfitLadderStartBalance * step * stage;
   return DayProfitLadderStartBalance + (accumulatedProfit*protectionLockRatio);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDayProfitLadder()
  {
   DayProfitLadderDate = GetDayProfitLadderDate();
   DailyProtectionStartTime = TimeCurrent();
   DayProfitLadderStartBalance = AccountBalance();
   DayProfitLadderStartEquity  = AccountEquity();
   DayProfitLadderStage = 0;
   DayProfitLadderTradingStopped = false;
   DayProfitLadderTargetReachedCandle = 0;
   DayProfitLadderResumePending = false;
   DayProfitLadderResumeDirection = 0;
   DayProfitLadderResumeTradeAttempt = false;
   DayProfitLadderTargetCleanupPending = false;
   DayProfitLadderNextTargetEquity = GetDayProfitLadderTarget(1);
   DayProfitLadderProtectionEquity = DayProfitLadderStartBalance * (1.0 - DayProfitInitialProtectionPercent / 100.0);
   DayProfitLadderInitialized = true;
   SaveDayProfitLadderState();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void LoadDayProfitLadderState() { InitializeDayProfitLadder(); }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAndDeleteAllEAOrdersOnTradingStop()
  {
   int freshPendingTickets[1000];
   int freshPendingCount = 0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
        {
         if(freshPendingCount < 1000)
            freshPendingTickets[freshPendingCount++]=OrderTicket();
        }
     }
   int freshOpenTickets[1000];
   int freshOpenCount=0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int marketType=OrderType();
      if(marketType==OP_BUY || marketType==OP_SELL)
        {
         if(freshOpenCount < 1000)
            freshOpenTickets[freshOpenCount++]=OrderTicket();
        }
     }
   for(int k=0; k<freshOpenCount; k++)
     {
      int ticket=freshOpenTickets[k];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)
         continue;
      double lots=OrderLots();
      SafeOrderClose(ticket,lots,type,Slippage,(type==OP_BUY ? clrRed : clrBlue));
     }
   for(int p=0; p<freshPendingCount; p++)
     {
      int pendingTicket=freshPendingTickets[p];
      if(!OrderSelect(pendingTicket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int pendingType=OrderType();
      if(pendingType!=OP_BUYSTOP && pendingType!=OP_SELLSTOP && pendingType!=OP_BUYLIMIT && pendingType!=OP_SELLLIMIT)
         continue;
      SafeOrderDelete(pendingTicket,clrRed);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CloseAllEAOrdersForLadderReset()
  {
   bool anyRemaining = false;
   int marketTickets[1000];
   int marketCount = 0;
   int pendingTickets[1000];
   int pendingCount = 0;
   if(DayProfitLadderCleanupStartTime > 0)
     {
      if((int)(TimeCurrent() - DayProfitLadderCleanupStartTime) >= LADDER_CLEANUP_TIMEOUT_SECONDS)
        {
         DayProfitLadderCleanupStartTime = 0;
         return true;
        }
     }
   else
      DayProfitLadderCleanupStartTime = TimeCurrent();

   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type==OP_BUY || type==OP_SELL)
        {
         if(marketCount<1000)
            marketTickets[marketCount++]=OrderTicket();
        }
      else
         if(type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
           {
            if(pendingCount<1000)
               pendingTickets[pendingCount++]=OrderTicket();
           }
     }
   for(int m=0; m<marketCount; m++)
     {
      int ticket=marketTickets[m];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL)
         continue;
      double lots=OrderLots();
      if(!SafeOrderClose(ticket,lots,type,Slippage,(type==OP_BUY ? clrRed : clrBlue)))
         anyRemaining=true;
     }
   for(int q=0; q<pendingCount; q++)
     {
      int ticket=pendingTickets[q];
      if(!OrderSelect(ticket,SELECT_BY_TICKET,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      if(!SafeOrderDelete(ticket,clrRed))
         anyRemaining=true;
     }
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber)
        {
         anyRemaining=true;
         break;
        }
     }
   if(anyRemaining)
      return false;
   DayProfitLadderCleanupStartTime = 0;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CreateDayProfitLadderPending(int direction)
  {
   if(!EnableTrading || DayProfitLadderTradingStopped)
      return false;
   if(direction!=OP_BUY && direction!=OP_SELL)
      return false;
   if(ServerRecoveryPending || !IsConnected() || GetTotalEAOrders() >= MaxOpenOrders)
      return false;
   RefreshRates();
   int pendingType=(direction==OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   double minimumGap=GetRequiredStopDistance();
   double gap=MathAbs(ProfitReEntryGapRaw);
   if(gap<minimumGap)
      gap=minimumGap;
   double entryPrice=0.0;
   if(direction==OP_BUY)
      entryPrice=Ask+gap;
   else
      entryPrice=Bid-gap;
   entryPrice=NormalizeDouble(entryPrice,Digits);
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(0.0, direction==OP_BUY ? "Day Ladder Buy Stop" : "Day Ladder Sell Stop", direction, 0);
   Lots=NormalizeLots(Lots);
   if(Lots<=0.0)
      return false;
   double slDistance=CalculatePriceDistanceUSD(StopLossUSD,Lots);
   if(slDistance<=0.0)
      return false;
   double stopLoss=(direction==OP_BUY) ? (entryPrice-slDistance) : (entryPrice+slDistance);
   stopLoss=NormalizeDouble(stopLoss,Digits);
   string comment=(direction==OP_BUY) ? "Day Ladder Buy Stop" : "Day Ladder Sell Stop";
   color orderColor=(direction==OP_BUY) ? BuyColor : SellColor;
   int ticket=SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, 0, comment, MagicNumber, orderColor);
   if(ticket<0)
      return false;
   InvalidateTotalEAOrdersCache();
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageDayProfitLadder()
  {
   if(!EnableDayProfitLadder)
      return;
   datetime today = GetDayProfitLadderDate();
   if(!DayProfitLadderInitialized || DayProfitLadderDate != today)
     {
      InitializeDayProfitLadder();
      return;
     }
   if(DayProfitLadderTradingStopped)
     {
      CloseAndDeleteAllEAOrdersOnTradingStop();
      return;
     }
   if(DayProfitLadderStartBalance <= 0.0)
      return;
   double equity = AccountEquity();
   double step = MathAbs(DayProfitLadder1Percent) / 100.0;
   if(step > 0.0 && equity >= DayProfitLadderStartBalance * (1.0 + step))
     {
      double profitRatio = (equity / DayProfitLadderStartBalance) - 1.0;
      int reachedStage = (int)MathFloor((profitRatio / step) + 0.000000001);
      if(reachedStage > DayProfitLadderStage)
        {
         DayProfitLadderStage = reachedStage;
         DayProfitLadderTargetReachedCandle = Time[0];
         DayProfitLadderResumeDirection = GetCurrentSSLDirection();
         if(DayProfitLadderResumeDirection == 0)
            DayProfitLadderResumeDirection = LastLiveSSLDirection;
         DayProfitLadderTargetCleanupPending = true;
         DayProfitLadderResumePending = (DayProfitLadderResumeDirection != 0);
         DayProfitLadderProtectionEquity = GetDayProfitLadderProtection(DayProfitLadderStage);
         DayProfitLadderNextTargetEquity = GetDayProfitLadderTarget(DayProfitLadderStage + 1);
         SaveDayProfitLadderState();
        }
     }
   if(equity <= DayProfitLadderProtectionEquity)
     {
      DayProfitLadderTradingStopped = true;
      DayProfitLadderTargetReachedCandle = 0;
      DayProfitLadderResumePending = false;
      DayProfitLadderResumeDirection = 0;
      DayProfitLadderResumeTradeAttempt = false;
      DayProfitLadderTargetCleanupPending = false;
      SaveDayProfitLadderState();
      CloseAndDeleteAllEAOrdersOnTradingStop();
      for(int dpl_i=0; dpl_i<MAX_DEFERRED_ORDERS; dpl_i++)
         DeferredActive[dpl_i]=false;
      EquityResetReEntryPending=false;
      ReEntryRetryPending=false;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDayProfitLadderTradingAllowed()
  {
   if(!EnableDayProfitLadder)
      return true;
   ManageDayProfitLadder();
   if(DayProfitLadderTradingStopped)
      return false;
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InitializeDailyProtectionState(DailyProtectionState &state)
  {
   ManageDayProfitLadder();
   state.DayDate = DayProfitLadderDate;
   state.DayStartBalance = DayProfitLadderStartBalance;
   state.DayProtectedBalance = DayProfitLadderProtectionEquity;
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
   state.TradingStopped = DayProfitLadderTradingStopped;
   state.Initialized = true;
   DailyProtectionStartTime = TimeCurrent();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void StartProtectedEquityWait()
  {
   ProtectedEquityWaitActive = true;
   ProtectedEquityWaitStartTime = TimeCurrent();
   EquityResetReEntryPending = false;
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
//|                                                                  |
//+------------------------------------------------------------------+
void QueueEquityResetReEntry()
  {
   EquityResetReEntryPending = true;
   OrderCreatedThisCandle = false;
   LastOrderCandleTime = 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ProcessEquityResetReEntry(DailyProtectionState &state)
  {
   if(!EquityResetReEntryPending || !EnableTrading || IsDailyTradingStopped(state) || Bars < SSLPeriod + 20)
      return;
   if(GetTotalEAOrders() > 0)
     {
      EquityResetReEntryPending = false;
      return;
     }
   if(GetTotalEAOrders() >= MaxOpenOrders)
      return;
   int currentDirection = GetCurrentSSLDirection();
   if(currentDirection > 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime = 0;
      DrawLiveSignal(0, true);
      int beforeOrders = GetTotalEAOrders();
      OpenBuy();
      int afterOrders = GetTotalEAOrders();
      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;
        }
      return;
     }
   if(currentDirection < 0)
     {
      OrderCreatedThisCandle = false;
      LastOrderCandleTime = 0;
      DrawLiveSignal(0, false);
      int beforeOrders = GetTotalEAOrders();
      OpenSell();
      int afterOrders = GetTotalEAOrders();
      if(afterOrders > beforeOrders)
        {
         EquityResetReEntryPending = false;
         TradeResetThisTick = true;
        }
      return;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDailyLossProtection(DailyProtectionState &state)
  {
   if(!EnableDayProfitLadder)
      return;
   state.DayDate = DayProfitLadderDate;
   state.DayStartBalance = DayProfitLadderStartBalance;
   state.DayProtectedBalance = DayProfitLadderProtectionEquity;
   state.TradingStopped = DayProfitLadderTradingStopped;
   state.ClosedOrdersToday = CountClosedOrdersSinceInitialization();
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

bool IsDailyTradingStopped(DailyProtectionState &state) { return EnableDayProfitLadder && DayProfitLadderTradingStopped; }

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
         SafeOrderDelete(OrderTicket(), clrYellow);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newSignalType)
  {
   if(!EAStartupComplete)
      return;
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
      if(orderPL > closeOppositeLossThreshold)
         continue;
      if((newSignalType == OP_BUY && orderType == OP_SELL) || (newSignalType == OP_SELL && orderType == OP_BUY))
        {
         SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
        }
     }
  }

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
//+------------------------------------------------------------------+
//| Check For Profitable Closed Order (With 60-Min Lifespan Limit)   |
//+------------------------------------------------------------------+
void CheckForProfitableClosedOrder(DailyProtectionState &state)
  {
   datetime latestCloseTime = 0;
   double latestProfit = 0;
   int latestTicket = -1, latestType = -1;
   double latestClosePrice = 0;
   datetime latestOpenTime = 0; // Added to track when the order opened

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
      latestOpenTime = OrderOpenTime(); // Capture the open time
     }
     
   if(latestTicket < 0)
      return;
   if(latestTicket == LastProcessedClosedTicket && latestCloseTime == LastProcessedClosedOrderTime)
      return;
      
   LastProcessedClosedTicket = latestTicket;
   LastProcessedClosedOrderTime = latestCloseTime;

   if(EnableProfitReEntryStop && !IsDailyTradingStopped(state))
     {
      // --- THE FIX: Calculate lifespan and block if >= 60 mins ---
      int orderDurationSeconds = (int)(latestCloseTime - latestOpenTime);
      
      if(orderDurationSeconds < 3600) // 3600 seconds = 60 minutes
        {
         CreateProfitReEntryStop(latestType, latestClosePrice, state, (latestProfit < 0.0));
        }
      else
        {
         Print("Re-entry BLOCKED: Order ", latestTicket, " was open for ", orderDurationSeconds / 60, " minutes.");
        }
      // -------------------------------------------------------------
      return;
     }
     
   if(EnableTrading && !IsDailyTradingStopped(state))
     {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(0))
         OpenBuy();
      if(GetTotalSellOrders() == 0 && IsSellSignal(0))
         OpenSell();
     }
  }
void CheckForProfitableClosedOrderold(DailyProtectionState &state)
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
   if(EnableProfitReEntryStop && !IsDailyTradingStopped(state))
     {
      CreateProfitReEntryStop(latestType, latestClosePrice, state, (latestProfit < 0.0));
      return;
     }
   if(EnableTrading && !IsDailyTradingStopped(state))
     {
      if(GetTotalBuyOrders() == 0 && IsBuySignal(0))
         OpenBuy();
      if(GetTotalSellOrders() == 0 && IsSellSignal(0))
         OpenSell();
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasPendingProfitReEntry(int pendingType)
  {
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber || OrderType()!=pendingType)
         continue;
      if(StringFind(OrderComment(),"SSL Profit ReEntry",0)==0)
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CreateProfitReEntryStop(int closedOrderType, double closedPrice, DailyProtectionState &state, bool afterStopLoss=false)
  {
   if(!EnableTrading || !EnableProfitReEntryStop || IsDailyTradingStopped(state))
      return;
   if(ServerRecoveryPending || !IsConnected())
     {
      ReEntryRetryPending=true;
      ReEntryRetryClosedType=closedOrderType;
      ReEntryRetryClosedPrice=closedPrice;
      return;
     }
   if(HasBasketNewOrderLossLimit() || IsDirectionBlockedAfterSL(closedOrderType) || GetTotalEAOrders() >= MaxOpenOrders || (MaxSameDirectionOrders > 0 && CountDirectionOrders(closedOrderType) >= MaxSameDirectionOrders))
      return;
   RefreshRates();
   double entryPrice = (closedOrderType == OP_BUY) ? (closedPrice + ProfitReEntryGapRaw) : (closedPrice - ProfitReEntryGapRaw);
   int pendingType = (closedOrderType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   color orderColor = (closedOrderType == OP_BUY) ? BuyColor : SellColor;
   string orderComment = (closedOrderType == OP_BUY) ? "SSL Profit ReEntry Buy Stop" : "SSL Profit ReEntry Sell Stop";
   double minimumGap = GetRequiredStopDistance();
   if(pendingType == OP_BUYSTOP && entryPrice < Ask + minimumGap)
      entryPrice = Ask + minimumGap;
   if(pendingType == OP_SELLSTOP && entryPrice > Bid - minimumGap)
      entryPrice = Bid - minimumGap;
   entryPrice = NormalizeDouble(entryPrice, Digits);
   ResetLastError();
   if(afterStopLoss)
      Lots = NormalizeLots(0.01);
   else
     {
      if(pendingType == OP_BUYSTOP)
         ChangeLots(GetOpenPL(OP_SELL), "SSL Profit ReEntry Buy Stop", OP_BUY,0);
      else
         ChangeLots(GetOpenPL(OP_BUY), "SSL Profit ReEntry Sell Stop", OP_SELL,0);
     }
   int requestedReEntryNumber = reEntryCounter + 1;
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;
   double stopLoss = (pendingType == OP_BUYSTOP) ? (entryPrice - slDistance) : (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);
   int ticket = SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, 0, orderComment, MagicNumber, orderColor);
   if(ticket < 0)
     {
      if(ServerRecoveryPending)
        {
         ReEntryRetryPending=true;
         ReEntryRetryClosedType=closedOrderType;
         ReEntryRetryClosedPrice=closedPrice;
        }
     }
   else
     {
      reEntryCounter=requestedReEntryNumber;
      SaveReEntryCounter();
      ReEntryRetryPending=false;
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
   if(CachedTotalEAOrdersTick==CurrentTickSequence && CachedTotalEAOrders>=0)
      return CachedTotalEAOrders;
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int type = OrderType();
      if(type==OP_BUY || type==OP_SELL || type==OP_BUYSTOP || type==OP_SELLSTOP || type==OP_BUYLIMIT || type==OP_SELLLIMIT)
         count++;
     }
   CachedTotalEAOrders=count;
   CachedTotalEAOrdersTick=CurrentTickSequence;
   return count;
  }

void InvalidateTotalEAOrdersCache() { CachedTotalEAOrders=-1; CachedTotalEAOrdersTick=-1; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenBuy()
  {
   if(!IsSafeToCreateMarketOrder(OP_BUY) || !PassesEMAFilter(OP_BUY) || !IsOneCandleOrderAllowed() || GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_BUY))
      return;
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(GetOpenPL(OP_SELL),"SSL Long",OP_BUY,0);
   RefreshRates();
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;
   double stopLoss = NormalizeDouble(Ask - slDistance, Digits);
   int ticket = SafeOrderSend(Symbol(), OP_BUY, Lots, Ask, Slippage, stopLoss, 0, "SSL Long", MagicNumber, BuyColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
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
   if(!IsSafeToCreateMarketOrder(OP_SELL) || !PassesEMAFilter(OP_SELL) || !IsOneCandleOrderAllowed() || GetTotalEAOrders() >= MaxOpenOrders || !HasMinimumSameOrderGap(OP_SELL))
      return;
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(GetOpenPL(OP_BUY),"SSL Short",OP_SELL,0);
   RefreshRates();
   double slDistance = CalculatePriceDistanceUSD(StopLossUSD, Lots);
   if(slDistance <= 0)
      return;
   double stopLoss = NormalizeDouble(Bid + slDistance, Digits);
   int ticket = SafeOrderSend(Symbol(), OP_SELL, Lots, Bid, Slippage, stopLoss, 0, "SSL Short", MagicNumber, SellColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
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
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         continue;
      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(currentProfit <= 0)
         continue;
      double orderLots = OrderLots();
      if(orderLots <= 0)
         continue;

      // --- INSTANT BREAK-EVEN FOR HIGH LOTS (>= 0.04) ---
      // if(orderLots >= 0.04 && currentProfit >= 0.50)
      //   {
      //    double breakEvenPrice = (orderType == OP_BUY) ? (OrderOpenPrice() + Point * 10) : (OrderOpenPrice() - Point * 10);
      //    breakEvenPrice = NormalizeDouble(breakEvenPrice, Digits);
      //    bool needsBE = (orderType == OP_BUY) ? (OrderStopLoss() < OrderOpenPrice()) : (OrderStopLoss() > OrderOpenPrice() || OrderStopLoss() == 0);
      //    if(needsBE)
      //      {
      //       SafeOrderModify(OrderTicket(), OrderOpenPrice(), breakEvenPrice, OrderTakeProfit(), 0, clrGold);
      //       Print("INSTANT BREAK-EVEN APPLIED | Ticket: ", OrderTicket(), " | Lots: ", orderLots);
      //      }
      //   }

      double ladder1Profit = OriginalLadder1ProfitUSD * orderLots * 100.0;
      double ladder2Profit = OriginalLadder2ProfitUSD * orderLots * 100.0;
      double ladder1StopMaxPrice = OriginalLadder1StopMaxPriceUSD * orderLots * 100.0;
      double lockedProfit = 0.0;

      if(EnableProfitLadder1 && ladder1Profit > 0 && currentProfit < ladder1StopMaxPrice)
        {
         int ladder1Level = (int)MathFloor(currentProfit / ladder1Profit);
         if(ladder1Level >= 1)
            lockedProfit = ladder1Level * ladder1Profit;
        }
      if(EnableProfitLadder2 && ladder2Profit > 0 && currentProfit >= ladder1StopMaxPrice)
        {
         int ladder2Level = (int)MathFloor(currentProfit / ladder2Profit);
         if(ladder2Level >= 1)
            lockedProfit = ladder2Level * ladder2Profit;
        }
      if(lockedProfit <= 0)
         continue;
      lockedProfit = NormalizeDouble(lockedProfit, 2);

      double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
      double tickSize = MarketInfo(Symbol(), MODE_TICKSIZE);
      if(tickValue <= 0 || tickSize <= 0)
         continue;

      double existingLockedProfit = 0.0;
      if(OrderStopLoss() > 0)
        {
         double existingPriceDistance = 0.0;
         if(orderType == OP_BUY)
            existingPriceDistance = OrderStopLoss() - OrderOpenPrice();
         if(orderType == OP_SELL)
            existingPriceDistance = OrderOpenPrice() - OrderStopLoss();
         if(existingPriceDistance > 0)
           {
            existingLockedProfit = (existingPriceDistance / tickSize) * tickValue * orderLots;
            existingLockedProfit = NormalizeDouble(existingLockedProfit, 2);
           }
        }

      double nextProfitTargetUSD=0.0;
      if(EnableProfitLadder1 && ladder1Profit>0.0 && currentProfit<ladder1StopMaxPrice)
        {
         int nextL1Level=(int)MathFloor(currentProfit/ladder1Profit)+1;
         nextProfitTargetUSD=nextL1Level*ladder1Profit;
        }
      else
         if(EnableProfitLadder2 && ladder2Profit>0.0)
           {
            int nextL2Level=(int)MathFloor(currentProfit/ladder2Profit)+1;
            nextProfitTargetUSD=nextL2Level*ladder2Profit;
           }

      double desiredTakeProfit=OrderTakeProfit();
      if(nextProfitTargetUSD>0.0)
        {
         double nextTP=CalculateDefaultProfitTargetPrice(orderType, OrderOpenPrice(), orderLots, nextProfitTargetUSD);
         double minimumTPDistance=GetRequiredStopDistance();
         if(nextTP>0.0)
           {
            bool validNextTP=true;
            if(orderType==OP_BUY && nextTP-Ask<minimumTPDistance)
               validNextTP=false;
            if(orderType==OP_SELL && Bid-nextTP<minimumTPDistance)
               validNextTP=false;
            if(validNextTP)
              {
               if(orderType==OP_BUY)
                 {
                  if(desiredTakeProfit<=0.0 || nextTP>desiredTakeProfit+Point)
                     desiredTakeProfit=nextTP;
                 }
               else
                  if(orderType==OP_SELL)
                    {
                     if(desiredTakeProfit<=0.0 || nextTP<desiredTakeProfit-Point)
                        desiredTakeProfit=nextTP;
                    }
              }
           }
        }

      bool takeProfitNeedsModify=false;
      if(orderType==OP_BUY)
        {
         if(desiredTakeProfit>0.0 && (OrderTakeProfit()<=0.0 || desiredTakeProfit>OrderTakeProfit()+Point))
            takeProfitNeedsModify=true;
        }
      else
         if(orderType==OP_SELL)
           {
            if(desiredTakeProfit>0.0 && (OrderTakeProfit()<=0.0 || desiredTakeProfit<OrderTakeProfit()-Point))
               takeProfitNeedsModify=true;
           }

      if(existingLockedProfit>=lockedProfit && !takeProfitNeedsModify)
         continue;
      double priceDistance = (lockedProfit / (tickValue * orderLots)) * tickSize;
      if(priceDistance <= 0)
         continue;
      double stopLevel = GetRequiredStopDistance();
      double newStopLoss = 0.0;
      bool needStopLossModify = (existingLockedProfit < lockedProfit);

      if(orderType == OP_BUY)
        {
         if(!needStopLossModify)
            newStopLoss=OrderStopLoss();
         else
           {
            newStopLoss = OrderOpenPrice() + priceDistance;
            newStopLoss = NormalizeDouble(newStopLoss, Digits);
            if(OrderStopLoss() > 0 && newStopLoss <= OrderStopLoss())
               continue;
            if(Bid - newStopLoss < stopLevel)
              {
               newStopLoss = Bid - stopLevel;
               newStopLoss = NormalizeDouble(newStopLoss, Digits);
              }
            if(newStopLoss <= 0 || newStopLoss >= Bid)
               continue;
            if(OrderStopLoss() > 0 && MathAbs(newStopLoss - OrderStopLoss()) < Point)
               continue;
           }
         ResetLastError();
         SafeOrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, desiredTakeProfit, 0, clrLimeGreen);
        }

      if(orderType == OP_SELL)
        {
         if(!needStopLossModify)
            newStopLoss=OrderStopLoss();
         else
           {
            newStopLoss = OrderOpenPrice() - priceDistance;
            newStopLoss = NormalizeDouble(newStopLoss, Digits);
            if(OrderStopLoss() > 0 && newStopLoss >= OrderStopLoss())
               continue;
            if(newStopLoss - Ask < stopLevel)
              {
               newStopLoss = Ask + stopLevel;
               newStopLoss = NormalizeDouble(newStopLoss, Digits);
              }
            if(newStopLoss <= Ask)
               continue;
            if(OrderStopLoss() > 0 && MathAbs(newStopLoss - OrderStopLoss()) < Point)
               continue;
           }
         ResetLastError();
         SafeOrderModify(OrderTicket(), OrderOpenPrice(), newStopLoss, desiredTakeProfit, 0, clrTomato);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CalculateSSL(int shift, double &sslUp, double &sslDown, int &hlv)
  {
   int oldest = MathMin(50, Bars - SSLPeriod - 2);
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
//|                                                                  |
//+------------------------------------------------------------------+
int GetCurrentSSLDirection()
  {
   if(Bars < SSLPeriod + 20)
      return 0;
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
bool IsLiveBuySignal() { return IsBuySignal(0); }
bool IsLiveSellSignal() { return IsSellSignal(0); }

//+------------------------------------------------------------------+
//|                                                                  |
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
double GetTotalLots(int orderType)
  {
   double lots=0.0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber || OrderType()!=orderType)
         continue;
      lots+=OrderLots();
     }
   return lots;
  }

int EMADirection=0;
int GlobalBUYSELLdashboardScore=0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(DailyProtectionState &state)
  {
   int totalOrders=0,buyOrders=0,sellOrders=0,pendingOrders=0;
   double floatingProfit=0,totalSwap=0,totalCommission=0;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      totalOrders++;
      if(type==OP_BUY || type==OP_SELL)
        {
         if(type==OP_BUY)
            buyOrders++;
         else
            sellOrders++;
         floatingProfit+=OrderProfit();
         totalSwap+=OrderSwap();
         totalCommission+=OrderCommission();
        }
      else
         pendingOrders++;
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
      if(Bid>ema)
        {
         emaState="BULLISH";
         emaColor=clrLime;
         EMADirection=1;
        }
      else
         if(Bid<ema)
           {
            emaState="BEARISH";
            emaColor=clrTomato;
            EMADirection=-1;
           }
         else
           {
            emaState="AT EMA";
            emaColor=clrGold;
            EMADirection=0;
           }
     }

   string statusText="READY";
   color statusColor=clrLime;
   if(!EnableTrading)
     {
      statusText="TRADING DISABLED";
      statusColor=clrTomato;
     }
   else
      if(ServerRecoveryPending)
        {
         statusText="SERVER RECOVERY";
         statusColor=clrGold;
        }
      else
         if(!IsConnected())
           {
            statusText="NO CONNECTION";
            statusColor=clrTomato;
           }
         else
            if(IsDailyTradingStopped(state))
              {
               statusText="TRADING STOPPED";
               statusColor=clrTomato;
              }
            else
               if(HasBasketNewOrderLossLimit())
                 {
                  statusText="BASKET RISK LOCK";
                  statusColor=clrOrangeRed;
                 }
               else
                  if(!ContinueTradingAfterSL && LosingSLCount>=MaxConsecutiveLosingSL && MaxConsecutiveLosingSL>0)
                    {
                     statusText="SL LOSS LIMIT";
                     statusColor=clrTomato;
                    }
                  else
                     if(ProtectedEquityWaitActive)
                       {
                        statusText="PROTECTED EQUITY WAIT";
                        statusColor=clrGold;
                       }
                     else
                        if(EquityResetReEntryPending)
                          {
                           statusText="RESET RE-ENTRY PENDING";
                           statusColor=clrGold;
                          }
                        else
                           if(totalOrders>=MaxOpenOrders)
                             {
                              statusText="MAX ORDERS";
                              statusColor=clrOrangeRed;
                             }
                           else
                              if(buyOrders>0 && sellOrders>0)
                                {
                                 statusText="HEDGE / MIXED";
                                 statusColor=clrGold;
                                }
                              else
                                 if(buyOrders>0)
                                   {
                                    statusText="BUY ACTIVE";
                                    statusColor=clrDeepSkyBlue;
                                   }
                                 else
                                    if(sellOrders>0)
                                      {
                                       statusText="SELL ACTIVE";
                                       statusColor=clrTomato;
                                      }

   double ladderProgress=0;
   if(DayProfitLadderNextTargetEquity>DayProfitLadderProtectionEquity)
     {
      ladderProgress=((AccountEquity()-DayProfitLadderProtectionEquity) / (DayProfitLadderNextTargetEquity-DayProfitLadderProtectionEquity))*100.0;
      if(ladderProgress<0)
         ladderProgress=0;
      if(ladderProgress>100)
         ladderProgress=100;
     }
   double dayPL=AccountEquity()-state.DayStartBalance;
   double dayPLPct=(state.DayStartBalance>0)?(dayPL/state.DayStartBalance)*100.0:0;
   double riskRemaining=BasketNewOrderLossLimitUSD>0 ? BasketNewOrderLossLimitUSD+netProfit : 0;
   if(riskRemaining<0)
      riskRemaining=0;

   string serverText="CONNECTED / OK";
   color serverColor=clrLime;
   if(!IsConnected())
     {
      serverText="NO CONNECTION";
      serverColor=clrTomato;
     }
   else
      if(ServerRecoveryPending)
        {
         serverText="RECOVERY PENDING #"+IntegerToString(ServerRecoveryLastError);
         serverColor=clrGold;
        }
      else
         if(ServerRecoveryLastError!=0)
           {
            serverText="LAST ERROR #"+IntegerToString(ServerRecoveryLastError);
            serverColor=clrGold;
           }

   int x=DashboardRightGap, y=DashboardTopGap, tx=x+12, w=DashboardWidth, panelHeight=900;

   int h1Direction=GetH1Direction();
   int m5Direction=GetM5Direction();
   int dashboardDirection=(currentSSLDirection>0)?1:(currentSSLDirection<0?-1:0);
   string h1Text=h1Direction>0?"BUY":h1Direction<0?"SELL":"NONE";
   string m5Text=m5Direction>0?"BUY":m5Direction<0?"SELL":"NONE";
   bool h1Confirm=(dashboardDirection!=0 && h1Direction==dashboardDirection);
   bool m5Confirm=(dashboardDirection!=0 && m5Direction==dashboardDirection);
   bool emaConfirm=(dashboardDirection!=0 && EMADirection==dashboardDirection);
   bool h1Opposite=(dashboardDirection!=0 && h1Direction==-dashboardDirection);

   double dashboardMomentumDiff=0.0;
   double dashboardMomentumThreshold=MathAbs(Min30MinutePriceDifference);
   bool momentumConfirm=false;
   if(dashboardDirection!=0)
     {
      dashboardMomentumDiff=Get30MinDifference(dashboardDirection==1?OP_BUY:OP_SELL);
      momentumConfirm=(dashboardDirection==1) ? (dashboardMomentumDiff>dashboardMomentumThreshold) : (dashboardMomentumDiff<-dashboardMomentumThreshold);
     }
   double dashboardATRRatio=GetM5CandleATRRatio();
   bool dashboardExtremeVol=IsExtremeVolatility();

   int dashboardScore=0;
   if(h1Confirm)
      dashboardScore++;
   if(m5Confirm)
      dashboardScore++;
   if(emaConfirm)
      dashboardScore++;
   if(momentumConfirm)
      dashboardScore++;
   GlobalBUYSELLdashboardScore=dashboardScore;

   double dashboardSuggestedLot=0.01;
   if(dashboardScore==1)
      dashboardSuggestedLot=0.01;
   else
      if(dashboardScore==2)
         dashboardSuggestedLot=0.03;
      else
         if(dashboardScore==3)
            dashboardSuggestedLot=0.06;
         else
            if(dashboardScore>=4)
               dashboardSuggestedLot=0.10;

   if(CapLotWhenH1Opposite && h1Opposite)
      dashboardSuggestedLot=MathMin(dashboardSuggestedLot,0.01);
   if(dashboardExtremeVol)
      dashboardSuggestedLot=MathMin(dashboardSuggestedLot,MathAbs(VolatilityLotCap));

   int dayOfWeekDash = TimeDayOfWeek(TimeCurrent());
   if(dayOfWeekDash == 0 || dayOfWeekDash == 6)
     {
      dashboardSuggestedLot = MathMin(dashboardSuggestedLot, 0.02);
     }

   int dashboardLotMultiplier=(int)(AccountBalance()/AccountMultiplierLOT);
   if(dashboardLotMultiplier<1)
      dashboardLotMultiplier=1;
   double dashboardFinalLot=NormalizeLots(MathMin(0.10,dashboardSuggestedLot*dashboardLotMultiplier));

   string h1Mark=h1Confirm?"PASS":(h1Opposite?"OPPOSITE":"NO");
   string m5Mark=m5Confirm?"PASS":"NO";
   string emaMark=emaConfirm?"PASS":"NO";
   string momMark=momentumConfirm?"PASS":"NO";
   color h1Color=h1Confirm?clrLime:(h1Opposite?clrTomato:clrGold);
   color m5Color=m5Confirm?clrLime:clrTomato;
   color emaConfirmColor=emaConfirm?clrLime:clrTomato;
   color momentumColor=momentumConfirm?clrLime:clrTomato;
   string scoreText="SCORE        : "+IntegerToString(dashboardScore)+" / 4  -> LOT "+DoubleToString(dashboardFinalLot,2);
   color scoreColor=(h1Opposite||dashboardExtremeVol)?clrGold:(dashboardScore>=3?clrLime:(dashboardScore>=1?clrGold:clrTomato));

   int checkDir = (currentSSLDirection > 0) ? OP_BUY : OP_SELL;
   string strong = (currentSSLDirection != 0 && IsStrongMomentum(checkDir)) ? "STRONG" : "Normal";
   CreateDashboardPanel(DASH_PREFIX+"PANEL",x,y,w,panelHeight,C'12,16,22');
   CreateDashboardPanel(DASH_PREFIX+"HEADER",x,y,w,38,C'25,70,115');
   CreateDashboardLabel(DASH_PREFIX+"TITLE","SSL CHANNEL EA  |  PRO CONTROL",tx,y+8,11,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"SUBTITLE",Symbol()+"  |  "+TimeframeToString(Period()),tx+w-125,y+10,8,clrLightGray);
   CreateDashboardLabel(DASH_PREFIX+"STATUS", "STATUS       : "+statusText,tx,y+47,10,statusColor);
   CreateDashboardLabel(DASH_PREFIX+"SIGNAL","SSL SIGNAL   : "+sslDirection+"  ("+strong+")",tx,y+67,9,sslColor);
   CreateDashboardPanel(DASH_PREFIX+"SEC_CONFIRM",x,y+90,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"CONF_H","MARKET-MOMENT CONFIRMATIONS",tx,y+94,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"CONF_H1","H1 DIRECTION : "+h1Text+"  ["+h1Mark+"]",tx,y+117,9,h1Color);
   CreateDashboardLabel(DASH_PREFIX+"CONF_M5","M5 3-CANDLE  : "+m5Text+"  ["+m5Mark+"]",tx,y+137,9,m5Color);
   CreateDashboardLabel(DASH_PREFIX+"CONF_EMA","EMA "+IntegerToString(InpEMA200Period)+"     : "+emaState+"  ["+emaMark+"]",tx,y+157,9,emaConfirmColor);
   CreateDashboardLabel(DASH_PREFIX+"CONF_30M","30M MOMENTUM  : "+DoubleToString(dashboardMomentumDiff,Digits)+" / "+DoubleToString(dashboardMomentumThreshold,Digits)+"  ["+momMark+"]",tx,y+177,8,momentumColor);
   CreateDashboardLabel(DASH_PREFIX+"CONF_ATR","M5 RANGE/ATR : "+DoubleToString(dashboardATRRatio,2)+" / "+DoubleToString(MaxCandleRangeATRMultiple,2)+"  ["+(dashboardExtremeVol?"EXTREME":"OK")+"]",tx,y+197,8,dashboardExtremeVol?clrTomato:clrLime);
   CreateDashboardLabel(DASH_PREFIX+"CONF_SCORE",scoreText,tx,y+217,10,scoreColor);
   CreateDashboardLabel(DASH_PREFIX+"CONF_RULE","SSL MASTER | H1/M5/EMA/30M score | H1 opposite / ATR spike caps lot",tx,y+236,7,clrSilver);
   CreateDashboardLabel(DASH_PREFIX+"PRICE","BID / ASK    : "+DoubleToString(Bid,Digits)+" / "+DoubleToString(Ask,Digits),tx,y+255,9,clrWhite);
   CreateDashboardPanel(DASH_PREFIX+"SEC_ACCOUNT",x,y+278,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"ACCOUNT_H","ACCOUNT & EQUITY",tx,y+282,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"BALANCE","BALANCE      : $"+DoubleToString(AccountBalance(),2),tx,y+305,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"EQUITY","EQUITY       : $"+DoubleToString(AccountEquity(),2),tx,y+325,9,clrLime);
   CreateDashboardLabel(DASH_PREFIX+"FREEMARGIN","FREE MARGIN   : $"+DoubleToString(AccountFreeMargin(),2),tx,y+345,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"DAYPL","DAY P/L       : "+(dayPL>=0?"+":"")+DoubleToString(dayPL,2)+" ("+DoubleToString(dayPLPct,1)+"%)",tx,y+365,9,dayPL>=0?clrLime:clrTomato);
   CreateDashboardPanel(DASH_PREFIX+"SEC_LADDER",x,y+388,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"LADDER_H","DAY PROFIT LADDER - ONLY DAILY PROTECTION",tx,y+392,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"DPL_START","OPEN BAL/EQ : $"+DoubleToString(DayProfitLadderStartBalance,2)+" / $"+DoubleToString(DayProfitLadderStartEquity,2),tx,y+415,8,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"DPL_STAGE","CURRENT STAGE : X"+IntegerToString(DayProfitLadderStage),tx,y+435,9,clrYellow);
   CreateDashboardLabel(DASH_PREFIX+"DPL_TARGET","NEXT TARGET   : $"+DoubleToString(DayProfitLadderNextTargetEquity,2),tx,y+455,8,clrLime);
   CreateDashboardLabel(DASH_PREFIX+"DPL_LOCK","PROTECTION    : $"+DoubleToString(DayProfitLadderProtectionEquity,2)+" / "+DoubleToString(DayProfitLadderNextTargetEquity-DayProfitLadder1Amount,2),tx,y+475,8,clrGold);
   CreateDashboardLabel(DASH_PREFIX+"PROGRESS","NEXT TARGET PROGRESS : "+DoubleToString(ladderProgress,1)+"%",tx,y+495,8,clrWhite);
   string dplStatus = DayProfitLadderTradingStopped ? "STOPPED" : "TRADING";
   color dplStatusColor = DayProfitLadderTradingStopped ? clrTomato : clrLime;
   CreateDashboardLabel(DASH_PREFIX+"DPL_STATUS","DAY LADDER    : "+dplStatus,tx,y+510,9,dplStatusColor);
   CreateDashboardPanel(DASH_PREFIX+"SEC_RISK",x,y+518,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"RISK_H","RISK & STOP-LOSS PROTECTION",tx,y+522,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"FLOAT","FLOATING P/L  : "+(netProfit>=0?"+":"")+DoubleToString(netProfit,2),tx,y+545,9,pnlColor);
   int balancelomultipler=(int)(AccountBalance()/AccountMultiplierLOT);
   if(balancelomultipler<1)
      balancelomultipler=1;
   CreateDashboardLabel(DASH_PREFIX+"ORDERS","ORDERS       : "+IntegerToString(totalOrders)+" / "+IntegerToString(MaxOpenOrders)+"   B:"+IntegerToString(buyOrders)+" S:"+IntegerToString(sellOrders),tx,y+565,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"LOTS","LOTS         : B "+DoubleToString(GetTotalLots(OP_BUY),2)+" / S "+DoubleToString(GetTotalLots(OP_SELL),2)+" Multi X "+IntegerToString(balancelomultipler),tx,y+585,9,clrWhite);
   CreateDashboardLabel(DASH_PREFIX+"SLRISK","SL LOSSES    : "+IntegerToString(LosingSLCount)+" | CONTINUE AFTER SL: "+(ContinueTradingAfterSL?"YES":"NO"),tx,y+605,9,ContinueTradingAfterSL?clrLime:(LosingSLCount>0?clrOrangeRed:clrLime));
   CreateDashboardLabel(DASH_PREFIX+"BASKET","BASKET LOCK  : $"+DoubleToString(BasketNewOrderLossLimitUSD,2)+" | ROOM $"+DoubleToString(riskRemaining,2),tx,y+625,9,HasBasketNewOrderLossLimit()?clrTomato:clrLime);
   CreateDashboardLabel(DASH_PREFIX+"COOLDOWN","SL COOLDOWN  : "+(SLProtectionUntil>TimeCurrent()?TimeToString(SLProtectionUntil,TIME_SECONDS):"READY"),tx,y+645,9,SLProtectionUntil>TimeCurrent()?clrGold:clrLime);
   CreateDashboardPanel(DASH_PREFIX+"SEC_SERVER",x,y+668,w,22,C'30,38,50');
   CreateDashboardLabel(DASH_PREFIX+"SERVER_H","SERVER / EA HEALTH",tx,y+672,9,clrAqua);
   CreateDashboardLabel(DASH_PREFIX+"SERVER","CONNECTION   : "+serverText,tx,y+695,9,serverColor);
   CreateDashboardLabel(DASH_PREFIX+"RECOVERY","RECOVERY CTS  : "+IntegerToString(ServerRecoveryResetCount)+"   LAST ERR: "+IntegerToString(ServerRecoveryLastError),tx,y+715,8,ServerRecoveryLastError==0?clrSilver:clrGold);
   CreateDashboardLabel(DASH_PREFIX+"REENTRY","RE-ENTRY      : "+(EquityResetReEntryPending?"PENDING":(ProtectedEquityWaitActive?"WAIT":"READY")),tx,y+735,8,EquityResetReEntryPending||ProtectedEquityWaitActive?clrGold:clrLime);
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

string LEFT_LIVE_PREFIX = "SSL_LEFT_LIVE_";
void CreateLeftLivePanel(string name,int x,int y,int width,int height,color background)
  {
   if(ObjectFind(0,name)<0)
      ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
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
   if(rows<1)
      rows=1;
   if(rows>24)
      rows=24;
   for(int i=OrdersTotal()-1; i>=0; i--)
     {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      total++;
      if(type==OP_BUY)
        {
         buyCount++;
         buyLots+=OrderLots();
        }
      else
         if(type==OP_SELL)
           {
            sellCount++;
            sellLots+=OrderLots();
           }
         else
            pendingCount++;
      if(type==OP_BUY || type==OP_SELL)
         netPL+=OrderProfit()+OrderSwap()+OrderCommission();
     }
   int x=LeftDashboardX, y=LeftDashboardY, tx=x+12, width=LeftDashboardWidth+180, panelHeight=rows*20+132;
   color pnlColor=clrWhite;
   if(netPL>0)
      pnlColor=clrLime;
   else
      if(netPL<0)
         pnlColor=clrTomato;
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PANEL", x, y, width, panelHeight, C'12,16,22');
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"HEADER", x, y, width, 38, C'25,70,115');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TITLE", "LIVE POSITION MONITOR", tx, y+8, 11, clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SYMBOL", Symbol()+"  |  "+TimeframeToString(Period()), x+width-112, y+10, 8, clrLightGray);
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"SUMMARYBAR", x, y+38, width, 42, C'25,31,42');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SUMMARY", "ORDERS "+IntegerToString(total)+"/"+IntegerToString(MaxOpenOrders)+"   BUY "+IntegerToString(buyCount)+"   SELL "+IntegerToString(sellCount)+"   PEND "+IntegerToString(pendingCount), tx, y+45, 8, clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TOTALS", "BUY LOT "+DoubleToString(buyLots,2)+"   SELL LOT "+DoubleToString(sellLots,2)+"   NET P/L "+(netPL>=0?"+":"")+DoubleToString(netPL,2), tx, y+62, 9, pnlColor);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD", "TYPE     LOT       OPEN       SL        TP        P/L     VERIFIED", tx, y+88, 8, clrSilver);

   for(int r=0; r<24; r++)
     {
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(r), "", tx, y+108+(r*20), 8, clrWhite);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"VERIFY"+IntegerToString(r), "", tx+475, y+108+(r*20), 8, clrSilver);
     }

   int row=0;
   for(int j=OrdersTotal()-1; j>=0; j--)
     {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;
      if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
         continue;
      int type=OrderType();
      if(type!=OP_BUY && type!=OP_SELL && type!=OP_BUYSTOP && type!=OP_SELLSTOP && type!=OP_BUYLIMIT && type!=OP_SELLLIMIT)
         continue;
      if(row>=rows)
         break;
      string typeText="";
      if(type==OP_BUY)
         typeText="BUY";
      else
         if(type==OP_SELL)
            typeText="SELL";
         else
            if(type==OP_BUYSTOP)
               typeText="BUY ST";
            else
               if(type==OP_SELLSTOP)
                  typeText="SELL ST";
               else
                  if(type==OP_BUYLIMIT)
                     typeText="BUY LM";
                  else
                     if(type==OP_SELLLIMIT)
                        typeText="SELL LM";
      double lots=OrderLots();
      double open=OrderOpenPrice();
      double sl=OrderStopLoss();
      double tp=OrderTakeProfit();
      double pl=0;
      if(type==OP_BUY || type==OP_SELL)
         pl=OrderProfit()+OrderSwap()+OrderCommission();
      double slDiffPoints=0;
      if(sl>0)
         slDiffPoints=MathAbs(open-sl)/Point/100;
      double tpDiffPoints=0;
      if(tp>0)
         tpDiffPoints=MathAbs(tp-open)/Point/100;
      string slDiffText="-";
      string tpDiffText="-";
      if(sl>0)
         slDiffText=DoubleToString(slDiffPoints,0);
      if(tp>0)
         tpDiffText=DoubleToString(tpDiffPoints,0);
      string plText="-";
      if(type==OP_BUY || type==OP_SELL)
         plText=(pl>=0?"+":"")+DoubleToString(pl,2);
      string verifiedStatus="N/A";
      color verifiedColor=clrSilver;
      if(type==OP_BUY || type==OP_SELL)
        {
         verifiedStatus=GetPostOrderSLTPVerificationStatus(OrderTicket());
         if(verifiedStatus=="VERIFIED")
            verifiedColor=clrLime;
         else
            if(verifiedStatus=="FAILED")
               verifiedColor=clrTomato;
            else
               if(verifiedStatus=="CHECKING")
                  verifiedColor=clrGold;
               else
                  if(verifiedStatus=="NOT CHECKED")
                     verifiedColor=clrOrange;
        }
      string rowText=StringFormat("%-7s %5.2f %10s %10s %10s %8s", typeText, lots, DoubleToString(open,Digits), slDiffText, tpDiffText, plText);
      color rowColor=clrWhite;
      if(type==OP_BUY)
         rowColor=clrDeepSkyBlue;
      else
         if(type==OP_SELL)
            rowColor=clrTomato;
         else
            rowColor=clrGold;
      if((type==OP_BUY || type==OP_SELL) && pl>0)
         rowColor=clrLime;
      if((type==OP_BUY || type==OP_SELL) && pl<0)
         rowColor=clrOrangeRed;
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"ROW"+IntegerToString(row), rowText, tx, y+108+(row*20), 8, rowColor);
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"VERIFY"+IntegerToString(row), verifiedStatus, tx+350, y+108+(row*20), 8, verifiedColor);
      row++;
     }
   if(total==0)
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY", "NO ACTIVE EA ORDERS", tx, y+108, 9, clrSilver);
   else
      CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"EMPTY", "Showing "+IntegerToString(MathMin(total,rows))+" of "+IntegerToString(total)+" orders", tx, y+108+(rows*20)+4, 8, clrSilver);
   ChartRedraw(0);
  }

//+------------------------------------------------------------------+
//| STRONG MOMENTUM DETECTION                                        |
//+------------------------------------------------------------------+
bool IsStrongMomentum(int direction)
  {
   double adxMain = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double adxPlus = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   double adxMin  = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_MINUSDI, 0);

   double candleRange = High[1] - Low[1];
   double candleBody  = MathAbs(Open[1] - Close[1]);
   bool isSolidCandle = false;

   if(candleRange > 0.0)
     {
      isSolidCandle = (candleBody / candleRange) >= 0.75;
     }

   if(direction == OP_BUY)
     {
      return (adxMain > 25.0 && adxPlus > adxMin && isSolidCandle);
     }
   else
      if(direction == OP_SELL)
        {
         return (adxMain > 25.0 && adxMin > adxPlus && isSolidCandle);
        }

   return false;
  }

//+------------------------------------------------------------------+
//| UPDATE SPECIFIC CANDLE BACKGROUND BASED ON MOMENTUM              |
//+------------------------------------------------------------------+
void UpdateMomentumBackground()
  {
   bool strongBuy  = IsStrongMomentum(OP_BUY);
   bool strongSell = IsStrongMomentum(OP_SELL);

   if(!strongBuy && !strongSell)
      return;

// Create a unique object name for the current candle
   string objName = PREFIX + "MOM_" + IntegerToString((int)Time[0]);

// Faint but solid Dark Green or Dark Red
   color momColor = strongBuy ? C'0,40,0' : C'40,0,0';

// Calculate the area to highlight (Candle High/Low + 10% visual buffer)
   double buffer = (High[0] - Low[0]) * 0.1;
   double topPrice = High[0] + buffer;
   double botPrice = Low[0] - buffer;

// Calculate width (Current candle open time to next candle open time)
   datetime endTime = Time[0] + Period() * 60;

// Draw the solid block behind the candle
   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, Time[0], topPrice, endTime, botPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, momColor);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);    // Keep it behind the candles
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);    // Make it solid, NOT transparent
     }
   else
     {
      // Update size dynamically as the live candle moves
      ObjectMove(0, objName, 0, Time[0], topPrice);
      ObjectMove(0, objName, 1, endTime, botPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, momColor);
     }
  }
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
