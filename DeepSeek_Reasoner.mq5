//+------------------------------------------------------------------+
//|                                    DeepSeek_Reasoner_XAUUSD_Pro.mq5 |
//|                                 Copyright 2026, DeepTrading |
//|                                            https://www.deeptrading.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DeepTrading"
#property link      "https://www.deeptrading.com"
#property version   "2.00"

//--- Input Parameters - Core Strategy
input group "=== EMA Strategy ==="
input int      FastEMA_Period = 9;          // Fast EMA Period
input int      SlowEMA_Period = 21;         // Slow EMA Period
input int      TrendEMA_Period = 50;        // Trend Filter EMA Period (Higher TF)

input group "=== Risk Management ==="
input double   LotSize = 0.01;              // Base Lot Size
input double   ATR_Multiplier = 1.5;        // ATR Multiplier for Stop Loss (reduced for Gold)
input double   RiskReward_Ratio = 2.0;      // Risk:Reward Ratio
input double   MaximumRisk = 1.5;           // Maximum risk percentage per trade
input double   DecreaseFactor = 3;          // Decrease factor after losses

input group "=== Indicators ==="
input int      ATR_Period = 14;             // ATR Period
input int      RSI_Period = 14;             // RSI Period for confirmation
input int      RSI_Overbought = 70;         // RSI Overbought Level
input int      RSI_Oversold = 30;           // RSI Oversold Level

input group "=== Filters ==="
input bool     UseVolatilityFilter = true;  // Use Volatility Filter
input double   MinATR_Value = 0.5;          // Minimum ATR for trading (in USD)
input double   MaxSpread_Points = 30;       // Maximum Spread in Points
input bool     UseTimeFilter = true;        // Use Time Filter
input int      StartHour = 7;               // Trading Start Hour (GMT)
input int      EndHour = 20;                // Trading End Hour (GMT)

input group "=== Advanced Exits ==="
input bool     UseTrailingStop = true;      // Use Trailing Stop
input double   TrailingStop_ATR = 1.5;      // Trailing Stop ATR Multiplier
input double   TrailingStep_ATR = 0.5;      // Trailing Step ATR Multiplier
input bool     UseBreakeven = true;         // Move to Breakeven
input double   Breakeven_ATR = 1.0;         // Breakeven Trigger (ATR multiplier)
input double   Breakeven_Profit = 5.0;      // Breakeven Profit Lock (USD)

input group "=== System ==="
input long     MagicNumber = 123456;        // Magic Number

//--- Global Variables
int      FastEMA_Handle;
int      SlowEMA_Handle;
int      TrendEMA_Handle;
int      ATR_Handle;
int      RSI_Handle;

double   FastEMA_Buffer[];
double   SlowEMA_Buffer[];
double   TrendEMA_Buffer[];
double   ATR_Buffer[];
double   RSI_Buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate input parameters
   if(FastEMA_Period <= 0 || SlowEMA_Period <= 0 || TrendEMA_Period <= 0 || ATR_Period <= 0)
   {
      Print("Error: Period values must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(FastEMA_Period >= SlowEMA_Period)
   {
      Print("Error: Fast EMA must be less than Slow EMA");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(LotSize <= 0)
   {
      Print("Error: Lot size must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Check if symbol is XAUUSD or Gold
   string symbolName = _Symbol;
   if(StringFind(symbolName, "XAU") == -1 && StringFind(symbolName, "GOLD") == -1)
   {
      Print("Warning: This EA is optimized for XAUUSD/Gold trading");
   }
   
   //--- Create indicator handles
   FastEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   SlowEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   TrendEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, TrendEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   RSI_Handle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   
   if(FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE || 
      TrendEMA_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE || 
      RSI_Handle == INVALID_HANDLE)
   {
      Print("Error: Failed to create indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set buffer arrays as series
   ArraySetAsSeries(FastEMA_Buffer, true);
   ArraySetAsSeries(SlowEMA_Buffer, true);
   ArraySetAsSeries(TrendEMA_Buffer, true);
   ArraySetAsSeries(ATR_Buffer, true);
   ArraySetAsSeries(RSI_Buffer, true);
   
   Print("===================================================");
   Print("XAUUSD Expert Advisor Pro - Initialized Successfully");
   Print("Symbol: ", _Symbol);
   Print("Period: ", EnumToString(PERIOD_CURRENT));
   Print("Fast EMA: ", FastEMA_Period, " | Slow EMA: ", SlowEMA_Period);
   Print("Trend Filter: ", TrendEMA_Period, " EMA");
   Print("Volatility Filter: ", UseVolatilityFilter ? "ON" : "OFF");
   Print("Time Filter: ", UseTimeFilter ? "ON" : "OFF");
   Print("Trailing Stop: ", UseTrailingStop ? "ON" : "OFF");
   Print("Breakeven: ", UseBreakeven ? "ON" : "OFF");
   Print("===================================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   if(FastEMA_Handle != INVALID_HANDLE) IndicatorRelease(FastEMA_Handle);
   if(SlowEMA_Handle != INVALID_HANDLE) IndicatorRelease(SlowEMA_Handle);
   if(TrendEMA_Handle != INVALID_HANDLE) IndicatorRelease(TrendEMA_Handle);
   if(ATR_Handle != INVALID_HANDLE) IndicatorRelease(ATR_Handle);
   if(RSI_Handle != INVALID_HANDLE) IndicatorRelease(RSI_Handle);
   
   Print("Expert Advisor deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Manage existing positions (trailing stop, breakeven)
   ManagePositions();
   
   //--- Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return; // Same bar, skip signal processing
   
   lastBarTime = currentBarTime;
   
   //--- Get indicator values
   if(!GetIndicatorValues())
      return;
   
   //--- Apply filters
   if(!PassFilters())
      return;
   
   //--- Check for open positions
   bool hasPosition = CheckOpenPosition();
   
   //--- Generate signals with confirmation
   bool longSignal = GenerateLongSignal();
   bool shortSignal = GenerateShortSignal();
   
   //--- Execute trades
   if(!hasPosition)
   {
      if(longSignal)
         OpenLongPosition();
      else if(shortSignal)
         OpenShortPosition();
   }
}

//+------------------------------------------------------------------+
//| Get indicator values                                             |
//+------------------------------------------------------------------+
bool GetIndicatorValues()
{
   //--- Copy indicator values
   if(CopyBuffer(FastEMA_Handle, 0, 0, 3, FastEMA_Buffer) < 3)
   {
      Print("Error: Failed to copy Fast EMA buffer");
      return false;
   }
   
   if(CopyBuffer(SlowEMA_Handle, 0, 0, 3, SlowEMA_Buffer) < 3)
   {
      Print("Error: Failed to copy Slow EMA buffer");
      return false;
   }
   
   if(CopyBuffer(TrendEMA_Handle, 0, 0, 2, TrendEMA_Buffer) < 2)
   {
      Print("Error: Failed to copy Trend EMA buffer");
      return false;
   }
   
   if(CopyBuffer(ATR_Handle, 0, 0, 2, ATR_Buffer) < 2)
   {
      Print("Error: Failed to copy ATR buffer");
      return false;
   }
   
   if(CopyBuffer(RSI_Handle, 0, 0, 2, RSI_Buffer) < 2)
   {
      Print("Error: Failed to copy RSI buffer");
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Apply trading filters                                            |
//+------------------------------------------------------------------+
bool PassFilters()
{
   //--- Volatility Filter
   if(UseVolatilityFilter)
   {
      if(ATR_Buffer[0] < MinATR_Value)
      {
         //Print("Filter: ATR too low (", NormalizeDouble(ATR_Buffer[0], 2), " < ", MinATR_Value, ")");
         return false;
      }
   }
   
   //--- Spread Filter
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > MaxSpread_Points)
   {
      //Print("Filter: Spread too high (", spread, " > ", MaxSpread_Points, ")");
      return false;
   }
   
   //--- Time Filter
   if(UseTimeFilter)
   {
      MqlDateTime currentTime;
      TimeToStruct(TimeCurrent(), currentTime);
      int currentHour = currentTime.hour;
      
      if(currentHour < StartHour || currentHour >= EndHour)
      {
         //Print("Filter: Outside trading hours");
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check for open positions                                         |
//+------------------------------------------------------------------+
bool CheckOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Generate long signal with multiple confirmations                 |
//+------------------------------------------------------------------+
bool GenerateLongSignal()
{
   //--- EMA Crossover: Fast crossed above Slow
   bool emaCross = (FastEMA_Buffer[1] <= SlowEMA_Buffer[1] && FastEMA_Buffer[0] > SlowEMA_Buffer[0]);
   
   if(!emaCross) return false;
   
   //--- Trend Filter: Price above Trend EMA
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   bool trendFilter = (currentPrice > TrendEMA_Buffer[0]);
   
   //--- RSI Confirmation: Not overbought
   bool rsiConfirm = (RSI_Buffer[0] < RSI_Overbought && RSI_Buffer[0] > 40);
   
   //--- Momentum: Fast EMA trending up
   bool momentum = (FastEMA_Buffer[0] > FastEMA_Buffer[1]);
   
   if(trendFilter && rsiConfirm && momentum)
   {
      Print("=== LONG SIGNAL GENERATED ===");
      Print("Price: ", currentPrice, " | Fast EMA: ", NormalizeDouble(FastEMA_Buffer[0], 2));
      Print("Slow EMA: ", NormalizeDouble(SlowEMA_Buffer[0], 2), " | Trend EMA: ", NormalizeDouble(TrendEMA_Buffer[0], 2));
      Print("RSI: ", NormalizeDouble(RSI_Buffer[0], 1), " | ATR: ", NormalizeDouble(ATR_Buffer[0], 2));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Generate short signal with multiple confirmations                |
//+------------------------------------------------------------------+
bool GenerateShortSignal()
{
   //--- EMA Crossover: Fast crossed below Slow
   bool emaCross = (FastEMA_Buffer[1] >= SlowEMA_Buffer[1] && FastEMA_Buffer[0] < SlowEMA_Buffer[0]);
   
   if(!emaCross) return false;
   
   //--- Trend Filter: Price below Trend EMA
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   bool trendFilter = (currentPrice < TrendEMA_Buffer[0]);
   
   //--- RSI Confirmation: Not oversold
   bool rsiConfirm = (RSI_Buffer[0] > RSI_Oversold && RSI_Buffer[0] < 60);
   
   //--- Momentum: Fast EMA trending down
   bool momentum = (FastEMA_Buffer[0] < FastEMA_Buffer[1]);
   
   if(trendFilter && rsiConfirm && momentum)
   {
      Print("=== SHORT SIGNAL GENERATED ===");
      Print("Price: ", currentPrice, " | Fast EMA: ", NormalizeDouble(FastEMA_Buffer[0], 2));
      Print("Slow EMA: ", NormalizeDouble(SlowEMA_Buffer[0], 2), " | Trend EMA: ", NormalizeDouble(TrendEMA_Buffer[0], 2));
      Print("RSI: ", NormalizeDouble(RSI_Buffer[0], 1), " | ATR: ", NormalizeDouble(ATR_Buffer[0], 2));
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Manage existing positions (Trailing Stop & Breakeven)            |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double currentTP = PositionGetDouble(POSITION_TP);
            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                                  SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                  SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            double atr = ATR_Buffer[0];
            double newSL = currentSL;
            bool modifyNeeded = false;
            
            //--- Breakeven Management
            if(UseBreakeven && currentSL != openPrice)
            {
               double profitDistance = (posType == POSITION_TYPE_BUY) ? 
                                      (currentPrice - openPrice) : 
                                      (openPrice - currentPrice);
               
               if(profitDistance >= atr * Breakeven_ATR)
               {
                  double breakeven_price = openPrice + (posType == POSITION_TYPE_BUY ? Breakeven_Profit * _Point : -Breakeven_Profit * _Point);
                  
                  if(posType == POSITION_TYPE_BUY && currentSL < breakeven_price)
                  {
                     newSL = breakeven_price;
                     modifyNeeded = true;
                     Print("Moving to breakeven+profit for BUY position #", ticket);
                  }
                  else if(posType == POSITION_TYPE_SELL && currentSL > breakeven_price)
                  {
                     newSL = breakeven_price;
                     modifyNeeded = true;
                     Print("Moving to breakeven+profit for SELL position #", ticket);
                  }
               }
            }
            
            //--- Trailing Stop
            if(UseTrailingStop && !modifyNeeded)
            {
               double trailingDistance = atr * TrailingStop_ATR;
               double trailingStep = atr * TrailingStep_ATR;
               
               if(posType == POSITION_TYPE_BUY)
               {
                  double newTrailSL = currentPrice - trailingDistance;
                  if(newTrailSL > currentSL + trailingStep)
                  {
                     newSL = NormalizePrice(newTrailSL);
                     modifyNeeded = true;
                     //Print("Trailing stop for BUY #", ticket, " to ", newSL);
                  }
               }
               else // SELL
               {
                  double newTrailSL = currentPrice + trailingDistance;
                  if(newTrailSL < currentSL - trailingStep)
                  {
                     newSL = NormalizePrice(newTrailSL);
                     modifyNeeded = true;
                     //Print("Trailing stop for SELL #", ticket, " to ", newSL);
                  }
               }
            }
            
            //--- Modify position if needed
            if(modifyNeeded)
            {
               MqlTradeRequest request = {};
               MqlTradeResult result = {};
               
               request.action = TRADE_ACTION_SLTP;
               request.position = ticket;
               request.symbol = _Symbol;
               request.sl = newSL;
               request.tp = currentTP;
               request.magic = MagicNumber;
               
               if(OrderSend(request, result))
               {
                  if(result.retcode == TRADE_RETCODE_DONE)
                  {
                     Print("Position #", ticket, " modified successfully. New SL: ", newSL);
                  }
               }
               else
               {
                  Print("Failed to modify position #", ticket, ". Error: ", GetLastError());
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Get filling mode for orders                                      |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) 
      return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) 
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

//+------------------------------------------------------------------+
//| Open long position                                               |
//+------------------------------------------------------------------+
void OpenLongPosition()
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double atr = ATR_Buffer[0];
   
   //--- Calculate stop loss and take profit
   double stopLoss = ask - (atr * ATR_Multiplier);
   double takeProfit = ask + (atr * ATR_Multiplier * RiskReward_Ratio);
   
   //--- Normalize prices
   ask = NormalizePrice(ask);
   stopLoss = NormalizePrice(stopLoss);
   takeProfit = NormalizePrice(takeProfit);
   
   //--- Validate levels
   if(!ValidateStopLossTakeprofit(ORDER_TYPE_BUY, ask, stopLoss, takeProfit))
   {
      Print("Error: Invalid SL/TP levels for buy order");
      return;
   }
   
   //--- Calculate lot size
   double lot = CalculateLotSize(stopLoss, ask);
   
   //--- Open buy order
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_BUY;
   request.price = ask;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = "XAUUSD Pro Long";
   request.type_filling = GetFillingMode();
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("✓ BUY ORDER OPENED | Ticket: ", result.deal);
         Print("  Volume: ", lot, " | Price: ", ask);
         Print("  SL: ", stopLoss, " (", NormalizeDouble((ask - stopLoss), 2), " USD)");
         Print("  TP: ", takeProfit, " (", NormalizeDouble((takeProfit - ask), 2), " USD)");
         Print("  Risk: $", NormalizeDouble((ask - stopLoss) * lot, 2));
      }
   }
   else
   {
      Print("✗ Error opening BUY: ", GetLastError(), " | Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Open short position                                              |
//+------------------------------------------------------------------+
void OpenShortPosition()
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = ATR_Buffer[0];
   
   //--- Calculate stop loss and take profit
   double stopLoss = bid + (atr * ATR_Multiplier);
   double takeProfit = bid - (atr * ATR_Multiplier * RiskReward_Ratio);
   
   //--- Normalize prices
   bid = NormalizePrice(bid);
   stopLoss = NormalizePrice(stopLoss);
   takeProfit = NormalizePrice(takeProfit);
   
   //--- Validate levels
   if(!ValidateStopLossTakeprofit(ORDER_TYPE_SELL, bid, stopLoss, takeProfit))
   {
      Print("Error: Invalid SL/TP levels for sell order");
      return;
   }
   
   //--- Calculate lot size
   double lot = CalculateLotSize(stopLoss, bid);
   
   //--- Open sell order
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lot;
   request.type = ORDER_TYPE_SELL;
   request.price = bid;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 20;
   request.magic = MagicNumber;
   request.comment = "XAUUSD Pro Short";
   request.type_filling = GetFillingMode();
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("✓ SELL ORDER OPENED | Ticket: ", result.deal);
         Print("  Volume: ", lot, " | Price: ", bid);
         Print("  SL: ", stopLoss, " (", NormalizeDouble((stopLoss - bid), 2), " USD)");
         Print("  TP: ", takeProfit, " (", NormalizeDouble((bid - takeProfit), 2), " USD)");
         Print("  Risk: $", NormalizeDouble((stopLoss - bid) * lot, 2));
      }
   }
   else
   {
      Print("✗ Error opening SELL: ", GetLastError(), " | Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk (improved for XAUUSD)           |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLoss, double entryPrice)
{
   double lot = LotSize;
   
   if(MaximumRisk > 0)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if(accountBalance <= 0)
      {
         Print("Warning: Invalid account balance, using base lot");
         return NormalizeDouble(LotSize, 2);
      }
      
      //--- Calculate risk amount
      double riskAmount = accountBalance * (MaximumRisk / 100.0);
      
      //--- Calculate stop loss distance in price
      double stopLossDistance = MathAbs(entryPrice - stopLoss);
      
      if(stopLossDistance <= 0)
      {
         Print("Warning: Invalid stop loss distance");
         return NormalizeDouble(LotSize, 2);
      }
      
      //--- Get contract size (for XAUUSD usually 100 oz)
      double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contractSize == 0) contractSize = 100; // Default for Gold
      
      //--- Calculate lot size: Risk / (SL Distance × Contract Size)
      double calculatedLot = riskAmount / (stopLossDistance * contractSize);
      
      //--- Apply decrease factor for losing trades
      if(DecreaseFactor > 0)
      {
         int losingTrades = CountLosingTrades();
         if(losingTrades > 0)
         {
            calculatedLot = calculatedLot / (DecreaseFactor * losingTrades);
            Print("Lot decreased due to ", losingTrades, " losses: ", NormalizeDouble(calculatedLot, 2));
         }
      }
      
      //--- Apply broker limits
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      if(minLot == 0) minLot = 0.01;
      if(maxLot == 0) maxLot = 100;
      if(lotStep == 0) lotStep = 0.01;
      
      if(calculatedLot < minLot) calculatedLot = minLot;
      if(calculatedLot > maxLot) calculatedLot = maxLot;
      
      //--- Round to lot step
      calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
      
      lot = calculatedLot;
      
      Print("Position sizing: Risk=$", NormalizeDouble(riskAmount, 2), 
            " | SL Distance=$", NormalizeDouble(stopLossDistance, 2), 
            " | Lot=", lot);
   }
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Count consecutive losing trades                                  |
//+------------------------------------------------------------------+
int CountLosingTrades()
{
   int losingCount = 0;
   datetime currentTime = TimeCurrent();
   
   if(!HistorySelect(currentTime - 86400 * 7, currentTime)) // Last 7 days
   {
      return 0;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   //--- Count from most recent
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
            HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double totalProfit = profit + commission + swap;
            
            if(totalProfit < 0)
               losingCount++;
            else
               break; // Stop at first winning trade
         }
      }
   }
   
   return losingCount;
}

//+------------------------------------------------------------------+
//| Normalize price                                                  |
//+------------------------------------------------------------------+
double NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize > 0)
   {
      price = NormalizeDouble(MathRound(price / tickSize) * tickSize, _Digits);
   }
   return price;
}

//+------------------------------------------------------------------+
//| Validate stop loss and take profit levels                        |
//+------------------------------------------------------------------+
bool ValidateStopLossTakeprofit(ENUM_ORDER_TYPE orderType, double price, double sl, double tp)
{
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   
   if(stopLevel == 0) stopLevel = 10 * _Point;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      if(sl >= price - stopLevel)
      {
         Print("Error: BUY SL too close. Price:", price, " SL:", sl, " Min:", stopLevel);
         return false;
      }
      if(tp <= price + stopLevel)
      {
         Print("Error: BUY TP too close. Price:", price, " TP:", tp, " Min:", stopLevel);
         return false;
      }
   }
   else if(orderType == ORDER_TYPE_SELL)
   {
      if(sl <= price + stopLevel)
      {
         Print("Error: SELL SL too close. Price:", price, " SL:", sl, " Min:", stopLevel);
         return false;
      }
      if(tp >= price - stopLevel)
      {
         Print("Error: SELL TP too close. Price:", price, " TP:", tp, " Min:", stopLevel);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+