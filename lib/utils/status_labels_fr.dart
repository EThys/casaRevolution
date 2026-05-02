/// Libellés de statut en français (réservations, sollicitations).
String frReservationStatus(String? status) {
  switch (status?.toUpperCase().trim()) {
    case 'PENDING':
      return 'En attente';
    case 'CONFIRMED':
    case 'APPROVED':
      return 'Confirmée';
    case 'COMPLETED':
      return 'Terminée';
    case 'CANCELLED':
    case 'CANCELED':
      return 'Annulée';
    default:
      if (status == null || status.isEmpty) return 'Inconnu';
      return status;
  }
}

String frSolicitationStatus(String? status) {
  switch (status?.toUpperCase().trim()) {
    case 'PENDING':
      return 'En attente';
    case 'APPROVED':
    case 'ACCEPTED':
      return 'Acceptée';
    case 'REJECTED':
      return 'Refusée';
    case 'CANCELLED':
    case 'CANCELED':
      return 'Annulée';
    case 'COMPLETED':
      return 'Terminée';
    case 'IN_PROGRESS':
    case 'INPROGRESS':
      return 'En cours';
    default:
      if (status == null || status.isEmpty) return 'En attente';
      return status;
  }
}
