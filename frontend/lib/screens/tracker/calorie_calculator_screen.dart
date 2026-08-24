import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/error_utils.dart';

/// Kalkulator dziennego zapotrzebowania kalorycznego — analogicznie do
/// kalkulatora BMI/kalorii NFZ (diety.nfz.gov.pl). Liczy trzy wartości
/// (utrzymanie / redukcja / przyrost wagi) wzorem Mifflin-St Jeor,
/// użytkownik wybiera jedną jako swój cel (kafelek) albo dostraja
/// suwakiem, po czym zapisuje wynik do profilu.
class CalorieCalculatorScreen extends StatefulWidget {
  const CalorieCalculatorScreen({super.key});

  @override
  State<CalorieCalculatorScreen> createState() => _CalorieCalculatorScreenState();
}

class _CalorieCalculatorScreenState extends State<CalorieCalculatorScreen> {
  final AuthService _authService = AuthService();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _gender = 'female';
  String _activityLevel = 'moderate';

  bool _isCalculating = false;
  bool _isSaving = false;
  String? _error;
  Map<String, int>? _result;
  // Wybrana wartość — albo dokładnie jedna z trzech (kafelek), albo
  // dowolna wartość ustawiona suwakiem pomiędzy nimi.
  double? _selectedGoal;

  static const List<Map<String, String>> _activityOptions = [
    {'value': 'sedentary', 'label': 'Siedzący tryb życia', 'desc': 'Mało lub brak ćwiczeń'},
    {'value': 'light', 'label': 'Lekka aktywność', 'desc': 'Trening 1–3 dni/tydzień'},
    {'value': 'moderate', 'label': 'Umiarkowana aktywność', 'desc': 'Trening 3–5 dni/tydzień'},
    {'value': 'active', 'label': 'Duża aktywność', 'desc': 'Trening 6–7 dni/tydzień'},
    {'value': 'very_active', 'label': 'Bardzo duża aktywność', 'desc': 'Praca fizyczna + codzienny trening'},
  ];

  @override
  void initState() {
    super.initState();
    // Wstępnie wypełnij tym, co użytkownik podał wcześniej (jeśli
    // kiedykolwiek korzystał z kalkulatora) — nie zaczynamy od zera
    // przy każdej wizycie.
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user?.weightKg != null) _weightController.text = user!.weightKg!.toStringAsFixed(0);
    if (user?.heightCm != null) _heightController.text = user!.heightCm!.toStringAsFixed(0);
    if (user?.age != null) _ageController.text = user!.age.toString();
    if (user?.gender != null) _gender = user!.gender!;
    if (user?.activityLevel != null) _activityLevel = user!.activityLevel!;
  }

  @override
  void dispose() {
    _weightController.dispose();
    _heightController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    final height = double.tryParse(_heightController.text.replaceAll(',', '.'));
    final age = int.tryParse(_ageController.text);

    if (weight == null || height == null || age == null) {
      setState(() => _error = 'Wypełnij wszystkie pola liczbami (waga, wzrost, wiek).');
      return;
    }

    setState(() {
      _isCalculating = true;
      _error = null;
    });

    try {
      final result = await _authService.calculateCalorieNeeds(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: _gender,
        activityLevel: _activityLevel,
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        // Domyślnie zaznacz "utrzymanie" — najbezpieczniejszy, neutralny
        // punkt startowy, użytkownik i tak może zmienić.
        _selectedGoal = result['maintenance']!.toDouble();
        _isCalculating = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyError(e);
        _isCalculating = false;
      });
    }
  }

  Future<void> _saveGoal() async {
    if (_selectedGoal == null) return;
    setState(() => _isSaving = true);
    try {
      final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));
      final height = double.tryParse(_heightController.text.replaceAll(',', '.'));
      final age = int.tryParse(_ageController.text);

      // Przy okazji zapisujemy też dane wejściowe do profilu — dzięki
      // temu przy kolejnej wizycie kalkulator wypełni się sam (patrz
      // initState), a nie tylko sam wybrany cel.
      await Provider.of<AuthProvider>(context, listen: false).updateProfile(
        weightKg: weight,
        heightCm: height,
        age: age,
        gender: _gender,
        activityLevel: _activityLevel,
        dailyKcalGoal: _selectedGoal!.round(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cel zapisany: ${_selectedGoal!.round()} kcal/dzień')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyError(e))),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kalkulator zapotrzebowania kalorycznego')),
      body: SafeArea(
        // UWAGA (naprawa — ten sam błąd co w plan_config_screen.dart i
        // plan_view_screen.dart): przycisk "Oblicz zapotrzebowanie" jest
        // ostatnim elementem przewijanej listy, chroniony tylko sztywnym
        // marginesem — w trybie edge-to-edge to za mało na niektórych
        // telefonach, przycisk częściowo chowa się pod paskiem nawigacji.
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Podaj swoje dane, żeby obliczyć dzienne zapotrzebowanie kaloryczne '
              '(wzór Mifflin-St Jeor — ten sam standard, na którym opiera się '
              'm.in. kalkulator NFZ).',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _weightController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Waga (kg)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Wzrost (cm)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Wiek (lata)'),
            ),
            const SizedBox(height: 16),

            Text('Płeć', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Kobieta')),
                ButtonSegment(value: 'male', label: Text('Mężczyzna')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 20),

            Text('Poziom aktywności fizycznej', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ..._activityOptions.map((opt) {
              final selected = _activityLevel == opt['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => setState(() => _activityLevel = opt['value']!),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? AppTheme.primaryColor.withOpacity(0.12) : AppTheme.surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected ? AppTheme.primaryColor : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: selected ? AppTheme.primaryColor : AppTheme.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(opt['label']!, style: const TextStyle(fontWeight: FontWeight.w600)),
                              Text(opt['desc']!, style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 20),

            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(_error!, style: TextStyle(color: AppTheme.errorColor)),
              ),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isCalculating ? null : _calculate,
                child: _isCalculating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Oblicz zapotrzebowanie'),
              ),
            ),

            if (_result != null) ..._buildResultSection(),
          ],
        ),
        ),
      ),
    );
  }

  List<Widget> _buildResultSection() {
    final loss = _result!['weight_loss']!;
    final maintenance = _result!['maintenance']!;
    final gain = _result!['weight_gain']!;

    return [
      const SizedBox(height: 28),
      Text('Wybierz swój cel', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 4),
      Text(
        'Dotknij kafelek, żeby go wybrać, albo dostrój suwakiem poniżej.',
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _buildGoalTile('Redukcja', loss, Icons.trending_down)),
          const SizedBox(width: 8),
          Expanded(child: _buildGoalTile('Utrzymanie', maintenance, Icons.trending_flat)),
          const SizedBox(width: 8),
          Expanded(child: _buildGoalTile('Przyrost', gain, Icons.trending_up)),
        ],
      ),
      const SizedBox(height: 24),
      Text(
        'Własna wartość: ${_selectedGoal!.round()} kcal/dzień',
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
      Slider(
        value: _selectedGoal!.clamp((loss - 300).toDouble(), (gain + 300).toDouble()),
        min: (loss - 300).toDouble(),
        max: (gain + 300).toDouble(),
        divisions: 60,
        activeColor: AppTheme.primaryColor,
        label: '${_selectedGoal!.round()} kcal',
        onChanged: (v) => setState(() => _selectedGoal = v),
      ),
      const SizedBox(height: 20),
      // Przewidywane zużycie makroskładników dla WYBRANEJ (kafelek albo
      // suwak) ilości kcal — standardowy, zbilansowany podział
      // 25% białko / 30% tłuszcz / 45% węglowodany, przeliczony na gramy
      // (białko i węglowodany: 4 kcal/g, tłuszcz: 9 kcal/g). To
      // orientacyjna wskazówka, nie sztywny wymóg — każdy posiłek
      // logowany w Śledzeniu ma swoje WŁASNE, dokładne wartości.
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              'Orientacyjny podział makroskładników',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroPrediction('Białko', _selectedGoal! * 0.25 / 4, '25%', AppTheme.secondaryColor),
                _buildMacroPrediction('Tłuszcz', _selectedGoal! * 0.30 / 9, '30%', const Color(0xFFE0A62E)),
                _buildMacroPrediction('Węgl.', _selectedGoal! * 0.45 / 4, '45%', const Color(0xFF3B82F6)),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _isSaving ? null : _saveGoal,
          style: FilledButton.styleFrom(backgroundColor: AppTheme.primaryColor),
          child: _isSaving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Zapisz jako mój cel'),
        ),
      ),
      const SizedBox(height: 8),
    ];
  }

  Widget _buildMacroPrediction(String label, double grams, String percent, Color color) {
    return Column(
      children: [
        Text(
          '${grams.round()}g',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        Text(percent, style: TextStyle(fontSize: 10, color: AppTheme.textSecondary.withOpacity(0.7))),
      ],
    );
  }

  Widget _buildGoalTile(String label, int kcal, IconData icon) {
    final isSelected = _selectedGoal?.round() == kcal;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _selectedGoal = kcal.toDouble()),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : AppTheme.surfaceColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : Colors.transparent, width: 2),
        ),
        child: Column(
          children: [
            Icon(icon, color: isSelected ? Colors.white : AppTheme.textSecondary, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$kcal',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.textPrimary,
              ),
            ),
            Text(
              'kcal',
              style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
