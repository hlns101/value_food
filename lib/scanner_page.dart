import 'dart:convert';

import 'package:barcode_scanner/scanbot_barcode_sdk.dart';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';


//for haptics
import 'package:flutter/services.dart';

// for food database api
//import 'package:openfoodfacts/openfoodfacts.dart';

// for getting the api
//import 'package:http/http.dart' as http;

class ScannerPage extends StatefulWidget {
  final String userId;

  const ScannerPage({super.key, required this.userId});
  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

Future<void> _initScanbotSdk() async {
  var config = SdkConfiguration(licenseKey: "", loggingEnabled: true);

  await ScanbotBarcodeSdk.initialize(config);

  // user agent for open food facts
  //   OpenFoodAPIConfiguration.userAgent = UserAgent(
  //   name: 'ValueFood',
  // );

  // OpenFoodAPIConfiguration.globalLanguages = <OpenFoodFactsLanguage>[
  //   OpenFoodFactsLanguage.ENGLISH,
  // ];
}

dynamic parseJSON(String jsonString) {
  // parse a JSON string and return the parsed json
  dynamic parsedJson = json.decode(jsonString);
  return parsedJson;
}

String getProductFromJSON(dynamic jsonData) {
  // return a placeholder string
  return jsonData["product_name"];
}

class _ScannerPageState extends State<ScannerPage> {
  @override
  void initState() {
    super.initState();
    _initScanbotSdk();
  }

  // test for api
  //  Future<Product> fetchProduct() async {
  //   final response = await http.get(Uri.parse('https://world.openfoodfacts.net/api/v2/product/{barcode}?fields=product_name'));

  //   if (response.statusCode == 200){
  //     return Product.fromJson(jsonDecode(response.body));
  //   } else {
  //     throw Exception("Failed to get product..");
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode Scanner')),
      body: Center(
        child: ElevatedButton(
          onPressed: _startBarcodeScanning, 
          // onPressed: () {
          //tested if it fetches a product, it returns null
          //   fetchProduct().then((value) {
          //     print(value.product_name);
          //   });
          // },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 40),
            textStyle: const TextStyle(fontSize: 18),
          ),
          child: const Text("Start single-barcode scanning"),
        ),
      ),
    );
  }

  void _startBarcodeScanning() async {
    var configuration = rtuUiSingleScanningUseCase();

    // Start the scanner
    // var result = await ScanbotBarcodeSdk.barcode.startScanner(
    // BarcodeScannerScreenConfiguration(),
    var result = await ScanbotBarcodeSdk.barcode.startScanner(configuration);

    if (result is Ok<BarcodeScannerUiResult>) {}
  }

  // to add overlay
  BarcodeScannerScreenConfiguration rtuUiSingleScanningUseCase() {
    String jsonString = "{\"product_name\":\"Skyflakes Cracker\",\"barcode\":\"750515018402\",\"description\":\"_wheat_ Flour, Coconut Oil, Vegetable Shortening (coconut Oil, Palm Oil And Vitamin E (antioxidant)), Iodized Salt, Sugar, Sodium Bicarbonate (raising Agent), Yeast\",\"nutri_facts\":\" Energy 492 kcal (2060 kJ), Fat 20 g, Saturated Fat 16 g, Carbohydrates 68 g, Sugars 8 g, Fiber 4 g, Protein 12 g, Salt 1.12 g, Vitamin A 0.0000593 g, Calcium 0.0228 g, Iron 0.0052 g.\",\"image_link\":\"https://images.barcodelookup.com/4811/48113697-1.jpg\"}";

     dynamic decoded = parseJSON(jsonString);
     String productName = getProductFromJSON(decoded);



    // Create the default configuration object.
    var configuration = BarcodeScannerScreenConfiguration();

    // Initialize the use case for single scanning.
    var scanningMode = SingleScanningMode();
    // Enable and configure the confirmation sheet.
    scanningMode.confirmationSheetEnabled = true;
    scanningMode.sheetColor = ScanbotColor("#FFFFFF");

    // Hide/unhide the barcode image.
    scanningMode.barcodeImageVisible = true;

 //test
    scanningMode.barcodeTitle.text = productName;
  
    // Configure the barcode title of the confirmation sheet.
    scanningMode.barcodeTitle.visible = true;
   
    scanningMode.barcodeTitle.color = ScanbotColor("#000000");

    // Configure the barcode subtitle of the confirmation sheet.
    scanningMode.barcodeSubtitle.visible = true;
    scanningMode.barcodeSubtitle.color = ScanbotColor("#000000");

    // Configure the cancel button of the confirmation sheet.
    scanningMode.cancelButton.text = "Close";
    scanningMode.cancelButton.foreground.color = ScanbotColor("#C8193C");
    scanningMode.cancelButton.background.fillColor = ScanbotColor("#00000000");

    // Configure the submit button of the confirmation sheet.
    scanningMode.submitButton.text = "Submit";
    scanningMode.submitButton.foreground.color = ScanbotColor("#FFFFFF");
    scanningMode.submitButton.background.fillColor = ScanbotColor("#C8193C");

    // Configure other parameters, pertaining to single-scanning mode as needed.

    configuration.useCase = scanningMode;

    return configuration;
  }
}

// test for api
// class Product {
//   final String product_name;
//   final String code;

//   const Product({required this.product_name, required this.code, });

//   factory Product.fromJson(Map<String, dynamic> json){
//     return Product(
//       product_name: json['product_name'],
//       code: json['code']
//     );
//   }
// }
