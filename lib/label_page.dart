import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'food_products.dart';
import 'recommendation_service.dart';
import 'gemini_service.dart';

// for python
// import 'package:flutter_python_bridge/flutter_python_bridge.dart';
class _OCRLine {
  final String text;
  final double top;
  final double left;
  final double right;

  _OCRLine({
    required this.text,
    required this.top,
    required this.left,
    required this.right,
  });
}

class RecognizeResult {
  final String imagePath;
  final String text;
  RecognizeResult(this.imagePath, this.text);
}

class LabelPage extends StatefulWidget {
  final String userId;

  const LabelPage({super.key, required this.userId});

  @override
  State<LabelPage> createState() => _LabelPageState();
}

class _LabelPageState extends State<LabelPage> {
  //File? _imageFile;
  final ImagePicker _picker = ImagePicker();
  final TextRecognizer _textRecognizer = TextRecognizer();
  String _recognizedText = '';
  XFile? _imageFile;
  bool _isProcessing = false;
  File? selectedImage;
  var testResult = '';

  // Recommendation service, alternatives list, and user data
  final RecommendationService _rec = RecommendationService();
  List<FoodProduct> _alternatives = [];
  Map<String, dynamic> _userData = {};
  final GeminiService _gemini = GeminiService();
  String _aiExplanation = '';
  bool _usedGemini = false;

  double _num(dynamic s) {
    if (s == null) return 0.0;
    final t = s.toString().replaceAll('O', '0');
    final m = RegExp(r'\d+(\.\d+)?').firstMatch(t);
    return m == null ? 0.0 : double.parse(m.group(0)!);
  }

  // Unlike _num (used by the display), this preserves missing OCR values.
  // A missing nutrient must never silently become a real zero for KNN.
  double? _nullableNum(dynamic value) {
    if (value == null) return null;
    final text = value.toString().replaceAll('O', '0').trim();
    if (text.isEmpty) return null;
    final match = RegExp(r'\d+(?:\.\d+)?').firstMatch(text);
    return match == null ? null : double.tryParse(match.group(0)!);
  }

  ({double amount, bool per100ml})? _readServingBasis(String text) {
    final lines = text.replaceAll('\r', '\n').split('\n');
    for (final line in lines) {
      if (!RegExp(r'serving\s*size', caseSensitive: false).hasMatch(line)) {
        continue;
      }

      // Prefer an explicit mass/volume quantity, including values in
      // parentheses such as "1 cup (240 mL)".
      final match = RegExp(
        r'(\d+(?:\.\d+)?)\s*(g|grams?|ml|millilit(?:er|re)s?)\b',
        caseSensitive: false,
      ).firstMatch(line);
      if (match == null) continue;

      final amount = double.tryParse(match.group(1)!);
      if (amount == null || amount <= 0) continue;
      final unit = match.group(2)!.toLowerCase();
      final per100ml = unit == 'ml' || unit.startsWith('milliliter') || unit.startsWith('millilitre');
      return (amount: amount, per100ml: per100ml);
    }
    return null;
  }

  String _extractNutrientValue(
    String text,
    List<String> nutrientNames,
  ) {
    final lines = text
        .replaceAll('\r', '\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final nutrient in nutrientNames) {
        final escaped = RegExp.escape(nutrient);

        // Find the nutrient name at the beginning of a line.
        final match = RegExp(
          '^\\s*$escaped\\b\\s*[:\\-]?\\s*(.*)\$',
          caseSensitive: false,
        ).firstMatch(line);

        if (match == null) continue;

        // First, look for a number on the same line.
        final sameLine = match.group(1) ?? '';
        final number = RegExp(r'\d+(?:\.\d+)?|[O](?:\.\d+)?')
            .firstMatch(sameLine);

        if (number != null) {
          return number.group(0)!.replaceAll('O', '0');
        }

        // If the value is on the next line, check that line too.
        if (i + 1 < lines.length) {
          final nextLine = lines[i + 1];
          final nextNumber = RegExp(
            r'\d+(?:\.\d+)?|[O](?:\.\d+)?',
          ).firstMatch(nextLine);

          if (nextNumber != null) {
            return nextNumber.group(0)!.replaceAll('O', '0');
          }
        }
      }
    }

    return '';
  }

  //serving Info is the header, the first 4 lines of a nutritional label starting from Nutrition
  var _servingInfo;
  var servingRegex = RegExp(r'\Nutrition(.*\n){4}', caseSensitive: false);

  // calories + the amount , maybe add separate regex for calories num
  var _caloriesInfo;
  var caloriesRegex = RegExp(
    r'\Calories \d+|Calories \Wkcal\W \d+',
    caseSensitive: false,
  );

  var _energy;
  var energyRegex = RegExp(
    r'(?<=Energy)(.*\d)|(?<=Energy)(.*O)',
    caseSensitive: false,
  );

  // for the fat number, no g at the end for now, can just change the d to n if need the g too. Also sometimes 0 is read as the letter O. for future purposes we can
  //probably use if statement for if this regex gets the letter O, that means its 0.
  var _fatNum;
  var fatNumRegex = RegExp(
    r'(?<=Total Fat)(.*\d)|(?<=Total Fat)(.*O)',
    caseSensitive: false,
  );

  // saturated fat
  var _satFatNum;
  var satFatNumRegex = RegExp(
    r'(?<=Saturated Fat)(.*\d)|(?<=Saturated Fat)(.*O)',
    caseSensitive: false,
  );

  // trans fat
  var _transFatNum;
  var transFatNumRegex = RegExp(
    r'(?<=Trans Fat)(.*\d)|(?<=Trans Fat)(.*O)',
    caseSensitive: false,
  );

  // cholesterol num
  var _cholesterolNum;
  var cholesterolNumRegex = RegExp(
    r'(?<=Cholesterol)(.*\d)|(?<=Cholesterol)(.*O)',
    caseSensitive: false,
  );

  //sodium num
  var _sodiumNum;
  var sodiumNumRegex = RegExp(
    r'(?<=Sodium)(.*\d)|(?<=Sodium)(.*O)',
    caseSensitive: false,
  );

  // potassium
  var _potassiumNum;
  var potassiumNumRegex = RegExp(
    r'(?<=Potassium)(.*\d)|(?<=Potassium)(.*O)',
    caseSensitive: false,
  );

  // total carbohydrate value
  var _totalCarbNum;
  var totalCarbNumRegex = RegExp(
    r'(?<=Total Carbohydrate)(.*\d)|(?<=Total Carbohydrate)(.*O)',
    caseSensitive: false,
  );

  //dietary fiber num
  var _dietaryfiberNum = 'r';
  var dietaryFiberNumRegex = RegExp(
    r'(?<=Dietary Fiber)(.*\d)|(?<=Dietary Fiber)(.*O)|(?<=Dletary Fiber)(.*\d)',
    caseSensitive: false,
  );

  // sugars/ total sugars
  var _sugars;
  var sugarsRegex = RegExp(r'\Sugars|Total Sugars', caseSensitive: false);

  var _sugarsNum;
  var sugarsNumRegex = RegExp(
    r'(?<=Sugars)(.*\d)|(?<=Sugars)(.*O)|(?<=Total Sugars)(.*\d)|(?<=Total Sugars)(.*O)',
    caseSensitive: false,
  );

  // protein / total protein
  var _protein;
  var proteinRegex = RegExp(r'\Protein|Total Protein', caseSensitive: false);

  var _proteinNum;
  var proteinNumRegex = RegExp(
    r'(?<=Protein)(.*\d)|(?<=Protein)(.*O)|(?<=Total Protein)(.*\d)|(?<=Total Protein)(.*O)',
    caseSensitive: false,
  );

  // Philippines uses RENI on nutritional labels but some use Daily Value % too and some also have both RENI and DV%
  // regex to find text that starts with digit(s) or '<' and has percentage next to it
  //var reniRegex = RegExp(r'\.*^\d+%|\.*^<\d+%', caseSensitive: false);

  //for now using this regex for testing since other one wasnt working
  var reniRegex = RegExp(r'\d+%', caseSensitive: false);

  // putting all matches of reniRegex in a list
  var reniList;

  // for the reni percentage of nutrients
  var _caloriesReni;
  var _dietaryFiberReni;
  var _proteinReni;

  var _fatReni;
  var _satFatReni;
  var _cholesterolReni;
  var _sodiumReni;
  var _totalCarbReni;

  // for when calories number is on the very right
  var caloriesRegex2 = RegExp(r'(?<=[^\w ])\d+(?=\n)', caseSensitive: false);

  var highProtein = ' ';
  var highFiber = ' ';
  var highSatFat = ' ';
  var score = 0;
  var recommendation = ' ';

  @override
  void initState() {
    super.initState();
    loadLabelData();
    _rec.loadCatalog();
    // runPythonExample();
  }

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isProcessing = true;
        _recognizedText = '';
      });

      final XFile? pickedFile = await _picker
          .pickImage(source: source, maxWidth: 2048, imageQuality: 85)
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('[picker] pickImage timed out after 20s');
              return null;
            },
          );
      debugPrint('[picker] pickImage returned: ${pickedFile?.path}');

      if (pickedFile == null) return;

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      final List<_OCRLine> ocrLines = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          ocrLines.add(
            _OCRLine(
              text: line.text,
              top: line.boundingBox.top,
              left: line.boundingBox.left,
              right: line.boundingBox.right,
            ),
          );
        }
      }

      if (!_rec.isLoaded) await _rec.loadCatalog();

      setState(() {
        _imageFile = pickedFile;
        _recognizedText = recognizedText.text;
        debugPrint('========== RAW OCR TEXT ==========');
        debugPrint(_recognizedText);
        debugPrint('==================================');
        print(recognizedText.text);

        var servingMatch = servingRegex.firstMatch(_recognizedText);
        var caloriesMatch = caloriesRegex.firstMatch(_recognizedText);
        var caloriesMatch2 = caloriesRegex2.firstMatch(_recognizedText);
        var energyMatch = energyRegex.firstMatch(_recognizedText);

        // Extract nutrient values using line-based matching.
        _fatNum = _extractNutrientValue(
          _recognizedText,
          ['Total Fat'],
        );

        _satFatNum = _extractNutrientValue(
          _recognizedText,
          ['Saturated Fat'],
        );

        _transFatNum = _extractNutrientValue(
          _recognizedText,
          ['Trans Fat'],
        );

        _cholesterolNum = _extractNutrientValue(
          _recognizedText,
          ['Cholesterol'],
        );

        _sodiumNum = _extractNutrientValue(
          _recognizedText,
          ['Sodium'],
        );

        _potassiumNum = _extractNutrientValue(
          _recognizedText,
          ['Potassium'],
        );

        _totalCarbNum = _extractNutrientValue(
          _recognizedText,
          ['Total Carbohydrate', 'Total Carbs'],
        );

        _dietaryfiberNum = _extractNutrientValue(
          _recognizedText,
          ['Dietary Fiber', 'Dietary Fibre'],
        );

        _sugarsNum = _extractNutrientValue(
          _recognizedText,
          ['Total Sugars', 'Sugars'],
        );

        _proteinNum = _extractNutrientValue(
          _recognizedText,
          ['Total Protein', 'Protein'],
        );

        // Preserve the nutrient labels used by your existing table.
        _sugars = 'Sugars';
        _protein = 'Protein';

        // reni stuff
        reniList =
            reniRegex
                .allMatches(_recognizedText)
                .map((z) => z.group(0))
                .toList();
        print(reniList);

        var lowercaseLabel = _recognizedText.toLowerCase();

        // check if label uses RENI or DV
        if (lowercaseLabel.contains('daily value') ||
            _recognizedText.contains('dv')) {
          print('Daily Value Label');
          // daily value labels usually have value for all except trans fat, sugars , and protein
          // labels also usually have 9-10 percentages, besides total fat, sat fat, cholesterol, sodium, total card, dietary fiber theres vitamin A, potassium
          if (reniList.length >= 6) {
            _fatReni = reniList[0];
            _satFatReni = reniList[1];
            _cholesterolReni = reniList[2];
            _sodiumReni = reniList[3];
            _totalCarbReni = reniList[4];
            _dietaryFiberReni = reniList[5];
            //reni only values
            _caloriesReni = '';
            _proteinReni = '';
            //
          } else {
            _fatReni = '';
            _satFatReni = '';
            _cholesterolReni = '';
            _sodiumReni = '';
            _totalCarbReni = '';
            _dietaryFiberReni = '';
            //reni only values
            _caloriesReni = '';
            _proteinReni = '';
            //
          }
          // if its RENI label
          // for now we can assume if the nutrition label has 2 percentages for the RENI, it will be for these nutrient values.
          //however some labels with 2 percentages has one for energy instead of calories
          // for juices its usually reni % for Calories, Dietary Fiber, Protein and others like Vitamin A
        } else {
          if (reniList.length == 2) {
            _caloriesReni = reniList[0];
            _proteinReni = reniList[1];
            _dietaryFiberReni = '';

            _fatReni = ' ';
            _satFatReni = '';
            _cholesterolReni = '';
            _sodiumReni = '';
            _totalCarbReni = '';
          } else if (reniList.length == 3) {
            _caloriesReni = reniList[0];
            _dietaryFiberReni = reniList[1];
            _proteinReni = reniList[2];

            _fatReni = ' ';
            _satFatReni = '';
            _cholesterolReni = '';
            _sodiumReni = '';
            _totalCarbReni = '';
          } else if (reniList.length == 6) {
            _caloriesReni = reniList[0];
            _dietaryFiberReni = reniList[1];
            _proteinReni = reniList[2];

            _fatReni = ' ';
            _satFatReni = '';
            _cholesterolReni = '';
            _sodiumReni = '';
            _totalCarbReni = '';
          } else {
            _caloriesReni = 'work in progress';
            _dietaryFiberReni = '';
            _proteinReni = '';

            _fatReni = ' ';
            _satFatReni = '';
            _cholesterolReni = '';
            _sodiumReni = '';
            _totalCarbReni = '';
            _dietaryFiberReni = '';
          }
        }

        _servingInfo =
            servingMatch?.group(0) ?? 'Not recognized as Nutritional Label';

        _caloriesInfo = caloriesMatch?.group(0) ??
            (caloriesMatch2 != null
                ? 'Calories ${caloriesMatch2.group(0)}'
                : 'Calories not recognized');

        _fatNum = _fatNum ?? '';
        _satFatNum = _satFatNum ?? '';
        _transFatNum = _transFatNum ?? '';
        _cholesterolNum = _cholesterolNum ?? '';
        _sodiumNum = _sodiumNum ?? '';
        _potassiumNum = _potassiumNum ?? '';
        _totalCarbNum = _totalCarbNum ?? '';
        _dietaryfiberNum = _dietaryfiberNum ?? '';
        _sugarsNum = _sugarsNum ?? '';
        _proteinNum = _proteinNum ?? '';

        _energy = energyMatch?.group(0) ?? '';

        _sugars = 'Sugars';
        _protein = 'Protein';

        // for recommendation part. placeholder for now
        // check if positive nutrients DV/Reni% are high:
        // 20% is considered high, 5% is considered low
        // positives: high fiber, high protein
        // negatives: high energy, high sugars, high saturated fats
        // remove percentage

        var finalSatFat = '0';

        if (_satFatReni.contains('%')) {
          finalSatFat = _satFatReni.replaceAll('%', '');
        }

        var finalProtein = '0';

        if (_proteinReni.contains('%')) {
          finalProtein = _proteinReni.replaceAll('%', '');
        }

        var finalFiber = '0';

        if (_dietaryFiberReni.contains('%')) {
          finalFiber = _dietaryFiberReni.replaceAll('%', '');
        }

        if ((int.tryParse(finalProtein.trim()) ?? 0) >= 20) {
          highProtein = 'This product is high in protein.';
          score += 3;
        } else if ((int.tryParse(finalProtein.trim()) ?? 0) >= 6) {
          score += 1;
          highProtein = '';
        } else {
          score -= 1;
          highProtein = '';
        }

        if ((int.tryParse(finalFiber.trim()) ?? 0) >= 20) {
          highFiber = 'This product is high in fiber.';
          score += 3;
        } else if ((int.tryParse(finalFiber.trim()) ?? 0) >= 6) {
          score += 1;
          highFiber = '';
        } else {
          score -= 1;
          highFiber = '';
        }

        if (finalSatFat != null) {
          if ((int.tryParse(finalSatFat.trim()) ?? 0) >= 20) {
            highSatFat = 'This product is high in saturated fat.';
            score -= 3;
          } else if ((int.tryParse(finalSatFat.trim()) ?? 0) >= 6) {
            score -= 1;
            highSatFat = '';
          } else {
            score += 1;
            highSatFat = '';
          }
        }
        // add one for energy
        print('score');
        print(score);

        if (score >= 6) {
          recommendation = 'Highly Recommended';
          score = 0;
        } else if (score >= 3) {
          recommendation = 'Recommended';
          score = 0;
        } else if (score >= 1) {
          recommendation = 'Slightly Recommended';
          score = 0;
        } else {
          recommendation = 'Not Recommended';
          score = 0;
        }

      });

      // KNN + budget pass runs OUTSIDE setState because it awaits Gemini.
      await _runRecommendation(pickedFile);
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to pick image: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Gemini reads the label (nutrients + ingredients + category); if it fails
  /// we fall back to the ML Kit + RegEx values. Then KNN + budget pass.
  
    Future<void> _loadExplanation(FoodProduct scanned, List<FoodProduct> alts) async {
    try {
      final why = await _gemini.explainAlternatives(
        scanned: scanned,
        alternatives: alts,
        user: _userData,
      );
      if (mounted && why != null) setState(() => _aiExplanation = why);
    } catch (e) {
      debugPrint('[label] explanation skipped: $e');
    }
  }
  
  Future<void> _runRecommendation(XFile file) async {
    await loadLabelData(); // fresh budget / spent / profile

    debugPrint('========== BUDGET CHECK ==========');
    debugPrint('Budget: ${_userData['budget']}');
    debugPrint('Spent: ${_userData['spent']}');
    debugPrint('User data: $_userData');
    debugPrint('==================================');
    final budget = double.tryParse(
      (_userData['budget'] ?? 0).toString(),
    ) ?? 0.0;

    final spent = double.tryParse(
      (_userData['spent'] ?? 0).toString(),
    ) ?? 0.0;

    final remaining = (budget - spent)
        .clamp(0.0, double.infinity)
        .toDouble();

    LabelData? label;
    try {
      final bytes = await file.readAsBytes();
      final mime =
          file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      label = await _gemini.extractLabel(
        bytes,
        mime: mime,
        categories: _rec.categories,
      );
    } catch (e) {
      debugPrint('[label] Gemini read failed: $e');
    }

    // Use Gemini's extracted product information when available.
    // OCR is a strict fallback: all four core nutrients and an explicit
    // serving mass/volume must be present before it can enter KNN.
    FoodProduct? ocrProduct;
    if (label == null) {
      final calories = _nullableNum(_caloriesInfo);
      final sodium = _nullableNum(_sodiumNum);
      final sugars = _nullableNum(_sugarsNum);
      final satFat = _nullableNum(_satFatNum);
      final serving = _readServingBasis(_recognizedText);

      // Same conversion + eligibility rules as the Gemini path: all four
      // nutrients, a positive g/ml serving size, and plausible per-100 values.
      final ocrLabel = LabelData(
        name: 'Scanned Item',
        category: '',
        productGroup: 'other',
        calories: calories,
        sodium: sodium,
        sugars: sugars,
        satFat: satFat,
        servingSize: serving?.amount,
        servingUnit: serving == null ? null : (serving.per100ml ? 'ml' : 'g'),
        ingredients: const [],
        nutritionSource: 'label_ocr',
      );

      if (ocrLabel.isEligibleForKnn) {
        ocrProduct = ocrLabel.toProduct();
      } else {
        debugPrint(
          '[label] OCR fallback rejected: missing=${ocrLabel.missingFields} '
          'calories=$calories sodium=$sodium sugars=$sugars '
          'satFat=$satFat serving=$serving',
        );
      }
    }

    final FoodProduct? scannedProduct = label?.toProduct() ?? ocrProduct;
    if (scannedProduct == null) {
      if (!mounted) return;
      setState(() {
        _usedGemini = false;
        _alternatives = [];
        _aiExplanation = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read all four nutrients and the serving size. '
            'Please try a clearer nutrition-label photo.',
          ),
        ),
      );
      return;
    }

    debugPrint('========== SCANNED PRODUCT DEBUG ==========');
    debugPrint('Gemini successful: ${label != null}');
    debugPrint('Name: ${scannedProduct.name}');
    debugPrint('Category: ${scannedProduct.category}');
    debugPrint('Product Group: ${scannedProduct.productGroup}');
    debugPrint('Nutrition Basis: ${scannedProduct.nutritionBasis}');
    debugPrint('Nutrition Eligible: ${scannedProduct.nutritionEligible}');
    debugPrint('Calories: ${scannedProduct.calories}');
    debugPrint('Sodium: ${scannedProduct.sodium}');
    debugPrint('Sugars: ${scannedProduct.sugars}');
    debugPrint('Saturated Fat: ${scannedProduct.satFat}');
    debugPrint('Remaining Budget: $remaining');
    debugPrint('============================================');

    final alts = _rec.recommend(
      scanned: scannedProduct,
      user: _userData,
      remainingBudget: remaining,
    );

    debugPrint('========== RECOMMENDATION RESULT ==========');
    debugPrint('Alternatives found: ${alts.length}');
    for (final product in alts) {
      debugPrint('${product.name} - ${product.price}');
    }
    debugPrint('============================================');

    if (!mounted) return;

    setState(() {
      _usedGemini = label != null;
      _alternatives = alts;
      _aiExplanation = '';
    });

    // Generate explanations in the background.
    _loadExplanation(scannedProduct, alts); // not awaited: shows up when ready
  }

  Future<void> loadLabelData() async {
    final userDoc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .get();

    if (mounted) {
      setState(() {
        _userData = userDoc.data() ?? <String, dynamic>{};
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Nutrtion Facts Label')),
      body: Container(
        decoration: BoxDecoration(color: Color.fromRGBO(122, 184, 77, 100)),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            /// scanner options
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12.0,
              runSpacing: 12.0,
              children: [
                /// upload image
                ButtonTheme(
                  minWidth: 30,
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.gallery),
                    icon: const Icon(
                      Icons.file_upload_outlined,
                      color: Colors.green,
                      size: 30,
                    ),
                    label: const Text(
                      'Upload Image',
                      style: TextStyle(fontSize: 24, color: Colors.black),
                    ),
                  ),
                ),

                /// take photo
                ButtonTheme(
                  minWidth: 30,
                  height: 80,
                  child: ElevatedButton.icon(
                    onPressed: () => _pickImage(ImageSource.camera),
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.green,
                      size: 30,
                    ),
                    label: const Text(
                      'Use Camera',
                      style: TextStyle(fontSize: 24, color: Colors.black),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child:
                  _isProcessing
                      ? const Center(
                        child: CircularProgressIndicator.adaptive(),
                      )
                      : _imageFile == null
                      ? const Center(
                        child: Text(
                          'No image selected',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Image.file(File(_imageFile!.path)),
                            const SizedBox(height: 12),

                            Container(
                              padding: const EdgeInsets.all(12),
                              color: Colors.white,
                              child: Text(
                                _recognizedText.isEmpty
                                    ? 'No text recognized.'
                                    // to see the full text
                                    //: _recognizedText,
                                    // text with regex, serving and calories info on top of table
                                    : _servingInfo +
                                        ('\n') +
                                        (_caloriesInfo ?? ' ') +
                                        ('\n'),

                                style: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                            ),
                            // container to hold if product is recommended
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Text(
                                recommendation,
                                style: TextStyle(
                                  color:
                                      (recommendation == 'Not Recommended')
                                          ? Colors.redAccent
                                          : (recommendation ==
                                              'Slighty Recommended')
                                          ? Colors.yellow
                                          : Colors.greenAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                            Container(
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Text(
                                highProtein +
                                    highSatFat +
                                    highFiber +
                                    testResult,
                              ),
                            ),
                            // where table begins
                            SingleChildScrollView(
                              child: Table(
                                border: TableBorder.all(
                                  color: const Color.fromARGB(
                                    255,
                                    143,
                                    210,
                                    67,
                                  ),
                                ),
                                defaultVerticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(
                                      color: Color.fromRGBO(232, 245, 233, 100),
                                    ),
                                    children: [
                                      TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),

                                          child: Text(
                                            'Nutrient',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      TableCell(
                                        verticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        child: Padding(
                                          padding: EdgeInsets.all(8.0),
                                          child: Text(
                                            '% RENI / % DV',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // the rows below the Nutrient and RENI
                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              // if theres no calories theres energy
                                              text:
                                                  _caloriesInfo ??
                                                  ('Energy') + _energy,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _caloriesReni,
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: ('Total Fat'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            // sometimes the ocr reads 0 as O
                                            TextSpan(
                                              text: _fatNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _fatReni ?? ' ',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      Text(
                                        ('Saturated Fat') +
                                            (_satFatNum.replaceAll('O', '0')),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                      Text(
                                        _satFatReni ?? ' ',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      Text(
                                        ('Trans Fat') +
                                            (_transFatNum.replaceAll('O', '0')),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                      Text(
                                        ' ',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(),
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: ('Cholesterol'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _cholesterolNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _cholesterolReni ?? ' ',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: ('Sodium'),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _sodiumNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _sodiumReni ?? ' ',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: 'Potassium',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _potassiumNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(' ', textAlign: TextAlign.center),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: 'Total Carbs',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _totalCarbNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _totalCarbReni ?? ' ',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      Text(
                                        ('Dietary Fiber ') +
                                            _dietaryfiberNum.replaceAll(
                                              'O',
                                              '0',
                                            ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Text(
                                        _dietaryFiberReni ?? ' ',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(text: _sugars),
                                            TextSpan(
                                              text: _sugarsNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(' ', textAlign: TextAlign.center),
                                    ],
                                  ),

                                  TableRow(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                    ),
                                    children: [
                                      RichText(
                                        textAlign: TextAlign.center,
                                        text: TextSpan(
                                          style: const TextStyle(
                                            color: Colors.black,
                                            fontSize: 16,
                                          ),
                                          children: <TextSpan>[
                                            TextSpan(
                                              text: _protein,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            TextSpan(
                                              text: _proteinNum.replaceAll(
                                                'O',
                                                '0',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        _proteinReni ?? '',
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // alternative products
                            Container(
                              padding: const EdgeInsets.all(8.0),
                              color: Colors.white,
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  const Text(
                                    'Alternative Products',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 20,
                                    ),
                                  ),
                                  Text(
                                    _alternatives.isEmpty
                                        ? 'No affordable healthier alternative found'
                                        : _alternatives
                                            .map(
                                              (p) =>
                                                  '${p.name} - ${p.price > 0 ? '₱${p.price.toStringAsFixed(0)}' : 'price not set'}',
                                            )
                                            .join('\n'),
                                    textAlign: TextAlign.center,
                                  ),
                                  if (_aiExplanation.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Text(
                                      _aiExplanation,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                  const SizedBox(height: 6),
                                  Text(
                                    _usedGemini
                                        ? 'Read by Gemini'
                                        : 'Read by on-device OCR',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            ButtonTheme(
                              minWidth: 30,
                              height: 80,
                              child: ElevatedButton.icon(
                                onPressed: () => {},
                                icon: const Icon(
                                  Icons.file_upload_outlined,
                                  color: Colors.green,
                                  size: 30,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                ),
                                label: const Text(
                                  'Upload Ingredients',
                                  style: TextStyle(
                                    fontSize: 24,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}