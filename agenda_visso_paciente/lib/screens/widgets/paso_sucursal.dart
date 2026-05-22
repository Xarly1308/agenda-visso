import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/sede.dart';
import '../../utils/app_theme.dart';

class PasoSucursal extends StatelessWidget {
  final List<Sede> sedes;
  final String? profesionalNombre;
  final ValueChanged<Sede> onSedeSeleccionada;

  const PasoSucursal({
    super.key,
    required this.sedes,
    required this.profesionalNombre,
    required this.onSedeSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selecciona una sucursal',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                color: AppTheme.primary,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Elije el centro de atención que más te convenga para recibir un diagnóstico profesional y personalizado.',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 32),
        if (profesionalNombre != null)
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.tertiary,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.primaryContainer.withAlpha(51)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Icon(Icons.medical_services, color: AppTheme.primaryContainer),
                    const SizedBox(width: 12),
                    Text(
                      'Especialista asignado:',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppTheme.primaryContainer),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(
                    profesionalNombre!,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              ],
            ),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth > 600;
            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: isDesktop ? 2 : 1,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                mainAxisExtent: 520,
              ),
              itemCount: sedes.length,
              itemBuilder: (context, index) {
                final sede = sedes[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSedeSeleccionada(sede),
                    borderRadius: BorderRadius.circular(8),
                    hoverColor: AppTheme.tertiary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Foto de la sede
                        _buildImagenSede(sede),
                        
                        // Información
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  sede.nombre,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.location_on_outlined, size: 16, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        sede.direccion,
                                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const Spacer(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    onPressed: () => _abrirMapa(sede.direccion),
                                    icon: const Icon(Icons.map_outlined, size: 18),
                                    label: const Text('Ver Mapa'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppTheme.primaryContainer,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
        const SizedBox(height: 48),
        _buildReviewsSection(context),
      ],
    );
  }

  Widget _buildImagenSede(Sede sede) {
    const assets = {
      'acropolis-visso': 'assets/ac-vs.jpg',
      'visso-funza': 'assets/vs-fz.jpg',
    };

    final assetPath = assets[sede.id];

    if (assetPath != null) {
      return Image.asset(
        assetPath,
        height: 350,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImagen(),
      );
    }
    return _buildPlaceholderImagen();
  }

  Widget _buildPlaceholderImagen() {
    return Container(
      height: 350,
      color: AppTheme.surfaceContainer,
      child: const Center(
        child: Icon(Icons.store, color: Colors.grey, size: 48),
      ),
    );
  }

  Future<void> _abrirMapa(String direccion) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(direccion)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  Widget _buildReviewsSection(BuildContext context) {
    final reviews = [
      {
        'nombre': 'Pvblo Platero',
        'info': 'Local Guide · 181 opiniones · 6 fotos',
        'tiempo': 'Hace 6 años',
        'comentario': 'La atención y profesionalismo de la óptica son su mejor carta de presentación, recomendada completamente',
        'estrellas': 5,
        'avatar': 'P',
      },
      {
        'nombre': 'Camilo Rodriguez',
        'info': '3 opiniones',
        'tiempo': 'Hace 2 meses',
        'comentario': 'Excelente atención y calidad, muy amables',
        'estrellas': 5,
        'avatar': 'C',
      },
      {
        'nombre': 'Oscar Orlando Sánchez',
        'info': '1 opinión',
        'tiempo': 'Hace 6 años',
        'comentario': 'Excelente servicio.',
        'estrellas': 5,
        'avatar': 'O',
      },
      {
        'nombre': 'Andrea Carolina López Gómez',
        'info': 'Local Guide · 126 opiniones · 35 fotos',
        'tiempo': 'Hace 7 años',
        'comentario': 'Recomendado totalmente, las instalaciones impecables.',
        'estrellas': 5,
        'avatar': 'A',
      },
      {
        'nombre': 'Jose Cardenas',
        'info': '',
        'tiempo': 'Hace 7 años',
        'comentario': 'Muy buen lugar, la atención al paciente es prioridad.',
        'estrellas': 5,
        'avatar': 'J',
      },
    ];

    return ReviewsCarousel(reviews: reviews);
  }
}

class ReviewsCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> reviews;
  const ReviewsCarousel({super.key, required this.reviews});

  @override
  State<ReviewsCarousel> createState() => _ReviewsCarouselState();
}

class _ReviewsCarouselState extends State<ReviewsCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.85);
    _startAutoScroll();
  }

  void _startAutoScroll() {
    _timer = Timer.periodic(const Duration(seconds: 6), (_) {
      if (widget.reviews.isEmpty) return;
      final nextPage = (_currentPage + 1) % widget.reviews.length;
      _controller.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      setState(() => _currentPage = nextPage);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.reviews.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              final review = widget.reviews[index];
              return _buildReviewCard(review);
            },
          ),
          Positioned(
            left: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black45),
              onPressed: () {
                final prevPage = _currentPage - 1;
                _controller.animateToPage(
                  prevPage < 0 ? widget.reviews.length - 1 : prevPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
          Positioned(
            right: 8,
            child: IconButton(
              icon: const Icon(Icons.arrow_forward_ios, size: 20, color: Colors.black45),
              onPressed: () {
                final nextPage = (_currentPage + 1) % widget.reviews.length;
                _controller.animateToPage(
                  nextPage,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    const googleColors = [
      Color(0xFF4285F4), // G
      Color(0xFFEA4335), // o
      Color(0xFFFBBC05), // o
      Color(0xFF34A853), // g
      Color(0xFF4285F4), // l
      Color(0xFFEA4335), // e
    ];
    const googleLetters = ['G', 'o', 'o', 'g', 'l', 'e'];

    return SizedBox(
      width: 280,
      child: Card(
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        elevation: 1,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.grey.shade200,
                    child: Text(review['avatar'] as String,
                        style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(review['nombre'] as String,
                            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if ((review['info'] as String).isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(review['info'] as String,
                              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  ...List.generate(
                    review['estrellas'] as int,
                    (i) => const Icon(Icons.star, color: Color(0xFFFABB05), size: 18),
                  ),
                  const SizedBox(width: 6),
                  Text(review['tiempo'] as String,
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(review['comentario'] as String,
                    style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  ...googleLetters.asMap().entries.map((e) => Text(
                        e.value,
                        style: TextStyle(
                          color: googleColors[e.key],
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                  const SizedBox(width: 4),
                  Text('Reviews',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
