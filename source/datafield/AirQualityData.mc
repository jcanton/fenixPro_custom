using Toybox.Application as App;
using Toybox.System as Sys;

/** AirQuality */
class AirQualityField extends BaseDataField {
   function initialize(id) {
      BaseDataField.initialize(id);
   }

   function cur_label(value) {
      var need_minimal = App.getApp().getProperty("minimal_data");
      var data = App.getApp().getProperty($.DATA_TYPE_AIR_QUALITY);
      if (data == null) {
         var error = App.getApp().getProperty($.DATA_TYPE_AIR_QUALITY + $.DATA_TYPE_ERROR_SUFFIX);

         if (error != null) {
            // Error
            return Lang.format("ERR $1$", [ error["code"] ]);
         } else {
            // No Data
            if (need_minimal) {
               return "--";
            } else {
               return "AI --";
            }
         }
      } else {
         // TODO Show --/err if valid data is older than XX hours
         var aqius = data["aqius"];

         if (need_minimal) {
            return aqius.toString();
         } else {
            // NOTE: Cannot use "AQI" as "Q" is missing from arc text font!
            return Lang.format("AI $1$", [ aqius ]);
         }
      }
   }
}
