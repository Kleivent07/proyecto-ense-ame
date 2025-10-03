import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/src/custom/library.dart';

class Constants {
//colors
static Color colorAccent = HexColor.fromHex("#991f34");
static Color colorPrimary = HexColor.fromHex("#b60927");
static Color colorPrimaryLight = HexColor.fromHex("#f03957");
static Color colorPrimaryDark = HexColor.fromHex("#4b1012");
static Color colorSecondary = HexColor.fromHex("#e08584");
static Color colorBackground = HexColor.fromHex("#fcfcfc");
static Color colorSurface = HexColor.fromHex("#7a4746");
static Color colorError = HexColor.fromHex("#ef132d");
static Color colorOnPrimary = HexColor.fromHex("#683e40");
static Color colorFont = HexColor.fromHex("#040303");
static Color colorButton = HexColor.fromHex("#5c131f");
static Color colorButtonOnPress = HexColor.fromHex("#2e0910");
static Color colorShadow = HexColor.fromHex("#d7c8ca");
static Color colorRosaDark = HexColor.fromHex("#870939");
static Color colorRosaLight = HexColor.fromHex("#f48fb1");
static Color colorRosa = HexColor.fromHex("#ae104b");


// font sizes
  static double fontSizeMega = 40;
  static double fontSizeJumbo = 20;
  static double fontSizeTitle = 25;
  static double fontSizeNormal = 16;
  static double fontSizeSmall = 11;

  static double letterSpacing = -2;

  // text style mega
  static TextStyle textStylePrimaryMega = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeMega, letterSpacing: letterSpacing, fontWeight: FontWeight.w600);
  static TextStyle textStyleAccentMega = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeMega, letterSpacing: letterSpacing, fontWeight: FontWeight.w600);
  static TextStyle textStyleFontMega = GoogleFonts.sora(color: colorFont, fontSize: fontSizeMega, letterSpacing: letterSpacing, fontWeight: FontWeight.w600);
  
  // text style jumbo
  static TextStyle textStylePrimaryJumbo = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeJumbo, fontWeight: FontWeight.w600);
  static TextStyle textStyleAccentJumbo = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeJumbo, fontWeight: FontWeight.w600);
  static TextStyle textStyleFontJumbo = GoogleFonts.sora(color: colorFont, fontSize: fontSizeJumbo, fontWeight: FontWeight.w600);
  static TextStyle textStyleBLANCOJumbo = GoogleFonts.sora(color: colorBackground, fontSize: fontSizeJumbo, fontWeight: FontWeight.w600);
  // text style title
  static TextStyle textStylePrimaryTitle = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeTitle, fontWeight: FontWeight.w800);
  static TextStyle textStyleAccentTitle = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeTitle, fontWeight: FontWeight.w800);
  static TextStyle textStyleFontTitle = GoogleFonts.sora(color: colorFont, fontSize: fontSizeTitle, fontWeight: FontWeight.w800);
  static TextStyle textStyleBLANCOTitle = GoogleFonts.sora(color: colorBackground, fontSize: fontSizeTitle, fontWeight: FontWeight.w800);
  // text style normal
  static TextStyle textStylePrimary = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeNormal, fontWeight: FontWeight.w400);
  static TextStyle textStyleAccent = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeNormal, fontWeight: FontWeight.w400);
  static TextStyle textStyleFont = GoogleFonts.sora(color: colorFont, fontSize: fontSizeNormal, fontWeight: FontWeight.w400);
  static TextStyle textStyleBLANCO = GoogleFonts.sora(color: colorBackground, fontSize: fontSizeNormal, fontWeight: FontWeight.w400);
  // text style small
  static TextStyle textStylePrimarySmall = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeSmall, fontWeight: FontWeight.normal);
  static TextStyle textStyleAccentSmall = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeSmall, fontWeight: FontWeight.normal);
  static TextStyle textStyleFontSmall = GoogleFonts.sora(color: colorFont, fontSize: fontSizeSmall, fontWeight: FontWeight.normal);
  static TextStyle textStyleBLANCOSmall = GoogleFonts.sora(color: colorBackground, fontSize: fontSizeSmall, fontWeight: FontWeight.normal);
  // text style bold
  static TextStyle textStylePrimaryBold = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeNormal, fontWeight: FontWeight.w600);
  static TextStyle textStyleAccentBold = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeNormal, fontWeight: FontWeight.w600);
  static TextStyle textStyleFontBold = GoogleFonts.sora(color: colorFont, fontSize: fontSizeNormal, fontWeight: FontWeight.w600);

  // text style semi bold
  static TextStyle textStylePrimarySemiBold = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeNormal, fontWeight: FontWeight.w500);
  static TextStyle textStyleAccentSemiBold = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeNormal, fontWeight: FontWeight.w500);
  static TextStyle textStyleFontSemiBold = GoogleFonts.sora(color: colorFont, fontSize: fontSizeNormal, fontWeight: FontWeight.w500);
  static TextStyle textStyleBLANCOSemiBold = GoogleFonts.sora(color: colorBackground, fontSize: fontSizeSmall, fontWeight: FontWeight.w500);
  // text style bold
  static TextStyle textStylePrimaryBoldSmall = GoogleFonts.sora(color: colorPrimary, fontSize: fontSizeSmall, fontWeight: FontWeight.w600);
  static TextStyle textStyleAccentBoldSmall = GoogleFonts.sora(color: colorAccent, fontSize: fontSizeSmall, fontWeight: FontWeight.w600);
  static TextStyle textStyleFontBoldSmall = GoogleFonts.sora(color: colorFont, fontSize: fontSizeSmall, fontWeight: FontWeight.w600);
}