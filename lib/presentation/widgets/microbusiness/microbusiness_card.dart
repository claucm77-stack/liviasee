import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../domain/entities/microbusiness.dart';

class MicrobusinessCard extends StatelessWidget {
  const MicrobusinessCard({
    super.key,
    required this.business,
    required this.onTap,
    required this.onHowToGet,
    required this.onToggleFavorite,
    required this.isFavorite,
  });

  final Microbusiness business;
  final VoidCallback onTap;
  final VoidCallback onHowToGet;
  final VoidCallback onToggleFavorite;
  final bool isFavorite;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _BusinessImage(imageUrl: business.imagen),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      business.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceAlt,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        business.categoria,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppColors.primaryDark,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    _BusinessRating(
                      rating: business.ratingPromedio,
                      totalRatings: business.totalCalificaciones,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      business.descripcion,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: onHowToGet,
                          icon: const Icon(Icons.directions_outlined),
                          label: const Text('Cómo llegar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onToggleFavorite,
                icon: Icon(
                  isFavorite ? Icons.favorite : Icons.favorite_border,
                  color: isFavorite ? Colors.red : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BusinessRating extends StatelessWidget {
  const _BusinessRating({
    required this.rating,
    required this.totalRatings,
  });

  final double? rating;
  final int? totalRatings;

  @override
  Widget build(BuildContext context) {
    final normalizedRating = (rating ?? 0).clamp(0, 5).toDouble();
    final count = totalRatings ?? 0;
    final countLabel = count == 1 ? 'calificación' : 'calificaciones';

    return Wrap(
      spacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (index) {
            final remaining = normalizedRating - index;
            final icon = remaining >= 0.75
                ? Icons.star
                : remaining >= 0.25
                    ? Icons.star_half
                    : Icons.star_border;
            return Icon(icon, color: Colors.amber.shade700, size: 17);
          }),
        ),
        Text(
          '${normalizedRating.toStringAsFixed(1)} · $count $countLabel',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _BusinessImage extends StatelessWidget {
  const _BusinessImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: 76,
        height: 76,
        child: imageUrl.isEmpty
            ? Container(
                color: AppColors.surfaceAlt,
                child: const Icon(Icons.storefront, color: AppColors.primary),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}
