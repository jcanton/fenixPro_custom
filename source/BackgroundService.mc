using Toybox.Background as Bg;
using Toybox.System as Sys;
using Toybox.Communications as Comms;
using Toybox.Application as App;

import Toybox.Lang;

const DATA_TYPE_AIR_QUALITY = "AirQuality";
const DATA_TYPE_WEATHER     = "OpenWeatherMapCurrent";

const DATA_TYPE_ERROR_SUFFIX = ".Error";

//! Background Service
//! Container for all background service requests.
//!
//!
//! @note Service may be terminated at any time to free memory for foreground applications.
//!       Service will also be terminated automatically if does not exit properly within 30 seconds of opening.
//! @see https://developer.garmin.com/connect-iq/core-topics/backgrounding/
(:background)
class BackgroundService extends Sys.ServiceDelegate {

   // Cached results
   var _results = {} as Dictionary<String, Dictionary<String, Lang.Any>>;
   var _expectedResults = {} as Dictionary<String, Number>;

   // Clients
   var _iqAirClient as IQAirClient?;

   (:background_method)
   function initialize() {
      Sys.ServiceDelegate.initialize();
   }

   // Read pending web requests, and call appropriate web request function.
   // This function determines priority of web requests, if multiple are pending.
   // Pending web request flag will be cleared only once the background data has been successfully received.
   (:background_method)
   function onTemporalEvent() {
      var pendingWebRequests = App.getApp().getProperty("PendingWebRequests");
      if (pendingWebRequests != null) {
         if (pendingWebRequests[$.DATA_TYPE_WEATHER] != null) {
            var api_key = App.getApp().getProperty("openweathermap_api");
            if (api_key.length() == 0) {
               api_key = "1cb1d74009767c92444cc93abfc31ef5"; // default apikey
            }
            makeWebRequest(
               "https://api.openweathermap.org/data/2.5/weather",
               {
                  "lat" => App.getApp().getProperty("LastLocationLat"),
                  "lon" => App.getApp().getProperty("LastLocationLng"),
                  "appid" => api_key,
                  "units" => "metric", // Celsius.
               },
               method(:onReceiveOpenWeatherMapCurrent)
            );
            _expectedResults[$.DATA_TYPE_WEATHER] = 1;
         }

         if (pendingWebRequests[$.DATA_TYPE_AIR_QUALITY] != null) {
            // Create client
            if (_iqAirClient == null) {
               _iqAirClient = new IQAirClient();
            }
            _iqAirClient.requestAirQualityData(method(:onReceiveClientData));
            _expectedResults[$.DATA_TYPE_AIR_QUALITY] = 1;
         }
      }
   }

   //! Receives client data and evaluate exiting background service
   (:background_method)
   function onReceiveClientData(type as String, responseCode as Number, data as Dictionary<String, Lang.Any>) {
      // Store data
      if (responseCode == 200) {
         // Valid data
         _results[type] = data;
      } else {
         // return error to the caller, without over-writing valid data
         // Note: Does not clear PendingWebRequests so request will be re-tried on next temporal event (every 5 minutes)
         _results[type + $.DATA_TYPE_ERROR_SUFFIX] = data;
      }

      // Exit background service and return results when all requests complete
      _expectedResults.remove(type);
      if (_expectedResults.size() == 0) {
         Bg.exit(_results);
      }
   }

   (:background_method)
   function onReceiveOpenWeatherMapCurrent(responseCode, data) {
      var result;

      // Useful data only available if result was successful.
      // Filter and flatten data response for data that we actually need.
      // Reduces runtime memory spike in main app.
      if (responseCode == 200) {
         result = {
            "cod" => data["cod"],
            "lat" => data["coord"]["lat"],
            "lon" => data["coord"]["lon"],
            "dt" => data["dt"],
            "temp" => data["main"]["temp"],
            "temp_min" => data["main"]["temp_min"],
            "temp_max" => data["main"]["temp_max"],
            "humidity" => data["main"]["humidity"],
            "wind_speed" => data["wind"]["speed"],
            "wind_direct" => data["wind"]["deg"],
            "icon" => data["weather"][0]["icon"],
            "des" => data["weather"][0]["main"],
            "clientTs" => Time.now().value()
         };
      } else {
         // Error
         result = {
            "cod" => responseCode,
            "clientTs" => Time.now().value()
         };
      }
      onReceiveClientData($.DATA_TYPE_WEATHER, responseCode, result);
   }

   (:background_method)
   function makeWebRequest(url, params, callback) {
      var options = {
         :method => Comms.HTTP_REQUEST_METHOD_GET,
         :headers => {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
         },
         :responseType => Comms.HTTP_RESPONSE_CONTENT_TYPE_JSON,
      };

      Comms.makeWebRequest(url, params, options, callback);
   }
}
