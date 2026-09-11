import 'package:flutter/material.dart';
import 'package:chatme/core/theme/chatme_theme.dart';

/// Contacts fictifs partagés (pas de backend d'annuaire pour la démo).
class MockContact {
  final String name;
  final String initials;
  final Color color;
  const MockContact({required this.name, required this.initials, required this.color});
}

const List<MockContact> kMockContacts = [
  MockContact(name: 'Akpédjé Sossou', initials: 'AK', color: ChatMeColors.cDiscussion),
  MockContact(name: 'Sena Houngbo', initials: 'SN', color: ChatMeColors.cAppel),
  MockContact(name: 'Grâce Fofana', initials: 'GR', color: ChatMeColors.cDocuments),
  MockContact(name: "Jezbine's — compte officiel", initials: 'JB', color: ChatMeColors.cReactions),
  MockContact(name: 'Eloi Dossou', initials: 'EL', color: ChatMeColors.cPortefeuille),
];

/// Catalogue des mini-programmes (Services).
class MockServiceItem {
  final String title;
  final int price; // 0 = gratuit / action simulée
  final String? note;
  const MockServiceItem({required this.title, required this.price, this.note});
}

class MockService {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final List<MockServiceItem> items;
  const MockService({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.items,
  });
}

const List<MockService> kServices = [
  MockService(
    id: 'taxi',
    label: 'Taxi',
    icon: Icons.local_taxi,
    color: ChatMeColors.cAppel,
    items: [
      MockServiceItem(title: 'Course centre-ville', price: 1500, note: 'Estimation 2,4 km'),
      MockServiceItem(title: 'Course aéroport', price: 6500, note: 'Estimation 12 km'),
      MockServiceItem(title: 'Course Dantokpa', price: 2200, note: 'Estimation 4 km'),
    ],
  ),
  MockService(
    id: 'boutique',
    label: 'Boutique',
    icon: Icons.shopping_bag,
    color: ChatMeColors.cPortefeuille,
    items: [
      MockServiceItem(title: 'Crédit téléphonique', price: 1000),
      MockServiceItem(title: 'Forfait data 2Go', price: 2000),
      MockServiceItem(title: 'Carte cadeau', price: 5000),
    ],
  ),
  MockService(
    id: 'factures',
    label: 'Factures',
    icon: Icons.receipt_long,
    color: ChatMeColors.cDocuments,
    items: [
      MockServiceItem(title: 'Électricité SODECI', price: 7800),
      MockServiceItem(title: 'Eau SODEAU', price: 3200),
      MockServiceItem(title: 'Internet', price: 11500),
    ],
  ),
  MockService(
    id: 'livraison',
    label: 'Livraison',
    icon: Icons.restaurant,
    color: ChatMeColors.cReactions,
    items: [
      MockServiceItem(title: 'Repas restaurant', price: 3500),
      MockServiceItem(title: 'Courses alimentaires', price: 4500),
      MockServiceItem(title: 'Pharmacie', price: 2100),
    ],
  ),
  MockService(
    id: 'demarches',
    label: 'Démarches',
    icon: Icons.account_balance,
    color: ChatMeColors.cProfil,
    items: [
      MockServiceItem(title: 'Extrait de naissance', price: 0, note: 'Téléchargement gratuit'),
      MockServiceItem(title: 'Certificat de résidence', price: 0, note: 'Téléchargement gratuit'),
      MockServiceItem(title: 'Renouvellement CNI', price: 1500),
    ],
  ),
  MockService(
    id: 'plus',
    label: 'Plus',
    icon: Icons.add,
    color: ChatMeColors.violet,
    items: [
      MockServiceItem(title: 'Transfert international', price: 0, note: 'Bientôt disponible'),
      MockServiceItem(title: 'Épargne', price: 0, note: 'Bientôt disponible'),
      MockServiceItem(title: 'Assurance', price: 0, note: 'Bientôt disponible'),
    ],
  ),
];

MockService? findService(String id) => kServices.where((s) => s.id == id).firstOrNull;
