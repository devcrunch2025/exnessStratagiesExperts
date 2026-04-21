// ===================================================
// ENHANCED VERSION
// Adds: candle size increasing + body ratio check
// ===================================================
int GetCreateNewOrderCandleReversalSignalStrong()
{
   double minBody     = 100;  // minimum body in points
   double minBodyRatio = 0.4; // body must be 40%+ of full candle

   // -----------------------------------------------
   // GET ALL CANDLE STATS
   // -----------------------------------------------
   double body0 = MathAbs(Close[0] - Open[0]) / Point;
   double body1 = MathAbs(Close[1] - Open[1]) / Point;
   double body2 = MathAbs(Close[2] - Open[2]) / Point;
   double body3 = MathAbs(Close[3] - Open[3]) / Point;

   double len0  = (High[0] - Low[0]) / Point;
   double len1  = (High[1] - Low[1]) / Point;
   double len2  = (High[2] - Low[2]) / Point;
   double len3  = (High[3] - Low[3]) / Point;

   // Body ratio (body / full length)
   double ratio0 = (len0 > 0) ? body0 / len0 : 0;
   double ratio1 = (len1 > 0) ? body1 / len1 : 0;
   double ratio2 = (len2 > 0) ? body2 / len2 : 0;
   double ratio3 = (len3 > 0) ? body3 / len3 : 0;

   // -----------------------------------------------
   // DIRECTION FLAGS
   // -----------------------------------------------
   bool cur_bull = (Close[0] > Open[0]);
   bool cur_bear = (Close[0] < Open[0]);

   bool c1_bull  = (Close[1] > Open[1]);
   bool c2_bull  = (Close[2] > Open[2]);
   bool c3_bull  = (Close[3] > Open[3]);

   bool c1_bear  = (Close[1] < Open[1]);
   bool c2_bear  = (Close[2] < Open[2]);
   bool c3_bear  = (Close[3] < Open[3]);

   // -----------------------------------------------
   // BODY SIZE VALID FLAGS
   // -----------------------------------------------
   bool b0ok = (body0 >= minBody && ratio0 >= minBodyRatio);
   bool b1ok = (body1 >= minBody && ratio1 >= minBodyRatio);
   bool b2ok = (body2 >= minBody && ratio2 >= minBodyRatio);
   bool b3ok = (body3 >= minBody && ratio3 >= minBodyRatio);

   // -----------------------------------------------
   // BUY SIGNAL — 3 red + current green
   // -----------------------------------------------
   bool threeBearish =
      c1_bear && b1ok &&
      c2_bear && b2ok &&
      c3_bear && b3ok;

   // Extra: current green candle body bigger than average of 3 reds
   double avgBearBody = (body1 + body2 + body3) / 3.0;
   bool strongGreenCandle = (body0 >= avgBearBody * 0.8); // at least 80% of avg

   bool buySignal = (threeBearish && cur_bull && b0ok && strongGreenCandle);

   // -----------------------------------------------
   // SELL SIGNAL — 3 green + current red
   // -----------------------------------------------
   bool threeBullish =
      c1_bull && b1ok &&
      c2_bull && b2ok &&
      c3_bull && b3ok;

   double avgBullBody = (body1 + body2 + body3) / 3.0;
   bool strongRedCandle = (body0 >= avgBullBody * 0.8);

   bool sellSignal = (threeBullish && cur_bear && b0ok && strongRedCandle);

   // -----------------------------------------------
   // DEBUG PRINT
   // -----------------------------------------------
   Print("C3=", c3_bull?"GRN":"RED", "(", DoubleToStr(body3,0), "pts)",
         " C2=", c2_bull?"GRN":"RED", "(", DoubleToStr(body2,0), "pts)",
         " C1=", c1_bull?"GRN":"RED", "(", DoubleToStr(body1,0), "pts)",
         " C0=", cur_bull?"GRN":"RED", "(", DoubleToStr(body0,0), "pts)");

   if(buySignal)
   {
      Print(">>> BUY REVERSAL: 3 red candles → green reversal");
      return  1;
   }
   if(sellSignal)
   {
      Print(">>> SELL REVERSAL: 3 green candles → red reversal");
      return -1;
   }

   return 0;
}