#property strict

int OnInit()
{
   RefreshRates();

   int ticket = OrderSend(
      Symbol(),      // current symbol
      OP_BUY,        // BUY order
      0.01,          // lot size
      Ask,           // price
      30,            // slippage
      0,             // stop loss
      0,             // take profit
      "TEST_BUY",    // comment
      12345,         // magic
      0,             // expiration
      clrLime        // color
   );

   if(ticket < 0)
   {
      Print("ORDER FAILED. Error=", GetLastError());
   }
   else
   {
      Print("ORDER OPENED. Ticket=", ticket);
   }

   return(INIT_SUCCEEDED);
}

void OnTick()
{
}