using Toybox.WatchUi as Ui;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Activity;
using Toybox.ActivityMonitor;
using Toybox.Application;

function getBarDataComplicationSettingDataKey(position) {
   if (position == 0) {
      // upper
      return Application.getApp().getProperty("compbart");
   } else if (position == 1) {
      // lower
      return Application.getApp().getProperty("compbarb");
   }
}

class BarDataComplication extends BarComplication {
   var dt_field;
   var field_type;
   var curval;
   var prevval;

   function initialize(params) {
      BarComplication.initialize(params);
      field_type = params.get(:field_type);
      dt_field = buildFieldObject(field_type);
      prevval = dt_field.min_val()-1;
   }

   function min_val() {
      var curval = dt_field.min_val();
      return curval;
   }

   function max_val() {
      var curval = dt_field.max_val();
      return curval;
   }

   function cur_val() {
      var curval = dt_field.cur_val();
      return curval;
   }

   function get_title() {
      var curval = dt_field.cur_val();
      //var pre_label = dt_field.cur_label(curval);
      var pre_label = "";
      return pre_label;
   }

   function need_draw() {
      return curval != prevval;
   }

   function bar_data() {
      return dt_field.bar_data();
   }

   function getSettingDataKey() {
      if (position == 0) {
         // upper
         return Application.getApp().getProperty("compbart");
      } else if (position == 1) {
         // lower
         return Application.getApp().getProperty("compbarb");
      }
   }

   function draw(dc, force_draw) {
      field_type = getSettingDataKey();
      if (field_type != dt_field.field_id()) {
         dt_field = buildFieldObject(field_type);
      }

      curval = cur_val(); 
      if (force_draw || need_draw()) {
         BarComplication.draw(dc);
         prevval = curval;
      }
   }
}
