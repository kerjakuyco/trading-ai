//+------------------------------------------------------------------+
//|                                             DeepSeek_Reasoner.mq5 |
//|                         Ultimate Gold Trading System - Pro Edition|
//|                    High Winrate + Low Drawdown + Trend Following  |
//+------------------------------------------------------------------+
#property copyright "DeepTrading.com"
#property version   "5.00"
#property description "Professional XAUUSD system combining trend following, pullbacks, and structure"
#property strict

//--- Input Parameters
input group "=== CAPITAL MANAGEMENT ==="
input double   AccountBalance = 1000.0;     // Account Balance (USD)
input double   RiskPercentPerTrade = 1.0;   // Risk Per Trade (%) - Conservative
input double   MaxDailyDrawdown = 3.0;      // Max Daily Drawdown (%)
input int      MaxTradesPerDay = 3;         // Max Trades Per Day

input group "=== MULTI-TIMEFRAME TREND ==="
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_H4;  // Higher Timeframe for Trend
input int      HTF_TrendEMA = 50;           // HTF Trend EMA (50 is key)
input int      MainTrendEMA = 21;           // Main Chart Trend EMA
input int      FastEMA = 9;                 // Fast EMA for entries
input bool     OnlyTradeTrendDirection = true; // Only Trade With HTF Trend

input group "=== PULLBACK STRATEGY ==="
input bool     UsePullbackEntry = true;     // Use Pullback to EMA (High Winrate)
input double   PullbackDistance = 0.3;      // Max Distance from EMA (ATR multiplier)
input bool     WaitForPriceRejection = true;// Wait for Rejection Candle
input int      ConsecutiveBarsInDirection = 2; // Bars confirming direction

input group "=== MARKET STRUCTURE ==="
input bool     UseStructureFilter = true;   // Use Market Structure (HH/HL for uptrend)
input int      SwingLookback = 20;          // Bars to look for swing highs/lows
input bool     AvoidRangeMarkets = true;    // Skip ranging/choppy markets
input double   MinTrendStrength = 0.5;      // Minimum ADX for trend

input group "=== MOMENTUM & CONFIRMATION ==="
input int      ADX_Period = 14;             // ADX Period
input double   MinADX = 25;                 // Minimum ADX (trend strength)
input int      RSI_Period = 14;             // RSI Period
input double   RSI_Bullish_Min = 40;        // RSI Min for Longs
input double   RSI_Bullish_Max = 70;        // RSI Max for Longs
input double   RSI_Bearish_Min = 30;        // RSI Min for Shorts
input double   RSI_Bearish_Max = 60;        // RSI Max for Shorts

input group "=== VOLATILITY & FILTERS ==="
input int      ATR_Period = 14;             // ATR Period
input double   ATR_Multiplier_SL = 2.0;     // Stop Loss (ATR Multiplier)
input double   ATR_Multiplier_TP = 4.0;     // Take Profit (ATR Multiplier)
input double   MinATR = 0.8;                // Minimum ATR to trade
input double   MaxATR = 6.0;                // Maximum ATR to trade
input double   MaxSpread = 30;              // Maximum Spread (points)

input group "=== SESSION FILTER ==="
input bool     UseSessionFilter = true;     // Trade Specific Sessions Only
input bool     TradeLondonSession = true;   // Trade London Session (High Volume)
input bool     TradeNYSession = true;       // Trade NY Session (High Volume)
input bool     TradeAsianSession = false;   // Trade Asian Session (Ranging)
input int      LondonStart = 7;             // London Open (GMT)
input int      LondonEnd = 16;              // London Close (GMT)
input int      NYStart = 13;                // NY Open (GMT)
input int      NYEnd = 21;                  // NY Close (GMT)

input group "=== ADVANCED EXITS (Critical for Profit) ==="
input bool     UseSmartTrailing = true;     // Smart Trailing Stop System
input double   TrailStart_ATR = 2.0;        // Start Trailing After (ATR)
input double   TrailDistance_ATR = 1.5;     // Trail Distance (ATR)
input bool     UsePartialTakeProfit = true; // Partial Profit Taking
input double   PartialTP1_ATR = 2.0;        // First TP (close 50%)
input double   PartialTP1_Percent = 50;     // Close % at TP1
input bool     BreakevenAfterTP1 = true;    // Move to BE after TP1 hit
input bool     UseTimeBasedExit = true;     // Exit after X hours if not profitable
input int      MaxHoursInTrade = 24;        // Max hours in trade

input group "=== RISK MANAGEMENT ==="
input bool     UseMartingale = false;       // ⚠️ Martingale (NOT recommended)
input bool     ReduceAfterLoss = true;      // Reduce size after losses
input int      ConsecutiveLossLimit = 3;    // Reduce after X losses
input double   LossReductionFactor = 0.5;   // Reduce to 50% after losses

input group "=== SYSTEM ==="
input long     MagicNumber = 999888;        // Magic Number
input string   TradeComment = "XAU_Pro";    // Trade Comment
input bool     ShowDashboard = true;        // Show Info Dashboard
input bool     DetailedLogs = true;         // Detailed Logging

//--- Global Variables
int handleHTF_EMA, handleMainEMA, handleFastEMA;
int handleATR, handleRSI, handleADX;
double htfEMA[], mainEMA[], fastEMA[];
double atrBuffer[], rsiBuffer[], adxBuffer[];

datetime lastTradeTime = 0;
int tradesThisDay = 0;
datetime currentDay = 0;
double dailyPL = 0;
int consecutiveLosses = 0;
bool tradingHalted = false;

struct TradeStats {
   int totalTrades;
   int winTrades;
   int lossTrades;
   double totalProfit;
   double bestTrade;
   double worstTrade;
   double currentWinrate;
} stats;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate
   if(RiskPercentPerTrade > 5.0)
   {
      Alert("⚠️ WARNING: Risk per trade > 5% is very aggressive!");
   }
   
   //--- Create indicators on current timeframe
   handleMainEMA = iMA(_Symbol, PERIOD_CURRENT, MainTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleFastEMA = iMA(_Symbol, PERIOD_CURRENT, FastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handleATR = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
   handleRSI = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
   handleADX = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);
   
   //--- Create HTF EMA
   handleHTF_EMA = iMA(_Symbol, HigherTimeframe, HTF_TrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   
   //--- Validate handles
   if(handleMainEMA == INVALID_HANDLE || handleFastEMA == INVALID_HANDLE || 
      handleHTF_EMA == INVALID_HANDLE || handleATR == INVALID_HANDLE || 
      handleRSI == INVALID_HANDLE || handleADX == INVALID_HANDLE)
   {
      Alert("❌ ERROR: Failed to create indicators!");
      return INIT_FAILED;
   }
   
   //--- Set arrays as series
   ArraySetAsSeries(htfEMA, true);
   ArraySetAsSeries(mainEMA, true);
   ArraySetAsSeries(fastEMA, true);
   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(adxBuffer, true);
   
   //--- Initialize stats
   LoadStats();
   
   //--- Print welcome message
   PrintWelcomeMessage();
   
   //--- Create dashboard
   if(ShowDashboard)
      CreateDashboard();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release handles
   IndicatorRelease(handleHTF_EMA);
   IndicatorRelease(handleMainEMA);
   IndicatorRelease(handleFastEMA);
   IndicatorRelease(handleATR);
   IndicatorRelease(handleRSI);
   IndicatorRelease(handleADX);
   
   //--- Remove dashboard
   ObjectsDeleteAll(0, "Dashboard_");
   
   Print("═══════════════════════════════════════════════════════════════");
   Print("EA Stopped. Final Statistics:");
   Print("Total Trades: ", stats.totalTrades);
   Print("Win Rate: ", NormalizeDouble(stats.currentWinrate, 2), "%");
   Print("Total P/L: $", NormalizeDouble(stats.totalProfit, 2));
   Print("═══════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Update dashboard
   if(ShowDashboard)
      UpdateDashboard();
   
   //--- Check daily limits
   CheckDailyLimits();
   
   if(tradingHalted)
   {
      ManageOpenPositions();
      return;
   }
   
   //--- Manage open positions
   ManageOpenPositions();
   
   //--- Check for new bar
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;
   
   lastBarTime = currentBarTime;
   
   //--- Get indicator values
   if(!UpdateIndicators())
      return;
   
   //--- Apply filters
   if(!PassAllFilters())
      return;
   
   //--- Check for positions
   if(GetOpenPositionsCount() > 0)
      return; // Only 1 position at a time for max control
   
   //--- Check signals
   int signal = AnalyzeMarket();
   
   if(signal == 1)
      OpenTrade(ORDER_TYPE_BUY);
   else if(signal == -1)
      OpenTrade(ORDER_TYPE_SELL);
}

//+------------------------------------------------------------------+
//| Update all indicators                                            |
//+------------------------------------------------------------------+
bool UpdateIndicators()
{
   if(CopyBuffer(handleHTF_EMA, 0, 0, 3, htfEMA) < 3) return false;
   if(CopyBuffer(handleMainEMA, 0, 0, 10, mainEMA) < 10) return false;
   if(CopyBuffer(handleFastEMA, 0, 0, 10, fastEMA) < 10) return false;
   if(CopyBuffer(handleATR, 0, 0, 3, atrBuffer) < 3) return false;
   if(CopyBuffer(handleRSI, 0, 0, 3, rsiBuffer) < 3) return false;
   if(CopyBuffer(handleADX, 0, 0, 3, adxBuffer) < 3) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Apply all filters                                                |
//+------------------------------------------------------------------+
bool PassAllFilters()
{
   //--- Volatility filter
   if(atrBuffer[0] < MinATR || atrBuffer[0] > MaxATR)
   {
      if(DetailedLogs) Print("❌ ATR Filter: ", NormalizeDouble(atrBuffer[0], 2));
      return false;
   }
   
   //--- Spread filter
   double spread = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - SymbolInfoDouble(_Symbol, SYMBOL_BID)) / _Point;
   if(spread > MaxSpread)
   {
      if(DetailedLogs) Print("❌ Spread too high: ", spread);
      return false;
   }
   
   //--- ADX filter (trend strength)
   if(adxBuffer[0] < MinADX)
   {
      if(DetailedLogs) Print("❌ ADX too low (no trend): ", NormalizeDouble(adxBuffer[0], 1));
      return false;
   }
   
   //--- Session filter
   if(UseSessionFilter && !IsGoodTradingSession())
   {
      return false;
   }
   
   //--- Ranging market filter
   if(AvoidRangeMarkets && IsMarketRanging())
   {
      if(DetailedLogs) Print("❌ Market is ranging");
      return false;
   }
   
   //--- Rate limiting (no more than 1 trade per 2 hours)
   if(TimeCurrent() - lastTradeTime < 7200)
   {
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyze market for entry (THE CORE LOGIC)                       |
//+------------------------------------------------------------------+
int AnalyzeMarket()
{
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   //--- Get HTF Trend Direction
   int htfTrend = GetHTFTrend();
   
   if(htfTrend == 0)
   {
      if(DetailedLogs) Print("⚠️ No clear HTF trend");
      return 0;
   }
   
   //--- Check market structure
   if(UseStructureFilter)
   {
      int structure = GetMarketStructure();
      if(structure != htfTrend)
      {
         if(DetailedLogs) Print("❌ Market structure not aligned with HTF trend");
         return 0;
      }
   }
   
   //=== LONG SIGNAL ===
   if(htfTrend == 1)
   {
      //--- Price must be above HTF EMA
      if(currentPrice < htfEMA[0])
         return 0;
      
      //--- Check if this is a pullback to EMA
      if(UsePullbackEntry)
      {
         double distanceToEMA = MathAbs(currentPrice - mainEMA[0]) / _Point;
         double maxDistance = atrBuffer[0] * PullbackDistance / _Point;
         
         if(distanceToEMA > maxDistance)
         {
            if(DetailedLogs) Print("⏳ Waiting for pullback to EMA (distance: ", NormalizeDouble(distanceToEMA, 1), ")");
            return 0;
         }
      }
      
      //--- Fast EMA must be above Main EMA or crossing above
      bool emaCrossUp = (fastEMA[1] <= mainEMA[1] && fastEMA[0] > mainEMA[0]) || 
                        (fastEMA[0] > mainEMA[0]);
      
      if(!emaCrossUp)
         return 0;
      
      //--- RSI in bullish zone
      if(rsiBuffer[0] < RSI_Bullish_Min || rsiBuffer[0] > RSI_Bullish_Max)
      {
         if(DetailedLogs) Print("❌ RSI not in bullish zone: ", NormalizeDouble(rsiBuffer[0], 1));
         return 0;
      }
      
      //--- Check for rejection/confirmation candle
      if(WaitForPriceRejection)
      {
         if(!IsBullishRejectionCandle())
         {
            if(DetailedLogs) Print("⏳ Waiting for bullish rejection candle");
            return 0;
         }
      }
      
      //--- Consecutive bars confirmation
      if(!CheckConsecutiveBullishBars())
         return 0;
      
      //--- RSI momentum (rising)
      if(rsiBuffer[0] <= rsiBuffer[1])
      {
         if(DetailedLogs) Print("❌ RSI not rising");
         return 0;
      }
      
      //--- All checks passed!
      LogTradeSignal("LONG", currentPrice);
      return 1;
   }
   
   //=== SHORT SIGNAL ===
   else if(htfTrend == -1)
   {
      //--- Price must be below HTF EMA
      if(currentPrice > htfEMA[0])
         return 0;
      
      //--- Check if this is a pullback to EMA
      if(UsePullbackEntry)
      {
         double distanceToEMA = MathAbs(currentPrice - mainEMA[0]) / _Point;
         double maxDistance = atrBuffer[0] * PullbackDistance / _Point;
         
         if(distanceToEMA > maxDistance)
         {
            if(DetailedLogs) Print("⏳ Waiting for pullback to EMA");
            return 0;
         }
      }
      
      //--- Fast EMA must be below Main EMA or crossing below
      bool emaCrossDown = (fastEMA[1] >= mainEMA[1] && fastEMA[0] < mainEMA[0]) || 
                          (fastEMA[0] < mainEMA[0]);
      
      if(!emaCrossDown)
         return 0;
      
      //--- RSI in bearish zone
      if(rsiBuffer[0] < RSI_Bearish_Min || rsiBuffer[0] > RSI_Bearish_Max)
      {
         if(DetailedLogs) Print("❌ RSI not in bearish zone: ", NormalizeDouble(rsiBuffer[0], 1));
         return 0;
      }
      
      //--- Check for rejection candle
      if(WaitForPriceRejection)
      {
         if(!IsBearishRejectionCandle())
         {
            if(DetailedLogs) Print("⏳ Waiting for bearish rejection candle");
            return 0;
         }
      }
      
      //--- Consecutive bars confirmation
      if(!CheckConsecutiveBearishBars())
         return 0;
      
      //--- RSI momentum (falling)
      if(rsiBuffer[0] >= rsiBuffer[1])
      {
         if(DetailedLogs) Print("❌ RSI not falling");
         return 0;
      }
      
      //--- All checks passed!
      LogTradeSignal("SHORT", currentPrice);
      return -1;
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Higher Timeframe Trend                                       |
//+------------------------------------------------------------------+
int GetHTFTrend()
{
   double currentPrice = iClose(_Symbol, PERIOD_CURRENT, 0);
   
   //--- Simple but effective: Price vs HTF EMA
   if(currentPrice > htfEMA[0] * 1.001) // 0.1% buffer
      return 1;  // Uptrend
   else if(currentPrice < htfEMA[0] * 0.999)
      return -1; // Downtrend
   
   return 0; // Neutral
}

//+------------------------------------------------------------------+
//| Get Market Structure (Higher Highs/Higher Lows)                  |
//+------------------------------------------------------------------+
int GetMarketStructure()
{
   //--- Find recent swing highs and lows
   double recentHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, SwingLookback, 1));
   double recentLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, SwingLookback, 1));
   
   double previousHigh = iHigh(_Symbol, PERIOD_CURRENT, iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, SwingLookback, SwingLookback + 1));
   double previousLow = iLow(_Symbol, PERIOD_CURRENT, iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, SwingLookback, SwingLookback + 1));
   
   //--- Higher Highs and Higher Lows = Uptrend
   if(recentHigh > previousHigh && recentLow > previousLow)
      return 1;
   
   //--- Lower Highs and Lower Lows = Downtrend
   if(recentHigh < previousHigh && recentLow < previousLow)
      return -1;
   
   return 0; // Ranging/unclear
}

//+------------------------------------------------------------------+
//| Check if market is ranging                                       |
//+------------------------------------------------------------------+
bool IsMarketRanging()
{
   //--- Use ADX: if below 20, market is ranging
   if(adxBuffer[0] < 20)
      return true;
   
   //--- Check EMA flatness
   double emaSlope = MathAbs(mainEMA[0] - mainEMA[5]) / atrBuffer[0];
   if(emaSlope < 0.1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for bullish rejection candle                               |
//+------------------------------------------------------------------+
bool IsBullishRejectionCandle()
{
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   double bodySize = MathAbs(close1 - open1);
   double totalSize = high1 - low1;
   double lowerWick = MathMin(open1, close1) - low1;
   
   //--- Bullish candle with long lower wick (rejection of lower prices)
   if(close1 > open1 && lowerWick > bodySize * 0.5)
      return true;
   
   //--- Or just bullish close
   if(close1 > open1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for bearish rejection candle                               |
//+------------------------------------------------------------------+
bool IsBearishRejectionCandle()
{
   double open1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
   double close1 = iClose(_Symbol, PERIOD_CURRENT, 1);
   double high1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
   double low1 = iLow(_Symbol, PERIOD_CURRENT, 1);
   
   double bodySize = MathAbs(close1 - open1);
   double totalSize = high1 - low1;
   double upperWick = high1 - MathMax(open1, close1);
   
   //--- Bearish candle with long upper wick (rejection of higher prices)
   if(close1 < open1 && upperWick > bodySize * 0.5)
      return true;
   
   //--- Or just bearish close
   if(close1 < open1)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check consecutive bullish bars                                   |
//+------------------------------------------------------------------+
bool CheckConsecutiveBullishBars()
{
   int bullishCount = 0;
   
   for(int i = 1; i <= ConsecutiveBarsInDirection; i++)
   {
      if(iClose(_Symbol, PERIOD_CURRENT, i) > iOpen(_Symbol, PERIOD_CURRENT, i))
         bullishCount++;
   }
   
   return (bullishCount >= ConsecutiveBarsInDirection - 1);
}

//+------------------------------------------------------------------+
//| Check consecutive bearish bars                                   |
//+------------------------------------------------------------------+
bool CheckConsecutiveBearishBars()
{
   int bearishCount = 0;
   
   for(int i = 1; i <= ConsecutiveBarsInDirection; i++)
   {
      if(iClose(_Symbol, PERIOD_CURRENT, i) < iOpen(_Symbol, PERIOD_CURRENT, i))
         bearishCount++;
   }
   
   return (bearishCount >= ConsecutiveBarsInDirection - 1);
}

//+------------------------------------------------------------------+
//| Check if good trading session                                    |
//+------------------------------------------------------------------+
bool IsGoodTradingSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   int hour = dt.hour;
   
   if(TradeLondonSession && hour >= LondonStart && hour < LondonEnd)
      return true;
   
   if(TradeNYSession && hour >= NYStart && hour < NYEnd)
      return true;
   
   if(TradeAsianSession)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Open trade with professional risk management                     |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double atr = atrBuffer[0];
   
   //--- Calculate SL and TP
   double stopLoss, takeProfit;
   
   if(orderType == ORDER_TYPE_BUY)
   {
      stopLoss = price - (atr * ATR_Multiplier_SL);
      takeProfit = price + (atr * ATR_Multiplier_TP);
   }
   else
   {
      stopLoss = price + (atr * ATR_Multiplier_SL);
      takeProfit = price - (atr * ATR_Multiplier_TP);
   }
   
   //--- Normalize
   price = NormalizeDouble(price, _Digits);
   stopLoss = NormalizeDouble(stopLoss, _Digits);
   takeProfit = NormalizeDouble(takeProfit, _Digits);
   
   //--- Calculate lot size based on risk
   double lotSize = CalculateLotSize(price, stopLoss);
   
   //--- Validate
   if(!ValidateSLTP(orderType, price, stopLoss, takeProfit))
      return;
   
   //--- Place order
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_DEAL;
   request.symbol = _Symbol;
   request.volume = lotSize;
   request.type = orderType;
   request.price = price;
   request.sl = stopLoss;
   request.tp = takeProfit;
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = TradeComment;
   request.type_filling = GetFillingMode();
   
   if(OrderSend(request, result))
   {
      if(result.retcode == TRADE_RETCODE_DONE)
      {
         lastTradeTime = TimeCurrent();
         tradesThisDay++;
         
         LogSuccessfulTrade(orderType, result.deal, price, stopLoss, takeProfit, lotSize, atr);
      }
      else
      {
         Print("❌ Order failed. Retcode: ", result.retcode);
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate lot size based on risk percentage                      |
//+------------------------------------------------------------------+
double CalculateLotSize(double entryPrice, double stopLoss)
{
   double balance = AccountBalance;
   double riskAmount = balance * (RiskPercentPerTrade / 100.0);
   
   //--- Apply reduction after losses
   if(ReduceAfterLoss && consecutiveLosses >= ConsecutiveLossLimit)
   {
      riskAmount *= LossReductionFactor;
      Print("⚠️ Risk reduced to ", NormalizeDouble(riskAmount, 2), " due to ", consecutiveLosses, " losses");
   }
   
   double stopDistance = MathAbs(entryPrice - stopLoss);
   double contractSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   double lot = riskAmount / (stopDistance * contractSize);
   
   //--- Apply broker limits
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Manage open positions - ADVANCED EXIT LOGIC                      |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && PositionSelectByTicket(ticket))
      {
         if(PositionGetString(POSITION_SYMBOL) != _Symbol || 
            PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
         
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL = PositionGetDouble(POSITION_SL);
         double currentTP = PositionGetDouble(POSITION_TP);
         double openTime = (double)PositionGetInteger(POSITION_TIME);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         double volume = PositionGetDouble(POSITION_VOLUME);
         
         double currentPrice = (posType == POSITION_TYPE_BUY) ? 
                               SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                               SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         double profit = PositionGetDouble(POSITION_PROFIT);
         double atr = atrBuffer[0];
         
         //--- Time-based exit
         if(UseTimeBasedExit)
         {
            double hoursInTrade = (TimeCurrent() - openTime) / 3600.0;
            if(hoursInTrade > MaxHoursInTrade && profit < 0)
            {
               ClosePosition(ticket, "Time Exit (Max hours reached)");
               continue;
            }
         }
         
         //--- Partial take profit
         if(UsePartialTakeProfit)
         {
            double profitDistance = (posType == POSITION_TYPE_BUY) ? 
                                   (currentPrice - openPrice) : 
                                   (openPrice - currentPrice);
            
            if(profitDistance >= atr * PartialTP1_ATR && volume > SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
            {
               double closeVolume = NormalizeDouble(volume * (PartialTP1_Percent / 100.0), 2);
               if(closeVolume >= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN))
               {
                  PartialClose(ticket, closeVolume, "Partial TP1");
                  
                  //--- Move to breakeven
                  if(BreakevenAfterTP1)
                  {
                     ModifyPosition(ticket, openPrice, currentTP, "Breakeven after TP1");
                  }
               }
            }
         }
         
         //--- Smart trailing stop
         if(UseSmartTrailing)
         {
            double profitDistance = (posType == POSITION_TYPE_BUY) ? 
                                   (currentPrice - openPrice) : 
                                   (openPrice - currentPrice);
            
            if(profitDistance >= atr * TrailStart_ATR)
            {
               double newSL;
               
               if(posType == POSITION_TYPE_BUY)
               {
                  newSL = currentPrice - (atr * TrailDistance_ATR);
                  if(newSL > currentSL + (atr * 0.3)) // Only move if significant
                  {
                     ModifyPosition(ticket, newSL, currentTP, "Trailing Stop");
                  }
               }
               else
               {
                  newSL = currentPrice + (atr * TrailDistance_ATR);
                  if(newSL < currentSL - (atr * 0.3))
                  {
                     ModifyPosition(ticket, newSL, currentTP, "Trailing Stop");
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close position                                                    |
//+------------------------------------------------------------------+
void ClosePosition(ulong ticket, string reason)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(!PositionSelectByTicket(ticket))
      return;
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = PositionGetDouble(POSITION_VOLUME);
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = reason;
   
   if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
   {
      Print("✅ Position #", ticket, " closed. Reason: ", reason);
   }
}

//+------------------------------------------------------------------+
//| Partial close                                                     |
//+------------------------------------------------------------------+
void PartialClose(ulong ticket, double volume, string reason)
{
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   if(!PositionSelectByTicket(ticket))
      return;
   
   request.action = TRADE_ACTION_DEAL;
   request.position = ticket;
   request.symbol = _Symbol;
   request.volume = volume;
   request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   request.price = (request.type == ORDER_TYPE_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   request.deviation = 30;
   request.magic = MagicNumber;
   request.comment = reason;
   
   if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
   {
      Print("💰 Partial close #", ticket, ": ", volume, " lots. Reason: ", reason);
   }
}

//+------------------------------------------------------------------+
//| Modify position                                                   |
//+------------------------------------------------------------------+
void ModifyPosition(ulong ticket, double newSL, double newTP, string reason)
{
   if(!PositionSelectByTicket(ticket))
      return;
   
   MqlTradeRequest request = {};
   MqlTradeResult result = {};
   
   request.action = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol = _Symbol;
   request.sl = NormalizeDouble(newSL, _Digits);
   request.tp = NormalizeDouble(newTP, _Digits);
   request.magic = MagicNumber;
   
   if(OrderSend(request, result) && result.retcode == TRADE_RETCODE_DONE)
   {
      Print("✅ Modified #", ticket, ". New SL: ", newSL, ". Reason: ", reason);
   }
}

//+------------------------------------------------------------------+
//| Check daily limits                                                |
//+------------------------------------------------------------------+
void CheckDailyLimits()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   datetime today = StringToTime(IntegerToString(dt.year) + "." + IntegerToString(dt.mon) + "." + IntegerToString(dt.day));
   
   if(today != currentDay)
   {
      currentDay = today;
      tradesThisDay = 0;
      dailyPL = 0;
      tradingHalted = false;
   }
   
   //--- Calculate daily P/L
   dailyPL = CalculateDailyPL();
   
   //--- Check max trades
   if(tradesThisDay >= MaxTradesPerDay)
   {
      if(!tradingHalted)
         Print("⚠️ Max daily trades reached (", MaxTradesPerDay, ")");
      tradingHalted = true;
   }
   
   //--- Check max drawdown
   double ddPercent = (dailyPL / AccountBalance) * 100.0;
   if(ddPercent < -MaxDailyDrawdown)
   {
      if(!tradingHalted)
         Print("🛑 Max daily drawdown reached (", NormalizeDouble(ddPercent, 2), "%)");
      tradingHalted = true;
   }
}

//+------------------------------------------------------------------+
//| Calculate daily P/L                                               |
//+------------------------------------------------------------------+
double CalculateDailyPL()
{
   double pl = 0;
   datetime todayStart = iTime(_Symbol, PERIOD_D1, 0);
   
   if(!HistorySelect(todayStart, TimeCurrent()))
      return 0;
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
      {
         pl += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         pl += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
         pl += HistoryDealGetDouble(ticket, DEAL_SWAP);
      }
   }
   
   return pl;
}

//+------------------------------------------------------------------+
//| Get open positions count                                          |
//+------------------------------------------------------------------+
int GetOpenPositionsCount()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket) && 
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber)
      {
         count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Load statistics                                                   |
//+------------------------------------------------------------------+
void LoadStats()
{
   stats.totalTrades = 0;
   stats.winTrades = 0;
   stats.lossTrades = 0;
   stats.totalProfit = 0;
   stats.bestTrade = 0;
   stats.worstTrade = 0;
   
   if(!HistorySelect(0, TimeCurrent()))
      return;
   
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(HistoryDealGetInteger(ticket, DEAL_MAGIC) == MagicNumber &&
         HistoryDealGetString(ticket, DEAL_SYMBOL) == _Symbol)
      {
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         stats.totalProfit += profit;
         stats.totalTrades++;
         
         if(profit > 0)
            stats.winTrades++;
         else if(profit < 0)
            stats.lossTrades++;
         
         if(profit > stats.bestTrade) stats.bestTrade = profit;
         if(profit < stats.worstTrade) stats.worstTrade = profit;
      }
   }
   
   if(stats.totalTrades > 0)
      stats.currentWinrate = (double)stats.winTrades / stats.totalTrades * 100.0;
}

//+------------------------------------------------------------------+
//| Helper functions                                                  |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE_FILLING GetFillingMode()
{
   uint filling = (uint)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
   if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
}

bool ValidateSLTP(ENUM_ORDER_TYPE type, double price, double sl, double tp)
{
   double stopLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(stopLevel == 0) stopLevel = 10 * _Point;
   
   if(type == ORDER_TYPE_BUY)
   {
      if(sl >= price - stopLevel || tp <= price + stopLevel)
         return false;
   }
   else
   {
      if(sl <= price + stopLevel || tp >= price - stopLevel)
         return false;
   }
   return true;
}

void LogTradeSignal(string direction, double price)
{
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║  🎯 ", direction, " SIGNAL - PROFESSIONAL SETUP CONFIRMED  ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("📍 Price: ", price);
   Print("📊 HTF EMA: ", NormalizeDouble(htfEMA[0], 2));
   Print("📈 Main EMA: ", NormalizeDouble(mainEMA[0], 2), " | Fast EMA: ", NormalizeDouble(fastEMA[0], 2));
   Print("🎯 RSI: ", NormalizeDouble(rsiBuffer[0], 1), " | ADX: ", NormalizeDouble(adxBuffer[0], 1));
   Print("📊 ATR: ", NormalizeDouble(atrBuffer[0], 2));
   Print("══════════════════════════════════════════════════════════════");
}

void LogSuccessfulTrade(ENUM_ORDER_TYPE type, ulong ticket, double entry, double sl, double tp, double lot, double atr)
{
   double risk = MathAbs(entry - sl) * lot * 100;
   double reward = MathAbs(tp - entry) * lot * 100;
   
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║       ✅ ", (type == ORDER_TYPE_BUY ? "BUY" : "SELL"), " ORDER EXECUTED ✅                          ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("🎫 Ticket: ", ticket);
   Print("💰 Lot: ", lot);
   Print("📍 Entry: ", entry);
   Print("🛡️  SL: ", sl, " (", NormalizeDouble(MathAbs(entry - sl), 2), " pts)");
   Print("🎯 TP: ", tp, " (", NormalizeDouble(MathAbs(tp - entry), 2), " pts)");
   Print("💵 Risk: $", NormalizeDouble(risk, 2), " | Reward: $", NormalizeDouble(reward, 2));
   Print("📊 R:R = 1:", NormalizeDouble(reward / risk, 2));
   Print("══════════════════════════════════════════════════════════════");
}

void PrintWelcomeMessage()
{
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║     🏆 XAUUSD PROFESSIONAL TRADER SYSTEM 🏆                 ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   Print("💰 Account: $", NormalizeDouble(AccountBalance, 2));
   Print("⚠️  Risk/Trade: ", RiskPercentPerTrade, "%");
   Print("📊 Strategy: Multi-Timeframe + Pullback + Structure");
   Print("⏰ HTF: ", EnumToString(HigherTimeframe), " | Current: ", EnumToString(PERIOD_CURRENT));
   Print("🎯 Target: High Winrate + Low Drawdown");
   Print("══════════════════════════════════════════════════════════════");
}

void CreateDashboard()
{
   // Simple text dashboard - you can enhance with OBJ_LABEL objects
}

void UpdateDashboard()
{
   // Update dashboard info
}
//+------------------------------------------------------------------+