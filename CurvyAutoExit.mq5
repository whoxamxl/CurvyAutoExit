//+------------------------------------------------------------------+
//|                                                CurvyAutoExit.mq5 |
//|                                                       Yuta Miura |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Yuta Miura"
#property link      "https://www.mql5.com"
#property version   "1.00"

//-INCLUDES-//

#include <errordescription.mqh>
#include <PositionManagerv3.mqh>
#include <Orders.mqh>

//-INPUT PARAMETERS-//
input bool UseTrailingStop = false;
input bool BreakEvenCommission = true;                               //Consider Commission when breakeven
input int ExitTimeOut= 150;                                           //Position timeout in miniutes

//-CONSTANTS-//

//-GLOBAL VARIABLES-//
MqlTick tick;
MqlRates rates;

PositionManager positionManager;
Orders orders;

//Tick data
double Ask, Bid;
double High[];
double Low[];
double Open[];
double Close[];

//-NATIVE MT5 EXPERT ADVISOR RUNNING FUNCTIONS-//

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
//---
   //If the initial pre checks have something wrong, stop the program
   if(!checkPreChecks()) {
      OnDeinit(INIT_FAILED);
      return(INIT_FAILED);
   }

   //Function to initialize the values of the global variables
   initializeVariables();

   // Set the timer to trigger every 1 second (1000 milliseconds)
   EventSetTimer(1);
//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---
   EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   updateSymbolInfo();

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTimer() {
   positionManager.UpdatePositions();
   evaluateExit();
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade() {
//---

}

//-CUSTOM EA FUNCTIONS-//

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool checkPreChecks() {
   //Check if Live Trading is enabled in terminal settings
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      Alert("Error: Automated trading is not allowed in the terminal settings");
      return false;
   }
   //Check if Live Trading is enabled in program settings
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      Alert("Error: Automated trading is not allowed in the program settings");
      return false;
   }
   //Confirm that the account has sufficient rights for trading
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) {
      Print("Error: Trading is not allowed on the account.");
      return false;
   }
   //Verify that the terminal is connected to the market
   if(!TerminalInfoInteger(TERMINAL_CONNECTED)) {
      Print("Error: Terminal is not connected to the market.");
      return false;
   }
   //Check ExitTimeOut
   if(ExitTimeOut < 0) {
      Print("Error: ExitTimeOut should be non-negative");
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void initializeVariables() {
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(Open, true);
   ArraySetAsSeries(Close, true);

   if(SymbolInfoTick(_Symbol, tick)) {
      Ask = tick.ask;
      Bid = tick.bid;
   }
   CopyHigh(_Symbol, _Period, 0, Bars(_Symbol, _Period), High);
   CopyLow(_Symbol, _Period, 0, Bars(_Symbol, _Period), Low);
   CopyOpen(_Symbol, _Period, 0, Bars(_Symbol, _Period), Open);
   CopyClose(_Symbol, _Period, 0, Bars(_Symbol, _Period), Close);
}

void updateSymbolInfo() {

   if(SymbolInfoTick(_Symbol, tick)) {
      Ask = tick.ask;
      Bid = tick.bid;
   }

   static int lastBarCount = 0;
   int currentBarCount = Bars(_Symbol, _Period);

   // Update historical data only when a new bar is added
   if(currentBarCount != lastBarCount) {
      CopyHigh(_Symbol, _Period, 0, Bars(_Symbol, _Period), High);
      CopyLow(_Symbol, _Period, 0, Bars(_Symbol, _Period), Low);
      CopyOpen(_Symbol, _Period, 0, Bars(_Symbol, _Period), Open);
      CopyClose(_Symbol, _Period, 0, Bars(_Symbol, _Period), Close);
      lastBarCount = currentBarCount;
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void evaluateExit() {


   if(PositionsTotal() != 0) {
      for(int i=0; i<PositionsTotal(); i++) {
         ulong ticket = PositionGetTicket(i);
         if(PositionGetSymbol(i) == _Symbol) {
            handleExit(ticket);
         }
      }
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleExit(ulong ticket) {

   if (!positionManager.contains(ticket)) {
      Print("Error: Position state not found for ticket: ", ticket);
      return;
   }

   PositionState* state = positionManager.getPosition(ticket);

   if (!isValidState(state)) {
      Print("Invalid state for ticket: ", ticket);
      return;
   }

   // Process trailing stop if enabled
   processTrailingStop(state, ticket);

   // Additional exit conditions
   evaluateBreakEven(state, ticket);
   evaluateProfitTarget(state, ticket);
   evaluateTimeBasedExit(state, ticket);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isValidState(PositionState* state) {
   if (state.StopLoss() <= 0.0) return false; // Check if stop loss is set
   if (state.Volume() <= 0) return false;    // Check if volume is valid
   if(!(state.TakeProfit() <= 0.0)) {
      if (MathAbs(state.TakeProfit() - state.PriceOpen()) < state.getR()) return false;
      if (state.getStopLossAtBreakEven() && MathAbs(state.TakeProfit() - state.PriceOpen()) < (1.5 * state.getR())) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void processTrailingStop(PositionState* state, ulong ticket) {
   //If Trailing stop enabled and price has moved by 1.5R
   if(UseTrailingStop && state.getStopLossAtBreakEven() && state.getPriceDifference() >= 1.5*state.getR()) {
      double newStopLoss = state.PriceCurrent() - 0.5 * ((state.PositionType() == POSITION_TYPE_BUY) ? state.getR() : -(state.getR()));
      if ((state.PositionType() == POSITION_TYPE_BUY && newStopLoss > state.StopLoss()) ||
            (state.PositionType() == POSITION_TYPE_SELL && newStopLoss < state.StopLoss())) {
         if(orders.modifyTrade(ticket, 0, newStopLoss, state.TakeProfit())) {
            positionManager.updateStopLossAtOneR(ticket);
            Print("Position modified due to Trailing Stop (" + state.getOrderTypeName() + ")");
         } else {
            Print("Position modify failed due to Trailing Stop (" + state.getOrderTypeName() + ")");
            return;
         }
      }

   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void evaluateBreakEven(PositionState* state, ulong ticket) {
   //If price has moved by 1R and SL is not yet at breakeven
   if(state.getPriceDifference() >= state.getR() && !state.getStopLossAtBreakEven()) {
      if(orders.modifyTrade(ticket, 0, BreakEvenCommission ? adjustStopLossForCommission(state, ticket) : state.PriceOpen(), state.TakeProfit())) {
         positionManager.updateStopLossAtBreakEven(ticket);
         Print("Position modified due to 1R (" + state.getOrderTypeName() + ")");
      } else {
         Print("Position modify failed due to 1R (" + state.getOrderTypeName() + ")");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void evaluateProfitTarget(PositionState* state, ulong ticket) {
   //If SL is at breakeven and price has moved by 1.5R
   if(!UseTrailingStop && state.getStopLossAtBreakEven() && !state.getStopLossAtOneR() && state.getPriceDifference() >= 1.5*state.getR()) {
      double newStopLoss = state.PriceOpen() + ((state.PositionType() == POSITION_TYPE_BUY) ? state.getR() : -(state.getR()));
      if(orders.modifyTrade(ticket, 0, newStopLoss, state.TakeProfit())) {
         positionManager.updateStopLossAtOneR(ticket);
         Print("Position modified due to 1.5R (" + state.getOrderTypeName() + ")");
      } else {
         Print("Position modify failed due to 1.5R (" + state.getOrderTypeName() + ")");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void evaluateTimeBasedExit(PositionState* state, ulong ticket) {
   //If order hasn't reached 1R in 1 hour, close it
   if((TimeCurrent() - state.Time()) >= (ExitTimeOut * 60) && state.getPriceDifference() < state.getR()) {
      if(orders.terminateTrade(ticket)) {
         //positionManager.DeletePosition(ticket);
         Print("Position closed due to timeout (" + state.getOrderTypeName() + ")");
      } else {
         Print("Position close failed due to timeout (" + state.getOrderTypeName() + ")");
         return;
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double adjustStopLossForCommission(PositionState* state, ulong ticket) {

   double commissionForTrade = state.Commission();

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double pointsToCoverCommission = commissionForTrade / (tickValue * state.Volume());


   // Calculate the adjusted stop loss
   double adjustedStopLoss;


   if(state.PositionType() == POSITION_TYPE_BUY) {
      adjustedStopLoss = state.PriceOpen() + pointsToCoverCommission * _Point;
   } else { // POSITION_TYPE_SELL
      adjustedStopLoss = state.PriceOpen() - pointsToCoverCommission * _Point;
   }

   return adjustedStopLoss;
}

//+------------------------------------------------------------------+
