import 'dart:convert' as convert;
import 'package:http/http.dart' as http;
import 'err.dart';

const _authorization = 'CWB-4265762E-BC4C-49FE-901B-EABE576583F6';

// 中央氣象局開放資料平臺之資料擷取API
// https://opendata.cwb.gov.tw/dist/opendata-swagger.html

// weather icon
// https://erikflowers.github.io/weather-icons/

const _cwbWxCodeToIconCode = {
  "1": ["wi-day-sunny", "晴天"],
  "2": ["wi-day-cloudy", "晴時多雲"],
  "3": ["wi-day-cloudy", "多雲時晴"],
  "4": ["wi-cloudy", "多雲"],
  "5": ["wi-day-cloudy", "多雲時陰"],
  "6": ["wi-day-cloudy", "陰時多雲"],
  "7": ["wi-cloud", "陰天"],
  "8": ["wi-showers", "多雲陣雨"],
  "9": ["wi-showers", "多雲時陰短暫雨"],
  "10": ["wi-showers", "陰時多雲短暫雨"],
  "12": ["wi-showers", "多雲時陰有雨"],
  "13": ["wi-showers", "陰時多雲有雨"],
  "14": ["wi-showers", "陰有雨"],
  "15": ["wi-day-storm-showers", "多雲陣雨或雷雨"],
  "16": ["wi-day-storm-showers", "多雲時陰雷陣雨"], //多雲時陰陣雨或雷雨
  "17": ["wi-day-storm-showers", "陰時多雲雷陣雨"], //陰時多雲有雷陣雨
  "18": ["wi-day-storm-showers", "陰有雷陣雨"], //陰有陣雨或雷雨
  "19": ["wi-day-showers", "晴午後多雲局部雨"],
  "20": ["wi-day-showers", "多雲午後局部雨"],
  "21": ["wi-day-showers", "晴午後多雲雷陣雨"], //晴午後多雲陣雨或雷雨
  "22": ["wi-day-showers", "多雲午後局部雷陣"], // 多雲午後局部陣雨或雷雨
  "23": ["wi-day-showers", "多雲局部陣雨或雪"], // 多雲局部陣雨或雪
  "24": ["wi-day-fog", "晴有霧"], // 晴有霧
  "25": ["wi-day-fog", "晴時多雲有霧"], // 晴時多雲有霧
  "26": ["wi-day-fog", "多雲時晴有霧"], // 多雲時晴有霧
  "27": ["wi-day-fog", "多雲有霧"], // 多雲有霧
  "28": ["wi-fog", "陰有霧"], // 陰有霧
  "29": ["wi-showers", "多雲局部雨"], // 多雲局部雨
  "30": ["wi-showers", "多雲時陰局部雨"], // 多雲時陰局部雨
  "31": ["wi-rain", "多雲有霧有局部雨"], // 多雲有霧有局部雨
  "32": ["wi-rain", "多雲時陰有霧有局部雨"], // 多雲時陰有霧有局部雨
  "33": ["wi-thunderstorm", "多雲局部雷陣雨"], // 多雲局部陣雨或雷雨
  "34": ["wi-thunderstorm", "多雲時陰局部雷陣雨"], // 多雲時陰局部陣雨或雷雨
  "35": ["wi-thunderstorm", "多雲有雷陣雨有霧"], // 多雲有陣雨或雷雨有霧
  "36": ["wi-thunderstorm", "多雲時陰有雷陣雨有霧"], // 多雲時陰有陣雨或雷雨有霧
  "37": ["wi-fog", "多雲局部雨或雪有霧"], // 多雲局部雨或雪有霧
  "38": ["wi-fog", "短暫陣雨有霧"], // 短暫陣雨有霧
  "39": ["wi-fog", "有雨有霧"], // 有雨有霧
  // 沒有 40
  "41": ["wi-fog", "短暫雷陣雨有霧"], // 短暫陣雨或雷雨有霧
  "42": ["wi-snow", "下雪"] // 下雪
};

String cwbWxCodeToIconCode(wx, [String? t]) {
  if (isNight(t)) {
    return _cwbWxCodeToIconCode[wx]![0].replaceAll('day', 'night');
  }
  return _cwbWxCodeToIconCode[wx]![0];
}

// 將原本比較長的天氣描術修短
String cwbWxCodeToWeather(wx) {
  return _cwbWxCodeToIconCode[wx]![1];
}

String cwdCurrentWeatherToIconCode(String weather) {
  if (weather == '-99') {
    return 'wi-na';
  }
/*
* 晴、多雲、陰
* x
* -、有霾、有靄、有閃電、有雷聲、有霧、有雨、有雨雪、有大雪、有雪珠、有冰珠、有陣雨
* 陣雨雪、有雹、有雷雨、有雷雪、有雷雹、大雷雨、大雷雹、有雷
* */
/*
* 分類：(有按照先後篩選條件)
* 有雨雪、有大雪、有雪珠、陣雨雪、有冰珠  (關鍵字：雪、冰)
* 有閃電、有雷聲、有雷 (關鍵字：閃電、雷聲)
* 有雷雨、有雷雪、有雷雹、大雷雨、大雷雹 (關鍵字：雷)
* 有雨、有陣雨 (關鍵字：雨)
* 有雹 (雹)
* 有靄、有霧、 (關鍵字：靄、霧)
* 有霾 (霾)
* - (單純有字首無字尾)
* */
  RegExp qing = new RegExp("^晴.*");
  RegExp duoyun = new RegExp("^多雲.*");
  RegExp xueBing = new RegExp(".*[雪冰]\\S?");
  RegExp shandian = new RegExp(".*[(有閃電)(有雷聲)(有雷)]\$");
  RegExp rei = new RegExp(".*[雷]\\S?");
  RegExp yu = new RegExp(".*[雨]\$");
  RegExp aiU = new RegExp(".*[靄霧]\\S?");
  RegExp mai = new RegExp(".*[霾]\\S?");
  RegExp bao = new RegExp(".*[雹]\$");

  String prefix = "陰";
  if (qing.hasMatch(weather)) {
    prefix = "晴";
  } else if (duoyun.hasMatch(weather)) {
    prefix = "多雲";
  }

  String ret = 'wi-na';
  if (prefix == '晴') {
    if (xueBing.hasMatch(weather)) {
      ret = 'wi-day-snow';
    } else if (shandian.hasMatch(weather)) {
      ret = 'wi-day-lightning';
    } else if (rei.hasMatch(weather)) {
      ret = 'wi-day-thunderstorm';
    } else if (yu.hasMatch(weather)) {
      ret = 'wi-day-rain';
    } else if (aiU.hasMatch(weather)) {
      ret = 'wi-day-fog';
    } else if (mai.hasMatch(weather)) {
      ret = 'wi-day-haze';
    } else if (bao.hasMatch(weather)) {
      ret = 'wi-day-hail';
    } else {
      ret = 'wi-day-sunny';
    }
  } else if (prefix == '多雲' || prefix == '陰') {
    if (xueBing.hasMatch(weather)) {
      ret = 'wi-snow';
    } else if (shandian.hasMatch(weather)) {
      ret = 'wi-lightning';
    } else if (rei.hasMatch(weather)) {
      ret = 'wi-thunderstorm';
    } else if (yu.hasMatch(weather)) {
      ret = 'wi-rain';
    } else if (aiU.hasMatch(weather)) {
      ret = 'wi-fog';
    } else if (mai.hasMatch(weather)) {
      ret = 'wi-dust';
    } else if (bao.hasMatch(weather)) {
      ret = 'wi-hail';
    } else {
      ret = 'wi-cloudy';
      if (prefix == '陰') {
        ret = 'wi-cloud';
      }
    }
  }
  if (isNight()) {
    ret.replaceAll('day', 'night');
  }

  return ret;
}

Future<dynamic> getForecastWeather(city) async {
  var response = await http.get(
      Uri.https('opendata.cwb.gov.tw', '/api/v1/rest/datastore/F-C0032-001',
          {'Authorization': _authorization, 'locationName': city}),
      headers: {'accept': 'application/json'});
  // add accept:application/json to prevent getting SocketException() after building
  if (response.statusCode == 200) {
    var jsonResponse = convert.jsonDecode(response.body);
    if (jsonResponse["success"] == "true") {
      List retList = [];
      var parameter = jsonResponse["records"]["location"][0]["weatherElement"];
      for (int j = 0; j < 3; j++) {
        Map ret = {};
        ret["startTime"] = parameter[0]["time"][j]["startTime"];
        ret["endTime"] = parameter[0]["time"][j]["endTime"];
        for (var i = 0; i < parameter.length; i++) {
          ret[parameter[i]["elementName"]] =
              parameter[i]["time"][j]["parameter"];
        }
        retList.add(ret);
      }
      return retList;
    }
  }
  return null;
}

Future<Map> getCurrentWeather(station) async {
  // api 說明檔
  // https://opendata.cwb.gov.tw/opendatadoc/DIV2/A0003-001.pdf
  var response = await http.get(Uri.https(
      'opendata.cwb.gov.tw',
      '/api/v1/rest/datastore/O-A0003-001',
      {'Authorization': _authorization, 'locationName': station}));
  if (response.statusCode == 200) {
    var jsonResponse = convert.jsonDecode(response.body);
    try {
      if (jsonResponse["success"] == "true") {
        var weatherElement =
            jsonResponse["records"]["location"][0]["weatherElement"];
        var len = weatherElement.length;
        Map ret = {};
        for (var i = 0; i < len; i++) {
          ret[weatherElement[i]["elementName"]] =
              weatherElement[i]["elementValue"] as String;
        }
        return ret;
      }
    } catch (e) {
      throw e;
    }
  }
  throw ErrorNetwork(response.statusCode);
}

bool isNight([String? t]) {
  int hour = t == null ? new DateTime.now().hour : DateTime.parse(t).hour;
  return hour < 6 || hour >= 18;
}
