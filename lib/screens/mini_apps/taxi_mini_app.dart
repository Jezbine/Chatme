import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatme/core/theme/chatme_theme.dart';
import 'package:chatme/core/utils/format_utils.dart';
import 'mini_app_frame.dart';

/// Mini-Application VTC Taxi & Moto Zem Bénin.
/// Offre une interface autonome de commande de transport urbain à Cotonou et Calavi.
class TaxiMiniApp extends StatefulWidget {
  const TaxiMiniApp({super.key});

  @override
  State<TaxiMiniApp> createState() => _TaxiMiniAppState();
}

class _TaxiMiniAppState extends State<TaxiMiniApp> {
  String _pickup = 'Aéroport International de Cotonou';
  String _dropoff = 'Haie Vive, Cotonou';
  String _selectedVehicle = 'moto'; // 'moto', 'taxi', 'vip'
  bool _isSearching = false;
  Map<String, dynamic>? _assignedDriver;

  final List<String> _popularPlaces = [
    'Aéroport International de Cotonou',
    'Haie Vive, Cotonou',
    'Cadjehoun (Étoile Rouge)',
    'Grand Marché Dantokpa',
    'Stade Général Mathieu Kérékou (Kouhounou)',
    'Plage Fidjrossè (Route des Pêches)',
    'Ganhi (Quartier Commercial)',
    'Akpakpa (PK3)',
    'Abomey-Calavi (Carrefour Kpota)',
    'Université d\'Abomey-Calavi (UAC)',
  ];

  final Map<String, Map<String, dynamic>> _vehicleTypes = {
    'moto': {
      'name': 'Moto Zem',
      'desc': 'Le plus rapide dans les embouteillages',
      'icon': Icons.two_wheeler,
      'basePrice': 500,
      'multiplier': 1.0,
      'eta': '2 min',
    },
    'taxi': {
      'name': 'Taxi Confort',
      'desc': 'Climatisé, 4 places avec coffre',
      'icon': Icons.local_taxi,
      'basePrice': 2000,
      'multiplier': 2.8,
      'eta': '5 min',
    },
    'vip': {
      'name': 'Berline VIP',
      'desc': 'Véhicule haut de gamme & affaires',
      'icon': Icons.directions_car,
      'basePrice': 5000,
      'multiplier': 5.0,
      'eta': '8 min',
    },
  };

  int get _estimatedPrice {
    final v = _vehicleTypes[_selectedVehicle]!;
    final base = v['basePrice'] as int;
    return base;
  }

  @override
  Widget build(BuildContext context) {
    return MiniAppFrame(
      title: 'ChatMe VTC & Zem 🚖',
      subtitle: 'Transport urbain Cotonou & Environs',
      brandColor: const Color(0xFFE65100),
      body: _assignedDriver != null
          ? _buildDriverTrackingView()
          : _isSearching
              ? _buildSearchingView()
              : _buildBookingView(),
    );
  }

  Widget _buildBookingView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Carte d'itinéraire
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.my_location, color: Colors.green, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _pickup,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Point de départ (Prise en charge)',
                        border: InputBorder.none,
                        labelStyle: TextStyle(fontSize: 12),
                      ),
                      items: _popularPlaces.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _pickup = v!),
                    ),
                  ),
                ],
              ),
              const Divider(),
              Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.red, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _dropoff,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Destination',
                        border: InputBorder.none,
                        labelStyle: TextStyle(fontSize: 12),
                      ),
                      items: _popularPlaces.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _dropoff = v!),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const Text('Choisissez votre type de course :', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),

        // Choix du véhicule
        ..._vehicleTypes.keys.map((key) {
          final isSel = _selectedVehicle == key;
          final v = _vehicleTypes[key]!;
          final price = (v['basePrice'] as int);

          return GestureDetector(
            onTap: () => setState(() => _selectedVehicle = key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isSel ? const Color(0xFFFFF3E0) : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSel ? const Color(0xFFE65100) : Colors.grey.shade300,
                  width: isSel ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: isSel ? const Color(0xFFE65100) : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(v['icon'] as IconData, color: isSel ? Colors.white : Colors.black87, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(v['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                              child: Text(v['eta'] as String, style: TextStyle(color: Colors.green.shade800, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(v['desc'] as String, style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(
                    '${FormatUtils.fmtFcfa(price)} F',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: isSel ? const Color(0xFFE65100) : Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE65100),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            icon: const Icon(Icons.near_me),
            label: Text('Commander ${_vehicleTypes[_selectedVehicle]!['name']} (${FormatUtils.fmtFcfa(_estimatedPrice)} F)', style: const TextStyle(fontWeight: FontWeight.bold)),
            onPressed: _startSearchDriver,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(color: Color(0xFFE65100), strokeWidth: 4),
            ),
            const SizedBox(height: 28),
            const Text('Recherche d\'un chauffeur à proximité...', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Départ : $_pickup', textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: () => setState(() => _isSearching = false),
              child: const Text('Annuler la recherche'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDriverTrackingView() {
    final d = _assignedDriver!;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Chauffeur trouvé ! Il est en route vers vous.', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              ),
              Text(d['eta'] as String, style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.green, fontSize: 16)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE65100),
                    child: Text(d['initials'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(d['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            Text(' ${d['rating']} • 1 420 courses', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                    child: Text(d['plate'] as String, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 1)),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.phone, color: Colors.green),
                    label: const Text('Appeler', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    onPressed: () => Get.snackbar('Appel Chauffeur', 'Connexion sécurisée en cours avec ${d['name']}...'),
                  ),
                  TextButton.icon(
                    icon: const Icon(Icons.message, color: ChatMeColors.violet),
                    label: const Text('Message', style: TextStyle(color: ChatMeColors.violet, fontWeight: FontWeight.bold)),
                    onPressed: () => Get.snackbar('Chat Chauffeur', 'Ouverture du canal de discussion éphémère...'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700, foregroundColor: Colors.white),
            onPressed: () {
              setState(() => _assignedDriver = null);
              Get.snackbar('Course terminée', 'Merci d\'avoir utilisé ChatMe VTC !');
            },
            child: const Text('Terminer la course'),
          ),
        ),
      ],
      ),
    );
  }

  void _startSearchDriver() {
    setState(() => _isSearching = true);
    // Simulation d'attribution après 2.5 secondes
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      final rng = Random();
      final plates = ['AX 4821 RB', 'BD 9102 RB', 'AY 6214 RB', 'BE 7731 RB'];
      final drivers = [
        {'name': 'Koffi ADEBAYO', 'initials': 'KA', 'rating': '4.9', 'plate': plates[rng.nextInt(plates.length)], 'eta': '3 min'},
        {'name': 'Rodrigue MENSAH', 'initials': 'RM', 'rating': '4.8', 'plate': plates[rng.nextInt(plates.length)], 'eta': '4 min'},
        {'name': 'Arnaud HOUNGBEDJI', 'initials': 'AH', 'rating': '5.0', 'plate': plates[rng.nextInt(plates.length)], 'eta': '2 min'},
      ];

      setState(() {
        _isSearching = false;
        _assignedDriver = drivers[rng.nextInt(drivers.length)];
      });
    });
  }
}
