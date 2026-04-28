import 'dart:typed_data';

enum _ValidUpiApps {
  allBank,
  amazonPay,
  axisPay,
  barodaPay,
  bhim,
  boiUpi,
  centUpi,
  cointab,
  corpUpi,
  csbUpi,
  cubUpi,
  digibank,
  dcbUpi,
  equitasUpi,
  finoBPay,
  freecharge,
  googlePay,
  hsbcSimplyPay,
  iMobileICICI,
  indusPay,
  kblUpi,
  khaaliJeb,
  kotak,
  mahaUpi,
  miPayGlobal,
  miPayXiaomi,
  mobikwik,
  orientalPay,
  paytm,
  paywiz,
  payZapp,
  phonePe,
  pnb,
  psb,
  rblPay,
  realmePaySa,
  sbiPay,
  trueCallerUpi,
  unitedUpiPay,
  vijayaUpi,
  yesPay,
}

/// This is the model class of apps returned by [getAllUpiApps()].
/// This class contains some predefined package names of UPI apps.
class UpiApp {
  /// BHIM ALLBANK UPI(Allahabad Bank): com.lcode.allahabadupi
  static UpiApp allBank = UpiApp._fromEnum(_ValidUpiApps.allBank);

  /// Amazon(Amazon Mobile LLC): in.amazon.mShop.android.shopping
  static UpiApp amazonPay = UpiApp._fromEnum(_ValidUpiApps.amazonPay);

  /// BHIM Axis Pay(Axis Bank Ltd.): com.upi.axispay
  static UpiApp axisPay = UpiApp._fromEnum(_ValidUpiApps.axisPay);

  /// BHIM Baroda Pay(Bank of Baroda): com.bankofbaroda.upi
  static UpiApp barodaPay = UpiApp._fromEnum(_ValidUpiApps.barodaPay);

  /// BHIM(National Payments Corporation of India): in.org.npci.upiapp
  static UpiApp bhim = UpiApp._fromEnum(_ValidUpiApps.bhim);

  /// BHIM BOI UPI(Bank of India Official): com.infra.boiupi
  static UpiApp boiUpi = UpiApp._fromEnum(_ValidUpiApps.boiUpi);

  /// BHIM Cent UPI(CENTRAL BANK OF INDIA): com.infrasofttech.centralbankupi
  static UpiApp centUpi = UpiApp._fromEnum(_ValidUpiApps.centUpi);

  /// Cointab: in.cointab.app
  static UpiApp cointab = UpiApp._fromEnum(_ValidUpiApps.cointab);

  /// BHIM CORP UPI(Corporation Bank): com.lcode.corpupi
  static UpiApp corpUpi = UpiApp._fromEnum(_ValidUpiApps.corpUpi);

  /// BHIM CSB-UPI(CSB Bank Ltd): com.lcode.csbupi
  static UpiApp csbUpi = UpiApp._fromEnum(_ValidUpiApps.csbUpi);

  ///BHIM CUB UPI(CITY UNION BANK LTD): com.cub.wallet.gui
  static UpiApp cubUpi = UpiApp._fromEnum(_ValidUpiApps.cubUpi);

  /// BHIM DCB Bank UPI(DCB Bank): com.olive.dcb.upi
  static UpiApp dcbUpi = UpiApp._fromEnum(_ValidUpiApps.dcbUpi);

  ///digibank(DBS Bank India): com.dbs.in.digitalbank
  static UpiApp digibank = UpiApp._fromEnum(_ValidUpiApps.digibank);

  /// BHIM Equitas UPI(Equitas Small Finance Bank Ltd): com.equitasbank.upi
  static UpiApp equitasUpi = UpiApp._fromEnum(_ValidUpiApps.equitasUpi);

  /// Fino BPay(Fino Payments Bank): com.finopaytech.bpayfino
  static UpiApp finoBPay = UpiApp._fromEnum(_ValidUpiApps.finoBPay);

  /// Freecharge: com.freecharge.android
  static UpiApp freecharge = UpiApp._fromEnum(_ValidUpiApps.freecharge);

  /// Google Pay(GoogleLLC): com.google.android.apps.nbu.paisa.user
  static UpiApp googlePay = UpiApp._fromEnum(_ValidUpiApps.googlePay);

  /// HSBC Simply Pay(HSBC India): com.mgs.hsbcupi
  static UpiApp hsbcSimplyPay = UpiApp._fromEnum(_ValidUpiApps.hsbcSimplyPay);

  /// iMobile(ICICI Bank Ltd.): com.csam.icici.bank.imobile
  static UpiApp iMobileICICI = UpiApp._fromEnum(_ValidUpiApps.iMobileICICI);

  /// BHIM IndusPay(IndusInd Bank Ltd.): com.mgs.induspsp
  static UpiApp indusPay = UpiApp._fromEnum(_ValidUpiApps.indusPay);

  /// BHIM KBL UPI(KARNATAKA BANK): com.lcode.smartz
  static UpiApp kblUpi = UpiApp._fromEnum(_ValidUpiApps.kblUpi);

  /// KhaaliJeb: com.khaalijeb.inkdrops
  static UpiApp khaaliJeb = UpiApp._fromEnum(_ValidUpiApps.khaaliJeb);

  /// Kotak - 811 & Mobile Banking(Kotak Mahindra Bank Ltd): com.msf.kbank.mobile
  static UpiApp kotak = UpiApp._fromEnum(_ValidUpiApps.kotak);

  /// BHIM Maha UPI(Bank of Maharashtra): com.infrasofttech.mahaupi
  static UpiApp mahaUpi = UpiApp._fromEnum(_ValidUpiApps.mahaUpi);

  /// Mi Pay(Non Xiaomi devices): com.mipay.in.wallet (From Play Store)
  static UpiApp miPayGlobal = UpiApp._fromEnum(_ValidUpiApps.miPayGlobal);

  /// Mi Pay(Only Xiaomi devices): com.mipay.wallet.in (From Get Apps)
  static UpiApp miPayXiaomi = UpiApp._fromEnum(_ValidUpiApps.miPayXiaomi);

  /// Mobikwik: com.mobikwik_new
  static UpiApp mobikwik = UpiApp._fromEnum(_ValidUpiApps.mobikwik);

  /// BHIM Oriental Pay(Oriental Bank of Commerce): com.mgs.obcbank
  static UpiApp orientalPay = UpiApp._fromEnum(_ValidUpiApps.orientalPay);

  /// Paytm(Paytm-One97 Communications Ltd.): net.one97.paytm
  static UpiApp paytm = UpiApp._fromEnum(_ValidUpiApps.paytm);

  ///BHIM PayWiz(IDBI BANK): com.idbibank.paywiz
  static UpiApp paywiz = UpiApp._fromEnum(_ValidUpiApps.paywiz);

  ///PayZapp(HDFC Bank Ltd.): com.enstage.wibmo.hdfc
  static UpiApp payZapp = UpiApp._fromEnum(_ValidUpiApps.payZapp);

  /// PhonePe: com.phonepe.app
  static UpiApp phonePe = UpiApp._fromEnum(_ValidUpiApps.phonePe);

  ///BHIM PNB(PNB): com.fss.pnbpsp
  static UpiApp pnb = UpiApp._fromEnum(_ValidUpiApps.pnb);

  /// BHIM PSB(PUNJAB & SIND BANK): com.mobileware.upipsb
  static UpiApp psb = UpiApp._fromEnum(_ValidUpiApps.psb);

  /// BHIM RBL Pay(RBL Bank Ltd.): com.rblbank.upi
  static UpiApp rblPay = UpiApp._fromEnum(_ValidUpiApps.rblPay);

  /// realme PaySa(M-Kash India Financial Solutions Private Limited): com.realmepay.payments
  static UpiApp realmePaySa = UpiApp._fromEnum(_ValidUpiApps.realmePaySa);

  /// BHIM SBI Pay(State Bank of India): com.sbi.upi
  static UpiApp sbiPay = UpiApp._fromEnum(_ValidUpiApps.sbiPay);

  /// Truecaller(True Software Scandinavia AB): com.truecaller
  static UpiApp trueCallerUPI = UpiApp._fromEnum(_ValidUpiApps.trueCallerUpi);

  ///BHIM United UPI Pay(United Bank of India): com.fss.unbipsp
  static UpiApp unitedUpiPay = UpiApp._fromEnum(_ValidUpiApps.unitedUpiPay);

  /// BHIM VIJAYA UPI App(Vijaya Bank): com.fss.vijayapsp
  static UpiApp vijayaUpi = UpiApp._fromEnum(_ValidUpiApps.vijayaUpi);

  /// BHIM YES PAY(Yes Bank Limited): com.YesBank
  static UpiApp yesPay = UpiApp._fromEnum(_ValidUpiApps.yesPay);

  /// app is the package name of the app. Pass this in [app] argument of [startTransaction]
  late String packageName;

  /// This is the app name for display purpose
  late String name;

  /// This is the icon of the UPI app. Pass it in [Image.memory()] to display the icon.
  late Uint8List icon;

  // Default constructor
  UpiApp(appName, package) {
    packageName = package;
    name = appName;
  }

  // Constructor for enum
  UpiApp._fromEnum(_ValidUpiApps app) {
    packageName = _getPackageName(app);
    name = _getName(app);
  }

  // Constructor for apps returned by PackageManager containing App Icon
  UpiApp.fromMap(Map<String, dynamic> m) {
    packageName = m['packageName'];
    name = m['name'];
    icon = m['icon'];
  }

  String _getName(_ValidUpiApps app) {
    switch (app) {
      case _ValidUpiApps.allBank:
        return 'ALLBANK';
      case _ValidUpiApps.amazonPay:
        return 'Amazon Pay';
      case _ValidUpiApps.axisPay:
        return 'Axis Pay';
      case _ValidUpiApps.barodaPay:
        return 'Baroda Pay';
      case _ValidUpiApps.bhim:
        return 'BHIM';
      case _ValidUpiApps.boiUpi:
        return 'BOI UPI';
      case _ValidUpiApps.centUpi:
        return 'Cent UPI';
      case _ValidUpiApps.cointab:
        return 'Cointab';
      case _ValidUpiApps.corpUpi:
        return 'CORP UPI';
      case _ValidUpiApps.csbUpi:
        return 'CSB UPI';
      case _ValidUpiApps.cubUpi:
        return "CUB UPI";
      case _ValidUpiApps.digibank:
        return "Digibank UPI";
      case _ValidUpiApps.dcbUpi:
        return 'DCB UPI';
      case _ValidUpiApps.equitasUpi:
        return "Equitas UPI";
      case _ValidUpiApps.finoBPay:
        return 'Fino BPay';
      case _ValidUpiApps.freecharge:
        return 'Freecharge';
      case _ValidUpiApps.googlePay:
        return "Google Pay";
      case _ValidUpiApps.hsbcSimplyPay:
        return 'HSBC Simply Pay';
      case _ValidUpiApps.iMobileICICI:
        return 'iMobile by ICICI';
      case _ValidUpiApps.indusPay:
        return 'IndusPay';
      case _ValidUpiApps.kblUpi:
        return 'KBL UPI';
      case _ValidUpiApps.khaaliJeb:
        return 'KhaaliJeb';
      case _ValidUpiApps.kotak:
        return "Kotak UPI";
      case _ValidUpiApps.mahaUpi:
        return 'MahaUPI';
      case _ValidUpiApps.miPayGlobal:
      case _ValidUpiApps.miPayXiaomi:
        return 'MiPay';
      case _ValidUpiApps.mobikwik:
        return 'Mobikwik';
      case _ValidUpiApps.orientalPay:
        return 'Oriental Pay';
      case _ValidUpiApps.paytm:
        return 'Paytm';
      case _ValidUpiApps.paywiz:
        return 'Paywiz';
      case _ValidUpiApps.payZapp:
        return "PayZapp";
      case _ValidUpiApps.phonePe:
        return 'PhonePe';
      case _ValidUpiApps.pnb:
        return "PNB UPI";
      case _ValidUpiApps.psb:
        return 'PSB';
      case _ValidUpiApps.rblPay:
        return 'RBL Pay';
      case _ValidUpiApps.realmePaySa:
        return "Realme PaySa";
      case _ValidUpiApps.sbiPay:
        return 'SBI Pay';
      case _ValidUpiApps.trueCallerUpi:
        return 'Truecaller';
      case _ValidUpiApps.unitedUpiPay:
        return "United UPI Pay";
      case _ValidUpiApps.vijayaUpi:
        return 'Vijaya UPI';
      case _ValidUpiApps.yesPay:
        return 'Yes Pay';
    }
  }

  String _getPackageName(_ValidUpiApps app) {
    switch (app) {
      case _ValidUpiApps.allBank:
        return 'com.lcode.allahabadupi';
      case _ValidUpiApps.amazonPay:
        return 'in.amazon.mShop.android.shopping';
      case _ValidUpiApps.axisPay:
        return 'com.upi.axispay';
      case _ValidUpiApps.barodaPay:
        return 'com.bankofbaroda.upi';
      case _ValidUpiApps.bhim:
        return 'in.org.npci.upiapp';
      case _ValidUpiApps.boiUpi:
        return 'com.infra.boiupi';
      case _ValidUpiApps.centUpi:
        return 'com.infrasofttech.centralbankupi';
      case _ValidUpiApps.cointab:
        return 'in.cointab.app';
      case _ValidUpiApps.corpUpi:
        return 'com.lcode.corpupi';
      case _ValidUpiApps.csbUpi:
        return 'com.lcode.csbupi';
      case _ValidUpiApps.cubUpi:
        return "com.cub.wallet.gui";
      case _ValidUpiApps.digibank:
        return "com.dbs.in.digitalbank";
      case _ValidUpiApps.dcbUpi:
        return 'com.olive.dcb.upi';
      case _ValidUpiApps.equitasUpi:
        return "com.equitasbank.upi";
      case _ValidUpiApps.finoBPay:
        return 'com.finopaytech.bpayfino';
      case _ValidUpiApps.freecharge:
        return 'com.freecharge.android';
      case _ValidUpiApps.googlePay:
        return "com.google.android.apps.nbu.paisa.user";
      case _ValidUpiApps.hsbcSimplyPay:
        return 'com.mgs.hsbcupi';
      case _ValidUpiApps.iMobileICICI:
        return 'com.csam.icici.bank.imobile';
      case _ValidUpiApps.indusPay:
        return 'com.mgs.induspsp';
      case _ValidUpiApps.kblUpi:
        return 'com.lcode.smartz';
      case _ValidUpiApps.khaaliJeb:
        return 'com.khaalijeb.inkdrops';
      case _ValidUpiApps.kotak:
        return "com.msf.kbank.mobile";
      case _ValidUpiApps.mahaUpi:
        return 'com.infrasofttech.mahaupi';
      case _ValidUpiApps.miPayGlobal:
        return 'com.mipay.in.wallet';
      case _ValidUpiApps.miPayXiaomi:
        return 'com.mipay.wallet.in';
      case _ValidUpiApps.mobikwik:
        return 'com.mobikwik_new';
      case _ValidUpiApps.orientalPay:
        return 'com.mgs.obcbank';
      case _ValidUpiApps.paytm:
        return 'net.one97.paytm';
      case _ValidUpiApps.paywiz:
        return 'com.idbibank.paywiz';
      case _ValidUpiApps.payZapp:
        return "com.enstage.wibmo.hdfc";
      case _ValidUpiApps.phonePe:
        return 'com.phonepe.app';
      case _ValidUpiApps.pnb:
        return "com.fss.pnbpsp";
      case _ValidUpiApps.psb:
        return 'com.mobileware.upipsb';
      case _ValidUpiApps.rblPay:
        return 'com.rblbank.upi';
      case _ValidUpiApps.realmePaySa:
        return "com.realmepay.payments";
      case _ValidUpiApps.sbiPay:
        return 'com.sbi.upi';
      case _ValidUpiApps.trueCallerUpi:
        return 'com.truecaller';
      case _ValidUpiApps.unitedUpiPay:
        return "com.fss.unbipsp";
      case _ValidUpiApps.vijayaUpi:
        return 'com.fss.vijayapsp';
      case _ValidUpiApps.yesPay:
        return 'com.YesBank';
    }
  }
}

