import 'package:flutter/material.dart';

/// 1-5 yıldız. Seçili yıldıza tekrar dokunmak puanı kaldırır.
/// [onDegisti] verilmezse yalnızca gösterir.
class PuanSecici extends StatelessWidget {
  const PuanSecici({super.key, required this.puan, this.onDegisti, this.boyut = 32});

  final int? puan;
  final ValueChanged<int?>? onDegisti;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme.primary;
    final degistir = onDegisti;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          degistir == null
              ? Icon(i <= (puan ?? 0) ? Icons.star : Icons.star_border, color: renk, size: boyut)
              : IconButton(
                  key: Key('puan_$i'),
                  tooltip: '$i yıldız',
                  iconSize: boyut,
                  icon: Icon(i <= (puan ?? 0) ? Icons.star : Icons.star_border, color: renk),
                  onPressed: () => degistir(puan == i ? null : i),
                ),
      ],
    );
  }
}
