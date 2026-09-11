import 'package:flutter/material.dart';
import 'package:chatme/core/theme/chatme_theme.dart';

/// Catalogue des mini-programmes (Services) - Catalogue officiel ChatMe
/// Disposition recommandée : 3 colonnes x 4 lignes = 12 services
/// Pour changer la disposition, modifiez crossAxisCount dans ServicesScreen
/// ex: 3 => 3x4, 4 => 4x3
class ServiceItem {
  final String title;
  final int price; // 0 = gratuit / action simulée
  final String? note;
  const ServiceItem({required this.title, required this.price, this.note});
}

class Service {
  final String id;
  final String label;
  final IconData icon;
  final Color color;
  final String description;
  final List<ServiceItem> items;
  const Service({
    required this.id,
    required this.label,
    required this.icon,
    required this.color,
    required this.description,
    required this.items,
  });
}

const List<Service> kServiceCatalog = [
  Service(
    id: 'taxi',
    label: 'Taxi',
    icon: Icons.local_taxi,
    color: ChatMeColors.cAppel,
    description: 'Réservez un taxi à Cotonou et environs. Courses estimées, suivi en temps réel et paiement via portefeuille.',
    items: [
      ServiceItem(title: 'Course centre-ville', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Course aéroport', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Course Dantokpa', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'boutique',
    label: 'Boutique',
    icon: Icons.shopping_bag,
    color: ChatMeColors.cPortefeuille,
    description: 'Achetez crédit téléphonique, forfaits data et cartes cadeaux directement depuis ChatMe.',
    items: [
      ServiceItem(title: 'Crédit téléphonique', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Forfait data 2Go', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Carte cadeau', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'factures',
    label: 'Factures',
    icon: Icons.receipt_long,
    color: ChatMeColors.cDocuments,
    description: 'Payez vos factures SBEE, SONEB et internet en un clic, avec historique et reçus automatiques.',
    items: [
      ServiceItem(title: 'Électricité SBEE', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Eau SONEB', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Internet', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'livraison',
    label: 'Livraison',
    icon: Icons.restaurant,
    color: ChatMeColors.cReactions,
    description: 'Commandez repas, courses alimentaires et produits pharmaceutiques avec livraison rapide.',
    items: [
      ServiceItem(title: 'Repas restaurant', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Courses alimentaires', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Pharmacie', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'demarches',
    label: 'Démarches',
    icon: Icons.account_balance,
    color: ChatMeColors.cProfil,
    description: 'Effectuez vos démarches administratives : extraits de naissance, certificats et CNI.',
    items: [
      ServiceItem(title: 'Extrait de naissance', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Certificat de résidence', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Renouvellement CNI', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'sante',
    label: 'Santé',
    icon: Icons.local_hospital,
    color: Color(0xFFE53935),
    description: 'Prenez rendez-vous, téléconsultez et commandez vos médicaments auprès de professionnels proches.',
    items: [
      ServiceItem(title: 'Téléconsultation', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Rendez-vous hôpital', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Commande pharmacie', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'education',
    label: 'Éducation',
    icon: Icons.school,
    color: Color(0xFF1E88E5),
    description: 'Cours, révisions et inscriptions scolaires. Accédez aux formations et concours au Bénin.',
    items: [
      ServiceItem(title: 'Cours en ligne', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Inscription concours', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Bibliothèque', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'immobilier',
    label: 'Immobilier',
    icon: Icons.home_work,
    color: Color(0xFF43A047),
    description: 'Trouvez maisons, appartements et terrains à louer ou à acheter, avec visites virtuelles.',
    items: [
      ServiceItem(title: 'Location appartement', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Achat terrain', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Location villa', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'emploi',
    label: 'Emploi',
    icon: Icons.work,
    color: Color(0xFFFB8C00),
    description: 'Offres d\'emploi, missions freelance et dépôt de CV. Connectez talents et recruteurs.',
    items: [
      ServiceItem(title: 'Offres locales', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Freelance', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Dépôt CV', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'divertissement',
    label: 'Loisirs',
    icon: Icons.movie,
    color: Color(0xFF8E24AA),
    description: 'Cinéma, événements, concerts et tickets. Réservez vos sorties en quelques secondes.',
    items: [
      ServiceItem(title: 'Cinéma', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Concert', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Événements', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'voyage',
    label: 'Voyage',
    icon: Icons.flight,
    color: Color(0xFF00ACC1),
    description: 'Billets de bus, vols et hôtels. Organisez vos déplacements au Bénin et à l\'international.',
    items: [
      ServiceItem(title: 'Billet de bus', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Vol intérieur', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Réservation hôtel', price: 0, note: 'Bientôt disponible'),
    ],
  ),
  Service(
    id: 'plus',
    label: 'Plus',
    icon: Icons.add,
    color: ChatMeColors.violet,
    description: 'Transfert international, épargne et assurance. Services financiers avancés bientôt disponibles.',
    items: [
      ServiceItem(title: 'Transfert international', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Épargne', price: 0, note: 'Bientôt disponible'),
      ServiceItem(title: 'Assurance', price: 0, note: 'Bientôt disponible'),
    ],
  ),
];

Service? findService(String id) => kServiceCatalog.where((s) => s.id == id).firstOrNull;
