import 'package:flutter/material.dart';
import 'package:chatme/core/theme/chatme_theme.dart';

class SecurityPolicyScreen extends StatelessWidget {
  const SecurityPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ChatMeColors.surface,
      appBar: AppBar(
        backgroundColor: ChatMeColors.surface,
        foregroundColor: ChatMeColors.ink,
        title: const Text('Confidentialité & sécurité'),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: const [
            _Intro(),
            SizedBox(height: 8),
            _Section(
              title: '1. Responsable du traitement',
              body:
                  'ChatMe est une application de messagerie et de services pour le Bénin. '
                  'Le responsable du traitement des données est ChatMe SAS (ci-après « ChatMe »). '
                  'Pour toute question relative à vos données, contactez privacy@chatme.app.',
            ),
            _Section(
              title: '2. Données collectées',
              body:
                  'Nous collectons : le numéro de téléphone et/ou l\'adresse email (authentification), '
                  'le nom d\'affichage et la bio (profil), les messages, appels, statuts et Moments que '
                  'vous publiez, les contacts que vous choisissez de synchroniser, les transactions de '
                  'portefeuille, et les données techniques (modèle d\'appareil, version, identifiants de '
                  'notification push). Les données biométriques (empreinte / visage) restent sur '
                  'l\'appareil et ne sont jamais envoyées à ChatMe.',
            ),
            _Section(
              title: '3. Finalités',
              body:
                  'Fournir le service de messagerie, les appels, le portefeuille, les statuts et Moments, '
                  'la sécurisation du compte, la prévention de la fraude, et l\'amélioration du service. '
                  'Vos données ne sont pas vendues à des tiers.',
            ),
            _Section(
              title: '4. Partage et transferts',
              body:
                  'Vos messages ne sont visibles que par les destinataires que vous choisissez. Nous '
                  'pouvons partager des données avec des prestataires indispensables (hébergement, '
                  'passerelles de paiement, services de notification) strictement nécessaires au service, '
                  'sous contrat de confidentialité. Aucun transfert hors de l\'espace économique prévu '
                  'sans base légale.',
            ),
            _Section(
              title: '5. Sécurité de l\'application',
              body:
                  '• Chiffrement de bout en bout des conversations lorsque la fonction est activée.\n'
                  '• Verrouillage de l\'application par code confidentiel à 4 chiffres.\n'
                  '• Déverrouillage biométrique (empreinte digitale ou reconnaissance faciale) lorsque '
                  'l\'appareil le prend en charge.\n'
                  '• Authentification à deux facteurs et alertes de connexion.\n'
                  '• Les données biométriques ne quittent jamais votre téléphone : elles sont gérées par '
                  'le système sécurisé de l\'appareil (Android Keystore / iOS Secure Enclave).\n'
                  '• Paiements protégés par un code ou une empreinte, avec alertes de transaction.',
            ),
            _Section(
              title: '6. Conservation',
              body:
                  'Les messages sont conservés le temps nécessaire au service et supprimés sur demande '
                  'ou après suppression du compte. Les statuts expirent automatiquement (durée choisie '
                  'par l\'utilisateur, modifiables 15 min, supprimables à tout moment).',
            ),
            _Section(
              title: '7. Vos droits',
              body:
                  'Conformément aux lois applicables (RGPD et législation béninoise), vous disposez d\'un '
                  'droit d\'accès, de rectification, d\'effacement, de limitation et d\'opposition. Pour '
                  'exercer ces droits, écrivez à privacy@chatme.app depuis l\'adresse associée à votre compte.',
            ),
            _Section(
              title: '8. Mineurs',
              body:
                  'Le service est destiné aux personnes âgées d\'au moins 15 ans. Les comptes de mineurs '
                  'sont soumis à l\'accord d\'un titulaire de l\'autorité parentale.',
            ),
            _Section(
              title: '9. Modifications',
              body:
                  'Cette politique peut être mise à jour. Vous serez informé des changements importants '
                  'directement dans l\'application.',
            ),
            SizedBox(height: 16),
            Text(
              'Dernière mise à jour : août 2026.',
              style: TextStyle(fontSize: 12, color: ChatMeColors.inkSoft),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ChatMeColors.violetPale,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: ChatMeColors.violet, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Chez ChatMe, votre vie privée est essentielle. Ce résumé explique comment '
              'vos données sont protégées et utilisées.',
              style: TextStyle(fontSize: 13, color: ChatMeColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final String body;
  const _Section({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: ChatMeColors.ink)),
          const SizedBox(height: 6),
          Text(body,
              style: const TextStyle(fontSize: 13.5, color: ChatMeColors.inkSoft, height: 1.5)),
        ],
      ),
    );
  }
}
