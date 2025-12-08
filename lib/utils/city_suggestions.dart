// Suggestions de villes pour l'autocomplétion du formulaire d'inscription.
// Ajoutez/complétez cette liste selon les besoins métiers.
//
// Note: certains écrans consomment `CitySuggestions.cities`, on expose donc une
// classe statique pour compatibilité, tout en conservant la liste brute.
class CitySuggestions {
  static const List<String> cities = citySuggestions;
}

const List<String> citySuggestions = [
  // RDC
  'Kinshasa', 'Lubumbashi', 'Goma', 'Bukavu', 'Kisangani', 'Mbuji-Mayi', 'Kananga',
  'Kolwezi', 'Matadi', 'Kikwit', 'Uvira', 'Bunia', 'Mbandaka', 'Kalemie', 'Kindu',
  'Isiro', 'Butembo', 'Boma', 'Gbadolite', 'Kamina', 'Beni', 'Likasi', 'Mwene-Ditu',
  'Kabinda', 'Kongolo', 'Kipushi', 'Kasongo', 'Bumba', 'Bandundu', 'Inongo', 'Kenge',
  'Moanda', 'Tshela', 'Kisantu', 'Kimpese',

  // Afrique
  'Abidjan', 'Dakar', 'Yaoundé', 'Douala', 'Libreville', 'Brazzaville', 'Lagos',
  'Accra', 'Cotonou', 'Niamey', 'Ouagadougou', 'Bamako', 'Conakry', 'Monrovia',
  'Tunis', 'Alger', 'Casablanca', 'Rabat', 'Marrakech', 'Nairobi', 'Addis-Abeba',
  'Kampala', 'Harare', 'Maputo', 'Johannesburg', 'Cape Town', 'Durban', 'Pretoria',
  'Lusaka', 'Windhoek', 'Kigali', 'Bujumbura', 'Djibouti', 'Tripoli',

  // Europe
  'Paris', 'Londres', 'Bruxelles', 'Amsterdam', 'Berlin', 'Madrid', 'Rome', 'Lisbonne',
  'Barcelone', 'Valence', 'Séville', 'Milan', 'Naples', 'Turin', 'Florence', 'Venise',
  'Vienne', 'Prague', 'Budapest', 'Varsovie', 'Dublin', 'Copenhague', 'Stockholm',
  'Oslo', 'Helsinki', 'Zurich', 'Genève', 'Munich', 'Hambourg', 'Cologne',
  'Francfort', 'Stuttgart', 'Rotterdam', 'La Haye', 'Anvers', 'Gand',

  // Amériques / Asie (quelques exemples)
  'New York', 'Los Angeles', 'Miami', 'Montréal', 'Toronto', 'Mexico',
  'São Paulo', 'Buenos Aires', 'Santiago', 'Bogotá', 'Lima',
  'Tokyo', 'Seoul', 'Singapour', 'Hong Kong', 'Shanghai', 'Pékin', 'New Delhi',
];

