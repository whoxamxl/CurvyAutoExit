//+------------------------------------------------------------------+
//|                                                       Orders.mqh |
//|                                                       Yuta Miura |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Yuta Miura"
#property link      "https://www.mql5.com"

#include <Trade\Trade.mqh>
#include "errordescription.mqh"
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>

class Orders {
private:
   CTrade trade;
   COrderInfo orderInfo;
   CPositionInfo positionInfo;
   string OrderNote;
   
public:
   Orders() {
      OrderNote = "";
   }
   ulong executeTrade(ENUM_ORDER_TYPE cmd, double volume, double entryPrice = 0, double stopLoss = 0, double takeProfit = 0, datetime Expiration=0, double stopLimit=0) {
      if(cmd == ORDER_TYPE_BUY || cmd == ORDER_TYPE_SELL) {
         entryPrice = cmd == ORDER_TYPE_BUY ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      bool res = false;
      ulong ticket = -1;

      switch(cmd) {
      case ORDER_TYPE_BUY:
      case ORDER_TYPE_SELL:
         res = trade.PositionOpen(_Symbol, cmd, volume, NormalizeDouble(entryPrice, _Digits), NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits), OrderNote);
         break;

      case ORDER_TYPE_BUY_LIMIT:
      case ORDER_TYPE_SELL_LIMIT:
      case ORDER_TYPE_BUY_STOP:
      case ORDER_TYPE_SELL_STOP:
      case ORDER_TYPE_BUY_STOP_LIMIT:
      case ORDER_TYPE_SELL_STOP_LIMIT:
         res = trade.OrderOpen(_Symbol, cmd, volume, NormalizeDouble(stopLimit, _Digits), NormalizeDouble(entryPrice, _Digits), NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits), ORDER_TIME_GTC, Expiration, OrderNote);
         break; // Exit the function early if the order type is invalid

      default:
         Print("Invalid order type provided.");
         return ticket;
      }

      ticket = (cmd == ORDER_TYPE_BUY || cmd == ORDER_TYPE_SELL) ? trade.ResultDeal() : trade.ResultOrder();

      if(res) {
         Print("TRADE - OPEN SUCCESS - Order " + IntegerToString(ticket) + " submitted: Command " + trade.RequestTypeDescription() + " Volume " + DoubleToString(trade.RequestVolume()) + " Open " + DoubleToString(trade.RequestPrice()) + " Stop " + DoubleToString(trade.RequestSL()) + " Take " + DoubleToString(trade.RequestTP()) + " StopLimit " + DoubleToString(trade.RequestStopLimit()) + " Expiration " + trade.RequestTypeTimeDescription());
      } else {
         Print("TRADE - OPEN FAILED - Order " + IntegerToString(ticket) + " submitted: Command " + trade.RequestTypeDescription() + " Volume " + DoubleToString(trade.RequestVolume()) + " Open " + DoubleToString(trade.RequestPrice()) + " Stop " + DoubleToString(trade.RequestSL()) + " Take " + DoubleToString(trade.RequestTP()) + " StopLimit " + DoubleToString(trade.RequestStopLimit()) + " Expiration " + trade.RequestTypeTimeDescription());
         int error = GetLastError();
         Print("ERROR - NEW - error sending order, return error: ", error, " - ", ErrorDescription(error));
         ticket = -1; // Set the ticket to -1 indicating a failed operation
      }
      return ticket;
   }

   bool modifyTrade(ulong ticket, double entryPrice = 0, double stopLoss = 0, double takeProfit = 0, datetime Expiration=0, double stopLimit=0) {
      bool res = false;
      if (orderInfo.Select(ticket)) { //If it's a pending order
         if (orderInfo.StopLoss() != NormalizeDouble(stopLoss, _Digits) || orderInfo.TakeProfit() != NormalizeDouble(takeProfit, _Digits) || orderInfo.PriceStopLimit() != NormalizeDouble(stopLimit, _Digits)) { //Check if there is a chnage in price
            if (trade.OrderModify(ticket, NormalizeDouble(entryPrice, _Digits), NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits), ORDER_TIME_GTC, Expiration, NormalizeDouble(stopLimit, _Digits))) {
               Print("TRADE - UPDATE ORDER SUCCESS - Order " + IntegerToString(ticket) + " new stop loss " + DoubleToString(stopLoss) +" new take profit " + DoubleToString(takeProfit));
               res = true;
            } else {
               int error = GetLastError();
               Print("ERROR - UPDATE ORDER FAILED - error modifying order " + IntegerToString(ticket) + " return error: " + IntegerToString(error) + ". Open " + DoubleToString(orderInfo.PriceOpen()) + " Old SL " + DoubleToString(orderInfo.StopLoss()) + " Old TP " + DoubleToString(orderInfo.TakeProfit()) + " New SL " + DoubleToString(stopLoss) + " New TP " + DoubleToString(takeProfit));
               Print("ERROR - ", ErrorDescription(error));
            }
         } else {
            Print("ERROR - No change in Price for ModifyTrade: ", ticket);
            return res;
         }
      } else if (positionInfo.SelectByTicket(ticket)) { //If it's an open position
         if (positionInfo.StopLoss() != NormalizeDouble(stopLoss, _Digits) || positionInfo.TakeProfit() != NormalizeDouble(takeProfit, _Digits)) { //Check if there is a chnage in price
            if (trade.PositionModify(ticket, NormalizeDouble(stopLoss, _Digits), NormalizeDouble(takeProfit, _Digits))) {
               Print("TRADE - UPDATE POSITION SUCCESS - Position " + IntegerToString(ticket) + " new stop loss " + DoubleToString(stopLoss) + " new take profit " + DoubleToString(takeProfit));
               res = true;
            } else {
               int error = GetLastError();
               Print("ERROR - UPDATE POSITION FAILED - error modifying order " + IntegerToString(ticket) + " return error: " + IntegerToString(error) + ". Open " + DoubleToString(positionInfo.PriceOpen()) + " Old SL " + DoubleToString(positionInfo.StopLoss()) + " Old TP " + DoubleToString(positionInfo.TakeProfit()) + " New SL " + DoubleToString(stopLoss) + " New TP " + DoubleToString(takeProfit));
               Print("ERROR - ", ErrorDescription(error));
            }
         } else {
            Print("ERROR - No change in Price for ModifyTrade: ", ticket);
            return res;
         }
      } else { //Check if the order is still valid
         Print("ERROR - Invalid ticket for ModifyTrade: ", ticket);
      }

      return res;
   }

   bool terminateTrade(ulong ticket) {
      bool res = false;
      if (orderInfo.Select(ticket)) { // If it's a pending order
         if (trade.OrderDelete(ticket)) {
            Print("TRADE - DELETE ORDER SUCCESS - Order " + IntegerToString(ticket) + " has been deleted.");
            res = true;
         } else {
            int error = GetLastError();
            Print("ERROR - DELETE ORDER FAILED - error deleting order " + IntegerToString(ticket) + ". Error: " + IntegerToString(error));
            Print("ERROR - ", ErrorDescription(error));
         }
      } else if (positionInfo.SelectByTicket(ticket)) { // If it's an open position
         if (trade.PositionClose(ticket)) {
            Print("TRADE - CLOSE POSITION SUCCESS - Position " + IntegerToString(ticket) + " has been closed.");
            res = true;
         } else {
            int error = GetLastError();
            Print("ERROR - CLOSE POSITION FAILED - error closing position " + IntegerToString(ticket) + ". Error: " + IntegerToString(error));
            Print("ERROR - ", ErrorDescription(error));
         }
      } else { // Check if the order or position is still valid
         Print("ERROR - Invalid ticket for CloseTrade: ", ticket);
      }

      return res;
   }

   
};

//+------------------------------------------------------------------+
