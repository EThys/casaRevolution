 import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/ServiceController.dart';
import '../models/PrestationModel.dart';
import 'ServiceDetailPage.dart';

/// Charge une prestation par id puis affiche [ServiceDetailPage].
///
/// Utiliser avec `Navigator.pushNamed(context, Routes.serviceDetail, arguments: {
///   'prestationId': 28,
///   'sollicitationId': optional,
/// });`
class PrestationIdDetailLoader extends StatefulWidget {
  const PrestationIdDetailLoader({
    Key? key,
    required this.prestationId,
    this.sollicitationId,
    this.serviceTypeName,
  }) : super(key: key);

  final int prestationId;
  final int? sollicitationId;
  final String? serviceTypeName;

  @override
  State<PrestationIdDetailLoader> createState() =>
      _PrestationIdDetailLoaderState();
}

class _PrestationIdDetailLoaderState extends State<PrestationIdDetailLoader> {
  Future<PrestationModel?>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= context
        .read<ServiceController>()
        .getPrestationById(widget.prestationId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PrestationModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final p = snapshot.data;
        if (p == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Prestation')),
            body: const Center(
              child: Text('Impossible de charger cette prestation.'),
            ),
          );
        }
        return ServiceDetailPage(
          service: p,
          serviceTypeName: widget.serviceTypeName,
          sollicitationId: widget.sollicitationId,
        );
      },
    );
  }
}
