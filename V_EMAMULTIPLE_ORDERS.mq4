//+------------------------------------------------------------------+
//|                  SSL CHANNEL CROSS EA - CONTINUOUS EQUITY LADDER |
//|                  TWO-STAGE PROFIT LADDER | CONTINUOUS RESET      |
//+------------------------------------------------------------------+
#property strict

//$100 to $170
//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/32fb1ba20d474fc8d4adb38d2558999b2ac82c56

//$100 to $170

//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/bd37b6095eb5e15d8e9d6e9dcad922a027d08f53

//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/00c472a227581be00abce1564b92f74e160f3876

//Deleted -2
//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/a3a7908f5cb6d3c86b516b18afa2cbd3525d9fc9

//No Limit profit blockage
//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/7e017c99e7de9bec2ae6e9e909eb567d0275fdb2


//every Flip Stop 20%
//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/9ee1d4e897a5bcd34d5d5825dc2771c6eca50b78

//V3001 25-09-2026 08.00 Aug 2nd to Aug 4th $100 to $400
//https://github.com/devcrunch2025/exnessStratagiesExperts/commit/f4f1c1340be330cd32a75da3f3a9b4bd5f4e4cf3


//string glbVersion = "V5008  29-09-2026 23.00 Aug 1st to Aug 5th $100 to $1000 equity $500 - Attached Image  balance ST-20 Partialclose, Close orders $1X close-   FlipLadderStepUSD 7 DailyEquityStopUSD 50%  TargetProfitPerFlipUSD 10%";
string glbVersion = "VMULTI-1020-GREEN line close orders issue filxed";


double DailyEquityStopUSD  =1000;//50;//20*2.5;//10;//20;// 10;//30.0; close all orders at $50Xmultipler
double TargetProfitPerFlipUSD =1000;//20;//10;//10*2;//10;//5;//20;// 10.0; close all orders at $20Xmultipler

double protectgapOnOrderclose=31;//30;//101;//1000;//303;//11111111111111


//Chance 1
double SecureOneDollarProfitPerOrder=1.0*1; //1X set modify order at profit $1(any lot)

//chance 2
int partialClose01in05IndividualPercentage=20;//10;//2*2;//per lot 0.01//if 0.05 close 0.01 at total profit of 20% means close 0.01 lot
//int partialLossMultipler=10; //10 values 0.05 means $50 close 0.01 partial lot
int partialLossMultipler=5;//5; //10 values 0.05 means $50 close 0.01 partial lot
//50/5=10
//48/4=12
// 45/3=15

//chance 3
double FlipLadderStepUSD =8;//0;//10;// 5;//10.0;//0 means nothing not work close all orders at $7Xmultipler

//chance 4
double modifyBasketProfitOrdersLotXPercent=50;//10.0;//20 % means 0.05 X 20 modify orders in basket $1 profit//work if basket is full profit mode

//chance 5
double CloseOrdersAtProfitFromOpeningBalanceEveryStep =2;//0.4;//1;//3;//5;//10;//25;// 5;// 5X step close orders every step


//chage 55
// double closeAllOrdersLowestEquityIncreasePercentage=20;
double closeAllOrdersLowestEquityIncreasePercentage =20;//100//50;// 50.0;
// equity is going down and increased equity more than 50% even in loss then close all orders
//$100 $50 to $75 close all orders - close one side orders if any

//close all orders(buy and sell) every step $50 equity changed - not required
double   g_stepSize            =1000;// 50.0; // The step increment ($50)



//chance 6 - basket//IMPORTANT TO CLOSE ONE SIDE OPEN ORDERS as soon as possible
double basketBUYorSELLProfitModifyUSD=1*2; //if all combined basket BUY OR SELL Only basket is profit >0 then modify stoploss
bool   InpEnableBasketProfitClose = true;        // Close open Buy/Sell/Total orders when basket profit target reached
double InpBasketProfitTargetUSD   = 1.0;         // Base target profit (.00) multiplied by balancelomultipler


int      g_dayNumber = -1;
double   g_dayOpeningBalance = 0.0;
bool     g_dailyEquityTradingBlocked = false;

bool EnableBounceBackDetection = false;

// =========================================================================
// FLIP Basket Support Order Settings (Ported from V-ScalpingBot.mq4)
// =========================================================================
double FLIPBasketSupportStopLossRaw = 200.0; // Raw price gap ($200) for FLIPBasketSupport order StopLoss
double FlipBaksetOrderStopLossRaw = 200.0;   // Alias matching FlipBakset naming
double FlipBaksetOrderStopLossUSD = 200.0;   // Kept for backward compatibility
bool   OnlyAllowFLIPBasketSupportOrders = false; // TEST ISOLATION: When true, blocks ALL orders in SafeOrderSend except FLIPBasketSupport
double FLIPBasketSupportLot = 0.06;                 // FLIP Basket Support order lot size (0.06)
double FLIPBasketSupportPendingGapRaw = 50.0;       // Raw gap (BTC price points) for FLIPBasketSupport pending stop order placement
double FLIPBasketSupportTakeProfitDistanceRaw = 2000;// Take profit distance (raw BTC price distance) for FLIPBasketSupport orders
double FLIPBasketSupportTakeProfitDistanceStopLossStep = 100.0; // Positive profit move step size (raw BTC price) to ratchet FLIPBasketSupport StopLoss
double FLIPBasketSupportMinEmaDistance = 100;       // Minimum raw price gap from live price to EMA ($100) required to open FLIPBasketSupport order
double FLIPBasketSupportMinOpenOrderGapRaw = 100.0; // Gate 6: Minimum raw price gap ($100) between open order and FLIPBasketSupportOrder
int    FLIPBasketSupportMinCloseGapSeconds = 300;   // Minimum 5-minute gap (300s) from recent closed FLIPBasketSupport order
double FLIPBasketSupportRecreateMinAngle = 5.0;     // Minimum MathAbs(GlobalEmaAngle30) (> 5.0) required for recreated support order
double FLIPBasketSupportRecreateOppositeMinLossUSD = 5.0; // Minimum loss (>$5.00) on opposite order type required for recreated support order
bool   FLIPBasketSupportBlockOnWeakEma = true;     // Block FLIPBasketSupport order creation when IsEmaWEAKDistanceReduced50PercentFromPeak is weak
int    FLIPBasketSupportMinFlipElapsedSeconds =60*1;// 900; // Minimum 15 minutes (60*15 = 900s) elapsed after EMA flip time
int    g_flipBasketSupportCreatedInCycle = 0;      // Number of FLIPBasketSupport orders created in current flip cycle
datetime LastClosedFLIPBasketSupportTime = 0;       // Timestamp of most recently closed FLIPBasketSupport order
int    g_lastActiveFLIPBasketSupportTicket = -1;   // Ticket of currently active FLIPBasketSupport order
bool   FLIPBasketSupportOpenedThisCycle = false;
int    g_weakStateCountPerEmaFlip = 0;             // Reset on each EMA direction flip



// ===== EMA FLIP PROFIT TARGET =====
// bool TradingHaltedUntilNextFlip = false;

// ===== EMA FLIP PROFIT LADDER =====
int FlipStepbackLevelCount=1;


double HighestCycleProfitUSD = 0.0;
bool   TradingHaltedUntilNextFlip =false;//true;// false;
double ActiveEquityBaseline = 0.0; // Add this new variable





datetime g_lastLadderCloseTime = 0;   // Stores timestamp of last basket reset
double   g_peakCycleProfit     = 0.0; // Tracks the highest profit reached in the current cycle




// ===== 5% CONTINUOUS LADDER SETTINGS =====
double Ladder5PercentBaseline = 0.0;
bool enable5PercentClose =true;// false; //5;//
bool enableCircleOrders = true;


int EMAFlipwaitingtimeMinutes =10;// 29; // Wait time after an EMA flip before resuming trading


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

// ===== LIQUIDITY SWEEP DETECTOR PRO SETTINGS (SMC ANALYTICAL MARKERS) =====
bool   InpShowLiquiditySweeps          = true;   // Show Liquidity Sweep Markers on Chart (BSL / SSL)
int    InpSweepPivotLen                = 3;      // Pivot Strength (bars each side, min 1)
int    InpSweepExtendBars              = 100;    // Extend Liquidity Levels (bars forward)
double InpSweepToleranceATR            = 0.15;   // Equal High/Low ATR Tolerance (multiplier of ATR 14)
bool   InpShowSweepLevels              = true;   // Show Liquidity Levels (EQH / EQL lines)
bool   InpShowSweepLabels              = true;   // Show Sweep Text Badges on Chart
color  InpBslSweepColor                = clrRed; // BSL (Buy Side) Sweep Color -> Bearish Sweep (SWEEP sell signal)
color  InpSslSweepColor                = clrLime;// SSL (Sell Side) Sweep Color -> Bullish Sweep (SWEEP buy signal)
color  InpSweepSubTextColor            = clrDodgerBlue; // BSL / SSL Subtext Color
enum ENUM_SWEEP_LINE_ACTION
  {
   SWEEP_LINE_CLOSE_ALL_OPPOSITE      = 0, // Close All Opposite Orders (RED line closes BUY, GREEN line closes SELL)
   SWEEP_LINE_MODIFY_SL_CURRENT_PRICE = 1  // Modify StopLoss to Current Price (Trail/Lock at Market)
  };

bool   InpManageSweepTerminalGlobals   = true;   // Manage MT4 Terminal Global Variables for Sweep Signals
bool   InpEnableLsdSweepLotAdjustment  = true;   // Enable LSD Sweep Lot Adjustment in ChangeLots
double InpLsdSweepLotSize              = 0.05;   // LSD Sweep Lot Size (0.05)
bool   InpLsdSweepMatchDirectionOnly   = true;   // Apply 0.05 only when Order aligns with Sweep Signal
bool   InpEnableSweepLineSLProtection  = false;  // LSD Sweep Line Order Protection (DISABLED: Sweep lines only create FlipBasketSupport, DO NOT modify/close orders)
ENUM_SWEEP_LINE_ACTION InpSweepLineAction = SWEEP_LINE_CLOSE_ALL_OPPOSITE; // Sweep Line Action: Close All Opposite or Modify SL
double InpSweepLineSLBufferPoints      = 20.0;   // Buffer Points from Current Price for SL
bool   InpSweepLineTriggerOnSweepSignal= false;  // Only trigger line action when physical line is present on chart
bool   InpEnableLsdSweepFlipBasketSupport = true; // Enable FLIPBasketSupport creation on LSD Sweep Line proximity
double InpLsdSweepFlipBasketMaxGapRaw  = 50.0;   // Max raw price gap ($50) between LSD Sweep line and live price to trigger FLIPBasketSupport

// Function Prototypes for Liquidity Sweep Detector
void     UpdateLiquiditySweepDetectorOnChart();
void     DeleteLiquiditySweepObjects();
void     ManageSweepGlobalVariables(string signalType);
void     ClearSweepGlobalVariables();
datetime GetActualEmaFlipTime(int targetType = 0);
double   GetEmaFlipPrice();
double   EMAflipdistance(int orderType = -1);
double   GetLsdSweepEqlPrice();
double   GetLsdSweepEqhPrice();
double   LsdSweepEqlDistance(int orderType = -1);
double   LSD_SWEEP_EQL_distance(int orderType = -1);
double   GetLsdSweepEqlDistance(int orderType = -1);
double   LsdSweepEqlDistancePoints(int orderType = -1);
double   LsdSweepEqhDistance(int orderType = -1);
double   LSD_SWEEP_EQH_distance(int orderType = -1);
int      GetLsdSweepSignal();
int      GetLsdSweepChartSignal();
bool     IsLsdSweepBuySignal();
bool     IsLsdSweepSellSignal();
bool     IsLsdSweepGreenLinePresent();
bool     IsLsdSweepRedLinePresent();
bool     IsLsdSweepGreenLineActive();
bool     IsLsdSweepRedLineActive();
// void     ManageLsdSweepLineStopLossProtection();
void     UpdateOrderCacheIfNeeded();
void     InvalidateOrderCache();

// ===== CUSTOM USER RULES SETTINGS =====
bool   InpEnableCustomRules      = true;
double InpPriceGapFromExtreme    = 100.0;
bool   InpEnableEmaAngleFilter   = false;
double InpMinEmaAngleDegrees     = 1.0;

// ===== DUBAI TIMEZONE SETTINGS =====
bool   EnableDubaiTradingPause    = true;
string DubaiTradingPauseHours     ="";// "19,20";
int    ServerToDubaiOffsetHours   = 4;



// ===== SPREAD & RISK SETTINGS =====
double MaxAllowedSpreadUSD = 35.0;
int AccountMultiplierLOT = 200;//500;
double OriginalStopLossUSD = 20;//6;//4;
double StopLossRawPriceGap =3000;// 2000.0;   // Raw price gap ($2000 BTC price points) for StopLoss
double TakeProfitRawPriceGap = 500.0;  // Raw price gap ($500 BTC price points) for TakeProfit
double StopLossUSD =30;//20;//10;//6;//10;//6;//5;//10;//2;// 10;

// ===== MOM ORDER FLAG (global - set before OpenBuy/OpenSell, cleared after) =====
bool isMOMOrder = false; // Set to true only during MOM order placement




bool   EnableDailyEquity30Stop = true;




double SecurebaselinePercentage=0.50;//0.90;


// --- NEW RESUME TIMER VARIABLES ---
datetime LadderHaltStartTime = 0;
int InpResumeAfterHaltMinutes = 60; // Resume after 1 hour if no flip occurs


int    HighestLadderLevelThisCycle = 0; // <-- NEW

// ===== EMA DISTANCE CLOSE SETTINGS =====
bool   EnableEmaDistanceClose =false;// true;
double EmaCloseDistancePoints =200;// 50;

// ===== 30-MINUTE PRICE MOMENTUM FILTER =====
bool Enable30MinuteMomentumFilter = false;
double Min30MinutePriceDifference = 200;
double Min30MinutePriceDifferenceDuration = 30;
bool Enable30MinuteMomentumForProfitReEntry = false;
bool Enable30MinuteMomentumForAllOrders = false;

// ===== MARKET-MOMENT SAFETY FILTERS =====
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


bool CloseOppositeOrdersOnSignal =true;// false;
double closeOppositeLossThreshold =0.01;
bool DeletePendingOrdersOnSSLChange = true; // Close/Delete all pending orders when SSL signal changes
bool DeleteOppositePendingOnSignal = true;
bool EnableProfitReEntryStop = true;
double MinimumClosedProfitUSD = -9;
double ProfitReEntryGapRaw =50;//30;//10;// 25;
double MinimumSameOrderGapRawReEntry =50;//30;//10;//20;// 50;
extern double SSLLongShortPendingGapRaw = 20.0; // Raw price gap ($20) for SSL Long / Short pending stop orders
// double MinimumSameOrderGapRawSSLLongShort =50;// 50;
double MinimumSameOrderGapRawMatched =100;//50;//30;//10;//20;//50;//20;// 50;//SSL long //SSL short
double MinimumSameOrderGapRawUnmatched =50;//10;//10;//20;// 100;

bool EnableReEntryNOnMatchingSignal=true;

double angleBlockAboveRule = 3;//1.0; no opposite order above 3 angle
double plBlockAboveRule = 10.0;

// ===== STOP-LOSS / RE-ENTRY SAFETY =====
bool EnableSLProtection = false;
int MaxSameDirectionOrders = 1000;
int MaxConsecutiveLosingSL = 1000;
int SLCooldownCandles = 3;
double SLReEntryGapRaw = 200;//50.0;
double BasketNewOrderLossLimitUSD = 10.00;
int SLProtectionSafetyBufferPoints = 2;
bool DeletePendingOrdersAfterLosingSL = false;
bool RequireFreshSSLAfterLosingSL = false;
bool ContinueTradingAfterSL = true;
bool EnableFreezeLevelProtection = true;
extern double MinimumSLModifyGapRaw = 25.0; // Minimum raw price gap (.0) required between SL modifications to prevent broker spam

bool EnableProfitLadder1 = true;
bool EnableProfitLadder2 = true;
double Ladder1ProfitUSD =1*1;// 0.50;
double Ladder1StopMaxPriceUSD =1.50;// 0.70;//2;
double Ladder2ProfitUSD = 0.50;
double DefaultOrderProfitUSD =5;// 2.00;


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

bool EnableRecoveryOrders =true;// true;
double RecoveryTriggerLossUSD =1;//2;//1;//0.50;// 2;
double RecoveryLotMultiplier = 2;
int MaxRecoveryOrders =10;// 5;//1;
double RecoveryBasketProfitUSD = 1;
double RecoveryMinDistanceRaw =1000;//1000;//100;//20;// 200.0;
double RecoveryStopLossDistanceRaw = 200.0; // Raw price gap ($200) for Recovery order StopLoss
double RecoveryStopLossRaw         = 200.0; // Alias matching RecoveryStopLossDistanceRaw

double DayProfitLadder1Amount = 5;

// ===== DYNAMIC DAY PROFIT LADDER =====
bool   EnableDayProfitLadder =false; //true;//false;//true;
double DayProfitLadder1Percent = 25;
double DayProfitLadder2Percent = 10;
double DayProfitLadderLockRatio = 10;
double DayProfitInitialProtectionPercent = 80;
double PeakProfitLockPercent =30;// 80.0;

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

double safeOrdersendLossCondition=2.0;
double OriginalsafeOrdersendLossCondition=2.0;


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
int LastTrackedSSLDirection = 0; // Tracks SSL direction to detect signal change
datetime LastLiveSignalCandle = 1;
bool EquityResetReEntryPending = true;
bool ProtectedEquityWaitActive = true;
datetime ProtectedEquityWaitStartTime = 0;
int ProtectedEquityWaitMinutes = 0;

// --- GLOBAL TICK CACHE ---
double GlobalEmaAngle30 = 0.0;
double GlobalEmaAngle200 = 0.0;
int    GlobalSSLDirection = 0;
double GlobalBuyPL = 0.0;
double GlobalSellPL = 0.0;
double Global30MinDiffBuy = 0.0;
double Global30MinDiffSell = 0.0;

double Get5MinDifferenceBuy1 = 0.0;
double Get5MinDifferenceSell1 = 0.0;

// ==================================================================
// CENTRALIZED ORDER CACHE (Optimizes order queries to single-pass O(1))
// ==================================================================
struct OrderCacheData
  {
   int               totalOrders;
   int               buyOrders;
   int               sellOrders;
   int               buyPending;
   int               sellPending;
   double            buyLots;
   double            sellLots;
   double            buyPL;
   double            sellPL;
   double            totalPL;
   double            minBuyPrice;
   double            maxBuyPrice;
   double            minSellPrice;
   double            maxSellPrice;
   datetime          oldestBuyTime;
   datetime          newestBuyTime;
   datetime          oldestSellTime;
   datetime          newestSellTime;
  };

OrderCacheData g_orderCache;
bool           g_orderCacheValid = false;
int            g_orderCacheTick  = -1;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void InvalidateOrderCache()
  {
   g_orderCacheValid = false;
   CachedTotalEAOrdersTick = -1;
   CachedTotalEAOrders = -1;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateOrderCacheIfNeeded()
  {
   if(g_orderCacheValid && g_orderCacheTick == CurrentTickSequence && CurrentTickSequence > 0)
      return;

   g_orderCache.totalOrders    = 0;
   g_orderCache.buyOrders      = 0;
   g_orderCache.sellOrders     = 0;
   g_orderCache.buyPending     = 0;
   g_orderCache.sellPending    = 0;
   g_orderCache.buyLots        = 0.0;
   g_orderCache.sellLots       = 0.0;
   g_orderCache.buyPL          = 0.0;
   g_orderCache.sellPL         = 0.0;
   g_orderCache.totalPL        = 0.0;
   g_orderCache.minBuyPrice    = 0.0;
   g_orderCache.maxBuyPrice    = 0.0;
   g_orderCache.minSellPrice   = 0.0;
   g_orderCache.maxSellPrice   = 0.0;
   g_orderCache.oldestBuyTime  = 0;
   g_orderCache.newestBuyTime  = 0;
   g_orderCache.oldestSellTime = 0;
   g_orderCache.newestSellTime = 0;

   int total = OrdersTotal();
   for(int i = total - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type          = OrderType();
      double lots       = OrderLots();
      double pl         = OrderProfit() + OrderSwap() + OrderCommission();
      double openPrice  = OrderOpenPrice();
      datetime openTime = OrderOpenTime();

      g_orderCache.totalOrders++;
      g_orderCache.totalPL += pl;

      if(type == OP_BUY)
        {
         g_orderCache.buyOrders++;
         g_orderCache.buyLots += lots;
         g_orderCache.buyPL += pl;
         if(g_orderCache.minBuyPrice == 0.0 || openPrice < g_orderCache.minBuyPrice)
            g_orderCache.minBuyPrice = openPrice;
         if(openPrice > g_orderCache.maxBuyPrice)
            g_orderCache.maxBuyPrice = openPrice;
         if(g_orderCache.oldestBuyTime == 0 || openTime < g_orderCache.oldestBuyTime)
            g_orderCache.oldestBuyTime = openTime;
         if(openTime > g_orderCache.newestBuyTime)
            g_orderCache.newestBuyTime = openTime;
        }
      else
         if(type == OP_SELL)
           {
            g_orderCache.sellOrders++;
            g_orderCache.sellLots += lots;
            g_orderCache.sellPL += pl;
            if(g_orderCache.minSellPrice == 0.0 || openPrice < g_orderCache.minSellPrice)
               g_orderCache.minSellPrice = openPrice;
            if(openPrice > g_orderCache.maxSellPrice)
               g_orderCache.maxSellPrice = openPrice;
            if(g_orderCache.oldestSellTime == 0 || openTime < g_orderCache.oldestSellTime)
               g_orderCache.oldestSellTime = openTime;
            if(openTime > g_orderCache.newestSellTime)
               g_orderCache.newestSellTime = openTime;
           }
         else
            if(type == OP_BUYSTOP || type == OP_BUYLIMIT)
              {
               g_orderCache.buyPending++;
              }
            else
               if(type == OP_SELLSTOP || type == OP_SELLLIMIT)
                 {
                  g_orderCache.sellPending++;
                 }
     }

   g_orderCacheTick = CurrentTickSequence;
   g_orderCacheValid = true;

   GlobalBuyPL = g_orderCache.buyPL;
   GlobalSellPL = g_orderCache.sellPL;
   CachedTotalEAOrders = g_orderCache.totalOrders;
   CachedTotalEAOrdersTick = CurrentTickSequence;
  }


// --- MISSED SIGNAL MEMORY VARIABLES ---
int      MissedSignalType  = 0;    // 1 for Buy, -1 for Sell, 0 for None
double   MissedSignalPrice = 0.0;
datetime MissedSignalTime  = 0;
bool     MissedSignalOverride = false; // Flag to bypass EMA filter when market confirms

// --- SSL SIGNAL MEMORY VARIABLES ---
bool     StoredSellSignalActive = false;
datetime StoredSellSignalTime   = 0;
bool     StoredBuySignalActive  = false;
datetime StoredBuySignalTime    = 0;
bool     StoredSignalOverride   = false;


int    EMADirection = 0;
int    GlobalBUYSELLdashboardScore = 0;

// Global cache variable for patterns
int CachedPatternDirection = 0;
datetime LastPatternCalcTime = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PassesUserRules(int orderType)
  {
   if(!InpEnableCustomRules)
      return true;

   double emaAngle = GlobalEmaAngle30;




// // --- STRICT EMA TREND FILTER ---
//    if(EMADirection != -1 && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
//      {
//       // Print("TRADE BLOCKED | EMA trend is not bearish for Sell order.");
//       return false;
//      }

//    if(EMADirection != 1 && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
//      {
//       // Print("TRADE BLOCKED | EMA trend is not bullish for Buy order.");
//       return false;
//      }

// if(emaAngle > 3 && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
//    return false;
// if(emaAngle < -3 && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
//    return false;

   int currentSSL = GlobalSSLDirection;
   int requestedDirection = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? 1 : -1;
   int baseMarketType     = (requestedDirection == 1) ? OP_BUY : OP_SELL;
   double currentPL       = (baseMarketType == OP_BUY) ? GlobalBuyPL : GlobalSellPL;

   if(currentSSL != requestedDirection)
     {
      Print("TRADE BLOCKED | SSL does not match requested direction  "+currentSSL+" :  "+requestedDirection);
      return false;
     }

// if(currentSSL != requestedDirection && (emaAngle < 6))
//   {
//    Print("TRADE BLOCKED | SSL does not match requested direction and angle < 6.");
//    return false;
//   }

// if(currentPL <= -plBlockAboveRule && currentSSL != requestedDirection)
//   {
//    Print("TRADE BLOCKED | Floating PL <= -", plBlockAboveRule, " and SSL does not match requested direction.");
//    return false;
//   }



   return true;
//maximum highest  lowest

   RefreshRates();

   double adxMain = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double adxPlus = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_PLUSDI, 0);
   double adxMin  = iADX(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, MODE_MINUSDI, 0);

   bool strongBullishMomentum = (adxMain >= 25.0 && adxPlus > adxMin && emaAngle >= 1.5);
   bool strongBearishMomentum = (adxMain >= 25.0 && adxMin > adxPlus && emaAngle <= -1.5);

   int highIdx = iHighest(Symbol(), PERIOD_H1, MODE_HIGH, 12, 1);
   int lowIdx  = iLowest(Symbol(), PERIOD_H1, MODE_LOW, 12, 1);
   double rolling12HourHigh = iHigh(Symbol(), PERIOD_H1, highIdx);
   double rolling12HourLow  = iLow(Symbol(), PERIOD_H1, lowIdx);

   if(orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
     {
      if(InpEnableEmaAngleFilter && emaAngle <= InpMinEmaAngleDegrees)
         return false;
      if(!strongBullishMomentum)
        {
         if(rolling12HourHigh > 0.0 && (rolling12HourHigh - Ask) <= InpPriceGapFromExtreme)
            return false;
        }
     }
   else
      if(orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
        {
         if(InpEnableEmaAngleFilter && emaAngle >= -InpMinEmaAngleDegrees)
            return false;
         if(!strongBearishMomentum)
           {
            if(rolling12HourLow > 0.0 && (Bid - rolling12HourLow) <= InpPriceGapFromExtreme)
               return false;
           }
        }

   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
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
   UpdateOrderCacheIfNeeded();
   if(orderType == OP_BUY)
      return g_orderCache.buyOrders;
   if(orderType == OP_SELL)
      return g_orderCache.sellOrders;
   if(orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
      return g_orderCache.buyPending;
   if(orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
      return g_orderCache.sellPending;
   return 0;
  }


//+------------------------------------------------------------------+
//| IsRecoveryOrderWithActiveParent: Returns true if the order is a  |
//| recovery order (1st or 2nd) and its parent trade is still open.  |
//| In this case, recovery orders must NEVER be closed or modified   |
//| individually; they must strictly wait for recovery basket profit |
//+------------------------------------------------------------------+
bool IsRecoveryOrderWithActiveParent(int ticket, string comment = "")
  {
   if(!IsAnyRecoveryOrder(ticket, comment))
      return false;

   string rootComment = GetRootOrderComment(ticket, comment);
   int parentTicket = GetRecoveryOrderParentTicket(ticket, rootComment);
   if(parentTicket <= 0)
      return false;

   int currentSelTicket = OrderTicket();
   bool parentFound = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int t = OrderType();
      if(t != OP_BUY && t != OP_SELL)
         continue;
      int tkt = OrderTicket();
      int origTkt = GetOriginalTicket(tkt, OrderComment());
      if(tkt == parentTicket || (origTkt > 0 && origTkt == parentTicket))
        {
         parentFound = true;
         break;
        }
     }

   if(currentSelTicket > 0)
      bool selRes = OrderSelect(currentSelTicket, SELECT_BY_TICKET, MODE_TRADES);

   return parentFound;
  }

//+------------------------------------------------------------------+
//| Safely close a market order directly                             |
//+------------------------------------------------------------------+
bool SafeOrderCloseMarket(int ticket, double lots, int slippage, color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;

   string key = MakeTradeErrorKey("CLOSE_MKT", ticket, "");
   if(IsTradeErrorBlockedThisTick(key))
      return false;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return true;
      return false;
     }

   int orderType = OrderType();
   if(orderType != OP_BUY && orderType != OP_SELL)
      return false;

   RefreshRates();
   double closePrice = (orderType == OP_BUY) ? Bid : Ask;
   closePrice = NormalizeDouble(closePrice, Digits);

   if(!CanSendTradeRequest("OrderClose", "Ticket=" + IntegerToString(ticket)))
      return false;

   ResetLastError();
   bool result = OrderClose(ticket, lots, closePrice, slippage, arrowColor);
   if(result)
     {
      InvalidateTotalEAOrdersCache();
      return true;
     }

   int err = GetLastError();
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return true;
     }

   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err, "OrderCloseMarket");
   return false;
  }

//+------------------------------------------------------------------+
//| GetWeakStateCountPerEmaFlip                                      |
//| Returns how many times weak state was set since last EMA flip    |
//+------------------------------------------------------------------+
int GetWeakStateCountPerEmaFlip()
  {
   return 0;
   return g_weakStateCountPerEmaFlip;
  }

//+------------------------------------------------------------------+
//| Get the highest price reached since the last EMA direction flip  |
//+------------------------------------------------------------------+
double GetHighestPriceSinceEmaFlip()
  {
   RefreshRates();
   double highest = Ask;
   int flipShift = (EmaFlipTime > 0) ? iBarShift(Symbol(), Period(), EmaFlipTime, false) : MathMin(Bars - 1, 100);
   if(flipShift < 0 || flipShift >= Bars)
      flipShift = MathMin(Bars - 1, 100);

   for(int i = flipShift; i >= 0; i--)
     {
      if(High[i] > highest)
         highest = High[i];
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int oType = OrderType();
      if(oType == OP_BUY || oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
        {
         double oPrice = OrderOpenPrice();
         if(oPrice > highest)
            highest = oPrice;
        }
     }
   return highest;
  }

//+------------------------------------------------------------------+
//| Get the lowest price reached since the last EMA direction flip   |
//+------------------------------------------------------------------+
double GetLowestPriceSinceEmaFlip()
  {
   RefreshRates();
   double lowest = Bid;
   int flipShift = (EmaFlipTime > 0) ? iBarShift(Symbol(), Period(), EmaFlipTime, false) : MathMin(Bars - 1, 100);
   if(flipShift < 0 || flipShift >= Bars)
      flipShift = MathMin(Bars - 1, 100);

   for(int i = flipShift; i >= 0; i--)
     {
      if(Low[i] < lowest)
         lowest = Low[i];
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int oType = OrderType();
      if(oType == OP_SELL || oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
        {
         double oPrice = OrderOpenPrice();
         if(oPrice < lowest)
            lowest = oPrice;
        }
     }
   return lowest;
  }

//+------------------------------------------------------------------+
//| IsFLIPBasketSupportOrder: Identifies FLIP Basket Support orders  |
//+------------------------------------------------------------------+
bool IsFLIPBasketSupportOrder(int ticket, string comment = "")
  {
   if(comment == "")
     {
      if(OrderTicket() == ticket)
         comment = OrderComment();
      else
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            comment = OrderComment();
         else
            return false;
     }
   return (StringFind(comment, "FLIPBasketSupport") >= 0);
  }

//+------------------------------------------------------------------+
//| HasOpenFLIPBasketSupportOrder: Returns true if an active         |
//| FLIPBasketSupport order exists.                                  |
//| targetType: OP_BUY, OP_SELL, or -1 (checks ANY open support order)|
//+------------------------------------------------------------------+
bool HasOpenFLIPBasketSupportOrder(int targetType = -1, bool excludeLsd = false)
  {
   int count=0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(!IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()))
         continue;
      if(excludeLsd && StringFind(OrderComment(), "FLIPBasketSupport_LSD") >= 0)
         continue;

      int oType = OrderType();
      if(targetType == OP_BUY)
        {
         if(oType != OP_BUY && oType != OP_BUYSTOP && oType != OP_BUYLIMIT)
            continue;
        }
      else if(targetType == OP_SELL)
        {
         if(oType != OP_SELL && oType != OP_SELLSTOP && oType != OP_SELLLIMIT)
            continue;
        }
      else if(targetType >= 0 && oType != targetType)
        {
         continue;
        }

      count++;
     }
   if(count < 1)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| InitializeFLIPBasketSupportTracking: Initializes active ticket   |
//| and latest closed support order time from account history.       |
//+------------------------------------------------------------------+
void InitializeFLIPBasketSupportTracking()
  {
   g_lastActiveFLIPBasketSupportTicket = -1;
   LastClosedFLIPBasketSupportTime = 0;

// 1. Audit active open orders for existing FLIPBasketSupport runner
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()))
        {
         g_lastActiveFLIPBasketSupportTicket = OrderTicket();
         break;
        }
     }

// 2. Audit recent history for latest closed FLIPBasketSupport order
   int totalHist = OrdersHistoryTotal();
   int scanLimit = MathMin(totalHist, 100);
   for(int h = totalHist - 1; h >= totalHist - scanLimit; h--)
     {
      if(!OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      string cmt = OrderComment();
      if(StringFind(cmt, "FLIPBasketSupport") >= 0)
        {
         datetime cTime = OrderCloseTime();
         if(cTime > LastClosedFLIPBasketSupportTime)
            LastClosedFLIPBasketSupportTime = cTime;
        }
     }
  }

//+------------------------------------------------------------------+
//| GetLastClosedFLIPBasketSupportCloseTime: Returns close time of   |
//| the most recently closed FLIPBasketSupport order.                |
//+------------------------------------------------------------------+
datetime GetLastClosedFLIPBasketSupportCloseTime()
  {
   datetime lastCloseTime = LastClosedFLIPBasketSupportTime;

// 1. Check if tracked active ticket recently moved to history
   if(g_lastActiveFLIPBasketSupportTicket > 0)
     {
      if(OrderSelect(g_lastActiveFLIPBasketSupportTicket, SELECT_BY_TICKET, MODE_HISTORY))
        {
         datetime histClose = OrderCloseTime();
         if(histClose > lastCloseTime)
            lastCloseTime = histClose;
         LastClosedFLIPBasketSupportTime = lastCloseTime;
         g_lastActiveFLIPBasketSupportTicket = -1;
        }
     }

// 2. Scan recent closed orders in account history
   int totalHistory = OrdersHistoryTotal();
   int scanLimit = MathMin(totalHistory, 100);

   for(int i = totalHistory - 1; i >= totalHistory - scanLimit; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string cmt = OrderComment();
      if(StringFind(cmt, "FLIPBasketSupport") >= 0)
        {
         datetime cTime = OrderCloseTime();
         if(cTime > lastCloseTime)
            lastCloseTime = cTime;
        }
     }

   if(lastCloseTime > LastClosedFLIPBasketSupportTime)
      LastClosedFLIPBasketSupportTime = lastCloseTime;

   return lastCloseTime;
  }

//+------------------------------------------------------------------+
//| CloseFLIPBasketSupportOrders: Closes active FLIPBasketSupport    |
//| orders on flip change, basket close, or orphan cleanup.          |
//| targetType: OP_BUY, OP_SELL, or -1 (all)                         |
//+------------------------------------------------------------------+
void CloseFLIPBasketSupportOrders(int targetType = -1, bool closeLsdOrders = false)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(!IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()))
         continue;
      if(!closeLsdOrders && StringFind(OrderComment(), "FLIPBasketSupport_LSD") >= 0)
         continue;

      int oType = OrderType();

      // Check targetType matching (matches market & pending for the direction)
      if(targetType == OP_BUY)
        {
         if(oType != OP_BUY && oType != OP_BUYSTOP && oType != OP_BUYLIMIT)
            continue;
        }
      else if(targetType == OP_SELL)
        {
         if(oType != OP_SELL && oType != OP_SELLSTOP && oType != OP_SELLLIMIT)
            continue;
        }
      else if(targetType >= 0 && oType != targetType)
        {
         continue;
        }

      int ticket = OrderTicket();
      double lots = OrderLots();

      if(oType == OP_BUY || oType == OP_SELL)
        {
         bool closed = false;
         for(int attempt = 0; attempt < 3; attempt++)
           {
            RefreshRates();
            double closePrice = (oType == OP_BUY) ? Bid : Ask;
            closePrice = NormalizeDouble(closePrice, Digits);
            ResetLastError();
            closed = OrderClose(ticket, lots, closePrice, Slippage, (oType == OP_BUY ? clrRed : clrBlue));
            if(closed)
              {
               LastClosedFLIPBasketSupportTime = TimeCurrent();
               if(ticket == g_lastActiveFLIPBasketSupportTicket)
                  g_lastActiveFLIPBasketSupportTicket = -1;
               Print("FLIPBasketSupport Ticket #", ticket, " (", (oType == OP_BUY ? "BUY" : "SELL"), ") closed successfully at ", DoubleToString(closePrice, Digits));
               InvalidateTotalEAOrdersCache();
               break;
              }
            Sleep(100);
           }

         if(!closed)
           {
            Print("Direct OrderClose failed for FLIPBasketSupport #", ticket, ", trying SafeOrderCloseMarket...");
            if(SafeOrderCloseMarket(ticket, lots, Slippage, (oType == OP_BUY ? clrRed : clrBlue)))
              {
               LastClosedFLIPBasketSupportTime = TimeCurrent();
               if(ticket == g_lastActiveFLIPBasketSupportTicket)
                  g_lastActiveFLIPBasketSupportTicket = -1;
               InvalidateTotalEAOrdersCache();
              }
           }
        }
      else if(oType == OP_BUYSTOP || oType == OP_SELLSTOP || oType == OP_BUYLIMIT || oType == OP_SELLLIMIT)
        {
         SafeOrderDelete(ticket, clrYellow);
         LastClosedFLIPBasketSupportTime = TimeCurrent();
         if(ticket == g_lastActiveFLIPBasketSupportTicket)
            g_lastActiveFLIPBasketSupportTicket = -1;
         InvalidateTotalEAOrdersCache();
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckAndCloseOrphanFLIPBasketSupportOrders                       |
//| Ensures a FLIPBasketSupport order never remains orphan / single. |
//| - If all regular SELL market orders are closed, close any SELL   |
//|   FLIPBasketSupport order immediately.                           |
//| - If all regular BUY market orders are closed, close any BUY     |
//|   FLIPBasketSupport order immediately.                           |
//| - Also deletes pending FLIPBasketSupport orders if all regular   |
//|   orders in that direction are gone.                             |
//+------------------------------------------------------------------+
void CheckAndCloseOrphanFLIPBasketSupportOrders()
  {
   if(!EAStartupComplete)
      return;
   if(OnlyAllowFLIPBasketSupportOrders)
      return;

   int regularBuyMarketCount   = 0;
   int regularSellMarketCount  = 0;
   int regularBuyTotalCount    = 0;
   int regularSellTotalCount   = 0;

   int supportBuyMarketCount   = 0;
   int supportSellMarketCount  = 0;
   int supportBuyPendingCount  = 0;
   int supportSellPendingCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      bool isSupport = IsFLIPBasketSupportOrder(OrderTicket(), OrderComment());
      if(isSupport && StringFind(OrderComment(), "FLIPBasketSupport_LSD") >= 0)
         continue; // LSD-triggered FLIPBasketSupport orders are standalone entries and must not be closed as orphans

      if(oType == OP_BUY)
        {
         if(isSupport)
            supportBuyMarketCount++;
         else
           {
            regularBuyMarketCount++;
            regularBuyTotalCount++;
           }
        }
      else if(oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
        {
         if(isSupport)
            supportBuyPendingCount++;
         else
            regularBuyTotalCount++;
        }
      else if(oType == OP_SELL)
        {
         if(isSupport)
            supportSellMarketCount++;
         else
           {
            regularSellMarketCount++;
            regularSellTotalCount++;
           }
        }
      else if(oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
        {
         if(isSupport)
            supportSellPendingCount++;
         else
            regularSellTotalCount++;
        }
     }

   // 1. SELL SIDE: If support SELL market order exists but 0 regular SELL market orders remain -> ORPHAN! Close it!
   if(supportSellMarketCount > 0 && regularSellMarketCount == 0)
     {
      Print("ORPHAN FLIPBasketSupport SELL DETECTED: All regular SELL orders are closed (0 market SELL left). Closing FLIPBasketSupport SELL immediately.");
      CloseFLIPBasketSupportOrders(OP_SELL);
     }


   // 2. BUY SIDE: If support BUY market order exists but 0 regular BUY market orders remain -> ORPHAN! Close it!
   if(supportBuyMarketCount > 0 && regularBuyMarketCount == 0)
     {
      Print("ORPHAN FLIPBasketSupport BUY DETECTED: All regular BUY orders are closed (0 market BUY left). Closing FLIPBasketSupport BUY immediately.");
      CloseFLIPBasketSupportOrders(OP_BUY);
     }

  }

//+------------------------------------------------------------------+
//| HasOppositeOrderTypeLossOver5: Checks if opposite order type has |
//| net loss > $5.00 or any single order has loss > $5.00.           |
//+------------------------------------------------------------------+
bool HasOppositeOrderTypeLossOver5(int currentDirection, double &outOppositeTotalPL, double &outMaxSingleLoss)
  {
   outOppositeTotalPL = 0.0;
   outMaxSingleLoss = 0.0;
   int oppType = (currentDirection == 1) ? OP_SELL : OP_BUY;
   int oppCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != oppType)
         continue;

      oppCount++;
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      outOppositeTotalPL += pl;
      if(pl < 0.0)
        {
         double lossVal = MathAbs(pl);
         if(lossVal > outMaxSingleLoss)
            outMaxSingleLoss = lossVal;
        }
     }

   if(oppCount == 0)
      return false;

// Condition satisfied if total net loss on opposite side > $5.00 OR single opposite order loss > $5.00
   if(outOppositeTotalPL < -FLIPBasketSupportRecreateOppositeMinLossUSD ||
      outMaxSingleLoss > FLIPBasketSupportRecreateOppositeMinLossUSD)
     {
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| SendFLIPBasketSupportOrder: Dedicated direct order placement     |
//| for FLIPBasketSupport orders. Bypasses regular order filters     |
//| in SafeOrderSend (loss thresholds, counter-trend gates, etc.)    |
//| while ensuring lot normalization and retry resilience on error.  |
//+------------------------------------------------------------------+
int SendFLIPBasketSupportOrder(int pendingType, double lots, double price, double stopLoss, double takeProfit, string comment, color arrowColor)
  {
   lots       = NormalizeLots(lots);
   price      = NormalizeDouble(price, Digits);
   stopLoss   = (stopLoss > 0.0) ? NormalizeDouble(stopLoss, Digits) : 0.0;
   takeProfit = (takeProfit > 0.0) ? NormalizeDouble(takeProfit, Digits) : 0.0;

   int ticket = -1;
   int maxAttempts = 3;

   for(int attempt = 0; attempt < maxAttempts; attempt++)
     {
      RefreshRates();
      ResetLastError();

      ticket = OrderSend(Symbol(), pendingType, lots, price, Slippage, stopLoss, takeProfit, comment, MagicNumber, 0, arrowColor);
      if(ticket > 0)
        {
         InvalidateTotalEAOrdersCache();
         return ticket;
        }

      int err = GetLastError();
      Print("FLIPBasketSupport OrderSend attempt ", (attempt + 1), " failed. Err=", err);

      // Retry on transient quote/busy errors
      if(err == 136 || err == 138 || err == 135 || err == 137 || err == 146)
        {
         Sleep(100);
         continue;
        }

      break;
     }

   return ticket;
  }

//+------------------------------------------------------------------+
//| CreateFLIPBasketSupportOrder: Opens 1 market order on every flip |
//| Supported long-term for basket profit until $10 equity lock      |
//| SAFEST METHOD: Closes already open support order before creating |
//| new one; strictly maximum 1 active support order in total!       |
//| Take profit set to 500 raw BTC price distance                    |
//+------------------------------------------------------------------+
int CreateFLIPBasketSupportOrder(int flipDirection, bool ignoreEmaDistanceGate = false, bool ignoreAllGates = false, string commentSuffix = "")
  {
   if(!EAStartupComplete)
      return -1;
   if(GetTotalEAOrders() >= MaxOpenOrders)
     {
      Print("FLIPBasketSupport order skipped: MaxOpenOrders reached");
      return -1;
     }

   if(!ignoreAllGates)
     {
// Gate: Order blocked if elapsed time since EmaFlipTime is less than 15 minutes (minimum 15 min after flip time)
   if(EmaFlipTime == 0 || (TimeCurrent() - EmaFlipTime) < FLIPBasketSupportMinFlipElapsedSeconds)
     {
      static datetime lastFlipElapsedLogTime = 0;
      if(TimeCurrent() - lastFlipElapsedLogTime >= 30) // Throttle journal logs to once per 30 seconds
        {
         lastFlipElapsedLogTime = TimeCurrent();
         if(EmaFlipTime == 0)
           {
            Print("FLIPBasketSupport order blocked: No EMA flip recorded yet (EmaFlipTime == 0). Requires minimum 15 min after flip time.");
           }
         else
           {
            int elapsedSec = (int)(TimeCurrent() - EmaFlipTime);
            int remainingSec = FLIPBasketSupportMinFlipElapsedSeconds - elapsedSec;
            Print("FLIPBasketSupport order blocked: Elapsed time since EMA flip < 15 min (TimeCurrent() - EmaFlipTime > 60*15 required). Elapsed=",
                  elapsedSec, "s (", (elapsedSec / 60), "m ", (elapsedSec % 60), "s), Required >= ", FLIPBasketSupportMinFlipElapsedSeconds,
                  "s (15 min). Remaining=", remainingSec, "s (", (remainingSec / 60), "m ", (remainingSec % 60), "s).");
           }
        }
      return -1;
     }

   int targetOrderType = (flipDirection == 1) ? OP_BUY : OP_SELL;

   if(GetOpenPL(targetOrderType)>=0)
     {
      //      return -1;
     }

// 0C. Weak Trend Gate: Do not create FLIPBasketSupport order when IsEmaWEAKDistanceReduced50PercentFromPeak is weak
   if(FLIPBasketSupportBlockOnWeakEma)
     {
      if(IsEmaWEAKDistanceReduced50PercentFromPeak(targetOrderType) || IsEmaWEAKDistanceReduced50PercentFromPeak(-1))
        {
         static datetime lastWeakSupportPrintTime = 0;
         if(TimeCurrent() - lastWeakSupportPrintTime >= 30) // Throttle journal logs to once per 30 seconds
           {
            lastWeakSupportPrintTime = TimeCurrent();
            Print("FLIPBasketSupport order blocked: IsEmaWEAKDistanceReduced50PercentFromPeak() is WEAK. (Trend is exhausted / pulling back from peak).");
           }
         return -1;
        }
     }

// 0D. Weak State Count Gate: Block FLIPBasketSupport if strong=" Weak" was detected more than once this EMA cycle
   if(GetWeakStateCountPerEmaFlip() > 1)
     {
      static datetime lastWeakCountPrintTime = 0;
      if(TimeCurrent() - lastWeakCountPrintTime >= 30)
        {
         lastWeakCountPrintTime = TimeCurrent();
         Print("FLIPBasketSupport order blocked [Gate 0D]: Weak state detected ",
               GetWeakStateCountPerEmaFlip(), " times this EMA cycle (> 1). Trend is exhausted.");
        }
      return -1;
     }

// Gate 9: EMA State Gate (string emaState="N/A"; emaState should be "BULLISH" for buy orders, "BEARISH" for sell orders)
   RefreshRates();
   double ema200Val = iMA(Symbol(), Period(), InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE, InpEMAPriceShift);
   string emaState = "N/A";
   if(ema200Val > 0.0)
     {
      if(Bid > ema200Val)
         emaState = "BULLISH";
      else if(Bid < ema200Val)
         emaState = "BEARISH";
      else
         emaState = "AT EMA";
     }

   string checkEmaState = emaState;
   StringToUpper(checkEmaState);

   if(flipDirection == 1) // BUY orders require BULLISH emaState
     {
      if(checkEmaState != "BULLISH")
        {
         static datetime lastEmaStateBuyLogTime = 0;
         if(TimeCurrent() - lastEmaStateBuyLogTime >= 30) // Throttle journal logs to once per 30 seconds
           {
            lastEmaStateBuyLogTime = TimeCurrent();
            Print("FLIPBasketSupport order blocked [Gate 9]: emaState is '", emaState,
                  "' (Bid=", DoubleToString(Bid, Digits), ", EMA200=", DoubleToString(ema200Val, Digits),
                  "). Required: 'BULLISH' for BUY orders.");
           }
         return -1;
        }
     }
   else if(flipDirection == -1) // SELL orders require BEARISH emaState
     {
      if(checkEmaState != "BEARISH")
        {
         static datetime lastEmaStateSellLogTime = 0;
         if(TimeCurrent() - lastEmaStateSellLogTime >= 30) // Throttle journal logs to once per 30 seconds
           {
            lastEmaStateSellLogTime = TimeCurrent();
            Print("FLIPBasketSupport order blocked [Gate 9]: emaState is '", emaState,
                  "' (Bid=", DoubleToString(Bid, Digits), ", EMA200=", DoubleToString(ema200Val, Digits),
                  "). Required: 'BEARISH' for SELL orders.");
           }
         return -1;
        }
     }

// 0E. Order Position Gate (Gate 6):
//     - In BUY EMA: At least one open BUY order must already exist ABOVE the proposed entry price
//       with a minimum raw price gap of $100: (Existing BUY OpenPrice - Proposed Entry >= $100.0).
//     - In SELL EMA: At least one open SELL order must already exist BELOW the proposed entry price
//       with a minimum raw price gap of $100: (Proposed Entry - Existing SELL OpenPrice >= $100.0).
//     - In addition, proposed entry must maintain minimum $100 raw price gap from ANY open order in that direction.
   RefreshRates();
   double testPendingGap = (FLIPBasketSupportPendingGapRaw > 0.0) ? FLIPBasketSupportPendingGapRaw : ProfitReEntryGapRaw;
   if(testPendingGap <= 0.0)
      testPendingGap = 20.0;
   double testMinGap = GetRequiredStopDistance();
   double proposedEntryPrice = 0.0;

   if(flipDirection == 1) // BUY
     {
      proposedEntryPrice = Ask + testPendingGap;
      if(proposedEntryPrice < Ask + testMinGap)
         proposedEntryPrice = Ask + testMinGap;
     }
   else
      if(flipDirection == -1) // SELL
        {
         proposedEntryPrice = Bid - testPendingGap;
         if(proposedEntryPrice > Bid - testMinGap)
            proposedEntryPrice = Bid - testMinGap;
        }
   proposedEntryPrice = NormalizeDouble(proposedEntryPrice, Digits);

   double minOpenOrderGap = (FLIPBasketSupportMinOpenOrderGapRaw > 0.0) ? FLIPBasketSupportMinOpenOrderGapRaw : 100.0;
   bool hasQualifyingOpenOrder = false;
   int openSameDirCount = 0;
   double extremeOpenPrice = (flipDirection == 1) ? -1.0 : 999999999.0;
   int tooCloseOrderTicket = -1;
   double tooCloseOrderPrice = 0.0;
   double tooCloseOrderGap = 0.0;

   for(int posIdx = OrdersTotal() - 1; posIdx >= 0; posIdx--)
     {
      if(!OrderSelect(posIdx, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int curType = OrderType();
      if(flipDirection == 1) // BUY EMA: Look for BUY orders above proposed entry
        {
         if(curType != OP_BUY && curType != OP_BUYSTOP && curType != OP_BUYLIMIT)
            continue;
         openSameDirCount++;
         double oPrice = OrderOpenPrice();
         if(oPrice > extremeOpenPrice)
            extremeOpenPrice = oPrice;

         // Gate 6: Qualifying order must be above proposed entry with >= $100 raw price gap
         if((oPrice - proposedEntryPrice) >= minOpenOrderGap)
            hasQualifyingOpenOrder = true;

         // Check proximity: Maintain minimum $100 raw price gap from any open BUY order
         double dist = MathAbs(proposedEntryPrice - oPrice);
         if(dist < minOpenOrderGap)
           {
            tooCloseOrderTicket = OrderTicket();
            tooCloseOrderPrice  = oPrice;
            tooCloseOrderGap    = dist;
           }
        }
      else
         if(flipDirection == -1) // SELL EMA: Look for SELL orders below proposed entry
           {
            if(curType != OP_SELL && curType != OP_SELLSTOP && curType != OP_SELLLIMIT)
               continue;
            openSameDirCount++;
            double oPrice = OrderOpenPrice();
            if(oPrice < extremeOpenPrice)
               extremeOpenPrice = oPrice;

            // Gate 6: Qualifying order must be below proposed entry with >= $100 raw price gap
            if((proposedEntryPrice - oPrice) >= minOpenOrderGap)
               hasQualifyingOpenOrder = true;

            // Check proximity: Maintain minimum $100 raw price gap from any open SELL order
            double dist = MathAbs(proposedEntryPrice - oPrice);
            if(dist < minOpenOrderGap)
              {
               tooCloseOrderTicket = OrderTicket();
               tooCloseOrderPrice  = oPrice;
               tooCloseOrderGap    = dist;
              }
           }
     }

   if(!hasQualifyingOpenOrder)
     {
      static datetime lastOrderPosPrintTime = 0;
      if(TimeCurrent() - lastOrderPosPrintTime >= 30)
        {
         lastOrderPosPrintTime = TimeCurrent();
         if(openSameDirCount == 0)
           {
            Print("FLIPBasketSupport order blocked [Gate 6]: No existing open ",
                  (flipDirection == 1 ? "BUY" : "SELL"), " orders found. FlipBasketSupport requires at least one existing order ",
                  (flipDirection == 1 ? "above" : "below"), " it.");
           }
         else
           {
            Print("FLIPBasketSupport order blocked [Gate 6]: No existing open ",
                  (flipDirection == 1 ? "BUY" : "SELL"), " order found with min $100 raw gap ",
                  (flipDirection == 1 ? "above" : "below"), " proposed entry (", DoubleToString(proposedEntryPrice, Digits),
                  "). Extreme open price=", DoubleToString(extremeOpenPrice, Digits),
                  " (Gap=", DoubleToString(MathAbs(extremeOpenPrice - proposedEntryPrice), 2),
                  " < Required Min $100.00). Must have at least one order >= $100 ",
                  (flipDirection == 1 ? "above" : "below"), " it.");
           }
        }
      return -1;
     }

   if(tooCloseOrderTicket > 0)
     {
      static datetime lastOrderCloseGapPrintTime = 0;
      if(TimeCurrent() - lastOrderCloseGapPrintTime >= 30)
        {
         lastOrderCloseGapPrintTime = TimeCurrent();
         Print("FLIPBasketSupport order blocked [Gate 6 - Min Gap]: Too close to open ",
               (flipDirection == 1 ? "BUY" : "SELL"), " order #", tooCloseOrderTicket,
               " at ", DoubleToString(tooCloseOrderPrice, Digits),
               " | Proposed Entry=", DoubleToString(proposedEntryPrice, Digits),
               " | Gap=$", DoubleToString(tooCloseOrderGap, 2), " < Required Min $100.00.");
        }
      return -1;
     }

// Top / Bottom Position Guard for FLIPBasketSupport (V10078)
// FLIPBasketSupport order must not be in the top position or within $100 of extreme price after EMA flip
   if(flipDirection == 1) // BUY
     {
      double highestAfterFlip = GetHighestPriceSinceEmaFlip();
      if(proposedEntryPrice >= (highestAfterFlip - 100.0))
        {
         static datetime lastFlipTopLogTime = 0;
         if(TimeCurrent() - lastFlipTopLogTime >= 30)
           {
            lastFlipTopLogTime = TimeCurrent();
            Print("FLIPBasketSupport order blocked [Gate 0E - Top Position]: Proposed BUY entry (",
                  DoubleToString(proposedEntryPrice, Digits), ") is within $100 of peak price since EMA flip (",
                  DoubleToString(highestAfterFlip, Digits), "). FlipBasketSupport must not be in top position.");
           }
         return -1;
        }
     }
   else
      if(flipDirection == -1) // SELL
        {
         double lowestAfterFlip = GetLowestPriceSinceEmaFlip();
         if(proposedEntryPrice <= (lowestAfterFlip + 100.0))
           {
            static datetime lastFlipBottomLogTime = 0;
            if(TimeCurrent() - lastFlipBottomLogTime >= 30)
              {
               lastFlipBottomLogTime = TimeCurrent();
               Print("FLIPBasketSupport order blocked [Gate 0E - Bottom Position]: Proposed SELL entry (",
                     DoubleToString(proposedEntryPrice, Digits), ") is within $100 of lowest price since EMA flip (",
                     DoubleToString(lowestAfterFlip, Digits), "). FlipBasketSupport must not be in bottom position.");
              }
            return -1;
           }
        }

// 0F. 0.05 Lot Minimum Gap Gate:
// Maintain minimum $100 raw price gap between FLIPBasketSupportOrder and any open 0.05 lot order (same EMA direction)
   int tooClose005Ticket = -1;
   double tooClose005Price = 0.0;
   double tooClose005Gap = 0.0;

   for(int cIdx = OrdersTotal() - 1; cIdx >= 0; cIdx--)
     {
      if(!OrderSelect(cIdx, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int curType = OrderType();
      if(flipDirection == 1) // BUY EMA
        {
         if(curType != OP_BUY && curType != OP_BUYSTOP && curType != OP_BUYLIMIT)
            continue;
        }
      else
         if(flipDirection == -1) // SELL EMA
           {
            if(curType != OP_SELL && curType != OP_SELLSTOP && curType != OP_SELLLIMIT)
               continue;
           }
         else
            continue;

      double oLots = OrderLots();
      bool is005Lot = (MathAbs(oLots - 0.05) < 0.000001 || (balancelomultipler > 1 && MathAbs(oLots - (0.05 * balancelomultipler)) < 0.000001));
      if(!is005Lot)
         continue;

      double oOpen = OrderOpenPrice();
      double dist = MathAbs(proposedEntryPrice - oOpen);
      if(dist < 100.0)
        {
         tooClose005Ticket = OrderTicket();
         tooClose005Price = oOpen;
         tooClose005Gap = dist;
         break;
        }
     }

   if(tooClose005Ticket > 0)
     {
      static datetime last005GapPrintTime = 0;
      if(TimeCurrent() - last005GapPrintTime >= 30)
        {
         last005GapPrintTime = TimeCurrent();
         Print("FLIPBasketSupport order blocked [Gate 0F]: Too close to open 0.05 lot order #", tooClose005Ticket,
               " at ", DoubleToString(tooClose005Price, Digits),
               " | Proposed Entry=", DoubleToString(proposedEntryPrice, Digits),
               " | Gap=$", DoubleToString(tooClose005Gap, 2), " < Required Min $100.00.");
        }
      return -1;
     }
     } // End if(!ignoreAllGates)

   int targetOrderType   = (flipDirection == 1) ? OP_BUY : OP_SELL;
   int oppositeOrderType = (flipDirection == 1) ? OP_SELL : OP_BUY;

   // 1. Strict concurrency gate: If an active FLIPBasketSupport order in the SAME direction already exists, do not recreate/churn!
   if(HasOpenFLIPBasketSupportOrder(targetOrderType))
     {
      return -1;
     }

   // 2. If an opposite FLIPBasketSupport order exists, close it before opening the new direction
   if(HasOpenFLIPBasketSupportOrder(oppositeOrderType))
     {
      CloseFLIPBasketSupportOrders(oppositeOrderType, true);
     }

   // 3. Final safety check: strictly max 1 active support order in total allowed
   if(HasOpenFLIPBasketSupportOrder(-1))
     {
      Print("FLIPBasketSupport order skipped: An active FLIPBasketSupport order is still open. Strictly max 1 active allowed in total.");
      return -1;
     }

   RefreshRates();
   double flipLots = FLIPBasketSupportLot * (balancelomultipler > 0 ? balancelomultipler : 1);
   flipLots = NormalizeLots(flipLots);

   int ticket = -1;
   string comment = "FLIPBasketSupport" + commentSuffix;

// Raw gap for pending stop order placement (like ProfitReEntryGapRaw)
   double pendingGap = (FLIPBasketSupportPendingGapRaw > 0.0) ? FLIPBasketSupportPendingGapRaw : ProfitReEntryGapRaw;
   if(pendingGap <= 0.0)
      pendingGap = 20.0;

   double minimumGap = GetRequiredStopDistance();

// Take profit set to raw BTC price distance
   double tpDist = (FLIPBasketSupportTakeProfitDistanceRaw > 0.0) ? FLIPBasketSupportTakeProfitDistanceRaw : 2000.0;

   if(flipDirection == 1) // FLIP to BUY -> Pending BUY STOP
     {
      int pendingType = OP_BUYSTOP;
      double entryPrice = Ask + pendingGap;
      if(entryPrice < Ask + minimumGap)
         entryPrice = Ask + minimumGap;
      entryPrice = NormalizeDouble(entryPrice, Digits);

      double slDistance = (FLIPBasketSupportStopLossRaw > 0.0) ? FLIPBasketSupportStopLossRaw : 200.0;
      double stopLoss = (slDistance > 0) ? NormalizeDouble(entryPrice - slDistance, Digits) : 0.0;
      double takeProfit = (tpDist > 0) ? NormalizeDouble(entryPrice + tpDist, Digits) : 0.0;

      ticket = SendFLIPBasketSupportOrder(pendingType, flipLots, entryPrice, stopLoss, takeProfit, comment, clrLime);
      if(ticket > 0)
        {
         g_lastActiveFLIPBasketSupportTicket = ticket;
         Print("FLIP BASKET SUPPORT PENDING ORDER CREATED: BUY STOP Ticket #", ticket, " Lots=", DoubleToString(flipLots, 2),
               " Entry=", DoubleToString(entryPrice, Digits), " (Ask+", DoubleToString(pendingGap, 2), ")",
               " SL=", DoubleToString(stopLoss, Digits), " TP=", DoubleToString(takeProfit, Digits), " (TPdist=", DoubleToString(tpDist, 2), ")");
        }
     }
   else
      if(flipDirection == -1) // FLIP to SELL -> Pending SELL STOP
        {
         int pendingType = OP_SELLSTOP;
         double entryPrice = Bid - pendingGap;
         if(entryPrice > Bid - minimumGap)
            entryPrice = Bid - minimumGap;
         entryPrice = NormalizeDouble(entryPrice, Digits);

         double slDistance = (FLIPBasketSupportStopLossRaw > 0.0) ? FLIPBasketSupportStopLossRaw : 200.0;
         double stopLoss = (slDistance > 0) ? NormalizeDouble(entryPrice + slDistance, Digits) : 0.0;
         double takeProfit = (tpDist > 0) ? NormalizeDouble(entryPrice - tpDist, Digits) : 0.0;

         ticket = SendFLIPBasketSupportOrder(pendingType, flipLots, entryPrice, stopLoss, takeProfit, comment, clrTomato);
         if(ticket > 0)
           {
            g_lastActiveFLIPBasketSupportTicket = ticket;
            Print("FLIP BASKET SUPPORT PENDING ORDER CREATED: SELL STOP Ticket #", ticket, " Lots=", DoubleToString(flipLots, 2),
                  " Entry=", DoubleToString(entryPrice, Digits), " (Bid-", DoubleToString(pendingGap, 2), ")",
                  " SL=", DoubleToString(stopLoss, Digits), " TP=", DoubleToString(takeProfit, Digits), " (TPdist=", DoubleToString(tpDist, 2), ")");
           }
        }

   if(ticket > 0)
     {
      g_flipBasketSupportCreatedInCycle++;
     }

   return ticket;
  }

//+------------------------------------------------------------------+
//| ManageFLIPBasketSupportTrailingStopLoss: Dedicated step-trailing |
//| StopLoss engine for FLIPBasketSupport AND Recovery orders.       |
//| Ratchets StopLoss forward on every 100 raw BTC step move in      |
//| positive profit (FLIPBasketSupportTakeProfitDistanceStopLossStep)|
//| Step 1 (+100 move): SL = openPrice (100 below live price / BE)   |
//| Step 2 (+200 move): SL = openPrice +/- 100 (+100 profit locked)  |
//| Step 3 (+300 move): SL = openPrice +/- 200 (+200 profit locked)  |
//| Step N (+N*100 move): SL = openPrice +/- (N-1)*100               |
//| Respects broker MODE_STOPLEVEL / GetRequiredStopDistance().      |
//+------------------------------------------------------------------+
void ManageFLIPBasketSupportTrailingStopLoss()
  {
   if(!EAStartupComplete)
      return;
   if(FLIPBasketSupportTakeProfitDistanceStopLossStep <= 0.0)
      return;

   double stepSize = FLIPBasketSupportTakeProfitDistanceStopLossStep;
   if(stepSize <= 0.0)
      stepSize = 100.0;

   RefreshRates();
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double spreadBuf = (Ask - Bid) * 1.5;
   double reqDistance = GetRequiredStopDistance();
   double minSafeDist = MathMax(reqDistance, MathMax(stopLevel, spreadBuf));
   if(minSafeDist < Point * 10.0)
      minSafeDist = Point * 10.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      bool isFlipSupport = IsFLIPBasketSupportOrder(OrderTicket(), OrderComment());
      bool isRecovery    = IsAnyRecoveryOrder(OrderTicket(), OrderComment());

      if(!isFlipSupport && !isRecovery)
         continue;

      int ticket       = OrderTicket();
      int oType        = OrderType();
      double openPrice = OrderOpenPrice();
      double curSL     = OrderStopLoss();
      double curTP     = OrderTakeProfit();

      if(oType == OP_BUY)
        {
         double favorableMove = Bid - openPrice;
         if(favorableMove < stepSize)
            continue; // Not yet reached 1st step (+100)

         int steps = (int)MathFloor(favorableMove / stepSize);
         if(steps < 1)
            continue;

         // Step 1 (+100 move): targetSL = openPrice (0 distance from openPrice, 100 below live price / breakeven)
         // Step 2 (+200 move): targetSL = openPrice + 100 (+100 profit locked)
         // Step 3 (+300 move): targetSL = openPrice + 200 (+200 profit locked)
         // Step N (+N*100 move): targetSL = openPrice + ((N - 1) * stepSize)
         double targetSL = NormalizeDouble(openPrice + ((steps - 1) * stepSize), Digits);

         // Broker safety: SL cannot be closer to Bid than minSafeDist
         if(targetSL > Bid - minSafeDist)
            targetSL = NormalizeDouble(Bid - minSafeDist, Digits);

         // Ratchet check: Only move SL forward (higher), never loosen
         if(curSL == 0.0 || targetSL > curSL + (Point * 0.5))
           {
            ResetLastError();
            bool modified = SafeOrderModify(ticket, openPrice, targetSL, curTP, 0, clrLimeGreen);
            Print("Step-Trailing [", (isFlipSupport ? "FLIP_SUPPORT" : "RECOVERY"), "]: BUY #", ticket,
                  " Step=", steps, " (+", DoubleToString(favorableMove, 2), " pts)",
                  " | Prev SL=", DoubleToString(curSL, Digits),
                  " | New SL=", DoubleToString(targetSL, Digits),
                  " | Success=", modified);
           }
        }
      else
         if(oType == OP_SELL)
           {
            double favorableMove = openPrice - Ask;
            if(favorableMove < stepSize)
               continue; // Not yet reached 1st step (+100)

            int steps = (int)MathFloor(favorableMove / stepSize);
            if(steps < 1)
               continue;

            // Step 1 (+100 move): targetSL = openPrice (0 distance from openPrice, 100 above live price / breakeven)
            // Step 2 (+200 move): targetSL = openPrice - 100 (+100 profit locked)
            // Step 3 (+300 move): targetSL = openPrice - 200 (+200 profit locked)
            // Step N (+N*100 move): targetSL = openPrice - ((N - 1) * stepSize)
            double targetSL = NormalizeDouble(openPrice - ((steps - 1) * stepSize), Digits);

            // Broker safety: SL cannot be closer to Ask than minSafeDist
            if(targetSL < Ask + minSafeDist)
               targetSL = NormalizeDouble(Ask + minSafeDist, Digits);

            // Ratchet check: Only move SL forward (lower), never loosen
            if(curSL == 0.0 || targetSL < curSL - (Point * 0.5))
              {
               ResetLastError();
               bool modified = SafeOrderModify(ticket, openPrice, targetSL, curTP, 0, clrTomato);
               Print("Step-Trailing [", (isFlipSupport ? "FLIP_SUPPORT" : "RECOVERY"), "]: SELL #", ticket,
                     " Step=", steps, " (+", DoubleToString(favorableMove, 2), " pts)",
                     " | Prev SL=", DoubleToString(curSL, Digits),
                     " | New SL=", DoubleToString(targetSL, Digits),
                     " | Success=", modified);
              }
           }
     }
  }



//Chance 1B: Pair Profit 2-Order Combination Live SL Modifier (> $1 profit)
bool   EnablePairProfitSLModify =true;// false;             // Disabled: avoid 20pt choke so 100-step trailing ladder has full authority
double PairCombinationProfitThresholdUSD = 1.0;       // Threshold profit in USD for 2-order combination
double PairCombinationSLDistanceRaw = 0.0;            // Distance from live price in raw points (0.0 = auto broker stop level)
bool   PairCombinationUseBalanceMultiplier = false;   // If true, scale threshold by balance multiplier (default false: fixed $1.00 USD)
bool   InpEnableCombinationProfitClose     = true;    // Close any order combination (or single order) when sum > $1 * multiplier
double InpCombinationCloseProfitUSD        = 1.0;     // Base profit threshold in USD ($1.00)
void   CheckBasketProfitClose();
void   CloseAllOpenBuyOrders(string reason = "");
void   CloseAllOpenSellOrders(string reason = "");
void   CloseProfitableOrderCombinations();
void   ModifyPairProfitWithStopLoss();
int    GetOriginalTicket(int ticket, string comment);
string GetRootOrderComment(int ticket, string comment = "");
string GetEffectiveOrderComment(int ticket, string comment = "");
void   RegisterPreservedOrderComment(int ticket, string comment);
string GetPreservedOrderComment(int ticket);
bool   IsAnyRecoveryOrder(int ticket, string comment = "");
int    GetRecoveryOrderParentTicket(int ticket, string comment = "");
void   MonitorEquityLossStopLossProtection();
double UpdateDynamicBasket10USDLockStep(double netPL);
double GetTotalLots(int orderType);
bool   IsEmaWEAKDistanceReduced50PercentFromPeak(int orderType = -1);
void   ManageHeavyExposurePartialLossClose();
bool   CanExecutePartialLossClose(int orderType);
bool     IsFLIPBasketSupportOrder(int ticket, string comment = "");
bool     HasOpenFLIPBasketSupportOrder(int targetType = -1, bool excludeLsd = false);
void     CloseFLIPBasketSupportOrders(int targetType = -1, bool closeLsdOrders = false);
void     CheckAndCloseOrphanFLIPBasketSupportOrders();
int      SendFLIPBasketSupportOrder(int pendingType, double lots, double price, double stopLoss, double takeProfit, string comment, color arrowColor);
int      CreateFLIPBasketSupportOrder(int flipDirection, bool ignoreEmaDistanceGate = false, bool ignoreAllGates = false, string commentSuffix = "");
void     CheckLsdSweepFlipBasketSupportOrder();
datetime GetLastClosedFLIPBasketSupportCloseTime();
bool     HasOppositeOrderTypeLossOver5(int currentDirection, double &outOppositeTotalPL, double &outMaxSingleLoss);
void     InitializeFLIPBasketSupportTracking();
void     ManageFLIPBasketSupportTrailingStopLoss();
int      GetWeakStateCountPerEmaFlip();
double   GetHighestPriceSinceEmaFlip();
double   GetLowestPriceSinceEmaFlip();
bool     SafeOrderCloseMarket(int ticket, double lots, int slippage, color arrowColor);
void     DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step);

bool IsRecoveryOrderWithActiveParent(int ticket, string comment = "");

//+------------------------------------------------------------------+
//| Preserved Comment Mapping Registry for Partial Closes            |
//| Preserves original "RECOVERY_XXXXX" prefix across MT4 "from #"   |
//| child tickets generated by OrderClose()                          |
//+------------------------------------------------------------------+
struct PreservedCommentMapping
  {
   int               ticket;
   string            comment;
  };
PreservedCommentMapping g_orderCommentRegistry[500];
int g_orderCommentRegistryCount = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RegisterPreservedOrderComment(int ticket, string comment)
  {
   if(ticket <= 0 || comment == "")
      return;
   for(int i = 0; i < g_orderCommentRegistryCount; i++)
     {
      if(g_orderCommentRegistry[i].ticket == ticket)
        {
         g_orderCommentRegistry[i].comment = comment;
         return;
        }
     }
   if(g_orderCommentRegistryCount < 500)
     {
      g_orderCommentRegistry[g_orderCommentRegistryCount].ticket = ticket;
      g_orderCommentRegistry[g_orderCommentRegistryCount].comment = comment;
      g_orderCommentRegistryCount++;
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string GetPreservedOrderComment(int ticket)
  {
   if(ticket <= 0)
      return "";
   for(int i = 0; i < g_orderCommentRegistryCount; i++)
     {
      if(g_orderCommentRegistry[i].ticket == ticket)
         return g_orderCommentRegistry[i].comment;
     }
   return "";
  }

//+------------------------------------------------------------------+
//| GetEffectiveOrderComment: Resolves preserved or root comment     |
//| so partial close child orders retain their RECOVERY_XXXXX prefix |
//+------------------------------------------------------------------+
string GetEffectiveOrderComment(int ticket, string comment = "")
  {
   string curComment = comment;
   if(curComment == "")
     {
      if(OrderTicket() == ticket)
         curComment = OrderComment();
      else
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            curComment = OrderComment();
         else
            if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
               curComment = OrderComment();
     }

// 1. If raw comment already contains RECOVERY_, register and return it
   if(StringFind(curComment, "RECOVERY_") >= 0)
     {
      RegisterPreservedOrderComment(ticket, curComment);
      return curComment;
     }

// 2. Check internal preserved comment registry
   string preserved = GetPreservedOrderComment(ticket);
   if(preserved != "")
      return preserved;

// 3. Resolve root comment across "from #" history
   if(StringFind(curComment, "from #") >= 0)
     {
      string rootCmt = GetRootOrderComment(ticket, curComment);
      if(StringFind(rootCmt, "RECOVERY_") >= 0)
        {
         RegisterPreservedOrderComment(ticket, rootCmt);
         return rootCmt;
        }
      return rootCmt;
     }

   return curComment;
  }

//+------------------------------------------------------------------+
//| IsAnyRecoveryOrder: Returns true if order is a recovery order    |
//| even if MT4 partial close changed comment to "from #xxxxx"       |
//+------------------------------------------------------------------+
bool IsAnyRecoveryOrder(int ticket, string comment = "")
  {
   string curComment = comment;
   if(curComment == "")
     {
      if(OrderTicket() == ticket)
         curComment = OrderComment();
      else
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            curComment = OrderComment();
         else
            if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
               curComment = OrderComment();
     }

   if(StringFind(curComment, "RECOVERY_") >= 0)
      return true;

   string effComment = GetEffectiveOrderComment(ticket, curComment);
   if(StringFind(effComment, "RECOVERY_") >= 0)
      return true;

   if(StringFind(curComment, "from #") >= 0)
     {
      string rootCmt = GetRootOrderComment(ticket, curComment);
      if(StringFind(rootCmt, "RECOVERY_") >= 0)
         return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| GetRecoveryOrderParentTicket: Extracts parent ticket from root   |
//| or effective comment across partial close chains.                |
//+------------------------------------------------------------------+
int GetRecoveryOrderParentTicket(int ticket, string comment = "")
  {
   string effCmt = GetEffectiveOrderComment(ticket, comment);
   int pos = StringFind(effCmt, "RECOVERY_");
   if(pos >= 0)
     {
      string numPart = StringSubstr(effCmt, pos + 9);
      return (int)StringToInteger(numPart);
     }
   string rootCmt = GetRootOrderComment(ticket, comment);
   pos = StringFind(rootCmt, "RECOVERY_");
   if(pos >= 0)
     {
      string numPart = StringSubstr(rootCmt, pos + 9);
      return (int)StringToInteger(numPart);
     }
   return 0;
  }

//+------------------------------------------------------------------+
//| GetRootOrderComment: Resolves root comment across partial closes |
//| so recovery orders never lose their RECOVERY_<parent> identity   |
//+------------------------------------------------------------------+
string GetRootOrderComment(int ticket, string comment = "")
  {
   string curComment = comment;
   if(curComment == "")
     {
      if(OrderTicket() == ticket)
         curComment = OrderComment();
      else
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            curComment = OrderComment();
         else
            if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
               curComment = OrderComment();
     }

   if(StringFind(curComment, "from #") < 0)
      return curComment;

   int current = ticket;
   int currentSelectedTicket = OrderTicket();
   int loops = 0;

   while(loops < 25)
     {
      loops++;
      int pos = StringFind(curComment, "from #");
      if(pos < 0)
         break;

      string parentStr = StringSubstr(curComment, pos + 6);
      int parentTicket = (int)StringToInteger(parentStr);
      if(parentTicket <= 0 || parentTicket == current)
         break;

      current = parentTicket;
      bool found = false;
      if(OrderSelect(current, SELECT_BY_TICKET, MODE_HISTORY))
        {
         curComment = OrderComment();
         found = true;
        }
      else
         if(OrderSelect(current, SELECT_BY_TICKET, MODE_TRADES))
           {
            curComment = OrderComment();
            found = true;
           }

      if(!found)
         break;
     }

   if(currentSelectedTicket > 0 && OrderTicket() != currentSelectedTicket)
      OrderSelect(currentSelectedTicket, SELECT_BY_TICKET, MODE_TRADES);

   return curComment;
  }


//+------------------------------------------------------------------+
//| ModifyPairProfitWithStopLoss      any2profitorders                               |
//| Checks all combinations of 2 open orders (excluding recovery     |
//| orders and FLIPBasketSupport orders). If any 2-order combination |
//| has combined profit > $1.00 (PairCombinationProfitThresholdUSD), |
//| modifies both orders with stop loss to protect/lock the profit.  |
//+------------------------------------------------------------------+
void ModifyPairProfitWithStopLoss()
  {
   if(!EnablePairProfitSLModify)
      return;

// 1. Scan and collect all eligible market orders
#define MAX_PAIR_SCAN_ORDERS 100
   int    candTickets[MAX_PAIR_SCAN_ORDERS];
   int    candTypes[MAX_PAIR_SCAN_ORDERS];
   double candLots[MAX_PAIR_SCAN_ORDERS];
   double candOpenPrices[MAX_PAIR_SCAN_ORDERS];
   double candStopLosses[MAX_PAIR_SCAN_ORDERS];
   double candTakeProfits[MAX_PAIR_SCAN_ORDERS];
   double candProfits[MAX_PAIR_SCAN_ORDERS];
   bool   qualifyForSL[MAX_PAIR_SCAN_ORDERS];
   ArrayInitialize(candTickets, 0);
   ArrayInitialize(candTypes, 0);
   ArrayInitialize(candLots, 0.0);
   ArrayInitialize(candOpenPrices, 0.0);
   ArrayInitialize(candStopLosses, 0.0);
   ArrayInitialize(candTakeProfits, 0.0);
   ArrayInitialize(candProfits, 0.0);
   ArrayInitialize(qualifyForSL, false);
   int    candCount = 0;

   double targetThreshold = PairCombinationProfitThresholdUSD;

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
     {
      targetThreshold=targetThreshold/2;
     }

   if(PairCombinationUseBalanceMultiplier && balancelomultipler > 1)
      targetThreshold = targetThreshold * balancelomultipler;

   for(int i = OrdersTotal() - 1; i >= 0 && candCount < MAX_PAIR_SCAN_ORDERS; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;
      // EXCLUDE RECOVERY ORDERS: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      string cmt = OrderComment();
      int tkt    = OrderTicket();

      // Exclude recovery orders
      if(IsAnyRecoveryOrder(tkt, cmt) || IsRecoveryOrderWithActiveParent(tkt, cmt))
         continue;

      // Exclude FLIPBasketSupport orders
      if(IsFLIPBasketSupportOrder(tkt, cmt) || StringFind(cmt, "FLIPBasketSupport") >= 0)
         continue;

      candTickets[candCount]    = tkt;
      candTypes[candCount]      = oType;
      candLots[candCount]       = OrderLots();
      candOpenPrices[candCount] = OrderOpenPrice();
      candStopLosses[candCount] = OrderStopLoss();
      candTakeProfits[candCount]= OrderTakeProfit();
      candProfits[candCount]    = OrderProfit() + OrderSwap() + OrderCommission();
      qualifyForSL[candCount]   = false;
      candCount++;
     }

   if(candCount < 2)
      return; // Need at least 2 orders to form a combination

// 2. Evaluate all 2-order combinations (i, j)
   int qualifyingPairsCount = 0;
   for(int i = 0; i < candCount - 1; i++)
     {
      for(int j = i + 1; j < candCount; j++)
        {
         double pairProfit = candProfits[i] + candProfits[j];
         if(pairProfit > targetThreshold)
           {
            qualifyForSL[i] = true;
            qualifyForSL[j] = true;
            qualifyingPairsCount++;
            Print("PAIR PROFIT > $", DoubleToString(targetThreshold, 2), " HIT: Pair [Ticket #", candTickets[i],
                  " ($", DoubleToString(candProfits[i], 2), ") + Ticket #", candTickets[j],
                  " ($", DoubleToString(candProfits[j], 2), ")] = Total $", DoubleToString(pairProfit, 2),
                  " | Qualifying both orders for StopLoss modification.");
           }
        }
     }

   if(qualifyingPairsCount == 0)
      return;

// 3. Modify qualifying orders with live StopLoss to lock profit
   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   if(minDistance < 20.0)
      minDistance = 20.0;


   double rawGap = (PairCombinationSLDistanceRaw > 0.0) ? PairCombinationSLDistanceRaw : 20.0;
   if(rawGap < minDistance)
      rawGap = minDistance;

   double curBid = MarketInfo(Symbol(), MODE_BID);
   double curAsk = MarketInfo(Symbol(), MODE_ASK);

   for(int k = 0; k < candCount; k++)
     {
      if(!qualifyForSL[k])
         continue;

      int    tkt   = candTickets[k];
      int    oType = candTypes[k];
      double oOpen = candOpenPrices[k];
      double curSL = candStopLosses[k];
      double curTP = candTakeProfits[k];

      RefreshRates();
      curBid = MarketInfo(Symbol(), MODE_BID);
      curAsk = MarketInfo(Symbol(), MODE_ASK);

      double proposedSL = 0.0;
      bool   shouldModify = false;

      if(oType == OP_BUY)
        {
         proposedSL = NormalizeDouble(curBid - rawGap, Digits);
         if((curBid - proposedSL) < minDistance)
            proposedSL = NormalizeDouble(curBid - minDistance, Digits);

// Ensure SL is strictly valid below Bid
         if(proposedSL >= curBid)
            continue;

         // Ensure SL only locks profit ABOVE open price (never prematurely tightens losing orders)
         if(proposedSL <= oOpen)
            continue;



         // For BUY: never move SL backward; only move forward (higher)
         if(curSL > -100.0 && proposedSL <= curSL)
            continue;

         // Avoid micro modifications below minimum modify gap
         if(curSL > -100.0 && (proposedSL - curSL) < MinimumSLModifyGapRaw)
            continue;

         shouldModify = true;
        }
      else
         if(oType == OP_SELL)
           {
            proposedSL = NormalizeDouble(curAsk + rawGap, Digits);
            if((proposedSL - curAsk) < minDistance)
               proposedSL = NormalizeDouble(curAsk + minDistance, Digits);

// Ensure SL is strictly valid above Ask
         if(proposedSL <= curAsk)
            continue;

         // Ensure SL only locks profit BELOW open price (never prematurely tightens losing orders)
         if(proposedSL >= oOpen)
            continue;



            // For SELL: never move SL backward; only move forward (lower)
            if(curSL > -100.0 && proposedSL >= curSL)
               continue;

            // Avoid micro modifications below minimum modify gap
            if(curSL > -100.0 && (curSL - proposedSL) < MinimumSLModifyGapRaw)
               continue;

            shouldModify = true;
           }

      if(shouldModify && proposedSL > 0.0)
        {
         ResetLastError();
         bool modified = SafeOrderModify(tkt, oOpen, proposedSL, curTP, 0, (oType == OP_BUY ? clrLimeGreen : clrTomato));
         if(modified)
           {
            Print("PAIR PROFIT SL MODIFIED | Ticket #", tkt,
                  " | Type=", (oType == OP_BUY ? "BUY" : "SELL"),
                  " | P/L=$", DoubleToString(candProfits[k], 2),
                  " | Old SL=", DoubleToString(curSL, Digits),
                  " | New SL=", DoubleToString(proposedSL, Digits));
           }
         else
           {
            Print("PAIR PROFIT SL MODIFY FAILED | Ticket #", tkt, " | Error=", GetLastError());
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Modify SL to live price with $50 gap or close on server error    |
//+------------------------------------------------------------------+
bool CloseMarketOrderDirect(int ticket)
  {
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
      return true; // Already closed

   int type = OrderType();
   if(type != OP_BUY && type != OP_SELL)
      return false;

   double lots = OrderLots();

   if(ServerRecoveryPending || !IsConnected())
     {
      return SafeOrderCloseMarket(ticket, lots, Slippage, (type == OP_BUY ? clrRed : clrBlue));
     }

   return SafeOrderClose(ticket, lots, type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
  }

//+------------------------------------------------------------------+
//| Close any combination of open orders when sum > $1 * multiplier  |
//| Supports 1, 2, 3 orders or entire basket, Buy or Sell or mixed   |
//+------------------------------------------------------------------+
void CloseProfitableOrderCombinations()
  {
   if(!InpEnableCombinationProfitClose)
      return;

   double minProfitUSD = InpCombinationCloseProfitUSD * balancelomultipler;
   if(minProfitUSD <= 0.0)
      minProfitUSD = 1.0;

// 1. Collect all open market orders for current symbol & magic number
#define MAX_COMB_ORDERS 100
   int    candTickets[MAX_COMB_ORDERS];
   int    candTypes[MAX_COMB_ORDERS];
   double candLots[MAX_COMB_ORDERS];
   double candProfits[MAX_COMB_ORDERS];
   bool   isClosed[MAX_COMB_ORDERS];
   ArrayInitialize(candTickets, 0);
   ArrayInitialize(candTypes, 0);
   ArrayInitialize(candLots, 0.0);
   ArrayInitialize(candProfits, 0.0);
   ArrayInitialize(isClosed, false);
   int    candCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0 && candCount < MAX_COMB_ORDERS; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;
      // EXCLUDE RECOVERY ORDERS: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      candTickets[candCount] = OrderTicket();
      candTypes[candCount]   = oType;
      candLots[candCount]    = OrderLots();
      candProfits[candCount] = OrderProfit() + OrderSwap() + OrderCommission();
      isClosed[candCount]    = false;
      candCount++;
     }

   if(candCount <= 0)
      return;

   bool anyOrdersClosed = false;

// 2. TOTAL BASKET CHECK (if all open orders combined sum >= minProfitUSD and count >= 2)
   if(candCount >= 2)
     {
      double totalBasketPL = 0.0;
      for(int b = 0; b < candCount; b++)
         totalBasketPL += candProfits[b];

      if(totalBasketPL >= minProfitUSD)
        {
         Print(">>> [COMBINATION CLOSE - ALL ORDERS] Total Basket Profit = $", DoubleToString(totalBasketPL, 2),
               " >= $", DoubleToString(minProfitUSD, 2), " | Closing ALL ", candCount, " open orders!");

         for(int b = 0; b < candCount; b++)
           {
            if(CloseMarketOrderDirect(candTickets[b]))
               isClosed[b] = true;
           }
         InvalidateTotalEAOrdersCache();
         return;
        }
     }

// 3. PRIORITY PAIR CHECK (Win + Loss): Pair a winning order with a losing order if sum >= minProfitUSD
   for(int i = 0; i < candCount - 1; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < candCount; j++)
        {
         if(isClosed[j])
            continue;

         // Check if at least one order is in loss (offsets losing order)
         if(candProfits[i] < 0.0 || candProfits[j] < 0.0)
           {
            double pairSum = candProfits[i] + candProfits[j];
            if(pairSum >= minProfitUSD)
              {
               Print(">>> [COMBINATION CLOSE - PAIR (WIN+LOSS)] Ticket #", candTickets[i],
                     " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[i], 2), ") + Ticket #",
                     candTickets[j], " (", (candTypes[j] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[j], 2),
                     ") = Total $", DoubleToString(pairSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Pair!");

               if(CloseMarketOrderDirect(candTickets[i]))
                  isClosed[i] = true;
               if(CloseMarketOrderDirect(candTickets[j]))
                  isClosed[j] = true;
               anyOrdersClosed = true;
              }
           }
        }
     }

// 4. PRIORITY TRIPLET CHECK (Win + Losses): Check combinations of 3 orders with at least one loss
   int maxTripletSearch = MathMin(candCount, 30);
   for(int i = 0; i < maxTripletSearch - 2; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < maxTripletSearch - 1; j++)
        {
         if(isClosed[j])
            continue;
         for(int k = j + 1; k < maxTripletSearch; k++)
           {
            if(isClosed[k])
               continue;

            if(candProfits[i] < 0.0 || candProfits[j] < 0.0 || candProfits[k] < 0.0)
              {
               double tripletSum = candProfits[i] + candProfits[j] + candProfits[k];
               if(tripletSum >= minProfitUSD)
                 {
                  Print(">>> [COMBINATION CLOSE - TRIPLET (WITH LOSS)] Tickets [#", candTickets[i], ", #", candTickets[j], ", #", candTickets[k],
                        "] = Total $", DoubleToString(tripletSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Triplet!");

                  if(CloseMarketOrderDirect(candTickets[i]))
                     isClosed[i] = true;
                  if(CloseMarketOrderDirect(candTickets[j]))
                     isClosed[j] = true;
                  if(CloseMarketOrderDirect(candTickets[k]))
                     isClosed[k] = true;
                  anyOrdersClosed = true;
                 }
              }
           }
        }
     }

// 5. ANY REMAINING PAIR CHECK (e.g. 2 Wins >= minProfitUSD)
   for(int i = 0; i < candCount - 1; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < candCount; j++)
        {
         if(isClosed[j])
            continue;

         double pairSum = candProfits[i] + candProfits[j];
         if(pairSum >= minProfitUSD)
           {
            Print(">>> [COMBINATION CLOSE - PAIR] Ticket #", candTickets[i],
                  " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[i], 2), ") + Ticket #",
                  candTickets[j], " (", (candTypes[j] == OP_BUY ? "BUY" : "SELL"), " $", DoubleToString(candProfits[j], 2),
                  ") = Total $", DoubleToString(pairSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Pair!");

            if(CloseMarketOrderDirect(candTickets[i]))
               isClosed[i] = true;
            if(CloseMarketOrderDirect(candTickets[j]))
               isClosed[j] = true;
            anyOrdersClosed = true;
           }
        }
     }

// 6. ANY REMAINING TRIPLET CHECK (e.g. 3 Wins >= minProfitUSD)
   for(int i = 0; i < maxTripletSearch - 2; i++)
     {
      if(isClosed[i])
         continue;
      for(int j = i + 1; j < maxTripletSearch - 1; j++)
        {
         if(isClosed[j])
            continue;
         for(int k = j + 1; k < maxTripletSearch; k++)
           {
            if(isClosed[k])
               continue;

            double tripletSum = candProfits[i] + candProfits[j] + candProfits[k];
            if(tripletSum >= minProfitUSD)
              {
               Print(">>> [COMBINATION CLOSE - TRIPLET] Tickets [#", candTickets[i], ", #", candTickets[j], ", #", candTickets[k],
                     "] = Total $", DoubleToString(tripletSum, 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Triplet!");

               if(CloseMarketOrderDirect(candTickets[i]))
                  isClosed[i] = true;
               if(CloseMarketOrderDirect(candTickets[j]))
                  isClosed[j] = true;
               if(CloseMarketOrderDirect(candTickets[k]))
                  isClosed[k] = true;
               anyOrdersClosed = true;
              }
           }
        }
     }

// 7. SINGLE ORDER CHECK (Any individual order with profit >= minProfitUSD)
   for(int i = 0; i < candCount; i++)
     {
      if(isClosed[i])
         continue;

      if(candProfits[i] >= minProfitUSD)
        {
         Print(">>> [COMBINATION CLOSE - SINGLE ORDER] Ticket #", candTickets[i],
               " (", (candTypes[i] == OP_BUY ? "BUY" : "SELL"), " ", DoubleToString(candLots[i], 2),
               " lots) Profit = $", DoubleToString(candProfits[i], 2), " >= $", DoubleToString(minProfitUSD, 2), " | Closing Order!");

         if(CloseMarketOrderDirect(candTickets[i]))
            isClosed[i] = true;
         anyOrdersClosed = true;
        }
     }

   if(anyOrdersClosed)
      InvalidateTotalEAOrdersCache();
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SecureDistanceProfitLadder()
  {
// The raw price gap increment (e.g., 50.0 represents a $50 price movement in BTC)
   double distanceStep = 104;//50.0*3;

   if(distanceStep <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      RefreshRates();

      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();

      // 1. Calculate safe StopLevel (Fallback to 2x Spread for Crypto brokers with bugged limits)
      double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      double spreadBuf = (Ask - Bid) * 2.0;
      double minSafeDistance = MathMax(stopLevel, spreadBuf);

      double maxLockableDistance = 0.0;

      // 2. Calculate the maximum raw distance we can safely lock right now
      if(type == OP_BUY)
         maxLockableDistance = (Bid - minSafeDistance) - openPrice;
      else
         if(type == OP_SELL)
            maxLockableDistance = openPrice - (Ask + minSafeDistance);

      // If we aren't even in profit, skip
      if(maxLockableDistance <= 0)
         continue;

      // 3. Determine the ladder level (1 = $50, 2 = $100, 3 = $150, etc.)
      int ladderLevel = (int)MathFloor(maxLockableDistance / distanceStep);

      // If price hasn't moved far enough to even lock the first step, skip
      if(ladderLevel < 1)
         continue;

      // 4. Calculate the exact price for this distance ladder rung
      double lockedDistance = ladderLevel * distanceStep;
      double newSL = 0.0;
      bool canModify = false;

      if(type == OP_BUY)
        {
         newSL = NormalizeDouble(openPrice + lockedDistance, Digits);

         // FINAL BROKER CHECK: Ensure live price hasn't suddenly dropped too close to our new SL
         if(Bid - newSL >= minSafeDistance)
           {
            // Ensure we only move the SL forward
            if(currentSL == 0.0 || newSL > currentSL + (Point / 2.0))
               canModify = true;
           }
        }
      else
         if(type == OP_SELL)
           {
            newSL = NormalizeDouble(openPrice - lockedDistance, Digits);

            // FINAL BROKER CHECK: Ensure live price hasn't suddenly spiked too close to our new SL
            if(newSL - Ask >= minSafeDistance)
              {
               // Ensure we only move the SL forward
               if(currentSL == 0.0 || newSL < currentSL - (Point / 2.0))
                  canModify = true;
              }
           }

      // 5. Modify the order with enhanced diagnostic logging
      if(canModify)
        {
         ResetLastError();
         bool modified =SafeOrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrDodgerBlue);

         if(modified)
           {
            Print("Secured Distance Ladder: ", ladderLevel, "X (+$", DoubleToString(lockedDistance, 2), " price gap)",
                  " | Ticket=", OrderTicket(),
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | New SL=", DoubleToString(newSL, Digits));
           }
         else
           {
            // If it still fails, this print will tell you exactly why
            Print("FAILED MODIFY DISTANCE SL | Ticket=", OrderTicket(),
                  " | Error=", GetLastError(),
                  " | Ask=", DoubleToString(Ask, Digits),
                  " | Bid=", DoubleToString(Bid, Digits),
                  " | Curr SL=", DoubleToString(currentSL, Digits),
                  " | Attempted SL=", DoubleToString(newSL, Digits),
                  " | Min Broker Distance=", DoubleToString(minSafeDistance, Digits));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void SecureOneDollarProfit()
  {
   if(GetTotalEAOrders() <= 0)
      return;

// The base 1X target amount in your account currency
   double baseProfitTarget = SecureOneDollarProfitPerOrder * balancelomultipler;

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
     {
      baseProfitTarget = baseProfitTarget / 2;
     }

   if(baseProfitTarget <= 0)
      return; // Prevent division by zero if inputs are 0

   double stopLevel = GetRequiredStopDistance();
   if(stopLevel < 10.0)
      stopLevel = 10.0;





   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      if(OrderLots() == 0)
         continue;

      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      double currentSL = OrderStopLoss();
      double openPrice = OrderOpenPrice();
      double expenses  = OrderSwap() + OrderCommission();

      double maxLockableGross = 0.0;

      // 1. Calculate the maximum gross profit we could technically lock right now
      if(type == OP_BUY)
        {
         double maxSL = Bid - stopLevel;
         maxLockableGross = (maxSL - openPrice) / 100.0;
        }
      else
         if(type == OP_SELL)
           {
            double maxSL = Ask + stopLevel;
            maxLockableGross = (openPrice - maxSL) / 100.0;
           }

      // 2. Convert maximum lockable gross into net profit
      double maxLockableNet = maxLockableGross + expenses;

      // 3. Determine the ladder level strictly in 1X increments (X1, X2, X3...)
      double rawMultiplier = maxLockableNet / baseProfitTarget;
      double ladderLevel = MathFloor(rawMultiplier);

      // If price hasn't moved far enough to even lock 1.0X, skip this order
      if(ladderLevel < 1.0)
         continue;

      // 4. Calculate the precise SL price for this specific integer ladder level
      double targetNetProfit = ladderLevel * baseProfitTarget;
      double requiredGrossProfit = targetNetProfit - expenses;
      double priceDistance = requiredGrossProfit * 100.0;

      double newSL = 0.0;
      bool canModify = false;

      if(type == OP_BUY)
        {
         newSL = NormalizeDouble(openPrice + priceDistance, Digits);
         // Ensure we only move the SL forward
         if(currentSL == 0.0 || newSL > currentSL + (Point / 2.0))
            canModify = true;
        }
      else
         if(type == OP_SELL)
           {
            newSL = NormalizeDouble(openPrice - priceDistance, Digits);
            // Ensure we only move the SL forward
            if(currentSL == 0.0 || newSL < currentSL - (Point / 2.0))
               canModify = true;
           }

      // 5. Modify the order if the new ladder rung is reached
      if(canModify)
        {
         ResetLastError();
         bool modified =SafeOrderModify(OrderTicket(), openPrice, newSL, OrderTakeProfit(), 0, clrGreen);

         if(modified)
           {
            Print("Secured Ladder Profit: X", DoubleToString(ladderLevel, 0), " ($", DoubleToString(targetNetProfit, 2), ")",
                  " | Ticket=", OrderTicket(),
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | New SL=", DoubleToString(newSL, Digits));
           }
         else
           {
            Print("FAILED to secure X", DoubleToString(ladderLevel, 0), " SL",
                  " | Ticket=", OrderTicket(),
                  " | Error=", GetLastError());
           }
        }
     }
  }
//2026.09.22 09:42:18.950   2026.08.02 09:29:21  SSLCHANEL-1 BTCUSDm,M1: 5% EQUITY LADDER TARGET ADJUSTED | Baseline=$124.88 | CurrentEquity=$103.89 | OldTarget=$131.12 | Difference=$27.23 | NewTarget=$108.89
double gbltargetEquity=0;
int gbltargetEquityCounter=0;

//+------------------------------------------------------------------+
//| DrawTargetEquityHitCircle: Draws green circle icon on chart      |
//| when target equity (gbltargetEquity) is hit.                     |
//+------------------------------------------------------------------+
void DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step)
  {
   static datetime lastHitTime = 0;
   static double   lastHitTarget = 0.0;
   // Prevent duplicate drawing on same bar for identical target value
   if(time == lastHitTime && MathAbs(targetVal - lastHitTarget) < 0.01)
      return;

   string objName = PREFIX + "TARGET_EQ_HIT_" + IntegerToString((int)time) + "_" + IntegerToString((int)targetVal);

   if(ObjectFind(0, objName) < 0)
     {
      // 1. Solid Green Circle Icon (Wingdings 159, Max Width 5)
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159); // Wingdings 159: Solid circle / dot
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime); // Vibrant green color
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 5);       // Thick, highly visible
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, StringFormat("Target Equity Hit: $%.2f | Step %d | Time: %s", targetVal, step, TimeToString(TimeCurrent(), TIME_SECONDS)));

      // 2. Descriptive Label Underneath Circle
      string lblName = objName + "_LBL";
      if(ObjectFind(0, lblName) < 0)
        {
         double lblPrice = price - MathMax(30 * Point, 15.0);
         ObjectCreate(0, lblName, OBJ_TEXT, 0, time, lblPrice);
         ObjectSetString(0, lblName, OBJPROP_TEXT, StringFormat("EQ Hit #%d ($%.2f)", step, targetVal));
         ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
         ObjectSetInteger(0, lblName, OBJPROP_COLOR, clrLime);
         ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
         ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, false);
        }

      ChartRedraw(0);
      lastHitTime = time;
      lastHitTarget = targetVal;
     }
  }

//+------------------------------------------------------------------+
//| Manage 5% / Step Ladder Target and Baseline                      |
//| Automatically resets target when account balance drops (e.g. SL) |
//| and trails target forward as profits are secured.                |
//+------------------------------------------------------------------+
void Manage5PercentLadderReset()
  {
   double currentBalance = AccountBalance();
   double curEquity      = AccountEquity();

// 1. Initial setup of baseline if uninitialized
   if(Ladder5PercentBaseline <= 0.0)
     {
      Ladder5PercentBaseline = currentBalance;
      gbltargetEquityCounter = 0;
     }

// 2. If no open market orders, keep baseline synchronized with current balance
   int marketOrders = GetTotalBuyOrders() + GetTotalSellOrders();
   if(marketOrders == 0)
     {
      Ladder5PercentBaseline = currentBalance;
      gbltargetEquityCounter = 0;
     }
// 3. Balance fall-down check: If an order hit negative loss SL and balance dropped below baseline
   else
      if(Ladder5PercentBaseline - currentBalance >= 0.01)
        {
         Print(
            "5% EQUITY LADDER RESET (BALANCE DROP) | OldBaseline=$", DoubleToString(Ladder5PercentBaseline, 2),
            " | NewBalance=$", DoubleToString(currentBalance, 2),
            " | DroppedBy=$", DoubleToString(Ladder5PercentBaseline - currentBalance, 2),
            " | Resetting baseline and target."
         );
         Ladder5PercentBaseline = currentBalance;
         gbltargetEquityCounter = 0;
        }
      // 4. Balance increase check: If orders closed in profit and balance increased above baseline
      else
         if(currentBalance - Ladder5PercentBaseline >= 0.01)
           {
            Print(
               "5% EQUITY LADDER BASELINE ADVANCED (PROFIT BANKED) | OldBaseline=$", DoubleToString(Ladder5PercentBaseline, 2),
               " | NewBalance=$", DoubleToString(currentBalance, 2),
               " | Gained=$", DoubleToString(currentBalance - Ladder5PercentBaseline, 2)
            );
            Ladder5PercentBaseline = currentBalance;
            gbltargetEquityCounter = 0;
           }

// 5. Calculate step amount based on multiplier
   double stepVal = (CloseOrdersAtProfitFromOpeningBalanceEveryStep > 0.0) ? CloseOrdersAtProfitFromOpeningBalanceEveryStep : 2.0;
   double stepAmount = stepVal * (balancelomultipler > 0 ? balancelomultipler : 1);

// 6. Calculate target equity based on baseline + current ladder step
   double targetEquity = Ladder5PercentBaseline + (stepAmount * (gbltargetEquityCounter + 1));
   gbltargetEquity = targetEquity;

// 7. Check if target equity reached
   if(curEquity >= targetEquity)
     {
      Print(
         "5% EQUITY LADDER TARGET REACHED (Step ", (gbltargetEquityCounter + 1), ")",
         " | Equity=$", DoubleToString(curEquity, 2),
         " | Target=$", DoubleToString(targetEquity, 2),
         " | Baseline=$", DoubleToString(Ladder5PercentBaseline, 2),
         " | Securing open orders profit."
      );

      // Display circle green color icon on chart
      double iconOffset = MathMax(50 * Point, 25.0);
      DrawTargetEquityHitCircle(Time[0], Low[0] - iconOffset, targetEquity, gbltargetEquityCounter + 1);

      // Modify open orders to secure profit
      ModifyOpenOrdersToSecureProfit();

      // Advance to next ladder step
      gbltargetEquityCounter++;
      gbltargetEquity = Ladder5PercentBaseline + (stepAmount * (gbltargetEquityCounter + 1));

      InitializeDayProfitLadder();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void Manage5PercentLadderResetOld()
  {
   if(Ladder5PercentBaseline <= 0.0)
     {
      Ladder5PercentBaseline = AccountBalance();
      return;
     }

   double targetEquity = Ladder5PercentBaseline * (1.0 + (CloseOrdersAtProfitFromOpeningBalanceEveryStep*balancelomultipler / 100.0));

   if(AccountEquity() >= targetEquity)
     {
      Print("5% Equity Ladder Target Reached. Closing all orders and resetting.");
      // for(int i = OrdersTotal() - 1; i >= 0; i--)
      //   {
      //    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
      //      {
      //       if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
      //         {
      //          int type = OrderType();
      //          if(type == OP_BUY || type == OP_SELL)
      //             SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
      //          else
      //             if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
      //                SafeOrderDelete(OrderTicket(), clrRed);
      //         }
      //      }
      //   }
      ModifyOpenOrdersToSecureProfit();


      Ladder5PercentBaseline = AccountBalance();

      InitializeDayProfitLadder();
      // DayProfitLadderTradingStopped = false;
      // OrderCreatedThisCandle = false;
      // LastOrderCandleTime = 0;
      // TradeResetThisTick = true;

      // int currentSignal = GlobalSSLDirection;
      // if(currentSignal == 1)
      //    OpenBuy();
      // else
      //    if(currentSignal == -1)
      //       OpenSell();
     }
  }
int MomDirection=0;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetSSLSignal()
  {
   if(Bars < SSLPeriod + 5)
      return 0;

   double atrValue = iATR(Symbol(), 0, SSLPeriod, 1);
   double smaHigh  = iMA(Symbol(), 0, SSLPeriod, 0, MODE_SMA, PRICE_HIGH, 1);
   double smaLow   = iMA(Symbol(), 0, SSLPeriod, 0, MODE_SMA, PRICE_LOW, 1);

   double upper = smaHigh + atrValue;
   double lower = smaLow - atrValue;

   double currentClose  = Close[1];
   double previousClose = Close[2];
   double currentOpen   = Open[1];

   if(MathAbs(currentClose - currentOpen) < (atrValue * 0.25))
      return 0;

   double adxMain = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, 1);
   if(adxMain < 20.0)
      return 0;

   if(previousClose <= upper && currentClose > upper)
     {
      if(InpUseEMA200Filter)
        {
         double emaFilter = iMA(Symbol(), 0, InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 1);
         if(currentClose > emaFilter)
            return 1;
        }
      else
         return 1;
     }
   if(previousClose >= lower && currentClose < lower)
     {
      if(InpUseEMA200Filter)
        {
         double emaFilter = iMA(Symbol(), 0, InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 1);
         if(currentClose < emaFilter)
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
   double calculatedLots = (AccountEquity() / 100000.0) * Lots * AccountMultiplierLOT;
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
      if(StringFind(name,"EMA_UPPER_",0)==0)
         ObjectDelete(0,name);
      if(StringFind(name,"EMA_LOWER_",0)==0)
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
         if(ObjectCreate(0,name,OBJ_TREND,0,Time[j],ema2,Time[i],ema1))
           {
            ObjectSetInteger(0,name,OBJPROP_COLOR,EMALineColor);
            ObjectSetInteger(0,name,OBJPROP_WIDTH,EMALineWidth);
            ObjectSetInteger(0,name,OBJPROP_STYLE,STYLE_SOLID);
            ObjectSetInteger(0,name,OBJPROP_RAY_RIGHT,false);
            ObjectSetInteger(0,name,OBJPROP_BACK,false);
            ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
            ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
           }
        }
      lastDrawnBar=Time[0];
     }

   double ema0=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,0);
   double ema1_live=iMA(Symbol(),Period(),InpEMA200Period,0,MODE_EMA,PRICE_CLOSE,1);

   if(ema0>0 && ema1_live>0)
     {
      string liveName=EMA_PREFIX+"0";
      if(ObjectFind(0,liveName)>=0)
        {
         ObjectMove(0,liveName,0,Time[1],ema1_live);
         ObjectMove(0,liveName,1,Time[0],ema0);
        }
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
   int currentDirection = GlobalSSLDirection;
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

//+------------------------------------------------------------------+
//| Close Buy orders below 50 EMA and Sell orders above 50 EMA (>$50)|
//+------------------------------------------------------------------+
void Manage50EmaClosures()
  {
// 1. Calculate the current 50 EMA value
   double ema50 = iMA(Symbol(), Period(), 50, 0, MODE_EMA, PRICE_CLOSE, 0);
   if(ema50 <= 0)
      return;

   RefreshRates();

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickSize <= 0.0 || tickValue <= 0.0)
      return;

// 2. Loop through all open orders backwards
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         // 3. Match your EA's Symbol and Magic Number
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            int type = OrderType();
            double lots = OrderLots();
            double priceGap = 0.0;

            // =====================================================================
            // EXIT BUYS: Calculate how far the Bid price is BELOW the 50 EMA
            // =====================================================================
            if(type == OP_BUY && Bid < ema50)
              {
               priceGap = ema50 - Bid; // Positive value means price is below EMA
               double distanceUSD = (priceGap / tickSize) * tickValue * lots;

               if(distanceUSD >= 50.0)
                 {
                  Print("CLOSING BUY: Price is below 50 EMA by $", DoubleToString(distanceUSD, 2));
                  SafeOrderClose(OrderTicket(), lots, type, Slippage, clrRed);
                 }
              }

            // =====================================================================
            // EXIT SELLS: Calculate how far the Ask price is ABOVE the 50 EMA
            // =====================================================================
            else
               if(type == OP_SELL && Ask > ema50)
                 {
                  priceGap = Ask - ema50; // Positive value means price is above EMA
                  double distanceUSD = (priceGap / tickSize) * tickValue * lots;

                  if(distanceUSD >= 50.0)
                    {
                     Print("CLOSING SELL: Price is above 50 EMA by $", DoubleToString(distanceUSD, 2));
                     SafeOrderClose(OrderTicket(), lots, type, Slippage, clrBlue);
                    }
                 }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Count closed market orders since the last EMA flip               |
//+------------------------------------------------------------------+
int GetClosedOrdersCountSinceEmaFlip()
  {
// Return 0 if the EMA hasn't flipped yet during this session
   if(EmaFlipTime == 0)
      return 0;

   static int      s_lastHistCountClose = -1;
   static datetime s_lastFlipTimeClose  = 0;
   static int      s_cachedClosedCount  = 0;

   int currentHistTotal = OrdersHistoryTotal();
   if(currentHistTotal == s_lastHistCountClose && EmaFlipTime == s_lastFlipTimeClose)
      return s_cachedClosedCount;

   int closedCount = 0;

// Loop through the account history backwards (chronological order)
   for(int i = currentHistTotal - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderCloseTime() < EmaFlipTime)
            break; // Past flip time, stop scanning!

         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            int type = OrderType();
            if(type == OP_BUY || type == OP_SELL)
               closedCount++;
           }
        }
     }

   s_lastHistCountClose = currentHistTotal;
   s_lastFlipTimeClose  = EmaFlipTime;
   s_cachedClosedCount  = closedCount;
   return closedCount;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLadderBox(datetime time, double price, int level)
  {
// Ensure unique name so boxes don't overwrite each other
   string objName = "LADDER_BOX_" + IntegerToString((int)time) + "_LVL_" + IntegerToString(level);

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 110); // Solid square
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);       // Make it thick/visible
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Ladder Step Hit: Level " + IntegerToString(level));
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetProfitAfterLastEmaFlip()
  {
   if(EmaFlipTime == 0)
      return 0.0;

   static int      s_lastHistCount = -1;
   static datetime s_lastFlipTime  = 0;
   static double   s_cachedProfit  = 0.0;

   int currentHistTotal = OrdersHistoryTotal();
   if(currentHistTotal == s_lastHistCount && EmaFlipTime == s_lastFlipTime)
      return s_cachedProfit;

   double realizedProfit = 0.0;

// Sum up all closed orders since the last EMA flip (chronological backwards)
   for(int i = currentHistTotal - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderCloseTime() < EmaFlipTime)
            break; // Past flip time, stop scanning!

         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            realizedProfit += (OrderProfit() + OrderSwap() + OrderCommission());
           }
        }
     }

   s_lastHistCount = currentHistTotal;
   s_lastFlipTime  = EmaFlipTime;
   s_cachedProfit  = realizedProfit;
   return realizedProfit;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckFlipProfitTarget()
  {
   if(TradingHaltedUntilNextFlip || EmaFlipTime == 0)
      return;

// 1. Closed order profit since flip
   double realizedProfit = profitAfterFlip;

// 2. Open floating order profit
   double floatingProfit = GetEAFloatingPL();

// 3. Combined total cycle profit (Closed + Open)
   double totalCycleProfit = realizedProfit + floatingProfit;

// 4. Calculate starting balance before this flip's closed profits
   double startingBalance = AccountBalance() - realizedProfit;
   if(startingBalance <= 0)
      startingBalance = AccountBalance();

// 5. Target profit amount for this cycle
// (If TargetProfitPerFlipUSD represents a dollar target adjusted by your multiplier)
   double targetProfitAmount = TargetProfitPerFlipUSD * balancelomultipler;

// --- ALTERNATIVE: If TargetProfitPerFlipUSD is actually a PERCENTAGE (e.g., 2%):
// double targetProfitAmount = startingBalance * (TargetProfitPerFlipUSD / 100.0);

// 6. Check if combined cycle profit hits or exceeds target
   if(totalCycleProfit >= targetProfitAmount && targetProfitAmount > 0.0)
     {
      Print("FLIP TARGET REACHED: Closed=$", DoubleToString(realizedProfit, 2),
            " | Open=$", DoubleToString(floatingProfit, 2),
            " | Total Cycle=$", DoubleToString(totalCycleProfit, 2),
            " | Target=$", DoubleToString(targetProfitAmount, 2),
            ". Securing profit and halting until next EMA flip.");

      TradingHaltedUntilNextFlip = true;
      ModifyOpenOrdersToSecureProfit();
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckFlipProfitTargetOldprice()
  {
   if(TradingHaltedUntilNextFlip || EmaFlipTime == 0)
      return;

   double realizedProfit = 0.0;

// Sum up all closed orders since the last EMA flip
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(OrderCloseTime() >= EmaFlipTime)
               realizedProfit += (OrderProfit() + OrderSwap() + OrderCommission());
           }
        }
     }

// Add current floating profit to closed profit
   double floatingProfit = GetEAFloatingPL();
   double totalCycleProfit = realizedProfit + floatingProfit;

// If the target is reached, close everything and halt
   if(totalCycleProfit >= TargetProfitPerFlipUSD*balancelomultipler)
     {
      Print("Target reached: $", totalCycleProfit, ". Securing profit and halting until next EMA flip.");
      TradingHaltedUntilNextFlip = true;
      // CloseAndDeleteAllEAOrdersOnTradingStop(); // Reuses your existing function
      ModifyOpenOrdersToSecureProfit();

     }
  }
//+------------------------------------------------------------------+
//| Manage Continuous EMA Flip Profit Ladder                         |
//+------------------------------------------------------------------+
void ManageFlipProfitLadder()
  {
   if(TradingHaltedUntilNextFlip || (FlipLadderStepUSD*balancelomultipler) <= 0)
      return;

// 1. Initialize the baseline if it is empty
   if(ActiveEquityBaseline <= 0.0 || OrdersTotal() == 0)
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

// === DIRECT SAFETY CHECK: HARD BASELINE FLOOR ===
   if(AccountEquity() <= ActiveEquityBaseline && GetDistanceToEMAPrice(OP_BUY, true) > 100)
     {
      Print("EMA SECURED BASELINE BREACHED | Equity ($", AccountEquity(), ") fell to or below baseline ($", ActiveEquityBaseline, ") | Halting trading.");

      DrawLadderHaltCircle(Time[0], High[0] + (50 * Point));
      TradingHaltedUntilNextFlip = true;
      LadderHaltStartTime = TimeCurrent();
      //CloseAndDeleteAllEAOrdersOnTradingStop();
      ///////////CloseAndDeleteNonEmaMatchingOrders();

      ModifyOpenOrdersToSecureProfit();


      return;
     }

// 2. Calculate continuous profit based on actual Account Equity
   double totalContinuousProfit = AccountEquity() - ActiveEquityBaseline;

// 3. Track the highest watermark profit reached
   if(totalContinuousProfit > HighestCycleProfitUSD)
     {
      HighestCycleProfitUSD = totalContinuousProfit;
     }

// 4. Calculate ladder level
//  if(FlipLadderStepUSD==0) FlipLadderStepUSD=1;

   int ladderLevel = (int)MathFloor(HighestCycleProfitUSD / (FlipLadderStepUSD*balancelomultipler));

// 5. Action taken when a new level is reached
   if(ladderLevel > HighestLadderLevelThisCycle && ladderLevel >= 1)
     {
      HighestLadderLevelThisCycle = ladderLevel;
      DrawLadderBox(Time[0], High[0] + (30 * Point), ladderLevel);

      // RATCHET UPWARD: Shift the secured baseline upward with each new level achieved
      // This locks in a higher baseline floor (e.g., 90% of current equity or stepping up by the ladder step)
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

      Print("LEVEL UP: Reached Level ", ladderLevel, " | Secured Baseline Ratcheted to: $", ActiveEquityBaseline);
     }

// 6. Manage locked profit targets for the current tier
   if(ladderLevel >= 1)
     {
      double lockedProfitTarget = (ladderLevel - FlipStepbackLevelCount) * (FlipLadderStepUSD*balancelomultipler);

      if(totalContinuousProfit <= lockedProfitTarget)
        {
         Print("EMA CONTINUOUS LADDER TRIGGERED | Peak was +$", HighestCycleProfitUSD,
               " | Retraced to lock +$", lockedProfitTarget,
               " | Halting trading and updating secured baseline.");

         ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage;

         DrawLadderHaltCircle(Time[0], High[0] + (50 * Point));
         TradingHaltedUntilNextFlip = true;
         LadderHaltStartTime = TimeCurrent();
         //CloseAndDeleteAllEAOrdersOnTradingStop();
         //////////////////CloseAndDeleteNonEmaMatchingOrders();
         //////////// ModifyOpenOrdersToSecureProfit();

        }
     }
  }
//+------------------------------------------------------------------+
//| Check if 1 hour has passed since halt and resume trading         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Check if 1 hour has passed since halt and resume trading         |
//+------------------------------------------------------------------+
// Inside CheckLadderHaltResume():
void CheckLadderHaltResume()
  {
   if(!TradingHaltedUntilNextFlip || LadderHaltStartTime == 0)
      return;

   if(TimeCurrent() >= LadderHaltStartTime + (InpResumeAfterHaltMinutes * EMAFlipwaitingtimeMinutes))
     {
      Print("LADDER RESUME TRIGGERED: Time elapsed since halt. Resuming order creation.");

      TradingHaltedUntilNextFlip = false;
      LadderHaltStartTime = 0;
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage; // Refresh baseline relative to current equity on resume
      HighestCycleProfitUSD = 0.0;
      HighestLadderLevelThisCycle = 0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawLadderHaltCircle(datetime time, double price)
  {
   string objName = "LADDER_HALT_" + IntegerToString((int)time);

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159); // Solid circle/dot
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 5);       // Maximum thickness
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, "Trading Halted: EMA Ladder Locked");
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrackEmaFlip()
  {
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0)
      return;

   int currentDirection = 0;
   if(Close[0] > ema)
      currentDirection = 1;
   else
      if(Close[0] < ema)
         currentDirection = -1;

// Check if the EMA direction has changed
   if(LastTrackedEmaDirection != 0 && currentDirection != 0 && currentDirection != LastTrackedEmaDirection)
     {
      HasEmaFlippedSinceLoad = true;
      EmaFlipTime = TimeCurrent();
      g_emaFlipPrice = (currentDirection == 1 ? Ask : Bid);

      TradingHaltedUntilNextFlip = false;
      LadderHaltStartTime = 0; // Clear timer on flip
      ActiveEquityBaseline = AccountBalance() * SecurebaselinePercentage; // Updated to 10% less than current equity on flip
      HighestCycleProfitUSD = 0.0;
      HighestLadderLevelThisCycle = 0;

      // Reset Sweep state on EMA flip
      g_forceSweepRecalc                  = true;
      g_rememberedSweepSignal             = "None";
      g_rememberedSweepBarTime            = 0;
      g_isSweepSignalConfirmed            = false;
      g_sweepSignalActiveInCurrentEmaFlip = false;
      g_sweepSignalTypeInCurrentEmaFlip   = "None";
      g_sweepSignalDetectedTimeInFlip     = 0;
      ManageSweepGlobalVariables("None");

      // Close previous FLIPBasketSupport orders immediately on flip change
      CloseFLIPBasketSupportOrders();
      CheckAndCloseOrphanFLIPBasketSupportOrders();

      // Reset support order creation flag for this flip cycle
      FLIPBasketSupportOpenedThisCycle = false;
      g_flipBasketSupportCreatedInCycle = 0;
      g_weakStateCountPerEmaFlip = 0;

      // Create FLIP Basket Support order on flip when EMAdistance gap from live price > MinEmaDistance
      int oType = (currentDirection == 1) ? OP_BUY : OP_SELL;
      double emaDist = GetDistanceToEMAPrice(oType, true);
      if(emaDist > FLIPBasketSupportMinEmaDistance)
        {
         int flpTkt = CreateFLIPBasketSupportOrder(currentDirection);
         if(flpTkt > 0)
            FLIPBasketSupportOpenedThisCycle = true;
        }
      else
        {
         Print("FLIPBasketSupport deferred at flip: EMAdistance gap from live price = ", DoubleToString(emaDist, 2),
               " <= ", DoubleToString(FLIPBasketSupportMinEmaDistance, 2), " (Waiting for EMAdistance gap > ", DoubleToString(FLIPBasketSupportMinEmaDistance, 2), ")");
        }


      // CloseOppositeLosingOrdersBeforeSignal(currentDirection); // Close any losing orders from the previous trend

      // HighestCycleProfitUSD = 0.0;        // Add this
      // HighestLadderLevelThisCycle = 0; // <-- NEW: Reset the box trigger
      // Print("EMA FLIP DETECTED: Trend changed. Evaluating open orders for closure.");

      /*
       for(int i = OrdersTotal() - 1; i >= 0; i--)
         {
          if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            {
             // Only process orders matching this EA's Symbol and Magic Number
             if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
               {
                int type = OrderType();
      double distanceUSD = GetDistanceToEmaUSD(type, 0.01);

                // Check Market Orders (Buy/Sell)
                if(type == OP_BUY || type == OP_SELL)
                  {
                   // Calculate total P/L including swap and commission
                   double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

                   // Calculate threshold: -$1 per 0.01 lot step
                   double lossThreshold = -1.0 * (OrderLots() / 0.01);

                   if(orderPL < lossThreshold || orderPL<-1.0)
                     {
                      if(type == OP_BUY && (GlobalEmaAngle30<-1  ))
                         SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrRed);
                      else
                         if(type == OP_SELL && (GlobalEmaAngle30>1  ))
                            SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrBlue);
                     }
                  }

                // Always Delete Pending Orders on Flip
                else
                   if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
                     {
                      SafeOrderDelete(OrderTicket(), clrYellow);
                     }
               }
            }
         }*/
     }

   if(LastTrackedEmaDirection == 0 && currentDirection != 0)
     {
      if(EmaFlipTime == 0)
         EmaFlipTime = GetActualEmaFlipTime(currentDirection);
      if(g_emaFlipPrice <= 0.0)
         g_emaFlipPrice = GetEmaFlipPrice();
     }

// Safety enforcement: If price changes flip direction, ensure any opposite regular FLIPBasketSupport order is closed (exclude LSD)
   if(currentDirection == 1 && HasOpenFLIPBasketSupportOrder(OP_SELL, true))
     {
      CloseFLIPBasketSupportOrders(OP_SELL, false);
     }
   else
      if(currentDirection == -1 && HasOpenFLIPBasketSupportOrder(OP_BUY, true))
        {
         CloseFLIPBasketSupportOrders(OP_BUY, false);
        }

// Check if FLIPBasketSupport order can be created (requires no active support order, EMA distance gap > MinEmaDistance, and not already opened this cycle)
   if(currentDirection != 0 && !FLIPBasketSupportOpenedThisCycle && !HasOpenFLIPBasketSupportOrder(-1))
     {
      int oType = (currentDirection == 1) ? OP_BUY : OP_SELL;
      double emaDist = GetDistanceToEMAPrice(oType, true);
      if(emaDist > FLIPBasketSupportMinEmaDistance)
        {
         int flpTkt = CreateFLIPBasketSupportOrder(currentDirection);
         if(flpTkt > 0)
           {
            FLIPBasketSupportOpenedThisCycle = true;
            Print("FLIPBasketSupport order created on EMAdistance gap > ", DoubleToString(FLIPBasketSupportMinEmaDistance, 2),
                  ": Ticket #", flpTkt, " EmaDistance=", DoubleToString(emaDist, 2), " for Direction=", currentDirection);
           }
        }
     }

   LastTrackedEmaDirection = currentDirection;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDistanceToEMAPrice(int orderType = OP_BUY, bool absoluteValue = true)
  {
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0.0)
      return 0.0;
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   double distance = currentPrice - ema;
   if(absoluteValue)
      return NormalizeDouble(MathAbs(distance), Digits);
   return NormalizeDouble(distance, Digits);
  }

//+------------------------------------------------------------------+
//| Calculate Distance from Live Price to EMA in USD ($)             |
//+------------------------------------------------------------------+
double GetDistanceToEmaUSD(int orderType, double currentLots)
  {
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0.0 || currentLots <= 0.0)
      return 0.0;

   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   double priceDistance = MathAbs(currentPrice - ema); // Raw gap in price

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE); // Value of 1 tick in account currency
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);  // Size of 1 tick (e.g., 0.00001 or 0.01)

   if(tickSize <= 0.0 || tickValue <= 0.0)
      return 0.0;

// Convert price distance to ticks, then calculate USD value based on lot size
   double distanceInTicks = priceDistance / tickSize;
   double distanceInUSD = distanceInTicks * tickValue * currentLots;

   return NormalizeDouble(distanceInUSD, 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersOnEmaDistance()
  {
   if(!EnableEmaDistanceClose || EmaCloseDistancePoints <= 0)
      return;
   if(!HasEmaFlippedSinceLoad)
      return;
   if(GetTotalEAOrders() <= 0)
      return;
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema <= 0)
      return;
   RefreshRates();
   double buyCutoff  = ema - EmaCloseDistancePoints;
   double sellCutoff = ema + EmaCloseDistancePoints;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderOpenTime() > EmaFlipTime)
         continue;

      // ADD THIS EXACT LINE TO PROTECT YOUR RECOVERY BASKETS
      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         continue;

      int type = OrderType();
      if(type == OP_BUY && Bid < buyCutoff && EMADirection == -1)
        {
         Print("EMA DISTANCE TRIGGER: Closing PRE-FLIP BUY.");
         SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrRed);
        }
      if(type == OP_SELL && Ask > sellCutoff && EMADirection == 1)
        {
         Print("EMA DISTANCE TRIGGER: Closing PRE-FLIP SELL.");
         SafeOrderClose(OrderTicket(), OrderLots(), type, Slippage, clrBlue);
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   partialLossMultipler = 5;
   if(AccountBalance() >= 1000)
      partialLossMultipler = 20;
   else
      if(AccountBalance() >= 500)
         partialLossMultipler = 10;
      else
         if(AccountBalance() >= 200)
            partialLossMultipler = 5;




   int lotMultiplierDiv = (AccountMultiplierLOT > 0) ? AccountMultiplierLOT : 500;
   balancelomultipler = (int)(AccountBalance() / lotMultiplierDiv);

   if(balancelomultipler<=0)
      balancelomultipler=1;

   // FlipLadderStepUSD remains base step; scaled dynamically in ladder routines
   SecurebaselinePercentage = (100.0 - (StopLossUSD * 5.0)) / 100.0;//

   EquityResetReEntryPending=false;

   EmaFlipTime = TimeCurrent();

   for(int initIndex = OrdersTotal() - 1; initIndex >= 0; initIndex--)
     {
      if(!OrderSelect(initIndex, SELECT_BY_POS, MODE_TRADES))
         continue;
      int initOrderType = OrderType();
      if(initOrderType == OP_BUYSTOP || initOrderType == OP_SELLSTOP || initOrderType == OP_BUYLIMIT || initOrderType == OP_SELLLIMIT)
         OrderDelete(OrderTicket(), clrNONE);
     }
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(ema > 0)
     {
      if(Close[0] > ema)
         LastTrackedEmaDirection = 1;
      else
         if(Close[0] < ema)
            LastTrackedEmaDirection = -1;
     }
   HasEmaFlippedSinceLoad = false;
// EmaFlipTime = 0;
   EmaFlipTime = TimeCurrent();
   if(g_emaFlipPrice <= 0.0)
      g_emaFlipPrice = GetEmaFlipPrice();

   LastTrackedSSLDirection = GetCurrentSSLDirection();
   if(LastTrackedSSLDirection != 0)
      LiveSSLInitialized = true;

   FLIPBasketSupportOpenedThisCycle = HasOpenFLIPBasketSupportOrder(-1);
   InitializeFLIPBasketSupportTracking();

   DrawHistoricalBouncebacks();

   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   Ladder1StopMaxPriceUSD = Ladder1ProfitUSD*1.2;
   DefaultOrderProfitUSD = Ladder1ProfitUSD*2;
// RecoveryTriggerLossUSD = StopLossUSD/3;

   OriginalLots = Lots;
   OriginalLadder1ProfitUSD = Ladder1ProfitUSD;
   OriginalLadder2ProfitUSD = Ladder2ProfitUSD;
   OriginalLadder1StopMaxPriceUSD = Ladder1StopMaxPriceUSD;
   RecoveryTriggerLossUSD = MathAbs(RecoveryTriggerLossUSD);
   OriginalStopLossUSD = StopLossUSD;

   DeleteOurObjects();
   DeleteDashboardObjects();
   DeleteLeftLiveOrdersDashboardObjects();
   DeleteLiquiditySweepObjects();
   if(ShowHistoricalSignals || ShowSSLLines)
      DrawHistoricalSignals();
   UpdateEMALineOnChart();
   UpdateLiquiditySweepDetectorOnChart();
   DailyProtectionStartTime = TimeCurrent();
   InitializeLastProcessedClosedOrder();
   LastProtectedLossTicket = LastProcessedClosedTicket;
   DayProfitLadderInitialized = false;
   DayProfitLadderTradingStopped = false;
   DayProfitLadderStage = 0;
   DayProfitLadderTargetReachedCandle = 0;
   InitializeDayProfitLadder();
   LoadReEntryCounter();
   EquityResetReEntryPending=false;

   return INIT_SUCCEEDED;
  }

datetime LastOrderCandleTime = 0;
bool OrderCreatedThisCandle = false;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsOneCandleOrderAllowed()
  {


   return true;
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
   DeleteLiquiditySweepObjects();
   ClearSweepGlobalVariables();
  }

int StartupProtectionTicks = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetEAFloatingPL()
  {
   UpdateOrderCacheIfNeeded();
   return g_orderCache.buyPL + g_orderCache.sellPL;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageProfitReEntryMomentumGate() { return; }
void ProcessPendingReEntry(DailyProtectionState &state) { return; }

bool GlobalVShapeBuy = false;
bool GlobalVShapeSell = false;
datetime LastVShapeCheckedTime = 0;
bool HasEmaFlippedSinceLoad = false;
datetime EmaFlipTime = 0;
double   g_emaFlipPrice = 0.0; // Price level where current EMA flip occurred
int LastTrackedEmaDirection = 0;

// ===== LIQUIDITY SWEEP RUNTIME & GLOBAL VARIABLES =====
#define LSD_PREFIX "LSD_SWEEP_"
string   g_lastSweepType                     = "None"; // Last detected sweep ("BSLS", "SSLS", or "None")
double   g_lastEqHighPrice                   = 0.0;    // Active Equal High level
double   g_lastEqLowPrice                    = 0.0;    // Active Equal Low level
datetime g_lastSweepBarTime                  = 0;      // Timestamp of last detected sweep
bool     g_forceSweepRecalc                  = false;  // Immediate recalculation flag on EMA flip

// Remembered Liquidity Sweep Signal State (Persists across candles until EMA flip or signal change)
string   g_rememberedSweepSignal             = "None"; // "BSLS", "SSLS", or "None"
datetime g_rememberedSweepBarTime            = 0;      // Bar time when remembered sweep was triggered
bool     g_isSweepSignalConfirmed            = false;  // True when a sweep signal is active and remembered
bool     g_sweepSignalActiveInCurrentEmaFlip = false;
string   g_sweepSignalTypeInCurrentEmaFlip   = "None";
datetime g_sweepSignalDetectedTimeInFlip     = 0;

// Managed Global Variables (Requested by user)
bool     GlobalSweepBuy                      = false;  // True when SWEEP buy signal is active (SSLS)
bool     GlobalSweepSell                     = false;  // True when SWEEP sell signal is active (BSLS)
string   GlobalSweepSignal                   = "None"; // "SWEEP buy signal", "SWEEP sell signal", or "None"

// --- PENDING BOUNCE VARIABLES ---
datetime PendingVShapeBuyTime = 0;
double   PendingVShapeBuyPrice = 0.0;
datetime PendingVShapeSellTime = 0;
double   PendingVShapeSellPrice = 0.0;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForNewDay()
  {
   int today = TimeDayOfYear(TimeCurrent());

   if(today != g_dayNumber)
     {
      // NEW DAY
      g_dayNumber = today;

      // Capture the balance at the start of the new day
      g_dayOpeningBalance = AccountBalance();

      // Reset daily protection
      g_dailyEquityTradingBlocked = false;

      Print("NEW DAY detected. Opening Balance = ",
            DoubleToString(g_dayOpeningBalance, 2));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDailyEquityStopReached1()
  {
   double stopEquity = g_dayOpeningBalance *
                       (DailyEquityStopUSD / 100.0);


   stopEquity=g_dayOpeningBalance+(DailyEquityStopUSD* balancelomultipler);

   Print("stopEquity "+stopEquity+" AccountEquity() "+AccountEquity());

   if(AccountEquity() <= stopEquity)
     {
      g_dailyEquityTradingBlocked = true;
      return true;
     }

   return g_dailyEquityTradingBlocked;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDailyEquityStopReached()
  {
// Calculates the ceiling equity (e.g., 100 * (1.0 + 0.05) = 105)
   double targetEquity = g_dayOpeningBalance * (1.0 + (DailyEquityStopUSD / 100.0));

   targetEquity=g_dayOpeningBalance+(DailyEquityStopUSD* balancelomultipler);

// Print("targetEquity: ", DoubleToString(targetEquity, 2), " AccountEquity(): ", DoubleToString(AccountEquity(), 2));

// Stop trading if equity hits or exceeds the target
   if(AccountEquity() >= targetEquity)
     {
      g_dailyEquityTradingBlocked = true;

      Print("IsDailyEquityStopReached");

      ModifyOpenOrdersToSecureProfit();

      return true;
     }

   return g_dailyEquityTradingBlocked;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {



   if(AccountEquity()<=0)
      return ;

   CurrentTickSequence++;
   InvalidateOrderCache();

   profitAfterFlip = GetProfitAfterLastEmaFlip();






   int lotMultiplierDiv = (AccountMultiplierLOT > 0) ? AccountMultiplierLOT : 500;

   balancelomultipler = (int)(AccountBalance() / lotMultiplierDiv);
   if(balancelomultipler<=0)
      balancelomultipler=1;


   SecureOneDollarProfit();
   CheckEquitySurplusReset();

   if(InpEnableBasketProfitClose)
      CheckBasketProfitClose();

///CloseProfitableOrderCombinations(); // Close any order combination (or single order) when sum > $1 * multiplier
   CheckAndCloseOrphanFLIPBasketSupportOrders(); // Ensure FLIPBasketSupport is never orphan/single without regular basket orders
   ManageOverallBasketProfit();//modify basket orders at $1 profit
   ManageFLIPBasketSupportTrailingStopLoss(); // Dedicated step-trailing StopLoss on every 100 step move in positive profit

   ManageDayProfitLadder();

   if(enable5PercentClose)
      Manage5PercentLadderReset();

   if(GetTotalSellOrders()>1)
      modifyOnlySellOrders();
   if(GetTotalBuyOrders()>1)
      modifyOnlyBuyOrders();
   CheckAndCloseOrphanFLIPBasketSupportOrders();

   CheckForNewDay();

   IsDailyEquityStopReached();

   UpdateMomentumBackground();
   UpdateDubaiTradingPauseDashboard();
   uint tickStartMs=GetTickCount();

   CheckEquityBalanceProfitTarget();

   CheckDynamicStepLadder();

   MonitorLowestEquityRecovery();
   CloseOppositeOrdersOnEmaDistance();

   UpdateLiquiditySweepDetectorOnChart();
   // ManageLsdSweepLineStopLossProtection(); // DISABLED: LSD Sweep lines only create FlipBasketSupport, DO NOT modify/close orders
   CheckLsdSweepFlipBasketSupportOrder();

   OnTickCore();
   OnTickPerformanceEnd(tickStartMs);



   ModifyPairProfitWithStopLoss();


   if(Time[0] != LastVShapeCheckedTime)
     {
      GlobalVShapeBuy = false;
      GlobalVShapeSell = false;
      LastVShapeCheckedTime = Time[0];

      // 1. Alert, Clear Opposite Orders, and Draw
      if(DetectBounceback(1, 1))
        {
         GlobalVShapeBuy = true;
         DrawBouncebackIcon(Time[1], Low[1] - (50 * Point), 1);
         Print("GLOBAL EVENT: Bullish Bounce Detected! Closing Sells & waiting 5 mins.");

         // for(int i = OrdersTotal() - 1; i >= 0; i--)
         //   {
         //    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         //      {
         //       if(OrderType() == OP_SELL)
         //          SafeOrderClose(OrderTicket(), OrderLots(), OP_SELL, Slippage, clrBlue);
         //       else
         //          if(OrderType() == OP_SELLSTOP || OrderType() == OP_SELLLIMIT)
         //             SafeOrderDelete(OrderTicket(), clrBlue);
         //      }
         //   }

         PendingVShapeBuyTime = TimeCurrent();
         PendingVShapeBuyPrice = Close[1];
        }

      if(DetectBounceback(-1, 1))
        {
         GlobalVShapeSell = true;
         DrawBouncebackIcon(Time[1], High[1] + (50 * Point), -1);
         Print("GLOBAL EVENT: Bearish Bounce Detected! Closing Buys & waiting 5 mins.");

         // for(int i = OrdersTotal() - 1; i >= 0; i--)
         //   {
         //    if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES) && OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
         //      {
         //       if(OrderType() == OP_BUY)
         //          SafeOrderClose(OrderTicket(), OrderLots(), OP_BUY, Slippage, clrRed);
         //       else
         //          if(OrderType() == OP_BUYSTOP || OrderType() == OP_BUYLIMIT)
         //             SafeOrderDelete(OrderTicket(), clrRed);
         //      }
         //   }

         PendingVShapeSellTime = TimeCurrent();
         PendingVShapeSellPrice = Close[1];
        }

      for(int i = 1; i <= 10; i++)
        {
         if(DetectBounceback(1, i))
            GlobalVShapeBuy = true;
         if(DetectBounceback(-1, i))
            GlobalVShapeSell = true;
        }

      ScanAndMarkStructuralPatterns();


     } // <-- End of new candle block
   DrawMomentumMarkers();

// ==========================================================
// 5-MINUTE TIMER CHECKS (RUNS EVERY TICK, OUTSIDE BAR BLOCK)
// ==========================================================
   if(PendingVShapeBuyTime > 0 && TimeCurrent() >= PendingVShapeBuyTime + 300)
     {
      if((Ask - PendingVShapeBuyPrice) / Point > 30)
        {
         GlobalVShapeBuy  = true;
         GlobalVShapeSell = false;
         if(EnableTrading)
            OpenBuy();
         GlobalVShapeBuy  = false;
        }
      else
        {
         Print("Bullish bounce canceled: Price did not increase by 30 points in 5 mins.");
        }
      PendingVShapeBuyTime = 0;
     }

   if(PendingVShapeSellTime > 0 && TimeCurrent() >= PendingVShapeSellTime + 300)
     {
      if((PendingVShapeSellPrice - Bid) / Point > 30)
        {
         GlobalVShapeSell = true;
         GlobalVShapeBuy  = false;
         if(EnableTrading)
            OpenSell();
         GlobalVShapeSell = false;
        }
      else
        {
         Print("Bearish bounce canceled: Price did not drop by 30 points in 5 mins.");
        }
      PendingVShapeSellTime = 0;
     }



  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Close / Delete all pending orders when SSL signal changes        |
//+------------------------------------------------------------------+
int CloseAllPendingOrdersOnSSLChange(int fromDirection, int toDirection)
  {
   int deletedCount = 0;
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Match current chart symbol and EA magic number
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
        {
         int ticket = OrderTicket();
         string typeStr = (type == OP_BUYSTOP ? "BUY STOP" : (type == OP_SELLSTOP ? "SELL STOP" : (type == OP_BUYLIMIT ? "BUY LIMIT" : "SELL LIMIT")));
         double lots = OrderLots();
         double openPrice = OrderOpenPrice();

         ResetLastError();
         if(OrderDelete(ticket, clrYellow))
           {
            deletedCount++;
            Print(">>> [SSL SIGNAL CHANGE] Deleted Pending Order #", ticket,
                  " (", typeStr, " ", DoubleToString(lots, 2), " @ ", DoubleToString(openPrice, Digits), ")");
           }
         else
           {
            Print(">>> [SSL SIGNAL CHANGE] Failed to delete Pending Order #", ticket, " | Error: ", GetLastError());
           }
        }
     }

   if(deletedCount > 0)
     {
      InvalidateTotalEAOrdersCache();
      string fromStr = (fromDirection == 1) ? "BUY (+1)" : (fromDirection == -1 ? "SELL (-1)" : "NONE (0)");
      string toStr   = (toDirection == 1) ? "BUY (+1)" : (toDirection == -1 ? "SELL (-1)" : "NONE (0)");
      Print(">>> [SSL SIGNAL CHANGE] Total Pending Orders Deleted: ", deletedCount, " (SSL changed from ", fromStr, " to ", toStr, ")");
     }

   return deletedCount;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ForceDeleteAllPendingOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int type = OrderType();
      if(type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT)
        {
         ResetLastError();
         if(!OrderDelete(OrderTicket(), clrYellow))
            Print("Force delete failed for ticket: ", OrderTicket(), " Error: ", GetLastError());
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckMomentumExhaustionExits()
  {
   double adxMain = iADX(Symbol(), PERIOD_M1, 14, PRICE_CLOSE, MODE_MAIN, 0);
   double adxPrev = iADX(Symbol(), PERIOD_M1, 14, PRICE_CLOSE, MODE_MAIN, 1);
   if(adxPrev > 35.0 && adxMain < 35.0)
     {
      for(int i=OrdersTotal()-1; i>=0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
           {
            if(OrderSymbol()==Symbol() && OrderMagicNumber()==MagicNumber && (OrderProfit() + OrderSwap() + OrderCommission()) > 0)
               SafeOrderClose(OrderTicket(), OrderLots(), OrderType(), Slippage, clrYellow);
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Manage Overall Basket Profit (Requires Both Buy and Sell Orders) |
//+------------------------------------------------------------------+
void ManageOverallBasketProfit()
  {
   UpdateOrderCacheIfNeeded();
   if(g_orderCache.buyOrders <= 0 || g_orderCache.sellOrders <= 0)
      return;

   double totalLots = g_orderCache.buyLots + g_orderCache.sellLots;
   double totalBasketProfit = g_orderCache.buyPL + g_orderCache.sellPL;

// Dynamic profit target: Total Lots * 0.50 * 100 (Total Lots * 50.0)
   double dynamicProfitTarget = totalLots*100 * (modifyBasketProfitOrdersLotXPercent/10);

   if(totalBasketProfit > dynamicProfitTarget)
     {
      Print("HEDGED BASKET PROFIT TARGET HIT ($", DoubleToString(totalBasketProfit, 2),
            " > Target: $", DoubleToString(dynamicProfitTarget, 2),
            " for ", DoubleToString(totalLots, 2), " total lots). Closing all orders and continuing trading.");

      // CloseAndDeleteAllEAOrdersOnTradingStop();
      ModifyOpenOrdersToSecureProfit();


      TradingHaltedUntilNextFlip = false;
      LadderHaltStartTime = 0;
     }
  }
//+------------------------------------------------------------------+
//| Check Stored Signals and Execute on EMA Trend Flip               |
//+------------------------------------------------------------------+
void CheckStoredSignals(DailyProtectionState &dailyState)
  {
   if(!EnableTrading || IsDailyTradingStopped(dailyState))
      return;

   int maxMemorySeconds = 7200; // 2 hours expiration window

   if(StoredSellSignalActive)
     {
      if(TimeCurrent() - StoredSellSignalTime > maxMemorySeconds)
        {
         StoredSellSignalActive = false;
         Print("STORED SELL SIGNAL EXPIRED: 2 hours elapsed without EMA flip.");
        }
      else
         if(PassesEMAFilter(OP_SELL))
           {
            Print("EMA FLIPPED TO SELL MODE: Executing stored SSL Sell signal.");
            StoredSignalOverride = true;
            if(GetTotalEAOrders() < MaxOpenOrders)
               OpenSell();
            StoredSignalOverride = false;
            StoredSellSignalActive = false;
           }
     }

   if(StoredBuySignalActive)
     {
      if(TimeCurrent() - StoredBuySignalTime > maxMemorySeconds)
        {
         StoredBuySignalActive = false;
         Print("STORED BUY SIGNAL EXPIRED: 2 hours elapsed without EMA flip.");
        }
      else
         if(PassesEMAFilter(OP_BUY))
           {
            Print("EMA FLIPPED TO BUY MODE: Executing stored SSL Buy signal.");
            StoredSignalOverride = true;
            if(GetTotalEAOrders() < MaxOpenOrders)
               OpenBuy();
            StoredSignalOverride = false;
            StoredBuySignalActive = false;
           }
     }
  }
//+------------------------------------------------------------------+
//| Close opposite orders created before signal change with loss > $2 |
//+------------------------------------------------------------------+
void CloseOppositeLosingOrdersBeforeSignal(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// Loop through all open trades
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // 1. Check if the open order is directly opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      // 2. Check if the order was created before the last EMA flip / signal change
      bool isBeforeSignalChange = (EmaFlipTime > 0 && OrderOpenTime() < EmaFlipTime);

      // 3. Calculate loss threshold: $2.00 per 0.01 lot step (scaled by lot size)
      double lossThreshold = -2.0 * (lots / 0.01);
      bool isLossExceeded = (orderPL <= lossThreshold);

      // If all conditions match, close the losing opposite order immediately
      if(isOppositeSignal && isBeforeSignalChange && isLossExceeded)
        {
         Print("OPPOSITE LOSING ORDER CLOSED: Ticket #", ticket,
               " | Type: ", GetOrderTypeText(orderType),
               " | Loss: $", DoubleToString(orderPL, 2),
               " | Threshold: $", DoubleToString(lossThreshold, 2));

         SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));
        }
     }
  }
//+------------------------------------------------------------------+
//| Standalone: Close profitable opposite orders on SSL signal       |
//+------------------------------------------------------------------+
void CloseOppositeProfitableOrdersIndependent(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// Loop through all open trades
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int orderType = OrderType();
      int ticket = OrderTicket();
      double lots = OrderLots();
      double orderPL = OrderProfit() + OrderSwap() + OrderCommission();

      // Calculate profit threshold: $0.25 per 0.01 lot step
      double profitThreshold = 0.25 * (lots / 0.01);

      // Check if the open order is directly opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      // If it's an opposite signal and has reached or exceeded the profit threshold, close it immediately
      if(isOppositeSignal && orderPL >= profitThreshold)
        {
         Print("INDEPENDENT CLOSE TRIGGERED: Ticket #", ticket,
               " | Type: ", GetOrderTypeText(orderType),
               " | Profit: $", DoubleToString(orderPL, 2),
               " | Threshold: $", DoubleToString(profitThreshold, 2));

         // SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));

         double targetSL = Bid - (15 * Point); // Example for a Buy order
         ModifyOrderStopLossByTicket(ticket, targetSL);
        }
     }
  }

//+------------------------------------------------------------------+
//| Modify an open order's Stop Loss by Ticket                      |
//+------------------------------------------------------------------+
bool ModifyOrderStopLossByTicket(int ticket, double newStopLoss)
  {
// Select the order by ticket
   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      Print("Failed to select order #", ticket, " for modification. Error: ", GetLastError());
      return false;
     }

// Ensure the order is still open and belongs to the current chart symbol
   if(OrderCloseTime() != 0)
     {
      Print("Order #", ticket, " is already closed. Cannot modify.");
      return false;
     }

   if(OrderSymbol() != Symbol())
     {
      Print("Order #", ticket, " symbol (", OrderSymbol(), ") does not match chart symbol (", Symbol(), ").");
      return false;
     }

   int    type      = OrderType();
   double openPrice = OrderOpenPrice();
   double currentTP = OrderTakeProfit();
   double currentSL = OrderStopLoss();

// Only modify if the stop loss is actually different
   if(NormalizeDouble(currentSL, Digits) == NormalizeDouble(newStopLoss, Digits))
     {
      return true; // Already set to this SL
     }

// Send the modification request
   bool modified =SafeOrderModify(ticket, openPrice, newStopLoss, currentTP, 0, clrYellow);

   if(!modified)
     {
      Print("Failed to modify Stop Loss for order #", ticket, ". Error: ", GetLastError());
      return false;
     }

   Print("Successfully updated Stop Loss for order #", ticket, " to ", DoubleToString(newStopLoss, Digits));
   return true;
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
   CheckLadderHaltResume(); // <-- ADD THIS LINE HERE

   TrackEmaFlip();
   CheckFlipProfitTarget(); // Add this line


//////////ManageFlipProfitLadder(); // Add this line// LEVEL 1 Step$5 profit ladder is not required - wrong calculation and closeing orders immidiatly/partial close orders having problem becauseo f this
// Manage50EmaClosures();
// ManageEmaAngleOppositeClose(); // <-- Add this here
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

// --- UPDATE GLOBAL TICK VARIABLES ---
   GlobalEmaAngle30 = GetEmaAngleDegrees(30);
   GlobalEmaAngle200 = GetEmaAngleDegrees(200);

   int currentSSLDirection = GetCurrentSSLDirection();
   if(LiveSSLInitialized && LastTrackedSSLDirection != 0 && currentSSLDirection != 0 && currentSSLDirection != LastTrackedSSLDirection)
     {
      if(DeletePendingOrdersOnSSLChange)
        {
         CloseAllPendingOrdersOnSSLChange(LastTrackedSSLDirection, currentSSLDirection);
        }
      LastTrackedSSLDirection = currentSSLDirection;
     }
   else
      if(!LiveSSLInitialized && currentSSLDirection != 0)
        {
         LiveSSLInitialized = true;
         LastTrackedSSLDirection = currentSSLDirection;
        }

   GlobalSSLDirection = currentSSLDirection;
   Global30MinDiffBuy = Get30MinDifference(OP_BUY);
   Global30MinDiffSell = Get30MinDifference(OP_SELL);

   Get5MinDifferenceBuy1 = Get5MinDifference(OP_BUY);
   Get5MinDifferenceSell1 = Get5MinDifference(OP_SELL);




   UpdateOrderCacheIfNeeded();

   TradeResetThisTick = false;

   if(StartupProtectionTicks < 1)
     {
      StartupProtectionTicks++;
      EAStartupComplete = true;
     }

   static DailyProtectionState dailyState;
   if(!dailyState.Initialized)
      InitializeDailyProtectionState(dailyState);


// ADD THIS LINE HERE:

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
// CheckMissedSignalMemory(dailyState); // <-- Add this here
   CheckStoredSignals(dailyState); // <-- Add this here

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

// CloseOppositeProfitableOrdersIndependent(OP_BUY);

// CloseOppositeProfitableOrdersIndependent(OP_SELL);


   if(Bars < SSLPeriod + 20)
      return;

   bool buySignal  = IsLiveBuySignal();
   bool sellSignal = IsLiveSellSignal();

   int currentTrend = GlobalSSLDirection;
   bool missingBuyOrder = (currentTrend == 1 && CountDirectionOrders(OP_BUY) == 0 && CountDirectionOrders(OP_BUYSTOP) == 0);
   bool missingSellOrder = (currentTrend == -1 && CountDirectionOrders(OP_SELL) == 0 && CountDirectionOrders(OP_SELLSTOP) == 0);

   if(buySignal || missingBuyOrder)
     {
      if(buySignal)
         DrawLiveSignal(0, true);
      if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != 1 || missingBuyOrder)
        {
         LastLiveSignalCandle = Time[0];
         LastLiveSSLDirection = 1;

         if(EnableTrading && !IsDailyTradingStopped(dailyState))
           {
            // if(CloseOppositeOrdersOnSignal)
            // CloseOppositeProfitableOrdersOnSignal(OP_BUY);

            // CloseOppositeProfitableOrdersIndependent(OP_BUY);
            // CloseOppositeOrders(OP_BUY);

            if(GetTotalEAOrders() < MaxOpenOrders)
              {
               if(PassesEMAFilter(OP_BUY))
                 {
                  OpenBuy();
                 }
               else
                 {
                  StoredBuySignalActive = true;
                  StoredBuySignalTime = TimeCurrent();
                  StoredSellSignalActive = false;
                  Print("SSL BUY SIGNAL STORED: Blocked by EMA. Waiting for EMA to turn bullish.");
                 }
              }
           }
        }
     }
   else
      if(sellSignal || missingSellOrder)
        {
         if(sellSignal)
            DrawLiveSignal(0, false);
         if(LastLiveSignalCandle != Time[0] || LastLiveSSLDirection != -1 || missingSellOrder)
           {
            LastLiveSignalCandle = Time[0];
            LastLiveSSLDirection = -1;

            if(EnableTrading && !IsDailyTradingStopped(dailyState))
              {
               // if(CloseOppositeOrdersOnSignal)
               // CloseOppositeProfitableOrdersOnSignal(OP_SELL);
               // CloseOppositeOrders(OP_SELL);

               // CloseOppositeProfitableOrdersIndependent(OP_SELL);

               if(GetTotalEAOrders() < MaxOpenOrders)
                 {
                  if(PassesEMAFilter(OP_SELL))
                    {
                     OpenSell();
                    }
                  else
                    {
                     StoredSellSignalActive = true;
                     StoredSellSignalTime = TimeCurrent();
                     StoredBuySignalActive = false;
                     Print("SSL SELL SIGNAL STORED: Blocked by EMA. Waiting for EMA to turn bearish.");
                    }
                 }
              }
           }
        }

   if(Bars >= SSLPeriod + 20 && !TradeResetThisTick)
      CheckForProfitableClosedOrder(dailyState);
  }
//+------------------------------------------------------------------+
//| Evaluate Stored Missed Signals for Market Follow-Through         |
//+------------------------------------------------------------------+
void CheckMissedSignalMemory(DailyProtectionState &dailyState)
  {
   if(MissedSignalType == 0)
      return;

// EXPIRATION: Clear memory if 15 minutes (900 seconds) have passed without confirmation
   if(TimeCurrent() - MissedSignalTime > 15 * 60)
     {
      Print("MISSED SIGNAL EXPIRED: 15 minutes elapsed without market confirmation.");
      MissedSignalType = 0;
      MissedSignalPrice = 0.0;
      MissedSignalTime = 0;
      return;
     }

   RefreshRates();

// Check for Buy confirmation (Price moves UP from stored reference price by at least 10 points)
   if(MissedSignalType == 1)
     {
      if((Ask - MissedSignalPrice) / Point >= 10.0)
        {
         Print("MISSED BUY CONFIRMED: Market moved up in stored direction. Executing order.");
         MissedSignalOverride = true;
         if(EnableTrading && !IsDailyTradingStopped(dailyState))
            OpenBuy();
         MissedSignalOverride = false;

         // Reset memory
         MissedSignalType = 0;
        }
     }
// Check for Sell confirmation (Price moves DOWN from stored reference price by at least 10 points)
   else
      if(MissedSignalType == -1)
        {
         if((MissedSignalPrice - Bid) / Point >= 10.0)
           {
            Print("MISSED SELL CONFIRMED: Market moved down in stored direction. Executing order.");
            MissedSignalOverride = true;
            if(EnableTrading && !IsDailyTradingStopped(dailyState))
               OpenSell();
            MissedSignalOverride = false;

            // Reset memory
            MissedSignalType = 0;
           }
        }
  }
datetime EmaAngleExtremeStartTime = 0;

//+------------------------------------------------------------------+
//| Close Opposite Orders on Extreme EMA Angle (> 5Â° for 30 Mins)    |
//+------------------------------------------------------------------+
void ManageEmaAngleOppositeClose()
  {
   double emaAngle = GlobalEmaAngle30;

// Check if angle magnitude exceeds 5.0 degrees continuously
   if(MathAbs(emaAngle) > 5.0)
     {
      if(EmaAngleExtremeStartTime == 0)
        {
         EmaAngleExtremeStartTime = TimeCurrent(); // Start tracking duration when threshold is first crossed
        }
      else
         if(TimeCurrent() - EmaAngleExtremeStartTime >= 30 * 60) // Check if 30 minutes have elapsed
           {
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                  continue;
               if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
                  continue;

               int orderType = OrderType();

               // If EMA angle > 5 continuously for 30m, close all SELL orders
               if(emaAngle > 5.0 && orderType == OP_SELL)
                 {
                  Print("EMA ANGLE TRIGGER (> 5Â° for 30m): Closing SELL order. Angle: ", DoubleToString(emaAngle, 2));
                  SafeOrderClose(OrderTicket(), OrderLots(), OP_SELL, Slippage, clrRed);
                 }

               // If EMA angle < -5 continuously for 30m, close all BUY orders
               else
                  if(emaAngle < -5.0 && orderType == OP_BUY)
                    {
                     Print("EMA ANGLE TRIGGER (< -5Â° for 30m): Closing BUY order. Angle: ", DoubleToString(emaAngle, 2));
                     SafeOrderClose(OrderTicket(), OrderLots(), OP_BUY, Slippage, clrRed);
                    }
              }
           }
     }
   else
     {
      // Reset the timer immediately if the angle flattens or drops back within 5 degrees
      EmaAngleExtremeStartTime = 0;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasMinimumSameOrderGap(int orderType, double minimumGapRaw)
  {
   RefreshRates();
   bool isBuy = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT);
   double currentPrice = isBuy ? Ask : Bid;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      int t = OrderType();
      bool matchDir = isBuy ? (t == OP_BUY || t == OP_BUYSTOP || t == OP_BUYLIMIT) : (t == OP_SELL || t == OP_SELLSTOP || t == OP_SELLLIMIT);
      if(!matchDir)
         continue;
      if(MathAbs(currentPrice - OrderOpenPrice()) < minimumGapRaw)
         return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetOpenPL(int OrderTypeFilter)
  {
   if(OrderTypeFilter == OP_BUY)
      return GlobalBuyPL;
   if(OrderTypeFilter == OP_SELL)
      return GlobalSellPL;
   return 0.0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetOppositeOrdersLots(int orderType)
  {
   UpdateOrderCacheIfNeeded();
   double totalLots = 0.01;
   if(orderType == OP_BUY)
      totalLots += g_orderCache.sellLots;
   else
      if(orderType == OP_SELL)
         totalLots += g_orderCache.buyLots;
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
   if(TradingHaltedUntilNextFlip) // Add this block
      return false;
   if(!IsDayProfitLadderTradingAllowed())
      return false;
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
   static int lastHistoryCount = -1;
   int curHistoryTotal = OrdersHistoryTotal();
   if(curHistoryTotal == lastHistoryCount)
      return;
   lastHistoryCount = curHistoryTotal;

   datetime latest=0;
   int ticket=-1,type=-1;
   double profit=0.0;
   for(int i=curHistoryTotal-1; i>=0; i--)
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
         break;
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
   LastLiveSSLDirection=GlobalSSLDirection;
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
void ResetTradeErrorRetryGuards() { TradeErrorBlockedCount=0; }
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
double GetPriceDifference(int lookbackMinutes = 30)
  {
   RefreshRates();

   double currentPrice = (Bid + Ask) / 2.0;

   lookbackMinutes = (int)MathMax(1, lookbackMinutes);

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
double Get5MinDifference(int orderType = OP_BUY)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   int lookbackMinutes = (int)MathMax(1.0, 5);
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
   double diff = (orderType == OP_BUY) ? Global30MinDiffBuy : Global30MinDiffSell;
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
int GetCachedPatternDirection()
  {
   if(Time[0] != LastPatternCalcTime)
     {
      LastPatternCalcTime = Time[0];
      CachedPatternDirection = (int)IsBullishORBearish();
     }
   return CachedPatternDirection;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateDefaultProfitTargetPrice(int orderType,double openPrice,double orderLots,double profitUSD)
  {
   if(openPrice<=0.0 || profitUSD<=0.0)
      return 0.0;
   // $1 USD = $100 raw price gap
   double priceDistance = profitUSD * 100.0;
   double target = 0.0;
   if(orderType==OP_BUY || orderType==OP_BUYLIMIT || orderType==OP_BUYSTOP)
      target = openPrice + priceDistance;
   else if(orderType==OP_SELL || orderType==OP_SELLLIMIT || orderType==OP_SELLSTOP)
      target = openPrice - priceDistance;
   else
      return 0.0;
   return NormalizeDouble(target, Digits);
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
            expectedSL=openPrice-Slippage-((StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 2000.0);
         else
            if(orderType==OP_SELL)
               expectedSL=openPrice+Slippage+((StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 2000.0);
        }
      if(expectedTP<=0.0)
        {
         if(orderType==OP_BUY)
            expectedTP=openPrice+Slippage+((TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0);
         else
            if(orderType==OP_SELL)
               expectedTP=openPrice-Slippage-((TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0);
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
bool IsDubaiTradingPauseHour()
  {
   if(EnableDubaiTradingPause)
      return IsTradingSloweHours();
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsTradingSloweHours()
  {
   datetime dubaiTime = TimeCurrent() + (ServerToDubaiOffsetHours * 3600);
   int currentHour = TimeHour(dubaiTime);

   string hours[];
   int count = StringSplit(DubaiTradingPauseHours, ',', hours);
   if(count <= 0)
      return false;

   for(int i = 0; i < count; i++)
     {
      string hourStr = hours[i];
      StringTrimLeft(hourStr);
      StringTrimRight(hourStr);
      if(hourStr == "")
         continue;
      int pauseHour = (int)StringToInteger(hourStr);
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
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RemoveDubaiTradingPauseDashboard() { }
//+------------------------------------------------------------------+
//| Verify if BUY or SELL order is allowed based on EMA & 300 gap    |
//+------------------------------------------------------------------+
bool IsOrderAllowedByTrendAndGap(int orderType)
  {
   RefreshRates();

   bool isBuyRequest  = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT);
   bool isSellRequest = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);

// Check counter-trend Buy orders when EMA direction is bearish (-1)
   if(EMADirection == -1 && isBuyRequest)
     {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;

         if(OrderType() == OP_BUY)
           {
            double priceGap = MathAbs(Ask - OrderOpenPrice());
            if(priceGap < 300.0)
              {
               Print("TRADE BLOCKED | EMADirection is Sell, open Buy exists, gap < 300.");
               return false;
              }
           }
        }
     }

// Check counter-trend Sell orders when EMA direction is bullish (1)
   if(EMADirection == 1 && isSellRequest)
     {
      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;

         if(OrderType() == OP_SELL)
           {
            double priceGap = MathAbs(Bid - OrderOpenPrice());
            if(priceGap < 300.0)
              {
               Print("TRADE BLOCKED | EMADirection is Buy, open Sell exists, gap < 300.");
               return false;
              }
           }
        }
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool emaflipstrongorweak()
  {
   static bool cachedVal = false;
   static int  cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   if(EmaFlipTime == 0)
     {
      cachedVal = false;
      cachedTick = CurrentTickSequence;
      return false;
     }

   RefreshRates();

   int flipShift = iBarShift(Symbol(), Period(), EmaFlipTime, false);
   if(flipShift < 0)
      flipShift = Bars - 1;

// 100.0 means exactly $100 USD price movement on BTCUSD
   double threshold = 100.0;

// Handle Buy Direction (EMAdirection == 1)
   if(EMADirection == 1)
     {
      double highestPrice = -1.0;
      for(int i = flipShift; i >= 0; i--)
        {
         if(High[i] > highestPrice)
            highestPrice = High[i];
        }

      double pullbackFromHigh = highestPrice - Bid;
      if(pullbackFromHigh >= threshold)
         cachedVal = false; // Weak (Price pulled back $100+ USD from the peak)
      else
         cachedVal = true; // Strong
     }
// Handle Sell Direction (EMAdirection == -1)
   else
      if(EMADirection == -1)
        {
         double lowestPrice = 999999.0;
         for(int i = flipShift; i >= 0; i--)
           {
            if(Low[i] < lowestPrice)
               lowestPrice = Low[i];
           }

         // Measures how many USD the Ask price has bounced UP from the lowest low
         double bounceFromLow = Ask - lowestPrice;
         if(bounceFromLow >= threshold)
            cachedVal = false; // Weak (Price bounced up $100+ USD from the low -> do not sell)
         else
            cachedVal = true; // Strong (Price has not bounced by $100+ USD)
        }
      else
        {
         cachedVal = false;
        }

   cachedTick = CurrentTickSequence;
   return cachedVal;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool emaflipstrongorweakOld()
  {
   if(EmaFlipTime == 0)
      return false;

   RefreshRates();

   int flipShift = iBarShift(Symbol(), Period(), EmaFlipTime, false);
   if(flipShift < 0)
      flipShift = Bars - 1;

   double threshold = 2*100.0 * Point;

// Handle Buy Direction (EMAdirection == 1)
   if(EMADirection == 1)
     {
      double highestPrice = 0.0;
      for(int i = flipShift-15; i >= 0; i--)
        {
         if(High[i] > highestPrice)
            highestPrice = High[i];
        }

      double pullbackFromHigh = highestPrice - Bid;
      if(pullbackFromHigh >= threshold)
         return false; // Weak

      return true; // Strong
     }
// Handle Sell Direction (EMAdirection == -1)
   else
      if(EMADirection == -1)
        {
         double lowestPrice = 999999.0;
         for(int i = flipShift-15; i >= 0; i--)
           {
            if(Low[i] < lowestPrice)
               lowestPrice = Low[i];
           }

         double bounceFromLow = Ask - lowestPrice;
         if(bounceFromLow >= threshold)
            return false; // Weak

         return true; // Strong
        }

   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasAnyLargeCandle(string symbol, ENUM_TIMEFRAMES timeframe, int candleCount, double threshold, bool checkBody = true)
  {
   for(int i = 1; i <= candleCount; i++)
     {
      double o = iOpen(symbol, timeframe, i);
      double c = iClose(symbol, timeframe, i);
      double h = iHigh(symbol, timeframe, i);
      double l = iLow(symbol, timeframe, i);

      double size = checkBody ? MathAbs(o - c) : MathAbs(h - l);

      if(size > threshold)
         return true;
     }
   return false;
  }
string TradeMonitoringLog="";
bool IsFarEnoughFromPeak(string symbol, double proximityThreshold = 50.0)
  {
// Last 1 hour on M1 = 60 candles (starting from bar 1)
   int highestBar = iHighest(symbol, PERIOD_M1, MODE_HIGH, 60, 10);
   if(highestBar < 0)
      return true;

   double highestPrice = iHigh(symbol, PERIOD_M1, highestBar);
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // or Close[0]

// Check if current price is within 'proximityThreshold' (e.g., 50) of the highest price
   if((highestPrice - currentPrice) <= proximityThreshold)
     {
      return false; // Too close to the 1-hour high
     }

   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsFarEnoughFromTrough(string symbol, double proximityThreshold = 50.0)
  {
// Last 1 hour on M1 = 60 candles (starting from bar 1)
   int lowestBar = iLowest(symbol, PERIOD_M1, MODE_LOW, 60, 1);
   if(lowestBar < 0)
      return true;

   double lowestPrice = iLow(symbol, PERIOD_M1, lowestBar);
   double currentPrice = SymbolInfoDouble(symbol, SYMBOL_BID); // or Close[0]

// Check if current price is within 'proximityThreshold' (e.g., 50) of the lowest price
   if((currentPrice - lowestPrice) <= proximityThreshold)
     {
      return false; // Too close to the 1-hour low (don't sell right at the bottom)
     }

   return true;
  }

// bool IsTradeAllowed(int orderType)
//   {
// // 1. Block if there's a huge candle (> 200.0) in the last 5 M1 bars (applies to both)
//    if(HasAnyLargeCandle(Symbol(), PERIOD_M1, 5, 200.0, false))
//       return false;

//    if(orderType == OP_BUY)
//      {
//       // Block Buy if price is within 50 points of the 1-hour high
//       if(!IsFarEnoughFromPeak(Symbol(), 50.0))
//          return false;
//      }
//    else
//       if(orderType == OP_SELL)
//         {
//          // For Sell, check proximity to 1-hour LOW instead of high (example logic)
//          if(!IsFarEnoughFromTrough(Symbol(), 50.0))
//             return false;
//         }

//    return true;
//   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// bool IsTradeAllowed(int orderType)
//   {
// // 1. Block if there's a huge candle (> 200.0) in the last 5 M1 bars (applies to both)
//    if(HasAnyLargeCandle(Symbol(), PERIOD_M1, 5, 200.0, false))
//       return false;

//    if(orderType == OP_BUY)
//      {
//       // Block Buy if price is within 50 points of the 1-hour high
//       if(!IsFarEnoughFromPeak(Symbol(), 50.0))
//          return false;
//      }
//    else
//       if(orderType == OP_SELL)
//         {
//          // For Sell, check proximity to 1-hour LOW instead of high (example logic)
//          if(!IsFarEnoughFromTrough(Symbol(), 50.0))
//             return false;
//         }

//    return true;
//   }
// Check if a new BUY order is allowed (Option B: blocks if a buy order is open and newPrice > existing OrderOpenPrice)
bool CanOpenBuyOrder(string sym, double newPrice)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == sym && (OrderType() == OP_BUY || OrderType() == OP_BUYSTOP || OrderType() == OP_BUYLIMIT))
           {
            // Do not open a new buy order if the new price is ABOVE an existing open buy order
            if(newPrice > OrderOpenPrice())
               return false;
           }
        }
     }
   return true;
  }

// Check if a new SELL order is allowed (Option B: blocks if a sell order is open and newPrice < existing OrderOpenPrice)
bool CanOpenSellOrder(string sym, double newPrice)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == sym && (OrderType() == OP_SELL || OrderType() == OP_SELLSTOP || OrderType() == OP_SELLLIMIT))
           {
            // Do not open a new sell order if the new price is BELOW an existing open sell order
            // (Change '<' to '>' if you want to block when price is above the existing sell)
            if(newPrice < OrderOpenPrice())
               return false;
           }
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double Get30MinutePriceDifference()
  {
   double currentPrice = Bid;
   double price30MinAgo = iClose(Symbol(), PERIOD_M1, 30);

   if(price30MinAgo <= 0.0)
      return 0.0;

   return currentPrice - price30MinAgo;
  }
string TradeMonitoringLog2="";
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int SafeOrderSend(string symbol,int orderType,double lots,double price,int slippage,double stopLoss,double takeProfit,string comment,int magic,color arrowColor)
  {
   bool isFlipBasketSupport = IsFLIPBasketSupportOrder(-1, comment);

   if(OnlyAllowFLIPBasketSupportOrders && !isFlipBasketSupport)
     {
      Print("SAFEORDERSEND BLOCKED [FLIP Test Mode]: Only FLIPBasketSupport orders allowed. Blocked order: '", comment, "' (Type=", orderType, ", Lots=", lots, ")");
      return -1;
     }

   if(g_dailyEquityTradingBlocked)



      // ADD THIS LINE: Block re-entry orders if EMA Ladder is halted
      if(TradingHaltedUntilNextFlip)
         return -1;
   ;


   if(TradeOperationFailedThisTick)
      return -1;
   if(IsDubaiTradingPauseHour())
      return -1;
   if(!IsDayProfitLadderTradingAllowed())
      return -1;








// // Blokkeer Buys wanneer het verlies minder is dan $2 (P/L > -2.0) en de EMA-hoek kleiner is dan 2.0
//    if(GetOpenPL(OP_BUY) > -safeOrdersendLossCondition*balancelomultipler && GlobalEmaAngle30 < 2 &&
//       (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
//      {
//       Print("TRADE BUY BLOCKED | Buy P/L is beter dan -$2 verlies en EMA-hoek is te laag (", DoubleToString(GlobalEmaAngle30, 2), " deg < 2.0).");
//       return -1;
//      }

// // Block Sell orders when floating loss is less than $2 (P/L > -2.0) and EMA angle is greater than -2.0
//    if(GetOpenPL(OP_SELL) > -safeOrdersendLossCondition*balancelomultipler && GlobalEmaAngle30 > -2 &&
//       (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
//      {
//       Print("TRADE SELL BLOCKED | Sell P/L is better than -$2 loss and EMA angle is too weak/flat (", DoubleToString(GlobalEmaAngle30, 2), " deg > -2.0).");
//       return -1;
//      }


//minimum angele with price diff condition

// if(MathAbs(GlobalEmaAngle30)<1 && MathAbs(Get30MinutePriceDifference())<100)
//   {
//    Print("TRADE BLOCKED | BOTH SIDES Angle below 2 degrees. No trade allowed.");
//    TradeMonitoringLog="TRADE BLOCKED | BOTH SIDES Angle below 2 degrees. No trade allowed.";
//    return -1;;
//   }
// else
//   {
//    TradeMonitoringLog="";
//   }


   int requestedDirection = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? 1 : -1;

// Determine whether to bypass EmaFlipTime for either Buy or Sell
   bool ignoreFlipTime = false;

// Buy condition: EMA is bullish (+1) and open Buy loss is $2.00 or more
   if(EMADirection == 1 && GetOpenPL(OP_BUY) <= -safeOrdersendLossCondition*balancelomultipler &&
      (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
     {
      ignoreFlipTime = true;
     }

// Sell condition: EMA is bearish (-1) and open Sell loss is $2.00 or more
   if(EMADirection == -1 && GetOpenPL(OP_SELL) <= -safeOrdersendLossCondition*balancelomultipler &&
      (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
     {
      ignoreFlipTime = true;
     }

   if(MathAbs(Get30MinutePriceDifference())<100)
      ignoreFlipTime = true;


   if(EMADirection != requestedDirection)
     {
      if(requestedDirection == -1 && GetOpenPL(OP_SELL) <= -20)
        {
         // Allow despite EMA direction mismatch
        }
      else
         if(requestedDirection == 1 && GetOpenPL(OP_BUY) <= -20)
           {
            // Allow despite EMA direction mismatch
           }
         else
           {
            return -1;
           }
     }

   if(!IsEmaWEAKDistanceReduced50PercentFromPeak() && EMADirection!= requestedDirection)
      return -1;


// if(EMAflipdistance()>200 && !IsEmaWEAKDistanceReduced50PercentFromPeak() && EMADirection!= requestedDirection)
//  return -1;


// Block trades if flip time is under 15 minutes and bypass criteria are NOT met
// if(!ignoreFlipTime && (TimeCurrent() - EmaFlipTime < 60 * 5))
//   {
//    Comment("TRADE BLOCKED | EmaFlipTime < 15 mins");
//    return -1;
//   }

// if(TimeCurrent() - EmaFlipTime < 60*15)
//   {

//    Comment("TRADE BLOCKED | EmaFlipTime < 60*30");

//    return -1;;

//   }


// if(IsEmaWEAKDistanceReduced50PercentFromPeak(orderType))//weak
//   {
//    Print("TRADE BLOCKED | IsEmaWEAKDistanceReduced50PercentFromPeak");

//    return -1;;


//   }

// if(GlobalEmaAngle30 < -2  )
//   {
//    Print("TRADE BLOCKED | EMA trend is not bullish for Buy order.");
//    return false;
//   }
// --- SEPARATE CONDITION: Strict block for opposite orders during strong uptrend (2 to 6 degrees) ---
   /* if((StringFind(OrderComment(), "RECOVERY_") <0) && EMADirection != -1 && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
      {
       Print("TRADE SELL BLOCKED | Strict opposite block: EMA trend is strong uptrend  ");
       return -1;
      }

   // --- SEPARATE CONDITION: Strict block for opposite orders during strong downtrend (-2 to -6 degrees) ---
    if((StringFind(OrderComment(), "RECOVERY_") <0) && EMADirection != 1 && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
      {
       Print("TRADE BUY BLOCKED | Strict opposite block: EMA trend is strong downtrend  ");
       return -1;
      }*/
// --- STRICT EMA TREND FILTER WITH EXHAUSTION ALLOWANCE ---

// --- STRICT EMA TREND FILTER WITH EXHAUSTION ALLOWANCE ---

// // Block Sells during a standard strong uptrend (2 to 6 degrees). Allows Sells > 6 for extreme exhaustion.
//    if(GetOpenPL(OP_BUY) >-2 && GlobalEmaAngle30 > 2.0 && GlobalEmaAngle30 <= 6.0 && EMADirection != -1 && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
//      {
//       Comment("TRADE SELL BLOCKED | EMA trend is strong (", DoubleToString(GlobalEmaAngle30, 2), " deg). Waiting for extreme exhaustion (>6) to Sell.");
//       return -1;
//      }

// // Block Buys during a standard strong downtrend (-2 to -6 degrees). Allows Buys < -6 for extreme exhaustion.
//    if(GetOpenPL(OP_SELL) > -2 && GlobalEmaAngle30 < -2.0 && GlobalEmaAngle30 >= -6.0 && EMADirection != 1 && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
//      {
//       Comment("TRADE BUY BLOCKED | EMA trend is strong (", DoubleToString(GlobalEmaAngle30, 2), " deg). Waiting for extreme exhaustion (<-6) to Buy.");
//       return -1;
//      }



// if(IsOrderAllowedByTrendAndGap(orderType) == false)
//   {
//    Comment("TRADE BLOCKED | Counter-trend order blocked due to EMA direction and gap rules.");
//    return -1;
//   }

// --- CHECK IF THIS IS A V-SHAPE BOUNCE OVERRIDE ---
// bool isVShapeOverride = ((orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) && GlobalVShapeBuy) ||
//                         ((orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT) && GlobalVShapeSell);


// bool isVShapeOverride = ((orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) && GlobalVShapeBuy) ||
// ((orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT) && GlobalVShapeSell) ||
// MissedSignalOverride; // <-- Added memory override flag


   bool isVShapeOverride = ((orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) && GlobalVShapeBuy) ||
                           ((orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT) && GlobalVShapeSell) ||
                           StoredSignalOverride; // <-- Added memory override flag

// --- STRATEGY FILTERS (IGNORED FOR BOUNCE ORDERS) ---
   if(!isVShapeOverride)
     {
      double currentAngle = GlobalEmaAngle30;

      // // 1. EMA Angle Hard Stops
      // if(currentAngle > angleBlockAboveRule && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
      //   {
      //    Print("TRADE BLOCKED | EMA Angle (", DoubleToString(currentAngle, 2), ") > ", angleBlockAboveRule, " prohibits Sell orders.");
      //    return -1;
      //   }
      // if(currentAngle < -angleBlockAboveRule && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
      //   {
      //    Print("TRADE BLOCKED | EMA Angle (", DoubleToString(currentAngle, 2), ") < -", angleBlockAboveRule, " prohibits Buy orders.");
      //    return -1;
      //   }

      // 2. Late Entry Exhaustion Blocks
      // if(currentAngle > angleBlockAboveRule && Global30MinDiffBuy < 30 && (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT))
      //   {
      //    Print("TRADE BLOCKED | EMA Angle (", DoubleToString(currentAngle, 2), ") > ", angleBlockAboveRule, " but Momentum < 30 prohibits Buy orders.");
      //    return -1;
      //   }
      // if(currentAngle < -angleBlockAboveRule && Global30MinDiffSell > -30 && (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT))
      //   {
      //    Print("TRADE BLOCKED | EMA Angle (", DoubleToString(currentAngle, 2), ") < -", angleBlockAboveRule, " but Momentum > -30 prohibits Sell orders.");
      //    return -1;
      //   }

      // // 3. 30-Minute Momentum Hard Block (50 points)
      // double minRequiredMomentum = 15.0;//50;
      // if((orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) && Get5MinDifferenceBuy1 < minRequiredMomentum)
      //   {
      //    Print("TRADE BLOCKED | Weak Upward Momentum: 30-min diff is ", DoubleToString(Get5MinDifferenceBuy1, 2), " (Requires >= ", minRequiredMomentum, ")");
      //    return -1;
      //   }
      // if((orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT) && Get5MinDifferenceSell1 > -minRequiredMomentum)
      //   {
      //    Print("TRADE BLOCKED | Weak Downward Momentum: 30-min diff is ", DoubleToString(Get5MinDifferenceSell1, 2), " (Requires <= -", minRequiredMomentum, ")");
      //    return -1;
      //   }
      // // 3. 30-Minute Momentum Hard Block (50 points)
      // double minRequiredMomentum = 15.0;//50;
      // if((orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) && Global30MinDiffBuy < minRequiredMomentum)
      //   {
      //    Print("TRADE BLOCKED | Weak Upward Momentum: 30-min diff is ", DoubleToString(Global30MinDiffBuy, 2), " (Requires >= ", minRequiredMomentum, ")");
      //    return -1;
      //   }
      // if((orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT) && Global30MinDiffSell > -minRequiredMomentum)
      //   {
      //    Print("TRADE BLOCKED | Weak Downward Momentum: 30-min diff is ", DoubleToString(Global30MinDiffSell, 2), " (Requires <= -", minRequiredMomentum, ")");
      //    return -1;
      //   }

      // 4. P&L & SSL Direction Block
      /*
      int currentSSL = GlobalSSLDirection;
      int requestedDirection = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? 1 : -1;
      int baseMarketType     = (requestedDirection == 1) ? OP_BUY : OP_SELL;
      double currentPL       = (baseMarketType == OP_BUY) ? GlobalBuyPL : GlobalSellPL;

      if(currentPL <= -plBlockAboveRule && currentSSL != requestedDirection)
        {
         Print("TRADE BLOCKED | Floating PL <= -", plBlockAboveRule, " and SSL does not match requested direction.");
         return -1;
        }
         */
     }
   else
     {
      Print("V-SHAPE OVERRIDE: Bypassing SafeOrderSend strategy filters for bounce trade.");
     }

// --- PHYSICAL SAFETY BLOCKS (APPLIES TO ALL ORDERS) ---
   RefreshRates();
   double currentSpreadUSD = Ask - Bid;
   if(currentSpreadUSD > MaxAllowedSpreadUSD)
     {
      Print("TRADE BLOCKED | Spread too high: $", DoubleToString(currentSpreadUSD, 2), " | Max allowed: $", DoubleToString(MaxAllowedSpreadUSD, 2));
      return -1;
     }

   if(Enable30MinuteMomentumFilter && Enable30MinuteMomentumForAllOrders && !isVShapeOverride)
     {
      if(!PassesDeferredMomentum(orderType))
         return QueueDeferredOrder(symbol,orderType,lots,price,slippage,stopLoss,takeProfit,comment,magic,arrowColor);
     }

   string key=MakeTradeErrorKey("SEND",-1,IntegerToString(orderType)+"|"+DoubleToString(lots,8)+"|"+comment);
   if(IsTradeErrorBlockedThisTick(key))
      return -1;

   lots = NormalizeLots(lots);

// ... [Rest of your standard execution logic below remains exactly the same] ...

   double sendPrice=price;
   if(orderType==OP_BUY)
      sendPrice=Ask;
   else
      if(orderType==OP_SELL)
         sendPrice=Bid;
   sendPrice=NormalizeDouble(sendPrice,Digits);
   if(takeProfit<=0.0)
     {
      double rawTPDist = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
      if(orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
         takeProfit = NormalizeDouble(sendPrice + rawTPDist, Digits);
      else if(orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
         takeProfit = NormalizeDouble(sendPrice - rawTPDist, Digits);
     }
   double safeSL=stopLoss;
   if(safeSL<=0.0)
     {
      double rawSLDist = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 2000.0;
      if(orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
         safeSL = NormalizeDouble(sendPrice - rawSLDist, Digits);
      else if(orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
         safeSL = NormalizeDouble(sendPrice + rawSLDist, Digits);
     }






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
//| Safely modify in-profit orders or close in-loss orders by ticket |
//+------------------------------------------------------------------+
bool SafeOrderCloseNew(int ticket, double lots, int orderType, int slippage, color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;

   string key = MakeTradeErrorKey("MANAGE", ticket, "");
   if(IsTradeErrorBlockedThisTick(key))
      return false;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return true; // Already closed
      return false;
     }

// Calculate total profit including commission and swap
   double totalProfit = OrderProfit() + OrderSwap() + OrderCommission();
   double openPrice = OrderOpenPrice();
   double currentTP = OrderTakeProfit();

   RefreshRates();

// --- BRANCH 1: IN PROFIT -> MODIFY STOP LOSS TO LOCK IN GAINS ---
   if(totalProfit >= 0)
     {
      double newStopLoss = 0;

      if(orderType == OP_BUY)
        {
         newStopLoss = Bid - (15 * Point);
         if(newStopLoss < openPrice)
            newStopLoss = openPrice + (2 * Point); // Ensure it locks in a slight profit above entry
        }
      else
         if(orderType == OP_SELL)
           {
            newStopLoss = Ask + (15 * Point);
            if(newStopLoss > openPrice)
               newStopLoss = openPrice - (2 * Point); // Ensure it locks in a slight profit below entry
           }

      newStopLoss = NormalizeDouble(newStopLoss, Digits);

      if(!CanSendTradeRequest("OrderModify", "Ticket=" + IntegerToString(ticket)))
         return false;

      ResetLastError();
      bool modResult =SafeOrderModify(ticket, openPrice, newStopLoss, currentTP, 0, arrowColor);

      if(modResult)
        {
         InvalidateTotalEAOrdersCache();
         return true;
        }

      int modErr = GetLastError();
      BlockTradeErrorUntilNextTick(key);
      MarkServerError(modErr, "OrderModify");
      return false;
     }
// --- BRANCH 2: IN LOSS -> CLOSE ORDER ---
   else
     {
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;
      closePrice = NormalizeDouble(closePrice, Digits);

      if(!CanSendTradeRequest("OrderClose", "Ticket=" + IntegerToString(ticket)))
         return false;

      ResetLastError();
      bool closeResult = OrderClose(ticket, lots, closePrice, slippage, arrowColor);

      if(closeResult)
        {
         InvalidateTotalEAOrdersCache();
         return true;
        }

      int closeErr = GetLastError();
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
            return true;
        }

      BlockTradeErrorUntilNextTick(key);
      MarkServerError(closeErr, "OrderClose");
      return false;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SafeOrderClose(int ticket, double lots, int orderType, int slippage, color arrowColor)
  {
   if(TradeOperationFailedThisTick)
      return false;

   string key = MakeTradeErrorKey("CLOSE_MOD", ticket, "");
   if(IsTradeErrorBlockedThisTick(key))
      return false;

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      // If it's already in history, the order is successfully closed
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return true;
      return false;
     }

   RefreshRates();

   // Server error condition: direct market close allowed ONLY on server error
   if(ServerRecoveryPending || !IsConnected())
     {
      return SafeOrderCloseMarket(ticket, lots, slippage, arrowColor);
     }

   double pl = OrderProfit() + OrderSwap() + OrderCommission();
   double openPrice = OrderOpenPrice();
   double currentSL = OrderStopLoss();
   double currentTP = OrderTakeProfit();
   double newSL = 0.0;

// Calculate safe stop limits to prevent Error 130
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double spreadBuf = (Ask - Bid) * 2.0;
   double minSafeDistance = MathMax(stopLevel, spreadBuf);
   if(minSafeDistance < 10.0 * Point)
      minSafeDistance = 10.0 * Point;

// ==================================================================
// Modify order with stoploss with liveprice and $rawpricegap $50
// ==================================================================
   double rawPriceGap50 = 50.0;
   if(orderType == OP_BUY)
     {
      newSL = Bid - rawPriceGap50;
      if(Bid - newSL < minSafeDistance)
         newSL = Bid - minSafeDistance;
      newSL = NormalizeDouble(newSL, Digits);

      // If current SL is already set:
      if(currentSL > 0.0)
        {
         // If current SL is already tighter than newSL, keep existing tighter SL
         if(currentSL >= newSL)
            return true;
         // Avoid micro-modifications below MinimumSLModifyGapRaw ($25)
         if(newSL - currentSL < MinimumSLModifyGapRaw)
            return true;
        }
     }
   else if(orderType == OP_SELL)
     {
      newSL = Ask + rawPriceGap50;
      if(newSL - Ask < minSafeDistance)
         newSL = Ask + minSafeDistance;
      newSL = NormalizeDouble(newSL, Digits);

      // If current SL is already set:
      if(currentSL > 0.0)
        {
         // If current SL is already tighter than newSL, keep existing tighter SL
         if(currentSL <= newSL)
            return true;
         // Avoid micro-modifications below MinimumSLModifyGapRaw ($25)
         if(currentSL - newSL < MinimumSLModifyGapRaw)
            return true;
        }
     }
   else
     {
      return false;
     }

// Check if the SL is already at the target to prevent unnecessary modification spam
   if(MathAbs(currentSL - newSL) < Point / 2.0)
      return true;

// Final check against broker limits before sending
   if(orderType == OP_BUY && Bid - newSL < minSafeDistance)
      return false;
   if(orderType == OP_SELL && newSL - Ask < minSafeDistance)
      return false;

   if(!CanSendTradeRequest("OrderModify", "Ticket=" + IntegerToString(ticket)))
      return false;

   ResetLastError();

// Execute Modify instead of direct Close
   bool result = SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, arrowColor);

   if(result)
     {
      InvalidateTotalEAOrdersCache();
      Print("SafeOrderClose: Modified SL with live price and $50 raw gap. Ticket: ", ticket, " | New SL: ", DoubleToString(newSL, Digits));
      return true;
     }

   int err = GetLastError();

   if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
     {
      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_HISTORY))
         return true;
     }

   BlockTradeErrorUntilNextTick(key);
   MarkServerError(err, "OrderModify (Intercepted from Close)");
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool SafeOrderCloseOld(int ticket,double lots,int orderType,int slippage,color arrowColor)
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

   string comment = OrderComment();

   RefreshRates();
   double requestedSL = (stopLoss > 0.0) ? NormalizeDouble(stopLoss, Digits) : 0.0;
   double requestedTP = (takeProfit > 0.0) ? NormalizeDouble(takeProfit, Digits) : 0.0;

   if(requestedSL > 0.0)
     {
      if(!PrepareStopLossForOrder(orderType, OrderOpenPrice(), requestedSL))
        {
         BlockTradeErrorUntilNextTick(key);
         MarkServerError(130, "OrderModify/unsafe-SL");
         return false;
        }
      if(orderType == OP_BUY && OrderStopLoss() > 0.0 && requestedSL <= OrderStopLoss())
        {
         BlockTradeErrorUntilNextTick(key);
         return false;
        }
      if(orderType == OP_SELL && OrderStopLoss() > 0.0 && requestedSL >= OrderStopLoss())
        {
         BlockTradeErrorUntilNextTick(key);
         return false;
        }
     }
   bool sameSL = (requestedSL <= 0.0 && OrderStopLoss() <= 0.0) || (requestedSL > 0.0 && MathAbs(OrderStopLoss() - requestedSL) < MinimumSLModifyGapRaw);
   bool sameTP = (requestedTP <= 0.0 && OrderTakeProfit() <= 0.0) || (requestedTP > 0.0 && MathAbs(OrderTakeProfit() - requestedTP) <= Point);
   if(sameSL && sameTP)
      return true;

   bool modified = false;
   int err = 0;
   int maxAttempts = 3;

   for(int attempt = 0; attempt < maxAttempts; attempt++)
     {
      ResetLastError();
      if(!CanSendTradeRequest("OrderModify", "Ticket=" + IntegerToString(ticket)))
         return false;

      modified = OrderModify(ticket, openPrice, requestedSL, requestedTP, expiration, arrowColor);
      if(modified)
         return true;

      err = GetLastError();

      // Retry on transient broker quote errors (136 Off Quotes, 138 Requote, 135 Price Changed, 137 Broker Busy, 146 Context Busy)
      if(err == 136 || err == 138 || err == 135 || err == 137 || err == 146)
        {
         Sleep(100);
         RefreshRates();

         // Re-validate and adapt SL distance if live price moved
         if(requestedSL > 0.0)
           {
            if(!PrepareStopLossForOrder(orderType, OrderOpenPrice(), requestedSL))
               break;
           }
         continue;
        }

      // Non-retryable error
      break;
     }

   if(!modified)
     {
      Print("ORDER MODIFY FAILED with server error ", err, " on Ticket #", ticket,
            " (Type=", GetOrderTypeText(orderType), "). Closing order immediately at market as requested...");

      if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
        {
         double curLots = OrderLots();
         int curType = OrderType();

         if(curType == OP_BUY || curType == OP_SELL)
           {
            for(int cAttempt = 0; cAttempt < 3; cAttempt++)
              {
               RefreshRates();
               double closePrice = (curType == OP_BUY) ? Bid : Ask;
               closePrice = NormalizeDouble(closePrice, Digits);
               ResetLastError();
               bool closed = OrderClose(ticket, curLots, closePrice, Slippage, (curType == OP_BUY ? clrRed : clrBlue));
               if(closed)
                 {
                  Print("ORDER CLOSED SUCCESSFULLY on modify error fallback: Ticket #", ticket,
                        " at ", DoubleToString(closePrice, Digits));
                  InvalidateTotalEAOrdersCache();
                  break;
                 }
               int closeErr = GetLastError();
               Print("OrderClose fallback attempt ", (cAttempt + 1), " failed for Ticket #", ticket, " | Error=", closeErr);
               Sleep(100);
              }
           }
         else if(curType == OP_BUYSTOP || curType == OP_SELLSTOP || curType == OP_BUYLIMIT || curType == OP_SELLLIMIT)
           {
            ResetLastError();
            bool deleted = OrderDelete(ticket, clrYellow);
            if(deleted)
              {
               Print("PENDING ORDER DELETED on modify error fallback: Ticket #", ticket);
               InvalidateTotalEAOrdersCache();
              }
           }
        }
      else
        {
         Print("Order #", ticket, " no longer open in MODE_TRADES (already closed).");
        }

      BlockTradeErrorUntilNextTick(key);
      MarkServerError(err, "OrderModify");
      return false;
     }

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
   int requiredAgeSeconds =0;// 6*60*60;
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
//+------------------------------------------------------------------+
//| Get direction for any specified timeframe based on current bar   |
//+------------------------------------------------------------------+
int GetCurrentMDirection(int timeframe)
  {
   double openPrice  = iOpen(Symbol(), timeframe, 0);
   double closePrice = iClose(Symbol(), timeframe, 0);

   if(openPrice <= 0.0 || closePrice <= 0.0)
      return 0;

   if(closePrice > openPrice)
      return 1;
   if(closePrice < openPrice)
      return -1;

   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetCurrentM30Direction()
  {
   double m30Open  = iOpen(Symbol(), PERIOD_M30, 0);
   double m30Close = iClose(Symbol(), PERIOD_M30, 0);

   if(m30Open <= 0.0 || m30Close <= 0.0)
      return 0;

   if(m30Close > m30Open)
      return 1;
   if(m30Close < m30Open)
      return -1;

   return 0;
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
   int sslDirection = GlobalSSLDirection;
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
   double momentumDiff = (orderType == OP_BUY) ? Global30MinDiffBuy : Global30MinDiffSell;
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
               lot = 0.10;

   if(CapLotWhenH1Opposite && h1Opposite)
      lot = MathMin(lot, 0.01);
   bool extremeVolatility = IsExtremeVolatility();
   if(extremeVolatility)
      lot = MathMin(lot, MathAbs(VolatilityLotCap));

   int dayOfWeek = TimeDayOfWeek(TimeCurrent());
   if(dayOfWeek == 0 || dayOfWeek == 6)
      lot = MathMin(lot, 0.02);
   return NormalizeLots(lot);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsSameLotOrderNearBy(int orderType, double checkLot, double gapRawThreshold)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? Ask : Bid;

   bool isBuyDirection  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSellDirection = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int existingType = OrderType();
      bool existingIsBuy  = (existingType == OP_BUY  || existingType == OP_BUYSTOP  || existingType == OP_BUYLIMIT);
      bool existingIsSell = (existingType == OP_SELL || existingType == OP_SELLSTOP || existingType == OP_SELLLIMIT);

      if(isBuyDirection && !existingIsBuy)
         continue;
      if(isSellDirection && !existingIsSell)
         continue;

      if(MathAbs(OrderLots() - checkLot) > 0.00001)
         continue;

      double distance = MathAbs(currentPrice - OrderOpenPrice());
      if(distance < gapRawThreshold)
        {
         Print("NEARBY ORDER DETECTED | Ticket: ", OrderTicket(), " | Gap: ", DoubleToString(distance, Digits));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateDecreaseLots(int reEntryCounter, double startLot, double endLot)
  {
   if(reEntryCounter < 0)
      reEntryCounter = 0;
   int totalSteps = (int)MathRound((startLot - endLot) / 0.01) + 1;
   if(totalSteps <= 0)
      return startLot;
   int currentStep = reEntryCounter % totalSteps;
   double calculatedLots = startLot - (currentStep * 0.01);
   return NormalizeDouble(calculatedLots, 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateIncreaseLots(int reEntryCounter, double startLot, double endLot)
  {
   if(reEntryCounter < 0)
      reEntryCounter = 0;
   int totalSteps = (int)MathRound((endLot - startLot) / 0.01) + 1;
   if(totalSteps <= 0)
      return startLot;
   int currentStep = reEntryCounter % totalSteps;
   double calculatedLots = startLot + (currentStep * 0.01);
   return NormalizeDouble(calculatedLots, 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CheckFastProfitableRecentOrders()
  {
   int validCount = 0;
   int checkedOrders = 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(checkedOrders >= 2)
         break;
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
              {
               double totalProfit = OrderProfit() + OrderSwap() + OrderCommission();
               int durationSeconds = (int)(OrderCloseTime() - OrderOpenTime());
               if(totalProfit > 0.0 && durationSeconds < 30)
                  validCount++;
               checkedOrders++;
              }
           }
        }
     }
   return (checkedOrders == 2 && validCount == 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool DetectBounceback(int direction, int shift)
  {
   if(EnableBounceBackDetection == false)
      return false; // Disable bounceback detection for now
   double ema = iMA(Symbol(), Period(), InpEMA200Period, 0, MODE_EMA, PRICE_CLOSE, shift);
   double c = Close[shift];
   double o = Open[shift];
   double atr = iATR(Symbol(), Period(), 14, shift);
   double distanceFromEMA = MathAbs(c - ema);
   double extremeDistance = atr * 4.0;
   double strongCandleBody = atr * 1.5;

   if(direction == 1)
     {
      if(c < ema && distanceFromEMA > extremeDistance)
        {
         if(c > o && (c - o) > strongCandleBody)
            return true;
        }
     }
   else
      if(direction == -1)
        {
         if(c > ema && distanceFromEMA > extremeDistance)
           {
            if(c < o && (o - c) > strongCandleBody)
               return true;
           }
        }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawBouncebackIcon(datetime time, double price, int direction)
  {
   string objName = "BOUNCE_BOX_" + IntegerToString((int)time);
   if(ObjectFind(0, objName) < 0)
     {
      // 1. Width: 5 Minutes (300 seconds)
      datetime endTime = time + (5 * 60);

      // 2. Dynamic Height: Use 50% of the current average candle size
      // This guarantees the box is always visually proportionate to the asset
      double visibleHeight = iATR(Symbol(), Period(), 14, 1) * 0.5;

      double topPrice = 0.0;
      double bottomPrice = 0.0;

      if(direction == 1)
        {
         // Bullish (Green): Box anchors at price and extends UP
         bottomPrice = price;
         topPrice = price + visibleHeight*5;
        }
      else
        {
         // Bearish (Red): Box anchors at price and extends DOWN
         topPrice = price;
         bottomPrice = price - visibleHeight*5;
        }

      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, time, topPrice, endTime, bottomPrice);

      // 3. Properties
      ObjectSetInteger(0, objName, OBJPROP_COLOR, (direction == 1) ? clrGreen : clrRed);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      // ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, (direction == 1) ? "Bullish Bounce Block" : "Bearish Bounce Block");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawHistoricalBouncebacks()
  {
   int lookback = MathMin(1000, Bars - 1);
   for(int i = lookback; i >= 1; i--)
     {
      if(DetectBounceback(1, i))
         DrawBouncebackIcon(Time[i], Low[i] - (50 * Point), 1);
      if(DetectBounceback(-1, i))
         DrawBouncebackIcon(Time[i], High[i] + (50 * Point), -1);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsBounceOne(int shift, int direction, double minReversalPrice)
  {
   double c0 = Close[shift],   o0 = Open[shift],   h0 = High[shift],   l0 = Low[shift];
   double c1 = Close[shift+1], o1 = Open[shift+1], h1 = High[shift+1], l1 = Low[shift+1];

   if(direction == 1)
     {
      if(c1 < o1 && c0 > o0)
        {
         if((c0 - l0) >= minReversalPrice && c0 > h1)
            return true;
        }
     }
   else
      if(direction == -1)
        {
         if(c1 > o1 && c0 < o0)
           {
            if((h0 - c0) >= minReversalPrice && c0 < l1)
               return true;
           }
        }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDoubleTap(int shift, int direction, int lookback, double tolerancePrice)
  {
   int minSwingBars = 3;

   if(direction == 1)
     {
      double currentLow = Low[shift];
      int prevLowIdx = iLowest(Symbol(), Period(), MODE_LOW, lookback, shift + minSwingBars);
      if(prevLowIdx == -1)
         return false;

      if(MathAbs(currentLow - Low[prevLowIdx]) <= tolerancePrice)
        {
         if(Close[shift] > Open[shift])
            return true;
        }
     }
   else
      if(direction == -1)
        {
         double currentHigh = High[shift];
         int prevHighIdx = iHighest(Symbol(), Period(), MODE_HIGH, lookback, shift + minSwingBars);
         if(prevHighIdx == -1)
            return false;

         if(MathAbs(currentHigh - High[prevHighIdx]) <= tolerancePrice)
           {
            if(Close[shift] < Open[shift])
               return true;
           }
        }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDoubleBottom(int shift, int lookback, double tolerancePrice)
  {
   int searchHalf = lookback / 2;
   int minSwingBars = 5;

   int low2Idx = iLowest(Symbol(), Period(), MODE_LOW, searchHalf, shift + 1);
   if(low2Idx == -1)
      return false;

   int low1Idx = iLowest(Symbol(), Period(), MODE_LOW, searchHalf, low2Idx + minSwingBars);
   if(low1Idx == -1)
      return false;

   int necklineIdx = iHighest(Symbol(), Period(), MODE_HIGH, (low1Idx - low2Idx), low2Idx + 1);
   if(necklineIdx == -1)
      return false;

   double neckline = High[necklineIdx];

   if(MathAbs(Low[low1Idx] - Low[low2Idx]) <= tolerancePrice)
     {
      if(Close[shift+1] <= neckline && Close[shift] > (neckline + (tolerancePrice * 0.25)))
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsDoubleTop(int shift, int lookback, double tolerancePrice)
  {
   int searchHalf = lookback / 2;
   int minSwingBars = 5;

   int high2Idx = iHighest(Symbol(), Period(), MODE_HIGH, searchHalf, shift + 1);
   if(high2Idx == -1)
      return false;

   int high1Idx = iHighest(Symbol(), Period(), MODE_HIGH, searchHalf, high2Idx + minSwingBars);
   if(high1Idx == -1)
      return false;

   int necklineIdx = iLowest(Symbol(), Period(), MODE_LOW, (high1Idx - high2Idx), high2Idx + 1);
   if(necklineIdx == -1)
      return false;

   double neckline = Low[necklineIdx];

   if(MathAbs(High[high1Idx] - High[high2Idx]) <= tolerancePrice)
     {
      if(Close[shift+1] >= neckline && Close[shift] < (neckline - (tolerancePrice * 0.25)))
         return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void DrawPatternMarker(datetime time, double price, color color1, string tooltipText="CIRCLE_REVERSE")
  {
   string objName = "PATTERN_MARKER_" + IntegerToString((int)time);
   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_ARROW, 0, time, price);
      ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 159);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, color1);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 5);
      ObjectSetInteger(0, objName, OBJPROP_BACK, false);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);

      // --- ADD HOVER TOOLTIP TEXT ---
      ObjectSetString(0, objName, OBJPROP_TOOLTIP, tooltipText);
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ScanAndMarkStructuralPatterns()
  {
   int shift = 5;
   int patternLookback = 30;
   double priceTolerance = 50.0;
   double minReversalPrice = 200.0;

   bool isBullishPattern = IsBounceOne(shift, 1, minReversalPrice) ||
                           IsDoubleTap(shift, 1, patternLookback, priceTolerance) ||
                           IsDoubleBottom(shift, patternLookback, priceTolerance);

   bool isBearishPattern = IsBounceOne(shift, -1, minReversalPrice) ||
                           IsDoubleTap(shift, -1, patternLookback, priceTolerance) ||
                           IsDoubleTop(shift, patternLookback, priceTolerance);

   if(isBullishPattern && Close[1] > High[shift])
     {
      // DrawPatternMarker(Time[1], Low[1] - (50 * Point), C'55,161,193',"CIRCLE_GREEN");
     }
   if(isBearishPattern && Close[1] < Low[shift])
     {
      // DrawPatternMarker(Time[1], High[1] + (50 * Point), C'255,230,0',"CIRCLE_RED");
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double IsBullishORBearish()
  {
   if(!enableCircleOrders)
      return 0;

   int shift = 5;
   int patternLookback = 30;
   double pointTolerance = 50.0;
   double minReversalPrice = 201.0;

   bool isBullishPattern = IsBounceOne(shift, 1, minReversalPrice) ||
                           IsDoubleTap(shift, 1, patternLookback, pointTolerance) ||
                           IsDoubleBottom(shift, patternLookback, pointTolerance);

   bool isBearishPattern = IsBounceOne(shift, -1, minReversalPrice) ||
                           IsDoubleTap(shift, -1, patternLookback, pointTolerance) ||
                           IsDoubleTop(shift, patternLookback, pointTolerance);

   if(isBullishPattern && Close[1] > High[shift])
      return 1;
   if(isBearishPattern && Close[1] < Low[shift])
      return -1;

   if(GlobalVShapeBuy)
      return 1;
   if(GlobalVShapeSell)
      return -1;

   return 0;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsHeavyLotOrderNearBy(int orderType, double checkLot, double gapRawThreshold)
  {
   RefreshRates();
   double currentPrice = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? Ask : Bid;

   bool isBuyDirection  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSellDirection = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int existingType = OrderType();
      bool existingIsBuy  = (existingType == OP_BUY  || existingType == OP_BUYSTOP  || existingType == OP_BUYLIMIT);
      bool existingIsSell = (existingType == OP_SELL || existingType == OP_SELLSTOP || existingType == OP_SELLLIMIT);

      if(isBuyDirection && !existingIsBuy)
         continue;
      if(isSellDirection && !existingIsSell)
         continue;

      double scaledCheckLot = checkLot * (balancelomultipler > 0 ? balancelomultipler : 1);
      if(OrderLots() < (scaledCheckLot * 0.8))
         continue;

      double distance = MathAbs(currentPrice - OrderOpenPrice());
      if(distance < gapRawThreshold)
        {
         Print("HEAVY ORDER Detected and Lots=0.01 | Ticket: ", OrderTicket(), " | Gap: ", DoubleToString(distance, Digits));
         return true;
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Close all orders if Equity exceeds Balance by $1.00 or more     |
//+------------------------------------------------------------------+
void CheckEquityBalanceProfitTarget()
  {
   double accountBalance = AccountBalance();
   double accountEquity  = AccountEquity();
   double targetProfit   = accountBalance + (Ladder1ProfitUSD * 5);

// Check if Equity has reached the protection target
   if(accountEquity >= targetProfit)
     {
      Print("Equity Target Reached! Balance: $", DoubleToString(accountBalance, 2),
            " | Equity: $", DoubleToString(accountEquity, 2), ". Modifying open orders to lock in profit and continuing trading.");

      // Modify open positions to lock in profit instead of closing them
      ModifyOpenOrdersToSecureProfit();
     }
  }
//+------------------------------------------------------------------+
//| Modify ONLY BUY orders if total Buy Basket Profit > $1           |
//+------------------------------------------------------------------+
void modifyOnlyBuyOrders()
  {
   UpdateOrderCacheIfNeeded();
   double basketBuyProfit = g_orderCache.buyPL;

// 2. If basket profit is > $1, modify all Buy orders
   if(basketBuyProfit > basketBUYorSELLProfitModifyUSD*balancelomultipler)
     {
      RefreshRates();

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
           {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_BUY)
              {
               int ticket       = OrderTicket();
               if(IsFLIPBasketSupportOrder(ticket, OrderComment()) || IsAnyRecoveryOrder(ticket, OrderComment()))
                  continue;
               double openPrice = OrderOpenPrice();
               double currentSL = OrderStopLoss();
               double currentTP = OrderTakeProfit();

               // Set SL based on current price (Bid)
               double minStopDist = GetRequiredStopDistance();
               double trailingBuffer = 20.0; // Raw BTC price buffer ($20.0), matching ModifyOpenOrdersToSecureProfit

               // Set SL based on current price (Bid) minus safe trailing buffer
               double newSL = Bid - trailingBuffer;
               newSL = NormalizeDouble(newSL, Digits);

               // Ensure broker stop distance is satisfied
               if(Bid - newSL < minStopDist)
                  newSL = NormalizeDouble(Bid - minStopDist, Digits);

               // CRITICAL: Only move SL UP to lock in profit, and ONLY once SL is above open price (guaranteeing profit)
               if(newSL > openPrice && (currentSL == 0.0 || newSL >= currentSL + MinimumSLModifyGapRaw))
                 {





                  ResetLastError();
                  bool modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrGreen);

                  if(modified)
                    {
                     Print("BUY BASKET > $1 | Ticket=", ticket, " | New SL=", DoubleToString(newSL, Digits));
                    }
                  else
                    {
                     Print("FAILED TO MODIFY BUY TICKET=", ticket, " | Error=", GetLastError());
                    }
                 }
              }
           }
        }
     }
  }


//+------------------------------------------------------------------+
//| Modify ONLY SELL orders if total Sell Basket Profit > $1         |
//+------------------------------------------------------------------+
void modifyOnlySellOrders()
  {
   UpdateOrderCacheIfNeeded();
   double basketSellProfit = g_orderCache.sellPL;

// 2. If basket profit is > $1, modify all Sell orders
   if(basketSellProfit > basketBUYorSELLProfitModifyUSD*balancelomultipler)
     {
      RefreshRates();

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
           {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber && OrderType() == OP_SELL)
              {
               int ticket       = OrderTicket();
               if(IsFLIPBasketSupportOrder(ticket, OrderComment()) || IsAnyRecoveryOrder(ticket, OrderComment()))
                  continue;
               double openPrice = OrderOpenPrice();
               double currentSL = OrderStopLoss();
               double currentTP = OrderTakeProfit();

               // Set SL based on current price (Ask)
               double minStopDist = GetRequiredStopDistance();
               double trailingBuffer = 20.0; // Raw BTC price buffer ($20.0), matching ModifyOpenOrdersToSecureProfit

               // Set SL based on current price (Ask) plus safe trailing buffer
               double newSL = Ask + trailingBuffer;
               newSL = NormalizeDouble(newSL, Digits);

               // Ensure broker stop distance is satisfied
               if(newSL - Ask < minStopDist)
                  newSL = NormalizeDouble(Ask + minStopDist, Digits);

               // CRITICAL: Only move SL DOWN to lock in profit, and ONLY once SL is below open price (guaranteeing profit)
               if(newSL < openPrice && (currentSL == 0.0 || newSL <= currentSL - MinimumSLModifyGapRaw))
                 {





                  ResetLastError();
                  bool modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrRed);

                  if(modified)
                    {
                     Print("SELL BASKET > $1 | Ticket=", ticket, " | New SL=", DoubleToString(newSL, Digits));
                    }
                  else
                    {
                     Print("FAILED TO MODIFY SELL TICKET=", ticket, " | Error=", GetLastError());
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Modify profitable orders and close losing orders                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| CloseAllOpenBuyOrders: Closes all open BUY market orders and     |
//| deletes any pending BUY stop/limit orders.                       |
//+------------------------------------------------------------------+
void CloseAllOpenBuyOrders(string reason = "")
  {
   static datetime lastBuyCloseLog = 0;
   if(TimeCurrent() - lastBuyCloseLog >= 5)
     {
      Print(">>> [BASKET CLOSE] Securing/Closing ALL open BUY orders (Reason: ", reason, ")...");
      lastBuyCloseLog = TimeCurrent();
     }
   int buyTickets[100];
   double buyLotsArr[100];
   int buyCount = 0;
   int pendingTickets[100];
   int pendingCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType == OP_BUY)
        {
         if(buyCount < 100)
           {
            buyTickets[buyCount]   = OrderTicket();
            buyLotsArr[buyCount]   = OrderLots();
            buyCount++;
           }
        }
      else if(oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
        {
         if(pendingCount < 100)
           {
            pendingTickets[pendingCount] = OrderTicket();
            pendingCount++;
           }
        }
     }

   for(int m = 0; m < buyCount; m++)
     {
      int tkt = buyTickets[m];
      double lts = buyLotsArr[m];

      if(ServerRecoveryPending || !IsConnected())
        {
         SafeOrderCloseMarket(tkt, lts, Slippage, clrRed);
         continue;
        }

      // Protect recovery orders: never close recovery orders via regular basket close
      if(IsAnyRecoveryOrder(tkt))
         continue;
      SafeOrderClose(tkt, lts, OP_BUY, Slippage, clrRed);
     }

   for(int p = 0; p < pendingCount; p++)
     {
      SafeOrderDelete(pendingTickets[p], clrYellow);
     }

   InvalidateTotalEAOrdersCache();
   InitializeFLIPBasketSupportTracking();
  }

//+------------------------------------------------------------------+
//| CloseAllOpenSellOrders: Closes all open SELL market orders and    |
//| deletes any pending SELL stop/limit orders.                      |
//+------------------------------------------------------------------+
void CloseAllOpenSellOrders(string reason = "")
  {
   static datetime lastSellCloseLog = 0;
   if(TimeCurrent() - lastSellCloseLog >= 5)
     {
      Print(">>> [BASKET CLOSE] Securing/Closing ALL open SELL orders (Reason: ", reason, ")...");
      lastSellCloseLog = TimeCurrent();
     }
   int sellTickets[100];
   double sellLotsArr[100];
   int sellCount = 0;
   int pendingTickets[100];
   int pendingCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType == OP_SELL)
        {
         if(sellCount < 100)
           {
            sellTickets[sellCount] = OrderTicket();
            sellLotsArr[sellCount] = OrderLots();
            sellCount++;
           }
        }
      else if(oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
        {
         if(pendingCount < 100)
           {
            pendingTickets[pendingCount] = OrderTicket();
            pendingCount++;
           }
        }
     }

   for(int m = 0; m < sellCount; m++)
     {
      int tkt = sellTickets[m];
      double lts = sellLotsArr[m];

      if(ServerRecoveryPending || !IsConnected())
        {
         SafeOrderCloseMarket(tkt, lts, Slippage, clrBlue);
         continue;
        }

      // Protect recovery orders: never close recovery orders via regular basket close
      if(IsAnyRecoveryOrder(tkt))
         continue;
      SafeOrderClose(tkt, lts, OP_SELL, Slippage, clrBlue);
     }

   for(int p = 0; p < pendingCount; p++)
     {
      SafeOrderDelete(pendingTickets[p], clrYellow);
     }

   InvalidateTotalEAOrdersCache();
   InitializeFLIPBasketSupportTracking();
  }

//+------------------------------------------------------------------+
//| CheckBasketProfitClose:                                          |
//| 1. If Buy basket total profit >  * multiplier (and Flip order  |
//|    is in profit >= 0 if present) -> Close all open BUY orders    |
//| 2. If Sell basket total profit >  * multiplier (and Flip order |
//|    is in profit >= 0 if present) -> Close all open SELL orders   |
//| 3. If Total Net profit (BUY + SELL) >  * multiplier ->         |
//|    Close ALL open orders (BUY and SELL)                          |
//+------------------------------------------------------------------+
void CheckBasketProfitClose()
  {
   if(!InpEnableBasketProfitClose)
      return;
   if(!EAStartupComplete)
      return;

   double targetProfit = InpBasketProfitTargetUSD * (balancelomultipler > 0 ? balancelomultipler : 1);

   double buyPL = 0.0;
   double sellPL = 0.0;
   int buyMarketCount = 0;
   int sellMarketCount = 0;
   int buySupportCount = 0;
   int sellSupportCount = 0;
   double buySupportPL = 0.0;
   double sellSupportPL = 0.0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      if(oType != OP_BUY && oType != OP_SELL)
         continue;
      // EXCLUDE RECOVERY ORDERS: Recovery orders manage their own independent basket
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      bool isSupport = IsFLIPBasketSupportOrder(OrderTicket(), OrderComment());

      if(oType == OP_BUY)
        {
         buyMarketCount++;
         buyPL += pl;
         if(isSupport)
           {
            buySupportCount++;
            buySupportPL += pl;
           }
        }
      else if(oType == OP_SELL)
        {
         sellMarketCount++;
         sellPL += pl;
         if(isSupport)
           {
            sellSupportCount++;
            sellSupportPL += pl;
           }
        }
     }

   int totalMarketOrders = buyMarketCount + sellMarketCount;
   double netPL = buyPL + sellPL;

   // 1. Overall Total Net Profit Target: If Net Profit across BUY + SELL >  * balancelomultipler -> Close ALL open orders
   if(totalMarketOrders > 0 && netPL > targetProfit)
     {
      string netReason = StringFormat("Total Net Profit Hit: $%.2f > Target $%.2f (1.0 * %d)", netPL, targetProfit, balancelomultipler);
      Print(">>> [BASKET PROFIT CLOSE - ALL] ", netReason);
      CloseAllOpenBuyOrders(netReason);
      CloseAllOpenSellOrders(netReason);
      return;
     }

   // 2. Buy Basket Target: If Buy Basket Profit >  * balancelomultipler (and if Buy Flip Support order exists, it is in profit >= 0) -> Close ALL open BUY orders
   if(buyMarketCount > 0 && buyPL > targetProfit)
     {
      bool buyFlipConditionMet = (buySupportCount == 0 || buySupportPL >= 0.0);
      if(buyFlipConditionMet)
        {
         string buyReason = StringFormat("BUY Basket Profit Hit: $%.2f > Target $%.2f (1.0 * %d) | Buy Support PL=$%.2f", buyPL, targetProfit, balancelomultipler, buySupportPL);
         Print(">>> [BASKET PROFIT CLOSE - BUY] ", buyReason);
         CloseAllOpenBuyOrders(buyReason);
        }
     }

   // 3. Sell Basket Target: If Sell Basket Profit >  * balancelomultipler (and if Sell Flip Support order exists, it is in profit >= 0) -> Close ALL open SELL orders
   if(sellMarketCount > 0 && sellPL > targetProfit)
     {
      bool sellFlipConditionMet = (sellSupportCount == 0 || sellSupportPL >= 0.0);
      if(sellFlipConditionMet)
        {
         string sellReason = StringFormat("SELL Basket Profit Hit: $%.2f > Target $%.2f (1.0 * %d) | Sell Support PL=$%.2f", sellPL, targetProfit, balancelomultipler, sellSupportPL);
         Print(">>> [BASKET PROFIT CLOSE - SELL] ", sellReason);
         CloseAllOpenSellOrders(sellReason);
        }
     }
  }

void ModifyOpenOrdersToSecureProfitNEW()
  {

   return ;
   RefreshRates();

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Current symbol only
      if(OrderSymbol() != Symbol())
         continue;

      // Current EA only
      if(OrderMagicNumber() != MagicNumber)
         continue;

      int ticket = OrderTicket();
      int type   = OrderType();

      // Only BUY / SELL
      if(type != OP_BUY && type != OP_SELL)
         continue;

      RefreshRates();

      double orderProfit = OrderProfit() + OrderSwap() + OrderCommission();

      //==============================================================
      // LOSS ORDER â†’ WIDEN SL BY $50 GAP (1-Min Cooldown)
      //==============================================================
      //==============================================================
      // LOSS ORDER â†’ WIDEN SL BY $50 GAP FROM CURRENT TICK PRICE
      //==============================================================
      if(orderProfit < 0.0)
        {
         double gapPrice =105;// 50.0*5;//ordermodifywith50
         double currentSL = OrderStopLoss();
         double newSL = 0.0;

         // 1. Calculate the distance from the current live price to the existing Stop Loss
         double distanceToSL = 0.0;
         if(type == OP_BUY)
            distanceToSL = Bid - currentSL;
         else
            if(type == OP_SELL)
               distanceToSL = currentSL - Ask;

         // 2. FILTER: If an SL is already set and its distance from the live price is $50 or less, IGNORE IT.
         // This ensures it never modifies an order that has already been adjusted to the $50 gap.
         if(currentSL != 0.0 && distanceToSL <= gapPrice+10)
           {
            continue; // Skip this order
           }

         // 3. Calculate new SL based strictly on the CURRENT LIVE TICK PRICE
         if(type == OP_BUY)
           {
            newSL = Bid - gapPrice;
           }
         else // OP_SELL
           {
            newSL = Ask + gapPrice;
           }

         newSL = NormalizeDouble(newSL, Digits);

         // 4. Modify the order
         if(MathAbs(newSL - currentSL) > Point / 2.0)
           {
            ResetLastError();
            bool modified =SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrOrange);

            if(modified)
              {
               Print("LOSS ORDER PROTECTED",
                     " | Ticket=", ticket,
                     " | Type=", type == OP_BUY ? "BUY" : "SELL",
                     " | Old SL=", DoubleToString(currentSL, Digits),
                     " | New SL=", DoubleToString(newSL, Digits),
                     " | Gap Set to $50 from Current Price");
              }
            else
              {
               Print("FAILED TO MODIFY LOSS ORDER SL",
                     " | Ticket=", ticket,
                     " | Error=", GetLastError());
              }
           }

         continue; // Move to the next order
        }

      //==============================================================
      // PROFIT ORDER â†’ MODIFY SL
      //==============================================================
      if(orderProfit > 0.0)
        {

         RefreshRates();

         double openPrice = OrderOpenPrice();
         double currentSL = OrderStopLoss();
         double currentTP = OrderTakeProfit();

         double newSL = 0.0;
         bool modify = false;

         // BUY
         if(type == OP_BUY)
           {
            newSL = Bid - (20 * Point);
            newSL = NormalizeDouble(newSL, Digits);

            // SL must secure profit
            if(newSL > openPrice)
              {
               // Only move SL forward
               if(currentSL == 0.0 || newSL > currentSL)
                  modify = true;
              }
           }

         // SELL
         else
            if(type == OP_SELL)
              {
               newSL = Ask + (20 * Point);
               newSL = NormalizeDouble(newSL, Digits);

               // SL must secure profit
               if(newSL < openPrice)
                 {
                  // Only move SL forward
                  if(currentSL == 0.0 || newSL < currentSL)
                     modify = true;
                 }
              }

         if(modify)
           {
            ResetLastError();

            bool modified =SafeOrderModify(
                              ticket,
                              openPrice,
                              newSL,
                              currentTP,
                              0,
                              type == OP_BUY ? clrGreen : clrRed
                           );

            if(modified)
              {
               Print(
                  "PROFIT ORDER SL MODIFIED",
                  " | Ticket=", ticket,
                  " | Type=", type == OP_BUY ? "BUY" : "SELL",
                  " | Profit=$", DoubleToString(orderProfit, 2),
                  " | NewSL=", DoubleToString(newSL, Digits)
               );
              }
            else
              {
               Print(
                  "FAILED TO MODIFY PROFIT ORDER",
                  " | Ticket=", ticket,
                  " | Error=", GetLastError()
               );
              }
           }
        }
     }


   ForceDeleteAllPendingOrders();

   CloseAllOrders();

  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ModifyOpenOrdersToSecureProfit()
  {
   RefreshRates();

// Raw price trailing buffer for BTCUSD (e.g., $15-$25 gives room to ride spikes)
   double trailingBufferUSD = 20.0;
   double lossRecoveryGapUSD =102;// 50.0*2;//100 // Room for losing orders to retrace

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(IsFLIPBasketSupportOrder(OrderTicket(), OrderComment()) || IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      int ticket       = OrderTicket();
      int type         = OrderType();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentTP = OrderTakeProfit();
      double netPL     = OrderProfit() + OrderSwap() + OrderCommission();

      // ==============================================================
      // 1. PROFITABLE ORDERS: Ride the spike & lock in strong profits
      // ==============================================================
      if(netPL > 0.0)
        {
         double newSL = 0.0;
         if(type == OP_BUY)
           {
            newSL = Bid - trailingBufferUSD;
            // Only move SL UP, and only once SL is above open price (guaranteeing profit)
            if(newSL > openPrice && (currentSL == 0.0 || newSL >= currentSL + MinimumSLModifyGapRaw))
               SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrGreen);
           }
         else
            if(type == OP_SELL)
              {
               newSL = Ask + trailingBufferUSD;
               // Only move SL DOWN, and only once SL is below open price
               if(newSL < openPrice && (currentSL == 0.0 || newSL <= currentSL - MinimumSLModifyGapRaw))
                  SafeOrderModify(ticket, openPrice, NormalizeDouble(newSL, Digits), currentTP, 0, clrRed);
              }
        }

      // ==============================================================
      // 2. LOSING ORDERS: Give them a chance to recover on retracement
      // ==============================================================
      else
         if(netPL < 0.0)
           {




            // Do NOT drag SL close to price! Keep the $50 safety gap so retracements can rescue the order
            double newSL = 0.0;
            if(type == OP_BUY)
               newSL = Bid - lossRecoveryGapUSD;
            else
               if(type == OP_SELL)
                  newSL = Ask + lossRecoveryGapUSD;

            newSL = NormalizeDouble(newSL, Digits);

            // Only adjust if distance is wider than $60, keeping a clean $50 breathing room
            double distToSL = (type == OP_BUY) ? (Bid - currentSL) : (currentSL - Ask);
            if(currentSL == 0.0 || distToSL > lossRecoveryGapUSD + 10.0)
              {
               SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrOrange);
              }
           }
     }
  }

//+------------------------------------------------------------------+
// Modify open orders to secure profit and keep trading active
//+------------------------------------------------------------------+
void ModifyOpenOrdersToSecureProfitOLD()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         // Ensure we only modify orders for the current chart symbol
         if(OrderSymbol() == Symbol())
           {
            int    ticket    = OrderTicket();
            int    type      = OrderType();
            double openPrice = OrderOpenPrice();
            double currentSL = OrderStopLoss();
            double currentTP = OrderTakeProfit();

            bool modified = false;
            double newSL  = 0;

            if(type == OP_BUY)
              {
               // Lock in profit by moving SL above the open price (e.g., securing a buffer below current Bid)
               newSL = Bid - (20 * Point);

               // Only update if the new SL is higher than the entry price and better than the current SL
               // if(newSL > openPrice && (currentSL == 0 || newSL > currentSL))
                 {
                  modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrGreen);
                 }
              }
            else
               if(type == OP_SELL)
                 {
                  // Lock in profit by moving SL below the open price (e.g., securing a buffer above current Ask)
                  newSL = Ask + (20 * Point);

                  // Only update if the new SL is lower than the entry price and better than the current SL
                  // if(newSL < openPrice && (currentSL == 0 || newSL < currentSL))
                    {
                     modified =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrRed);
                    }
                 }

            if(!modified && GetLastError() != 0)
              {
               Print("Failed to modify order #", ticket, ". Error: ", GetLastError());
              }
           }
        }
     }
  }
// void CheckEquityBalanceProfitTarget()
//   {
//    double accountBalance = AccountBalance();
//    double accountEquity  = AccountEquity();

//    // Check if Equity is greater than or equal to Balance + $1.00
//    if(accountEquity >= (accountBalance + (Ladder1ProfitUSD*5)))//2.00))
//      {
//       Print("Equity Target Reached! Balance: $", DoubleToString(accountBalance, 2),
//             " | Equity: $", DoubleToString(accountEquity, 2), ". Closing all open orders.");

//       // Close all open positions
//       CloseAllOrders();

//       // // Optional: Set your pause/halt flags if needed
//       // TradingHaltedUntilNextFlip = true;
//       // LadderHaltStartTime = TimeCurrent();
//      }
//   }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//| GetDynamicOrderGap: Calculates dynamic minimum price gap between |
//| same-direction orders. Adapts intelligently based on:            |
//| 1. Trend strength & EMA pullback (IsEmaWEAK)                     |
//| 2. Directional consensus (SSL vs EMA agreement)                  |
//| 3. Floating drawdown (widens grid spacing progressively on loss) |
//| 4. Signal matching (matched vs unmatched fallback)              |
//+------------------------------------------------------------------+
double GetDynamicOrderGap(int orderType)
  {
   double baseGap = (MinimumSameOrderGapRawMatched > 0.0) ? MinimumSameOrderGapRawMatched : 50.0;
   double unmatchedGap = (MinimumSameOrderGapRawUnmatched > 0.0) ? MinimumSameOrderGapRawUnmatched : 50.0;

   int sslDir = GlobalSSLDirection;
   int emaDir = EMADirection;

   // 1. Evaluate indicators alignment and risk conditions
   bool isWeak = IsEmaWEAKDistanceReduced50PercentFromPeak(orderType);
   bool isConflicted = (sslDir != 0 && emaDir != 0 && sslDir != emaDir);

   // 2. Base multiplier
   int multiplier = 1;

   // 3. Risk-based multiplier expansion
   if(isWeak)
      multiplier = MathMax(multiplier, 2);
   else if(isConflicted)
      multiplier = MathMax(multiplier, 2);

   // 4. Floating loss scaling: progressively widen gap on drawdown
   double pl = GetOpenPL(orderType);
   if(pl < 0.0)
     {
      double lossStep = 3.0 * (balancelomultipler > 0 ? balancelomultipler : 1);
      int lossMultiplier = 1 + (int)MathFloor(MathAbs(pl) / lossStep);
      lossMultiplier = MathMin(lossMultiplier, 4); // Cap to safe maximum 4X
      multiplier = MathMax(multiplier, lossMultiplier);
     }

   // 5. Check signal alignment (SSL or Chart Pattern)
   bool sslMatches = ((orderType == OP_BUY && sslDir == 1) || (orderType == OP_SELL && sslDir == -1));
   if(sslMatches)
      return baseGap * multiplier;

   // Lazy evaluation of pattern direction only if SSL is not matching
   int patternDir = GetCachedPatternDirection();
   bool patternMatches = ((orderType == OP_BUY && patternDir == 1) || (orderType == OP_SELL && patternDir == -1));
   if(patternMatches)
      return baseGap * multiplier;

   // 6. Unmatched / Counter-trend fallback
   return MathMax(unmatchedGap, baseGap * multiplier);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int balancelomultipler=1;//
double profitAfterFlip = 0;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChangeLots(double OpenPL, string reason, int orderType, int stoplevelStep,string MOMorder="")
  {
   double MaxRecoveryLot =0.05;//0.10;// 0.05;
   double oppositeLots = GetOppositeOrdersLots(orderType);
   bool isSSLSignal = (reason == "SSL Long" || reason == "SSL Short");
   bool isSSLProfitReEntry = (reason == "SSL Profit ReEntry Buy Stop" || reason == "SSL Profit ReEntry Sell Stop");





// if(profitAfterFlip > 20)
//   {
//    MaxRecoveryLot = 0.01;
//   }
// else
//    if(profitAfterFlip > 10)
//      {
//       MaxRecoveryLot = 0.03;
//      }
   /*
      if(isSSLSignal)
        {
         Lots = GetMarketMomentLot(orderType);
         if(GlobalSSLDirection == EMADirection || GlobalBUYSELLdashboardScore==4)
            Lots=0.02;
         else
            Lots=0.01;
         if(GlobalSSLDirection == EMADirection)
            Lots=0.02;

         double emaAngle = GlobalEmaAngle30;
         double emaDistance = GetDistanceToEMAPrice(orderType, true);
         if(orderType == OP_BUY)
           {
            if(emaAngle < 1.0)
               Lots = 0.01;
            else
               if(emaDistance < 100.0 && emaAngle < 1.0)
                  Lots = 0.01;
           }
         else
            if(orderType == OP_SELL)
              {
               if(emaAngle > -1.0)
                  Lots = 0.01;
               else
                  if(emaDistance < 100.0 && emaAngle > -1.0)
                     Lots = 0.01;
              }

         double buyPL  = GlobalBuyPL;
         double sellPL = GlobalSellPL;
         double currentAngle = GlobalEmaAngle30;

         if(orderType == OP_BUY && EMADirection == 1 && sellPL <= -10.0)
           {
            if(sellPL <= -10.0 && currentAngle > 1.0)
               Lots = 0.10;
            else
               if(sellPL <= -5.0 && currentAngle > 1.0)
                  Lots = 0.05;
               else
                  Lots = 0.03;
           }
         else
            if(orderType == OP_SELL && EMADirection == -1 && buyPL <= -10.0)
              {
               if(buyPL <= -20.0 && currentAngle < -3.0)
                  Lots = 0.10;
               else
                  if(buyPL <= -10.0 && currentAngle < -3.0)
                     Lots = 0.05;
                  else
                     Lots = 0.03;
              }
        }
      else
         if(isSSLProfitReEntry && MathAbs(  GlobalEmaAngle30)>3)
           {
            Lots = 0.03;
            if(GlobalSSLDirection == EMADirection)
              {
               Lots = CalculateDecreaseLots(reEntryCounter, 0.04, 0.01);
               if(CheckFastProfitableRecentOrders())
                  Lots = 0.02;
              }
            else
              {
               Lots = CalculateIncreaseLots(reEntryCounter, 0.01, 0.04);
               if(CheckFastProfitableRecentOrders() && Lots<0.03)
                  Lots = 0.02;
              }
           }

      if(orderType == OP_BUY && GlobalVShapeBuy)
         Lots = 0.02;
      else
         if(orderType == OP_SELL && GlobalVShapeSell)
            Lots = 0.02;

      if(IsHeavyLotOrderNearBy(orderType, Lots, 300) && Lots>=0.03)
         Lots = 0.01;

      double currentEmaAngle = GlobalEmaAngle30;
      // if(InpEnableEmaAngleFilter)
      //   {
      //    if((orderType == OP_BUY && currentEmaAngle <= InpMinEmaAngleDegrees) ||
      //       (orderType == OP_SELL && currentEmaAngle >= -InpMinEmaAngleDegrees))
      //      {
      //       Lots = 0.01;
      //      }
      //   }

      if(MathAbs(InpEnableEmaAngleFilter)<3)
      {
         Lots = 0.01;

      }

      if(IsExtremePriceOrder(orderType, Lots,0.02))
        {
         Lots = 0.01;
         Print("LOT CAP APPLIED: New order is the extreme (Highest Buy / Lowest Sell). Lot reduced to 0.02");
        }

        */


   /*

   if (angleAbs > 9)
   {
      // Define behavior for very steep angles (e.g., cap at a specific lot or keep minimum)
      Lots = 0.01;
   }
   else if (angleAbs > 3)
   {
      // Scale lots based on angle magnitude between 3 and 9
      Lots = 0.01 * MathRound(angleAbs);
   }
   else
   {
      // Default fallback for angles <= 3
      Lots = 0.01;
   }
   */

   /*
   double angleAbs = MathAbs(GlobalEmaAngle30);
   Lots = 0.01; // Default fallback

   if(orderType == OP_BUY && GlobalEmaAngle30 > 1.0)
     {
      Lots = 0.01 * (5 - MathRound(angleAbs));
     }
   else
      if(orderType == OP_SELL && GlobalEmaAngle30 < -1.0)
        {
         Lots = 0.01 * (5 - MathRound(angleAbs));
        }

   // CRITICAL SAFETY CATCH: Prevent 0 or negative lots during extreme trends
   if(Lots < 0.01)
     {
      Lots = 0.01;
     }
   if(IsStrongMomentum(orderType) && Lots<0.04)
     {
      Lots = 0.04;

     }

     */

//---------------------------------FINAL ----------------------------

   int closedCount = GetClosedOrdersCountSinceEmaFlip();

// The modulo (%) returns the remainder, creating a repeating cycle of 0, 1, 2, 3, 4
   int cycleStep = closedCount % 5;

// Subtract the cycle step from 5 to get the repeating 5-to-1 countdown
   Lots = 0.01 * (5 - cycleStep);
// Lots = 0.01 * (10 - cycleStep);

// if(Lots==0.01)
   Lots=0.01;//MaxRecoveryLot;

// Lots=0.05;//
// Print("Closed Orders Since EMA Flip: ", closedCount, " | Cycle Step: ", cycleStep, " | Calculated Lots: ", Lots);

// if((GlobalEmaAngle30 > -3.0 && GlobalEmaAngle30 < 3.0))
//   {
//    Lots = 0.01;

//   }

// if(GlobalSSLDirection != EMADirection)
//   {
//    Lots = 0.01;


//   }

// if(MathAbs(GlobalEmaAngle30)<2)
//   {
//    Lots = 0.01;
//   }

//   if(GetH1Direction() != EMADirection)
//   {
//    Lots = 0.01;


//   }
// if(GetOpenPL(OP_SELL)<0 && intOrdertype == -1)
//   {
//    Lots = 0.01;


//   }
   if(GlobalSSLDirection != EMADirection)
     {
      //  Lots = 0.02;


     }



// if((GlobalEmaAngle30>10 || GlobalEmaAngle30<-10) &&  GlobalSSLDirection != EMADirection)
//   {
//    Lots = 0.01;


//   }



// double emaDistance = GetDistanceToEMAPrice(orderType, true);


// if(emaDistance < 50  )
//    Lots = 0.01;



// ===== NEW RULE: CAPP LOTS TO 0.02 IF EQUITY PROFIT > $10 AFTER FLIP =====
// double realizedProfitAfterFlip = 0.0;
// if(EmaFlipTime > 0)
//   {
//    for(int h = OrdersHistoryTotal() - 1; h >= 0; h--)
//      {
//       if(OrderSelect(h, SELECT_BY_POS, MODE_HISTORY))
//         {
//          if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
//            {
//             if(OrderCloseTime() >= EmaFlipTime)
//                realizedProfitAfterFlip += (OrderProfit() + OrderSwap() + OrderCommission());
//            }
//         }
//      }
//   }
// double equityProfitAfterFlip = realizedProfitAfterFlip + GetEAFloatingPL();

// if(equityProfitAfterFlip > 10.0 && Lots >= 0.02)
//   {
//    Lots = 0.01;
//   }

// if(GetCurrentM30Direction() != EMADirection && Lots >= 0.03)
//   {
//    Lots = 0.01;
//   }

// --- PREVIOUS 2 M1 CANDLES BODY HEIGHT FILTER (Each > 100 raw price difference) ---
// if(MathAbs(Open[1] - Close[1]) > 100.0 && MathAbs(Open[2] - Close[2]) > 100.0)
//   {
//    Lots = 0.01;
//   }

// if(HasAnyLargeCandle(Symbol(), PERIOD_M1, 30, 300.0, false))
//    Lots = 0.01;
// if(GlobalEmaAngle30<2 &&  GlobalEmaAngle30 > -2)
//      Lots = 0.01;



// if( && GlobalEmaAngle30<2 && orderType==1)

// if(IsAbsolutePriceDifferenceExceeded(5,200))
// {
// Lots = 0.01;

// }

// Lots=0.05;//


// Lots=Lots*2;

   if(Lots==0.02)
     {
      // Lots = 0.04;

     }

   double buyLots  = GetTotalLots(OP_BUY);
   double sellLots = GetTotalLots(OP_SELL);

   int requestedDirection = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? 1 : -1;


// if(requestedDirection==1 && GetOpenPL(OP_BUY)<=-5)
//   {
//    Lots = 0.01;

//   }
// if(requestedDirection==-1 && GetOpenPL(OP_SELL)<=-5)

//   {
//    Lots = 0.01;

//   }



















   if(IsEmaWEAKDistanceReduced50PercentFromPeak(orderType) && GlobalSSLDirection == EMADirection)//weak
     {
      Lots = 0.01;

     }


   if(IsLsdSweepGreenLinePresent() && GlobalSSLDirection==-1)
     {
      Lots = 0.01;
     }


   if(IsLsdSweepRedLinePresent() && GlobalSSLDirection==1)
     {
      Lots = 0.01;
     }

//

   /*

      if(GlobalSweepBuy &&   GlobalSSLDirection == -1)
         Lots = 0.01;

      if(GlobalSweepSell &&   GlobalSSLDirection == 1)
         Lots = 0.01;
   */

   if(IsLsdSweepGreenLinePresent() && GlobalSSLDirection==1 && (GetLsdSweepEqlDistance(requestedDirection)<100 ||EMADirection==-1))
     {
      Lots = 0.03;
     }


   if(IsLsdSweepRedLinePresent() && GlobalSSLDirection==-1 && (GetLsdSweepEqlDistance(requestedDirection)<100 ||EMADirection==1))
     {
      Lots = 0.03;
     }



   if(!IsEmaWEAKDistanceReduced50PercentFromPeak(orderType) && GlobalSSLDirection != EMADirection)//weak
     {
      Lots = 0.01;

     }


   /*

    if(IsLsdSweepGreenLinePresent() && GlobalSSLDirection==1)
   {
   Lots = 0.05;
   }


   if(IsLsdSweepRedLinePresent() && GlobalSSLDirection==-1)
   {
   Lots = 0.05;
   }
   */

//if(EMAflipdistance()<200 || TimeCurrent() - EmaFlipTime < 60 * 60)
// Lots = 0.01;



   if(isMOMOrder==true)
     {
      //  Lots = 0.03;

     }
   if(MOMorder=="MOM_BUY" && (EMADirection==1 && !IsEmaWEAKDistanceReduced50PercentFromPeak(orderType)))
     {

      Lots = 0.02;
     }



   if(MOMorder=="MOM_SELL" && (EMADirection==-1 && !IsEmaWEAKDistanceReduced50PercentFromPeak(orderType)))
     {

      Lots = 0.02;
     }

//oppsite direction

   if(MOMorder=="MOM_BUY" && (EMADirection==-1 && IsEmaWEAKDistanceReduced50PercentFromPeak(orderType)))
     {

      Lots = 0.02;
     }



   if(MOMorder=="MOM_SELL" && (EMADirection==1 && IsEmaWEAKDistanceReduced50PercentFromPeak(orderType)))
     {

      Lots = 0.02;
     }

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
     {



      if(GlobalSSLDirection != EMADirection)
         Lots = 0.04;

      else
         Lots = 0.01;

     }


   /*
   if(MathAbs( GetPriceDifference(15)>200))
   {

   if(IsEmaWEAKDistanceReduced50PercentFromPeak)
   {



   if(GlobalSSLDirection != EMADirection)
   Lots = 0.04;

   else
   Lots = 0.01;


   }



   }
   */


   if(!IsEmaWEAKDistanceReduced50PercentFromPeak(orderType) && Lots==0.01 && EMADirection==1 &&  GetOpenPL(OP_BUY)<=-20)
      Lots = 0.02;

   if(!IsEmaWEAKDistanceReduced50PercentFromPeak(orderType) && Lots==0.01 && EMADirection==-1 &&  GetOpenPL(OP_SELL)<=-20)
      Lots = 0.02;


   if(CountOrdersByType(orderType)<=2 && Lots==0.01)
      Lots = 0.02;
      
      
        //if(IsEmaWEAKDistanceReduced50PercentFromPeak(orderType) &&   EMADirection==requestedDirection)
      //Lots = 0.01;

   //if(IsEmaWEAKDistanceReduced50PercentFromPeak(orderType)   && EMADirection==requestedDirection)
     // Lots = 0.01;




   if(IsHeavyLotOrderNearBy(orderType, Lots, 300) && Lots>=0.02)
      Lots = 0.01;
//----------------------------------------------------------------------------------------
// Safety catch


   if(Lots < 0.01)
     {
      Lots = 0.01;
     }


// Check if EMA angle magnitude is greater than 1 degree
// if(MathAbs(GlobalEmaAngle30) > 1.0)
//   {
//    int requestedDirection = (orderType == OP_BUY) ? 1 : -1;
//    int emaTrendDirection  = (GlobalEmaAngle30 > 0) ? 1 : -1;

//    // If the EMA trend direction disagrees with the requested order direction, lock lot size to 0.01
//    if(emaTrendDirection != requestedDirection)
//      {
//       Lots = 0.01;
//      }
//   }

//   if(IsStrongMomentum(orderType))
//   {
//    Lots = 0.04;

//   }
//*************************************final*****************************************************************

   if(Lots < 0.01)
      Lots = 0.01;

   datetime dubaiTime = TimeCurrent() + (ServerToDubaiOffsetHours * 3600);
   int currentHour = TimeHour(dubaiTime);

   double effectiveMaxLot = MathMax(MaxRecoveryLot, (InpEnableLsdSweepLotAdjustment && GetLsdSweepSignal() != 0) ? InpLsdSweepLotSize : MaxRecoveryLot);
   if(Lots > effectiveMaxLot)
      Lots = effectiveMaxLot;

   int lotMultiplierDiv = (AccountMultiplierLOT > 0) ? AccountMultiplierLOT : 500;
   balancelomultipler = (int)(AccountBalance() / lotMultiplierDiv);
   if(balancelomultipler < 1)
      balancelomultipler = 1;
   Lots = Lots * balancelomultipler;

   Lots = NormalizeLots(Lots);




   StopLossUSD = OriginalStopLossUSD * Lots * 100;

// if(Lots==0.05 || Lots==0.04  ||   (TimeCurrent() - EmaFlipTime > 60*60))
// {
// StopLossUSD = 2 * Lots * 100;

// }

// if(HasAnyLargeCandle(Symbol(), PERIOD_M1, 30, 200.0, false))
//    StopLossUSD = 1 * Lots * 200;

// Corrected directional comparison for StopLossUSD assignment
// int requestedDirection = (orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT) ? 1 : -1;
// if(EMADirection != requestedDirection)
//   {
//    StopLossUSD = OriginalLadder1ProfitUSD/2 * Lots * 100;
//   }



// int StopLossUSDA=10-  MathRound(MathAbs(GlobalEmaAngle30));
// if(StopLossUSDA<2)
//   {
//    StopLossUSDA=2;
//   }
// StopLossUSD = StopLossUSDA * Lots * 100;

// StopLossUSD = OriginalStopLossUSD * Lots * 100;
   Ladder1ProfitUSD = OriginalLadder1ProfitUSD * Lots * 100;
   Ladder2ProfitUSD = OriginalLadder2ProfitUSD * Lots * 100;
   Ladder1StopMaxPriceUSD = OriginalLadder1StopMaxPriceUSD * Lots * 100;


  }

//+------------------------------------------------------------------+
//| Check if absolute price difference exceeds threshold in timeframe|
//+------------------------------------------------------------------+
bool IsAbsolutePriceDifferenceExceeded(int minutes, double threshold)
  {
// Assuming an M1 chart, 1 minute = 1 bar.
// If your EA runs on M5, M15, etc., you can adjust the multiplier accordingly,
// but assuming M1 execution:
   int barsToCheck = minutes;

   if(Bars < barsToCheck || barsToCheck <= 0)
      return false;

   double highestPrice = High[0];
   double lowestPrice  = Low[0];

// Scan the historical bars within the specified minute window
   for(int i = 1; i < barsToCheck; i++)
     {
      if(High[i] > highestPrice)
         highestPrice = High[i];
      if(Low[i] < lowestPrice)
         lowestPrice  = Low[i];
     }

// Absolute distance between the ceiling and floor within the time window
   double absoluteDifference = highestPrice - lowestPrice;

// Returns true if the absolute range exceeds the user-defined threshold
   if(absoluteDifference > threshold)
     {
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsExtremePriceOrder(int orderType, double requestedLot,double maxLot)
  {
   if(requestedLot < maxLot)
      return false;

   bool isExtreme = true;
   bool hasExistingOrders = false;
   RefreshRates();

   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != orderType)
         continue;

      hasExistingOrders = true;

      if(orderType == OP_BUY && OrderOpenPrice() >= currentPrice)
         isExtreme = false;
      if(orderType == OP_SELL && OrderOpenPrice() <= currentPrice)
         isExtreme = false;
     }
   return (hasExistingOrders && isExtreme);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountActiveRecoveryOrders()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         count++;
     }
   return count;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckRecoveryOrders()
  {
   if(!EnableRecoveryOrders || GetTotalEAOrders() >= MaxOpenOrders || !IsOneCandleOrderAllowed())
      return;
   if(CountActiveRecoveryOrders() >= 1)
      return;

   if(!IsEmaWEAKDistanceReduced50PercentFromPeak() && GlobalSSLDirection != 1 && EMADirection)
     {
      return;

     }

   double emaAngle = GlobalEmaAngle30;

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

      // if(InpEnableEmaAngleFilter)
      //   {
      //    if(parentType == OP_BUY && emaAngle <= InpMinEmaAngleDegrees)
      //       continue;
      //    if(parentType == OP_SELL && emaAngle >= -InpMinEmaAngleDegrees)
      //       continue;
      //   }

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

      double parentLots = OrderLots();
      double currentProfitUSD = OrderProfit() + OrderSwap() + OrderCommission();

      double dynamicRecoveryLossLimit = -MathAbs(RecoveryTriggerLossUSD * parentLots * 100.0);
      if(currentProfitUSD > dynamicRecoveryLossLimit)
         continue;

      double newExecutionPrice = (parentType == OP_BUY) ? Ask : Bid;
      double adverseDistance = (parentType == OP_BUY) ? (OrderOpenPrice() - newExecutionPrice) : (newExecutionPrice - OrderOpenPrice());

      // if(parentType == OP_BUY  && EMADirection == 1)// && GlobalSSLDirection == 1 && emaAngle > 5.0)
      //   {
      //    if(adverseDistance < (RecoveryMinDistanceRaw / 2.0))
      //       continue;
      //   }
      // else
      //    if(parentType == OP_SELL && EMADirection == -1)// && GlobalSSLDirection == -1  && emaAngle < -5.0)
      //      {
      //       if(adverseDistance < (RecoveryMinDistanceRaw / 2.0))
      //          continue;
      //      }
      //    else
        {
         if(adverseDistance < RecoveryMinDistanceRaw)
            continue;
        }

      if(parentType == OP_BUY && GlobalSSLDirection != 1 && EMADirection != 1)
         continue;
      if(parentType == OP_SELL && GlobalSSLDirection != -1 && EMADirection != -1)
         continue;

      double recoveryLots = NormalizeLots(parentLots * RecoveryLotMultiplier);
      if(recoveryLots <= 0)
         continue;

      StopLossUSD=OriginalStopLossUSD;

      int recoveryTicket = -1;
      double slDistance = (RecoveryStopLossDistanceRaw > 0.0) ? RecoveryStopLossDistanceRaw : ((RecoveryStopLossRaw > 0.0) ? RecoveryStopLossRaw : 200.0);
      double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;

      double recoverySL = 0.0;
      double recoveryTP = 0.0;

      if(parentType == OP_BUY)
        {
         recoverySL = (slDistance > 0) ? NormalizeDouble(Ask - slDistance, Digits) : 0;
         recoveryTP = (tpDistance > 0) ? NormalizeDouble(Ask + tpDistance, Digits) : 0;
         recoveryTicket = SafeOrderSend(Symbol(), OP_BUY, recoveryLots, Ask, Slippage, recoverySL, recoveryTP, "RECOVERY_" + IntegerToString(parentTicket), MagicNumber, clrAqua);
        }
      else
        {
         recoverySL = (slDistance > 0) ? NormalizeDouble(Bid + slDistance, Digits) : 0;
         recoveryTP = (tpDistance > 0) ? NormalizeDouble(Bid - tpDistance, Digits) : 0;
         recoveryTicket = SafeOrderSend(Symbol(), OP_SELL, recoveryLots, Bid, Slippage, recoverySL, recoveryTP, "RECOVERY_" + IntegerToString(parentTicket), MagicNumber, clrOrange);
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

   if(!IsEmaWEAKDistanceReduced50PercentFromPeak() && GlobalSSLDirection != 1 && EMADirection)
     {
      return;

     }

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      string comment = OrderComment();
      if(StringFind(comment, "RECOVERY_") != 0)
         continue;

      int recoveryTicket = OrderTicket();
      double recoveryLots = OrderLots();
      int recoveryType = OrderType();
      double recoveryProfit = OrderProfit() + OrderSwap() + OrderCommission();

      int parentTicket = (int)StringToInteger(StringSubstr(comment, 9));

      bool parentFound = false;
      double parentLots = 0.0;
      int parentType = -1;
      double parentProfit = 0.0;

      for(int j = OrdersTotal() - 1; j >= 0; j--)
        {
         if(!OrderSelect(j, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderTicket() == parentTicket)
           {
            parentFound = true;
            parentLots = OrderLots();
            parentType = OrderType();
            parentProfit = OrderProfit() + OrderSwap() + OrderCommission();
            break;
           }
        }

      if(!parentFound)
         continue;

      double basketProfit = recoveryProfit + parentProfit;

      if(basketProfit >= RecoveryBasketProfitUSD) //*(OrderLots() / 0.01))
        {
         SafeOrderClose(recoveryTicket, recoveryLots, recoveryType, Slippage, (recoveryType == OP_BUY ? clrRed : clrBlue));
         SafeOrderClose(parentTicket, parentLots, parentType, Slippage, (parentType == OP_BUY ? clrRed : clrBlue));
         break;
        }
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool HasRecoveryOrder(int ParentTicket)
  {
   int currentSelectedTicket = OrderTicket();
   string targetComment = "RECOVERY_" + IntegerToString(ParentTicket);
   bool found = false;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderMagicNumber() != MagicNumber)
         continue;
      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;
      if(OrderSymbol() != Symbol())
         continue;
      if(StringFind(OrderComment(), targetComment) == 0)
        {
         found = true;
         break;
        }
     }
   if(currentSelectedTicket > 0)
      OrderSelect(currentSelectedTicket, SELECT_BY_TICKET, MODE_TRADES);
   return found;
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
void SaveDayProfitLadderState() { return; }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime GetOldestOpenOrderTime()
  {
   datetime oldestTime = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
           {
            int type = OrderType();
            if(type == OP_BUY || type == OP_SELL)
              {
               if(oldestTime == 0 || OrderOpenTime() < oldestTime)
                  oldestTime = OrderOpenTime();
              }
           }
        }
     }
   return oldestTime;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDayProfitLadderTarget(int stage)
  {
   if(stage <= 0 || DayProfitLadderStartBalance <= 0.0)
      return DayProfitLadderStartBalance;

   double step1 = MathAbs(DayProfitLadder1Percent) / 100.0;
   double step2 = MathAbs(DayProfitLadder2Percent) / 100.0;

   double target1 = DayProfitLadderStartBalance * (1.0 + step1);
   if(stage == 1)
      return target1;

   double subsequentStepAmount = target1 * step2;
   return target1 + (subsequentStepAmount * (stage - 1));
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetDayProfitLadderProtection(int stage)
  {
   if(DayProfitLadderStartBalance <= 0.0)
      return 0.0;
   if(stage <= 0)
      return DayProfitLadderStartBalance * (DayProfitInitialProtectionPercent / 100.0);
   double currentTarget = GetDayProfitLadderTarget(stage);
   double lockRatio = (100.0 - DayProfitLadderLockRatio) / 100.0;
   return currentTarget * lockRatio;
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
//| Close and delete orders whose direction does not match EMADirection|
//+------------------------------------------------------------------+
void CloseAndDeleteNonEmaMatchingOrders()
  {
   int nonMatchingPendingTickets[1000];
   int nonMatchingPendingCount = 0;

   int nonMatchingOpenTickets[1000];
   int nonMatchingOpenCount = 0;

// 1. Scan and filter open and pending orders
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      bool isPending = (type == OP_BUYSTOP || type == OP_SELLSTOP || type == OP_BUYLIMIT || type == OP_SELLLIMIT);
      bool isMarket  = (type == OP_BUY || type == OP_SELL);

      if(isMarket)
        {
         bool isBuy = (type == OP_BUY);
         // Check if market order direction matches EMADirection (Buy needs EMADirection == 1, Sell needs EMADirection == -1)
         bool matchesEma = (isBuy && EMADirection == 1) || (!isBuy && EMADirection == -1);

         if(!matchesEma && nonMatchingOpenCount < 1000)
           {
            nonMatchingOpenTickets[nonMatchingOpenCount++] = OrderTicket();
           }
        }
      else
         if(isPending)
           {
            bool isBuyPending = (type == OP_BUYSTOP || type == OP_BUYLIMIT);
            bool matchesEma = (isBuyPending && EMADirection == 1) || (!isBuyPending && EMADirection == -1);

            if(!matchesEma && nonMatchingPendingCount < 1000)
              {
               nonMatchingPendingTickets[nonMatchingPendingCount++] = OrderTicket();
              }
           }
     }

// 2. Close non-matching open market orders
   for(int k = 0; k < nonMatchingOpenCount; k++)
     {
      int ticket = nonMatchingOpenTickets[k];
      if(!OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int type = OrderType();
      if(type != OP_BUY && type != OP_SELL)
         continue;

      double lots = OrderLots();
      SafeOrderClose(ticket, lots, type, Slippage, (type == OP_BUY ? clrRed : clrBlue));
     }

// 3. Delete non-matching pending orders
   for(int p = 0; p < nonMatchingPendingCount; p++)
     {
      int pendingTicket = nonMatchingPendingTickets[p];
      if(!OrderSelect(pendingTicket, SELECT_BY_TICKET, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      SafeOrderDelete(pendingTicket, clrRed);
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAndDeleteAllEAOrdersOnTradingStop()
  {

   Print("CloseAndDeleteAllEAOrdersOnTradingStop");
   ModifyOpenOrdersToSecureProfit();

   return ;

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
   if(InpEnableCustomRules && !PassesUserRules(direction == OP_BUY ? OP_BUY : OP_SELL))
      return false;
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
   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;

   double stopLoss=(direction==OP_BUY) ? (entryPrice-slDistance) : (entryPrice+slDistance);
   stopLoss=NormalizeDouble(stopLoss,Digits);
   double takeProfit = (direction == OP_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
   takeProfit = NormalizeDouble(takeProfit, Digits);
   string comment=(direction==OP_BUY) ? "Day Ladder Buy Stop" : "Day Ladder Sell Stop";
   color orderColor=(direction==OP_BUY) ? BuyColor : SellColor;
   int ticket=SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, takeProfit, comment, MagicNumber, orderColor);
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

   double equity = AccountEquity();
   double balance = AccountBalance();

   datetime oldestOrderTime = GetOldestOpenOrderTime();
   if(oldestOrderTime > 0)
     {
      int openDurationSeconds = (int)(TimeCurrent() - oldestOrderTime);
      if(openDurationSeconds >= 7200)
        {
         double previousTarget = (DayProfitLadderStage == 0) ? DayProfitLadderStartBalance : GetDayProfitLadderTarget(DayProfitLadderStage);
         double nextTarget = GetDayProfitLadderTarget(DayProfitLadderStage + 1);
         double requiredLegProfit = nextTarget - previousTarget;
         double halfTargetEquity = previousTarget + (requiredLegProfit * 0.5);

         if(equity >= halfTargetEquity)
           {
            Print("TACTICAL EXIT: 2 Hours elapsed & 50% of leg target reached ($", DoubleToString(equity, 2), "). Closing stale orders.");
            // CloseAndDeleteAllEAOrdersOnTradingStop();
            return;
           }
        }
     }

   if(DayProfitLadderStage > 0)
     {
      double targetEquity = GetDayProfitLadderTarget(DayProfitLadderStage);
      double targetProfit = targetEquity - DayProfitLadderStartBalance;

      if(targetProfit > 0)
        {
         double lockedProfitAmount = targetProfit * (PeakProfitLockPercent / 100.0);
         double dynamicEquityFloor = DayProfitLadderStartBalance + lockedProfitAmount;

         if(AccountEquity() <= dynamicEquityFloor)
           {
            Print("Target Profit Lock Hit! Stage: ", DayProfitLadderStage, " | Target: $", targetEquity, " | Equity dropped below $", dynamicEquityFloor, ". Flattening trades.");
            CloseAndDeleteAllEAOrdersOnTradingStop();
            InitializeDayProfitLadder();
            return;
           }
        }
     }

   datetime today = GetDayProfitLadderDate();
   if(!DayProfitLadderInitialized)
     {
      InitializeDayProfitLadder();
      return;
     }

   if(DayProfitLadderDate != today)
     {
      if(GetEAFloatingPL() >= 0.0)
        {
         InitializeDayProfitLadder();
         return;
        }
     }

   if(DayProfitLadderTradingStopped)
     {
      CloseAndDeleteAllEAOrdersOnTradingStop();
      return;
     }

   if(DayProfitLadderStartBalance <= 0.0)
      return;

   int checkStage = DayProfitLadderStage + 1;
   while(equity >= GetDayProfitLadderTarget(checkStage))
     {
      checkStage++;
     }

   int reachedStage = checkStage - 1;
   if(reachedStage > DayProfitLadderStage)
     {
      DayProfitLadderStage = reachedStage;
      DayProfitLadderTargetReachedCandle = Time[0];
      DayProfitLadderResumeDirection = GlobalSSLDirection;
      if(DayProfitLadderResumeDirection == 0)
         DayProfitLadderResumeDirection = LastLiveSSLDirection;
      DayProfitLadderTargetCleanupPending = true;
      DayProfitLadderResumePending = (DayProfitLadderResumeDirection != 0);

      DayProfitLadderProtectionEquity = GetDayProfitLadderProtection(DayProfitLadderStage);
      DayProfitLadderNextTargetEquity = GetDayProfitLadderTarget(DayProfitLadderStage + 1);
      SaveDayProfitLadderState();
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

   int currentDirection = GlobalSSLDirection;
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

      // FIXED: EMA Direction must be opposite (-1 for OP_BUY, 1 for OP_SELL)
      bool deleteOrder = ((newSignalType == OP_BUY && orderType == OP_SELLSTOP && EMADirection == -1) ||
                          (newSignalType == OP_SELL && orderType == OP_BUYSTOP && EMADirection == 1));

      if(deleteOrder)
         SafeOrderDelete(OrderTicket(), clrYellow);
     }
  }
//+------------------------------------------------------------------+
//| Close opposite profitable orders on SSL signal + EMA condition   |
//+------------------------------------------------------------------+
void CloseOppositeProfitableOrdersOnSignal(int newSignalType)
  {
   if(!EAStartupComplete)
      return;

   RefreshRates();

// 1. Calculate current EMA and local direction
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   int localEmaDirection = 0;

   if(ema > 0)
     {
      if(Bid > ema)
         localEmaDirection = 1;      // Bullish EMA
      else
         if(Bid < ema)
            localEmaDirection = -1;   // Bearish EMA
     }

// 2. Loop through open orders
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

      // Calculate profit threshold: $0.25 per 0.01 lot step
      double profitThreshold = 0.25 * (lots / 0.01);

      // Check if the order is opposite to the incoming signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // SCENARIO A: Sell order is open, EMA is Bullish (1), new signal is Buy
         bool isSellOpenBullishEma = (orderType == OP_SELL && localEmaDirection == 1 && newSignalType == OP_BUY);

         // SCENARIO B: Buy order is open, EMA is Bearish (-1), new signal is Sell
         bool isBuyOpenBearishEma  = (orderType == OP_BUY && localEmaDirection == -1 && newSignalType == OP_SELL);

         // If either conflicting condition matches and the order has crossed the profit threshold
         if((isSellOpenBullishEma || isBuyOpenBearishEma) && orderPL >= profitThreshold)
           {
            Print("PROFITABLE OPPOSITE CLOSE: Ticket #", ticket, " | Type: ", GetOrderTypeText(orderType),
                  " | Profit: $", DoubleToString(orderPL, 2), " | Reaching threshold ($", DoubleToString(profitThreshold, 2), ")");

            SafeOrderClose(ticket, lots, orderType, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrders(int newSignalType)
  {
   if(!EAStartupComplete)
      return;
   RefreshRates();

// 1. Calculate EMA and True Direction instantly on this exact tick
   double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   int localEmaDirection = 0;

   if(ema > 0)
     {
      if(Bid > ema)
         localEmaDirection = 1;
      else
         if(Bid < ema)
            localEmaDirection = -1;
     }

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
      double profitThreshold = 0.25 * (lots / 0.01);

      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // 2. Use localEmaDirection for absolute precision
         bool emaMatchesOrder = ((orderType == OP_BUY && localEmaDirection == 1) ||
                                 (orderType == OP_SELL && localEmaDirection == -1));

         bool emaMatchesSignal = ((newSignalType == OP_BUY && localEmaDirection == 1) ||
                                  (newSignalType == OP_SELL && localEmaDirection == -1));

         if(emaMatchesOrder)
           {
            // Instead of closing, lock the SL at the profit threshold
            if(orderPL > profitThreshold)
              {
               double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
               double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);

               if(tickValue > 0 && tickSize > 0)
                 {
                  // Convert USD profit threshold into raw price distance
                  double lockDistance = (profitThreshold / (tickValue * lots)) * tickSize;
                  double newSL = 0.0;

                  if(orderType == OP_BUY)
                    {
                     newSL = NormalizeDouble(OrderOpenPrice() + lockDistance, Digits);
                     // Only modify if the current SL is lower than the new SL or doesn't exist
                     if(OrderStopLoss() == 0 || newSL > OrderStopLoss())
                       {
                        Print("OPPOSITE SIGNAL: Locking Buy profit at threshold SL.");
                        SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrLimeGreen);
                       }
                    }
                  else
                     if(orderType == OP_SELL)
                       {
                        newSL = NormalizeDouble(OrderOpenPrice() - lockDistance, Digits);
                        // Only modify if the current SL is higher than the new SL or doesn't exist
                        if(OrderStopLoss() == 0 || newSL < OrderStopLoss())
                          {
                           Print("OPPOSITE SIGNAL: Locking Sell profit at threshold SL.");
                           SafeOrderModify(ticket, OrderOpenPrice(), newSL, OrderTakeProfit(), 0, clrTomato);
                          }
                       }
                 }
              }
           }
         else
            if(emaMatchesSignal)
              {
               // Close immediately if distance > 100
               double currentPrice = (orderType == OP_BUY) ? Bid : Ask;
               double distanceToEma = MathAbs(currentPrice - ema);

               if(distanceToEma > 100.0)
                 {
                  Print("CLOSE EXECUTED: Fighting EMA & SSL + Distance > 100.");
                  SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetOrderDirection(int orderType)
  {
   if(orderType == OP_BUY || orderType == OP_BUYSTOP || orderType == OP_BUYLIMIT)
      return 1;
   if(orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT)
      return -1;
   return 0;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersold2(int newSignalType)
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
      double profitThreshold = 0.25 * (lots / 0.01);

      // 1. Check if the order is opposite to the new SSL signal
      bool isOppositeSignal = ((newSignalType == OP_BUY && orderType == OP_SELL) ||
                               (newSignalType == OP_SELL && orderType == OP_BUY));

      if(isOppositeSignal)
        {
         // 2. ONLY close if it has reached the profit threshold.
         // If it is below the threshold, it is ignored and left running.
         if(orderPL > profitThreshold)
           {
            SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOppositeOrdersold(int newSignalType)
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

      // if(orderPL <= closeOppositeLossThreshold)
      //    continue;

      if((newSignalType == OP_BUY && orderType == OP_SELL && EMADirection == 1) || (newSignalType == OP_SELL && orderType == OP_BUY && EMADirection == -1))
        {
         SafeOrderClose(ticket, lots, orderType, Slippage, (orderType==OP_SELL ? clrRed : clrBlue));
        }
     }
  }

uint LastSSLUpdateMs = 0;
int  SSLUpdateIntervalMs = 1000;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateSSLChannelOnTick()
  {
   if(!ShowSSLLines || Bars < SSLPeriod + 20)
      return;
   uint now = GetTickCount();
   if(LastSSLUpdateMs != 0 && (uint)(now - LastSSLUpdateMs) < (uint)SSLUpdateIntervalMs)
      return;
   LastSSLUpdateMs = now;

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

bool IsCircleOrderComment(string comment) { return (StringFind(comment, "CircleOrder", 0) == 0); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool CreateCircleOrder(int direction, DailyProtectionState &state)
  {

   return false; // Circle orders are disabled in this version. Remove this line to enable.
   int orderType = (direction == 1) ? OP_BUY : OP_SELL;
   if(InpEnableCustomRules && !PassesUserRules(orderType))
      return false;
   if(!EnableTrading || IsDailyTradingStopped(state))
      return false;
   if(direction != 1 && direction != -1)
      return false;
   if(ServerRecoveryPending || !IsConnected())
      return false;
   if(GetTotalEAOrders() >= MaxOpenOrders)
      return false;
   if(!IsSafeToCreateMarketOrder(orderType))
      return false;
   if(!PassesEMAFilter(orderType))
      return false;
   if(!IsOneCandleOrderAllowed())
      return false;
   if(!HasMinimumSameOrderGap(orderType, GetDynamicOrderGap(orderType)))
      return false;
   RefreshRates();

   if(orderType == OP_BUY)
      ChangeLots(GlobalSellPL, "SSL Long", OP_BUY, 0);
   else
      ChangeLots(GlobalBuyPL, "SSL Short", OP_SELL, 0);

   Lots = NormalizeLots(Lots);
   if(Lots <= 0.0)
      return false;

   double entryPrice = (orderType == OP_BUY) ? Ask : Bid;
   entryPrice = NormalizeDouble(entryPrice, Digits);

   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   if(slDistance <= 0.0)
      return false;

   double stopLoss = (orderType == OP_BUY) ? entryPrice - slDistance : entryPrice + slDistance;
   stopLoss = NormalizeDouble(stopLoss, Digits);
   double takeProfit = (orderType == OP_BUY) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
   takeProfit = NormalizeDouble(takeProfit, Digits);

   string orderComment = (orderType == OP_BUY) ? "CircleOrder BUY" : "CircleOrder SELL";
   color orderColor = (orderType == OP_BUY) ? BuyColor : SellColor;

   int ticket = SafeOrderSend(Symbol(), orderType, Lots, entryPrice, Slippage, stopLoss, takeProfit, orderComment, MagicNumber, orderColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
      Print("CIRCLE ORDER CREATED | Ticket=", ticket, " | Direction=", (orderType == OP_BUY ? "BUY" : "SELL"), " | Lots=", DoubleToString(Lots, 2), " | Pattern=", (direction == 1 ? "BULLISH" : "BEARISH"), " | ProfitReEntry=DISABLED");
      return true;
     }
   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckForProfitableClosedOrder(DailyProtectionState &state)
  {
   datetime latestCloseTime = 0;
   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;
      if(OrderCloseTime() > latestCloseTime)
         latestCloseTime = OrderCloseTime();
     }

   if(latestCloseTime <= 0)
      return;
   if(latestCloseTime == LastProcessedClosedOrderTime)
      return;

   double batchProfit = 0.0;
   int latestTicket = -1, latestType = -1;
   double latestClosePrice = 0, latestProfit = 0;
   datetime latestOpenTime = 0;
   string latestComment = "";

   for(int i = OrdersHistoryTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      if(OrderCloseTime() == latestCloseTime)
        {
         batchProfit += (OrderProfit() + OrderSwap() + OrderCommission());
         if(OrderTicket() > latestTicket)
           {
            latestTicket = OrderTicket();
            latestType = OrderType();
            latestClosePrice = OrderClosePrice();
            latestOpenTime = OrderOpenTime();
            latestComment = OrderComment();
            latestProfit = OrderProfit() + OrderSwap() + OrderCommission();
           }
        }
     }

   if(latestTicket < 0)
      return;
   LastProcessedClosedTicket = latestTicket;
   LastProcessedClosedOrderTime = latestCloseTime;

   if(IsCircleOrderComment(latestComment))
      return;

   int latestDirection = 0;
   if(latestType == OP_BUY)
      latestDirection = 1;
   else
      if(latestType == OP_SELL)
         latestDirection = -1;

   int patternDirection = GetCachedPatternDirection();
   bool circleSignal = ((patternDirection == 1 && latestDirection == 1) || (patternDirection == -1 && latestDirection == -1));

   if(circleSignal)
     {
      CreateCircleOrder(latestDirection, state);
      return;
     }
   if(EnableProfitReEntryStop && !IsDailyTradingStopped(state))
     {
      int currentSSL = GlobalSSLDirection;
      int closedDirection = (latestType == OP_BUY) ? 1 : -1;

      if(currentSSL != 0 && currentSSL != closedDirection)
         return;

      // if(GlobalSSLDirection != EMADirection && !IsEmaWEAKDistanceReduced50PercentFromPeak())
      // return ;

      if(!EnableReEntryNOnMatchingSignal && GlobalSSLDirection != EMADirection)
         return ;


      int orderDurationSeconds = (int)(latestCloseTime - latestOpenTime);
      if(batchProfit >=-1)// 0.0) //|| orderDurationSeconds < 60 * 30 * 1)
        {
         CreateProfitReEntryStop(latestType, latestClosePrice, state, (batchProfit < 0.0));
        }
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

// ADD THIS LINE: Block re-entry orders if EMA Ladder is halted
   if(TradingHaltedUntilNextFlip)
      return;

   int pendingType = (closedOrderType == OP_BUY) ? OP_BUYSTOP : OP_SELLSTOP;
   if(InpEnableCustomRules && !PassesUserRules(pendingType))
      return;
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
   if(!HasMinimumSameOrderGap(closedOrderType, MinimumSameOrderGapRawReEntry))
      return;

   RefreshRates();
   double entryPrice = (closedOrderType == OP_BUY) ? (closedPrice + ProfitReEntryGapRaw) : (closedPrice - ProfitReEntryGapRaw);
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
      Lots = NormalizeLots(0.01 * (balancelomultipler > 0 ? balancelomultipler : 1));
   else
     {
      if(pendingType == OP_BUYSTOP)
         ChangeLots(GlobalSellPL, "SSL Profit ReEntry Buy Stop", OP_BUY,0);
      else
         ChangeLots(GlobalBuyPL, "SSL Profit ReEntry Sell Stop", OP_SELL,0);
     }
   int requestedReEntryNumber = reEntryCounter + 1;
   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   if(slDistance <= 0)
      return;
   double stopLoss = (pendingType == OP_BUYSTOP) ? (entryPrice - slDistance) : (entryPrice + slDistance);
   stopLoss = NormalizeDouble(stopLoss, Digits);
   double takeProfit = (pendingType == OP_BUYSTOP) ? (entryPrice + tpDistance) : (entryPrice - tpDistance);
   takeProfit = NormalizeDouble(takeProfit, Digits);
   int ticket = SafeOrderSend(Symbol(), pendingType, Lots, entryPrice, Slippage, stopLoss, takeProfit, orderComment, MagicNumber, orderColor);
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
   UpdateOrderCacheIfNeeded();
   return g_orderCache.buyOrders;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalSellOrders()
  {
   UpdateOrderCacheIfNeeded();
   return g_orderCache.sellOrders;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int GetTotalEAOrders()
  {
   UpdateOrderCacheIfNeeded();
   return g_orderCache.totalOrders;
  }

void InvalidateTotalEAOrdersCache() { InvalidateOrderCache(); }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OpenBuy(string MOMorder="")
  {
   if(InpEnableCustomRules && !PassesUserRules(OP_BUY))
     {
      Print("Order Blocked InpEnableCustomRules");
      return;

     }
   if(!IsSafeToCreateMarketOrder(OP_BUY) || !PassesEMAFilter(OP_BUY) || !IsOneCandleOrderAllowed() || GetTotalEAOrders() >= MaxOpenOrders)
     {
      Print("Order Blocked IsSafeToCreateMarketOrder");
      return;

     }
   double buyGap = GetDynamicOrderGap(OP_BUY);
   if(!HasMinimumSameOrderGap(OP_BUY, buyGap))
     {
      Print("Order Blocked HasMinimumSameOrderGap: Required Gap=", DoubleToString(buyGap, 2));
      return;
     }
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(GlobalSellPL,"SSL Long",OP_BUY,0,MOMorder);
   RefreshRates();
   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   double pendingGap = (SSLLongShortPendingGapRaw > 0.0) ? SSLLongShortPendingGapRaw : 20.0;
   double minStopDist = GetRequiredStopDistance();
   double entryPrice = Ask + pendingGap;
   if(entryPrice < Ask + minStopDist)
      entryPrice = Ask + minStopDist;
   entryPrice = NormalizeDouble(entryPrice, Digits);

   double stopLoss = (slDistance > 0.0) ? NormalizeDouble(entryPrice - slDistance, Digits) : 0.0;
   double takeProfit = (tpDistance > 0.0) ? NormalizeDouble(entryPrice + tpDistance, Digits) : 0.0;

   int ticket = SafeOrderSend(Symbol(), OP_BUYSTOP, Lots, entryPrice, Slippage, stopLoss, takeProfit, "SSL Long", MagicNumber, BuyColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
      Print("SSL LONG PENDING ORDER CREATED: BUY STOP Ticket #", ticket, " Lots=", DoubleToString(Lots, 2),
            " Entry=", DoubleToString(entryPrice, Digits), " (Ask+", DoubleToString(pendingGap, 2), ")",
            " SL=", DoubleToString(stopLoss, Digits), " TP=", DoubleToString(takeProfit, Digits));
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
void OpenSell(string MOMorder="")
  {
   if(InpEnableCustomRules && !PassesUserRules(OP_SELL))
     {
      Print("InpEnableCustomRules ");
      return;

     }
   if(!IsSafeToCreateMarketOrder(OP_SELL) || !PassesEMAFilter(OP_SELL) || !IsOneCandleOrderAllowed() || GetTotalEAOrders() >= MaxOpenOrders)
     {
      Print("IsSafeToCreateMarketOrder ");
      return;

     }
   double sellGap = GetDynamicOrderGap(OP_SELL);
   if(!HasMinimumSameOrderGap(OP_SELL, sellGap))
     {
      Print("Order Blocked HasMinimumSameOrderGap: Required Gap=", DoubleToString(sellGap, 2));
      return;
     }
   reEntryCounter=0;
   SaveReEntryCounter();
   ChangeLots(GlobalBuyPL,"SSL Short",OP_SELL,0,MOMorder);
   RefreshRates();
   double slDistance = (StopLossRawPriceGap > 0.0) ? StopLossRawPriceGap : 3000.0;
   double tpDistance = (TakeProfitRawPriceGap > 0.0) ? TakeProfitRawPriceGap : 500.0;
   double pendingGap = (SSLLongShortPendingGapRaw > 0.0) ? SSLLongShortPendingGapRaw : 20.0;
   double minStopDist = GetRequiredStopDistance();
   double entryPrice = Bid - pendingGap;
   if(entryPrice > Bid - minStopDist)
      entryPrice = Bid - minStopDist;
   entryPrice = NormalizeDouble(entryPrice, Digits);

   double stopLoss = (slDistance > 0.0) ? NormalizeDouble(entryPrice + slDistance, Digits) : 0.0;
   double takeProfit = (tpDistance > 0.0) ? NormalizeDouble(entryPrice - tpDistance, Digits) : 0.0;

   int ticket = SafeOrderSend(Symbol(), OP_SELLSTOP, Lots, entryPrice, Slippage, stopLoss, takeProfit, "SSL Short", MagicNumber, SellColor);
   if(ticket > 0)
     {
      OrderCreatedThisCandle = true;
      LastOrderCandleTime = Time[0];
      Print("SSL SHORT PENDING ORDER CREATED: SELL STOP Ticket #", ticket, " Lots=", DoubleToString(Lots, 2),
            " Entry=", DoubleToString(entryPrice, Digits), " (Bid-", DoubleToString(pendingGap, 2), ")",
            " SL=", DoubleToString(stopLoss, Digits), " TP=", DoubleToString(takeProfit, Digits));
     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
// double CalculatePriceDistanceUSD(double usdAmount, double orderLots)
//   {
//    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
//    double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
//    if(tickValue <= 0.0 || tickSize <= 0.0 || orderLots <= 0.0)
//       return 0.0;
//    double denom = tickValue * orderLots;
//    if(denom <= 0.0)
//       return 0.0;
//    return (usdAmount / denom) * tickSize;
//   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePriceDistanceUSD(double usdAmount, double orderLots)
  {
   // $1 USD = $100 raw price gap
   if(usdAmount <= 0.0)
      return 0.0;
   return usdAmount * 100.0;
  }


























//+------------------------------------------------------------------+
//| Manage Partial Closes for Large Lots (>= 0.03)                   |
//| Closes 0.01 lots when profit reaches $1.00                       |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Manage Partial Closes for Large Lots (>= 0.03)                   |
//| Closes 0.01 lots at +$1.00 profit or -$1.00 loss                 |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Close all open orders for current symbol and magic number        |
//+------------------------------------------------------------------+
void CloseAllOrders()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Match current symbol and magic number
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      // Skip recovery orders if your EA uses them separately
      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         continue;

      int orderType = OrderType();
      if(orderType == OP_BUY || orderType == OP_SELL)
        {
         SafeOrderClose(OrderTicket(), OrderLots(), orderType, 3, (orderType == OP_BUY ? clrRed : clrBlue));
        }
     }
  }



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckDynamicStepLadder()
  {
   double currentOpenProfit = 0.0;
   int openOrdersCount = 0;

// 1. Calculate current open profit
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         continue;

      int orderType = OrderType();
      if(orderType == OP_BUY || orderType == OP_SELL)
        {
         currentOpenProfit += OrderProfit() + OrderSwap() + OrderCommission();
         openOrdersCount++;
        }
     }

// If no orders are open, reset peak tracking for the next cycle
   if(openOrdersCount == 0)
     {
      g_peakCycleProfit = 0.0;
      return;
     }

// 2. Calculate realized profit from closed history since last reset
   double realizedHistoryProfit = 0.0;
   int historyTotal = HistoryTotal();

   for(int i = 0; i < historyTotal; i++)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      if(OrderCloseTime() > g_lastLadderCloseTime)
        {
         realizedHistoryProfit += OrderProfit() + OrderSwap() + OrderCommission();
        }
     }

// 3. Current active cycle profit
   double cycleProfit = realizedHistoryProfit + currentOpenProfit;

// 4. Update Peak Profit Watermark if we make a new high
   if(cycleProfit > g_peakCycleProfit)
     {
      g_peakCycleProfit = cycleProfit;
     }

// 5. Dynamically calculate the highest $5 step milestone unlocked by the peak
// e.g., if peak is $14, MathFloor(14 / 5) * 5 = $10 floor milestone.
// If peak is $17, MathFloor(17 / 5) * 5 = $15 floor milestone.
   double unlockedStepFloor = MathFloor(g_peakCycleProfit / g_stepSize) * g_stepSize;

// Ensure we have at least crossed the first $5 step before trailing starts
   if(unlockedStepFloor >= g_stepSize)
     {
      // 6. If the current profit drops down to or below the previous step floor, close all orders!
      // (e.g., Peak hit $14 -> Floor is $10. If current profit drops back to $10, trigger close.)
      if(cycleProfit <= unlockedStepFloor)
        {
         Print("Dynamic Step Exit! Peak reached: $", DoubleToString(g_peakCycleProfit, 2),
               " | Market came down to step floor: $", DoubleToString(unlockedStepFloor, 2), ". Closing all open orders.");

         // CloseAllOrders();
         ModifyOpenOrdersToSecureProfit();


         // Save baseline time and reset peak for the next cycle
         g_lastLadderCloseTime = TimeCurrent();
         g_peakCycleProfit = 0.0;
        }
     }
  }

//+------------------------------------------------------------------+
//| Dynamic Lowest Equity Recovery                                   |
//|                                                                  |
//| Logic:                                                           |
//| 1. Store the lowest equity reached                               |
//| 2. If equity falls further, update LowestEquity                  |
//| 3. When equity recovers 20% from LowestEquity:                  |
//|      - Call ModifyOpenOrdersToSecureProfit()                     |
//|      - Set LowestEquity = current equity                         |
//| 4. Continue monitoring indefinitely                              |
//+------------------------------------------------------------------+


double LowestEquity = 0.0;
bool   LowestEquityInitialized = false;
double currentEquity=0;


//+------------------------------------------------------------------+
//| Monitor Lowest Equity Recovery                                   |
//+------------------------------------------------------------------+
void MonitorLowestEquityRecovery()
  {
   currentEquity = AccountEquity();


   if(currentEquity<g_dayOpeningBalance)
     {
      return;
     }

//==============================================================
// FIRST RUN
//==============================================================
   if(!LowestEquityInitialized)
     {
      LowestEquity = currentEquity;
      LowestEquityInitialized = true;

      Print("EQUITY MONITOR STARTED",
            " | Current Equity = ",
            DoubleToString(currentEquity, 2),
            " | Lowest Equity = ",
            DoubleToString(LowestEquity, 2));

      return;
     }


//==============================================================
// EQUITY MAKES A NEW LOW
//==============================================================
   if(currentEquity < LowestEquity)
     {
      LowestEquity = currentEquity;

      Print("NEW LOWEST EQUITY",
            " | Lowest Equity = ",
            DoubleToString(LowestEquity, 2),
            " | Current Equity = ",
            DoubleToString(currentEquity, 2));

      return;
     }


//==============================================================
// CALCULATE RECOVERY TARGET
//
// Example:
// Lowest Equity = $50
// Recovery = 20%
// Target = $60
//==============================================================
   double recoveryTarget =
      LowestEquity * (1.0 + closeAllOrdersLowestEquityIncreasePercentage / 100.0);


//==============================================================
// EQUITY RECOVERED 20%
//==============================================================
   if(currentEquity >= recoveryTarget)
     {
      Print("========================================");
      Print("EQUITY RECOVERY TARGET REACHED");
      Print("Lowest Equity   = ",
            DoubleToString(LowestEquity, 2));
      Print("Current Equity  = ",
            DoubleToString(currentEquity, 2));
      Print("Recovery Target = ",
            DoubleToString(recoveryTarget, 2));
      Print("Recovery %      = ",
            DoubleToString(closeAllOrdersLowestEquityIncreasePercentage, 2), "%");
      Print("Calling ModifyOpenOrdersToSecureProfit()");
      Print("========================================");


      //==============================================================
      // CALL YOUR EXISTING FUNCTION
      //==============================================================
      ModifyOpenOrdersToSecureProfit();


      //==============================================================
      // RESET LOWEST EQUITY TO CURRENT EQUITY
      //==============================================================
      LowestEquity = currentEquity;

      Print("LOWEST EQUITY RESET",
            " | New Lowest Equity = ",
            DoubleToString(LowestEquity, 2));
     }
  }
// //+------------------------------------------------------------------+
// //| Step-by-Step Profit Ladder ($5, $10, $15, etc.)                  |
// //+------------------------------------------------------------------+
// datetime g_lastLadderCloseTime = 0;   // Stores timestamp of last basket reset
// double   g_peakCombinedProfit  = 0.0; // Tracks the highest profit reached in the current cycle
// double   g_currentStepTarget   = 5.0; // Current step threshold to cross ($5, $10, etc.)
// bool     g_targetUnlocked      = false; // True once we've crossed the current $5 tier and are trailing

// void CheckTrailingProfitLadder()
//   {
//    double currentOpenProfit = 0.0;
//    int openOrdersCount = 0;

//    // 1. Calculate current open profit
//    for(int i = OrdersTotal() - 1; i >= 0; i--)
//      {
//       if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
//          continue;
//       if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
//          continue;
//       if(StringFind(OrderComment(), "RECOVERY_") == 0)
//          continue;

//       int orderType = OrderType();
//       if(orderType == OP_BUY || orderType == OP_SELL)
//         {
//          currentOpenProfit += OrderProfit() + OrderSwap() + OrderCommission();
//          openOrdersCount++;
//         }
//      }

//    // If no orders are open, reset tracking variables for the next cycle
//    if(openOrdersCount == 0)
//      {
//       g_peakCombinedProfit = 0.0;
//       g_targetUnlocked = false;
//       return;
//      }

//    // 2. Calculate realized profit from closed history since last reset
//    double realizedHistoryProfit = 0.0;
//    int historyTotal = HistoryTotal();

//    for(int i = 0; i < historyTotal; i++)
//      {
//       if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
//          continue;
//       if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
//          continue;

//       if(OrderCloseTime() > g_lastLadderCloseTime)
//         {
//          realizedHistoryProfit += OrderProfit() + OrderSwap() + OrderCommission();
//         }
//      }

//    // 3. Total Combined Profit (Closed history + Current open positions)
//    double totalCombinedProfit = realizedHistoryProfit + currentOpenProfit;

//    // 4. Update Peak Profit Watermark if we are making a new high
//    if(totalCombinedProfit > g_peakCombinedProfit)
//      {
//       g_peakCombinedProfit = totalCombinedProfit;
//      }

//    // 5. Phase 1: Check if we have crossed our current step target (e.g., $5, $10, etc.)
//    if(!g_targetUnlocked && totalCombinedProfit >= g_currentStepTarget)
//      {
//       g_targetUnlocked = true;
//       Print("Step Target Unlocked ($", DoubleToString(g_currentStepTarget, 2), ")! Peak profit tracking active. Current Peak: $", DoubleToString(g_peakCombinedProfit, 2));
//      }

//    // 6. Phase 2: If target was unlocked, check for a pullback (price coming down from peak)
//    // We close if profit drops below the peak by a small buffer (e.g., $0.50 pullback) or drops back below the target tier.
//    if(g_targetUnlocked)
//      {
//       double pullbackBuffer = 0.50; // Adjust this buffer if you want tighter or looser pullback sensitivity

//       if(totalCombinedProfit < (g_peakCombinedProfit - pullbackBuffer) || totalCombinedProfit <= (g_currentStepTarget - 2.0))
//         {
//          Print("Pullback detected from peak ($", DoubleToString(g_peakCombinedProfit, 2), ")! Current Profit: $", DoubleToString(totalCombinedProfit, 2), ". Closing all open orders.");

//          // Close all open positions to lock in the trailing profit
//          CloseAllOrders();

//          // Save baseline time and reset states
//          g_lastLadderCloseTime = TimeCurrent();
//          g_targetUnlocked = false;
//          g_peakCombinedProfit = 0.0;

//          // // Trigger halt flags
//          // TradingHaltedUntilNextFlip = true;
//          // LadderHaltStartTime = TimeCurrent();

//          // Advance to the next $5 step tier ($5 -> $10 -> $15...)
//          g_currentStepTarget += 5.0;
//          Print("Advanced to next Step Target Tier: $", DoubleToString(g_currentStepTarget, 2));
//         }
//      }
//   }
// Global tracker for the 30-minute loss gap
datetime g_lastLossCloseTime = 0;
double   g_lastClosedPrice   = 0;
// Global arrays to track individual ticket states independently for multi-order support
int      g_trackedTickets[];
datetime g_lastLossCloseTimes[];
double   g_lastClosedPrices[];

// Global arrays to track individual ticket states independently


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrackTicketLossState(int ticket, datetime closeTime, double closePrice)
  {
   int size = ArraySize(g_trackedTickets);
   int index = -1;

   for(int i = 0; i < size; i++)
     {
      if(g_trackedTickets[i] == ticket)
        {
         index = i;
         break;
        }
     }

   if(index == -1)
     {
      ArrayResize(g_trackedTickets, size + 1);
      ArrayResize(g_lastLossCloseTimes, size + 1);
      ArrayResize(g_lastClosedPrices, size + 1);
      index = size;
      g_trackedTickets[index] = ticket;
     }

   g_lastLossCloseTimes[index] = closeTime;
   g_lastClosedPrices[index]   = closePrice;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool GetTrackedTicketState(int ticket, datetime &outTime, double &outPrice)
  {
   int size = ArraySize(g_trackedTickets);
   for(int i = 0; i < size; i++)
     {
      if(g_trackedTickets[i] == ticket)
        {
         outTime  = g_lastLossCloseTimes[i];
         outPrice = g_lastClosedPrices[i];
         return true;
        }
     }
   return false;
  }
//   void ManagePartialClosesNew()
//   {
//    for(int i = OrdersTotal() - 1; i >= 0; i--)
//      {
//       if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
//          continue;

//       // Ensure it matches current symbol
//       if(OrderSymbol() != Symbol())
//          continue;

//       int orderType = OrderType();
//       if(orderType != OP_BUY && orderType != OP_SELL)
//          continue;

//       double orderLots = OrderLots();
//       int currentTicket = OrderTicket();

//       // Check if order size meets your threshold (0.02 lots or higher)
//       if(orderLots >= 0.02 * balancelomultipler)
//         {
//          // Calculate total net profit for this specific ticket (including swap/commission)
//          double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
//          double lotsToClose   = 0.01;

//          // Ensure leaving a valid minimum lot size behind (at least 0.01 remaining)
//          if(orderLots - lotsToClose >= 0.01 * balancelomultipler)
//            {
//             bool   triggerClose = false;
//             string actionType   = "";
//             int    orderTypeInt = (orderType == OP_SELL) ? -1 : 1;
//             int    minimum_Profit = 2;

//             if(TimeCurrent() - OrderOpenTime() > 60 * 30)
//               {
//                minimum_Profit = 1;
//               }

//             // Retrieve independent state for this specific ticket
//             datetime ticketLastLossTime = 0;
//             double   ticketLastPrice    = 0;
//             bool     hasState           = GetTrackedTicketState(currentTicket, ticketLastLossTime, ticketLastPrice);

//             // === CONDITION 1: PROFIT TARGET REACHED ===
//             if(currentProfit >= minimum_Profit &&
//                TimeCurrent() - OrderOpenTime() > 60 * 1 &&
//                (!hasState || TimeCurrent() - ticketLastLossTime >= 60 * 2))
//               {
//                triggerClose = true;
//                actionType   = "PROFIT";
//               }
//             // === CONDITION 2: SEQUENTIAL LOSS GAP CUT ($100 GAPS) ===
//             else if(currentProfit <= -(orderLots * 100.0))
//               {
//                bool priceGapReached = false;

//                if(!hasState || ticketLastPrice == 0)
//                  {
//                   priceGapReached = true; // First partial loss close for this ticket
//                  }
//                else if(orderTypeInt == 1 && (ticketLastPrice - Bid) >= 100.0) // OP_BUY
//                  {
//                   priceGapReached = true;
//                  }
//                else if(orderTypeInt == -1 && (Ask - ticketLastPrice) >= 100.0) // OP_SELL
//                  {
//                   priceGapReached = true;
//                  }

//                if(priceGapReached)
//                  {
//                   triggerClose = true;
//                   actionType   = "LOSS CUT";
//                  }
//               }

//             // === EXECUTE ORDER CLOSE ONCE IF TRIGGERED ===
//             if(triggerClose)
//               {
//                RefreshRates();
//                double closePrice = (orderType == OP_BUY) ? Bid : Ask;

//                // Use higher slippage (20) to prevent Error 138 during fast market movement
//                bool success = OrderClose(currentTicket, lotsToClose, closePrice, 20, (actionType == "PROFIT" ? clrOrange : clrRed));

//                if(success)
//                  {
//                   // Save state independently for this ticket
//                   TrackTicketLossState(currentTicket, TimeCurrent(), closePrice);

//                   Print("Partial Close Success [", actionType, "]: Ticket #", currentTicket,
//                         " | Closed: ", lotsToClose, " lots | P/L: $", DoubleToString(currentProfit, 2),
//                         " | Price: ", closePrice);
//                  }
//                else
//                  {
//                   Print("Partial Close Failed for Ticket #", currentTicket, ". Error: ", GetLastError());
//                  }
//               }
//            }
//         }
//      }
//   }

// Global variables to track equity-based step loss milestones
double g_lastMilestoneLoss = 0.0; // Tracks the last loss step reached (e.g., -5, -10, -15...)

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManageEquityStepLoss()
  {
// 1. Calculate total floating P/L across all open orders on the current symbol
   double totalBasketProfit = 0.0;
   int openOrdersCount = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;
      if(OrderType() != OP_BUY && OrderType() != OP_SELL)
         continue;

      totalBasketProfit += OrderProfit() + OrderSwap() + OrderCommission();
      openOrdersCount++;
     }

// If no orders or basket is in profit, reset milestone tracking and exit
   if(openOrdersCount == 0 || totalBasketProfit >= 0)
     {
      g_lastMilestoneLoss = 0.0;
      return;
     }

// 2. Define your step size (e.g., every $5.00 step in total loss)
   double stepSize = 5.00*balancelomultipler;

// Calculate which step milestone we are currently at (e.g., -5, -10, -15...)
// totalBasketProfit is negative, so we check against negative thresholds
   double currentLossMagnitude = MathAbs(totalBasketProfit);

// Determine if we crossed a new $5 step increment
   bool   triggerStepClose = false;
   double nextMilestone    = g_lastMilestoneLoss + stepSize;

   if(currentLossMagnitude >= nextMilestone)
     {
      triggerStepClose = true;
      g_lastMilestoneLoss = nextMilestone; // Update milestone tracker
     }

   if(triggerStepClose)
     {
      // 3. Find the open order with the LARGEST lot size
      int    largestOrderTicket = -1;
      double largestLotSize     = 0.0;
      int    targetOrderType    = -1;

      for(int i = OrdersTotal() - 1; i >= 0; i--)
        {
         if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
            continue;
         if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
            continue;

         double lots = OrderLots();
         // Ensure the order has enough volume to shave 0.01 while leaving at least 0.01 behind
         if(lots >= 0.02 && lots > largestLotSize)
           {
            largestLotSize     = lots;
            largestOrderTicket = OrderTicket();
            targetOrderType    = OrderType();
           }
        }

      // 4. Execute partial close (0.01) on the largest order found
      if(largestOrderTicket != -1)
        {
         if(OrderSelect(largestOrderTicket, SELECT_BY_TICKET))
           {
            RefreshRates();
            double closePrice = (targetOrderType == OP_BUY) ? Bid : Ask;
            double lotsToClose = 0.01;

            bool success = OrderClose(largestOrderTicket, lotsToClose, closePrice, 20, clrRed);
            if(success)
              {
               Print("Equity Step Loss Triggered at Total P/L: $", DoubleToString(totalBasketProfit, 2),
                     " | Closed 0.01 lots from Largest Order Ticket #", largestOrderTicket,
                     " (Initial Lots: ", largestLotSize, ")");
              }
            else
              {
               Print("Equity Step Loss Close Failed for Ticket #", largestOrderTicket, ". Error: ", GetLastError());
              }
           }
        }
     }
  }
// Global arrays to track individual ticket states independently for loss cuts
//int      g_trackedTickets[];
//double   g_lastClosedPrices[];
// Helper to find the original parent ticket across partial closes
int GetOriginalTicket(int ticket, string comment)
  {
// MT4 formats partial closes as "from #12345"
   int pos = StringFind(comment, "from #");
   if(pos >= 0)
     {
      string parentStr = StringSubstr(comment, pos + 6);
      return (int)StringToInteger(parentStr);
     }
   return ticket;
  }
// Helper function to update or add a ticket's last closed price
void UpdateTicketClosePrice(int ticket, double closePrice)
  {
   int size = ArraySize(g_trackedTickets);
   int index = -1;

   for(int i = 0; i < size; i++)
     {
      if(g_trackedTickets[i] == ticket)
        {
         index = i;
         break;
        }
     }

   if(index == -1)
     {
      ArrayResize(g_trackedTickets, size + 1);
      ArrayResize(g_lastClosedPrices, size + 1);
      index = size;
      g_trackedTickets[index] = ticket;
     }

   g_lastClosedPrices[index] = closePrice;
  }

// Helper function to get a specific ticket's last closed price
double GetTicketLastClosePrice(int ticket)
  {
   int size = ArraySize(g_trackedTickets);
   for(int i = 0; i < size; i++)
     {
      if(g_trackedTickets[i] == ticket)
         return g_lastClosedPrices[i];
     }
   return 0.0; // Returns 0 if this ticket has never partially closed yet
  }
//+------------------------------------------------------------------+
//| Partial Loss Close                                               |
//|                                                                   |
//| Lot Size   Loss Trigger   Partial Close                          |
//| 0.05       <= -$5.00      0.01                                  |
//| 0.04       <= -$8.00      0.01                                  |
//| 0.03       <= -$9.00      0.01                                  |
//| 0.02       <= -$8.00      0.01                                  |
//|                                                                   |
//| After the first partial loss close, the SAME parent order must   |
//| move another 100 raw price units against the position before     |
//| another partial loss close is allowed.                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Partial Loss Close                                               |
//| User Rules:                                                      |
//| 0.05 lot: close 0.01 lot when raw distance >= $300               |
//| 0.04 lot: close 0.01 lot when raw distance >= $500               |
//| 0.03 lot: close 0.01 lot when raw distance >= $800               |
//| 0.02 lot: close 0.01 lot when loss < -$20 OR raw distance >= $1000|
//|                                                                  |
//| After a partial loss close, the SAME parent order must move       |
//| another $100 raw price units against the position before another |
//| partial loss close is allowed.                                   |
//+------------------------------------------------------------------+
void ManagePartialClosesLoss()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() ||
         OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();

      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      // Exclude recovery orders from regular scalp partial loss cuts
      if(IsAnyRecoveryOrder(OrderTicket(), OrderComment()))
         continue;

      double orderLots     = OrderLots();
      int    currentTicket = OrderTicket();
      double openPrice     = OrderOpenPrice();

      RefreshRates();
      // Raw price distance moving against position (loss direction)
      double rawLossDistance = (orderType == OP_BUY) ? (openPrice - Bid) : (Ask - openPrice);

      // Current order net P/L
      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();

      int baseMult = (balancelomultipler > 0 ? balancelomultipler : 1);
      double lotsToClose = 0.01 * baseMult;

      bool conditionMet = false;
      string triggerReason = "";

      if(MathAbs(orderLots - (0.05 * baseMult)) < 0.000001)
        {
         if(rawLossDistance >= 300.0)
           {
            conditionMet = true;
            triggerReason = StringFormat("0.05L Raw Dist $%.1f >= $300", rawLossDistance);
           }
        }
      else if(MathAbs(orderLots - (0.04 * baseMult)) < 0.000001)
        {
         if(rawLossDistance >= 500.0)
           {
            conditionMet = true;
            triggerReason = StringFormat("0.04L Raw Dist $%.1f >= $500", rawLossDistance);
           }
        }
      else if(MathAbs(orderLots - (0.03 * baseMult)) < 0.000001)
        {
         if(rawLossDistance >= 800.0)
           {
            conditionMet = true;
            triggerReason = StringFormat("0.03L Raw Dist $%.1f >= $800", rawLossDistance);
           }
        }
      else if(MathAbs(orderLots - (0.02 * baseMult)) < 0.000001)
        {
         double dollarLossLimit = -20.0 * baseMult;
         if(currentProfit < dollarLossLimit || rawLossDistance >= 1000.0)
           {
            conditionMet = true;
            triggerReason = StringFormat("0.02L (P/L $%.2f < $%.2f OR Raw Dist $%.1f >= $1000)", currentProfit, dollarLossLimit, rawLossDistance);
           }
        }
      else
        {
         // No partial-loss rule for other lot sizes
         continue;
        }

      if(!conditionMet)
         continue;

      // Must leave at least 0.01 lot after partial close
      double minLot = MarketInfo(Symbol(), MODE_MINLOT);
      double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);

      if(minLot <= 0.0)
         minLot = 0.01;

      if(lotStep <= 0.0)
         lotStep = 0.01;

      lotsToClose = MathFloor(lotsToClose / lotStep + 0.0000001) * lotStep;
      lotsToClose = NormalizeDouble(lotsToClose, 2);

      if(lotsToClose < minLot)
         lotsToClose = minLot;

      if(orderLots - lotsToClose < minLot)
         continue;

      // -------------------------------------------------------------
      // Parent-ticket tracking
      // -------------------------------------------------------------
      int baseTicket = GetOriginalTicket(currentTicket, OrderComment());
      if(baseTicket <= 0)
         baseTicket = currentTicket;

      double lastClosedPrice = GetTicketLastClosePrice(baseTicket);

      // -------------------------------------------------------------
      // $100 raw price gap between partial loss closes for same parent
      // -------------------------------------------------------------
      bool priceGapReached = false;

      if(lastClosedPrice <= 0.0)
        {
         // First partial loss close for this parent order
         priceGapReached = true;
        }
      else
        {
         if(orderType == OP_BUY)
           {
            // BUY must move $100 lower
            if((lastClosedPrice - Bid) >= 100.0)
               priceGapReached = true;
           }
         else if(orderType == OP_SELL)
           {
            // SELL must move $100 higher
            if((Ask - lastClosedPrice) >= 100.0)
               priceGapReached = true;
           }
        }

      if(!priceGapReached)
         continue;

      // -------------------------------------------------------------
      // Execute partial loss close
      // -------------------------------------------------------------
      RefreshRates();
      double closePrice = (orderType == OP_BUY) ? Bid : Ask;

      ResetLastError();
      bool success = OrderClose(currentTicket, lotsToClose, closePrice, Slippage, (orderType == OP_BUY ? clrRed : clrBlue));

      if(success)
        {
         UpdateTicketClosePrice(baseTicket, closePrice);

         Print(">>> [PARTIAL LOSS CLOSE SUCCESS] Ticket #", currentTicket,
               " (Parent #", baseTicket, ") Closed ", DoubleToString(lotsToClose, 2),
               "L of ", DoubleToString(orderLots, 2), "L at ", DoubleToString(closePrice, Digits),
               " | Trigger: ", triggerReason,
               " | Current P/L: $", DoubleToString(currentProfit, 2),
               " | Next Gap: $100");

         return;
        }

      int errorCode = GetLastError();
      Print(">>> [PARTIAL LOSS CLOSE FAILED] Ticket #", currentTicket,
            " (Parent #", baseTicket, ") | Error=", errorCode);

      return;
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePartialClosesLossOld()
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Ensure it matches current symbol and magic number
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;

      double orderLots = OrderLots();
      int currentTicket = OrderTicket();

      // Check if order size meets your threshold (0.02 lots or higher to allow partial close)
      if(orderLots >= 0.02 * balancelomultipler)
        {
         // Calculate total net profit for this specific ticket (including swap/commission)
         double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
         double lotsToClose   = 0.01*balancelomultipler;

         // Ensure leaving a valid minimum lot size behind (at least 0.01 remaining)
         if(orderLots - lotsToClose >= 0.01 * balancelomultipler)
           {
            bool   triggerClose = false;
            int    orderTypeInt = (orderType == OP_SELL) ? -1 : 1;

            // Retrieve the last closed price specific to *this* unique ticket reference from our array
            int baseTicket = GetOriginalTicket(currentTicket, OrderComment());
            double lastClosedPrice = GetTicketLastClosePrice(baseTicket);

            // === PURE LOSS GAP CUT CONDITION ($100 RAW PRICE GAP PER SPECIFIC ORDER) ===
            if(currentProfit <= -(orderLots * 100.0*2))
              {
               bool priceGapReached = false;

               if(lastClosedPrice == 0.0)
                 {
                  priceGapReached = true; // First partial loss close for this specific ticket
                 }
               else
                  if(orderTypeInt == 1 && (lastClosedPrice - Bid) >= 100.0) // OP_BUY: Current Bid must be $100 lower than the last close price for THIS ticket
                    {
                     priceGapReached = true;
                    }
                  else
                     if(orderTypeInt == -1 && (Ask - lastClosedPrice) >= 100.0) // OP_SELL: Current Ask must be $100 higher than the last close price for THIS ticket
                       {
                        priceGapReached = true;
                       }

               if(priceGapReached)
                 {
                  triggerClose = true;
                 }
              }

            // === EXECUTE ORDER CLOSE ONCE LOSS GAP IS TRIGGERED ===
            if(triggerClose)
              {
               RefreshRates();
               double closePrice = (orderType == OP_BUY) ? Bid : Ask;

               // Slippage set to 20 to prevent Error 138 during fast market movement
               bool success = OrderClose(currentTicket, lotsToClose, closePrice, 20, clrRed);

               if(success)
                 {
                  // Save this close price exclusively referenced to this unique order ticket in the array
                  UpdateTicketClosePrice(baseTicket, closePrice);
                  Print("Partial Loss Cut Success: Ticket #", currentTicket,
                        " | Closed: ", lotsToClose, " lots | P/L: $", DoubleToString(currentProfit, 2),
                        " | Execution Price Recorded: ", closePrice);
                 }
               else
                 {
                  Print("Partial Loss Cut Failed for Ticket #", currentTicket, ". Error: ", GetLastError());
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ManagePartialCloses()
  {


   ManagePartialClosesLoss();
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      // Ensure it matches current symbol
      if(OrderSymbol() != Symbol())
         continue;

      int orderType = OrderType();
      if(orderType != OP_BUY && orderType != OP_SELL)
         continue;


      if(StringFind(OrderComment(), "RECOVERY_") == 0)
         continue;

      double orderLots = OrderLots();

      // Check if order size meets your threshold (0.02 lots or higher)
      if(orderLots >= 0.02 * balancelomultipler)
        {
         // Calculate total net profit for this specific ticket (including swap/commission)
         double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
         double lotsToClose   = 0.01*balancelomultipler;

         // g_lastClosedPrice=OrderOpenPrice();

         // Ensure leaving a valid minimum lot size behind (at least 0.01 remaining)
         if(orderLots - lotsToClose >= 0.01 * balancelomultipler)
           {
            bool   triggerClose = false;
            string actionType   = "";
            int    orderTypeInt = (orderType == OP_SELL) ? -1 : 1;
            int    minimum_Profit =orderLots*100*partialClose01in05IndividualPercentage;

            if(TimeCurrent() - OrderOpenTime() > 60 * 30)
              {
               minimum_Profit =minimum_Profit/2;// 1*balancelomultipler;
              }

            // === CONDITION 1: PROFIT TARGET REACHED ===
            if(currentProfit >= minimum_Profit &&
               TimeCurrent() - OrderOpenTime() > 60 * 1 &&
               TimeCurrent() - g_lastLossCloseTime >= 60 * 2)
              {
               triggerClose = true;
               actionType   = "PROFIT";
              }
            // // === CONDITION 2: SEQUENTIAL LOSS GAP CUT ($100 GAPS) ===
            // else
            //    if(currentProfit <= -(orderLots * 100.0))
            //      {
            //       bool priceGapReached = false;



            //       if(g_lastClosedPrice == 0)
            //         {
            //          priceGapReached = true; // First partial loss close
            //         }
            //       else
            //          if(orderTypeInt == 1 && (g_lastClosedPrice - Bid) >= 100.0) // OP_BUY
            //            {
            //             priceGapReached = true;
            //            }
            //          else
            //             if(orderTypeInt == -1 && (Ask - g_lastClosedPrice) >= 100.0) // OP_SELL
            //               {
            //                priceGapReached = true;
            //               }

            //       if(priceGapReached)
            //         {
            //          triggerClose = true;
            //          actionType   = "LOSS CUT";
            //         }
            //      }

            // === EXECUTE ORDER CLOSE ONCE IF TRIGGERED ===
            if(triggerClose)
              {
               RefreshRates();
               double closePrice = (orderType == OP_BUY) ? Bid : Ask;

               // Use higher slippage (20) to prevent Error 138 during fast market movement
               bool success = OrderClose(OrderTicket(), lotsToClose, closePrice, 20, (actionType == "PROFIT" ? clrOrange : clrRed));

               if(success)
                 {
                  // if(actionType == "LOSS CUT")
                    {
                     g_lastLossCloseTime = TimeCurrent();
                     g_lastClosedPrice   = closePrice; // Save reference price for the next $100 gap
                    }

                  Print("Partial Close Success [", actionType, "]: Ticket #", OrderTicket(),
                        " | Closed: ", lotsToClose, " lots | P/L: $", DoubleToString(currentProfit, 2),
                        " | Price: ", closePrice);
                 }
               else
                 {
                  Print("Partial Close Failed for Ticket #", OrderTicket(), ". Error: ", GetLastError());
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Manage Partial Closes with 30-Minute Gap Between Losses          |
//+------------------------------------------------------------------+
// void ManagePartialClosesNew111()
//   {
//    for(int i = OrdersTotal() - 1; i >= 0; i--)
//      {
//       if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
//          continue;

//       // Ensure it matches current symbol
//       if(OrderSymbol() != Symbol())
//          continue;

//       int orderType = OrderType();
//       if(orderType != OP_BUY && orderType != OP_SELL)
//          continue;

//       double orderLots = OrderLots();
//       int ticket = OrderTicket();

//       // Check if order size meets your threshold (e.g., 0.05 lots or higher)
//       if(orderLots >= 0.05)
//         {
//          // Calculate total net profit for this specific ticket (including swap/commission)
//          double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();

//          double lotsToClose = 0.01; // The portion to bank
//          double minimum_Profit = 2.0; // Your profit threshold

//          // Condition: Profit target reached
//          if(currentProfit >= minimum_Profit && TimeCurrent() - OrderOpenTime() > 60 * 1 && TimeCurrent() - g_lastLossCloseTime >= 60 * 2)
//            {
//             RefreshRates();
//             bool success = false;

//             // 1. Partially close 0.01 lots to bank real profit
//             if(orderType == OP_BUY)
//                success = OrderClose(ticket, lotsToClose, Bid, 3, clrOrange);
//             else
//                if(orderType == OP_SELL)
//                   success = OrderClose(ticket, lotsToClose, Ask, 3, clrOrange);

//             if(success)
//               {
//                Print("Partial Close Success [PROFIT LOCK]: Ticket #", ticket,
//                      " | Closed: ", lotsToClose, " lots | P/L at close: $", DoubleToString(currentProfit, 2));

//                // 2. Select the remaining portion (0.04 lots) and move SL to lock in profit on the rest
//                if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
//                  {
//                   double openPrice = OrderOpenPrice();
//                   double currentTP = OrderTakeProfit();
//                   double newSL = 0;

//                   if(orderType == OP_BUY)
//                     {
//                      // Set SL above open price to lock in a profit buffer for the remaining 0.04 lots
//                      newSL = Bid - (15 * Point);
//                      if(newSL < openPrice)
//                         newSL = openPrice + (2 * Point);
//                     }
//                   else
//                      if(orderType == OP_SELL)
//                        {
//                         // Set SL below open price to lock in a profit buffer for the remaining 0.04 lots
//                         newSL = Ask + (15 * Point);
//                         if(newSL > openPrice)
//                            newSL = openPrice - (2 * Point);
//                        }

//                   newSL = NormalizeDouble(newSL, Digits);

//                   // Modify the remaining active volume with the new profit-locking Stop Loss
//                   bool modSuccess =SafeOrderModify(ticket, openPrice, newSL, currentTP, 0, clrLime);
//                   if(modSuccess)
//                     {
//                      Print("Successfully moved Stop Loss on remaining ", OrderLots(), " lots for Ticket #", ticket);
//                     }
//                   else
//                     {
//                      Print("Failed to update SL on remaining volume for Ticket #", ticket, ". Error: ", GetLastError());
//                     }
//                  }
//               }
//             else
//               {
//                Print("Partial Close Failed for Ticket #", ticket, ". Error: ", GetLastError());
//               }
//            }
//         }
//      }
//   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Manage Profit Ladder & Partial Closes                            |
//+------------------------------------------------------------------+
void ManageProfitLadder()
  {
   if(GetTotalEAOrders() <= 0)
      return;

// 1. Run partial close checks first (handles its own loop safely)
   ManagePartialCloses();

   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   double tickSize  = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tickValue <= 0 || tickSize <= 0)
      return;

// 2. Then proceed with the standard profit ladder / trailing SL loop
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
      if(HasRecoveryOrder(OrderTicket()))
         continue;

      double currentProfit = OrderProfit() + OrderSwap() + OrderCommission();
      if(currentProfit <= 0)
         continue;
      double orderLots = OrderLots();
      if(orderLots <= 0)
         continue;

      double ladder1Profit = OriginalLadder1ProfitUSD * orderLots * 100.0;
      // double currentSL = OrderStopLoss();
      double open=OrderOpenPrice();
      double sl=OrderStopLoss();

      double existingPriceDistance = 0.0;
      if(orderType == OP_BUY)
         existingPriceDistance = OrderStopLoss() - OrderOpenPrice();
      if(orderType == OP_SELL)
         existingPriceDistance = OrderOpenPrice() - OrderStopLoss();



      // --- NEW LOGIC: Reduce ladder1Profit by half if order is older than 1 hour or lots >= 0.03 ---
      // if(TimeCurrent() - OrderOpenTime() > 60*60 || orderLots >= 0.03)

      double currentSLPoints = MathAbs(OrderOpenPrice() - OrderStopLoss());
      if(TimeCurrent() - OrderOpenTime() > 60*30)
        {
         // ladder1Profit = ladder1Profit / 2.0;
        }

      if((MathAbs(existingPriceDistance) == 100 && orderLots==0.01) || (GlobalSSLDirection != EMADirection))
        {
         //ladder1Profit = 0.20*2*orderLots*100; // Or scale dynamically: (slDistance / 100.0) * 0.10
        }

      // ladder1Profit=ladder1Profit*balancelomultipler; // orderLots already scaled by balancelomultipler

      // -----------------------------------------------------------------------------

      double ladder2Profit = OriginalLadder2ProfitUSD * orderLots * 100.0;
      double ladder1StopMaxPrice = OriginalLadder1StopMaxPriceUSD * orderLots * 100.0;

      // ladder2Profit=ladder2Profit*balancelomultipler; // orderLots already scaled by balancelomultipler

      double lockedProfit = 0.0;


      // Print("currentSL"+existingPriceDistance+" - "+ladder1Profit+" - "+ currentProfit+" < "+ ladder1StopMaxPrice);

      if(EnableProfitLadder1 && ladder1Profit > 0 && (currentProfit < ladder1StopMaxPrice))// || existingPriceDistance == 100))
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
            existingLockedProfit = (existingPriceDistance / 100.0);
            existingLockedProfit = NormalizeDouble(existingLockedProfit, 2);
           }
        }

      double nextProfitTargetUSD = 0.0;
      if(EnableProfitLadder1 && ladder1Profit > 0.0 && currentProfit < ladder1StopMaxPrice)
        {
         int nextL1Level = (int)MathFloor(currentProfit / ladder1Profit) + 1;
         nextProfitTargetUSD = nextL1Level * ladder1Profit;
        }
      else
         if(EnableProfitLadder2 && ladder2Profit > 0.0)
           {
            int nextL2Level = (int)MathFloor(currentProfit / ladder2Profit) + 1;
            nextProfitTargetUSD = nextL2Level * ladder2Profit;
           }

      double desiredTakeProfit = OrderTakeProfit();
      if(nextProfitTargetUSD > 0.0)
        {
         double nextTP = CalculateDefaultProfitTargetPrice(orderType, OrderOpenPrice(), orderLots, nextProfitTargetUSD);
         double minimumTPDistance = GetRequiredStopDistance();
         if(nextTP > 0.0)
           {
            bool validNextTP = true;
            if(orderType == OP_BUY && nextTP - Ask < minimumTPDistance)
               validNextTP = false;
            if(orderType == OP_SELL && Bid - nextTP < minimumTPDistance)
               validNextTP = false;
            if(validNextTP)
              {
               if(orderType == OP_BUY)
                 {
                  if(desiredTakeProfit <= 0.0 || nextTP > desiredTakeProfit + Point)
                     desiredTakeProfit = nextTP;
                 }
               else
                  if(orderType == OP_SELL)
                    {
                     if(desiredTakeProfit <= 0.0 || nextTP < desiredTakeProfit - Point)
                        desiredTakeProfit = nextTP;
                    }
              }
           }
        }

      bool takeProfitNeedsModify = false;
      if(orderType == OP_BUY)
        {
         if(desiredTakeProfit > 0.0 && (OrderTakeProfit() <= 0.0 || desiredTakeProfit > OrderTakeProfit() + Point))
            takeProfitNeedsModify = true;
        }
      else
         if(orderType == OP_SELL)
           {
            if(desiredTakeProfit > 0.0 && (OrderTakeProfit() <= 0.0 || desiredTakeProfit < OrderTakeProfit() - Point))
               takeProfitNeedsModify = true;
           }

      if(existingLockedProfit >= lockedProfit && !takeProfitNeedsModify)
         continue;
      double priceDistance = lockedProfit * 100.0;
      if(priceDistance <= 0)
         continue;
      double stopLevel = GetRequiredStopDistance();
      double newStopLoss = 0.0;
      bool needStopLossModify = (existingLockedProfit < lockedProfit);

      if(orderType == OP_BUY)
        {
         if(!needStopLossModify)
            newStopLoss = OrderStopLoss();
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
            newStopLoss = OrderStopLoss();
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
   static int cachedDir  = 0;
   static int cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedDir;

   if(Bars < SSLPeriod + 20)
     {
      cachedDir  = 0;
      cachedTick = CurrentTickSequence;
      return 0;
     }

   double up, down;
   int hlv;
   CalculateSSL(0, up, down, hlv);
   if(up > down)
      cachedDir = 1;
   else
      if(up < down)
         cachedDir = -1;
      else
         cachedDir = 0;

   cachedTick = CurrentTickSequence;
   return cachedDir;
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
void CheckEquitySurplusReset()
  {
   double balance = AccountBalance();
   double equity  = AccountEquity();

   double buyLots  = GetTotalLots(OP_BUY);
   double sellLots = GetTotalLots(OP_SELL);

   double totalEALots = buyLots + sellLots;

// Every 0.02 lots = 1% equity target
   double targetSteps = (totalEALots * 100.0);// / 2.0;

// Minimum target = 1%
   if(targetSteps < 1.0)
      targetSteps = 1.0;

   double targetPercent = 0.01 * targetSteps;
   double equityTarget  = balance * (1.0 + targetPercent);

   if(balance > 0.0 && equity >= equityTarget)
     {
      Print(
         "EQUITY SURPLUS TARGET HIT",
         " | Balance=$", DoubleToString(balance, 2),
         " | Equity=$", DoubleToString(equity, 2),
         " | BuyLots=", DoubleToString(buyLots, 2),
         " | SellLots=", DoubleToString(sellLots, 2),
         " | TotalLots=", DoubleToString(totalEALots, 2),
         " | TargetSteps=", DoubleToString(targetSteps, 2),
         " | Target=", DoubleToString(targetPercent * 100.0, 2), "%",
         " | RequiredEquity=$", DoubleToString(equityTarget, 2)
      );

      ModifyOpenOrdersToSecureProfit();
     }
  }
//+------------------------------------------------------------------+
//| Check if Equity exceeds Balance by 5% or more                    |
//+------------------------------------------------------------------+
// void CheckEquitySurplusReset()
//   {
//    double balance = AccountBalance();
//    double equity  = AccountEquity();

// // Check if equity is more than 5% above the account balance
//    if(balance > 0.0 && equity >= balance * (1.00+(0.01*GetTotalEAOrders)))
//      {
//       Print("RARE EVENT: Equity ($", equity, ") exceeds Balance ($", balance, ") by 5%+. Triggering EMAladder target hit.");

//          ModifyOpenOrdersToSecureProfit();


//       // Call your 5% ladder reset / target hit process
//       // Manage5PercentLadderReset();
//      }
//   }
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

      if(isBuy)
         OpenBuy();
      else
         OpenSell();

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


// isMOMOrder is now a global variable (declared at top of file)

//+------------------------------------------------------------------+
//| MISSING FUNCTIONS                                                |
//+------------------------------------------------------------------+
void DrawMomentumMarkers()
  {
   static datetime lastMomentumBar = 0;
   if(lastMomentumBar == Time[0])
      return;
   lastMomentumBar = Time[0];

   int lookback = 500; // Number of historical bars to scan
   if(lookback > Bars - 1)
      lookback = Bars - 1;

// Start at 1 to evaluate only closed candles and prevent repainting
   for(int i = lookback; i >= 1; i--)
     {
      string objName = "MOM_MARKER_" + IntegerToString((int)Time[i]);

      if(IsStrongMomentum(OP_BUY, i))
        {
         if(ObjectFind(0, objName) < 0) // Only draw if it doesn't already exist
           {
            ObjectCreate(0, objName, OBJ_ARROW, 0, Time[i], Low[i] - (30 * Point));
            ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 233); // Wingdings Up Arrow
            ObjectSetInteger(0, objName, OBJPROP_COLOR, clrLime);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
            //if(EMADirection == 1)// && !IsEmaWEAKDistanceReduced50PercentFromPeak(1))
              {



              }
           }

         isMOMOrder=true;
         GlobalSSLDirection=1;
         // Print("MOM Buy open");
         OpenBuy("MOM_BUY");

         isMOMOrder=false;




        }
      else
         if(IsStrongMomentum(OP_SELL, i))
           {
            if(ObjectFind(0, objName) < 0)
              {
               ObjectCreate(0, objName, OBJ_ARROW, 0, Time[i], High[i] + (30 * Point));
               ObjectSetInteger(0, objName, OBJPROP_ARROWCODE, 234); // Wingdings Down Arrow
               ObjectSetInteger(0, objName, OBJPROP_COLOR, clrRed);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, 2);
               GlobalSSLDirection=-1;
               // if(EMADirection == -1)// && !IsEmaWEAKDistanceReduced50PercentFromPeak(-1))

              }
              {

               isMOMOrder=true;
               // Print("MOM Sell open");
               OpenSell("MOM_SELL");
               isMOMOrder=false;

              }

           }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsStrongMomentum(int direction, int shift = 1)
  {
   double adxMain = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MAIN, shift);
   double adxPlus = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_PLUSDI, shift);
   double adxMin  = iADX(Symbol(), Period(), 14, PRICE_CLOSE, MODE_MINUSDI, shift);

   double candleRange = High[shift] - Low[shift];
   double candleBody  = MathAbs(Open[shift] - Close[shift]);
   bool isSolidCandle = false;

   if(candleRange > 0.0)
      isSolidCandle = (candleBody / candleRange) >= 0.75;

   if(direction == OP_BUY)
      return (adxMain > 25.0 && adxPlus > adxMin && isSolidCandle);
   else
      if(direction == OP_SELL)
         return (adxMain > 25.0 && adxMin > adxPlus && isSolidCandle);

   return false;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetEmaAngleDegrees(int lookbackBars = 5)
  {
   if(lookbackBars <= 0)
      return 0.0;
   double emaCurrent  = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   double emaPrevious = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, lookbackBars);
   if(emaCurrent <= 0 || emaPrevious <= 0)
      return 0.0;

   double atr = iATR(Symbol(), Period(), 14, 1);
   if(atr <= 0)
      atr = Point * 10;
   double normalizedRise = (emaCurrent - emaPrevious) / atr;
   double slope = normalizedRise / (double)lookbackBars;
   double angle = MathArctan(slope) * 180.0 / 3.14159265358979323846;
   angle = angle * 2.0;

   if(angle > 85.0)
      angle = 85.0;
   if(angle < -85.0)
      angle = -85.0;
   return NormalizeDouble(angle, 2);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateMomentumBackground()
  {
   bool strongBuy  = IsStrongMomentum(OP_BUY);
   bool strongSell = IsStrongMomentum(OP_SELL);
   if(!strongBuy && !strongSell)
      return;

   string objName = PREFIX + "MOM_" + IntegerToString((int)Time[0]);
   color momColor = strongBuy ? C'0,40,0' : C'40,0,0';
   double buffer = (High[0] - Low[0]) * 0.1;
   double topPrice = High[0] + buffer;
   double botPrice = Low[0] - buffer;
   datetime endTime = Time[0] + Period() * 60;

   if(ObjectFind(0, objName) < 0)
     {
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, Time[0], topPrice, endTime, botPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, momColor);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
     }
   else
     {
      ObjectMove(0, objName, 0, Time[0], topPrice);
      ObjectMove(0, objName, 1, endTime, botPrice);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, momColor);
     }
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
   UpdateOrderCacheIfNeeded();
   if(orderType == OP_BUY)
      return g_orderCache.buyLots;
   if(orderType == OP_SELL)
      return g_orderCache.sellLots;
   return g_orderCache.buyLots + g_orderCache.sellLots;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void UpdateDashboard(DailyProtectionState &state)
  {
   UpdateOrderCacheIfNeeded();
   int totalOrders   = g_orderCache.totalOrders;
   int buyOrders     = g_orderCache.buyOrders;
   int sellOrders    = g_orderCache.sellOrders;
   int pendingOrders = g_orderCache.buyPending + g_orderCache.sellPending;
   double netProfit  = g_orderCache.buyPL + g_orderCache.sellPL;
   color pnlColor=netProfit>0?clrLime:netProfit<0?clrTomato:clrWhite;
   int currentSSLDirection=GlobalSSLDirection;
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

   if(TradeMonitoringLog!="")
     {
      statusText="PAUSE - Waiting for Angle>2";
      statusColor=clrGold;
     }
   else

      if(!EnableTrading)
        {
         statusText="TRADING DISABLED";
         statusColor=clrTomato;
        }
      else
         if(g_dailyEquityTradingBlocked)
           {
            statusText="DAY TRADING PAUSED";
            statusColor=clrTomato;
           }
         else
            if(TradingHaltedUntilNextFlip)
              {
               statusText="EMA LADDER HALT";
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

   int x=DashboardRightGap, y=DashboardTopGap, tx=x+12, w=DashboardWidth, panelHeight=950;
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
      dashboardMomentumDiff = (dashboardDirection == 1) ? Global30MinDiffBuy : Global30MinDiffSell;
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
      dashboardSuggestedLot = MathMin(dashboardSuggestedLot, 0.02);

   int dashboardLotMultiplier=(int)(AccountEquity()/AccountMultiplierLOT);
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

   if(GetCachedPatternDirection()==1)
      strong=strong+" Double";
   else
      if(GetCachedPatternDirection()==-1)
         strong=strong+" - ";

   if(IsEmaWEAKDistanceReduced50PercentFromPeak())
      strong=" Weak";
   else
      strong= " STRONG";

   string txLock="FLIP Step "+FlipLadderStepUSD*balancelomultipler+"% Day Stop $"+DailyEquityStopUSD*balancelomultipler+""+" Flip Stop $"+TargetProfitPerFlipUSD*balancelomultipler+"";

   static bool s_dashRedesignV4Reset = false;
   if(!s_dashRedesignV4Reset)
     {
      DeleteDashboardObjects();
      s_dashRedesignV4Reset = true;
     }

   if(FlipLadderStepUSD <= 0)
      FlipLadderStepUSD = 5;
   int currEmaLvl = (int)MathFloor(HighestCycleProfitUSD / (FlipLadderStepUSD * balancelomultipler));
   double emaLockedPrf = (currEmaLvl >= 1) ? (currEmaLvl - FlipStepbackLevelCount) * (FlipLadderStepUSD * balancelomultipler) : 0.0;
   double emaNextTarget = (currEmaLvl + 1) * FlipLadderStepUSD * balancelomultipler;
   double totalCycleProfit = profitAfterFlip + GetEAFloatingPL();

   // Scan order status for regular baskets, pending orders, recovery orders, and support orders
   int regBuyOrders = 0;
   int regSellOrders = 0;
   double regBuyLots = 0.0;
   double regSellLots = 0.0;
   double regBuyPL = 0.0;
   double regSellPL = 0.0;

   int pendingBuyCount = 0;
   int pendingSellCount = 0;
   double pendingBuyPrice = 0.0;
   double pendingSellPrice = 0.0;

   int recCount = 0;
   int recTicket = 0;
   int recType = -1;
   double recLots = 0.0;
   double recPL = 0.0;

   int flipCount = 0;
   int flipTicket = 0;
   double flipLots = 0.0;
   double flipPL = 0.0;

   for(int ordIdx = OrdersTotal() - 1; ordIdx >= 0; ordIdx--)
     {
      if(!OrderSelect(ordIdx, SELECT_BY_POS, MODE_TRADES))
         continue;
      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType = OrderType();
      int tkt = OrderTicket();
      string cmt = OrderComment();
      double lts = OrderLots();
      double pl = OrderProfit() + OrderSwap() + OrderCommission();
      double oPrice = OrderOpenPrice();

      if(oType == OP_BUY)
        {
         if(IsAnyRecoveryOrder(tkt, cmt))
           {
            recCount++;
            recTicket = tkt;
            recType = OP_BUY;
            recLots += lts;
            recPL += pl;
           }
         else if(IsFLIPBasketSupportOrder(tkt, cmt))
           {
            flipCount++;
            flipTicket = tkt;
            flipLots += lts;
            flipPL += pl;
            regBuyOrders++;
            regBuyLots += lts;
            regBuyPL += pl;
           }
         else
           {
            regBuyOrders++;
            regBuyLots += lts;
            regBuyPL += pl;
           }
        }
      else if(oType == OP_SELL)
        {
         if(IsAnyRecoveryOrder(tkt, cmt))
           {
            recCount++;
            recTicket = tkt;
            recType = OP_SELL;
            recLots += lts;
            recPL += pl;
           }
         else if(IsFLIPBasketSupportOrder(tkt, cmt))
           {
            flipCount++;
            flipTicket = tkt;
            flipLots += lts;
            flipPL += pl;
            regSellOrders++;
            regSellLots += lts;
            regSellPL += pl;
           }
         else
           {
            regSellOrders++;
            regSellLots += lts;
            regSellPL += pl;
           }
        }
      else if(oType == OP_BUYSTOP || oType == OP_BUYLIMIT)
        {
         pendingBuyCount++;
         pendingBuyPrice = oPrice;
        }
      else if(oType == OP_SELLSTOP || oType == OP_SELLLIMIT)
        {
         pendingSellCount++;
         pendingSellPrice = oPrice;
        }
     }

   w = MathMax(DashboardWidth, 355);
   panelHeight = 460;
   x = DashboardRightGap;
   y = DashboardTopGap;
   tx = x + 12;

   // Base Background Panel
   CreateDashboardPanel(DASH_PREFIX+"PANEL", x, y, w, panelHeight, C'14,18,24');

   // Header Bar
   CreateDashboardPanel(DASH_PREFIX+"HEADER", x, y, w, 36, C'20,55,90');
   string eaTitle = "SSL PRO SCALPER | " + Symbol() + " " + TimeframeToString(Period());
   CreateDashboardLabel(DASH_PREFIX+"TITLE", eaTitle, tx, y+4, 9, clrWhite);
   string priceStatus = StringFormat("BID: %." + IntegerToString(Digits) + "f | ASK: %." + IntegerToString(Digits) + "f | SPR: %d pts", Bid, Ask, (int)MarketInfo(Symbol(), MODE_SPREAD));
   CreateDashboardLabel(DASH_PREFIX+"PRICE", priceStatus, tx, y+19, 8, clrLightGray);

   // Status Line
   CreateDashboardLabel(DASH_PREFIX+"STATUS", "EA STATUS   : " + statusText, tx, y+39, 9, statusColor);

   // ==========================================================
   // SECTION 1: CAPITAL & EQUITY TARGETS
   // ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_ACC", x, y+58, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"ACC_H", "--- CAPITAL & EQUITY TARGETS ---", tx, y+60, 8, clrAqua);

   string balEqStr = StringFormat("BALANCE / EQ: $%.2f / $%.2f (%dX)", AccountBalance(), AccountEquity(), balancelomultipler);
   CreateDashboardLabel(DASH_PREFIX+"BALEQ", balEqStr, tx, y+78, 8, clrWhite);

   string tgtEqStr = StringFormat("TARGET EQ   : $%.2f (Hits: %d) | Day: %s$%.2f (%s%.1f%%)", gbltargetEquity, gbltargetEquityCounter, (dayPL >= 0 ? "+" : "-"), MathAbs(dayPL), (dayPL >= 0 ? "+" : ""), dayPLPct);
   color tgtClr = (gbltargetEquityCounter > 0 || dayPL >= 0) ? clrLime : clrTomato;
   CreateDashboardLabel(DASH_PREFIX+"TGTEQ", tgtEqStr, tx, y+94, 8, tgtClr);

   string cycleStr = StringFormat("CYCLE / LOCK: %s$%.2f / Next: $%.2f | Lock: $%.2f", (totalCycleProfit >= 0 ? "+" : "-"), MathAbs(totalCycleProfit), emaNextTarget, emaLockedPrf);
   CreateDashboardLabel(DASH_PREFIX+"LAD_CYCLE", cycleStr, tx, y+110, 8, (totalCycleProfit >= 0 ? clrLime : clrTomato));

   // ==========================================================
   // SECTION 2: BASKETS & FLOATING P/L ($1x TARGET)
   // ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_BSK", x, y+130, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"BSK_H", "--- BASKETS & FLOATING P/L ($1x TARGET) ---", tx, y+132, 8, clrAqua);

   double targetProfit = InpBasketProfitTargetUSD * (balancelomultipler > 0 ? balancelomultipler : 1);

   string buyStatus = (regBuyPL >= targetProfit && regBuyOrders > 0) ? "[READY TO CLOSE]" : StringFormat("[Tgt: >$%.2f]", targetProfit);
   color buyClr = (regBuyPL >= targetProfit && regBuyOrders > 0) ? clrLime : (regBuyPL > 0 ? clrDeepSkyBlue : (regBuyOrders > 0 ? clrTomato : clrSilver));
   string buyBskStr = StringFormat("BUY BASKET  : (%d | %.2fL) %s$%.2f  %s", regBuyOrders, regBuyLots, (regBuyPL >= 0 ? "+" : "-"), MathAbs(regBuyPL), buyStatus);
   CreateDashboardLabel(DASH_PREFIX+"BSK_BUY", buyBskStr, tx, y+150, 8, buyClr);

   string sellStatus = (regSellPL >= targetProfit && regSellOrders > 0) ? "[READY TO CLOSE]" : StringFormat("[Tgt: >$%.2f]", targetProfit);
   color sellClr = (regSellPL >= targetProfit && regSellOrders > 0) ? clrLime : (regSellPL > 0 ? clrDeepSkyBlue : (regSellOrders > 0 ? clrTomato : clrSilver));
   string sellBskStr = StringFormat("SELL BASKET : (%d | %.2fL) %s$%.2f  %s", regSellOrders, regSellLots, (regSellPL >= 0 ? "+" : "-"), MathAbs(regSellPL), sellStatus);
   CreateDashboardLabel(DASH_PREFIX+"BSK_SELL", sellBskStr, tx, y+166, 8, sellClr);

   double netPL = regBuyPL + regSellPL;
   double totLots = regBuyLots + regSellLots + recLots;
   string netStr = StringFormat("NET FLOAT   : %s$%.2f | Orders: %d/%d (Lots: %.2fL)", (netPL >= 0 ? "+" : "-"), MathAbs(netPL), totalOrders, MaxOpenOrders, totLots);
   CreateDashboardLabel(DASH_PREFIX+"FLOAT", netStr, tx, y+182, 8, (netPL >= 0 ? clrLime : clrTomato));

   // ==========================================================
   // SECTION 3: PENDING & SPECIAL ORDERS
   // ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_SPC", x, y+202, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"SPC_H", "--- PENDING & SPECIAL ORDERS ---", tx, y+204, 8, clrAqua);

   string pendStr = "NONE (Market Active)";
   color pendClr = clrSilver;
   if(pendingBuyCount > 0 && pendingSellCount > 0)
     {
      pendStr = StringFormat("BUY & SELL STOPS Active ($%.0f Gap)", SSLLongShortPendingGapRaw);
      pendClr = clrGold;
     }
   else if(pendingBuyCount > 0)
     {
      pendStr = StringFormat("BUY STOP @ %." + IntegerToString(Digits) + "f ($%.0f Gap)", pendingBuyPrice, SSLLongShortPendingGapRaw);
      pendClr = clrDeepSkyBlue;
     }
   else if(pendingSellCount > 0)
     {
      pendStr = StringFormat("SELL STOP @ %." + IntegerToString(Digits) + "f ($%.0f Gap)", pendingSellPrice, SSLLongShortPendingGapRaw);
      pendClr = clrTomato;
     }
   CreateDashboardLabel(DASH_PREFIX+"PEND_SSL", "SSL PENDING : " + pendStr, tx, y+222, 8, pendClr);

   string recStr = "NONE";
   color recClr = clrSilver;
   if(recCount > 0)
     {
      recStr = StringFormat("#%d (%s %.2fL) %s$%.2f [SL Gap $%.0f]", recTicket, (recType == OP_BUY ? "BUY" : "SELL"), recLots, (recPL >= 0 ? "+" : "-"), MathAbs(recPL), RecoveryStopLossDistanceRaw);
      recClr = (recPL >= 0 ? clrLime : clrTomato);
     }
   CreateDashboardLabel(DASH_PREFIX+"REC_ORD", "RECOVERY    : " + recStr, tx, y+238, 8, recClr);

   string flipStr = "NONE";
   color flipClr = clrSilver;
   if(flipCount > 0)
     {
      flipStr = StringFormat("#%d (%.2fL) %s$%.2f [Step Trail Active]", flipTicket, flipLots, (flipPL >= 0 ? "+" : "-"), MathAbs(flipPL));
      flipClr = (flipPL >= 0 ? clrLime : clrGold);
     }
   CreateDashboardLabel(DASH_PREFIX+"FLIP_ORD", "FLIP SUPPORT: " + flipStr, tx, y+254, 8, flipClr);

   // ==========================================================
   // SECTION 4: TREND & SIGNALS
   // ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_SIG", x, y+274, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"SIG_H", "--- TREND & SIGNALS ---", tx, y+276, 8, clrAqua);

   string globalEmaStr = "FLAT / NEUTRAL (0)";
   color globalEmaClr = clrGold;
   if(EMADirection == 1)
     {
      globalEmaStr = "BULLISH / BUY (+1)";
      globalEmaClr = clrLime;
     }
   else if(EMADirection == -1)
     {
      globalEmaStr = "BEARISH / SELL (-1)";
      globalEmaClr = clrTomato;
     }
   double flipDist = EMAflipdistance();
   string emaTrendStr = StringFormat("GLOBAL EMA  : %s | Gap: $%.1f", globalEmaStr, flipDist);
   CreateDashboardLabel(DASH_PREFIX+"EMA_DIR", emaTrendStr, tx, y+294, 8, globalEmaClr);

   bool isEmaWeak = IsEmaWEAKDistanceReduced50PercentFromPeak();
   string emaWeakStrongStr = isEmaWeak ? "WEAK (50% Retraced)" : "STRONG";
   color emaWeakStrongClr = isEmaWeak ? clrTomato : clrLime;
   string emaStrText = StringFormat("EMA STRENGTH: %s | Angle: %+.1f deg", emaWeakStrongStr, GlobalEmaAngle30);
   CreateDashboardLabel(DASH_PREFIX+"EMA_STR", emaStrText, tx, y+310, 8, emaWeakStrongClr);

   string sslSignalStr = "NONE (0)";
   color sslSignalClr = clrSilver;
   if(currentSSLDirection > 0)
     {
      sslSignalStr = "BUY / LONG (+1)";
      sslSignalClr = clrDeepSkyBlue;
     }
   else if(currentSSLDirection < 0)
     {
      sslSignalStr = "SELL / SHORT (-1)";
      sslSignalClr = clrTomato;
     }
   CreateDashboardLabel(DASH_PREFIX+"SSL", "SSL SIGNAL  : " + sslSignalStr, tx, y+326, 8, sslSignalClr);

   bool hasRedLine = IsLsdSweepRedLinePresent();
   bool hasGreenLine = IsLsdSweepGreenLinePresent();
   string lsdSigName = (g_rememberedSweepSignal != "" ? g_rememberedSweepSignal : (g_lastSweepType != "" ? g_lastSweepType : "NONE"));
   color lsdClr = (lsdSigName == "SSLS") ? clrLime : (lsdSigName == "BSLS" ? clrTomato : clrSilver);
   string lineDesc = hasRedLine ? "RED (Close BUY)" : (hasGreenLine ? "GREEN (Close SELL)" : "Scanning");
   string lsdSummary = StringFormat("LSD SWEEP   : %s | Line: %s", lsdSigName, lineDesc);
   CreateDashboardLabel(DASH_PREFIX+"SWEEP_EVT", lsdSummary, tx, y+342, 8, lsdClr);

   // ==========================================================
   // SECTION 5: RISK & SYSTEM GUARDS
   // ==========================================================
   CreateDashboardPanel(DASH_PREFIX+"SEC_RSK", x, y+362, w, 18, C'28,38,50');
   CreateDashboardLabel(DASH_PREFIX+"RSK_H", "--- RISK & SYSTEM GUARDS ---", tx, y+364, 8, clrAqua);

   string slModStr = StringFormat("SL ANTI-SPAM: Min Mod Gap $%.2f Raw [ACTIVE]", MinimumSLModifyGapRaw);
   CreateDashboardLabel(DASH_PREFIX+"SL_MOD", slModStr, tx, y+382, 8, clrAqua);

   string safeCloseStr = "SAFE CLOSE  : SL at Live Price + $50.00 Raw [ACTIVE]";
   CreateDashboardLabel(DASH_PREFIX+"SAFE_CLOSE", safeCloseStr, tx, y+398, 8, clrAqua);

   string dayRiskStr = StringFormat("DAY STOP/RSK: Stop $%.0f | Floor $%.2f | Room $%.2f [%s]", DailyEquityStopUSD * balancelomultipler, DayProfitLadderProtectionEquity, riskRemaining, (HasBasketNewOrderLossLimit() ? "LOCKED" : "OK"));
   color dayRiskClr = HasBasketNewOrderLossLimit() ? clrTomato : clrLime;
   CreateDashboardLabel(DASH_PREFIX+"DAY_STOP", dayRiskStr, tx, y+414, 8, dayRiskClr);

   string srvStr = StringFormat("SERVER/CONN : %s", serverText);
   CreateDashboardLabel(DASH_PREFIX+"SERVER", srvStr, tx, y+430, 8, serverColor);

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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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
//| Check if price expanded away after EMA flip (>= 60 mins), and    |
//| is now coming back down (distance reduced by 50%+ from peak)     |
//+------------------------------------------------------------------+
bool IsEmaWEAKDistanceReduced50PercentFromPeak(int orderType = -1)
  {
   if(EmaFlipTime == 0)
      return false;




   if(!emaflipstrongorweak())// if weak then return true , if strong double check again
     {
      return true;//weak
     }
   else
      return false;//strong

   RefreshRates();

   int flipShift = iBarShift(Symbol(), Period(), EmaFlipTime, false);
   if(flipShift < 1 || flipShift >= Bars)
      return false;

   double maxDistance = 0.0;
   for(int i = flipShift; i >= 1; i--)
     {
      double historicalEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, i);
      if(historicalEma <= 0.0)
         continue;

      double candleExtreme = (EMADirection == 1) ? High[i] : ((EMADirection == -1) ? Low[i] : Close[i]);
      double dist = MathAbs(candleExtreme - historicalEma);




      if(dist > maxDistance)
         maxDistance = dist;
     }

   if(maxDistance <= Point * 10)
      return false;

   double currentEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(currentEma <= 0.0)
      return false;

// Fix: Properly resolve price based on active EMADirection if orderType is omitted
   double currentPrice = Bid;
   if(orderType == OP_BUY)
      currentPrice = Ask;
   else
      if(orderType == OP_SELL)
         currentPrice = Bid;
      else
         currentPrice = (EMADirection == 1) ? Bid : Ask;

   double currentDistance = MathAbs(currentPrice - currentEma);

   if(currentDistance <= (maxDistance * 0.50))
      return true;

   return false;
  }
//+------------------------------------------------------------------+
//| Check if distance between price and EMA200 has reduced by 50%   |
//| compared to the distance at the time of the last EMA flip        |
//+------------------------------------------------------------------+
bool IsEmaDistanceReduced50PercentSinceFlipold(int orderType = -1)
  {
// 1. Ensure an EMA flip has actually occurred and at least 1 hour has passed since it
   if(EmaFlipTime == 0 || TimeCurrent() - EmaFlipTime < 3600)
      return false;

   RefreshRates();

// 2. Current Live Price and EMA200
   double currentEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(currentEma <= 0.0)
      return false;

   double currentPrice = (orderType == OP_BUY) ? Ask : (orderType == OP_SELL ? Bid : Close[0]);
   double currentDistance = MathAbs(currentPrice - currentEma);

// 3. Find the historical bar corresponding to the exact EmaFlipTime
   int flipBarShift = iBarShift(Symbol(), Period(), EmaFlipTime, false);
   if(flipBarShift < 0 || flipBarShift >= Bars)
      return false;

// 4. Historical Price and EMA200 at the EMA flip time
   double flipEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, flipBarShift);
   double flipPrice = iClose(Symbol(), Period(), flipBarShift);
   if(flipEma <= 0.0 || flipPrice <= 0.0)
      return false;

   double flipDistance = MathAbs(flipPrice - flipEma);

// Avoid zero or negligible base distances
   if(flipDistance <= Point)
      return false;

// 5. Return true if current distance has contracted to 50% or less of the distance at flip time
   if(currentDistance <= (flipDistance * 0.50))
      return true;

   return false;
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
   double buyLots=0,sellLots=0,buyPL=0,sellPL=0,netPL=0;
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
      double orderPL = (type==OP_BUY || type==OP_SELL) ? (OrderProfit()+OrderSwap()+OrderCommission()) : 0.0;
      if(type==OP_BUY)
        {
         buyCount++;
         buyLots+=OrderLots();
         buyPL+=orderPL;
        }
      else
         if(type==OP_SELL)
           {
            sellCount++;
            sellLots+=OrderLots();
            sellPL+=orderPL;
           }
         else
            pendingCount++;
      if(type==OP_BUY || type==OP_SELL)
         netPL+=orderPL;
     }
   int x=LeftDashboardX, y=LeftDashboardY, tx=x+12, width=MathMax(LeftDashboardWidth+250, 580), panelHeight=rows*20+132;
   color pnlColor=clrWhite;
   if(netPL>0)
      pnlColor=clrLime;
   else
      if(netPL<0)
         pnlColor=clrTomato;

   string netPLStr  = (netPL>=0  ? "+" : "") + DoubleToString(netPL,2);
   string buyPLStr  = (buyPL>=0  ? "+" : "") + DoubleToString(buyPL,2);
   string sellPLStr = (sellPL>=0 ? "+" : "") + DoubleToString(sellPL,2);

   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"PANEL", x, y, width, panelHeight, C'12,16,22');
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"HEADER", x, y, width, 38, C'25,70,115');
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TITLE", "LIVE POSITION MONITOR", tx, y+8, 11, clrWhite);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SYMBOL", Symbol()+"  |  "+TimeframeToString(Period()), x+width-112, y+10, 8, clrLightGray);
   CreateLeftLivePanel(LEFT_LIVE_PREFIX+"SUMMARYBAR", x, y+38, width, 42, C'25,31,42');

   // Top Row: Buy Lot and Buy P/L , sell LOT and sell P/l - Net P/L
   string topRowText = "BUY " + DoubleToString(buyLots,2) + " (P/L " + buyPLStr + ") , SELL " + DoubleToString(sellLots,2) + " (P/L " + sellPLStr + ") - NET " + netPLStr;
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"TOTALS", topRowText, tx, y+45, 9, pnlColor);

   // Second Row: Orders Count Summary
   string summaryText = "ORDERS " + IntegerToString(total) + "/" + IntegerToString(MaxOpenOrders) +
                        "   BUY " + IntegerToString(buyCount) +
                        "   SELL " + IntegerToString(sellCount) +
                        "   PEND " + IntegerToString(pendingCount);
   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"SUMMARY", summaryText, tx, y+62, 8, clrWhite);

   CreateLeftLiveLabel(LEFT_LIVE_PREFIX+"HEAD", "TYPE     LOT       OPEN       SL       GAP        P/L     VERIFIED", tx, y+88, 8, clrSilver);

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
      double pl=0;
      if(type==OP_BUY || type==OP_SELL)
         pl=OrderProfit()+OrderSwap()+OrderCommission();

      double slDiffPoints=0;
      if(sl>0)
         slDiffPoints=MathAbs(open-sl)/Point/100;

      string slDiffText="-";
      if(sl>0)
         slDiffText=DoubleToString(slDiffPoints,0);

      int currentTicket=OrderTicket();
      datetime currentOpenTime=OrderOpenTime();
      datetime bestPrevTime=0;
      int bestPrevTicket=0;
      double prevSameOrderPrice=-1.0;

      for(int k=OrdersTotal()-1; k>=0; k--)
        {
         if(k==j)
            continue;
         if(!OrderSelect(k,SELECT_BY_POS,MODE_TRADES))
            continue;
         if(OrderSymbol()!=Symbol() || OrderMagicNumber()!=MagicNumber)
            continue;
         int prevType=OrderType();
         bool sameDir=false;
         if((type==OP_BUY || type==OP_BUYSTOP || type==OP_BUYLIMIT) &&
            (prevType==OP_BUY || prevType==OP_BUYSTOP || prevType==OP_BUYLIMIT))
            sameDir=true;
         else if((type==OP_SELL || type==OP_SELLSTOP || type==OP_SELLLIMIT) &&
                 (prevType==OP_SELL || prevType==OP_SELLSTOP || prevType==OP_SELLLIMIT))
            sameDir=true;

         if(!sameDir)
            continue;

         datetime ot=OrderOpenTime();
         int tk=OrderTicket();
         if(ot<currentOpenTime || (ot==currentOpenTime && tk<currentTicket))
           {
            if(bestPrevTime==0 || ot>bestPrevTime || (ot==bestPrevTime && tk>bestPrevTicket))
              {
               bestPrevTime=ot;
               bestPrevTicket=tk;
               prevSameOrderPrice=OrderOpenPrice();
              }
           }
        }
      if(!OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
         continue;

      string gapText="-";
      if(prevSameOrderPrice>0.0)
        {
         int gapDecimals=(Digits<=2) ? 1 : Digits;
         gapText=DoubleToString(MathAbs(open-prevSameOrderPrice),gapDecimals);
        }

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

      verifiedStatus=OrderComment();
      string rowText=StringFormat("%-7s %5.2f %10s %10s %10s %8s", typeText, lots, DoubleToString(open,Digits), slDiffText, gapText, plText);
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
//| LIQUIDITY SWEEP DETECTOR & GLOBAL VARIABLE MANAGEMENT           |
//| Replicated from V-EMASingleOrder.mq4                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ManageSweepGlobalVariables: Sets both EA global variables and   |
//| MT4 Terminal Global Variables (viewable via F3) with SWEEP       |
//| buy signal or SWEEP sell signal.                                 |
//+------------------------------------------------------------------+
void ManageSweepGlobalVariables(string signalType)
  {
   if(signalType == "SSLS" || signalType == "SSL" || signalType == "BUY" || signalType == "SWEEP buy signal")
     {
      GlobalSweepBuy    = true;
      GlobalSweepSell   = false;
      GlobalSweepSignal = "SWEEP buy signal";

      if(InpManageSweepTerminalGlobals)
        {
         GlobalVariableSet(Symbol() + "_SWEEP_SIGNAL", 1.0);
         GlobalVariableSet(Symbol() + "_SWEEP_BUY_SIGNAL", 1.0);
         GlobalVariableSet(Symbol() + "_SWEEP_SELL_SIGNAL", 0.0);
         GlobalVariableSet("SWEEP_SIGNAL", 1.0);
         GlobalVariableSet("SWEEP_BUY_SIGNAL", 1.0);
         GlobalVariableSet("SWEEP_SELL_SIGNAL", 0.0);
        }
     }
   else
      if(signalType == "BSLS" || signalType == "BSL" || signalType == "SELL" || signalType == "SWEEP sell signal")
        {
         GlobalSweepBuy    = false;
         GlobalSweepSell   = true;
         GlobalSweepSignal = "SWEEP sell signal";

         if(InpManageSweepTerminalGlobals)
           {
            GlobalVariableSet(Symbol() + "_SWEEP_SIGNAL", -1.0);
            GlobalVariableSet(Symbol() + "_SWEEP_BUY_SIGNAL", 0.0);
            GlobalVariableSet(Symbol() + "_SWEEP_SELL_SIGNAL", 1.0);
            GlobalVariableSet("SWEEP_SIGNAL", -1.0);
            GlobalVariableSet("SWEEP_BUY_SIGNAL", 0.0);
            GlobalVariableSet("SWEEP_SELL_SIGNAL", 1.0);
           }
        }
      else
        {
         GlobalSweepBuy    = false;
         GlobalSweepSell   = false;
         GlobalSweepSignal = "None";

         if(InpManageSweepTerminalGlobals)
           {
            GlobalVariableSet(Symbol() + "_SWEEP_SIGNAL", 0.0);
            GlobalVariableSet(Symbol() + "_SWEEP_BUY_SIGNAL", 0.0);
            GlobalVariableSet(Symbol() + "_SWEEP_SELL_SIGNAL", 0.0);
            GlobalVariableSet("SWEEP_SIGNAL", 0.0);
            GlobalVariableSet("SWEEP_BUY_SIGNAL", 0.0);
            GlobalVariableSet("SWEEP_SELL_SIGNAL", 0.0);
           }
        }
  }

//+------------------------------------------------------------------+
//| ClearSweepGlobalVariables: Cleans up Terminal Global Variables  |
//+------------------------------------------------------------------+
void ClearSweepGlobalVariables()
  {
   if(InpManageSweepTerminalGlobals)
     {
      GlobalVariableDel(Symbol() + "_SWEEP_SIGNAL");
      GlobalVariableDel(Symbol() + "_SWEEP_BUY_SIGNAL");
      GlobalVariableDel(Symbol() + "_SWEEP_SELL_SIGNAL");
      GlobalVariableDel("SWEEP_SIGNAL");
      GlobalVariableDel("SWEEP_BUY_SIGNAL");
      GlobalVariableDel("SWEEP_SELL_SIGNAL");
     }
  }

//+------------------------------------------------------------------+
//| GetActualEmaFlipTime: Scans backward to identify exact EMA flip |
//+------------------------------------------------------------------+
datetime GetActualEmaFlipTime(int targetType = 0)
  {
   int dir = targetType;
   if(dir == OP_BUY)
      dir = 1;
   else
      if(dir == OP_SELL)
         dir = -1;
      else
         if(dir == 0)
            dir = EMADirection;
   if(dir == 0)
      dir = LastTrackedEmaDirection;

   int lookback = MathMin(Bars - 2, 5000);

   if(dir == 1) // BULLISH (+1): price above EMA-200
     {
      for(int i = 1; i < lookback; i++)
        {
         double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, i);
         if(ema <= 0.0)
            continue;
         bool crossed = (Close[i] <= ema);
         if(crossed)
           {
            return Time[MathMax(0, i - 1)];
           }
        }
     }
   else
      if(dir == -1) // BEARISH (-1): price below EMA-200
        {
         for(int i = 1; i < lookback; i++)
           {
            double ema = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, i);
            if(ema <= 0.0)
               continue;
            bool crossed = (Close[i] >= ema);
            if(crossed)
              {
               return Time[MathMax(0, i - 1)];
              }
           }
        }
   return 0;
  }

//+------------------------------------------------------------------+
//| GetEmaFlipPrice:                                                 |
//| Returns the price level where the current EMA flip took place.   |
//| Reconstructs from candle history if not yet set in memory.       |
//+------------------------------------------------------------------+
double GetEmaFlipPrice()
  {
   if(g_emaFlipPrice > 0.0)
      return g_emaFlipPrice;

   datetime flipTime = GetActualEmaFlipTime(EMADirection);
   if(flipTime > 0)
     {
      int flipShift = iBarShift(Symbol(), Period(), flipTime, false);
      if(flipShift >= 0 && flipShift < Bars)
        {
         double pClose = iClose(Symbol(), Period(), flipShift);
         if(pClose > 0.0)
           {
            g_emaFlipPrice = pClose;
            return g_emaFlipPrice;
           }
         double pEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, flipShift);
         if(pEma > 0.0)
           {
            g_emaFlipPrice = pEma;
            return g_emaFlipPrice;
           }
        }
     }

   double liveEma = iMA(Symbol(), Period(), InpEMA200Period, InpEMAPriceShift, MODE_EMA, PRICE_CLOSE, 0);
   if(liveEma > 0.0)
      g_emaFlipPrice = liveEma;
   else
      g_emaFlipPrice = (Ask + Bid) * 0.5;

   return g_emaFlipPrice;
  }

//+------------------------------------------------------------------+
//| EMAflipdistance:                                                 |
//| USER RULE: "create one function EMAflipdistance to get the raw   |
//| price distance from EMAflip to live tick price."                 |
//| Computes raw price distance ($ USD) between the EMA flip price   |
//| and the live tick price.                                         |
//+------------------------------------------------------------------+
double EMAflipdistance(int orderType = -1)
  {
   static double cachedDist = 0.0;
   static int    cachedType = -999;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && cachedType == orderType && CurrentTickSequence > 0)
      return cachedDist;

   RefreshRates();
   double flipPrice = GetEmaFlipPrice();
   if(flipPrice <= 0.0)
     {
      cachedDist = 0.0;
      cachedType = orderType;
      cachedTick = CurrentTickSequence;
      return 0.0;
     }

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - flipPrice);

   cachedDist = rawDist;
   cachedType = orderType;
   cachedTick = CurrentTickSequence;
   return rawDist;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepEqlPrice:                                             |
//| Returns the price level of the active LSD_SWEEP EQL (Green line).|
//| Checks memory variable first; if 0, scans chart objects.         |
//+------------------------------------------------------------------+
double GetLsdSweepEqlPrice()
  {
   static double cachedVal = 0.0;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   if(g_lastEqLowPrice > 0.0)
     {
      cachedVal = g_lastEqLowPrice;
      cachedTick = CurrentTickSequence;
      return cachedVal;
     }

   cachedVal = 0.0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0)
        {
         double p = ObjectGet(name, OBJPROP_PRICE1);
         if(p > 0.0)
           {
            cachedVal = p;
            break;
           }
        }
     }
   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepEqhPrice:                                             |
//| Returns the price level of the active LSD_SWEEP EQH (Red line).  |
//| Checks memory variable first; if 0, scans chart objects.         |
//+------------------------------------------------------------------+
double GetLsdSweepEqhPrice()
  {
   static double cachedVal = 0.0;
   static int    cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   if(g_lastEqHighPrice > 0.0)
     {
      cachedVal = g_lastEqHighPrice;
      cachedTick = CurrentTickSequence;
      return cachedVal;
     }

   cachedVal = 0.0;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0)
        {
         double p = ObjectGet(name, OBJPROP_PRICE1);
         if(p > 0.0)
           {
            cachedVal = p;
            break;
           }
        }
     }
   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| LsdSweepEqlDistance:                                             |
//| USER RULE: "Get Raw price gap between LSD_SWEEP_EQL and live     |
//| tick price . create a method to get distance"                    |
//| Computes raw price distance ($ USD) between the active           |
//| LSD_SWEEP EQL (Equal Low green line) and live tick price.        |
//| Returns 0.0 if no EQL line is active.                            |
//+------------------------------------------------------------------+
double LsdSweepEqlDistance(int orderType = -1)
  {
   RefreshRates();
   double eqlPrice = GetLsdSweepEqlPrice();
   if(eqlPrice <= 0.0)
      return 0.0;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqlPrice);
   return rawDist;
  }

// Aliases for user convenience & exact naming match:
double LSD_SWEEP_EQL_distance(int orderType = -1)
  {
   return LsdSweepEqlDistance(orderType);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double GetLsdSweepEqlDistance(int orderType = -1)
  {
   return LsdSweepEqlDistance(orderType);
  }

// Distance in broker Points (Pipettes)
double LsdSweepEqlDistancePoints(int orderType = -1)
  {
   if(Point <= 0.0)
      return 0.0;
   return (LsdSweepEqlDistance(orderType) / Point);
  }

// Companion: Equal High Red line raw price gap
double LsdSweepEqhDistance(int orderType = -1)
  {
   RefreshRates();
   double eqhPrice = GetLsdSweepEqhPrice();
   if(eqhPrice <= 0.0)
      return 0.0;

   bool isBuy  = (orderType == OP_BUY  || orderType == OP_BUYSTOP  || orderType == OP_BUYLIMIT);
   bool isSell = (orderType == OP_SELL || orderType == OP_SELLSTOP || orderType == OP_SELLLIMIT);
   double livePrice = isBuy ? Ask : (isSell ? Bid : ((Ask + Bid) * 0.5));
   double rawDist = MathAbs(livePrice - eqhPrice);
   return rawDist;
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double LSD_SWEEP_EQH_distance(int orderType = -1)
  {
   return LsdSweepEqhDistance(orderType);
  }


//+------------------------------------------------------------------+
//| DeleteLiquiditySweepObjects: Removes all sweep markers/lines     |
//+------------------------------------------------------------------+
void DeleteLiquiditySweepObjects()
  {
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX, 0) == 0)
         ObjectDelete(0, name);
     }
   g_lastEqHighPrice = 0.0;
   g_lastEqLowPrice  = 0.0;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepChartSignal: Scans chart objects for LSD_SWEEP markers|
//| Returns:                                                         |
//|   +1 = Green/Lime Buy sweep marker (SSLS)                        |
//|   -1 = Red Sell sweep marker (BSLS)                              |
//|    0 = None found                                                |
//+------------------------------------------------------------------+
int GetLsdSweepChartSignal()
  {
   int total = ObjectsTotal(0, -1, -1);
   datetime newestTime = 0;
   int newestSig = 0;

   for(int k = total - 1; k >= 0; k--)
     {
      string objName = ObjectName(0, k, -1, -1);
      if(StringFind(objName, LSD_PREFIX, 0) == 0 || StringFind(objName, "LSD_SWEEP", 0) >= 0)
        {
         int objType = ObjectType(objName);
         if(objType == OBJ_ARROW || objType == OBJ_TEXT)
           {
            datetime objTime = (datetime)ObjectGetInteger(0, objName, OBJPROP_TIME1);
            if(objTime == 0)
               objTime = (datetime)ObjectGet(objName, OBJPROP_TIME1);

            color objColor = (color)ObjectGetInteger(0, objName, OBJPROP_COLOR);
            int arrowCode  = (int)ObjectGetInteger(0, objName, OBJPROP_ARROWCODE);

            int sig = 0;
            // Check for Buy / Green signal (SSLS / Arrow 241 / Green / Lime)
            if(StringFind(objName, "SSL", 0) >= 0 || StringFind(objName, "BUY", 0) >= 0 ||
               arrowCode == 241 || objColor == InpSslSweepColor || objColor == clrLime || objColor == clrGreen)
              {
               sig = 1;
              }
            // Check for Sell / Red signal (BSLS / Arrow 242 / Red / Tomato)
            else
               if(StringFind(objName, "BSL", 0) >= 0 || StringFind(objName, "SELL", 0) >= 0 ||
                  arrowCode == 242 || objColor == InpBslSweepColor || objColor == clrRed || objColor == clrTomato)
                 {
                  sig = -1;
                 }

            if(sig != 0 && (objTime >= newestTime || newestTime == 0))
              {
               newestTime = objTime;
               newestSig  = sig;
              }
           }
        }
     }
   return newestSig;
  }

//+------------------------------------------------------------------+
//| GetLsdSweepSignal: Evaluates active LSD_SWEEP Buy/Sell signal.   |
//| Checks:                                                          |
//|   1. EA internal state (GlobalSweepBuy, GlobalSweepSell,         |
//|      GlobalSweepSignal, g_rememberedSweepSignal)                 |
//|   2. MT4 Terminal Global Variables (F3)                          |
//|   3. Chart objects (LSD_SWEEP markers & arrows)                  |
//| Returns:                                                         |
//|   +1 = LSD_SWEEP BUY green signal (SSLS)                         |
//|   -1 = LSD_SWEEP SELL red signal (BSLS)                          |
//|    0 = None                                                      |
//+------------------------------------------------------------------+
int GetLsdSweepSignal()
  {
// 1. Check EA internal state
   if(GlobalSweepBuy || GlobalSweepSignal == "SWEEP buy signal" || g_rememberedSweepSignal == "SSLS" || g_lastSweepType == "SSLS")
      return 1;
   if(GlobalSweepSell || GlobalSweepSignal == "SWEEP sell signal" || g_rememberedSweepSignal == "BSLS" || g_lastSweepType == "BSLS")
      return -1;

// 2. Check MT4 Terminal Global Variables (F3)
   string sym = Symbol();
   if(GlobalVariableCheck(sym + "_SWEEP_BUY_SIGNAL") && GlobalVariableGet(sym + "_SWEEP_BUY_SIGNAL") > 0.5)
      return 1;
   if(GlobalVariableCheck(sym + "_SWEEP_SELL_SIGNAL") && GlobalVariableGet(sym + "_SWEEP_SELL_SIGNAL") > 0.5)
      return -1;
   if(GlobalVariableCheck(sym + "_SWEEP_SIGNAL"))
     {
      double val = GlobalVariableGet(sym + "_SWEEP_SIGNAL");
      if(val > 0.5)
         return 1;
      if(val < -0.5)
         return -1;
     }
   if(GlobalVariableCheck("SWEEP_BUY_SIGNAL") && GlobalVariableGet("SWEEP_BUY_SIGNAL") > 0.5)
      return 1;
   if(GlobalVariableCheck("SWEEP_SELL_SIGNAL") && GlobalVariableGet("SWEEP_SELL_SIGNAL") > 0.5)
      return -1;
   if(GlobalVariableCheck("SWEEP_SIGNAL"))
     {
      double val = GlobalVariableGet("SWEEP_SIGNAL");
      if(val > 0.5)
         return 1;
      if(val < -0.5)
         return -1;
     }

// 3. Fallback: Scan Chart Objects
   int chartSig = GetLsdSweepChartSignal();
   if(chartSig != 0)
      return chartSig;

   return 0;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepBuySignal: Returns true if LSD_SWEEP BUY green active  |
//+------------------------------------------------------------------+
bool IsLsdSweepBuySignal()
  {
   return (GetLsdSweepSignal() == 1);
  }

//+------------------------------------------------------------------+
//| IsLsdSweepSellSignal: Returns true if LSD_SWEEP SELL red active  |
//+------------------------------------------------------------------+
bool IsLsdSweepSellSignal()
  {
   return (GetLsdSweepSignal() == -1);
  }

//+------------------------------------------------------------------+
//| IsLsdSweepGreenLinePresent: Checks if EQL green line exists      |
//+------------------------------------------------------------------+
bool IsLsdSweepGreenLinePresent()
  {
   static bool cachedVal = false;
   static int  cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   cachedVal = false;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQL_", 0) == 0)
        {
         cachedVal = true;
         break;
        }
     }
   if(!cachedVal)
      cachedVal = (g_lastEqLowPrice > 0.0);

   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepRedLinePresent: Checks if EQH red line exists          |
//+------------------------------------------------------------------+
bool IsLsdSweepRedLinePresent()
  {
   static bool cachedVal = false;
   static int  cachedTick = -1;
   if(cachedTick == CurrentTickSequence && CurrentTickSequence > 0)
      return cachedVal;

   cachedVal = false;
   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, LSD_PREFIX + "EQH_", 0) == 0)
        {
         cachedVal = true;
         break;
        }
     }
   if(!cachedVal)
      cachedVal = (g_lastEqHighPrice > 0.0);

   cachedTick = CurrentTickSequence;
   return cachedVal;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepGreenLineActive:                                       |
//| Returns true if the LSD_SWEEP green line (EQL Equal Low level)   |
//| is present on the chart, or if green sweep signal (SSLS) is active.|
//+------------------------------------------------------------------+
bool IsLsdSweepGreenLineActive()
  {
   if(IsLsdSweepGreenLinePresent())
      return true;
   if(InpSweepLineTriggerOnSweepSignal && IsLsdSweepBuySignal())
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| IsLsdSweepRedLineActive:                                         |
//| Returns true if the LSD_SWEEP red line (EQH Equal High level)    |
//| is present on the chart, or if red sweep signal (BSLS) is active. |
//+------------------------------------------------------------------+
bool IsLsdSweepRedLineActive()
  {
   if(IsLsdSweepRedLinePresent())
      return true;
   if(InpSweepLineTriggerOnSweepSignal && IsLsdSweepSellSignal())
      return true;
   return false;
  }

//+------------------------------------------------------------------+
//| ManageLsdSweepLineStopLossProtection:                            |
//| USER OPTION 2 RULE:                                              |
//| ACTIVE LINE: RED LINE -> Close all BUY orders (or modify SL)     |
//| ACTIVE LINE: GREEN LINE -> Close all SELL orders (or modify SL)   |
//+------------------------------------------------------------------+
void ManageLsdSweepLineStopLossProtection()
  {
   return; // DISABLED: LSD Sweep lines only create new Order FlipBasketSupport, DO NOT modify or close existing orders
   if(!InpEnableSweepLineSLProtection)
      return;

   bool greenLineActive = IsLsdSweepGreenLineActive();
   bool redLineActive   = IsLsdSweepRedLineActive();

   if(!greenLineActive && !redLineActive)
      return;

   RefreshRates();
   double minDistance = GetRequiredStopDistance();
   double buffer = MathMax(minDistance, InpSweepLineSLBufferPoints * Point);

   double buyTargetSL  = NormalizeDouble(Bid - buffer, Digits);
   double sellTargetSL = NormalizeDouble(Ask + buffer, Digits);

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
         continue;

      if(OrderSymbol() != Symbol() || OrderMagicNumber() != MagicNumber)
         continue;

      int oType        = OrderType();
      int ticket       = OrderTicket();
      double lots      = OrderLots();
      double openPrice = OrderOpenPrice();
      double currentSL = OrderStopLoss();
      double currentTP = OrderTakeProfit();

      // 1. GREEN LINE ACTIVE -> Close all SELL (or modify SL to current price)
      if(oType == OP_SELL && greenLineActive)
        {
         if(InpSweepLineAction == SWEEP_LINE_CLOSE_ALL_OPPOSITE)
           {
            ResetLastError();
            bool closed = SafeOrderClose(ticket, lots, OP_SELL, Slippage, clrLime);
            if(closed)
              {
               Print(">>> [LSD_SWEEP GREEN LINE ACTION] Closed SELL Order #", ticket,
                     " (", DoubleToString(lots, 2), "L) at market Ask=", DoubleToString(Ask, Digits));
              }
            else
              {
               int err = GetLastError();
               if(err != 0 && err != 1)
                  Print(">>> [LSD_SWEEP GREEN LINE ACTION] Failed to close SELL Order #", ticket, " | Err=", err);
              }
           }
         else // SWEEP_LINE_MODIFY_SL_CURRENT_PRICE
           {
            if(sellTargetSL > 0.0)
              {
               if(currentSL == 0.0 || (sellTargetSL < currentSL && MathAbs(currentSL - sellTargetSL) >= MinimumSLModifyGapRaw))
                 {
                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime);
                  if(!modified)
                    {
                     ResetLastError();
                     modified = OrderModify(ticket, openPrice, sellTargetSL, currentTP, 0, clrLime);
                    }

                  if(modified)
                    {
                     Print(">>> [LSD_SWEEP GREEN LINE SL] Modified SELL Order #", ticket,
                           " | StopLoss set to Current Price Ask=", DoubleToString(sellTargetSL, Digits),
                           " (Previous SL=", DoubleToString(currentSL, Digits), ")");
                    }
                  else
                    {
                     int err = GetLastError();
                     if(err != 1 && err != 0)
                        Print(">>> [LSD_SWEEP GREEN LINE SL] Failed to modify SELL Order #", ticket,
                              " | TargetSL=", DoubleToString(sellTargetSL, Digits), " | Err=", err);
                    }
                 }
              }
           }
        }

      // 2. RED LINE ACTIVE -> Close all BUY (or modify SL to current price)
      if(oType == OP_BUY && redLineActive)
        {
         if(InpSweepLineAction == SWEEP_LINE_CLOSE_ALL_OPPOSITE)
           {
            ResetLastError();
            bool closed = SafeOrderClose(ticket, lots, OP_BUY, Slippage, clrTomato);
            if(closed)
              {
               Print(">>> [LSD_SWEEP RED LINE ACTION] Closed BUY Order #", ticket,
                     " (", DoubleToString(lots, 2), "L) at market Bid=", DoubleToString(Bid, Digits));
              }
            else
              {
               int err = GetLastError();
               if(err != 0 && err != 1)
                  Print(">>> [LSD_SWEEP RED LINE ACTION] Failed to close BUY Order #", ticket, " | Err=", err);
              }
           }
         else // SWEEP_LINE_MODIFY_SL_CURRENT_PRICE
           {
            if(buyTargetSL > 0.0)
              {
               if(currentSL == 0.0 || (buyTargetSL > currentSL && MathAbs(currentSL - buyTargetSL) >= MinimumSLModifyGapRaw))
                 {
                  ResetLastError();
                  bool modified = SafeOrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato);
                  if(!modified)
                    {
                     ResetLastError();
                     modified = OrderModify(ticket, openPrice, buyTargetSL, currentTP, 0, clrTomato);
                    }

                  if(modified)
                    {
                     Print(">>> [LSD_SWEEP RED LINE SL] Modified BUY Order #", ticket,
                           " | StopLoss set to Current Price Bid=", DoubleToString(buyTargetSL, Digits),
                           " (Previous SL=", DoubleToString(currentSL, Digits), ")");
                    }
                  else
                    {
                     int err = GetLastError();
                     if(err != 1 && err != 0)
                        Print(">>> [LSD_SWEEP RED LINE SL] Failed to modify BUY Order #", ticket,
                              " | TargetSL=", DoubleToString(buyTargetSL, Digits), " | Err=", err);
                    }
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| CheckLsdSweepFlipBasketSupportOrder:                             |
//| USER RULE: If LSD_SWEEP greenline appear and liveprice tick and  |
//| greenline gap is less than $50 rawprice gap then create          |
//| Flipbasketorder BUY and ignore all gates.                        |
//| Similarly redline with $50 rawpricegap creates SELL order.       |
//+------------------------------------------------------------------+
void CheckLsdSweepFlipBasketSupportOrder()
  {
   if(!InpEnableLsdSweepFlipBasketSupport)
      return;
   if(!EAStartupComplete)
      return;

   // 1. Check Green Line (EQL Equal Low) -> BUY
   bool greenPresent = IsLsdSweepGreenLinePresent();
   double eqlPrice   = greenPresent ? GetLsdSweepEqlPrice() : 0.0;
   double greenGap   = (greenPresent && eqlPrice > 0.0) ? LsdSweepEqlDistance(OP_BUY) : 999999.0;
   bool greenTrigger = (greenPresent && eqlPrice > 0.0 && greenGap < InpLsdSweepFlipBasketMaxGapRaw);

   // 2. Check Red Line (EQH Equal High) -> SELL
   bool redPresent   = IsLsdSweepRedLinePresent();
   double eqhPrice   = redPresent ? GetLsdSweepEqhPrice() : 0.0;
   double redGap     = (redPresent && eqhPrice > 0.0) ? LsdSweepEqhDistance(OP_SELL) : 999999.0;
   bool redTrigger   = (redPresent && eqhPrice > 0.0 && redGap < InpLsdSweepFlipBasketMaxGapRaw);

   if(!greenTrigger && !redTrigger)
      return;

   // If both lines trigger simultaneously, select the closer level
   if(greenTrigger && redTrigger)
     {
      if(greenGap <= redGap)
         redTrigger = false;
      else
         greenTrigger = false;
     }

   static datetime lastLsdFlipOrderTime = 0;
   static datetime lastLsdFlipOrderBar  = 0;
   if(TimeCurrent() - lastLsdFlipOrderTime < 60 || Time[0] == lastLsdFlipOrderBar)
      return;

   // Strictly max 1 active FLIPBasketSupport order allowed in total
   if(HasOpenFLIPBasketSupportOrder(-1))
      return;

   if(greenTrigger)
     {
      // If an active BUY FLIPBasketSupport order is already open, do not duplicate
      if(HasOpenFLIPBasketSupportOrder(OP_BUY))
         return;

      // Close opposite SELL support order if any exists
      if(HasOpenFLIPBasketSupportOrder(OP_SELL))
         CloseFLIPBasketSupportOrders(OP_SELL);

      Print(">>> [LSD_SWEEP GREEN LINE TRIGGER] EQL=", DoubleToString(eqlPrice, Digits),
            " Ask=", DoubleToString(Ask, Digits), " Gap=", DoubleToString(greenGap, 2),
            " < MaxGap=", DoubleToString(InpLsdSweepFlipBasketMaxGapRaw, 2),
            " -> Creating FLIPBasketSupport BUY (ignoring all gates)...");

      int tkt = CreateFLIPBasketSupportOrder(1, true, true, "_LSD");
      if(tkt > 0)
        {
         lastLsdFlipOrderTime = TimeCurrent();
         lastLsdFlipOrderBar  = Time[0];
         FLIPBasketSupportOpenedThisCycle = true;
         Print(">>> [LSD_SWEEP GREEN LINE TRIGGER] Successfully created FLIPBasketSupport BUY Ticket #", tkt);
        }
     }
   else if(redTrigger)
     {
      // If an active SELL FLIPBasketSupport order is already open, do not duplicate
      if(HasOpenFLIPBasketSupportOrder(OP_SELL))
         return;

      // Close opposite BUY support order if any exists
      if(HasOpenFLIPBasketSupportOrder(OP_BUY))
         CloseFLIPBasketSupportOrders(OP_BUY);

      Print(">>> [LSD_SWEEP RED LINE TRIGGER] EQH=", DoubleToString(eqhPrice, Digits),
            " Bid=", DoubleToString(Bid, Digits), " Gap=", DoubleToString(redGap, 2),
            " < MaxGap=", DoubleToString(InpLsdSweepFlipBasketMaxGapRaw, 2),
            " -> Creating FLIPBasketSupport SELL (ignoring all gates)...");

      int tkt = CreateFLIPBasketSupportOrder(-1, true, true, "_LSD");
      if(tkt > 0)
        {
         lastLsdFlipOrderTime = TimeCurrent();
         lastLsdFlipOrderBar  = Time[0];
         FLIPBasketSupportOpenedThisCycle = true;
         Print(">>> [LSD_SWEEP RED LINE TRIGGER] Successfully created FLIPBasketSupport SELL Ticket #", tkt);
        }
     }
  }

//+------------------------------------------------------------------+
//| UpdateLiquiditySweepDetectorOnChart: Smart Money Concept (SMC)   |
//| Markers & Liquidity Sweep Detection:                             |
//| - Equal High (EQH) & Equal Low (EQL) Detection via Pivots        |
//| - BSL (Buy-Side Liquidity Sweep): High > EQH && Close < EQH      |
//|   -> Produces Bearish SWEEP sell signal                          |
//| - SSL (Sell-Side Liquidity Sweep): Low < EQL && Close > EQL      |
//|   -> Produces Bullish SWEEP buy signal                           |
//| - Automatic line truncation/deletion on sweep                    |
//+------------------------------------------------------------------+
void UpdateLiquiditySweepDetectorOnChart()
  {
   if(!InpShowLiquiditySweeps)
     {
      DeleteLiquiditySweepObjects();
      ManageSweepGlobalVariables("None");
      return;
     }

   if(Bars < (InpSweepPivotLen * 2 + 15))
      return;

   static datetime lastSweepBar = 0;
   static uint lastSweepCalcMs = 0;
   bool rebuild = (lastSweepBar != Time[0]);
   uint nowMs = GetTickCount();

// Throttle calculation: run on every new bar OR forced on EMA flip OR once every 1000ms
   if(!rebuild && !g_forceSweepRecalc && lastSweepCalcMs != 0 && (uint)(nowMs - lastSweepCalcMs) < 1000)
      return;

   g_forceSweepRecalc = false;
   lastSweepCalcMs = nowMs;
   lastSweepBar = Time[0];

   int maxLookbackBars = 1000;
   int limit = Bars - (InpSweepPivotLen * 2 + 2);
   if(limit > maxLookbackBars)
      limit = maxLookbackBars;
   if(limit <= 0)
      return;

   DeleteLiquiditySweepObjects();

   double eqHigh = 0.0;
   datetime eqHighTime = 0;
   string curHighLineName = "";
   double activeEqHighPrice = 0.0;

   double eqLow = 0.0;
   datetime eqLowTime = 0;
   string curLowLineName = "";
   double activeEqLowPrice = 0.0;

   bool sweepFoundInCurrentFlip = false;
   string sweepTypeInCurrentFlip = "None";
   datetime sweepTimeInCurrentFlip = 0;
   datetime flipTime = GetActualEmaFlipTime(EMADirection);
   if(flipTime == 0 && EmaFlipTime > 0)
      flipTime = EmaFlipTime;
   if(flipTime <= 0 && Bars > 0)
      flipTime = Time[MathMin(Bars - 1, limit)];

// Forward chronological iteration from oldest bar (limit) down to current bar (0)
   for(int i = limit; i >= 0; i--)
     {
      // 1. Pivot High Detection at bar (i + InpSweepPivotLen)
      int phBar = i + InpSweepPivotLen;
      if(phBar < Bars - InpSweepPivotLen)
        {
         bool isPh = true;
         double candidateH = High[phBar];
         for(int j = 1; j <= InpSweepPivotLen; j++)
           {
            if(candidateH <= High[phBar + j])
              {
               isPh = false;
               break;
              }
            if(candidateH < High[phBar - j])
              {
               isPh = false;
               break;
              }
           }

         if(isPh)
           {
            double ph = candidateH;
            if(eqHigh > 0.0)
              {
               double atr = iATR(Symbol(), Period(), 14, i);
               if(MathAbs(ph - eqHigh) <= atr * InpSweepToleranceATR)
                 {
                  if(InpShowSweepLevels)
                    {
                     if(curHighLineName != "")
                        ObjectDelete(0, curHighLineName);

                     curHighLineName = LSD_PREFIX + "EQH_" + IntegerToString((int)Time[phBar]);
                     datetime endTime = Time[i] + Period() * 60 * InpSweepExtendBars;
                     ObjectCreate(0, curHighLineName, OBJ_TREND, 0, Time[phBar], eqHigh, endTime, eqHigh);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_COLOR, InpBslSweepColor);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_WIDTH, 2);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, curHighLineName, OBJPROP_HIDDEN, true);
                    }
                  activeEqHighPrice = eqHigh;
                 }
               eqHigh = ph;
               eqHighTime = Time[phBar];
              }
            else
              {
               eqHigh = ph;
               eqHighTime = Time[phBar];
              }
           }
        }

      // 2. Pivot Low Detection at bar (i + InpSweepPivotLen)
      int plBar = i + InpSweepPivotLen;
      if(plBar < Bars - InpSweepPivotLen)
        {
         bool isPl = true;
         double candidateL = Low[plBar];
         for(int j = 1; j <= InpSweepPivotLen; j++)
           {
            if(candidateL >= Low[plBar + j])
              {
               isPl = false;
               break;
              }
            if(candidateL > Low[plBar - j])
              {
               isPl = false;
               break;
              }
           }

         if(isPl)
           {
            double pl = candidateL;
            if(eqLow > 0.0)
              {
               double atr = iATR(Symbol(), Period(), 14, i);
               if(MathAbs(pl - eqLow) <= atr * InpSweepToleranceATR)
                 {
                  if(InpShowSweepLevels)
                    {
                     if(curLowLineName != "")
                        ObjectDelete(0, curLowLineName);

                     curLowLineName = LSD_PREFIX + "EQL_" + IntegerToString((int)Time[plBar]);
                     datetime endTime = Time[i] + Period() * 60 * InpSweepExtendBars;
                     ObjectCreate(0, curLowLineName, OBJ_TREND, 0, Time[plBar], eqLow, endTime, eqLow);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_COLOR, InpSslSweepColor);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_WIDTH, 2);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_RAY_RIGHT, false);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_SELECTABLE, false);
                     ObjectSetInteger(0, curLowLineName, OBJPROP_HIDDEN, true);
                    }
                  activeEqLowPrice = eqLow;
                 }
               eqLow = pl;
               eqLowTime = Time[plBar];
              }
            else
              {
               eqLow = pl;
               eqLowTime = Time[plBar];
              }
           }
        }

      // 3. Sweep Detection on bar i
      bool bslSweep = (eqHigh > 0.0 && High[i] > eqHigh && Close[i] < eqHigh);
      bool sslSweep = (eqLow > 0.0 && Low[i] < eqLow && Close[i] > eqLow);

      if(bslSweep)
        {
         double atr = iATR(Symbol(), Period(), 14, i);
         if(InpShowLiquiditySweeps)
           {
            // Red down triangle marker above bar (Bearish SWEEP sell signal)
            string arrName = LSD_PREFIX + "BSL_ARR_" + IntegerToString((int)Time[i]);
            ObjectCreate(0, arrName, OBJ_ARROW, 0, Time[i], High[i] + atr * 0.25);
            ObjectSetInteger(0, arrName, OBJPROP_ARROWCODE, 242);
            ObjectSetInteger(0, arrName, OBJPROP_COLOR, InpBslSweepColor);
            ObjectSetInteger(0, arrName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, arrName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, arrName, OBJPROP_HIDDEN, true);

            if(InpShowSweepLabels)
              {
               // Red badge text: BSLS
               string lblName = LSD_PREFIX + "BSL_LBL_" + IntegerToString((int)Time[i]);
               ObjectCreate(0, lblName, OBJ_TEXT, 0, Time[i], High[i] + atr * 0.45);
               ObjectSetString(0, lblName, OBJPROP_TEXT, "BSLS");
               ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
               ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, lblName, OBJPROP_COLOR, InpBslSweepColor);
               ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
              }
           }

         // Remove swept level line & clear eqHigh
         if(curHighLineName != "")
           {
            ObjectDelete(0, curHighLineName);
            curHighLineName = "";
           }
         eqHigh = 0.0;
         activeEqHighPrice = 0.0;
         g_lastSweepType = "BSLS";
         g_lastSweepBarTime = Time[i];

         if(flipTime > 0 && Time[i] >= flipTime)
           {
            sweepFoundInCurrentFlip = true;
            sweepTypeInCurrentFlip   = "BSLS";
            sweepTimeInCurrentFlip   = Time[i];
           }
        }

      if(sslSweep)
        {
         double atr = iATR(Symbol(), Period(), 14, i);
         if(InpShowLiquiditySweeps)
           {
            // Lime up triangle marker below bar (Bullish SWEEP buy signal)
            string arrName = LSD_PREFIX + "SSL_ARR_" + IntegerToString((int)Time[i]);
            ObjectCreate(0, arrName, OBJ_ARROW, 0, Time[i], Low[i] - atr * 0.25);
            ObjectSetInteger(0, arrName, OBJPROP_ARROWCODE, 241);
            ObjectSetInteger(0, arrName, OBJPROP_COLOR, InpSslSweepColor);
            ObjectSetInteger(0, arrName, OBJPROP_WIDTH, 3);
            ObjectSetInteger(0, arrName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, arrName, OBJPROP_HIDDEN, true);

            if(InpShowSweepLabels)
              {
               // Lime badge text: SSLS
               string lblName = LSD_PREFIX + "SSL_LBL_" + IntegerToString((int)Time[i]);
               ObjectCreate(0, lblName, OBJ_TEXT, 0, Time[i], Low[i] - atr * 0.45);
               ObjectSetString(0, lblName, OBJPROP_TEXT, "SSLS");
               ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
               ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 8);
               ObjectSetInteger(0, lblName, OBJPROP_COLOR, InpSslSweepColor);
               ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, lblName, OBJPROP_HIDDEN, true);
              }
           }

         // Remove swept level line & clear eqLow
         if(curLowLineName != "")
           {
            ObjectDelete(0, curLowLineName);
            curLowLineName = "";
           }
         eqLow = 0.0;
         activeEqLowPrice = 0.0;
         g_lastSweepType = "SSLS";
         g_lastSweepBarTime = Time[i];

         if(flipTime > 0 && Time[i] >= flipTime)
           {
            sweepFoundInCurrentFlip = true;
            sweepTypeInCurrentFlip   = "SSLS";
            sweepTimeInCurrentFlip   = Time[i];
           }
        }
     }

   g_lastEqHighPrice = (curHighLineName != "") ? activeEqHighPrice : 0.0;
   g_lastEqLowPrice  = (curLowLineName != "") ? activeEqLowPrice : 0.0;

// USER RULE: Sweep updated signal is remembered until EMA flip or sweep signal change
   string activeFoundSweep = "None";
   datetime activeFoundTime = 0;
   if(sweepFoundInCurrentFlip && sweepTypeInCurrentFlip != "None")
     {
      activeFoundSweep = sweepTypeInCurrentFlip;
      activeFoundTime = sweepTimeInCurrentFlip;
     }
   else
      if(g_lastSweepType == "BSLS" || g_lastSweepType == "SSLS")
        {
         activeFoundSweep = g_lastSweepType;
         activeFoundTime = g_lastSweepBarTime;
        }

   if(activeFoundSweep != "None")
     {
      if(g_rememberedSweepSignal != activeFoundSweep)
        {
         Print(">>> [SWEEP SIGNAL UPDATED] Sweep signal active: '", activeFoundSweep,
               "' (", (activeFoundSweep == "SSLS" ? "SWEEP buy signal" : "SWEEP sell signal"),
               ") at bar time ", TimeToStr(activeFoundTime, TIME_DATE|TIME_MINUTES),
               " | Remembered until EMA flip or signal change!");
        }
      g_rememberedSweepSignal             = activeFoundSweep;
      g_rememberedSweepBarTime            = activeFoundTime;
      g_isSweepSignalConfirmed            = true;
      g_sweepSignalActiveInCurrentEmaFlip = true;
      g_sweepSignalTypeInCurrentEmaFlip   = activeFoundSweep;
      g_sweepSignalDetectedTimeInFlip     = activeFoundTime;
      ManageSweepGlobalVariables(activeFoundSweep);
     }
   else
      if(g_isSweepSignalConfirmed && g_rememberedSweepSignal != "None")
        {
         // Preserve remembered sweep state across ticks until EMA flip or sweep signal change!
         g_sweepSignalActiveInCurrentEmaFlip = true;
         g_sweepSignalTypeInCurrentEmaFlip   = g_rememberedSweepSignal;
         g_sweepSignalDetectedTimeInFlip     = g_rememberedSweepBarTime;
         ManageSweepGlobalVariables(g_rememberedSweepSignal);
        }
      else
        {
         g_sweepSignalActiveInCurrentEmaFlip = false;
         g_sweepSignalTypeInCurrentEmaFlip   = "None";
         g_sweepSignalDetectedTimeInFlip     = 0;
         ManageSweepGlobalVariables("None");
        }
  }
//+------------------------------------------------------------------+
