import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../theme.dart';
import '../widgets/common.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _start() {
    final name = _name.text.trim();
    if (name.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ismingizni yozing (kamida 2 harf)')));
      return;
    }
    runWithSpinner(context, () => context.read<GameState>().register(name));
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        const ContourBackground(),
        Positioned(
          top: size.height * 0.08,
          left: 0,
          right: 0,
          child: Bob(
            ms: 2600,
            child: ShaderMask(
              shaderCallback: (r) => const RadialGradient(
                colors: [Colors.black, Colors.transparent],
                stops: [0.6, 0.75],
              ).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Image.asset('assets/images/hero.jpg', height: size.width * 1.02, fit: BoxFit.cover),
            ),
          ),
        ),
        Positioned(
          top: size.height * 0.46,
          left: -60,
          right: -60,
          child: const SizedBox(
            height: 60,
            child: Stack(alignment: Alignment.center, children: [
              Ribbon(text: 'HAR QADAM HISOBLANADI', angle: 0.09, color: QC.text),
              Ribbon(text: 'YUR / QUR / BOSIB OL', angle: -0.1),
            ]),
          ),
        ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight - 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset('assets/images/logo.png', width: 34, height: 34, fit: BoxFit.cover),
                      ),
                      const SizedBox(width: 10),
                      Text("HARAKATLAN", style: display(18, letterSpacing: 1.2)),
                    ]),
                    SizedBox(height: size.height * 0.42),
                    Align(
                      alignment: Alignment.centerRight,
                      child: HandNote("kechqurun qal'ang tayyor!", size: 26),
                    ),
                    Text('YUR.', style: display(76, height: 0.9, letterSpacing: -3)),
                    Text('QUR.',
                        style: display(76, height: 0.9, letterSpacing: -3).copyWith(
                          foreground: Paint()
                            ..style = PaintingStyle.stroke
                            ..strokeWidth = 2
                            ..color = QC.lime,
                        )),
                    Text('BOSIB OL.', style: display(56, color: QC.lime, height: 0.95, letterSpacing: -2)),
                    const SizedBox(height: 22),
                    TextField(
                      controller: _name,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _start(),
                      style: body(16),
                      decoration: const InputDecoration(
                        labelText: 'Ismingiz',
                        hintText: 'Masalan, Jasur',
                      ),
                    ),
                    const SizedBox(height: 12),
                    LimeButton(label: "Ro'yxatdan o'tish", onPressed: _start, glow: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
