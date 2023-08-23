using Toybox.Background;
using Toybox.System;
using Toybox.Communications;
using Toybox.Application;
using Toybox.Time;

import Toybox.Lang;

//! IQAir Client for Air Quality Index (AQI) Service
//!
//! @note Uses "Get nearest city data" to read AQI data
//!
//! @see https://www.iqair.com/ca/air-pollution-data-api
//! @see https://api-docs.iqair.com/?version=latest#5ea0dcc1-78c3-4939-aa80-6d4929646b82
(:background)
class IQAirClient {

   const CLIENT_NAME = "IQAir";
   const DATA_TYPE_AIR_QUALITY = "AirQuality";

   //! Uses "Get nearest city data" API to read AQI data
   //! (IP geolocation) http://api.airvisual.com/v2/nearest_city?key={{YOUR_API_KEY}}
   //! (GPS coordinates) http://api.airvisual.com/v2/nearest_city?lat={{LATITUDE}}&lon={{LONGITUDE}}&key={{YOUR_API_KEY}}
   const API_NEAREST_CITY_URL = "https://api.airvisual.com/v2/nearest_city";

   //! Consumer callback for returning formatted data
   private var _callback as Method(type as String, responseCode as Number, data as Dictionary<String, Lang.Any>) as Void;

   function initialize() {
      System.ServiceDelegate.initialize();
   }

   //! Public entry method to make background request to get data from remote service
   function requestAirQualityData(callback as Method(type as String, responseCode as Number, data as Dictionary<String, Lang.Any>) as Void) as Void {
      var app = Application.getApp();
      var key = app.getProperty("iqair_api");
      var lat = app.getProperty("LastLocationLat");
      var lon = app.getProperty("LastLocationLng");

      // Save callback method
      self._callback = callback;

      if (key.length() == 0) {
         key = "582a5d0c-abd9-41c5-ba3e-e7110915cfc0"; // default apikey
      }

      var params = {
         "key" => key
      };

      if ((lat != null) && (lon != null)) {
         // Use location data (else uses IP geolocation)
         params["lat"] = lat;
         params["lon"] = lon;
      }

      makeWebRequest(
         API_NEAREST_CITY_URL,
         params,
         method(:onReceiveAirQualityData)
      );
   }

   //! onReceiveAirQualityData
   //!
   //! Callback handler for makeWebRequest. Decodes response and flatten (extract) data we need
   function onReceiveAirQualityData(responseCode as Number, data as Dictionary?) {
      var result;

      // Useful data only available if result was successful.
      // Filter and flatten data response for data that we actually need.
      // Reduces runtime memory spike in main app.
      if (responseCode != 200) {
         // Error
         var hasData = ((data!=null) && (data.hasKey("status")) && data.hasKey("data") && data["data"].hasKey("message"));
         result = {
            "code" =>    responseCode,
            "status" =>  hasData ? data["status"] : responseCode.toString(),
            "message" => hasData ? data["data"]["message"] : "HTTP Error " + responseCode.toString(),
            "client" =>  CLIENT_NAME,
            "clientTs" => Time.now().value()
         };
      } else {
         // Success
         result = {
            "code" => responseCode,
            "status" => data["status"],
            "city" =>   data["data"]["city"],
            "country" =>data["data"]["country"],
            "lat" =>    data["data"]["location"]["coordinates"][1],
            "lon" =>    data["data"]["location"]["coordinates"][0],
            "ts" =>     data["data"]["current"]["pollution"]["ts"],
            "aqius" =>  data["data"]["current"]["pollution"]["aqius"],
            "mainus" => data["data"]["current"]["pollution"]["mainus"],
            "aqicn" =>  data["data"]["current"]["pollution"]["aqicn"],
            "maincn" => data["data"]["current"]["pollution"]["maincn"],
            "client" => CLIENT_NAME,
            "clientTs" => Time.now().value()
         };
      }

      // Send formatted result to registered callback
      _callback.invoke(DATA_TYPE_AIR_QUALITY, responseCode, result);
   }

   protected function makeWebRequest(url, params, callback) as Void {
      var options = {
         :method => Communications.HTTP_REQUEST_METHOD_GET,
         :headers => {
            "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
         },
         :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
      };

      Communications.makeWebRequest(url, params, options, callback);
   }
}
