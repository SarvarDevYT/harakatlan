import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../game/game_state.dart';
import '../theme.dart';
import 'common.dart';

const List<String> uzbekistanRegions = [
  'Toshkent shahri',
  'Toshkent viloyati',
  'Samarqand viloyati',
  'Buxoro viloyati',
  'Farg\'ona viloyati',
  'Andijon viloyati',
  'Namangan viloyati',
  'Qashqadaryo viloyati',
  'Surxondaryo viloyati',
  'Xorazm viloyati',
  'Jizzax viloyati',
  'Navoiy viloyati',
  'Sirdaryo viloyati',
  'Qoraqalpog\'iston Respublikasi',
];

Future<void> showRegionSelector(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _RegionSelectorSheet(),
  );
}

class _RegionSelectorSheet extends StatefulWidget {
  const _RegionSelectorSheet();

  @override
  State<_RegionSelectorSheet> createState() => _RegionSelectorSheetState();
}

class _RegionSelectorSheetState extends State<_RegionSelectorSheet> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final g = context.watch<GameState>();
    final currentLeague = g.league;
    final filtered = uzbekistanRegions.where((r) {
      if (_search.isEmpty) return true;
      return r.toLowerCase().contains(_search.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: QC.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: QC.glassBorder, width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(color: QC.outline, borderRadius: BorderRadius.circular(99)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hududingizni tanlang', style: display(22)),
                      const SizedBox(height: 3),
                      Text("O'z viloyatingiz ligasida g'alaba qozoning", style: body(13, color: QC.muted)),
                    ],
                  ),
                ),
                RoundIconButton(
                  icon: Icons.close_rounded,
                  tooltip: 'Yopish',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: TextField(
              onChanged: (v) => setState(() => _search = v.trim()),
              style: body(15),
              decoration: InputDecoration(
                hintText: "Viloyat yoki shaharni qidirish...",
                prefixIcon: const Icon(Icons.search_rounded, color: QC.muted),
                filled: true,
                fillColor: QC.surface2,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              itemCount: filtered.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final region = filtered[i];
                final isSelected = region.toLowerCase() == currentLeague.toLowerCase();

                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () {
                      context.read<GameState>().changeLeague(region);
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("$region ligasiga o'tdingiz!")),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? QC.lime.withAlpha(25) : QC.surface2.withAlpha(140),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected ? QC.lime : QC.glassBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: isSelected ? QC.lime : QC.surface,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.location_on_rounded,
                              size: 20,
                              color: isSelected ? QC.bg : QC.textSoft,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  region,
                                  style: display(
                                    16,
                                    weight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? QC.lime : QC.text,
                                  ),
                                ),
                                Text(
                                  "$region ligasi · Bellashuv faol",
                                  style: body(12, color: QC.muted),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: QC.lime,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                'Faol',
                                style: body(11, color: QC.bg, weight: FontWeight.w700),
                              ),
                            )
                          else
                            const Icon(Icons.chevron_right_rounded, color: QC.muted, size: 20),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
