import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/TerrainModel.dart';
import 'package:casa/models/AgenceModel.dart';
import 'package:casa/utils/Endpoints.dart';
import 'package:casa/utils/requetes.dart';
import 'package:casa/screens/AgenceDetailsPage.dart';
import 'package:casa/screens/HotelDetailPage.dart';
import 'package:casa/screens/PropertyDetailPage.dart';
import 'package:casa/screens/TerrainDetailPage.dart';
import 'package:casa/utils/Routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Ouvre le détail approprié après enrichissement local (mémoire / SQLite),
/// pour aligner Home, catégories, recherche et listes avec le même niveau d’info
/// qu’une entrée déjà complète (ex. terrains depuis l’API JSON complet).
Future<void> navigateToPropertyDetail(
  BuildContext context,
  PropertyModel property, {
  String? heroTag,
}) async {
  if (property.propertyTypeId == 9) {
    if (!context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EnrichedTerrainDetailHost(
          property: property,
          heroTag: heroTag,
        ),
      ),
    );
    return;
  }

  // Vacances: ouvrir la page agence dédiée si on a agenceId.
  if (property.propertyTypeId == 6 ||
      property.propertyTypeId == 10 ||
      property.propertyTypeId == 11) {
    final agenceId = property.agenceId;
    if (agenceId != null) {
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AgenceIdDetailLoader(agenceId: agenceId),
        ),
      );
      return;
    }
  }

  final ctrl = context.read<PropertyController>();
  final enriched = await ctrl.enrichPropertySnapshot(property);
  if (!context.mounted) return;

  // Détail hôtel: écran dédié, plus riche/optimisé.
  if (enriched.propertyTypeId == 5) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HotelDetailPage(property: enriched),
      ),
    );
    return;
  }

  final Object args =
      heroTag != null ? <String, dynamic>{'property': enriched, 'heroTag': heroTag} : enriched;
  Navigator.pushNamed(context, Routes.detailPageRoute, arguments: args);
}

/// Charge une agence depuis l’API puis ouvre [AgenceDetailsPage].
class AgenceIdDetailLoader extends StatefulWidget {
  final int agenceId;

  const AgenceIdDetailLoader({Key? key, required this.agenceId}) : super(key: key);

  @override
  State<AgenceIdDetailLoader> createState() => _AgenceIdDetailLoaderState();
}

class _AgenceIdDetailLoaderState extends State<AgenceIdDetailLoader> {
  bool _loading = true;
  String? _error;
  AgenceModel? _agency;

  List<AgenceSiteModel> _parseSitesFromItem(Map<String, dynamic> item) {
    final raw = item['site'] ?? item['sites'];
    if (raw is! List) return const [];
    final out = <AgenceSiteModel>[];
    for (final s in raw) {
      if (s is! Map) continue;
      out.add(AgenceSiteModel.fromJson(Map<String, dynamic>.from(s as Map)));
    }
    return out;
  }

  List<AgenceSiteModel> _parseSitesFromDetail(Map<String, dynamic> node) {
    final raw = node['site'] ?? node['sites'];
    if (raw is! List) return const [];
    final out = <AgenceSiteModel>[];
    for (final s in raw) {
      if (s is! Map) continue;
      out.add(AgenceSiteModel.fromJson(Map<String, dynamic>.from(s as Map)));
    }
    return out;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      // 1) Tenter un endpoint détail si dispo.
      final detailResp = await getData('${Endpoints.agences}/${widget.agenceId}');
      if (detailResp is Map) {
        final m = Map<String, dynamic>.from(detailResp as Map);
        final node = (m['data'] is Map)
            ? Map<String, dynamic>.from(m['data'] as Map)
            : (m['agence'] is Map ? Map<String, dynamic>.from(m['agence'] as Map) : m);
        final agency = AgenceModel.fromJson(node);
        agency.sites = _parseSitesFromDetail(node);
        if (!mounted) return;
        setState(() {
          _agency = agency;
          _loading = false;
        });
        return;
      }

      // 2) Fallback réel API: /public/agences → {data:[{agence:{...}, site:[...]}, ...]}
      final listResp = await getData(Endpoints.agences);
      if (listResp is Map) {
        final m = Map<String, dynamic>.from(listResp as Map);
        final data = m['data'];
        if (data is List) {
          Map<String, dynamic>? agenceNode;
          Map<String, dynamic>? matchedItem;
          for (final item in data) {
            if (item is! Map) continue;
            final mm = Map<String, dynamic>.from(item as Map);
            final a = mm['agence'];
            if (a is! Map) continue;
            final am = Map<String, dynamic>.from(a as Map);
            final id = am['id'] ?? am['agenceId'];
            if (id?.toString() == widget.agenceId.toString()) {
              agenceNode = am;
              matchedItem = mm;
              break;
            }
          }
          if (agenceNode != null) {
            final agency = AgenceModel.fromJson(agenceNode);
            if (matchedItem != null) {
              agency.sites = _parseSitesFromItem(matchedItem!);
            }
            if (!mounted) return;
            setState(() {
              _agency = agency;
              _loading = false;
            });
            return;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _error = 'Agence introuvable.';
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement.';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Agence')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!))),
      );
    }
    return AgenceDetailsPage(agency: _agency!);
  }
}

/// Route nommée / notifications : terrain avec enrichissement cache avant affichage.
class EnrichedTerrainDetailHost extends StatefulWidget {
  final PropertyModel property;
  final String? heroTag;

  const EnrichedTerrainDetailHost({
    Key? key,
    required this.property,
    this.heroTag,
  }) : super(key: key);

  @override
  State<EnrichedTerrainDetailHost> createState() => _EnrichedTerrainDetailHostState();
}

class _EnrichedTerrainDetailHostState extends State<EnrichedTerrainDetailHost> {
  PropertyModel? _enriched;

  @override
  void initState() {
    super.initState();
    // Affichage optimiste: on montre immédiatement le détail avec le snapshot actuel,
    // puis on enrichit en arrière-plan (sans spinner bloquant).
    _enriched = widget.property;
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final c = context.read<PropertyController>();
    // Important: pour les terrains, certaines infos (annonceur, photos, etc.)
    // n’arrivent pas toujours dans les snapshots (Home/lists). On fait donc:
    // cache/local enrichment -> fetch by id -> merge -> affichage.
    final partial = await c.enrichPropertySnapshot(widget.property);
    final id = widget.property.propertyId ?? partial.propertyId;
    PropertyModel e = partial;
    if (id != null) {
      final fresh = await c.getPropertyById(
        id,
        propertyTypeId: 9,
        mergeWith: partial,
      );
      if (fresh != null) e = fresh;
    }
    if (!mounted) return;
    setState(() {
      _enriched = e;
    });
  }

  @override
  Widget build(BuildContext context) {
    final model = _enriched ?? widget.property;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      child: TerrainDetailPage(
        key: ValueKey<int?>(model.propertyId),
        terrain: TerrainModel.fromPropertyListing(model),
        heroTag: widget.heroTag,
      ),
    );
  }
}

/// Charge un bien depuis [propertyId] (ex. notification) puis ouvre le bon écran.
class PropertyIdDetailLoader extends StatefulWidget {
  final int propertyId;
  final int? propertyTypeId;

  const PropertyIdDetailLoader({
    Key? key,
    required this.propertyId,
    this.propertyTypeId,
  }) : super(key: key);

  @override
  State<PropertyIdDetailLoader> createState() => _PropertyIdDetailLoaderState();
}

class _PropertyIdDetailLoaderState extends State<PropertyIdDetailLoader> {
  bool _loading = true;
  String? _error;
  PropertyModel? _model;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final c = context.read<PropertyController>();
    final hint = PropertyModel(
      propertyId: widget.propertyId,
      propertyTypeId: widget.propertyTypeId,
    );
    final partial = await c.enrichPropertySnapshot(hint);
    final fresh = await c.getPropertyById(
      widget.propertyId,
      propertyTypeId: widget.propertyTypeId ?? partial.propertyTypeId,
      mergeWith: partial,
    );
    if (!mounted) return;
    if (fresh == null) {
      setState(() {
        _loading = false;
        _error = 'Bien introuvable ou indisponible.';
      });
      return;
    }
    setState(() {
      _model = fresh;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Détail')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              _error!,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final m = _model!;
    if (m.propertyTypeId == 9) {
      return TerrainDetailPage(
        terrain: TerrainModel.fromPropertyListing(m),
      );
    }
    if (m.propertyTypeId == 5) {
      return HotelDetailPage(property: m);
    }
    return PropertyDetailPage(property: m);
  }
}
