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
  '/horaires': [
    FaqItem(
      question: 'Comment enregistrer une arrivée ou un départ ?',
      reponse:
          "Appuyez directement sur le créneau \"Arrivée\" ou \"Départ\" vide de l'enfant : l'heure actuelle est enregistrée immédiatement. Pour un départ, on vous demande ensuite les kilomètres parcourus dans la journée (facultatif, laissez vide si aucun trajet).",
    ),
    FaqItem(
      question: 'Comment corriger une heure déjà enregistrée ?',
      reponse:
          "Appuyez sur l'horaire déjà enregistré : un menu propose \"Modifier l'heure\" (au format HH:MM) ou \"Supprimer l'horaire\", avec confirmation.",
    ),
    FaqItem(
      question: 'Comment marquer un enfant absent ?',
      reponse:
          "Utilisez le bouton \"Marquer absent\" : l'arrivée et le départ du jour sont réinitialisés. Vous pouvez annuler l'absence à tout moment, et enregistrer une nouvelle arrivée retire automatiquement le statut \"absent\".",
    ),
  ],
  '/activites': [
    FaqItem(
      question: "Pourquoi je ne peux pas ajouter d'activité ?",
      reponse:
          "L'heure d'arrivée de l'enfant doit d'abord être enregistrée dans l'écran Horaires — un message \"Arrivée requise\" s'affiche sinon.",
    ),
    FaqItem(
      question: 'Comment ajouter une activité ?',
      reponse:
          "Renseignez l'heure, le type d'activité (liste déroulante ou activité personnalisée), l'attitude de l'enfant et son niveau de participation (Pas/Peu/Bien/Très bien participé), puis ajoutez une observation si besoin.",
    ),
    FaqItem(
      question: 'Comment créer une activité personnalisée ?',
      reponse:
          "Dans la liste déroulante des types d'activité, choisissez \"Ajouter une activité personnalisée\" (nom limité à 3 mots).",
    ),
  ],
  '/sante': [
    FaqItem(
      question: 'Comment ajouter un soin ou une mesure ?',
      reponse:
          "Comme pour les activités, l'enfant doit avoir une arrivée enregistrée aujourd'hui. Choisissez ensuite le type : Température (valeur + voie de prise), Poids, Médicaments ou Autre (observation).",
    ),
    FaqItem(
      question: "Le poids saisi ici met-il à jour la fiche de l'enfant ?",
      reponse:
          "Oui : dès que vous enregistrez ou modifiez un soin de type \"Poids\", la valeur est automatiquement reportée sur le profil de l'enfant.",
    ),
    FaqItem(
      question: 'Comment modifier ou supprimer un soin ?',
      reponse:
          "Ouvrez le soin dans la liste : \"Modifier\" reprend les mêmes champs, ou supprimez-le directement avec confirmation.",
    ),
  ],
  '/change': [
    FaqItem(
      question: 'Comment enregistrer un change ?',
      reponse:
          "Renseignez l'heure, puis au moins une information parmi : type de change (Couche/Pot/Toilette), Pipi/Selles, ou soins complémentaires (Nez/Yeux/Oreilles/Crème) — sans au moins un de ces éléments, l'ajout est bloqué.",
    ),
    FaqItem(
      question: 'Comment modifier ou supprimer un change ?',
      reponse:
          "Ouvrez le change dans la liste : \"Modifier\" permet de tout reprendre, ou supprimez-le avec confirmation.",
    ),
    FaqItem(
      question: "Puis-je enregistrer un change pour un autre jour qu'aujourd'hui ?",
      reponse:
          "Oui : changez d'abord la date en haut de l'écran, à condition que l'enfant ait bien une arrivée enregistrée ce jour-là.",
    ),
  ],
  '/photos': [
    FaqItem(
      question: 'Comment envoyer une photo ou une vidéo ?',
      reponse:
          "Appuyez sur le bouton d'ajout, renseignez l'heure, puis choisissez la source : photo (caméra ou galerie, plusieurs photos possibles) ou vidéo (caméra ou galerie). Un aperçu s'affiche avant l'envoi.",
    ),
    FaqItem(
      question: 'Y a-t-il une limite pour les vidéos ?',
      reponse:
          "Les vidéos filmées depuis l'app sont limitées à 15 secondes et 200 Mo. Vous ne pouvez pas mélanger photos et vidéo dans le même envoi.",
    ),
    FaqItem(
      question: 'Comment supprimer une photo envoyée par erreur ?',
      reponse:
          "Une fois envoyée, une photo ou vidéo ne peut plus être modifiée, seulement supprimée (bouton de suppression avec confirmation).",
    ),
  ],
  '/agenda': [
    FaqItem(
      question: 'Comment ajouter un rappel ?',
      reponse:
          "Appuyez sur \"Nouvelle entrée\", renseignez un titre (obligatoire), des notes éventuelles, la date et l'heure. En MAM, vous pouvez activer \"Partager avec toute la MAM\".",
    ),
    FaqItem(
      question: 'Comment modifier ou supprimer un rappel ?',
      reponse:
          "Appuyez sur la carte du rappel pour rouvrir le formulaire pré-rempli, ou utilisez directement le bouton de suppression sur la carte.",
    ),
    FaqItem(
      question: "Suis-je prévenue avant l'échéance ?",
      reponse:
          "Oui, une notification de rappel est programmée automatiquement à la création et annulée si vous supprimez l'entrée. La couleur de la carte indique l'urgence (rouge = en retard, cyan = aujourd'hui, jaune = demain).",
    ),
  ],
  '/stock': [
    FaqItem(
      question: 'Comment signaler qu\'un produit manque pour un enfant ?',
      reponse:
          "Appuyez sur le \"+\" de la carte de l'enfant, cochez les produits manquants dans les catégories proposées (Hygiène, Alimentation, Santé...) puis validez.",
    ),
    FaqItem(
      question: "Comment ajouter un produit qui n'est pas dans la liste ?",
      reponse:
          "Utilisez \"Gérer les produits personnalisés\" pour créer un nouvel article — il sera disponible pour tous les enfants de la structure.",
    ),
    FaqItem(
      question: 'Comment retirer un besoin une fois le produit racheté ?',
      reponse:
          "Touchez le badge du produit affiché sous le nom de l'enfant et confirmez pour le décocher.",
    ),
  ],
  '/recap-enfant': [
    FaqItem(
      question: 'Puis-je modifier une information depuis cet écran ?',
      reponse:
          "Non, le récapitulatif est en lecture seule : il rassemble automatiquement les données déjà saisies ailleurs (repas, activités, sieste, change, santé, horaires, photos, transmissions). Pour corriger une information, retournez sur l'écran correspondant.",
    ),
    FaqItem(
      question: "Pourquoi un enfant n'apparaît pas dans le récap du jour ?",
      reponse:
          "Un enfant marqué absent ou non prévu au planning ce jour-là n'apparaît pas dans le récap, même si des données existent pour lui.",
    ),
    FaqItem(
      question: "Comment voir le récap d'un autre jour ?",
      reponse: "Utilisez le sélecteur de date en haut de l'écran.",
    ),
  ],
  '/actualites': [
    FaqItem(
      question: 'Comment ajouter un événement ou une sortie ?',
      reponse:
          "Utilisez le bouton \"+\" dans l'onglet correspondant (Événements ou Sorties). Le titre est obligatoire, ainsi que le lieu pour une sortie ; la date ne peut pas être dans le passé.",
    ),
    FaqItem(
      question: 'Comment renseigner le menu de la semaine ?',
      reponse:
          "Depuis \"Modifier\", saisissez les plats de chaque jour (du lundi au vendredi, avec un week-end dépliable). Attention : le menu se réinitialise automatiquement chaque lundi, pensez à le ressaisir.",
    ),
    FaqItem(
      question: 'Comment supprimer un événement ?',
      reponse:
          "Utilisez l'icône de suppression sur l'événement concerné, avec confirmation.",
    ),
  ],
  '/transmissions': [
    FaqItem(
      question: 'Comment envoyer une transmission aux parents ?',
      reponse:
          "Appuyez sur le \"+\" de la carte de l'enfant, choisissez la catégorie (Santé ou Autre) et rédigez votre message, puis validez.",
    ),
    FaqItem(
      question: 'Puis-je envoyer la même transmission à plusieurs enfants ?',
      reponse:
          "Oui, utilisez la transmission groupée pour sélectionner plusieurs enfants en une seule fois.",
    ),
    FaqItem(
      question: 'Comment modifier ou supprimer une transmission déjà envoyée ?',
      reponse:
          "Chaque transmission affiche une icône crayon (modifier) et une icône poubelle (supprimer avec confirmation).",
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
