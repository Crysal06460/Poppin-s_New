class FaqItem {
  final String question;
  final String reponse;

  const FaqItem({required this.question, required this.reponse});
}

/// Base de FAQ statique (zéro IA, zéro coût) indexée par chemin de route.
/// Contenu rédigé à partir du code des écrans concernés — à relire et valider
/// avant publication, car affiché directement aux utilisateurs.
const Map<String, List<FaqItem>> aideFaqParEcran = {
  '/repas': [
    FaqItem(
      question: 'Comment ajouter un repas ?',
      reponse:
          "Sélectionnez l'enfant, appuyez sur le bouton d'ajout, puis renseignez l'heure, le moment (petit-déjeuner, midi, goûter, soir) et le type d'alimentation (biberon, allaitement, solide, mixte). Pour un biberon, indiquez aussi la quantité en ml. Validez avec \"AJOUTER\".\n\nÀ savoir : l'heure d'arrivée de l'enfant doit avoir été enregistrée avant de pouvoir ajouter un repas.",
    ),
    FaqItem(
      question: 'Comment modifier un repas déjà enregistré ?',
      reponse:
          "Appuyez sur le repas dans la liste pour ouvrir ses détails, puis sur \"MODIFIER\". Vous pouvez changer l'heure, le moment, le type d'alimentation et les observations.",
    ),
    FaqItem(
      question: 'Comment supprimer un repas ?',
      reponse:
          "Ouvrez le repas, appuyez sur l'icône de suppression (poubelle) en haut de la fenêtre de détails, puis confirmez. Le repas est retiré du journal, du récapitulatif et du fil des parents.",
    ),
  ],
  '/sieste': [
    FaqItem(
      question: 'Comment ajouter une sieste ?',
      reponse:
          "Sélectionnez l'enfant, indiquez l'heure de début de la sieste. La durée se calcule automatiquement une fois l'heure de fin renseignée.",
    ),
    FaqItem(
      question: 'Comment indiquer la qualité du sommeil ?',
      reponse:
          "La qualité du sommeil (Bien dormi, etc.) se renseigne au moment où vous enregistrez l'heure de fin de la sieste, avec un champ observations optionnel.",
    ),
    FaqItem(
      question: 'Comment modifier ou supprimer une sieste ?',
      reponse:
          "Ouvrez la sieste dans la liste : \"MODIFIER\" permet de changer les horaires ou les observations, l'icône de suppression la retire définitivement.",
    ),
  ],
};

/// Questions affichées quand l'écran courant n'a pas encore de FAQ dédiée.
const List<FaqItem> aideFaqParDefaut = [
  FaqItem(
    question: "Comment contacter le support Poppin's ?",
    reponse:
        "Cette aide rapide ne couvre pas encore cet écran. Vous pouvez nous contacter directement depuis l'application pour toute question.",
  ),
];
