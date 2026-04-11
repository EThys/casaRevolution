import 'package:casa/controllers/PropertyCtrl.dart';
import 'package:casa/models/PropertyModel.dart';
import 'package:casa/models/TerrainModel.dart';
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

  final ctrl = context.read<PropertyController>();
  final enriched = await ctrl.enrichPropertySnapshot(property);
  if (!context.mounted) return;

  final Object args =
      heroTag != null ? <String, dynamic>{'property': enriched, 'heroTag': heroTag} : enriched;
  Navigator.pushNamed(context, Routes.detailPageRoute, arguments: args);
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
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _run() async {
    final c = context.read<PropertyController>();
    final e = await c.enrichPropertySnapshot(widget.property);
    if (!mounted) return;
    setState(() {
      _enriched = e;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _enriched == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return TerrainDetailPage(
      terrain: TerrainModel.fromPropertyListing(_enriched!),
      heroTag: widget.heroTag,
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
