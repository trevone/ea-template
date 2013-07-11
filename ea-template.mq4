#property copyright "Trevor Schuil"
#property link "EA Template"
#define MAGIC 20130711
extern string TOOLS = ".............................................................................................................";
extern bool CloseAll = false;
extern bool ContinueTrading = true;
extern string TRADING = ".............................................................................................................";
extern int QueryHistory = 12; 
extern double BasketProfit = 3;
extern double OpenProfit = 1.3;
extern double TradeSpace = 1.1; 
extern double Aggressive = 8;
extern double DynamicSlippage = 1;  
extern string RISK = ".............................................................................................................";
extern int MaxTrades = 13;
extern double BaseLotSize = 0.01;
extern double RangeUsage = 0.15;
extern double TrendUsage = 0.08;
extern string INDICATOR_ATR = ".............................................................................................................";
extern int ATRTimeFrame = 0;
extern int ATRPeriod = 14;
extern int ATRShift = 0; 
extern string INDICATOR_ADX = ".............................................................................................................";
extern double ADXMain = 40;
extern int ADXTimeFrame = 0;
extern int ADXPeriod = 22;
extern int ADXShift = 0; 

double slippage, marginRequirement, lotSize, totalHistoryProfit, totalProfit, totalLoss, symbolHistory,
eATR, eADXMain, eADXPlusDi, eADXMinusDi;

int digits, totalTrades;

int totalHistory = 100;
double pipPoints = 0.00010;  
bool nearLongPosition = false;
bool nearShortPosition = false; 
double drawdown = 0; 
bool rangingMarket = false;
bool bullish = false;
bool bearish = false;
string display = "\n"; 

int init(){ 
   prepare() ; 
   return( 0 );
}

double marginCalculate( string symbol, double volume ){ 
   return ( MarketInfo( symbol, MODE_MARGINREQUIRED ) * volume ) ; 
} 

void lotSize(){ 
   slippage = NormalizeDouble( ( eATR / pipPoints ) * DynamicSlippage, 1 );
   marginRequirement = marginCalculate( Symbol(), BaseLotSize );  
   drawdown = 1 - AccountEquity() / AccountBalance();
   if( rangingMarket ) lotSize = NormalizeDouble( ( AccountFreeMargin() * RangeUsage / marginRequirement ) * BaseLotSize , 2 ) ;
   else lotSize = NormalizeDouble( ( AccountFreeMargin() * TrendUsage / marginRequirement ) * BaseLotSize, 2 ) ; 
   if( lotSize < 0.01 ) lotSize = 0.01; 
} 

void setPipPoint(){
   digits = MarketInfo( Symbol(), MODE_DIGITS );
   if( digits == 3 ) pipPoints = 0.010;
   else if( digits == 5 ) pipPoints = 0.00010;
} 

void closeAll( string type = "none" ){
   for( int i = 0; i < OrdersTotal(); i++ ) {
   if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) break;
      if( OrderSymbol() == Symbol() ){ 
         RefreshRates();
         if( ( OrderStopLoss() == 0 && OrderProfit() > 0 && type == "profits" ) || type == "none" ){
            if( OrderType() == OP_BUY ) OrderClose( OrderTicket(), OrderLots(), Bid, slippage );
            if( OrderType() == OP_SELL ) OrderClose( OrderTicket(), OrderLots(), Ask, slippage );
         }
      }
   }
} 

void update(){
   display = "";
   display = display + " Trade Space: " + DoubleToStr( TradeSpace * eATR / pipPoints, 1 ) + "pips";  
   display = display + " Lot Size: " + DoubleToStr( lotSize, 2 );  
   display = display + " Draw Down: " + DoubleToStr( drawdown, 2 );
   display = display + " Open Trades: " + DoubleToStr( totalTrades, 0 ) + " (" + DoubleToStr( MaxTrades, 0 ) + ")";  
   display = display + " Profit: " + DoubleToStr( totalProfit, 2 );
   display = display + " Loss: " + DoubleToStr( totalLoss, 2 );
   display = display + " History: " + DoubleToStr( totalHistoryProfit, 2 ); 
   display = display + " Ranging: " + DoubleToStr( rangingMarket, 0 ); 
   display = display + " Bullish: " + DoubleToStr( bullish, 0 ) ;
   display = display + " Bearish: " + DoubleToStr( bearish, 0 ); 
   Comment( display );
}

void prepareHistory(){
   symbolHistory = 0;
   totalHistoryProfit = 0;
   for( int iPos = OrdersHistoryTotal() - 1 ; iPos > ( OrdersHistoryTotal() - 1 ) - totalHistory; iPos-- ){
      OrderSelect( iPos, SELECT_BY_POS, MODE_HISTORY ) ;
      double QueryHistoryDouble = ( double ) QueryHistory;
      if( symbolHistory >= QueryHistoryDouble ) break;
      if( OrderSymbol() == Symbol() ){
         totalHistoryProfit = totalHistoryProfit + OrderProfit() ;
         symbolHistory = symbolHistory + 1 ;
      }
   }
}

void prepareTrend(){
   if( eADXMain < ADXMain ) {
      rangingMarket = true;
      bullish = false;
      bearish = false;
   } else {
      rangingMarket = false;
      if( eADXPlusDi > eADXMinusDi ){
         bullish = true;
         bearish = false;
      } else if( eADXMinusDi > eADXPlusDi ){
         bullish = false;
         bearish = true;
      }
   }
}

void preparePositions() {
   nearLongPosition = false;
   nearShortPosition = false;
   totalTrades = 0;
   totalProfit = 0;
   totalLoss = 0;
   for( int i = 0 ; i < OrdersTotal() ; i++ ) {
      if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) break; 
      if(OrderSymbol() == Symbol()){totalTrades = totalTrades + 1;}
      if( OrderSymbol() == Symbol() && OrderStopLoss() == 0 ) {
         if( rangingMarket && eADXMain < ADXMain ){
            if( OrderType() == OP_BUY && MathAbs( OrderOpenPrice() - Ask ) < eATR * TradeSpace ) nearLongPosition = true ;
            if( OrderType() == OP_SELL && MathAbs( OrderOpenPrice() - Bid ) < eATR * TradeSpace ) nearShortPosition = true ;
         } else {
            if( OrderType() == OP_BUY && MathAbs( OrderOpenPrice() - Ask ) < eATR * TradeSpace / Aggressive ) nearLongPosition = true ;
            if( OrderType() == OP_SELL && MathAbs( OrderOpenPrice() - Bid ) < eATR * TradeSpace / Aggressive ) nearShortPosition = true ;
         }
         if( OrderProfit() > 0 ) totalProfit = totalProfit + OrderProfit();
         else totalLoss = totalLoss + OrderProfit(); 
      }
   }
} 

void prepareIndicators(){
   eATR = iATR( NULL, ATRTimeFrame, ATRPeriod, ATRShift ); 
   eADXMain = iADX( NULL, ADXTimeFrame, ADXPeriod, PRICE_MEDIAN, MODE_MAIN, ADXShift ); 
   eADXPlusDi = iADX( NULL, ADXTimeFrame, ADXPeriod, PRICE_MEDIAN, MODE_PLUSDI, ADXShift );  
   eADXMinusDi = iADX( NULL, ADXTimeFrame, ADXPeriod, PRICE_MEDIAN, MODE_MINUSDI, ADXShift );    
} 

void prepare(){ 
   prepareIndicators();
   prepareTrend();
   setPipPoint(); 
   prepareHistory();
   preparePositions(); 
   lotSize();   
   update() ;
} 

void openPosition(){ 
   if( !nearLongPosition && bullish ) OrderSend( Symbol(), OP_BUY , lotSize, Ask, slippage, 0, 0, "scalp", MAGIC ) ;
   else if( !nearShortPosition && bearish ) OrderSend( Symbol(), OP_SELL, lotSize, Bid, slippage, 0, 0, "scalp", MAGIC ) ;  
} 

void managePositions(){
   if( ( totalHistoryProfit < 0 || totalTrades == 1 ) && MathAbs( totalHistoryProfit ) < totalProfit * BasketProfit  ) closeAll( "profits" );
   else if( totalTrades > 1 && totalProfit > MathAbs( totalLoss ) * OpenProfit ) closeAll();
   else { 
      for( int i = 0 ; i < OrdersTotal() ; i++ ) {
         if( OrderSelect( i, SELECT_BY_POS, MODE_TRADES ) == false ) break;  
      }
   }
} 

int start() { 
   prepare() ;  
   if( CloseAll ) closeAll() ;
   else {
      if( ( ContinueTrading || ( !ContinueTrading && totalTrades > 0 ) ) && ( totalTrades < MaxTrades || MaxTrades == 0 ) ) openPosition() ; 
      managePositions() ;
   }
   return( 0 ) ;
}