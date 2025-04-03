#property copyright "Kishor"
#property link      ""
#property version   "3.0"
#property strict

// Input parameters
input double LotSize = 0.1;          // Trade lot size
input int MagicNumber = 123456;      // EA's magic number
input int MaPeriod1 = 9;             // Fast MA period
input int MaPeriod2 = 21;            // Slow MA period
input int RsiPeriod = 14;            // RSI period
input int SlPips = 50;               // Stop loss in pips
input int TpPips = 100;              // Take profit in pips
input bool UseTrailingStop = true;   // Enable trailing stop
input int TrailingStopPips = 30;     // Trailing stop distance
input int MaxSpread = 3;             // Maximum allowed spread
input string TradeTimeStart = "09:00"; // Trading start time
input string TradeTimeEnd = "17:00";   // Trading end time

// Global variables
datetime lastTradeTime;
double ma1, ma2, rsi;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize indicators
   SetIndexStyle(0,DRAW_LINE,STYLE_SOLID,2,"MA1");
   SetIndexStyle(1,DRAW_LINE,STYLE_DASH,3,"MA2");
   
   // Initialize last trade time
   lastTradeTime = D'30 Jan 2000';
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check trading time
   if(!IsTradeTime()) return;
   
   // Check spread
   if(MarketInfo(Symbol(), MODE_SPREAD) > MaxSpread * 10) return;
   
   // Get indicator values
   ma1 = iMA(NULL, 0, MaPeriod1, 0, MODE_SMA, PRICE_CLOSE, 0);
   ma2 = iMA(NULL, 0, MaPeriod2, 0, MODE_SMA, PRICE_CLOSE, 0);
   rsi = iRSI(NULL, 0, RsiPeriod, PRICE_CLOSE, 0);
   
   // Check minimum bars
   if(Bars <= MaPeriod2) return;
   
   // Check for new bar
   if(Time[0] == lastTradeTime) return;
   
   // Check open positions
   if(OrdersTotal() > 0) {
      ManageOpenPositions();
      return;
   }
   
   // Check entry conditions
   if(ma1 > ma2 && rsi < 30) {
      OpenTrade(OP_BUY);
   }
   else if(ma1 < ma2 && rsi > 70) {
      OpenTrade(OP_SELL);
   }
   
   lastTradeTime = Time[0];
}

//+------------------------------------------------------------------+
//| Trade management function                                        |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   for(int i = OrdersTotal()-1; i >= 0; i--) {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if(OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) {
            if(UseTrailingStop) {
               TrailingStop(OrderTicket());
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Open trade function                                              |
//+------------------------------------------------------------------+
void OpenTrade(int cmd)
{
   double price = (cmd == OP_BUY) ? Ask : Bid;
   double sl = (cmd == OP_BUY) ? price - SlPips * Point : price + SlPips * Point;
   double tp = (cmd == OP_BUY) ? price + TpPips * Point : price - TpPips * Point;
   
   int ticket = OrderSend(Symbol(), cmd, LotSize, price, 3, sl, tp, "MansamusaV3", MagicNumber, 0, clrNONE);
   
   if(ticket < 0) {
      Print("OrderSend failed with error #", GetLastError());
   }
}

//+------------------------------------------------------------------+
//| Trailing stop function                                           |
//+------------------------------------------------------------------+
void TrailingStop(int ticket)
{
   if(OrderSelect(ticket, SELECT_BY_TICKET)) {
      double newSl = 0;
      if(OrderType() == OP_BUY) {
         newSl = Bid - TrailingStopPips * Point;
         if(newSl > OrderStopLoss() || OrderStopLoss() == 0) {
            OrderModify(ticket, OrderOpenPrice(), newSl, OrderTakeProfit(), 0, clrNONE);
         }
      }
      else if(OrderType() == OP_SELL) {
         newSl = Ask + TrailingStopPips * Point;
         if(newSl < OrderStopLoss() || OrderStopLoss() == 0) {
            OrderModify(ticket, OrderOpenPrice(), newSl, OrderTakeProfit(), 0, clrNONE);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check trading time function                                      |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   datetime start = StrToTime(TradeTimeStart);
   datetime end = StrToTime(TradeTimeEnd);
   datetime now = TimeCurrent();
   
   if(start < end) {
      return (now >= start && now < end);
   }
   else {
      return (now >= start || now < end);
   }
}