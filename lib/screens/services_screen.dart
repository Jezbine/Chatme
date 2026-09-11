import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/chat_header.dart';
import '../../core/services/service_catalog.dart';
import 'service_detail_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late List<Service> ordered;
  bool isEditMode = false;

  // Disposition choisie par l'utilisateur : ex 3x4, 2x3, 3x3, 4x4 ...
  int columns = 3;
  int rows = 4;
  Set<String> visibleIds = {};

  static const Map<String, List<int>> kLayoutPresets = {
    '2×3': [2, 3],
    '3×3': [3, 3],
    '3×4': [3, 4],
    '4×3': [4, 3],
    '4×4': [4, 4],
    '2×4': [2, 4],
  };

  @override
  void initState() {
    super.initState();
    ordered = List.from(kServiceCatalog);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // ordre
      final savedOrder = prefs.getStringList('services_order');
      if (savedOrder != null && savedOrder.isNotEmpty) {
        final map = {for (var s in kServiceCatalog) s.id: s};
        final sorted = <Service>[];
        for (final id in savedOrder) {
          if (map.containsKey(id)) sorted.add(map[id]!);
        }
        for (final s in kServiceCatalog) {
          if (!savedOrder.contains(s.id)) sorted.add(s);
        }
        if (sorted.length == kServiceCatalog.length) ordered = sorted;
      }
      // layout
      final layout = prefs.getString('services_layout');
      if (layout != null && kLayoutPresets.containsKey(layout)) {
        columns = kLayoutPresets[layout]![0];
        rows = kLayoutPresets[layout]![1];
      }
      // visibles
      final vis = prefs.getStringList('services_visible_ids');
      if (vis != null && vis.isNotEmpty) {
        visibleIds = vis.toSet();
      } else {
        // par défaut : tout visible si capacité >= total, sinon premiers N
        visibleIds = ordered.map((e) => e.id).toSet();
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('services_order', ordered.map((e) => e.id).toList());
  }

  Future<void> _saveLayout(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('services_layout', key);
  }

  Future<void> _saveVisible() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('services_visible_ids', visibleIds.toList());
  }

  int get capacity => columns * rows;
  List<Service> get visibleOrdered {
    // ordre respecté, filtré par visibleIds
    var list = ordered.where((s) => visibleIds.contains(s.id)).toList();
    // si visibleIds vide ou incomplet (première fois), prendre par capacité
    if (list.isEmpty) {
      list = ordered.take(capacity).toList();
      visibleIds = list.map((e) => e.id).toSet();
    }
    return list;
  }

  bool get hasOverflow => ordered.length > visibleOrdered.length;

  List<dynamic> get displayTiles {
    // dynamic = Service ou String '__plus'
    final vis = visibleOrdered;
    if (hasOverflow) {
      // réserve 1 case pour le bouton Plus/Personnaliser
      final shown = vis.take(capacity - 1).toList();
      return [...shown, '__plus'];
    }
    // si tout rentre, afficher vis limité à capacity
    return vis.take(capacity).toList();
  }

  void _resetOrder() async {
    setState(() {
      ordered = List.from(kServiceCatalog);
      visibleIds = ordered.map((e) => e.id).toSet();
      columns = 3;
      rows = 4;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('services_order');
    await prefs.remove('services_visible_ids');
    await prefs.remove('services_layout');
    Get.snackbar('Organisation réinitialisée', 'Disposition 3×4 et tous les services restaurés',
        snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
  }

  void _showLayoutPicker() {
    final cs = Theme.of(context).colorScheme;
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Choisir la disposition', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black)),
              const SizedBox(height: 4),
              Text('Nombre de colonnes × lignes affichées', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: kLayoutPresets.entries.map((e) {
                  final isSelected = columns == e.value[0] && rows == e.value[1];
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        columns = e.value[0];
                        rows = e.value[1];
                      });
                      _saveLayout(e.key);
                      Get.back();
                      Get.snackbar('Disposition', 'Passé en ${e.key} (${e.value[0] * e.value[1]} services max)',
                          snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
                    },
                    child: Container(
                      width: 90,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected ? cs.primary : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? cs.primary : Colors.grey.shade300),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.grid_view, color: isSelected ? Colors.white : cs.primary, size: 20),
                          const SizedBox(height: 6),
                          Text(e.key, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isSelected ? Colors.white : Colors.black)),
                          Text('${e.value[0] * e.value[1]} cases', style: TextStyle(fontSize: 10, color: isSelected ? Colors.white70 : Colors.grey)),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPersonalizeSheet() {
    final cs = Theme.of(context).colorScheme;
    // copie éditable
    Set<String> tempVisible = Set.from(visibleIds);
    // si vide, init à tout
    if (tempVisible.isEmpty) tempVisible = ordered.map((e) => e.id).toSet();

    Get.bottomSheet(
      StatefulBuilder(
        builder: (context, setSheetState) {
          final hiddenCount = ordered.length - tempVisible.length;
          return Container(
            height: MediaQuery.of(context).size.height * 0.82,
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SafeArea(
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        const Expanded(child: Text('Personnaliser les services', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black))),
                        TextButton(onPressed: () => Get.back(), child: const Text('Fermer', style: TextStyle(color: Colors.black))),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text('Choisissez quels services afficher directement. Les autres seront accessibles via “Plus”. Disposition actuelle : $columns×$rows = $capacity cases.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text('$hiddenCount masqués', style: TextStyle(fontSize: 11, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        TextButton(
                          onPressed: () {
                            setSheetState(() => tempVisible = ordered.map((e) => e.id).toSet());
                          },
                          child: const Text('Tout afficher', style: TextStyle(fontSize: 12, color: Colors.black)),
                        ),
                        TextButton(
                          onPressed: () {
                            // garder seulement capacity-1 pour forcer Plus
                            final keep = ordered.take(capacity - 1).map((e) => e.id).toSet();
                            setSheetState(() => tempVisible = keep);
                          },
                          child: Text('Garder ${capacity - 1}', style: const TextStyle(fontSize: 12, color: Colors.black)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      itemCount: ordered.length,
                      // ignore: deprecated_member_use
                      onReorder: (oldIdx, newIdx) {
                        setSheetState(() {
                          if (newIdx > oldIdx) newIdx -= 1;
                          final item = ordered.removeAt(oldIdx);
                          ordered.insert(newIdx, item);
                        });
                        _saveOrder();
                      },
                      itemBuilder: (context, idx) {
                        final s = ordered[idx];
                        final isVisible = tempVisible.contains(s.id);
                        return Container(
                          key: ValueKey(s.id),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            color: isVisible ? Colors.white : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isVisible ? cs.primary.withValues(alpha: 0.3) : Colors.grey.shade200),
                          ),
                          child: CheckboxListTile(
                            value: isVisible,
                            onChanged: (v) {
                              setSheetState(() {
                                if (v == true) {
                                  tempVisible.add(s.id);
                                } else {
                                  // garder au moins 1 visible
                                  if (tempVisible.length > 1) tempVisible.remove(s.id);
                                }
                              });
                            },
                            secondary: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(8)),
                              child: Icon(s.icon, color: Colors.white, size: 18),
                            ),
                            title: Text(s.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black)),
                            subtitle: Text(s.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            activeColor: cs.primary,
                            checkColor: Colors.white,
                            controlAffinity: ListTileControlAffinity.trailing,
                          ),
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: cs.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: () {
                          setState(() => visibleIds = tempVisible);
                          _saveVisible();
                          _saveOrder();
                          Get.back();
                          Get.snackbar('Préférences enregistrées', '${tempVisible.length} services visibles en $columns×$rows',
                              snackPosition: SnackPosition.BOTTOM, backgroundColor: Colors.white, colorText: Colors.black);
                        },
                        child: const Text('Enregistrer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tiles = displayTiles;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const ChatHeader(title: 'Services'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(color: cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.search, color: cs.onSurfaceVariant, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('Rechercher un service', style: TextStyle(color: Colors.grey, fontSize: 13))),
                    GestureDetector(
                      onTap: _showLayoutPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.primary.withValues(alpha: 0.3))),
                        child: Row(children: [
                          const Icon(Icons.grid_view, size: 14, color: Colors.black),
                          const SizedBox(width: 4),
                          Text('$columns×$rows', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.black)),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => setState(() => isEditMode = !isEditMode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: isEditMode ? cs.primary : Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: cs.primary)),
                        child: Row(children: [
                          Icon(isEditMode ? Icons.check : Icons.dashboard_customize, size: 14, color: isEditMode ? Colors.white : cs.primary),
                          const SizedBox(width: 4),
                          Text(isEditMode ? 'Terminer' : 'Organiser', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isEditMode ? Colors.white : cs.primary)),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Icon(Icons.apps, size: 12, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isEditMode ? 'Appui long et glissez pour réorganiser • $columns×$rows' : 'Disposition $columns×$rows • ${tiles.length} affichés • “Plus” pour personnaliser',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                    ),
                  ),
                  GestureDetector(onTap: _showPersonalizeSheet, child: Text('Personnaliser', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cs.primary))),
                  if (isEditMode) ...[
                    const SizedBox(width: 8),
                    GestureDetector(onTap: _resetOrder, child: Text('Réinitialiser', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: cs.primary))),
                  ]
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.78,
                ),
                itemCount: tiles.length,
                itemBuilder: (context, index) {
                  final item = tiles[index];
                  // Tuile spéciale Plus / Personnaliser
                  if (item == '__plus') {
                    final hidden = ordered.length - visibleOrdered.length;
                    return GestureDetector(
                      onTap: _showPersonalizeSheet,
                      child: Container(
                        decoration: BoxDecoration(
                          color: cs.primary,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), borderRadius: BorderRadius.circular(12)),
                              child: const Icon(Icons.apps, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 7),
                            const Text('Plus', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
                            const SizedBox(height: 2),
                            Text('+$hidden', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6)),
                              child: const Text('Personnaliser', style: TextStyle(fontSize: 7, fontWeight: FontWeight.w700, color: Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final s = item as Service;
                  final tile = _ServiceTile(service: s, isDark: isDark, cs: cs, isEditMode: isEditMode);

                  if (isEditMode) {
                    return LongPressDraggable<Service>(
                      data: s,
                      delay: const Duration(milliseconds: 150),
                      feedback: Material(color: Colors.transparent, child: SizedBox(width: 90, height: 90, child: Opacity(opacity: 0.85, child: tile))),
                      childWhenDragging: Opacity(opacity: 0.25, child: tile),
                      child: DragTarget<Service>(
                        onWillAcceptWithDetails: (d) => d.data.id != s.id,
                        onAcceptWithDetails: (d) {
                          final from = ordered.indexWhere((e) => e.id == d.data.id);
                          final to = ordered.indexWhere((e) => e.id == s.id);
                          if (from != -1 && to != -1 && from != to) {
                            setState(() {
                              final it = ordered.removeAt(from);
                              int insertAt = to;
                              ordered.insert(insertAt, it);
                            });
                            _saveOrder();
                          }
                        },
                        builder: (context, cand, rej) {
                          final hover = cand.isNotEmpty;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            decoration: hover ? BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: cs.primary, width: 2)) : null,
                            child: tile,
                          );
                        },
                      ),
                    );
                  }

                  return GestureDetector(onTap: () => Get.to(() => ServiceDetailScreen(service: s)), child: tile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final Service service;
  final bool isDark;
  final ColorScheme cs;
  final bool isEditMode;
  const _ServiceTile({required this.service, required this.isDark, required this.cs, required this.isEditMode});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final tileW = constraints.maxWidth;
      final iconSize = (tileW * 0.32).clamp(28.0, 44.0);
      final iconInner = (iconSize * 0.48).clamp(14.0, 22.0);
      final labelSize = (tileW * 0.11).clamp(9.0, 11.0);
      final descSize = (tileW * 0.07).clamp(6.0, 7.5);
      return Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              color: cs.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.outline, width: isDark ? 1 : 0.5),
              boxShadow: isDark ? null : [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 6, offset: const Offset(0, 2))],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(color: service.color.withValues(alpha: isEditMode ? 0.9 : 0.85), borderRadius: BorderRadius.circular(12)),
                    child: Icon(service.icon, color: Colors.white, size: iconInner),
                  ),
                  const SizedBox(height: 6),
                  Text(service.label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w700, color: cs.onSurface)),
                  const SizedBox(height: 2),
                  Text(service.description, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: TextStyle(fontSize: descSize, color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: isEditMode ? Colors.orange.withValues(alpha: 0.12) : cs.primary.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(6)),
                    child: Text(isEditMode ? 'Glisser' : 'Bientôt', style: TextStyle(fontSize: (descSize * 0.9).clamp(6.0, 7.0), fontWeight: FontWeight.w700, color: isEditMode ? Colors.orange : cs.primary)),
                  ),
                ],
              ),
            ),
          ),
          Positioned(top: 6, right: 6, child: Icon(isEditMode ? Icons.drag_indicator : Icons.lock_clock, size: 13, color: cs.onSurfaceVariant.withValues(alpha: 0.5))),
        ],
      );
    });
  }
}
