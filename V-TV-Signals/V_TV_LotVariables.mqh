//+------------------------------------------------------------------+
//| V_TV_LotVariables.mqh                                            |
//| Central place for ALL lot-size-sensitive variables               |
//|                                                                  |
//| HOW TO USE:                                                      |
//|   Change ONLY SeqSellLotSize / SeqBuyLotSize.                   |
//|   ProfitTarget and StopLossUSD are calculated automatically      |
//|   in OnInit() via InitLotDependentVars().                        |
//|                                                                  |
//| AUTO-SCALING REFERENCE (base: 0.01 lot = $0.50 TP / $20 SL):   |
//|   LOT 0.01  ->  TP $0.50    SL $20.00                           |
//|   LOT 0.10  ->  TP $5.00    SL $200.00                          |
//|   LOT 1.00  ->  TP $50.00   SL $2000.00                         |
//|   LOT 10.00 ->  TP $500.00  SL $20000.00                        |
//|                                                                  |
//| NOTE: MinGapPoints, MaxOrders, Slippage, MinSecsBetweenOrders   |
//|       do NOT scale with lot — keep them the same always.         |
//+------------------------------------------------------------------+
#ifndef V_TV_LOT_VARIABLES_MQH
#define V_TV_LOT_VARIABLES_MQH

input string _LotVars_ = "======= LOT & RISK SETTINGS =======";



//--- Slippage (lot-independent) -------------------------------------
input int SeqSellSlippage   = 100;    // SELL slippage in points
input int SeqBuySlippage    = 100;    // BUY slippage in points
input int SeqCloseSlippage  = 0;    // Close slippage in points

//--- Min price gap between signals (lot-independent) ----------------
input int SeqSellMinGapPoints = 0; // SELL: min drop between signals (pts)
input int SeqBuyMinGapPoints  = 0; // BUY:  min rise between signals (pts)



//--- Min time between orders (lot-independent) ----------------------
input int SeqSellMinSecsBetweenOrders = 60; // SELL: min seconds between orders seconds
input int SeqBuyMinSecsBetweenOrders  = 60; // BUY:  min seconds between orders seconds

//--- Fake tick / broker manipulation protection (Condition 10) ------
input string _FakeTick_            = "--- FAKE TICK PROTECTION ---";
input bool   EnableFakeDetection   = true;  // Enable Cond10
input int    MaxSpreadPoints       = 30;    // Block if spread > this (absolute points)
input double SpreadSpikeMultiplier = 2.5;   // Block if spread > running avg × this
input double VolumeMinRatio        = 0.25;  // Block if bar volume < avg × this (0=disabled)
input int    VolumeAvgBars         = 20;    // Bars used for average volume

//--- 15-min trend confirmation (Condition 11) -----------------------
input string _TrendCond_           = "--- 15-MIN TREND FILTER ---";
input bool   EnableTrendFilter     = true;  // Enable Cond11
input int    TrendLookbackBars     = 3;     // M30 bars back to compare (3 bars = 90 min trend)
input double TrendMinMovePercent   = 1;  // Min price move % required (e.g. 0.15 = 0.15% of price)

//--- Partial profit booking -------------------------------------------
input string _PartialProfit_          = "--- PARTIAL PROFIT ---";
input bool   EnablePartialProfit      = false;   // Book partial profit at threshold
input double PartialProfitTriggerUSD  = 0.50;   // Close half lot when profit reaches this $
input double PartialProfitCloseRatio  = 1;    // Fraction of lot to close (0.5 = 50%)

bool isEMATouchesInsideLines=false;;

//--- 0.01; Profit / StopLoss (auto-calculated in InitLotDependentVars) ----
double SeqSellProfitTarget = 0.30;
double SeqSellStopLossUSD  =1.5;
double SeqBuyProfitTarget  =0.30;
double SeqBuyStopLossUSD   =1.5;

//--- Lot sizes (CHANGE ONLY THESE) ----------------------------------
input double SeqSellLotSize = 0.01;  // SELL lot size
input double SeqBuyLotSize  = 0.01;  // BUY lot size

input double SellProfitTargetInput = 0.30; 
input double BuyProfitTargetInput   =0.30;


  bool CloseOrderONLYProfitNotSignal  = true;  // BUY lot size
  bool OpenNewOrderAfter30MinLessPrice  = true;  // BUY lot size

double StopTradingMaxProfit=100.00;
 

int EMAGAP3000Condition=1;


//--- Max open orders (lot-independent) ------------------------------
  int SeqSellMaxOrders  =1;     // Max simultaneous SELL orders
  int SeqBuyMaxOrders   = 1;     // Max simultaneous BUY orders

  bool enableEMAGapDynamicMaxOrders = true; // Adjust max orders based on EMA gap (Condition 9)

//+------------------------------------------------------------------+
//| Call this once in OnInit() — scales TP/SL to the chosen lot size |
//+------------------------------------------------------------------+
void InitLotDependentVars()
  {
   double sellScale = (SeqSellLotSize > 0) ? SeqSellLotSize / 0.01 : 1.0;
   double buyScale  = (SeqBuyLotSize  > 0) ? SeqBuyLotSize  / 0.01 : 1.0;

   SeqSellProfitTarget = NormalizeDouble(SeqSellProfitTarget  * sellScale, 2);
   SeqSellStopLossUSD  = NormalizeDouble(SeqSellStopLossUSD  * sellScale, 2);
   SeqBuyProfitTarget  = NormalizeDouble(SeqBuyProfitTarget  * buyScale,  2);
   SeqBuyStopLossUSD   = NormalizeDouble(SeqBuyStopLossUSD   * buyScale,  2);

   Print("LotVars | SELL lot=", SeqSellLotSize,
         "  TP=$", SeqSellProfitTarget, "  SL=$", SeqSellStopLossUSD);
   Print("LotVars | BUY  lot=", SeqBuyLotSize,
         "  TP=$", SeqBuyProfitTarget,  "  SL=$", SeqBuyStopLossUSD);
  }

#endif
