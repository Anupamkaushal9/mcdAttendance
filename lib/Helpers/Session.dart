import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import 'Constant.dart';
import 'Demo_Localization.dart';

Future<bool> isNetworkAvailable() async {
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.mobile) {
    return true;
  } else if (connectivityResult == ConnectivityResult.wifi) {
    return true;
  }
  return false;
}

getBasicAuth(){
  String basicAuth =
      'Basic ${base64.encode(utf8.encode('$authUserName:$authPassword'))}';
  return basicAuth;
}

Map<String, String> get headers => {
  'Authorization': '${getBasicAuth()}',
};

String? getTranslated(BuildContext context, String key) {
  return DemoLocalization.of(context)!.translate(key);
}

noIntImage() {
  return SvgPicture.asset(
    'assets/images/no_internet.svg',
    fit: BoxFit.contain,
  );
}

noIntText(BuildContext context) {
  return Text(getTranslated(context, 'NO_INTERNET')!,
      style: Theme.of(context)
          .textTheme
          .headlineMedium!
          .copyWith(color: const Color(0xffd11818), fontWeight: FontWeight.normal));
}

noIntDec(BuildContext context) {
  return Container(
    padding:
        const EdgeInsetsDirectional.only(top: 30.0, start: 30.0, end: 30.0),
    child: Text(getTranslated(context, 'NO_INTERNET_DISC')!,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.headlineSmall!.copyWith(
              color: const Color(0xff999999),
              fontWeight: FontWeight.normal,
            )),
  );
}
