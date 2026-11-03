import 'package:casa/models/PropertyFeatureModel.dart';
import 'package:casa/models/PropertyImageKitchenModel.dart';
import 'package:casa/models/PropertyImageLivingRoomModel.dart';
import 'package:casa/models/PropertyImageModel.dart';
import 'package:casa/models/PropertyImageRoomModel.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/UserModel.dart';
import 'package:casa/utils/listing_fields_parse.dart';

/// Fusionne un modèle « navigation » (souvent partiel : favoris, réservations, etc.)
/// avec une source plus riche (cache mémoire, SQLite, réponse API détail).
///
/// Règle : chaque champ garde la valeur du [nav] si elle est significative,
/// sinon celle de [fill]. Pour les listes (images, chambres hôtel), on préfère
/// la liste la plus complète.
class PropertySnapshotMerge {
  PropertySnapshotMerge._();

  static String? _nz(String? nav, String? rich) {
    if (nav != null && nav.trim().isNotEmpty) return nav;
    return rich;
  }

  /// Fusionne les chambres par id : garde le texte et les photos les plus complets.
  static List<HotelRoomStructure>? mergeHotelRooms(
    List<HotelRoomStructure>? nav,
    List<HotelRoomStructure>? rich,
  ) {
    if ((nav == null || nav.isEmpty) && (rich == null || rich.isEmpty)) {
      return nav ?? rich;
    }
    final byId = <int, HotelRoomStructure>{};
    final withoutId = <HotelRoomStructure>[];

    void take(List<HotelRoomStructure>? list) {
      if (list == null) return;
      for (final room in list) {
        final id = room.chambre?.id;
        if (id == null) {
          withoutId.add(room);
          continue;
        }
        final prev = byId[id];
        byId[id] = prev == null ? room : richerRoom(prev, room);
      }
    }

    take(rich);
    take(nav);
    if (byId.isEmpty && withoutId.isEmpty) return nav ?? rich;
    return [...byId.values, ...withoutId];
  }

  static HotelRoomStructure richerRoom(HotelRoomStructure a, HotelRoomStructure b) {
    final aCount = a.images?.length ?? 0;
    final bCount = b.images?.length ?? 0;
    final images = bCount > aCount
        ? b.images
        : (aCount > 0 ? a.images : b.images);
    return HotelRoomStructure(
      chambre: _richerChambre(a.chambre, b.chambre),
      images: images,
    );
  }

  static String? _longerText(String? a, String? b) {
    final as = (a ?? '').trim();
    final bs = (b ?? '').trim();
    if (bs.length > as.length) return b;
    return as.isNotEmpty ? a : b;
  }

  static HotelRoomModel? _richerChambre(HotelRoomModel? a, HotelRoomModel? b) {
    if (a == null) return b;
    if (b == null) return a;
    final price = (a.price != null && a.price! > 0) ? a.price : b.price;
    return HotelRoomModel(
      id: a.id ?? b.id,
      hotelId: a.hotelId ?? b.hotelId,
      deviseId: a.deviseId ?? b.deviseId,
      title: _longerText(a.title, b.title),
      description: _longerText(a.description, b.description),
      numberPiece: a.numberPiece ?? b.numberPiece,
      price: price,
      priceHeure: _longerText(a.priceHeure, b.priceHeure),
      createdAt: a.createdAt ?? b.createdAt,
      updatedAt: a.updatedAt ?? b.updatedAt,
      available: a.available ?? b.available,
    );
  }

  static List<T>? _preferLongerList<T>(List<T>? nav, List<T>? rich) {
    final ln = nav?.length ?? 0;
    final lr = rich?.length ?? 0;
    if (lr > ln) return rich;
    if (ln > 0) return nav;
    return rich ?? nav;
  }

  static UserModel? _mergeUser(UserModel? nav, UserModel? rich) {
    if (rich == null) return nav;
    if (nav == null) return rich;
    return nav.copyWith(
      userId: nav.userId ?? rich.userId,
      email: _nz(nav.email, rich.email),
      username: _nz(nav.username, rich.username),
      phone: _nz(nav.phone, rich.phone),
      city: _nz(nav.city, rich.city),
      country: _nz(nav.country, rich.country),
      profilePicture: _nz(nav.profilePicture, rich.profilePicture),
      fullName: _nz(nav.fullName, rich.fullName),
      isPremium: nav.isPremium ?? rich.isPremium,
      isCertified: nav.isCertified ?? rich.isCertified,
      cityModel: nav.cityModel ?? rich.cityModel,
      typeAccount: nav.typeAccount ?? rich.typeAccount,
      createdStart: _nz(nav.createdStart, rich.createdStart),
    );
  }

  /// [nav] : snapshot issu de la navigation (peut être minimal).
  /// [fill] : donnée locale ou API plus complète (même [propertyId]).
  static PropertyModel mergeFillMissing(PropertyModel nav, PropertyModel? fill) {
    if (fill == null) return nav;
    if (nav.propertyId != null &&
        fill.propertyId != null &&
        nav.propertyId != fill.propertyId) {
      return nav;
    }

    final rich = fill;

    return rich.copyWith(
      propertyId: nav.propertyId ?? rich.propertyId,
      title: _nz(nav.title, rich.title),
      username: _nz(nav.username, rich.username),
      postBy: _nz(nav.postBy, rich.postBy),
      image: _nz(nav.image, rich.image),
      description: _nz(nav.description, rich.description),
      price: nav.price ?? rich.price,
      surface: nav.surface ?? rich.surface,
      rooms: nav.rooms ?? rich.rooms,
      bedrooms: nav.bedrooms ?? rich.bedrooms,
      kitchen: nav.kitchen ?? rich.kitchen,
      livingRoom: nav.livingRoom ?? rich.livingRoom,
      bathroom: nav.bathroom ?? rich.bathroom,
      floor: nav.floor ?? rich.floor,
      address: _nz(nav.address, rich.address),
      guarantee: _nz(nav.guarantee, rich.guarantee),
      communeValue: _nz(nav.communeValue, rich.communeValue),
      cityValue: _nz(nav.cityValue, rich.cityValue),
      countryValue: _nz(nav.countryValue, rich.countryValue),
      districtValue: _nz(nav.districtValue, rich.districtValue),
      quartierValue: _nz(nav.quartierValue, rich.quartierValue),
      cityId: nav.cityId ?? rich.cityId,
      communeId: nav.communeId ?? rich.communeId,
      quartierId: nav.quartierId ?? rich.quartierId,
      districtId: nav.districtId ?? rich.districtId,
      postalCode: _nz(nav.postalCode, rich.postalCode),
      quartier: _nz(nav.quartier, rich.quartier),
      transactionType: _nz(nav.transactionType, rich.transactionType),
      propertyTypeId: nav.propertyTypeId ?? rich.propertyTypeId,
      propertyType: nav.propertyType ?? rich.propertyType,
      userId: nav.userId ?? rich.userId,
      user: _mergeUser(nav.user, rich.user),
      latitude: nav.latitude ?? rich.latitude,
      longitude: nav.longitude ?? rich.longitude,
      createdStart: _nz(nav.createdStart, rich.createdStart),
      updatedAt: _nz(nav.updatedAt, rich.updatedAt),
      createdAt: _nz(nav.createdAt, rich.createdAt),
      electric: nav.electric ?? rich.electric,
      water: nav.water ?? rich.water,
      roomMeet: nav.roomMeet ?? rich.roomMeet,
      numberPiece: nav.numberPiece ?? rich.numberPiece,
      isEquip: nav.isEquip ?? rich.isEquip,
      capacityPeople: nav.capacityPeople ?? rich.capacityPeople,
      isDecore: nav.isDecore ?? rich.isDecore,
      pisteDanse: nav.pisteDanse ?? rich.pisteDanse,
      usage: _nz(nav.usage, rich.usage),
      viewCount: nav.viewCount ?? rich.viewCount,
      favoriteCount: nav.favoriteCount ?? rich.favoriteCount,
      isFavorite: nav.isFavorite ?? rich.isFavorite,
      rating: nav.rating ?? rich.rating,
      reviewCount: nav.reviewCount ?? rich.reviewCount,
      isActive: nav.isActive ?? rich.isActive,
      isVerified: nav.isVerified ?? rich.isVerified,
      isFeatured: nav.isFeatured ?? rich.isFeatured,
      available: ListingFieldsParse.mergeAvailable(nav.available, rich.available) ??
          nav.available ??
          rich.available,
      sold: ListingFieldsParse.mergeSold(nav.sold, rich.sold) ?? nav.sold ?? rich.sold,
      listingAllowed: rich.listingAllowed,
      status: _nz(nav.status, rich.status),
      rejectionReason: _nz(nav.rejectionReason, rich.rejectionReason),
      features: _preferLongerList<PropertyFeatureModel>(nav.features, rich.features),
      propertyImage: _preferLongerList<PropertyImageModel>(nav.propertyImage, rich.propertyImage),
      propertyImageRoom: _preferLongerList<PropertyImageRoomModel>(nav.propertyImageRoom, rich.propertyImageRoom),
      propertyImageLivingRoom:
          _preferLongerList<PropertyImageLivingRoomModel>(nav.propertyImageLivingRoom, rich.propertyImageLivingRoom),
      propertyImageKitchen:
          _preferLongerList<PropertyImageKitchenModel>(nav.propertyImageKitchen, rich.propertyImageKitchen),
      deviseId: nav.deviseId ?? rich.deviseId,
      hotelStructure: mergeHotelRooms(nav.hotelStructure, rich.hotelStructure),
    );
  }
}
