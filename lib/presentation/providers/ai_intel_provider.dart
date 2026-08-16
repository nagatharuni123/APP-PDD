import 'package:flutter/foundation.dart';
import 'package:review_analyze/data/services/ai_intel_service.dart';
enum AiStatus { idle, loading, done, error }

/// Provider for all TrustGuard AI intelligence features:
///   - Smart Review Summary
///   - Shopping Assistant chat
///   - Deep Analysis
class AiIntelProvider extends ChangeNotifier {
  final _svc = AiIntelService();

  // ── Summary state ─────────────────────────────────────────────────────────
  AiSummaryResult? _summary;
  AiStatus _summaryStatus = AiStatus.idle;
  String   _summaryError  = '';

  AiSummaryResult? get summary       => _summary;
  AiStatus         get summaryStatus => _summaryStatus;
  String           get summaryError  => _summaryError;
  bool             get summaryLoading => _summaryStatus == AiStatus.loading;

  // ── Chat state ────────────────────────────────────────────────────────────
  final List<AiChatMessage> _messages = [];
  AiStatus _chatStatus = AiStatus.idle;
  String   _chatError  = '';

  List<AiChatMessage> get messages   => List.unmodifiable(_messages);
  AiStatus get chatStatus            => _chatStatus;
  bool     get chatLoading           => _chatStatus == AiStatus.loading;
  String   get chatError             => _chatError;

  // ── Deep state ────────────────────────────────────────────────────────────
  AiDeepResult? _deep;
  AiStatus      _deepStatus = AiStatus.idle;
  String        _deepError  = '';

  AiDeepResult? get deep       => _deep;
  AiStatus      get deepStatus => _deepStatus;
  bool          get deepLoading => _deepStatus == AiStatus.loading;
  String        get deepError  => _deepError;

  // ── Context for active review ─────────────────────────────────────────────
  String? _reviewContext;
  double? _trustScore;
  String? _label;

  void setReviewContext({String? text, double? trustScore, String? label}) {
    _reviewContext = text;
    _trustScore    = trustScore;
    _label         = label;
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SMART SUMMARY
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> generateSummary({
    required String reviewText,
    required String apiKey,
    required double trustScore,
    required String label,
    List<String>? explanation,
  }) async {
    _summaryStatus = AiStatus.loading;
    _summaryError  = '';
    _summary       = null;
    notifyListeners();
    try {
      _summary = await _svc.smartSummary(
        reviewText: reviewText,
        apiKey: apiKey,
        trustScore: trustScore,
        label: label,
        explanation: explanation,
      );
      _summaryStatus = AiStatus.done;
    } catch (e) {
      _summaryError  = _friendly(e.toString());
      _summaryStatus = AiStatus.error;
    }
    notifyListeners();
  }

  void clearSummary() {
    _summary = null; _summaryStatus = AiStatus.idle; _summaryError = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SHOPPING ASSISTANT
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> sendMessage(String text, String apiKey) async {
    if (text.trim().isEmpty) return;
    _messages.add(AiChatMessage(role: 'user', content: text.trim()));
    _chatStatus = AiStatus.loading;
    _chatError  = '';
    notifyListeners();
    try {
      final history = _messages
          .where((m) => m.role == 'assistant')
          .take(6)
          .map((m) => m.toMap())
          .toList();
      final reply = await _svc.askAssistant(
        message:    text.trim(),
        apiKey:     apiKey,
        context:    _reviewContext,
        trustScore: _trustScore,
        label:      _label,
        history:    history,
      );
      _messages.add(AiChatMessage(role: 'assistant', content: reply));
      _chatStatus = AiStatus.done;
    } catch (e) {
      final raw = e.toString();
      // For missing API key or empty reply, use local fallback silently
      // (no red error banner — just give the smart local answer)
      final isLocalFallback = raw.contains('no-api-key') ||
          raw.contains('empty-reply') ||
          raw.contains('400');
      if (!isLocalFallback) {
        _chatError = _friendly(raw);
      }
      _chatStatus = isLocalFallback ? AiStatus.done : AiStatus.error;
      // Generate a smart local response based on the actual user question
      // so the chatbot always gives a relevant answer even without a backend.
      final localReply = _localFallback(text.trim());
      _messages.add(AiChatMessage(role: 'assistant', content: localReply));
    }
    notifyListeners();
  }

  void clearChat() {
    _messages.clear(); _chatStatus = AiStatus.idle; _chatError = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  DEEP ANALYSIS
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> runDeep({
    required String text,
    required String apiKey,
    Map<String, dynamic>? tfidfResult,
  }) async {
    _deepStatus = AiStatus.loading;
    _deepError  = '';
    _deep       = null;
    notifyListeners();
    try {
      _deep = await _svc.deepAnalysis(
          text: text, apiKey: apiKey, tfidfResult: tfidfResult);
      _deepStatus = AiStatus.done;
    } catch (e) {
      _deepError  = _friendly(e.toString());
      _deepStatus = AiStatus.error;
    }
    notifyListeners();
  }

  void clearDeep() {
    _deep = null; _deepStatus = AiStatus.idle; _deepError = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  LOCAL SMART FALLBACK
  //  Used when the backend is unreachable or the API key is missing.
  //  Reads the actual user question and returns a relevant answer.
  // ─────────────────────────────────────────────────────────────────────────

  String _localFallback(String message) {
    final q = message.toLowerCase();

    // ── Greeting ─────────────────────────────────────────────────────────
    if (q.contains('hello') || q.contains('hi ') || q == 'hi' ||
        q.contains('hey') || q.contains('good morning') ||
        q.contains('good evening') || q.contains('good afternoon')) {
      return "Hello! 👋 I'm the **TrustGuard AI Shopping Assistant**.\n\n"
          "I can help you with:\n"
          "• Understanding fake review detection\n"
          "• Explaining how the Trust Score is calculated\n"
          "• Giving safe shopping advice\n"
          "• Answering questions about TF-IDF and Random Forest\n\n"
          "What would you like to know?";
    }

    // ── How does fake review detection work ───────────────────────────────
    if ((q.contains('how') && (q.contains('detect') || q.contains('work') ||
        q.contains('fake review'))) ||
        q.contains('fake review detection') ||
        (q.contains('detection') && q.contains('work'))) {
      return "TrustGuard AI uses a **TF-IDF + Random Forest** machine learning pipeline:\n\n"
          "1. **Text Preprocessing** — The review text is cleaned and tokenised\n"
          "2. **TF-IDF Vectorizer** — Converts text into 5,000 numerical features based on word frequency and importance\n"
          "3. **N-gram Analysis** — Detects repeated 1–3 word phrases typical of bot-generated content\n"
          "4. **Lexical Diversity Check** — Measures vocabulary variety (bots reuse the same words more than humans)\n"
          "5. **Sentiment Analysis** — Flags unnaturally positive reviews that lack any criticism\n"
          "6. **Random Forest Classifier** — 200 decision trees vote to classify the review as:\n"
          "   • ✅ Genuine  • ⚠️ Suspicious  • 🚫 Deceptive/Bot-Generated\n\n"
          "The result is a **Trust Score (0–100%)** with XAI explanations showing exactly why the verdict was reached.";
    }

    // ── Trust score ───────────────────────────────────────────────────────
    if (q.contains('trust score') || q.contains('score calculat') ||
        q.contains('how is the score') || q.contains('score work') ||
        (q.contains('score') && (q.contains('calcul') || q.contains('how')))) {
      return "**How the Trust Score is calculated:**\n\n"
          "The score starts from the Random Forest classifier's probability that a review is genuine, "
          "then penalties are applied based on detected red flags:\n\n"
          "• **−6 pts** per repeated keyword\n"
          "• **−8 pts** per repeated phrase (bigram)\n"
          "• **−up to 16 pts** for excessive exclamation marks\n"
          "• **−30 pts** for high caps ratio (>25% uppercase)\n"
          "• **−10 pts** per promotional phrase ('Buy now', 'Limited offer')\n"
          "• **−15 pts** for very short reviews (<12 words)\n"
          "• **−12 pts** for low vocabulary diversity (<45% unique words)\n\n"
          "**Score ranges:**\n"
          "• 75–100% ✅ Genuine\n"
          "• 40–74% ⚠️ Suspicious\n"
          "• 0–39% 🚫 Deceptive / Bot-Generated";
    }

    // ── What makes a review suspicious ───────────────────────────────────
    if (q.contains('suspicious') || q.contains('red flag') ||
        q.contains('what makes') || q.contains('signs of fake') ||
        q.contains('fake sign') || q.contains('spot fake') ||
        q.contains('identify fake') || q.contains('recogni')) {
      return "**Signs that make a review suspicious:**\n\n"
          "• 🔴 **Keyword repetition** — Same words used 3+ times unnaturally\n"
          "• 🔴 **Too positive** — 5+ praise words with zero criticism or specific detail\n"
          "• 🔴 **Hyperbolic language** — 'Best product ever', '100% recommend', 'life-changing'\n"
          "• 🔴 **Very short review** — Under 12 words with no specifics\n"
          "• 🔴 **Promotional phrases** — 'Buy now', 'Limited offer', 'Click here'\n"
          "• 🔴 **Low vocabulary diversity** — Less than 45% unique words (bot-like pattern)\n"
          "• 🔴 **Excessive caps** — More than 25% uppercase characters\n"
          "• 🔴 **No specific details** — Doesn't mention the product name, model, or actual experience\n\n"
          "If you see 3 or more of these in a review, it is very likely fake.";
    }

    // ── Tips to spot fake reviews ─────────────────────────────────────────
    if (q.contains('tip') || q.contains('advice') || q.contains('guide') ||
        q.contains('how can i spot') || q.contains('how to spot') ||
        q.contains('how to identify') || q.contains('shopping safe')) {
      return "**Tips for spotting fake reviews:**\n\n"
          "1. 📊 **Check the rating distribution** — A product with only 5-star ratings and no lower reviews is suspicious\n"
          "2. 📅 **Look at review dates** — A sudden burst of reviews posted in one day is a red flag\n"
          "3. ✅ **Filter to Verified Purchases only** — Only trust reviews from confirmed buyers\n"
          "4. 📝 **Read the 3-star reviews** — Middle-ground reviews tend to be the most honest\n"
          "5. 🔍 **Look for specific product details** — Real buyers mention exact features, model numbers, or comparisons\n"
          "6. 📸 **Check for photos/videos** — Genuine buyers often attach real product photos\n"
          "7. 👤 **Check the reviewer's profile** — A new account with only 5-star reviews is suspicious\n"
          "8. 🔗 **Use TrustGuard AI** — Paste the review text or product URL for instant AI analysis";
    }

    // ── TF-IDF ────────────────────────────────────────────────────────────
    if (q.contains('tf-idf') || q.contains('tf idf') || q.contains('tfidf') ||
        q.contains('term frequency') || q.contains('inverse document')) {
      return "**What is TF-IDF?**\n\n"
          "TF-IDF stands for **Term Frequency – Inverse Document Frequency**. "
          "It is a numerical technique that converts text into numbers a machine learning model can process.\n\n"
          "• **TF (Term Frequency)** — How often a word appears in the review\n"
          "• **IDF (Inverse Document Frequency)** — How unique that word is across all reviews "
          "(common words like 'the' get a low score; rare words get a high score)\n\n"
          "**In TrustGuard AI:**\n"
          "The TF-IDF vectorizer converts each review into a vector of 5,000 features using N-grams (1–3 word combinations). "
          "Bot-generated reviews score high on a small set of repeated terms, while genuine reviews spread weight across many varied terms. "
          "These features are fed into the Random Forest classifier to determine the verdict.";
    }

    // ── Random Forest ─────────────────────────────────────────────────────
    if (q.contains('random forest') || q.contains('random-forest') ||
        q.contains('decision tree') || q.contains('ensemble') ||
        q.contains('classifier') || q.contains('machine learning') ||
        q.contains('ml model') || q.contains('ai model')) {
      return "**What is Random Forest?**\n\n"
          "Random Forest is an **ensemble machine learning algorithm** that builds many decision trees "
          "and combines their votes for a final prediction.\n\n"
          "**In TrustGuard AI:**\n"
          "• **200 decision trees** are trained on labelled review data (Genuine / Suspicious / Fake)\n"
          "• Each tree independently classifies the review\n"
          "• The majority vote determines the final verdict\n"
          "• Class weights are balanced to handle unequal training data\n\n"
          "**Why Random Forest?**\n"
          "• Resistant to overfitting compared to a single decision tree\n"
          "• Works well with TF-IDF sparse feature vectors\n"
          "• Provides probability scores (used for the Trust Score %) alongside the class label\n"
          "• Fast inference — classifies a review in milliseconds";
    }

    // ── Genuine review ────────────────────────────────────────────────────
    if (q.contains('genuine') || q.contains('real review') ||
        q.contains('authentic') || q.contains('trusted review') ||
        (q.contains('what is') && q.contains('review') && !q.contains('fake'))) {
      return "**What is a genuine review?**\n\n"
          "A genuine review is written by a real buyer who actually purchased and used the product. "
          "TrustGuard AI identifies genuine reviews by these signals:\n\n"
          "✅ **Balanced sentiment** — Mentions both positives and negatives\n"
          "✅ **Specific details** — References the product name, model, or real usage experience\n"
          "✅ **Natural vocabulary** — High lexical diversity (>55% unique words)\n"
          "✅ **Reasonable length** — Usually 20–200 words with complete sentences\n"
          "✅ **No promotional language** — Does not say 'Buy now', 'Limited time offer', etc.\n"
          "✅ **Consistent tone** — Sentiment matches the star rating given\n\n"
          "A genuine review scores **75–100% on the TrustGuard Trust Score**.";
    }

    // ── 5-star reviews ────────────────────────────────────────────────────
    if (q.contains('5 star') || q.contains('five star') ||
        q.contains('all positive') || q.contains('only positive') ||
        q.contains('trustworth') || q.contains('can i trust')) {
      return "**Are all 5-star reviews trustworthy?**\n\n"
          "Not necessarily. A high star rating alone does not mean the reviews are genuine.\n\n"
          "**Red flags even in 5-star reviews:**\n"
          "• Multiple 5-star reviews posted on the same day\n"
          "• Reviews with identical or very similar wording\n"
          "• Very short reviews ('Great product! Highly recommend!')\n"
          "• Reviewer profiles with only 5-star reviews across many products\n"
          "• No mention of specific product features or comparisons\n\n"
          "**What to do:**\n"
          "Paste the review text into TrustGuard AI's Scanner to get an instant Trust Score. "
          "A genuine-looking 5-star review will score 75%+, while a bot-generated one will score below 40%.";
    }

    // ── What does the AI assistant do ────────────────────────────────────
    if ((q.contains('what') && q.contains('assistant')) ||
        (q.contains('what') && q.contains('do you do')) ||
        q.contains('what can you') || q.contains('your purpose') ||
        q.contains('who are you') || q.contains('what are you')) {
      return "I'm the **TrustGuard AI Shopping Assistant** — your guide to safe online shopping.\n\n"
          "I can help you with:\n\n"
          "🔍 **Review Analysis** — Explain why a review was flagged as fake or genuine\n"
          "🛡️ **Fake Detection** — How TrustGuard's TF-IDF + Random Forest system works\n"
          "📊 **Trust Score** — What the 0–100% score means and how it's calculated\n"
          "💡 **Shopping Tips** — How to spot fake reviews yourself\n"
          "🤖 **ML Explanations** — What TF-IDF, Random Forest, and XAI mean in plain English\n\n"
          "Try asking: *'How does fake review detection work?'* or *'What makes a review suspicious?'*";
    }

    // ── Thank you ─────────────────────────────────────────────────────────
    if (q.contains('thank') || q.contains('thanks') || q.contains('great') ||
        q.contains('awesome') || q.contains('helpful') || q.contains('perfect')) {
      return "You're welcome! 😊\n\n"
          "Feel free to ask anything else about fake reviews, trust scores, or safe shopping. "
          "You can also use the **Scanner tab** to analyze any review text or product URL instantly.";
    }

    // ── XAI / Explainability ──────────────────────────────────────────────
    if (q.contains('xai') || q.contains('explainable') ||
        q.contains('explanation') || q.contains('why did') ||
        q.contains('why was')) {
      return "**Explainable AI (XAI) in TrustGuard:**\n\n"
          "After every scan, TrustGuard shows *why* the verdict was reached, not just *what* it is.\n\n"
          "**XAI breakdown includes:**\n"
          "• Specific words or phrases that triggered fake signals\n"
          "• Whether vocabulary diversity is too low (bot-like)\n"
          "• Whether sentiment is unnaturally one-sided\n"
          "• Whether exclamation marks or caps are excessive\n"
          "• Whether promotional language patterns were detected\n\n"
          "This transparency lets you understand and verify the AI's reasoning rather than blindly trusting a score.";
    }

    // ── Generic default — still relevant, not identical for every question ─
    return "I can help with questions about **fake review detection**, **trust scores**, "
        "**safe shopping**, and the **TF-IDF + Random Forest model** used in TrustGuard AI.\n\n"
        "Here are some things you can ask me:\n\n"
        "• *'How does fake review detection work?'*\n"
        "• *'What makes a review suspicious?'*\n"
        "• *'How is the trust score calculated?'*\n"
        "• *'What is TF-IDF?'*\n"
        "• *'What is Random Forest?'*\n"
        "• *'Tips to spot fake reviews'*\n\n"
        "For AI-powered responses based on your Gemini API key, add your key in the **Profile → AI Engine** section.";
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _friendly(String raw) {
    final lower = raw.toLowerCase();
    // Network / connection errors
    if (lower.contains('socketexception') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('os error') ||
        lower.contains('failed host lookup')) {
      return 'Backend unreachable — start the Python server on port 8000.';
    }
    if (lower.contains('timeoutexception') || lower.contains('timed out')) {
      return 'Connection timed out — is the backend running on port 8000?';
    }
    if (lower.contains('502') || lower.contains('503') || lower.contains('refused')) {
      return 'Backend unreachable — start the Python server on port 8000.';
    }
    if (lower.contains('api key') || lower.contains('401') || lower.contains('403')) {
      return 'Intelligence key error — check your API key in Settings.';
    }
    if (lower.contains('xmlhttprequest') || lower.contains('cors')) {
      return 'Connection blocked — check that the backend has CORS enabled.';
    }
    return raw.length > 120 ? '${raw.substring(0, 120)}…' : raw;
  }

  void reset() {
    clearSummary(); clearChat(); clearDeep();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  SCANNER ENHANCE
  // ─────────────────────────────────────────────────────────────────────────

  ScannerEnhanceResult? _enhance;
  AiStatus _enhanceStatus = AiStatus.idle;
  String   _enhanceError  = '';

  ScannerEnhanceResult? get enhanceResult  => _enhance;
  AiStatus              get enhanceStatus  => _enhanceStatus;
  bool                  get enhanceLoading => _enhanceStatus == AiStatus.loading;
  String                get enhanceError   => _enhanceError;

  Future<void> runEnhance({
    required String reviewText,
    required String apiKey,
    double? trustScore,
    String? label,
  }) async {
    _enhanceStatus = AiStatus.loading;
    _enhanceError  = '';
    _enhance       = null;
    clearChat(); // fresh chat for each scan
    notifyListeners();
    try {
      _enhance = await _svc.enhanceScan(
        reviewText: reviewText, apiKey: apiKey,
        trustScore: trustScore, label: label,
      );
      _enhanceStatus = AiStatus.done;
    } catch (e) {
      _enhanceError  = _friendly(e.toString());
      _enhanceStatus = AiStatus.error;
    }
    notifyListeners();
  }

  void clearEnhance() {
    _enhance = null; _enhanceStatus = AiStatus.idle; _enhanceError = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  COMPARISON MODE
  // ─────────────────────────────────────────────────────────────────────────

  CompareResult? _compare;
  AiStatus _compareStatus = AiStatus.idle;
  String   _compareError  = '';

  CompareResult? get compareResult  => _compare;
  AiStatus       get compareStatus  => _compareStatus;
  bool           get compareLoading => _compareStatus == AiStatus.loading;
  String         get compareError   => _compareError;

  Future<void> compareProducts({
    required String productA,
    required String productB,
    required String apiKey,
  }) async {
    _compareStatus = AiStatus.loading;
    _compareError  = '';
    _compare       = null;
    notifyListeners();
    try {
      _compare = await _svc.compareProducts(
        productA: productA, productB: productB, apiKey: apiKey);
      _compareStatus = AiStatus.done;
    } catch (e) {
      _compareError  = _friendly(e.toString());
      _compareStatus = AiStatus.error;
    }
    notifyListeners();
  }

  void clearCompare() {
    _compare = null; _compareStatus = AiStatus.idle; _compareError = '';
    notifyListeners();
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  COMPARE DETAIL (rich: image, price, rating, description)
  // ─────────────────────────────────────────────────────────────────────────

  CompareDetailResult? _compareDetail;
  AiStatus _compareDetailStatus = AiStatus.idle;
  String   _compareDetailError  = '';

  CompareDetailResult? get compareDetailResult  => _compareDetail;
  AiStatus             get compareDetailStatus  => _compareDetailStatus;
  bool                 get compareDetailLoading => _compareDetailStatus == AiStatus.loading;
  String               get compareDetailError   => _compareDetailError;

  Future<void> runCompareDetail({
    required String productA,
    required String productB,
    required String apiKey,
  }) async {
    _compareDetailStatus = AiStatus.loading;
    _compareDetailError  = '';
    _compareDetail       = null;
    notifyListeners();
    try {
      _compareDetail = await _svc.compareDetail(
          productA: productA, productB: productB, apiKey: apiKey);
      _compareDetailStatus = AiStatus.done;
    } catch (e) {
      _compareDetailError  = _friendly(e.toString());
      _compareDetailStatus = AiStatus.error;
    }
    notifyListeners();
  }

  void clearCompareDetail() {
    _compareDetail = null;
    _compareDetailStatus = AiStatus.idle;
    _compareDetailError  = '';
    notifyListeners();
  }
}
