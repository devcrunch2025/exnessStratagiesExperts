import os

mq4_path = r'V_EMAMULTIPLE_ORDERS.mq4'
with open(mq4_path, 'r', encoding='utf-8', errors='ignore') as f:
    c = f.read().replace('\r\n', '\n')

targets = [
    'string glbVersion = "VMULTI-1104- Special Chart Icons on EquityProfitLadder5 Every Step Hit";',
    'double InpDoubleSlGapMultiplier            = 2.0;   // Gap multiplier (default 2.0 = double gap $150 to $300)',
    'void     DrawTargetEquityHitCircle(datetime time, double price, double targetVal, int step);',
    'double CalculateProportionalLadderSL(int orderType, double openPrice, double orderLots)',
    'double lockedDistance = 0.0;\n   if(ladderLevel == 1)\n     {\n      lockedDistance = 0.0;\n     }',
    'newSL = openPrice;\n        }\n      else\n        {\n         double rawPriceGap = GetLotBasedPriceGap(lots, balancelomultipler);',
    'if(IsEquityHitSecuredOrder(ticket) && callerName != "EquityTargetHit_LossTighten" && callerName != "DrawdownRelief50Pct" && StringFind(callerName, "Method") < 0)',
    'if(openPrice > 0.0 && sl < openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))\n            sl = openPrice; // USER RULE: Never modify order with loss amount (BUY order not less than openPrice)',
    'if(openPrice > 0.0 && sl > openPrice && (isProfitGapReached || rawProfitGap > 0.0 || orderProfit > 0.0))\n            sl = openPrice; // USER RULE: Never modify order with loss amount (SELL order not greater than openPrice)',
    'if(openPrice > 0.0 && targetSL < openPrice && isProfitGapReached)\n         targetSL = openPrice;',
    'if(openPrice > 0.0 && targetSL > openPrice && isProfitGapReached)\n         targetSL = openPrice;',
    'bool isSecuringProfit = (orderType == OP_BUY && requestedSL >= oOpen) || (orderType == OP_SELL && requestedSL <= oOpen);',
    'if(orderType == OP_BUY && requestedSL < oOpen)\n           {\n            Print(">>> [LOSS MODIFICATION PREVENTED] BUY #", ticket, " requestedSL=", DoubleToString(requestedSL, Digits),\n                  " clamped to openPrice=", DoubleToString(oOpen, Digits), " (Rule: Never modify order with loss amount)");\n            requestedSL = oOpen;\n           }',
    'if(orderType == OP_BUY && requestedSL > oOpen && (curExistingSL <= 0.0 || oOpen > curExistingSL))\n              {\n               Print(">>> [COMMON LADDER ENFORCED] BUY #", ticket, " (", DoubleToString(oLots, 2),\n                     "L): Proposed SL=", DoubleToString(requestedSL, Digits),\n                     " clamped to Breakeven=", DoubleToString(oOpen, Digits),\n                     " (Price has not reached Level 1 step gap yet)");\n               requestedSL = oOpen;\n              }',
    'if(!PrepareStopLossForOrder(orderType, OrderOpenPrice(), requestedSL))'
]

for i, t in enumerate(targets):
    cnt = c.count(t)
    print(f'Target {i+1}: {cnt} match(es)')
    if cnt != 1:
        print(f'FAILED target {i+1}:\n{t[:60]}...')
