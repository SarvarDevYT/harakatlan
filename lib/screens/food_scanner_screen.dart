import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/nutrition_models.dart';
import '../services/nutrition_service.dart';
import '../theme.dart';
import '../widgets/common.dart';

enum ScannerState { initial, loading, success, error }

class FoodScannerScreen extends StatefulWidget {
  const FoodScannerScreen({super.key});

  @override
  State<FoodScannerScreen> createState() => _FoodScannerScreenState();
}

class _FoodScannerScreenState extends State<FoodScannerScreen> with SingleTickerProviderStateMixin {
  final _picker = ImagePicker();
  ScannerState _state = ScannerState.initial;
  Uint8List? _selectedImageBytes;
  NutritionAnalysisResult? _result;
  String _errorMessage = '';

  late final AnimationController _scannerPulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

  @override
  void dispose() {
    _scannerPulse.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1400,
        maxHeight: 1400,
        imageQuality: 85,
      );
      if (file == null) return;

      final bytes = await file.readAsBytes();
      setState(() {
        _selectedImageBytes = bytes;
        _state = ScannerState.loading;
        _errorMessage = '';
      });

      _analyzeImage(bytes);
    } catch (e) {
      setState(() {
        _state = ScannerState.error;
        _errorMessage = "Rasm yuklashda xatolik yuz berdi: $e";
      });
    }
  }

  Future<void> _analyzeImage(Uint8List bytes) async {
    try {
      final res = await NutritionService.analyzeFoodImage(imageBytes: bytes);
      if (!mounted) return;
      setState(() {
        _result = res;
        _state = ScannerState.success;
      });
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = ScannerState.error;
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
      });
      HapticFeedback.heavyImpact();
    }
  }

  void _loadDemoSample() {
    setState(() {
      _selectedImageBytes = null;
      _result = NutritionService.getSampleDish();
      _state = ScannerState.success;
    });
  }

  void _editIngredient(int index) {
    if (_result == null) return;
    final ing = _result!.ingredients[index];
    final ctrl = TextEditingController(text: ing.estimatedWeightG.toStringAsFixed(0));

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QC.surface,
        title: Text("${ing.name} vaznini tahrirlash", style: display(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Vazn o'zgarganda kaloriya va makrolar avtomatik qayta hisoblanadi:",
                style: body(13, color: QC.textSoft)),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              style: display(22, color: QC.lime),
              decoration: const InputDecoration(
                labelText: "Vazni (gramm)",
                suffixText: "g",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Bekor qilish"),
          ),
          FilledButton(
            onPressed: () {
              final newWeight = double.tryParse(ctrl.text.trim());
              if (newWeight != null && newWeight > 0) {
                setState(() {
                  _result!.ingredients[index] = ing.updateWeight(newWeight);
                  _result!.recalculateTotals();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Saqlash"),
          ),
        ],
      ),
    );
  }

  void _deleteIngredient(int index) {
    if (_result == null) return;
    setState(() {
      _result!.ingredients.removeAt(index);
      _result!.recalculateTotals();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Ingredient o'chirildi")),
    );
  }

  void _addIngredientDialog() {
    final nameCtrl = TextEditingController();
    final weightCtrl = TextEditingController(text: "100");
    final calCtrl = TextEditingController(text: "150");

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: QC.surface,
        title: Text("Yangi ingredient qo'shish", style: display(18)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              style: body(15),
              decoration: const InputDecoration(labelText: "Nomi (masalan, Non)"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              style: body(15),
              decoration: const InputDecoration(labelText: "Vazni (gramm)", suffixText: "g"),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              style: body(15),
              decoration: const InputDecoration(labelText: "Kaloriyasi (kcal)", suffixText: "kcal"),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Bekor qilish")),
          FilledButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final weight = double.tryParse(weightCtrl.text.trim()) ?? 100.0;
              final cal = int.tryParse(calCtrl.text.trim()) ?? 100;
              if (name.isNotEmpty) {
                setState(() {
                  _result!.ingredients.add(FoodIngredient(
                    name: name,
                    estimatedWeightG: weight,
                    calories: cal,
                    proteinG: (cal * 0.08 * 10).round() / 10,
                    carbsG: (cal * 0.12 * 10).round() / 10,
                    fatG: (cal * 0.03 * 10).round() / 10,
                  ));
                  _result!.recalculateTotals();
                });
              }
              Navigator.pop(ctx);
            },
            child: const Text("Qo'shish"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        const ContourBackground(),
        SafeArea(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  tooltip: 'Orqaga',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text("AI Taom Skaneri", style: display(22)),
                    Text("Gemini Flash Vision · Kaloriyalar", style: body(12, color: QC.muted)),
                  ]),
                ),
                Chip2("AI Vision", dot: QC.lime, background: QC.surface2),
              ]),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: switch (_state) {
                ScannerState.initial => _buildInitialView(),
                ScannerState.loading => _buildLoadingSkeleton(),
                ScannerState.success => _buildSuccessView(),
                ScannerState.error => _buildErrorView(),
              },
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _buildInitialView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: QC.lime.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: QC.lime, width: 2),
            ),
            child: const Icon(Icons.restaurant_rounded, size: 54, color: QC.lime),
          ),
          const SizedBox(height: 20),
          Text("Taomingizni suratga oling", style: display(24), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "Gemini 1.5 Flash Vision taomni aniqlab, uning grammlari, kaloriyasi va makronutrientlarini hisoblab beradi.",
            textAlign: TextAlign.center,
            style: body(14, color: QC.textSoft, height: 1.4),
          ),
          const SizedBox(height: 32),
          LimeButton(
            label: "Kamerada suratga olish",
            icon: Icons.camera_alt_rounded,
            onPressed: () => _pickImage(ImageSource.camera),
          ),
          const SizedBox(height: 12),
          OutlinePill(
            label: "Galereyadan tanlash",
            icon: Icons.photo_library_rounded,
            color: QC.lime,
            onPressed: () => _pickImage(ImageSource.gallery),
          ),
          const SizedBox(height: 20),
          TextButton.icon(
            onPressed: _loadDemoSample,
            icon: const Icon(Icons.lightbulb_outline_rounded, color: QC.muted, size: 18),
            label: Text("Namuna taom bilan sinab ko'rish (Demo)", style: body(13, color: QC.muted)),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Skanerlash kartasi
        Container(
          height: 220,
          decoration: BoxDecoration(
            color: QC.surface,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: QC.lime.withAlpha(120), width: 1.5),
          ),
          child: Stack(alignment: Alignment.center, children: [
            if (_selectedImageBytes != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.memory(_selectedImageBytes!, width: double.infinity, height: 220, fit: BoxFit.cover),
              ),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                color: Colors.black.withAlpha(140),
              ),
            ),
            AnimatedBuilder(
              animation: _scannerPulse,
              builder: (context, _) => Column(mainAxisSize: MainAxisSize.min, children: [
                Transform.scale(
                  scale: 0.9 + _scannerPulse.value * 0.2,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: QC.lime.withAlpha(40),
                      shape: BoxShape.circle,
                      border: Border.all(color: QC.lime, width: 2),
                    ),
                    child: const Icon(Icons.document_scanner_rounded, size: 36, color: QC.lime),
                  ),
                ),
                const SizedBox(height: 14),
                Text("Gemini AI tahlil qilmoqda...", style: display(18, color: QC.lime)),
                const SizedBox(height: 4),
                Text("Ingredientlar va kaloriyalar segmentlanmoqda", style: body(12, color: QC.textSoft)),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 18),
        // Shimmer skeleton kartalari
        _buildSkeletonCard(height: 80),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 110),
        const SizedBox(height: 12),
        _buildSkeletonCard(height: 60),
        const SizedBox(height: 8),
        _buildSkeletonCard(height: 60),
      ]),
    );
  }

  Widget _buildSkeletonCard({required double height}) {
    return AnimatedBuilder(
      animation: _scannerPulse,
      builder: (context, _) => Container(
        height: height,
        decoration: BoxDecoration(
          color: QC.surface.withAlpha((70 + _scannerPulse.value * 50).toInt()),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: QC.glassBorder),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    final r = _result!;
    final totalMacrosWeight = r.totalMacros.proteinG + r.totalMacros.carbsG + r.totalMacros.fatG;
    final pShare = totalMacrosWeight > 0 ? (r.totalMacros.proteinG / totalMacrosWeight) : 0.33;
    final cShare = totalMacrosWeight > 0 ? (r.totalMacros.carbsG / totalMacrosWeight) : 0.33;
    final fShare = totalMacrosWeight > 0 ? (r.totalMacros.fatG / totalMacrosWeight) : 0.33;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      children: [
        if (_selectedImageBytes != null)
          Container(
            height: 180,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: QC.glassBorder),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(_selectedImageBytes!, fit: BoxFit.cover),
          ),
        // Dish Title & Confidence
        Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.dishName, style: display(26, color: QC.text)),
              const SizedBox(height: 2),
              Text("Aniqlangan taom", style: body(13, color: QC.muted)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0x1FD4FF3F),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: QC.lime.withAlpha(100)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.verified_rounded, size: 16, color: QC.lime),
              const SizedBox(width: 4),
              Text("${(r.confidenceScore * 100).round()}% ishonch",
                  style: body(12, color: QC.lime, weight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 16),
        // Total Calories Hero Card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF233610), Color(0xFF131F09)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: QC.lime, width: 1.5),
            boxShadow: const [
              BoxShadow(color: Color(0x33D4FF3F), blurRadius: 30, offset: Offset(0, 8)),
            ],
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("UMUMIY KALORIYA", style: body(12, color: QC.lime, weight: FontWeight.w800).copyWith(letterSpacing: 1.2)),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text("${r.totalCalories}", style: display(52, color: QC.text, height: 1.0)),
                const SizedBox(width: 6),
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text("kcal", style: display(18, color: QC.lime, weight: FontWeight.w600)),
                ),
              ]),
            ]),
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(color: Color(0x2BD4FF3F), shape: BoxShape.circle),
              child: const Icon(Icons.local_fire_department_rounded, size: 36, color: QC.lime),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        // Macronutrients breakdown
        GlassCard(
          radius: 24,
          padding: const EdgeInsets.all(18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text("Makronutrientlar", style: body(14, weight: FontWeight.w700)),
              const Spacer(),
              Text("Jami ${(totalMacrosWeight).toStringAsFixed(0)} g", style: body(12, color: QC.muted)),
            ]),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: SizedBox(
                height: 12,
                child: Row(children: [
                  Expanded(
                    flex: (pShare * 100).round().clamp(1, 99),
                    child: Container(color: QC.lime),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    flex: (cShare * 100).round().clamp(1, 99),
                    child: Container(color: QC.orange),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    flex: (fShare * 100).round().clamp(1, 99),
                    child: Container(color: QC.blueSoft),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildMacroItem("Oqsil (P)", "${r.totalMacros.proteinG} g", QC.lime),
              _buildMacroItem("Uglevod (C)", "${r.totalMacros.carbsG} g", QC.orange),
              _buildMacroItem("Yog' (F)", "${r.totalMacros.fatG} g", QC.blueSoft),
            ]),
          ]),
        ),
        const SizedBox(height: 20),
        // Ingredients Header + Add Button
        Row(children: [
          Expanded(child: SectionHeader("Ingredientlar tarkibi", trailing: "${r.ingredients.length} xil")),
          IconButton(
            tooltip: "Ingredient qo'shish",
            icon: const Icon(Icons.add_circle_outline_rounded, color: QC.lime),
            onPressed: _addIngredientDialog,
          ),
        ]),
        const SizedBox(height: 8),
        Text("Vaznni (g) o'zgartirish uchun qalamcha ustiga bosing:", style: body(12, color: QC.muted)),
        const SizedBox(height: 10),
        // Ingredient list
        ...List.generate(r.ingredients.length, (i) {
          final ing = r.ingredients[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GlassCard(
              radius: 18,
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(ing.name, style: body(15, weight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(
                      "${ing.estimatedWeightG.toStringAsFixed(0)} g  ·  ${ing.calories} kcal  (P: ${ing.proteinG}g, C: ${ing.carbsG}g, F: ${ing.fatG}g)",
                      style: body(12.5, color: QC.textSoft),
                    ),
                  ]),
                ),
                IconButton(
                  tooltip: "Vaznni tahrirlash",
                  icon: const Icon(Icons.edit_outlined, size: 20, color: QC.lime),
                  onPressed: () => _editIngredient(i),
                ),
                IconButton(
                  tooltip: "O'chirish",
                  icon: const Icon(Icons.delete_outline_rounded, size: 20, color: QC.muted),
                  onPressed: () => _deleteIngredient(i),
                ),
              ]),
            ),
          );
        }),
        const SizedBox(height: 16),
        // Action: Scan another dish
        OutlinePill(
          label: "Boshqa taomni skanerlash",
          icon: Icons.camera_alt_outlined,
          color: QC.lime,
          onPressed: () => setState(() => _state = ScannerState.initial),
        ),
      ],
    );
  }

  Widget _buildMacroItem(String label, String value, Color color) {
    return Row(children: [
      Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: body(11, color: QC.muted)),
        Text(value, style: display(14, color: QC.text)),
      ]),
    ]);
  }

  Widget _buildErrorView() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Container(
          width: 80,
          height: 80,
          decoration: const BoxDecoration(color: Color(0x22FF5A4E), shape: BoxShape.circle),
          child: const Icon(Icons.error_outline_rounded, size: 44, color: QC.red),
        ),
        const SizedBox(height: 16),
        Text("Tahlil qilib bo'lmadi", style: display(20, color: QC.red)),
        const SizedBox(height: 8),
        Text(
          _errorMessage.isNotEmpty
              ? _errorMessage
              : "Rasmda ovqat aniqlanmadi yoki server bilan bog'lanishda xatolik yuz berdi.",
          textAlign: TextAlign.center,
          style: body(14, color: QC.textSoft, height: 1.4),
        ),
        const SizedBox(height: 24),
        LimeButton(
          label: "Qayta urinish",
          icon: Icons.replay_rounded,
          onPressed: () => setState(() => _state = ScannerState.initial),
        ),
      ]),
    );
  }
}
