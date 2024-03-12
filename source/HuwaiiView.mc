using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;
using Toybox.Lang;

using Toybox.Time.Gregorian as Date;
using Toybox.Application as App;
using Toybox.ActivityMonitor as Mon;
using Toybox.UserProfile;

var small_digi_font = null;
var second_digi_font = null;
var second_x = 160;
var second_y = 140;
var heart_x = 80;
var center_x;
var center_y;

var second_font_height_half = 7;
var second_background_color = 0x000000;
var second_font_color = 0xffffff;
var second_clip_size = null;

// theming
var gbackground_color = 0x000000;
var gmain_color = 0xffffff;
var gsecondary_color = 0xff0000;
var garc_color = 0x555555;
var gbar_color_indi = 0xaaaaaa;
var gbar_color_back = 0x550000;
var gbar_color_0 = 0xffff00;
var gbar_color_1 = 0x0000ff;

var gtheme = -1;

class HuwaiiView extends WatchUi.WatchFace {

   var last_battery_hour = null;

   var font_padding = 12;
   var font_height_half = 7;

   var face_radius;

   var did_clear = false;

   var screenbuffer = null;

   function initialize() {
      WatchFace.initialize();
   }

   // Load your resources here
   function onLayout(dc) {
      small_digi_font = WatchUi.loadResource(Rez.Fonts.smadigi);
      center_x = dc.getWidth() / 2;
      center_y = dc.getHeight() / 2;

      face_radius = center_x - ((18 * center_x) / 120).toNumber();

      setLayout(Rez.Layouts.WatchFace(dc));

      checkGlobals();
   }

   // Called when this View is brought to the foreground. Restore
   // the state of this View and prepare it to be shown. This includes
   // loading resources into memory.
   function onShow() {
   }

   // Update the view
   function onUpdate(dc) {
      mainDrawComponents(dc);
      // Update always on seconds and HR
      // onPartialUpdate(dc);
   }

   function mainDrawComponents(dc) {
      dc.setColor(Graphics.COLOR_TRANSPARENT, gbackground_color);
      dc.clear();
      dc.setColor(gbackground_color, Graphics.COLOR_TRANSPARENT);
      dc.fillRectangle(0, 0, center_x * 2, center_y * 2);

      var backgroundView = View.findDrawableById("background");
      var bar1 = View.findDrawableById("aBarDisplay");
      var bar2 = View.findDrawableById("bBarDisplay");
      var bar3 = View.findDrawableById("cBarDisplay");
      var bar4 = View.findDrawableById("dBarDisplay");
      var bar5 = View.findDrawableById("eBarDisplay");
      var bar6 = View.findDrawableById("fBarDisplay");
      var bbar1 = View.findDrawableById("bUBarDisplay");
      var bbar2 = View.findDrawableById("tUBarDisplay");

      bar1.draw(dc);
      bar2.draw(dc);
      bar3.draw(dc);
      bar4.draw(dc);
      bar5.draw(dc);
      bar6.draw(dc);

      dc.setColor(gbackground_color, Graphics.COLOR_TRANSPARENT);
      dc.fillCircle(center_x, center_y, face_radius);

      backgroundView.draw(dc);
      bbar1.draw(dc);
      bbar2.draw(dc);

      var bgraph1 = View.findDrawableById("tGraphDisplay");
      var bgraph2 = View.findDrawableById("bGraphDisplay");
      bgraph1.draw(dc);
      bgraph2.draw(dc);

      View.findDrawableById("digital").draw(dc);
   }

   // function onPartialUpdate(dc) {
   //    if (!Application.getApp().getProperty("use_analog")) {
   //       if (Application.getApp().getProperty("always_on_second")) {
   //          var clockTime = System.getClockTime();
   //          var second_text = clockTime.sec.format("%02d");

   //          dc.setClip(
   //             second_x,
   //             second_y,
   //             second_clip_size[0],
   //             second_clip_size[1]
   //          );
   //          dc.setColor(Graphics.COLOR_TRANSPARENT, gbackground_color);
   //          dc.clear();
   //          dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
   //          dc.drawText(
   //             second_x,
   //             second_y - font_padding,
   //             second_digi_font,
   //             second_text,
   //             Graphics.TEXT_JUSTIFY_LEFT
   //          );
   //          dc.clearClip();
   //       }

   //       if (Application.getApp().getProperty("always_on_heart")) {
   //          var h = _retrieveHeartrate();
   //          var heart_text = "--";
   //          if (h != null) {
   //             heart_text = h.format("%d");
   //          }
   //          //var ss = dc.getTextDimensions(heart_text, second_digi_font);
   //          //var s = (ss[0] * 1.2).toNumber();
   //          var s2 = (second_clip_size[0] * 1.25).toNumber();
   //          dc.setClip(heart_x - s2 - 1, second_y, s2 + 2, second_clip_size[1]);
   //          dc.setColor(Graphics.COLOR_TRANSPARENT, gbackground_color);
   //          dc.clear();

   //          dc.setColor(gmain_color, Graphics.COLOR_TRANSPARENT);
   //          dc.drawText(
   //             heart_x - 1,
   //             second_y - font_padding,
   //             second_digi_font,
   //             heart_text,
   //             Graphics.TEXT_JUSTIFY_RIGHT
   //          );
   //          dc.clearClip();
   //       }
   //    }
   // }

   // Called when this View is removed from the screen. Save the
   // state of this View here. This includes freeing resources from
   // memory.
   function onHide() {
   }

   // The user has just looked at their watch. Timers and animations may be started here.
   function onExitSleep() {
      var dialDisplay = View.findDrawableById("analog");
      if (dialDisplay != null) {
         dialDisplay.enableSecondHand();
      }
   }

   // Terminate any active timers and prepare for slow updates.
   function onEnterSleep() {
      if (Application.getApp().getProperty("use_analog")) {
         var dialDisplay = View.findDrawableById("analog");
         if (dialDisplay != null) {
            dialDisplay.disableSecondHand();
         }
      } else {
         if (Application.getApp().getProperty("always_on_second")) {
            var dc = screenbuffer.getDc();
            dc.setClip(
               second_x,
               second_y,
               second_clip_size[0],
               second_clip_size[1]
            );
            dc.setColor(Graphics.COLOR_TRANSPARENT, gbackground_color);
            dc.clear();
         }
      }
   }

   function checkGlobals() {
      checkTheme();
      checkAlwaysOnStyle();
   }

   function checkTheme() {
      var theme_code = Application.getApp().getProperty("theme_code");
      if (gtheme != theme_code || theme_code == 18) {
         if (theme_code == 18) {
            var background_color =
               Application.getApp().getProperty("background_color");
            var text_color =
               Application.getApp().getProperty("text_color");
            var accent_color =
               Application.getApp().getProperty("accent_color");
            var ticks_color =
               Application.getApp().getProperty("ticks_color");
            var bar_background_color =
               Application.getApp().getProperty(
                  "bar_background_color"
               );
            var bar_indicator_color =
               Application.getApp().getProperty("bar_indicator_color");
            var bar_graph_color_top = Application.getApp().getProperty(
               "bar_graph_color_top"
            );
            var bar_graph_color_bottom =
               Application.getApp().getProperty(
                  "bar_graph_color_bottom"
               );
            if (
               background_color != gbackground_color ||
               text_color != gmain_color ||
               accent_color != gsecondary_color ||
               ticks_color != garc_color ||
               bar_background_color != gbar_color_back ||
               bar_indicator_color != gbar_color_indi ||
               bar_graph_color_top != gbar_color_0 ||
               bar_graph_color_bottom != gbar_color_1
            ) {
               // background
               gbackground_color = background_color;
               // main text
               gmain_color = text_color;
               // accent (dividers between complications)
               gsecondary_color = accent_color;
               // ticks
               garc_color = ticks_color;
               // indicator pointing at the bar
               gbar_color_indi = bar_indicator_color;
               // bar background
               gbar_color_back = bar_background_color;
               // bar foreground/graph (top)
               gbar_color_0 = bar_graph_color_top;
               // bar foreground/graph (bottom)
               gbar_color_1 = bar_graph_color_bottom;
            }
         } else {
            var theme_pallete = WatchUi.loadResource(
               Rez.JsonData.theme_pallete
            );
            var theme = theme_pallete["" + theme_code];
            // background
            gbackground_color = theme[0];
            // main text
            gmain_color = theme[1];
            // accent (dividers between complications)
            gsecondary_color = theme[2];
            // ticks
            garc_color = theme[3];
            // indicator pointing at the bar
            gbar_color_indi = theme[4];
            // bar background
            gbar_color_back = theme[5];
            // bar foreground/graph (top)
            gbar_color_0 = theme[6];
            // bar foreground/graph (bottom)
            gbar_color_1 = theme[7];
         }
         // set the global theme
         gtheme = theme_code;
      }
   }

   function checkAlwaysOnStyle() {
      second_digi_font = WatchUi.loadResource(Rez.Fonts.secodigi);
      second_font_height_half = 7;
      second_clip_size = [20, 15];
   }

   function removeAllFonts() {
      View.findDrawableById("analog").removeFont();
      View.findDrawableById("digital").removeFont();
   }

}