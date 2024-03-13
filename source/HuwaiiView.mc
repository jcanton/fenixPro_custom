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

   var font_padding = 12;
   var face_radius;
   var force_redraw_all = false;
   var force_redraw_cmp = false;

   var backgroundView;
   var bar1, bar2, bar3, bar4, bar5, bar6;
   var bbar1, bbar2;
   var bgraph1, bgraph2;

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

      backgroundView = View.findDrawableById("background");
      bar1 = View.findDrawableById("aBarDisplay");
      bar2 = View.findDrawableById("bBarDisplay");
      // bar3 = View.findDrawableById("cBarDisplay");
      bar4 = View.findDrawableById("dBarDisplay");
      bar5 = View.findDrawableById("eBarDisplay");
      bar6 = View.findDrawableById("fBarDisplay");
      bbar1 = View.findDrawableById("bUBarDisplay");
      // bbar2 = View.findDrawableById("tUBarDisplay");
      // bgraph1 = View.findDrawableById("tGraphDisplay");
      // bgraph2 = View.findDrawableById("bGraphDisplay");
      force_redraw_all = true;
   }

   // Called when this View is brought to the foreground. Restore
   // the state of this View and prepare it to be shown. This includes
   // loading resources into memory.
   function onShow() {
      force_redraw_all = true;
   }

   // Update the view
   function onUpdate(dc) {
      var clockTime = System.getClockTime();
      if (force_redraw_all || clockTime.sec % 10 == 0) {
         dc.setColor(Graphics.COLOR_TRANSPARENT, gbackground_color);
         dc.clear();
         backgroundView.draw(dc);
         View.findDrawableById("digital").draw(dc);
         force_redraw_all = false;
         force_redraw_cmp = true;
      }
      bar1.draw(dc, force_redraw_cmp);
      bar2.draw(dc, force_redraw_cmp);
      // bar3.draw(dc, force_redraw_cmp);
      bar4.draw(dc, force_redraw_cmp);
      bar5.draw(dc, force_redraw_cmp);
      bar6.draw(dc, force_redraw_cmp);
      bbar1.draw(dc, force_redraw_cmp);
      // bbar2.draw(dc, force_redraw_cmp);
      // bgraph1.draw(dc, force_redraw_cmp);
      // bgraph2.draw(dc, force_redraw_cmp);
      force_redraw_cmp = false;
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

   // Called when this View is removed from the screen. Save the state of this
   // View here. This includes freeing resources from memory.
   function onHide() {
   }

   // The user has just looked at their watch. Timers and animations may be started here.
   function onExitSleep() {
   }

   // Terminate any active timers and prepare for slow updates.
   function onEnterSleep() {
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

}