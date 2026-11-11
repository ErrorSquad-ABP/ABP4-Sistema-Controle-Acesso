import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'location_contract.dart';

/// Cartão da lista (frame "Locais de acesso"): identificação, contexto e o
/// alcance do geofence.
class LocationCard extends StatelessWidget {
  const LocationCard({super.key, required this.location});

  final Location location;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final description = location.description;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: palette.background,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  Icons.apartment_outlined,
                  size: 24,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _StatusChip(active: location.isActive),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                location.name,
                style: text.titleLarge?.copyWith(height: 1.35),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                description == null
                    ? 'Raio de ${location.radiusMeters} m'
                    : '$description · raio de ${location.radiusMeters} m',
                style: text.bodySmall?.copyWith(height: 1.35),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Latitude ${_coordinate(location.latitude)} · '
            'Longitude ${_coordinate(location.longitude)}',
            style: text.bodySmall?.copyWith(height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Graus decimais com 4 casas no separador pt-BR; é a precisão que o backend
/// guarda e o que o administrador confere ao cadastrar.
String _coordinate(double value) =>
    value.toStringAsFixed(4).replaceAll('.', ',');

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (background, dot) = active
        ? (palette.successSoft, palette.success)
        : (palette.errorSoft, palette.error);

    return Container(
      // 12/8 do Figma: o horizontal não cai na grade de 8.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              active ? 'Ativo' : 'Inativo',
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: palette.onSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
