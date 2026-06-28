//+------------------------------------------------------------------+
//|                                         SmartCushionEA.mq5        |
//|  Estrategia nueva (reemplaza por completo a la grilla/escalon):  |
//|  - Abre operaciones de forma continua (Buy Stop + Sell Stop      |
//|    siempre cerca del precio, lote fijo, SIN escalar)             |
//|  - Cada posicion tiene su propio Take Profit lejano, su propio   |
//|    Trailing Stop y su propio Breakeven (independientes)          |
//|  - "Colchon" de ganancia acumulada y CERRADA (persistente en     |
//|    archivo, sobrevive a reinicios del EA/terminal): si una       |
//|    posicion esta en flotante negativo y el colchon acumulado     |
//|    alcanza para cubrir esa perdida, se cierra esa posicion para  |
//|    asegurar que el resultado neto siga siendo positivo            |
//|                                                                    |
//|  New strategy (fully replaces the old grid/scaling one):         |
//|  - Opens trades continuously (Buy Stop + Sell Stop always near   |
//|    price, fixed lot, NO scaling)                                  |
//|  - Each position has its own far Take Profit, its own Trailing    |
//|    Stop and its own Breakeven (all independent per position)      |
//|  - Persistent "cushion" of accumulated CLOSED profit (saved to    |
//|    file, survives EA/terminal restarts): if an open position is   |
//|    floating negative and the cushion covers that loss, it closes  |
//|    that position to keep the net result positive                 |
//+------------------------------------------------------------------+
#property copyright "Custom EA"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//----------------------- PARAMETROS GENERALES | GENERAL -----------------------
input double Lot                = 0.01;  // Lote fijo, NO escala | Fixed lot, NO scaling
input double LevelDistance      = 1.0;   // Distancia Buy/Sell Stop al precio | Distance from price
input int    RefreshSeconds     = 30;    // Cada cuanto se refresca el par pendiente | Pending pair refresh interval (sec)
input int    MagicNumber        = 778911;// Numero magico del EA | EA magic number
input int    SlippagePoints     = 20;    // Slippage permitido | Allowed slippage (points)
input string TradeComment       = "SmartCushionEA"; // Comentario | Comment

//----------------------- TAKE PROFIT -----------------------
input double TakeProfitMoney    = 10.0;  // TP lejano en USC por posicion | Far TP in account currency (cents) per position

//----------------------- BREAKEVEN (siempre activo) | BREAKEVEN (always on) -----------------------
input double BreakevenStart     = 30;    // Puntos de ganancia para activar BE | Profit (points) to trigger BE
input double BreakevenOffset    = 5;     // Puntos extra sobre la entrada | Extra points above/below entry

//----------------------- TRAILING STOP (siempre activo) | TRAILING (always on) -----------------------
input double TrailingStart      = 60;    // Puntos de ganancia para activar trailing | Profit (points) to start trailing
input double TrailingDistance   = 40;    // Distancia del trailing al precio | Trailing distance (points)
input double TrailingStep       = 5;     // Paso minimo para mover el SL | Minimum step to move SL (points)

//----------------------- COLCHON DE GANANCIA | PROFIT CUSHION -----------------------
input string CushionFileName    = "SmartCushionEA_cushion.txt"; // Archivo donde se guarda el colchon | File where cushion is saved

//----------------------- VARIABLES GLOBALES | GLOBALS -----------------------
double accumulatedClosedProfit = 0.0; // Colchon acumulado (ganancia real ya cerrada) | Accumulated closed profit (cushion)
ulong  lastProcessedDealTicket = 0;   // Ultimo deal ya contabilizado | Last deal already counted
datetime lastRefreshTime = 0;

//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(SlippagePoints);

   LoadCushion();

   MaintainPendingOrders();
   lastRefreshTime = TimeCurrent();

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   // 1) Actualizar el colchon con cualquier operacion que se haya cerrado (TP, trailing, BE, o cierre manual del EA)
   UpdateCushionFromHistory();

   // 2) Aplicar breakeven y trailing a todas las posiciones abiertas del EA
   ManagePositions();

   // 3) Revisar perdidas flotantes que el colchon ya puede cubrir, y cerrarlas
   CloseCoveredLosses();

   // 4) Mantener siempre un par Buy Stop / Sell Stop pendiente cerca del precio (apertura continua)
   if(TimeCurrent() - lastRefreshTime >= RefreshSeconds)
     {
      MaintainPendingOrders();
      lastRefreshTime = TimeCurrent();
     }
  }

//+------------------------------------------------------------------+
//| Asegura que siempre haya 1 Buy Stop y 1 Sell Stop pendientes      |
//| cerca del precio actual. Si ya existen, los reubica si el precio  |
//| se alejo demasiado. No toca las posiciones ya abiertas.           |
//+------------------------------------------------------------------+
void MaintainPendingOrders()
  {
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double stopsLevelPoints = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevelPoints * point;

   bool hasBuyStop = false, hasSellStop = false;
   ulong buyTicket = 0, sellTicket = 0;

   for(int i = 0; i < OrdersTotal(); i++)
     {
      ulong ticket = OrderGetTicket(i);
      if(ticket <= 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

      long type = OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP)  { hasBuyStop = true;  buyTicket = ticket; }
      if(type == ORDER_TYPE_SELL_STOP) { hasSellStop = true; sellTicket = ticket; }
     }

   double buyPrice  = NormalizeDouble(ask + LevelDistance, digits);
   double sellPrice = NormalizeDouble(bid - LevelDistance, digits);

   if(buyPrice - ask < minStopDistance)  buyPrice = ask + minStopDistance;
   if(bid - sellPrice < minStopDistance) sellPrice = bid - minStopDistance;

   double tpBuy  = PriceForMoneyTarget(buyPrice, true);
   double tpSell = PriceForMoneyTarget(sellPrice, false);

   if(!hasBuyStop)
     {
      if(!trade.BuyStop(Lot, buyPrice, _Symbol, 0, tpBuy, ORDER_TIME_GTC, 0, TradeComment + "_B"))
         Print("Error BuyStop: ", trade.ResultRetcodeDescription());
     }
   else
     {
      // Reubicar si se alejo mucho del precio actual (mas de 2x la distancia configurada)
      if(OrderSelect(buyTicket))
        {
         double currentPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         if(MathAbs(currentPrice - buyPrice) > LevelDistance * 2)
            trade.OrderModify(buyTicket, buyPrice, 0, tpBuy, ORDER_TIME_GTC, 0);
        }
     }

   if(!hasSellStop)
     {
      if(!trade.SellStop(Lot, sellPrice, _Symbol, 0, tpSell, ORDER_TIME_GTC, 0, TradeComment + "_S"))
         Print("Error SellStop: ", trade.ResultRetcodeDescription());
     }
   else
     {
      if(OrderSelect(sellTicket))
        {
         double currentPrice = OrderGetDouble(ORDER_PRICE_OPEN);
         if(MathAbs(currentPrice - sellPrice) > LevelDistance * 2)
            trade.OrderModify(sellTicket, sellPrice, 0, tpSell, ORDER_TIME_GTC, 0);
        }
     }
  }

//+------------------------------------------------------------------+
//| Calcula el precio de TP para alcanzar TakeProfitMoney             |
//+------------------------------------------------------------------+
double PriceForMoneyTarget(double entryPrice, bool isBuy)
  {
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(tickValue <= 0 || tickSize <= 0) return 0;

   double moneyPerTick = tickValue * Lot;
   double ticksNeeded = TakeProfitMoney / moneyPerTick;
   double priceDistance = ticksNeeded * tickSize;

   double tp = isBuy ? entryPrice + priceDistance : entryPrice - priceDistance;
   return NormalizeDouble(tp, digits);
  }

//+------------------------------------------------------------------+
//| Breakeven + Trailing, por posicion, siempre activos               |
//+------------------------------------------------------------------+
void ManagePositions()
  {
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double currentTP = PositionGetDouble(POSITION_TP);
      double newSL = currentSL;
      bool modify = false;

      if(type == POSITION_TYPE_BUY)
        {
         double profitPoints = (bid - openPrice) / point;

         // Breakeven
         double beLevel = NormalizeDouble(openPrice + BreakevenOffset * point, digits);
         if(profitPoints >= BreakevenStart && (currentSL == 0 || currentSL < beLevel))
           { newSL = beLevel; modify = true; }

         // Trailing (solo si ya supera el nivel de breakeven, para no pisarlo con algo peor)
         if(profitPoints >= TrailingStart)
           {
            double trailLevel = NormalizeDouble(bid - TrailingDistance * point, digits);
            if(trailLevel > newSL && (newSL == 0 || trailLevel - newSL >= TrailingStep * point))
              { newSL = trailLevel; modify = true; }
           }

         if(modify)
           {
            if(!trade.PositionModify(ticket, newSL, currentTP))
               Print("Error modificando BUY ticket ", ticket, ": ", trade.ResultRetcodeDescription());
           }
        }
      else if(type == POSITION_TYPE_SELL)
        {
         double profitPoints = (openPrice - ask) / point;

         double beLevel = NormalizeDouble(openPrice - BreakevenOffset * point, digits);
         if(profitPoints >= BreakevenStart && (currentSL == 0 || currentSL > beLevel))
           { newSL = beLevel; modify = true; }

         if(profitPoints >= TrailingStart)
           {
            double trailLevel = NormalizeDouble(ask + TrailingDistance * point, digits);
            if((newSL == 0 || trailLevel < newSL) && (currentSL == 0 || currentSL - trailLevel >= TrailingStep * point))
              { newSL = trailLevel; modify = true; }
           }

         if(modify)
           {
            if(!trade.PositionModify(ticket, newSL, currentTP))
               Print("Error modificando SELL ticket ", ticket, ": ", trade.ResultRetcodeDescription());
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Cierra posiciones en flotante negativo que el colchon ya cubre    |
//+------------------------------------------------------------------+
void CloseCoveredLosses()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(profit < 0)
        {
         double loss = MathAbs(profit);
         if(accumulatedClosedProfit > loss)
           {
            Print("Cerrando posicion en perdida cubierta por el colchon. Perdida: ", loss,
                  " | Colchon disponible: ", accumulatedClosedProfit);
            trade.PositionClose(ticket);
            // El colchon se actualiza solo en el siguiente UpdateCushionFromHistory()
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Recorre el historial de deals nuevos del EA y suma su profit al   |
//| colchon acumulado, guardando el resultado en archivo              |
//+------------------------------------------------------------------+
void UpdateCushionFromHistory()
  {
   datetime fromDate = 0; // traer todo el historial disponible; se filtra por ticket ya procesado
   if(!HistorySelect(fromDate, TimeCurrent())) return;

   int total = HistoryDealsTotal();
   bool changed = false;

   for(int i = 0; i < total; i++)
     {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket <= lastProcessedDealTicket) continue; // ya contabilizado

      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue; // solo cierres

      double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                         + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
                         + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

      accumulatedClosedProfit += dealProfit;
      if(dealTicket > lastProcessedDealTicket)
         lastProcessedDealTicket = dealTicket;
      changed = true;
     }

   if(changed)
     {
      SaveCushion();
      Print("Colchon actualizado. Total acumulado: ", accumulatedClosedProfit);
     }
  }

//+------------------------------------------------------------------+
//| Guarda el colchon y el ultimo deal procesado en archivo           |
//+------------------------------------------------------------------+
void SaveCushion()
  {
   int handle = FileOpen(CushionFileName, FILE_WRITE | FILE_TXT | FILE_COMMON);
   if(handle == INVALID_HANDLE)
     {
      handle = FileOpen(CushionFileName, FILE_WRITE | FILE_TXT);
      if(handle == INVALID_HANDLE) { Print("Error guardando colchon: ", GetLastError()); return; }
     }
   FileWrite(handle, DoubleToString(accumulatedClosedProfit, 2));
   FileWrite(handle, IntegerToString((long)lastProcessedDealTicket));
   FileClose(handle);
  }

//+------------------------------------------------------------------+
//| Carga el colchon guardado, si existe                              |
//+------------------------------------------------------------------+
void LoadCushion()
  {
   int handle = FileOpen(CushionFileName, FILE_READ | FILE_TXT | FILE_COMMON);
   if(handle == INVALID_HANDLE)
      handle = FileOpen(CushionFileName, FILE_READ | FILE_TXT);

   if(handle == INVALID_HANDLE)
     {
      accumulatedClosedProfit = 0.0;
      lastProcessedDealTicket = 0;
      Print("No se encontro archivo de colchon previo. Arrancando en 0.");
      return;
     }

   if(!FileIsEnding(handle))
      accumulatedClosedProfit = StringToDouble(FileReadString(handle));
   if(!FileIsEnding(handle))
      lastProcessedDealTicket = (ulong)StringToInteger(FileReadString(handle));

   FileClose(handle);
   Print("Colchon cargado: ", accumulatedClosedProfit, " | Ultimo deal procesado: ", lastProcessedDealTicket);
  }
//+------------------------------------------------------------------+
