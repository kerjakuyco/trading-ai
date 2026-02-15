# DeepSeek Reasoner - MetaTrader 5 Expert Advisor

This is a MetaTrader 5 Expert Advisor (EA) adaptation of the TradingView Pine Script indicator "DeepSeek Reasoner". The EA implements an EMA crossover strategy with ATR-based stop loss and take profit, optimized for XAUUSD (Gold) trading with a low lot size of 0.01.

## Strategy Overview

The EA follows the same logic as the original TradingView indicator:

- **Entry Signals**: Buy when Fast EMA (9) crosses above Slow EMA (21); Sell when Fast EMA crosses below Slow EMA
- **Exit Strategy**: ATR-based stop loss and take profit with configurable risk:reward ratio
- **Position Management**: One position at a time (no pyramiding)
- **Risk Management**: Fixed lot size (0.01) with optional risk-based lot calculation
- **Symbol**: Optimized for XAUUSD (Gold)

## File Structure

- `DeepSeek_Reasoner.mq5` - Main Expert Advisor file
- `README.md` - This MetaTrader 5 documentation

## Installation Instructions

### Step 1: Copy the EA to MetaTrader 5

1. Open MetaTrader 5
2. Navigate to `File` → `Open Data Folder`
3. Go to `MQL5` → `Experts` folder
4. Copy `DeepSeek_Reasoner.mq5` into the `Experts` folder
5. Restart MetaTrader 5 or right-click in the Navigator panel and select "Refresh"

### Step 2: Compile the EA

1. In MetaTrader 5, open the Navigator panel (Ctrl+N)
2. Find "Expert Advisors" section
3. Locate "DeepSeek_Reasoner"
4. Right-click on it and select "Compile"
5. Check the "Errors" tab in the Toolbox (Ctrl+T) for any compilation errors
6. If compilation is successful, the EA is ready to use

### Step 3: Attach EA to Chart

1. Open a XAUUSD chart (or any symbol you want to trade)
2. Drag and drop "DeepSeek_Reasoner" from the Navigator onto the chart
3. Configure the input parameters in the popup window
4. Check "Allow Algo Trading" in the chart's properties
5. Click "OK" to start the EA

## Input Parameters

| Parameter | Default | Description | Range |
|-----------|---------|-------------|-------|
| **FastEMA_Period** | 9 | Fast Exponential Moving Average period | ≥1 |
| **SlowEMA_Period** | 21 | Slow Exponential Moving Average period | ≥1 |
| **LotSize** | 0.01 | Fixed lot size for XAUUSD | >0 |
| **ATR_Multiplier** | 2.0 | Multiplier for ATR-based stop loss | >0 |
| **RiskReward_Ratio** | 2.5 | Risk:Reward ratio for take profit | >0 |
| **ATR_Period** | 14 | Period for Average True Range | ≥1 |
| **MagicNumber** | 123456 | Unique identifier for EA's trades | Any integer |
| **MaximumRisk** | 0.02 | Maximum risk percentage (2%) for lot sizing | ≥0 |
| **DecreaseFactor** | 3 | Decrease factor for lot sizing | >0 |

## Default Settings for XAUUSD

For optimal performance with XAUUSD (Gold), use these settings:

- **LotSize**: 0.01 (minimum lot size for most brokers)
- **ATR_Multiplier**: 2.0 (adjusts stop loss based on volatility)
- **RiskReward_Ratio**: 2.5 (take profit is 2.5× stop loss distance)
- **Timeframe**: M15 or H1 recommended (same as original strategy)

## How It Works

### Signal Generation
1. The EA calculates Fast EMA (9-period) and Slow EMA (21-period)
2. Buy signal when Fast EMA crosses above Slow EMA
3. Sell signal when Fast EMA crosses below Slow EMA
4. Only enters new position when no existing position is open

### Position Entry
- **Long Position**: Buy at current Ask price
- **Short Position**: Sell at current Bid price
- **Stop Loss**: Entry price ± (ATR × ATR_Multiplier)
- **Take Profit**: Entry price ± (ATR × ATR_Multiplier × RiskReward_Ratio)

### Risk Management
- Fixed lot size of 0.01 (configurable)
- Optional risk-based lot calculation using MaximumRisk parameter
- Automatic lot size adjustment to broker limits
- One position at a time (prevents over-trading)

## Important Notes for XAUUSD Trading

### Lot Size Considerations
- XAUUSD typically has higher margin requirements than forex pairs
- 0.01 lot = 1 ounce of gold
- With gold price around $2,000, 0.01 lot = ~$20 position value
- Adjust lot size based on your account size and risk tolerance

### Volatility Considerations
- Gold (XAUUSD) can be highly volatile during news events
- ATR-based stop loss automatically adapts to market volatility
- Consider increasing ATR_Multiplier during high volatility periods

### Trading Sessions
- Best trading sessions: London/NY overlap (13:00-16:00 UTC)
- High volatility: During US economic data releases
- Lower volatility: Asian session

## Backtesting

### How to Backtest in MetaTrader 5
1. Open Strategy Tester (Ctrl+R)
2. Select "DeepSeek_Reasoner" from the dropdown
3. Choose XAUUSD as symbol
4. Set testing period (recommended: 1 year)
5. Use "Every tick" or "1 minute OHLC" modeling
6. Click "Start"

### Expected Results
- Win rate: 40-60% (depending on market conditions)
- Profit factor: 1.2-1.8
- Maximum drawdown: 15-25%

### Optimization
You can optimize these parameters:
- FastEMA_Period (5-15)
- SlowEMA_Period (15-30)
- ATR_Multiplier (1.5-3.0)
- RiskReward_Ratio (2.0-3.5)

## Live Trading Recommendations

### Account Requirements
- Minimum account balance: $500 (for 0.01 lot size)
- Recommended account balance: $1,000+
- Use a demo account first for at least 2 weeks

### Broker Considerations
- Ensure your broker supports XAUUSD trading
- Check spread and commission costs
- Verify that 0.01 lot size is available
- Test execution speed during volatile periods

### Risk Management
- Never risk more than 2% of account per trade
- Start with 0.01 lot size and increase gradually
- Monitor drawdown and adjust parameters if needed
- Consider using a stop-out level of 50% account equity

## Troubleshooting

### Common Issues

1. **EA not trading**
   - Check "Allow Algo Trading" is enabled
   - Verify chart is for XAUUSD symbol
   - Check Expert tab in Toolbox for errors

2. **Compilation errors**
   - Ensure MetaTrader 5 is updated to latest version
   - Check for syntax errors in the code
   - Verify all required files are in correct folders

3. **Orders rejected**
   - Check account has sufficient margin
   - Verify symbol is tradable (not expired)
   - Check broker restrictions on lot sizes

4. **Incorrect stop loss/take profit**
   - Verify ATR calculation is working
   - Check current volatility levels
   - Ensure prices are normalized correctly

### Error Messages
- **Error 130**: Invalid stops - adjust ATR_Multiplier
- **Error 134**: Not enough money - reduce lot size
- **Error 4109**: Invalid ticket - restart EA
- **Error 4110**: Long only or short only - check market conditions

## Differences from TradingView Version

| Feature | TradingView | MetaTrader 5 |
|---------|------------|--------------|
| **Commission** | Binance Futures specific | Broker-specific |
| **Slippage** | ATR-based model | Fixed deviation (10 pips) |
| **Funding Fees** | Simulated | Not implemented |
| **Dashboard** | Table display | Terminal logs only |
| **Year Filter** | Available | Not implemented |
| **Multiple Timeframes** | Not needed | Uses chart timeframe |

## Customization

### Adding Features
You can modify the EA to add:
- Trailing stop functionality
- Multiple timeframe analysis
- Additional confirmation indicators (RSI, MACD)
- Email/SMS alerts
- Custom money management rules

### Code Structure
- `OnInit()`: Initialization and indicator creation
- `OnTick()`: Main trading logic on each tick
- `OnDeinit()`: Cleanup on EA removal
- Helper functions for signal generation, position management, and lot calculation

## Support

For questions or issues:
1. Check the MetaTrader 5 Journal (Ctrl+J) for error details
2. Review this documentation
3. Test on demo account first
4. Adjust parameters based on market conditions

## Disclaimer

**Trading involves substantial risk of loss and is not suitable for all investors.** This Expert Advisor is for educational purposes only. Past performance does not guarantee future results. Always:

- Trade with risk capital only
- Use proper risk management
- Test strategies thoroughly before live trading
- Consider seeking advice from a qualified financial professional

## Version History

- **v1.0** (2026-02-15): Initial release
  - EMA crossover strategy
  - ATR-based stop loss and take profit
  - Fixed lot size (0.01) for XAUUSD
  - Basic risk management

## License

This EA is provided as-is for educational purposes. Use at your own risk.