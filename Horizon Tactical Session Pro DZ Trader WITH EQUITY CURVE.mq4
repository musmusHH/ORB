//+------------------------------------------------------------------+
//| Horizon Tactical Session Pro DZ Trader WITH EQUITY CURVE.mq4                               |
//| MULTI-THEME + CUSTOM COLORS  WITH EQUITY CURVE   |
//| Original author credits preserved                                |
//+------------------------------------------------------------------+
#property copyright "AIT CHIKH MUSTAPHA"
#property link      "https://www.mql5.com"
#property version   "2.00"
#property strict

//===============================================================
// EMBEDDED UI ASSETS (compiled into the EA - no external files)
// Generated to match the HORIZON TACTICAL mockup exactly.
//===============================================================
#resource "HorizonAssets\\logo_card.bmp"
// Clocks and equity curve are now rendered LIVE at runtime (ResourceCreate)
// from real session times and actual trade history - see HTP_* functions.
//===============================================================
// AUTO DST CORE FOR EXNESS / LONDON + NEW YORK ORB
// Server model: FIXED GMT+0 ALL YEAR
// Keeps: London only / New York only / Both sessions
//===============================================================

#ifndef __AUTO_DST_EXNESS_CORE_MQH__
#define __AUTO_DST_EXNESS_CORE_MQH__

enum ENUM_SESSION_ID
{
   SESSION_ID_LONDON   = 0,
   SESSION_ID_NEWYORK  = 1
};

input string Inp_AutoDST = "=== AUTO DST / BROKER CLOCK ===";
input bool   UseAutoSessionDST         = true; // Always ON by default for automatic London/New York DST switching
input int    Broker_Winter_GMT_Offset  = 0;    // Exness fixed GMT+0 server in winter
input int    Broker_Summer_GMT_Offset  = 0;    // Exness fixed GMT+0 server in summer

struct AutoSessionBrokerTimes
{
   datetime day_stamp;
   bool     uk_dst;
   bool     us_dst;
   int      london_open_server_min;
   int      london_orb_end_server_min;
   int      london_close_server_min;
   int      ny_open_server_min;
   int      ny_orb_end_server_min;
   int      ny_close_server_min;
   string   london_open_text;
   string   ny_open_text;
};

AutoSessionBrokerTimes g_auto_session_times;

bool AutoDST_SameServerDate(datetime a, datetime b)
{
   MqlDateTime da, db;
   TimeToStruct(a, da);
   TimeToStruct(b, db);
   return (da.year == db.year && da.mon == db.mon && da.day == db.day);
}

int AutoDST_DayOfWeekForDate(int year,int month,int day)
{
   MqlDateTime dt;
   ZeroMemory(dt);
   dt.year = year;
   dt.mon  = month;
   dt.day  = day;
   return TimeDayOfWeek(StructToTime(dt));
}

int AutoDST_NthWeekdayOfMonth(int year,int month,int weekday,int nth)
{
   int firstDow = AutoDST_DayOfWeekForDate(year, month, 1);
   int firstWanted = 1 + ((7 + weekday - firstDow) % 7);
   return firstWanted + (nth - 1) * 7;
}

int AutoDST_LastWeekdayOfMonth(int year,int month,int weekday)
{
   int daysInMonth = 31;
   if(month==4 || month==6 || month==9 || month==11) daysInMonth = 30;
   if(month==2)
   {
      bool leap = ((year%4==0 && year%100!=0) || (year%400==0));
      daysInMonth = leap ? 29 : 28;
   }

   int lastDow = AutoDST_DayOfWeekForDate(year, month, daysInMonth);
   return daysInMonth - ((7 + lastDow - weekday) % 7);
}

//===============================================================
// EXACT DST CHECKERS FOR EXNESS FIXED GMT+0 SERVER
//===============================================================

// UK DST (BST)
// Starts: last Sunday in March at 01:00 UTC
// Ends  : last Sunday in October at 01:00 UTC
bool IsUK_DST(datetime time)
{
   MqlDateTime dt, start_dt, end_dt;
   TimeToStruct(time, dt);
   ZeroMemory(start_dt);
   ZeroMemory(end_dt);

   int year = dt.year;

   start_dt.year = year;
   start_dt.mon  = 3;
   start_dt.day  = AutoDST_LastWeekdayOfMonth(year, 3, 0);
   start_dt.hour = 1;
   start_dt.min  = 0;
   start_dt.sec  = 0;

   end_dt.year = year;
   end_dt.mon  = 10;
   end_dt.day  = AutoDST_LastWeekdayOfMonth(year, 10, 0);
   end_dt.hour = 1;
   end_dt.min  = 0;
   end_dt.sec  = 0;

   datetime dst_start = StructToTime(start_dt);
   datetime dst_end   = StructToTime(end_dt);

   return (time >= dst_start && time < dst_end);
}

// US DST (New York)
// Starts: second Sunday in March at 07:00 UTC
// Ends  : first Sunday in November at 06:00 UTC
bool IsUS_DST(datetime time)
{
   MqlDateTime dt, start_dt, end_dt;
   TimeToStruct(time, dt);
   ZeroMemory(start_dt);
   ZeroMemory(end_dt);

   int year = dt.year;

   start_dt.year = year;
   start_dt.mon  = 3;
   start_dt.day  = AutoDST_NthWeekdayOfMonth(year, 3, 0, 2);
   start_dt.hour = 7;
   start_dt.min  = 0;
   start_dt.sec  = 0;

   end_dt.year = year;
   end_dt.mon  = 11;
   end_dt.day  = AutoDST_NthWeekdayOfMonth(year, 11, 0, 1);
   end_dt.hour = 6;
   end_dt.min  = 0;
   end_dt.sec  = 0;

   datetime dst_start = StructToTime(start_dt);
   datetime dst_end   = StructToTime(end_dt);

   return (time >= dst_start && time < dst_end);
}

// Backward-compatible wrappers used by existing code sections
bool AutoDST_IsEuropeDST_Local(datetime localTime)
{
   return IsUK_DST(localTime);
}

bool AutoDST_IsUSDST_UTC(datetime utcTime)
{
   return IsUS_DST(utcTime);
}

int AutoDST_NormalizeMinutes(int mins)
{
   while(mins < 0) mins += 1440;
   while(mins >= 1440) mins -= 1440;
   return mins;
}

string AutoDST_MinutesToText(int mins)
{
   mins = AutoDST_NormalizeMinutes(mins);
   return StringFormat("%02d:%02d", mins / 60, mins % 60);
}

int AutoDST_GetSessionCloseSpanMinutes(ENUM_SESSION_ID sessionId)
{
   if(sessionId == SESSION_ID_NEWYORK)
      return (NY_End_Hour * 60) - (NY_Start_Hour * 60 + NY_Start_Minute);

   return (Lon_End_Hour * 60) - (Lon_Start_Hour * 60 + Lon_Start_Minute);
}

void AutoDST_CalcSessionServerSchedule(datetime serverTime,
                                       ENUM_SESSION_ID sessionId,
                                       int &startServer,
                                       int &orbEndServer,
                                       int &closeServer)
{
   if(UseAutoSessionDST)
   {
      if(sessionId == SESSION_ID_LONDON)
         startServer = IsUK_DST(serverTime) ? (8 * 60) : (8 * 60);
      else
         startServer = IsUS_DST(serverTime) ? (13 * 60 + 30) : (14 * 60 + 30);

      int orbDuration = (sessionId == SESSION_ID_NEWYORK) ? NY_Duration_Min : Lon_Duration_Min;
      int closeSpan   = AutoDST_GetSessionCloseSpanMinutes(sessionId);

      orbEndServer = AutoDST_NormalizeMinutes(startServer + orbDuration);
      closeServer  = AutoDST_NormalizeMinutes(startServer + closeSpan);
      return;
   }

   int startLocal = (sessionId == SESSION_ID_NEWYORK)
                  ? (NY_Start_Hour * 60 + NY_Start_Minute)
                  : (Lon_Start_Hour * 60 + Lon_Start_Minute);

   int orbDuration = (sessionId == SESSION_ID_NEWYORK) ? NY_Duration_Min : Lon_Duration_Min;
   int closeLocal  = (sessionId == SESSION_ID_NEWYORK) ? (NY_End_Hour * 60) : (Lon_End_Hour * 60);
   int brokerOffset = Broker_Winter_GMT_Offset;
   int sessionOffset = (sessionId == SESSION_ID_NEWYORK) ? NY_GMT_Offset : Lon_GMT_Offset;

   startServer  = AutoDST_NormalizeMinutes(startLocal + (brokerOffset - sessionOffset) * 60);
   orbEndServer = AutoDST_NormalizeMinutes(startServer + orbDuration);
   closeServer  = AutoDST_NormalizeMinutes(closeLocal + (brokerOffset - sessionOffset) * 60);
}

void AutoDST_UpdateSessionTimes(datetime serverTime=0)
{
   if(serverTime == 0)
      serverTime = TimeCurrent();

   datetime dayStamp = serverTime - (serverTime % 86400);
   if(g_auto_session_times.day_stamp == dayStamp)
      return;

   g_auto_session_times.day_stamp = dayStamp;
   g_auto_session_times.uk_dst    = IsUK_DST(serverTime);
   g_auto_session_times.us_dst    = IsUS_DST(serverTime);

   AutoDST_CalcSessionServerSchedule(serverTime, SESSION_ID_LONDON,
                                     g_auto_session_times.london_open_server_min,
                                     g_auto_session_times.london_orb_end_server_min,
                                     g_auto_session_times.london_close_server_min);

   AutoDST_CalcSessionServerSchedule(serverTime, SESSION_ID_NEWYORK,
                                     g_auto_session_times.ny_open_server_min,
                                     g_auto_session_times.ny_orb_end_server_min,
                                     g_auto_session_times.ny_close_server_min);

   g_auto_session_times.london_open_text = AutoDST_MinutesToText(g_auto_session_times.london_open_server_min);
   g_auto_session_times.ny_open_text     = AutoDST_MinutesToText(g_auto_session_times.ny_open_server_min);
}

int AutoDST_GetServerMinutes(datetime serverTime)
{
   MqlDateTime dt;
   TimeToStruct(serverTime, dt);
   return dt.hour * 60 + dt.min;
}

int AutoDST_GetBrokerGMTOffsetHours(datetime serverTime)
{
   if(!UseAutoSessionDST)
      return Broker_Winter_GMT_Offset;

   // Exness broker server assumed fixed on GMT+0 all year for this EA build.
   return Broker_Winter_GMT_Offset;
}

datetime AutoDST_GetUTCFromServer(datetime serverTime)
{
   return serverTime - AutoDST_GetBrokerGMTOffsetHours(serverTime) * 3600;
}

int AutoDST_GetSessionGMTOffsetHours(datetime serverTime, ENUM_SESSION_ID sessionId)
{
   if(!UseAutoSessionDST)
   {
      if(sessionId == SESSION_ID_LONDON)  return Lon_GMT_Offset;
      if(sessionId == SESSION_ID_NEWYORK) return NY_GMT_Offset;
   }

   if(sessionId == SESSION_ID_LONDON)
      return IsUK_DST(serverTime) ? 1 : 0;

   return IsUS_DST(serverTime) ? -4 : -5;
}

datetime AutoDST_GetSessionLocalTime(datetime serverTime, ENUM_SESSION_ID sessionId)
{
   datetime utcTime = AutoDST_GetUTCFromServer(serverTime);
   int sessionOffset = AutoDST_GetSessionGMTOffsetHours(serverTime, sessionId);
   return utcTime + sessionOffset * 3600;
}

int AutoDST_GetSessionMinutes(datetime serverTime, ENUM_SESSION_ID sessionId)
{
   MqlDateTime dt;
   TimeToStruct(AutoDST_GetSessionLocalTime(serverTime, sessionId), dt);
   return dt.hour * 60 + dt.min;
}

int AutoDST_SessionLocalMinutesToServerMinutes(datetime serverTime, ENUM_SESSION_ID sessionId, int sessionLocalMinutes)
{
   int brokerOffset  = AutoDST_GetBrokerGMTOffsetHours(serverTime);
   int sessionOffset = AutoDST_GetSessionGMTOffsetHours(serverTime, sessionId);
   return AutoDST_NormalizeMinutes(sessionLocalMinutes + (brokerOffset - sessionOffset) * 60);
}

bool AutoDST_MinuteInWindow(int minuteValue, int startMinute, int endMinute)
{
   if(startMinute <= endMinute)
      return (minuteValue >= startMinute && minuteValue < endMinute);

   return (minuteValue >= startMinute || minuteValue < endMinute);
}

void AutoDST_GetFixedSessionConfig(ENUM_SESSION_ID sessionId,
                                   int &startHour,
                                   int &startMinute,
                                   int &durationMinutes,
                                   int &endHour)
{
   if(sessionId == SESSION_ID_NEWYORK)
   {
      startHour       = NY_Start_Hour;
      startMinute     = NY_Start_Minute;
      durationMinutes = NY_Duration_Min;
      endHour         = NY_End_Hour;
   }
   else
   {
      startHour       = Lon_Start_Hour;
      startMinute     = Lon_Start_Minute;
      durationMinutes = Lon_Duration_Min;
      endHour         = Lon_End_Hour;
   }
}

void AutoDST_GetSessionServerSchedule(datetime serverTime,
                                      ENUM_SESSION_ID sessionId,
                                      int &startServer,
                                      int &endServer,
                                      int &closeServer)
{
   AutoDST_UpdateSessionTimes(serverTime);

   if(AutoDST_SameServerDate(serverTime, g_auto_session_times.day_stamp))
   {
      if(sessionId == SESSION_ID_LONDON)
      {
         startServer = g_auto_session_times.london_open_server_min;
         endServer   = g_auto_session_times.london_orb_end_server_min;
         closeServer = g_auto_session_times.london_close_server_min;
      }
      else
      {
         startServer = g_auto_session_times.ny_open_server_min;
         endServer   = g_auto_session_times.ny_orb_end_server_min;
         closeServer = g_auto_session_times.ny_close_server_min;
      }
      return;
   }

   AutoDST_CalcSessionServerSchedule(serverTime, sessionId, startServer, endServer, closeServer);
}

ENUM_SESSION_ID AutoDST_GetDisplaySessionId(datetime serverTime, int mode)
{
   if(mode == MODE_NY_ONLY) return SESSION_ID_NEWYORK;
   if(mode == MODE_LONDON_ONLY) return SESSION_ID_LONDON;

   int nowServerMin = AutoDST_GetServerMinutes(serverTime);
   int lonStart, lonEnd, lonClose;
   int nyStart, nyEnd, nyClose;

   AutoDST_GetSessionServerSchedule(serverTime, SESSION_ID_LONDON,  lonStart, lonEnd, lonClose);
   AutoDST_GetSessionServerSchedule(serverTime, SESSION_ID_NEWYORK, nyStart,  nyEnd,  nyClose);

   if(nowServerMin < lonStart)
      return SESSION_ID_LONDON;

   if(nowServerMin < lonClose)
      return SESSION_ID_LONDON;

   if(nowServerMin < nyClose)
      return SESSION_ID_NEWYORK;

   return SESSION_ID_LONDON;
}

void AutoDST_GetModeSessionConfig(int mode,
                                  datetime serverTime,
                                  ENUM_SESSION_ID &sessionId,
                                  int &startHour,
                                  int &startMinute,
                                  int &durationMinutes,
                                  int &endHour)
{
   sessionId = AutoDST_GetDisplaySessionId(serverTime, mode);
   AutoDST_GetFixedSessionConfig(sessionId, startHour, startMinute, durationMinutes, endHour);
}

string AutoDST_GetSessionCountdownText(int mode)
{
   datetime nowServer = TimeCurrent();
   ENUM_SESSION_ID sessionId = AutoDST_GetDisplaySessionId(nowServer, mode);

   MqlDateTime nowDt;
   TimeToStruct(nowServer, nowDt);

   int nowServerMin  = nowDt.hour * 60 + nowDt.min;
   int currentSecond = nowDt.sec;
   int startServer=0, endServer=0, closeServer=0;
   AutoDST_GetSessionServerSchedule(nowServer, sessionId, startServer, endServer, closeServer);

   if(nowServerMin < startServer)
      return "START " + FormatClock((startServer - nowServerMin) * 60 - currentSecond);

   if(nowServerMin >= startServer && nowServerMin < endServer)
      return "ORB " + FormatClock((endServer - nowServerMin) * 60 - currentSecond);

   if(nowServerMin >= endServer && nowServerMin < closeServer)
      return "CLOSE " + FormatClock((closeServer - nowServerMin) * 60 - currentSecond);

   return "NEXT SESSION";
}

bool AutoDST_FindSessionORBRange(int startLocalMinute,
                                 int endLocalMinute,
                                 double &hi,
                                 double &lo,
                                 ENUM_SESSION_ID sessionId)
{
   hi = -1;
   lo = 999999;

   datetime nowServer = TimeCurrent();
   int nowServerMin = AutoDST_GetServerMinutes(nowServer);
   int startServerNow=0, endServerNow=0, closeServerNow=0;
   AutoDST_GetSessionServerSchedule(nowServer, sessionId, startServerNow, endServerNow, closeServerNow);

   if(nowServerMin < endServerNow)
      return false;

   // ------------------------------------------------------------------
   // EXACT 30-MINUTE WINDOW CALCULATION (timeframe-independent).
   // The opening range is defined strictly by TIME: every candle whose
   // open time falls inside [session open, session open + OrbDuration)
   // is aggregated. On an M5 chart that is ALL SIX 5-minute candles of a
   // 30-minute ORB - never just one. If the chart timeframe is coarser
   // than 5 minutes, M5 data is used so the range is still exact.
   // ------------------------------------------------------------------
   datetime dayBase     = nowServer - (nowServer % 86400);
   datetime windowStart = dayBase + startServerNow * 60;
   datetime windowEnd   = dayBase + endServerNow   * 60;   // exclusive
   if(windowEnd <= windowStart) windowEnd += 86400;        // midnight wrap safety

   int tf = (PeriodSeconds() <= 300) ? Period() : PERIOD_M5;

   int startShift = iBarShift(NULL, tf, windowStart, false);
   if(startShift < 0)
      return false;   // M5 history still loading - retry on a later tick

   bool found = false;
   for(int i = startShift; i >= 0; i--)
   {
      datetime bt = iTime(NULL, tf, i);
      if(bt < windowStart) continue;    // bar before the window (nearest-shift artifact)
      if(bt >= windowEnd)  break;       // window fully covered
      double bh = iHigh(NULL, tf, i);
      double bl = iLow(NULL, tf, i);
      if(bh > hi) hi = bh;
      if(bl < lo) lo = bl;
      found = true;
   }

   return (found && hi > 0 && lo < 999999);
}

void AutoDST_ProcessSessionTrading(int startLocalMinute,
                                   int durationMinutes,
                                   int endHour,
                                   int magic,
                                   double &cachedHi,
                                   double &cachedLo,
                                   datetime &lastSig,
                                   ENUM_SESSION_ID sessionId)
{
   datetime nowServer = TimeCurrent();
   int nowServerMin = AutoDST_GetServerMinutes(nowServer);
   int startServerMin=0, endServerMin=0, closeServerMin=0;
   AutoDST_GetSessionServerSchedule(nowServer, sessionId, startServerMin, endServerMin, closeServerMin);

   if(nowServerMin < endServerMin || nowServerMin >= closeServerMin)
      return;

   if(HasOpenTradeMagic(magic))
      return;

   if(Time[1] == lastSig)
      return;

   if(UseSpreadFilter)
   {
      int currentSpread = (int)MarketInfo(Symbol(), MODE_SPREAD);
      if(currentSpread > MaxSpreadFilter)
         return;
   }

   double hi, lo;
   if(AutoDST_FindSessionORBRange(startLocalMinute, startLocalMinute + durationMinutes, hi, lo, sessionId))
   {
      cachedHi = hi;
      cachedLo = lo;
   }

   if(cachedHi > 0 && cachedLo > 0)
   {
      int signal = CheckBreakoutSignal(cachedHi, cachedLo);
      if(signal != 0)
      {
         ExecuteTradeMagic(signal, cachedHi, cachedLo, magic);
         lastSig = Time[1];
      }
   }
}

void AutoDST_DrawSessionHistorical(int startHour,
                                   int startMinute,
                                   int durationMinutes,
                                   int endHour,
                                   ENUM_SESSION_ID sessionId,
                                   string prefix,
                                   color hiClr,
                                   color loClr,
                                   color orbFillClr)
{
   if(DrawHistoryDays <= 0) return;

   int barsCount   = iBars(NULL, 0);
   int daysCount   = 0;
   int currentBar  = 0;

   while(daysCount < DrawHistoryDays && currentBar < barsCount)
   {
      datetime baseTime = iTime(NULL, 0, currentBar);
      MqlDateTime d0;
      TimeToStruct(baseTime, d0);

      double hi = -1, lo = 999999;
      datetime sessStart = 0, sessEnd = 0;
      bool dayFound = false, orbFound = false;

      while(currentBar < barsCount)
      {
         datetime t = iTime(NULL, 0, currentBar);
         MqlDateTime dt;
         TimeToStruct(t, dt);

         if(dt.year != d0.year || dt.mon != d0.mon || dt.day != d0.day)
            break;

         int barServerMin=0, startServer=0, orbEndServer=0, sessEndServer=0;
         barServerMin = AutoDST_GetServerMinutes(t);
         AutoDST_CalcSessionServerSchedule(t, sessionId, startServer, orbEndServer, sessEndServer);

         if(AutoDST_MinuteInWindow(barServerMin, startServer, orbEndServer))
         {
            if(iHigh(NULL,0,currentBar) > hi) hi = iHigh(NULL,0,currentBar);
            if(iLow(NULL,0,currentBar)  < lo) lo = iLow(NULL,0,currentBar);
            orbFound = true;
         }

         if(AutoDST_MinuteInWindow(barServerMin, startServer, sessEndServer))
         {
            if(sessEnd == 0) sessEnd = t + PeriodSeconds();
            sessStart = t;
            dayFound = true;
         }

         currentBar++;
      }

      if(dayFound && orbFound && hi > 0 && lo < 999999)
      {
         string dateStr = StringFormat("%d%02d%02d", d0.year, d0.mon, d0.day);
         string bName = "ORB_Box_" + prefix + "_" + dateStr;

         if(ObjectFind(0, bName) < 0)
            ObjectCreate(0, bName, OBJ_RECTANGLE, 0, sessStart, hi, sessEnd, lo);
         else
         {
            ObjectSetInteger(0, bName, OBJPROP_TIME, 0, sessStart);
            ObjectSetDouble(0, bName, OBJPROP_PRICE, 0, hi);
            ObjectSetInteger(0, bName, OBJPROP_TIME, 1, sessEnd);
            ObjectSetDouble(0, bName, OBJPROP_PRICE, 1, lo);
         }

         ObjectSetInteger(0, bName, OBJPROP_COLOR, orbFillClr);
         ObjectSetInteger(0, bName, OBJPROP_FILL, UseOrbFill);
         ObjectSetInteger(0, bName, OBJPROP_BACK, true);
         ObjectSetInteger(0, bName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, bName, OBJPROP_HIDDEN, true);

         string hName = "ORB_Lv_H_" + prefix + "_" + dateStr;
         if(ObjectFind(0, hName) < 0)
            ObjectCreate(0, hName, OBJ_TREND, 0, sessStart, hi, sessEnd, hi);
         else
         {
            ObjectSetInteger(0, hName, OBJPROP_TIME, 0, sessStart);
            ObjectSetDouble(0, hName, OBJPROP_PRICE, 0, hi);
            ObjectSetInteger(0, hName, OBJPROP_TIME, 1, sessEnd);
            ObjectSetDouble(0, hName, OBJPROP_PRICE, 1, hi);
         }
         ObjectSetInteger(0, hName, OBJPROP_COLOR, hiClr);
         ObjectSetInteger(0, hName, OBJPROP_WIDTH, OrbLineWidth);
         ObjectSetInteger(0, hName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, hName, OBJPROP_BACK, true);

         string lName = "ORB_Lv_L_" + prefix + "_" + dateStr;
         if(ObjectFind(0, lName) < 0)
            ObjectCreate(0, lName, OBJ_TREND, 0, sessStart, lo, sessEnd, lo);
         else
         {
            ObjectSetInteger(0, lName, OBJPROP_TIME, 0, sessStart);
            ObjectSetDouble(0, lName, OBJPROP_PRICE, 0, lo);
            ObjectSetInteger(0, lName, OBJPROP_TIME, 1, sessEnd);
            ObjectSetDouble(0, lName, OBJPROP_PRICE, 1, lo);
         }
         ObjectSetInteger(0, lName, OBJPROP_COLOR, loClr);
         ObjectSetInteger(0, lName, OBJPROP_WIDTH, OrbLineWidth);
         ObjectSetInteger(0, lName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lName, OBJPROP_BACK, true);

         daysCount++;
      }

      if(currentBar < barsCount)
         currentBar++;
   }
}

#endif


//====================================================================
// PANEL THEME SELECTOR
//====================================================================
enum ENUM_PANEL_THEME
{
   THEME_DARK       = 0,  // Dark Classic
   THEME_LIGHT      = 1,  // Light Clean
   THEME_GOLD       = 2,  // Gold Luxury
   THEME_NEON       = 3,  // Neon Cyber
   THEME_MIDNIGHT   = 4,  // Midnight Navy
   THEME_MATRIX     = 5,  // Matrix Green
   THEME_CYBERPUNK  = 6,  // Cyberpunk Magenta/Cyan
   THEME_EMERALD    = 7,  // Emerald Mint
   THEME_ROYAL_RUBY = 8,  // Royal Ruby Wine
   THEME_SOLAR      = 9,  // Obsidian Solar Flare
   THEME_CUSTOM     = 10  // Custom Colors
};

//====================================================================
// INPUTS
//====================================================================
input string Inp_Theme = "=== PANEL THEME ===";
input ENUM_PANEL_THEME PanelTheme = THEME_DARK;  // Choose dashboard theme
input bool   ApplyChartColors = true;            // Recolor chart bg/candles/grid to match theme

input string Inp_CustomColors = "=== CUSTOM COLORS (used when Theme = Custom, or to override) ===";
input bool   OverrideColors      = false;        // Force these colors on ANY theme
input color  Cust_PanelBG        = C'12,12,20';  // Panel / card background
input color  Cust_Border         = C'30,30,45';  // Card border
input color  Cust_Accent         = C'0,255,200'; // Accent (top line, rings, meters)
input color  Cust_TitleText      = C'240,244,255'; // Header big title text
input color  Cust_TextPrimary    = C'240,244,255'; // Main values text
input color  Cust_TextSecondary  = C'140,148,170'; // Sub-labels text
input color  Cust_TextMuted       = C'70,75,95';   // Faint labels text
input color  Cust_Success        = C'0,230,130';  // Profit / positive text
input color  Cust_Danger         = C'255,60,80';  // Loss / negative text
input color  Cust_Warning        = C'255,180,0';  // Warning text
input color  Cust_Info           = C'0,190,255';  // Info text
input color  Cust_SaveBtnBG      = C'30,90,220';  // SAVE button background
input color  Cust_SaveBtnText    = C'255,255,255'; // SAVE button text
input color  Cust_OnAccentText   = C'255,255,255'; // Text on ON/OFF + accent buttons

input string Inp_Currency = "=== CURRENCY SETTINGS ===";
input bool   StartInDZD   = false;       // Start panel in DZD mode
input double USD_DZD_Rate = 250.0;       // USD to DZD Exchange Rate

input string Inp_Trade = "=== TRADE SETTINGS ===";
input double LotSize = 0.04;
input bool   UseRiskPercent = false;
input double RiskPercent = 1.0;
input int    Slippage = 30;          // points (30 pts = $0.30 on 2-digit XAUUSD)
input int    MagicNumber = 123459;
input bool   GlobalHistory = true;

input string Inp_RawSpread = "=== RAW SPREAD FILTER ===";
input bool   UseSpreadFilter = true;
input int    MaxSpreadFilter = 100;
input bool   ShowSpreadAlert = true;

input string Inp_TP = "=== TP/SL SETTINGS ===";
input bool   UseIndicatorSL = true;
input int    FixedSL_Points = 500;
input double TP1_RR = 1.2;
input double TP2_RR = 2.2;
input bool   UseTP1_PartialClose = true;
input bool   MoveToBreakeven = true;

input string Inp_Trailing = "=== TRAILING STOP ===";
input bool   UseTrailingStop = true;
input int    TrailingStart = 700;
input int    TrailingDist = 100;
input int    TrailingStep = 100;

input string Inp_MaxLoss = "=== MAX LOSS ===";
input bool   UseMaxLoss = true;
input double MaxLossUSD = 7.5;

input string Inp_Martingale = "=== MARTINGALE ===";
input bool   UseMartingale = false;
input double MartingaleAddLot = 0.05;
input int    MaxMartingaleLevel = 1;

input string Inp_ProfitCompd = "=== PROFIT COMPOUNDING ===";
input bool   EnableProfitCompd = true;
input double CompoundingStepProfit = 400.0;
input double CompoundingAddLot = 0.05;
input bool   ScaleProfitMaxLoss = true;

enum ENUM_ORB_SESSION_MODE
{
   MODE_LONDON_ONLY   = 0, // Trade London ORB Only
   MODE_NY_ONLY       = 1, // Trade New York ORB Only
   MODE_BOTH_SESSIONS = 2  // Trade BOTH London & New York ORB
};

input string Inp_SessionMode = "=== ORB SESSION TRADING SELECTION ===";
input ENUM_ORB_SESSION_MODE OrbTradeMode = MODE_BOTH_SESSIONS; // Select ORB session(s) to trade

input string Inp_TradingDays = "=== WEEKDAY TRADING ALLOWED ===";
input bool   Allow_Trading_Mon = true; // Monday Allowed
input bool   Allow_Trading_Tue = true; // Tuesday Allowed
input bool   Allow_Trading_Wed = true; // Wednesday Allowed
input bool   Allow_Trading_Thu = true; // Thursday Allowed
input bool   Allow_Trading_Fri = true; // Friday Allowed

input string Inp_LonSession = "=== LONDON ORB SETTINGS ===";
input int    Lon_GMT_Offset   = 1;
input int    Lon_Start_Hour   = 8;
input int    Lon_Start_Minute = 0;
input int    Lon_Duration_Min = 30;
input int    Lon_End_Hour     = 16;

input string Inp_NYSession  = "=== NEW YORK ORB SETTINGS ===";
input int    NY_GMT_Offset    = -4;
input int    NY_Start_Hour    = 9;  // 9:30
input int    NY_Start_Minute  = 30;
input int    NY_Duration_Min  = 30;
input int    NY_End_Hour      = 17;
input int    NY_MagicNumber   = 12346;

input string Inp_Filter = "=== FILTERS ===";
input bool   UseTrendFilter = false;
input int    MA_Period = 200;
input ENUM_MA_METHOD MA_Method = MODE_EMA;
input int    BreakoutPadding = 20;
input bool   UseADXFilter = false;
input int    ADX_Period = 14;
input int    ADX_Minimum = 20;
input double MinRangePoints = 500;
input double MaxRangePoints = 5000000;

input string Inp_News = "=== NEWS FILTER ===";
input bool   UseNewsFilter = true;
input int    MinsBeforeNews = 30;
input int    MinsAfterNews = 30;
input bool   News_HighImpact = true;
input bool   News_MedImpact = true;
input string News_Currency = "USD,EUR";

input string Inp_UI = "=== GLASSMORPHISM UI ===";
input bool   UseCreativeAuroraUI = true;
input string AuroraAssetFolder = "HorizonTactical_Navy_Assets\\MT4_BMP";
input bool   ShowModernPanel = true;
input int    UI_PosX = 0;
input int    UI_PosY = 0;
input bool   UI_StartCollapsed = false;
input double UI_Transparency = 0.85;
input color  Inp_NeonAccent = C'0,255,200'; // Neon accent for Dark theme
input bool   UI_ShowMeters = true;
input bool   UI_ShowHeaderInfo = true;
input bool   UI_ChartShift = true;
input double DailyTargetUSD = 50.0;
input int    UI_ShadowOffsetX = 3;
input int    UI_ShadowOffsetY = 4;

input string Inp_CandleCard      = "=== CANDLE & SESSION CARD (BOTTOM-RIGHT) ===";
input bool   ShowCandleCard      = true;               // Show Candle & Session Card
input int    CandleCard_PosX     = 15;                 // Distance from Right edge (px)
input int    CandleCard_PosY     = 25;                 // Distance from Bottom edge (px)
input bool   Card_UseThemeColors = true;               // Match Dashboard Theme (if false, use custom below)
input color  Card_CustomBG       = C'12,20,34';        // Custom Card Background
input color  Card_CustomBorder   = C'40,70,98';        // Custom Card Border
input color  Card_CustomAccent   = C'0,255,200';       // Custom Card Top Line & Meter Accent
input color  Card_CustomTitleClr = C'160,170,190';     // Custom Header Title Color
input color  Card_CustomValClr   = C'255,255,255';     // Custom Values Text Color
input color  Card_CustomSubClr   = C'90,100,120';      // Custom Sub-labels Color
input string Card_FontName       = "Segoe UI";         // Card Font Family Name
input int    Card_TitleFontSize  = 10;                  // Header Title Font Size
input int    Card_LabelFontSize  = 9;                  // Sub-labels Font Size
input int    Card_ValueFontSize  = 12;                 // Values Text Font Size

input string Inp_Chart = "=== CHART DRAWINGS ===";
input int    OrbLineWidth = 0;
input int    DrawHistoryDays = 360;
input color  C_OrbHi = clrDodgerBlue;
input color  C_OrbLo = clrOrangeRed;
input color  C_OrbFill_Lon = C'10,35,70'; // London ORB Fill (Deep Premium Ocean Blue)
input color  C_OrbFill_NY = C'55,15,45';  // NY ORB Fill (Deep Royal Velvet Purple)
input bool   UseOrbFill = true;
input bool ShowProfitTracker = true;

input string Inp_TradeBadges         = "=== TRADE RESULT CHARTS BADGES (BOX & LABELS) ===";
input bool   Badge_ShowBoxes         = true;                   // Show Glass Box behind Result
input bool   Badge_DrawBehindPanel   = true;                   // Draw Badges behind UI Panel (Background layer)
input color  Badge_BoxColor          = clrNONE;         // Glass Box Background Color
input int    Badge_BoxWidthBars      = 6;                      // Box Width (Candles count)
input int    Badge_BoxHalfHeightPips = 12;                     // Box Vertical Half-Height (standard pips/cents)
input int    Badge_FontSize          = 9;                     // Result Text Font Size
input string Badge_FontName          = "Segoe UI Black Bold";       // Result Text Font & Weight (Bold/Black)
input color  Badge_WinTextColor      = clrWhite;           // Winning Trade Text Color
input color  Badge_LossTextColor     = clrDarkOrange;           // Losing Trade Text Color
input color  Badge_WinLineColor      = C'0,230,130';           // Winning Top Neon Line Color
input color  Badge_LossLineColor     = C'255,60,80';           // Losing Top Neon Line Color

input string Inp_EquityCurve          = "=== EQUITY CURVE BOX (TOP-RIGHT CORNER) ===";
input bool   ShowEquityCurve          = true;                  // Show Equity Curve Box
input int    EQ_BoxWidth              = 300;                   // Box Width (pixels)
input int    EQ_BoxHeight             = 160;                   // Box Height (pixels)
input int    EQ_PosX                  = 15;                    // Distance from Right Edge
input int    EQ_PosY                  = 40;                    // Distance from Top
input color  EQ_BoxBG                 = clrWhite;              // Box Background Color
input color  EQ_BoxBorder             = C'180,190,210';        // Box Border Color
input color  EQ_CurveColor            = C'0,120,255';          // Equity Curve Line Color (Blue)
input color  EQ_DotColor              = C'0,180,100';          // Dot Color at Each Trade
input color  EQ_LossColor             = C'220,50,70';          // Loss Segment Color
input color  EQ_TitleColor            = C'30,40,60';           // Title Text Color
input color  EQ_SubTextColor          = C'100,110,130';        // Sub-text Color
input color  EQ_ZeroLineColor         = C'200,210,225';        // Zero/Start Line Color

//====================================================================
// COLORS / THEME (resolved at runtime)
//====================================================================
color C_Glass_BG=C'5,10,18'; color C_Glass_Panel=C'10,18,30'; color C_Glass_Border=C'40,70,98';
color C_Glass_Card=C'12,20,34'; color C_Glass_Accent=C'0,245,255'; color C_Glass_Accent2=C'0,120,255';
color C_Glass_Shadow=C'1,3,7'; color C_Glass_Highlight=C'90,180,220'; color C_Meter_BG=C'18,28,44';
color C_Text_Primary=C'255,255,255'; color C_Text_Secondary=C'160,170,190'; color C_Text_Muted=C'90,100,120';
color C_Success_Glow=C'0,255,150'; color C_Warning_Glow=C'255,190,0'; color C_Danger_Glow=C'255,80,90'; color C_Info_Glow=C'0,200,255';
color C_Tracker_Text=C'180,190,200'; color C_Tracker_Value=C'255,255,255'; color C_Tracker_Header=C'120,130,150';
color C_Tracker_Success=C'0,255,150'; color C_Tracker_Danger=C'255,80,90';
color C_BG_Dark=C'12,12,20'; color C_Card_Dark=C'18,18,30'; color C_Accent_Neon=C'0,255,200'; color C_Border_Soft=C'30,30,45';

// Theme-aware text colors for buttons/headers
color C_OnAccent_Text = C'255,255,255';
color C_Header_Title  = C'240,244,255';
color C_Save_BG   = C'30,90,220';
color C_Save_Text = C'255,255,255';

//====================================================================
// GLOBALS
//====================================================================
struct RepNode {
   datetime time;
   double   drawnPrice;
   int      barShift;
};
RepNode g_repNodes[];
int g_repNodesCount = 0;

ENUM_PANEL_THEME CurrentTheme = THEME_LIGHT;
int DASH_COL1_W=200, DASH_COL2_W=200, DASH_COL3_W=300, DASH_SPACING=8, DASH_TOTAL_H=680;
int totalHistory=0;
int Lon_MagicNumber = 12345;
datetime lastSignalLon=0, lastSignalNY=0;
double lonOrbHigh=0, lonOrbLow=0;
double nyOrbHigh=0, nyOrbLow=0;
bool EA_Enabled=true, UI_Collapsed=false, DisplayDZD=false;
bool g_uiPulse=false;
datetime g_lastSpreadAlert=0;
struct NewsEvent { datetime time; string title; string currency; int impact; };
NewsEvent g_news[]; int g_newsCount=0; datetime g_lastNewsDownload=0; string g_newsStatus="IDLE";
int lastHistoryCount=-1; datetime lastUIBar=0; int tickCounter=0;
double cachedGrossProfit=0,cachedGrossLoss=0,cachedNetProfit=0,cachedEANetProfit=0;
int cachedWins=0,cachedLosses=0,cachedLongs=0,cachedShorts=0;
double cachedAvgWin=0,cachedAvgLoss=0,cachedPF=0,cachedWinRate=0;
double cachedRF=0,cachedRatio=0,cachedDailyPL=0,cachedDailyPL_Lon=0,cachedDailyPL_NY=0,cachedDailyWon=0,cachedDailyLoss=0,cachedMaxDD=0;
int cachedDaysTraded=0;
double cachedBestTrade=0,cachedWorstTrade=0,cachedTotalPips=0,cachedExpectancy=0;
string ui_prefix="GLASS_ORB_"; string tracker_prefix="TRACK_"; string tracker_save_btn="TRACK_SaveBtn";
string eq_prefix="EQCURVE_";
double g_eqBalances[];
int    g_eqCount=0;

//====================================================================
// PROTOTYPES
//====================================================================
void CreatePremiumUI(); void UpdatePremiumUI(); void RefreshNewsData(); void CheckClosedTrades();
void DrawHistoricalORBLevels(); void DrawTradeResult(int ticket,double profit,double price,datetime time,int count=1);
void CreateProfitTrackerUI(); void UpdateProfitTrackerUI();
void CreateBottomCard(); void UpdateBottomCard();
string ThemeToString(ENUM_PANEL_THEME th);
void CreateBottomPanel(string id,int x,int y,int w,int h,color bg,color borderClr,color outerBg);
void CreateBottomLabel(string id,string text,int x,int y,int size,string font,color clr,int anchor=ANCHOR_LEFT_LOWER);
void CreateBottomMeter(string id,int xRight,int y,int meterW,int h);
void UpdateBottomMeter(string id,double percent,color fillColor,color bgClr);
void GetDayStats(datetime day,double &pips,double &profit,double &gain,double &lots);
void RemoveAllUI(); void RemoveTrackerUI(); void SaveTradeHistoryToHTML(); void RefreshStatsCache();
void BuildEquityData(); void DrawEquityCurveBox(); void CleanEquityCurve();
void CreatePremiumPanel(string id,int x,int y,int w,int h,color bg,color borderClr,color outerBg);
void CreateCardMeter(string id,int x,int y,int w,int h); void UpdateCardMeter(string id,double percent,color fillColor);
void CreatePremiumCard(string id,string title,int x,int y,int w,int h,color bgClr,bool showMeter=true);
void CreatePremiumRingCard(string id,string title,int x,int y,int w,int h,color bgClr);
void DrawCircularProgress(string id, int x, int y, double percent, color clr_neon, string clockText, string countdownText, color countdownClr, string profitText, color profitClr);
datetime GetNextSessionOpenTime(ENUM_SESSION_ID sessionId);
void UpdateCardValue(string id,string value,color clr); void UpdateLabel(string id,string text,color clr);
void CreateTrackerPanel(string id,int x,int y,int w,int h,color bg,int borderWidth);
void CreateTrackerGlowLine(string id,int x,int y,int w,color clr);
void CreateTrackerLabel(string id,string text,int x,int y,int size,string font,color clr,int anchor=ANCHOR_LEFT_UPPER);
void CreateStatBox(string id,string label,int x,int y,int w,int h); void UpdateStatBox(string id,string val,color clr);
void UpdateORBPricePointer(double price,double low,double high,int startX,int startY,int w);
bool FindSessionORBRange(int startM,int endM,double &hi,double &lo,int offset); int CheckBreakoutSignal(double orbHigh,double orbLow);
void ExecuteTradeMagic(int signal,double orbHigh,double orbLow,int magic); void ManageOpenTrades(); bool HasOpenTradeMagic(int magic);
int GetMinutesWithOffset(datetime time,int offset); void ProcessSessionTrading(int startM,int durM,int endHour,int magic,double &cachedHi,double &cachedLo,datetime &lastSig,int offset);
double CalculateLotSize(double slPoints); double GetMartingaleLot(); double GetPeriodProfit(int periodMode);
void GetDailyPLBreakdown(double &won,double &loss); double GetActiveProfit(); int GetDaysTraded();
void ParseMyfxbookHTML(string html); string ExtractTimeData(string rowData); int ExtractImpactData(string rowData);
string ExtractCurrencyData(string rowData); string StringBetween(string data,string start,string end);
datetime ParseMyfxTimestamp(string ts); bool IsNewsTime(); bool GetNextHighNews(datetime &newsTime,string &currency);
string TFToString(int tf); double ClampValue(double v,double vMin,double vMax); string FormatMoney(double v); string FormatMoneyAbs(double v);
string FormatClock(int totalSeconds); string GetSessionCountdownText(); double GetStatusProgressPercent(int lonMin);
int DayOfWeekForDate(int year,int month,int day); int NthSunday(int year,int month,int nth); bool IsEuroDST(datetime t);
datetime GetLondonTime(datetime time); int GetLondonMinutes(datetime time); string TrimString(string s); double CalcSelectedOrderPips();
void ApplyThemeChartColors(); string GetLocalClockText();

string ThemeToString(ENUM_PANEL_THEME th)
{
   if(th==THEME_DARK)       return "DARK";
   if(th==THEME_LIGHT)      return "LIGHT";
   if(th==THEME_GOLD)       return "GOLD";
   if(th==THEME_NEON)       return "NEON";
   if(th==THEME_MIDNIGHT)   return "NAVY";
   if(th==THEME_MATRIX)     return "MATRIX";
   if(th==THEME_CYBERPUNK)  return "CYBER";
   if(th==THEME_EMERALD)    return "EMERALD";
   if(th==THEME_ROYAL_RUBY) return "RUBY";
   if(th==THEME_SOLAR)      return "SOLAR";
   if(th==THEME_CUSTOM)     return "CUSTOM";
   return "THEME";
}

//====================================================================
// MULTI-THEME PALETTE ENGINE (+ custom override)
//====================================================================
void ApplyPremiumColors()
{
   switch(CurrentTheme)
   {
      case THEME_LIGHT:
         C_BG_Dark=C'238,242,248'; C_Card_Dark=C'255,255,255'; C_Border_Soft=C'180,195,215';
         C_Accent_Neon=C'29,78,216'; C_OnAccent_Text=C'255,255,255'; C_Header_Title=C'15,23,42';
         C_Text_Primary=C'15,23,42'; C_Text_Secondary=C'51,65,85'; C_Text_Muted=C'100,116,139';
         C_Success_Glow=C'5,150,105'; C_Warning_Glow=C'217,119,6'; C_Danger_Glow=C'220,38,38';
         C_Info_Glow=C'8,145,178'; C_Meter_BG=C'210,220,235';
         C_Save_BG=C'29,78,216'; C_Save_Text=C'255,255,255';
         break;
      case THEME_GOLD:
         C_BG_Dark=C'16,12,6'; C_Card_Dark=C'26,20,10'; C_Border_Soft=C'110,88,34';
         C_Accent_Neon=C'255,200,50'; C_OnAccent_Text=C'20,15,4'; C_Header_Title=C'255,230,160';
         C_Text_Primary=C'255,235,185'; C_Text_Secondary=C'210,180,120'; C_Text_Muted=C'140,115,75';
         C_Success_Glow=C'160,230,100'; C_Warning_Glow=C'255,200,50'; C_Danger_Glow=C'240,80,70';
         C_Info_Glow=C'100,200,255'; C_Meter_BG=C'44,35,16';
         C_Save_BG=C'255,200,50'; C_Save_Text=C'20,15,4';
         break;
      case THEME_NEON:
         C_BG_Dark=C'8,4,18'; C_Card_Dark=C'16,8,34'; C_Border_Soft=C'90,40,140';
         C_Accent_Neon=C'0,255,200'; C_OnAccent_Text=C'4,2,10'; C_Header_Title=C'245,240,255';
         C_Text_Primary=C'245,240,255'; C_Text_Secondary=C'180,150,230'; C_Text_Muted=C'110,80,160';
         C_Success_Glow=C'0,255,140'; C_Warning_Glow=C'255,220,30'; C_Danger_Glow=C'255,40,110';
         C_Info_Glow=C'60,210,255'; C_Meter_BG=C'32,16,60';
         C_Save_BG=C'0,255,200'; C_Save_Text=C'4,2,10';
         break;
      case THEME_MIDNIGHT:
         C_BG_Dark=C'4,10,24'; C_Card_Dark=C'10,20,44'; C_Border_Soft=C'36,65,115';
         C_Accent_Neon=C'60,165,255'; C_OnAccent_Text=C'4,8,20'; C_Header_Title=C'235,245,255';
         C_Text_Primary=C'235,245,255'; C_Text_Secondary=C'150,180,225'; C_Text_Muted=C'85,110,155';
         C_Success_Glow=C'30,230,160'; C_Warning_Glow=C'255,195,50'; C_Danger_Glow=C'255,75,95';
         C_Info_Glow=C'60,165,255'; C_Meter_BG=C'20,38,75';
         C_Save_BG=C'60,165,255'; C_Save_Text=C'4,8,20';
         break;
      case THEME_MATRIX:
         C_BG_Dark=C'4,14,6'; C_Card_Dark=C'8,24,12'; C_Border_Soft=C'28,85,42';
         C_Accent_Neon=C'0,255,80'; C_OnAccent_Text=C'2,10,4'; C_Header_Title=C'190,255,210';
         C_Text_Primary=C'190,255,210'; C_Text_Secondary=C'120,215,150'; C_Text_Muted=C'60,130,80';
         C_Success_Glow=C'0,255,80'; C_Warning_Glow=C'230,255,60'; C_Danger_Glow=C'255,60,70';
         C_Info_Glow=C'60,255,190'; C_Meter_BG=C'16,45,24';
         C_Save_BG=C'0,255,80'; C_Save_Text=C'2,10,4';
         break;
      case THEME_CYBERPUNK:
         C_BG_Dark=C'16,4,24'; C_Card_Dark=C'26,8,40'; C_Border_Soft=C'130,30,160';
         C_Accent_Neon=C'255,0,120'; C_OnAccent_Text=C'255,255,255'; C_Header_Title=C'255,240,250';
         C_Text_Primary=C'255,240,250'; C_Text_Secondary=C'210,130,240'; C_Text_Muted=C'140,70,170';
         C_Success_Glow=C'0,240,255'; C_Warning_Glow=C'255,200,0'; C_Danger_Glow=C'255,20,80';
         C_Info_Glow=C'0,240,255'; C_Meter_BG=C'48,16,75';
         C_Save_BG=C'255,0,120'; C_Save_Text=C'255,255,255';
         break;
      case THEME_EMERALD:
         C_BG_Dark=C'2,18,12'; C_Card_Dark=C'6,30,20'; C_Border_Soft=C'24,100,68';
         C_Accent_Neon=C'16,185,129'; C_OnAccent_Text=C'2,18,12'; C_Header_Title=C'236,253,245';
         C_Text_Primary=C'236,253,245'; C_Text_Secondary=C'110,231,183'; C_Text_Muted=C'52,143,108';
         C_Success_Glow=C'52,211,153'; C_Warning_Glow=C'245,158,11'; C_Danger_Glow=C'239,68,68';
         C_Info_Glow=C'56,189,248'; C_Meter_BG=C'12,50,34';
         C_Save_BG=C'16,185,129'; C_Save_Text=C'2,18,12';
         break;
      case THEME_ROYAL_RUBY:
         C_BG_Dark=C'20,8,16'; C_Card_Dark=C'34,14,28'; C_Border_Soft=C'120,40,85';
         C_Accent_Neon=C'225,29,72'; C_OnAccent_Text=C'255,255,255'; C_Header_Title=C'255,241,242';
         C_Text_Primary=C'255,241,242'; C_Text_Secondary=C'251,113,133'; C_Text_Muted=C'159,18,57';
         C_Success_Glow=C'34,197,94'; C_Warning_Glow=C'251,191,36'; C_Danger_Glow=C'244,63,94';
         C_Info_Glow=C'96,165,250'; C_Meter_BG=C'60,20,45';
         C_Save_BG=C'225,29,72'; C_Save_Text=C'255,255,255';
         break;
      case THEME_SOLAR:
         C_BG_Dark=C'10,10,12'; C_Card_Dark=C'18,18,22'; C_Border_Soft=C'80,50,30';
         C_Accent_Neon=C'255,107,0'; C_OnAccent_Text=C'10,10,12'; C_Header_Title=C'255,245,235';
         C_Text_Primary=C'255,245,235'; C_Text_Secondary=C'255,170,100'; C_Text_Muted=C'150,90,50';
         C_Success_Glow=C'34,197,94'; C_Warning_Glow=C'255,190,0'; C_Danger_Glow=C'239,68,68';
         C_Info_Glow=C'56,189,248'; C_Meter_BG=C'38,25,18';
         C_Save_BG=C'255,107,0'; C_Save_Text=C'10,10,12';
         break;
      case THEME_CUSTOM:
         C_BG_Dark=Cust_PanelBG; C_Card_Dark=Cust_PanelBG; C_Border_Soft=Cust_Border;
         C_Accent_Neon=Cust_Accent; C_OnAccent_Text=Cust_OnAccentText; C_Header_Title=Cust_TitleText;
         C_Text_Primary=Cust_TextPrimary; C_Text_Secondary=Cust_TextSecondary; C_Text_Muted=Cust_TextMuted;
         C_Success_Glow=Cust_Success; C_Warning_Glow=Cust_Warning; C_Danger_Glow=Cust_Danger;
         C_Info_Glow=Cust_Info; C_Meter_BG=Cust_PanelBG;
         C_Save_BG=Cust_SaveBtnBG; C_Save_Text=Cust_SaveBtnText;
         break;
      case THEME_DARK:
      default:
         C_BG_Dark=C'10,12,20'; C_Card_Dark=C'18,20,34'; C_Border_Soft=C'45,55,80';
         C_Accent_Neon=Inp_NeonAccent; C_OnAccent_Text=C'255,255,255'; C_Header_Title=C'240,244,255';
         C_Text_Primary=C'240,244,255'; C_Text_Secondary=C'140,155,185'; C_Text_Muted=C'75,88,115';
         C_Success_Glow=C'0,230,130'; C_Warning_Glow=C'255,180,0'; C_Danger_Glow=C'255,60,80';
         C_Info_Glow=C'0,190,255'; C_Meter_BG=C'24,28,48';
         C_Save_BG=C'30,90,220'; C_Save_Text=C'255,255,255';
         break;
   }
   if(OverrideColors && CurrentTheme != THEME_CUSTOM)
   {
      C_BG_Dark=Cust_PanelBG; C_Card_Dark=Cust_PanelBG; C_Border_Soft=Cust_Border;
      C_Accent_Neon=Cust_Accent; C_OnAccent_Text=Cust_OnAccentText; C_Header_Title=Cust_TitleText;
      C_Text_Primary=Cust_TextPrimary; C_Text_Secondary=Cust_TextSecondary; C_Text_Muted=Cust_TextMuted;
      C_Success_Glow=Cust_Success; C_Warning_Glow=Cust_Warning; C_Danger_Glow=Cust_Danger;
      C_Info_Glow=Cust_Info; C_Meter_BG=Cust_PanelBG;
      C_Save_BG=Cust_SaveBtnBG; C_Save_Text=Cust_SaveBtnText;
   }
   C_Glass_BG=C_BG_Dark; C_Glass_Panel=C_Card_Dark; C_Glass_Border=C_Border_Soft;
   C_Glass_Card=C_Card_Dark; C_Glass_Accent=C_Accent_Neon; C_Glass_Accent2=C_Accent_Neon;
   C_Glass_Shadow=C_Border_Soft; C_Glass_Highlight=C_Accent_Neon;
   C_Tracker_Text=C_Text_Secondary; C_Tracker_Value=C_Text_Primary; C_Tracker_Header=C_Text_Muted;
   C_Tracker_Success=C_Success_Glow; C_Tracker_Danger=C_Danger_Glow;
}

void ApplyThemeChartColors()
{
   if(!ApplyChartColors) return;
   long c=0; color bg,fg,grid,bull,bear,up,dn,line,vol,ask,bid,stop;
   switch(CurrentTheme)
   {
      case THEME_LIGHT: bg=C'248,250,252';fg=C'71,85,105';grid=C'226,232,240';bull=C'16,185,129';bear=C'239,68,68';up=C'5,150,105';dn=C'220,38,38';line=C'15,23,42';vol=C'148,163,184';ask=C'37,99,235';bid=C'217,119,6';stop=C'148,163,184'; break;
      case THEME_GOLD: bg=C'18,15,8';fg=C'200,176,120';grid=C'56,46,22';bull=C'255,196,60';bear=C'235,120,90';up=C'255,210,90';dn=C'210,90,60';line=C'255,224,150';vol=C'120,104,70';ask=C'255,196,60';bid=C'180,150,90';stop=C'120,104,70'; break;
      case THEME_NEON: bg=C'8,4,18';fg=C'170,140,220';grid=C'40,20,70';bull=C'0,255,150';bear=C'255,40,120';up=C'0,255,150';dn=C'255,40,120';line=C'240,230,255';vol=C'95,70,140';ask=C'0,255,200';bid=C'255,40,120';stop=C'95,70,140'; break;
      case THEME_MIDNIGHT: bg=C'6,12,28';fg=C'140,165,205';grid=C'24,40,72';bull=C'40,220,170';bear=C'255,90,110';up=C'40,220,170';dn=C'255,90,110';line=C'225,238,255';vol=C'70,90,130';ask=C'90,170,255';bid=C'255,190,70';stop=C'70,90,130'; break;
      case THEME_MATRIX: bg=C'4,12,6';fg=C'110,200,140';grid=C'18,52,28';bull=C'0,255,90';bear=C'255,80,80';up=C'0,255,90';dn=C'255,80,80';line=C'180,255,200';vol=C'50,110,70';ask=C'0,255,90';bid=C'220,255,80';stop=C'50,110,70'; break;
      case THEME_CYBERPUNK: bg=C'12,2,18';fg=C'210,130,240';grid=C'50,15,70';bull=C'0,240,255';bear=C'255,0,120';up=C'0,240,255';dn=C'255,0,120';line=C'255,240,250';vol=C'140,70,170';ask=C'255,0,120';bid=C'0,240,255';stop=C'140,70,170'; break;
      case THEME_EMERALD: bg=C'2,16,10';fg=C'110,231,183';grid=C'15,55,38';bull=C'16,185,129';bear=C'239,68,68';up=C'16,185,129';dn=C'239,68,68';line=C'236,253,245';vol=C'52,143,108';ask=C'245,158,11';bid=C'16,185,129';stop=C'52,143,108'; break;
      case THEME_ROYAL_RUBY: bg=C'16,6,12';fg=C'251,113,133';grid=C'60,20,40';bull=C'34,197,94';bear=C'225,29,72';up=C'34,197,94';dn=C'225,29,72';line=C'255,241,242';vol=C'159,18,57';ask=C'251,191,36';bid=C'225,29,72';stop=C'159,18,57'; break;
      case THEME_SOLAR: bg=C'8,8,10';fg=C'255,170,100';grid=C'45,30,20';bull=C'255,107,0';bear=C'239,68,68';up=C'255,107,0';dn=C'239,68,68';line=C'255,245,235';vol=C'150,90,50';ask=C'255,190,0';bid=C'255,107,0';stop=C'150,90,50'; break;
      case THEME_CUSTOM: bg=Cust_PanelBG;fg=Cust_TextSecondary;grid=Cust_Border;bull=Cust_Success;bear=Cust_Danger;up=Cust_Success;dn=Cust_Danger;line=Cust_TextPrimary;vol=Cust_TextMuted;ask=Cust_Accent;bid=Cust_Warning;stop=Cust_TextMuted; break;
      case THEME_DARK: default: bg=C'12,12,20';fg=C'140,148,170';grid=C'30,30,45';bull=C'0,230,130';bear=C'255,60,80';up=C'0,230,130';dn=C'255,60,80';line=C'240,244,255';vol=C'70,75,95';ask=C'0,255,200';bid=C'90,100,120';stop=C'90,100,120'; break;
   }
   ChartSetInteger(c,CHART_COLOR_BACKGROUND,bg); ChartSetInteger(c,CHART_COLOR_FOREGROUND,fg); ChartSetInteger(c,CHART_COLOR_GRID,grid);
   ChartSetInteger(c,CHART_COLOR_CANDLE_BULL,bull); ChartSetInteger(c,CHART_COLOR_CANDLE_BEAR,bear);
   ChartSetInteger(c,CHART_COLOR_CHART_UP,up); ChartSetInteger(c,CHART_COLOR_CHART_DOWN,dn);
   ChartSetInteger(c,CHART_COLOR_CHART_LINE,line); ChartSetInteger(c,CHART_COLOR_VOLUME,vol);
   ChartSetInteger(c,CHART_COLOR_ASK,ask); ChartSetInteger(c,CHART_COLOR_BID,bid); ChartSetInteger(c,CHART_COLOR_STOP_LEVEL,stop);
   ChartRedraw(c);
}


//====================================================================
// CREATIVE AURORA GLASS UI
// Visual layer only. Trading logic above remains unchanged.
//====================================================================
string aurora_prefix="AURORA_";
int aurora_w=0, aurora_h=0, aurora_left_w=298, aurora_right_w=298;

void AuroraDeleteAll()
{
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
   {
      string n=ObjectName(0,i,-1);
      if(StringFind(n,aurora_prefix)==0) ObjectDelete(0,n);
   }
}
// Solid raised card style: BORDER_RAISED gives the classic 3D solid edge.
void AuroraRect(string id,int x,int y,int w,int h,color bg,color border=clrNONE)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,MathMax(1,w)); ObjectSetInteger(0,n,OBJPROP_YSIZE,MathMax(1,h));
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_COLOR,border==clrNONE?bg:border);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false); ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
bool AuroraBitmap(string id,string file,int x,int y,int w,int h,bool behind=false)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BITMAP_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   // Keep native bitmap dimensions: MT4 crops when the object is smaller than the asset.
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_BMPFILE,AuroraAssetFolder+"\\"+file);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,n,OBJPROP_BACK,behind);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   return true;
}
// Embedded-resource bitmap (asset compiled into the EA via #resource).
bool AuroraResBitmap(string id,string res,int x,int y,int w,int h,bool behind=false)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BITMAP_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_BMPFILE,"::HorizonAssets\\"+res);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,n,OBJPROP_BACK,behind);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
   return true;
}

//====================================================================
// LIVE-RENDERED WIDGETS (mockup style, drawn from real data)
// Clocks: real London/NY local time (DST-aware) + session arc.
// Equity curve: built from actual closed trade history.
//====================================================================
int g_htp_lastClockMin=-1, g_htp_lastHist=-1;
int g_htp_clockLX=0,g_htp_clockLY=0,g_htp_clockNX=0,g_htp_clockNY=0,g_htp_eqX=0,g_htp_eqY=0;

uint HTP_ARGB(color c){ return ((uint)0xFF<<24) | ((uint)(c&0xFF)<<16) | ((uint)((c>>8)&0xFF)<<8) | (uint)((c>>16)&0xFF); }

double HTP_SegDist(double pxx,double pyy,double x0,double y0,double x1,double y1)
{
   double vx=x1-x0, vy=y1-y0, wx=pxx-x0, wy=pyy-y0;
   double c1=vx*wx+vy*wy; if(c1<=0.0) return MathSqrt(wx*wx+wy*wy);
   double c2=vx*vx+vy*vy; if(c2<=c1) return MathSqrt((pxx-x1)*(pxx-x1)+(pyy-y1)*(pyy-y1));
   double b=c1/c2, bx=x0+b*vx, by=y0+b*vy;
   return MathSqrt((pxx-bx)*(pxx-bx)+(pyy-by)*(pyy-by));
}

void HTP_Line(uint &buf[],int w,int h,int x0,int y0,int x1,int y1,uint c)
{
   int dx=(int)MathAbs(x1-x0), sx=(x0<x1?1:-1);
   int dy=-(int)MathAbs(y1-y0), sy=(y0<y1?1:-1);
   int err=dx+dy;
   while(true)
   {
      for(int oy=0;oy<2;oy++) for(int ox=0;ox<2;ox++)
      { int X=x0+ox, Y=y0+oy; if(X>=0&&X<w&&Y>=0&&Y<h) buf[Y*w+X]=c; }
      if(x0==x1 && y0==y1) break;
      int e2=2*err;
      if(e2>=dy){ err+=dy; x0+=sx; }
      if(e2<=dx){ err+=dx; y0+=sy; }
   }
}

// rightAnchor=true -> x is the distance from the chart's RIGHT edge to the
// bitmap's RIGHT edge (CORNER_RIGHT_UPPER), so it never leaves the view.
void HTP_SetBitmapObj(string id,string res,int x,int y,int w,int h,bool rightAnchor=false)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_BITMAP_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,w); ObjectSetInteger(0,n,OBJPROP_YSIZE,h);
   ObjectSetString(0,n,OBJPROP_BMPFILE,res);
   ObjectSetInteger(0,n,OBJPROP_CORNER,rightAnchor?CORNER_RIGHT_UPPER:CORNER_LEFT_UPPER); ObjectSetInteger(0,n,OBJPROP_BACK,false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}

// Analog session clock rendered live: hands = real session local time,
// colored arc = the session window (open -> close) on the 12h dial.
// x = distance from the chart's RIGHT edge to the clock's RIGHT edge (right-anchored).
void HTP_DrawLiveClock(string id,int x,int y,ENUM_SESSION_ID sess,color arcColor)
{
   int w=112,h=112;
   uint pxbuf[]; ArrayResize(pxbuf,w*h); ArrayInitialize(pxbuf,0x00000000);
   double PI2=6.28318530717959;
   double cx=(w-1)/2.0, cy=(h-1)/2.0;
   double rOut=55.0, ringIn=45.0, faceR=42.0;

   datetime now=TimeCurrent();
   datetime lt=AutoDST_GetSessionLocalTime(now,sess);
   MqlDateTime dt; TimeToStruct(lt,dt);
   double mm=dt.min+dt.sec/60.0;
   double hh=(dt.hour%12)+mm/60.0;
   double aH=hh/12.0*PI2, aM=mm/60.0*PI2;                 // angle from 12 o'clock, clockwise

   int brokerOff=AutoDST_GetBrokerGMTOffsetHours(now);
   int sessOff  =AutoDST_GetSessionGMTOffsetHours(now,sess);
   int openSrv  =(sess==SESSION_ID_LONDON ? g_auto_session_times.london_open_server_min  : g_auto_session_times.ny_open_server_min);
   int closeSrv =(sess==SESSION_ID_LONDON ? g_auto_session_times.london_close_server_min : g_auto_session_times.ny_close_server_min);
   int openLoc  =AutoDST_NormalizeMinutes(openSrv -(brokerOff-sessOff)*60);
   int spanMin  =AutoDST_NormalizeMinutes(closeSrv-openSrv); if(spanMin>720) spanMin=720;
   double aStart=MathMod((double)openLoc,720.0)/720.0*PI2;
   double aSpan =spanMin/720.0*PI2;

   uint cArc  =HTP_ARGB(arcColor);
   uint cRing =HTP_ARGB(C'42,50,66');
   uint cFace =HTP_ARGB(C'246,244,243');
   uint cDark =HTP_ARGB(C'30,40,56');
   uint cDot  =HTP_ARGB(C'110,118,132');

   // hand endpoints
   double mx=cx+MathSin(aM)*33.0, my=cy-MathCos(aM)*33.0;
   double hx=cx+MathSin(aH)*23.0, hy=cy-MathCos(aH)*23.0;

   for(int py=0;py<h;py++)
   {
      for(int pxi=0;pxi<w;pxi++)
      {
         double dx=pxi-cx, dy=py-cy;
         double dist=MathSqrt(dx*dx+dy*dy);
         if(dist>rOut) continue;
         int idx=py*w+pxi;
         double ang=Atan2(dx,-dy); if(ang<0) ang+=PI2;    // 0 at 12 o'clock, clockwise
         if(dist>=ringIn)                                  // outer ring + session arc
         {
            double rel=ang-aStart; if(rel<0) rel+=PI2;
            pxbuf[idx]=(rel<=aSpan ? cArc : cRing);
            continue;
         }
         if(dist>faceR){ pxbuf[idx]=cDark; continue; }     // thin dark rim
         pxbuf[idx]=cFace;                                 // white face
         // hour tick marks
         if(dist>faceR-7.0 && dist<faceR-2.0)
         {
            double tickStep=PI2/12.0;
            double nearest=MathMod(ang+tickStep/2.0,tickStep)-tickStep/2.0;
            if(MathAbs(nearest)*dist<1.6){ pxbuf[idx]=cDark; continue; }
         }
         // hands
         if(HTP_SegDist(pxi,py,cx,cy,mx,my)<=1.7){ pxbuf[idx]=cDark; continue; }
         if(HTP_SegDist(pxi,py,cx,cy,hx,hy)<=2.3){ pxbuf[idx]=cDark; continue; }
         if(dist<=3.2) pxbuf[idx]=cDot;                    // center dot
      }
   }
   string res="::HTP_"+id;
   ResourceCreate(res,pxbuf,w,h,0,0,0,1);
   HTP_SetBitmapObj(id,res,x,y,w,h,true);
}

// Equity curve rendered live from actual closed-trade history (g_eqBalances).
// x = distance from the chart's RIGHT edge to the panel's RIGHT edge (right-anchored).
void HTP_DrawLiveEquity(string id,int x,int y)
{
   int w=250,h=72;
   BuildEquityData();
   uint pxbuf[]; ArrayResize(pxbuf,w*h);
   uint cBG=HTP_ARGB(C'23,37,54'), cBrd=HTP_ARGB(C'47,75,99');
   uint cBlue=HTP_ARGB(C'58,180,240'), cOrg=HTP_ARGB(C'255,139,34');
   ArrayInitialize(pxbuf,cBG);
   for(int bx=0;bx<w;bx++){ pxbuf[bx]=cBrd; pxbuf[(h-1)*w+bx]=cBrd; }
   for(int by=0;by<h;by++){ pxbuf[by*w]=cBrd; pxbuf[by*w+w-1]=cBrd; }

   if(g_eqCount>=2)
   {
      double minB=g_eqBalances[0], maxB=g_eqBalances[0];
      for(int i=1;i<g_eqCount;i++){ if(g_eqBalances[i]<minB) minB=g_eqBalances[i]; if(g_eqBalances[i]>maxB) maxB=g_eqBalances[i]; }
      double range=maxB-minB; if(range<=0.0000001) range=1.0;
      int padL=6,padR=6,padT=18,padB=8;
      int plotW=w-padL-padR, plotH=h-padT-padB;
      double startBal=g_eqBalances[0];
      int prevX=padL, prevY=padT+plotH-(int)((g_eqBalances[0]-minB)/range*plotH);
      for(int i=1;i<g_eqCount;i++)
      {
         int cxp=padL+(int)((double)i/(double)(g_eqCount-1)*plotW);
         int cyp=padT+plotH-(int)((g_eqBalances[i]-minB)/range*plotH);
         uint segClr=(g_eqBalances[i]<startBal ? cOrg : cBlue);   // below start = orange (as in mockup)
         HTP_Line(pxbuf,w,h,prevX,prevY,cxp,cyp,segClr);
         prevX=cxp; prevY=cyp;
      }
   }
   string res="::HTP_"+id;
   ResourceCreate(res,pxbuf,w,h,0,0,0,1);
   HTP_SetBitmapObj(id,res,x,y,w,h,true);
}

// Refresh live widgets: clocks once per minute, equity when history changes.
void HTP_UpdateLiveWidgets(bool force=false)
{
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt);
   int curMin=dt.hour*60+dt.min;
   if(force || curMin!=g_htp_lastClockMin)
   {
      g_htp_lastClockMin=curMin;
      HTP_DrawLiveClock("ClockL",g_htp_clockLX,g_htp_clockLY,SESSION_ID_LONDON,C'34,197,94');
      HTP_DrawLiveClock("ClockN",g_htp_clockNX,g_htp_clockNY,SESSION_ID_NEWYORK,C'255,139,34');
   }
   int histNow=OrdersHistoryTotal();
   if(force || histNow!=g_htp_lastHist)
   {
      g_htp_lastHist=histNow;
      HTP_DrawLiveEquity("EqBox",g_htp_eqX,g_htp_eqY);
   }
}
void AuroraLabel(string id,string text,int x,int y,int size,color clr,string font="Arial Bold",int anchor=ANCHOR_LEFT_UPPER)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,text); ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,anchor); ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void AuroraText(string id,string text,color clr)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)>=0){ ObjectSetString(0,n,OBJPROP_TEXT,text); ObjectSetInteger(0,n,OBJPROP_COLOR,clr); }
}
void AuroraLine(string id,int x,int y,int w,color clr){ AuroraRect(id,x,y,w,2,clr); }
void AuroraMetric(string id,string key,string value,int x,int y,color accent)
{
   // Tactical Navy metric tile: opaque card, accent rail, compact key/value hierarchy.
   AuroraRect(id+"BG",x,y-4,260,38,C'15,30,50',C'38,70,94');
   AuroraRect(id+"Rail",x,y-4,4,38,accent);
   AuroraLabel(id+"K",key,x+16,y,8,C'160,178,198',"Arial");
   AuroraLabel(id+"V",value,x+16,y+13,13,clrWhite,"Arial Bold");
}
void AuroraCard(string id,int x,int y,int w,int h,string title,string value,color accent)
{
   AuroraRect(id+"BG",x,y,w,h,C'18,28,46',C'48,70,98');
   AuroraLabel(id+"K",title,x+10,y+5,8,C'160,170,190',"Arial Bold");
   AuroraLabel(id+"V",value,x+10,y+19,11,accent,"Arial Bold");
}
void AuroraRefCard(string id,string title,string value,int x,int y,int w,int h,color accent)
{
   AuroraRect(id+"BG",x,y,w,h,C'18,34,54',C'47,75,99');
   AuroraRect(id+"Accent",x,y,3,h,accent);
   AuroraLabel(id+"K",title,x+10,y+7,9,C'190,201,213',"Arial");
   AuroraLabel(id+"V",value,x+10,y+23,14,accent,"Arial Bold");
}
//--- RIGHT-ANCHORED variants (CORNER_RIGHT_UPPER): XDISTANCE is measured from
//--- the chart's real renderable right edge, so the right panel can never
//--- fall outside the view, whatever the window size or price-scale width.
//--- Objects always extend right/down, so xl = distance from the right edge
//--- to the element's LEFT side.
void AuroraRectR(string id,int xl,int y,int w,int h,color bg,color border=clrNONE)
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,xl); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE,MathMax(1,w)); ObjectSetInteger(0,n,OBJPROP_YSIZE,MathMax(1,h));
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,n,OBJPROP_COLOR,border==clrNONE?bg:border);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE,BORDER_RAISED);
   ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_BACK,false); ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void AuroraLabelR(string id,string text,int xl,int y,int size,color clr,string font="Arial Bold")
{
   string n=aurora_prefix+id;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE,xl); ObjectSetInteger(0,n,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,n,OBJPROP_TEXT,text); ObjectSetString(0,n,OBJPROP_FONT,font);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,n,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,n,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); ObjectSetInteger(0,n,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,n,OBJPROP_HIDDEN,true);
}
void AuroraRefCardR(string id,string title,string value,int xl,int y,int w,int h,color accent)
{
   AuroraRectR(id+"BG",xl,y,w,h,C'18,34,54',C'47,75,99');
   AuroraRectR(id+"Accent",xl,y,3,h,accent);
   AuroraLabelR(id+"K",title,xl-10,y+7,9,C'190,201,213',"Arial");
   AuroraLabelR(id+"V",value,xl-10,y+23,14,accent,"Arial Bold");
}
void AuroraBuild()
{
   aurora_w=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0); aurora_h=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
   if(aurora_w<300) aurora_w=1366; if(aurora_h<300) aurora_h=768;   // fallback only if chart not ready yet
   int side=285, mid=MathMax(300,aurora_w-2*side), chartBottom=MathMax(360,aurora_h-190);
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES); ChartSetInteger(0,CHART_FOREGROUND,false);
   ChartSetInteger(0,CHART_COLOR_BACKGROUND,C'7,17,31'); ChartSetInteger(0,CHART_COLOR_GRID,C'35,58,79');
   ChartSetInteger(0,CHART_COLOR_CANDLE_BULL,C'53,220,210'); ChartSetInteger(0,CHART_COLOR_CANDLE_BEAR,C'255,139,34');
   ChartSetInteger(0,CHART_COLOR_CHART_UP,C'53,220,210'); ChartSetInteger(0,CHART_COLOR_CHART_DOWN,C'255,139,34');
   ChartSetInteger(0,CHART_SHOW_PRICE_SCALE,true); ChartSetInteger(0,CHART_SHOW_DATE_SCALE,true);
   AuroraRect("RefLeft",0,0,side,aurora_h,C'9,20,35',C'33,73,101'); AuroraRectR("RefRight",side,0,side,aurora_h,C'9,20,35',C'33,73,101');
   AuroraRect("RefBottom",side,chartBottom,mid,aurora_h-chartBottom,C'10,25,42',C'34,70,93');
   // Logo card: generated bitmap asset matching the mockup (compass + HORIZON TACTICAL + target).
   AuroraResBitmap("LogoCard","logo_card.bmp",10,8,265,86);
   AuroraRefCard("Status","EA STATUS","ACTIVE (GREEN)",10,102,265,55,C'104,244,157');
   AuroraRefCard("Srv","DATE / SERVER TIME",TimeToString(TimeCurrent(),TIME_DATE)+"  "+TimeToString(TimeCurrent(),TIME_SECONDS),10,164,265,55,C'190,201,213');
   AuroraLabel("AccTitle","ACCOUNT INFO",20,236,20,clrWhite,"Arial");
   AuroraRefCard("Bal","BALANCE",FormatMoneyAbs(AccountBalance()),18,268,124,58,C'190,201,213'); AuroraRefCard("Eq","EQUITY",FormatMoneyAbs(AccountEquity()),151,268,124,58,C'190,201,213');
   AuroraRefCard("FM","FREE MARGIN",FormatMoneyAbs(AccountFreeMargin()),18,334,124,58,C'190,201,213'); AuroraRefCard("Lot","LOT SIZE",DoubleToString(CalculateLotSize(FixedSL_Points),2),151,334,124,58,C'190,201,213');
   AuroraRefCard("DD","DRAWDOWN",DoubleToString(AccountBalance()>0?cachedMaxDD/AccountBalance()*100.0:0,1)+"%",18,400,124,58,C'255,139,34'); AuroraRefCard("Lev","LEVERAGE","1:"+IntegerToString((int)AccountLeverage()),151,400,124,58,C'190,201,213');
   AuroraLabel("StrTitle","STRATEGY INFO",20,482,20,clrWhite,"Arial"); AuroraRefCard("Strat","CURRENT STRATEGY",OrbTradeMode==MODE_NY_ONLY?"NEW YORK ORB":"LONDON ORB",18,515,257,52,C'58,220,221');
   AuroraRefCard("ORBH","ORB HIGH",DoubleToString(lonOrbHigh,2),18,575,124,58,C'190,201,213'); AuroraRefCard("ORBL","ORB LOW",DoubleToString(lonOrbLow,2),151,575,124,58,C'190,201,213'); AuroraRefCard("ORBR","ORB RANGE",DoubleToString(MathAbs(lonOrbHigh-lonOrbLow)/Point,0)+" pips",18,641,124,58,C'58,220,221');
   AuroraLabel("TradeRun","LONDON / NEW YORK ORB  //  RUNNING",18,aurora_h-23,9,C'58,220,221');
   // Right panel: ANCHORED TO THE RIGHT EDGE (CORNER_RIGHT_UPPER) so it always
   // stays fully visible regardless of the window / chart size.
   AuroraLabelR("SesL","LONDON SESSION",side-16,20,11,clrWhite,"Arial"); AuroraLabelR("SesN","NEW YORK SESSION",side-144,20,11,clrWhite,"Arial");
   // Session clocks: LIVE analog clocks (real DST-aware London/NY time, session arc = actual session window).
   g_htp_clockLX=side-18; g_htp_clockLY=42; g_htp_clockNX=side-150; g_htp_clockNY=42;   // distance from RIGHT edge to clock's LEFT side
   HTP_DrawLiveClock("ClockL",g_htp_clockLX,g_htp_clockLY,SESSION_ID_LONDON,C'34,197,94');
   HTP_DrawLiveClock("ClockN",g_htp_clockNX,g_htp_clockNY,SESSION_ID_NEWYORK,C'255,139,34');
   AuroraLabelR("PerfTitle","PERFORMANCE SUMMARY",side-16,178,15,clrWhite,"Arial");
   AuroraRefCardR("TTrades","TOTAL TRADES",IntegerToString(cachedWins+cachedLosses),side-18,211,80,58,clrWhite); AuroraRefCardR("Wins","WINS",IntegerToString(cachedWins),side-103,211,80,58,C'104,244,157'); AuroraRefCardR("Loss","LOSSES",IntegerToString(cachedLosses),side-188,211,80,58,C'255,96,120');
   AuroraRefCardR("Win","WINRATE",DoubleToString(cachedWinRate,1)+"%",side-18,277,124,58,C'104,244,157'); AuroraRefCardR("PF","PROFIT FACTOR",DoubleToString(cachedPF,2),side-151,277,117,58,C'104,244,157');
   AuroraLabelR("PLTitle","P/L METRICS",side-16,359,15,clrWhite,"Arial"); AuroraRefCardR("DayPL","DAILY P/L",FormatMoney(GetPeriodProfit(0)),side-18,392,124,58,C'104,244,157'); AuroraRefCardR("ActivePL","ACTIVE P/L",FormatMoney(GetActiveProfit()),side-151,392,117,58,C'104,244,157');
   // Equity curve widget: LIVE curve drawn from actual closed-trade history (mockup style).
   g_htp_eqX=side-18; g_htp_eqY=480;   // distance from RIGHT edge to panel's LEFT side
   HTP_DrawLiveEquity("EqBox",g_htp_eqX,g_htp_eqY);
   AuroraLabelR("EqCurve","Equity curve",side-24,486,8,C'160,178,198',"Arial");
   AuroraLabelR("NewsTitle","NEWS RADAR",side-16,579,15,clrWhite,"Arial"); AuroraRectR("NewsBox",side-18,610,250,115,C'17,35,53',C'47,75,99'); AuroraLabelR("News1","●  News / session filter",side-28,628,9,C'255,96,120'); AuroraLabelR("News2","●  Spread protection active",side-28,652,9,C'255,139,34'); AuroraLabelR("News3","●  ORB execution monitor",side-28,676,9,C'174,116,255'); AuroraLabelR("News4",g_newsStatus,side-28,700,9,C'190,201,213');
   // Bottom center tracker modeled on the reference table.
   AuroraLabel("LiveTitle","LIVE PROFIT TRACKER",side+18,chartBottom+12,19,clrWhite,"Arial"); AuroraRefCard("Float","TOTAL FLOATING P/L",FormatMoney(GetActiveProfit()),side+mid-265,chartBottom+8,125,48,C'104,244,157'); AuroraRefCard("Gain","TODAY'S GAIN",DoubleToString(AccountBalance()>0?GetPeriodProfit(0)/AccountBalance()*100.0:0,2)+"%",side+mid-135,chartBottom+8,117,48,C'104,244,157');
   string heads[10]={"TICKET","OPEN TIME","TYPE","LOT","ITEM","PRICE","S/L","T/P","COMMISSION","FLOATING P/L"}; int widths[10]={75,92,42,35,58,62,55,55,78,95}; int xx=side+18; for(int h=0;h<10;h++){ AuroraLabel("Head"+IntegerToString(h),heads[h],xx,chartBottom+75,8,C'190,201,213',"Arial"); xx+=widths[h]; }
   int row=0; for(int oi=0;oi<OrdersTotal() && row<5;oi++)
   {
      if(!OrderSelect(oi,SELECT_BY_POS,MODE_TRADES)) continue;
      xx=side+18; int yy=chartBottom+96+row*20; string vals[10];
      vals[0]=IntegerToString(OrderTicket()); vals[1]=TimeToString(OrderOpenTime(),TIME_DATE|TIME_MINUTES);
      vals[2]=(OrderType()==OP_BUY?"BUY":"SELL"); vals[3]=DoubleToString(OrderLots(),2); vals[4]=Symbol();
      vals[5]=DoubleToString(OrderOpenPrice(),2); vals[6]=DoubleToString(OrderStopLoss(),2); vals[7]=DoubleToString(OrderTakeProfit(),2);
      vals[8]=FormatMoney(OrderCommission()); vals[9]=FormatMoney(OrderProfit()+OrderSwap()+OrderCommission());
      for(int q=0;q<10;q++){ AuroraLabel("Row"+IntegerToString(row)+"_"+IntegerToString(q),vals[q],xx,yy,8,(OrderProfit()>=0?C'104,244,157':C'255,96,120'),"Arial"); xx+=widths[q]; }
      row++;
   }
   AuroraLabel("TrackerStatus","WINRATE "+DoubleToString(cachedWinRate,1)+"%     DD "+DoubleToString(AccountBalance()>0?cachedMaxDD/AccountBalance()*100.0:0,1)+"%     CANDLE "+FormatClock((int)MathMax(0,Time[0]+PeriodSeconds()-TimeCurrent())),side+18,aurora_h-25,9,C'190,201,213');
   ChartRedraw(0);
}
void AuroraUpdate()
{
   if(!UseCreativeAuroraUI) return;
   if(ObjectFind(0,aurora_prefix+"RefLeft")<0){ AuroraBuild(); return; }
   HTP_UpdateLiveWidgets(); // live clocks (per minute) + live equity curve (on new closed trades)
   AuroraText("BalV",FormatMoneyAbs(AccountBalance()),clrWhite); AuroraText("EqV",FormatMoneyAbs(AccountEquity()),clrWhite); AuroraText("FMV",FormatMoneyAbs(AccountFreeMargin()),clrWhite); AuroraText("LotV",DoubleToString(CalculateLotSize(FixedSL_Points),2),clrWhite);
   AuroraText("SrvV",TimeToString(TimeCurrent(),TIME_DATE)+"  "+TimeToString(TimeCurrent(),TIME_SECONDS),C'190,201,213'); AuroraText("ActivePLV",FormatMoney(GetActiveProfit()),C'104,244,157'); AuroraText("DayPLV",FormatMoney(GetPeriodProfit(0)),C'104,244,157');
   AuroraText("TTradesV",IntegerToString(cachedWins+cachedLosses),clrWhite); AuroraText("WinsV",IntegerToString(cachedWins),C'104,244,157'); AuroraText("LossV",IntegerToString(cachedLosses),C'255,96,120'); AuroraText("WinV",DoubleToString(cachedWinRate,1)+"%",C'104,244,157'); AuroraText("PFV",DoubleToString(cachedPF,2),C'104,244,157');
   AuroraText("FloatV",FormatMoney(GetActiveProfit()),C'104,244,157'); AuroraText("GainV",DoubleToString(AccountBalance()>0?GetPeriodProfit(0)/AccountBalance()*100.0:0,2)+"%",C'104,244,157'); AuroraText("News4",g_newsStatus,C'190,201,213'); ChartRedraw(0);
}
//====================================================================
// LIFECYCLE
//====================================================================
int OnInit()
{
   // Initialize interactive buttons based on user inputs
   g_trade_day_mon = Allow_Trading_Mon;
   g_trade_day_tue = Allow_Trading_Tue;
   g_trade_day_wed = Allow_Trading_Wed;
   g_trade_day_thu = Allow_Trading_Thu;
   g_trade_day_fri = Allow_Trading_Fri;

   AutoDST_UpdateSessionTimes(TimeCurrent());
   totalHistory=OrdersHistoryTotal();
   UI_Collapsed=UI_StartCollapsed;
   DisplayDZD=StartInDZD;
   if(!UseNewsFilter) g_newsStatus="OFF";
   Print("LONDON & NY DUAL ORB EA - Multi-Theme UI v2.5 AIT CHIKH MUSTAPHA: ",MagicNumber);
   
   CurrentTheme = PanelTheme;
   Lon_MagicNumber = MagicNumber;
   ChartSetInteger(0,CHART_MODE,CHART_CANDLES); // Default to Candlesticks
   ChartSetInteger(0,CHART_FOREGROUND,false);
   ChartSetInteger(0,CHART_SHIFT,UI_ChartShift);
   ApplyThemeChartColors();
   RefreshStatsCache();
   double hi,lo;
   int lonStartM = Lon_Start_Hour * 60 + Lon_Start_Minute;
   int nyStartM  = NY_Start_Hour * 60 + NY_Start_Minute;
   if(AutoDST_FindSessionORBRange(lonStartM, lonStartM + Lon_Duration_Min, hi, lo, SESSION_ID_LONDON)){ lonOrbHigh=hi; lonOrbLow=lo; }
   if(AutoDST_FindSessionORBRange(nyStartM, nyStartM + NY_Duration_Min, hi, lo, SESSION_ID_NEWYORK)){ nyOrbHigh=hi; nyOrbLow=lo; }
   ApplyPremiumColors();
   if(UseCreativeAuroraUI){ AuroraBuild(); AuroraUpdate(); }
   else { if(ShowModernPanel){ CreatePremiumUI(); UpdatePremiumUI(); }
   if(ShowProfitTracker){ CreateProfitTrackerUI(); UpdateProfitTrackerUI(); }
   if(ShowCandleCard){ CreateBottomCard(); UpdateBottomCard(); } }
   CheckClosedTrades();
   if(ShowEquityCurve && !UseCreativeAuroraUI){ BuildEquityData(); DrawEquityCurveBox(); }
   EventSetTimer(1);
   RefreshNewsData();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){ EventKillTimer(); Print("LONDON ORB EA AIT CHIKH MUSTAPHA Removed."); AuroraDeleteAll(); RemoveAllUI(); }

void OnTimer()
{
   AutoDST_UpdateSessionTimes(TimeCurrent());
   g_uiPulse=!g_uiPulse;
   if(UseCreativeAuroraUI) AuroraUpdate();
   else { if(ShowModernPanel) UpdatePremiumUI();
   if(ShowProfitTracker) UpdateProfitTrackerUI();
   if(ShowCandleCard) UpdateBottomCard(); }
   CheckClosedTrades(); DrawHistoricalORBLevels();
   static int newsTimer=0; if(++newsTimer>=60){ RefreshNewsData(); newsTimer=0; }
}

void OnTick()
{
   AutoDST_UpdateSessionTimes(TimeCurrent());
   if(Bars<10) return;
   ManageOpenTrades();
   bool isNewBar=(Time[0]!=lastUIBar); bool historyChanged=(OrdersHistoryTotal()!=lastHistoryCount); tickCounter++;
   bool shouldUpdate=isNewBar||historyChanged;
   if(IsTesting()){ if(tickCounter%50==0) shouldUpdate=true; } else { if(tickCounter%5==0) shouldUpdate=true; }
   if(shouldUpdate)
   {
      lastUIBar=Time[0];
      if(historyChanged) { RefreshStatsCache(); if(ShowEquityCurve && !UseCreativeAuroraUI){ BuildEquityData(); DrawEquityCurveBox(); } }
      if(Badge_ShowBoxes) CheckClosedTrades();
      if(isNewBar) RefreshNewsData();
      double hi,lo;
      int lonStartM = Lon_Start_Hour * 60 + Lon_Start_Minute;
      int nyStartM  = NY_Start_Hour * 60 + NY_Start_Minute;
      if(FindSessionORBRange(lonStartM, lonStartM + Lon_Duration_Min, hi, lo, Lon_GMT_Offset)){ lonOrbHigh=hi; lonOrbLow=lo; }
      if(FindSessionORBRange(nyStartM, nyStartM + NY_Duration_Min, hi, lo, NY_GMT_Offset)){ nyOrbHigh=hi; nyOrbLow=lo; }
      if(UseCreativeAuroraUI) AuroraUpdate();
      else { if(ShowModernPanel) UpdatePremiumUI();
      if(ShowProfitTracker) UpdateProfitTrackerUI();
      if(ShowCandleCard) UpdateBottomCard(); }
      DrawHistoricalORBLevels();
   }
   if(IsNewsTime() || !EA_Enabled) return;
   
   if(OrbTradeMode == MODE_LONDON_ONLY || OrbTradeMode == MODE_BOTH_SESSIONS)
   {
      AutoDST_ProcessSessionTrading(Lon_Start_Hour*60 + Lon_Start_Minute, Lon_Duration_Min, Lon_End_Hour, MagicNumber, lonOrbHigh, lonOrbLow, lastSignalLon, SESSION_ID_LONDON);
   }
   if(OrbTradeMode == MODE_NY_ONLY || OrbTradeMode == MODE_BOTH_SESSIONS)
   {
      AutoDST_ProcessSessionTrading(NY_Start_Hour*60 + NY_Start_Minute, NY_Duration_Min, NY_End_Hour, NY_MagicNumber, nyOrbHigh, nyOrbLow, lastSignalNY, SESSION_ID_NEWYORK);
   }
}

//====================================================================
// HELPERS & CURRENCY FORMATTERS
//====================================================================
string TFToString(int tf){ if(tf==PERIOD_M1)return "M1"; if(tf==PERIOD_M5)return "M5"; if(tf==PERIOD_M15)return "M15"; if(tf==PERIOD_M30)return "M30"; if(tf==PERIOD_H1)return "H1"; if(tf==PERIOD_H4)return "H4"; if(tf==PERIOD_D1)return "D1"; if(tf==PERIOD_W1)return "W1"; if(tf==PERIOD_MN1)return "MN"; return IntegerToString(tf); }
double ClampValue(double v,double vMin,double vMax){ if(v<vMin)return vMin; if(v>vMax)return vMax; return v; }
string FormatMoney(double v)
{ 
   double val = DisplayDZD ? v * USD_DZD_Rate : v;
   string sym = DisplayDZD ? " DZD" : "$";
   if(DisplayDZD) return (val>=0?"+":"-") + DoubleToString(MathAbs(val),0) + sym;
   else return (val>=0?"+$":"-$") + DoubleToString(MathAbs(val),2);
}
string FormatMoneyAbs(double v)
{
   double val = DisplayDZD ? v * USD_DZD_Rate : v;
   string sym = DisplayDZD ? " DZD" : "$";
   if(DisplayDZD) return DoubleToString(MathAbs(val),0) + sym;
   else return "$" + DoubleToString(MathAbs(val),2);
}
string FormatClock(int totalSeconds){ if(totalSeconds<0)totalSeconds=0; int hh=totalSeconds/3600; int mm=(totalSeconds%3600)/60; int ss=totalSeconds%60; return StringFormat("%02d:%02d:%02d",hh,mm,ss); }
string GetSessionCountdownText()
{
   return AutoDST_GetSessionCountdownText(OrbTradeMode);
}
double GetStatusProgressPercent(int sessionMin)
{
   datetime nowServer = TimeCurrent();
   ENUM_SESSION_ID sessionId = AutoDST_GetDisplaySessionId(nowServer, OrbTradeMode);
   int startH, startM, durM, endH;
   AutoDST_GetFixedSessionConfig(sessionId, startH, startM, durM, endH);

   int startMin = startH * 60 + startM;
   int endMin   = startMin + durM;
   
   if(sessionMin < startMin){ if(startMin<=0)return 0; return ClampValue((double)sessionMin*100.0/startMin,0.0,100.0); }
   if(sessionMin >= startMin && sessionMin < endMin){ int dur=MathMax(1,durM); return ClampValue((double)(sessionMin-startMin)*100.0/dur,0.0,100.0); }
   if(sessionMin >= endMin && sessionMin < endH*60){ int dur2=MathMax(1,endH*60-endMin); return ClampValue((double)(sessionMin-endMin)*100.0/dur2,0.0,100.0); }
   return 100.0;
}
int DayOfWeekForDate(int year,int month,int day){ MqlDateTime dt; ZeroMemory(dt); dt.year=year; dt.mon=month; dt.day=day; return TimeDayOfWeek(StructToTime(dt)); }
int NthSunday(int year,int month,int nth){ int firstDow=DayOfWeekForDate(year,month,1); int firstSunday=1+((7-firstDow)%7); return firstSunday+(nth-1)*7; }
bool IsEuroDST(datetime t)
{
   MqlDateTime dt; TimeToStruct(t,dt);
   if(dt.mon<3||dt.mon>10) return false;
   if(dt.mon>3 && dt.mon<10) return true;
   if(dt.mon==3){ int last=NthSunday(dt.year,3,5); if(last>31) last=NthSunday(dt.year,3,4); if(dt.day>last)return true; if(dt.day<last)return false; return(dt.hour>=1); }
   if(dt.mon==10){ int last=NthSunday(dt.year,10,5); if(last>31) last=NthSunday(dt.year,10,4); if(dt.day<last)return true; if(dt.day>last)return false; return(dt.hour<1); }
   return false;
}
datetime GetLondonTime(datetime time)
{
   return AutoDST_GetSessionLocalTime(time, SESSION_ID_LONDON);
}

int GetLondonMinutes(datetime time)
{
   return AutoDST_GetSessionMinutes(time, SESSION_ID_LONDON);
}
string GetLocalClockText(){ datetime lt=TimeLocal(); MqlDateTime dt; TimeToStruct(lt,dt); return StringFormat("%02d:%02d:%02d LOCAL",dt.hour,dt.min,dt.sec); }
string TrimString(string s){ while(StringLen(s)>0 && StringGetChar(s,0)<=32) s=StringSubstr(s,1); while(StringLen(s)>0 && StringGetChar(s,StringLen(s)-1)<=32) s=StringSubstr(s,0,StringLen(s)-1); return s; }
double CalcSelectedOrderPips()
{
   double point=MarketInfo(OrderSymbol(),MODE_POINT); int digits=(int)MarketInfo(OrderSymbol(),MODE_DIGITS); if(point<=0)point=Point;
   double diff=MathAbs(OrderOpenPrice()-OrderClosePrice()); double pips=diff/point; if(digits==3||digits==5)pips/=10.0;
   bool profitDir=(OrderType()==OP_BUY)?(OrderClosePrice()>OrderOpenPrice()):(OrderClosePrice()<OrderOpenPrice());
   return profitDir?pips:-pips;
}

//====================================================================
// UI PRIMITIVES
//====================================================================
void CreatePremiumPanel(string id,int x,int y,int w,int h,color bg,color borderClr,color outerBg)
{
   string name=ui_prefix+id;
   ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,borderClr); ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_BACK,false);
   if(outerBg!=CLR_NONE)
   {
      string cs[4]; cs[0]=name+"_C1";cs[1]=name+"_C2";cs[2]=name+"_C3";cs[3]=name+"_C4";
      int cx[4]; int cy[4]; cx[0]=x;cy[0]=y; cx[1]=x+w-3;cy[1]=y; cx[2]=x;cy[2]=y+h-3; cx[3]=x+w-3;cy[3]=y+h-3;
      for(int k=0;k<4;k++){ ObjectCreate(0,cs[k],OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,cs[k],OBJPROP_XDISTANCE,cx[k]); ObjectSetInteger(0,cs[k],OBJPROP_YDISTANCE,cy[k]); ObjectSetInteger(0,cs[k],OBJPROP_XSIZE,3); ObjectSetInteger(0,cs[k],OBJPROP_YSIZE,3); ObjectSetInteger(0,cs[k],OBJPROP_BGCOLOR,outerBg); ObjectSetInteger(0,cs[k],OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,cs[k],OBJPROP_COLOR,outerBg); ObjectSetInteger(0,cs[k],OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,cs[k],OBJPROP_BACK,false); }
   }
}
void CreateCardMeter(string id,int x,int y,int w,int h)
{
   string bg=ui_prefix+id+"_MeterBG"; string fill=ui_prefix+id+"_MeterFill";
   ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,bg,OBJPROP_XSIZE,w); ObjectSetInteger(0,bg,OBJPROP_YSIZE,h); ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C_Meter_BG); ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,bg,OBJPROP_COLOR,C_Meter_BG); ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectCreate(0,fill,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,fill,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,fill,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,fill,OBJPROP_XSIZE,2); ObjectSetInteger(0,fill,OBJPROP_YSIZE,h); ObjectSetInteger(0,fill,OBJPROP_BGCOLOR,C_Accent_Neon); ObjectSetInteger(0,fill,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,fill,OBJPROP_COLOR,C_Accent_Neon); ObjectSetInteger(0,fill,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,fill,OBJPROP_BACK,false);
}
void UpdateCardMeter(string id,double percent,color fillColor)
{
   string bg=ui_prefix+id+"_MeterBG"; string fill=ui_prefix+id+"_MeterFill";
   if(ObjectFind(0,bg)<0||ObjectFind(0,fill)<0)return;
   percent=ClampValue(percent,0.0,100.0); int meterW=(int)ObjectGetInteger(0,bg,OBJPROP_XSIZE); int fillW=MathMax(2,(int)(meterW*percent/100.0));
   ObjectSetInteger(0,fill,OBJPROP_XSIZE,fillW); ObjectSetInteger(0,fill,OBJPROP_BGCOLOR,fillColor); ObjectSetInteger(0,fill,OBJPROP_COLOR,fillColor);
}
void CreatePremiumLabel(string id,string text,int x,int y,int size,string font,color clr,int anchor=ANCHOR_LEFT_UPPER)
{
   string name=ui_prefix+id; ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,font); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,name,OBJPROP_COLOR,clr); ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
}
void CreatePremiumButton(string id,string text,int x,int y,int w,int h,color bg)
{
   string name=ui_prefix+id; ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI Bold"); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,name,OBJPROP_COLOR,C_OnAccent_Text); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,bg); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_STATE,false);
}
void CreatePremiumCard(string id,string title,int x,int y,int w,int h,color bgClr,bool showMeter=true)
{
   CreatePremiumPanel(id+"_BG",x,y,w,h,bgClr,C_Border_Soft,C_BG_Dark);
   int titleY=(h>=52?y+4:y+2); int valueY=(h>=52?y+16:y+12);
   CreatePremiumLabel(id+"_Title",title,x+8,titleY,6,"Segoe UI Bold",C_Text_Secondary);
   CreatePremiumLabel(id+"_Value","---",x+8,valueY,9,"Segoe UI Bold",C_Text_Primary);
   if(showMeter) CreateCardMeter(id,x+8,y+h-4,w-16,2);
}
void CreatePremiumRingCard(string id,string title,int x,int y,int w,int h,color bgClr)
{
   CreatePremiumCard(id,title,x,y,w,h,bgClr,true);
   CreatePremiumLabel(id+"_Ring","O",x+w-15,y+4,6,"Segoe UI Bold",C_Accent_Neon);
}
datetime GetNextSessionOpenTime(ENUM_SESSION_ID sessionId)
{
   int startH, startM, dur, endH;
   AutoDST_GetFixedSessionConfig(sessionId, startH, startM, dur, endH);
   
   datetime now = TimeCurrent();
   MqlDateTime dt; TimeToStruct(now, dt);
   
   dt.hour = startH;
   dt.min = startM;
   dt.sec = 0;
   datetime sessionOpenToday = StructToTime(dt);
   
   int daysToAdd = 0;
   int dow = dt.day_of_week;
   
   if(dow == 6) // Saturday
      daysToAdd = 2;
   else if(dow == 0) // Sunday
      daysToAdd = 1;
   else if(now >= sessionOpenToday) // Weekday but already opened today
   {
      if(dow == 5) // Friday night
         daysToAdd = 3;
      else
         daysToAdd = 1;
   }
   
   datetime nextOpen = sessionOpenToday + daysToAdd * 86400;
   return nextOpen;
}

double Atan2(double y, double x)
{
   if(x > 0) return MathArctan(y/x);
   if(x < 0 && y >= 0) return MathArctan(y/x) + 3.14159265;
   if(x < 0 && y < 0) return MathArctan(y/x) - 3.14159265;
   if(x == 0 && y > 0) return 3.14159265 / 2.0;
   if(x == 0 && y < 0) return -3.14159265 / 2.0;
   return 0;
}

void DrawCircularProgress(string id, int x, int y, double percent, color clr_neon, string clockText, string countdownText, color countdownClr, string profitText, color profitClr)
{
   string obj_name = ui_prefix + id + "_Circle";
   string res_name = "::" + id + "_Bmp";
   int w = 180; int h = 150; // Increased height to prevent text overflows
   
   uint pixels[]; ArrayResize(pixels, w * h);
   ArrayInitialize(pixels, 0x00000000); // Transparent background
   
   int cx = w / 2; int cy = 42;
   double r = 32.0; double t = 5.0;
   double rad_min = r - t/2.0;
   double rad_max = r + t/2.0;
   
   uchar r_b = (uchar)(clr_neon & 0xFF);
   uchar g_b = (uchar)((clr_neon >> 8) & 0xFF);
   uchar b_b = (uchar)((clr_neon >> 16) & 0xFF);
   uint argb_neon = (0xFF << 24) | (r_b << 16) | (g_b << 8) | b_b;
   uint argb_bg = (0xFF << 24) | (35 << 16) | (40 << 8) | 55; // Dark grey ring background
   
   double limit_angle = (percent / 100.0) * 2.0 * 3.14159265;
   
   for(int py=0; py<h; py++)
   {
      for(int px=0; px<w; px++)
      {
         double dist = MathSqrt((px-cx)*(px-cx) + (py-cy)*(py-cy));
         if(dist >= rad_min && dist <= rad_max)
         {
            double angle = Atan2(px-cx, cy-py);
            if(angle < 0) angle += 2.0 * 3.14159265;
            
            int idx = py * w + px;
            if(angle <= limit_angle)
               pixels[idx] = argb_neon;
            else
               pixels[idx] = argb_bg;
         }
      }
   }
   
   ResourceCreate(res_name, pixels, w, h, 0, 0, 0, 1);
   
   if(ObjectFind(0, obj_name) < 0)
   {
      ObjectCreate(0, obj_name, OBJ_BITMAP_LABEL, 0, 0, 0);
      ObjectSetInteger(0, obj_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   }
   ObjectSetInteger(0, obj_name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, obj_name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, obj_name, OBJPROP_BMPFILE, res_name);
   
   // Draw Text in center of circle
   string t_clock = ui_prefix + id + "_TxtClock";
   if(ObjectFind(0, t_clock) < 0)
   {
      ObjectCreate(0, t_clock, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, t_clock, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, t_clock, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, t_clock, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, t_clock, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetInteger(0, t_clock, OBJPROP_XDISTANCE, x + cx);
   ObjectSetInteger(0, t_clock, OBJPROP_YDISTANCE, y + cy - 6);
   ObjectSetString(0, t_clock, OBJPROP_TEXT, clockText);
   ObjectSetInteger(0, t_clock, OBJPROP_COLOR, C_Text_Primary);
   
   // Draw LOCAL CLOCK under the clock inside the circle
   string t_status = ui_prefix + id + "_TxtStatus";
   if(ObjectFind(0, t_status) < 0)
   {
      ObjectCreate(0, t_status, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, t_status, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, t_status, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, t_status, OBJPROP_FONT, "Segoe UI");
      ObjectSetInteger(0, t_status, OBJPROP_FONTSIZE, 5);
   }
   ObjectSetInteger(0, t_status, OBJPROP_XDISTANCE, x + cx);
   ObjectSetInteger(0, t_status, OBJPROP_YDISTANCE, y + cy + 8);
   ObjectSetString(0, t_status, OBJPROP_TEXT, "LOCAL CLOCK");
   ObjectSetInteger(0, t_status, OBJPROP_COLOR, C_Text_Muted);
   
   // Draw Session Name underneath the Circle
   string t_session = ui_prefix + id + "_TxtSession";
   if(ObjectFind(0, t_session) < 0)
   {
      ObjectCreate(0, t_session, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, t_session, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, t_session, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, t_session, OBJPROP_FONT, "Segoe UI Black");
      ObjectSetInteger(0, t_session, OBJPROP_FONTSIZE, 8);
   }
   ObjectSetInteger(0, t_session, OBJPROP_XDISTANCE, x + cx);
   ObjectSetInteger(0, t_session, OBJPROP_YDISTANCE, y + cy + 42);
   ObjectSetString(0, t_session, OBJPROP_TEXT, id == "Lon" ? "LONDON SESSION" : "NY SESSION");
   ObjectSetInteger(0, t_session, OBJPROP_COLOR, clr_neon);
   
   // Draw profit text underneath Session Name
   string t_profit = ui_prefix + id + "_TxtProfit";
   if(ObjectFind(0, t_profit) < 0)
   {
      ObjectCreate(0, t_profit, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, t_profit, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, t_profit, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, t_profit, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, t_profit, OBJPROP_FONTSIZE, 7);
   }
   ObjectSetInteger(0, t_profit, OBJPROP_XDISTANCE, x + cx);
   ObjectSetInteger(0, t_profit, OBJPROP_YDISTANCE, y + cy + 56);
   ObjectSetString(0, t_profit, OBJPROP_TEXT, profitText);
   ObjectSetInteger(0, t_profit, OBJPROP_COLOR, profitClr);

   // Draw countdown text UNDER the Profit text (المطلب الجديد)
   string t_countdown = ui_prefix + id + "_TxtCountdown";
   if(ObjectFind(0, t_countdown) < 0)
   {
      ObjectCreate(0, t_countdown, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, t_countdown, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, t_countdown, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetString(0, t_countdown, OBJPROP_FONT, "Segoe UI Bold");
      ObjectSetInteger(0, t_countdown, OBJPROP_FONTSIZE, 7);
   }
   ObjectSetInteger(0, t_countdown, OBJPROP_XDISTANCE, x + cx);
   ObjectSetInteger(0, t_countdown, OBJPROP_YDISTANCE, y + cy + 70);
   ObjectSetString(0, t_countdown, OBJPROP_TEXT, countdownText);
   ObjectSetInteger(0, t_countdown, OBJPROP_COLOR, countdownClr);
}
void CreatePremiumUI()
{
   int startX=UI_PosX; int startY=UI_PosY; int mainW=580; int mainH=UI_Collapsed?34:520;
   color chartBg=(color)ChartGetInteger(0,CHART_COLOR_BACKGROUND);
   CreatePremiumPanel("MainShell",startX,startY,mainW,mainH,C_BG_Dark,C_Border_Soft,chartBg);
   CreatePremiumPanel("HeaderBar",startX+1,startY+1,mainW-2,28,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   ObjectCreate(0,ui_prefix+"TopGlow",OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_XDISTANCE,startX+1); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_YDISTANCE,startY+1); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_XSIZE,mainW-2); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_YSIZE,2); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_BGCOLOR,C_Accent_Neon); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_COLOR,C_Accent_Neon); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,ui_prefix+"TopGlow",OBJPROP_BACK,false);
   int y=startY+5; int leftX=startX+10;
   CreatePremiumLabel("Title","LONDON ORB SESSION DZ TRADER ",leftX,y,8,"Segoe UI Black",C_Header_Title);
   CreatePremiumLabel("Subtitle","AIT CHIKH MUSTAPHA",leftX,y+13,8,"Segoe UI Black",C_Accent_Neon);
   if(UI_ShowHeaderInfo)
   {
      CreatePremiumLabel("HdrSymbol",Symbol()+" | "+TFToString(Period()),leftX+200,y+1,8,"Segoe UI Black",C_Text_Secondary);
      CreatePremiumLabel("HdrMode","TACTICAL VIEW // PREMIUM CORE",leftX+200,y+13,8,"Segoe UI Black",C_Accent_Neon);
   }
   
   // Create Currency Switcher + EA Toggle + Panel Minimize
   CreatePremiumButton("ToggleCurr",DisplayDZD?"DZD":"USD",startX+mainW-125,y+1,40,20,C_Save_BG);
   CreatePremiumButton("ToggleEA",EA_Enabled?"ON":"OFF",startX+mainW-80,y+1,40,20,EA_Enabled?C_Success_Glow:C_Danger_Glow);
   CreatePremiumButton("TogglePanel",UI_Collapsed?"+":"-",startX+mainW-35,y+1,20,20,C_Card_Dark);

   // Interactive Panel Buttons for Weekdays (المطلب الثاني - إنشاء الأزرار رسومياً عبر العرض الكامل)
   if(!UI_Collapsed)
   {
      int btnW = 100; int btnH = 20; int btnGap = 11;
      int btnStartX = startX + 15;
      int btnY = startY + mainH - 45; // Just above the footer inside the MainShell
      
      color monBg = g_trade_day_mon ? clrGreen : clrRed;
      color tueBg = g_trade_day_tue ? clrGreen : clrRed;
      color wedBg = g_trade_day_wed ? clrGreen : clrRed;
      color thuBg = g_trade_day_thu ? clrGreen : clrRed;
      color friBg = g_trade_day_fri ? clrGreen : clrRed;

      CreatePremiumButton("BtnMon", g_trade_day_mon ? "MON: ON" : "MON: OFF", btnStartX, btnY, btnW, btnH, monBg);
      CreatePremiumButton("BtnTue", g_trade_day_tue ? "TUE: ON" : "TUE: OFF", btnStartX + (btnW + btnGap), btnY, btnW, btnH, tueBg);
      CreatePremiumButton("BtnWed", g_trade_day_wed ? "WED: ON" : "WED: OFF", btnStartX + 2*(btnW + btnGap), btnY, btnW, btnH, wedBg);
      CreatePremiumButton("BtnThu", g_trade_day_thu ? "THU: ON" : "THU: OFF", btnStartX + 3*(btnW + btnGap), btnY, btnW, btnH, thuBg);
      CreatePremiumButton("BtnFri", g_trade_day_fri ? "FRI: ON" : "FRI: OFF", btnStartX + 4*(btnW + btnGap), btnY, btnW, btnH, friBg);
   }
   
   if(UI_Collapsed){ ChartRedraw(0); return; }
   int zoneY=startY+40; int colW=180; int halfW=86; int centerX=startX+198; int rightX=startX+386;
   
   // London & NY Separate Circular Status Clocks (تصميم نيون دائري احترافي)
   DrawCircularProgress("Lon", leftX, zoneY, 100.0, C_Accent_Neon, "---", "WAITING", C_Info_Glow, "P/L: $0.00", C_Success_Glow);
   DrawCircularProgress("Ny", leftX, zoneY+145, 100.0, C_Accent_Neon, "---", "WAITING", C_Danger_Glow, "P/L: $0.00", C_Success_Glow);
   
   // NEWS RADAR is cleanly placed at the bottom of Column 1
   CreatePremiumRingCard("HighNews","NEWS RADAR",leftX,zoneY+290,colW,34,C_Card_Dark);

   // ================= COLUMN 2 (CENTER) =================
   CreatePremiumCard("PLToday","NET PROFIT",centerX,zoneY,colW,52,C_Card_Dark,true);
   CreatePremiumLabel("PLWon_Placeholder","WON:",centerX+10,zoneY+32,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("PLWon_Value","+$0.00",centerX+34,zoneY+32,6,"Segoe UI Bold",C_Success_Glow);
   CreatePremiumLabel("PLLoss_Placeholder","LOST:",centerX+95,zoneY+32,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("PLLoss_Value","-$0.00",centerX+122,zoneY+32,6,"Segoe UI Bold",C_Danger_Glow);
   CreatePremiumLabel("GrossProfit_Value","+$0.00",centerX+34,zoneY+32,6,"Segoe UI Bold",C_Success_Glow);
   CreatePremiumLabel("GrossLoss_Value","-$0.00",centerX+122,zoneY+32,6,"Segoe UI Bold",C_Danger_Glow);
   CreatePremiumCard("PLActive","ACTIVE P/L",centerX,zoneY+58,colW,52,C_Card_Dark,true);
   CreatePremiumPanel("ORB_Matrix_BG",centerX,zoneY+116,colW,72,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   CreatePremiumLabel("ORB_Matrix_Title","ORB MATRIX",centerX+10,zoneY+116+4,6,"Segoe UI Bold",C_Text_Secondary);
   CreatePremiumLabel("ORB_High_Label","ORB HIGH",centerX+10,zoneY+116+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("ORBHigh_Value","---",centerX+10,zoneY+116+23,8,"Segoe UI Black",C_Text_Primary);
   CreatePremiumLabel("ORB_Low_Label","ORB LOW",centerX+95,zoneY+116+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("ORBLow_Value","---",centerX+95,zoneY+116+23,8,"Segoe UI Black",C_Text_Primary);
   CreatePremiumLabel("ORB_Range_Label","ORB RANGE",centerX+10,zoneY+116+40,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("ORBRange_Value","---",centerX+10,zoneY+116+48,8,"Segoe UI Black",C_Accent_Neon);
   string trackName=ui_prefix+"ORB_PriceTrack"; ObjectCreate(0,trackName,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,trackName,OBJPROP_XDISTANCE,centerX+10); ObjectSetInteger(0,trackName,OBJPROP_YDISTANCE,zoneY+116+62); ObjectSetInteger(0,trackName,OBJPROP_XSIZE,160); ObjectSetInteger(0,trackName,OBJPROP_YSIZE,2); ObjectSetInteger(0,trackName,OBJPROP_BGCOLOR,C_Meter_BG); ObjectSetInteger(0,trackName,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,trackName,OBJPROP_COLOR,C_Meter_BG); ObjectSetInteger(0,trackName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   string pointerName=ui_prefix+"ORB_PricePointer"; ObjectCreate(0,pointerName,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,pointerName,OBJPROP_XDISTANCE,centerX+10); ObjectSetInteger(0,pointerName,OBJPROP_YDISTANCE,zoneY+116+60); ObjectSetInteger(0,pointerName,OBJPROP_XSIZE,3); ObjectSetInteger(0,pointerName,OBJPROP_YSIZE,6); ObjectSetInteger(0,pointerName,OBJPROP_BGCOLOR,C_Accent_Neon); ObjectSetInteger(0,pointerName,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,pointerName,OBJPROP_COLOR,C_Accent_Neon); ObjectSetInteger(0,pointerName,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   CreatePremiumCard("TrendStatus","TREND FILTER",centerX,zoneY+194,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("TotalPipsC","TOTAL PIPS",centerX+94,zoneY+194,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("BestTrade","BEST TRADE",centerX,zoneY+234,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("WorstTrade","WORST TRADE",centerX+94,zoneY+234,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("LongsCard","LONGS",centerX,zoneY+274,halfW,34,C_Card_Dark,true);
   CreatePremiumCard("ShortsCard","SHORTS",centerX+94,zoneY+274,halfW,34,C_Card_Dark,true);
   CreatePremiumRingCard("WinRate","WIN RATE",centerX,zoneY+314,halfW,34,C_Card_Dark);
   CreatePremiumRingCard("ProfitFactor","PROFIT FACTOR",centerX+94,zoneY+314,halfW,34,C_Card_Dark);
   CreatePremiumCard("TotalTrades","TOTAL TRADES",centerX,zoneY+354,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("DaysTraded","DAYS TRADED",centerX+94,zoneY+354,halfW,34,C_Card_Dark,false);

   // ================= COLUMN 3 (RIGHT) =================
   CreatePremiumPanel("AccountEquity_BG",rightX,zoneY,colW,52,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   CreatePremiumLabel("AccountEquity_Title","ACCOUNT EQUITY",rightX+10,zoneY+4,6,"Segoe UI Bold",C_Text_Secondary);
   CreatePremiumLabel("Balance_Lbl","BALANCE",rightX+10,zoneY+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("Balance_Value","---",rightX+10,zoneY+23,8,"Segoe UI Black",C_Text_Primary);
   CreatePremiumLabel("Equity_Lbl","EQUITY",rightX+95,zoneY+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("Equity_Value","---",rightX+95,zoneY+23,8,"Segoe UI Black",C_Text_Primary);
   CreatePremiumPanel("MarginStatus_BG",rightX,zoneY+58,colW,52,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   CreatePremiumLabel("MarginStatus_Title","MARGIN STATUS",rightX+10,zoneY+58+4,6,"Segoe UI Bold",C_Text_Secondary);
   CreatePremiumLabel("FreeMargin_Lbl","FREE MARGIN",rightX+10,zoneY+58+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("FreeMargin_Value","---",rightX+10,zoneY+58+23,8,"Segoe UI Black",C_Text_Primary);
   CreatePremiumLabel("MarginLevel_Lbl","MARGIN LEVEL",rightX+95,zoneY+58+15,5,"Segoe UI Bold",C_Text_Muted);
   CreatePremiumLabel("SpreadVal_Value","---",rightX+95,zoneY+58+23,8,"Segoe UI Black",C_Text_Primary);
   CreateCardMeter("SpreadVal",rightX+8,zoneY+58+52-4,colW-16,2);
   CreatePremiumRingCard("PipValCard","DAILY GOAL PROGRESS",rightX,zoneY+116,colW,34,C_Card_Dark);
   CreatePremiumCard("NextLot","LOT SIZE",rightX,zoneY+156,halfW,34,C_Card_Dark,true);
   CreatePremiumCard("Spread","SPREAD",rightX+94,zoneY+156,halfW,34,C_Card_Dark,true);
   CreatePremiumPanel("SLPoints_BG",rightX,zoneY+196,halfW,34,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   CreatePremiumLabel("SLPoints_Title","SL & TARGET RR",rightX+8,zoneY+196+4,5,"Segoe UI Bold",C_Text_Secondary);
   CreatePremiumLabel("SLPoints_Value","---",rightX+8,zoneY+196+12,7,"Segoe UI Black",C_Warning_Glow);
   CreatePremiumLabel("TP1Card_Value","TP1: --",rightX+8,zoneY+196+23,5,"Segoe UI Bold",C_Success_Glow);
   CreatePremiumLabel("TP2Card_Value","TP2: --",rightX+44,zoneY+196+23,5,"Segoe UI Bold",C_Info_Glow);
   CreatePremiumCard("MaxLossCard","MAX LOSS",rightX+94,zoneY+196,halfW,34,C_Card_Dark,false);
   CreatePremiumCard("MaxDD","MAX DRAWDOWN",rightX,zoneY+236,halfW,34,C_Card_Dark,true);
   CreatePremiumCard("ExpectCard","EXPECTANCY",rightX+94,zoneY+236,halfW,34,C_Card_Dark,false);
   CreatePremiumRingCard("RecoveryFactor","RECOVERY FACTOR",rightX,zoneY+276,colW,34,C_Card_Dark); // RecoveryFactor stretched full width, SESSION TIMER card deleted
   CreatePremiumRingCard("RatioCard","BUY TRIGGER",rightX,zoneY+316,halfW,34,C_Card_Dark);
   CreatePremiumRingCard("ShortRatio","SELL TRIGGER",rightX+94,zoneY+316,halfW,34,C_Card_Dark);
   CreatePremiumCard("AvgWinC","AVG WIN",rightX,zoneY+356,halfW,34,C_Card_Dark,false); // AvgWin/AvgLoss beautifully moved under Buy/Sell triggers!
   CreatePremiumCard("AvgLossC","AVG LOSS",rightX+94,zoneY+356,halfW,34,C_Card_Dark,false);
   
   
   CreatePremiumPanel("FooterBG",startX+10,startY+mainH-20,mainW-20,14,C_Card_Dark,C_Border_Soft,C_BG_Dark);
   CreatePremiumLabel("TimeInfo","-- LON | READY",startX+mainW/2,startY+mainH-18,6,"Segoe UI Bold",C_Text_Muted,ANCHOR_UPPER);
   ChartRedraw(0);
}
void UpdatePremiumUI()
{
   if(!ShowModernPanel) return;
   
   int leftX = UI_PosX + 10;
   int zoneY = UI_PosY + 40;

   datetime nowServer = TimeCurrent();
   ENUM_SESSION_ID uiSession = AutoDST_GetDisplaySessionId(nowServer, OrbTradeMode);
   int uiStartHour, uiStartMinute, uiDurationMinutes, uiEndHour;
   AutoDST_GetFixedSessionConfig(uiSession, uiStartHour, uiStartMinute, uiDurationMinutes, uiEndHour);

   int curMin = AutoDST_GetSessionMinutes(nowServer, uiSession);
   int startMinCur = uiStartHour * 60 + uiStartMinute;
   int endMinCur   = startMinCur + uiDurationMinutes;
   int closeMinCur = uiEndHour * 60;
   
   // ------------------ LONDON SESSION STATUS & COUNTDOWN ------------------
   int lonStartH, lonStartM, lonDur, lonEndH;
   AutoDST_GetFixedSessionConfig(SESSION_ID_LONDON, lonStartH, lonStartM, lonDur, lonEndH);
   int lonCurMin = AutoDST_GetSessionMinutes(nowServer, SESSION_ID_LONDON);
   int lonStartMin = lonStartH * 60 + lonStartM;
   int lonEndMin   = lonStartMin + lonDur;
   int lonCloseMin = lonEndH * 60;
   
   bool isWeekend = false;
   MqlDateTime srvDt; TimeToStruct(nowServer, srvDt);
   if(srvDt.day_of_week == 6 || (srvDt.day_of_week == 5 && srvDt.hour >= 21) || (srvDt.day_of_week == 0 && srvDt.hour < 22)) isWeekend = true;

   string lonStatus = "WAITING"; color lonColor = C_Text_Secondary;
   double lonProgressPercent = 0.0;
   string lonSubText = "REMAINING";
   if(isWeekend)
   {
      lonStatus = "WAITING";
      long lonSecs = GetNextSessionOpenTime(SESSION_ID_LONDON) - nowServer;
      lonSubText = "OPENS IN " + FormatClock((int)lonSecs);
      lonProgressPercent = 100.0;
   }
   else if(lonCurMin < lonStartMin)
   {
      lonStatus = "WAITING";
      lonSubText = "OPENS IN " + FormatClock((lonStartMin - lonCurMin)*60);
      lonProgressPercent = 100.0;
   }
   else if(lonCurMin >= lonStartMin && lonCurMin < lonEndMin)
   {
      lonStatus = "ORB";
      lonSubText = "ORB END " + FormatClock((lonEndMin - lonCurMin)*60);
      lonColor = C_Warning_Glow;
      lonProgressPercent = 100.0 - (((double)(lonCurMin - lonStartMin) / (double)lonDur) * 100.0);
   }
   else if(lonCurMin >= lonEndMin && lonCurMin < lonCloseMin)
   {
      lonStatus = "ACTIVE";
      lonSubText = "CLOSE IN " + FormatClock((lonCloseMin - lonCurMin)*60);
      lonColor = C_Success_Glow;
      lonProgressPercent = 100.0 - (((double)(lonCurMin - lonEndMin) / (double)(lonCloseMin - lonEndMin)) * 100.0);
   }
   else
   {
      lonStatus = "CLOSED";
      lonSubText = "CLOSED";
      lonColor = C_Danger_Glow;
      lonProgressPercent = 0.0;
   }
   
   // London Broker/Server Time
   string lonClockTime = TimeToString(AutoDST_GetSessionLocalTime(nowServer, SESSION_ID_LONDON), TIME_SECONDS);
   if(!UI_Collapsed) DrawCircularProgress("Lon", leftX, zoneY, lonProgressPercent, lonColor, lonClockTime, lonSubText, C_Info_Glow, "P/L: " + FormatMoney(cachedDailyPL_Lon), cachedDailyPL_Lon >= 0 ? C_Success_Glow : C_Danger_Glow);

   // ------------------ NEW YORK SESSION STATUS & COUNTDOWN ------------------
   int nyStartH, nyStartM, nyDur, nyEndH;
   AutoDST_GetFixedSessionConfig(SESSION_ID_NEWYORK, nyStartH, nyStartM, nyDur, nyEndH);
   int nyCurMin = AutoDST_GetSessionMinutes(nowServer, SESSION_ID_NEWYORK);
   int nyStartMin = nyStartH * 60 + nyStartM;
   int nyEndMin   = nyStartMin + nyDur;
   int nyCloseMin = nyEndH * 60;
   
   string nyStatus = "WAITING"; color nyColor = C_Text_Secondary;
   double nyProgressPercent = 0.0;
   string nySubText = "REMAINING";
   if(isWeekend)
   {
      nyStatus = "WAITING";
      long nySecs = GetNextSessionOpenTime(SESSION_ID_NEWYORK) - nowServer;
      nySubText = "OPENS IN " + FormatClock((int)nySecs);
      nyProgressPercent = 100.0;
   }
   else if(nyCurMin < nyStartMin)
   {
      nyStatus = "WAITING";
      nySubText = "OPENS IN " + FormatClock((nyStartMin - nyCurMin)*60);
      nyProgressPercent = 100.0;
   }
   else if(nyCurMin >= nyStartMin && nyCurMin < nyEndMin)
   {
      nyStatus = "ORB";
      nySubText = "ORB END " + FormatClock((nyEndMin - nyCurMin)*60);
      nyColor = C_Warning_Glow;
      nyProgressPercent = 100.0 - (((double)(nyCurMin - nyStartMin) / (double)nyDur) * 100.0);
   }
   else if(nyCurMin >= nyEndMin && nyCurMin < nyCloseMin)
   {
      nyStatus = "ACTIVE";
      nySubText = "CLOSE IN " + FormatClock((nyCloseMin - nyCurMin)*60);
      nyColor = C_Success_Glow;
      nyProgressPercent = 100.0 - (((double)(nyCurMin - nyEndMin) / (double)(nyCloseMin - nyEndMin)) * 100.0);
   }
   else
   {
      nyStatus = "CLOSED";
      nySubText = "CLOSED";
      nyColor = C_Danger_Glow;
      nyProgressPercent = 0.0;
   }
   
   // NY Broker/Server Time
   string nyClockTime = TimeToString(AutoDST_GetSessionLocalTime(nowServer, SESSION_ID_NEWYORK), TIME_SECONDS);
   if(!UI_Collapsed) DrawCircularProgress("Ny", leftX, zoneY+130, nyProgressPercent, nyColor, nyClockTime, nySubText, C_Danger_Glow, "P/L: " + FormatMoney(cachedDailyPL_NY), cachedDailyPL_NY >= 0 ? C_Success_Glow : C_Danger_Glow);
   datetime lonTime=GetLondonTime(TimeCurrent()); MqlDateTime londt; TimeToStruct(lonTime,londt);
   string months[]={"","JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"};
   string timeStr=StringFormat("%02d %s %02d:%02d LON",londt.day,months[londt.mon],londt.hour,londt.min);
   
   
   // Update Currency switcher display
   string currText=DisplayDZD?"DZD":"USD";
   ObjectSetString(0,ui_prefix+"ToggleCurr",OBJPROP_TEXT,currText);
   ObjectSetInteger(0,ui_prefix+"ToggleCurr",OBJPROP_BGCOLOR,C_Save_BG);
   ObjectSetInteger(0,ui_prefix+"ToggleCurr",OBJPROP_COLOR,C_OnAccent_Text);
   string eaText=EA_Enabled?"ON":"OFF"; color eaColor=EA_Enabled?C_Success_Glow:C_Danger_Glow;
   ObjectSetString(0,ui_prefix+"ToggleEA",OBJPROP_TEXT,eaText); ObjectSetInteger(0,ui_prefix+"ToggleEA",OBJPROP_BGCOLOR,eaColor); ObjectSetInteger(0,ui_prefix+"ToggleEA",OBJPROP_COLOR,C_OnAccent_Text);
   ObjectSetString(0,ui_prefix+"TogglePanel",OBJPROP_TEXT,UI_Collapsed?"+":"-");
   if(UI_ShowHeaderInfo)
   {
      UpdateLabel("HdrSymbol",Symbol()+" | "+TFToString(Period())+" | "+GetSessionCountdownText(),C_Text_Secondary);
      UpdateLabel("HdrMode",(GlobalHistory?"GLOBAL":"EA")+" | BAL "+FormatMoneyAbs(AccountBalance())+" | EQ "+FormatMoneyAbs(AccountEquity()),C_Accent_Neon);
   }
   if(!UI_Collapsed)
   {
      double plTotal=cachedNetProfit;
      UpdateCardValue("PLToday",FormatMoney(plTotal),plTotal>=0?C_Success_Glow:C_Danger_Glow);
      UpdateCardMeter("PLToday",ClampValue(MathAbs(plTotal)/MathMax(1.0,CompoundingStepProfit)*100.0,0.0,100.0),plTotal>=0?C_Success_Glow:C_Danger_Glow);
      double plActive=GetActiveProfit();
      UpdateCardValue("PLActive",FormatMoney(plActive),plActive>=0?C_Success_Glow:C_Danger_Glow);
      UpdateCardMeter("PLActive",ClampValue(MathAbs(plActive)/MathMax(1.0,MaxLossUSD)*100.0,0.0,100.0),plActive>=0?C_Success_Glow:C_Danger_Glow);
      UpdateCardValue("Balance",FormatMoneyAbs(AccountBalance()),C_Text_Primary);
      double equity=AccountEquity();
      UpdateCardValue("Equity",FormatMoneyAbs(equity),equity>=AccountBalance()?C_Success_Glow:C_Danger_Glow);
      UpdateCardValue("FreeMargin",FormatMoneyAbs(AccountFreeMargin()),C_Text_Primary);
      double nextLot=CalculateLotSize(FixedSL_Points); if(nextLot<=0)nextLot=LotSize;
      UpdateCardValue("NextLot",DoubleToString(nextLot,2),C_Warning_Glow);
      double maxLot=MarketInfo(Symbol(),MODE_MAXLOT); if(maxLot>0) UpdateCardMeter("NextLot",ClampValue(nextLot/maxLot*100.0,0.0,100.0),C_Warning_Glow);
      int spread=(int)MarketInfo(Symbol(),MODE_SPREAD); color spreadColor=C_Success_Glow;
      if(spread>MaxSpreadFilter) spreadColor=C_Danger_Glow; else if(spread>MaxSpreadFilter/2) spreadColor=C_Warning_Glow;
      string spreadStr=IntegerToString(spread)+" pts"; if(UseSpreadFilter && spread>MaxSpreadFilter) spreadStr+=" [BLOCKED]";
      UpdateCardValue("Spread",spreadStr,spreadColor); UpdateCardMeter("Spread",(MaxSpreadFilter>0?(spread*100.0/MaxSpreadFilter):0),spreadColor);
      double dispHi=0, dispLo=0; string orbLbl="ORB MATRIX";
      if(OrbTradeMode == MODE_NY_ONLY)
      {
         dispHi=nyOrbHigh; dispLo=nyOrbLow; orbLbl="ORB MATRIX (NY)";
      }
      else if(OrbTradeMode == MODE_LONDON_ONLY)
      {
         dispHi=lonOrbHigh; dispLo=lonOrbLow; orbLbl="ORB MATRIX (LON)";
      }
      else
      {
         ENUM_SESSION_ID matrixSession = AutoDST_GetDisplaySessionId(nowServer, OrbTradeMode);
         if(matrixSession == SESSION_ID_NEWYORK && nyOrbHigh > 0 && nyOrbLow > 0)
         {
            dispHi=nyOrbHigh; dispLo=nyOrbLow; orbLbl="ORB MATRIX (NY)";
         }
         else
         {
            dispHi=lonOrbHigh; dispLo=lonOrbLow; orbLbl="ORB MATRIX (LON)";
         }
      }
      ObjectSetString(0,ui_prefix+"ORB_Matrix_Title",OBJPROP_TEXT,orbLbl);
      
      if(dispHi>0 && dispLo>0)
      {
         double range=(dispHi-dispLo)/Point;
         UpdateCardValue("ORBRange",DoubleToString(range,0)+" points",C_Accent_Neon);
         UpdateCardValue("ORBHigh",DoubleToString(dispHi,Digits),C_Text_Primary);
         UpdateCardValue("ORBLow",DoubleToString(dispLo,Digits),C_Text_Primary);
         int centerX=UI_PosX+198; int matrix_zoneY=UI_PosY+34; UpdateORBPricePointer(Bid,dispLo,dispHi,centerX,matrix_zoneY+116,180);
      }
      else { UpdateCardValue("ORBRange","Not Available",C_Text_Muted); UpdateCardValue("ORBHigh","---",C_Text_Muted); UpdateCardValue("ORBLow","---",C_Text_Muted); ObjectSetInteger(0,ui_prefix+"ORB_PricePointer",OBJPROP_XSIZE,0); }
      UpdateCardValue("WinRate",DoubleToString(cachedWinRate,1)+"%",cachedWinRate>=60?C_Success_Glow:(cachedWinRate>=40?C_Warning_Glow:C_Danger_Glow));
      UpdateCardValue("ProfitFactor",DoubleToString(cachedPF,2),cachedPF>=1.5?C_Success_Glow:(cachedPF>=1.0?C_Warning_Glow:C_Danger_Glow));
      UpdateCardMeter("WinRate",cachedWinRate,cachedWinRate>=60?C_Success_Glow:(cachedWinRate>=40?C_Warning_Glow:C_Danger_Glow));
      UpdateCardMeter("ProfitFactor",ClampValue(cachedPF*50.0,0.0,100.0),cachedPF>=1.5?C_Success_Glow:(cachedPF>=1.0?C_Warning_Glow:C_Danger_Glow));
      int totalTrades=cachedWins+cachedLosses;
      UpdateCardValue("TotalTrades",IntegerToString(totalTrades)+" | "+IntegerToString(cachedWins)+"W/"+IntegerToString(cachedLosses)+"L",C_Text_Primary);
      string trend="DISABLED"; color trendColor=C_Text_Muted;
      if(UseTrendFilter){ double ma=iMA(NULL,0,MA_Period,0,MA_Method,PRICE_CLOSE,1); if(Close[1]>ma){trend="BULLISH +";trendColor=C_Success_Glow;} else {trend="BEARISH -";trendColor=C_Danger_Glow;} }
      UpdateCardValue("TrendStatus",trend,trendColor);
      UpdateCardValue("PLWon",FormatMoney(MathAbs(cachedGrossProfit)),C_Success_Glow);
      UpdateCardValue("PLLoss",FormatMoney(-MathAbs(cachedGrossLoss)),C_Danger_Glow);
      UpdateCardValue("GrossProfit",FormatMoney(MathAbs(cachedGrossProfit)),C_Success_Glow);
      UpdateCardValue("GrossLoss",FormatMoney(-MathAbs(cachedGrossLoss)),C_Danger_Glow);
      UpdateCardValue("RecoveryFactor",DoubleToString(cachedRF,2),cachedRF>=2.0?C_Success_Glow:(cachedRF>=1.0?C_Warning_Glow:C_Danger_Glow));
      UpdateCardValue("DaysTraded",IntegerToString(cachedDaysTraded)+" d",C_Text_Primary);
      UpdateCardValue("MaxDD",FormatMoney(-MathAbs(cachedMaxDD)),C_Danger_Glow);
      UpdateCardMeter("MaxDD",ClampValue((AccountBalance()>0?cachedMaxDD/AccountBalance()*500.0:0.0),0.0,100.0),C_Danger_Glow);
      // Leverage / Session Timer card updates completely removed as requested
      UpdateCardValue("MaxLossCard",FormatMoneyAbs(MaxLossUSD),C_Danger_Glow);
      UpdateCardValue("SLPoints",IntegerToString(FixedSL_Points)+" pts",C_Warning_Glow);
      UpdateCardValue("TP1Card","1:"+DoubleToString(TP1_RR,1),C_Success_Glow);
      UpdateCardValue("TP2Card","1:"+DoubleToString(TP2_RR,1),C_Info_Glow);
      
      
      double margin=AccountMargin(); double marginLevel=(margin>0)?(AccountEquity()/margin)*100.0:0.0;
      color marginClr=marginLevel>=300?C_Success_Glow:(marginLevel>=150?C_Warning_Glow:C_Danger_Glow);
      UpdateCardValue("SpreadVal",(margin>0?DoubleToString(marginLevel,0)+"%":"0%"),marginClr); UpdateCardMeter("SpreadVal",ClampValue(marginLevel/5.0,0.0,100.0),marginClr);
      double dailyPct=(DailyTargetUSD>0)?(cachedDailyPL/DailyTargetUSD)*100.0:0.0; color goalClr=cachedDailyPL>=0?C_Success_Glow:C_Danger_Glow;
      UpdateCardValue("PipValCard",FormatMoney(cachedDailyPL),goalClr); UpdateCardMeter("PipValCard",ClampValue(MathAbs(dailyPct),0.0,100.0),goalClr);
      color bestClr=cachedBestTrade>=0?C_Success_Glow:C_Danger_Glow; color worstClr=cachedWorstTrade>=0?C_Success_Glow:C_Danger_Glow;
      UpdateCardValue("BestTrade",FormatMoney(cachedBestTrade),bestClr); UpdateCardValue("WorstTrade",FormatMoney(cachedWorstTrade),worstClr);
      UpdateCardValue("TotalPipsC",DoubleToString(cachedTotalPips,1)+" pips",cachedTotalPips>=0?C_Success_Glow:C_Danger_Glow);
      UpdateCardValue("ExpectCard",FormatMoney(cachedExpectancy)+"/tr",cachedExpectancy>=0?C_Success_Glow:C_Danger_Glow);
      UpdateCardValue("AvgWinC",FormatMoney(MathAbs(cachedAvgWin)),C_Success_Glow);
      UpdateCardValue("AvgLossC",FormatMoney(-MathAbs(cachedAvgLoss)),C_Danger_Glow);
      int totalTr2=cachedLongs+cachedShorts;
      UpdateCardValue("LongsCard",IntegerToString(cachedLongs)+" trades",C_Info_Glow);
      UpdateCardValue("ShortsCard",IntegerToString(cachedShorts)+" trades",C_Danger_Glow);
      UpdateCardMeter("LongsCard",totalTr2>0?cachedLongs*100.0/totalTr2:0,C_Info_Glow);
      UpdateCardMeter("ShortsCard",totalTr2>0?cachedShorts*100.0/totalTr2:0,C_Danger_Glow);
      double buyDistPts=0.0,sellDistPts=0.0,orbRangePts=1.0;
      if(dispHi>0 && dispLo>0){ double bbp=dispHi+BreakoutPadding*Point; double sbp=dispLo-BreakoutPadding*Point; buyDistPts=(bbp-Ask)/Point; sellDistPts=(Bid-sbp)/Point; orbRangePts=MathMax(1.0,(dispHi-dispLo)/Point); }
      string buyTxt=(dispHi>0?(buyDistPts<=0?"READY":DoubleToString(buyDistPts,0)+" pts"):"---");
      string sellTxt=(dispLo>0?(sellDistPts<=0?"READY":DoubleToString(sellDistPts,0)+" pts"):"---");
      UpdateCardValue("RatioCard",buyTxt,dispHi>0 && buyDistPts<=0?C_Success_Glow:C_Info_Glow);
      UpdateCardValue("ShortRatio",sellTxt,dispLo>0 && sellDistPts<=0?C_Success_Glow:C_Danger_Glow);
      double buyProx=(dispHi>0?(buyDistPts<=0?100.0:ClampValue(100.0-(buyDistPts/orbRangePts)*100.0,0.0,100.0)):0.0);
      double sellProx=(dispLo>0?(sellDistPts<=0?100.0:ClampValue(100.0-(sellDistPts/orbRangePts)*100.0,0.0,100.0)):0.0);
      UpdateCardMeter("RatioCard",buyProx,C_Info_Glow); UpdateCardMeter("ShortRatio",sellProx,C_Danger_Glow);
      string newsStr="No News Found"; color newsColor=C_Text_Muted; double newsMeter=0; datetime nextNews=0; string currency="";
      if(GetNextHighNews(nextNews,currency))
      {
         datetime lonNewsTime=GetLondonTime(nextNews); MqlDateTime ndt; TimeToStruct(lonNewsTime,ndt);
         newsStr=StringFormat("%s News: %02d %s %02d:%02d LON",currency,ndt.day,months[ndt.mon],ndt.hour,ndt.min);
         long minsToNews=(nextNews-TimeCurrent())/60;
         if(minsToNews>0 && minsToNews<=60) newsColor=C_Warning_Glow;
         else if(minsToNews<=0 && minsToNews>-30){ newsStr=currency+" News ACTIVE"; newsColor=C_Info_Glow; }
         newsMeter=(minsToNews>0 && minsToNews<=180)?ClampValue(100.0-minsToNews*100.0/180.0,0.0,100.0):(minsToNews<=0 && minsToNews>-30?100:0);
      }
      UpdateCardValue("HighNews",newsStr,newsColor); UpdateCardMeter("HighNews",newsMeter,newsColor);
      // Update Weekdays Button Text and Colors (المطلب الثاني - تحديث الحالات والألوان)
      ObjectSetString(0, ui_prefix + "BtnMon", OBJPROP_TEXT, g_trade_day_mon ? "MON: ON" : "MON: OFF");
      ObjectSetInteger(0, ui_prefix + "BtnMon", OBJPROP_BGCOLOR, g_trade_day_mon ? clrGreen : clrRed);
      ObjectSetInteger(0, ui_prefix + "BtnMon", OBJPROP_BORDER_COLOR, g_trade_day_mon ? clrGreen : clrRed);

      ObjectSetString(0, ui_prefix + "BtnTue", OBJPROP_TEXT, g_trade_day_tue ? "TUE: ON" : "TUE: OFF");
      ObjectSetInteger(0, ui_prefix + "BtnTue", OBJPROP_BGCOLOR, g_trade_day_tue ? clrGreen : clrRed);
      ObjectSetInteger(0, ui_prefix + "BtnTue", OBJPROP_BORDER_COLOR, g_trade_day_tue ? clrGreen : clrRed);

      ObjectSetString(0, ui_prefix + "BtnWed", OBJPROP_TEXT, g_trade_day_wed ? "WED: ON" : "WED: OFF");
      ObjectSetInteger(0, ui_prefix + "BtnWed", OBJPROP_BGCOLOR, g_trade_day_wed ? clrGreen : clrRed);
      ObjectSetInteger(0, ui_prefix + "BtnWed", OBJPROP_BORDER_COLOR, g_trade_day_wed ? clrGreen : clrRed);

      ObjectSetString(0, ui_prefix + "BtnThu", OBJPROP_TEXT, g_trade_day_thu ? "THU: ON" : "THU: OFF");
      ObjectSetInteger(0, ui_prefix + "BtnThu", OBJPROP_BGCOLOR, g_trade_day_thu ? clrGreen : clrRed);
      ObjectSetInteger(0, ui_prefix + "BtnThu", OBJPROP_BORDER_COLOR, g_trade_day_thu ? clrGreen : clrRed);

      ObjectSetString(0, ui_prefix + "BtnFri", OBJPROP_TEXT, g_trade_day_fri ? "FRI: ON" : "FRI: OFF");
      ObjectSetInteger(0, ui_prefix + "BtnFri", OBJPROP_BGCOLOR, g_trade_day_fri ? clrGreen : clrRed);
      ObjectSetInteger(0, ui_prefix + "BtnFri", OBJPROP_BORDER_COLOR, g_trade_day_fri ? clrGreen : clrRed);

      string footerStr=timeStr+" | "+GetLocalClockText()+" | "+GetSessionCountdownText()+" | Spread: "+IntegerToString(spread)+" | News: "+g_newsStatus;
      UpdateLabel("TimeInfo",footerStr,C_Text_Muted);
   }
   ChartRedraw(0);
}
void UpdateORBPricePointer(double price,double low,double high,int startX,int startY,int w)
{
   string trackName=ui_prefix+"ORB_PriceTrack"; string pointerName=ui_prefix+"ORB_PricePointer";
   if(ObjectFind(0,trackName)<0||ObjectFind(0,pointerName)<0)return;
   double range=high-low; if(range<=0){ ObjectSetInteger(0,pointerName,OBJPROP_XSIZE,0); return; }
   double pct=ClampValue((price-low)/range,0.0,1.0);
   int trackW=(int)ObjectGetInteger(0,trackName,OBJPROP_XSIZE); int trackX=(int)ObjectGetInteger(0,trackName,OBJPROP_XDISTANCE);
   int pointerX=trackX+(int)(trackW*pct)-2; ObjectSetInteger(0,pointerName,OBJPROP_XDISTANCE,pointerX); ObjectSetInteger(0,pointerName,OBJPROP_XSIZE,4);
   color ptrClr=C_Accent_Neon; if(price>high)ptrClr=C_Success_Glow; else if(price<low)ptrClr=C_Danger_Glow;
   ObjectSetInteger(0,pointerName,OBJPROP_BGCOLOR,ptrClr); ObjectSetInteger(0,pointerName,OBJPROP_COLOR,ptrClr);
}
void UpdateCardValue(string id,string value,color clr){ ObjectSetString(0,ui_prefix+id+"_Value",OBJPROP_TEXT,value); ObjectSetInteger(0,ui_prefix+id+"_Value",OBJPROP_COLOR,clr); }
void UpdateLabel(string id,string text,color clr){ ObjectSetString(0,ui_prefix+id,OBJPROP_TEXT,text); ObjectSetInteger(0,ui_prefix+id,OBJPROP_COLOR,clr); }

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   // Rebuild the Aurora UI when the chart window is resized so every panel
   // stays inside the view (right panel is right-anchored, bottom re-flows).
   if(id==CHARTEVENT_CHART_CHANGE && UseCreativeAuroraUI)
   {
      int cw=(int)ChartGetInteger(0,CHART_WIDTH_IN_PIXELS,0);
      int ch=(int)ChartGetInteger(0,CHART_HEIGHT_IN_PIXELS,0);
      if(cw>0 && ch>0 && (cw!=aurora_w || ch!=aurora_h))
      {
         AuroraDeleteAll();
         AuroraBuild();
         HTP_UpdateLiveWidgets(true);
      }
   }
   if(id==CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam==tracker_prefix+"ToggleTheme" || sparam==ui_prefix+"ToggleTheme")
      {
         CurrentTheme = (ENUM_PANEL_THEME)(((int)CurrentTheme + 1) % 11);
         ObjectSetInteger(0, ui_prefix+"ToggleTheme", OBJPROP_STATE, false);
         ApplyPremiumColors();
         ApplyThemeChartColors();
         RemoveAllUI();
         if(ShowModernPanel) CreatePremiumUI();
         if(ShowProfitTracker) CreateProfitTrackerUI();
         if(ShowCandleCard) CreateBottomCard();
         UpdatePremiumUI();
         UpdateProfitTrackerUI();
         if(ShowCandleCard) UpdateBottomCard();
         CheckClosedTrades();
         DrawHistoricalORBLevels();
         if(ShowEquityCurve && !UseCreativeAuroraUI){ BuildEquityData(); DrawEquityCurveBox(); }
      }
      else if(sparam==ui_prefix+"ToggleEA"){ EA_Enabled=!EA_Enabled; ObjectSetInteger(0,ui_prefix+"ToggleEA",OBJPROP_STATE,false); UpdatePremiumUI(); }
      else if(sparam==ui_prefix+"ToggleCurr"){ DisplayDZD=!DisplayDZD; ObjectSetInteger(0,ui_prefix+"ToggleCurr",OBJPROP_STATE,false); UpdatePremiumUI(); if(ShowProfitTracker)UpdateProfitTrackerUI(); if(ShowCandleCard)UpdateBottomCard(); CheckClosedTrades(); }
      else if(sparam==ui_prefix+"TogglePanel"){ UI_Collapsed=!UI_Collapsed; ObjectSetInteger(0,ui_prefix+"TogglePanel",OBJPROP_STATE,false); RemoveAllUI(); if(ShowModernPanel)CreatePremiumUI(); if(ShowProfitTracker)CreateProfitTrackerUI(); if(ShowCandleCard)CreateBottomCard(); UpdatePremiumUI(); UpdateProfitTrackerUI(); if(ShowCandleCard)UpdateBottomCard(); CheckClosedTrades(); if(ShowEquityCurve && !UseCreativeAuroraUI){ BuildEquityData(); DrawEquityCurveBox(); } }
      else if(sparam==tracker_prefix+"SaveBtn"){ ObjectSetInteger(0,tracker_prefix+"SaveBtn",OBJPROP_STATE,false); SaveTradeHistoryToHTML(); }
      
      // Weekdays Buttons Event Handling (المطلب الثاني - معالجة الأحداث)
      else if(sparam==ui_prefix+"BtnMon"){ g_trade_day_mon = !g_trade_day_mon; ObjectSetInteger(0,ui_prefix+"BtnMon",OBJPROP_STATE,false); UpdatePremiumUI(); }
      else if(sparam==ui_prefix+"BtnTue"){ g_trade_day_tue = !g_trade_day_tue; ObjectSetInteger(0,ui_prefix+"BtnTue",OBJPROP_STATE,false); UpdatePremiumUI(); }
      else if(sparam==ui_prefix+"BtnWed"){ g_trade_day_wed = !g_trade_day_wed; ObjectSetInteger(0,ui_prefix+"BtnWed",OBJPROP_STATE,false); UpdatePremiumUI(); }
      else if(sparam==ui_prefix+"BtnThu"){ g_trade_day_thu = !g_trade_day_thu; ObjectSetInteger(0,ui_prefix+"BtnThu",OBJPROP_STATE,false); UpdatePremiumUI(); }
      else if(sparam==ui_prefix+"BtnFri"){ g_trade_day_fri = !g_trade_day_fri; ObjectSetInteger(0,ui_prefix+"BtnFri",OBJPROP_STATE,false); UpdatePremiumUI(); }
   }
}
//====================================================================
// BOTTOM-RIGHT CANDLE & SESSION COUNTDOWN CARD API
//====================================================================
void CreateBottomPanel(string id,int xRight,int y,int w,int h,color bg,color borderClr,color outerBg)
{
   string name=ui_prefix+id;
   ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xRight); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,name,OBJPROP_COLOR,borderClr); ObjectSetInteger(0,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER); ObjectSetInteger(0,name,OBJPROP_BACK,false);
   if(outerBg!=CLR_NONE)
   {
      string cs[4]; cs[0]=name+"_C1";cs[1]=name+"_C2";cs[2]=name+"_C3";cs[3]=name+"_C4";
      int cx[4]; int cy[4];
      cx[0]=xRight;     cy[0]=y;
      cx[1]=xRight+w-3; cy[1]=y;
      cx[2]=xRight;     cy[2]=y+h-3;
      cx[3]=xRight+w-3; cy[3]=y+h-3;
      for(int k=0;k<4;k++){
         ObjectCreate(0,cs[k],OBJ_RECTANGLE_LABEL,0,0,0);
         ObjectSetInteger(0,cs[k],OBJPROP_XDISTANCE,cx[k]); ObjectSetInteger(0,cs[k],OBJPROP_YDISTANCE,cy[k]);
         ObjectSetInteger(0,cs[k],OBJPROP_XSIZE,3); ObjectSetInteger(0,cs[k],OBJPROP_YSIZE,3);
         ObjectSetInteger(0,cs[k],OBJPROP_BGCOLOR,outerBg); ObjectSetInteger(0,cs[k],OBJPROP_BORDER_TYPE,BORDER_FLAT);
         ObjectSetInteger(0,cs[k],OBJPROP_COLOR,outerBg); ObjectSetInteger(0,cs[k],OBJPROP_CORNER,CORNER_RIGHT_LOWER);
         ObjectSetInteger(0,cs[k],OBJPROP_BACK,false);
      }
   }
}

void CreateBottomLabel(string id,string text,int xRight,int y,int size,string font,color clr,int anchor=ANCHOR_LEFT_LOWER)
{
   string name=ui_prefix+id; ObjectCreate(0,name,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,xRight); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,font);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,name,OBJPROP_COLOR,clr);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_RIGHT_LOWER);
}

void CreateBottomMeter(string id,int xRight,int y,int meterW,int h)
{
   string bg=ui_prefix+id+"_MeterBG"; string fill=ui_prefix+id+"_MeterFill";
   ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,xRight); ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,bg,OBJPROP_XSIZE,meterW); ObjectSetInteger(0,bg,OBJPROP_YSIZE,h); ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,C_Meter_BG); ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,bg,OBJPROP_COLOR,C_Meter_BG); ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_LOWER); ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectCreate(0,fill,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,fill,OBJPROP_XDISTANCE,xRight+meterW-2); ObjectSetInteger(0,fill,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,fill,OBJPROP_XSIZE,2); ObjectSetInteger(0,fill,OBJPROP_YSIZE,h); ObjectSetInteger(0,fill,OBJPROP_BGCOLOR,C_Accent_Neon); ObjectSetInteger(0,fill,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,fill,OBJPROP_COLOR,C_Accent_Neon); ObjectSetInteger(0,fill,OBJPROP_CORNER,CORNER_RIGHT_LOWER); ObjectSetInteger(0,fill,OBJPROP_BACK,false);
}

void UpdateBottomMeter(string id,double percent,color fillColor,color bgClr)
{
   string bg=ui_prefix+id+"_MeterBG"; string fill=ui_prefix+id+"_MeterFill";
   if(ObjectFind(0,bg)<0||ObjectFind(0,fill)<0)return;
   percent=ClampValue(percent,0.0,100.0); int meterW=(int)ObjectGetInteger(0,bg,OBJPROP_XSIZE); int fillW=MathMax(2,(int)(meterW*percent/100.0));
   int bgXRight=(int)ObjectGetInteger(0,bg,OBJPROP_XDISTANCE);
   int fillXRight = bgXRight + meterW - fillW;
   ObjectSetInteger(0,fill,OBJPROP_XDISTANCE,fillXRight);
   ObjectSetInteger(0,fill,OBJPROP_XSIZE,fillW); ObjectSetInteger(0,fill,OBJPROP_BGCOLOR,fillColor); ObjectSetInteger(0,fill,OBJPROP_COLOR,fillColor);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,bgClr); ObjectSetInteger(0,bg,OBJPROP_COLOR,bgClr);
}

void CreateBottomCard()
{
   if(!ShowCandleCard) return;
   int x = CandleCard_PosX;
   int y = CandleCard_PosY;
   int w = 310;
   int h = 78;
   
   color chartBg   = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   color bgClr     = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'241,245,249' : C_Card_Dark) : Card_CustomBG;
   color borderClr = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'148,163,184' : C_Border_Soft) : Card_CustomBorder;
   color accentClr = Card_UseThemeColors ? C_Accent_Neon : Card_CustomAccent;
   color titleClr  = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'15,23,42' : C_Text_Secondary) : Card_CustomTitleClr;
   color subClr    = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'71,85,105' : C_Text_Muted) : Card_CustomSubClr;
   color valClr    = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'15,23,42' : C_Text_Primary) : Card_CustomValClr;
   
   // 1. Drop shadow box
   CreateBottomPanel("BC_Shadow", x - 4, y - 4, w, h, CurrentTheme==THEME_LIGHT ? C'203,213,225' : C'2,6,14', CurrentTheme==THEME_LIGHT ? C'203,213,225' : C'2,6,14', CLR_NONE);
   // 2. Outer border frame
   CreateBottomPanel("BC_Frame", x - 1, y - 1, w + 2, h + 2, borderClr, borderClr, CLR_NONE);
   // 3. Card solid background
   CreateBottomPanel("BC_BG", x, y, w, h, bgClr, bgClr, CLR_NONE);
   // 4. Top neon accent bar
   CreateBottomPanel("BC_TopGlow", x, y + h - 3, w, 3, accentClr, accentClr, CLR_NONE);
   // 5. Center vertical separator line
   CreateBottomPanel("BC_Divider", x + 155, y + 10, 1, h - 22, borderClr, borderClr, CLR_NONE);
   
   // Left column: Candle countdown (left aligned near left card edge: x + 310 - 14 = x + 296)
   CreateBottomLabel("BC_CandleHeader", "CANDLE COUNTDOWN", x + w - 14, y + 58, Card_TitleFontSize, Card_FontName + " Bold", titleClr, ANCHOR_LEFT_LOWER);
   CreateBottomLabel("BC_CandleTF", "TIMEFRAME: " + TFToString(Period()), x + w - 14, y + 42, Card_LabelFontSize, Card_FontName + " Bold", subClr, ANCHOR_LEFT_LOWER);
   CreateBottomLabel("BC_CandleVal", "---", x + w - 14, y + 18, Card_ValueFontSize, Card_FontName + " Bold", valClr, ANCHOR_LEFT_LOWER);
   
   // Right column: Session status & name (left aligned near center divider: x + 142)
   CreateBottomLabel("BC_SessHeader", "MARKET SESSION", x + 142, y + 58, Card_TitleFontSize, Card_FontName + " Bold", titleClr, ANCHOR_LEFT_LOWER);
   CreateBottomLabel("BC_SessName", "---", x + 142, y + 40, MathMax(6, Card_ValueFontSize - 1), Card_FontName + " Bold", valClr, ANCHOR_LEFT_LOWER);
   CreateBottomLabel("BC_SessVal", "---", x + 142, y + 20, Card_LabelFontSize + 1, Card_FontName + " Bold", accentClr, ANCHOR_LEFT_LOWER);
   
   CreateBottomMeter("BC", x + 10, y + 6, w - 20, 4);
}

void UpdateBottomCard()
{
   if(!ShowCandleCard) return;
   if(ObjectFind(0, ui_prefix+"BC_BG") < 0) CreateBottomCard();
   
   int w = 310;
   int h = 78;
   color chartBg   = (color)ChartGetInteger(0, CHART_COLOR_BACKGROUND);
   color bgClr     = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'241,245,249' : C_Card_Dark) : Card_CustomBG;
   color borderClr = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'148,163,184' : C_Border_Soft) : Card_CustomBorder;
   color accentClr = Card_UseThemeColors ? C_Accent_Neon : Card_CustomAccent;
   color titleClr  = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'15,23,42' : C_Header_Title) : Card_CustomTitleClr;
   color subClr    = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'71,85,105' : C_Text_Secondary) : Card_CustomSubClr;
   color valClr    = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'15,23,42' : C_Text_Primary) : Card_CustomValClr;
   color meterBg   = Card_UseThemeColors ? (CurrentTheme==THEME_LIGHT ? C'203,213,225' : C_Meter_BG) : Card_CustomBorder;
   
   ObjectSetInteger(0, ui_prefix+"BC_Shadow", OBJPROP_BGCOLOR, CurrentTheme==THEME_LIGHT ? C'203,213,225' : C'2,6,14');
   ObjectSetInteger(0, ui_prefix+"BC_Shadow", OBJPROP_COLOR, CurrentTheme==THEME_LIGHT ? C'203,213,225' : C'2,6,14');
   ObjectSetInteger(0, ui_prefix+"BC_Frame", OBJPROP_BGCOLOR, borderClr);
   ObjectSetInteger(0, ui_prefix+"BC_Frame", OBJPROP_COLOR, borderClr);
   ObjectSetInteger(0, ui_prefix+"BC_BG", OBJPROP_BGCOLOR, bgClr);
   ObjectSetInteger(0, ui_prefix+"BC_BG", OBJPROP_COLOR, bgClr);
   ObjectSetInteger(0, ui_prefix+"BC_TopGlow", OBJPROP_BGCOLOR, accentClr);
   ObjectSetInteger(0, ui_prefix+"BC_TopGlow", OBJPROP_COLOR, accentClr);
   ObjectSetInteger(0, ui_prefix+"BC_Divider", OBJPROP_BGCOLOR, borderClr);
   ObjectSetInteger(0, ui_prefix+"BC_Divider", OBJPROP_COLOR, borderClr);
   
   // Typography styling updates
   ObjectSetString(0, ui_prefix+"BC_CandleHeader", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_CandleHeader", OBJPROP_FONTSIZE, Card_TitleFontSize);
   ObjectSetInteger(0, ui_prefix+"BC_CandleHeader", OBJPROP_COLOR, titleClr);
   
   ObjectSetString(0, ui_prefix+"BC_CandleTF", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_CandleTF", OBJPROP_FONTSIZE, Card_LabelFontSize);
   ObjectSetInteger(0, ui_prefix+"BC_CandleTF", OBJPROP_COLOR, subClr);
   
   ObjectSetString(0, ui_prefix+"BC_CandleVal", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_CandleVal", OBJPROP_FONTSIZE, Card_ValueFontSize);
   
   ObjectSetString(0, ui_prefix+"BC_SessHeader", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_SessHeader", OBJPROP_FONTSIZE, Card_TitleFontSize);
   ObjectSetInteger(0, ui_prefix+"BC_SessHeader", OBJPROP_COLOR, titleClr);
   
   ObjectSetString(0, ui_prefix+"BC_SessName", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_SessName", OBJPROP_FONTSIZE, MathMax(6, Card_ValueFontSize - 1));
   
   ObjectSetString(0, ui_prefix+"BC_SessVal", OBJPROP_FONT, Card_FontName+" Bold");
   ObjectSetInteger(0, ui_prefix+"BC_SessVal", OBJPROP_FONTSIZE, Card_LabelFontSize + 1);
   
   // 1. Candle Countdown Logic
   string candleVal = "---";
   color candleClr = valClr;
   datetime now = TimeCurrent();
   datetime nextBar = Time[0] + PeriodSeconds();
   long remSec = (long)(nextBar - now);
   
   MqlDateTime dt; TimeToStruct(now, dt);
   int dow = dt.day_of_week;
   int nowSec = dt.hour * 3600 + dt.min * 60 + dt.sec;
   
   bool isWeekend = false;
   if(dow == 6) isWeekend = true;
   else if(dow == 5 && dt.hour >= 21) isWeekend = true;
   else if(dow == 0 && dt.hour < 22) isWeekend = true;
   
   if(isWeekend || remSec < 0 || (now - Time[0] > PeriodSeconds() * 2))
   {
      candleVal = "MARKET CLOSED";
      candleClr = Card_UseThemeColors ? C_Danger_Glow : clrRed;
   }
   else
   {
      candleVal = FormatClock((int)remSec);
      if(remSec <= 10 && Period() <= PERIOD_M15) candleClr = Card_UseThemeColors ? C_Warning_Glow : clrOrangeRed;
      else candleClr = valClr;
   }
   
   ObjectSetString(0, ui_prefix+"BC_CandleTF", OBJPROP_TEXT, "TIMEFRAME: " + TFToString(Period()));
   ObjectSetString(0, ui_prefix+"BC_CandleVal", OBJPROP_TEXT, candleVal);
   ObjectSetInteger(0, ui_prefix+"BC_CandleVal", OBJPROP_COLOR, candleClr);
   
   // 2. Market Session & Overlap Radar Logic (AUTO DST FOR LONDON / NEW YORK)
   string sessHeader = "ACTIVE MARKET SESSION";
   string sessName   = "---";
   string sessTimer  = "---";
   color  sessNameClr = valClr;
   color  sessTimerClr = accentClr;
   double meterPct = 0.0;
   bool   isOverlap = false;

   int nowMin = dt.hour * 60 + dt.min;
   int lonOpenSrv=0, lonOrbEndSrv=0, lonCloseSrv=0;
   int nyOpenSrv=0,  nyOrbEndSrv=0,  nyCloseSrv=0;
   AutoDST_GetSessionServerSchedule(now, SESSION_ID_LONDON,  lonOpenSrv, lonOrbEndSrv, lonCloseSrv);
   AutoDST_GetSessionServerSchedule(now, SESSION_ID_NEWYORK, nyOpenSrv,  nyOrbEndSrv,  nyCloseSrv);

   int overlapStartSrv = MathMax(lonOpenSrv, nyOpenSrv);
   int overlapEndSrv   = MathMin(lonCloseSrv, nyCloseSrv);

   if(isWeekend)
   {
      long secToSun22 = 0;
      if(dow == 5) secToSun22 = (24*3600 - nowSec) + 24*3600 + 22*3600;
      else if(dow == 6) secToSun22 = (24*3600 - nowSec) + 22*3600;
      else if(dow == 0) secToSun22 = 22*3600 - nowSec;
      
      sessHeader   = "WEEKEND // MARKET CLOSED";
      sessName     = "TOKYO SESSION";
      sessTimer    = "OPENS IN " + FormatClock((int)secToSun22);
      sessNameClr  = subClr;
      sessTimerClr = Card_UseThemeColors ? C_Warning_Glow : clrOrange;
      
      double totalWeekendSec = 48.0 * 3600.0;
      double elapsedWeekend = totalWeekendSec - (double)secToSun22;
      meterPct = ClampValue(elapsedWeekend / totalWeekendSec * 100.0, 0.0, 100.0);
   }
   else
   {
      if(nowMin >= nyCloseSrv && nowMin < 22*60)
      {
         long secToTokyo = 22 * 3600 - nowSec;
         sessHeader   = "POST-MARKET // RADAR";
         sessName     = "TOKYO SESSION";
         sessTimer    = "OPENS IN " + FormatClock((int)secToTokyo);
         sessNameClr  = valClr;
         sessTimerClr = Card_UseThemeColors ? C_Warning_Glow : accentClr;
         
         double gapDur = MathMax(1.0, (22*60 - nyCloseSrv) * 60.0);
         double elapsedGap = gapDur - (double)secToTokyo;
         meterPct = ClampValue(elapsedGap / gapDur * 100.0, 0.0, 100.0);
      }
      else if(dt.hour >= 22 || dt.hour < 7)
      {
         long secToTokyoEnd = (dt.hour >= 22 ? (24 + 7)*3600 - nowSec : 7*3600 - nowSec);
         sessHeader   = "ACTIVE MARKET SESSION";
         sessName     = "TOKYO SESSION";
         sessTimer    = "CLOSES IN " + FormatClock((int)secToTokyoEnd);
         sessNameClr  = valClr;
         sessTimerClr = Card_UseThemeColors ? C_Success_Glow : clrLime;
         
         double tokyoDur = 9.0 * 3600.0;
         double elapsedTokyo = tokyoDur - (double)secToTokyoEnd;
         meterPct = ClampValue(elapsedTokyo / tokyoDur * 100.0, 0.0, 100.0);
      }
      else if(dt.hour >= 7 && nowMin < lonOpenSrv)
      {
         long secToLondon = lonOpenSrv * 60 - nowSec;
         sessHeader   = "ASIAN BREAK // RADAR";
         sessName     = "LONDON SESSION";
         sessTimer    = "OPENS IN " + FormatClock((int)secToLondon);
         sessNameClr  = valClr;
         sessTimerClr = Card_UseThemeColors ? C_Warning_Glow : clrOrange;
         
         double gapToLondon = MathMax(1.0, (lonOpenSrv - 7*60) * 60.0);
         meterPct = ClampValue((gapToLondon - (double)secToLondon) / gapToLondon * 100.0, 0.0, 100.0);
      }
      else if(nowMin >= overlapStartSrv && nowMin < overlapEndSrv)
      {
         isOverlap = true;
         long secToNY  = nyCloseSrv * 60 - nowSec;
         long secToLon = lonCloseSrv * 60 - nowSec;
         
         sessHeader   = "ACTIVE OVERLAP (LON+NY)";
         sessName     = "NY SESSION:  " + FormatClock((int)secToNY);
         sessTimer    = "LON SESSION: " + FormatClock((int)secToLon);
         
         double totalDaySec = MathMax(1.0, (nyCloseSrv - lonOpenSrv) * 60.0);
         double elapsedDay  = (double)(nowMin - lonOpenSrv) * 60.0 + dt.sec;
         meterPct = ClampValue(elapsedDay / totalDaySec * 100.0, 0.0, 100.0);
      }
      else if(nowMin >= lonOpenSrv && nowMin < overlapStartSrv)
      {
         long secToLondonEnd = lonCloseSrv * 60 - nowSec;
         sessHeader   = "ACTIVE MARKET SESSION";
         sessName     = "LONDON SESSION";
         sessTimer    = "CLOSES IN " + FormatClock((int)secToLondonEnd);
         sessNameClr  = valClr;
         sessTimerClr = Card_UseThemeColors ? C_Success_Glow : clrLime;
         
         double lonDur = MathMax(1.0, (overlapStartSrv - lonOpenSrv) * 60.0);
         double elapsedLon = lonDur - (double)(overlapStartSrv * 60 - nowSec);
         meterPct = ClampValue(elapsedLon / lonDur * 100.0, 0.0, 100.0);
      }
      else
      {
         long secToNYEnd = nyCloseSrv * 60 - nowSec;
         sessHeader   = "ACTIVE MARKET SESSION";
         sessName     = "NEW YORK SESSION";
         sessTimer    = "CLOSES IN " + FormatClock((int)secToNYEnd);
         sessNameClr  = valClr;
         sessTimerClr = Card_UseThemeColors ? C_Info_Glow : accentClr;
         
         double nyDur = MathMax(1.0, (nyCloseSrv - overlapEndSrv) * 60.0);
         double elapsedNY = nyDur - (double)secToNYEnd;
         meterPct = ClampValue(elapsedNY / nyDur * 100.0, 0.0, 100.0);
      }
   }
   
   if(isOverlap)
   {
      ObjectSetInteger(0, ui_prefix+"BC_SessName", OBJPROP_FONTSIZE, Card_LabelFontSize + 2);
      ObjectSetInteger(0, ui_prefix+"BC_SessVal", OBJPROP_FONTSIZE, Card_LabelFontSize + 2);
      ObjectSetInteger(0, ui_prefix+"BC_SessName", OBJPROP_COLOR, Card_UseThemeColors ? C_Info_Glow : accentClr);
      ObjectSetInteger(0, ui_prefix+"BC_SessVal", OBJPROP_COLOR, Card_UseThemeColors ? C_Success_Glow : clrLime);
   }
   else
   {
      ObjectSetInteger(0, ui_prefix+"BC_SessName", OBJPROP_FONTSIZE, MathMax(6, Card_ValueFontSize - 1));
      ObjectSetInteger(0, ui_prefix+"BC_SessVal", OBJPROP_FONTSIZE, Card_LabelFontSize + 1);
      ObjectSetInteger(0, ui_prefix+"BC_SessName", OBJPROP_COLOR, sessNameClr);
      ObjectSetInteger(0, ui_prefix+"BC_SessVal", OBJPROP_COLOR, sessTimerClr);
   }
   
   ObjectSetString(0, ui_prefix+"BC_SessHeader", OBJPROP_TEXT, sessHeader);
   ObjectSetString(0, ui_prefix+"BC_SessName", OBJPROP_TEXT, sessName);
   ObjectSetString(0, ui_prefix+"BC_SessVal", OBJPROP_TEXT, sessTimer);
   
   UpdateBottomMeter("BC", meterPct, isOverlap ? (Card_UseThemeColors ? C_Info_Glow : accentClr) : sessTimerClr, meterBg);
}

void RemoveAllUI(){ ObjectsDeleteAll(0,ui_prefix); ObjectsDeleteAll(0,tracker_prefix); ObjectsDeleteAll(0,eq_prefix); ObjectsDeleteAll(0,"ORB_Lv_"); ObjectsDeleteAll(0,"ORB_Box_"); ObjectsDeleteAll(0,"Result_"); ObjectsDeleteAll(0,"Badge"); ObjectsDeleteAll(0,"Pointer_"); ChartRedraw(0); }
void RemoveTrackerUI(){ ObjectsDeleteAll(0,tracker_prefix); }

//====================================================================
// PROFIT TRACKER UI
//====================================================================
void CreateTrackerPanel(string id,int x,int y,int w,int h,color bg,int borderWidth)
{
   string name=tracker_prefix+id; if(ObjectFind(0,name)>=0)return;
   ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,h); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg); ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,name,OBJPROP_COLOR,borderWidth>0?C_Glass_Border:bg); ObjectSetInteger(0,name,OBJPROP_WIDTH,1); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_BACK,false);
   string top=tracker_prefix+id+"_TOP"; ObjectCreate(0,top,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,top,OBJPROP_XDISTANCE,x+1); ObjectSetInteger(0,top,OBJPROP_YDISTANCE,y+1); ObjectSetInteger(0,top,OBJPROP_XSIZE,MathMax(10,w/4)); ObjectSetInteger(0,top,OBJPROP_YSIZE,1); ObjectSetInteger(0,top,OBJPROP_BGCOLOR,C_Glass_Accent2); ObjectSetInteger(0,top,OBJPROP_BORDER_TYPE,BORDER_FLAT); ObjectSetInteger(0,top,OBJPROP_COLOR,C_Glass_Accent2); ObjectSetInteger(0,top,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,top,OBJPROP_BACK,false);
}
void CreateTrackerGlowLine(string id,int x,int y,int w,color clr){ string name=tracker_prefix+id; if(ObjectFind(0,name)>=0)return; ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetInteger(0,name,OBJPROP_XSIZE,w); ObjectSetInteger(0,name,OBJPROP_YSIZE,1); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clr); ObjectSetInteger(0,name,OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,name,OBJPROP_COLOR,clr); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_BACK,false); }
void CreateTrackerLabel(string id,string text,int x,int y,int size,string font,color clr,int anchor){ string name=tracker_prefix+id; if(ObjectFind(0,name)>=0)return; ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y); ObjectSetString(0,name,OBJPROP_TEXT,text); ObjectSetString(0,name,OBJPROP_FONT,font); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,size); ObjectSetInteger(0,name,OBJPROP_COLOR,clr); ObjectSetInteger(0,name,OBJPROP_ANCHOR,anchor); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); }
void CreateStatBox(string id,string label,int x,int y,int w,int h){ CreateTrackerPanel(id+"_BG",x,y,w,h,C_Glass_Card,1); CreateTrackerLabel(id+"_Lbl",label,x+w/2,y+2,7,"Segoe UI Black",C_Text_Primary,ANCHOR_UPPER); CreateTrackerLabel(id+"_Val","---",x+w/2,y+h-13,9,"Segoe UI Black",C_Text_Primary,ANCHOR_UPPER); }
void UpdateStatBox(string id,string val,color clr){ ObjectSetString(0,tracker_prefix+id+"_Val",OBJPROP_TEXT,val); ObjectSetInteger(0,tracker_prefix+id+"_Val",OBJPROP_COLOR,clr); }
void CreateProfitTrackerUI()
{
   if(!ShowProfitTracker||UI_Collapsed)return;
   int x=UI_PosX+580; int y=UI_PosY; int w=300; int h=520; int rowH=22; // Keep row height like original
   CreateTrackerPanel("TrackerShell",x,y,w,h,C_Glass_BG,1);
   CreateTrackerPanel("TrackerTop",x+1,y+1,w-2,38,C_Glass_Panel,0);
   ObjectCreate(0,tracker_prefix+"TrackerGlow",OBJ_RECTANGLE_LABEL,0,0,0); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_XDISTANCE,x+1); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_YDISTANCE,y+1); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_XSIZE,w-2); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_YSIZE,2); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_BGCOLOR,C_Accent_Neon); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_BORDER_TYPE,BORDER_RAISED); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_COLOR,C_Accent_Neon); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,tracker_prefix+"TrackerGlow",OBJPROP_BACK,false);
   string name=tracker_prefix+"Title"; ObjectCreate(0,name,OBJ_LABEL,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x+8); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y+10); ObjectSetString(0,name,OBJPROP_TEXT,"PERFORMANCE TAPE // LAST 8 DAYS"); ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI Black"); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9); ObjectSetInteger(0,name,OBJPROP_COLOR,C_Text_Primary); ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER);
   name=tracker_prefix+"SaveBtn";
   if(ObjectFind(0,name)<0){ ObjectCreate(0,name,OBJ_BUTTON,0,0,0); ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x+w-55); ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y+4); ObjectSetInteger(0,name,OBJPROP_XSIZE,50); ObjectSetInteger(0,name,OBJPROP_YSIZE,15); ObjectSetString(0,name,OBJPROP_TEXT,"SAVE "); ObjectSetString(0,name,OBJPROP_FONT,"Segoe UI Black"); ObjectSetInteger(0,name,OBJPROP_FONTSIZE,8); ObjectSetInteger(0,name,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,name,OBJPROP_STATE,false); }
   ObjectSetInteger(0,name,OBJPROP_COLOR,C_Save_Text); ObjectSetInteger(0,name,OBJPROP_BGCOLOR,C_Save_BG); ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,C_Save_BG);
   
   string thBtn=tracker_prefix+"ToggleTheme";
   if(ObjectFind(0,thBtn)<0){ ObjectCreate(0,thBtn,OBJ_BUTTON,0,0,0); ObjectSetInteger(0,thBtn,OBJPROP_XDISTANCE,x+w-55); ObjectSetInteger(0,thBtn,OBJPROP_YDISTANCE,y+21); ObjectSetInteger(0,thBtn,OBJPROP_XSIZE,50); ObjectSetInteger(0,thBtn,OBJPROP_YSIZE,15); ObjectSetString(0,thBtn,OBJPROP_TEXT,ThemeToString(CurrentTheme)); ObjectSetString(0,thBtn,OBJPROP_FONT,"Segoe UI Bold"); ObjectSetInteger(0,thBtn,OBJPROP_FONTSIZE,7); ObjectSetInteger(0,thBtn,OBJPROP_CORNER,CORNER_LEFT_UPPER); ObjectSetInteger(0,thBtn,OBJPROP_STATE,false); }
   ObjectSetInteger(0,thBtn,OBJPROP_COLOR,C_OnAccent_Text); ObjectSetInteger(0,thBtn,OBJPROP_BGCOLOR,C_Border_Soft); ObjectSetInteger(0,thBtn,OBJPROP_BORDER_COLOR,C_Border_Soft);
   
   int kpiY=y+50; int boxW=110; int gap=8;
   CreateStatBox("Stat_NetProfit","NET PROFIT",x+12,kpiY,boxW,30);
   CreateStatBox("Stat_WinRate","WIN RATE",x+12+boxW+gap,kpiY,boxW,30);
   CreateStatBox("Stat_PF","PROFIT FACTOR",x+12,kpiY+34,boxW,30);
   CreateStatBox("Stat_RF","RECOVERY",x+12+boxW+gap,kpiY+34,boxW,30);
   int hiY=kpiY+90; CreateTrackerPanel("Highlight_BG",x+12,hiY,w-24,18,C_Card_Dark,1);
   CreateTrackerLabel("Highlight_Text","DAILY: -- | MONTHLY: -- | TOTAL: --",x+w/2,hiY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_UPPER);
   int tableY=hiY+35; CreateTrackerPanel("RowHeader_BG",x+12,tableY,w-24,14,C_Glass_Panel,1);
   CreateTrackerLabel("Head_Date","DATE",x+18,tableY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_LEFT_UPPER); CreateTrackerLabel("Head_Pips","PIPS",x+118,tableY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_RIGHT_UPPER); CreateTrackerLabel("Head_Profit","PROFIT",x+196,tableY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_RIGHT_UPPER); CreateTrackerLabel("Head_Gain","GAIN%",x+250,tableY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_RIGHT_UPPER); CreateTrackerLabel("Head_Lot","LOT",x+284,tableY+3,7,"Segoe UI Bold",C_Text_Primary,ANCHOR_RIGHT_UPPER);
   tableY+=25;
   for(int i=0;i<13;i++){ string rowId="Row_"+IntegerToString(i); CreateTrackerPanel(rowId+"_BG",x+12,tableY,w-24,rowH,(i%2==0?C_Glass_BG:C_Glass_Card),0); CreateTrackerLabel(rowId+"_D","---",x+18,tableY+3,7,"Segoe UI Bold",C_Tracker_Text,ANCHOR_LEFT_UPPER); CreateTrackerLabel(rowId+"_P","",x+118,tableY+3,7,"Segoe UI Bold",C_Tracker_Text,ANCHOR_RIGHT_UPPER); CreateTrackerLabel(rowId+"_R","",x+196,tableY+3,7,"Segoe UI Bold",C_Tracker_Text,ANCHOR_RIGHT_UPPER); CreateTrackerLabel(rowId+"_G","",x+250,tableY+3,7,"Segoe UI Bold",C_Tracker_Text,ANCHOR_RIGHT_UPPER); CreateTrackerLabel(rowId+"_L","",x+284,tableY+3,7,"Segoe UI Bold",C_Tracker_Text,ANCHOR_RIGHT_UPPER); tableY+=rowH+2; }
   CreateTrackerPanel("FooterBG",x+12,y+h-25,w-24,18,C_Glass_Panel,0);
   CreateTrackerLabel("FooterStats","Trades: 0 |   Wins: 0 | Losses: 0 | Days: 0",x+w/2,y+h-21,6,"Segoe UI Bold",C_Text_Muted,ANCHOR_UPPER);
}
void UpdateProfitTrackerUI()
{
   if(!ShowProfitTracker||UI_Collapsed){ RemoveTrackerUI(); return; }
   if(ObjectFind(0,tracker_prefix+"TrackerShell")<0) CreateProfitTrackerUI();
   
   if(ObjectFind(0,tracker_prefix+"Head_Profit")>=0)
      ObjectSetString(0,tracker_prefix+"Head_Profit",OBJPROP_TEXT,DisplayDZD?"PROFIT(DZD)":"PROFIT($)");
   if(ObjectFind(0,tracker_prefix+"ToggleTheme")>=0){
      ObjectSetString(0,tracker_prefix+"ToggleTheme",OBJPROP_TEXT,ThemeToString(CurrentTheme));
      ObjectSetInteger(0,tracker_prefix+"ToggleTheme",OBJPROP_BGCOLOR,C_Border_Soft);
      ObjectSetInteger(0,tracker_prefix+"ToggleTheme",OBJPROP_COLOR,C_OnAccent_Text);
   }
   
   double totalProfit=cachedNetProfit; double initialBalance=AccountBalance()-totalProfit; double growth=(initialBalance>0)?(totalProfit/initialBalance)*100.0:0;
   UpdateStatBox("Stat_NetProfit",FormatMoney(totalProfit),totalProfit>=0?C_Tracker_Success:C_Tracker_Danger);
   UpdateStatBox("Stat_WinRate",DoubleToString(cachedWinRate,1)+"%",cachedWinRate>=50?C_Tracker_Success:C_Tracker_Danger);
   UpdateStatBox("Stat_PF",DoubleToString(cachedPF,2),cachedPF>=1.2?C_Tracker_Success:(cachedPF>=1.0?C_Warning_Glow:C_Tracker_Danger));
   UpdateStatBox("Stat_RF",DoubleToString(cachedRF,2),cachedRF>=1.5?C_Tracker_Success:C_Warning_Glow);
   double dailyPL=GetPeriodProfit(0); double dailyP=(AccountBalance()-dailyPL>0)?(dailyPL/(AccountBalance()-dailyPL))*100.0:0;
   double monthlyPL=GetPeriodProfit(1); double monthlyP=(AccountBalance()-monthlyPL>0)?(monthlyPL/(AccountBalance()-monthlyPL))*100.0:0;
   string highlight=StringFormat("DAILY: %.2f%%   |   MONTHLY: %.2f%%   |   TOTAL: %.2f%%",dailyP,monthlyP,growth);
   ObjectSetString(0,tracker_prefix+"Highlight_Text",OBJPROP_TEXT,highlight); ObjectSetInteger(0,tracker_prefix+"Highlight_Text",OBJPROP_COLOR,dailyP>=0?C_Tracker_Success:C_Tracker_Danger);
   datetime now=TimeCurrent(); datetime checkDay=now-(now%86400); int rowIdx=0; int daysProcessed=0;
   while(rowIdx<13 && daysProcessed<60)
   {
      int dow=TimeDayOfWeek(checkDay);
      if(dow!=0 && dow!=6)
      {
         double dpips,dprofit,dgain,dlots; GetDayStats(checkDay,dpips,dprofit,dgain,dlots);
         if(dprofit!=0||dpips!=0||dlots!=0||rowIdx==0)
         {
            string dateStr; if(rowIdx==0) dateStr="TODAY"; else { MqlDateTime dts; TimeToStruct(checkDay,dts); dateStr=StringFormat("%02d/%02d/%d",dts.day,dts.mon,dts.year); }
            double dispProfit = DisplayDZD ? dprofit * USD_DZD_Rate : dprofit;
            string profitStr = DisplayDZD ? (DoubleToString(dispProfit,0)+" DZD") : ((dispProfit>=0?"$":"-$")+DoubleToString(MathAbs(dispProfit),2));
            string rowBase=tracker_prefix+"Row_"+IntegerToString(rowIdx);
            ObjectSetString(0,rowBase+"_D",OBJPROP_TEXT,dateStr);
            ObjectSetString(0,rowBase+"_P",OBJPROP_TEXT,DoubleToString(dpips,1));
            ObjectSetString(0,rowBase+"_R",OBJPROP_TEXT,profitStr);
            ObjectSetString(0,rowBase+"_G",OBJPROP_TEXT,DoubleToString(dgain,2));
            ObjectSetString(0,rowBase+"_L",OBJPROP_TEXT,DoubleToString(dlots,2));
            color rowClr=(dprofit>0?C_Tracker_Success:(dprofit<0?C_Tracker_Danger:C_Tracker_Value));
            ObjectSetInteger(0,rowBase+"_D",OBJPROP_COLOR,rowClr); ObjectSetInteger(0,rowBase+"_P",OBJPROP_COLOR,rowClr); ObjectSetInteger(0,rowBase+"_R",OBJPROP_COLOR,rowClr); ObjectSetInteger(0,rowBase+"_G",OBJPROP_COLOR,rowClr); ObjectSetInteger(0,rowBase+"_L",OBJPROP_COLOR,rowClr);
            ObjectSetInteger(0,tracker_prefix+"Row_"+IntegerToString(rowIdx)+"_BG",OBJPROP_BGCOLOR,rowIdx==0 && g_uiPulse?C_Card_Dark:(rowIdx%2==0?C_Glass_BG:C_Glass_Card));
            rowIdx++;
         }
      }
      checkDay-=86400; daysProcessed++;
   }
   for(int i=rowIdx;i<13;i++){ string rb=tracker_prefix+"Row_"+IntegerToString(i); ObjectSetString(0,rb+"_D",OBJPROP_TEXT,""); ObjectSetString(0,rb+"_P",OBJPROP_TEXT,""); ObjectSetString(0,rb+"_R",OBJPROP_TEXT,""); ObjectSetString(0,rb+"_G",OBJPROP_TEXT,""); ObjectSetString(0,rb+"_L",OBJPROP_TEXT,""); }
   string footer=StringFormat("Trades: %d  |  Wins: %d  |  Losses: %d  |  Days: %d",(cachedWins+cachedLosses),cachedWins,cachedLosses,cachedDaysTraded);
   ObjectSetString(0,tracker_prefix+"FooterStats",OBJPROP_TEXT,footer); ChartRedraw(0);
}
void GetDayStats(datetime day,double &pips,double &profit,double &gain,double &lots)
{
   pips=0;profit=0;gain=0;lots=0; datetime dayStart=day-(day%86400); datetime dayEnd=dayStart+86400;
   for(int i=0;i<OrdersHistoryTotal();i++){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderType()>1)continue; if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber()))){ datetime ct=OrderCloseTime(); if(ct>=dayStart&&ct<dayEnd){ double p=OrderProfit()+OrderSwap()+OrderCommission(); profit+=p; lots+=OrderLots(); pips+=CalcSelectedOrderPips(); } } } }
   if(AccountBalance()-profit>0) gain=(profit/(AccountBalance()-profit))*100.0;
}

//====================================================================
// NEWS FILTER
//====================================================================
void RefreshNewsData()
{
   if(!UseNewsFilter||IsTesting())return; static datetime lastRetry=0;
   if(g_lastNewsDownload!=0 && TimeCurrent()-g_lastNewsDownload<14400)return;
   if(g_lastNewsDownload==0 && TimeCurrent()-lastRetry<300)return;
   Print("News Filter: Refreshing news data..."); lastRetry=TimeCurrent();
   string url="https://www.myfxbook.com/calendar"; uchar post[],result[]; string result_headers; string headers="User-Agent: MetaTrader/4.00; LONDON_ORB_EA\r\n"; int timeout=5000;
   ResetLastError(); int res=WebRequest("GET",url,headers,timeout,post,result,result_headers);
   if(res>=200 && res<300){ string html=CharArrayToString(result); if(StringFind(html,"economicCalendarRow")>=0){ ParseMyfxbookHTML(html); g_lastNewsDownload=TimeCurrent(); g_newsStatus="UPDATED"; } else g_newsStatus="PARSE ERROR"; }
   else { int err=GetLastError(); if(err==4060){ Print("News Filter: URL not allowed in MT4 settings"); g_newsStatus="URL BLOCKED"; } else g_newsStatus="DOWNLOAD FAILED"; }
}
void ParseMyfxbookHTML(string html)
{
   ArrayFree(g_news); g_newsCount=0; string rowSearch="economicCalendarRow"; int pos=0,processed=0,maxRows=200;
   while((pos=StringFind(html,rowSearch,pos))>=0 && processed<maxRows)
   {
      pos+=StringLen(rowSearch); int endPos=StringFind(html,rowSearch,pos); string rowData=(endPos>0?StringSubstr(html,pos,endPos-pos):StringSubstr(html,pos));
      string metaTime=ExtractTimeData(rowData); int impact=ExtractImpactData(rowData); string currency=ExtractCurrencyData(rowData);
      if(metaTime!="" && currency!="" && impact>0){ if((impact==3 && News_HighImpact)||(impact==2 && News_MedImpact)){ if(StringFind(News_Currency,currency)>=0){ NewsEvent ev; ev.time=ParseMyfxTimestamp(metaTime); ev.currency=currency; ev.impact=impact; ev.title=""; if(ev.time>TimeCurrent()-3600){ ArrayResize(g_news,g_newsCount+1); g_news[g_newsCount]=ev; g_newsCount++; } } } }
      processed++; if(endPos<0)break;
   }
   Print("News Filter: ",g_newsCount," relevant events parsed.");
}
string ExtractTimeData(string rowData){ string attrs[]={"data-calendardatetd","data-calendardatetD","data-calendarDateTd"}; for(int i=0;i<ArraySize(attrs);i++){ int pos=StringFind(rowData,attrs[i]); if(pos>=0){ int qStart=StringFind(rowData,"=",pos); if(qStart>=0){ string qChar=StringSubstr(rowData,qStart+1,1); if(qChar=="\""||qChar=="'"){ int qEnd=StringFind(rowData,qChar,qStart+2); if(qEnd>qStart+1) return StringSubstr(rowData,qStart+2,qEnd-qStart-2); } } } } return ""; }
int ExtractImpactData(string rowData){ string lower=rowData; StringToLower(lower); if(StringFind(lower,"impact_high")>=0)return 3; if(StringFind(lower,"impact_medium")>=0)return 2; if(StringFind(lower,"impact_low")>=0)return 1; return 0; }
string ExtractCurrencyData(string rowData){ int searchPos=0,cellCount=0; while(cellCount<4 && (searchPos=StringFind(rowData,"calendarToggleCell",searchPos))>=0){ searchPos+=18; cellCount++; if(cellCount==4){ int startCell=StringFind(rowData,">",searchPos); int endCell=StringFind(rowData,"</td>",startCell); if(startCell>0 && endCell>startCell){ string currency=StringSubstr(rowData,startCell+1,endCell-startCell-1); int tagStart=StringFind(currency,"<"); if(tagStart>=0)currency=StringSubstr(currency,0,tagStart); currency=TrimString(currency); return (StringLen(currency)>3?StringSubstr(currency,0,3):currency); } } } return ""; }
string StringBetween(string data,string start,string end){ int s=StringFind(data,start); if(s<0)return ""; s+=StringLen(start); int e=StringFind(data,end,s); if(e<0)return ""; return StringSubstr(data,s,e-s); }
datetime ParseMyfxTimestamp(string ts){ MqlDateTime dt; ZeroMemory(dt); dt.year=(int)StringToInteger(StringSubstr(ts,0,4)); dt.mon=(int)StringToInteger(StringSubstr(ts,5,2)); dt.day=(int)StringToInteger(StringSubstr(ts,8,2)); dt.hour=(int)StringToInteger(StringSubstr(ts,11,2)); dt.min=(int)StringToInteger(StringSubstr(ts,14,2)); dt.sec=0; return StructToTime(dt); }
bool IsNewsTime(){ if(!UseNewsFilter||IsTesting()||g_newsCount==0)return false; datetime now=TimeCurrent(); for(int i=0;i<g_newsCount;i++) if(now>=g_news[i].time-MinsBeforeNews*60 && now<=g_news[i].time+MinsAfterNews*60) return true; return false; }
bool GetNextHighNews(datetime &newsTime,string &currency){ if(!UseNewsFilter||g_newsCount==0)return false; datetime now=TimeCurrent(); datetime soonest=0; int index=-1; for(int i=0;i<g_newsCount;i++) if(g_news[i].impact==3 && g_news[i].time>now-1800) if(soonest==0||g_news[i].time<soonest){ soonest=g_news[i].time; index=i; } if(index!=-1){ newsTime=g_news[index].time; currency=g_news[index].currency; return true; } return false; }

//====================================================================
// TRADING CORE
//====================================================================
bool IsOurMagic(int m)
{
   if(OrbTradeMode == MODE_LONDON_ONLY) return (m == Lon_MagicNumber);
   if(OrbTradeMode == MODE_NY_ONLY)     return (m == NY_MagicNumber);
   return (m == Lon_MagicNumber || m == NY_MagicNumber);
}

bool HasOpenTradeMagic(int magic){ for(int i=OrdersTotal()-1;i>=0;i--) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&OrderMagicNumber()==magic)return true; return false; }

double GetMartingaleLot()
{
   if(!UseMartingale)return 0; int streak=0; double lastLot=0;
   for(int i=OrdersHistoryTotal()-1;i>=0;i--){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber())){ double profit=OrderProfit()+OrderSwap()+OrderCommission(); if(profit<0){ streak++; if(streak==1)lastLot=OrderLots(); } else if(profit>=0)break; } } }
   if(streak>0 && streak<=MaxMartingaleLevel) return lastLot+MartingaleAddLot; return 0;
}
double CalculateLotSize(double slPoints)
{
   double martingaleLot=GetMartingaleLot();
   if(martingaleLot>0){ double minLot=MarketInfo(Symbol(),MODE_MINLOT); double maxLot=MarketInfo(Symbol(),MODE_MAXLOT); double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP); martingaleLot=MathFloor(martingaleLot/lotStep)*lotStep; return MathMax(minLot,MathMin(maxLot,martingaleLot)); }
   double calculatedLot=LotSize;
   if(UseRiskPercent && slPoints>0){ double riskAmount=AccountBalance()*RiskPercent/100.0; double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE); double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE); double pointValue=MarketInfo(Symbol(),MODE_POINT); if(tickSize>0){ double valuePerPoint=tickValue/(tickSize/pointValue); double slMoneyPerLot=slPoints*valuePerPoint; if(slMoneyPerLot>0) calculatedLot=riskAmount/slMoneyPerLot; } }
   if(EnableProfitCompd && cachedEANetProfit>0 && CompoundingStepProfit>0){ int steps=(int)(cachedEANetProfit/CompoundingStepProfit); calculatedLot+=steps*CompoundingAddLot; }
   double minLot=MarketInfo(Symbol(),MODE_MINLOT); double maxLot=MarketInfo(Symbol(),MODE_MAXLOT); double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP); calculatedLot=MathFloor(calculatedLot/lotStep)*lotStep; return MathMax(minLot,MathMin(maxLot,calculatedLot));
}
void RefreshStatsCache()
{
   int currentTotal=OrdersHistoryTotal(); if(currentTotal==lastHistoryCount)return;
   cachedGrossProfit=0;cachedGrossLoss=0;cachedNetProfit=0;cachedEANetProfit=0;cachedWins=0;cachedLosses=0;cachedLongs=0;cachedShorts=0;cachedMaxDD=0;cachedBestTrade=0;cachedWorstTrade=0;cachedTotalPips=0;cachedExpectancy=0;cachedAvgWin=0;cachedAvgLoss=0;cachedPF=0;cachedWinRate=0;cachedRF=0;cachedDailyPL=0;cachedDailyWon=0;cachedDailyLoss=0;cachedDaysTraded=0;
   double curve=0.0,peakCurve=0.0; bool firstTrade=true; datetime lastDay=0;
   for(int i=0;i<currentTotal;i++){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderType()>1)continue; double profit=OrderProfit()+OrderSwap()+OrderCommission(); bool eaTrade=(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber())); if(eaTrade)cachedEANetProfit+=profit; if(GlobalHistory||eaTrade){ cachedNetProfit+=profit; if(profit>=0){cachedWins++;cachedGrossProfit+=profit;}else{cachedLosses++;cachedGrossLoss+=profit;} if(OrderType()==OP_BUY)cachedLongs++; if(OrderType()==OP_SELL)cachedShorts++; curve+=profit; if(curve>peakCurve)peakCurve=curve; double currentDD=peakCurve-curve; if(currentDD>cachedMaxDD)cachedMaxDD=currentDD; if(firstTrade){cachedBestTrade=profit;cachedWorstTrade=profit;firstTrade=false;}else{if(profit>cachedBestTrade)cachedBestTrade=profit;if(profit<cachedWorstTrade)cachedWorstTrade=profit;} cachedTotalPips+=CalcSelectedOrderPips(); datetime closeTime=OrderCloseTime(); datetime dayStart=closeTime-(closeTime%86400); if(dayStart!=lastDay){cachedDaysTraded++;lastDay=dayStart;} } } }
   if(firstTrade){cachedBestTrade=0;cachedWorstTrade=0;}
   cachedWinRate=(cachedWins+cachedLosses>0)?((double)cachedWins/(cachedWins+cachedLosses))*100.0:0.0;
   cachedAvgWin=(cachedWins>0)?cachedGrossProfit/cachedWins:0.0; cachedAvgLoss=(cachedLosses>0)?MathAbs(cachedGrossLoss)/cachedLosses:0.0;
   cachedPF=(cachedGrossLoss!=0)?cachedGrossProfit/MathAbs(cachedGrossLoss):0.0; cachedRF=(cachedMaxDD>0)?cachedNetProfit/cachedMaxDD:0.0;
   cachedExpectancy=(cachedWinRate/100.0*cachedAvgWin)-((1.0-cachedWinRate/100.0)*cachedAvgLoss); 
   cachedDailyPL=GetPeriodProfit(0); 
   
   // Calculate session-specific daily profits (المطلب الجديد)
   cachedDailyPL_Lon = 0;
   cachedDailyPL_NY = 0;
   int cYear=TimeYear(TimeCurrent()); int cMonth=TimeMonth(TimeCurrent()); int cDay=TimeDay(TimeCurrent());
   for(int k=0; k<OrdersHistoryTotal(); k++)
   {
      if(OrderSelect(k, SELECT_BY_POS, MODE_HISTORY))
      {
         if(OrderType() > 1) continue;
         if(GlobalHistory || (OrderSymbol() == Symbol() && IsOurMagic(OrderMagicNumber())))
         {
            datetime ct = OrderCloseTime();
            if(TimeYear(ct) == cYear && TimeMonth(ct) == cMonth && TimeDay(ct) == cDay)
            {
               double p = OrderProfit() + OrderSwap() + OrderCommission();
               if(OrderMagicNumber() == Lon_MagicNumber) cachedDailyPL_Lon += p;
               else if(OrderMagicNumber() == NY_MagicNumber) cachedDailyPL_NY += p;
            }
         }
      }
   }
   
   GetDailyPLBreakdown(cachedDailyWon,cachedDailyLoss); lastHistoryCount=currentTotal;
}
int GetMinutesWithOffset(datetime time, int offset)
{
   // Legacy wrapper retained for compatibility.
   // Session-aware logic now uses AutoDST_* helpers.
   MqlDateTime dt;
   TimeToStruct(time, dt);
   return dt.hour * 60 + dt.min;
}

bool FindSessionORBRange(int startM, int endM, double &hi, double &lo, int offset)
{
   ENUM_SESSION_ID sid = (offset < 0 ? SESSION_ID_NEWYORK : SESSION_ID_LONDON);
   return AutoDST_FindSessionORBRange(startM, endM, hi, lo, sid);
}

int CheckBreakoutSignal(double orbHigh,double orbLow)
{
   if(Bars<3)return 0; double buffer=BreakoutPadding*Point; double range=(orbHigh-orbLow)/Point;
   if(range<MinRangePoints||range>MaxRangePoints)return 0;
   double closeNow=Close[1];
   bool buyBreak=(Low[1]<orbLow-buffer && closeNow>orbLow);
   bool sellBreak=(High[1]>orbHigh+buffer && closeNow<orbHigh);
   if(UseADXFilter){ double adx=iADX(NULL,0,ADX_Period,PRICE_CLOSE,MODE_MAIN,1); if(adx<ADX_Minimum)return 0; }
   if(UseTrendFilter){ double ma=iMA(NULL,0,MA_Period,0,MA_Method,PRICE_CLOSE,1); if(buyBreak && closeNow<ma)buyBreak=false; if(sellBreak && closeNow>ma)sellBreak=false; }
   if(buyBreak)return 1; if(sellBreak)return -1; return 0;
}

// Interactive Buttons State for Trading Days (Initialized by User Inputs)
bool g_trade_day_mon = true;
bool g_trade_day_tue = true;
bool g_trade_day_wed = true;
bool g_trade_day_thu = true;
bool g_trade_day_fri = true;

//====================================================================
// BROKER-SAFE EXECUTION LAYER (anti error 129/130/135/136/138/146)
//====================================================================
int    BrokerDigits()        { return (int)MarketInfo(Symbol(),MODE_DIGITS); }
double BrokerPoint()         { return MarketInfo(Symbol(),MODE_POINT); }
int    BrokerStopLevel()     { return (int)MarketInfo(Symbol(),MODE_STOPLEVEL); }
int    BrokerFreezeLevel()   { return (int)MarketInfo(Symbol(),MODE_FREEZELEVEL); }
double BrokerMinStopDist()   { return (BrokerStopLevel()+1)*BrokerPoint(); }
bool   WaitTradeContext(int maxWaitMs){ int waited=0; while(IsTradeContextBusy() && waited<maxWaitMs){ Sleep(100); waited+=100; } return(!IsTradeContextBusy()); }

int SafeOrderSend(int orderType,double lots,double price,double slPrice,double tpPrice,int magic,color arrowClr)
{
   string sym=Symbol(); int digits=BrokerDigits(); double minDist=BrokerMinStopDist();
   for(int attempt=0; attempt<3; attempt++)
   {
      if(!WaitTradeContext(2000)){ Print("SafeOrderSend: trade context busy, attempt ",attempt+1); continue; }
      RefreshRates();
      double entry=NormalizeDouble(orderType==OP_BUY?Ask:Bid,digits);
      double sl=slPrice, tp=tpPrice;
      if(sl>0){ if(orderType==OP_BUY && entry-sl<minDist) sl=entry-minDist; if(orderType==OP_SELL && sl-entry<minDist) sl=entry+minDist; sl=NormalizeDouble(sl,digits); }
      if(tp>0){ if(orderType==OP_BUY && tp-entry<minDist) tp=entry+minDist; if(orderType==OP_SELL && entry-tp<minDist) tp=entry-minDist; tp=NormalizeDouble(tp,digits); }
      // step 1: try with SL/TP attached, instant-execution brokers accept this
      int ticket=OrderSend(sym,orderType,lots,entry,Slippage,sl,tp,"LONDON_NY_ORB",magic,0,arrowClr);
      if(ticket>0) return ticket;
      int err=GetLastError(); Print("SafeOrderSend: OrderSend with stops failed, error ",err,", attempt ",attempt+1);
      if(err==130)
      {  // step 2: ECN or market-execution broker, open naked then attach stops after fill
         RefreshRates();
         entry=NormalizeDouble(orderType==OP_BUY?Ask:Bid,digits);
         if(sl>0){ if(orderType==OP_BUY && entry-sl<minDist) sl=entry-minDist; if(orderType==OP_SELL && sl-entry<minDist) sl=entry+minDist; sl=NormalizeDouble(sl,digits); }
         if(tp>0){ if(orderType==OP_BUY && tp-entry<minDist) tp=entry+minDist; if(orderType==OP_SELL && entry-tp<minDist) tp=entry-minDist; tp=NormalizeDouble(tp,digits); }
         ticket=OrderSend(sym,orderType,lots,entry,Slippage,0,0,"LONDON_NY_ORB",magic,0,arrowClr);
         if(ticket>0)
         {
            if((sl>0||tp>0) && OrderSelect(ticket,SELECT_BY_TICKET))
               if(!OrderModify(ticket,OrderOpenPrice(),sl,tp,0,clrNONE)) Print("SafeOrderSend: ECN attach SL/TP failed (",GetLastError(),") ticket ",ticket);
            return ticket;
         }
         err=GetLastError(); Print("SafeOrderSend: naked OrderSend failed, error ",err,", attempt ",attempt+1);
      }
      if(err==131||err==132||err==133||err==134||err==139||err==148) break; // fatal: volume/money/disabled/locked/max orders
      Sleep(400+attempt*400);
   }
   return -1;
}

bool SafeOrderModify(int ticket,double newSL,double newTP,color arrowClr)
{
   if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
   int digits=BrokerDigits(); double pt=BrokerPoint(); double minDist=BrokerMinStopDist();
   double sl=NormalizeDouble(newSL,digits); double tp=NormalizeDouble(newTP,digits);
   double cur=(OrderType()==OP_BUY?Bid:Ask);
   if(sl>0 && MathAbs(cur-sl)<minDist) return false;  // too close -> broker would reject, wait next ticks
   if(tp>0 && MathAbs(tp-cur)<minDist) return false;
   int frz=BrokerFreezeLevel();
   if(frz>0 && MathAbs(cur-OrderOpenPrice())<frz*pt) return false; // inside freeze level
   if(sl==NormalizeDouble(OrderStopLoss(),digits) && tp==NormalizeDouble(OrderTakeProfit(),digits)) return true; // nothing to change
   if(!WaitTradeContext(1500)) return false;
   if(!OrderModify(ticket,OrderOpenPrice(),sl,tp,0,arrowClr)){ int e=GetLastError(); if(e!=1) Print("SafeOrderModify: failed (",e,") ticket ",ticket); return false; }
   return true;
}

bool SafeOrderClose(int ticket,double lots,color arrowClr)
{
   for(int attempt=0; attempt<2; attempt++)
   {
      if(!WaitTradeContext(1500)) continue;
      RefreshRates();
      if(!OrderSelect(ticket,SELECT_BY_TICKET)) return false;
      double p=NormalizeDouble(OrderType()==OP_BUY?Bid:Ask,BrokerDigits());
      if(OrderClose(ticket,lots,p,Slippage,arrowClr)) return true;
      int err=GetLastError(); Print("SafeOrderClose: failed (",err,") ticket ",ticket,", attempt ",attempt+1);
      if(err!=135 && err!=136 && err!=138) break; // retry only on price-change type errors
   }
   return false;
}

void ExecuteTradeMagic(int signal,double orbHigh,double orbLow,int magic)
{
   // Trading Logic Day Verification (المطلب الثاني)
   int currentDay = DayOfWeek();
   if(currentDay == 1 && !g_trade_day_mon) { Print("Trading is disabled for Monday via UI Panel."); return; }
   if(currentDay == 2 && !g_trade_day_tue) { Print("Trading is disabled for Tuesday via UI Panel."); return; }
   if(currentDay == 3 && !g_trade_day_wed) { Print("Trading is disabled for Wednesday via UI Panel."); return; }
   if(currentDay == 4 && !g_trade_day_thu) { Print("Trading is disabled for Thursday via UI Panel."); return; }
   if(currentDay == 5 && !g_trade_day_fri) { Print("Trading is disabled for Friday via UI Panel."); return; }

   double range=orbHigh-orbLow; double slPrice,tpPrice,entryPrice; int orderType;
   if(signal==1){ entryPrice=Ask; slPrice=UseIndicatorSL?orbLow:(Ask-FixedSL_Points*Point); tpPrice=entryPrice+range*TP2_RR; orderType=OP_BUY; }
   else { entryPrice=Bid; slPrice=UseIndicatorSL?orbHigh:(Bid+FixedSL_Points*Point); tpPrice=entryPrice-range*TP2_RR; orderType=OP_SELL; }
   double slPoints=MathAbs(entryPrice-slPrice)/Point; double lot=CalculateLotSize(slPoints); if(lot<=0)return;
   double combinedLot=lot*2.0; 
   
   // Lot Capping Clamp (المطلب الأول)
   double maxAllowedLot = MarketInfo(Symbol(), MODE_MAXLOT);
   if(maxAllowedLot > 0 && combinedLot > maxAllowedLot)
   {
      Print("Lot Size Capped: Combined Lot ", DoubleToString(combinedLot, 2), " exceeds MAXLOT (", DoubleToString(maxAllowedLot, 2), "). Clamping value while preserving internal calculations.");
      combinedLot = maxAllowedLot;
   }

   double marginOneLot=MarketInfo(Symbol(),MODE_MARGINREQUIRED);
   if(marginOneLot>0){ double requiredMargin=marginOneLot*combinedLot; double freeMargin=AccountFreeMargin(); if(freeMargin<requiredMargin){ double maxTotalLot=(freeMargin*0.9)/marginOneLot; double minLot=MarketInfo(Symbol(),MODE_MINLOT); double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP); combinedLot=MathFloor(maxTotalLot/lotStep)*lotStep; if(combinedLot<minLot)return; } }
   if(UseMaxLoss && combinedLot>0){ double tickValue=MarketInfo(Symbol(),MODE_TICKVALUE); double tickSize=MarketInfo(Symbol(),MODE_TICKSIZE); double pointValue=MarketInfo(Symbol(),MODE_POINT); if(tickSize>0 && pointValue>0){ double valuePerPoint=tickValue/(tickSize/pointValue); double ratio=(LotSize>0?(combinedLot/LotSize):1.0); double maxLossTotal=ScaleProfitMaxLoss?MaxLossUSD*ratio:MaxLossUSD; if(valuePerPoint>0){ double maxLossPoints=maxLossTotal/(combinedLot*valuePerPoint); if(signal==1){ double m=entryPrice-maxLossPoints*Point; if(slPrice<m||slPrice==0||!UseIndicatorSL)slPrice=m; } else { double m2=entryPrice+maxLossPoints*Point; if(slPrice>m2||slPrice==0||!UseIndicatorSL)slPrice=m2; } } } }
   int ticket=SafeOrderSend(orderType,combinedLot,entryPrice,slPrice,tpPrice,magic,signal==1?clrGreen:clrRed);
   if(ticket<=0) Print("ExecuteTradeMagic: order skipped after safe retries (see log above).");
}

void ProcessSessionTrading(int startM,int durM,int endHour,int magic,double &cachedHi,double &cachedLo,datetime &lastSig,int offset)
{
   ENUM_SESSION_ID sid = (offset < 0 ? SESSION_ID_NEWYORK : SESSION_ID_LONDON);
   AutoDST_ProcessSessionTrading(startM, durM, endHour, magic, cachedHi, cachedLo, lastSig, sid);
}

void ManageOpenTrades()
{
   for(int i=OrdersTotal()-1;i>=0;i--)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_TRADES))continue; if(OrderSymbol()!=Symbol()||!IsOurMagic(OrderMagicNumber()))continue;
      double entryPrice=OrderOpenPrice(); double currentSL=OrderStopLoss(); double currentTP=OrderTakeProfit(); double totalDist=MathAbs(currentTP-entryPrice); double oneR=(TP2_RR>0)?(totalDist/TP2_RR):0;
      if(oneR>0)
      {
         double tp1Dist=oneR*TP1_RR;
         if(OrderType()==OP_BUY){ double tp1Price=entryPrice+tp1Dist; if(Bid>=tp1Price){ bool ap=(StringFind(OrderComment(),"from #")>=0||StringFind(OrderComment(),"part")>=0); if(UseTP1_PartialClose && !ap && OrderLots()>MarketInfo(Symbol(),MODE_MINLOT)*1.5){ double cl=NormalizeDouble(OrderLots()*0.5,2); double minLot=MarketInfo(Symbol(),MODE_MINLOT); double lotStep=MarketInfo(Symbol(),MODE_LOTSTEP); cl=MathFloor(cl/lotStep)*lotStep; cl=MathMax(cl,minLot); if(OrderLots()-cl>=minLot) SafeOrderClose(OrderTicket(),cl,clrYellow); } if(MoveToBreakeven && (currentSL<entryPrice||currentSL==0)){ double newSL=entryPrice+1*Point; if(newSL<Bid) SafeOrderModify(OrderTicket(),newSL,currentTP,clrBlue); } } }
         else if(OrderType()==OP_SELL){ double tp1Price2=entryPrice-tp1Dist; if(Ask<=tp1Price2){ bool ap2=(StringFind(OrderComment(),"from #")>=0||StringFind(OrderComment(),"part")>=0); if(UseTP1_PartialClose && !ap2 && OrderLots()>MarketInfo(Symbol(),MODE_MINLOT)*1.5){ double cl2=NormalizeDouble(OrderLots()*0.5,2); double minLot2=MarketInfo(Symbol(),MODE_MINLOT); double lotStep2=MarketInfo(Symbol(),MODE_LOTSTEP); cl2=MathFloor(cl2/lotStep2)*lotStep2; cl2=MathMax(cl2,minLot2); if(OrderLots()-cl2>=minLot2) SafeOrderClose(OrderTicket(),cl2,clrYellow); } if(MoveToBreakeven && (currentSL>entryPrice||currentSL==0)){ double newSL2=entryPrice-1*Point; if(newSL2>Ask) SafeOrderModify(OrderTicket(),newSL2,currentTP,clrBlue); } } }
      }
      if(UseTrailingStop)
      {
         if(OrderType()==OP_BUY){ double pp=(Bid-entryPrice)/Point; if(pp>=TrailingStart){ double newSL3=Bid-TrailingDist*Point; if(newSL3>currentSL+TrailingStep*Point) SafeOrderModify(OrderTicket(),newSL3,OrderTakeProfit(),clrAqua); } }
         else if(OrderType()==OP_SELL){ double pp2=(entryPrice-Ask)/Point; if(pp2>=TrailingStart){ double newSL4=Ask+TrailingDist*Point; if(currentSL==0||newSL4<currentSL-TrailingStep*Point) SafeOrderModify(OrderTicket(),newSL4,OrderTakeProfit(),clrAqua); } }
      }
   }
}

double GetPeriodProfit(int periodMode)
{
   double profit=0; int cYear=TimeYear(TimeCurrent()); int cMonth=TimeMonth(TimeCurrent()); int cDay=TimeDay(TimeCurrent());
   for(int i=0;i<OrdersHistoryTotal();i++){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderType()>1)continue; if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber()))){ datetime ct=OrderCloseTime(); bool match=false; if(periodMode==0){ if(TimeYear(ct)==cYear&&TimeMonth(ct)==cMonth&&TimeDay(ct)==cDay)match=true; } else if(periodMode==1){ if(TimeYear(ct)==cYear&&TimeMonth(ct)==cMonth)match=true; } if(match)profit+=OrderProfit()+OrderSwap()+OrderCommission(); } } }
   return profit;
}

void GetDailyPLBreakdown(double &won,double &loss)
{
   won=0;loss=0; int cYear=TimeYear(TimeCurrent()); int cMonth=TimeMonth(TimeCurrent()); int cDay=TimeDay(TimeCurrent());
   for(int i=0;i<OrdersHistoryTotal();i++){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderType()>1)continue; if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber()))){ datetime ct=OrderCloseTime(); if(TimeYear(ct)==cYear&&TimeMonth(ct)==cMonth&&TimeDay(ct)==cDay){ double profit=OrderProfit()+OrderSwap()+OrderCommission(); if(profit>=0)won+=profit; else loss+=profit; } } } }
}

double GetActiveProfit(){ double profit=0; for(int i=0;i<OrdersTotal();i++) if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)) if(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber())) profit+=OrderProfit()+OrderSwap()+OrderCommission(); return profit; }

int GetDaysTraded(){ int days=0; datetime lastDay=0; for(int i=0;i<OrdersHistoryTotal();i++){ if(OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)){ if(OrderType()>1)continue; if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber()))){ datetime closeTime=OrderCloseTime(); datetime dayStart=closeTime-(closeTime%86400); if(dayStart!=lastDay){days++;lastDay=dayStart;} } } } return days; }

//====================================================================
// CHART DRAWINGS / TRADE LABELS
//====================================================================
void DrawSessionHistorical(int startH, int startM, int durM, int endH, int offset, string prefix, color hiClr, color loClr)
{
   color currentFillClr = (prefix == "LON" || prefix == "LON_") ? C_OrbFill_Lon : C_OrbFill_NY;
   if(DrawHistoryDays<=0)return; int barsCount=iBars(NULL,0); int daysCount=0; int currentBar=0;
   int startMin = startH * 60 + startM;
   int orbEndMin = startMin + durM;
   int sessEndMin = endH * 60;
   
   while(daysCount<DrawHistoryDays && currentBar<barsCount)
   {
      datetime barTime=iTime(NULL,0,currentBar); int year=TimeYear(barTime); int month=TimeMonth(barTime); int day=TimeDay(barTime);
      double hi=-1,lo=999999; datetime sessStart=0,sessEnd=0; bool dayFound=false,orbFound=false;
      while(currentBar<barsCount && TimeYear(iTime(NULL,0,currentBar))==year && TimeMonth(iTime(NULL,0,currentBar))==month && TimeDay(iTime(NULL,0,currentBar))==day)
      { datetime t=iTime(NULL,0,currentBar); int m=GetMinutesWithOffset(t, offset); if(m>=startMin && m<orbEndMin){ if(iHigh(NULL,0,currentBar)>hi)hi=iHigh(NULL,0,currentBar); if(iLow(NULL,0,currentBar)<lo)lo=iLow(NULL,0,currentBar); orbFound=true; } if(m>=startMin && m<sessEndMin){ if(sessEnd==0)sessEnd=t+PeriodSeconds(); sessStart=t; dayFound=true; } currentBar++; }
      if(dayFound && orbFound && hi>0 && lo<999999)
      {
         string dateStr=StringFormat("%d%02d%02d",year,month,day); string bName="ORB_Box_"+prefix+"_"+dateStr;
         if(ObjectFind(0,bName)<0)ObjectCreate(0,bName,OBJ_RECTANGLE,0,sessStart,hi,sessEnd,lo); else { ObjectSetInteger(0,bName,OBJPROP_TIME,0,sessStart); ObjectSetDouble(0,bName,OBJPROP_PRICE,0,hi); ObjectSetInteger(0,bName,OBJPROP_TIME,1,sessEnd); ObjectSetDouble(0,bName,OBJPROP_PRICE,1,lo); }
         ObjectSetInteger(0,bName,OBJPROP_COLOR,currentFillClr); ObjectSetInteger(0,bName,OBJPROP_FILL,UseOrbFill); ObjectSetInteger(0,bName,OBJPROP_BACK,true); ObjectSetInteger(0,bName,OBJPROP_SELECTABLE,false); ObjectSetInteger(0,bName,OBJPROP_HIDDEN,true);
         string hName="ORB_Lv_H_"+prefix+"_"+dateStr; if(ObjectFind(0,hName)<0)ObjectCreate(0,hName,OBJ_TREND,0,sessStart,hi,sessEnd,hi); else { ObjectSetInteger(0,hName,OBJPROP_TIME,0,sessStart); ObjectSetDouble(0,hName,OBJPROP_PRICE,0,hi); ObjectSetInteger(0,hName,OBJPROP_TIME,1,sessEnd); ObjectSetDouble(0,hName,OBJPROP_PRICE,1,hi); } ObjectSetInteger(0,hName,OBJPROP_COLOR,hiClr); ObjectSetInteger(0,hName,OBJPROP_WIDTH,OrbLineWidth); ObjectSetInteger(0,hName,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,hName,OBJPROP_BACK,true);
         string lName="ORB_Lv_L_"+prefix+"_"+dateStr; if(ObjectFind(0,lName)<0)ObjectCreate(0,lName,OBJ_TREND,0,sessStart,lo,sessEnd,lo); else { ObjectSetInteger(0,lName,OBJPROP_TIME,0,sessStart); ObjectSetDouble(0,lName,OBJPROP_PRICE,0,lo); ObjectSetInteger(0,lName,OBJPROP_TIME,1,sessEnd); ObjectSetDouble(0,lName,OBJPROP_PRICE,1,lo); } ObjectSetInteger(0,lName,OBJPROP_COLOR,loClr); ObjectSetInteger(0,lName,OBJPROP_WIDTH,OrbLineWidth); ObjectSetInteger(0,lName,OBJPROP_RAY_RIGHT,false); ObjectSetInteger(0,lName,OBJPROP_BACK,true);
         daysCount++;
      }
   }
}

void DrawHistoricalORBLevels()
{
   if(OrbTradeMode == MODE_LONDON_ONLY || OrbTradeMode == MODE_BOTH_SESSIONS)
      AutoDST_DrawSessionHistorical(Lon_Start_Hour, Lon_Start_Minute, Lon_Duration_Min, Lon_End_Hour, SESSION_ID_LONDON, "LON", C_OrbHi, C_OrbLo, C_OrbFill_Lon);

   if(OrbTradeMode == MODE_NY_ONLY || OrbTradeMode == MODE_BOTH_SESSIONS)
      AutoDST_DrawSessionHistorical(NY_Start_Hour, NY_Start_Minute, NY_Duration_Min, NY_End_Hour, SESSION_ID_NEWYORK, "NY", clrAqua, clrMagenta, C_OrbFill_NY);
}
void DrawTradeResult(int ticket,double profit,double price,datetime time,int count=1)
{
   if(!Badge_ShowBoxes) return;
   
   string tName = "Result_"    + IntegerToString(ticket);
   string bName = "BadgeBG_"   + IntegerToString(ticket);
   string pill  = "BadgePill_" + IntegerToString(ticket);
   string lName = "BadgeGlow_" + IntegerToString(ticket);
   string pName = "Pointer_"   + IntegerToString(ticket);
   
   double pip = Point; if(Digits==3 || Digits==5) pip = Point * 10.0;
   double chartSpan = WindowPriceMax(0) - WindowPriceMin(0);
   double inpPipsH  = (double)MathMax(10, Badge_BoxHalfHeightPips) * pip;
   double scaledH   = (chartSpan > 0) ? (chartSpan * 0.022) : inpPipsH;
   double boxHalfH  = MathMax(inpPipsH, scaledH);
   double minSafeDist = boxHalfH * 2.4;
   double baseOffset  = (profit >= 0) ? boxHalfH * 2.2 : -boxHalfH * 2.2;
   double candidateY  = price + baseOffset;
   int    curBar      = iBarShift(NULL, 0, time);
   
   bool hasCollision = true;
   int  safetyCounter = 0;
   while(hasCollision && safetyCounter < 15)
   {
      hasCollision = false;
      for(int k = 0; k < g_repNodesCount; k++)
      {
         int barDist = MathAbs(curBar - g_repNodes[k].barShift);
         if(barDist <= Badge_BoxWidthBars)
         {
            double vertDist = MathAbs(candidateY - g_repNodes[k].drawnPrice);
            if(vertDist < minSafeDist)
            {
               hasCollision = true;
               if(profit >= 0) candidateY = g_repNodes[k].drawnPrice + minSafeDist;
               else            candidateY = g_repNodes[k].drawnPrice - minSafeDist;
               break;
            }
         }
      }
      safetyCounter++;
   }
   
   ArrayResize(g_repNodes, g_repNodesCount + 1);
   g_repNodes[g_repNodesCount].time       = time;
   g_repNodes[g_repNodesCount].drawnPrice = candidateY;
   g_repNodes[g_repNodesCount].barShift   = curBar;
   g_repNodesCount++;
   
   color profitClr = (profit>=0 ? Badge_WinLineColor : Badge_LossLineColor);
   color textClr   = (profit>=0 ? Badge_WinTextColor : Badge_LossTextColor);
   color greyCard  = Badge_BoxColor;
   
   long barSec = PeriodSeconds(); if(barSec<=0) barSec = 60;
   int halfBars = MathMax(1, Badge_BoxWidthBars / 2);
   datetime t1 = time - (datetime)(barSec * halfBars);
   datetime t2 = time + (datetime)(barSec * halfBars);
   double   pTop    = candidateY + boxHalfH;
   double   pBottom = candidateY - boxHalfH;
   
   if(ObjectFind(0, bName) < 0)
   {
      if(ObjectFind(0, tName) >= 0) ObjectDelete(0, tName);
      ObjectCreate(0, bName, OBJ_RECTANGLE, 0, t1, pTop, t2, pBottom);
      ObjectCreate(0, pill,  OBJ_TEXT,      0, time, candidateY);
      ObjectCreate(0, lName, OBJ_TREND,     0, t1, pTop, t2, pTop);
      ObjectCreate(0, tName, OBJ_TEXT,      0, time, candidateY);
   }
   
   ObjectSetInteger(0, bName, OBJPROP_TIME, 0, t1); ObjectSetDouble(0, bName, OBJPROP_PRICE, 0, pTop);
   ObjectSetInteger(0, bName, OBJPROP_TIME, 1, t2); ObjectSetDouble(0, bName, OBJPROP_PRICE, 1, pBottom);
   bool backLayer = Badge_DrawBehindPanel;
   ObjectSetInteger(0, bName, OBJPROP_COLOR, greyCard);
   ObjectSetInteger(0, bName, OBJPROP_FILL, true);
   ObjectSetInteger(0, bName, OBJPROP_BACK, backLayer);
   ObjectSetInteger(0, bName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, bName, OBJPROP_HIDDEN, true);
   
   ObjectSetInteger(0, pill, OBJPROP_TIME, 0, time); ObjectSetDouble(0, pill, OBJPROP_PRICE, 0, candidateY);
   string pillBlock = ""; StringInit(pillBlock, 10, 0x2588);
   ObjectSetString(0, pill, OBJPROP_TEXT, pillBlock);
   ObjectSetInteger(0, pill, OBJPROP_COLOR, greyCard);
   ObjectSetInteger(0, pill, OBJPROP_FONTSIZE, Badge_FontSize + 4);
   ObjectSetString(0, pill, OBJPROP_FONT, "Segoe UI");
   ObjectSetInteger(0, pill, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, pill, OBJPROP_BACK, backLayer);
   ObjectSetInteger(0, pill, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, pill, OBJPROP_HIDDEN, true);
   
   ObjectSetInteger(0, lName, OBJPROP_TIME, 0, t1); ObjectSetDouble(0, lName, OBJPROP_PRICE, 0, pTop);
   ObjectSetInteger(0, lName, OBJPROP_TIME, 1, t2); ObjectSetDouble(0, lName, OBJPROP_PRICE, 1, pTop);
   ObjectSetInteger(0, lName, OBJPROP_COLOR, profitClr);
   ObjectSetInteger(0, lName, OBJPROP_WIDTH, 3);
   ObjectSetInteger(0, lName, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, lName, OBJPROP_BACK, backLayer);
   ObjectSetInteger(0, lName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, lName, OBJPROP_HIDDEN, true);
   
   double dispProfit = DisplayDZD ? profit * USD_DZD_Rate : profit;
   string cntStr     = (count > 1) ? " (" + IntegerToString(count) + ")" : "";
   string text = DisplayDZD ? ((dispProfit>=0?"+":"-")+DoubleToString(MathAbs(dispProfit),0)+" DZD"+cntStr) : ((dispProfit>=0?"+$":"-$")+DoubleToString(MathAbs(dispProfit),2)+cntStr);
   
   ObjectSetInteger(0, tName, OBJPROP_TIME, 0, time); ObjectSetDouble(0, tName, OBJPROP_PRICE, 0, candidateY);
   ObjectSetString(0, tName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, tName, OBJPROP_COLOR, textClr);
   ObjectSetInteger(0, tName, OBJPROP_FONTSIZE, Badge_FontSize);
   ObjectSetString(0, tName, OBJPROP_FONT, Badge_FontName);
   ObjectSetInteger(0, tName, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, tName, OBJPROP_BACK, backLayer);
   ObjectSetInteger(0, tName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, tName, OBJPROP_HIDDEN, true);
   
   if(MathAbs(candidateY - price) > boxHalfH * 1.5)
   {
      double attachY = (candidateY > price) ? pBottom : pTop;
      if(ObjectFind(0, pName) < 0) ObjectCreate(0, pName, OBJ_TREND, 0, time, price, time, attachY);
      else {
         ObjectSetInteger(0, pName, OBJPROP_TIME, 0, time); ObjectSetDouble(0, pName, OBJPROP_PRICE, 0, price);
         ObjectSetInteger(0, pName, OBJPROP_TIME, 1, time); ObjectSetDouble(0, pName, OBJPROP_PRICE, 1, attachY);
      }
      ObjectSetInteger(0, pName, OBJPROP_COLOR, profitClr);
      ObjectSetInteger(0, pName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, pName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, pName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, pName, OBJPROP_BACK, true);
      ObjectSetInteger(0, pName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, pName, OBJPROP_HIDDEN, true);
   }
   else if(ObjectFind(0, pName) >= 0) ObjectDelete(0, pName);
}

void CheckClosedTrades()
{
   g_repNodesCount = 0; ArrayFree(g_repNodes);
   int historyTotal = OrdersHistoryTotal(); int start = MathMax(0, historyTotal - 50);
   
   int procTickets[]; int procCount = 0;
   
   for(int i = start; i < historyTotal; i++)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY)) continue;
      if(OrderSymbol() != Symbol() || OrderType() > 1) continue;
      if(!GlobalHistory && !IsOurMagic(OrderMagicNumber())) continue;
      
      int ticket = OrderTicket();
      bool skip = false;
      for(int p=0; p<procCount; p++) if(procTickets[p] == ticket){ skip=true; break; }
      if(skip) continue;
      
      datetime closeTime   = OrderCloseTime();
      double   totalProfit = OrderProfit() + OrderSwap() + OrderCommission();
      double   drawPrice   = OrderClosePrice();
      int      clusterCnt  = 1;
      
      ArrayResize(procTickets, procCount + 1);
      procTickets[procCount++] = ticket;
      
      for(int k = i + 1; k < historyTotal; k++)
      {
         if(!OrderSelect(k, SELECT_BY_POS, MODE_HISTORY)) continue;
         if(OrderSymbol() != Symbol() || OrderType() > 1) continue;
         if(!GlobalHistory && !IsOurMagic(OrderMagicNumber())) continue;
         
         if(MathAbs(OrderCloseTime() - closeTime) < 180 || iBarShift(NULL,0,OrderCloseTime()) == iBarShift(NULL,0,closeTime))
         {
            int sibTicket = OrderTicket();
            bool sibSkip = false;
            for(int p2=0; p2<procCount; p2++) if(procTickets[p2] == sibTicket){ sibSkip=true; break; }
            if(!sibSkip){
               totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
               clusterCnt++;
               ArrayResize(procTickets, procCount + 1);
               procTickets[procCount++] = sibTicket;
            }
         }
      }
      
      DrawTradeResult(ticket, totalProfit, drawPrice, closeTime, clusterCnt);
   }
   
   int objTotal = ObjectsTotal(0, -1, -1);
   for(int j = objTotal - 1; j >= 0; j--)
   {
      string oName = ObjectName(0, j, -1);
      if(StringLen(oName) > 0 && StringGetChar(oName, 0) == '#')
      {
         ObjectSetInteger(0, oName, OBJPROP_BACK, true);
      }
   }
   
   ChartRedraw(0);
}

//====================================================================
// HTML EXPORT HELPERS
//====================================================================
void jsEqDataAdd(string &labels,string &data,string label,double val)
{ if(StringLen(labels)>0) labels+=","; labels+="'"+label+"'"; if(StringLen(data)>0) data+=","; data+=DoubleToString(val,2); }
void jsDailyAdd(string &labels,string &data,string &colors,string label,double val)
{ if(StringLen(labels)>0) labels+=","; labels+="'"+label+"'"; if(StringLen(data)>0) data+=","; data+=DoubleToString(val,2); if(StringLen(colors)>0) colors+=","; colors+=(val>=0)?"'#10b981'":"'#ef4444'"; }
void jsValAdd(string &arr,double v){ if(StringLen(arr)>0) arr+=","; arr+=DoubleToString(v,2); }

//====================================================================
// SAVE HISTORY TO HTML (Multilingual EN/AR + Dark/Light + DZD/USD)
//====================================================================
void SaveTradeHistoryToHTML()
{
   string filename="Trading_History_Report.html";
   int handle=FileOpen(filename,FILE_BIN|FILE_WRITE|FILE_ANSI);
   if(handle==INVALID_HANDLE){ Alert("Error creating file: ",GetLastError()); return; }
   string jsEqLabels="",jsEqData="",jsDailyLabels="",jsDailyData="",jsHourData="",jsDayData="";
   string jsWinsCum="",jsLossCum="",jsDDseries="",jsOutcomes="",jsTradesArr="";
   double balance=0,peakBalance=0,maxDD=0,grossProfit=0,grossLoss=0,netProfit=0;
   int wins=0,losses=0,totalTrades=0,buyTrades=0,sellTrades=0;
   double bestTrade=-DBL_MAX,worstTrade=DBL_MAX,totalPips=0;
   int currentStreak=0,maxWinStreak=0,maxLossStreak=0; bool lastWasWin=false;
   double hourProfit[24]; ArrayInitialize(hourProfit,0);
   double dayProfit[7]; ArrayInitialize(dayProfit,0);
   double cumWins=0,cumLoss=0; datetime currentDay=0; double currentDayProfit=0; string _dummyColors="";
   
   double rate = DisplayDZD ? USD_DZD_Rate : 1.0;
   string cSym = DisplayDZD ? "DA " : "$";
   jsEqDataAdd(jsEqLabels,jsEqData,"Start",0); jsValAdd(jsWinsCum,0); jsValAdd(jsLossCum,0); jsValAdd(jsDDseries,0);
   int historyTotal=OrdersHistoryTotal();
   for(int i=0;i<historyTotal;i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(!(GlobalHistory || (OrderSymbol()==Symbol() && IsOurMagic(OrderMagicNumber())))) continue;
      if(OrderType()>1) continue;
      double profit=(OrderProfit()+OrderSwap()+OrderCommission()) * rate; datetime tclose=OrderCloseTime();
      netProfit+=profit; balance+=profit; if(balance>peakBalance) peakBalance=balance;
      double dd=peakBalance-balance; if(dd>maxDD) maxDD=dd;
      if(profit>bestTrade) bestTrade=profit; if(profit<worstTrade) worstTrade=profit;
      if(profit>=0){ grossProfit+=profit; cumWins+=profit; wins++; if(lastWasWin) currentStreak++; else { lastWasWin=true; currentStreak=1; } if(currentStreak>maxWinStreak) maxWinStreak=currentStreak; }
      else { grossLoss+=profit; cumLoss+=MathAbs(profit); losses++; if(!lastWasWin) currentStreak++; else { lastWasWin=false; currentStreak=1; } if(currentStreak>maxLossStreak) maxLossStreak=currentStreak; }
      if(OrderType()==OP_BUY) buyTrades++; else sellTrades++; totalTrades++;
      double diff=MathAbs(OrderOpenPrice()-OrderClosePrice()); double pips=diff/Point; if(Digits==3||Digits==5) pips/=10.0;
      if((OrderType()==OP_BUY && OrderClosePrice()<OrderOpenPrice())||(OrderType()==OP_SELL && OrderClosePrice()>OrderOpenPrice())) pips=-pips;
      totalPips+=pips;
      hourProfit[TimeHour(tclose)]+=profit; dayProfit[TimeDayOfWeek(tclose)]+=profit;
      jsEqDataAdd(jsEqLabels,jsEqData,TimeToString(tclose,TIME_DATE|TIME_MINUTES),balance);
      jsValAdd(jsWinsCum,cumWins); jsValAdd(jsLossCum,cumLoss); jsValAdd(jsDDseries,-dd);
      datetime day=tclose-(tclose%86400);
      if(day!=currentDay){ if(currentDay!=0) jsDailyAdd(jsDailyLabels,jsDailyData,_dummyColors,TimeToString(currentDay,TIME_DATE),currentDayProfit); currentDay=day; currentDayProfit=0; }
      currentDayProfit+=profit;
   }
   if(currentDay!=0) jsDailyAdd(jsDailyLabels,jsDailyData,_dummyColors,TimeToString(currentDay,TIME_DATE),currentDayProfit);
   for(int h=0;h<24;h++){ if(StringLen(jsHourData)>0) jsHourData+=","; jsHourData+=DoubleToString(hourProfit[h],2); }
   for(int d=0;d<7;d++){ if(StringLen(jsDayData)>0) jsDayData+=","; jsDayData+=DoubleToString(dayProfit[d],2); }
   int kept=0;
   for(int i2=historyTotal-1;i2>=0 && kept<30;i2--)
   {
      if(!OrderSelect(i2,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(!(GlobalHistory || (OrderSymbol()==Symbol() && IsOurMagic(OrderMagicNumber())))) continue;
      if(OrderType()>1) continue;
      double p=(OrderProfit()+OrderSwap()+OrderCommission()) * rate; jsValAdd(jsOutcomes,p); kept++;
   }
   for(int i3=historyTotal-1;i3>=0;i3--)
   {
      if(!OrderSelect(i3,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(!(GlobalHistory || (OrderSymbol()==Symbol() && IsOurMagic(OrderMagicNumber())))) continue;
      if(OrderType()>1) continue;
      double profit=(OrderProfit()+OrderSwap()+OrderCommission()) * rate; double diff=MathAbs(OrderOpenPrice()-OrderClosePrice()); double pips=diff/Point; if(Digits==3||Digits==5) pips/=10.0;
      if((OrderType()==OP_BUY && OrderClosePrice()<OrderOpenPrice())||(OrderType()==OP_SELL && OrderClosePrice()>OrderOpenPrice())) pips=-pips;
      string ttype=(OrderType()==OP_BUY)?"BUY":"SELL";
      if(StringLen(jsTradesArr)>0) jsTradesArr+=",";
      jsTradesArr+=StringFormat("{\"ticket\":%d,\"symbol\":\"%s\",\"type\":\"%s\",\"lots\":\"%.2f\",\"open\":\"%.5f\",\"close\":\"%.5f\",\"pips\":%.1f,\"profit\":%.2f,\"time\":\"%s\"}",
         OrderTicket(),OrderSymbol(),ttype,OrderLots(),OrderOpenPrice(),OrderClosePrice(),pips,profit,TimeToString(OrderCloseTime(),TIME_DATE|TIME_MINUTES));
   }
   double avgWin=(wins>0)?grossProfit/wins:0; double avgLoss=(losses>0)?MathAbs(grossLoss)/losses:0;
   double profitFactor=(MathAbs(grossLoss)>0)?grossProfit/MathAbs(grossLoss):0;
   double winRate=(totalTrades>0)?((double)wins/totalTrades*100.0):0;
   double expectancy=(winRate/100.0*avgWin)-((1.0-winRate/100.0)*avgLoss);
   double recoveryFactor=(maxDD>0)?netProfit/maxDD:0; double avgRR=(avgLoss!=0)?avgWin/avgLoss:0;
   int buyPct=(totalTrades>0)?(int)(buyTrades*100.0/totalTrades):0; int sellPct=(totalTrades>0)?(int)(sellTrades*100.0/totalTrades):0;
   if(bestTrade==-DBL_MAX) bestTrade=0; if(worstTrade==DBL_MAX) worstTrade=0;
   int winPct=(totalTrades>0)?(int)(wins*100.0/totalTrades):0; int lossPct=(totalTrades>0)?(int)(losses*100.0/totalTrades):0;
   string genTime=TimeToString(TimeCurrent(),TIME_DATE|TIME_MINUTES);
   double accBalance=AccountBalance() * rate;
   double accEquity=AccountEquity() * rate;
   string head="<!DOCTYPE html><html lang='en' data-theme='dark' dir='ltr'><head><meta charset='UTF-8'><meta name='viewport' content='width=device-width,initial-scale=1.0'><title>London Session ORB - Analytics Report</title>";
   head+="<link href='https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700;800;900&family=Tajawal:wght@300;400;500;700;800;900&family=JetBrains+Mono:wght@500;700&display=swap' rel='stylesheet'>";
   head+="<style>*,*::before,*::after{box-sizing:border-box;margin:0;padding:0}";
   head+=":root[data-theme='dark']{--bg0:#020617;--bg2:#0f172a;--card:rgba(15,23,42,0.72);--card-solid:#0f172a;--border:rgba(71,85,105,0.35);--border-strong:rgba(100,116,139,0.55);--border-glow:rgba(59,130,246,0.35);--accent:#3b82f6;--accent2:#60a5fa;--accent-dim:rgba(59,130,246,0.14);--success:#10b981;--success-dim:rgba(16,185,129,0.14);--danger:#ef4444;--danger-dim:rgba(239,68,68,0.14);--warn:#f59e0b;--warn-dim:rgba(245,158,11,0.14);--purple:#8b5cf6;--purple-dim:rgba(139,92,246,0.14);--cyan:#06b6d4;--pink:#ec4899;--text0:#f8fafc;--text1:#cbd5e1;--text2:#94a3b8;--text3:#475569;--radius:18px;--shadow-glow:0 0 60px rgba(59,130,246,0.08);--grid-line:rgba(148,163,184,0.08);--tooltip-bg:rgba(2,6,23,0.96);}";
   head+=":root[data-theme='light']{--bg0:#f1f5f9;--bg2:#f8fafc;--card:rgba(255,255,255,0.85);--card-solid:#ffffff;--border:rgba(203,213,225,0.7);--border-strong:rgba(148,163,184,0.6);--border-glow:rgba(59,130,246,0.35);--accent:#2563eb;--accent2:#3b82f6;--accent-dim:rgba(59,130,246,0.10);--success:#059669;--success-dim:rgba(5,150,105,0.10);--danger:#dc2626;--danger-dim:rgba(220,38,38,0.10);--warn:#d97706;--warn-dim:rgba(217,119,6,0.10);--purple:#7c3aed;--purple-dim:rgba(124,58,237,0.10);--cyan:#0891b2;--pink:#db2777;--text0:#0f172a;--text1:#334155;--text2:#64748b;--text3:#cbd5e1;--radius:18px;--shadow-glow:0 4px 30px rgba(15,23,42,0.06);--grid-line:rgba(15,23,42,0.06);--tooltip-bg:rgba(15,23,42,0.95);}";
   head+="body{background:var(--bg0);color:var(--text0);font-family:'Inter',system-ui,sans-serif;font-size:14px;line-height:1.6;min-height:100vh;transition:.35s}html[dir='rtl'] body{font-family:'Tajawal','Inter',sans-serif}";
   head+=".wrap{max-width:1480px;margin:0 auto;padding:28px 24px 60px}.site-header{display:flex;align-items:center;justify-content:space-between;gap:20px;padding:24px 28px;margin-bottom:28px;background:var(--card);border:1px solid var(--border);border-radius:var(--radius);flex-wrap:wrap}";
   head+=".logo-block{display:flex;align-items:center;gap:14px}.logo-mark{width:48px;height:48px;border-radius:14px;background:linear-gradient(135deg,var(--accent),var(--purple));display:flex;align-items:center;justify-content:center}.logo-mark svg{width:26px;height:26px;color:#fff}.logo-title{font-size:18px;font-weight:800;background:linear-gradient(135deg,var(--accent2),var(--purple));-webkit-background-clip:text;-webkit-text-fill-color:transparent;background-clip:text}.logo-sub{font-size:11px;color:var(--text2);font-weight:600;letter-spacing:1.8px;text-transform:uppercase}";
   head+=".toolbar{display:flex;align-items:center;gap:10px;flex-wrap:wrap}.tool-btn{display:inline-flex;align-items:center;gap:8px;background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:9px 14px;color:var(--text1);cursor:pointer;font-family:inherit;font-size:12px;font-weight:600}.tool-btn:hover{border-color:var(--accent);color:var(--accent2)}.tool-btn svg{width:16px;height:16px}.lang-group{display:inline-flex;background:var(--bg2);border:1px solid var(--border);border-radius:10px;padding:3px;gap:2px}.lang-group .tool-btn{border:none;background:transparent;padding:7px 12px}.lang-group .tool-btn.active{background:var(--accent);color:#fff}";
   head+=".header-badge{display:inline-flex;align-items:center;gap:10px;background:var(--success-dim);border:1px solid rgba(16,185,129,0.4);border-radius:40px;padding:8px 16px;font-size:11px;color:var(--success);font-weight:700}.dot-live{width:8px;height:8px;border-radius:50%;background:var(--success);animation:pulse 1.6s infinite}@keyframes pulse{0%,100%{opacity:1}50%{opacity:.45}}";
   head+=".section-title{display:flex;align-items:center;gap:10px;font-size:11px;font-weight:800;letter-spacing:2.5px;text-transform:uppercase;color:var(--text2);margin:8px 2px 16px}.section-title svg{width:14px;height:14px;color:var(--accent2)}";
   head+=".grid-4{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:24px}.grid-5{display:grid;grid-template-columns:repeat(5,1fr);gap:16px;margin-bottom:24px}.grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:24px}.grid-2-1{display:grid;grid-template-columns:2fr 1fr;gap:16px;margin-bottom:24px}@media(max-width:1100px){.grid-5,.grid-4,.grid-3{grid-template-columns:repeat(2,1fr)}.grid-2-1{grid-template-columns:1fr}}@media(max-width:680px){.grid-5,.grid-4,.grid-3,.grid-2-1{grid-template-columns:1fr}}";
   head+=".card{background:var(--card);border:1px solid var(--border);border-radius:var(--radius);padding:22px;position:relative;overflow:hidden}.card:hover{border-color:var(--border-glow);box-shadow:var(--shadow-glow)}.card-title{display:flex;align-items:center;gap:10px;font-size:13px;font-weight:700;color:var(--text0);margin-bottom:18px}.card-title .dot{width:8px;height:8px;border-radius:50%}.card-title svg{width:16px;height:16px;color:var(--accent2)}.card-title .spacer{flex:1}.card-title .pill{font-size:10px;font-weight:700;padding:3px 8px;border-radius:6px;text-transform:uppercase;background:var(--accent-dim);color:var(--accent2)}";
   head+=".kpi-hero{display:flex;flex-direction:column;justify-content:space-between;min-height:140px}.kpi-top{display:flex;align-items:center;justify-content:space-between;margin-bottom:14px}.kpi-icon{width:44px;height:44px;border-radius:12px;display:flex;align-items:center;justify-content:center;background:var(--accent-dim);color:var(--accent2)}.kpi-icon svg{width:22px;height:22px}.kpi-trend{font-size:11px;font-weight:700;padding:4px 10px;border-radius:20px;display:inline-flex;align-items:center;gap:4px}.kpi-trend.up{background:var(--success-dim);color:var(--success)}.kpi-trend.down{background:var(--danger-dim);color:var(--danger)}.kpi-trend svg{width:12px;height:12px}.kpi-label{font-size:11px;font-weight:700;letter-spacing:1.4px;text-transform:uppercase;color:var(--text2);margin-bottom:4px}.kpi-value{font-family:'JetBrains Mono',monospace;font-size:30px;font-weight:800;line-height:1.05}.kpi-sub{font-size:12px;color:var(--text2);margin-top:8px}";
   head+=".kpi-accent-blue .kpi-icon{background:var(--accent-dim);color:var(--accent2)}.kpi-accent-blue .kpi-value{color:var(--accent2)}.kpi-accent-green .kpi-icon{background:var(--success-dim);color:var(--success)}.kpi-accent-green .kpi-value{color:var(--success)}.kpi-accent-red .kpi-icon{background:var(--danger-dim);color:var(--danger)}.kpi-accent-red .kpi-value{color:var(--danger)}";
   head+=".stat-row{display:flex;justify-content:space-between;align-items:center;padding:11px 0;border-bottom:1px dashed var(--border)}.stat-row:last-child{border-bottom:none}.stat-key{display:inline-flex;align-items:center;gap:8px;font-size:12.5px;color:var(--text2)}.stat-key .dotc{width:9px;height:9px;border-radius:50%}.stat-val{font-family:'JetBrains Mono',monospace;font-size:13px;font-weight:700;color:var(--text0)}";
   head+=".prog-wrap{margin-top:8px;margin-bottom:6px}.prog-bar-bg{background:var(--bg2);border-radius:6px;height:8px;overflow:hidden;border:1px solid var(--border)}.prog-bar{height:100%;border-radius:6px}.prog-blue{background:linear-gradient(90deg,var(--accent),var(--cyan))}.prog-green{background:linear-gradient(90deg,var(--success),#34d399)}.prog-red{background:linear-gradient(90deg,#dc2626,var(--danger))}";
   head+=".chart-wrap{position:relative;height:300px;width:100%}.chart-wrap-sm{position:relative;height:220px;width:100%}.chart-svg{width:100%;height:100%;display:block}.chart-tooltip{position:absolute;pointer-events:none;background:var(--tooltip-bg);color:#fff;font-family:'JetBrains Mono',monospace;font-size:11px;font-weight:600;padding:8px 12px;border-radius:8px;border:1px solid var(--border-strong);opacity:0;transform:translate(-50%,-130%);transition:opacity .15s;z-index:50;white-space:nowrap}.chart-tooltip.show{opacity:1}";
   head+=".donut-legend{display:flex;flex-direction:column;gap:10px;margin-top:14px}.donut-legend-item{display:flex;align-items:center;gap:10px;font-size:12.5px}.donut-legend-color{width:12px;height:12px;border-radius:4px}.donut-legend-label{flex:1;color:var(--text1)}.donut-legend-val{font-family:'JetBrains Mono',monospace;color:var(--text0);font-weight:700}";
   head+=".indicator-grid{display:grid;grid-template-columns:repeat(10,1fr);gap:8px;margin-top:8px}.indicator-circle{aspect-ratio:1/1;border-radius:50%;transition:transform .2s}.indicator-circle:hover{transform:scale(1.15)}";
   head+=".badge{display:inline-flex;align-items:center;gap:5px;padding:4px 10px;border-radius:6px;font-size:10.5px;font-weight:700;text-transform:uppercase;font-family:'JetBrains Mono',monospace}.badge-buy{background:var(--accent-dim);color:var(--accent2)}.badge-sell{background:var(--danger-dim);color:var(--danger)}";
   head+=".tbl-wrap{overflow-x:auto}table{width:100%;border-collapse:collapse}thead tr{background:var(--bg2)}th{padding:13px 14px;font-size:10.5px;font-weight:800;letter-spacing:1.4px;text-transform:uppercase;color:var(--text2);white-space:nowrap;border-bottom:1px solid var(--border);text-align:start}tbody tr:hover{background:var(--accent-dim)}td{padding:12px 14px;border-bottom:1px solid var(--border);font-size:13px;color:var(--text1);white-space:nowrap;text-align:start}td.mono{font-family:'JetBrains Mono',monospace}.pos{color:var(--success)}.neg{color:var(--danger)}.muted{color:var(--text2)}";
   head+=".filter-row{display:flex;gap:8px;margin-bottom:18px;align-items:center;flex-wrap:wrap}.filter-label{font-size:11px;color:var(--text2);font-weight:700;text-transform:uppercase}.filter-btn{background:transparent;border:1px solid var(--border);border-radius:8px;padding:7px 14px;color:var(--text2);cursor:pointer;font-family:inherit;font-size:11.5px;font-weight:600;display:inline-flex;align-items:center;gap:6px}.filter-btn:hover{border-color:var(--accent);color:var(--accent2)}.filter-btn.active{border-color:var(--accent);color:#fff;background:var(--accent)}.filter-btn svg{width:13px;height:13px}";
   head+=".divider-label{display:flex;align-items:center;gap:14px;margin:8px 0 18px}.divider-label span{font-size:11px;font-weight:800;letter-spacing:2.5px;text-transform:uppercase;color:var(--text2);display:inline-flex;align-items:center;gap:8px}.divider-label span svg{width:14px;height:14px;color:var(--accent2)}.divider-label::before,.divider-label::after{content:'';flex:1;height:1px;background:var(--border)}";
   head+=".site-footer{text-align:center;padding:32px 0;color:var(--text2);font-size:12px;margin-top:40px;border-top:1px solid var(--border);display:flex;flex-direction:column;gap:8px;align-items:center}.site-footer .brand{font-weight:700;color:var(--text1);display:inline-flex;align-items:center;gap:8px}.site-footer .brand svg{width:14px;height:14px;color:var(--accent2)}";
   head+="html[dir='rtl'] .kpi-value,html[dir='rtl'] .stat-val,html[dir='rtl'] td.mono{direction:ltr;unicode-bidi:embed;display:inline-block}</style></head>";
   FileWriteString(handle,head);
   string body="<body><div class='wrap'><header class='site-header'><div class='logo-block'>";
   body+="<div class='logo-mark'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.2'><path d='M3 3v18h18'/><path d='M7 14l4-4 4 4 5-5'/></svg></div>";
   body+="<div class='logo-text'><div class='logo-title' data-i18n='title'>LONDON SESSION ORB</div><div class='logo-sub' data-i18n='subtitle'>Advanced Analytics Report • AIT CHIKH MUSTAPHA</div></div></div>";
   body+="<div class='toolbar'><div class='lang-group'><button class='tool-btn active' id='langEn' type='button'>EN</button><button class='tool-btn' id='langAr' type='button'>ع</button></div>";
   body+="<button class='tool-btn' id='themeToggle' type='button'><svg id='themeIcon' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='4'/><path d='M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41'/></svg><span id='themeLabel' data-i18n='theme_dark'>Dark</span></button>";
   body+="<div class='header-badge'><div class='dot-live'></div><span><span data-i18n='generated'>Generated</span>: "+genTime+"</span></div></div></header>";
   body+="<div class='section-title'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><polygon points='13 2 3 14 12 14 11 22 21 10 12 10 13 2'/></svg><span data-i18n='perf_summary'>Performance Summary</span></div><div class='grid-5'>";
   FileWriteString(handle,body);
   string npCls=(netProfit>=0)?"kpi-accent-green":"kpi-accent-red"; string npSign=(netProfit>=0)?"+":"-";
   string tUp="<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.5'><polyline points='23 6 13.5 15.5 8.5 10.5 1 18'/><polyline points='17 6 23 6 23 12'/></svg>";
   string tDn="<svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2.5'><polyline points='23 18 13.5 8.5 8.5 13.5 1 6'/><polyline points='17 18 23 18 23 12'/></svg>";
   string npTrend=(netProfit>=0)?("<span class='kpi-trend up'>"+tUp+"+P/L</span>"):("<span class='kpi-trend down'>"+tDn+"-P/L</span>");
   FileWriteString(handle,"<div class='card kpi-hero "+npCls+"'><div class='kpi-top'><div class='kpi-icon'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 2v20M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6'/></svg></div>"+npTrend+"</div><div><div class='kpi-label' data-i18n='net_profit'>Net Profit</div><div class='kpi-value'>"+npSign+cSym+DoubleToString(MathAbs(netProfit),2)+"</div><div class='kpi-sub'><span data-i18n='recovery_factor'>Recovery Factor</span>: "+DoubleToString(recoveryFactor,2)+"x</div></div></div>");
   string wrCls=(winRate>=55)?"kpi-accent-green":(winRate>=45?"kpi-accent-blue":"kpi-accent-red");
   FileWriteString(handle,"<div class='card kpi-hero "+wrCls+"'><div class='kpi-top'><div class='kpi-icon'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><circle cx='12' cy='12' r='6'/><circle cx='12' cy='12' r='2'/></svg></div></div><div><div class='kpi-label' data-i18n='win_rate'>Win Rate</div><div class='kpi-value'>"+DoubleToString(winRate,1)+"%</div><div class='kpi-sub'>"+IntegerToString(wins)+" <span data-i18n='wins'>Wins</span> / "+IntegerToString(losses)+" <span data-i18n='losses'>Losses</span></div></div></div>");
   string pfCls=(profitFactor>=1.5)?"kpi-accent-green":(profitFactor>=1.0?"kpi-accent-blue":"kpi-accent-red");
   FileWriteString(handle,"<div class='card kpi-hero "+pfCls+"'><div class='kpi-top'><div class='kpi-icon'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M12 20V10M18 20V4M6 20v-6'/></svg></div></div><div><div class='kpi-label' data-i18n='profit_factor'>Profit Factor</div><div class='kpi-value'>"+DoubleToString(profitFactor,2)+"</div><div class='kpi-sub'><span data-i18n='expectancy'>Expectancy</span>: "+cSym+DoubleToString(expectancy,2)+"/<span data-i18n='trade_unit_short'>trade</span></div></div></div>");
   FileWriteString(handle,"<div class='card kpi-hero kpi-accent-red'><div class='kpi-top'><div class='kpi-icon'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M3 3v18h18'/><path d='M7 10l4 4 4-4 5 5'/></svg></div></div><div><div class='kpi-label' data-i18n='max_dd'>Max Drawdown</div><div class='kpi-value'>-"+cSym+DoubleToString(maxDD,2)+"</div><div class='kpi-sub'><span data-i18n='total_trades'>Total Trades</span>: "+IntegerToString(totalTrades)+"</div></div></div>");
   FileWriteString(handle,"<div class='card kpi-hero kpi-accent-blue'><div class='kpi-top'><div class='kpi-icon'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><rect x='2' y='5' width='20' height='14' rx='2'/><path d='M2 10h20'/></svg></div></div><div><div class='kpi-label' data-i18n='balance'>Balance</div><div class='kpi-value'>"+cSym+DoubleToString(accBalance,2)+"</div><div class='kpi-sub'><span data-i18n='equity'>Equity</span>: "+cSym+DoubleToString(accEquity,2)+"</div></div></div></div>");
   FileWriteString(handle,"<div class='grid-2-1'><div class='card'><div class='card-title'><span class='dot' style='background:var(--success)'></span><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M3 3v18h18'/><path d='M7 14l4-4 4 4 5-5'/></svg><span data-i18n='equity_curve'>Equity Growth Curve</span><span class='spacer'></span><span class='pill' data-i18n='cumulative'>CUMULATIVE</span></div><div class='chart-wrap'><svg class='chart-svg' viewBox='0 0 800 300' preserveAspectRatio='none' id='eqChart'></svg><div class='chart-tooltip' id='eqTip'></div></div></div>");
   FileWriteString(handle,"<div class='card'><div class='card-title'><span class='dot' style='background:var(--accent)'></span><span data-i18n='key_stats'>Key Statistics</span></div>"
      "<div class='stat-row'><span class='stat-key'><span class='dotc' style='color:var(--success)'></span><span data-i18n='best_trade'>Best Trade</span></span><span class='stat-val pos'>+"+cSym+DoubleToString(MathAbs(bestTrade),2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span class='dotc' style='color:var(--danger)'></span><span data-i18n='worst_trade'>Worst Trade</span></span><span class='stat-val neg'>-"+cSym+DoubleToString(MathAbs(worstTrade),2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='avg_win'>Avg Win</span></span><span class='stat-val pos'>+"+cSym+DoubleToString(avgWin,2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='avg_loss'>Avg Loss</span></span><span class='stat-val neg'>-"+cSym+DoubleToString(avgLoss,2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='avg_rr'>Avg R:R</span></span><span class='stat-val'>1:"+DoubleToString(avgRR,2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='win_streak'>Win Streak</span></span><span class='stat-val'>"+IntegerToString(maxWinStreak)+" <span data-i18n='trades_unit'>trades</span></span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='loss_streak'>Loss Streak</span></span><span class='stat-val'>"+IntegerToString(maxLossStreak)+" <span data-i18n='trades_unit'>trades</span></span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='total_pips'>Total Pips</span></span><span class='stat-val'>"+DoubleToString(totalPips,1)+" <span data-i18n='pips_unit'>pips</span></span></div></div></div>");
   FileWriteString(handle,"<div class='section-title'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><path d='M12 6v6l4 2'/></svg><span data-i18n='timing_analysis'>Timing & Distribution Analysis</span></div><div class='grid-3'>"
      "<div class='card'><div class='card-title'><span class='dot' style='background:var(--success)'></span><span data-i18n='daily_pl'>Daily P&L</span></div><div class='chart-wrap-sm'><svg class='chart-svg' viewBox='0 0 400 220' preserveAspectRatio='none' id='dailyChart'></svg><div class='chart-tooltip' id='dailyTip'></div></div></div>"
      "<div class='card'><div class='card-title'><span class='dot' style='background:var(--accent)'></span><span data-i18n='by_hour'>Performance by Hour</span></div><div class='chart-wrap-sm'><svg class='chart-svg' viewBox='0 0 400 220' preserveAspectRatio='none' id='hourChart'></svg><div class='chart-tooltip' id='hourTip'></div></div></div>"
      "<div class='card'><div class='card-title'><span class='dot' style='background:var(--purple)'></span><span data-i18n='by_day'>Day of Week</span></div><div class='chart-wrap-sm'><svg class='chart-svg' viewBox='0 0 400 220' preserveAspectRatio='none' id='dayChart'></svg><div class='chart-tooltip' id='dayTip'></div></div></div></div>");
   FileWriteString(handle,"<div class='grid-3'><div class='card'><div class='card-title'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><circle cx='12' cy='12' r='10'/><circle cx='12' cy='12' r='4'/></svg><span data-i18n='trade_distribution'>Trade Distribution</span></div>"
      "<div style='position:relative;display:flex;justify-content:center;align-items:center;height:200px'><svg class='chart-svg' viewBox='0 0 200 200' id='donutChart' style='max-width:200px'></svg><div style='position:absolute;text-align:center;pointer-events:none'><div style='font-size:11px;font-weight:700;color:var(--text2);text-transform:uppercase' data-i18n='total'>Total</div><div style='font-family:JetBrains Mono,monospace;font-size:28px;font-weight:800;color:var(--text0)'>"+IntegerToString(totalTrades)+"</div></div></div>"
      "<div class='donut-legend'><div class='donut-legend-item'><span class='donut-legend-color' style='background:var(--accent)'></span><span class='donut-legend-label' data-i18n='buy_trades'>Buy Trades</span><span class='donut-legend-val'>"+IntegerToString(buyTrades)+" ("+IntegerToString(buyPct)+"%)</span></div>"
      "<div class='donut-legend-item'><span class='donut-legend-color' style='background:var(--danger)'></span><span class='donut-legend-label' data-i18n='sell_trades'>Sell Trades</span><span class='donut-legend-val'>"+IntegerToString(sellTrades)+" ("+IntegerToString(sellPct)+"%)</span></div>"
      "<div class='donut-legend-item'><span class='donut-legend-color' style='background:var(--success)'></span><span class='donut-legend-label' data-i18n='winning'>Winning</span><span class='donut-legend-val'>"+IntegerToString(wins)+" ("+IntegerToString(winPct)+"%)</span></div>"
      "<div class='donut-legend-item'><span class='donut-legend-color' style='background:var(--warn)'></span><span class='donut-legend-label' data-i18n='losing'>Losing</span><span class='donut-legend-val'>"+IntegerToString(losses)+" ("+IntegerToString(lossPct)+"%)</span></div></div></div>"
      "<div class='card'><div class='card-title'><span class='dot' style='background:var(--success)'></span><span data-i18n='wins_vs_losses'>Wins vs Losses (Cum.)</span></div><div class='chart-wrap-sm'><svg class='chart-svg' viewBox='0 0 400 220' preserveAspectRatio='none' id='dualChart'></svg><div class='chart-tooltip' id='dualTip'></div></div></div>"
      "<div class='card'><div class='card-title'><span class='dot' style='background:var(--danger)'></span><span data-i18n='drawdown_curve'>Drawdown Curve</span></div><div class='chart-wrap-sm'><svg class='chart-svg' viewBox='0 0 400 220' preserveAspectRatio='none' id='ddChart'></svg><div class='chart-tooltip' id='ddTip'></div></div></div></div>");
   FileWriteString(handle,"<div class='section-title'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M9 11l3 3L22 4'/></svg><span data-i18n='detailed_metrics'>Detailed Metrics</span></div><div class='grid-3'>"
      "<div class='card'><div class='card-title'><span data-i18n='distribution_progress'>Distribution Progress</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='long_buy'>Long (BUY)</span></span><span class='stat-val' style='color:var(--accent2)'>"+IntegerToString(buyTrades)+" ("+IntegerToString(buyPct)+"%)</span></div><div class='prog-wrap'><div class='prog-bar-bg'><div class='prog-bar prog-blue' style='width:"+IntegerToString(buyPct)+"%'></div></div></div>"
      "<div class='stat-row' style='margin-top:8px'><span class='stat-key'><span data-i18n='short_sell'>Short (SELL)</span></span><span class='stat-val' style='color:var(--danger)'>"+IntegerToString(sellTrades)+" ("+IntegerToString(sellPct)+"%)</span></div><div class='prog-wrap'><div class='prog-bar-bg'><div class='prog-bar prog-red' style='width:"+IntegerToString(sellPct)+"%'></div></div></div>"
      "<div class='stat-row' style='margin-top:8px'><span class='stat-key'><span data-i18n='wins'>Wins</span></span><span class='stat-val pos'>"+IntegerToString(winPct)+"%</span></div><div class='prog-wrap'><div class='prog-bar-bg'><div class='prog-bar prog-green' style='width:"+IntegerToString(winPct)+"%'></div></div></div></div>"
      "<div class='card'><div class='card-title'><span data-i18n='pl_breakdown'>P&L Breakdown</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='gross_profit'>Gross Profit</span></span><span class='stat-val pos'>+"+cSym+DoubleToString(grossProfit,2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='gross_loss'>Gross Loss</span></span><span class='stat-val neg'>-"+cSym+DoubleToString(MathAbs(grossLoss),2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='net_profit'>Net Profit</span></span><span class='stat-val "+(string)((netProfit>=0)?"pos":"neg")+"'>"+((netProfit>=0)?"+":"-")+cSym+DoubleToString(MathAbs(netProfit),2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='max_dd'>Max Drawdown</span></span><span class='stat-val neg'>-"+cSym+DoubleToString(maxDD,2)+"</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='recovery_factor'>Recovery Factor</span></span><span class='stat-val'>"+DoubleToString(recoveryFactor,2)+"x</span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='profit_factor'>Profit Factor</span></span><span class='stat-val'>"+DoubleToString(profitFactor,2)+"</span></div></div>"
      "<div class='card'><div class='card-title'><span data-i18n='last_30'>Last 30 Trade Outcomes</span></div><div style='font-size:11.5px;color:var(--text2);margin-bottom:14px' data-i18n='last_30_hint'>Green = Win, Red = Loss, sized by profit magnitude</div><div class='indicator-grid' id='indicatorGrid'></div>"
      "<div style='margin-top:24px'><div class='stat-row'><span class='stat-key'><span data-i18n='max_win_streak'>Max Win Streak</span></span><span class='stat-val pos'>"+IntegerToString(maxWinStreak)+" <span data-i18n='in_a_row'>in a row</span></span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='max_loss_streak'>Max Loss Streak</span></span><span class='stat-val neg'>"+IntegerToString(maxLossStreak)+" <span data-i18n='in_a_row'>in a row</span></span></div>"
      "<div class='stat-row'><span class='stat-key'><span data-i18n='expectancy'>Expectancy</span></span><span class='stat-val'>"+cSym+DoubleToString(expectancy,2)+"/<span data-i18n='trade_unit_short'>trade</span></span></div></div></div></div></div>");
   FileWriteString(handle,"<div class='divider-label'><span><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><path d='M3 6h18M3 12h18M3 18h18'/></svg><span data-i18n='trade_history'>Trade History</span></span></div>"
      "<div class='card' style='padding:0;overflow:hidden'><div style='padding:22px 24px 0'><div class='card-title'><span data-i18n='all_closed'>All Closed Trades</span><span class='spacer'></span><span class='pill'><span id='rowCount'>"+IntegerToString(totalTrades)+"</span> <span data-i18n='records'>records</span></span></div>"
      "<div class='filter-row'><span class='filter-label' data-i18n='filter'>Filter:</span>"
      "<button class='filter-btn active' data-filter='all'><span data-i18n='filter_all'>All</span></button>"
      "<button class='filter-btn' data-filter='buy'><span data-i18n='filter_buy'>Buy</span></button>"
      "<button class='filter-btn' data-filter='sell'><span data-i18n='filter_sell'>Sell</span></button>"
      "<button class='filter-btn' data-filter='pos'><span data-i18n='filter_profit'>Profit</span></button>"
      "<button class='filter-btn' data-filter='neg'><span data-i18n='filter_loss'>Loss</span></button></div></div>"
      "<div class='tbl-wrap'><table id='tradeTable'><thead><tr><th>#</th><th data-i18n='th_symbol'>Symbol</th><th data-i18n='th_type'>Type</th><th data-i18n='th_lots'>Lots</th><th data-i18n='th_open'>Open</th><th data-i18n='th_close'>Close</th><th data-i18n='th_pips'>Pips</th><th data-i18n='th_profit'>Profit</th><th data-i18n='th_close_time'>Close Time</th></tr></thead><tbody id='tradeBody'></tbody></table></div></div>");
   FileWriteString(handle,"<div class='site-footer'><div class='brand'><svg viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2'><polygon points='13 2 3 14 12 14 11 22 21 10 12 10 13 2'/></svg>London Session ORB • AIT CHIKH MUSTAPHA</div><div><span data-i18n='report_generated'>Report generated</span>: "+genTime+"</div><div style='font-size:11px;color:var(--text3)' data-i18n='copyright'>© All rights reserved</div></div></div>");
   string js="<script>";
   js+="var SERVER={EQUITY:["+jsEqData+"],DAILY:{labels:["+jsDailyLabels+"],values:["+jsDailyData+"]},HOURS:["+jsHourData+"],DOW:["+jsDayData+"],WINS_CUM:["+jsWinsCum+"],LOSS_CUM:["+jsLossCum+"],DD:["+jsDDseries+"],OUTCOMES:["+jsOutcomes+"],TRADES:["+jsTradesArr+"]};";
   js+="var I18N={en:{title:'LONDON SESSION ORB',subtitle:'Advanced Analytics Report \\u2022 AIT CHIKH MUSTAPHA',generated:'Generated',theme_dark:'Dark',theme_light:'Light',perf_summary:'Performance Summary',net_profit:'Net Profit',balance:'Balance',equity:'Equity',win_rate:'Win Rate',profit_factor:'Profit Factor',max_dd:'Max Drawdown',wins:'Wins',losses:'Losses',total_trades:'Total Trades',recovery_factor:'Recovery Factor',expectancy:'Expectancy',trade_unit_short:'trade',equity_curve:'Equity Growth Curve',cumulative:'CUMULATIVE',key_stats:'Key Statistics',best_trade:'Best Trade',worst_trade:'Worst Trade',avg_win:'Avg Win',avg_loss:'Avg Loss',avg_rr:'Avg R:R',win_streak:'Win Streak',loss_streak:'Loss Streak',total_pips:'Total Pips',trades_unit:'trades',pips_unit:'pips',timing_analysis:'Timing & Distribution Analysis',daily_pl:'Daily P&L',by_hour:'Performance by Hour',by_day:'Day of Week',trade_distribution:'Trade Distribution',total:'Total',buy_trades:'Buy Trades',sell_trades:'Sell Trades',winning:'Winning',losing:'Losing',wins_vs_losses:'Wins vs Losses (Cum.)',drawdown_curve:'Drawdown Curve',detailed_metrics:'Detailed Metrics',distribution_progress:'Distribution Progress',long_buy:'Long (BUY)',short_sell:'Short (SELL)',pl_breakdown:'P&L Breakdown',gross_profit:'Gross Profit',gross_loss:'Gross Loss',last_30:'Last 30 Trade Outcomes',last_30_hint:'Green = Win, Red = Loss, sized by profit magnitude',max_win_streak:'Max Win Streak',max_loss_streak:'Max Loss Streak',in_a_row:'in a row',trade_history:'Trade History',all_closed:'All Closed Trades',records:'records',filter:'Filter:',filter_all:'All',filter_buy:'Buy',filter_sell:'Sell',filter_profit:'Profit',filter_loss:'Loss',th_symbol:'Symbol',th_type:'Type',th_lots:'Lots',th_open:'Open',th_close:'Close',th_pips:'Pips',th_profit:'Profit',th_close_time:'Close Time',report_generated:'Report generated',copyright:'\\u00a9 All rights reserved',days:['SUN','MON','TUE','WED','THU','FRI','SAT']},";
   js+="ar:{title:'\\u062c\\u0644\\u0633\\u0629 \\u0646\\u064a\\u0648\\u064a\\u0648\\u0631\\u0643 ORB',subtitle:'\\u062a\\u0642\\u0631\\u064a\\u0631 \\u062a\\u062d\\u0644\\u064a\\u0644\\u064a \\u0645\\u062a\\u0642\\u062f\\u0645 \\u2022 \\u0622\\u064a\\u062a \\u0634\\u064a\\u062e \\u0645\\u0635\\u0637\\u0641\\u0649',generated:'\\u062a\\u0645 \\u0627\\u0644\\u0625\\u0646\\u0634\\u0627\\u0621',theme_dark:'\\u062f\\u0627\\u0643\\u0646',theme_light:'\\u0641\\u0627\\u062a\\u062d',perf_summary:'\\u0645\\u0644\\u062e\\u0635 \\u0627\\u0644\\u0623\\u062f\\u0627\\u0621',net_profit:'\\u0635\\u0627\\u0641\\u064a \\u0627\\u0644\\u0631\\u0628\\u062d',balance:'\\u0627\\u0644\\u0631\\u0635\\u064a\\u062f',equity:'\\u062d\\u0642\\u0648\\u0642 \\u0627\\u0644\\u0645\\u0644\\u0643\\u064a\\u0629',win_rate:'\\u0646\\u0633\\u0628\\u0629 \\u0627\\u0644\\u0641\\u0648\\u0632',profit_factor:'\\u0639\\u0627\\u0645\\u0644 \\u0627\\u0644\\u0631\\u0628\\u062d',max_dd:'\\u0623\\u0642\\u0635\\u0649 \\u062a\\u0631\\u0627\\u062c\\u0639',wins:'\\u0631\\u0627\\u0628\\u062d\\u0629',losses:'\\u062e\\u0627\\u0633\\u0631\\u0629',total_trades:'\\u0625\\u062c\\u0645\\u0627\\u0644\\u064a \\u0627\\u0644\\u0635\\u0641\\u0642\\u0627\\u062a',recovery_factor:'\\u0639\\u0627\\u0645\\u0644 \\u0627\\u0644\\u062a\\u0639\\u0627\\u0641\\u064a',expectancy:'\\u0627\\u0644\\u062a\\u0648\\u0642\\u0639',trade_unit_short:'\\u0635\\u0641\\u0642\\u0629',equity_curve:'\\u0645\\u0646\\u062d\\u0646\\u0649 \\u0646\\u0645\\u0648 \\u0631\\u0623\\u0633 \\u0627\\u0644\\u0645\\u0627\\u0644',cumulative:'\\u062a\\u0631\\u0627\\u0643\\u0645\\u064a',key_stats:'\\u0627\\u0644\\u0625\\u062d\\u0635\\u0627\\u0626\\u064a\\u0627\\u062a',best_trade:'\\u0623\\u0641\\u0636\\u0644 \\u0635\\u0641\\u0642\\u0629',worst_trade:'\\u0623\\u0633\\u0648\\u0623 \\u0635\\u0641\\u0642\\u0629',avg_win:'\\u0645\\u062a\\u0648\\u0633\\u0637 \\u0627\\u0644\\u0631\\u0628\\u062d',avg_loss:'\\u0645\\u062a\\u0648\\u0633\\u0637 \\u0627\\u0644\\u062e\\u0633\\u0627\\u0631\\u0629',avg_rr:'\\u0645\\u062a\\u0648\\u0633\\u0637 R:R',win_streak:'\\u0633\\u0644\\u0633\\u0644\\u0629 \\u0641\\u0648\\u0632',loss_streak:'\\u0633\\u0644\\u0633\\u0644\\u0629 \\u062e\\u0633\\u0627\\u0631\\u0629',total_pips:'\\u0625\\u062c\\u0645\\u0627\\u0644\\u064a \\u0627\\u0644\\u0646\\u0642\\u0627\\u0637',trades_unit:'\\u0635\\u0641\\u0642\\u0629',pips_unit:'\\u0646\\u0642\\u0637\\u0629',timing_analysis:'\\u062a\\u062d\\u0644\\u0627\\u0644 \\u0627\\u0644\\u062a\\u0648\\u0642\\u064a\\u062a',daily_pl:'\\u0627\\u0644\\u0623\\u0631\\u0628\\u0627\\u062d \\u0627\\u0644\\u064a\\u0648\\u0645\\u064a\\u0629',by_hour:'\\u0627\\u0644\\u0623\\u062f\\u0627\\u0621 \\u062d\\u0633\\u0628 \\u0627\\u0644\\u0633\\u0627\\u0639\\u0629',by_day:'\\u0623\\u064a\\u0627\\u0645 \\u0627\\u0644\\u0623\\u0633\\u0628\\u0648\\u0639',trade_distribution:'\\u062a\\u0648\\u0632\\u064a\\u0639 \\u0627\\u0644\\u0635\\u0641\\u0642\\u0627\\u062a',total:'\\u0627\\u0644\\u0625\\u062c\\u0645\\u0627\\u0644\\u064a',buy_trades:'\\u0635\\u0641\\u0642\\u0627\\u062a \\u0634\\u0631\\u0627\\u0621',sell_trades:'\\u0635\\u0641\\u0642\\u0627\\u062a \\u0628\\u064a\\u0639',winning:'\\u0631\\u0627\\u0628\\u062d\\u0629',losing:'\\u062e\\u0633\\u0631\\u0629',wins_vs_losses:'\\u0627\\u0644\\u0623\\u0631\\u0628\\u0627\\u062d \\u0645\\u0642\\u0627\\u0628\\u0644 \\u0627\\u0644\\u062e\\u0633\\u0627\\u0626\\u0631',drawdown_curve:'\\u0645\\u0646\\u062d\\u0646\\u0649 \\u0627\\u0644\\u062a\\u0631\\u0627\\u062c\\u0639',detailed_metrics:'\\u0627\\u0644\\u0645\\u0642\\u0627\\u064a\\u064a\\u0633',distribution_progress:'\\u062a\\u0642\\u062f\\u0645 \\u0627\\u0644\\u062a\\u0648\\u0632\\u064a\\u0639',long_buy:'\\u0634\\u0631\\u0627\\u0621',short_sell:'\\u0628\\u064a\\u0639',pl_breakdown:'\\u062a\\u0641\\u0635\\u064a\\u0644 \\u0627\\u0644\\u0623\\u0631\\u0628\\u0627\\u062d',gross_profit:'\\u0625\\u062c\\u0645\\u0627\\u0644\\u064a \\u0627\\u0644\\u0631\\u0628\\u062d',gross_loss:'\\u0625\\u062c\\u0645\\u0627\\u0644\\u064a \\u0627\\u0644\\u062e\\u0633\\u0627\\u0631\\u0629',last_30:'\\u0622\\u062e\\u0631 30 \\u0635\\u0641\\u0642\\u0629',last_30_hint:'\\u0623\\u062e\\u0636\\u0631 = \\u0641\\u0648\\u0632\\u060c \\u0623\\u062d\\u0645\\u0631 = \\u062e\\u0633\\u0627\\u0631\\u0629',max_win_streak:'\\u0623\\u0642\\u0635\\u0649 \\u0633\\u0644\\u0633\\u0644\\u0629 \\u0641\\u0648\\u0632',max_loss_streak:'\\u0623\\u0642\\u0635\\u0649 \\u0633\\u0644\\u0633\\u0644\\u0629 \\u062e\\u0633\\u0627\\u0631\\u0629',in_a_row:'\\u0645\\u062a\\u062a\\u0627\\u0644\\u064a\\u0629',trade_history:'\\u0633\\u062c\\u0644 \\u0627\\u0644\\u0635\\u0641\\u0642\\u0627\\u062a',all_closed:'\\u062c\\u0645\\u064a\\u0639 \\u0627\\u0644\\u0635\\u0641\\u0642\\u0627\\u062a',records:'\\u0633\\u062c\\u0644',filter:'\\u062a\\u0635\\u0641\\u064a\\u0629:',filter_all:'\\u0627\\u0644\\u0643\\u0644',filter_buy:'\\u0634\\u0631\\u0627\\u0621',filter_sell:'\\u0628\\u064a\\u0639',filter_profit:'\\u0631\\u0628\\u062d',filter_loss:'\\u062e\\u0633\\u0627\\u0631\\u0629',th_symbol:'\\u0627\\u0644\\u0631\\u0645\\u0632',th_type:'\\u0627\\u0644\\u0646\\u0648\\u0639',th_lots:'\\u0627\\u0644\\u0644\\u0648\\u062a',th_open:'\\u0627\\u0644\\u0641\\u062a\\u062d',th_close:'\\u0627\\u0644\\u0625\\u063a\\u0644\\u0627\\u0642',th_pips:'\\u0627\\u0644\\u0646\\u0642\\u0627\\u0637',th_profit:'\\u0627\\u0644\\u0631\\u0628\\u062d',th_close_time:'\\u0648\\u0642\\u062a \\u0627\\u0644\\u0625\\u063a\\u0644\\u0627\\u0642',report_generated:'\\u062a\\u0645 \\u0625\\u0646\\u0634\\u0627\\u0621 \\u0627\\u0644\\u062a\\u0642\\u0631\\u064a\\u0631',copyright:'\\u00a9 \\u062c\\u0645\\u064a\\u0639 \\u0627\\u0644\\u062d\\u0642\\u0648\\u0642',days:['\\u0623\\u062d\\u062f','\\u0625\\u062b\\u0646','\\u062b\\u0644\\u0627','\\u0623\\u0631\\u0628','\\u062e\\u0645\\u064a','\\u062c\\u0645\\u0639','\\u0633\\u0628\\u062a']}};";
   js+="var currentLang='en',currentTheme='dark';";
   js+="function applyI18n(lang){currentLang=lang;var d=I18N[lang];document.documentElement.lang=lang;document.documentElement.dir=(lang=='ar')?'rtl':'ltr';document.querySelectorAll('[data-i18n]').forEach(function(el){var k=el.getAttribute('data-i18n');if(d[k]!==undefined)el.textContent=d[k];});document.getElementById('langEn').classList.toggle('active',lang=='en');document.getElementById('langAr').classList.toggle('active',lang=='ar');drawAllCharts();}";
   js+="function applyTheme(t){currentTheme=t;document.documentElement.setAttribute('data-theme',t);var lbl=document.getElementById('themeLabel');lbl.textContent=(t=='dark')?I18N[currentLang].theme_dark:I18N[currentLang].theme_light;drawAllCharts();}";
   js+="document.getElementById('langEn').addEventListener('click',function(){applyI18n('en');});document.getElementById('langAr').addEventListener('click',function(){applyI18n('ar');});document.getElementById('themeToggle').addEventListener('click',function(){applyTheme(currentTheme=='dark'?'light':'dark');});";
   js+="function cssVar(n){return getComputedStyle(document.documentElement).getPropertyValue(n).trim();}";
   js+="function drawAreaChart(svgId,tipId,data,opts){var svg=document.getElementById(svgId);if(!svg||!data.length)return;svg.innerHTML='';var W=800,H=300,pL=46,pR=14,pT=18,pB=32,iW=W-pL-pR,iH=H-pT-pB;var mx=Math.max.apply(null,data),mn=Math.min.apply(null,data.concat([0]));var rg=(mx-mn)||1;var sx=iW/Math.max(1,data.length-1);var col=opts.color||cssVar('--success'),colRgb=opts.colorRgb||'16,185,129';var gC=cssVar('--grid-line'),tC=cssVar('--text2');for(var i=0;i<=4;i++){var y=pT+(iH/4)*i;var v=mx-(rg/4)*i;svg.insertAdjacentHTML('beforeend','<line x1=\"'+pL+'\" y1=\"'+y+'\" x2=\"'+(W-pR)+'\" y2=\"'+y+'\" stroke=\"'+gC+'\" stroke-width=\"1\"/><text x=\"'+(pL-8)+'\" y=\"'+(y+4)+'\" fill=\"'+tC+'\" font-size=\"10\" text-anchor=\"end\">"+cSym+"'+v.toFixed(0)+'</text>');}var pts=data.map(function(v,i){var x=pL+i*sx;var y=pT+iH-((v-mn)/rg)*iH;return [x,y];});var lp=pts.map(function(p,i){return (i===0?'M':'L')+p[0].toFixed(1)+' '+p[1].toFixed(1);}).join(' ');var gId=svgId+'grad';svg.insertAdjacentHTML('beforeend','<defs><linearGradient id=\"'+gId+'\" x1=\"0\" x2=\"0\" y1=\"0\" y2=\"1\"><stop offset=\"0%\" stop-color=\"rgba('+colRgb+',0.45)\"/><stop offset=\"100%\" stop-color=\"rgba('+colRgb+',0)\"/></linearGradient></defs>');var ap=lp+' L '+pts[pts.length-1][0].toFixed(1)+' '+(pT+iH).toFixed(1)+' L '+pts[0][0].toFixed(1)+' '+(pT+iH).toFixed(1)+' Z';svg.insertAdjacentHTML('beforeend','<path d=\"'+ap+'\" fill=\"url(#'+gId+')\"/>');svg.insertAdjacentHTML('beforeend','<path d=\"'+lp+'\" fill=\"none\" stroke=\"'+col+'\" stroke-width=\"2.4\"/>');var tip=document.getElementById(tipId),wrap=svg.parentElement;pts.forEach(function(p,i){var c=document.createElementNS('http://www.w3.org/2000/svg','circle');c.setAttribute('cx',p[0]);c.setAttribute('cy',p[1]);c.setAttribute('r',8);c.setAttribute('fill','transparent');c.addEventListener('mouseenter',function(){var r=wrap.getBoundingClientRect();tip.textContent='"+cSym+"'+data[i].toFixed(2);tip.style.left=((p[0]/W)*r.width)+'px';tip.style.top=((p[1]/H)*r.height)+'px';tip.classList.add('show');});c.addEventListener('mouseleave',function(){tip.classList.remove('show');});svg.appendChild(c);});}";
   js+="function drawBarChart(svgId,tipId,labels,values,opts){var svg=document.getElementById(svgId);if(!svg||!values.length)return;svg.innerHTML='';var W=400,H=220,pL=38,pR=10,pT=14,pB=30,iW=W-pL-pR,iH=H-pT-pB;var mx=Math.max.apply(null,values.concat([1])),mn=Math.min.apply(null,values.concat([0]));var rg=(mx-mn)||1;var bw=iW/values.length*0.7,gp=iW/values.length*0.3;var gC=cssVar('--grid-line'),tC=cssVar('--text2');var cP=opts.colorPos||cssVar('--success'),cN=opts.colorNeg||cssVar('--danger'),cS=opts.colorSingle;for(var i=0;i<=4;i++){var y=pT+(iH/4)*i;var v=mx-(rg/4)*i;svg.insertAdjacentHTML('beforeend','<line x1=\"'+pL+'\" y1=\"'+y+'\" x2=\"'+(W-pR)+'\" y2=\"'+y+'\" stroke=\"'+gC+'\" stroke-width=\"1\"/>');}var tip=document.getElementById(tipId),wrap=svg.parentElement;values.forEach(function(v,i){var x=pL+(iW/values.length)*i+gp/2;var yZero=pT+iH-((0-mn)/rg)*iH;var yVal=pT+iH-((v-mn)/rg)*iH;var y=Math.min(yZero,yVal),h=Math.abs(yVal-yZero);var col=cS?cS:(v>=0?cP:cN);var r=document.createElementNS('http://www.w3.org/2000/svg','rect');r.setAttribute('x',x);r.setAttribute('y',y);r.setAttribute('width',bw);r.setAttribute('height',Math.max(2,h));r.setAttribute('fill',col);r.setAttribute('rx',3);r.addEventListener('mouseenter',function(){var rc=wrap.getBoundingClientRect();tip.innerHTML=labels[i]+'<br>"+cSym+"'+v.toFixed(2);tip.style.left=(((x+bw/2)/W)*rc.width)+'px';tip.style.top=((y/H)*rc.height)+'px';tip.classList.add('show');});r.addEventListener('mouseleave',function(){tip.classList.remove('show');});svg.appendChild(r);var step=Math.max(1,Math.floor(values.length/8));if(i%step===0)svg.insertAdjacentHTML('beforeend','<text x=\"'+(x+bw/2)+'\" y=\"'+(H-10)+'\" fill=\"'+tC+'\" font-size=\"9\" text-anchor=\"middle\">'+labels[i]+'</text>');});}";
   js+="function drawDonut(svgId,segs){var svg=document.getElementById(svgId);if(!svg)return;svg.innerHTML='';svg.setAttribute('viewBox','0 0 200 200');var cx=100,cy=100,r=72,ri=50;var total=segs.reduce(function(s,x){return s+x.value;},0);if(total<=0)return;var a=-Math.PI/2;segs.forEach(function(s){var sl=(s.value/total)*Math.PI*2;var a2=a+sl;var lg=sl>Math.PI?1:0;var x1=cx+r*Math.cos(a),y1=cy+r*Math.sin(a),x2=cx+r*Math.cos(a2),y2=cy+r*Math.sin(a2);var x3=cx+ri*Math.cos(a2),y3=cy+ri*Math.sin(a2),x4=cx+ri*Math.cos(a),y4=cy+ri*Math.sin(a);var d='M '+x1+' '+y1+' A '+r+' '+r+' 0 '+lg+' 1 '+x2+' '+y2+' L '+x3+' '+y3+' A '+ri+' '+ri+' 0 '+lg+' 0 '+x4+' '+y4+' Z';svg.insertAdjacentHTML('beforeend','<path d=\"'+d+'\" fill=\"'+s.color+'\" stroke=\"'+cssVar('--card-solid')+'\" stroke-width=\"2\"/>');a=a2;});}";
   js+="function drawDualLine(svgId,A,B,cA,cB){var svg=document.getElementById(svgId);if(!svg||!A.length)return;svg.innerHTML='';var W=400,H=220,pL=40,pR=10,pT=14,pB=30,iW=W-pL-pR,iH=H-pT-pB;var mx=Math.max.apply(null,A.concat(B).concat([1]));var rg=mx||1;var gC=cssVar('--grid-line');for(var i=0;i<=4;i++){var y=pT+(iH/4)*i;svg.insertAdjacentHTML('beforeend','<line x1=\"'+pL+'\" y1=\"'+y+'\" x2=\"'+(W-pR)+'\" y2=\"'+y+'\" stroke=\"'+gC+'\" stroke-width=\"1\"/>');}var sx=iW/Math.max(1,A.length-1);function bp(S){return S.map(function(v,i){var x=pL+i*sx;var y=pT+iH-(v/rg)*iH;return (i===0?'M':'L')+x.toFixed(1)+' '+y.toFixed(1);}).join(' ');}svg.insertAdjacentHTML('beforeend','<path d=\"'+bp(A)+'\" fill=\"none\" stroke=\"'+cA+'\" stroke-width=\"2.2\"/>');svg.insertAdjacentHTML('beforeend','<path d=\"'+bp(B)+'\" fill=\"none\" stroke=\"'+cB+'\" stroke-width=\"2.2\"/>');}";
   js+="function renderIndicators(){var g=document.getElementById('indicatorGrid');if(!g)return;g.innerHTML='';var O=SERVER.OUTCOMES;if(!O.length)return;var mA=Math.max.apply(null,O.map(Math.abs))||1;O.forEach(function(v,i){var ratio=Math.abs(v)/mA;var sz=18+ratio*16;var c=v>=0?cssVar('--success'):cssVar('--danger');var w=document.createElement('div');w.style.display='flex';w.style.alignItems='center';w.style.justifyContent='center';w.innerHTML='<div class=\"indicator-circle\" style=\"width:'+sz+'px;height:'+sz+'px;background:'+c+';\" title=\"#'+(i+1)+': '+(v>=0?\"+\":\"\")+\""+cSym+"\"+v.toFixed(2)+'\"></div>';g.appendChild(w);});}";
   js+="function drawAllCharts(){drawAreaChart('eqChart','eqTip',SERVER.EQUITY,{color:cssVar('--success'),colorRgb:'16,185,129'});drawBarChart('dailyChart','dailyTip',SERVER.DAILY.labels,SERVER.DAILY.values,{});var hr=[];for(var i=0;i<24;i++)hr.push((i<10?'0':'')+i);drawBarChart('hourChart','hourTip',hr,SERVER.HOURS,{colorSingle:cssVar('--accent2')});drawBarChart('dayChart','dayTip',I18N[currentLang].days,SERVER.DOW,{colorSingle:cssVar('--purple')});drawDonut('donutChart',[{value:"+IntegerToString(buyTrades)+",color:cssVar('--accent')},{value:"+IntegerToString(sellTrades)+",color:cssVar('--danger')},{value:"+IntegerToString(wins)+",color:cssVar('--success')},{value:"+IntegerToString(losses)+",color:cssVar('--warn')}]);drawDualLine('dualChart',SERVER.WINS_CUM,SERVER.LOSS_CUM,cssVar('--success'),cssVar('--danger'));drawAreaChart('ddChart','ddTip',SERVER.DD,{color:cssVar('--danger'),colorRgb:'239,68,68'});renderIndicators();}";
   js+="function renderTable(filter){var tb=document.getElementById('tradeBody');tb.innerHTML='';var fil=SERVER.TRADES.filter(function(t){if(filter=='all')return true;if(filter=='buy')return t.type=='BUY';if(filter=='sell')return t.type=='SELL';if(filter=='pos')return t.profit>=0;if(filter=='neg')return t.profit<0;return true;});fil.forEach(function(t){var pc=t.profit>=0?'pos':'neg';var pic=t.pips>=0?'pos':'neg';var s=t.profit>=0?'+':'-';var ps=t.pips>=0?'+':'';var bdg=t.type=='BUY'?'badge-buy':'badge-sell';tb.insertAdjacentHTML('beforeend','<tr><td class=\"muted mono\">#'+t.ticket+'</td><td style=\"font-weight:700\">'+t.symbol+'</td><td><span class=\"badge '+bdg+'\">'+t.type+'</span></td><td class=\"mono\">'+t.lots+'</td><td class=\"muted mono\">'+t.open+'</td><td class=\"muted mono\">'+t.close+'</td><td class=\"'+pic+' mono\">'+ps+t.pips.toFixed(1)+'</td><td class=\"'+pc+' mono\" style=\"font-weight:700\">'+s+'"+cSym+"'+Math.abs(t.profit).toFixed(2)+'</td><td class=\"muted mono\">'+t.time+'</td></tr>');});document.getElementById('rowCount').textContent=fil.length;}";
   js+="document.querySelectorAll('.filter-btn').forEach(function(b){b.addEventListener('click',function(){document.querySelectorAll('.filter-btn').forEach(function(x){x.classList.remove('active');});b.classList.add('active');renderTable(b.dataset.filter);});});";
   js+="window.addEventListener('load',function(){applyI18n('en');applyTheme('dark');renderTable('all');var t;window.addEventListener('resize',function(){clearTimeout(t);t=setTimeout(drawAllCharts,150);});});";
   js+="</script></body></html>";
   FileWriteString(handle,js);
   FileClose(handle);
   Alert("Premium Multilingual Report Generated! Open MQL4/Files/",filename);
}

//+------------------------------------------------------------------+
//|  EQUITY CURVE BOX - Fixed pixel-based box in top-right corner    |
//|  Added by Arena.ai - does NOT touch any trading logic            |
//+------------------------------------------------------------------+
void CleanEquityCurve()
{
   for(int i=ObjectsTotal(0,-1,-1)-1;i>=0;i--)
   {
      string n=ObjectName(0,i,-1);
      if(StringFind(n,eq_prefix)==0) ObjectDelete(0,n);
   }
}

void BuildEquityData()
{
   double startBal=AccountBalance()-cachedNetProfit;
   double runBal=startBal;
   
   int validCount=0;
   for(int j=0;j<OrdersHistoryTotal();j++)
   {
      if(!OrderSelect(j,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderType()>1) continue;
      if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber())))
         validCount++;
   }
   
   ArrayResize(g_eqBalances,validCount+1);
   g_eqBalances[0]=startBal;
   g_eqCount=1;
   
   for(int i=0;i<OrdersHistoryTotal();i++)
   {
      if(!OrderSelect(i,SELECT_BY_POS,MODE_HISTORY)) continue;
      if(OrderType()>1) continue;
      if(GlobalHistory||(OrderSymbol()==Symbol()&&IsOurMagic(OrderMagicNumber())))
      {
         runBal+=OrderProfit()+OrderSwap()+OrderCommission();
         g_eqBalances[g_eqCount]=runBal;
         g_eqCount++;
      }
   }
}

void DrawEquityCurveBox()
{
   CleanEquityCurve();
   if(!ShowEquityCurve || g_eqCount<2) return;
   
   int boxW=EQ_BoxWidth, boxH=EQ_BoxHeight;
   int boxX=EQ_PosX, boxY=EQ_PosY;
   int graphX=boxX+10, graphY=boxY+32;
   int graphW=boxW-20, graphH=boxH-52;
   
   // Shadow
   string shd=eq_prefix+"Shd";
   ObjectCreate(0,shd,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,shd,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,shd,OBJPROP_XDISTANCE,boxX-2);
   ObjectSetInteger(0,shd,OBJPROP_YDISTANCE,boxY+2);
   ObjectSetInteger(0,shd,OBJPROP_XSIZE,boxW);
   ObjectSetInteger(0,shd,OBJPROP_YSIZE,boxH);
   ObjectSetInteger(0,shd,OBJPROP_BGCOLOR,C'180,185,195');
   ObjectSetInteger(0,shd,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,shd,OBJPROP_COLOR,C'180,185,195');
   ObjectSetInteger(0,shd,OBJPROP_BACK,false);
   ObjectSetInteger(0,shd,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,shd,OBJPROP_HIDDEN,true);
   
   // Main box
   string bg=eq_prefix+"BG";
   ObjectCreate(0,bg,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,bg,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,bg,OBJPROP_XDISTANCE,boxX);
   ObjectSetInteger(0,bg,OBJPROP_YDISTANCE,boxY);
   ObjectSetInteger(0,bg,OBJPROP_XSIZE,boxW);
   ObjectSetInteger(0,bg,OBJPROP_YSIZE,boxH);
   ObjectSetInteger(0,bg,OBJPROP_BGCOLOR,EQ_BoxBG);
   ObjectSetInteger(0,bg,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,bg,OBJPROP_COLOR,EQ_BoxBorder);
   ObjectSetInteger(0,bg,OBJPROP_WIDTH,1);
   ObjectSetInteger(0,bg,OBJPROP_BACK,false);
   ObjectSetInteger(0,bg,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bg,OBJPROP_HIDDEN,true);
   
   // Title
   double netPL=g_eqBalances[g_eqCount-1]-g_eqBalances[0];
   string titleTxt="EQUITY CURVE  Net: "+(netPL>=0?"+":"")+DoubleToString(netPL,2);
   string ttl=eq_prefix+"Title";
   ObjectCreate(0,ttl,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,ttl,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,ttl,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,ttl,OBJPROP_XDISTANCE,boxX+5);
   ObjectSetInteger(0,ttl,OBJPROP_YDISTANCE,boxY+4);
   ObjectSetString(0,ttl,OBJPROP_TEXT,titleTxt);
   ObjectSetString(0,ttl,OBJPROP_FONT,"Segoe UI Bold");
   ObjectSetInteger(0,ttl,OBJPROP_FONTSIZE,8);
   ObjectSetInteger(0,ttl,OBJPROP_COLOR,netPL>=0?EQ_CurveColor:EQ_LossColor);
   ObjectSetInteger(0,ttl,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,ttl,OBJPROP_HIDDEN,true);
   
   // Sub text
   string sub=eq_prefix+"Sub";
   ObjectCreate(0,sub,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,sub,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,sub,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,sub,OBJPROP_XDISTANCE,boxX+5);
   ObjectSetInteger(0,sub,OBJPROP_YDISTANCE,boxY+17);
   ObjectSetString(0,sub,OBJPROP_TEXT,
      "Start: $"+DoubleToString(g_eqBalances[0],2)+"  End: $"+DoubleToString(g_eqBalances[g_eqCount-1],2));
   ObjectSetString(0,sub,OBJPROP_FONT,"Segoe UI");
   ObjectSetInteger(0,sub,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,sub,OBJPROP_COLOR,EQ_SubTextColor);
   ObjectSetInteger(0,sub,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,sub,OBJPROP_HIDDEN,true);
   
   // Find min/max for scaling
   double minB=g_eqBalances[0], maxB=g_eqBalances[0];
   for(int i=1;i<g_eqCount;i++)
   {
      if(g_eqBalances[i]<minB) minB=g_eqBalances[i];
      if(g_eqBalances[i]>maxB) maxB=g_eqBalances[i];
   }
   double bRng=maxB-minB;
   if(bRng<=0) bRng=1;
   
   double stepX=(double)graphW/(double)(g_eqCount-1);
   
   // Zero line (starting balance)
   int zeroY=graphY+graphH-(int)(((g_eqBalances[0]-minB)/bRng)*graphH);
   string zl=eq_prefix+"ZL";
   ObjectCreate(0,zl,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,zl,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,zl,OBJPROP_XDISTANCE,graphX);
   ObjectSetInteger(0,zl,OBJPROP_YDISTANCE,zeroY);
   ObjectSetInteger(0,zl,OBJPROP_XSIZE,graphW);
   ObjectSetInteger(0,zl,OBJPROP_YSIZE,1);
   ObjectSetInteger(0,zl,OBJPROP_BGCOLOR,EQ_ZeroLineColor);
   ObjectSetInteger(0,zl,OBJPROP_BORDER_TYPE,BORDER_FLAT);
   ObjectSetInteger(0,zl,OBJPROP_COLOR,EQ_ZeroLineColor);
   ObjectSetInteger(0,zl,OBJPROP_BACK,false);
   ObjectSetInteger(0,zl,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,zl,OBJPROP_HIDDEN,true);
   
   // Draw curve segments using pixel rectangles
   for(int i=0;i<g_eqCount-1;i++)
   {
      int x1=boxX+boxW-10-(int)(i*stepX);
      int x2=boxX+boxW-10-(int)((i+1)*stepX);
      int py1=graphY+graphH-(int)(((g_eqBalances[i]-minB)/bRng)*graphH);
      int py2=graphY+graphH-(int)(((g_eqBalances[i+1]-minB)/bRng)*graphH);
      
      bool segWin=(g_eqBalances[i+1]>=g_eqBalances[i]);
      color segClr=segWin?EQ_CurveColor:EQ_LossColor;
      
      // Draw line using small pixel blocks (Bresenham)
      int dx=x1-x2;
      int dy=py2-py1;
      int steps=MathMax(MathAbs(dx),MathAbs(dy));
      if(steps<1)steps=1;
      if(steps>40)steps=40;
      
      for(int s=0;s<=steps;s++)
      {
         int px=x1-(int)((double)s/steps*dx);
         int py=py1+(int)((double)s/steps*dy);
         
         string pxN=eq_prefix+"P"+IntegerToString(i)+"_"+IntegerToString(s);
         ObjectCreate(0,pxN,OBJ_RECTANGLE_LABEL,0,0,0);
         ObjectSetInteger(0,pxN,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
         ObjectSetInteger(0,pxN,OBJPROP_XDISTANCE,px);
         ObjectSetInteger(0,pxN,OBJPROP_YDISTANCE,py);
         ObjectSetInteger(0,pxN,OBJPROP_XSIZE,3);
         ObjectSetInteger(0,pxN,OBJPROP_YSIZE,3);
         ObjectSetInteger(0,pxN,OBJPROP_BGCOLOR,segClr);
         ObjectSetInteger(0,pxN,OBJPROP_BORDER_TYPE,BORDER_FLAT);
         ObjectSetInteger(0,pxN,OBJPROP_COLOR,segClr);
         ObjectSetInteger(0,pxN,OBJPROP_BACK,false);
         ObjectSetInteger(0,pxN,OBJPROP_SELECTABLE,false);
         ObjectSetInteger(0,pxN,OBJPROP_HIDDEN,true);
      }
      
      // Dot at trade point
      string dotN=eq_prefix+"D"+IntegerToString(i+1);
      ObjectCreate(0,dotN,OBJ_RECTANGLE_LABEL,0,0,0);
      ObjectSetInteger(0,dotN,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
      ObjectSetInteger(0,dotN,OBJPROP_XDISTANCE,x2-2);
      ObjectSetInteger(0,dotN,OBJPROP_YDISTANCE,py2-2);
      ObjectSetInteger(0,dotN,OBJPROP_XSIZE,5);
      ObjectSetInteger(0,dotN,OBJPROP_YSIZE,5);
      ObjectSetInteger(0,dotN,OBJPROP_BGCOLOR,EQ_DotColor);
      ObjectSetInteger(0,dotN,OBJPROP_BORDER_TYPE,BORDER_FLAT);
      ObjectSetInteger(0,dotN,OBJPROP_COLOR,EQ_BoxBG);
      ObjectSetInteger(0,dotN,OBJPROP_BACK,false);
      ObjectSetInteger(0,dotN,OBJPROP_SELECTABLE,false);
      ObjectSetInteger(0,dotN,OBJPROP_HIDDEN,true);
   }
   
   // Bottom info
   double maxDD=0,peak=g_eqBalances[0];
   for(int i=1;i<g_eqCount;i++)
   {
      if(g_eqBalances[i]>peak) peak=g_eqBalances[i];
      double dd=peak-g_eqBalances[i];
      if(dd>maxDD) maxDD=dd;
   }
   
   string bot=eq_prefix+"Bot";
   ObjectCreate(0,bot,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,bot,OBJPROP_CORNER,CORNER_RIGHT_UPPER);
   ObjectSetInteger(0,bot,OBJPROP_ANCHOR,ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0,bot,OBJPROP_XDISTANCE,boxX+5);
   ObjectSetInteger(0,bot,OBJPROP_YDISTANCE,boxY+boxH-14);
   ObjectSetString(0,bot,OBJPROP_TEXT,
      "Lo:$"+DoubleToString(minB,0)+
      " Hi:$"+DoubleToString(maxB,0)+
      " DD:$"+DoubleToString(maxDD,2));
   ObjectSetString(0,bot,OBJPROP_FONT,"Segoe UI");
   ObjectSetInteger(0,bot,OBJPROP_FONTSIZE,7);
   ObjectSetInteger(0,bot,OBJPROP_COLOR,EQ_SubTextColor);
   ObjectSetInteger(0,bot,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,bot,OBJPROP_HIDDEN,true);
   
   ChartRedraw(0);
}
//+------------------------------------------------------------------+
