import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:review_analyze/config/api_config.dart';

/// TrustGuard AI Intelligence Service
class AiIntelService {
  static const Duration _timeout = Duration(seconds: 30);

  // ── Smart Summary ─────────────────────────────────────────────────────────

  Future<AiSummaryResult> smartSummary({
    required String reviewText,
    required String apiKey,
    required double trustScore,
    required String label,
    List<String>? explanation,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.aiSummary),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'review_text': reviewText,
        'api_key': apiKey,
        'trust_score': trustScore,
        'label': label,
        if (explanation != null) 'explanation': explanation,
      }),
    ).timeout(_timeout);

    if (resp.statusCode == 200) {
      return AiSummaryResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception(_parseError(resp.body));
  }

  // ── Shopping Assistant ────────────────────────────────────────────────────

  Future<String> askAssistant({
    required String message,
    required String apiKey,
    String? context,
    double? trustScore,
    String? label,
    List<Map<String, String>>? history,
  }) async {
    // Guard: if no API key is set, throw immediately so the provider's
    // catch block activates the local smart fallback — no network round-trip.
    if (apiKey.trim().length < 10) {
      throw Exception('no-api-key');
    }

    final resp = await http.post(
      Uri.parse(ApiConfig.aiAssistant),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'message': message,
        'api_key': apiKey,
        if (context != null)     'context': context,
        if (trustScore != null)  'trust_score': trustScore,
        if (label != null)       'label': label,
        if (history != null)     'history': history,
      }),
    ).timeout(_timeout);

    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final reply = data['reply'] as String? ?? '';
      // If the backend returned an empty string, treat it as a fallback trigger
      if (reply.trim().isEmpty) throw Exception('empty-reply');
      return reply;
    }
    throw Exception(_parseError(resp.body));
  }

  // ── Deep Analysis ─────────────────────────────────────────────────────────

  Future<AiDeepResult> deepAnalysis({
    required String text,
    required String apiKey,
    Map<String, dynamic>? tfidfResult,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.aiDeep),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'text': text,
        'api_key': apiKey,
        if (tfidfResult != null) 'tfidf_result': tfidfResult,
      }),
    ).timeout(_timeout);

    if (resp.statusCode == 200) {
      return AiDeepResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception(_parseError(resp.body));
  }

  String _parseError(String body) {
    try {
      final m = jsonDecode(body) as Map<String, dynamic>;
      return m['detail']?.toString() ?? body;
    } catch (_) {
      return body.length > 100 ? '${body.substring(0, 100)}…' : body;
    }
  }
}

// ── Result models ─────────────────────────────────────────────────────────

class AiSummaryResult {
  final String summary;
  final List<String> keyPoints;
  final String buyingAdvice;
  final String sentimentNote;

  const AiSummaryResult({
    required this.summary,
    required this.keyPoints,
    required this.buyingAdvice,
    required this.sentimentNote,
  });

  factory AiSummaryResult.fromJson(Map<String, dynamic> j) => AiSummaryResult(
        summary:       j['summary']       as String? ?? '',
        keyPoints:     List<String>.from(j['key_points'] ?? []),
        buyingAdvice:  j['buying_advice'] as String? ?? '',
        sentimentNote: j['sentiment_breakdown'] as String? ?? '',
      );
}

class AiDeepResult {
  final String deepLabel;
  final double deepTrustScore;
  final String narrative;
  final List<String> redFlags;
  final List<String> greenFlags;
  final String finalVerdict;

  const AiDeepResult({
    required this.deepLabel,
    required this.deepTrustScore,
    required this.narrative,
    required this.redFlags,
    required this.greenFlags,
    required this.finalVerdict,
  });

  factory AiDeepResult.fromJson(Map<String, dynamic> j) => AiDeepResult(
        deepLabel:      j['deep_label']       as String? ?? '',
        deepTrustScore: (j['deep_trust_score'] as num?)?.toDouble() ?? 0,
        narrative:      j['narrative']         as String? ?? '',
        redFlags:       List<String>.from(j['red_flags']   ?? []),
        greenFlags:     List<String>.from(j['green_flags'] ?? []),
        finalVerdict:   j['final_verdict']     as String? ?? '',
      );
}

// ── Chat message ──────────────────────────────────────────────────────────

class AiChatMessage {
  final String role;    // 'user' | 'assistant'
  final String content;
  final DateTime time;

  AiChatMessage({required this.role, required this.content, DateTime? time})
      : time = time ?? DateTime.now();

  Map<String, String> toMap() => {'role': role, 'content': content};
}

// ── Product Global Analysis ───────────────────────────────────────────────

class ProductAnalyzeResult {
  final String productName;
  final String report;

  const ProductAnalyzeResult({required this.productName, required this.report});

  factory ProductAnalyzeResult.fromJson(Map<String, dynamic> j) =>
      ProductAnalyzeResult(
        productName: j['product_name'] as String? ?? '',
        report: j['report'] as String? ?? '',
      );
}

extension ProductAnalyze on AiIntelService {
  Future<ProductAnalyzeResult> analyzeProduct({
    required String productName,
    required String apiKey,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.aiProductAnalyze),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_name': productName, 'api_key': apiKey}),
    ).timeout(const Duration(seconds: 35));

    if (resp.statusCode == 200) {
      return ProductAnalyzeResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    // Non-200: surface the detail message from the backend
    String detail = resp.body;
    try {
      final m = jsonDecode(resp.body) as Map<String, dynamic>;
      detail = m['detail']?.toString() ?? resp.body;
    } catch (_) {}
    throw Exception(detail.length > 120 ? '${detail.substring(0, 120)}…' : detail);
  }
}

// ── Scanner Enhancement ───────────────────────────────────────────────────

class ScannerEnhanceResult {
  final String sentiment;
  final double sentimentScore;
  final String keyTakeaway;
  final double predictedRating;
  final List<String> pros;
  final List<String> cons;
  final List<String> fakeSignals;
  final bool isSuspicious;
  final List<String> emotions;
  final Map<String, dynamic> emotionScores;
  final String summaryOneLine;

  const ScannerEnhanceResult({
    required this.sentiment, required this.sentimentScore,
    required this.keyTakeaway, required this.predictedRating,
    required this.pros, required this.cons, required this.fakeSignals,
    required this.isSuspicious, required this.emotions,
    required this.emotionScores, required this.summaryOneLine,
  });

  factory ScannerEnhanceResult.fromJson(Map<String, dynamic> j) =>
      ScannerEnhanceResult(
        sentiment: j['sentiment'] as String? ?? 'Neutral',
        sentimentScore: (j['sentiment_score'] as num?)?.toDouble() ?? 50,
        keyTakeaway: j['key_takeaway'] as String? ?? '',
        predictedRating: (j['predicted_rating'] as num?)?.toDouble() ?? 3.0,
        pros: List<String>.from(j['pros'] ?? []),
        cons: List<String>.from(j['cons'] ?? []),
        fakeSignals: List<String>.from(j['fake_signals'] ?? []),
        isSuspicious: j['is_suspicious'] as bool? ?? false,
        emotions: List<String>.from(j['emotions'] ?? ['Neutral']),
        emotionScores: j['emotion_scores'] as Map<String, dynamic>? ?? {},
        summaryOneLine: j['summary_one_line'] as String? ?? '',
      );
}

class CompareResult {
  final String productAName, productBName;
  final double productAScore, productBScore;
  final String winner, recommendation;
  final List<String> comparisonPoints, aPros, bPros, aCons, bCons;

  const CompareResult({
    required this.productAName, required this.productBName,
    required this.productAScore, required this.productBScore,
    required this.winner, required this.recommendation,
    required this.comparisonPoints, required this.aPros, required this.bPros,
    this.aCons = const [], this.bCons = const [],
  });

  factory CompareResult.fromJson(Map<String, dynamic> j) => CompareResult(
    productAName: j['product_a_name'] as String? ?? '',
    productBName: j['product_b_name'] as String? ?? '',
    productAScore: (j['product_a_score'] as num?)?.toDouble() ?? 65,
    productBScore: (j['product_b_score'] as num?)?.toDouble() ?? 70,
    winner: j['winner'] as String? ?? 'product_b',
    recommendation: j['recommendation'] as String? ?? '',
    comparisonPoints: List<String>.from(j['comparison_points'] ?? []),
    aPros: List<String>.from(j['a_pros'] ?? []),
    bPros: List<String>.from(j['b_pros'] ?? []),
    aCons: List<String>.from(j['a_cons'] ?? []),
    bCons: List<String>.from(j['b_cons'] ?? []),
  );

  bool get aWins => winner == 'product_a';
}

extension ScannerEnhance on AiIntelService {
  Future<ScannerEnhanceResult> enhanceScan({
    required String reviewText,
    required String apiKey,
    double? trustScore,
    String? label,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.aiScannerEnhance),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'review_text': reviewText,
        'api_key': apiKey,
        if (trustScore != null) 'trust_score': trustScore,
        if (label != null) 'label': label,
      }),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return ScannerEnhanceResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Enhance failed: ${resp.statusCode}');
  }

  Future<CompareResult> compareProducts({
    required String productA,
    required String productB,
    required String apiKey,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.aiCompare),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_a': productA, 'product_b': productB, 'api_key': apiKey}),
    ).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return CompareResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Compare failed: ${resp.statusCode}');
  }
}

// ── Compare Detail ────────────────────────────────────────────────────────

class ProductDetailInfo {
  final String name;
  final String? imageUrl, price, rating, description, error;
  final bool isUrl;
  const ProductDetailInfo({required this.name, this.imageUrl, this.price,
      this.rating, this.description, this.error, this.isUrl = false});
  factory ProductDetailInfo.fromJson(Map<String, dynamic> j) =>
      ProductDetailInfo(
        name:        j['name']        as String? ?? '',
        imageUrl:    j['image_url']   as String?,
        price:       j['price']       as String?,
        rating:      j['rating']      as String?,
        description: j['description'] as String?,
        error:       j['error']       as String?,
        isUrl:       j['is_url']      as bool? ?? false,
      );
}

class CompareDetailResult {
  final ProductDetailInfo productA, productB;
  final Map<String, dynamic>? aiComparison;
  const CompareDetailResult({required this.productA, required this.productB,
      this.aiComparison});
  factory CompareDetailResult.fromJson(Map<String, dynamic> j) =>
      CompareDetailResult(
        productA:     ProductDetailInfo.fromJson(j['product_a'] as Map<String, dynamic>),
        productB:     ProductDetailInfo.fromJson(j['product_b'] as Map<String, dynamic>),
        aiComparison: j['ai_comparison'] as Map<String, dynamic>?,
      );
  String? get winner => aiComparison?['winner'] as String?;
  double get aScore  => (aiComparison?['product_a_score'] as num?)?.toDouble() ?? 65;
  double get bScore  => (aiComparison?['product_b_score'] as num?)?.toDouble() ?? 65;
  String get recommendation => aiComparison?['recommendation'] as String? ?? '';
  List<String> get comparisonPoints =>
      (aiComparison?['comparison_points'] as List?)?.cast<String>() ?? [];
  List<String> get aPros => (aiComparison?['a_pros'] as List?)?.cast<String>() ?? [];
  List<String> get bPros => (aiComparison?['b_pros'] as List?)?.cast<String>() ?? [];
  List<String> get aCons => (aiComparison?['a_cons'] as List?)?.cast<String>() ?? [];
  List<String> get bCons => (aiComparison?['b_cons'] as List?)?.cast<String>() ?? [];
  bool get aWins => winner == 'product_a';
}

extension CompareDetail on AiIntelService {
  Future<CompareDetailResult> compareDetail({
    required String productA,
    required String productB,
    required String apiKey,
  }) async {
    final resp = await http.post(
      Uri.parse(ApiConfig.compareDetail),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'product_a': productA, 'product_b': productB, 'api_key': apiKey}),
    ).timeout(const Duration(seconds: 40));
    if (resp.statusCode == 200) {
      return CompareDetailResult.fromJson(
          jsonDecode(resp.body) as Map<String, dynamic>);
    }
    throw Exception('Compare detail failed: ${resp.statusCode}');
  }
}
