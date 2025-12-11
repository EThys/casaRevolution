import '../models/ServiceModel.dart';

class StaticServicesData {
  // Données statiques pour les services par catégorie
  static List<ServiceModel> getStaticServices() {
    return [
      // PLOMBIER
      ServiceModel()
        ..serviceId = 1
        ..title = "Plombier professionnel - Réparation urgente"
        ..description = "Plombier expérimenté disponible 24/7 pour toutes vos urgences. Réparation de fuites, installation de robinets, réparation de chauffe-eau, débouchage de canalisations. Intervention rapide dans toute la ville de Kinshasa."
        ..serviceType = ServiceType.plomberie
        ..price = 25000.0
        ..priceUnit = "Par intervention"
        ..address = "Gombe, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Gombe"
        ..phone = "+243900000001"
        ..whatsapp = "+243900000001"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        ..availableHours = "07:00-20:00"
        ..experienceYears = 8
        ..rating = 4.8
        ..reviewCount = 45
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=800",
          "https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800",
        ],

      ServiceModel()
        ..serviceId = 2
        ..title = "Installation sanitaire complète"
        ..description = "Installation complète de systèmes sanitaires pour maisons et appartements. Installation de douches, WC, éviers, chauffe-eau. Travaux garantis et conformes aux normes."
        ..serviceType = ServiceType.plomberie
        ..price = 150000.0
        ..priceUnit = "Par projet"
        ..address = "Lingwala, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Lingwala"
        ..phone = "+243900000002"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi"]
        ..availableHours = "08:00-18:00"
        ..experienceYears = 12
        ..rating = 4.9
        ..reviewCount = 78
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1607472586893-edb57bdc0e39?w=800",
        ],

      // ÉLECTRICIEN
      ServiceModel()
        ..serviceId = 3
        ..title = "Électricien certifié - Installation électrique"
        ..description = "Électricien professionnel pour installation, réparation et maintenance électrique. Installation de tableaux électriques, prises, éclairages, climatisation. Service rapide et sécurisé."
        ..serviceType = ServiceType.electricite
        ..price = 30000.0
        ..priceUnit = "Par heure"
        ..address = "Ngaliema, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Ngaliema"
        ..phone = "+243900000003"
        ..whatsapp = "+243900000003"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-19:00"
        ..experienceYears = 10
        ..rating = 4.7
        ..reviewCount = 62
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800",
          "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=800",
        ],

      ServiceModel()
        ..serviceId = 4
        ..title = "Dépannage électrique urgent"
        ..description = "Intervention rapide pour pannes électriques, coupures, court-circuits. Réparation de prises, interrupteurs, tableaux électriques. Disponible 24/7 pour urgences."
        ..serviceType = ServiceType.electricite
        ..price = 35000.0
        ..priceUnit = "Par intervention"
        ..address = "Kalamu, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Kalamu"
        ..phone = "+243900000004"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        ..availableHours = "00:00-23:59"
        ..experienceYears = 15
        ..rating = 4.9
        ..reviewCount = 120
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1621905252507-b35492cc74b4?w=800",
        ],

      // PEINTRE
      ServiceModel()
        ..serviceId = 5
        ..title = "Peintre professionnel - Intérieur & Extérieur"
        ..description = "Peinture intérieure et extérieure de qualité. Préparation des surfaces, peinture murale, plafonds, portes, fenêtres. Finition impeccable garantie."
        ..serviceType = ServiceType.peinture
        ..price = 20000.0
        ..priceUnit = "Par m²"
        ..address = "Masina, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Masina"
        ..phone = "+243900000005"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-17:00"
        ..experienceYears = 7
        ..rating = 4.6
        ..reviewCount = 38
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800",
          "https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800",
        ],

      ServiceModel()
        ..serviceId = 6
        ..title = "Décoration murale et fresques"
        ..description = "Artiste peintre spécialisé en décoration murale, fresques et peintures artistiques. Création de designs uniques pour votre intérieur ou extérieur."
        ..serviceType = ServiceType.peinture
        ..price = 50000.0
        ..priceUnit = "Par projet"
        ..address = "Bandundu, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Bandundu"
        ..phone = "+243900000006"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi"]
        ..availableHours = "09:00-18:00"
        ..experienceYears = 5
        ..rating = 4.8
        ..reviewCount = 25
        ..isVerified = false
        ..images = [
          "https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800",
        ],

      // CARRELEUR
      ServiceModel()
        ..serviceId = 7
        ..title = "Carreleur expert - Carrelage de qualité"
        ..description = "Pose de carrelage pour sols et murs. Salles de bain, cuisines, salons. Carrelage céramique, grès, faïence. Travaux soignés et durables."
        ..serviceType = ServiceType.carrelage
        ..price = 25000.0
        ..priceUnit = "Par m²"
        ..address = "Lemba, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Lemba"
        ..phone = "+243900000007"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-18:00"
        ..experienceYears = 9
        ..rating = 4.7
        ..reviewCount = 52
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
        ],

      // FRIGORISTE / CLIMATISATION
      ServiceModel()
        ..serviceId = 8
        ..title = "Installation et réparation climatisation"
        ..description = "Installation, réparation et maintenance de climatiseurs. Nettoyage, recharge de gaz, dépannage. Toutes marques. Service rapide et professionnel."
        ..serviceType = ServiceType.climatisation
        ..price = 40000.0
        ..priceUnit = "Par intervention"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000008"
        ..whatsapp = "+243900000008"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-19:00"
        ..experienceYears = 11
        ..rating = 4.8
        ..reviewCount = 89
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1631540575402-3c2b1b0e5c5e?w=800",
        ],

      // RÉPARATION
      ServiceModel()
        ..serviceId = 9
        ..title = "Réparateur polyvalent - Tout type de réparation"
        ..description = "Réparation de meubles, portes, fenêtres, serrures, électroménagers. Bricolage général. Service à domicile rapide et efficace."
        ..serviceType = ServiceType.reparation
        ..price = 20000.0
        ..priceUnit = "Par heure"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000009"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-17:00"
        ..experienceYears = 6
        ..rating = 4.5
        ..reviewCount = 34
        ..isVerified = false
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      // NETTOYAGE / SALUBRITÉ
      ServiceModel()
        ..serviceId = 10
        ..title = "Service de nettoyage professionnel"
        ..description = "Nettoyage de bureaux, maisons, appartements. Nettoyage après déménagement, nettoyage de vitres, nettoyage en profondeur. Équipe professionnelle."
        ..serviceType = ServiceType.nettoyage
        ..price = 15000.0
        ..priceUnit = "Par heure"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000010"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-18:00"
        ..experienceYears = 4
        ..rating = 4.6
        ..reviewCount = 41
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
        ],

      // TRANSPORT / CHAUFFEUR
      ServiceModel()
        ..serviceId = 11
        ..title = "Chauffeur professionnel avec véhicule"
        ..description = "Service de chauffeur privé avec véhicule. Transport personnel, courses, rendez-vous. Véhicule propre et confortable. Disponible sur réservation."
        ..serviceType = ServiceType.transport
        ..price = 50000.0
        ..priceUnit = "Par jour"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000011"
        ..whatsapp = "+243900000011"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        ..availableHours = "06:00-22:00"
        ..experienceYears = 8
        ..rating = 4.9
        ..reviewCount = 95
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      // RÉNOVATION
      ServiceModel()
        ..serviceId = 12
        ..title = "Rénovation complète de maisons"
        ..description = "Rénovation complète de maisons et appartements. Plomberie, électricité, peinture, carrelage. Gestion complète de votre projet de rénovation."
        ..serviceType = ServiceType.renovation
        ..price = 500000.0
        ..priceUnit = "Par projet"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000012"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi"]
        ..availableHours = "08:00-17:00"
        ..experienceYears = 14
        ..rating = 4.8
        ..reviewCount = 67
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800",
        ],

      // INSTALLATION
      ServiceModel()
        ..serviceId = 13
        ..title = "Installation d'équipements"
        ..description = "Installation de portes, fenêtres, stores, rideaux, étagères, meubles. Montage et installation professionnels à domicile."
        ..serviceType = ServiceType.installation
        ..price = 25000.0
        ..priceUnit = "Par intervention"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000013"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-18:00"
        ..experienceYears = 7
        ..rating = 4.7
        ..reviewCount = 48
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      // SERRURERIE
      ServiceModel()
        ..serviceId = 14
        ..title = "Serrurier - Ouverture de portes"
        ..description = "Ouverture de portes bloquées, changement de serrures, installation de systèmes de sécurité. Intervention rapide 24/7 pour urgences."
        ..serviceType = ServiceType.serrurerie
        ..price = 30000.0
        ..priceUnit = "Par intervention"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000014"
        ..whatsapp = "+243900000014"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        ..availableHours = "00:00-23:59"
        ..experienceYears = 10
        ..rating = 4.9
        ..reviewCount = 112
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      // VITRERIE
      ServiceModel()
        ..serviceId = 15
        ..title = "Vitrier - Remplacement de vitres"
        ..description = "Remplacement de vitres cassées, miroirs, vitrines. Découpe sur mesure. Intervention rapide pour urgences."
        ..serviceType = ServiceType.vitrerie
        ..price = 35000.0
        ..priceUnit = "Par m²"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000015"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-18:00"
        ..experienceYears = 6
        ..rating = 4.6
        ..reviewCount = 29
        ..isVerified = false
        ..images = [
          "https://images.unsplash.com/photo-1589939705384-5185137a7f0f?w=800",
        ],

      // MAJORDOME / FEMME DE MÉNAGE
      ServiceModel()
        ..serviceId = 16
        ..title = "Femme de ménage professionnelle - Nettoyage complet"
        ..description = "Service de ménage professionnel à domicile. Nettoyage complet de votre maison, appartement ou bureau. Ponctuelle, sérieuse et expérimentée. Disponible tous les jours."
        ..serviceType = ServiceType.majordhomme
        ..price = 15000.0
        ..priceUnit = "Par heure"
        ..address = "Gombe, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Gombe"
        ..phone = "+243900000016"
        ..whatsapp = "+243900000016"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-18:00"
        ..experienceYears = 5
        ..specialties = ["nettoyage", "repassage", "cuisine"]
        ..rating = 4.7
        ..reviewCount = 52
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
          "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=800",
        ],

      ServiceModel()
        ..serviceId = 17
        ..title = "Aide-ménagère expérimentée - Service régulier"
        ..description = "Aide-ménagère avec 8 ans d'expérience. Nettoyage régulier ou ponctuel. Repassage, cuisine, entretien général. Références disponibles."
        ..serviceType = ServiceType.majordhomme
        ..price = 12000.0
        ..priceUnit = "Par heure"
        ..address = "Ngaliema, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Ngaliema"
        ..phone = "+243900000017"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi"]
        ..availableHours = "08:00-17:00"
        ..experienceYears = 8
        ..specialties = ["nettoyage", "repassage", "cuisine", "jardinage"]
        ..rating = 4.9
        ..reviewCount = 89
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
        ],

      ServiceModel()
        ..serviceId = 18
        ..title = "Service de ménage après déménagement"
        ..description = "Nettoyage en profondeur après déménagement. Nettoyage de vitres, sols, murs, sanitaires. Service complet pour votre nouveau logement."
        ..serviceType = ServiceType.majordhomme
        ..price = 50000.0
        ..priceUnit = "Par projet"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000018"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi", "dimanche"]
        ..availableHours = "07:00-20:00"
        ..experienceYears = 6
        ..specialties = ["nettoyage", "vitres"]
        ..rating = 4.8
        ..reviewCount = 34
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=800",
        ],

      ServiceModel()
        ..serviceId = 19
        ..title = "Femme de ménage - Service hebdomadaire"
        ..description = "Service de ménage hebdomadaire pour votre domicile. Nettoyage régulier, entretien, repassage. Personne de confiance et discrète."
        ..serviceType = ServiceType.majordhomme
        ..price = 20000.0
        ..priceUnit = "Par visite"
        ..address = "Lemba, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Lemba"
        ..phone = "+243900000019"
        ..whatsapp = "+243900000019"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi"]
        ..availableHours = "08:00-16:00"
        ..experienceYears = 4
        ..specialties = ["nettoyage", "repassage"]
        ..rating = 4.6
        ..reviewCount = 28
        ..isVerified = false
        ..images = [
          "https://images.unsplash.com/photo-1581578731548-c64695cc6952?w=800",
        ],

      // DÉMÉNAGEMENT
      ServiceModel()
        ..serviceId = 20
        ..title = "Service de déménagement complet - Camion et équipe"
        ..description = "Déménagement complet avec camion et équipe professionnelle. Emballage, transport, déballage. Service rapide et sécurisé dans toute la ville."
        ..serviceType = ServiceType.demenagement
        ..price = 200000.0
        ..priceUnit = "Par déménagement"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000020"
        ..whatsapp = "+243900000020"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-18:00"
        ..experienceYears = 10
        ..hasVehicle = true
        ..hasTeam = true
        ..teamSize = 4
        ..rating = 4.8
        ..reviewCount = 67
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
          "https://images.unsplash.com/photo-1621905251918-48416bd8575a?w=800",
        ],

      ServiceModel()
        ..serviceId = 21
        ..title = "Déménagement express - Service rapide"
        ..description = "Déménagement express pour petits et moyens volumes. Équipe expérimentée, matériel adapté. Intervention rapide le jour même sur réservation."
        ..serviceType = ServiceType.demenagement
        ..price = 150000.0
        ..priceUnit = "Par déménagement"
        ..address = "Gombe, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Gombe"
        ..phone = "+243900000021"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-17:00"
        ..experienceYears = 7
        ..hasVehicle = true
        ..hasTeam = true
        ..teamSize = 3
        ..rating = 4.7
        ..reviewCount = 45
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      ServiceModel()
        ..serviceId = 22
        ..title = "Transport de meubles et objets lourds"
        ..description = "Transport spécialisé pour meubles, électroménagers et objets lourds. Manutention professionnelle, protection des biens. Service fiable et sécurisé."
        ..serviceType = ServiceType.demenagement
        ..price = 80000.0
        ..priceUnit = "Par transport"
        ..address = "Kinshasa"
        ..cityValue = "Kinshasa"
        ..phone = "+243900000022"
        ..whatsapp = "+243900000022"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "07:00-19:00"
        ..experienceYears = 9
        ..hasVehicle = true
        ..hasTeam = true
        ..teamSize = 2
        ..rating = 4.9
        ..reviewCount = 92
        ..isVerified = true
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],

      ServiceModel()
        ..serviceId = 23
        ..title = "Déménagement économique - Petit volume"
        ..description = "Service de déménagement économique pour petits volumes. Idéal pour studios, chambres, bureaux. Prix compétitifs, service de qualité."
        ..serviceType = ServiceType.demenagement
        ..price = 100000.0
        ..priceUnit = "Par déménagement"
        ..address = "Masina, Kinshasa"
        ..cityValue = "Kinshasa"
        ..communeValue = "Masina"
        ..phone = "+243900000023"
        ..isAvailable = true
        ..availableDays = ["lundi", "mardi", "mercredi", "jeudi", "vendredi", "samedi"]
        ..availableHours = "08:00-18:00"
        ..experienceYears = 5
        ..hasVehicle = true
        ..hasTeam = true
        ..teamSize = 2
        ..rating = 4.6
        ..reviewCount = 38
        ..isVerified = false
        ..images = [
          "https://images.unsplash.com/photo-1504148455328-c376907d081c?w=800",
        ],
    ];
  }

  // Obtenir les services par type
  static List<ServiceModel> getServicesByType(ServiceType type) {
    return getStaticServices().where((service) => service.serviceType == type).toList();
  }

  // Obtenir les services populaires (top 6)
  static List<ServiceModel> getPopularServices() {
    final allServices = getStaticServices();
    allServices.sort((a, b) {
      final ratingA = a.rating ?? 0.0;
      final ratingB = b.rating ?? 0.0;
      final reviewA = a.reviewCount ?? 0;
      final reviewB = b.reviewCount ?? 0;
      // Trier par note puis par nombre d'avis
      if (ratingB.compareTo(ratingA) != 0) {
        return ratingB.compareTo(ratingA);
      }
      return reviewB.compareTo(reviewA);
    });
    return allServices.take(6).toList();
  }
}

