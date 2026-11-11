import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:ui';
import 'dashboard_page.dart';
import 'budget_page.dart';
import 'goals_page.dart';
import 'profile_page.dart';
import 'food_products.dart';
import 'recommendation_service.dart';
import 'gemini_service.dart';
import 'utils/nutrition_label_guard.dart';

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
  bool _scanRejected = false;
  File? selectedImage;
  var testResult = '';

  // Recommendation service, alternatives list, and user data
  final RecommendationService _rec = RecommendationService();
  List<FoodProduct> _alternatives = [];
  Map<String, dynamic> _userData = {};
  final GeminiService _gemini = GeminiService();
  String _aiExplanation = '';
  bool _usedGemini = false;
  FoodProduct? _lastScannedProduct;
  double _lastRemainingBudget = 0;
  List<String> _ingredientItems = [];
  List<String> _ingredientAdvisories = [];
  String _ingredientRawText = '';
  bool _ingredientPanelDetected = false;
  bool _isScanningIngredients = false;
  int _resultTab = 0; // 0 = Nutrition Facts, 1 = Ingredients

  List<String> get _userAllergies {
    final raw = _userData['allergies'];
    if (raw is List) {
      return raw.map((a) => a.toString().trim())
          .where((a) => a.isNotEmpty).toList();
    }
    return <String>[];
  }

  List<String> get _matchedAllergies => _rec.matchedAllergies(
    userAllergies: _userAllergies,
    ingredientText: _ingredientItems,
    advisoryStatements: _ingredientAdvisories,
  );

  /// OCR fallback requires an actual ingredient heading. It never interprets
  /// arbitrary nutrition text as an ingredient list.
  List<String> _ingredientsFromOcr(String text) {
    final match = RegExp(
      r'\bingredients?\s*[:：]\s*([\s\S]*?)(?=\n\s*(?:nutrition facts|nutritional information|storage|manufactured|distributed|best before|expiry)\b|$)',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return [];
    final body = (match.group(1) ?? '').replaceAll('\n', ' ').trim();
    if (body.isEmpty) return [];
    return body.split(RegExp(r'[,;]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
  }

  List<String> _advisoriesFromOcr(String text) => text.split('\n')
      .where((line) => RegExp(
        r'\b(contains|may contain|processed in a facility|manufactured in a facility)\b',
        caseSensitive: false,
      ).hasMatch(line))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  /// A second image can show the side/back of the package even when the
  /// nutrition facts and ingredients are printed on different surfaces.
  Future<void> _scanIngredientPanel(ImageSource source) async {
    if (_isScanningIngredients || _isProcessing) return;
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 2048,
      imageQuality: 90,
    );
    if (picked == null || !mounted) return;

    setState(() => _isScanningIngredients = true);
    try {
      final recognized = await _textRecognizer.processImage(
        InputImage.fromFilePath(picked.path),
      );
      final ocr = recognized.text;
      final bytes = await picked.readAsBytes();
      final mime = picked.path.toLowerCase().endsWith('.png')
          ? 'image/png'
          : 'image/jpeg';
      final ai = await _gemini.extractIngredients(bytes, mime: mime)
          .timeout(const Duration(seconds: 35), onTimeout: () => null);
      final ocrIngredients = _ingredientsFromOcr(ocr);
      final ocrAdvisories = _advisoriesFromOcr(ocr);
      final ingredients = ai != null && ai.panelDetected &&
              ai.ingredients.isNotEmpty
          ? ai.ingredients
          : ocrIngredients;
      final advisories = <String>{
        ...ocrAdvisories,
        if (ai?.panelDetected == true) ...ai!.advisoryStatements,
      }.toList();
      final identified = ingredients.isNotEmpty || advisories.isNotEmpty;
      if (!mounted) return;
      setState(() {
        _ingredientItems = ingredients;
        _ingredientAdvisories = advisories;
        _ingredientRawText = ocr;
        _ingredientPanelDetected = identified;
      });

      if (!identified) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Ingredient list not readable. Try a closer, clearer photo.'),
        ));
      }
      _refreshAlternativesForIngredients();
    } catch (error) {
      debugPrint('[label] Ingredient scan failed: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not scan ingredients. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _isScanningIngredients = false);
    }
  }

  void _refreshAlternativesForIngredients() {
    final scanned = _lastScannedProduct;
    if (scanned == null) return;
    final alternatives = _rec.recommend(
      scanned: scanned,
      user: _userData,
      remainingBudget: _lastRemainingBudget,
      scannedIngredients: _ingredientItems,
    );
    if (!mounted) return;
    setState(() {
      _alternatives = alternatives;
      _aiExplanation = '';
    });
    _loadExplanation(scanned, alternatives);
  }


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
    final normalizedText = text
        .replaceAll('\r', '\n')
        .replaceAll('O', '0');

    final lines = normalizedText
        .split('\n')
        .map((line) => line.trim())
        .toList();

    // STEP 1: Look for serving sizes in parentheses anywhere.
    // Example: 2 biscuits (36g)
    // This handles incorrect OCR reading order.

    final parenthesisMatch = RegExp(
      r'\(\s*(\d+(?:\.\d+)?)\s*'
      r'(g|grams?|ml|millilit(?:er|re)s?)\s*\)',
      caseSensitive: false,
    ).firstMatch(normalizedText);

    if (parenthesisMatch != null) {
      final amount = double.tryParse(parenthesisMatch.group(1)!);

      if (amount != null && amount > 0) {
        final unit = parenthesisMatch.group(2)!.toLowerCase();

        final per100ml = unit == 'ml' ||
            unit.startsWith('milliliter') ||
            unit.startsWith('millilitre');

        debugPrint(
          '[OCR] Serving size found in parentheses: '
          '$amount ${per100ml ? 'ml' : 'g'}',
        );

        return (
          amount: amount,
          per100ml: per100ml,
        );
      }
    }

    // STEP 2: Original fallback.
    // Look around the Serving Size heading.

    for (var i = 0; i < lines.length; i++) {
      if (!RegExp(
        r'serving\s*size',
        caseSensitive: false,
      ).hasMatch(lines[i])) {
        continue;
      }

      final servingText = lines
          .skip(i)
          .take(5)
          .join(' ')
          .replaceAll(RegExp(r'\s+'), ' ');

      final match = RegExp(
        r'(\d+(?:\.\d+)?)\s*'
        r'(g|grams?|ml|millilit(?:er|re)s?)\b',
        caseSensitive: false,
      ).firstMatch(servingText);

      if (match == null) continue;

      final amount = double.tryParse(match.group(1)!);

      if (amount == null || amount <= 0) continue;

      final unit = match.group(2)!.toLowerCase();

      final per100ml = unit == 'ml' ||
          unit.startsWith('milliliter') ||
          unit.startsWith('millilitre');

      debugPrint(
        '[OCR] Serving size found near heading: '
        '$amount ${per100ml ? 'ml' : 'g'}',
      );

      return (
        amount: amount,
        per100ml: per100ml,
      );
    }

    debugPrint('[OCR] Serving size could not be identified.');

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

  // Separate percentage values. Never infer a column from the order of OCR matches.
  String _caloriesReni = '';
  String _dietaryFiberReni = '';
  String _proteinReni = '';
  String _fatReni = '';
  String _satFatReni = '';
  String _cholesterolReni = '';
  String _sodiumReni = '';
  String _totalCarbReni = '';

  String _caloriesDv = '';
  String _dietaryFiberDv = '';
  String _proteinDv = '';
  String _fatDv = '';
  String _satFatDv = '';
  String _cholesterolDv = '';
  String _sodiumDv = '';
  String _totalCarbDv = '';

  // Header-aware, coordinate-based percentage extraction.
  // Percentage columns may be far to the right of the nutrient names.
  double _textXAt(_OCRLine line, double characterIndex) {
    if (line.text.isEmpty) return line.left;
    final fraction = (characterIndex / line.text.length).clamp(0.0, 1.0);
    return line.left + (line.right - line.left) * fraction;
  }

  Map<String, Map<String, String>> _extractPercentageColumns(
    List<_OCRLine> lines,
    String fullText,
  ) {
    final result = <String, Map<String, String>>{};
    const aliases = <String, List<String>>{
      'calories': ['calories', 'energy'],
      'fat': ['total fat'],
      'satFat': ['saturated fat'],
      'cholesterol': ['cholesterol'],
      'sodium': ['sodium'],
      'totalCarb': ['total carbohydrate', 'total carbs'],
      'fiber': ['dietary fiber', 'dietary fibre'],
      'protein': ['protein'],
    };

    final reniHeader = <double>[];
    final dvHeader = <double>[];

    for (final line in lines) {
      final lower = line.text.toLowerCase();
      for (final match in RegExp(r'reni|rni|rei').allMatches(lower)) {
        reniHeader.add(_textXAt(line, (match.start + match.end) / 2));
      }
      for (final match in RegExp(r'\bdv\b|daily\s*value').allMatches(lower)) {
        dvHeader.add(_textXAt(line, (match.start + match.end) / 2));
      }
    }

    // If OCR recognizes only one header, only that column is eligible.
    // Do not guess the meaning of a percentage when neither header is found.
    final hasReniHeader = reniHeader.isNotEmpty ||
        RegExp(r'\breni\b|\brni\b|\bpdri\b', caseSensitive: false)
            .hasMatch(fullText);
    final hasDvHeader = dvHeader.isNotEmpty ||
        RegExp(r'daily\s*value|\bdv\b', caseSensitive: false)
            .hasMatch(fullText);

    final nutrientRows = <String, double>{};
    for (final entry in aliases.entries) {
      for (final line in lines) {
        final lower = line.text.toLowerCase();
        if (entry.value.any((name) => lower.contains(name))) {
          nutrientRows[entry.key] = line.top;
          break;
        }
      }
    }

    for (final line in lines) {
      final matches = RegExp(r'<\s*\d+(?:\.\d+)?\s*%|\d+(?:\.\d+)?\s*%')
          .allMatches(line.text)
          .toList();
      for (final match in matches) {
        final value = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
        final x = _textXAt(line, (match.start + match.end) / 2);

        String? nearestNutrient;
        double nearestDistance = double.infinity;
        for (final entry in nutrientRows.entries) {
          final distance = (line.top - entry.value).abs();
          if (distance < nearestDistance) {
            nearestDistance = distance;
            nearestNutrient = entry.key;
          }
        }
        if (nearestNutrient == null) continue;

        // Restrict matching to the same/adjacent visual row. This prevents
        // assigning a percentage from a distant nutrient row.
        final rowLine = lines.firstWhere(
          (candidate) =>
              candidate.text.toLowerCase().contains(
                aliases[nearestNutrient]!.first,
              ),
          orElse: () => line,
        );
        final rowTolerance = (rowLine.top - line.top).abs();
        final maxDistance = lines
            .map((item) => (item.right - item.left).abs())
            .fold<double>(0, (a, b) => a > b ? a : b) * 0.035;
        if (rowTolerance > (maxDistance < 12 ? 12 : maxDistance)) continue;

        String? column;
        if (reniHeader.isNotEmpty && dvHeader.isNotEmpty) {
          final reniX = reniHeader.reduce((a, b) => a + b) / reniHeader.length;
          final dvX = dvHeader.reduce((a, b) => a + b) / dvHeader.length;
          column = (x - reniX).abs() <= (x - dvX).abs() ? 'reni' : 'dv';
        } else if (hasReniHeader && !hasDvHeader) {
          column = 'reni';
        } else if (hasDvHeader && !hasReniHeader) {
          column = 'dv';
        } else if (reniHeader.isNotEmpty || dvHeader.isNotEmpty) {
          final knownX = reniHeader.isNotEmpty ? reniHeader : dvHeader;
          final center = knownX.reduce((a, b) => a + b) / knownX.length;
          column = reniHeader.isNotEmpty && (x - center).abs() < 80
              ? 'reni'
              : 'dv';
        }
        if (column == null) continue;

        final nutrientValues = result.putIfAbsent(
          nearestNutrient!,
          () => <String, String>{},
        );
        nutrientValues.putIfAbsent(column, () => value);
      }
    }
    return result;
  }

  String _formatPercent(double amount, double reference) {
    if (!amount.isFinite || reference <= 0) return '';
    return '${(amount / reference * 100).round()}%*';
  }

  // Philippine PDRI 2015 label references (male adults 19–29):
  // energy 2,530 kcal, protein 71 g, dietary fibre 23 g.
  // These are the official general-label computation references.
  void _calculateMissingReni() {
    if (_caloriesReni.isEmpty) {
      final amount = _nullableNum(_caloriesInfo);
      if (amount != null) _caloriesReni = _formatPercent(amount, 2530);
    }
    if (_proteinReni.isEmpty) {
      final amount = _nullableNum(_proteinNum);
      if (amount != null) _proteinReni = _formatPercent(amount, 71);
    }
    if (_dietaryFiberReni.isEmpty) {
      final amount = _nullableNum(_dietaryfiberNum);
      if (amount != null) _dietaryFiberReni = _formatPercent(amount, 23);
    }
  }

  // FDA-style 2,000 kcal Daily Values. Used only when the label's DV
  // column is positively identified and the nutrient amount is available.
  void _calculateMissingDv() {
    final references = <String, double>{
      'fat': 78,
      'satFat': 20,
      'cholesterol': 300,
      'sodium': 2300,
      'totalCarb': 275,
      'fiber': 28,
      'protein': 50,
    };
    final amounts = <String, String>{
      'fat': _fatNum,
      'satFat': _satFatNum,
      'cholesterol': _cholesterolNum,
      'sodium': _sodiumNum,
      'totalCarb': _totalCarbNum,
      'fiber': _dietaryfiberNum,
      'protein': _proteinNum,
    };
    final current = <String, String>{
      'fat': _fatDv,
      'satFat': _satFatDv,
      'cholesterol': _cholesterolDv,
      'sodium': _sodiumDv,
      'totalCarb': _totalCarbDv,
      'fiber': _dietaryFiberDv,
      'protein': _proteinDv,
    };
    final calculated = <String, String>{};
    for (final key in references.keys) {
      if (current[key]!.isNotEmpty) {
        calculated[key] = current[key]!;
        continue;
      }
      final amount = _nullableNum(amounts[key]);
      calculated[key] = amount == null
          ? ''
          : _formatPercent(amount, references[key]!);
    }
    _fatDv = calculated['fat']!;
    _satFatDv = calculated['satFat']!;
    _cholesterolDv = calculated['cholesterol']!;
    _sodiumDv = calculated['sodium']!;
    _totalCarbDv = calculated['totalCarb']!;
    _dietaryFiberDv = calculated['fiber']!;
    _proteinDv = calculated['protein']!;
  }

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
        _alternatives = [];
        _aiExplanation = '';
        recommendation = ' ';
        _lastScannedProduct = null;
        _ingredientItems = [];
        _ingredientAdvisories = [];
        _ingredientRawText = '';
        _ingredientPanelDetected = false;
        _resultTab = 0;
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

      if (pickedFile == null || !mounted) return;
      setState(() {
        _imageFile = pickedFile;
        _scanRejected = false;
      });

      final inputImage = InputImage.fromFilePath(pickedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(
        inputImage,
      );
      if (!mounted) return;
      LabelData? verifiedLabel;
      if (!looksLikeNutritionLabel(recognizedText.text)) {
        // Curved cans and narrow columns can scramble OCR reading order.
        // Give the image model a chance before rejecting the photograph.
        if (!_rec.isLoaded) await _rec.loadCatalog();
        verifiedLabel = await _readLabel(pickedFile);
        if (!mounted) return;
        if (verifiedLabel == null) {
          setState(() {
            _scanRejected = true;
            _recognizedText = '';
            _usedGemini = false;
            score = 0;
          });
          return;
        }
      }
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
        _scanRejected = false;
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

        // Extract percentages by nutrient row and header column, not by list order.
        final percentageMap = _extractPercentageColumns(
          ocrLines,
          _recognizedText,
        );

        _caloriesReni = percentageMap['calories']?['reni'] ?? '';
        _fatReni = percentageMap['fat']?['reni'] ?? '';
        _satFatReni = percentageMap['satFat']?['reni'] ?? '';
        _cholesterolReni = percentageMap['cholesterol']?['reni'] ?? '';
        _sodiumReni = percentageMap['sodium']?['reni'] ?? '';
        _totalCarbReni = percentageMap['totalCarb']?['reni'] ?? '';
        _dietaryFiberReni = percentageMap['fiber']?['reni'] ?? '';
        _proteinReni = percentageMap['protein']?['reni'] ?? '';

        _caloriesDv = percentageMap['calories']?['dv'] ?? '';
        _fatDv = percentageMap['fat']?['dv'] ?? '';
        _satFatDv = percentageMap['satFat']?['dv'] ?? '';
        _cholesterolDv = percentageMap['cholesterol']?['dv'] ?? '';
        _sodiumDv = percentageMap['sodium']?['dv'] ?? '';
        _totalCarbDv = percentageMap['totalCarb']?['dv'] ?? '';
        _dietaryFiberDv = percentageMap['fiber']?['dv'] ?? '';
        _proteinDv = percentageMap['protein']?['dv'] ?? '';

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

        // Fill only missing DV values when the OCR positively identified a DV
        // heading. A calculated value is marked with * in the results table.
        final hasDvHeading = RegExp(
          r'daily\\s*value|\\bdv\\b',
          caseSensitive: false,
        ).hasMatch(_recognizedText);
        final hasReniHeading = RegExp(
          r'reni|rni|rei|pdri',
          caseSensitive: false,
        ).hasMatch(_recognizedText);
        if (hasReniHeading) _calculateMissingReni();
        if (hasDvHeading) _calculateMissingDv();


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
      await _runRecommendation(pickedFile, verifiedLabel: verifiedLabel);
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
      final why = await _gemini
          .explainAlternatives(
            scanned: scanned,
            alternatives: alts,
            user: _userData,
            scannedIngredients: _ingredientItems,
          )
          .timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              debugPrint('[label] Gemini explanation timed out; skipping it.');
              return null;
            },
          );
      if (mounted && why != null) setState(() => _aiExplanation = why);
    } catch (e) {
      debugPrint('[label] explanation skipped: $e');
    }
  }
  
  Future<LabelData?> _readLabel(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final mime =
          file.path.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
      return await _gemini
          .extractLabel(
            bytes,
            mime: mime,
            categories: _rec.categories,
          )
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () {
              debugPrint(
                '[label] Gemini extraction timed out after 35 seconds; '
                'using on-device OCR fallback.',
              );
              return null;
            },
          );
    } catch (e) {
      debugPrint('[label] Gemini read failed: $e');
    }
    return null;
  }

  Future<void> _runRecommendation(
    XFile file, {
    LabelData? verifiedLabel,
  }) async {
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

    // Reuse a successful image review instead of sending the same photo twice.
    final label = verifiedLabel ?? await _readLabel(file);

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

    // The same photo may include ingredients, but a second photo is supported.
    final extractedIngredients = label?.ingredients ?? _ingredientsFromOcr(_recognizedText);
    final extractedAdvisories = _advisoriesFromOcr(_recognizedText);
    _ingredientItems = extractedIngredients;
    _ingredientAdvisories = extractedAdvisories;
    _ingredientRawText = _recognizedText;
    _ingredientPanelDetected =
        extractedIngredients.isNotEmpty || extractedAdvisories.isNotEmpty;

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
      scannedIngredients: _ingredientItems,
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
      _lastScannedProduct = scannedProduct;
      _lastRemainingBudget = remaining;
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

  static const Color _green = Color(0xFF287D35);
  static const Color _blue = Color(0xFF176084);
  static const Color _background = Color(0xFFF7FAF7);
  static const Color _lightGreen = Color(0xFFEAF6EB);

  void _navigate(Widget page) => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => page),
      );

  String _nutritionValue(dynamic value, String unit) {
    final number = _nullableNum(value);
    if (number == null) return '—';
    final formatted = number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(1);
    return '$formatted $unit';
  }

  String _percentage(String value) => value.trim().isEmpty ? '—' : value.trim();

  Widget _sectionCard(Widget child, {EdgeInsetsGeometry? padding}) => Container(
        width: double.infinity,
        padding: padding ?? const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFDDEBDD)),
          borderRadius: BorderRadius.circular(18),
        ),
        child: child,
      );

  Widget _pageHeader() => Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.canPop(context)
                ? Navigator.pop(context)
                : _navigate(DashboardPage(userId: widget.userId)),
            child: const CircleAvatar(
              backgroundColor: Color(0xFFE8F6EA),
              child: Icon(Icons.chevron_left_rounded, color: _green),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Scan ', style: TextStyle(color: Color(0xFF7DB848))),
                  TextSpan(text: 'Label', style: TextStyle(color: _blue)),
                ]),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const Text(
                'Check nutrition facts and food recommendations',
                style: TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ]),
          ),
        ],
      );

  Widget _scanFrame({required bool hasResult}) => _sectionCard(
        Column(children: [
          Container(
            height: hasResult ? 165 : 225,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFBFDFB),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFFCEEDD2), width: 1.2),
            ),
            child: Stack(children: [
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: hasResult
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(File(_imageFile!.path), fit: BoxFit.contain),
                        )
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Icons.document_scanner_outlined, size: 62, color: _green),
                          const SizedBox(height: 13),
                          const Text('Scan or Upload Nutrition Label',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 5),
                          const Text('Align the Nutrition Facts table inside the frame',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 11, color: Colors.black54)),
                          const SizedBox(height: 4),
                          const Text('Supports JPG and PNG • OCR + Gemini',
                              style: TextStyle(fontSize: 10, color: _green)),
                        ]),
                ),
              ),
              for (final a in const [Alignment.topLeft, Alignment.topRight,
                Alignment.bottomLeft, Alignment.bottomRight])
                Align(
                  alignment: a,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CustomPaint(painter: _ScannerCornerPainter(
                        horizontalRight: a.x > 0,
                        verticalBottom: a.y > 0,
                      )),
                    ),
                  ),
                ),
            ]),
          ),
          if (hasResult && !_scanRejected && !_isProcessing) ...[
            const SizedBox(height: 9),
            Text(_usedGemini ? 'Analyzed with Gemini and OCR' : 'Nutrition label read with OCR',
                style: const TextStyle(fontSize: 11, color: _green)),
          ],
        ]),
      );

  Widget _scanButton(String label, IconData icon, ImageSource source,
      {required bool filled}) => SizedBox(
        height: 48,
        width: double.infinity,
        child: filled
            ? ElevatedButton.icon(
                onPressed: _isProcessing ? null : () => _pickImage(source),
                icon: Icon(icon, size: 19),
                label: Text(label),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              )
            : OutlinedButton.icon(
                onPressed: _isProcessing ? null : () => _pickImage(source),
                icon: Icon(icon, size: 19),
                label: Text(label),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  side: const BorderSide(color: _green),
                  shape: const StadiumBorder(),
                  textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                ),
              ),
      );

  Widget _rejectedScanCard() => _sectionCard(
    Column(children: [
      const Icon(Icons.document_scanner_outlined, size: 30, color: _green),
      const SizedBox(height: 12),
      const Text(
        'No readable Nutrition Facts panel detected. '
        'Photograph the printed nutrition table, rather than the food '
        'or front of the package.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, height: 1.45),
      ),
      const SizedBox(height: 16),
      _scanButton('Retake Nutrition Label', Icons.camera_alt_outlined,
        ImageSource.camera, filled: true),
      const SizedBox(height: 8),
      _scanButton('Choose Another Label', Icons.upload_file_rounded,
        ImageSource.gallery, filled: false),
    ]),
  );

  Widget _nutritionRow(String label, String value, String reni, String dv,
      {bool highlight = false}) => Container(
        color: highlight ? const Color(0xFFF5FAF3) : Colors.white,
        child: Row(children: [
          Expanded(flex: 3, child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
              Text(value, style: const TextStyle(fontSize: 11, color: Colors.black54)),
            ]),
          )),
          Expanded(flex: 2, child: Text(_percentage(reni),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10))),
          Expanded(flex: 2, child: Text(_percentage(dv),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10))),
        ]),
      );

  Widget _ingredientsCard() {
    final matches = _matchedAllergies;
    final userHasAllergies = _userAllergies.isNotEmpty;
    final warning = matches.isNotEmpty;
    final message = !_ingredientPanelDetected
        ? 'Not verified — scan the printed ingredients and allergen warnings.'
        : warning
            ? 'Allergen warning: ${matches.join(', ')} found in scanned text.'
            : userHasAllergies
                ? 'No matches found for your recorded allergies in the recognized text.'
                : 'Ingredients captured. Check the original package for accuracy.';

    return _sectionCard(Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Ingredients & Allergen Check', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800, color: _green,
        )),
        const SizedBox(height: 7),
        Text(message, style: TextStyle(
          fontSize: 12,
          color: warning ? Colors.red.shade700 : Colors.black87,
          fontWeight: warning ? FontWeight.w700 : FontWeight.w400,
        )),
        if (_ingredientItems.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('Recognized ingredients', style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 5),
          Text(_ingredientItems.join(', '), style: const TextStyle(fontSize: 11)),
        ],
        if (_ingredientAdvisories.isNotEmpty) ...[
          const SizedBox(height: 9),
          Text(_ingredientAdvisories.join(' • '), style: TextStyle(
            fontSize: 11, color: Colors.deepOrange.shade800,
          )),
        ],
        const SizedBox(height: 10),
        const Text(
          'Screening is based on recognized text and may miss unclear ingredients or cross-contact warnings.',
          style: TextStyle(fontSize: 10, color: Colors.black54),
        ),
        if (_ingredientRawText.trim().isNotEmpty) ...[
          const SizedBox(height: 7),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Review OCR text',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
            children: [
              SelectableText(_ingredientRawText,
                  style: const TextStyle(fontSize: 10)),
            ],
          ),
        ],
        const SizedBox(height: 12),
        if (_isScanningIngredients)
          const Center(child: CircularProgressIndicator(color: _green))
        else
          Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: () => _scanIngredientPanel(ImageSource.gallery),
              icon: const Icon(Icons.upload_rounded, size: 17),
              label: const Text('Upload Ingredients'),
              style: OutlinedButton.styleFrom(foregroundColor: _green),
            )),
            const SizedBox(width: 8),
            Expanded(child: ElevatedButton.icon(
              onPressed: () => _scanIngredientPanel(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_outlined, size: 17),
              label: const Text('Scan Ingredients'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _green, foregroundColor: Colors.white,
              ),
            )),
          ]),
      ],
    ));
  }

  Widget _resultTabButton(String label, int tab) {
    final selected = _resultTab == tab;

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _resultTab = tab),
        borderRadius: BorderRadius.circular(26),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: selected ? _green : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : _green,
            ),
          ),
        ),
      ),
    );
  }

  Widget _results() {
    final calorieValue = _nutritionValue(_caloriesInfo, 'kcal');
    final allergenDetected = _matchedAllergies.isNotEmpty;
    final needsIngredientScan =
        _userAllergies.isNotEmpty && !_ingredientPanelDetected;
    final status = allergenDetected
        ? 'Allergen detected: ${_matchedAllergies.join(', ')}'
        : needsIngredientScan
            ? 'Scan ingredients for allergy screening'
            : recommendation.trim();
    final recommended = !allergenDetected && !needsIngredientScan &&
        status.isNotEmpty && status != 'Not Recommended';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Two tabs only: the app does not scan barcodes.
      Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _lightGreen,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            _resultTabButton('Nutrition Facts', 0),
            _resultTabButton('Ingredients', 1),
          ],
        ),
      ),
      const SizedBox(height: 12),
      if (_resultTab == 0) ...[
      _sectionCard(Row(children: [
        SizedBox(width: 86, height: 105, child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(File(_imageFile!.path), fit: BoxFit.cover),
        )),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Scanned Nutrition Label', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          Text(_servingInfo?.toString() ?? 'Serving information unavailable',
            maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.black54)),
          const SizedBox(height: 5),
          Text('Calories: $calorieValue', style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 7),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 9),
            decoration: BoxDecoration(
              color: needsIngredientScan ? const Color(0xFFF1F4F3) :
                  recommended ? const Color(0xFFEAF6EB) : const Color(0xFFFDEDED),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(status.isEmpty ? 'Assessment unavailable' : status,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                color: needsIngredientScan ? _blue :
                    recommended ? _green : Colors.red.shade700)),
          ),
        ])),
      ])),
      const SizedBox(height: 12),
      _sectionCard(Column(children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(color: _lightGreen, borderRadius: BorderRadius.circular(8)),
          child: const Row(children: [
            Expanded(flex: 3, child: Text('Nutrient / amount', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            Expanded(flex: 2, child: Text('% RENI', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
            Expanded(flex: 2, child: Text('% DV', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800))),
          ]),
        ),
        _nutritionRow('Calories', calorieValue, _caloriesReni, _caloriesDv, highlight: true),
        _nutritionRow('Total Fat', _nutritionValue(_fatNum, 'g'), _fatReni, _fatDv),
        _nutritionRow('Saturated Fat', _nutritionValue(_satFatNum, 'g'), _satFatReni, _satFatDv, highlight: true),
        _nutritionRow('Trans Fat', _nutritionValue(_transFatNum, 'g'), '', ''),
        _nutritionRow('Cholesterol', _nutritionValue(_cholesterolNum, 'mg'), _cholesterolReni, _cholesterolDv, highlight: true),
        _nutritionRow('Sodium', _nutritionValue(_sodiumNum, 'mg'), _sodiumReni, _sodiumDv),
        _nutritionRow('Potassium', _nutritionValue(_potassiumNum, 'mg'), '', '', highlight: true),
        _nutritionRow('Total Carbs', _nutritionValue(_totalCarbNum, 'g'), _totalCarbReni, _totalCarbDv),
        _nutritionRow('Dietary Fiber', _nutritionValue(_dietaryfiberNum, 'g'), _dietaryFiberReni, _dietaryFiberDv, highlight: true),
        _nutritionRow('Sugars', _nutritionValue(_sugarsNum, 'g'), '', ''),
        _nutritionRow('Protein', _nutritionValue(_proteinNum, 'g'), _proteinReni, _proteinDv, highlight: true),
        const SizedBox(height: 8),
        const Text('— = not available on the scanned label. * = calculated reference percentage.',
          style: TextStyle(fontSize: 9, color: Colors.black54)),
      ]), padding: const EdgeInsets.all(10)),
      const SizedBox(height: 12),
      ] else ...[
        _ingredientsCard(),
        const SizedBox(height: 12),
      ],
      _sectionCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Center(child: Text('Alternative Products', style: TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800))),
        const SizedBox(height: 12),
        if (_alternatives.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: Text('No affordable healthier alternative found',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 12))),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF3F8F3),
              borderRadius: BorderRadius.circular(12)),
            child: Column(children: _alternatives.map((product) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(
                '${product.name} — ${product.price > 0 ? '₱${product.price.toStringAsFixed(0)}' : 'Price unavailable'}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
              ),
            )).toList()),
          ),
        if (_aiExplanation.trim().isNotEmpty) ...[
          const SizedBox(height: 11),
          Text(_aiExplanation, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: Colors.black87)),
        ],
      ])),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _scanButton('Upload Again', Icons.upload_rounded, ImageSource.gallery,
          filled: false)),
        const SizedBox(width: 9),
        Expanded(child: _scanButton('Use Camera', Icons.camera_alt_rounded, ImageSource.camera,
          filled: true)),
      ]),
    ]);
  }

  Widget _navItem(IconData icon, String label, bool active, VoidCallback onTap) =>
      Expanded(child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(25),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: active ? const Color(0xFF2987B0) : _green, size: 23),
          Text(label, style: TextStyle(fontSize: 10,
            color: active ? const Color(0xFF2987B0) : _green)),
        ]),
      ));

  Widget _glassNavigation() => Positioned(
    left: 15,
    right: 15,
    bottom: 12 + MediaQuery.of(context).padding.bottom,
    child: SizedBox(height: 96,
      child: Stack(alignment: Alignment.bottomCenter, clipBehavior: Clip.none, children: [
        Positioned(left: 0, right: 0, bottom: 0, height: 68,
          child: ClipRRect(borderRadius: BorderRadius.circular(38),
            child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(38),
                  gradient: LinearGradient(colors: [
                    Colors.white.withOpacity(.10),
                    Colors.white.withOpacity(.03),
                    Colors.white.withOpacity(.08),
                  ]),
                  border: Border.all(color: Colors.white.withOpacity(.2), width: .5),
                ),
                child: Row(children: [
                  _navItem(Icons.home_rounded, 'home', false,
                      () => _navigate(DashboardPage(userId: widget.userId))),
                  _navItem(Icons.savings_rounded, 'budget', false,
                      () => _navigate(BudgetPage(userId: widget.userId))),
                  const Expanded(child: SizedBox()),
                  _navItem(Icons.flag_rounded, 'goals', false,
                      () => _navigate(GoalsPage(userId: widget.userId))),
                  _navItem(Icons.person_rounded, 'profile', false,
                      () => _navigate(ProfilePage(userId: widget.userId))),
                ]),
              ),
            ),
          ),
        ),
        Positioned(top: 0, child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _isProcessing ? null : () => _pickImage(ImageSource.camera),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 61, height: 61, padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: [
                  Colors.white.withOpacity(.85),
                  const Color(0xFFDEF3E6).withOpacity(.55),
                ]),
                border: Border.all(color: Color(0xFF2987B0), width: 2),
              ),
              child: Center(child: Image.asset('assets/icons/scan_icon.png',
                height: 29, color: Color(0xFF2987B0),
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.qr_code_scanner_rounded, color: Color(0xFF2987B0), size: 29))),
            ),
            const SizedBox(height: 3),
            const Text('SCAN LABEL', style: TextStyle(
              fontSize: 8, color: Color(0xFF2987B0), fontWeight: FontWeight.w800,
              letterSpacing: .35)),
          ]),
        )),
      ]),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final hasImage = _imageFile != null;
    return Scaffold(
      backgroundColor: _background,
      extendBody: true,
      body: Stack(children: [
        SafeArea(bottom: false, child: ListView(
          padding: EdgeInsets.fromLTRB(16, 18, 16,
            140 + MediaQuery.of(context).padding.bottom),
          children: [
            _pageHeader(),
            const SizedBox(height: 20),
            if (!hasImage) ...[
              _scanFrame(hasResult: false),
              const SizedBox(height: 28),
              _scanButton('Use Camera to Scan', Icons.camera_alt_outlined,
                ImageSource.camera, filled: true),
              const SizedBox(height: 12),
              _scanButton('Upload Photo from Gallery', Icons.upload_file_rounded,
                ImageSource.gallery, filled: false),
            ] else ...[
              _scanFrame(hasResult: true),
              const SizedBox(height: 12),
              if (_isProcessing)
                const Padding(padding: EdgeInsets.all(24),
                  child: Center(child: Column(children: [
                    CircularProgressIndicator(color: _green),
                    SizedBox(height: 10),
                    Text('Reading nutrition facts and finding alternatives...',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: _green)),
                  ])))
              else if (_scanRejected)
                _rejectedScanCard()
              else
                _results(),
            ],
          ],
        )),
        _glassNavigation(),
      ]),
    );
  }
}

class _ScannerCornerPainter extends CustomPainter {
  final bool horizontalRight;
  final bool verticalBottom;
  const _ScannerCornerPainter({required this.horizontalRight, required this.verticalBottom});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF287D35)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final x = horizontalRight ? size.width : 0.0;
    final y = verticalBottom ? size.height : 0.0;
    final hx = horizontalRight ? -1.0 : 1.0;
    final vy = verticalBottom ? -1.0 : 1.0;
    final path = Path()
      ..moveTo(x + 14 * hx, y)
      ..lineTo(x + 3 * hx, y)
      ..quadraticBezierTo(x, y, x, y + 3 * vy)
      ..lineTo(x, y + 14 * vy);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ScannerCornerPainter oldDelegate) =>
      horizontalRight != oldDelegate.horizontalRight ||
      verticalBottom != oldDelegate.verticalBottom;
}
