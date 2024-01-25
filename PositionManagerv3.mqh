//+------------------------------------------------------------------+
//|                                            PositionManagerv3.mqh |
//|                                                       Yuta Miura |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Yuta Miura"
#property link      "https://www.mql5.com"

#include <Trade\PositionInfo.mqh>
#include <Generic\HashMap.mqh>
#include <Arrays\ArrayLong.mqh>

class PositionState : public CPositionInfo {
private:
   ulong ticketId;
   bool stopLossAtBreakEven;
   bool stopLossAtOneR;
   double R;
   double currentPrice;
   double priceDifference;
   string orderTypeName;

public:
   PositionState(ulong ticket) {
      this.ticketId = ticket;
      this.stopLossAtBreakEven = false;
      this.stopLossAtOneR = false;
      if(SelectByTicket(ticket)) {
         this.R = MathAbs(PriceOpen() - StopLoss());
         this.orderTypeName = (PositionType() == POSITION_TYPE_BUY) ? "BUY" : "SELL";

      }

   }

   void updatePriceInfo(double ask, double bid) {
      currentPrice = (PositionType() == POSITION_TYPE_BUY) ? bid : ask;
      priceDifference = (PositionType() == POSITION_TYPE_BUY) ?
                        (currentPrice - PriceOpen()) :
                        (PriceOpen() - currentPrice);
   }

   double getCurrentPrice() {
      return currentPrice;
   }

   double getPriceDifference() {
      return priceDifference;
   }

   string getOrderTypeName() {
      return orderTypeName;
   }

   ulong getTicketId() {
      return ticketId;
   }

   bool getStopLossAtBreakEven() {
      return stopLossAtBreakEven;
   }

   bool getStopLossAtOneR() {
      return stopLossAtOneR;
   }

   double getR() {
      return R;
   }

   void setStopLossAtBreakEven() {
      stopLossAtBreakEven = true;
   }

   void setStopLossAtOneR() {
      stopLossAtOneR = true;
   }
};

class PositionManager {

private:
   CHashMap<ulong, PositionState*> positionsMap;

public:

   // Call this method on every tick
   void UpdatePositions() {
      // Temporary container to hold currently active tickets
      CArrayLong activeTickets;
      activeTickets.Clear();
      CArrayLong ticketsToDelete;
      ticketsToDelete.Clear();

      // Iterate over all positions
      for(int i = 0; i < PositionsTotal(); i++) {
         ulong ticket = PositionGetTicket(i);
         if(!contains(ticket)) {
            // If the position is new, create a PositionState for it
            addPosition(ticket);
         }
         // Add the ticket to the active tickets list
         activeTickets.Add(ticket);
      }

      ulong keys[];
      PositionState* values[];
      positionsMap.CopyTo(keys, values);

      // Check for closed positions and delete their PositionStates
      for(int i = 0; i < positionsMap.Count(); i++) {
         ulong ticket = keys[i];
         if(activeTickets.Search(ticket) < 0) {
            // If the ticket is not in the active tickets list, add it to the deletion list
            ticketsToDelete.Add(ticket);
         }

      }
      // Delete positions that are no longer active
      for(int i = 0; i < ticketsToDelete.Total(); i++) {
         deletePosition(ticketsToDelete.At(i));
      }
   }

   // Method to add a new position
   void addPosition(ulong ticket) {
      if (!positionsMap.ContainsKey(ticket)) {
         PositionState* newState = new PositionState(ticket); // Assuming the PositionState constructor takes a ticket
         positionsMap.Add(ticket, newState);
      }
   }

   // Method to delete a position state
   void deletePosition(ulong ticket) {
      PositionState* state;
      if (positionsMap.TryGetValue(ticket, state) && state != NULL) {
         delete state;  // Free memory
         positionsMap.Remove(ticket);
      }
   }

   // Method to check if a position exists
   bool contains(ulong ticket) {
      return positionsMap.ContainsKey(ticket);
   }

   // Method to get a position state
   PositionState* getPosition(ulong ticket) {
      PositionState* state;
      positionsMap.TryGetValue(ticket, state);
      return state;
   }

   // Method to update StopLossAtBreakEven for a position
   void updateStopLossAtBreakEven(ulong ticket) {
      PositionState* state;
      if (positionsMap.TryGetValue(ticket, state) && state != NULL) {
         state.setStopLossAtBreakEven(); // Using pointer access operator
      }
   }

   // Method to update StopLossAtOneR for a position
   void updateStopLossAtOneR(ulong ticket) {
      PositionState* state;
      if (positionsMap.TryGetValue(ticket, state) && state != NULL) {
         state.setStopLossAtOneR(); // Using pointer access operator
      }
   }

};

//+------------------------------------------------------------------+

