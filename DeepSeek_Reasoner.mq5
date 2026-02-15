//+------------------------------------------------------------------+
//|                                              DeepSeek_Reasoner.mq5 |
//|                                 Copyright 2026, DeepTrading |
//|                                            https://www.deeptrading.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, DeepTrading"
#property link      "https://www.deeptrading.com"
#property version   "1.00"

//--- Input Parameters
input int      FastEMA_Period = 9;          // Fast EMA Period
input int      SlowEMA_Period = 21;         // Slow EMA Period
input double   LotSize = 0.01;              // Lot Size (0.01 for XAUUSD)
input double   ATR_Multiplier = 2.0;        // ATR Multiplier for Stop Loss
input double   RiskReward_Ratio = 2.5;      // Risk:Reward Ratio
input int      ATR_Period = 14;             // ATR Period
input long     MagicNumber = 123456;        // Magic Number for trades
input double   MaximumRisk = 2.0;           // Maximum risk percentage (2%)
input double   DecreaseFactor = 3;          // Decrease factor for lot sizing

//--- Global Variables
int      FastEMA_Handle;
int      SlowEMA_Handle;
int      ATR_Handle;
double   FastEMA_Buffer[3];
double   SlowEMA_Buffer[3];
double   ATR_Buffer[1];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Check for valid input parameters
   if(FastEMA_Period <= 0 || SlowEMA_Period <= 0 || ATR_Period <= 0)
   {
      Print("Error: Period values must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   if(LotSize <= 0)
   {
      Print("Error: Lot size must be greater than zero");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
   //--- Create indicator handles (FIXED: Using PERIOD_CURRENT instead of _Period)
   FastEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   SlowEMA_Handle = iMA(_Symbol, PERIOD_CURRENT, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
   ATR_Handle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   
   if(FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
   {
      Print("Error: Failed to create indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set buffer arrays
   ArraySetAsSeries(FastEMA_Buffer, true);
   ArraySetAsSeries(SlowEMA_Buffer, true);
   ArraySetAsSeries(ATR_Buffer, true);
   
   //--- Set magic number for trades
   Print("Expert Advisor initialized successfully");
   Print("Symbol: ", _Symbol, ", Period: ", EnumToString(PERIOD_CURRENT));
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
   if(ATR_Handle != INVALID_HANDLE) IndicatorRelease(ATR_Handle);
   
   Print("Expert Advisor deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return; // Same bar, skip processing
   
   lastBarTime = currentBarTime;
   
   //--- Get indicator values
   if(!GetIndicatorValues())
      return;
   
   //--- Check for open positions
   bool hasPosition = CheckOpenPosition();
   
   //--- Generate signals
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
   
   if(CopyBuffer(ATR_Handle, 0, 0, 1, ATR_Buffer) < 1)
   {
      Print("Error: Failed to copy ATR buffer");
      return false;
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
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Generate long signal                                             |
//+------------------------------------------------------------------+
bool GenerateLongSignal()
{
   //--- Fast EMA crossed above Slow EMA
   if(FastEMA_Buffer[1] <= SlowEMA_Buffer[1] && FastEMA_Buffer[0] > SlowEMA_Buffer[0])
   {
      Print("Long signal generated: Fast EMA(", FastEMA_Period, ") crossed above Slow EMA(", SlowEMA_Period, ")");
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Generate short signal                                            |
//+------------------------------------------------------------------+
bool GenerateShortSignal()
{
   //--- Fast EMA crossed below Slow EMA
   if(FastEMA_Buffer[1] >= SlowEMA_Buffer[1] && FastEMA_Buffer[0] < SlowEMA_Buffer[0])
   {
      Print("Short signal generated: Fast EMA(", FastEMA_Period, ") crossed below Slow EMA(", SlowEMA_Period, ")");
      return true;
   }
   return false;
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
   
   //--- Normalize prices according to symbol specifications
   ask = NormalizePrice(ask);
   stopLoss = NormalizePrice(stopLoss);
   takeProfit = NormalizePrice(takeProfit);
   
   //--- Validate stop loss and take profit levels
   if(!ValidateStopLossTakeprofit(ORDER_TYPE_BUY, ask, stopLoss, takeProfit))
   {
      Print("Error: Invalid stop loss or take profit levels for buy order");
      return;
   }
   
   //--- Calculate lot size
   double lot = CalculateLotSize(LotSize);
   
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
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "DeepSeek Reasoner Long";
   request.type_filling = GetFillingMode(); // FIXED: Auto-detect filling mode
   
   //--- Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("Buy order opened successfully. Ticket: ", result.deal, ", Volume: ", lot, 
               ", Price: ", ask, ", SL: ", stopLoss, ", TP: ", takeProfit);
      }
      else
      {
         Print("Order partially filled or pending. Retcode: ", result.retcode, 
               ", Deal: ", result.deal, ", Volume filled: ", result.volume);
      }
   }
   else
   {
      Print("Error opening buy order: ", GetLastError(), ", Retcode: ", result.retcode);
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
   
   //--- Normalize prices according to symbol specifications
   bid = NormalizePrice(bid);
   stopLoss = NormalizePrice(stopLoss);
   takeProfit = NormalizePrice(takeProfit);
   
   //--- Validate stop loss and take profit levels
   if(!ValidateStopLossTakeprofit(ORDER_TYPE_SELL, bid, stopLoss, takeProfit))
   {
      Print("Error: Invalid stop loss or take profit levels for sell order");
      return;
   }
   
   //--- Calculate lot size
   double lot = CalculateLotSize(LotSize);
   
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
   request.deviation = 10;
   request.magic = MagicNumber;
   request.comment = "DeepSeek Reasoner Short";
   request.type_filling = GetFillingMode(); // FIXED: Auto-detect filling mode
   
   //--- Send order
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         Print("Sell order opened successfully. Ticket: ", result.deal, ", Volume: ", lot, 
               ", Price: ", bid, ", SL: ", stopLoss, ", TP: ", takeProfit);
      }
      else
      {
         Print("Order partially filled or pending. Retcode: ", result.retcode, 
               ", Deal: ", result.deal, ", Volume filled: ", result.volume);
      }
   }
   else
   {
      Print("Error opening sell order: ", GetLastError(), ", Retcode: ", result.retcode);
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size with risk management                          |
//+------------------------------------------------------------------+
double CalculateLotSize(double baseLot)
{
   double lot = baseLot;
   
   //--- If MaximumRisk is set (> 0), calculate lot based on risk percentage
   if(MaximumRisk > 0)
   {
      double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      
      if(accountBalance <= 0)
      {
         Print("Warning: Account balance is zero or negative, using base lot size");
         return NormalizeDouble(baseLot, 2);
      }
      
      //--- Calculate risk amount in account currency
      double riskAmount = accountBalance * (MaximumRisk / 100.0);
      
      //--- Get symbol information for proper lot calculation
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      
      if(tickSize == 0 || tickValue == 0 || point == 0)
      {
         Print("Warning: Failed to get symbol properties, using base lot size");
         return NormalizeDouble(baseLot, 2);
      }
      
      //--- Calculate approximate stop loss distance in points
      double atr = ATR_Buffer[0];
      double stopLossDistancePoints = (atr * ATR_Multiplier) / point;
      
      if(stopLossDistancePoints <= 0)
      {
         Print("Warning: Invalid stop loss distance, using base lot size");
         return NormalizeDouble(baseLot, 2);
      }
      
      //--- Calculate lot size based on risk amount
      double pointValuePerLot = tickValue * (tickSize / point);
      double calculatedLot = riskAmount / (stopLossDistancePoints * pointValuePerLot);
      
      //--- Apply decrease factor if there are losing trades
      if(DecreaseFactor > 0)
      {
         int losingTrades = CountLosingTrades();
         if(losingTrades > 0)
         {
            calculatedLot = calculatedLot / (DecreaseFactor * losingTrades);
            Print("Decreasing lot size due to ", losingTrades, " consecutive losing trades");
         }
      }
      
      //--- Ensure lot is within broker limits
      double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
      double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
      double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
      
      if(minLot == 0 || maxLot == 0 || lotStep == 0)
      {
         Print("Warning: Failed to get lot size limits, using base lot size");
         return NormalizeDouble(baseLot, 2);
      }
      
      if(calculatedLot < minLot) calculatedLot = minLot;
      if(calculatedLot > maxLot) calculatedLot = maxLot;
      
      //--- Round to nearest lot step
      calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
      
      lot = calculatedLot;
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
   
   //--- Look at recent trades in history (last 24 hours)
   if(!HistorySelect(currentTime - 86400, currentTime))
   {
      Print("Warning: Failed to select history");
      return 0;
   }
   
   int totalHistory = HistoryDealsTotal();
   
   //--- Count consecutive losing trades with our magic number
   for(int i = totalHistory - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket > 0)
      {
         long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
         string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
         
         if(magic == MagicNumber && symbol == _Symbol)
         {
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            double swap = HistoryDealGetDouble(ticket, DEAL_SWAP);
            double totalProfit = profit + commission + swap;
            
            if(totalProfit < 0)
            {
               losingCount++;
            }
            else
            {
               // Found a winning trade, stop counting
               break;
            }
         }
      }
   }
   
   return losingCount;
}

//+------------------------------------------------------------------+
//| Normalize price according to symbol specifications               |
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
   //--- Get stop level
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   
   if(stopLevel == 0) stopLevel = 10 * _Point; // Default if broker allows zero
   
   //--- For buy orders
   if(orderType == ORDER_TYPE_BUY)
   {
      // Stop loss must be below current price
      if(sl >= price - stopLevel)
      {
         Print("Error: Stop loss too close to price for buy order. Price: ", price, 
               " SL: ", sl, " Required distance: ", stopLevel);
         return false;
      }
      // Take profit must be above current price
      if(tp <= price + stopLevel)
      {
         Print("Error: Take profit too close to price for buy order. Price: ", price, 
               " TP: ", tp, " Required distance: ", stopLevel);
         return false;
      }
   }
   //--- For sell orders
   else if(orderType == ORDER_TYPE_SELL)
   {
      // Stop loss must be above current price
      if(sl <= price + stopLevel)
      {
         Print("Error: Stop loss too close to price for sell order. Price: ", price, 
               " SL: ", sl, " Required distance: ", stopLevel);
         return false;
      }
      // Take profit must be below current price
      if(tp >= price - stopLevel)
      {
         Print("Error: Take profit too close to price for sell order. Price: ", price, 
               " TP: ", tp, " Required distance: ", stopLevel);
         return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+