using Toybox.Application;
using Toybox.Activity as Activity;
using Toybox.System as Sys;
using Toybox.Background as Bg;
using Toybox.WatchUi as Ui;
using Toybox.Time;
using Toybox.Math;
using Toybox.Time.Gregorian as Date;

import Toybox.Lang;

// In-memory current location.
// Previously persisted in App.Storage, but now persisted in Object Store due to #86 workaround for App.Storage firmware bug.
// Current location retrieved/saved in checkPendingWebRequests().
// Persistence allows weather and sunrise/sunset features to be used after watch face restart, even if watch no longer has current
// location available.
var gLocationLat = null;
var gLocationLng = null;

function degreesToRadians(degrees) {
   return (degrees * Math.PI) / 180;
}

function radiansToDegrees(radians) {
   return (radians * 180) / Math.PI;
}

function convertCoorX(radians, radius) {
   return center_x + radius * Math.cos(radians);
}

function convertCoorY(radians, radius) {
   return center_y + radius * Math.sin(radians);
}

(:background)
class HuwaiiApp extends Application.AppBase {
   var mView;
   var days;
   var months;

   var _currentFieldIds as Array<Number> = {};

   function initialize() {
      AppBase.initialize();
      days = {
         Date.DAY_MONDAY => "MON",
         Date.DAY_TUESDAY => "TUE",
         Date.DAY_WEDNESDAY => "WED",
         Date.DAY_THURSDAY => "THU",
         Date.DAY_FRIDAY => "FRI",
         Date.DAY_SATURDAY => "SAT",
         Date.DAY_SUNDAY => "SUN",
      };
      months = {
         Date.MONTH_JANUARY => "JAN",
         Date.MONTH_FEBRUARY => "FEB",
         Date.MONTH_MARCH => "MAR",
         Date.MONTH_APRIL => "APR",
         Date.MONTH_MAY => "MAY",
         Date.MONTH_JUNE => "JUN",
         Date.MONTH_JULY => "JUL",
         Date.MONTH_AUGUST => "AUG",
         Date.MONTH_SEPTEMBER => "SEP",
         Date.MONTH_OCTOBER => "OCT",
         Date.MONTH_NOVEMBER => "NOV",
         Date.MONTH_DECEMBER => "DEC",
      };
   }

   // onStart() is called on application start up
   function onStart(state) {}

   // onStop() is called when your application is exiting
   function onStop(state) {}

   // Return the initial view of your application here
   function getInitialView() {
      updateCurrentDataFieldIds();
      mView = new HuwaiiView();
      return [mView];
   }

   function getView() {
      return mView;
   }

   function onSettingsChanged() {
      // triggered by settings change in GCM
      updateCurrentDataFieldIds();

      if (HuwaiiApp has :checkPendingWebRequests) {
         // checkPendingWebRequests() can be excluded to save memory.
         checkPendingWebRequests();
      }
      mView.checkGlobals();
      mView.last_draw_minute = -1;
      WatchUi.requestUpdate(); // update the view to reflect changes
   }

   // Determine if any web requests are needed.
   // If so, set approrpiate pendingWebRequests flag for use by BackgroundService, then register for
   // temporal event.
   // Currently called on layout initialisation, when settings change, and on exiting sleep.
   (:background_method)
   function checkPendingWebRequests() {
      // Update last known location
      updateLastLocation();

      if (!(Sys has :ServiceDelegate)) {
         return;
      }

      var pendingWebRequests = {};

      if (needWeatherDataUpdate()) {
         pendingWebRequests[$.DATA_TYPE_WEATHER] = true;
      }

      if (needAirQualityDataUpdate()) {
         pendingWebRequests[$.DATA_TYPE_AIR_QUALITY] = true;
      }

      setProperty("PendingWebRequests", pendingWebRequests);

      // If there are any pending requests:
      if (pendingWebRequests.keys().size() > 0) {
         // Register for background temporal event as soon as possible.
         var lastTime = Bg.getLastTemporalEventTime();

         if (lastTime) {
            // Events scheduled for a time in the past trigger immediately.
            var nextTime = lastTime.add(new Time.Duration(5 * 60));
            Bg.registerForTemporalEvent(nextTime);
         } else {
            Bg.registerForTemporalEvent(Time.now());
         }
      }
   }

   //! Populates a list of all the data field ids in use
   function updateCurrentDataFieldIds() as Void {
      var fieldIds = [
         getComplicationSettingDataKey(12),
         getComplicationSettingDataKey(10),
         getComplicationSettingDataKey(2),
         getComplicationSettingDataKey(4),
         getComplicationSettingDataKey(6),
         getComplicationSettingDataKey(8),
         getBarDataComplicationSettingDataKey(0),
         getBarDataComplicationSettingDataKey(1),
         $.getGraphComplicationDataKey(0),
         $.getGraphComplicationDataKey(1)
      ];

      _currentFieldIds = fieldIds;
   }

   function isAnyDataFieldsInUse(fieldIds as Array<Number>) {
      for (var i =0; i < fieldIds.size(); i++) {
         var id = fieldIds[i];
         if (_currentFieldIds.indexOf(id) != -1) {
            return true;
         }
      }
      return false;
   }

   function updateLastLocation() as Void {
      // Attempt to update current location, to be used by Sunrise/Sunset, Weather, Air Quality.
      // If current location available from current activity, save it in case it goes "stale" and can not longer be retrieved.
      var location = Activity.getActivityInfo().currentLocation;
      if (location) {
         // Save current location to globals
         location = location.toDegrees(); // Array of Doubles.
         gLocationLat = location[0].toFloat();
         gLocationLng = location[1].toFloat();

         Application.getApp().setProperty("LastLocationLat", gLocationLat);
         Application.getApp().setProperty("LastLocationLng", gLocationLng);
      } else {
         // current location is not available, read stored value from Object Store, being careful not to overwrite a valid
         // in-memory value with an invalid stored one.
         var lat = Application.getApp().getProperty("LastLocationLat");
         var lng = Application.getApp().getProperty("LastLocationLng");
         if ((lat != null) && (lng != null)) {
            gLocationLat = lat;
            gLocationLng = lng;
         }
      }
   }

   function needWeatherDataUpdate() as Boolean {
      // OpenWeatherMap data field must be shown.
      if (!isAnyDataFieldsInUse( [FIELD_TYPE_TEMPERATURE_HL, FIELD_TYPE_TEMPERATURE_OUT, FIELD_TYPE_WEATHER, FIELD_TYPE_WIND] )) {
         return false;
      }

      // Location must be available
      if ((gLocationLat == null) || (gLocationLng == null)) {
         return false;
      }

      var lastData = getProperty($.DATA_TYPE_WEATHER);

      if ((lastData == null) || (lastData["clientTs"] == null)) {
         // No existing data.
         return true;
      } else if (lastData["cod"] == 200) {
         // Successfully received weather data.
         // TODO: Consider requesting weather at sunrise/sunset to update weather icon.
         if (
            // Existing data is older than 15 mins.
            // Note: We use clientTs as we do not *know* how often weather data is updated (typically hourly)
            Time.now().value() > (lastData["clientTs"] + (15 * 60)) ||
            // Existing data not for this location.
            // Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
            // true distance calculation. 0.02 degree of latitude is just over a mile.
            (gLocationLat - lastData["lat"]).abs() > 0.02 ||
            (gLocationLng - lastData["lon"]).abs() > 0.02) {
            return true;
         }
      } else {
         // Retry on error
         return true;
      }
   }

   function needAirQualityDataUpdate() as Boolean {
      // AirQuality data field must be shown.
      if (!isAnyDataFieldsInUse( [FIELD_TYPE_AIR_QUALITY] )) {
         return false;
      }

      // Check data validity
      var lastData = getProperty($.DATA_TYPE_AIR_QUALITY);
      if (  (
               // No valid data.
               (lastData == null) || (lastData["clientTs"] == null)
            ) || (
               // Existing data is older than 30 mins.
               // Note: We use clientTs as we do not *know* how often weather data is updated (typically hourly)
               Time.now().value() > (lastData["clientTs"] + (30 * 60))
            )
      ) {
         return true;
      }

      // Check location
      // Note: As we use "Nearest City" API, we expect there to be some distance between user and location returned from API.
      if (  (
               // Current location data valid
               (gLocationLat != null) && (gLocationLat != null)
            ) && (
               // Existing data not for this location.
               // Not a great test, as a degree of longitude varies betwee 69 (equator) and 0 (pole) miles, but simpler than
               // true distance calculation. 0.145 degree of latitude is 10 mile.
               // Note as API is using "Nearest City" we use 10 mile resolution before faster update
               ((gLocationLat - lastData["lat"]).abs() > 0.145) ||
               ((gLocationLng - lastData["lon"]).abs() > 0.145)
            )
      ) {
         return true;
      }

      // Data still valid
      return false;
   }

   (:background_method)
   function getServiceDelegate() {
      return [new BackgroundService()];
   }

   // Handle data received from BackgroundService.
   // On success, clear appropriate pendingWebRequests flag.
   // data is Dictionary with single key that indicates the data type received. This corresponds with Object Store and
   // pendingWebRequests keys.
   function onBackgroundData(data) {
      var pendingWebRequests = getProperty("PendingWebRequests");
      if (pendingWebRequests == null) {
         pendingWebRequests = {};
      }

      var keys = data.keys();
      for(var i=0; i< keys.size(); i++) {
         var type = keys[i];

         var storedData = getProperty(type);
         var receivedData = data[type]; // The actual data received: strip away type key.

         // New data received: clear pendingWebRequests flag and overwrite stored data.
         pendingWebRequests.remove(type);
         setProperty("PendingWebRequests", pendingWebRequests);
         setProperty(type, receivedData);
      }

      // Save list of any remaining background requests
      setProperty("PendingWebRequests", pendingWebRequests);
      Ui.requestUpdate();
   }

   function getFormattedDate() {
      var now = Time.now();
      var date = Date.info(now, Time.FORMAT_SHORT);
      var date_formatter = Application.getApp().getProperty("date_format");
      if (date_formatter == 0) {
         if (Application.getApp().getProperty("force_date_english")) {
            var day_of_week = date.day_of_week;
            return Lang.format("$1$ $2$", [
               days[day_of_week],
               date.day.format("%d"),
            ]);
         } else {
            var long_date = Date.info(now, Time.FORMAT_LONG);
            var day_of_week = long_date.day_of_week;
            return Lang.format("$1$ $2$", [
               day_of_week.toUpper(),
               date.day.format("%d"),
            ]);
         }
      } else if (date_formatter == 1) {
         // dd/mm
         return Lang.format("$1$.$2$", [
            date.day.format("%d"),
            date.month.format("%d"),
         ]);
      } else if (date_formatter == 2) {
         // mm/dd
         return Lang.format("$1$.$2$", [
            date.month.format("%d"),
            date.day.format("%d"),
         ]);
      } else if (date_formatter == 3) {
         // dd/mm/yyyy
         var year = date.year;
         var yy = year / 100.0;
         yy = Math.round((yy - yy.toNumber()) * 100.0);
         return Lang.format("$1$.$2$.$3$", [
            date.day.format("%d"),
            date.month.format("%d"),
            yy.format("%d"),
         ]);
      } else if (date_formatter == 4) {
         // mm/dd/yyyy
         var year = date.year;
         var yy = year / 100.0;
         yy = Math.round((yy - yy.toNumber()) * 100.0);
         return Lang.format("$1$.$2$.$3$", [
            date.month.format("%d"),
            date.day.format("%d"),
            yy.format("%d"),
         ]);
      } else if (date_formatter == 5 || date_formatter == 6) {
         // dd mmm
         var day = null;
         var month = null;
         if (Application.getApp().getProperty("force_date_english")) {
            day = date.day;
            month = months[date.month];
         } else {
            var medium_date = Date.info(now, Time.FORMAT_MEDIUM);
            day = medium_date.day;
            month = months[medium_date.month];
         }
         if (date_formatter == 5) {
            return Lang.format("$1$ $2$", [day.format("%d"), month]);
         } else {
            return Lang.format("$1$ $2$", [month, day.format("%d")]);
         }
      }
   }

   function toKValue(value) {
      var valK = value / 1000.0;
      return valK.format("%0.1f");
   }
}
